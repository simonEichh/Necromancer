-- Builds the low-poly rigged Bone Colossus into ServerStorage.Models.BoneColossus.
-- Run in Studio's command bar / via the Studio MCP execute_luau (Edit mode).
-- The old Creator Store model is kept as BoneColossus_Old until the new one is approved.
--
-- Same rig conventions as build_skelly.lua (see src/client/Modules/UnitAnimator.lua):
--   * front = -Z, character's right = +X, feet on y = 0, root part = HumanoidRootPart at y = 2.2
--   * Motor6Ds named Root/Waist/Neck/Jaw/LShoulder/RShoulder/LElbow/RElbow/LHip/RHip/LKnee/RKnee
--   * attributes: Rig = "Procedural", RootHeight, Height
-- A hulking heap of bone: a huge ribcage cage with a glowing soul-fire core, a skull sunk between giant
-- pauldrons (each topped with a little skull), pillar legs and club fists with knuckle spikes.
local ServerStorage = game:GetService("ServerStorage")
local models = ServerStorage.Models

local old = models:FindFirstChild("BoneColossus")
if old and old:GetAttribute("Rig") ~= "Procedural" then
	old.Name = "BoneColossus_Old"
elseif old then
	old:Destroy()
end

local BONE = Color3.fromRGB(230, 224, 206)
local BONE_SHADE = Color3.fromRGB(186, 178, 156)
local BONE_DARK = Color3.fromRGB(130, 122, 108)
local VOID = Color3.fromRGB(34, 30, 34)
local SOUL = Color3.fromRGB(110, 220, 255)

local model = Instance.new("Model")
model.Name = "BoneColossus"

