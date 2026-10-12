-- DigGrave handler: uses up owned graves, rolls units, stores them in the inventory
-- and sends the results to the client for the reveal animation.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(script.Parent.Remotes)
local PlayerData = require(script.Parent.PlayerData)
local Rolling = require(script.Parent.Rolling)
local Wheel = require(script.Parent.Wheel)
local Quests = require(script.Parent.Quests)
local Graves = require(ReplicatedStorage.Shared.Graves)
local Units = require(ReplicatedStorage.Shared.Units)

local getWheelData = Wheel.getWheelData
local rollRarity = Rolling.rollRarity
local rollUnit = Rolling.rollUnit
local getPity = Rolling.getPity
local getBaseOneIn = Units.getBaseOneIn
local incrementQuest = Quests.increment

local MAX_PULLS = 10 -- most graves opened in one request

-- DigGrave(graveType, count): opens up to `count` graves of that type (default 1). It stops early when the player runs out
-- of graves or inventory space, and answers with ONE RollResult carrying the list of results:
-- { { unitType, rarity, pity, oneIn }, ... } (pity is the pity counter right after that roll).
Remotes.DigGrave.OnServerEvent:Connect(function(player, graveType, count)
	local profile = PlayerData.get(player)
	local grave = type(graveType) == "string" and Graves[graveType]
	if not profile or not grave then
		return
	end
	count = math.clamp(math.floor(tonumber(count) or 1), 1, MAX_PULLS)

	-- Luck: each luckBoost level = +10% and the wheel buff doubles it; it multiplies the weights of Rare and better
	local wd = getWheelData(player)
	local buffMult = (tick() < wd.luckBuffEnd) and 2 or 1
	local boostedGrave = {
		odds = grave.odds,
		luckFactor = (1 + profile.upgrades.luckBoost * 0.1) * buffMult,
		pityRarity = grave.pityRarity,
	}

	local results = {}
	for _ = 1, count do
		-- Must own the grave and have room for the unit
		if (profile.ownedGraves[graveType] or 0) <= 0 then
			break
		end
		if not PlayerData.hasFreeSlot(player) then
			if #results == 0 then
				Remotes.Notice:FireClient(player, "Inventory full!")
			end
			break
		end
		PlayerData.consumeGrave(player, graveType)

		-- Roll rarity and unit
		local rarity = rollRarity(boostedGrave, player, graveType)
		local unitType = rollUnit(rarity)
		local oneIn = getBaseOneIn(unitType)
		PlayerData.addUnit(player, unitType, oneIn)

		table.insert(results, { unitType = unitType, rarity = rarity, pity = getPity(player, graveType), oneIn = oneIn })
		print("🪦 " .. player.Name .. " dug up: " .. unitType .. " (" .. rarity .. ")")
	end

	if #results == 0 then
		Remotes.DigRejected:FireClient(player)
		return
	end
	Remotes.RollResult:FireClient(player, results)
	incrementQuest(player, "openGraves", #results)
end)

return {}
