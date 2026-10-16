-- Lays the whole world out as a coliseum: a circular plaza in the middle (shop stalls + beacon) with the
-- 8 plots arranged around it, each plot's lane pointing straight outward. Safe to re-run.
-- Run in Studio's command bar / via the Studio MCP execute_luau (Edit mode).
--
-- Conventions (the server derives everything from the parts we place here, see CLAUDE.md):
--   * every plot is rotated so the Base part's LookVector (local -Z) is the lane direction (outward);
--     Base size = (40 across, 2, 48 along), WallOrigin on the outer edge, PlayerSpawn at +8 along the lane,
--     GraveSpot1-10 as 2 columns (-10 / -18 along the lane) x 5 rows (-14..14 across, spaced 7).
--   * Workspace attribute HubSpawn = where the SHOPS button teleports players.
local floorTop = -1.7
local PLAZA_R = 56        -- radius of the plaza disc
local PLOT_IN_R = 60      -- distance from the centre to a plot's inner edge
local PLOT_LEN, PLOT_W = 48, 40

local STONE_DARK = Color3.fromRGB(58, 60, 72)
local STONE = Color3.fromRGB(88, 91, 106)
local STONE_LIGHT = Color3.fromRGB(122, 126, 142)
local WOOD = Color3.fromRGB(92, 66, 52)
local WOOD_DARK = Color3.fromRGB(62, 44, 36)
local ROBE = Color3.fromRGB(46, 38, 66)
local LAMP = Color3.fromRGB(255, 190, 110)
local GLOW = Color3.fromRGB(120, 255, 190)

-- direction on the ground for a compass angle in degrees (0 = -Z, clockwise when seen from above)
local function dirAt(deg)
	local a = math.rad(deg)
	return Vector3.new(math.sin(a), 0, -math.cos(a))
end

-- ── Plots ─────────────────────────────────────────────────────
local ROWS = { -14, -7, 0, 7, 14 }
for i = 1, 8 do
	local m = workspace.Plots["Plot" .. i]
	local d = dirAt((i - 1) * 45)
	local centre = d * (PLOT_IN_R + PLOT_LEN / 2) -- plot centre on the ground plane
	local function at(forward, lateral, y, size)
		-- world CFrame at (forward along the lane, lateral across), facing down the lane
		local base = CFrame.lookAt(Vector3.new(centre.X, y, centre.Z), Vector3.new(centre.X, y, centre.Z) + d)
		return base * CFrame.new(lateral, 0, -forward) -- local -Z is forward
	end

	local base = m.Base
	base.Size = Vector3.new(PLOT_W, 2, PLOT_LEN)
	base.CFrame = at(0, 0, floorTop - 1)

	m.WallOrigin.Size = Vector3.new(PLOT_W, 6, 1)
	m.WallOrigin.CFrame = at(PLOT_LEN / 2, 0, 1.3)

	m.PlayerSpawn.Size = Vector3.new(12, 0.2, 12)
	m.PlayerSpawn.CFrame = at(8, 0, floorTop + 0.1)

	for g = 1, 10 do
		local spot = m["GraveSpot" .. g]
		local col = (g - 1) // 5 + 1
		local row = (g - 1) % 5 + 1
		spot.Size = Vector3.new(4, 0.1, 4)
		spot.CFrame = at(col == 1 and -10 or -18, ROWS[row], -1.6)
		spot.Transparency = 1
		spot.CanCollide = false
		spot.CanTouch = false
		spot.CanQuery = false
	end
end

-- ── Hub: clear the old one ────────────────────────────────────
local old = workspace:FindFirstChild("HubDecor")
if old then old:Destroy() end
local decor = Instance.new("Folder")
decor.Name = "HubDecor"
decor.Parent = workspace

local function part(parent, name, size, cframe, color, material, shape)
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
	p.Parent = parent
	return p
end

-- flat disc (cylinder with its axis pointing up)
local UP = CFrame.Angles(0, 0, math.rad(90))
local function disc(parent, name, radius, thickness, y, color, material)
	return part(parent, name, Vector3.new(thickness, radius * 2, radius * 2), CFrame.new(0, y, 0) * UP, color, material, Enum.PartType.Cylinder)
end

-- ── Plaza floor ───────────────────────────────────────────────
local floor = workspace.HubFloor
floor.Shape = Enum.PartType.Cylinder
floor.Anchored = true
floor.Size = Vector3.new(2, PLAZA_R * 2, PLAZA_R * 2)
floor.CFrame = CFrame.new(0, floorTop - 1, 0) * UP
floor.Material = Enum.Material.Cobblestone
floor.Color = Color3.fromRGB(70, 72, 86)

disc(decor, "InlayOuter", 27, 0.1, floorTop + 0.05, STONE_DARK)
disc(decor, "InlayRing", 25.5, 0.12, floorTop + 0.06, STONE_LIGHT, Enum.Material.Slate)
disc(decor, "InlayInner", 23.5, 0.14, floorTop + 0.07, STONE_DARK)
disc(decor, "Podium", 9, 0.5, floorTop + 0.25, STONE, Enum.Material.Cobblestone)