local function part(name, size, pos, color, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = CFrame.new(pos)
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = false
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

-- ── Core ──────────────────────────────────────────────────────
local root = part("HumanoidRootPart", Vector3.new(1.8, 0.5, 1.1), Vector3.new(0, 2.2, 0), BONE_SHADE)
root.Transparency = 1
model.PrimaryPart = root

local pelvis = part("Pelvis", Vector3.new(2.0, 0.6, 1.2), Vector3.new(0, 2.2, 0), BONE_SHADE)
motor("Root", root, pelvis, Vector3.new(0, 2.2, 0))

-- ribcage: a dark hollow chest with a glowing soul-fire core, caged by thick ribs
local torso = part("Torso", Vector3.new(2.3, 1.7, 1.3), Vector3.new(0, 3.25, 0), VOID)
motor("Waist", pelvis, torso, Vector3.new(0, 2.5, 0))
weld(torso, part("Core", Vector3.new(0.8, 0.8, 0.6), Vector3.new(0, 3.3, -0.1), SOUL, Enum.Material.Neon))
for i, y in ipairs({ 2.65, 2.95, 3.25, 3.55, 3.85 }) do
	weld(torso, part("Rib" .. i, Vector3.new(2.4, 0.16, 0.22), Vector3.new(0, y, -0.62), BONE))
	weld(torso, part("RibL" .. i, Vector3.new(0.22, 0.16, 1.2), Vector3.new(-1.14, y, 0), BONE))
	weld(torso, part("RibR" .. i, Vector3.new(0.22, 0.16, 1.2), Vector3.new(1.14, y, 0), BONE))
end
weld(torso, part("Breastbone", Vector3.new(0.3, 1.5, 0.26), Vector3.new(0, 3.25, -0.66), BONE_SHADE))
weld(torso, part("BackPlate", Vector3.new(2.3, 1.7, 0.2), Vector3.new(0, 3.25, 0.62), BONE_SHADE))
for i, y in ipairs({ 2.8, 3.3, 3.8 }) do
	weld(torso, part("SpineSpike" .. i, Vector3.new(0.22, 0.4, 0.4), Vector3.new(0, y, 0.85), BONE))
end

-- ── Head: a huge skull sunk between the shoulders ─────────────
local head = part("Head", Vector3.new(1.5, 1.2, 1.4), Vector3.new(0, 4.6, -0.1), BONE)
motor("Neck", torso, head, Vector3.new(0, 4.1, 0))
weld(head, part("Brow", Vector3.new(1.54, 0.22, 0.3), Vector3.new(0, 4.95, -0.62), BONE_SHADE))
for _, x in ipairs({ -0.38, 0.38 }) do
	weld(head, part("EyeSocket", Vector3.new(0.46, 0.4, 0.14), Vector3.new(x, 4.72, -0.68), VOID))
	weld(head, part("EyeGlow", Vector3.new(0.22, 0.2, 0.14), Vector3.new(x, 4.72, -0.72), SOUL, Enum.Material.Neon))
end
weld(head, part("Nose", Vector3.new(0.2, 0.26, 0.1), Vector3.new(0, 4.4, -0.7), VOID))
weld(head, part("Crack", Vector3.new(0.1, 0.5, 0.06), Vector3.new(0.45, 5.05, -0.72), BONE_DARK))
local jaw = part("Jaw", Vector3.new(1.2, 0.4, 1.0), Vector3.new(0, 4.0, -0.2), BONE_SHADE)
motor("Jaw", head, jaw, Vector3.new(0, 4.15, 0.4))
for _, x in ipairs({ -0.45, -0.15, 0.15, 0.45 }) do
	weld(jaw, part("Tooth", Vector3.new(0.16, 0.26, 0.12), Vector3.new(x, 4.25, -0.66), BONE))
end

-- ── Arms: giant pauldrons, thick limbs, club fists (character's right = +X) ──
local function arm(side, x)
	local sx = x > 0 and 1 or -1
	local upper = part(side .. "UpperArm", Vector3.new(0.9, 1.25, 0.9), Vector3.new(x, 3.2, 0), BONE)
	motor(side .. "Shoulder", torso, upper, Vector3.new(x, 3.85, 0))
	weld(upper, part(side .. "Pauldron", Vector3.new(1.3, 0.7, 1.3), Vector3.new(x, 3.95, 0), BONE_SHADE))
	-- a little skull on each pauldron
	weld(upper, part(side .. "PauldronSkull", Vector3.new(0.5, 0.45, 0.45), Vector3.new(x + sx * 0.1, 4.55, 0), BONE))
	for _, dx in ipairs({ -0.12, 0.12 }) do
		weld(upper, part(side .. "SkullEye", Vector3.new(0.12, 0.12, 0.06), Vector3.new(x + sx * 0.1 + dx, 4.58, -0.25), VOID))
	end
	local fore = part(side .. "Forearm", Vector3.new(1.0, 1.3, 1.0), Vector3.new(x, 1.95, 0), BONE_SHADE)
	motor(side .. "Elbow", upper, fore, Vector3.new(x, 2.6, 0))
	weld(fore, part(side .. "ElbowBand", Vector3.new(1.08, 0.2, 1.08), Vector3.new(x, 2.55, 0), BONE_DARK))
	local fist = part(side .. "Fist", Vector3.new(1.35, 1.0, 1.35), Vector3.new(x, 0.95, 0), BONE)
	weld(fore, fist)
	for _, dx in ipairs({ -0.4, 0, 0.4 }) do
		weld(fore, part(side .. "Knuckle", Vector3.new(0.22, 0.22, 0.4), Vector3.new(x + dx, 0.95, -0.8), BONE_DARK))
	end
end
arm("L", -1.75)
arm("R", 1.75)

-- ── Legs: pillars with a knee cap and wide feet ───────────────
local function leg(side, x)
	local upper = part(side .. "UpperLeg", Vector3.new(1.0, 1.05, 1.0), Vector3.new(x, 1.5, 0), BONE)
	motor(side .. "Hip", pelvis, upper, Vector3.new(x, 2.0, 0))
	local lower = part(side .. "LowerLeg", Vector3.new(0.85, 0.75, 0.85), Vector3.new(x, 0.65, 0), BONE_SHADE)
	motor(side .. "Knee", upper, lower, Vector3.new(x, 1.0, 0))
	weld(lower, part(side .. "KneeCap", Vector3.new(0.7, 0.4, 0.3), Vector3.new(x, 1.0, -0.5), BONE_DARK))
	weld(lower, part("Foot" .. side, Vector3.new(1.1, 0.3, 1.5), Vector3.new(x, 0.15, -0.25), BONE))
end
leg("L", -0.75)
leg("R", 0.75)

-- cold glow from the soul-fire (no shadows, see CLAUDE.md)
local light = Instance.new("PointLight")
light.Name = "CoreLight"
light.Color = SOUL
light.Brightness = 0.8
light.Range = 10
light.Shadows = false
light.Parent = torso

model:SetAttribute("Rig", "Procedural")
model:SetAttribute("RootHeight", 2.2)
model:SetAttribute("Height", 5.3)
model.Parent = models

local count = 0
for _, d in ipairs(model:GetDescendants()) do
	if d:IsA("Motor6D") then count += 1 end
end
return "BoneColossus built: " .. #model:GetChildren() .. " parts, " .. count .. " joints"
