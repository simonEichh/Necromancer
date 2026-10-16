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

### Unit art direction: the shadow army (decided 2026-10-15)

From now on the units get a **Solo Leveling vibe** (the manhwa/anime: the Shadow Monarch's army). Mood board:
https://claude.ai/artifact/YBQLTTpL4rZUNC1A4FHLd3 (private to the user). The units are soldiers of a shadow army
raised by the necromancer: a power fantasy told with darkness and light. Rules:
- **Black first:** black / obsidian bodies with a strong, readable silhouette (horns, plumes, capes, claws, plates);
  detail lives in the shape, not in surface colour.
- **Lit from inside:** the only bright parts are small, intense lights where the shadow burns through: eyes, mouth,
  chest core, seams between plates, weapon edges. Shadow-mana violet (~#8B4DFF, hot core ~#C7A6FF).
- **Made of shadow:** dark violet vapour trails off limbs and capes, pools at the feet; units rise out of the ground in
  smoke.
- **Sharp and armored:** angular, lean, menacing proportions; never round or cute.
- **Power escalates by rank:** higher rarities get more armor, size, glow, a cape, presence (later; the user's rule of
  no per-rarity treatment until the top rarities are settled still holds).
- **Stillness, then violence:** a held anticipation, then an explosive, almost instant strike with a flash and debris,
  then calm (fits the momentum rule).
- Inspiration only: no names, characters or exact designs from Solo Leveling. The graveyard / gothic world stays.
- Decided 2026-10-15: every unit gets rebuilt in this style, the Zombie first (a lopsided brute, the first test).
  Violet is the shared identity, plus **one accent per unit = a trace of what it was in life** (Zombie: rot green
  glowing through its cracks; Skelly: bone white; Ghoul: its yellow eyes), like a knight whose armor turned black
  but kept its red plume. The blue System-style UI frames come later, not now.
- **Shadow = the awakened form (decided 2026-10-15, replaces "every unit in the shadow style"):** units keep a
  dungeon-fantasy base look up to level 9; at `Economy.AWAKEN_LEVEL` (10) they appear in their shadow form (model
  `<Unit>_Shadow`, same shape and rig, so the same animations; Army picks it at spawn, its hits send
  `"<hitFx>Shadow"`). Level 10 shows no level aura: the shadow form is the reward (LevelAuras tiers 3 / 6 / 9 only).
  Done: the Zombie (base: rotting flesh, bone shards, flies, a rot-green crush; shadow: the look above, violet crush),
  the Skelly (shadow: black bones and skull, only the teeth bone white, violet-edged blade) and the Ghoul (shadow: black, its
  yellow eyes kept, violet claws, low smoke). Every shadow form has the ethereal layer (ForceField shimmer, dark flames,
  a faint violet tint); the forms differ by silhouette, accent and their own extras (blade smear, crawling smoke).
- **Uncommon roster (agreed 2026-10-15):** Hollow Archer (built, replaced the Goblin; the poison mechanic is gone),
  Crypt Spider (built, replaced the Ghost: a spider grown into a human skull, one attack: the venom spit), Wraith reworked (a floating shroud
  lashing chains), Crypt Bat reworked (built: a slow screech dive every 1.6 s). Each gets a base and a shadow form.
- **Origin (agreed):** the graves hold the dead; digging one is the raising. The necromancer's command is **RISE**:
  the grave cracks, black smoke pours out, a shape rises and its eyes ignite violet. The reveal's fake-out becomes
  "the soul resists" (the smoke collapses, the grave shakes, then it gives in). Owned units live in the necromancer's
  shadow; placing one = it rises from the shadow at its grave; ascending = the army sinks back into the shadow.
  Later idea: the Codex shows what a unit was before it was raised.

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

**Boss designs** (best fit: a body with 8 limbs, one per plot, so each lane's "wall" is part of the boss). A rotation
of 2-3 bosses later keeps the event fresh.

| Boss | The "wall" in each lane | Score | Notes |
|---|---|---|---|
| **The Shroud Weaver** (giant spectral spider) | its 8 legs stab down into the 8 lanes, soul-silk webs between the leg segments | **5 (first boss)** | Hangs high above the centre on a glowing thread; cracked bone carapace, cluster of green eyes. Legs crack and bleed light as HP drops; at the end it falls toward the plaza and dissolves before it lands. Spice: shakes the web, every army stumbles back a few studs. |
| **The Hollow Matriarch** (veiled giantess, 8 arms) | a giant skeletal hand plants its fingers in each lane | **4** | Floats above the centre in a tattered veil; fingers twitch and clench, at low HP the hands rise and slam down again. |
| **The Buried King** (crowned corpse on a throne of tombstones) | giant sarcophagi hurled into the lanes, standing upright | **4** | Strongest tie to the grave theme: could drop graves as loot. Less "8 limbs", more throwing walls. |
| **The Death Knell** (cathedral bell rung by a skeleton) | chains from the bell hold an iron wrecking weight in each lane | **3** | Every ring sends a shockwave; great for sound later, less of a creature. |
| **The Watcher Beyond** (giant eye with tentacles) | tentacles in the lanes | **2** | Eldritch, not undead, and the Eldritch grave already uses tentacles. |

Rejected: the boss breaching one gate (armies leave their lanes, messy pathing), a bigger plaza (rebuilds the whole
world, the shop conflict stays).

### Wall rework (before the world boss; discussed 2026-10-14, not final)

Problems today: the walls are stacked rectangles (32 thin slabs 6.4 studs apart), nothing explains why they are there,
and players can swim, jump or walk around them and stand between them.

**The reason: an entity that keeps making walls.** Behind the end of each lane is a god / entity guarding what lies
beyond, and it keeps conjuring new walls to stop the army. The gate at the end does not have to be a gate: it can be
its portal. New walls are spawned as the army approaches; later a cool animation: ghostly hands reach out of the
portal and weave / build the wall with magic. (Open: what the entity is and how its walls look.)

**Walls break in stages.** Agreed: a wall shows its damage (cracks, chunks falling off, half caved in) before it
collapses. Decided: a run is **4 walls with 4 damage stages each** (done in the economy: each wall is the sum of 8 old
layers, sim preset "four"; the stages are not built yet). Fewer breaks are fine because the gold comes from hits; each
break drops more dust, and another dust source is needed later.

**Spawned as the army approaches** (agreed in principle): only the wall being fought and maybe the next one exist; the
entity conjures the next one ahead of the army. This also removes the stacked-slices look and the gaps to stand in.

**Not getting around them:**
1. **Wider walls with flanks** (agreed): the wall reaches past the lane edge with towers / spikes / rubble / pillars
   angled backwards, so it reads as a defence line. The lane side walls stay low (a tall walled road was rejected).
2. **Soul mist behind the front** (agreed): a dense ghostly fog curtain behind the wall being fought; walking or
   swimming into it gently pushes the player back ("The mist will not let you pass"), with player-only invisible
   collision hidden in the fog.
3. **Lava next to the lanes** (agreed): replaces the terrain water between the lanes (`set_water.lua`, place file).
   Default orange-red for now; later the lava colour may change per ascension. Touching it sends the player back to
   their plot with a short burn effect (no death).

**Wall shape** (agreed): the wall must envelop the road, not stand on it like a slab. A crescent bending towards the
army, about 70-80 studs wide against the 40-stud lane, tallest in the middle where the army fights; the wings curve
forward on both sides and step down at the ends into pillars / rubble / spikes that run out into the hazard. Damage
stages crack from the middle outwards, the wings break last.

Next step when we start: one wall type with its damage stages as a test model, the user judges the look first.

### Realms (agreed 2026-10-14)

Ascensions are grouped into **realms**: realm 1 = ascensions 0-4, realm 2 = 5-9, and so on, open-ended (many more
ascensions later without a new theme for every one). Each realm transforms the player's lane: its own entity, wall
style, lane look and hazard. Inside a realm each ascension varies the details (more wear, ornaments, lava colour).
Everyone in the server sees how far each player has come.

**Several realms in one lobby:** every plot owns a wedge of the arena (its lane plus the land halfway to the
neighbouring lanes); the realm only changes that wedge. A **realm veil** (tall shimmering curtain of ghostly mist with
drifting runes) stands on the line exactly between two lanes, from the plaza edge to the outer wall; hazards stop at
the veil. Walking through a veil into another player's realm slightly changes your own screen tint (client only).

**The entity is a titan behind the outer wall** (the user's idea, like the Colossal Titan): behind every occupied
lane the realm's entity stands outside the outer ring, ~150-200 studs tall, upper body over the wall (~70 high),
leaning on it and looking down into the lane. Its hands move slowly (resting on the battlements, pointing, weaving);
when a new wall is needed it summons it: threads of light from its fingers down into the lane, the wall grows out of
the ground. When the gate falls it reels back / roars; after ascending into a new realm the next titan takes its
place. Low-poly (~300-400 parts), client-animated like the units, must stay loaded from afar (streaming persistent).
Several titans around the coliseum = a strong image for clips.

#### Realm 1: The Forgotten Cemetery (approved draft)

- **Entity: the Gravekeeper.** A colossal hooded sexton as the titan: stooped, pale bony hands, a huge lantern hanging
  from one hand above the lane (green-gold light), the other hand weaving the walls.
- **Walls 1-3: cemetery walls in a crescent.** Mossy fieldstone with a spiked iron fence on top (~20 high in the
  middle); the wings carry crooked tombstones, dead trees, roots through the stone, and end in buttress pillars with
  hanging lanterns, then rubble into the lava. Damage stages: 1 fence bends, tombstones topple; 2 cracks with green
  soul light; 3 the middle caves in, lanterns fall; 4 collapse to rubble, wings last.
- **Wall 4, the realm's gate:** a mausoleum wall with a heavy iron double gate, chains and a stone angel on top;
  bigger and taller.
- **Lane look:** dirt path with broken cobblestones, low ground fog, crooked lamp posts, a few graves at the edges,
  dead trees on the wings.
- **Hazard:** orange-red lava next to the lane (colour may shift per ascension or realm later).
- **Colours:** moss green, grey fieldstone, rusty iron, warm lantern gold, green soul light (matches the plots and the
  Mossy grave).

#### The end of a run: the titan's defeat and the portal (agreed 2026-10-14)

- **Defeat (built):** when the gate falls the titan rears back, reaches over the lane once more while his eyes go out,
  and sinks behind the outer wall; his lantern falls into the arena and goes out. **Return (built):** after the
  ascension his hands come over the wall first, then his head, the lantern is pulled back up, he rests again.
- **The portal behind the gate (planned):** when the gate falls the gate tower's sealed door bursts open and the portal
  to the next realm appears behind it. It shows how far the player still has to go (a ring of runes, one per ascension
  of the realm, the done ones lit; text like "2 more ascensions until the Cathedral"). Before that it **rejects** the
  player (a shockwave throws them back, the runes flare): a visible long-term goal. Normal ascensions stay on the Ascend
  button. At the realm's last ascension all runes are lit, the portal opens fully with a glimpse of the next realm, and
  **walking through it is the ascension into the new realm** (its own cinematic).
- On hold: a victory moment when the gate falls (banner, light, pulsing Ascend tile).

Later realms escalate, e.g. the cathedral (the Last Saint), the golden threshold of the living (the Warden), the
spectral choir (the Hollow Choir), the abyss.

Build order (proposal): wall 1 test model (intact stage) -> its damage stages -> gate wall -> lane look + lava +
veil -> the Gravekeeper titan -> summoning animation.

### Making the player matter (agreed 2026-10-14, after a playtest)

Playtest verdict: not fun enough yet. The player has nothing to do but watch, gold has no visible impact (graves are
random, the Forge needs dust), the first pulls are bland, and walls go minutes without any reward. Decisions:

- **Loot at every damage stage** (B): a wall bursts out coins (sometimes dust) at 75 / 50 / 25 %, not only when it
  breaks.
- **Gold is kept through the ascensions of a realm** and only reset at the realm change (sim: practically no change in
  pacing; no friction when ascending; the realm change becomes the big cut). Later the leftover gold is converted into
  **Souls** at the realm change (a permanent currency).
- **No run upgrades** (C is dropped): players would not spend gold on something temporary.
- **Necromancer spells** (A, next big feature): 3-4 spells with cooldowns cast in the lane (Raise Dead: skeletons fight
  for 20 s; Curse: the wall takes +50 % for 10 s; Soul Surge: faster attacks), upgraded **permanently with gold** on a
  growing cost curve: the main gold sink, visible and felt.
- **A better start** (D): a guaranteed Rare (or the first Signature) in the first pulls.
- **The necromancer raises the dead himself** (built 2026-10-14): the grave cinematic shows the player's character
  working dark magic on the grave (raised arms, a necromantic circle, ghostly threads into it) before it shines in the
  rarity colour; after Continue he absorbs the unit into a spectral grimoire. Graves stay the source of units.
- **Codex / compendium (later, wanted):** a book listing every pullable unit (seen / owned, rarity, odds, art), ideally
  the same grimoire the necromancer absorbs units into. Doubles as the collection index from the content table.
- **Items / outfits (NEXT, agreed 2026-10-14; plan below).** Long term: staffs shape the spells, small passives, the Soul
  Wisp as the first familiar; from the Codex, ascension milestones, the Gem Shop, later Souls; NOT a second gacha; small
  stats, big looks.

#### Items / outfits plan (agreed 2026-10-14, not started)

Why now: the player's character is the lead in the pull cinematics and the Codex, so its look matters. Spells do not
exist yet, so items start as **cosmetics (look only)**; effects come with the spells (step 2).

- **Avatars:** players keep their own avatars; the game is set to **R15** (the user changed Game Settings > Avatar;
  the IK poses of the ritual / Codex need R15). Scale ranges stay default unless something breaks. These settings cannot
  be changed through the Studio MCP (locked properties).
- **Three slots:**
  1. **Hand / magic:** staffs, scythes, lanterns, a skull orb, a grimoire. Held in the right hand (or on the back when
     idle); raised in the ritual.
  2. **Head:** hoods, crowns, horns, a skull mask, a halo of soul flames.
  3. **Back** (the flexible slot, chosen because the camera mostly sees the character's back and one attachment point,
     `BodyBackAttachment`, fits almost every body): capes / torn mantles, bone or ghost wings, a gravestone strapped on
     like the titan's, spectral chains, a floating ring of souls, a floating open grimoire.
  - Later maybe a 4th slot: **aura** (particles round the character; robust on any avatar, good for rare items).
  - Full robes were rejected for now (they break on very different body shapes; a mantle/cape is robust).
- **How they are built:** from parts in the game's chunky block style (like the unit models), as models welded to the
  R15 body (hand: RightGripAttachment / RightHand; head: HatAttachment / Head; back: BodyBackAttachment / UpperTorso),
  scaled to the avatar's body size. Items live in ReplicatedStorage (client-visible) or ServerStorage (server attaches,
  replicates).
- **Start set** (dark gothic, Realm 1 colours: moss green, charcoal, bone, rusty iron, lantern gold, soul green):
  e.g. Lantern Staff, Bone Staff, Gravedigger's Hood, a skull mask or crown, Tattered Cape, a strapped gravestone or bone
  wings. Show the user the first 2-3 as models before building the rest (models are approved batch by batch).
- **Wardrobe panel ("Outfits")**, opened by a HUD tile: the character turns to the camera and is shown in 3D (a short
  camera move like the Codex, upright, no overhead swing); slots with owned items, equip / unequip.
- **Server:** owned items + equipped per slot saved per player (PlayerData + Persistence), equipped items attached to
  the character on spawn for everyone to see; sources: Codex page completion rewards, ascension milestones (e.g. the
  realm portal), a few in the Gem Shop (cosmetics only for Robux later, no power).
- **Step 2 (with the spells):** staffs get spell effects, head / back items small passives.

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

### Signature value: they never fall off (decided 2026-10-15)

Problem: a chase Signature from a low rarity becomes useless later (raw damage is always outclassed by higher
rarities) and gets sold. Decision:
- **Specials deal a share of the ARMY's power, not a fixed number:** "X seconds of your whole army's DPS" (e.g. Knell's
  toll = 15 s of army DPS). A Common Signature stays worth having in realm 9, yet it can never be faster than the
  player's own strength (it is a multiplier of roughly +10-20% per Signature). NOT a share of the wall's max HP (that
  would break pacing: stacked Signatures would fell any wall in a fixed time) and not of its current HP (too weak).
- **A small passive aura per Signature,** percentage based (e.g. Knell: +8% attack speed while the bell tolls; Hush: wall
  regeneration halved; Sigilwright: +10% damage to the gate).
- **A cap:** only the strongest few Signatures placed on graves count (e.g. 3), so stacking ten cannot snowball. (2026-10-16: replaced by the commander slot, see "Unit families, the commander slot and placement".)
- Later, on top: a commander slot (one Signature whose aura leads the army), Mastery (below). Rebalance the existing
  Signatures (Knell, Hush, Sigilwright, Malak's specials) with the economy simulator when we get to it.

### Gacha direction (discussed 2026-10-15, not decided; the user liked these takes)

From the user's "general ideas.txt" (switching to a star / banner system with few pulls):
- **Keep frequent pulling** (pillars 1 and 2; the Roblox audience expects to roll often; a low-volume banner gacha
  needs gear / stats depth to spend on between pulls, which is out of scope).
- Borrow from banner games: a **featured unit** per grave or realm (rate-up, a clear chase), **hard pity** on the top
  units (guaranteed after N pulls, maybe a 50/50 on the featured one). Rarity names stay (they carry the tone); stars
  could be shown as display only.
- Graves going obsolete is normal for the genre; give old graves a reason: **each grave tier has its own exclusive
  Signature**.
- **Mastery:** maxing a unit (Lv 10, the shadow form) leaves a small permanent account buff (stacks, fits the Codex).
  If Forge success chances are lowered, failures should build progress (fragments towards a guaranteed success)
  rather than simply removing the pity.

### Unit families, the commander slot and placement (2026-10-16; families OK'd by the user, numbers open. BUILT: the family data + bonuses (server), the commander thrones (2nd for 500 gems), family-aware Place Best (`Army.bestLineup`: best DPS with Flesh and the Beasts' burst at 25% uptime, swap search). BUILT too: the Army screen (`ArmyPanel`, tile + R), the Codex family card, the unique traits of all four commanders)

Problem: DPS is the only reason to pick a unit, and Place Best makes even that choice for the player. Goal: a reason to
keep, level and place weaker units, and a real decision when building the army, without forcing anyone to micromanage.
Model: **Teamfight Tactics traits** (Riot): shared traits that grow in tiers, plus unique traits for the special units.

**Families (TFT traits).** Every normal unit belongs to one family. Placing units of a family on graves activates its
bonus in tiers at **2 / 4 / 6**. Rules (decided by the user):
- **Duplicates count once** (two Skellys = one Bones), like TFT: it rewards collecting different units.
- **A unit in its shadow form (Lv 10) counts double**: a reason to level, and three shadow units can reach the top tier.
- With 5-10 grave slots: two small sets, or one big one plus singles.

| Family | Units |
|---|---|
| **Bones** | Skelly, Hollow Archer, Baron Bone, Bone Colossus, Dread Knight, Skeleton King |
| **Flesh** | Zombie, Ghoul, Plague Doctor, Abyssal Titan, The Undying |
| **Spirits** | Wraith, Banshee, Soul Eater, Shade Lord, Death Reaper, Last Lantern |
| **Beasts** | Crypt Spider, Crypt Bat, Shadow Hound, Eldritch Fiend |
| **Arcane** | Lich Acolyte, Lich Lord, Void Walker, Mind Shatterer, Death Incarnate |

**Family bonuses (first numbers, to tune with the simulator):** only ONE family is plain damage; the others are
SITUATIONAL, so a perfect Place Best (which scores DPS) gives a good all-round army and a thinking player does better.

| Family | 2 | 4 | 6 | Kind |
|---|---|---|---|---|
| **Flesh**: the horde | Flesh units +10% damage | +25% | +45% | plain DPS (Place Best counts it) |
| **Bones**: the siege | +10% damage to the gate (whole army) | +25% | +45% | the run's end |
| **Spirits**: the harvest | +10% gold from hits | +25% | +45% | economy, not DPS |
| **Beasts**: the pack | Beasts +30% damage for 8 s after a wall stands | +60% | +100% | burst on every fresh wall |
| **Arcane**: the rites | the commanders' specials charge 10% faster | 20% | 35% | commander synergy |

**The commander slot (Signatures and Sovereigns).** Signatures and Sovereigns have NO family. They go only into a
**commander slot**: one slot for everyone, a second one bought with gems (price open; maybe a third later from realm
progress). The commander slot is a grave of its own, clearly set apart on the plot (a raised throne-grave / dais with
its own glow, at the head of the graves). This replaces the old "only the strongest 3 Signatures count" cap.

**Unique traits (TFT unique traits).** Each Signature / Sovereign carries its own trait, named after its TITLE (decided by
the user: no extra names), shown like a family, with its own effect (it is the unit's passive on the Codex page; the
passive card is then named after the title too, e.g. Malak's "Envoy's Command" becomes "The Envoy"). Proposals:

| Unit | Unique trait | Effect (proposal) |
|---|---|---|
| **Malak** | **The Envoy** | his drone fires its own volley; the whole army +10% damage (built) |
| **Knell** | **The Mourning Bell** | while its bell tolls (its special), the whole army attacks 10% faster |
| **Hush** | **The Unbreathing** | the army deals +15% damage to walls below half HP |
| **Sigilwright** | **The Last Word** | its Verdict marks the wall: the army deals +20% damage to it for 10 s after the Verdict |

(Hush's planned "wall regeneration halved" is dropped: wall regeneration is 2-8 HP/s against millions of HP, it does
nothing. The Sigilwright's planned "+10% damage to the gate" is dropped: the Bones own the gate.)

**Place Best stays** (idle players, mobile), but becomes family-aware: it fills the commander slot(s) with the best
Signature / Sovereign and the graves with the lineup of the best total DPS, counting Flesh and the Beasts' average (10
slots and 5 families is small enough to try the sensible combinations). It ignores gold, gate and specials on purpose:
that is the room left for the player ("I am about to push the gate: swap in Bones").

**A placement screen** (in-world, like the Codex / Outfits): the camera rises over the plot, the graves and the commander
throne light up, the inventory slides in; tap or drag a unit onto a grave; the active family tiers show live like TFT's
trait list ("Spirits 4 / 6: +25% gold"). Place Best is a button on it. The Codex unit page shows the unit's family (or
unique trait) and its tiers.

**Later (the user, 2026-10-16): units with MORE THAN ONE family, like TFT** (e.g. a Bones + Arcane lich), most likely
for the rarer units, so a rare pull can complete two sets at once. The data allows it with little change:
`Units.FamilyOf[unit]` becomes a list, `familyCounts` counts the unit for each of its families (duplicates still once,
the shadow form still double), and the Army screen / Codex show one line per family.

**Still open:** the bonus numbers, the second commander slot's price, how the commander throne looks. (The unique
traits are built: Knell +10% army damage while its bell tolls, Hush +15% against walls below half HP, the Sigilwright
+20% for 10 s after the Verdict, Malak +10% and his drone.) **Suggested order:** (2) family + trait data in Units.lua, the bonuses and the commander slot on the server
(saving it), (3) family-aware Place Best, (4) the placement screen and the commander throne on the plot, the Codex line.

### Content / depth (already in the backlog)

| Idea | Score | Notes |
|---|---|---|
| Mutations (2-5 % at pull time) | **4** | Late-game chase, more rare moments, good for clips. |
| One Signature unit per tier + the guaranteed early Signature | **4** | Strengthens the core pull moment. |
| Collection index | **4** | Cheap, gives every pull meaning. |
| New-player tutorial / gradual unlocks | **5** | Needed before any growth push. |

### The Soul Broker (gem stall, agreed 2026-10-16)

Replaces the old Sell stall (selling lives in the inventory only) at plaza angle 142.5; the old Upgrade stall's spot
stays empty. **The look:** a hooded merchant behind a counter and a gallery wall of four ornate gilded portrait frames
behind him; BIGGER and MORE DETAILED than the old stalls (the user's call), at least on the level of the grave shop and
the Forge. Each frame is a "living painting": the offer turning slowly in 3D (potion, catalyst, dust crystal, unit)
with a gem price badge, a red "-20%" sale ribbon (the saving against the deal's `worth`) and the stock left. On the hour the paintings burn away in soul fire and the new ones paint themselves in, seen by
everyone in the plaza. Walking up opens a WorldView in front of the gallery (like the Forge); click a portrait to buy.
**The Broker IS the Gem Shop** (the user's call, 2026-10-16): one shop, tabs **Deals** (the portraits), **Wares** (consumables:
the catalysts), **Unlocks** (permanent: Remote Forge, Wisp speed, second throne) and **Skills** (unlockable skills and finishers:
Fleet Strike now, the necromancer's spells later). At the stall the wares stand as REAL OBJECTS on the counter and
shelves (catalyst jars, a little anvil for the Remote Forge, a caged soul for the Wisp, ...), clicked in the in-world
view; the Shop tile opens the same shop as a plain panel anywhere.

**Rules** (shared `BrokerDeals`, server `Broker`): global rotation every hour (every server computes the same deals from
the clock, amounts / tiers scale to the player like the wheel); stock per player per rotation, depending on the deal,
saved (`profile.broker`). Portraits: **Bundle** (5 Fortune for 120 / 5 Warding for 80 / 20 top-tier dust for 40; 2 each),
**Potion** (1 Luck Potion for 25, stock 3 / three for 60, stock 1; potions are sold only here and won on the wheel),
**Featured** (big centre frame: a unit from your highest grave one rarity above its pity rarity, never a Signature or
Sovereign, priced by rarity (Rare 40 .. Primordial 1000 Gems) so digging stays cheaper per unit; stock 1),
**Curio** (Grand Dust Hoard 80 dust for 150 / Seeker's Kit 2 potions + 2 Fortune for 100; exclusive cosmetics join it
once they exist). Prices are first drafts: check them with the sim.

**Order:** 1. rules + data DONE 2026-10-16; the Gem Shop panel with the Deals / Wares / Unlocks / Skills tabs DONE (Shop tile, the
stall's prompt, DEV "Broker"); 2. the stall model with the portrait wall BUILT (`build_broker_stall.lua`, user to review); 3a. the portraits painted per player (client `BrokerPortraits`: SurfaceGuis in PlayerGui on each `Canvas`: the featured
unit turns in 3D, the rest show their icons; gem price badge, sale ribbon, stock line, SOLD OUT stamp; the brass plates
were dropped for the badge, the featured frame raised above the broker's hood) DONE 2026-10-16; 3a+. the broker comes alive (client `BrokerKeeper`, the user's idea: wanders behind the counter doing comic bits:
potion held to the light, gem polishing, playing the scale, dozing and startling awake, admiring the featured portrait,
drumming his fingers; head follows a nearby player; the prompt calls him to the counter and the shop opens when he
arrives) DONE 2026-10-16; 3b. the in-world view DONE 2026-10-16 (agreed with the user: like the Forge, the camera glides to the counter, the
stall fills the left, the normal Gem Shop panel stands on the right at once while the broker walks over; hovering a
portrait gives it a gold rim, a click opens the view if needed and highlights that deal's card; the Shop tile keeps the
plain panel anywhere); **Outfit of the Day** (agreed 2026-10-16, built): one themed outfit SET (Head + Back + Hand) a day for everyone (new at
00:00 UTC, shared `OutfitSets`, picked from the clock), worn by a mannequin on a pedestal at the stall's front left
(server `OutfitOfTheDay`, `Outfits.dress`), sold in the Gem Shop's **Outfit** tab: each piece (150 Gems unless the item
has a `price`) or the whole set at 80 % of the missing pieces (`BuyOutfit(what, day)`). Only sets whose pieces all have
models are offered; the collection (`OutfitSets.SETS`) is added later, Studio offers a test set of the starter pieces
meanwhile. The two candelabras and the big gem chest made room for the pedestal.
3c. the wares as real objects DONE 2026-10-16: only what you buy again and again (the user's call: one-time unlocks
stay in the panel): a gold-green Fortune jar and a blue Warding jar on the counter (`Ware_<key>` models, client
`BrokerWares`: gold outline on hover, a click selects the card in Wares); the burn-and-paint rotation is parked for later; 4. cosmetics in the Curio.

## 5. Suggested order (when we get there)

**Lucky Wheel rewards agreed and implemented 2026-10-16:** progression-scaled Gold Chest, Grave Hoard and Dust Cache;
Gems; a Luck Potion the player saves and activates; Fortune Catalyst bundle; a wheel-exclusive Spectral Crown jackpot.
Repeated crown wins convert to Gems. Crown modelling is postponed (spectral bone, slowly orbiting fragments); the
permanent outfit unlock saves now and becomes wearable once its model is built. Full odds/rules in `docs/features.md`.

1. Rare-pull broadcast, server luck (free meter first, Robux later), luck potions from wheel / quests.
2. Friend boost, monument leaderboard, plot statues.
3. Tutorial and gradual unlocks.
4. World boss: the sky boss with limbs in every lane; later the arena outside the ring.
5. Run upgrades + Souls (sim first).
6. Game passes and gem packs (after the odds disclosure check).
7. Async ranked arena, events with limited units, mutations.
8. Session locking, then trading.
