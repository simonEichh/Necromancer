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
	return math.min(0.55, (model:GetAttribute("AttackCD") or 1) * 0.85)
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
	elseif u then
		local shoulder, elbow, lean, mouth = attackPose(u)
		rShoulder, rElbow, waistPitch, jaw = shoulder, elbow, lean, mouth
	end

	set(rig, "LShoulder", ANGLES(lShoulder, 0, 0))
	set(rig, "LElbow", ANGLES(lElbow, 0, 0))
	set(rig, "RShoulder", ANGLES(rShoulder, 0, 0))
	set(rig, "RElbow", ANGLES(rElbow, 0, 0))
	set(rig, "RStaff", ANGLES(staffRot, 0, 0))
	set(rig, "Waist", ANGLES(waistPitch, 0, waistRoll))
	set(rig, "Neck", ANGLES(-0.04 * w, math.sin(t * 0.8) * 0.12 * (1 - w), 0))

	-- wings (bats and other fliers): LWing/RWing flap up and down around Z; they flap faster while moving
	if rig.joints.LWing or rig.joints.RWing then
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

RunService.RenderStepped:Connect(function(dt)
	local now = os.clock()
	for model, rig in pairs(rigs) do
		if model.Parent == nil then
			rigs[model] = nil
		else
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
