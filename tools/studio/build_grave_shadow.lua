-- Builds the Shadow Vault (grave tier 5) into ReplicatedStorage.GraveModels.Shadow, from the concept art
-- Images/Graves/shadowVault.png: a tall black basalt vault on a plinth with front steps, a steep gabled roof with a big spike,
-- tall obelisk pillars at the front corners, iron-strapped double doors with rivets and a diamond boss, blue-violet light
-- seeping round the doors, dark shadow smoke round the foot with glowing eyes in it.
-- Run in Edit mode via the Studio MCP execute_luau (or loadstring over a local http.server, see CLAUDE.md). Safe to re-run.
--
-- Grave model conventions: see build_grave_mossy.lua (Body / Lid / Pit / Core, "Glow" parts, OpenStyle).
-- OpenStyle "Door" with double doors (Modules/GraveOpening): Lid.DoorL and Lid.DoorR each have an invisible Hinge part at
-- their outer edge and the attribute Swing (+1 / -1): they are blasted open outwards (SwingAngle) and bang against the wall.
-- The unit walks out (Modules/GraveCinematic, StarSummon): FloorHeight, WalkOut and DoorHeight as in build_grave_cursed.lua.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local folder = ReplicatedStorage:FindFirstChild("GraveModels")
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "GraveModels"
	folder.Parent = ReplicatedStorage
end
local old = folder:FindFirstChild("Shadow")
if old then
	old:Destroy()
end

local STONE_DARK = Color3.fromRGB(32, 33, 46)
local STONE = Color3.fromRGB(48, 50, 66)
local STONE_LIGHT = Color3.fromRGB(66, 68, 88)
local IRON = Color3.fromRGB(34, 34, 42)
local STRAP = Color3.fromRGB(66, 62, 70)
local RIVET = Color3.fromRGB(92, 88, 96)
local CRACK = Color3.fromRGB(18, 18, 24)
local INSIDE = Color3.fromRGB(4, 4, 8)
local GROUND = Color3.fromRGB(28, 26, 36)
local GLOW = Color3.fromRGB(90, 70, 255) -- blue-violet shadow light
local EYE = Color3.fromRGB(200, 185, 255)

local model = Instance.new("Model")
model.Name = "Shadow"
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
-- a block whose length runs along the 2D (x, y) direction `d` in the front plane, centred at (x, y, z)
local function slopeBlock(parent, name, len, thick, depth, x, y, z, d, color, material)
	local along = Vector3.new(d.X, d.Y, 0).Unit
	local up = Vector3.new(-along.Y, along.X, 0)
	if up.Y < 0 then
		up = -up
	end
	return part(parent, name, Vector3.new(len, thick, depth), CFrame.fromMatrix(Vector3.new(x, y, z), along, up), color, material)
end
-- the upward normal of the 2D line a -> b
local function upNormal(a, b)
	local d = (b - a).Unit
	local n = Vector2.new(-d.Y, d.X)
	return n.Y < 0 and -n or n, d
end
-- a spike: a cube standing on one corner, the top half pointing up
local SPIKE_ROT = CFrame.fromAxisAngle(Vector3.new(1, 1, 1).Unit:Cross(Vector3.yAxis).Unit, math.acos(1 / math.sqrt(3)))
local function spike(parent, pos, size)
	part(parent, "Spike", Vector3.new(size, size, size), CFrame.new(pos) * SPIKE_ROT, STONE_LIGHT)
end
-- a diamond (a square turned 45 degrees) lying in the front plane
local function diamond(parent, name, pos, size, depth, color, material)
	return part(parent, name, Vector3.new(size, size, depth), CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(45)), color, material)
end

-- layout: chamber walls x +-2.6, z +-2.6 (front at -Z), floor at FLOOR, walls up to WALL_TOP, door x +-DOOR_HW
local FLOOR = 1.0
local WALL_TOP = 5.0
local WT = 0.45
local DOOR_HW = 1.15
local SPRING, APEX = 3.6, 4.55
local EAVE_X, RIDGE_Y = 2.9, 7.0
local FRONT = -2.6

