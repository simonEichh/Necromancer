-- Builds the Void Sanctum (grave tier 8) into ReplicatedStorage.GraveModels.Void, from the concept art
-- Images/Graves/Void sanctum.png: an obsidian coffin standing upright and floating over a swirling violet vortex, a starry
-- void showing through its cracked front, stone ribs and diamonds over it, a spire and two curved horns on top, crystal
-- shards hovering round it.
-- Run in Edit mode via the Studio MCP execute_luau (or loadstring over a local http.server, see CLAUDE.md). Safe to re-run.
--
-- Grave model conventions: see build_grave_mossy.lua (Body / Lid / Pit / Core, "Glow" parts, OpenStyle).
-- OpenStyle "Summon": nothing bursts. In Modules/GraveCinematic the floating coffin casts a magic circle on the ground in
-- front of it, a beam gathers in the sky and strikes the circle, the unit materializes on it. Attribute Float: the coffin
-- (Lid) and every "Shard" model hover and sway (Modules/GraveOpening idle float).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local folder = ReplicatedStorage:FindFirstChild("GraveModels")
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "GraveModels"
	folder.Parent = ReplicatedStorage
end
local old = folder:FindFirstChild("Void")
if old then
	old:Destroy()
end

local OBSIDIAN = Color3.fromRGB(44, 42, 56)
local OBSIDIAN_LIGHT = Color3.fromRGB(70, 68, 86)
local COSMOS = Color3.fromRGB(26, 12, 56)
local STAR = Color3.fromRGB(215, 195, 255)
local GROUND = Color3.fromRGB(20, 14, 30)
local GLOW = Color3.fromRGB(150, 70, 255) -- void violet
local K = 1.05 -- the whole model is built at this scale (the coordinates below are drawn 1/K bigger)

local model = Instance.new("Model")
model.Name = "Void"
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
-- a spike: a cube standing on one corner, the top half pointing up
local SPIKE_ROT = CFrame.fromAxisAngle(Vector3.new(1, 1, 1).Unit:Cross(Vector3.yAxis).Unit, math.acos(1 / math.sqrt(3)))
local function spike(parent, pos, size, color)
	part(parent, "Spike", Vector3.new(size, size, size), CFrame.new(pos) * SPIKE_ROT, color or OBSIDIAN_LIGHT)
end
-- the coffin outline seen from the front (x, y): a point at the bottom, wide shoulders, a flat top
local OUTLINE = {
	Vector2.new(0, 1.5), Vector2.new(0.95, 2.3), Vector2.new(1.45, 5.0), Vector2.new(1.0, 6.5),
	Vector2.new(-1.0, 6.5), Vector2.new(-1.45, 5.0), Vector2.new(-0.95, 2.3),
}
local CENTER = Vector2.new(0, 4.3)
-- a slab along the outline edge a -> b in the front plane, t wide towards the inside, `depth` deep, centred at z
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
-- a bar from a to b in the front plane
local function bar(parent, name, a, b, w, depth, z, color, material)
	local d = b - a
	return part(parent, name, Vector3.new(d.Magnitude + w * 0.5, w, depth),
		CFrame.new((a.X + b.X) / 2, (a.Y + b.Y) / 2, z) * CFrame.Angles(0, 0, math.atan2(d.Y, d.X)), color, material)
end
-- a curling horn: segments of shrinking width, each turned further from `dir` towards `bend`
local function curl(parent, pos, dir, bend, lengths, widths, angles)
	dir = dir.Unit
	bend = (bend - dir * bend:Dot(dir)).Unit
	for i, len in ipairs(lengths) do
		local axis = dir:Cross(bend).Unit
		part(parent, "Horn", Vector3.new(widths[i], len + widths[i] * 0.3, widths[i]), CFrame.fromMatrix(pos + dir * (len / 2), axis, dir), OBSIDIAN_LIGHT)
		pos = pos + dir * len
		local r = CFrame.fromAxisAngle(axis, math.rad(angles[i]))
		dir = r:VectorToWorldSpace(dir)
		bend = r:VectorToWorldSpace(bend)
	end
end
local rng = Random.new(8)

