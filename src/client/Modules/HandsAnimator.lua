-- The realm keeper's hands (tag RealmHands; ServerStorage.TitanModels.GravekeeperHands, tools/studio/build_titan_hands.lua,
-- placed by the server's Titans behind every claimed lane): everything moves on the clients, through the rig's
-- Motor6D.Transform (identity = the resting pose baked into the model) and the anchored rift / eye parts.
--
-- Idle (slow and heavy, like every huge thing in the game):
--   breathing   both arms rise and sink very slowly round their rifts, the rifts' light pulses with it
--   twitches    a finger lifts a little now and then
--   actions     every 10-20 s per hand (never both hands at once) one of:
--                 drum   the fingers tap the stone one after another, a few rounds
--                 flex   the hand lifts, opens and closes its fingers in the air, settles back
--                 point  the hand lifts and points one long finger at the wall the army fights (attribute Focus)
--   swirls      the dark streaks in the rifts turn round the rift's normal
--   eyes        blink every few seconds (now and then twice), drift a little in the fog, shift towards the player
-- Behaviours (attributes SummonAt / SummonKind set by the server's Walls / Titans; timings kept in sync with Walls'
-- TITAN_* constants, the same as the old titan's):
--   SlamWeave   the eyes turn red, both hands rise out of the rifts and clench, slam the battlements at IMPACT_HIT
--               (dust, chunks, the owner's camera shake, the tremor down the lane), then the left hand weaves the next
--               wall with green threads (WEAVE_FROM..WEAVE_TO) and settles back
--   Defeat      (the gate fell; held) the eyes flare, the hands shudder and rear up, are dragged back into the rifts,
--               the rifts zip shut and leave smoking scars, the eyes flicker out
--   Return      (after an ascension) the scars tear open, the hands push out high, grasping, and are lowered onto the
--               battlements; the eyes open
--   Waiting / Enter   a player's first visit: closed rifts and dark eyes until the owner steps onto the plot, then
--               the Return, a little slower
--   FleetStrike (Malak's finisher, client FleetStrike.lua sets SummonKind / SummonAt LOCALLY at the cutscene's start;
--               its times are the cutscene's): he notices the ship during the scan (eyes red, hands tense), the barrage
--               makes his hands shudder, he raises both hands high as a shield as the cannon charges, the beam slams
--               into his palms (his eyes flinch shut, he recoils), and when the gate falls he is DRIVEN BACK (not killed:
--               he is the secret world boss): dragged into the rifts, which close; his eyes dim
-- The effects (dust, shake, tremor, threads) are small copies of Modules/TitanAnimator's (kept for the world boss).
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local MAX_DISTANCE = 900 -- keepers farther than this from the camera are not animated
local SWIRL_SPEED = 0.22 -- rad/s
local IMPACT_HIT = 3.1 -- Walls.TITAN_IMPACT
local WEAVE_FROM, WEAVE_TO = 5.6, 8.8 -- Walls.TITAN_WEAVE_RISE / + TITAN_RISE_TIME
local TREMOR_SPEED = 140 -- Walls.TREMOR_SPEED
local RETRACT = 64 -- studs an arm is pulled back into its rift when it is gone
local RIFT_CLOSED = 0.04 -- the rifts' scale when shut
local EYE_ANGRY = Color3.fromRGB(255, 40, 25)
local EYE_DEAD = Color3.fromRGB(10, 12, 11)
local THREAD_CORE = ColorSequence.new(Color3.fromRGB(190, 255, 215), Color3.fromRGB(120, 255, 170))
local THREAD_GLOW = ColorSequence.new(Color3.fromRGB(40, 255, 130), Color3.fromRGB(20, 210, 110))
local CRACK_COLOR = Color3.fromRGB(80, 255, 160)
local STONE = Color3.fromRGB(108, 112, 138) -- the outer wall's stone
local DUST = Color3.fromRGB(120, 112, 100)

local player = Players.LocalPlayer
local keepers = {} -- [model] = state

local function smooth(x)
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

-- 0 -> 1 over `rise` seconds, held, back to 0 over `fall` seconds before `dur`
local function envelope(t, dur, rise, fall)
	if t <= 0 or t >= dur then
		return 0
	end
	return math.min(smooth(t / rise), smooth((dur - t) / fall))
end

-- a value along keys { {t, v, ease}, ... } (smooth between keys; ease "in" = accelerating into that key, a fall)
local function key(keys, t)
	if t <= keys[1][1] then
		return keys[1][2]
	end
	for i = 2, #keys do
		local a, b = keys[i - 1], keys[i]
		if t <= b[1] then
			local f = (t - a[1]) / math.max(1e-3, b[1] - a[1])
			f = (b[3] == "in") and (f * f) or smooth(f)
			return a[2] + (b[2] - a[2]) * f
		end
	end
	return keys[#keys][2]
end

-- ============================================================
-- Behaviour timelines: per hand lift (deg, round the rift), back (studs into the rift), wrist (deg), clench (0..1),
-- weave (0..1, left hand only); plus the rifts' scale and the eyes' anger / darkness
-- ============================================================
local LENGTH = { SlamWeave = 10.4, Return = 7.6, Enter = 8.8, FleetStrike = 56 }
local HOLD = { Defeat = true, Waiting = true }

local TL = {
	SlamWeave = {
		lift = { { 0, 0 }, { 0.4, 0 }, { 2.3, 38 }, { 2.7, 40 }, { IMPACT_HIT, -5, "in" }, { 3.6, -3 }, { 4.4, 0 } },
		liftL = { { 0, 0 }, { 0.4, 0 }, { 2.3, 38 }, { 2.7, 40 }, { IMPACT_HIT, -5, "in" }, { 3.6, -3 }, { 4.6, 0 },
			{ WEAVE_FROM - 0.3, 22 }, { WEAVE_TO - 0.2, 22 }, { 10.2, 0 } },
		back = { { 0, 0 }, { 2.3, 9 }, { IMPACT_HIT, 0, "in" } },
		wrist = { { 0, 0 }, { 2.3, -25 }, { IMPACT_HIT, 8, "in" }, { 3.7, 0 } },
		wristL = { { 0, 0 }, { 2.3, -25 }, { IMPACT_HIT, 8, "in" }, { 3.7, 0 }, { 4.6, 0 }, { WEAVE_FROM - 0.3, 36 }, { WEAVE_TO - 0.2, 36 }, { 10.2, 0 } },
		clench = { { 0, 0 }, { 1.6, 0 }, { 2.4, 1 }, { 3.3, 1 }, { 3.7, 0 } },
		weave = { { 0, 0 }, { 4.6, 0 }, { WEAVE_FROM - 0.2, 1 }, { WEAVE_TO, 1 }, { 9.6, 0 } },
		anger = { { 0, 0 }, { 0.3, 0 }, { 1.5, 1 }, { IMPACT_HIT + 2.8, 1 }, { IMPACT_HIT + 4, 0 } },
	},
	Defeat = {
		lift = { { 0, 0 }, { 3.2, 0 }, { 4.2, 16 }, { 6.2, 10 } },
		back = { { 0, 0 }, { 4.4, 0 }, { 6.4, RETRACT, "in" } },
		wrist = { { 0, 0 }, { 3.2, 0 }, { 4.2, -20 }, { 6.2, -30 } },
		clench = { { 0, 0 }, { 1.2, 0.6 }, { 3.2, 0.6 }, { 4.2, 0 }, { 6.2, 0.4 } },
		rift = { { 0, 1 }, { 6.2, 1 }, { 7.2, RIFT_CLOSED, "in" } },
		anger = { { 0, 0 }, { 1.2, 1 } },
		dark = { { 0, 0 }, { 5.2, 0 }, { 7.2, 1 } },
		shudder = { { 0, 0 }, { 1.2, 1 }, { 3.2, 1 }, { 4.0, 0 } },
	},
	Return = {
		rift = { { 0, RIFT_CLOSED }, { 1.2, 1 } },
		back = { { 0, RETRACT }, { 1.0, RETRACT }, { 3.6, 0 } },
		lift = { { 0, 30 }, { 3.6, 24 }, { 5.4, 6 }, { 6.8, 0 } },
		wrist = { { 0, -20 }, { 3.6, -10 }, { 5.6, 0 } },
		clench = { { 0, 1 }, { 3.6, 0.6 }, { 5.4, 0 } },
		dark = { { 0, 1 }, { 2.2, 1 }, { 3.2, 0 } },
	},
	Enter = {
		rift = { { 0, RIFT_CLOSED }, { 0.6, RIFT_CLOSED }, { 2.0, 1 } },
		back = { { 0, RETRACT }, { 2.0, RETRACT }, { 5.2, 0 } },
		lift = { { 0, 30 }, { 5.2, 24 }, { 7.0, 6 }, { 8.4, 0 } },
		wrist = { { 0, -20 }, { 5.2, -10 }, { 7.2, 0 } },
		clench = { { 0, 1 }, { 5.2, 0.6 }, { 7.0, 0 } },
		dark = { { 0, 1 }, { 3.4, 1 }, { 4.4, 0 } },
	},
	-- (times = Fleet Strike cutscene times: scan 31, barrage 38, cannon 42, beam 46, gate falls 49.4)
	FleetStrike = {
		anger = { { 0, 0 }, { 31.2, 0 }, { 32.6, 1 } },
		clench = { { 0, 0 }, { 31.6, 0 }, { 32.8, 0.5 }, { 43.6, 0.5 }, { 44.6, 0 }, { 47.6, 0.25 }, { 49.8, 0.7 } },
		lift = { { 0, 0 }, { 31.6, 0 }, { 32.8, 5 }, { 38.6, 5 }, { 39.4, 11 }, { 43.2, 11 }, { 45.2, 58 }, { 45.9, 62 },
			{ 46.3, 54 }, { 47.6, 50 }, { 49.6, 22 }, { 51.6, 14 } },
		wrist = { { 0, 0 }, { 31.6, 0 }, { 32.8, -6 }, { 43.2, -6 }, { 45.2, -38 }, { 45.9, -50 }, { 46.3, -36 },
			{ 47.6, -40 }, { 49.6, -18 }, { 51.6, -30 } },
		back = { { 0, 0 }, { 46.0, 0 }, { 46.4, 7 }, { 47.6, 5 }, { 49.8, 5 }, { 52.0, RETRACT, "in" } },
		rift = { { 0, 1 }, { 51.8, 1 }, { 52.8, RIFT_CLOSED, "in" } },
		squint = { { 0, 0 }, { 46.0, 0 }, { 46.15, 1 }, { 48.6, 1 }, { 49.2, 0.4 }, { 52.6, 0.4 } },
		dark = { { 0, 0 }, { 50.0, 0 }, { 53.0, 0.85 } },
		shudder = { { 0, 0 }, { 38.2, 0 }, { 38.7, 0.5 }, { 42, 0.5 }, { 43, 0 }, { 46.0, 0 }, { 46.2, 1 }, { 49.8, 1 }, { 51, 0.3 } },
	},
	Waiting = {
		rift = { { 0, RIFT_CLOSED }, { 1, RIFT_CLOSED } },
		back = { { 0, RETRACT }, { 1, RETRACT } },
		dark = { { 0, 1 }, { 1, 1 } },
	},
}

local IDLE_ACTIONS = { drum = 3.2, flex = 5.0, point = 5.5 }
local IDLE_NAMES = { "drum", "flex", "point" }

-- ============================================================
-- Effects: dust, the camera shake, the impact, the tremor down the lane, the weave's threads
-- ============================================================
local shakeUntil, shakeLength, shakePower = 0, 1, 0

local function dust(pos, amount, size, speed)
	local holder = Instance.new("Part")
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.Transparency = 1
	holder.Size = Vector3.new(1, 1, 1)
	holder.Position = pos
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	e.Color = ColorSequence.new(DUST)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size * 0.5), NumberSequenceKeypoint.new(1, size * 1.6) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
	e.Lifetime = NumberRange.new(1.8, 3)
	e.Speed = NumberRange.new(speed * 0.4, speed)
	e.SpreadAngle = Vector2.new(180, 50)
	e.Drag = 2
	e.Rotation = NumberRange.new(0, 360)
	e.Enabled = false
	e.Parent = holder
	holder.Parent = workspace
	e:Emit(amount)
	Debris:AddItem(holder, 4)
end

local function shake(power, length)
	shakeUntil = os.clock() + length
	shakeLength = length
	shakePower = math.max(shakePower, power)
end

-- a crack of soul light runs down the lane from the outer wall towards the plot (LaneEnd / LaneBack / LaneLength)
local function tremor(model)
	local laneEnd = model:GetAttribute("LaneEnd")
	local back = model:GetAttribute("LaneBack")
	local length = model:GetAttribute("LaneLength") or 280
	if not (laneEnd and back) then
		return
	end
	local right = back:Cross(Vector3.yAxis).Unit
	local y = laneEnd.Y + 0.25
	task.spawn(function()
		local d, lat = 0, 0
		local step = 6
		while d < length and model.Parent do
			local nextLat = math.clamp(lat + (math.random() - 0.5) * 6, -12, 12)
			local a = laneEnd + back * d + right * lat
			local b = laneEnd + back * (d + step) + right * nextLat
			a = Vector3.new(a.X, y, a.Z)
			b = Vector3.new(b.X, y, b.Z)
			local crack = Instance.new("Part")
			crack.Anchored = true
			crack.CanCollide = false
			crack.CanQuery = false
			crack.CastShadow = false
			crack.Material = Enum.Material.Neon
			crack.Color = CRACK_COLOR
			crack.Size = Vector3.new(0.6, 0.15, (b - a).Magnitude + 0.3)
			crack.CFrame = CFrame.lookAt((a + b) / 2, b)
			crack.Parent = workspace
			TweenService:Create(crack, TweenInfo.new(2.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 1.5), { Transparency = 1 }):Play()
			Debris:AddItem(crack, 4.2)
			if math.floor(d / step) % 3 == 0 then
				dust(b + Vector3.new(0, 1, 0), 10, 6, 10)
			end
			d += step
			lat = nextLat
			task.wait(step / TREMOR_SPEED)
		end
	end)
end

local function impact(st)
	for _, side in ipairs({ "L", "R" }) do
		local hand = st.handParts[side]
		if hand then
			local pos = hand.Position
			dust(pos, 30, 12, 26)
			for _ = 1, 8 do
				local s = 2 + math.random() * 4
				local c = Instance.new("Part")
				c.Size = Vector3.new(s, s * 0.8, s)
				c.Color = STONE
				c.Material = Enum.Material.Cobblestone
				c.CollisionGroup = "Debris"
				c.CFrame = CFrame.new(pos + Vector3.new((math.random() - 0.5) * 14, -4, (math.random() - 0.5) * 14))
				c.AssemblyLinearVelocity = Vector3.new((math.random() - 0.5) * 50, 25 + math.random() * 30, (math.random() - 0.5) * 50)
				c.AssemblyAngularVelocity = Vector3.new(math.random(-5, 5), math.random(-5, 5), math.random(-5, 5))
				c.Parent = workspace
				Debris:AddItem(c, 4)
			end
		end
	end
	tremor(st.model)
	-- only the keeper's own player feels it (with 8 players the shakes would never stop)
	if st.model:GetAttribute("OwnerId") == player.UserId then
		shake(1.1, 1.6)
	end
end

-- one glowing beam from each left fingertip to the rising wall
local function threads(st)
	if st.threadFolder then
		return st.threads
	end
	local folder = Instance.new("Folder")
	folder.Name = "KeeperThreads"
	folder.Parent = workspace
	st.threadFolder = folder
	st.threads = {}
	for k = 1, 4 do
		local tip = st.tips[k]
		if tip then
			local a0 = Instance.new("Attachment")
			a0.Parent = tip
			local anchor = Instance.new("Part")
			anchor.Anchored = true
			anchor.CanCollide = false
			anchor.CanQuery = false
			anchor.Transparency = 1
			anchor.Size = Vector3.new(0.5, 0.5, 0.5)
			anchor.Parent = folder
			local a1 = Instance.new("Attachment")
			a1.Parent = anchor
			local glow = Instance.new("Beam")
			glow.Attachment0 = a0
			glow.Attachment1 = a1
			glow.Color = THREAD_GLOW
			glow.LightEmission = 1
			glow.LightInfluence = 0
			glow.FaceCamera = true
			glow.Width0 = 3.2
			glow.Width1 = 1.8
			glow.Segments = 24
			glow.CurveSize0 = -12
			glow.Texture = "rbxasset://textures/particles/sparkles_main.dds"
			glow.TextureMode = Enum.TextureMode.Wrap
			glow.TextureLength = 8
			glow.TextureSpeed = 1.6
			glow.Transparency = NumberSequence.new(1)
			glow.Parent = anchor
			local beam = Instance.new("Beam")
			beam.Attachment0 = a0
			beam.Attachment1 = a1
			beam.Color = THREAD_CORE
			beam.LightEmission = 1
			beam.LightInfluence = 0
			beam.FaceCamera = true
			beam.Width0 = 0.9
			beam.Width1 = 0.5
			beam.Segments = 24
			beam.CurveSize0 = -12
			beam.Transparency = NumberSequence.new(1)
			beam.Parent = anchor
			local sparks = Instance.new("ParticleEmitter")
			sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
			sparks.Color = THREAD_GLOW
			sparks.LightEmission = 1
			sparks.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 0) })
			sparks.Lifetime = NumberRange.new(0.6, 1.2)
			sparks.Speed = NumberRange.new(3, 8)
			sparks.SpreadAngle = Vector2.new(180, 180)
			sparks.Rate = 0
			sparks.Parent = anchor
			table.insert(st.threads, { beam = beam, glow = glow, anchor = anchor, sparks = sparks, k = k })
		end
	end
	return st.threads
