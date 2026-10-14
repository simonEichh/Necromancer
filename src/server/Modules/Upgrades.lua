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

-- Realm upgrades (Economy.REALM_UPGRADES): one level per request, for gold
Remotes.BuyRealmUpgrade.OnServerEvent:Connect(function(player, key)
	local profile = PlayerData.get(player)
	if not profile or type(key) ~= "string" or not Economy.REALM_UPGRADE[key] then
		return
	end
	local level = profile.realmUpgrades[key] or 0
	local cost = Economy.realmUpgradeCost(key, level, profile.rebirthCount)
	if not cost or not PlayerData.spendGold(player, cost) then
		return
	end
	profile.realmUpgrades[key] = level + 1
	PlayerData.changed(player)
	if key == "might" then
		-- the army's damage changes at once
		local Army = require(script.Parent.Army)
		local plotState = require(script.Parent.PlotRegistry).getPlot(player)
		if plotState then
			Army.setDamageMultiplier(plotState)
		end
	end
end)

return {}
