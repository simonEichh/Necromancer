-- Builds the low-poly rigged Lich Lord into ServerStorage.Models.LichLord.
-- Run in Studio's command bar / via the Studio MCP execute_luau (Edit mode). Safe to re-run.
--
-- Standard humanoid rig (see build_skelly.lua and src/client/Modules/UnitAnimator.lua): front = -Z, right = +X,
-- feet on y = 0, root part = HumanoidRootPart at y = 2.2, joints Root/Waist/Neck/Jaw/L,RShoulder/L,RElbow/
-- L,RHip/L,RKnee, attributes Rig = "Procedural", RootHeight, Height.
-- The Lich Acolyte's master: a skull wearing a crown of bone spikes tipped with violet flames, a tall
-- spiked bone collar, a layered black-violet robe with a bone-ribbed chest and a glowing phylactery at the
-- belt, two floating familiar skulls, a spell tome hovering at the left hand and a tall staff with a glowing
-- orb in the right (the attack swing is the cast). The robe is split into flaps welded to the legs.
local ServerStorage = game:GetService("ServerStorage")
local models = ServerStorage.Models

local old = models:FindFirstChild("LichLord")
if old then
	old:Destroy()
end

local ROBE = Color3.fromRGB(44, 26, 72)
local ROBE_DARK = Color3.fromRGB(24, 14, 42)
local BONE = Color3.fromRGB(224, 216, 194)
local BONE_SHADE = Color3.fromRGB(176, 168, 148)
local VIOLET = Color3.fromRGB(172, 104, 255)
local GOLD = Color3.fromRGB(222, 180, 80)
local WOOD = Color3.fromRGB(66, 50, 44)
local HOLLOW = Color3.fromRGB(20, 12, 32)

local model = Instance.new("Model")
model.Name = "LichLord"

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
local root = part("HumanoidRootPart", Vector3.new(1.4, 0.4, 0.9), Vector3.new(0, 2.2, 0), ROBE)
root.Transparency = 1
model.PrimaryPart = root

local pelvis = part("Pelvis", Vector3.new(1.5, 0.4, 0.95), Vector3.new(0, 2.2, 0), ROBE_DARK)
motor("Root", root, pelvis, Vector3.new(0, 2.2, 0))

local torso = part("Torso", Vector3.new(1.7, 1.4, 1.0), Vector3.new(0, 3.1, 0), ROBE)
motor("Waist", pelvis, torso, Vector3.new(0, 2.4, 0))
weld(torso, part("Mantle", Vector3.new(2.25, 0.35, 1.25), Vector3.new(0, 3.8, 0), ROBE_DARK))
weld(torso, part("MantleTrim", Vector3.new(2.3, 0.08, 1.3), Vector3.new(0, 3.62, 0), VIOLET, Enum.Material.Neon))
for i, y in ipairs({ 3.5, 3.25, 3.0 }) do
	weld(torso, part("Rib" .. i, Vector3.new(1.0, 0.1, 0.08), Vector3.new(0, y, -0.54), BONE))
end
weld(torso, part("Sash", Vector3.new(1.78, 0.2, 1.08), Vector3.new(0, 2.5, 0), ROBE_DARK))
-- phylactery: a glowing violet gem in a bone frame at the belt
weld(torso, part("PhylacteryFrame", Vector3.new(0.42, 0.52, 0.12), Vector3.new(0, 2.5, -0.58), BONE))
weld(torso, part("Phylactery", Vector3.new(0.26, 0.36, 0.1), Vector3.new(0, 2.5, -0.65), VIOLET, Enum.Material.Neon))

-- tall spiked bone collar behind the head
weld(torso, part("CollarBack", Vector3.new(1.9, 1.3, 0.2), Vector3.new(0, 4.35, 0.7), ROBE_DARK))
for i, x in ipairs({ -0.8, -0.4, 0, 0.4, 0.8 }) do
	weld(torso, part("CollarSpike" .. i, Vector3.new(0.16, 0.55 - math.abs(x) * 0.25, 0.16), Vector3.new(x, 5.25 + (0.55 - math.abs(x) * 0.25) / 2 - 0.2, 0.7), BONE))
end

-- ── Head: skull with a crown of bone spikes and violet flames ──
local head = part("Head", Vector3.new(1.05, 1.1, 1.0), Vector3.new(0, 4.5, 0), BONE)
motor("Neck", torso, head, Vector3.new(0, 3.85, 0))
for _, x in ipairs({ -0.27, 0.27 }) do
	weld(head, part("EyeSocket", Vector3.new(0.3, 0.32, 0.1), Vector3.new(x, 4.58, -0.5), HOLLOW))
	weld(head, part("EyeGlow", Vector3.new(0.16, 0.16, 0.1), Vector3.new(x, 4.58, -0.54), VIOLET, Enum.Material.Neon))
