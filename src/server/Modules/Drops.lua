-- Loot drops: a broken wall no longer pays out directly, it bursts into gold coins and dust crystals that lie on the lane
-- until they are collected. Server authoritative: the drops are real parts the server creates (in Workspace.Drops), the
-- server decides when one is collected and pays it through PlayerData. The client (Modules/Pickups) only animates them:
-- the burst out of the wall, the bob and spin, and the flight to whoever collected them (attribute `Collected`).
--
-- Collecting:
--   * walking close to a drop (MAGNET_RADIUS around the character)
--   * the Soul Wisp (profile.collector, earned by breaking COLLECTOR_WALLS walls): a server-moved wisp that flies along the
--     owner's lane, picks up one drop after another and then hovers behind the army
--   * overflow: with more than MAX_DROPS on a lane the oldest one is collected automatically at OVERFLOW_SHARE of its value,
--     so an idle player still earns something
-- Ascending clears the lane: dust is paid in full, gold is dropped (ascending resets gold anyway).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Remotes = require(script.Parent.Remotes)
local PlayerData = require(script.Parent.PlayerData)
local PlotFrame = require(script.Parent.PlotFrame)
local PlotRegistry = require(script.Parent.PlotRegistry)
local Economy = require(game:GetService("ReplicatedStorage").Shared.Economy)

local Drops = {}

Drops.COLLECTOR_WALLS = 2 -- walls to break for the Soul Wisp
local MAGNET_RADIUS = 7
local MAX_DROPS = 80
local OVERFLOW_SHARE = 0.5
local WISP_SWEEP = 3 -- the wisp also picks up every drop this close to the one it grabs (coins land in clusters)
local WISP_SPEED = 14 -- studs per second (slow at first; meant to become a gold upgrade later)
local WISP_PAUSE = 0.5 -- seconds it lingers after each pick-up
local WISP_HEIGHT = 5
local COLLECT_REMOVE_DELAY = 0.6 -- the part stays this long after being collected, so clients can fly it away
local LANE_HALF = 15 -- drops scatter this far across the lane

local GOLD_COLOR = Color3.fromRGB(255, 200, 70)
local DUST_COLOR = {
	Stone = Color3.fromRGB(150, 146, 140),
	Silver = Color3.fromRGB(196, 204, 216),
	Gold = Color3.fromRGB(232, 190, 90),
	Diamond = Color3.fromRGB(130, 220, 240),
	Star = Color3.fromRGB(226, 150, 255),
}

local root = Instance.new("Folder")
root.Name = "Drops"
root.Parent = workspace

local byOwner = {} -- [userId] = { folder, plotState, list = { drop }, wisp = Part?, wispTarget = drop? }
local nextId = 0

-- the army's income for the HUD's "+X/s": gold of every coin dropped (walls and hits) over the last RATE_WINDOW
-- seconds, set as the player attribute `GoldRate` once per second
local RATE_WINDOW = 30
local function noteEarned(s, gold)
	table.insert(s.earned, { t = os.clock(), gold = gold })
end

local function stateFor(player, plotState)
	local s = byOwner[player.UserId]
	if not s then
		local folder = Instance.new("Folder")
		folder.Name = "Drops_" .. player.UserId
		folder.Parent = root
		s = { folder = folder, list = {}, phase = math.random() * 100, earned = {}, startedAt = os.clock() }
		byOwner[player.UserId] = s
	end
	s.plotState = plotState or s.plotState
	return s
end

-- ============================================================
-- Paying out
-- ============================================================
local function pay(player, drop, share)
	local amount = math.floor(drop.amount * (share or 1))
	if amount <= 0 then return end
	if drop.kind == "Gold" then
		PlayerData.addGold(player, amount)
	else
		PlayerData.addMaterial(player, drop.kind, amount)
	end
end

-- removes the drop from the lane and pays it; `by` is "player", "wisp" or "overflow" (the client animates accordingly)
local function collect(player, s, index, by, share)
	local drop = table.remove(s.list, index)
	if not drop then return end
	pay(player, drop, share)
	if drop.part and drop.part.Parent then
		drop.part:SetAttribute("Collected", by)
		local part = drop.part
		task.delay(COLLECT_REMOVE_DELAY, function()
			if part.Parent then part:Destroy() end
		end)
	end
	if s.wispTarget == drop then
		s.wispTarget = nil
	end
end

-- ============================================================
-- Spawning
-- ============================================================
local function makePart(s, kind, pos, from)
	local p = Instance.new("Part")
	p.Name = kind == "Gold" and "Coin" or "Dust"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	if kind == "Gold" then
		p.Shape = Enum.PartType.Cylinder
		p.Size = Vector3.new(0.3, 1.3, 1.3)
		p.Color = GOLD_COLOR
	else
		p.Size = Vector3.new(0.8, 0.8, 0.8)
		p.Color = DUST_COLOR[kind] or Color3.new(1, 1, 1)
	end
	p.CFrame = CFrame.new(pos)
	p:SetAttribute("Kind", kind)
	p:SetAttribute("From", from) -- where the burst starts (the wall), for the client's arc
	p:SetAttribute("SpawnTime", workspace:GetServerTimeNow())
	p.Parent = s.folder
	return p
