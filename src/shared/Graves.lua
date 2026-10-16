-- Grave tier definitions shared by server and client.
--
-- Every grave has its own rarity table `odds` (percent, normalised when rolling, so they only need to be roughly 100):
-- the better the grave, the better the units, and the best rarities only turn up in the best graves.
-- Luck upgrades and the wheel buff multiply the weights of Rare and better (see Rolling). `pityRarity`: after 60 rolls
-- without that rarity or better the next roll is at least that rarity.
-- Tuned with tools/sim/economy_sim.py (tools/sim/dump_lua.py prints these tables).
local GRAVES = {
	Mossy = {
		name = "Mossy Grave",
		cost = 100,
		odds = { Common = 84.151, Uncommon = 13.337, Rare = 2.114, Cursed = 0.335, Legendary = 0.053, Abyssal = 0.008, Eldritch = 0.001 },
		pityRarity = "Rare",
		unlockAscension = 0,
	},
	Stone = {
		name = "Stone Coffin",
		cost = 1500,
		odds = { Common = 9.986, Uncommon = 75.748, Rare = 12.005, Cursed = 1.903, Legendary = 0.302, Abyssal = 0.048, Eldritch = 0.008, Eternal = 0.001 },
		pityRarity = "Cursed",
		unlockAscension = 1,
	},
	Ancient = {
		name = "Ancient Tomb",
		cost = 25000,
		odds = { Common = 1.119, Uncommon = 22.335, Rare = 64.415, Cursed = 10.209, Legendary = 1.618, Abyssal = 0.256, Eldritch = 0.041, Eternal = 0.006 },
		pityRarity = "Legendary",
		unlockAscension = 2,
	},
	Cursed = {
		name = "Cursed Crypt",
		cost = 400000,
		odds = { Common = 0.107, Uncommon = 2.128, Rare = 42.454, Cursed = 46.550, Legendary = 7.378, Abyssal = 1.169, Eldritch = 0.185, Eternal = 0.029 },
		pityRarity = "Legendary",
		unlockAscension = 3,
	},
	Shadow = {
		name = "Shadow Vault",
		cost = 6000000,
		odds = { Common = 0.008, Uncommon = 0.162, Rare = 3.238, Cursed = 64.606, Legendary = 26.932, Abyssal = 4.268, Eldritch = 0.677, Eternal = 0.107, Primordial = 0.001 },
		pityRarity = "Abyssal",
		unlockAscension = 4,
	},
	Abyssal = {
		name = "Abyssal Tomb",
		cost = 40000000, -- (late tiers grow x6-10, not x16: the newest grave stays affordable each stage; sim 2026-10-16)
		odds = { Common = 0.001, Uncommon = 0.010, Rare = 0.203, Cursed = 4.041, Legendary = 80.619, Abyssal = 12.777, Eldritch = 2.025, Eternal = 0.321, Primordial = 0.004 },
		pityRarity = "Abyssal",
		unlockAscension = 5,
	},
	Eldritch = {
		name = "Eldritch Reliquary",
		cost = 400000000,
		odds = { Uncommon = 0.001, Rare = 0.025, Cursed = 0.500, Legendary = 9.966, Abyssal = 75.602, Eldritch = 11.982, Eternal = 1.899, Primordial = 0.024 },
		pityRarity = "Eldritch",
		unlockAscension = 6,
	},
	Void = {
		name = "Void Sanctum",
		cost = 3000000000,
		odds = { Rare = 0.003, Cursed = 0.057, Legendary = 1.139, Abyssal = 22.729, Eldritch = 65.551, Eternal = 10.389, Primordial = 0.132 },
		pityRarity = "Eldritch",
		unlockAscension = 7,
	},
	Eternal = {
		name = "Eternal Throne",
		cost = 20000000000,
		odds = { Cursed = 0.006, Legendary = 0.116, Abyssal = 2.317, Eldritch = 46.229, Eternal = 50.689, Primordial = 0.643 },
		pityRarity = "Eternal",
		unlockAscension = 8,
	},
	Celestial = {
		name = "Celestial Abyss",
		cost = 120000000000,
		odds = { Cursed = 0.001, Legendary = 0.012, Abyssal = 0.231, Eldritch = 4.615, Eternal = 92.071, Primordial = 3.071 },
		pityRarity = "Eternal",
		unlockAscension = 9,
	},
}

return GRAVES
