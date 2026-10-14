-- Builds the Realm 1 ("The Forgotten Cemetery") wall into ServerStorage.WallModels.Cemetery: a cemetery wall in a
-- CRESCENT that envelops the road (see Design.md, "Wall rework" / "Realm 1"), standing on its own earth bank. Walls.lua
-- clones it for walls 1-3 of a run; the damage stages are animated on the client from the grouped pieces (Segment,
-- Picket, Grave, Lantern, Cross models, see Modules/WallStages).
-- Run in Edit mode via the Studio MCP execute_luau (or loadstring over a local http.server, see CLAUDE.md). Safe to re-run.
--
-- Conventions: origin = floor centre of the wall's middle, FRONT (the side the army comes from) faces -Z, x = across the
-- lane. The crescent's wings curve towards the front.
local ServerStorage = game:GetService("ServerStorage")

local folder = ServerStorage:FindFirstChild("WallModels")
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "WallModels"
	folder.Parent = ServerStorage
end
local old = folder:FindFirstChild("Cemetery")
if old then
	old:Destroy()
end

-- ============================================================
-- Palette (Realm 1: moss green, grey fieldstone, rusty iron, warm lantern gold)
-- ============================================================
local STONE = {
	Color3.fromRGB(104, 106, 100),
	Color3.fromRGB(116, 117, 110),
	Color3.fromRGB(92, 95, 92),
	Color3.fromRGB(126, 124, 114),
}
local STONE_DARK = Color3.fromRGB(70, 72, 70)
local STONE_LIGHT = Color3.fromRGB(146, 144, 134)
local MOSS = Color3.fromRGB(74, 98, 52)
local MOSS_DARK = Color3.fromRGB(54, 74, 40)
local IRON = Color3.fromRGB(62, 48, 40)
local IRON_DARK = Color3.fromRGB(40, 34, 32)
local WOOD = Color3.fromRGB(58, 46, 38)
local ROOT = Color3.fromRGB(64, 50, 40)
local LAMP = Color3.fromRGB(255, 190, 110)
local GRAVE = Color3.fromRGB(120, 122, 118)
local DIRT = Color3.fromRGB(56, 48, 42)
local DIRT_DARK = Color3.fromRGB(42, 36, 32)
local ROCK = Color3.fromRGB(82, 80, 78)

-- ============================================================
-- Shape
-- ============================================================
local R = 45 -- radius of the crescent's arc
local MAX_ANGLE = math.rad(50) -- the wings reach this far round the arc (about 69 studs wide, 16 studs forward)
local SEGMENTS = 14
local H_MID, H_END = 20, 9.5 -- wall height in the middle / at the wing ends
local T_MID, T_END = 4, 3 -- wall thickness
local FENCE_ANGLE = math.rad(28) -- the iron fence runs on top of the middle part only

local rng = Random.new(1307)

local model = Instance.new("Model")
model.Name = "Cemetery"
local wallM = Instance.new("Model")
wallM.Name = "Wall"
wallM.Parent = model
local fenceM = Instance.new("Model")
fenceM.Name = "Fence"
fenceM.Parent = model
local decorM = Instance.new("Model")
decorM.Name = "Decor"
decorM.Parent = model
local groundM = Instance.new("Model")
groundM.Name = "Ground" -- the earth bank the wall stands on (the only parts with collision: players can stand on it)
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

-- point on the arc's foot line at angle a (0 = the middle), and the frame there (RightVector along the wall, local -Z
-- = the wall's front)
local function arcPoint(a)
	return Vector3.new(R * math.sin(a), 0, -R + R * math.cos(a))
end
local function arcFrame(a, y)
	local p = arcPoint(a)
	local tangent = Vector3.new(math.cos(a), 0, -math.sin(a))
	return CFrame.fromMatrix(p + Vector3.new(0, y or 0, 0), tangent, Vector3.yAxis)
end
local function heightAt(a)
	local f = math.abs(a) / MAX_ANGLE
	return H_MID - (H_MID - H_END) * f ^ 1.4
