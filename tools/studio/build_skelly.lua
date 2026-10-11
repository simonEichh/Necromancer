-- Builds the low-poly rigged Skelly into ServerStorage.Models.Skelly.
-- Run in Studio's command bar / via the Studio MCP execute_luau (Edit mode).
-- The old model is kept as Skelly_Old until the new one is approved.
--
-- Rig conventions (see src/client/Modules/UnitAnimator.lua):
--   * front = -Z, character's right = +X, feet on y = 0, root part = HumanoidRootPart at y = 2.2
--   * joints are Motor6Ds named Waist/Neck/Jaw/LShoulder/RShoulder/LElbow/RElbow/LHip/RHip/LKnee/RKnee
--     whose rest rotation is identity, so animating = setting Motor6D.Transform
--   * attributes: Rig = "Procedural", RootHeight = distance floor->root, Height = total height
local ServerStorage = game:GetService("ServerStorage")
local models = ServerStorage.Models

local old = models:FindFirstChild("Skelly")
if old and old:GetAttribute("Rig") ~= "Procedural" then
	old.Name = "Skelly_Old"
elseif old then
	old:Destroy()
end

local BONE = Color3.fromRGB(222, 214, 192)
local BONE_SHADE = Color3.fromRGB(176, 168, 148)
local DARK = Color3.fromRGB(46, 42, 44)
local GLOW = Color3.fromRGB(110, 255, 175)
local STEEL = Color3.fromRGB(150, 158, 168)
local LEATHER = Color3.fromRGB(104, 76, 58)

local model = Instance.new("Model")
model.Name = "Skelly"

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
local root = part("HumanoidRootPart", Vector3.new(1.2, 0.4, 0.8), Vector3.new(0, 2.2, 0), BONE)
root.Transparency = 1
model.PrimaryPart = root

local pelvis = part("Pelvis", Vector3.new(1.3, 0.4, 0.8), Vector3.new(0, 2.2, 0), BONE_SHADE)
motor("Root", root, pelvis, Vector3.new(0, 2.2, 0))

local torso = part("Torso", Vector3.new(1.5, 1.3, 0.9), Vector3.new(0, 3.05, 0), BONE)
motor("Waist", pelvis, torso, Vector3.new(0, 2.4, 0))

-- ribs + spine on the front of the ribcage
for i, y in ipairs({ 3.4, 3.15, 2.9 }) do
	local rib = part("Rib" .. i, Vector3.new(1.25, 0.1, 0.06), Vector3.new(0, y, -0.47), DARK)
	weld(torso, rib)
end
weld(torso, part("Spine", Vector3.new(0.1, 1.15, 0.06), Vector3.new(0, 3.05, -0.47), DARK))

-- ── Head ──────────────────────────────────────────────────────
local head = part("Head", Vector3.new(1.1, 1.1, 1.1), Vector3.new(0, 4.35, 0), BONE)
motor("Neck", torso, head, Vector3.new(0, 3.7, 0))
for _, x in ipairs({ -0.28, 0.28 }) do
	weld(head, part("Eye", Vector3.new(0.24, 0.24, 0.1), Vector3.new(x, 4.45, -0.56), GLOW, Enum.Material.Neon))
end
weld(head, part("Nose", Vector3.new(0.14, 0.22, 0.08), Vector3.new(0, 4.2, -0.56), DARK))
local jaw = part("Jaw", Vector3.new(0.9, 0.28, 0.8), Vector3.new(0, 3.9, -0.1), BONE_SHADE)
motor("Jaw", head, jaw, Vector3.new(0, 3.9, 0.3))

-- ── Arms (character's right = +X) ─────────────────────────────
local function arm(side, x)
	local upper = part(side .. "UpperArm", Vector3.new(0.32, 0.95, 0.32), Vector3.new(x, 3.075, 0), BONE)
	motor(side .. "Shoulder", torso, upper, Vector3.new(x, 3.55, 0))
	local fore = part(side .. "Forearm", Vector3.new(0.28, 0.9, 0.28), Vector3.new(x, 2.15, 0), BONE_SHADE)
	motor(side .. "Elbow", upper, fore, Vector3.new(x, 2.6, 0))
	local hand = part(side .. "Hand", Vector3.new(0.3, 0.25, 0.3), Vector3.new(x, 1.6, 0), BONE)
	weld(fore, hand)
	return fore, hand
end
arm("L", -0.95)
local _, rHand = arm("R", 0.95)

-- rusty sword gripped in the right hand, blade pointing down and slightly forward
local grip = part("SwordGrip", Vector3.new(0.12, 0.12, 0.4), Vector3.new(0.95, 1.6, -0.05), LEATHER)
weld(rHand, grip)
local guard = part("SwordGuard", Vector3.new(0.5, 0.1, 0.14), Vector3.new(0.95, 1.5, -0.05), LEATHER)
weld(rHand, guard)
local blade = part("SwordBlade", Vector3.new(0.1, 1.5, 0.26), Vector3.new(0.95, 0.72, -0.05), STEEL, Enum.Material.Metal)
weld(rHand, blade)

-- ── Legs ──────────────────────────────────────────────────────
local function leg(side, x)
	local upper = part(side .. "UpperLeg", Vector3.new(0.45, 0.9, 0.45), Vector3.new(x, 1.55, 0), BONE)
	motor(side .. "Hip", pelvis, upper, Vector3.new(x, 2.0, 0))
	local lower = part(side .. "LowerLeg", Vector3.new(0.38, 0.9, 0.38), Vector3.new(x, 0.65, 0), BONE_SHADE)
	motor(side .. "Knee", upper, lower, Vector3.new(x, 1.1, 0))
	local foot = part("Foot" .. side, Vector3.new(0.55, 0.2, 0.9), Vector3.new(x, 0.1, -0.15), BONE)
	weld(lower, foot)
end
leg("L", -0.4)
leg("R", 0.4)

model:SetAttribute("Rig", "Procedural")
model:SetAttribute("RootHeight", 2.2)
model:SetAttribute("Height", 4.9)
model.Parent = models

local count = 0
for _, d in ipairs(model:GetDescendants()) do
	if d:IsA("Motor6D") then count += 1 end
end
return "Skelly built: " .. #model:GetChildren() .. " parts, " .. count .. " joints"
