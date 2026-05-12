-- ============================================================
--  NECRO BUDDIES — ManaOrbScript (LocalScript)
--  Place inside StarterPlayerScripts
-- ============================================================

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ============================================================
--  GAME STATE
-- ============================================================
local gold = 50000

local rebirthCount = 0
local goldMultiplier = 1.0
local ASCEND_COSTS = { 4000, 25000, 50000 }

-- Inventory: up to 300 units; first 10 are shown in the toolbar
local INVENTORY_MAX = 300
local inventory = {}
local selectedSlot = 1

-- Forward declarations (defined after the UI is built)
local wheelPanel

-- Owned (bought, unopened) graves
local ownedGraves = {
	Mossy = 0,
	Stone = 0,
	Ancient = 0,
	Cursed = 0,
	Shadow = 0,
	Abyssal = 0,
	Eldritch = 0,
	Void = 0,
	Eternal = 0,
	Celestial = 0,
}

-- Pity tracking (updated when roll result comes back)
local lastPity = {
	Mossy = 0,
	Stone = 0,
	Ancient = 0,
	Cursed = 0,
	Shadow = 0,
	Abyssal = 0,
	Eldritch = 0,
	Void = 0,
	Eternal = 0,
	Celestial = 0,
}

local activeRollPopup = nil
local isRolling = false
local autoRollActive = false
local currentRollGraveType = nil
local skipCycling = false


-- Upgrade levels (synced from server via UpgradeGranted)
local luckBoostLevel = 0
local coinBoostLevel = 0
local UPGRADE_MAX = { luckBoost = 20, coinBoost = 15 }

-- Gems (premium currency)
local gems = 0

-- Wheel spins
local wheelSpins = 0
local wheelCountdownSecs = 900 -- seconds until next spin grant
local luckBuffEnd = 0 -- tick() timestamp when 2x luck buff expires

local function luckBoostCost(level)
	return math.floor(500 * (2.5 ^ level))
end
local function coinBoostCost(level)
	return math.floor(1500 * (3.0 ^ level))
end

local function fmtGold(n)
	if n >= 1e9 then
		return string.format("%.1fB", n / 1e9)
	elseif n >= 1e6 then
		return string.format("%.1fM", n / 1e6)
	elseif n >= 1e3 then
		return string.format("%.1fK", n / 1e3)
	else
		return tostring(math.floor(n))
	end
end

-- ============================================================
--  UNIT / GRAVE INFO TABLES
-- ============================================================
local _C = Color3.fromRGB
local UNIT_INFO = {
	-- Common
	Skelly = { emoji = "🦴", rarity = "Common", rarityColor = _C(200, 200, 200) },
	Zombie = { emoji = "🧟", rarity = "Common", rarityColor = _C(200, 200, 200) },
	Ghoul = { emoji = "🪦", rarity = "Common", rarityColor = _C(200, 200, 200) },
	-- Uncommon
	Ghost = { emoji = "👻", rarity = "Uncommon", rarityColor = _C(100, 220, 100) },
	Goblin = { emoji = "🏹", rarity = "Uncommon", rarityColor = _C(100, 220, 100) },
	Wraith = { emoji = "🌫️", rarity = "Uncommon", rarityColor = _C(100, 220, 100) },
	CryptBat = { emoji = "🦇", rarity = "Uncommon", rarityColor = _C(100, 220, 100) },
	-- Rare
	BaronBone = { emoji = "💀", rarity = "Rare", rarityColor = _C(80, 150, 255) },
	PlagueDoctor = { emoji = "🧪", rarity = "Rare", rarityColor = _C(80, 150, 255) },
	ShadowHound = { emoji = "🐺", rarity = "Rare", rarityColor = _C(80, 150, 255) },
	BoneColossus = { emoji = "🗿", rarity = "Rare", rarityColor = _C(80, 150, 255) },
	-- Cursed
	Banshee = { emoji = "👁️", rarity = "Cursed", rarityColor = _C(180, 80, 255) },
	LichAcolyte = { emoji = "🔮", rarity = "Cursed", rarityColor = _C(180, 80, 255) },
	DreadKnight = { emoji = "⚔️", rarity = "Cursed", rarityColor = _C(180, 80, 255) },
	-- Legendary
	SkeletonKing = { emoji = "👑", rarity = "Legendary", rarityColor = _C(255, 200, 50) },
	LichLord = { emoji = "🧙", rarity = "Legendary", rarityColor = _C(255, 200, 50) },
	DeathReaper = { emoji = "☠️", rarity = "Legendary", rarityColor = _C(255, 200, 50) },
	VoidWalker = { emoji = "🌑", rarity = "Legendary", rarityColor = _C(255, 200, 50) },
	-- Abyssal
	SoulEater = { emoji = "🔥", rarity = "Abyssal", rarityColor = _C(220, 50, 50) },
	AbyssalTitan = { emoji = "🌋", rarity = "Abyssal", rarityColor = _C(220, 50, 50) },
	ShadeLord = { emoji = "🕳️", rarity = "Abyssal", rarityColor = _C(220, 50, 50) },
	-- Eldritch
	EldritchFiend = { emoji = "🐙", rarity = "Eldritch", rarityColor = _C(50, 220, 200) },
	MindShatterer = { emoji = "🧠", rarity = "Eldritch", rarityColor = _C(50, 220, 200) },
	-- Eternal
	TheUndying = { emoji = "✨", rarity = "Eternal", rarityColor = _C(240, 240, 255) },
	DeathIncarnate = { emoji = "💀", rarity = "Eternal", rarityColor = _C(240, 240, 255) },
}

local UNIT_COLORS = {
	-- Common
	Skelly = BrickColor.new("White"),
	Zombie = BrickColor.new("Medium green"),
	Ghoul = BrickColor.new("Dark orange"),
	-- Uncommon
	Ghost = BrickColor.new("Pastel blue"),
	Goblin = BrickColor.new("Bright green"),
	Wraith = BrickColor.new("Light stone grey"),
	CryptBat = BrickColor.new("Dark grey"),
	-- Rare
	BaronBone = BrickColor.new("Bright yellow"),
	PlagueDoctor = BrickColor.new("Olive"),
	ShadowHound = BrickColor.new("Reddish brown"),
	BoneColossus = BrickColor.new("White"),
	-- Cursed
	Banshee = BrickColor.new("Hot pink"),
	LichAcolyte = BrickColor.new("Medium lavender"),
	DreadKnight = BrickColor.new("Bright red"),
	-- Legendary
	SkeletonKing = BrickColor.new("Gold"),
	LichLord = BrickColor.new("Bright violet"),
	DeathReaper = BrickColor.new("Dark indigo"),
	VoidWalker = BrickColor.new("Really black"),
	-- Abyssal
	SoulEater = BrickColor.new("Bright orange"),
	AbyssalTitan = BrickColor.new("Bright red"),
	ShadeLord = BrickColor.new("Dark purple"),
	-- Eldritch
	EldritchFiend = BrickColor.new("Teal"),
	MindShatterer = BrickColor.new("Cyan"),
	-- Eternal
	TheUndying = BrickColor.new("Institutional white"),
	DeathIncarnate = BrickColor.new("Really black"),
}

-- Ordered grave tier definitions (mirrors server GRAVES table)
local GRAVE_DATA = {
	{
		key = "Mossy",
		name = "Mossy Grave",
		emoji = "🪦",
		image = "rbxassetid://75308456335180",
		cost = 50,
		luck = 100,
		unlockAscension = 0,
		color = Color3.fromRGB(55, 85, 55),
	},
	{
		key = "Stone",
		name = "Stone Coffin",
		emoji = "⚰️",
		image = "rbxassetid://77145781270719",
		cost = 500,
		luck = 200,
		unlockAscension = 1,
		color = Color3.fromRGB(70, 70, 90),
	},
	{
		key = "Ancient",
		name = "Ancient Tomb",
		emoji = "👑",
		image = "rbxassetid://110643368436289",
		cost = 3000,
		luck = 500,
		unlockAscension = 2,
		color = Color3.fromRGB(90, 70, 20),
	},
	{
		key = "Cursed",
		name = "Cursed Crypt",
		emoji = "💀",
		image = "rbxassetid://127271561685050",
		cost = 20000,
		luck = 1000,
		unlockAscension = 3,
		color = Color3.fromRGB(80, 20, 80),
	},
	{
		key = "Shadow",
		name = "Shadow Vault",
		emoji = "🌑",
		image = "rbxassetid://122618880404468",
		cost = 100000,
		luck = 2000,
		unlockAscension = 4,
		color = Color3.fromRGB(20, 20, 40),
	},
	{
		key = "Abyssal",
		name = "Abyssal Tomb",
		emoji = "🔥",
		image = "rbxassetid://79850946861944",
		cost = 500000,
		luck = 4000,
		unlockAscension = 5,
		color = Color3.fromRGB(120, 30, 10),
	},
	{
		key = "Eldritch",
		name = "Eldritch Reliquary",
		emoji = "🐙",
		image = "rbxassetid://91010271116619",
		cost = 2500000,
		luck = 8000,
		unlockAscension = 6,
		color = Color3.fromRGB(10, 80, 80),
	},
	{
		key = "Void",
		name = "Void Sanctum",
		emoji = "🌌",
		image = "rbxassetid://106891433077044",
		cost = 12000000,
		luck = 16000,
		unlockAscension = 7,
		color = Color3.fromRGB(10, 10, 30),
	},
	{
		key = "Eternal",
		name = "Eternal Throne",
		emoji = "✨",
		image = "",
		cost = 60000000,
		luck = 35000,
		unlockAscension = 8,
		color = Color3.fromRGB(80, 80, 120),
	},
	{
		key = "Celestial",
		name = "Celestial Abyss",
		emoji = "🌟",
		image = "",
		cost = 300000000,
		luck = 75000,
		unlockAscension = 9,
		color = Color3.fromRGB(40, 60, 100),
	},
}

local RARITY_COLORS = {
	Common = _C(200, 200, 200),
	Uncommon = _C(100, 220, 100),
	Rare = _C(80, 150, 255),
	Cursed = _C(180, 80, 255),
	Legendary = _C(255, 200, 50),
	Abyssal = _C(220, 50, 50),
	Eldritch = _C(50, 220, 200),
	Eternal = _C(240, 240, 255),
}

-- Precomputed DPS (damage / attackCD, floored) matching server UNITS table
local UNIT_DPS = {
	-- Common
	Skelly = 8,
	Zombie = 6,
	Ghoul = 13,
	-- Uncommon
	Ghost = 18,
	Goblin = 22,
	Wraith = 35,
	CryptBat = 41,
	-- Rare
	BaronBone = 55,
	PlagueDoctor = 70,
	ShadowHound = 85,
	BoneColossus = 100,
	-- Cursed
	Banshee = 160,
	LichAcolyte = 200,
	DreadKnight = 260,
	-- Legendary
	SkeletonKing = 350,
	LichLord = 480,
	DeathReaper = 650,
	VoidWalker = 800,
	-- Abyssal
	SoulEater = 1200,
	AbyssalTitan = 1600,
	ShadeLord = 2200,
	-- Eldritch
	EldritchFiend = 4000,
	MindShatterer = 6500,
	-- Eternal
	TheUndying = 12000,
	DeathIncarnate = 20000,
}

