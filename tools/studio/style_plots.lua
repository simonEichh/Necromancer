-- Restyles the 8 plots (gothic stone look). Safe to re-run. Run in Studio's command bar / via the Studio MCP
-- execute_luau (Edit mode), after tools/studio/build_coliseum.lua has placed the plots.
--
-- Everything is built relative to each plot's frame (floor-level centre of the Base, local -Z = lane direction,
-- outward). Decoration goes into a "Style" folder inside each Plot model, so the server's named lookups
-- (Base, WallOrigin, PlayerSpawn, GraveSpotN) are unaffected.
-- The lane floor, lane side walls and wall tints are created at runtime by src/server/Modules/Walls.lua.
local STONE_DARK = Color3.fromRGB(58, 60, 72)
local STONE = Color3.fromRGB(88, 91, 106)
local STONE_LIGHT = Color3.fromRGB(122, 126, 142)
local BASE_COLOR = Color3.fromRGB(84, 88, 106)
local GRASS = Color3.fromRGB(52, 80, 58)
local MUD = Color3.fromRGB(70, 56, 48)
local GLOW = Color3.fromRGB(120, 255, 190)

local UP = CFrame.Angles(0, 0, math.rad(90)) -- turns a cylinder's axis (X) to point up

for i = 1, 8 do
	local model = workspace.Plots["Plot" .. i]
	local old = model:FindFirstChild("Style")
	if old then old:Destroy() end
	local style = Instance.new("Folder")
	style.Name = "Style"
	style.Parent = model

	local base = model.Base
	base.Material = Enum.Material.Cobblestone
	base.Color = BASE_COLOR
	local frame = base.CFrame * CFrame.new(0, base.Size.Y / 2, 0)

	-- CFrame at (forward along the lane, lateral across, height above the floor), facing down the lane
	local function at(forward, lateral, y)
		return frame * CFrame.new(lateral, y, -forward)
	end

	local function part(name, size, cframe, color, material, shape)
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.Size = size
		p.CFrame = cframe
		p.Color = color
		p.Material = material or Enum.Material.Slate
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		if shape then p.Shape = shape end
		p.Parent = style
		return p
	end
	local function flatDisc(name, radius, thickness, forward, y, color, material)
		return part(name, Vector3.new(thickness, radius * 2, radius * 2), at(forward, 0, y) * UP, color, material, Enum.PartType.Cylinder)
	end

	-- low stone walls along both sides (the lane continues them at runtime), with a lighter cap
	for _, side in ipairs({ -1, 1 }) do
		part("SideWall", Vector3.new(0.8, 1.4, base.Size.Z), at(0, side * (base.Size.X / 2 + 0.4), 0.7), STONE, Enum.Material.Cobblestone)
		part("SideWallCap", Vector3.new(1.1, 0.25, base.Size.Z), at(0, side * (base.Size.X / 2 + 0.4), 1.52), STONE_LIGHT)
	end

	-- graveyard: a muddy border with a patch of grass under the tombstones
	part("GraveMud", Vector3.new(38, 0.1, 18), at(-15, 0, 0.05), MUD, Enum.Material.Mud)
	part("GraveGrass", Vector3.new(35, 0.1, 15.5), at(-15, 0, 0.1), GRASS, Enum.Material.Grass)

	-- spawn pad: a glowing ring and a three-bar rune
	flatDisc("SpawnRing", 5.6, 0.1, 8, 0.06, GLOW, Enum.Material.Neon)
	flatDisc("SpawnDisc", 5.2, 0.12, 8, 0.07, STONE_DARK, Enum.Material.Slate)
	for k = 0, 2 do
		part("SpawnRune", Vector3.new(9, 0.05, 0.3), at(8, 0, 0.14) * CFrame.Angles(0, math.rad(60 * k), 0), GLOW, Enum.Material.Neon)
	end

	-- entrance arch where the plot meets the plaza, with the plot number facing the plaza
	for _, side in ipairs({ -1, 1 }) do
		part("ArchPillar", Vector3.new(1.6, 6, 1.6), at(-23.2, side * 9.6, 3), STONE, Enum.Material.Cobblestone)
		part("ArchPillarCap", Vector3.new(2.1, 0.4, 2.1), at(-23.2, side * 9.6, 6.2), STONE_LIGHT)
	end
	part("ArchLintel", Vector3.new(21, 1, 1.6), at(-23.2, 0, 6.9), STONE, Enum.Material.Cobblestone)
	part("ArchGlow", Vector3.new(19, 0.15, 0.2), at(-23.2, 0, 6.3), GLOW, Enum.Material.Neon)
	local sign = part("ArchSign", Vector3.new(6, 1.5, 0.3), at(-23.2, 0, 8.3), STONE_DARK)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back -- the side facing the plaza (local +Z)
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 60
	gui.Parent = sign
	local text = Instance.new("TextLabel")
	text.Size = UDim2.new(1, 0, 1, 0)
	text.BackgroundTransparency = 1
	text.Text = "PLOT " .. i
	text.TextColor3 = GLOW
	text.TextScaled = true
	text.Font = Enum.Font.GothamBlack
	text.Parent = gui
	-- readable from the lane side too
	local front = gui:Clone()
	front.Face = Enum.NormalId.Front
	front.Parent = sign
end

return "plots restyled"
