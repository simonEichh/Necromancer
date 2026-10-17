-- Builds Orvoss, the Blackwake (Sovereign, see docs/orvoss.md) into ServerStorage.Models.Orvoss.
-- Run in Edit mode (Studio MCP execute_luau or loadstring from the tools/studio http server), then
-- publish_unit_models.lua. Safe to re-run: it replaces its own model (a hand-altered copy is kept once as Orvoss_Old).
-- It builds off-tree, validates (connections, unique joints, floor) and only then installs; it returns a report.
--
-- After the concept art (Images/Concept/Unit/Orvoss-the-Blackwake-concept-v1.png): a tall lean skeletal pirate admiral.
-- A broad battered tricorn with a skull-and-anchor badge, a skull with deep sockets and sea-green eyes, a tall flared
-- collar, a ruined charcoal greatcoat with sea-green lining, brass trim and fringed epaulettes, an open chest showing
-- the ribcage round a green soul, a baldric, a belt with a compass, long torn coat tails, iron bracers, skeletal hands,
-- buckled boots. A cutlass in his RIGHT hand and a heavy flintlock in his LEFT, both lowered and pointing outwards.
-- Sparse barnacles (hat, left shoulder, right boot, a hem) and seaweed.
--
-- Rig conventions (see src/client/Modules/UnitAnimator.lua):
--   * front = -Z, character's right = +X, root part = HumanoidRootPart at RootHeight, soles on y = 0
--   * Motor6Ds Root/Waist/Neck/LShoulder/RShoulder/LElbow/RElbow/LWrist/RWrist/LHip/RHip/LKnee/RKnee/LAnkle/RAnkle,
--     rest = identity Transform
--   * Jaw (Head -> JawRoot, hinge under the ear line), Hat (Head -> HatRoot, the whole hat incl. badge/growth)
--   * Cutlass (RHand -> CutlassRoot): frame origin at the grip centre, -Z along the blade, +Y the spine (knuckle bow and
--     edge on -Y). Attachments CutlassGrip, BladeBase, BladeTip, CommandPoint (all -Z along the blade)
--   * Pistol (LHand -> PistolRoot): -Z = the muzzle direction, +Y the top of the gun. PistolHammer (PistolRoot ->
--     PistolHammerRoot, the cock). Attachments Muzzle (-Z out of the bore), PistolGrip, Hammer
--   * Compass (Pelvis -> CompassRoot, face -Z), CompassLid (CompassRoot -> CompassLidRoot, hinged at the top, built OPEN;
--     rotate it 180 deg about its X to close). Attachments CompassFace, CompassGrip (the future left-hand hold)
--   * Pelvis attachment PistolHolster (-Z down into the sheath) for stowing the pistol later
--   * coat tails: Tail<i> (Pelvis -> the upper panel) and Tail<i>_2 (the lower panel of the long ones), attributes
--     TailIndex, Segment, CoatAngle (degrees from the front towards his right)
--   * every part carries the attribute Cat (its build region) so the report can count them
--   * attributes Rig = "Procedural", RootHeight, Height, BuiltBy; no Pose / AttackStyle yet (no animation handler)
local ServerStorage = game:GetService("ServerStorage")
local models = ServerStorage.Models

local NAME = "Orvoss"
local BUILT_BY = "build_orvoss"

local SMOOTH = Enum.Material.SmoothPlastic
local NEON = Enum.Material.Neon
local FABRIC = Enum.Material.Fabric
local METAL = Enum.Material.Metal

local COAT = Color3.fromRGB(20, 25, 26)          -- the greatcoat
local COAT_RAISED = Color3.fromRGB(34, 42, 42)   -- raised panels, folds, the next layer
local COAT_DEEP = Color3.fromRGB(10, 15, 17)     -- recesses, the chest cavity
local LINING = Color3.fromRGB(25, 65, 59)        -- dark sea-green lining
local LINING_DARK = Color3.fromRGB(18, 47, 43)
local TROUSER = Color3.fromRGB(24, 27, 30)
local BONE = Color3.fromRGB(184, 179, 151)       -- weathered ivory
local BONE_DARK = Color3.fromRGB(136, 128, 104)
local BONE_SHADOW = Color3.fromRGB(82, 76, 62)
local VOID = Color3.fromRGB(5, 8, 9)
local BRASS = Color3.fromRGB(137, 111, 64)       -- old brass
local BRASS_LIGHT = Color3.fromRGB(178, 148, 92)
local BRASS_DARK = Color3.fromRGB(98, 80, 48)
local IRON = Color3.fromRGB(42, 48, 48)          -- blackened iron
local IRON_DARK = Color3.fromRGB(27, 31, 32)
local BLADE = Color3.fromRGB(52, 58, 58)
local BLADE_EDGE = Color3.fromRGB(92, 100, 98)
local VERDIGRIS = Color3.fromRGB(50, 90, 77)
local LEATHER = Color3.fromRGB(46, 35, 27)
local LEATHER_DARK = Color3.fromRGB(30, 23, 18)
local SOLE_COLOR = Color3.fromRGB(16, 13, 11)
local WOOD = Color3.fromRGB(58, 37, 25)
local SOUL = Color3.fromRGB(40, 225, 165)        -- the drowned soul's sea green
local SOUL_CORE = Color3.fromRGB(200, 255, 232)
local SOUL_DEEP = Color3.fromRGB(16, 110, 88)
local BARNACLE = Color3.fromRGB(100, 97, 83)    -- crusted grey shell
local BARNACLE_LIGHT = Color3.fromRGB(128, 123, 104)
local BARNACLE_DARK = Color3.fromRGB(34, 34, 29)
local SEAWEED = Color3.fromRGB(66, 78, 44)
local SEAWEED_DARK = Color3.fromRGB(43, 53, 32)

local ANKLE_Y = 0.42
local HIP_Y = 3.7    -- the root (and pelvis) height
local WAIST_Y = 4.05
local rng = Random.new(1717) -- deterministic: a rebuild gives the same barnacles and tears

local model = Instance.new("Model")
model.Name = NAME
local cat = "Rig" -- the build region the next parts are counted in (attribute Cat)

-- ====================================================================
-- Helpers
-- ====================================================================
local function finish(p, name, color, material)
	p.Name = name
	p.Color = color
	p.Material = material or SMOOTH
	if material == METAL then
		p.Reflectance = 0.04
	end
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.Anchored = false
	p:SetAttribute("Cat", cat)
	p.Parent = model
	return p
end

local function part(name, size, at, color, material, shape)
	local p = Instance.new("Part")
	p.Size = size
	p.CFrame = typeof(at) == "CFrame" and at or CFrame.new(at)
	if shape then
		p.Shape = shape
	end
	return finish(p, name, color, material)
end

-- a carrier: an invisible rig part (counted in "Rig")
local function carrier(name, at)
	local was = cat
	cat = "Rig"
	local p = part(name, Vector3.new(0.2, 0.2, 0.2), at, COAT_DEEP)
	p.Transparency = 1
	cat = was
	return p
end

local function motor(name, p0, p1, jointPos)
	local m = Instance.new("Motor6D")
	m.Name = name
	m.Part0 = p0
	m.Part1 = p1
	local jcf = typeof(jointPos) == "CFrame" and jointPos or CFrame.new(jointPos)
	m.C0 = p0.CFrame:Inverse() * jcf
	m.C1 = p1.CFrame:Inverse() * jcf
	m.Parent = p1
	return m
end

local function weld(p0, p1)
	local w = Instance.new("WeldConstraint")
	w.Part0 = p0
	w.Part1 = p1
	w.Parent = p1
	return w
end

local function deco(to, name, size, at, color, material, shape)
	local p = part(name, size, at, color, material, shape)
	weld(to, p)
	return p
end

-- a box between two points (w x h cross-section), welded to `to`; `roll` turns it about its own axis
local function bar(to, name, a, b, w, h, color, material, roll)
	local dir = b - a
	local len = dir.Magnitude
	if len < 1e-3 then
		return nil
	end
	local up = math.abs(dir.Y / len) > 0.98 and Vector3.new(0, 0, 1) or Vector3.new(0, 1, 0)
	local cf = CFrame.lookAt((a + b) / 2, b, up) * CFrame.Angles(0, 0, roll or 0)
	return deco(to, name, Vector3.new(w, h or w, len), cf, color, material)
end

-- a cylinder centred on `c` whose axis runs along `axis`
local function cyl(to, name, c, axis, length, diameter, color, material)
	local u = axis.Unit
	local cf
	if math.abs(u.Y) > 0.98 then
		cf = CFrame.new(c) * CFrame.Angles(0, 0, math.pi / 2)
	else
		cf = CFrame.lookAt(c, c + u) * CFrame.Angles(0, math.pi / 2, 0)
	end
	return deco(to, name, Vector3.new(length, diameter, diameter), cf, color, material, Enum.PartType.Cylinder)
end

local function ball(to, name, c, d, color, material)
	return deco(to, name, Vector3.new(d, d, d), CFrame.new(c), color, material, Enum.PartType.Ball)
end

local function glow(to, name, size, at, color, transparency)
	local p = deco(to, name, size, at, color or SOUL, NEON)
	p.Transparency = transparency or 0
	return p
end

local function light(parentPart, range, brightness, color)
	local l = Instance.new("PointLight")
	l.Color = color or SOUL
	l.Range = range
	l.Brightness = brightness
	l.Shadows = false
	l.Parent = parentPart
	return l
end

local function attach(p, name, worldCF)
	local a = Instance.new("Attachment")
	a.Name = name
	a.CFrame = p.CFrame:ToObjectSpace(typeof(worldCF) == "CFrame" and worldCF or CFrame.new(worldCF))
	a.Parent = p
	return a
end

-- a solid triangle a-b-c of thickness t (one or two wedges), welded to `to`
local function tri(to, name, a, b, c, t, color, material)
	local ab, ac, bc = b - a, c - a, c - b
	local abd, acd, bcd = ab:Dot(ab), ac:Dot(ac), bc:Dot(bc)
	if abd > acd and abd > bcd then
		c, a = a, c
	elseif acd > bcd and acd > abd then
		a, b = b, a
	end
	ab, ac, bc = b - a, c - a, c - b
	local right = ac:Cross(ab)
	if right.Magnitude < 1e-5 or bc.Magnitude < 1e-4 then
		return
	end
	right = right.Unit
	local up = bc:Cross(right).Unit
	local back = bc.Unit
	local height = math.abs(ab:Dot(up))
	local d0, d1 = math.abs(ab:Dot(back)), math.abs(ac:Dot(back))
	if d0 > 0.01 then
		local w = Instance.new("WedgePart")
		w.Size = Vector3.new(t, height, d0)
		w.CFrame = CFrame.fromMatrix((a + b) / 2, right, up, back)
		finish(w, name, color, material)
		weld(to, w)
	end
	if d1 > 0.01 then
		local w = Instance.new("WedgePart")
		w.Size = Vector3.new(t, height, d1)
		w.CFrame = CFrame.fromMatrix((a + c) / 2, -right, up, -back)
		finish(w, name, color, material)
		weld(to, w)
	end
end

