# The Envoy (working name): design draft

Signature unit, designed with the user on 2026-10-15. Model built and liked by the user (2026-10-15):
`tools/studio/build_malak.lua` -> `ServerStorage.Models.Malak` (512 parts, no shadow form yet). Idle done: model
attribute `Pose = "Envoy"` -> UnitAnimator's Envoy block (slow double hover bob, glide lean and turn banking, dangling
legs, the 11 coat blades + tabard on spring joints `Coat...` with attribute `CoatAngle`, a glance down at the hologram
every ~11 s, hologram pulse + flicker). `Units.lua` has a placeholder entry (Primordial pool, weight 0: DEV panel only). Order: model (screenshots for approval) ->
drone -> basic attack -> skill -> frigate model -> finisher cutscene -> sound.

**Name:** Malak, the Envoy. **Class: Sovereign** (a new class above Signature: very few units, each with a gate
finisher cutscene unlocked once for gems; one finisher per gate; a name style above the Signature ember).

**Tone:** gothic but clearly, over-the-top high-tech (decided 2026-10-15): it may look far more advanced than
anything else in the game. Hard-edged armour plates, glowing seams, hologram UI, hover tech, a real warship with
turrets and a main cannon. The warp portal can be a tech rift with rune accents.

**The frigate: blade dreadnought** (chosen over the cathedral look): a long, narrow, layered dagger hull pointing at
the gate, armour plates stacked in steps along its length; the prow splits open down the middle to reveal the main
cannon.

**General rule for every animation here:** build it slower than seems right first; it can be sped up later.

## Look

Tall figure, matte black armoured long coat with a high collar, a smooth faceless helmet with one vertical slit of
cold light, a cape of thin light filaments. One arm wears a gauntlet that projects hologram runes. A drone (a small
floating reliquary) is always beside him.

## Kit

| Part | What it does |
|---|---|
| **Basic: orbital tag** (built 2026-10-15) | Every 6.5 s (`attackCD` 6.5, slow on purpose: a little waiting between strikes). While he fights, his small palm pad opens into a BIG hologram floating in front of him (client `Modules/OrbitalStrike.lua`, `BOARD_*`; UnitAnimator's Envoy block hides the pad and lets the empty hand rest). Per attack: 0.5 s a red targeting ring opens on the big hologram by itself (pane tinted red); 1.85 s the red laser cuts diagonally out of the sky (from the ship's spot: 110 up, 75 to the side, 18 in front of the wall face; a red glint) and a reticle opens where it lands; 2.8 s lock (reticle and hologram flash); from 1.75 s he lazily raises his arm and at 3.05 s presses the hologram once (a ripple where he touched it); 3.1 s the gunship fires: a big muzzle blast with rings rolling out, a white-hot man-sized slug comes down the laser in 0.8 s with a tracer, shockwave rings off its path and a sonic boom halfway; 0.22 s before impact the reticle collapses to a point and the laser goes thin and white; 3.9 s impact (= `hitDelay`, damage lands): flash, fireball, shockwave over the wall, big debris that bounces, a dust ring rolling out on the ground, embers, sparks, smoke, cooling scorch, a short camera shake for the plot's owner when close (model attribute `OwnerId`, set in `Army.spawnUnit`); he tips his head up a touch to check. No column of fire, no line from the pad to the wall (the user did not want them). The LEFT hand is saved for the ultimate. |
| **Drone (constant)** | Model: part of `build_malak.lua` (a floating armillary beside his left shoulder: glowing core in a cage, three nested chrome rings on tilted Spin joints `SpinDrone1-3`, a broken outer C-ring, spikes; joint `Drone` from the root with its own bob and outward-only spring lag). Attack, the converging bolts (built 2026-10-15): unit def `companion = { period 4.5, share 0.3, hitAt 2.05 }` -> `Army.fireCompanion` (generic: its own clock while the unit fights, sets `DroneAim` + `DroneShot` server time, deals `share` of the unit's DPS; basic attacks deal the rest). Client: the rings drift apart into a triangle in front of the drone and spin up (UnitAnimator, `DRONE_RING_SPREAD`), cold sparks charge in them from 0.9 s, at 1.6 s they fire one after another (0.06 s apart) thin cold bolts that accelerate and meet on the wall, impact at 2.05 s (cold flash, ring, sparks), the rings snap back (OrbitalStrike.lua, "The drone's volley"). Independent of the shells: they may land together. |
| **Skill (charges, like other Signature specials): rail lance** | Pulls out a long rifle, charge-up lines draw in along the barrel, one tracer shot, delayed impact on the wall. |
| **Ultimate: Fleet Strike** | Gate only. Unlocked by a purchase. When the gate drops to 20% HP while the Envoy is placed, it is executed by the frigate (the gate holds until the cutscene ends). |

## Fleet Strike cutscene (first draft of the timing, about 38 s; skippable)

Letterbox bars in, units stop attacking, the camera takes over.

| Time | Beat |
|---|---|
| 0-4 s | **Nonchalant.** Close on the Envoy, completely relaxed, weight on one leg, other hand behind his back. Runes flicker up along his gauntlet as a small hologram panel; he taps, drags and rearranges them with one finger; the last rune clicks into place with a small confirm pulse. Barely moves his head. |
| 4-7 s | **The drone transforms** into a sending device: plates unfold, an antenna ring extends, it turns skyward and sends a pulse up, transmission rings rising. |
| 7-8.5 s | **Nothing happens.** A beat of silence. He lowers his arm. |
| 8.5-14 s | **The sky tears.** The camera swipes up. Clouds swirl into a vortex, a huge portal ring of runes forms, cracks of light spread across the sky. Slow. |
| 14-22 s | **Warp-in, slow and ominous.** The bow pushes out of the portal inch by inch so the scale reads, light streaks off the hull, the portal closes behind it, a shockwave rolls across the sky. Lights run down its spine. |
| 22-27 s | **Scanning.** Camera under the hull looking up. A red scan fan sweeps the gate, reticles lock one by one (a sound each), every turret turns to the gate. |
| 27-31 s | **Barrage.** Broadside: tracer streams, curving missiles, the gate shakes, smoke and fire build. |
| 31-34 s | **Main cannon charges.** The prow opens, a huge charge pulls light and debris in. Half a second of silence. |
| 34-37 s | **The beam.** White flash, slow-motion shockwave, the gate breaks apart. |
| 37-39 s | Back to the Envoy, unbothered, closing his rune panel. Bars out, control back. |

**After the cutscene:** the frigate does NOT turn (it is too massive). It lingers over the plot for a while (visible to
every player in the server, the after-wow moment), then a portal opens behind it and it drifts backwards into it very
slowly, stern first, the bow last, and the portal collapses with a low boom.

## Sound (later, important)

Gauntlet rune clicks and the confirm pulse, the drone's transformation and transmission, the silence beat, the sky
tearing (deep groan + crackle), the warp-in (sub-bass swell), lock-on beeps, the broadside, the cannon charge whine
cut to silence, the beam impact, the slow warp-out boom.

## Open questions

- Rarity (Primordial suggested; Abyssal and Eldritch have no Signature yet).
- The purchase: gems (decided). Per account (any Envoy can use it)?
- The frigate's name.
- Damage split between basic, drone, skill.
