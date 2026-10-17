-- Builds Veyr, the Last Sight (Sovereign, see docs/veyr.md) into ServerStorage.Models.Veyr.
-- Run in Edit mode (Studio MCP execute_luau or loadstring from the tools/studio http server), then build_veyr_shadow.lua
-- and publish_unit_models.lua. Safe to re-run: it replaces the model (a hand-altered copy is kept once as Veyr_Old).
--
-- After the concept art (Images/Concept/Unit/Spektraler Scharfschuetze mit arkanem Gewehr.png): a lean hooded skeletal
-- marksman, a deep cowl with two spectral blue eyes and the hint of a skull, black sharp armour with bone-like ribs, a
-- wind-torn mantle and robe in long ragged strips, bare skeletal hands, and the defining silhouette: a long blackened
-- gothic rifle (stock, pistol grip, receiver with fins, scope on two mounts, a layered fore-end with rune channels, a long
-- braced barrel and a pronged muzzle crown) held shouldered and aimed. Dark shards with violet cores float above and
-- behind his shoulders. Built in that firing pose, bladed (the left shoulder towards the target), leaning in.
--
-- Rig conventions (see src/client/Modules/UnitAnimator.lua, Pose "Marksman"):
--   * front = -Z, character's right = +X, root part = HumanoidRootPart at RootHeight; he floats SOLE studs up
--   * Motor6Ds Root/Waist/Neck/LShoulder/RShoulder/LElbow/RElbow/LWrist/RWrist/LHip/RHip/LKnee/RKnee, rest = identity
--   * the rifle hangs on its own joint `Rifle` (Torso -> RifleRoot, at the shoulder pocket); the arms are BUILT gripping
--     it and the animator re-solves them by IK onto the rifle's GripR / GripL attachments, so recoil moves both hands
--   * RifleRoot attachments: Muzzle, RingOrigin (where the focusing sights grow), ScopeEye, ScopeLens, Ejection,
--     Chamber, Butt, GripR, GripL
--   * cloth: Mantle<i>_<k> (a chain of k segments per strip, attribute MantleIndex), Robe<i> (skirt panels on hinges,
--     attribute CoatAngle like Malak's coat), HoodTail; shards: Shard<i> joints from the torso (attribute ShardIndex)
--   * attributes Rig = "Procedural", RootHeight, Height, Float, Pose = "Marksman", AttackStyle = "Marksman"
local ServerStorage = game:GetService("ServerStorage")
local models = ServerStorage.Models

local NAME = "Veyr"
local old = models:FindFirstChild(NAME)
if old then
	if old:GetAttribute("BuiltBy") ~= "build_veyr" and not models:FindFirstChild(NAME .. "_Old") then
		old.Name = NAME .. "_Old" -- (hand-altered: keep it once)
	else
		old:Destroy()
	end
end

local SMOOTH = Enum.Material.SmoothPlastic
local NEON = Enum.Material.Neon
local FABRIC = Enum.Material.Fabric
local METAL = Enum.Material.Metal

local CLOTH = Color3.fromRGB(17, 17, 23)        -- near-black cloth
local CLOTH_LIGHT = Color3.fromRGB(38, 38, 52)  -- the next layer, so the folds read
local CLOTH_RIM = Color3.fromRGB(66, 66, 86)    -- the hood's rim, torn edges, bands
local STEEL = Color3.fromRGB(36, 36, 46)        -- blackened steel
local STEEL_DARK = Color3.fromRGB(22, 22, 29)
local SILVER = Color3.fromRGB(172, 176, 198)    -- cold silver trim
local BONE = Color3.fromRGB(196, 196, 204)      -- skeletal hands
local BONE_DARK = Color3.fromRGB(152, 152, 166)
local VOID = Color3.fromRGB(4, 4, 7)            -- inside the hood
local SKULL = Color3.fromRGB(46, 46, 58)        -- the skull in the dark, barely there
local EYE = Color3.fromRGB(90, 175, 255)        -- spectral blue eyes (his trace of life)
local ENERGY = Color3.fromRGB(118, 86, 255)     -- indigo-violet soul light
local ENERGY_CORE = Color3.fromRGB(205, 196, 255)
local ENERGY_DEEP = Color3.fromRGB(64, 40, 190)
local SHARD = Color3.fromRGB(20, 18, 30)

local SOLE = 0.25 -- he floats this high
local HIP_Y = 3.55
local WAIST_Y = 3.85
local YAW = math.rad(-38) -- the upper body is bladed: left shoulder towards the target
local LEAN = math.rad(-7) -- and leans into the rifle
local rng = Random.new(41)

local model = Instance.new("Model")
model.Name = NAME

-- ====================================================================
-- Helpers
-- ====================================================================
local function finish(p, name, color, material)
	p.Name = name
	p.Color = color
	p.Material = material or SMOOTH
	if material == METAL then
		p.Reflectance = 0.05
	end
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.Anchored = false
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

-- a wedge (slope rises from -Z to +Z... Roblox wedge: the slope faces +Y/-Z), welded to `to`
local function wedge(to, name, size, cf, color, material)
	local p = Instance.new("WedgePart")
	p.Size = size
	p.CFrame = cf
	finish(p, name, color, material)
	weld(to, p)
	return p
end

-- a box between two points (w x h cross-section), welded to `to`; `roll` turns it about its own axis
local function bar(to, name, a, b, w, h, color, material, roll)
	local dir = b - a
	local up = math.abs(dir.Unit.Y) > 0.98 and Vector3.new(0, 0, 1) or Vector3.new(0, 1, 0)
	local cf = CFrame.lookAt((a + b) / 2, b, up) * CFrame.Angles(0, 0, roll or 0)
	return deco(to, name, Vector3.new(w, h or w, dir.Magnitude), cf, color, material)
end

-- a cylinder centred on `c` whose axis runs along `axis`
local function cyl(to, name, c, axis, length, diameter, color, material)
	local cf
	if math.abs(axis.Unit.Y) > 0.98 then
		cf = CFrame.new(c) * CFrame.Angles(0, 0, math.pi / 2)
	else
		cf = CFrame.lookAt(c, c + axis) * CFrame.Angles(0, math.pi / 2, 0)
	end
	return deco(to, name, Vector3.new(length, diameter, diameter), cf, color, material, Enum.PartType.Cylinder)
end

local function glow(to, name, size, at, color, transparency)
	local p = deco(to, name, size, at, color or ENERGY, NEON)
	p.Transparency = transparency or 0
	return p
end

local function light(parentPart, range, brightness, color)
	local l = Instance.new("PointLight")
	l.Color = color or ENERGY
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

-- A ragged cloth panel in the frame `cf`: it hangs from the origin down -Y for length L (width w, thickness t), its
-- lower part torn into `teeth` strips of uneven length that taper and splay a little. The strips are thinner than the
-- panel so no two faces share a plane.
local function rag(to, name, cf, w, L, t, teeth, color, tear)
	tear = tear or 0.38
	local solid = L * (1 - tear)
	deco(to, name, Vector3.new(w, solid, t), cf * CFrame.new(0, -solid / 2, 0), color, FABRIC)
	local tw = w / teeth
	for i = 1, teeth do
		local x = -w / 2 + tw * (i - 0.5)
		local len = L * tear * rng:NextNumber(0.35, 1.15)
		local splay = rng:NextNumber(-0.12, 0.12)
		local c = (i % 2 == 0) and color or CLOTH_LIGHT
		local stripCF = cf * CFrame.new(x, -solid + 0.06, 0) * CFrame.Angles(0, 0, splay)
		deco(to, name .. "Tear", Vector3.new(tw * rng:NextNumber(0.7, 0.95), len, t * 0.8),
			stripCF * CFrame.new(0, -len / 2, 0), c, FABRIC)
		-- a pointed end
		local tipW = tw * 0.5
		deco(to, name .. "TearTip", Vector3.new(tipW, tipW, t * 0.7),
			stripCF * CFrame.new(0, -len, 0) * CFrame.Angles(0, 0, math.rad(45)), c, FABRIC)
	end
end

-- a ring of n box segments round the local Y axis of `frame` (radius r, radial width w, height h), welded to `to`
local function ring(to, name, frame, r, n, w, h, color, material)
	local seg = 2 * math.pi * r / n * 1.04
	for i = 0, n - 1 do
		local a = i / n * 2 * math.pi
		deco(to, name, Vector3.new(seg, h, w), frame * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -r), color, material)
	end
end

-- ====================================================================
-- Frames
-- ====================================================================
local LOWER = CFrame.new(0, HIP_Y, 0) * CFrame.Angles(0, math.rad(-22), 0) -- the hips, bladed a little less
local UPPER = CFrame.new(0, WAIST_Y, 0) * CFrame.Angles(0, YAW, 0) * CFrame.Angles(LEAN, 0, 0) -- the chest frame
local function U(x, y, z) -- a point in the chest frame (y from the waist)
	return UPPER * CFrame.new(x, y, z)
end

local R_SHOULDER = U(0.66, 1.5, 0.02).Position
local L_SHOULDER = U(-0.66, 1.5, 0.02).Position
local NECK = U(0, 1.78, 0.05).Position

