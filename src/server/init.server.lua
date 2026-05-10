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

local wheelSpinRemote = Instance.new("RemoteEvent")
wheelSpinRemote.Name = "WheelSpin"
wheelSpinRemote.Parent = ReplicatedStorage

local wheelResultRemote = Instance.new("RemoteEvent")
wheelResultRemote.Name = "WheelResult"
wheelResultRemote.Parent = ReplicatedStorage

local wheelSpinsUpdateRemote = Instance.new("RemoteEvent")
wheelSpinsUpdateRemote.Name = "WheelSpinsUpdate"
wheelSpinsUpdateRemote.Parent = ReplicatedStorage

-- ============================================================
--  WORLD SETUP
-- ============================================================

-- Delete the default Baseplate if it exists (stops floor flickering)
local baseplate = workspace:FindFirstChild("Baseplate")
if baseplate then
	baseplate:Destroy()
end

-- Ground
local ground = Instance.new("Part")
ground.Name = "Ground"
ground.Size = Vector3.new(160, 4, 100)
ground.Position = Vector3.new(0, -2, 0)
ground.Anchored = true
ground.BrickColor = BrickColor.new("Medium stone grey")
ground.Material = Enum.Material.SmoothPlastic
ground.TopSurface = Enum.SurfaceType.Smooth
ground.Parent = workspace

-- Move spawn location to the left side
local spawnLoc = workspace:FindFirstChildOfClass("SpawnLocation")
if spawnLoc then
	spawnLoc.Position = Vector3.new(-50, 1, 0)
end

-- Summon zone marker (just a flat coloured slab)
local spawnMarker = Instance.new("Part")
spawnMarker.Name = "SpawnZone"
spawnMarker.Size = Vector3.new(20, 0.2, 30)
spawnMarker.Position = Vector3.new(-40, 0.1, 0)
spawnMarker.Anchored = true
spawnMarker.CanCollide = false
spawnMarker.BrickColor = BrickColor.new("Lilac")
spawnMarker.Material = Enum.Material.Neon
spawnMarker.Transparency = 0.5
spawnMarker.Parent = workspace

-- ============================================================
--  GRAVE SLOTS  (5 at start, +1 per ascension up to 10)
-- ============================================================
local ALL_GRAVE_POSITIONS = {
	-- Row 1 (start unlocked)
	Vector3.new(-28, 0, -8),
	Vector3.new(-28, 0, -4),
	Vector3.new(-28, 0, 0),
	Vector3.new(-28, 0, 4),
	Vector3.new(-28, 0, 8),
	-- Row 2 (unlocked via ascension)
	Vector3.new(-24, 0, -8),
	Vector3.new(-24, 0, -4),
	Vector3.new(-24, 0, 0),
	Vector3.new(-24, 0, 4),
	Vector3.new(-24, 0, 8),
}

local graveSlots = {}
local recallUnitFromSlot -- forward declared; defined after activeUnits

local function addGraveSlot(i)
	local basePos = ALL_GRAVE_POSITIONS[i]
	if not basePos then
		return
	end

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
	stone.Position = basePos + Vector3.new(0, 1.9, -0.9)
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

	graveSlots[i] = {
		slab = slab,
		stone = stone,
		label = lbl,
		rarityLabel = rarityLbl,
		dpsLabel = dpsLbl,
		prompt = prompt,
		occupied = false,
	}

	local idx = i
	local spawnPoint = basePos + Vector3.new(0, 2, 0)
	prompt.Triggered:Connect(function(player)
		if graveSlots[idx].occupied then
			recallUnitFromSlot(idx, player)
		else
			selectGraveRemote:FireClient(player, spawnPoint, idx)
		end
	end)
end

-- Start with 5 slots
for i = 1, 5 do
	addGraveSlot(i)
end

-- Grave Shopkeeper NPC
local graveNPC = Instance.new("Part")
graveNPC.Name = "GraveShopkeeper"
graveNPC.Size = Vector3.new(2, 4, 2)
graveNPC.Position = Vector3.new(-50, 2, 18)
graveNPC.Anchored = true
graveNPC.BrickColor = BrickColor.new("Bright violet")
graveNPC.Material = Enum.Material.SmoothPlastic
graveNPC.Parent = workspace

