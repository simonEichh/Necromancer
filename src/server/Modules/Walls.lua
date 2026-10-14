-- Per-plot wall: HP bar, preview queue, breaking and reset.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")
local Remotes = require(script.Parent.Remotes)
local Collision = require(script.Parent.Collision)
local PlotFrame = require(script.Parent.PlotFrame)
local Quests = require(script.Parent.Quests)
local PlayerData = require(script.Parent.PlayerData)
local Drops = require(script.Parent.Drops)
local Economy = require(game:GetService("ReplicatedStorage").Shared.Economy)

local incrementQuest = Quests.increment

-- Lane layout, in "forward" studs along the lane measured from the plot centre (see PlotFrame):
--   0 .. 24     the plot's Base (graves, spawn)
--   24 .. 105   open battlefield: the army marches here and forms up (see Army: formation rows)
--   105 .. 302  the walls of a run (Economy.WALLS_PER_RUN, 4 of them), WALL_SPACING apart, ALL standing from the start. The
--               front wall is the first one; breaking it crumbles it and the army marches on to the next, so it advances
--               down the lane until it reaches the last wall: THE GATE, in front of the outer ring's gate tower.
--   308         the lane ends at the gate tower of the outer ring (radius 392 minus the plot centre radius 84,
--               see tools/studio/build_ring.lua). If you move the ring, update LANE_END_FWD and GATE_FWD.
local NUM_WALLS = Economy.WALLS_PER_RUN
local WALL_FWD = 105         -- distance of the FIRST wall from the plot centre
local GATE_FWD = 302         -- distance of the last wall (the gate)
local LANE_START_FWD = 24    -- outer edge of the plot's Base
local LANE_END_FWD = 308
local WALL_SPACING = (GATE_FWD - WALL_FWD) / (NUM_WALLS - 1) -- about 66 studs with 4 walls
local WALL_WIDTH = 40        -- across the lane
local WALL_THICKNESS = 3
local WALL_HEIGHT = 20       -- height of an ordinary wall
local GATE_HEIGHT = 36       -- the gate is taller

-- lane look (matches the plaza stone)
local LANE_COLOR = Color3.fromRGB(84, 88, 106)
local LANE_WALL_COLOR = Color3.fromRGB(88, 91, 106)
local LANE_CAP_COLOR = Color3.fromRGB(122, 126, 142)

-- Front-wall tint per layer (cycles). Muted so the walls match the gothic stone look.
local LAYER_COLORS = {
	Color3.fromRGB(122, 126, 142),
	Color3.fromRGB(92, 128, 106),
	Color3.fromRGB(92, 110, 160),
	Color3.fromRGB(130, 100, 160),
	Color3.fromRGB(160, 100, 108),
}

-- "12.3K" style numbers for the HP text (wall HP gets huge)
local function compact(n)
	n = math.floor(n)
	if n >= 1e15 then return string.format("%.1fQa", n / 1e15)
	elseif n >= 1e12 then return string.format("%.1fT", n / 1e12)
	elseif n >= 1e9 then return string.format("%.1fB", n / 1e9)
	elseif n >= 1e6 then return string.format("%.1fM", n / 1e6)
	elseif n >= 1e4 then return string.format("%.1fK", n / 1e3)
	end
	return tostring(n)
end

-- Fill colour by remaining health: a deep blood red when almost broken, a lively red-orange when full
local FILL_LOW = Color3.fromRGB(150, 38, 38)
local FILL_FULL = Color3.fromRGB(232, 78, 56)

-- "WALL 5 / 32", "THE GATE" for the last wall of a run, "LAYER 40" beyond it (walls past the gate are optional farming)
local GATE_COLOR = Color3.fromRGB(150, 118, 60)
local function layerText(layer)
	if Economy.isGate(layer) then
		return "THE GATE"
	elseif layer < Economy.WALLS_PER_RUN then
		return "WALL " .. layer .. " / " .. Economy.WALLS_PER_RUN
	end
	return "LAYER " .. layer
end

-- The realm's wall model (ServerStorage.WallModels, built by tools/studio/build_wall_cemetery.lua). The wall part stays
-- as the invisible collider and the model is cloned into it as "WallModel". The gate keeps the plain slab until its own
-- model exists.
local WALL_MODEL_GUI_LIFT = 8 -- the model is taller than the slab (fence, cross): lift the HP bar and the tag
local function wallModelFor(layer)
	local models = ServerStorage:FindFirstChild("WallModels")
	if Economy.isGate(layer) or not models then return nil end
	return models:FindFirstChild("Cemetery")