-- the rifle: its frame RIFLE sits at the shoulder pocket (the butt), looking straight at the target (-Z)
local BUTT = R_SHOULDER + Vector3.new(-0.2, -0.12, -0.18)
local RIFLE = CFrame.new(BUTT + Vector3.new(0, 0.1, 0)) -- the bore line runs 0.1 above the butt centre
local function RF(x, y, z) -- a point on the rifle (forward = -z)
	return RIFLE * CFrame.new(x, y, z)
end

-- ====================================================================
-- Root, pelvis, legs
-- ====================================================================
local root = part("HumanoidRootPart", Vector3.new(1.2, 0.4, 0.8), Vector3.new(0, HIP_Y, 0), CLOTH)
root.Transparency = 1
model.PrimaryPart = root

local pelvis = part("Pelvis", Vector3.new(0.9, 0.5, 0.58), LOWER, STEEL_DARK)
motor("Root", root, pelvis, Vector3.new(0, HIP_Y, 0))
deco(pelvis, "Belt", Vector3.new(1.06, 0.16, 0.7), LOWER * CFrame.new(0, 0.24, 0), STEEL)
deco(pelvis, "BeltTrim", Vector3.new(1.08, 0.03, 0.72), LOWER * CFrame.new(0, 0.33, 0), SILVER, METAL)
deco(pelvis, "Buckle", Vector3.new(0.22, 0.2, 0.05), LOWER * CFrame.new(0, 0.24, -0.37) * CFrame.Angles(0, 0, math.rad(45)), SILVER, METAL)
glow(pelvis, "BuckleCore", Vector3.new(0.07, 0.07, 0.04), LOWER * CFrame.new(0, 0.24, -0.4) * CFrame.Angles(0, 0, math.rad(45)))
-- a pouch and a row of spare rounds on the right hip
deco(pelvis, "Pouch", Vector3.new(0.22, 0.3, 0.26), LOWER * CFrame.new(0.56, 0.08, -0.05), CLOTH_LIGHT, FABRIC)
for i = 0, 3 do
	local c = LOWER * CFrame.new(0.38 - i * 0.13, 0.24, 0.37)
	deco(pelvis, "BeltRound", Vector3.new(0.07, 0.2, 0.07), c, STEEL_DARK, METAL)
	glow(pelvis, "BeltRoundTip", Vector3.new(0.05, 0.06, 0.05), c * CFrame.new(0, 0.13, 0))
end

-- tassets: two layered plates hanging over each hip at the front
for _, sx in ipairs({ -1, 1 }) do
	local T = LOWER * CFrame.new(sx * 0.4, 0.12, -0.22) * CFrame.Angles(math.rad(-10), sx * math.rad(-28), sx * math.rad(8))
	deco(pelvis, "Tasset", Vector3.new(0.36, 0.46, 0.06), T * CFrame.new(0, -0.2, 0), STEEL, METAL)
	deco(pelvis, "TassetLow", Vector3.new(0.32, 0.26, 0.07), T * CFrame.new(0, -0.48, -0.015) * CFrame.Angles(math.rad(-6), 0, 0), STEEL_DARK, METAL)
	deco(pelvis, "TassetEdge", Vector3.new(0.34, 0.03, 0.085), T * CFrame.new(0, -0.62, -0.02) * CFrame.Angles(math.rad(-6), 0, 0), SILVER, METAL)
	deco(pelvis, "TassetEdge", Vector3.new(0.38, 0.03, 0.075), T * CFrame.new(0, -0.42, 0), SILVER, METAL)
	deco(pelvis, "TassetRivet", Vector3.new(0.05, 0.05, 0.08), T * CFrame.new(0, -0.08, 0), SILVER, METAL)
	glow(pelvis, "TassetRune", Vector3.new(0.025, 0.18, 0.075), T * CFrame.new(0, -0.24, 0), ENERGY, 0.25)
end
-- a chain on the left hip with a small skull token; a second pouch behind it
do
	local prev = (LOWER * CFrame.new(-0.52, 0.18, -0.18)).Position
	for k = 1, 4 do
		local nxt = (LOWER * CFrame.new(-0.56 - (k % 2) * 0.04, 0.18 - k * 0.11, -0.2)).Position
		bar(pelvis, "ChainLink", prev, nxt, 0.035, 0.07, SILVER, METAL, k % 2 == 0 and math.rad(90) or 0)
		prev = nxt
	end
	local tok = LOWER * CFrame.new(-0.56, -0.38, -0.2) * CFrame.Angles(0, math.rad(20), 0)
	deco(pelvis, "Token", Vector3.new(0.15, 0.15, 0.11), tok, BONE_DARK)
	deco(pelvis, "TokenJaw", Vector3.new(0.1, 0.06, 0.09), tok * CFrame.new(0, -0.09, -0.01), BONE_DARK)
	for _, e in ipairs({ -1, 1 }) do
		glow(pelvis, "TokenEye", Vector3.new(0.035, 0.035, 0.03), tok * CFrame.new(e * 0.035, 0.015, -0.05), EYE)
	end
	deco(pelvis, "PouchL", Vector3.new(0.2, 0.26, 0.22), LOWER * CFrame.new(-0.5, 0.08, 0.22), CLOTH_LIGHT, FABRIC)
	deco(pelvis, "PouchFlap", Vector3.new(0.22, 0.1, 0.24), LOWER * CFrame.new(-0.5, 0.2, 0.22), CLOTH_RIM, FABRIC)
	deco(pelvis, "PouchFlap", Vector3.new(0.24, 0.1, 0.28), LOWER * CFrame.new(0.56, 0.2, -0.05), CLOTH_RIM, FABRIC)
	-- a long rune knife across the small of the back
	local k0, k1, k2 = LOWER * CFrame.new(-0.36, 0.12, 0.42), LOWER * CFrame.new(0.3, 0.2, 0.42), LOWER * CFrame.new(0.56, 0.24, 0.42)
	bar(pelvis, "KnifeSheath", k0.Position, k1.Position, 0.1, 0.07, STEEL_DARK, METAL)
	bar(pelvis, "KnifeSheathTip", k0.Position, k0.Position + (k0.Position - k1.Position).Unit * 0.12, 0.05, 0.05, SILVER, METAL)
	bar(pelvis, "KnifeGuard", (k1 * CFrame.new(0, 0.1, 0)).Position, (k1 * CFrame.new(0, -0.1, 0)).Position, 0.05, 0.05, SILVER, METAL)
	bar(pelvis, "KnifeHandle", k1.Position, k2.Position, 0.06, 0.06, BONE_DARK)
	deco(pelvis, "KnifePommel", Vector3.new(0.08, 0.08, 0.08), k2 * CFrame.Angles(0, 0, math.rad(45)), SILVER, METAL)
end

local function leg(side, x, foot, pole)
	local hip = (LOWER * CFrame.new(x, -0.1, 0)).Position
	local ankle = Vector3.new(foot.X, SOLE + 0.32, foot.Z)
	local knee = solveJoint(hip, ankle, 1.6, 1.62, pole)
	local thigh = part(side .. "Thigh", Vector3.new(0.34, 0.34, 0.34), CFrame.lookAt((hip + knee) / 2, knee), STEEL_DARK)
	thigh.Transparency = 1
	motor(side .. "Hip", pelvis, thigh, hip)
	bar(thigh, "ThighWrap", hip, knee, 0.36, 0.36, CLOTH_LIGHT, FABRIC)
	bar(thigh, "ThighPlate", hip:Lerp(knee, 0.15), hip:Lerp(knee, 0.85), 0.24, 0.42, STEEL, METAL)
	local shin = part(side .. "Shin", Vector3.new(0.3, 0.3, 0.3), CFrame.lookAt((knee + ankle) / 2, ankle), STEEL_DARK)
	shin.Transparency = 1
	motor(side .. "Knee", thigh, shin, knee)
	-- a sharp knee cop and a long pointed greave
	local fwd = (LOWER.LookVector * Vector3.new(1, 0, 1)).Unit
	deco(shin, "KneeCop", Vector3.new(0.34, 0.34, 0.34), CFrame.lookAt(knee + fwd * 0.12, knee + fwd) * CFrame.Angles(0, 0, math.rad(45)), STEEL, METAL)
	bar(shin, "KneeSpike", knee + fwd * 0.18, knee + fwd * 0.45 + Vector3.new(0, 0.22, 0), 0.08, 0.08, SILVER, METAL)
	bar(shin, "Greave", knee:Lerp(ankle, 0.08), ankle, 0.3, 0.32, STEEL, METAL)
	bar(shin, "GreaveRidge", knee:Lerp(ankle, 0.15) + fwd * 0.15, ankle + fwd * 0.12, 0.06, 0.06, SILVER, METAL)
	-- a pointed sabaton, toes tilted down (he floats)
	local toe = ankle + fwd * 0.62 + Vector3.new(0, -0.3, 0)
	bar(shin, "Sabaton", ankle + Vector3.new(0, -0.12, 0) - fwd * 0.12, toe, 0.26, 0.2, STEEL_DARK, METAL)
	bar(shin, "SabatonPlate", ankle + Vector3.new(0, -0.02, 0), toe + Vector3.new(0, 0.07, 0), 0.18, 0.08, STEEL, METAL)
	for k = 1, 3 do -- lames across the foot
		local p = ankle:Lerp(toe, k * 0.22) + Vector3.new(0, 0.1 - k * 0.02, 0)
		bar(shin, "SabatonLame", p - fwd * 0.04, p + fwd * 0.04, 0.24 - k * 0.03, 0.05, SILVER, METAL)
	end
	-- the thigh plate's silver edge, two bands round the greave, a glowing gem in the knee
	bar(thigh, "ThighEdge", hip:Lerp(knee, 0.2) + fwd * 0.215, hip:Lerp(knee, 0.85) + fwd * 0.215, 0.05, 0.04, SILVER, METAL)
	for _, f in ipairs({ 0.3, 0.62 }) do
		bar(shin, "GreaveBand", knee:Lerp(ankle, f - 0.03), knee:Lerp(ankle, f + 0.03), 0.34, 0.36, STEEL_DARK, METAL)
	end
	glow(shin, "KneeGem", Vector3.new(0.07, 0.07, 0.07), CFrame.lookAt(knee + fwd * 0.3, knee + fwd * 2) * CFrame.Angles(0, 0, math.rad(45)), ENERGY)
