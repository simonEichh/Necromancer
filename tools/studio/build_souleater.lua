-- Builds the low-poly rigged Soul Eater into ServerStorage.Models.SoulEater.
-- Run in Studio's command bar / via the Studio MCP execute_luau (Edit mode). Safe to re-run.
--
-- Standard humanoid rig (see build_skelly.lua and src/client/Modules/UnitAnimator.lua): front = -Z, right = +X,
-- feet on y = 0, root part = HumanoidRootPart at y = 2.2, joints Root/Waist/Neck/Jaw/L,RShoulder/L,RElbow/
-- L,RHip/L,RKnee, attributes Rig = "Procedural", RootHeight, Height.
-- A gaunt hunched demon: grey-green skin over a visible ribcage that holds glowing green captured souls,
-- a second mouth full of teeth and green soul-fire in the belly, a horned skull-like head with a hinged jaw,
-- a spiked spine, very long arms ending in long claws and thin clawed legs.
local ServerStorage = game:GetService("ServerStorage")
local models = ServerStorage.Models

local old = models:FindFirstChild("SoulEater")
if old then
	old:Destroy()
end

local SKIN = Color3.fromRGB(78, 92, 84)
local SKIN_D = Color3.fromRGB(48, 58, 54)
local BONE = Color3.fromRGB(214, 206, 184)
local SOUL = Color3.fromRGB(120, 255, 160)
local MAW = Color3.fromRGB(14, 20, 16)

local model = Instance.new("Model")
model.Name = "SoulEater"

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
local root = part("HumanoidRootPart", Vector3.new(1.2, 0.4, 0.8), Vector3.new(0, 2.2, 0), SKIN_D)
root.Transparency = 1
model.PrimaryPart = root

local pelvis = part("Pelvis", Vector3.new(1.3, 0.45, 0.9), Vector3.new(0, 2.2, 0), SKIN_D)
motor("Root", root, pelvis, Vector3.new(0, 2.2, 0))

local torso = part("Torso", Vector3.new(1.7, 1.6, 1.0), Vector3.new(0, 3.1, 0), SKIN)
motor("Waist", pelvis, torso, Vector3.new(0, 2.4, 0))
-- ribs, with captured souls glowing inside
for i, y in ipairs({ 3.7, 3.45, 3.2 }) do
	weld(torso, part("Rib" .. i, Vector3.new(1.4, 0.1, 0.1), Vector3.new(0, y, -0.52), BONE))
end
for i, p in ipairs({ { -0.35, 3.45 }, { 0.3, 3.65 }, { 0.05, 3.28 } }) do
	weld(torso, part("Soul" .. i, Vector3.new(0.22, 0.22, 0.22), Vector3.new(p[1], p[2], -0.44), SOUL, Enum.Material.Neon))
end
-- the belly mouth: dark frame, glowing soul-fire inside and two rows of teeth
weld(torso, part("BellyMaw", Vector3.new(1.2, 0.85, 0.12), Vector3.new(0, 2.7, -0.52), MAW))
weld(torso, part("BellyFire", Vector3.new(0.95, 0.5, 0.1), Vector3.new(0, 2.7, -0.58), SOUL, Enum.Material.Neon))
for i, x in ipairs({ -0.45, -0.22, 0, 0.22, 0.45 }) do
	weld(torso, part("TopTooth" .. i, Vector3.new(0.13, 0.28, 0.1), Vector3.new(x, 2.96, -0.62), BONE))
	weld(torso, part("LowTooth" .. i, Vector3.new(0.13, 0.28, 0.1), Vector3.new(x + 0.1, 2.44, -0.62), BONE))
end
weld(torso, part("Mantle", Vector3.new(2.1, 0.5, 1.1), Vector3.new(0, 3.85, 0), SKIN_D))
for i, y in ipairs({ 3.2, 3.55, 3.9 }) do
	weld(torso, part("SpineSpike" .. i, Vector3.new(0.18, 0.5, 0.2), Vector3.new(0, y, 0.58), BONE))
end

