-- Builds the low-poly rigged Shade Lord into ServerStorage.Models.ShadeLord.
-- Run in Studio's command bar / via the Studio MCP execute_luau (Edit mode). Safe to re-run.
--
-- Rig conventions (see build_skelly.lua and src/client/Modules/UnitAnimator.lua): front = -Z, root part =
-- HumanoidRootPart at y = 2.2, attributes Rig = "Procedural", RootHeight, Height, Float (hover bob).
-- Joints: Root/Waist/Neck/L,RShoulder/L,RElbow plus LWing/RWing, which UnitAnimator flaps.
-- A floating dark lord: an indigo spirit body with a blank black face and two blazing blue eyes, a crown
-- of spikes with glowing tips, spiked pauldrons, a floating blue orb at the right hand, a tapering tail
-- instead of legs and a pair of big dark feathered wings that flap. The body is opaque.
local ServerStorage = game:GetService("ServerStorage")
local models = ServerStorage.Models

local old = models:FindFirstChild("ShadeLord")
if old then
	old:Destroy()
end

local SHADE = Color3.fromRGB(18, 20, 42)
local SHADE_L = Color3.fromRGB(38, 42, 78)
local VOID = Color3.fromRGB(4, 4, 10)
local BLUE = Color3.fromRGB(70, 130, 255)
local EYE = Color3.fromRGB(206, 228, 255)
local CROWN = Color3.fromRGB(46, 50, 90)

local model = Instance.new("Model")
model.Name = "ShadeLord"

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
local root = part("HumanoidRootPart", Vector3.new(1.2, 0.4, 0.8), Vector3.new(0, 2.2, 0), SHADE)
root.Transparency = 1
model.PrimaryPart = root

local pelvis = part("Pelvis", Vector3.new(1.4, 0.4, 0.9), Vector3.new(0, 2.2, 0), SHADE)
motor("Root", root, pelvis, Vector3.new(0, 2.2, 0))

local torso = part("Torso", Vector3.new(1.7, 1.5, 1.0), Vector3.new(0, 3.15, 0), SHADE_L)
motor("Waist", pelvis, torso, Vector3.new(0, 2.4, 0))
weld(torso, part("Core", Vector3.new(0.42, 0.42, 0.1), Vector3.new(0, 3.3, -0.54), BLUE, Enum.Material.Neon))
weld(torso, part("CoreFrame", Vector3.new(0.6, 0.6, 0.08), Vector3.new(0, 3.3, -0.52), SHADE))
for _, x in ipairs({ -1, 1 }) do
	weld(torso, part("Pauldron", Vector3.new(0.9, 0.5, 1.0), Vector3.new(x * 1.05, 3.95, 0), SHADE))
	weld(torso, part("PauldronSpike", Vector3.new(0.16, 0.6, 0.16), Vector3.new(x * 1.15, 4.45, 0), CROWN))
	weld(torso, part("PauldronTip", Vector3.new(0.2, 0.12, 0.2), Vector3.new(x * 1.15, 4.8, 0), BLUE, Enum.Material.Neon))
end

-- tapering tail (no legs: it floats)
local tiers = { { "Tier1", 1.9, 0.5, 1.95 }, { "Tier2", 1.5, 0.5, 1.45 }, { "Tier3", 1.1, 0.45, 1.0 }, { "Tier4", 0.7, 0.4, 0.62 } }
for _, t in ipairs(tiers) do
	weld(pelvis, part(t[1], Vector3.new(t[2], t[3], t[2] * 0.65), Vector3.new(0, t[4], 0), SHADE))
end
for i, d in ipairs({ { -0.8, 1.4 }, { -0.27, 1.8 }, { 0.27, 1.6 }, { 0.8, 1.2 } }) do
	weld(pelvis, part("Ribbon" .. i, Vector3.new(0.3, d[2], 0.1), Vector3.new(d[1], 1.9 - d[2] / 2, 0.6), SHADE_L, nil, 0.4))
end

-- ── Head: blank black face, blazing eyes, crown of spikes ─────
local head = part("Head", Vector3.new(1.2, 1.3, 1.2), Vector3.new(0, 4.6, 0), SHADE)
motor("Neck", torso, head, Vector3.new(0, 3.9, 0))
weld(head, part("Face", Vector3.new(0.9, 0.9, 0.1), Vector3.new(0, 4.6, -0.64), VOID))
for _, x in ipairs({ -1, 1 }) do
	weld(head, part("Eye", Vector3.new(0.3, 0.12, 0.1), Vector3.new(x * 0.22, 4.72, -0.7), EYE, Enum.Material.Neon))
