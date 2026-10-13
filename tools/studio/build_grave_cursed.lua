-- Builds the Cursed Crypt (grave tier 4) into ReplicatedStorage.GraveModels.Cursed, from the concept art
-- Images/Graves/cursedCrypt.png: a small dark stone crypt on a stepped base, a gabled roof, spiked corner pillars, a pointed
-- arch door with glowing violet runes, rusty chains wrapped round it and a padlock on the door, violet smoke round the foot.
-- Run in Edit mode via the Studio MCP execute_luau (or loadstring over a local http.server, see CLAUDE.md). Safe to re-run.
--
-- Grave model conventions: see build_grave_mossy.lua (Body / Lid / Pit / Core, "Glow" parts, OpenStyle).
-- OpenStyle "Door" (Modules/GraveOpening): the model Lid.Door falls flat forward round the invisible part Lid.Door.Hinge
-- (its X axis is the hinge line, attribute FallAngle on the model), every other Lid part (chains, padlock) flies off, and
-- the unit WALKS out of the crypt (Modules/GraveCinematic): it starts on the chamber floor (attribute FloorHeight) at the
-- Core and walks WalkOut studs forward. DoorHeight lets the cinematic scale the crypt up so tall units fit through.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local folder = ReplicatedStorage:FindFirstChild("GraveModels")
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "GraveModels"
	folder.Parent = ReplicatedStorage
end
local old = folder:FindFirstChild("Cursed")
if old then
	old:Destroy()
end

local STONE_DARK = Color3.fromRGB(40, 38, 50)
local STONE = Color3.fromRGB(58, 56, 72)
local STONE_LIGHT = Color3.fromRGB(80, 78, 96)
local DOOR = Color3.fromRGB(58, 56, 70)
local RUST = Color3.fromRGB(104, 70, 48)
local IRON = Color3.fromRGB(70, 56, 46)
local CRACK = Color3.fromRGB(30, 28, 36)
local INSIDE = Color3.fromRGB(6, 4, 10)
local GROUND = Color3.fromRGB(44, 38, 48)
local GLOW = Color3.fromRGB(165, 60, 255) -- violet curse light

local model = Instance.new("Model")
model.Name = "Cursed"
local body = Instance.new("Model")
body.Name = "Body"
body.Parent = model
local lid = Instance.new("Model")
lid.Name = "Lid"
lid.Parent = model
local door = Instance.new("Model")
door.Name = "Door"
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
-- a spike: a cube standing on one corner, the top half pointing up
local SPIKE_ROT = CFrame.fromAxisAngle(Vector3.new(1, 1, 1).Unit:Cross(Vector3.yAxis).Unit, math.acos(1 / math.sqrt(3)))
local function spike(parent, pos, size)
	part(parent, "Spike", Vector3.new(size, size, size), CFrame.new(pos) * SPIKE_ROT, STONE_LIGHT)
end

-- layout: chamber walls x +-2.5, z +-2.4 (front at -Z), floor at FLOOR, walls up to WALL_TOP, door x +-1.1
local FLOOR = 0.85
local WALL_TOP = 4.0
local WT = 0.4
local DOOR_HW = 1.1
local SPRING, APEX = 3.1, 3.95 -- the pointed arch: straight sides up to SPRING, the point at APEX
local EAVE_X, RIDGE_Y = 2.8, 5.5

