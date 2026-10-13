-- Builds the Abyssal Tomb (grave tier 6) into ReplicatedStorage.GraveModels.Abyssal, from the concept art
-- Images/Graves/abyssal tomb.png: a black stone sarcophagus cracked all over with glowing magma veins, square corner pillars
-- with iron bands, rivets and a curved horn on top, glowing gem diamonds set in the stone, a lid of heavy blocks with lava in
-- the seams, and fire rising behind it.
-- Run in Edit mode via the Studio MCP execute_luau (or loadstring over a local http.server, see CLAUDE.md). Safe to re-run.
--
-- Grave model conventions: see build_grave_mossy.lua (Body / Lid / Pit / Core, "Glow" parts, OpenStyle).
-- OpenStyle "Lid": the whole lid is blasted off in one piece and tumbles away (Modules/GraveOpening).
-- The tomb lies along X (its long side faces the camera, which looks from -Z). Same layout as build_grave_ancient.lua.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local folder = ReplicatedStorage:FindFirstChild("GraveModels")
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "GraveModels"
	folder.Parent = ReplicatedStorage
end
local old = folder:FindFirstChild("Abyssal")
if old then
	old:Destroy()
end

local STONE_DARK = Color3.fromRGB(30, 29, 36)
local STONE = Color3.fromRGB(46, 44, 52)
local STONE_LIGHT = Color3.fromRGB(64, 61, 70)
local INSET = Color3.fromRGB(62, 22, 18) -- dark red stone, glowing from within
local IRON = Color3.fromRGB(64, 54, 50)
local RIVET = Color3.fromRGB(112, 92, 80)
local HORN = Color3.fromRGB(122, 104, 92)
local GROUND = Color3.fromRGB(34, 24, 22)
local GLOW = Color3.fromRGB(255, 84, 20) -- magma

local model = Instance.new("Model")
model.Name = "Abyssal"
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

-- a frame lying in a face with outward normal `normal` (X = along the face, Y = up, Z = into the stone)
local function faceFrame(pos, normal)
	return CFrame.fromMatrix(pos, normal:Cross(Vector3.yAxis), Vector3.yAxis)
end
-- a thin glowing vein from a to b (2D points in the face frame `cf`)
local function vein(parent, cf, a, b, width)
	local mid = (a + b) / 2
	local d = b - a
	part(parent, "Glow", Vector3.new(d.Magnitude + (width or 0.07), width or 0.07, 0.04),
		cf * CFrame.new(mid.X, mid.Y, -0.01) * CFrame.Angles(0, 0, math.atan2(d.Y, d.X)), GLOW, Enum.Material.Neon)
end
-- a web of magma veins over a w x h face: jittered nodes in a grid, each joined to its right and upper neighbour
local rng = Random.new(66)
local function veinWeb(parent, cf, w, h, cols, rows)
	local nodes = {}
	for i = 0, cols do
		nodes[i] = {}
		for j = 0, rows do
			local x = -w / 2 + w * i / cols
			local y = -h / 2 + h * j / rows
			if i > 0 and i < cols then x += rng:NextNumber(-0.25, 0.25) * w / cols end
			if j > 0 and j < rows then y += rng:NextNumber(-0.3, 0.3) * h / rows end
			nodes[i][j] = Vector2.new(x, y)
		end
	end
	for i = 0, cols do
		for j = 0, rows do
			if i < cols and j > 0 and j < rows then
				vein(parent, cf, nodes[i][j], nodes[i + 1][j])
			end
			if j < rows and i > 0 and i < cols and rng:NextNumber() < 0.75 then
				vein(parent, cf, nodes[i][j], nodes[i][j + 1])
			end
		end
	end
end
-- a glowing gem: a stone diamond frame with a magma diamond inside
local function gem(parent, cf, size)
	local d = cf * CFrame.Angles(0, 0, math.rad(45))
	part(parent, "GemFrame", Vector3.new(size, size, 0.1), d * CFrame.new(0, 0, -0.03), IRON, Enum.Material.Metal)
	part(parent, "Glow", Vector3.new(size * 0.55, size * 0.55, 0.06), d * CFrame.new(0, 0, -0.08), GLOW, Enum.Material.Neon)
end

