-- Animation of the realm titans (models tagged "RealmTitan", placed by the server module Titans; rig built by
-- tools/studio/build_titan_gravekeeper.lua). Every frame each joint's Motor6D.Transform gets an offset on top of the
-- pose baked into its C0/C1 (the baked pose has the left hand raised: that is the WEAVE pose).
-- He is HUGE, so everything is slow and heavy: small slow idle motion, long anticipation, and overlapping action (the
-- torso leads, shoulders, elbows and wrists follow later: JOINT_LAG), a lantern that keeps swinging after the impact.
--   Idle       both hands rest on the outer wall, slow breathing, the head turns towards the wall the army is fighting
--              (model attribute Focus), the lantern sways, a finger twitches now and then
--   Summon     when a wall breaks the server sets SummonAt (server time) and SummonKind on the model:
--              "SlamWeave": he gathers himself (leans back, raises both hands), slams them onto the battlements
--              (stone chunks, dust, a tremor runs down his lane and stuns the army: the server's Army / the client
--              StunFx), rebounds and settles breathing hard, then slowly raises his left hand and weaves the next wall
--              with glowing threads while it rises, and lowers the hand again.
--              "Slam": the gate fell, only the slam.
--   Timing constants mirror the server's Walls.lua (TITAN_*).
-- Only the titan's own player feels the camera shake. Purely cosmetic and client side; every client derives the same
-- timeline from the synced server clock.
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local HEAD_TURN_SPEED = 0.35
local MAX_YAW, MAX_PITCH = math.rad(40), math.rad(25)
local IMPACT_HIT = 3.1 -- seconds into the summon when the hands hit the wall (Walls.TITAN_IMPACT)
local WEAVE_FROM, WEAVE_TO = 5.6, 8.8 -- the weave: the wall rises from 5.6 s for 3.2 s (Walls.TITAN_WEAVE_RISE / RISE_TIME)
local TREMOR_SPEED = 140 -- studs per second (Walls.TREMOR_SPEED)
local THREAD_CORE = ColorSequence.new(Color3.fromRGB(190, 255, 215), Color3.fromRGB(120, 255, 170))
local THREAD_GLOW = ColorSequence.new(Color3.fromRGB(40, 255, 130), Color3.fromRGB(20, 210, 110))
local CRACK_COLOR = Color3.fromRGB(80, 255, 160)
local STONE = Color3.fromRGB(108, 112, 138) -- the outer wall's stone
local DUST = Color3.fromRGB(120, 112, 100)
local EYE_ANGRY = Color3.fromRGB(255, 40, 25) -- his eyes burn red from the gathering until a while after the slam

-- the overlapping action: each joint follows the timeline this many seconds late (the torso leads, the head and the
-- arms trail). The joints of one arm share their lag: staggered inside an arm, the shoulder would come down while the
-- elbow is still raised and drive the hand into the wall.
local JOINT_LAG = { Waist = 0, Neck = 0.15, RShoulder = 0.35, RElbow = 0.35, LShoulder = 0.35, LElbow = 0.35, LWrist = 0.35 }

-- ============================================================
-- Key poses: a rotation (CFrame) per joint, applied as its Transform; missing = the baked pose. IDLE and SLAM are built
-- per titan (makePoses): the left hand rests on the battlements, its elbow hidden behind the wall.
-- ============================================================
local ID = CFrame.new()
local function pitch(a)
	return CFrame.Angles(a, 0, 0)
end
local GATHER = { Waist = pitch(0.18), Neck = pitch(0.35), RShoulder = pitch(1.0), RElbow = pitch(0.6), LShoulder = pitch(0.4), LElbow = pitch(0.35), LWrist = pitch(0.35) }
local WEAVE = { Neck = pitch(-0.05) }

-- the resting left arm in design units (1/scale of the model, feet at the origin, front -Z; see
-- build_titan_gravekeeper.lua): the elbow behind the outer wall below its top, the wrist just over the battlements
local L_ELBOW_REST = Vector3.new(-3.2, 8.0, -1.0)
local L_WRIST_REST = Vector3.new(-3.4, 9.1, -4.1)

-- { t, pose name, ease }: ease "in" = accelerating into this key (the fall of the slam), else smooth.
-- (the hands arrive JOINT_LAG later than the key times: the slam key at 2.75 s hits at IMPACT_HIT)
local TIMELINES = {
	SlamWeave = {
		{ 0, "IDLE" }, { 2.2, "GATHER" }, { 2.75, "SLAM", "in" }, { 3.15, "SLAM_DEEP" }, { 3.85, "SLAM" },
		{ 4.4, "SLAM" }, { 5.3, "WEAVE" }, { 8.3, "WEAVE" }, { 9.8, "IDLE" },
	},
	Slam = { { 0, "IDLE" }, { 2.2, "GATHER" }, { 2.75, "SLAM", "in" }, { 3.15, "SLAM_DEEP" }, { 3.85, "SLAM" }, { 4.6, "SLAM" }, { 5.6, "IDLE" } },
}

