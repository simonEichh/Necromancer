-- DigGrave handler: uses up an owned grave, rolls a unit, stores it in the inventory
-- and sends the result to the client for the reveal animation.
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

Remotes.DigGrave.OnServerEvent:Connect(function(player, graveType)
	local profile = PlayerData.get(player)
	local grave = type(graveType) == "string" and Graves[graveType]
	if not profile or not grave then
		return
	end

	-- Must own the grave and have room for the unit
	if (profile.ownedGraves[graveType] or 0) <= 0 then
		Remotes.DigRejected:FireClient(player)
		return
	end
	if not PlayerData.hasFreeSlot(player) then
		Remotes.Notice:FireClient(player, "⚠️ Inventory full!")
		Remotes.DigRejected:FireClient(player)
		return
	end
	PlayerData.consumeGrave(player, graveType)

	-- Apply luck boost upgrade (each level = +10% to grave luck) + wheel luck buff
	local wd = getWheelData(player)
	local buffMult = (tick() < wd.luckBuffEnd) and 2 or 1
	local boostedGrave = {
		luck = grave.luck * (1 + profile.upgrades.luckBoost * 0.1) * buffMult,
		pityRarity = grave.pityRarity,
	}

	-- Roll rarity and unit
	local rarity = rollRarity(boostedGrave, player, graveType)
	local unitType = rollUnit(rarity)
	local oneIn = getBaseOneIn(unitType)
	PlayerData.addUnit(player, unitType, oneIn)

	local pity = getPity(player, graveType)
	Remotes.RollResult:FireClient(player, unitType, rarity, pity, oneIn)
	incrementQuest(player, "openGraves", 1)
	print("🪦 " .. player.Name .. " dug up: " .. unitType .. " (" .. rarity .. ")")
end)

return {}
