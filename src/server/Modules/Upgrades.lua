-- Per-player upgrade levels (luckBoost, coinBoost).
local Remotes = require(script.Parent.Remotes)

-- Per-player upgrade levels (luckBoost, coinBoost)
local playerUpgrades = {}
local UPGRADE_MAX = { luckBoost = 20, coinBoost = 15 }

local function getPlayerUpgrades(player)
	local id = tostring(player.UserId)
	if not playerUpgrades[id] then
		playerUpgrades[id] = { luckBoost = 0, coinBoost = 0 }
	end
	return playerUpgrades[id]
end

Remotes.BuyUpgrade.OnServerEvent:Connect(function(player, upgradeType)
	local upgrades = getPlayerUpgrades(player)
	local max = UPGRADE_MAX[upgradeType]
	if not max or not upgrades[upgradeType] then
		return
	end
	if upgrades[upgradeType] >= max then
		return
	end
	upgrades[upgradeType] += 1
	Remotes.UpgradeGranted:FireClient(player, upgradeType, upgrades[upgradeType])
	print("⚗️ " .. player.Name .. " upgraded " .. upgradeType .. " → level " .. upgrades[upgradeType])
end)

local function remove(player)
	playerUpgrades[tostring(player.UserId)] = nil
end

return {
	getPlayerUpgrades = getPlayerUpgrades,
	remove = remove,
}
