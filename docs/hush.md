# Hush, the Unbreathing

The fourth Sovereign (since 2026-11-05; he was an Eternal Signature): stats, model, finger beam, Rift Chains in
`docs/models.md` ("Hush"). This file holds the **gate finisher** the user designed on 2026-11-04, THE LAST CROSS (built,
first pass), and the promotion.

## Promotion to Sovereign (done 2026-11-05)

`Units.lua`: `sovereign = true`, title kept: **The Unbreathing** (his unique trait is named after it, like the other
Sovereigns; the user asked to "give him a title": he already had this one, it is only shown more places now: the Codex
under his name, after his name in the pull arrival), rarity **Primordial** (moved out of the Eternal pool), pool weight
0.05 from the Celestial grave only like Malak / Veyr / Orvoss (1 in 56,000 like them), damage 170000 = **85K DPS** like the
other three (placeholder; he was 90000 = 45K DPS as an Eternal Signature), abilities: The Unbreathing (passive), Rift
Chains (special), The Last Cross (finisher, locked until bought: `unlock = LastCross`, price `LAST_CROSS_PRICE`). The Codex
page needs nothing else: it reads the flag (SOVEREIGN label, COMMANDER badge, title, the three abilities with the
finisher's unlock). He stands on a commander throne (already true as a Signature). The plaza showcase (`ReliquaryShowcase`)
and the rare-pull banner pick him up automatically (they list every Sovereign).
Not done: his OWN pull cinematic (he gets Malak's ship, like Orvoss: a gas-masked child arriving on a spaceship does not
fit: a Hush arrival is a later piece of work), the economy sim (`tools/sim`) does not know him as a Primordial.
Real trigger tested in Studio (2026-11-05): dev gems -> `BuyGemItem("LastCross")` -> a dev Hush -> `DevGateLow` -> the
army brought the gate under 20 %: the server logged `LastCross on plot 1`, every client played it from the remote, the
gate was held until `GATE_HIT` and then broken for real by the server ("wall 4 broken"), the finisher ended at 59 s.

## Facts the finisher must respect

- Hush floats (`RootHeight` 9.6), "crucified" in the air (`Pose = "Crucified"`: head lolling and twitching, arms
  sloping down and out, nails through the sleeves, shackles with broken chains, bare feet shackled together). He never
  walks. He stands at his fixed post (`infiniteRange`, like the Sigilwright; `INFINITE_RANGE_POST_FWD` in `Army.lua`).
- He has no voice (a child in a gas mask: "It does not speak. It only points"). Sound = thunder, chains, breath.
- His Rift Chains special already tears a rift, sends chains out that bite into the wall and explode
  (`SpecialFx.lua`). The finisher must feel like that, only enormous, and must not reuse its beat.
- The gate is a wall that stands: nothing can hang it in the air. The cross falls onto it like a felled tree.

## Concept: THE LAST CROSS (working name; the user's storyboard, "a bit longer and slower")

Hush floats up, the sky darkens, purple lightning storms behind him, he glows purple, his head twitches and snaps,
huge rifts open behind him, huge chains drift out like in his special, accelerate and swarm in the air, the swarm
forms a massive cross (he was crucified: now the cross is his), the cross topples AWAY from Hush towards the gate and
slams into it, leaving a massive ravine that runs along the whole lane up to the outer walls and climbs the outer
wall. The camera returns to Hush, who floats slowly down.

### Beat sheet (first pass, about 62 s, like Malak 54 s / Veyr 45 s / Orvoss 67 s; times are a proposal)

| Time | Beat | What happens |
|---|---|---|
| 0-5 | **THE RISE** | The army stops. Hush floats up slowly from his post (to ~45 studs), still crucified, head lolling. The sky starts to darken (a long fade, up to 11 s). |
| 5-11 | **THE STORM** | Purple lightning far behind him, then nearer, thunder rolling. He starts to glow purple (neon tint + light). |
| 11-18 | **THE SNAPPING** | His head twitches, then snaps harder and faster; every snap pulses the glow and sends a lightning strike behind him. Slow camera push-in. Mask breath gets faster. |
| 18-25 | **THE RIFTS** | Huge rifts tear open behind him one after another (4-6, the look of Rift Chains, scaled up). The realm keeper's hands behind the gate react (raise / recoil, `HandsAnimator`). |
| 25-34 | **THE CHAINS** | Huge chains drift out of the rifts, slow and heavy. Then they accelerate and swarm through the air in a wild mass. Wide camera. |
| 34-41 | **THE CROSS** | The swarm is drawn together and locks into one massive cross that hangs trembling; lightning silhouettes it. |
| 41-48 | **THE FALL** | The cross topples slowly away from Hush towards the gate (hinged at its foot), faster and faster. |
| 48-50 | **THE IMPACT** | It slams into the gate: flash, shake, dust. **The server breaks the gate here (gate hit).** |
| 50-56 | **THE RAVINE** | A ravine tears out from the impact along the whole lane to the outer walls and climbs the outer wall; the keeper recoils; the cross dissolves into falling chains and sparks. |
| 56-62 | **THE END** | The camera goes back to Hush, who floats slowly down to his post while the glow fades and the sky clears. |

## How it plugs in (same contract as the other finishers; see `docs/veyr.md` "Finisher", `docs/orvoss.md`)

- Server: an entry in `Army.checkFinisher`'s registry `FINISHERS` (flee / end / gate-hit times), `plotState.finisherWall`
  one per gate, the finisher holds the gate (holdHP) and breaks it once at gate hit if it is still the same gate;
  `Walls.breakWall` asks `plotState.tryFinisher` first. First eligible commander throne with its own finisher unlocked
  wins. Hush is a Signature and already stands on a commander throne.
- Unlock: a saved profile flag (default false, DataSync field, `State`), `Economy.<NAME>_PRICE`, `BuyGemItem("<Name>")`,
  a Codex entry, like `fleetStrike` / `finalHorizon`. Gate at or below 20 % HP, one finisher per gate. Price: undecided.
- Client: a timeline module in `src/shared` (like `VeyrTimeline`) and a client module that plays it for everyone (a
  remote like `FinalHorizon` / `LastBroadside`), a Studio preview from the DEV panel (`Anim:` list).
- Plot geometry: use `PlotFrame` for everything (never world X/Z); the ravine and the cross are laid out along the
  plot's lane, which points in different directions per plot.

## Build stages (proposal; each one gets tested with the user)

1. Server trigger, unlock, remote, DEV preview, timeline skeleton, Hush's rise, the sky fade, the lightning, the glow,
   the head snapping, the camera shots.
2. The rifts and the chain swarm (performance: a few dozen long chains built from pooled links moved on curves, not
   hundreds of loose parts; reuse the chain link model made for Orvoss).
3. The cross (every chain flies to its slot, then the cross turns as one rigid body about its foot) and the fall.
4. The impact, the gate break, the ravine along the lane and up the outer wall (client visual geometry), the keeper's reaction.
5. The end (Hush descends, sky back), sounds, tuning.

## Open points

- Army during the finisher: hidden or sent away like the others (decide at stage 1).
- How big the cross must be to read from the camera without clipping through the outer wall (Orvoss's ships have the
  same problem at a real gate): plan the camera shots first.
- Shadow form (level 10): does it change the colours (purple glow is already the shadow accent)?
- Sounds: thunder, chain rattle, the impact, mask breath. Files come from the user (see how the other finishers did it).
- Unlock price; the promotion of Hush to a Sovereign (later).

## Build state (2026-11-04, STAGES 1-4 written, first pass, not approved)

- Shared `src/shared/HushTimeline.lua` (the beat times, `RISE_HEIGHT`, the `SNAPS` list). Server: `Army` `FINISHERS.Hush`
  (kind `LastCross`, army never flees), `PlayerData.lastCross` (saved, DataSync, `State.lastCross`),
  `Economy.LAST_CROSS_PRICE` 1000 (provisional), `GemShop` item `LastCross`, remotes `LastCross` / `DevLastCross`, a
  `Units.lua` ability entry (Codex sells it), `DevTools` preview handler.
- Client `HushFinisher.lua`: the take-over, the camera shots (rise, storm, snapping, rifts, chains, a wide hold,
  descent), the watchers' colour grade (a ColorCorrection only: this map's Atmosphere haze is already 0.9, raising its
  density whited the screen out), lightning strikes behind him that get more frequent and strike on every snap, his
  purple Highlight + light pulsing with the snaps. `UnitAnimator`'s Crucified pose: the rise, lifting arms and the
  snapping head, keyed on the client-only model attributes `FinisherAt` / `FinisherKind`.
