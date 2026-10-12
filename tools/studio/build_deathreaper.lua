-- Builds the low-poly rigged Death Reaper into ServerStorage.Models.DeathReaper.
-- Run in Studio's command bar / via the Studio MCP execute_luau (Edit mode). Safe to re-run.
--
-- Standard humanoid rig (see build_skelly.lua and src/client/Modules/UnitAnimator.lua): front = -Z, right = +X,
-- feet on y = 0, root part = HumanoidRootPart at y = 2.2, joints Root/Waist/Neck/Jaw/L,RShoulder/L,RElbow/
-- L,RHip/L,RKnee, attributes Rig = "Procedural", RootHeight, Height.
-- The grim reaper: a black hooded robe with blood-red trim, a bone skull with burning orange eyes and
-- jagged teeth, bony forearms and hands, a ragged red scarf, an hourglass at the belt and a long-shafted
-- scythe whose blade curves forward in the right hand (the attack swing sweeps it down).
local ServerStorage = game:GetService("ServerStorage")
local models = ServerStorage.Models

local old = models:FindFirstChild("DeathReaper")
if old then
	old:Destroy()
end

local ROBE = Color3.fromRGB(24, 22, 30)
local ROBE_DARK = Color3.fromRGB(14, 12, 20)
local RED = Color3.fromRGB(112, 16, 28)
local BONE = Color3.fromRGB(222, 214, 192)
local BONE_SHADE = Color3.fromRGB(172, 164, 144)
local EYE = Color3.fromRGB(255, 96, 40)
local HOLLOW = Color3.fromRGB(10, 6, 12)
local STEEL = Color3.fromRGB(184, 190, 204)
local WOOD = Color3.fromRGB(62, 46, 40)
local GOLD = Color3.fromRGB(210, 170, 70)
local SAND = Color3.fromRGB(255, 170, 60)

local model = Instance.new("Model")
model.Name = "DeathReaper"

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
local root = part("HumanoidRootPart", Vector3.new(1.2, 0.4, 0.8), Vector3.new(0, 2.2, 0), ROBE)
root.Transparency = 1
model.PrimaryPart = root

local pelvis = part("Pelvis", Vector3.new(1.3, 0.4, 0.85), Vector3.new(0, 2.2, 0), ROBE_DARK)
motor("Root", root, pelvis, Vector3.new(0, 2.2, 0))

local torso = part("Torso", Vector3.new(1.4, 1.3, 0.85), Vector3.new(0, 3.05, 0), ROBE)
motor("Waist", pelvis, torso, Vector3.new(0, 2.4, 0))
weld(torso, part("Mantle", Vector3.new(1.9, 0.3, 1.0), Vector3.new(0, 3.65, 0), ROBE_DARK))
weld(torso, part("Belt", Vector3.new(1.48, 0.14, 0.93), Vector3.new(0, 2.5, 0), RED))
-- ragged red scarf hanging front and back
weld(torso, part("ScarfFront", Vector3.new(0.3, 1.4, 0.08), Vector3.new(0, 2.95, -0.47), RED))
weld(torso, part("ScarfBack", Vector3.new(0.34, 1.2, 0.08), Vector3.new(0.2, 2.95, 0.47), RED))
-- hourglass hanging at the belt: gold caps, glowing sand
weld(torso, part("HourglassTop", Vector3.new(0.3, 0.06, 0.3), Vector3.new(-0.55, 2.8, -0.5), GOLD, Enum.Material.Metal))
weld(torso, part("HourglassBottom", Vector3.new(0.3, 0.06, 0.3), Vector3.new(-0.55, 2.2, -0.5), GOLD, Enum.Material.Metal))
weld(torso, part("HourglassSand", Vector3.new(0.18, 0.5, 0.18), Vector3.new(-0.55, 2.5, -0.5), SAND, Enum.Material.Neon))

-- ── Head: bone skull in a black hood, burning eyes, jagged teeth ──
local head = part("Head", Vector3.new(0.95, 1.0, 0.95), Vector3.new(0, 4.35, 0), BONE)
motor("Neck", torso, head, Vector3.new(0, 3.7, 0))
weld(head, part("HoodBack", Vector3.new(1.4, 1.4, 0.3), Vector3.new(0, 4.4, 0.55), ROBE))
weld(head, part("HoodTop", Vector3.new(1.4, 0.3, 1.5), Vector3.new(0, 5.0, 0.08), ROBE))
weld(head, part("HoodPeak", Vector3.new(0.5, 0.45, 0.5), Vector3.new(0, 5.3, 0.4), ROBE_DARK))
for _, x in ipairs({ -1, 1 }) do
	weld(head, part("HoodSide", Vector3.new(0.26, 1.4, 1.25), Vector3.new(x * 0.62, 4.4, 0.0), ROBE))
	weld(head, part("HoodRimSide", Vector3.new(0.1, 1.2, 0.1), Vector3.new(x * 0.5, 4.4, -0.62), RED))
	weld(head, part("EyeSocket", Vector3.new(0.3, 0.3, 0.1), Vector3.new(x * 0.23, 4.45, -0.48), HOLLOW))
	weld(head, part("EyeGlow", Vector3.new(0.16, 0.16, 0.1), Vector3.new(x * 0.23, 4.45, -0.52), EYE, Enum.Material.Neon))
