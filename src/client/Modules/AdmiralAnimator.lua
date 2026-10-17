-- Orvoss's procedural animation (model attribute Pose = "Admiral", tools/studio/build_orvoss.lua; docs/orvoss.md).
-- Called by UnitAnimator every frame for his model; it sets every joint of his rig itself.
--
-- The idle, "sea legs": a slow deck roll (the weight shifts side to side with a little fore and aft, hips and chest out
-- of phase, the knees giving as the pelvis dips; both feet stay planted by two-bone IK). The skull counters the roll
-- and stays level, like a sailor keeping the horizon. The coat tails (Tail<i> / Tail<i>_2) drift as if underwater:
-- each panel on a soft, lightly damped spring, out of phase, hanging after gravity and lagging the hips, with a slow
-- lift / spread / settle running round the coat. The arms hang heavy on soft springs; the cutlass and the flintlock
-- follow the hands on their own springs, so the cutlass tip lags the roll.
--
-- Gestures, one every 10-15 s, never the same twice in a row (not while walking):
--   brim push: the flintlock comes up and its barrel pushes the hat brim up (the left arm by IK onto the brim), then
--     the arm sinks slowly and the hat settles back over a few seconds;
--   listening to the fleet: the head turns up to one side, holds, the jaw opens a hair as if to give an order;
--   compass glance: the head tips down to the open compass on his belt and the needle twitches towards the gate.
-- Every gesture channel runs through a spring, so nothing snaps back to rest (Knell's momentum rule). The walk is the
-- generic stride for now.
--
-- All of it is worked out in the root's build space (RS: the HumanoidRootPart at the origin, model axes), where every
-- body joint frame is axis-aligned, so a Motor6D.Transform there is just the rotation itself.
local ANGLES = CFrame.Angles
local Admiral = {}

local ROLL_PERIOD = 6.6 -- seconds per deck roll
local GESTURE_GAP = { 10, 15 } -- seconds from one gesture's start to the next
local GESTURE_LEN = { 7.2, 7.5, 6.6 } -- brim, listen, compass (how long each blocks the next)
-- brim push targets (RS studs at scale 1): where the muzzle meets the brim (just under the hat's front point) and the
-- barrel's direction up to it
local BRIM_MUZZLE = Vector3.new(-0.1, 2.9, -1.12)
local BRIM_DIR = Vector3.new(0.3, 0.95, -0.04).Unit
local BRIM_POLE = Vector3.new(-0.8, -0.6, 0.15)

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
-- the rotation turning direction a onto b (the shortest way)
local function turnOnto(a, b)
	local axis = a:Cross(b)
	local dot = math.clamp(a:Dot(b), -1, 1)
	if axis.Magnitude < 1e-5 then
		return CFrame.new()
	end
	return CFrame.fromAxisAngle(axis.Unit, math.acos(dot))
end

-- ====================================================================
-- Setup: the build-space geometry, read from the joints (so it follows the model's scale)
-- ====================================================================
local function setup(model, rig)
	local j = rig.joints
	for _, n in ipairs({ "Root", "Waist", "Neck", "LShoulder", "LElbow", "LWrist", "LHip", "LKnee", "LAnkle", "RHip", "RKnee", "RAnkle", "Pistol" }) do
		if not j[n] then
			return nil
		end
	end
	-- every part's build frame in RS, by walking the Motor6Ds from the root
	local byPart1 = {}
	for _, joint in pairs(j) do
		if joint.Part1 then
			byPart1[joint.Part1] = joint
		end
	end
	local partB = {}
	local function buildOf(p)
		if partB[p] then
			return partB[p]
		end
		local joint = byPart1[p]
		local cf = joint and joint.Part0 and (buildOf(joint.Part0) * joint.C0 * joint.C1:Inverse()) or CFrame.new()
		partB[p] = cf
		return cf
	end
	local function jointFrame(joint)
		return buildOf(joint.Part0) * joint.C0
	end
	local ad = { st = {}, partB = partB }

	-- a limb from its three joints: rest positions, lengths, the build's bend direction and frames
	local function limb(sJ, eJ, wJ)
		local S, E, W = jointFrame(sJ).Position, jointFrame(eJ).Position, jointFrame(wJ).Position
		local sw = (W - S).Unit
		local bend = (E - S) - sw * (E - S):Dot(sw)
		local u0, f0 = (E - S).Unit, (W - E).Unit
		return {
			S = S, E = E, W = W, a = (E - S).Magnitude, b = (W - E).Magnitude,
			pole = bend.Magnitude > 1e-3 and bend.Unit or Vector3.new(0, 0, -1),
			Fu = frameOf(u0, f0), Ff = frameOf(f0, u0),
			sJ = sJ, eJ = eJ, wJ = wJ,
		}
	end
	ad.lArm = limb(j.LShoulder, j.LElbow, j.LWrist)
	ad.lLeg = limb(j.LHip, j.LKnee, j.LAnkle)
	ad.rLeg = limb(j.RHip, j.RKnee, j.RAnkle)
	ad.neck = jointFrame(j.Neck).Position
	-- the flintlock: grip and muzzle in RS at rest
	local function attachB(name)
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("Attachment") and d.Name == name and d.Parent:IsA("BasePart") then
				return (buildOf(d.Parent) * d.CFrame).Position
			end
		end
	end
	local grip, muzzle = attachB("PistolGrip"), attachB("Muzzle")
	if not (grip and muzzle) then
		return nil
	end
	ad.grip, ad.muzzleLen, ad.pisDir = grip, (muzzle - grip).Magnitude, (muzzle - grip).Unit
	-- the weapon joints' frames (their Transforms work in those frames)
	ad.cutRot = j.Cutlass and jointFrame(j.Cutlass).Rotation
	ad.pisRot = jointFrame(j.Pistol).Rotation
	-- the coat tails
	ad.tails = {}
	for name, joint in pairs(j) do
		local idx = joint:GetAttribute("TailIndex")
		if idx and name:sub(1, 4) == "Tail" then
			local seg = joint:GetAttribute("Segment") or 1
			local f = jointFrame(joint)
			table.insert(ad.tails, {
				name = name, i = idx, seg = seg,
				a = math.rad(joint:GetAttribute("CoatAngle") or 0),
				inv = f.Rotation:Inverse(), -- RS -> the joint's frame
				g0 = f.Rotation:VectorToObjectSpace(Vector3.new(0, -1, 0)),
				front = math.abs(joint:GetAttribute("CoatAngle") or 0) < 100,
			})
		end
	end
	table.sort(ad.tails, function(a, b) -- (upper segments first: the lower ones read their parent's swing)
		return a.seg < b.seg or (a.seg == b.seg and a.i < b.i)
	end)
	ad.nextGesture = os.clock() + 5 + math.random() * 3 -- (the first one comes sooner)
	return ad
end

-- solve a limb onto a target (its own rest space) with the end part turned by `endRot`
local function solveLimb(lb, Wt, endRot, pole)
	local E2 = solveJoint(lb.S, Wt, lb.a, lb.b, pole or lb.pole)
	local u1, f1 = (E2 - lb.S).Unit, (Wt - E2).Unit
	local R1 = frameOf(u1, f1) * lb.Fu:Inverse()
	local R2 = frameOf(f1, u1) * lb.Ff:Inverse()
	lb.sJ.Transform = R1
	lb.eJ.Transform = R1:Inverse() * R2
	lb.wJ.Transform = R2:Inverse() * endRot
	return R1, R2
end

-- ====================================================================
-- Every frame
-- ====================================================================
function Admiral.animate(model, rig, dt, now, ctx)
	local ad = rig.admiral
	if ad == nil or (ad == false and (rig.adRetry or 0) < now) then
		ad = setup(model, rig) or false
		rig.admiral = ad
		rig.adRetry = now + 1 -- (StreamingEnabled: the joints may still be arriving)
	end
	if not ad then
		return
	end
	local st = ad.st
	local set = ctx.set
	local scale = ctx.scale
	local j = rig.joints
	dt = math.min(dt, 1 / 20)
	-- (dev: model attribute AnimTimeScale plays him in slow motion, to inspect a gesture)
	local ts = model:GetAttribute("AnimTimeScale")
	if ts then
		dt *= ts
		ad.slowT = (ad.slowT or now) + dt
		now = ad.slowT
	elseif ad.slowT then
		now = ad.slowT -- (stays on the slowed clock once used, so nothing jumps; only in dev)
		ad.slowT += dt
	end
	if dt <= 0 then
		return
	end
	local t = now + rig.t0
	local w = rig.walk -- (0..1, the generic walk blend)
	local still = 1 - w

	-- ── gestures: pick one every GESTURE_GAP s, never the same twice in a row; walking cancels it
	local forced = model:GetAttribute("DevGesture") -- (dev: 1 brim, 2 listen, 3 compass plays that gesture now)
	if forced then
		model:SetAttribute("DevGesture", nil)
		ad.gesture, ad.lastGesture, ad.gStart = forced, forced, now
		ad.side = math.random() < 0.5 and -1 or 1
		ad.nextGesture = now + GESTURE_LEN[forced] + GESTURE_GAP[1]
	end
	if w > 0.3 then
		ad.gesture = nil
		ad.nextGesture = math.max(ad.nextGesture, now + 4)
	elseif not ad.gesture and now >= ad.nextGesture then
		local g
		repeat
			g = math.random(1, 3)
		until g ~= ad.lastGesture
		ad.gesture, ad.lastGesture, ad.gStart = g, g, now
		ad.side = math.random() < 0.5 and -1 or 1
		ad.nextGesture = now + math.max(GESTURE_LEN[g] + 3, GESTURE_GAP[1] + math.random() * (GESTURE_GAP[2] - GESTURE_GAP[1]))
	end
	local g = ad.gesture
	local gt = g and (now - ad.gStart) or 0
	if g and gt > GESTURE_LEN[g] + 3 then -- (+3: the hat settles after the brim push)
		ad.gesture = nil
		g = nil
	end
	local brimArm, brimPush, hatLift, listen, jawOpen, lookDown, needleGo = 0, 0, 0, 0, 0, 0, 0
	if g == 1 then
		brimArm = ease(gt, 0.3, 2.6) * (1 - ease(gt, 4.4, 7.0))
		brimPush = ease(gt, 2.4, 3.3) * (1 - ease(gt, 3.7, 4.6))
		hatLift = ease(gt, 2.4, 3.3) * (1 - 0.35 * ease(gt, 3.6, 4.6)) * (1 - ease(gt, 6.0, 9.5))
	elseif g == 2 then
		listen = ease(gt, 0.3, 2.6) * (1 - ease(gt, 4.8, 7.2))
		jawOpen = ease(gt, 3.0, 3.7) * (1 - ease(gt, 4.3, 5.2))
	elseif g == 3 then
		lookDown = ease(gt, 0.3, 2.0) * (1 - ease(gt, 4.3, 6.4))
		needleGo = ease(gt, 1.7, 1.8) * (1 - ease(gt, 4.6, 5.6))
	end
	-- (springs on every gesture channel: momentum in and out, and a cancelled gesture eases away)
	brimArm = spring(st, "brimArm", brimArm, 9, 4.6, dt)
	brimPush = spring(st, "brimPush", brimPush, 14, 5.5, dt)
	hatLift = spring(st, "hatLift", hatLift, 16, 4.2, dt)
	listen = spring(st, "listen", listen, 8, 4.2, dt)
	jawOpen = spring(st, "jaw", jawOpen, 30, 7, dt)
	lookDown = spring(st, "look", lookDown, 9, 4.6, dt)
	local side = spring(st, "side", ad.side or 1, 6, 5, dt)

	-- ── the deck roll: the pelvis shifts and leans with it, the chest follows out of phase
	local ph = t * (2 * math.pi / ROLL_PERIOD)
	local sr = math.sin(ph)
	local rootX = 0.07 * sr * still
	local rootY = -0.025 * sr * sr * still - 0.015 * still -- (the knees give at each side)
	local rootRoll = -0.032 * sr * still -- (leans the way the weight goes)
	local rootPitch = (0.014 * math.sin(ph * 0.63 + 1.1)) * still
	local rootYaw = 0.02 * math.sin(ph * 0.5 + 0.4) * still
	local walkBob = math.abs(math.sin(rig.phase)) * 0.12 * w
	local rootCF = CFrame.new(rootX * scale, (rootY + walkBob) * scale, 0) * ANGLES(rootPitch, rootYaw, rootRoll)
	set(rig, "Root", rootCF)
	local breathe = math.sin(t * 1.1) * 0.012
	local waistRoll = 0.022 * math.sin(ph - 1.0) * still
	local waistPitch = 0.012 * math.sin(ph * 0.63 + 0.2) + breathe - 0.07 * lookDown + 0.02 * brimArm
	local waistYaw = 0.1 * listen * side + 0.06 * brimArm
	local waistRot = ANGLES(waistPitch, waistYaw, waistRoll)
	set(rig, "Waist", waistRot)
	local chestRot = rootCF.Rotation * waistRot
	local chestRoll, chestPitch = rootRoll + waistRoll, rootPitch + waistPitch

	-- ── the skull keeps the horizon (counters the whole roll), plus the gestures
	local headGesture = ANGLES(
		0.22 * listen - 0.5 * lookDown + 0.06 * hatLift - 0.05 * brimArm + math.sin(t * 0.37) * 0.015,
		0.62 * listen * side + 0.1 * lookDown + 0.08 * brimArm + math.sin(t * 0.23 + 1) * 0.03,
		-0.08 * listen * side)
	local neckRot = chestRot:Inverse() * headGesture
	set(rig, "Neck", neckRot)
	set(rig, "Jaw", ANGLES(-0.1 * jawOpen - 0.015 * listen, 0, 0))
	-- the hat: pushed up at the front by the barrel, settling back slowly; a little lag of its own otherwise
	local hatWobble = spring(st, "hatW", -chestRoll * 0.3, 40, 5, dt) + chestRoll * 0.3
	set(rig, "Hat", CFrame.new(0, 0.05 * hatLift * scale, 0.02 * hatLift * scale) * ANGLES(0.17 * hatLift, 0, hatWobble))

	-- ── the right arm hangs heavy: its swing lags the chest on a soft spring; the cutlass follows the hand
	local rz = spring(st, "rz", -chestRoll * 0.8, 9, 2.2, dt)
	local rx = spring(st, "rx", -chestPitch * 0.7 + 0.015 * math.sin(t * 1.1 - 0.5), 9, 2.2, dt)
	set(rig, "RShoulder", ANGLES(rx, 0, rz))
	set(rig, "RElbow", ANGLES(0.03 * math.sin(ph - 1.6) * still, 0, 0))
	set(rig, "RWrist", CFrame.new())
	if ad.cutRot then
		-- the blade's own angle follows the hand's on a looser spring: what is left over turns it in the grip
		local handZ, handX = chestRoll + rz, chestPitch + rx
		local bz = spring(st, "bladeZ", handZ, 22, 3, dt)
		local bx = spring(st, "bladeX", handX, 22, 3, dt)
		local lag = ANGLES(math.clamp(bx - handX, -0.12, 0.12), 0, math.clamp(bz - handZ, -0.12, 0.12))
		set(rig, "Cutlass", ad.cutRot:Inverse() * lag * ad.cutRot)
	end

	-- ── the left arm (by IK, so the brim push can lead the muzzle to the hat): hanging, it swings like the right one
	local lz = spring(st, "lz", -chestRoll * 0.8, 8.5, 2.1, dt)
	local lx = spring(st, "lx", -chestPitch * 0.7 + 0.015 * math.sin(t * 1.1 - 0.9), 8.5, 2.1, dt)
	local pend = ANGLES(lx, 0, lz)
	local arm = ad.lArm
	local Wrest = arm.S + pend * (arm.W - arm.S)
	local Wt, handRot, pole = Wrest, pend, pend * arm.pole
	if brimArm > 0.001 then
		-- the brim's point in the torso's rest space: the head's turn carried into it, then lifted by the push
		local headCF = CFrame.new(ad.neck) * neckRot * CFrame.new(-ad.neck)
		local muzzleT = headCF * (BRIM_MUZZLE * scale) + Vector3.new(0, 0.17 * brimPush * scale, 0.04 * brimPush * scale)
		local dir = (headCF.Rotation * BRIM_DIR).Unit
		local rotG = turnOnto(ad.pisDir, dir)
		local gripT = muzzleT - dir * ad.muzzleLen
		local WtG = gripT + rotG * (arm.W - ad.grip)
		local k = math.min(brimArm, 1.05)
		Wt = Wrest:Lerp(WtG, k)
		handRot = pend:Lerp(rotG, math.clamp(k, 0, 1))
		pole = pole:Lerp(BRIM_POLE.Unit, math.clamp(k, 0, 1))
	end
	solveLimb(arm, Wt, handRot, pole)
	-- the flintlock's weight: its own lag in the grip, fading out while it works the brim
	local pz = spring(st, "pisZ", chestRoll + lz, 24, 3.2, dt) - (chestRoll + lz)
	local px = spring(st, "pisX", chestPitch + lx, 24, 3.2, dt) - (chestPitch + lx)
	local pisLag = ANGLES(math.clamp(px, -0.1, 0.1), 0, math.clamp(pz, -0.1, 0.1)):Lerp(CFrame.new(), clamp01(brimArm))
	set(rig, "Pistol", ad.pisRot:Inverse() * pisLag * ad.pisRot)

	-- ── the legs: the feet stay planted (IK in the pelvis's rest space), blended with the generic stride when walking
	local rootInv = rootCF:Inverse()
	local footRot = rootCF.Rotation:Inverse()
	local stride = math.sin(rig.phase)
	local strideC = math.cos(rig.phase)
	for _, sd in ipairs({ { ad.lLeg, 1 }, { ad.rLeg, -1 } }) do
		local lb, sgn = sd[1], sd[2]
		solveLimb(lb, rootInv * lb.W, footRot)
		if w > 0.001 then
			local hip = ANGLES(sgn * stride * 0.75 * w, 0, 0)
			local knee = ANGLES(-math.max(0, -sgn * strideC) * 0.9 * w, 0, 0)
			lb.sJ.Transform = lb.sJ.Transform:Lerp(hip, w)
			lb.eJ.Transform = lb.eJ.Transform:Lerp(knee, w)
			lb.wJ.Transform = lb.wJ.Transform:Lerp(CFrame.new(), w)
		end
	end

	-- ── the compass needle: a slow restless drift; in the glance it snaps round towards the gate and quivers there
	if j.CompassNeedle then
		local target = math.sin(t * 0.31) * 0.12 + math.sin(t * 0.83 + 2) * 0.05
		if needleGo > 0 then
			target = target * (1 - needleGo) + needleGo * (math.rad(28) + math.sin(t * 7.3) * 0.04 * (1 - ease(gt, 2.4, 4.0)))
		end
		set(rig, "CompassNeedle", ANGLES(0, 0, spring(st, "needle", target, 70, 3.2, dt)))
	end

	-- ── the coat tails, underwater: each panel hangs after gravity (in the pelvis's turned frame), lags the hips'
	-- motion, and drifts on a slow wave round the coat; soft, lightly damped springs, the lower segments whip after
	local rootPos = rootCF.Position
	local lastPos = ad.lastRoot or rootPos
	ad.lastRoot = rootPos
	local vel = (rootPos - lastPos) / dt / math.max(scale, 0.05) -- (studs/s at scale 1)
	local gravP = rootCF.Rotation:VectorToObjectSpace(Vector3.new(0, -1, 0))
	local velP = rootCF.Rotation:VectorToObjectSpace(vel)
	local upper = {}
	for _, tl in ipairs(ad.tails) do
		local a = tl.a
		local gl = tl.inv * gravP
		local vl = tl.inv * velP
		local tx, tz
		if tl.seg == 1 then
			local spread = 0.5 + 0.5 * math.sin(t * 0.42 - a * 1.1)
			tx = -(gl.Z - tl.g0.Z) * 0.6 + vl.Z * 0.35 -- (hang, then lag)
				- 0.04 - 0.07 * spread - 0.02 * math.sin(t * 0.9 + tl.i * 1.7)
				- w * 0.4 * math.max(0, -math.cos(a) * 0.9 + 0.3) -- (trailing behind him while he walks)
			tz = (gl.X - tl.g0.X) * 0.6 - vl.X * 0.35 + 0.05 * math.sin(t * 0.33 + tl.i * 2.1)
		else
			local up = upper[tl.i] or { x = 0, vx = 0, z = 0, vz = 0 }
			tx = -0.05 * math.sin(t * 0.42 - a * 1.1 - 0.9) - up.vx * 0.22 - 0.25 * w * math.max(0, -math.cos(a))
			tz = 0.04 * math.sin(t * 0.33 + tl.i * 2.1 - 0.9) - up.vz * 0.22
		end
		local soft = tl.seg == 1 and 7 or 5
		local damp = tl.seg == 1 and 1.8 or 1.4
		local x = spring(st, tl.name .. "x", tx, soft, damp, dt)
		local z = spring(st, tl.name .. "z", tz, soft, damp, dt)
		if tl.seg == 1 then
			x = math.clamp(x, -0.6, tl.front and 0.04 or 0.1)
			z = math.clamp(z, -0.25, 0.25)
			upper[tl.i] = { x = x, vx = st[tl.name .. "x_v"], z = z, vz = st[tl.name .. "z_v"] }
		else
			x = math.clamp(x, -0.4, 0.3)
			z = math.clamp(z, -0.2, 0.2)
		end
		st[tl.name .. "x"], st[tl.name .. "z"] = x, z
		set(rig, tl.name, ANGLES(x, 0, z))
	end
end

return Admiral
