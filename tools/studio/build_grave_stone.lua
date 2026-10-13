-- Builds the Stone Coffin (grave tier 2) into ReplicatedStorage.GraveModels.Stone, from the concept art
-- Images/Graves/stoneCoffin.png: a plain grey stone coffin lying flat, a heavy lid with a carved coffin-shaped panel,
-- iron brackets with rivets on every corner, cracks, and pale white light leaking from the seam under the lid.
-- Run in Edit mode via the Studio MCP execute_luau (or loadstring over a local http.server, see CLAUDE.md). Safe to re-run.
--
-- Grave model conventions: see build_grave_mossy.lua (Body / Lid / Pit / Core, "Glow" parts, OpenStyle).
-- OpenStyle "Lid": the whole lid is blasted off in one piece and tumbles away (Modules/GraveOpening).
-- The coffin lies along X (its long side faces the camera, which looks from -Z); head end at +X.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local folder = ReplicatedStorage:FindFirstChild("GraveModels")
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "GraveModels"
	folder.Parent = ReplicatedStorage
end
local old = folder:FindFirstChild("Stone")
if old then
	old:Destroy()
end

local STONE_DARK = Color3.fromRGB(78, 80, 92)
local STONE = Color3.fromRGB(112, 114, 128)
local STONE_LIGHT = Color3.fromRGB(140, 142, 156)
local IRON = Color3.fromRGB(58, 54, 52)
local RIVET = Color3.fromRGB(96, 90, 84)
local CRACK = Color3.fromRGB(40, 40, 48)
local GROUND = Color3.fromRGB(56, 48, 44)
local GLOW = Color3.fromRGB(225, 235, 255) -- pale white light

local model = Instance.new("Model")
model.Name = "Stone"
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
	p.Material = material or Enum.Material.Slate
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if shape then
		p.Shape = shape
	end
	p.Parent = parent
	return p
end
local UPRIGHT = CFrame.Angles(0, 0, math.rad(90))

-- the coffin outline (top view): head end at +X, wide shoulders, narrower foot
local function outline(scale)
	scale = scale or 1
	local pts = {
		Vector3.new(3.2, 0, 1.0), Vector3.new(1.8, 0, 1.6), Vector3.new(-3.2, 0, 1.0),
		Vector3.new(-3.2, 0, -1.0), Vector3.new(1.8, 0, -1.6), Vector3.new(3.2, 0, -1.0),
	}
	for i, p in ipairs(pts) do
		pts[i] = p * scale
	end
	return pts
end
-- a slab along the edge a -> b (top view), `t` thick towards the inside, `h` high, centred at height y
local function edgeSlab(parent, name, a, b, t, h, y, color, material, outward)
	local along = (b - a).Unit
	local inward = Vector3.new(-along.Z, 0, along.X) -- (the outline runs clockwise seen from above: the left side is inside)
	if inward:Dot(-(a + b) / 2) < 0 then
		inward = -inward
	end
	local mid = (a + b) / 2 + inward * (t / 2) - inward * (outward or 0)
	return part(parent, name, Vector3.new((b - a).Magnitude, h, t), CFrame.fromMatrix(Vector3.new(mid.X, y, mid.Z), along, Vector3.yAxis), color, material)
end

