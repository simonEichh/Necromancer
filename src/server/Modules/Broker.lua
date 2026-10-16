-- The Soul Broker (gem stall in the plaza): BuyBrokerDeal(portrait, rot) buys what that portrait offers this player
-- in rotation `rot` (shared BrokerDeals). The client sends the rotation it saw, so a deal that rotated away under the
-- player's click is refused instead of buying the next one. Stock is per player per rotation, saved
-- (`profile.broker = { rot, bought = { [portrait] = n } }`) so rejoining does not refill it.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(script.Parent.Remotes)
local PlayerData = require(script.Parent.PlayerData)
local BrokerDeals = require(ReplicatedStorage.Shared.BrokerDeals)
local Units = require(ReplicatedStorage.Shared.Units)

local lastRequest = {} -- [UserId] = os.clock() of the last purchase

game:GetService("Players").PlayerRemoving:Connect(function(player)
	lastRequest[player.UserId] = nil
end)

Remotes.BuyBrokerDeal.OnServerEvent:Connect(function(player, portrait, rot)
	local profile = PlayerData.get(player)
	if not profile or type(portrait) ~= "number" or not BrokerDeals.PORTRAITS[portrait] or type(rot) ~= "number" then
		return
	end
	local now = os.clock()
	if lastRequest[player.UserId] and now - lastRequest[player.UserId] < 0.3 then
		return
	end
	lastRequest[player.UserId] = now

	local current = BrokerDeals.rotation(workspace:GetServerTimeNow())
	if rot ~= current then
		Remotes.Notice:FireClient(player, "The Broker has changed his wares. Look again.")
		return
	end
	if profile.broker.rot ~= current then
		profile.broker = { rot = current, bought = { 0, 0, 0, 0 } } -- (always dense: sparse arrays do not survive remotes)
	end
	local offer = BrokerDeals.offer(current, portrait, profile.rebirthCount)
	local bought = profile.broker.bought[portrait] or 0
	if bought >= offer.stock then
		Remotes.Notice:FireClient(player, "Sold out for you this hour.")
		return
	end
	if offer.unitType and not PlayerData.hasFreeSlot(player) then
		Remotes.Notice:FireClient(player, "Your inventory is full.")
		return
	end
	if not PlayerData.spendGems(player, offer.price) then
		Remotes.Notice:FireClient(player, "Not enough Gems (" .. offer.price .. " needed).")
		return
	end
	profile.broker.bought[portrait] = bought + 1
	if offer.unitType then
		PlayerData.addUnit(player, offer.unitType, Units.getBaseOneIn(offer.unitType))
	end
	if offer.catalyst then
		PlayerData.addCatalyst(player, offer.catalyst, offer.catalystCount)
	end
	if offer.dust then
		PlayerData.addMaterial(player, offer.dust, offer.dustCount)
	end
	if offer.potions then
		PlayerData.addLuckPotions(player, offer.potions)
	end
	PlayerData.changed(player)
	Remotes.Notice:FireClient(player, "Bought: " .. offer.name .. ".")
end)

return {}
