-- DigGrave handler: rolls a unit and sends the result to the client.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(script.Parent.Remotes)
local Rolling = require(script.Parent.Rolling)
local Upgrades = require(script.Parent.Upgrades)
local Wheel = require(script.Parent.Wheel)
local Quests = require(script.Parent.Quests)
local Graves = require(ReplicatedStorage.Shared.Graves)
local Units = require(ReplicatedStorage.Shared.Units)

local GRAVES = Graves
local getPlayerUpgrades = Upgrades.getPlayerUpgrades
local getWheelData = Wheel.getWheelData
local rollRarity = Rolling.rollRarity
local rollUnit = Rolling.rollUnit
local getPity = Rolling.getPity
local getBaseOneIn = Units.getBaseOneIn
local incrementQuest = Quests.increment

Remotes.DigGrave.OnServerEvent:Connect(function(player, graveType)
	local grave = GRAVES[graveType]
	if not grave then
		return
	end

	-- Apply luck boost upgrade (each level = +10% to grave luck) + wheel luck buff
	local upgrades = getPlayerUpgrades(player)
	local wd = getWheelData(player)
	local buffMult = (tick() < wd.luckBuffEnd) and 2 or 1
	local boostedGrave = {
		luck = grave.luck * (1 + upgrades.luckBoost * 0.1) * buffMult,
		pityRarity = grave.pityRarity,
	}

	-- Roll rarity and unit
	local rarity = rollRarity(boostedGrave, player, graveType)
	local unitType = rollUnit(rarity)

	-- DON'T spawn the unit here anymore
	-- Just send the result to the client to add to collection
	local pity = getPity(player, graveType)
	local oneIn = getBaseOneIn(unitType)
	Remotes.RollResult:FireClient(player, unitType, rarity, pity, oneIn)
	incrementQuest(player, "openGraves", 1)
	print("🪦 " .. player.Name .. " dug up: " .. unitType .. " (" .. rarity .. ")")
end)

return {}
