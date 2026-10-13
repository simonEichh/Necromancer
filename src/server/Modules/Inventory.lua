-- Inventory requests from the client: sell, reorder, and (re)sending the data snapshot.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(script.Parent.Remotes)
local PlayerData = require(script.Parent.PlayerData)
local Economy = require(ReplicatedStorage.Shared.Economy)
local Units = require(ReplicatedStorage.Shared.Units)
local Rarities = require(ReplicatedStorage.Shared.Rarities)

local SELL_ALL_INTERVAL = 1 -- seconds between two "sell all" requests of one player
local lastSellAll = {}

-- Sell the unit in inventory slot `slot` for gold.
Remotes.SellUnit.OnServerEvent:Connect(function(player, slot)
	local profile = PlayerData.get(player)
	if not profile then return end
	local held = PlayerData.getUnit(player, slot)
	if not held or held.locked then return end
	local unit = PlayerData.takeUnit(player, slot)
	if not unit then return end
	local sellValue = Economy.sellValue(unit.oneIn)
	PlayerData.addGold(player, math.floor(sellValue * Economy.sellGoldMultiplier(profile.upgrades.coinBoost)))
	Remotes.AddGold:FireClient(player, sellValue, unit.unitType) -- banner only
	print("💰 " .. player.Name .. " sold " .. unit.unitType .. " for " .. sellValue .. " gold")
end)

-- Sell every unlocked inventory unit whose rarity rank is `maxRank` or lower (1 = Common); with `keepUpgraded` units
-- above level 0 are kept too. Units standing on graves are not in the inventory, so they are never touched.
Remotes.SellAll.OnServerEvent:Connect(function(player, maxRank, keepUpgraded)
	local profile = PlayerData.get(player)
	if not profile or type(maxRank) ~= "number" or maxRank ~= maxRank then return end
	local now = os.clock()
	if lastSellAll[player.UserId] and now - lastSellAll[player.UserId] < SELL_ALL_INTERVAL then return end
	lastSellAll[player.UserId] = now
	local mult = Economy.sellGoldMultiplier(profile.upgrades.coinBoost)
	local sold, gold = 0, 0
	for slot, unit in pairs(profile.inventory) do
		local rank = Rarities.Rank[Units.Rarity[unit.unitType]] or 1
		if not unit.locked and rank <= maxRank and not (keepUpgraded == true and (unit.level or 0) > 0) then
			if PlayerData.takeUnit(player, slot) then
				sold += 1
				gold += math.floor(Economy.sellValue(unit.oneIn) * mult)
			end
		end
	end
	if sold == 0 then
		Remotes.Notice:FireClient(player, "Nothing to sell.")
		return
	end
	PlayerData.addGold(player, gold)
	Remotes.Notice:FireClient(player, "Sold " .. sold .. " units for " .. gold .. " Gold.")
	print("💰 " .. player.Name .. " sold " .. sold .. " units for " .. gold .. " gold")
end)

Remotes.ToggleLock.OnServerEvent:Connect(function(player, slot)
	PlayerData.toggleLock(player, slot)
end)

game:GetService("Players").PlayerRemoving:Connect(function(player)
	lastSellAll[player.UserId] = nil
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