local graveHead = Instance.new("Part")
graveHead.Size = Vector3.new(2.2, 2.2, 2.2)
graveHead.Position = Vector3.new(-50, 5.1, 18)
graveHead.Anchored = true
graveHead.BrickColor = BrickColor.new("Bright violet")
graveHead.Material = Enum.Material.SmoothPlastic
graveHead.Parent = workspace
local graveWeld = Instance.new("WeldConstraint")
graveWeld.Part0 = graveNPC
graveWeld.Part1 = graveHead
graveWeld.Parent = graveNPC

-- Grave NPC label
local graveGui = Instance.new("BillboardGui", graveNPC)
graveGui.Size = UDim2.new(0, 160, 0, 50)
graveGui.StudsOffset = Vector3.new(0, 5, 0)
graveGui.AlwaysOnTop = false
local graveLbl = Instance.new("TextLabel", graveGui)
graveLbl.Size = UDim2.new(1, 0, 1, 0)
graveLbl.BackgroundTransparency = 1
graveLbl.Text = "🪦 Buy Units"
graveLbl.TextColor3 = Color3.fromRGB(200, 180, 255)
graveLbl.TextScaled = true
graveLbl.Font = Enum.Font.GothamBold

-- ProximityPrompt on grave NPC
local gravePrompt = Instance.new("ProximityPrompt")
gravePrompt.ActionText = "Open"
gravePrompt.ObjectText = "Buy Units"
gravePrompt.KeyboardKeyCode = Enum.KeyCode.E
gravePrompt.MaxActivationDistance = 10
gravePrompt.Parent = graveNPC

local openGraveRemote = Instance.new("RemoteEvent")
openGraveRemote.Name = "OpenGrave"
openGraveRemote.Parent = ReplicatedStorage

gravePrompt.Triggered:Connect(function(player)
	openGraveRemote:FireClient(player)
end)

-- ============================================================
--  SELL SHOPKEEPER NPC
-- ============================================================
local sellNPC = Instance.new("Part")
sellNPC.Name = "SellShopkeeper"
sellNPC.Size = Vector3.new(2, 4, 2)
sellNPC.Position = Vector3.new(-50, 2, -18)
sellNPC.Anchored = true
sellNPC.BrickColor = BrickColor.new("Bright orange")
sellNPC.Material = Enum.Material.SmoothPlastic
sellNPC.Parent = workspace

local sellHead = Instance.new("Part")
sellHead.Size = Vector3.new(2.2, 2.2, 2.2)
sellHead.Position = Vector3.new(-50, 5.1, -18)
sellHead.Anchored = true
sellHead.BrickColor = BrickColor.new("Bright orange")
sellHead.Material = Enum.Material.SmoothPlastic
sellHead.Parent = workspace
local sellWeld = Instance.new("WeldConstraint")
sellWeld.Part0 = sellNPC
sellWeld.Part1 = sellHead
sellWeld.Parent = sellNPC

local sellGui = Instance.new("BillboardGui", sellNPC)
sellGui.Size = UDim2.new(0, 160, 0, 50)
sellGui.StudsOffset = Vector3.new(0, 5, 0)
sellGui.AlwaysOnTop = false
local sellLbl = Instance.new("TextLabel", sellGui)
sellLbl.Size = UDim2.new(1, 0, 1, 0)
sellLbl.BackgroundTransparency = 1
sellLbl.Text = "💰 Sell Units"
sellLbl.TextColor3 = Color3.fromRGB(255, 220, 100)
sellLbl.TextScaled = true
sellLbl.Font = Enum.Font.GothamBold

local sellPrompt = Instance.new("ProximityPrompt")
sellPrompt.ActionText = "Open"
sellPrompt.ObjectText = "Sell Units"
sellPrompt.KeyboardKeyCode = Enum.KeyCode.E
sellPrompt.MaxActivationDistance = 10
sellPrompt.Parent = sellNPC

local openSellRemote = Instance.new("RemoteEvent")
openSellRemote.Name = "OpenSell"
openSellRemote.Parent = ReplicatedStorage

