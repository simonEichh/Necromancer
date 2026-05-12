-- ============================================================
--  NECRO BUDDIES — WorldScript (Script)
--  Place inside ServerScriptService
--  Each unit = one single block. Simple and reliable.
-- ============================================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

-- ============================================================
--  REMOTE EVENTS
-- ============================================================
local summonRemote = Instance.new("RemoteEvent")
summonRemote.Name = "SummonUnit"
summonRemote.Parent = ReplicatedStorage

local wallBreakRemote = Instance.new("RemoteEvent")
wallBreakRemote.Name = "WallBreak"
wallBreakRemote.Parent = ReplicatedStorage

local damageRemote = Instance.new("RemoteEvent")
damageRemote.Name = "DamageHit"
damageRemote.Parent = ReplicatedStorage

local deployRemote = Instance.new("RemoteEvent")
deployRemote.Name = "DeployUnit"
deployRemote.Parent = ReplicatedStorage
--
local undeployRemote = Instance.new("RemoteEvent")
undeployRemote.Name = "UndeployUnit"
undeployRemote.Parent = ReplicatedStorage

local ascendRemote = Instance.new("RemoteEvent")
ascendRemote.Name = "PlayerAscend"
ascendRemote.Parent = ReplicatedStorage

local selectGraveRemote = Instance.new("RemoteEvent")
selectGraveRemote.Name = "SelectGrave"
selectGraveRemote.Parent = ReplicatedStorage

local placeAtGraveRemote = Instance.new("RemoteEvent")
placeAtGraveRemote.Name = "PlaceAtGrave"
placeAtGraveRemote.Parent = ReplicatedStorage

local recallUnitRemote = Instance.new("RemoteEvent")
recallUnitRemote.Name = "RecallUnit"
recallUnitRemote.Parent = ReplicatedStorage

local placeBestRemote = Instance.new("RemoteEvent")
placeBestRemote.Name = "PlaceBest"
placeBestRemote.Parent = ReplicatedStorage

local placeBestResultRemote = Instance.new("RemoteEvent")
placeBestResultRemote.Name = "PlaceBestResult"
placeBestResultRemote.Parent = ReplicatedStorage

local getWallPosFunc = Instance.new("RemoteFunction")
getWallPosFunc.Name = "GetWallPos"
getWallPosFunc.Parent = ReplicatedStorage

local wheelSpinRemote = Instance.new("RemoteEvent")
wheelSpinRemote.Name = "WheelSpin"
wheelSpinRemote.Parent = ReplicatedStorage

local buyGraveRequestRemote = Instance.new("RemoteEvent")
buyGraveRequestRemote.Name = "BuyGraveRequest"
buyGraveRequestRemote.Parent = ReplicatedStorage

local buyGraveResultRemote = Instance.new("RemoteEvent")
buyGraveResultRemote.Name = "BuyGraveResult"
buyGraveResultRemote.Parent = ReplicatedStorage

local shopStockUpdateRemote = Instance.new("RemoteEvent")
shopStockUpdateRemote.Name = "ShopStockUpdate"
shopStockUpdateRemote.Parent = ReplicatedStorage

local wheelResultRemote = Instance.new("RemoteEvent")
wheelResultRemote.Name = "WheelResult"
wheelResultRemote.Parent = ReplicatedStorage

local wheelSpinsUpdateRemote = Instance.new("RemoteEvent")
wheelSpinsUpdateRemote.Name = "WheelSpinsUpdate"
wheelSpinsUpdateRemote.Parent = ReplicatedStorage

-- ============================================================
--  WORLD SETUP
-- ============================================================

-- World is built in Studio (Plots folder + HubFloor). Nothing generated here.

-- ============================================================
--  PLOT SYSTEM
-- ============================================================
local plotsFolder = workspace:WaitForChild("Plots", 10)
local playerPlots  = {}  -- [userId] = plotState
local plotOccupied = {}  -- [1..8]  = true/false
local WALL_SPACING = 60
local initPlotForPlayer -- forward declared; defined after wall functions

local function getPlot(player)
	return playerPlots[tostring(player.UserId)]
end

getWallPosFunc.OnServerInvoke = function(player)
	local plotState = getPlot(player)
	if plotState and plotState.wall and plotState.wall.Parent then
		return plotState.wall.Position
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

local recallUnitFromSlot -- forward declared

local function addGraveSlot(i, basePos, plotState, ownerId)
	local slab = Instance.new("Part")
	slab.Name = "GraveSlot_" .. i
	slab.Size = Vector3.new(2.5, 0.5, 2.5)
	slab.Position = basePos + Vector3.new(0, 0.25, 0)
	slab.Anchored = true
	slab.BrickColor = BrickColor.new("Dark stone grey")
	slab.Material = Enum.Material.SmoothPlastic
	slab.TopSurface = Enum.SurfaceType.Smooth
	slab.Parent = workspace

	local stone = Instance.new("Part")
	stone.Name = "GraveHeadstone_" .. i
	stone.Size = Vector3.new(1.8, 2.8, 0.5)
	stone.Position = basePos + Vector3.new(plotState.laneDir * 0.9, 1.9, 0)
	stone.Anchored = true
	stone.BrickColor = BrickColor.new("Medium stone grey")
	stone.Material = Enum.Material.SmoothPlastic
	stone.Parent = workspace

	local gui = Instance.new("BillboardGui", slab)
	gui.Size = UDim2.new(0, 150, 0, 68)
	gui.StudsOffset = Vector3.new(0, 5.5, 0)
	gui.AlwaysOnTop = true
	local lbl = Instance.new("TextLabel", gui)
	lbl.Size = UDim2.new(1, 0, 0.38, 0)
	lbl.Position = UDim2.new(0, 0, 0, 0)
	lbl.BackgroundTransparency = 1
	lbl.Text = "🪦 Empty"
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
	prompt.Parent = slab

	plotState.graveSlots[i] = {
		slab = slab, stone = stone, label = lbl,
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
			selectGraveRemote:FireClient(player, spawnPoint, idx)
		end
	end)
end

-- ============================================================
--  SHOPKEEPER REMOTES
-- ============================================================
local openGraveRemote = Instance.new("RemoteEvent")
openGraveRemote.Name = "OpenGrave"
openGraveRemote.Parent = ReplicatedStorage

local openSellRemote = Instance.new("RemoteEvent")
openSellRemote.Name = "OpenSell"
openSellRemote.Parent = ReplicatedStorage

local openUpgradeRemote = Instance.new("RemoteEvent")
openUpgradeRemote.Name = "OpenUpgrade"
openUpgradeRemote.Parent = ReplicatedStorage

local sellUnitRemote = Instance.new("RemoteEvent")
sellUnitRemote.Name = "SellUnit"
sellUnitRemote.Parent = ReplicatedStorage

local addGoldRemote = Instance.new("RemoteEvent")
addGoldRemote.Name = "AddGold"
addGoldRemote.Parent = ReplicatedStorage

sellUnitRemote.OnServerEvent:Connect(function(player, unitType, oneIn)
	if not unitType or not oneIn then return end
	local sellValue = math.floor(oneIn ^ 1.2 * 5)
	addGoldRemote:FireClient(player, sellValue, unitType)
	print("💰 " .. player.Name .. " sold " .. unitType .. " for " .. sellValue .. " gold")
end)

