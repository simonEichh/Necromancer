-- Upgrade purchases (luckBoost, coinBoost). Levels live in PlayerData.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(script.Parent.Remotes)
local PlayerData = require(script.Parent.PlayerData)
local Economy = require(ReplicatedStorage.Shared.Economy)

Remotes.BuyUpgrade.OnServerEvent:Connect(function(player, upgradeType)
	local profile = PlayerData.get(player)
	if not profile or type(upgradeType) ~= "string" then
		return
	end
	local max = Economy.UPGRADE_MAX[upgradeType]
	local level = profile.upgrades[upgradeType]
	if not max or not level or level >= max then
		return
	end
	if not PlayerData.spendGold(player, Economy.upgradeCost(upgradeType, level)) then
		return
	end
	PlayerData.incrementUpgrade(player, upgradeType)
	print("⚗️ " .. player.Name .. " upgraded " .. upgradeType .. " → level " .. (level + 1))
end)

return {}
