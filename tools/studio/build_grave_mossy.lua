-- Builds the Mossy Grave (grave tier 1, the cheapest loot box) into ReplicatedStorage.GraveModels.Mossy, from the
-- concept art Images/Graves/mossyGrave.png: a low earth mound full of moss, rocks, grass and pale mushrooms with soul-green
-- light leaking through its cracks, and a cracked, moss-covered rounded headstone at its head.
-- Run in Edit mode via the Studio MCP execute_luau (or loadstring over a local http.server, see CLAUDE.md). Safe to re-run.
--
-- Grave model conventions (shared by every tier, read by the client's opening animation):
--   origin = floor centre (PrimaryPart "Base", a thin ground patch whose bottom sits on y = 0), FRONT faces -Z,
--   footprint about 5 x 7 studs, attributes OpenStyle ("Mound" here), GlowColor, Height.
--   "Body"  model: everything that stays when the grave opens.
--   "Lid"   model: everything that bursts away (for a Mound: the earth layers, moss, cracks, rocks and mushrooms on it).
--   "Pit"   model: what the opening reveals (a dark hole with a glowing rim), hidden under the lid until then.
--   "Core"  part:  invisible point inside the grave where the light and the unit come out.
--   Parts named "Glow" are the soul-light cracks the animation brightens before the burst.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local folder = ReplicatedStorage:FindFirstChild("GraveModels")
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "GraveModels"
	folder.Parent = ReplicatedStorage
end
local old = folder:FindFirstChild("Mossy")
if old then
	old:Destroy()
end

local MUD_DARK = Color3.fromRGB(60, 42, 32)
local MUD = Color3.fromRGB(104, 72, 50)
local MUD_LIGHT = Color3.fromRGB(110, 78, 54)
local STONE_DARK = Color3.fromRGB(70, 72, 82)
local STONE = Color3.fromRGB(104, 106, 118)
local STONE_LIGHT = Color3.fromRGB(136, 138, 150)
local MOSS_DARK = Color3.fromRGB(62, 96, 40)
local MOSS = Color3.fromRGB(96, 140, 52)
local MOSS_LIGHT = Color3.fromRGB(128, 170, 64)
local GRASS = Color3.fromRGB(84, 132, 58)
local CAP = Color3.fromRGB(226, 220, 196)
local STEM = Color3.fromRGB(180, 220, 200)
local GLOW = Color3.fromRGB(120, 255, 190)

local rng = Random.new(11) -- fixed seed: the same grave every time

local model = Instance.new("Model")
model.Name = "Mossy"
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
local function at(x, y, z)
	return CFrame.new(x, y, z)
end
local UPRIGHT = CFrame.Angles(0, 0, math.rad(90)) -- cylinders run along X; this stands them up
local function disc(parent, name, radius, height, cf, color, material)
	return part(parent, name, Vector3.new(height, radius * 2, radius * 2), cf * UPRIGHT, color, material, Enum.PartType.Cylinder)
end
-- a rough rock: a box tilted a little at random
local function rock(parent, x, y, z, s, color, mossy)
	local r = part(parent, "Rock", Vector3.new(s * rng:NextNumber(0.9, 1.3), s * rng:NextNumber(0.6, 0.9), s * rng:NextNumber(0.8, 1.2)),
		at(x, y, z) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, math.pi), rng:NextNumber(-0.3, 0.3)), color or STONE, Enum.Material.Slate)
	if mossy then
		part(parent, "RockMoss", Vector3.new(r.Size.X * 0.8, 0.08, r.Size.Z * 0.7), r.CFrame * CFrame.new(0, r.Size.Y / 2 + 0.03, 0), MOSS, Enum.Material.Grass)
	end
	return r
end
-- a tuft of grass: a few thin blades fanning out
local function tuft(parent, x, y, z, h)
	for k = 0, 4 do
		local a = k / 5 * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
		local lean = rng:NextNumber(0.25, 0.5)
		part(parent, "Grass", Vector3.new(0.08, h * rng:NextNumber(0.7, 1.1), 0.22),
			at(x, y, z) * CFrame.Angles(0, a, 0) * CFrame.Angles(lean, 0, 0) * CFrame.new(0, h * 0.45, 0), GRASS, Enum.Material.Grass)
	end
