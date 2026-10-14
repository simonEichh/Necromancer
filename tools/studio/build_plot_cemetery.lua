-- Builds the Realm 1 plot look into ServerStorage.LaneModels.CemeteryPlot (see Design.md "Realm 1"): the plot becomes
-- part of the realm like the lane, so the cut between neutral stone and the realm sits at the plot's entrance arch.
-- Contents: grass and moss strips under the two rows of graves (tools/studio/layout_graves.lua), a path of broken
-- flagstones down the middle (it runs on into the lane's), crumbling fieldstone walls with a spiked iron fence along
-- both sides (players cannot fall off; units ignore them), and a cemetery gate at the plaza entrance (two fieldstone
-- pillars with hanging lanterns, a wrought iron arch with spikes, the plot number on a plaque: part "PlotSign", its
-- TextLabel is filled in by the server).
-- The server module PlotLook clones it onto a plot when it is claimed (pivoted to the plot's frame), recolours the Base
-- (attributes FloorColor / FloorMaterial) and hides the plot's neutral Style parts it replaces (attribute Hides, a
-- comma list of part names); it restores them when the player leaves.
-- Run in Edit mode via the Studio MCP execute_luau (or loadstring, see CLAUDE.md). Safe to re-run.
--
-- Plot space = the plot frame (floor-level centre of the Base): x = across, y = up, forward (down the lane) = -Z.
-- The Base is 40 across and 48 along (forward -24 at the plaza .. +24 where the lane starts).
local ServerStorage = game:GetService("ServerStorage")

local folder = ServerStorage:FindFirstChild("LaneModels")
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "LaneModels"
	folder.Parent = ServerStorage
end
local old = folder:FindFirstChild("CemeteryPlot")
if old then
	old:Destroy()
end

local HALF_W, HALF_L = 20, 24
local GRAVE_LAT = 13

local STONE = {
	Color3.fromRGB(104, 106, 100),
	Color3.fromRGB(116, 117, 110),
	Color3.fromRGB(92, 95, 92),
}
local STONE_LIGHT = Color3.fromRGB(146, 144, 134)
local STONE_DARK = Color3.fromRGB(70, 72, 70)
local FLAG = { Color3.fromRGB(104, 102, 96), Color3.fromRGB(92, 90, 86), Color3.fromRGB(118, 114, 104) }
local GRASS = Color3.fromRGB(58, 82, 48)
local MOSS = Color3.fromRGB(74, 98, 52)
local MUD = Color3.fromRGB(56, 46, 40)
local IRON = Color3.fromRGB(62, 48, 40)
local IRON_DARK = Color3.fromRGB(40, 34, 32)
local LAMP = Color3.fromRGB(255, 190, 110)
local GLOW = Color3.fromRGB(120, 255, 190)

local rng = Random.new(6613)
local model = Instance.new("Model")
model.Name = "CemeteryPlot"

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

local function L(lat, fwd, y)
	return CFrame.new(lat, y or 0, -fwd)
end

-- ============================================================
-- Grass and moss under the two rows of graves (a little above the floor; no collision)
-- ============================================================
for _, side in ipairs({ -1, 1 }) do
	part("GraveMud", Vector3.new(10, 0.1, 44), L(side * GRAVE_LAT, -2, 0.04), MUD, Enum.Material.Mud)
	local fwd = -22
	while fwd < 20 do
		local len = rng:NextNumber(4, 8)
		part("GraveGrass", Vector3.new(rng:NextNumber(7, 9.5), 0.12, len), L(side * (GRAVE_LAT + rng:NextNumber(-0.8, 0.8)), fwd + len / 2, 0.08)
			* CFrame.Angles(0, rng:NextNumber(-0.15, 0.15), 0), GRASS, Enum.Material.Grass)
		fwd += len - 0.6
	end
	for _ = 1, 4 do
		part("Moss", Vector3.new(rng:NextNumber(1.5, 3), 0.14, rng:NextNumber(1.5, 3)), L(side * rng:NextNumber(6, 9), rng:NextNumber(-20, 18), 0.09)
			* CFrame.Angles(0, rng:NextNumber(0, 3), 0), MOSS, Enum.Material.Grass)
	end
end

-- ============================================================
-- Broken flagstones down the middle path (they run on into the lane's)
-- ============================================================
for fwd = -HALF_L + 2, HALF_L - 1, 4.4 do
	for lat = -4.2, 4.2, 4.2 do
		if rng:NextNumber() < 0.65 then
			local w, d = rng:NextNumber(2.4, 3.8), rng:NextNumber(2, 3.4)
			part("Flagstone", Vector3.new(w, 0.3, d), L(lat + rng:NextNumber(-0.6, 0.6), fwd + rng:NextNumber(-0.6, 0.6), -0.02)
				* CFrame.Angles(0, rng:NextNumber(-0.25, 0.25), 0), FLAG[rng:NextInteger(1, #FLAG)], Enum.Material.Slate)
		end
	end
end

-- ============================================================
-- Crumbling fieldstone walls along both sides with a spiked iron fence (players cannot fall off; Decor group)
-- ============================================================
for _, side in ipairs({ -1, 1 }) do
	local lat = side * (HALF_W + 0.6)
	local fwd = -HALF_L + 2.5
	while fwd < HALF_L do
		local len = rng:NextNumber(4.5, 7)
		local h = rng:NextNumber(2.2, 3.4)
		local wall = part("SideWall", Vector3.new(1.4, h, len + 0.2), L(lat, fwd + len / 2, h / 2), STONE[rng:NextInteger(1, #STONE)], Enum.Material.Cobblestone)
		wall.CanCollide = true
		part("SideWallCap", Vector3.new(1.7, 0.4, len + 0.3), L(lat, fwd + len / 2, h + 0.15) * CFrame.Angles(0, 0, math.rad(rng:NextNumber(-3, 3))), STONE_LIGHT, Enum.Material.Slate)
		if rng:NextNumber() < 0.5 then
			part("Moss", Vector3.new(1.8, 0.25, len * rng:NextNumber(0.4, 0.8)), L(lat, fwd + len / 2, h + 0.4), MOSS, Enum.Material.Grass)
		end
		-- the iron fence on top: a rail and spiked bars
		part("FenceRail", Vector3.new(0.16, 0.16, len), L(lat, fwd + len / 2, h + 2.2), IRON, Enum.Material.CorrodedMetal)
		for b = 0.6, len - 0.4, 1.3 do
			local tilt = rng:NextNumber() < 0.12 and math.rad(rng:NextNumber(-18, 18)) or 0
			local bar = L(lat, fwd + b, h + 0.3) * CFrame.Angles(tilt, 0, 0) * CFrame.new(0, 1.3, 0)
			part("FenceBar", Vector3.new(0.18, 2.6, 0.18), bar, IRON, Enum.Material.CorrodedMetal)
			part("FenceSpike", Vector3.new(0.3, 0.3, 0.3), bar * CFrame.new(0, 1.4, 0) * CFrame.Angles(math.rad(45), 0, math.rad(45)), IRON_DARK, Enum.Material.CorrodedMetal)
		end
		fwd += len + (rng:NextNumber() < 0.15 and 0.8 or 0) -- now and then a small gap where the wall crumbled
	end
end

-- ============================================================
-- The cemetery gate at the plaza entrance
-- ============================================================
do
	local gateFwd = -HALF_L + 0.8
	for _, side in ipairs({ -1, 1 }) do
		local lat = side * 10.6
		part("GatePillar", Vector3.new(3, 1, 3), L(lat, gateFwd, 0.5), STONE_DARK, Enum.Material.Slate)
		part("GatePillar", Vector3.new(2.4, 9, 2.4), L(lat, gateFwd, 5.5), STONE[2], Enum.Material.Cobblestone)
		part("GatePillarCap", Vector3.new(3, 0.8, 3), L(lat, gateFwd, 10.4), STONE_LIGHT, Enum.Material.Slate)
		part("GatePillarCap", Vector3.new(1.6, 1.6, 1.6), L(lat, gateFwd, 11.4) * CFrame.Angles(0, math.rad(45), 0) * CFrame.Angles(math.rad(45), 0, 0), STONE_LIGHT, Enum.Material.Slate)
		part("Moss", Vector3.new(3.1, 0.3, 3.1), L(lat, gateFwd, 10.9), MOSS, Enum.Material.Grass)
		-- a lantern hanging from an iron arm on the plaza side
		part("LanternArm", Vector3.new(0.22, 0.22, 2), L(lat, gateFwd - 1.8, 8.4), IRON_DARK, Enum.Material.CorrodedMetal)
		local lampCf = L(lat, gateFwd - 2.6, 7.2)
		part("LanternCage", Vector3.new(0.9, 0.2, 0.9), lampCf * CFrame.new(0, 0.55, 0), IRON_DARK, Enum.Material.CorrodedMetal)
		part("LanternCage", Vector3.new(0.9, 0.2, 0.9), lampCf * CFrame.new(0, -0.55, 0), IRON_DARK, Enum.Material.CorrodedMetal)
		local glow = part("LanternGlow", Vector3.new(0.6, 0.9, 0.6), lampCf, LAMP, Enum.Material.Neon)
		local light = Instance.new("PointLight")
		light.Color = LAMP
		light.Range = 16
		light.Brightness = 1.2
		light.Shadows = false
		light.Parent = glow
	end
	-- the wrought iron arch between the pillars: a curve of short bars with spikes, a plaque with the plot number
	local n = 12
	local span, rise, baseY = 9.4, 3.2, 10.8
	local prev
	for k = 0, n do
		local f = k / n
		local x = -span + 2 * span * f
		local y = baseY + math.sin(f * math.pi) * rise
		local p = Vector3.new(x, y, 0)
		if prev then
			local a, b = L(prev.X, gateFwd, prev.Y).Position, L(p.X, gateFwd, p.Y).Position
			part("ArchIron", Vector3.new(0.25, 0.25, (b - a).Magnitude + 0.1), CFrame.lookAt((a + b) / 2, b), IRON_DARK, Enum.Material.CorrodedMetal)
		end
		if k % 2 == 0 and k > 0 and k < n then
			part("ArchSpike", Vector3.new(0.14, 1.2, 0.14), L(x, gateFwd, y + 0.6), IRON, Enum.Material.CorrodedMetal)
			part("ArchSpike", Vector3.new(0.28, 0.28, 0.28), L(x, gateFwd, y + 1.25) * CFrame.Angles(math.rad(45), 0, math.rad(45)), IRON_DARK, Enum.Material.CorrodedMetal)
		end
		prev = p
	end
	part("ArchIron", Vector3.new(2 * span, 0.25, 0.25), L(0, gateFwd, baseY), IRON_DARK, Enum.Material.CorrodedMetal)
	local plaque = part("PlotSign", Vector3.new(5, 1.4, 0.3), L(0, gateFwd, baseY + rise - 0.6), STONE_DARK, Enum.Material.Slate)
	for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 60
		gui.Parent = plaque
		local text = Instance.new("TextLabel")
		text.Name = "PlotNumber"
		text.Size = UDim2.new(1, 0, 1, 0)
		text.BackgroundTransparency = 1
		text.Text = "PLOT"
		text.TextColor3 = GLOW
		text.TextScaled = true
		text.Font = Enum.Font.GothamBlack
		text.Parent = gui
	end
end

local parts = 0
for _, d in ipairs(model:GetDescendants()) do
	if d:IsA("BasePart") then
		parts += 1
	end
end
model.WorldPivot = CFrame.new()
model:SetAttribute("Realm", 1)
model:SetAttribute("FloorColor", Color3.fromRGB(70, 60, 50))
model:SetAttribute("FloorMaterial", "Ground")
-- the plot's neutral Style parts this look replaces (style_plots.lua)
model:SetAttribute("Hides", "SideWall,SideWallCap,GraveMud,GraveGrass,ArchPillar,ArchPillarCap,ArchLintel,ArchGlow,ArchSign")
model.Parent = folder
return "Cemetery plot: " .. parts .. " parts"