-- two-bone solve: where the elbow (knee) goes for a limb from S to W with lengths a, b, bending towards `pole`
local function solveJoint(S, W, a, b, pole)
	local d = W - S
	local dist = math.min(d.Magnitude, a + b - 0.02)
	local u = d.Unit
	local cosA = math.clamp((a * a + dist * dist - b * b) / (2 * a * dist), -1, 1)
	local sinA = math.sqrt(1 - cosA * cosA)
	local p = (pole - u * pole:Dot(u)).Unit
	return S + (u * cosA + p * sinA) * a
end

-- a run of n chain links from a to b sagging `sag` studs, alternately turned 90 degrees, a little irregular
local function chain(to, name, a, b, sag, n, w, color)
	w = w or 0.035
	local prev = a
	for k = 1, n do
		local t = k / n
		local p = a:Lerp(b, t) - Vector3.new(0, sag * 4 * t * (1 - t), 0)
		if k < n then
			p += Vector3.new(rng:NextNumber(-0.012, 0.012), rng:NextNumber(-0.012, 0.012), rng:NextNumber(-0.012, 0.012))
		end
		bar(to, name, prev, p, w, w * 2.3, color or IRON, METAL, k % 2 == 0 and math.rad(90) or 0)
		prev = p
	end
end

-- a barnacle: a crusted grey cone (a wide base, a narrower lighter rim) with a dark slit mouth on top, normal n
local function barnacle(to, pos, n, s)
	n = n.Unit
	cyl(to, "Barnacle", pos + n * s * 0.18, n, s * 0.42, s, BARNACLE)
	local side = math.abs(n.Y) > 0.9 and Vector3.new(1, 0, 0) or Vector3.new(0, 1, 0)
	local top = CFrame.lookAt(pos + n * s * 0.44, pos + n * 2, side) * CFrame.Angles(0, 0, rng:NextNumber(0, math.pi))
	deco(to, "BarnacleRim", Vector3.new(s * 0.5, s * 0.5, s * 0.26), top * CFrame.Angles(0, 0, math.rad(45)), BARNACLE_LIGHT)
	deco(to, "BarnacleMouth", Vector3.new(s * 0.32, s * 0.08, s * 0.28), top, BARNACLE_DARK)
end

-- a strand of seaweed: flat torn segments hanging from `start`, zig-zagging a little, tapering
local function seaweed(to, start, n, segL, w)
	local prev = start
	for k = 1, n do
		local side = (k % 2 == 0) and 1 or -1
		local p = prev + Vector3.new(side * rng:NextNumber(0.02, 0.05), -segL, rng:NextNumber(-0.03, 0.03))
		bar(to, "Seaweed", prev, p, w * (1 - (k - 1) * 0.22), 0.02, k % 2 == 0 and SEAWEED_DARK or SEAWEED, FABRIC)
		prev = p
	end
end

-- ====================================================================
-- Frames
-- ====================================================================
local PELVIS = CFrame.new(0, HIP_Y, 0)
local function PV(x, y, z)
	return (PELVIS * CFrame.new(x, y, z)).Position
end
local UPPER = CFrame.new(0, WAIST_Y, 0) * CFrame.Angles(math.rad(2.5), 0, 0) -- the chest, held back proudly
local function T(x, y, z) -- a frame in the chest (y from the waist)
	return UPPER * CFrame.new(x, y, z)
end
local function TV(x, y, z)
	return (UPPER * CFrame.new(x, y, z)).Position
end
local R_SHOULDER = TV(0.74, 1.5, 0.02)
local L_SHOULDER = TV(-0.74, 1.5, 0.02)
local NECK = TV(0, 1.8, 0.04)
local HEAD = CFrame.new(NECK + Vector3.new(0, 0.5, -0.06)) * CFrame.Angles(math.rad(3), 0, 0) -- the chin a little up
local function H(x, y, z)
	return HEAD * CFrame.new(x, y, z)
end
local function HV(x, y, z)
	return (HEAD * CFrame.new(x, y, z)).Position
end

-- ====================================================================
-- Root and pelvis
-- ====================================================================
local root = part("HumanoidRootPart", Vector3.new(1.2, 0.4, 0.8), Vector3.new(0, HIP_Y, 0), COAT_DEEP)
root.Transparency = 1
model.PrimaryPart = root
cat = "Legs"
local pelvis = part("Pelvis", Vector3.new(0.8, 0.5, 0.5), PELVIS * CFrame.new(0, 0.02, 0), TROUSER, FABRIC)
motor("Root", root, pelvis, Vector3.new(0, HIP_Y, 0))

-- ====================================================================
-- Torso: the dark chest cavity (the carrier), the coat body, the open front with the ribcage and the soul
-- ====================================================================
cat = "Chest"
local torso = part("Torso", Vector3.new(0.74, 1.5, 0.44), T(0, 0.85, 0.1), COAT_DEEP)
motor("Waist", pelvis, torso, Vector3.new(0, WAIST_Y, 0))

-- the sternum, the clavicles, six pairs of ribs (two angled bones each: out from the sternum, then back and down)
deco(torso, "Manubrium", Vector3.new(0.14, 0.14, 0.06), T(0, 1.42, -0.3), BONE)
bar(torso, "Sternum", TV(0, 1.36, -0.31), TV(0, 0.84, -0.31), 0.085, 0.05, BONE)
deco(torso, "Xiphoid", Vector3.new(0.05, 0.08, 0.04), T(0, 0.78, -0.3) * CFrame.Angles(0, 0, math.rad(45)), BONE_DARK)
for _, s in ipairs({ -1, 1 }) do
	bar(torso, "Clavicle", TV(s * 0.07, 1.46, -0.31), TV(s * 0.42, 1.58, -0.16), 0.06, 0.05, BONE)
	for k = 0, 5 do
		local y = 1.33 - k * 0.13
		local reach = 0.31 - k * 0.012
		local a = TV(s * 0.05, y, -0.315)
		local b = TV(s * 0.2, y + 0.015 - k * 0.012, -0.32)
		local c = TV(s * reach, y - 0.1, -0.17)
		bar(torso, "Rib", a, b, 0.05, 0.045, BONE)
		bar(torso, "RibBack", b, c, 0.05, 0.045, BONE_DARK)
	end
end
-- the spine behind the ribs, showing in the gaps and under the ribs down to the belt
for k = 0, 4 do
	deco(torso, "Vertebra", Vector3.new(0.11, 0.08, 0.1), T(0, 0.14 + k * 0.17, -0.16), BONE_DARK)
end
-- the drowned soul: a compact irregular core behind the sternum, a hot centre, slivers deeper in, a faint glow behind
glow(torso, "SoulVeil", Vector3.new(0.46, 0.78, 0.02), T(0, 0.98, -0.14), SOUL_DEEP, 0.45)
glow(torso, "SoulCore", Vector3.new(0.17, 0.22, 0.09), T(0, 0.98, -0.2) * CFrame.Angles(0.3, 0.5, 0.7), SOUL, 0.05)
glow(torso, "SoulCore", Vector3.new(0.14, 0.17, 0.08), T(0.03, 1.06, -0.19) * CFrame.Angles(-0.4, 0.2, -0.5), SOUL, 0.15)
glow(torso, "SoulCore", Vector3.new(0.11, 0.15, 0.08), T(-0.04, 0.9, -0.19) * CFrame.Angles(0.6, -0.3, 0.2), SOUL, 0.15)
local soulHot = glow(torso, "SoulHot", Vector3.new(0.06, 0.09, 0.05), T(0, 0.99, -0.24) * CFrame.Angles(0, 0, 0.4), SOUL_CORE)
for i, sl in ipairs({ { -0.13, 1.16, 0.5 }, { 0.14, 1.12, -0.6 }, { -0.1, 0.78, -0.3 }, { 0.11, 0.82, 0.35 } }) do
	glow(torso, "SoulSliver", Vector3.new(0.03, 0.2, 0.03), T(sl[1], sl[2], -0.16) * CFrame.Angles(0, i, sl[3]), SOUL, 0.3)
end
light(soulHot, 5, 1.1, SOUL)

-- the coat body
cat = "CoatUpper"
deco(torso, "CoatBack", Vector3.new(1.0, 1.55, 0.1), T(0, 0.82, 0.36), COAT, FABRIC)
deco(torso, "CoatYoke", Vector3.new(1.12, 0.44, 0.12), T(0, 1.38, 0.38), COAT_RAISED, FABRIC)
deco(torso, "CoatYokeSeam", Vector3.new(1.1, 0.04, 0.125), T(0, 1.15, 0.385), COAT_DEEP, FABRIC)
deco(torso, "CoatBackSeam", Vector3.new(0.045, 1.0, 0.11), T(0, 0.6, 0.38), COAT_DEEP, FABRIC)
for _, s in ipairs({ -1, 1 }) do
	deco(torso, "CoatSide", Vector3.new(0.1, 1.45, 0.66), T(s * 0.52, 0.78, 0.04) * CFrame.Angles(0, 0, s * math.rad(4)), COAT, FABRIC)
	deco(torso, "CoatSidePanel", Vector3.new(0.11, 1.1, 0.3), T(s * 0.53, 0.66, 0.2) * CFrame.Angles(0, 0, s * math.rad(4)), COAT_RAISED, FABRIC)
	deco(torso, "CoatShoulder", Vector3.new(0.46, 0.12, 0.66), T(s * 0.5, 1.56, 0.03) * CFrame.Angles(0, 0, s * math.rad(-12)), COAT_RAISED, FABRIC)
	deco(torso, "CoatYokeWing", Vector3.new(0.3, 0.3, 0.12), T(s * 0.5, 1.42, 0.39) * CFrame.Angles(0, 0, s * math.rad(-30)), COAT_RAISED, FABRIC)
	-- the front panels either side of the opening (turned a little towards the sides)
	local fp = T(s * 0.41, 0.8, -0.27) * CFrame.Angles(0, -s * math.rad(12), 0)
	deco(torso, "CoatFront", Vector3.new(0.3, 1.5, 0.1), fp, COAT, FABRIC)
	-- buttons down both fronts, brass tabs (frogging) across his left front
	for k = 0, 3 do
		local y = 0.22 - k * 0.2
		cyl(torso, "Button", (fp * CFrame.new(s * 0.09, y, -0.055)).Position, fp.LookVector, 0.03, 0.07, s < 0 and BRASS or BRASS_DARK, METAL)
		if s < 0 then
			bar(torso, "Frog", TV(-0.29, 1.02 - k * 0.2, -0.4), (fp * CFrame.new(-0.07, y, -0.06)).Position, 0.035, 0.04, BRASS, METAL)
		end
	end
	-- the lapels: broad, turned out, a sea-green facing along the opening, a thin brass edge
	local A = TV(s * 0.2, 1.6, -0.27)
	local B = TV(s * 0.58, 1.46, -0.25)
	local C = TV(s * 0.44, 1.18, -0.37)
	local D = TV(s * 0.37, 0.62, -0.37)
	local E = TV(s * 0.28, 0.16, -0.34)
	local F = TV(s * 0.27, 1.12, -0.35)
	tri(torso, "Lapel", A, B, F, 0.05, COAT_RAISED, FABRIC)
	tri(torso, "Lapel", B, C, F, 0.05, COAT_RAISED, FABRIC)
	tri(torso, "Lapel", C, D, F, 0.05, COAT, FABRIC)
	tri(torso, "Lapel", D, E, F, 0.05, COAT, FABRIC)
	bar(torso, "LapelFacing", A, F, 0.06, 0.045, LINING, FABRIC)
	bar(torso, "LapelFacing", F, E, 0.06, 0.045, LINING, FABRIC)
	bar(torso, "LapelEdge", B, C, 0.035, 0.06, BRASS_DARK, METAL)
	bar(torso, "LapelEdge", C, D, 0.035, 0.06, BRASS_DARK, METAL)
