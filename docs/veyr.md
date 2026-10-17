# Veyr, the Last Sight (second Sovereign)

Work in progress (started 2026-10-16). The brief is `docs/prompts/spectral-marksman-claude-prompt.txt`; this file records what
is agreed and built. Concept art: `Images/Concept/Unit/Spektraler Scharfschütze mit arkanem Gewehr.png`.

## Character

A hooded skeletal marksman with a long arcane rifle: a patient, silent executioner who has already found the weak point
and expends almost no motion until the shot. One visual vocabulary: hood, skeletal hands, torn mantle, blackened gothic
rifle, blue-violet soul light, concentric focusing sights, floating shards. One escalation: a few rings for a basic shot,
a corridor of sigils for the special, the whole sky as his scope for the finisher.

## State

| Stage | Status |
| --- | --- |
| Base model | done (`build_veyr.lua`, ~700 parts) |
| Awakened model | done (`build_veyr_shadow.lua`), first look |
| Idle / glide / aim / recoil / bolt | done (`MarksmanAnimator.lua`), tuning |
| Basic shot + mark | done (`Army.fireMarksman`, `VeyrShot.lua`, `VeyrSights.lua`) |
| Special (The Long Goodbye) | done (`Army.startSpecial` army variant, `VeyrSpecial.lua`), tuning |
| Finisher (The Final Horizon) | done (`VeyrFinisher.lua`, `Army.checkFinisher`): voice lines, ash gate, reload ending |
| Pull cinematic (A Sight Beyond the Grave) | approved for now (`VeyrArrival.lua`); pool weight 0.05 like Malak |
| Gem Shop card, Codex abilities | done (GemShopPanel Skills, `Units.Abilities.Veyr`) |
| Sounds | done 2026-10-17 (`sounds/veyr/`, Sfx veyr_*; finisher: beds + beat one-shots in VeyrFinisher `LINES` / `BEDS` / `once`, tuned with the user: moon drone from the start (quiet), ambience bed off, aura lower + EQ bass, the build-up slowed to 0.6 to span the charge, the collapse at 0.375 + EQ bass from the shot cut at GATE_HIT, a deep boom (impact 0.45 + EQ) at the break, bolt sounds on the seat and the reload; no `cracks.ogg` yet) |

## Model and rig (`tools/studio/build_veyr.lua`, `build_veyr_shadow.lua`)

- Rerunnable; run `build_veyr.lua`, then `build_veyr_shadow.lua`, then `publish_unit_models.lua`, and save the place.
- Built in the firing pose (bladed, leaning into the rifle). Procedural rig: Root, Waist, Neck, L/R Shoulder, Elbow,
  Wrist, Hip, Knee; `Rifle` (torso -> RifleRoot, pivot at the shoulder pocket); `Bolt` (rifle -> BoltRoot);
  `HoodTail`; `Robe<R|L><i>` (attribute CoatAngle); `Mantle<i>_<k>` (attributes MantleIndex, Segment, Thin for the
  ribbons); `Shard<i>` (attribute ShardIndex).
- RifleRoot attachments: Muzzle, RingOrigin, ScopeEye, ScopeLens, Ejection, Chamber, Butt, GripR, GripL.
- Model attributes: Rig "Procedural", RootHeight 3.55, Height 7.4, Float 0.1, Pose "Marksman", AttackStyle "Marksman".
- The user asked for more detail on the first pass (layered gothic hood with stitched rim and throat clasp, armour
  lames, tassets, skull token, rune knife, ribbons) and brighter trims; a crosshair sigil on the mantle's back was
  rejected ("looks like he is being aimed at").
- Shadow form: void black cloth, dark violet metal, ghostly violet bone, stronger violet runes, blue eyes kept,
  floating armour fragments, smoking mantle ends, muzzle smoke, the usual shell / flames / pool / outline.

## Animation (`src/client/Modules/MarksmanAnimator.lua`, hooked from UnitAnimator for Pose "Marksman")

