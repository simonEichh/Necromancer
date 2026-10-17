-- Authoritative per-player data (gold, gems, inventory, graves, upgrades, ascension).
-- The server owns this; the client only receives read-only snapshots via DataSync.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(script.Parent.Remotes)
local Economy = require(ReplicatedStorage.Shared.Economy)
local Graves = require(ReplicatedStorage.Shared.Graves)
local Units = require(ReplicatedStorage.Shared.Units)
local Items = require(ReplicatedStorage.Shared.Items)

local INVENTORY_MAX = Economy.INVENTORY_MAX
local MAX_CURRENCY = 9e15 -- keep values exactly representable
local START_GOLD = 300

local PlayerData = {}
local profiles = {} -- [UserId] = profile

local function clampNumber(value, default, min)
	if type(value) ~= "number" or value ~= value then
		return default
	end
	return math.clamp(value, min, MAX_CURRENCY)
end

local function newOwnedGraves()
	local owned = {}
	for key in pairs(Graves) do
		owned[key] = 0
	end
	return owned
end

-- Builds a profile from saved data (or defaults), dropping anything invalid.
function PlayerData.create(player, saved)
	saved = type(saved) == "table" and saved or nil
	local profile = {
		player = player,
		gold = START_GOLD,
		gems = 0,
		luckPotions = 0, -- saved consumables from the wheel
		luckBuffEnd = 0, -- server time; remaining duration is saved, offline time does not consume it
		broker = { rot = 0, bought = { 0, 0, 0, 0 } }, -- the Soul Broker's stock this player used in rotation `rot` (Broker), saved
		rebirthCount = 0,
		gateCleared = false, -- session only: the gate (last wall of the run) fell, so the player may ascend
		materials = {}, -- [dust key from Economy.DUSTS] = amount of that upgrade dust
		catalysts = {}, -- [key from Economy.CATALYSTS] = how many the player owns (bought with gems)
		inventory = {}, -- [slot 1..INVENTORY_MAX] = { unitType, oneIn }
		ownedGraves = newOwnedGraves(),
		upgrades = { luckBoost = 0, coinBoost = 0 },
		realmUpgrades = {}, -- [Economy.REALM_UPGRADES key] = level; kept through a realm's ascensions, reset with the gold
		codex = {}, -- [unitType] = how many the player has ever pulled (the Codex; discovered = in this table)
		items = {}, -- [item key from Items.Defs] = true: outfit items the player owns
		equipped = {}, -- [slot from Items.SLOTS] = item key worn there (see Modules/Outfits)
		wallsBroken = 0, -- walls ever broken (the first objective: Drops.COLLECTOR_WALLS earns the Soul Wisp)
		collector = false, -- has the Soul Wisp (collects the loot drops, see Drops)
		wispLevel = 0, -- Soul Wisp speed level (Gem Shop, Economy.wispSpeed)
		remoteForge = false, -- bought the Remote Forge (Gem Shop): the Forge works anywhere
		fleetStrike = false, -- bought Malak's Fleet Strike finisher (Gem Shop / Codex)
		finalHorizon = false, -- bought Veyr's The Final Horizon finisher (Gem Shop / Codex; separate from the Fleet Strike)
		lastBroadside = false, -- bought Orvoss's The Last Broadside finisher (Gem Shop / Codex)
		commanderSlots = 1, -- commander thrones (Signatures / Sovereigns); the second is bought with gems (GemShop)
		settings = { master = 1, effects = 1, music = 1 }, -- the Settings panel: volumes 0..1 (saved)
		saved = saved, -- raw saved data, for modules that restore their own state
		syncQueued = false,
		dirty = false,
		loadFailed = false, -- set by Persistence; true means never save over the stored data
	}

	if saved then
		profile.gold = clampNumber(saved.gold, START_GOLD, 0)
		profile.gems = clampNumber(saved.gems, 0, 0)
		profile.luckPotions = math.floor(clampNumber(saved.luckPotions, 0, 0))
		profile.luckBuffEnd = workspace:GetServerTimeNow() + clampNumber(saved.luckBuffRemaining, 0, 0)
		if type(saved.broker) == "table" and type(saved.broker.bought) == "table" then
			local bought = {}
			for i = 1, 4 do
				bought[i] = math.floor(clampNumber(saved.broker.bought[i], 0, 0))
			end
			profile.broker = { rot = math.floor(clampNumber(saved.broker.rot, 0, 0)), bought = bought }
		end
		profile.rebirthCount = math.floor(clampNumber(saved.rebirthCount, 0, 0))
		profile.wallsBroken = math.floor(clampNumber(saved.wallsBroken, 0, 0))
		profile.collector = saved.collector == true
		profile.wispLevel = math.floor(clampNumber(saved.wispLevel, 0, 0))
		profile.remoteForge = saved.remoteForge == true
		profile.fleetStrike = saved.fleetStrike == true
		profile.finalHorizon = saved.finalHorizon == true -- (old saves: false)
		profile.lastBroadside = saved.lastBroadside == true
		profile.commanderSlots = math.clamp(math.floor(clampNumber(saved.commanderSlots, 1, 1)), 1, 2)
		if type(saved.settings) == "table" then
			for key in pairs(profile.settings) do
				local v = saved.settings[key]
				if type(v) == "number" and v == v then
					profile.settings[key] = math.clamp(v, 0, 1)
				end
			end
		end

		if type(saved.ownedGraves) == "table" then
			for key in pairs(profile.ownedGraves) do
				profile.ownedGraves[key] = math.floor(clampNumber(saved.ownedGraves[key], 0, 0))
			end
		end

		if type(saved.upgrades) == "table" then
			for key, max in pairs(Economy.UPGRADE_MAX) do
				profile.upgrades[key] = math.floor(clampNumber(saved.upgrades[key], 0, 0))
				profile.upgrades[key] = math.min(profile.upgrades[key], max)
			end
		end

		if type(saved.realmUpgrades) == "table" then
			for _, u in ipairs(Economy.REALM_UPGRADES) do
				local level = math.floor(clampNumber(saved.realmUpgrades[u.key], 0, 0))
				profile.realmUpgrades[u.key] = u.max and math.min(level, u.max) or level
			end
		end

		if type(saved.materials) == "table" then
			for _, dust in ipairs(Economy.DUSTS) do
				profile.materials[dust] = math.floor(clampNumber(saved.materials[dust], 0, 0))
			end
			-- old saves kept one material per rarity: pour them into that rarity's dust
			for _, rarity in ipairs(Economy.RARITIES_ASC) do
				local old = math.floor(clampNumber(saved.materials[rarity], 0, 0))
				if old > 0 then
					local dust = Economy.dustOf(rarity)
					profile.materials[dust] = math.min(profile.materials[dust] + old, MAX_CURRENCY)
				end
			end
		end

		if type(saved.catalysts) == "table" then
			for _, key in ipairs(Economy.CATALYSTS) do
				profile.catalysts[key] = math.floor(clampNumber(saved.catalysts[key], 0, 0))
			end
		end

		if type(saved.inventory) == "table" then
			for _, entry in ipairs(saved.inventory) do
				local slot = type(entry) == "table" and entry.slot
				if
					type(slot) == "number"
					and slot >= 1
					and slot <= INVENTORY_MAX
					and slot % 1 == 0
					and profile.inventory[slot] == nil
					and Units.Stats[entry.unitType]
				then
					profile.inventory[slot] = {
						unitType = entry.unitType,
						oneIn = clampNumber(entry.oneIn, Units.getBaseOneIn(entry.unitType), 1),
						level = math.floor(clampNumber(entry.level, 0, 0)) <= Economy.MAX_UNIT_LEVEL and math.floor(clampNumber(entry.level, 0, 0)) or Economy.MAX_UNIT_LEVEL,
						fails = math.floor(clampNumber(entry.fails, 0, 0)),
						locked = entry.locked == true or nil,
					}
				end
			end
		end
	end

	-- the Codex: saved counts, plus everything the player owns now (older saves had no codex)
	if type(saved) == "table" and type(saved.codex) == "table" then
		for unitType, n in pairs(saved.codex) do
			if Units.Stats[unitType] then
				profile.codex[unitType] = math.floor(clampNumber(n, 1, 1))
			end
		end
	end
	for _, unit in pairs(profile.inventory) do
		profile.codex[unit.unitType] = math.max(profile.codex[unit.unitType] or 0, 1)
	end
	if type(saved) == "table" and type(saved.placed) == "table" then
		for _, p in ipairs(saved.placed) do
			if type(p) == "table" and Units.Stats[p.unitType] then
				profile.codex[p.unitType] = math.max(profile.codex[p.unitType] or 0, 1)
			end
		end
	end

	-- outfit items: the start set plus whatever was saved; new players wear the start set
	for _, key in ipairs(Items.START) do
		profile.items[key] = true
	end
	if type(saved) == "table" and type(saved.items) == "table" then
		for _, key in ipairs(saved.items) do
			if Items.Defs[key] then
				profile.items[key] = true
			end
		end
	end
	if type(saved) == "table" and type(saved.equipped) == "table" then
		for _, slot in ipairs(Items.SLOTS) do
			local key = saved.equipped[slot]
			if profile.items[key] and Items.Defs[key].slot == slot then
				profile.equipped[slot] = key
			end
		end
	else
		for _, key in ipairs(Items.START) do
			profile.equipped[Items.Defs[key].slot] = key
		end
	end

	profiles[player.UserId] = profile
	return profile