- STAGE 2 (built when T reaches RIFTS - 2, so they sit round where he really hangs; centre = his chest, NOT the
  bounding box: it is 38 studs tall with the chains): five huge rifts (RX 7, RY 30) in an arc behind him, the middle
  first, one every 1.2 s; the rift look of Rift Chains (rim pieces, frayed spikes, fragments) with the oval's interior as
  18 stacked slats (a Cylinder part draws as a circle at its smaller diameter), a deep violet that glows. 12 huge chains
  (34 links of 4.6 studs, alternate links turned 90 degrees, Neon) creep out of the rifts, slowly, wriggling, then from
  `CHAINS + 5` s blend into a speeding-up Lissajous swarm round a point between him and the gate. A chain is the
  precomputed path of its head with links trailing at a fixed arc length. ~830 parts, all moved with ONE
  `BulkMoveTo` per frame. Until stage 3 the swarm just goes on and fades at the ravine; the rifts zip shut before
  the descent.
- Seen by eye (Studio previews, 2026-11-04): the rise over the plaza, the storm sky, the face shot with a lightning
  bolt, the five rifts opening, chains wriggling out, the swarm sweeping the sky. NOT checked: frame rate with a real
  army, other clients, the real trigger at a gate (only the DEV preview has run).
- Known: in the swarm the chains pass very close to the camera (huge slabs fill the screen); the face Highlight is a flat
  purple silhouette at the snap peaks; the scene is dark overall.
