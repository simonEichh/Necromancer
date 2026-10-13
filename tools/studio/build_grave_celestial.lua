-- Builds the Celestial Abyss (grave tier 10) into ReplicatedStorage.GraveModels.Celestial, from the concept art
-- Images/Graves/celestial.png: a tall pearl crystal coffin standing upright on a dark gothic pedestal (spires, arches, teal
-- crystal windows), a gold frame with a skull emblem and a gold dagger, a crown of crystals with a gold star, a starry ring
-- orbiting it at a tilt (gold rims, constellations, gold stars), two ringed planets circling it and floating star sparkles.
-- Run in Edit mode via the Studio MCP execute_luau (or loadstring over a local http.server, see CLAUDE.md). Safe to re-run.
--
-- Grave model conventions: see build_grave_mossy.lua (Body / Lid / Pit / Core, "Glow" parts, OpenStyle).
-- Idle motion (Modules/GraveOpening): the models named "Spin" turn round SpinAxis through SpinCenter (the ring; the planets
-- orbit), the "Shard" models (star sparkles) bob; the burst spins them up hard for a few seconds.
-- OpenStyle "Chest" with a side hinge: Lid.Door (attribute Swing) swings open like a door, the starry inside shows, the unit
-- rises out of it and glides down off the pedestal (HopOut / FloorHeight / WallTop / HopTime).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local folder = ReplicatedStorage:FindFirstChild("GraveModels")
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "GraveModels"
	folder.Parent = ReplicatedStorage
end
local old = folder:FindFirstChild("Celestial")
if old then
	old:Destroy()
end

local SLATE = Color3.fromRGB(56, 60, 76)
local SLATE_DARK = Color3.fromRGB(38, 40, 54)
local PEARL = Color3.fromRGB(226, 228, 242)
local PEARL_SHADE = Color3.fromRGB(196, 200, 226)
local GOLD = Color3.fromRGB(196, 158, 82)
local BONE = Color3.fromRGB(232, 226, 210)
local COSMOS = Color3.fromRGB(22, 20, 62)
local CRYSTAL = Color3.fromRGB(70, 210, 200) -- the pedestal's teal windows
local STAR = Color3.fromRGB(255, 205, 110) -- gold stars
local DOT = Color3.fromRGB(225, 225, 255)
local GROUND = Color3.fromRGB(30, 30, 44)
local GLOW = Color3.fromRGB(120, 150, 255) -- icy celestial blue

local model = Instance.new("Model")
model.Name = "Celestial"
local body = Instance.new("Model")
body.Name = "Body"
body.Parent = model
local lid = Instance.new("Model")
lid.Name = "Lid"
lid.Parent = model
local door = Instance.new("Model")
door.Name = "Door"
door:SetAttribute("Swing", 1) -- hinged on its left edge, swings open outwards
door.Parent = lid
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
local function gold(parent, name, size, cf)
	return part(parent, name, size, cf, GOLD, Enum.Material.Metal)
end
local UPRIGHT = CFrame.Angles(0, 0, math.rad(90))
local SPIKE_ROT = CFrame.fromAxisAngle(Vector3.new(1, 1, 1).Unit:Cross(Vector3.yAxis).Unit, math.acos(1 / math.sqrt(3)))
local function spike(parent, pos, size, color)
	part(parent, "Spike", Vector3.new(size, size, size), CFrame.new(pos) * SPIKE_ROT, color or GOLD, Enum.Material.Metal)
end
-- a four-pointed star sparkle (two crossed thin bars and a diamond in the middle), facing along the frame's Z
local function star(parent, cf, size, name)
	part(parent, name or "Star", Vector3.new(size, size * 0.12, size * 0.12), cf, STAR, Enum.Material.Neon)
	part(parent, name or "Star", Vector3.new(size * 0.12, size, size * 0.12), cf, STAR, Enum.Material.Neon)
	part(parent, name or "Star", Vector3.new(size * 0.3, size * 0.3, size * 0.14), cf * CFrame.Angles(0, 0, math.rad(45)), STAR, Enum.Material.Neon)