-- ============================================================
-- Ground: a dark patch, the swirling vortex (Pit + glowing ring arcs)
-- ============================================================
local base = part(body, "Base", Vector3.new(0.2, 9.0, 9.0), CFrame.new(0, 0.1, 0) * UPRIGHT, GROUND, Enum.Material.Ground, Enum.PartType.Cylinder)
part(pit, "PitFloor", Vector3.new(0.05, 4.2, 4.2), CFrame.new(0, 0.22, 0) * UPRIGHT, Color3.fromRGB(6, 2, 14), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
part(pit, "PitFloor", Vector3.new(0.05, 2.2, 2.2), CFrame.new(0, 0.24, 0) * UPRIGHT, Color3.fromRGB(2, 0, 6), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
-- three rings of arcs, each ring turned a little against the others and with gaps, so they read as a spiral
for ring, r in ipairs({ 1.1, 1.75, 2.45, 3.1 }) do
	local count = 10 + ring * 3
	for i = 0, count - 1 do
		if (i + ring) % 4 ~= 0 then
			local a = (i + ring * 0.37) / count * math.pi * 2
			local len = 2 * math.pi * r / count * 0.95
			local cf = CFrame.new(0, 0.26 + ring * 0.005, 0) * CFrame.Angles(0, -a, 0) * CFrame.new(r, 0, 0) * CFrame.Angles(0, math.rad(90 + 8), 0)
			part((ring <= 2) and pit or body, "Glow", Vector3.new(len, 0.03, 0.09 + 0.03 * (4 - ring)), cf, GLOW, Enum.Material.Neon)
		end
	end
end
local core = part(model, "Core", Vector3.new(0.4, 0.4, 0.4), CFrame.new(0, 0.6 / K, 0), GLOW, Enum.Material.Neon)
core.Transparency = 1

-- ============================================================
-- The floating coffin (Lid): obsidian frame round a starry void, a stone back, ribs and diamonds on the front
-- ============================================================
for i = 1, #OUTLINE do
	local a, b = OUTLINE[i], OUTLINE[i % #OUTLINE + 1]
	edgeSlab(lid, "Frame", a, b, 0.42, 1.4, 0, OBSIDIAN)
	edgeSlab(lid, "Void", a, b, 1.0, 1.0, 0.2, COSMOS, Enum.Material.SmoothPlastic)
	edgeSlab(lid, "Back", a, b, 1.0, 0.16, 0.62, OBSIDIAN)
	-- a lighter bevel along the front edge of the frame
	edgeSlab(lid, "Bevel", a, b, 0.12, 0.08, -0.72, OBSIDIAN_LIGHT)
end
part(lid, "Void", Vector3.new(1.95, 4.2, 1.0), CFrame.new(0, 4.4, 0.2), COSMOS, Enum.Material.SmoothPlastic)
part(lid, "Back", Vector3.new(1.95, 4.2, 0.16), CFrame.new(0, 4.4, 0.62), OBSIDIAN)
-- stars in the void
for _ = 1, 26 do
	local y = rng:NextNumber(2.4, 6.1)
	local halfW = (y < 5.0) and (0.6 + (y - 2.3) / 2.7 * 0.6) or (1.2 - (y - 5.0) / 1.5 * 0.35)
	local s = rng:NextNumber(0.05, 0.13)
	part(lid, "Star", Vector3.new(s, s, s), CFrame.new(rng:NextNumber(-halfW, halfW), y, -0.31), STAR, Enum.Material.Neon, Enum.PartType.Ball)
end
-- violet cracks running through the void and over the frame
for _, c in ipairs({
	{ Vector2.new(-0.7, 5.6), Vector2.new(-0.2, 4.9) }, { Vector2.new(-0.2, 4.9), Vector2.new(-0.5, 4.1) },
	{ Vector2.new(0.4, 3.6), Vector2.new(0.9, 3.0) }, { Vector2.new(0.4, 3.6), Vector2.new(0.2, 2.6) },
	{ Vector2.new(0.6, 5.9), Vector2.new(1.0, 5.2) }, { Vector2.new(-0.8, 3.2), Vector2.new(-0.4, 2.7) },
}) do
	bar(lid, "Glow", c[1], c[2], 0.05, 0.03, -0.33, GLOW, Enum.Material.Neon)
end
for _, c in ipairs({ { Vector2.new(1.2, 4.3), Vector2.new(1.38, 3.7) }, { Vector2.new(-1.25, 5.5), Vector2.new(-1.05, 6.0) }, { Vector2.new(-0.75, 2.2), Vector2.new(-0.45, 1.95) } }) do
	bar(lid, "Glow", c[1], c[2], 0.05, 0.03, -0.73, GLOW, Enum.Material.Neon)
end
-- the stone ribs over the front: a spine down the middle, an arch from the shoulders up to the top, a fork at the bottom
local RZ = -0.62
bar(lid, "Rib", Vector2.new(0, 1.9), Vector2.new(0, 6.6), 0.3, 0.3, RZ, OBSIDIAN_LIGHT)
for _, s in ipairs({ -1, 1 }) do
	bar(lid, "Rib", Vector2.new(s * 1.15, 4.8), Vector2.new(s * 0.55, 6.15), 0.26, 0.28, RZ, OBSIDIAN_LIGHT)
	bar(lid, "Rib", Vector2.new(s * 1.15, 4.8), Vector2.new(s * 0.45, 4.15), 0.24, 0.28, RZ, OBSIDIAN_LIGHT)
	bar(lid, "Rib", Vector2.new(s * 0.75, 2.75), Vector2.new(0, 3.3), 0.22, 0.28, RZ, OBSIDIAN_LIGHT)
end
for _, d in ipairs({ { 6.25, 0.55 }, { 4.15, 0.6 }, { 2.4, 0.42 } }) do
	part(lid, "Diamond", Vector3.new(d[2], d[2] * 1.35, 0.32), CFrame.new(0, d[1], -0.7) * CFrame.Angles(0, 0, math.rad(45)), OBSIDIAN_LIGHT)
end
-- the crown: a cap, a spire with a spike, two horns curving in
part(lid, "Cap", Vector3.new(2.3, 0.4, 1.6), CFrame.new(0, 6.7, 0), OBSIDIAN)
part(lid, "Cap", Vector3.new(1.0, 0.25, 1.2), CFrame.new(0, 7.0, 0), OBSIDIAN_LIGHT)
part(lid, "Spire", Vector3.new(0.55, 0.7, 0.55), CFrame.new(0, 7.45, 0), OBSIDIAN)
spike(lid, Vector3.new(0, 7.85, 0), 0.62)
for _, s in ipairs({ -1, 1 }) do
	curl(lid, Vector3.new(s * 0.85, 6.85, 0), Vector3.new(s * 0.35, 1, 0), Vector3.new(-s, 0, 0),
		{ 0.5, 0.45, 0.4, 0.35 }, { 0.45, 0.35, 0.25, 0.13 }, { 10, 16, 22, 0 })
end

-- ============================================================
-- Crystal shards hovering round the coffin (Body: they stay; the burst throws its own debris)
-- ============================================================
for i = 1, 7 do
	local a = math.rad(-15 + (i - 1) * 35) -- only at the sides and the back (+Z), never between the camera and the unit
	local r = rng:NextNumber(2.4, 3.0)
	local y = rng:NextNumber(2.2, 6.0)
	local size = rng:NextNumber(0.9, 1.4)
	local cf = CFrame.new(math.cos(a) * r, y, math.sin(a) * r * 0.8 + 0.3)
		* CFrame.Angles(rng:NextNumber(-0.4, 0.4), rng:NextNumber(0, 6), rng:NextNumber(-0.4, 0.4))
	local shard = Instance.new("Model") -- each shard bobs and turns on its own (GraveOpening idle float)
	shard.Name = "Shard"
	shard.Parent = body
	part(shard, "Crystal", Vector3.new(0.38 * size, 0.9 * size, 0.3 * size), cf, OBSIDIAN)
	spike(shard, (cf * CFrame.new(0, 0.45 * size, 0)).Position, 0.3 * size, OBSIDIAN)
	spike(shard, (cf * CFrame.new(0, -0.45 * size, 0)).Position, 0.26 * size, OBSIDIAN)
	part(shard, "Glow", Vector3.new(0.04, 0.6 * size, 0.04), cf * CFrame.new(0.08 * size, 0, -0.16 * size) * CFrame.Angles(0, 0, 0.3), GLOW, Enum.Material.Neon)
end

-- ============================================================
-- Scale everything down by K (drawn big for readable numbers), then the pivot on the floor centre
-- ============================================================
for _, p in ipairs(model:GetDescendants()) do
	if p:IsA("BasePart") then
		local rot = p.CFrame.Rotation
		p.Size = p.Size * K
		p.CFrame = CFrame.new(p.Position * K) * rot
	end
end
base.Size = Vector3.new(0.1, base.Size.Y, base.Size.Z) -- the ground patch stays thin (top at 0.1, under the vortex)
base.CFrame = CFrame.new(0, 0.05, 0) * UPRIGHT
model.PrimaryPart = base
base.PivotOffset = base.CFrame:Inverse()

-- violet motes rising from the vortex (only shows in the world, ViewportFrames draw no particles)
local src = part(body, "Motes", Vector3.new(0.3, 0.3, 0.3), CFrame.new(0, 0.3, 0), GLOW, Enum.Material.SmoothPlastic)
src.Transparency = 1
local e = Instance.new("ParticleEmitter")
e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
e.Color = ColorSequence.new(GLOW, Color3.fromRGB(90, 40, 200))
e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 0) })
e.Lifetime = NumberRange.new(2, 3)
e.Speed = NumberRange.new(0.8, 1.6)
e.SpreadAngle = Vector2.new(25, 25)
e.Shape = Enum.ParticleEmitterShape.Disc
e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
e.LightEmission = 1
e.Rate = 6
e.Parent = src
src.Size = Vector3.new(4, 0.1, 4)

-- ============================================================
-- Attributes and placement
-- ============================================================
model:SetAttribute("OpenStyle", "Summon")
model:SetAttribute("Float", true) -- the coffin and the shards hover (GraveOpening idle float)
model:SetAttribute("GlowColor", GLOW)
model:SetAttribute("DebrisColor", OBSIDIAN)
model:SetAttribute("Height", 8.2 * K)
model.Parent = folder

-- a preview next to the other graves' (behind the hub spawn); delete Workspace.GravePreview before publishing
local preview = workspace:FindFirstChild("GravePreview")
if not preview then
	preview = Instance.new("Folder")
	preview.Name = "GravePreview"
	preview.Parent = workspace
end
local oldCopy = preview:FindFirstChild("Void")
if oldCopy then
	oldCopy:Destroy()
end
local copy = model:Clone()
copy:PivotTo(CFrame.new(-30, -1.7, 40))
copy.Parent = preview

local count = 0
for _, d in ipairs(model:GetDescendants()) do
	if d:IsA("BasePart") then count += 1 end
end
return "Void sanctum built: " .. count .. " parts"