end

local function updateThreads(st, weight, ta)
	if weight <= 0 and not st.threadFolder then
		return
	end
	local list = threads(st)
	local focus = st.model:GetAttribute("Focus")
	local right = st.model:GetPivot().RightVector
	local rise = math.clamp((ta - WEAVE_FROM) / (WEAVE_TO - WEAVE_FROM), 0, 1)
	for _, th in ipairs(list) do
		local flicker = 0.06 * math.sin(os.clock() * 5 + th.k)
		th.beam.Transparency = NumberSequence.new(math.clamp(1 - weight * (0.95 + flicker), 0, 1))
		th.glow.Transparency = NumberSequence.new(math.clamp(1 - weight * (0.55 + flicker), 0, 1))
		th.sparks.Rate = weight > 0.5 and 30 or 0
		if focus then
			th.anchor.Position = focus + right * ((th.k - 2.5) * 9) + Vector3.new(0, -10 + rise * 18 + math.sin(os.clock() * 1.6 + th.k) * 1.5, 0)
		end
	end
end

-- a rift: scaled open / shut (a smoking scar while shut)
local function setRift(rift, r, scale)
	-- (compared with the model's real scale, never a cached one; the keeper streams in atomically, see the build script)
	if math.abs(scale - rift:GetScale()) < 0.004 then
		return
	end
	pcall(function()
		rift:ScaleTo(math.max(scale, 0.01))
	end)
	local open = scale > 0.5
	for _, e in ipairs(r.emitters) do
		e.Enabled = open
	end
	if r.scar then
		r.scar.Enabled = scale < 0.15
	end
end

-- ============================================================
-- Registering a keeper (parts and joints can stream in later)
-- ============================================================
local function register(model)
	if keepers[model] then
		return
	end
	local st = {
		model = model, joints = {}, eyes = {}, swirls = {}, lights = {}, rifts = {}, armParts = {}, handParts = {}, tips = {},
		phase = math.random() * 50, hands = {},
	}
	keepers[model] = st
	local function scan()
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("Motor6D") then
				st.joints[d.Name] = d
			elseif d:IsA("BasePart") then
				if d.Name == "Eye" and not st.eyes[d] then
					st.eyes[d] = { base = d.CFrame, size = d.Size, color = d.Color }
				elseif not d.Anchored and not st.armParts[d] then
					st.armParts[d] = true -- (moved by the joints: hidden while pulled into the rift)
				end
				if d.Name == "LHand" or d.Name == "RHand" then
					st.handParts[d.Name:sub(1, 1)] = d
				end
				local k = d.Name:match("^LFinger(%d)Tip$")
				if k then
					st.tips[tonumber(k)] = d
				end
			elseif d:IsA("Model") and d.Name == "Swirl" and d.PrimaryPart and not st.swirls[d] then
				st.swirls[d] = { base = d:GetPivot(), dir = (d.Parent and d.Parent.Name == "RiftL") and 1 or -1 }
			elseif d:IsA("PointLight") and d.Parent and d.Parent.Name == "RiftLight" and not st.lights[d] then
				st.lights[d] = d.Brightness
			elseif d:IsA("Model") and (d.Name == "RiftL" or d.Name == "RiftR") and not st.rifts[d] then
				local r = { emitters = {} }
				for _, e in ipairs(d:GetDescendants()) do
					if e:IsA("ParticleEmitter") then
						table.insert(r.emitters, e)
					end
				end
				-- the scar's smoke while the rift is shut (client-made)
				local centre = d:GetBoundingBox()
				local holder = Instance.new("Part")
				holder.Anchored = true
				holder.CanCollide = false
				holder.CanQuery = false
				holder.Transparency = 1
				holder.Size = Vector3.new(4, 10, 2)
				holder.CFrame = centre
				local smoke = Instance.new("ParticleEmitter")
				smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
				smoke.Color = ColorSequence.new(Color3.fromRGB(40, 46, 42))
				smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 3), NumberSequenceKeypoint.new(1, 9) })
				smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1) })
				smoke.Lifetime = NumberRange.new(3, 5)
				smoke.Speed = NumberRange.new(1.5, 3)
				smoke.EmissionDirection = Enum.NormalId.Top
				smoke.Rate = 5
				smoke.Enabled = false
				smoke.Parent = holder
				holder.Parent = model
				r.scar = smoke
				st.rifts[d] = r
			end
		end
	end
	scan()
	model.DescendantAdded:Connect(function()
		task.defer(scan)
	end)
	for _, side in ipairs({ "L", "R" }) do
		st.hands[side] = { action = nil, startAt = 0, nextAt = os.clock() + math.random(4, 12) + (side == "R" and 5 or 0) }
	end
	st.nextBlink = os.clock() + math.random(2, 5)
