-- Realm 1 hazard: replaces the terrain water inside the outer wall with a lava sea (see Design.md, "Wall rework").
-- Builds Workspace.Lava: one big lava surface just below the lane floor (CrackedLava material, orange-red), glowing lava
-- pools and ember emitters scattered over it. The surface is named "Surface"; the server module Lava sends players who
-- touch it back to their plot. The walls' earth banks run down into it.
-- Run in Edit mode via the Studio MCP execute_luau (or loadstring over a local http.server, see CLAUDE.md). Safe to re-run.
-- The water OUTSIDE the outer wall is kept (nobody sees it over the 70-stud ring).
local Terrain = workspace.Terrain

local RING_RADIUS = 392 -- inner radius of the outer wall (build_ring.lua)
local FLOOR_Y = -1.7 -- top of the plaza / plot / lane floors
local LAVA_Y = FLOOR_Y - 0.9 -- top of the lava surface
local LAVA = Color3.fromRGB(255, 104, 36)
local LAVA_HOT = Color3.fromRGB(255, 132, 40)
local EMBER = Color3.fromRGB(255, 150, 60)

local old = workspace:FindFirstChild("Lava")
if old then
	old:Destroy()
end

-- ============================================================
-- Clear the water inside the ring (a cylinder of air from the sea floor up to above the old surface)
-- ============================================================
Terrain:FillCylinder(CFrame.new(0, -30, 0), 64, RING_RADIUS + 10, Enum.Material.Air)

local folder = Instance.new("Folder")
folder.Name = "Lava"

local function part(name, size, cf, color, material, shape)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if shape then
		p.Shape = shape
	end
	p.Parent = folder
	return p
end

-- ============================================================
-- The surface: a flat disc under the whole arena (floors, plots and lanes stand above it)
-- ============================================================
local surface = part("Surface", Vector3.new(4, (RING_RADIUS + 6) * 2, (RING_RADIUS + 6) * 2),
	CFrame.new(0, LAVA_Y - 2, 0) * CFrame.Angles(0, 0, math.rad(90)), LAVA, Enum.Material.CrackedLava, Enum.PartType.Cylinder)
surface.CanCollide = true -- players land on it (and are sent back to their plot, see the server module Lava)
surface.CanTouch = true
surface:SetAttribute("LavaY", LAVA_Y)

-- ============================================================
-- Glowing pools and embers scattered over the lava (between the lanes; under a floor they are simply hidden)
-- ============================================================
local rng = Random.new(5150)
local LAVA_DEEP = Color3.fromRGB(210, 70, 22) -- pools are opaque and a bit darker, so the bloom does not blow them out
local LAVA_MID = Color3.fromRGB(235, 96, 28)

-- one flat piece of glowing lava lying on the surface (`lift` stacks overlapping pieces so they never z-fight)
local function flat(name, w, d, pos, yaw, color, lift)
	return part(name, Vector3.new(w, 0.12, d), CFrame.new(pos + Vector3.new(0, lift, 0)) * CFrame.Angles(0, yaw, 0), color, Enum.Material.Neon)
end

for i = 1, 70 do
	local r = rng:NextNumber(70, RING_RADIUS - 8)
	local a = rng:NextNumber(0, math.pi * 2)
	local centre = Vector3.new(math.cos(a) * r, LAVA_Y + 0.02, math.sin(a) * r)
	local size = rng:NextNumber(6, 18)
	-- a ragged pool: a few overlapping rotated slabs of different sizes, the hottest one in the middle
	local blobs = rng:NextInteger(3, 6)
	local hot
	for k = 1, blobs do
		local off = Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1)) * size * 0.35
		local w = size * rng:NextNumber(0.35, 0.8)
		local d = w * rng:NextNumber(0.3, 0.8)
		local color = (k == blobs) and LAVA_HOT or (k % 2 == 0 and LAVA_MID or LAVA_DEEP)
		local piece = flat("Pool", w, d, centre + off, rng:NextNumber(0, math.pi), color, k * 0.03)
		if k == blobs then
			hot = piece
		end
	end
	-- glowing rivulets running out of the pool: a few short crooked strokes each
	for _ = 1, rng:NextInteger(1, 3) do
		local pos = centre
		local dir = rng:NextNumber(0, math.pi * 2)
		for _ = 1, rng:NextInteger(2, 4) do
			dir += rng:NextNumber(-0.6, 0.6)
			local len = rng:NextNumber(2.5, 6)
			local step = Vector3.new(math.cos(dir), 0, math.sin(dir)) * len
			flat("Rivulet", rng:NextNumber(0.4, 0.9), len + 0.4, pos + step / 2, -dir + math.pi / 2, LAVA_DEEP, 0.01)
			pos += step
		end
	end
	if i % 3 == 0 and hot then
		local e = Instance.new("ParticleEmitter")
		e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		e.Color = ColorSequence.new(EMBER)
		e.LightEmission = 1
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
		e.Lifetime = NumberRange.new(2, 4)
		e.Speed = NumberRange.new(2, 5)
		e.SpreadAngle = Vector2.new(25, 25)
		e.Acceleration = Vector3.new(0, 1.5, 0)
		e.Rate = 4
		e.EmissionDirection = Enum.NormalId.Top
		e.Parent = hot
	end
end

folder.Parent = workspace
return "lava built, water cleared inside the ring"
