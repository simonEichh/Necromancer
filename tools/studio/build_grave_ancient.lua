-- Builds the Ancient Tomb (grave tier 3) into ReplicatedStorage.GraveModels.Ancient, from the concept art
-- Images/Graves/tier3.png: a sandstone sarcophagus, four square corner pillars with stepped pyramid caps, dark inset
-- panels with carved diamond reliefs, a heavy cracked lid with a carved panel, amber light leaking from the seam under
-- the lid, sand drifted against the foot.
-- Run in Edit mode via the Studio MCP execute_luau (or loadstring over a local http.server, see CLAUDE.md). Safe to re-run.
--
-- Grave model conventions: see build_grave_mossy.lua (Body / Lid / Pit / Core, "Glow" parts, OpenStyle).
-- OpenStyle "Lid": the whole lid is blasted off in one piece and tumbles away (Modules/GraveOpening).
-- The tomb lies along X (its long side faces the camera, which looks from -Z).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local folder = ReplicatedStorage:FindFirstChild("GraveModels")
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "GraveModels"
	folder.Parent = ReplicatedStorage
end
local old = folder:FindFirstChild("Ancient")
if old then
	old:Destroy()
end

local SAND_DARK = Color3.fromRGB(124, 96, 62)
local SANDSTONE = Color3.fromRGB(164, 130, 86)
local SAND_LIGHT = Color3.fromRGB(184, 152, 104)
local INSET = Color3.fromRGB(74, 70, 68)
local CRACK = Color3.fromRGB(70, 52, 32)
local SAND = Color3.fromRGB(176, 138, 80)
local PEBBLE = Color3.fromRGB(110, 98, 88)
local GLOW = Color3.fromRGB(255, 150, 40) -- amber light

local model = Instance.new("Model")
model.Name = "Ancient"
local body = Instance.new("Model")
body.Name = "Body"
body.Parent = model
local lid = Instance.new("Model")
lid.Name = "Lid"
lid.Parent = model
local pit = Instance.new("Model")
pit.Name = "Pit"
pit.Parent = model

local function part(parent, name, size, cf, color, material, shape)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CastShadow = false
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.Sandstone
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if shape then
		p.Shape = shape
	end
	p.Parent = parent
	return p
end
local UPRIGHT = CFrame.Angles(0, 0, math.rad(90))

-- a frame lying in a face with outward normal `normal` (X = along the face, Y = up, Z = into the stone)
local function faceFrame(pos, normal)
	return CFrame.fromMatrix(pos, normal:Cross(Vector3.yAxis), Vector3.yAxis)
end
-- a carved diamond on a face: a raised diamond and (optionally) a diamond outline round it
local function diamond(parent, cf, size, ring)
	local d = cf * CFrame.Angles(0, 0, math.rad(45))
	part(parent, "Relief", Vector3.new(size, size, 0.1), d, SANDSTONE)
	if ring then
		local w = 0.09
		for _, s in ipairs({ -1, 1 }) do
			part(parent, "Relief", Vector3.new(ring + w, w, 0.1), d * CFrame.new(0, s * ring / 2, 0), SANDSTONE)
			part(parent, "Relief", Vector3.new(w, ring, 0.1), d * CFrame.new(s * ring / 2, 0, 0), SANDSTONE)
		end
	end
end
-- a slab along the edge a -> b of a closed outline (top view), `t` thick towards the inside
local function edgeSlab(parent, name, a, b, t, h, y, color, material)
	local along = (b - a).Unit
	local inward = Vector3.new(-along.Z, 0, along.X)
	if inward:Dot(-(a + b) / 2) < 0 then
		inward = -inward
	end
	local mid = (a + b) / 2 + inward * (t / 2)
	return part(parent, name, Vector3.new((b - a).Magnitude, h, t), CFrame.fromMatrix(Vector3.new(mid.X, y, mid.Z), along, Vector3.yAxis), color, material)
end

-- box: walls span X +-2.7 and Z +-1.6, pillars stand on the corners (centres +-3.2, +-1.7)
local HX, HZ = 2.7, 1.6
local PX, PZ, PW = 3.2, 1.7, 1.0
local WALL_Y0, WALL_Y1 = 0.5, 1.8
local WALL_T = 0.35

