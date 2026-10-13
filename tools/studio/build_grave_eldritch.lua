-- Builds the Eldritch Reliquary (grave tier 7) into ReplicatedStorage.GraveModels.Eldritch, from the concept art
-- Images/Graves/eldritchReliquary.png: a chest of dark teal stone in a frame of verdigris bronze, corner posts with pyramid
-- caps standing on clawed feet, gothic arches on the sides, a great closed eye carved on the lid, teal light leaking from the
-- seam and tentacles with glowing suckers spilling out of it.
-- Run in Edit mode via the Studio MCP execute_luau (or loadstring over a local http.server, see CLAUDE.md). Safe to re-run.
--
-- Grave model conventions: see build_grave_mossy.lua (Body / Lid / Pit / Core, "Glow" parts, OpenStyle).
-- OpenStyle "Chest" (Modules/GraveOpening): Lid.ChestLid flips up and back round its invisible Hinge part (attribute
-- Tilt = 1, model TiltAngle), like a chest; the risen unit then hops out over the front wall (HopOut / FloorHeight / WallTop).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local folder = ReplicatedStorage:FindFirstChild("GraveModels")
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "GraveModels"
	folder.Parent = ReplicatedStorage
end
local old = folder:FindFirstChild("Eldritch")
if old then
	old:Destroy()
end

local STONE = Color3.fromRGB(38, 56, 62)
local STONE_DARK = Color3.fromRGB(26, 38, 44)
local BRONZE = Color3.fromRGB(118, 96, 66)
local BRONZE_DARK = Color3.fromRGB(90, 74, 54)
local VERDIGRIS = Color3.fromRGB(86, 110, 90) -- bronze gone green
local TENTACLE = Color3.fromRGB(34, 40, 58)
local CRACK = Color3.fromRGB(16, 24, 28)
local GROUND = Color3.fromRGB(24, 32, 34)
local GLOW = Color3.fromRGB(30, 225, 205) -- eldritch teal

local model = Instance.new("Model")
model.Name = "Eldritch"
local body = Instance.new("Model")
body.Name = "Body"
body.Parent = model
local lid = Instance.new("Model")
lid.Name = "Lid"
lid.Parent = model
local chestLid = Instance.new("Model")
chestLid.Name = "ChestLid"
chestLid:SetAttribute("Tilt", 1)
chestLid.Parent = lid
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
local function bronze(parent, name, size, cf)
	return part(parent, name, size, cf, BRONZE, Enum.Material.Metal)
end
-- a frame lying in a face with outward normal `normal` (X = along the face, Y = up, Z = into the stone)
local function faceFrame(pos, normal)
	return CFrame.fromMatrix(pos, normal:Cross(Vector3.yAxis), Vector3.yAxis)
end
-- a bronze strip from a to b (2D points in the face frame `cf`)
local function strip(parent, cf, a, b, width, depth)
	local mid = (a + b) / 2
	local d = b - a
	return part(parent, "Trim", Vector3.new(d.Magnitude + width, width, depth or 0.08),
		cf * CFrame.new(mid.X, mid.Y, -(depth or 0.08) / 2) * CFrame.Angles(0, 0, math.atan2(d.Y, d.X)), BRONZE, Enum.Material.Metal)
end
-- a pointed gothic arch outline (bronze) on a face, its foot at y0, w wide, h high to the point
local function arch(parent, cf, x, y0, w, h)
	local spring = y0 + h * 0.62
	strip(parent, cf, Vector2.new(x - w / 2, y0), Vector2.new(x - w / 2, spring), 0.09)
	strip(parent, cf, Vector2.new(x + w / 2, y0), Vector2.new(x + w / 2, spring), 0.09)
	strip(parent, cf, Vector2.new(x - w / 2, spring), Vector2.new(x, y0 + h), 0.09)
	strip(parent, cf, Vector2.new(x + w / 2, spring), Vector2.new(x, y0 + h), 0.09)