end

-- the coffin outline seen from the front (x, y): narrow foot, wide shoulders, a flat top
local OUTLINE = {
	Vector2.new(0.95, 2.25), Vector2.new(1.45, 5.2), Vector2.new(1.0, 7.4),
	Vector2.new(-1.0, 7.4), Vector2.new(-1.45, 5.2), Vector2.new(-0.95, 2.25),
}
local CENTER = Vector2.new(0, 4.8)
local FRONT, BACK = -0.75, 0.75
local function edgeSlab(parent, name, a, b, t, depth, z, color, material)
	local d = (b - a).Unit
	local inward = Vector2.new(-d.Y, d.X)
	if inward:Dot(CENTER - (a + b) / 2) < 0 then
		inward = -inward
	end
	local mid = (a + b) / 2 + inward * (t / 2)
	return part(parent, name, Vector3.new((b - a).Magnitude + 0.05, t, depth),
		CFrame.fromMatrix(Vector3.new(mid.X, mid.Y, z), Vector3.new(d.X, d.Y, 0), Vector3.new(inward.X, inward.Y, 0)), color, material)
end
local function bar(parent, name, a, b, w, depth, z, color, material)
	local d = b - a
	return part(parent, name, Vector3.new(d.Magnitude + w * 0.5, w, depth),
		CFrame.new((a.X + b.X) / 2, (a.Y + b.Y) / 2, z) * CFrame.Angles(0, 0, math.atan2(d.Y, d.X)), color, material)
end
local rng = Random.new(10)

-- ============================================================
-- Ground patch (PrimaryPart) and the gothic pedestal
-- ============================================================
local base = part(body, "Base", Vector3.new(0.2, 10.5, 10.5), CFrame.new(0, 0.1, 0) * UPRIGHT, GROUND, Enum.Material.Ground, Enum.PartType.Cylinder)
model.PrimaryPart = base
base.PivotOffset = base.CFrame:Inverse() -- pivot on the floor centre, upright
part(body, "Pedestal", Vector3.new(6.0, 0.5, 6.0), CFrame.new(0, 0.45, 0), SLATE_DARK)
part(body, "Pedestal", Vector3.new(5.0, 1.2, 5.0), CFrame.new(0, 1.3, 0), SLATE)
part(body, "Pedestal", Vector3.new(4.5, 0.3, 4.0), CFrame.new(0, 2.05, 0), SLATE_DARK)
gold(body, "PedestalTrim", Vector3.new(5.1, 0.1, 5.1), CFrame.new(0, 1.92, 0))
-- gothic arches with teal crystal windows on each face
for k = 0, 3 do
	local face = CFrame.Angles(0, k * math.pi / 2, 0)
	for _, x in ipairs({ -1.4, 0, 1.4 }) do
		local c = face * CFrame.new(x, 1.2, -2.51)
		part(body, "Glow", Vector3.new(0.5, 0.75, 0.05), c, CRYSTAL, Enum.Material.Neon)
		gold(body, "Arch", Vector3.new(0.08, 0.85, 0.08), c * CFrame.new(-0.3, 0, -0.03))
		gold(body, "Arch", Vector3.new(0.08, 0.85, 0.08), c * CFrame.new(0.3, 0, -0.03))
		gold(body, "Arch", Vector3.new(0.3, 0.08, 0.08), c * CFrame.new(-0.15, 0.5, -0.03) * CFrame.Angles(0, 0, math.rad(35)))
		gold(body, "Arch", Vector3.new(0.3, 0.08, 0.08), c * CFrame.new(0.15, 0.5, -0.03) * CFrame.Angles(0, 0, math.rad(-35)))
	end