end
local function mushroom(parent, x, y, z, s)
	disc(parent, "MushroomStem", 0.08 * s, 0.4 * s, at(x, y + 0.2 * s, z), STEM, Enum.Material.SmoothPlastic)
	disc(parent, "MushroomCap", 0.24 * s, 0.12 * s, at(x, y + 0.42 * s, z), CAP, Enum.Material.SmoothPlastic)
	disc(parent, "MushroomCapTop", 0.15 * s, 0.08 * s, at(x, y + 0.5 * s, z), CAP, Enum.Material.SmoothPlastic)
	disc(parent, "Glow", 0.2 * s, 0.03 * s, at(x, y + 0.35 * s, z), GLOW, Enum.Material.Neon) -- a faint glow under the cap
end

-- ============================================================
-- Ground patch (PrimaryPart) and the pit under the mound
-- ============================================================
local base = disc(body, "Base", 3.6, 0.2, at(0, 0.1, 0), MUD_DARK, Enum.Material.Ground)
model.PrimaryPart = base
local MZ = -0.4 -- centre of the mound (the headstone stands at its +Z end)
part(pit, "PitHole", Vector3.new(2.6, 0.04, 4.6), at(0, 0.22, MZ), Color3.fromRGB(6, 8, 8), Enum.Material.SmoothPlastic)
for _, s in ipairs({ -1, 1 }) do
	part(pit, "Glow", Vector3.new(0.12, 0.05, 4.8), at(s * 1.35, 0.23, MZ), GLOW, Enum.Material.Neon)
	part(pit, "Glow", Vector3.new(2.8, 0.05, 0.12), at(0, 0.23, MZ + s * 2.35), GLOW, Enum.Material.Neon)
end
local core = part(model, "Core", Vector3.new(0.4, 0.4, 0.4), at(0, 0.6, MZ), GLOW, Enum.Material.Neon)
core.Transparency = 1

-- ============================================================
-- The mound (Lid): one smooth rounded hump (a capsule lying along Z, sunk into the ground), with moss, soul-light
-- cracks, rocks and mushrooms laid on its surface
-- ============================================================
local R, CY, HL = 2.0, -0.45, 1.2 -- capsule radius, axis height (below the floor), half-length of its straight part
part(lid, "Mound", Vector3.new(HL * 2, R * 2, R * 2), at(0, CY, MZ) * CFrame.Angles(0, math.rad(90), 0), MUD, Enum.Material.Ground, Enum.PartType.Cylinder)
for _, s in ipairs({ -1, 1 }) do
	part(lid, "MoundEnd", Vector3.new(R * 2, R * 2, R * 2), at(0, CY, MZ + s * HL), MUD, Enum.Material.Ground, Enum.PartType.Ball)
end
-- the point on the mound's surface above (x, z) and the surface normal there
local function surface(x, z)
	local cz = math.clamp(z, MZ - HL, MZ + HL)
	local dz = z - cz
	local y = CY + math.sqrt(math.max(R * R - x * x - dz * dz, 0))
	local pos = Vector3.new(x, y, z)
	return pos, (pos - Vector3.new(0, CY, cz)).Unit
end
-- a frame lying on the surface (local Y = the normal), turned by yaw around it
local function onSurface(x, z, yaw, lift)
	local pos, n = surface(x, z)
	local right = Vector3.zAxis:Cross(n).Unit
	return CFrame.fromMatrix(pos + n * (lift or 0), right, n) * CFrame.Angles(0, yaw or 0, 0)
end
-- moss: patches hugging the hump, darker towards the ground
for _, m in ipairs({ { 0.1, -1.9, 0.9, 0.8, 0.3 }, { -0.4, -1.3, 0.8, 0.7, 1.1 }, { -0.5, 0.0, 0.9, 0.8, -0.4 }, { 0.1, 0.5, 0.7, 0.7, 0.6 },
	{ 0.6, 0.9, 0.8, 0.7, 0.9 }, { -0.3, 1.6, 0.7, 0.6, 0.2 }, { 0.5, -0.6, 0.6, 0.6, 0.3 }, { -0.9, -2.2, 0.6, 0.6, 0.2 }, { 1.0, -0.4, 0.5, 0.7, -0.2 },
	{ -1.0, 0.9, 0.5, 0.7, 0.5 }, { 0.9, -2.5, 0.5, 0.5, 0.1 }, { 0.2, -2.9, 0.6, 0.5, 0.4 } }) do
	local pos = surface(m[1], MZ + m[2])
	part(lid, "Moss", Vector3.new(m[3], 0.08, m[4]), onSurface(m[1], MZ + m[2], m[5], 0.0), (pos.Y > 1.1) and MOSS or MOSS_DARK, Enum.Material.Grass)