-- ============================================================
-- Ground patch (PrimaryPart), plinth and the front steps
-- ============================================================
local base = part(body, "Base", Vector3.new(0.2, 9.6, 9.6), CFrame.new(0, 0.1, 0) * UPRIGHT, GROUND, Enum.Material.Ground, Enum.PartType.Cylinder)
model.PrimaryPart = base
base.PivotOffset = base.CFrame:Inverse() -- pivot on the floor centre, upright
part(body, "Plinth", Vector3.new(6.4, FLOOR - 0.2, 6.0), CFrame.new(0, (FLOOR + 0.2) / 2, 0), STONE_DARK)
part(body, "PlinthRim", Vector3.new(6.6, 0.15, 6.2), CFrame.new(0, FLOOR - 0.075, 0), STONE)
for i, st in ipairs({ { 0.47, -3.9 }, { 0.73, -3.6 }, { 1.0, -3.3 } }) do
	local y0 = (i == 1) and 0.2 or ({ 0.47, 0.73 })[i - 1]
	local depth = -3.0 - st[2]
	part(body, "Step", Vector3.new(2.9, st[1] - y0, depth), CFrame.new(0, (st[1] + y0) / 2, st[2] + depth / 2), (i % 2 == 0) and STONE or STONE_LIGHT)
	-- seams between the step stones
	for _, x in ipairs({ -0.5, 0.7 }) do
		part(body, "Crack", Vector3.new(0.05, st[1] - y0 + 0.01, 0.05), CFrame.new(x + i * 0.15, (st[1] + y0) / 2, st[2] - 0.01), CRACK, Enum.Material.SmoothPlastic)
	end
end

-- ============================================================
-- Chamber: walls, the front with the pointed arch and its frame, the dark inside (Pit)
-- ============================================================
local WALL_H = WALL_TOP - FLOOR
local WALL_YC = FLOOR + WALL_H / 2
for _, s in ipairs({ -1, 1 }) do
	part(body, "Wall", Vector3.new(WT, WALL_H, 5.2), CFrame.new(s * (2.6 - WT / 2), WALL_YC, 0), STONE)
	local w = 2.6 - WT - DOOR_HW
	part(body, "Wall", Vector3.new(w, WALL_H, WT), CFrame.new(s * (DOOR_HW + w / 2), WALL_YC, FRONT + WT / 2), STONE)
	-- a cornice along the top of the side walls
	part(body, "Cornice", Vector3.new(WT + 0.25, 0.25, 5.4), CFrame.new(s * (2.6 - WT / 2 + 0.1), WALL_TOP - 0.12, 0), STONE_LIGHT)
	-- carved gothic niche on the side walls
	part(body, "Niche", Vector3.new(0.05, 1.8, 0.7), CFrame.new(s * 2.62, 2.6, 0.6), CRACK, Enum.Material.SmoothPlastic)
	part(body, "Niche", Vector3.new(0.05, 0.5, 0.5), CFrame.new(s * 2.62, 3.5, 0.6) * CFrame.Angles(math.rad(45), 0, 0), CRACK, Enum.Material.SmoothPlastic)