-- ============================================================
-- Ground patch (PrimaryPart), stepped base
-- ============================================================
local base = part(body, "Base", Vector3.new(0.2, 8.8, 8.8), CFrame.new(0, 0.1, 0) * UPRIGHT, GROUND, Enum.Material.Ground, Enum.PartType.Cylinder)
model.PrimaryPart = base
base.PivotOffset = base.CFrame:Inverse() -- pivot on the floor centre, upright
part(body, "Step", Vector3.new(6.6, 0.35, 6.6), CFrame.new(0, 0.375, 0), STONE_DARK)
part(body, "Step", Vector3.new(5.6, 0.3, 5.6), CFrame.new(0, 0.7, 0), STONE)
-- cracks in the steps
for _, c in ipairs({ { -2.2, -3.31, 0.7, 70 }, { 1.4, -3.31, 0.5, -60 }, { 2.5, -2.81, 0.4, 80 } }) do
	part(body, "Crack", Vector3.new(0.05, c[3] * 0.5, 0.04), CFrame.new(c[1], 0.45, c[2]) * CFrame.Angles(0, 0, math.rad(c[4] - 90)), CRACK, Enum.Material.SmoothPlastic)
end

-- ============================================================
-- Chamber: walls, the front with the pointed arch, the dark inside (Pit)
-- ============================================================
local WALL_H = WALL_TOP - FLOOR
local WALL_YC = FLOOR + WALL_H / 2
for _, s in ipairs({ -1, 1 }) do
	part(body, "Wall", Vector3.new(WT, WALL_H, 4.8), CFrame.new(s * (2.5 - WT / 2), WALL_YC, 0), STONE)
	-- the front beside the door
	local w = 2.5 - WT - DOOR_HW
	part(body, "Wall", Vector3.new(w, WALL_H, WT), CFrame.new(s * (DOOR_HW + w / 2), WALL_YC, -2.4 + WT / 2), STONE)
end
part(body, "Wall", Vector3.new(5.0 - 2 * WT, WALL_H, WT), CFrame.new(0, WALL_YC, 2.4 - WT / 2), STONE)
-- stone fill above the pointed arch (one slab along each slope, its lower edge on the arch line)
for _, s in ipairs({ -1, 1 }) do
	local a = Vector2.new(s * DOOR_HW, SPRING)
	local b = Vector2.new(0, APEX)
	local d = (b - a).Unit
	local n = Vector2.new(-d.Y, d.X)
	if n.Y < 0 then n = -n end
	local mid = (a + b) / 2 + n * 0.6
	slopeBlock(body, "Wall", (b - a).Magnitude + 0.8, 1.2, WT, mid.X, mid.Y, -2.4 + WT / 2, d, STONE)
	-- the arch frame: a lighter band of stone just over the arch line
	local fmid = (a + b) / 2 + n * 0.12
	slopeBlock(body, "ArchFrame", (b - a).Magnitude + 0.15, 0.26, 0.12, fmid.X, fmid.Y, -2.43, d, STONE_LIGHT)
	part(body, "ArchFrame", Vector3.new(0.26, SPRING - FLOOR, 0.12), CFrame.new(s * (DOOR_HW + 0.13), FLOOR + (SPRING - FLOOR) / 2, -2.43), STONE_LIGHT)
end
-- the dark inside: lining, ceiling, floor with violet cracks
part(pit, "Inside", Vector3.new(4.15, WALL_H, 0.05), CFrame.new(0, WALL_YC, 2.4 - WT - 0.03), INSIDE, Enum.Material.SmoothPlastic)
for _, s in ipairs({ -1, 1 }) do
	part(pit, "Inside", Vector3.new(0.05, WALL_H, 4.0), CFrame.new(s * (2.5 - WT - 0.03), WALL_YC, 0), INSIDE, Enum.Material.SmoothPlastic)
end
part(pit, "Inside", Vector3.new(4.2, 0.05, 4.0), CFrame.new(0, WALL_TOP - 0.03, 0), INSIDE, Enum.Material.SmoothPlastic)
part(pit, "PitFloor", Vector3.new(4.15, 0.05, 4.0), CFrame.new(0, FLOOR + 0.02, 0), INSIDE, Enum.Material.SmoothPlastic)
for _, c in ipairs({ { -1.1, 0.6, 1.4, 25 }, { 0.6, -0.5, 1.2, -40 }, { 1.2, 1.1, 0.8, 70 } }) do
	part(pit, "Glow", Vector3.new(c[3], 0.03, 0.08), CFrame.new(c[1], FLOOR + 0.06, c[2]) * CFrame.Angles(0, math.rad(c[4]), 0), GLOW, Enum.Material.Neon)
