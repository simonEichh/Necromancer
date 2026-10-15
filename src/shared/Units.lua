-- Unit stats, rarity pools and drop-chance helpers shared by server and client.
local Rarities = require(script.Parent.Rarities)
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
	},
	-- Malak, the Envoy: the first Sovereign (docs/envoy.md). WORK IN PROGRESS: weight 0 in the pool, so he can only be
	-- spawned from the DEV panel; placeholder numbers. Basic attack, the orbital tag (model AttackStyle "OrbitalTag",
	-- client OrbitalStrike.lua): while he fights his hologram pad opens into a big hologram in front of him; he taps it
	-- once, a red laser cuts diagonally out of the sky onto the wall, then a shell from a cannon far above hits it.
	-- One slow, heavy hit every 6.5 s; the damage lands with the shell (hitDelay must match OrbitalStrike.IMPACT_AT).
	Malak = {
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
		{ unit = "Malak", weight = 0 }, -- (work in progress: never rolled yet)
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
local SIGNATURE_COLOR = Color3.fromRGB(255, 226, 150)
local function isSignature(unitType)
	local def = UNITS[unitType]
	return def ~= nil and def.special ~= nil
end

-- Units that were replaced or renamed: old saves still hold the old key and are migrated on load (Persistence)
local RENAMED = {
	Goblin = "HollowArcher",
	Ghost = "CryptSpider",
}

return {
	Stats = UNITS,
	RENAMED = RENAMED,
	isSignature = isSignature,
	SIGNATURE_COLOR = SIGNATURE_COLOR,
	Pools = RARITY_UNITS,
	Rarity = UNIT_RARITY,
	Emoji = UNIT_EMOJIS,
	getBaseOneIn = getBaseOneIn,
}