end
part(body, "Wall", Vector3.new(5.2 - 2 * WT, WALL_H, WT), CFrame.new(0, WALL_YC, 2.6 - WT / 2), STONE)
for _, s in ipairs({ -1, 1 }) do
	local a, b = Vector2.new(s * DOOR_HW, SPRING), Vector2.new(0, APEX)
	local n, d = upNormal(a, b)
	local mid = (a + b) / 2 + n * 0.6
	slopeBlock(body, "Wall", (b - a).Magnitude + 0.8, 1.2, WT, mid.X, mid.Y, FRONT + WT / 2, d, STONE)
	-- the arch frame: big voussoir stones over the arch, a jamb down each side
	local fmid = (a + b) / 2 + n * 0.22
	slopeBlock(body, "ArchFrame", (b - a).Magnitude + 0.3, 0.45, 0.16, fmid.X, fmid.Y, FRONT - 0.06, d, STONE_LIGHT)
	for k = 1, 2 do
		local q = a:Lerp(b, k / 3) + n * 0.22
		slopeBlock(body, "Crack", 0.47, 0.05, 0.17, q.X, q.Y, FRONT - 0.07, n, CRACK, Enum.Material.SmoothPlastic)
	end
	part(body, "ArchFrame", Vector3.new(0.4, SPRING - FLOOR, 0.16), CFrame.new(s * (DOOR_HW + 0.2), FLOOR + (SPRING - FLOOR) / 2, FRONT - 0.06), STONE_LIGHT)
	for _, y in ipairs({ 1.9, 2.9 }) do
		part(body, "Crack", Vector3.new(0.42, 0.05, 0.17), CFrame.new(s * (DOOR_HW + 0.2), y, FRONT - 0.07), CRACK, Enum.Material.SmoothPlastic)
	end
	-- blue-violet light seeping out between the frame and the doors
	part(body, "Glow", Vector3.new(0.05, SPRING - FLOOR, 0.05), CFrame.new(s * (DOOR_HW - 0.01), FLOOR + (SPRING - FLOOR) / 2, FRONT + 0.1), GLOW, Enum.Material.Neon)
	local gmid = (a + b) / 2 - n * 0.01
	slopeBlock(body, "Glow", (b - a).Magnitude, 0.05, 0.05, gmid.X, gmid.Y, FRONT + 0.1, d, GLOW, Enum.Material.Neon)
end
part(body, "Glow", Vector3.new(2 * DOOR_HW, 0.05, 0.05), CFrame.new(0, FLOOR + 0.02, FRONT + 0.1), GLOW, Enum.Material.Neon)
-- the dark inside: lining, ceiling, floor with glowing cracks
part(pit, "Inside", Vector3.new(4.3, WALL_H, 0.05), CFrame.new(0, WALL_YC, 2.6 - WT - 0.03), INSIDE, Enum.Material.SmoothPlastic)
for _, s in ipairs({ -1, 1 }) do
	part(pit, "Inside", Vector3.new(0.05, WALL_H, 4.3), CFrame.new(s * (2.6 - WT - 0.03), WALL_YC, 0), INSIDE, Enum.Material.SmoothPlastic)
end
part(pit, "Inside", Vector3.new(4.3, 0.05, 4.3), CFrame.new(0, WALL_TOP - 0.03, 0), INSIDE, Enum.Material.SmoothPlastic)
part(pit, "PitFloor", Vector3.new(4.3, 0.05, 4.3), CFrame.new(0, FLOOR + 0.02, 0), INSIDE, Enum.Material.SmoothPlastic)
for _, c in ipairs({ { -1.0, 0.7, 1.5, 30 }, { 0.7, -0.4, 1.2, -45 }, { 1.3, 1.2, 0.8, 75 } }) do
	part(pit, "Glow", Vector3.new(c[3], 0.03, 0.08), CFrame.new(c[1], FLOOR + 0.06, c[2]) * CFrame.Angles(0, math.rad(c[4]), 0), GLOW, Enum.Material.Neon)
end
local core = part(model, "Core", Vector3.new(0.4, 0.4, 0.4), CFrame.new(0, FLOOR + 0.4, 0), GLOW, Enum.Material.Neon)
core.Transparency = 1

-- ============================================================
-- Steep gabled roof: gable ends, roof slabs, a ridge, a big spike over the front
-- ============================================================
for _, s in ipairs({ -1, 1 }) do
	local eave, ridge = Vector2.new(s * EAVE_X, WALL_TOP), Vector2.new(0, RIDGE_Y)
	local n, d = upNormal(eave, ridge)
	local mid = (eave + ridge) / 2
	local len = (ridge - eave).Magnitude
	local gm = mid - n * 0.6
	for _, z in ipairs({ FRONT + WT / 2, 2.6 - WT / 2 }) do
		slopeBlock(body, "Gable", len, 1.2, WT, gm.X, gm.Y, z, d, STONE)
	end
	local rm = mid + n * 0.2 - d * 0.3
	slopeBlock(body, "Roof", len + 0.6, 0.4, 6.0, rm.X, rm.Y, 0, d, STONE_LIGHT)
	-- a raised edge along the front gable, cracks between the roof stones
	local em = mid + n * 0.25 - d * 0.3
	slopeBlock(body, "GableEdge", len + 0.6, 0.5, 0.35, em.X, em.Y, -3.0, d, STONE_LIGHT)
	for _, z in ipairs({ -1.5, 0, 1.5 }) do
		local cm = mid + n * 0.41 - d * 0.3
		slopeBlock(body, "Crack", len + 0.5, 0.02, 0.06, cm.X, cm.Y, z, d, CRACK, Enum.Material.SmoothPlastic)
	end
	for _, f in ipairs({ 0.35, 0.7 }) do
		local q = eave:Lerp(ridge, f) + n * 0.41
		slopeBlock(body, "Crack", 0.06, 0.02, 6.0, q.X, q.Y, 0, d, CRACK, Enum.Material.SmoothPlastic)
	end