end

-- Damage stage of a modelled wall from its HP (0 intact, 1 at 75 %, 2 at 50 %, 3 at 25 %; 4 = collapse when it breaks).
-- Only ever goes up (the wall regenerates a little, the cracks stay). The client animates it (Modules/WallStages).
local function setWallStage(wallPart, stage)
	local m = wallPart and wallPart:FindFirstChild("WallModel")
	if m and stage > (m:GetAttribute("Stage") or 0) then
		m:SetAttribute("Stage", stage)
	end
end

local function updateWallGui(plotState)
	if not plotState.wall then return end -- the gate has fallen: no wall left
	local pct = math.clamp(plotState.wallHP / plotState.WALL_MAX_HP, 0, 1)
	plotState.hpFill.Size = UDim2.new(pct, 0, 1, 0)
	plotState.hpFill.BackgroundColor3 = FILL_LOW:Lerp(FILL_FULL, pct)
	plotState.hpText.Text = compact(plotState.wallHP) .. " / " .. compact(plotState.WALL_MAX_HP)
	setWallStage(plotState.wall, pct <= 0.25 and 3 or pct <= 0.5 and 2 or pct <= 0.75 and 1 or 0)
	if plotState.layerLbl then
		plotState.layerLbl.Text = layerText(plotState.wallLayer)
	end
end

-- The wall's health bar (a billboard above the front wall): a "LAYER n" title and a stone-framed bar with a worn
-- bronze rim, a glossy blood-red fill and the HP numbers. Matches the client Theme (dark gothic); built here on the server
-- because the billboard belongs to the wall part.
local BAR_STONE = Color3.fromRGB(22, 25, 28)
local BAR_RIM = Color3.fromRGB(122, 110, 84)
local BAR_BONE = Color3.fromRGB(222, 214, 190)

local function buildWallGui(wallPart, plotState)
	local gui = Instance.new("BillboardGui", wallPart)
	gui.Size = UDim2.new(0, 320, 0, 74)
	gui.StudsOffset = Vector3.new(0, wallPart:FindFirstChild("WallModel") and 14 + WALL_MODEL_GUI_LIFT or 14, 0)
	gui.AlwaysOnTop = true

	local layerLbl = Instance.new("TextLabel", gui)
	layerLbl.Size = UDim2.new(1, 0, 0, 30)
	layerLbl.BackgroundTransparency = 1
	layerLbl.Text = "LAYER 1"
	layerLbl.TextColor3 = BAR_BONE
	layerLbl.TextSize = 26
	layerLbl.Font = Enum.Font.FredokaOne
	layerLbl.TextStrokeColor3 = Color3.fromRGB(8, 10, 12)
	layerLbl.TextStrokeTransparency = 0
	plotState.layerLbl = layerLbl

	-- stone frame with a bronze rim
	local frame = Instance.new("Frame", gui)
	frame.Size = UDim2.new(1, 0, 0, 34)
	frame.Position = UDim2.new(0, 0, 0, 36)
	frame.BackgroundColor3 = BAR_STONE
	frame.BorderSizePixel = 0
	Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 5)
	local rim = Instance.new("UIStroke", frame)
	rim.Color = BAR_RIM
	rim.Thickness = 3
	rim.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

	-- the track the fill slides in (inset from the rim)
	local track = Instance.new("Frame", frame)
	track.Size = UDim2.new(1, -8, 1, -8)
	track.Position = UDim2.new(0, 4, 0, 4)
	track.BackgroundColor3 = Color3.fromRGB(8, 10, 12)
	track.BorderSizePixel = 0
	track.ClipsDescendants = true
	Instance.new("UICorner", track).CornerRadius = UDim.new(0, 3)

	plotState.hpFill = Instance.new("Frame", track)
	plotState.hpFill.Size = UDim2.new(1, 0, 1, 0)
	plotState.hpFill.BackgroundColor3 = FILL_FULL
	plotState.hpFill.BorderSizePixel = 0
	Instance.new("UICorner", plotState.hpFill).CornerRadius = UDim.new(0, 3)
	local shade = Instance.new("UIGradient", plotState.hpFill) -- lighter on top, darker at the bottom: a rounded, glossy fill
	shade.Rotation = 90
	shade.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(150, 150, 150))
	local gloss = Instance.new("Frame", plotState.hpFill) -- a thin highlight along the top edge
	gloss.Size = UDim2.new(1, 0, 0.32, 0)
	gloss.BackgroundColor3 = Color3.new(1, 1, 1)
	gloss.BackgroundTransparency = 0.82
	gloss.BorderSizePixel = 0

	plotState.hpText = Instance.new("TextLabel", frame)
	plotState.hpText.Size = UDim2.new(1, 0, 1, 0)
	plotState.hpText.BackgroundTransparency = 1
	plotState.hpText.TextColor3 = Color3.fromRGB(255, 244, 232)
	plotState.hpText.TextSize = 18
	plotState.hpText.Font = Enum.Font.FredokaOne
	plotState.hpText.TextStrokeColor3 = Color3.fromRGB(20, 6, 6)
	plotState.hpText.TextStrokeTransparency = 0
	plotState.hpText.ZIndex = 3