end
-- a curling limb (tentacle, claw): segments of shrinking width, each turned further from `dir` towards `bend`
local function curl(parent, name, pos, dir, bend, lengths, widths, angles, color, material, suckers)
	dir = dir.Unit
	bend = (bend - dir * bend:Dot(dir)).Unit
	for i, len in ipairs(lengths) do
		local w = widths[i]
		local axis = dir:Cross(bend).Unit
		local center = pos + dir * (len / 2)
		part(parent, name, Vector3.new(w, len + w * 0.35, w), CFrame.fromMatrix(center, axis, dir), color, material)
		if suckers and i < #lengths then
			part(parent, "Glow", Vector3.new(w * 0.42, w * 0.42, w * 0.42), CFrame.new(center - bend * (w * 0.48)), GLOW, Enum.Material.Neon, Enum.PartType.Ball)
		end
		pos = pos + dir * len
		local r = CFrame.fromAxisAngle(axis, math.rad(angles[i]))
		dir = r:VectorToWorldSpace(dir)
		bend = r:VectorToWorldSpace(bend)
	end
end

-- chest: walls X +-2.4, Z +-1.7; corner posts at +-2.55, +-1.85; on clawed feet
local HX, HZ = 2.4, 1.7
local PX, PZ, PW = 2.55, 1.85, 0.8
local FLOOR = 0.65
local WALL_Y0, WALL_Y1 = 0.65, 2.0
local WALL_T = 0.3