end
-- the high flared collar: seven panels round the back of the neck, leaning out, sea-green inside, a raised edge
for _, deg in ipairs({ -118, -84, -44, 0, 44, 84, 118 }) do
	local a = math.rad(deg)
	local o = UPPER:VectorToWorldSpace(Vector3.new(math.sin(a), 0, math.cos(a)))
	local base = TV(math.sin(a) * 0.33, 1.6, 0.06 + math.cos(a) * 0.27)
	local front = math.abs(deg) > 100
	local h = front and 0.64 or (deg == 0 and 0.84 or 0.78)
	local lean = math.rad(front and 14 or 21)
	local up = UPPER.UpVector * math.cos(lean) + o * math.sin(lean)
	local cf = CFrame.fromMatrix(base + up * h / 2 + o * 0.03, up:Cross(o).Unit, up)
	deco(torso, "Collar", Vector3.new(0.46, h, 0.05), cf, COAT, FABRIC)
	deco(torso, "CollarLining", Vector3.new(0.44, h * 0.96, 0.03), cf * CFrame.new(0, -0.01, -0.045), LINING, FABRIC)
	deco(torso, "CollarEdge", Vector3.new(0.46, 0.045, 0.09), cf * CFrame.new(0, h / 2, -0.01), front and BRASS_DARK or COAT_RAISED, front and METAL or FABRIC)
end
-- the baldric from his right shoulder across the chest (it stops at the belt; the pelvis carries its lower end)
do
	local a, m, b = TV(0.5, 1.5, -0.42), TV(0.02, 0.78, -0.39), TV(-0.42, 0.08, -0.4)
	bar(torso, "Baldric", a, m, 0.17, 0.05, LEATHER, SMOOTH)
	bar(torso, "Baldric", m, b, 0.17, 0.05, LEATHER, SMOOTH)
	local bk = CFrame.lookAt(a:Lerp(m, 0.45), m) -- the buckle on the chest
	deco(torso, "BaldricBuckle", Vector3.new(0.24, 0.07, 0.2), bk, BRASS, METAL)
	deco(torso, "BaldricBuckleHole", Vector3.new(0.14, 0.075, 0.1), bk, LEATHER_DARK)
	deco(torso, "BaldricTongue", Vector3.new(0.03, 0.08, 0.12), bk * CFrame.new(0, 0, -0.02), BRASS_LIGHT, METAL)
	bar(torso, "BaldricRivet", m:Lerp(b, 0.5) + UPPER.LookVector * 0.03, m:Lerp(b, 0.52) + UPPER.LookVector * 0.03, 0.06, 0.06, BRASS_DARK, METAL)
end
-- across the back: a chain between the shoulders with a small anchor medallion
do
	chain(torso, "BackChain", TV(-0.48, 1.46, 0.45), TV(0.48, 1.46, 0.45), 0.24, 8, 0.03, BRASS_DARK)
	local c = T(0, 1.18, 0.47) * CFrame.Angles(0, math.pi, 0)
	deco(torso, "BackAnchor", Vector3.new(0.04, 0.24, 0.03), c, BRASS, METAL)
	deco(torso, "BackAnchorStock", Vector3.new(0.15, 0.035, 0.03), c * CFrame.new(0, 0.07, 0), BRASS, METAL)
	bar(torso, "BackAnchorArm", (c * CFrame.new(0, -0.12, 0)).Position, (c * CFrame.new(0.1, -0.05, 0)).Position, 0.035, 0.03, BRASS, METAL)
	bar(torso, "BackAnchorArm", (c * CFrame.new(0, -0.12, 0)).Position, (c * CFrame.new(-0.1, -0.05, 0)).Position, 0.035, 0.03, BRASS, METAL)
end

-- ====================================================================
-- Head: the skull (bone round dark recesses), the jaw on its own hinge, the neck
-- ====================================================================
cat = "Skull"
local head = part("Head", Vector3.new(0.66, 0.66, 0.66), H(0, 0.13, 0.05), BONE, SMOOTH, Enum.PartType.Ball)
motor("Neck", torso, head, NECK)
deco(head, "Forehead", Vector3.new(0.52, 0.22, 0.12), H(0, 0.2, -0.24) * CFrame.Angles(math.rad(-12), 0, 0), BONE)
deco(head, "Occiput", Vector3.new(0.48, 0.3, 0.1), H(0, -0.02, 0.36), BONE_DARK)
for _, s in ipairs({ -1, 1 }) do
	deco(head, "Temple", Vector3.new(0.07, 0.3, 0.42), H(s * 0.29, 0.04, 0.0), BONE_DARK)
	-- the sockets: dark and deep, with a severe brow (low at the inside), a rim round the outside and below
	deco(head, "Socket", Vector3.new(0.19, 0.17, 0.1), H(s * 0.135, -0.05, -0.25) * CFrame.Angles(0, 0, s * math.rad(-8)), VOID)
	bar(head, "Brow", HV(s * 0.03, 0.02, -0.33), HV(s * 0.27, 0.1, -0.28), 0.08, 0.07, BONE)
	bar(head, "SocketRim", HV(s * 0.26, 0.08, -0.28), HV(s * 0.27, -0.13, -0.27), 0.06, 0.06, BONE)
	bar(head, "SocketRim", HV(s * 0.05, -0.15, -0.32), HV(s * 0.26, -0.12, -0.28), 0.06, 0.06, BONE)
	-- the eyes: small, set back in the sockets, a pale hot centre
	glow(head, "Eye", Vector3.new(0.075, 0.05, 0.02), H(s * 0.135, -0.05, -0.305) * CFrame.Angles(0, 0, s * math.rad(-10)), SOUL, 0.05)
	glow(head, "EyeCore", Vector3.new(0.028, 0.026, 0.02), H(s * 0.135, -0.05, -0.318), SOUL_CORE)
	-- cheekbones and the hollow under them, the arch back to the ear
	deco(head, "Cheekbone", Vector3.new(0.1, 0.09, 0.24), H(s * 0.27, -0.16, -0.17) * CFrame.Angles(0, s * math.rad(-15), 0), BONE)
	deco(head, "CheekHollow", Vector3.new(0.2, 0.08, 0.2), H(s * 0.2, -0.25, -0.19), BONE_SHADOW)
	bar(head, "ZygomaticArch", HV(s * 0.3, -0.15, -0.08), HV(s * 0.3, -0.12, 0.15), 0.05, 0.05, BONE_DARK)
	bar(head, "NasalSide", HV(s * 0.015, -0.1, -0.35), HV(s * 0.08, -0.26, -0.335), 0.035, 0.035, BONE)
end
deco(head, "NasalBridge", Vector3.new(0.07, 0.13, 0.06), H(0, -0.03, -0.335), BONE)
tri(head, "NasalCavity", HV(0, -0.1, -0.345), HV(-0.065, -0.25, -0.33), HV(0.065, -0.25, -0.33), 0.04, VOID)
deco(head, "Maxilla", Vector3.new(0.36, 0.16, 0.1), H(0, -0.25, -0.27), BONE_DARK)
deco(head, "UpperRidge", Vector3.new(0.34, 0.06, 0.08), H(0, -0.33, -0.29), BONE)
deco(head, "Mouth", Vector3.new(0.3, 0.14, 0.08), H(0, -0.42, -0.23), VOID)
for k = 0, 7 do -- the upper teeth along a slight arc (on the skull)
	local x = -0.15 + k * 0.043
	deco(head, "ToothUpper", Vector3.new(0.036, 0.08, 0.04), H(x, -0.385, -0.3 + x * x * 1.6) * CFrame.Angles(0, x * 1.5, 0), k % 3 == 1 and BONE_DARK or BONE)
end
for k = 0, 1 do -- the neck: two vertebrae under the skull (a third sits on the torso)
	deco(head, "NeckVertebra", Vector3.new(0.13, 0.09, 0.13), H(0, -0.37 - k * 0.13, 0.1), BONE_DARK)
end
deco(torso, "NeckVertebra", Vector3.new(0.14, 0.09, 0.14), T(0, 1.76, 0.06), BONE_DARK)
attach(head, "EyeLight", H(0, -0.05, -0.42))
light(head:FindFirstChild("EyeLight"), 2.4, 1.1, SOUL)
-- the jaw: its own hinge under the ear line; the lower teeth ride with it
local jawHinge = H(0, -0.26, 0.06)
local jaw = part("JawRoot", Vector3.new(0.24, 0.1, 0.12), H(0, -0.56, -0.25), BONE)
motor("Jaw", head, jaw, jawHinge)
deco(jaw, "JawRidge", Vector3.new(0.28, 0.05, 0.07), H(0, -0.51, -0.25), BONE)
for _, s in ipairs({ -1, 1 }) do
	bar(jaw, "Mandible", HV(s * 0.11, -0.55, -0.24), HV(s * 0.25, -0.5, -0.02), 0.07, 0.09, BONE)
	bar(jaw, "Ramus", HV(s * 0.25, -0.5, -0.02), HV(s * 0.26, -0.27, 0.06), 0.06, 0.08, BONE_DARK)
end
for k = 0, 6 do
	local x = -0.13 + k * 0.043
	deco(jaw, "ToothLower", Vector3.new(0.034, 0.065, 0.035), H(x, -0.465, -0.27 + x * x * 1.6) * CFrame.Angles(0, x * 1.5, 0), k % 3 == 2 and BONE_DARK or BONE)
end

-- ====================================================================
-- The tricorn (its own joint Hat: everything on it moves with it). Three upturned walls round a crown; the corners rise,
-- his right back corner droops; a skull-and-anchor badge on the front point, a hatband, a chain, barnacles, seaweed.
-- ====================================================================
cat = "Hat"
local HATF = H(0, 0.3, 0.04) * CFrame.Angles(math.rad(-6), 0, math.rad(-3))
local function HTV(x, y, z)
	return (HATF * CFrame.new(x, y, z)).Position
end
local hat = part("HatRoot", Vector3.new(0.84, 0.42, 0.8), HATF * CFrame.new(0, 0.21, 0.04), COAT, FABRIC)
motor("Hat", head, hat, HATF)
deco(hat, "HatCrownTop", Vector3.new(0.7, 0.12, 0.66), HATF * CFrame.new(0, 0.46, 0.06), COAT_RAISED, FABRIC)
for _, s in ipairs({ -1, 1 }) do
	deco(hat, "HatCrownBevel", Vector3.new(0.14, 0.3, 0.74), HATF * CFrame.new(s * 0.36, 0.36, 0.05) * CFrame.Angles(0, 0, s * math.rad(-35)), COAT, FABRIC)