-- Base "1 in X" odds (mirrors server getBaseOneIn, no luck applied — shown raw in UI)
local UNIT_ONE_IN = {
	-- Common  (45% tier)
	Skelly = 5, -- 45% × 4/9  = 20%   → 1/5
	Zombie = 7, -- 45% × 3/9  = 15%   → 1/7
	Ghoul = 10, -- 45% × 2/9  = 10%   → 1/10
	-- Uncommon (25% tier)
	Ghost = 10, -- 25% × 4/10 = 10%   → 1/10
	Goblin = 13, -- 25% × 3/10 = 7.5%  → 1/13
	Wraith = 20, -- 25% × 2/10 = 5%    → 1/20
	CryptBat = 40, -- 25% × 1/10 = 2.5%  → 1/40
	-- Rare     (15% tier)
	BaronBone = 18, -- 15% × 3/8  = 5.6%  → 1/18
	PlagueDoctor = 27, -- 15% × 2/8  = 3.75% → 1/27
	ShadowHound = 27, -- 15% × 2/8  = 3.75% → 1/27
	BoneColossus = 53, -- 15% × 1/8  = 1.875%→ 1/53
	-- Cursed   (8% tier)
	Banshee = 25, -- 8%  × 3/6  = 4%    → 1/25
	LichAcolyte = 38, -- 8%  × 2/6  = 2.67% → 1/38
	DreadKnight = 75, -- 8%  × 1/6  = 1.33% → 1/75
	-- Legendary (4% tier)
	SkeletonKing = 50, -- 4%  × 6/12 = 2%    → 1/50
	LichLord = 100, -- 4%  × 3/12 = 1%    → 1/100
	DeathReaper = 150, -- 4%  × 2/12 = 0.67% → 1/150
	VoidWalker = 300, -- 4%  × 1/12 = 0.33% → 1/300
	-- Abyssal  (2% tier)
	SoulEater = 100, -- 2%  × 3/6  = 1%    → 1/100
	AbyssalTitan = 150, -- 2%  × 2/6  = 0.67% → 1/150
	ShadeLord = 300, -- 2%  × 1/6  = 0.33% → 1/300
	-- Eldritch (0.75% tier)
	EldritchFiend = 200, -- 0.75% × 2/3= 0.5%  → 1/200
	MindShatterer = 400, -- 0.75% × 1/3= 0.25% → 1/400
	-- Eternal  (0.25% tier)
	TheUndying = 600, -- 0.25% × 2/3= 0.167%→ 1/600
	DeathIncarnate = 1200, -- 0.25% × 1/3= 0.083%→ 1/1200
}

local ALL_UNIT_KEYS = {
	"Skelly",
	"Zombie",
	"Ghoul",
	"Ghost",
	"Goblin",
	"Wraith",
	"CryptBat",
	"BaronBone",
	"PlagueDoctor",
	"ShadowHound",
	"BoneColossus",
	"Banshee",
	"LichAcolyte",
	"DreadKnight",
	"SkeletonKing",
	"LichLord",
	"DeathReaper",
	"VoidWalker",
	"SoulEater",
	"AbyssalTitan",
	"ShadeLord",
	"EldritchFiend",
	"MindShatterer",
	"TheUndying",
	"DeathIncarnate",
}

-- ============================================================
--  SCREEN GUI
-- ============================================================
local GravesDock      = require(script.Modules.GravesDock)
local InventoryPanel  = require(script.Modules.InventoryPanel)
local ShopPanel       = require(script.Modules.ShopPanel)

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "NecroUI"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.Parent = playerGui

-- ── TOP HUD BAR ──────────────────────────────────────────────
local hudBar = Instance.new("Frame")
hudBar.Size = UDim2.new(1, 0, 0, 48)
hudBar.Position = UDim2.new(0, 0, 0, 0)
hudBar.BackgroundColor3 = Color3.fromRGB(20, 10, 40)
hudBar.BackgroundTransparency = 0.2
hudBar.BorderSizePixel = 0
hudBar.Parent = screenGui

local goldLabel = Instance.new("TextLabel")
goldLabel.Size = UDim2.new(0.45, 0, 1, 0)
goldLabel.Position = UDim2.new(0.25, 0, 0, 0)
goldLabel.BackgroundTransparency = 1
goldLabel.Text = "💰 300  💎 0"
goldLabel.TextColor3 = Color3.fromRGB(255, 215, 100)
goldLabel.TextScaled = true
goldLabel.Font = Enum.Font.GothamBold
goldLabel.Parent = hudBar

-- Luck buff indicator (shown below gold label when active)
local luckBuffLabel = Instance.new("TextLabel")
luckBuffLabel.Size = UDim2.new(0.2, 0, 0, 22)
luckBuffLabel.Position = UDim2.new(0.25, 0, 1, 2)
luckBuffLabel.BackgroundColor3 = Color3.fromRGB(30, 120, 30)
luckBuffLabel.BackgroundTransparency = 0.3
luckBuffLabel.Text = "🍀 2x Luck!"
luckBuffLabel.TextColor3 = Color3.fromRGB(180, 255, 180)
luckBuffLabel.TextScaled = true
luckBuffLabel.Font = Enum.Font.GothamBold
luckBuffLabel.BorderSizePixel = 0
luckBuffLabel.ZIndex = 5
luckBuffLabel.Visible = false
luckBuffLabel.Parent = screenGui
Instance.new("UICorner", luckBuffLabel).CornerRadius = UDim.new(0, 6)

-- ── NAV BUTTONS (top-right of hud bar) ───────────────────────
-- 🎡 Wheel button (far left of the nav cluster)
local wheelHudBtn = Instance.new("TextButton", hudBar)
wheelHudBtn.Size = UDim2.new(0, 150, 0, 34)
wheelHudBtn.Position = UDim2.new(1, -528, 0.5, -17)
wheelHudBtn.BackgroundColor3 = Color3.fromRGB(80, 40, 0)
wheelHudBtn.Text = "🎡 Spin (0)"
wheelHudBtn.TextColor3 = Color3.fromRGB(255, 220, 100)
wheelHudBtn.TextScaled = true
wheelHudBtn.Font = Enum.Font.GothamBold
wheelHudBtn.BorderSizePixel = 0
wheelHudBtn.ZIndex = 5
Instance.new("UICorner", wheelHudBtn).CornerRadius = UDim.new(0, 8)

local invHudBtn = Instance.new("TextButton", hudBar)
invHudBtn.Size = UDim2.new(0, 120, 0, 34)
invHudBtn.Position = UDim2.new(1, -368, 0.5, -17)
invHudBtn.BackgroundColor3 = Color3.fromRGB(30, 15, 60)
invHudBtn.Text = "📦 Inventory"
invHudBtn.TextColor3 = Color3.fromRGB(200, 175, 255)
invHudBtn.TextScaled = true
invHudBtn.Font = Enum.Font.GothamBold
invHudBtn.BorderSizePixel = 0
invHudBtn.ZIndex = 5
Instance.new("UICorner", invHudBtn).CornerRadius = UDim.new(0, 8)

local shopsBtn = Instance.new("TextButton", hudBar)
shopsBtn.Size = UDim2.new(0, 110, 0, 34)
shopsBtn.Position = UDim2.new(1, -238, 0.5, -17)
shopsBtn.BackgroundColor3 = Color3.fromRGB(40, 20, 80)
shopsBtn.Text = "🛒 Shops"
shopsBtn.TextColor3 = Color3.fromRGB(220, 200, 255)
shopsBtn.TextScaled = true
shopsBtn.Font = Enum.Font.GothamBold
shopsBtn.BorderSizePixel = 0
shopsBtn.ZIndex = 5
Instance.new("UICorner", shopsBtn).CornerRadius = UDim.new(0, 8)

local wallBtn = Instance.new("TextButton", hudBar)
wallBtn.Size = UDim2.new(0, 110, 0, 34)
wallBtn.Position = UDim2.new(1, -120, 0.5, -17)
wallBtn.BackgroundColor3 = Color3.fromRGB(80, 25, 25)
wallBtn.Text = "🏰 Wall"
wallBtn.TextColor3 = Color3.fromRGB(255, 190, 190)
wallBtn.TextScaled = true
wallBtn.Font = Enum.Font.GothamBold
wallBtn.BorderSizePixel = 0
wallBtn.ZIndex = 5
Instance.new("UICorner", wallBtn).CornerRadius = UDim.new(0, 8)

local getWallPosFunc = ReplicatedStorage:WaitForChild("GetWallPos", 5)

shopsBtn.MouseButton1Click:Connect(function()
	local char = player.Character
	if not char then return end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	hrp.CFrame = CFrame.new(-245, 3, 89)
end)

wallBtn.MouseButton1Click:Connect(function()
	local char = player.Character
	if not char then return end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	if not getWallPosFunc then return end
	local wallPos = getWallPosFunc:InvokeServer()
	if wallPos then
		hrp.CFrame = CFrame.new(wallPos.X + 15, 3, wallPos.Z)
	end
end)

invHudBtn.MouseButton1Click:Connect(function()
	InventoryPanel.toggle()
end)

-- ============================================================
--  HELPERS
-- ============================================================
local function fmt(n)
	if n >= 1e9 then
		return string.format("%.1fB", n / 1e9)
	elseif n >= 1e6 then
		return string.format("%.1fM", n / 1e6)
	elseif n >= 1e3 then
		return string.format("%.1fK", n / 1e3)
	elseif n >= 10 then
		return string.format("%.0f", n)
	else
		return string.format("%.1f", n)
	end
end

local function updateHUD()
	goldLabel.Text = "💰 " .. fmt(gold) .. "  💎 " .. gems
	local buffActive = tick() < luckBuffEnd
	luckBuffLabel.Visible = buffActive
	if buffActive then
		local secs = math.max(0, math.floor(luckBuffEnd - tick()))
		local m = math.floor(secs / 60)
		local s = secs % 60
		luckBuffLabel.Text = string.format("🍀 2x Luck %d:%02d", m, s)
	end
end

-- ============================================================
--  TOOLBAR  (10 slots at bottom)
-- ============================================================
local SLOT_SIZE = 58
local SLOT_GAP = 4
local TOOLBAR_W = SLOT_SIZE * 10 + SLOT_GAP * 9 + 12 -- 12 for padding

local toolbarFrame = Instance.new("Frame")
toolbarFrame.Size = UDim2.new(0, TOOLBAR_W, 0, SLOT_SIZE + 10)
toolbarFrame.Position = UDim2.new(0.5, -TOOLBAR_W / 2, 1, -80)
toolbarFrame.BackgroundColor3 = Color3.fromRGB(12, 6, 28)
toolbarFrame.BackgroundTransparency = 0.25
toolbarFrame.BorderSizePixel = 0
toolbarFrame.Parent = screenGui
Instance.new("UICorner", toolbarFrame).CornerRadius = UDim.new(0, 10)

local toolbarLayout = Instance.new("UIListLayout", toolbarFrame)
toolbarLayout.FillDirection = Enum.FillDirection.Horizontal
toolbarLayout.Padding = UDim.new(0, SLOT_GAP)
toolbarLayout.SortOrder = Enum.SortOrder.LayoutOrder
toolbarLayout.VerticalAlignment = Enum.VerticalAlignment.Center
toolbarLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

Instance.new("UIPadding", toolbarFrame).PaddingLeft = UDim.new(0, 6)
local toolbarPad = Instance.new("UIPadding", toolbarFrame)
toolbarPad.PaddingLeft = UDim.new(0, 6)
toolbarPad.PaddingRight = UDim.new(0, 6)

local slotFrames = {}

-- ── INVENTORY HOVER TOOLTIP ───────────────────────────────────
local tooltip = Instance.new("Frame", screenGui)
tooltip.Size = UDim2.new(0, 175, 0, 96)
tooltip.BackgroundColor3 = Color3.fromRGB(18, 8, 38)
tooltip.BackgroundTransparency = 0.08
tooltip.BorderSizePixel = 0
tooltip.Visible = false
tooltip.ZIndex = 60
Instance.new("UICorner", tooltip).CornerRadius = UDim.new(0, 8)
local ttStroke = Instance.new("UIStroke", tooltip)
ttStroke.Color = Color3.fromRGB(80, 40, 140)
ttStroke.Thickness = 1

local ttName = Instance.new("TextLabel", tooltip)
ttName.Size = UDim2.new(1, -10, 0.34, 0)
ttName.Position = UDim2.new(0, 5, 0.02, 0)
ttName.BackgroundTransparency = 1
ttName.TextColor3 = Color3.fromRGB(255, 255, 255)
ttName.TextScaled = true
ttName.Font = Enum.Font.GothamBold
ttName.ZIndex = 61

local ttRarity = Instance.new("TextLabel", tooltip)
ttRarity.Size = UDim2.new(1, -10, 0.24, 0)
ttRarity.Position = UDim2.new(0, 5, 0.36, 0)
ttRarity.BackgroundTransparency = 1
ttRarity.TextScaled = true
ttRarity.Font = Enum.Font.Gotham
ttRarity.ZIndex = 61

