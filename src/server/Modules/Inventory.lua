-- Inventory requests from the client: sell, reorder, and (re)sending the data snapshot.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(script.Parent.Remotes)
local PlayerData = require(script.Parent.PlayerData)
local Economy = require(ReplicatedStorage.Shared.Economy)

-- Sell the unit in inventory slot `slot` for gold.
Remotes.SellUnit.OnServerEvent:Connect(function(player, slot)
	local profile = PlayerData.get(player)
	if not profile then return end
	local unit = PlayerData.takeUnit(player, slot)
	if not unit then return end
	local sellValue = Economy.sellValue(unit.oneIn)
	PlayerData.addGold(player, math.floor(sellValue * Economy.sellGoldMultiplier(profile.upgrades.coinBoost)))
	Remotes.AddGold:FireClient(player, sellValue, unit.unitType) -- banner only
	print("💰 " .. player.Name .. " sold " .. unit.unitType .. " for " .. sellValue .. " gold")
end)

-- Swap two inventory slots (used when picking a unit from the inventory panel).
Remotes.SwapInventory.OnServerEvent:Connect(function(player, a, b)
	PlayerData.swapSlots(player, a, b)
end)

-- The client asks for a snapshot once its UI is ready.
Remotes.RequestData.OnServerEvent:Connect(function(player)
	PlayerData.sync(player)
end)

return {}
