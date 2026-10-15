# Malak, the Envoy: design draft

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

**The ship: The Absolution** (redesigned 2026-10-15; the dagger did not fit Malak). Built out of Malak's own visual
language, scaled up to a warship: a long narrow central hull whose rear half flares into layered pointed blade fins like
his coat skirt (glowing seam, silver edges, diamond emblem on each; they are the engines, glow pours out between them);
a smooth faceless bow like his helmet with ONE long vertical slit of light (the main cannon opens out of it: the slit
splits apart, the halves fold aside); a tall upswept armour crest behind the bow like his high collar (the bridge); a
giant armillary amidships, two or three huge nested rings turning round a glowing core like his drone (they spin up and
lock into alignment when the cannon charges); turrets set into chevron plates on the underside (his chest chevrons),
missile bays in the fins. His palette: black chrome, silver, cold white-blue seams, a hint of violet; red only for the
targeting lasers. Concept art: `Images/Concept/Unit/Die Absolution – gotisches Ringschlachtschiff.png` (side + underside view).

**Model (built 2026-10-15, approved):** `tools/studio/build_absolution.lua` -> `ReplicatedStorage.ShipModels.Absolution`
(place file only; ~420 studs chin to fin tips, 1795 parts, front = -Z, origin = the core, PrimaryPart `Root`). A heavy
hull (it must read as a massive warship, not a bird: broad armour fins that flare only a little), belt armour with vents,
~200 lit windows, a stepped bridge tower with Malak's slit in the command cab and sensor masts, the collar crest behind
it, five triple-barrel main turrets (two forward, the big one superfiring; one aft and one below facing the stern),
secondaries, point defence, the core in a cage, an engine block with five stepped thruster bells and two outrigger pods.
Joints for the cutscene: `BowL` / `BowR` (the helmet halves fold open), `Cannon` (slides out of the slit), `RingA` /
`RingB` / `RingC` (spin up, lock into line), `Turret1..26` (yaw) and `Turret<n>Guns` on the main turrets (elevation).
To do in the cutscene: real exhaust (beams / particles) instead of the solid plume cylinders. Size idea: 300-400 studs
long, ~150 studs over the plot.

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

## Fleet Strike cutscene (second draft, about 45 s; skippable)

**Build status (2026-10-15):** built in steps, each approved before the next (client `Modules/FleetStrike.lua`, played
from the DEV panel: Anim: Fleet, Play; needs your Malak placed; now 52 s). Done: 1. the frame (camera / controls / UI
taken over, letterbox, Skip, Studio beat caption). 2. Malak's beats (the left hand types on runes rising from the
gauntlet, the drone stacks into a transmitter and fires a pulse up at 9.0 s, the army flees at 11 s: server
`Army.startFinisher`, Studio remote `DevFleetStrike`; nameplates hidden, the big attack hologram and palm pad closed).
3. the tear (darkening, vortex, rune ring, cracks, void) and the warp-in (the Absolution slides out LEFT to RIGHT as
seen from Malak, far away and high: SKY_SIDE 650, SKY_HEIGHT 400, SKY_LEFT 150; ~9.5 s; hidden behind the portal plane;
window lights run bow to stern; the reactor rings turn, the core pulses; haze thinned on screen). 4. scan (turrets turn
to the gate, red scan fan + scan line, five reticles lock) and barrage from 38 s (main salvos, tracers, 12 missiles,
fire and smoke on the gate, camera shake). The camera is ONE continuous path through keyframes (`KEYS`, monotone
Hermite: never overshoots); the user calls it almost perfect, small things to fix later. Next: 5. main cannon (bow
opens, cannon swivels to the gate, rings spin up and lock), beam, the gate breaks. IDEA (user, 2026-10-15): the final
shot also strikes the realm keeper (his hands + eyes behind the gate, `HandsAnimator`). He is NOT killed: he is the
secret world boss, so he is wounded and DRIVEN BACK (his existing Defeat: dragged into the rifts reads as a retreat).
He notices the ship during the scan (eyes turn red, hands tense), the barrage also hits his hands; the cannon aims at
him first (the gate is low, he is high above the outer wall: one straight beam cannot hit both): he raises both hands in
front of his eyes, the beam slams into his palms, his eyes flinch shut, he recoils; still firing, the beam drags down the
outer wall onto the gate and cuts it apart; the gate falls and he withdraws into the rifts (chosen: the sweep). 6. ending, the ship lingers and warps
out, the army returns. 7. gameplay (trigger at 20% gate HP, gems unlock, settings toggle, view for other players).
8. sound.