- STAGE 3 (the cross, built in `buildStage2` too): the cross stands in the lane with its foot `L * sin 70` studs before the
  gate (`L` = 150 studs, clamped by the lane length; the gate was measured 240 studs from Hush), so hinged at its foot
  and toppling forward its top lands on the gate face at 70 degrees (~51 studs up). Six chains side by side (3.4 studs
  apart) make the upright beam, six the arms (span 0.64 L, shorter than a chain: its links bunch up), slots in the
  cross's own frame (`c.slots`, x across, y up, z depth); the head links end at the top / the right arm end. From
  CROSS - 0.5 s each link is captured into its slot (staggered along the chain and chain after chain, `ease` 3.5 s), the
  cross holds trembling (CROSS + 3 .. FALL), leans back a little, then topples with theta = 70 degrees * s^2.4 (s = 0..1
  over FALL..IMPACT). Camera shots: the cross from behind it, face on; the fall following the tip; a wide hold on the gate.
- Seen (Studio): the chains pulled into the cross, the finished cross upright, the cross lying at 70 degrees at IMPACT.
  The tip's landing on the REAL gate face was not checked (the preview gate is the wall being fought, `AimPos`).
- STAGE 4 (`buildImpact`, `buildRavine`): at IMPACT the tip (`ctx.tip`) gets a violet-white flash ball, a violet light, 7
  lightning bolts, a dust cloud (one emitter burst) and 26 chunks thrown back down the lane on a ballistic arc, with a
  hard camera shake (3, decaying over ~2 s). The server's real gate break still happens at GATE_HIT 49 (unchanged). The
  ravine: the gate is only ~8 studs in front of the outer wall's gate tower (`Workspace.OuterWall`, the face found by a
  raycast from the gate; fallback 14 studs behind), so it runs from under Hush's post down the lane (a jittering path,
  widening to ~13 studs at the gate, 14 side cracks), through the gate and 70 studs up the tower (6 side cracks). Static
  pieces made once at build (~630 parts: a black core, a glowing violet heart, rim strips that flare white when it opens,
  stone lips, side cracks) revealed by the front (floor 2.6 s from RAVINE, then the wall 1.5 s); violet lights and rising
  embers along it; it fades out from DESCEND. Camera: the impact shot, then a wide shot from the lane in front of the gate.