-- ── Head: horned skull-like head, glowing green eyes, hinged jaw ──
local head = part("Head", Vector3.new(1.0, 1.05, 1.0), Vector3.new(0, 4.4, -0.2), SKIN)
motor("Neck", torso, head, Vector3.new(0, 3.8, 0))
for _, x in ipairs({ -1, 1 }) do
	weld(head, part("EyeSocket", Vector3.new(0.34, 0.26, 0.1), Vector3.new(x * 0.25, 4.5, -0.7), MAW))
	weld(head, part("EyeGlow", Vector3.new(0.2, 0.14, 0.1), Vector3.new(x * 0.25, 4.5, -0.74), SOUL, Enum.Material.Neon))
	weld(head, part("HornBase", Vector3.new(0.22, 0.5, 0.22), Vector3.new(x * 0.42, 5.0, -0.1), BONE))
	weld(head, part("HornMid", Vector3.new(0.18, 0.4, 0.18), Vector3.new(x * 0.55, 5.4, 0.1), BONE))
	weld(head, part("HornTip", Vector3.new(0.12, 0.35, 0.12), Vector3.new(x * 0.62, 5.75, 0.3), BONE))
end
weld(head, part("Nose", Vector3.new(0.16, 0.2, 0.08), Vector3.new(0, 4.3, -0.72), MAW))
local jaw = part("Jaw", Vector3.new(0.8, 0.3, 0.8), Vector3.new(0, 3.95, -0.3), SKIN_D)
motor("Jaw", head, jaw, Vector3.new(0, 4.05, 0.1))
for _, x in ipairs({ -0.28, -0.1, 0.1, 0.28 }) do
	weld(jaw, part("Fang", Vector3.new(0.1, 0.22, 0.08), Vector3.new(x, 4.1, -0.68), BONE))
end

-- ── Arms: very long, ending in long claws (character's right = +X) ──
local function arm(side, x)
	local upper = part(side .. "UpperArm", Vector3.new(0.4, 1.1, 0.4), Vector3.new(x, 3.0, 0), SKIN)
	motor(side .. "Shoulder", torso, upper, Vector3.new(x, 3.55, 0))
	local fore = part(side .. "Forearm", Vector3.new(0.36, 1.2, 0.36), Vector3.new(x, 1.85, 0), SKIN_D)
	motor(side .. "Elbow", upper, fore, Vector3.new(x, 2.45, 0))
	weld(fore, part(side .. "Hand", Vector3.new(0.4, 0.3, 0.4), Vector3.new(x, 1.1, 0), SKIN))
	for _, dx in ipairs({ -0.13, 0, 0.13 }) do
		weld(fore, part(side .. "Claw", Vector3.new(0.06, 0.6, 0.06), Vector3.new(x + dx, 0.7, -0.05), BONE))
	end
end
arm("L", -1.2)
arm("R", 1.2)

-- ── Legs: thin and clawed ──────────────────────────────────────
local function leg(side, x)
	local upper = part(side .. "UpperLeg", Vector3.new(0.5, 0.9, 0.5), Vector3.new(x, 1.55, 0), SKIN_D)
	motor(side .. "Hip", pelvis, upper, Vector3.new(x, 2.0, 0))
	local lower = part(side .. "LowerLeg", Vector3.new(0.42, 0.9, 0.42), Vector3.new(x, 0.65, 0), SKIN)
	motor(side .. "Knee", upper, lower, Vector3.new(x, 1.1, 0))
	weld(lower, part("Foot" .. side, Vector3.new(0.6, 0.2, 0.9), Vector3.new(x, 0.1, -0.2), SKIN_D))
	weld(lower, part("Toes" .. side, Vector3.new(0.5, 0.12, 0.2), Vector3.new(x, 0.08, -0.7), BONE))
end
leg("L", -0.45)
leg("R", 0.45)

-- green glow from the souls and the belly fire (no shadows, see CLAUDE.md)
local light = Instance.new("PointLight")
light.Name = "SoulLight"
light.Color = SOUL
light.Brightness = 0.9
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
return "SoulEater built: " .. #model:GetChildren() .. " parts, " .. count .. " joints"
