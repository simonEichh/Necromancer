-- Builds the low-poly rigged Goblin into ServerStorage.Models.Goblin.
-- Run in Studio's command bar / via the Studio MCP execute_luau (Edit mode).
-- The old Creator Store model is kept as Goblin_Old until the new one is approved.
--
-- Same rig conventions as build_skelly.lua (see src/client/Modules/UnitAnimator.lua), but this rig is
-- SHORT and hunched (hip at y = 1.4, root part = HumanoidRootPart at y = 1.6) with a big head, so
-- RootHeight is 1.6 instead of 2.2. Joint names are unchanged:
--   Root/Waist/Neck/Jaw/LShoulder/RShoulder/LElbow/RElbow/LHip/RHip/LKnee/RKnee
-- A scrawny green poison thrower: huge pointed ears, a long nose, fangs, a leather vest with a bandolier
-- of poison vials and a flask in each hand (the attack swing is the throw).
local ServerStorage = game:GetService("ServerStorage")
local models = ServerStorage.Models

local old = models:FindFirstChild("Goblin")
if old and old:GetAttribute("Rig") ~= "Procedural" then
	old.Name = "Goblin_Old"
elseif old then
	old:Destroy()
end

local SKIN = Color3.fromRGB(116, 190, 72)
local SKIN_DARK = Color3.fromRGB(76, 140, 52)
local LEATHER = Color3.fromRGB(112, 78, 52)
local CLOTH = Color3.fromRGB(88, 70, 60)
local EYE = Color3.fromRGB(255, 226, 70)
local TEETH = Color3.fromRGB(236, 228, 196)
local POISON = Color3.fromRGB(150, 255, 90)
local GLASS = Color3.fromRGB(190, 230, 170)
local CORK = Color3.fromRGB(150, 110, 70)

local model = Instance.new("Model")
model.Name = "Goblin"

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

-- a poison flask: glass body, glowing liquid, cork
local function flask(hand, name, pos, scale)
	weld(hand, part(name .. "Glass", Vector3.new(0.46, 0.46, 0.46) * scale, pos, GLASS))
	weld(hand, part(name .. "Liquid", Vector3.new(0.36, 0.3, 0.36) * scale, pos + Vector3.new(0, -0.04, 0) * scale, POISON, Enum.Material.Neon))
	weld(hand, part(name .. "Neck", Vector3.new(0.16, 0.2, 0.16) * scale, pos + Vector3.new(0, 0.32, 0) * scale, GLASS))
	weld(hand, part(name .. "Cork", Vector3.new(0.2, 0.1, 0.2) * scale, pos + Vector3.new(0, 0.46, 0) * scale, CORK))
end

-- ── Core (short and hunched) ───────────────────────────────────
local root = part("HumanoidRootPart", Vector3.new(1.1, 0.4, 0.8), Vector3.new(0, 1.6, 0), CLOTH)
root.Transparency = 1
model.PrimaryPart = root

local pelvis = part("Pelvis", Vector3.new(1.2, 0.4, 0.85), Vector3.new(0, 1.6, 0), CLOTH)
motor("Root", root, pelvis, Vector3.new(0, 1.6, 0))
-- ragged loincloth
weld(pelvis, part("ClothFront", Vector3.new(0.8, 0.6, 0.1), Vector3.new(0, 1.25, -0.45), CLOTH))
weld(pelvis, part("ClothBack", Vector3.new(0.8, 0.5, 0.1), Vector3.new(0, 1.3, 0.45), CLOTH))

local torso = part("Torso", Vector3.new(1.3, 1.2, 0.9), Vector3.new(0, 2.35, 0), SKIN)
motor("Waist", pelvis, torso, Vector3.new(0, 1.8, 0))
weld(torso, part("Vest", Vector3.new(1.38, 0.9, 0.96), Vector3.new(0, 2.45, 0), LEATHER))
weld(torso, part("Belly", Vector3.new(0.9, 0.3, 0.1), Vector3.new(0, 2.05, -0.46), SKIN_DARK))
-- bandolier of poison vials across the chest
weld(torso, part("Strap", Vector3.new(1.5, 0.16, 1.02), CFrame.new(0, 2.5, 0).Position, CLOTH))
for i, x in ipairs({ -0.4, 0, 0.4 }) do
	weld(torso, part("Vial" .. i, Vector3.new(0.18, 0.34, 0.14), Vector3.new(x, 2.5, -0.52), POISON, Enum.Material.Neon))