end
part(body, "Gable", Vector3.new(2.2, 0.7, WT), CFrame.new(0, WALL_TOP + 0.3, 2.6 - WT / 2), STONE)
part(body, "Ridge", Vector3.new(0.6, 0.6, 6.2), CFrame.new(0, RIDGE_Y + 0.2, 0) * CFrame.Angles(0, 0, math.rad(45)), STONE_LIGHT)
part(body, "RidgeCap", Vector3.new(0.9, 0.6, 0.9), CFrame.new(0, RIDGE_Y + 0.55, -2.95), STONE_LIGHT)
part(body, "RidgeCap", Vector3.new(0.6, 0.35, 0.6), CFrame.new(0, RIDGE_Y + 1.0, -2.95), STONE)
spike(body, Vector3.new(0, RIDGE_Y + 1.3, -2.95), 0.85)
part(body, "RidgeCap", Vector3.new(0.6, 0.35, 0.6), CFrame.new(0, RIDGE_Y + 0.45, 2.95), STONE_LIGHT)
spike(body, Vector3.new(0, RIDGE_Y + 0.75, 2.95), 0.55)

-- ============================================================
-- Pillars: tall obelisks at the front corners (carved gothic panel, stepped foot), smaller ones at the back
-- ============================================================
local function pillar(x, z, top, w, panelFront)
	part(body, "PillarFoot", Vector3.new(w + 0.5, 0.6, w + 0.5), CFrame.new(x, 0.5, z), STONE_DARK)
	part(body, "PillarFoot", Vector3.new(w + 0.25, 0.5, w + 0.25), CFrame.new(x, 1.05, z), STONE)
	local shaftTop = top - 0.7
	part(body, "Pillar", Vector3.new(w, shaftTop - 1.3, w), CFrame.new(x, 1.3 + (shaftTop - 1.3) / 2, z), STONE)
	part(body, "Band", Vector3.new(w + 0.15, 0.15, w + 0.15), CFrame.new(x, 2.4, z), STONE_LIGHT)
	part(body, "Cap", Vector3.new(w + 0.25, 0.4, w + 0.25), CFrame.new(x, shaftTop + 0.2, z), STONE_LIGHT)
	part(body, "Cap", Vector3.new(w * 0.8, 0.3, w * 0.8), CFrame.new(x, shaftTop + 0.55, z), STONE)
	spike(body, Vector3.new(x, shaftTop + 0.75, z), w * 0.75)
	if panelFront then
		-- the carved gothic window on the front face
		local fz = z - w / 2 - 0.02
		part(body, "Niche", Vector3.new(w * 0.45, shaftTop - 3.2, 0.05), CFrame.new(x, 2.6 + (shaftTop - 3.2) / 2, fz), CRACK, Enum.Material.SmoothPlastic)
		diamond(body, "Niche", Vector3.new(x, shaftTop - 0.6, fz), w * 0.32, 0.05, CRACK, Enum.Material.SmoothPlastic)
	end
end
for _, s in ipairs({ -1, 1 }) do
	pillar(s * 3.05, -2.8, 6.3, 1.1, true)
	pillar(s * 2.95, 2.8, 4.8, 0.85, false)
