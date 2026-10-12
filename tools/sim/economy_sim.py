#!/usr/bin/env python3
"""Economy / pacing simulator for Necromancer.

Plays the game like a typical player and prints how long each stage takes, so the curves in Economy.lua, Graves.lua and
Walls.lua can be tuned against the pace targets (see TARGETS) before anything is changed in the game.

    python tools/sim/economy_sim.py                       # the "proposed" rules, one run, 2 h of play per day
    python tools/sim/economy_sim.py --preset current      # the rules the game has today (shows why they need changing)
    python tools/sim/economy_sim.py --runs 20             # median over 20 random runs
    python tools/sim/economy_sim.py --hours-per-day 1.5 --max-hours 120

Unit stats, the rarity pools and odds, grave prices and luck are READ from the game files (src/shared/*.lua), so the
simulation always uses the real roster. Everything else (wall curves, ascension, upgrades, materials) lives in PRESETS.

What is modelled: the shop (limited stock, rotation every 5 minutes), best-of-N luck rolls with pity, placing the best
units in the grave slots (5 + 1 per ascension, max 10), walls (HP and gold per layer), ascending, the two gold upgrades and
the planned unit upgrade system (materials of a tier per rarity, success chance with pity, no level loss on failure,
dismantling spare units into materials). Time is ACTIVE play time (the army only fights while the player is in the game).
Not modelled: the wheel, quests, offline rewards, ranged-unit march time, formation.
"""
import argparse
import math
import os
import random
import re
import statistics

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")
SHARED = os.path.join(ROOT, "src", "shared")


# ============================================================
# Game data (read from the Lua files)
# ============================================================
def read(name):
    with open(os.path.join(SHARED, name), encoding="utf-8") as f:
        return f.read()


def load_game_data():
    units_src = read("Units.lua")
    # unit stats
    stats = {}
    block = units_src[units_src.index("local UNITS = {"): units_src.index("-- Which units belong to which rarity")]
    for m in re.finditer(r"\n\t(\w+) = \{(.*?)\n\t\},", block, re.S):
        body = m.group(2)
        dmg = re.search(r"damage = ([\d.]+)", body)
        cd = re.search(r"attackCD = ([\d.]+)", body)
        if dmg and cd:
            stats[m.group(1)] = {"damage": float(dmg.group(1)), "cd": float(cd.group(1)), "static": "static = true" in body}
    # rarity pools
    pools = {}
    pool_src = units_src[units_src.index("local RARITY_UNITS = {"): units_src.index("-- Reverse lookup")]
    for m in re.finditer(r"\n\t(\w+) = \{(.*?)\n\t\},", pool_src, re.S):
        entries = re.findall(r'unit = "(\w+)", weight = (\d+)', m.group(2))
        pools[m.group(1)] = [(u, int(w)) for u, w in entries]

    rar_src = read("Rarities.lua")
    odds_block = rar_src[rar_src.index("local BASE_ODDS = {"): rar_src.index("local RARITY_RANK")]
    odds = {k: float(v) for k, v in re.findall(r"(\w+) = ([\d.]+),", odds_block)}
    rank_block = rar_src[rar_src.index("local RARITY_RANK = {"): rar_src.index("local RARITY_ORDER")]
    rank = {k: int(v) for k, v in re.findall(r"(\w+) = (\d+),", rank_block)}
    rarities = sorted(rank, key=lambda r: rank[r])  # lowest to highest

    graves = []
    gsrc = read("Graves.lua")
    for m in re.finditer(r"\n\t(\w+) = \{\s*name = \"[^\"]+\",\s*cost = (\d+),\s*odds = \{([^}]*)\},\s*pityRarity = \"(\w+)\",\s*unlockAscension = (\d+),", gsrc):
        table = {r: float(v) for r, v in re.findall(r"(\w+) = ([\d.]+)", m.group(3))}
        graves.append({"key": m.group(1), "cost": int(m.group(2)), "odds_table": table, "pity": m.group(4), "unlock": int(m.group(5))})

    # per-unit "1 in X" (Units.getBaseOneIn) and sell value base
    one_in = {}
    for rar, entries in pools.items():
        total = sum(w for _, w in entries)
        for unit, w in entries:
            chance = odds[rar] / 100 * (w / total)
            one_in[unit] = max(2, round(1 / chance))
    unit_rarity = {u: r for r, es in pools.items() for u, _ in es}
    return {"stats": stats, "pools": pools, "odds": odds, "rank": rank, "rarities": rarities, "graves": graves,
            "one_in": one_in, "unit_rarity": unit_rarity}


