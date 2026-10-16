-- Run with execute_luau in Edit or Server. Executes the synced sources with isolated profiles,
-- remotes, clock and DataStore; never changes a player's live data or stored save.
local shared = game.ReplicatedStorage.Shared
local modules = game.ServerScriptService.Server.Modules
local now, ticket, checks, lastLuck = 10000, 1, 0, nil
local function check(value, message)
	assert(value, message)
	checks += 1
end
local remotes = setmetatable({}, { __index = function(t, key)
	local remote = { calls = {}, handlers = {} }
	remote.OnServerEvent = { Connect = function(_, fn) table.insert(remote.handlers, fn) end }
	function remote:FireClient(player, ...)
		table.insert(self.calls, { player = player, args = { ... } })
	end
	function remote:send(player, ...)
		for _, fn in ipairs(self.handlers) do fn(player, ...) end
	end
	t[key] = remote
	return remote
end })
local wheelModel = Instance.new("Model")
wheelModel.Name = "WheelTest"
Instance.new("Model", wheelModel).Name = "Rotor"
local clockWorld = {
	GetServerTimeNow = function() return now end,
	FindFirstChild = function(_, name) return name == "LuckyWheel" and wheelModel or nil end,
}
local savedByKey = {}
local store = {
	UpdateAsync = function(_, key, callback) savedByKey[key] = callback(savedByKey[key]) end,
	GetAsync = function(_, key) return savedByKey[key] end,
}
local mockGame = { GetService = function(_, name)
	if name == "DataStoreService" then return { GetDataStore = function() return store end } end
	if name == "Players" then return { PlayerRemoving = { Connect = function() end } } end
	return game:GetService(name)
end }
local mocks = {
	[modules.Remotes] = remotes,
	[modules.Quests] = { getSaveData = function() return {} end, init = function() end, increment = function() end },
	[modules.Rolling] = {
		exportPity = function() return {} end, importPity = function() end, getPity = function() return 0 end,
		rollRarity = function(grave) lastLuck = grave.luckFactor return "Common" end,
		rollUnit = function() return "Skelly" end,
	},
	[modules.ShowcasePulls] = { record = function() end },
	[modules.Army] = {},
	[modules.PlotRegistry] = { getPlot = function() return nil end },
}
local loaded = {}
local function loadModule(node)
	if mocks[node] then return mocks[node] end
	if loaded[node] then return loaded[node] end
	local fn = assert(loadstring(node.Source, node:GetFullName()))
	local env = setmetatable({ script = node, require = loadModule, workspace = clockWorld,
		game = mockGame, tick = function() return now end, print = function() end }, { __index = getfenv() })
	if node == modules.Wheel then
		env.math = table.clone(math)
		env.math.random = function() return ticket end
		env.os = table.clone(os)
		env.os.clock = function() return now end
	end
	setfenv(fn, env)
	local value = fn()
	loaded[node] = value
	return value
end
local PlayerData = loadModule(modules.PlayerData)
local Wheel = loadModule(modules.Wheel)
local Prizes = loadModule(shared.WheelPrizes)
local Rewards = loadModule(shared.WheelRewards)
local Graves = loadModule(shared.Graves)
local Economy = loadModule(shared.Economy)
local Persistence = loadModule(modules.Persistence)
loadModule(modules.Digging)
local nextId = -50000
local function playerAt(ascension, saved)
	nextId -= 1
	local player = { UserId = nextId, Name = "WheelTest", Parent = true }
	local profile = PlayerData.create(player, saved)
	profile.rebirthCount = ascension
	return player, profile