end
weld(head, part("NoseHole", Vector3.new(0.12, 0.2, 0.08), Vector3.new(0, 4.35, -0.51), HOLLOW))
local jaw = part("Jaw", Vector3.new(0.85, 0.28, 0.75), Vector3.new(0, 4.0, -0.08), BONE_SHADE)
motor("Jaw", head, jaw, Vector3.new(0, 4.08, 0.3))
weld(head, part("CrownBand", Vector3.new(1.2, 0.2, 1.15), Vector3.new(0, 5.12, 0), BONE_SHADE))
local spikes = { { 0, 0.55, 0.7 }, { -0.5, 0, 0.55 }, { 0.5, 0, 0.55 }, { 0, -0.5, 0.5 }, { -0.35, 0.4, 0.45 }, { 0.35, 0.4, 0.45 } }
for i, s in ipairs(spikes) do
	weld(head, part("CrownSpike" .. i, Vector3.new(0.16, s[3], 0.16), Vector3.new(s[1], 5.2 + s[3] / 2, s[2]), BONE))
	weld(head, part("CrownFlame" .. i, Vector3.new(0.2, 0.3, 0.2), Vector3.new(s[1], 5.2 + s[3] + 0.2, s[2]), VIOLET, Enum.Material.Neon))
end

-- ── Arms: wide sleeves, bone cuffs and hands ──────────────────
local function arm(side, x)
	local upper = part(side .. "UpperArm", Vector3.new(0.5, 0.95, 0.5), Vector3.new(x, 3.075, 0), ROBE)
	motor(side .. "Shoulder", torso, upper, Vector3.new(x, 3.6, 0))
	local fore = part(side .. "Forearm", Vector3.new(0.62, 0.9, 0.62), Vector3.new(x, 2.15, 0), ROBE_DARK)
	motor(side .. "Elbow", upper, fore, Vector3.new(x, 2.6, 0))
	weld(fore, part(side .. "Cuff", Vector3.new(0.7, 0.14, 0.7), Vector3.new(x, 1.8, 0), BONE))
	local hand = part(side .. "Hand", Vector3.new(0.3, 0.3, 0.3), Vector3.new(x, 1.6, 0), BONE)
	weld(fore, hand)
	return hand
end
local lHand = arm("L", -1.1)
local rHand = arm("R", 1.1)

-- staff in the right hand: shaft, gold ring, two bone prongs holding a big glowing orb
weld(rHand, part("StaffShaft", Vector3.new(0.16, 4.0, 0.16), Vector3.new(1.1, 2.0, -0.05), WOOD))
weld(rHand, part("StaffRing", Vector3.new(0.5, 0.12, 0.5), Vector3.new(1.1, 4.0, -0.05), GOLD, Enum.Material.Metal))
for _, dx in ipairs({ -0.26, 0.26 }) do
	weld(rHand, part("StaffProng", Vector3.new(0.14, 0.8, 0.14), Vector3.new(1.1 + dx, 4.45, -0.05), BONE))
end
weld(rHand, part("StaffOrb", Vector3.new(0.6, 0.6, 0.6), Vector3.new(1.1, 4.6, -0.05), VIOLET, Enum.Material.Neon))

-- spell tome hovering at the left hand
weld(lHand, part("TomeCover", Vector3.new(0.62, 0.14, 0.82), Vector3.new(-1.1, 1.2, -0.35), ROBE_DARK))
weld(lHand, part("TomePages", Vector3.new(0.52, 0.1, 0.72), Vector3.new(-1.1, 1.27, -0.35), BONE))
weld(lHand, part("TomeRune", Vector3.new(0.22, 0.04, 0.22), Vector3.new(-1.1, 1.34, -0.35), VIOLET, Enum.Material.Neon))

-- two floating familiar skulls behind the shoulders
for _, x in ipairs({ -1, 1 }) do
	weld(torso, part("FamiliarSkull", Vector3.new(0.5, 0.5, 0.46), Vector3.new(x * 1.5, 4.7, 0.5), BONE))
	for _, dx in ipairs({ -0.12, 0.12 }) do
		weld(torso, part("FamiliarEye", Vector3.new(0.12, 0.12, 0.06), Vector3.new(x * 1.5 + dx, 4.75, 0.24), VIOLET, Enum.Material.Neon))
	end
end

-- ── Legs: robe flaps follow the stride ─────────────────────────
local function leg(side, x)
	local upper = part(side .. "UpperLeg", Vector3.new(0.75, 0.9, 0.95), Vector3.new(x, 1.55, 0), ROBE)
	motor(side .. "Hip", pelvis, upper, Vector3.new(x, 2.0, 0))
	local lower = part(side .. "LowerLeg", Vector3.new(0.7, 0.8, 0.9), Vector3.new(x, 0.7, 0), ROBE_DARK)
	motor(side .. "Knee", upper, lower, Vector3.new(x, 1.1, 0))
	weld(lower, part("Hem" .. side, Vector3.new(0.74, 0.1, 0.94), Vector3.new(x, 0.32, 0), VIOLET, Enum.Material.Neon))
	weld(lower, part("Boot" .. side, Vector3.new(0.5, 0.25, 0.8), Vector3.new(x, 0.12, -0.2), BONE_SHADE))
end
leg("L", -0.42)
leg("R", 0.42)

-- violet glow from the flames and orb (no shadows, see CLAUDE.md)
local light = Instance.new("PointLight")
light.Name = "LordLight"
light.Color = VIOLET
light.Brightness = 0.9
light.Range = 10
light.Shadows = false
light.Parent = torso

model:SetAttribute("Rig", "Procedural")
model:SetAttribute("RootHeight", 2.2)
model:SetAttribute("Height", 6.2)
model.Parent = models

local count = 0
for _, d in ipairs(model:GetDescendants()) do
	if d:IsA("Motor6D") then count += 1 end
end
return "LichLord built: " .. #model:GetChildren() .. " parts, " .. count .. " joints"