end

local WALL_MATERIALS = {
	Enum.Material.Cobblestone, Enum.Material.Brick,  Enum.Material.Concrete, Enum.Material.Granite,
	Enum.Material.Slate,       Enum.Material.Basalt, Enum.Material.Limestone,
}

-- ── Walls ─────────────────────────────────────────────────────
-- All walls of a run stand in the lane from the start, WALL_SPACING apart. plotState.wallQueue[layer] is the wall of that
-- layer. The army fights the wall of plotState.wallLayer; when it breaks the army marches on to the next one
-- (plotState.wallFwd / wallTargetFwd / wallFaceFwd follow the front wall, Army reads them every frame).
local function wallFwdOf(layer)
	return WALL_FWD + (layer - 1) * WALL_SPACING
end

local function wallHeight(layer)
	return Economy.isGate(layer) and GATE_HEIGHT or WALL_HEIGHT
end

-- Moves the "front" (where the army fights) to the wall of `layer`
local function setFront(plotState, layer)
	plotState.wallFwd = wallFwdOf(layer)
	plotState.wallTargetFwd = plotState.wallFwd - (WALL_THICKNESS / 2 + 3)
	plotState.wallFaceFwd = plotState.wallFwd - WALL_THICKNESS / 2
	plotState.wallTarget = PlotFrame.toWorld(plotState, 0, plotState.wallTargetFwd)
end

