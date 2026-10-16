-- The Soul Broker comes alive (client only, cosmetic; Design.md "The Soul Broker"): the hooded broker of the gem stall
-- (HubDecor.Stall_SoulBroker.Broker, rigged by build_broker_stall.lua: Root at the feet, sub-models Head / ArmL / ArmR
-- turning round their attribute Pivot) walks round behind his counter and does small comic bits: holds a potion up to
-- the light and shakes it, polishes a gem, plays the scale with his arms, dozes off on his feet and startles awake,
-- admires the featured portrait, drums his fingers on the counter. While idle his head follows a nearby player.
-- The stall's prompt (OpenBroker) or a click on a portrait opens the Gem Shop's in-world view at the stall at once
-- (GemShopPanel.openAtStall) and calls him to the counter: he walks to its middle, faces the customer and puts his hands
-- on the counter; when the shop closes he goes back to his round after a moment.
-- Motion: every value (position, facing, lean, head, arms) follows a critically damped spring and walking keeps its
-- momentum, so nothing ever snaps (the project's animation rule). Each client moves its own copy of the parts.
-- Builds itself when required (no init call).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GemShopPanel = require(script.Parent.GemShopPanel)
local BrokerPortraits = require(script.Parent.BrokerPortraits)

local player = Players.LocalPlayer

local BrokerKeeper = {}

local TOP = 0.95 -- the dais top in the stall's frame (build_broker_stall.lua)
local WALK_SPEED = 2.6 -- studs/s
local WALK_ACCEL = 3.2 -- how fast the walking velocity follows (spring rate)
local HANG = 0.75 -- arm angle that lets it hang (0 = hands on the counter, negative = raised forward)
local ACTIVE_RANGE = 140 -- no animation when the camera is further away

-- spots in the stall's frame (x, z; he faces -X at yaw 0, toward the customer)
local COUNTER = Vector2.new(1.6, 0)

-- ============================================================
-- Springs
-- ============================================================
local springs = {}
local function spring(x, w)
	local s = { x = x, v = 0, t = x, w = w }
	table.insert(springs, s)
	return s
end
local function stepSprings(dt)
	for _, s in ipairs(springs) do
		local a = s.w * s.w * (s.t - s.x) - 2 * s.w * s.v
		s.v += a * dt
		s.x += s.v * dt
	end
end

local yaw = spring(0, 4) -- facing (0 = toward the customer)
local lean = spring(0, 5) -- forward lean (+ = top toward where he faces)
local sway = spring(0, 5) -- sideways roll
local lift = spring(0, 6) -- body up / down
local headPitch = spring(0, 6) -- + = nods down
local headYaw = spring(0, 5)
local headRoll = spring(0, 5)
local armPitch = { [-1] = spring(0, 6), [1] = spring(0, 6) }
local armIn = { [-1] = spring(0, 6), [1] = spring(0, 6) } -- + = toward the middle

local pos = Vector2.new(COUNTER.X, COUNTER.Y)
local vel = Vector2.zero
local target = pos
local walkPhase = 0
local wasWalking = false

-- ============================================================
-- The rig
-- ============================================================
local rig -- { stall, parts = { BasePart }, groups = { { kind, side, pivot, parts, offsets } } }

local function buildRig(stall)
	local broker = stall:FindFirstChild("Broker")
	local root = broker and broker:FindFirstChild("Root")
	if not root then return nil end
	local frame = stall:GetPivot()
	local root0 = frame * CFrame.new(COUNTER.X, TOP, COUNTER.Y)
	local r = { stall = stall, broker = broker, frame = frame, groups = {} }
	local function group(kind, model, side)
		local pivot = model and model:GetAttribute("Pivot") or Vector3.zero
		local base = root0 * CFrame.new(pivot)
		local g = { kind = kind, side = side, pivot = pivot, parts = {}, offsets = {} }
		local function add(p)
			table.insert(g.parts, p)
			table.insert(g.offsets, base:ToObjectSpace(p.CFrame))
		end
		if model then
			for _, d in ipairs(model:GetDescendants()) do
				if d:IsA("BasePart") then add(d) end
			end
		else
			for _, d in ipairs(broker:GetChildren()) do
				if d:IsA("BasePart") and d ~= root then add(d) end
			end
		end
		table.insert(r.groups, g)
	end
	group("body", nil)
	group("head", broker:FindFirstChild("Head"))
	for _, arm in ipairs({ broker:FindFirstChild("ArmL"), broker:FindFirstChild("ArmR") }) do
		if arm then group("arm", arm, arm:GetAttribute("Side") or 1) end
	end
	-- (the rig is measured from the pose he was built in: standing at the counter, hands on it)
	return r
end

local function pose()
	local f = rig.frame
	local bob = math.abs(math.sin(walkPhase)) * 0.12 * math.min(1, vel.Magnitude / WALK_SPEED)
	local body = f * CFrame.new(pos.X, TOP + lift.x + bob, pos.Y) * CFrame.Angles(0, yaw.x, 0)
		* CFrame.Angles(sway.x, 0, lean.x)
	local parts, cfs = {}, {}
	for _, g in ipairs(rig.groups) do
		local base
		if g.kind == "body" then
			base = body
		elseif g.kind == "head" then
			base = body * CFrame.new(g.pivot) * CFrame.Angles(0, headYaw.x, 0) * CFrame.Angles(headRoll.x, 0, headPitch.x)
		else
			local s = g.side
			base = body * CFrame.new(g.pivot) * CFrame.Angles(0, -s * armIn[s].x, 0) * CFrame.Angles(0, 0, armPitch[s].x)
		end
		for i, p in ipairs(g.parts) do
			table.insert(parts, p)
			table.insert(cfs, base * g.offsets[i])
		end
	end
	workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
end

-- ============================================================
-- Behaviour: a script per action, cancelled by a generation counter
-- ============================================================
local gen = 0
local serving = false
local freeLook = false -- the head may follow the player (between bits and while serving)
local function alive(g) return g == gen end
local function wait(g, t)
	local t0 = os.clock()
	while os.clock() - t0 < t do
		if not alive(g) then return false end
		task.wait()
	end
	return alive(g)
end

-- the yaw that faces the direction (dx, dz) in the stall frame
local function yawFor(dx, dz)
	return math.atan2(dz, -dx)
end
local function face(angle)
	-- the shortest way round
	local cur = yaw.x
	yaw.t = cur + ((angle - cur + math.pi) % (2 * math.pi) - math.pi)
end

local function restPose(handsOnCounter)
	lean.t, sway.t, lift.t = 0, 0, 0
	headPitch.t, headYaw.t, headRoll.t = 0, 0, 0
	for _, s in ipairs({ -1, 1 }) do
		armPitch[s].t = handsOnCounter and 0 or HANG
		armIn[s].t = 0
	end
end

local function walkTo(g, spot)
	target = spot
	restPose(false)
	local t0 = os.clock()
	while (pos - spot).Magnitude > 0.08 or vel.Magnitude > 0.08 do
		if not alive(g) or os.clock() - t0 > 12 then return alive(g) end
		task.wait()
	end
	return alive(g)
end

local ACTIONS = {
	-- holds a potion up to the light, tilts his head, shakes it, shakes his head
	function(g)
		if not walkTo(g, Vector2.new(2.9, -7.0)) then return end
		face(yawFor(1, -0.3))
		if not wait(g, 0.8) then return end
		local s = -1
		armPitch[s].t, lean.t = -0.55, 0.12 -- reaches to the shelf
		if not wait(g, 1.0) then return end
		armPitch[s].t, armIn[s].t, lean.t, headPitch.t = -1.25, 0.55, -0.05, -0.35 -- holds it up to the light
		if not wait(g, 0.6) then return end
		for k = 1, 3 do
			headRoll.t = (k % 2 == 0) and 0.3 or -0.3
			if not wait(g, 0.7) then return end
		end
		for k = 1, 6 do -- shakes it
			armIn[s].t = 0.55 + ((k % 2 == 0) and 0.18 or -0.18)
			if not wait(g, 0.12) then return end
		end
		headRoll.t, armIn[s].t = 0, 0.5
		for k = 1, 4 do -- disappointed: no
			headYaw.t = (k % 2 == 0) and 0.35 or -0.35
			if not wait(g, 0.28) then return end
		end
		restPose(false)
		wait(g, 1.0)
	end,
	-- polishes a gem in small circles, then nods
	function(g)
		if not walkTo(g, Vector2.new(2.9, 7.0)) then return end
		face(yawFor(1, 0.3))
		if not wait(g, 0.8) then return end
		local s = 1
		armPitch[s].t, armIn[s].t, lean.t, headPitch.t = -0.75, 0.35, 0.08, 0.3
		armPitch[-s].t, armIn[-s].t = -0.6, 0.6
		local t0 = os.clock()
		while os.clock() - t0 < 3.5 do
			local a = (os.clock() - t0) * 9
			armPitch[s].t = -0.75 + math.sin(a) * 0.12
			armIn[s].t = 0.45 + math.cos(a) * 0.12
			if not wait(g, 0.03) then return end
		end
		headPitch.t = -0.1
		for k = 1, 2 do -- satisfied nods
			headPitch.t = 0.3
			if not wait(g, 0.25) then return end
			headPitch.t = -0.05
			if not wait(g, 0.25) then return end
		end
		restPose(false)
		wait(g, 1.0)
	end,
	-- plays the scale: his arms see-saw like the pans, then a shrug
	function(g)
		if not walkTo(g, Vector2.new(1.6, -4.4)) then return end
		face(0)
		if not wait(g, 0.6) then return end
		headPitch.t = 0.2
		for k = 1, 6 do
			local up = (k % 2 == 0) and 1 or -1
			armPitch[-1].t, armPitch[1].t = -0.25 * up, 0.25 * up
			armIn[-1].t, armIn[1].t = -0.3, -0.3
			headRoll.t = 0.15 * up
			sway.t = 0.04 * up
			if not wait(g, 0.45) then return end
		end
		-- shrug: arms out, shoulders up, head tilted
		armPitch[-1].t, armPitch[1].t = -0.35, -0.35
		armIn[-1].t, armIn[1].t = -0.7, -0.7
		lift.t, headRoll.t, sway.t, headPitch.t = 0.18, 0.25, 0, 0
		if not wait(g, 1.1) then return end
		restPose(false)
		wait(g, 1.0)
	end,
	-- dozes off on his feet, then startles awake and looks round
	function(g)
		if not walkTo(g, Vector2.new(1.8, 3.6)) then return end
		face(0)
		armPitch[-1].t, armPitch[1].t = 0.1, 0.1
		if not wait(g, 0.6) then return end
		headPitch.w, lift.w = 1.6, 1.6 -- (slow drowsy springs)
		headPitch.t, lift.t, lean.t = 0.55, -0.18, 0.06
		local t0 = os.clock()
		while os.clock() - t0 < 5 do
			lift.t = -0.18 + math.sin((os.clock() - t0) * 1.4) * 0.05 -- slow breathing
			if not wait(g, 0.05) then return end
		end
		headPitch.w, lift.w = 14, 12 -- (snappy: the startle)
		headPitch.t, lift.t, lean.t = -0.25, 0.3, -0.08
		armPitch[-1].t, armPitch[1].t = -0.3, -0.3
		if not wait(g, 0.35) then return end
		headPitch.w, lift.w = 6, 6
		lift.t, lean.t = 0, 0
		for _, y in ipairs({ 0.6, -0.6, 0.6, 0 }) do -- did anyone see?
			headYaw.t = y
			if not wait(g, 0.35) then return end
		end
		restPose(false)
		wait(g, 1.0)
	end,
	-- admires the featured portrait, hands behind his back
	function(g)
		if not walkTo(g, Vector2.new(2.2, 0.4)) then return end
		face(math.pi)
		if not wait(g, 0.9) then return end
		armPitch[-1].t, armPitch[1].t = 1.35, 1.35 -- hands behind the back
		armIn[-1].t, armIn[1].t = 0.25, 0.25
		headPitch.t, lean.t, lift.t = -0.4, -0.06, 0.06
		local t0 = os.clock()
		while os.clock() - t0 < 4 do
			sway.t = math.sin((os.clock() - t0) * 1.6) * 0.05
			headRoll.t = math.sin((os.clock() - t0) * 0.8) * 0.12
			if not wait(g, 0.05) then return end
		end
		sway.t, headRoll.t = 0, 0
		headPitch.t = -0.15 -- a proud nod
		if not wait(g, 0.4) then return end
		headPitch.t = -0.4
		if not wait(g, 0.4) then return end
		restPose(false)
		wait(g, 1.0)
	end,
	-- drums his fingers on the counter over the ledger
	function(g)
		if not walkTo(g, Vector2.new(1.6, -1.6)) then return end
		face(0)
		if not wait(g, 0.6) then return end
		headPitch.t, lean.t = 0.35, 0.06
		armPitch[-1].t, armPitch[1].t = 0, 0
		for k = 1, 16 do
			local s = (k % 2 == 0) and 1 or -1
			armPitch[s].t = -0.07
			armPitch[-s].t = 0.02
			if not wait(g, 0.13) then return end
		end
		headPitch.t, headYaw.t = 0.1, 0.4 -- a glance up: anyone?
		if not wait(g, 1.0) then return end
		restPose(false)
		wait(g, 0.8)
	end,
}

local function idleLoop()
	gen += 1
	local g = gen
	task.spawn(function()
		local last
		while alive(g) do
			local i
			repeat i = math.random(1, #ACTIONS) until i ~= last or #ACTIONS < 2
			last = i
			freeLook = false
			ACTIONS[i](g)
			if not alive(g) then return end
			restPose(false)
			freeLook = true
			wait(g, math.random(15, 35) / 10)
		end
	end)
end

-- the stall's prompt / a portrait click: the shop's view opens at once, he comes to the counter to serve
local function serve()
	GemShopPanel.openAtStall("deals")
	if not rig or serving then
		return
	end
	gen += 1
	local g = gen
	serving = true
	freeLook = false
	task.spawn(function()
		headPitch.w, lift.w = 6, 6
		walkTo(g, COUNTER)
		if not alive(g) then return end
		face(0)
		restPose(true)
		freeLook = true -- he looks at his customer
		while alive(g) and GemShopPanel.isOpen() do task.wait(0.2) end
		if not wait(g, 2.5) then return end
		serving = false
		idleLoop()
	end)
end

-- ============================================================
-- The frame loop
-- ============================================================
RunService.Heartbeat:Connect(function(dt)
	if not (rig and rig.broker.Parent) then return end
	local cam = workspace.CurrentCamera
	if cam and (cam.CFrame.Position - rig.frame.Position).Magnitude > ACTIVE_RANGE then return end
	dt = math.min(dt, 1 / 20)
	-- walking: the velocity eases toward the wanted one (momentum), slows down on arrival
	local to = target - pos
	local dist = to.Magnitude
	local want = dist > 0.02 and to.Unit * math.min(WALK_SPEED, dist * 1.4) or Vector2.zero
	local before = vel
	vel = vel + (want - vel) * math.min(1, WALK_ACCEL * dt)
	pos = pos + vel * dt
	local speed = vel.Magnitude
	if speed > 0.25 then
		face(yawFor(vel.X, vel.Y)) -- turn into the walk
	end
	walkPhase += dt * speed * 2.6
	local walking = math.min(1, speed / WALK_SPEED)
	local isWalking = walking > 0.05
	-- lean with speed and acceleration, swing the arms with the stride
	local accel = (vel - before).Magnitude / math.max(dt, 1e-3)
	if isWalking then
		lean.t = 0.07 * walking + math.clamp(accel * 0.01, 0, 0.05)
		sway.t = math.sin(walkPhase) * 0.04 * walking
		for _, s in ipairs({ -1, 1 }) do
			armPitch[s].t = HANG + math.sin(walkPhase + (s > 0 and math.pi or 0)) * 0.35 * walking
		end
	elseif wasWalking then
		-- just stopped: settle the stride (the next pose is set by whoever called walkTo)
		lean.t, sway.t = 0, 0
		for _, s in ipairs({ -1, 1 }) do armPitch[s].t = serving and 0 or HANG end
	end
	wasWalking = isWalking
	-- between bits and while serving, the head follows the player when near
	if freeLook and not isWalking then
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		local look = 0
		if hrp then
			local rel = rig.frame:PointToObjectSpace(hrp.Position)
			local d = Vector2.new(rel.X - pos.X, rel.Z - pos.Y)
			if d.Magnitude < 22 then
				local want = (yawFor(d.X, d.Y) - yaw.x + math.pi) % (2 * math.pi) - math.pi
				look = math.clamp(want, -0.9, 0.9)
			end
		end
		headYaw.t = look
	end
	stepSprings(dt)
	pose()
end)

-- ============================================================
-- Find the broker (the stall is persistent; it may be rebuilt in Studio)
-- ============================================================
local function scan()
	local decor = workspace:FindFirstChild("HubDecor")
	local stall = decor and decor:FindFirstChild("Stall_SoulBroker")
	if stall and (not rig or rig.stall ~= stall or not rig.broker.Parent) then
		rig = buildRig(stall)
		pos, vel, target = COUNTER, Vector2.zero, COUNTER
		if rig then idleLoop() end
	end
end
task.spawn(function()
	local decor = workspace:WaitForChild("HubDecor", 60)
	if not decor then return end
	local stall = decor:WaitForChild("Stall_SoulBroker", 60)
	if stall then stall:WaitForChild("Broker", 30) end
	scan()
	decor.ChildAdded:Connect(function(c)
		if c.Name == "Stall_SoulBroker" then
			task.wait(1)
			scan()
		end
	end)
end)

local openBroker = ReplicatedStorage:WaitForChild("OpenBroker", 5)
if openBroker then
	openBroker.OnClientEvent:Connect(serve)
end
-- a click on a portrait: open the stall's view if needed and pick that deal
BrokerPortraits.onPick = function(index)
	serve()
	GemShopPanel.select(index)
end

return BrokerKeeper
