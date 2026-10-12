-- Builds the low-poly rigged Void Walker into ServerStorage.Models.VoidWalker.
-- Run in Studio's command bar / via the Studio MCP execute_luau (Edit mode). Safe to re-run.
--
-- Standard humanoid rig (see build_skelly.lua and src/client/Modules/UnitAnimator.lua): front = -Z, right = +X,
-- feet on y = 0, root part = HumanoidRootPart at y = 2.2, joints Root/Waist/Neck/L,RShoulder/L,RElbow/L,RHip/
-- L,RKnee, attributes Rig = "Procedural", RootHeight, Height.
-- A lanky figure of living void: near-black body with glowing violet veins, a tear in reality (a glowing ring
-- around a black disc) in the chest, slit eyes, a floating halo, very long arms with glowing claws and a few
-- drifting crystal shards around the shoulders. The body is opaque (translucent parts overlap badly).
local ServerStorage = game:GetService("ServerStorage")
local models = ServerStorage.Models

local old = models:FindFirstChild("VoidWalker")
if old then
	old:Destroy()
end

local VOID = Color3.fromRGB(14, 9, 26)
local VOID_L = Color3.fromRGB(38, 22, 66)
local NEON = Color3.fromRGB(206, 90, 255)
local EYE = Color3.fromRGB(246, 214, 255)

local model = Instance.new("Model")
model.Name = "VoidWalker"

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

-- a flat disc (Cylinder part) facing the front (-Z); diameter and thickness in studs
local FACE_FRONT = CFrame.Angles(0, math.rad(90), 0)
local function discFront(name, diameter, thickness, pos, color, material)
	local p = part(name, Vector3.new(thickness, diameter, diameter), CFrame.new(pos) * FACE_FRONT, color, material)
	p.Shape = Enum.PartType.Cylinder
	return p
end
-- a flat disc facing up (a halo)
local FACE_UP = CFrame.Angles(0, 0, math.rad(90))
local function discUp(name, diameter, thickness, pos, color, material)
	local p = part(name, Vector3.new(thickness, diameter, diameter), CFrame.new(pos) * FACE_UP, color, material)
	p.Shape = Enum.PartType.Cylinder
	return p
end

-- ── Core ──────────────────────────────────────────────────────
local root = part("HumanoidRootPart", Vector3.new(1.0, 0.4, 0.6), Vector3.new(0, 2.2, 0), VOID)
root.Transparency = 1
model.PrimaryPart = root

local pelvis = part("Pelvis", Vector3.new(1.0, 0.4, 0.6), Vector3.new(0, 2.2, 0), VOID_L)
motor("Root", root, pelvis, Vector3.new(0, 2.2, 0))

local torso = part("Torso", Vector3.new(1.15, 1.5, 0.7), Vector3.new(0, 3.2, 0), VOID)
motor("Waist", pelvis, torso, Vector3.new(0, 2.45, 0))
-- the tear in the chest: a glowing ring around a black disc, plus glowing veins
local ring = discFront("RiftRing", 0.95, 0.1, Vector3.new(0, 3.3, -0.38), NEON, Enum.Material.Neon)
weld(torso, ring)
local rift = discFront("RiftCore", 0.62, 0.12, Vector3.new(0, 3.3, -0.4), Color3.fromRGB(2, 0, 6))
weld(torso, rift)
for _, x in ipairs({ -0.3, 0.3 }) do
	weld(torso, part("Vein", Vector3.new(0.06, 1.1, 0.04), Vector3.new(x, 3.1, -0.36), NEON, Enum.Material.Neon))
end
weld(torso, part("Collar", Vector3.new(1.4, 0.2, 0.9), Vector3.new(0, 3.9, 0), VOID_L))

-- ── Head: elongated, slit eyes, three spikes and a floating halo ──
local head = part("Head", Vector3.new(0.85, 1.2, 0.8), Vector3.new(0, 4.7, 0), VOID)
motor("Neck", torso, head, Vector3.new(0, 4.0, 0))
for _, x in ipairs({ -0.2, 0.2 }) do
	weld(head, part("Eye", Vector3.new(0.3, 0.1, 0.1), Vector3.new(x, 4.85, -0.42), EYE, Enum.Material.Neon))
