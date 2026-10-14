-- Builds the Realm 1 gate (the 4th wall of a run) into ServerStorage.WallModels.CemeteryGate: a mausoleum in the middle
-- of a taller crescent of cemetery wall (see Design.md, "Realm 1"). A stepped mausoleum front with columns, a pediment
-- with a skull and a stone angel on top, an iron double gate chained shut with a padlock, soul light behind the bars,
-- two braziers with green fire, fieldstone wings with lantern pillars, tombstones and dead trees, all on an earth bank.
-- Walls.lua clones it for the gate; the damage stages are animated on the client (Modules/WallStages): the chains fall,
-- the angel falls, the doors sag and finally burst open.
-- Run in Edit mode via the Studio MCP execute_luau (or loadstring over a local http.server, see CLAUDE.md). Safe to re-run.
--
-- Conventions: like build_wall_cemetery.lua (origin = floor centre of the wall's middle, FRONT faces -Z).
local ServerStorage = game:GetService("ServerStorage")

local folder = ServerStorage:FindFirstChild("WallModels")
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "WallModels"
	folder.Parent = ServerStorage
end
local old = folder:FindFirstChild("CemeteryGate")
if old then
	old:Destroy()
end

-- ============================================================
-- Palette (the cemetery wall's, plus the mausoleum's dressed stone)
-- ============================================================
local STONE = {
	Color3.fromRGB(104, 106, 100),
	Color3.fromRGB(116, 117, 110),
	Color3.fromRGB(92, 95, 92),
	Color3.fromRGB(126, 124, 114),
}
local STONE_DARK = Color3.fromRGB(70, 72, 70)
local STONE_LIGHT = Color3.fromRGB(146, 144, 134)
local MAUSOLEUM = Color3.fromRGB(132, 130, 122)
local MAUSOLEUM_DARK = Color3.fromRGB(96, 95, 90)
local ANGEL = Color3.fromRGB(156, 154, 144)
local VOID = Color3.fromRGB(14, 16, 18)
local MOSS = Color3.fromRGB(74, 98, 52)
local MOSS_DARK = Color3.fromRGB(54, 74, 40)
local IRON = Color3.fromRGB(62, 48, 40)
local IRON_DARK = Color3.fromRGB(40, 34, 32)
local WOOD = Color3.fromRGB(58, 46, 38)
local ROOT = Color3.fromRGB(64, 50, 40)
local LAMP = Color3.fromRGB(255, 190, 110)
local SOUL = Color3.fromRGB(120, 255, 190)
local GRAVE = Color3.fromRGB(120, 122, 118)
local DIRT = Color3.fromRGB(56, 48, 42)
local DIRT_DARK = Color3.fromRGB(42, 36, 32)
local ROCK = Color3.fromRGB(82, 80, 78)

-- ============================================================
-- Shape
-- ============================================================
local R = 45 -- radius of the crescent's arc (as the cemetery wall)
local INNER = math.rad(14) -- the wings start here (the mausoleum fills the middle)
local MAX_ANGLE = math.rad(52)
local WING_SEGMENTS = 6 -- per side
local H_IN, H_END = 22, 11 -- wing height next to the mausoleum / at the ends
local T_IN, T_END = 4.5, 3.2
local FLOOR = 1.6 -- top of the mausoleum's podium (the doorway floor)
local DOOR_HALF = 5 -- the doorway is 10 wide
local DOOR_H = 15.2

local rng = Random.new(2207)

local model = Instance.new("Model")
model.Name = "CemeteryGate"
local wallM = Instance.new("Model")
wallM.Name = "Wall"
wallM.Parent = model
local decorM = Instance.new("Model")
decorM.Name = "Decor"
decorM.Parent = model
local groundM = Instance.new("Model")
groundM.Name = "Ground"
groundM.Parent = model

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

local function wedge(parent, name, size, cf, color, material)
	local p = Instance.new("WedgePart")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CastShadow = false
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.Slate
	p.Parent = parent
	return p
end

-- a small sub-model (one piece the client animates as a whole, see Modules/WallStages) with its pivot at `pivot`
local function group(parent, name, pivot)
	local m = Instance.new("Model")
	m.Name = name
	m.WorldPivot = pivot
	m.Parent = parent
	return m
end

-- a cylinder from a to b (Roblox cylinders run along X)
local function rod(parent, name, a, b, thickness, color, material)
	local len = (b - a).Magnitude
	local cf = CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.rad(90), 0)
	return part(parent, name, Vector3.new(len, thickness, thickness), cf, color, material or Enum.Material.Wood, Enum.PartType.Cylinder)
