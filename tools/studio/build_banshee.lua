-- Builds the low-poly rigged Banshee into ServerStorage.Models.Banshee.
-- Run in Studio's command bar / via the Studio MCP execute_luau (Edit mode).
-- The old Creator Store model is kept as Banshee_Old until the new one is approved.
--
-- Same rig conventions as build_skelly.lua (see src/client/Modules/UnitAnimator.lua):
--   * front = -Z, character's right = +X, root part = HumanoidRootPart at y = 2.2
--   * Motor6Ds named Root/Waist/Neck/Jaw/LShoulder/RShoulder/LElbow/RElbow
--   * attributes: Rig = "Procedural", RootHeight, Height, Float (hover bob, see UnitAnimator)
-- A floating wailing spectre: pale face with glowing pink eyes and a screaming mouth, long black-violet
-- hair, clawed arms and a tattered gown that tapers away into rags instead of legs. The gown tiers are
-- opaque (the Ghost taught us that stacked translucent parts look bad).
local ServerStorage = game:GetService("ServerStorage")
local models = ServerStorage.Models

local old = models:FindFirstChild("Banshee")
if old and old:GetAttribute("Rig") ~= "Procedural" then
	old.Name = "Banshee_Old"
elseif old then
	old:Destroy()
end

local SKIN = Color3.fromRGB(226, 216, 240)
local SKIN_SHADE = Color3.fromRGB(190, 176, 214)
local HAIR = Color3.fromRGB(38, 22, 58)
local GOWN = Color3.fromRGB(92, 44, 124)
local GOWN_DARK = Color3.fromRGB(58, 26, 84)
local GLOW = Color3.fromRGB(255, 70, 170)
local HOLLOW = Color3.fromRGB(24, 10, 34)

local model = Instance.new("Model")
model.Name = "Banshee"

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
local root = part("HumanoidRootPart", Vector3.new(1.2, 0.4, 0.8), Vector3.new(0, 2.2, 0), GOWN)
root.Transparency = 1
model.PrimaryPart = root

local pelvis = part("Pelvis", Vector3.new(1.3, 0.4, 0.8), Vector3.new(0, 2.2, 0), GOWN_DARK)
motor("Root", root, pelvis, Vector3.new(0, 2.2, 0))

local torso = part("Torso", Vector3.new(1.3, 1.3, 0.8), Vector3.new(0, 3.05, 0), GOWN)
motor("Waist", pelvis, torso, Vector3.new(0, 2.4, 0))
weld(torso, part("Collar", Vector3.new(1.0, 0.2, 0.9), Vector3.new(0, 3.65, 0), GLOW, Enum.Material.Neon))
weld(torso, part("Sash", Vector3.new(1.36, 0.16, 0.86), Vector3.new(0, 2.55, 0), GOWN_DARK))

-- gown: tiers that taper away, ending in ragged tatters (no legs: it floats)
local tiers = {
	{ "Tier1", 1.5, 0.45, 1.95 },
	{ "Tier2", 1.2, 0.4, 1.5 },
	{ "Tier3", 0.9, 0.35, 1.1 },
}
for _, t in ipairs(tiers) do
	weld(pelvis, part(t[1], Vector3.new(t[2], t[3], t[2] * 0.7), Vector3.new(0, t[4], 0), GOWN_DARK))
end
for i, d in ipairs({ { -0.28, 0.5 }, { 0.0, 0.7 }, { 0.28, 0.45 } }) do
	weld(pelvis, part("Rag" .. i, Vector3.new(0.26, d[2], 0.3), Vector3.new(d[1], 0.92 - d[2] / 2, 0), GOWN))
end

-- ── Head: pale face, long hair, screaming mouth ───────────────
local head = part("Head", Vector3.new(1.0, 1.05, 1.0), Vector3.new(0, 4.35, 0), SKIN)
motor("Neck", torso, head, Vector3.new(0, 3.7, 0))
weld(head, part("HairTop", Vector3.new(1.12, 0.3, 1.12), Vector3.new(0, 4.92, 0.04), HAIR))
weld(head, part("HairBack", Vector3.new(1.4, 2.6, 0.3), Vector3.new(0, 3.65, 0.62), HAIR))
for _, x in ipairs({ -1, 1 }) do
	weld(head, part("HairSide", Vector3.new(0.28, 1.5, 0.5), Vector3.new(x * 0.68, 4.2, 0.28), HAIR))
	weld(head, part("HairStrand", Vector3.new(0.2, 0.9, 0.3), Vector3.new(x * 0.7, 3.2, 0.4), HAIR))
	weld(head, part("EyeHollow", Vector3.new(0.34, 0.3, 0.1), Vector3.new(x * 0.26, 4.45, -0.51), HOLLOW))
	weld(head, part("EyeGlow", Vector3.new(0.18, 0.14, 0.1), Vector3.new(x * 0.26, 4.45, -0.55), GLOW, Enum.Material.Neon))
end
local jaw = part("Jaw", Vector3.new(0.5, 0.45, 0.12), Vector3.new(0, 3.98, -0.5), HOLLOW)
motor("Jaw", head, jaw, Vector3.new(0, 4.2, -0.5))

-- ── Arms: thin, ending in long pink claws (character's right = +X) ──
local function arm(side, x)
	local upper = part(side .. "UpperArm", Vector3.new(0.28, 0.95, 0.28), Vector3.new(x, 3.075, 0), SKIN_SHADE)
	motor(side .. "Shoulder", torso, upper, Vector3.new(x, 3.55, 0))
	local fore = part(side .. "Forearm", Vector3.new(0.24, 0.9, 0.24), Vector3.new(x, 2.15, 0), SKIN)
	motor(side .. "Elbow", upper, fore, Vector3.new(x, 2.6, 0))
	weld(fore, part(side .. "Hand", Vector3.new(0.3, 0.26, 0.3), Vector3.new(x, 1.6, 0), SKIN))
	for _, dx in ipairs({ -0.1, 0, 0.1 }) do
		weld(fore, part(side .. "Claw", Vector3.new(0.05, 0.4, 0.05), Vector3.new(x + dx, 1.28, -0.06), GLOW, Enum.Material.Neon))
	end
end
arm("L", -0.85)
arm("R", 0.85)

-- faint pink glow (no shadows, see CLAUDE.md)
local light = Instance.new("PointLight")
light.Name = "BansheeLight"
light.Color = GLOW
light.Brightness = 0.9
light.Range = 9
light.Shadows = false
light.Parent = torso

model:SetAttribute("Rig", "Procedural")
model:SetAttribute("RootHeight", 2.2)
model:SetAttribute("Height", 5.2)
model:SetAttribute("Float", 0.15)
model.Parent = models

local count = 0
for _, d in ipairs(model:GetDescendants()) do
	if d:IsA("Motor6D") then count += 1 end
end
return "Banshee built: " .. #model:GetChildren() .. " parts, " .. count .. " joints"
