-- Builds the low-poly rigged Plague Doctor into ServerStorage.Models.PlagueDoctor.
-- Run in Studio's command bar / via the Studio MCP execute_luau (Edit mode).
-- The old Creator Store model is kept as PlagueDoctor_Old until the new one is approved.
--
-- Same rig conventions as build_skelly.lua (see src/client/Modules/UnitAnimator.lua):
--   * front = -Z, character's right = +X, feet on y = 0, root part = HumanoidRootPart at y = 2.2
--   * Motor6Ds named Root/Waist/Neck/LShoulder/RShoulder/LElbow/RElbow/LHip/RHip/LKnee/RKnee
--     (rest rotation identity, so animating = setting Motor6D.Transform)
--   * attributes: Rig = "Procedural", RootHeight, Height
-- The right arm does the attack swing, so the doctor holds a lantern staff there and
-- carries a glowing potion flask in the left hand.
local ServerStorage = game:GetService("ServerStorage")
local models = ServerStorage.Models

local old = models:FindFirstChild("PlagueDoctor")
if old and old:GetAttribute("Rig") ~= "Procedural" then
	old.Name = "PlagueDoctor_Old"
elseif old then
	old:Destroy()
end

local COAT = Color3.fromRGB(44, 40, 50)
local COAT_SHADE = Color3.fromRGB(64, 58, 72)
local LEATHER = Color3.fromRGB(104, 76, 58)
local MASK = Color3.fromRGB(196, 184, 150)
local GLASS = Color3.fromRGB(120, 255, 150)
local WOOD = Color3.fromRGB(86, 62, 46)
local BRASS = Color3.fromRGB(196, 150, 70)
local GLOVE = Color3.fromRGB(34, 30, 36)

local model = Instance.new("Model")
model.Name = "PlagueDoctor"

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
local root = part("HumanoidRootPart", Vector3.new(1.2, 0.4, 0.8), Vector3.new(0, 2.2, 0), COAT)
root.Transparency = 1
model.PrimaryPart = root

local pelvis = part("Pelvis", Vector3.new(1.3, 0.4, 0.8), Vector3.new(0, 2.2, 0), COAT)
motor("Root", root, pelvis, Vector3.new(0, 2.2, 0))

local torso = part("Torso", Vector3.new(1.5, 1.3, 0.9), Vector3.new(0, 3.05, 0), COAT)
motor("Waist", pelvis, torso, Vector3.new(0, 2.4, 0))

-- long coat: skirt hanging from the pelvis, collar, belt with pouch and buttons
weld(pelvis, part("CoatSkirt", Vector3.new(1.6, 1.0, 1.05), Vector3.new(0, 1.8, 0), COAT_SHADE))
weld(torso, part("Collar", Vector3.new(1.7, 0.25, 1.1), Vector3.new(0, 3.62, 0), COAT_SHADE))
weld(torso, part("Belt", Vector3.new(1.58, 0.16, 0.98), Vector3.new(0, 2.5, 0), LEATHER))
weld(torso, part("BeltBuckle", Vector3.new(0.24, 0.2, 0.06), Vector3.new(0, 2.5, -0.5), BRASS, Enum.Material.Metal))
weld(torso, part("Pouch", Vector3.new(0.38, 0.4, 0.24), Vector3.new(0.55, 2.32, -0.52), LEATHER))
for i, y in ipairs({ 3.25, 2.95 }) do
	weld(torso, part("Button" .. i, Vector3.new(0.14, 0.14, 0.06), Vector3.new(0, y, -0.47), BRASS, Enum.Material.Metal))
end

-- ── Head: bird-beak mask, goggle eyes, wide-brim hat ──────────
local head = part("Head", Vector3.new(1.0, 1.0, 1.0), Vector3.new(0, 4.3, 0), MASK)
motor("Neck", torso, head, Vector3.new(0, 3.7, 0))
local beakTop = part("BeakBridge", Vector3.new(0.4, 0.4, 0.55), Vector3.new(0, 4.2, -0.75), MASK)
weld(head, beakTop)
weld(head, part("BeakTip", Vector3.new(0.22, 0.26, 0.6), Vector3.new(0, 4.06, -1.2), MASK))
weld(head, part("BeakHook", Vector3.new(0.14, 0.14, 0.2), Vector3.new(0, 3.9, -1.45), LEATHER))
for _, x in ipairs({ -0.27, 0.27 }) do
	weld(head, part("GoggleRim", Vector3.new(0.4, 0.4, 0.1), Vector3.new(x, 4.45, -0.52), BRASS, Enum.Material.Metal))
	weld(head, part("GoggleGlass", Vector3.new(0.3, 0.3, 0.12), Vector3.new(x, 4.45, -0.54), GLASS, Enum.Material.Neon))