end

-- an upright cylinder standing on `foot` (height h, diameter d)
local function column(parent, name, foot, h, d, color, material)
	return part(parent, name, Vector3.new(h, d, d), foot * CFrame.new(0, h / 2, 0) * CFrame.Angles(0, 0, math.rad(90)), color, material, Enum.PartType.Cylinder)
end

local function light(parentPart, color, range, brightness)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Shadows = false
	l.Parent = parentPart
	return l
end

local function arcPoint(a)
	return Vector3.new(R * math.sin(a), 0, -R + R * math.cos(a))
end
local function arcFrame(a, y)
	local p = arcPoint(a)
	local tangent = Vector3.new(math.cos(a), 0, -math.sin(a))
	return CFrame.fromMatrix(p + Vector3.new(0, y or 0, 0), tangent, Vector3.yAxis)
end
local function wingF(a)
	return math.clamp((math.abs(a) - INNER) / (MAX_ANGLE - INNER), 0, 1)
end
local function heightAt(a)
	return H_IN - (H_IN - H_END) * wingF(a) ^ 1.2
end
local function thicknessAt(a)
	return T_IN - (T_IN - T_END) * wingF(a)
end

-- ============================================================
-- Base (PrimaryPart, invisible, at the origin)
-- ============================================================
local base = part(model, "Base", Vector3.new(4, 0.2, 4), CFrame.new(0, 0.1, 0), DIRT)
base.Transparency = 1
model.PrimaryPart = base

