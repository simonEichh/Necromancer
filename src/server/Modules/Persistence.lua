-- Loads and saves player data with DataStore.
-- If loading fails the player gets default data but is never saved over their stored data.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local Remotes = require(script.Parent.Remotes)
local PlayerData = require(script.Parent.PlayerData)
local Quests = require(script.Parent.Quests)
local Wheel = require(script.Parent.Wheel)
local Rolling = require(script.Parent.Rolling)
local Army = require(script.Parent.Army)
local PlotRegistry = require(script.Parent.PlotRegistry)
local Economy = require(game:GetService("ReplicatedStorage").Shared.Economy)
local Units = require(game:GetService("ReplicatedStorage").Shared.Units)

local STORE_NAME = "PlayerData_v1"
local SAVE_VERSION = 1
local AUTOSAVE_INTERVAL = 60
local ATTEMPTS = 3

local store = DataStoreService:GetDataStore(STORE_NAME)
local saving = {} -- [UserId] = true while a save is in flight

local function keyFor(player)
	return "player_" .. player.UserId
end

-- Runs fn (which may error) up to ATTEMPTS times. Returns ok, result.
local function withRetry(label, fn)
	local lastErr
	for attempt = 1, ATTEMPTS do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		lastErr = result
		warn(("DataStore %s failed (attempt %d/%d): %s"):format(label, attempt, ATTEMPTS, tostring(result)))
		if attempt < ATTEMPTS then
			task.wait(attempt)
		end
	end
	return false, lastErr
end

-- Everything that is stored for a player, as plain tables/numbers/strings.
local function collect(player, profile)
	local placed = {}
	local plotState = PlotRegistry.getPlot(player)
	if plotState then
		for _, entry in ipairs(Army.placedList(plotState)) do
			table.insert(placed, entry)
		end
	end
	local snapshot = PlayerData.snapshot(profile)
	return {
		version = SAVE_VERSION,
		gold = profile.gold,
		gems = profile.gems,
		luckPotions = profile.luckPotions,
		luckBuffRemaining = math.max(0, profile.luckBuffEnd - workspace:GetServerTimeNow()),
		rebirthCount = profile.rebirthCount,
		ownedGraves = snapshot.ownedGraves,
		upgrades = { luckBoost = profile.upgrades.luckBoost, coinBoost = profile.upgrades.coinBoost },
		realmUpgrades = table.clone(profile.realmUpgrades),
		codex = table.clone(profile.codex),
		items = snapshot.items,
		equipped = snapshot.equipped,
		inventory = snapshot.inventory,
		materials = snapshot.materials,
		catalysts = snapshot.catalysts,
		wallsBroken = profile.wallsBroken,
		collector = profile.collector,
		wispLevel = profile.wispLevel,
		remoteForge = profile.remoteForge,
		fleetStrike = profile.fleetStrike,
		finalHorizon = profile.finalHorizon,
		commanderSlots = profile.commanderSlots,
		broker = profile.broker,
		settings = profile.settings,
		placed = placed,
		pity = Rolling.exportPity(player),
		wheelSpins = Wheel.getWheelData(player).spins,
		quests = Quests.getSaveData(player),
	}
end

-- Units that were replaced or renamed (Units.RENAMED, e.g. the Goblin became the Hollow Archer): rewrites the old keys
-- in a loaded save (inventory, units on graves, the Codex) before PlayerData reads it.
local function migrateUnitNames(saved)
	if type(saved) ~= "table" then
		return
	end
	for _, listName in ipairs({ "inventory", "placed" }) do
		local list = saved[listName]
		if type(list) == "table" then
			for _, entry in pairs(list) do
				if type(entry) == "table" and Units.RENAMED[entry.unitType] then
					entry.unitType = Units.RENAMED[entry.unitType]
				end
			end
		end
	end
	if type(saved.codex) == "table" then
		for oldKey, newKey in pairs(Units.RENAMED) do
			if type(saved.codex[oldKey]) == "number" then
				saved.codex[newKey] = (tonumber(saved.codex[newKey]) or 0) + saved.codex[oldKey]
				saved.codex[oldKey] = nil
			end
		end
	end
end

local Persistence = {}

-- Creates the player's authoritative data (from DataStore when possible) and restores per-system state.
-- Yields while talking to DataStore.
function Persistence.load(player)
	local ok, saved = withRetry("load", function()
		return store:GetAsync(keyFor(player))
	end)
	if not player.Parent then
		return nil
	end

	if ok then
		migrateUnitNames(saved)
	end
	local profile = PlayerData.create(player, ok and saved or nil)
	if not ok then
		profile.loadFailed = true
		warn("Could not load data for " .. player.Name .. "; their progress will not be saved this session.")
		task.delay(6, function()
			if player.Parent then
				Remotes.Notice:FireClient(player, "Your saved data couldn't be loaded. Progress won't be saved this session.")
			end
		end)
	end

	local data = profile.saved
	Quests.init(player, data and data.quests)
	if data then
		Rolling.importPity(player, data.pity)
		if type(data.wheelSpins) == "number" then
			Wheel.setSpins(player, data.wheelSpins)
		end
	end
	return profile
end

-- Re-deploys the units that were on graves when the player last left. Call after the plot exists.
function Persistence.restorePlaced(player)
	local profile = PlayerData.get(player)
	local plotState = PlotRegistry.getPlot(player)
	local placed = profile and profile.saved and profile.saved.placed
	if not plotState or type(placed) ~= "table" then
		return
	end
	for _, entry in ipairs(placed) do
		if type(entry) == "table" and type(entry.slot) == "number" then
			local level = math.clamp(math.floor(tonumber(entry.level) or 0), 0, Economy.MAX_UNIT_LEVEL)
			local fails = math.max(0, math.floor(tonumber(entry.fails) or 0))
			if not Army.placeInSlot(plotState, entry.slot, entry.unitType, level, fails, entry.locked == true) then
				-- (no such slot any more, or a commander on a grave / a normal unit on a throne: back to the inventory)
				if Units.Stats[entry.unitType] then
					PlayerData.addUnit(player, entry.unitType, Units.getBaseOneIn(entry.unitType), level, fails, entry.locked == true)
				end
			end
		end
	end
end

-- Saves one player. Yields. Safe to call repeatedly; overlapping saves for a player are skipped.
function Persistence.save(player)
	local profile = PlayerData.get(player)
	if not profile or profile.loadFailed or saving[player.UserId] then
		return false
	end
	saving[player.UserId] = true
	local data = collect(player, profile) -- gathered now, before any yielding
	local ok = withRetry("save", function()
		store:UpdateAsync(keyFor(player), function()
			return data
		end)
	end)
	saving[player.UserId] = nil
	if ok then
		profile.dirty = false
		print("💾 saved data for " .. player.Name)
	end
	return ok
end

-- Periodically saves everyone.
function Persistence.startAutosave()
	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_INTERVAL)
			for _, player in ipairs(Players:GetPlayers()) do
				task.spawn(Persistence.save, player)
			end
		end
	end)
end

-- Saves everyone when the server shuts down (waits for the saves, up to a time limit).
function Persistence.bindToClose()
	game:BindToClose(function()
		local pending = 0
		for _, player in ipairs(Players:GetPlayers()) do
			pending += 1
			task.spawn(function()
				Persistence.save(player)
				pending -= 1
			end)
		end
		local deadline = os.clock() + 25
		while pending > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)
end

return Persistence
