-- Daily/weekly quests.
local Players = game:GetService("Players")
local Remotes = require(script.Parent.Remotes)
local PlayerData = require(script.Parent.PlayerData)

local DAILY_QUESTS = {
	{ id = "d_graves",   label = "Open 50 Graves",      type = "openGraves", target = 50,      reward = 15 },
	{ id = "d_playtime", label = "Play for 30 Minutes", type = "playtime",   target = 1800,    reward = 20 },
	{ id = "d_walls",    label = "Break 3 Walls",       type = "breakWalls", target = 3,       reward = 25 },
}
local WEEKLY_QUESTS = {
	{ id = "w_graves",   label = "Open 300 Graves",     type = "openGraves", target = 300,     reward = 75  },
	{ id = "w_playtime", label = "Play for 3 Hours",    type = "playtime",   target = 10800,   reward = 100 },
	{ id = "w_gold",     label = "Earn 1,000,000 Gold", type = "earnGold",   target = 1000000, reward = 125 },
}

local playerQuestData = {}

local function getDayKey()  return math.floor(os.time() / 86400)   end
local function getWeekKey() return math.floor(os.time() / 604800)  end

-- Creates fresh quest data, restoring progress from `saved` (stored quest data) if given.
local function initQuestData(player, saved)
	local id = tostring(player.UserId)
	local data = {
		daily   = { progress = {}, claimed = {}, dayKey  = getDayKey()  },
		weekly  = { progress = {}, claimed = {}, weekKey = getWeekKey() },
		playtimeAccum = 0,
	}
	for _, q in ipairs(DAILY_QUESTS)  do data.daily.progress[q.id] = 0; data.daily.claimed[q.id] = false end
	for _, q in ipairs(WEEKLY_QUESTS) do data.weekly.progress[q.id] = 0; data.weekly.claimed[q.id] = false end

	if type(saved) == "table" then
		local function restore(section, list, src, keyName)
			if type(src) ~= "table" then return end
			if type(src[keyName]) == "number" then section[keyName] = src[keyName] end
			for _, q in ipairs(list) do
				local progress = type(src.progress) == "table" and src.progress[q.id]
				if type(progress) == "number" then
					section.progress[q.id] = math.clamp(progress, 0, q.target)
				end
				if type(src.claimed) == "table" and src.claimed[q.id] == true then
					section.claimed[q.id] = true
				end
			end
		end
		restore(data.daily, DAILY_QUESTS, saved.daily, "dayKey")
		restore(data.weekly, WEEKLY_QUESTS, saved.weekly, "weekKey")
	end

	playerQuestData[id] = data
end

local function checkQuestReset(player)
	local id = tostring(player.UserId)
	local data = playerQuestData[id]
	if not data then return end
	if data.daily.dayKey ~= getDayKey() then
		data.daily.dayKey = getDayKey()
		for _, q in ipairs(DAILY_QUESTS) do
			data.daily.progress[q.id] = 0
			data.daily.claimed[q.id]  = false
		end
	end
	if data.weekly.weekKey ~= getWeekKey() then
		data.weekly.weekKey = getWeekKey()
		for _, q in ipairs(WEEKLY_QUESTS) do
			data.weekly.progress[q.id] = 0
			data.weekly.claimed[q.id]  = false
		end
	end
end

local function sendQuestUpdate(player)
	local id   = tostring(player.UserId)
	local data = playerQuestData[id]
	if not data then return end
	local now = os.time()
	Remotes.QuestUpdate:FireClient(player,
		data.daily.progress,  data.daily.claimed,
		data.weekly.progress, data.weekly.claimed,
		86400  - (now % 86400),
		604800 - (now % 604800)
	)
end

local function incrementQuest(player, questType, amount)
	local id   = tostring(player.UserId)
	local data = playerQuestData[id]
	if not data then return end
	local changed = false
	for _, q in ipairs(DAILY_QUESTS) do
		if q.type == questType and not data.daily.claimed[q.id] then
			local prev = data.daily.progress[q.id] or 0
			if prev < q.target then
				data.daily.progress[q.id] = math.min(prev + amount, q.target)
				changed = true
			end
		end
	end
	for _, q in ipairs(WEEKLY_QUESTS) do
		if q.type == questType and not data.weekly.claimed[q.id] then
			local prev = data.weekly.progress[q.id] or 0
			if prev < q.target then
				data.weekly.progress[q.id] = math.min(prev + amount, q.target)
				changed = true
			end
		end
	end
	if changed then sendQuestUpdate(player) end
end

Remotes.ClaimQuest.OnServerEvent:Connect(function(player, questId, isWeekly)
	local id   = tostring(player.UserId)
	local data = playerQuestData[id]
	if not data then return end
	local questList = isWeekly and WEEKLY_QUESTS or DAILY_QUESTS
	local qd        = isWeekly and data.weekly   or data.daily
	for _, q in ipairs(questList) do
		if q.id == questId then
			if qd.claimed[questId] then return end
			if (qd.progress[questId] or 0) < q.target then return end
			qd.claimed[questId] = true
			PlayerData.addGems(player, q.reward)
			sendQuestUpdate(player)
			return
		end
	end
end)

-- Adds elapsed play time to the playtime quests; call every frame with dt.
local function tickPlaytime(dt)
	for _, p in ipairs(Players:GetPlayers()) do
		local qd = playerQuestData[tostring(p.UserId)]
		if qd then
			qd.playtimeAccum = (qd.playtimeAccum or 0) + dt
			if qd.playtimeAccum >= 30 then
				local secs = math.floor(qd.playtimeAccum)
				qd.playtimeAccum = qd.playtimeAccum - secs
				incrementQuest(p, "playtime", secs)
			end
		end
	end
end

local function remove(player)
	playerQuestData[tostring(player.UserId)] = nil
end

-- Quest data in a form that can be stored (nil if the player has none).
local function getSaveData(player)
	local data = playerQuestData[tostring(player.UserId)]
	if not data then return nil end
	return { daily = data.daily, weekly = data.weekly }
end

return {
	init = initQuestData,
	checkReset = checkQuestReset,
	sendUpdate = sendQuestUpdate,
	increment = incrementQuest,
	tickPlaytime = tickPlaytime,
	remove = remove,
	getSaveData = getSaveData,
}