Trigger: the gate drops to 20% HP while Malak is placed and the finisher is unlocked. The gate holds there (no more
damage) until the cutscene ends. Letterbox bars in, units stop attacking, music drops, the camera takes over (owner
only; everyone else sees it play out in the sky over the plot, without the camera).

| Time | Beat |
|---|---|
| 0-1.5 s | **The trigger.** Bars slide in, the army goes still, the music drops away. |
| 1.5-6 s | **The left hand.** Close on Malak. For the first time his LEFT hand comes out from behind his back. Runes rise along his right gauntlet into a small panel; he types on it with the left hand, drags and rearranges runes, slowly, barely moving his head; the last rune clicks into place with a small confirm pulse. |
| 6-9.5 s | **The drone transforms** into a transmitter: its rings stop, swing into one plane and stack, the spikes extend into a spire, the core flares; it turns skyward and sends a thin pulse straight up, transmission rings rising after it. |
| 9.5-11 s | **Nothing happens; the army knows.** A wide shot: the rest of the army looks up at the pulse, then breaks and runs back past him towards the graves (some stumble, some glance back over their shoulders). Malak does not move; the left hand goes back behind his back and he watches. (Idea of the user, 2026-10-15. The units return to the wall after the cutscene; server side a short \"flee\" order back to the graves.) |
| 11-17 s | **The sky tears.** The camera swipes up, slowly. The sky darkens, the clouds swirl into a vortex over the lane, a huge portal ring of runes etches itself into the sky, cracks of light spread from it. |
| 17-26 s | **The warp-in, slow and ominous.** The faceless bow pushes out first, its slit glowing like his helmet, inch by inch so the scale reads; then the collar crest; then the giant armillary, turning; last the coat fins, unfolding behind it as it clears the portal, engine glow pouring out between them. The portal snaps shut, a shockwave rolls through the clouds, lights run down the spine. |
| 26-31 s | **Scanning.** Camera under the hull, looking up. A red scan fan sweeps out of the bow slit over the gate, reticles lock on one by one, the chevron turrets turn to the gate in sequence. |
| 31-35 s | **Barrage.** The turrets open up (tracer streams), missiles curve in from the fin bays, the gate shakes, smoke and fire build. |
| 35-39 s | **The main cannon.** The bow slit splits open, the halves fold aside, the cannon pushes out; the armillary rings spin up and lock into line with it; light and debris are pulled in. Half a second of silence. |
| 39-42 s | **The beam.** White flash, slow-motion shockwave, the gate breaks apart. |
| 42-45 s | Back to Malak, unbothered: the rune panel folds back into the gauntlet, the drone unfolds into its armillary. Bars out, control back. |

**After the cutscene:** the Absolution does NOT turn (it is too massive). It lingers over the plot for a while (~20 s,
visible to every player in the server, the after-wow moment), then a portal opens behind it and it drifts backwards
into it very slowly, stern first, the bow last, and the portal collapses with a low boom.

**Continuity:** the red glint in the sky that his basic attack's laser and shells come from is the Absolution, out of
sight; the finisher is the first time players see it.

## Sound (later, important)

Gauntlet rune clicks and the confirm pulse, the drone's transformation and transmission, the silence beat, the sky
tearing (deep groan + crackle), the warp-in (sub-bass swell), lock-on beeps, the broadside, the cannon charge whine
cut to silence, the beam impact, the slow warp-out boom.

## Open questions

- Rarity (Primordial suggested; Abyssal and Eldritch have no Signature yet).
- The purchase: gems (decided). Per account (any Envoy can use it)?
- Damage split between basic, drone, skill.
