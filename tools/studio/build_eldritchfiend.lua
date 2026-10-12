-- Builds the low-poly rigged Eldritch Fiend into ServerStorage.Models.EldritchFiend.
-- Run in Studio's command bar / via the Studio MCP execute_luau (Edit mode). Safe to re-run.
--
-- Standard humanoid rig (see build_skelly.lua and src/client/Modules/UnitAnimator.lua): front = -Z, right = +X,
-- feet on y = 0, root part = HumanoidRootPart at y = 2.2, joints Root/Waist/Neck/Jaw/L,RShoulder/L,RElbow/
-- L,RHip/L,RKnee, attributes Rig = "Procedural", RootHeight, Height. The game scales it to its size (3.5).
-- A cosmic horror: bruise-purple flesh, a hulking body with many staring lime-green eyes (on the head, the
-- chest and on stalks over the shoulders), a mouth full of teeth in the chest, a writhing crown of tentacles
-- on the head, three tentacles rising from the back, thick arms ending in hooked claws and three-toed feet.
local ServerStorage = game:GetService("ServerStorage")
local models = ServerStorage.Models

local old = models:FindFirstChild("EldritchFiend")
if old then
	old:Destroy()
end

local FLESH = Color3.fromRGB(86, 48, 102)
local FLESH_D = Color3.fromRGB(52, 28, 68)
local PALE = Color3.fromRGB(208, 182, 218)
local EYE = Color3.fromRGB(204, 255, 80)
local DARK = Color3.fromRGB(20, 10, 28)
local NEON = Enum.Material.Neon

local model = Instance.new("Model")
model.Name = "EldritchFiend"

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

-- an eye: a glowing lime sclera with a dark slit pupil, flat on a surface facing -Z
local function eye(parent, name, x, y, z, s)
	weld(parent, part(name .. "Ball", Vector3.new(s, s, 0.1), Vector3.new(x, y, z), EYE, NEON))
	weld(parent, part(name .. "Pupil", Vector3.new(s * 0.3, s * 0.8, 0.1), Vector3.new(x, y, z - 0.04), DARK))
end

-- ── Core ──────────────────────────────────────────────────────
local root = part("HumanoidRootPart", Vector3.new(1.4, 0.4, 0.9), Vector3.new(0, 2.2, 0), FLESH_D)
root.Transparency = 1
model.PrimaryPart = root

local pelvis = part("Pelvis", Vector3.new(1.5, 0.45, 1.0), Vector3.new(0, 2.2, 0), FLESH_D)
motor("Root", root, pelvis, Vector3.new(0, 2.2, 0))

local torso = part("Torso", Vector3.new(2.1, 1.8, 1.4), Vector3.new(0, 3.2, 0), FLESH)
motor("Waist", pelvis, torso, Vector3.new(0, 2.4, 0))
-- a mouth in the chest: dark frame, glowing throat, two rows of teeth
weld(torso, part("ChestMaw", Vector3.new(1.3, 0.8, 0.1), Vector3.new(0, 2.85, -0.72), DARK))
weld(torso, part("ChestThroat", Vector3.new(1.0, 0.45, 0.1), Vector3.new(0, 2.85, -0.78), EYE, NEON))
for i, x in ipairs({ -0.5, -0.3, -0.1, 0.1, 0.3, 0.5 }) do
	weld(torso, part("TopTooth" .. i, Vector3.new(0.14, 0.26, 0.1), Vector3.new(x, 3.08, -0.82), PALE))
	weld(torso, part("LowTooth" .. i, Vector3.new(0.14, 0.26, 0.1), Vector3.new(x + 0.1, 2.62, -0.82), PALE))
end
for i, e in ipairs({ { -0.75, 3.85, 0.34 }, { 0.8, 3.7, 0.28 }, { -0.25, 3.95, 0.2 }, { 0.3, 3.85, 0.24 } }) do
	eye(torso, "ChestEye" .. i, e[1], e[2], -0.74, e[3])
end
-- hump on the back with three rising tentacles
weld(torso, part("Hump", Vector3.new(1.8, 1.4, 0.6), Vector3.new(0, 3.3, 0.95), FLESH_D))
for i, x in ipairs({ -0.7, 0, 0.7 }) do
	local k = (i == 2) and 0 or (i == 1 and -1 or 1)
	weld(torso, part("BackTentacle" .. i .. "A", Vector3.new(0.4, 0.7, 0.4), Vector3.new(x, 4.0, 1.25), FLESH))
	weld(torso, part("BackTentacle" .. i .. "B", Vector3.new(0.3, 0.7, 0.3), Vector3.new(x + 0.3 * k, 4.65, 1.5), FLESH))
	weld(torso, part("BackTentacle" .. i .. "C", Vector3.new(0.2, 0.6, 0.2), Vector3.new(x + 0.6 * k, 5.2, 1.7), FLESH_D))
	weld(torso, part("BackTentacleTip" .. i, Vector3.new(0.16, 0.16, 0.16), Vector3.new(x + 0.7 * k, 5.6, 1.78), EYE, NEON))