end
-- corner spires and a spire in the middle of the front
for _, c in ipairs({ { -2.55, -2.55 }, { 2.55, -2.55 }, { -2.55, 2.55 }, { 2.55, 2.55 }, { 0, -2.75 } }) do
	part(body, "Spire", Vector3.new(0.6, 2.0, 0.6), CFrame.new(c[1], 1.6, c[2]), SLATE)
	part(body, "Glow", Vector3.new(0.2, 0.7, 0.62), CFrame.new(c[1], 1.6, c[2]), CRYSTAL, Enum.Material.Neon)
	gold(body, "SpireCap", Vector3.new(0.7, 0.15, 0.7), CFrame.new(c[1], 2.65, c[2]))
	spike(body, Vector3.new(c[1], 2.85, c[2]), 0.5)
end
star(body, CFrame.new(0, 1.55, -3.07), 0.7)

-- ============================================================
-- The coffin shell (Body): pearl crystal sides and back on the outline, the starry void inside (Pit)
-- ============================================================
for i = 1, #OUTLINE do
	local a, b = OUTLINE[i], OUTLINE[i % #OUTLINE + 1]
	edgeSlab(body, "Shell", a, b, 0.3, BACK - FRONT, 0, PEARL, Enum.Material.Marble)
	edgeSlab(body, "Shell", a, b, 1.1, 0.2, BACK - 0.1, PEARL_SHADE, Enum.Material.Marble)
	edgeSlab(pit, "Void", a, b, 1.1, 0.05, BACK - 0.22, COSMOS, Enum.Material.SmoothPlastic)
	-- the gold rim round the front edge (stays when the door opens)
	edgeSlab(body, "Rim", a, b, 0.1, 0.12, FRONT - 0.02, GOLD, Enum.Material.Metal)
end
part(body, "Shell", Vector3.new(1.95, 5.2, 0.2), CFrame.new(0, 4.8, BACK - 0.1), PEARL_SHADE, Enum.Material.Marble)
part(pit, "Void", Vector3.new(1.95, 5.2, 0.05), CFrame.new(0, 4.8, BACK - 0.22), COSMOS, Enum.Material.SmoothPlastic)
part(pit, "PitFloor", Vector3.new(1.9, 0.05, 1.3), CFrame.new(0, 2.27, 0), COSMOS, Enum.Material.SmoothPlastic)
for _ = 1, 22 do
	local y = rng:NextNumber(2.6, 7.0)
	local halfW = (y < 5.2) and (0.65 + (y - 2.25) / 2.95 * 0.5) or (1.15 - (y - 5.2) / 2.2 * 0.4)
	local sz = rng:NextNumber(0.05, 0.12)
	part(pit, "Glow", Vector3.new(sz, sz, sz), CFrame.new(rng:NextNumber(-halfW, halfW), y, BACK - 0.27), DOT, Enum.Material.Neon, Enum.PartType.Ball)
end
-- rainbow lightning cracks running down the sides
for _, c in ipairs({
	{ Vector2.new(-1.42, 5.3), Vector2.new(-1.25, 4.6) }, { Vector2.new(-1.25, 4.6), Vector2.new(-1.3, 3.8) },
	{ Vector2.new(1.4, 5.0), Vector2.new(1.2, 4.2) }, { Vector2.new(1.2, 4.2), Vector2.new(1.05, 3.1) },
	{ Vector2.new(0.9, 6.9), Vector2.new(1.2, 6.2) },
}) do
	bar(body, "Glow", c[1], c[2], 0.06, BACK - FRONT + 0.06, 0, GLOW, Enum.Material.Neon)
end
local core = part(model, "Core", Vector3.new(0.4, 0.4, 0.4), CFrame.new(0, 2.65, 0), GLOW, Enum.Material.Neon)
core.Transparency = 1

-- ============================================================
-- The crown: a gold band, crystal points and a gold star on top
-- ============================================================
gold(body, "Crown", Vector3.new(2.3, 0.3, 1.7), CFrame.new(0, 7.55, 0))
for i, x in ipairs({ -0.8, -0.4, 0, 0.4, 0.8 }) do
	local h = (i == 3) and 1.0 or ((i == 2 or i == 4) and 0.75 or 0.55)
	local col = (i % 2 == 0) and Color3.fromRGB(190, 170, 255) or Color3.fromRGB(160, 220, 255)
	part(body, "Crystal", Vector3.new(0.28, h, 0.28), CFrame.new(x, 7.7 + h / 2, -0.1) * CFrame.Angles(0, math.rad(45), 0), col, Enum.Material.Glass)
	part(body, "Crystal", Vector3.new(0.24, 0.24, 0.24), CFrame.new(x, 7.7 + h + 0.05, -0.1) * SPIKE_ROT, col, Enum.Material.Glass)
end
for _, x in ipairs({ -1.05, 1.05 }) do
	spike(body, Vector3.new(x, 7.8, 0), 0.4)
end
star(body, CFrame.new(0, 9.1, -0.1), 1.2)

-- ============================================================
-- The door (Lid.Door): the pearl front panel in a gold frame with a skull emblem and a gold dagger; swings open
-- ============================================================
for i = 1, #OUTLINE do
	local a, b = OUTLINE[i], OUTLINE[i % #OUTLINE + 1]
	edgeSlab(door, "Panel", a, b, 1.2, 0.2, FRONT - 0.12, PEARL, Enum.Material.Marble)
	edgeSlab(door, "Frame", a, b, 0.14, 0.08, FRONT - 0.25, GOLD, Enum.Material.Metal)
end
part(door, "Panel", Vector3.new(1.95, 5.15, 0.2), CFrame.new(0, 4.8, FRONT - 0.12), PEARL, Enum.Material.Marble)
-- facets and cracks in the pearl
for _, c in ipairs({ { Vector2.new(-0.6, 3.0), Vector2.new(0.2, 4.6) }, { Vector2.new(0.5, 5.6), Vector2.new(-0.2, 6.6) }, { Vector2.new(0.7, 3.4), Vector2.new(0.3, 2.6) } }) do
	bar(door, "Facet", c[1], c[2], 0.04, 0.03, FRONT - 0.23, PEARL_SHADE, Enum.Material.SmoothPlastic)
end
-- the emblem: a gold frame round a dark plate with a skull, a gold dagger running down from it
local EZ = FRONT - 0.27
part(door, "Emblem", Vector3.new(1.0, 1.0, 0.08), CFrame.new(0, 5.8, EZ) * CFrame.Angles(0, 0, math.rad(45)), GOLD, Enum.Material.Metal)
part(door, "Emblem", Vector3.new(0.78, 0.78, 0.08), CFrame.new(0, 5.8, EZ - 0.03) * CFrame.Angles(0, 0, math.rad(45)), SLATE_DARK)
part(door, "Skull", Vector3.new(0.5, 0.42, 0.12), CFrame.new(0, 5.86, EZ - 0.08), BONE, Enum.Material.SmoothPlastic)
part(door, "Skull", Vector3.new(0.3, 0.16, 0.12), CFrame.new(0, 5.6, EZ - 0.08), BONE, Enum.Material.SmoothPlastic)
for _, s in ipairs({ -1, 1 }) do
	part(door, "Eye", Vector3.new(0.13, 0.12, 0.05), CFrame.new(s * 0.12, 5.86, EZ - 0.15), SLATE_DARK, Enum.Material.SmoothPlastic)
end
bar(door, "Dagger", Vector2.new(0, 5.15), Vector2.new(0, 3.1), 0.14, 0.08, EZ, GOLD, Enum.Material.Metal)
bar(door, "Dagger", Vector2.new(-0.32, 5.0), Vector2.new(0.32, 5.0), 0.1, 0.08, EZ, GOLD, Enum.Material.Metal)
part(door, "Dagger", Vector3.new(0.3, 0.3, 0.08), CFrame.new(0, 3.05, EZ) * CFrame.Angles(0, 0, math.rad(45)), GOLD, Enum.Material.Metal)
part(door, "Dagger", Vector3.new(0.34, 0.34, 0.08), CFrame.new(0, 6.65, EZ) * CFrame.Angles(0, 0, math.rad(45)), GOLD, Enum.Material.Metal)
-- the light seam round the door
for i = 1, #OUTLINE do
	local a, b = OUTLINE[i], OUTLINE[i % #OUTLINE + 1]
	edgeSlab(door, "Glow", a, b, 0.05, 0.05, FRONT - 0.02, GLOW, Enum.Material.Neon)
end
local hinge = part(door, "Hinge", Vector3.new(0.2, 0.2, 0.2), CFrame.new(-1.45, 2.25, FRONT - 0.22), GLOW, Enum.Material.SmoothPlastic)
hinge.Transparency = 1

-- ============================================================
-- The starry ring (Spin): a tilted band with gold rims, constellation dots and three gold stars, turning round the coffin
-- ============================================================
local RING_C = Vector3.new(0, 4.9, 0)
local tilt = CFrame.Angles(math.rad(14), 0, math.rad(-12))
local n = tilt.UpVector
local u = tilt.RightVector
local v = tilt.LookVector
local R = 4.3
local ring = Instance.new("Model")
ring.Name = "Spin"
ring:SetAttribute("SpinAxis", n)
ring:SetAttribute("SpinCenter", RING_C)
ring:SetAttribute("SpinSpeed", 0.3)
ring.Parent = body
local SEGS = 30
for i = 0, SEGS - 1 do
	local a = i / SEGS * math.pi * 2
	local radial = u * math.cos(a) + v * math.sin(a)
	local tangent = -u * math.sin(a) + v * math.cos(a)
	local pos = RING_C + radial * R
	local len = 2 * math.pi * R / SEGS + 0.04
	part(ring, "Band", Vector3.new(len, 0.08, 0.7), CFrame.fromMatrix(pos, tangent, n), COSMOS, Enum.Material.SmoothPlastic)
	for _, side in ipairs({ -1, 1 }) do
		gold(ring, "Rim", Vector3.new(len, 0.14, 0.09), CFrame.fromMatrix(pos + radial * side * 0.38, tangent, n))
	end
	if i % 3 == 1 then
		local off = rng:NextNumber(-0.22, 0.22)
		part(ring, "Glow", Vector3.new(0.1, 0.1, 0.1), CFrame.new(pos + radial * off + n * 0.06), DOT, Enum.Material.Neon, Enum.PartType.Ball)
	end
end
for k = 0, 2 do
	local a = k / 3 * math.pi * 2 + 0.5
	local radial = u * math.cos(a) + v * math.sin(a)
	local pos = RING_C + radial * R
	-- a gold medallion with a star, standing up on the band
	local cf = CFrame.lookAt(pos + n * 0.35, pos + n * 0.35 + radial)
	gold(ring, "Medallion", Vector3.new(0.1, 0.55, 0.55), cf * CFrame.Angles(0, math.rad(90), 0)).Shape = Enum.PartType.Cylinder
	star(ring, cf * CFrame.new(0, 0, -0.07), 0.9)
end

-- ============================================================
-- Two ringed planets orbiting the coffin (Spin round the vertical axis) and floating star sparkles (Shard)
-- ============================================================
local planets = Instance.new("Model")
planets.Name = "Spin"
planets:SetAttribute("SpinAxis", Vector3.yAxis)
planets:SetAttribute("SpinCenter", Vector3.new(0, 0, 0))
planets:SetAttribute("SpinSpeed", -0.2)
planets.Parent = body
for k, c in ipairs({ { 0.6, 7.2, 4.4 }, { 3.7, 6.2, 4.7 } }) do
	local pos = Vector3.new(math.cos(c[1]) * c[3], c[2], math.sin(c[1]) * c[3])
	part(planets, "Planet", Vector3.new(1.1, 1.1, 1.1), CFrame.new(pos), (k == 1) and Color3.fromRGB(40, 44, 120) or Color3.fromRGB(70, 40, 110), Enum.Material.Glass, Enum.PartType.Ball)
	part(planets, "Glow", Vector3.new(0.05, 0.6, 0.05), CFrame.new(pos + Vector3.new(0.1, 0, -0.56)) * CFrame.Angles(0, 0, 0.6), GLOW, Enum.Material.Neon)
	local pr = CFrame.new(pos) * CFrame.Angles(math.rad(70), math.rad(20 * k), 0)
	for j = 0, 13 do
		local a = j / 14 * math.pi * 2
		gold(planets, "PlanetRing", Vector3.new(0.42, 0.06, 0.08), pr * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -0.85) * CFrame.Angles(0, 0, 0))
	end
end
for i = 1, 6 do
	local a = math.rad(-30 + (i - 1) * 48)
	local r = rng:NextNumber(3.0, 3.8)
	local shard = Instance.new("Model")
	shard.Name = "Shard"
	shard.Parent = body
	local pos = Vector3.new(math.cos(a) * r, rng:NextNumber(3.0, 8.5), math.sin(a) * r * 0.9 + 0.4)
	if i % 2 == 0 then
		star(shard, CFrame.lookAt(pos, Vector3.new(0, pos.Y, -10)), rng:NextNumber(0.6, 0.9))
	else
		local col = Color3.fromRGB(180, 190, 255)
		part(shard, "Crystal", Vector3.new(0.25, 0.7, 0.25), CFrame.new(pos) * CFrame.Angles(0, math.rad(45), 0), col, Enum.Material.Glass)
		part(shard, "Crystal", Vector3.new(0.22, 0.22, 0.22), CFrame.new(pos + Vector3.new(0, 0.4, 0)) * SPIKE_ROT, col, Enum.Material.Glass)
		part(shard, "Crystal", Vector3.new(0.2, 0.2, 0.2), CFrame.new(pos - Vector3.new(0, 0.4, 0)) * SPIKE_ROT, col, Enum.Material.Glass)
	end
end
-- sparkles drifting round it (only shows in the world, ViewportFrames draw no particles)
local src = part(body, "Motes", Vector3.new(6, 6, 6), CFrame.new(0, 5, 0), GLOW, Enum.Material.SmoothPlastic)
src.Transparency = 1
local e = Instance.new("ParticleEmitter")
e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
e.Color = ColorSequence.new(Color3.fromRGB(255, 225, 160), Color3.fromRGB(150, 170, 255))
e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0) })
e.Lifetime = NumberRange.new(1.5, 2.5)
e.Speed = NumberRange.new(0.2, 0.6)
e.SpreadAngle = Vector2.new(180, 180)
e.LightEmission = 1
e.Rate = 7
e.Parent = src

