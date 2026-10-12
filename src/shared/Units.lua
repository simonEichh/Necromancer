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
	},
	Zombie = {
		color = BrickColor.new("Medium green"),
		size = Vector3.new(2.2, 2.2, 2.2),
		damage = 20,
		speed = 5,
		attackRange = 5,
		attackCD = 2.0,
	},
	Ghoul = {
		color = BrickColor.new("Dark orange"),
		size = Vector3.new(1.8, 1.8, 1.8),
		damage = 18,
		speed = 14,
		attackRange = 6,
		attackCD = 1.2,
	},
	-- ── Uncommon ────────────────────────────────────────────────────────
	Ghost = {
		color = BrickColor.new("Pastel blue"),
		size = Vector3.new(2.2, 2.2, 2.2),
		damage = 26,
		speed = 14,
		attackRange = 10,
		attackCD = 0.8,
		transparent = true,
	},
	Goblin = {
		color = BrickColor.new("Bright green"),
		size = Vector3.new(1.8, 1.8, 1.8),
		damage = 35,
		speed = 16,
		attackRange = 30,
		attackCD = 1.0,
		poison = 3,
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
		damage = 29,
		speed = 22,
		attackRange = 12,
		attackCD = 0.6,
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
		poison = 5,
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
	-- it, and small sigil circles open in the air in a cone whose tip is on the wall (attack style "SigilCast", see
	-- SpellEffects). Its darts leave the small circles and fly `shotFlight` seconds, slow at first and then accelerating.
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
		{ unit = "Ghost", weight = 4 },
		{ unit = "Goblin", weight = 3 },
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
	},
	Primordial = {
		{ unit = "LastLantern", weight = 1 },
		{ unit = "Sigilwright", weight = 1 },
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
	Ghost = "",
	Goblin = "",
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
	-- Primordial
	LastLantern = "",
	Sigilwright = "",
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

return {
	Stats = UNITS,
	Pools = RARITY_UNITS,
	Rarity = UNIT_RARITY,
	Emoji = UNIT_EMOJIS,
	getBaseOneIn = getBaseOneIn,
}
