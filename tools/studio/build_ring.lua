-- Builds the outer fortress ring around the whole arena (Workspace.OuterWall). Safe to re-run.
-- Run in Studio's command bar / via the Studio MCP execute_luau (Edit mode).
--
-- Geometry: centred on the plaza (origin). The lanes end at radius 392 (see Walls.lua: groundLen) where each
-- lane meets a gate tower with a glowing emblem and the plot number; a wall ring (inner radius 392, 12 thick)
-- joins the 8 gate towers, with 8 round mid-towers between them.
local floorTop = -1.7
local R_IN = 392              -- inner face of the ring (lane ends here)
local THICK = 12
local R_MID = R_IN + THICK / 2
local WALL_TOP = floorTop + 70
local BOTTOM = -12            -- foundation sinks below the water
local SEG_DEG = 5

local STONE_DARK = Color3.fromRGB(58, 60, 72)
local WALL = Color3.fromRGB(108, 112, 138)
local STONE_LIGHT = Color3.fromRGB(150, 152, 176)
local GLOW = Color3.fromRGB(120, 255, 190)
local FIRE = Color3.fromRGB(255, 170, 90)
local DOOR = Color3.fromRGB(30, 28, 38)

local old = workspace:FindFirstChild("OuterWall")
if old then old:Destroy() end
local ring = Instance.new("Folder")
ring.Name = "OuterWall"

local function dirAt(deg)
	local a = math.rad(deg)
	return Vector3.new(math.sin(a), 0, -math.cos(a))
end

local function part(parent, name, size, cframe, color, material, shape)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or Enum.Material.Cobblestone
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if shape then p.Shape = shape end
	p.Parent = parent
	return p
end

-- CFrame at radius r, compass angle deg, height y, facing the centre (LookVector = inward,
-- RightVector = tangent, so part X = along the wall, Z = radial thickness)
local function onRing(r, deg, y)
	local pos = dirAt(deg) * r
	return CFrame.lookAt(Vector3.new(pos.X, y, pos.Z), Vector3.new(0, y, 0))
end

local UP = CFrame.Angles(0, 0, math.rad(90)) -- cylinder axis X -> Y

-- ── Wall segments ─────────────────────────────────────────────
local segLen = 2 * R_MID * math.tan(math.rad(SEG_DEG / 2)) + 0.8
local wallHeight = WALL_TOP - BOTTOM
local wallMidY = (WALL_TOP + BOTTOM) / 2
for k = 0, 360 / SEG_DEG - 1 do
	local deg = k * SEG_DEG
	local walls = Instance.new("Folder")
	walls.Name = "Segment"
	walls.Parent = ring

	part(walls, "Wall", Vector3.new(segLen, wallHeight, THICK), onRing(R_MID, deg, wallMidY), WALL)
	part(walls, "Plinth", Vector3.new(segLen + 0.4, 9, THICK + 2.4), onRing(R_MID, deg, floorTop + 3), STONE_DARK)
	part(walls, "Cornice", Vector3.new(segLen + 0.4, 2, THICK + 3), onRing(R_MID, deg, WALL_TOP + 1), STONE_LIGHT, Enum.Material.Slate)
	local battlement = onRing(R_MID, deg, WALL_TOP + 2 + 2.5)
	for _, off in ipairs({ -11, 0, 11 }) do
		part(walls, "Merlon", Vector3.new(7, 5, 4), battlement * CFrame.new(off, 0, 0), WALL)
	end
	-- vertical pilaster on the inner face at the boundary with the next segment
	part(walls, "Pilaster", Vector3.new(3, WALL_TOP - floorTop, 1.6), onRing(R_IN - 0.6, deg + SEG_DEG / 2, (WALL_TOP + floorTop) / 2), STONE_LIGHT, Enum.Material.Slate)
end

-- ── Brazier on top of a tower: stone bowl + glowing fire + light ──
local function brazier(parent, centre, y)
	local bowl = part(parent, "BrazierBowl", Vector3.new(2, 7, 7), CFrame.new(centre.X, y + 1, centre.Z) * UP, STONE_DARK)
	bowl.Shape = Enum.PartType.Cylinder
	local fire = part(parent, "Fire", Vector3.new(4.5, 4.5, 4.5), CFrame.new(centre.X, y + 4.5, centre.Z), FIRE, Enum.Material.Neon, Enum.PartType.Ball)
	local light = Instance.new("PointLight")
	light.Color = FIRE
	light.Range = 90
	light.Brightness = 1.4
	light.Shadows = false
	light.Parent = fire
end

