-- Builds the low-poly rigged Abyssal Titan into ServerStorage.Models.AbyssalTitan.
-- Run in Studio's command bar / via the Studio MCP execute_luau (Edit mode). Safe to re-run.
--
-- Same rig as the Bone Colossus (see build_bonecolossus.lua and src/client/Modules/UnitAnimator.lua): front = -Z,
-- right = +X, feet on y = 0, root part = HumanoidRootPart at y = 2.2, joints Root/Waist/Neck/Jaw/L,RShoulder/
-- L,RElbow/L,RHip/L,RKnee, attributes Rig = "Procedural", RootHeight, Height. The game scales it to its size (4).
-- A colossal brute of deep-sea obsidian: dark blue stone plates split by glowing teal cracks, coral spikes on
-- the shoulders and back, tusks, a chain draped over the left pauldron and a rusted giant anchor held in the
-- right fist (the attack swing is the anchor smash).
local ServerStorage = game:GetService("ServerStorage")
local models = ServerStorage.Models

local old = models:FindFirstChild("AbyssalTitan")
if old then
	old:Destroy()
end

local ROCK = Color3.fromRGB(32, 38, 58)
local ROCK_L = Color3.fromRGB(58, 68, 94)
local CRACK = Color3.fromRGB(70, 235, 225)
local CORAL = Color3.fromRGB(226, 112, 136)
local TUSK = Color3.fromRGB(222, 218, 200)
local RUST = Color3.fromRGB(112, 84, 60)
local CHAIN = Color3.fromRGB(122, 126, 138)
local VOID = Color3.fromRGB(8, 10, 18)
local METAL = Enum.Material.Metal

local model = Instance.new("Model")
model.Name = "AbyssalTitan"

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
local root = part("HumanoidRootPart", Vector3.new(1.8, 0.5, 1.1), Vector3.new(0, 2.2, 0), ROCK)
root.Transparency = 1
model.PrimaryPart = root

local pelvis = part("Pelvis", Vector3.new(2.0, 0.6, 1.2), Vector3.new(0, 2.2, 0), ROCK)
motor("Root", root, pelvis, Vector3.new(0, 2.2, 0))

-- torso: stone plates with glowing teal cracks and a rune
local torso = part("Torso", Vector3.new(2.5, 1.8, 1.4), Vector3.new(0, 3.3, 0), ROCK)
motor("Waist", pelvis, torso, Vector3.new(0, 2.5, 0))
for _, x in ipairs({ -0.62, 0.62 }) do
	weld(torso, part("ChestPlate", Vector3.new(1.1, 1.5, 0.22), Vector3.new(x, 3.25, -0.72), ROCK_L))
end
for i, d in ipairs({ { -0.1, 3.0, 1.2 }, { 0.15, 3.35, 0.9 }, { 0.9, 3.0, 1.1 } }) do
	weld(torso, part("Crack" .. i, Vector3.new(0.08, d[3], 0.06), Vector3.new(d[1], d[2], -0.86), CRACK, Enum.Material.Neon))
end
weld(torso, part("Rune", Vector3.new(0.5, 0.5, 0.08), Vector3.new(0, 3.7, -0.86), CRACK, Enum.Material.Neon))
weld(torso, part("BackPlate", Vector3.new(2.5, 1.8, 0.2), Vector3.new(0, 3.3, 0.7), ROCK_L))
for i, p in ipairs({ { -0.7, 3.95 }, { 0.7, 3.95 }, { -0.35, 3.3 }, { 0.35, 3.3 }, { 0, 2.8 } }) do
	weld(torso, part("BackCoral" .. i, Vector3.new(0.25, 0.7, 0.25), Vector3.new(p[1], p[2] + 0.35, 0.95), CORAL))
end

-- ── Head: a heavy head sunk between the shoulders, tusks and horns ──
local head = part("Head", Vector3.new(1.5, 1.2, 1.4), Vector3.new(0, 4.65, -0.1), ROCK_L)
motor("Neck", torso, head, Vector3.new(0, 4.2, 0))
weld(head, part("Brow", Vector3.new(1.54, 0.24, 0.3), Vector3.new(0, 5.0, -0.62), ROCK))
for _, x in ipairs({ -0.4, 0.4 }) do
	weld(head, part("EyeSocket", Vector3.new(0.44, 0.36, 0.14), Vector3.new(x, 4.78, -0.7), VOID))
	weld(head, part("EyeGlow", Vector3.new(0.22, 0.18, 0.14), Vector3.new(x, 4.78, -0.74), CRACK, Enum.Material.Neon))
end
weld(head, part("CrackHead", Vector3.new(0.08, 0.6, 0.06), Vector3.new(0.3, 5.1, -0.72), CRACK, Enum.Material.Neon))
for i, p in ipairs({ { 0, 0.9 }, { -0.55, 0.65 }, { 0.55, 0.65 } }) do
	weld(head, part("HeadSpike" .. i, Vector3.new(0.25, p[2], 0.25), Vector3.new(p[1], 5.25 + p[2] / 2, 0.1), CORAL))
end
local jaw = part("Jaw", Vector3.new(1.2, 0.4, 1.0), Vector3.new(0, 4.05, -0.25), ROCK)
motor("Jaw", head, jaw, Vector3.new(0, 4.2, 0.4))
for _, x in ipairs({ -0.5, 0.5 }) do
	weld(jaw, part("Tusk", Vector3.new(0.2, 0.7, 0.2), Vector3.new(x, 4.45, -0.7), TUSK))
