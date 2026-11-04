# Backlog, state and open issues

Read the newest state first. Older session logs were folded into the lists below (what was built is in git history
and in the feature docs: `docs/features.md`, `docs/envoy.md`, `docs/world.md`, `docs/models.md`, `Design.md`).

## Hush, the Unbreathing (2026-11-04 / 05: now a Sovereign, his finisher built end to end; details in docs/hush.md)

**Done (first pass, in two commits):** the gate finisher THE LAST CROSS (~59 s, `HushFinisher.lua` + shared
`HushTimeline`): he floats up with the glow and the first lightning already during the rise, his head snaps, five huge
rifts open behind him, huge chains swarm out, a solid stone cross floats up out of a rift in the lane floor, the chains
wind themselves round it (criss-cross lacing), fully wrapped it topples onto the gate like a felled tree, the ravine tears
open at the hit, runs back down the lane and up the gate tower; he floats down. Server: registry entry, saved unlock
(`lastCross`, 1000 gems provisional), Gem Shop item, remotes, DEV preview (`Anim: Last Cross`). The **real trigger was
tested** in Studio (gate under 20 % -> the server logged it, every client played it, the gate was held and broken at
`GATE_HIT`). The **promotion**: `sovereign = true`, title "The Unbreathing", Primordial, Celestial grave only, weight 0.05
(1 in 56,000 like the other three), 85K DPS; his Codex page gets the Sovereign label, the COMMANDER badge, the title and
the finisher ability with its unlock without further code.

**Open for Hush (in this order of importance):**
1. **Sounds**: thunder, chain rattle, the cross rising, the impact, his mask breath (no voice). Files come from the user.
2. **The user's review of the whole finisher** (not yet seen in full by them): the face glow is a flat purple silhouette at
   the snap peaks, the swarm passes very close to the camera (huge slabs fill the screen), the scene is dark overall, how
   much stone should show under the chains.
3. **A white frame** appeared a few times in the preview (once at the impact flash, probably Bloom 0.8 on the neon, once
   at ~58 s that could not be reproduced); the flash was weakened afterwards. Look again with the real thing.
4. **Not checked at all:** the first frames of the ravine after the hit and the climb up the tower in motion, a rotated
   plot (everything was only run on plot 1: the geometry uses `PlotFrame`-style vectors but nothing proves it), a real
   throne (the test used a dev Hush), a second client watching (Watch / Leave), frame rate with a real army (about 2000
   parts, ~1300 moved by one `BulkMoveTo` per frame), the shadow form (level 10), what spectators see of the staff...
5. **His own pull cinematic** (he gets Malak's ship, which does not fit a gas-masked child), then the economy sim (he is
   a Primordial now), the unlock price, a Gem Shop card.
6. The preview moves a near gate out to 240 studs; the real gate is the last wall. If the real lane is ever shorter than
   ~240 studs the cross's size clamps (100-150) but the camera shots were only tuned for 240.

**The necromancer's basic attack (restart, 2026-11-04):** a first visual try (hold F, a soul wisp from the Lantern Staff,
IK arms, a closed-loop grip turn) was written, reviewed by the user ("looks horrible": the staff pointed its butt at the
wall) and fully REVERTED at their request, nothing of it is in git. Agreed so far: the attack depends on the equipped
weapon (the weapon slot of the existing outfit items; cosmetic for now, the Lantern Staff is the default), you hold a
button, it auto-aims at the wall while you stand on your plot, auto-attack unlocks later, the upgrade track comes after
the animation and VFX are good. **Learned:** the staff is built along the forearm, so it only looks right hanging at the
side; IK cannot reach the hand's orientation (position works), the grip can be turned through the staff's own
`RightGripAttachment` (the accessory is held by a `RigidConstraint`, not a weld); the Lich Acolyte's cast stance
(`UnitAnimator.castPose`: staff out level at the wall, an `RStaff` joint) is the look the user wants to copy.