end

-- Called by Walls when a wall of `player`'s run breaks: `gold` (already multiplied) and `dusts` ({ dust, amount } list).
-- `faceFwd` is where the broken wall's face stood along the lane.
function Drops.spawnWallDrops(player, plotState, gold, dusts, faceFwd)
	local s = stateFor(player, plotState)
	local floorY = plotState.frame.Position.Y
	local from = PlotFrame.toWorld(plotState, 0, faceFwd + 1.5) + Vector3.new(0, 6, 0)
	local function scatter()
		local lateral = (math.random() * 2 - 1) * LANE_HALF
		local forward = faceFwd - 3 - math.random() * 12
		local p = PlotFrame.toWorld(plotState, lateral, forward)
		return Vector3.new(p.X, floorY + 0.9, p.Z)
	end
	local function add(kind, amount)
		nextId += 1
		local pos = scatter()
		local drop = { id = nextId, kind = kind, amount = amount, pos = pos, born = os.clock() }
		drop.part = makePart(s, kind, pos, from)
		table.insert(s.list, drop)
	end
	-- gold: 3 to 6 coins depending on the amount
	gold = math.floor(gold)
	if gold > 0 then
		noteEarned(s, gold)
		local coins = math.clamp(math.floor(math.log10(gold + 1)) + 2, 3, 6)
		local each = math.floor(gold / coins)
		for k = 1, coins do
			add("Gold", (k == coins) and (gold - each * (coins - 1)) or each)
		end
	end
	for _, d in ipairs(dusts) do
		if d.amount > 0 then
			-- one crystal per 5 dust, at most 3 per drop entry
			local crystals = math.clamp(math.ceil(d.amount / 5), 1, 3)
			local each = math.floor(d.amount / crystals)
			for k = 1, crystals do
				add(d.dust, (k == crystals) and (d.amount - each * (crystals - 1)) or each)
			end
		end
	end
	-- overflow: too many drops on the lane, the oldest are collected at a reduced value
	while #s.list > MAX_DROPS do
		collect(player, s, 1, "overflow", OVERFLOW_SHARE)
	end
end

-- Called by Army with the gold one unit earned by hitting the wall (hit income, already multiplied): `count` coins pop
-- out of the wall face at `lateral` (where that unit hits) and land on the lane in front of it. `t` (0..1, the unit's
-- strength) makes the coins bigger, fly higher and land further out.
function Drops.spawnHitCoins(player, plotState, gold, lateral, count, t)
	gold = math.floor(gold)
	if gold <= 0 then return end
	count = math.clamp(math.min(count, gold), 1, 6)
	local s = stateFor(player, plotState)
	noteEarned(s, gold)
	local faceFwd = plotState.wallFaceFwd
	local floorY = plotState.frame.Position.Y
	local from = PlotFrame.toWorld(plotState, lateral, faceFwd + 1.5) + Vector3.new(0, 5, 0)
	local scale = 0.8 + 0.7 * t
	local each = math.floor(gold / count)
	for k = 1, count do
		local spread = 3 + 3 * t
		local landLat = math.clamp(lateral + (math.random() * 2 - 1) * spread, -LANE_HALF, LANE_HALF)
		local p = PlotFrame.toWorld(plotState, landLat, faceFwd - 2 - math.random() * (5 + 6 * t))
		local pos = Vector3.new(p.X, floorY + 0.9, p.Z)
		nextId += 1
		local drop = { id = nextId, kind = "Gold", amount = (k == count) and (gold - each * (count - 1)) or each, pos = pos, born = os.clock() }
		drop.part = makePart(s, "Gold", pos, from)
		drop.part.Size *= scale
		drop.part:SetAttribute("ArcHeight", 4 + 5 * t)
		table.insert(s.list, drop)
	end
	while #s.list > MAX_DROPS do
		collect(player, s, 1, "overflow", OVERFLOW_SHARE)
	end
end

-- Ascending (Walls.resetWall): dust still on the lane is paid, gold is lost (gold resets anyway).
function Drops.clearPlot(plotState)
	for userId, s in pairs(byOwner) do
		if s.plotState == plotState then
			local player = Players:GetPlayerByUserId(userId)
			for _, drop in ipairs(s.list) do
				if player and drop.kind ~= "Gold" then
					pay(player, drop)
				end
				if drop.part then drop.part:Destroy() end
			end
			s.list = {}
			s.wispTarget = nil
		end
	end
end

-- ============================================================
-- The Soul Wisp
-- ============================================================
local function makeWisp(s, pos)
	local w = Instance.new("Part")
	w.Name = "SoulWisp"
	w.Shape = Enum.PartType.Ball
	w.Size = Vector3.new(1.2, 1.2, 1.2)
	w.Color = Color3.fromRGB(170, 255, 220)
	w.Material = Enum.Material.Neon
	w.Anchored = true
	w.CanCollide = false
	w.CanQuery = false
	w.CanTouch = false
	w.CastShadow = false
	w.CFrame = CFrame.new(pos)
	w.Parent = s.folder
	return w
