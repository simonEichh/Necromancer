-- Procedural animation for rigged units (models tagged "ProceduralUnit").
--
-- The server only sets attributes on the model:
--   State = "walk" | "idle"  (idle = standing and attacking)
--   AttackCount             (incremented on every attack; the swing plays on each change)
--   Speed, AttackCD         (walk speed in studs/s, seconds between attacks)
-- and optionally, set once on the model: Float (hover bob amplitude in studs, for floating units)
-- Optional joints besides the humanoid ones: LWing/RWing (flapping wings, positive Z rotation raises the right wing)
-- and RStaff (the staff in the right hand, so a caster can point it forward; see AttackStyle below).
-- Optional joints named Spin... turn continuously around Y (rings, wheels): the Motor6D's attribute SpinSpeed is the speed in rad/s.
-- Optional model attributes RiseStart (server time) and RiseTime (seconds): the model rises out of the ground, used for towers.
-- Optional model attribute AttackStyle = "StaffCast": at the wall the unit holds its staff out in front of it for as
-- long as it keeps attacking (a stance, not a per-attack swing) and SpellEffects streams projectiles from a circle.
-- Every client animates the model's Motor6D joints locally each frame, so nothing is sent over the
-- network per frame and no uploaded Animation assets are needed.
--
-- Rig conventions: front = -Z, right = +X, joints have identity rest rotation (set Motor6D.Transform).
-- A positive X rotation swings a limb forward.
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local TAG = "ProceduralUnit"
local rigs = {} -- [model] = state table

local function clamp01(x)
	return math.clamp(x, 0, 1)
end

local function register(model)
	if rigs[model] then
		return
	end
	local joints = {}
	local spinners = {} -- joints named Spin...: they turn around Y all the time
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("Motor6D") then
			joints[d.Name] = d
			if d.Name:sub(1, 4) == "Spin" then
				table.insert(spinners, { joint = d, speed = d:GetAttribute("SpinSpeed") or 1 })
			end
		end
	end
	-- with StreamingEnabled a model placed in the world can arrive before its parts and joints: pick those up later
	model.DescendantAdded:Connect(function(d)
		if d:IsA("Motor6D") then
			joints[d.Name] = d
			if d.Name:sub(1, 4) == "Spin" then
				table.insert(spinners, { joint = d, speed = d:GetAttribute("SpinSpeed") or 1 })
			end
		end
	end)
	rigs[model] = {
		joints = joints,
		spinners = spinners,
		phase = math.random() * math.pi * 2,
		walk = 1, -- 0..1 blend between standing and walking
		attackStart = nil,
		lastCount = model:GetAttribute("AttackCount") or 0,
		cast = 0, -- 0..1 blend into the staff-cast stance
		t0 = math.random() * 10,
	}
end

local function set(rig, name, cf)
	local joint = rig.joints[name]
	if joint then
		joint.Transform = cf
	end
end

local ANGLES = CFrame.Angles

-- Swing of the right arm: wind up overhead, strike down, recover. u runs 0..1.
local function attackPose(u)
	if u < 0.35 then
		local a = 1 - (1 - u / 0.35) ^ 2 -- ease out
		return 0.2 + 2.3 * a, 0.5 + 0.4 * a, 0.35 * a, 0.5 * a
	elseif u < 0.6 then
		local k = (u - 0.35) / 0.25
		return 2.5 - 2.1 * k * k, 0.9 - 0.7 * k, 0.35 - 0.8 * k, 0.5 - 0.4 * k -- fast strike, lean forward
	end
	local k = (u - 0.6) / 0.4
	return 0.4 * (1 - k), 0.2 + 0.3 * k, -0.45 * (1 - k), 0.1 * (1 - k)
end

