-- Display order, odds and colours shared by the physical wheel and the server's reward roll.
local rewards = {
	{ id = "gold_chest", weight = 30, label = "Gold Chest", face = "GOLD\nCHEST", color = Color3.fromRGB(158, 120, 46), minutes = 10 }, -- minutes of the army's hit income,
	{ id = "luck_potion", weight = 10, label = "Luck Potion", face = "LUCK\nPOTION", color = Color3.fromRGB(45, 111, 74), count = 1, duration = 300 },
	{ id = "gems", weight = 16, label = "75 Gems", face = "75\nGEMS", color = Color3.fromRGB(50, 108, 133), count = 75 },
	{ id = "grave_hoard", weight = 20, label = "Grave Hoard", face = "GRAVE\nHOARD", color = Color3.fromRGB(111, 74, 130), count = 3 },
	{ id = "dust_cache", weight = 15, label = "Dust Cache", face = "DUST\nCACHE", color = Color3.fromRGB(48, 69, 124), count = 12 },
	{ id = "fortune_bundle", weight = 8, label = "Fortune Catalysts", face = "FORTUNE\nCATALYSTS", color = Color3.fromRGB(76, 48, 102), count = 3 },
	{ id = "spectral_crown", weight = 1, label = "Spectral Crown", face = "SPECTRAL\nCROWN", color = Color3.fromRGB(122, 52, 53), itemKey = "SpectralCrown", duplicateGems = 250 },
}

-- Start halfway before Gold so the resting pointer is at the centre of its slice.
local total = 0
for _, reward in ipairs(rewards) do total += reward.weight end
local angle = -math.pi * rewards[1].weight / total
for _, reward in ipairs(rewards) do
	reward.startAngle = angle
	reward.arc = 2 * math.pi * reward.weight / total
	reward.centerAngle = angle + reward.arc / 2
	angle += reward.arc
	reward.endAngle = angle
end

return rewards
