-- Unit stats, rarity pools and drop-chance helpers shared by server and client.
local Rarities = require(script.Parent.Rarities)
local VEYR_SP = require(script.Parent.VeyrTimeline).SPECIAL -- (Veyr's special: the hit times live with his timeline)
local ADMIRAL = require(script.Parent.AdmiralTimeline) -- (Orvoss's Double Report: when the ball lands)
local BASE_ODDS = Rarities.BaseOdds

local UNITS = {
	-- ── Common ──────────────────────────────────────────────────────────
	Skelly = {
		color = BrickColor.new("White"),
		size = Vector3.new(2, 2, 2),
		damage = 14,
		speed = 8,
		attackRange = 5,
		attackCD = 1.2,
		hitDelay = 0.4, -- (the sword chop meets the wall ~0.38 s into the swing, UnitAnimator "Strike")
		hitFx = "Slash", -- (HitEffects draws a white sword cut instead of the plain flash)
	},
	Zombie = {
		color = BrickColor.new("Medium green"),
		size = Vector3.new(2.2, 2.2, 2.2),
		damage = 20,
		speed = 5,
		attackRange = 5,
		attackCD = 2.0,
		hitDelay = 0.82, -- (the club lands ~0.80 s into the slam, UnitAnimator "Slam")
		hitFx = "Crush",
		hitHeight = 2.9, -- (studs above the floor: the fist lands above the wall's plinth)
	},
	Ghoul = {
		color = BrickColor.new("Dark orange"),
		size = Vector3.new(1.8, 1.8, 1.8),
		damage = 18,
		speed = 14,
		attackRange = 6,
		attackCD = 1.2,
		hitDelay = 0.48, -- (the pounce's claws rake the wall ~0.46 s into the leap, UnitAnimator "Pounce")
		hitFx = "Claw",
		hitHeight = 2.8, -- (studs above the floor: it rakes from the top of its leap, above the wall's 1.6-stud plinth)
	},
	-- ── Uncommon ────────────────────────────────────────────────────────
	-- a spider that grew into a human skull (replaced the Ghost on 2026-10-15). It spits a glob of venom: released
	-- `releaseAt` s into the attack (UnitAnimator "Spit"), flying at `projectileSpeed` studs/s in an arc (client VenomFx)
	CryptSpider = {
		color = BrickColor.new("Dark taupe"),
		size = Vector3.new(2.2, 2.2, 2.2),
		damage = 26,
		speed = 14,
		attackRange = 10,
		attackCD = 0.8,
		releaseAt = 0.4, -- (= 0.5 of the attack cycle)
		projectileSpeed = 45,
		hitFx = "Venom",
		hitHeight = 2.4, -- (studs above the floor: above the wall's 1.6-stud plinth)
	},
	-- a dead archer keeping his post (replaced the Goblin on 2026-10-15; old saves are renamed, see RENAMED below).
	-- Its arrow is a real projectile: released `releaseAt` s into the attack (UnitAnimator "Bow"), it flies at
	-- `projectileSpeed` studs/s (client ArrowFx draws it); the server lands the damage when it arrives.
	HollowArcher = {
		color = BrickColor.new("Dark green"),
		size = Vector3.new(2, 2, 2),
		damage = 52.5, -- (DPS 35: a slow, heavy shot)
		speed = 14,
		attackRange = 30,
		attackCD = 1.5,
		releaseAt = 0.825, -- (= 0.55 of the attack cycle, UnitAnimator ARCHER.RELEASE x attackCD)
		projectileSpeed = 140,
		hitFx = "Arrow",
		hitHeight = 3.5, -- (studs above the floor: it shoots level from its chin)
	},
	Wraith = {
		color = BrickColor.new("Light stone grey"),
		size = Vector3.new(2, 2, 2),
		damage = 35,
		speed = 16,
		attackRange = 8,
		attackCD = 0.8,
		transparent = true,
	},
	CryptBat = {
		color = BrickColor.new("Dark grey"),
		size = Vector3.new(1.5, 1.5, 1.5),
		damage = 77.3, -- (DPS 48.3: one slow, hard dive)
		speed = 22,
		attackRange = 12,
		attackCD = 1.6,
		hitDelay = 0.88, -- (the dive hits the wall 0.55 into the cycle, UnitAnimator "Dive")
		hitFx = "Screech",
		hitHeight = 2.3, -- (studs above the floor: above the wall's plinth)
	},
	-- ── Rare ────────────────────────────────────────────────────────────
	BaronBone = {
		color = BrickColor.new("Bright yellow"),
		size = Vector3.new(2.5, 2.5, 2.5),
		damage = 92,
		speed = 8,
		attackRange = 7,
		attackCD = 0.9,
	},
	PlagueDoctor = {
		color = BrickColor.new("Olive"),
		size = Vector3.new(2, 2, 2),
		damage = 92,
		speed = 10,
		attackRange = 20,
		attackCD = 0.8,
	},
	ShadowHound = {
		color = BrickColor.new("Reddish brown"),
		size = Vector3.new(2, 2, 2),
		damage = 89,
		speed = 24,
		attackRange = 7,
		attackCD = 0.7,
	},
	BoneColossus = {
		color = BrickColor.new("White"),
		size = Vector3.new(3.5, 3.5, 3.5),
		damage = 165,
		speed = 4,
		attackRange = 8,
		attackCD = 1.2,
	},
	-- ── Cursed ──────────────────────────────────────────────────────────
	Banshee = {
		color = BrickColor.new("Hot pink"),
		size = Vector3.new(2.4, 2.4, 2.4),
		damage = 164,
		speed = 18,
		attackRange = 20,
		attackCD = 0.5,
		transparent = true,
		regenReduction = 0.8,
	},
	LichAcolyte = {
		color = BrickColor.new("Medium lavender"),
		size = Vector3.new(2.2, 2.2, 2.2),
		damage = 256,
		speed = 10,
		attackRange = 25,
		attackCD = 0.7,
	},
	DreadKnight = {
		color = BrickColor.new("Bright red"),
		size = Vector3.new(2.8, 2.8, 2.8),
		damage = 313,
		speed = 12,
		attackRange = 8,
		attackCD = 0.75,
	},
	-- ── Legendary ───────────────────────────────────────────────────────
	SkeletonKing = {
		color = BrickColor.new("Gold"),
		size = Vector3.new(3, 3, 3),
		damage = 1049,
		speed = 10,
		attackRange = 8,
		attackCD = 1.0,
	},
	LichLord = {
		color = BrickColor.new("Bright violet"),
		size = Vector3.new(2.8, 2.8, 2.8),
		damage = 982,
		speed = 8,
		attackRange = 30,
		attackCD = 0.8,
		regenReduction = 0.5,
	},
	DeathReaper = {
		color = BrickColor.new("Dark indigo"),
		size = Vector3.new(2.5, 2.5, 2.5),
		damage = 1000,
		speed = 20,
		attackRange = 10,
		attackCD = 0.7,
	},
	VoidWalker = {
		color = BrickColor.new("Really black"),
		size = Vector3.new(2.2, 2.2, 2.2),
		damage = 793,
		speed = 25,
		attackRange = 15,
		attackCD = 0.5,
		transparent = true,
	},
	-- Knell, the Mourning Bell: a rare Legendary Signature with a three-toll spectacle.
	Knell = {
		title = "The Mourning Bell", -- (a Signature title: the Codex shows it under the name)
		color = BrickColor.new("Sand green"),
		size = Vector3.new(2.8, 4, 2.8),
		damage = 3300, -- 1,650 nominal DPS: top of Legendary, below Abyssal
		speed = 9,
		attackRange = 20,
		attackCD = 2,
		hitDelay = 0.55,
		-- The Procession: one toll, pallbearers carry a chained coffin to the wall, a black-red claw rakes through it
		-- (client KnellFx; the hits: the toll, the rake, the tear imploding)
		special = { kind = "Procession", cooldown = 90, share = 0.6, duration = 11.0,
			hits = { { at = 0.35, share = 0.08 }, { at = 7.2, share = 0.72 }, { at = 10.5, share = 0.2 } } },
		-- its unique trait, THE MOURNING BELL (Army.traitMultiplier): while its bell tolls (its special), the whole army
		-- deals more damage
		trait = { kind = "duringSpecial", damage = 0.10 },
	},
	-- ── Abyssal ─────────────────────────────────────────────────────────
	SoulEater = {
		color = BrickColor.new("Bright orange"),
		size = Vector3.new(3, 3, 3),
		damage = 2013,
		speed = 16,
		attackRange = 12,
		attackCD = 0.6,
	},
	AbyssalTitan = {
		color = BrickColor.new("Bright red"),
		size = Vector3.new(4, 4, 4),
		damage = 3875,
		speed = 6,
		attackRange = 10,
		attackCD = 1.0,
	},
	ShadeLord = {
		color = BrickColor.new("Dark purple"),
		size = Vector3.new(3, 3, 3),
		damage = 2726,
		speed = 18,
		attackRange = 20,
		attackCD = 0.6,
		transparent = true,
		regenReduction = 0.9,
	},
	-- ── Eldritch ────────────────────────────────────────────────────────
	EldritchFiend = {
		color = BrickColor.new("Teal"),
		size = Vector3.new(3.5, 3.5, 3.5),
		damage = 7516,
		speed = 12,
		attackRange = 25,
		attackCD = 0.7,
	},
	MindShatterer = {
		color = BrickColor.new("Cyan"),
		size = Vector3.new(2.8, 2.8, 2.8),
		damage = 8213,
		speed = 22,
		attackRange = 30,
		attackCD = 0.6,
	},
	-- ── Eternal ─────────────────────────────────────────────────────────
	TheUndying = {
		color = BrickColor.new("Institutional white"),
		size = Vector3.new(4, 4, 4),
		damage = 24052,
		speed = 15,
		attackRange = 15,
		attackCD = 0.7,
		transparent = true,
		regenReduction = 1.0,
	},
	-- a floating gas-masked child, "crucified" in the air; points a claw finger out of its sleeve and fires a thin beam
	-- (model attribute AttackStyle = "FingerBeam"; the damage lands hitDelay seconds after the attack, with the beam)
	Hush = {
		title = "The Unbreathing", -- (a Signature title: the Codex shows it under the name)
		color = BrickColor.new("Royal purple"),
		size = Vector3.new(2.2, 4, 2.2),
		damage = 90000, -- 45K DPS: a Signature unit is among the strongest of its rarity (but stays below the next tier)
		speed = 12,
		attackRange = 20,
		attackCD = 2.0,
		hitDelay = 0.5,
		infiniteRange = true, -- beams the wall from the fixed post like the Sigilwright: no marching, the arm stays raised
		-- special attack (Army.startSpecial, client SpecialFx): rips a rift into reality, chains swarm out and bite into the
		-- wall (hit 1), then explode (hit 2). `share` of the unit's damage comes from the special, the rest from basic
		-- attacks, so its DPS is unchanged. In Studio the cooldown is SPECIAL_TEST_COOLDOWN (Army) for testing.
		special = { kind = "RiftChains", cooldown = 90, share = 0.6, duration = 8.8, hits = { { at = 6.95, share = 0.4 }, { at = 7.6, share = 0.6 } } },
		-- its unique trait, THE UNBREATHING (Army.traitMultiplier): the whole army deals more damage to a wall below half HP
		trait = { kind = "lowWall", damage = 0.15, below = 0.5 },
	},
	DeathIncarnate = {
		color = BrickColor.new("Really black"),
		size = Vector3.new(5, 5, 5),
		damage = 26615,
		speed = 10,
		attackRange = 20,
		attackCD = 0.6,
		regenReduction = 1.0,
	},
	-- ── Primordial ──────────────────────────────────────────────────────
	-- The first artillery: a colossal tower that rises from the ground far behind the warband and burns the wall
	-- with a ray of souls: one beam of about a second every attackCD seconds, each beam dealing `damage`
	-- (160000 / 4 s = 40000 DPS). `static` units never walk: they rise straight at their formation slot.
	-- attackRange 32 puts it 60 studs from the wall (see Army.standDistance).
	LastLantern = {
		color = BrickColor.new("Dark green"),
		size = Vector3.new(4, 4, 4),
		damage = 439805,
		speed = 0,
		attackRange = 32,
		attackCD = 4.0,
		static = true,
	},
	-- The Sigilwright walks with the army and fights from far back: it lifts a hand, a big rune circle opens flat above
	-- it, and small sigil circles open in the air in a fixed cone far ahead (attack style "SigilCast", see SpellEffects).
	-- It has unlimited range (`infiniteRange`): it never marches after the wall, it stands at a fixed post (Army
	-- INFINITE_RANGE_POST_FWD) and its darts fly `shotFlight` seconds to the wall wherever it is, slow at first and then
	-- accelerating.
	-- DPS: 85000 / 1 s.
	Sigilwright = {
		title = "The Last Word", -- (a Signature title: the Codex shows it under the name)
		color = BrickColor.new("Pastel yellow"),
		size = Vector3.new(2.4, 2.4, 2.4),
		damage = 85000,
		speed = 10,
		attackRange = 30,
		attackCD = 1.0,
		shotsPerSecond = 8,
		shotFlight = 0.45,
		infiniteRange = true, -- it stays at a fixed post far behind the front and shoots the wall wherever it is
		-- The Verdict: it writes a five-word sentence of rune circles over the wall, slots its stars into them, then
		-- speaks it: every word bursts into fire and fires a hypersonic bolt of judgement (client Modules/VerdictFx)
		special = { kind = "Verdict", cooldown = 90, share = 0.6, duration = 13.0,
			hits = { { at = 9.36, share = 0.12 }, { at = 9.96, share = 0.12 }, { at = 10.41, share = 0.12 },
				{ at = 10.76, share = 0.12 }, { at = 11.36, share = 0.52 } } },
		-- its unique trait, THE LAST WORD (Army.traitMultiplier): when the Verdict is spoken (its last bolt) the wall is
		-- marked, and the whole army deals more damage to it for `duration` s
		trait = { kind = "afterSpecial", damage = 0.20, from = 11.4, duration = 10 },
	},
	-- Malak, the Envoy: the first Sovereign (docs/envoy.md), pool weight 0.05 from the Celestial grave only. Basic attack, the orbital tag (model AttackStyle "OrbitalTag",
	-- client OrbitalStrike.lua): while he fights his hologram pad opens into a big hologram in front of him; he taps it
	-- once, a red laser cuts diagonally out of the sky onto the wall, then a shell from a cannon far above hits it.
	-- One slow, heavy hit every 6.5 s; the damage lands with the shell (hitDelay must match OrbitalStrike.IMPACT_AT).
	Malak = {
		sovereign = true, -- (his own pull cinematic: client SovereignArrival)
		title = "The Envoy", -- (shown after his name in SovereignArrival)
		color = BrickColor.new("Really black"),
		size = Vector3.new(2.2, 4, 2.2),
		damage = 552500, -- 85K DPS (placeholder)
		speed = 10,
		attackRange = 32, -- stands 60 studs from the wall (Army.standDistance), twice as far as range 20 put him
		attackCD = 6.5,
		hitDelay = 3.9,
		hitFx = "Orbital", -- (OrbitalStrike.lua draws the impact; HitEffects draws nothing)
		hitHeight = 4,
		-- his drone (Army.fireCompanion, client OrbitalStrike.lua "The drone's volley"): every `period` s while he
		-- fights its three rings spread into a triangle, charge and fire three thin blue bolts that meet on the wall;
		-- `share` of his damage, the shells deal the rest. hitAt must match the client's DRONE_* timings.
		companion = { period = 4.5, share = 0.3, hitAt = 2.05, firstDelay = 2.0, hitHeight = 6 },
		-- his special, the REQUISITION (client RequisitionFx, docs/envoy.md): a supply pod drops from the Absolution, a
		-- dispenser launches six drones that fight the wall, they fly home and the pod is beamed up. He keeps attacking
		-- meanwhile (keepAttacking). The drones deal `swarm.armySeconds` seconds of the WHOLE ARMY's DPS, in ticks between
		-- `swarm.from` and `swarm.to` (s after the start; must match the client's LAUNCH_FROM + T_LAUNCH and SWARM_END).
		special = { kind = "Requisition", cooldown = 150, share = 0, duration = 42, hits = {}, keepAttacking = true,
			swarm = { from = 10.4, to = 33.8, armySeconds = 25, tick = 0.5 } },
		-- his passive aura while he is on a grave: +10% damage for the whole army (Army.auraMultiplier; auras of one kind do
		-- not stack, the strongest counts)
		aura = { damage = 0.10 },
	},
	-- Veyr, the Last Sight: the second Sovereign (docs/veyr.md), a hooded skeletal marksman with a long arcane rifle.
	-- Basic attack DEAD RECKONING (model AttackStyle "Marksman", client MarksmanAnimator + VeyrShot): one deliberate shot
	-- every attackCD; aim, focusing rings, a quiet beat, the shot at shared VeyrTimeline.FIRE. (First pass: the shot,
	-- the mark, the special and the finisher are built in stages; numbers are provisional.)
	Veyr = {
		sovereign = true,
		title = "The Last Sight",
		color = BrickColor.new("Really black"),
		size = Vector3.new(2.2, 4, 2.2),
		-- 93K DPS nominal: his basics pause for the special (~91 % of nominal), so ~85K in practice like Malak (2026-10-17)
		damage = 700000,
		speed = 10,
		attackRange = 32,
		-- a sniper's overwatch post (the user's call): like the Sigilwright he never marches after the front; he takes a
		-- fixed post `postFwd` studs from the plot centre, just in front of the graves, and shoots every wall from there
		-- (~70 studs to the first wall, ~270 to the gate; the round's flight grows with it, VeyrTimeline.impactAt)
		infiniteRange = true,
		postFwd = 30,
		-- his perch (the user's call): at the post he rises `height` studs into the air and drifts `out` studs past the
		-- lane's edge, shooting down at the wall diagonally. Only his model moves there (client MarksmanAnimator); his
		-- unit stays inside the lane at lateral side x `laneLat` (Army). A second Veyr takes the other side.
		perch = { height = 15, out = 9, laneLat = 16 },
		attackCD = 7.5, -- (his performance takes VeyrTimeline.SETTLE_END = 6.4 s; nothing changes attackCD at runtime)
		-- (no hitDelay: Army.fireMarksman lands the round at VeyrTimeline.impactAt(distance))
		hitFx = "Marksman", -- (VeyrShot.lua draws the round and the impact; HitEffects draws nothing)
		hitHeight = 4,
		-- his unique trait, THE LAST SIGHT (Army.traitMultiplier): every round that lands exposes a weak point on that wall
		-- for `duration` s, and the whole army deals +`damage` to it. One mark per plot: more Veyrs refresh it, never
		-- stack it; the strongest `damage` counts. Cleared when the wall is replaced or the run resets.
		trait = { kind = "mark", damage = 0.10, duration = 6 },
		-- his special, THE LONG GOODBYE (client VeyrSpecial, docs/veyr.md): his shards fly down the lane and open six
		-- sigils, the round passes through them all. `army`: one snapshot of the WHOLE army's ordinary DPS when it starts,
		-- times `seconds`, split over the `hits` (the fracture and its delayed collapse), all on the wall he aimed at.
		-- share = 0: his basic shots keep their full damage (they pause while it plays).
		special = { kind = "LongGoodbye", cooldown = 150, share = 0, duration = VEYR_SP.END, hits = {},
			-- (24 army-seconds + the mark's ~+8 % against Malak's Requisition 25 s + aura +10 %: about level, 2026-10-17)
			army = { seconds = 24, hits = { { at = VEYR_SP.IMPACT, share = 0.8 }, { at = VEYR_SP.COLLAPSE, share = 0.2 } } } },
	},
	-- Orvoss, the Blackwake: the third Sovereign (docs/orvoss.md), a drowned skeletal admiral with a cutlass, a
	-- flintlock and a ghost fleet. Basic attack DOUBLE REPORT (client AdmiralAnimator + DoubleReport, shared
	-- AdmiralTimeline): he levels the flintlock while a ghost cannon forms at his left; both fire as one, ONE hit when
	-- the ball lands. No special, trait, finisher or own pull cinematic yet (he gets Malak's).
	Orvoss = {
		sovereign = true,
		title = "The Blackwake",
		color = BrickColor.new("Really black"),
		size = Vector3.new(2.4, 4, 2.4),
		damage = 595000, -- 85K DPS like Malak and Veyr (placeholder until his kit is built)
		speed = 4.5, -- (a heavy march: his stride is long and slow, the cadence follows this speed; AdmiralAnimator)
		attackRange = 25, -- stands 40 studs from the wall (Army.standDistance): a gunline, closer than Malak
		attackCD = 7, -- (the performance takes AdmiralTimeline.LOWER_TO = 5 s)
		hitDelay = ADMIRAL.IMPACT,
		hitFx = "DoubleReport", -- (DoubleReport.lua draws the shots and the impact; HitEffects draws nothing)
		hitHeight = 4,
	},
}

-- Which units belong to which rarity, each with a relative weight
-- (higher weight = more likely within that rarity tier)
local RARITY_UNITS = {
	Common = {
		{ unit = "Skelly", weight = 4 },
		{ unit = "Zombie", weight = 3 },
		{ unit = "Ghoul", weight = 2 },
	},
	Uncommon = {
		{ unit = "CryptSpider", weight = 4 },
		{ unit = "HollowArcher", weight = 3 },
		{ unit = "Wraith", weight = 2 },
		{ unit = "CryptBat", weight = 1 },
	},
	Rare = {
		{ unit = "BaronBone", weight = 3 },
		{ unit = "PlagueDoctor", weight = 2 },
		{ unit = "ShadowHound", weight = 2 },
		{ unit = "BoneColossus", weight = 1 },
	},
	Cursed = {
		{ unit = "Banshee", weight = 3 },
		{ unit = "LichAcolyte", weight = 2 },
		{ unit = "DreadKnight", weight = 1 },
	},
	Legendary = {
		{ unit = "SkeletonKing", weight = 6 },
		{ unit = "LichLord", weight = 3 },
		{ unit = "DeathReaper", weight = 2 },
		{ unit = "VoidWalker", weight = 1 },
		{ unit = "Knell", weight = 0.15 }, -- Signature: rare within its tier
	},
	Abyssal = {
		{ unit = "SoulEater", weight = 3 },
		{ unit = "AbyssalTitan", weight = 2 },
		{ unit = "ShadeLord", weight = 1 },
	},
	Eldritch = {
		{ unit = "EldritchFiend", weight = 2 },
		{ unit = "MindShatterer", weight = 1 },
	},
	Eternal = {
		{ unit = "TheUndying", weight = 2 },
		{ unit = "DeathIncarnate", weight = 1 },
		{ unit = "Hush", weight = 0.2 }, -- Signature: very low weight
	},
	Primordial = {
		{ unit = "LastLantern", weight = 1 },
		{ unit = "Sigilwright", weight = 0.2 }, -- Signature: very low weight
		{ unit = "Malak", weight = 0.05, graves = { Celestial = true } }, -- Sovereign: rarer than a Signature, and only from the Celestial grave (`graves`: Rolling skips the entry elsewhere, the wheel never gives him)
		{ unit = "Veyr", weight = 0.05, graves = { Celestial = true } }, -- Sovereign: like Malak (his own pull cinematic, VeyrArrival, approved 2026-10-17)
		{ unit = "Orvoss", weight = 0.05, graves = { Celestial = true } }, -- Sovereign: like Malak (no own pull cinematic yet: he gets Malak's ship)
	},
}

-- Reverse lookup: unitType  rarity string
local UNIT_RARITY = {}
for rarity, units in pairs(RARITY_UNITS) do
	for _, entry in ipairs(units) do
		UNIT_RARITY[entry.unit] = rarity
	end
end

local UNIT_EMOJIS = {
	-- Common
	Skelly = "",
	Zombie = "",
	Ghoul = "",
	-- Uncommon
	CryptSpider = "",
	HollowArcher = "",
	Wraith = "",
	CryptBat = "",
	-- Rare
	BaronBone = "",
	PlagueDoctor = "",
	ShadowHound = "",
	BoneColossus = "",
	-- Cursed
	Banshee = "",
	LichAcolyte = "",
	DreadKnight = "",
	-- Legendary
	SkeletonKing = "",
	LichLord = "",
	DeathReaper = "",
	VoidWalker = "",
	Knell = "",
	-- Abyssal
	SoulEater = "",
	AbyssalTitan = "",
	ShadeLord = "",
	-- Eldritch
	EldritchFiend = "",
	MindShatterer = "",
	-- Eternal
	TheUndying = "",
	DeathIncarnate = "",
	Hush = "",
	-- Primordial
	LastLantern = "",
	Sigilwright = "",
	Malak = "",
	Veyr = "",
	Orvoss = "",
}

-- Base "1 in X" chance for a unit (uses BASE_ODDS only — no luck, always shown raw)
local function getBaseOneIn(unitType)
	local rarity = UNIT_RARITY[unitType] or "Common"
	local rarityChance = BASE_ODDS[rarity] / 100
	local pool = RARITY_UNITS[rarity]
	local totalWeight = 0
	for _, entry in ipairs(pool) do
		totalWeight += entry.weight
	end
	local unitWeight = 0
	for _, entry in ipairs(pool) do
		if entry.unit == unitType then
			unitWeight = entry.weight
			break
		end
	end
	if unitWeight == 0 or totalWeight == 0 then
		return 999
	end
	local chance = rarityChance * (unitWeight / totalWeight)
	return math.max(2, math.round(1 / chance))
end

-- Signature units: every unit with its own special attack (`special` in its def). Their NAME burns everywhere it is
-- shown (client Modules/SignatureName: an ember gradient shimmering through the letters, on slots, tooltips, the reveal,
-- the star cinematic, the Forge and the nameplate in the world); the reveal and the tooltip also say "Signature". They
-- always get the star cinematic. Rules: their DPS is at the TOP of their rarity's range (one of the strongest of the tier, never into the
-- next tier), and they ALWAYS get a very low weight in RARITY_UNITS (e.g. 0.2 against 1-4 for normal units), so they
-- are the chase within each tier. (Planned: a "guaranteed Rare Signature" box for new players.)
-- Only Signatures and Sovereigns get a `title` ("The Unbreathing"): the Codex shows it under the name, even before
-- the unit is discovered (under its black silhouette).
local SIGNATURE_COLOR = Color3.fromRGB(255, 226, 150)
local function isSignature(unitType)
	local def = UNITS[unitType]
	return def ~= nil and def.special ~= nil
end

-- Sovereign units (a class above Signature, docs/envoy.md): their own gate finisher and their own pull cinematic
local function isSovereign(unitType)
	local def = UNITS[unitType]
	return def ~= nil and def.sovereign == true
end

-- ============================================================
-- Abilities, as the Codex unit page shows them (the numbers come from the defs above, so the page and the server agree).
-- Per unit a list of { name, kind = "Passive" | "Special" | "Finisher", text = function(def, Economy) -> string,
-- unlock = { state = <State key that owns it>, price = <Economy key>, buy = <BuyGemItem item> } (locked until owned) }.
-- In `text`, {braces} mark the numbers the page highlights.
-- ============================================================
local function shortNumber(n)
	n = math.floor(n + 0.5)
	if n >= 1e9 then return ("%.1fB"):format(n / 1e9) end
	if n >= 1e6 then return ("%.1fM"):format(n / 1e6) end
	if n >= 1e4 then return ("%.1fK"):format(n / 1e3) end
	return tostring(n)
end
local function ownDamageSeconds(def)
	return math.floor(def.special.share * def.special.cooldown + 0.5)
end
local ABILITIES = {
	Knell = {
		{ name = "The Mourning Bell", kind = "Passive", text = function(def)
			return ("While its bell tolls (its special, {%s s}), your whole army deals {+%d%%} damage."):format(tostring(def.special.duration), math.floor(def.trait.damage * 100 + 0.5))
		end },
		{ name = "The Procession", kind = "Special", text = function(def)
			return ("Every {%d s} Knell tolls the bell: pallbearers carry a chained coffin to the wall and a black-red claw rakes through it, dealing {%d s} of Knell's own damage.")
				:format(def.special.cooldown, ownDamageSeconds(def))
		end },
	},
	Hush = {
		{ name = "The Unbreathing", kind = "Passive", text = function(def)
			return ("Your whole army deals {+%d%%} damage to a wall below {%d%%} HP."):format(math.floor(def.trait.damage * 100 + 0.5), math.floor(def.trait.below * 100 + 0.5))
		end },
		{ name = "Rift Chains", kind = "Special", text = function(def)
			return ("Every {%d s} Hush tears a rift into reality: chains swarm out, bite into the wall and explode, dealing {%d s} of Hush's own damage.")
				:format(def.special.cooldown, ownDamageSeconds(def))
		end },
	},
	Sigilwright = {
		{ name = "The Last Word", kind = "Passive", text = function(def)
			return ("When the Verdict is spoken, the wall is marked: your whole army deals {+%d%%} damage to it for {%d s}."):format(math.floor(def.trait.damage * 100 + 0.5), def.trait.duration)
		end },
		{ name = "The Verdict", kind = "Special", text = function(def)
			return ("Every {%d s} the Sigilwright writes a sentence of {5} runes over the wall and speaks it: every word fires a bolt of judgement, together {%d s} of its own damage.")
				:format(def.special.cooldown, ownDamageSeconds(def))
		end },
	},
	Malak = {
		{ name = "Requisition", kind = "Special", text = function(def)
			local sw = def.special.swarm
			return ("Every {%d s} a supply pod drops from the Absolution. Its dispenser launches {6} drones that strafe the wall for {%d s}, dealing {%d s} of your whole army's damage. Malak keeps fighting meanwhile.")
				:format(def.special.cooldown, math.floor(sw.to - sw.from + 1.6 + 0.5), sw.armySeconds)
		end },
		{ name = "The Envoy", kind = "Passive", text = function(def)
			local c = def.companion
			return ("His drone fires its own volley at the wall every {%s s} for {%s} damage. While Malak stands on a grave, your whole army deals {+%d%%} damage.")
				:format(tostring(c.period), shortNumber(def.damage / def.attackCD * c.share * c.period), math.floor(def.aura.damage * 100 + 0.5))
		end },
		{ name = "Fleet Strike", kind = "Finisher", text = function(_, Economy)
			return ("When the gate falls below {%d%%} HP, Malak calls in the Absolution: the fleet tears out of the sky and its main cannon brings the gate down. Everyone on the server sees it.")
				:format(math.floor(Economy.FLEET_STRIKE_HP * 100 + 0.5))
		end, unlock = { state = "fleetStrike", price = "FLEET_STRIKE_PRICE", buy = "FleetStrike" } },
	},
	Veyr = {
		{ name = "The Last Sight", kind = "Passive", text = function(def)
			return ("Every round he fires marks the wall's weak point: your whole army deals {+%d%%} damage to it for {%d s}. A second Veyr refreshes the mark, it does not stack.")
				:format(math.floor(def.trait.damage * 100 + 0.5), def.trait.duration)
		end },
		{ name = "The Long Goodbye", kind = "Special", text = function(def)
			return ("Every {%d s} Veyr sends his shards down the lane to open six sights and fires one round through all of them, dealing {%d s} of your whole army's damage.")
				:format(def.special.cooldown, def.special.army.seconds)
		end },
		{ name = "The Final Horizon", kind = "Finisher", text = function(_, Economy)
			return ("When the gate falls below {%d%%} HP, Veyr rises into the sky, opens a wheel of giant rifles and fires them all at once. The gate stands a moment longer, then turns to ash. Everyone on the server sees it.")
				:format(math.floor(Economy.FLEET_STRIKE_HP * 100 + 0.5))
		end, unlock = { state = "finalHorizon", price = "FINAL_HORIZON_PRICE", buy = "FinalHorizon" } },
	},
	Orvoss = {
		{ name = "The Last Broadside", kind = "Finisher", text = function(_, Economy)
			return ("When the gate falls below {%d%%} HP, Orvoss calls his drowned fleet out of a black ocean in the sky. Ship after ship turns its broadside on the gate and the volley rolls down the line until the flagship fires last. Then the anchors drag the ruins into the deep. Everyone on the server sees it.")
				:format(math.floor(Economy.FLEET_STRIKE_HP * 100 + 0.5))
		end, unlock = { state = "lastBroadside", price = "LAST_BROADSIDE_PRICE", buy = "LastBroadside" } },
	},
}

-- ============================================================
-- Descriptions for the Codex unit page: a plain line or two for the normal units, a little lore for the Signatures
-- and Sovereigns. (First drafts, 2026-10-16: rewrite freely.)
-- ============================================================
local DESCRIPTIONS = {
	Skelly = "A soldier picked clean by time, raised with a rusted blade still in hand. It does not tire, does not question, and does not stop.",
	Zombie = "A shambling corpse with more stubbornness than sense. It batters the wall with whatever it has left.",
	Ghoul = "A crawling grave-robber with long claws and a longer hunger. It leaps at stone as if it were flesh.",
	CryptSpider = "A spider that made its nest inside a human skull, and never left. It spits venom that eats through mortar.",
	HollowArcher = "A dead archer who never abandoned his post. His arrows still fly true; his eyes are long gone.",
	Wraith = "A cold shape of grief and fog. Walls mean little to something that was never quite there.",
	CryptBat = "A swarm-born bat of the crypts, all teeth and wings. It strikes fast and comes back for more.",
	BaronBone = "A skeletal nobleman in a tall hat, still convinced he owns the place. He fights with the arrogance of old money.",
	PlagueDoctor = "A masked physician who stopped trying to cure the plague and started carrying it instead.",
	ShadowHound = "A hound stitched from shadow, loyal only to the one who called it. It hunts the wall like prey.",
	BoneColossus = "Hundreds of bones fused into one lumbering giant. Slow to start, impossible to stop.",
	Banshee = "A weeping spirit whose scream cracks stone. Those who hear it rarely forget it.",
	LichAcolyte = "A student of forbidden rites, halfway to lichdom. Its spells are clumsy but its devotion is not.",
	DreadKnight = "A knight in black plate who swore an oath to death itself. He keeps it with every swing.",
	SkeletonKing = "A crowned skeleton who ruled a kingdom of the dead. He still expects to be obeyed.",
	LichLord = "A master of death magic who traded his heart for eternity. His power has only grown since.",
	DeathReaper = "The hooded collector of souls. Its scythe was made for harvests, and the wall is no exception.",
	VoidWalker = "A traveller from the empty places between worlds. Where it steps, light forgets to follow.",
	SoulEater = "A ravenous spirit that feeds on what remains of the dead. Every soul it takes makes it stronger.",
	AbyssalTitan = "A colossus dragged up from the abyss. It strikes with the weight of the deep.",
	ShadeLord = "A lord of shades who commands darkness like a court. Even other spirits keep their distance.",
	EldritchFiend = "A thing with too many eyes and no single shape. Looking at it too long is unwise.",
	MindShatterer = "An eldritch horror that breaks minds before it breaks walls. Its whispers echo in stone.",
	TheUndying = "It has been killed more times than anyone can count. It always gets back up.",
	DeathIncarnate = "Not a servant of death, but death given form. The air grows still when it arrives.",
	LastLantern = "A colossal tower that rises from the earth far behind the army, burning the wall with a ray of captured souls.",
	Knell = "The bell of a drowned chapel, rung once for every soul it buried. When the village was gone the bell kept tolling, and something answered. Now Knell walks, and the dead walk behind it in procession.",
	Hush = "A child found in a sealed ward, still wearing the gas mask the nurses gave it. It never breathed again, and it never came down. It does not speak. It only points.",
	Sigilwright = "A scribe of the old courts who wrote the sentences that kings would speak. Death took the kings; the scribe kept writing. Every verdict it writes is final, and every word of it burns.",
	Veyr = "He was the marksman of a city that fell. He waited at his post for the one shot that would have saved it, and he was still waiting when the last bell stopped. Death did not end the wait. Now he sees the one point where any resistance can still break, and he is patient enough to wait beyond death for it.",
	Orvoss = "An admiral who sank with his flagship rather than strike his colours. The sea kept him, and the drowned crews of every ship he ever sent to the bottom. He came back up to finish the war, and his fleet still answers when he calls.",
	Malak = "An envoy of a High Command no one in this realm has ever seen. He arrived from a tear in the sky, aboard a warship that does not answer to the dead, and he did not come to serve. He came to negotiate, and his terms are written in orbital fire.",
}

-- The basic attack, for the Codex unit page: { name, how } per unit (`how` starts the sentence; the interval and the
-- base damage per hit are added from the def; the damage a special or a companion takes is left out of the hit).
local BASIC = {
	Skelly = { "Rusted Blade", "Slashes the wall with its rusted blade" },
	Zombie = { "Rotting Fists", "Pounds the wall with its fists" },
	Ghoul = { "Pounce", "Leaps up and rakes the wall with its claws" },
	CryptSpider = { "Venom Spit", "Spits a glob of venom at the wall" },
	HollowArcher = { "Grave Arrow", "Looses an arrow at the wall" },
	Wraith = { "Chilling Touch", "Reaches into the wall with a chilling touch" },
	CryptBat = { "Dive", "Dives and bites at the wall" },
	BaronBone = { "Noble Strike", "Strikes the wall" },
	PlagueDoctor = { "Plague Strike", "Strikes the wall" },
	ShadowHound = { "Shadow Bite", "Lunges and bites at the wall" },
	BoneColossus = { "Bone Fist", "Smashes the wall with a fist of bone" },
	Banshee = { "Wail", "Screams at the wall" },
	LichAcolyte = { "Dark Bolt", "Casts a bolt of dark magic at the wall" },
	DreadKnight = { "Cleave", "Cleaves the wall with his blade" },
	SkeletonKing = { "Royal Strike", "Strikes the wall" },
	LichLord = { "Death Magic", "Casts death magic at the wall" },
	DeathReaper = { "Reap", "Reaps the wall with its scythe" },
	VoidWalker = { "Void Strike", "Strikes the wall out of the void" },
	Knell = { "Toll", "Tolls its bell, and the sound strikes the wall" },
	SoulEater = { "Devour", "Tears at the wall" },
	AbyssalTitan = { "Abyssal Slam", "Slams the wall" },
	ShadeLord = { "Shade Strike", "Strikes the wall with darkness" },
	EldritchFiend = { "Rend", "Rends the wall" },
	MindShatterer = { "Shatter", "Strikes the wall" },
	TheUndying = { "Relentless", "Strikes the wall" },
	Hush = { "Finger Beam", "Points a claw finger and fires a thin beam at the wall" },
	DeathIncarnate = { "Final Touch", "Strikes the wall" },
	LastLantern = { "Soul Ray", "Burns the wall with a ray of captured souls" },
	Sigilwright = { "Sigil Darts", "Opens sigil circles in the air and fires a stream of darts at the wall" },
	Malak = { "Orbital Tag", "Marks the wall with a red targeting laser, and a shell from orbit strikes it" },
	Veyr = { "Dead Reckoning", "Focuses his sights and fires one spectral round through the wall's weak point" },
	Orvoss = { "Double Report", "Levels his flintlock while a ghost cannon forms beside him; both fire as one" },
}
local function basicAttack(unitType)
	local def = UNITS[unitType]
	if not def then return nil end
	local b = BASIC[unitType] or { "Basic Attack", "Strikes the wall" }
	return { name = b[1], kind = "Basic", text = function(d)
		local share = (d.special and d.special.share or 0) + (d.companion and d.companion.share or 0)
		local every = d.attackCD == math.floor(d.attackCD) and tostring(d.attackCD) or ("%.1f"):format(d.attackCD)
		return ("%s every {%s s} for {%s} damage."):format(b[2], every, shortNumber(d.damage * (1 - share)))
	end }
end

-- ============================================================
-- Families (TFT-style traits, Design.md "Unit families, the commander slot and placement"). Every normal unit belongs
-- to one; Signatures and Sovereigns have none (they are commanders with a unique trait: their title). Units of a family
-- placed on the plot activate its bonus in tiers at 2 / 4 / 6: duplicates of one unit count once, a unit in its
-- shadow form (Economy.AWAKEN_LEVEL) counts double. The server applies the bonuses (Army); `kind` says what they do:
--   damage  the family's own units deal more damage          gate   the whole army deals more damage to the gate
--   gold    more gold from hits                               burst  the family's units deal more for `burstTime` s
--   special the commanders' specials charge faster                     after a wall stands
-- ============================================================
local FAMILIES = {
	Bones = { kind = "gate", tiers = { 0.10, 0.25, 0.45 }, blurb = "the siege" },
	Flesh = { kind = "damage", tiers = { 0.10, 0.25, 0.45 }, blurb = "the horde" },
	Spirits = { kind = "gold", tiers = { 0.10, 0.25, 0.45 }, blurb = "the harvest" },
	Beasts = { kind = "burst", tiers = { 0.30, 0.60, 1.00 }, burstTime = 8, blurb = "the pack" },
	Arcane = { kind = "special", tiers = { 0.10, 0.20, 0.35 }, blurb = "the rites" },
}
local FAMILY_THRESHOLDS = { 2, 4, 6 }
local FAMILY_ORDER = { "Bones", "Flesh", "Spirits", "Beasts", "Arcane" }
local FAMILY_OF = {
	Skelly = "Bones", HollowArcher = "Bones", BaronBone = "Bones", BoneColossus = "Bones", DreadKnight = "Bones", SkeletonKing = "Bones",
	Zombie = "Flesh", Ghoul = "Flesh", PlagueDoctor = "Flesh", AbyssalTitan = "Flesh", TheUndying = "Flesh",
	Wraith = "Spirits", Banshee = "Spirits", SoulEater = "Spirits", ShadeLord = "Spirits", DeathReaper = "Spirits", LastLantern = "Spirits",
	CryptSpider = "Beasts", CryptBat = "Beasts", ShadowHound = "Beasts", EldritchFiend = "Beasts",
	LichAcolyte = "Arcane", LichLord = "Arcane", VoidWalker = "Arcane", MindShatterer = "Arcane", DeathIncarnate = "Arcane",
}

-- counts per family for a list of { unitType, level } (duplicates once: the copy with the highest level counts; a
-- shadow-form copy counts 2), and the active bonus per family (0 below the first tier)
local function familyCounts(list, awakenLevel)
	local best = {}
	for _, u in ipairs(list) do
		if FAMILY_OF[u.unitType] then
			best[u.unitType] = math.max(best[u.unitType] or 0, u.level or 0)
		end
	end
	local counts = {}
	for unitType, level in pairs(best) do
		local fam = FAMILY_OF[unitType]
		counts[fam] = (counts[fam] or 0) + ((awakenLevel and level >= awakenLevel) and 2 or 1)
	end
	return counts
end
local function familyTier(count)
	local tier = 0
	for i, need in ipairs(FAMILY_THRESHOLDS) do
		if (count or 0) >= need then
			tier = i
		end
	end
	return tier
end
local function familyBonuses(list, awakenLevel)
	local counts = familyCounts(list, awakenLevel)
	local bonus = {}
	for name, fam in pairs(FAMILIES) do
		local tier = familyTier(counts[name])
		bonus[name] = tier > 0 and fam.tiers[tier] or 0
	end
	return bonus, counts
end

-- Units that were replaced or renamed: old saves still hold the old key and are migrated on load (Persistence)
local RENAMED = {
	Goblin = "HollowArcher",
	Ghost = "CryptSpider",
}

return {
	Stats = UNITS,
	Abilities = ABILITIES,
	Descriptions = DESCRIPTIONS,
	basicAttack = basicAttack,
	Families = FAMILIES,
	FamilyOf = FAMILY_OF,
	FAMILY_THRESHOLDS = FAMILY_THRESHOLDS,
	FAMILY_ORDER = FAMILY_ORDER,
	familyCounts = familyCounts,
	familyTier = familyTier,
	familyBonuses = familyBonuses,
	RENAMED = RENAMED,
	isSignature = isSignature,
	isSovereign = isSovereign,
	SIGNATURE_COLOR = SIGNATURE_COLOR,
	Pools = RARITY_UNITS,
	Rarity = UNIT_RARITY,
	Emoji = UNIT_EMOJIS,
	getBaseOneIn = getBaseOneIn,
}
