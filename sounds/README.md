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

**His finisher's own sounds (2026-10-17): all in but `cracks.ogg`** (prepared: `buildup` cut at its peak, 5.1 s,
stereo, ends on the shot; `ambience` 24 s / `aura` 8 s / `moon` 8 s seamless loops faded in and out under the beats
(watchers only, the ambience dips in the stillness); `launch` 1.6 s, `rifle_slide` 1 s, `circle`, `laser` 1.2 s, `wind`
3.25 s (peaks ~3 s in, when the ash wave reaches him), `rocks` 3.5 s, `breath` 2 s; ids in `Sfx.lua` veyr_*).
The original request: The Final Horizon has sound on only a few beats; these fill
the rest (the existing sounds stand in where one is missing). Drop them in `_source/veyr/` (any name, say which is which).
Search terms are Splice-style tags (sound categories, not descriptions); combine one with a mood tag like "dark",
"cinematic", "horror" or "trailer", e.g. "dark whoosh", "cinematic sub drop".

| File | Length | Sound | Used in | Prio | Search terms |
|---|---|---|---|---|---|
| `buildup.ogg` | ~6 s, stereo | a short, rising build-up that cuts off hard at its peak (no music under the rest) | the charge into the stillness, ends right before the shot (about 24 .. 30) | A | "string crescendo", "tremolo crescendo", "orchestral swell minor", "shepard tone riser", "rising glissando strings", "cluster crescendo", "brass crescendo stop" |
| `ambience.ogg` | 20-40 s, seamless loop, stereo | a dark, low, steady bed under the whole finisher: a cold wind, a distant drone, a faint hollow choir; no melody, no beat | the whole finisher, quiet, for whoever watches | A | "minor drone", "pedal tone drone", "low cello drone", "dark ambient pad", "phrygian drone", "dissonant pad", "cluster chord pad", "tremolo strings pianissimo", "sul ponticello strings", "evolving pad minor" |
| `launch.ogg` | 1-2 s | a powerful upward launch: a burst of air with a rising whoosh | he launches into the sky (ASCENT 7.5) | A | "whoosh", "riser whoosh", "swoosh up", "air burst", "cinematic whoosh", "transition fx up" |
| `cracks.ogg` | 2-4 s | stone cracking slowly, with a glassy crackle in it | the crack web spreading over the gate | A | "foley crack", "ice crack", "glass foley", "crackle texture", "granular texture", "debris foley" |
| `rifle_slide.ogg` | 1-2 s | a heavy metal piece sliding out and locking, an arcane shimmer on it | the giant rifles slide out of their circles (GIANTS_OUT 14.5) | A | "sword shing", "metal foley", "blade swipe", "metallic impact", "shimmer", "reverse cymbal" |
| `moon.ogg` | 2-4 s | a deep, dark swell: a low choir or drone | the moon appears behind him (MOON 10.5) | B | "choir pad", "vocal pad", "dark drone", "swell", "reverse swell", "atmosphere pad" |
| `circle.ogg` | 0.5-1 s | a magic circle snapping open: a short arcane whoosh with a chime | the eight magic circles (ARSENAL 13) | B | "magic fx", "chime", "bell hit", "glass hit", "sparkle", "shimmer one shot" |
| `laser.ogg` | 0.5-1.5 s | a thin beam locking on: a short bright electric hum, not sci-fi | the targeting lasers reach the gate (LOCK 18) | B | "zap", "electric fx", "laser", "synth fx one shot", "glitch", "buzz" |
| `wind.ogg` | 2-4 s | a long gust of wind rushing past | the ash wave blowing down the lane past him | B | "wind", "whoosh", "noise sweep", "white noise riser", "downlifter", "air texture" |
| `aura.ogg` | 3-5 s, seamless loop | a low rumbling energy hum | his charge aura while the rocks circle (AURA 5.5 .. STILL 27) | C | "drone loop", "hum", "sub bass drone", "dark texture loop", "pad loop", "rumble" |
| `rocks.ogg` | 1-3 s | rocks breaking loose and rumbling | the ground cracking under his perch, the rocks lifting | C | "debris", "rock foley", "rumble", "impact debris", "earthquake", "sub drop" |
| `breath.ogg` | 1-2 s | a deep, slow undead exhale, dry and hollow | the stillness, right before "Bang." | C | "breath", "vocal fx", "creature vocal", "growl", "exhale", "horror vocal" |

