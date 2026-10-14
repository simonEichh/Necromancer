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
