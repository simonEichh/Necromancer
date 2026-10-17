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
require(Modules.VerdictFx) -- the Sigilwright's special: the sentence of rune circles, burning words, hypersonic bolts
require(Modules.HitEffects)
require(Modules.WallStages) -- damage stages of the modelled walls (cracks, collapse)
require(Modules.TitanAnimator) -- idle animation of the realm titans behind the outer wall
require(Modules.HandsAnimator) -- the realm keeper's hands, rifts and eyes behind every claimed lane
require(Modules.PortalFx) -- the portal behind the gate (door bursts open, rune progress, rejection)
require(Modules.CodexPanel) -- the Codex: every unit, read in the necromancer's grimoire (tile + C)
require(Modules.OutfitsPanel) -- the wardrobe: outfit items (tile + O)
require(Modules.ArmyPanel) -- the Army screen: placing the army, families, commanders (tile + R)
require(Modules.CapeSway) -- the equipped cape sways with walking speed
AscendPanel = require(Modules.AscendPanel)
require(Modules.ForgePanel)
require(Modules.GemShopPanel) -- the Gem Shop (Shop tile, right) and the Remote Forge tile (left)
require(Modules.BrokerPortraits) -- the Soul Broker stall's portraits painted with this player's deals
require(Modules.BrokerWares) -- the catalyst jars on the Soul Broker's counter: hover outline, click to buy
require(Modules.BrokerKeeper) -- the Soul Broker walks round his stall; the stall's prompt calls him to the counter
require(Modules.SettingsPanel) -- the Settings tile (top right) and panel: sound volumes, saved
require(Modules.WorldFx) -- spinning world decoration (the Forge magic circle)
require(Modules.ReliquaryShowcase) -- the plaza's showcase pedestal: a big chase unit turning, its real odds on the plate
require(Modules.AltarFx) -- the Soul Altar's braziers burn as high as the realm upgrade levels
require(Modules.LevelAuras) -- necromantic auras on units of level 3 / 6 / 9 (none from 10: the shadow form)
require(Modules.Pickups) -- loot drops on the lane, the Soul Wisp, the first objective
require(Modules.FingerBeam) -- the finger-beam attack (Hush): magic circle at the fingertip, beam to the wall
require(Modules.OrbitalStrike) -- the orbital tag (Malak): red targeting laser from the sky, shell, impact
require(Modules.RequisitionFx) -- Malak's special: the supply pod, the drone swarm
require(Modules.FleetStrike) -- Malak's gate finisher: the server starts it for everyone (remote FleetStrike)
require(Modules.VeyrShot) -- Veyr's basic attack: focusing sights, the round, the puncture, the weak point (his trait)
require(Modules.VeyrSpecial) -- Veyr's special, The Long Goodbye: his shards open six sigils down the lane
require(Modules.VeyrFinisher) -- Veyr's gate finisher, The Final Horizon: the server starts it for everyone (remote FinalHorizon)
require(Modules.DoubleReport) -- Orvoss's basic attack: the ghost cannon, the two shots and the impact (AdmiralTimeline)
require(Modules.RarePullBanner) -- the banner everyone else sees when someone pulls a Signature / Sovereign
require(Modules.SpecialFx) -- special attacks: charge meter over the unit, the Rift Chains
require(Modules.KnellFx) -- Knell's soul tolls and the colossal spectral bell
require(Modules.UpgradesPanel) -- realm upgrades + permanent luck / coin (the Upgrades tile, the upgrade stall)
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