end

-- Outfits: wear `key` in `slot` (nil takes the slot off). Returns true if it changed.
function PlayerData.equipItem(player, slot, key)
	local profile = profiles[player.UserId]
	if not profile or not Items.SLOT_INFO[slot] then
		return false
	end
	if key ~= nil and not (profile.items[key] and Items.Defs[key].slot == slot) then
		return false
	end
	-- An unlocked cosmetic can precede its model (the wheel's Spectral Crown).
	local models = ReplicatedStorage:FindFirstChild("ItemModels")
	if key ~= nil and not (models and models:FindFirstChild(key)) then return false end
	if profile.equipped[slot] == key then
		return false
	end
	profile.equipped[slot] = key
	PlayerData.changed(player)
	return true
end

-- Outfits: list of owned item keys (for snapshots and saving)
function PlayerData.ownedItems(profile)
	local list = {}
	for key in pairs(profile.items) do
		table.insert(list, key)
	end
	table.sort(list)
	return list
end

-- The Codex: one more of `unitType` pulled (Digging)
function PlayerData.recordPull(player, unitType)
	local profile = profiles[player.UserId]
	if profile and Units.Stats[unitType] then
		profile.codex[unitType] = (profile.codex[unitType] or 0) + 1
	end
end

function PlayerData.get(player)
	return profiles[player.UserId]
end

-- (DEV) every unit discovered in the Codex
function PlayerData.unlockCodex(player)
	local profile = profiles[player.UserId]
	if not profile then return end
	for unitType in pairs(Units.Stats) do
		profile.codex[unitType] = math.max(1, profile.codex[unitType] or 0)
	end
	PlayerData.changed(player)
end

function PlayerData.remove(player)
	profiles[player.UserId] = nil
end

-- ── Snapshot / sync ──────────────────────────────────────────
-- Set by Army: function(player) -> the units standing on the graves as a list of { slot, unitType, level, fails }
PlayerData.placedProvider = nil

function PlayerData.snapshot(profile)
	local inventory = {}
	for slot = 1, INVENTORY_MAX do
		local unit = profile.inventory[slot]
		if unit then
			table.insert(inventory, { slot = slot, unitType = unit.unitType, oneIn = unit.oneIn, level = unit.level or 0, fails = unit.fails or 0, locked = unit.locked == true })
		end
	end
	local owned = {}
	for key, count in pairs(profile.ownedGraves) do
		owned[key] = count
	end
	local materials = {}
	for _, dust in ipairs(Economy.DUSTS) do
		materials[dust] = profile.materials[dust] or 0
	end
	local catalysts = {}
	for _, key in ipairs(Economy.CATALYSTS) do
		catalysts[key] = profile.catalysts[key] or 0
	end
	return {
		gold = profile.gold,
		gems = profile.gems,
		luckPotions = profile.luckPotions,
		luckBuffEnd = profile.luckBuffEnd,
		rebirthCount = profile.rebirthCount,
		gateCleared = profile.gateCleared,
		catalysts = catalysts,
		goldMultiplier = Economy.goldMultiplier(profile.rebirthCount),
		ownedGraves = owned,
		luckBoostLevel = profile.upgrades.luckBoost,
		coinBoostLevel = profile.upgrades.coinBoost,
		realmUpgrades = table.clone(profile.realmUpgrades),
		codex = table.clone(profile.codex),
		items = PlayerData.ownedItems(profile),
		equipped = table.clone(profile.equipped),
		inventory = inventory,
		materials = materials,
		wallsBroken = profile.wallsBroken,
		collector = profile.collector,
		wispLevel = profile.wispLevel,
		remoteForge = profile.remoteForge,
		fleetStrike = profile.fleetStrike,
		finalHorizon = profile.finalHorizon,
		lastBroadside = profile.lastBroadside,
		commanderSlots = profile.commanderSlots,
		broker = { rot = profile.broker.rot, bought = table.clone(profile.broker.bought) },
		settings = profile.settings,
		placed = PlayerData.placedProvider and PlayerData.placedProvider(profile.player) or {},
	}
end

-- functions(player, profile) called after every sync, for server modules that mirror player data into the world
-- (PlotLook: the realm upgrade levels on the Soul Altar); they are registered by the modules themselves (no cycles)
PlayerData.onSync = {}

function PlayerData.sync(player)
	local profile = profiles[player.UserId]
	if profile and player.Parent then
		Remotes.DataSync:FireClient(player, PlayerData.snapshot(profile))
		for _, fn in ipairs(PlayerData.onSync) do
			task.spawn(fn, player, profile)
		end
	end
end

-- Marks the profile changed and sends one coalesced snapshot at the end of the frame.
function PlayerData.changed(player)
	local profile = profiles[player.UserId]
	if not profile then
		return
	end
	profile.dirty = true
	if profile.syncQueued then
		return
	end
	profile.syncQueued = true
	task.defer(function()
		profile.syncQueued = false
		if profiles[player.UserId] == profile then
			PlayerData.sync(player)
		end
	end)
end

-- ── Currency ─────────────────────────────────────────────────
function PlayerData.addGold(player, amount)
	local profile = profiles[player.UserId]
	if not profile or type(amount) ~= "number" or amount ~= amount or amount <= 0 then
		return false
	end
	profile.gold = math.min(profile.gold + amount, MAX_CURRENCY)
	PlayerData.changed(player)
	return true
end

function PlayerData.spendGold(player, amount)
	local profile = profiles[player.UserId]
	if not profile or type(amount) ~= "number" or amount ~= amount or amount < 0 then
		return false
	end
	if profile.gold < amount then
		return false
	end
	profile.gold -= amount
	PlayerData.changed(player)
	return true
end

function PlayerData.addGems(player, amount)
	local profile = profiles[player.UserId]
	if not profile or type(amount) ~= "number" or amount ~= amount or amount <= 0 then
		return false
	end
	profile.gems = math.min(profile.gems + amount, MAX_CURRENCY)
	PlayerData.changed(player)
	return true
end

-- Takes gems; returns false (and takes nothing) when the player does not have that many.
function PlayerData.spendGems(player, amount)
	local profile = profiles[player.UserId]
	if not profile or type(amount) ~= "number" or amount ~= amount or amount <= 0 or profile.gems < amount then
		return false
	end
	profile.gems -= amount
	PlayerData.changed(player)
	return true
end

-- ============================================================
-- Wheel consumables and cosmetic unlocks
-- ============================================================
function PlayerData.addLuckPotions(player, amount)
	local profile = profiles[player.UserId]
	if not profile or type(amount) ~= "number" or amount ~= amount or amount <= 0 then return false end
	profile.luckPotions = math.min(profile.luckPotions + math.floor(amount), MAX_CURRENCY)
	PlayerData.changed(player)
	return true
end

function PlayerData.useLuckPotion(player, duration)
	local profile = profiles[player.UserId]
	if not profile or profile.luckPotions < 1 then return false end
	profile.luckPotions -= 1
	profile.luckBuffEnd = math.max(workspace:GetServerTimeNow(), profile.luckBuffEnd) + duration
	PlayerData.changed(player)
	return true
end

function PlayerData.grantItem(player, key)
	local profile = profiles[player.UserId]
	if not profile or not Items.Defs[key] or profile.items[key] then return false end
	profile.items[key] = true
	PlayerData.changed(player)
	return true
end

-- ── Catalysts (Forge) ────────────────────────────────────────
function PlayerData.addCatalyst(player, key, amount)
	local profile = profiles[player.UserId]
	if not profile or not Economy.CATALYST_INFO[key] or type(amount) ~= "number" or amount ~= amount or amount <= 0 then
		return false
	end
	profile.catalysts[key] = math.min((profile.catalysts[key] or 0) + math.floor(amount), MAX_CURRENCY)
	PlayerData.changed(player)
	return true
end

-- Uses up one catalyst; returns false when the player has none.
function PlayerData.useCatalyst(player, key)
	local profile = profiles[player.UserId]
	if not profile or (profile.catalysts[key] or 0) < 1 then
		return false
	end
	profile.catalysts[key] -= 1
	PlayerData.changed(player)
	return true
end

-- ── Inventory ────────────────────────────────────────────────
local function firstFreeSlot(profile)
	for slot = 1, INVENTORY_MAX do
		if profile.inventory[slot] == nil then
			return slot
		end
	end
	return nil
end

function PlayerData.hasFreeSlot(player)
	local profile = profiles[player.UserId]
	return profile ~= nil and firstFreeSlot(profile) ~= nil
end

-- Adds a unit to the first free slot. Returns the slot, or nil if the inventory is full.
function PlayerData.addUnit(player, unitType, oneIn, level, fails, locked)
	local profile = profiles[player.UserId]
	if not profile or not Units.Stats[unitType] then
		return nil
	end
	local slot = firstFreeSlot(profile)
	if not slot then
		return nil
	end
	profile.inventory[slot] = { unitType = unitType, oneIn = oneIn or Units.getBaseOneIn(unitType), level = level or 0, fails = fails or 0, locked = locked == true or nil }
	PlayerData.changed(player)
	return slot
end

function PlayerData.hasFreeSlot(player)
	local profile = profiles[player.UserId]
	return profile ~= nil and firstFreeSlot(profile) ~= nil
end

-- Removes and returns the unit in a slot (nil if the slot is invalid or empty).
function PlayerData.takeUnit(player, slot)
	local profile = profiles[player.UserId]
	if not profile or type(slot) ~= "number" or slot % 1 ~= 0 or slot < 1 or slot > INVENTORY_MAX then
		return nil
	end
	local unit = profile.inventory[slot]
	if not unit then
		return nil
	end
	profile.inventory[slot] = nil
	PlayerData.changed(player)
	return unit
end

function PlayerData.getUnit(player, slot)
	local profile = profiles[player.UserId]
	if not profile or type(slot) ~= "number" or slot % 1 ~= 0 or slot < 1 or slot > INVENTORY_MAX then
		return nil
	end
	return profile.inventory[slot]
end

-- Locks or unlocks the unit in a slot (a locked unit can never be sold or dismantled). Returns the new state, or nil.
function PlayerData.toggleLock(player, slot)
	local unit = PlayerData.getUnit(player, slot)
	if not unit then
		return nil
	end
	unit.locked = (not unit.locked) or nil
	PlayerData.changed(player)
	return unit.locked == true
end

function PlayerData.swapSlots(player, a, b)
	local profile = profiles[player.UserId]
	if not profile then
		return false
	end
	for _, slot in ipairs({ a, b }) do
		if type(slot) ~= "number" or slot % 1 ~= 0 or slot < 1 or slot > INVENTORY_MAX then
			return false
		end
	end
	profile.inventory[a], profile.inventory[b] = profile.inventory[b], profile.inventory[a]
	PlayerData.changed(player)
	return true
end

-- Replaces the whole inventory with a compact list of { unitType, oneIn }.
function PlayerData.setInventoryList(player, list)
	local profile = profiles[player.UserId]
	if not profile then
		return
	end
	profile.inventory = {}
	for i, unit in ipairs(list) do
		if i > INVENTORY_MAX then
			break
		end
		profile.inventory[i] = { unitType = unit.unitType, oneIn = unit.oneIn, level = unit.level or 0, fails = unit.fails or 0, locked = unit.locked }
	end
	PlayerData.changed(player)
end

function PlayerData.inventoryList(player)
	local profile = profiles[player.UserId]
	local list = {}
	if profile then
		for slot = 1, INVENTORY_MAX do
			if profile.inventory[slot] then
				table.insert(list, profile.inventory[slot])
			end
		end
	end
	return list
end

-- ── Materials (unit upgrades) ────────────────────────────────
function PlayerData.addMaterial(player, dust, amount)
	local profile = profiles[player.UserId]
	if not profile or Economy.DUST_NAMES[dust] == nil or type(amount) ~= "number" or amount ~= amount or amount <= 0 then
		return false
	end
	profile.materials[dust] = math.min((profile.materials[dust] or 0) + math.floor(amount), MAX_CURRENCY)
	PlayerData.changed(player)
	return true
end

-- Takes materials; returns false (and takes nothing) when the player does not have that many.
function PlayerData.spendMaterial(player, dust, amount)
	local profile = profiles[player.UserId]
	if not profile or Economy.DUST_NAMES[dust] == nil or type(amount) ~= "number" or amount < 0 then
		return false
	end
	if (profile.materials[dust] or 0) < amount then
		return false
	end
	profile.materials[dust] -= amount
	PlayerData.changed(player)
	return true
end

-- ── Graves / upgrades / ascension ────────────────────────────
function PlayerData.addGraves(player, graveType, count)
	local profile = profiles[player.UserId]
	if not profile or profile.ownedGraves[graveType] == nil or count <= 0 then
		return false
	end
	profile.ownedGraves[graveType] += count
	PlayerData.changed(player)
	return true
end

-- Uses up one owned grave. Returns false if the player has none.
function PlayerData.consumeGrave(player, graveType)
	local profile = profiles[player.UserId]
	if not profile or (profile.ownedGraves[graveType] or 0) <= 0 then
		return false
	end
	profile.ownedGraves[graveType] -= 1
	PlayerData.changed(player)
	return true
end

function PlayerData.refundGrave(player, graveType)
	PlayerData.addGraves(player, graveType, 1)
end

-- Raises an upgrade by one level. Caller has already checked cost and max.
function PlayerData.incrementUpgrade(player, upgradeType)
	local profile = profiles[player.UserId]
	if not profile or profile.upgrades[upgradeType] == nil then
		return
	end
	profile.upgrades[upgradeType] += 1
	PlayerData.changed(player)
end

-- Resets gold and bumps the ascension count once the gate is broken.
-- Returns the new ascension count, or nil if the gate has not fallen.
function PlayerData.ascend(player)
	local profile = profiles[player.UserId]
	if not profile then
		return nil
	end
	if not profile.gateCleared then
		return nil -- ascending needs the gate (the last wall of the run) to be broken
	end
	profile.gateCleared = false
	profile.rebirthCount += 1
	-- gold is kept through the ascensions of a realm; a new realm starts from zero
	if profile.rebirthCount % Economy.ASCENSIONS_PER_REALM == 0 then
		profile.gold = 0
		profile.realmUpgrades = {} -- the realm upgrades go with it
	end
	PlayerData.changed(player)
	return profile.rebirthCount
end

-- Called by Walls when the gate (last wall of a run) breaks.
function PlayerData.setGateCleared(player, cleared)
	local profile = profiles[player.UserId]
	if profile and profile.gateCleared ~= cleared then
		profile.gateCleared = cleared
		PlayerData.changed(player)
	end
end

-- the Settings panel: the client sends its volumes when a slider is let go; only known keys, numbers 0..1, saved
-- with the profile (no DataSync back: the client already shows them)
Remotes.SaveSettings.OnServerEvent:Connect(function(player, settings)
	local profile = PlayerData.get(player)
	if not profile or type(settings) ~= "table" then
		return
	end
	for key in pairs(profile.settings) do
		local v = settings[key]
		if type(v) == "number" and v == v then
			profile.settings[key] = math.clamp(v, 0, 1)
		end
	end
	profile.dirty = true
end)

return PlayerData