local function attackDuration(model)
	-- units with a longer, scripted attack (e.g. Hush's finger beam) set AttackAnim on the model
	return model:GetAttribute("AttackAnim") or math.min(0.55, (model:GetAttribute("AttackCD") or 1) * 0.85)
end

-- Staff cast stance (AttackStyle = "StaffCast"): while the unit stands at the wall and keeps attacking it holds
-- the staff out in front of it (the left arm gestures) instead of swinging once per attack. k is the blend into
-- the stance (0 = relaxed, 1 = staff held out), t is a time value for the small hovering motion of the held staff.
-- Returns rShoulder, rElbow, lShoulder, lElbow and waist pitch. SpellEffects draws the circle and the projectiles.
local function castPose(k, t)
	local sway = math.sin(t * 5) * 0.03 * k
	return 1.35 * k + sway, 0.35 * k, 0.9 * k, 0.9 * k, 0.12 * k + sway * 0.5
end

-- A staff caster is "in attack mode" while the server says it is firing a barrage (model attribute Barrage, set by Army
-- when the unit stands in its slot and cleared when it stops attacking or walks again).
local function isCasting(model)
	local style = model:GetAttribute("AttackStyle")
	return (style == "StaffCast" or style == "SigilCast")
		and model:GetAttribute("Barrage") == true
		and model:GetAttribute("State") ~= "walk"
end

-- Catmull-Rom through keyframes { t, v1, v2, ... } (channel c: 2 = v1): the curve keeps its speed through every key,
-- so a motion flows on instead of easing to a stop at each pose (momentum)
local function sampleKeys(keys, a, c)
	local n = #keys
	if a <= keys[1][1] then
		return keys[1][c]
	end
	if a >= keys[n][1] then
		return keys[n][c]
	end
	for i = 1, n - 1 do
		local k1, k2 = keys[i], keys[i + 1]
		if a <= k2[1] then
			local f = (a - k1[1]) / (k2[1] - k1[1])
			local p0 = (keys[i - 1] or k1)[c]
			local p1, p2 = k1[c], k2[c]
			local p3 = (keys[i + 2] or k2)[c]
			return 0.5 * ((2 * p1) + (-p0 + p2) * f + (2 * p0 - 5 * p1 + 4 * p2 - p3) * f * f + (-p0 + 3 * p1 - 3 * p2 + p3) * f * f * f)
		end
	end
	return keys[n][c]
end

-- one damped-spring step (in small substeps, so stiff springs stay stable at low frame rates): new value, velocity
local function springStep(x, v, target, stiffness, damping, dt)
	dt = math.min(dt, 0.1)
	local steps = math.max(1, math.ceil(dt / 0.008))
	local h = dt / steps
	for _ = 1, steps do
		v += ((target - x) * stiffness - v * damping) * h
		x += v * h
	end
	return x, v
end

-- AttackStyle "Strike" (a one-handed sword chop, Skelly; see the Strike block in animate). One attack cycle, keys
-- { t, right shoulder pitch, right shoulder roll (+ = out), right elbow, wrist (+ = blade up), left shoulder pitch,
-- left shoulder roll (+ = in), left elbow, waist pitch (- = lean in), waist yaw (+ = chest turns left), lift, forward
-- (- = towards the wall) }. It starts and ends in the guard, so attack after attack is one unbroken motion.
-- The blade meets the wall at ~0.38 s: the unit def's hitDelay (0.4, Units.lua) lands the WallHit then.
local STRIKE_GUARD = { 0.55, 0.35, 1.45, 0.45, 0.45, -0.15, 0.7, -0.08, -0.25, -0.12, 0 }
local STRIKE = {
	{ 0.00, table.unpack(STRIKE_GUARD) }, -- high guard: the sword up at the right shoulder
	{ 0.24, 2.7, 0.5, 1.1, 0.5, 1.0, -0.1, 0.25, 0.12, -0.55, -0.02, 0.12 }, -- anticipation: coiled back, the left hand points
	{ 0.31, 2.9, 0.55, 1.15, 0.75, 1.05, -0.1, 0.2, 0.14, -0.62, 0.0, 0.14 }, -- the coil still tightens as the blow starts
	{ 0.38, 1.25, -0.15, 0.1, -0.35, -0.25, -0.2, 0.6, -0.3, 0.4, -0.3, -0.25 }, -- contact: arm straight, body thrown in
	{ 0.58, 0.35, -0.55, 0.35, -0.6, -0.35, -0.25, 0.7, -0.36, 0.6, -0.32, -0.28 }, -- follow-through past the left hip
	{ 0.74, 0.25, -0.5, 0.6, -0.3, -0.1, -0.2, 0.75, -0.28, 0.45, -0.26, -0.2 }, -- momentum spent
	{ 0.94, 0.3, 0.1, 1.2, 0.2, 0.25, -0.15, 0.7, -0.14, -0.05, -0.16, -0.08 }, -- the blade loops up the right side
	{ 1.12, table.unpack(STRIKE_GUARD) },
}

-- AttackStyle "Pounce" (the crawling Ghoul, Pose "Crawler"; see the Crawler block in animate). Keys { t, lift, forward
-- (- = towards the wall), body pitch (+ = front up), spine, neck pitch (+ = head up), jaw, front shoulder (+ = arm
-- forward / up), front elbow, wrist extra (+ = claws up, - = hooked down; the hand is kept level otherwise), hind hip,
-- hind knee, ankle extra }. Like a cat: crouch and coil back, leap (the hind legs push off, the arms fly up), rake down
-- with both claws at the top of the leap (contact ~0.46 s: the unit def's hitDelay 0.48 lands the WallHit then), land
-- in a crouch, hop back into the stalking crouch. Starts and ends in that crouch.
local POUNCE_READY = { -0.2, 0, -0.05, 0.05, 0.2, 0.15, 0, 0.15, 0, 0.3, -0.55, 0 }
local POUNCE = {
	{ 0.00, table.unpack(POUNCE_READY) },
	{ 0.22, -0.45, 0.35, -0.15, 0.12, 0.35, 0.1, -0.25, 0.35, 0, 0.65, -1.0, 0 }, -- coiled: low, weight back
	{ 0.30, 0.45, -0.8, 0.35, 0.25, -0.05, 0.6, 1.5, -0.1, 0.6, -0.5, 0.25, -0.4 }, -- launch: the hind legs push off
	{ 0.40, 1.0, -2.0, 0.5, 0.1, -0.25, 0.75, 2.2, 0.15, 0.8, -0.55, 0.1, -0.4 }, -- the top: claws high, jaws wide
	{ 0.46, 0.5, -3.0, 0.05, -0.25, -0.1, 0.35, 0.35, 0.1, -0.9, 0.45, -0.6, 0.2 }, -- the rake: both claws slam down
	{ 0.62, -0.2, -2.8, -0.2, -0.15, 0.3, 0.2, -0.1, 0.6, 0, 0.55, -0.95, 0 }, -- landed, crouched under the wall
	{ 0.84, 0.3, -1.3, 0.08, 0.05, 0.2, 0.05, 0.45, 0.45, 0.2, -0.1, -0.3, 0 }, -- the hop back
	{ 1.05, table.unpack(POUNCE_READY) },
}

-- How far a unit can lunge before it would go into the wall: the distance from `origin` along `dir` to the first
-- anchored, visible part (the wall's real, bumpy surface; the units in the way are unanchored), or nil.
local wallRayParams = RaycastParams.new()
wallRayParams.FilterType = Enum.RaycastFilterType.Exclude
local function distanceAhead(origin, dir, maxDist)
	local ignore = {}
	for _ = 1, 6 do
		wallRayParams.FilterDescendantsInstances = ignore
		local hit = workspace:Raycast(origin, dir * maxDist, wallRayParams)
		if not hit then
			return nil
		end
		if hit.Instance.Anchored and hit.Instance.Transparency < 1 then
			return hit.Distance
		end
		table.insert(ignore, hit.Instance)
	end
	return nil
end

-- AttackStyle "Slam" (the Zombie, a lopsided brute with a huge RIGHT club arm; see the Slam block in animate). Keys
-- { t, right shoulder pitch, right shoulder roll (+ = out), right elbow, left shoulder pitch, left shoulder roll (+ = in),
-- left elbow, waist pitch (- = lean in), waist yaw (+ = chest turns left), lift, forward (a fraction of the lunge
-- measured to the wall: -1 = the full lunge) }. A slow, heavy overhead wind-up (the club rises, the body leans back
-- and twists, the withered arm reaches forward as a counterweight), a hold with the coil still tightening, the drop
-- (the whole body falls in after the club), contact at ~0.80 s (the unit def's hitDelay 0.82 lands the WallHit then)
-- and a short freeze on the impact (two near-equal keys = a hit-stop), bent into the wall, a lurch back into the
-- ready stance. The club's pendulum follow-through comes from its soft spring (see the block).
local SLAM_READY = { 0.2, 0.1, 0.25, 0.1, 0, 0.4, -0.25, -0.1, -0.1, 0 }
local SLAM = {
	{ 0.00, table.unpack(SLAM_READY) },
	{ 0.35, 1.6, 0.35, 0.6, -0.1, -0.2, 0.5, 0.0, -0.35, 0.0, 0.15 }, -- the club starts to rise, weight back
	{ 0.62, 3.0, 0.25, 0.5, 0.5, 0, 0.3, 0.22, -0.3, 0.12, 0.2 }, -- overhead, leaning back
	{ 0.70, 3.15, 0.2, 0.55, 0.6, 0, 0.25, 0.26, -0.32, 0.14, 0.22 }, -- the coil still tightens
	{ 0.80, 1.35, -0.05, 0.05, -0.4, -0.15, 0.6, -0.6, 0.15, -0.45, -1 }, -- IMPACT
	{ 0.88, 1.3, -0.05, 0.08, -0.38, -0.15, 0.62, -0.62, 0.16, -0.48, -1 }, -- (hit-stop)
	{ 1.05, 1.0, -0.05, 0.15, -0.35, -0.15, 0.65, -0.62, 0.18, -0.5, -1 }, -- bent into the wall
	{ 1.4, 0.35, 0.1, 0.35, 0.05, 0, 0.45, -0.2, -0.15, -0.05, -0.1 }, -- lurches back
	{ 1.8, table.unpack(SLAM_READY) },
}

-- Two-bone IK for an arm whose rest pose hangs straight down (-Y) from the shoulder, with an elbow that bends towards
-- -Z on +X (the procedural rigs). Positions are in the parent's build space (the torso before any animation): the
-- shoulder joint, the wrist target and a pole direction the elbow should point to. Returns the shoulder's Transform
-- and the elbow angle (out of reach = straight arm towards the target).
local function armIK(shoulder, target, upperLen, lowerLen, pole)
	local toTarget = target - shoulder
	local dist = math.clamp(toTarget.Magnitude, 0.05, upperLen + lowerLen - 0.001)
	local d = toTarget.Magnitude > 1e-4 and toTarget.Unit or Vector3.new(0, -1, 0)
	local a = math.acos(math.clamp((upperLen * upperLen + dist * dist - lowerLen * lowerLen) / (2 * upperLen * dist), -1, 1))
	local bend = math.pi - math.acos(math.clamp((upperLen * upperLen + lowerLen * lowerLen - dist * dist) / (2 * upperLen * lowerLen), -1, 1))
	local poleDir = pole - d * pole:Dot(d)
	if poleDir.Magnitude < 1e-3 then
		poleDir = Vector3.new(0, 0, 1) - d * d.Z
	end
	poleDir = poleDir.Unit
	local upper = (d * math.cos(a) + poleDir * math.sin(a)).Unit
	local elbow = shoulder + upper * upperLen
	local fore = (shoulder + d * dist) - elbow
	local bendDir = fore - upper * fore:Dot(upper)
	bendDir = bendDir.Magnitude > 1e-4 and bendDir.Unit or -poleDir
	-- the shoulder turns the arm's local -Y onto the upper arm and its local -Z onto the bend direction
	local yAxis, zAxis = -upper, -bendDir
	return CFrame.fromMatrix(Vector3.zero, yAxis:Cross(zAxis), yAxis, zAxis), bend
end

-- The Hollow Archer (AttackStyle "Bow", build_hollowarcher.lua; these numbers must match the build): shoulders, arm
-- lengths, the hand centre's drop below the wrist, the bow's brace (string 0.34 behind the grip) and its full draw.
-- The bow hand (GRIP, in the model's space) is held out so the arrow line passes the right cheek; the string hand is always derived from the string's nock point
-- (grip + brace + draw), so the hand and the string stay together. RELEASE = Units.HollowArcher.releaseAt.
local ARCHER = {
	lShoulder = Vector3.new(-0.6, 3.85, 0), rShoulder = Vector3.new(0.6, 3.85, 0), upper = 0.85, lower = 0.85,
	handDrop = 0.12, brace = 0.34, drawLen = 1.05,
	GRIP = Vector3.new(0.5, 3.95, -1.62), -- (the arrow line runs past the right cheek: the anchor point)
	RELEASE = 0.55, -- (a fraction of the attack cycle, which lasts AttackCD; Units releaseAt = RELEASE x attackCD)
	QUIVER = Vector3.new(0.34, 4.35, 0.5), -- (in the torso's space: the top of the quiver over the right shoulder)
}

-- AttackStyle "Spit" (the Crypt Spider; see the Spider block). Keys over one attack cycle (0..1, stretched to AttackCD):
-- { t, body pitch (+ = front up), lift, forward (- = towards the wall), front legs' lift, front legs' swing, front
-- knees, middle legs' lift, hind legs' lift, fangs (+ = open), abdomen pitch }. Rear up with the front legs high (the
-- threat display), hold while the venom gathers, drop forward and spit at 0.5, settle.
local SPIT_KEYS = {
	{ 0.00, 0, 0, 0, 0, 0, 0, 0.05, 0, 0.05, 0 },
	{ 0.30, 0.45, 0.35, 0.15, 0.95, 0.35, 0.4, 0.25, -0.2, 0.4, -0.25 },
	{ 0.42, 0.5, 0.38, 0.16, 1.0, 0.38, 0.42, 0.27, -0.22, 0.45, -0.28 },
	{ 0.50, -0.2, 0.0, -0.35, 0.3, 0.1, 0.1, 0, 0.1, 0.65, 0.15 },
	{ 0.62, -0.05, -0.05, -0.15, 0.1, 0.02, 0.02, 0, 0.02, 0.15, 0.05 },
	{ 1.00, 0, 0, 0, 0, 0, 0, 0.05, 0, 0.05, 0 },
}

-- AttackStyle "Dive" (the Crypt Bat; see the Bat block). Keys over one attack cycle (0..1, stretched to AttackCD):
-- { t, rise, forward (a fraction of the lunge measured to the wall: -1 = at the wall), pitch (+ = nose up), wing beat
-- amplitude, wing fold (0 spread .. 1 folded back), hind feet forward (the rake), jaw }. It climbs with strong beats,
-- tips over and folds its wings, dives at the wall, flares open and rakes with its feet while it screeches (contact at
-- 0.55: the unit def's hitDelay = 0.55 x attackCD), pulls up and flaps back to its hover spot.
local DIVE_KEYS = {
	{ 0.00, 0, 0, 0, 1, 0, 0, 0.05 },
	{ 0.25, 1.2, 0.08, 0.35, 1.4, 0, 0, 0.05 },
	{ 0.36, 1.5, 0.1, -0.7, 0, 1, 0, 0.1 },
	{ 0.50, -0.2, -0.9, -0.9, 0, 1, 0.3, 0.3 },
	{ 0.55, -0.3, -1, 0.6, 0.3, 0.25, 1.3, 0.9 },
	{ 0.62, 0.5, -0.75, 0.5, 1.3, 0, 0.4, 0.7 },
	{ 0.85, 0.2, -0.1, 0.1, 1.0, 0, 0, 0.15 },
	{ 1.00, 0, 0, 0, 1, 0, 0, 0.05 },
}

local ArrowFx = require(script.Parent.ArrowFx)
local VenomFx = require(script.Parent.VenomFx)
local Units = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Units"))

local function animate(model, rig, dt, now)
	local state = model:GetAttribute("State")
	local speed = model:GetAttribute("Speed") or 8
	local scale = model:GetScale()

	-- walk blend + stride phase
	local target = state == "walk" and 1 or 0
	rig.walk += (target - rig.walk) * clamp01(dt * 10)
	local w = rig.walk
	rig.phase += dt * (3 + speed * 0.45) * w
	local s, c = math.sin(rig.phase), math.cos(rig.phase)
	local t = now + rig.t0

	-- attack trigger
	local count = model:GetAttribute("AttackCount") or 0
	local style = model:GetAttribute("AttackStyle")
	local casterStyle = style == "StaffCast" or style == "SigilCast"
	if count ~= rig.lastCount then
		rig.lastCount = count
		rig.lastShot = now
		if not casterStyle then
			rig.attackStart = now -- (casters hold a stance while the server reports a barrage instead of swinging per attack)
		end
	end
	local attackDur = attackDuration(model)
	local u = rig.attackStart and (now - rig.attackStart) / attackDur
	if u and u >= 1 then
		rig.attackStart = nil
		u = nil
	end
	if casterStyle then
		-- blend smoothly into / out of the casting stance
		rig.cast += ((isCasting(model) and 1 or 0) - rig.cast) * clamp01(dt * 6)
	end

	-- legs
	set(rig, "LHip", ANGLES(s * 0.75 * w, 0, 0))
	set(rig, "RHip", ANGLES(-s * 0.75 * w, 0, 0))
	set(rig, "LKnee", ANGLES(-math.max(0, -c) * 0.9 * w, 0, 0))
	set(rig, "RKnee", ANGLES(-math.max(0, c) * 0.9 * w, 0, 0))

	-- body bob + sway
	local breathe = math.sin(t * 2) * 0.03
	local bob = math.abs(s) * 0.12 * w * scale
	-- floating units (attribute Float = amplitude in studs) hover up and down instead of stepping
	local float = (model:GetAttribute("Float") or 0) * math.sin(t * 2.2) * scale
	-- rising out of the ground (towers): sinks the whole model at first, eases up over RiseTime seconds, rumbling
	local rise, shake = 0, 0
	local riseStart = model:GetAttribute("RiseStart")
	if riseStart then
		local p = clamp01((workspace:GetServerTimeNow() - riseStart) / (model:GetAttribute("RiseTime") or 3))
		if p < 1 then
			rise = -(model:GetAttribute("Height") or 5) * scale * (1 - p) ^ 2.2
			shake = math.sin(now * 55) * 0.22 * (1 - p) * scale
		end
	end
	set(rig, "Root", CFrame.new(shake, bob + float + rise, shake * 0.7))
	for _, spinner in ipairs(rig.spinners) do
		spinner.joint.Transform = ANGLES(0, now * spinner.speed, 0)
	end

	-- arms (left arm swings with the right leg; the sword arm swings less)
	local idleElbow = 0.25 + 0.15 * w
	local rShoulder = s * 0.3 * w + breathe
	local rElbow = idleElbow
	local waistPitch = 0.06 * w + breathe
	local waistRoll = s * 0.07 * w
	local jaw = math.max(0, math.sin(t * 5)) * 0.06 * (1 - w)

	local lShoulder = -s * 0.6 * w - breathe
	local lElbow = idleElbow
	local staffRot = 0 -- optional RStaff joint: turns the staff in the hand so it points forward while casting

	if casterStyle then
		if rig.cast > 0.001 then
			local k = rig.cast
			local rs, re, ls, le, lean = castPose(k, t)
			if style == "SigilCast" then
				-- the right hand is lifted high (a rune circle opens above it) and the left hand gestures out to the side
				rs, re, ls, le, lean = 2.85 * k + math.sin(t * 3) * 0.04 * k, 0.15 * k, 0.5 * k, 0.5 * k, -0.08 * k
			end
			-- blend with the relaxed pose while the stance is not fully up (e.g. just after walking)
			rShoulder = rShoulder + (rs - rShoulder) * k
			rElbow = rElbow + (re - rElbow) * k
			lShoulder = lShoulder + (ls - lShoulder) * k
			lElbow = lElbow + (le - lElbow) * k
			waistPitch = waistPitch + (lean - waistPitch) * k
			-- the staff points up in the hand at rest; undo the arm rotation and pitch it to horizontal (slightly up)
			if style == "StaffCast" then
				staffRot = -(1.5708 * k + rShoulder + rElbow) + 0.15 * k
			end
		end
	elseif u and style ~= "Strike" and style ~= "Pounce" and style ~= "Slam" and style ~= "Bow" and style ~= "Spit" then
		local shoulder, elbow, lean, mouth = attackPose(u)
		rShoulder, rElbow, waistPitch, jaw = shoulder, elbow, lean, mouth
	end

	-- the Sigilwright's Verdict (VerdictFx, 13 s): it rises and holds its hand up, writing in the air (1.5..7), and
	-- on every spoken word (bolts at 9.3, 9.9, 10.35, 10.7, 11.3) jerks the hand forward at the wall; before the last
	-- word it pulls the hand far back, then thrusts it; every jerk flows back into the raised pose (no snap)
	local verdictLift = 0
	if style == "SigilCast" and model:GetAttribute("SpecialKind") == "Verdict" then
		local spAt = model:GetAttribute("SpecialAt")
		local st = spAt and workspace:GetServerTimeNow() - spAt or -1
		if st >= 0 and st < 13 then
			local function sm(x)
				x = clamp01(x)
				return x * x * (3 - 2 * x)
			end
			local vw = sm(st / 0.8) * (1 - sm((st - 12.2) / 0.8))
			local rs, re, ls, le, lean = 2.6, 0.2, 0.55, 0.6, -0.12
			if st > 1.5 and st < 7 then
				rs += math.sin(st * 7) * 0.18 + math.sin(st * 11.3) * 0.08 -- writing
				re += math.sin(st * 9) * 0.12
			end
			for i, b in ipairs({ 9.3, 9.9, 10.35, 10.7, 11.3 }) do
				local d = st - (b - 0.08)
				if d >= 0 and d < 0.7 then
					local thrust = d < 0.08 and (d / 0.08) ^ 2 or (1 - sm((d - 0.08) / 0.6))
					local big = (i == 5) and 1.4 or 1
					rs -= 1.1 * thrust * big
					re -= 0.15 * thrust
					lean += 0.12 * thrust * big
				end
			end
			rs += 0.6 * sm((st - 10.75) / 0.45) * (st < 11.22 and 1 or 0) -- the wind-up before the last word
			rShoulder = rShoulder + (rs - rShoulder) * vw
			rElbow = rElbow + (re - rElbow) * vw
			lShoulder = lShoulder + (ls - lShoulder) * vw
			lElbow = lElbow + (le - lElbow) * vw
			waistPitch = waistPitch + (lean - waistPitch) * vw
			verdictLift = 1.6 * vw
		end
	end

	set(rig, "LShoulder", ANGLES(lShoulder, 0, 0))
	set(rig, "LElbow", ANGLES(lElbow, 0, 0))
	set(rig, "RShoulder", ANGLES(rShoulder, 0, 0))
	set(rig, "RElbow", ANGLES(rElbow, 0, 0))
	set(rig, "RStaff", ANGLES(staffRot, 0, 0))
	set(rig, "Waist", ANGLES(waistPitch, 0, waistRoll))
	set(rig, "Neck", ANGLES(-0.04 * w, math.sin(t * 0.8) * 0.12 * (1 - w), 0))
	if verdictLift > 0 then
		set(rig, "Root", CFrame.new(shake, bob + float + rise + verdictLift * scale, shake * 0.7))
	end

	-- AttackStyle "Strike" (Skelly): a one-handed sword chop as ONE continuous cycle, never a reset to rest. Between
	-- attacks it stands in a high guard (sword up at the right shoulder, left foot forward, knees bent, bouncing a
	-- little); each attack coils it further back (anticipation, the coil still tightening as the blow starts), chops
	-- diagonally down across the body (contact ~0.38 s: the server's hitDelay lands the WallHit then and HitEffects
	-- draws the white slash), momentum carries the blade on past the left hip (follow-through, the body thrown in, the
	-- left arm pulling back as a counterweight) and the blade loops back up the right side into the guard (not back
	-- along the cut). The keys (STRIKE) are joined by Catmull-Rom and every channel runs through a stiff spring that
	-- absorbs jumps (an early attack, the blend in from walking). The guard eases out ~1 s after the last attack.
	-- Idle (standing, not fighting): hunched, the weight rocking from foot to foot (the feet stay planted), the sword
	-- swaying in a loose grip, the head roaming and cocking to one side on a spring (it overshoots and settles), and
	-- every ~5 s a bone-rattling shiver with a clatter of the jaw.
	if style == "Strike" then
		local sk = rig.strike
		if not sk then
			sk = { sm = {}, fight = 0, tilt = 0, tiltV = 0 }
			rig.strike = sk
		end
		local cd = model:GetAttribute("AttackCD") or 1.2
		local since = rig.lastShot and (now - rig.lastShot) or math.huge
		local fighting = state ~= "walk" and since < cd + 1.0
		sk.fight += ((fighting and 1 or 0) - sk.fight) * clamp01(dt * (fighting and 10 or 2.5))
		local fw = sk.fight * sk.fight * (3 - 2 * sk.fight) * (1 - w) -- weight of the fighting layer
		local sw = 1 - w -- weight of the standing (idle) pose over the walk
		local function mix(a, b, k)
			return a + (b - a) * k
		end

		-- idle
		local sh = math.sin(t * 0.8)
		local look = math.sin(t * 0.45) * 0.3 + math.sin(t * 1.27) * 0.06
		local cyc = (t * 0.21) % 1
		local shiver = cyc < 0.07 and math.sin(cyc / 0.07 * math.pi) or 0
		local rattle = math.sin(now * 47) * shiver
		local cockTarget = (math.floor(t * 0.21) % 2 == 0) and 0.2 or -0.06
		sk.tilt, sk.tiltV = springStep(sk.tilt, sk.tiltV, cockTarget, 70, 6, dt)

		local rS = mix(rShoulder, 0.1 + breathe + rattle * 0.05, sw)
		local rZ = mix(0, 0.1, sw)
		local rE = mix(rElbow, 0.35, sw)
		local wr = mix(-0.1, math.sin(t * 1.1) * 0.12, sw)
		local lS = mix(lShoulder, -0.02 - breathe, sw)
		local lZ = mix(0, -0.06, sw)
		local lE = mix(lElbow, 0.3 + rattle * 0.06, sw)
		local wp = mix(waistPitch, -0.12 + breathe, sw)
		local wy = mix(0, look * 0.25, sw)
		local wroll = mix(waistRoll, -sh * 0.05, sw)
		local np = mix(-0.04, 0.12 + rattle * 0.05, sw)
		local ny = mix(0, look, sw)
		local nr = mix(0, sk.tilt, sw)
		local lat = mix(0, sh * 0.08, sw)
		local lift, fwd = 0, 0
		local lH, rH = s * 0.75 * w, -s * 0.75 * w
		local lK, rK = -math.max(0, -c) * 0.9 * w, -math.max(0, c) * 0.9 * w
		local hipZ = -lat / 1.9 -- (the legs lean against the sideways shift so the feet stay put)
		jaw = mix(jaw, 0.03 + shiver * math.abs(math.sin(now * 31)) * 0.22, sw)

		-- fighting
		if fw > 0.001 then
			local a = math.min(since, STRIKE[#STRIKE][1])
			local function key(i)
				return sampleKeys(STRIKE, a, i)
			end
			local bounce = math.sin(t * 2.4) * 0.025
			local l = key(11) + bounce
			rS = mix(rS, key(2) + bounce, fw)
			rZ = mix(rZ, key(3), fw)
			rE = mix(rE, key(4), fw)
			wr = mix(wr, key(5) - bounce, fw)
			lS = mix(lS, key(6), fw)
			lZ = mix(lZ, key(7), fw)
			lE = mix(lE, key(8), fw)
			wp = mix(wp, key(9), fw)
			wy = mix(wy, key(10), fw)
			wroll = mix(wroll, 0, fw)
			np = mix(np, 0.05 - key(9) * 0.6, fw) -- the head stays on the wall while the body leans
			ny = mix(ny, 0, fw)
			nr = mix(nr, 0, fw)
			lat = mix(lat, 0, fw)
			lift = mix(lift, l, fw)
			fwd = mix(fwd, key(12), fw)
			-- the jaw gapes through the blow
			jaw = mix(jaw, (a > 0.2 and a < 0.6) and math.sin((a - 0.2) / 0.4 * math.pi) * 0.22 or 0, fw)
			-- the stance: left foot forward, right foot back; the knees take the dips of the body
			lH = mix(lH, 0.3 - l * 0.4, fw)
			rH = mix(rH, -0.25 - l * 0.4, fw)
			lK = mix(lK, -0.35 + l * 1.2, fw)
			rK = mix(rK, -0.2 + l * 1.0, fw)
			hipZ = mix(hipZ, 0, fw)
		end

		local function sm(name, x)
			local e = sk.sm[name]
			if not e then
				e = { x = x, v = 0 }
				sk.sm[name] = e
			end
			e.x, e.v = springStep(e.x, e.v, x, 900, 60, dt)
			return e.x
		end
		local wyS = sm("wy", wy)
		local hz = sm("hipZ", hipZ)
		set(rig, "RShoulder", ANGLES(sm("rS", rS), 0, sm("rZ", rZ)))
		set(rig, "RElbow", ANGLES(sm("rE", rE), 0, 0))
		set(rig, "RWrist", ANGLES(sm("wr", wr), 0, 0))
		set(rig, "LShoulder", ANGLES(sm("lS", lS), 0, sm("lZ", lZ)))
		set(rig, "LElbow", ANGLES(sm("lE", lE), 0, 0))
		set(rig, "Waist", ANGLES(sm("wp", wp), wyS, sm("wroll", wroll)))
		set(rig, "Neck", ANGLES(sm("np", np), sm("ny", ny) - wyS * 0.6, sm("nr", nr)))
		set(rig, "LHip", ANGLES(sm("lH", lH), 0, hz))
		set(rig, "RHip", ANGLES(sm("rH", rH), 0, hz))
		set(rig, "LKnee", ANGLES(sm("lK", lK), 0, 0))
		set(rig, "RKnee", ANGLES(sm("rK", rK), 0, 0))
		local jitter = rattle * 0.015 * (1 - fw)
		set(rig, "Root", CFrame.new((sm("lat", lat) + jitter) * scale, bob + float + rise + sm("lift", lift) * scale, sm("fwd", fwd) * scale))
	end

	-- AttackStyle "Bow" (the Hollow Archer, build_hollowarcher.lua): both arms are placed with armIK from hand targets.
	--   walk / idle: the bow hangs at its side; idle, the hooded head turns slowly, watching the distance;
	--   fight, one attack = one continuous cycle with ONE draw (times below for a 1 s cycle; it is stretched to AttackCD): the arrow is already on the string; it draws
	--     (0-0.4, easing out as the bow gets heavy, the eyes brighten), holds at full draw with the string trembling (to
	--     RELEASE 0.55) and looses: the string snaps back and vibrates, the bow arm kicks, the draw hand's follow-through
	--     flies back past the ear on to the quiver in one motion (0.55-0.7), takes an arrow (to 0.8) and brings it to the
	--     string (0.8-1.0), ready for the next draw. (The quiver trip is part of the follow-through: at the START of the
	--     attack it read as a second draw.) At the release ArrowFx flies the arrow from the nock to AimPos (the server's
	--     damage lands when it arrives).
	--   The string is the model's two Beams through the Nock attachment, moved back as it draws; the nocked arrow is a
	--   client-only part under the model.
	if style == "Bow" then
		local A = ARCHER
		local ab = rig.bow
		if not ab then
			ab = { fight = 0, eyes = {} }
			rig.bow = ab
		end
		if not ab.lHand or not ab.lHand.Parent then
			ab.lHand = model:FindFirstChild("LHand", true)
			ab.nock = ab.lHand and ab.lHand:FindFirstChild("Nock")
			table.clear(ab.eyes)
			for _, d in ipairs(model:GetDescendants()) do
				if d:IsA("BasePart") and d.Name == "Eye" then
					table.insert(ab.eyes, d)
				end
			end
		end
		if not ab.nocked then
			local arrow = Instance.new("Part")
			arrow.Name = "NockedArrow"
			arrow.Size = Vector3.new(0.07, 0.07, 1.9) * scale
			arrow.Color = model:GetAttribute("Form") == "Shadow" and Color3.fromRGB(30, 26, 40) or Color3.fromRGB(214, 204, 176)
			arrow.Material = Enum.Material.SmoothPlastic
			arrow.Anchored = true
			arrow.CanCollide, arrow.CanQuery, arrow.CanTouch, arrow.CastShadow = false, false, false, false
			arrow.Transparency = 1
			arrow.Parent = model
			ab.nocked = arrow
		end
		local function sm01(x)
			x = clamp01(x)
			return x * x * (3 - 2 * x)
		end
		local function mix(a, b, k)
			return a + (b - a) * k
		end
		local cd = model:GetAttribute("AttackCD") or 1
		local since = rig.lastShot and (now - rig.lastShot) or math.huge
		local fighting = state ~= "walk" and since < cd + 1.2
		ab.fight += ((fighting and 1 or 0) - ab.fight) * clamp01(dt * (fighting and 6 or 2))
		local fw = ab.fight * ab.fight * (3 - 2 * ab.fight) * (1 - w)

		-- the attack cycle: the draw hand's target, the string's draw (0..1), the arrow on the string, eye flare, bow kick
		local function nockAt(d)
			return A.GRIP + Vector3.new(0, 0, A.brace + d * A.drawLen)
		end
		local HOLD = Vector3.new(0.04, 0.02, 0.06) -- (the hand centre is a little behind the fingers on the string)
		local REST = nockAt(0) + HOLD
		-- like a real archer it turns side-on to shoot (the chest turns right, the left shoulder towards the wall), which
		-- lets the draw elbow point out to the right; the fight targets are meant in the model's space (aimed straight at
		-- the wall), so they are turned back into the twisted torso's space
		local twist = -0.55 * fw
		local WAIST = Vector3.new(0, 2.72, 0)
		local untwist = CFrame.new(WAIST) * CFrame.Angles(0, -twist, 0) * CFrame.new(-WAIST)
		-- (the cycle is written for 1 s and stretched to the unit's AttackCD, so a slower archer draws slower)
		local a = math.min(since / cd, 1.0)
		local hand, draw, shown, flare, kick, grow = REST, 0, true, 0, 0, 1
		if a < 0.4 then
			local f = a / 0.4
			draw = 1 - (1 - f) * (1 - f)
			hand = nockAt(draw) + HOLD
			flare = f * 0.5
		elseif a < A.RELEASE then
			draw = 1 + math.sin(now * 60) * 0.012
			hand = nockAt(draw) + HOLD
			flare = 1
		else
			local r = a - A.RELEASE
			draw = math.sin(r * 70) * math.exp(-r * 18) * 0.08
			kick = math.sin(r * 25) * math.exp(-r * 10)
			flare = math.max(0, 1 - r / 0.15)
			shown = a >= 0.93 -- (the new arrow arrives on the string with the hand)
			-- the follow-through flies back past the ear and on to the quiver in one motion (a curve through the ear point,
			-- fast out of the release, slowing into the quiver), a moment there to take an arrow, then forward to the string.
			-- (the quiver sits on the torso: its point is turned into the model's space like the other targets)
			local full = nockAt(1) + HOLD
			local ear = full + Vector3.new(0.25, 0.15, 0.3)
			local quiver = untwist:Inverse() * A.QUIVER
			if a < 0.7 then
				local e = 1 - (1 - (a - A.RELEASE) / (0.7 - A.RELEASE)) ^ 2
				hand = full:Lerp(ear, e):Lerp(ear:Lerp(quiver, e), e)
			elseif a < 0.8 then
				hand = quiver + Vector3.new(0, math.sin((a - 0.7) / 0.1 * math.pi) * 0.06, 0)
			else
				hand = quiver:Lerp(REST, sm01((a - 0.8) / 0.2))
			end
		end

		-- loose the arrow once per attack
		if rig.lastShot and since >= A.RELEASE * cd and ab.firedShot ~= rig.lastShot then
			ab.firedShot = rig.lastShot
			local aim = model:GetAttribute("AimPos")
			local def = Units.Stats[model.Name]
			if ab.lHand and typeof(aim) == "Vector3" and def and def.projectileSpeed then
				local from = ab.lHand.CFrame:PointToWorldSpace(Vector3.new(0, 0, (A.brace + A.drawLen) * scale))
				ArrowFx.fire(model, from, aim, def.projectileSpeed)
			end
		end

		-- hand targets: the bow hand out at chin height (fight) or hanging at the side (walk / idle)
		local lFight = untwist * (A.GRIP + Vector3.new(0, A.handDrop, 0) + Vector3.new(0, -0.05, -0.06) * kick)
		hand = untwist * hand
		local lRest = Vector3.new(-0.62, 2.15, -0.05 - s * 0.25 * w)
		local rRest = Vector3.new(0.62, 2.15, s * 0.3 * w)
		local lTarget = lRest:Lerp(lFight, fw)
		local rTarget = rRest:Lerp(hand, fw)
		local lPole = Vector3.new(0, 0, 1):Lerp(Vector3.new(-1, -0.4, 0.2), fw)
		local rPole = Vector3.new(0, 0, 1):Lerp(Vector3.new(1, -0.1, 0.6), fw) -- (the draw elbow out to the right, about shoulder height)
		local bowRot = CFrame.Angles(0, 0, 0.08):Lerp(CFrame.Angles(0, -twist, 0) * CFrame.Angles(-0.05 * kick, 0, -0.12), fw)
		local lCF, lBend = armIK(A.lShoulder, lTarget, A.upper, A.lower, lPole)
		local rCF, rBend = armIK(A.rShoulder, rTarget, A.upper, A.lower, rPole)
		set(rig, "LShoulder", lCF)
		set(rig, "LElbow", ANGLES(lBend, 0, 0))
		set(rig, "LWrist", (lCF * ANGLES(lBend, 0, 0)):Inverse() * bowRot)
		set(rig, "RShoulder", rCF)
		set(rig, "RElbow", ANGLES(rBend, 0, 0))

		-- body: a planted stance while shooting, a slow look into the distance when idle
		set(rig, "Waist", ANGLES(mix(waistPitch, -0.04 + kick * 0.05, fw), twist, mix(waistRoll, 0, fw)))
		set(rig, "Neck", ANGLES(mix(-0.04 * w, 0.03, fw), mix(math.sin(t * 0.35) * 0.4 * (1 - w), 0, fw) - twist, 0)) -- (the head stays on the wall)
		if fw > 0.001 then
			set(rig, "LHip", ANGLES(mix(s * 0.75 * w, 0.15, fw), 0, 0))
			set(rig, "RHip", ANGLES(mix(-s * 0.75 * w, -0.12, fw), 0, 0))
			set(rig, "LKnee", ANGLES(mix(-math.max(0, -c) * 0.9 * w, -0.1, fw), 0, 0))
			set(rig, "RKnee", ANGLES(mix(-math.max(0, c) * 0.9 * w, -0.08, fw), 0, 0))
		end

		-- the string, the nocked arrow and the eyes
		local pull = (A.brace + draw * A.drawLen * fw) * scale
		if ab.nock then
			ab.nock.Position = Vector3.new(0, 0, pull)
		end
		if ab.lHand and shown and fw > 0.3 then
			local cf = ab.lHand.CFrame
			local nockW = cf:PointToWorldSpace(Vector3.new(0, 0, pull))
			local fwdW = cf:VectorToWorldSpace(Vector3.new(0, 0, -1))
			local centre = nockW + fwdW * 0.95 * scale
			ab.nocked.CFrame = CFrame.lookAt(centre, centre + fwdW)
			ab.nocked.Transparency = 1 - grow -- (the next arrow forms on the string)
		else
			ab.nocked.Transparency = 1
		end
		for _, eye in ipairs(ab.eyes) do
			eye.Transparency = 0.2 - 0.2 * flare * fw
		end
	end

	-- AttackStyle "Slam" (the Zombie, build_zombie.lua): a lopsided brute; the huge club is the right arm. Layers, mixed
	-- and then sprung (no snapping):
	--   walk: a lurching shamble; the heavy right leg strides, the left foot drags (barely lifts), the body drops and
	--     rolls onto each step, the head stays forward;
	--   idle: heavy, slow breathing (the chest heaves), the head lolls, the jaw hangs, the weight sways; every ~6 s the
	--     club jerks up and swings back down;
	--   fight: the SLAM cycle, the lunge scaled to the wall (measured per attack: the fist should just meet the stone).
	-- The club arm runs through a SOFT spring outside the attack, so it lags and swings like a heavy pendulum after every
	-- lurch, twitch and the follow-through; during the blow its spring is stiff so the slam stays sharp.
	if style == "Slam" then
		local zb = rig.slam
		if not zb then
			zb = { sm = {}, fight = 0, phase = 0, lunge = 0 }
			rig.slam = zb
		end
		local function mix(a, b, k)
			return a + (b - a) * k
		end
		local cd = model:GetAttribute("AttackCD") or 2
		local since = rig.lastShot and (now - rig.lastShot) or math.huge
		local fighting = state ~= "walk" and since < cd + 1.0
		zb.fight += ((fighting and 1 or 0) - zb.fight) * clamp01(dt * (fighting and 8 or 2))
		local fw = zb.fight * zb.fight * (3 - 2 * zb.fight) * (1 - w)
		local sw = 1 - w
		zb.phase += dt * (2.2 + speed * 0.35) * w
		local ph = zb.phase
		local sp, cp = math.sin(ph), math.cos(ph)

		-- walk: the shamble
		local rS, rZ, rE = -sp * 0.4 * w + 0.1, 0.1, 0.3
		local lS, lZ, lE = sp * 0.2 * w, 0.05, 0.55
		local wp = -0.3 * w
		local wy = sp * 0.12 * w
		local wroll = sp * 0.14 * w
		local np, ny, nr = 0.3 * w + math.sin(ph * 2) * 0.05 * w, 0, -sp * 0.08 * w
		local lat = sp * 0.12 * w
		local lift = -math.max(0, -sp) * 0.14 * w -- (drops onto the dragging left leg)
		local fwd = 0
		local rH, rK = sp * 0.55 * w, -math.max(0, cp) * 0.7 * w
		local lH, lK = -sp * 0.3 * w, -math.max(0, -cp) * 0.15 * w
		local hipZ = 0
		local mouth = 0.25

		-- idle
		if sw > 0.001 then
			local breath = math.sin(t * 1.3)
			local sway = math.sin(t * 0.7)
			local cyc = (t * 0.165) % 1
			local twitch = cyc < 0.05 and math.sin(cyc / 0.05 * math.pi) or 0
			rS = mix(rS, 0.06 + sway * 0.06 + twitch * 0.9, sw)
			rZ = mix(rZ, 0.12 + twitch * 0.3, sw)
			rE = mix(rE, 0.2 + twitch * 0.4, sw)
			lS = mix(lS, 0.05 - sway * 0.04, sw)
			lE = mix(lE, 0.5 + breath * 0.05, sw)
			wp = mix(wp, -0.3 + breath * 0.06, sw)
			wy = mix(wy, sway * 0.08, sw)
			wroll = mix(wroll, -sway * 0.06, sw)
			np = mix(np, 0.28 - breath * 0.04, sw)
			ny = mix(ny, math.sin(t * 0.37) * 0.25, sw)
			nr = mix(nr, math.sin(t * 0.5) * 0.22, sw)
			lat = mix(lat, sway * 0.08, sw)
			lift = mix(lift, breath * 0.03, sw)
			rH, rK = mix(rH, 0.05, sw), mix(rK, -0.08, sw)
			lH, lK = mix(lH, -0.05, sw), mix(lK, -0.05, sw)
			hipZ = mix(hipZ, -lat / 2.0, sw)
			mouth = mix(mouth, 0.25 + breath * 0.08, sw)
		end

		-- the lunge, measured once per attack: the fist (~3.9 design units ahead at the impact) should just meet the
		-- stone at fist height, and the feet must not walk into the plinth
		if rig.lastShot and zb.measuredShot ~= rig.lastShot then
			zb.measuredShot = rig.lastShot
			zb.lunge = 0
			local hrp = model.PrimaryPart
			if hrp then
				local look = Vector3.new(hrp.CFrame.LookVector.X, 0, hrp.CFrame.LookVector.Z)
				if look.Magnitude > 0.1 then
					look = look.Unit
					local floorY = hrp.Position.Y - (model:GetAttribute("RootHeight") or 2.4) * scale
					local high = distanceAhead(Vector3.new(hrp.Position.X, floorY + 2.9 * scale, hrp.Position.Z), look, 14)
					local low = distanceAhead(Vector3.new(hrp.Position.X, floorY + 0.3 * scale, hrp.Position.Z), look, 14)
					local studs = 1.2 * scale
					if high then
						studs = math.min(studs, high - 3.9 * scale)
					end
					if low then
						studs = math.min(studs, low - 0.9 * scale)
					end
					zb.lunge = math.clamp(studs, -0.5 * scale, 1.6 * scale) / scale
				end
			end
		end

		-- fight
		if fw > 0.001 then
			local a = math.min(since, SLAM[#SLAM][1])
			local function key(i)
				return sampleKeys(SLAM, a, i)
			end
			local l = key(10)
			rS = mix(rS, key(2), fw)
			rZ = mix(rZ, key(3), fw)
			rE = mix(rE, key(4), fw)
			lS = mix(lS, key(5), fw)
			lZ = mix(lZ, key(6), fw)
			lE = mix(lE, key(7), fw)
			wp = mix(wp, key(8), fw)
			wy = mix(wy, key(9), fw)
			wroll = mix(wroll, 0, fw)
			np = mix(np, 0.1 - key(8) * 0.7, fw) -- the head stays on the wall while the body leans
			ny = mix(ny, 0, fw)
			nr = mix(nr, 0, fw)
			lat = mix(lat, 0, fw)
			lift = mix(lift, l, fw)
			fwd = mix(fwd, key(11) * zb.lunge, fw) -- (key -1 = the full lunge towards the wall)
			-- the stance: left foot forward, right foot back, the knees take the drops
			lH = mix(lH, 0.3 - l * 0.5, fw)
			rH = mix(rH, -0.2 - l * 0.5, fw)
			lK = mix(lK, -0.25 + l * 1.1, fw)
			rK = mix(rK, -0.15 + l * 1.0, fw)
			hipZ = mix(hipZ, 0, fw)
			-- the jaw gapes on the drop
			mouth = mix(mouth, 0.25 + ((a > 0.6 and a < 1.2) and math.sin((a - 0.6) / 0.6 * math.pi) * 0.3 or 0), fw)
		end

		local function sm(name, x, stiffness, damping)
			local e = zb.sm[name]
			if not e then
				e = { x = x, v = 0 }
				zb.sm[name] = e
			end
			e.x, e.v = springStep(e.x, e.v, x, stiffness or 900, damping or 60, dt)
			return e.x
		end
		-- the club: soft and swinging outside the blow, stiff during it
		local clubK, clubD = mix(55, 900, fw), mix(6, 60, fw)
		local wyS = sm("wy", wy)
		set(rig, "RShoulder", ANGLES(sm("rS", rS, clubK, clubD), 0, sm("rZ", rZ, clubK, clubD)))
		set(rig, "RElbow", ANGLES(sm("rE", rE, clubK * 1.5, clubD), 0, 0))
		set(rig, "LShoulder", ANGLES(sm("lS", lS, 300, 25), 0, sm("lZ", lZ, 300, 25)))
		set(rig, "LElbow", ANGLES(sm("lE", lE, 300, 25), 0, 0))
		set(rig, "Waist", ANGLES(sm("wp", wp), wyS, sm("wroll", wroll)))
		set(rig, "Neck", ANGLES(sm("np", np), sm("ny", ny) - wyS * 0.6, sm("nr", nr)))
		local hz = sm("hipZ", hipZ)
		set(rig, "LHip", ANGLES(sm("lH", lH), 0, hz))
		set(rig, "RHip", ANGLES(sm("rH", rH), 0, hz))
		set(rig, "LKnee", ANGLES(sm("lK", lK), 0, 0))
		set(rig, "RKnee", ANGLES(sm("rK", rK), 0, 0))
		set(rig, "Root", CFrame.new(sm("lat", lat) * scale, sm("lift", lift) * scale + float + rise, sm("fwd", fwd) * scale))
		jaw = sm("mouth", mouth, 200, 20)
	end

	-- Pose "Spider" (the Crypt Spider, AttackStyle "Spit", build_cryptspider.lua): eight legs, joints <side><n>Hip /
	-- Knee / Ankle (n = 1 front .. 4), Root (the body), Pedicel (the skull abdomen), LFang / RFang; every joint turns
	-- about the model's axes. A leg's hip = a swing fore/aft (about Y) and a lift (about Z); `side` mirrors left/right.
	--   walk: the alternating tetrapod gait of real spiders (L1 R2 L3 R4 step together, then the other four), fast, the
	--     body low and level;
	--   idle: still, then a front leg taps the stone, the fangs twitch, the body turns a few degrees in a sudden jerk
	--     (an underdamped spring), the skull breathes;
	--   fight, one attack = SPIT_KEYS stretched to AttackCD: it rears up on its hind legs with the front legs spread high
	--     (a threat display), the skull abdomen pulses as the venom gathers, then it drops forward and spits at 0.5 of
	--     the cycle (Units releaseAt = 0.5 x attackCD): VenomFx flies the glob to AimPos.
	if model:GetAttribute("Pose") == "Spider" then
		local sp = rig.spider
		if not sp then
			sp = { sm = {}, fight = 0, phase = 0, yaw = 0, yawV = 0 }
			rig.spider = sp
		end
		local function mix(a, b, k)
			return a + (b - a) * k
		end
		local cd = model:GetAttribute("AttackCD") or 0.8
		local since = rig.lastShot and (now - rig.lastShot) or math.huge
		local fighting = state ~= "walk" and since < cd + 1.0
		sp.fight += ((fighting and 1 or 0) - sp.fight) * clamp01(dt * (fighting and 8 or 2.5))
		local fw = sp.fight * sp.fight * (3 - 2 * sp.fight) * (1 - w)
		local sw = 1 - w
		sp.phase += dt * (6 + speed * 0.6) * w

		-- per leg: swing and lift (walk + idle), then the attack adds on top
		local legSwing, legLift, legKnee = {}, {}, {}
		local GROUP_A = { L1 = true, R2 = true, L3 = true, R4 = true }
		for _, s in ipairs({ "L", "R" }) do
			for n = 1, 4 do
				local key = s .. n
				local ph = sp.phase + (GROUP_A[key] and 0 or math.pi)
				legSwing[key] = math.sin(ph) * 0.32 * w
				legLift[key] = math.max(0, math.cos(ph)) * 0.32 * w
				legKnee[key] = 0
			end
		end
		local pitch, lift, fwd, yaw = 0, -math.abs(math.cos(sp.phase)) * 0.04 * w, 0, 0
		local fangs, abdomen = math.sin(t * 9) * 0.04, math.sin(t * 1.5) * 0.03

		-- idle: a tapping front leg, a sudden jerk of the body every few seconds
		if sw > 0.001 then
			local idx = math.floor(t * 0.33)
			local r = (math.sin(idx * 12.9898) * 43758.5453) % 1
			sp.yaw, sp.yawV = springStep(sp.yaw, sp.yawV, (r - 0.5) * 0.5, 420, 18, dt)
			yaw = mix(yaw, sp.yaw, sw)
			local tapCyc = (t * 0.4) % 1
			local tapLeg = (math.floor(t * 0.4) % 2 == 0) and "L1" or "R1"
			if tapCyc < 0.25 then
				local u = tapCyc / 0.25
				legLift[tapLeg] += (math.sin(u * math.pi) * 0.25 + math.max(0, math.sin(u * math.pi * 4)) * 0.12) * sw
			end
			local twitch = ((t * 0.7) % 1) < 0.06 and 0.25 or 0
			fangs += twitch * sw
		end

		-- fight
		if fw > 0.001 then
			local a = math.min(since / cd, 1.0)
			local function key(i)
				return sampleKeys(SPIT_KEYS, a, i)
			end
			local pulse = (a > 0.3 and a < 0.48) and math.sin(a * 90) * 0.07 or 0
			pitch = mix(pitch, key(2), fw)
			lift = mix(lift, key(3), fw)
			fwd = mix(fwd, key(4), fw)
			yaw = mix(yaw, 0, fw)
			fangs = mix(fangs, key(10), fw)
			abdomen = mix(abdomen, key(11) + pulse, fw)
			for _, s in ipairs({ "L", "R" }) do
				for n = 1, 4 do
					local k = s .. n
					if n == 1 then
						legLift[k] = mix(legLift[k], key(5), fw)
						legSwing[k] = mix(legSwing[k], key(6), fw)
						legKnee[k] = mix(legKnee[k], key(7), fw)
					elseif n == 2 then
						legLift[k] = mix(legLift[k], key(8), fw)
						legSwing[k] = mix(legSwing[k], 0, fw)
					else
						-- the hind legs stay planted: they press down as the body rears
						legLift[k] = mix(legLift[k], key(9), fw)
						legSwing[k] = mix(legSwing[k], 0, fw)
					end
				end
			end
		end

		-- loose the venom once per attack
		local releaseAt = 0.5 * cd
		if rig.lastShot and since >= releaseAt and sp.firedShot ~= rig.lastShot then
			sp.firedShot = rig.lastShot
			local aim = model:GetAttribute("AimPos")
			local def = Units.Stats[model.Name]
			local thorax = model:FindFirstChild("Thorax")
			if thorax and typeof(aim) == "Vector3" and def and def.projectileSpeed then
				VenomFx.fire(model, thorax.CFrame:PointToWorldSpace(Vector3.new(0, -0.08, -0.66) * scale), aim, def.projectileSpeed)
			end
		end

		local function sm(name, x)
			local e = sp.sm[name]
			if not e then
				e = { x = x, v = 0 }
				sp.sm[name] = e
			end
			e.x, e.v = springStep(e.x, e.v, x, 900, 60, dt)
			return e.x
		end
		local pitchS = sm("pitch", pitch)
		set(rig, "Root", CFrame.new(0, sm("lift", lift) * scale + float + rise, sm("fwd", fwd) * scale) * ANGLES(pitchS, sm("yaw", yaw), 0))
		set(rig, "Pedicel", ANGLES(sm("abdomen", abdomen) - pitchS * 0.6, 0, 0)) -- (the skull stays roughly level as it rears)
		local fangS = sm("fangs", fangs)
		set(rig, "LFang", ANGLES(0, -fangS, 0))
		set(rig, "RFang", ANGLES(0, fangS, 0))
		for _, s in ipairs({ "L", "R" }) do
			local side = (s == "R") and 1 or -1
			for n = 1, 4 do
				local k = s .. n
				local swing, liftK, knee = sm(k .. "s", legSwing[k]), sm(k .. "l", legLift[k]), sm(k .. "k", legKnee[k])
				-- (the hind legs counter the body's pitch so their feet stay on the ground)
				local counter = (n >= 3) and -pitchS or 0
				set(rig, k .. "Hip", ANGLES(counter, side * swing, side * liftK))
				set(rig, k .. "Knee", ANGLES(0, 0, side * knee))
				set(rig, k .. "Ankle", ANGLES(0, 0, -side * (liftK * 0.5 + knee * 0.3)))
			end
		end
	end

	-- Pose "Bat" (the Crypt Bat, AttackStyle "Dive", build_cryptbat.lua): it never touches the ground. Joints Root,
	-- Neck, Jaw, L/RWing (shoulder: up/down about Z, swept back about Y), L/RWingTip (elbow: the outer wing lags the beat
	-- and folds back), L/RLeg (the clawed feet).
	--   flying (walk): fast deep beats, nose a little down, the body rising on each downstroke;
	--   hover (idle): quick, slightly uneven beats, a bobbing body, the head jerking to new spots (an underdamped
	--     spring), and now and then a quick barrel roll;
	--   fight: DIVE_KEYS stretched to AttackCD, the lunge measured once per attack (rays at hover and dive height to the
	--     real wall surface) so the snout stops just short of the stone.
	if model:GetAttribute("Pose") == "Bat" then
		local bt = rig.bat
		if not bt then
			bt = { sm = {}, fight = 0, phase = 0, lunge = 0, yaw = 0, yawV = 0, pitch = 0, pitchV = 0 }
			rig.bat = bt
		end
		local function mix(a, b, k)
			return a + (b - a) * k
		end
		local function sm01(x)
			x = clamp01(x)
			return x * x * (3 - 2 * x)
		end
		local cd = model:GetAttribute("AttackCD") or 1.6
		local since = rig.lastShot and (now - rig.lastShot) or math.huge
		local fighting = state ~= "walk" and since < cd + 1.0
		bt.fight += ((fighting and 1 or 0) - bt.fight) * clamp01(dt * (fighting and 8 or 2.5))
		local fw = bt.fight * bt.fight * (3 - 2 * bt.fight) * (1 - w)
		local sw = 1 - w
		bt.phase += dt * (mix(10 + math.sin(t * 1.7) * 1.5, 13, w))
		local ph = bt.phase

		-- flying / hovering
		local amp = 1
		local fold = 0
		local rise, fwd, lat = 0, 0, 0
		local pitch, yaw, roll = -0.2 * w, 0, 0
		local legs, mouth = 0, 0.05
		local neckP, neckY = 0, 0
		if sw > 0.001 then
			local idx = math.floor(t * 0.8)
			local r1 = (math.sin(idx * 12.9898) * 43758.5453) % 1
			local r2 = (math.sin(idx * 78.233) * 12345.6789) % 1
			bt.yaw, bt.yawV = springStep(bt.yaw, bt.yawV, (r1 - 0.5) * 0.8, 380, 16, dt)
			bt.pitch, bt.pitchV = springStep(bt.pitch, bt.pitchV, (r2 - 0.5) * 0.4, 380, 16, dt)
			neckY = mix(neckY, bt.yaw, sw)
			neckP = mix(neckP, bt.pitch, sw)
			lat = mix(lat, math.sin(t * 0.9) * 0.2, sw)
			yaw = mix(yaw, math.sin(t * 0.6) * 0.15, sw)
			-- a quick barrel roll every ~8 s
			local cyc = (t * 0.12) % 1
			if cyc < 0.07 then
				roll = mix(roll, sm01(cyc / 0.07) * math.pi * 2, sw * (1 - fw))
			end
		end

		-- the dive's lunge, measured once per attack
		if rig.lastShot and bt.measuredShot ~= rig.lastShot then
			bt.measuredShot = rig.lastShot
			bt.lunge = 0
			local hrp = model.PrimaryPart
			if hrp then
				local look = Vector3.new(hrp.CFrame.LookVector.X, 0, hrp.CFrame.LookVector.Z)
				if look.Magnitude > 0.1 then
					look = look.Unit
					local room
					for _, dy in ipairs({ 0, -0.5 }) do
						local d = distanceAhead(hrp.Position + Vector3.new(0, dy * scale, 0), look, 30)
						if d then
							room = math.min(room or d, d)
						end
					end
					if room then
						-- (at the bottom of the dive the snout is ~0.5 design units ahead of the root's start: measured in play)
						bt.lunge = math.max(0, room - 0.5 * scale - 0.2) / scale
					end
				end
			end
		end

		-- fight
		if fw > 0.001 then
			local a = math.min(since / cd, 1.0)
			local function key(i)
				return sampleKeys(DIVE_KEYS, a, i)
			end
			rise = mix(rise, key(2), fw)
			fwd = mix(fwd, key(3) * bt.lunge, fw)
			pitch = mix(pitch, key(4), fw)
			amp = mix(amp, key(5), fw)
			fold = mix(fold, clamp01(key(6)), fw)
			legs = mix(legs, key(7), fw)
			mouth = mix(mouth, key(8), fw)
			lat = mix(lat, 0, fw)
			yaw = mix(yaw, 0, fw)
			neckY = mix(neckY, 0, fw)
			neckP = mix(neckP, -key(4) * 0.5, fw) -- (the head stays on the wall through the climb and the dive)
		end

		local function sm(name, x, k, d)
			local e = bt.sm[name]
			if not e then
				e = { x = x, v = 0 }
				bt.sm[name] = e
			end
			e.x, e.v = springStep(e.x, e.v, x, k or 900, d or 60, dt)
			return e.x
		end
		amp, fold = sm("amp", amp), sm("fold", fold)
		-- the body rises on each downstroke
		local bob = -math.cos(ph) * 0.12 * amp
		set(rig, "Root", CFrame.new(sm("lat", lat) * scale, (sm("rise", rise) + bob) * scale + float, sm("fwd", fwd) * scale)
			* ANGLES(sm("pitch", pitch), sm("yaw", yaw), roll))
		set(rig, "Neck", ANGLES(sm("neckP", neckP), sm("neckY", neckY), 0))
		jaw = sm("mouth", mouth) -- (the generic code sets the Jaw joint from this at the end)
		local beat = math.sin(ph)
		local lagBeat = math.sin(ph - 0.7)
		local legsS = sm("legs", legs)
		for _, s in ipairs({ "L", "R" }) do
			local side = (s == "R") and 1 or -1
			local flapAngle = (beat * 0.8 + 0.1) * amp * (1 - fold)
			set(rig, s .. "Wing", ANGLES(0, -side * 0.9 * fold, side * (flapAngle + 1.1 * fold)))
			set(rig, s .. "WingTip", ANGLES(0, -side * 1.4 * fold, side * lagBeat * 0.5 * amp * (1 - fold)))
			set(rig, s .. "Leg", ANGLES(legsS + 0.1, 0, 0))
		end
	end

	-- Pose "Crawler" (the Ghoul, AttackStyle "Pounce"): a starved thing on all fours (build_ghoul.lua). Every joint turns
	-- about the model's own axes. Three layers, mixed and then run through stiff springs (no snapping):
	--   walk: a fast skittering diagonal gait (left front with right hind), the paws lift as they swing forward and stay
	--     level, the body rolls and bobs under a head that stays steady;
	--   idle: a stalking crouch, breathing; the head jerks to new spots (a stiff, underdamped spring: it snaps and
	--     overshoots), sniffs now and then, scratches the ground twice with the right claw (~6.5 s) and has a full-body
	--     spasm (~9 s);
	--   fight: the POUNCE cycle (the right side trails the left by 0.03 s), the hind end wiggles before the leap like a
	--     cat's; between attacks it holds the crouch and eases out ~1 s after the last attack.
	if model:GetAttribute("Pose") == "Crawler" then
		local cr = rig.crawler
		if not cr then
			cr = { sm = {}, fight = 0, phase = 0, yaw = 0, yawV = 0, pitch = 0, pitchV = 0 }
			rig.crawler = cr
		end
		local function mix(a, b, k)
			return a + (b - a) * k
		end
		local cd = model:GetAttribute("AttackCD") or 1.2
		local since = rig.lastShot and (now - rig.lastShot) or math.huge
		local fighting = state ~= "walk" and since < cd + 1.0
		cr.fight += ((fighting and 1 or 0) - cr.fight) * clamp01(dt * (fighting and 10 or 2.5))
		local fw = cr.fight * cr.fight * (3 - 2 * cr.fight) * (1 - w)
		local sw = 1 - w
		cr.phase += dt * (4 + speed * 0.55) * w

		-- channels
		local L = { S = 0, E = 0, Wx = 0, H = 0, K = 0, Ax = 0 } -- left front + left hind
		local R = { S = 0, E = 0, Wx = 0, H = 0, K = 0, Ax = 0 }
		local lift, fwd, pitch, roll, yaw, spine, spineYaw = 0, 0, 0, 0, 0, 0, 0
		local neckP, neckY, neckR, mouth = 0, 0, 0, 0

		-- walk
		local function gait(side, ph)
			local swingF, liftF = math.sin(ph), math.max(0, math.cos(ph))
			local swingH, liftH = math.sin(ph + math.pi), math.max(0, math.cos(ph + math.pi))
			side.S, side.E = swingF * 0.45 * w, liftF * 0.55 * w
			side.H, side.K, side.Ax = swingH * 0.4 * w, -liftH * 0.55 * w, liftH * 0.2 * w
		end
		gait(L, cr.phase)
		gait(R, cr.phase + math.pi)
		lift = -math.abs(math.cos(cr.phase)) * 0.07 * w
		roll = math.sin(cr.phase) * 0.06 * w
		spine = math.sin(cr.phase * 2) * 0.04 * w
		neckP = -spine * 0.8 + 0.05 * w
		mouth = 0.12 * w

		-- idle
		if sw > 0.001 then
			local breath = math.sin(t * 1.6)
			-- the head jerks to a new spot about once a second
			local idx = math.floor(t * 1.1)
			local r1 = (math.sin(idx * 12.9898) * 43758.5453) % 1
			local r2 = (math.sin(idx * 78.233) * 12345.6789) % 1
			cr.yaw, cr.yawV = springStep(cr.yaw, cr.yawV, (r1 - 0.5) * 0.9, 320, 14, dt)
			cr.pitch, cr.pitchV = springStep(cr.pitch, cr.pitchV, (r2 - 0.5) * 0.35, 320, 14, dt)
			local sniffCyc = (t * 0.3) % 1
			local sniff = sniffCyc < 0.2 and math.sin(sniffCyc / 0.2 * math.pi) or 0
			local scratchCyc = (t * 0.155) % 1
			local scratch = scratchCyc < 0.12 and math.sin(scratchCyc / 0.12 * math.pi) or 0
			local rake = scratch > 0 and math.sin(scratchCyc / 0.12 * math.pi * 4) or 0
			local spasmCyc = (t * 0.11) % 1
			local spasm = spasmCyc < 0.035 and math.sin(spasmCyc / 0.035 * math.pi) or 0
			local jolt = math.sin(now * 53) * spasm

			lift = mix(lift, -0.12 + breath * 0.02, sw)
			spine = mix(spine, breath * 0.03 + jolt * 0.12, sw)
			roll = mix(roll, jolt * 0.06, sw)
			neckP = mix(neckP, 0.1 + cr.pitch + math.sin(now * 16) * 0.05 * sniff - scratch * 0.25 + jolt * 0.2, sw)
			neckY = mix(neckY, cr.yaw * (1 - scratch) - scratch * 0.3, sw)
			neckR = mix(neckR, cr.yaw * -0.3 + jolt * 0.15, sw)
			mouth = mix(mouth, 0.08 + math.abs(math.sin(now * 23)) * 0.08 * sniff + spasm * 0.3, sw)
			for _, side in ipairs({ L, R }) do
				side.S = mix(side.S, -0.05, sw)
				side.E = mix(side.E, 0.15, sw)
				side.H = mix(side.H, 0.25, sw)
				side.K = mix(side.K, -0.45, sw)
				side.Ax = mix(side.Ax, 0, sw)
			end
			-- the scratching claw: lifted, reaching forward and pulling back twice
			R.S += (0.3 * scratch + rake * 0.25 * scratch) * sw
			R.E += 0.45 * scratch * sw
			R.Wx += -0.4 * scratch * sw
		end

		-- the leap is shortened to fit the room in front of it (measured once per attack, at three heights, against the
		-- real wall surface incl. the plinth): the front of the body reaches ~2.1 design units past the lunge at the rake
		if rig.lastShot and cr.measuredShot ~= rig.lastShot then
			cr.measuredShot = rig.lastShot
			cr.reach = 1
			local hrp = model.PrimaryPart
			if hrp then
				local look = Vector3.new(hrp.CFrame.LookVector.X, 0, hrp.CFrame.LookVector.Z)
				if look.Magnitude > 0.1 then
					look = look.Unit
					local floorY = hrp.Position.Y - (model:GetAttribute("RootHeight") or 2) * scale
					local room
					for _, h in ipairs({ 0.3, 1.0, 2.0 }) do
						local d = distanceAhead(Vector3.new(hrp.Position.X, floorY + h * scale, hrp.Position.Z), look, 14)
						if d then
							room = math.min(room or d, d)
						end
					end
					if room then
						local maxLunge = POUNCE[5][3] -- (the deepest forward key, the rake; negative)
						cr.reach = math.clamp((room - 2.1 * scale - 0.15) / (-maxLunge * scale), 0, 1)
					end
				end
			end
		end

		-- fight
		if fw > 0.001 then
			local a = math.min(since, POUNCE[#POUNCE][1])
			local function key(i, lag)
				return sampleKeys(POUNCE, math.max(0, a - (lag or 0)), i)
			end
			local wiggle = (a > 0.05 and a < 0.25) and math.sin((a - 0.05) / 0.2 * math.pi * 3) * 0.12 or 0
			lift = mix(lift, key(2), fw)
			fwd = mix(fwd, key(3) * (cr.reach or 1), fw)
			pitch = mix(pitch, key(4), fw)
			roll = mix(roll, 0, fw)
			yaw = mix(yaw, wiggle, fw)
			spineYaw = mix(spineYaw, -wiggle * 1.3, fw)
			spine = mix(spine, key(5), fw)
			neckP = mix(neckP, key(6), fw)
			neckY = mix(neckY, 0, fw)
			neckR = mix(neckR, 0, fw)
			mouth = mix(mouth, key(7), fw)
			for _, e in ipairs({ { L, 0 }, { R, 0.03 } }) do
				local side, lag = e[1], e[2]
				side.S = mix(side.S, key(8, lag), fw)
				side.E = mix(side.E, key(9, lag), fw)
				side.Wx = mix(side.Wx, key(10, lag), fw)
				side.H = mix(side.H, key(11, lag), fw)
				side.K = mix(side.K, key(12, lag), fw)
				side.Ax = mix(side.Ax, key(13, lag), fw)
			end
		end

		local function sm(name, x)
			local e = cr.sm[name]
			if not e then
				e = { x = x, v = 0 }
				cr.sm[name] = e
			end
			e.x, e.v = springStep(e.x, e.v, x, 900, 60, dt)
			return e.x
		end
		set(rig, "Root", CFrame.new(0, (sm("lift", lift)) * scale + float + rise, sm("fwd", fwd) * scale)
			* ANGLES(sm("pitch", pitch), sm("yaw", yaw), sm("roll", roll)))
		set(rig, "Spine", ANGLES(sm("spine", spine), sm("spineYaw", spineYaw), 0))
		set(rig, "Neck", ANGLES(sm("neckP", neckP), sm("neckY", neckY), sm("neckR", neckR)))
		for name, side in pairs({ L = L, R = R }) do
			local S, E = sm(name .. "S", side.S), sm(name .. "E", side.E)
			local H, K = sm(name .. "H", side.H), sm(name .. "K", side.K)
			set(rig, name .. "Shoulder", ANGLES(S, 0, 0))
			set(rig, name .. "Elbow", ANGLES(E, 0, 0))
			set(rig, name .. "Wrist", ANGLES(-(S + E) + sm(name .. "Wx", side.Wx), 0, 0)) -- (the paw stays level)
			set(rig, name .. "Hip", ANGLES(H, 0, 0))
			set(rig, name .. "Knee", ANGLES(K, 0, 0))
			set(rig, name .. "Ankle", ANGLES(-(H + K) + sm(name .. "Ax", side.Ax), 0, 0)) -- (the foot stays flat)
		end
		jaw = sm("mouth", mouth)
	end

	-- Knell (Pose "Bellbearer"): it carries its own belfry; the right hand holds the bell rope. Built on the classic
	-- principles (roblox-animation skill + anticipation / follow-through / overlap): every layer (idle procession,
	-- walk lean, rope pull, Last Toll) adds into one pose, so nothing snaps; the bell and the veil hang on damped springs
	-- and trail the body (secondary motion).
	--   pull (a = seconds since it started): anticipation 0..0.18 (leans back, both hands climb the rope, looks up),
	--   the yank 0.18..0.28 (eased in: the body snaps forward and dips), the bell rings at 0.26 (KnellFx's clang),
	--   follow-through to 0.9 with a slight overshoot (used for the Last Toll's first two tolls).
	--   Basic attack = a Kamehameha-style THROW in one continuous cycle (no reset to rest): from the charged pose (both
	--   hands at the right hip, the body coiled) the arms are flung forward, palms together (0.22 s: the shockwave leaves
	--   the hands, KnellFx), momentum carries them on, they fall, swing down and back past the hips and gather at the
	--   hip again (1.8 s), charging until the next attack (attackCD 2 s) launches straight out of it. Keyframes are
	--   joined by a Catmull-Rom spline (velocity carries through each key) and a fast spring absorbs timing jitter;
	--   the cycle eases out into the idle when the attacks stop.
	--   The Procession (SpecialAt, 11 s): one hard pull at 0.35 s, it rises and conducts with the left hand, arches back
	--   with the claw's wind-up (6.1..7.1) and dives forward on the rake (7.2).
	if model:GetAttribute("Pose") == "Bellbearer" then
		local function smooth01(x)
			x = clamp01(x)
			return x * x * (3 - 2 * x)
		end
		local function damped(x, amp, freq, decay)
			return x > 0 and amp * math.sin(x * freq) * math.exp(-x * decay) or 0
		end
		local k = rig.knell
		if not k then
			k = { bell = 0, bellV = 0, veil = 0, veilV = 0, roll = 0, rollV = 0 }
			rig.knell = k
		end
		local function spring(x, v, target, stiffness, damping)
			v = v + ((target - x) * stiffness - v * damping) * math.min(dt, 0.05)
			return x + v * math.min(dt, 0.05), v
		end

		-- idle procession + walking lean
		local rS, rE = 0.25 + math.max(0, math.sin(t * 1.6)) ^ 8 * 0.25, 0.45
		local lS, lE, lRoll = 0.12 + math.sin(t * 0.9 + 1) * 0.05, 0.25, 0
		local waist = -0.05 + math.sin(t * 1.8) * 0.02 + 0.18 * w
		local waistRoll = math.sin(t * 0.9) * 0.06
		local neck = 0.06 - 0.06 * w
		local neckYaw = math.sin(t * 0.5) * 0.12
		local lift = 0 -- extra height of the root (design units)
		local bellKick, clap = 0, math.sin(t * 1.7) * 0.05
		rS -= 0.15 * w
		lS -= 0.15 * w

		-- the throw cycle: { t, rS, rE, rY, lS, lE, lY, waist pitch, waist yaw, lift }
		-- { t, rS, rE, rY, lS, lE, lY, waist pitch, waist yaw, lift, rZ, lZ (shoulder rolls, + = the hand inwards) }
		-- the charge pose is the Kamehameha form (user's reference): both forearms held forward at the right hip, the
		-- wrists together, the hands cupped round the orb (the right one a little lower)
		local CHARGE = { 0.05, 1.4, 0.0, -0.15, 1.45, 0.0, -0.06, -0.5, 0.05, 0.45, 1.05 }
		local THROW = {
			{ 0.00, table.unpack(CHARGE) },
			{ 0.22, 1.3, 0.1, 0.25, 1.3, 0.1, -0.25, 0.18, 0.1, -0.2, 0.15, 0.15 }, -- the thrust: straight at the wall, palms together
			{ 0.55, 1.36, 0.05, 0.25, 1.36, 0.05, -0.25, 0.22, 0.12, -0.25, 0.15, 0.15 }, -- held: the push carries on a little
			{ 0.95, 0.75, 1.0, 0.1, 0.7, 1.05, -0.1, 0.1, -0.15, -0.1, 0.25, 0.45 }, -- drawn back: the elbows bend first
			{ 1.35, 0.15, 1.4, 0.0, 0.0, 1.45, 0.0, -0.02, -0.4, 0.0, 0.4, 0.9 }, -- the hands sweep back to the hip
			{ 1.80, table.unpack(CHARGE) }, -- the Kamehameha form again: the charge
		}
		local function sampleThrow(a, c)
			local n = #THROW
			if a <= THROW[1][1] then
				return THROW[1][c]
			end
			if a >= THROW[n][1] then
				return THROW[n][c]
			end
			for i = 1, n - 1 do
				local k1, k2 = THROW[i], THROW[i + 1]
				if a <= k2[1] then
					local f = (a - k1[1]) / (k2[1] - k1[1])
					local p0 = (THROW[i - 1] or k1)[c]
					local p1, p2 = k1[c], k2[c]
					local p3 = (THROW[i + 2] or k2)[c]
					-- Catmull-Rom: the curve keeps its speed through every key (momentum, not ease-to-a-stop)
					return 0.5 * ((2 * p1) + (-p0 + p2) * f + (2 * p0 - 5 * p1 + 4 * p2 - p3) * f * f + (-p0 + 3 * p1 - 3 * p2 + p3) * f * f * f)
				end
			end
			return THROW[n][c]
		end

		-- one pull on the rope; p = power
		local function pull(a, p)
			if a < 0 or a > 0.9 then
				return
			end
			local up = smooth01(a / 0.18) -- anticipation
			local yank = clamp01((a - 0.18) / 0.1) ^ 2 -- the action, eased in
			local back = smooth01((a - 0.28) / 0.62) -- follow-through
			local hold = (1 - yank) * up
			local hit = yank * (1 - back)
			local over = math.sin(clamp01((a - 0.28) / 0.62) * math.pi) * 0.12 * p
			rS += hold * 2.4 + hit * -0.6 - over
			rE += hold * -0.2 + hit * 1.0
			lS += hold * 2.0 + hit * -0.3
			lE += hit * 1.1
			lRoll += hold * -0.35
			waist += hold * -0.22 * p + hit * 0.42 * p - over
			neck += hold * -0.3 + hit * 0.15
			lift += hold * 0.25 - hit * 0.5 * p
			bellKick += damped(a - 0.26, -0.75 * p, 6.5, 2.2)
			clap += damped(a - 0.27, 1.0 * p, 11, 3.2)
		end
		local specialAt = model:GetAttribute("SpecialAt")
		local st = specialAt and workspace:GetServerTimeNow() - specialAt or -1
		local inSpecial = st >= 0 and st < 11.0

		-- the throw: blended in while it fights (eases out ~2.4 s after the last attack, off while walking / the special)
		local rY, lY, waistYaw, rZ, lZ = 0, 0, 0, 0, 0
		-- (DebugThrowT: freezes the throw at that time, for looking at the poses; set it on the client only)
		local debugT = model:GetAttribute("DebugThrowT")
		if (rig.lastShot or debugT) and not inSpecial then
			local a = debugT or (now - rig.lastShot)
			local wA = (a < 2.4 and 1 or 1 - smooth01((a - 2.4) / 0.8)) * (1 - w)
			if wA > 0 then
				local ta = math.min(a, 1.8)
				local tremble = a > 1.5 and math.sin(now * 38) * 0.03 * clamp01((a - 1.5) / 0.3) or 0 -- the charge trembles
				local function mix(base, c)
					return base + (sampleThrow(ta, c) - base) * wA
				end
				rS = mix(rS, 2) + tremble
				rE = mix(rE, 3)
				rY = mix(0, 4)
				lS = mix(lS, 5) - tremble
				lE = mix(lE, 6)
				lY = mix(0, 7)
				rZ = mix(0, 11)
				lZ = mix(0, 12)
				waist = mix(waist, 8)
				waistYaw = mix(0, 9)
				lift = mix(lift, 10)
				bellKick += (damped(a - 0.22, -0.7, 6.5, 2.2)) * wA
				clap += damped(a - 0.23, 1.0, 11, 3.2) * wA
			end
		end
		-- a fast spring on the arm and body channels: absorbs the jump when an attack comes a little early or late
		k.sm = k.sm or {}
		local function smoothed(name, target)
			local e = k.sm[name]
			if not e then
				e = { x = target, v = 0 }
				k.sm[name] = e
			end
			e.x, e.v = spring(e.x, e.v, target, 260, 30)
			return e.x
		end
		if inSpecial then
			-- the Procession (KnellFx): one hard toll, then it rises and conducts the pallbearers with the raised left
			-- hand; as the claw winds up it arches back with it, and dives forward on the rake (7.0 s)
			local conduct = math.min(clamp01((st - 0.6) / 0.8), clamp01((11.0 - st) / 0.7))
			lift += conduct * 1.6
			lS += conduct * 1.3
			lRoll += conduct * 0.35
			neck -= conduct * 0.15
			pull(st - 0.09, 1.6)
			-- the right arm swings WITH the claw, on the same curves: it winds up far back, high and out to the right
			-- (6.1..7.1, still drifting back at the end), rakes diagonally down across the body (7.1..7.22, accelerating)
			-- and its momentum carries it on across (to 8.1, decelerating), then it eases back to conducting
			local function lerp(a0, b0, f)
				return a0 + (b0 - a0) * f
			end
			local COCKED = { rS = 3.0, rE = 0.35, rY = 0.5, rZ = -0.7, waist = -0.35, waistYaw = -0.6, lS = 0.4, lift = 0.6 }
			local THROUGH = { rS = 0.25, rE = 0.15, rY = -0.45, rZ = 0.75, waist = 0.45, waistYaw = 0.55, lS = -0.1, lift = -0.6 }
			local AFTER = { rS = -0.35, rE = 0.5, rY = -0.6, rZ = 0.95, waist = 0.5, waistYaw = 0.7, lS = 0.1, lift = -0.8 }
			local target, wgt
			if st >= 6.1 and st < 7.1 then
				local u = (st - 6.1) / 1.0
				target = table.clone(COCKED)
				target.rS += 0.25 * math.max(0, u - 0.7) / 0.3 -- (the coil keeps tightening: no stop before the blow)
				wgt = smooth01(u)
			elseif st >= 7.1 and st < 7.22 then
				local s = ((st - 7.1) / 0.12) ^ 1.6
				target = {}
				for key, v in pairs(COCKED) do
					target[key] = lerp(v + (key == "rS" and 0.25 or 0), THROUGH[key], s)
				end
				wgt = 1
			elseif st >= 7.22 and st < 8.9 then
				local f = math.min(1, (st - 7.22) / 0.88)
				local e = 1 - (1 - f) ^ 3
				target = {}
				for key, v in pairs(THROUGH) do
					target[key] = lerp(v, AFTER[key], e)
				end
				wgt = 1 - smooth01((st - 8.1) / 0.8)
			end
			if target then
				rS = lerp(rS, target.rS, wgt)
				rE = lerp(rE, target.rE, wgt)
				rY = lerp(rY, target.rY, wgt)
				rZ = lerp(rZ, target.rZ, wgt)
				waist = lerp(waist, target.waist, wgt)
				waistYaw = lerp(waistYaw, target.waistYaw, wgt)
				lS = lerp(lS, target.lS, wgt)
				lift = lerp(lift, target.lift, wgt)
			end
			bellKick += damped(st - 7.2, 0.6, 6, 1.8)
			clap += damped(st - 7.2, 1.2, 11, 3)
		end

		-- secondary motion: the bell swings behind the body (it hangs still in the world while the body leans), the
		-- veil trails backwards when it moves and lags behind every lean
		k.bell, k.bellV = spring(k.bell, k.bellV, -waist * 0.8, 38, 5)
		k.roll, k.rollV = spring(k.roll, k.rollV, -waistRoll * 1.2, 30, 4)
		k.veil, k.veilV = spring(k.veil, k.veilV, -(waist + neck) - 0.12 - 0.35 * w - 0.25 * clamp01(math.abs(lift) / 2), 22, 3.5)

		rS, rE, rY = smoothed("rS", rS), smoothed("rE", rE), smoothed("rY", rY)
		rZ, lZ = smoothed("rZ", rZ), smoothed("lZ", lZ)
		lS, lE, lY = smoothed("lS", lS), smoothed("lE", lE), smoothed("lY", lY)
		waist, waistYaw, lift = smoothed("waist", waist), smoothed("waistYaw", waistYaw), smoothed("lift", lift)
		set(rig, "Root", CFrame.new(0, float + rise + lift * scale, 0))
		set(rig, "Waist", ANGLES(waist, waistYaw, waistRoll))
		-- (the head counters the twist: it keeps looking at the target)
		set(rig, "Neck", ANGLES(neck, neckYaw - waistYaw * 0.6, 0))
		set(rig, "RShoulder", ANGLES(rS, rY, -rZ))
		set(rig, "RElbow", ANGLES(rE, 0, 0))
		set(rig, "LShoulder", ANGLES(lS, lY + 0.1 * lRoll, -lRoll + lZ))
		set(rig, "LElbow", ANGLES(lE, 0, 0))
		set(rig, "BellSwing", ANGLES(k.bell + bellKick, 0, k.roll))
		set(rig, "BellClapper", ANGLES(clap - k.bell * 0.5, 0, 0))
		set(rig, "Veil", ANGLES(k.veil, 0, -waistRoll * 0.8))
	end

	-- "Crucified" pose (model attribute Pose, e.g. Hush): the rig is BUILT in a T pose; it hangs in the air as if nailed
	-- to an invisible cross: arms sag a little, the empty sleeves hang from the elbows and swing, the head hangs to one
	-- side and twitches now and then, the legs dangle with the feet crossed, and the whole body sways slowly
	if model:GetAttribute("Pose") == "Crucified" then
		local sway = math.sin(t * 0.6)
		local sag = 0.12 + breathe
		set(rig, "RShoulder", ANGLES(0, 0, -sag))
		set(rig, "LShoulder", ANGLES(0, 0, sag))
		-- the empty sleeves hang from the elbows (undoing the shoulder sag) in three loose segments (Elbow, Sleeve1,
		-- Sleeve2): each segment is bent a little against the one above (crumpled cloth) and swings with a delay and
		-- more than the one above, so the sleeve dangles like fabric
		for i, side in ipairs({ "R", "L" }) do
			local dir = (side == "R") and 1 or -1
			local p0 = i * 1.7
			local function swing(k, amp)
				local d = k * 0.55 -- each lower segment lags behind
				return math.sin(t * 1.15 + p0 - d) * amp, math.sin(t * 0.85 + p0 * 0.7 - d) * amp * 0.7
			end
			local x1, z1 = swing(0, 0.12)
			local x2, z2 = swing(1, 0.16)
			local x3, z3 = swing(2, 0.2)
			set(rig, side .. "Elbow", ANGLES(x1 + 0.05, 0, dir * sag + z1 + dir * 0.06))
			set(rig, side .. "Sleeve1", ANGLES(x2 - 0.18, 0, z2 - dir * 0.22))
			set(rig, side .. "Sleeve2", ANGLES(x3 + 0.16, 0, z3 + dir * 0.14))
		end
		-- a short twitch of the head every few seconds
		local cycle = (t * 0.17) % 1
		local twitch = (cycle < 0.04) and math.sin(cycle / 0.04 * math.pi) * 0.3 or 0
		set(rig, "Neck", ANGLES(-0.35 - twitch * 0.5, math.sin(t * 0.4) * 0.1, 0.32 + twitch))
		set(rig, "Waist", ANGLES(-0.06 + breathe, 0, sway * 0.03))
		-- legs hang slack, crossed at the ankles, swinging a little
		local swing = math.sin(t * 0.9) * 0.06
		set(rig, "RHip", ANGLES(0.05 + swing, 0, -0.1))
		set(rig, "LHip", ANGLES(-0.03 + swing, 0, 0.1))
		set(rig, "RKnee", ANGLES(-0.15, 0, 0))
		set(rig, "LKnee", ANGLES(-0.2, 0, 0))
		set(rig, "Root", CFrame.new(0, float + rise, 0) * ANGLES(0, math.sin(t * 0.3) * 0.08, sway * 0.05))

		-- the finger-beam attack (AttackStyle "FingerBeam"): while the unit is fighting (it shot within the last
		-- AttackCD + 0.8 s and is not walking) the right sleeve stays raised, pointing straight at the wall, and the claw
		-- finger stays out of the sleeve opening; every shot (FingerBeam.lua draws circle + beam) only adds a small recoil.
		-- The sleeve drops again when the unit walks or has nothing left to shoot.
		if style == "FingerBeam" then
			local cd = model:GetAttribute("AttackCD") or 2
			local spAt = model:GetAttribute("SpecialAt")
			local inSpecial = spAt ~= nil and (workspace:GetServerTimeNow() - spAt) < 9.6 -- (no basic shots during a special)
			local fighting = state ~= "walk" and ((rig.lastShot ~= nil and (now - rig.lastShot) < cd + 0.8) or inSpecial)
			rig.hold = (rig.hold or 0) + ((fighting and 1 or 0) - (rig.hold or 0)) * clamp01(dt * 5)
			local k = rig.hold * rig.hold * (3 - 2 * rig.hold) -- smoothstep
			local ext = math.clamp((rig.hold - 0.45) / 0.45, 0, 1)
			local recoil = 0
			if rig.lastShot then
				local since = now - rig.lastShot - 0.5 -- the beam fires 0.5 s after the attack starts
				if since > 0 and since < 0.3 then
					recoil = math.sin(since / 0.3 * math.pi) * 0.12
				end
			end
			local rest = Vector3.new(math.cos(math.rad(32)), -math.sin(math.rad(32)), 0) -- the upper arm at rest (build_hush.lua)
			local function fromTo(a, b)
				local axis = a:Cross(b)
				if axis.Magnitude < 1e-4 then return CFrame.new() end
				return CFrame.fromAxisAngle(axis.Unit, math.acos(math.clamp(a:Dot(b), -1, 1)))
			end
			local aim = Vector3.new(-0.08, 0.06 + recoil, -1).Unit -- straight ahead at the wall, a touch inward and up
			local shoulder = fromTo(rest, aim)
			local elbow = fromTo(Vector3.new(0, -1, 0), rest) -- the hanging sleeve lines up with the arm
			local function blend(name, target)
				local joint = rig.joints[name]
				if joint then
					joint.Transform = joint.Transform:Lerp(target, k)
				end
			end
			if k > 0.001 then
				blend("RShoulder", shoulder)
				blend("RElbow", elbow)
				blend("RSleeve1", CFrame.new())
				blend("RSleeve2", CFrame.new())
				blend("Neck", ANGLES(0.05, 0, 0.12)) -- the head lifts toward the wall
			end
			set(rig, "RFinger", CFrame.new(0, -1.6 * ext + recoil * 0.6, 0))
		end

		-- the Rift Chains special (SpecialFx.lua draws the rip and the chains from the same server clock). The finger stays
		-- in the sleeve; the whole body acts it out: wind-up (sleeve out to the side, leaning back and twisting), a quick
		-- slash, hunched over the rip with both sleeves raised, slowly pulling the chains out, a short gathering pull, both
		-- arms flung up as the chains scatter (arching back, rising), thrown down at the wall (leaning in), shudders at the
		-- impacts, a jolt back from the explosions, and back into the aiming stance. Keyframes are blended over the pose
		-- set above (fading in and out), so it starts and ends smoothly.
		local specialAt = model:GetAttribute("SpecialAt")
		if specialAt and model:GetAttribute("SpecialKind") == "RiftChains" then
			local st = workspace:GetServerTimeNow() - specialAt
			if st >= 0 and st < 8.8 then
				local function v(x, y, z) return Vector3.new(x, y, z).Unit end
				local restR = v(math.cos(math.rad(32)), -math.sin(math.rad(32)), 0) -- the upper arms at rest (build_hush.lua)
				local restL = v(-restR.X, restR.Y, 0)
				local fwdR = v(-0.08, 0.06, -1)
				-- t, right arm, left arm, sleeves along the arm (1) or hanging (0), waist pitch / yaw, neck pitch / roll, rise
				local F = {
					{ 0, fwdR, restL, 1, -0.06, 0, -0.1, 0.15, 0 },
					{ 0.7, v(1, 0.25, 0.2), restL, 1, 0.18, 0.25, 0.2, 0, 0.3 },
					{ 0.9, v(1, 0.28, 0.25), restL, 1, 0.22, 0.3, 0.22, 0, 0.35 },
					{ 1.05, v(-0.55, -0.5, -0.7), v(-0.5, -0.3, 0.2), 1, -0.25, -0.35, -0.15, 0, 0 },
					{ 1.7, v(0.35, -0.1, -1), v(-0.35, -0.1, -1), 0, -0.2, 0, -0.3, 0.1, -0.2 },
					{ 5.0, v(0.25, 0.05, -1), v(-0.25, 0.05, -1), 0, -0.3, 0, -0.38, -0.1, -0.35 },
					{ 5.3, v(0.6, -0.2, -0.5), v(-0.6, -0.2, -0.5), 0.5, -0.1, 0, -0.1, 0, -0.1 },
					{ 5.55, v(0.45, 1, -0.15), v(-0.45, 1, -0.15), 1, 0.35, 0, 0.5, 0, 1.1 },
					{ 6.0, v(0.4, 1, -0.2), v(-0.4, 1, -0.2), 1, 0.3, 0, 0.42, 0, 1.2 },
					{ 6.6, v(0.15, -0.25, -1), v(-0.15, -0.25, -1), 1, -0.32, 0, -0.25, 0, 0.4 },
					{ 7.55, v(0.15, -0.2, -1), v(-0.15, -0.2, -1), 0.6, -0.25, 0, -0.2, 0, 0.25 },
					{ 7.75, v(0.25, 0.1, -1), v(-0.25, 0.1, -1), 0.6, 0.18, 0, 0.28, 0, 0.55 },
					{ 8.4, fwdR, restL, 1, -0.06, 0, -0.1, 0.15, 0 },
					{ 8.8, fwdR, restL, 1, -0.06, 0, -0.1, 0.15, 0 },
				}
				local k0, k1, f = F[1], F[2], 0
				for i = 1, #F - 1 do
					if st >= F[i][1] and st < F[i + 1][1] then
						k0, k1 = F[i], F[i + 1]
						f = (st - k0[1]) / (k1[1] - k0[1])
						f = f * f * (3 - 2 * f)
						break
					end
				end
				local function num(i) return k0[i] + (k1[i] - k0[i]) * f end
				local function dir(i) return k0[i]:Lerp(k1[i], f).Unit end
				local aimR, aimL, along = dir(2), dir(3), num(4)
				local wp, wy, np, nr, rise2 = num(5), num(6), num(7), num(8), num(9)
				-- slow pulling motion while the chains creep out, shudders at the impacts
				if st > 1.7 and st < 5.3 then
					local pull = math.sin(st * 2.6) * 0.12
					aimR = (aimR + Vector3.new(0, pull, pull * 0.5)).Unit
					aimL = (aimL + Vector3.new(0, pull, pull * 0.5)).Unit
				end
				if st > 6.6 and st < 7.3 then
					wp += math.sin(now * 38) * 0.05
					np += math.sin(now * 33 + 1) * 0.06
				end
				local function fromTo(a, b)
					local axis = a:Cross(b)
					if axis.Magnitude < 1e-4 then return CFrame.new() end
					return CFrame.fromAxisAngle(axis.Unit, math.acos(math.clamp(a:Dot(b), -1, 1)))
				end
				-- fade in over 0.15 s and out over the last 0.4 s
				local w = math.clamp(st / 0.15, 0, 1) * math.clamp((8.8 - st) / 0.4, 0, 1)
				local function blend(name, target)
					local joint = rig.joints[name]
					if joint then
						joint.Transform = joint.Transform:Lerp(target, w)
					end
				end
				local down = Vector3.new(0, -1, 0)
				for _, arm in ipairs({ { "R", restR, aimR }, { "L", restL, aimL } }) do
					local side, rest, aimDir = arm[1], arm[2], arm[3]
					local shoulder = fromTo(rest, aimDir)
					blend(side .. "Shoulder", shoulder)
					-- the sleeve either streams along the arm or hangs straight down (undoing the arm's rotation)
					blend(side .. "Elbow", shoulder:Inverse():Lerp(fromTo(down, rest), along))
					blend(side .. "Sleeve1", ANGLES(math.sin(t * 1.3) * 0.12 * (1 - along), 0, 0))
					blend(side .. "Sleeve2", ANGLES(math.sin(t * 1.3 - 0.6) * 0.16 * (1 - along), 0, 0))
				end
				set(rig, "RFinger", CFrame.new()) -- the finger stays in the sleeve during the special
				blend("Waist", ANGLES(wp, wy, 0))
				blend("Neck", ANGLES(np, 0, nr))
				blend("Root", CFrame.new(0, float + rise + rise2 * scale, 0) * ANGLES(0, wy * 0.4, 0))
			end
		end
	end

	-- wings (bats and other fliers): LWing/RWing flap up and down around Z; they flap faster while moving
	if (rig.joints.LWing or rig.joints.RWing) and model:GetAttribute("Pose") ~= "Bat" then -- (the Crypt Bat flies in its own block)
		local flap = math.sin(t * (9 + 5 * w)) * 0.55 + 0.15
		set(rig, "RWing", ANGLES(0, 0, flap))
		set(rig, "LWing", ANGLES(0, 0, -flap))
	end
	set(rig, "Jaw", ANGLES(jaw, 0, 0))
end

CollectionService:GetInstanceAddedSignal(TAG):Connect(register)
CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(model)
	rigs[model] = nil
end)
for _, model in ipairs(CollectionService:GetTagged(TAG)) do
	register(model)
end

local StunFx = require(script.Parent.StunFx)

RunService.RenderStepped:Connect(function(dt)
	local now = os.clock()
	local serverNow = workspace:GetServerTimeNow()
	for model, rig in pairs(rigs) do
		if model.Parent == nil then
			rigs[model] = nil
		elseif not StunFx.isStunned(model, serverNow) then -- a unit bound by the titan's tremor holds its pose
			animate(model, rig, dt, now)
		end
	end
end)

return {
	isCasting = isCasting, -- (model) -> true while a staff caster is in attack mode
	castAmount = function(model) -- (model) -> 0..1, how far the staff is raised
		local rig = rigs[model]
		return rig and rig.cast or 0
	end,
}
