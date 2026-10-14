# Backlog, state and open issues

**Keeper hands (2026-10-14):** the titan behind each lane is replaced by his hands from two rifts and his eyes in fog (docs/world.md). Open: the resting hands sit slightly inside the outer wall (fix with the outer wall rework: one realm-styled sector per plot, swapped by PlotLook, neutral buttresses at the sector seams, gate towers keep `GateTower<i>`/`GateDoor` for the portal), the shut rifts' scar smoke is faint, the effects duplicate TitanAnimator's, the Return was not watched on its own. Later: the full Gravekeeper as a world boss (phase 2: 16 hands).

**On hold (2026-10-14, the user's idea, discussed):** raise the quality floor of the standard units with a reusable "attack kit" (4-5 attack styles + hit effects, one per unit, scaled by rarity: Common/Uncommon own attack motion + hit effect, Rare/Cursed visible ranged/area attack, Legendary+ a small in-world special, Signature cinematic specials + a second skill unlocked by awakening (Forge level 10 or Star Dust)). Keep the current Signatures as Signatures. Proposal per unit to be made and approved batch by batch when the user picks it up.

Moved out of CLAUDE.md: what was built when, the agreed next steps, small known issues, the before-publishing checklist and discarded ideas.

## Next steps (backlog, in the order we discussed)

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