end
-- glowing cracks in the front pillars and the steps (they glow during the buildup)
for _, c in ipairs({ { -3.1, 1.7, 0.6, 20, -3.37 }, { 3.0, 4.2, 0.5, -30, -3.37 }, { -0.6, 0.33, 0.22, 70, -3.92 } }) do
	part(body, "Glow", Vector3.new(0.05, c[3], 0.04), CFrame.new(c[1], c[2], c[5]) * CFrame.Angles(0, 0, math.rad(c[4])), GLOW, Enum.Material.Neon)
end

-- ============================================================
-- The double doors (Lid.DoorL / Lid.DoorR): iron leaves with a pointed top, straps forming an X, rivets, a diamond boss
-- ============================================================
local DOOR_T = 0.3
local DOOR_Z = FRONT + 0.18 + DOOR_T / 2
local DOOR_FRONT = DOOR_Z - DOOR_T / 2
local FZ = DOOR_FRONT - 0.04 -- the face the straps sit on
for _, s in ipairs({ -1, 1 }) do
	local door = Instance.new("Model")
	door.Name = s < 0 and "DoorL" or "DoorR"
	door:SetAttribute("Swing", s < 0 and 1 or -1)
	door.Parent = lid
	local cx = s * DOOR_HW / 2
	part(door, "Leaf", Vector3.new(DOOR_HW - 0.03, SPRING - FLOOR, DOOR_T), CFrame.new(s * (DOOR_HW / 2 + 0.015), FLOOR + (SPRING - FLOOR) / 2, DOOR_Z), IRON, Enum.Material.Metal)
	local a, b = Vector2.new(s * DOOR_HW, SPRING), Vector2.new(0, APEX)
	local n, d = upNormal(a, b)
	local mid = (a + b) / 2 - n * 0.45
	slopeBlock(door, "Leaf", (b - a).Magnitude, 0.9, DOOR_T, mid.X, mid.Y, DOOR_Z, d, IRON, Enum.Material.Metal)
	-- vertical planks
	part(door, "Crack", Vector3.new(0.04, SPRING - FLOOR - 0.1, 0.03), CFrame.new(cx, FLOOR + (SPRING - FLOOR) / 2, DOOR_FRONT - 0.01), CRACK, Enum.Material.SmoothPlastic)
	-- the straps: a diagonal from the outer top to the middle, one from the middle to the outer bottom (an X over both doors)
	local midP = Vector2.new(s * 0.05, 2.45)
	for _, outer in ipairs({ Vector2.new(s * (DOOR_HW - 0.12), 3.55), Vector2.new(s * (DOOR_HW - 0.12), 1.35) }) do
		local len = (outer - midP).Magnitude
		local c = (outer + midP) / 2
		slopeBlock(door, "Strap", len, 0.2, 0.06, c.X, c.Y, FZ, outer - midP, STRAP, Enum.Material.Metal)
	end
	-- horizontal bands top and bottom, rivets along the outer edge and on the bands
	for _, y in ipairs({ FLOOR + 0.3, SPRING - 0.15 }) do
		part(door, "Strap", Vector3.new(DOOR_HW - 0.1, 0.18, 0.06), CFrame.new(cx, y, FZ), STRAP, Enum.Material.Metal)
		for _, f in ipairs({ 0.2, 0.8 }) do
			part(door, "Rivet", Vector3.new(0.14, 0.14, 0.14), CFrame.new(s * DOOR_HW * f, y, FZ - 0.05), RIVET, Enum.Material.Metal, Enum.PartType.Ball)
		end
	end
	for _, y in ipairs({ 1.9, 2.45, 3.0 }) do
		part(door, "Rivet", Vector3.new(0.14, 0.14, 0.14), CFrame.new(s * (DOOR_HW - 0.12), y, FZ - 0.03), RIVET, Enum.Material.Metal, Enum.PartType.Ball)
	end
	-- the hinge: at the outer edge of the leaf, bottom
	local hinge = part(door, "Hinge", Vector3.new(0.2, 0.2, 0.2), CFrame.new(s * DOOR_HW, FLOOR, DOOR_FRONT), GLOW, Enum.Material.SmoothPlastic)
	hinge.Transparency = 1
	-- iron hinge straps on the outer edge
	for _, y in ipairs({ 1.6, 3.2 }) do
		part(door, "Strap", Vector3.new(0.35, 0.16, 0.08), CFrame.new(s * (DOOR_HW - 0.18), y, FZ), STRAP, Enum.Material.Metal)
	end