**Tooling notes from this session:** Rojo's Studio plugin silently stops syncing now and then (the file on disk is right,
Studio keeps the old copy; reconnecting the plugin fixes it, so always check the script's length in Studio before
testing); screenshots through the Studio MCP arrive up to ~5 s late and unevenly (time the wait, expect to miss frames);
`execute_luau` `require` gives fresh module instances (a module's own state is not the running game's).

## Orvoss, the Blackwake (2026-10-17: model + idle animation done and approved; details in docs/orvoss.md)

Committed 04591f8: the idle (`AdmiralAnimator`, Pose "Admiral": deck roll, level skull, underwater coat tails, heavy
weapons, gestures brim push / listening / compass glance; dev attributes `DevGesture`, `AnimTimeScale`), a
`CompassNeedle` joint, a normal weapon hold (both weapons down and forward at his sides) and fixed fists (palm outside
the grip, the pistol's index finger curled). The user approved it. `Workspace.OrvossPreview` is still in the place
(delete before publishing; tag it `ProceduralUnit` on the client in play mode to see him animate).

**Later on 2026-10-17 (all committed):** his heavy walk; the basic attack DOUBLE REPORT (flintlock + ghost cannon at his
left, `DoubleReport.lua`, `AdmiralTimeline`; `Army` now sets `AttackAt` on every attack); the fleet (5 warships), the
flagship and the anchor + chain (`build_blackwake_fleet.lua`, `build_blackwake_anchor.lua`, `ReplicatedStorage.ShipModels`;
the previews were deleted from the place: **save the place file**); the finisher THE LAST BROADSIDE stages 1-3
(docs/orvoss.md "Build state"); his first sounds (`sounds/orvoss/`, `Sfx.lua` orvoss_*).

**Next for Orvoss:** 1) **the finisher at a real gate: the ships clip through the outer wall** (the user's note; ideas in
docs/orvoss.md "Build state"); 2) the rest of the finisher: his poses, the drag + whirlpool, the gate break, the voice
line "Give them the deep.", the missing sounds, a Gem Shop card; 3) a real 20 % trigger, other players watching; 4) his
special, his pull cinematic, the shadow form.

**Earlier order (done):** 1) DONE (unit def, see docs/orvoss.md "Status"; the user still has to look at the
portrait / walk / Codex page) his unit def (Sovereign, throne only, pool weight like Malak/Veyr, Codex, check
the portraits and the army walk); 2) his basic attack, idea from the user (docs/orvoss.md "Basic attack"): he aims and
fires the flintlock while a ghost cannon forms beside him and fires at the same moment; open: the cannon's side
(suggested: his left, a little behind) and the name (not "Dead Reckoning"). Later: the special, the pull cinematic, the
finisher The Last Broadside (models needed: flagship, fleet warship with variants, anchor + chain; reuses the ghost
cannon), sounds, the shadow form.

## Veyr, the Last Sight (2026-10-17: done but for sounds; details in docs/veyr.md)

Built and committed: base + shadow models, `MarksmanAnimator`, basic shot + the mark, the special The Long Goodbye, the
overwatch perch, the finisher The Final Horizon (voice lines "One round. That is all you deserve." / "Bang.", the camera
cut into the scope instead of the face close-up, no turning his back: it ends on a slow reload in close-up, the gate
turns to ash stone by stone from a glowing pinhole instead of the black hole), the pull cinematic A Sight Beyond the
Grave (`VeyrArrival`, routed by `SovereignArrival.ARRIVALS`; his echo shoots his own grave open, a field of 26 echo
glints, skeletal hands tear the slit open, eyes ignite + ring + mantle flare + shards click in, his line "Death is just
the distance between us."; nearby army units are hidden on this screen), pool weight 0.05 like Malak (each Sovereign
now 1 in 52,000), Gem Shop Skills card + Codex abilities, damage tuned to Malak's level (700K / 7.5 s, special 24
army-seconds). Voice files trimmed with `tools/audio/prep_sound.py shot` and uploaded with `upload_sound.py`.

