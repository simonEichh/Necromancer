-- Per-plot wall: HP bar, preview queue, breaking and reset.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Remotes = require(script.Parent.Remotes)
local Collision = require(script.Parent.Collision)
local PlotFrame = require(script.Parent.PlotFrame)
local Quests = require(script.Parent.Quests)
local PlayerData = require(script.Parent.PlayerData)
local Economy = require(game:GetService("ReplicatedStorage").Shared.Economy)

local incrementQuest = Quests.increment

local WALL_SPACING = 45      -- distance between queued walls
local NUM_WALLS = 5          -- walls in the queue (front wall + 4 behind it)
local WALL_WIDTH = 40        -- across the lane
local WALL_THICKNESS = 4
local WALL_HEIGHT = 20       -- front wall height
local WALL_HEIGHT_STEP = 5   -- each wall further back is this much taller
local SLIDE_TIME = 1.0       -- seconds for the queue to slide forward after a break

local LAYER_COLORS = {
	BrickColor.new("Medium stone grey"),
	BrickColor.new("Bright green"),
	BrickColor.new("Bright blue"),
	BrickColor.new("Bright violet"),
	BrickColor.new("Bright pink"),
}

local function updateWallGui(plotState)
	local pct = math.clamp(plotState.wallHP / plotState.WALL_MAX_HP, 0, 1)
	plotState.hpFill.Size = UDim2.new(pct, 0, 1, 0)
	plotState.hpFill.BackgroundColor3 = Color3.fromRGB(220, math.floor(60*pct), math.floor(60*pct))
	plotState.hpText.Text = "Layer " .. plotState.wallLayer .. "  " .. math.floor(plotState.wallHP) .. " / " .. plotState.WALL_MAX_HP
end

local function buildWallGui(wallPart, plotState)
	local gui = Instance.new("BillboardGui", wallPart)
	gui.Size = UDim2.new(0, 260, 0, 55)
	gui.StudsOffset = Vector3.new(0, 14, 0)
	gui.AlwaysOnTop = true
	local bg = Instance.new("Frame", gui)
	bg.Size = UDim2.new(1, 0, 0.5, 0)
	bg.Position = UDim2.new(0, 0, 0.1, 0)
	bg.BackgroundColor3 = Color3.fromRGB(60, 20, 20)
	bg.BorderSizePixel = 0
	Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 6)
	plotState.hpFill = Instance.new("Frame", bg)
	plotState.hpFill.Size = UDim2.new(1, 0, 1, 0)
	plotState.hpFill.BackgroundColor3 = Color3.fromRGB(220, 60, 60)
	plotState.hpFill.BorderSizePixel = 0
	Instance.new("UICorner", plotState.hpFill).CornerRadius = UDim.new(0, 6)
	plotState.hpText = Instance.new("TextLabel", gui)
	plotState.hpText.Size = UDim2.new(1, 0, 0.38, 0)
	plotState.hpText.Position = UDim2.new(0, 0, 0.62, 0)
	plotState.hpText.BackgroundTransparency = 1
	plotState.hpText.TextColor3 = Color3.fromRGB(255, 210, 210)
	plotState.hpText.TextScaled = true
	plotState.hpText.Font = Enum.Font.GothamBold
end

local WALL_MATERIALS = {
	Enum.Material.SmoothPlastic, Enum.Material.Brick,   Enum.Material.Cobblestone,
	Enum.Material.Concrete,      Enum.Material.Granite,  Enum.Material.Marble,
	Enum.Material.Sandstone,     Enum.Material.Slate,    Enum.Material.Wood,
	Enum.Material.WoodPlanks,    Enum.Material.Basalt,   Enum.Material.Limestone,
}

