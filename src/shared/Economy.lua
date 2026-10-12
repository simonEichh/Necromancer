-- Economy rules shared by server (authoritative) and client (display only).
local Economy = {}

Economy.INVENTORY_MAX = 300

-- ============================================================
-- Tuned with tools/sim/economy_sim.py (the "proposed" preset); change the numbers there first and check the pace table.
-- ============================================================
-- Per ascension, the wall gets tougher and pays more (index k = going from k to k+1 ascensions). Tuned for the gate design.
local HP_STEP = { 3.5, 3.5, 3.5, 9, 6, 9, 8, 6, 6 }
local GOLD_STEP = { 4, 4, 4, 5, 5, 5, 4.5, 4, 4 }
local WALL_HP_BASE, WALL_HP_GROWTH = 300, 1.22 -- HP of layer L = base * growth^(L-1) * ascension steps
local WALL_GOLD_BASE, WALL_GOLD_GROWTH = 45, 1.12
Economy.DAMAGE_PER_ASCENSION = 1.5 -- every ascension multiplies the damage of all units

local function steps(list, count)
	local product = 1
	for i = 1, math.min(count, #list) do
		product *= list[i]
	end
	return product
end

Economy.WALLS_PER_RUN = 32 -- the 32nd wall of a run is the gate: breaking it unlocks the ascension
local GATE_HP_MULT = 1.5

function Economy.isGate(layer)
	return layer == Economy.WALLS_PER_RUN
end
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

-- Damage multiplier of all units for the given number of ascensions
function Economy.damageMultiplier(rebirthCount)
	return Economy.DAMAGE_PER_ASCENSION ^ rebirthCount
end

-- HP of the wall at `layer` after `rebirthCount` ascensions
function Economy.wallHp(layer, rebirthCount)
	local hp = WALL_HP_BASE * WALL_HP_GROWTH ^ (layer - 1) * steps(HP_STEP, rebirthCount)
	if Economy.isGate(layer) then
		hp *= GATE_HP_MULT
	end
	return math.floor(hp)
end

-- Gold for breaking the wall of `layer` (before the coin boost)
function Economy.wallGold(layer, rebirthCount)
	return math.floor(WALL_GOLD_BASE * WALL_GOLD_GROWTH ^ (layer - 1) * steps(GOLD_STEP, rebirthCount))
end

-- Kept for the old ascend panel text: the "multiplier" of an ascension is now the damage multiplier
function Economy.goldMultiplier(rebirthCount)
	return Economy.damageMultiplier(rebirthCount)
end

-- Multiplier applied to wall-break gold (coin boost only; ascensions raise the wall's own gold)
function Economy.wallGoldMultiplier(_rebirthCount, coinBoostLevel)
	return 1 + coinBoostLevel * 0.5
end

-- Multiplier applied to gold from selling
function Economy.sellGoldMultiplier(coinBoostLevel)
	return 1 + coinBoostLevel * 0.5
end

return Economy