sellPrompt.Triggered:Connect(function(player)
	openSellRemote:FireClient(player)
end)

-- SellUnit remote — client sends (unitType, oneIn); server gives gold back
local sellUnitRemote = Instance.new("RemoteEvent")
sellUnitRemote.Name = "SellUnit"
sellUnitRemote.Parent = ReplicatedStorage

-- Created at startup so the client's WaitForChild finds it immediately
local addGoldRemote = Instance.new("RemoteEvent")
addGoldRemote.Name = "AddGold"
addGoldRemote.Parent = ReplicatedStorage

sellUnitRemote.OnServerEvent:Connect(function(player, unitType, oneIn)
	if not unitType or not oneIn then
		return
	end
	local sellValue = math.floor(oneIn ^ 1.2 * 5)
	addGoldRemote:FireClient(player, sellValue, unitType)
	print("💰 " .. player.Name .. " sold " .. unitType .. " for " .. sellValue .. " gold")
end)

-- ============================================================
--  UPGRADE NPC
-- ============================================================
local upgradeNPC = Instance.new("Part")
upgradeNPC.Name = "UpgradeShopkeeper"
upgradeNPC.Size = Vector3.new(2, 4, 2)
upgradeNPC.Position = Vector3.new(-50, 2, 0)
upgradeNPC.Anchored = true
upgradeNPC.BrickColor = BrickColor.new("Cyan")
upgradeNPC.Material = Enum.Material.SmoothPlastic
upgradeNPC.Parent = workspace

local upgradeHead = Instance.new("Part")
upgradeHead.Size = Vector3.new(2.2, 2.2, 2.2)
upgradeHead.Position = Vector3.new(-50, 5.1, 0)
upgradeHead.Anchored = true
upgradeHead.BrickColor = BrickColor.new("Cyan")
upgradeHead.Material = Enum.Material.SmoothPlastic
upgradeHead.Parent = workspace
local upgradeWeld = Instance.new("WeldConstraint")
upgradeWeld.Part0 = upgradeNPC
upgradeWeld.Part1 = upgradeHead
upgradeWeld.Parent = upgradeNPC

local upgradeGui = Instance.new("BillboardGui", upgradeNPC)
upgradeGui.Size = UDim2.new(0, 160, 0, 50)
upgradeGui.StudsOffset = Vector3.new(0, 5, 0)
upgradeGui.AlwaysOnTop = false
local upgradeLbl = Instance.new("TextLabel", upgradeGui)
upgradeLbl.Size = UDim2.new(1, 0, 1, 0)
upgradeLbl.BackgroundTransparency = 1
upgradeLbl.Text = "⚗️ Upgrades"
upgradeLbl.TextColor3 = Color3.fromRGB(100, 255, 240)
upgradeLbl.TextScaled = true
upgradeLbl.Font = Enum.Font.GothamBold

local upgradePrompt = Instance.new("ProximityPrompt")
upgradePrompt.ActionText = "Open"
upgradePrompt.ObjectText = "Upgrades"
upgradePrompt.KeyboardKeyCode = Enum.KeyCode.E
upgradePrompt.MaxActivationDistance = 10
upgradePrompt.Parent = upgradeNPC

local openUpgradeRemote = Instance.new("RemoteEvent")
openUpgradeRemote.Name = "OpenUpgrade"
openUpgradeRemote.Parent = ReplicatedStorage

upgradePrompt.Triggered:Connect(function(player)
	openUpgradeRemote:FireClient(player)
end)

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

