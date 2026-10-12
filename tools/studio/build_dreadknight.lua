-- Builds the low-poly rigged Dread Knight into ServerStorage.Models.DreadKnight.
-- Run in Studio's command bar / via the Studio MCP execute_luau (Edit mode). Safe to re-run.
--
-- Standard humanoid rig (see build_skelly.lua and src/client/Modules/UnitAnimator.lua): front = -Z, right = +X,
-- feet on y = 0, root part = HumanoidRootPart at y = 2.2, joints Root/Waist/Neck/L,RShoulder/L,RElbow/L,RHip/
-- L,RKnee, attributes Rig = "Procedural", RootHeight, Height.
-- A hulking black-plate knight: horned great helm with a glowing red visor slit and a crimson plume, spiked
-- pauldrons and knees, a tattered crimson cape and tabard, a spiked shield on the left arm and a jagged black
-- greatsword with a glowing red fuller in the right.
local ServerStorage = game:GetService("ServerStorage")
local models = ServerStorage.Models

local old = models:FindFirstChild("DreadKnight")
if old then
	old:Destroy()
end

local STEEL_D = Color3.fromRGB(52, 54, 66)
local STEEL = Color3.fromRGB(88, 92, 108)
local BLACK = Color3.fromRGB(22, 22, 28)
local CRIMSON = Color3.fromRGB(104, 20, 30)
local GLOW = Color3.fromRGB(255, 64, 50)
local LEATHER = Color3.fromRGB(70, 50, 44)
local METAL = Enum.Material.Metal

local model = Instance.new("Model")
model.Name = "DreadKnight"

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
local root = part("HumanoidRootPart", Vector3.new(1.6, 0.5, 1.0), Vector3.new(0, 2.2, 0), STEEL_D)
root.Transparency = 1
model.PrimaryPart = root

local pelvis = part("Pelvis", Vector3.new(1.7, 0.5, 1.0), Vector3.new(0, 2.2, 0), STEEL_D, METAL)
motor("Root", root, pelvis, Vector3.new(0, 2.2, 0))
weld(pelvis, part("Belt", Vector3.new(1.8, 0.2, 1.1), Vector3.new(0, 2.4, 0), LEATHER))
weld(pelvis, part("TassetFront", Vector3.new(1.3, 0.8, 0.14), Vector3.new(0, 1.9, -0.58), STEEL, METAL))
weld(pelvis, part("TassetBack", Vector3.new(1.3, 0.8, 0.14), Vector3.new(0, 1.9, 0.58), STEEL, METAL))
weld(pelvis, part("Tabard", Vector3.new(0.7, 1.1, 0.06), Vector3.new(0, 1.75, -0.68), CRIMSON))

-- torso: black plate with a glowing red sigil, a gorget, a tattered cape
local torso = part("Torso", Vector3.new(1.9, 1.45, 1.05), Vector3.new(0, 3.1, 0), STEEL_D, METAL)
motor("Waist", pelvis, torso, Vector3.new(0, 2.4, 0))
weld(torso, part("Breastplate", Vector3.new(1.8, 1.2, 0.22), Vector3.new(0, 3.15, -0.62), STEEL, METAL))
weld(torso, part("BreastRidge", Vector3.new(0.18, 1.1, 0.12), Vector3.new(0, 3.15, -0.74), STEEL_D, METAL))
weld(torso, part("Sigil", Vector3.new(0.34, 0.34, 0.08), Vector3.new(0, 3.4, -0.78), GLOW, Enum.Material.Neon))
weld(torso, part("BackPlate", Vector3.new(1.8, 1.2, 0.18), Vector3.new(0, 3.15, 0.6), STEEL_D, METAL))
weld(torso, part("Gorget", Vector3.new(1.5, 0.25, 1.1), Vector3.new(0, 3.8, 0), STEEL, METAL))
weld(torso, part("Cape", Vector3.new(1.9, 2.4, 0.1), Vector3.new(0, 2.6, 0.82), CRIMSON))
for i, x in ipairs({ -0.65, 0, 0.65 }) do
	weld(torso, part("CapeTatter" .. i, Vector3.new(0.55, 0.5 + (i % 2) * 0.3, 0.1), Vector3.new(x, 1.15 - (i % 2) * 0.15, 0.82), CRIMSON))