Done (2026-10-17, trimmed from the user's files in `_source/veyr/`): `crack` (1.8 s), `ring` (from 0.5 s, 0.6 s), `bolt`,
`impact`, `charge`, `collapse` (3 s), `ash` (3.5 s of 40), `claws` (3 s; really an undead howl, the user kept it),
`ignite` (from 0.85 s, just before its peak), `cloth`, `glint` (from 0.25 s: only the end of its reverse build-up, 0.55
s), `rift` (2.2 s, cued 0.6 s early so it builds into the opening); ids in `Sfx.lua` (veyr_*). Also `voice_arrival.ogg` (pull: "Death is just the distance between us."), `finisher_seat.ogg` ("One round. That is all
you deserve."), `finisher_bang.ogg` ("Bang."), `finisher_turn.ogg` (cut, not cued); originals in `_source/veyr/`.

## orvoss/ (Orvoss, the Blackwake: docs/orvoss.md)

His sound: heavy, wet, old wood and iron under the sea. Black-powder guns (deep booms, not modern gunshots), creaking
timber, chains, bells, water, and a hollow ghostly layer on top (underwater reverb, a low choir, a breath of wind).
Never bright or magical-sparkly (that is Veyr) and never sci-fi (that is Malak). Mono for one-shots in the world,
stereo for the finisher's beds. Drop them in `_source/orvoss/` (any name, say which is which); Claude trims and uploads.

Done (2026-10-17, from the user's files in `_source/orvoss/`, ids in `Sfx.lua` orvoss_*): `cannon` (1.8 s; Double Report and
every volley of the broadside), `anchor_drop` (4.5 s), `chain` (4 s), `bell` (4.4 s), `sea_rise` (6 s of a 15 s underwater
splash; the sea opening and closing), `ambience` (a 24 s mono loop cut from 18 s of the 61 s ghost-ship ambience).

**Basic attack, Double Report** (every 7 s, so keep them short and not tiring):

| File | Length | Sound | Used in | Prio | Search terms |
|---|---|---|---|---|---|
| `cannon.ogg` | 1.5-3 s | one black-powder cannon shot: a deep boom with a rolling tail | the ghost cannon fires (and every gun in the finisher) | A | "cannon shot", "cannon fire", "artillery boom", "black powder cannon", "pirate cannon" |
| `flintlock.ogg` | 0.5-1.2 s | a flintlock pistol: a click-snap of the flint, then a dull pop/bang | the pistol fires with the cannon | A | "flintlock pistol", "musket shot", "old pistol shot", "black powder pistol" |
| `cannon_impact.ogg` | 1-2 s | a heavy ball smashing into stone: crunch, debris, a low thud | the ball hits the wall | A | "cannonball impact", "stone impact debris", "heavy impact rock", "wall hit debris" |
| `ghost_form.ogg` | 1-1.5 s | a wet ghostly swell: water bubbling upwards, a hollow whoosh | the ghost cannon forming out of fog | B | "underwater whoosh", "ghost whoosh", "bubbles rising", "spectral swell", "reverse splash" |
| `hammer.ogg` | 0.2-0.5 s | a pistol hammer being cocked: one heavy metallic click | his thumb cocks the hammer | B | "gun cock", "hammer cock", "revolver cock", "flintlock cock" |
| `fuse.ogg` | 0.5-1 s | a fuse catching and fizzing | the cannon's fuse | C | "fuse hiss", "fuse burning", "sparkler", "fuse sizzle" |

**The finisher, The Last Broadside** (~67 s; cues in docs/orvoss.md "Beat sheet"):

| File | Length | Sound | Used in | Prio | Search terms |
|---|---|---|---|---|---|
| `voice_order.ogg` | 1-2 s | his voice line "Give them the deep." (a deep, cold, undead admiral; you make it in ElevenLabs like Veyr's) | the order (34-40) | A | (ElevenLabs) |
| `ambience.ogg` | 20-40 s, seamless loop, stereo | a dark sea bed: deep wind, slow waves, distant creaking, a faint low choir; no melody | under the whole finisher | A | "dark ocean ambience", "stormy sea ambience", "ghost ship ambience", "underwater drone", "dark ambient pad" |
| `bell.ogg` | 2-5 s | one ship's bell or a big church bell, struck once, far away with a long tail | the call (0) | A | "ship bell", "distant bell toll", "church bell single", "bell toll reverb" |
| `anchor_drop.ogg` | 1.5-3 s | a huge iron weight slamming into the ground: deep boom, earth cracking, a chain rattle after | the anchor lands (9-13) | A | "heavy metal impact", "anchor drop", "earth impact boom", "trailer impact" |
| `chain.ogg` | 1-3 s | a heavy chain rattling and dragging, then pulling taut with a strain | the anchor's chain, the drag (52-58) | A | "heavy chain rattle", "chain drag", "chain tension", "anchor chain" |
| `broadside.ogg` | 3-6 s | a rolling volley: many cannons firing one after another, echoing | the travelling broadside (40-52; layered with `cannon`) | A | "cannon volley", "broadside", "naval battle cannons", "cannon barrage", "rolling artillery" |
| `sea_rise.ogg` | 3-6 s | a vast surge of water, a rising roar like a wave building | the sky ocean opening, the ships breaking out (13-20) | A | "massive wave", "water surge", "tidal wave", "ocean swell", "water riser" |
| `creak.ogg` | 2-4 s | a big wooden ship creaking and groaning as it turns | the fleet swings into line (28-34), the flagship passing | B | "ship creak", "wood creak", "hull groan", "old ship timber" |
| `whirlpool.ogg` | 3-6 s | a huge swirling vortex of water, a deep draining roar | the gate dragged into the whirlpool (52-63) | B | "whirlpool", "water vortex", "water drain", "maelstrom", "swirling water" |
| `fog.ogg` | 3-5 s | a low rolling hiss with a ghostly whisper, like fog creeping in | the fog rolling down the lane (4-9) | B | "fog whoosh", "ghostly wind", "creeping mist", "dark wind texture" |
| `gate_break.ogg` | 2-4 s | a huge stone structure collapsing: a crack, a roar of falling stone | the gate breaks (52) | B | "building collapse", "stone collapse", "rock crumble large", "castle wall destruction" |
| `compass.ogg` | 0.2-0.5 s | a small brass lid snapping shut: one sharp metallic click | he snaps the compass shut (0) | B | "pocket watch close", "metal lid click", "brass click", "compass snap" |
| `rigging.ogg` | 1.5-3 s | ropes stretching and creaking, canvas snapping in the wind | he rises on the spectral rigging (34-40) | C | "rope creak", "rope stretch", "sail flap", "canvas flutter" |
| `drips.ogg` | 2-4 s, seamless loop | water dripping and trickling, a little reversed | water dripping upwards off his coat (4-20) | C | "water drips", "dripping water", "reverse water drops" |
| `hat.ogg` | 0.3-0.8 s | a soft cloth/leather catch | he catches his hat (63-67) | C | "cloth grab", "hat catch", "fabric foley" |

## Preparing files

Originals go in `_source/` (kept, not uploaded). `tools/audio/prep_sound.py` makes the game versions:
- `python tools/audio/prep_sound.py info sounds/_source/x.wav` shows channels, length, levels and loudness over time
- `python tools/audio/prep_sound.py loop sounds/_source/x.wav sounds/loops/x.ogg [--length 4] [--start 6]` cuts a
  seamless mono loop from the steadiest stretch (or from --start seconds)
- `python tools/audio/prep_sound.py shot sounds/_source/x.wav sounds/impacts/x.ogg [--max 2]` trims the silence at the
  start, mono, peak -1 dB

Done: `loops/rumble.ogg` (from `_source/rumble.wav`, 16.9 s stereo: 4 s mono loop cut from 6.0 s;
`_source/rumble_looptest.ogg` plays it 4 times to check the seam).