end
-- the hatband round the crown with a brass clasp on his left
deco(hat, "Hatband", Vector3.new(0.86, 0.1, 0.03), HATF * CFrame.new(0, 0.07, -0.375), LEATHER_DARK)
deco(hat, "Hatband", Vector3.new(0.86, 0.1, 0.03), HATF * CFrame.new(0, 0.07, 0.455), LEATHER_DARK)
deco(hat, "Hatband", Vector3.new(0.03, 0.1, 0.84), HATF * CFrame.new(-0.435, 0.07, 0.04), LEATHER_DARK)
deco(hat, "Hatband", Vector3.new(0.03, 0.1, 0.84), HATF * CFrame.new(0.435, 0.07, 0.04), LEATHER_DARK)
deco(hat, "HatbandClasp", Vector3.new(0.04, 0.09, 0.1), HATF * CFrame.new(-0.455, 0.07, 0.12), BRASS, METAL)
-- the brim: the underside, then the walls
local CENTRE = Vector3.new(0, 0, 0.05)
local CF_, CL_, CR_ = Vector3.new(0, 0, -1.02), Vector3.new(-1.0, 0, 0.6), Vector3.new(1.02, 0, 0.62)
local function pulled(a, b)
	return CENTRE + ((a + b) / 2 - CENTRE) * 0.86
end
local MFL, MB, MFR = pulled(CF_, CL_), pulled(CL_, CR_), pulled(CR_, CF_)
tri(hat, "HatBrimUnder", HTV(CF_.X, -0.02, CF_.Z), HTV(CL_.X, -0.02, CL_.Z), HTV(CR_.X, -0.02, CR_.Z), 0.05, COAT_DEEP, FABRIC)
local LEAN = math.rad(24)
local hatWalls = {}
local function hatWall(a, b, ha, hb, trim)
	local e = b - a
	local n = Vector3.new(-e.Z, 0, e.X).Unit
	if n:Dot((a + b) / 2 - CENTRE) < 0 then
		n = -n
	end
	local u = Vector3.new(0, 1, 0) * math.cos(LEAN) + n * math.sin(LEAN)
	local aW, bW = HTV(a.X, a.Y, a.Z), HTV(b.X, b.Y, b.Z)
	local uW, eW = HATF:VectorToWorldSpace(u), HATF:VectorToWorldSpace(e).Unit
	local hmin = math.min(ha, hb)
	local len = e.Magnitude + 0.05
	deco(hat, "HatWall", Vector3.new(len, hmin, 0.08), CFrame.fromMatrix((aW + bW) / 2 + uW * hmin / 2, eW, uW), COAT, FABRIC)
	if ha > hb then
		tri(hat, "HatWallRise", aW + uW * hmin, aW + uW * ha, bW + uW * hmin, 0.08, COAT, FABRIC)
	elseif hb > ha then
		tri(hat, "HatWallRise", bW + uW * hmin, bW + uW * hb, aW + uW * hmin, 0.08, COAT, FABRIC)
	end
	if trim then
		local t0, t1 = aW + uW * (ha + 0.015), bW + uW * (hb + 0.015)
		bar(hat, "HatTrim", t0, t0:Lerp(t1, trim), 0.045, 0.05, BRASS_DARK, METAL)
	end
	table.insert(hatWalls, { a = aW, b = bW, u = uW, n = HATF:VectorToWorldSpace(n), ha = ha, hb = hb })
end
hatWall(CF_, MFL, 0.44, 0.3, 1)
hatWall(MFL, CL_, 0.3, 0.72, 1)
hatWall(CL_, MB, 0.72, 0.38, 1)
hatWall(MB, CR_, 0.38, 0.6, 0.45) -- (the damaged back: the trim is torn away)
hatWall(CR_, MFR, 0.6, 0.28, 0.6)
hatWall(MFR, CF_, 0.28, 0.44, 1)
-- the corner points: the front and his left rise, his right droops and splits
do
	local w1, w6 = hatWalls[1], hatWalls[6]
	local fTop = w1.a + (w1.u + w6.u) / 2 * 0.44
	bar(hat, "HatTip", fTop - (w1.u + w6.u) / 2 * 0.06, fTop + (w1.u + w6.u) / 2 * 0.08, 0.1, 0.08, COAT, FABRIC)
	local w2, w3 = hatWalls[2], hatWalls[3]
	local lTop = w2.b + (w2.u + w3.u) / 2 * 0.72
	bar(hat, "HatTip", lTop - Vector3.new(0, 0.06, 0), lTop + (w2.n + w3.n).Unit * 0.12 + Vector3.new(0, 0.1, 0), 0.1, 0.08, COAT, FABRIC)
	local w4, w5 = hatWalls[4], hatWalls[5]
	local rTop = w4.b + (w4.u + w5.u) / 2 * 0.6
	local rOut = (w4.n + w5.n).Unit
	local droop = rTop + rOut * 0.24 - Vector3.new(0, 0.2, 0)
	bar(hat, "HatTipDroop", rTop, droop, 0.13, 0.08, COAT, FABRIC)
	bar(hat, "HatTipSplit", rTop + rOut * 0.05, rTop + rOut * 0.2 - Vector3.new(0, 0.05, 0) + HATF.LookVector * 0.08, 0.06, 0.07, COAT_RAISED, FABRIC)
	-- seaweed hanging from the drooping corner
	seaweed(hat, droop, 3, 0.2, 0.07)
	seaweed(hat, droop:Lerp(rTop, 0.6) + HATF.LookVector * 0.06, 3, 0.16, 0.06)
	-- a short chain hanging from his left corner along the side
	chain(hat, "HatChain", lTop - Vector3.new(0, 0.12, 0), w2.a + w2.u * 0.22, 0.22, 5, 0.03, IRON)
	-- barnacles clustered on his left front wall, near the corner
	for i, b in ipairs({ { 0.62, 0.34, 0.15 }, { 0.75, 0.48, 0.11 }, { 0.5, 0.18, 0.09 }, { 0.82, 0.24, 0.08 } }) do
		local pos = w2.a:Lerp(w2.b, b[1]) + w2.u * b[2] + w2.n * 0.04
		barnacle(hat, pos, w2.n + Vector3.new(0, 0.3 * (i % 2), 0), b[3])
	end
end
-- the skull-and-anchor badge on the front point
do
	local bf = HATF * CFrame.new(0, 0.25, -1.07) * CFrame.Angles(-0.38, 0, 0)
	local function B(x, y, z)
		return (bf * CFrame.new(x, y, z)).Position
	end
	cyl(hat, "BadgeCockade", B(0, 0, 0), bf.LookVector, 0.03, 0.34, COAT_DEEP, FABRIC)
	deco(hat, "BadgeShank", Vector3.new(0.04, 0.26, 0.03), bf * CFrame.new(0, -0.01, -0.03), BRASS, METAL)
	cyl(hat, "BadgeRing", B(0, 0.145, -0.03), bf.LookVector, 0.03, 0.07, BRASS, METAL)
	deco(hat, "BadgeStock", Vector3.new(0.17, 0.035, 0.03), bf * CFrame.new(0, 0.085, -0.03), BRASS, METAL)
	for _, s in ipairs({ -1, 1 }) do
		bar(hat, "BadgeArm", B(0, -0.13, -0.03), B(s * 0.1, -0.06, -0.03), 0.035, 0.03, BRASS, METAL)
		bar(hat, "BadgeFluke", B(s * 0.095, -0.07, -0.032), B(s * 0.125, 0.0, -0.032), 0.045, 0.028, BRASS_LIGHT, METAL)
	end
	deco(hat, "BadgeSkull", Vector3.new(0.09, 0.09, 0.09), bf * CFrame.new(0, 0.03, -0.06), BONE, SMOOTH, Enum.PartType.Ball)
	deco(hat, "BadgeSkullJaw", Vector3.new(0.05, 0.03, 0.03), bf * CFrame.new(0, -0.02, -0.065), BONE)
	for _, s in ipairs({ -1, 1 }) do
		deco(hat, "BadgeSkullEye", Vector3.new(0.022, 0.022, 0.02), bf * CFrame.new(s * 0.019, 0.035, -0.1), VOID)
	end
end

-- ====================================================================
-- Weapon frames (the arms are built gripping them)
-- ====================================================================
-- the cutlass: the right fist's centre GRIP_R, the blade running down and out along CUT_DIR
local GRIP_R = Vector3.new(1.2, 3.6, -0.3)
local CUT_DIR = Vector3.new(0.62, -0.58, -0.52).Unit
local FORE_R = Vector3.new(0.2, -0.96, -0.12).Unit
local cutWrist = (-FORE_R - CUT_DIR * (-FORE_R):Dot(CUT_DIR)).Unit -- from the handle towards the wrist (the spine side)
local cutPalm = CUT_DIR:Cross(cutWrist).Unit
if cutPalm.X > 0 then
	cutPalm = -cutPalm -- the palm faces his body
end
local CUT = CFrame.lookAt(GRIP_R, GRIP_R + CUT_DIR, cutWrist) -- origin = the grip centre, -Z = the blade, +Y = the spine
local function CV(x, y, z)
	return (CUT * CFrame.new(x, y, z)).Position
end
local WRIST_R = GRIP_R + cutPalm * 0.13 + cutWrist * 0.3

-- the flintlock: the left fist's centre GRIP_L, the muzzle pointing down, forward and out; the top of the gun outwards
local GRIP_L = Vector3.new(-1.2, 3.62, -0.26)
local PIS_DIR = Vector3.new(-0.46, -0.76, -0.46).Unit
local PIS_ROT = CFrame.lookAt(Vector3.zero, PIS_DIR, Vector3.new(-0.7, 0, -0.7))
local GC_LOCAL = Vector3.new(0, -0.34, 0.3) -- the fist's centre on the grip, in the gun's frame (origin = the breech)
local PIS = PIS_ROT + (GRIP_L - PIS_ROT:VectorToWorldSpace(GC_LOCAL))
local function PS(x, y, z)
	return (PIS * CFrame.new(x, y, z)).Position
end
local palmSign = PIS.RightVector.X > 0 and 1 or -1 -- the gun's side towards his body takes the palm
local LOCK = -palmSign -- the lock, pan and cock face outwards
local pisAxis = PIS:VectorToWorldSpace(Vector3.new(0, 0.894, -0.447)) -- up the grip, towards the trigger
local pisWrist = PIS:VectorToWorldSpace(Vector3.new(0, 0.447, 0.894))
local pisPalm = PIS.RightVector * palmSign
local WRIST_L = GRIP_L + pisPalm * 0.12 + pisWrist * 0.32

