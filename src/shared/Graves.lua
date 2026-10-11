-- Grave tier definitions shared by server and client.

-- Grave definitions — luck drives the best-of-N roll multiplier
-- 100 = 1× (one roll), 300 = 3× (three rolls, keep rarest), etc.
local GRAVES = {
	Mossy = {
		name = "Mossy Grave",
		cost = 50,
		luck = 100,
		pityRarity = "Rare",
		unlockAscension = 0,
	},
	Stone = {
		name = "Stone Coffin",
		cost = 500,
		luck = 200,
		pityRarity = "Cursed",
		unlockAscension = 1,
	},
	Ancient = {
		name = "Ancient Tomb",
		cost = 3000,
		luck = 500,
		pityRarity = "Legendary",
		unlockAscension = 2,
	},
	Cursed = {
		name = "Cursed Crypt",
		cost = 20000,
		luck = 1000,
		pityRarity = "Legendary",
		unlockAscension = 3,
	},
	Shadow = {
		name = "Shadow Vault",
		cost = 100000,
		luck = 2000,
		pityRarity = "Abyssal",
		unlockAscension = 4,
	},
	Abyssal = {
		name = "Abyssal Tomb",
		cost = 500000,
		luck = 4000,
		pityRarity = "Abyssal",
		unlockAscension = 5,
	},
	Eldritch = {
		name = "Eldritch Reliquary",
		cost = 2500000,
		luck = 8000,
		pityRarity = "Eldritch",
		unlockAscension = 6,
	},
	Void = {
		name = "Void Sanctum",
		cost = 12000000,
		luck = 16000,
		pityRarity = "Eldritch",
		unlockAscension = 7,
	},
	Eternal = {
		name = "Eternal Throne",
		cost = 60000000,
		luck = 35000,
		pityRarity = "Eternal",
		unlockAscension = 8,
	},
	Celestial = {
		name = "Celestial Abyss",
		cost = 300000000,
		luck = 75000,
		pityRarity = "Eternal",
		unlockAscension = 9,
	},
}

return GRAVES