end
weld(head, part("HoodRimTop", Vector3.new(1.1, 0.1, 0.1), Vector3.new(0, 4.92, -0.62), RED))
weld(head, part("NoseHole", Vector3.new(0.12, 0.18, 0.08), Vector3.new(0, 4.25, -0.49), HOLLOW))
local jaw = part("Jaw", Vector3.new(0.8, 0.26, 0.72), Vector3.new(0, 3.92, -0.08), BONE_SHADE)
motor("Jaw", head, jaw, Vector3.new(0, 4.0, 0.28))
for i, x in ipairs({ -0.3, -0.15, 0, 0.15, 0.3 }) do
	weld(jaw, part("Tooth" .. i, Vector3.new(0.1, 0.12 + (i % 2) * 0.1, 0.06), Vector3.new(x, 4.03, -0.45), BONE))
end

-- ── Arms: ragged sleeves, bare bone forearms and hands (character's right = +X) ──
local function arm(side, x)
	local upper = part(side .. "UpperArm", Vector3.new(0.4, 0.95, 0.4), Vector3.new(x, 3.075, 0), ROBE)
	motor(side .. "Shoulder", torso, upper, Vector3.new(x, 3.55, 0))
	local fore = part(side .. "Forearm", Vector3.new(0.26, 0.9, 0.26), Vector3.new(x, 2.15, 0), BONE_SHADE)
	motor(side .. "Elbow", upper, fore, Vector3.new(x, 2.6, 0))
	weld(fore, part(side .. "Cuff", Vector3.new(0.52, 0.28, 0.52), Vector3.new(x, 2.5, 0), ROBE_DARK))
	local hand = part(side .. "Hand", Vector3.new(0.28, 0.3, 0.28), Vector3.new(x, 1.58, 0), BONE)
	weld(fore, hand)
	for _, dx in ipairs({ -0.09, 0.09 }) do
		weld(fore, part(side .. "Finger", Vector3.new(0.05, 0.28, 0.05), Vector3.new(x + dx, 1.3, -0.06), BONE))
	end
	return hand
end
arm("L", -1.0)
local rHand = arm("R", 1.0)

-- scythe in the right hand: a long shaft with the blade curving forward from the top
weld(rHand, part("ScytheShaft", Vector3.new(0.14, 4.5, 0.14), Vector3.new(1.0, 2.25, -0.05), WOOD))
weld(rHand, part("ScytheCap", Vector3.new(0.24, 0.2, 0.24), Vector3.new(1.0, 4.55, -0.05), BONE))
weld(rHand, part("BladeTop", Vector3.new(0.12, 0.26, 1.0), Vector3.new(1.0, 4.4, -0.62), STEEL, Enum.Material.Metal))
weld(rHand, part("BladeDrop", Vector3.new(0.12, 0.55, 0.26), Vector3.new(1.0, 4.05, -1.05), STEEL, Enum.Material.Metal))
weld(rHand, part("BladeTip", Vector3.new(0.1, 0.2, 0.34), Vector3.new(1.0, 3.7, -0.92), STEEL, Enum.Material.Metal))
weld(rHand, part("BladeEdge", Vector3.new(0.05, 0.05, 1.0), Vector3.new(1.0, 4.26, -0.62), EYE, Enum.Material.Neon))

-- ── Legs: robe flaps follow the stride, bony boots peek out ────
local function leg(side, x)
	local upper = part(side .. "UpperLeg", Vector3.new(0.65, 0.9, 0.85), Vector3.new(x, 1.55, 0), ROBE)
	motor(side .. "Hip", pelvis, upper, Vector3.new(x, 2.0, 0))
	local lower = part(side .. "LowerLeg", Vector3.new(0.58, 0.8, 0.8), Vector3.new(x, 0.7, 0), ROBE_DARK)
	motor(side .. "Knee", upper, lower, Vector3.new(x, 1.1, 0))
	weld(lower, part("Hem" .. side, Vector3.new(0.62, 0.1, 0.84), Vector3.new(x, 0.34, 0), RED))
	weld(lower, part("Boot" .. side, Vector3.new(0.45, 0.22, 0.85), Vector3.new(x, 0.11, -0.18), BONE_SHADE))
end
leg("L", -0.38)
leg("R", 0.38)

-- faint ember glow from the eyes and the sand (no shadows, see CLAUDE.md)
local light = Instance.new("PointLight")
light.Name = "ReaperLight"
light.Color = EYE
light.Brightness = 0.6
light.Range = 8
light.Shadows = false
light.Parent = torso

model:SetAttribute("Rig", "Procedural")
model:SetAttribute("RootHeight", 2.2)
model:SetAttribute("Height", 5.6)
model.Parent = models

local count = 0
for _, d in ipairs(model:GetDescendants()) do
	if d:IsA("Motor6D") then count += 1 end
end
return "DeathReaper built: " .. #model:GetChildren() .. " parts, " .. count .. " joints"