-- ====================================================================
-- Arms: fitted sleeves with a turned-back cuff, worn at the elbow, blackened iron bracers, bare wrist bones, skeletal
-- hands closed round the weapons. The epaulettes ride on the upper arms.
-- ====================================================================
local UPPER_LEN, FORE_LEN = 1.15, 1.1
local function arm(side, shoulder, wrist, pole)
	local s = side == "R" and 1 or -1
	local elbow = solveJoint(shoulder, wrist, UPPER_LEN, FORE_LEN, pole)
	local upper = carrier(side .. "UpperArm", CFrame.lookAt((shoulder + elbow) / 2, elbow))
	motor(side .. "Shoulder", torso, upper, shoulder)
	cat = "Arms"
	local d1 = (elbow - shoulder).Unit
	bar(upper, "Sleeve", shoulder, elbow + d1 * 0.04, 0.36, 0.36, COAT, FABRIC)
	bar(upper, "SleeveCap", shoulder - d1 * 0.1, shoulder + d1 * 0.3, 0.44, 0.44, COAT_RAISED, FABRIC)
	bar(upper, "SleeveWorn", shoulder:Lerp(elbow, 0.84), elbow + d1 * 0.06, 0.385, 0.385, COAT_DEEP, FABRIC)
	local fore = carrier(side .. "Forearm", CFrame.lookAt((elbow + wrist) / 2, wrist))
	motor(side .. "Elbow", upper, fore, elbow)
	local d = (wrist - elbow).Unit
	local out = Vector3.new(s, 0, 0)
	out = (out - d * out:Dot(d)).Unit
	bar(fore, "ForeSleeve", elbow - d * 0.05, elbow:Lerp(wrist, 0.5), 0.34, 0.34, COAT, FABRIC)
	bar(fore, "CuffLining", elbow:Lerp(wrist, 0.31), elbow:Lerp(wrist, 0.35), 0.41, 0.41, LINING, FABRIC)
	bar(fore, "Cuff", elbow:Lerp(wrist, 0.34), elbow:Lerp(wrist, 0.52), 0.43, 0.43, COAT_RAISED, FABRIC)
	-- torn strips hanging from the worn elbow
	for k = 0, 2 do
		local p = elbow:Lerp(wrist, 0.08 + k * 0.08) + out * 0.17 + (out:Cross(d)).Unit * (k - 1) * 0.08
		bar(fore, "SleeveTatter", p, p + Vector3.new(0, -0.22 - k * 0.05, 0) + out * 0.03, 0.08, 0.025, k == 1 and COAT_RAISED or COAT, FABRIC)
	end
	-- the bracer: an iron sleeve, a raised outer plate with rivets, two lames at the wrist, leather straps, a brass edge
	bar(fore, "Bracer", elbow:Lerp(wrist, 0.48), elbow:Lerp(wrist, 0.9), 0.31, 0.31, IRON_DARK, METAL)
	bar(fore, "BracerPlate", elbow:Lerp(wrist, 0.5) + out * 0.14, elbow:Lerp(wrist, 0.86) + out * 0.14, 0.2, 0.08, IRON, METAL)
	bar(fore, "BracerLame", elbow:Lerp(wrist, 0.85), elbow:Lerp(wrist, 0.92), 0.33, 0.33, IRON, METAL)
	bar(fore, "BracerLame", elbow:Lerp(wrist, 0.9), elbow:Lerp(wrist, 0.96), 0.31, 0.31, IRON_DARK, METAL)
	bar(fore, "BracerEdge", elbow:Lerp(wrist, 0.47), elbow:Lerp(wrist, 0.5), 0.34, 0.34, BRASS_DARK, METAL)
	for _, f in ipairs({ 0.58, 0.76 }) do
		bar(fore, "BracerStrap", elbow:Lerp(wrist, f - 0.025), elbow:Lerp(wrist, f + 0.025), 0.335, 0.335, LEATHER_DARK)
	end
	for _, f in ipairs({ 0.54, 0.67, 0.81 }) do
		ball(fore, "BracerRivet", elbow:Lerp(wrist, f) + out * 0.185, 0.055, BRASS, METAL)
	end
	local perp = d:Cross(out).Unit
	for _, k in ipairs({ -1, 1 }) do
		bar(fore, "WristBone", elbow:Lerp(wrist, 0.93) + perp * k * 0.05, wrist + perp * k * 0.03, 0.06, 0.06, BONE)
	end
	cat = "Hands"
	local hand = part(side .. "Hand", Vector3.new(0.16, 0.14, 0.16), CFrame.lookAt(wrist, wrist + d), BONE_DARK)
	motor(side .. "Wrist", fore, hand, wrist)
	return hand, upper, elbow
end

-- a skeletal fist round a handle: c = the handle's centre, axis = along the handle towards the index finger,
-- palmDir / wristDir = unit vectors across it towards the palm and the wrist. R scales the wrap for a thicker grip.
-- indexTo: the index finger lies straight to this point instead (off the trigger).
local function fist(hand, c, axis, palmDir, wristDir, wrist, R, indexTo)
	local function pt(deg, r, z)
		local a = math.rad(deg)
		return c + palmDir * (math.cos(a) * r * R) + wristDir * (math.sin(a) * r * R) + axis * z
	end
	deco(hand, "Palm", Vector3.new(0.3, 0.26, 0.07), CFrame.fromMatrix(pt(5, 0.15, 0) + wristDir * 0.07, axis, wristDir), BONE_SHADOW)
	local FINGERS = { { z = 0.11, w = 0.058 }, { z = 0.035, w = 0.062 }, { z = -0.04, w = 0.058 }, { z = -0.11, w = 0.05 } }
	for i, f in ipairs(FINGERS) do
		local k0 = pt(-40, 0.15, f.z)
		bar(hand, "Metacarpal", wrist + axis * f.z * 0.45 + palmDir * 0.03, k0, 0.05, 0.05, BONE)
		ball(hand, "Knuckle", k0, f.w * 1.35, BONE_DARK)
		if i == 1 and indexTo then
			local mid = k0:Lerp(indexTo, 0.55)
			bar(hand, "Finger", k0, mid, f.w, f.w, BONE)
			bar(hand, "FingerTip", mid, indexTo, f.w * 0.85, f.w * 0.85, BONE)
		else
			local k1 = pt(-112, 0.125, f.z)
			local k2 = pt(-180, 0.115, f.z)
			local tip = pt(-232, 0.1, f.z)
			bar(hand, "Finger", k0, k1, f.w, f.w, BONE)
			bar(hand, "FingerMid", k1, k2, f.w * 0.92, f.w * 0.92, BONE)
			bar(hand, "FingerTip", k2, tip, f.w * 0.8, f.w * 0.8, BONE_DARK)
		end
	end
	local t0, t1, t2 = pt(55, 0.2, 0.15), pt(105, 0.16, 0.2), pt(150, 0.13, 0.17)
	bar(hand, "Thumb", wrist + axis * 0.08, t0, 0.065, 0.065, BONE)
	bar(hand, "ThumbMid", t0, t1, 0.058, 0.058, BONE)
	bar(hand, "ThumbTip", t1, t2, 0.05, 0.05, BONE_DARK)
end

local rHand, rUpper = arm("R", R_SHOULDER, WRIST_R, Vector3.new(0.5, 0, 0.85))
fist(rHand, GRIP_R, CUT_DIR, cutPalm, cutWrist, WRIST_R, 1)
local lHand, lUpper = arm("L", L_SHOULDER, WRIST_L, Vector3.new(-0.5, 0, 0.85))
fist(lHand, GRIP_L, pisAxis, pisPalm, pisWrist, WRIST_L, 1.25, PS(palmSign * 0.1, -0.07, -0.34))

-- the epaulettes: a round board with a brass rim and boss, a strap towards the collar, a fringe under the outer edge
cat = "Epaulettes"
local EPAULETTE = {}
for _, sd in ipairs({ { "R", 1, rUpper }, { "L", -1, lUpper } }) do
	local s, upper = sd[2], sd[3]
	local e = CFrame.new(TV(s * 0.66, 1.63, 0.03)) * CFrame.Angles(0, 0, s * math.rad(-16))
	local up = e.UpVector
	cyl(upper, "EpauletteBoard", e.Position, up, 0.07, 0.56, COAT_RAISED, FABRIC)
	cyl(upper, "EpauletteRim", e.Position - up * 0.035, up, 0.045, 0.6, BRASS_DARK, METAL)
	cyl(upper, "EpauletteBoss", e.Position + up * 0.05, up, 0.05, 0.3, BRASS, METAL)
	deco(upper, "EpauletteStrap", Vector3.new(0.36, 0.05, 0.17), e * CFrame.new(-s * 0.32, 0.03, 0), BRASS_DARK, METAL)
	ball(upper, "EpauletteButton", (e * CFrame.new(-s * 0.46, 0.06, 0)).Position, 0.08, BRASS_LIGHT, METAL)
	for k = 0, 7 do
		local th = math.rad(-78 + k * 22)
		local top = (e * CFrame.new(s * math.cos(th) * 0.27, -0.03, math.sin(th) * 0.27)).Position
		local bottom = (e * CFrame.new(s * (math.cos(th) * 0.27 + 0.04), -0.31 - (k % 2) * 0.03, math.sin(th) * 0.29)).Position
		bar(upper, "EpauletteFringe", top, bottom, 0.045, 0.045, k % 2 == 0 and BRASS or BRASS_DARK, METAL)
	end
	EPAULETTE[sd[1]] = e
end
-- barnacles on the left epaulette and a strand of seaweed from its fringe
do
	local e = EPAULETTE.L
	for i, b in ipairs({ { 0.12, 0.08, 0.13 }, { 0.2, -0.1, 0.09 }, { -0.02, 0.18, 0.08 } }) do
		barnacle(lUpper, (e * CFrame.new(-b[1], 0.05, b[2])).Position, e.UpVector + Vector3.new(-0.2 * i, 0, 0), b[3])
	end
	seaweed(lUpper, (e * CFrame.new(0.27, -0.05, -0.12)).Position, 3, 0.2, 0.07)
end

-- ====================================================================
-- The cutlass (Cutlass: RHand -> CutlassRoot, the grip). A dark curved blade with a spine, a lighter bevel and a thin
-- sea-green edge, a brass shell guard with a knuckle bow over the fingers, a wrapped grip and a pommel.
-- ====================================================================
cat = "Cutlass"
local cutlass = part("CutlassRoot", Vector3.new(0.41, 0.12, 0.12), CUT * CFrame.Angles(0, math.pi / 2, 0), LEATHER_DARK, SMOOTH, Enum.PartType.Cylinder)
motor("Cutlass", rHand, cutlass, CUT)
local GUARD_Z = -0.22 -- the guard, in front of the index finger
for _, z in ipairs({ -0.12, -0.02, 0.08 }) do
	deco(cutlass, "GripWrap", Vector3.new(0.025, 0.13, 0.13), CUT * CFrame.new(0, 0, z) * CFrame.Angles(0.35, math.pi / 2, 0), BRASS_DARK, METAL, Enum.PartType.Cylinder)
end
ball(cutlass, "Pommel", CV(0, 0, 0.25), 0.13, BRASS, METAL)
cyl(cutlass, "PommelCap", CV(0, 0, 0.31), CUT.LookVector, 0.05, 0.08, BRASS_DARK, METAL)
cyl(cutlass, "GuardShell", CV(0, -0.02, GUARD_Z), CUT.LookVector, 0.04, 0.36, BRASS, METAL)
deco(cutlass, "GuardVerdigris", Vector3.new(0.15, 0.12, 0.045), CUT * CFrame.new(0.04, -0.07, GUARD_Z) * CFrame.Angles(0, 0, 0.5), VERDIGRIS)
deco(cutlass, "Ferrule", Vector3.new(0.08, 0.22, 0.1), CUT * CFrame.new(0, 0, GUARD_Z - 0.06), IRON_DARK, METAL)
bar(cutlass, "Quillon", CV(0, 0.05, GUARD_Z), CV(0, 0.19, GUARD_Z + 0.03), 0.05, 0.05, BRASS, METAL)
ball(cutlass, "QuillonKnob", CV(0, 0.21, GUARD_Z + 0.04), 0.075, BRASS_LIGHT, METAL)
do -- the knuckle bow, from the shell round the fingers to the pommel, and two side bars of the basket
	local pts = { CV(0, -0.16, GUARD_Z), CV(0, -0.25, -0.12), CV(0, -0.27, 0.02), CV(0, -0.23, 0.16), CV(0, -0.06, 0.26) }
	for k = 1, #pts - 1 do
		bar(cutlass, "KnuckleBow", pts[k], pts[k + 1], 0.045, 0.045, BRASS, METAL)
	end
	for _, s in ipairs({ -1, 1 }) do
		bar(cutlass, "GuardBasket", CV(s * 0.1, -0.13, GUARD_Z), CV(s * 0.07, -0.25, -0.03), 0.035, 0.035, BRASS_DARK, METAL)
	end
