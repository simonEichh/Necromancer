-- Builds the low-poly rigged Baron Bone into ServerStorage.Models.BaronBone.
-- Run in Studio's command bar / via the Studio MCP execute_luau (Edit mode). Safe to re-run.
--
-- Rig conventions (see src/client/Modules/UnitAnimator.lua and build_skelly.lua): front = -Z, right = +X,
-- feet on y = 0, root part = HumanoidRootPart at y = 2.2, joints Root/Waist/Neck/Jaw/L,RShoulder/L,RElbow/
-- L,RHip/L,RKnee, attributes Rig = "Procedural", RootHeight, Height.
-- A dapper skeleton nobleman: tall black top hat with a gold band, a monocle, a mustard frock coat with
-- gold buttons and tails that follow the legs, a white ruffled cravat, white gloves and a cane topped with
-- a golden skull (the attack swing is the cane strike).
local ServerStorage = game:GetService("ServerStorage")
local models = ServerStorage.Models

local old = models:FindFirstChild("BaronBone")
if old then
	old:Destroy()
end

local BONE = Color3.fromRGB(224, 216, 194)
local BONE_SHADE = Color3.fromRGB(176, 168, 148)
local COAT = Color3.fromRGB(196, 150, 40)
local COAT_DARK = Color3.fromRGB(132, 98, 28)
local BLACK = Color3.fromRGB(32, 28, 34)
local GOLD = Color3.fromRGB(240, 200, 80)
local WHITE = Color3.fromRGB(240, 238, 230)
local EYE = Color3.fromRGB(255, 190, 60)
local WOOD = Color3.fromRGB(70, 48, 38)

local model = Instance.new("Model")
model.Name = "BaronBone"

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
local root = part("HumanoidRootPart", Vector3.new(1.3, 0.4, 0.8), Vector3.new(0, 2.2, 0), COAT_DARK)
root.Transparency = 1
model.PrimaryPart = root

local pelvis = part("Pelvis", Vector3.new(1.4, 0.4, 0.9), Vector3.new(0, 2.2, 0), COAT_DARK)
motor("Root", root, pelvis, Vector3.new(0, 2.2, 0))

-- frock coat: gold buttons, trim, a ruffled cravat and a collar
local torso = part("Torso", Vector3.new(1.6, 1.35, 0.95), Vector3.new(0, 3.05, 0), COAT)
motor("Waist", pelvis, torso, Vector3.new(0, 2.4, 0))
weld(torso, part("Lapel", Vector3.new(0.9, 1.2, 0.08), Vector3.new(0, 3.0, -0.5), COAT_DARK))
weld(torso, part("Cravat", Vector3.new(0.5, 0.55, 0.14), Vector3.new(0, 3.5, -0.52), WHITE))
for i, y in ipairs({ 3.15, 2.85, 2.55 }) do
	weld(torso, part("Button" .. i, Vector3.new(0.13, 0.13, 0.06), Vector3.new(0.3, y, -0.56), GOLD, Enum.Material.Metal))
end
weld(torso, part("Collar", Vector3.new(1.7, 0.2, 1.05), Vector3.new(0, 3.7, 0), COAT_DARK))
weld(torso, part("Sash", Vector3.new(1.68, 0.14, 1.03), Vector3.new(0, 2.5, 0), GOLD, Enum.Material.Metal))

-- ── Head: skull, monocle and a tall top hat ───────────────────
local head = part("Head", Vector3.new(1.05, 1.05, 1.05), Vector3.new(0, 4.35, 0), BONE)
motor("Neck", torso, head, Vector3.new(0, 3.8, 0))
for _, x in ipairs({ -0.27, 0.27 }) do
	weld(head, part("EyeSocket", Vector3.new(0.3, 0.3, 0.1), Vector3.new(x, 4.42, -0.53), BLACK))
	weld(head, part("EyeGlow", Vector3.new(0.16, 0.16, 0.1), Vector3.new(x, 4.42, -0.57), EYE, Enum.Material.Neon))
end
weld(head, part("Nose", Vector3.new(0.14, 0.22, 0.08), Vector3.new(0, 4.2, -0.54), BLACK))
-- monocle on the right eye, with a chain
weld(head, part("MonocleRim", Vector3.new(0.46, 0.46, 0.08), Vector3.new(0.27, 4.42, -0.6), GOLD, Enum.Material.Metal))
weld(head, part("MonocleChain", Vector3.new(0.05, 0.6, 0.05), Vector3.new(0.5, 4.05, -0.58), GOLD, Enum.Material.Metal))
local jaw = part("Jaw", Vector3.new(0.85, 0.28, 0.8), Vector3.new(0, 3.9, -0.1), BONE_SHADE)
motor("Jaw", head, jaw, Vector3.new(0, 3.98, 0.3))
for _, x in ipairs({ -0.25, 0, 0.25 }) do
	weld(jaw, part("Tooth", Vector3.new(0.13, 0.13, 0.06), Vector3.new(x, 4.05, -0.48), BONE))
