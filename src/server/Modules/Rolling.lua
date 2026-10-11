-- Rarity/unit rolling with luck and pity.
local Rarities = require(game:GetService("ReplicatedStorage").Shared.Rarities)
local Units = require(game:GetService("ReplicatedStorage").Shared.Units)

local BASE_ODDS = Rarities.BaseOdds
local RARITY_RANK = Rarities.Rank
local RARITY_ORDER = Rarities.Order
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

local function remove(player)
	playerPity[tostring(player.UserId)] = nil
end

return {
	rollRarity = rollRarity,
	rollUnit = rollUnit,
	getPity = getPity,
	remove = remove,
}
