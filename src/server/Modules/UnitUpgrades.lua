-- The Forge: upgrading units with materials and dismantling spare units into materials. Server authoritative: the client only
-- sends requests (UpgradeUnit, DismantleUnit) and receives UpgradeResult plus the usual DataSync snapshot.
--
--   UpgradeUnit(kind, index)   kind "inv" (inventory slot) or "grave" (grave slot with a unit standing on it)
--   DismantleUnit(slot)        inventory units only
--   BuyCatalyst(key, qty)      gems for catalysts (Economy.CATALYST_INFO); UpgradeUnit's useFortune / useWarding use them
--   BuyDust(dust, qty)         the Buy Dust tab: gold for dust, limited stock per restock (GraveShop), unlocked by ascension
--
-- Rules (numbers in Economy, tuned with tools/sim/economy_sim.py): a unit is upgraded with the dust of ITS rarity
-- (Economy.dustOf); going from level L to L + 1 costs Economy.unitUpgradeCost(L, rarity) dust and works with Economy.upgradeChance(L, fails). A failure
-- never lowers the level: it costs part of the materials and raises the chance of the next try (pity, saved with the unit).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(script.Parent.Remotes)
local PlayerData = require(script.Parent.PlayerData)
local PlotRegistry = require(script.Parent.PlotRegistry)
local Army = require(script.Parent.Army)
local Economy = require(ReplicatedStorage.Shared.Economy)
local Units = require(ReplicatedStorage.Shared.Units)
local Rarities = require(ReplicatedStorage.Shared.Rarities)
local ShopNpcs = require(script.Parent.ShopNpcs)
local GraveShop = require(script.Parent.GraveShop)

local lastRequest = {} -- [UserId] = os.clock() of the last upgrade/dismantle request (a little rate limit)
local MIN_INTERVAL = 0.12

local function throttled(player)
	local now = os.clock()
	if lastRequest[player.UserId] and now - lastRequest[player.UserId] < MIN_INTERVAL then
		return true
	end
	lastRequest[player.UserId] = now
	return false
end

game:GetService("Players").PlayerRemoving:Connect(function(player)
	lastRequest[player.UserId] = nil
end)

Remotes.BuyDust.OnServerEvent:Connect(function(player, dust, qty)
	local profile = PlayerData.get(player)
	if not profile or throttled(player) or type(dust) ~= "string" or type(qty) ~= "number" or qty ~= qty then
		return
	end
	if not ShopNpcs.nearForge(player) then
		Remotes.Notice:FireClient(player, "Visit the Forge to buy dust.")
		return
	end
	local d = Economy.dustIndex(dust)
	local stock = GraveShop.dustStock(player)
	if not d or not stock or (profile.rebirthCount or 0) < Economy.dustShopUnlock(d) then
		return
	end
	local price = Economy.dustPrice(d)
	local amount = math.min(math.floor(qty), stock[dust] or 0, math.floor(profile.gold / price))
	if amount <= 0 then
		return
	end
	if not PlayerData.spendGold(player, price * amount) then
		return
	end
	stock[dust] -= amount
	PlayerData.addMaterial(player, dust, amount)
	GraveShop.sendDustStock(player)
end)

Remotes.BuyCatalyst.OnServerEvent:Connect(function(player, key, qty)
	local profile = PlayerData.get(player)
	if not profile or throttled(player) or type(key) ~= "string" or type(qty) ~= "number" or qty ~= qty then
		return
	end
	local info = Economy.CATALYST_INFO[key]
	if not info then
		return
	end
	if not ShopNpcs.nearForge(player) then
		Remotes.Notice:FireClient(player, "Visit the Forge to buy catalysts.")
		return
	end
	local amount = math.min(math.floor(qty), 10, math.floor(profile.gems / info.price))
	if amount <= 0 then
		Remotes.Notice:FireClient(player, "Not enough Gems (" .. info.price .. " needed).")
		return
	end
	if PlayerData.spendGems(player, info.price * amount) then
		PlayerData.addCatalyst(player, key, amount)
	end
end)

Remotes.UpgradeUnit.OnServerEvent:Connect(function(player, kind, index, useFortune, useWarding)
	local profile = PlayerData.get(player)
	if not profile or throttled(player) or type(index) ~= "number" or index % 1 ~= 0 then
		return
	end
	if not ShopNpcs.nearForge(player) then
		Remotes.Notice:FireClient(player, "Visit the Forge to upgrade units.")
		return
	end

	-- find the unit
	local unitType, level, fails, plotState
	local invUnit
	if kind == "inv" then
		invUnit = PlayerData.getUnit(player, index)
		if not invUnit then return end
		unitType, level, fails = invUnit.unitType, invUnit.level or 0, invUnit.fails or 0
	elseif kind == "grave" then
		plotState = PlotRegistry.getPlot(player)
		local slot = plotState and plotState.graveSlots[index]
		if not slot or not slot.occupied then return end
		unitType, level, fails = slot.unitType, slot.level or 0, slot.fails or 0
	else
		return
	end

	if level >= Economy.MAX_UNIT_LEVEL then
		Remotes.Notice:FireClient(player, unitType .. " is already at the maximum level.")
		return
	end
	local rarity = Units.Rarity[unitType]
	local dust = Economy.dustOf(rarity)
	local cost = Economy.unitUpgradeCost(level, rarity)
	if (profile.materials[dust] or 0) < cost then
		Remotes.Notice:FireClient(player, "Not enough " .. Economy.DUST_NAMES[dust] .. " (" .. cost .. " needed).")
		return
	end

	-- the roll (a Fortune Catalyst raises the chance and is used up; a Warding Catalyst is only used up when it saves the
	-- dust of a failed attempt)
	local chance = Economy.upgradeChance(level, fails)
	if useFortune == true and chance < 1 and PlayerData.useCatalyst(player, "Fortune") then
		chance = math.min(1, chance + Economy.FORTUNE_BONUS)
	end
	local success = math.random() < chance
	if success then
		PlayerData.spendMaterial(player, dust, cost)
		level += 1
		fails = 0
	else
		if not (useWarding == true and PlayerData.useCatalyst(player, "Warding")) then
			PlayerData.spendMaterial(player, dust, Economy.upgradeFailLoss(cost))
		end
		fails += 1
	end

	if kind == "inv" then
		invUnit.level, invUnit.fails = level, fails
	else
		Army.setUnitLevel(plotState, index, level, fails)
	end
	PlayerData.changed(player)
	Remotes.UpgradeResult:FireClient(player, success, unitType, level, success and 1 or chance)
end)

Remotes.DismantleUnit.OnServerEvent:Connect(function(player, slot)
	local profile = PlayerData.get(player)
	if not profile or throttled(player) then
		return
	end
	if not ShopNpcs.nearForge(player) then
		Remotes.Notice:FireClient(player, "Visit the Forge to dismantle units.")
		return
	end
	local unit = PlayerData.getUnit(player, slot)
	if not unit then return end
	if unit.locked then
		Remotes.Notice:FireClient(player, unit.unitType .. " is locked. Unlock it in the inventory to dismantle it.")
		return
	end
	local rarity = Units.Rarity[unit.unitType]
	local amount = Economy.dismantleYield(Rarities.Rank[rarity] or 1)
	PlayerData.takeUnit(player, slot)
	local dust = Economy.dustOf(rarity)
	PlayerData.addMaterial(player, dust, amount)
	Remotes.Notice:FireClient(player, "Dismantled " .. unit.unitType .. ": +" .. amount .. " " .. Economy.DUST_NAMES[dust])
end)

return {}