GAME = load_game_data()
RARITIES = GAME["rarities"]
RANK = GAME["rank"]


# ============================================================
# Rules (presets). "current" = what the game does today. "proposed" = the new design being tuned.
# ============================================================
SHOP_STOCK = {"Mossy": 999, "Stone": 50, "Ancient": 30, "Cursed": 20, "Shadow": 15, "Abyssal": 10, "Eldritch": 5, "Void": 3, "Eternal": 2, "Celestial": 1}
SHOP_CHANCE = {"Mossy": 1.0, "Stone": 0.9, "Ancient": 0.8, "Cursed": 0.7, "Shadow": 0.6, "Abyssal": 0.5, "Eldritch": 0.4, "Void": 0.3, "Eternal": 0.2, "Celestial": 0.1}
RESTOCK_SECONDS = 300
MATERIALS = ["Stone Dust", "Bone Shards", "Grave Iron", "Hex Ash", "Gilded Relic", "Abyssal Pearl", "Eldritch Ichor", "Eternal Ember", "Primordial Core"]  # one per rarity, lowest first

def prod(xs):
    out = 1.0
    for x in xs:
        out *= x
    return out


# per-ascension growth of wall HP, wall gold and ascension price (step k = going from ascension k to k+1)
HP_STEP = [3.5, 3.5, 3.5, 5, 5, 5, 4.5, 4, 4]
GOLD_STEP = [4, 4, 4, 5, 5, 5, 4.5, 4, 4]
COST_STEP = [6, 6, 6, 8, 8, 8, 7, 6, 6]

PRESETS = {
    "current": dict(
        start_gold=50000,  # the game's testing value
        wall_hp=lambda L, r: 500 * 2 ** (L - 1),
        wall_gold=lambda L, r, coin: 1000 * L * (1 + r + 0.5 * coin),
        ascend_cost=lambda r: [4000, 25000, 50000][min(r, 2)],
        damage_mult=lambda r: 1.0,
        upgrades=False,
        boss_every=0,
    ),
    "proposed": dict(
        start_gold=300,
        shop_stock={"Mossy": 40, "Stone": 25, "Ancient": 20, "Cursed": 15, "Shadow": 12, "Abyssal": 8, "Eldritch": 5, "Void": 3, "Eternal": 2, "Celestial": 1},
        wall_hp=lambda L, r: 300 * 1.22 ** (L - 1) * prod(HP_STEP[:r]),
        wall_gold=lambda L, r, coin: 45 * 1.12 ** (L - 1) * prod(GOLD_STEP[:r]) * (1 + 0.5 * coin),
        ascend_cost=lambda r: 2500 * prod(COST_STEP[:r]),
        damage_mult=lambda r: 1.5 ** r,  # ascension = damage multiplier
        upgrades=True,
        boss_every=10,
        # unit upgrade system
        max_level=10,
        level_damage=0.30,  # +30% damage per level (additive)
        upgrade_base_cost=4,  # materials for the first level of any rarity
        upgrade_cost_growth=1.55,
        upgrade_fail_keep=0.5,  # on failure only half the materials are lost
        upgrade_pity=0.10,  # +10 % success chance per consecutive failure
        dismantle_base=2,  # materials from dismantling a spare unit of the lowest rarity
        dismantle_growth=1.8,  # ...times this per rarity step
        wall_mats=lambda L, r: 1 + L // 3,  # materials per wall break
    ),
}