-- ============================================================
-- Ground patch (PrimaryPart) and the pit (the tomb's dark inside)
-- ============================================================
local base = part(body, "Base", Vector3.new(0.2, 9.4, 9.4), CFrame.new(0, 0.1, 0) * UPRIGHT, Color3.fromRGB(92, 74, 52), Enum.Material.Sand, Enum.PartType.Cylinder)
model.PrimaryPart = base
base.PivotOffset = base.CFrame:Inverse() -- pivot on the floor centre, upright
part(pit, "PitFloor", Vector3.new(4.6, 0.05, 2.4), CFrame.new(0, 0.52, 0), Color3.fromRGB(10, 8, 6), Enum.Material.SmoothPlastic)
for _, c in ipairs({ { -1.5, 0.4, 1.3, 25 }, { 0.5, -0.4, 1.1, -40 }, { 1.7, 0.3, 0.8, 65 } }) do
	part(pit, "Glow", Vector3.new(c[3], 0.03, 0.08), CFrame.new(c[1], 0.56, c[2]) * CFrame.Angles(0, math.rad(c[4]), 0), GLOW, Enum.Material.Neon)
end
local core = part(model, "Core", Vector3.new(0.4, 0.4, 0.4), CFrame.new(0, 0.9, 0), GLOW, Enum.Material.Neon)
core.Transparency = 1

-- ============================================================
-- Body: plinth, four walls with dark carved panels, a rim band
-- ============================================================
part(body, "Plinth", Vector3.new(5.9, 0.3, 3.7), CFrame.new(0, 0.35, 0), SAND_DARK)
local WALL_H = WALL_Y1 - WALL_Y0
local WALL_YC = WALL_Y0 + WALL_H / 2
for _, s in ipairs({ -1, 1 }) do
	part(body, "Wall", Vector3.new(2 * HX - 2 * WALL_T, WALL_H, WALL_T), CFrame.new(0, WALL_YC, s * (HZ - WALL_T / 2)), SANDSTONE)
	part(body, "Wall", Vector3.new(WALL_T, WALL_H, 2 * HZ), CFrame.new(s * (HX - WALL_T / 2), WALL_YC, 0), SANDSTONE)
	-- the rim band along the top edge of the long walls
	part(body, "Rim", Vector3.new(2 * HX - 0.4, 0.18, WALL_T + 0.12), CFrame.new(0, WALL_Y1 - 0.09, s * (HZ - WALL_T / 2 + 0.06)), SAND_LIGHT)
end

-- a dark panel set into a face, with a sandstone frame round it
local function facePanel(center, normal, w, h)
	local cf = faceFrame(center, normal)
	part(body, "Inset", Vector3.new(w, h, 0.06), cf * CFrame.new(0, 0, -0.01), INSET, Enum.Material.Slate)
	local f = 0.12
	for _, s in ipairs({ -1, 1 }) do
		part(body, "Frame", Vector3.new(w + 2 * f, f, 0.1), cf * CFrame.new(0, s * (h + f) / 2, -0.02), SANDSTONE)
		part(body, "Frame", Vector3.new(f, h, 0.1), cf * CFrame.new(s * (w + f) / 2, 0, -0.02), SANDSTONE)
	end
	return cf
end
local PANEL_Y, PANEL_H = WALL_Y0 + 0.55, 0.78
for _, s in ipairs({ -1, 1 }) do
	-- long faces (front -Z, back +Z): two diamond motifs and a divider between them
	local n = Vector3.new(0, 0, s)
	local cf = facePanel(Vector3.new(0, PANEL_Y, s * (HZ + 0.03)), n, 4.4, PANEL_H)
	part(body, "Frame", Vector3.new(0.12, PANEL_H, 0.1), cf * CFrame.new(0, 0, -0.02), SANDSTONE)
	diamond(body, cf * CFrame.new(-1.1, 0, -0.04), 0.3, 0.58)
	diamond(body, cf * CFrame.new(1.1, 0, -0.04), 0.3, 0.58)
	for _, dx in ipairs({ -1.85, -0.38, 0.38, 1.85 }) do
		diamond(body, cf * CFrame.new(dx, 0, -0.04), 0.16)
	end
	-- short faces (the ends): one diamond motif
	local ncf = facePanel(Vector3.new(s * (HX + 0.03), PANEL_Y, 0), Vector3.new(s, 0, 0), 2.0, PANEL_H)
	diamond(body, ncf * CFrame.new(0, 0, -0.04), 0.3, 0.58)
end

-- ============================================================
-- Corner pillars: foot, shaft with carved panels, capital, a block with a dark niche, stepped pyramid cap
-- ============================================================
for _, sx in ipairs({ -1, 1 }) do
	for _, sz in ipairs({ -1, 1 }) do
		local x, z = sx * PX, sz * PZ
		part(body, "PillarFoot", Vector3.new(PW + 0.25, 0.35, PW + 0.25), CFrame.new(x, 0.375, z), SAND_DARK)
		part(body, "Pillar", Vector3.new(PW, 1.95, PW), CFrame.new(x, 0.55 + 1.95 / 2, z), SANDSTONE)
		part(body, "Capital", Vector3.new(PW + 0.2, 0.2, PW + 0.2), CFrame.new(x, 2.6, z), SAND_LIGHT)
		part(body, "PillarTop", Vector3.new(PW, 0.5, PW), CFrame.new(x, 2.95, z), SANDSTONE)
		part(body, "Cap", Vector3.new(PW + 0.2, 0.15, PW + 0.2), CFrame.new(x, 3.275, z), SAND_LIGHT)
		local y = 3.35
		for i, w in ipairs({ 0.9, 0.62, 0.34 }) do
			local h = (i == 3) and 0.14 or 0.15
			part(body, "Pyramid", Vector3.new(w, h, w), CFrame.new(x, y + h / 2, z), (i == 1) and SANDSTONE or SAND_LIGHT)
			y += h
		end
		-- the two outward faces: a tall dark panel with a diamond on the shaft, a dark niche in the top block
		for _, n in ipairs({ Vector3.new(sx, 0, 0), Vector3.new(0, 0, sz) }) do
			local c = Vector3.new(x, 0, z) + n * (PW / 2 + 0.02)
			local cf = faceFrame(c + Vector3.new(0, 1.5, 0), n)
			part(body, "Inset", Vector3.new(0.6, 1.4, 0.06), cf, INSET, Enum.Material.Slate)
			diamond(body, cf * CFrame.new(0, 0, -0.03), 0.3)
			part(body, "Niche", Vector3.new(0.5, 0.28, 0.06), faceFrame(c + Vector3.new(0, 2.92, 0), n), INSET, Enum.Material.Slate)
		end
	end
end

-- the light seam under the lid
local SEAM_Y = WALL_Y1 + 0.03
for _, s in ipairs({ -1, 1 }) do
	part(body, "Glow", Vector3.new(2 * HX - 0.5, 0.06, 0.06), CFrame.new(0, SEAM_Y, s * (HZ + 0.02)), GLOW, Enum.Material.Neon)
	part(body, "Glow", Vector3.new(0.06, 0.06, 2 * HZ - 0.5), CFrame.new(s * (HX + 0.02), SEAM_Y, 0), GLOW, Enum.Material.Neon)
end

-- ============================================================
-- Lid: a heavy slab notched round the pillars, a carved panel, cracks running over the top and down the edges
-- ============================================================
local LID_Y0, LID_H = SEAM_Y + 0.04, 0.6
local LID_TOP = LID_Y0 + LID_H
local LID_YC = LID_Y0 + LID_H / 2
part(lid, "LidSlab", Vector3.new(2 * HX - 0.1, LID_H, 2 * HZ + 0.15), CFrame.new(0, LID_YC, 0), SAND_LIGHT)
part(lid, "LidSlab", Vector3.new(2 * HX + 0.5, LID_H, 2 * (PZ - PW / 2) - 0.1), CFrame.new(0, LID_YC, 0), SAND_LIGHT)
-- the carved panel: a groove in an elongated octagon, the panel inside raised a little
local OCT = {
	Vector3.new(2.15, 0, -0.45), Vector3.new(2.15, 0, 0.45), Vector3.new(1.7, 0, 0.9), Vector3.new(-1.7, 0, 0.9),
	Vector3.new(-2.15, 0, 0.45), Vector3.new(-2.15, 0, -0.45), Vector3.new(-1.7, 0, -0.9), Vector3.new(1.7, 0, -0.9),
}
for i = 1, #OCT do
	edgeSlab(lid, "Groove", OCT[i], OCT[i % #OCT + 1], 0.13, 0.04, LID_TOP + 0.005, INSET, Enum.Material.SmoothPlastic)
end
part(lid, "Panel", Vector3.new(3.5, 0.06, 1.3), CFrame.new(0, LID_TOP + 0.02, 0), SANDSTONE)
part(lid, "Panel", Vector3.new(4.0, 0.06, 0.62), CFrame.new(0, LID_TOP + 0.02, 0), SANDSTONE)
-- cracks over the top
for _, c in ipairs({ { -1.4, 0.35, 1.2, 70 }, { 1.0, -0.5, 1.0, -60 }, { 2.4, 0.9, 0.7, 80 }, { -2.5, -0.9, 0.6, -75 } }) do
	part(lid, "Crack", Vector3.new(c[3], 0.04, 0.06), CFrame.new(c[1], LID_TOP + 0.06, c[2]) * CFrame.Angles(0, math.rad(c[4]), 0), CRACK, Enum.Material.SmoothPlastic)
end
-- cracks running down the lid's front and back edges
for _, c in ipairs({ { -1.9, -1 }, { 0.6, -1 }, { 1.8, -1 }, { -0.9, 1 }, { 1.4, 1 } }) do
	part(lid, "Crack", Vector3.new(0.06, LID_H + 0.02, 0.04), CFrame.new(c[1], LID_YC, c[2] * (HZ + 0.1)) * CFrame.Angles(0, 0, math.rad(8)), CRACK, Enum.Material.SmoothPlastic)
end

-- ============================================================
-- Sand drifted against the foot, a few pebbles
-- ============================================================
for _, c in ipairs({ { -3.0, -2.6, 2.4, 1.6 }, { 1.2, -2.3, 2.0, 1.2 }, { 3.6, 0.6, 1.4, 2.2 }, { -3.9, 1.2, 1.2, 1.8 }, { -0.6, 2.4, 2.2, 1.1 } }) do
	part(body, "Sand", Vector3.new(c[3] * 1.3, 0.7, c[4] * 1.3), CFrame.new(c[1], 0.18, c[2]), SAND, Enum.Material.Sand, Enum.PartType.Ball)
end
for _, c in ipairs({ { -2.4, -2.9, 0.3 }, { -3.7, -2.2, 0.22 }, { 2.0, -2.7, 0.26 }, { 4.1, 1.4, 0.2 } }) do
	part(body, "Pebble", Vector3.new(c[3] * 1.3, c[3], c[3]), CFrame.new(c[1], 0.3, c[2]), PEBBLE, Enum.Material.Slate, Enum.PartType.Ball)
end

-- ============================================================
-- Attributes and placement
-- ============================================================
model:SetAttribute("OpenStyle", "Lid")
-- the risen unit hops out over the front wall and lands HopOut studs in front of the Core (Modules/GraveCinematic)
model:SetAttribute("HopOut", 3.0)
model:SetAttribute("FloorHeight", 0.5)
model:SetAttribute("WallTop", SEAM_Y)
model:SetAttribute("GlowColor", GLOW)
model:SetAttribute("DebrisColor", SANDSTONE)
model:SetAttribute("Height", 3.6)
model.Parent = folder

-- a preview next to the other graves' (behind the hub spawn); delete Workspace.GravePreview before publishing
local preview = workspace:FindFirstChild("GravePreview")
if not preview then
	preview = Instance.new("Folder")
	preview.Name = "GravePreview"
	preview.Parent = workspace
end
local oldCopy = preview:FindFirstChild("Ancient")
if oldCopy then
	oldCopy:Destroy()
end
local copy = model:Clone()
copy:PivotTo(CFrame.new(20, -1.7, 40))
copy.Parent = preview

local count = 0
for _, d in ipairs(model:GetDescendants()) do
	if d:IsA("BasePart") then count += 1 end
end
return "Ancient tomb built: " .. count .. " parts"
