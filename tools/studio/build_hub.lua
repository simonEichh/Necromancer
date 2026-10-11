-- Builds/rebuilds the hub: floor, three shop stalls, east wall and lamp posts.
-- Run in Studio's command bar / via the Studio MCP execute_luau (Edit mode). Safe to re-run.
--
-- Layout (see CLAUDE.md): hub strip is 60 (X) x 410.3 (Z), west edge touches the plots at X = -256,
-- floor top at Y = -1.7. Shopkeeper anchor parts (Workspace.Shops.*) are kept - the server wires their
-- ProximityPrompts - but are made invisible and moved onto the stall counters.
local floorTop = -1.7
local HUB_X, HUB_W, HUB_LEN, HUB_Z = -226, 60, 410.3, 44.35

local STONE_DARK = Color3.fromRGB(58, 60, 72)
local STONE = Color3.fromRGB(88, 91, 106)
local STONE_LIGHT = Color3.fromRGB(122, 126, 142)
local WOOD = Color3.fromRGB(92, 66, 52)
local WOOD_DARK = Color3.fromRGB(62, 44, 36)
local ROBE = Color3.fromRGB(46, 38, 66)
local LAMP = Color3.fromRGB(255, 190, 110)

local old = workspace:FindFirstChild("HubDecor")
if old then old:Destroy() end
local decor = Instance.new("Folder")
decor.Name = "HubDecor"
decor.Parent = workspace

local function part(parent, name, size, pos, color, material, transparency)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.Position = pos
	p.Color = color
	p.Material = material or Enum.Material.Slate
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Transparency = transparency or 0
	p.Parent = parent
	return p
end

-- ── Floor ─────────────────────────────────────────────────────
local floor = workspace.HubFloor
floor.Anchored = true
floor.Orientation = Vector3.new(0, 0, 0)
floor.Size = Vector3.new(HUB_W, 2, HUB_LEN)
floor.Position = Vector3.new(HUB_X, floorTop - 1, HUB_Z)
floor.Material = Enum.Material.Cobblestone
floor.Color = Color3.fromRGB(70, 72, 86)

-- lighter flagstone path down the middle, plus a thin dark inlay on each side of it
part(decor, "Path", Vector3.new(14, 0.1, HUB_LEN), Vector3.new(HUB_X, floorTop + 0.05, HUB_Z), STONE_LIGHT, Enum.Material.Slate)
for _, dx in ipairs({ -7.5, 7.5 }) do
	part(decor, "PathEdge", Vector3.new(1, 0.12, HUB_LEN), Vector3.new(HUB_X + dx, floorTop + 0.06, HUB_Z), STONE_DARK, Enum.Material.Slate)
end

-- ── East wall (water side) with lamp posts ────────────────────
local eastX = HUB_X + HUB_W / 2 - 0.6
part(decor, "EastWall", Vector3.new(0.8, 1.4, HUB_LEN), Vector3.new(eastX, floorTop + 0.7, HUB_Z), STONE, Enum.Material.Cobblestone)
part(decor, "EastWallCap", Vector3.new(1.1, 0.25, HUB_LEN), Vector3.new(eastX, floorTop + 1.52, HUB_Z), STONE_LIGHT, Enum.Material.Slate)

local function lampPost(x, z, height)
	local m = Instance.new("Model")
	m.Name = "LampPost"
	m.Parent = decor
	part(m, "Foot", Vector3.new(1.8, 0.5, 1.8), Vector3.new(x, floorTop + 0.25, z), STONE_DARK)
	part(m, "Pole", Vector3.new(0.7, height, 0.7), Vector3.new(x, floorTop + 0.5 + height / 2, z), STONE)
	part(m, "Cradle", Vector3.new(1.3, 0.3, 1.3), Vector3.new(x, floorTop + 0.5 + height + 0.15, z), STONE_DARK)
	local lamp = part(m, "Lamp", Vector3.new(0.9, 0.9, 0.9), Vector3.new(x, floorTop + 0.5 + height + 0.75, z), LAMP, Enum.Material.Neon)
	part(m, "Cap", Vector3.new(1.3, 0.25, 1.3), Vector3.new(x, floorTop + 0.5 + height + 1.3, z), STONE_DARK)
	local light = Instance.new("PointLight")
	light.Color = LAMP
	light.Range = 18
	light.Brightness = 1.2
	light.Shadows = false
	light.Parent = lamp
end

local segments = 20
local pitch = HUB_LEN / segments
for i = 0, segments do
	local z = HUB_Z - HUB_LEN / 2 + i * pitch
	lampPost(eastX, z, 3.4)                -- on the east wall
	if i % 2 == 0 then
		lampPost(HUB_X - HUB_W / 2 + 3, z, 3.4) -- west side, near the plots
	end
end

