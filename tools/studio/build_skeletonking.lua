-- Builds the low-poly rigged Skeleton King into ServerStorage.Models.SkeletonKing.
-- Run in Studio's command bar / via the Studio MCP execute_luau (Edit mode).
-- The old Creator Store model is kept as SkeletonKing_Old until the new one is approved.
--
-- Same rig conventions as build_skelly.lua (see src/client/Modules/UnitAnimator.lua):
--   * front = -Z, character's right = +X, feet on y = 0, root part = HumanoidRootPart at y = 2.2
--   * Motor6Ds named Root/Waist/Neck/Jaw/LShoulder/RShoulder/LElbow/RElbow/LHip/RHip/LKnee/RKnee
--   * attributes: Rig = "Procedural", RootHeight, Height
-- A bulkier, regal Skelly: golden plate armour (breastplate, spiked pauldrons, vambraces, greaves,
-- boots), a gem-studded crown, an ermine mantle and crimson cape, a kite shield on the left arm and a
-- golden greatsword in the right (the attack swing is the overhead strike).
local ServerStorage = game:GetService("ServerStorage")
local models = ServerStorage.Models

local old = models:FindFirstChild("SkeletonKing")
if old and old:GetAttribute("Rig") ~= "Procedural" then
	old.Name = "SkeletonKing_Old"
elseif old then
	old:Destroy()
end

local BONE = Color3.fromRGB(224, 216, 194)
local BONE_SHADE = Color3.fromRGB(176, 168, 148)
local DARK = Color3.fromRGB(46, 42, 44)
local GOLD = Color3.fromRGB(232, 190, 70)
local GOLD_DARK = Color3.fromRGB(170, 126, 38)
local CRIMSON = Color3.fromRGB(122, 22, 46)
local ERMINE = Color3.fromRGB(242, 238, 228)
local EYE = Color3.fromRGB(255, 190, 60)
local RUBY = Color3.fromRGB(255, 60, 70)
local SAPPHIRE = Color3.fromRGB(90, 160, 255)
local STEEL = Color3.fromRGB(176, 184, 196)
local LEATHER = Color3.fromRGB(86, 60, 46)
local METAL = Enum.Material.Metal

local model = Instance.new("Model")
model.Name = "SkeletonKing"

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
local root = part("HumanoidRootPart", Vector3.new(1.6, 0.5, 1.0), Vector3.new(0, 2.2, 0), BONE_SHADE)
root.Transparency = 1
model.PrimaryPart = root

local pelvis = part("Pelvis", Vector3.new(1.7, 0.5, 1.0), Vector3.new(0, 2.2, 0), BONE_SHADE)
motor("Root", root, pelvis, Vector3.new(0, 2.2, 0))
-- belt, buckle and tassets (armour skirt plates)
weld(pelvis, part("Belt", Vector3.new(1.8, 0.2, 1.1), Vector3.new(0, 2.4, 0), LEATHER))
weld(pelvis, part("BeltBuckle", Vector3.new(0.4, 0.28, 0.08), Vector3.new(0, 2.4, -0.56), GOLD, METAL))
weld(pelvis, part("TassetFront", Vector3.new(1.3, 0.8, 0.14), Vector3.new(0, 1.9, -0.58), GOLD_DARK, METAL))
weld(pelvis, part("TassetBack", Vector3.new(1.3, 0.8, 0.14), Vector3.new(0, 1.9, 0.58), GOLD_DARK, METAL))

-- torso: dark ribcage under a golden breastplate with a ruby
local torso = part("Torso", Vector3.new(1.9, 1.4, 1.0), Vector3.new(0, 3.1, 0), DARK)
motor("Waist", pelvis, torso, Vector3.new(0, 2.4, 0))
weld(torso, part("Breastplate", Vector3.new(1.8, 1.15, 0.22), Vector3.new(0, 3.15, -0.58), GOLD, METAL))
weld(torso, part("BreastRidge", Vector3.new(0.18, 1.1, 0.12), Vector3.new(0, 3.15, -0.7), GOLD_DARK, METAL))
weld(torso, part("Ruby", Vector3.new(0.3, 0.3, 0.1), Vector3.new(0, 3.5, -0.74), RUBY, Enum.Material.Neon))
weld(torso, part("BackPlate", Vector3.new(1.8, 1.15, 0.18), Vector3.new(0, 3.15, 0.56), GOLD_DARK, METAL))
weld(torso, part("Gorget", Vector3.new(1.5, 0.22, 1.1), Vector3.new(0, 3.75, 0), GOLD, METAL))
-- ermine mantle over the shoulders and a crimson cape down the back
weld(torso, part("Mantle", Vector3.new(2.5, 0.38, 1.3), Vector3.new(0, 3.9, 0), ERMINE))
for i, x in ipairs({ -0.9, -0.3, 0.3, 0.9 }) do
	weld(torso, part("MantleSpot" .. i, Vector3.new(0.2, 0.08, 0.2), Vector3.new(x, 4.1, -0.45), DARK))
