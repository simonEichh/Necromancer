# Backlog, state and open issues

## State at the end of the 2026-10-15 Malak session (read this first)

**Built and committed:** formation spacing; **Malak, the Envoy** (first Sovereign; model + drone, idle, orbital tag
basic attack with the big hologram, drone volley as a generic `companion`, z-fighting fixed); **the Absolution** ship
model; **the Fleet Strike** finisher cutscene steps 1-7 (frame, Malak's beats, warp-in, scan + barrage, cannon on the
realm keeper + gate falls, ending with the ship lingering, real gameplay: 1000-gem unlock, trigger at 20% gate HP,
everyone sees it, Watch button). Design notes: docs/envoy.md (everything about Malak), Design.md "Signature value"
(decided) + "Gacha direction" (discussed).

**Committed 2026-10-15 (evening):** the Settings panel (Master / Effects / Music, saved), Malak's attack sounds, the
Fleet Strike sounds + music, the sky scene at SKY_SCALE. Sound files: the game versions (`sounds/malak/`) are in git,
the originals (`sounds/_source/`, git-ignored) and the .wav drafts in `impacts/` / `magic/` are not.
`tools/audio/make_whistle.py` is still untracked (its whistle sounded off): ask whether to delete it.

**Next steps (agreed / open):**
1. **Fleet Strike sounds:** the user is making them; they drop files into `sounds/malak/` with the names in
   sounds/README.md (Fleet Strike table) + optional `fleet_music.ogg` (54 s cue, plan in the README). Adapt lengths
   with prep_sound.py, upload (upload_sound.py), add ids to Sfx.lua, wire them into FleetStrike.lua at the beat times.
   `shell_whistle` slot is empty (waits for a real one). **2026-10-15: the first 13 are in and wired (cue sheet = "Step 8"
   in FleetStrike.lua, list in sounds/README.md); second batch (missiles, bow, reactor, charge, beam,
   roar, gate, warp_out) in too; the tear in (3 files), the barrage uses cannon_far + shell_impact;
   the music in (first try, cut to 52.5 s, not fitted to the beats). Not yet heard in play by the user.**
2. Malak still open: rarity / pool weight (now weight 0 = DEV only), real damage numbers, the Sovereign class look (name
   style, "Sovereign" on reveal / tooltip), the rail lance skill (special), shadow form (lv 10).
3. Signatures rework per Design.md "Signature value" (specials = seconds of army DPS, small auras, cap of 3).
4. From "general ideas.txt" (discussed, not started): small 3D unit over a magic circle on its grave (Malak is 750
   parts: needs a simple copy), the portal visible behind the gate before it falls (remove the door), no reveal
   overlay after single grave cinematics, Mastery for maxed units, gacha direction (featured unit, hard pity).