-- ── Shop stalls ───────────────────────────────────────────────
-- Each stall faces -X (towards the plots). Origin = centre of the stall on the floor.
local function stall(shopName, label, accent, z)
	local origin = Vector3.new(HUB_X, floorTop, z)
	local function at(x, y, zz) return origin + Vector3.new(x, y, zz) end
	local m = Instance.new("Model")
	m.Name = "Stall_" .. shopName
	m.Parent = decor

	part(m, "Platform", Vector3.new(8.6, 0.3, 10.6), at(0, 0.15, 0), STONE_DARK, Enum.Material.Cobblestone)
	-- counter
	part(m, "Counter", Vector3.new(1.8, 2.0, 8.2), at(-2.2, 1.3, 0), WOOD)
	part(m, "CounterTop", Vector3.new(2.4, 0.2, 8.6), at(-2.2, 2.4, 0), WOOD_DARK)
	part(m, "CounterTrim", Vector3.new(0.12, 0.45, 7.6), at(-3.1, 1.6, 0), accent, Enum.Material.SmoothPlastic)
	-- back shelf wall
	part(m, "BackWall", Vector3.new(0.7, 3.4, 8.6), at(3.6, 2.0, 0), STONE)
	for _, dz in ipairs({ -2.6, 0, 2.6 }) do
		part(m, "Banner", Vector3.new(0.12, 2.0, 1.4), at(3.2, 2.6, dz), accent, Enum.Material.Fabric)
	end
	-- posts + striped canopy
	for _, dx in ipairs({ -3.8, 3.8 }) do
		for _, dz in ipairs({ -4.8, 4.8 }) do
			part(m, "Post", Vector3.new(0.5, 5.2, 0.5), at(dx, 2.9, dz), WOOD_DARK)
		end
	end
	for i = 1, 5 do
		local c = (i % 2 == 1) and accent or STONE_DARK
		part(m, "Canopy" .. i, Vector3.new(9.4, 0.35, 2.2), at(0, 5.65, -4.4 + (i - 1) * 2.2), c, Enum.Material.Fabric)
	end
	part(m, "CanopyRidge", Vector3.new(0.4, 0.5, 11.2), at(0, 5.95, 0), STONE_DARK)
	-- marquee sign standing on the canopy (faces -X)
	for _, dz in ipairs({ -2.2, 2.2 }) do
		part(m, "SignSupport", Vector3.new(0.3, 1.2, 0.3), at(-4.2, 6.55, dz), WOOD_DARK)
	end
	local sign = part(m, "Sign", Vector3.new(0.3, 1.5, 6.0), at(-4.2, 7.3, 0), WOOD_DARK)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Left
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 60
	gui.Parent = sign
	local text = Instance.new("TextLabel")
	text.Size = UDim2.new(1, 0, 1, 0)
	text.BackgroundTransparency = 1
	text.Text = label
	text.TextColor3 = accent
	text.TextScaled = true
	text.Font = Enum.Font.GothamBlack
	text.Parent = gui
	-- merchant: a hooded figure behind the counter
	part(m, "Robe", Vector3.new(2.2, 2.8, 1.6), at(0.6, 1.7, 0), ROBE, Enum.Material.Fabric)
	part(m, "Shoulders", Vector3.new(2.6, 0.7, 1.9), at(0.6, 3.0, 0), ROBE, Enum.Material.Fabric)
	part(m, "Hood", Vector3.new(1.7, 1.7, 1.7), at(0.6, 4.0, 0), ROBE, Enum.Material.Fabric)
	part(m, "Face", Vector3.new(0.1, 1.1, 1.2), at(-0.28, 3.95, 0), Color3.fromRGB(12, 10, 16), Enum.Material.SmoothPlastic)
	for _, dz in ipairs({ -0.3, 0.3 }) do
		part(m, "Eye", Vector3.new(0.1, 0.22, 0.22), at(-0.31, 4.0, dz), accent, Enum.Material.Neon)
	end
	for _, dz in ipairs({ -1.7, 1.7 }) do
		part(m, "Arm", Vector3.new(1.8, 0.5, 0.5), at(-1.0, 2.6, dz), ROBE, Enum.Material.Fabric)
	end
	-- goods on the counter + a candle
	for i, dz in ipairs({ -2.8, -1.7, 1.9, 3.0 }) do
		part(m, "Goods" .. i, Vector3.new(0.7, 0.7, 0.7), at(-2.3, 2.85, dz), accent, Enum.Material.SmoothPlastic)
	end
	local candle = part(m, "Candle", Vector3.new(0.3, 0.6, 0.3), at(-2.0, 2.8, -0.9), LAMP, Enum.Material.Neon)
	local light = Instance.new("PointLight")
	light.Color = accent
	light.Range = 14
	light.Brightness = 1
	light.Shadows = false
	light.Parent = candle

	-- the interaction anchor used by the server: invisible, on top of the counter
	local anchor = workspace.Shops[shopName]
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.Transparency = 1
	anchor.Orientation = Vector3.new(0, 0, 0)
	anchor.Size = Vector3.new(2.4, 1, 6)
	anchor.Position = at(-2.2, 3.0, 0)
	return m
end

stall("GraveShopkeeper", "BUY", Color3.fromRGB(90, 220, 140), 58)
stall("SellShopkeeper", "SELL", Color3.fromRGB(255, 205, 80), 74)
stall("UpgradeShopkeeper", "UPGRADE", Color3.fromRGB(170, 120, 255), 90)

return "hub built: " .. #decor:GetDescendants() .. " instances"