# "gate" preset: a fixed number of walls per run, the last one is the gate; beating it ascends (no gold price).
GATE_HP_STEP = [3.5, 3.5, 3.5, 9, 6, 9, 8, 6, 6]  # tougher late steps than "proposed": the run is a fixed length, so HP carries the difficulty
PRESETS["gate"] = dict(
    PRESETS["proposed"],
    gate=dict(walls=32, hp_mult=1.5),
    mat_stock=6,  # materials of each tier on sale per 5-minute restock
    mat_price=lambda tier: 20 * 8 ** tier,  # gold per material
    ascend_cost=lambda r: 0,
    wall_hp=lambda L, r: 300 * 1.22 ** (L - 1) * prod(GATE_HP_STEP[:r]),
)

# Pace targets in ACTIVE minutes per stage (my proposal; the user agreed): ascension k takes this long after the previous one.
TARGETS = {1: (10, 15), 2: (20, 40), 3: (20, 40), 4: (20, 40), 5: (60, 180), 6: (60, 180), 7: (60, 180), 8: (180, 1440), 9: (180, 1440)}

LUCK_COST = lambda lv: math.floor(500 * 2.5 ** lv)
COIN_COST = lambda lv: math.floor(1500 * 3.0 ** lv)
LUCK_MAX, COIN_MAX = 20, 15
STALL_SECONDS = 150  # the player ascends once the current wall would take longer than this
PITY_AT = 60
LUCK_STEP = 0.10  # +10 % per luck upgrade level (rework: multiplies the weights of Rare and better)


