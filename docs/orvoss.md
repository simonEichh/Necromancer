# Orvoss, the Blackwake

## Status (2026-10-17)

The base character model and his idle animation are built (approved). Unit def added 2026-10-17 (`Units.Orvoss`:
Sovereign, throne only, pool weight 0.05 from Celestial like Malak/Veyr, 510K / 6 s = 85K DPS placeholder, range 25,
Codex lore line; the generic hit until his basic attack exists, Malak's pull cinematic until he has his own). Tested
once: he spawns, walks, attacks, no errors; the hotbar portrait shows. Not done: his attacks, the awakened form, fleet /
arrival / finisher.

- Approved art: `Images/Concept/Unit/Orvoss-the-Blackwake-concept-v1.png`; brief: `docs/prompts/orvoss-blackwake-model-claude-prompt.txt`.
- Builder: `tools/studio/build_orvoss.lua` (Edit mode, via the tools/studio http server). It builds off-tree, validates
  (every part connected to the root, one weld per part, unique joint/attachment names, flags, no scripts/Humanoid) and
  only then replaces `ServerStorage.Models.Orvoss` (a hand-made model would be kept once as `Orvoss_Old`). It returns a
  report. Rebuilding gives the same model (seeded random).
- `tools/studio/check_orvoss.lua`: checks that scaling and rotating keep every part in place, and that each joint moves
  its whole assembly. It leaves a posed copy (`OrvossPoseTest`) for screenshots.
- `tools/studio/show_orvoss.lua`: stages `Workspace.OrvossPreview` at (0, floor, 16) on the plaza (`COMPARE = true`
  adds Malak and Veyr). **Delete it before publishing.**
- `ReplicatedStorage.UnitModels.Orvoss` was rebuilt with `publish_unit_models.lua`. Save the place file: the model only
  lives there.

### Measured (last build)

716 BaseParts, 40 Motor6Ds, 11 attachments, 0 emitters, 2 lights. Size 5.37 x 7.52 x 3.63 (width x height x depth),
soles at y = 0, hat top 7.52. `RootHeight` 3.7, `Height` 7.52.
Parts by region: Skull 55, Hat 74, Chest (ribs, spine, soul) 44, CoatUpper (body, collar, lapels, baldric, back chain)
89, CoatTails 124, Epaulettes 38, Arms 42, Hands 49, Legs 51, Cutlass 44, Pistol 36, Belt (belt, holster, chains) 32,
Compass 17, Growth (hem seaweed/barnacles) 12, Rig carriers 9. (Each part has a `Cat` attribute with its region.)

### Rig contract

- Front -Z, right +X. HumanoidRootPart at 3.7. Standard joints Root, Waist, Neck, L/RShoulder, L/RElbow, L/RWrist,
  L/RHip, L/RKnee, L/RAnkle, rest pose at identity Transform.
- `Jaw` (Head -> JawRoot, hinge under the ear line; the lower teeth ride on it; negative X rotation opens it).
- `Hat` (Head -> HatRoot): the whole tricorn including badge, chain, barnacles and seaweed.
- `Cutlass` (RHand -> CutlassRoot = the grip): frame origin at the fist centre, -Z along the blade, +Y the spine.
  Attachments `CutlassGrip`, `BladeBase`, `BladeTip`, `CommandPoint` (all with -Z along the blade).
- `Pistol` (LHand -> PistolRoot, the stock): -Z = muzzle direction, +Y = top; `PistolHammer` (-> PistolHammerRoot,
  the cock). Attachments `Muzzle` (LookVector out of the bore), `PistolGrip`, `Hammer`. Pelvis attachment
  `PistolHolster` (-Z down into the sheath on his left hip) for stowing it.
- `Compass` (Pelvis -> CompassRoot, the face looks -Z) and `CompassLid` (hinged at the top, built OPEN; rotate it
  180 degrees about its X axis to close). Attachments `CompassFace`, `CompassGrip`.
- Coat tails: 10 panels round the hips (open at the front), `Tail1..10` from the pelvis, the 8 long ones with a lower
  segment `Tail<i>_2`; attributes `TailIndex`, `Segment`, `CoatAngle`. Seaweed and chains are welded.
- Eye light: attachment `EyeLight` on Head; the soul light sits on `SoulHot` in the chest.

### Palette (as built)

Coat 20,25,26 / raised 34,42,42 / deep 10,15,17; lining 25,65,59; bone 184,179,151 (dark 136,128,104); brass
137,111,64; iron 42,48,48; verdigris 50,90,77; soul 40,225,165 with a 200,255,232 core; barnacles 100,97,83 with dark
slit mouths. Neon only in the eyes, chest, cutlass edge and compass needle.

### Verified (Studio, 2026-10-17)

- Builder report clean over 6 rebuilds (same count each time, no duplicates); soles exactly on y = 0.
- `check_orvoss`: ScaleTo 0.4 plus a 73 degree turn gives a worst offset of 0.0001 studs. RShoulder raised 150
  degrees carries blade, guard, epaulette, cuff and fingers. LShoulder aimed carries pistol and hammer. Hat, Jaw,
  CompassLid and Neck carry their parts. Raised cutlass tip ends 2.2 studs above the hat; the aimed pistol's hammer
  stays clear of the neck.
- Screenshots of the front three-quarter, rear, head, both hands and the raised pose, beside Malak and Veyr, under the
  plaza lighting.

### Not verified / known issues

- Not checked: an animated idle (none exists), UnitPortrait framing in a real ViewportFrame, the hotbar / held copy /
  army path (no unit def yet).
- The tricorn reads a bit small and flat at eye level compared with the art. Barnacles were reworked once because
  they looked like eyes; check them up close.
- At rest the hands are fairly close to the coat. The pistol is rather long and its grip is hard to see from the front.
- The tails' clearance was only checked by eye (rest pose and a spread pose), not tested in motion.

## Idle animation (2026-10-17, built and approved by the user, 04591f8)

`src/client/Modules/AdmiralAnimator.lua` (Pose "Admiral", called from UnitAnimator like Veyr's module): the deck roll
(6.6 s, feet planted by leg IK, skull level), underwater coat tails on soft springs, heavy arms with the cutlass and
flintlock lagging on their own springs, and the three gestures (brim push by left-arm IK onto the hat, listening,
compass glance with the needle on its new `CompassNeedle` joint). Walk = the generic stride blended in. Dev
attributes on the model: `DevGesture` (1 brim, 2 listen, 3 compass plays it now), `AnimTimeScale` (slow motion).
Tested on `Workspace.OrvossPreview` (tag it `ProceduralUnit` on the client in play mode): no errors; each gesture
checked by a frozen screenshot. Not checked: the motion's feel in real time, the army walk, portraits.
The user asked for a normal weapon hold: both weapons now hang down and forward at his sides (grips at x = +-1.12),
and both fists have the palm on the outside of the grip (back of the hand outwards); the pistol hand's index finger
is curled round the grip like the others (the straight trigger finger looked wrong). 717 parts, 41 motors now.

### The agreed spec

Agreed with the user: the base layer plus gestures 1, 3 and 4 (the hammer check is dropped: too small to read).

- New `Pose = "Admiral"` branch in `src/client/Modules/UnitAnimator.lua` (or its own module like
  `MarksmanAnimator` once attacks exist); set the Pose attribute in `build_orvoss.lua`. All motion on springs or smooth
  continuous curves, never snapping back to rest (Knell's rule); make the first pass slower than seems right.
- **Base layer, "sea legs":** a slow deck roll (weight shifting side to side, a little fore and aft, a period of about
  6-7 s; hips and chest out of phase, the knees giving slightly). The skull counters the roll and stays level, like a
  sailor keeping the horizon. The coat tails drift as if underwater (soft, slow, low-damping springs, each panel out of
  phase, a gentle lift / spread / settle; use the `Tail<i>` / `Tail<i>_2` joints and `CoatAngle`). The weapons hang
  heavy; the cutlass tip lags the roll.
- **Gestures**, one every 10-15 s at random, never the same twice in a row:
  1. Brim push: he raises the flintlock and pushes the hat brim up with the barrel (a small Hat joint lift), then
     lowers it slowly.
  3. Listening to the fleet: the head turns slowly to one side and up, holds about 2 s, the jaw opens a hair as if
     about to give an order, then returns.
  4. Compass glance: the head tilts down to the open compass on the belt; the needle twitches towards the gate (the
     needle is welded to CompassRoot now: give it its own small joint if needed).
- Test it on `Workspace.OrvossPreview` / the animated portrait. A preview loop and UnitAnimator must never both write
  the same joint. The army walk can stay generic for now.
- Also look at the coat tails from behind first: they were widened after the last rear screenshot.

## Basic attack: DOUBLE REPORT (built 2026-10-17, first pass approved for now)

Name and the cannon's side (his left, a little behind) chosen by the user. Shared `AdmiralTimeline` (beats in s after
the server's `AttackAt`, a model attribute the generic attack in `Army` now sets for every unit): aim 0.1-1.0, the
cannon forms 0.4-1.6 (barrel, then carriage, rising out of fog with upward drips), hammer 1.7-2.05, fuse 1.8, FIRE
2.4, IMPACT 2.6 (= `Units.Orvoss.hitDelay`, ONE hit; a fast flight, the user's call), the cannon sinks 3.2-4.4, the pistol lowers 3.0-5.0;
attackCD 7, damage 595K (85K DPS). Body: `AdmiralAnimator` (side-on turn over planted feet, left arm IK lays the
barrel on `AimPos`, cutlass arm sinks back, hammer joint `PistolHammer`, the kick throws the muzzle up and rocks him
back). Effects: client `DoubleReport.lua` (one ghost cannon per unit, see-through sea-green parts with a Highlight
outline; fog, drips, fuse sparks, muzzle flashes, smoke and sparks, the ball and the pistol shot with trails, the
big impact: flashes, a soul-green fireball, a shockwave ring on the wall, sparks, a dust cloud, stone chunks; `hitFx = "DoubleReport"` so HitEffects draws nothing). No sounds yet. Reviewed by the user
(fine for now): fixed the cannon dipping while it formed and the flintlock aiming too low.

### The original idea (the user's, 2026-10-17)

He takes aim and fires the flintlock while a ghostly cannon forms beside him and fires at the same moment. Proposed beats
(first pass slow, one attack every ~7 s): the pistol swings up and levels at the wall, side-on like a duellist (0-1 s);
sea-green fog and upward-dripping water form a see-through ghost cannon, barrel first, then the carriage (0.4-1.6 s);
stillness, the thumb cocks the hammer (`PistolHammer`), the fuse glows (1.6-2.4 s); both fire at 2.4 s (small pistol
flash, big cannon boom and smoke, the pistol kicks, the cannon rolls back); a glowing cannonball (with the pistol shot)
hits ~2.8 s as ONE hit; the cannon sinks into fog, he lowers the pistol slowly (3-5 s). Open: the cannon's side
(suggested his left, a little behind the pistol arm) and the name ("Dead Reckoning" is Veyr's; ideas: Double Report,
Gun Salute, Shot Across the Bow). Needs the unit def first. The ghost cannon model is reused in the finisher.

## The drowned fleet (first pass built 2026-10-17, waiting for the user's review)

`tools/studio/build_blackwake_fleet.lua` -> `ReplicatedStorage.ShipModels.BlackwakeFleet`: five warships from one
seeded builder, refined after the concept art `Images/Concept/Unit/Fleetship.png` (taken as inspiration, not exact):
Brig (737 parts, 1 gun deck), Frigate (844, 2), Galleon (849, 2, tall stern, snapped mizzen), Wreck (850, 2, snapped
main mast, three breaches, sails mostly torn), ManOWar (933, 3). Dark wet timber (greener below), tumblehome hull with
raised castles, heavy dark wales, a balustrade rail with brass posts; brass-framed gun ports glowing sea-green with dark
barrels run out (no lids); breaches held by soul-green ribs over a glowing inside, splintered planks round them; glowing
cracks; barnacle clusters with drowned skulls in a band along the lower hull, lots of hanging weed (bottom, wales,
bowsprit); a horned bone skull figurehead with an open jaw and bone ribs down the bow; quarter galleries of glowing
windows with brass trim, a skull on the stern, three brass lanterns (the big one has a PointLight); masts with brass
bands, fighting tops, ratlines, torn green translucent sails (one bellied canvas per yard, ragged strips), a pennant.
Contract: bow -Z, up +Y, origin at the
waterline amidships; `Root` anchored and invisible, everything welded to it; `PortGlow` parts (attributes Deck, Index
bow to stern, Side) and `Gun` barrels with a `Muzzle` attachment for the rolling broadside; `Hawse` attachment on Root
for an anchor chain; model attributes Length, Variant, GunDecks, PortsPerSide. `tools/studio/show_fleet.lua` stages
them high over the plaza in `Workspace.FleetPreview` (**delete before publishing**).

**The flagship** (same builder, variant `Flagship`, 1047 parts, first pass 2026-10-17, Claude's own design: the user
did not like the generated concept art): 290 studs, three gun decks of bigger ports (`portScale` 1.4), a drowned
copper bottom gone verdigris, a soul-light seam along the waterline, Orvoss himself as the figurehead (tricorn,
cutlass thrust forward), a great black main course with a bone skull-and-anchor, a three-row stern gallery, two
anchors on catheads with short chains, lanterns along the rails. Extra attachments on Root: `Bridge` (quarterdeck,
where Orvoss stands), `HawseL` / `HawseR` (the anchor rings). Not checked up close: the figurehead, the stern, the
emblem. Not yet: the separate anchor + chain model for the finisher, the ghost cannon.

## Finisher models (estimate, 2026-10-17)

New: the flagship (hero model, detailed broadside with stacked gun decks, ports lighting bow to stern; the biggest job,
needs a part budget), one fleet warship builder with variants (4-6 ships, simpler, seen further away), an anchor with
chain (reused several times). Reused: the ghost cannon, Orvoss (compass lid, hat, cutlass joints). Effects, not models:
fog, upward drips, the sky ocean, ship shadows, rigging, cannon fire, the whirlpool. Crews: start with light behind the
gun ports, a ghost-sailor model only if the close-ups need it. Order: anchor, warship, flagship.

## Character direction

A tall, lean skeletal pirate admiral commanding the ghost fleet that sank with him. Ruined charcoal naval greatcoat,
dark sea-green lining, weathered brass, exposed ivory ribs with green soul fire, severe skull with green eyes, broad
battered tricorn with skull-and-anchor badge, high collar, epaulettes, compass, sparse chains/barnacles/seaweed,
long torn coat tails, bracers, and buckled boots. The approved art shows the cutlass in his anatomical right hand and
the flintlock in his left. Base form follows the art; the level-10 shadow form is a later stage.

Future character animation hooks: pistol aim/recoil, raised/lowered command cutlass, closing compass lid, detachable
hat for a catch/reseat, jaw for a spoken order, cloth lag and spread during ascent. The model brief details carriers,
joint/attachment contracts, visual construction, a suggested 700-part allocation, and practical verification.

## Kit brainstorm (not implemented)

- Basic: a heavy flintlock shot with a spectral cannon barrel briefly forming around the weapon.
  The brainstorm name "Dead Reckoning" conflicts with Veyr's existing basic attack; rename before implementation.
- Special: "Warning Shot": a ghost frigate emerges beside the lane and fires a rolling broadside, then departs into fog.
- Arrival: an anchor lands beside the grave, its chain pulls taut overhead, a wreck emerges, and Orvoss descends on the chain.

These are design context; finish and review the character model before implementing this kit.

## Agreed finisher concept: The Last Broadside

Approximately 65 seconds, still a concept. Orvoss closes his compass; water drips upward from his coat and black fog
rolls toward the gate while the army withdraws. Ship shadows pass beneath the lane; an anchor lands beside the gate.
A spectral black ocean appears in the sky, and the drowned fleet emerges, with broken hulls held together by ghost
light. His flagship arrives, crews load guns, and ships turn broadside. Orvoss ascends on spectral rigging, raises his
cutlass, and gives the proposed order "Give them the deep." Staggered rolling broadsides bombard the gate. Afterwards,
the anchors pull taut as the fleet sails away, dragging the ruined gate into a whirlpool. The ocean closes; Orvoss
lands and catches/reseats his hat. Distant bells, creaking timber, silence before the order, and heavy sequential
cannon reports establish the sound direction. No audio assets or final timing have been made.

**User's explicit camera correction:** the enormous ship SIDES and stacked gun decks must be visible, rather than
mostly undersides. Place the ocean/horizon high beyond the gate, angled toward the battlefield. The flagship crosses
in front of Orvoss, slightly overhead and to one side; a low three-quarter shot reveals its bow and long broadside.
Keep Orvoss tiny in the foreground for scale. Ships face their gun sides toward the gate, with the camera outside the
firing corridor looking diagonally along several broadsides. Track alongside the flagship as gun ports ignite from
bow to stern. This replaces the earlier emphasis on an upside-down overhead ocean/underside reveal.

Future implementation must use the existing server-authoritative gate finisher arbitration and plot-local geometry;
the model brief does not implement or change either system.
