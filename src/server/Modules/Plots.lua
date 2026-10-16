-- Plot claiming/assignment, physical grave slots, ascension.
local ServerStorage = game:GetService("ServerStorage")
local Economy = require(game:GetService("ReplicatedStorage").Shared.Economy)
local Remotes = require(script.Parent.Remotes)
local PlayerData = require(script.Parent.PlayerData)
local Army = require(script.Parent.Army)
local Walls = require(script.Parent.Walls)
local Collision = require(script.Parent.Collision)
local PlotFrame = require(script.Parent.PlotFrame)
local PlotRegistry = require(script.Parent.PlotRegistry)
local Titans = require(script.Parent.Titans)
local Portal = require(script.Parent.Portal)
local PlotLook = require(script.Parent.PlotLook)
local GraveRune = require(script.Parent.GraveRune)
local GemShop = require(script.Parent.GemShop)

local playerPlots = PlotRegistry.playerPlots
local getPlot = PlotRegistry.getPlot
local recallUnitFromSlot = Army.recallUnitFromSlot
local initWallQueue = Walls.initWallQueue
local resetWall = Walls.resetWall

local plotsFolder = workspace:WaitForChild("Plots", 10)
local plotOccupied = {} -- [1..8] = true/false
local initPlotForPlayer -- forward declared; defined below

Remotes.GetWallPos.OnServerInvoke = function(player)
	local plotState = getPlot(player)
	if plotState then
		-- a spot 12 studs in front of the wall being fought (the front advances as walls break), facing the wall
		local pos = PlotFrame.toWorld(plotState, 0, plotState.wallFwd - 12)
		return CFrame.lookAt(pos, pos + PlotFrame.forwardFlat(plotState))
	end
	return nil
end

local function claimPlot()
	if not plotsFolder then return nil, nil end
	for i = 1, 8 do
		if not plotOccupied[i] then
			local model = plotsFolder:FindFirstChild("Plot" .. i)
			if model then
				plotOccupied[i] = true
				return model, i
			end
		end
	end
	return nil, nil
end

local modelsFolder = ServerStorage:FindFirstChild("Models")
local tombstoneTemplate = modelsFolder and modelsFolder:FindFirstChild("Tombstone")