# ============================================================
# One simulated player
# ============================================================
class Player:
    def __init__(self, rules, rng, hours_per_day):
        self.R = rules
        self.rng = rng
        self.t = 0.0  # active seconds
        self.gold = rules["start_gold"]
        self.r = 0  # ascensions
        self.layer = 1
        self.wall_hp = rules["wall_hp"](1, 0)
        self.graves = {g["key"]: 0 for g in GAME["graves"]}
        self.pity = {g["key"]: 0 for g in GAME["graves"]}
        self.luck_lv = 0
        self.coin_lv = 0
        self.units = []  # {"type", "level"}
        self.mats = {m: 0 for m in MATERIALS}
        self.fail_streak = {}  # per unit id
        self.events = []  # (time, kind, text): the "meaningful progress" moments
        self.best_rank = -1
        self.ascend_times = []
        self.layers_at_ascend = []
        self.shop = {}
        self.next_restock = 0.0
        self.restock(0.0)
        self.slots = 5
        self.uid = 0
        self.pulls = 0
        self.snap = []

    # ---- helpers -------------------------------------------------
    def hp_for(self, layer):
        """HP of the wall at `layer`; in gate mode the last wall (the gate) is tougher."""
        hp = self.R["wall_hp"](layer, self.r)
        gate = self.R.get("gate")
        if gate and layer == gate["walls"]:
            hp *= gate["hp_mult"]
        return hp

    def do_ascend(self):
        self.gold = 0
        self.r += 1
        self.snap.append((self.pulls, round(self.total_dps()), [GAME["unit_rarity"][u["type"]][:4] for u in self.placed()][:5]))
        self.ascend_times.append(self.t)
        self.layers_at_ascend.append(self.layer)
        self.log("ascend", f"#{self.r} (reached layer {self.layer})")
        self.layer = 1
        self.wall_hp = self.hp_for(1)
        self.slots = min(10, 5 + self.r)

    def log(self, kind, text=""):
        self.events.append((self.t, kind, text))

    def restock(self, now):
        self.shop = {k: (SHOP_STOCK[k] if self.rng.random() <= SHOP_CHANCE[k] else 0) for k in SHOP_STOCK}
        self.next_restock = now + RESTOCK_SECONDS
        # the material shop restocks with the grave shop: a few of every tier
        self.mat_shop = {i: self.R.get("mat_stock", 0) for i in range(len(MATERIALS))}

    def unit_dps(self, u):
        s = GAME["stats"][u["type"]]
        lvl = 1 + self.R.get("level_damage", 0) * u["level"] if self.R["upgrades"] else 1
        return s["damage"] / s["cd"] * lvl * self.R["damage_mult"](self.r)

    def placed(self):
        return sorted(self.units, key=lambda u: -self.unit_dps(u))[: min(10, 5 + self.r)]

    def total_dps(self):
        return sum(self.unit_dps(u) for u in self.placed())

    # ---- rolling -------------------------------------------------
    def roll_rarity(self, grave):
        key = grave["key"]
        if self.pity[key] >= PITY_AT:
            self.pity[key] = 0
            return grave["pity"]
        if "odds_table" in grave:
            f = 1 + LUCK_STEP * self.luck_lv  # luck upgrade: every Rare-or-better weight is multiplied by f
            w = [(rar, p * (f if RANK[rar] >= 3 else 1)) for rar, p in grave["odds_table"].items()]
            pick = self.rng.random() * sum(x for _, x in w)
            acc = 0
            best = w[-1][0]
            for rar, x in w:
                acc += x
                if pick <= acc:
                    best = rar
                    break
            self.pity[key] = 0 if RANK[best] >= RANK[grave["pity"]] else self.pity[key] + 1
            return best
        mult = max(1.0, grave["luck"] * (1 + 0.1 * self.luck_lv) / 100)
        rolls = int(mult) + (1 if self.rng.random() < mult % 1 else 0)
        # best of N base rolls, sampled directly from the CDF: P(best <= k) = cdf_k ** N
        u = self.rng.random()
        best = None
        cum = 0.0
        for rar in RARITIES:
            cum += GAME["odds"][rar] / 100
            if u <= min(1.0, cum) ** rolls:
                best = rar
                break
        best = best or RARITIES[-1]
        self.pity[key] = 0 if best == grave["pity"] else self.pity[key] + 1
        return best

    def open_graves(self, key, n):
        grave = next(g for g in GAME["graves"] if g["key"] == key)
        for _ in range(n):
            rar = self.roll_rarity(grave)
            pool = GAME["pools"][rar]
            pick = self.rng.random() * sum(w for _, w in pool)
            acc = 0
            unit = pool[-1][0]
            for name, w in pool:
                acc += w
                if pick <= acc:
                    unit = name
                    break
            self.units.append({"type": unit, "level": 0, "id": self.uid})
            self.uid += 1
            self.pulls += 1
            if RANK[rar] > self.best_rank:
                self.best_rank = RANK[rar]
                self.log("new_rarity", f"{rar} ({unit})")
        self.graves[key] -= n

    # ---- the player's decisions ---------------------------------
    def ascend_cost(self):
        return self.R["ascend_cost"](self.r)

    def manage(self):
        R = self.R
        if self.t >= self.next_restock:
            self.restock(self.t)

        # upgrades of gold (luck / coin): buy when cheap compared with the gold in hand
        for _ in range(3):
            if self.luck_lv < LUCK_MAX and LUCK_COST(self.luck_lv) <= self.gold * 0.15:
                self.gold -= LUCK_COST(self.luck_lv)
                self.luck_lv += 1
            elif self.coin_lv < COIN_MAX and COIN_COST(self.coin_lv) <= self.gold * 0.15:
                self.gold -= COIN_COST(self.coin_lv)
                self.coin_lv += 1
            else:
                break

        # is the wall stalling? then save for the next ascension, otherwise spend everything
        dps = max(self.total_dps(), 1e-9)
        stalled = len(self.units) >= self.slots and self.wall_hp / dps > STALL_SECONDS
        can_ascend = self.ascend_cost() is not None and not R.get("gate")  # gate mode: beating the gate ascends, no gold needed
        reserve = self.ascend_cost() if (stalled and can_ascend) else 0

        # buy graves: highest unlocked tier first (it is the best use of gold), limited by shop stock
        for grave in reversed(GAME["graves"]):
            if grave["unlock"] > self.r:
                continue
            key = grave["key"]
            stock = self.shop.get(key, 0)
            afford = int(max(0, self.gold - reserve) // grave["cost"])
            n = min(stock, afford)
            if n > 0:
                self.gold -= n * grave["cost"]
                self.shop[key] = stock - n
                self.graves[key] += n
        before = {u["id"] for u in self.placed()}
        # open everything (only up to the free inventory; ignored here)
        for key, n in list(self.graves.items()):
            if n > 0:
                self.open_graves(key, n)

        self.manage_units()
        entered = [u for u in self.placed() if u["id"] not in before]
        if entered and self.pulls > 6:
            self.log("better_unit", ", ".join(u["type"] for u in entered[:3]))

        # ascend (gold price mode)
        if stalled and can_ascend and self.gold >= self.ascend_cost():
            self.do_ascend()

    def manage_units(self):
        R = self.R
        placed = self.placed()
        placed_ids = {u["id"] for u in placed}
        placed_rarities = {GAME["unit_rarity"][u["type"]]: u for u in placed}
        keep = []
        for u in self.units:
            if u["id"] in placed_ids:
                keep.append(u)
                continue
            rar = GAME["unit_rarity"][u["type"]]
            if R["upgrades"] and rar in placed_rarities and placed_rarities[rar]["level"] < R["max_level"]:
                # a spare unit of a rarity we are upgrading: dismantle it for materials
                self.mats[MATERIALS[RANK[rar] - 1]] += round(R["dismantle_base"] * R["dismantle_growth"] ** (RANK[rar] - 1))
            else:
                one_in = GAME["one_in"][u["type"]]
                self.gold += math.floor(one_in ** 1.2 * 5) * (1 + 0.5 * self.coin_lv)
        self.units = keep
        if R["upgrades"]:
            self.buy_materials()
            self.try_upgrades()

    def buy_materials(self):
        """Gold sink: buy the materials the next upgrade of a placed unit needs, limited by the shop's stock and price."""
        R = self.R
        if not R.get("mat_stock"):
            return
        for u in self.placed():
            if u["level"] >= R["max_level"]:
                continue
            rar = GAME["unit_rarity"][u["type"]]
            tier = RANK[rar] - 1
            cost = math.ceil(R["upgrade_base_cost"] * R["upgrade_cost_growth"] ** u["level"])
            need = cost - self.mats[MATERIALS[tier]]
            if need <= 0:
                continue
            price = R["mat_price"](tier)
            n = min(need, self.mat_shop.get(tier, 0), int(self.gold // price))
            if n > 0:
                self.gold -= n * price
                self.mat_shop[tier] -= n
                self.mats[MATERIALS[tier]] += n

    def try_upgrades(self):
        R = self.R
        for u in self.placed():
            while u["level"] < R["max_level"]:
                rar = GAME["unit_rarity"][u["type"]]
                mat = MATERIALS[RANK[rar] - 1]
                cost = math.ceil(R["upgrade_base_cost"] * R["upgrade_cost_growth"] ** u["level"])
                if self.mats[mat] < cost:
                    break
                chance = min(1.0, max(0.2, 1 - 0.08 * u["level"]) + R["upgrade_pity"] * self.fail_streak.get(u["id"], 0))
                if self.rng.random() < chance:
                    self.mats[mat] -= cost
                    u["level"] += 1
                    self.fail_streak[u["id"]] = 0
                    self.log("level_up", f"{u['type']} -> {u['level']}")
                else:
                    self.mats[mat] -= math.ceil(cost * R["upgrade_fail_keep"])
                    self.fail_streak[u["id"]] = self.fail_streak.get(u["id"], 0) + 1

    # ---- the wall ------------------------------------------------
    def fight(self, dt):
        dmg = self.total_dps() * dt
        R = self.R
        broke = 0
        while dmg >= self.wall_hp and broke < 200:
            dmg -= self.wall_hp
            gate = R.get("gate")
            if gate and self.layer == gate["walls"]:
                self.log("gate", f"cleared at {self.t / 60:.1f} min")
                self.do_ascend()  # beating the gate ascends
                continue
            self.layer += 1
            broke += 1
            self.gold += R["wall_gold"](self.layer, self.r, self.coin_lv)
            if R["upgrades"]:
                self.drop_materials()
            self.wall_hp = self.hp_for(self.layer)
        self.wall_hp -= dmg

    def drop_materials(self):
        """Every wall drops materials of a tier around the player's ascension; boss walls drop a better tier."""
        R = self.R
        top = min(len(MATERIALS) - 1, self.r + 1)
        amount = R["wall_mats"](self.layer, self.r)
        # mostly the top unlocked tier, sometimes one below
        tier = top if self.rng.random() < 0.7 else max(0, top - 1)
        self.mats[MATERIALS[tier]] += amount
        if R["boss_every"] and self.layer % R["boss_every"] == 0:
            self.mats[MATERIALS[min(len(MATERIALS) - 1, top + 1)]] += amount * 3
            self.log("boss", f"layer {self.layer}")


def apply_overrides(rules):
    """Presets may override grave prices / luck, shop stock and rarity odds (all read from the game files otherwise)."""
    for g in GAME["graves"]:
        g["cost"] = rules.get("grave_cost", {}).get(g["key"], g["cost"])
    for k, v in rules.get("shop_stock", {}).items():
        SHOP_STOCK[k] = v
    for k, v in rules.get("odds", {}).items():
        GAME["odds"][k] = v


def tier_odds(t, center_step, up, down, prim_factor):
    """Rarity weights (percent) of grave tier t: a bell around a centre rank; ranks above fade by 10^-up per rank, ranks below by 10^-down."""
    c = 1 + t * center_step
    w = {}
    for rar in RARITIES:
        k = RANK[rar]
        x = 10 ** (-(k - c) * up) if k >= c else 10 ** (-(c - k) * down)
        if rar == RARITIES[-1]:
            x *= prim_factor
        w[rar] = x
    tot = sum(w.values())
    return {r: 100 * v / tot for r, v in w.items()}


def dps_for(rank, base, growth):
    return base * growth ** (rank - 1)


def rebalance(rules):
    rb = rules.get("rebalance")
    if not rb:
        return
    for i, g in enumerate(GAME["graves"]):
        g["odds_table"] = tier_odds(i, rb["center_step"], rb["up"], rb["down"], rb["prim_factor"])
    # unit DPS: geometric by rarity rank, relative order inside a rarity kept from the current stats
    for rar, entries in GAME["pools"].items():
        cur = {u: GAME["stats"][u]["damage"] / GAME["stats"][u]["cd"] for u, _ in entries}
        low = min(cur.values())
        for u, _ in entries:
            rel = (cur[u] / low) ** rb.get("spread", 0.5)
            GAME["stats"][u]["damage"] = dps_for(RANK[rar], rb["dps_base"], rb["dps_growth"]) * rel * GAME["stats"][u]["cd"]


def run(rules, seed, max_hours):
    apply_overrides(rules)
    rebalance(rules)
    rng = random.Random(seed)
    p = Player(rules, rng, 0)
    next_manage = 0.0
    while p.t < max_hours * 3600 and len(p.ascend_times) < 9:
        dt = 2.0 if p.t < 300 else (5.0 if p.t < 3600 else 10.0)
        p.fight(dt)
        p.t += dt
        if p.t >= next_manage:
            p.manage()
            next_manage = p.t + (10 if p.t < 600 else 30)
    return p


# ============================================================
# Report
# ============================================================
def fmt_min(m):
    if m < 120:
        return f"{m:6.1f} min"
    if m < 60 * 48:
        return f"{m / 60:6.1f} h  "
    return f"{m / 1440:6.1f} d  "


def judge(k, minutes):
    lo, hi = TARGETS.get(k, (None, None))
    if lo is None:
        return ""
    if minutes < lo * 0.7:
        return "TOO FAST"
    if minutes > hi * 1.4:
        return "TOO SLOW"
    return "ok" if lo * 0.7 <= minutes <= hi * 1.4 else ""


def report(runs, preset, hours_per_day):
    print(f"preset: {preset}   ({len(runs)} run(s), active play time)\n")
    first_wall = []
    for p in runs:
        # time of the first wall break is not logged separately; the first ascension tells the early pace
        pass
    print(f"{'ascension':>10} {'stage took':>12} {'total':>12} {'target':>14}   {'layers climbed':>15}  verdict")
    for k in range(1, 10):
        durations, totals, layers = [], [], []
        for p in runs:
            if len(p.ascend_times) >= k:
                prev = p.ascend_times[k - 2] if k > 1 else 0
                durations.append((p.ascend_times[k - 1] - prev) / 60)
                totals.append(p.ascend_times[k - 1] / 60)
                layers.append(p.layers_at_ascend[k - 1])
        if not durations:
            print(f"{k:>10}   (not reached in {runs[0].t / 3600:.0f} active hours)")
            continue
        d = statistics.median(durations)
        t = statistics.median(totals)
        lo, hi = TARGETS[k]
        tgt = f"{lo}-{hi} min" if hi < 600 else f"{lo / 60:.0f}h-{hi / 60:.0f}h"
        print(f"{k:>10} {fmt_min(d)} {fmt_min(t)} {tgt:>14}   {statistics.median(layers):>15.0f}  {judge(k, d)}")
    reached = [len(p.ascend_times) for p in runs]
    end_t = [p.t / 60 for p in runs if len(p.ascend_times) >= 9]
    if end_t:
        total_h = statistics.median(end_t) / 60
        print(f"\nall 9 ascensions: {total_h:.1f} active hours = {total_h / hours_per_day:.1f} days at {hours_per_day} h/day (target 2-4 weeks)")
    else:
        print(f"\nascensions reached after {runs[0].t / 3600:.0f} active hours: median {statistics.median(reached)}")

    # the longest gaps between "meaningful progress" events (a new rarity, a level up, an ascension, a boss wall)
    gaps = []
    for p in runs:
        times = [0.0] + [e[0] for e in p.events if e[1] in ("new_rarity", "level_up", "ascend", "boss", "better_unit")] + [p.t]
        g = [(b - a) / 60 for a, b in zip(times, times[1:])]
        gaps.append(max(g) if g else 0)
    print(f"longest gap without any progress event (new rarity / level up / ascension / boss wall): median {statistics.median(gaps):.1f} min")

    p = runs[0]
    print("\nfirst run: (total pulls, army DPS, rarities placed) at each ascension")
    for i, sn in enumerate(p.snap):
        print(f"  #{i + 1}: {sn}")
    print("\nfirst run, progress events:")
    shown = 0
    for t, kind, text in p.events:
        if kind in ("ascend", "new_rarity", "boss") or (kind == "level_up" and shown < 4):
            print(f"  {t / 60:9.1f} min  {kind:11s} {text}")
            if kind == "level_up":
                shown += 1


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--preset", default="proposed", choices=list(PRESETS))
    ap.add_argument("--runs", type=int, default=1)
    ap.add_argument("--seed", type=int, default=1)
    ap.add_argument("--hours-per-day", type=float, default=2.0)
    ap.add_argument("--max-hours", type=float, default=200)
    a = ap.parse_args()
    rules = PRESETS[a.preset]
    runs = [run(rules, a.seed + i, a.max_hours) for i in range(a.runs)]
    report(runs, a.preset, a.hours_per_day)


if __name__ == "__main__":
    main()