-- Wire up Studio-placed shopkeepers
local shopsFolder = workspace:WaitForChild("Shops", 10)
if shopsFolder then
	local function wireShop(name, remote, label)
		local npc = shopsFolder:FindFirstChild(name)
		if not npc then warn("Shops." .. name .. " not found") return end
		local prompt = npc:FindFirstChildOfClass("ProximityPrompt")
		if not prompt then warn(name .. " has no ProximityPrompt") return end
		prompt.ActionText = "Talk"
		prompt.ObjectText = label
		prompt.Triggered:Connect(function(player)
			remote:FireClient(player)
		end)
		local gui = Instance.new("BillboardGui", npc)
		gui.Size = UDim2.new(0, 120, 0, 40)
		gui.StudsOffset = Vector3.new(0, 4, 0)
		gui.AlwaysOnTop = false
		local lbl = Instance.new("TextLabel", gui)
		lbl.Size = UDim2.new(1, 0, 1, 0)
		lbl.BackgroundTransparency = 1
		lbl.Text = label
		lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
		lbl.TextScaled = true
		lbl.Font = Enum.Font.GothamBold
	end
	wireShop("GraveShopkeeper",   openGraveRemote,   "Buy")
	wireShop("SellShopkeeper",    openSellRemote,    "Sell")
	wireShop("UpgradeShopkeeper", openUpgradeRemote, "Upgrade")
else
	warn("Shops folder not found in Workspace")
end

-- Per-player upgrade levels (luckBoost, coinBoost)
local playerUpgrades = {}
local UPGRADE_MAX = { luckBoost = 20, coinBoost = 15 }

local function getPlayerUpgrades(player)
	local id = tostring(player.UserId)
	if not playerUpgrades[id] then
		playerUpgrades[id] = { luckBoost = 0, coinBoost = 0 }
	end
	return playerUpgrades[id]
end

-- ── WHEEL DATA ───────────────────────────────────────────────
local playerWheelData = {}
local function getWheelData(player)
	local id = tostring(player.UserId)
	if not playerWheelData[id] then
		playerWheelData[id] = {
			spins = 0,
			lastGrantTime = tick(),
			luckBuffEnd = 0,
		}
	end
	return playerWheelData[id]
end

-- ============================================================
--  SHOP ROTATION SYSTEM
-- ============================================================
local GRAVE_STOCK_BASE = {
	Mossy = 999, Stone = 50, Ancient = 30, Cursed = 20,
	Shadow = 15, Abyssal = 10, Eldritch = 5,
	Void = 3, Eternal = 2, Celestial = 1,
}
local GRAVE_ROTATION_CHANCE = {
	Mossy = 1.0, Stone = 0.9, Ancient = 0.8, Cursed = 0.7,
	Shadow = 0.6, Abyssal = 0.5, Eldritch = 0.4,
	Void = 0.3, Eternal = 0.2, Celestial = 0.1,
}
local SHOP_RESTOCK_TIME = 300
local playerShopData = {}

local function generateRotation(player)
	local id = tostring(player.UserId)
	local stock, inRotation = {}, {}
	for key, baseStock in pairs(GRAVE_STOCK_BASE) do
		local chance = GRAVE_ROTATION_CHANCE[key] or 1
		if math.random() <= chance then
			stock[key] = baseStock
			inRotation[key] = true
		else
			stock[key] = 0
			inRotation[key] = false
		end
	end
	playerShopData[id] = {
		stock = stock,
		inRotation = inRotation,
		nextRestock = tick() + SHOP_RESTOCK_TIME,
	}
end

local function sendShopUpdate(player)
	local id = tostring(player.UserId)
	local data = playerShopData[id]
	if not data then return end
	local secsLeft = math.max(0, math.floor(data.nextRestock - tick()))
	shopStockUpdateRemote:FireClient(player, data.stock, data.inRotation, secsLeft)
end

buyGraveRequestRemote.OnServerEvent:Connect(function(player, graveType, qty)
	if type(graveType) ~= "string" or type(qty) ~= "number" then return end
	local id = tostring(player.UserId)
	local data = playerShopData[id]
	if not data or not data.inRotation[graveType] then return end
	local available = data.stock[graveType] or 0
	local approved = math.min(math.floor(qty), available)
	if approved <= 0 then return end
	data.stock[graveType] = available - approved
	buyGraveResultRemote:FireClient(player, graveType, approved, data.stock[graveType])
end)

Players.PlayerAdded:Connect(function(player)
	local wd = getWheelData(player)
	player.CharacterAdded:Connect(function()
		task.wait(1)
		local secsLeft = math.max(0, math.floor(900 - (tick() - wd.lastGrantTime)))
		wheelSpinsUpdateRemote:FireClient(player, wd.spins, secsLeft)
	end)
	-- Assign plot (wait for character to load first)
	task.spawn(function()
		if not player.Character then
			player.CharacterAdded:Wait()
		end
		task.wait(1)
		initPlotForPlayer(player)
		generateRotation(player)
		sendShopUpdate(player)
	end)
end)

Players.PlayerRemoving:Connect(function(player)
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
			if slot.slab and slot.slab.Parent then slot.slab:Destroy() end
			if slot.stone and slot.stone.Parent then slot.stone:Destroy() end
		end
		plotOccupied[plotState.plotIndex] = false
		playerPlots[id] = nil
	end
	playerWheelData[id] = nil
	playerUpgrades[id]  = nil
	if playerPity then playerPity[id] = nil end
	playerShopData[id] = nil
end)

-- Wheel outcomes (7 segments matching the client display order)
local WHEEL_OUTCOMES = {
	{ id = "gold_1k",    weight = 50, label = "+1k Gold",          emoji = "💰" },
	{ id = "luck_buff",  weight = 10, label = "2x Luck 5min",      emoji = "🍀" },
	{ id = "gems_50",    weight = 16, label = "+50 Gems",          emoji = "💎" },
	{ id = "graves_5",   weight = 10, label = "+5 Ancient Graves", emoji = "🪦", graveType = "Ancient", count = 5 },
	{ id = "gems_100",   weight = 8,  label = "+100 Gems",         emoji = "💎" },
	{ id = "grave_rare", weight = 5,  label = "+1 Shadow Grave",   emoji = "🌑", graveType = "Shadow",  count = 1 },
	{ id = "lucky_box",  weight = 1,  label = "Lucky Box!",        emoji = "📦" },
}
local WHEEL_TOTAL_WEIGHT = 0
for _, o in ipairs(WHEEL_OUTCOMES) do
	WHEEL_TOTAL_WEIGHT += o.weight
end

local function rollWheelOutcome()
	local r = math.random(1, WHEEL_TOTAL_WEIGHT)
	local cum = 0
	for i, o in ipairs(WHEEL_OUTCOMES) do
		cum += o.weight
		if r <= cum then
			return i, o
		end
	end
	return 1, WHEEL_OUTCOMES[1]
end

local buyUpgradeRemote = Instance.new("RemoteEvent")
buyUpgradeRemote.Name = "BuyUpgrade"
buyUpgradeRemote.Parent = ReplicatedStorage

local upgradeGrantedRemote = Instance.new("RemoteEvent")
upgradeGrantedRemote.Name = "UpgradeGranted"
upgradeGrantedRemote.Parent = ReplicatedStorage

buyUpgradeRemote.OnServerEvent:Connect(function(player, upgradeType)
	local upgrades = getPlayerUpgrades(player)
	local max = UPGRADE_MAX[upgradeType]
	if not max or not upgrades[upgradeType] then
		return
	end
	if upgrades[upgradeType] >= max then
		return
	end
	upgrades[upgradeType] += 1
	upgradeGrantedRemote:FireClient(player, upgradeType, upgrades[upgradeType])
	print("⚗️ " .. player.Name .. " upgraded " .. upgradeType .. " → level " .. upgrades[upgradeType])
end)

