-- ============================================================
--  NECRO BUDDIES — Client bootstrap
--  Builds the UI by wiring the client modules together (see src/client/Modules).
--  Module load order matters: UI created later is drawn on top of earlier UI.
-- ============================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Modules = script.Modules

local State = require(Modules.State)
local GameData = require(Modules.GameData)
local Format = require(Modules.Format)
local screenGui = require(Modules.Gui)

local GravesDock = require(Modules.GravesDock)
local InventoryPanel = require(Modules.InventoryPanel)
local ShopPanel = require(Modules.ShopPanel)
local QuestsPanel = require(Modules.QuestsPanel)
local HUD = require(Modules.HUD)
local Sync = require(Modules.Sync)

-- Forward declarations (panels that are built after the HUD, which toggles them)
local AscendPanel
local WheelPanel

-- ============================================================
--  TOOLBAR / INVENTORY
-- ============================================================
local Toolbar = require(Modules.Toolbar)

InventoryPanel.init(screenGui, {
	inventory = State.inventory,
	UNIT_INFO = GameData.UNIT_INFO,
	RARITY_COLORS = GameData.RARITY_COLORS,
	UNIT_DPS = GameData.UNIT_DPS,
	UNIT_ONE_IN = GameData.UNIT_ONE_IN,
	INVENTORY_MAX = State.INVENTORY_MAX,
	tooltip = Toolbar.tooltip.frame,
	ttName = Toolbar.tooltip.name,
	ttRarity = Toolbar.tooltip.rarity,
	ttDps = Toolbar.tooltip.dps,
	ttOneIn = Toolbar.tooltip.oneIn,
	getSelectedSlot = function()
		return State.selectedSlot
	end,
	refreshToolbar = Toolbar.refresh,
	updateCarriedUnit = Toolbar.updateCarried,
	swapSlots = function(a, b)
		ReplicatedStorage:WaitForChild("SwapInventory"):FireServer(a, b)
	end,
})

-- Place Best button, place at grave, recall
require(Modules.Placement)

-- ============================================================
--  GRAVES / SHOP / QUESTS / HUD
-- ============================================================
local GraveRolling = require(Modules.GraveRolling)

GravesDock.init(screenGui, State.ownedGraves, GameData.GRAVE_DATA, GraveRolling.openGrave)

ShopPanel.init(screenGui, {
	GRAVE_DATA = GameData.GRAVE_DATA,
	ownedGraves = State.ownedGraves,
	getGold = function()
		return State.gold
	end,
	spendGold = function(n)
		State.gold = State.gold - n
		HUD.update()
	end,
	getRebirthCount = function()
		return State.rebirthCount
	end,
	fmtGold = Format.fmtGold,
	refreshDock = function()
		GravesDock.refresh()
	end,
})

QuestsPanel.init(screenGui, {
	claimQuestRemote = ReplicatedStorage:WaitForChild("ClaimQuest", 5),
	onGemsAdded = function() end, -- gems are granted by the server and arrive via Sync
})

local getWallPosFunc = ReplicatedStorage:WaitForChild("GetWallPos", 5)

HUD.init(screenGui, {
	getGold = function()
		return State.gold
	end,
	getGems = function()
		return State.gems
	end,
	getSpins = function()
		return State.wheelSpins
	end,
	getCountdown = function()
		return State.wheelCountdownSecs
	end,
	getLuckBuffEnd = function()
		return State.luckBuffEnd
	end,
	fmtNumber = Format.fmt,
	onShops = function()
		local char = player.Character
		if not char then
			return
		end
		local hrp = char:FindFirstChild("HumanoidRootPart")
		if not hrp then
			return
		end
		-- the plaza spawn point is stored on the workspace by tools/studio/build_coliseum.lua
		local spawnPoint = workspace:GetAttribute("HubSpawn") or Vector3.new(0, 3, 24)
		hrp.CFrame = CFrame.lookAt(spawnPoint, spawnPoint + Vector3.new(0, 0, -1))
	end,
	onWall = function()
		local char = player.Character
		if not char then
			return
		end
		local hrp = char:FindFirstChild("HumanoidRootPart")
		if not hrp then
			return
		end
		-- the server returns a CFrame in front of the wall, facing it
		local standCFrame = getWallPosFunc and getWallPosFunc:InvokeServer()
		if standCFrame then
			hrp.CFrame = standCFrame + Vector3.new(0, 3, 0)
		end
	end,
	onAscend = function()
		if AscendPanel then
			AscendPanel.toggle()
		end
	end,
	onInventory = function()
		InventoryPanel.toggle()
	end,
	onSpin = function()
		if WheelPanel then
			WheelPanel.toggle()
		end
	end,
	onQuests = function()
		QuestsPanel.show()
	end,
	onFriends = function()
		local ok, err = pcall(function()
			game:GetService("SocialService"):PromptGameInvite(player)
		end)
		if not ok then
			warn("Friends invite failed:", err)
		end
	end,
})

-- Shopkeeper: Buy
local openGraveEvt = ReplicatedStorage:WaitForChild("OpenGrave", 5)
if openGraveEvt then
	openGraveEvt.OnClientEvent:Connect(function()
		ShopPanel.show()
	end)
end

-- ============================================================
--  EFFECTS + PANELS (built after the HUD)
-- ============================================================
require(Modules.Effects)
require(Modules.UnitAnimator)
require(Modules.SpellEffects)
require(Modules.HitEffects)
AscendPanel = require(Modules.AscendPanel)
require(Modules.SellPanel)
require(Modules.ForgePanel)
require(Modules.UpgradePanel)
WheelPanel = require(Modules.WheelPanel)
require(Modules.DevPanel) -- Studio only, drawn on top

-- ============================================================
--  SERVER DATA
-- ============================================================
-- Gold, gems, inventory, graves and upgrades are owned by the server; Sync mirrors them into State.
HUD.update()
Toolbar.refresh()
GravesDock.refresh()
Sync.start()