end
local core = part(model, "Core", Vector3.new(0.4, 0.4, 0.4), CFrame.new(0, FLOOR + 0.4, 0), GLOW, Enum.Material.Neon)
core.Transparency = 1

-- ============================================================
-- Gabled roof: gable ends front and back, two roof slabs, a ridge with spikes
-- ============================================================
for _, s in ipairs({ -1, 1 }) do
	local eave = Vector2.new(s * EAVE_X, WALL_TOP)
	local ridge = Vector2.new(0, RIDGE_Y)
	local d = (ridge - eave).Unit
	local n = Vector2.new(-d.Y, d.X)
	if n.Y < 0 then n = -n end
	local mid = (eave + ridge) / 2
	-- the gable end walls (front and back slices), under the roof line
	local gm = mid - n * 0.5
	for _, z in ipairs({ -2.4 + WT / 2, 2.4 - WT / 2 }) do
		slopeBlock(body, "Gable", (ridge - eave).Magnitude, 1.0, WT, gm.X, gm.Y, z, d, STONE)
	end
	-- the roof slab, overhanging at the eave and the ends
	local rm = mid + n * 0.175 - d * 0.25
	slopeBlock(body, "Roof", (ridge - eave).Magnitude + 0.5, 0.35, 5.6, rm.X, rm.Y, 0, d, STONE_LIGHT)
	-- grooves between the roof stones
	for _, z in ipairs({ -1.4, 0, 1.4 }) do
		local gmid = mid + n * 0.36 - d * 0.25
		slopeBlock(body, "Crack", (ridge - eave).Magnitude + 0.4, 0.02, 0.06, gmid.X, gmid.Y, z, d, CRACK, Enum.Material.SmoothPlastic)
	end
end
part(body, "Gable", Vector3.new(2.0, 0.5, WT), CFrame.new(0, WALL_TOP + 0.25, 2.4 - WT / 2), STONE)
part(body, "Ridge", Vector3.new(0.5, 0.5, 6.0), CFrame.new(0, RIDGE_Y + 0.15, 0) * CFrame.Angles(0, 0, math.rad(45)), STONE_LIGHT)
for _, z in ipairs({ -2.85, 2.85 }) do
	part(body, "RidgeCap", Vector3.new(0.6, 0.35, 0.6), CFrame.new(0, RIDGE_Y + 0.5, z), STONE_LIGHT)
	spike(body, Vector3.new(0, RIDGE_Y + 0.75, z), 0.5)
end

-- ============================================================
-- Corner pillars with spikes
-- ============================================================
for _, sx in ipairs({ -1, 1 }) do
	for _, sz in ipairs({ -1, 1 }) do
		local x, z = sx * 2.65, sz * 2.55
		part(body, "PillarFoot", Vector3.new(1.25, 0.6, 1.25), CFrame.new(x, 0.85, z), STONE_DARK)
		part(body, "Pillar", Vector3.new(0.85, 2.55, 0.85), CFrame.new(x, 1.15 + 2.55 / 2, z), STONE)
		part(body, "Band", Vector3.new(1.0, 0.15, 1.0), CFrame.new(x, 2.4, z), STONE_LIGHT)
		part(body, "Cap", Vector3.new(1.05, 0.3, 1.05), CFrame.new(x, 3.85, z), STONE_LIGHT)
		part(body, "Cap", Vector3.new(0.75, 0.2, 0.75), CFrame.new(x, 4.1, z), STONE)
		spike(body, Vector3.new(x, 4.35, z), 0.62)
	end
