# Necro Buddies: design direction

Written 2026-10-14. A guide for choosing the next features, not a promise to build all of them. Ratings are a first
opinion; change them when playtests say otherwise.

## 1. Identity

**A rolling (gacha) game with depth underneath.** The surface is Spin a Baddie: roll a grave, place the unit, it
earns gold, roll again. Underneath is incremental progression (ascensions as rebirths, the Forge, dusts, multipliers)
and a light tycoon touch (your own plot in the coliseum). This is the Pet Simulator formula: gacha on top,
incremental below.

Pillars (every feature should serve at least one):
1. **The rare pull is the core moment.** Cinematics, odds, Signatures. It is also the clip people share.
2. **Simple surface, deep underneath.** A new player only sees roll / place / gold. Systems appear one at a time
   when they become useful.
3. **Always something earning.** Hit income, coins on the lane, the wisp: no dead time while stuck on a wall.
4. **Others matter.** Other players see your pulls and your army, help you, fight bosses with you, compete.
   (This is the biggest gap today.)
5. **Dark gothic, never cute.** No emojis in the UI.

What we are NOT making: a building tycoon (no droppers/conveyors), a menu-and-math idle game.

## 2. Genres in short

| | Tycoon | Incremental / Simulator | Rolling / gacha |
|---|---|---|---|
| Fun | watching your base grow | numbers x10, next zone, rebirth | the rare pull, showing it off |
| Strength | clear goal, visible progress | long retention, endless layers | understood in 5 s, clip-able, impulse buys |
| Weakness | over when the base is done | complex, menus, new players bounce | thin alone, needs constant content |
| Money | 2x cash, auto-collect, VIP | boosts, multipliers, passes | luck potions, server luck, limited units, passes |

**Market snapshot (Roblox top chart, 2026-10-14, players online):** 1 Steal An Egg ~1.03M, 2 Adopt Me ~234K,
3 Brookhaven ~201K, 4 Break and Steal an Egg ~153K, 5 99 Nights in the Forest ~128K; also Blox Fruits, MM2, RIVALS,
Steal a Brainrot, Fish It! in the top 10. Collecting rare things plus a social twist (stealing, trading, showing off)
dominates. What the top games share: a dead-simple loop, other players matter, server-wide boosts bought by one
player, frequent limited events, cheap impulse products plus a few game passes, often trading. Roblox also pays
Premium Payouts for the time Premium members spend in the game (check the current rules on idle time).

## 3. Core loop and unlock order (proposed)

1. Minute 0: roll Mossy graves, place units, they march and hit walls, coins pop out. Only the HUD, hotbar,
   Graves and Place Best are shown.
2. 10 walls: the Soul Wisp (exists).
3. First ascension (~12 min): more grave tiers and slots; the Forge and dust start to matter.
4. Ascension 2-4: Buy Dust, catalysts, Gem Shop items, run upgrades (if built).
5. Mid game: world boss, ranked arena (if built).
6. Late game: mutations, Signatures per tier, trading (if built).

Rule: a system's button appears when the player can first use it, with a short one-line hint.

## 4. Feature ideas with ratings

Scale 1-5. **Fit** = matches the identity; **Impact** = retention / growth / revenue; **Effort** = 5 is cheap,
1 is a big project; **Risk** = 5 is safe. **Score** is my overall verdict for this game, not an average.

### Social layer

| Idea | Fit | Impact | Effort | Risk | Score | Notes |
|---|---|---|---|---|---|---|
| **Rare-pull broadcast** | 5 | 4 | 5 | 5 | **5** | Legendary+: everyone in the server sees the star fall over that plot (the star summon is already in the world) + banner "X pulled Hush (1 in 50,000)". Primordial / Signature: banner in all servers (MessagingService). Makes others want to roll. |
| **Server luck** | 5 | 5 | 4 | 4 | **5** | One player buys it, the whole server gets 2x luck for 15 min, banner "X blessed the server". A genre best seller. Free version: gate clears fill a shared server-luck meter. Paid luck: odds disclosure check first. |
| **World boss** (your idea) | 5 | 5 | 3 | 4 | **5** | Every 20-30 min, countdown banner. Rewards by damage share + a minimum for showing up; boss-only drops (dust, later a boss unit / mutation). HP scales with players. The signature social feature. NOT in the plaza (too small, it would bother the shops): see "World boss plan" below. |
| **Friend boost** | 4 | 4 | 5 | 5 | **4** | +10 % gold per friend in the server (cap). Invites are free advertising. |
| **Leaderboard on the monument** | 4 | 3 | 5 | 5 | **4** | Highest ascension, rarest unit, most walls. Cheap showing off. |
| **Best-unit statue on each plot arch** | 4 | 3 | 4 | 5 | **4** | Your best unit stands on your arch, others see it walking by. |
| **Reinforcements** (helping, your idea) | 4 | 3 | 3 | 4 | **3** | Lend one unit to a friend's lane for 10 min, both get a bonus. Nice, but friend boost covers most of the value for less work. |
| **Async ranked arena** (your PvP idea, cheap form) | 4 | 4 | 2 | 3 | **3** | Your best 5 units become a defense other players raid; ranks, seasons, season rewards. Or a siege race: two players on identical walls, first to break wins. Watch pay-to-win. |
| **Live PvP with fixed slots** (your idea, full form) | 3 | 4 | 1 | 2 | **2** | Needs unit-vs-unit combat (HP, targeting, counters): a new game inside the game. Only after the async arena proves people want PvP. |
| **Unit trading** (your idea) | 4 | 5 | 1 | 1 | **3 (later)** | The strongest long-term driver (Adopt Me, Pet Sim) but scams, dupes, value lists, a changed economy. Needs session locking first (known issue). Last, once the economy is stable. A one-way "gift to a friend" could come earlier. |
| **Coin stealing on lanes** ("Steal a..." touch) | 3 | 3 | 4 | 2 | **2** | Uncollected coins on your lane can be picked up by others walking through. Gives the wisp more value, copies what the top games do, but AFK players losing gold feels bad. Only as an experiment. |