end

-- ── Head: big, with huge ears, a long nose and fangs ─────────
local head = part("Head", Vector3.new(1.3, 1.15, 1.2), Vector3.new(0, 3.5, -0.1), SKIN)
motor("Neck", torso, head, Vector3.new(0, 2.95, 0))
weld(head, part("Brow", Vector3.new(1.34, 0.18, 0.2), Vector3.new(0, 3.82, -0.62), SKIN_DARK))
for _, x in ipairs({ -1, 1 }) do
	weld(head, part("Eye", Vector3.new(0.28, 0.24, 0.1), Vector3.new(x * 0.32, 3.62, -0.7), EYE, Enum.Material.Neon))
	weld(head, part("Ear", Vector3.new(0.8, 0.36, 0.14), Vector3.new(x * 1.0, 3.7, 0.0), SKIN_DARK))
	weld(head, part("EarTip", Vector3.new(0.5, 0.22, 0.12), Vector3.new(x * 1.55, 3.9, 0.0), SKIN_DARK))
end
weld(head, part("Nose", Vector3.new(0.2, 0.2, 0.55), Vector3.new(0, 3.42, -0.85), SKIN_DARK))
weld(head, part("NoseTip", Vector3.new(0.26, 0.26, 0.2), Vector3.new(0, 3.36, -1.15), SKIN))
local jaw = part("Jaw", Vector3.new(0.95, 0.3, 0.85), Vector3.new(0, 3.0, -0.2), SKIN_DARK)
motor("Jaw", head, jaw, Vector3.new(0, 3.1, 0.3))
for _, x in ipairs({ -0.3, 0.3 }) do
	weld(jaw, part("Fang", Vector3.new(0.12, 0.22, 0.08), Vector3.new(x, 3.2, -0.6), TEETH))
end

-- ── Arms (character's right = +X): long and thin, a flask in each hand ──
local function arm(side, x)
	local upper = part(side .. "UpperArm", Vector3.new(0.3, 0.85, 0.3), Vector3.new(x, 2.4, 0), SKIN)
	motor(side .. "Shoulder", torso, upper, Vector3.new(x, 2.85, 0))
	local fore = part(side .. "Forearm", Vector3.new(0.27, 0.8, 0.27), Vector3.new(x, 1.58, 0), SKIN_DARK)
	motor(side .. "Elbow", upper, fore, Vector3.new(x, 1.98, 0))
	local hand = part(side .. "Hand", Vector3.new(0.34, 0.26, 0.34), Vector3.new(x, 1.08, 0), SKIN)
	weld(fore, hand)
	return fore
end
local lFore = arm("L", -0.85)
local rFore = arm("R", 0.85)
flask(rFore, "RFlask", Vector3.new(0.85, 0.82, -0.12), 1)
flask(lFore, "LFlask", Vector3.new(-0.85, 0.86, -0.1), 0.75)

-- ── Legs: short and bandy ──────────────────────────────────────
local function leg(side, x)
	local upper = part(side .. "UpperLeg", Vector3.new(0.4, 0.7, 0.4), Vector3.new(x, 1.05, 0), SKIN_DARK)
	motor(side .. "Hip", pelvis, upper, Vector3.new(x, 1.4, 0))
	local lower = part(side .. "LowerLeg", Vector3.new(0.34, 0.7, 0.34), Vector3.new(x, 0.35, 0), SKIN)
	motor(side .. "Knee", upper, lower, Vector3.new(x, 0.7, 0))
	weld(lower, part("Foot" .. side, Vector3.new(0.5, 0.2, 0.9), Vector3.new(x, 0.1, -0.2), LEATHER))
end
leg("L", -0.35)
leg("R", 0.35)

model:SetAttribute("Rig", "Procedural")
model:SetAttribute("RootHeight", 1.6)
model:SetAttribute("Height", 4.2)
model.Parent = models

local count = 0
for _, d in ipairs(model:GetDescendants()) do
	if d:IsA("Motor6D") then count += 1 end
end
return "Goblin built: " .. #model:GetChildren() .. " parts, " .. count .. " joints"