- Both arms are solved by IK onto the rifle every frame (in the torso's build space), so the hands stay on the rifle
  through the low ready, recoil and the bolt.
- Timing contract: `src/shared/VeyrTimeline.lua` (shot beats from the attack start; the server will use the same).
- Recoil (user's call): straight back into the shoulder, the chest twists, the body slides back a little, only a small
  muzzle hop (~2.5 deg), no head or torso pitch.
- Dev: model attribute `AnimTimeScale` plays him in slow motion.

## Position and movement (user's calls)

- **Overwatch post**: `infiniteRange = true` with his own `postFwd = 30` (Army reads `def.postFwd`, default
  INFINITE_RANGE_POST_FWD): he never marches after the front; ~70 studs to the first wall, ~270 to the gate.
- He never steps: he floats, legs trailing on soft springs; `FLY_HEIGHT` 1.8 studs above his build height
  (MarksmanAnimator; the shadow smoke pool stays on the ground).
- **Perch** (`Units.Veyr.perch = { height 15, out 9, laneLat 16 }`): his unit stands inside the lane at lateral
  side x 16 (Army; model attribute PerchSide, a second Veyr takes the other side; his label moves up with him); the
  model rises 15 studs and drifts 9 past the lane edge once he is at his post (client, not in portraits), turns his
  body towards his target and lays the bore exactly on it, so every shot and the special's corridor run diagonally
  down to the wall. `fireMarksman` measures the flight from the perch.
- The titan's stun rings sit on his torso (model attributes StunCore / StunSize, read by StunFx), not on his
  bounding box (rifle + perch made two separate-looking rings).

## Basic attack: DEAD RECKONING

- Server `Army.fireMarksman` (own branch, AttackStyle "Marksman"): publishes AimPos, ShotImpact, ShotAt, then
  AttackCount; damage fixed at the shot, lands at `VeyrTimeline.impactAt(distance)` (FIRE 3.2 s + distance / 600) on
  the wall he aimed at (dropped if it broke, the run reset or he was removed). attackCD 7.5, damage 700000 (93K DPS
  nominal; with the special's pauses his basics are ~91 % of it, ~85K like Malak; tuned 2026-10-17).
- Client `VeyrShot.lua`: scope glint, three focusing sights at the muzzle (`VeyrSights`), a small sight on the wall,
  the blast (star, flame spike, two shock discs, smoke, ground dust; owner-only shake), the round + glow + lingering
  pierced line, pressure rings, the sights blown forward; the impact (flash, shock discs, a spear of light out the back
  of the wall, dust, sparks, chips, cooling cracks). No impact sound (too massive for a basic, the user's call).
- Trait THE LAST SIGHT: `plotState.mark` (one per plot, refreshed not stacked, strongest counts, cleared with its
  wall) feeds `traitMultiplier`; +10 % army damage for 6 s; the wall model gets MarkUntil / MarkPos and clients draw a
  faint broken sight (four brackets). Verified: a Skelly 11 -> 12 DPS while marked.
- Dev remote `DevToughWall` (Studio): the wall being fought gets 1e15 HP (no DEV panel button yet).

## Special: THE LONG GOODBYE

- `Units.Veyr.special = { kind "LongGoodbye", cooldown 150, duration 13.5, army = { seconds 24, hits 80 % at IMPACT
  9.05 s, 20 % at COLLAPSE 10.4 s } }`; timings in `VeyrTimeline.SPECIAL`. Army: ONE snapshot of the army's ordinary
  DPS at the start (multipliers applied once), all hits on the wall he aimed at, cancelled by a wall change, removal or
  a finisher. It waits until his last basic shot has settled; basics pause for it. Verified (at 20 s, before the 2026-10-17
  tuning): (85000 + 11) x 1.1 (marked) x 20 = 1.87M, dealt 1,496,205 + 374,051 at +9.09 / +10.43 s. Balance against
  Malak: his Requisition 25 army-seconds / 150 s (+17 %) and aura +10 % vs Veyr's 24 / 150 s (+16 %) and the mark
  (+10 % for 6 s of every 7.5 s, ~+8 %); own damage ~85K each.
- Client `VeyrSpecial.lua`: the corridor is laid out at LAYOUT (1.15 s) level along his facing from his muzzle; the
  animator aims the bore exactly down it (measured: 0.00 deg, muzzle within ~0.1 studs). His six real shards fly out
  to the stations (joint transforms), six sigils open in gothic brackets (sized with the corridor's length), lock one
  by one, the round forms in the chamber and runs down the barrel, the shot crosses the corridor in 0.25 s (each sigil
  flashes + pressure disc), the fracture, energy gathering into a dark core, the implosion, the sigils break up, the
  shards fly home, he works the bolt. Planted stance, mantle pulled forward, heavy horizontal recoil.

## Finisher: agreed direction (2026-10-16)

The brief's "cathedral window" final sight was replaced at the user's request by an over-the-top anime combo:

1. **Eclipse Scope** (world, everyone sees it): the sky over the owner's lane darkens; a big moon disc behind the gate;
   a giant ring of light slides over it like an eclipse, crosshair lines extend across the sky, its centre locks on the
   gate. (Owner / watchers only: a round scope vignette closes in on screen with a faint reticle.) Kept within the
   low-quality draw distance: big and close behind the gate, not truly in space.
2. **Phantom Echoes**: his shards burst into 6-8 spectral copies of him (simplified ghost silhouettes, not full
   clones) hovering in an arc over the lane, all aiming at the gate in sync.
3. **The shot** (he still fires his own rifle) and the **Frozen Frame**: the world freezes, black and white with speed
   lines, only the round and his eyes in colour; the round crawls; the scope picture shatters like glass, colour
   floods back, the rounds converge into one point and pierce the gate.
4. **Already Dead**: he has already lowered the rifle, worked the bolt and turned away; a beat of silence; the round's
   path ignites down the lane and the gate erupts behind him (the server's authoritative break); the keeper recoils.

**Rebuilt to the user's version (2026-10-16), 45 s, `VeyrTimeline.FINISHER`:** MARKSMAN 2 (he seats a round), AURA 5.5
(the ground under his perch cracks, 40 rocks lift and later circle his energy), FLEE 6 (server), ASCENT 7.5-11 (MarksmanAnimator
flies his Root up PEAK_HEIGHT 70 and back PEAK_BACK 26, a hard launch easing into the peak, tilted forward by the
momentum, mantle and legs streaming), MOON 10.5 (a big moon placed behind him on the peak shot's line), ARSENAL 13 (eight
magic circles in a wheel round his line of fire), GIANTS_OUT 14.5 / GIANTS_AIM 17 (eight giant rifles = every part of
his own rifle cloned from UnitModels.Veyr, scaled 4.2, slide out and swing onto the gate; the circles fade back),
LOCK 18 (nine targeting lasers), SHIELD 19.5 (the keeper raises his hands, HandsAnimator `FinalHorizon`), CHARGE 21
(debris faster, light dashes drawn up the lasers, aura sparks, a camera orbit), STILL 27 (debris stops, lasers dim),
LIGHT_RUN 27.6-29 (a light along every weapon, stock to barrel), FIRE 30 (nine rounds at once: impact frames = a white
frame, a black frame with white speed lines, a hard black-and-white grade), IMPACT 30.45 (impact frames again, the scope
picture shatters, the keeper's hands blown back; the gate stands untouched but for one glowing pinhole), CRUMBLE 32
(the giants dissolve into falling sparks), TURN 32.5 / DESCEND 33-37.5 (he drifts down to his perch, still on the gate,
while a branching web of violet cracks spreads from the pinhole over the gate's real stones), GATE_HIT 38 (ALREADY DEAD,
2026-10-17, the user's pick over the black hole, which replaced a pillar of light: the server breaks the gate; the client
copies its parts at GATE_HIT - 0.4 and hides the real ones on this screen, then stone by stone, outward from the pinhole
at ASH_WAVE_SPEED 26 studs/s, each glows, turns to ash and drifts away down the lane; an ash wave rolls past his perch),
RELOAD 42.3, END 45. One scope view only (the user): SCOPE_2 28.2-IMPACT, the camera locked at his eyepiece, his whole
model hidden on that screen meanwhile (he blocked the view). The camera path supports hard cuts (`cut = true` keys). Dropped on the way: the echoes, the giant sight on
the gate, the frozen frame, the ring shatter ("scuffed").

Server (`Army.checkFinisher`, registry `FINISHERS`): Malak { FleetStrike, fleeAt 11, 54 s, gate 49.4 } and Veyr
{ FinalHorizon, FINISHER.FLEE / END / GATE_HIT }; the thrones in order, the first commander with his own finisher
unlocked wins, dev units only as a fallback; `plotState.finisherWall` = one per gate; the finisher holds the gate
(holdHP) and breaks it once at gateHit, only if it is still the same gate; `Walls.breakWall` asks
`plotState.tryFinisher` first, so a hit that crosses the threshold straight to 0 starts the finisher instead of skipping
it (this applies to Malak too). Unlock: `profile.finalHorizon` (default false, saved, DataSync `finalHorizon`, State),
`Economy.FINAL_HORIZON_PRICE` 1000, `BuyGemItem("FinalHorizon")`; separate from `fleetStrike`.

Gameplay contract unchanged from the brief: gem unlock (provisional 1000, separate from Fleet Strike),
gate at or below 20 % HP, the server holds the gate, one finisher per gate, first eligible commander throne wins.

## Pull cinematic: A SIGHT BEYOND THE GRAVE (first draft 2026-10-17)

`src/client/Modules/VeyrArrival.lua`, ~30 s + the usual absorb. Routing: `SovereignArrival.ARRIVALS` maps a Sovereign to
its own arrival (`Veyr = VeyrArrival`); `SovereignArrival.play` hands the pull over when the FIRST Sovereign in the
results has one (Malak keeps the ship); the server's `Digging` keeps the first Sovereign of a dig for `ArrivalShow`, so
spectators get the same one. If it cannot play, GraveRolling falls back as before. DEV panel `Anim: Veyr Pull`.
Beats (timeline constants at the top of the file): the bait; a small sight over the grave; far off (ECHO_OUT 150 beyond,
ECHO_UP 46 above, ECHO_SIDE 22 across) a slim dark opening tears and a glint shows; a long lens on his **echo** (a ghost
copy of his model: dark parts, his neon, a violet Highlight outline, 1.6x); six sights open along the line from the
echo's muzzle to the grave while the camera rides it back; the echo fires his real basic shot (`VeyrShot` via
ShotAt / ShotImpact on the clone): he shot his own grave open; impact frames (white, black), `GraveOpening.burst`; the
echo fades, the opening closes; a shadow slit opens in the ground with low fog, his eyes first (EyeLight brightened),
he rises out of it with the rifle held up (ShotAt held); the last sight shrinks round the muzzle, the bolt (ShotAt set
to the bolt beat), a glassy tink; name, class and the raw odds; a last glint on his scope. His line starts
`VOICE_LEAD` 1.5 s before he is fully out of the slit (the user's call) and ends about at the tink (~26 s in all). The camera starts revolving round him into the hero shot `ORBIT_DELAY` 1 s after the line
starts (the user's call; the rifle close-up for the bolt was dropped for it).
**Added 2026-10-17 (the user: "basically his special with a twist"):** a FIELD of 26 glints round the plot
(FIELD_FROM 8.4, seeded by the grave's spot so every screen agrees) that lay faint lines on the grave and fire with him,
their rounds breaking apart in flight; skeletal hands (procedural `buildHand`) claw up and tear the slit open; at
IGNITE_AT his eyes flare, a ring of light rolls over the ground, the mantle flares out (model attribute `MantleFlare`,
MarksmanAnimator) and the shards circle wide and click in one by one (`ShardsGatherAt`). It ends on the revolving hero shot
after he is out (Continue 1.2 s after his line / the bolt); a finale where he aimed at the camera and cut to black was
tried and cut by the user. Army units within NEARBY_HIDE 45 studs of the grave are hidden on this screen while it plays
(they blocked the camera). ~29 s.
Voice (the user wants a demonic undead voice): "Death is just the distance between us." Sfx slot
`voice_veyr_arrival` (`sounds/veyr/voice_arrival.ogg`, 4.68 s, second phrase at 2.65 s, asset 110588920076095; ElevenLabs original in `sounds/_source/veyr/`).
Pool weight still 0 (`RARITY_UNITS`) until the user approves the cinematic.

**No turn (2026-10-17):** turning his back looked wrong (in place, and snapping back after the end), so the user cut it:
he stays on the gate through the eruption and the scene ends on the reload, `FINISHER.RELOAD` 42.3 (the bolt beat at
RELOAD_SLOW 0.65 speed, MarksmanAnimator), on a cut to a close shot of the receiver (like the seat at the start). The TURN beat is only the cut back to him now.

**Voice lines (2026-10-17, `VeyrFinisher.LINES`, watchers only, subtitles like the pulls):** "One round. That is all you
deserve." at MARKSMAN + 0.3 (the round seats on the second phrase), "Bang." at FIRE - 0.75. Files `sounds/veyr/finisher_seat|bang.ogg`
(ElevenLabs originals in `sounds/_source/veyr/`), Sfx `voice_veyr_seat|bang`. A third line as he turns away ("Dead men
don't need to fall quickly.", `finisher_turn.ogg`, asset 134071586633328) was cut: too much (the user).

## Sound

Reuse only Malak's neutral sounds (rune ticks, tear rumble/crack, gate collapse, keeper roar, maybe shell impact as a
low layer); not his laser, cannon, ship, scanner, warhorn or voice. New sounds go to `sounds/veyr/` (the user may
provide): rifle crack with a supernatural tail, bolt clack, glassy ring "tink", rising inward charge, deep implosion,
cloth flutter.