Sounds (2026-10-17, d4212a4): all 23 of his sounds are in (the user collects them on Splice; Claude trims with
`prep_sound.py`, uploads with `upload_sound.py`), the finisher's cue sheet tuned with the user (see docs/veyr.md "State").
Remember: after a Studio restart check that Rojo is connected (a whole round of "no sounds" was an unsynced Studio).

**Next for Veyr:** `cracks.ogg` for the crack web on the gate (still silent), maybe a real ~9 s build-up instead of the
slowed 5.1 s one, volumes of the basic shot / special / pull sounds (only the finisher was tuned), then the checks nobody did: two Veyrs on one plot, a rotated plot, a second player (Watch / Leave, the RarePull banner), Malak +
Veyr on both thrones (the first throne's finisher wins), a real pull from a Celestial grave. His shadow form is still a
first look.

## State at the end of the 2026-10-16 session (read this first)

**Second 2026-10-16 session (all committed):**
- **Lucky Wheel rewards** reworked (with Codex): Gold Chest = 10 minutes of the army's hit income (was 3x the top grave's
  price, which outgrew late income), stored Luck Potion (used in the grave views only), 75 Gems, Grave Hoard (3 graves
  of the top tier since the balance pass), Dust Cache, Fortune Catalysts, Spectral Crown unlock (model deferred by the
  user). Dev "+10 Spins" button. Sim: `--wheel`.
- **Plaza**: the Sell and Upgrade stalls are gone (`ServerStorage.RetiredPlaza`); selling lives in the inventory.
- **The Soul Broker** (Design.md "The Soul Broker"): the gem stall at plaza angle 157.5 (`build_broker_stall.lua`) IS
  the Gem Shop (tabs Deals / Wares / Unlocks / Outfit / Skills; the Shop tile opens it anywhere). Hourly global deals
  in four painted portraits (`BrokerDeals`, server `Broker`, client `BrokerPortraits`: featured unit in 3D, gem badge,
  sale ribbon, stock, SOLD OUT), clickable; the catalyst jars on the counter are clickable wares (`BrokerWares`); the
  broker is rigged and walks round doing comic bits, then serves at the counter (`BrokerKeeper`); "Talk" opens an
  in-world view like the Forge (`GemShopPanel.openAtStall`).
- **Outfit of the Day**: one set (Head + Back + Hand) a day for everyone (`OutfitSets`, server `OutfitOfTheDay`), worn
  by a mannequin on a pedestal at the stall, Outfit tab (pieces or the set at 80 %), the camera pans to it. The
  collection is empty: add sets to `OutfitSets.SETS` (Studio offers a test set of the starter pieces meanwhile).
- **Balance pass** (docs/economy.md): late grave prices flattened (Abyssal 40M .. Celestial 120B), wall HP steps
  retuned (14, 10, 3, 14, 4, 5.5, 6.5, 6, 5): every stage within target in the sim, all nine ~35 h with the wheel.

**Untested / to check (second session):** the new HP steps and grave prices in a real playtest (the first wall after
ascensions 1 and 4 is x14 tougher); buying a deal / ware / outfit piece with real clicks; the outfit camera framing
(pulled back after the last screenshot); the broker's comic bits one by one; a real outfit set (only the test set,
which everyone owns). **Save the place file** (the stall rebuilds, retired stalls, pedestal).

**Built and committed today:**
- **Ascension cinematic** reworked: the rite happens at the fallen gate, the grimoire draws the army in (like a pull),
  labels hidden, a still side shot. DEV panel: **Break all** (every wall incl. the gate), **Unlock Codex**.
- **Keeper's hands** lifted off the parapet in the Defeat / Fleet Strike retreat (no more fingers through the wall).
- **Empty plots** in the plaza's look (balustrades, skull piers, bone arch, sealed ledger stones, obelisks, mist; hidden by
  `PlotLook` when claimed); the spawn point is a **summoning circle** (turning glyph band + hexagram); corner lamp posts
  retired; rose windows lowered, gate doors in front of the tower plinths.
