-- Resolves progression rewards for both the server award and the client's prize preview.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Graves = require(ReplicatedStorage.Shared.Graves)
local Economy = require(ReplicatedStorage.Shared.Economy)
local Items = require(ReplicatedStorage.Shared.Items)
local Units = require(ReplicatedStorage.Shared.Units)
local Rarities = require(ReplicatedStorage.Shared.Rarities)

local WheelPrizes = {}

local CHEST_MIN = 300 -- an empty army still gets something

-- Gold per second the placed army earns by hitting the wall (Army.payHitGold without the family bonus):
-- `placed` is the DataSync list of { unitType, level }.
function WheelPrizes.armyIncome(placed, ascension, coinBoost, harvestLevel)
	local perSec = 0
	for _, p in ipairs(placed) do
		perSec += Economy.hitIncome(Rarities.Rank[Units.Rarity[p.unitType]] or 1, p.level, 0)
	end
	return perSec * Economy.hitIncomeStep(ascension) * Economy.wallGoldMultiplier(ascension, coinBoost)
		* Economy.realmUpgradeEffect("harvest", harvestLevel or 0)
end

-- `income` = the army's gold per second (WheelPrizes.armyIncome)
function WheelPrizes.resolve(outcome, ascension, income, crownOwned)
	local graveKey, grave = "Mossy", Graves.Mossy
	for key, def in pairs(Graves) do
		if def.unlockAscension <= ascension and def.unlockAscension > grave.unlockAscension then
			graveKey, grave = key, def
		end
	end
	local prize = { id = outcome.id }
	if outcome.id == "gold_chest" then
		prize.gold = math.max(CHEST_MIN, math.floor(income * 60 * outcome.minutes))
	elseif outcome.id == "grave_hoard" then
		prize.graveType, prize.count = graveKey, outcome.count
	elseif outcome.id == "dust_cache" then
		local dust = Economy.DUSTS[1]
		for i, key in ipairs(Economy.DUSTS) do
			if ascension >= Economy.dustShopUnlock(i) then dust = key end
		end
		prize.dust, prize.count = dust, outcome.count
	elseif outcome.id == "gems" then
		prize.gems = outcome.count
	elseif outcome.id == "luck_potion" then
		prize.count, prize.duration = outcome.count, outcome.duration
	elseif outcome.id == "fortune_bundle" then
		prize.catalyst, prize.count = "Fortune", outcome.count
	elseif outcome.id == "spectral_crown" then
		prize.itemKey = outcome.itemKey
		if crownOwned then prize.gems, prize.duplicate = outcome.duplicateGems, true end
	else
		error("Unknown wheel reward: " .. tostring(outcome.id))
	end
	return prize
end

function WheelPrizes.describe(prize, formatNumber)
	formatNumber = formatNumber or tostring
	if prize.gold then return "+" .. formatNumber(prize.gold) .. " Gold" end
	if prize.duplicate then return "+" .. prize.gems .. " Gems (crown already owned)" end
	if prize.gems then return "+" .. prize.gems .. " Gems" end
	if prize.graveType then return prize.count .. " x " .. Graves[prize.graveType].name end
	if prize.dust then return "+" .. prize.count .. " " .. Economy.DUST_NAMES[prize.dust] end
	if prize.catalyst then return "+" .. prize.count .. " Fortune Catalysts" end
	if prize.itemKey then return Items.Defs[prize.itemKey].name .. " unlocked" end
	return "+" .. prize.count .. " Luck Potion (2x, " .. prize.duration / 60 .. " min)"
end

return WheelPrizes