end
-- violet cracks in the front stones (they glow during the buildup)
for _, c in ipairs({ { -1.75, 1.4, 0.6, 15 }, { 1.75, 3.0, 0.5, -25 } }) do
	part(body, "Glow", Vector3.new(0.05, c[3], 0.04), CFrame.new(c[1], c[2], -2.42) * CFrame.Angles(0, 0, math.rad(c[4])), GLOW, Enum.Material.Neon)
end

-- ============================================================
-- The door (Lid.Door): two stone leaves with a pointed top, a glowing seam and runes; falls round its Hinge
-- ============================================================
local DOOR_T = 0.25
local DOOR_Z = -2.4 + 0.15 + DOOR_T / 2 -- a little set back into the wall
local DOOR_FRONT = DOOR_Z - DOOR_T / 2
for _, s in ipairs({ -1, 1 }) do
	part(door, "Leaf", Vector3.new(DOOR_HW - 0.03, SPRING - FLOOR, DOOR_T), CFrame.new(s * (DOOR_HW / 2 + 0.015), FLOOR + (SPRING - FLOOR) / 2, DOOR_Z), DOOR)
	-- the pointed top: a slab along each slope, its upper edge on the arch line
	local a = Vector2.new(s * DOOR_HW, SPRING)
	local b = Vector2.new(0, APEX)
	local d = (b - a).Unit
	local n = Vector2.new(-d.Y, d.X)
	if n.Y < 0 then n = -n end
	local mid = (a + b) / 2 - n * 0.45
	slopeBlock(door, "Leaf", (b - a).Magnitude, 0.9, DOOR_T, mid.X, mid.Y, DOOR_Z, d, DOOR)
	-- runes: a pair of chevrons on each leaf, a short bar under them
	local rx = s * 0.55
	for k, ry in ipairs({ 2.75, 2.2 }) do
		for _, side in ipairs({ -1, 1 }) do
			part(door, "Glow", Vector3.new(0.06, 0.42, 0.03), CFrame.new(rx + side * 0.13, ry, DOOR_FRONT - 0.015) * CFrame.Angles(0, 0, math.rad(side * s * 35)), GLOW, Enum.Material.Neon)
		end
		if k == 2 then
			part(door, "Glow", Vector3.new(0.06, 0.7, 0.03), CFrame.new(rx, 1.45, DOOR_FRONT - 0.015), GLOW, Enum.Material.Neon)
		end
	end
end
-- the seam between the leaves
part(door, "Glow", Vector3.new(0.05, APEX - FLOOR - 0.1, 0.03), CFrame.new(0, FLOOR + (APEX - FLOOR) / 2 - 0.05, DOOR_FRONT - 0.01), GLOW, Enum.Material.Neon)
local hinge = part(door, "Hinge", Vector3.new(0.2, 0.2, 0.2), CFrame.new(0, FLOOR, DOOR_FRONT), GLOW, Enum.Material.SmoothPlastic)
hinge.Transparency = 1

-- ============================================================
-- Chains (round the crypt and across the door) and the padlock: Lid parts that fly off
-- ============================================================
local function chain(a, b)
	local len = (b - a).Magnitude
	local count = math.max(2, math.floor(len / 0.44))
	local along = (b - a).Unit
	for i = 0, count - 1 do
		local p = a + along * ((i + 0.5) / count * len)
		local cf = CFrame.lookAt(p, p + along) * CFrame.Angles(0, math.rad(90), 0) -- X along the chain
		if i % 2 == 1 then
			cf *= CFrame.Angles(math.rad(90), 0, 0)
		end
		part(lid, "Chain", Vector3.new(0.56, 0.3, 0.13), cf, RUST, Enum.Material.Metal)
	end
end
local LOCK = Vector3.new(0, 2.0, DOOR_FRONT - 0.32)
local CY = 2.55
for _, s in ipairs({ -1, 1 }) do
	-- front: from the front pillars sagging down to the padlock
	chain(Vector3.new(s * 2.7, CY, -3.04), LOCK + Vector3.new(s * 0.3, 0.15, 0))
	-- the sides and the back, just outside the pillars
	chain(Vector3.new(s * 3.14, CY, -2.6), Vector3.new(s * 3.14, CY, 2.6))