- The Studio PREVIEW moves a near gate out to 240 studs (the wall you are fighting is usually near; the real gate is the
  last wall). With a near gate the cross's foot lands next to the camera and the screen fills with chain links.
- Not seen / open: I could not reliably catch the impact frames or the climb up the tower in screenshots (capture lag); a
  few frames came out completely white (one at the impact flash, which can be the bloom from the neon flash, one around
  58 s that I could not reproduce): the flash was weakened afterwards; Bloom is intensity 0.8, threshold 1.0 on this map.
- Not built: sounds, the descent's own details
  animator's `DESCEND_TIME` exist), sounds, a Codex page check, the real gate trigger.

## Changes after the first review (2026-11-05)

- **Shorter start (the user):** everything up to the rifts (section 4) went from 18 s to 11 s and the finisher from 62 s to
  55 s (`HushTimeline`: STORM 0.4, SNAP 5, RIFTS 11, CHAINS 18, CROSS 27, FALL 34, IMPACT 41, GATE_HIT 42, RAVINE 43,
  DESCEND 49, END 55; the head snaps compressed into 5.2-9.8 s; `SHOT_STORM` 3.5). The glow and the first lightning now
  start at 0.4 s, DURING the rise (the sky darkens over 6 s). The beat table above still shows the old first-pass times.
- **The cross rebuilt (the user's idea, 2026-11-05):** a SOLID cross floats up out of a rift in the lane floor while the chains
  swarm; the chains then wind themselves round it; only when it is fully wrapped does it fall. Timeline: GROUND_RIFT 19.5
  (a 108-stud-wide rift opens in the lane floor, sparks rise), CROSS_RISE 20.5 (the cross floats up from 164 studs under
  the floor to hover `CROSS_HOVER` 5 above it, ending at CROSS - 0.5), CROSS 27 (the chains wind round it: chain n is
  handed over at CROSS + 0.3 (n-1), flies 1.4 s from the swarm to the start of its spiral and winds along it for 4.5 s,
  all done by CROSS + 9.3), FALL 38, IMPACT 45, GATE_HIT 46, RAVINE 47, DESCEND 53, END 59.
  Code (`HushFinisher.lua`): `buildCrossModel` (~35 parts in the cross's own frame: slate beam and arms, iron caps and bands,
  a boss at the crossing, neon rune strips, 8 violet PointLights so the stone is visible against the night sky; stone
  colours must stay light, black vanishes), `spiralPoint` / `buildChain` (a chain is the precomputed path of its head: swarm,
  then a bezier approach, then a spiral round a beam; 56 links of 4.6 studs; six chains spiral the upright and six the
  arms, interleaved at 60 degrees and winding both ways, so they criss-cross like lacing; `c.slots` = where each link
  rests in the cross's frame, used once its head has finished so the whole cross can fall rigidly with its chains).
  Camera: "emerge" (low on the lane, looking up at the top as it rises) and "wrap" (a slow orbit); the fall, impact and
  ravine shots are unchanged. `ctx.crossLift(t)` is the cross's height offset.
- Seen (Studio preview, 2026-11-05): the cross emerging, the cross standing with the first chains winding up it (like
  corset lacing), the cross fully wrapped at the start of its fall. NOT re-checked after the change: the fall, impact and
  ravine frames (their code only had the hover offset added).
- **The ravine opens at the hit (the user, 2026-11-05):** `RAVINE` = `IMPACT` (45); `GATE_HIT` 45.4 (the server breaks the gate a
  beat after the hit); `SHOT_RAVINE` 46.6 (the camera cut from the impact shot). It now spreads FROM the impact: the
  floor reveals from the gate back towards his post over 2.6 s while the gate tower's wall cracks climb at the same time
  (1.5 s up 70 studs). The chains and the solid cross dissolve from `RAVINE` + 1.5 (not at the hit). Seen: the finished
  ravine on the lane and the glowing cracks up the tower face; the first frames after the hit were not caught.