- **Malak**: shadow form (`build_malak_shadow.lua`); **his special, the Requisition** (dial on his hologram, supply pod,
  dispenser, 6 drones for 25 s of army DPS, recall, tractor beam; waits while walls rise; cut by Fleet Strike / ascension);
  aura +10% army damage; quieter aiming beeps, his line starts as the pod opens.
- **Other players** see rare pulls: the `RarePull` banner for Signatures / Sovereigns, and **Malak's arrival plays in their
  world** with Watch / Leave (`ArrivalStarted` / `ArrivalShow`, server-checked).
- **Codex unit page**: animated 3D portrait, stats, description / lore, family badge (hover: tiers), ability cards
  (unique trait / basic attack / special / finisher, numbers highlighted, locked ones with Unlock), base / your damage toggle.
- **Families** (TFT-style traits, Design.md "Unit families, the commander slot and placement"): Bones / Flesh / Spirits /
  Beasts / Arcane, tiers 2 / 4 / 6 (duplicates once, shadow form double), bonuses on the server.
- **Commander thrones**: Signatures / Sovereigns only on a throne, normal units only on graves; a second throne for 500
  gems (sealed until bought); unique traits named after the titles (Malak, Knell, Hush, Sigilwright).
- **Place Best** is family-aware (best DPS with Flesh and the Beasts' burst, swap search).
- **The Army screen** (tile + R): in-world view over the plot, families like a TFT trait list (hover tiers), commanders
  (hover: unique trait), inventory strip to place / recall, Place Best.

**Untested / to check:**
- Knell's and the Sigilwright's traits live (only Hush's was measured); buying the second throne; the call-in dial's arm
  angles; the base / your damage toggle view; clicking graves in the Army screen with real clicks.
- Malak's shadow form in play (some effects may set blue colours at runtime: hologram, orbital laser, drone volley).
- A real two-client Sovereign pull (the arrival for other players was only tested with a faked show).
- **Save the place file** after the Studio changes (plots, rose windows, gate doors, `Malak_Shadow`, retired lamp posts).

**Next steps (agreed order):**
1. **Necromancer spells** (design WITH the user): the necromancer's own basic attack always damages the wall (also the
   fix for the no-units softlock), then 3-4 spells with cooldowns (ideas: Raise Dead, Curse, Soul Surge), upgraded with
   gold on a growing cost curve. Design.md "Making the player matter".
2. The Signatures' specials still deal a share of their OWN damage; the rule (Design.md "Signature value") says seconds
   of the ARMY's DPS like the Requisition. Rework Knell / Hush / Sigilwright.
3. **Gem sim** (the user parked it): model gem income (wheel, quests) and the Broker / featured unit / outfit prices.
   The sim also does not model families, commander traits or Malak's swarm yet (the balance pass tuned grave prices
   and wall HP without them).
4. A better start, a pacing playtest. Polish: a grander commander throne, a real Army tile icon.

## Agreed for later

- **Soul Broker later**: the burn-and-paint rotation on the hour, outfit pieces as Curio deals, a real outfit
  collection, maybe a small warship for Fleet Strike.
- **Soul Well reactions** to rare pulls / ascensions on the plaza (the `RarePull` remote exists now), **leaderboard
  obelisks**, plaza ambient sounds (need files).
- **Luck rework**: luck (`luckFactor` in `Rolling.rollRarity`, up to x3) multiplies every rarity from Rare up by the same
  factor, so in graves without Common / Uncommon it changes nothing and never lifts a top rarity against a Rare (Malak:
  ~1 in 814 pulls in the Celestial grave with or without max luck). Idea: boost the rarities above each grave's most
  common one, more for rarer ones (capped). Check in the sim, decide with the user.
- **A better start**: a guaranteed Rare (or a first early Signature, a Rare designed with the user) in the first pulls.
- **Gacha direction** (Design.md, discussed, not decided): featured unit per grave, hard pity, an exclusive Signature per
  grave tier, Mastery for maxed units.