-- box: walls span X +-2.7 and Z +-1.6, pillars stand on the corners (centres +-3.2, +-1.7)
local HX, HZ = 2.7, 1.6
local PX, PZ, PW = 3.2, 1.7, 1.0
local WALL_Y0, WALL_Y1 = 0.5, 1.8
local WALL_T = 0.35

-- ============================================================
-- Ground patch (PrimaryPart), scorched cracks in it, the pit (the tomb's glowing inside)
-- ============================================================
local base = part(body, "Base", Vector3.new(0.2, 9.4, 9.4), CFrame.new(0, 0.1, 0) * UPRIGHT, GROUND, Enum.Material.CrackedLava, Enum.PartType.Cylinder)
model.PrimaryPart = base
base.PivotOffset = base.CFrame:Inverse() -- pivot on the floor centre, upright
part(pit, "PitFloor", Vector3.new(4.6, 0.05, 2.4), CFrame.new(0, 0.52, 0), Color3.fromRGB(14, 6, 4), Enum.Material.SmoothPlastic)
for _, c in ipairs({ { -1.5, 0.4, 1.3, 25 }, { 0.5, -0.4, 1.1, -40 }, { 1.7, 0.3, 0.8, 65 }, { -0.4, 0.5, 0.9, 80 } }) do
	part(pit, "Glow", Vector3.new(c[3], 0.03, 0.09), CFrame.new(c[1], 0.56, c[2]) * CFrame.Angles(0, math.rad(c[4]), 0), GLOW, Enum.Material.Neon)
end
local core = part(model, "Core", Vector3.new(0.4, 0.4, 0.4), CFrame.new(0, 0.9, 0), GLOW, Enum.Material.Neon)
core.Transparency = 1

-- ============================================================
-- Body: plinth, four walls with magma-veined red panels, a rim band, gems
-- ============================================================
part(body, "Plinth", Vector3.new(5.9, 0.3, 3.7), CFrame.new(0, 0.35, 0), STONE_DARK)
local WALL_H = WALL_Y1 - WALL_Y0
local WALL_YC = WALL_Y0 + WALL_H / 2
for _, s in ipairs({ -1, 1 }) do
	part(body, "Wall", Vector3.new(2 * HX - 2 * WALL_T, WALL_H, WALL_T), CFrame.new(0, WALL_YC, s * (HZ - WALL_T / 2)), STONE)
	part(body, "Wall", Vector3.new(WALL_T, WALL_H, 2 * HZ), CFrame.new(s * (HX - WALL_T / 2), WALL_YC, 0), STONE)
	part(body, "Rim", Vector3.new(2 * HX - 0.4, 0.2, WALL_T + 0.12), CFrame.new(0, WALL_Y1 - 0.1, s * (HZ - WALL_T / 2 + 0.06)), STONE_LIGHT)
end
local PANEL_Y, PANEL_H = WALL_Y0 + 0.5, 0.75
for _, s in ipairs({ -1, 1 }) do
	-- long faces: a red panel full of veins, a gem in the middle
	local cf = faceFrame(Vector3.new(0, PANEL_Y, s * (HZ + 0.03)), Vector3.new(0, 0, s))
	part(body, "Inset", Vector3.new(4.5, PANEL_H, 0.06), cf, INSET, Enum.Material.Slate)
	veinWeb(body, cf * CFrame.new(0, 0, -0.03), 4.5, PANEL_H, 6, 2)
	gem(body, cf * CFrame.new(0, 0, -0.04), 0.5)
	-- short faces
	local ncf = faceFrame(Vector3.new(s * (HX + 0.03), PANEL_Y, 0), Vector3.new(s, 0, 0))
	part(body, "Inset", Vector3.new(2.1, PANEL_H, 0.06), ncf, INSET, Enum.Material.Slate)
	veinWeb(body, ncf * CFrame.new(0, 0, -0.03), 2.1, PANEL_H, 3, 2)
	-- veins in the rim band and the plinth
	local rcf = faceFrame(Vector3.new(0, WALL_Y1 - 0.4, s * (HZ + 0.02)), Vector3.new(0, 0, s))
	vein(body, rcf, Vector2.new(-1.8, 0.05), Vector2.new(-1.1, -0.1))
	vein(body, rcf, Vector2.new(0.9, -0.08), Vector2.new(1.9, 0.06))
	local pcf = faceFrame(Vector3.new(0, 0.35, s * 1.86), Vector3.new(0, 0, s))
	vein(body, pcf, Vector2.new(-2.4, 0.05), Vector2.new(-1.2, -0.06))
	vein(body, pcf, Vector2.new(0.4, -0.04), Vector2.new(1.6, 0.07))
end

-- ============================================================
-- Corner pillars: foot, shaft with gems, iron bands with rivets, a curved horn on top
-- ============================================================
local function horn(base, inward)
	-- tapering segments, each turned a little further towards `inward`, so the horn curves over the tomb
	local axis = Vector3.yAxis:Cross(inward).Unit
	local cf = CFrame.new(base)
	local widths = { 0.6, 0.5, 0.4, 0.3, 0.2, 0.11 }
	for i, w in ipairs(widths) do
		local len = 0.5
		local seg = cf * CFrame.new(0, len / 2, 0)
		part(body, "Horn", Vector3.new(w, len + 0.08, w), seg, (i <= 2) and IRON or HORN, (i <= 2) and Enum.Material.Metal or Enum.Material.Slate)
		cf = cf * CFrame.new(0, len, 0) * CFrame.fromAxisAngle(cf:VectorToObjectSpace(axis), math.rad(13))
	end
end
for _, sx in ipairs({ -1, 1 }) do
	for _, sz in ipairs({ -1, 1 }) do
		local x, z = sx * PX, sz * PZ
		part(body, "PillarFoot", Vector3.new(PW + 0.3, 0.4, PW + 0.3), CFrame.new(x, 0.4, z), STONE_DARK)
		part(body, "Pillar", Vector3.new(PW, 1.9, PW), CFrame.new(x, 0.6 + 1.9 / 2, z), STONE)
		part(body, "Band", Vector3.new(PW + 0.16, 0.22, PW + 0.16), CFrame.new(x, 1.75, z), IRON, Enum.Material.Metal)
		part(body, "Band", Vector3.new(PW + 0.22, 0.32, PW + 0.22), CFrame.new(x, 2.55, z), IRON, Enum.Material.Metal)
		part(body, "Cap", Vector3.new(PW * 0.8, 0.25, PW * 0.8), CFrame.new(x, 2.83, z), STONE_LIGHT)
		for _, n in ipairs({ Vector3.new(sx, 0, 0), Vector3.new(0, 0, sz) }) do
			local c = Vector3.new(x, 0, z) + n * (PW / 2 + 0.02)
			gem(body, faceFrame(c + Vector3.new(0, 1.15, 0), n), 0.42)
			-- rivets on the upper band
			for _, off in ipairs({ -0.3, 0.3 }) do
				local f = faceFrame(c + Vector3.new(0, 2.55, 0) + n * 0.11, n)
				part(body, "Rivet", Vector3.new(0.13, 0.13, 0.13), f * CFrame.new(off, 0, -0.02), RIVET, Enum.Material.Metal, Enum.PartType.Ball)
			end
		end
		-- the horn curves in over the tomb (towards its middle, along the long side)
		horn(Vector3.new(x, 2.9, z), Vector3.new(-sx, 0, -sz * 0.35).Unit)
	end
end

-- the magma seam under the lid
local SEAM_Y = WALL_Y1 + 0.03
for _, s in ipairs({ -1, 1 }) do
	part(body, "Glow", Vector3.new(2 * HX - 0.4, 0.08, 0.08), CFrame.new(0, SEAM_Y, s * (HZ + 0.03)), GLOW, Enum.Material.Neon)
	part(body, "Glow", Vector3.new(0.08, 0.08, 2 * HZ - 0.4), CFrame.new(s * (HX + 0.03), SEAM_Y, 0), GLOW, Enum.Material.Neon)
end

-- ============================================================
-- Lid: a heavy slab notched round the pillars, raised stone blocks on top with magma in the seams between them
-- ============================================================
local LID_Y0, LID_H = SEAM_Y + 0.05, 0.55
local LID_TOP = LID_Y0 + LID_H
local LID_YC = LID_Y0 + LID_H / 2
part(lid, "LidSlab", Vector3.new(2 * HX - 0.1, LID_H, 2 * HZ + 0.15), CFrame.new(0, LID_YC, 0), STONE_LIGHT)
part(lid, "LidSlab", Vector3.new(2 * HX + 0.5, LID_H, 2 * (PZ - PW / 2) - 0.1), CFrame.new(0, LID_YC, 0), STONE_LIGHT)
-- the top: blocks of different sizes with glowing gaps between them
local blocks = {
	{ -1.95, -0.75, 1.3, 1.25 }, { -1.95, 0.7, 1.3, 1.3 }, { -0.2, -0.45, 2.0, 1.9 }, { -0.2, 1.05, 2.0, 0.85 },
	{ 1.65, -0.85, 1.5, 1.05 }, { 1.65, 0.55, 1.5, 1.55 },
}
for _, b in ipairs(blocks) do
	part(lid, "LidBlock", Vector3.new(b[3] - 0.12, 0.22, b[4] - 0.12), CFrame.new(b[1], LID_TOP + 0.11, b[2]), STONE, Enum.Material.Slate)
end
part(lid, "Glow", Vector3.new(5.2, 0.06, 2.85), CFrame.new(0, LID_TOP + 0.02, 0.0), GLOW, Enum.Material.Neon)
-- a raised plate on the biggest block
part(lid, "LidPlate", Vector3.new(1.4, 0.1, 1.2), CFrame.new(-0.2, LID_TOP + 0.27, -0.45), STONE_LIGHT, Enum.Material.Slate)
-- veins running down the lid's edges
for _, c in ipairs({ { -1.9, -1 }, { 0.6, -1 }, { 1.8, -1 }, { -0.9, 1 }, { 1.4, 1 } }) do
	part(lid, "Glow", Vector3.new(0.07, LID_H + 0.02, 0.04), CFrame.new(c[1], LID_YC, c[2] * (HZ + 0.1)) * CFrame.Angles(0, 0, math.rad(10)), GLOW, Enum.Material.Neon)
end

-- ============================================================
-- Fire rising behind the tomb and embers (only shows in the world, ViewportFrames draw no particles)
-- ============================================================
for _, p in ipairs({ Vector3.new(-1.6, 2.6, 1.0), Vector3.new(1.4, 2.6, 1.1), Vector3.new(3.4, 2.4, 1.9), Vector3.new(-3.4, 2.4, 1.9) }) do
	local src = part(body, "Fire", Vector3.new(0.3, 0.3, 0.3), CFrame.new(p), GLOW, Enum.Material.SmoothPlastic)
	src.Transparency = 1
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/fire_main.dds"
	e.Color = ColorSequence.new(Color3.fromRGB(255, 120, 40), Color3.fromRGB(120, 20, 10))
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(1, 0.1) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1) })
	e.Lifetime = NumberRange.new(0.8, 1.4)
	e.Speed = NumberRange.new(1.5, 2.5)
	e.SpreadAngle = Vector2.new(15, 15)
	e.LightEmission = 0.7
	e.Rate = 9
	e.Parent = src
	local embers = Instance.new("ParticleEmitter")
	embers.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	embers.Color = ColorSequence.new(Color3.fromRGB(255, 160, 60))
	embers.Size = NumberSequence.new(0.15)
	embers.Lifetime = NumberRange.new(1.5, 2.5)
	embers.Speed = NumberRange.new(1.5, 3)
	embers.SpreadAngle = Vector2.new(30, 30)
	embers.LightEmission = 1
	embers.Rate = 3
	embers.Parent = src
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
model:SetAttribute("DebrisColor", STONE)
model:SetAttribute("Height", 4.6)
model.Parent = folder

-- a preview next to the other graves' (behind the hub spawn); delete Workspace.GravePreview before publishing
local preview = workspace:FindFirstChild("GravePreview")
if not preview then
	preview = Instance.new("Folder")
	preview.Name = "GravePreview"
	preview.Parent = workspace
end
local oldCopy = preview:FindFirstChild("Abyssal")
if oldCopy then
	oldCopy:Destroy()
end
local copy = model:Clone()
copy:PivotTo(CFrame.new(-10, -1.7, 40))
copy.Parent = preview

local count = 0
for _, d in ipairs(model:GetDescendants()) do
	if d:IsA("BasePart") then count += 1 end
end
return "Abyssal tomb built: " .. count .. " parts"
