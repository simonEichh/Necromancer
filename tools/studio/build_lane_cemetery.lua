-- Builds the Realm 1 lane look into ServerStorage.LaneModels.Cemetery (see Design.md, "Realm 1"): a cemetery road.
-- Walls.lua clones it onto every lane when the lane is built (pivoted to the plot's frame), recolours the lane floor
-- (dirt) and leaves out the low side walls (the shoulders are the natural edges). Contents: broken flagstones down the middle of the path (no collision, so
-- the units never catch on them), ragged dirt shoulders with rocks running down into the lava, crooked iron lamp posts,
-- tilted graves, dead trees and low white ground fog. Decoration keeps clear of the spots where the walls stand.
-- Run in Edit mode via the Studio MCP execute_luau (or loadstring over a local http.server, see CLAUDE.md). Safe to re-run.
--
-- Lane space = the plot frame (see PlotFrame): x = across the lane, y = up from the floor top, forward = -Z.
local ServerStorage = game:GetService("ServerStorage")

local folder = ServerStorage:FindFirstChild("LaneModels")
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "LaneModels"
	folder.Parent = ServerStorage
end
local old = folder:FindFirstChild("Cemetery")
if old then
	old:Destroy()
end

local LANE_START, LANE_END = 26, 306 -- forward range of the lane (Walls.lua LANE_START_FWD / LANE_END_FWD)
local HALF = 20 -- half the lane width
local WALLS = { 105, 170.67, 236.33, 302 } -- where the walls stand (Walls.lua wallFwdOf with 4 walls)

local FLAG = {
	Color3.fromRGB(104, 102, 96),
	Color3.fromRGB(92, 90, 86),
	Color3.fromRGB(118, 114, 104),
	Color3.fromRGB(84, 82, 80),
}
local DIRT = Color3.fromRGB(62, 52, 44)
local DIRT_DARK = Color3.fromRGB(46, 39, 34)
local ROCK = Color3.fromRGB(82, 80, 78)
local MOSS_DARK = Color3.fromRGB(54, 74, 40)
local GRAVE = Color3.fromRGB(120, 122, 118)
local IRON_DARK = Color3.fromRGB(40, 34, 32)
local WOOD = Color3.fromRGB(58, 46, 38)
local LAMP = Color3.fromRGB(255, 190, 110)
local FOG = Color3.fromRGB(200, 206, 204)

local rng = Random.new(4401)
local model = Instance.new("Model")
model.Name = "Cemetery"

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
	p.Material = material or Enum.Material.Slate
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if shape then
		p.Shape = shape
	end
	p.Parent = model
	return p
end

local function rod(name, a, b, thickness, color, material)
	local len = (b - a).Magnitude
	local cf = CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.rad(90), 0)
	return part(name, Vector3.new(len, thickness, thickness), cf, color, material or Enum.Material.Wood, Enum.PartType.Cylinder)
end

-- a point of the lane: `lat` across, `fwd` along the lane, `y` above the floor top
local function L(lat, fwd, y)
	return CFrame.new(lat, y or 0, -fwd)
end

