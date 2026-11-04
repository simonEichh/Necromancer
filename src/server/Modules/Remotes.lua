-- Creates every RemoteEvent/RemoteFunction at server startup.
-- (Remotes must all exist before clients WaitForChild them.)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EVENTS = {
	-- client -> server requests
	"BuyGraveRequest",
	"BuyUpgrade",
	"BuyRealmUpgrade", -- (key) a realm upgrade level for gold (Upgrades)
	"ClaimQuest",
	"DevClearUnits", -- Studio-only dev tools (see DevTools / client DevPanel)
	"DevGiveGems",
	"DevGiveWheelSpins", -- Studio: add ten wheel spin charges
	"DevGiveGold",
	"DevFastSpecials",
	"DevFleetStrike", -- (on) Studio: start / stop a Fleet Strike finisher on your plot (FleetStrike.lua previews it)
	"ArrivalStarted", -- client -> server ({ G, dir, feet }): the puller's Sovereign arrival cinematic started (Digging checks it)
	"ArrivalShow", -- server -> other clients ({ owner, unitType, rarity, graveType, G, dir, feet, startAt }): play it in their world
	"RarePull", -- server -> all clients ({ userId, name, unitType, oneIn }): someone pulled a Signature / Sovereign (client RarePullBanner)
	"RecallUnit", -- (slotIndex) the Army screen takes a unit off a grave / throne back into the inventory
	"DevUnlockCodex", -- Studio: every unit counts as discovered in your Codex (saved)
	"DevBreakAll", -- Studio: break every wall including the gate (loot and all), so you can ascend
	"DevGateLow", -- Studio: break walls up to the gate and set it just above 20% HP (to test the Fleet Strike trigger)
	"DevFinalHorizon", -- Studio: Veyr's finisher preview (the army holds, then flees; no real gate break)
	"FinalHorizon", -- server -> all clients: Veyr's gate finisher starts ({ owner, startAt, unit, gate, unitCF })
	"DevLastBroadside", -- Studio: Orvoss's finisher preview (the army holds; no real gate break)
	"LastBroadside", -- server -> all clients: Orvoss's gate finisher starts ({ owner, startAt, unit, gate, unitCF })
	"DevLastCross", -- Studio: Hush's finisher preview (the army holds; no real gate break)
	"LastCross", -- server -> all clients: Hush's gate finisher starts ({ owner, startAt, unit, gate, unitCF })
	"DevToughWall", -- Studio: the wall being fought gets a huge HP pool (to watch attacks, marks and specials on one wall)
	"SaveSettings", -- ({ master, effects, music } volumes 0..1): the Settings panel (PlayerData)
	"FleetStrike", -- server -> all clients ({ owner, startAt, malak, gate }): Malak's finisher starts (client FleetStrike)
	"DismantleAll",
	"DismantleAllResult",
	"DevSpawnUnit",
	"DigGrave",
	"PlaceAtGrave",
	"PlaceBest",
	"PlayerAscend",
	"RequestData",
	"SellUnit",
	"SellAll", -- (maxRank, keepUpgraded): sell every unlocked inventory unit of that rarity rank or lower
	"ToggleLock", -- (inventory slot): a locked unit can never be sold or dismantled
	"SwapInventory",
	"UpgradeUnit", -- (kind "inv" | "grave", index, useFortune, useWarding): the Forge, see UnitUpgrades
	"DismantleUnit", -- (inventory slot)
	"BuyDust", -- (dust key, quantity): the Forge's Buy Dust tab, see UnitUpgrades
	"BuyCatalyst", -- (catalyst key, quantity): gems for Forge catalysts, see UnitUpgrades
	"OpenBroker", -- the Soul Broker stall's prompt (ShopNpcs) -> client GemShopPanel (Deals tab)
	"BuyBrokerDeal", -- (portrait, rotation): the Soul Broker's portrait deals, see Broker
	"BuyGemItem", -- (item "RemoteForge" | "WispSpeed"): the Gem Shop, see GemShop
	"BuyOutfit", -- (what "Set" | slot, day): the Outfit of the Day, see OutfitOfTheDay
	"EquipItem", -- (slot, item key | nil): wear or take off an outfit item, see Outfits
	"WheelSpin",
	"UseLuckPotion", -- use one saved potion for five minutes of 2x luck (time stacks)
	-- server -> client
	"AddGold", -- sell banner only; gold itself arrives via DataSync
	"OpenForge", -- the Forge stall's prompt was used: open the Forge panel
	"BuyGraveResult",
	"WallHit", -- (position, forward, damage, isGhost): a unit hit the wall; clients draw the hit flash (HitEffects)
	"DataSync", -- full snapshot of the player's authoritative data
	"DigRejected",
	"Notice", -- short message to show the player
	"UpgradeResult", -- (success, unitType, newLevel, chance) after an UpgradeUnit
	"OpenGrave",
	"QuestUpdate",
	"RollResult",
	"SelectGrave",
	"ShopStockUpdate",
	"DustStockUpdate", -- (stock {dust = count}, seconds until the restock): the Forge's Buy Dust tab
	"WallBreak",
	"WheelResult",
	"WheelRejected", -- reason: no spin was consumed
	"OpenWheel", -- the plaza wheel's prompt opens its in-world view
	"WheelSpinsUpdate",
}

local Remotes = {}

for _, name in ipairs(EVENTS) do
	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = ReplicatedStorage
	Remotes[name] = remote
end

local getWallPos = Instance.new("RemoteFunction")
getWallPos.Name = "GetWallPos"
getWallPos.Parent = ReplicatedStorage
Remotes.GetWallPos = getWallPos

return Remotes
