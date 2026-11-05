# Lanthe, the Last Vigil (planned fifth Sovereign)

Concept by the user on 2026-11-05: "a unit like the E33 Lampmaster" (Clair Obscur: Expedition 33). Reference images in
`Images/Concept/Unit/` (`Coe33_Lampmaster.webp`, `lampmaster2.jpg`, `lampmaster3.webp`). The model is built and the user
liked it; nothing else exists yet (no `Units.lua` entry, no animation, no attacks).

## What we took from the Lampmaster

Upside down, too many thin limbs (six arms), every hand holding something (lanterns, a staff), a shaggy black mantle and
hair, pale ashen skin with bandaged wrists / ankles, white-gold ribbons of light round it, floating.

## The character

The keeper of the graveyard lights: she lit one lantern for every soul buried. When the lights ran out she kept watching,
and she still hangs there in the dark.

- **Silhouette (our own, not a copy):** she HANGS head-down like the Hanged Man of the tarot, the right ankle chained to
  the crook of a tall wrought-iron lamp-post that floats with her, the left leg folded behind the right knee (a "4").
- **Six arms:** five lanterns (the "souls") and a grave-digger's shovel instead of the Lampmaster's blades (ties her to
  the graves). Low pair + side pair: lanterns; upper left: a lamplighter's pole with a lantern on its hook; upper right:
  the shovel, blade up.
- **The Vigil Lamp:** a sixth, big lantern hanging from the crook in front of her (the finisher's pendulum).
- Black rag robe falling down over the torso from the waist, a shaggy ruff, black hair hanging from the crown toward the
  ground, the face wrapped in bandages with a single slit and a candle-flame eye, threads of pale light from every
  lantern to its wrist.

## Planned stats and abilities (proposal, not built)

- Sovereign, Primordial, Celestial grave only, pool weight 0.05, 85K DPS like the other four, fixed post
  (`infiniteRange`, like Hush / the Sigilwright), commander throne.
- **Passive "Every Lantern":** each lantern is a soul; while all five are lit the army deals a bit more damage.
- **Special "Snuff":** she puts out one lantern, the lane goes dark for a beat, then an orb of white light flies at the
  wall and bursts (the Lampmaster's light ball).
- **Finisher "The Vigil Ends":** the sky darkens, hundreds of lanterns rise from the ground (one per dead soul), every
  light goes out at once, and in the dark the Vigil Lamp swings down like a pendulum, cuts through the gate and bursts
  into light.

## Model (done 2026-11-05, first pass, liked by the user)

`tools/studio/build_lanthe.lua` -> `ServerStorage.Models.Lanthe`, ~723 parts, 41 joints, height 14.3, `RootHeight` 7,
`Float` 0.25, built in its final hanging pose (head at the bottom). Rig and joints: see `docs/models.md` ("Lanthe").
Preview copy `Workspace.LanthePreview` (anchored, y 300 above the plaza): delete before publishing.
How it was run: the MCP no longer allows `HttpService` to 127.0.0.1, so the script was copied to
`src/shared/TempBuildLanthe.lua`, synced by Rojo, `require`d in Edit mode, then the temp file was deleted.

Open: the held lanterns read a little small / dim from far away; the folded leg is mostly hidden behind the body.

## Next steps (agreed order, one at a time)

1. Optional visual pass (bigger / brighter held lanterns, the folded leg more visible).
2. `Units.lua` entry + `publish_unit_models.lua`, so she can be spawned from the DEV panel.
3. Her own Pose in `UnitAnimator` (a `Vigil` module like `AdmiralAnimator`): a slow pendulum swing about the `Hang`
   joint, lanterns swaying on their joints, hair and robe drifting; smooth, momentum-driven (the animation rule).
4. Basic attack, the Snuff special, then the Vigil Ends finisher.