end
chain(Vector3.new(-2.7, CY, 3.04), Vector3.new(2.7, CY, 3.04))
part(lid, "Padlock", Vector3.new(0.75, 0.62, 0.26), CFrame.new(LOCK), IRON, Enum.Material.Metal)
part(lid, "Keyhole", Vector3.new(0.12, 0.26, 0.04), CFrame.new(LOCK + Vector3.new(0, -0.05, -0.14)), CRACK, Enum.Material.SmoothPlastic)
for _, s in ipairs({ -1, 1 }) do
	part(lid, "Shackle", Vector3.new(0.1, 0.42, 0.1), CFrame.new(LOCK + Vector3.new(s * 0.22, 0.48, 0)), RUST, Enum.Material.Metal)
	for _, sy in ipairs({ -1, 1 }) do
		part(lid, "Rivet", Vector3.new(0.09, 0.09, 0.09), CFrame.new(LOCK + Vector3.new(s * 0.27, sy * 0.21, -0.14)), RUST, Enum.Material.Metal, Enum.PartType.Ball)
	end
end
part(lid, "Shackle", Vector3.new(0.54, 0.1, 0.1), CFrame.new(LOCK + Vector3.new(0, 0.7, 0)), RUST, Enum.Material.Metal)

-- ============================================================
-- Violet smoke creeping round the foot (only shows in the world, ViewportFrames draw no particles)
-- ============================================================
for _, p in ipairs({ Vector3.new(-3.2, 0.4, -2.8), Vector3.new(3.3, 0.4, 0.6), Vector3.new(-0.5, 0.4, 3.3) }) do
	local src = part(body, "Wisps", Vector3.new(0.3, 0.3, 0.3), CFrame.new(p), GLOW, Enum.Material.SmoothPlastic)
	src.Transparency = 1
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	e.Color = ColorSequence.new(GLOW, Color3.fromRGB(70, 20, 120))
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 2.2) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.6), NumberSequenceKeypoint.new(1, 1) })
	e.Lifetime = NumberRange.new(2.5, 4)
	e.Speed = NumberRange.new(0.3, 0.8)
	e.SpreadAngle = Vector2.new(60, 60)
	e.Acceleration = Vector3.new(0, 0.5, 0)
	e.RotSpeed = NumberRange.new(-20, 20)
	e.LightEmission = 0.6
	e.Rate = 2.5
	e.Parent = src
end

-- ============================================================
-- Attributes and placement
-- ============================================================
model:SetAttribute("OpenStyle", "Door")
model:SetAttribute("GlowColor", GLOW)
model:SetAttribute("DebrisColor", STONE)
model:SetAttribute("Height", RIDGE_Y + 0.9)
model:SetAttribute("FallAngle", 97)
model:SetAttribute("FloorHeight", FLOOR)
model:SetAttribute("DoorHeight", APEX - FLOOR)
model:SetAttribute("WalkOut", 6.2)
model.Parent = folder

-- a preview next to the other graves' (behind the hub spawn); delete Workspace.GravePreview before publishing
local preview = workspace:FindFirstChild("GravePreview")
if not preview then
	preview = Instance.new("Folder")
	preview.Name = "GravePreview"
	preview.Parent = workspace
end
local oldCopy = preview:FindFirstChild("Cursed")
if oldCopy then
	oldCopy:Destroy()
end
local copy = model:Clone()
copy:PivotTo(CFrame.new(30, -1.7, 40))
copy.Parent = preview

local count = 0
for _, d in ipairs(model:GetDescendants()) do
	if d:IsA("BasePart") then count += 1 end
end
return "Cursed crypt built: " .. count .. " parts"