end
for _, x in ipairs({ -0.2, 0.2 }) do
	weld(jaw, part("Tooth", Vector3.new(0.14, 0.22, 0.12), Vector3.new(x, 4.3, -0.72), TUSK))
end

-- ── Arms: giant pauldrons with coral, thick limbs, club fists (character's right = +X) ──
local function arm(side, x)
	local sx = x > 0 and 1 or -1
	local upper = part(side .. "UpperArm", Vector3.new(0.95, 1.25, 0.95), Vector3.new(x, 3.2, 0), ROCK)
	motor(side .. "Shoulder", torso, upper, Vector3.new(x, 3.85, 0))
	weld(upper, part(side .. "Pauldron", Vector3.new(1.4, 0.75, 1.4), Vector3.new(x, 4.0, 0), ROCK_L))
	for i, dx in ipairs({ -0.35, 0.1 }) do
		weld(upper, part(side .. "PauldronCoral" .. i, Vector3.new(0.24, 0.55 + i * 0.15, 0.24), Vector3.new(x + sx * dx, 4.65, 0), CORAL))
	end
	local fore = part(side .. "Forearm", Vector3.new(1.05, 1.3, 1.05), Vector3.new(x, 1.95, 0), ROCK_L)
	motor(side .. "Elbow", upper, fore, Vector3.new(x, 2.6, 0))
	weld(fore, part(side .. "ForearmCrack", Vector3.new(0.06, 0.8, 0.06), Vector3.new(x + sx * 0.1, 1.95, -0.54), CRACK, Enum.Material.Neon))
	local fist = part(side .. "Fist", Vector3.new(1.35, 1.0, 1.35), Vector3.new(x, 0.95, 0), ROCK)
	weld(fore, fist)
	return fore, fist, upper
end
local _, _, lUpper = arm("L", -1.85)
local _, rFist = arm("R", 1.85)

-- chain draped over the left pauldron
for i = 1, 6 do
	local flat = i % 2 == 0
	weld(lUpper, part("ChainLink" .. i, flat and Vector3.new(0.12, 0.34, 0.24) or Vector3.new(0.24, 0.34, 0.12), Vector3.new(-2.55, 3.9 - i * 0.28, 0), CHAIN, METAL))
end

-- giant rusted anchor in the right fist: shaft, ring, stock and curved flukes
-- (it towers above the shoulder so it reads from the front: shaft to y = 4.9, ring at the top)
weld(rFist, part("AnchorShaft", Vector3.new(0.3, 4.8, 0.3), Vector3.new(1.85, 2.5, -0.1), RUST, METAL))
weld(rFist, part("AnchorStock", Vector3.new(1.8, 0.28, 0.28), Vector3.new(1.85, 4.5, -0.1), RUST, METAL))
weld(rFist, part("AnchorRingTop", Vector3.new(0.6, 0.12, 0.16), Vector3.new(1.85, 5.35, -0.1), CHAIN, METAL))
for _, dx in ipairs({ -0.27, 0.27 }) do
	weld(rFist, part("AnchorRingSide", Vector3.new(0.12, 0.5, 0.16), Vector3.new(1.85 + dx, 5.1, -0.1), CHAIN, METAL))
end
weld(rFist, part("AnchorFlukeBar", Vector3.new(2.2, 0.28, 0.28), Vector3.new(1.85, 0.3, -0.1), RUST, METAL))
for _, dx in ipairs({ -1.05, 1.05 }) do
	weld(rFist, part("AnchorFluke", Vector3.new(0.28, 0.9, 0.28), Vector3.new(1.85 + dx, 0.75, -0.1), RUST, METAL))
	weld(rFist, part("AnchorTip", Vector3.new(0.5, 0.22, 0.28), Vector3.new(1.85 + dx * 1.2, 1.3, -0.1), RUST, METAL))
end

-- ── Legs: stone pillars with coral barnacles ──────────────────
local function leg(side, x)
	local upper = part(side .. "UpperLeg", Vector3.new(1.0, 1.05, 1.0), Vector3.new(x, 1.5, 0), ROCK)
	motor(side .. "Hip", pelvis, upper, Vector3.new(x, 2.0, 0))
	local lower = part(side .. "LowerLeg", Vector3.new(0.85, 0.75, 0.85), Vector3.new(x, 0.65, 0), ROCK_L)
	motor(side .. "Knee", upper, lower, Vector3.new(x, 1.0, 0))
	weld(lower, part(side .. "KneeCap", Vector3.new(0.7, 0.4, 0.3), Vector3.new(x, 1.0, -0.5), ROCK))
	weld(lower, part(side .. "Barnacle", Vector3.new(0.2, 0.3, 0.2), Vector3.new(x + 0.3, 0.7, -0.4), CORAL))
	weld(lower, part("Foot" .. side, Vector3.new(1.1, 0.3, 1.5), Vector3.new(x, 0.15, -0.25), ROCK))
end
leg("L", -0.75)
leg("R", 0.75)

-- cold teal glow from the cracks (no shadows, see CLAUDE.md)
local light = Instance.new("PointLight")
light.Name = "TitanLight"
light.Color = CRACK
light.Brightness = 0.8
light.Range = 10
light.Shadows = false
light.Parent = torso

model:SetAttribute("Rig", "Procedural")
model:SetAttribute("RootHeight", 2.2)
model:SetAttribute("Height", 6.4)
model.Parent = models

local count = 0
for _, d in ipairs(model:GetDescendants()) do
	if d:IsA("Motor6D") then count += 1 end
end
return "AbyssalTitan built: " .. #model:GetChildren() .. " parts, " .. count .. " joints"
