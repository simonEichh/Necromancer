-- Builds the low-poly rigged Ghoul into ServerStorage.Models.Ghoul.
-- Run in Studio's command bar / via the Studio MCP execute_luau (Edit mode).
-- The old Creator Store model is kept as Ghoul_Old until the new one is approved.
--
-- Same rig conventions as build_skelly.lua (see src/client/Modules/UnitAnimator.lua):
--   * front = -Z, character's right = +X, feet on y = 0, root part = HumanoidRootPart at y = 2.2
--   * Motor6Ds named Root/Waist/Neck/Jaw/LShoulder/RShoulder/LElbow/RElbow/LHip/RHip/LKnee/RKnee
--   * attributes: Rig = "Procedural", RootHeight, Height
-- A gaunt, fast scavenger: grey-orange skin stretched over a bony frame, a spine ridge, pointed ears,
-- long arms ending in claws, glowing eyes and a ragged loincloth.
local ServerStorage = game:GetService("ServerStorage")
local models = ServerStorage.Models

local old = models:FindFirstChild("Ghoul")
if old and old:GetAttribute("Rig") ~= "Procedural" then
	old.Name = "Ghoul_Old"
elseif old then
	old:Destroy()
end

local SKIN = Color3.fromRGB(170, 120, 84)
local SKIN_DARK = Color3.fromRGB(122, 84, 62)
local BONE = Color3.fromRGB(214, 200, 170)
local CLOTH = Color3.fromRGB(70, 52, 46)
local CLOTH_DARK = Color3.fromRGB(48, 36, 34)
local EYE = Color3.fromRGB(255, 120, 60)
local TEETH = Color3.fromRGB(226, 218, 190)

local model = Instance.new("Model")
model.Name = "Ghoul"

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
local root = part("HumanoidRootPart", Vector3.new(1.1, 0.4, 0.7), Vector3.new(0, 2.2, 0), CLOTH)
root.Transparency = 1
model.PrimaryPart = root

local pelvis = part("Pelvis", Vector3.new(1.15, 0.4, 0.75), Vector3.new(0, 2.2, 0), CLOTH)
motor("Root", root, pelvis, Vector3.new(0, 2.2, 0))

local torso = part("Torso", Vector3.new(1.2, 1.3, 0.75), Vector3.new(0, 3.05, 0), SKIN)
motor("Waist", pelvis, torso, Vector3.new(0, 2.4, 0))

-- bare ribs and a knobbly spine ridge down the back
for i, y in ipairs({ 3.45, 3.2, 2.95 }) do
	weld(torso, part("Rib" .. i, Vector3.new(1.0, 0.09, 0.06), Vector3.new(0, y, -0.38), BONE))
	weld(torso, part("Vertebra" .. i, Vector3.new(0.22, 0.2, 0.14), Vector3.new(0, y, 0.43), BONE))
end
-- ragged loincloth: a front and a back flap hanging from the pelvis
weld(pelvis, part("ClothFront", Vector3.new(0.9, 0.9, 0.1), Vector3.new(0, 1.8, -0.42), CLOTH))
weld(pelvis, part("ClothBack", Vector3.new(0.9, 0.8, 0.1), Vector3.new(0, 1.85, 0.42), CLOTH_DARK))
weld(torso, part("Rope", Vector3.new(1.28, 0.14, 0.82), Vector3.new(0, 2.5, 0), CLOTH_DARK))

-- ── Head ──────────────────────────────────────────────────────
local head = part("Head", Vector3.new(1.0, 1.0, 1.0), Vector3.new(0, 4.3, -0.05), SKIN)
motor("Neck", torso, head, Vector3.new(0, 3.7, 0))
weld(head, part("Brow", Vector3.new(1.04, 0.14, 0.16), Vector3.new(0, 4.52, -0.5), SKIN_DARK))
for _, x in ipairs({ -0.26, 0.26 }) do
	weld(head, part("Eye", Vector3.new(0.24, 0.16, 0.1), Vector3.new(x, 4.4, -0.52), EYE, Enum.Material.Neon))
	weld(head, part("Ear", Vector3.new(0.5, 0.2, 0.12), Vector3.new(x * 2.15, 4.5, 0.05), SKIN_DARK))
	weld(head, part("EarTip", Vector3.new(0.24, 0.14, 0.1), Vector3.new(x * 2.9, 4.62, 0.05), SKIN_DARK))
end
weld(head, part("Nose", Vector3.new(0.12, 0.2, 0.1), Vector3.new(0, 4.25, -0.54), SKIN_DARK))
local jaw = part("Jaw", Vector3.new(0.85, 0.3, 0.8), Vector3.new(0, 3.88, -0.1), SKIN_DARK)
motor("Jaw", head, jaw, Vector3.new(0, 3.95, 0.3))
for _, x in ipairs({ -0.28, -0.1, 0.1, 0.28 }) do
	weld(jaw, part("Fang", Vector3.new(0.1, 0.18, 0.06), Vector3.new(x, 4.05, -0.43), TEETH))
end

-- ── Arms: long and thin, ending in claws (character's right = +X) ──
local function arm(side, x)
	local upper = part(side .. "UpperArm", Vector3.new(0.3, 1.0, 0.3), Vector3.new(x, 3.05, 0), SKIN)
	motor(side .. "Shoulder", torso, upper, Vector3.new(x, 3.55, 0))
	local fore = part(side .. "Forearm", Vector3.new(0.26, 0.95, 0.26), Vector3.new(x, 2.075, 0), SKIN_DARK)
	motor(side .. "Elbow", upper, fore, Vector3.new(x, 2.55, 0))
	local hand = part(side .. "Hand", Vector3.new(0.34, 0.26, 0.34), Vector3.new(x, 1.47, 0), SKIN)
	weld(fore, hand)
	for _, dx in ipairs({ -0.11, 0, 0.11 }) do
		weld(fore, part(side .. "Claw", Vector3.new(0.06, 0.38, 0.06), Vector3.new(x + dx, 1.15, -0.08), BONE))
	end
end
arm("L", -0.85)
arm("R", 0.85)

-- ── Legs: thin and bony, with clawed feet ──────────────────────
local function leg(side, x)
	local upper = part(side .. "UpperLeg", Vector3.new(0.38, 0.9, 0.38), Vector3.new(x, 1.55, 0), SKIN_DARK)
	motor(side .. "Hip", pelvis, upper, Vector3.new(x, 2.0, 0))
	local lower = part(side .. "LowerLeg", Vector3.new(0.32, 0.9, 0.32), Vector3.new(x, 0.65, 0), SKIN)
	motor(side .. "Knee", upper, lower, Vector3.new(x, 1.1, 0))
	weld(lower, part("Foot" .. side, Vector3.new(0.5, 0.2, 0.85), Vector3.new(x, 0.1, -0.15), SKIN_DARK))
	weld(lower, part("Toes" .. side, Vector3.new(0.4, 0.12, 0.2), Vector3.new(x, 0.08, -0.62), BONE))
end
leg("L", -0.35)
leg("R", 0.35)

model:SetAttribute("Rig", "Procedural")
model:SetAttribute("RootHeight", 2.2)
model:SetAttribute("Height", 4.8)
model.Parent = models

local count = 0
for _, d in ipairs(model:GetDescendants()) do
	if d:IsA("Motor6D") then count += 1 end
end
return "Ghoul built: " .. #model:GetChildren() .. " parts, " .. count .. " joints"
