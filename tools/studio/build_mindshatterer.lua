-- Builds the low-poly rigged Mind Shatterer into ServerStorage.Models.MindShatterer.
-- Run in Studio's command bar / via the Studio MCP execute_luau (Edit mode). Safe to re-run.
--
-- Rig conventions (see build_skelly.lua and src/client/Modules/UnitAnimator.lua): front = -Z, root part =
-- HumanoidRootPart at y = 2.2, attributes Rig = "Procedural", RootHeight, Height, Float (hover bob).
-- Joints: Root/Waist/Neck/Jaw/L,RShoulder/L,RElbow. The tentacles around the mouth hang from the Jaw part, so
-- they writhe whenever the jaw moves (it opens on every attack).
-- A floating psychic horror: a huge exposed pink brain with glowing veins on a pale face with two blazing
-- eyes and a beard of mouth tentacles, two thin psychic rings round the head, a tapering magenta robe with
-- no legs, thin arms with long fingers and a few drifting shards.
local ServerStorage = game:GetService("ServerStorage")
local models = ServerStorage.Models

local old = models:FindFirstChild("MindShatterer")
if old then
	old:Destroy()
end

local SKIN = Color3.fromRGB(176, 164, 196)
local SKIN_D = Color3.fromRGB(128, 116, 150)
local ROBE = Color3.fromRGB(58, 22, 70)
local ROBE_D = Color3.fromRGB(32, 12, 44)
local BRAIN = Color3.fromRGB(236, 128, 176)
local BRAIN_D = Color3.fromRGB(170, 70, 130)
local NEON_C = Color3.fromRGB(255, 100, 200)
local EYE = Color3.fromRGB(255, 214, 244)
local DARK = Color3.fromRGB(14, 6, 20)
local NEON = Enum.Material.Neon

local model = Instance.new("Model")
model.Name = "MindShatterer"

