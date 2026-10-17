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

## malak/ (Malak, the Envoy: his attacks and the Fleet Strike; docs/envoy.md)

Tone: cold, precise, HIGH-TECH (not magic): clean synthetic tones, servo whirs, sub bass, glassy UI blips. The only
"warm" sounds are the explosions. Mono unless marked stereo (stereo = played flat for the cutscene's owner).

**His basic attack and the drone** (every 6.5 s / 4.5 s, so they must not get tiring: short, dry, a little variation)

| File | Length | Sound | Used in | Prio | Asset id |
|---|---|---|---|---|---|
| `holo_open.ogg` | 0.3-0.6 s | hologram opening, soft digital shimmer | his pad opening into the big hologram | B | 134658410245808 |
| `holo_tap.ogg` | 0.1-0.3 s | crisp glassy touchscreen tap | the press on the hologram | A | 107161022622819 |
| `target_lock.ogg` | 0.3-0.6 s | targeting lock-on: two rising blips, a confirm tone | reticle locking on the wall | A | 130032888810460 |
| `laser_hum.ogg` | 2-3 s loop | thin electric hum of the red targeting laser | while the laser is on the wall | B | 109042425391276 |
| `cannon_far.ogg` | 1-2 s | a far-away heavy gun firing high up in the sky (distant thump with a long tail) | the gunship fires | A | 131391741535295 |
| `shell_whistle.ogg` | 0.6-1 s | a fast descending whistle / incoming shriek | the shell coming down | A | |
| `shell_impact.ogg` | 1-2 s | heavy explosion, crunch of stone, debris | the shell hits | A | 81958184521977 |
| `drone_charge.ogg` | 0.5-0.8 s | three quick rising charge blips | the drone's rings charging | B | 101800259271161 |
| `drone_bolt.ogg` | 0.2-0.4 s | short sharp energy zap (played 3x, staggered) | the drone's bolts | A | 77110040590592 |
| `drone_hit.ogg` | 0.3-0.6 s | cold crack / energy pop | where the bolts meet | B | 99175078643431 |

Done 2026-10-15 (originals in `_source/malak/`, adapted with prep_sound.py): cannon_far cut to 2.5 s, drone_bolt to
0.6 s (played 3x, rising pitch), drone_charge to 0.8 s (played 3x as rising blips), drone_hit to its first 0.4 s,
shell_impact to 3 s, laser_hum a 2.5 s loop; shell_whistle: the generated placeholder (tools/audio/make_whistle.py)
sounded off and is switched off (empty id): the slot waits for a real one. Wired in client OrbitalStrike.lua through Sfx.playAt / Sfx.loopAt.

**The Fleet Strike** (54 s; times are seconds from its start; each is one moment, so they can be big)

Voice lines (2026-10-15, assignment corrected by the user): **"High Command. Grant us passage."** uses
`high_command_passage.ogg` (3.38 s, asset `137755688226874`, Sfx slot `voice_call`) at 5.37 s. Original:
`_source/malak/high_command_passage.mp3`, prepared with `prep_sound.py shot`. **"Absolution. Deliver my verdict."**
uses `voice_verdict.ogg` (3.81 s, asset `98769145369327`) at 41.69 s: this is the former opening clip, originally
uploaded as `voice_call.ogg`. The old presence-required clip (`122907832067254`) is no longer cued. Leading silence
trimmed, peak normalized, original pitch and pauses kept. Played flat for viewers only, through Effects; music drops
to 30% during speech. The call ends before the drone pulse; the verdict ends half a second before the main beam.
FleetStrike.lua also carries the matching military-style typewriter subtitles and phrase pauses. Cue lengths and
subtitle timings must match these files if replaced.

Final standing shot: `voice_defiance.ogg` (2.06 s, asset `105269459367929`) at 51 s, **"Their defiance was noted."**
Source: `_source/malak/defiance was noted.mp3`, prepared with `prep_sound.py shot`; original pitch retained.
Ends before the cutscene's 54 s finish, with the same watcher-only playback, music duck and typewriter subtitles.

| File | Length | Sound | At | Prio | Asset id |
|---|---|---|---|---|---|
| `rune_click.ogg` | 0.1-0.2 s | tiny precise click (several variants ok) | his left hand typing (1.5-5 s) | B || 129592415819508 |
| `rune_confirm.ogg` | 0.4-0.8 s | a clean confirm tone, slightly ominous | the last rune clicks home (5.3 s) | A || 80333702320714 |
| `drone_transform.ogg` | 1.5-2.5 s | mechanical servos, rings locking, rising whine | the drone stacking into a transmitter (6-8 s) | A || 71750103238347 |
| `transmit_pulse.ogg` | 1.5-3 s | a powerful pulse shooting upwards, then fading pings (stereo) | the pulse into the sky (9.0 s) | A || 120112861024931 |
| `sky_tear.ogg` | 4-6 s | the sky tearing: a deep groan, crackling, glass-like cracks (stereo) | the tear (13-19 s) | A | |
| `portal_hum.ogg` | 3-5 s loop | deep unstable hum of the open portal | while the portal is open | B || 133901763364756 |
| `warp_in.ogg` | 8-10 s | the big one: a slow sub-bass swell, pressure building, metal groaning (stereo) | the Absolution sliding out (20-29.5 s) | A || 3 layers: suspense 84069854063299, scanner 132548472903596, warhorn 83144722290957 |
| `portal_snap.ogg` | 1.5-3 s | the portal slamming shut + a shockwave boom (stereo) | the snap (29.8 s) | A || 108174408928980 |
| `ship_hum.ogg` | 4-6 s loop | the ship's engines: a low, massive drone | while the ship is in the sky | B || 93352074241039 (ship_hum2: 125935309800038) |
| `scan_sweep.ogg` | 2-4 s | a scanning sweep, electronic (stereo) | the red scan fan (32-35.6 s) | B || 132910803481650 |
| `turret_turn.ogg` | 0.5-1 s | heavy turret servo turning | the turrets turning (31.3 s on) | C || 124298652524588 |
| `broadside.ogg` | 1-2 s | heavy naval guns firing in a salvo (played per salvo) | the barrage (38-42 s) | A | |
| `missile_launch.ogg` | 0.5-1 s | missile launch whoosh | the missiles (38.4 s on) | B || 87074924125787 |
| `bow_open.ogg` | 1.5-2.5 s | huge armour plates unlocking and sliding apart, hydraulic hiss | the bow opening (42.2-43.8 s) | A || 75819785753943 |
| `reactor_spin.ogg` | 2-3 s | rising turbine whine, ending in a heavy lock (clunk) | the rings spinning up and locking (42.4-45.6 s) | A || 2 files: reactor_windup 80732352001103, reactor_lock 109134827602753 |
| `cannon_charge.ogg` | 1.5-2 s | charge building to a peak that CUTS OFF (the half second of silence) | the charge (44.4-46 s) | A || 136468737245177 |
| `main_beam.ogg` | 3-4 s | the beam: a massive roar with crackle, sustained (stereo) | the beam (46-49.4 s) | A || 95516675338021 |
| `keeper_roar.ogg` | 1-2 s | the keeper's pained roar (deep, inhuman) | his palms are struck (46 s) | B || 130529185820696 |
| `gate_collapse.ogg` | 2-3 s | the gate exploding and collapsing: stone, crash, rumble (stereo) | the gate falls (49.4 s) | A || 79285090609348 |
| `warp_out.ogg` | 3-5 s | low boom as the portal collapses behind the leaving ship | the warp-out | B || 77036647861580 |

Done 2026-10-15 (originals in `_source/malak/`, all stereo and played flat; the cue sheet is "Step 8" in
FleetStrike.lua): rune_click cut to 0.3 s (played at his two taps, 3.11 and 4.08 s, and softer where the drag starts), transmit_pulse whole (5.9 s, 1.5 s fade, the swell covers the rising rings),
portal_hum a 5 s loop (open 16.4-29.8 s, and again for the warp-out portal), the warp-in is three layers (suspense at 19,
scanner at 20, warhorn at 21.5; each cut to 7 s), portal_snap 6 s (also when the warp-out portal shuts), ship_hum a 3.5 s
loop and ship_hum2 a 6 s loop (compare them with `SHIP_HUM` in FleetStrike.lua), scan_sweep 3.5 s at 32, turret_turn
2.5 s at 31.3 (quiet, 0.35; may be dropped). Second batch: missile_launch 1.5 s (4 launches from 38.4), bow_open spliced (its opening
clunk + the end clunk from 3.85 s, which lands 1.35 s in = the bow fully open), reactor_windup = 1-5 s of the original at
1.5x (42.4-45.0), reactor_lock cut to 0.8 s at 45.0, cannon_charge = only the build (3.0-7.35 s of the 10 s original) at
1.25x, hard cut at its peak 0.5 s before the beam (46), main_beam 4.3 s, keeper_roar and gate_collapse whole, warp_out
whole (replaces the portal snap when the ship leaves). After the user's first listen: drone_transform volume halved, target_lock (his basic attack's) plays at each reticle
locking on after the scan fan (LOCKS, rising pitch). The barrage plays cannon_far (his basic attack's gun) per salvo instead of broadside, and the missiles are
silent (the user wants only the distant cannons; missile_launch is uploaded but not cued). Second listen: drone_transform volume 0.12, transmit_pulse replaced by two layers (the user split it):
transmit_laser (10 s of _source/malak/transmit_pulse_laser.ogg, 1.5 s fade, at 9.0, volume 0.5) and sublift_scanner (9.9 s, 1.5 s fade, at 9.0,
volume 0.6, full until the void opens at 17.4, then fading out by 18.9), turret_turn not cued (too far to hear servos), shell_impact (his basic attack's) at the barrage's shell
and missile hits (boom() in FleetStrike.lua, at most one per 0.12 s, lower pitch). sky_tear is three files: tear_rumble (6 s from 0.5 s of
_source/deep_tear_rumble_thunder.ogg, 2 s fade, at 13), tear_crack (from 0.45 s, at 15.2), tear_open (a swell from 0.5 s,
2.54 s, timed so its peak lands on OPEN_AT 17.4; taken out again after a listen: uploaded, not cued). Volumes after
listening: tear_crack 0.2, bow_open 0.4. Music: _source/malak/fleet_music.ogg (76.7 s) cut to its first
52.5 s with a 2 s fade (`malak/fleet_music.ogg`), played from 1.5 s through Sfx.music (Music group), only for whoever
watches, ducked to silence 45.5-46 s (before the beam). A first try: not cut to the beats yet.

**Music (optional but the biggest win): `fleet_music.ogg`, stereo, ~54 s, timed to the beats** (no loop):
0-1.5 silence falls; 1.5-6 calm, precise (he types); 6-11 tension rises with the transmitter, pulse at 9.0; 11-13 the
army flees (unease); 13-19 dread builds (the sky tears); 20-29.5 the slow, heavy reveal of the ship, a big hit at the
snap (29.8); 31-36 cold, mechanical (scan, lock-ons); 36-38 a breath; 38-42 full force (barrage); 42-46 rising, unbearable
(the bow, the charge) and then SILENCE for ~0.5 s before 46; 46-49.4 the beam; 49.4 the gate falls (biggest hit);
50-54 a calm, cold resolve (he looks at what is left).

## veyr/ (Veyr, the Last Sight: docs/veyr.md)

His sound: quiet, precise, supernatural. One sharp event surrounded by silence, never noisy or busy. Every sound gets a
cold glassy or soul-light layer (a ring, a shimmer, a breath) on top of the physical sound. No sci-fi lasers, beeps or
mechanical servo whirs (that is Malak). Mono, one-shots trimmed tight at the start. The `Sfx` name is the slot in
`src/client/Modules/Sfx.lua`; "placeholder" means a borrowed sound plays there for now.

| File | Sfx slot | Length | Sound | Used in | Prio | Search terms |
|---|---|---|---|---|---|---|
| `crack.ogg` | `veyr_crack` (empty) | 1-2.5 s | one heavy rifle shot: a sharp, dry crack, then a short ghostly tail (a whoosh or shimmer that rings out) | every basic shot, the special, the finisher's shot | A | "sniper rifle shot", "rifle crack reverb tail", "magic gunshot", "arcane shot" |
| `ring.ogg` | `veyr_ring` (placeholder: rune_click) | 0.2-0.6 s | a small glassy "tink": crystal, a tuning fork, a wine glass struck lightly | each sight opening, the shards clicking in, the glints, the tink after the bolt | A | "glass tink", "crystal ping", "magic chime short", "glass clink" |
| `bolt.ogg` | `veyr_bolt` (empty) | 0.8-1.3 s | a bolt-action cycle: lift, back, forward, down (four clean metallic clicks/slides), heavy and old, not tactical | after every shot, his pull, the finisher's reload | A | "bolt action rifle reload", "bolt cycle", "rifle bolt" |
| `impact.ogg` | `veyr_impact` (placeholder: shell_impact) | 0.5-1.5 s | a puncture: a sharp hit into stone, then a low thud/tail, no big explosion | where his round lands, the grave burst in his pull | A | "bullet impact stone", "heavy impact punch", "magic impact" |
| `charge.ogg` | `veyr_charge` (empty) | 2-4 s | a rising inward tone: energy being drawn in, a reversed shimmer, a swell that ends abruptly | the special's build-up, the finisher's charge, before the shot in his pull | B | "reverse whoosh", "magic charge up", "energy build up", "riser" |
| `collapse.ogg` | `veyr_collapse` (empty) | 1.5-3 s | a deep implosion: air sucked in, then a low soft boom; a dark soul-like tail | the special's fracture, the gate turning to ash | B | "implosion", "deep boom", "magic implosion", "sub drop" |
| `ash.ogg` | (new slot) | 2-4 s | stone crumbling to dust, a dry hiss and rustle like sand blown away, a faint ghostly whisper in it | the gate turning to ash (finisher) | B | "stone crumble dust", "disintegrate", "sand dissolve", "dust blow away" |
| `claws.ogg` | (new slot) | 1-2 s | bony fingers scraping and clawing out of earth, cracking soil | the skeletal hands tearing the slit open (pull) | B | "skeleton hands dirt", "zombie rising from grave", "bone scrape dirt" |
| `ignite.ogg` | (new slot) | 1-2 s | a deep "whoomp" of soul fire catching, a breath of air outward | his eyes ignite, the ring of light (pull) | B | "magic ignite whoosh", "soul fire burst", "fire whoomp" |
| `cloth.ogg` | (new slot) | 0.5-1.5 s | a heavy cloak snapping out in a gust | the mantle flaring out like wings (pull) | C | "cloak flap", "cape whoosh", "cloth flutter heavy" |
| `glint.ogg` | (new slot) | 0.3-0.8 s | a bright sparkle "shing", like light catching a lens or a blade | the scope glints, the field of echoes (pull) | C | "glint sparkle", "shine sound effect", "sparkle shing" |
| `rift.ogg` | (new slot; now tear_rumble / tear_crack) | 1.5-3 s | a thin, dark tear in the air: a low rumble and a crack, quieter and narrower than Malak's sky tear | the far opening in his pull | C | "dimensional rift", "portal tear", "reality crack" |

Done: `voice_arrival.ogg` (pull: "Death is just the distance between us."), `finisher_seat.ogg` ("One round. That is all
you deserve."), `finisher_bang.ogg` ("Bang."), `finisher_turn.ogg` (cut, not cued); originals in `_source/veyr/`.

## Preparing files

Originals go in `_source/` (kept, not uploaded). `tools/audio/prep_sound.py` makes the game versions:
- `python tools/audio/prep_sound.py info sounds/_source/x.wav` shows channels, length, levels and loudness over time
- `python tools/audio/prep_sound.py loop sounds/_source/x.wav sounds/loops/x.ogg [--length 4] [--start 6]` cuts a
  seamless mono loop from the steadiest stretch (or from --start seconds)
- `python tools/audio/prep_sound.py shot sounds/_source/x.wav sounds/impacts/x.ogg [--max 2]` trims the silence at the
  start, mono, peak -1 dB

Done: `loops/rumble.ogg` (from `_source/rumble.wav`, 16.9 s stereo: 4 s mono loop cut from 6.0 s;
`_source/rumble_looptest.ogg` plays it 4 times to check the seam).