Players.PlayerAdded:Connect(function(player)
	local wd = getWheelData(player)
	-- Notify client of starting spin count once character loads
	player.CharacterAdded:Connect(function()
		task.wait(1)
		local secsLeft = math.max(0, math.floor(900 - (tick() - wd.lastGrantTime)))
		wheelSpinsUpdateRemote:FireClient(player, wd.spins, secsLeft)
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	local id = tostring(player.UserId)
	playerWheelData[id] = nil
	playerUpgrades[id] = nil
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
--  THE WALL
-- ============================================================
local hpFill
local hpText
local WALL_MAX_HP = 500
local wallHP = WALL_MAX_HP
local wallLayer = 1
local wallRegen = 1 -- HP/sec
local goldMultiplier = 1.0
local WALL_SPACING = 60
local wallTarget

local wall = Instance.new("Part")
wall.Name = "TheWall"
wall.Size = Vector3.new(4, 20, 100)
wall.Position = Vector3.new(40, 10, 0)
wall.Anchored = true
wall.BrickColor = BrickColor.new("Medium stone grey")
wall.Material = Enum.Material.SmoothPlastic
wall.Parent = workspace

wallTarget = Vector3.new(wall.Position.X - wall.Size.X / 2 - 3, 0, 0)

-- HP bar floating above the wall
local wallGui = Instance.new("BillboardGui", wall)
wallGui.Size = UDim2.new(0, 260, 0, 55)
wallGui.StudsOffset = Vector3.new(0, 14, 0)
wallGui.AlwaysOnTop = true

local hpBg = Instance.new("Frame", wallGui)
hpBg.Size = UDim2.new(1, 0, 0.5, 0)
hpBg.Position = UDim2.new(0, 0, 0.1, 0)
hpBg.BackgroundColor3 = Color3.fromRGB(60, 20, 20)
hpBg.BorderSizePixel = 0
Instance.new("UICorner", hpBg).CornerRadius = UDim.new(0, 6)

hpFill = Instance.new("Frame", hpBg)
hpFill.Size = UDim2.new(1, 0, 1, 0)
hpFill.BackgroundColor3 = Color3.fromRGB(220, 60, 60)
hpFill.BorderSizePixel = 0
Instance.new("UICorner", hpFill).CornerRadius = UDim.new(0, 6)

hpText = Instance.new("TextLabel", wallGui)
hpText.Size = UDim2.new(1, 0, 0.38, 0)
hpText.Position = UDim2.new(0, 0, 0.62, 0)
hpText.BackgroundTransparency = 1
hpText.TextColor3 = Color3.fromRGB(255, 210, 210)
hpText.TextScaled = true
hpText.Font = Enum.Font.GothamBold

local function updateWallGui()
	local pct = math.clamp(wallHP / WALL_MAX_HP, 0, 1)
	hpFill.Size = UDim2.new(pct, 0, 1, 0)
	hpFill.BackgroundColor3 = Color3.fromRGB(220, math.floor(60 * pct), math.floor(60 * pct))
	hpText.Text = "Layer " .. wallLayer .. "  " .. math.floor(wallHP) .. " / " .. WALL_MAX_HP
end

local LAYER_COLORS = {
	BrickColor.new("Medium stone grey"),
	BrickColor.new("Bright green"),
	BrickColor.new("Bright blue"),
	BrickColor.new("Bright violet"),
	BrickColor.new("Bright pink"),
}

local function breakWall()
	wallLayer += 1
	WALL_MAX_HP = math.floor(500 * (2 ^ (wallLayer - 1)))
	wallHP = WALL_MAX_HP
	wallRegen = wallLayer * 2

	-- Save position before destroying
	local oldX = wall.Position.X

	-- Flash old wall white then destroy it
	wall.BrickColor = BrickColor.new("White")
	wall:Destroy()

	-- New wall position: further along the X axis
	local newX = oldX + WALL_SPACING
	local newColor = LAYER_COLORS[((wallLayer - 1) % #LAYER_COLORS) + 1]

	-- Build the new wall
	wall = Instance.new("Part")
	wall.Name = "TheWall"
	wall.Size = Vector3.new(4, 20, 100)
	wall.Position = Vector3.new(newX, 10, 0)
	wall.Anchored = true
	wall.BrickColor = newColor
	wall.Material = Enum.Material.SmoothPlastic
	wall.Parent = workspace

	-- Rebuild the HP bar GUI on the new wall
	local newGui = Instance.new("BillboardGui", wall)
	newGui.Size = UDim2.new(0, 260, 0, 55)
	newGui.StudsOffset = Vector3.new(0, 14, 0)
	newGui.AlwaysOnTop = true

	local newHpBg = Instance.new("Frame", newGui)
	newHpBg.Size = UDim2.new(1, 0, 0.5, 0)
	newHpBg.Position = UDim2.new(0, 0, 0.1, 0)
	newHpBg.BackgroundColor3 = Color3.fromRGB(60, 20, 20)
	newHpBg.BorderSizePixel = 0
	Instance.new("UICorner", newHpBg).CornerRadius = UDim.new(0, 6)

	hpFill = Instance.new("Frame", newHpBg)
	hpFill.Size = UDim2.new(1, 0, 1, 0)
	hpFill.BackgroundColor3 = Color3.fromRGB(220, 60, 60)
	hpFill.BorderSizePixel = 0
	Instance.new("UICorner", hpFill).CornerRadius = UDim.new(0, 6)

	hpText = Instance.new("TextLabel", newGui)
	hpText.Size = UDim2.new(1, 0, 0.38, 0)
	hpText.Position = UDim2.new(0, 0, 0.62, 0)
	hpText.BackgroundTransparency = 1
	hpText.TextColor3 = Color3.fromRGB(255, 210, 210)
	hpText.TextScaled = true
	hpText.Font = Enum.Font.GothamBold

	-- Extend the ground forward to cover the new section
	-- We just spawn a new ground slab ahead of the current one
	local groundExtension = Instance.new("Part")
	groundExtension.Name = "GroundExt"
	groundExtension.Size = Vector3.new(WALL_SPACING, 4, 100)
	groundExtension.Position = Vector3.new(newX - WALL_SPACING / 2, -2, 0)
	groundExtension.Anchored = true
	groundExtension.BrickColor = BrickColor.new("Medium stone grey")
	groundExtension.Material = Enum.Material.SmoothPlastic
	groundExtension.TopSurface = Enum.SurfaceType.Smooth
	groundExtension.Parent = workspace

	-- Update wallTarget so all units start walking to the new wall
	wallTarget = Vector3.new(wall.Position.X - wall.Size.X / 2 - 3, 0, 0)

	updateWallGui()

	-- Rewards
	local goldReward = math.floor(1000 * wallLayer * goldMultiplier)
	for _, p in ipairs(Players:GetPlayers()) do
		wallBreakRemote:FireClient(p, goldReward, wallLayer - 1)
	end
	print("🎉 Wall " .. (wallLayer - 1) .. " broken! New wall at X=" .. newX)
end

updateWallGui()

-- Reset wall back to layer 1 at the starting position (called on ascension)
local function resetWall()
	-- Destroy current wall
	if wall and wall.Parent then
		wall:Destroy()
	end
	-- Remove all ground extension slabs spawned by breakWall
	for _, part in ipairs(workspace:GetChildren()) do
		if part.Name == "GroundExt" then
			part:Destroy()
		end
	end
	-- Reset wall state variables
	wallLayer = 1
	WALL_MAX_HP = 500
	wallHP = WALL_MAX_HP
	wallRegen = 1
	-- Rebuild wall at original starting position
	wall = Instance.new("Part")
	wall.Name = "TheWall"
	wall.Size = Vector3.new(4, 20, 100)
	wall.Position = Vector3.new(40, 10, 0)
	wall.Anchored = true
	wall.BrickColor = BrickColor.new("Medium stone grey")
	wall.Material = Enum.Material.SmoothPlastic
	wall.Parent = workspace
	-- Rebuild HP bar GUI on the new wall
	local newGui = Instance.new("BillboardGui", wall)
	newGui.Size = UDim2.new(0, 260, 0, 55)
	newGui.StudsOffset = Vector3.new(0, 14, 0)
	newGui.AlwaysOnTop = true
	local newHpBg = Instance.new("Frame", newGui)
	newHpBg.Size = UDim2.new(1, 0, 0.5, 0)
	newHpBg.Position = UDim2.new(0, 0, 0.1, 0)
	newHpBg.BackgroundColor3 = Color3.fromRGB(60, 20, 20)
	newHpBg.BorderSizePixel = 0
	Instance.new("UICorner", newHpBg).CornerRadius = UDim.new(0, 6)
	hpFill = Instance.new("Frame", newHpBg)
	hpFill.Size = UDim2.new(1, 0, 1, 0)
	hpFill.BackgroundColor3 = Color3.fromRGB(220, 60, 60)
	hpFill.BorderSizePixel = 0
	Instance.new("UICorner", hpFill).CornerRadius = UDim.new(0, 6)
	hpText = Instance.new("TextLabel", newGui)
	hpText.Size = UDim2.new(1, 0, 0.38, 0)
	hpText.Position = UDim2.new(0, 0, 0.62, 0)
	hpText.BackgroundTransparency = 1
	hpText.TextColor3 = Color3.fromRGB(255, 210, 210)
	hpText.TextScaled = true
	hpText.Font = Enum.Font.GothamBold
	-- Reset wall target for unit AI
	wallTarget = Vector3.new(wall.Position.X - wall.Size.X / 2 - 3, 0, 0)
	updateWallGui()
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

local activeUnits = {}

recallUnitFromSlot = function(slotIndex, player)
	local slot = graveSlots[slotIndex]
	if not slot or not slot.occupied then
		return
	end
	-- Destroy the unit block and remove it from activeUnits
	if slot.unitEntry then
		for i = #activeUnits, 1, -1 do
			if activeUnits[i] == slot.unitEntry then
				if activeUnits[i].block and activeUnits[i].block.Parent then
					activeUnits[i].block:Destroy()
				end
				table.remove(activeUnits, i)
				break
			end
		end
	end
	-- Return the unit to the player's inventory
	recallUnitRemote:FireClient(player, slot.unitType, getBaseOneIn(slot.unitType))
	-- Free the slot
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

local function spawnUnit(unitType, customPos)
	local def = UNITS[unitType]
	if not def then
		return
	end
	-- When spawning from a grave slot use its Z so the unit walks straight to the wall
	local laneZ = customPos and customPos.Z or math.random(-45, 45)

	-- Use the given grave position or pick a random spot in the spawn zone.
	-- When spawning from a grave, push the unit forward (toward the wall) by half its
	-- size + 2 studs so large units don't clip into or get stuck on the gravestone.
	local forwardClearance = def.size.X / 2 + 2
	local spawnPos = customPos and Vector3.new(customPos.X + forwardClearance, customPos.Y, customPos.Z)
		or Vector3.new(
			-40 + math.random(-8, 8),
			4, -- start a little above ground so it drops naturally
			math.random(-12, 12)
		)

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
	bg.CFrame = CFrame.new(spawnPos, Vector3.new(wallTarget.X, spawnPos.Y, wallTarget.Z))
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

	table.insert(activeUnits, {
		block = block,
		bv = bv,
		bg = bg,
		def = def,
		lastAttack = 0,
		laneZ = laneZ,
	})

	print("Spawned unit with laneZ:", laneZ)
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
	if not UNITS[unitType] then
		return
	end
	spawnUnit(unitType, spawnPos)
	if slotIndex and graveSlots[slotIndex] then
		local slot = graveSlots[slotIndex]
		slot.occupied = true
		slot.unitType = unitType
		slot.unitEntry = activeUnits[#activeUnits]
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

-- Helper: silently recall a slot without firing RecallUnit to the client
local function clearSlot(i)
	local slot = graveSlots[i]
	if not slot or not slot.occupied then
		return nil
	end
	local unitType = slot.unitType
	if slot.unitEntry then
		for j = #activeUnits, 1, -1 do
			if activeUnits[j] == slot.unitEntry then
				if activeUnits[j].block and activeUnits[j].block.Parent then
					activeUnits[j].block:Destroy()
				end
				table.remove(activeUnits, j)
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
	-- Pool: units in graves + units sent from client inventory
	local pool = {}

	for i = 1, #graveSlots do
		local item = clearSlot(i)
		if item then
			table.insert(pool, item)
		end
	end

	if type(clientInventory) == "table" then
		for _, item in ipairs(clientInventory) do
			if item and item.unitType and UNITS[item.unitType] then
				table.insert(pool, {
					unitType = item.unitType,
					oneIn = item.oneIn or getBaseOneIn(item.unitType),
				})
			end
		end
	end

	-- Sort pool by DPS descending
	table.sort(pool, function(a, b)
		local dA = UNITS[a.unitType] and (UNITS[a.unitType].damage / UNITS[a.unitType].attackCD) or 0
		local dB = UNITS[b.unitType] and (UNITS[b.unitType].damage / UNITS[b.unitType].attackCD) or 0
		return dA > dB
	end)

	-- Deploy best units into available grave slots
	local slotCount = #graveSlots
	for i, item in ipairs(pool) do
		if i > slotCount then
			break
		end
		local basePos = ALL_GRAVE_POSITIONS[i]
		local spawnPos = basePos + Vector3.new(0, 2, 0)
		spawnUnit(item.unitType, spawnPos)
		local slot = graveSlots[i]
		slot.occupied = true
		slot.unitType = item.unitType
		slot.unitEntry = activeUnits[#activeUnits]
		local dps = math.floor(UNITS[item.unitType].damage / UNITS[item.unitType].attackCD)
		local rarity = UNIT_RARITY[item.unitType] or "Common"
		slot.label.Text = "⚔️ " .. item.unitType
		slot.rarityLabel.Text = rarity
		slot.rarityLabel.TextColor3 = RARITY_COLOR[rarity] or Color3.fromRGB(200, 200, 200)
		slot.dpsLabel.Text = dps .. " DPS"
		slot.prompt.ActionText = "Recall"
		slot.prompt.ObjectText = "Grave " .. i .. " (" .. item.unitType .. ")"
	end

	-- Remaining units (beyond slot count) go back to client
	local remaining = {}
	for i = slotCount + 1, #pool do
		table.insert(remaining, pool[i])
	end
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
	spawnUnit(unitType)
	if UNITS[unitType] then
		UNITS[unitType].damage = original
	end
end)

undeployRemote.OnServerEvent:Connect(function(player, unitIndex)
	local u = activeUnits[unitIndex]
	if u then
		if u.block and u.block.Parent then
			u.block:Destroy()
		end
		table.remove(activeUnits, unitIndex)
	end
end)

ascendRemote.OnServerEvent:Connect(function(player)
	-- Unlock a new grave slot (up to 10 max)
	local nextSlot = #graveSlots + 1
	if nextSlot <= 10 then
		addGraveSlot(nextSlot)
	end
	-- Reset wall back to layer 1
	resetWall()
	-- Teleport all deployed units back to the spawn zone so they walk toward the new wall
	-- (without this they'd be stranded beyond the ground and fall off)
	-- Teleport in front of the grave deployment slots (which sit at X=-28 to X=-24)
	-- so units don't have to walk through headstones to reach the wall
	for _, u in ipairs(activeUnits) do
		if u.block and u.block.Parent then
			u.block.CFrame = CFrame.new(-10 + math.random(-5, 5), 6, u.laneZ)
		end
	end
	print("⬆️ " .. player.Name .. " ascended — wall reset, units returned to spawn, graves: " .. #graveSlots)
end)
-- ============================================================
--  ACTIVE UNITS
-- ============================================================

-- ============================================================
--  SUMMON REMOTE
-- ============================================================
summonRemote.OnServerEvent:Connect(function(player, unitType)
	spawnUnit(unitType)
	print("Summoned " .. unitType .. " for " .. player.Name)
end)

-- ============================================================
--  ATTACK FLASH
-- ============================================================
local function flashAttack(isGhost, position)
	local flash = Instance.new("Part")
	flash.Size = Vector3.new(1.5, 1.5, 0.3)
	flash.CFrame = CFrame.new(
		position or Vector3.new(wall.Position.X - wall.Size.X / 2 - 0.2, 1 + math.random(0, 8), math.random(-14, 14))
	)
	flash.Anchored = true
	flash.CanCollide = false
	flash.BrickColor = isGhost and BrickColor.new("Pastel blue") or BrickColor.new("Bright yellow")
	flash.Material = Enum.Material.Neon
	flash.Parent = workspace
	game:GetService("Debris"):AddItem(flash, 0.2)
end

local function shootArrow(fromPos, targetPos, damage)
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
		if arrow and arrow.Parent then
			arrow:Destroy()
		end
		flashAttack(true, targetPos)
		wallHP = math.max(0, wallHP - damage)
		updateWallGui()
		damageRemote:FireAllClients(damage, targetPos, true)
		if wallHP <= 0 then
			breakWall()
		end
	end)
end

-- ============================================================
--  MAIN LOOP
-- ============================================================
local lastRegen = tick()
local lastSpinCheck = tick()

RunService.Heartbeat:Connect(function(dt)
	local now = tick()

	-- Wall regen once per second
	if now - lastRegen >= 1 then
		lastRegen = now
		if wallHP < WALL_MAX_HP then
			wallHP = math.min(wallHP + wallRegen, WALL_MAX_HP)
		end
		updateWallGui()
	end
	-- Grant wheel spins every 15 minutes of playtime (check every 10 s)
	if now - lastSpinCheck >= 10 then
		lastSpinCheck = now
		for _, p in ipairs(Players:GetPlayers()) do
			local wd = getWheelData(p)
			if now - wd.lastGrantTime >= 900 then
				wd.lastGrantTime = wd.lastGrantTime + 900
				wd.spins += 1
				local secondsUntilNext = math.max(0, math.floor(900 - (now - wd.lastGrantTime)))
				wheelSpinsUpdateRemote:FireClient(p, wd.spins, secondsUntilNext)
				print("🎡 Granted spin to " .. p.Name .. " (total: " .. wd.spins .. ")")
			end
		end
	end

	for i = #activeUnits, 1, -1 do
		local u = activeUnits[i]
		if not u.block.Parent then
			table.remove(activeUnits, i)
			continue
		end

		if not u.phase then
			u.phase = math.random() * math.pi * 2
		end

		local pos = u.block.Position
		local flatPos = Vector3.new(pos.X, 0, pos.Z)
		local flatTarget = Vector3.new(wallTarget.X, 0, u.laneZ)
		local dist = (flatPos - flatTarget).Magnitude

		if dist <= u.def.attackRange then
			u.bv.Velocity = Vector3.new(0, 0, 0)
			u.bg.CFrame = CFrame.new(pos, Vector3.new(wall.Position.X, pos.Y, pos.Z))

			local gui = u.block:FindFirstChildOfClass("BillboardGui")
			if gui then
				local bob = math.sin(now * 3 + u.phase) * 0.4
				gui.StudsOffset = Vector3.new(0, 1.5 + bob, 0)
			end

			-- Goblin poison: drains wall every frame via dt
			if u.block.Name == "Goblin" then
				local poison = UNITS.Goblin.poison or 1
				wallHP = math.max(0, wallHP - poison * dt)
				updateWallGui()
				if wallHP <= 0 then
					breakWall()
				end
			end

			-- Regular attack tick
			if now - u.lastAttack >= u.def.attackCD then
				u.lastAttack = now
				local fromPos = u.block.Position
				local targetPos = Vector3.new(wall.Position.X - wall.Size.X / 2, fromPos.Y + 0.5, fromPos.Z)
				if u.block.Name == "Goblin" then
					shootArrow(fromPos, targetPos, u.def.damage)
				else
					flashAttack(u.def.transparent)
					wallHP = math.max(0, wallHP - u.def.damage)
					updateWallGui()
					local impactPos =
						Vector3.new(wall.Position.X - wall.Size.X / 2, 2 + math.random(0, 7), math.random(-14, 14))
					damageRemote:FireAllClients(u.def.damage, impactPos, u.def.transparent)
					if wallHP <= 0 then
						breakWall()
					end
				end
			end
		else
			local dir = (flatTarget - flatPos).Unit
			u.bv.Velocity = Vector3.new(dir.X * u.def.speed, 0, dir.Z * u.def.speed)
			u.bg.CFrame = CFrame.new(pos, pos + Vector3.new(dir.X, 0, dir.Z))

			local gui = u.block:FindFirstChildOfClass("BillboardGui")
			if gui then
				local bob = math.abs(math.sin(now * 8 + u.phase)) * 0.3
				gui.StudsOffset = Vector3.new(0, 1.5 + bob, 0)
			end
		end
	end
end)
