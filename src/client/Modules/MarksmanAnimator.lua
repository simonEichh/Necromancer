-- Veyr's procedural animation (model attribute Pose = "Marksman", tools/studio/build_veyr.lua; docs/veyr.md).
-- Called by UnitAnimator every frame for his model; it sets every joint of his rig itself.
--
-- He is BUILT shouldering the rifle (the aim pose). The rifle hangs on its own joint (Rifle: torso -> RifleRoot, the
-- pivot at the shoulder pocket) and both arms are re-solved every frame by two-bone IK onto the wrist positions the
-- build gave them relative to the rifle, so whatever the rifle does (lowered, recoil, the bolt canting it) the hands
-- stay on it. All of it is worked out in the torso's build space, where every joint frame is axis-aligned, so a
-- Motor6D.Transform there is just the rotation itself.
--
-- His character: unnaturally still. A slow, irregular hover; a slow gliding step when he moves; a controlled low ready
-- with the rifle across his body when he is not shooting; small head corrections as if he sees something far away.
-- Every channel runs through a spring, so nothing snaps back to rest (Knell's momentum rule). Cloth (mantle strips,
-- ribbons, robe, the hood's peak) and the shards lag behind his moves, each on its own spring and phase.
--
-- The basic attack, DEAD RECKONING (shared VeyrTimeline, from the server time ShotAt, or the AttackCount change as a
-- fallback): settle into the shoulder (0-0.9 s), focus (the rings, 0.9-2.2), everything settles and stills
-- (2.2-3.15), the shot (3.2): rifle kicks up and back, the shoulder and torso absorb it, the head rocks, mantle and
-- shards react a little later; the rifle comes back down through a controlled arc, then the right hand works the bolt
-- (lift, back, forward, down) and returns to the grip; stillness. VeyrShot.lua draws the rings, the round and the hit.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VeyrTimeline = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("VeyrTimeline"))
local VeyrSpecial = require(script.Parent.VeyrSpecial) -- (the special's shard stations)
local Units = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Units"))
local SP = VeyrTimeline.SPECIAL
local FN = VeyrTimeline.FINISHER
local VeyrFinisher -- (required lazily: it requires modules that load after this one)
local function finisherState(model)
	if not VeyrFinisher then
		local ok, mod = pcall(require, script.Parent.VeyrFinisher)
		VeyrFinisher = ok and mod or false
	end
	return VeyrFinisher and VeyrFinisher.state(model) or nil
end

local ANGLES = CFrame.Angles
local FLY_HEIGHT = 1.8 -- studs he floats above his build height (in the world; portraits too)
local Marksman = {}

local function clamp01(x)
	return math.clamp(x, 0, 1)
end
local function ease(x, a, b) -- 0..1 between a and b, smoothstep
	local k = clamp01((x - a) / (b - a))
	return k * k * (3 - 2 * k)
end

-- a scalar damped spring kept in table `st` under `key` (substeps keep stiff springs stable at low frame rates)
local function spring(st, key, target, stiffness, damping, dt)
	local x = st[key]
	if x == nil then
		x = target
	end
	local v = st[key .. "_v"] or 0
	local steps = math.max(1, math.ceil(dt / (1 / 120)))
	local h = dt / steps
	for _ = 1, steps do
		v += ((target - x) * stiffness - v * damping) * h
		x += v * h
	end
	st[key], st[key .. "_v"] = x, v
	return x
end
local function kick(st, key, dv)
	st[key .. "_v"] = (st[key .. "_v"] or 0) + dv
end

-- two-bone solve: the elbow for a limb from S to W (lengths a, b), bending towards `pole`
local function solveJoint(S, W, a, b, pole)
	local d = W - S
	local dist = math.clamp(d.Magnitude, 0.05, a + b - 0.005)
	local u = d.Magnitude > 1e-4 and d.Unit or Vector3.new(0, -1, 0)
	local cosA = math.clamp((a * a + dist * dist - b * b) / (2 * a * dist), -1, 1)
	local p = pole - u * pole:Dot(u)
	p = p.Magnitude > 1e-4 and p.Unit or Vector3.new(0, -1, 0)
	return S + (u * cosA + p * math.sqrt(1 - cosA * cosA)) * a
end
-- an orthonormal frame from a limb direction u and the next limb's direction f (u along X, the bend plane's normal Z)
local function frameOf(u, f)
	local z = u:Cross(f)
	if z.Magnitude < 1e-4 then
		z = u:Cross(Vector3.new(0, 1, 0))
		if z.Magnitude < 1e-4 then
			z = Vector3.new(0, 0, 1)
		end
	end
	z = z.Unit
	local y = z:Cross(u)
	return CFrame.fromMatrix(Vector3.zero, u, y, z)
