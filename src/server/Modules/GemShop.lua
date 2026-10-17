-- The Gem Shop: gem purchases that are not tied to a place (the client panel is Modules/GemShopPanel, opened from the
-- HUD's Shop tile). Catalysts are bought with BuyCatalyst (UnitUpgrades); this module handles:
--   BuyGemItem("RemoteForge")   one-time, Economy.REMOTE_FORGE_PRICE: the Forge works anywhere (ShopNpcs.nearForge)
--   BuyGemItem("WispSpeed")     the next Soul Wisp speed level (needs the wisp; Economy.wispLevelPrice / wispSpeed)
--   BuyGemItem("FleetStrike")   one-time, Economy.FLEET_STRIKE_PRICE: Malak's gate finisher (Army.checkFinisher)
--   BuyGemItem("FinalHorizon")  one-time, Economy.FINAL_HORIZON_PRICE: Veyr's gate finisher (separate from the above)
--   BuyGemItem("LastBroadside") one-time, Economy.LAST_BROADSIDE_PRICE: Orvoss's gate finisher
--   BuyGemItem("CommanderSlot") one-time, Economy.COMMANDER_SLOT_PRICE: the second commander throne (Plots unseals it)
-- Server authoritative: it checks the gems and the limits and changes the profile through PlayerData.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(script.Parent.Remotes)
local PlayerData = require(script.Parent.PlayerData)
local Economy = require(ReplicatedStorage.Shared.Economy)

local lastRequest = {} -- [UserId] = os.clock() of the last purchase (a little rate limit)

game:GetService("Players").PlayerRemoving:Connect(function(player)
	lastRequest[player.UserId] = nil
end)

local GemShop = {}

function GemShop.buy(player, item)
	local profile = PlayerData.get(player)
	if not profile or type(item) ~= "string" then
		return
	end
	local now = os.clock()
	if lastRequest[player.UserId] and now - lastRequest[player.UserId] < 0.3 then
		return
	end
	lastRequest[player.UserId] = now

	if item == "RemoteForge" then
		if profile.remoteForge then
			return
		end
		if not PlayerData.spendGems(player, Economy.REMOTE_FORGE_PRICE) then
			Remotes.Notice:FireClient(player, "Not enough Gems (" .. Economy.REMOTE_FORGE_PRICE .. " needed).")
			return
		end
		profile.remoteForge = true
		PlayerData.changed(player)
		Remotes.Notice:FireClient(player, "Remote Forge unlocked: open the Forge from the button on the left.")
	elseif item == "FleetStrike" then
		if profile.fleetStrike then
			return
		end
		if not PlayerData.spendGems(player, Economy.FLEET_STRIKE_PRICE) then
			Remotes.Notice:FireClient(player, "Not enough Gems (" .. Economy.FLEET_STRIKE_PRICE .. " needed).")
			return
		end
		profile.fleetStrike = true
		PlayerData.changed(player)
		Remotes.Notice:FireClient(player, "Fleet Strike unlocked: with Malak on your plot, the Absolution executes the gate at 20%.")
	elseif item == "FinalHorizon" then
		if profile.finalHorizon then
			return
		end
		if not PlayerData.spendGems(player, Economy.FINAL_HORIZON_PRICE) then
			Remotes.Notice:FireClient(player, "Not enough Gems (" .. Economy.FINAL_HORIZON_PRICE .. " needed).")
			return
		end
		profile.finalHorizon = true
		PlayerData.changed(player)
		Remotes.Notice:FireClient(player, "The Final Horizon unlocked: with Veyr on a commander throne, he takes the gate at 20%.")
	elseif item == "LastBroadside" then
		if profile.lastBroadside then
			return
		end
		if not PlayerData.spendGems(player, Economy.LAST_BROADSIDE_PRICE) then
			Remotes.Notice:FireClient(player, "Not enough Gems (" .. Economy.LAST_BROADSIDE_PRICE .. " needed).")
			return
		end
		profile.lastBroadside = true
		PlayerData.changed(player)
		Remotes.Notice:FireClient(player, "The Last Broadside unlocked: with Orvoss on a commander throne, his fleet takes the gate at 20%.")
	elseif item == "CommanderSlot" then
		if (profile.commanderSlots or 1) >= Economy.MAX_COMMANDER_SLOTS then
			return
		end
		if not PlayerData.spendGems(player, Economy.COMMANDER_SLOT_PRICE) then
			Remotes.Notice:FireClient(player, "Not enough Gems (" .. Economy.COMMANDER_SLOT_PRICE .. " needed).")
			return
		end
		profile.commanderSlots = (profile.commanderSlots or 1) + 1
		PlayerData.changed(player)
		if PlayerData.onCommanderSlots then
			PlayerData.onCommanderSlots(player)
		end
		Remotes.Notice:FireClient(player, "A second commander throne: two Signatures can lead your army now.")
	elseif item == "WispSpeed" then
		local level = profile.wispLevel or 0
		if not profile.collector or level >= Economy.WISP_MAX_LEVEL then
			return
		end
		local price = Economy.wispLevelPrice(level)
		if not PlayerData.spendGems(player, price) then
			Remotes.Notice:FireClient(player, "Not enough Gems (" .. price .. " needed).")
			return
		end
		profile.wispLevel = level + 1
		PlayerData.changed(player)
	end
end
Remotes.BuyGemItem.OnServerEvent:Connect(GemShop.buy)

return GemShop
