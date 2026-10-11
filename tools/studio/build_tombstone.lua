-- Builds the low-poly Tombstone into ServerStorage.Models.Tombstone.
-- Run in Studio's command bar / via the Studio MCP execute_luau (Edit mode).
-- The old model is kept as Tombstone_Old until the new one is approved.
--
-- Conventions: origin = centre of a thin base plate (PrimaryPart) whose bottom sits on the floor,
-- front faces +X (towards the hub), footprint 6 x 5.7 so it fits the grave grid (7 stud rows, 8 stud columns).
local ServerStorage = game:GetService("ServerStorage")
local models = ServerStorage.Models

local old = models:FindFirstChild("Tombstone")
if old and old.Name == "Tombstone" then
	old.Name = "Tombstone_Old"
end

local STONE_DARK = Color3.fromRGB(58, 60, 72)
local STONE = Color3.fromRGB(88, 91, 106)
local STONE_LIGHT = Color3.fromRGB(122, 126, 142)
local MOSS = Color3.fromRGB(64, 98, 72)
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

local base = part("Base", Vector3.new(6, 0.2, 5.7), Vector3.new(0, 0, 0), STONE_DARK, Enum.Material.Cobblestone)
model.PrimaryPart = base

-- Plinth + headstone (arched top; the cylinder axis is X = the slab thickness direction)
part("Plinth", Vector3.new(2.0, 0.5, 3.6), Vector3.new(-0.6, 0.35, 0), STONE_DARK)
part("Headstone", Vector3.new(1.0, 3.4, 2.6), Vector3.new(-0.6, 2.3, 0), STONE)
part("Arch", Vector3.new(1.0, 2.6, 2.6), Vector3.new(-0.6, 4.0, 0), STONE, Enum.Material.Slate, Enum.PartType.Cylinder)

-- Raised border frame on the front face
part("FrameTop", Vector3.new(0.2, 0.18, 2.1), Vector3.new(-0.05, 5.0, 0), STONE_LIGHT)
part("FrameL", Vector3.new(0.2, 2.9, 0.18), Vector3.new(-0.05, 3.55, 1.05), STONE_LIGHT)
part("FrameR", Vector3.new(0.2, 2.9, 0.18), Vector3.new(-0.05, 3.55, -1.05), STONE_LIGHT)

-- Glowing cross rune
part("CrossV", Vector3.new(0.12, 1.7, 0.28), Vector3.new(0.02, 3.9, 0), GLOW, Enum.Material.Neon)
part("CrossH", Vector3.new(0.12, 0.28, 1.0), Vector3.new(0.02, 4.2, 0), GLOW, Enum.Material.Neon)

-- Epitaph plate
part("Epitaph", Vector3.new(0.14, 0.5, 1.5), Vector3.new(-0.03, 2.55, 0), STONE_DARK)
part("EpitaphLine1", Vector3.new(0.16, 0.08, 1.0), Vector3.new(-0.02, 2.65, 0), STONE_LIGHT)
part("EpitaphLine2", Vector3.new(0.16, 0.08, 0.7), Vector3.new(-0.02, 2.45, 0), STONE_LIGHT)

-- Stepped burial mound in front (flat discs: cylinders rotated so the axis points up)
local up = CFrame.Angles(0, 0, math.rad(90))
local mound1 = part("Mound1", Vector3.new(0.5, 3.8, 4.2), Vector3.new(1.6, 0.15, 0), MOSS, Enum.Material.Grass, Enum.PartType.Cylinder)
mound1.CFrame = CFrame.new(1.6, 0.15, 0) * up
local mound2 = part("Mound2", Vector3.new(0.4, 2.6, 3.0), Vector3.new(1.6, 0.5, 0), STONE_DARK, Enum.Material.Slate, Enum.PartType.Cylinder)
mound2.CFrame = CFrame.new(1.6, 0.5, 0) * up
mound2.Color = Color3.fromRGB(76, 62, 54)
mound2.Material = Enum.Material.Mud

-- Little stone corner posts
for _, z in ipairs({ -2.1, 2.1 }) do
	part("Post", Vector3.new(0.5, 0.9, 0.5), Vector3.new(2.5, 0.35, z), STONE)
	part("PostCap", Vector3.new(0.65, 0.18, 0.65), Vector3.new(2.5, 0.88, z), STONE_LIGHT)
end

-- Moss patches
part("MossA", Vector3.new(0.5, 0.3, 1.1), Vector3.new(0.45, 0.35, -1.2), MOSS, Enum.Material.Grass)
part("MossB", Vector3.new(0.4, 0.5, 0.8), Vector3.new(-0.6, 0.45, 1.5), MOSS, Enum.Material.Grass)
part("MossC", Vector3.new(0.9, 0.2, 0.7), Vector3.new(-0.55, 5.15, -0.5), MOSS, Enum.Material.Grass)

model.Parent = models
return "Tombstone built: " .. #model:GetChildren() .. " parts"
