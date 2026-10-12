-- Procedural animation for rigged units (models tagged "ProceduralUnit").
--
-- The server only sets attributes on the model:
--   State = "walk" | "idle"  (idle = standing and attacking)
--   AttackCount             (incremented on every attack; the swing plays on each change)
--   Speed, AttackCD         (walk speed in studs/s, seconds between attacks)
-- and optionally, set once on the model: Float (hover bob amplitude in studs, for floating units)
-- Optional joints besides the humanoid ones: LWing/RWing (flapping wings, positive Z rotation raises the right wing).
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
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("Motor6D") then
			joints[d.Name] = d
		end
	end
	rigs[model] = {
		joints = joints,
		phase = math.random() * math.pi * 2,
		walk = 1, -- 0..1 blend between standing and walking
		attackStart = nil,
		lastCount = model:GetAttribute("AttackCount") or 0,
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
	if count ~= rig.lastCount then
		rig.lastCount = count
		rig.attackStart = now
	end
	local attackDur = math.min(0.55, (model:GetAttribute("AttackCD") or 1) * 0.85)
	local u = rig.attackStart and (now - rig.attackStart) / attackDur
	if u and u >= 1 then
		rig.attackStart = nil
		u = nil
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
	set(rig, "Root", CFrame.new(0, bob + float, 0))

	-- arms (left arm swings with the right leg; the sword arm swings less)
	local idleElbow = 0.25 + 0.15 * w
	local rShoulder = s * 0.3 * w + breathe
	local rElbow = idleElbow
	local waistPitch = 0.06 * w + breathe
	local waistRoll = s * 0.07 * w
	local jaw = math.max(0, math.sin(t * 5)) * 0.06 * (1 - w)

	if u then
		local shoulder, elbow, lean, mouth = attackPose(u)
		rShoulder, rElbow, waistPitch, jaw = shoulder, elbow, lean, mouth
	end

	set(rig, "LShoulder", ANGLES(-s * 0.6 * w - breathe, 0, 0))
	set(rig, "LElbow", ANGLES(idleElbow, 0, 0))
	set(rig, "RShoulder", ANGLES(rShoulder, 0, 0))
	set(rig, "RElbow", ANGLES(rElbow, 0, 0))
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

return {}
