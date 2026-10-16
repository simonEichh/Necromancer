-- Builds the outer fortress ring around the whole arena (Workspace.OuterWall). Safe to re-run.
-- Run in Studio's command bar / via the Studio MCP execute_luau (Edit mode).
--
-- Geometry: centred on the plaza (origin). The lanes end at radius 392 (see Walls.lua: groundLen) where each
-- lane meets a gate tower with a glowing emblem and the plot number; a wall ring (inner radius 392, 12 thick)
-- joins the 8 gate towers.
-- Look (2026-10-15, the neutral "dark fortress stone"): dark basalt, buttresses every 10 degrees with arrow slits
-- between them, spiked battlements, and a massive seam pillar with a spire halfway between two lanes. The wall is
-- grouped in 8 sections (OuterWall.Section<i>: the 45 degrees behind plot i, its gate tower in the middle), so a
-- realm can later swap in its own section (PlotLook); the seam pillars (OuterWall.Seams) hide the joints.
local floorTop = -1.7
local R_IN = 392              -- inner face of the ring (lane ends here)
local THICK = 12
local R_MID = R_IN + THICK / 2
local WALL_TOP = floorTop + 70
local BOTTOM = -12            -- foundation sinks below the water
local SEG_DEG = 5

local STONE_DARK = Color3.fromRGB(38, 36, 44)
local WALL = Color3.fromRGB(68, 65, 76)
local STONE_LIGHT = Color3.fromRGB(104, 98, 110)
local IRON = Color3.fromRGB(28, 26, 30)
local GLOW = Color3.fromRGB(150, 110, 240) -- (soul violet, like the plaza)
local FIRE = Color3.fromRGB(255, 170, 90)
local SOUL_FLAME = Color3.fromRGB(170, 255, 200) -- (the plaza's lantern flames)
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
	p.Material = material or Enum.Material.Slate -- (Basalt read brown under the warm lights)
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

-- ── A gothic rose window: violet glass behind stone tracery (a ring, 8 spokes, an inner ring, a boss) ──
-- cf: the centre on the face it sits on, its -Z looking out; everything stands in front of that face
local GLASS = Color3.fromRGB(84, 40, 112) -- (bluer values came out bright blue under the bloom)
local function roseWindow(parent, cf, d)
	local r = d / 2
	local turn = CFrame.Angles(0, math.rad(90), 0) -- (cylinder axis X -> local Z)
	part(parent, "RoseGlass", Vector3.new(0.3, d - 0.4, d - 0.4), cf * CFrame.new(0, 0, -0.2) * turn, GLASS, Enum.Material.Neon, Enum.PartType.Cylinder)
	local function ring(name, radius, n, w, depth, z)
		for k = 0, n - 1 do
			local a0, a1 = k / n * math.pi * 2, (k + 1) / n * math.pi * 2
			local p0 = Vector3.new(math.cos(a0) * radius, math.sin(a0) * radius, 0)
			local p1 = Vector3.new(math.cos(a1) * radius, math.sin(a1) * radius, 0)
			local mid = (p0 + p1) / 2
			local along = (p1 - p0)
			part(parent, name, Vector3.new(along.Magnitude + w * 0.5, w, depth), cf * CFrame.new(mid.X, mid.Y, z) * CFrame.Angles(0, 0, math.atan2(along.Y, along.X)), STONE_LIGHT, Enum.Material.Slate)
		end
	end
	ring("RoseRing", r - 0.5, 16, 1.4, 1.2, -0.75)
	ring("RoseInner", r * 0.32, 8, 0.6, 0.8, -0.55)
	for k = 0, 7 do
		local a = k / 8 * math.pi * 2
		local mid = (r * 0.32 + r - 0.5) / 2
		part(parent, "RoseSpoke", Vector3.new((r - 0.5) - r * 0.32, 0.55, 0.7), cf * CFrame.new(math.cos(a) * mid, math.sin(a) * mid, -0.5) * CFrame.Angles(0, 0, a), STONE_LIGHT, Enum.Material.Slate)
	end
	part(parent, "RoseBoss", Vector3.new(1.2, d * 0.14, d * 0.14), cf * CFrame.new(0, 0, -0.8) * turn, STONE_LIGHT, Enum.Material.Slate, Enum.PartType.Cylinder)
	local light = Instance.new("SurfaceLight")
	light.Face = Enum.NormalId.Right -- (the glass cylinder's +X looks out of the face)
	light.Color = GLOW
	light.Range = d * 0.8
	light.Brightness = 0.6
	light.Parent = parent:FindFirstChild("RoseGlass")
end

-- ── Wall segments, grouped in 8 sections ──────────────────────
local sections = {}
for i = 1, 8 do
	local f = Instance.new("Folder")
	f.Name = "Section" .. i
	f:SetAttribute("PlotIndex", i)
	f.Parent = ring
	sections[i] = f
end
local segLen = 2 * R_MID * math.tan(math.rad(SEG_DEG / 2)) + 0.8
local wallHeight = WALL_TOP - BOTTOM
local wallMidY = (WALL_TOP + BOTTOM) / 2
local innerH = WALL_TOP - floorTop
for k = 0, 360 / SEG_DEG - 1 do
	local deg = k * SEG_DEG
	local walls = Instance.new("Folder")
	walls.Name = "Segment"
	walls.Parent = sections[math.floor((deg + 22.5) / 45) % 8 + 1] -- (section i: the 45 degrees round plot i's lane)

	part(walls, "Wall", Vector3.new(segLen, wallHeight, THICK), onRing(R_MID, deg, wallMidY), WALL)
	part(walls, "Plinth", Vector3.new(segLen + 0.4, 9, THICK + 2.4), onRing(R_MID, deg, floorTop + 3), STONE_DARK)
	part(walls, "Cornice", Vector3.new(segLen + 0.4, 2, THICK + 3), onRing(R_MID, deg, WALL_TOP + 1), STONE_LIGHT, Enum.Material.Slate)
	local behindTower = deg % 45 == 0 -- (the gate tower stands in front of this stretch: no decorations through it)
	-- a string course a third of the way up the inner face
	if not behindTower then part(walls, "Course", Vector3.new(segLen + 0.2, 1.4, 1.2), onRing(R_IN - 0.4, deg, floorTop + innerH * 0.36), STONE_LIGHT, Enum.Material.Slate) end
	-- spiked battlements: tall merlons, an iron spike on each
	local battlement = onRing(R_MID, deg, WALL_TOP + 2 + 3)
	for _, off in ipairs({ -11, 0, 11 }) do
		part(walls, "Merlon", Vector3.new(6, 6, 4), battlement * CFrame.new(off, 0, -THICK / 2 + 2.5), WALL)
		part(walls, "MerlonSpike", Vector3.new(0.6, 3.2, 0.6), battlement * CFrame.new(off, 4.6, -THICK / 2 + 2.5), IRON, Enum.Material.Metal)
	end
	if k % 2 == 0 then
		-- a deep buttress on the inner face (every 10 degrees), stepped back near the top
		local b = deg + SEG_DEG / 2
		part(walls, "Buttress", Vector3.new(4.5, innerH - 8, 4), onRing(R_IN - 2, b, floorTop + (innerH - 8) / 2), WALL)
		part(walls, "ButtressStep", Vector3.new(3.6, 8, 2.4), onRing(R_IN - 1.2, b, WALL_TOP - 4), WALL)
		part(walls, "ButtressCap", Vector3.new(5.2, 1, 4.6), onRing(R_IN - 2, b, floorTop + innerH - 7.5), STONE_LIGHT, Enum.Material.Slate)
	elseif not behindTower then
		-- a tall dark arrow slit between two buttresses
		part(walls, "ArrowSlit", Vector3.new(1.4, 9, 0.4), onRing(R_IN - 0.15, deg, floorTop + innerH * 0.62), STONE_DARK, Enum.Material.SmoothPlastic)
	end
end

-- ── The seams: a massive pillar with a spire halfway between two lanes ──
local seams = Instance.new("Folder")
seams.Name = "Seams"
seams.Parent = ring
local SEAM_TOP = WALL_TOP + 16
for i = 0, 7 do
	local deg = i * 45 + 22.5
	local f = Instance.new("Folder")
	f.Name = "Seam" .. (i + 1)
	f.Parent = seams
	local r = R_MID - 3 -- (it stands out of the inner face)
	part(f, "Pillar", Vector3.new(12, SEAM_TOP - BOTTOM, THICK + 10), onRing(r, deg, (SEAM_TOP + BOTTOM) / 2), WALL)
	part(f, "PillarPlinth", Vector3.new(14, 12, THICK + 12), onRing(r, deg, floorTop + 4), STONE_DARK)
	part(f, "PillarBand", Vector3.new(13, 1.6, THICK + 11), onRing(r, deg, floorTop + innerH * 0.36), STONE_LIGHT, Enum.Material.Slate)
	part(f, "PillarCornice", Vector3.new(14, 2, THICK + 12), onRing(r, deg, SEAM_TOP + 1), STONE_LIGHT, Enum.Material.Slate)
	-- the spire: stacked, narrowing blocks turned 45 degrees, an iron finial
	local y = SEAM_TOP + 2
	for k, w in ipairs({ 9, 7, 5, 3.4, 2 }) do
		local h = 5 + k * 1.5
		part(f, "Spire", Vector3.new(w, h, w), onRing(r, deg, y + h / 2) * CFrame.Angles(0, math.rad(45), 0), k % 2 == 0 and STONE_LIGHT or WALL, Enum.Material.Slate)
		y += h
	end
	part(f, "Finial", Vector3.new(0.8, 8, 0.8), onRing(r, deg, y + 4), IRON, Enum.Material.Metal)
	-- a small rose window on its face
	roseWindow(f, onRing(r - (THICK + 10) / 2, deg, floorTop + innerH * 0.6), 8)
end

-- ── Brazier on top of a tower: stone bowl + glowing fire + light ──
local function brazier(parent, centre, y)
	local bowl = part(parent, "BrazierBowl", Vector3.new(2, 7, 7), CFrame.new(centre.X, y + 1, centre.Z) * UP, STONE_DARK)
	bowl.Shape = Enum.PartType.Cylinder
	local fire = part(parent, "Fire", Vector3.new(4.5, 4.5, 4.5), CFrame.new(centre.X, y + 4.5, centre.Z), FIRE, Enum.Material.Neon, Enum.PartType.Ball)
	local light = Instance.new("PointLight")
	light.Color = FIRE
	light.Range = 35 -- (90 lit the whole dark tower terracotta)
	light.Brightness = 1
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
	local faceZ = -14.8 -- in front of the inner face and the plinth (which stands out 1.5)
	local gateBase = onRing(R_TOWER, deg, floorTop) -- floor level, centred on the lane
	part(tower, "GateFrame", Vector3.new(16, 22, 1.6), gateBase * CFrame.new(0, 11, faceZ), STONE_LIGHT, Enum.Material.Slate)
	part(tower, "GateDoor", Vector3.new(11, 18, 1.2), gateBase * CFrame.new(0, 9, faceZ - 0.7), DOOR, Enum.Material.Slate)
	part(tower, "GateGlow", Vector3.new(11, 0.4, 0.4), gateBase * CFrame.new(0, 18.3, faceZ - 1.4), GLOW, Enum.Material.Neon)

	-- glowing emblem high on the face: ring + cross + plot number
	-- a rose window high on the face (it was a neon ring with spokes)
	roseWindow(tower, onRing(R_TOWER, deg, floorTop + 57) * CFrame.new(0, 0, -13), 20) -- (top clear of the wall cornice that runs across the face)
	local sign = part(tower, "PlotSign", Vector3.new(16, 5, 0.8), onRing(R_TOWER, deg, floorTop + 40) * CFrame.new(0, 0, -13.6), STONE_DARK, Enum.Material.Slate)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front -- local -Z, the side facing the lane
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.LightInfluence = 0 -- (readable on the dark stone)
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
		local flame = part(sconces, "SconceFlame", Vector3.new(1.1, 1.6, 1.1), cf * CFrame.new(0, 1.1, 0), SOUL_FLAME, Enum.Material.Neon)
		local light = Instance.new("PointLight")
		light.Color = SOUL_FLAME
		light.Range = 34 -- (55 painted big round light blotches on the wall)
		light.Brightness = 0.8
		light.Shadows = false
		light.Parent = flame
	end
end

ring.Parent = workspace
return "outer wall built: " .. #ring:GetDescendants() .. " instances"