end
local function spin(player, roll)
	now += 6
	ticket = roll
	Wheel.setSpins(player, 2)
	local before = #remotes.WheelResult.calls
	remotes.WheelSpin:send(player)
	check(#remotes.WheelResult.calls == before + 1, "spin did not produce a result")
	check(Wheel.getWheelData(player).spins == 1, "accepted spin must consume exactly one spin")
	return remotes.WheelResult.calls[#remotes.WheelResult.calls].args[1]
end

local total, expectedStart = 0, Rewards[1].startAngle
for _, outcome in ipairs(Rewards) do
	check(math.abs(outcome.startAngle - expectedStart) < 1e-8, "wheel arcs have a gap")
	check(math.abs(outcome.arc - 2 * math.pi * outcome.weight / 100) < 1e-8, "arc does not match odds")
	total += outcome.weight
	expectedStart = outcome.endAngle
end
check(total == 100, "odds must sum to 100")
check(math.abs(expectedStart - Rewards[1].startAngle - 2 * math.pi) < 1e-8, "wheel must cover a circle")

for ascension = 0, 12 do
	local expectedGrave, expectedDust = "Mossy", "Stone"
	for key, grave in pairs(Graves) do
		if grave.unlockAscension <= ascension and grave.unlockAscension > Graves[expectedGrave].unlockAscension then
			expectedGrave = key
		end
	end
	for i, dust in ipairs(Economy.DUSTS) do
		if Economy.dustShopUnlock(i) <= ascension then expectedDust = dust end
	end
	local cumulative = 0
	for i, outcome in ipairs(Rewards) do
		for _, roll in ipairs({ cumulative + 1, cumulative + outcome.weight }) do
			local player, profile = playerAt(ascension)
			profile.upgrades.coinBoost = ascension % 3
			local result = spin(player, roll)
			check(result.outcomeIdx == i, "weighted boundary picked wrong reward")
			local prize = result.prize
			if prize.gold then
				-- no army in the isolated plot: the chest pays its minimum (10 minutes of hit income otherwise)
				local amount = 300
				check(prize.gold == amount and profile.gold == 300 + amount, "gold chest award mismatch")
			elseif prize.gems then
				check(profile.gems == 75, "gem award mismatch")
			elseif prize.graveType then
				check(prize.graveType == expectedGrave and profile.ownedGraves[expectedGrave] == 5, "grave hoard must use unlocked tier")
			elseif prize.dust then
				check(prize.dust == expectedDust and profile.materials[expectedDust] == 12, "dust must use unlocked tier")
			elseif prize.catalyst then
				check(profile.catalysts.Fortune == 3, "Fortune bundle mismatch")
			elseif prize.itemKey then
				check(profile.items.SpectralCrown == true, "crown was not unlocked")
				check(not PlayerData.equipItem(player, "Head", "SpectralCrown"), "unmodelled crown must not equip")
				local duplicate = spin(player, 100)
				check(duplicate.prize.duplicate and profile.gems == 250, "repeat crown must give 250 gems")
			else
				check(profile.luckPotions == 1 and profile.luckBuffEnd == 0, "potion must be stored, not activated")
			end
			check(#Prizes.describe(prize) > 0, "reward description is empty")
			local delta = wheelModel:GetAttribute("SpinTo") - Rewards[wheelModel:GetAttribute("SpinWinner")].centerAngle
			check(math.abs(math.atan2(math.sin(delta), math.cos(delta))) < 1e-7, "pointer landing mismatch")
		end
		cumulative += outcome.weight
	end
end

local player, profile = playerAt(4)
PlayerData.addLuckPotions(player, 2)
remotes.UseLuckPotion:send(player, 999999) -- extra arguments cannot set duration
check(profile.luckPotions == 1 and profile.luckBuffEnd == now + 300, "potion duration must be server-owned")
remotes.UseLuckPotion:send(player)
check(profile.luckPotions == 1, "rapid duplicate use should be throttled")
now += 1
remotes.UseLuckPotion:send(player)
check(profile.luckPotions == 0 and profile.luckBuffEnd == now + 599, "potion time must stack, not strength")
now += 1
local oldEnd = profile.luckBuffEnd
remotes.UseLuckPotion:send(player)
check(profile.luckPotions == 0 and profile.luckBuffEnd == oldEnd, "empty potion request changed the buff")

PlayerData.addLuckPotions(player, 3)
PlayerData.grantItem(player, "SpectralCrown")
Wheel.setSpins(player, 7)
check(Persistence.save(player), "isolated save failed")
local saved = savedByKey["player_" .. player.UserId]
check(saved.luckPotions == 3 and saved.wheelSpins == 7, "consumables/spins not saved")
check(math.abs(saved.luckBuffRemaining - (oldEnd - now)) < 0.01, "remaining luck not saved")
check(table.find(saved.items, "SpectralCrown") ~= nil, "crown ownership not saved")
now += 86400
local rejoined = Persistence.load(player)
check(rejoined.luckPotions == 3 and rejoined.items.SpectralCrown, "saved rewards not restored")
check(math.abs(rejoined.luckBuffEnd - now - saved.luckBuffRemaining) < 0.01, "offline time consumed luck")
check(Wheel.getWheelData(player).spins == 7, "saved spins not restored")
local snap = PlayerData.snapshot(rejoined)
check(snap.luckPotions == 3 and snap.luckBuffEnd == rejoined.luckBuffEnd, "potion snapshot mismatch")
rejoined.upgrades.luckBoost = 2
PlayerData.addGraves(player, "Mossy", 2)
remotes.DigGrave:send(player, "Mossy", 1)
check(math.abs(lastLuck - 2.4) < 1e-8, "active potion did not double grave luck")
now = rejoined.luckBuffEnd + 1
remotes.DigGrave:send(player, "Mossy", 1)
check(math.abs(lastLuck - 1.2) < 1e-8, "expired potion still changed grave luck")

local legacy, legacyProfile = playerAt(0, { gold = 123 })
check(legacyProfile.luckPotions == 0 and legacyProfile.luckBuffEnd == now, "old saves need safe potion defaults")
local _, malformed = playerAt(0, { luckPotions = 0/0, luckBuffRemaining = "bad" })
check(malformed.luckPotions == 0 and malformed.luckBuffEnd == now, "invalid potion save was accepted")
Wheel.setSpins(legacy, 0)
local results = #remotes.WheelResult.calls
remotes.WheelSpin:send(legacy)
check(#remotes.WheelResult.calls == results, "empty spin awarded a reward")
local other = playerAt(0)
spin(legacy, 1)
Wheel.setSpins(other, 1)
remotes.WheelSpin:send(other)
check(Wheel.getWheelData(other).spins == 1, "busy rejection consumed another player's spin")
local wd = Wheel.getWheelData(other)
Wheel.grantTick(other, wd.lastGrantTime + 900)
check(wd.spins == 2, "free spin grant broken")
wheelModel:Destroy()
return { checks = checks, result = "PASS", note = "All profiles, remotes and DataStore writes were isolated." }