end
-- the diamond boss in the middle (on the left leaf), a small diamond above and below it
diamond(lid.DoorL, "Boss", Vector3.new(0, 2.45, FZ - 0.04), 0.62, 0.12, STRAP, Enum.Material.Metal)
diamond(lid.DoorL, "Boss", Vector3.new(0, 2.45, FZ - 0.1), 0.3, 0.06, RIVET, Enum.Material.Metal)
diamond(lid.DoorL, "Boss", Vector3.new(0, 1.2, FZ), 0.22, 0.06, STRAP, Enum.Material.Metal)
diamond(lid.DoorR, "Boss", Vector3.new(0, 3.75, FZ), 0.22, 0.06, STRAP, Enum.Material.Metal)

-- ============================================================
-- Shadow smoke round the foot with glowing eyes in it (the smoke only shows in the world)
-- ============================================================
for _, p in ipairs({ Vector3.new(-3.7, 0.4, -3.4), Vector3.new(3.9, 0.4, -1.2), Vector3.new(-3.6, 0.4, 2.4), Vector3.new(1.9, 0.4, -4.3) }) do
	local src = part(body, "Wisps", Vector3.new(0.3, 0.3, 0.3), CFrame.new(p), GLOW, Enum.Material.SmoothPlastic)
	src.Transparency = 1
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	e.Color = ColorSequence.new(Color3.fromRGB(70, 50, 190), Color3.fromRGB(14, 10, 36))
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 2.6) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.45), NumberSequenceKeypoint.new(1, 1) })
	e.Lifetime = NumberRange.new(3, 4.5)
	e.Speed = NumberRange.new(0.3, 0.7)
	e.SpreadAngle = Vector2.new(70, 20)
	e.Acceleration = Vector3.new(0, 0.3, 0)
	e.RotSpeed = NumberRange.new(-15, 15)
	e.LightEmission = 0.25
	e.Rate = 3
	e.Parent = src
end
for _, c in ipairs({ { -3.5, 0.5, -3.75, 25 }, { 3.85, 0.45, -1.7, -70 }, { -1.8, 0.35, -4.3, 5 }, { 2.6, 0.4, -4.05, -20 } }) do
	local cf = CFrame.new(c[1], c[2], c[3]) * CFrame.Angles(0, math.rad(c[4]), 0)
	for _, s in ipairs({ -1, 1 }) do
		part(body, "Eye", Vector3.new(0.13, 0.13, 0.13), cf * CFrame.new(s * 0.12, 0, 0), EYE, Enum.Material.Neon, Enum.PartType.Ball)
	end
end

-- ============================================================
-- Attributes and placement
-- ============================================================
model:SetAttribute("OpenStyle", "Door")
model:SetAttribute("GlowColor", GLOW)
model:SetAttribute("DebrisColor", STONE_LIGHT)
model:SetAttribute("Height", RIDGE_Y + 1.6)
model:SetAttribute("SwingAngle", 86)
model:SetAttribute("FloorHeight", FLOOR)
model:SetAttribute("DoorHeight", APEX - FLOOR)
model:SetAttribute("WalkOut", 5.8)
model.Parent = folder

-- a preview next to the other graves' (behind the hub spawn); delete Workspace.GravePreview before publishing
local preview = workspace:FindFirstChild("GravePreview")
if not preview then
	preview = Instance.new("Folder")
	preview.Name = "GravePreview"
	preview.Parent = workspace
end
local oldCopy = preview:FindFirstChild("Shadow")
if oldCopy then
	oldCopy:Destroy()
end
local copy = model:Clone()
copy:PivotTo(CFrame.new(40, -1.7, 40))
copy.Parent = preview

local count = 0
for _, d in ipairs(model:GetDescendants()) do
	if d:IsA("BasePart") then count += 1 end
end
return "Shadow vault built: " .. count .. " parts"
