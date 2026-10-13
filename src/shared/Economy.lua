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

-- ============================================================
-- Unit upgrades (the Forge). Tuned with tools/sim/economy_sim.py (the "dust" preset models these rules).
-- ============================================================
-- Materials are DUSTS, one per pair of rarities (Common + Uncommon use Stone Dust, ...). A unit is upgraded with the dust of
-- ITS rarity; the higher rarity of a pair pays PAIR_COST times as much. Walls drop dust, spare units can be dismantled into it.
-- A failed upgrade never lowers the level: it only costs dust, and every failure makes the next try more likely (pity).
Economy.RARITIES_ASC = { "Common", "Uncommon", "Rare", "Cursed", "Legendary", "Abyssal", "Eldritch", "Eternal", "Primordial" }
Economy.DUSTS = { "Stone", "Silver", "Gold", "Diamond", "Star" } -- lowest first; saved under these keys
Economy.DUST_NAMES = {
	Stone = "Stone Dust",
	Silver = "Silver Dust",
	Gold = "Gold Dust",
	Diamond = "Diamond Dust",
	Star = "Star Dust",
}
local RARITIES_PER_DUST = 2
local PAIR_COST = 1.5

-- index into RARITIES_ASC (1 = Common) of every rarity
local RARITY_INDEX = {}
for i, rarity in ipairs(Economy.RARITIES_ASC) do
	RARITY_INDEX[rarity] = i
end

-- The dust (key from Economy.DUSTS) that upgrades units of `rarity`
function Economy.dustOf(rarity)
	local i = RARITY_INDEX[rarity] or 1
	return Economy.DUSTS[math.min(#Economy.DUSTS, (i - 1) // RARITIES_PER_DUST + 1)]
end

Economy.MAX_UNIT_LEVEL = 10
local LEVEL_DAMAGE = 0.30 -- +30% damage per level
local UPGRADE_BASE_COST, UPGRADE_COST_GROWTH = 4, 1.55
local UPGRADE_FAIL_LOSS = 0.5 -- a failed attempt costs this share of the materials
local UPGRADE_PITY = 0.10 -- +10% chance for every failed attempt in a row on that unit
local DISMANTLE_BASE, DISMANTLE_GROWTH = 2, 1.8
local BOSS_EVERY = 10 -- every 10th wall (and the gate) is a boss wall: it drops materials of a better tier

-- Damage multiplier of a unit of the given level
function Economy.levelMultiplier(level)
	return 1 + LEVEL_DAMAGE * (level or 0)
end

-- Dust needed to take a unit of `rarity` from `level` to `level + 1`
function Economy.unitUpgradeCost(level, rarity)
	local cost = UPGRADE_BASE_COST * UPGRADE_COST_GROWTH ^ level
	if ((RARITY_INDEX[rarity] or 1) - 1) % RARITIES_PER_DUST == 1 then
		cost *= PAIR_COST -- the higher rarity of the pair
	end
	return math.ceil(cost)
end

-- Chance (0..1) that the next upgrade works, given the level and the failed attempts in a row
function Economy.upgradeChance(level, fails)
	return math.min(1, math.max(0.2, 1 - 0.08 * level) + UPGRADE_PITY * (fails or 0))
end

-- Materials lost when an attempt fails
function Economy.upgradeFailLoss(cost)
	return math.ceil(cost * UPGRADE_FAIL_LOSS)
end

-- Dust (of the unit's own rarity) a spare unit gives when dismantled; `rank` = 1 for Common ... 9 for Primordial
function Economy.dismantleYield(rank)
	return math.floor(DISMANTLE_BASE * DISMANTLE_GROWTH ^ (rank - 1) + 0.5)
end

-- Catalysts (bought with gems, kept as a saved count, switched on in the Forge before an upgrade attempt):
--   Fortune: +FORTUNE_BONUS success chance on that attempt (capped at 100 %); used up by the attempt
--   Warding: if the attempt fails, no dust is lost; used up only when it saved the dust (a success keeps it)
Economy.CATALYSTS = { "Fortune", "Warding" } -- display order; saved under these keys
Economy.CATALYST_INFO = {
	Fortune = { name = "Fortune Catalyst", price = 30, text = "+25% chance" },
	Warding = { name = "Warding Catalyst", price = 20, text = "No dust lost on a fail" },
}
Economy.FORTUNE_BONUS = 0.25

-- The dust shop (Buy Dust tab at the Forge, stock rotates with the grave shop every 5 minutes; sim preset "dust").
-- A dust is on sale from the ascension at which walls start dropping it (dust index d: 1 = Stone ... 5 = Star).
Economy.DUST_SHOP_STOCK = 10 -- of each dust per restock
function Economy.dustPrice(d)
	return 20 * 50 ^ (d - 1) -- gold per dust: Stone 20, Silver 1K, Gold 50K, Diamond 2.5M, Star 125M
end
function Economy.dustShopUnlock(d)
	return math.max(0, 2 * d - 3) -- the ascension that unlocks dust d in the shop: 0, 1, 3, 5, 7
end
function Economy.dustIndex(dust)
	for i, key in ipairs(Economy.DUSTS) do
		if key == dust then
			return i
		end
	end
	return nil
end

-- What breaking the wall of `layer` drops after `rebirthCount` ascensions: a list of { dust, amount }.
-- Mostly the dust of the best rarity the player has reached (one higher than their ascensions), sometimes of the rarity
-- below; boss walls and the gate add three times as much of the dust of the rarity above.
function Economy.wallMaterials(layer, rebirthCount, roll)
	local top = math.min(#Economy.RARITIES_ASC, rebirthCount + 2) -- index into RARITIES_ASC (1 = Common)
	local amount = 1 + layer // 3
	local tier = ((roll or math.random()) < 0.7) and top or math.max(1, top - 1)
	local drops = { { dust = Economy.dustOf(Economy.RARITIES_ASC[tier]), amount = amount } }
	if layer % BOSS_EVERY == 0 or layer == Economy.WALLS_PER_RUN then
		local above = Economy.RARITIES_ASC[math.min(#Economy.RARITIES_ASC, top + 1)]
		table.insert(drops, { dust = Economy.dustOf(above), amount = amount * 3 })
	end
	return drops
end

return Economy