local function smooth(x)
	return x * x * (3 - 2 * x)
end

-- the rotation that turns direction `a` onto direction `b` (the shortest way)
local function rotateOnto(a, b)
	a, b = a.Unit, b.Unit
	local axis = a:Cross(b)
	if axis.Magnitude < 1e-4 then
		return ID
	end
	return CFrame.fromAxisAngle(axis.Unit, math.acos(math.clamp(a:Dot(b), -1, 1)))
end

-- builds the poses of one titan (computed once from the rig in its rest pose, before any Transform is set)
local function makePoses(t)
	local j = t.joints
	local sh, el, wr = j.LShoulder, j.LElbow, j.LWrist
	local root = t.parts.HumanoidRootPart
	if not (sh and el and wr and root and sh.Part0 and el.Part0 and wr.Part0) then
		return nil
	end
	local pivot = t.model:GetPivot()
	local scale = (root.Position - pivot.Position).Magnitude / 8 -- the hips stand 8 design units above the feet
	local elbowWant = pivot:PointToWorldSpace(L_ELBOW_REST * scale)
	local wristWant = pivot:PointToWorldSpace(L_WRIST_REST * scale)
	local Js = sh.Part0.CFrame * sh.C0
	local Je = el.Part0.CFrame * el.C0
	local Jw = wr.Part0.CFrame * wr.C0
	local shoulderT = rotateOnto(Js:VectorToObjectSpace(Je.Position - Js.Position), Js:VectorToObjectSpace(elbowWant - Js.Position))
	local Je2 = (Js * shoulderT * Js:Inverse()) * Je -- the elbow's frame after the shoulder turned
	local elbowT = rotateOnto(Je:VectorToObjectSpace(Jw.Position - Je.Position), Je2:VectorToObjectSpace(wristWant - Je2.Position))
	local restL = { LShoulder = shoulderT, LElbow = elbowT, LWrist = pitch(-0.6) }
	local function with(extra)
		local out = table.clone(restL)
		for k, v in pairs(extra) do
			out[k] = v
		end
		return out
	end
	t.poses = {
		IDLE = restL,
		GATHER = GATHER,
		WEAVE = WEAVE,
		-- the slam ends with both hands on the wall, the body pressed forward; SLAM_DEEP is the overshoot after the hit
		SLAM = with({ Waist = pitch(-0.08), Neck = pitch(-0.1), RShoulder = pitch(-0.05) }),
		SLAM_DEEP = with({ Waist = pitch(-0.11), Neck = pitch(-0.18), RShoulder = pitch(-0.07) }),
	}
	return t.poses
end