-- ── Gate towers at every lane axis ────────────────────────────
local TOWER_H = 125
local TOWER_TOP = floorTop + TOWER_H
local R_TOWER = R_IN + 13 -- tower inner face sits exactly at the end of the lane
for i = 1, 8 do
	local deg = (i - 1) * 45
	local tower = Instance.new("Folder")
	tower.Name = "GateTower" .. i
	tower.Parent = ring
	local base = onRing(R_TOWER, deg, (TOWER_TOP + BOTTOM) / 2)
	part(tower, "Body", Vector3.new(26, TOWER_TOP - BOTTOM, 26), base, WALL)
	part(tower, "Plinth", Vector3.new(29, 10, 29), onRing(R_TOWER, deg, floorTop + 3.3), STONE_DARK)
	part(tower, "Cornice", Vector3.new(31, 3, 31), onRing(R_TOWER, deg, TOWER_TOP + 1.5), STONE_LIGHT, Enum.Material.Slate)
	-- battlements around the top
	local top = onRing(R_TOWER, deg, TOWER_TOP + 3 + 3)
	for _, off in ipairs({ -10, -3.3, 3.3, 10 }) do
		part(tower, "Merlon", Vector3.new(5, 6, 4), top * CFrame.new(off, 0, 13.2), WALL)  -- outer side
		part(tower, "Merlon", Vector3.new(5, 6, 4), top * CFrame.new(off, 0, -13.2), WALL) -- inner side
		part(tower, "Merlon", Vector3.new(4, 6, 5), top * CFrame.new(13.2, 0, off), WALL)
		part(tower, "Merlon", Vector3.new(4, 6, 5), top * CFrame.new(-13.2, 0, off), WALL)
	end
	local topCentre = dirAt(deg) * R_TOWER
	brazier(tower, topCentre, TOWER_TOP + 3)

	-- sealed gate where the lane ends (inner face is local -Z, at radius R_IN)
	local faceZ = -13.2 -- just in front of the inner face
	local gateBase = onRing(R_TOWER, deg, floorTop) -- floor level, centred on the lane
	part(tower, "GateFrame", Vector3.new(16, 22, 1.6), gateBase * CFrame.new(0, 11, faceZ), STONE_LIGHT, Enum.Material.Slate)
	part(tower, "GateDoor", Vector3.new(11, 18, 1.2), gateBase * CFrame.new(0, 9, faceZ - 0.7), DOOR, Enum.Material.Slate)
	part(tower, "GateGlow", Vector3.new(11, 0.4, 0.4), gateBase * CFrame.new(0, 18.3, faceZ - 1.4), GLOW, Enum.Material.Neon)

	-- glowing emblem high on the face: ring + cross + plot number
	local emblem = onRing(R_TOWER, deg, floorTop + 62) * CFrame.new(0, 0, faceZ - 0.3)
	local faceTurn = CFrame.Angles(0, math.rad(90), 0) -- cylinder axis X -> local Z (towards the lane)
	part(tower, "EmblemRing", Vector3.new(0.6, 22, 22), emblem * faceTurn, GLOW, Enum.Material.Neon, Enum.PartType.Cylinder)
	part(tower, "EmblemDisc", Vector3.new(0.8, 19.6, 19.6), emblem * CFrame.new(0, 0, -0.1) * faceTurn, STONE_DARK, Enum.Material.Slate, Enum.PartType.Cylinder)
	for k = 0, 2 do
		part(tower, "EmblemBar", Vector3.new(18, 0.5, 0.5), emblem * CFrame.new(0, 0, -0.5) * CFrame.Angles(0, 0, math.rad(60 * k)), GLOW, Enum.Material.Neon)
	end
	local sign = part(tower, "PlotSign", Vector3.new(16, 5, 0.8), onRing(R_TOWER, deg, floorTop + 40) * CFrame.new(0, 0, faceZ - 0.4), STONE_DARK, Enum.Material.Slate)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front -- local -Z, the side facing the lane
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.Parent = sign
	local text = Instance.new("TextLabel")
	text.Size = UDim2.new(1, 0, 1, 0)
	text.BackgroundTransparency = 1
	text.Text = "PLOT " .. i
	text.TextColor3 = GLOW
	text.TextScaled = true
	text.Font = Enum.Font.GothamBlack
	text.Parent = gui
end

-- ── Round mid-towers between the gate towers ──────────────────
-- Off since the realm titans (tools/studio/build_titan_gravekeeper.lua): a titan's arm lies along the battlements and
-- would reach into the tower beside its lane.
local MID_TOWERS = false
local MID_H = 100
local MID_TOP = floorTop + MID_H
for i = 0, MID_TOWERS and 7 or -1 do
	local deg = i * 45 + 22.5
	local tower = Instance.new("Folder")
	tower.Name = "MidTower" .. (i + 1)
	tower.Parent = ring
	local pos = dirAt(deg) * R_MID
	part(tower, "Body", Vector3.new(MID_TOP - BOTTOM, 20, 20), CFrame.new(pos.X, (MID_TOP + BOTTOM) / 2, pos.Z) * UP, WALL, Enum.Material.Cobblestone, Enum.PartType.Cylinder)
	part(tower, "Plinth", Vector3.new(10, 23, 23), CFrame.new(pos.X, floorTop + 3, pos.Z) * UP, STONE_DARK, Enum.Material.Cobblestone, Enum.PartType.Cylinder)
	part(tower, "Cap", Vector3.new(3, 24, 24), CFrame.new(pos.X, MID_TOP + 1.5, pos.Z) * UP, STONE_LIGHT, Enum.Material.Slate, Enum.PartType.Cylinder)
	brazier(tower, pos, MID_TOP + 3)
end

-- ── Wall sconces: warm lights along the inner face so the ring is readable from the lanes ──
local sconces = Instance.new("Folder")
sconces.Name = "Sconces"
sconces.Parent = ring
for k = 0, 23 do
	local deg = k * 15 + 7.5 -- between the towers (towers sit at multiples of 22.5)
	if deg % 22.5 ~= 0 then
		local cf = onRing(R_IN - 1.2, deg, floorTop + 14)
		part(sconces, "SconceBracket", Vector3.new(1.4, 0.5, 1.8), cf, STONE_DARK, Enum.Material.Slate)
		local flame = part(sconces, "SconceFlame", Vector3.new(1.1, 1.6, 1.1), cf * CFrame.new(0, 1.1, 0), FIRE, Enum.Material.Neon)
		local light = Instance.new("PointLight")
		light.Color = FIRE
		light.Range = 55
		light.Brightness = 1.2
		light.Shadows = false
		light.Parent = flame
	end
end

ring.Parent = workspace
return "outer wall built: " .. #ring:GetDescendants() .. " instances"
