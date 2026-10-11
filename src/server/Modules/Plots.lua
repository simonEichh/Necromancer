-- Plot claiming/assignment, physical grave slots, ascension.
local ServerStorage = game:GetService("ServerStorage")
local Remotes = require(script.Parent.Remotes)
local PlayerData = require(script.Parent.PlayerData)
local Army = require(script.Parent.Army)
local Walls = require(script.Parent.Walls)
local Collision = require(script.Parent.Collision)
local PlotFrame = require(script.Parent.PlotFrame)
local PlotRegistry = require(script.Parent.PlotRegistry)

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
		-- the front wall never moves; return a spot 12 studs in front of it, facing the wall
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
		-- the tombstone model faces +X; turn it to face away from the lane (towards the plaza)
		graveModel:PivotTo(CFrame.new(basePos) * PlotFrame.rotation(plotState) * CFrame.Angles(0, -math.pi / 2, 0))
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
	lbl.Text = "Empty"
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

	plotState.graveSlots[i] = {
		slab = slab, stone = graveModel, label = lbl,
		rarityLabel = rarityLbl, dpsLabel = dpsLbl,
		prompt = prompt, occupied = false,
	}

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

initPlotForPlayer = function(player)
	local plotModel, plotIndex = claimPlot()
	if not plotModel then
		warn("No plots available for " .. player.Name)
		return
	end
	local basePart       = plotModel:FindFirstChild("Base")
	local wallOriginPart = plotModel:FindFirstChild("WallOrigin")
	local spawnPart2     = plotModel:FindFirstChild("PlayerSpawn")
	if not basePart or not wallOriginPart then
		warn("Plot" .. plotIndex .. " missing Base or WallOrigin")
		plotOccupied[plotIndex] = false
		return
	end
	-- The plot frame: floor-level centre of the Base, LookVector = lane direction (the Base part's
	-- local -Z points down the lane, towards the walls). WallOrigin marks where the front wall stands.
	local frame = basePart.CFrame * CFrame.new(0, basePart.Size.Y / 2, 0)
	local plotState = {
		plotModel        = plotModel,
		plotIndex        = plotIndex,
		ownerId          = tostring(player.UserId),
		frame            = frame,
		wallFwd          = (wallOriginPart.Position - frame.Position):Dot(frame.LookVector),
		plotGroundY      = frame.Position.Y,
		wall             = nil,
		wallQueue        = {},
		wallHP           = 500,
		wallLayer        = 1,
		WALL_MAX_HP      = 500,
		wallRegen        = 1,
		goldMultiplier   = 1.0,
		hpFill           = nil,
		hpText           = nil,
		wallTarget       = Vector3.new(0, 0, 0),
		wallTargetFwd    = 0,
		wallFaceFwd      = 0,
		graveSlots       = {},
		activeUnits      = {},
		groundExtensions = {},
	}
	initWallQueue(plotState)
	-- 5 grave slots to start, +1 per ascension (max 10)
	local profile = PlayerData.get(player)
	local slotCount = math.min(10, 5 + (profile and profile.rebirthCount or 0))
	for i = 1, slotCount do
		local graveSpot = plotModel:FindFirstChild("GraveSpot" .. i)
		if graveSpot then
			addGraveSlot(i, graveSpot.Position, plotState, tostring(player.UserId))
		end
	end
	playerPlots[tostring(player.UserId)] = plotState
	local spawnPart = plotModel:FindFirstChild("PlayerSpawn")
	if spawnPart then
		local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if hrp then
			hrp.CFrame = CFrame.new(spawnPart.Position + Vector3.new(0, 3, 0))
		end
	end
	print("✅ Assigned Plot" .. plotIndex .. " to " .. player.Name)
end

Remotes.PlayerAscend.OnServerEvent:Connect(function(player)
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
	-- put the units back behind the graves (10 studs towards the plaza), in their own lanes
	local graveSpot1 = plotState.plotModel:FindFirstChild("GraveSpot1")
	local nearFwd = graveSpot1 and (select(2, PlotFrame.toLocal(plotState, graveSpot1.Position)) - 10)
		or (plotState.wallFwd - 60)
	local forward = PlotFrame.forwardFlat(plotState)
	for _, u in ipairs(plotState.activeUnits) do
		if u.block and u.block.Parent then
			local pos = PlotFrame.toWorld(plotState, u.lateral, nearFwd + math.random(-5, 5)) + Vector3.new(0, 7.7, 0)
			u.block.CFrame = CFrame.lookAt(pos, pos + forward)
		end
	end
	print("⬆️ " .. player.Name .. " ascended — wall reset, graves: " .. #plotState.graveSlots)
end)

-- Tears down a leaving player's plot objects and frees the plot.
local function releasePlot(player)
	local id = tostring(player.UserId)
	local plotState = playerPlots[id]
	if plotState then
		for _, w in ipairs(plotState.wallQueue or {}) do
			if w and w.Parent then w:Destroy() end
		end
		for _, ext in ipairs(plotState.groundExtensions) do
			if ext and ext.Parent then ext:Destroy() end
		end
		for _, u in ipairs(plotState.activeUnits) do
			if u.block and u.block.Parent then u.block:Destroy() end
		end
		for _, slot in ipairs(plotState.graveSlots) do
			if slot.stone and slot.stone.Parent then slot.stone:Destroy() end
			if slot.slab and slot.slab.Parent then slot.slab:Destroy() end
		end
		plotOccupied[plotState.plotIndex] = false
		playerPlots[id] = nil
	end
end

return {
	initPlotForPlayer = initPlotForPlayer,
	releasePlot = releasePlot,
}