end
-- eyes on stalks over the shoulders
for _, x in ipairs({ -1, 1 }) do
	weld(torso, part("EyeStalk", Vector3.new(0.1, 0.8, 0.1), Vector3.new(x * 1.7, 4.8, -0.1), FLESH))
	local ball = part("StalkEye", Vector3.new(0.34, 0.34, 0.34), Vector3.new(x * 1.7, 5.35, -0.1), EYE, NEON)
	ball.Shape = Enum.PartType.Ball
	weld(torso, ball)
	weld(torso, part("StalkPupil", Vector3.new(0.1, 0.22, 0.1), Vector3.new(x * 1.7, 5.35, -0.27), DARK))
end

-- ── Head: three staring eyes, a hinged toothy jaw and a crown of tentacles ──
local head = part("Head", Vector3.new(1.3, 1.1, 1.2), Vector3.new(0, 4.85, 0), FLESH)
motor("Neck", torso, head, Vector3.new(0, 4.1, 0))
eye(head, "BigEye", 0, 5.0, -0.64, 0.5)
eye(head, "EyeL", -0.45, 4.78, -0.64, 0.22)
eye(head, "EyeR", 0.45, 4.78, -0.64, 0.22)
for i, x in ipairs({ -0.45, -0.15, 0.15, 0.45 }) do
	local k = x < 0 and -1 or 1
	weld(head, part("CrownA" .. i, Vector3.new(0.2, 0.5, 0.2), Vector3.new(x, 5.65, 0), FLESH))
	weld(head, part("CrownB" .. i, Vector3.new(0.16, 0.4, 0.16), Vector3.new(x + 0.1 * k, 6.05, 0.1), FLESH_D))
	weld(head, part("CrownTip" .. i, Vector3.new(0.12, 0.12, 0.12), Vector3.new(x + 0.2 * k, 6.35, 0.2), EYE, NEON))
end
local jaw = part("Jaw", Vector3.new(1.0, 0.3, 0.9), Vector3.new(0, 4.35, -0.2), FLESH_D)
motor("Jaw", head, jaw, Vector3.new(0, 4.45, 0.3))
for i, x in ipairs({ -0.35, -0.12, 0.12, 0.35 }) do
	weld(jaw, part("Fang" .. i, Vector3.new(0.1, 0.24 + (i % 2) * 0.1, 0.08), Vector3.new(x, 4.5, -0.62), PALE))
end

-- ── Arms: thick limbs with suckers, ending in hooked claws (character's right = +X) ──
local function arm(side, x)
	local upper = part(side .. "UpperArm", Vector3.new(0.65, 1.15, 0.65), Vector3.new(x, 3.3, 0), FLESH)
	motor(side .. "Shoulder", torso, upper, Vector3.new(x, 3.9, 0))
	local fore = part(side .. "Forearm", Vector3.new(0.55, 1.2, 0.55), Vector3.new(x, 2.1, 0), FLESH_D)
	motor(side .. "Elbow", upper, fore, Vector3.new(x, 2.7, 0))
	for i, y in ipairs({ 2.45, 2.1, 1.75 }) do
		weld(fore, part(side .. "Sucker" .. i, Vector3.new(0.16, 0.16, 0.1), Vector3.new(x, y, -0.3), PALE))
	end
	weld(fore, part(side .. "Palm", Vector3.new(0.5, 0.35, 0.5), Vector3.new(x, 1.3, 0), FLESH))
	for _, dx in ipairs({ -0.18, -0.06, 0.06, 0.18 }) do
		weld(fore, part(side .. "Finger", Vector3.new(0.1, 0.55, 0.1), Vector3.new(x + dx, 0.88, -0.1), PALE))
		weld(fore, part(side .. "Hook", Vector3.new(0.1, 0.1, 0.22), Vector3.new(x + dx, 0.6, -0.2), PALE))
	end
end
arm("L", -1.45)
arm("R", 1.45)

-- ── Legs: thick, with three-toed feet ─────────────────────────
local function leg(side, x)
	local upper = part(side .. "UpperLeg", Vector3.new(0.7, 0.9, 0.7), Vector3.new(x, 1.55, 0), FLESH_D)
	motor(side .. "Hip", pelvis, upper, Vector3.new(x, 2.0, 0))
	local lower = part(side .. "LowerLeg", Vector3.new(0.6, 0.9, 0.6), Vector3.new(x, 0.65, 0), FLESH)
	motor(side .. "Knee", upper, lower, Vector3.new(x, 1.1, 0))
	weld(lower, part("Foot" .. side, Vector3.new(0.8, 0.22, 0.8), Vector3.new(x, 0.11, -0.1), FLESH_D))
	for _, dx in ipairs({ -0.25, 0, 0.25 }) do
		weld(lower, part("Toe" .. side, Vector3.new(0.2, 0.16, 0.4), Vector3.new(x + dx, 0.08, -0.6), PALE))
	end
end
leg("L", -0.6)
leg("R", 0.6)

-- sickly green glow from all the eyes (no shadows, see CLAUDE.md)
local light = Instance.new("PointLight")
light.Name = "FiendLight"
light.Color = EYE
light.Brightness = 0.9
light.Range = 10
light.Shadows = false
light.Parent = torso

model:SetAttribute("Rig", "Procedural")
model:SetAttribute("RootHeight", 2.2)
model:SetAttribute("Height", 6.5)
model.Parent = models

local count = 0
for _, d in ipairs(model:GetDescendants()) do
	if d:IsA("Motor6D") then count += 1 end
end
return "EldritchFiend built: " .. #model:GetChildren() .. " parts, " .. count .. " joints"