-- ============================================================
--  PER-PLOT WALL FUNCTIONS
-- ============================================================
local LAYER_COLORS = {
	BrickColor.new("Medium stone grey"),
	BrickColor.new("Bright green"),
	BrickColor.new("Bright blue"),
	BrickColor.new("Bright violet"),
	BrickColor.new("Bright pink"),
}
local NUM_PREVIEW_WALLS = 8

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

-- Spawns a dim preview wall showing an upcoming layer number
local function spawnPreviewWall(x, layerNum, plotState)
	local wallPart = Instance.new("Part")
	wallPart.Name = "PreviewWall_" .. plotState.plotIndex
	wallPart.Size = Vector3.new(4, 20, 40)
	wallPart.Position = Vector3.new(x, plotState.plotGroundY + 10, plotState.plotCenterZ)
	wallPart.Anchored = true
	wallPart.BrickColor = BrickColor.new("Dark stone grey")
	wallPart.Transparency = 0
	wallPart.Material = Enum.Material.SmoothPlastic
	wallPart.Parent = workspace
	local gui = Instance.new("BillboardGui", wallPart)
	gui.Name = "PreviewGui"
	gui.Size = UDim2.new(0, 0, 0, 0)
	return wallPart
end

-- Promotes a preview wall to the active wall (full color + HP bar)
local function activateWall(wallPart, plotState)
	wallPart.Name = "TheWall_" .. plotState.plotIndex
	wallPart.BrickColor = LAYER_COLORS[((plotState.wallLayer - 1) % #LAYER_COLORS) + 1]
	wallPart.Transparency = 0
	local previewGui = wallPart:FindFirstChild("PreviewGui")
	if previewGui then previewGui:Destroy() end
	buildWallGui(wallPart, plotState)
end

-- Spawns initial ground slab + 8 walls, activates the first one
local function initWallQueue(plotState)
	-- Initial ground covering all preview walls
	local ld = plotState.laneDir
	local groundLen = (NUM_PREVIEW_WALLS + 1) * WALL_SPACING
	local initGround = Instance.new("Part")
	initGround.Name = "GroundExt"
	initGround.Size = Vector3.new(groundLen, 2, 40)
	initGround.Position = Vector3.new(
		plotState.wallOriginX + ld * groundLen / 2,
		plotState.plotGroundY - 1,
		plotState.plotCenterZ
	)
	initGround.Anchored = true
	initGround.Color = Color3.fromRGB(165, 8, 8)
	initGround.Material = Enum.Material.Carpet
	initGround.TopSurface = Enum.SurfaceType.Smooth
	initGround.Parent = workspace
	table.insert(plotState.groundExtensions, initGround)
	plotState.plotLaneEndX = plotState.wallOriginX + ld * groundLen

	-- Spawn 8 preview walls
	plotState.wallQueue = {}
	for i = 1, NUM_PREVIEW_WALLS do
		local x = plotState.wallOriginX + ld * (i - 1) * WALL_SPACING
		local wallPart = spawnPreviewWall(x, plotState.wallLayer + (i - 1), plotState)
		table.insert(plotState.wallQueue, wallPart)
	end

	-- Activate the front wall
	activateWall(plotState.wallQueue[1], plotState)
	plotState.wall = plotState.wallQueue[1]
	plotState.wallTarget = Vector3.new(plotState.wall.Position.X - ld * (plotState.wall.Size.X/2 + 3), 0, plotState.plotCenterZ)
	updateWallGui(plotState)
end

local function breakWall(plotState)
	plotState.wallLayer += 1
	plotState.WALL_MAX_HP = math.floor(500 * (2 ^ (plotState.wallLayer - 1)))
	plotState.wallHP = plotState.WALL_MAX_HP
	plotState.wallRegen = plotState.wallLayer * 2

	-- Flash and destroy active wall
	plotState.wallQueue[1].BrickColor = BrickColor.new("White")
	plotState.wallQueue[1]:Destroy()
	table.remove(plotState.wallQueue, 1)

	-- Spawn new preview at the far end
	local ld = plotState.laneDir
	local lastWall = plotState.wallQueue[#plotState.wallQueue]
	local newPreviewX = lastWall.Position.X + ld * WALL_SPACING
	local newPreview = spawnPreviewWall(newPreviewX, plotState.wallLayer + #plotState.wallQueue - 1, plotState)
	table.insert(plotState.wallQueue, newPreview)

	-- Ground extension if beyond initial coverage
	if (newPreviewX - plotState.plotLaneEndX) * ld > 0 then
		local groundExt = Instance.new("Part")
		groundExt.Name = "GroundExt"
		groundExt.Size = Vector3.new(WALL_SPACING, 2, 40)
		groundExt.Position = Vector3.new(newPreviewX - ld * WALL_SPACING/2, plotState.plotGroundY - 1, plotState.plotCenterZ)
		groundExt.Anchored = true
		groundExt.Color = Color3.fromRGB(165, 8, 8)
		groundExt.Material = Enum.Material.Carpet
		groundExt.TopSurface = Enum.SurfaceType.Smooth
		groundExt.Parent = workspace
		table.insert(plotState.groundExtensions, groundExt)
		plotState.plotLaneEndX = newPreviewX
	end

	-- Activate the new front wall
	activateWall(plotState.wallQueue[1], plotState)
	plotState.wall = plotState.wallQueue[1]
	plotState.wallTarget = Vector3.new(plotState.wall.Position.X - ld * (plotState.wall.Size.X/2 + 3), 0, plotState.plotCenterZ)
	updateWallGui(plotState)

	local goldReward = math.floor(1000 * plotState.wallLayer * plotState.goldMultiplier)
	for _, p in ipairs(Players:GetPlayers()) do
		if tostring(p.UserId) == plotState.ownerId then
			wallBreakRemote:FireClient(p, goldReward, plotState.wallLayer - 1)
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
	-- Detect lane direction from WallOrigin vs PlayerSpawn positions
	local laneDir = -1
	if spawnPart2 and wallOriginPart.Position.X > spawnPart2.Position.X then
		laneDir = 1
	end
	local plotState = {
		plotModel        = plotModel,
		plotIndex        = plotIndex,
		ownerId          = tostring(player.UserId),
		plotCenterZ      = basePart.Position.Z,
		wallOriginX      = wallOriginPart.Position.X,
		plotLaneEndX     = 0,
		plotGroundY      = basePart.Position.Y + basePart.Size.Y / 2,
		laneDir          = laneDir,
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
		graveSlots       = {},
		activeUnits      = {},
		groundExtensions = {},
	}
	initWallQueue(plotState)
	for i = 1, 5 do
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

-- ============================================================
--  UNIT DEFINITIONS
-- ============================================================
local UNITS = {
	-- ── Common ──────────────────────────────────────────────────────────
	Skelly = {
		color = BrickColor.new("White"),
		size = Vector3.new(2, 2, 2),
		damage = 10,
		speed = 8,
		attackRange = 5,
		attackCD = 1.2,
	},
	Zombie = {
		color = BrickColor.new("Medium green"),
		size = Vector3.new(2.2, 2.2, 2.2),
		damage = 12,
		speed = 5,
		attackRange = 5,
		attackCD = 2.0,
	},
	Ghoul = {
		color = BrickColor.new("Dark orange"),
		size = Vector3.new(1.8, 1.8, 1.8),
		damage = 16,
		speed = 14,
		attackRange = 6,
		attackCD = 1.2,
	},
	-- ── Uncommon ────────────────────────────────────────────────────────
	Ghost = {
		color = BrickColor.new("Pastel blue"),
		size = Vector3.new(2.2, 2.2, 2.2),
		damage = 15,
		speed = 14,
		attackRange = 10,
		attackCD = 0.8,
		transparent = true,
	},
	Goblin = {
		color = BrickColor.new("Bright green"),
		size = Vector3.new(1.8, 1.8, 1.8),
		damage = 22,
		speed = 16,
		attackRange = 30,
		attackCD = 1.0,
		poison = 3,
	},
	Wraith = {
		color = BrickColor.new("Light stone grey"),
		size = Vector3.new(2, 2, 2),
		damage = 28,
		speed = 16,
		attackRange = 8,
		attackCD = 0.8,
		transparent = true,
	},
	CryptBat = {
		color = BrickColor.new("Dark grey"),
		size = Vector3.new(1.5, 1.5, 1.5),
		damage = 25,
		speed = 22,
		attackRange = 12,
		attackCD = 0.6,
	},
	-- ── Rare ────────────────────────────────────────────────────────────
	BaronBone = {
		color = BrickColor.new("Bright yellow"),
		size = Vector3.new(2.5, 2.5, 2.5),
		damage = 50,
		speed = 8,
		attackRange = 7,
		attackCD = 0.9,
	},
	PlagueDoctor = {
		color = BrickColor.new("Olive"),
		size = Vector3.new(2, 2, 2),
		damage = 56,
		speed = 10,
		attackRange = 20,
		attackCD = 0.8,
		poison = 5,
	},
	ShadowHound = {
		color = BrickColor.new("Reddish brown"),
		size = Vector3.new(2, 2, 2),
		damage = 60,
		speed = 24,
		attackRange = 7,
		attackCD = 0.7,
	},
	BoneColossus = {
		color = BrickColor.new("White"),
		size = Vector3.new(3.5, 3.5, 3.5),
		damage = 120,
		speed = 4,
		attackRange = 8,
		attackCD = 1.2,
	},
	-- ── Cursed ──────────────────────────────────────────────────────────
	Banshee = {
		color = BrickColor.new("Hot pink"),
		size = Vector3.new(2.4, 2.4, 2.4),
		damage = 80,
		speed = 18,
		attackRange = 20,
		attackCD = 0.5,
		transparent = true,
		regenReduction = 0.8,
	},
	LichAcolyte = {
		color = BrickColor.new("Medium lavender"),
		size = Vector3.new(2.2, 2.2, 2.2),
		damage = 140,
		speed = 10,
		attackRange = 25,
		attackCD = 0.7,
	},
	DreadKnight = {
		color = BrickColor.new("Bright red"),
		size = Vector3.new(2.8, 2.8, 2.8),
		damage = 195,
		speed = 12,
		attackRange = 8,
		attackCD = 0.75,
	},
	-- ── Legendary ───────────────────────────────────────────────────────
	SkeletonKing = {
		color = BrickColor.new("Gold"),
		size = Vector3.new(3, 3, 3),
		damage = 350,
		speed = 10,
		attackRange = 8,
		attackCD = 1.0,
	},
	LichLord = {
		color = BrickColor.new("Bright violet"),
		size = Vector3.new(2.8, 2.8, 2.8),
		damage = 384,
		speed = 8,
		attackRange = 30,
		attackCD = 0.8,
		regenReduction = 0.5,
	},
	DeathReaper = {
		color = BrickColor.new("Dark indigo"),
		size = Vector3.new(2.5, 2.5, 2.5),
		damage = 455,
		speed = 20,
		attackRange = 10,
		attackCD = 0.7,
	},
	VoidWalker = {
		color = BrickColor.new("Really black"),
		size = Vector3.new(2.2, 2.2, 2.2),
		damage = 400,
		speed = 25,
		attackRange = 15,
		attackCD = 0.5,
		transparent = true,
	},
	-- ── Abyssal ─────────────────────────────────────────────────────────
	SoulEater = {
		color = BrickColor.new("Bright orange"),
		size = Vector3.new(3, 3, 3),
		damage = 720,
		speed = 16,
		attackRange = 12,
		attackCD = 0.6,
	},
	AbyssalTitan = {
		color = BrickColor.new("Bright red"),
		size = Vector3.new(4, 4, 4),
		damage = 1600,
		speed = 6,
		attackRange = 10,
		attackCD = 1.0,
	},
	ShadeLord = {
		color = BrickColor.new("Dark purple"),
		size = Vector3.new(3, 3, 3),
		damage = 1320,
		speed = 18,
		attackRange = 20,
		attackCD = 0.6,
		transparent = true,
		regenReduction = 0.9,
	},
	-- ── Eldritch ────────────────────────────────────────────────────────
	EldritchFiend = {
		color = BrickColor.new("Teal"),
		size = Vector3.new(3.5, 3.5, 3.5),
		damage = 2800,
		speed = 12,
		attackRange = 25,
		attackCD = 0.7,
	},
	MindShatterer = {
		color = BrickColor.new("Cyan"),
		size = Vector3.new(2.8, 2.8, 2.8),
		damage = 3900,
		speed = 22,
		attackRange = 30,
		attackCD = 0.6,
	},
	-- ── Eternal ─────────────────────────────────────────────────────────
	TheUndying = {
		color = BrickColor.new("Institutional white"),
		size = Vector3.new(4, 4, 4),
		damage = 8400,
		speed = 15,
		attackRange = 15,
		attackCD = 0.7,
		transparent = true,
		regenReduction = 1.0,
	},
	DeathIncarnate = {
		color = BrickColor.new("Really black"),
		size = Vector3.new(5, 5, 5),
		damage = 12000,
		speed = 10,
		attackRange = 20,
		attackCD = 0.6,
		regenReduction = 1.0,
	},
}

-- Rarity definitions
local RARITIES = {
	{ name = "Common", color = Color3.fromRGB(200, 200, 200) },
	{ name = "Uncommon", color = Color3.fromRGB(100, 220, 100) },
	{ name = "Rare", color = Color3.fromRGB(80, 150, 255) },
	{ name = "Cursed", color = Color3.fromRGB(180, 80, 255) },
	{ name = "Legendary", color = Color3.fromRGB(255, 200, 50) },
	{ name = "Abyssal", color = Color3.fromRGB(220, 50, 50) },
	{ name = "Eldritch", color = Color3.fromRGB(50, 220, 200) },
	{ name = "Eternal", color = Color3.fromRGB(240, 240, 255) },
}

-- Which units belong to which rarity, each with a relative weight
-- (higher weight = more likely within that rarity tier)
local RARITY_UNITS = {
	Common = {
		{ unit = "Skelly", weight = 4 },
		{ unit = "Zombie", weight = 3 },
		{ unit = "Ghoul", weight = 2 },
	},
	Uncommon = {
		{ unit = "Ghost", weight = 4 },
		{ unit = "Goblin", weight = 3 },
		{ unit = "Wraith", weight = 2 },
		{ unit = "CryptBat", weight = 1 },
	},
	Rare = {
		{ unit = "BaronBone", weight = 3 },
		{ unit = "PlagueDoctor", weight = 2 },
		{ unit = "ShadowHound", weight = 2 },
		{ unit = "BoneColossus", weight = 1 },
	},
	Cursed = {
		{ unit = "Banshee", weight = 3 },
		{ unit = "LichAcolyte", weight = 2 },
		{ unit = "DreadKnight", weight = 1 },
	},
	Legendary = {
		{ unit = "SkeletonKing", weight = 6 },
		{ unit = "LichLord", weight = 3 },
		{ unit = "DeathReaper", weight = 2 },
		{ unit = "VoidWalker", weight = 1 },
	},
	Abyssal = {
		{ unit = "SoulEater", weight = 3 },
		{ unit = "AbyssalTitan", weight = 2 },
		{ unit = "ShadeLord", weight = 1 },
	},
	Eldritch = {
		{ unit = "EldritchFiend", weight = 2 },
		{ unit = "MindShatterer", weight = 1 },
	},
	Eternal = {
		{ unit = "TheUndying", weight = 2 },
		{ unit = "DeathIncarnate", weight = 1 },
	},
}

-- Reverse lookup: unitType → rarity string
local UNIT_RARITY = {}
for rarity, units in pairs(RARITY_UNITS) do
	for _, entry in ipairs(units) do
		UNIT_RARITY[entry.unit] = rarity
	end
end

-- Rarity → Color3 for labels
local RARITY_COLOR = {
	Common = Color3.fromRGB(200, 200, 200),
	Uncommon = Color3.fromRGB(100, 220, 100),
	Rare = Color3.fromRGB(80, 150, 255),
	Cursed = Color3.fromRGB(180, 80, 255),
	Legendary = Color3.fromRGB(255, 200, 50),
	Abyssal = Color3.fromRGB(220, 50, 50),
	Eldritch = Color3.fromRGB(50, 220, 200),
	Eternal = Color3.fromRGB(240, 240, 255),
}

-- Base rarity odds at 1× luck (all graves share this curve)
local BASE_ODDS = {
	Common = 45,
	Uncommon = 25,
	Rare = 15,
	Cursed = 8,
	Legendary = 4,
	Abyssal = 2,
	Eldritch = 0.75,
	Eternal = 0.25,
}

-- Grave definitions — luck drives the best-of-N roll multiplier
-- 100 = 1× (one roll), 300 = 3× (three rolls, keep rarest), etc.
local GRAVES = {
	Mossy = {
		name = "Mossy Grave",
		cost = 50,
		luck = 100,
		pityRarity = "Rare",
		unlockAscension = 0,
	},
	Stone = {
		name = "Stone Coffin",
		cost = 500,
		luck = 200,
		pityRarity = "Cursed",
		unlockAscension = 1,
	},
	Ancient = {
		name = "Ancient Tomb",
		cost = 3000,
		luck = 500,
		pityRarity = "Legendary",
		unlockAscension = 2,
	},
	Cursed = {
		name = "Cursed Crypt",
		cost = 20000,
		luck = 1000,
		pityRarity = "Legendary",
		unlockAscension = 3,
	},
	Shadow = {
		name = "Shadow Vault",
		cost = 100000,
		luck = 2000,
		pityRarity = "Abyssal",
		unlockAscension = 4,
	},
	Abyssal = {
		name = "Abyssal Tomb",
		cost = 500000,
		luck = 4000,
		pityRarity = "Abyssal",
		unlockAscension = 5,
	},
	Eldritch = {
		name = "Eldritch Reliquary",
		cost = 2500000,
		luck = 8000,
		pityRarity = "Eldritch",
		unlockAscension = 6,
	},
	Void = {
		name = "Void Sanctum",
		cost = 12000000,
		luck = 16000,
		pityRarity = "Eldritch",
		unlockAscension = 7,
	},
	Eternal = {
		name = "Eternal Throne",
		cost = 60000000,
		luck = 35000,
		pityRarity = "Eternal",
		unlockAscension = 8,
	},
	Celestial = {
		name = "Celestial Abyss",
		cost = 300000000,
		luck = 75000,
		pityRarity = "Eternal",
		unlockAscension = 9,
	},
}

-- Per-player pity counters
local playerPity = {} -- playerPity[userId][graveType] = count

local function getPity(player, graveType)
	local id = tostring(player.UserId)
	if not playerPity[id] then
		playerPity[id] = {}
	end
	return playerPity[id][graveType] or 0
end

local function incrementPity(player, graveType)
	local id = tostring(player.UserId)
	if not playerPity[id] then
		playerPity[id] = {}
	end
	playerPity[id][graveType] = (playerPity[id][graveType] or 0) + 1
end

local function resetPity(player, graveType)
	local id = tostring(player.UserId)
	if playerPity[id] then
		playerPity[id][graveType] = 0
	end
end

local RARITY_RANK = {
	Common = 1,
	Uncommon = 2,
	Rare = 3,
	Cursed = 4,
	Legendary = 5,
	Abyssal = 6,
	Eldritch = 7,
	Eternal = 8,
}
local RARITY_ORDER = { "Eternal", "Eldritch", "Abyssal", "Legendary", "Cursed", "Rare", "Uncommon", "Common" }

-- Single roll against BASE_ODDS (no luck applied)
-- Uses 10000-point scale to support fractional % like Eldritch (0.75%) and Eternal (0.25%)
local function rollBaseRarity()
	local roll = math.random(1, 10000)
	local cumulative = 0
	for _, rarity in ipairs(RARITY_ORDER) do
		cumulative += BASE_ODDS[rarity] * 100
		if roll <= cumulative then
			return rarity
		end
	end
	return "Common"
end

-- Roll rarity using grave luck (best-of-N: N = grave.luck / 100)
local function rollRarity(grave, player, graveType)
	local pity = getPity(player, graveType)
	if pity >= 60 then
		resetPity(player, graveType)
		return grave.pityRarity
	end

	local luckMult = math.max(1, grave.luck / 100)
	local rolls = math.floor(luckMult)
	if math.random() < (luckMult % 1) then
		rolls += 1
	end

	local best = "Common"
	for _ = 1, rolls do
		local r = rollBaseRarity()
		if RARITY_RANK[r] > RARITY_RANK[best] then
			best = r
		end
	end

	if best == grave.pityRarity then
		resetPity(player, graveType)
	else
		incrementPity(player, graveType)
	end
	return best
end

-- Pick a weighted random unit from a rarity pool
local function rollUnit(rarity)
	local pool = RARITY_UNITS[rarity]
	if not pool or #pool == 0 then
		return "Skelly"
	end
	local totalWeight = 0
	for _, entry in ipairs(pool) do
		totalWeight += entry.weight
	end
	local roll = math.random(1, totalWeight)
	local cumulative = 0
	for _, entry in ipairs(pool) do
		cumulative += entry.weight
		if roll <= cumulative then
			return entry.unit
		end
	end
	return pool[#pool].unit
end

-- Base "1 in X" chance for a unit (uses BASE_ODDS only — no luck, always shown raw)
local function getBaseOneIn(unitType)
	local rarity = UNIT_RARITY[unitType] or "Common"
	local rarityChance = BASE_ODDS[rarity] / 100
	local pool = RARITY_UNITS[rarity]
	local totalWeight = 0
	for _, entry in ipairs(pool) do
		totalWeight += entry.weight
	end
	local unitWeight = 0
	for _, entry in ipairs(pool) do
		if entry.unit == unitType then
			unitWeight = entry.weight
			break
		end
	end
	if unitWeight == 0 or totalWeight == 0 then
		return 999
	end
	local chance = rarityChance * (unitWeight / totalWeight)
	return math.max(2, math.round(1 / chance))
end

recallUnitFromSlot = function(slotIndex, player, plotState)
	local slot = plotState.graveSlots[slotIndex]
	if not slot or not slot.occupied then return end
	if slot.unitEntry then
		for i = #plotState.activeUnits, 1, -1 do
			if plotState.activeUnits[i] == slot.unitEntry then
				if plotState.activeUnits[i].block and plotState.activeUnits[i].block.Parent then
					plotState.activeUnits[i].block:Destroy()
				end
				table.remove(plotState.activeUnits, i)
				break
			end
		end
	end
	recallUnitRemote:FireClient(player, slot.unitType, getBaseOneIn(slot.unitType))
	slot.occupied = false
	slot.unitType = nil
	slot.unitEntry = nil
	slot.label.Text = "🪦 Empty"
	slot.rarityLabel.Text = ""
	slot.dpsLabel.Text = ""
	slot.prompt.ActionText = "Place Unit"
	slot.prompt.ObjectText = "Grave " .. slotIndex
	print("↩️ " .. player.Name .. " recalled unit from grave " .. slotIndex)
end

local function spawnUnit(unitType, customPos, plotState)
	local def = UNITS[unitType]
	if not def then return end

	local ld = plotState.laneDir
	local laneZ = customPos and customPos.Z or (plotState.plotCenterZ + math.random(-8, 8))
	local forwardClearance = def.size.X / 2 + 2
	local spawnPos = customPos
		and Vector3.new(customPos.X + ld * forwardClearance, customPos.Y + 2, customPos.Z)
		or  Vector3.new(plotState.wallOriginX - ld * 80, 4, laneZ)

	local block = Instance.new("Part")
	block.Name = unitType
	block.Size = def.size
	block.BrickColor = def.color
	block.Material = Enum.Material.SmoothPlastic
	block.Position = spawnPos
	block.CanCollide = true
	block.CastShadow = true
	if def.transparent then
		block.Transparency = 0.35
	end
	block.Parent = workspace

	-- BodyVelocity steers the block on X/Z
	-- MaxForce Y = 0 so gravity still pulls it down onto the floor
	local bv = Instance.new("BodyVelocity")
	bv.Velocity = Vector3.new(0, 0, 0)
	bv.MaxForce = Vector3.new(1e5, 0, 1e5)
	bv.P = 1e4
	bv.Parent = block

	-- BodyGyro keeps it upright and facing the wall
	local bg = Instance.new("BodyGyro")
	bg.MaxTorque = Vector3.new(0, 1e5, 0)
	bg.P = 1e4
	bg.D = 400
	bg.CFrame = CFrame.new(spawnPos, Vector3.new(plotState.wallTarget.X, spawnPos.Y, plotState.wallTarget.Z))
	bg.Parent = block

	-- Unit info label (emoji + name / rarity / DPS)
	local UNIT_EMOJIS = {
		-- Common
		Skelly = "🦴",
		Zombie = "🧟",
		Ghoul = "🪦",
		-- Uncommon
		Ghost = "👻",
		Goblin = "🏹",
		Wraith = "🌫️",
		CryptBat = "🦇",
		-- Rare
		BaronBone = "💀",
		PlagueDoctor = "🧪",
		ShadowHound = "🐺",
		BoneColossus = "🗿",
		-- Cursed
		Banshee = "👁️",
		LichAcolyte = "🔮",
		DreadKnight = "⚔️",
		-- Legendary
		SkeletonKing = "👑",
		LichLord = "🧙",
		DeathReaper = "☠️",
		VoidWalker = "🌑",
		-- Abyssal
		SoulEater = "🔥",
		AbyssalTitan = "🌋",
		ShadeLord = "🕳️",
		-- Eldritch
		EldritchFiend = "🐙",
		MindShatterer = "🧠",
		-- Eternal
		TheUndying = "✨",
		DeathIncarnate = "💀",
	}
	local unitRarity = UNIT_RARITY[unitType] or "Common"
	local unitDps = math.floor(def.damage / def.attackCD)
	local gui = Instance.new("BillboardGui", block)
	gui.Size = UDim2.new(0, 150, 0, 68)
	gui.StudsOffset = Vector3.new(0, def.size.Y + 1.8, 0)
	gui.AlwaysOnTop = true
	local nameLbl = Instance.new("TextLabel", gui)
	nameLbl.Size = UDim2.new(1, 0, 0.38, 0)
	nameLbl.Position = UDim2.new(0, 0, 0, 0)
	nameLbl.BackgroundTransparency = 1
	nameLbl.Text = (UNIT_EMOJIS[unitType] or "💀") .. " " .. unitType
	nameLbl.TextColor3 = Color3.fromRGB(255, 230, 255)
	nameLbl.TextScaled = true
	nameLbl.Font = Enum.Font.GothamBold
	local rarityLbl = Instance.new("TextLabel", gui)
	rarityLbl.Size = UDim2.new(1, 0, 0.31, 0)
	rarityLbl.Position = UDim2.new(0, 0, 0.38, 0)
	rarityLbl.BackgroundTransparency = 1
	rarityLbl.Text = unitRarity
	rarityLbl.TextColor3 = RARITY_COLOR[unitRarity] or Color3.fromRGB(200, 200, 200)
	rarityLbl.TextScaled = true
	rarityLbl.Font = Enum.Font.Gotham
	local dpsLbl = Instance.new("TextLabel", gui)
	dpsLbl.Size = UDim2.new(1, 0, 0.31, 0)
	dpsLbl.Position = UDim2.new(0, 0, 0.69, 0)
	dpsLbl.BackgroundTransparency = 1
	dpsLbl.Text = unitDps .. " DPS"
	dpsLbl.TextColor3 = Color3.fromRGB(100, 255, 130)
	dpsLbl.TextScaled = true
	dpsLbl.Font = Enum.Font.GothamBold

	table.insert(plotState.activeUnits, {
		block = block, bv = bv, bg = bg, def = def,
		lastAttack = 0, laneZ = laneZ,
	})
end

-- RemoteEvent for digging a grave
local digGraveRemote = Instance.new("RemoteEvent")
digGraveRemote.Name = "DigGrave"
digGraveRemote.Parent = ReplicatedStorage

-- RemoteEvent to send roll result back to client
local rollResultRemote = Instance.new("RemoteEvent")
rollResultRemote.Name = "RollResult"
rollResultRemote.Parent = ReplicatedStorage

-- RemoteEvent for spending gold (client tells server to deduct)
local spendGoldRemote = Instance.new("RemoteEvent")
spendGoldRemote.Name = "SpendGold"
spendGoldRemote.Parent = ReplicatedStorage

digGraveRemote.OnServerEvent:Connect(function(player, graveType)
	local grave = GRAVES[graveType]
	if not grave then
		return
	end

	-- Apply luck boost upgrade (each level = +10% to grave luck) + wheel luck buff
	local upgrades = getPlayerUpgrades(player)
	local wd = getWheelData(player)
	local buffMult = (tick() < wd.luckBuffEnd) and 2 or 1
	local boostedGrave = {
		luck = grave.luck * (1 + upgrades.luckBoost * 0.1) * buffMult,
		pityRarity = grave.pityRarity,
	}

	-- Roll rarity and unit
	local rarity = rollRarity(boostedGrave, player, graveType)
	local unitType = rollUnit(rarity)

	-- DON'T spawn the unit here anymore
	-- Just send the result to the client to add to collection
	local pity = getPity(player, graveType)
	local oneIn = getBaseOneIn(unitType)
	rollResultRemote:FireClient(player, unitType, rarity, pity, oneIn)
	print("🪦 " .. player.Name .. " dug up: " .. unitType .. " (" .. rarity .. ")")
end)

placeAtGraveRemote.OnServerEvent:Connect(function(player, unitType, spawnPos, slotIndex)
	if not UNITS[unitType] then return end
	local plotState = getPlot(player)
	if not plotState then return end
	spawnUnit(unitType, spawnPos, plotState)
	if slotIndex and plotState.graveSlots[slotIndex] then
		local slot = plotState.graveSlots[slotIndex]
		slot.occupied = true
		slot.unitType = unitType
		slot.unitEntry = plotState.activeUnits[#plotState.activeUnits]
		local dps = math.floor(UNITS[unitType].damage / UNITS[unitType].attackCD)
		local rarity = UNIT_RARITY[unitType] or "Common"
		slot.label.Text = "⚔️ " .. unitType
		slot.rarityLabel.Text = rarity
		slot.rarityLabel.TextColor3 = RARITY_COLOR[rarity] or Color3.fromRGB(200, 200, 200)
		slot.dpsLabel.Text = dps .. " DPS"
		slot.prompt.ActionText = "Recall"
		slot.prompt.ObjectText = "Grave " .. slotIndex .. " (" .. unitType .. ")"
	end
	print("🪦 " .. player.Name .. " placed " .. unitType .. " at grave " .. (slotIndex or "?"))
end)

local function clearSlot(i, plotState)
	local slot = plotState.graveSlots[i]
	if not slot or not slot.occupied then return nil end
	local unitType = slot.unitType
	if slot.unitEntry then
		for j = #plotState.activeUnits, 1, -1 do
			if plotState.activeUnits[j] == slot.unitEntry then
				if plotState.activeUnits[j].block and plotState.activeUnits[j].block.Parent then
					plotState.activeUnits[j].block:Destroy()
				end
				table.remove(plotState.activeUnits, j)
				break
			end
		end
	end
	slot.occupied = false
	slot.unitType = nil
	slot.unitEntry = nil
	slot.label.Text = "🪦 Empty"
	slot.rarityLabel.Text = ""
	slot.dpsLabel.Text = ""
	slot.prompt.ActionText = "Place Unit"
	slot.prompt.ObjectText = "Grave " .. i
	return { unitType = unitType, oneIn = getBaseOneIn(unitType) }
end

placeBestRemote.OnServerEvent:Connect(function(player, clientInventory)
	local plotState = getPlot(player)
	if not plotState then return end
	local pool = {}
	for i = 1, #plotState.graveSlots do
		local item = clearSlot(i, plotState)
		if item then table.insert(pool, item) end
	end
	if type(clientInventory) == "table" then
		for _, item in ipairs(clientInventory) do
			if item and item.unitType and UNITS[item.unitType] then
				table.insert(pool, { unitType = item.unitType, oneIn = item.oneIn or getBaseOneIn(item.unitType) })
			end
		end
	end
	table.sort(pool, function(a, b)
		local dA = UNITS[a.unitType] and (UNITS[a.unitType].damage / UNITS[a.unitType].attackCD) or 0
		local dB = UNITS[b.unitType] and (UNITS[b.unitType].damage / UNITS[b.unitType].attackCD) or 0
		return dA > dB
	end)
	local slotCount = #plotState.graveSlots
	for i, item in ipairs(pool) do
		if i > slotCount then break end
		local graveSpot = plotState.plotModel:FindFirstChild("GraveSpot" .. i)
		if graveSpot then
			local spawnPos = graveSpot.Position + Vector3.new(0, 2, 0)
			spawnUnit(item.unitType, spawnPos, plotState)
			local slot = plotState.graveSlots[i]
			slot.occupied = true
			slot.unitType = item.unitType
			slot.unitEntry = plotState.activeUnits[#plotState.activeUnits]
			local dps = math.floor(UNITS[item.unitType].damage / UNITS[item.unitType].attackCD)
			local rarity = UNIT_RARITY[item.unitType] or "Common"
			slot.label.Text = "⚔️ " .. item.unitType
			slot.rarityLabel.Text = rarity
			slot.rarityLabel.TextColor3 = RARITY_COLOR[rarity] or Color3.fromRGB(200, 200, 200)
			slot.dpsLabel.Text = dps .. " DPS"
			slot.prompt.ActionText = "Recall"
			slot.prompt.ObjectText = "Grave " .. i .. " (" .. item.unitType .. ")"
		end
	end
	local remaining = {}
	for i = slotCount + 1, #pool do table.insert(remaining, pool[i]) end
	placeBestResultRemote:FireClient(player, remaining)
	print("🏆 " .. player.Name .. " used Place Best — deployed " .. math.min(#pool, slotCount) .. " units")
end)

-- ── LUCKY WHEEL ──────────────────────────────────────────────
wheelSpinRemote.OnServerEvent:Connect(function(player, clientOutcomeIdx)
	local wd = getWheelData(player)
	if wd.spins <= 0 then
		return
	end
	wd.spins -= 1

	-- Use the client-nominated index (the animation already landed there)
	-- but re-validate server-side: we actually do our own roll and just use
	-- the client index for the animation; override the reward with our roll
	local idx, outcome = rollWheelOutcome()

	-- Award reward
	local rewardData = { outcomeIdx = idx, outcome = outcome }
	if outcome.id == "gold_1k" then
		addGoldRemote:FireClient(player, 1000, nil)
	elseif outcome.id == "luck_buff" then
		wd.luckBuffEnd = tick() + 300 -- 5 minutes
		rewardData.buffDuration = 300
	elseif outcome.id == "gems_50" then
		rewardData.gems = 50
	elseif outcome.id == "gems_100" then
		rewardData.gems = 100
	elseif outcome.id == "graves_5" then
		rewardData.graveType = outcome.graveType
		rewardData.graveCount = outcome.count
	elseif outcome.id == "grave_rare" then
		rewardData.graveType = outcome.graveType
		rewardData.graveCount = outcome.count
	elseif outcome.id == "lucky_box" then
		-- Roll 3 Legendary+ units as a bonus
		local boxUnits = {}
		local highRarities = { "Legendary", "Abyssal", "Eldritch", "Eternal" }
		local highWeights = { 60, 25, 10, 5 }
		for _ = 1, 3 do
			local rRoll = math.random(1, 100)
			local cum2 = 0
			local pickedRarity = "Legendary"
			for ri, w in ipairs(highWeights) do
				cum2 += w
				if rRoll <= cum2 then
					pickedRarity = highRarities[ri]
					break
				end
			end
			local unitType = rollUnit(pickedRarity)
			local oneIn = getBaseOneIn(unitType)
			table.insert(boxUnits, { unitType = unitType, oneIn = oneIn })
		end
		rewardData.boxUnits = boxUnits
	end

	-- Tell client the authoritative outcome index + reward payload
	wheelResultRemote:FireClient(player, rewardData)
	-- Send updated spin count
	local now = tick()
	local secondsUntilNext = math.max(0, math.floor(900 - (now - wd.lastGrantTime)))
	wheelSpinsUpdateRemote:FireClient(player, wd.spins, secondsUntilNext)
	print("🎡 " .. player.Name .. " spun wheel → " .. outcome.label)
end)

deployRemote.OnServerEvent:Connect(function(player, unitType, damage)
	local original = UNITS[unitType] and UNITS[unitType].damage
	if UNITS[unitType] then
		UNITS[unitType].damage = damage
	end
	local plotState2 = getPlot(player)
	if plotState2 then spawnUnit(unitType, nil, plotState2) end
	if UNITS[unitType] then UNITS[unitType].damage = original end
end)

undeployRemote.OnServerEvent:Connect(function(player, unitIndex)
	local plotState = getPlot(player)
	if not plotState then return end
	local u = plotState.activeUnits[unitIndex]
	if u then
		if u.block and u.block.Parent then u.block:Destroy() end
		table.remove(plotState.activeUnits, unitIndex)
	end
end)

ascendRemote.OnServerEvent:Connect(function(player)
	local plotState = getPlot(player)
	if not plotState then return end
	local nextSlot = #plotState.graveSlots + 1
	if nextSlot <= 10 then
		local graveSpot = plotState.plotModel:FindFirstChild("GraveSpot" .. nextSlot)
		if graveSpot then
			addGraveSlot(nextSlot, graveSpot.Position, plotState, tostring(player.UserId))
		end
	end
	resetWall(plotState)
	local graveSpot1 = plotState.plotModel:FindFirstChild("GraveSpot1")
	local nearX = graveSpot1 and (graveSpot1.Position.X - plotState.laneDir * 10) or (plotState.wallOriginX - plotState.laneDir * 60)
	for _, u in ipairs(plotState.activeUnits) do
		if u.block and u.block.Parent then
			u.block.CFrame = CFrame.new(nearX + math.random(-5, 5), 6, u.laneZ)
		end
	end
	print("⬆️ " .. player.Name .. " ascended — wall reset, graves: " .. #plotState.graveSlots)
end)

summonRemote.OnServerEvent:Connect(function(player, unitType)
	local plotState = getPlot(player)
	if plotState then spawnUnit(unitType, nil, plotState) end
end)

-- ============================================================
--  ATTACK FLASH
-- ============================================================
local function flashAttack(isGhost, position, plotState)
	local flash = Instance.new("Part")
	flash.Size = Vector3.new(1.5, 1.5, 0.3)
	flash.CFrame = CFrame.new(
		position or Vector3.new(
			plotState.wall.Position.X - plotState.laneDir * (plotState.wall.Size.X/2 + 0.2),
			1 + math.random(0, 8),
			plotState.plotCenterZ + math.random(-8, 8)
		)
	)
	flash.Anchored = true
	flash.CanCollide = false
	flash.BrickColor = isGhost and BrickColor.new("Pastel blue") or BrickColor.new("Bright yellow")
	flash.Material = Enum.Material.Neon
	flash.Parent = workspace
	game:GetService("Debris"):AddItem(flash, 0.2)
end

local function shootArrow(fromPos, targetPos, damage, plotState)
	local arrowStart = fromPos + Vector3.new(0, 0.5, 0)
	local arrow = Instance.new("Part")
	arrow.Size = Vector3.new(0.2, 0.2, 1.5)
	arrow.BrickColor = BrickColor.new("Bright green")
	arrow.Material = Enum.Material.Neon
	arrow.CastShadow = false
	arrow.CanCollide = false
	arrow.Anchored = true
	arrow.CFrame = CFrame.lookAt(arrowStart, targetPos)
	arrow.Parent = workspace
	local travelTime = (targetPos - arrowStart).Magnitude / 60
	TweenService:Create(
		arrow,
		TweenInfo.new(travelTime, Enum.EasingStyle.Linear),
		{ CFrame = CFrame.lookAt(targetPos, targetPos + (targetPos - arrowStart).Unit) }
	):Play()
	task.delay(travelTime, function()
		if arrow and arrow.Parent then arrow:Destroy() end
		flashAttack(true, targetPos, plotState)
		plotState.wallHP = math.max(0, plotState.wallHP - damage)
		updateWallGui(plotState)
		damageRemote:FireAllClients(damage, targetPos, true)
		if plotState.wallHP <= 0 then breakWall(plotState) end
	end)
end

-- ============================================================
--  MAIN LOOP
-- ============================================================
local lastRegen = tick()
local lastSpinCheck = tick()

RunService.Heartbeat:Connect(function(dt)
	local now = tick()

	-- Wall regen + spin grants
	if now - lastRegen >= 1 then
		lastRegen = now
		for _, plotState in pairs(playerPlots) do
			if plotState.wallHP < plotState.WALL_MAX_HP then
				plotState.wallHP = math.min(plotState.wallHP + plotState.wallRegen, plotState.WALL_MAX_HP)
			end
			updateWallGui(plotState)
		end
	end
	if now - lastSpinCheck >= 10 then
		lastSpinCheck = now
		for _, p in ipairs(Players:GetPlayers()) do
			local wd = getWheelData(p)
			if now - wd.lastGrantTime >= 900 then
				wd.lastGrantTime = wd.lastGrantTime + 900
				wd.spins += 1
				local secondsUntilNext = math.max(0, math.floor(900 - (now - wd.lastGrantTime)))
				wheelSpinsUpdateRemote:FireClient(p, wd.spins, secondsUntilNext)
			end
			-- Restock shop if timer expired
			local sd = playerShopData[tostring(p.UserId)]
			if sd and now >= sd.nextRestock then
				generateRotation(p)
				sendShopUpdate(p)
			end
		end
	end

	-- Unit AI — iterate over every player's plot
	for _, plotState in pairs(playerPlots) do
		if not plotState.wall or not plotState.wall.Parent then continue end

		for i = #plotState.activeUnits, 1, -1 do
			local u = plotState.activeUnits[i]
			if not u.block.Parent then
				table.remove(plotState.activeUnits, i)
				continue
			end
			if not u.phase then u.phase = math.random() * math.pi * 2 end

			local pos = u.block.Position
			local flatPos    = Vector3.new(pos.X, 0, pos.Z)
			local flatTarget = Vector3.new(plotState.wallTarget.X, 0, u.laneZ)
			local dist = (flatPos - flatTarget).Magnitude

			if dist <= u.def.attackRange then
				u.bv.Velocity = Vector3.new(0, 0, 0)
				u.bg.CFrame = CFrame.new(pos, Vector3.new(plotState.wall.Position.X, pos.Y, pos.Z))

				local gui = u.block:FindFirstChildOfClass("BillboardGui")
				if gui then
					gui.StudsOffset = Vector3.new(0, 1.5 + math.sin(now*3 + u.phase)*0.4, 0)
				end

				if u.block.Name == "Goblin" then
					local poison = UNITS.Goblin.poison or 1
					plotState.wallHP = math.max(0, plotState.wallHP - poison * dt)
					updateWallGui(plotState)
					if plotState.wallHP <= 0 then breakWall(plotState) end
				end

				if now - u.lastAttack >= u.def.attackCD then
					u.lastAttack = now
					local fromPos = u.block.Position
					local wallFaceX = plotState.wall.Position.X - plotState.laneDir * plotState.wall.Size.X/2
					local targetPos = Vector3.new(wallFaceX, fromPos.Y + 0.5, fromPos.Z)
					if u.block.Name == "Goblin" then
						shootArrow(fromPos, targetPos, u.def.damage, plotState)
					else
						local impactPos = Vector3.new(
							wallFaceX,
							2 + math.random(0, 7),
							plotState.plotCenterZ + math.random(-8, 8)
						)
						flashAttack(u.def.transparent, impactPos, plotState)
						plotState.wallHP = math.max(0, plotState.wallHP - u.def.damage)
						updateWallGui(plotState)
						damageRemote:FireAllClients(u.def.damage, impactPos, u.def.transparent)
						if plotState.wallHP <= 0 then breakWall(plotState) end
					end
				end
			else
				local dir = (flatTarget - flatPos).Unit
				u.bv.Velocity = Vector3.new(dir.X * u.def.speed, 0, dir.Z * u.def.speed)
				u.bg.CFrame = CFrame.new(pos, pos + Vector3.new(dir.X, 0, dir.Z))

				local gui = u.block:FindFirstChildOfClass("BillboardGui")
				if gui then
					gui.StudsOffset = Vector3.new(0, 1.5 + math.abs(math.sin(now*8 + u.phase))*0.3, 0)
				end
			end
		end
	end
end)
