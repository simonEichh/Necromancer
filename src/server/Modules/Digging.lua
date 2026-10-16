-- DigGrave handler: uses up owned graves, rolls units, stores them in the inventory
-- and sends the results to the client for the reveal animation.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(script.Parent.Remotes)
local PlayerData = require(script.Parent.PlayerData)
local Rolling = require(script.Parent.Rolling)
local Quests = require(script.Parent.Quests)
local ShowcasePulls = require(script.Parent.ShowcasePulls)
local Graves = require(ReplicatedStorage.Shared.Graves)
local Units = require(ReplicatedStorage.Shared.Units)

local rollRarity = Rolling.rollRarity
local rollUnit = Rolling.rollUnit
local getPity = Rolling.getPity
local getBaseOneIn = Units.getBaseOneIn
local incrementQuest = Quests.increment

local MAX_PULLS = 10 -- most graves opened in one request
local Players = game:GetService("Players")

-- a Sovereign pulled, waiting for the puller's client to start its arrival cinematic: [player] = { unitType, ... }
local pendingArrivals = {}
local ARRIVAL_WAIT = 120 -- s (the roll animation plays first)
local ARRIVAL_REACH = 60 -- studs: the grave must stand near the puller

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

	-- Luck potions double the Rare-and-better weight boost while active.
	local buffMult = (workspace:GetServerTimeNow() < profile.luckBuffEnd) and 2 or 1
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
		local unitType = rollUnit(rarity, graveType)
		local oneIn = getBaseOneIn(unitType)
		PlayerData.addUnit(player, unitType, oneIn)
		PlayerData.recordPull(player, unitType) -- (the Codex)
		ShowcasePulls.record(player, unitType) -- (the Reliquary's "Pulled by")
		if Units.isSovereign(unitType) then
			-- (the puller's client reports where its arrival cinematic plays: ArrivalStarted below)
			pendingArrivals[player] = { unitType = unitType, rarity = rarity, graveType = graveType, at = os.clock() }
		end
		if Units.isSignature(unitType) or Units.isSovereign(unitType) then
			-- every player sees a banner (the puller has the cinematic instead)
			Remotes.RarePull:FireAllClients({ userId = player.UserId, name = player.DisplayName, unitType = unitType, oneIn = oneIn })
		end

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

-- ArrivalStarted({ G, dir, feet }): the puller's Sovereign arrival cinematic started; every other player gets it in their
-- world (client SovereignArrival, spectate), on one shared clock. Only once per Sovereign pulled, near the puller.
Remotes.ArrivalStarted.OnServerEvent:Connect(function(player, data)
	local pending = pendingArrivals[player]
	pendingArrivals[player] = nil
	if not pending or os.clock() - pending.at > ARRIVAL_WAIT or type(data) ~= "table" then
		return
	end
	local G, dir, feet = data.G, data.dir, data.feet
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if typeof(G) ~= "Vector3" or typeof(dir) ~= "Vector3" or typeof(feet) ~= "Vector3" or not hrp
		or (G - hrp.Position).Magnitude > ARRIVAL_REACH or (feet - hrp.Position).Magnitude > ARRIVAL_REACH then
		return
	end
	local flat = Vector3.new(dir.X, 0, dir.Z)
	if flat.Magnitude < 0.1 then
		return
	end
	local show = {
		owner = player.UserId, unitType = pending.unitType, rarity = pending.rarity, graveType = pending.graveType,
		G = G, dir = flat.Unit, feet = feet, startAt = workspace:GetServerTimeNow(),
	}
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= player then
			Remotes.ArrivalShow:FireClient(other, show)
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	pendingArrivals[player] = nil
end)

return {}