end
weld(head, part("HatBrim", Vector3.new(1.9, 0.12, 1.9), Vector3.new(0, 4.82, 0), COAT))
weld(head, part("HatCrown", Vector3.new(1.1, 0.7, 1.1), Vector3.new(0, 5.2, 0), COAT))
weld(head, part("HatBand", Vector3.new(1.14, 0.16, 1.14), Vector3.new(0, 4.98, 0), LEATHER))

-- ── Arms (character's right = +X) ─────────────────────────────
local function arm(side, x)
	local upper = part(side .. "UpperArm", Vector3.new(0.4, 0.95, 0.4), Vector3.new(x, 3.075, 0), COAT)
	motor(side .. "Shoulder", torso, upper, Vector3.new(x, 3.55, 0))
	local fore = part(side .. "Forearm", Vector3.new(0.36, 0.9, 0.36), Vector3.new(x, 2.15, 0), COAT_SHADE)
	motor(side .. "Elbow", upper, fore, Vector3.new(x, 2.6, 0))
	local hand = part(side .. "Hand", Vector3.new(0.32, 0.28, 0.32), Vector3.new(x, 1.58, 0), GLOVE)
	weld(fore, hand)
	return fore, hand
end
local _, lHand = arm("L", -1.0)
local _, rHand = arm("R", 1.0)

-- lantern staff in the right hand: wooden shaft held in the fist, brass cage + glowing lantern on top
weld(rHand, part("StaffShaft", Vector3.new(0.14, 3.6, 0.14), Vector3.new(1.0, 1.9, -0.05), WOOD))
weld(rHand, part("StaffCap", Vector3.new(0.3, 0.12, 0.3), Vector3.new(1.0, 3.74, -0.05), BRASS, Enum.Material.Metal))
weld(rHand, part("LanternGlass", Vector3.new(0.42, 0.55, 0.42), Vector3.new(1.0, 4.05, -0.05), GLASS, Enum.Material.Neon))
weld(rHand, part("LanternTop", Vector3.new(0.5, 0.1, 0.5), Vector3.new(1.0, 4.38, -0.05), BRASS, Enum.Material.Metal))

-- potion flask in the left hand
weld(lHand, part("FlaskBody", Vector3.new(0.42, 0.42, 0.42), Vector3.new(-1.0, 1.28, 0), GLASS, Enum.Material.Neon))
weld(lHand, part("FlaskNeck", Vector3.new(0.16, 0.22, 0.16), Vector3.new(-1.0, 1.58, 0), MASK))
weld(lHand, part("FlaskCork", Vector3.new(0.2, 0.1, 0.2), Vector3.new(-1.0, 1.74, 0), LEATHER))

-- ── Legs ──────────────────────────────────────────────────────
local function leg(side, x)
	local upper = part(side .. "UpperLeg", Vector3.new(0.45, 0.9, 0.45), Vector3.new(x, 1.55, 0), COAT)
	motor(side .. "Hip", pelvis, upper, Vector3.new(x, 2.0, 0))
	local lower = part(side .. "LowerLeg", Vector3.new(0.4, 0.9, 0.4), Vector3.new(x, 0.65, 0), COAT_SHADE)
	motor(side .. "Knee", upper, lower, Vector3.new(x, 1.1, 0))
	weld(lower, part("Boot" .. side, Vector3.new(0.55, 0.3, 0.9), Vector3.new(x, 0.15, -0.15), LEATHER))
end
leg("L", -0.4)
leg("R", 0.4)

model:SetAttribute("Rig", "Procedural")
model:SetAttribute("RootHeight", 2.2)
model:SetAttribute("Height", 5.6)
model.Parent = models

local count = 0
for _, d in ipairs(model:GetDescendants()) do
	if d:IsA("Motor6D") then count += 1 end
end
return "PlagueDoctor built: " .. #model:GetChildren() .. " parts, " .. count .. " joints"