end
-- the blade: five segments curving back towards the spine, then a clipped point
local bladeTipCF
do
	local frame = CUT * CFrame.new(0, 0, GUARD_Z - 0.1)
	local SEGS = { 0.46, 0.46, 0.46, 0.44, 0.4 }
	for k, L in ipairs(SEGS) do
		local h = 0.22 - k * 0.006
		local c = frame * CFrame.new(0, 0, -L / 2)
		deco(cutlass, "Blade", Vector3.new(0.05, h, L + 0.05), c, BLADE, METAL)
		deco(cutlass, "BladeSpine", Vector3.new(0.065, 0.03, L + 0.05), c * CFrame.new(0, h / 2, 0), IRON_DARK, METAL)
		deco(cutlass, "BladeBevel", Vector3.new(0.035, 0.05, L + 0.05), c * CFrame.new(0, -h / 2 - 0.02, 0), BLADE_EDGE, METAL)
		glow(cutlass, "BladeEdge", Vector3.new(0.02, 0.022, L + 0.05), c * CFrame.new(0, -h / 2 - 0.054, 0), SOUL, 0.1)
		if k <= 3 then
			deco(cutlass, "BladeFuller", Vector3.new(0.056, 0.035, L + 0.02), c * CFrame.new(0, h * 0.2, 0), IRON_DARK, METAL)
		end
		frame = frame * CFrame.new(0, 0, -L) * CFrame.Angles(math.rad(5), 0, 0)
	end
	local h = 0.19
	local spine = (frame * CFrame.new(0, h / 2 + 0.015, 0)).Position
	local edge = (frame * CFrame.new(0, -h / 2 - 0.065, 0)).Position
	local tip = (frame * CFrame.new(0, h * 0.35, -0.44)).Position
	tri(cutlass, "BladeTip", spine, edge, tip, 0.05, BLADE, METAL)
	bar(cutlass, "BladeTipEdge", edge + (frame.UpVector * 0.01), tip, 0.022, 0.022, SOUL, NEON).Transparency = 0.1
	deco(cutlass, "BladeRust", Vector3.new(0.055, 0.08, 0.16), CUT * CFrame.new(0, 0.03, GUARD_Z - 1.1), IRON_DARK, METAL)
	bladeTipCF = CFrame.lookAt(tip, tip + (tip - spine:Lerp(edge, 0.5)).Unit, frame.UpVector)
end
attach(cutlass, "CutlassGrip", CUT)
attach(cutlass, "BladeBase", CUT * CFrame.new(0, 0, GUARD_Z - 0.1))
attach(cutlass, "BladeTip", bladeTipCF)
attach(cutlass, "CommandPoint", CUT * CFrame.new(0, 0.08, GUARD_Z - 1.5) * CFrame.Angles(math.rad(8), 0, 0))