end
weld(head, part("CrownBand", Vector3.new(1.35, 0.2, 1.35), Vector3.new(0, 5.3, 0), CROWN))
for i, s in ipairs({ { -0.55, 0, 0.7 }, { -0.28, -0.5, 0.55 }, { 0, -0.6, 0.85 }, { 0.28, -0.5, 0.55 }, { 0.55, 0, 0.7 }, { 0, 0.55, 0.6 } }) do
	weld(head, part("CrownSpike" .. i, Vector3.new(0.16, s[3], 0.16), Vector3.new(s[1], 5.4 + s[3] / 2, s[2]), CROWN))
	weld(head, part("CrownTip" .. i, Vector3.new(0.14, 0.14, 0.14), Vector3.new(s[1], 5.4 + s[3] + 0.08, s[2]), BLUE, Enum.Material.Neon))
end

-- ── Arms: long sleeves and clawed hands; a glowing orb floats at the right hand ──
local function arm(side, x)
	local upper = part(side .. "UpperArm", Vector3.new(0.4, 1.0, 0.4), Vector3.new(x, 3.2, 0), SHADE)
	motor(side .. "Shoulder", torso, upper, Vector3.new(x, 3.7, 0))
	local fore = part(side .. "Forearm", Vector3.new(0.5, 0.95, 0.5), Vector3.new(x, 2.2, 0), SHADE_L)
	motor(side .. "Elbow", upper, fore, Vector3.new(x, 2.7, 0))
	weld(fore, part(side .. "Hand", Vector3.new(0.3, 0.3, 0.3), Vector3.new(x, 1.58, 0), SHADE))
	for _, dx in ipairs({ -0.1, 0, 0.1 }) do
		weld(fore, part(side .. "Claw", Vector3.new(0.05, 0.4, 0.05), Vector3.new(x + dx, 1.25, -0.05), BLUE, Enum.Material.Neon))
	end
	return fore
end
arm("L", -1.15)
local rFore = arm("R", 1.15)
local orb = part("Orb", Vector3.new(0.5, 0.5, 0.5), Vector3.new(1.15, 1.0, -0.45), BLUE, Enum.Material.Neon)
orb.Shape = Enum.PartType.Ball
weld(rFore, orb)

-- ── Wings: a feathered bar on each side, flapped by LWing/RWing ──
local function wing(side, sx)
	local rootPart = part(side .. "WingRoot", Vector3.new(0.3, 0.3, 0.3), Vector3.new(sx * 0.7, 4.0, 0.55), SHADE)
	motor(side .. "Wing", torso, rootPart, Vector3.new(sx * 0.6, 4.0, 0.5))
	weld(rootPart, part(side .. "WingBar", Vector3.new(2.4, 0.16, 0.16), Vector3.new(sx * 1.9, 4.3, 0.55), CROWN))
	for i, d in ipairs({ { 1.0, 2.6 }, { 1.5, 2.3 }, { 2.0, 2.0 }, { 2.5, 1.6 }, { 3.0, 1.2 } }) do
		weld(rootPart, part(side .. "Feather" .. i, Vector3.new(0.3, d[2], 0.06), Vector3.new(sx * d[1], 4.3 - d[2] / 2, 0.55), SHADE_L))
		weld(rootPart, part(side .. "FeatherTip" .. i, Vector3.new(0.2, 0.1, 0.08), Vector3.new(sx * d[1], 4.3 - d[2], 0.55), BLUE, Enum.Material.Neon))
	end
end
wing("L", -1)
wing("R", 1)

-- cold blue glow (no shadows, see CLAUDE.md)
local light = Instance.new("PointLight")
light.Name = "ShadeLight"
light.Color = BLUE
light.Brightness = 0.9
light.Range = 10
light.Shadows = false
light.Parent = torso

model:SetAttribute("Rig", "Procedural")
model:SetAttribute("RootHeight", 2.2)
model:SetAttribute("Height", 6.2)
model:SetAttribute("Float", 0.2)
model.Parent = models

local count = 0
for _, d in ipairs(model:GetDescendants()) do
	if d:IsA("Motor6D") then count += 1 end
end
return "ShadeLord built: " .. #model:GetChildren() .. " parts, " .. count .. " joints"