end
local function thicknessAt(a)
	return T_MID - (T_MID - T_END) * math.abs(a) / MAX_ANGLE
end

-- ============================================================
-- Base (PrimaryPart, invisible, at the origin)
-- ============================================================
local base = part(model, "Base", Vector3.new(4, 0.2, 4), CFrame.new(0, 0.1, 0), DIRT)
base.Transparency = 1
model.PrimaryPart = base

-- ============================================================
-- The wall: fieldstone segments along the arc
-- ============================================================
local step = 2 * MAX_ANGLE / SEGMENTS
local chord = 2 * R * math.sin(step / 2)
for i = 0, SEGMENTS - 1 do
	local a = -MAX_ANGLE + (i + 0.5) * step
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
	-- loose fieldstones sticking out of the front face
	for _ = 1, 2 do
		local sy = rng:NextNumber(2.5, h - 2)
		local sx = rng:NextNumber(-w / 2 + 1, w / 2 - 1)
		part(seg, "Fieldstone", Vector3.new(rng:NextNumber(1.4, 2.6), rng:NextNumber(0.9, 1.6), 0.7),
			foot * CFrame.new(sx, sy, -t / 2 - 0.1) * CFrame.Angles(0, 0, math.rad(rng:NextNumber(-8, 8))),
			STONE[rng:NextInteger(1, #STONE)], Enum.Material.Slate)
	end
	-- moss on the coping and creeping down the front
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

-- ============================================================
-- Iron fence on top of the middle part (spiked bars, two rails, a few bent bars)
-- ============================================================
do
	local bars = 26
	for i = 0, bars do
		local a = -FENCE_ANGLE + (2 * FENCE_ANGLE) * i / bars
		local top = heightAt(a) + 0.85
		local barH = 3.6
		local bent = rng:NextNumber() < 0.15
		local tilt = bent and math.rad(rng:NextNumber(-22, 22)) or 0
		local cf = arcFrame(a, top) * CFrame.Angles(tilt, 0, 0) * CFrame.new(0, barH / 2, 0)
		local picket = group(fenceM, "Picket", cf * CFrame.new(0, -barH / 2, 0))
		picket:SetAttribute("Angle", math.deg(a))
		part(picket, "Bar", Vector3.new(0.22, barH, 0.22), cf, IRON, Enum.Material.CorrodedMetal)
		part(picket, "Spike", Vector3.new(0.38, 0.38, 0.38), cf * CFrame.new(0, barH / 2 + 0.15, 0) * CFrame.Angles(math.rad(45), 0, math.rad(45)),
			IRON_DARK, Enum.Material.CorrodedMetal)
	end
	-- rails: short straight pieces between the bars
	for _, ry in ipairs({ 1.1, 3.0 }) do
		for i = 0, bars - 1 do
			local a0 = -FENCE_ANGLE + (2 * FENCE_ANGLE) * i / bars
			local a1 = -FENCE_ANGLE + (2 * FENCE_ANGLE) * (i + 1) / bars
			local p0 = arcPoint(a0) + Vector3.new(0, heightAt(a0) + 0.85 + ry, 0)
			local p1 = arcPoint(a1) + Vector3.new(0, heightAt(a1) + 0.85 + ry, 0)
			local cf = CFrame.lookAt((p0 + p1) / 2, p1)
			part(fenceM, "Rail", Vector3.new(0.16, 0.16, (p1 - p0).Magnitude + 0.1), cf, IRON, Enum.Material.CorrodedMetal)
		end
	end
end

-- ============================================================
-- Stone cross on the middle
-- ============================================================
do
	local top = heightAt(0) + 0.85
	local cf = arcFrame(0, top) * CFrame.Angles(0, 0, math.rad(4))
	local cross = group(decorM, "Cross", cf)
	part(cross, "CrossStem", Vector3.new(1.1, 7, 1.1), cf * CFrame.new(0, 3.5, 0), STONE_LIGHT, Enum.Material.Slate)
	part(cross, "CrossArm", Vector3.new(4.2, 1.1, 1.1), cf * CFrame.new(0, 5.1, 0), STONE_LIGHT, Enum.Material.Slate)
	part(cross, "Moss", Vector3.new(1.3, 1.2, 1.3), cf * CFrame.new(0, 0.6, 0), MOSS, Enum.Material.Grass)
end

-- ============================================================
-- Buttress pillars with hanging lanterns (where the fence ends, and at the wing ends)
-- ============================================================
local function pillar(a, extra)
	local h = heightAt(math.clamp(a, -MAX_ANGLE, MAX_ANGLE)) + extra
	local foot = arcFrame(a)
	part(decorM, "Pillar", Vector3.new(3.4, 1.8, 3.4) + Vector3.new(0.8, 0, 0.8), foot * CFrame.new(0, 0.9, 0), STONE_DARK, Enum.Material.Slate)
	part(decorM, "Pillar", Vector3.new(3.4, h, 3.4), foot * CFrame.new(0, h / 2, 0), STONE[2], Enum.Material.Cobblestone)
	part(decorM, "Cap", Vector3.new(4.2, 1, 4.2), foot * CFrame.new(0, h + 0.5, 0), STONE_LIGHT, Enum.Material.Slate)
	part(decorM, "Cap", Vector3.new(2.4, 2.4, 2.4), foot * CFrame.new(0, h + 1.4, 0) * CFrame.Angles(0, math.rad(45), 0) * CFrame.Angles(math.rad(45), 0, 0),
		STONE_LIGHT, Enum.Material.Slate)
	part(decorM, "Moss", Vector3.new(4.3, 0.3, 4.3), foot * CFrame.new(0, h + 1.05, 0), MOSS, Enum.Material.Grass)
	-- iron arm out to the front, lantern hanging from it
	local armY = h - 2.5
	local armStart = foot * CFrame.new(0, armY, -1.7)
	part(decorM, "Arm", Vector3.new(0.25, 0.25, 2.6), armStart * CFrame.new(0, 0, -1.3), IRON_DARK, Enum.Material.CorrodedMetal)
	local lampCf = armStart * CFrame.new(0, -1.1, -2.4)
	local lantern = group(decorM, "Lantern", lampCf)
	lantern:SetAttribute("Drop", lampCf.Position.Y - foot.Position.Y) -- how far it falls to the ground
	part(lantern, "Chain", Vector3.new(0.12, 0.8, 0.12), lampCf * CFrame.new(0, 0.95, 0), IRON_DARK, Enum.Material.CorrodedMetal)
	part(lantern, "Cage", Vector3.new(1.1, 0.25, 1.1), lampCf * CFrame.new(0, 0.6, 0), IRON_DARK, Enum.Material.CorrodedMetal)
	part(lantern, "Cage", Vector3.new(1.1, 0.25, 1.1), lampCf * CFrame.new(0, -0.6, 0), IRON_DARK, Enum.Material.CorrodedMetal)
	local glow = part(lantern, "LanternGlow", Vector3.new(0.7, 1, 0.7), lampCf, LAMP, Enum.Material.Neon)
	local light = Instance.new("PointLight")
	light.Color = LAMP
	light.Range = 14
	light.Brightness = 1.4
	light.Shadows = false
	light.Parent = glow
end
pillar(-FENCE_ANGLE - step * 0.15, 2.5)
pillar(FENCE_ANGLE + step * 0.15, 2.5)
pillar(-MAX_ANGLE, 3)
pillar(MAX_ANGLE, 3)

-- ============================================================
-- Wings: crooked tombstones in front, roots through the stone, a dead tree near each end
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
	tombstone(side * math.rad(36), 3.2)
	tombstone(side * math.rad(42), 5.5)
	tombstone(side * math.rad(47), 2.8)

	-- roots growing through the wing's front face
	for k = 1, 2 do
		local a = side * math.rad(rng:NextNumber(33, 46))
		local foot = arcFrame(a)
		local t = thicknessAt(a)
		local p0 = (foot * CFrame.new(rng:NextNumber(-2, 2), heightAt(a) - 1, -t / 2 - 0.1)).Position
		local p1 = (foot * CFrame.new(rng:NextNumber(-3, 3), 0.3, -t / 2 - 1.2)).Position
		rod(decorM, "Root", p0, p1, 0.45 - k * 0.08, ROOT)
	end

	-- dead tree just in front of the wing end
	local treeFoot = (arcFrame(side * math.rad(44)) * CFrame.new(side * 1.5, 0, -6)).Position
	local trunkTop = treeFoot + Vector3.new(side * 0.8, 11, 0.5)
	rod(decorM, "Trunk", treeFoot, trunkTop, 1.1, WOOD)
	for b = 1, 4 do
		local from = treeFoot:Lerp(trunkTop, 0.45 + b * 0.12)
		local dir = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(0.4, 0.9), rng:NextNumber(-1, 1)).Unit
		rod(decorM, "Branch", from, from + dir * rng:NextNumber(2.5, 4.5), 0.42 - b * 0.05, WOOD)
	end
end

-- ============================================================
-- Ground: an irregular earth bank under the whole crescent (the wall is wider than the 40-stud lane, so it brings its
-- own ground). Follows the arc a little past the rubble, reaches further forward under the wings (tombstones, trees),
-- ragged edges, a lower ledge and rocks so it slopes down into the hazard. Top BANK_TOP below the lane floor (inside
-- the lane the floor covers it; a top close to the floor's would z-fight and flicker).
-- ============================================================
do
	local BANK_TOP = -0.3
	local GROUND_ANGLE = MAX_ANGLE + math.rad(14)
	local n = 18
	local gStep = 2 * GROUND_ANGLE / n
	local gChord = 2 * R * math.sin(gStep / 2)
	for i = 0, n - 1 do
		local a = -GROUND_ANGLE + (i + 0.5) * gStep
		local f = math.abs(a) / GROUND_ANGLE
		local front = 5 + 5 * math.min(1, f * 1.3) + rng:NextNumber(-1, 1.5) -- deeper in front under the wings
		local back = 4 + rng:NextNumber(-0.5, 1.5)
		local depth = front + back
		local foot = arcFrame(a)
		-- (local -Z is the front: the slab's centre sits (front - back) / 2 towards the front)
		local mid = foot * CFrame.new(0, 0, -(front - back) / 2)
		local top = part(groundM, "Bank", Vector3.new(gChord + 1.2, 4, depth), mid * CFrame.new(0, BANK_TOP - 2, 0)
			* CFrame.Angles(0, math.rad(rng:NextNumber(-4, 4)), 0), DIRT, Enum.Material.Ground)
		top.CanCollide = true
		-- lower ledge, wider: the bank steps down into the hazard
		local ledge = part(groundM, "Ledge", Vector3.new(gChord + 2, 3, depth + 3 + rng:NextNumber(0, 2)),
			mid * CFrame.new(0, -1.1 - 1.5, rng:NextNumber(-0.5, 0.5)) * CFrame.Angles(0, math.rad(rng:NextNumber(-6, 6)), 0), DIRT_DARK, Enum.Material.Ground)
		ledge.CanCollide = true
		-- rocks along the front and back edges
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
-- Rubble beyond the wing ends (the wall runs out into the hazard)
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
model:SetAttribute("SoulColor", Color3.fromRGB(120, 255, 190)) -- the light in the cracks (damage stage 2)
model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
model.Parent = folder

-- (the old preview copy in Plot1's lane is no longer made: the wall is in the game, and the copy stood where wall 1 is)
local preview = workspace:FindFirstChild("WallPreview")
if preview then
	preview:Destroy()
end

local count = 0
for _, d in ipairs(model:GetDescendants()) do
	if d:IsA("BasePart") then
		count += 1
	end
end
return "Cemetery wall: " .. count .. " parts"