end
part(lid, "MossTuft", Vector3.new(0.6, 0.16, 0.45), onSurface(-0.3, MZ - 1.3, 0.6, 0.08), MOSS_LIGHT, Enum.Material.Grass)
part(lid, "MossTuft", Vector3.new(0.5, 0.16, 0.55), onSurface(0.5, MZ + 0.3, -0.4, 0.08), MOSS_LIGHT, Enum.Material.Grass)
-- soul-light cracks: zigzags running over the hump
local function crack(points)
	for k = 1, #points - 1 do
		local a = surface(points[k][1], MZ + points[k][2])
		local b, n = surface((points[k][1] + points[k + 1][1]) / 2, MZ + (points[k][2] + points[k + 1][2]) / 2)
		local c = surface(points[k + 1][1], MZ + points[k + 1][2])
		local len = (c - a).Magnitude
		part(lid, "Glow", Vector3.new(0.09, 0.05, len), CFrame.lookAt(b + n * 0.03, c + n * 0.03, n), GLOW, Enum.Material.Neon)
	end
end
crack({ { -1.1, -2.1 }, { -0.5, -1.8 }, { -0.2, -1.2 }, { 0.5, -1.0 } })
crack({ { 0.9, 0.2 }, { 0.4, 0.6 }, { 0.6, 1.2 }, { 0.1, 1.7 } })
crack({ { -1.5, -0.8 }, { -1.2, -0.3 }, { -1.45, 0.3 } })
crack({ { 1.6, -2.0 }, { 1.3, -1.5 }, { 1.55, -1.0 } })
-- rocks and mushrooms sitting on the mound
local function rockOn(x, z, s, color, mossy)
	local pos = surface(x, MZ + z)
	rock(lid, pos.X, pos.Y + s * 0.15, pos.Z, s, color, mossy)
end
rockOn(-0.9, 1.3, 0.45, STONE)
rockOn(0.8, -1.7, 0.38, STONE_LIGHT)
rockOn(1.4, 1.5, 0.4, STONE, true)
rockOn(-1.5, -1.5, 0.35, STONE)
local mp = surface(-0.9, MZ - 0.6)
mushroom(lid, mp.X, mp.Y - 0.05, mp.Z, 1.1)
mp = surface(1.2, MZ - 2.4)
mushroom(lid, mp.X, mp.Y - 0.05, mp.Z, 0.9)

-- ============================================================
-- Rocks and grass round the edge (Body: they stay)
-- ============================================================
for k = 0, 15 do
	local t = k / 16 * math.pi * 2 + rng:NextNumber(-0.15, 0.15)
	local x = math.cos(t) * 2.2
	local z = MZ + math.sin(t) * 3.2
	if z < 2.2 then -- leave the headstone end clear
		rock(body, x, 0.3, z, rng:NextNumber(0.35, 0.7), (k % 3 == 0) and STONE_LIGHT or STONE, k % 4 == 1)
	end
end
for _, g in ipairs({ { -2.2, -3.0 }, { 2.1, -2.2 }, { -2.3, 0.6 }, { 2.3, 1.2 }, { -1.4, 2.4 }, { 1.6, 2.6 }, { 0.3, -3.6 } }) do
	tuft(body, g[1], 0.2, g[2], rng:NextNumber(0.45, 0.65))
end
mushroom(body, 1.9, 0.2, 1.9, 1.0)
mushroom(body, 2.15, 0.2, 2.2, 0.7)

-- ============================================================
-- Headstone (Body): a thick rounded slab, cracked across the upper right, moss over the top
-- ============================================================
local HZ = 2.9
local tilt = CFrame.Angles(math.rad(-6), 0, math.rad(3)) -- leaning back a little, settled into the earth
local hs = at(0, 0, HZ) * tilt -- headstone frame: its foot at y = 0
local W, T, H = 3.2, 0.9, 2.6 -- width, thickness, height of the straight part
part(body, "HeadstoneFoot", Vector3.new(W + 0.4, 0.4, T + 0.5), hs * CFrame.new(0, 0.2, 0), MUD, Enum.Material.Ground)
part(body, "Headstone", Vector3.new(W, H, T), hs * CFrame.new(0, H / 2, 0), STONE, Enum.Material.Slate)
-- the round top: a cylinder along the slab's thickness
part(body, "HeadstoneTop", Vector3.new(T, W, W), hs * CFrame.new(0, H, 0) * CFrame.Angles(0, math.rad(90), 0), STONE, Enum.Material.Slate, Enum.PartType.Cylinder)
-- chamfered corner stones on the front edges
for _, s in ipairs({ -1, 1 }) do
	part(body, "HeadstoneEdge", Vector3.new(0.3, H * 0.9, 0.3), hs * CFrame.new(s * (W / 2 - 0.05), H * 0.5, -T / 2 + 0.05) * CFrame.Angles(0, math.rad(45), 0), STONE_LIGHT, Enum.Material.Slate)