local ttDps = Instance.new("TextLabel", tooltip)
ttDps.Size = UDim2.new(1, -10, 0.2, 0)
ttDps.Position = UDim2.new(0, 5, 0.60, 0)
ttDps.BackgroundTransparency = 1
ttDps.TextColor3 = Color3.fromRGB(100, 255, 130)
ttDps.TextScaled = true
ttDps.Font = Enum.Font.GothamBold
ttDps.ZIndex = 61

local ttOneIn = Instance.new("TextLabel", tooltip)
ttOneIn.Size = UDim2.new(1, -10, 0.2, 0)
ttOneIn.Position = UDim2.new(0, 5, 0.80, 0)
ttOneIn.BackgroundTransparency = 1
ttOneIn.TextColor3 = Color3.fromRGB(190, 165, 255)
ttOneIn.TextScaled = true
ttOneIn.Font = Enum.Font.Gotham
ttOneIn.ZIndex = 61

for i = 1, 10 do
	local slot = Instance.new("Frame", toolbarFrame)
	slot.Size = UDim2.new(0, SLOT_SIZE, 0, SLOT_SIZE)
	slot.BackgroundColor3 = Color3.fromRGB(22, 10, 45)
	slot.BorderSizePixel = 0
	slot.LayoutOrder = i
	Instance.new("UICorner", slot).CornerRadius = UDim.new(0, 8)

	-- Slot number (top-left)
	local numLbl = Instance.new("TextLabel", slot)
	numLbl.Size = UDim2.new(0, 16, 0, 16)
	numLbl.Position = UDim2.new(0, 3, 0, 2)
	numLbl.BackgroundTransparency = 1
	numLbl.Text = tostring(i % 10) -- 1-9 then 0
	numLbl.TextColor3 = Color3.fromRGB(150, 130, 190)
	numLbl.TextScaled = true
	numLbl.Font = Enum.Font.GothamBold
	numLbl.ZIndex = 2

	-- Unit emoji (center)
	local emojiLbl = Instance.new("TextLabel", slot)
	emojiLbl.Size = UDim2.new(1, 0, 0.58, 0)
	emojiLbl.Position = UDim2.new(0, 0, 0.08, 0)
	emojiLbl.BackgroundTransparency = 1
	emojiLbl.Text = ""
	emojiLbl.TextScaled = true
	emojiLbl.ZIndex = 2

	-- Unit name (bottom)
	local nameLbl = Instance.new("TextLabel", slot)
	nameLbl.Size = UDim2.new(1, -2, 0, 13)
	nameLbl.Position = UDim2.new(0, 1, 1, -15)
	nameLbl.BackgroundTransparency = 1
	nameLbl.Text = ""
	nameLbl.TextColor3 = Color3.fromRGB(190, 170, 220)
	nameLbl.TextSize = 9
	nameLbl.Font = Enum.Font.Gotham
	nameLbl.ZIndex = 2

	slotFrames[i] = { frame = slot, emoji = emojiLbl, name = nameLbl }

	-- Click to select
	local btn = Instance.new("TextButton", slot)
	btn.Size = UDim2.new(1, 0, 1, 0)
	btn.BackgroundTransparency = 1
	btn.Text = ""
	btn.ZIndex = 3
	local slotIndex = i
	btn.MouseButton1Click:Connect(function()
		selectSlot(slotIndex)
	end)

	btn.MouseEnter:Connect(function()
		local unit = inventory[slotIndex]
		if not unit then
			tooltip.Visible = false
			return
		end
		local info = UNIT_INFO[unit.unitType] or {}
		ttName.Text = (info.emoji or "❓") .. " " .. unit.unitType
		ttRarity.Text = info.rarity or ""
		ttRarity.TextColor3 = RARITY_COLORS[info.rarity] or Color3.fromRGB(200, 200, 200)
		ttDps.Text = (UNIT_DPS[unit.unitType] or "?") .. " DPS"
		ttOneIn.Text = "1 in " .. (unit.oneIn or UNIT_ONE_IN[unit.unitType] or "?")
		local abs = slot.AbsolutePosition
		local sz = slot.AbsoluteSize
		local sw = screenGui.AbsoluteSize.X
		local tx = math.clamp(abs.X + sz.X / 2 - 87, 0, sw - 175)
		tooltip.Position = UDim2.new(0, tx, 0, abs.Y - 104)
		tooltip.Visible = true
	end)

	btn.MouseLeave:Connect(function()
		tooltip.Visible = false
	end)
end

-- ============================================================
--  TOOLBAR / INVENTORY FUNCTIONS
-- ============================================================
local heldBlock = nil

local function updateCarriedUnit()
	if heldBlock then
		heldBlock:Destroy()
		heldBlock = nil
	end

	local unit = inventory[selectedSlot]
	if not unit then
		return
	end

	local char = player.Character
	if not char then
		return
	end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return
	end

	heldBlock = Instance.new("Part")
	heldBlock.Size = Vector3.new(0.9, 0.9, 0.9)
	heldBlock.BrickColor = UNIT_COLORS[unit.unitType] or BrickColor.new("Medium stone grey")
	heldBlock.Material = Enum.Material.SmoothPlastic
	heldBlock.CanCollide = false
	heldBlock.CastShadow = false
	heldBlock.Parent = char

	local weld = Instance.new("Weld")
	weld.Part0 = hrp
	weld.Part1 = heldBlock
	weld.C0 = CFrame.new(1.5, -0.4, -0.7)
	weld.Parent = heldBlock

	local info = UNIT_INFO[unit.unitType] or {}
	local gui = Instance.new("BillboardGui", heldBlock)
	gui.Size = UDim2.new(0, 160, 0, 72)
	gui.StudsOffset = Vector3.new(0, 1.4, 0)
	gui.AlwaysOnTop = false

	local nameLbl = Instance.new("TextLabel", gui)
	nameLbl.Size = UDim2.new(1, 0, 0.4, 0)
	nameLbl.Position = UDim2.new(0, 0, 0, 0)
	nameLbl.BackgroundTransparency = 1
	nameLbl.Text = (info.emoji or "❓") .. " " .. unit.unitType
	nameLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameLbl.TextScaled = true
	nameLbl.Font = Enum.Font.GothamBold

	local rarityLbl = Instance.new("TextLabel", gui)
	rarityLbl.Size = UDim2.new(1, 0, 0.3, 0)
	rarityLbl.Position = UDim2.new(0, 0, 0.4, 0)
	rarityLbl.BackgroundTransparency = 1
	rarityLbl.Text = info.rarity or ""
	rarityLbl.TextColor3 = RARITY_COLORS[info.rarity] or Color3.fromRGB(200, 200, 200)
	rarityLbl.TextScaled = true
	rarityLbl.Font = Enum.Font.Gotham

	local dpsLbl = Instance.new("TextLabel", gui)
	dpsLbl.Size = UDim2.new(1, 0, 0.3, 0)
	dpsLbl.Position = UDim2.new(0, 0, 0.7, 0)
	dpsLbl.BackgroundTransparency = 1
	dpsLbl.Text = (UNIT_DPS[unit.unitType] or "?") .. " DPS"
	dpsLbl.TextColor3 = Color3.fromRGB(100, 255, 130)
	dpsLbl.TextScaled = true
	dpsLbl.Font = Enum.Font.GothamBold
end

local function refreshToolbar()
	for i = 1, 10 do
		local sf = slotFrames[i]
		local unit = inventory[i]
		local isSel = (i == selectedSlot)

		if unit then
			local info = UNIT_INFO[unit.unitType] or {}
			local rc = RARITY_COLORS[info.rarity] or Color3.fromRGB(80, 40, 120)
			local ri, gi, bi = rc.R * 255, rc.G * 255, rc.B * 255
			sf.emoji.Text = info.emoji or "❓"
			sf.name.Text = unit.unitType
			sf.frame.BackgroundColor3 = isSel
					and Color3.fromRGB(
						math.floor(ri * 0.45 + 25),
						math.floor(gi * 0.45 + 12),
						math.floor(bi * 0.45 + 45)
					)
				or Color3.fromRGB(math.floor(ri * 0.18 + 6), math.floor(gi * 0.18 + 3), math.floor(bi * 0.18 + 12))
		else
			sf.emoji.Text = ""
			sf.name.Text = ""
			sf.frame.BackgroundColor3 = isSel and Color3.fromRGB(55, 30, 90) or Color3.fromRGB(22, 10, 45)
		end
	end
end

function selectSlot(n)
	selectedSlot = n
	refreshToolbar()
	updateCarriedUnit()
end

local function addToInventory(unitType, oneIn)
	for i = 1, INVENTORY_MAX do
		if inventory[i] == nil then
			inventory[i] = { unitType = unitType, oneIn = oneIn or UNIT_ONE_IN[unitType] or 1 }
			refreshToolbar()
			if InventoryPanel.isVisible() then
				InventoryPanel.refresh()
			end
			return true
		end
	end
	return false -- full
end

-- Key 1-0 → select slot
local KEY_TO_SLOT = {
	[Enum.KeyCode.One] = 1,
	[Enum.KeyCode.Two] = 2,
	[Enum.KeyCode.Three] = 3,
	[Enum.KeyCode.Four] = 4,
	[Enum.KeyCode.Five] = 5,
	[Enum.KeyCode.Six] = 6,
	[Enum.KeyCode.Seven] = 7,
	[Enum.KeyCode.Eight] = 8,
	[Enum.KeyCode.Nine] = 9,
	[Enum.KeyCode.Zero] = 10,
}
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end
	local slot = KEY_TO_SLOT[input.KeyCode]
	if slot then
		selectSlot(slot)
	end
end)

-- Re-attach held block if character respawns
player.CharacterAdded:Connect(function()
	heldBlock = nil
	task.delay(1, updateCarriedUnit)
end)

-- ============================================================
--  INVENTORY PANEL
-- ============================================================
InventoryPanel.init(screenGui, {
	inventory       = inventory,
	UNIT_INFO       = UNIT_INFO,
	RARITY_COLORS   = RARITY_COLORS,
	UNIT_DPS        = UNIT_DPS,
	UNIT_ONE_IN     = UNIT_ONE_IN,
	INVENTORY_MAX   = INVENTORY_MAX,
	tooltip         = tooltip,
	ttName          = ttName,
	ttRarity        = ttRarity,
	ttDps           = ttDps,
	ttOneIn         = ttOneIn,
	getSelectedSlot = function() return selectedSlot end,
	refreshToolbar  = refreshToolbar,
	updateCarriedUnit = updateCarriedUnit,
})

-- ── Place Best button (top-center, just below HUD) ────────────
local placeBestBtn = Instance.new("TextButton")
placeBestBtn.Name = "PlaceBestBtn"
placeBestBtn.Size = UDim2.new(0, 170, 0, 36)
placeBestBtn.Position = UDim2.new(0.5, -85, 0, 48)
placeBestBtn.BackgroundColor3 = Color3.fromRGB(130, 25, 25)
placeBestBtn.Text = "🏆 Place Best"
placeBestBtn.TextColor3 = Color3.fromRGB(255, 210, 210)
placeBestBtn.TextScaled = true
placeBestBtn.Font = Enum.Font.GothamBold
placeBestBtn.BorderSizePixel = 0
placeBestBtn.ZIndex = 10
Instance.new("UICorner", placeBestBtn).CornerRadius = UDim.new(0, 10)
placeBestBtn.Parent = screenGui

local placeBestRemote = ReplicatedStorage:WaitForChild("PlaceBest", 5)
local placeBestResultEvt = ReplicatedStorage:WaitForChild("PlaceBestResult", 5)

