-- Shared client game state. Modules read fields on this table (e.g. State.gold) instead of
-- sharing locals. Most of it is a read-only mirror of the server's data, written only by Sync.
local Economy = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Economy"))

local State = {
	gold = 0,
	gems = 0,
	rebirthCount = 0,
	gateCleared = false, -- the gate fell: ascending is possible
	goldMultiplier = 1.0,

	-- Inventory: up to INVENTORY_MAX units; first 10 are shown in the toolbar
	inventory = {},
	selectedSlot = 1,

	-- Owned (bought, unopened) graves
	ownedGraves = {
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
	},

	-- Upgrade levels (synced from server via UpgradeGranted)
	luckBoostLevel = 0,
	coinBoostLevel = 0,

	-- Wheel
	wheelSpins = 0,
	wheelCountdownSecs = 900, -- seconds until next spin grant
	luckBuffEnd = 0, -- tick() timestamp when 2x luck buff expires

	-- Constants
	INVENTORY_MAX = Economy.INVENTORY_MAX,
	UPGRADE_MAX = Economy.UPGRADE_MAX,
}

return State
