-- Display order, odds and colours shared by the physical wheel and the server's reward roll.
local rewards = {
	{ id = "gold_1k", weight = 50, label = "+1k Gold", face = "1,000\nGOLD", color = Color3.fromRGB(158, 120, 46) },
	{ id = "luck_buff", weight = 10, label = "2x Luck 5min", face = "2x LUCK\n5 MIN", color = Color3.fromRGB(45, 111, 74) },
	{ id = "gems_50", weight = 16, label = "+50 Gems", face = "50\nGEMS", color = Color3.fromRGB(50, 108, 133) },
	{ id = "graves_5", weight = 10, label = "+5 Ancient Graves", face = "5 ANCIENT\nGRAVES", color = Color3.fromRGB(111, 74, 130), graveType = "Ancient", count = 5 },
	{ id = "gems_100", weight = 8, label = "+100 Gems", face = "100\nGEMS", color = Color3.fromRGB(48, 69, 124) },
	{ id = "grave_rare", weight = 5, label = "+1 Shadow Grave", face = "1 SHADOW\nGRAVE", color = Color3.fromRGB(76, 48, 102), graveType = "Shadow", count = 1 },
	{ id = "lucky_box", weight = 1, label = "Lucky Box!", face = "LUCKY\nBOX", color = Color3.fromRGB(122, 52, 53) },
}

-- Start halfway before Gold so the default resting pointer is at the centre of its 50% slice.
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