end

-- ── Head: horned great helm, glowing visor slit, crimson plume ──
local head = part("Head", Vector3.new(1.2, 1.25, 1.2), Vector3.new(0, 4.5, 0), STEEL, METAL)
motor("Neck", torso, head, Vector3.new(0, 3.85, 0))
weld(head, part("Visor", Vector3.new(0.85, 0.12, 0.1), Vector3.new(0, 4.55, -0.62), GLOW, Enum.Material.Neon))
weld(head, part("VisorRidge", Vector3.new(0.12, 1.0, 0.1), Vector3.new(0, 4.5, -0.62), STEEL_D, METAL))
weld(head, part("Brow", Vector3.new(1.24, 0.14, 0.18), Vector3.new(0, 4.82, -0.6), STEEL_D, METAL))
for _, x in ipairs({ -1, 1 }) do
	weld(head, part("HornBase", Vector3.new(0.3, 0.45, 0.3), Vector3.new(x * 0.65, 4.95, 0), STEEL_D, METAL))
	weld(head, part("HornMid", Vector3.new(0.24, 0.4, 0.24), Vector3.new(x * 0.82, 5.3, 0), STEEL_D, METAL))
	weld(head, part("HornTip", Vector3.new(0.16, 0.35, 0.16), Vector3.new(x * 0.95, 5.65, 0), STEEL, METAL))
end
for i, z in ipairs({ -0.35, 0.05, 0.45 }) do
	weld(head, part("Plume" .. i, Vector3.new(0.2, 0.45 - (i - 1) * 0.08, 0.3), Vector3.new(0, 5.3, z), CRIMSON))
end

