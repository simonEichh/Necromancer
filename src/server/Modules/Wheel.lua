-- Lucky wheel: spin grants, outcomes and rewards.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(script.Parent.Remotes)
local PlayerData = require(script.Parent.PlayerData)
local WHEEL_OUTCOMES = require(ReplicatedStorage.Shared.WheelRewards)
local WheelPrizes = require(ReplicatedStorage.Shared.WheelPrizes)
local SPIN_TIME = 5
local busyUntil = 0
local POTION_DURATION = WHEEL_OUTCOMES[2].duration

-- ── WHEEL DATA ───────────────────────────────────────────────
local playerWheelData = {}
local function getWheelData(player)
	local id = tostring(player.UserId)
	if not playerWheelData[id] then
		playerWheelData[id] = {
			spins = 0,
			lastGrantTime = tick(),
			lastPotionUse = 0,
		}
	end
	return playerWheelData[id]
end

Remotes.UseLuckPotion.OnServerEvent:Connect(function(player)
	if not PlayerData.get(player) then return end
	local wd = getWheelData(player)
	local now = os.clock()
	if now - wd.lastPotionUse < 0.5 then return end
	wd.lastPotionUse = now
	if not PlayerData.useLuckPotion(player, POTION_DURATION) then
		Remotes.Notice:FireClient(player, "You have no luck potions. Win them from the Lucky Wheel.")
	end
end)

-- Wheel outcomes (7 segments matching the client display order)
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
		Remotes.WheelRejected:FireClient(player, "No spins available yet.")
		return
	end
	local wheel = workspace:FindFirstChild("LuckyWheel")
	if not wheel or not wheel:FindFirstChild("Rotor") then
		Remotes.WheelRejected:FireClient(player, "The plaza wheel is not available.")
		return
	end
	local at = workspace:GetServerTimeNow()
	if at < busyUntil then
		Remotes.WheelRejected:FireClient(player, "The wheel is spinning. Try again in a moment.")
		return
	end
	busyUntil = at + SPIN_TIME
	wd.spins -= 1
	profile.dirty = true

	-- The server rolls the outcome; the client only animates toward the index we send.
	local idx, outcome = rollWheelOutcome()
	local from = wheel:GetAttribute("SpinTo") or 0
	local landing = outcome.centerAngle
	local to = from + 6 * 2 * math.pi + (landing - from % (2 * math.pi)) % (2 * math.pi)
	wheel:SetAttribute("SpinFrom", from)
	wheel:SetAttribute("SpinTo", to)
	wheel:SetAttribute("SpinDuration", SPIN_TIME)
	wheel:SetAttribute("SpinWinner", idx)
	wheel:SetAttribute("SpinOwner", player.UserId)
	wheel:SetAttribute("SpinAt", at) -- last: clients see one consistent animation snapshot

	-- Resolve once at spin time, so the preview and award use the same progression rules.
	local prize = WheelPrizes.resolve(outcome, profile.rebirthCount, WheelPrizes.armyIncome(PlayerData.placedProvider and PlayerData.placedProvider(player) or {},
		profile.rebirthCount, profile.upgrades.coinBoost, profile.realmUpgrades.harvest), profile.items.SpectralCrown == true)
	local rewardData = { outcomeIdx = idx, prize = prize, spinAt = at, spinDuration = SPIN_TIME }
	if prize.gold then
		PlayerData.addGold(player, prize.gold)
	elseif prize.gems then
		PlayerData.addGems(player, prize.gems)
	elseif prize.graveType then
		PlayerData.addGraves(player, prize.graveType, prize.count)
	elseif prize.dust then
		PlayerData.addMaterial(player, prize.dust, prize.count)
	elseif prize.catalyst then
		PlayerData.addCatalyst(player, prize.catalyst, prize.count)
	elseif prize.itemKey then
		PlayerData.grantItem(player, prize.itemKey)
	else
		PlayerData.addLuckPotions(player, prize.count)
	end

	-- Tell client the authoritative outcome index + reward payload
	Remotes.WheelResult:FireClient(player, rewardData)
	-- Send updated spin count
	local now = tick()
	local secondsUntilNext = math.max(0, math.floor(900 - (now - wd.lastGrantTime)))
	Remotes.WheelSpinsUpdate:FireClient(player, wd.spins, secondsUntilNext)
	print("🎡 " .. player.Name .. " spun wheel → " .. outcome.label)
end)

-- The model lives in the Studio place. The prompt and the HUD tile use the same wheel view.
local wheel = workspace:FindFirstChild("LuckyWheel")
local prompt = wheel and wheel:FindFirstChild("WheelPrompt", true)
if prompt then
	prompt.Triggered:Connect(function(player)
		local wd = getWheelData(player)
		local secondsUntilNext = math.max(0, math.floor(900 - (tick() - wd.lastGrantTime)))
		Remotes.WheelSpinsUpdate:FireClient(player, wd.spins, secondsUntilNext)
		Remotes.OpenWheel:FireClient(player)
	end)
end

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
		local profile = PlayerData.get(p)
		if profile then profile.dirty = true end
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
