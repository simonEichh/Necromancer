-- Builds the low-poly rigged Zombie into ServerStorage.Models.Zombie.
-- Run in Studio's command bar / via the Studio MCP execute_luau (Edit mode).
-- The old Creator Store model is kept as Zombie_Old until the new one is approved.
--
-- Same rig conventions as build_skelly.lua (see src/client/Modules/UnitAnimator.lua):
--   * front = -Z, character's right = +X, feet on y = 0, root part = HumanoidRootPart at y = 2.2
--   * Motor6Ds named Root/Waist/Neck/Jaw/LShoulder/RShoulder/LElbow/RElbow/LHip/RHip/LKnee/RKnee
--   * attributes: Rig = "Procedural", RootHeight, Height
-- A hulking, hunched zombie: rotten green skin, torn shirt and trousers, bare ribs and bandaged fists.
local ServerStorage = game:GetService("ServerStorage")
local models = ServerStorage.Models

local old = models:FindFirstChild("Zombie")
if old and old:GetAttribute("Rig") ~= "Procedural" then
	old.Name = "Zombie_Old"
elseif old then
	old:Destroy()
end

local SKIN = Color3.fromRGB(122, 156, 96)
local SKIN_DARK = Color3.fromRGB(88, 116, 70)
local SHIRT = Color3.fromRGB(96, 80, 66)
local SHIRT_DARK = Color3.fromRGB(70, 58, 50)
local PANTS = Color3.fromRGB(58, 62, 84)
local BANDAGE = Color3.fromRGB(206, 196, 168)
local EYE = Color3.fromRGB(255, 230, 90)
local WOUND = Color3.fromRGB(120, 36, 40)
local TEETH = Color3.fromRGB(226, 218, 190)

local model = Instance.new("Model")
model.Name = "Zombie"

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
local root = part("HumanoidRootPart", Vector3.new(1.4, 0.4, 0.9), Vector3.new(0, 2.2, 0), PANTS)
root.Transparency = 1
model.PrimaryPart = root

local pelvis = part("Pelvis", Vector3.new(1.5, 0.45, 0.95), Vector3.new(0, 2.2, 0), PANTS)
motor("Root", root, pelvis, Vector3.new(0, 2.2, 0))

local torso = part("Torso", Vector3.new(1.8, 1.4, 1.0), Vector3.new(0, 3.1, 0), SHIRT)
motor("Waist", pelvis, torso, Vector3.new(0, 2.4, 0))

-- torn shirt: ragged hem, a rotten patch on the chest and bare ribs peeking through
weld(torso, part("ShirtHem", Vector3.new(1.86, 0.2, 1.06), Vector3.new(0, 2.5, 0), SHIRT_DARK))
weld(torso, part("ChestPatch", Vector3.new(0.7, 0.55, 0.06), Vector3.new(-0.4, 3.3, -0.51), SKIN_DARK))
weld(torso, part("ChestWound", Vector3.new(0.3, 0.2, 0.07), Vector3.new(-0.45, 3.35, -0.52), WOUND))
for i, y in ipairs({ 3.0, 2.78 }) do
	weld(torso, part("Rib" .. i, Vector3.new(0.6, 0.08, 0.07), Vector3.new(0.4, y, -0.51), TEETH))
end
weld(torso, part("Shoulders", Vector3.new(2.0, 0.3, 1.05), Vector3.new(0, 3.65, 0), SHIRT_DARK))

-- ── Head ──────────────────────────────────────────────────────
local head = part("Head", Vector3.new(1.2, 1.1, 1.1), Vector3.new(0, 4.4, -0.05), SKIN)
motor("Neck", torso, head, Vector3.new(0, 3.8, 0))
weld(head, part("Brow", Vector3.new(1.24, 0.18, 0.2), Vector3.new(0, 4.62, -0.55), SKIN_DARK))
weld(head, part("EyeL", Vector3.new(0.26, 0.2, 0.1), Vector3.new(-0.3, 4.48, -0.58), EYE, Enum.Material.Neon))
weld(head, part("EyeR", Vector3.new(0.2, 0.2, 0.1), Vector3.new(0.3, 4.48, -0.58), EYE, Enum.Material.Neon))
weld(head, part("Nose", Vector3.new(0.2, 0.3, 0.12), Vector3.new(0, 4.3, -0.6), SKIN_DARK))
weld(head, part("HeadPatch", Vector3.new(0.5, 0.35, 0.06), Vector3.new(0.45, 4.8, 0.2), WOUND))
local jaw = part("Jaw", Vector3.new(1.0, 0.3, 0.9), Vector3.new(0, 3.98, -0.1), SKIN_DARK)
motor("Jaw", head, jaw, Vector3.new(0, 4.05, 0.3))
for _, x in ipairs({ -0.3, 0, 0.3 }) do
	weld(jaw, part("Tooth", Vector3.new(0.14, 0.14, 0.06), Vector3.new(x, 4.12, -0.52), TEETH))
end

-- ── Arms (character's right = +X) ─────────────────────────────
local function arm(side, x)
	local upper = part(side .. "UpperArm", Vector3.new(0.55, 0.95, 0.55), Vector3.new(x, 3.075, 0), SHIRT)
	motor(side .. "Shoulder", torso, upper, Vector3.new(x, 3.6, 0))
	local fore = part(side .. "Forearm", Vector3.new(0.5, 0.9, 0.5), Vector3.new(x, 2.15, 0), SKIN)
	motor(side .. "Elbow", upper, fore, Vector3.new(x, 2.6, 0))
	local fist = part(side .. "Fist", Vector3.new(0.62, 0.55, 0.62), Vector3.new(x, 1.5, 0), SKIN_DARK)
	weld(fore, fist)
	weld(fore, part(side .. "Bandage", Vector3.new(0.56, 0.22, 0.56), Vector3.new(x, 1.85, 0), BANDAGE))
end
arm("L", -1.2)
arm("R", 1.2)

-- ── Legs ──────────────────────────────────────────────────────
local function leg(side, x)
	local upper = part(side .. "UpperLeg", Vector3.new(0.6, 0.9, 0.6), Vector3.new(x, 1.55, 0), PANTS)
	motor(side .. "Hip", pelvis, upper, Vector3.new(x, 2.0, 0))
	local lower = part(side .. "LowerLeg", Vector3.new(0.52, 0.9, 0.52), Vector3.new(x, 0.65, 0), PANTS)
	motor(side .. "Knee", upper, lower, Vector3.new(x, 1.1, 0))
	weld(lower, part("Foot" .. side, Vector3.new(0.7, 0.3, 1.0), Vector3.new(x, 0.15, -0.15), SKIN_DARK))
end
leg("L", -0.5)
leg("R", 0.5)
-- one trouser leg is torn off at the knee
weld(model.LLowerLeg,part("TornCuff", Vector3.new(0.58, 0.14, 0.58), Vector3.new(-0.5, 1.0, 0), BANDAGE))

model:SetAttribute("Rig", "Procedural")
model:SetAttribute("RootHeight", 2.2)
model:SetAttribute("Height", 5.0)
model.Parent = models

local count = 0
for _, d in ipairs(model:GetDescendants()) do
	if d:IsA("Motor6D") then count += 1 end
end
return "Zombie built: " .. #model:GetChildren() .. " parts, " .. count .. " joints"