end
for i, d in ipairs({ { -0.28, 0.8 }, { 0, 1.0 }, { 0.28, 0.8 } }) do
	weld(head, part("Spike" .. i, Vector3.new(0.1, d[2], 0.1), Vector3.new(d[1], 5.3 + d[2] / 2, 0.1), VOID_L))
end
local halo = discUp("Halo", 1.3, 0.08, Vector3.new(0, 6.5, 0), NEON, Enum.Material.Neon)
weld(head, halo)

-- ── Arms: very long and thin, with glowing claws ──────────────
local function arm(side, x)
	local upper = part(side .. "UpperArm", Vector3.new(0.28, 1.2, 0.28), Vector3.new(x, 3.25, 0), VOID_L)
	motor(side .. "Shoulder", torso, upper, Vector3.new(x, 3.85, 0))
	local fore = part(side .. "Forearm", Vector3.new(0.24, 1.2, 0.24), Vector3.new(x, 2.05, 0), VOID)
	motor(side .. "Elbow", upper, fore, Vector3.new(x, 2.65, 0))
	weld(fore, part(side .. "Hand", Vector3.new(0.3, 0.3, 0.3), Vector3.new(x, 1.3, 0), VOID_L))
	for _, dx in ipairs({ -0.1, 0, 0.1 }) do
		weld(fore, part(side .. "Claw", Vector3.new(0.05, 0.5, 0.05), Vector3.new(x + dx, 0.9, -0.05), NEON, Enum.Material.Neon))
	end
end
arm("L", -0.85)
arm("R", 0.85)

-- drifting crystal shards around the shoulders
for i, p in ipairs({ { -1.5, 4.5, -0.2 }, { 1.5, 4.8, 0.2 }, { -1.3, 3.3, 0.6 }, { 1.4, 3.0, -0.5 }, { 0, 5.9, 0.9 } }) do
	weld(torso, part("Shard" .. i, Vector3.new(0.16, 0.5 + (i % 2) * 0.2, 0.16), Vector3.new(p[1], p[2], p[3]), NEON, Enum.Material.Neon))
end

-- ── Legs: long and thin ───────────────────────────────────────
local function leg(side, x)
	local upper = part(side .. "UpperLeg", Vector3.new(0.34, 0.95, 0.34), Vector3.new(x, 1.525, 0), VOID)
	motor(side .. "Hip", pelvis, upper, Vector3.new(x, 2.0, 0))
	local lower = part(side .. "LowerLeg", Vector3.new(0.3, 0.95, 0.3), Vector3.new(x, 0.575, 0), VOID_L)
	motor(side .. "Knee", upper, lower, Vector3.new(x, 1.05, 0))
	weld(lower, part("Foot" .. side, Vector3.new(0.4, 0.2, 0.75), Vector3.new(x, 0.1, -0.15), VOID))
	weld(lower, part("FootGlow" .. side, Vector3.new(0.3, 0.05, 0.6), Vector3.new(x, 0.02, -0.15), NEON, Enum.Material.Neon))
end
leg("L", -0.3)
leg("R", 0.3)

-- violet glow from the rift (no shadows, see CLAUDE.md)
local light = Instance.new("PointLight")
light.Name = "VoidLight"
light.Color = NEON
light.Brightness = 1
light.Range = 11
light.Shadows = false
light.Parent = torso

model:SetAttribute("Rig", "Procedural")
model:SetAttribute("RootHeight", 2.2)
model:SetAttribute("Height", 6.6)
model.Parent = models

local count = 0
for _, d in ipairs(model:GetDescendants()) do
	if d:IsA("Motor6D") then count += 1 end
end
return "VoidWalker built: " .. #model:GetChildren() .. " parts, " .. count .. " joints"
