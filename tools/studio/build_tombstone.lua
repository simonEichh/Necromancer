-- Builds the low-poly Tombstone into ServerStorage.Models.Tombstone (replacing any existing one).
-- Run in Studio's command bar / via the Studio MCP execute_luau (Edit mode).
--
-- Conventions: origin = centre of a thin base plate (PrimaryPart) whose bottom sits on the floor,
-- front faces +X (towards the hub), footprint 6 x 5.7 so it fits the grave grid (7 stud rows, 8 stud columns).
-- Nothing may overlap or stick out of another part (no clipping).
local ServerStorage = game:GetService("ServerStorage")
local models = ServerStorage.Models

for _, name in ipairs({ "Tombstone", "Tombstone_Old" }) do
	local existing = models:FindFirstChild(name)
	if existing then
		existing:Destroy()
	end
end

local STONE_DARK = Color3.fromRGB(58, 60, 72)
local STONE = Color3.fromRGB(88, 91, 106)
local STONE_LIGHT = Color3.fromRGB(122, 126, 142)
local MOSS = Color3.fromRGB(64, 98, 72)
local MUD = Color3.fromRGB(76, 62, 54)
local GLOW = Color3.fromRGB(120, 255, 190)

local model = Instance.new("Model")
model.Name = "Tombstone"

local function part(name, size, offset, color, material, shape)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.Slate
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if shape then
		p.Shape = shape
	end
	p.CFrame = CFrame.new(offset)
	p.Parent = model
	return p
end

-- A flat disc: a cylinder rotated so its axis points up
local UP = CFrame.Angles(0, 0, math.rad(90))
local function disc(name, diameter, thickness, centre, color, material)
	local p = part(name, Vector3.new(thickness, diameter, diameter), centre, color, material, Enum.PartType.Cylinder)
	p.CFrame = CFrame.new(centre) * UP
	return p
end

-- Base plate (top surface at y = 0.1)
local base = part("Base", Vector3.new(6, 0.2, 5.7), Vector3.new(0, 0, 0), STONE_DARK, Enum.Material.Cobblestone)
model.PrimaryPart = base

-- Plinth (y 0.1 .. 0.6) and the headstone rim: a slab with a round top (cylinder axis = X = slab thickness).
-- Slab front face is at x = -0.1; slab spans y 0.6 .. 4.0, the arch is centred at y = 4.0 with radius 1.3.
part("Plinth", Vector3.new(2.0, 0.5, 3.6), Vector3.new(-0.6, 0.35, 0), STONE_DARK)
part("Headstone", Vector3.new(1.0, 3.4, 2.6), Vector3.new(-0.6, 2.3, 0), STONE_LIGHT)
part("Arch", Vector3.new(1.0, 2.6, 2.6), Vector3.new(-0.6, 4.0, 0), STONE_LIGHT, Enum.Material.Slate, Enum.PartType.Cylinder)

-- Raised inner panel with the same round top, leaving an even rim of lighter stone all around
-- (panel spans y 0.9 .. 3.9 as a block, then a round top of radius 1.0 centred at y = 3.9)
part("Panel", Vector3.new(0.12, 3.0, 2.0), Vector3.new(-0.04, 2.4, 0), STONE)
part("PanelArch", Vector3.new(0.12, 2.0, 2.0), Vector3.new(-0.04, 3.9, 0), STONE, Enum.Material.Slate, Enum.PartType.Cylinder)

-- Glowing cross rune (sits on the panel front face at x = 0.02)
part("CrossV", Vector3.new(0.12, 1.5, 0.26), Vector3.new(0.08, 3.65, 0), GLOW, Enum.Material.Neon)
part("CrossH", Vector3.new(0.12, 0.26, 0.9), Vector3.new(0.08, 3.95, 0), GLOW, Enum.Material.Neon)

-- Epitaph plate and lines
part("Epitaph", Vector3.new(0.1, 0.5, 1.4), Vector3.new(0.07, 2.2, 0), STONE_DARK)
part("EpitaphLine1", Vector3.new(0.1, 0.08, 0.9), Vector3.new(0.12, 2.3, 0), STONE_LIGHT)
part("EpitaphLine2", Vector3.new(0.1, 0.08, 0.6), Vector3.new(0.12, 2.1, 0), STONE_LIGHT)

-- Stepped burial mound in front of the plinth, fully inside the base plate (x 0.5 .. 2.9)
disc("Mound1", 2.4, 0.4, Vector3.new(1.7, 0.3, 0), MOSS, Enum.Material.Grass)
disc("Mound2", 1.6, 0.3, Vector3.new(1.7, 0.65, 0), MUD, Enum.Material.Mud)

-- Little stone corner posts
for _, z in ipairs({ -2.1, 2.1 }) do
	part("Post", Vector3.new(0.5, 0.9, 0.5), Vector3.new(2.5, 0.35, z), STONE)
	part("PostCap", Vector3.new(0.65, 0.18, 0.65), Vector3.new(2.5, 0.88, z), STONE_LIGHT)
end

-- Moss: flat patches lying on the free corners of the base plate (nothing else occupies x < -1.7)
for _, z in ipairs({ -1.9, 1.9 }) do
	disc("MossPatch", 0.9, 0.12, Vector3.new(-2.3, 0.16, z), MOSS, Enum.Material.Grass)
end

model.Parent = models
return "Tombstone built: " .. #model:GetChildren() .. " parts"