-- ── Arms (character's right = +X) ──────────────────────────────
local function arm(side, x)
	local sx = x > 0 and 1 or -1
	local upper = part(side .. "UpperArm", Vector3.new(0.55, 0.95, 0.55), Vector3.new(x, 3.075, 0), STEEL_D, METAL)
	motor(side .. "Shoulder", torso, upper, Vector3.new(x, 3.6, 0))
	weld(upper, part(side .. "Pauldron", Vector3.new(1.05, 0.55, 1.05), Vector3.new(x, 3.7, 0), STEEL, METAL))
	weld(upper, part(side .. "PauldronSpike", Vector3.new(0.2, 0.55, 0.2), Vector3.new(x + sx * 0.2, 4.2, 0), STEEL_D, METAL))
	local fore = part(side .. "Forearm", Vector3.new(0.5, 0.9, 0.5), Vector3.new(x, 2.15, 0), STEEL, METAL)
	motor(side .. "Elbow", upper, fore, Vector3.new(x, 2.6, 0))
	weld(fore, part(side .. "Vambrace", Vector3.new(0.62, 0.6, 0.62), Vector3.new(x, 2.0, 0), STEEL_D, METAL))
	local gauntlet = part(side .. "Gauntlet", Vector3.new(0.6, 0.45, 0.6), Vector3.new(x, 1.55, 0), STEEL_D, METAL)
	weld(fore, gauntlet)
	return fore, gauntlet
end
local lFore = arm("L", -1.25)
local _, rHand = arm("R", 1.25)

-- spiked heater shield on the left forearm
weld(lFore, part("ShieldBody", Vector3.new(0.14, 1.4, 1.0), Vector3.new(-1.72, 2.2, 0), STEEL_D, METAL))
weld(lFore, part("ShieldRimFront", Vector3.new(0.2, 1.4, 0.1), Vector3.new(-1.72, 2.2, -0.55), STEEL, METAL))
weld(lFore, part("ShieldRimBack", Vector3.new(0.2, 1.4, 0.1), Vector3.new(-1.72, 2.2, 0.55), STEEL, METAL))
weld(lFore, part("ShieldRimTop", Vector3.new(0.2, 0.1, 1.1), Vector3.new(-1.72, 2.9, 0), STEEL, METAL))
weld(lFore, part("ShieldEmblem", Vector3.new(0.06, 0.4, 0.4), Vector3.new(-1.8, 2.3, 0), GLOW, Enum.Material.Neon))
weld(lFore, part("ShieldBoss", Vector3.new(0.3, 0.22, 0.22), Vector3.new(-1.88, 2.3, 0), STEEL, METAL))

-- jagged black greatsword with a glowing red fuller in the right hand
weld(rHand, part("SwordGrip", Vector3.new(0.14, 0.14, 0.5), Vector3.new(1.25, 1.55, -0.05), LEATHER))
weld(rHand, part("SwordGuard", Vector3.new(1.1, 0.16, 0.24), Vector3.new(1.25, 1.4, -0.05), STEEL, METAL))
weld(rHand, part("SwordBlade", Vector3.new(0.42, 1.4, 0.12), Vector3.new(1.25, 0.68, -0.05), BLACK, METAL))
weld(rHand, part("SwordFuller", Vector3.new(0.08, 1.2, 0.14), Vector3.new(1.25, 0.72, -0.05), GLOW, Enum.Material.Neon))
for i, y in ipairs({ 1.0, 0.6, 0.2 }) do
	weld(rHand, part("SwordTooth" .. i, Vector3.new(0.16, 0.2, 0.1), Vector3.new(1.25 + 0.28, y, -0.05), BLACK, METAL))
end

-- ── Legs ───────────────────────────────────────────────────────
local function leg(side, x)
	local upper = part(side .. "UpperLeg", Vector3.new(0.62, 0.9, 0.62), Vector3.new(x, 1.55, 0), STEEL_D, METAL)
	motor(side .. "Hip", pelvis, upper, Vector3.new(x, 2.0, 0))
	weld(upper, part(side .. "Cuisse", Vector3.new(0.74, 0.55, 0.74), Vector3.new(x, 1.7, 0), STEEL, METAL))
	local lower = part(side .. "LowerLeg", Vector3.new(0.54, 0.9, 0.54), Vector3.new(x, 0.65, 0), STEEL_D, METAL)
	motor(side .. "Knee", upper, lower, Vector3.new(x, 1.1, 0))
	weld(lower, part(side .. "KneeCap", Vector3.new(0.6, 0.34, 0.34), Vector3.new(x, 1.08, -0.32), STEEL, METAL))
	weld(lower, part(side .. "KneeSpike", Vector3.new(0.14, 0.14, 0.35), Vector3.new(x, 1.08, -0.55), STEEL_D, METAL))
	weld(lower, part(side .. "Greave", Vector3.new(0.66, 0.55, 0.66), Vector3.new(x, 0.62, 0), STEEL, METAL))
	weld(lower, part("Boot" .. side, Vector3.new(0.8, 0.3, 1.1), Vector3.new(x, 0.15, -0.2), BLACK, METAL))
end
leg("L", -0.55)
leg("R", 0.55)

-- red glow from the visor and sigil (no shadows, see CLAUDE.md)
local light = Instance.new("PointLight")
light.Name = "KnightLight"
light.Color = GLOW
light.Brightness = 0.6
light.Range = 8
light.Shadows = false
light.Parent = torso

model:SetAttribute("Rig", "Procedural")
model:SetAttribute("RootHeight", 2.2)
model:SetAttribute("Height", 5.9)
model.Parent = models

local count = 0
for _, d in ipairs(model:GetDescendants()) do
	if d:IsA("Motor6D") then count += 1 end
end
return "DreadKnight built: " .. #model:GetChildren() .. " parts, " .. count .. " joints"