-- gate paths: from the plaza edge to each plot's inner edge
for i = 1, 8 do
	local d = dirAt((i - 1) * 45)
	local mid = d * (PLAZA_R + 1)
	local cf = CFrame.lookAt(Vector3.new(mid.X, floorTop + 0.05, mid.Z), Vector3.new(mid.X, floorTop + 0.05, mid.Z) + d)
	part(decor, "GatePath", Vector3.new(16, 0.1, 10), cf, STONE_LIGHT)
	for _, side in ipairs({ -8, 8 }) do
		part(decor, "GateEdge", Vector3.new(0.8, 0.12, 10), cf * CFrame.new(side, 0.01, 0), STONE_DARK)
	end
end

-- ── Central monument + beacon ─────────────────────────────────
part(decor, "MonumentBase", Vector3.new(6, 1, 6), CFrame.new(0, floorTop + 1, 0), STONE_DARK, Enum.Material.Cobblestone)
part(decor, "MonumentStep", Vector3.new(4.4, 1, 4.4), CFrame.new(0, floorTop + 2, 0), STONE)
part(decor, "MonumentShaft", Vector3.new(2.6, 14, 2.6), CFrame.new(0, floorTop + 9.5, 0), STONE)
part(decor, "MonumentCap", Vector3.new(3.4, 0.7, 3.4), CFrame.new(0, floorTop + 16.85, 0), STONE_LIGHT)
local orb = part(decor, "Beacon", Vector3.new(2.4, 2.4, 2.4), CFrame.new(0, floorTop + 18.6, 0), GLOW, Enum.Material.Neon, Enum.PartType.Ball)
local orbLight = Instance.new("PointLight")
orbLight.Color = GLOW
orbLight.Range = 40
orbLight.Brightness = 1.5
orbLight.Shadows = false
orbLight.Parent = orb

-- ── Lamp posts ────────────────────────────────────────────────
local function lampPost(parent, cframe, height)
	local m = Instance.new("Model")
	m.Name = "LampPost"
	m.Parent = parent
	local function p(name, size, y, color, material)
		return part(m, name, size, cframe * CFrame.new(0, y, 0), color, material)
	end
	p("Foot", Vector3.new(1.8, 0.5, 1.8), 0.25, STONE_DARK)
	p("Pole", Vector3.new(0.7, height, 0.7), 0.5 + height / 2, STONE)
	p("Cradle", Vector3.new(1.3, 0.3, 1.3), 0.5 + height + 0.15, STONE_DARK)
	local lamp = p("Lamp", Vector3.new(0.9, 0.9, 0.9), 0.5 + height + 0.75, LAMP, Enum.Material.Neon)
	p("Cap", Vector3.new(1.3, 0.25, 1.3), 0.5 + height + 1.3, STONE_DARK)
	local light = Instance.new("PointLight")
	light.Color = LAMP
	light.Range = 18
	light.Brightness = 1.2
	light.Shadows = false
	light.Parent = lamp
end

-- framing every gate
for i = 1, 8 do
	for _, off in ipairs({ -10.5, 10.5 }) do
		local p = dirAt((i - 1) * 45 + off) * (PLAZA_R - 1.5)
		lampPost(decor, CFrame.new(p.X, floorTop, p.Z), 3.4)
	end
end
-- on every plot, near its four corners
for i = 1, 8 do
	local m = workspace.Plots["Plot" .. i]
	local base = m.Base
	for _, corner in ipairs({ Vector3.new(-18.5, 1, 22.5), Vector3.new(18.5, 1, 22.5), Vector3.new(-18.5, 1, -22.5), Vector3.new(18.5, 1, -22.5) }) do
		local p = (base.CFrame * CFrame.new(corner)).Position
		lampPost(decor, CFrame.new(p.X, floorTop, p.Z), 3.4)
	end
end

-- ── Plaza rim wall (with gaps at the 8 gates) ─────────────────
local RIM_R = PLAZA_R - 1.2
for k = 0, 71 do
	local deg = k * 5
	local nearest = math.abs(((deg + 22.5) % 45) - 22.5) -- distance to the nearest gate angle
	if nearest > 9 then
		local pos = dirAt(deg) * RIM_R
		local cf = CFrame.lookAt(Vector3.new(pos.X, floorTop + 0.7, pos.Z), Vector3.new(0, floorTop + 0.7, 0))
		part(decor, "Rim", Vector3.new(5.3, 1.4, 0.9), cf, STONE, Enum.Material.Cobblestone)
		part(decor, "RimCap", Vector3.new(5.4, 0.22, 1.2), cf * CFrame.new(0, 0.81, 0), STONE_LIGHT)
	end
end

