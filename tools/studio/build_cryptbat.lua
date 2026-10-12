-- Builds the low-poly rigged Crypt Bat into ServerStorage.Models.CryptBat.
-- Run in Studio's command bar / via the Studio MCP execute_luau (Edit mode). Safe to re-run.
--
-- Rig conventions (see src/client/Modules/UnitAnimator.lua): front = -Z, root part = HumanoidRootPart at
-- y = 2.2, attributes Rig = "Procedural", RootHeight, Height, Float (hover bob).
-- A small flying bat: Root/Waist/Neck/Jaw for the body, LHip/RHip for the dangling feet and LWing/RWing
-- (flap joints, UnitAnimator makes them beat) for the wings. It hovers instead of walking.
local ServerStorage = game:GetService("ServerStorage")
local models = ServerStorage.Models

local old = models:FindFirstChild("CryptBat")
if old then
	old:Destroy()
end

local FUR = Color3.fromRGB(70, 52, 86)
local FUR_DARK = Color3.fromRGB(42, 30, 56)
local BELLY = Color3.fromRGB(122, 100, 140)
local MEMBRANE = Color3.fromRGB(88, 40, 104)
local BONE = Color3.fromRGB(190, 180, 200)
local EYE = Color3.fromRGB(255, 70, 70)
local TEETH = Color3.fromRGB(240, 236, 226)

local model = Instance.new("Model")
model.Name = "CryptBat"

local function part(name, size, pos, color, material, transparency)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = CFrame.new(pos)
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Transparency = transparency or 0
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

-- ── Core ──────────────────────────────────────────────────────
local root = part("HumanoidRootPart", Vector3.new(0.8, 0.4, 0.6), Vector3.new(0, 2.2, 0), FUR)
root.Transparency = 1
model.PrimaryPart = root

local pelvis = part("Pelvis", Vector3.new(0.7, 0.4, 0.6), Vector3.new(0, 2.15, 0), FUR_DARK)
motor("Root", root, pelvis, Vector3.new(0, 2.2, 0))

local torso = part("Torso", Vector3.new(1.0, 1.1, 0.9), Vector3.new(0, 2.65, 0), FUR)
motor("Waist", pelvis, torso, Vector3.new(0, 2.3, 0))
weld(torso, part("Belly", Vector3.new(0.7, 0.8, 0.1), Vector3.new(0, 2.6, -0.46), BELLY))

-- ── Head: big pointed ears, snout, red eyes and fangs ─────────
local head = part("Head", Vector3.new(0.95, 0.85, 0.85), Vector3.new(0, 3.5, -0.05), FUR)
motor("Neck", torso, head, Vector3.new(0, 3.2, 0))
for _, x in ipairs({ -1, 1 }) do
	weld(head, part("Ear", Vector3.new(0.3, 0.8, 0.12), Vector3.new(x * 0.3, 4.2, 0.05), FUR_DARK))
	weld(head, part("EarTip", Vector3.new(0.16, 0.3, 0.1), Vector3.new(x * 0.3, 4.7, 0.05), FUR_DARK))
	weld(head, part("EarInner", Vector3.new(0.14, 0.6, 0.06), Vector3.new(x * 0.3, 4.2, -0.02), BELLY))
	weld(head, part("Eye", Vector3.new(0.2, 0.2, 0.1), Vector3.new(x * 0.24, 3.6, -0.46), EYE, Enum.Material.Neon))
end
weld(head, part("Snout", Vector3.new(0.45, 0.3, 0.35), Vector3.new(0, 3.38, -0.55), FUR_DARK))
weld(head, part("Nose", Vector3.new(0.2, 0.14, 0.1), Vector3.new(0, 3.42, -0.74), BONE))
local jaw = part("Jaw", Vector3.new(0.5, 0.14, 0.45), Vector3.new(0, 3.2, -0.45), FUR_DARK)
motor("Jaw", head, jaw, Vector3.new(0, 3.28, -0.1))
for _, x in ipairs({ -0.14, 0.14 }) do
	weld(jaw, part("Fang", Vector3.new(0.08, 0.2, 0.08), Vector3.new(x, 3.34, -0.64), TEETH))
end

-- ── Wings: arm bone, hanging membrane and finger bones, flapped by the LWing/RWing joints ──
local function wing(side, sx)
	local rootPart = part(side .. "WingRoot", Vector3.new(0.25, 0.25, 0.25), Vector3.new(sx * 0.58, 2.9, 0.1), FUR_DARK)
	motor(side .. "Wing", torso, rootPart, Vector3.new(sx * 0.5, 2.9, 0.1))
	weld(rootPart, part(side .. "WingArm", Vector3.new(1.9, 0.12, 0.12), Vector3.new(sx * 1.5, 2.95, 0.1), BONE))
	weld(rootPart, part(side .. "WingMembrane", Vector3.new(1.85, 1.0, 0.05), Vector3.new(sx * 1.5, 2.4, 0.12), MEMBRANE, nil, 0.1))
	for i, x in ipairs({ 1.0, 1.7, 2.35 }) do
		local h = 1.15 - (i - 1) * 0.15
		weld(rootPart, part(side .. "Finger" .. i, Vector3.new(0.08, h, 0.08), Vector3.new(sx * x, 2.95 - h / 2, 0.1), BONE))
	end
	weld(rootPart, part(side .. "Thumb", Vector3.new(0.1, 0.3, 0.1), Vector3.new(sx * 2.45, 3.1, 0.1), BONE))
end
wing("L", -1)
wing("R", 1)

-- ── Feet: thin dangling legs with claws ───────────────────────
local function foot(side, x)
	local leg = part(side .. "UpperLeg", Vector3.new(0.14, 0.6, 0.14), Vector3.new(x, 1.8, 0), FUR_DARK)
	motor(side .. "Hip", pelvis, leg, Vector3.new(x, 2.1, 0))
	weld(leg, part(side .. "Claw", Vector3.new(0.3, 0.1, 0.3), Vector3.new(x, 1.45, -0.05), BONE))
end
foot("L", -0.22)
foot("R", 0.22)

model:SetAttribute("Rig", "Procedural")
model:SetAttribute("RootHeight", 2.2)
model:SetAttribute("Height", 4.8)
model:SetAttribute("Float", 0.25)
model.Parent = models

local count = 0
for _, d in ipairs(model:GetDescendants()) do
	if d:IsA("Motor6D") then count += 1 end
end
return "CryptBat built: " .. #model:GetChildren() .. " parts, " .. count .. " joints"