placeBestBtn.MouseButton1Click:Connect(function()
	if not placeBestRemote then
		return
	end
	-- Gather client inventory and send it to the server
	local clientInv = {}
	for i = 1, INVENTORY_MAX do
		if inventory[i] then
			table.insert(clientInv, { unitType = inventory[i].unitType, oneIn = inventory[i].oneIn or 1 })
		end
	end
	-- Optimistically clear local inventory; server will return the leftovers
	for i = 1, INVENTORY_MAX do
		inventory[i] = nil
	end
	refreshToolbar()
	if InventoryPanel.isVisible() then
		InventoryPanel.refresh()
	end
	updateCarriedUnit()
	placeBestRemote:FireServer(clientInv)
end)

-- Server returns units that didn't fit into graves
if placeBestResultEvt then
	placeBestResultEvt.OnClientEvent:Connect(function(remaining)
		for i = 1, INVENTORY_MAX do
			inventory[i] = nil
		end
		for i, item in ipairs(remaining) do
			inventory[i] = {
				unitType = item.unitType,
				oneIn = item.oneIn or UNIT_ONE_IN[item.unitType] or 1,
			}
		end
		refreshToolbar()
		if InventoryPanel.isVisible() then
			InventoryPanel.refresh()
		end
		updateCarriedUnit()
	end)
end

-- I key toggles the inventory panel
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end
	if input.KeyCode == Enum.KeyCode.I then
		InventoryPanel.toggle()
	end
end)

