-- Builds the low-poly rigged Ghost into ServerStorage.Models.Ghost.
-- Run in Studio's command bar / via the Studio MCP execute_luau (Edit mode).
-- The old Creator Store model is kept as Ghost_Old until the new one is approved.
--
-- Same rig conventions as build_skelly.lua (see src/client/Modules/UnitAnimator.lua):
--   * front = -Z, root part = HumanoidRootPart at y = 2.2
--   * attributes: Rig = "Procedural", RootHeight, Height, Float (hover bob amplitude, see UnitAnimator)
-- Not humanoid: a translucent capsule (a cylinder with a rounded top) that floats above the floor.
-- It only has the Root and Waist joints: Root bobs it, Waist leans/sways the whole body (including the
-- glowing base ring) around its base, so the attack is a lunge.
-- The translucent body is built from stacked, NON-overlapping cylinders (the dome is a stepped stack of
-- shrinking cylinders): overlapping translucent parts show up as darker seams.
local ServerStorage = game:GetService("ServerStorage")
local models = ServerStorage.Models

local old = models:FindFirstChild("Ghost")
if old and old:GetAttribute("Rig") ~= "Procedural" then
	old.Name = "Ghost_Old"
elseif old then
	old:Destroy()
end

local SHEET = Color3.fromRGB(226, 236, 248)
local SHEET_SHADE = Color3.fromRGB(176, 196, 224)
local HOLLOW = Color3.fromRGB(20, 24, 40)
local GLOW = Color3.fromRGB(120, 230, 255)
local BODY_T = 0.25 -- body transparency

local BASE_Y = 0.9 -- bottom of the body: it floats this far above the floor
local RADIUS = 1.0
local RING_H = 0.18
local LOWER_H = 0.6 -- darker lower section
local BODY_TOP = 3.6 -- where the straight cylinder ends and the dome starts
local DOME_LAYERS = 5

local model = Instance.new("Model")
model.Name = "Ghost"

local function part(name, size, cf, color, material, transparency)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = typeof(cf) == "Vector3" and CFrame.new(cf) or cf
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

-- Cylinder parts have their axis along X, so rotate 90 degrees to stand them upright
local UPRIGHT = CFrame.Angles(0, 0, math.rad(90))
local function cylinder(name, diameter, height, bottomY, color, material, transparency)
	local p = part(name, Vector3.new(height, diameter, diameter), CFrame.new(0, bottomY + height / 2, 0) * UPRIGHT, color, material, transparency)
	p.Shape = Enum.PartType.Cylinder
	return p
end

-- ── Core ──────────────────────────────────────────────────────
local root = part("HumanoidRootPart", Vector3.new(1.2, 0.4, 0.8), Vector3.new(0, 2.2, 0), SHEET)
root.Transparency = 1
model.PrimaryPart = root

-- invisible anchor part: Root moves it, Waist tilts the whole visible body (ring included) above it
local pelvis = part("Pelvis", Vector3.new(0.4, 0.2, 0.4), Vector3.new(0, BASE_Y, 0), SHEET)
pelvis.Transparency = 1
motor("Root", root, pelvis, Vector3.new(0, BASE_Y, 0))

-- glowing base ring: the body's first part, so it tilts with the body
local body = cylinder("Base", RADIUS * 2 - 0.1, RING_H, BASE_Y, GLOW, Enum.Material.Neon, 0.1)
motor("Waist", pelvis, body, Vector3.new(0, BASE_Y, 0))

local lowerBottom = BASE_Y + RING_H
weld(body, cylinder("Lower", RADIUS * 2, LOWER_H, lowerBottom, SHEET_SHADE, nil, BODY_T + 0.1))
local midBottom = lowerBottom + LOWER_H
weld(body, cylinder("Mid", RADIUS * 2, BODY_TOP - midBottom, midBottom, SHEET, nil, BODY_T))

-- dome: stacked cylinders whose radius follows a circle
local layerH = RADIUS / DOME_LAYERS
for i = 1, DOME_LAYERS do
	local y = (i - 0.5) * layerH -- height of the layer's middle above the dome base
	local r = math.sqrt(RADIUS * RADIUS - y * y)
	weld(body, cylinder("Dome" .. i, r * 2, layerH, BODY_TOP + (i - 1) * layerH, SHEET, nil, BODY_T))
end

-- ── Eyes on the front (-Z) ─────────────────────────────────────
for _, x in ipairs({ -0.36, 0.36 }) do
	weld(body, part("EyeHollow", Vector3.new(0.36, 0.5, 0.12), Vector3.new(x, 3.3, -0.9), HOLLOW))
	weld(body, part("EyeGlow", Vector3.new(0.14, 0.22, 0.12), Vector3.new(x, 3.26, -0.95), GLOW, Enum.Material.Neon))
end

-- faint cold glow around the ghost (no shadows, see CLAUDE.md)
local light = Instance.new("PointLight")
light.Name = "GhostLight"
light.Color = GLOW
light.Brightness = 0.8
light.Range = 9
light.Shadows = false
light.Parent = body

model:SetAttribute("Rig", "Procedural")
model:SetAttribute("RootHeight", 2.2)
model:SetAttribute("Height", BODY_TOP + RADIUS)
model:SetAttribute("Float", 0.12)
model.Parent = models

local count = 0
for _, d in ipairs(model:GetDescendants()) do
	if d:IsA("Motor6D") then count += 1 end
end
return "Ghost built: " .. #model:GetChildren() .. " parts, " .. count .. " joints"