-- ============================================================
-- Ground patch (PrimaryPart) and the pit (the coffin's dark inside)
-- ============================================================
local base = part(body, "Base", Vector3.new(0.2, 8.4, 8.4), CFrame.new(0, 0.1, 0) * UPRIGHT, GROUND, Enum.Material.Ground, Enum.PartType.Cylinder)
model.PrimaryPart = base
base.PivotOffset = base.CFrame:Inverse() -- pivot on the floor centre, upright
part(pit, "PitFloor", Vector3.new(6.2, 0.05, 2.6), CFrame.new(-0.1, 0.52, 0), Color3.fromRGB(8, 8, 10), Enum.Material.SmoothPlastic)
for _, c in ipairs({ { -1.8, 0.3, 1.4, 20 }, { 0.6, -0.4, 1.2, -35 }, { 2.0, 0.2, 0.9, 60 } }) do
	part(pit, "Glow", Vector3.new(c[3], 0.03, 0.08), CFrame.new(c[1], 0.56, c[2]) * CFrame.Angles(0, math.rad(c[4]), 0), GLOW, Enum.Material.Neon)
end
local core = part(model, "Core", Vector3.new(0.4, 0.4, 0.4), CFrame.new(0, 0.9, 0), GLOW, Enum.Material.Neon)
core.Transparency = 1

-- ============================================================
-- Body: a low plinth, the walls following the coffin outline, iron corner brackets
-- ============================================================
local OUT = outline(1)
local PLINTH = outline(1.08)
for i = 1, 6 do
	edgeSlab(body, "Plinth", PLINTH[i], PLINTH[i % 6 + 1], 0.9, 0.3, 0.35, STONE_DARK, Enum.Material.Slate)
end
part(body, "PlinthFill", Vector3.new(6.6, 0.3, 2.2), CFrame.new(0, 0.35, 0), STONE_DARK, Enum.Material.Slate)
local WALL_Y0, WALL_H = 0.5, 1.15
for i = 1, 6 do
	edgeSlab(body, "Wall", OUT[i], OUT[i % 6 + 1], 0.4, WALL_H, WALL_Y0 + WALL_H / 2, STONE, Enum.Material.Slate)
end
-- iron brackets: an L of two plates round every corner, rivets on each plate
local function bracket(parent, v, prev, nxt, y, h)
	local d1 = (prev - v).Unit
	local d2 = (nxt - v).Unit
	for _, d in ipairs({ d1, d2 }) do
		local outward = Vector3.new(-d.Z, 0, d.X)
		if outward:Dot(v) < 0 then
			outward = -outward
		end
		local c = v + d * 0.3 + outward * 0.04
		local cf = CFrame.fromMatrix(Vector3.new(c.X, y, c.Z), d, Vector3.yAxis)
		part(parent, "Bracket", Vector3.new(0.62, h, 0.1), cf, IRON, Enum.Material.Metal)
		for _, ry in ipairs({ -h * 0.28, h * 0.28 }) do
			part(parent, "Rivet", Vector3.new(0.16, 0.16, 0.16), cf * CFrame.new(0.05, ry, -0.0) + outward * 0.07, RIVET, Enum.Material.Metal, Enum.PartType.Ball)
		end
	end
end
for i = 1, 6 do
	bracket(body, OUT[i], OUT[(i - 2) % 6 + 1], OUT[i % 6 + 1], WALL_Y0 + WALL_H / 2, WALL_H)
end

-- the light seam under the lid
local SEAM_Y = WALL_Y0 + WALL_H + 0.03
for i = 1, 6 do
	edgeSlab(body, "Glow", OUT[i], OUT[i % 6 + 1], 0.06, 0.06, SEAM_Y, GLOW, Enum.Material.Neon, 0.05)
end

-- ============================================================
-- Lid: a heavy slab on the same outline, a carved coffin panel, cracks, its own corner brackets
-- ============================================================
local LID = outline(1.04)
local LID_Y0, LID_H = SEAM_Y + 0.04, 0.62
local LID_TOP = LID_Y0 + LID_H
part(lid, "LidFill", Vector3.new(6.4, LID_H, 2.0), CFrame.new(0, LID_Y0 + LID_H / 2, 0), STONE_LIGHT, Enum.Material.Slate)
for i = 1, 6 do
	edgeSlab(lid, "LidEdge", LID[i], LID[i % 6 + 1], 0.9, LID_H, LID_Y0 + LID_H / 2, STONE_LIGHT, Enum.Material.Slate)
end
-- the carved panel: a groove in the shape of a smaller coffin, the panel inside slightly darker
local PANEL = outline(0.72)
for i = 1, 6 do
	edgeSlab(lid, "Groove", PANEL[i], PANEL[i % 6 + 1], 0.12, 0.04, LID_TOP + 0.005, CRACK, Enum.Material.SmoothPlastic)
end
part(lid, "Panel", Vector3.new(4.2, 0.03, 1.2), CFrame.new(-0.1, LID_TOP + 0.003, 0), STONE, Enum.Material.Slate)
-- cracks over the lid
for _, c in ipairs({ { -1.6, 0.55, 1.1, 30 }, { 1.3, -0.4, 0.9, -50 }, { 2.4, 0.5, 0.6, 70 }, { -2.6, -0.5, 0.7, -20 } }) do
	part(lid, "Crack", Vector3.new(c[3], 0.03, 0.06), CFrame.new(c[1], LID_TOP + 0.01, c[2]) * CFrame.Angles(0, math.rad(c[4]), 0), CRACK, Enum.Material.SmoothPlastic)
end
for i = 1, 6 do
	bracket(lid, LID[i], LID[(i - 2) % 6 + 1], LID[i % 6 + 1], LID_Y0 + LID_H / 2, LID_H)
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
model:SetAttribute("Height", LID_TOP)
model.Parent = folder

-- a preview next to the Mossy Grave's (behind the hub spawn); delete Workspace.GravePreview before publishing
local preview = workspace:FindFirstChild("GravePreview")
if not preview then
	preview = Instance.new("Folder")
	preview.Name = "GravePreview"
	preview.Parent = workspace
end
local oldCopy = preview:FindFirstChild("Stone")
if oldCopy then
	oldCopy:Destroy()
end
local copy = model:Clone()
copy:PivotTo(CFrame.new(10, -1.7, 40))
copy.Parent = preview

local count = 0
for _, d in ipairs(model:GetDescendants()) do
	if d:IsA("BasePart") then count += 1 end
end
return "Stone coffin built: " .. count .. " parts"