local function part(name, size, cf, color, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = typeof(cf) == "Vector3" and CFrame.new(cf) or cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = false
	p.CanQuery = false
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

-- a flat ring (Cylinder part) lying horizontally
local FACE_UP = CFrame.Angles(0, 0, math.rad(90))
local function ringUp(name, diameter, thickness, pos, color, material)
	local p = part(name, Vector3.new(thickness, diameter, diameter), CFrame.new(pos) * FACE_UP, color, material)
	p.Shape = Enum.PartType.Cylinder
	return p
end

-- ── Core ──────────────────────────────────────────────────────
local root = part("HumanoidRootPart", Vector3.new(1.0, 0.4, 0.7), Vector3.new(0, 2.2, 0), ROBE)
root.Transparency = 1
model.PrimaryPart = root

local pelvis = part("Pelvis", Vector3.new(1.0, 0.4, 0.7), Vector3.new(0, 2.2, 0), ROBE_D)
motor("Root", root, pelvis, Vector3.new(0, 2.2, 0))

local torso = part("Torso", Vector3.new(1.3, 1.4, 0.8), Vector3.new(0, 3.1, 0), ROBE)
motor("Waist", pelvis, torso, Vector3.new(0, 2.4, 0))
weld(torso, part("CollarBack", Vector3.new(1.9, 1.3, 0.2), Vector3.new(0, 4.2, 0.5), ROBE_D))
weld(torso, part("CollarTrim", Vector3.new(1.4, 0.08, 0.9), Vector3.new(0, 3.82, 0), NEON_C, NEON))
-- an eye sigil on the chest
weld(torso, part("SigilEye", Vector3.new(0.5, 0.26, 0.08), Vector3.new(0, 3.3, -0.44), NEON_C, NEON))
weld(torso, part("SigilPupil", Vector3.new(0.14, 0.2, 0.1), Vector3.new(0, 3.3, -0.47), DARK))

-- robe tapering into a point (no legs: it floats)
local tiers = { { "Tier1", 1.5, 0.5, 1.95 }, { "Tier2", 1.2, 0.5, 1.45 }, { "Tier3", 0.9, 0.45, 1.0 }, { "Tier4", 0.55, 0.4, 0.62 } }
for _, t in ipairs(tiers) do
	weld(pelvis, part(t[1], Vector3.new(t[2], t[3], t[2] * 0.7), Vector3.new(0, t[4], 0), ROBE_D))
end

-- ── Head: pale face under a huge exposed brain ────────────────
local head = part("Head", Vector3.new(1.2, 1.0, 1.0), Vector3.new(0, 4.4, 0), SKIN)
motor("Neck", torso, head, Vector3.new(0, 3.8, 0))
weld(head, part("BrainMain", Vector3.new(1.6, 0.9, 1.4), Vector3.new(0, 5.2, 0.05), BRAIN))
weld(head, part("BrainTop", Vector3.new(1.0, 0.35, 1.0), Vector3.new(0, 5.75, 0.05), BRAIN))
for _, x in ipairs({ -1, 1 }) do
	weld(head, part("BrainLobe", Vector3.new(0.55, 0.7, 1.2), Vector3.new(x * 0.95, 5.05, 0.05), BRAIN_D))
end
for i, y in ipairs({ 5.0, 5.25, 5.5 }) do
	weld(head, part("BrainFold" .. i, Vector3.new(1.2, 0.1, 0.1), Vector3.new(0, y, -0.72), BRAIN_D))
end
for i, x in ipairs({ -0.5, 0, 0.5 }) do
	weld(head, part("BrainVein" .. i, Vector3.new(0.06, 0.55, 0.06), Vector3.new(x, 5.3, -0.74), NEON_C, NEON))
end
for _, x in ipairs({ -1, 1 }) do
	weld(head, part("EyeSocket", Vector3.new(0.36, 0.28, 0.1), Vector3.new(x * 0.28, 4.5, -0.52), DARK))
	weld(head, part("EyeGlow", Vector3.new(0.22, 0.16, 0.1), Vector3.new(x * 0.28, 4.5, -0.56), EYE, NEON))
end
-- the mouth tentacles hang from the jaw
local jaw = part("Jaw", Vector3.new(0.9, 0.22, 0.55), Vector3.new(0, 3.95, -0.35), SKIN_D)
motor("Jaw", head, jaw, Vector3.new(0, 4.0, 0.0))
for i, d in ipairs({ { -0.33, 0.7, 0.5 }, { -0.11, 0.8, 0.6 }, { 0.11, 0.8, 0.6 }, { 0.33, 0.7, 0.5 } }) do
	weld(jaw, part("TentacleA" .. i, Vector3.new(0.18, d[2], 0.18), Vector3.new(d[1], 3.95 - d[2] / 2, -0.45), SKIN_D))
	weld(jaw, part("TentacleB" .. i, Vector3.new(0.13, d[3], 0.13), Vector3.new(d[1] * 1.15, 3.95 - d[2] - d[3] / 2, -0.5), SKIN))
	weld(jaw, part("TentacleTip" .. i, Vector3.new(0.12, 0.12, 0.12), Vector3.new(d[1] * 1.15, 3.95 - d[2] - d[3] - 0.05, -0.5), NEON_C, NEON))
end
-- two psychic rings round the head
weld(head, ringUp("RingOuter", 3.2, 0.05, Vector3.new(0, 5.35, 0), NEON_C, NEON))
weld(head, ringUp("RingInner", 2.5, 0.05, Vector3.new(0, 4.85, 0), NEON_C, NEON))

-- ── Arms: thin, ending in long glowing fingers ────────────────
local function arm(side, x)
	local upper = part(side .. "UpperArm", Vector3.new(0.34, 1.0, 0.34), Vector3.new(x, 3.2, 0), ROBE)
	motor(side .. "Shoulder", torso, upper, Vector3.new(x, 3.7, 0))
	local fore = part(side .. "Forearm", Vector3.new(0.26, 0.95, 0.26), Vector3.new(x, 2.2, 0), SKIN_D)
	motor(side .. "Elbow", upper, fore, Vector3.new(x, 2.7, 0))
	weld(fore, part(side .. "Hand", Vector3.new(0.3, 0.3, 0.3), Vector3.new(x, 1.6, 0), SKIN))
	for _, dx in ipairs({ -0.12, -0.04, 0.04, 0.12 }) do
		weld(fore, part(side .. "Finger", Vector3.new(0.04, 0.5, 0.04), Vector3.new(x + dx, 1.25, -0.06), SKIN))
		weld(fore, part(side .. "FingerTip", Vector3.new(0.06, 0.08, 0.06), Vector3.new(x + dx, 0.98, -0.06), NEON_C, NEON))
	end
end
arm("L", -0.95)
arm("R", 0.95)

-- drifting shards
for i, p in ipairs({ { -1.6, 3.6, -0.3 }, { 1.7, 4.2, 0.2 }, { -1.3, 2.6, 0.6 }, { 1.4, 2.9, -0.5 } }) do
	weld(torso, part("Shard" .. i, Vector3.new(0.14, 0.45 + (i % 2) * 0.2, 0.14), Vector3.new(p[1], p[2], p[3]), NEON_C, NEON))
end

-- pink glow (no shadows, see CLAUDE.md)
local light = Instance.new("PointLight")
light.Name = "MindLight"
light.Color = NEON_C
light.Brightness = 0.9
light.Range = 10
light.Shadows = false
light.Parent = torso

model:SetAttribute("Rig", "Procedural")
model:SetAttribute("RootHeight", 2.2)
model:SetAttribute("Height", 6.2)
model:SetAttribute("Float", 0.25)
model.Parent = models

local count = 0
for _, d in ipairs(model:GetDescendants()) do
	if d:IsA("Motor6D") then count += 1 end
end
return "MindShatterer built: " .. #model:GetChildren() .. " parts, " .. count .. " joints"
