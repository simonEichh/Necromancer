-- Rarity tables shared by server and client.

-- Rarity → Color3 for labels
local RARITY_COLOR = {
	Common = Color3.fromRGB(200, 200, 200),
	Uncommon = Color3.fromRGB(100, 220, 100),
	Rare = Color3.fromRGB(80, 150, 255),
	Cursed = Color3.fromRGB(180, 80, 255),
	Legendary = Color3.fromRGB(255, 200, 50),
	Abyssal = Color3.fromRGB(220, 50, 50),
	Eldritch = Color3.fromRGB(50, 220, 200),
	Eternal = Color3.fromRGB(240, 240, 255),
}

-- Base rarity odds at 1× luck (all graves share this curve)
local BASE_ODDS = {
	Common = 45,
	Uncommon = 25,
	Rare = 15,
	Cursed = 8,
	Legendary = 4,
	Abyssal = 2,
	Eldritch = 0.75,
	Eternal = 0.25,
}

local RARITY_RANK = {
	Common = 1,
	Uncommon = 2,
	Rare = 3,
	Cursed = 4,
	Legendary = 5,
	Abyssal = 6,
	Eldritch = 7,
	Eternal = 8,
}
local RARITY_ORDER = { "Eternal", "Eldritch", "Abyssal", "Legendary", "Cursed", "Rare", "Uncommon", "Common" }

return {
	Color = RARITY_COLOR,
	BaseOdds = BASE_ODDS,
	Rank = RARITY_RANK,
	Order = RARITY_ORDER,
}