-- ============================================================
--  ROLL ANIMATION
-- ============================================================
local function playRollAnimation(unitType, rarity, pity, oneIn)
	if activeRollPopup and activeRollPopup.Parent then
		activeRollPopup:Destroy()
		activeRollPopup = nil
	end
	skipCycling = false

	-- Backdrop (taller to fit buttons)
	local backdrop = Instance.new("Frame", screenGui)
	backdrop.Size = UDim2.new(0, 480, 0, 290)
	backdrop.Position = UDim2.new(0.5, -240, 0.35, -145)
	backdrop.BackgroundColor3 = Color3.fromRGB(12, 5, 30)
	backdrop.BackgroundTransparency = 0.1
	backdrop.BorderSizePixel = 0
	backdrop.ZIndex = 40
	Instance.new("UICorner", backdrop).CornerRadius = UDim.new(0, 16)
	activeRollPopup = backdrop

	local rollingLbl = Instance.new("TextLabel", backdrop)
	rollingLbl.Size = UDim2.new(1, -20, 0, 90)
	rollingLbl.Position = UDim2.new(0, 10, 0, 10)
	rollingLbl.BackgroundTransparency = 1
	rollingLbl.TextScaled = true
	rollingLbl.Font = Enum.Font.GothamBold
	rollingLbl.ZIndex = 41

	local subLbl = Instance.new("TextLabel", backdrop)
	subLbl.Size = UDim2.new(1, -20, 0, 60)
	subLbl.Position = UDim2.new(0, 10, 0, 108)
	subLbl.BackgroundTransparency = 1
	subLbl.TextColor3 = Color3.fromRGB(170, 150, 210)
	subLbl.TextScaled = false
	subLbl.TextSize = 19
	subLbl.TextWrapped = true
	subLbl.Font = Enum.Font.Gotham
	subLbl.ZIndex = 41

	-- ── Buttons ──────────────────────────────────────────────
	local skipBtn = Instance.new("TextButton", backdrop)
	skipBtn.Size = UDim2.new(0.44, -8, 0, 58)
	skipBtn.Position = UDim2.new(0, 10, 1, -68)
	skipBtn.BackgroundColor3 = Color3.fromRGB(40, 20, 80)
	skipBtn.Text = "⏭  Skip"
	skipBtn.TextColor3 = Color3.fromRGB(200, 180, 255)
	skipBtn.TextScaled = true
	skipBtn.Font = Enum.Font.GothamBold
	skipBtn.BorderSizePixel = 0
	skipBtn.ZIndex = 42
	Instance.new("UICorner", skipBtn).CornerRadius = UDim.new(0, 12)

	local autoBtn = Instance.new("TextButton", backdrop)
	autoBtn.Size = UDim2.new(0.56, -12, 0, 58)
	autoBtn.Position = UDim2.new(0.44, 2, 1, -68)
	autoBtn.TextScaled = true
	autoBtn.Font = Enum.Font.GothamBold
	autoBtn.BorderSizePixel = 0
	autoBtn.ZIndex = 42
	Instance.new("UICorner", autoBtn).CornerRadius = UDim.new(0, 12)

	local function updateAutoBtn()
		autoBtn.Text = autoRollActive and "⟳  Auto Roll  ON" or "⟳  Auto Roll  OFF"
		autoBtn.BackgroundColor3 = autoRollActive and Color3.fromRGB(20, 110, 40) or Color3.fromRGB(40, 20, 70)
		autoBtn.TextColor3 = autoRollActive and Color3.fromRGB(140, 255, 140) or Color3.fromRGB(180, 150, 220)
	end
	updateAutoBtn()
	autoBtn.MouseButton1Click:Connect(function()
		autoRollActive = not autoRollActive
		updateAutoBtn()
	end)

	-- Fade in
	backdrop.Size = UDim2.new(0, 120, 0, 50)
	backdrop.Position = UDim2.new(0.5, -60, 0.35, -25)
	TweenService:Create(
		backdrop,
		TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Size = UDim2.new(0, 480, 0, 290), Position = UDim2.new(0.5, -240, 0.35, -145) }
	):Play()

	-- ── Close / auto-roll-next helper ────────────────────────
	local function closeAndContinue()
		local gt = currentRollGraveType
		backdrop:Destroy()
		if activeRollPopup == backdrop then
			activeRollPopup = nil
		end
		if autoRollActive and gt and (ownedGraves[gt] or 0) > 0 then
			-- Fire next roll in the chain
			ownedGraves[gt] -= 1
			GravesDock.refresh()
			local remote = ReplicatedStorage:FindFirstChild("DigGrave")
			if remote then
				remote:FireServer(gt)
			end
			-- isRolling stays true; next RollResult restarts playRollAnimation
		else
			isRolling = false
			autoRollActive = false
		end
	end

	-- ── Result reveal ─────────────────────────────────────────
	local resultShown = false
	local function showResult()
		if resultShown then
			return
		end
		resultShown = true
		skipCycling = false

		local info = UNIT_INFO[unitType] or {}
		local rc = RARITY_COLORS[rarity] or Color3.fromRGB(255, 255, 255)
		rollingLbl.Text = (info.emoji or "❓") .. "  " .. unitType
		rollingLbl.TextColor3 = rc
		subLbl.TextColor3 = rc
		subLbl.Text = rarity:upper()
			.. "   •   1 in "
			.. (oneIn or UNIT_ONE_IN[unitType] or "?")
			.. "   (Pity: "
			.. (pity or 0)
			.. " / 60)"

		local added = addToInventory(unitType, oneIn)
		if not added then
			subLbl.Text = "⚠️ Inventory full! Unit lost."
			subLbl.TextColor3 = Color3.fromRGB(255, 100, 80)
		end

		-- Skip becomes Close
		skipBtn.Text = "✕  Close"
		skipBtn.BackgroundColor3 = Color3.fromRGB(80, 20, 20)
		skipBtn.TextColor3 = Color3.fromRGB(255, 150, 150)

		if autoRollActive then
			-- Auto-proceed quickly
			task.delay(0.6, function()
				if backdrop.Parent then
					closeAndContinue()
				end
			end)
		end
	end

	-- ── Skip button ───────────────────────────────────────────
	skipBtn.MouseButton1Click:Connect(function()
		if not resultShown then
			skipCycling = true -- cycling loop will call showResult next tick
		else
			closeAndContinue() -- continue auto roll chain (or just close if auto roll is off)
		end
	end)

	-- ── Cycling animation ─────────────────────────────────────
	local cycles = 0
	local MAX_CYCLES = 16

	local function tick()
		if not backdrop.Parent then
			return
		end
		if cycles >= MAX_CYCLES or skipCycling then
			showResult()
			return
		end
		cycles += 1
		local rand = ALL_UNIT_KEYS[math.random(#ALL_UNIT_KEYS)]
		local info = UNIT_INFO[rand] or {}
		rollingLbl.Text = (info.emoji or "❓") .. "  " .. rand
		rollingLbl.TextColor3 = RARITY_COLORS[info.rarity] or Color3.fromRGB(220, 200, 255)
		subLbl.TextColor3 = Color3.fromRGB(170, 150, 210)
		subLbl.Text = (info.rarity or "?") .. "   •   1 in " .. (UNIT_ONE_IN[rand] or "?")
		local delay = 0.06 + (cycles / MAX_CYCLES) * 0.22
		task.delay(delay, tick)
	end

	tick()
end

function openGrave(graveType)
	if isRolling then
		return
	end -- locked while animation is active
	if ShopPanel.isGraveLocked(graveType) then
		return
	end
	if (ownedGraves[graveType] or 0) <= 0 then
		return
	end

	-- Check for inventory space
	local hasSpace = false
	for i = 1, 10 do
		if inventory[i] == nil then
			hasSpace = true
			break
		end
	end
	if not hasSpace then
		local warn = Instance.new("TextLabel", screenGui)
		warn.Size = UDim2.new(0, 260, 0, 40)
		warn.Position = UDim2.new(0.5, -130, 1, -310)
		warn.BackgroundColor3 = Color3.fromRGB(120, 30, 30)
		warn.BackgroundTransparency = 0.2
		warn.Text = "⚠️ Inventory full!"
		warn.TextColor3 = Color3.fromRGB(255, 180, 180)
		warn.TextScaled = true
		warn.Font = Enum.Font.GothamBold
		warn.ZIndex = 50
		warn.BorderSizePixel = 0
		Instance.new("UICorner", warn).CornerRadius = UDim.new(0, 8)
		game:GetService("Debris"):AddItem(warn, 2)
		return
	end

	-- Lock and track grave type for auto-roll chain
	isRolling = true
	currentRollGraveType = graveType
	autoRollActive = false -- always start a fresh session with auto roll off

	ownedGraves[graveType] -= 1
	GravesDock.refresh()
	local remote = ReplicatedStorage:FindFirstChild("DigGrave")
	if remote then
		remote:FireServer(graveType)
	end
end

-- Initialise GravesDock now that openGrave is defined
GravesDock.init(screenGui, ownedGraves, GRAVE_DATA, openGrave)

-- Initialise ShopPanel
ShopPanel.init(screenGui, {
	GRAVE_DATA      = GRAVE_DATA,
	ownedGraves     = ownedGraves,
	getGold         = function() return gold end,
	spendGold       = function(n) gold = gold - n; updateHUD() end,
	getRebirthCount = function() return rebirthCount end,
	fmtGold         = fmtGold,
	refreshDock     = function() GravesDock.refresh() end,
})

-- ============================================================
--  GRAVE PLACEMENT  (E on physical grave in world)
-- ============================================================
local selectGraveEvt = ReplicatedStorage:WaitForChild("SelectGrave", 5)
local placeAtGraveRemote = ReplicatedStorage:WaitForChild("PlaceAtGrave", 5)

if selectGraveEvt then
	selectGraveEvt.OnClientEvent:Connect(function(gravePos, slotIndex)
		local unit = inventory[selectedSlot]
		if not unit then
			return
		end -- nothing selected

		-- Deploy unit at this grave
		if placeAtGraveRemote then
			placeAtGraveRemote:FireServer(unit.unitType, gravePos, slotIndex)
		end

		-- Remove from inventory
		inventory[selectedSlot] = nil
		refreshToolbar()
		updateCarriedUnit()
	end)
end

-- ============================================================
--  RECALL UNIT  (server returns a unit from a grave to inventory)
-- ============================================================
local recallUnitEvt = ReplicatedStorage:WaitForChild("RecallUnit", 5)
if recallUnitEvt then
	recallUnitEvt.OnClientEvent:Connect(function(unitType, oneIn)
		local added = addToInventory(unitType, oneIn)
		if not added then
			local warn = Instance.new("TextLabel", screenGui)
			warn.Size = UDim2.new(0, 280, 0, 40)
			warn.Position = UDim2.new(0.5, -140, 1, -200)
			warn.BackgroundColor3 = Color3.fromRGB(120, 30, 30)
			warn.BackgroundTransparency = 0.2
			warn.Text = "⚠️ Inventory full — " .. unitType .. " lost!"
			warn.TextColor3 = Color3.fromRGB(255, 180, 180)
			warn.TextScaled = true
			warn.Font = Enum.Font.GothamBold
			warn.ZIndex = 50
			warn.BorderSizePixel = 0
			Instance.new("UICorner", warn).CornerRadius = UDim.new(0, 8)
			game:GetService("Debris"):AddItem(warn, 2.5)
		end
	end)
end

-- ============================================================
--  WALL BREAK REWARDS
-- ============================================================
local camera = workspace.CurrentCamera

local function screenShake(intensity, duration)
	local elapsed = 0
	local conn
	conn = RunService.RenderStepped:Connect(function(dt)
		elapsed += dt
		if elapsed >= duration then
			conn:Disconnect()
			return
		end
		local fade = 1 - (elapsed / duration)
		camera.CFrame = camera.CFrame
			* CFrame.new(
				math.random(-100, 100) / 100 * intensity * fade,
				math.random(-100, 100) / 100 * intensity * fade,
				0
			)
	end)
end

local function showBigText(line1, line2, color1, color2)
	local bd = Instance.new("Frame")
	bd.Size = UDim2.new(0, 500, 0, 160)
	bd.Position = UDim2.new(0.5, -250, 0.35, -80)
	bd.BackgroundColor3 = Color3.fromRGB(15, 5, 35)
	bd.BackgroundTransparency = 0.2
	bd.BorderSizePixel = 0
	bd.ZIndex = 20
	Instance.new("UICorner", bd).CornerRadius = UDim.new(0, 18)
	bd.Parent = screenGui

	local top = Instance.new("TextLabel", bd)
	top.Size = UDim2.new(1, 0, 0.55, 0)
	top.BackgroundTransparency = 1
	top.Text = line1
	top.TextColor3 = color1
	top.TextScaled = true
	top.Font = Enum.Font.GothamBold
	top.ZIndex = 21

	local bot = Instance.new("TextLabel", bd)
	bot.Size = UDim2.new(1, 0, 0.45, 0)
	bot.Position = UDim2.new(0, 0, 0.55, 0)
	bot.BackgroundTransparency = 1
	bot.Text = line2
	bot.TextColor3 = color2
	bot.TextScaled = true
	bot.Font = Enum.Font.Gotham
	bot.ZIndex = 21

	bd.Size = UDim2.new(0, 100, 0, 40)
	bd.Position = UDim2.new(0.5, -50, 0.35, -20)
	TweenService:Create(
		bd,
		TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Size = UDim2.new(0, 500, 0, 160), Position = UDim2.new(0.5, -250, 0.35, -80) }
	):Play()

	task.delay(2.2, function()
		TweenService:Create(bd, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
		TweenService:Create(top, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
		TweenService:Create(bot, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
		task.delay(0.45, function()
			bd:Destroy()
		end)
	end)
end

local function spawnConfetti()
	local colors = {
		Color3.fromRGB(255, 100, 180),
		Color3.fromRGB(100, 200, 255),
		Color3.fromRGB(255, 220, 80),
		Color3.fromRGB(160, 255, 130),
		Color3.fromRGB(200, 130, 255),
	}
	for _ = 1, 35 do
		local p = Instance.new("Frame")
		p.Size = UDim2.new(0, math.random(8, 18), 0, math.random(8, 18))
		p.Position = UDim2.new(math.random(10, 90) / 100, 0, -0.05, 0)
		p.Rotation = math.random(0, 360)
		p.BackgroundColor3 = colors[math.random(#colors)]
		p.BorderSizePixel = 0
		p.ZIndex = 19
		p.Parent = screenGui
		local ft = math.random(12, 22) / 10
		TweenService:Create(p, TweenInfo.new(ft, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = UDim2.new(p.Position.X.Scale, 0, math.random(80, 110) / 100, 0),
			Rotation = p.Rotation + math.random(180, 540),
		}):Play()
		game:GetService("Debris"):AddItem(p, ft + 0.1)
	end
end

local wallBreakEvt = ReplicatedStorage:WaitForChild("WallBreak", 5)
if wallBreakEvt then
	wallBreakEvt.OnClientEvent:Connect(function(goldReward, clearedLayer)
		gold += math.floor(goldReward * (goldMultiplier + coinBoostLevel * 0.5))
		updateHUD()
		screenShake(0.35, 0.6)
		spawnConfetti()
		showBigText(
			"🎉 WALL CLEARED!",
			"Layer " .. (clearedLayer or "?") .. " destroyed!   +" .. goldReward .. " Gold",
			Color3.fromRGB(255, 220, 80),
			Color3.fromRGB(200, 170, 255)
		)
	end)
end

local damageEvt = ReplicatedStorage:WaitForChild("DamageHit", 5)
if damageEvt then
	damageEvt.OnClientEvent:Connect(function(amount, worldPos, isGhost)
		local anchor = Instance.new("Part")
		anchor.Size = Vector3.new(0.1, 0.1, 0.1)
		anchor.Position = worldPos + Vector3.new(-4, 0, 0)
		anchor.Anchored = false
		anchor.CanCollide = false
		anchor.Transparency = 1
		anchor.Parent = workspace

		local bv = Instance.new("BodyVelocity")
		bv.Velocity = Vector3.new(math.random(-2, 2), 8, math.random(-1, 1))
		bv.MaxForce = Vector3.new(1e4, 1e4, 1e4)
		bv.P = 1e4
		bv.Parent = anchor

		local gui = Instance.new("BillboardGui", anchor)
		gui.Size = UDim2.new(0, 80, 0, 45)
		gui.AlwaysOnTop = true
		gui.LightInfluence = 0

		local lbl = Instance.new("TextLabel", gui)
		lbl.Size = UDim2.new(1, 0, 1, 0)
		lbl.BackgroundTransparency = 1
		lbl.Text = "-" .. amount
		lbl.TextScaled = true
		lbl.Font = Enum.Font.GothamBold
		lbl.TextColor3 = isGhost and Color3.fromRGB(29, 59, 255) or Color3.fromRGB(255, 64, 6)

		TweenService
			:Create(lbl, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { TextTransparency = 1 })
			:Play()
		game:GetService("Debris"):AddItem(anchor, 1)
	end)
end

-- ============================================================
--  ROLL RESULT
-- ============================================================
local rollResultEvt = ReplicatedStorage:WaitForChild("RollResult", 5)
if rollResultEvt then
	rollResultEvt.OnClientEvent:Connect(function(unitType, rarity, pity, oneIn)
		playRollAnimation(unitType, rarity, pity, oneIn)
	end)
end

-- ============================================================
--  SHOP / GRAVE NPC OPEN EVENTS
-- ============================================================
local openGraveEvt = ReplicatedStorage:WaitForChild("OpenGrave", 5)
if openGraveEvt then
	openGraveEvt.OnClientEvent:Connect(function()
		ShopPanel.show()
	end)
end

-- ============================================================
--  ASCEND (REBIRTH) SYSTEM
-- ============================================================
local ascendBtn = Instance.new("TextButton")
ascendBtn.Size = UDim2.new(0, 160, 0, 42)
ascendBtn.Position = UDim2.new(0, 10, 1, -58)
ascendBtn.BackgroundColor3 = Color3.fromRGB(90, 30, 10)
ascendBtn.Text = "⬆️ Ascend"
ascendBtn.TextColor3 = Color3.fromRGB(255, 190, 80)
ascendBtn.TextScaled = true
ascendBtn.Font = Enum.Font.GothamBold
ascendBtn.BorderSizePixel = 0
ascendBtn.Parent = screenGui
Instance.new("UICorner", ascendBtn).CornerRadius = UDim.new(0, 10)

local ascendPanel = Instance.new("Frame")
ascendPanel.Name = "AscendPanel"
ascendPanel.Size = UDim2.new(0, 420, 0, 280)
ascendPanel.Position = UDim2.new(0.5, -210, 0.5, -140)
ascendPanel.BackgroundColor3 = Color3.fromRGB(20, 8, 5)
ascendPanel.BorderSizePixel = 0
ascendPanel.Visible = false
ascendPanel.ZIndex = 50
ascendPanel.Parent = screenGui
Instance.new("UICorner", ascendPanel).CornerRadius = UDim.new(0, 16)

local ascendTitle = Instance.new("TextLabel", ascendPanel)
ascendTitle.Size = UDim2.new(1, -20, 0, 50)
ascendTitle.Position = UDim2.new(0, 10, 0, 10)
ascendTitle.BackgroundTransparency = 1
ascendTitle.Text = "⬆️ ASCEND"
ascendTitle.TextColor3 = Color3.fromRGB(255, 190, 80)
ascendTitle.TextScaled = true
ascendTitle.Font = Enum.Font.GothamBold
ascendTitle.ZIndex = 51

local ascendWarning = Instance.new("TextLabel", ascendPanel)
ascendWarning.Size = UDim2.new(1, -20, 0, 36)
ascendWarning.Position = UDim2.new(0, 10, 0, 62)
ascendWarning.BackgroundTransparency = 1
ascendWarning.Text = "⚠️ You will lose all your Gold!"
ascendWarning.TextColor3 = Color3.fromRGB(255, 120, 80)
ascendWarning.TextScaled = true
ascendWarning.Font = Enum.Font.GothamBold
ascendWarning.ZIndex = 51

local ascendInfoLbl = Instance.new("TextLabel", ascendPanel)
ascendInfoLbl.Size = UDim2.new(1, -20, 0, 80)
ascendInfoLbl.Position = UDim2.new(0, 10, 0, 104)
ascendInfoLbl.BackgroundTransparency = 1
ascendInfoLbl.TextColor3 = Color3.fromRGB(220, 200, 255)
ascendInfoLbl.TextScaled = true
ascendInfoLbl.Font = Enum.Font.Gotham
ascendInfoLbl.TextWrapped = true
ascendInfoLbl.ZIndex = 51

local ascendConfirmBtn = Instance.new("TextButton", ascendPanel)
ascendConfirmBtn.Size = UDim2.new(0, 170, 0, 44)
ascendConfirmBtn.Position = UDim2.new(0, 20, 1, -60)
ascendConfirmBtn.BackgroundColor3 = Color3.fromRGB(140, 60, 10)
ascendConfirmBtn.Text = "✅ Confirm Ascend"
ascendConfirmBtn.TextColor3 = Color3.fromRGB(255, 230, 150)
ascendConfirmBtn.TextScaled = true
ascendConfirmBtn.Font = Enum.Font.GothamBold
ascendConfirmBtn.BorderSizePixel = 0
ascendConfirmBtn.ZIndex = 51
Instance.new("UICorner", ascendConfirmBtn).CornerRadius = UDim.new(0, 10)

local ascendCancelBtn = Instance.new("TextButton", ascendPanel)
ascendCancelBtn.Size = UDim2.new(0, 170, 0, 44)
ascendCancelBtn.Position = UDim2.new(1, -190, 1, -60)
ascendCancelBtn.BackgroundColor3 = Color3.fromRGB(50, 25, 25)
ascendCancelBtn.Text = "✖ Cancel"
ascendCancelBtn.TextColor3 = Color3.fromRGB(200, 150, 150)
ascendCancelBtn.TextScaled = true
ascendCancelBtn.Font = Enum.Font.GothamBold
ascendCancelBtn.BorderSizePixel = 0
ascendCancelBtn.ZIndex = 51
Instance.new("UICorner", ascendCancelBtn).CornerRadius = UDim.new(0, 10)

local ASCEND_UNLOCKS = {
	[1] = "Unlocks: Stone Coffin grave",
	[2] = "Unlocks: Ancient Tomb grave",
}

local function updateAscendPanel()
	local tier = rebirthCount + 1
	local cost = ASCEND_COSTS[math.min(tier, #ASCEND_COSTS)]
	local unlockText = ASCEND_UNLOCKS[tier] or "No new unlocks — gold multiplier only"
	local newMult = 1.0 + (rebirthCount + 1)
	ascendInfoLbl.Text =
		string.format("Cost: 💰 %s Gold\n%s\nNew gold multiplier: %.0fx", fmt(cost), unlockText, newMult)
	local canAfford = gold >= cost
	ascendConfirmBtn.BackgroundColor3 = canAfford and Color3.fromRGB(140, 60, 10) or Color3.fromRGB(50, 25, 10)
	ascendConfirmBtn.TextColor3 = canAfford and Color3.fromRGB(255, 230, 150) or Color3.fromRGB(130, 100, 60)
end

ascendBtn.MouseButton1Click:Connect(function()
	updateAscendPanel()
	ascendPanel.Visible = true
end)
ascendCancelBtn.MouseButton1Click:Connect(function()
	ascendPanel.Visible = false
end)

ascendConfirmBtn.MouseButton1Click:Connect(function()
	local tier = rebirthCount + 1
	local cost = ASCEND_COSTS[math.min(tier, #ASCEND_COSTS)]
	if gold < cost then
		return
	end

	gold = 0
	rebirthCount += 1
	goldMultiplier = 1.0 + rebirthCount

	-- Remove the lock overlay for whichever grave tier just unlocked
	for _, gd in ipairs(GRAVE_DATA) do
		if gd.unlockAscension == rebirthCount then
			ShopPanel.unlockGrave(gd.key)
		end
	end

	ascendPanel.Visible = false
	updateHUD()
	ShopPanel.updateGraveyard()

	local ascendRemote = ReplicatedStorage:FindFirstChild("PlayerAscend")
	if ascendRemote then
		ascendRemote:FireServer()
	end

	showBigText(
		"⬆️ ASCENDED!",
		"Ascension " .. rebirthCount .. "  |  " .. string.format("%.0fx", goldMultiplier) .. " Gold Multiplier",
		Color3.fromRGB(255, 190, 80),
		Color3.fromRGB(255, 220, 150)
	)
end)

-- ============================================================
--  SELL PANEL
-- ============================================================
local sellUnitRemote = ReplicatedStorage:WaitForChild("SellUnit", 5)
local openSellEvt = ReplicatedStorage:WaitForChild("OpenSell", 5)

local function getSellValue(oneIn)
	return math.floor((oneIn or 1) ^ 1.2 * 5)
end

-- Panel backdrop
local sellPanel = Instance.new("Frame")
sellPanel.Name = "SellPanel"
sellPanel.Size = UDim2.new(0, 420, 0, 480)
sellPanel.Position = UDim2.new(0.5, -210, 0.5, -240)
sellPanel.BackgroundColor3 = Color3.fromRGB(18, 10, 4)
sellPanel.BorderSizePixel = 0
sellPanel.Visible = false
sellPanel.ZIndex = 50
sellPanel.Parent = screenGui
Instance.new("UICorner", sellPanel).CornerRadius = UDim.new(0, 16)

do -- sell panel header setup
	local sellStroke = Instance.new("UIStroke", sellPanel)
	sellStroke.Color = Color3.fromRGB(200, 140, 40)
	sellStroke.Thickness = 2
	local sellTitle = Instance.new("TextLabel", sellPanel)
	sellTitle.Size = UDim2.new(1, -20, 0, 48)
	sellTitle.Position = UDim2.new(0, 10, 0, 8)
	sellTitle.BackgroundTransparency = 1
	sellTitle.Text = "💰 Sell Units"
	sellTitle.TextColor3 = Color3.fromRGB(255, 220, 80)
	sellTitle.TextScaled = true
	sellTitle.Font = Enum.Font.GothamBold
	sellTitle.ZIndex = 51
	local sellCloseBtn = Instance.new("TextButton", sellPanel)
	sellCloseBtn.Size = UDim2.new(0, 36, 0, 36)
	sellCloseBtn.Position = UDim2.new(1, -44, 0, 8)
	sellCloseBtn.BackgroundColor3 = Color3.fromRGB(80, 20, 20)
	sellCloseBtn.Text = "✕"
	sellCloseBtn.TextColor3 = Color3.fromRGB(255, 120, 120)
	sellCloseBtn.TextScaled = true
	sellCloseBtn.Font = Enum.Font.GothamBold
	sellCloseBtn.BorderSizePixel = 0
	sellCloseBtn.ZIndex = 52
	Instance.new("UICorner", sellCloseBtn).CornerRadius = UDim.new(0, 8)
	sellCloseBtn.MouseButton1Click:Connect(function()
		sellPanel.Visible = false
	end)
end

-- Scrollable list of inventory slots
local sellScroll = Instance.new("ScrollingFrame", sellPanel)
sellScroll.Size = UDim2.new(1, -20, 1, -70)
sellScroll.Position = UDim2.new(0, 10, 0, 58)
sellScroll.BackgroundTransparency = 1
sellScroll.BorderSizePixel = 0
sellScroll.ScrollBarThickness = 6
sellScroll.ScrollBarImageColor3 = Color3.fromRGB(200, 140, 40)
sellScroll.ZIndex = 51

local sellList = Instance.new("UIListLayout", sellScroll)
sellList.Padding = UDim.new(0, 6)
sellList.SortOrder = Enum.SortOrder.LayoutOrder

local function refreshSellPanel()
	-- Clear old rows (keep UIListLayout)
	for _, child in ipairs(sellScroll:GetChildren()) do
		if not child:IsA("UIListLayout") then
			child:Destroy()
		end
	end

	local rowCount = 0
	for i = 1, INVENTORY_MAX do
		local unit = inventory[i]
		if unit then
			local info = UNIT_INFO[unit.unitType]
			local oneIn = unit.oneIn or UNIT_ONE_IN[unit.unitType] or 1
			local sell = getSellValue(oneIn)
			local rColor = (info and RARITY_COLORS[info.rarity]) or Color3.fromRGB(200, 200, 200)
			local emoji = (info and info.emoji) or "💀"
			local rarity = (info and info.rarity) or "?"

			local row = Instance.new("Frame", sellScroll)
			row.Size = UDim2.new(1, 0, 0, 54)
			row.BackgroundColor3 = Color3.fromRGB(30, 18, 8)
			row.BorderSizePixel = 0
			row.LayoutOrder = i
			row.ZIndex = 52
			Instance.new("UICorner", row).CornerRadius = UDim.new(0, 8)

			-- Name + rarity
			local nameLbl = Instance.new("TextLabel", row)
			nameLbl.Size = UDim2.new(0.55, 0, 0.5, 0)
			nameLbl.Position = UDim2.new(0, 10, 0, 2)
			nameLbl.BackgroundTransparency = 1
			nameLbl.Text = emoji .. " " .. unit.unitType
			nameLbl.TextColor3 = Color3.fromRGB(240, 230, 210)
			nameLbl.TextScaled = true
			nameLbl.Font = Enum.Font.GothamBold
			nameLbl.TextXAlignment = Enum.TextXAlignment.Left
			nameLbl.ZIndex = 53

			local rarLbl = Instance.new("TextLabel", row)
			rarLbl.Size = UDim2.new(0.55, 0, 0.42, 0)
			rarLbl.Position = UDim2.new(0, 10, 0.52, 0)
			rarLbl.BackgroundTransparency = 1
			rarLbl.Text = rarity .. "  •  1 in " .. oneIn
			rarLbl.TextColor3 = rColor
			rarLbl.TextScaled = true
			rarLbl.Font = Enum.Font.Gotham
			rarLbl.TextXAlignment = Enum.TextXAlignment.Left
			rarLbl.ZIndex = 53

			-- Sell button
			local sellBtn = Instance.new("TextButton", row)
			sellBtn.Size = UDim2.new(0, 110, 0, 36)
			sellBtn.Position = UDim2.new(1, -120, 0.5, -18)
			sellBtn.BackgroundColor3 = Color3.fromRGB(160, 100, 10)
			sellBtn.Text = "Sell  💰" .. sell
			sellBtn.TextColor3 = Color3.fromRGB(255, 230, 120)
			sellBtn.TextScaled = true
			sellBtn.Font = Enum.Font.GothamBold
			sellBtn.BorderSizePixel = 0
			sellBtn.ZIndex = 53
			Instance.new("UICorner", sellBtn).CornerRadius = UDim.new(0, 8)

			local slotIndex = i
			sellBtn.MouseButton1Click:Connect(function()
				if not inventory[slotIndex] then
					return
				end
				local u = inventory[slotIndex]
				if sellUnitRemote then
					sellUnitRemote:FireServer(u.unitType, u.oneIn or UNIT_ONE_IN[u.unitType] or 1)
				end
				inventory[slotIndex] = nil
				refreshToolbar()
				refreshSellPanel()
			end)

			rowCount += 1
		end
	end

	-- Empty state message
	if rowCount == 0 then
		local emptyLbl = Instance.new("TextLabel", sellScroll)
		emptyLbl.Size = UDim2.new(1, 0, 0, 50)
		emptyLbl.BackgroundTransparency = 1
		emptyLbl.Text = "No units in inventory"
		emptyLbl.TextColor3 = Color3.fromRGB(140, 120, 90)
		emptyLbl.TextScaled = true
		emptyLbl.Font = Enum.Font.Gotham
		emptyLbl.ZIndex = 52
	end

	sellScroll.CanvasSize = UDim2.new(0, 0, 0, rowCount * 60)
end


-- AddGold remote — server sends gold reward after a sell
local addGoldEvt = ReplicatedStorage:WaitForChild("AddGold", 5)
if addGoldEvt then
	addGoldEvt.OnClientEvent:Connect(function(amount, unitType)
		gold += math.floor(amount * (1 + coinBoostLevel * 0.5))
		updateHUD()
		showBigText(
			"💰 SOLD!",
			unitType .. "  +  " .. amount .. " Gold",
			Color3.fromRGB(255, 220, 80),
			Color3.fromRGB(200, 170, 60)
		)
	end)
end

if openSellEvt then
	openSellEvt.OnClientEvent:Connect(function()
		refreshSellPanel()
		sellPanel.Visible = true
	end)
end

-- ============================================================
--  UPGRADE PANEL
-- ============================================================
local buyUpgradeRemote = ReplicatedStorage:WaitForChild("BuyUpgrade", 5)
local upgradeGrantedEvt = ReplicatedStorage:WaitForChild("UpgradeGranted", 5)
local openUpgradeEvt = ReplicatedStorage:WaitForChild("OpenUpgrade", 5)

local upgradePanel = Instance.new("Frame")
upgradePanel.Name = "UpgradePanel"
upgradePanel.Size = UDim2.new(0, 420, 0, 320)
upgradePanel.Position = UDim2.new(0.5, -210, 0.5, -160)
upgradePanel.BackgroundColor3 = Color3.fromRGB(6, 18, 20)
upgradePanel.BorderSizePixel = 0
upgradePanel.Visible = false
upgradePanel.ZIndex = 50
upgradePanel.Parent = screenGui
Instance.new("UICorner", upgradePanel).CornerRadius = UDim.new(0, 16)
do -- upgrade panel header setup
	local upStroke = Instance.new("UIStroke", upgradePanel)
	upStroke.Color = Color3.fromRGB(50, 200, 200)
	upStroke.Thickness = 2
	local upTitle = Instance.new("TextLabel", upgradePanel)
	upTitle.Size = UDim2.new(1, -20, 0, 48)
	upTitle.Position = UDim2.new(0, 10, 0, 6)
	upTitle.BackgroundTransparency = 1
	upTitle.Text = "⚗️ Upgrades"
	upTitle.TextColor3 = Color3.fromRGB(100, 255, 240)
	upTitle.TextScaled = true
	upTitle.Font = Enum.Font.GothamBold
	upTitle.ZIndex = 51
	local upCloseBtn = Instance.new("TextButton", upgradePanel)
	upCloseBtn.Size = UDim2.new(0, 36, 0, 36)
	upCloseBtn.Position = UDim2.new(1, -44, 0, 8)
	upCloseBtn.BackgroundColor3 = Color3.fromRGB(40, 80, 80)
	upCloseBtn.Text = "✕"
	upCloseBtn.TextColor3 = Color3.fromRGB(100, 255, 240)
	upCloseBtn.TextScaled = true
	upCloseBtn.Font = Enum.Font.GothamBold
	upCloseBtn.BorderSizePixel = 0
	upCloseBtn.ZIndex = 52
	Instance.new("UICorner", upCloseBtn).CornerRadius = UDim.new(0, 8)
	upCloseBtn.MouseButton1Click:Connect(function()
		upgradePanel.Visible = false
	end)
end

-- Helper: build one upgrade row, returns a refresh function
local function makeUpgradeRow(parent, yPos, icon, title, getLevel, getMax, getCost, getEffectText)
	local row = Instance.new("Frame", parent)
	row.Size = UDim2.new(1, -20, 0, 100)
	row.Position = UDim2.new(0, 10, 0, yPos)
	row.BackgroundColor3 = Color3.fromRGB(10, 30, 32)
	row.BorderSizePixel = 0
	row.ZIndex = 51
	Instance.new("UICorner", row).CornerRadius = UDim.new(0, 12)

	local iconLbl = Instance.new("TextLabel", row)
	iconLbl.Size = UDim2.new(0, 48, 0, 48)
	iconLbl.Position = UDim2.new(0, 8, 0.5, -24)
	iconLbl.BackgroundColor3 = Color3.fromRGB(15, 50, 52)
	iconLbl.Text = icon
	iconLbl.TextScaled = true
	iconLbl.ZIndex = 52
	Instance.new("UICorner", iconLbl).CornerRadius = UDim.new(0, 10)

	local titleLbl = Instance.new("TextLabel", row)
	titleLbl.Size = UDim2.new(0.55, 0, 0, 26)
	titleLbl.Position = UDim2.new(0, 64, 0, 10)
	titleLbl.BackgroundTransparency = 1
	titleLbl.TextColor3 = Color3.fromRGB(200, 255, 250)
	titleLbl.TextScaled = true
	titleLbl.Font = Enum.Font.GothamBold
	titleLbl.TextXAlignment = Enum.TextXAlignment.Left
	titleLbl.ZIndex = 52

	local effectLbl = Instance.new("TextLabel", row)
	effectLbl.Size = UDim2.new(0.55, 0, 0, 22)
	effectLbl.Position = UDim2.new(0, 64, 0, 38)
	effectLbl.BackgroundTransparency = 1
	effectLbl.TextColor3 = Color3.fromRGB(100, 220, 180)
	effectLbl.TextScaled = true
	effectLbl.Font = Enum.Font.Gotham
	effectLbl.TextXAlignment = Enum.TextXAlignment.Left
	effectLbl.ZIndex = 52

	local nextLbl = Instance.new("TextLabel", row)
	nextLbl.Size = UDim2.new(0.55, 0, 0, 20)
	nextLbl.Position = UDim2.new(0, 64, 0, 62)
	nextLbl.BackgroundTransparency = 1
	nextLbl.TextColor3 = Color3.fromRGB(150, 180, 160)
	nextLbl.TextScaled = true
	nextLbl.Font = Enum.Font.Gotham
	nextLbl.TextXAlignment = Enum.TextXAlignment.Left
	nextLbl.ZIndex = 52

	local buyBtn = Instance.new("TextButton", row)
	buyBtn.Size = UDim2.new(0, 120, 0, 44)
	buyBtn.Position = UDim2.new(1, -130, 0.5, -22)
	buyBtn.BackgroundColor3 = Color3.fromRGB(20, 100, 100)
	buyBtn.TextColor3 = Color3.fromRGB(180, 255, 240)
	buyBtn.TextScaled = true
	buyBtn.Font = Enum.Font.GothamBold
	buyBtn.BorderSizePixel = 0
	buyBtn.ZIndex = 52
	Instance.new("UICorner", buyBtn).CornerRadius = UDim.new(0, 10)

	local function refresh()
		local level = getLevel()
		local max = getMax()
		local cost = getCost(level)
		local maxed = level >= max

		titleLbl.Text = title .. "  (Lv " .. level .. "/" .. max .. ")"
		effectLbl.Text = getEffectText(level)

		if maxed then
			nextLbl.Text = "✨ Maxed out!"
			buyBtn.Text = "MAX"
			buyBtn.BackgroundColor3 = Color3.fromRGB(30, 60, 50)
			buyBtn.TextColor3 = Color3.fromRGB(100, 160, 140)
			buyBtn.Active = false
		else
			nextLbl.Text = "Next: " .. getEffectText(level + 1)
			local canAfford = gold >= cost
			buyBtn.Text = "Buy\n💰 " .. fmtGold(cost)
			buyBtn.BackgroundColor3 = canAfford and Color3.fromRGB(20, 120, 110) or Color3.fromRGB(15, 50, 50)
			buyBtn.TextColor3 = canAfford and Color3.fromRGB(180, 255, 240) or Color3.fromRGB(80, 130, 120)
			buyBtn.Active = true
		end
	end

	return buyBtn, refresh
end

-- Luck Boost row
local luckBuyBtn, refreshLuckRow = makeUpgradeRow(
	upgradePanel,
	62,
	"🍀",
	"Luck Boost",
	function()
		return luckBoostLevel
	end,
	function()
		return UPGRADE_MAX.luckBoost
	end,
	luckBoostCost,
	function(lv)
		return "+" .. (lv * 10) .. "% luck on all graves"
	end
)

-- Coin Boost row
local coinBuyBtn, refreshCoinRow = makeUpgradeRow(
	upgradePanel,
	172,
	"💰",
	"Coin Boost",
	function()
		return coinBoostLevel
	end,
	function()
		return UPGRADE_MAX.coinBoost
	end,
	coinBoostCost,
	function(lv)
		return "+" .. string.format("%.1fx", lv * 0.5) .. " gold multiplier"
	end
)

local function refreshUpgradePanel()
	refreshLuckRow()
	refreshCoinRow()
end

luckBuyBtn.MouseButton1Click:Connect(function()
	if luckBoostLevel >= UPGRADE_MAX.luckBoost then
		return
	end
	local cost = luckBoostCost(luckBoostLevel)
	if gold < cost then
		return
	end
	gold -= cost
	updateHUD()
	if buyUpgradeRemote then
		buyUpgradeRemote:FireServer("luckBoost")
	end
end)

coinBuyBtn.MouseButton1Click:Connect(function()
	if coinBoostLevel >= UPGRADE_MAX.coinBoost then
		return
	end
	local cost = coinBoostCost(coinBoostLevel)
	if gold < cost then
		return
	end
	gold -= cost
	updateHUD()
	if buyUpgradeRemote then
		buyUpgradeRemote:FireServer("coinBoost")
	end
end)

if upgradeGrantedEvt then
	upgradeGrantedEvt.OnClientEvent:Connect(function(upgradeType, newLevel)
		if upgradeType == "luckBoost" then
			luckBoostLevel = newLevel
		elseif upgradeType == "coinBoost" then
			coinBoostLevel = newLevel
		end
		refreshUpgradePanel()
	end)
end

if openUpgradeEvt then
	openUpgradeEvt.OnClientEvent:Connect(function()
		refreshUpgradePanel()
		upgradePanel.Visible = true
	end)
end

-- ============================================================
--  LUCKY WHEEL
-- ============================================================

-- Outcome definitions (must match server order exactly; chance % shown on card)
local WHEEL_OUTCOMES = {
	{
		id = "gold_1k",
		label = "+1k Gold",
		emoji = "💰",
		chance = "50%",
		color = Color3.fromRGB(220, 160, 10),
	},
	{
		id = "luck_buff",
		label = "2x Luck 5min",
		emoji = "🍀",
		chance = "10%",
		color = Color3.fromRGB(30, 150, 30),
	},
	{
		id = "gems_50",
		label = "+50 Gems",
		emoji = "💎",
		chance = "16%",
		color = Color3.fromRGB(50, 120, 220),
	},
	{
		id = "graves_5",
		label = "+5 Graves",
		emoji = "🪦",
		chance = "10%",
		color = Color3.fromRGB(120, 60, 200),
	},
	{
		id = "gems_100",
		label = "+100 Gems",
		emoji = "💎",
		chance = "8%",
		color = Color3.fromRGB(20, 70, 200),
	},
	{
		id = "grave_rare",
		label = "+1 Rare Grave",
		emoji = "🌑",
		chance = "5%",
		color = Color3.fromRGB(60, 20, 130),
	},
	{
		id = "lucky_box",
		label = "Lucky Box!",
		emoji = "📦",
		chance = "1%",
		color = Color3.fromRGB(200, 40, 40),
	},
}
local NUM_OUTCOMES = #WHEEL_OUTCOMES

-- Wheel panel
do
	local CARD_W = 130
	local CARD_H = 150
	local CARD_GAP = 8
	local VISIBLE_CARDS = 7 -- how many cards are visible at once
	local STRIP_W = VISIBLE_CARDS * (CARD_W + CARD_GAP) - CARD_GAP
	local REPEATS = 12 -- how many full loops of outcomes in the strip

	wheelPanel = Instance.new("Frame")
	wheelPanel.Name = "WheelPanel"
	wheelPanel.Size = UDim2.new(0, STRIP_W + 60, 0, 380)
	wheelPanel.Position = UDim2.new(0.5, -(STRIP_W + 60) / 2, 0.5, -190)
	wheelPanel.BackgroundColor3 = Color3.fromRGB(20, 10, 40)
	wheelPanel.BackgroundTransparency = 0.05
	wheelPanel.BorderSizePixel = 0
	wheelPanel.ZIndex = 60
	wheelPanel.Visible = false
	wheelPanel.Parent = screenGui
	Instance.new("UICorner", wheelPanel).CornerRadius = UDim.new(0, 18)

	-- Title
	local wTitle = Instance.new("TextLabel", wheelPanel)
	wTitle.Size = UDim2.new(1, 0, 0, 50)
	wTitle.Position = UDim2.new(0, 0, 0, 0)
	wTitle.BackgroundTransparency = 1
	wTitle.Text = "🎡 Lucky Wheel"
	wTitle.TextColor3 = Color3.fromRGB(255, 220, 100)
	wTitle.TextScaled = true
	wTitle.Font = Enum.Font.GothamBold
	wTitle.ZIndex = 61

	-- Close button
	local wClose = Instance.new("TextButton", wheelPanel)
	wClose.Size = UDim2.new(0, 36, 0, 36)
	wClose.Position = UDim2.new(1, -44, 0, 8)
	wClose.BackgroundColor3 = Color3.fromRGB(80, 30, 30)
	wClose.Text = "✕"
	wClose.TextColor3 = Color3.fromRGB(255, 180, 180)
	wClose.TextScaled = true
	wClose.Font = Enum.Font.GothamBold
	wClose.BorderSizePixel = 0
	wClose.ZIndex = 62
	Instance.new("UICorner", wClose).CornerRadius = UDim.new(0, 8)
	wClose.MouseButton1Click:Connect(function()
		wheelPanel.Visible = false
	end)

	-- Spin count label
	local wSpinCount = Instance.new("TextLabel", wheelPanel)
	wSpinCount.Name = "SpinCount"
	wSpinCount.Size = UDim2.new(1, 0, 0, 26)
	wSpinCount.Position = UDim2.new(0, 0, 0, 48)
	wSpinCount.BackgroundTransparency = 1
	wSpinCount.Text = "Spins available: 0"
	wSpinCount.TextColor3 = Color3.fromRGB(200, 200, 255)
	wSpinCount.TextScaled = true
	wSpinCount.Font = Enum.Font.Gotham
	wSpinCount.ZIndex = 61

	-- Countdown label
	local wCountdown = Instance.new("TextLabel", wheelPanel)
	wCountdown.Name = "Countdown"
	wCountdown.Size = UDim2.new(1, 0, 0, 22)
	wCountdown.Position = UDim2.new(0, 0, 0, 72)
	wCountdown.BackgroundTransparency = 1
	wCountdown.Text = "Next spin in: 15:00"
	wCountdown.TextColor3 = Color3.fromRGB(160, 160, 200)
	wCountdown.TextScaled = true
	wCountdown.Font = Enum.Font.Gotham
	wCountdown.ZIndex = 61

	-- Strip container (clips cards)
	local stripClip = Instance.new("Frame", wheelPanel)
	stripClip.Size = UDim2.new(0, STRIP_W, 0, CARD_H)
	stripClip.Position = UDim2.new(0, 30, 0, 104)
	stripClip.BackgroundTransparency = 1
	stripClip.ClipsDescendants = true
	stripClip.ZIndex = 61

	-- Highlight box (center of strip - shows the "winning" position)
	local highlightBox = Instance.new("Frame", wheelPanel)
	highlightBox.Size = UDim2.new(0, CARD_W + 8, 0, CARD_H + 8)
	highlightBox.Position = UDim2.new(0, 30 + (VISIBLE_CARDS // 2) * (CARD_W + CARD_GAP) - 4, 0, 100)
	highlightBox.BackgroundTransparency = 1
	highlightBox.BorderSizePixel = 3
	highlightBox.ZIndex = 65
	local hlStroke = Instance.new("UIStroke", highlightBox)
	hlStroke.Color = Color3.fromRGB(255, 220, 50)
	hlStroke.Thickness = 3

	-- Build the strip (REPEATS * NUM_OUTCOMES cards)
	local totalCards = REPEATS * NUM_OUTCOMES
	local stripInner = Instance.new("Frame", stripClip)
	stripInner.Name = "StripInner"
	stripInner.Size = UDim2.new(0, totalCards * (CARD_W + CARD_GAP), 0, CARD_H)
	stripInner.Position = UDim2.new(0, 0, 0, 0)
	stripInner.BackgroundTransparency = 1
	stripInner.ZIndex = 62

	for i = 1, totalCards do
		local oi = ((i - 1) % NUM_OUTCOMES) + 1
		local o = WHEEL_OUTCOMES[oi]
		local card = Instance.new("Frame", stripInner)
		card.Size = UDim2.new(0, CARD_W, 0, CARD_H)
		card.Position = UDim2.new(0, (i - 1) * (CARD_W + CARD_GAP), 0, 0)
		card.BackgroundColor3 = o.color
		card.BorderSizePixel = 0
		card.ZIndex = 63
		Instance.new("UICorner", card).CornerRadius = UDim.new(0, 12)

		local emojiLbl = Instance.new("TextLabel", card)
		emojiLbl.Size = UDim2.new(1, 0, 0, 60)
		emojiLbl.Position = UDim2.new(0, 0, 0, 12)
		emojiLbl.BackgroundTransparency = 1
		emojiLbl.Text = o.emoji
		emojiLbl.TextScaled = true
		emojiLbl.Font = Enum.Font.GothamBold
		emojiLbl.ZIndex = 64

		local nameLbl = Instance.new("TextLabel", card)
		nameLbl.Size = UDim2.new(1, -8, 0, 40)
		nameLbl.Position = UDim2.new(0, 4, 0, 74)
		nameLbl.BackgroundTransparency = 1
		nameLbl.Text = o.label
		nameLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
		nameLbl.TextScaled = true
		nameLbl.Font = Enum.Font.GothamBold
		nameLbl.TextWrapped = true
		nameLbl.ZIndex = 64

		local chanceLbl = Instance.new("TextLabel", card)
		chanceLbl.Size = UDim2.new(1, -8, 0, 26)
		chanceLbl.Position = UDim2.new(0, 4, 0, 116)
		chanceLbl.BackgroundTransparency = 1
		chanceLbl.Text = o.chance
		chanceLbl.TextColor3 = Color3.fromRGB(180, 255, 140)
		chanceLbl.TextScaled = true
		chanceLbl.Font = Enum.Font.GothamBold
		chanceLbl.ZIndex = 64
	end

	-- Spin button
	local spinBtn = Instance.new("TextButton", wheelPanel)
	spinBtn.Name = "SpinBtn"
	spinBtn.Size = UDim2.new(0, 200, 0, 50)
	spinBtn.Position = UDim2.new(0.5, -100, 0, 268)
	spinBtn.BackgroundColor3 = Color3.fromRGB(180, 100, 0)
	spinBtn.Text = "SPIN!"
	spinBtn.TextColor3 = Color3.fromRGB(255, 240, 180)
	spinBtn.TextScaled = true
	spinBtn.Font = Enum.Font.GothamBold
	spinBtn.BorderSizePixel = 0
	spinBtn.ZIndex = 61
	Instance.new("UICorner", spinBtn).CornerRadius = UDim.new(0, 12)

	-- Result label (shown after spin)
	local resultLbl = Instance.new("TextLabel", wheelPanel)
	resultLbl.Name = "ResultLbl"
	resultLbl.Size = UDim2.new(1, -20, 0, 42)
	resultLbl.Position = UDim2.new(0, 10, 0, 325)
	resultLbl.BackgroundTransparency = 1
	resultLbl.Text = ""
	resultLbl.TextColor3 = Color3.fromRGB(255, 255, 180)
	resultLbl.TextScaled = true
	resultLbl.Font = Enum.Font.GothamBold
	resultLbl.ZIndex = 61

	-- ── Wheel logic ──────────────────────────────────────────
	local spinning = false
	local pendingSpin = false -- true while waiting for server response

	local function refreshWheelUI()
		local sc = wheelPanel:FindFirstChild("SpinCount")
		if sc then
			sc.Text = "Spins available: " .. wheelSpins
		end
		local canSpin = wheelSpins > 0 and not spinning and not pendingSpin
		spinBtn.BackgroundColor3 = canSpin and Color3.fromRGB(180, 100, 0) or Color3.fromRGB(60, 40, 20)
		spinBtn.Active = canSpin
	end

	-- Animate strip landing on outcomeIdx (1-based in WHEEL_OUTCOMES)
	local function playSpinAnimation(outcomeIdx, onDone)
		spinning = true
		spinBtn.Active = false
		resultLbl.Text = ""
		stripInner.Position = UDim2.new(0, 0, 0, 0)

		-- The center visible card index (0-based) is VISIBLE_CARDS // 2
		local centerCard = math.floor(VISIBLE_CARDS / 2) -- = 3

		-- We want to land so the card at 'centerCard' position in view
		-- is an outcome card matching outcomeIdx.
		-- In the second-to-last "loop" of repeats, find the matching card index (0-based)
		local targetLoop = REPEATS - 2 -- land somewhere near the end but not last loop
		-- Card index (0-based): targetLoop*NUM_OUTCOMES + (outcomeIdx - 1)
		local targetCardIdx = targetLoop * NUM_OUTCOMES + (outcomeIdx - 1)
		-- The X position where the strip should stop so targetCard is centered:
		-- stripInner.X = -(targetCardIdx * (CARD_W+CARD_GAP)) + centerCard * (CARD_W+CARD_GAP)
		local finalX = -(targetCardIdx * (CARD_W + CARD_GAP)) + centerCard * (CARD_W + CARD_GAP)

		-- Strip scrolls LEFT (X decreases). Stop several full loops BEFORE
		-- finalX so the slow tween continues leftward into the landing position.
		local loopWidth = NUM_OUTCOMES * (CARD_W + CARD_GAP)
		local fastTarget = finalX + 4 * loopWidth -- 4 loops before final landing
		-- First tween: fast linear scroll to a point before landing
		local fastTween = TweenService:Create(
			stripInner,
			TweenInfo.new(2.5, Enum.EasingStyle.Linear),
			{ Position = UDim2.new(0, fastTarget, 0, 0) }
		)
		-- Second tween: slow decelerate the remaining distance to the winning card
		local slowTween = TweenService:Create(
			stripInner,
			TweenInfo.new(1.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Position = UDim2.new(0, finalX, 0, 0) }
		)

		fastTween:Play()
		fastTween.Completed:Connect(function()
			slowTween:Play()
			slowTween.Completed:Connect(function()
				spinning = false
				if onDone then
					onDone()
				end
			end)
		end)
	end

	local wheelSpinRemote = ReplicatedStorage:WaitForChild("WheelSpin", 5)
	local wheelResultEvt = ReplicatedStorage:WaitForChild("WheelResult", 5)
	local wheelSpinsUpdateEvt = ReplicatedStorage:WaitForChild("WheelSpinsUpdate", 5)

	local function updateWheelHudBtn()
		local m = math.floor(wheelCountdownSecs / 60)
		local s = wheelCountdownSecs % 60
		if wheelSpins > 0 then
			wheelHudBtn.Text = string.format("🎡 Spin! (%d)", wheelSpins)
			wheelHudBtn.BackgroundColor3 = Color3.fromRGB(140, 70, 0)
			wheelHudBtn.TextColor3 = Color3.fromRGB(255, 230, 100)
		else
			wheelHudBtn.Text = string.format("🎡 %d:%02d", m, s)
			wheelHudBtn.BackgroundColor3 = Color3.fromRGB(50, 30, 10)
			wheelHudBtn.TextColor3 = Color3.fromRGB(160, 130, 70)
		end
	end

	if wheelSpinsUpdateEvt then
		wheelSpinsUpdateEvt.OnClientEvent:Connect(function(newSpins, secondsUntilNext)
			wheelSpins = newSpins
			wheelCountdownSecs = secondsUntilNext or 900
			updateWheelHudBtn()
			refreshWheelUI()
		end)
	end

	if wheelResultEvt then
		wheelResultEvt.OnClientEvent:Connect(function(rewardData)
			pendingSpin = false
			local idx = rewardData.outcomeIdx or 1
			local outcome = WHEEL_OUTCOMES[idx]

			playSpinAnimation(idx, function()
				-- Apply client-side rewards
				if rewardData.gems then
					gems += rewardData.gems
					updateHUD()
				end
				if rewardData.buffDuration then
					luckBuffEnd = tick() + rewardData.buffDuration
					updateHUD()
				end
				if rewardData.graveType and rewardData.graveCount then
					local gt = rewardData.graveType
					ownedGraves[gt] = (ownedGraves[gt] or 0) + rewardData.graveCount
					GravesDock.refresh()
				end
				if rewardData.boxUnits then
					for _, u in ipairs(rewardData.boxUnits) do
						addToInventory(u.unitType, u.oneIn)
					end
				end
				-- Gold is handled server-side via AddGold remote

				-- Show result text
				local label = outcome and outcome.label or "???"
				resultLbl.Text = "✨ You got: " .. label .. "!"

				-- Re-enable spin button
				refreshWheelUI()
				updateWheelHudBtn()
			end)
		end)
	end

	spinBtn.MouseButton1Click:Connect(function()
		if spinning or pendingSpin or wheelSpins <= 0 then
			return
		end
		if not wheelSpinRemote then
			return
		end
		wheelSpins -= 1
		pendingSpin = true
		refreshWheelUI()
		updateWheelHudBtn()
		wheelSpinRemote:FireServer()
	end)

	wheelHudBtn.MouseButton1Click:Connect(function()
		wheelPanel.Visible = not wheelPanel.Visible
		if wheelPanel.Visible then
			refreshWheelUI()
		end
	end)

	-- Local countdown ticker (client-side, synced from server grants)
	local lastCountdownTick = tick()
	RunService.Heartbeat:Connect(function()
		local now = tick()
		if now - lastCountdownTick >= 1 then
			lastCountdownTick = now
			if wheelSpins == 0 then
				wheelCountdownSecs = math.max(0, wheelCountdownSecs - 1)
			end
			updateWheelHudBtn()
			-- Update countdown label inside panel if visible
			if wheelPanel.Visible then
				local cd = wheelPanel:FindFirstChild("Countdown")
				if cd then
					local m = math.floor(wheelCountdownSecs / 60)
					local s = wheelCountdownSecs % 60
					cd.Text = string.format("Next spin in: %d:%02d", m, s)
				end
				refreshWheelUI()
			end
			-- Update luck buff label
			if tick() < luckBuffEnd or luckBuffEnd > 0 then
				updateHUD()
			end
		end
	end)

	updateWheelHudBtn()
	refreshWheelUI()
end -- do-block end

-- ============================================================
--  MAIN LOOP
-- ============================================================

updateHUD()
refreshToolbar()
GravesDock.refresh()