-- the rotation of joint `name` at `t` seconds into a timeline (nil outside it)
local function sampleJoint(poses, timeline, t, name)
	if t < 0 or t > timeline[#timeline][1] then
		return nil
	end
	for i = 2, #timeline do
		local a, b = timeline[i - 1], timeline[i]
		if t <= b[1] then
			local f = (t - a[1]) / math.max(1e-3, b[1] - a[1])
			f = b[3] == "in" and f * f * f or smooth(f)
			return (poses[a[2]][name] or ID):Lerp(poses[b[2]][name] or ID, f)
		end
	end
	return nil
end

-- 0..1: how much the weave is on at `t`
local function weaveWeight(kind, t)
	if kind ~= "SlamWeave" then
		return 0
	end
	local from, to = WEAVE_FROM - 0.6, WEAVE_TO + 0.6
	if t < from or t > to then
		return 0
	end
	return math.clamp(math.min((t - from) / 0.8, (to - t) / 0.8), 0, 1)
end

-- ============================================================
-- Titans
-- ============================================================
local titans = {} -- [model] = state

local function register(model)
	if titans[model] then return end
	local t = { model = model, joints = {}, parts = {}, eyes = {}, yaw = 0, pitch = 0, phase = math.random() * 100 }
	local function add(d)
		if d:IsA("Motor6D") then
			t.joints[d.Name] = d
		elseif d:IsA("BasePart") then
			t.parts[d.Name] = d
			if d.Name == "Eye" then
				table.insert(t.eyes, { part = d, calm = d.Color })
			end
		end
	end
	for _, d in ipairs(model:GetDescendants()) do
		add(d)
	end
	model.DescendantAdded:Connect(add)
	titans[model] = t
end

for _, m in ipairs(CollectionService:GetTagged("RealmTitan")) do
	register(m)
end
CollectionService:GetInstanceAddedSignal("RealmTitan"):Connect(register)
CollectionService:GetInstanceRemovedSignal("RealmTitan"):Connect(function(m)
	local t = titans[m]
	if t and t.threadFolder then
		t.threadFolder:Destroy()
	end
	titans[m] = nil
end)

local function set(j, cf)
	if j then
		j.Transform = cf
	end
end

local function aimHead(t, dt)
	local neck = t.joints.Neck
	local focus = t.model:GetAttribute("Focus")
	if not (neck and neck.Part0 and focus) then
		return CFrame.new()
	end
	local rest = neck.Part0.CFrame * neck.C0
	local dir = rest:VectorToObjectSpace(focus - rest.Position)
	local wantYaw = math.clamp(math.atan2(-dir.X, -dir.Z), -MAX_YAW, MAX_YAW)
	local wantPitch = math.clamp(math.atan2(dir.Y, math.sqrt(dir.X * dir.X + dir.Z * dir.Z)), -MAX_PITCH, MAX_PITCH)
	local k = 1 - math.exp(-HEAD_TURN_SPEED * dt)
	t.yaw += (wantYaw - t.yaw) * k
	t.pitch += (wantPitch - t.pitch) * k
	return CFrame.Angles(0, t.yaw, 0) * CFrame.Angles(t.pitch, 0, 0)
end

-- ============================================================
-- Effects: dust, the impact on the outer wall, the tremor down the lane
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

-- the tremor: a crack of soul light runs down the lane from its end at the outer wall towards the plot, dust bursting
-- up behind it (attributes LaneEnd / LaneBack / LaneLength set by the server's Titans)
local function tremor(t)
	local laneEnd = t.model:GetAttribute("LaneEnd")
	local back = t.model:GetAttribute("LaneBack")
	local length = t.model:GetAttribute("LaneLength") or 280
	if not (laneEnd and back) then return end
	local right = back:Cross(Vector3.yAxis).Unit
	local y = laneEnd.Y + 0.25
	task.spawn(function()
		local d, lat = 0, 0
		local step = 6
		while d < length and t.model.Parent do
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

local function impact(t)
	for _, name in ipairs({ "RHand", "LHand" }) do
		local hand = t.parts[name]
		if hand then
			local pos = hand.Position
			dust(pos, 30, 10, 24)
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
	if t.model:GetAttribute("SummonKind") == "SlamWeave" then
		tremor(t)
	end
	-- only the titan's own player feels it (with 8 players the shakes would never stop)
	if t.model:GetAttribute("OwnerId") == Players.LocalPlayer.UserId then
		shake(1.1, 1.6)
	end
end

-- ============================================================
-- The weave's threads: one glowing beam from each left fingertip to the rising wall
-- ============================================================
local function threads(t)
	if t.threadFolder then
		return t.threads
	end
	local folder = Instance.new("Folder")
	folder.Name = "TitanThreads"
	folder.Parent = workspace
	t.threadFolder = folder
	t.threads = {}
	for k = 1, 4 do
		local tip = t.parts["LFinger" .. k .. "Tip"]
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
			-- a wide glowing sheath with light flowing along it, and a thin bright core
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
			table.insert(t.threads, { beam = beam, glow = glow, anchor = anchor, sparks = sparks, k = k })
		end
	end
	return t.threads
end

local function updateThreads(t, weight, ta)
	if weight <= 0 and not t.threadFolder then
		return
	end
	local list = threads(t)
	local focus = t.model:GetAttribute("Focus")
	local right = t.model:GetPivot().RightVector
	local rise = math.clamp((ta - WEAVE_FROM) / (WEAVE_TO - WEAVE_FROM), 0, 1)
	for _, th in ipairs(list) do
		local flicker = 0.06 * math.sin(os.clock() * 5 + th.k)
		th.beam.Transparency = NumberSequence.new(math.clamp(1 - weight * (0.95 + flicker), 0, 1))
		th.glow.Transparency = NumberSequence.new(math.clamp(1 - weight * (0.55 + flicker), 0, 1))
		th.sparks.Rate = weight > 0.5 and 30 or 0
		if focus then
			-- the threads end on the rising wall, spread across it, climbing with it
			th.anchor.Position = focus + right * ((th.k - 2.5) * 9) + Vector3.new(0, -10 + rise * 18 + math.sin(os.clock() * 1.6 + th.k) * 1.5, 0)
		end
	end
end

-- ============================================================
-- Every frame
-- ============================================================
RunService.RenderStepped:Connect(function(dt)
	local now = os.clock()
	local serverNow = workspace:GetServerTimeNow()
	for model, t in pairs(titans) do
		if not model.Parent then
			if t.threadFolder then
				t.threadFolder:Destroy()
			end
			titans[model] = nil
			continue
		end
		local poses = t.poses or makePoses(t)
		if not poses then
			continue -- the rig has not fully streamed in yet
		end
		local j = t.joints
		local c = now + t.phase
		local summonAt = model:GetAttribute("SummonAt")
		local kind = model:GetAttribute("SummonKind")
		local ta = summonAt and (serverNow - summonAt) or math.huge
		local timeline = TIMELINES[kind or ""]
		local acting = timeline ~= nil and ta >= 0 and ta <= timeline[#timeline][1] + 0.6
		local weave = weaveWeight(kind, ta)
		if acting and ta >= IMPACT_HIT and ta < IMPACT_HIT + 1 and t.impactDone ~= summonAt then
			t.impactDone = summonAt
			impact(t)
		end
		-- after the impact he breathes hard for a while; the lantern keeps swinging from the blow
		local sinceHit = (acting and ta >= IMPACT_HIT) and (ta - IMPACT_HIT) or math.huge
		local heave = sinceHit < 6 and math.exp(-sinceHit / 2.5) or 0
		local calm = acting and 0.4 or 1

		local function p(name)
			if acting then
				return sampleJoint(poses, timeline, ta - (JOINT_LAG[name] or 0), name) or poses.IDLE[name] or ID
			end
			return poses.IDLE[name] or ID
		end

		-- body: slow breathing (heavier right after the slam), a very slow sway
		local breath = math.sin(c * 0.3)
		local hardBreath = math.sin(c * 1.4) * heave
		set(j.Waist, p("Waist") * CFrame.Angles(math.rad(breath * 1.4 * calm + hardBreath * 2.5), math.rad(math.sin(c * 0.12) * 2) * calm, math.rad(math.sin(c * 0.17) * 1) * calm))
		set(j.Neck, aimHead(t, dt) * p("Neck") * CFrame.Angles(math.rad(math.sin(c * 0.21) * 1.5), math.rad(math.sin(c * 0.15) * 2.5), 0))
		local swing = 1 + heave * 2.5
		set(j.Lantern, CFrame.Angles(math.rad(math.sin(c * 0.7) * 5 * swing), 0, math.rad(math.sin(c * 0.52 + 1) * 3.5 * swing)))

		-- arms (the weave adds a slow drift to the raised arm)
		set(j.RShoulder, p("RShoulder") * pitch(math.rad(breath * 1 + hardBreath * 1.5)))
		set(j.RElbow, p("RElbow"))
		set(j.LShoulder, p("LShoulder") * CFrame.Angles(math.rad(math.sin(c * 0.25) * 3) * weave, math.rad(math.sin(c * 0.18) * 3) * weave, 0))
		set(j.LElbow, p("LElbow") * pitch(math.rad(math.sin(c * 0.3 + 1) * 4) * weave))
		set(j.LWrist, p("LWrist") * CFrame.Angles(math.rad(math.sin(c * 1.1) * 12) * weave, math.rad(math.cos(c * 1.1) * 8) * weave, 0))

		-- fingers: weaving = a slow wave through the left fingers; resting = a slow twitch now and then; the slam clenches
		local clench = (acting and ta >= IMPACT_HIT - 0.3 and ta < IMPACT_HIT + 1.4) and 1 or 0
		for k = 1, 4 do
			local wave = math.sin(c * 2.2 - k * 0.8)
			local twitchL = math.max(0, math.sin(c * 0.16 + k * 2.3)) ^ 10
			local twitchR = math.max(0, math.sin(c * 0.19 + k * 1.9)) ^ 10
			local lCurl = weave * (wave * 26 + 10) + (1 - weave) * (-twitchL * 16) + clench * 35
			set(j["LFinger" .. k .. "a"], CFrame.Angles(math.rad(lCurl), math.rad(math.sin(c * 0.7 + k) * 7) * weave, 0))
			set(j["LFinger" .. k .. "b"], CFrame.Angles(math.rad(weave * (wave * 28 + 12) + clench * 30), 0, 0))
			set(j["RFinger" .. k .. "a"], CFrame.Angles(math.rad(-twitchR * 16 + clench * 30), 0, 0))
		end
		set(j.LThumba, CFrame.Angles(math.rad(math.sin(c * 2.2 + 1) * 16) * weave, 0, 0))

		updateThreads(t, weave, ta)

		-- anger: the eyes turn red while he gathers himself, burn through the slam and cool down before the weave
		local anger = 0
		if acting then
			anger = math.clamp(math.min((ta - 0.3) / 1.2, (IMPACT_HIT + 2.8 - ta) / 1.2), 0, 1)
		end
		for _, eye in ipairs(t.eyes) do
			eye.part.Color = eye.calm:Lerp(EYE_ANGRY, anger)
		end
	end
end)

-- the camera shake (only for the titan's own player), after the camera scripts have placed the camera this frame
RunService:BindToRenderStep("TitanShake", Enum.RenderPriority.Camera.Value + 1, function()
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
