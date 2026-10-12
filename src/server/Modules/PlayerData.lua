-- Authoritative per-player data (gold, gems, inventory, graves, upgrades, ascension).
-- The server owns this; the client only receives read-only snapshots via DataSync.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(script.Parent.Remotes)
local Economy = require(ReplicatedStorage.Shared.Economy)
local Graves = require(ReplicatedStorage.Shared.Graves)
local Units = require(ReplicatedStorage.Shared.Units)

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
		rebirthCount = 0,
		gateCleared = false, -- session only: the gate (last wall of the run) fell, so the player may ascend
		materials = {}, -- [rarity] = amount of that rarity's upgrade material
		inventory = {}, -- [slot 1..INVENTORY_MAX] = { unitType, oneIn }
		ownedGraves = newOwnedGraves(),
		upgrades = { luckBoost = 0, coinBoost = 0 },
		saved = saved, -- raw saved data, for modules that restore their own state
		syncQueued = false,
		dirty = false,
		loadFailed = false, -- set by Persistence; true means never save over the stored data
	}

	if saved then
		profile.gold = clampNumber(saved.gold, START_GOLD, 0)
		profile.gems = clampNumber(saved.gems, 0, 0)
		profile.rebirthCount = math.floor(clampNumber(saved.rebirthCount, 0, 0))

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

		if type(saved.materials) == "table" then
			for _, rarity in ipairs(Economy.RARITIES_ASC) do
				profile.materials[rarity] = math.floor(clampNumber(saved.materials[rarity], 0, 0))
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
					}
				end
			end
		end
	end

	profiles[player.UserId] = profile
	return profile
end

function PlayerData.get(player)
	return profiles[player.UserId]
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
			table.insert(inventory, { slot = slot, unitType = unit.unitType, oneIn = unit.oneIn, level = unit.level or 0, fails = unit.fails or 0 })
		end
	end
	local owned = {}
	for key, count in pairs(profile.ownedGraves) do
		owned[key] = count
	end
	local materials = {}
	for _, rarity in ipairs(Economy.RARITIES_ASC) do
		materials[rarity] = profile.materials[rarity] or 0
	end
	return {
		gold = profile.gold,
		gems = profile.gems,
		rebirthCount = profile.rebirthCount,
		gateCleared = profile.gateCleared,
		goldMultiplier = Economy.goldMultiplier(profile.rebirthCount),
		ownedGraves = owned,
		luckBoostLevel = profile.upgrades.luckBoost,
		coinBoostLevel = profile.upgrades.coinBoost,
		inventory = inventory,
		materials = materials,
		placed = PlayerData.placedProvider and PlayerData.placedProvider(profile.player) or {},
	}
end

function PlayerData.sync(player)
	local profile = profiles[player.UserId]
	if profile and player.Parent then
		Remotes.DataSync:FireClient(player, PlayerData.snapshot(profile))
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
function PlayerData.addUnit(player, unitType, oneIn, level, fails)
	local profile = profiles[player.UserId]
	if not profile or not Units.Stats[unitType] then
		return nil
	end
	local slot = firstFreeSlot(profile)
	if not slot then
		return nil
	end
	profile.inventory[slot] = { unitType = unitType, oneIn = oneIn or Units.getBaseOneIn(unitType), level = level or 0, fails = fails or 0 }
	PlayerData.changed(player)
	return slot
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
		profile.inventory[i] = { unitType = unit.unitType, oneIn = unit.oneIn, level = unit.level or 0, fails = unit.fails or 0 }
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
function PlayerData.addMaterial(player, rarity, amount)
	local profile = profiles[player.UserId]
	if not profile or Economy.MATERIAL_NAMES[rarity] == nil or type(amount) ~= "number" or amount ~= amount or amount <= 0 then
		return false
	end
	profile.materials[rarity] = math.min((profile.materials[rarity] or 0) + math.floor(amount), MAX_CURRENCY)
	PlayerData.changed(player)
	return true
end

-- Takes materials; returns false (and takes nothing) when the player does not have that many.
function PlayerData.spendMaterial(player, rarity, amount)
	local profile = profiles[player.UserId]
	if not profile or Economy.MATERIAL_NAMES[rarity] == nil or type(amount) ~= "number" or amount < 0 then
		return false
	end
	if (profile.materials[rarity] or 0) < amount then
		return false
	end
	profile.materials[rarity] -= amount
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
	profile.gold = 0
	profile.rebirthCount += 1
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

return PlayerData
