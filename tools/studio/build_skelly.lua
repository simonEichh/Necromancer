-- Builds the rigged Skelly into ServerStorage.Models.Skelly.
-- v2 (2026-10-15): a detailed skeleton soldier: an open ribcage (separate ribs, sternum, spine, clavicles, shoulder
-- blades) with a soul glow inside, a skull with brow ridge, dark sockets, glowing eyes, cheekbones, gapped teeth and a
-- crack, bony limbs with joint knobs, a rusted pauldron (left) and greave (right), a belt and a tattered loincloth, and a
-- proper arming sword (pommel, wrapped grip, crossguard, fuller, pointed tip) gripped in the fist on its own wrist joint.
-- Run in Studio's command bar / via the Studio MCP execute_luau (Edit mode), then run publish_unit_models.lua.
--
-- Rig conventions (see src/client/Modules/UnitAnimator.lua):
--   * front = -Z, character's right = +X, feet on y = 0, root part = HumanoidRootPart at y = 2.2
--   * joints are Motor6Ds named Root/Waist/Neck/Jaw/LShoulder/RShoulder/LElbow/RElbow/RWrist/LHip/RHip/LKnee/RKnee
--     whose rest rotation is identity, so animating = setting Motor6D.Transform
--   * RWrist (right forearm -> fist): the sword is welded to the fist; a positive X rotation tips the blade up.
--     At rest the blade points forward and 30 degrees down.
--   * attributes: Rig = "Procedural", RootHeight, Height, AttackStyle = "Strike" (UnitAnimator's sword chop)
local ServerStorage = game:GetService("ServerStorage")
local models = ServerStorage.Models

local old = models:FindFirstChild("Skelly")
if old and old:GetAttribute("Rig") ~= "Procedural" then
	old.Name = "Skelly_Old"
elseif old then
	old:Destroy()
end

local BONE = Color3.fromRGB(222, 214, 192)
local BONE_SHADE = Color3.fromRGB(186, 177, 154)
local BONE_DARK = Color3.fromRGB(132, 123, 104)
local TOOTH = Color3.fromRGB(232, 222, 188)
local SOCKET = Color3.fromRGB(22, 19, 21)
local GLOW = Color3.fromRGB(110, 255, 175)
local IRON = Color3.fromRGB(84, 82, 82)
local RUST = Color3.fromRGB(122, 70, 44)
local STEEL = Color3.fromRGB(170, 174, 180)
local STEEL_DARK = Color3.fromRGB(98, 102, 110)
local LEATHER = Color3.fromRGB(70, 48, 36)
local LEATHER_DARK = Color3.fromRGB(46, 32, 26)
local CLOTH = Color3.fromRGB(66, 30, 34)

local SMOOTH = Enum.Material.SmoothPlastic

local model = Instance.new("Model")
model.Name = "Skelly"

local function part(name, size, at, color, material, shape)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = typeof(at) == "CFrame" and at or CFrame.new(at)
	p.Color = color
	p.Material = material or SMOOTH
	if shape then
		p.Shape = shape
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

local function wedge(name, size, cf, color, material)
	local p = Instance.new("WedgePart")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or SMOOTH
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.Anchored = false
	p.Parent = model
	return p
end

local function motor(name, p0, p1, jointPos)
	local m = Instance.new("Motor6D")
	m.Name = name
	m.Part0 = p0
	m.Part1 = p1
	m.C0 = p0.CFrame:Inverse() * CFrame.new(jointPos)
	m.C1 = p1.CFrame:Inverse() * CFrame.new(jointPos)
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

-- a bone (or strap) between two points, welded to `to`; w x h is its cross-section
local function bar(name, a, b, w, h, color, to, material)
	local p = part(name, Vector3.new(w, h or w, (b - a).Magnitude), CFrame.lookAt((a + b) / 2, b), color, material)
	weld(to, p)
	return p
end

local function deco(to, name, size, at, color, material, shape)
	local p = part(name, size, at, color, material, shape)
	weld(to, p)
	return p
end

-- ── Pelvis ────────────────────────────────────────────────────
local root = part("HumanoidRootPart", Vector3.new(1.2, 0.4, 0.8), Vector3.new(0, 2.2, 0), BONE)
root.Transparency = 1
model.PrimaryPart = root

local pelvis = part("Pelvis", Vector3.new(0.7, 0.26, 0.42), Vector3.new(0, 2.2, 0.06), BONE_SHADE)
motor("Root", root, pelvis, Vector3.new(0, 2.2, 0))
for _, x in ipairs({ -1, 1 }) do
	-- the hip bones flare up and out
	deco(pelvis, "Ilium", Vector3.new(0.36, 0.4, 0.4), CFrame.new(x * 0.36, 2.3, 0.04) * CFrame.Angles(0, 0, x * 0.3), BONE)
end
deco(pelvis, "Sacrum", Vector3.new(0.28, 0.34, 0.12), Vector3.new(0, 2.24, 0.3), BONE_SHADE)
deco(pelvis, "Pubis", Vector3.new(0.46, 0.12, 0.14), Vector3.new(0, 2.06, -0.16), BONE_SHADE)

-- belt, buckle and a tattered loincloth (front and back strips of different lengths)
deco(pelvis, "Belt", Vector3.new(1.0, 0.13, 0.6), Vector3.new(0, 2.4, 0.04), LEATHER, Enum.Material.Leather)
deco(pelvis, "Buckle", Vector3.new(0.2, 0.17, 0.05), Vector3.new(0.14, 2.4, -0.27), IRON, Enum.Material.Metal)
deco(pelvis, "BuckleTongue", Vector3.new(0.04, 0.13, 0.06), Vector3.new(0.14, 2.4, -0.29), RUST, Enum.Material.Metal)
for i, s in ipairs({ { -0.2, 0.26, 0.5, 0.06 }, { 0.04, 0.24, 0.68, -0.04 }, { 0.27, 0.2, 0.42, 0.1 } }) do
	local x, w, h, roll = s[1], s[2], s[3], s[4]
	deco(pelvis, "ClothFront" .. i, Vector3.new(w, h, 0.04),
		CFrame.new(x, 2.36 - h / 2, -0.33) * CFrame.Angles(0.06, 0, roll), CLOTH, Enum.Material.Fabric)
end
for i, s in ipairs({ { -0.14, 0.34, 0.6, -0.05 }, { 0.2, 0.28, 0.46, 0.08 } }) do
	local x, w, h, roll = s[1], s[2], s[3], s[4]
	deco(pelvis, "ClothBack" .. i, Vector3.new(w, h, 0.04),
		CFrame.new(x, 2.36 - h / 2, 0.37) * CFrame.Angles(-0.06, 0, roll), CLOTH, Enum.Material.Fabric)
end

-- ── Spine + ribcage ───────────────────────────────────────────
local torso = part("Torso", Vector3.new(0.2, 1.26, 0.2), Vector3.new(0, 3.05, 0.28), BONE_SHADE)
motor("Waist", pelvis, torso, Vector3.new(0, 2.4, 0.1))
for i = 0, 4 do
	deco(torso, "Vertebra" .. i, Vector3.new(0.12, 0.08, 0.14), Vector3.new(0, 2.6 + i * 0.24, 0.42), BONE)
end
deco(torso, "Lumbar", Vector3.new(0.26, 0.12, 0.26), Vector3.new(0, 2.52, 0.24), BONE)

-- four ribs, each a ring of three bars per side (back to the spine, the side, forward and down to the sternum);
-- the lowest one is a floating rib that stops short of the sternum
local RIBS = { { 3.48, 0.6 }, { 3.27, 0.64 }, { 3.05, 0.6 }, { 2.85, 0.5 } }
for i, r in ipairs(RIBS) do
	local y, half = r[1], r[2]
	for _, x in ipairs({ -1, 1 }) do
		local back = Vector3.new(x * 0.1, y + 0.05, 0.32)
		local sideBack = Vector3.new(x * half, y, 0.2)
		local sideFront = Vector3.new(x * half, y - 0.02, -0.3)
		local front = Vector3.new(x * 0.1, y - 0.12, -0.44)
		bar("Rib", back, sideBack, 0.08, 0.09, BONE, torso)
		bar("Rib", sideBack, sideFront, 0.08, 0.09, BONE, torso)
		if i < #RIBS then
			bar("Rib", sideFront, front, 0.08, 0.09, BONE, torso)
		else
			bar("Rib", sideFront, sideFront:Lerp(front, 0.45), 0.08, 0.09, BONE, torso)
		end
	end
end
deco(torso, "Sternum", Vector3.new(0.16, 0.62, 0.08), Vector3.new(0, 3.2, -0.45), BONE)
deco(torso, "Xiphoid", Vector3.new(0.08, 0.14, 0.06), Vector3.new(0, 2.84, -0.44), BONE_SHADE)
for _, x in ipairs({ -1, 1 }) do
	bar("Clavicle", Vector3.new(x * 0.08, 3.6, -0.42), Vector3.new(x * 0.82, 3.64, -0.04), 0.09, 0.09, BONE, torso)
	deco(torso, "Scapula", Vector3.new(0.36, 0.46, 0.07), CFrame.new(x * 0.42, 3.34, 0.36) * CFrame.Angles(0, 0, x * 0.12), BONE_SHADE)
end

-- the soul that animates it: a green glow hovering inside the ribs
local soul = deco(torso, "Soul", Vector3.one * 0.3, Vector3.new(0, 3.18, -0.06), GLOW, Enum.Material.Neon, Enum.PartType.Ball)
local halo = deco(torso, "SoulHalo", Vector3.one * 0.5, Vector3.new(0, 3.18, -0.06), GLOW, Enum.Material.Neon, Enum.PartType.Ball)
halo.Transparency = 0.75
local soulLight = Instance.new("PointLight")
soulLight.Color = GLOW
soulLight.Range = 5
soulLight.Brightness = 1.2
soulLight.Shadows = false
soulLight.Parent = soul

-- a leather strap across the chest (left shoulder to right hip)
bar("Strap", Vector3.new(-0.55, 3.62, -0.47), Vector3.new(0.52, 2.5, -0.47), 0.13, 0.04, LEATHER, torso, Enum.Material.Leather)

-- ── Head ──────────────────────────────────────────────────────
local head = part("Head", Vector3.new(1.0, 0.72, 1.02), Vector3.new(0, 4.52, 0.02), BONE)
motor("Neck", torso, head, Vector3.new(0, 3.7, 0.1))
deco(head, "NeckBone1", Vector3.new(0.2, 0.12, 0.2), Vector3.new(0, 3.77, 0.12), BONE_SHADE)
deco(head, "NeckBone2", Vector3.new(0.2, 0.12, 0.2), Vector3.new(0, 3.9, 0.1), BONE_SHADE)
deco(head, "CraniumTop", Vector3.new(0.84, 0.14, 0.86), Vector3.new(0, 4.93, 0.04), BONE)
deco(head, "CraniumBack", Vector3.new(0.88, 0.5, 0.2), Vector3.new(0, 4.46, 0.56), BONE)
deco(head, "Face", Vector3.new(0.84, 0.36, 0.86), Vector3.new(0, 4.04, -0.05), BONE)
deco(head, "Brow", Vector3.new(1.02, 0.14, 0.2), Vector3.new(0, 4.36, -0.45), BONE_SHADE)
for _, x in ipairs({ -1, 1 }) do
	deco(head, "Socket", Vector3.new(0.32, 0.26, 0.08), Vector3.new(x * 0.24, 4.19, -0.49), SOCKET)
	deco(head, "Eye", Vector3.one * 0.13, Vector3.new(x * 0.24, 4.19, -0.51), GLOW, Enum.Material.Neon, Enum.PartType.Ball)
	deco(head, "Cheekbone", Vector3.new(0.16, 0.14, 0.34), Vector3.new(x * 0.47, 4.07, -0.3), BONE_SHADE)
end
local eyeLight = Instance.new("PointLight")
eyeLight.Color = GLOW
eyeLight.Range = 3
eyeLight.Brightness = 0.8
eyeLight.Shadows = false
eyeLight.Parent = head
deco(head, "Nose", Vector3.new(0.12, 0.16, 0.06), Vector3.new(0, 3.99, -0.49), SOCKET)
deco(head, "Mouth", Vector3.new(0.62, 0.1, 0.06), Vector3.new(0, 3.86, -0.44), SOCKET)
for i = 1, 6 do
	if i ~= 4 then -- (a missing tooth)
		deco(head, "Tooth", Vector3.new(0.085, 0.12, 0.06), Vector3.new(-0.25 + (i - 1) * 0.1, 3.84, -0.47), TOOTH)
	end
end
-- a crack running down from the crown towards the right eye
bar("Crack", Vector3.new(0.12, 4.99, -0.2), Vector3.new(0.22, 4.82, -0.47), 0.04, 0.04, SOCKET, head)
bar("Crack", Vector3.new(0.22, 4.82, -0.52), Vector3.new(0.3, 4.48, -0.53), 0.04, 0.04, SOCKET, head)

local jaw = part("Jaw", Vector3.new(0.6, 0.14, 0.2), Vector3.new(0, 3.68, -0.37), BONE_SHADE)
motor("Jaw", head, jaw, Vector3.new(0, 3.88, 0.25))
for _, x in ipairs({ -1, 1 }) do
	bar("JawSide", Vector3.new(x * 0.3, 3.7, -0.32), Vector3.new(x * 0.4, 3.9, 0.15), 0.12, 0.14, BONE_SHADE, jaw)
end
for i = 1, 5 do
	deco(jaw, "LowerTooth", Vector3.new(0.08, 0.1, 0.05), Vector3.new(-0.2 + (i - 1) * 0.1, 3.78, -0.42), TOOTH)
end

-- ── Arms (character's right = +X) ─────────────────────────────
local function arm(side, x)
	local upper = part(side .. "UpperArm", Vector3.new(0.18, 0.8, 0.18), Vector3.new(x, 3.1, 0), BONE)
	motor(side .. "Shoulder", torso, upper, Vector3.new(x, 3.52, 0))
	deco(upper, "ShoulderKnob", Vector3.one * 0.32, Vector3.new(x * 0.97, 3.52, 0), BONE, nil, Enum.PartType.Ball)
	deco(upper, "ElbowKnob", Vector3.new(0.25, 0.22, 0.25), Vector3.new(x, 2.66, 0.02), BONE_SHADE)
	local fore = part(side .. "Forearm", Vector3.new(0.1, 0.78, 0.1), Vector3.new(x - 0.04, 2.2, -0.02), BONE)
	motor(side .. "Elbow", upper, fore, Vector3.new(x, 2.64, 0))
	deco(fore, "Ulna", Vector3.new(0.08, 0.76, 0.08), Vector3.new(x + 0.05, 2.2, 0.04), BONE_SHADE)
	deco(fore, "WristKnob", Vector3.new(0.18, 0.09, 0.18), Vector3.new(x, 1.8, 0), BONE_SHADE)
	return upper, fore
end
local lUpper, lFore = arm("L", -0.95)
local _, rFore = arm("R", 0.95)

-- left hand: an open, hanging claw of finger bones
deco(lFore, "LHand", Vector3.new(0.22, 0.2, 0.18), Vector3.new(-0.95, 1.67, 0), BONE)
for i, z in ipairs({ -0.07, 0, 0.07 }) do
	bar("Finger", Vector3.new(-0.95, 1.58, z), Vector3.new(-0.95 - 0.02 * i, 1.36, z - 0.06), 0.05, 0.05, BONE_SHADE, lFore)
end
bar("Thumb", Vector3.new(-0.86, 1.62, -0.08), Vector3.new(-0.84, 1.48, -0.16), 0.05, 0.05, BONE_SHADE, lFore)

-- rusted pauldron + strap on the left shoulder
deco(lUpper, "Pauldron", Vector3.new(0.5, 0.14, 0.6), CFrame.new(-1.0, 3.64, 0) * CFrame.Angles(0, 0, 0.38), IRON, Enum.Material.Metal)
deco(lUpper, "PauldronRim", Vector3.new(0.52, 0.05, 0.62), CFrame.new(-0.98, 3.72, 0) * CFrame.Angles(0, 0, 0.38), RUST, Enum.Material.Metal)
deco(lUpper, "PauldronLame", Vector3.new(0.44, 0.12, 0.54), CFrame.new(-1.13, 3.45, 0) * CFrame.Angles(0, 0, 0.8), IRON, Enum.Material.Metal)
for _, z in ipairs({ -0.2, 0.2 }) do
	deco(lUpper, "Rivet", Vector3.one * 0.07, CFrame.new(-0.96, 3.73, z) * CFrame.Angles(0, 0, 0.38), STEEL_DARK)
end
deco(lUpper, "ArmStrap", Vector3.new(0.24, 0.08, 0.24), Vector3.new(-0.95, 3.22, 0), LEATHER_DARK, Enum.Material.Leather)

-- ── Right fist + sword (on the RWrist joint) ──────────────────
-- the sword frame: origin in the fist, -Z along the blade (forward and 30 degrees down at rest), Y across the edge
local handPos = Vector3.new(0.95, 1.62, -0.02)
local swordDir = Vector3.new(0, -math.sin(math.rad(30)), -math.cos(math.rad(30)))
local swordCF = CFrame.lookAt(handPos, handPos + swordDir)

local fist = part("RHand", Vector3.new(0.24, 0.24, 0.26), swordCF * CFrame.new(0, 0, 0.04), BONE)
motor("RWrist", rFore, fist, Vector3.new(0.95, 1.79, 0))
deco(fist, "Knuckles", Vector3.new(0.07, 0.2, 0.22), swordCF * CFrame.new(-0.13, 0, 0.04), BONE_SHADE)
deco(fist, "Thumb", Vector3.new(0.08, 0.08, 0.16), swordCF * CFrame.new(0.06, 0.13, -0.06), BONE_SHADE)

local function sword(name, size, offset, color, material)
	return deco(fist, name, size, swordCF * offset, color, material)
end
sword("Pommel", Vector3.new(0.17, 0.17, 0.12), CFrame.new(0, 0, 0.36), IRON, Enum.Material.Metal)
sword("PommelCap", Vector3.new(0.1, 0.1, 0.06), CFrame.new(0, 0, 0.44), RUST, Enum.Material.Metal)
sword("Grip", Vector3.new(0.1, 0.1, 0.46), CFrame.new(0, 0, 0.08), LEATHER, Enum.Material.Leather)
sword("GripWrap", Vector3.new(0.12, 0.12, 0.04), CFrame.new(0, 0, 0.24), LEATHER_DARK, Enum.Material.Leather)
sword("Guard", Vector3.new(0.11, 0.62, 0.1), CFrame.new(0, 0, -0.2), IRON, Enum.Material.Metal)
for _, y in ipairs({ -1, 1 }) do
	-- the quillons bend a little towards the blade
	sword("Quillon", Vector3.new(0.12, 0.1, 0.14), CFrame.new(0, y * 0.33, -0.24) * CFrame.Angles(y * 0.5, 0, 0), RUST, Enum.Material.Metal)
end
sword("Ricasso", Vector3.new(0.075, 0.2, 0.18), CFrame.new(0, 0, -0.34), STEEL_DARK, Enum.Material.Metal)
sword("Blade", Vector3.new(0.055, 0.24, 1.5), CFrame.new(0, 0, -1.1), STEEL, Enum.Material.Metal)
sword("Fuller", Vector3.new(0.065, 0.06, 1.0), CFrame.new(0, 0, -0.95), STEEL_DARK, Enum.Material.Metal)
sword("Rust", Vector3.new(0.062, 0.1, 0.18), CFrame.new(0, 0.06, -0.68), RUST, Enum.Material.Metal)
sword("Rust", Vector3.new(0.062, 0.08, 0.14), CFrame.new(0, -0.07, -1.5), RUST, Enum.Material.Metal)
-- the point: two mirrored wedges
local tipUp = wedge("Tip", Vector3.new(0.055, 0.12, 0.34), swordCF * CFrame.new(0, 0.06, -2.02), STEEL, Enum.Material.Metal)
weld(fist, tipUp)
local tipDown = wedge("Tip", Vector3.new(0.055, 0.12, 0.34), swordCF * CFrame.new(0, -0.06, -2.02) * CFrame.Angles(0, 0, math.pi), STEEL, Enum.Material.Metal)
weld(fist, tipDown)

-- ── Legs ──────────────────────────────────────────────────────
local function leg(side, x)
	local dir = x > 0 and 1 or -1
	local upper = part(side .. "UpperLeg", Vector3.new(0.19, 0.82, 0.19), Vector3.new(x, 1.58, 0), BONE)
	motor(side .. "Hip", pelvis, upper, Vector3.new(x, 2.02, 0))
	deco(upper, "FemurHead", Vector3.one * 0.24, Vector3.new(x * 0.9, 2.0, 0), BONE, nil, Enum.PartType.Ball)
	deco(upper, "KneeKnob", Vector3.new(0.26, 0.2, 0.24), Vector3.new(x, 1.14, 0), BONE_SHADE)
	deco(upper, "Kneecap", Vector3.new(0.2, 0.2, 0.1), Vector3.new(x, 1.13, -0.14), BONE)
	local lower = part(side .. "LowerLeg", Vector3.new(0.14, 0.82, 0.14), Vector3.new(x, 0.66, 0), BONE)
	motor(side .. "Knee", upper, lower, Vector3.new(x, 1.12, 0))
	deco(lower, "Fibula", Vector3.new(0.08, 0.76, 0.08), Vector3.new(x + dir * 0.09, 0.68, 0.05), BONE_SHADE)
	deco(lower, "AnkleKnob", Vector3.new(0.2, 0.12, 0.2), Vector3.new(x, 0.24, 0), BONE_SHADE)
	deco(lower, "Foot" .. side, Vector3.new(0.3, 0.16, 0.4), Vector3.new(x, 0.1, -0.02), BONE)
	deco(lower, "Metatarsus", Vector3.new(0.3, 0.1, 0.26), Vector3.new(x, 0.06, -0.33), BONE_SHADE)
	for i, o in ipairs({ -0.1, 0, 0.1 }) do
		deco(lower, "Toe", Vector3.new(0.07, 0.07, 0.13 - math.abs(o) * 0.3), Vector3.new(x + o, 0.04, -0.51 + math.abs(o) * 0.1), BONE)
	end
	return lower
end
leg("L", -0.38)
local rLower = leg("R", 0.38)
-- a dented iron greave on the right shin
deco(rLower, "Greave", Vector3.new(0.26, 0.44, 0.1), Vector3.new(0.38, 0.72, -0.11), IRON, Enum.Material.Metal)
deco(rLower, "GreaveStrap", Vector3.new(0.22, 0.06, 0.22), Vector3.new(0.38, 0.62, 0), LEATHER_DARK, Enum.Material.Leather)

model:SetAttribute("Rig", "Procedural")
model:SetAttribute("RootHeight", 2.2)
model:SetAttribute("Height", 5.0)
model:SetAttribute("AttackStyle", "Strike")
model.Parent = models

local parts, joints = 0, 0
for _, d in ipairs(model:GetDescendants()) do
	if d:IsA("BasePart") then parts += 1 end
	if d:IsA("Motor6D") then joints += 1 end
end
return "Skelly built: " .. parts .. " parts, " .. joints .. " joints"