end

-- ====================================================================
-- Setup: the build-space geometry the IK needs, read from the joints (so it follows the model's scale)
-- ====================================================================
local function setup(model, rig)
	local j = rig.joints
	local rJ = j.Rifle
	if not (rJ and j.RShoulder and j.LShoulder and j.RElbow and j.LElbow and j.RWrist and j.LWrist) then
		return nil
	end
	local mk = { st = {} }
	local TB = rJ.C0.Rotation:Inverse() -- torso local -> build axes (the rifle's joint frame has no rotation in the build)
	mk.TB = TB
	mk.pivot = (TB * rJ.C0).Position
	local rifleBuild = TB * rJ.C0 * rJ.C1:Inverse()
	mk.arms = {}
	for _, side in ipairs({ "R", "L" }) do
		local sJ, eJ, wJ = j[side .. "Shoulder"], j[side .. "Elbow"], j[side .. "Wrist"]
		local S = (TB * sJ.C0).Position
		local upperBuild = TB * sJ.C0 * sJ.C1:Inverse()
		local E = (upperBuild * eJ.C0).Position
		local foreBuild = upperBuild * eJ.C0 * eJ.C1:Inverse()
		local W = (foreBuild * wJ.C0).Position
		local u0, f0 = (E - S).Unit, (W - E).Unit
		-- the build's bend direction: from the shoulder-wrist line towards the elbow
		local sw = (W - S).Unit
		local bend = (E - S) - sw * (E - S):Dot(sw)
		mk.arms[side] = {
			S = S, E = E, W = W, a = (E - S).Magnitude, b = (W - E).Magnitude,
			pole = bend.Magnitude > 1e-4 and bend.Unit or Vector3.new(0, -1, 0),
			Fu = frameOf(u0, f0), Ff = frameOf(f0, u0),
			wristInRifle = rifleBuild:PointToObjectSpace(W),
		}
	end
	-- the bolt: its knob in the bolt's frame, the bolt joint's frame on the rifle
	local bJ = j.Bolt
	local knob = model:FindFirstChild("BoltKnob", true)
	if bJ and knob and bJ.Part1 then
		mk.bolt = { J = bJ, knobInBolt = bJ.Part1.CFrame:PointToObjectSpace(knob.Position) }
		mk.rifleBuild = rifleBuild
	end
	mk.rifleBuild = rifleBuild
	-- cloth and shards
	mk.mantle = {}
	mk.robe = {}
	mk.shards = {}
	for name, joint in pairs(j) do
		local mi = joint:GetAttribute("MantleIndex")
		if mi then
			table.insert(mk.mantle, { name = name, i = mi, k = joint:GetAttribute("Segment") or 1, thin = joint:GetAttribute("Thin") == true })
		elseif joint:GetAttribute("CoatAngle") and name:sub(1, 4) == "Robe" then
			table.insert(mk.robe, { name = name, a = math.rad(joint:GetAttribute("CoatAngle")) })
		elseif name:match("^Shard%d+$") then
			local idx = tonumber(name:sub(6))
			-- turns a build-space offset into the shard joint's own frame
			table.insert(mk.shards, { name = name, i = idx, inv = (TB * joint.C0).Rotation:Inverse(), ph = idx * 1.7 })
		end
	end
	mk.muzzle = model:FindFirstChild("Muzzle", true)
	local eye = model:FindFirstChild("EyeLight", true)
	mk.eyeLight = eye and eye:FindFirstChildOfClass("PointLight")
	mk.eyeBase = mk.eyeLight and mk.eyeLight.Brightness or 0
	mk.nextGlance = 0
	return mk
end

-- solve one arm onto a wrist target (build space) with the hand turned by `handRot`
local function solveArm(rig, side, arm, Wt, handRot)
	local E2 = solveJoint(arm.S, Wt, arm.a, arm.b, arm.pole)
	local u1, f1 = (E2 - arm.S).Unit, (Wt - E2).Unit
	local R1 = frameOf(u1, f1) * arm.Fu:Inverse()
	local R2 = frameOf(f1, u1) * arm.Ff:Inverse()
	local j = rig.joints
	j[side .. "Shoulder"].Transform = R1
	j[side .. "Elbow"].Transform = R1:Inverse() * R2
	j[side .. "Wrist"].Transform = R2:Inverse() * handRot
end

-- ====================================================================
-- Every frame
-- ====================================================================
function Marksman.animate(model, rig, dt, now, ctx)
	local mk = rig.marksman
	if mk == nil or (mk == false and (rig.mkRetry or 0) < now) then
		mk = setup(model, rig) or false
		rig.marksman = mk
		rig.mkRetry = now + 1 -- (StreamingEnabled: the joints may still be arriving)
	end
	if not mk then
		return
	end
	local st = mk.st
	local set = ctx.set
	local scale = ctx.scale
	local state = ctx.state
	dt = math.min(dt, 1 / 20)
	-- (dev: model attribute AnimTimeScale plays him in slow motion, to inspect the beats of a shot)
	local ts = model:GetAttribute("AnimTimeScale")
	local serverNow = workspace:GetServerTimeNow()
	if ts then
		dt *= ts
		mk.slowT = (mk.slowT or now) + dt
		now = mk.slowT
		mk.slowShot = (mk.slowShot or 0) + dt
	end
	local t = now + rig.t0

	-- ── glide and turn rate (like Malak's Envoy block)
	rig.glide = (rig.glide or 0) + ((state == "walk" and 1 or 0) - (rig.glide or 0)) * clamp01(dt * 2)
	local glide = rig.glide
	local look = model:GetPivot().LookVector
	local yaw = math.atan2(-look.X, -look.Z)
	local dyaw = rig.mkYaw and ((yaw - rig.mkYaw + math.pi) % (2 * math.pi) - math.pi) or 0
	rig.mkYaw = yaw
	rig.mkTurn = (rig.mkTurn or 0) + ((dt > 0 and dyaw / dt or 0) - (rig.mkTurn or 0)) * clamp01(dt * 4)
	local turn = math.clamp(rig.mkTurn, -3, 3)

	-- ── the attack clock: ShotAt (server time) if the server sends it, else the AttackCount change
	local shotAt = model:GetAttribute("ShotAt")
	local count = model:GetAttribute("AttackCount") or 0
	if shotAt and shotAt ~= mk.shotAt then
		mk.shotAt = shotAt
		mk.start = shotAt
		mk.count = count
	elseif count ~= mk.count then
		mk.count = count
		if not shotAt or shotAt == mk.shotAt and serverNow - shotAt > 1 then
			mk.start = serverNow
		end
	end
	if mk.start ~= mk.slowFor then
		mk.slowFor = mk.start
		mk.slowShot = 0
	end
	local sa = mk.start and (ts and mk.slowShot or (serverNow - mk.start)) or math.huge
	local T = VeyrTimeline
	local fighting = state ~= "walk" and sa < T.SETTLE_END + T.HOLD
	local inCycle = sa >= 0 and sa < T.SETTLE_END

	-- the beats of one shot (0 outside the cycle)
	local focus = inCycle and ease(sa, T.RINGS_FROM, T.LOCK) * (1 - ease(sa, T.FIRE, T.FIRE + 0.3)) or 0
	local lock = inCycle and ease(sa, T.LOCK, T.QUIET - 0.2) * (1 - ease(sa, T.FIRE, T.FIRE + 0.15)) or 0
	-- his special, THE LONG GOODBYE (VeyrTimeline.SPECIAL; VeyrSpecial draws it): planted, still, the mantle pulled
	-- forward into the gathering, a far heavier recoil, then the bolt
	local spAt = model:GetAttribute("SpecialKind") == "LongGoodbye" and model:GetAttribute("SpecialAt")
	local sp = spAt and (serverNow - spAt) or math.huge
	local inSpecial = sp >= 0 and sp < SP.END
	local spW = inSpecial and ease(sp, 0, SP.PLANT) * (1 - ease(sp, SP.END - 1.2, SP.END)) or 0
	local spState0 = inSpecial and VeyrSpecial.state(model) or nil
	local spStill = inSpecial and ease(sp, SP.LOCK_FROM - 0.6, SP.LOCK_FROM) * (1 - ease(sp, SP.FIRE, SP.FIRE + 0.4)) or 0
	local pull = inSpecial and ease(sp, SP.LOCK_FROM - 1, SP.FIRE - 0.4) * (1 - ease(sp, SP.FIRE, SP.FIRE + 0.25)) or 0
	if inSpecial then
		fighting = true
		inCycle = false -- (no basic cycle while it plays: the server holds his shots)
		focus, lock = math.max(0, spStill * 0.8), spStill
	end
	-- his gate finisher, THE FINAL HORIZON (VeyrTimeline.FINISHER; VeyrFinisher sets the client-only attribute FinisherAt
	-- = the server's start): he seats one round, holds absolutely still, fires once (the world freezes: so does he),
	-- then lowers the rifle, works the bolt and turns his back on the gate before it erupts
	local finAt = model:GetAttribute("FinisherAt")
	local ft = finAt and (serverNow - finAt) or math.huge
	local inFin = ft >= 0 and ft < FN.END
	local finState = inFin and finisherState(model) or nil
	local finTurn = inFin and ease(ft, FN.TURN + 0.6, FN.TURN + 2.8) or 0
	-- his flight: up and back along the lane (fast off the perch, easing into the peak), and down again after the shot;
	-- the momentum tilts him forward while he rises
	local flightUp, flightBack, flightTilt = 0, 0, 0
	if inFin then
		local rise = ease(ft, FN.ASCENT_FROM, FN.ASCENT_TO)
		rise = 1 - (1 - rise) ^ 2 -- (a hard launch that slows into the peak)
		local fall = ease(ft, FN.DESCEND_FROM, FN.DESCEND_TO)
		local h = rise * (1 - fall)
		flightUp = FN.PEAK_HEIGHT * h
		flightBack = FN.PEAK_BACK * h
		local speedUp = math.sin(math.pi * math.clamp((ft - FN.ASCENT_FROM) / (FN.ASCENT_TO - FN.ASCENT_FROM), 0, 1))
		flightTilt = -0.42 * speedUp * (1 - ease(ft, FN.ASCENT_TO - 1, FN.ASCENT_TO))
		mk.flightSpeed = speedUp + 0.6 * math.sin(math.pi * math.clamp((ft - FN.DESCEND_FROM) / (FN.DESCEND_TO - FN.DESCEND_FROM), 0, 1))
	else
		mk.flightSpeed = 0
	end
	if inFin then
		fighting = finTurn < 0.5
		inCycle = false
		local finStill = ease(ft, FN.STILL - 0.6, FN.STILL) * (1 - ease(ft, FN.FIRE, FN.FIRE + 0.3))
		focus = math.max(ease(ft, FN.LOCK, FN.CHARGE) * (1 - ease(ft, FN.FIRE, FN.FIRE + 0.3)), finStill)
		lock = finStill
		if ft >= FN.FIRE and mk.finFiredFor ~= finAt then
			mk.finFiredFor = finAt
			if ft < FN.FIRE + 0.08 then
				kick(st, "rPitch", 1.4)
				kick(st, "rBack", 6)
				kick(st, "wYaw", -3.8)
				kick(st, "rootBack", 5.5)
				mk.clothKickAt = now + 0.07
				mk.clothKickMul = 2.5
			end
		end
		if ft >= FN.GATE_HIT and mk.finEruptFor ~= finAt then
			mk.finEruptFor = finAt
			mk.clothKickAt = now + 0.15 -- (the blast's wind from behind him)
			mk.clothKickMul = 1.6
		end
	end
	local still = math.max(focus * 0.6, lock) -- how far the idle motion is suppressed
	if inSpecial and sp >= SP.FIRE and mk.spFiredFor ~= spAt then
		mk.spFiredFor = spAt
		if sp < SP.FIRE + 0.5 then
			-- the same horizontal recoil as his basic shot, far heavier
			kick(st, "rPitch", 1.3)
			kick(st, "rBack", 5.5)
			kick(st, "wYaw", -3.4)
			kick(st, "rootBack", 5)
			mk.clothKickAt = now + 0.07
			mk.clothKickMul = 2.2
		end
	end
	-- the shot: one impulse through the chain, the cloth and shards a moment later
	if inCycle and sa >= T.FIRE and mk.firedFor ~= mk.start then
		mk.firedFor = mk.start
		if sa < T.FIRE + 0.5 then -- (joining late: no recoil from an old shot)
			-- (a trained marksman (the user's call): the recoil goes straight back into the shoulder, the right shoulder
			-- is driven back so the chest twists, the body slides back a little; only a small muzzle hop (~2.5 deg,
			-- settles fast), no head or torso pitch)
			kick(st, "rPitch", 0.7)
			kick(st, "rBack", 2.6)
			kick(st, "wYaw", -1.6)
			kick(st, "rootBack", 2.2)
			mk.clothKickAt = now + 0.07
		end
	end
	if mk.clothKickAt and now >= mk.clothKickAt then
		mk.clothKickAt = nil
		local mul = mk.clothKickMul or 1
		mk.clothKickMul = nil
		for _, m in ipairs(mk.mantle) do
			kick(st, m.name, -(0.9 + m.k * 0.35) * (m.thin and 1.4 or 1) * mul)
		end
		for _, r in ipairs(mk.robe) do
			kick(st, r.name, -0.6 * mul)
		end
		for _, s in ipairs(mk.shards) do
			kick(st, s.name .. "z", (2.2 + (s.i % 3) * 0.5) * mul)
		end
		kick(st, "tail", -1.5 * mul)
	end

	-- the bolt: lift, draw back, push forward, down (in seconds of the cycle)
	local boltLift, boltBack, boltHand = 0, 0, 0
	local bt -- (seconds into a bolt cycle: after his basic shot, or after the special's)
	if inCycle then
		bt = sa - T.BOLT_FROM
	elseif inSpecial then
		bt = sp - (SP.BREAK + 0.6)
	elseif inFin then
		bt = ft < FN.TURN and (ft - (FN.SEAT - 1.0)) or (ft - (FN.TURN + 0.3))
	end
	if bt then
		local len = T.BOLT_TO - T.BOLT_FROM
		boltHand = ease(bt, 0, 0.3) * (1 - ease(bt, len - 0.25, len + 0.05))
		boltLift = ease(bt, 0.3, 0.45) * (1 - ease(bt, len - 0.42, len - 0.28))
		boltBack = ease(bt, 0.48, 0.68) * (1 - ease(bt, 0.78, 0.98))
	end

	-- ── how far he holds the rifle up: aimed while fighting, the low ready otherwise (slow, deliberate)
	local aimTarget = (fighting or (inCycle and state ~= "walk")) and 1 or 0
	local aim = spring(st, "aim", aimTarget, 7, 5.2, dt)
	local low = 1 - clamp01(aim)

	-- idle drift (suppressed in the focus): slow, irregular, never on one sine
	local drift = 1 - still
	local sway1 = (math.sin(t * 0.53) + 0.6 * math.sin(t * 1.37 + 1.3)) * drift
	local sway2 = (math.sin(t * 0.41 + 2.1) + 0.5 * math.sin(t * 1.11)) * drift
	local breathe = math.sin(t * 1.6) * drift -- (a skeleton barely breathes: tiny settling)

	-- ── the rifle (pivot at the shoulder pocket; + pitch = muzzle up, + yaw = muzzle to his left, back = +Z)
	local rPitch = spring(st, "rPitch", -0.42 * low + 0.006 * sway1 - 0.05 * boltHand + 0.04 * glide * low, 46, 9.5, dt)
	local rYaw = spring(st, "rYaw", 0.36 * low + 0.004 * sway2 + turn * 0.05, 30, 8.5, dt)
	local rRoll = spring(st, "rRoll", -0.22 * low + 0.16 * boltHand, 34, 8, dt)
	local rBack = spring(st, "rBack", 0.06 * low, 70, 12, dt)
	local rDrop = spring(st, "rDrop", 0.22 * low, 30, 8.5, dt)
	-- ── his perch (Units.Veyr.perch, the user's call): at his post he rises high into the air and drifts out past the
	-- lane's edge on his side (model attribute PerchSide, from the server); gliding there he stays low. Not in portraits.
	if mk.portrait == nil then
		mk.portrait = model:FindFirstAncestorWhichIsA("ViewportFrame") ~= nil
	end
	local perchDef = Units.Stats[model.Name] and Units.Stats[model.Name].perch
	local side = model:GetAttribute("PerchSide")
	local perchW = spring(st, "perch", (perchDef and side and not mk.portrait and state ~= "walk") and 1 or 0, 2.4, 3, dt)
	local perchOffset = perchDef and side and Vector3.new(side * perchDef.out * perchW, perchDef.height * perchW, 0) * scale
		or Vector3.zero

	-- what he aims at: the special's corridor, else his last shot's spot on the wall while he fights
	local pivot = model:GetPivot()
	local target
	if inFin then
		target = finState and finState.gate or model:GetAttribute("AimPos")
	elseif inSpecial then
		target = (spState0 and spState0.ready) and spState0.surface or model:GetAttribute("SpecialAim")
	elseif fighting or inCycle then
		target = model:GetAttribute("AimPos")
	end
	-- his whole body turns towards it (the perch puts it off to the side and below him): a yaw on the Root
	local yawNeed = 0
	if target then
		local rootPos = (pivot * CFrame.new(perchOffset)).Position
		local l = pivot:VectorToObjectSpace(target - rootPos)
		yawNeed = math.atan2(-l.X, -l.Z) * clamp01(aim)
		if inFin then
			yawNeed = math.atan2(-l.X, -l.Z) + finTurn * 2.5 -- (he turns his back on the gate)
		end
	end
	local bodyYaw = spring(st, "bodyYaw", yawNeed, 14, 6.5, dt)

	-- during the special the bore is laid exactly on the sigils' axis (VeyrSpecial's corridor): the needed angles in the
	-- rifle joint's (build-axis) frame, from the torso's current rotation; for Angles(p, y, 0) the bore (0, 0, -1)
	-- points along (-sin y, cos y sin p, -cos y cos p)
	-- (the corridor runs level along his facing, so the aim does not wait for VeyrSpecial's layout: it is already true
	-- when the corridor is laid out on it)
	-- the bore is laid exactly on his line: the special's corridor axis, or (fighting) from his muzzle to the spot he
	-- shoots at; the needed angles in the rifle joint's (build-axis) frame from the torso's current rotation
	local spState = spState0
	local torsoPart = rig.joints.Waist and rig.joints.Waist.Part1
	local muzzleAtt = mk.muzzle
	if torsoPart and muzzleAtt and target then
		local axisDir
		if inSpecial and spState and spState.ready then
			axisDir = spState.axis.LookVector
		else
			axisDir = (target - muzzleAtt.WorldPosition).Unit
		end
		local d = mk.TB * (torsoPart.CFrame.Rotation:Inverse() * axisDir)
		local needYaw = math.asin(math.clamp(-d.X, -1, 1))
		local needPitch = math.atan2(d.Y, -d.Z)
		local k
		if inSpecial then
			k = ease(sp, 0.2, 0.8) * (1 - ease(sp, SP.END - 1.2, SP.END))
				* (1 - 0.85 * ease(sp, SP.FIRE, SP.FIRE + 0.05) * (1 - ease(sp, SP.FIRE + 0.6, SP.FIRE + 1.4)))
		else
			-- (his own recoil hop and the bolt still show: the correction gives way around them)
			k = clamp01(aim) * (1 - 0.85 * (inCycle and ease(sa, T.FIRE, T.FIRE + 0.05) * (1 - ease(sa, T.FIRE + 0.5, T.FIRE + 1.2)) or 0))
		end
		rPitch += (needPitch - rPitch) * k
		rYaw += (needYaw - rYaw) * k
	end
	local rifleT = CFrame.new(0, -rDrop * scale, rBack * scale) * ANGLES(rPitch, rYaw, rRoll)
	set(rig, "Rifle", rifleT)

	-- the bolt joint (a turn about the bore lifts the handle, then the draw back)
	local boltT = ANGLES(0, 0, 1.05 * boltLift) * CFrame.new(0, 0, 0.3 * boltBack * scale)
	set(rig, "Bolt", boltT)

	-- ── the arms by IK onto the rifle (build space); the right hand leaves the grip for the bolt knob
	local P = mk.pivot
	local function onRifle(pLocal) -- a point given in the rifle's build-local frame -> build space, with the rifle pose
		local Wb = mk.rifleBuild * pLocal
		return P + rifleT * (Wb - P)
	end
	local handRot = rifleT.Rotation
	local R = mk.arms.R
	local rWrist = onRifle(R.wristInRifle)
	if boltHand > 0.001 and mk.bolt then
		local bJ = mk.bolt.J
		local knobRifle = (bJ.C0 * boltT * bJ.C1:Inverse()) * mk.bolt.knobInBolt
		local wristAtKnob = knobRifle + Vector3.new(0.05, 0.14, 0.2) * scale
		rWrist = rWrist:Lerp(onRifle(wristAtKnob), boltHand)
		handRot = handRot * ANGLES(0, 0, -0.5 * boltHand) -- (the hand turns over to pinch the knob)
	end
	solveArm(rig, "R", R, rWrist, handRot)
	solveArm(rig, "L", mk.arms.L, onRifle(mk.arms.L.wristInRifle), rifleT.Rotation)

	-- ── the body: a slow irregular hover, the glide lean and bank, the recoil absorbed
	local float = (model:GetAttribute("Float") or 0.1) * scale
	local hover = float * (math.sin(t * 1.05) + 0.45 * math.sin(t * 2.3 + 1.2) + 0.2 * math.sin(t * 0.37)) * (1 - 0.6 * lock) * (1 - 0.8 * spW)
	local rootBack = spring(st, "rootBack", 0, 40, 9, dt)
	-- (he floats FLY_HEIGHT above his build height, the user's call: over the army's heads; the shadow form's smoke pool
	-- hangs on the root part, so it stays on the ground under him)
	set(rig, "Root", CFrame.new(perchOffset + Vector3.new(0, FLY_HEIGHT * scale + hover + 0.05 * glide * scale - 0.16 * spW * scale
		+ flightUp * scale, (rootBack * 0.8 + flightBack) * scale))
		* ANGLES(-0.09 * glide + flightTilt + 0.01 * sway2, bodyYaw + math.sin(t * 0.3) * 0.03 * drift, turn * 0.07 + math.sin(t * 0.45) * 0.012 * drift))

	-- waist: + pitch = lean back, + yaw = the chest turns to his left (towards the front: unbladed in the low ready)
	local wPitch = spring(st, "wPitch", -0.05 * aim - 0.02 * lock + 0.012 * breathe + 0.04 * low - 0.06 * spW, 38, 8, dt)
	local wYaw = spring(st, "wYaw", 0.28 * low * (0.6 + 0.4 * glide) - 0.03 * lock + 0.01 * sway1, 24, 7.5, dt)
	set(rig, "Waist", ANGLES(wPitch, wYaw, 0.01 * sway2))

	-- head: down into the scope when aiming (the build pose), up and turned ahead in the low ready; now and then a small
	-- correction, as if he saw something far away (a stiff spring: a quick small move, then still)
	if now >= mk.nextGlance then
		mk.nextGlance = now + 2.5 + math.random() * 4.5
		mk.gPitch = (math.random() - 0.5) * 0.08
		mk.gYaw = (math.random() - 0.5) * 0.14
	end
	local gW = 1 - still
	local nPitch = spring(st, "nPitch", 0.24 * low - 0.03 * lock + (mk.gPitch or 0) * gW, 55, 10, dt)
	local nYaw = spring(st, "nYaw", -0.32 * low * (0.6 + 0.4 * glide) + (mk.gYaw or 0) * gW + turn * 0.08, 55, 10, dt)
	set(rig, "Neck", ANGLES(nPitch, nYaw, 0.04 * low))

	-- his eyes sharpen while he focuses
	if mk.eyeLight then
		mk.eyeLight.Brightness = mk.eyeBase * (1 + 1.2 * focus)
	end

	-- ── legs: he never steps, he floats (the user's call): moving, the legs hang and trail back a little behind the
	-- glide, lagging the hover; standing, they keep their stance with a faint drift
	local legLag = math.sin(t * 1.05 - 0.8) * 0.04
	-- (the finisher's flight streams them out like the glide does, harder)
	local stream = math.max(glide, math.min(1.6, (mk.flightSpeed or 0) * 1.6))
	local trailL = spring(st, "trailL", 0.24 * stream, 9, 4, dt) -- (softer than the body: they lag the start and the stop)
	local trailR = spring(st, "trailR", 0.3 * stream, 8, 3.6, dt)
	set(rig, "LHip", ANGLES(-trailL + legLag + 0.08 * spW, 0, -0.1 * spW))
	set(rig, "RHip", ANGLES(-trailR + legLag * 0.7 - 0.1 * spW, 0, 0.1 * spW))
	set(rig, "LKnee", ANGLES(-0.18 * trailL - legLag * 0.5 - 0.16 * spW, 0, 0))
	set(rig, "RKnee", ANGLES(-0.22 * trailR - legLag * 0.4 - 0.12 * spW, 0, 0))

	-- ── the hood's peak lags the head and streams back in the glide
	local tail = spring(st, "tail", -0.25 * glide + 0.04 * math.sin(t * 0.9) * drift, 26, 5, dt)
	set(rig, "HoodTail", ANGLES(tail, turn * -0.12, 0))

	-- ── the mantle strips and ribbons: a chain of springs per strip (negative X = the bottom swings back, away from
	-- him); the later segments are softer, the ribbons flutter more, a slow wind runs across them, never in unison
	for _, m in ipairs(mk.mantle) do
		local soft = m.k
		local amp = m.thin and 0.11 or 0.05
		local wind = (math.sin(t * (0.7 + m.i * 0.07) - m.k * 0.9 + m.i * 1.3) + 0.4 * math.sin(t * 1.9 + m.i * 2.1)) * amp * (1 - 0.5 * lock)
		local trail = -stream * (0.22 + 0.1 * soft) * (m.thin and 1.4 or 1)
		local target = trail + wind - 0.02 * soft + pull * (0.22 + 0.08 * soft) * (m.thin and 1.5 or 1)
			+ pull * math.sin(t * 7 + m.i * 1.7 + m.k) * 0.05 -- (straining, trembling)
		local x = spring(st, m.name, target, 30 - soft * 6, 4.5 - soft * 0.4, dt)
		x = math.clamp(x, -1.1, 0.12 + 0.45 * pull)
		local side = spring(st, m.name .. "s", -turn * 0.06 * soft + (m.thin and 0.05 * math.sin(t * 2.3 + m.i) or 0), 20, 4, dt)
		set(rig, m.name, ANGLES(x, 0, side))
	end
	-- the robe panels (negative X = the bottom swings outward)
	for _, r in ipairs(mk.robe) do
		local a = r.a
		local trailR = glide * 0.32 * math.max(0, -math.cos(a) * 0.9 + 0.3)
		local press = glide * 0.06 * math.max(0, math.cos(a))
		local target = -trailR + press - turn * math.sin(a) * 0.07 + pull * 0.1 * math.max(0, -math.cos(a))
			+ math.sin(t * 0.7 - a * 1.5) * 0.035 * drift + math.sin(t * 1.7 + a * 3) * 0.012
		local x = spring(st, r.name, target, 36, 5.5, dt)
		set(rig, r.name, ANGLES(math.clamp(x, -0.9, 0.25), 0, 0))
	end

	-- ── the shards: each drifts on its own slow bob and turn, trails behind the glide, holds still in the focus,
	-- and is thrown back a little by the shot (the kick on its "z" spring)
	for _, sh in ipairs(mk.shards) do
		local ph = sh.ph
		local amp = 0.09 * (1 - 0.75 * still)
		local bob = Vector3.new(
			math.sin(t * (0.43 + sh.i * 0.05) + ph) * amp * 0.6,
			math.sin(t * (0.61 + sh.i * 0.07) + ph * 1.3) * amp,
			math.cos(t * (0.37 + sh.i * 0.04) + ph) * amp * 0.5)
		local back = spring(st, sh.name .. "z", glide * 0.5, 14 + sh.i, 3.6, dt)
		local sideLag = spring(st, sh.name .. "x", -turn * 0.25, 10 + sh.i * 0.7, 3, dt)
		local offset = (bob + Vector3.new(sideLag, 0, back)) * scale
		mk[sh.name .. "spin"] = (mk[sh.name .. "spin"] or ph) + dt * (0.25 + (sh.i % 3) * 0.12) * (1 - 0.8 * still)
		local idleT = CFrame.new(sh.inv * offset) * ANGLES(math.sin(t * 0.5 + ph) * 0.12, mk[sh.name .. "spin"], 0)
		-- during the special: out to its station (the keystone above its sigil) on an arc, held there, home again
		local spState = inSpecial and VeyrSpecial.state(model)
		local station = spState and spState.stations[sh.i]
		local w = 0
		if station then
			local out = ease(sp, SP.SHARDS_OUT + (sh.i - 1) * SP.SHARD_STEP, SP.SHARDS_OUT + (sh.i - 1) * SP.SHARD_STEP + SP.SHARD_FLY)
			local home = ease(sp, SP.BREAK + 0.3 + (#mk.shards - sh.i) * 0.12, SP.SHARDS_HOME)
			w = out * (1 - home)
		elseif finState and finState.stations and finState.stations[sh.i] then
			-- (the finisher: each shard flies to its echo's spot and bursts into it; home again when they dissolve)
			station = finState.stations[sh.i]
			local out = ease(ft, FN.ARSENAL, FN.ARSENAL + 0.6)
			local home = ease(ft, FN.FADE, FN.FADE + 2)
			w = out * (1 - home)
		end
		local joint = rig.joints[sh.name]
		local torso = joint and joint.Part0
		if w > 0.001 and torso then
			local restCF = torso.CFrame * joint.C0 * idleT * joint.C1:Inverse()
			local pos = restCF.Position:Lerp(station, w) + Vector3.new(0, 2.5 * math.sin(math.pi * w), 0)
			local rot = restCF.Rotation:Lerp(CFrame.Angles(0, (inSpecial and sp or ft) * 1.2 + sh.i, 0), w)
			local desired = CFrame.new(pos) * rot
			joint.Transform = joint.C0:Inverse() * torso.CFrame:Inverse() * desired * joint.C1
		else
			set(rig, sh.name, idleT)
		end
	end
end

return Marksman