local function addGraveSlot(i, basePos, plotState, ownerId)
	local slab, graveModel

	if tombstoneTemplate and tombstoneTemplate:IsA("Model") then
		graveModel = tombstoneTemplate:Clone()
		for _, p in ipairs(graveModel:GetDescendants()) do
			if p:IsA("BasePart") then
				p.Anchored = true
				p.CollisionGroup = Collision.GRAVES
			end
		end
		graveModel.Parent = workspace
		-- the tombstone model faces +X; the graves stand in two rows along the plot's sides (tools/studio/layout_graves.lua)
		-- and face the free path down the middle
		local lateral = PlotFrame.toLocal(plotState, basePos)
		graveModel:PivotTo(CFrame.new(basePos) * PlotFrame.rotation(plotState) * CFrame.Angles(0, lateral > 0 and math.pi or 0, 0))
		slab = graveModel.PrimaryPart or graveModel:FindFirstChildWhichIsA("BasePart")
	else
		-- Fallback: plain parts
		slab = Instance.new("Part")
		slab.Name = "GraveSlot_" .. i
		slab.Size = Vector3.new(2.5, 0.5, 2.5)
		slab.Position = basePos + Vector3.new(0, 0.25, 0)
		slab.Anchored = true
		slab.BrickColor = BrickColor.new("Dark stone grey")
		slab.Material = Enum.Material.SmoothPlastic
		slab.TopSurface = Enum.SurfaceType.Smooth
		slab.CollisionGroup = Collision.GRAVES
		slab.Parent = workspace

		local stone = Instance.new("Part")
		stone.Name = "GraveHeadstone_" .. i
		stone.Size = Vector3.new(1.8, 2.8, 0.5)
		stone.Position = basePos + Vector3.new(0, 1.9, 0) + plotState.frame.LookVector * 0.9
		stone.Anchored = true
		stone.BrickColor = BrickColor.new("Medium stone grey")
		stone.Material = Enum.Material.SmoothPlastic
		stone.CollisionGroup = Collision.GRAVES
		stone.Parent = workspace
		graveModel = stone
	end

	local gui = Instance.new("BillboardGui", slab)
	gui.Size = UDim2.new(0, 150, 0, 68)
	gui.StudsOffset = Vector3.new(0, 5.5, 0)
	gui.AlwaysOnTop = true
	local lbl = Instance.new("TextLabel", gui)
	lbl.Size = UDim2.new(1, 0, 0.38, 0)
	lbl.Position = UDim2.new(0, 0, 0, 0)
	lbl.BackgroundTransparency = 1
	lbl.Text = "" -- (an empty grave shows no text: its rune is dark, GraveRune)
	lbl.TextColor3 = Color3.fromRGB(160, 200, 160)
	lbl.TextScaled = true
	lbl.Font = Enum.Font.GothamBold
	local rarityLbl = Instance.new("TextLabel", gui)
	rarityLbl.Name = "RarityLabel"
	rarityLbl.Size = UDim2.new(1, 0, 0.31, 0)
	rarityLbl.Position = UDim2.new(0, 0, 0.38, 0)
	rarityLbl.BackgroundTransparency = 1
	rarityLbl.Text = ""
	rarityLbl.TextColor3 = Color3.fromRGB(200, 200, 200)
	rarityLbl.TextScaled = true
	rarityLbl.Font = Enum.Font.Gotham
	local dpsLbl = Instance.new("TextLabel", gui)
	dpsLbl.Name = "DpsLabel"
	dpsLbl.Size = UDim2.new(1, 0, 0.31, 0)
	dpsLbl.Position = UDim2.new(0, 0, 0.69, 0)
	dpsLbl.BackgroundTransparency = 1
	dpsLbl.Text = ""
	dpsLbl.TextColor3 = Color3.fromRGB(100, 255, 130)
	dpsLbl.TextScaled = true
	dpsLbl.Font = Enum.Font.GothamBold

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Place Unit"
	prompt.ObjectText = "Grave " .. i
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.Parent = slab

	-- (the Army screen finds the grave under the mouse by this)
	for _, inst in ipairs({ slab, graveModel }) do
		inst:SetAttribute("GraveSlot", i)
		inst:SetAttribute("OwnerId", tonumber(ownerId))
	end
	plotState.graveSlots[i] = {
		slab = slab, stone = graveModel, label = lbl,
		rarityLabel = rarityLbl, dpsLabel = dpsLbl,
		prompt = prompt, occupied = false,
	}
	GraveRune.attach(plotState.graveSlots[i])

	local idx = i
	local spawnPoint = basePos + Vector3.new(0, 2, 0)
	prompt.Triggered:Connect(function(player)
		if tostring(player.UserId) ~= ownerId then return end
		if plotState.graveSlots[idx].occupied then
			recallUnitFromSlot(idx, player, plotState)
		else
			Remotes.SelectGrave:FireClient(player, spawnPoint, idx)
		end
	end)
end