local function spawnWall(layer, plotState)
	local height = wallHeight(layer)
	local gate = Economy.isGate(layer)
	local wallPart = Instance.new("Part")
	wallPart.Name = "PreviewWall_" .. plotState.plotIndex
	wallPart.Size = Vector3.new(WALL_WIDTH, height, gate and WALL_THICKNESS + 2 or WALL_THICKNESS)
	wallPart.CFrame = CFrame.new(PlotFrame.toWorld(plotState, 0, wallFwdOf(layer)) + Vector3.new(0, height / 2, 0))
		* PlotFrame.rotation(plotState)
	wallPart.Anchored = true
	wallPart.Color = gate and GATE_COLOR or LAYER_COLORS[((layer - 1) % #LAYER_COLORS) + 1]
	wallPart.Material = gate and Enum.Material.Brick or WALL_MATERIALS[(layer % #WALL_MATERIALS) + 1]
	local template = wallModelFor(layer)
	if template then
		wallPart.Transparency = 1
		local m = template:Clone()
		m.Name = "WallModel"
		m:SetAttribute("Stage", 0)
		-- the model's front (-Z) faces back up the lane, towards the army
		m:PivotTo(CFrame.new(PlotFrame.toWorld(plotState, 0, wallFwdOf(layer))) * PlotFrame.rotation(plotState) * CFrame.Angles(0, math.pi, 0))
		for _, d in ipairs(m:GetDescendants()) do
			if d:IsA("BasePart") and d.CanCollide then
				d.CollisionGroup = Collision.DECOR -- the earth bank: players stand on it, units ignore its ledge
			end
		end
		CollectionService:AddTag(m, "StagedWall")
		m.Parent = wallPart
		height += WALL_MODEL_GUI_LIFT
	end
	wallPart.Parent = workspace

	-- small "Wall N" tag above the wall (sized in studs, so it shrinks with distance); only the gate is visible from afar
	local gui = Instance.new("BillboardGui", wallPart)
	gui.Name = "PreviewGui"
	gui.Size = UDim2.new(12, 0, 3, 0)
	gui.StudsOffset = Vector3.new(0, (template and height - WALL_MODEL_GUI_LIFT or height) / 2 + 3 + (template and WALL_MODEL_GUI_LIFT or 0), 0)
	gui.AlwaysOnTop = false
	gui.MaxDistance = gate and 400 or 60
	local lbl = Instance.new("TextLabel", gui)
	lbl.Size = UDim2.new(1, 0, 1, 0)
	lbl.BackgroundTransparency = 1
	lbl.Text = gate and "THE GATE" or ("Wall " .. layer)
	lbl.TextColor3 = gate and Color3.fromRGB(255, 214, 120) or Color3.fromRGB(215, 205, 235)
	lbl.TextStrokeTransparency = 0.5
	lbl.TextScaled = true
	lbl.Font = Enum.Font.GothamBold
	return wallPart
end

-- Makes the wall of `layer` the one being fought (HP bar on it, the army's front moves to it)
local function activateWall(plotState, layer)
	local wallPart = plotState.wallQueue[layer]
	wallPart.Name = "TheWall_" .. plotState.plotIndex
	local previewGui = wallPart:FindFirstChild("PreviewGui")
	if previewGui then previewGui:Destroy() end
	buildWallGui(wallPart, plotState)
	plotState.wall = wallPart
	setFront(plotState, layer)
end

-- Spawns the lane ground + every wall of the run, activates the first one
local function initWallQueue(plotState)
	-- the whole lane from the plot's Base to the gate tower of the outer ring (radius 392)
	local groundLen = LANE_END_FWD - LANE_START_FWD
	local groundCentreFwd = LANE_START_FWD + groundLen / 2
	local initGround = Instance.new("Part")
	initGround.Name = "GroundExt"
	initGround.Size = Vector3.new(WALL_WIDTH, 2, groundLen)
	initGround.CFrame = CFrame.new(PlotFrame.toWorld(plotState, 0, groundCentreFwd) - Vector3.new(0, 1, 0))
		* PlotFrame.rotation(plotState)
	initGround.Anchored = true
	initGround.Color = LANE_COLOR
	initGround.Material = Enum.Material.Cobblestone
	initGround.TopSurface = Enum.SurfaceType.Smooth
	initGround.Parent = workspace
	table.insert(plotState.groundExtensions, initGround)

	-- low stone walls along both sides of the lane (so nobody falls into the water), with a lighter cap
	for _, side in ipairs({ -1, 1 }) do
		local centre = PlotFrame.toWorld(plotState, side * (WALL_WIDTH / 2 + 0.4), groundCentreFwd)
		local rot = PlotFrame.rotation(plotState)
		local sideWall = Instance.new("Part")
		sideWall.Name = "LaneWall"
		sideWall.Size = Vector3.new(0.8, 1.4, groundLen)
		sideWall.CFrame = CFrame.new(centre + Vector3.new(0, 0.7, 0)) * rot
		sideWall.Anchored = true
		sideWall.Color = LANE_WALL_COLOR
		sideWall.Material = Enum.Material.Cobblestone
		sideWall.Parent = workspace
		table.insert(plotState.groundExtensions, sideWall)
		local cap = Instance.new("Part")
		cap.Name = "LaneWallCap"
		cap.Size = Vector3.new(1.1, 0.25, groundLen)
		cap.CFrame = CFrame.new(centre + Vector3.new(0, 1.52, 0)) * rot
		cap.Anchored = true
		cap.Color = LANE_CAP_COLOR
		cap.Material = Enum.Material.Slate
		cap.Parent = workspace
		table.insert(plotState.groundExtensions, cap)
	end

	plotState.wallQueue = {}
	for layer = 1, NUM_WALLS do
		plotState.wallQueue[layer] = spawnWall(layer, plotState)
	end
	activateWall(plotState, 1)
	updateWallGui(plotState)
end

-- A broken wall flashes, fades out and throws a few chunks of itself away from the units
local function crumbleWall(wall, plotState)
	local frame = plotState.frame
	local m = wall:FindFirstChild("WallModel")
	if m then
		-- the clients bring it down (Modules/WallStages, stage 4); the collider stops blocking right away
		m:SetAttribute("Stage", 4)
		wall.CanCollide = false
		local gui = wall:FindFirstChildOfClass("BillboardGui")
		if gui then gui:Destroy() end
		Debris:AddItem(wall, 3)
		return
	end
	for _ = 1, 10 do
		local size = math.random(10, 30) / 10
		local chunk = Instance.new("Part")
		chunk.Size = Vector3.new(size, size, size)
		chunk.Position = wall.Position + frame.RightVector * math.random(-16, 16) + Vector3.new(0, math.random(-6, 6), 0)
		chunk.Color = wall.Color
		chunk.Material = wall.Material
		chunk.CollisionGroup = Collision.DEBRIS
		chunk.AssemblyLinearVelocity = frame.LookVector * math.random(6, 18)
			+ frame.RightVector * math.random(-8, 8)
			+ Vector3.new(0, math.random(8, 22), 0)
		chunk.AssemblyAngularVelocity = Vector3.new(math.random(-8, 8), math.random(-8, 8), math.random(-8, 8))
		chunk.Parent = workspace
		Debris:AddItem(chunk, 3)
	end
	wall.BrickColor = BrickColor.new("White")
	local gui = wall:FindFirstChildOfClass("BillboardGui")
	if gui then gui:Destroy() end
	TweenService:Create(wall, TweenInfo.new(0.3), { Transparency = 1 }):Play()
	Debris:AddItem(wall, 0.4)
end

-- Ascensions of the plot's owner (the wall's HP and gold depend on them)
local function ownerRebirths(plotState)
	for _, p in ipairs(Players:GetPlayers()) do
		if tostring(p.UserId) == plotState.ownerId then
			local profile = PlayerData.get(p)
			return profile and profile.rebirthCount or 0
		end
	end
	return 0
end

local function breakWall(plotState)
	if plotState.wallLayer > NUM_WALLS then return end -- the gate already fell (late arrows, last barrage hits)
	local brokenLayer = plotState.wallLayer
	local brokenFaceFwd = plotState.wallFaceFwd -- where the loot bursts out
	plotState.wallLayer += 1
	crumbleWall(plotState.wallQueue[brokenLayer], plotState)

	if plotState.wallLayer <= NUM_WALLS then
		-- the army marches on to the next wall
		plotState.WALL_MAX_HP = Economy.wallHp(plotState.wallLayer, ownerRebirths(plotState))
		plotState.wallHP = plotState.WALL_MAX_HP
		plotState.wallRegen = plotState.wallLayer * 2
		activateWall(plotState, plotState.wallLayer)
		updateWallGui(plotState)
	else
		-- that was the gate: nothing left to fight until the player ascends
		plotState.wall = nil
		plotState.wallHP = 0
	end

	local goldReward = Economy.wallGold(brokenLayer, ownerRebirths(plotState))
	for _, p in ipairs(Players:GetPlayers()) do
		if tostring(p.UserId) == plotState.ownerId then
			local profile = PlayerData.get(p)
			if profile then
				local mult = Economy.wallGoldMultiplier(profile.rebirthCount, profile.upgrades.coinBoost)
				-- the wall bursts into gold coins and dust crystals that lie on the lane until they are collected
				-- (boss walls and the gate drop better dust), see Drops
				Drops.spawnWallDrops(p, plotState, math.floor(goldReward * mult), Economy.wallMaterials(brokenLayer, profile.rebirthCount), brokenFaceFwd)
				Drops.wallBroken(p)
			end
			Remotes.WallBreak:FireClient(p, goldReward, plotState.wallLayer - 1)
			if Economy.isGate(brokenLayer) then
				PlayerData.setGateCleared(p, true)
				Remotes.Notice:FireClient(p, "The gate has fallen! You can ascend now.")
			end
			incrementQuest(p, "breakWalls", 1)
			incrementQuest(p, "earnGold", goldReward)
			break
		end
	end
	print("🎉 Plot" .. plotState.plotIndex .. " wall " .. (plotState.wallLayer-1) .. " broken!")
end

local function resetWall(plotState)
	Drops.clearPlot(plotState)
	for _, w in pairs(plotState.wallQueue or {}) do
		if w and w.Parent then w:Destroy() end
	end
	plotState.wallQueue = {}
	plotState.wall = nil
	for _, ext in ipairs(plotState.groundExtensions) do
		if ext and ext.Parent then ext:Destroy() end
	end
	plotState.groundExtensions = {}
	plotState.wallLayer = 1
	plotState.WALL_MAX_HP = Economy.wallHp(1, ownerRebirths(plotState))
	plotState.wallHP = plotState.WALL_MAX_HP
	plotState.wallRegen = 1
	initWallQueue(plotState)
end

-- Once-a-second wall HP regeneration for one plot.
local function regen(plotState)
			if plotState.wallHP < plotState.WALL_MAX_HP then
				plotState.wallHP = math.min(plotState.wallHP + plotState.wallRegen, plotState.WALL_MAX_HP)
			end
			updateWallGui(plotState)
end

return {
	WALL_FWD = WALL_FWD,
	WALL_WIDTH = WALL_WIDTH,
	updateWallGui = updateWallGui,
	initWallQueue = initWallQueue,
	breakWall = breakWall,
	resetWall = resetWall,
	regen = regen,
}