-- ============================================================
-- Attributes and placement
-- ============================================================
model:SetAttribute("OpenStyle", "Chest")
model:SetAttribute("GlowColor", GLOW)
model:SetAttribute("DebrisColor", PEARL)
model:SetAttribute("Height", 9.8)
model:SetAttribute("SwingAngle", 105)
-- the risen unit glides down off the pedestal and lands in front of it (Modules/GraveCinematic)
model:SetAttribute("HopOut", 4.6)
model:SetAttribute("FloorHeight", 2.25)
model:SetAttribute("WallTop", 2.9) -- (higher than the door sill so the glide clears the pedestal edge)
model:SetAttribute("HopTime", 1.2)
model:SetAttribute("UnitInside", true) -- the unit already stands inside the upright coffin, seen when the door opens
model.Parent = folder

-- a preview next to the other graves' (behind the hub spawn); delete Workspace.GravePreview before publishing
local preview = workspace:FindFirstChild("GravePreview")
if not preview then
	preview = Instance.new("Folder")
	preview.Name = "GravePreview"
	preview.Parent = workspace
end
local oldCopy = preview:FindFirstChild("Celestial")
if oldCopy then
	oldCopy:Destroy()
end
local copy = model:Clone()
copy:PivotTo(CFrame.new(-55, -1.7, 40))
copy.Parent = preview

local count = 0
for _, d in ipairs(model:GetDescendants()) do
	if d:IsA("BasePart") then count += 1 end
end
return "Celestial abyss built: " .. count .. " parts"