5. Small: the user mentioned the Fleet Strike camera is fine now.
6. **Fleet Strike draw distance (found 2026-10-15):** the ship (~800 studs from the camera) and the portal (~900) are not
   drawn at lower graphics quality (Automatic drops it when the frame rate dips: the portal "spawns late or not at all";
   on low-end phones the whole sky part is missing). Measured in Studio (neon parts, size does not help): Level 1 draws to
   ~300-350 studs, Level 5 ~400-450, Level 10 ~700, Level 21 1000+. Fix: bring the whole sky scene in and scale it down by
   the same factor (ship model, SKY_HEIGHT / SKY_SIDE / SKY_LEFT, PORTAL_RADIUS, the tear's vortex, beam / projectile
   lengths), so it looks the same but sits inside ~300 studs. **Done (untested by the user): `SKY_SCALE = 1/3` in FleetStrike.lua
   (the ship is `ScaleTo`'d, projectile speeds scaled so flight times stay, beam width x0.6 = `BEAM_WIDTH`).**
   **User (2026-10-15): fine that it is closer, but the ship should look a bit BIGGER.** Options: scale the ship on its
   own (e.g. a separate SHIP_SCALE ~0.4-0.45 while the distances stay at SKY_SCALE 1/3: check it still clears the
   portal, the ship-relative offsets in warpIn / barrage / finale use SKY_SCALE and would need SHIP_SCALE), or tighter
   lenses (lower FOV) in the warp-in / barrage camera keys. Keep it within ~300 studs of the camera.
   **Done: `SHIP_SCALE = 0.55` (65% bigger than 1/3; measured in play: 263 studs long, was 160, ~244 from the camera) for the ship and every offset measured on it; PORTAL_BEHIND is
   ship-sized too so the stern clears the portal. The sky positions, portal and vortex stay at SKY_SCALE.**

## State at the end of the 2026-10-14 / 15 session (read this first)

**Built and committed (in order):**
- **Graves in the world** (`GraveScene`): owned grave tiers rise in an arc in front of the player; Open hands the grave
  straight to the grave cinematic (`GraveCinematic.fits` shared stage checks). Falls back to the plain panel.
- **The Soul Altar** (realm upgrades in the world): a bone-bridge island beside every claimed plot (`build_altar.lua`,
  `PlotLook`), braziers burn with the realm upgrade levels (`AltarFx`), the Upgrades panel opens at the altar
  (`AltarScene`), permanent upgrades are "written into the tome" (a rite).
- **Batch dismantle** (Forge "Dismantle" tab, list of the units it takes) and a **50 % dust refund** for upgraded units.
- **CLAUDE.md shortened**: details moved to `docs/` (world, models, economy, features, backlog). `AGENTS.md` points Codex
  (which also has the Studio MCP) to the same docs.
- **The realm keeper as hands**: the titan is hidden; two torn rifts behind each lane's end with his forearms and hands,
  his eyes in black fog (`build_titan_hands.lua`, `HandsAnimator`), idle + every behaviour. The full Gravekeeper model
  is kept for a future world boss.
- **Knell reworked** (red and black, own belfry, a Kamehameha throw with a manga-style blast, special **The Procession**:
  pallbearers, chained coffin, a black-red claw raking the wall, a lingering void tear) and the **Sigilwright's special
  The Verdict** (a sentence of huge rune circles, stars slotted in, words burst into fire and fire hypersonic bolts).
  Details: docs/features.md "Signature specials".
- **Specials balance**: 90 s charge (10 s in Studio unless the DEV panel's "Specials: REAL" is on), 60 % of the unit's
  damage (was 35 %), total DPS unchanged. Sigilwright pool weight 0.2 (it is a Signature now).
- From Codex (committed as is): cape sway, the Quests panel restyle, the shared Lucky Wheel in the plaza (its model
  needs a rework).

**The user's preferences learned this session (important for every future feature):**
- **Animation:** smooth, momentum-driven; actions flow into each other, nothing snaps back to a rest pose (spline
  keyframes + a spring, anticipation, follow-through, secondary motion). Knell's block in `UnitAnimator` is the model.
- **Specials** must feel worth waiting for: big, readable, and they hit much harder than basic attacks.
- In-world panels are loved (Codex, Outfits, Forge, Graves, Altar). Proposals get discussed first, often with a concept
  image; the user tests in their own Studio and asks to be left to test ("stop testing").
- Skills installed with `npx skills add ...` land in `.agents/skills/` (Codex) and are linked into `.claude/skills/`:
  `roblox-animation`, `roblox-vfx` (use them for animation / VFX work).

**Next (in this order unless the user says otherwise):**
1. **Necromancer spells** (design WITH the user): the player's own basic attack always damages the wall (also the
   softlock fix), 3-4 spells with cooldowns. Still the biggest gap ("the player only watches").
2. **Outer wall rework**: one realm-styled sector per plot (swapped by PlotLook, neutral buttresses at the seams, gate
   towers keep `GateTower<i>` / `GateDoor`); fixes the keeper's hands sitting inside the wall.
3. **Attack kit** for the standard units (on hold, see below) and a **Signature DPS check**: the Sigilwright's 85k DPS is
   below Last Lantern's ~110k (the rule says Signatures sit at the TOP of their rarity) - ask the user.
4. Smaller: the Lucky Wheel model, a better start (guaranteed Rare / early Signature), a pacing playtest, the hovering
   unit over its grave (user's idea file), Signature pulls are extremely rare (~1 in 10,000 pulls for a Descent).

**Before publishing:** save the place (altar, keeper hands, Knell model, wheel, special durations on the stored unit
models live only in it), delete preview folders, run `publish_unit_models.lua` after unit model changes.


**Spin wheel (2026-10-14, made by ChatGPT/Codex, committed as is):** a shared `LuckyWheel` in the plaza (`tools/studio/build_wheel.lua`, place file), `WheelScene`, `WheelRewards`. TODO: rework the wheel MODEL (the user finds it weak); one spin at a time server-wide (others are rejected for 5 s: consider a queue); the prompt is only wired if the wheel exists at server start.

**Keeper hands (2026-10-14):** the titan behind each lane is replaced by his hands from two rifts and his eyes in fog (docs/world.md). Open: the resting hands sit slightly inside the outer wall (fix with the outer wall rework: one realm-styled sector per plot, swapped by PlotLook, neutral buttresses at the sector seams, gate towers keep `GateTower<i>`/`GateDoor` for the portal), the shut rifts' scar smoke is faint, the effects duplicate TitanAnimator's, the Return was not watched on its own. Later: the full Gravekeeper as a world boss (phase 2: 16 hands).

**On hold (2026-10-14, the user's idea, discussed):** raise the quality floor of the standard units with a reusable "attack kit" (4-5 attack styles + hit effects, one per unit, scaled by rarity: Common/Uncommon own attack motion + hit effect, Rare/Cursed visible ranged/area attack, Legendary+ a small in-world special, Signature cinematic specials + a second skill unlocked by awakening (Forge level 10 or Star Dust)). Keep the current Signatures as Signatures. Proposal per unit to be made and approved batch by batch when the user picks it up.

Moved out of CLAUDE.md: what was built when, the agreed next steps, small known issues, the before-publishing checklist and discarded ideas.

## Next steps (backlog, in the order we discussed)

**Knell and the Sigilwright's specials (2026-10-15, built with the user):** Knell reworked (red and black, its own belfry, a Kamehameha throw, the Procession special) and the Sigilwright got THE VERDICT (docs/features.md "Signature specials"). Open: Sigilwright's pool weight is still 1 (the Signature rule says very low; ask the user), the claw / bolt sizes were tuned by eye in few test runs, no sounds.

**Lucky Wheel rework:** the old scrolling strip is replaced by a real seven-section wheel on the main plaza, with an E prompt and an in-world camera/controls view. Odds and rewards are unchanged. Actual spin, shared busy rejection, winning-section landing and view restoration checked in Studio. Save the place to keep `Workspace.LuckyWheel`; rebuild script `tools/studio/build_wheel.lua`. See `docs/features.md` and `docs/world.md`.

### State at the end of the 2026-10-14 session (read `Design.md` too: identity, realms, every idea rated)

Built this session (all committed): hit income with coin drops per unit and the HUD "+X/s" (measured `GoldRate`);
4 walls per run; Realm 1 "The Forgotten Cemetery": cemetery walls + mausoleum gate with damage stages, walls rise one at a
time, lava sea, cemetery lane, cemetery plot look with the new grave layout; the Gravekeeper titan (slam + tremor stun +
weave, defeat at the gate, return after ascending); the portal behind the gate (realm progress runes, rejection, walking
through ascends at a realm's last ascension); coin bursts at every wall damage stage; gold kept through a realm; realm
upgrades + the Upgrades panel (old UpgradePanel removed).

**Also built later on 2026-10-14 (committed):** the necromancer's ritual in all pull cinematics (NecroRitual), the Codex
(CodexPanel, discovered units saved), realm upgrades + Upgrades panel, the cemetery plot look with the new grave layout.

**Built in the second 2026-10-14 session (all committed):**
- Outfit items (section "Outfit items"): Lantern Staff, Gravedigger's Hood, Tattered Cape (detailed part-built
  Accessories, R15; the user approved them), owned + equipped saved, worn on the character (the hood hides hats and
  hair), every player starts with and wears the three; the Outfits panel (wardrobe with a front camera, drag to turn).
- `WorldView`: the shared camera helper for in-world panels (Codex, Outfits, Forge use it). The user LOVES these
  in-world menus and wants more (section "In-world views").
- The Forge in the world (ForgeScene): anvil view, the stall's magic circle rests on the anvil, the ghostly smith strikes
  (hammer head fixed), dust pour, success burst or failure tease, dismantle into dust, Skip + Quick.
- Players join on the plaza; the titan waits hidden and climbs up the first time the owner steps onto the plot.

**Ideas for more in-world panels** (Forge and Graves are done; next agreed: the Soul Altar for the realm upgrades, see below):
Graves (the owned grave tiers rise out of the ground in a half circle round the player, Open goes straight into the
grave cinematic), Inventory (the army lined up on the plot as ghostly copies, capped), Ascend (camera to the portal),
Quests (a parchment board / scroll like the Codex), Upgrades (a realm altar with four soul flames), Wheel (a bone wheel
rising in the sky). Every one: upright camera, short, skippable, fast on repeat use.

**The Soul Altar (built: models, flames, in-world view, tome rite; concept `Images/Plot/altar.png`):** View: client `Modules/AltarScene` (`available()` = your altar (tag `SoulAltar`, `OwnerId`) within 95 studs; `open(keepGui, onFinish)` = WorldView with the camera at altar-local `CAM_POS`/`CAM_LOOK` (the altar left of centre, the panel right), the character stays where it is, hidden; the user dropped placing it at the altar: no room), an "Upgrades" prompt (E) on your own altar's big `Step`. `UpgradesPanel` lives in its own ScreenGui `UpgradesUI` and opens in the world when `AltarScene.available()` (tile, prompt), else the plain centred panel (also the plaza stall). Hovering a card: `AltarFx.highlight(key)`: a realm upgrade = the other braziers sink to embers, the hovered one flares; a permanent one = all braziers dim, the tome glows in its colour. Tome rite (`AltarFx.playRite`): the server also mirrors `Perm_luckBoost`/`Perm_coinBoost`; a new level: both rune rings are taken over from WorldFx (`WorldFx.pause`), spin one extra full turn (rejoining seamlessly) and pull in, the outer rune nearest the camera swoops into the pages (flash, four pages flutter, tome light flares), then Luck = emerald sparkles + a four-leaf sigil that sinks into the book, Coin = 16 gold coins spray out and rain back (2.1 s). The bridge start has an invisible `BridgeLanding` slab and an earth `BridgeFoot` (island model): a corner there let players touch the lava. Dev panel: `Gold x10` (`DevGiveGold`). Flames: `PlotLook` writes the owner's realm upgrade levels onto the altar (tag `SoulAltar`, attributes `Level_<key>`, `OwnerId`) at the claim and after every data sync (`PlayerData.onSync` hooks, called in `PlayerData.sync`); client `Modules/AltarFx` turns each brazier's level into a built-in `Fire` (`AltarFire`, size/heat; the particle flame was too faint at dusk, its emitter only bursts on a flare), soul particles, light and coals (embers at 0; capped upgrades reach full at their max, Might/Harvest grow as 1 - e^(-L/8)); a level going up flares the brazier and four souls fly into the tome; `AltarFx.highlight(key)` is for the view (step 3). Testing note: setting `Level_*` by hand is overwritten by the next sync. `tools/studio/build_altar.lua` (safe to re-run, ~470 parts, place file only) builds `LaneModels.AltarCore` and `LaneModels.CemeteryAltarIsland` in the plot frame (island centre lateral 40 / forward 15, radius 9.5; the bridge starts on the lane shoulder at lateral 23.5 / forward 33.5, clear of the plot side wall that runs on to forward 28.3; checked by numbers: ribs 1.7 studs from the wall cap), `PlotLook` places both on every claimed plot (`PlotAltar_<i>`, `PlotAltarIsland_<i>`, colliders in the Decor group). Core contents: stepped dais, altar with a glowing skull relief and an open bone tome, candles; four `Brazier` models (attribute `Upgrade` = the realm upgrade key, `FlameColor`; part `FlameAnchor` with emitters `Flame`/`Souls` and light `FlameLight`, part `Coals`); two rune rings `RuneRing` (14 green, SpinFx 0.22) and `RuneRingInner` (9 violet, -0.38) (the user wanted a ring and a counter-ring, no ground circle); `BoneBridge` (vertebrae, ribs, soul light, invisible `BridgeDeck`/`BridgeRail`, the `Skull` with a `SkullRamp`). Original design: the realm upgrades in the world. A small island in the hazard on each plot's RIGHT side (in the plot frame), beside the lane start (open lava there: ~30 studs between plots; measured on Plot1: the neighbour's near corner is at lateral 28 / forward -27, gone past forward 6.5), reached by a BONE BRIDGE (giant spine deck, ribs as railings, a skull at the island end, green soul light between the bones) from the plot's front corner on the lane shoulder. Two models: `AltarCore` (the same in every realm: cracked stone altar with an open bone tome and candles, four braziers, the bridge) and `AltarIsland.<Realm>` (only the ground and dressing; Realm 1: cemetery earth, fieldstone, tombstones, NOT lava themed, the hazard differs per realm), placed by `PlotLook`. Braziers: Army Might blood red, Soul Harvest gold, Swift March soul green, Grasping Souls violet; the flame grows with the level (embers at 0; Might/Harvest have no max: slower growth), a buy flares it and souls stream into the altar, they go out at a realm change. Opening: the Upgrades tile on your plot glides the camera to the altar (the character is placed at the altar), panel on the right like the Forge, hovering a card lights its brazier; a prompt on the island opens the same; elsewhere and at the plaza stall the plain panel. Steps: 1. the models, 2. flames from the levels + flare, 3. the view and the prompt.

**Then, in this order (agreed after the 2026-10-14 playtest: "not fun enough yet, the player only watches"):**
1. **Necromancer spells** (the next big feature, design it WITH the user first): 3-4 spells with cooldowns cast in the
   lane (ideas: Raise Dead, Curse, Soul Surge), upgraded permanently with gold on a growing cost curve. See Design.md
   "Making the player matter". The necromancer's own basic attack must ALWAYS damage the wall: it is also the fix for the softlock the
   user hit (no units, no graves, gold below a Mossy grave after dismantling everything; the user chose this over a
   "keep the last unit" guard or a free pauper's grave).
2. **A better start:** a guaranteed Rare (or the planned first early Signature unit) in the first pulls.
3. A real playtest of the new pacing with a normal army (the sim does not model the ~9 s titan stun per wall).
4. Later: Souls (leftover gold converted at the realm change), items (staff / robe / familiars, from Souls, not a
   gacha), the realm veil (only when realm 2 exists), realm 2 "the Cathedral", the social layer from Design.md
   (rare-pull broadcast, server luck, world boss = the Shroud Weaver).

**Known issues / small things:**
- The titan's resting right hand: its fingers dip slightly into the outer wall (fix with an outer wall rework).
- Icons are placeholders: the Upgrades tile and its cards, Shop (Gems icon), Forge (Gold Dust icon), Codex (Inventory
  icon), Outfits (Ascend icon). Icon ids live in `Theme.Image.Icon` / `Theme.Image.Dust` (Theme.lua); each tile picks
  one where it is built (HUD, GravesDock, GemShopPanel, CodexPanel, OutfitsPanel, UpgradesPanel).
- Outfits: the cape does not sway yet (Motor6Ds `CapeSway1..3` are there); the items are not checked in the ritual /
  Codex poses, on R6 or very different avatars; pressing O also zooms the default camera out a little.
- Forge in the world: never run end to end with real clicks (MCP clicks do not reach the game); the strike / burst /
  tease sizes were tuned by numbers, the user only saw part of it.
- The titan's giant shovel (welded to his anchored root) sticks out over the wall even while he waits hidden.
- The titan's entrance plays once per session; respawning after a death is not handled (spawn location).
- The victory moment when the gate falls is on hold (user's call).
- Not tested in game from earlier: buying the Remote Forge, the Forge catalyst chips, a Warding Catalyst on a failed
  upgrade, tall units leaving graves, the narrowed Void-summon circle.
- **Postponed by the user** (do not start unprompted): StarSummon / SignatureDescent support for the new grave opening
  styles, more opening effects for higher tiers, the sound pass (only `rumble` is wired; slots in `sounds/README.md`).
- **Sounds:** originals go to `sounds/_source/`; `tools/audio/prep_sound.py` + `upload_sound.py` (Open Cloud key in
  `tools/audio/.roblox_api_key`, git-ignored; it was pasted in chat once: remind the user to revoke it when the sound
  work is done). Waiting: `sounds/impacts/burst_earth_small.wav`.
- **Before publishing:** save the place (walls, gate, lane, plot look, titan, lava, grave layout, the outfit item models
  in `ReplicatedStorage.ItemModels`, the Forge smith's hammer fix all live in it), make sure `Workspace.GravePreview`,
  `ModelPreviews` and `ItemPreview` are gone (all deleted on 2026-10-14), run `publish_unit_models.lua` if unit models
  changed.
- **Watch:** part counts per occupied lane (cemetery walls ~350, gate ~354, lane ~400, plot look ~286, titan ~274) and the
  grave stall (~2400).
- **User's own uncommitted files:** `Unit ideas.txt`, `sounds/impacts/` (leave them alone).

### Older backlog

1. ~~Buy Dust tab at the Forge~~ (done).
1b. ~~Catalysts, Gem Shop, Remote Forge, Soul Wisp speed~~ (done). Later: Robux gem packs (Developer Products, with the odds-disclosure check), more gem items.
1c. **The first early Signature unit** (a Rare, designed with the user like Hush) as a guaranteed first pull / "guaranteed Rare Signature" box for new players; later one Signature unit per tier; specials for Sigilwright and Last Lantern; maybe a Hush "trial" for new players. Decide whether to remove the dead `/give` chat command (Army.lua).
2. Later: **mutations** (random modifier at pull time, 2-5 % odds, tint/particles, stored on the unit) as the late-game progress filler.
3. **Star summon polish**: sounds (rumble, whoosh, impact; fill `GachaReveal.Sounds` and add some to StarSummon), a real crawl-out pose, lower `STAR_MIN_RANK` if wanted, test on phones, broadcast to other players.
4. **Material/upgrade balance in the sim** (failure path untested in game), a min income per wall against bad-luck stalls, ascension 7 is a bit slow, stage 1 ~20 min (target 10-15).
5. Restyle the remaining old panels (shop next, then quests, ascend (its confirm panel is old style), upgrade, sell, wheel, currency display, hotbar frame, spin button), wall nameplates, a new-player tutorial, offline/daily rewards, boss walls, a collection index; extend barrage casts to LichLord/PlagueDoctor; tower re-rise.
6. Check the Roblox odds-disclosure rule before selling pulls or boosters for Robux.

## Discarded: Pale Sovereign (unicorn)

The user dropped the unicorn idea (2026-10-13). Its build script `tools/studio/build_palesovereign.lua` was removed (still in git history, commit 16c8054); do not bring it back unless asked.