-- ====================================================================
-- The flintlock (Pistol: LHand -> PistolRoot, the stock's wrist). Frame PIS: origin on the bore line at the breech,
-- -Z = the muzzle direction, +Y = the top. A thick iron barrel with brass bands and a swelled muzzle with a recessed
-- bore, a wood stock, the lock (plate, pan, frizzen and the cock on its own joint) on the outer side, a brass trigger
-- guard, a curved grip with a brass butt cap.
-- ====================================================================
cat = "Pistol"
local pistol = part("PistolRoot", Vector3.new(0.16, 0.2, 0.42), PIS * CFrame.new(0, -0.07, 0.08), WOOD)
motor("Pistol", lHand, pistol, CFrame.new(GRIP_L) * PIS.Rotation)
local function PD(name, size, x, y, z, color, material, rx, ry, rz)
	return deco(pistol, name, size, PIS * CFrame.new(x, y, z) * CFrame.Angles(rx or 0, ry or 0, rz or 0), color, material)
end
local FWD = PIS.LookVector
PD("Forestock", Vector3.new(0.15, 0.12, 0.7), 0, -0.1, -0.38, WOOD)
cyl(pistol, "Barrel", PS(0, 0.02, -0.46), FWD, 0.92, 0.17, IRON, METAL)
cyl(pistol, "Breech", PS(0, 0.02, 0.0), FWD, 0.12, 0.2, IRON_DARK, METAL)
for _, z in ipairs({ -0.25, -0.52, -0.74 }) do
	cyl(pistol, "BarrelBand", PS(0, 0.0, z), FWD, 0.05, 0.22, BRASS, METAL)
end
cyl(pistol, "MuzzleSwell", PS(0, 0.02, -0.88), FWD, 0.12, 0.245, BRASS, METAL)
for k = 0, 5 do -- a lip round the bore, standing proud of the swell so the dark bore sits back inside it
	local a = k / 6 * math.pi * 2
	local c = PIS * CFrame.new(0, 0.02, -0.96) * CFrame.Angles(0, 0, a) * CFrame.new(0, 0.1, 0)
	deco(pistol, "MuzzleLip", Vector3.new(0.11, 0.045, 0.06), c, BRASS_LIGHT, METAL)
end
cyl(pistol, "MuzzleBore", PS(0, 0.02, -0.935), FWD, 0.02, 0.155, VOID)
PD("FrontSight", Vector3.new(0.025, 0.04, 0.05), 0, 0.12, -0.82, BRASS, METAL)
cyl(pistol, "Ramrod", PS(0, -0.19, -0.5), FWD, 0.78, 0.045, IRON_DARK, METAL)
for _, z in ipairs({ -0.42, -0.76 }) do
	cyl(pistol, "RamrodPipe", PS(0, -0.19, z), FWD, 0.06, 0.07, BRASS, METAL)
end
PD("LockPlate", Vector3.new(0.025, 0.13, 0.38), LOCK * 0.085, -0.04, 0.05, IRON_DARK, METAL)
PD("Pan", Vector3.new(0.06, 0.04, 0.08), LOCK * 0.1, 0.03, -0.09, BRASS, METAL)
PD("Frizzen", Vector3.new(0.04, 0.16, 0.06), LOCK * 0.1, 0.12, -0.1, IRON, METAL, math.rad(-10))
PD("SidePlate", Vector3.new(0.02, 0.08, 0.3), -LOCK * 0.085, -0.05, 0.06, BRASS, METAL)
-- the cock on its own joint (PistolHammer), pivoting at the back of the lock plate
local HAMMER_PIVOT = PIS * CFrame.new(LOCK * 0.1, 0.0, 0.14)
local hammer = part("PistolHammerRoot", Vector3.new(0.045, 0.08, 0.06), HAMMER_PIVOT, IRON, METAL)
motor("PistolHammer", pistol, hammer, HAMMER_PIVOT)
bar(hammer, "HammerNeck", PS(LOCK * 0.1, 0.02, 0.14), PS(LOCK * 0.1, 0.15, 0.06), 0.045, 0.045, IRON, METAL)
deco(hammer, "HammerJaw", Vector3.new(0.05, 0.05, 0.08), PIS * CFrame.new(LOCK * 0.1, 0.17, 0.03), IRON, METAL)
deco(hammer, "Flint", Vector3.new(0.035, 0.03, 0.05), PIS * CFrame.new(LOCK * 0.1, 0.14, -0.02), Color3.fromRGB(70, 70, 66))
-- the trigger guard and the trigger (kept clear: the index finger lies along the side)
do
	local a, b, c, d = PS(0, -0.15, -0.2), PS(0, -0.3, -0.1), PS(0, -0.3, 0.06), PS(0, -0.18, 0.13)
	bar(pistol, "TriggerGuard", a, b, 0.035, 0.035, BRASS, METAL)
	bar(pistol, "TriggerGuard", b, c, 0.035, 0.035, BRASS, METAL)
	bar(pistol, "TriggerGuard", c, d, 0.035, 0.035, BRASS, METAL)
	bar(pistol, "Trigger", PS(0, -0.14, -0.03), PS(0, -0.25, 0.0), 0.025, 0.025, IRON, METAL)
end
-- the grip, curving down, and the brass butt cap with its spur
bar(pistol, "Grip", PS(0, -0.12, 0.18), PS(0, -0.43, 0.38), 0.15, 0.2, WOOD)
bar(pistol, "GripLow", PS(0, -0.4, 0.36), PS(0, -0.6, 0.43), 0.16, 0.22, WOOD)
bar(pistol, "ButtCap", PS(0, -0.6, 0.42), PS(0, -0.69, 0.47), 0.19, 0.25, BRASS, METAL)
bar(pistol, "ButtSpur", PS(0, -0.66, 0.5), PS(0, -0.78, 0.6), 0.06, 0.08, BRASS_DARK, METAL)
PD("ButtVerdigris", Vector3.new(0.195, 0.08, 0.08), 0, -0.66, 0.42, VERDIGRIS, nil, math.rad(-30))
attach(pistol, "Muzzle", PIS * CFrame.new(0, 0.02, -1.0))
attach(pistol, "PistolGrip", CFrame.new(GRIP_L) * PIS.Rotation)
attach(pistol, "Hammer", HAMMER_PIVOT)

-- ====================================================================
-- Legs: narrow trousers, tall buckled boots with a turned-down cuff, a shaped foot on its own ankle joint
-- ====================================================================
cat = "Legs"
local LEG = {}
local function leg(side, s)
	local hip = PV(s * 0.27, -0.12, 0)
	local ankle = Vector3.new(s * 0.5, ANKLE_Y, -0.04)
	local knee = solveJoint(hip, ankle, 1.62, 1.6, Vector3.new(s * 0.12, 0, -1))
	local thigh = carrier(side .. "Thigh", CFrame.lookAt((hip + knee) / 2, knee))
	motor(side .. "Hip", pelvis, thigh, hip)
	bar(thigh, "Trouser", hip + Vector3.new(0, 0.08, 0), knee, 0.42, 0.42, TROUSER, FABRIC)
	bar(thigh, "TrouserFold", hip:Lerp(knee, 0.55), hip:Lerp(knee, 0.62), 0.44, 0.44, COAT_DEEP, FABRIC)
	local shin = carrier(side .. "Shin", CFrame.lookAt((knee + ankle) / 2, ankle))
	motor(side .. "Knee", thigh, shin, knee)
	local d = (ankle - knee).Unit
	local fwd = Vector3.new(0, 0, -1)
	local out = Vector3.new(s, 0, 0)
	bar(shin, "BootCuff", knee - d * 0.1, knee + d * 0.3, 0.52, 0.54, LEATHER_DARK)
	bar(shin, "BootCuffRim", knee - d * 0.13, knee - d * 0.05, 0.56, 0.58, LEATHER)
	bar(shin, "BootShaft", knee + d * 0.25, ankle + d * 0.06, 0.4, 0.42, LEATHER)
	bar(shin, "BootShin", knee + d * 0.32 + fwd * 0.19, ankle - d * 0.08 + fwd * 0.2, 0.22, 0.06, LEATHER_DARK, SMOOTH)
	for _, f in ipairs({ 0.4, 0.62, 0.82 }) do
		local p = knee:Lerp(ankle, f)
		bar(shin, "BootStrap", p - d * 0.035, p + d * 0.035, 0.45, 0.46, LEATHER_DARK)
		deco(shin, "BootBuckle", Vector3.new(0.12, 0.1, 0.04), CFrame.lookAt(p + out * 0.235, p + out * 2), BRASS, METAL)
	end
	-- the foot: toes turned out a little; the sole on the floor
	local ft = CFrame.new(ankle) * CFrame.Angles(0, s * math.rad(-7), 0)
	local foot = part(side .. "Foot", Vector3.new(0.32, 0.28, 0.42), ft * CFrame.new(0, -0.2, -0.2) * CFrame.Angles(math.rad(-15), 0, 0), LEATHER)
	motor(side .. "Ankle", shin, foot, ankle)
	deco(foot, "BootSole", Vector3.new(0.34, 0.07, 1.02), ft * CFrame.new(0, -ANKLE_Y + 0.035, -0.28), SOLE_COLOR)
	deco(foot, "BootHeel", Vector3.new(0.3, 0.16, 0.26), ft * CFrame.new(0, -0.3, 0.09), LEATHER_DARK)
	deco(foot, "BootVamp", Vector3.new(0.3, 0.17, 0.4), ft * CFrame.new(0, -0.265, -0.52), LEATHER)
	cyl(foot, "BootToe", (ft * CFrame.new(0, -0.28, -0.7)).Position, Vector3.new(0, 1, 0), 0.15, 0.3, LEATHER_DARK)
	deco(foot, "InstepStrap", Vector3.new(0.35, 0.07, 0.1), ft * CFrame.new(0, -0.1, -0.25) * CFrame.Angles(math.rad(-15), 0, 0), LEATHER_DARK)
	deco(foot, "InstepBuckle", Vector3.new(0.04, 0.09, 0.1), ft * CFrame.new(s * 0.18, -0.11, -0.25), BRASS, METAL)
	LEG[side] = { knee = knee, ankle = ankle, shin = shin, foot = foot, out = out, fwd = fwd, ft = ft }
end
leg("R", 1)
leg("L", -1)
-- barnacles on the right boot: on the outer shaft and over the toe
do
	local L = LEG.R
	for _, b in ipairs({ { 0.66, 0.14, 0.0 }, { 0.74, 0.1, -0.12 }, { 0.56, 0.09, 0.12 } }) do
		local p = L.knee:Lerp(L.ankle, b[1]) + L.out * 0.21 + Vector3.new(0, 0, b[3])
		barnacle(L.shin, p, L.out + Vector3.new(0, 0, b[3]), b[2])
	end
	barnacle(L.foot, (L.ft * CFrame.new(0.08, -0.18, -0.6)).Position, Vector3.new(0.3, 1, -0.4), 0.09)
end

-- ====================================================================
-- The belt (pelvis): it wraps round the coat, a brass buckle, loops; the baldric's lower end and the holster; the
-- compass with its lid on a hinge; a waist chain and a loop at the right hip
-- ====================================================================
cat = "Belt"
deco(pelvis, "Belt", Vector3.new(0.9, 0.17, 0.05), PELVIS * CFrame.new(0, 0.3, -0.37), LEATHER)
deco(pelvis, "Belt", Vector3.new(0.98, 0.17, 0.05), PELVIS * CFrame.new(0, 0.3, 0.455), LEATHER)
for _, s in ipairs({ -1, 1 }) do
	deco(pelvis, "Belt", Vector3.new(0.05, 0.17, 0.86), PELVIS * CFrame.new(s * 0.6, 0.3, 0.04), LEATHER)
	tri(pelvis, "BeltCorner", PV(s * 0.43, 0.3, -0.39), PV(s * 0.62, 0.3, -0.22), PV(s * 0.52, 0.3, -0.36), 0.17, LEATHER)
	deco(pelvis, "BeltLoop", Vector3.new(0.05, 0.22, 0.07), PELVIS * CFrame.new(s * 0.62, 0.3, 0.2), LEATHER_DARK)
end
do -- the buckle: a brass frame round dark leather, a tongue
	local bk = PELVIS * CFrame.new(0.22, 0.3, -0.405)
	for _, e in ipairs({ { 0, 0.1, 0.24, 0.035 }, { 0, -0.1, 0.24, 0.035 }, { -0.105, 0, 0.035, 0.2 }, { 0.105, 0, 0.035, 0.2 } }) do
		deco(pelvis, "BeltBuckle", Vector3.new(e[3], e[4], 0.04), bk * CFrame.new(e[1], e[2], 0), BRASS, METAL)
	end
	deco(pelvis, "BeltTongue", Vector3.new(0.12, 0.03, 0.03), bk * CFrame.new(-0.03, 0, -0.01), BRASS_LIGHT, METAL)
end
-- the baldric's end under the belt, to the holster on his left hip
local HOLSTER_TOP, HOLSTER_TIP = PV(-0.48, 0.12, -0.5), PV(-0.58, -0.5, -0.56)
bar(pelvis, "BaldricLow", PV(-0.36, 0.38, -0.42), HOLSTER_TOP, 0.15, 0.045, LEATHER)
bar(pelvis, "Holster", HOLSTER_TOP, HOLSTER_TIP, 0.2, 0.13, LEATHER_DARK)
bar(pelvis, "HolsterMouth", HOLSTER_TOP - (HOLSTER_TIP - HOLSTER_TOP).Unit * 0.03, HOLSTER_TOP + (HOLSTER_TIP - HOLSTER_TOP).Unit * 0.05, 0.23, 0.16, BRASS_DARK, METAL)
bar(pelvis, "HolsterTip", HOLSTER_TIP - (HOLSTER_TIP - HOLSTER_TOP).Unit * 0.06, HOLSTER_TIP + (HOLSTER_TIP - HOLSTER_TOP).Unit * 0.02, 0.16, 0.1, BRASS_DARK, METAL)
attach(pelvis, "PistolHolster", CFrame.lookAt(HOLSTER_TOP, HOLSTER_TIP))
-- the compass (Compass: Pelvis -> CompassRoot, the housing; face towards -Z)
cat = "Compass"
local COMPASS = PELVIS * CFrame.new(-0.1, 0.3, -0.44)
local function CP(x, y, z)
	return (COMPASS * CFrame.new(x, y, z)).Position
end
local cfwd = COMPASS.LookVector
local compass = part("CompassRoot", Vector3.new(0.08, 0.34, 0.34), CFrame.lookAt(COMPASS.Position, COMPASS.Position + cfwd) * CFrame.Angles(0, math.pi / 2, 0), BRASS, METAL, Enum.PartType.Cylinder)
motor("Compass", pelvis, compass, COMPASS)
cyl(compass, "CompassBack", CP(0, 0, 0.045), cfwd, 0.03, 0.37, BRASS_DARK, METAL)
cyl(compass, "CompassFace", CP(0, 0, -0.045), cfwd, 0.02, 0.27, COAT_DEEP)
for k = 0, 3 do
	local a = k * math.pi / 2
	deco(compass, "CompassMark", Vector3.new(0.025, k == 0 and 0.06 or 0.04, 0.012), COMPASS * CFrame.Angles(0, 0, a) * CFrame.new(0, 0.1, -0.058), k == 0 and BRASS_LIGHT or BRASS, METAL)
end
local needle = COMPASS * CFrame.Angles(0, 0, math.rad(-28))
glow(compass, "CompassNeedle", Vector3.new(0.03, 0.1, 0.012), needle * CFrame.new(0, 0.05, -0.062), SOUL, 0.05)
deco(compass, "CompassNeedleTail", Vector3.new(0.03, 0.09, 0.012), needle * CFrame.new(0, -0.045, -0.062), IRON, METAL)
cyl(compass, "CompassPin", CP(0, 0, -0.065), cfwd, 0.02, 0.035, BRASS_LIGHT, METAL)
deco(compass, "CompassStem", Vector3.new(0.05, 0.06, 0.05), COMPASS * CFrame.new(0.17, 0.07, 0) * CFrame.Angles(0, 0, math.rad(-65)), BRASS, METAL)
cyl(compass, "CompassBow", CP(0.22, 0.09, 0), cfwd, 0.02, 0.09, BRASS_DARK, METAL)
cyl(compass, "CompassHinge", CP(0, 0.172, -0.035), COMPASS.RightVector, 0.11, 0.04, BRASS_DARK, METAL)
attach(compass, "CompassFace", COMPASS * CFrame.new(0, 0, -0.07))
attach(compass, "CompassGrip", COMPASS * CFrame.new(0, 0, 0.06))
-- the lid (CompassLid), hinged at the top and built OPEN: it stands above the housing, its engraved inside to the front
local LID_HINGE = COMPASS * CFrame.new(0, 0.172, -0.035)
local lid = part("CompassLidRoot", Vector3.new(0.035, 0.35, 0.35), CFrame.lookAt(CP(0, 0.345, 0.0), CP(0, 0.345, 0.0) + cfwd) * CFrame.Angles(0, math.pi / 2, 0), BRASS, METAL, Enum.PartType.Cylinder)
motor("CompassLid", compass, lid, LID_HINGE)
cyl(lid, "CompassLidInside", CP(0, 0.345, -0.02), cfwd, 0.01, 0.27, BRASS_DARK, METAL)
deco(lid, "CompassLidRose", Vector3.new(0.05, 0.05, 0.012), COMPASS * CFrame.new(0, 0.345, -0.026) * CFrame.Angles(0, 0, math.rad(45)), BRASS_LIGHT, METAL)
deco(lid, "CompassLidCatch", Vector3.new(0.06, 0.04, 0.04), COMPASS * CFrame.new(0, 0.52, 0.0), BRASS_LIGHT, METAL)
-- chains: from the compass bow to the right of the belt, and a damaged loop on the right hip
cat = "Belt"
chain(pelvis, "WaistChain", CP(0.25, 0.06, 0.0), PV(0.46, 0.22, -0.38), 0.22, 7, 0.032, BRASS_DARK)
chain(pelvis, "HipChain", PV(0.63, 0.24, -0.18), PV(0.64, 0.26, 0.24), 0.3, 6, 0.032, IRON)

-- ====================================================================
-- The coat tails: ten panels round the hips (open at the front), sea-green inside. The long ones (sides and back) have a
-- second segment on its own joint; the hems are torn into strips, the lining hangs a little longer in green tatters.
-- ====================================================================
cat = "CoatTails"
local TAILS = {
	-- a = degrees from the front towards his right; L2 = the lower segment (none: a single torn panel)
	{ a = 56, L1 = 2.45, w = 0.52, flare = 0.15 },
	{ a = 86, L1 = 1.6, L2 = 1.3, w = 0.62, flare = 0.24 },
	{ a = 116, L1 = 1.7, L2 = 1.45, w = 0.68, flare = 0.3 },
	{ a = 146, L1 = 1.75, L2 = 1.6, w = 0.7, flare = 0.31 },
	{ a = 172, L1 = 1.8, L2 = 1.6, w = 0.64, flare = 0.25 },
}
local LEFT_LEN = { 0.95, 1.05, 0.92, 1.04, 0.98 } -- his left side is torn differently
local function tearHem(to, name, cf, w, L, t, teeth, color, tearFrac)
	local solid = L * (1 - tearFrac)
	deco(to, name, Vector3.new(w, solid + 0.04, t), cf * CFrame.new(0, -solid / 2, 0), color, FABRIC)
	local tw = w / teeth
	for i = 1, teeth do
		local x = -w / 2 + tw * (i - 0.5)
		local len = L * tearFrac * rng:NextNumber(0.4, 1.15)
		local tilt = rng:NextNumber(-0.16, 0.16)
		deco(to, name .. "Tear", Vector3.new(tw * rng:NextNumber(0.62, 0.9), len, t * 0.85),
			cf * CFrame.new(x, -solid + 0.04, 0) * CFrame.Angles(0, 0, tilt) * CFrame.new(0, -len / 2, 0), color, FABRIC)
	end
end
local tailIndex = 0
local hemWeed = {}
for _, side in ipairs({ 1, -1 }) do
	for n, spec in ipairs(TAILS) do
		tailIndex += 1
		local i = tailIndex
		local f = side < 0 and LEFT_LEN[n] or 1
		local deg = side * spec.a + (side < 0 and -3 or 0)
		local a = math.rad(deg)
		local stagger = (n % 2 == 0) and 0.03 or 0
		local top = PV(math.sin(a) * (0.56 + stagger), 0.25, -math.cos(a) * ((spec.a < 90 and 0.36 or 0.43) + stagger))
		local outv = Vector3.new(math.sin(a), 0, -math.cos(a))
		local xv = Vector3.new(-math.cos(a), 0, -math.sin(a))
		local frame = CFrame.fromMatrix(top, xv, Vector3.new(0, 1, 0), outv) * CFrame.Angles(-spec.flare, 0, side * 0.03)
		local outerColor = (n % 2 == 0) and COAT_RAISED or COAT
		local L1 = spec.L1 * (spec.L2 and 1 or f)
		local single = spec.L2 == nil
		-- the upper panel (the carrier)
		local upperLen = single and L1 * 0.68 or L1
		local upperPanel = part("Tail" .. i, Vector3.new(spec.w, upperLen + 0.04, 0.06), frame * CFrame.new(0, -upperLen / 2, 0), outerColor, FABRIC)
		local j = motor("Tail" .. i, pelvis, upperPanel, frame)
		j:SetAttribute("TailIndex", i)
		j:SetAttribute("Segment", 1)
		j:SetAttribute("CoatAngle", deg)
		deco(upperPanel, "TailLining", Vector3.new(spec.w * 0.94, upperLen, 0.035), frame * CFrame.new(0, -upperLen / 2, -0.055), LINING_DARK, FABRIC)
		deco(upperPanel, "TailFold", Vector3.new(0.07, upperLen * 0.75, 0.075), frame * CFrame.new(side * spec.w * 0.2, -upperLen * 0.52, 0.012), (n % 2 == 0) and COAT or COAT_RAISED, FABRIC)
		deco(upperPanel, "TailHole", Vector3.new(0.12, 0.16, 0.065), frame * CFrame.new(rng:NextNumber(-0.15, 0.15), -upperLen * rng:NextNumber(0.45, 0.8), 0.01) * CFrame.Angles(0, 0, rng:NextNumber(-0.5, 0.5)), LINING, FABRIC)
		if single then
			-- the front panels: one torn panel; a brass edge and buttons along the coat's front opening
			local lowerLen = L1 * 0.32 + 0.6
			tearHem(upperPanel, "TailHem", frame * CFrame.new(0, -upperLen, 0), spec.w * 0.98, lowerLen, 0.055, 3, outerColor, 0.75)
			tearHem(upperPanel, "TailLiningHem", frame * CFrame.new(0, -upperLen, -0.05), spec.w * 0.86, lowerLen + 0.18, 0.03, 2, LINING, 0.8)
			local edgeX = -side * spec.w / 2
			deco(upperPanel, "TailFrontEdge", Vector3.new(0.035, upperLen * 0.95, 0.075), frame * CFrame.new(edgeX, -upperLen * 0.5, 0.005), BRASS_DARK, METAL)
			for k = 1, 2 do
				cyl(upperPanel, "TailButton", (frame * CFrame.new(edgeX + side * 0.08, -0.3 - k * 0.42, 0.035)).Position, frame.LookVector, 0.03, 0.07, BRASS, METAL)
			end
		else
			-- the lower panel on its own joint
			local f2 = frame * CFrame.new(0, -L1, 0) * CFrame.Angles(-0.11, 0, side * 0.04)
			local L2 = spec.L2 * f
			local w2 = spec.w * 0.92
			local solid = L2 * 0.6
			local lower = part("Tail" .. i .. "_2", Vector3.new(w2, solid + 0.06, 0.055), f2 * CFrame.new(0, -solid / 2 + 0.03, 0), outerColor, FABRIC)
			local j2 = motor("Tail" .. i .. "_2", upperPanel, lower, f2)
			j2:SetAttribute("TailIndex", i)
			j2:SetAttribute("Segment", 2)
			j2:SetAttribute("CoatAngle", deg)
			local tw = w2 / 3
			for t = 1, 3 do
				local x = -w2 / 2 + tw * (t - 0.5)
				local len = L2 * 0.4 * rng:NextNumber(0.45, 1.15)
				deco(lower, "TailTear", Vector3.new(tw * rng:NextNumber(0.62, 0.9), len, 0.048),
					f2 * CFrame.new(x, -solid + 0.04, 0) * CFrame.Angles(0, 0, rng:NextNumber(-0.16, 0.16)) * CFrame.new(0, -len / 2, 0), outerColor, FABRIC)
			end
			tearHem(lower, "TailLiningHem", f2 * CFrame.new(0, 0, -0.05), w2 * 0.88, L2 + 0.15, 0.03, 2, LINING, 0.4)
			deco(lower, "TailHole", Vector3.new(0.13, 0.14, 0.062), f2 * CFrame.new(rng:NextNumber(-0.14, 0.14), -solid * rng:NextNumber(0.3, 0.7), 0.01) * CFrame.Angles(0, 0, rng:NextNumber(-0.5, 0.5)), LINING, FABRIC)
			if n == 4 then
				table.insert(hemWeed, { lower, f2 * CFrame.new(side * 0.15, -solid * 0.9, 0.04), f2 })
			end
		end
	end
end
-- a little growth on two back hems: a strand of seaweed and a pair of barnacles
cat = "Growth"
for k, h in ipairs(hemWeed) do
	seaweed(h[1], h[2].Position, 3, 0.2, 0.07)
	if k == 1 then
		barnacle(h[1], (h[2] * CFrame.new(-0.12, 0.25, 0)).Position, h[3].LookVector * -1, 0.1)
		barnacle(h[1], (h[2] * CFrame.new(-0.02, 0.38, 0)).Position, h[3].LookVector * -1, 0.07)
	end
end

-- ====================================================================
-- Attributes, validation, install
-- ====================================================================
cat = "Rig"
local partsList, motors, attachments, emitters, lights = {}, {}, {}, 0, 0
local adj = {}
local function link(a, b)
	adj[a] = adj[a] or {}
	adj[b] = adj[b] or {}
	table.insert(adj[a], b)
	table.insert(adj[b], a)
end
local weldCount = {}
local problems = {}
for _, d in ipairs(model:GetDescendants()) do
	if d:IsA("BasePart") then
		table.insert(partsList, d)
		if d.Anchored or d.CanCollide or d.CanTouch or d.CanQuery then
			table.insert(problems, "flags: " .. d.Name)
		end
	elseif d:IsA("Motor6D") then
		table.insert(motors, d)
		link(d.Part0, d.Part1)
	elseif d:IsA("WeldConstraint") then
		link(d.Part0, d.Part1)
		weldCount[d.Part1] = (weldCount[d.Part1] or 0) + 1
	elseif d:IsA("Attachment") then
		table.insert(attachments, d)
	elseif d:IsA("ParticleEmitter") or d:IsA("Beam") or d:IsA("Trail") then
		emitters += 1
	elseif d:IsA("Light") then
		lights += 1
	elseif d:IsA("BaseScript") or d:IsA("Humanoid") then
		table.insert(problems, "forbidden: " .. d.ClassName)
	end
end
for p, c in pairs(weldCount) do
	if c > 1 then
		table.insert(problems, "two welds on " .. p.Name)
	end
end
-- every part reached from the root through welds and motors
local seen, queue = { [root] = true }, { root }
while #queue > 0 do
	local p = table.remove(queue)
	for _, q in ipairs(adj[p] or {}) do
		if not seen[q] then
			seen[q] = true
			table.insert(queue, q)
		end
	end
end
local orphans = 0
for _, p in ipairs(partsList) do
	if not seen[p] then
		orphans += 1
		table.insert(problems, "orphan: " .. p.Name)
	end
end
local names = {}
for _, m in ipairs(motors) do
	if names[m.Name] then
		table.insert(problems, "duplicate joint " .. m.Name)
	end
	names[m.Name] = true
end
local anames = {}
for _, a in ipairs(attachments) do
	if anames[a.Name] then
		table.insert(problems, "duplicate attachment " .. a.Name)
	end
	anames[a.Name] = true
end
-- measured extents
local minV, maxV = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
local cats = {}
for _, p in ipairs(partsList) do
	local c = p:GetAttribute("Cat") or "?"
	cats[c] = (cats[c] or 0) + 1
	local h = p.Size / 2
	for _, sx in ipairs({ -1, 1 }) do
		for _, sy in ipairs({ -1, 1 }) do
			for _, sz in ipairs({ -1, 1 }) do
				local v = (p.CFrame * CFrame.new(h.X * sx, h.Y * sy, h.Z * sz)).Position
				minV = minV:Min(v)
				maxV = maxV:Max(v)
			end
		end
	end
end
local height = maxV.Y - minV.Y
model:SetAttribute("Rig", "Procedural")
model:SetAttribute("RootHeight", math.floor((HIP_Y - minV.Y) * 1000 + 0.5) / 1000)
model:SetAttribute("Height", math.floor(height * 100 + 0.5) / 100)
model:SetAttribute("BuiltBy", BUILT_BY)

local catList = {}
for c, k in pairs(cats) do
	table.insert(catList, c .. " " .. k)
end
table.sort(catList)
local report = ("%s: %d parts, %d motors, %d attachments, %d emitters, %d lights | size %.2f x %.2f x %.2f, floor %.3f, top %.2f | %s")
	:format(NAME, #partsList, #motors, #attachments, emitters, lights, maxV.X - minV.X, height, maxV.Z - minV.Z, minV.Y, maxV.Y, table.concat(catList, ", "))
if orphans > 0 or #problems > 0 then
	model:Destroy()
	return "NOT INSTALLED. " .. report .. " | problems: " .. table.concat(problems, "; ", 1, math.min(#problems, 20))
end

local old = models:FindFirstChild(NAME)
if old then
	if old:GetAttribute("BuiltBy") ~= BUILT_BY and not models:FindFirstChild(NAME .. "_Old") then
		old.Name = NAME .. "_Old" -- (hand-altered: keep it once)
	else
		old:Destroy()
	end
end
model.Parent = models
return report