end
-- the crack: a dark split running down from the top right, with the broken piece standing a little proud
local front = -T / 2 - 0.02
for _, c in ipairs({ { 0.75, 3.5, 0.7, -25 }, { 0.95, 2.9, 0.7, 15 }, { 0.85, 2.3, 0.6, -10 } }) do
	part(body, "Crack", Vector3.new(0.07, c[3], 0.06), hs * CFrame.new(c[1], c[2], front) * CFrame.Angles(0, 0, math.rad(c[4])), Color3.fromRGB(26, 26, 30), Enum.Material.SmoothPlastic)
end
part(body, "BrokenPiece", Vector3.new(0.7, 1.0, 0.12), hs * CFrame.new(1.15, 2.85, front - 0.04) * CFrame.Angles(0, 0, math.rad(8)), STONE_LIGHT, Enum.Material.Slate)
part(body, "Crack", Vector3.new(0.06, 0.9, 0.06), hs * CFrame.new(-1.0, 1.1, front) * CFrame.Angles(0, 0, math.rad(20)), Color3.fromRGB(26, 26, 30), Enum.Material.SmoothPlastic)
-- moss: a cap over the top and drips down the front
-- moss clumps growing along the rounded top (radial pieces round the arch, thickest on the left)
for k, deg in ipairs({ -70, -45, -22, 0, 25 }) do
	local a = math.rad(deg)
	local len = (k <= 3) and 0.9 or 0.6
	part(body, "HeadstoneMoss", Vector3.new(len, 0.16, T + 0.1), hs * CFrame.new(0, H, 0) * CFrame.Angles(0, 0, -a) * CFrame.new(0, W / 2 + 0.03, 0), (k % 2 == 0) and MOSS_LIGHT or MOSS, Enum.Material.Grass)
end
for _, d in ipairs({ { -1.25, 3.0, 0.22, 0.9 }, { -0.95, 3.15, 0.18, 0.6 }, { -0.5, 3.45, 0.2, 0.5 }, { 1.35, 0.5, 0.25, 0.8 }, { -1.3, 0.35, 0.3, 0.5 } }) do
	part(body, "MossDrip", Vector3.new(d[3], d[4], 0.08), hs * CFrame.new(d[1], d[2], front - 0.01), (d[2] > 2) and MOSS or MOSS_DARK, Enum.Material.Grass)
end
part(body, "Glow", Vector3.new(0.08, 0.6, 0.06), hs * CFrame.new(1.05, 0.5, front - 0.02) * CFrame.Angles(0, 0, math.rad(-10)), GLOW, Enum.Material.Neon)
rock(body, -1.9, 0.3, HZ - 0.2, 0.55, STONE, true)
rock(body, 1.9, 0.3, HZ + 0.1, 0.5, STONE_LIGHT)
tuft(body, -1.2, 0.2, HZ - 0.8, 0.6)
tuft(body, 1.3, 0.2, HZ - 0.9, 0.5)

-- ============================================================
-- Attributes and placement
-- ============================================================
model:SetAttribute("OpenStyle", "Mound")
model:SetAttribute("GlowColor", GLOW)
model:SetAttribute("Height", 4.4)
base.PivotOffset = base.CFrame:Inverse() -- pivot on the floor centre, upright (the base disc itself is a rotated cylinder)
model.Parent = folder

-- a preview in the plaza so it can be looked at in Edit mode (delete Workspace.GravePreview before publishing)
local preview = workspace:FindFirstChild("GravePreview")
if preview then
	preview:Destroy()
end
preview = Instance.new("Folder")
preview.Name = "GravePreview"
preview.Parent = workspace
local copy = model:Clone()
copy:PivotTo(CFrame.new(0, -1.7, 40)) -- behind the hub spawn between the Forge and the sell stall, its front towards the spawn
copy.Parent = preview

local count = 0
for _, d in ipairs(model:GetDescendants()) do
	if d:IsA("BasePart") then count += 1 end
end
return "Mossy grave built: " .. count .. " parts"