end
leg("L", -0.3, (LOWER * CFrame.new(-0.42, 0, -0.62)).Position, (LOWER.LookVector + Vector3.new(0, 0.2, 0)))
leg("R", 0.3, (LOWER * CFrame.new(0.46, 0, 0.66)).Position, (LOWER.LookVector + Vector3.new(0, -0.1, 0)))

-- ====================================================================
-- The robe: long ragged panels round the hips on their own hinges (CoatAngle like Malak's coat; open at the front)
-- ====================================================================
local function robeHinge(jointName, top, out, deg)
	local hingeCF = CFrame.lookAt(top, top - out)
	local hinge = part(jointName .. "Hinge", Vector3.new(0.1, 0.1, 0.1), hingeCF, CLOTH)
	hinge.Transparency = 1
	local m = Instance.new("Motor6D")
	m.Name = jointName
	m.Part0 = pelvis
	m.Part1 = hinge
	m.C0 = pelvis.CFrame:Inverse() * hingeCF
	m.C1 = CFrame.new()
	m:SetAttribute("CoatAngle", deg)
	m.Parent = hinge
	return hinge, hingeCF
end
local ROBE = {
	{ a = 52, w = 0.62, L = 2.7, flare = 0.18 },
	{ a = 92, w = 0.7, L = 3.1, flare = 0.24 },
	{ a = 132, w = 0.74, L = 3.35, flare = 0.3 },
	{ a = 168, w = 0.76, L = 3.5, flare = 0.34 },
}
local function robePanel(i, deg, s, n)
	local a = math.rad(deg)
	local local_ = Vector3.new(math.sin(a) * 0.55, 0.22, -math.cos(a) * 0.4)
	local top = (LOWER * CFrame.new(local_)).Position
	local out = LOWER:VectorToWorldSpace(Vector3.new(math.sin(a), 0, -math.cos(a)))
	local hinge, hingeCF = robeHinge("Robe" .. i, top, out, deg)
	local cf = hingeCF * CFrame.Angles(-s.flare, 0, 0)
	rag(hinge, "RobePanel", cf, s.w, s.L, 0.06, 3, n % 2 == 0 and CLOTH or CLOTH_LIGHT, 0.45)
	deco(hinge, "RobeBand", Vector3.new(s.w * 0.98, 0.08, 0.075), cf * CFrame.new(0, -0.16, 0), CLOTH_RIM, FABRIC)
	deco(hinge, "RobeStud", Vector3.new(0.06, 0.06, 0.09), cf * CFrame.new(0, -0.16, 0) * CFrame.Angles(0, 0, math.rad(45)), SILVER, METAL)
	deco(hinge, "RobeCrease", Vector3.new(0.05, s.L * 0.4, 0.075), cf * CFrame.new(s.w * 0.22, -s.L * 0.36, 0), n % 2 == 0 and CLOTH_LIGHT or CLOTH, FABRIC)
end
for i, s in ipairs(ROBE) do
	robePanel("R" .. i, s.a, s, i)
	robePanel("L" .. i, -s.a - 4, s, i + 1)
end

-- ====================================================================
-- Torso: black sharp armour, a bone-ribbed chest, a bandolier of spectral rounds, the gorget
-- ====================================================================
local torso = part("Torso", Vector3.new(1.1, 1.55, 0.62), U(0, 0.82, 0), STEEL_DARK)
motor("Waist", pelvis, torso, Vector3.new(0, WAIST_Y, 0))
deco(torso, "Abdomen", Vector3.new(0.86, 0.5, 0.56), U(0, 0.22, -0.02), CLOTH_LIGHT, FABRIC)
-- the chest plate: a keel with layered angled plates either side
deco(torso, "Chest", Vector3.new(1.06, 0.9, 0.2), U(0, 1.1, -0.3) * CFrame.Angles(math.rad(6), 0, 0), STEEL, METAL)
for _, s in ipairs({ -1, 1 }) do
	deco(torso, "ChestWing", Vector3.new(0.5, 0.7, 0.12), U(s * 0.36, 1.12, -0.42) * CFrame.Angles(math.rad(6), s * math.rad(-22), 0), STEEL_DARK, METAL)
	-- ribs: four bone-coloured bars curving down and out, the skeleton showing through the armour
	for k = 0, 3 do
		local y = 1.32 - k * 0.17
		bar(torso, "Rib", U(s * 0.06, y, -0.47).Position, U(s * (0.42 - k * 0.03), y - 0.1, -0.44).Position, 0.06, 0.05, BONE_DARK)
	end
end
deco(torso, "Sternum", Vector3.new(0.1, 0.66, 0.06), U(0, 1.12, -0.47), BONE_DARK)
glow(torso, "SoulCore", Vector3.new(0.09, 0.09, 0.03), U(0, 0.88, -0.505) * CFrame.Angles(0, 0, math.rad(45)))
deco(torso, "Back", Vector3.new(1.0, 1.1, 0.16), U(0, 1.0, 0.32), STEEL_DARK, METAL)
-- the spine: vertebrae down the back plate
for k = 0, 4 do
	deco(torso, "Vertebra", Vector3.new(0.12, 0.1, 0.1), U(0, 1.4 - k * 0.2, 0.43), BONE_DARK)
end
-- the bandolier from the left shoulder to the right hip, with glowing rounds
do
	local a, b = U(-0.48, 1.5, -0.36).Position, U(0.46, 0.12, -0.36).Position
	bar(torso, "Bandolier", a, b, 0.16, 0.05, CLOTH_RIM, FABRIC)
	for k = 1, 5 do
		local p = a:Lerp(b, 0.12 + k * 0.14) + UPPER.LookVector * 0.05
		local c = CFrame.lookAt(p, p + (b - a).Unit) * CFrame.Angles(math.rad(90), 0, 0)
		deco(torso, "Round", Vector3.new(0.06, 0.16, 0.06), c, SILVER, METAL)
		glow(torso, "RoundTip", Vector3.new(0.045, 0.06, 0.045), c * CFrame.new(0, 0.1, 0))
	end
end
-- the gorget: a high plated collar under the hood
deco(torso, "Gorget", Vector3.new(0.7, 0.24, 0.56), U(0, 1.66, 0.02), STEEL, METAL)
deco(torso, "GorgetTrim", Vector3.new(0.72, 0.03, 0.58), U(0, 1.79, 0.02), SILVER, METAL)
deco(torso, "GorgetLow", Vector3.new(0.84, 0.12, 0.66), U(0, 1.57, 0.02), STEEL_DARK, METAL)
deco(torso, "GorgetLowTrim", Vector3.new(0.86, 0.025, 0.68), U(0, 1.51, 0.02), SILVER, METAL)
deco(torso, "GorgetPlate", Vector3.new(0.2, 0.2, 0.05), U(0, 1.66, -0.3) * CFrame.Angles(0, 0, math.rad(45)), STEEL, METAL)
glow(torso, "GorgetGem", Vector3.new(0.07, 0.07, 0.04), U(0, 1.66, -0.33) * CFrame.Angles(0, 0, math.rad(45)), ENERGY)
-- the abdomen: three overlapping lames with silver edges
for k = 0, 2 do
	local c = U(0, 0.52 - k * 0.15, -0.33) * CFrame.Angles(math.rad(-8), 0, 0)
	deco(torso, "Lame", Vector3.new(0.84 - k * 0.06, 0.13, 0.08), c, STEEL, METAL)
	deco(torso, "LameEdge", Vector3.new(0.86 - k * 0.06, 0.025, 0.09), c * CFrame.new(0, -0.065, 0), SILVER, METAL)
end
-- silver edges on the chest wings, a soul seam down each side of the keel
for _, sx in ipairs({ -1, 1 }) do
	local wing = U(sx * 0.36, 1.12, -0.42) * CFrame.Angles(math.rad(6), sx * math.rad(-22), 0)
	deco(torso, "ChestWingEdge", Vector3.new(0.035, 0.72, 0.14), wing * CFrame.new(sx * 0.25, 0, 0), SILVER, METAL)
	deco(torso, "ChestWingEdge", Vector3.new(0.52, 0.035, 0.14), wing * CFrame.new(0, -0.35, 0), SILVER, METAL)
	glow(torso, "ChestSeam", Vector3.new(0.025, 0.66, 0.025), U(sx * 0.53, 1.1, -0.4) * CFrame.Angles(math.rad(6), 0, 0), ENERGY, 0.2)
	-- shoulder blades on the back, bone through the armour
	deco(torso, "Scapula", Vector3.new(0.3, 0.42, 0.05), U(sx * 0.26, 1.22, 0.41) * CFrame.Angles(0, 0, sx * math.rad(14)), BONE_DARK)
	deco(torso, "ScapulaRidge", Vector3.new(0.3, 0.04, 0.07), U(sx * 0.26, 1.32, 0.42) * CFrame.Angles(0, 0, sx * math.rad(-10)), BONE)
	-- the mantle's brooches on both shoulders
	local br = U(sx * 0.5, 1.74, 0.3)
	cyl(torso, "Brooch", br.Position, UPPER.UpVector, 0.05, 0.22, SILVER, METAL)
	cyl(torso, "BroochInset", br.Position + UPPER.UpVector * 0.02, UPPER.UpVector, 0.04, 0.15, STEEL_DARK, METAL)
	glow(torso, "BroochGem", Vector3.new(0.07, 0.07, 0.07), br * CFrame.new(0, 0.05, 0) * CFrame.Angles(0, math.rad(45), 0), ENERGY)
end
-- the bandolier's buckle
do
	local a, b = U(-0.48, 1.5, -0.36).Position, U(0.46, 0.12, -0.36).Position
	deco(torso, "BandolierBuckle", Vector3.new(0.2, 0.08, 0.14), CFrame.lookAt(a:Lerp(b, 0.1), b), SILVER, METAL)
end

-- ====================================================================
-- Shoulders: an asymmetric pair. The LEFT (towards the target) carries a big layered spiked pauldron; the RIGHT (the
-- stock side) only a low plate under the mantle, so the rifle sits clean in the pocket.
-- ====================================================================
do
	local base = U(-0.74, 1.56, 0.0)
	for k = 0, 2 do
		local c = base * CFrame.new(-k * 0.06, -k * 0.16, 0) * CFrame.Angles(0, 0, math.rad(20 + k * 10))
		deco(torso, "LPauldron", Vector3.new(0.66 - k * 0.06, 0.12, 0.78 - k * 0.08), c, k == 1 and STEEL_DARK or STEEL, METAL)
		deco(torso, "LPauldronEdge", Vector3.new(0.68 - k * 0.06, 0.04, 0.035), c * CFrame.new(0, -0.02, -(0.39 - k * 0.04)), SILVER, METAL)
	end
	-- three swept spikes rising back from the pauldron
	for k = 0, 2 do
		local from = (base * CFrame.new(-0.05 - k * 0.08, 0.08, 0.2 - k * 0.22)).Position
		local to = from + UPPER:VectorToWorldSpace(Vector3.new(-0.34, 0.34 - k * 0.07, 0.3))
		bar(torso, "LPauldronSpike", from, to, 0.1 - k * 0.015, 0.06, STEEL, METAL)
		bar(torso, "LPauldronSpikeTip", to, to + (to - from).Unit * 0.22, 0.05, 0.035, SILVER, METAL)
	end
	glow(torso, "LPauldronRune", Vector3.new(0.12, 0.03, 0.12), base * CFrame.new(0, 0.07, 0) * CFrame.Angles(0, math.rad(45), 0))
	for k = 0, 2 do
		local c = base * CFrame.new(-k * 0.06, -k * 0.16, 0) * CFrame.Angles(0, 0, math.rad(20 + k * 10))
		for r = -1, 1 do
			deco(torso, "LPauldronRivet", Vector3.new(0.045, 0.03, 0.045), c * CFrame.new(r * 0.2, 0.07, -(0.39 - k * 0.04) + 0.07), SILVER, METAL)
		end
		glow(torso, "LPauldronLine", Vector3.new(0.5 - k * 0.06, 0.02, 0.02), c * CFrame.new(0, 0.065, 0.12), ENERGY, 0.35)
	end
	-- mail hanging under the pauldron
	deco(torso, "LPauldronMail", Vector3.new(0.3, 0.32, 0.56), base * CFrame.new(0.02, -0.42, 0) * CFrame.Angles(0, 0, math.rad(18)), STEEL_DARK, Enum.Material.DiamondPlate)
	local rbase = U(0.72, 1.52, 0.04)
	deco(torso, "RPauldron", Vector3.new(0.48, 0.1, 0.6), rbase * CFrame.Angles(0, 0, math.rad(-24)), STEEL, METAL)
	deco(torso, "RPauldronEdge", Vector3.new(0.5, 0.035, 0.035), rbase * CFrame.Angles(0, 0, math.rad(-24)) * CFrame.new(0, -0.02, -0.3), SILVER, METAL)
	for k = 1, 2 do
		local c = rbase * CFrame.new(k * 0.05, -k * 0.13, 0) * CFrame.Angles(0, 0, math.rad(-24 - k * 10))
		deco(torso, "RPauldron", Vector3.new(0.44 - k * 0.05, 0.09, 0.56 - k * 0.06), c, k == 1 and STEEL_DARK or STEEL, METAL)
		deco(torso, "RPauldronEdge", Vector3.new(0.46 - k * 0.05, 0.03, 0.035), c * CFrame.new(0, -0.02, -(0.28 - k * 0.03)), SILVER, METAL)
	end
	deco(torso, "RPauldronRivet", Vector3.new(0.05, 0.03, 0.05), rbase * CFrame.Angles(0, 0, math.rad(-24)) * CFrame.new(0, 0.06, -0.18), SILVER, METAL)
end

-- ====================================================================
-- Head: a deep hood (wedges and plates round a void), the hint of an angular skull, two spectral blue eyes. The head
-- turns back from the bladed chest to look down the rifle and dips to the scope.
-- ====================================================================
local HEAD = CFrame.new(NECK + Vector3.new(0.16, 0.5, -0.12)) * CFrame.Angles(0, math.rad(6), 0) * CFrame.Angles(math.rad(-12), 0, math.rad(-8))
local function H(x, y, z)
	return HEAD * CFrame.new(x, y, z)
end
local head = part("Head", Vector3.new(0.5, 0.56, 0.52), H(0, 0, 0.05), VOID)
motor("Neck", torso, head, NECK)
-- the void behind the face, then the skull: brow ridge, cheekbones, a narrow jaw, all dark
deco(head, "HoodVoid", Vector3.new(0.62, 0.74, 0.08), H(0, 0.04, 0.22), VOID)
deco(head, "SkullBrow", Vector3.new(0.44, 0.08, 0.14), H(0, 0.12, -0.2) * CFrame.Angles(math.rad(-10), 0, 0), SKULL)
for _, s in ipairs({ -1, 1 }) do
	deco(head, "Cheek", Vector3.new(0.1, 0.16, 0.12), H(s * 0.17, -0.05, -0.19) * CFrame.Angles(0, s * math.rad(20), 0), SKULL)
	-- the eyes: a hot blue slit inside a dark socket, angled down at the outer corner
	deco(head, "Socket", Vector3.new(0.15, 0.09, 0.04), H(s * 0.105, 0.045, -0.235) * CFrame.Angles(0, 0, s * math.rad(-12)), VOID)
	glow(head, "Eye", Vector3.new(0.09, 0.04, 0.04), H(s * 0.105, 0.045, -0.255) * CFrame.Angles(0, 0, s * math.rad(-12)), EYE)
end
deco(head, "Jaw", Vector3.new(0.26, 0.14, 0.14), H(0, -0.22, -0.16) * CFrame.Angles(math.rad(12), 0, 0), SKULL)
for k = -2, 2 do
	deco(head, "Tooth", Vector3.new(0.03, 0.05, 0.02), H(k * 0.04, -0.15, -0.235), BONE_DARK)
end
local eyeLight = Instance.new("Attachment")
eyeLight.Name = "EyeLight"
eyeLight.CFrame = head.CFrame:ToObjectSpace(H(0, 0.04, -0.3))
eyeLight.Parent = head
local el = Instance.new("PointLight")
el.Color = EYE
el.Range = 2.6
el.Brightness = 1.4
el.Shadows = false
el.Parent = eyeLight
-- the hood: a pointed gothic cowl built from layered cloth. Each side steps inward in three folds towards the face
-- (outer, middle, inner), creases run down the outside, two upper panels round the crown into a pointed arch, the back
-- closes in a point. The opening has a rim with silver stitches and a gothic point at the brow, the throat a clasp; the
-- face sits deep in shadow behind a dark circlet.
local HOOD_LEAN = math.rad(21)
for _, s in ipairs({ -1, 1 }) do
	local side = H(s * 0.29, 0.08, -0.02) * CFrame.Angles(0, 0, s * HOOD_LEAN)
	-- the outer layer, its upper back corner bevelled off so the hood is rounded in profile, the lower back too
	deco(head, "HoodSide", Vector3.new(0.12, 1.1, 0.62), side * CFrame.new(0, 0, -0.19), CLOTH, FABRIC)
	deco(head, "HoodSideBack", Vector3.new(0.115, 0.62, 0.5), side * CFrame.new(0, -0.08, 0.22), CLOTH, FABRIC)
	deco(head, "HoodSideBevel", Vector3.new(0.11, 0.5, 0.5), side * CFrame.new(0, 0.26, 0.12) * CFrame.Angles(math.rad(45), 0, 0), CLOTH, FABRIC)
	-- creases down the outside
	bar(head, "HoodCrease", (side * CFrame.new(s * 0.065, 0.42, -0.32)).Position, (side * CFrame.new(s * 0.065, -0.42, 0.0)).Position, 0.04, 0.05, CLOTH_LIGHT, FABRIC)
	bar(head, "HoodCrease", (side * CFrame.new(s * 0.062, 0.2, 0.08)).Position, (side * CFrame.new(s * 0.062, -0.45, 0.32)).Position, 0.035, 0.045, CLOTH_LIGHT, FABRIC)
	-- the middle and inner folds, each stepping back from the rim towards the face
	local mid = H(s * 0.235, 0.05, -0.02) * CFrame.Angles(0, 0, s * math.rad(25))
	deco(head, "HoodFoldMid", Vector3.new(0.08, 1.0, 0.26), mid * CFrame.new(0, 0, -0.31), CLOTH_LIGHT, FABRIC)
	local inner = H(s * 0.19, 0.02, -0.02) * CFrame.Angles(0, 0, s * math.rad(28))
	deco(head, "HoodFoldInner", Vector3.new(0.07, 0.9, 0.2), inner * CFrame.new(0, 0, -0.28), CLOTH, FABRIC)
	-- the rim in three pieces following the curve of the opening, with silver stitches
	for _, r in ipairs({ { 0.38, -10 }, { 0, 0 }, { -0.38, 10 } }) do
		local z = -0.5 - math.abs(r[1]) * 0.05
		deco(head, "HoodRim", Vector3.new(0.16, 0.4, 0.08), side * CFrame.new(-s * 0.02, r[1], z) * CFrame.Angles(math.rad(r[2]), 0, 0), CLOTH_RIM, FABRIC)
		deco(head, "HoodStitch", Vector3.new(0.035, 0.035, 0.03), side * CFrame.new(-s * 0.02, r[1] + 0.1, z - 0.055), SILVER, METAL)
		deco(head, "HoodStitch", Vector3.new(0.035, 0.035, 0.03), side * CFrame.new(-s * 0.02, r[1] - 0.1, z - 0.055), SILVER, METAL)
	end
	glow(head, "HoodThread", Vector3.new(0.015, 0.8, 0.015), side * CFrame.new(-s * 0.1, -0.02, -0.545), ENERGY_DEEP, 0.45)
	-- the upper crown panel: rounds the A into a pointed arch
	deco(head, "HoodCrown", Vector3.new(0.1, 0.34, 0.72), H(s * 0.13, 0.52, -0.16) * CFrame.Angles(0, 0, s * math.rad(55)), CLOTH, FABRIC)
	-- the hood's lower edges fall onto the shoulders, torn at the hem
	local drape = H(s * 0.44, -0.58, 0.06) * CFrame.Angles(0, 0, s * math.rad(-12))
	deco(head, "HoodDrape", Vector3.new(0.14, 0.5, 0.7), drape, CLOTH_LIGHT, FABRIC)
	rag(head, "HoodDrapeHem", drape * CFrame.new(0, -0.22, 0) * CFrame.Angles(0, math.rad(90), 0), 0.66, 0.36, 0.06, 3, CLOTH, 0.85)
end
deco(head, "HoodRidge", Vector3.new(0.24, 0.12, 0.7), H(0, 0.61, -0.17), CLOTH, FABRIC)
deco(head, "HoodRidgeBevel", Vector3.new(0.23, 0.12, 0.5), H(0, 0.5, 0.3) * CFrame.Angles(math.rad(-40), 0, 0), CLOTH, FABRIC)
deco(head, "HoodRidgeRim", Vector3.new(0.26, 0.14, 0.08), H(0, 0.61, -0.52), CLOTH_RIM, FABRIC)
deco(head, "HoodPoint", Vector3.new(0.15, 0.15, 0.085), H(0, 0.69, -0.53) * CFrame.Angles(0, 0, math.rad(45)), CLOTH_RIM, FABRIC)
deco(head, "HoodPointStud", Vector3.new(0.05, 0.05, 0.03), H(0, 0.62, -0.58) * CFrame.Angles(0, 0, math.rad(45)), SILVER, METAL)
deco(head, "HoodBack", Vector3.new(0.72, 0.62, 0.12), H(0, -0.12, 0.46), CLOTH, FABRIC)
deco(head, "HoodBackSeam", Vector3.new(0.05, 0.6, 0.13), H(0, -0.1, 0.465), CLOTH_LIGHT, FABRIC)
deco(head, "HoodInner", Vector3.new(0.5, 0.86, 0.1), H(0, 0.08, 0.36), CLOTH, FABRIC) -- (closes the gap the eyes shone through)
deco(head, "HoodBackPoint", Vector3.new(0.42, 0.42, 0.11), H(0, 0.2, 0.44) * CFrame.Angles(math.rad(-30), 0, math.rad(45)), CLOTH, FABRIC)
-- the circlet in the dark over the brow, a silver point and a faint gem
deco(head, "Circlet", Vector3.new(0.46, 0.05, 0.05), H(0, 0.22, -0.2), STEEL, METAL)
deco(head, "CircletPoint", Vector3.new(0.07, 0.07, 0.04), H(0, 0.27, -0.225) * CFrame.Angles(0, 0, math.rad(45)), SILVER, METAL)
glow(head, "CircletGem", Vector3.new(0.035, 0.035, 0.03), H(0, 0.27, -0.25) * CFrame.Angles(0, 0, math.rad(45)), ENERGY)
-- the throat clasp holding the hood's edges together under the jaw
for _, s in ipairs({ -1, 1 }) do
	deco(head, "ClaspPlate", Vector3.new(0.1, 0.13, 0.04), H(s * 0.14, -0.52, -0.42) * CFrame.Angles(0, 0, s * math.rad(15)), SILVER, METAL)
end
bar(head, "ClaspChain", H(-0.12, -0.56, -0.44).Position, H(0.12, -0.56, -0.44).Position, 0.025, 0.025, SILVER, METAL)
glow(head, "ClaspGem", Vector3.new(0.07, 0.07, 0.04), H(0, -0.56, -0.46) * CFrame.Angles(0, 0, math.rad(45)), ENERGY)
-- the peak: a point falling back on its own joint (HoodTail), so it trails behind turns; its end is torn
do
	local tailRoot = H(0, 0.5, 0.42)
	local tail = part("HoodTailRoot", Vector3.new(0.1, 0.1, 0.1), tailRoot, CLOTH)
	tail.Transparency = 1
	motor("HoodTail", head, tail, tailRoot)
	bar(tail, "HoodPeak", H(0, 0.52, 0.36).Position, H(0, 0.28, 0.92).Position, 0.22, 0.12, CLOTH, FABRIC)
	bar(tail, "HoodPeakTip", H(0, 0.36, 0.86).Position, H(0, 0.08, 1.2).Position, 0.12, 0.08, CLOTH_LIGHT, FABRIC)
	bar(tail, "HoodPeakTear", H(0.04, 0.14, 1.14).Position, H(0.08, -0.22, 1.28).Position, 0.06, 0.03, CLOTH, FABRIC)
	bar(tail, "HoodPeakTear", H(-0.04, 0.2, 1.06).Position, H(-0.09, -0.08, 1.18).Position, 0.05, 0.03, CLOTH_LIGHT, FABRIC)
end
-- a short torn capelet round the neck over both shoulders
do
	for k = 0, 6 do
		local a = math.rad(-150 + k * 50)
		local top = U(math.sin(a) * 0.62, 1.82, math.cos(a) * 0.4)
		local cf = CFrame.lookAt(top.Position, top.Position + UPPER:VectorToWorldSpace(Vector3.new(math.sin(a), 0, math.cos(a)))) * CFrame.Angles(math.rad(-30), math.pi, 0)
		rag(torso, "Capelet", cf, 0.42, 0.75, 0.05, 2, k % 2 == 0 and CLOTH or CLOTH_LIGHT, 0.5)
	end
end

-- ====================================================================
-- The rifle (on its own joint): butt and stock, pistol grip and trigger, a finned gothic receiver, a long scope on two
-- mounts, a layered fore-end with rune channels, a long braced barrel housing, and a pronged muzzle crown.
-- ====================================================================
local rifleRoot = part("RifleRoot", Vector3.new(0.2, 0.2, 0.2), RIFLE, STEEL_DARK)
rifleRoot.Transparency = 1
motor("Rifle", torso, rifleRoot, RIFLE)
local function R(name, size, x, y, z, color, material, rx, ry, rz)
	return deco(rifleRoot, name, size, RF(x, y, z) * CFrame.Angles(rx or 0, ry or 0, rz or 0), color, material)
end
local function RG(name, size, x, y, z, color, t, rx, ry, rz)
	local p = R(name, size, x, y, z, color or ENERGY, NEON, rx, ry, rz)
	p.Transparency = t or 0
	return p
end
local function RW(name, size, x, y, z, color, rx, ry, rz) -- a wedge on the rifle
	return wedge(rifleRoot, name, size, RF(x, y, z) * CFrame.Angles(rx or 0, ry or 0, rz or 0), color, METAL)
end

-- stock: butt plate, a hollow skeletal stock (two bars and a cheek rest), the wrist
R("ButtPlate", Vector3.new(0.2, 0.62, 0.08), 0, -0.2, 0.08, STEEL, METAL)
R("ButtPad", Vector3.new(0.16, 0.56, 0.06), 0, -0.2, 0.14, CLOTH_LIGHT, FABRIC)
bar(rifleRoot, "StockUpper", RF(0, 0.06, 0.04).Position, RF(0, -0.02, -0.72).Position, 0.16, 0.14, STEEL, METAL)
bar(rifleRoot, "StockLower", RF(0, -0.46, 0.04).Position, RF(0, -0.18, -0.74).Position, 0.15, 0.13, STEEL, METAL)
bar(rifleRoot, "StockStrut", RF(0, -0.42, -0.26).Position, RF(0, 0.0, -0.4).Position, 0.08, 0.08, STEEL_DARK, METAL)
R("CheekRest", Vector3.new(0.18, 0.06, 0.4), 0, 0.15, -0.28, STEEL_DARK, METAL)
RG("StockRune", Vector3.new(0.17, 0.035, 0.22), 0, -0.3, -0.42, ENERGY, 0.1, math.rad(-20), 0, 0)
-- grip and trigger
bar(rifleRoot, "PistolGrip", RF(0, -0.08, -0.78).Position, RF(0, -0.5, -0.64).Position, 0.14, 0.18, STEEL_DARK, METAL)
R("TriggerGuard", Vector3.new(0.05, 0.04, 0.36), 0, -0.3, -0.98, STEEL, METAL)
bar(rifleRoot, "TriggerGuardFront", RF(0, -0.3, -1.15).Position, RF(0, -0.1, -1.18).Position, 0.05, 0.04, STEEL, METAL)
R("Trigger", Vector3.new(0.03, 0.14, 0.04), 0, -0.19, -0.97, SILVER, METAL, math.rad(15))
-- receiver: a long block with a raised spine, side plates, gothic fins, the ejection port on the right
R("Receiver", Vector3.new(0.3, 0.38, 1.25), 0, 0.0, -1.32, STEEL, METAL)
R("ReceiverSpine", Vector3.new(0.18, 0.08, 1.2), 0, 0.22, -1.32, STEEL_DARK, METAL)
for _, s in ipairs({ -1, 1 }) do
	R("ReceiverPlate", Vector3.new(0.04, 0.26, 1.0), s * 0.165, 0.0, -1.32, STEEL_DARK, METAL)
	R("ReceiverTrim", Vector3.new(0.045, 0.03, 1.02), s * 0.168, 0.14, -1.32, SILVER, METAL)
	-- a fin sweeping back from the front of the receiver
	RW("ReceiverFin", Vector3.new(0.035, 0.28, 0.6), s * 0.17, -0.22, -1.6, STEEL, math.rad(180), 0, 0)
end
R("EjectionPort", Vector3.new(0.03, 0.12, 0.34), 0.175, 0.04, -1.12, VOID)
RG("ChamberGlow", Vector3.new(0.025, 0.06, 0.26), 0.18, 0.04, -1.12, ENERGY, 0)
-- the bolt on its own joint (Bolt: rifle -> BoltRoot, the bolt's axis = the bore): the animator lifts the handle
-- (a turn about Z) and draws it back (+Z) after every shot, the right hand following the knob
local boltRoot = part("BoltRoot", Vector3.new(0.08, 0.08, 0.1), RF(0.2, 0.1, -0.86), SILVER, METAL)
motor("Bolt", rifleRoot, boltRoot, RF(0.0, 0.1, -0.86))
bar(boltRoot, "BoltHandle", RF(0.2, 0.1, -0.86).Position, RF(0.36, -0.02, -0.8).Position, 0.05, 0.05, SILVER, METAL)
deco(boltRoot, "BoltKnob", Vector3.new(0.11, 0.11, 0.11), RF(0.37, -0.03, -0.8), STEEL_DARK, METAL, Enum.PartType.Ball)
-- the magazine: a short angular box of spectral rounds under the receiver
R("Magazine", Vector3.new(0.18, 0.36, 0.32), 0, -0.32, -1.45, STEEL_DARK, METAL, math.rad(-8))
RG("MagazineWindow", Vector3.new(0.19, 0.2, 0.05), 0, -0.32, -1.36, ENERGY_DEEP, 0.15, math.rad(-8))
-- scope: rear eyepiece, tube, turret, objective bell, two mounts with gothic claws
local SCOPE_Y = 0.48
cyl(rifleRoot, "ScopeEyepiece", RF(0, SCOPE_Y, -0.5).Position, Vector3.new(0, 0, -1), 0.26, 0.26, STEEL_DARK, METAL)
cyl(rifleRoot, "ScopeTube", RF(0, SCOPE_Y, -1.35).Position, Vector3.new(0, 0, -1), 1.5, 0.17, STEEL, METAL)
cyl(rifleRoot, "ScopeBell", RF(0, SCOPE_Y, -2.2).Position, Vector3.new(0, 0, -1), 0.36, 0.3, STEEL_DARK, METAL)
cyl(rifleRoot, "ScopeBellRim", RF(0, SCOPE_Y, -2.39).Position, Vector3.new(0, 0, -1), 0.04, 0.32, SILVER, METAL)
local lens = cyl(rifleRoot, "ScopeLens", RF(0, SCOPE_Y, -2.4).Position, Vector3.new(0, 0, -1), 0.03, 0.2, Color3.fromRGB(40, 90, 200), NEON)
lens.Transparency = 0.45
local eyeLens = cyl(rifleRoot, "ScopeEyeLens", RF(0, SCOPE_Y, -0.36).Position, Vector3.new(0, 0, -1), 0.02, 0.18, ENERGY_DEEP, NEON)
eyeLens.Transparency = 0.3
cyl(rifleRoot, "ScopeTurret", RF(0, SCOPE_Y + 0.12, -1.3).Position, Vector3.new(0, 1, 0), 0.12, 0.13, STEEL_DARK, METAL)
cyl(rifleRoot, "ScopeTurretSide", RF(0.12, SCOPE_Y, -1.3).Position, Vector3.new(1, 0, 0), 0.1, 0.12, STEEL_DARK, METAL)
for _, z in ipairs({ -0.9, -1.75 }) do
	R("ScopeMount", Vector3.new(0.1, 0.3, 0.12), 0, 0.33, z, STEEL_DARK, METAL)
	cyl(rifleRoot, "ScopeRing", RF(0, SCOPE_Y, z).Position, Vector3.new(0, 0, -1), 0.1, 0.22, STEEL, METAL)
	for _, s in ipairs({ -1, 1 }) do
		bar(rifleRoot, "ScopeClaw", RF(s * 0.06, 0.3, z).Position, RF(s * 0.16, 0.42, z + 0.05).Position, 0.04, 0.04, SILVER, METAL)
	end
end
-- fore-end: a layered handguard with rune channels on both sides
R("ForeEnd", Vector3.new(0.34, 0.34, 1.7), 0, -0.02, -2.8, STEEL_DARK, METAL)
R("ForeEndTop", Vector3.new(0.26, 0.08, 1.74), 0, 0.18, -2.8, STEEL, METAL)
R("ForeEndBelly", Vector3.new(0.22, 0.1, 1.5), 0, -0.22, -2.75, STEEL, METAL)
for _, s in ipairs({ -1, 1 }) do
	for k = 0, 3 do
		RG("ForeEndRune", Vector3.new(0.025, 0.03, 0.24), s * 0.174, 0.02, -2.2 - k * 0.38, ENERGY, 0.2)
	end
	R("ForeEndRib", Vector3.new(0.05, 0.36, 0.06), s * 0.18, -0.02, -1.98, SILVER, METAL)
	R("ForeEndRib", Vector3.new(0.05, 0.36, 0.06), s * 0.18, -0.02, -3.62, SILVER, METAL)
end
-- barrel: an octagonal housing (two boxes crossed at 45 degrees) with a recessed channel on top, braces and fins
local BARREL_FROM, BARREL_TO = -3.6, -6.35
local barrelLen = BARREL_FROM - BARREL_TO
local barrelMid = (BARREL_FROM + BARREL_TO) / 2
R("BarrelHousing", Vector3.new(0.24, 0.24, barrelLen), 0, 0.02, barrelMid, STEEL, METAL)
R("BarrelHousing45", Vector3.new(0.22, 0.22, barrelLen - 0.02), 0, 0.02, barrelMid, STEEL_DARK, METAL, 0, 0, math.rad(45))
RG("BarrelChannel", Vector3.new(0.05, 0.03, barrelLen - 0.3), 0, 0.165, barrelMid, ENERGY, 0)
for _, s in ipairs({ -1, 1 }) do
	R("BarrelChannelLip", Vector3.new(0.035, 0.05, barrelLen - 0.2), s * 0.05, 0.15, barrelMid, SILVER, METAL)
end
local BRACES = { -3.75, -4.55, -5.35, -6.05 }
for i, z in ipairs(BRACES) do
	cyl(rifleRoot, "BarrelBrace", RF(0, 0.02, z).Position, Vector3.new(0, 0, -1), 0.12, 0.36, STEEL_DARK, METAL)
	cyl(rifleRoot, "BarrelBraceTrim", RF(0, 0.02, z).Position, Vector3.new(0, 0, -1), 0.14, 0.31, SILVER, METAL)
	-- gothic fins: a pointed blade up and two swept down at every other brace
	if i % 2 == 1 then
		RW("BarrelFin", Vector3.new(0.035, 0.3, 0.42), 0, 0.3, z + 0.12, STEEL)
		for _, s in ipairs({ -1, 1 }) do
			RW("BarrelFinLow", Vector3.new(0.03, 0.22, 0.34), s * 0.14, -0.2, z + 0.1, STEEL, math.pi, 0, s * math.rad(30))
		end
	end
end
-- muzzle: a heavy brake with side ports and a crown of four prongs where the sights are born
R("MuzzleBrake", Vector3.new(0.34, 0.34, 0.5), 0, 0.02, -6.55, STEEL_DARK, METAL)
for _, s in ipairs({ -1, 1 }) do
	for k = 0, 1 do
		R("MuzzlePort", Vector3.new(0.03, 0.18, 0.08), s * 0.172, 0.02, -6.45 - k * 0.18, VOID)
	end
end
cyl(rifleRoot, "MuzzleCollar", RF(0, 0.02, -6.82).Position, Vector3.new(0, 0, -1), 0.06, 0.4, SILVER, METAL)
for k = 0, 3 do
	local a = k * math.pi / 2 + math.pi / 4
	local base = RF(math.cos(a) * 0.17, 0.02 + math.sin(a) * 0.17, -6.84).Position
	local tip = RF(math.cos(a) * 0.3, 0.02 + math.sin(a) * 0.3, -7.18).Position
	bar(rifleRoot, "MuzzleProng", base, tip, 0.05, 0.05, STEEL, METAL)
	glow(rifleRoot, "MuzzleProngTip", Vector3.new(0.05, 0.05, 0.05), CFrame.new(tip), ENERGY)
end
local bore = cyl(rifleRoot, "MuzzleBore", RF(0, 0.02, -6.81).Position, Vector3.new(0, 0, -1), 0.02, 0.13, ENERGY_CORE, NEON)
light(bore, 3, 0.8, ENERGY)
-- attachments the effects and the animator use
attach(rifleRoot, "Muzzle", RF(0, 0.02, -6.86))
attach(rifleRoot, "RingOrigin", RF(0, 0.02, -7.2))
attach(rifleRoot, "ScopeEye", RF(0, SCOPE_Y, -0.36))
attach(rifleRoot, "ScopeLens", RF(0, SCOPE_Y, -2.42))
attach(rifleRoot, "Ejection", RF(0.2, 0.04, -1.12))
attach(rifleRoot, "Chamber", RF(0, 0.02, -1.1))
attach(rifleRoot, "Butt", RF(0, -0.2, 0.12))
local GRIP_R = RF(0.0, -0.28, -0.74) -- the hand's centre on the pistol grip
local GRIP_L = RF(-0.04, -0.3, -2.55) -- under the fore-end
attach(rifleRoot, "GripR", GRIP_R)
attach(rifleRoot, "GripL", GRIP_L)

-- ====================================================================
-- Arms: armoured sleeves under the mantle, bracers, bare bone wrists and skeletal hands that grip the rifle
-- ====================================================================
local UPPER_LEN, FORE_LEN = 1.08, 1.02
local function arm(side, shoulder, gripCF, wristBack, pole, curlAxis)
	local wrist = (gripCF * CFrame.new(wristBack)).Position
	local elbow = solveJoint(shoulder, wrist, UPPER_LEN, FORE_LEN, pole)
	local upper = part(side .. "UpperArm", Vector3.new(0.3, 0.3, 0.3), CFrame.lookAt((shoulder + elbow) / 2, elbow), CLOTH)
	upper.Transparency = 1
	motor(side .. "Shoulder", torso, upper, shoulder)
	bar(upper, "Sleeve", shoulder, elbow, 0.34, 0.34, CLOTH_LIGHT, FABRIC)
	bar(upper, "ArmPlate", shoulder:Lerp(elbow, 0.2), shoulder:Lerp(elbow, 0.85), 0.2, 0.38, STEEL, METAL, side == "L" and math.rad(20) or math.rad(-20))
	local fore = part(side .. "Forearm", Vector3.new(0.28, 0.28, 0.28), CFrame.lookAt((elbow + wrist) / 2, wrist), CLOTH)
	fore.Transparency = 1
	motor(side .. "Elbow", upper, fore, elbow)
	deco(fore, "ElbowCop", Vector3.new(0.3, 0.3, 0.3), CFrame.lookAt(elbow, wrist) * CFrame.Angles(0, 0, math.rad(45)), STEEL, METAL)
	-- the bracer covers the forearm up to a flared, pointed cuff; then two bare bones to the wrist
	local cuff = elbow:Lerp(wrist, 0.74)
	bar(fore, "Bracer", elbow:Lerp(wrist, 0.08), cuff, 0.27, 0.27, STEEL, METAL)
	bar(fore, "BracerTrim", cuff - (wrist - elbow).Unit * 0.04, cuff + (wrist - elbow).Unit * 0.03, 0.33, 0.33, SILVER, METAL)
	bar(fore, "BracerSpike", elbow:Lerp(wrist, 0.5), elbow:Lerp(wrist, 0.5) + (-pole).Unit * -0.2 + (wrist - elbow).Unit * -0.25, 0.06, 0.06, STEEL, METAL)
	glow(fore, "BracerRune", Vector3.new(0.05, 0.05, 0.05), CFrame.new(elbow:Lerp(wrist, 0.45) + pole.Unit * 0.14))
	for _, f in ipairs({ 0.22, 0.4, 0.58 }) do
		bar(fore, "BracerBand", elbow:Lerp(wrist, f - 0.02), elbow:Lerp(wrist, f + 0.02), 0.3, 0.3, f == 0.4 and SILVER or STEEL_DARK, METAL)
	end
	bar(upper, "SleeveBand", shoulder:Lerp(elbow, 0.9), elbow, 0.37, 0.37, CLOTH_RIM, FABRIC)
	bar(upper, "ArmPlateEdge", shoulder:Lerp(elbow, 0.84), shoulder:Lerp(elbow, 0.88), 0.22, 0.4, SILVER, METAL, side == "L" and math.rad(20) or math.rad(-20))
	local d = (wrist - elbow).Unit
	local perp = d:Cross(Vector3.new(0, 1, 0))
	perp = perp.Magnitude > 0.01 and perp.Unit or Vector3.new(1, 0, 0)
	for _, s in ipairs({ -1, 1 }) do
		bar(fore, "WristBone", cuff + perp * s * 0.05, wrist + perp * s * 0.03, 0.05, 0.05, BONE)
	end
	-- the hand: a bony palm at the grip, fingers curled round it (each finger two bones), the thumb over the top
	local hand = part(side .. "Hand", Vector3.new(0.12, 0.2, 0.22), CFrame.lookAt(wrist, gripCF.Position) * CFrame.new(0, 0, -0.1), BONE)
	motor(side .. "Wrist", fore, hand, wrist)
	return hand, wrist
end

-- the right hand: on the pistol grip, index finger on the trigger
do
	local hand, wrist = arm("R", R_SHOULDER, GRIP_R, Vector3.new(0.06, 0.12, 0.2), Vector3.new(1, -1.2, 0.5))
	for k = 0, 2 do -- three fingers wrapped round the grip from the left side
		local y = -0.32 - k * 0.07
		local a = RF(0.09, y, -0.62 - k * 0.015).Position
		local b = RF(-0.1, y - 0.02, -0.64).Position
		local c = RF(-0.1, y - 0.03, -0.78).Position
		bar(hand, "Finger", a, b, 0.05, 0.05, BONE)
		bar(hand, "FingerTip", b, c, 0.045, 0.045, BONE)
		deco(hand, "Knuckle", Vector3.new(0.065, 0.065, 0.065), CFrame.new(b), BONE_DARK)
	end
	bar(hand, "Index", RF(0.08, -0.18, -0.72).Position, RF(0.03, -0.2, -0.92).Position, 0.045, 0.045, BONE)
	bar(hand, "IndexTip", RF(0.03, -0.2, -0.92).Position, RF(0.0, -0.24, -0.98).Position, 0.04, 0.04, BONE)
	bar(hand, "Thumb", RF(-0.06, -0.1, -0.66).Position, RF(-0.1, -0.02, -0.82).Position, 0.05, 0.05, BONE)
	bar(hand, "Knuckles", RF(0.1, -0.2, -0.64).Position, RF(0.1, -0.44, -0.64).Position, 0.08, 0.06, BONE_DARK)
end
-- the left hand: under the fore-end, palm up, fingers curling up over the far side
do
	local hand = arm("L", L_SHOULDER, GRIP_L, Vector3.new(-0.16, -0.1, 0.12), Vector3.new(-0.5, -1, 0.2))
	for k = 0, 3 do
		local z = -2.42 - k * 0.07
		local a = RF(-0.12, -0.27, z).Position
		local b = RF(0.17, -0.25, z).Position
		local c = RF(0.21, -0.06, z).Position
		bar(hand, "Finger", a, b, 0.045, 0.045, BONE)
		bar(hand, "FingerTip", b, c, 0.04, 0.04, BONE)
		deco(hand, "Knuckle", Vector3.new(0.06, 0.06, 0.06), CFrame.new(b), BONE_DARK)
	end
	bar(hand, "Thumb", RF(-0.14, -0.2, -2.5).Position, RF(-0.19, -0.04, -2.68).Position, 0.05, 0.05, BONE)
end

-- ====================================================================
-- The mantle: torn strips from the shoulders and the back, each a chain of segments on Mantle<i>_<k> joints so the
-- animator can trail them on springs. It streams back and a little to his left, like the wind in the art.
-- ====================================================================
local MANTLE = {
	{ x = -0.66, segs = { 1.2, 1.15, 0.8 }, w = 0.6, flare = 0.3 },
	{ x = -0.36, segs = { 1.3, 1.25, 1.0 }, w = 0.62, flare = 0.22 },
	{ x = -0.02, segs = { 1.35, 1.3, 1.1 }, w = 0.66, flare = 0.17 },
	{ x = 0.32, segs = { 1.3, 1.2, 0.9 }, w = 0.6, flare = 0.21 },
	{ x = 0.62, segs = { 1.15, 1.05 }, w = 0.54, flare = 0.28 },
}
for i, m in ipairs(MANTLE) do
	local top = U(m.x, 1.7, 0.44 - math.abs(m.x) * 0.14) -- (staggered: the middle strip lies outermost, no shared planes)
	-- the strip's frame: hangs down -Y, faces back (+Z of the chest), tilted out from the back
	local frame = top * CFrame.Angles(-m.flare, 0, m.x * -0.25)
	local parentPart = torso
	for k, L in ipairs(m.segs) do
		local hinge = part("Mantle" .. i .. "_" .. k .. "Hinge", Vector3.new(0.1, 0.1, 0.1), frame, CLOTH)
		hinge.Transparency = 1
		local j = motor("Mantle" .. i .. "_" .. k, parentPart, hinge, frame)
		j:SetAttribute("MantleIndex", i)
		j:SetAttribute("Segment", k)
		local last = k == #m.segs
		local w = m.w * (1 - (k - 1) * 0.12)
		if last then
			rag(hinge, "MantleCloth", frame, w, L, 0.05, 3, (i + k) % 2 == 0 and CLOTH or CLOTH_LIGHT, 0.55)
		else
			deco(hinge, "MantleCloth", Vector3.new(w, L + 0.06, 0.05), frame * CFrame.new(0, -L / 2, 0), (i + k) % 2 == 0 and CLOTH or CLOTH_LIGHT, FABRIC)
			-- a torn hole or a frayed edge every few segments
			deco(hinge, "MantleFray", Vector3.new(0.08, L * 0.4, 0.06), frame * CFrame.new(w / 2 - 0.02, -L * 0.6, 0) * CFrame.Angles(0, 0, 0.2), CLOTH_RIM, FABRIC)
			deco(hinge, "MantleCrease", Vector3.new(0.05, L * 0.7, 0.065), frame * CFrame.new(-w * 0.18, -L * 0.45, 0) * CFrame.Angles(0, 0, -0.06), (i + k) % 2 == 0 and CLOTH_LIGHT or CLOTH, FABRIC)
			deco(hinge, "MantleEdge", Vector3.new(0.06, L * 0.85, 0.06), frame * CFrame.new(-w / 2 + 0.02, -L * 0.48, 0), CLOTH_RIM, FABRIC)
			if k == 1 then
				deco(hinge, "MantleBand", Vector3.new(w * 0.96, 0.08, 0.065), frame * CFrame.new(0, -0.12, 0), CLOTH_RIM, FABRIC)
				deco(hinge, "MantleBandStud", Vector3.new(0.05, 0.05, 0.08), frame * CFrame.new(0, -0.12, 0) * CFrame.Angles(0, 0, math.rad(45)), SILVER, METAL)
			end
		end
		parentPart = hinge
		frame = frame * CFrame.new(0, -L, 0) * CFrame.Angles(-0.1, 0, 0)
	end
end

-- thin torn ribbons (the strips that trail behind him in the art): from the back of the belt and the left shoulder,
-- on the same Mantle<i>_<k> joints (attribute Thin = true, so the animator can let them flutter more)
local RIBBONS = {
	{ from = pelvis, at = LOWER * CFrame.new(-0.3, 0.2, 0.4), segs = { 0.9, 0.85, 0.7 }, w = 0.13, flare = 0.4 },
	{ from = pelvis, at = LOWER * CFrame.new(0.18, 0.18, 0.42), segs = { 1.0, 0.9, 0.8 }, w = 0.11, flare = 0.35 },
	{ from = torso, at = U(-0.8, 1.45, 0.25), segs = { 0.8, 0.75, 0.6 }, w = 0.12, flare = 0.5 },
	{ from = torso, at = U(-0.62, 1.6, 0.4), segs = { 0.9, 0.8 }, w = 0.1, flare = 0.45 },
}
for n, r in ipairs(RIBBONS) do
	local i = #MANTLE + n
	local frame = r.at * CFrame.Angles(-r.flare, 0, 0)
	local parentPart = r.from
	for k, L in ipairs(r.segs) do
		local hinge = part("Mantle" .. i .. "_" .. k .. "Hinge", Vector3.new(0.1, 0.1, 0.1), frame, CLOTH)
		hinge.Transparency = 1
		local j = motor("Mantle" .. i .. "_" .. k, parentPart, hinge, frame)
		j:SetAttribute("MantleIndex", i)
		j:SetAttribute("Segment", k)
		j:SetAttribute("Thin", true)
		local w = r.w * (1 - (k - 1) * 0.15)
		deco(hinge, "Ribbon", Vector3.new(w, L + 0.04, 0.03), frame * CFrame.new(0, -L / 2, 0), k % 2 == 0 and CLOTH_LIGHT or CLOTH, FABRIC)
		if k == #r.segs then
			deco(hinge, "RibbonTip", Vector3.new(w * 0.7, w * 0.7, 0.025), frame * CFrame.new(0, -L, 0) * CFrame.Angles(0, 0, math.rad(45)), CLOTH, FABRIC)
		end
		parentPart = hinge
		frame = frame * CFrame.new(0, -L, 0) * CFrame.Angles(-0.12, 0, (n % 2 == 0 and 1 or -1) * 0.08)
	end
end

-- ====================================================================
-- Floating shards above and behind the shoulders: dark elongated crystals with a violet core, each on its own joint
-- (Shard<i>, attribute ShardIndex) so they can drift individually and later fly out to become the sights' brackets.
-- ====================================================================
local SHARDS = {
	{ U(-1.05, 2.55, 0.55), 0.8, 0.5, -0.3 },
	{ U(-1.45, 1.85, 0.95), 0.6, -0.4, 0.6 },
	{ U(-0.55, 2.95, 0.95), 0.55, 0.2, 0.9 },
	{ U(0.95, 2.45, 0.85), 0.7, -0.6, -0.5 },
	{ U(1.35, 1.75, 0.55), 0.5, 0.7, 0.2 },
	{ U(0.2, 3.1, 1.25), 0.45, -0.2, -0.8 },
}
for i, s in ipairs(SHARDS) do
	local c = CFrame.new(s[1].Position) * CFrame.Angles(s[3], i * 1.3, s[4])
	local core = part("Shard" .. i .. "Core", Vector3.new(0.07, s[2] * 0.6, 0.07), c, ENERGY, NEON)
	motor("Shard" .. i, torso, core, c):SetAttribute("ShardIndex", i)
	local L = s[2]
	local w = L * 0.24
	-- a long diamond prism, stepped down to a point at each end, two of its edges glowing
	deco(core, "ShardBody", Vector3.new(w, L * 0.5, w), c * CFrame.Angles(0, math.rad(45), 0), SHARD, METAL)
	for _, d in ipairs({ 1, -1 }) do
		deco(core, "ShardPoint", Vector3.new(w * 0.62, L * 0.2, w * 0.62), c * CFrame.new(0, d * L * 0.33, 0) * CFrame.Angles(0, math.rad(45), 0), SHARD, METAL)
		deco(core, "ShardTip", Vector3.new(w * 0.28, L * 0.14, w * 0.28), c * CFrame.new(0, d * L * 0.48, 0) * CFrame.Angles(0, math.rad(45), 0), SHARD, METAL)
	end
	glow(core, "ShardEdge", Vector3.new(0.025, L * 0.46, 0.025), c * CFrame.new(w * 0.71, 0, 0), ENERGY, 0.35)
end

-- a faint cold light round him, so the dark layers read at night
light(torso, 6, 0.5, Color3.fromRGB(110, 100, 200))

model:SetAttribute("Rig", "Procedural")
model:SetAttribute("RootHeight", HIP_Y)
model:SetAttribute("Height", 7.4)
model:SetAttribute("Float", 0.1)
model:SetAttribute("Pose", "Marksman")
model:SetAttribute("AttackStyle", "Marksman")
model:SetAttribute("StunCore", "Torso") -- (StunFx: the titan's stun rings sit on his body, not on his rifle's box)
model:SetAttribute("StunSize", Vector3.new(3.4, 7.4, 3.4))
model:SetAttribute("SpecialDuration", 13.5) -- (the charge meter shows the special firing this long: VeyrTimeline.SPECIAL.END)
model:SetAttribute("BuiltBy", "build_veyr")
model.Parent = models

local parts, joints = 0, 0
for _, d in ipairs(model:GetDescendants()) do
	if d:IsA("BasePart") then parts += 1 end
	if d:IsA("Motor6D") then joints += 1 end
end
return NAME .. ": " .. parts .. " parts, " .. joints .. " joints"
