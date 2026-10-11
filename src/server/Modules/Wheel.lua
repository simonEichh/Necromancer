-- Lucky wheel: spin grants, outcomes and rewards.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(script.Parent.Remotes)
local PlayerData = require(script.Parent.PlayerData)
local Rolling = require(script.Parent.Rolling)
local Units = require(ReplicatedStorage.Shared.Units)
local Economy = require(ReplicatedStorage.Shared.Economy)

local rollUnit = Rolling.rollUnit
local getBaseOneIn = Units.getBaseOneIn

-- ── WHEEL DATA ───────────────────────────────────────────────
local playerWheelData = {}
local function getWheelData(player)
	local id = tostring(player.UserId)
	if not playerWheelData[id] then
		playerWheelData[id] = {
			spins = 0,
			lastGrantTime = tick(),
			luckBuffEnd = 0,
		}
	end
	return playerWheelData[id]
end

-- Wheel outcomes (7 segments matching the client display order)
local WHEEL_OUTCOMES = {
	{ id = "gold_1k",    weight = 50, label = "+1k Gold",          emoji = "💰" },
	{ id = "luck_buff",  weight = 10, label = "2x Luck 5min",      emoji = "🍀" },
	{ id = "gems_50",    weight = 16, label = "+50 Gems",          emoji = "💎" },
	{ id = "graves_5",   weight = 10, label = "+5 Ancient Graves", emoji = "🪦", graveType = "Ancient", count = 5 },
	{ id = "gems_100",   weight = 8,  label = "+100 Gems",         emoji = "💎" },
	{ id = "grave_rare", weight = 5,  label = "+1 Shadow Grave",   emoji = "🌑", graveType = "Shadow",  count = 1 },
	{ id = "lucky_box",  weight = 1,  label = "Lucky Box!",        emoji = "📦" },
}
local WHEEL_TOTAL_WEIGHT = 0
for _, o in ipairs(WHEEL_OUTCOMES) do
	WHEEL_TOTAL_WEIGHT += o.weight
end

local function rollWheelOutcome()
	local r = math.random(1, WHEEL_TOTAL_WEIGHT)
	local cum = 0
	for i, o in ipairs(WHEEL_OUTCOMES) do
		cum += o.weight
		if r <= cum then
			return i, o
		end
	end
	return 1, WHEEL_OUTCOMES[1]
end

-- ── LUCKY WHEEL ──────────────────────────────────────────────
Remotes.WheelSpin.OnServerEvent:Connect(function(player)
	local profile = PlayerData.get(player)
	local wd = getWheelData(player)
	if not profile or wd.spins <= 0 then
		return
	end
	wd.spins -= 1

	-- The server rolls the outcome; the client only animates toward the index we send.
	local idx, outcome = rollWheelOutcome()

	-- Award reward (stored in PlayerData; the client sees it via DataSync)
	local rewardData = { outcomeIdx = idx, outcome = outcome }
	if outcome.id == "gold_1k" then
		PlayerData.addGold(player, math.floor(1000 * Economy.sellGoldMultiplier(profile.upgrades.coinBoost)))
	elseif outcome.id == "luck_buff" then
		wd.luckBuffEnd = tick() + 300 -- 5 minutes
		rewardData.buffDuration = 300
	elseif outcome.id == "gems_50" then
		PlayerData.addGems(player, 50)
		rewardData.gems = 50
	elseif outcome.id == "gems_100" then
		PlayerData.addGems(player, 100)
		rewardData.gems = 100
	elseif outcome.id == "graves_5" then
		PlayerData.addGraves(player, outcome.graveType, outcome.count)
		rewardData.graveType = outcome.graveType
		rewardData.graveCount = outcome.count
	elseif outcome.id == "grave_rare" then
		PlayerData.addGraves(player, outcome.graveType, outcome.count)
		rewardData.graveType = outcome.graveType
		rewardData.graveCount = outcome.count
	elseif outcome.id == "lucky_box" then
		-- Roll 3 Legendary+ units as a bonus
		local boxUnits = {}
		local highRarities = { "Legendary", "Abyssal", "Eldritch", "Eternal" }
		local highWeights = { 60, 25, 10, 5 }
		for _ = 1, 3 do
			local rRoll = math.random(1, 100)
			local cum2 = 0
			local pickedRarity = "Legendary"
			for ri, w in ipairs(highWeights) do
				cum2 += w
				if rRoll <= cum2 then
					pickedRarity = highRarities[ri]
					break
				end
			end
			local unitType = rollUnit(pickedRarity)
			local oneIn = getBaseOneIn(unitType)
			table.insert(boxUnits, { unitType = unitType, oneIn = oneIn })
			if not PlayerData.addUnit(player, unitType, oneIn) then
				Remotes.Notice:FireClient(player, "⚠️ Inventory full — " .. unitType .. " lost!")
			end
		end
		rewardData.boxUnits = boxUnits
	end

	-- Tell client the authoritative outcome index + reward payload
	Remotes.WheelResult:FireClient(player, rewardData)
	-- Send updated spin count
	local now = tick()
	local secondsUntilNext = math.max(0, math.floor(900 - (now - wd.lastGrantTime)))
	Remotes.WheelSpinsUpdate:FireClient(player, wd.spins, secondsUntilNext)
	print("🎡 " .. player.Name .. " spun wheel → " .. outcome.label)
end)

-- Sends the spin count once the player's character exists.
local function onPlayerAdded(player)
	local wd = getWheelData(player)
	player.CharacterAdded:Connect(function()
		task.wait(1)
		local secsLeft = math.max(0, math.floor(900 - (tick() - wd.lastGrantTime)))
		Remotes.WheelSpinsUpdate:FireClient(player, wd.spins, secsLeft)
	end)
end

-- Grants a free spin every 15 minutes of playtime; call periodically.
local function grantTick(p, now)
	local wd = getWheelData(p)
	if now - wd.lastGrantTime >= 900 then
		wd.lastGrantTime = wd.lastGrantTime + 900
		wd.spins += 1
		local secondsUntilNext = math.max(0, math.floor(900 - (now - wd.lastGrantTime)))
		Remotes.WheelSpinsUpdate:FireClient(p, wd.spins, secondsUntilNext)
	end
end

local function remove(player)
	playerWheelData[tostring(player.UserId)] = nil
end

-- Spins are the only wheel state that is stored between sessions.
local function setSpins(player, spins)
	getWheelData(player).spins = math.max(0, math.floor(spins))
end

return {
	getWheelData = getWheelData,
	onPlayerAdded = onPlayerAdded,
	grantTick = grantTick,
	remove = remove,
	setSpins = setSpins,
}