-- ── Shop stalls ───────────────────────────────────────────────
-- Built around the origin facing -X, then moved into place with PivotTo so they face the monument.
local function buildStall(shopName, label, accent, deg)
	local origin = Vector3.new(0, floorTop, 0)
	local function at(x, y, z) return CFrame.new(origin + Vector3.new(x, y, z)) end
	local m = Instance.new("Model")
	m.Name = "Stall_" .. shopName
	m.WorldPivot = CFrame.new(origin)
	m.Parent = decor

	local function p(name, size, x, y, z, color, material)
		return part(m, name, size, at(x, y, z), color, material)
	end
	p("Platform", Vector3.new(8.6, 0.3, 10.6), 0, 0.15, 0, STONE_DARK, Enum.Material.Cobblestone)
	p("Counter", Vector3.new(1.8, 2.0, 8.2), -2.2, 1.3, 0, WOOD)
	p("CounterTop", Vector3.new(2.4, 0.2, 8.6), -2.2, 2.4, 0, WOOD_DARK)
	p("CounterTrim", Vector3.new(0.12, 0.45, 7.6), -3.1, 1.6, 0, accent, Enum.Material.SmoothPlastic)
	p("BackWall", Vector3.new(0.7, 3.4, 8.6), 3.6, 2.0, 0, STONE)
	for _, dz in ipairs({ -2.6, 0, 2.6 }) do
		p("Banner", Vector3.new(0.12, 2.0, 1.4), 3.2, 2.6, dz, accent, Enum.Material.Fabric)
	end
	for _, dx in ipairs({ -3.8, 3.8 }) do
		for _, dz in ipairs({ -4.8, 4.8 }) do
			p("Post", Vector3.new(0.5, 5.2, 0.5), dx, 2.9, dz, WOOD_DARK)
		end
	end
	for k = 1, 5 do
		local c = (k % 2 == 1) and accent or STONE_DARK
		p("Canopy" .. k, Vector3.new(9.4, 0.35, 2.2), 0, 5.65, -4.4 + (k - 1) * 2.2, c, Enum.Material.Fabric)
	end
	p("CanopyRidge", Vector3.new(0.4, 0.5, 11.2), 0, 5.95, 0, STONE_DARK)
	for _, dz in ipairs({ -2.2, 2.2 }) do
		p("SignSupport", Vector3.new(0.3, 1.2, 0.3), -4.2, 6.55, dz, WOOD_DARK)
	end
	local sign = p("Sign", Vector3.new(0.3, 1.5, 6.0), -4.2, 7.3, 0, WOOD_DARK)
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
	p("Robe", Vector3.new(2.2, 2.8, 1.6), 0.6, 1.7, 0, ROBE, Enum.Material.Fabric)
	p("Shoulders", Vector3.new(2.6, 0.7, 1.9), 0.6, 3.0, 0, ROBE, Enum.Material.Fabric)
	p("Hood", Vector3.new(1.7, 1.7, 1.7), 0.6, 4.0, 0, ROBE, Enum.Material.Fabric)
	p("Face", Vector3.new(0.1, 1.1, 1.2), -0.28, 3.95, 0, Color3.fromRGB(12, 10, 16), Enum.Material.SmoothPlastic)
	for _, dz in ipairs({ -0.3, 0.3 }) do
		p("Eye", Vector3.new(0.1, 0.22, 0.22), -0.31, 4.0, dz, accent, Enum.Material.Neon)
	end
	for _, dz in ipairs({ -1.7, 1.7 }) do
		p("Arm", Vector3.new(1.8, 0.5, 0.5), -1.0, 2.6, dz, ROBE, Enum.Material.Fabric)
	end
	for k, dz in ipairs({ -2.8, -1.7, 1.9, 3.0 }) do
		p("Goods" .. k, Vector3.new(0.7, 0.7, 0.7), -2.3, 2.85, dz, accent, Enum.Material.SmoothPlastic)
	end
	local candle = p("Candle", Vector3.new(0.3, 0.6, 0.3), -2.0, 2.8, -0.9, LAMP, Enum.Material.Neon)
	local light = Instance.new("PointLight")
	light.Color = accent
	light.Range = 14
	light.Brightness = 1
	light.Shadows = false
	light.Parent = candle

	-- place it on the plaza: local +X points away from the monument, so the counter faces the centre
	local pos = dirAt(deg) * 31
	local cf = CFrame.fromMatrix(Vector3.new(pos.X, floorTop, pos.Z), dirAt(deg), Vector3.yAxis)
	m:PivotTo(cf)

	-- the interaction anchor used by the server: invisible, on top of the counter
	local anchor = workspace.Shops[shopName]
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(2.4, 1, 6)
	anchor.CFrame = cf * CFrame.new(-2.2, 3.0, 0)
end

-- the grave shop (plaza angle 22.5) and the Forge (202.5) have their own detailed stalls: after re-running this script,
-- run build_grave_stall.lua and build_forge_stall.lua again
-- (the old Sell and Upgrade stalls were removed on 2026-10-16: selling is in the inventory, upgrades in the HUD tile)

workspace:SetAttribute("HubSpawn", Vector3.new(0, floorTop + 3, 18))

return "coliseum built: " .. #decor:GetDescendants() .. " hub instances"