end
weld(torso, part("Cape", Vector3.new(1.9, 2.5, 0.12), Vector3.new(0, 2.5, 0.78), CRIMSON))
weld(torso, part("CapeTrim", Vector3.new(1.96, 0.16, 0.16), Vector3.new(0, 1.3, 0.78), GOLD, METAL))

-- ── Head: skull, glowing amber eyes, jewelled crown ───────────
local head = part("Head", Vector3.new(1.25, 1.2, 1.2), Vector3.new(0, 4.5, 0), BONE)
motor("Neck", torso, head, Vector3.new(0, 3.85, 0))
for _, x in ipairs({ -0.3, 0.3 }) do
	weld(head, part("EyeSocket", Vector3.new(0.34, 0.34, 0.1), Vector3.new(x, 4.55, -0.61), DARK))
	weld(head, part("EyeGlow", Vector3.new(0.18, 0.18, 0.1), Vector3.new(x, 4.55, -0.65), EYE, Enum.Material.Neon))
end
weld(head, part("Nose", Vector3.new(0.14, 0.22, 0.08), Vector3.new(0, 4.3, -0.62), DARK))
local jaw = part("Jaw", Vector3.new(1.0, 0.3, 0.9), Vector3.new(0, 3.98, -0.1), BONE_SHADE)
motor("Jaw", head, jaw, Vector3.new(0, 4.05, 0.35))
for _, x in ipairs({ -0.3, 0, 0.3 }) do
	weld(jaw, part("Tooth", Vector3.new(0.14, 0.14, 0.06), Vector3.new(x, 4.12, -0.56), BONE))
end
weld(head, part("CrownBase", Vector3.new(1.4, 0.3, 1.4), Vector3.new(0, 5.2, 0), GOLD, METAL))
weld(head, part("CrownRim", Vector3.new(1.46, 0.1, 1.46), Vector3.new(0, 5.02, 0), GOLD_DARK, METAL))
local spikes = {
	{ 0, -0.6, 0.65 }, { -0.6, 0, 0.5 }, { 0.6, 0, 0.5 }, { -0.4, 0.55, 0.45 }, { 0.4, 0.55, 0.45 }, { 0, 0.6, 0.4 },
}
for i, s in ipairs(spikes) do
	weld(head, part("CrownSpike" .. i, Vector3.new(0.2, s[3], 0.2), Vector3.new(s[1], 5.35 + s[3] / 2, s[2]), GOLD, METAL))
end
weld(head, part("CrownGemFront", Vector3.new(0.24, 0.24, 0.12), Vector3.new(0, 5.2, -0.72), RUBY, Enum.Material.Neon))
weld(head, part("CrownGemL", Vector3.new(0.14, 0.2, 0.14), Vector3.new(-0.6, 5.5, 0), SAPPHIRE, Enum.Material.Neon))
weld(head, part("CrownGemR", Vector3.new(0.14, 0.2, 0.14), Vector3.new(0.6, 5.5, 0), SAPPHIRE, Enum.Material.Neon))

