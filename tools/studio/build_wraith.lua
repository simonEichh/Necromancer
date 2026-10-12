-- Builds the low-poly rigged Wraith into ServerStorage.Models.Wraith.
-- Run in Studio's command bar / via the Studio MCP execute_luau (Edit mode).
-- The old Creator Store model is kept as Wraith_Old until the new one is approved.
--
-- Same rig conventions as build_skelly.lua (see src/client/Modules/UnitAnimator.lua):
--   * front = -Z, character's right = +X, root part = HumanoidRootPart at y = 2.2
--   * Motor6Ds named Root/Waist/Neck/LShoulder/RShoulder/LElbow/RElbow
--   * attributes: Rig = "Procedural", RootHeight, Height, Float (hover bob, see UnitAnimator)
-- A tall hooded shade: an empty black hood with two pale glowing eyes, spiked pauldrons, very long arms
-- ending in talons, and a ragged cloak that tapers into trailing ribbons instead of legs. It floats.
-- The body is opaque; only the thin trailing ribbons are translucent and they never overlap.
local ServerStorage = game:GetService("ServerStorage")
local models = ServerStorage.Models

local old = models:FindFirstChild("Wraith")
if old and old:GetAttribute("Rig") ~= "Procedural" then
	old.Name = "Wraith_Old"
elseif old then
	old:Destroy()
end

local CLOAK = Color3.fromRGB(46, 50, 68)
local CLOAK_DARK = Color3.fromRGB(28, 30, 42)
local STONE = Color3.fromRGB(150, 158, 178) -- light stone grey trim
local VOID = Color3.fromRGB(8, 8, 14)
local GLOW = Color3.fromRGB(190, 240, 255)
local BONE = Color3.fromRGB(206, 206, 194)

local model = Instance.new("Model")
model.Name = "Wraith"

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
local root = part("HumanoidRootPart", Vector3.new(1.2, 0.4, 0.8), Vector3.new(0, 2.2, 0), CLOAK)
root.Transparency = 1
model.PrimaryPart = root

local pelvis = part("Pelvis", Vector3.new(1.4, 0.4, 0.9), Vector3.new(0, 2.2, 0), CLOAK_DARK)
motor("Root", root, pelvis, Vector3.new(0, 2.2, 0))

local torso = part("Torso", Vector3.new(1.5, 1.4, 0.95), Vector3.new(0, 3.1, 0), CLOAK)
motor("Waist", pelvis, torso, Vector3.new(0, 2.4, 0))
weld(torso, part("Clasp", Vector3.new(0.3, 0.3, 0.1), Vector3.new(0, 3.55, -0.5), GLOW, Enum.Material.Neon))
weld(torso, part("TrimFront", Vector3.new(0.18, 1.3, 0.06), Vector3.new(0, 3.1, -0.5), STONE))

-- spiked pauldrons
for _, x in ipairs({ -1, 1 }) do
	weld(torso, part("Pauldron", Vector3.new(0.7, 0.4, 1.0), Vector3.new(x * 1.0, 3.85, 0), CLOAK_DARK))
	weld(torso, part("Spike", Vector3.new(0.18, 0.55, 0.18), Vector3.new(x * 1.12, 4.2, 0), STONE))
end

-- cloak: tiers that taper to a point (no legs: it floats)
local tiers = {
	{ "Tier1", 1.7, 0.5, 1.95 },
	{ "Tier2", 1.4, 0.5, 1.45 },
	{ "Tier3", 1.0, 0.45, 1.0 },
	{ "Tier4", 0.6, 0.4, 0.62 },
}
for _, t in ipairs(tiers) do
	weld(pelvis, part(t[1], Vector3.new(t[2], t[3], t[2] * 0.65), Vector3.new(0, t[4], 0), CLOAK_DARK))
end
-- trailing ribbons (translucent, spaced apart so they never overlap)
for i, d in ipairs({ { -0.75, 1.5 }, { -0.25, 1.9 }, { 0.25, 1.7 }, { 0.75, 1.3 } }) do
	weld(pelvis, part("Ribbon" .. i, Vector3.new(0.3, d[2], 0.1), Vector3.new(d[1], 1.9 - d[2] / 2, 0.55), STONE, nil, 0.35))
end

-- ── Head: a black hood with an empty face and two eyes ────────
local head = part("Head", Vector3.new(1.3, 1.4, 1.3), Vector3.new(0, 4.55, 0), CLOAK_DARK)
motor("Neck", torso, head, Vector3.new(0, 3.8, 0))
weld(head, part("HoodPeak", Vector3.new(0.7, 0.5, 0.7), Vector3.new(0, 5.45, 0.25), CLOAK_DARK))
weld(head, part("HoodTail", Vector3.new(0.5, 0.9, 0.4), Vector3.new(0, 4.6, 0.8), CLOAK_DARK))
weld(head, part("Face", Vector3.new(0.92, 0.95, 0.1), Vector3.new(0, 4.6, -0.64), VOID))
weld(head, part("RimTop", Vector3.new(1.34, 0.16, 0.2), Vector3.new(0, 5.2, -0.62), STONE))
for _, x in ipairs({ -1, 1 }) do
	weld(head, part("RimSide", Vector3.new(0.16, 1.1, 0.2), Vector3.new(x * 0.54, 4.6, -0.62), STONE))
	weld(head, part("Eye", Vector3.new(0.2, 0.28, 0.1), Vector3.new(x * 0.22, 4.68, -0.7), GLOW, Enum.Material.Neon))
end

-- ── Arms: very long, dark sleeves and bone talons (character's right = +X) ──
local function arm(side, x)
	local upper = part(side .. "UpperArm", Vector3.new(0.34, 1.1, 0.34), Vector3.new(x, 3.05, 0), CLOAK)
	motor(side .. "Shoulder", torso, upper, Vector3.new(x, 3.6, 0))
	local fore = part(side .. "Forearm", Vector3.new(0.3, 1.1, 0.3), Vector3.new(x, 1.95, 0), CLOAK_DARK)
	motor(side .. "Elbow", upper, fore, Vector3.new(x, 2.5, 0))
	weld(fore, part(side .. "Cuff", Vector3.new(0.4, 0.16, 0.4), Vector3.new(x, 1.45, 0), STONE))
	weld(fore, part(side .. "Hand", Vector3.new(0.3, 0.3, 0.3), Vector3.new(x, 1.25, 0), BONE))
	for _, dx in ipairs({ -0.1, 0, 0.1 }) do
		weld(fore, part(side .. "Talon", Vector3.new(0.05, 0.6, 0.05), Vector3.new(x + dx, 0.82, -0.05), BONE))
	end
end
arm("L", -1.0)
arm("R", 1.0)

-- cold glow (no shadows, see CLAUDE.md)
local light = Instance.new("PointLight")
light.Name = "WraithLight"
light.Color = GLOW
light.Brightness = 0.7
light.Range = 9
light.Shadows = false
light.Parent = torso

model:SetAttribute("Rig", "Procedural")
model:SetAttribute("RootHeight", 2.2)
model:SetAttribute("Height", 5.8)
model:SetAttribute("Float", 0.18)
model.Parent = models

local count = 0
for _, d in ipairs(model:GetDescendants()) do
	if d:IsA("Motor6D") then count += 1 end
end
return "Wraith built: " .. #model:GetChildren() .. " parts, " .. count .. " joints"
