# Orvoss, the Blackwake

## Status (2026-10-17)

The base character model is built (model only). Not done: unit definition, stats, odds, animations (no `Pose`, so he
stands static), attacks, the awakened form, fleet / arrival / finisher.

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
