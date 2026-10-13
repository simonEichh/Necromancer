# Sounds

Drop each file in its folder with exactly the name below (`.ogg` or `.mp3`). The code layers them per
animation, so every sound is short and reusable. Missing files are fine: that slot is silent until it exists.

**Rules for every file**
- No silence at the start (trim it, or hits feel late). A little tail at the end is fine.
- Loops must loop seamlessly (no click at the seam) and have no fade-in or fade-out.
- Similar loudness for all files. Volume and pitch are balanced in code.
- Mono for sounds that come from a spot in the world (`loops`, `impacts`, `graves`, `magic`, `units`); stereo is fine
  for `stings`, `ui` and `music`.
- Upload: `python tools/audio/upload_sound.py sounds/<folder>/<file>.ogg` (Open Cloud, key in tools/audio/.roblox_api_key,
  git-ignored), then put the id in the table and in `src/client/Modules/Sfx.lua`.

Priority: **A** = needed for the basic cinematics, **B** = makes them much better, **C** = nice to have.

## loops/ (2-5 s, seamless)

| File | Length | Sound | Used in | Prio | Asset id |
|---|---|---|---|---|---|
| `rumble.ogg` | 3-5 s | deep earth rumble, stone grinding | grave rising and shaking (all cinematics) | A | 110236453654824 |
| `charge.ogg` | 2-4 s | magic energy building up, rising hum | buildup before every burst, star aura, sky orb | A | |
| `circle_hum.ogg` | 3-5 s | low mystical drone / choir pad | magic circles (Descent cone, Void summon) | B | |
| `wind.ogg` | 3-5 s | howling magical wind | Descent charging, star falling | B | |
| `beam.ogg` | 2-3 s | crackling energy beam | Void summon beam, Last Lantern ray | C | |
| `fire.ogg` | 2-4 s | burning fire / soul fire | falling star trail | C | |

## impacts/ (0.3-2 s)

| File | Length | Sound | Used in | Prio | Asset id |
|---|---|---|---|---|---|
| `burst_small.ogg` | 0.5-1 s | earth/stone bursting open, light | grave burst, low rarities | A | |
| `burst_big.ogg` | 1-2 s | huge explosion with a magic tail | grave burst, high rarities | A | |
| `star_impact.ogg` | 1-2 s | meteor crash, deep boom | star summon crash | A | |
| `beam_strike.ogg` | 0.5-1.5 s | lightning / energy blast hitting the ground | Void summon strike | B | |
| `whoosh.ogg` | 0.5-1 s | fast whoosh | star falling, camera swings, Descent fall | B | |
| `shockwave.ogg` | 0.5-1 s | air pressure wave / boom | shock rings, Descent landing | C | |

## graves/ (0.2-1.5 s, the opening styles)

| File | Length | Sound | Used in | Prio | Asset id |
|---|---|---|---|---|---|
| `stone_crack.ogg` | 0.2-0.6 s | stone cracking (several variants ok: `stone_crack2.ogg`...) | buildup cracks, all graves | A | |
| `lid_slam.ogg` | 0.5-1 s | heavy stone slab thrown / landing | Stone, Ancient, Abyssal (lid flies off) | A | |
| `door_fall.ogg` | 0.5-1 s | heavy stone door falling flat | Cursed Crypt | B | |
| `door_swing.ogg` | 0.5-1 s | heavy iron doors bursting open, bang | Shadow Vault, Celestial Abyss | B | |
| `chest_creak.ogg` | 0.5-1 s | heavy chest lid creaking open, thud | Eldritch Reliquary | B | |
| `chains_break.ogg` | 0.3-0.8 s | chains snapping, rattling | Cursed Crypt | C | |
| `levitate.ogg` | 1-2 s | holy rising shimmer | Eternal Throne lid lifting | C | |
| `earth_debris.ogg` | 0.5-1 s | dirt and pebbles falling | Mossy mound, debris landing | C | |

## magic/ (0.3-2 s)

| File | Length | Sound | Used in | Prio | Asset id |
|---|---|---|---|---|---|
| `circle_open.ogg` | 0.3-1 s | magic circle snapping open, chime | every magic circle (Descent, Void summon) | A | |
| `portal_open.ogg` | 1-2 s | dimensional rift opening | Descent portal | B | |
| `flare.ogg` | 0.5-1 s | bright magical flare / shine | star flares, Void coffin casting | B | |
| `sparkle.ogg` | 0.5-1.5 s | glittering sparkles | gold sparks, star sparkles | C | |
| `halo.ogg` | 0.3-0.8 s | soft ring / bell | circles collapsing into halos (Descent) | C | |

## units/ (0.3-2 s)

| File | Length | Sound | Used in | Prio | Asset id |
|---|---|---|---|---|---|
| `materialize.ogg` | 1-2 s | shimmering materialize / power-up | Void summon, unit appearing | A | |
| `rise.ogg` | 1-2 s | dirt shifting, unit climbing out | units rising from graves | B | |
| `land.ogg` | 0.3-0.6 s | heavy footstep / thud on stone | hop-out, walk-out, Descent landing | B | |
| `souls.ogg` | 1-2 s | ghostly whispers / wails | soul particles, grave glow | C | |

## stings/ (1-3 s, musical hit when the unit is revealed)

| File | Length | Sound | Used in | Prio | Asset id |
|---|---|---|---|---|---|
| `reveal_low.ogg` | 1-2 s | short dark reveal hit | Common - Rare | A | |
| `reveal_mid.ogg` | 1.5-2.5 s | bigger reveal, a bit of choir | Cursed - Abyssal | A | |
| `reveal_high.ogg` | 2-3 s | epic reveal, choir and brass | Eldritch - Primordial, Signatures | A | |
| `fakeout.ogg` | 0.5-1 s | sound sucked out / reverse swell | the silent fake-out before big bursts | B | |

## ui/ (0.1-0.5 s, stereo ok)

| File | Length | Sound | Used in | Prio | Asset id |
|---|---|---|---|---|---|
| `collect.ogg` | 0.2-0.5 s | satisfying collect / coin chime | Collect button | A | |
| `click.ogg` | 0.1-0.2 s | soft stone click | Continue, Skip, buttons | B | |

## music/ (optional, stereo)

| File | Length | Sound | Used in | Prio | Asset id |
|---|---|---|---|---|---|
| `descent_loop.ogg` | 10-20 s, seamless | dark epic loop | The Descent (looped, then the reveal sting on top) | C | |

Everything scales with the pull's rarity in code (pitch, volume, how many layers), so one version of each sound is enough.

## Preparing files

Originals go in `_source/` (kept, not uploaded). `tools/audio/prep_sound.py` makes the game versions:
- `python tools/audio/prep_sound.py info sounds/_source/x.wav` shows channels, length, levels and loudness over time
- `python tools/audio/prep_sound.py loop sounds/_source/x.wav sounds/loops/x.ogg [--length 4] [--start 6]` cuts a
  seamless mono loop from the steadiest stretch (or from --start seconds)
- `python tools/audio/prep_sound.py shot sounds/_source/x.wav sounds/impacts/x.ogg [--max 2]` trims the silence at the
  start, mono, peak -1 dB

Done: `loops/rumble.ogg` (from `_source/rumble.wav`, 16.9 s stereo: 4 s mono loop cut from 6.0 s;
`_source/rumble_looptest.ogg` plays it 4 times to check the seam).