end
weld(head, part("HatBrim", Vector3.new(1.7, 0.1, 1.7), Vector3.new(0, 4.9, 0), BLACK))
weld(head, part("HatCrown", Vector3.new(1.1, 1.0, 1.1), Vector3.new(0, 5.4, 0), BLACK))
weld(head, part("HatBand", Vector3.new(1.14, 0.2, 1.14), Vector3.new(0, 5.05, 0), GOLD, Enum.Material.Metal))
weld(head, part("HatBuckle", Vector3.new(0.26, 0.26, 0.06), Vector3.new(0, 5.05, -0.58), WHITE))

-- ── Arms: coat sleeves, white gloves (character's right = +X) ──
local function arm(side, x)
	local upper = part(side .. "UpperArm", Vector3.new(0.42, 0.95, 0.42), Vector3.new(x, 3.075, 0), COAT)
	motor(side .. "Shoulder", torso, upper, Vector3.new(x, 3.55, 0))
	local fore = part(side .. "Forearm", Vector3.new(0.4, 0.9, 0.4), Vector3.new(x, 2.15, 0), COAT_DARK)
	motor(side .. "Elbow", upper, fore, Vector3.new(x, 2.6, 0))
	weld(fore, part(side .. "Cuff", Vector3.new(0.5, 0.16, 0.5), Vector3.new(x, 1.78, 0), WHITE))
	local hand = part(side .. "Hand", Vector3.new(0.36, 0.34, 0.36), Vector3.new(x, 1.6, 0), WHITE)
	weld(fore, hand)
	return hand
end
arm("L", -1.0)
local rHand = arm("R", 1.0)

-- cane in the right hand: wooden shaft ending in a golden skull knob
weld(rHand, part("CaneShaft", Vector3.new(0.12, 3.0, 0.12), Vector3.new(1.0, 1.65, -0.05), WOOD))
weld(rHand, part("CaneSkull", Vector3.new(0.4, 0.4, 0.38), Vector3.new(1.0, 3.3, -0.05), GOLD, Enum.Material.Metal))
for _, dx in ipairs({ -0.09, 0.09 }) do
	weld(rHand, part("CaneSkullEye", Vector3.new(0.09, 0.09, 0.05), Vector3.new(1.0 + dx, 3.33, -0.25), BLACK))
end
weld(rHand, part("CaneTip", Vector3.new(0.18, 0.14, 0.18), Vector3.new(1.0, 0.1, -0.05), GOLD, Enum.Material.Metal))

-- ── Legs: coat tails follow the stride ─────────────────────────
local function leg(side, x)
	local upper = part(side .. "UpperLeg", Vector3.new(0.5, 0.9, 0.5), Vector3.new(x, 1.55, 0), BONE)
	motor(side .. "Hip", pelvis, upper, Vector3.new(x, 2.0, 0))
	weld(upper, part(side .. "CoatTail", Vector3.new(0.7, 0.75, 1.05), Vector3.new(x, 1.85, 0), COAT))
	local lower = part(side .. "LowerLeg", Vector3.new(0.42, 0.9, 0.42), Vector3.new(x, 0.65, 0), BONE_SHADE)
	motor(side .. "Knee", upper, lower, Vector3.new(x, 1.1, 0))
	weld(lower, part("Spat" .. side, Vector3.new(0.5, 0.25, 0.5), Vector3.new(x, 0.4, 0), WHITE))
	weld(lower, part("Shoe" .. side, Vector3.new(0.55, 0.22, 0.95), Vector3.new(x, 0.11, -0.15), BLACK))
end
leg("L", -0.4)
leg("R", 0.4)

model:SetAttribute("Rig", "Procedural")
model:SetAttribute("RootHeight", 2.2)
model:SetAttribute("Height", 5.9)
model.Parent = models

local count = 0
for _, d in ipairs(model:GetDescendants()) do
	if d:IsA("Motor6D") then count += 1 end
end
return "BaronBone built: " .. #model:GetChildren() .. " parts, " .. count .. " joints"