-- ============================================================
-- Ground patch (PrimaryPart) and the pit (the chest's dark inside)
-- ============================================================
local base = part(body, "Base", Vector3.new(0.2, 9.0, 9.0), CFrame.new(0, 0.1, 0) * UPRIGHT, GROUND, Enum.Material.Ground, Enum.PartType.Cylinder)
model.PrimaryPart = base
base.PivotOffset = base.CFrame:Inverse() -- pivot on the floor centre, upright
part(pit, "PitFloor", Vector3.new(4.1, 0.05, 2.7), CFrame.new(0, FLOOR + 0.02, 0), Color3.fromRGB(4, 10, 12), Enum.Material.SmoothPlastic)
for _, c in ipairs({ { -1.2, 0.5, 1.3, 25 }, { 0.6, -0.5, 1.1, -40 }, { 1.4, 0.6, 0.8, 70 } }) do
	part(pit, "Glow", Vector3.new(c[3], 0.03, 0.08), CFrame.new(c[1], FLOOR + 0.06, c[2]) * CFrame.Angles(0, math.rad(c[4]), 0), GLOW, Enum.Material.Neon)
end
local core = part(model, "Core", Vector3.new(0.4, 0.4, 0.4), CFrame.new(0, FLOOR + 0.4, 0), GLOW, Enum.Material.Neon)
core.Transparency = 1

-- ============================================================
-- Body: floor plate, stone walls, the bronze frame (bottom and top bands), gothic arches, emblems
-- ============================================================
part(body, "Bottom", Vector3.new(2 * HX, 0.2, 2 * HZ), CFrame.new(0, FLOOR - 0.1, 0), STONE_DARK)
local WALL_H = WALL_Y1 - WALL_Y0
local WALL_YC = WALL_Y0 + WALL_H / 2
for _, s in ipairs({ -1, 1 }) do
	part(body, "Wall", Vector3.new(2 * HX - 2 * WALL_T, WALL_H, WALL_T), CFrame.new(0, WALL_YC, s * (HZ - WALL_T / 2)), STONE)
	part(body, "Wall", Vector3.new(WALL_T, WALL_H, 2 * HZ), CFrame.new(s * (HX - WALL_T / 2), WALL_YC, 0), STONE)
	-- bronze bands round the bottom and the top of the walls
	bronze(body, "Band", Vector3.new(2 * HX + 0.1, 0.2, 0.14), CFrame.new(0, WALL_Y0 + 0.05, s * (HZ + 0.05)))
	bronze(body, "Band", Vector3.new(0.14, 0.2, 2 * HZ + 0.1), CFrame.new(s * (HX + 0.05), WALL_Y0 + 0.05, 0))
	bronze(body, "Band", Vector3.new(2 * HX + 0.1, 0.24, 0.16), CFrame.new(0, WALL_Y1 - 0.12, s * (HZ + 0.05)))
	bronze(body, "Band", Vector3.new(0.16, 0.24, 2 * HZ + 0.1), CFrame.new(s * (HX + 0.05), WALL_Y1 - 0.12, 0))
end
for _, s in ipairs({ -1, 1 }) do
	-- long faces: gothic arches carved in the stone, a bronze emblem (a pointed arch round a diamond) in the middle
	local cf = faceFrame(Vector3.new(0, 0, s * (HZ + 0.01)), Vector3.new(0, 0, s))
	for _, x in ipairs({ -1.55, -0.8, 0.8, 1.55 }) do
		part(body, "Niche", Vector3.new(0.42, 0.75, 0.04), cf * CFrame.new(x, WALL_Y0 + 0.62, -0.01), CRACK, Enum.Material.SmoothPlastic)
		part(body, "Niche", Vector3.new(0.3, 0.3, 0.04), cf * CFrame.new(x, WALL_Y0 + 1.0, -0.01) * CFrame.Angles(0, 0, math.rad(45)), CRACK, Enum.Material.SmoothPlastic)
	end
	arch(body, cf, 0, WALL_Y0 + 0.25, 0.8, 1.0)
	part(body, "Emblem", Vector3.new(0.28, 0.28, 0.1), cf * CFrame.new(0, WALL_Y0 + 0.62, -0.06) * CFrame.Angles(0, 0, math.rad(45)), BRONZE, Enum.Material.Metal)
	-- short faces: one arch
	local ncf = faceFrame(Vector3.new(s * (HX + 0.01), 0, 0), Vector3.new(s, 0, 0))
	arch(body, ncf, 0, WALL_Y0 + 0.25, 1.0, 0.95)
	part(body, "Niche", Vector3.new(0.5, 0.45, 0.04), ncf * CFrame.new(0, WALL_Y0 + 0.55, -0.01), CRACK, Enum.Material.SmoothPlastic)
end

-- ============================================================
-- Corner posts on clawed feet, pyramid caps, verdigris
-- ============================================================
local POST_Y0, POST_Y1 = 0.35, 2.6
for _, sx in ipairs({ -1, 1 }) do
	for _, sz in ipairs({ -1, 1 }) do
		local x, z = sx * PX, sz * PZ
		bronze(body, "PostFoot", Vector3.new(PW + 0.25, 0.3, PW + 0.25), CFrame.new(x, POST_Y0 + 0.05, z))
		bronze(body, "Post", Vector3.new(PW, POST_Y1 - POST_Y0, PW), CFrame.new(x, (POST_Y0 + POST_Y1) / 2, z))
		bronze(body, "PostBand", Vector3.new(PW + 0.15, 0.2, PW + 0.15), CFrame.new(x, WALL_Y1 - 0.1, z))
		bronze(body, "PostCap", Vector3.new(PW + 0.2, 0.2, PW + 0.2), CFrame.new(x, POST_Y1 + 0.1, z)).Color = VERDIGRIS
		local y = POST_Y1 + 0.2
		for i, w in ipairs({ 0.72, 0.5, 0.28 }) do
			bronze(body, "Pyramid", Vector3.new(w, 0.16, w), CFrame.new(x, y + 0.08, z)).Color = (i == 2) and BRONZE or VERDIGRIS
			y += 0.16
		end
		-- gothic slits in the two outward faces, verdigris patches
		for _, n in ipairs({ Vector3.new(sx, 0, 0), Vector3.new(0, 0, sz) }) do
			local c = Vector3.new(x, 0, z) + n * (PW / 2 + 0.01)
			local f = faceFrame(c, n)
			part(body, "Niche", Vector3.new(0.22, 0.9, 0.04), f * CFrame.new(0, 1.15, -0.01), CRACK, Enum.Material.SmoothPlastic)
			part(body, "Niche", Vector3.new(0.16, 0.16, 0.04), f * CFrame.new(0, 1.62, -0.01) * CFrame.Angles(0, 0, math.rad(45)), CRACK, Enum.Material.SmoothPlastic)
		end
		-- three claws gripping the ground, splayed outwards
		local out = Vector3.new(sx, 0, sz).Unit
		for _, a in ipairs({ -40, 0, 40 }) do
			local d = (CFrame.Angles(0, math.rad(a), 0):VectorToWorldSpace(out) + Vector3.new(0, 0.5, 0)).Unit
			local start = Vector3.new(x, POST_Y0 + 0.05, z) + Vector3.new(d.X, 0, d.Z).Unit * 0.38
			curl(body, "Claw", start, d, Vector3.new(0, -1, 0), { 0.3, 0.28, 0.24 }, { 0.24, 0.17, 0.09 }, { 35, 45, 0 }, BRONZE_DARK, Enum.Material.Metal)
		end
	end
end

-- the teal seam under the lid
local SEAM_Y = WALL_Y1 + 0.03
for _, s in ipairs({ -1, 1 }) do
	part(body, "Glow", Vector3.new(2 * HX - 0.3, 0.07, 0.07), CFrame.new(0, SEAM_Y, s * (HZ + 0.06)), GLOW, Enum.Material.Neon)
	part(body, "Glow", Vector3.new(0.07, 0.07, 2 * HZ - 0.3), CFrame.new(s * (HX + 0.06), SEAM_Y, 0), GLOW, Enum.Material.Neon)
end

-- ============================================================
-- Tentacles spilling out of the seam and curling down over the walls (Body: they stay when the lid flips open)
-- ============================================================
local function tentacle(pos, out)
	curl(body, "Tentacle", pos, out + Vector3.new(0, 0.3, 0), Vector3.new(0, -1, 0),
		{ 0.42, 0.4, 0.36, 0.32, 0.28, 0.24 }, { 0.44, 0.38, 0.32, 0.26, 0.19, 0.12 }, { 28, 34, 30, -30, -55, 0 },
		TENTACLE, Enum.Material.SmoothPlastic, true)
end
tentacle(Vector3.new(-1.3, SEAM_Y, -HZ - 0.05), Vector3.new(0, 0, -1))
tentacle(Vector3.new(1.5, SEAM_Y, -HZ - 0.05), Vector3.new(0.2, 0, -1))
tentacle(Vector3.new(HX + 0.05, SEAM_Y, -0.6), Vector3.new(1, 0, 0))
tentacle(Vector3.new(-HX - 0.05, SEAM_Y, 0.7), Vector3.new(-1, 0, 0))

-- ============================================================
-- The lid (Lid.ChestLid): a heavy stone slab in a bronze frame with the great closed eye; flips open round its Hinge
-- ============================================================
local LID_Y0, LID_H = SEAM_Y + 0.05, 0.5
local LID_TOP = LID_Y0 + LID_H
local LID_YC = LID_Y0 + LID_H / 2
local LX, LZ = HX - 0.12, HZ + 0.1
part(chestLid, "LidSlab", Vector3.new(2 * LX, LID_H, 2 * LZ), CFrame.new(0, LID_YC, 0), STONE)
part(chestLid, "LidTop", Vector3.new(2 * LX - 0.6, 0.15, 2 * LZ - 0.6), CFrame.new(0, LID_TOP + 0.075, 0), STONE)
for _, s in ipairs({ -1, 1 }) do
	bronze(chestLid, "LidFrame", Vector3.new(2 * LX + 0.08, 0.16, 0.22), CFrame.new(0, LID_TOP - 0.06, s * (LZ - 0.07)))
	bronze(chestLid, "LidFrame", Vector3.new(0.22, 0.16, 2 * LZ + 0.08), CFrame.new(s * (LX - 0.07), LID_TOP - 0.06, 0))
	-- seams between the lid stones
	part(chestLid, "Crack", Vector3.new(0.05, 0.02, 2 * LZ - 0.7), CFrame.new(s * 1.75, LID_TOP + 0.16, 0), CRACK, Enum.Material.SmoothPlastic)
end
-- the eye: a lens-shaped bronze rim (two arcs of three strips each), a heavy closed eyelid, a glowing slit, corner spikes
local EY = LID_TOP + 0.17
local top = CFrame.new(0, EY, 0) * CFrame.Angles(math.rad(90), 0, 0) -- a face frame looking up (X along, Y = +Z, -Z = up)
local lens = { Vector2.new(-1.55, 0), Vector2.new(-0.85, 0.62), Vector2.new(0.85, 0.62), Vector2.new(1.55, 0) }
for _, sy in ipairs({ -1, 1 }) do
	for i = 1, 3 do
		local a, b = lens[i], lens[i + 1]
		strip(chestLid, top, Vector2.new(a.X, a.Y * sy), Vector2.new(b.X, b.Y * sy), 0.14, 0.12)
	end
end
part(chestLid, "Eyelid", Vector3.new(2.3, 0.2, 0.9), CFrame.new(0, EY + 0.06, 0), STONE_DARK)
part(chestLid, "Eyelid", Vector3.new(1.5, 0.12, 1.05), CFrame.new(0, EY + 0.1, 0), STONE_DARK)
part(chestLid, "Glow", Vector3.new(2.0, 0.05, 0.07), CFrame.new(0, EY + 0.17, 0.02), GLOW, Enum.Material.Neon)
for _, s in ipairs({ -1, 1 }) do
	bronze(chestLid, "EyeSpike", Vector3.new(0.3, 0.3, 0.3), CFrame.new(s * 1.62, EY + 0.08, 0) * CFrame.Angles(0, math.rad(45), 0))
	bronze(chestLid, "EyeSpike", Vector3.new(0.28, 0.28, 0.12), CFrame.new(0, EY + 0.05, s * 0.78) * CFrame.Angles(0, 0, math.rad(45)) * CFrame.Angles(math.rad(90), 0, 0))
end
-- the hinge: along the lid's back bottom edge
local hinge = part(chestLid, "Hinge", Vector3.new(0.2, 0.2, 0.2), CFrame.new(0, LID_Y0, LZ), GLOW, Enum.Material.SmoothPlastic)
hinge.Transparency = 1

-- ============================================================
-- Attributes and placement
-- ============================================================
model:SetAttribute("OpenStyle", "Chest")
model:SetAttribute("GlowColor", GLOW)
model:SetAttribute("DebrisColor", STONE)
model:SetAttribute("Height", 3.3)
model:SetAttribute("TiltAngle", 112)
-- the risen unit hops out over the front wall and lands HopOut studs in front of the Core (Modules/GraveCinematic)
model:SetAttribute("HopOut", 3.4)
model:SetAttribute("FloorHeight", FLOOR)
model:SetAttribute("WallTop", SEAM_Y)
model.Parent = folder

-- a preview next to the other graves' (behind the hub spawn); delete Workspace.GravePreview before publishing
local preview = workspace:FindFirstChild("GravePreview")
if not preview then
	preview = Instance.new("Folder")
	preview.Name = "GravePreview"
	preview.Parent = workspace
end
local oldCopy = preview:FindFirstChild("Eldritch")
if oldCopy then
	oldCopy:Destroy()
end
local copy = model:Clone()
copy:PivotTo(CFrame.new(-20, -1.7, 40))
copy.Parent = preview

local count = 0
for _, d in ipairs(model:GetDescendants()) do
	if d:IsA("BasePart") then count += 1 end
end
return "Eldritch reliquary built: " .. count .. " parts"