-- true when `fwd` is clear of every wall (a wall's crescent and bank reach about 20 studs towards the plot)
local function clearOfWalls(fwd)
	for _, w in ipairs(WALLS) do
		if fwd > w - 24 and fwd < w + 8 then
			return false
		end
	end
	return true
end

-- ============================================================
-- Broken flagstones down the middle of the path
-- ============================================================
for fwd = LANE_START + 2, LANE_END - 4, 4.4 do
	for lat = -8, 8, 4.2 do
		if rng:NextNumber() < 0.6 then
			local w, d = rng:NextNumber(2.4, 3.8), rng:NextNumber(2, 3.4)
			part("Flagstone", Vector3.new(w, 0.3, d), L(lat + rng:NextNumber(-0.8, 0.8), fwd + rng:NextNumber(-0.8, 0.8), -0.02)
				* CFrame.Angles(0, rng:NextNumber(-0.25, 0.25), 0), FLAG[rng:NextInteger(1, #FLAG)], Enum.Material.Slate)
		end
	end
end

-- ============================================================
-- Ragged dirt shoulders outside the lane edges (top below the floor, sloping into the lava), with rocks
-- ============================================================
for _, side in ipairs({ -1, 1 }) do
	local fwd = LANE_START
	while fwd < LANE_END do
		local len = rng:NextNumber(6, 11)
		local w = rng:NextNumber(3, 7)
		local shoulder = part("Shoulder", Vector3.new(w, 3, len + 1), L(side * (HALF + w / 2 - 0.5), fwd + len / 2, -0.35 - 1.5)
			* CFrame.Angles(0, rng:NextNumber(-0.12, 0.12), 0), DIRT, Enum.Material.Ground)
		shoulder.CanCollide = true
		part("Ledge", Vector3.new(w + 2.5, 2, len + 2), L(side * (HALF + w / 2 + 0.5), fwd + len / 2, -1.3 - 1)
			* CFrame.Angles(0, rng:NextNumber(-0.2, 0.2), 0), DIRT_DARK, Enum.Material.Ground)
		if rng:NextNumber() < 0.55 then
			local rs = rng:NextNumber(1.4, 3)
			part("Rock", Vector3.new(rs * 1.3, rs * 0.8, rs), L(side * (HALF + w - 0.5), fwd + rng:NextNumber(0, len), -0.4)
				* CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, 6), rng:NextNumber(-0.3, 0.3)), ROCK, Enum.Material.Slate)
		end
		if rng:NextNumber() < 0.35 then
			part("Moss", Vector3.new(rng:NextNumber(1.5, 3), 0.2, rng:NextNumber(2, 4)), L(side * (HALF + 1.5), fwd + len / 2, -0.28), MOSS_DARK, Enum.Material.Grass)
		end
		fwd += len
	end
end

-- ============================================================
-- Crooked iron lamp posts on the shoulders (warm light), alternating sides
-- ============================================================
local lampSide = 1
for fwd = 44, LANE_END - 10, 33 do
	if clearOfWalls(fwd) then
		local foot = L(lampSide * (HALF + 2.5), fwd, -0.35)
		part("LampBase", Vector3.new(1.6, 0.8, 1.6), foot * CFrame.new(0, 0.4, 0), IRON_DARK, Enum.Material.CorrodedMetal)
		local lean = Vector3.new(-lampSide * rng:NextNumber(0.3, 1), 0, rng:NextNumber(-0.5, 0.5))
		local top = foot.Position + Vector3.new(0, 11, 0) + lean
		rod("LampPost", foot.Position + Vector3.new(0, 0.8, 0), top, 0.45, IRON_DARK, Enum.Material.CorrodedMetal)
		local armEnd = top + Vector3.new(-lampSide * 2.4, -0.3, 0)
		rod("LampArm", top, armEnd, 0.25, IRON_DARK, Enum.Material.CorrodedMetal)
		local lampCf = CFrame.new(armEnd - Vector3.new(0, 1.2, 0))
		part("LampChain", Vector3.new(0.12, 0.8, 0.12), lampCf * CFrame.new(0, 0.8, 0), IRON_DARK, Enum.Material.CorrodedMetal)
		part("LampCage", Vector3.new(1.1, 0.25, 1.1), lampCf * CFrame.new(0, 0.6, 0), IRON_DARK, Enum.Material.CorrodedMetal)
		part("LampCage", Vector3.new(1.1, 0.25, 1.1), lampCf * CFrame.new(0, -0.6, 0), IRON_DARK, Enum.Material.CorrodedMetal)
		local glow = part("LampGlow", Vector3.new(0.7, 1, 0.7), lampCf, LAMP, Enum.Material.Neon)
		local light = Instance.new("PointLight")
		light.Color = LAMP
		light.Range = 20
		light.Brightness = 1.2
		light.Shadows = false
		light.Parent = glow
		lampSide = -lampSide
	end
end

-- ============================================================
-- Tilted graves and dead trees on the shoulders
-- ============================================================
for _ = 1, 14 do
	local fwd = rng:NextNumber(LANE_START + 6, LANE_END - 8)
	if clearOfWalls(fwd) then
		local side = rng:NextNumber() < 0.5 and -1 or 1
		local foot = L(side * rng:NextNumber(HALF + 1.5, HALF + 4), fwd, -0.4)
			* CFrame.Angles(math.rad(rng:NextNumber(-15, 12)), math.rad(rng:NextNumber(-30, 30)), math.rad(rng:NextNumber(-12, 12)))
		local h = rng:NextNumber(2.2, 3.4)
		local cf = foot * CFrame.new(0, h / 2 - 0.3, 0)
		part("Tombstone", Vector3.new(2, h, 0.6), cf, GRAVE, Enum.Material.Slate)
		part("Tombstone", Vector3.new(0.6, 2, 2), cf * CFrame.new(0, h / 2, 0) * CFrame.Angles(0, math.rad(90), 0), GRAVE, Enum.Material.Slate, Enum.PartType.Cylinder)
		part("Moss", Vector3.new(2.1, 0.5, 0.7), cf * CFrame.new(0, -h / 2 + 0.6, 0), MOSS_DARK, Enum.Material.Grass)
	end
end
for _ = 1, 4 do
	local fwd = rng:NextNumber(LANE_START + 10, LANE_END - 10)
	if clearOfWalls(fwd) then
		local side = rng:NextNumber() < 0.5 and -1 or 1
		local base = L(side * rng:NextNumber(HALF + 3, HALF + 5), fwd, -0.4).Position
		local top = base + Vector3.new(side * rng:NextNumber(0.5, 1.5), rng:NextNumber(9, 13), rng:NextNumber(-1, 1))
		rod("Trunk", base, top, 1.1, WOOD)
		for b = 1, 4 do
			local from = base:Lerp(top, 0.45 + b * 0.12)
			local dir = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(0.4, 0.9), rng:NextNumber(-1, 1)).Unit
			rod("Branch", from, from + dir * rng:NextNumber(2.5, 4.5), 0.42 - b * 0.05, WOOD)
		end
	end
end

-- ============================================================
-- Low white ground fog over the lane
-- ============================================================
for _, fwd in ipairs({ 70, 150, 230 }) do
	local holder = part("FogEmitter", Vector3.new(HALF * 2 + 8, 0.5, 70), L(0, fwd, 0.6), FOG, Enum.Material.SmoothPlastic)
	holder.Transparency = 1
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	e.Color = ColorSequence.new(FOG)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 8), NumberSequenceKeypoint.new(1, 16) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.86), NumberSequenceKeypoint.new(0.7, 0.88), NumberSequenceKeypoint.new(1, 1) })
	e.Lifetime = NumberRange.new(9, 13)
	e.Rate = 3
	e.Speed = NumberRange.new(0.3, 0.8)
	e.SpreadAngle = Vector2.new(180, 10)
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-6, 6)
	e.Shape = Enum.ParticleEmitterShape.Box
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	e.Parent = holder
end

local parts = 0
for _, d in ipairs(model:GetDescendants()) do
	if d:IsA("BasePart") then
		parts += 1
	end
end
model.WorldPivot = CFrame.new()
model:SetAttribute("Realm", 1)
model:SetAttribute("FloorColor", Color3.fromRGB(70, 60, 50)) -- Walls.lua recolours the lane floor with these
model:SetAttribute("FloorMaterial", "Ground")
model.Parent = folder
return "Cemetery lane: " .. parts .. " parts"
