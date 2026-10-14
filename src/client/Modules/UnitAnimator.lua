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
