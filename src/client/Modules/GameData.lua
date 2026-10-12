-- Client-side unit/grave display data, derived from the shared server data
-- (src/shared) so the two can no longer drift apart.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local SharedUnits = require(Shared:WaitForChild("Units"))
local SharedGraves = require(Shared:WaitForChild("Graves"))
local Rarities = require(Shared:WaitForChild("Rarities"))

local RARITY_COLORS = Rarities.Color

local UNIT_INFO = {}
local UNIT_COLORS = {}
local UNIT_DPS = {}
local UNIT_ONE_IN = {}
for unitType, def in pairs(SharedUnits.Stats) do
	local rarity = SharedUnits.Rarity[unitType]
	UNIT_INFO[unitType] = {
		emoji = SharedUnits.Emoji[unitType],
		rarity = rarity,
		rarityColor = RARITY_COLORS[rarity],
	}
	UNIT_COLORS[unitType] = def.color
	UNIT_DPS[unitType] = math.floor(def.damage / def.attackCD) -- matches server DPS
	UNIT_ONE_IN[unitType] = SharedUnits.getBaseOneIn(unitType) -- base odds, no luck
end

-- Every unit key, lowest rarity first (used by the roll animation)
local ALL_UNIT_KEYS = {}
for i = #Rarities.Order, 1, -1 do
	for _, entry in ipairs(SharedUnits.Pools[Rarities.Order[i]]) do
		table.insert(ALL_UNIT_KEYS, entry.unit)
	end
end

-- UI-only grave extras (the rest comes from the shared GRAVES table)
local C = Color3.fromRGB
local GRAVE_UI = {
	Mossy = { emoji = "", image = "rbxassetid://75308456335180", color = C(55, 85, 55) },
	Stone = { emoji = "", image = "rbxassetid://77145781270719", color = C(70, 70, 90) },
	Ancient = { emoji = "", image = "rbxassetid://110643368436289", color = C(90, 70, 20) },
	Cursed = { emoji = "", image = "rbxassetid://127271561685050", color = C(80, 20, 80) },
	Shadow = { emoji = "", image = "rbxassetid://122618880404468", color = C(20, 20, 40) },
	Abyssal = { emoji = "", image = "rbxassetid://79850946861944", color = C(120, 30, 10) },
	Eldritch = { emoji = "", image = "rbxassetid://91010271116619", color = C(10, 80, 80) },
	Void = { emoji = "", image = "rbxassetid://106891433077044", color = C(10, 10, 30) },
	Eternal = { emoji = "", image = "", color = C(80, 80, 120) },
	Celestial = { emoji = "", image = "", color = C(40, 60, 100) },
}

-- Ordered grave tier definitions
local GRAVE_ORDER = { "Mossy", "Stone", "Ancient", "Cursed", "Shadow", "Abyssal", "Eldritch", "Void", "Eternal", "Celestial" }
local GRAVE_DATA = {}
for _, key in ipairs(GRAVE_ORDER) do
	local g, ui = SharedGraves[key], GRAVE_UI[key]
	table.insert(GRAVE_DATA, {
		key = key,
		name = g.name,
		emoji = ui.emoji,
		image = ui.image,
		cost = g.cost,
		luck = g.luck,
		unlockAscension = g.unlockAscension,
		color = ui.color,
	})
end

return {
	UNIT_INFO = UNIT_INFO,
	UNIT_COLORS = UNIT_COLORS,
	UNIT_DPS = UNIT_DPS,
	UNIT_ONE_IN = UNIT_ONE_IN,
	RARITY_COLORS = RARITY_COLORS,
	GRAVE_DATA = GRAVE_DATA,
	ALL_UNIT_KEYS = ALL_UNIT_KEYS,
}