- From the user's `general ideas.txt`: a small 3D unit over a magic circle on its grave (Malak is 750 parts: needs a
  simple copy), the portal visible behind the gate before it falls, no reveal overlay after single grave cinematics.
- **Attack kit for the standard units** (on hold): 4-5 reusable attack styles + hit effects, scaled by rarity; a proposal
  per unit, approved batch by batch when the user picks it up.
- A crypt-opening effect outside the ascension cinematic; the realm's last ascension through the portal (own cinematic,
  when realm 2 exists); realm 2 "the Cathedral"; the world boss (the full Gravekeeper, the Shroud Weaver idea).
- Souls (leftover gold at the realm change), items from Souls; mutations at pull time (late game).
- Restyle the remaining old panels (shop, quests, ascend confirm, sell, currency display, hotbar frame), wall
  nameplates, a tutorial, offline / daily rewards; Robux gem packs only after the odds-disclosure check.
- A pacing playtest with a normal army (the sim does not model the ~9 s keeper stun per wall).

## Known issues / small things

- Icons are placeholders: Army (Graves icon), Upgrades, Shop (Gems), Forge (Gold Dust), Codex (Inventory), Outfits
  (Ascend). Ids in `Theme.Image.Icon` / `Theme.Image.Dust`.
- The Lucky Wheel model is weak (rework); one spin server-wide at a time (others rejected for 5 s).
- Outfits: not checked in the ritual / Codex poses, on R6 or unusual avatars.
- The Forge in the world was never run end to end with real clicks.
- Basic-attack sentences in the Codex are generic for units whose models are unclear (Baron Bone, Plague Doctor, Skeleton
  King, ...): ask the user what they really do.
- Not tested in game from earlier: buying the Remote Forge, catalysts on failed upgrades, tall units leaving graves.
- **Postponed by the user** (do not start unprompted): StarSummon / SignatureDescent for the new grave opening styles,
  more opening effects for higher tiers.
- `tools/audio/make_whistle.py` is untracked (its whistle sounded off): ask whether to delete it. The Open Cloud key in
  `tools/audio/.roblox_api_key` was pasted in chat once: remind the user to revoke it when the sound work is done.
- **User's own uncommitted files**: `Unit ideas.txt`, `general ideas.txt`, `sounds/impacts/`, `sounds/magic/`,
  `Images/Concept/` (leave them alone).
- Watch part counts: empty plots ~3300 for all 8 (the summoning circles ~950), cemetery walls ~350, gate ~354, lane
  ~400, plot look ~286, Malak 758.

## The user's preferences (for every feature)

- Small steps, batch by batch, approved as they go; short replies that say plainly what is untested.
- Dark gothic, no emojis in the UI, never "cute". In-world panels are loved (Codex, Outfits, Forge, Graves, Altar, Army).
- Animation: smooth, momentum-driven, nothing snaps back to rest (Knell's block in `UnitAnimator` is the model).
- Specials must feel worth waiting for: big, readable, much harder than basic attacks. Sovereigns may clearly outclass
  Signatures.
- Reuse existing sounds; say when a new sound is really needed.
- The user tests in their own Studio and resets the test save freely ("just reset my save").

## Before publishing

Save the place (the world, unit models, `ReplicatedStorage.UnitModels` live only in it), run
`tools/studio/publish_unit_models.lua` after unit model changes, make sure no preview folders are left in the workspace,
File > Publish to Roblox, set the experience Private / Friends for testers.

## Discarded

- **Pale Sovereign (unicorn)**, dropped 2026-10-13 (`build_palesovereign.lua` removed, in git history: commit 16c8054).
- **Malak's rail lance** (a sniper shot), replaced by the Requisition 2026-10-16: a sniper-themed unit comes later.
- Hush's "wall regeneration halved" and the Sigilwright's "+10% damage to the gate" auras: regeneration is 2-8 HP/s
  against millions of HP (it does nothing), and the Bones own the gate.