-- ============================================================
-- The commander thrones (Design.md "the commander slot"): at the head of the graves, where the lane begins, a raised
-- round dais with a gold rim and an ornate tombstone; only Signatures and Sovereigns stand here (Army.getSlot, slot
-- index Army.COMMANDER_BASE + k). The first is open for everyone; the second stands sealed (dark, no tombstone, "Unlock
-- Throne") until it is bought with gems (GemShop "CommanderSlot").
-- ============================================================
local THRONE_FWD = 19
local THRONE_LAT = { -4.8, 4.8 }
local THRONE_STONE = Color3.fromRGB(40, 37, 44)
local THRONE_TOP = Color3.fromRGB(58, 54, 62)
local THRONE_GOLD = Color3.fromRGB(226, 186, 92)
local THRONE_SEALED = Color3.fromRGB(70, 66, 76)

local function buildThrone(k, plotState, ownerId, sealed)
	local old = plotState.commanderSlots[k]
	if old and old.model then
		old.model:Destroy()
	end
	local floor = PlotFrame.toWorld(plotState, THRONE_LAT[k], THRONE_FWD)
	local facePlaza = PlotFrame.rotation(plotState) * CFrame.Angles(0, -math.pi / 2, 0) -- (the tombstone model faces +X)
	local model = Instance.new("Model")
	model.Name = "CommanderThrone_" .. k
	local function part(name, size, cf, color, material, shape)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = cf
		p.Color = color
		p.Material = material or Enum.Material.Slate
		if shape then p.Shape = shape end
		p.Anchored = true
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.CollisionGroup = Collision.GRAVES
		p.Parent = model
		return p
	end
	local up = CFrame.Angles(0, 0, math.pi / 2) -- (a cylinder's axis up)
	part("Dais", Vector3.new(1, 7.5, 7.5), CFrame.new(floor + Vector3.new(0, 0.5, 0)) * up, THRONE_STONE, nil, Enum.PartType.Cylinder)
	local rim = part("DaisRim", Vector3.new(0.14, 7.8, 7.8), CFrame.new(floor + Vector3.new(0, 0.98, 0)) * up, sealed and THRONE_SEALED or THRONE_GOLD,
		sealed and Enum.Material.Slate or Enum.Material.Neon, Enum.PartType.Cylinder)
	local top = part("DaisTop", Vector3.new(0.3, 6.6, 6.6), CFrame.new(floor + Vector3.new(0, 1.1, 0)) * up, THRONE_TOP, nil, Enum.PartType.Cylinder)
	if not sealed then
		local light = Instance.new("PointLight")
		light.Color = THRONE_GOLD
		light.Range = 14
		light.Brightness = 0.8
		light.Shadows = false
		light.Parent = rim
	end
	local stone
	if not sealed and tombstoneTemplate then
		stone = tombstoneTemplate:Clone()
		for _, p in ipairs(stone:GetDescendants()) do
			if p:IsA("BasePart") then
				p.Anchored = true
				p.CollisionGroup = Collision.GRAVES
			end
		end
		stone:ScaleTo(1.25)
		stone.Parent = model
		-- at the back of the dais (towards the lane), facing the plaza
		stone:PivotTo(CFrame.new(floor + Vector3.new(0, 1.25, 0) + plotState.frame.LookVector * 1.6) * facePlaza)
	end
	model:SetAttribute("GraveSlot", Army.COMMANDER_BASE + k) -- (the Army screen finds the throne under the mouse by this)
	model:SetAttribute("Sealed", sealed == true)
	model:SetAttribute("OwnerId", tonumber(ownerId))
	model.Parent = workspace

	local gui = Instance.new("BillboardGui", top)
	gui.Size = UDim2.new(0, 160, 0, 72)
	gui.StudsOffset = Vector3.new(0, 7, 0)
	gui.AlwaysOnTop = true
	local function label(name, y, h, font, color)
		local l = Instance.new("TextLabel", gui)
		l.Name = name
		l.Size = UDim2.new(1, 0, h, 0)
		l.Position = UDim2.new(0, 0, y, 0)
		l.BackgroundTransparency = 1
		l.Text = ""
		l.TextColor3 = color
		l.TextScaled = true
		l.Font = font
		return l
	end
	local lbl = label("Title", 0, 0.38, Enum.Font.GothamBold, THRONE_GOLD)
	local rarityLbl = label("RarityLabel", 0.38, 0.31, Enum.Font.Gotham, Color3.fromRGB(200, 200, 200))
	local dpsLbl = label("DpsLabel", 0.69, 0.31, Enum.Font.GothamBold, Color3.fromRGB(100, 255, 130))

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = sealed and "Unlock Throne" or "Place Commander"
	prompt.ObjectText = sealed and (Economy.COMMANDER_SLOT_PRICE .. " Gems") or "Commander Throne"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt.Parent = top

	local slot = {
		slab = top, stone = stone, label = lbl, rarityLabel = rarityLbl, dpsLabel = dpsLbl, prompt = prompt,
		occupied = false, commander = true, sealed = sealed or nil, model = model,
		spawnPos = floor + Vector3.new(0, 3.2, 0),
	}
	plotState.commanderSlots[k] = slot
	if stone then
		GraveRune.attach(slot)
	end
	local index = Army.COMMANDER_BASE + k
	prompt.Triggered:Connect(function(player)
		if tostring(player.UserId) ~= ownerId then return end
		if slot.sealed then
			GemShop.buy(player, "CommanderSlot")
		elseif slot.occupied then
			recallUnitFromSlot(index, player, plotState)
		else
			Remotes.SelectGrave:FireClient(player, slot.spawnPos, index)
		end
	end)
end

-- the thrones for a player's plot: as many open as they own (PlayerData commanderSlots), the rest sealed
local function buildThrones(plotState, player)
	local profile = PlayerData.get(player)
	local owned = profile and profile.commanderSlots or 1
	for k = 1, Economy.MAX_COMMANDER_SLOTS do
		local slot = plotState.commanderSlots[k]
		local sealed = k > owned
		if not slot or (slot.sealed and not sealed) then
			buildThrone(k, plotState, tostring(player.UserId), sealed)
		end
	end
end
-- (GemShop: the second throne was bought: unseal it)
PlayerData.onCommanderSlots = function(player)
	local plotState = getPlot(player)
	if plotState then
		buildThrones(plotState, player)
	end
end

initPlotForPlayer = function(player)
	local plotModel, plotIndex = claimPlot()
	if not plotModel then
		warn("No plots available for " .. player.Name)
		return
	end
	local basePart       = plotModel:FindFirstChild("Base")
	local spawnPart2     = plotModel:FindFirstChild("PlayerSpawn")
	if not basePart then
		warn("Plot" .. plotIndex .. " missing Base")
		plotOccupied[plotIndex] = false
		return
	end
	-- The plot frame: floor-level centre of the Base, LookVector = lane direction (the Base part's
	-- local -Z points down the lane, towards the walls). The front wall stands Walls.WALL_FWD studs down the lane
	-- (the plot's WallOrigin part in the place file is no longer used).
	local frame = basePart.CFrame * CFrame.new(0, basePart.Size.Y / 2, 0)
	local startProfile = PlayerData.get(player)
	local startHp = Economy.wallHp(1, startProfile and startProfile.rebirthCount or 0)
	local plotState = {
		plotModel        = plotModel,
		plotIndex        = plotIndex,
		ownerId          = tostring(player.UserId),
		frame            = frame,
		wallFwd          = Walls.WALL_FWD,
		plotGroundY      = frame.Position.Y,
		wall             = nil,
		wallQueue        = {},
		wallHP           = startHp,
		wallLayer        = 1,
		WALL_MAX_HP      = startHp,
		wallRegen        = 1,
		goldMultiplier   = 1.0,
		hpFill           = nil,
		hpText           = nil,
		wallTarget       = Vector3.new(0, 0, 0),
		wallTargetFwd    = 0,
		wallFaceFwd      = 0,
		graveSlots       = {},
		commanderSlots   = {}, -- the commander thrones (buildThrones; Army.getSlot index 101, 102)
		activeUnits      = {},
		groundExtensions = {},
	}
	initWallQueue(plotState)
	Titans.spawn(plotState) -- the realm's titan behind the lane
	PlotLook.apply(plotState) -- the plot becomes part of the realm (cemetery ground, walls, gate)
	-- 5 grave slots to start, +1 per ascension (max 10)
	local profile = PlayerData.get(player)
	local slotCount = math.min(10, 5 + (profile and profile.rebirthCount or 0))
	for i = 1, slotCount do
		local graveSpot = plotModel:FindFirstChild("GraveSpot" .. i)
		if graveSpot then
			addGraveSlot(i, graveSpot.Position, plotState, tostring(player.UserId))
		end
	end
	buildThrones(plotState, player)
	playerPlots[tostring(player.UserId)] = plotState
	plotModel:SetAttribute("OwnerId", player.UserId) -- (the client finds its own plot by this: the ascension cinematic)
	Portal.open(plotState, player, true) -- the run's portal stands sealed behind the gate
	-- players join on the plaza, facing their plot (the titan climbs up when they first step onto it, see Titans)
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if hrp then
		local hub = workspace:GetAttribute("HubSpawn") or Vector3.new(0, 3, 24)
		local toPlot = Vector3.new(frame.Position.X - hub.X, 0, frame.Position.Z - hub.Z)
		hrp.CFrame = CFrame.lookAt(hub, hub + (toPlot.Magnitude > 0.1 and toPlot.Unit or Vector3.new(0, 0, -1)))
	end
	print("✅ Assigned Plot" .. plotIndex .. " to " .. player.Name)
end

-- Ascends the player (the Ascend button, or walking through the open portal at a realm's last ascension)
-- mode "cinematic": the client's ascension cinematic (Modules/AscensionCinematic) is playing on the plot and moves the
-- character to the plaza itself when it ends, so the server does not teleport it
local function ascendPlayer(player, mode)
	local plotState = getPlot(player)
	if not plotState then return end
	if not PlayerData.ascend(player) then return end -- can't afford it
	local nextSlot = #plotState.graveSlots + 1
	if nextSlot <= 10 then
		local graveSpot = plotState.plotModel:FindFirstChild("GraveSpot" .. nextSlot)
		if graveSpot then
			addGraveSlot(nextSlot, graveSpot.Position, plotState, tostring(player.UserId))
		end
	end
	resetWall(plotState)
	Portal.open(plotState, player, true) -- (resetWall closed it: sealed again for the new run)
	Army.setDamageMultiplier(plotState)
	-- put the units back behind the graves (10 studs towards the plaza), in their own lanes
	local graveSpot1 = plotState.plotModel:FindFirstChild("GraveSpot1")
	local nearFwd = graveSpot1 and (select(2, PlotFrame.toLocal(plotState, graveSpot1.Position)) - 10)
		or (plotState.wallFwd - 60)
	local forward = PlotFrame.forwardFlat(plotState)
	for _, u in ipairs(plotState.activeUnits) do
		u.staticFwd = nil
		if u.block and u.block.Parent then
			if u.def.static then
				-- towers cannot walk: they rise again straight at their slot in front of the new first wall
				local pos = PlotFrame.toWorld(plotState, u.slotLat or 0, Army.standForward(plotState, u.def))
					+ Vector3.new(0, u.def.size.Y / 2 + 1, 0)
				u.block.CFrame = CFrame.lookAt(pos, pos + forward)
				if u.model then
					u.model:SetAttribute("RiseStart", workspace:GetServerTimeNow())
				end
			else
				local pos = PlotFrame.toWorld(plotState, u.lateral, nearFwd + math.random(-5, 5)) + Vector3.new(0, 7.7, 0)
				u.block.CFrame = CFrame.lookAt(pos, pos + forward)
			end
		end
	end
	-- the player goes back to the main plaza (the same spot the SHOPS button uses)
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if hrp and mode ~= "cinematic" then
		local hub = workspace:GetAttribute("HubSpawn") or Vector3.new(0, 3, 24)
		hrp.CFrame = CFrame.lookAt(hub, hub + Vector3.new(0, 0, -1))
	end
	print("⬆️ " .. player.Name .. " ascended — wall reset, graves: " .. #plotState.graveSlots)
end
Remotes.PlayerAscend.OnServerEvent:Connect(ascendPlayer)
Portal.onPass = ascendPlayer

-- Tears down a leaving player's plot objects and frees the plot.
local function releasePlot(player)
	local id = tostring(player.UserId)
	local plotState = playerPlots[id]
	if plotState then
		for _, w in pairs(plotState.wallQueue or {}) do
			if w and w.Parent then w:Destroy() end
		end
		for _, ext in ipairs(plotState.groundExtensions) do
			if ext and ext.Parent then ext:Destroy() end
		end
		Titans.remove(plotState)
		Portal.close(plotState)
		PlotLook.clear(plotState)
		for _, u in ipairs(plotState.activeUnits) do
			if u.block and u.block.Parent then u.block:Destroy() end
		end
		for _, slot in ipairs(plotState.graveSlots) do
			if slot.stone and slot.stone.Parent then slot.stone:Destroy() end
			if slot.slab and slot.slab.Parent then slot.slab:Destroy() end
		end
		for _, slot in pairs(plotState.commanderSlots or {}) do
			if slot.model and slot.model.Parent then slot.model:Destroy() end
		end
		plotOccupied[plotState.plotIndex] = false
		if plotState.plotModel then
			plotState.plotModel:SetAttribute("OwnerId", nil)
		end
		playerPlots[id] = nil
	end
end

return {
	initPlotForPlayer = initPlotForPlayer,
	releasePlot = releasePlot,
}