end

for _, m in ipairs(CollectionService:GetTagged("RealmHands")) do
	register(m)
end
CollectionService:GetInstanceAddedSignal("RealmHands"):Connect(register)
CollectionService:GetInstanceRemovedSignal("RealmHands"):Connect(function(m)
	local st = keepers[m]
	if st and st.threadFolder then
		st.threadFolder:Destroy()
	end
	keepers[m] = nil
end)

local function set(j, cf)
	if j then
		j.Transform = cf
	end
end

-- ============================================================
-- One hand: the idle (when nothing else happens) plus the behaviour's values
-- ============================================================
local function animateHand(st, side, c, now, breath, beh)
	local j = st.joints
	local h = st.hands[side]
	local other = st.hands[side == "L" and "R" or "L"]
	if beh.acting then
		h.action = nil -- (no idle actions during a behaviour)
		h.nextAt = math.max(h.nextAt, now + 6)
	elseif not h.action and now >= h.nextAt and not other.action then
		h.action = IDLE_NAMES[math.random(#IDLE_NAMES)]
		h.startAt = now
	end
	local at = h.action and (now - h.startAt) or 0
	if h.action and at >= IDLE_ACTIONS[h.action] then
		h.action = nil
		h.nextAt = now + math.random(10, 20)
	end

	local lift, wristPitch, wristYaw = beh.lift, beh.wrist, 0
	local curl = {}
	for k = 1, 5 do
		curl[k] = beh.clench * 62
	end
	if h.action == "drum" then
		local e = envelope(at, IDLE_ACTIONS.drum, 0.4, 0.5)
		lift += 1.2 * e
		for k = 1, 4 do
			local beat = (at * 2.4 - (4 - k) * 0.18) % 1
			local tap = beat < 0.3 and math.sin(beat / 0.3 * math.pi) or 0
			curl[k] -= tap * 28 * e
		end
	elseif h.action == "flex" then
		local e = envelope(at, IDLE_ACTIONS.flex, 1.4, 1.5)
		lift += 7 * e
		wristPitch += 12 * e
		local open = math.sin(math.clamp((at - 1.0) / 2.6, 0, 1) * math.pi * 2)
		for k = 1, 4 do
			curl[k] += (-38 * math.max(0, open) + 30 * math.max(0, -open)) * e
		end
		curl[5] -= 20 * math.max(0, open) * e
	elseif h.action == "point" then
		local e = envelope(at, IDLE_ACTIONS.point, 1.3, 1.4)
		lift += 6 * e
		wristPitch += 34 * e
		local focus = st.model:GetAttribute("Focus")
		if focus then
			local lp = st.model:GetPivot():PointToObjectSpace(focus)
			wristYaw = math.clamp(-lp.X * 0.08, -12, 12) * e
		end
		curl[1] += 40 * e
		curl[3] += 42 * e
		curl[4] += 44 * e
		curl[5] += 20 * e
		curl[2] -= 34 * e
	end
	-- the weave (left hand): a slow wave through the spread fingers
	if beh.weave > 0 then
		for k = 1, 4 do
			local wave = math.sin(c * 2.2 - k * 0.8)
			curl[k] += beh.weave * (wave * 26 + 6)
		end
		wristYaw += math.sin(c * 1.1) * 8 * beh.weave
	end
	-- the beaten keeper's hands shudder
	local shudder = beh.shudder > 0 and (math.sin(now * 23 + (side == "L" and 0 or 1.3)) * 2.5 + math.sin(now * 37) * 1.5) * beh.shudder or 0

	local breathing = beh.acting and 0.3 or 1
	set(j[side .. "Arm"], CFrame.new(0, 0, beh.back) * CFrame.Angles(math.rad(breath * 0.9 * breathing + lift + shudder),
		math.rad(math.sin(c * 0.11 + (side == "L" and 0 or 2)) * 0.6 + shudder * 0.4), 0))
	set(j[side .. "Wrist"], CFrame.Angles(math.rad(wristPitch + breath * 0.5 * breathing), math.rad(wristYaw), 0))
	for k = 1, 4 do
		local twitch = beh.acting and 0 or (math.max(0, math.sin(c * (0.16 + k * 0.013) + k * 2.3 + (side == "L" and 0 or 1.7))) ^ 12)
		local a = curl[k] - twitch * 14
		-- (these hands' finger joints bend the other way round than the titan's: a positive curl is a negative angle)
		set(j[side .. "Finger" .. k .. "a"], CFrame.Angles(math.rad(-a), 0, 0))
		set(j[side .. "Finger" .. k .. "b"], CFrame.Angles(math.rad(-a * 0.8), 0, 0))
	end
	set(j[side .. "Thumba"], CFrame.Angles(math.rad(-curl[5]), 0, 0))
	set(j[side .. "Thumbb"], CFrame.Angles(math.rad(-curl[5] * 0.6), 0, 0))
end

-- ============================================================
-- Every frame
-- ============================================================
RunService.RenderStepped:Connect(function()
	local now = os.clock()
	local serverNow = workspace:GetServerTimeNow()
	local camera = workspace.CurrentCamera
	local camPos = camera and camera.CFrame.Position
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	for model, st in pairs(keepers) do
		if not model.Parent then
			if st.threadFolder then
				st.threadFolder:Destroy()
			end
			keepers[model] = nil
			continue
		end
		local pivot = model:GetPivot()
		if camPos and (pivot.Position - camPos).Magnitude > MAX_DISTANCE then
			continue
		end
		local c = now + st.phase
		local breath = math.sin(c * 0.32)

		-- the behaviour
		local kind = model:GetAttribute("SummonKind")
		local summonAt = model:GetAttribute("SummonAt")
		local ta = summonAt and (serverNow - summonAt) or math.huge
		local tl = TL[kind or ""]
		local acting = tl ~= nil and ta >= 0 and (HOLD[kind] or ta <= (LENGTH[kind] or 0) + 0.3)
		local function v(name, default)
			local keys = acting and tl[name]
			return keys and key(keys, ta) or default
		end
		if kind == "SlamWeave" and acting and ta >= IMPACT_HIT and ta < IMPACT_HIT + 1 and st.impactDone ~= summonAt then
			st.impactDone = summonAt
			impact(st)
		end
		local weave = v("weave", 0)
		for _, side in ipairs({ "L", "R" }) do
			local beh = {
				acting = acting,
				lift = (side == "L" and acting and tl.liftL) and key(tl.liftL, ta) or v("lift", 0),
				back = v("back", 0),
				wrist = (side == "L" and acting and tl.wristL) and key(tl.wristL, ta) or v("wrist", 0),
				clench = v("clench", 0),
				weave = side == "L" and weave or 0,
				shudder = v("shudder", 0),
			}
			animateHand(st, side, c, now, breath, beh)
		end
		updateThreads(st, weave, ta)

		-- pulled into the rift: the arms vanish (they would show behind it)
		local hidden = math.clamp((v("back", 0) - RETRACT * 0.6) / (RETRACT * 0.35), 0, 1)
		if hidden ~= st.hidden then
			st.hidden = hidden
			for p in pairs(st.armParts) do
				if p.Parent then
					p.LocalTransparencyModifier = hidden
				end
			end
		end

		-- the rifts: open / shut, the swirls turn, the light pulses with the breath
		local riftScale = v("rift", 1)
		for rift, r in pairs(st.rifts) do
			if rift.Parent then
				setRift(rift, r, riftScale)
			end
		end
		if riftScale > 0.99 then
			for swirl, s in pairs(st.swirls) do
				if swirl.Parent then
					swirl:PivotTo(s.base * CFrame.Angles(0, 0, s.dir * (c * SWIRL_SPEED) % (2 * math.pi)))
				end
			end
		end
		for light, base in pairs(st.lights) do
			light.Brightness = base * (0.85 + 0.15 * breath) * math.clamp(riftScale, 0, 1)
		end

		-- the eyes: blink (squashed flat), drift in the fog, shift a little towards the player; red with anger, out
		-- when beaten or waiting
		if now >= st.nextBlink then
			st.blinkAt = now
			st.doubleBlink = math.random() < 0.25
			st.nextBlink = now + math.random(3, 7) + math.random()
		end
		local open = 1
		if st.blinkAt then
			local b = now - st.blinkAt
			local function closeAt(t0)
				local x = (b - t0) / 0.2
				return (x > 0 and x < 1) and math.sin(x * math.pi) or 0
			end
			open = 1 - math.max(closeAt(0), st.doubleBlink and closeAt(0.32) or 0)
		end
		local anger = v("anger", 0)
		local dark = v("dark", 0)
		if kind == "Defeat" and acting and dark > 0 and dark < 1 then
			dark = (math.sin(ta * 40) > 0.2) and dark or dark * 0.3 -- (a flicker before they die)
		end
		if anger > 0 then
			open = math.max(open, 1) * (1 + 0.25 * anger) -- (wide open with anger)
		end
		open *= 1 - 0.85 * v("squint", 0) -- (flinching shut: the Fleet Strike's beam)
		local look = Vector3.zero
		if hrp then
			local lp = pivot:PointToObjectSpace(hrp.Position)
			look = Vector3.new(math.clamp(lp.X / 120, -1, 1) * 0.9, math.clamp(lp.Y / 120, -1, 0.3) * 0.5, 0)
		end
		for eye, e in pairs(st.eyes) do
			if eye.Parent then
				local drift = Vector3.new(math.sin(c * 0.21) * 0.8, math.sin(c * 0.17 + 1) * 0.6, 0)
				eye.CFrame = e.base + pivot:VectorToWorldSpace(look + drift)
				eye.Size = Vector3.new(e.size.X, math.max(0.05, e.size.Y * open), e.size.Z)
				eye.Color = e.color:Lerp(EYE_ANGRY, anger):Lerp(EYE_DEAD, dark)
				eye.Transparency = math.clamp((dark - 0.6) / 0.4, 0, 1) -- (out: black slits would show against the sky)
			end
		end
	end
end)

-- the camera shake (only for the keeper's own player), after the camera scripts have placed the camera this frame
RunService:BindToRenderStep("KeeperShake", Enum.RenderPriority.Camera.Value + 1, function()
	local now = os.clock()
	if now < shakeUntil then
		local cam = workspace.CurrentCamera
		local a = shakePower * ((shakeUntil - now) / shakeLength) ^ 2
		cam.CFrame = cam.CFrame * CFrame.new((math.random() - 0.5) * a, (math.random() - 0.5) * a, 0)
	else
		shakePower = 0
	end
end)

return {}
