-- Economy rules shared by server (authoritative) and client (display only).
local Economy = {}

Economy.INVENTORY_MAX = 300

-- ============================================================
-- Tuned with tools/sim/economy_sim.py (the "income" preset); change the numbers there first and check the pace table.
-- ============================================================
-- Per ascension, the wall gets tougher and pays more (index k = going from k to k+1 ascensions). Tuned for the gate design.
local HP_STEP = { 14, 10, 3, 14, 4, 5.5, 6.5, 6, 5 } -- (2026-10-16 balance pass: stages 2, 3, 5 were too fast; sim variant G)
local GOLD_STEP = { 4, 4, 4, 5, 5, 5, 4.5, 4, 4 }
local WALL_HP_BASE, WALL_HP_GROWTH = 300, 1.20 -- HP of layer L = base * growth^(L-1) * ascension steps
local WALL_GOLD_BASE, WALL_GOLD_GROWTH = 45, 1.12
Economy.DAMAGE_PER_ASCENSION = 1.5 -- every ascension multiplies the damage of all units

local function steps(list, count)
	local product = 1
	for i = 1, math.min(count, #list) do
		product *= list[i]
	end
	return product
end

Economy.WALLS_PER_RUN = 4 -- the 4th wall of a run is the gate: breaking it unlocks the ascension
-- Each wall stands for LAYERS_PER_WALL of the old 32 thin walls ("sub-layers"): its HP, gold and dust are theirs added
-- up, so the pacing of the old design is kept (sim preset "four"). Every wall shows 4 damage stages in game.
Economy.LAYERS_PER_WALL = 8
-- A wall pays part of its gold at each damage stage (75 / 50 / 25 % HP: 3 stages), the rest when it breaks; the total
-- is unchanged (Walls.payStageLoot)
Economy.STAGE_GOLD_SHARE = 0.15
-- Ascensions are grouped into realms (Design.md "Realms"): gold is kept through the ascensions of a realm and only
-- reset when a new realm starts (PlayerData.ascend); the portal behind the gate counts them (server Portal)
Economy.ASCENSIONS_PER_REALM = 5
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

-- Walls get this much tougher per ascension on top of HP_STEP (it balances the realm upgrades, which make the army
-- stronger the longer a realm lasts; sim preset "realm")
local HP_PER_ASCENSION = 0.15

-- HP of the wall at `layer` (1..WALLS_PER_RUN) after `rebirthCount` ascensions: the sum of its sub-layers (the gate's
-- last sub-layer counts GATE_HP_MULT times)
function Economy.wallHp(layer, rebirthCount)
	local hp = 0
	local last = Economy.WALLS_PER_RUN * Economy.LAYERS_PER_WALL
	for sub = (layer - 1) * Economy.LAYERS_PER_WALL + 1, layer * Economy.LAYERS_PER_WALL do
		hp += WALL_HP_BASE * WALL_HP_GROWTH ^ (sub - 1) * (sub == last and GATE_HP_MULT or 1)
	end
	return math.floor(hp * steps(HP_STEP, rebirthCount) * (1 + HP_PER_ASCENSION * rebirthCount))
end

-- ============================================================
-- Realm upgrades: bought with gold, kept through the ascensions of a realm and reset (like the gold) when a new realm
-- starts. Each level costs `base` x `growth`^level, scaled by the gold steps of the realm's first ascension.
-- Tuned with tools/sim/economy_sim.py (preset "realm": might and harvest; march and magnet do not change the economy).
-- ============================================================
Economy.REALM_UPGRADES = {
	{ key = "might", name = "Army Might", per = 0.08, base = 80, growth = 2.2, text = "damage of all units" },
	{ key = "harvest", name = "Soul Harvest", per = 0.08, base = 96, growth = 2.2, text = "gold from hits" },
	{ key = "march", name = "Swift March", per = 0.10, base = 150, growth = 2.4, max = 10, text = "marching speed" },
	{ key = "magnet", name = "Grasping Souls", per = 1.5, base = 120, growth = 2.4, max = 8, text = "coin pickup reach", studs = true },
}
Economy.REALM_UPGRADE = {}
for _, u in ipairs(Economy.REALM_UPGRADES) do
	Economy.REALM_UPGRADE[u.key] = u
end

-- gold for taking realm upgrade `key` from `level` to level + 1 (nil at the max)
function Economy.realmUpgradeCost(key, level, rebirthCount)
	local u = Economy.REALM_UPGRADE[key]
	if not u or (u.max and level >= u.max) then
		return nil
	end
	local realmStart = rebirthCount - rebirthCount % Economy.ASCENSIONS_PER_REALM
	return math.floor(u.base * steps(GOLD_STEP, realmStart) * u.growth ^ level)
end

-- the effect of realm upgrade `key` at `level`: a multiplier (1 + per x level), or extra studs for "studs" upgrades
function Economy.realmUpgradeEffect(key, level)
	local u = Economy.REALM_UPGRADE[key]
	if not u then
		return 1
	end
	if u.studs then
		return u.per * (level or 0)
	end
	return 1 + u.per * (level or 0)
end

-- Gold for breaking the wall of `layer` (before the coin boost): the sum of its sub-layers
function Economy.wallGold(layer, rebirthCount)
	local gold = 0
	for sub = (layer - 1) * Economy.LAYERS_PER_WALL + 2, layer * Economy.LAYERS_PER_WALL + 1 do
		gold += WALL_GOLD_BASE * WALL_GOLD_GROWTH ^ (sub - 1)
	end
	return math.floor(gold * steps(GOLD_STEP, rebirthCount))
end

-- ============================================================
-- Hit income: every unit hitting the wall earns gold per second ON TOP of the break gold, so a player stuck on a tough
-- wall still earns. Geometric by rarity rank, x the unit's level multiplier, x the per-ascension steps, x the coin boost.
-- ============================================================
local INCOME_BASE, INCOME_GROWTH = 3, 1.5 -- gold/s of a Common unit at ascension 0, x1.5 per rarity rank
local INCOME_STEP = { 4, 4, 3, 2, 1.5, 1.5, 1.5, 1.5, 1.5 }

-- Growth of the hit income from ascensions (the same for every unit)
function Economy.hitIncomeStep(rebirthCount)
	return steps(INCOME_STEP, rebirthCount)
end

-- Gold per second a unit of `rank` and `level` earns while hitting the wall (before the coin boost)
function Economy.hitIncome(rank, level, rebirthCount)
	return INCOME_BASE * INCOME_GROWTH ^ ((rank or 1) - 1) * Economy.levelMultiplier(level) * Economy.hitIncomeStep(rebirthCount)
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
-- from this level on a unit is "awakened": it appears in its shadow form (the model "<Unit>_Shadow", when it has one)
Economy.AWAKEN_LEVEL = 10
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

-- Dismantling an UPGRADED unit gives back this share of the dust its levels cost (the successful steps; failed tries
-- are not counted): low-rarity units fall off fast, and an upgrade should not feel wasted when the unit is outgrown.
Economy.DISMANTLE_REFUND = 0.5

-- all the dust dismantling a unit of `rarity` at `level` gives: the base yield plus the refund of its levels
function Economy.dismantleDust(rarity, level)
	local spent = 0
	for l = 0, (level or 0) - 1 do
		spent += Economy.unitUpgradeCost(l, rarity)
	end
	return Economy.dismantleYield(RARITY_INDEX[rarity] or 1) + math.floor(spent * Economy.DISMANTLE_REFUND)
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

-- The Gem Shop (HUD Shop tile, usable anywhere; server GemShop): catalysts (above), Remote Forge (the Forge opens
-- anywhere, one-time) and Soul Wisp speed levels.
Economy.REMOTE_FORGE_PRICE = 250
-- Malak's Fleet Strike (docs/envoy.md): a one-time Gem Shop unlock (per account: any Malak can use it); at this share of
-- the gate's HP, with a Malak on the plot, the Absolution executes the gate (server Army.checkFleetStrike)
Economy.FLEET_STRIKE_PRICE = 1000
-- Veyr's The Final Horizon (docs/veyr.md): its own one-time unlock, separate from the Fleet Strike; the same gate share
-- (Economy.FLEET_STRIKE_HP) triggers it (server Army.checkFinisher)
Economy.FINAL_HORIZON_PRICE = 1000
-- Orvoss's The Last Broadside (docs/orvoss.md): its own one-time unlock, the same trigger
Economy.LAST_BROADSIDE_PRICE = 1000
-- the second commander slot (the throne for a second Signature / Sovereign; Design.md "the commander slot")
Economy.COMMANDER_SLOT_PRICE = 500
Economy.MAX_COMMANDER_SLOTS = 2
Economy.FLEET_STRIKE_HP = 0.2
Economy.WISP_MAX_LEVEL = 5
function Economy.wispLevelPrice(level) -- gems to go from `level` to level + 1: 40, 80, 160, 320, 640
	return 40 * 2 ^ level
end
function Economy.wispSpeed(level) -- studs per second: 14 at level 0, +30 % per level (35 at level 5)
	return 14 * (1 + 0.3 * level)
end
function Economy.wispPause(level) -- seconds the wisp lingers after each pick-up
	return 0.5 * (1 - 0.12 * level)
end

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

-- What breaking the wall of `layer` drops after `rebirthCount` ascensions: a list of { dust, amount }, the sum of its
-- sub-layers. Each sub-layer drops mostly the dust of the best rarity the player has reached (one higher than their
-- ascensions), sometimes of the rarity below; every BOSS_EVERY-th sub-layer and the gate's last one add three times as
-- much of the dust of the rarity above.
function Economy.wallMaterials(layer, rebirthCount)
	local top = math.min(#Economy.RARITIES_ASC, rebirthCount + 2) -- index into RARITIES_ASC (1 = Common)
	local last = Economy.WALLS_PER_RUN * Economy.LAYERS_PER_WALL
	local total, order = {}, {}
	local function add(rarityIndex, amount)
		local dust = Economy.dustOf(Economy.RARITIES_ASC[rarityIndex])
		if not total[dust] then
			total[dust] = 0
			table.insert(order, dust)
		end
		total[dust] += amount
	end
	for sub = (layer - 1) * Economy.LAYERS_PER_WALL + 2, layer * Economy.LAYERS_PER_WALL + 1 do
		local amount = 1 + sub // 3
		add((math.random() < 0.7) and top or math.max(1, top - 1), amount)
		if sub % BOSS_EVERY == 0 or sub == last then
			add(math.min(#Economy.RARITIES_ASC, top + 1), amount * 3)
		end
	end
	local drops = {}
	for _, dust in ipairs(order) do
		table.insert(drops, { dust = dust, amount = total[dust] })
	end
	return drops
end

return Economy