end

local function updateWisp(player, s, dt)
	local profile = PlayerData.get(player)
	if not profile or not profile.collector or not s.plotState then
		return
	end
	local plotState = s.plotState
	-- while idle it drifts around just in front of the wall being fought: slow loops across the lane, a little to and
	-- fro, a gentle bob (it chases this moving point, so it never stands still)
	local t = os.clock() + (s.phase or 0)
	local restFwd = (plotState.wallFaceFwd or 100) - 5 + math.sin(t * 0.9) * 2.5
	local restLat = math.sin(t * 0.45) * 10
	local rest = PlotFrame.toWorld(plotState, restLat, restFwd) + Vector3.new(0, WISP_HEIGHT + 2 + math.sin(t * 1.7) * 1.2, 0)
	if not s.wisp or not s.wisp.Parent then
		s.wisp = makeWisp(s, rest)
	end
	-- pick the next drop: the nearest one
	if not s.wispTarget and #s.list > 0 then
		local best, bestD
		for _, drop in ipairs(s.list) do
			local d = (drop.pos - s.wisp.Position).Magnitude
			if not bestD or d < bestD then
				best, bestD = drop, d
			end
		end
		s.wispTarget = best
	end
	if s.pauseUntil and os.clock() < s.pauseUntil then
		return
	end
	local goal = s.wispTarget and (s.wispTarget.pos + Vector3.new(0, 0.5, 0)) or rest
	local pos = s.wisp.Position
	local delta = goal - pos
	local step = Economy.wispSpeed(profile.wispLevel or 0) * dt -- (Gem Shop levels; WISP_SPEED is level 0)
	if delta.Magnitude <= step then
		pos = goal
		if s.wispTarget then
			for i, drop in ipairs(s.list) do
				if drop == s.wispTarget then
					local at = drop.pos
					collect(player, s, i, "wisp")
					for k = #s.list, 1, -1 do
						if (s.list[k].pos - at).Magnitude <= WISP_SWEEP then
							collect(player, s, k, "wisp")
						end
					end
					s.pauseUntil = os.clock() + Economy.wispPause(profile.wispLevel or 0)
					break
				end
			end
			s.wispTarget = nil
		end
	else
		pos += delta.Unit * step
	end
	s.wisp.CFrame = CFrame.new(pos)
end

-- ============================================================
-- Every frame: magnet pick-ups and the wisp
-- ============================================================
RunService.Heartbeat:Connect(function(dt)
	-- a player who owns the wisp gets it as soon as they have a plot (even before the first drop)
	for _, player in ipairs(Players:GetPlayers()) do
		if not byOwner[player.UserId] then
			local profile = PlayerData.get(player)
			local plotState = profile and profile.collector and PlotRegistry.getPlot(player)
			if plotState then
				stateFor(player, plotState)
			end
		end
	end
	for userId, s in pairs(byOwner) do
		local player = Players:GetPlayerByUserId(userId)
		if player then
			local char = player.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			if hrp then
				-- (realm upgrade Grasping Souls widens the reach)
				local profile = PlayerData.get(player)
				local reach = MAGNET_RADIUS + Economy.realmUpgradeEffect("magnet", profile and profile.realmUpgrades.magnet or 0)
				for i = #s.list, 1, -1 do
					if (s.list[i].pos - hrp.Position).Magnitude <= reach then
						collect(player, s, i, "player")
					end
				end
			end
			updateWisp(player, s, dt)
			local now = os.clock()
			if now - (s.rateAt or 0) >= 1 then
				s.rateAt = now
				local sum = 0
				for i = #s.earned, 1, -1 do
					if now - s.earned[i].t > RATE_WINDOW then
						table.remove(s.earned, i)
					else
						sum += s.earned[i].gold
					end
				end
				-- (divide by the time the plot has been running while it is shorter than the window)
				player:SetAttribute("GoldRate", sum / math.clamp(now - s.startedAt, 5, RATE_WINDOW))
			end
		end
	end
end)

-- ============================================================
-- The first objective: break COLLECTOR_WALLS walls to earn the Soul Wisp
-- ============================================================
function Drops.wallBroken(player)
	local profile = PlayerData.get(player)
	if not profile then return end
	profile.wallsBroken = (profile.wallsBroken or 0) + 1
	if not profile.collector and profile.wallsBroken >= Drops.COLLECTOR_WALLS then
		profile.collector = true
		Remotes.Notice:FireClient(player, "You earned the Soul Wisp! It flies down your lane and collects your loot.")
	end
	PlayerData.changed(player)
end

Players.PlayerRemoving:Connect(function(player)
	local s = byOwner[player.UserId]
	if s then
		s.folder:Destroy()
		byOwner[player.UserId] = nil
	end
end)

return Drops