-- ── Arms: golden pauldrons and vambraces (character's right = +X) ──
local function arm(side, x)
	local sx = x > 0 and 1 or -1
	local upper = part(side .. "UpperArm", Vector3.new(0.55, 0.95, 0.55), Vector3.new(x, 3.05, 0), BONE)
	motor(side .. "Shoulder", torso, upper, Vector3.new(x, 3.6, 0))
	weld(upper, part(side .. "Pauldron", Vector3.new(0.95, 0.45, 0.95), Vector3.new(x, 3.62, 0), GOLD, METAL))
	weld(upper, part(side .. "PauldronSpike", Vector3.new(0.18, 0.45, 0.18), Vector3.new(x + sx * 0.12, 4.05, 0), GOLD_DARK, METAL))
	local fore = part(side .. "Forearm", Vector3.new(0.48, 0.9, 0.48), Vector3.new(x, 2.15, 0), BONE_SHADE)
	motor(side .. "Elbow", upper, fore, Vector3.new(x, 2.6, 0))
	weld(fore, part(side .. "Vambrace", Vector3.new(0.6, 0.6, 0.6), Vector3.new(x, 2.0, 0), GOLD_DARK, METAL))
	local gauntlet = part(side .. "Gauntlet", Vector3.new(0.55, 0.4, 0.55), Vector3.new(x, 1.55, 0), GOLD, METAL)
	weld(fore, gauntlet)
	return fore, gauntlet
end
local lFore = arm("L", -1.2)
local _, rHand = arm("R", 1.2)

-- kite shield on the left forearm, crimson with a gold rim and a skull-and-crown emblem
weld(lFore, part("ShieldBody", Vector3.new(0.14, 1.5, 1.05), Vector3.new(-1.66, 2.2, 0), CRIMSON))
weld(lFore, part("ShieldRimTop", Vector3.new(0.2, 0.12, 1.15), Vector3.new(-1.66, 2.98, 0), GOLD, METAL))
weld(lFore, part("ShieldRimBottom", Vector3.new(0.2, 0.12, 0.5), Vector3.new(-1.66, 1.38, 0), GOLD, METAL))
weld(lFore, part("ShieldRimFront", Vector3.new(0.2, 1.5, 0.1), Vector3.new(-1.66, 2.2, -0.56), GOLD, METAL))
weld(lFore, part("ShieldRimBack", Vector3.new(0.2, 1.5, 0.1), Vector3.new(-1.66, 2.2, 0.56), GOLD, METAL))
weld(lFore, part("ShieldEmblem", Vector3.new(0.08, 0.4, 0.4), Vector3.new(-1.75, 2.35, 0), BONE))
weld(lFore, part("ShieldCrown", Vector3.new(0.08, 0.16, 0.5), Vector3.new(-1.75, 2.66, 0), GOLD, METAL))

-- golden greatsword in the right hand, blade pointing down and slightly forward
weld(rHand, part("SwordGrip", Vector3.new(0.14, 0.14, 0.5), Vector3.new(1.2, 1.55, -0.05), LEATHER))
weld(rHand, part("SwordGuard", Vector3.new(0.9, 0.14, 0.2), Vector3.new(1.2, 1.4, -0.05), GOLD, METAL))
weld(rHand, part("SwordGem", Vector3.new(0.2, 0.2, 0.12), Vector3.new(1.2, 1.4, -0.18), RUBY, Enum.Material.Neon))
weld(rHand, part("SwordBlade", Vector3.new(0.3, 1.5, 0.12), Vector3.new(1.2, 0.63, -0.05), STEEL, METAL))
weld(rHand, part("SwordFuller", Vector3.new(0.08, 1.3, 0.14), Vector3.new(1.2, 0.68, -0.05), GOLD_DARK, METAL))

-- ── Legs: armoured thighs, greaves and boots ───────────────────
local function leg(side, x)
	local upper = part(side .. "UpperLeg", Vector3.new(0.6, 0.9, 0.6), Vector3.new(x, 1.55, 0), BONE)
	motor(side .. "Hip", pelvis, upper, Vector3.new(x, 2.0, 0))
	weld(upper, part(side .. "Cuisse", Vector3.new(0.72, 0.55, 0.72), Vector3.new(x, 1.7, 0), GOLD_DARK, METAL))
	local lower = part(side .. "LowerLeg", Vector3.new(0.52, 0.9, 0.52), Vector3.new(x, 0.65, 0), BONE_SHADE)
	motor(side .. "Knee", upper, lower, Vector3.new(x, 1.1, 0))
	weld(lower, part(side .. "KneeCap", Vector3.new(0.58, 0.32, 0.3), Vector3.new(x, 1.08, -0.3), GOLD, METAL))
	weld(lower, part(side .. "Greave", Vector3.new(0.64, 0.55, 0.64), Vector3.new(x, 0.62, 0), GOLD_DARK, METAL))
	weld(lower, part("Boot" .. side, Vector3.new(0.78, 0.3, 1.1), Vector3.new(x, 0.15, -0.2), GOLD, METAL))
end
leg("L", -0.55)
leg("R", 0.55)

-- warm glow from the crown and eyes (no shadows, see CLAUDE.md)
local light = Instance.new("PointLight")
light.Name = "KingLight"
light.Color = Color3.fromRGB(255, 200, 110)
light.Brightness = 0.8
light.Range = 10
light.Shadows = false
light.Parent = torso

model:SetAttribute("Rig", "Procedural")
model:SetAttribute("RootHeight", 2.2)
model:SetAttribute("Height", 6.0)
model.Parent = models

local count = 0
for _, d in ipairs(model:GetDescendants()) do
	if d:IsA("Motor6D") then count += 1 end
end
return "SkeletonKing built: " .. #model:GetChildren() .. " parts, " .. count .. " joints"
