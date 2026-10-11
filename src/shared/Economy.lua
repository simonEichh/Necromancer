-- Economy rules shared by server (authoritative) and client (display only).
local Economy = {}

Economy.INVENTORY_MAX = 300
Economy.ASCEND_COSTS = { 4000, 25000, 50000 }
Economy.UPGRADE_MAX = { luckBoost = 20, coinBoost = 15 }

function Economy.luckBoostCost(level)
	return math.floor(500 * (2.5 ^ level))
end

function Economy.coinBoostCost(level)
	return math.floor(1500 * (3.0 ^ level))
end

-- Cost of the next level of an upgrade, or nil for an unknown upgrade
function Economy.upgradeCost(upgradeType, level)
	if upgradeType == "luckBoost" then
		return Economy.luckBoostCost(level)
	elseif upgradeType == "coinBoost" then
		return Economy.coinBoostCost(level)
	end
	return nil
end

-- Gold for selling a unit with the given "1 in X" odds (before coin boost)
function Economy.sellValue(oneIn)
	return math.floor((oneIn or 1) ^ 1.2 * 5)
end

-- Cost of the next ascension given how many the player already has
function Economy.ascendCost(rebirthCount)
	return Economy.ASCEND_COSTS[math.min(rebirthCount + 1, #Economy.ASCEND_COSTS)]
end

function Economy.goldMultiplier(rebirthCount)
	return 1.0 + rebirthCount
end

-- Multiplier applied to wall-break gold
function Economy.wallGoldMultiplier(rebirthCount, coinBoostLevel)
	return Economy.goldMultiplier(rebirthCount) + coinBoostLevel * 0.5
end

-- Multiplier applied to gold from selling
function Economy.sellGoldMultiplier(coinBoostLevel)
	return 1 + coinBoostLevel * 0.5
end

return Economy