-- ============================================================
-- Wings: fieldstone segments along the arc on both sides of the mausoleum
-- ============================================================
local step = (MAX_ANGLE - INNER) / WING_SEGMENTS
local chord = 2 * R * math.sin(step / 2)
for _, side in ipairs({ -1, 1 }) do
	for i = 0, WING_SEGMENTS - 1 do
		local a = side * (INNER + (i + 0.5) * step)
		local h = heightAt(a)
		local t = thicknessAt(a)
		local w = chord + 0.5
		local foot = arcFrame(a)
		part(wallM, "Plinth", Vector3.new(w + 0.3, 1.6, t + 1.4), foot * CFrame.new(0, 0.8, 0), STONE_DARK, Enum.Material.Slate)
		local seg = group(wallM, "Segment", foot)
		seg:SetAttribute("Angle", math.deg(a))
		seg:SetAttribute("Height", h)
		seg:SetAttribute("Thickness", t)
		seg:SetAttribute("Width", w)
		part(seg, "Stone", Vector3.new(w, h, t), foot * CFrame.new(0, h / 2, 0), STONE[rng:NextInteger(1, #STONE)], Enum.Material.Cobblestone)
		local cope = part(seg, "Coping", Vector3.new(w + 0.2, 0.9, t + 0.7),
			foot * CFrame.new(0, h + 0.4, 0) * CFrame.Angles(0, 0, math.rad(rng:NextNumber(-2.5, 2.5))), STONE_LIGHT, Enum.Material.Slate)
		for _ = 1, 2 do
			part(seg, "Fieldstone", Vector3.new(rng:NextNumber(1.4, 2.6), rng:NextNumber(0.9, 1.6), 0.7),
				foot * CFrame.new(rng:NextNumber(-w / 2 + 1, w / 2 - 1), rng:NextNumber(2.5, h - 2), -t / 2 - 0.1) * CFrame.Angles(0, 0, math.rad(rng:NextNumber(-8, 8))),
				STONE[rng:NextInteger(1, #STONE)], Enum.Material.Slate)
		end
		if rng:NextNumber() < 0.6 then
			part(seg, "Moss", Vector3.new(w * rng:NextNumber(0.4, 0.9), 0.25, t + 0.8), cope.CFrame * CFrame.new(rng:NextNumber(-1, 1), 0.55, 0),
				MOSS, Enum.Material.Grass)
		end
		if rng:NextNumber() < 0.5 then
			local mh = rng:NextNumber(2, 5)
			part(seg, "Moss", Vector3.new(rng:NextNumber(1.5, 3), mh, 0.2), foot * CFrame.new(rng:NextNumber(-1.5, 1.5), 1.6 + mh / 2, -t / 2 - 0.12),
				MOSS_DARK, Enum.Material.Grass)
		end
	end
end

-- ============================================================
-- The mausoleum: podium and steps, two piers with columns, the lintel with an arched doorway and a pediment
-- ============================================================
local DEPTH_FRONT, DEPTH_BACK = -1.5, 10.5 -- the mausoleum's front and back (z)
local depth = DEPTH_BACK - DEPTH_FRONT
local midZ = (DEPTH_FRONT + DEPTH_BACK) / 2
part(wallM, "Podium", Vector3.new(26, FLOOR, depth + 0.6), CFrame.new(0, FLOOR / 2, midZ - 0.3), MAUSOLEUM_DARK, Enum.Material.Slate)
part(wallM, "Step", Vector3.new(15, 0.8, 1.8), CFrame.new(0, 0.4, DEPTH_FRONT - 1.5), MAUSOLEUM_DARK, Enum.Material.Slate)
part(wallM, "Step", Vector3.new(13, 0.8, 1.2), CFrame.new(0, 1.2, DEPTH_FRONT - 0.9), MAUSOLEUM_DARK, Enum.Material.Slate)

-- the doorway's dark inside, soul light deep in the tomb
part(wallM, "Inside", Vector3.new(DOOR_HALF * 2, DOOR_H, 0.4), CFrame.new(0, FLOOR + DOOR_H / 2, 3), VOID, Enum.Material.Slate)
local soul = part(wallM, "SoulLight", Vector3.new(DOOR_HALF * 2 - 2, DOOR_H - 3, 0.3), CFrame.new(0, FLOOR + DOOR_H / 2 - 1, 2.6), SOUL, Enum.Material.Neon)
soul.Transparency = 0.6
light(soul, SOUL, 16, 0.9)

local PIER_W, PIER_H = 7, 22
for _, side in ipairs({ -1, 1 }) do
	local x = side * (DOOR_HALF + PIER_W / 2)
	local foot = CFrame.new(x, FLOOR, midZ)
	local pier = group(wallM, "Segment", foot)
	pier:SetAttribute("Angle", 0)
	pier:SetAttribute("Height", PIER_H)
	pier:SetAttribute("Thickness", depth)
	pier:SetAttribute("Width", PIER_W)
	pier:SetAttribute("Sink", 0.15) -- at 25 % the mausoleum only sags (the doors stand in front of it)
	part(pier, "Stone", Vector3.new(PIER_W, PIER_H, depth), foot * CFrame.new(0, PIER_H / 2, 0), MAUSOLEUM, Enum.Material.Slate)
	-- a dark niche in the front
	part(pier, "Niche", Vector3.new(3.2, 6, 0.3), CFrame.new(x + side * 0.6, FLOOR + 12, DEPTH_FRONT - 0.1), VOID, Enum.Material.Slate)
	part(pier, "NicheTop", Vector3.new(0.3, 3.2, 3.2), CFrame.new(x + side * 0.6, FLOOR + 15, DEPTH_FRONT - 0.1) * CFrame.Angles(0, math.rad(90), 0),
		VOID, Enum.Material.Slate, Enum.PartType.Cylinder)
	-- a column beside the doorway
	local colFoot = CFrame.new(side * (DOOR_HALF + 1.4), FLOOR, DEPTH_FRONT - 1.2)
	part(pier, "ColumnBase", Vector3.new(3, 1, 3), colFoot * CFrame.new(0, 0.5, 0), MAUSOLEUM_DARK, Enum.Material.Slate)
	column(pier, "Column", colFoot * CFrame.new(0, 1, 0), 17, 2.2, MAUSOLEUM, Enum.Material.Slate)
	part(pier, "Capital", Vector3.new(3.2, 1.1, 3.2), colFoot * CFrame.new(0, 18.5, 0), MAUSOLEUM_DARK, Enum.Material.Slate)
	part(pier, "Moss", Vector3.new(PIER_W + 0.2, 0.3, depth + 0.2), foot * CFrame.new(0, PIER_H + 0.1, 0), MOSS, Enum.Material.Grass)
	part(pier, "Moss", Vector3.new(2.4, rng:NextNumber(3, 6), 0.2), CFrame.new(x - side * 1.5, FLOOR + 2.5, DEPTH_FRONT - 0.12), MOSS_DARK, Enum.Material.Grass)
end

do
	-- the lintel, the arch over the doorway, the cornice, the pediment with a skull, the gabled roof
	local foot = CFrame.new(0, FLOOR, midZ)
	local top = group(wallM, "Segment", foot)
	top:SetAttribute("Angle", 0)
	top:SetAttribute("Height", PIER_H + 9)
	top:SetAttribute("Thickness", depth)
	top:SetAttribute("Width", 24)
	top:SetAttribute("Sink", 0.15)
	top:SetAttribute("NoCracks", true)
	local y0 = FLOOR + PIER_H -- top of the piers
	part(top, "Tympanum", Vector3.new(DOOR_HALF * 2, PIER_H - DOOR_H, depth), CFrame.new(0, FLOOR + DOOR_H + (PIER_H - DOOR_H) / 2, midZ), MAUSOLEUM, Enum.Material.Slate)
	part(top, "Arch", Vector3.new(0.3, DOOR_HALF * 2, DOOR_HALF * 2), CFrame.new(0, FLOOR + DOOR_H - 0.5, DEPTH_FRONT - 0.12) * CFrame.Angles(0, math.rad(90), 0),
		VOID, Enum.Material.Slate, Enum.PartType.Cylinder)
	part(top, "Lintel", Vector3.new(25, 3, depth + 0.6), CFrame.new(0, y0 + 1.5, midZ), MAUSOLEUM_DARK, Enum.Material.Slate)
	part(top, "Inscription", Vector3.new(14, 1.1, 0.2), CFrame.new(0, y0 + 1.5, DEPTH_FRONT - 0.42), VOID, Enum.Material.Slate)
	part(top, "Cornice", Vector3.new(27, 0.8, depth + 1.6), CFrame.new(0, y0 + 3.4, midZ), STONE_LIGHT, Enum.Material.Slate)
	local py = y0 + 3.8 -- the pediment sits on the cornice
	local ph, pw = 6, 12.5
	wedge(top, "Pediment", Vector3.new(2, ph, pw), CFrame.new(-pw / 2, py + ph / 2, DEPTH_FRONT) * CFrame.Angles(0, math.rad(90), 0), MAUSOLEUM, Enum.Material.Slate)
	wedge(top, "Pediment", Vector3.new(2, ph, pw), CFrame.new(pw / 2, py + ph / 2, DEPTH_FRONT) * CFrame.Angles(0, math.rad(-90), 0), MAUSOLEUM, Enum.Material.Slate)
	local slope = math.atan2(ph, pw)
	local roofLen = math.sqrt(ph * ph + pw * pw) + 0.6
	for _, side in ipairs({ -1, 1 }) do
		part(top, "Roof", Vector3.new(roofLen, 0.8, depth + 1.2), CFrame.new(side * pw / 2, py + ph / 2 + 0.3, midZ + 0.4) * CFrame.Angles(0, 0, -side * slope),
			STONE_DARK, Enum.Material.Slate)
	end
	part(top, "Moss", Vector3.new(6, 0.3, depth), CFrame.new(-4, py + ph * 0.66 + 0.75, midZ) * CFrame.Angles(0, 0, slope), MOSS, Enum.Material.Grass)
	-- a carved skull in the pediment, faint soul light in its eyes
	local skullY = py + 2.3
	part(top, "Skull", Vector3.new(2.2, 2, 0.6), CFrame.new(0, skullY, DEPTH_FRONT - 1.05), ANGEL, Enum.Material.Slate)
	part(top, "Skull", Vector3.new(1.4, 0.8, 0.6), CFrame.new(0, skullY - 1.2, DEPTH_FRONT - 1.05), ANGEL, Enum.Material.Slate)
	for _, side in ipairs({ -1, 1 }) do
		part(top, "SkullEye", Vector3.new(0.5, 0.5, 0.2), CFrame.new(side * 0.5, skullY + 0.1, DEPTH_FRONT - 1.4), SOUL, Enum.Material.Neon)
	end

	-- ============================================================
	-- The stone angel on the apex (a "Topper": tilts at 50 %, falls at 25 %)
	-- ============================================================
	local apex = CFrame.new(0, py + ph, DEPTH_FRONT + 0.5)
	local angel = group(decorM, "Angel", apex)
	part(angel, "Plinth", Vector3.new(2.8, 1, 2.6), apex * CFrame.new(0, 0.5, 0), MAUSOLEUM_DARK, Enum.Material.Slate)
	part(angel, "Robe", Vector3.new(2.4, 3.6, 1.9), apex * CFrame.new(0, 2.8, 0), ANGEL, Enum.Material.Slate)
	part(angel, "Torso", Vector3.new(2, 2.2, 1.5), apex * CFrame.new(0, 5.7, 0), ANGEL, Enum.Material.Slate)
	part(angel, "Head", Vector3.new(1.3, 1.3, 1.3), apex * CFrame.new(0, 7.5, -0.1), ANGEL, Enum.Material.Slate, Enum.PartType.Ball)
	part(angel, "Hood", Vector3.new(1.5, 0.9, 1.4), apex * CFrame.new(0, 7.9, 0.1), MAUSOLEUM_DARK, Enum.Material.Slate)
	for _, side in ipairs({ -1, 1 }) do
		-- forearms meeting in prayer in front of the chest
		part(angel, "Arm", Vector3.new(0.55, 0.55, 1.7), apex * CFrame.new(side * 0.55, 5.6, -0.9) * CFrame.Angles(math.rad(-35), math.rad(side * 25), 0), ANGEL, Enum.Material.Slate)
		-- folded wings rising behind the shoulders
		part(angel, "Wing", Vector3.new(0.4, 5.2, 2.4), apex * CFrame.new(side * 1.3, 6.4, 0.9) * CFrame.Angles(math.rad(12), 0, math.rad(-side * 18)), ANGEL, Enum.Material.Slate)
		part(angel, "Wing", Vector3.new(0.35, 3.4, 1.8), apex * CFrame.new(side * 1.9, 4.2, 1.2) * CFrame.Angles(math.rad(8), 0, math.rad(-side * 8)), MAUSOLEUM, Enum.Material.Slate)
	end
	part(angel, "Moss", Vector3.new(2.2, 0.3, 1.6), apex * CFrame.new(0, 6.85, 0), MOSS, Enum.Material.Grass)
end

-- ============================================================
-- The iron double gate (two "Door" models hinged at the doorway's sides) and the chains with a padlock
-- ============================================================
for _, side in ipairs({ -1, 1 }) do
	local dir = -side -- the leaf reaches from its hinge towards the middle
	local hinge = CFrame.new(side * DOOR_HALF, FLOOR, DEPTH_FRONT - 0.45) -- hung in front of the facade (and the dark arch)
	local door = group(decorM, "Door", hinge)
	local function at(x, y)
		return hinge * CFrame.new(dir * x, y, 0)
	end
	for _, x in ipairs({ 0.25, DOOR_HALF - 0.25 }) do
		part(door, "Stile", Vector3.new(0.45, DOOR_H, 0.45), at(x, DOOR_H / 2), IRON_DARK, Enum.Material.CorrodedMetal)
	end
	for _, y in ipairs({ 0.6, DOOR_H * 0.5, DOOR_H - 0.6 }) do
		part(door, "Rail", Vector3.new(DOOR_HALF, 0.4, 0.4), at(DOOR_HALF / 2, y), IRON_DARK, Enum.Material.CorrodedMetal)
	end
	for k = 0, 4 do
		local x = 0.85 + k * 0.85
		part(door, "Bar", Vector3.new(0.22, DOOR_H, 0.22), at(x, DOOR_H / 2), IRON, Enum.Material.CorrodedMetal)
		part(door, "Spike", Vector3.new(0.4, 0.4, 0.4), at(x, DOOR_H + 0.25) * CFrame.Angles(math.rad(45), 0, math.rad(45)), IRON_DARK, Enum.Material.CorrodedMetal)
	end
	part(door, "Ring", Vector3.new(0.25, 2.6, 2.6), at(DOOR_HALF / 2, DOOR_H * 0.68) * CFrame.Angles(0, math.rad(90), 0), IRON_DARK, Enum.Material.CorrodedMetal, Enum.PartType.Cylinder)
	part(door, "RingHole", Vector3.new(0.3, 1.8, 1.8), at(DOOR_HALF / 2, DOOR_H * 0.68) * CFrame.Angles(0, math.rad(90), 0), VOID, Enum.Material.Slate, Enum.PartType.Cylinder)
end

do
	local z = DEPTH_FRONT - 0.85
	local chains = group(decorM, "Chains", CFrame.new(0, FLOOR + 7.5, z))
	local function chain(a, b)
		local n = 9
		local dir = (b - a).Unit
		for k = 0, n - 1 do
			local p = a:Lerp(b, (k + 0.5) / n)
			part(chains, "Link", Vector3.new(0.18, 0.55, (b - a).Magnitude / n + 0.25), CFrame.lookAt(p, p + dir) * CFrame.Angles(0, 0, k % 2 == 0 and 0 or math.rad(90)),
				IRON, Enum.Material.CorrodedMetal)
		end
	end
	chain(Vector3.new(-DOOR_HALF + 0.4, FLOOR + 11.5, z), Vector3.new(DOOR_HALF - 0.4, FLOOR + 4, z))
	chain(Vector3.new(DOOR_HALF - 0.4, FLOOR + 11.5, z), Vector3.new(-DOOR_HALF + 0.4, FLOOR + 4, z))
	part(chains, "Padlock", Vector3.new(1.4, 1.6, 0.6), CFrame.new(0, FLOOR + 7.2, z - 0.4), IRON_DARK, Enum.Material.CorrodedMetal)
	part(chains, "Shackle", Vector3.new(1, 0.25, 0.25), CFrame.new(0, FLOOR + 8.6, z - 0.4), IRON, Enum.Material.CorrodedMetal)
	for _, side in ipairs({ -1, 1 }) do
		part(chains, "Shackle", Vector3.new(0.25, 0.9, 0.25), CFrame.new(side * 0.4, FLOOR + 8.2, z - 0.4), IRON, Enum.Material.CorrodedMetal)
	end
end

-- ============================================================
-- Braziers with green soul fire in front of the steps
-- ============================================================
for _, side in ipairs({ -1, 1 }) do
	local foot = CFrame.new(side * 9.5, 0, DEPTH_FRONT - 5)
	local brazier = group(decorM, "Brazier", foot)
	part(brazier, "Foot", Vector3.new(2, 0.6, 2), foot * CFrame.new(0, 0.3, 0), STONE_DARK, Enum.Material.Slate)
	column(brazier, "Stem", foot * CFrame.new(0, 0.6, 0), 2.6, 1.2, IRON_DARK, Enum.Material.CorrodedMetal)
	column(brazier, "Bowl", foot * CFrame.new(0, 3.1, 0), 0.9, 3, IRON, Enum.Material.CorrodedMetal)
	local fire = part(brazier, "Flame", Vector3.new(1.3, 1.6, 1.3), foot * CFrame.new(0, 4.6, 0) * CFrame.Angles(0, math.rad(45), 0), SOUL, Enum.Material.Neon)
	part(brazier, "Flame", Vector3.new(0.8, 1.2, 0.8), foot * CFrame.new(0.2, 5.6, 0.1) * CFrame.Angles(0, math.rad(20), math.rad(10)), SOUL, Enum.Material.Neon)
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/fire_main.dds"
	e.Color = ColorSequence.new(SOUL)
	e.LightEmission = 1
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.6), NumberSequenceKeypoint.new(1, 0) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
	e.Lifetime = NumberRange.new(0.5, 0.9)
	e.Speed = NumberRange.new(3, 5)
	e.SpreadAngle = Vector2.new(12, 12)
	e.Rate = 18
	e.Parent = fire
	light(fire, SOUL, 18, 1.5)
end

-- ============================================================
-- Buttress pillars with hanging lanterns (beside the mausoleum and at the wing ends)
-- ============================================================
local function pillar(a, extra)
	local h = heightAt(math.clamp(a, -MAX_ANGLE, MAX_ANGLE)) + extra
	local foot = arcFrame(a)
	part(decorM, "Pillar", Vector3.new(4.2, 1.8, 4.2), foot * CFrame.new(0, 0.9, 0), STONE_DARK, Enum.Material.Slate)
	part(decorM, "Pillar", Vector3.new(3.4, h, 3.4), foot * CFrame.new(0, h / 2, 0), STONE[2], Enum.Material.Cobblestone)
	part(decorM, "Cap", Vector3.new(4.2, 1, 4.2), foot * CFrame.new(0, h + 0.5, 0), STONE_LIGHT, Enum.Material.Slate)
	part(decorM, "Cap", Vector3.new(2.4, 2.4, 2.4), foot * CFrame.new(0, h + 1.4, 0) * CFrame.Angles(0, math.rad(45), 0) * CFrame.Angles(math.rad(45), 0, 0),
		STONE_LIGHT, Enum.Material.Slate)
	part(decorM, "Moss", Vector3.new(4.3, 0.3, 4.3), foot * CFrame.new(0, h + 1.05, 0), MOSS, Enum.Material.Grass)
	local armStart = foot * CFrame.new(0, h - 2.5, -1.7)
	part(decorM, "Arm", Vector3.new(0.25, 0.25, 2.6), armStart * CFrame.new(0, 0, -1.3), IRON_DARK, Enum.Material.CorrodedMetal)
	local lampCf = armStart * CFrame.new(0, -1.1, -2.4)
	local lantern = group(decorM, "Lantern", lampCf)
	lantern:SetAttribute("Drop", lampCf.Position.Y - foot.Position.Y)
	part(lantern, "Chain", Vector3.new(0.12, 0.8, 0.12), lampCf * CFrame.new(0, 0.95, 0), IRON_DARK, Enum.Material.CorrodedMetal)
	part(lantern, "Cage", Vector3.new(1.1, 0.25, 1.1), lampCf * CFrame.new(0, 0.6, 0), IRON_DARK, Enum.Material.CorrodedMetal)
	part(lantern, "Cage", Vector3.new(1.1, 0.25, 1.1), lampCf * CFrame.new(0, -0.6, 0), IRON_DARK, Enum.Material.CorrodedMetal)
	local glow = part(lantern, "LanternGlow", Vector3.new(0.7, 1, 0.7), lampCf, LAMP, Enum.Material.Neon)
	light(glow, LAMP, 14, 1.4)
end
pillar(-INNER - math.rad(2), 4)
pillar(INNER + math.rad(2), 4)
pillar(-MAX_ANGLE, 3)
pillar(MAX_ANGLE, 3)

-- ============================================================
-- Wing decoration: crooked tombstones, roots through the stone, a dead tree near each end
-- ============================================================
local function tombstone(a, ahead)
	local foot = arcFrame(a) * CFrame.new(rng:NextNumber(-1, 1), 0, -ahead)
	local tilt = CFrame.Angles(math.rad(rng:NextNumber(-14, 10)), math.rad(rng:NextNumber(-20, 20)), math.rad(rng:NextNumber(-12, 12)))
	local hgt = rng:NextNumber(2.4, 3.4)
	local cf = foot * tilt * CFrame.new(0, hgt / 2 - 0.3, 0)
	local grave = group(decorM, "Grave", foot * tilt)
	part(grave, "Tombstone", Vector3.new(2, hgt, 0.6), cf, GRAVE, Enum.Material.Slate)
	part(grave, "Tombstone", Vector3.new(0.6, 2, 2), cf * CFrame.new(0, hgt / 2, 0) * CFrame.Angles(0, math.rad(90), 0), GRAVE, Enum.Material.Slate, Enum.PartType.Cylinder)
	part(grave, "Moss", Vector3.new(2.1, 0.5, 0.7), cf * CFrame.new(0, -hgt / 2 + 0.6, 0), MOSS_DARK, Enum.Material.Grass)
end
for _, side in ipairs({ -1, 1 }) do
	tombstone(side * math.rad(28), 3.6)
	tombstone(side * math.rad(38), 5.5)
	tombstone(side * math.rad(47), 2.8)
	for k = 1, 2 do
		local a = side * math.rad(rng:NextNumber(24, 46))
		local foot = arcFrame(a)
		local t = thicknessAt(a)
		local p0 = (foot * CFrame.new(rng:NextNumber(-2, 2), heightAt(a) - 1, -t / 2 - 0.1)).Position
		local p1 = (foot * CFrame.new(rng:NextNumber(-3, 3), 0.3, -t / 2 - 1.2)).Position
		rod(decorM, "Root", p0, p1, 0.45 - k * 0.08, ROOT)
	end
	local treeFoot = (arcFrame(side * math.rad(44)) * CFrame.new(side * 1.5, 0, -6)).Position
	local trunkTop = treeFoot + Vector3.new(side * 0.8, 12, 0.5)
	rod(decorM, "Trunk", treeFoot, trunkTop, 1.2, WOOD)
	for b = 1, 4 do
		local from = treeFoot:Lerp(trunkTop, 0.45 + b * 0.12)
		local dir = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(0.4, 0.9), rng:NextNumber(-1, 1)).Unit
		rod(decorM, "Branch", from, from + dir * rng:NextNumber(2.5, 4.5), 0.42 - b * 0.05, WOOD)
	end
end

-- ============================================================
-- Ground: the earth bank (as the cemetery wall's; deeper in the middle under the mausoleum, the steps and the braziers)
-- ============================================================
do
	local BANK_TOP = -0.3
	local GROUND_ANGLE = MAX_ANGLE + math.rad(14)
	local n = 20
	local gStep = 2 * GROUND_ANGLE / n
	local gChord = 2 * R * math.sin(gStep / 2)
	for i = 0, n - 1 do
		local a = -GROUND_ANGLE + (i + 0.5) * gStep
		local f = math.abs(a) / GROUND_ANGLE
		local middle = math.abs(a) < math.rad(20)
		local front = (middle and 10 or 5 + 5 * math.min(1, f * 1.3)) + rng:NextNumber(-1, 1.5)
		local back = (middle and 13 or 4) + rng:NextNumber(-0.5, 1.5)
		local foot = arcFrame(a)
		local mid = foot * CFrame.new(0, 0, -(front - back) / 2)
		local top = part(groundM, "Bank", Vector3.new(gChord + 1.2, 4, front + back), mid * CFrame.new(0, BANK_TOP - 2, 0)
			* CFrame.Angles(0, math.rad(rng:NextNumber(-4, 4)), 0), DIRT, Enum.Material.Ground)
		top.CanCollide = true
		local ledge = part(groundM, "Ledge", Vector3.new(gChord + 2, 3, front + back + 3 + rng:NextNumber(0, 2)),
			mid * CFrame.new(0, -1.1 - 1.5, rng:NextNumber(-0.5, 0.5)) * CFrame.Angles(0, math.rad(rng:NextNumber(-6, 6)), 0), DIRT_DARK, Enum.Material.Ground)
		ledge.CanCollide = true
		for _, edge in ipairs({ -front, back }) do
			if rng:NextNumber() < 0.7 then
				local rs = rng:NextNumber(1.6, 3.2)
				part(groundM, "Rock", Vector3.new(rs * 1.3, rs * 0.8, rs), foot * CFrame.new(rng:NextNumber(-1.5, 1.5), -0.3, edge + (edge < 0 and 0.6 or -0.6))
					* CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, 6), rng:NextNumber(-0.3, 0.3)), ROCK, Enum.Material.Slate)
			end
		end
		if rng:NextNumber() < 0.5 then
			part(groundM, "Moss", Vector3.new(gChord * rng:NextNumber(0.5, 1), 0.2, rng:NextNumber(2, 4)),
				foot * CFrame.new(0, BANK_TOP + 0.08, -front + 2), MOSS_DARK, Enum.Material.Grass)
		end
	end
end

-- ============================================================
-- Rubble beyond the wing ends
-- ============================================================
for _, side in ipairs({ -1, 1 }) do
	for k = 1, 5 do
		local a = side * (MAX_ANGLE + math.rad(2 + k * 2.6))
		local s = 2.6 - k * 0.3
		part(decorM, "Rubble", Vector3.new(s * rng:NextNumber(0.9, 1.4), s * 0.7, s), arcFrame(a, s * 0.3)
			* CFrame.new(0, 0, rng:NextNumber(-1.5, 1.5)) * CFrame.Angles(rng:NextNumber(-0.4, 0.4), rng:NextNumber(0, 6), rng:NextNumber(-0.4, 0.4)),
			STONE[rng:NextInteger(1, #STONE)], Enum.Material.Slate)
	end
end

base.PivotOffset = CFrame.new()
local parts = 0
for _, d in ipairs(model:GetDescendants()) do
	if d:IsA("BasePart") then
		parts += 1
	end
end
model:SetAttribute("Parts", parts) -- the client waits until all of them have replicated (Modules/WallStages)
model:SetAttribute("Realm", 1)
model:SetAttribute("SoulColor", SOUL)
model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
model.Parent = folder

return "Cemetery gate: " .. parts .. " parts"