-- ── Wall queue ────────────────────────────────────────────────
-- The front wall always stays at the same spot (the plot's WallOrigin). Walls further back in the
-- queue stand behind it, getting taller like a skyline. Breaking the front wall crumbles it and
-- slides the whole queue one slot forward, so the fight never moves away from the hub.
local function wallHeight(slot)
	return WALL_HEIGHT + (slot - 1) * WALL_HEIGHT_STEP
end

-- World CFrame of a queue slot: centred across the lane, wallFwd + (slot-1)*spacing along it,
-- oriented like the plot (part X = across the lane, Z = along it)
local function slotCFrame(plotState, slot)
	local pos = PlotFrame.toWorld(plotState, 0, plotState.wallFwd + (slot - 1) * WALL_SPACING)
		+ Vector3.new(0, wallHeight(slot) / 2, 0)
	return CFrame.new(pos) * PlotFrame.rotation(plotState)
end

-- Spawns a preview wall at a queue slot (slot may be one past the end: the wall slides in from there)
local function spawnPreviewWall(slot, layerNum, plotState, invisible)
	local height = wallHeight(math.min(slot, NUM_WALLS))
	local wallPart = Instance.new("Part")
	wallPart.Name = "PreviewWall_" .. plotState.plotIndex
	wallPart.Size = Vector3.new(WALL_WIDTH, height, WALL_THICKNESS)
	wallPart.CFrame = slotCFrame(plotState, slot)
	wallPart.Anchored = true
	wallPart.BrickColor = BrickColor.new("Dark stone grey")
	wallPart.Transparency = invisible and 1 or 0
	wallPart.Material = WALL_MATERIALS[math.random(#WALL_MATERIALS)]
	wallPart.Parent = workspace

	-- small "Layer N" tag above the wall (sized in studs, so it shrinks with distance)
	local gui = Instance.new("BillboardGui", wallPart)
	gui.Name = "PreviewGui"
	gui.Size = UDim2.new(12, 0, 3, 0)
	gui.StudsOffset = Vector3.new(0, height / 2 + 3, 0)
	gui.AlwaysOnTop = false
	gui.MaxDistance = 400
	local lbl = Instance.new("TextLabel", gui)
	lbl.Size = UDim2.new(1, 0, 1, 0)
	lbl.BackgroundTransparency = 1
	lbl.Text = "Layer " .. layerNum
	lbl.TextColor3 = Color3.fromRGB(215, 205, 235)
	lbl.TextStrokeTransparency = 0.5
	lbl.TextScaled = true
	lbl.Font = Enum.Font.GothamBold
	return wallPart
end

-- Promotes a wall to the active wall (full color + HP bar)
local function activateWall(wallPart, plotState)
	wallPart.Name = "TheWall_" .. plotState.plotIndex
	wallPart.BrickColor = LAYER_COLORS[((plotState.wallLayer - 1) % #LAYER_COLORS) + 1]
	local previewGui = wallPart:FindFirstChild("PreviewGui")
	if previewGui then previewGui:Destroy() end
	buildWallGui(wallPart, plotState)
end

-- Spawns the lane ground + the wall queue, activates the first wall
local function initWallQueue(plotState)
	-- lane long enough for every queued wall (plus the slot a new wall slides in from)
	local groundLen = (NUM_WALLS + 1) * WALL_SPACING + 10
	local initGround = Instance.new("Part")
	initGround.Name = "GroundExt"
	initGround.Size = Vector3.new(WALL_WIDTH, 2, groundLen)
	initGround.CFrame = CFrame.new(PlotFrame.toWorld(plotState, 0, plotState.wallFwd + groundLen / 2) - Vector3.new(0, 1, 0))
		* PlotFrame.rotation(plotState)
	initGround.Anchored = true
	initGround.Color = Color3.fromRGB(165, 8, 8)
	initGround.Material = Enum.Material.Carpet
	initGround.TopSurface = Enum.SurfaceType.Smooth
	initGround.Parent = workspace
	table.insert(plotState.groundExtensions, initGround)

	plotState.wallQueue = {}
	plotState.wallTweens = {}
	for slot = 1, NUM_WALLS do
		table.insert(plotState.wallQueue, spawnPreviewWall(slot, plotState.wallLayer + slot - 1, plotState))
	end

	activateWall(plotState.wallQueue[1], plotState)
	plotState.wall = plotState.wallQueue[1]
	-- units walk to just in front of the fixed front slot (distances are "forward" along the lane)
	plotState.wallTargetFwd = plotState.wallFwd - (WALL_THICKNESS / 2 + 3)
	plotState.wallFaceFwd = plotState.wallFwd - WALL_THICKNESS / 2
	plotState.wallTarget = PlotFrame.toWorld(plotState, 0, plotState.wallTargetFwd)
	updateWallGui(plotState)
end

-- Slides every queued wall to its slot (cancelling any slide still in progress)
local function slideQueue(plotState)
	for _, tween in ipairs(plotState.wallTweens) do
		tween:Cancel()
	end
	plotState.wallTweens = {}
	local info = TweenInfo.new(SLIDE_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
	for slot, wall in ipairs(plotState.wallQueue) do
		local height = wallHeight(slot)
		local tween = TweenService:Create(wall, info, {
			CFrame = slotCFrame(plotState, slot),
			Size = Vector3.new(WALL_WIDTH, height, WALL_THICKNESS),
			Transparency = 0,
		})
		tween:Play()
		table.insert(plotState.wallTweens, tween)
		local previewGui = wall:FindFirstChild("PreviewGui")
		if previewGui then
			previewGui.StudsOffset = Vector3.new(0, height / 2 + 3, 0)
		end
	end
end

-- A broken wall flashes, fades out and throws a few chunks of itself away from the units
local function crumbleWall(wall, plotState)
	local frame = plotState.frame
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

local function breakWall(plotState)
	plotState.wallLayer += 1
	plotState.WALL_MAX_HP = math.floor(500 * (2 ^ (plotState.wallLayer - 1)))
	plotState.wallHP = plotState.WALL_MAX_HP
	plotState.wallRegen = plotState.wallLayer * 2

	-- Crumble the front wall, queue a new wall at the far end (it fades in while sliding)
	crumbleWall(table.remove(plotState.wallQueue, 1), plotState)
	local newLayer = plotState.wallLayer + NUM_WALLS - 1
	table.insert(plotState.wallQueue, spawnPreviewWall(NUM_WALLS + 1, newLayer, plotState, true))

	-- The next wall slides up to the front; it is the active wall straight away
	activateWall(plotState.wallQueue[1], plotState)
	plotState.wall = plotState.wallQueue[1]
	slideQueue(plotState)
	updateWallGui(plotState)

	local goldReward = math.floor(1000 * plotState.wallLayer * plotState.goldMultiplier)
	for _, p in ipairs(Players:GetPlayers()) do
		if tostring(p.UserId) == plotState.ownerId then
			local profile = PlayerData.get(p)
			if profile then
				local mult = Economy.wallGoldMultiplier(profile.rebirthCount, profile.upgrades.coinBoost)
				PlayerData.addGold(p, math.floor(goldReward * mult))
			end
			Remotes.WallBreak:FireClient(p, goldReward, plotState.wallLayer - 1)
			incrementQuest(p, "breakWalls", 1)
			incrementQuest(p, "earnGold", goldReward)
			break
		end
	end
	print("🎉 Plot" .. plotState.plotIndex .. " wall " .. (plotState.wallLayer-1) .. " broken!")
end

local function resetWall(plotState)
	for _, w in ipairs(plotState.wallQueue or {}) do
		if w and w.Parent then w:Destroy() end
	end
	plotState.wallQueue = {}
	for _, ext in ipairs(plotState.groundExtensions) do
		if ext and ext.Parent then ext:Destroy() end
	end
	plotState.groundExtensions = {}
	plotState.wallLayer = 1
	plotState.WALL_MAX_HP = 500
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
	updateWallGui = updateWallGui,
	initWallQueue = initWallQueue,
	breakWall = breakWall,
	resetWall = resetWall,
	regen = regen,
}
