-- Rarity/unit rolling with luck and pity.
local Rarities = require(game:GetService("ReplicatedStorage").Shared.Rarities)
local Units = require(game:GetService("ReplicatedStorage").Shared.Units)

local RARITY_RANK = Rarities.Rank
local RARITY_UNITS = Units.Pools

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

-- Roll the rarity from the grave's own odds table. `grave` = { odds, pityRarity, luckFactor }: luckFactor (the luck
-- upgrade, +10% per level, times the wheel's 2x buff) multiplies the weights of Rare and better, so luck makes good
-- units more likely without ever making a grave give rarities outside its table.
local LUCK_FROM_RANK = 3
local PITY_ROLLS = 60

local function rollRarity(grave, player, graveType)
	local pity = getPity(player, graveType)
	if pity >= PITY_ROLLS then
		resetPity(player, graveType)
		return grave.pityRarity
	end

	local factor = grave.luckFactor or 1
	local entries, total = {}, 0
	for rarity, weight in pairs(grave.odds) do
		local w = weight * ((RARITY_RANK[rarity] >= LUCK_FROM_RANK) and factor or 1)
		table.insert(entries, { rarity = rarity, weight = w })
		total += w
	end
	local roll = math.random() * total
	local picked = entries[#entries].rarity
	for _, e in ipairs(entries) do
		roll -= e.weight
		if roll <= 0 then
			picked = e.rarity
			break
		end
	end

	if RARITY_RANK[picked] >= RARITY_RANK[grave.pityRarity] then
		resetPity(player, graveType)
	else
		incrementPity(player, graveType)
	end
	return picked
end

-- Pick a weighted random unit from a rarity pool. An entry with `graves` (a set of grave keys) only rolls from those
-- graves (Malak: Celestial only); without a graveType (the wheel) such entries never roll.
local function rollUnit(rarity, graveType)
	local pool = RARITY_UNITS[rarity]
	if not pool or #pool == 0 then
		return "Skelly"
	end
	local function allowed(entry)
		return not entry.graves or (graveType ~= nil and entry.graves[graveType] == true)
	end
	local totalWeight = 0
	for _, entry in ipairs(pool) do
		if allowed(entry) then
			totalWeight += entry.weight
		end
	end
	local roll = math.random() * totalWeight -- (weights may be fractions: Signature units have very low ones)
	local cumulative = 0
	for _, entry in ipairs(pool) do
		if allowed(entry) then
			cumulative += entry.weight
			if roll < cumulative then
				return entry.unit
			end
		end
	end
	return pool[1].unit
end

local function remove(player)
	playerPity[tostring(player.UserId)] = nil
end

-- Pity counters in a form that can be stored, and restored from stored data.
local function exportPity(player)
	local copy = {}
	for graveType, count in pairs(playerPity[tostring(player.UserId)] or {}) do
		copy[graveType] = count
	end
	return copy
end

local function importPity(player, saved)
	if type(saved) ~= "table" then return end
	local pity = {}
	for graveType, count in pairs(saved) do
		if type(graveType) == "string" and type(count) == "number" and count >= 0 then
			pity[graveType] = math.floor(count)
		end
	end
	playerPity[tostring(player.UserId)] = pity
end

return {
	rollRarity = rollRarity,
	rollUnit = rollUnit,
	getPity = getPity,
	remove = remove,
	exportPity = exportPity,
	importPity = importPity,
}