#### World boss plan (agreed 2026-10-14)

1. **First: the sky boss with limbs in every lane.** A colossal undead appears high above the coliseum centre, far
   bigger than anything on the ground, visible from every plot; the plaza and shops stay untouched. It slams a hand /
   claw / tendril into every player's lane right in front of their army (rising out of the ground like the Last
   Lantern), standing in for the wall being fought. Every army keeps fighting in its own lane with its normal
   formation; all damage goes to ONE shared HP bar at the top of the screen. Reuses walls, formation, barrages, beams,
   hit coins; idle players join automatically. The giant overhead is the shared moment (and the clip).
2. **Later: a boss arena outside the ring** as the bigger event version (weekend boss, harder, better drops). A
   "Boss" travel tile teleports players to a separate battlefield where a raid squad (your best 5 units) fights next
   to everyone else's. Most social and spectacular, but a new map and squad logic.

Rejected: the boss breaching one gate (armies leave their lanes, messy pathing), a bigger plaza (rebuilds the whole
world, the shop conflict stays).

### Monetization

| Idea | Fit | Impact | Effort | Risk | Score | Notes |
|---|---|---|---|---|---|---|
| **Luck potions** (timed) | 5 | 5 | 4 | 4 | **5** | Free small ones from wheel / quests, big ones for Robux. Odds disclosure check. |
| **Server luck** | 5 | 5 | 4 | 4 | **5** | See social. |
| **Game passes: 2x Gold, Open All, VIP** | 5 | 4 | 4 | 5 | **5** | Open All is already planned as paid. VIP: small luck + chat tag + cosmetic. |
| **Gem packs** | 4 | 4 | 4 | 5 | **4** | The Gem Shop exists; add a "Get Gems" section. |
| **Limited / event units** | 5 | 5 | 3 | 4 | **4** | Weekly or monthly events with a limited Signature, boss events. Needs an update rhythm. |
| **Extra inventory / grave slots** | 4 | 3 | 4 | 3 | **3** | Comfort is fine; extra grave slots is power, cap it. |

### Upgrades rework

| Idea | Fit | Impact | Effort | Risk | Score | Notes |
|---|---|---|---|---|---|---|
| **Run upgrades** (gold, reset on ascending, priced by stage) | 4 | 4 | 3 | 4 | **4** | Army damage %, hit income %, coin magnet, coins per pop. Gold sink and choices in every run, fills late-game gaps. Keep in ONE panel, in the background. |
| **Permanent upgrades for Souls** (earned at the gate) | 4 | 4 | 3 | 3 | **4** | Luck (small steps, potions keep value), starting gold, lower pity, faster auto roll, offline income. Old Luck / Coin levels refunded as Souls. |
| **Keep Luck / Coin Boost as they are** | 2 | 2 | 5 | 4 | **2** | Fixed gold prices: maxed by ascension 6-7, then dead; competes with paid luck. |

### Content / depth (already in the backlog)

| Idea | Score | Notes |
|---|---|---|
| Mutations (2-5 % at pull time) | **4** | Late-game chase, more rare moments, good for clips. |
| One Signature unit per tier + the guaranteed early Signature | **4** | Strengthens the core pull moment. |
| Collection index | **4** | Cheap, gives every pull meaning. |
| New-player tutorial / gradual unlocks | **5** | Needed before any growth push. |

## 5. Suggested order (when we get there)

1. Rare-pull broadcast, server luck (free meter first, Robux later), luck potions from wheel / quests.
2. Friend boost, monument leaderboard, plot statues.
3. Tutorial and gradual unlocks.
4. World boss: the sky boss with limbs in every lane; later the arena outside the ring.
5. Run upgrades + Souls (sim first).
6. Game passes and gem packs (after the odds disclosure check).
7. Async ranked arena, events with limited units, mutations.
8. Session locking, then trading.
