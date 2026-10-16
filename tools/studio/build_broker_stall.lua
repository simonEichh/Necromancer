-- Builds the Soul Broker's gem stall on the plaza: Workspace.HubDecor.Stall_SoulBroker (a hooded merchant behind a
-- carved counter, a tall gallery wall with three gilded portraits (the big Featured one in the centre, Bundle left,
-- Potion right) and the Curio portrait on an easel front right (where the stall view's camera sees it), a velvet canopy, lanterns, gem chests, potion shelves)
-- and the invisible interaction anchor Workspace.Shops.SoulBroker (with its ProximityPrompt; the server wires it in
-- ShopNpcs). Design.md "The Soul Broker". Theme: violet velvet, gold and gem cyan (the grave shop is red, the Forge green).
-- Each portrait's canvas is a part named "Canvas" with the attribute Portrait = 1..4 (BrokerDeals.PORTRAITS order): the
-- client (BrokerPortraits) paints the offers onto them, price badge and sale ribbon included.
-- Run in Edit mode via the Studio MCP execute_luau. Safe to re-run (it replaces both).

local CollectionService = game:GetService("CollectionService")

local floorTop = -1.7
local DEG = 157.5 -- plaza angle (dirAt(deg) = (sin, 0, -cos)): halfway between the Plot4 (135) and Plot5 (180) paths
local RADIUS = 38

local STONE_DARK = Color3.fromRGB(46, 42, 56)
local STONE = Color3.fromRGB(74, 70, 88)
local STONE_LIGHT = Color3.fromRGB(108, 104, 124)
local BASALT = Color3.fromRGB(30, 28, 38)
local VELVET = Color3.fromRGB(70, 34, 96)
local VELVET_DARK = Color3.fromRGB(42, 20, 60)
local GOLD = Color3.fromRGB(212, 168, 82)
local GOLD_DARK = Color3.fromRGB(150, 112, 52)
local WOOD = Color3.fromRGB(58, 38, 32)
local WOOD_DARK = Color3.fromRGB(38, 26, 24)
local IRON = Color3.fromRGB(44, 44, 52)
local BONE = Color3.fromRGB(226, 216, 190)
local GEM = Color3.fromRGB(110, 210, 255)
local GEM_VIOLET = Color3.fromRGB(190, 120, 255)
local POTION = Color3.fromRGB(90, 230, 140)
local CANVAS = Color3.fromRGB(22, 18, 30)
local FLAME = Color3.fromRGB(255, 196, 120)

local decor = workspace:FindFirstChild("HubDecor")
local shops = workspace:FindFirstChild("Shops")
assert(decor and shops, "HubDecor / Shops missing")
local old = decor:FindFirstChild("Stall_SoulBroker")
if old then old:Destroy() end

local origin = Vector3.new(0, floorTop, 0)
local m = Instance.new("Model")
m.Name = "Stall_SoulBroker"
m.WorldPivot = CFrame.new(origin)

-- local frame: built around the origin facing -X (the counter side faces the monument after PivotTo); +Z is the
-- customer's right
local function at(x, y, z)
	return CFrame.new(origin + Vector3.new(x, y, z))
end

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
	if shape then p.Shape = shape end
	p.Parent = parent
	return p
end
local function solid(...)
	local p = part(...)
	p.CanCollide = true
	return p
end
local function wedge(parent, name, size, cf, color, material)
	local w = Instance.new("WedgePart")
	w.Name = name
	w.Anchored = true
	w.CanCollide = false
	w.CastShadow = false
	w.Size = size
	w.CFrame = cf
	w.Color = color
	w.Material = material or Enum.Material.Slate
	w.Parent = parent
	return w
end
local function light(parent, color, range, brightness)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Shadows = false
	l.Parent = parent
	return l
end
local UPRIGHT = CFrame.Angles(0, 0, math.rad(90)) -- a vertical cylinder (Roblox cylinders run along X)
local function disc(parent, name, radius, height, cf, color, material)
	return part(parent, name, Vector3.new(height, radius * 2, radius * 2), cf * UPRIGHT, color, material, Enum.PartType.Cylinder)
end
local function ball(parent, name, d, cf, color, material)
	return part(parent, name, Vector3.new(d, d, d), cf, color, material or Enum.Material.SmoothPlastic, Enum.PartType.Ball)
end
-- a beam-like part from a to b (local positions)
local function rod(parent, name, a, b, w, h, color, material)
	local pa, pb = origin + a, origin + b
	return part(parent, name, Vector3.new(w, h, (pb - pa).Magnitude), CFrame.lookAt((pa + pb) / 2, pb), color, material)
end
local function candle(parent, cf, h)
	part(parent, "Candle", Vector3.new(0.22, h, 0.22), cf * CFrame.new(0, h / 2, 0), BONE, Enum.Material.SmoothPlastic)
	local f = part(parent, "CandleFlame", Vector3.new(0.12, 0.26, 0.12), cf * CFrame.new(0, h + 0.15, 0), FLAME, Enum.Material.Neon)
	light(f, FLAME, 5, 0.6)
end
-- a cut gem: two square pyramids made of a diamond-turned block, glassy neon
local function gemstone(parent, name, s, cf, color)
	return part(parent, name, Vector3.new(s, s * 1.3, s), cf * CFrame.Angles(math.rad(45), math.rad(45), 0), color, Enum.Material.Neon)
end

-- ============================================================
-- Dais
-- ============================================================
solid(m, "DaisBase", Vector3.new(17, 0.5, 26), at(0, 0.25, 0), STONE_DARK, Enum.Material.Cobblestone)
solid(m, "Dais", Vector3.new(15.6, 0.45, 24.6), at(0.4, 0.72, 0), STONE, Enum.Material.Slate)
local TOP = 0.95 -- top of the dais
solid(m, "Step", Vector3.new(1.4, 0.5, 12), at(-9.2, 0.25, 0), STONE, Enum.Material.Slate)
part(m, "StepTrim", Vector3.new(1.42, 0.08, 12.02), at(-9.2, 0.5, 0), GOLD_DARK, Enum.Material.Metal)
-- gold trim round the dais edge
part(m, "DaisTrimFront", Vector3.new(0.16, 0.1, 24.6), at(-7.4, TOP, 0), GOLD, Enum.Material.Metal)
part(m, "DaisTrimL", Vector3.new(15.6, 0.1, 0.16), at(0.4, TOP, -12.3), GOLD, Enum.Material.Metal)
part(m, "DaisTrimR", Vector3.new(15.6, 0.1, 0.16), at(0.4, TOP, 12.3), GOLD, Enum.Material.Metal)
-- the customer's rug in front of the counter, with a gem sigil
part(m, "Rug", Vector3.new(4.6, 0.05, 11), at(-4.6, TOP + 0.02, 0), VELVET, Enum.Material.Fabric)
part(m, "RugBorderF", Vector3.new(0.2, 0.06, 11), at(-6.8, TOP + 0.03, 0), GOLD, Enum.Material.Fabric)
part(m, "RugBorderB", Vector3.new(0.2, 0.06, 11), at(-2.4, TOP + 0.03, 0), GOLD, Enum.Material.Fabric)
part(m, "RugBorderL", Vector3.new(4.6, 0.06, 0.2), at(-4.6, TOP + 0.03, -5.4), GOLD, Enum.Material.Fabric)
part(m, "RugBorderR", Vector3.new(4.6, 0.06, 0.2), at(-4.6, TOP + 0.03, 5.4), GOLD, Enum.Material.Fabric)
part(m, "RugSigil", Vector3.new(1.6, 0.07, 1.6), at(-4.6, TOP + 0.04, 0) * CFrame.Angles(0, math.rad(45), 0), GEM, Enum.Material.Neon)
part(m, "RugSigilInner", Vector3.new(1.1, 0.08, 1.1), at(-4.6, TOP + 0.045, 0) * CFrame.Angles(0, math.rad(45), 0), VELVET_DARK, Enum.Material.Fabric)
for _, z in ipairs({ -4.6, -2.3, 2.3, 4.6 }) do
	part(m, "RugTassel", Vector3.new(0.3, 0.06, 0.3), at(-7.05, TOP + 0.03, z), GOLD, Enum.Material.Fabric)
end

-- ============================================================
-- The gallery wall (back), pointed gable, pillars
-- ============================================================
local WX = 6.6 -- centre of the wall (its front face is at WX - 0.7)
local FACE = WX - 0.7
local WALL_H = 18
solid(m, "GalleryWall", Vector3.new(1.4, WALL_H, 22), at(WX, TOP + WALL_H / 2, 0), STONE_DARK, Enum.Material.Brick)
part(m, "WallPlinth", Vector3.new(1.7, 1.0, 22.2), at(WX - 0.1, TOP + 0.5, 0), STONE, Enum.Material.Slate)
part(m, "WallCornice", Vector3.new(1.8, 0.5, 22.4), at(WX - 0.1, TOP + WALL_H, 0), STONE_LIGHT, Enum.Material.Slate)
part(m, "WallCorniceGold", Vector3.new(1.84, 0.12, 22.44), at(WX - 0.1, TOP + WALL_H - 0.3, 0), GOLD_DARK, Enum.Material.Metal)
-- pointed gable over the centre
local GABLE_H = 4.5
wedge(m, "GableL", Vector3.new(1.4, GABLE_H, 7), at(WX, TOP + WALL_H + 0.25 + GABLE_H / 2, -3.5), STONE_DARK, Enum.Material.Brick)
wedge(m, "GableR", Vector3.new(1.4, GABLE_H, 7), at(WX, TOP + WALL_H + 0.25 + GABLE_H / 2, 3.5) * CFrame.Angles(0, math.pi, 0), STONE_DARK, Enum.Material.Brick)
-- gable rim (gold) and a gem rose window
local gTopY = TOP + WALL_H + 0.25 + GABLE_H
local slope = math.atan2(GABLE_H, 7)
rod(m, "GableRimL", Vector3.new(WX - 0.75, TOP + WALL_H + 0.25, -7), Vector3.new(WX - 0.75, gTopY, 0), 0.12, 0.25, GOLD, Enum.Material.Metal)
rod(m, "GableRimR", Vector3.new(WX - 0.75, TOP + WALL_H + 0.25, 7), Vector3.new(WX - 0.75, gTopY, 0), 0.12, 0.25, GOLD, Enum.Material.Metal)
disc(m, "RoseWindowRim", 1.25, 0.12, at(FACE - 0.04, TOP + WALL_H + 1.8, 0) * CFrame.Angles(0, 0, math.rad(90)), GOLD, Enum.Material.Metal)
disc(m, "RoseWindow", 1.05, 0.14, at(FACE - 0.05, TOP + WALL_H + 1.8, 0) * CFrame.Angles(0, 0, math.rad(90)), GEM_VIOLET, Enum.Material.Neon)
for k = 0, 7 do
	local a = k / 8 * math.pi
	part(m, "RoseSpoke", Vector3.new(0.06, 2.1, 0.08), at(FACE - 0.12, TOP + WALL_H + 1.8, 0) * CFrame.Angles(a, 0, 0), GOLD_DARK, Enum.Material.Metal)
end
light(ball(m, "GableGem", 0.7, at(WX - 0.9, gTopY + 0.3, 0), GEM, Enum.Material.Neon), GEM, 10, 0.8)
part(m, "GableFinial", Vector3.new(0.3, 1.2, 0.3), at(WX - 0.75, gTopY + 0.9, 0), GOLD, Enum.Material.Metal)

-- buttress pillars at the wall's ends and between the portraits
local function pillar(name, x, z, h, finial)
	solid(m, name, Vector3.new(1.6, h, 1.6), at(x, TOP + h / 2, z), STONE, Enum.Material.Slate)
	part(m, name .. "Base", Vector3.new(2.0, 0.7, 2.0), at(x, TOP + 0.35, z), STONE_LIGHT, Enum.Material.Slate)
	part(m, name .. "Capital", Vector3.new(2.0, 0.5, 2.0), at(x, TOP + h - 0.25, z), STONE_LIGHT, Enum.Material.Slate)
	part(m, name .. "Band", Vector3.new(1.66, 0.14, 1.66), at(x, TOP + h * 0.62, z), GOLD_DARK, Enum.Material.Metal)
	if finial then
		part(m, name .. "Cap", Vector3.new(1.2, 0.4, 1.2), at(x, TOP + h + 0.2, z), GOLD_DARK, Enum.Material.Metal)
		ball(m, name .. "Urn", 0.9, at(x, TOP + h + 0.8, z), GOLD, Enum.Material.Metal)
		part(m, name .. "Spike", Vector3.new(0.18, 0.9, 0.18), at(x, TOP + h + 1.6, z), GOLD, Enum.Material.Metal)
	end
end
pillar("WallPillarL", WX - 0.3, -11.6, WALL_H + 1, true)
pillar("WallPillarR", WX - 0.3, 11.6, WALL_H + 1, true)

-- velvet drape behind the merchant (under the featured portrait), gathered at the sides
part(m, "Drape", Vector3.new(0.12, 7.2, 6.4), at(FACE - 0.08, TOP + 4.6, 0), VELVET_DARK, Enum.Material.Fabric)
for _, z in ipairs({ -3.3, 3.3 }) do
	part(m, "DrapeFold", Vector3.new(0.5, 7.4, 0.8), at(FACE - 0.3, TOP + 4.5, z), VELVET, Enum.Material.Fabric)
	part(m, "DrapeTie", Vector3.new(0.6, 0.2, 0.9), at(FACE - 0.3, TOP + 3.6, z), GOLD, Enum.Material.Fabric)
	ball(m, "DrapeTassel", 0.3, at(FACE - 0.62, TOP + 3.3, z), GOLD, Enum.Material.Fabric)
end
part(m, "DrapeRod", Vector3.new(0.16, 0.16, 7.4), at(FACE - 0.3, TOP + 8.3, 0), GOLD, Enum.Material.Metal)
for _, z in ipairs({ -3.75, 3.75 }) do
	ball(m, "DrapeRodEnd", 0.36, at(FACE - 0.3, TOP + 8.3, z), GOLD, Enum.Material.Metal)
end

-- ============================================================
-- Portraits (gilded frames; the canvas and price plate carry the attribute Portrait)
-- ============================================================
local function portrait(index, cf, w, h, grand)
	local frameModel = Instance.new("Model")
	frameModel.Name = "Portrait" .. index
	frameModel.Parent = m
	local canvas = part(frameModel, "Canvas", Vector3.new(0.1, h, w), cf, CANVAS, Enum.Material.SmoothPlastic)
	canvas:SetAttribute("Portrait", index)
	local B = grand and 0.5 or 0.4
	local D = 0.32
	local function edge(name, size, off)
		part(frameModel, name, size, cf * CFrame.new(off), GOLD, Enum.Material.Metal)
	end
	edge("FrameTop", Vector3.new(D, B, w + 2 * B), Vector3.new(-0.08, h / 2 + B / 2, 0))
	edge("FrameBottom", Vector3.new(D, B, w + 2 * B), Vector3.new(-0.08, -h / 2 - B / 2, 0))
	edge("FrameLeft", Vector3.new(D, h, B), Vector3.new(-0.08, 0, -w / 2 - B / 2))
	edge("FrameRight", Vector3.new(D, h, B), Vector3.new(-0.08, 0, w / 2 + B / 2))
	-- inner dark lip and outer bead
	part(frameModel, "FrameLip", Vector3.new(0.12, h + 0.12, w + 0.12), cf * CFrame.new(0.02, 0, 0), GOLD_DARK, Enum.Material.Metal)
	part(frameModel, "FrameBack", Vector3.new(0.14, h + 2 * B + 0.3, w + 2 * B + 0.3), cf * CFrame.new(0.14, 0, 0), WOOD_DARK, Enum.Material.Wood)
	-- corner rosettes
	for _, sy in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			local c = cf * CFrame.new(-0.26, sy * (h / 2 + B / 2), sz * (w / 2 + B / 2))
			ball(frameModel, "Rosette", B * 1.25, c, GOLD, Enum.Material.Metal)
			gemstone(frameModel, "RosetteGem", B * 0.45, c * CFrame.new(-B * 0.5, 0, 0), grand and GEM or GEM_VIOLET)
		end
	end
	-- crest on top: two scrolls and a gem
	local crest = cf * CFrame.new(-0.12, h / 2 + B + 0.45, 0)
	wedge(frameModel, "CrestL", Vector3.new(0.26, 0.9, 1.4), crest * CFrame.new(0, 0, -0.7) * CFrame.Angles(0, math.pi, 0), GOLD, Enum.Material.Metal)
	wedge(frameModel, "CrestR", Vector3.new(0.26, 0.9, 1.4), crest * CFrame.new(0, 0, 0.7), GOLD, Enum.Material.Metal)
	gemstone(frameModel, "CrestGem", grand and 0.6 or 0.42, crest * CFrame.new(-0.25, 0.15, 0), grand and GEM or GEM_VIOLET)
	-- a picture lamp above (warm, the canvas reads in the dark)
	local lampCf = cf * CFrame.new(-0.7, h / 2 + B + 0.05, 0)
	part(frameModel, "LampArm", Vector3.new(0.7, 0.08, 0.08), lampCf * CFrame.new(0.35, 0, 0), GOLD_DARK, Enum.Material.Metal)
	local hood = part(frameModel, "LampHood", Vector3.new(0.3, 0.18, w * 0.55), lampCf, GOLD_DARK, Enum.Material.Metal)
	local bulb = part(frameModel, "LampGlow", Vector3.new(0.12, 0.06, w * 0.5), lampCf * CFrame.new(0, -0.1, 0), FLAME, Enum.Material.Neon)
	local sl = Instance.new("SpotLight")
	sl.Face = Enum.NormalId.Bottom
	sl.Angle = 70
	sl.Range = h + 3
	sl.Brightness = 1.2
	sl.Color = Color3.fromRGB(255, 226, 180)
	sl.Parent = bulb
	return frameModel
end
-- canvases face -X (the customer); BrokerDeals.PORTRAITS: 1 Bundle, 2 Potion, 3 Featured, 4 Curio
local PY = TOP + 11.2
local FEATURED_Y = PY + 1.4 -- raised so the broker's hood never covers it
portrait(3, at(FACE - 0.06, FEATURED_Y, 0), 4.6, 5.6, true) -- Featured, the big centre frame
portrait(1, at(FACE - 0.06, PY - 0.4, -7.4), 3.4, 4.2) -- Bundle, the customer's left
portrait(2, at(FACE - 0.06, PY - 0.4, 7.4), 3.4, 4.2) -- Potion, the customer's right

-- ============================================================
-- Shelves on the wall either side of the drape: potions, gems, ledgers
-- ============================================================
local bottleColors = { POTION, GEM, GEM_VIOLET, Color3.fromRGB(255, 120, 150), POTION }
for _, side in ipairs({ -1, 1 }) do
	for row = 0, 2 do
		local y = TOP + 1.8 + row * 1.9
		local zc = side * 7.4
		part(m, "Shelf", Vector3.new(1.0, 0.16, 5.2), at(FACE - 0.5, y, zc), WOOD, Enum.Material.Wood)
		part(m, "ShelfEdge", Vector3.new(0.06, 0.1, 5.22), at(FACE - 1.0, y + 0.02, zc), GOLD_DARK, Enum.Material.Metal)
		for _, dz in ipairs({ -2.4, 2.4 }) do
			wedge(m, "ShelfBracket", Vector3.new(0.1, 0.5, 0.7), at(FACE - 0.35, y - 0.33, zc + dz) * CFrame.Angles(0, math.rad(90), math.rad(180)), GOLD_DARK, Enum.Material.Metal)
		end
		for k = 0, 4 do
			local z = zc - 2.0 + k * 1.0
			local kind = (row + k + (side > 0 and 1 or 0)) % 3
			if kind == 0 then
				-- a potion bottle: glass body, neck, cork, glowing liquid
				local c = bottleColors[(k + row) % #bottleColors + 1]
				local bh = 0.5 + ((k * 7 + row * 3) % 3) * 0.12
				local b = part(m, "Bottle", Vector3.new(bh, 0.42, 0.42), at(FACE - 0.55, y + 0.08 + bh / 2, z) * UPRIGHT, c, Enum.Material.Neon, Enum.PartType.Cylinder)
				b.Transparency = 0.15
				part(m, "BottleNeck", Vector3.new(0.22, 0.14, 0.14), at(FACE - 0.55, y + 0.19 + bh, z) * UPRIGHT, Color3.fromRGB(200, 220, 230), Enum.Material.Glass, Enum.PartType.Cylinder)
				part(m, "Cork", Vector3.new(0.12, 0.16, 0.16), at(FACE - 0.55, y + 0.36 + bh, z) * UPRIGHT, WOOD, Enum.Material.Wood, Enum.PartType.Cylinder)
			elseif kind == 1 then
				gemstone(m, "ShelfGem", 0.3, at(FACE - 0.55, y + 0.36, z), (k % 2 == 0) and GEM or GEM_VIOLET)
				gemstone(m, "ShelfGem", 0.22, at(FACE - 0.45, y + 0.27, z + 0.3), GEM)
			else
				-- stacked ledgers
				part(m, "Ledger", Vector3.new(0.62, 0.16, 0.48), at(FACE - 0.55, y + 0.16, z), VELVET, Enum.Material.Fabric)
				part(m, "Ledger", Vector3.new(0.56, 0.14, 0.44), at(FACE - 0.55, y + 0.31, z) * CFrame.Angles(0, 0.2, 0), WOOD, Enum.Material.Fabric)
				part(m, "LedgerClasp", Vector3.new(0.64, 0.05, 0.08), at(FACE - 0.55, y + 0.39, z) * CFrame.Angles(0, 0.2, 0), GOLD, Enum.Material.Metal)
			end
		end
	end
end

-- ============================================================
-- Front pillars and the velvet canopy (slopes down from the wall to the front)
-- ============================================================
local FX = -6.6 -- front pillars
local FRONT_H = 15
pillar("FrontPillarL", FX, -11.4, FRONT_H, true)
pillar("FrontPillarR", FX, 11.4, FRONT_H, true)
-- beams: along the front, and from each front pillar back to the wall
part(m, "FrontBeam", Vector3.new(1.0, 0.9, 24), at(FX, TOP + FRONT_H - 0.2, 0), WOOD_DARK, Enum.Material.Wood)
part(m, "FrontBeamGold", Vector3.new(1.04, 0.12, 24.04), at(FX, TOP + FRONT_H - 0.55, 0), GOLD_DARK, Enum.Material.Metal)
local BACK_Y = TOP + WALL_H - 0.6
for _, z in ipairs({ -11.4, -3.8, 3.8, 11.4 }) do
	rod(m, "RoofBeam", Vector3.new(FX, TOP + FRONT_H + 0.4, z), Vector3.new(FACE, BACK_Y, z), 0.5, 0.6, WOOD_DARK, Enum.Material.Wood)
end
-- the canopy cloth: striped violet panels laid on the beams
do
	local a = Vector3.new(FX - 0.6, TOP + FRONT_H + 0.75, 0)
	local b = Vector3.new(FACE, BACK_Y + 0.35, 0)
	local len = (b - a).Magnitude
	local mid = (a + b) / 2
	local look = CFrame.lookAt(origin + mid, origin + mid + Vector3.new(0, 0, 1), (b - a).Unit:Cross(Vector3.zAxis) * -1)
	local stripes = 8
	for k = 0, stripes - 1 do
		local z = -12.3 + (k + 0.5) * (24.6 / stripes)
		local c = CFrame.new(origin + mid + Vector3.new(0, 0, z)) * CFrame.fromMatrix(Vector3.zero, (b - a).Unit, (b - a).Unit:Cross(Vector3.zAxis) * -1)
		part(m, "Canopy", Vector3.new(len, 0.2, 24.6 / stripes + 0.02), c, (k % 2 == 0) and VELVET or VELVET_DARK, Enum.Material.Fabric)
	end
	-- gold seams on the cloth
	for k = 1, stripes - 1 do
		local z = -12.3 + k * (24.6 / stripes)
		local c = CFrame.new(origin + mid + Vector3.new(0, 0.11, z)) * CFrame.fromMatrix(Vector3.zero, (b - a).Unit, (b - a).Unit:Cross(Vector3.zAxis) * -1)
		part(m, "CanopySeam", Vector3.new(len, 0.04, 0.1), c, GOLD_DARK, Enum.Material.Fabric)
	end
end
-- scalloped valance along the front with gold tassels
for k = 0, 15 do
	local z = -11.25 + k * 1.5
	local drop = (k % 2 == 0) and 1.2 or 0.9
	part(m, "Valance", Vector3.new(0.12, drop, 1.46), at(FX - 0.62, TOP + FRONT_H + 0.6 - drop / 2, z), (k % 2 == 0) and VELVET or VELVET_DARK, Enum.Material.Fabric)
	wedge(m, "ValancePoint", Vector3.new(0.12, 0.45, 0.73), at(FX - 0.62, TOP + FRONT_H + 0.6 - drop - 0.22, z - 0.365) * CFrame.Angles(math.pi, 0, 0), (k % 2 == 0) and VELVET or VELVET_DARK, Enum.Material.Fabric)
	wedge(m, "ValancePoint", Vector3.new(0.12, 0.45, 0.73), at(FX - 0.62, TOP + FRONT_H + 0.6 - drop - 0.22, z + 0.365) * CFrame.Angles(math.pi, math.pi, 0), (k % 2 == 0) and VELVET or VELVET_DARK, Enum.Material.Fabric)
	part(m, "ValanceTrim", Vector3.new(0.14, 0.1, 1.5), at(FX - 0.64, TOP + FRONT_H + 0.5, z), GOLD, Enum.Material.Fabric)
	ball(m, "Tassel", 0.22, at(FX - 0.64, TOP + FRONT_H + 0.6 - drop - 0.55, z), GOLD, Enum.Material.Fabric)
end

-- the sign on the front beam
local sign = part(m, "SignBoard", Vector3.new(0.3, 1.5, 9), at(FX - 0.85, TOP + FRONT_H + 1.5, 0), BASALT, Enum.Material.Wood)
sign.CanCollide = false
part(m, "SignFrame", Vector3.new(0.26, 1.8, 9.4), at(FX - 0.78, TOP + FRONT_H + 1.5, 0), GOLD, Enum.Material.Metal)
for _, z in ipairs({ -4.9, 4.9 }) do
	gemstone(m, "SignGem", 0.5, at(FX - 0.95, TOP + FRONT_H + 1.5, z), GEM)
end
do
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Left
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 60
	gui.LightInfluence = 0
	gui.Parent = sign
	local text = Instance.new("TextLabel")
	text.Size = UDim2.new(1, 0, 1, 0)
	text.BackgroundTransparency = 1
	text.Text = "SOUL BROKER"
	text.TextColor3 = GOLD
	text.TextScaled = true
	text.Font = Enum.Font.GothamBlack
	text.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(40, 20, 50)
	stroke.Thickness = 3
	stroke.Parent = text
end

-- banners on the front pillars: velvet with a gold-trimmed gem emblem
for _, z in ipairs({ -11.4, 11.4 }) do
	local bx = FX - 0.86
	part(m, "Banner", Vector3.new(0.1, 5.2, 1.4), at(bx, TOP + 6.4, z), VELVET, Enum.Material.Fabric)
	part(m, "BannerTrimL", Vector3.new(0.12, 5.2, 0.1), at(bx - 0.01, TOP + 6.4, z - 0.68), GOLD, Enum.Material.Fabric)
	part(m, "BannerTrimR", Vector3.new(0.12, 5.2, 0.1), at(bx - 0.01, TOP + 6.4, z + 0.68), GOLD, Enum.Material.Fabric)
	wedge(m, "BannerTail", Vector3.new(0.1, 0.7, 0.7), at(bx, TOP + 3.45, z - 0.35) * CFrame.Angles(math.pi, 0, 0), VELVET, Enum.Material.Fabric)
	wedge(m, "BannerTail", Vector3.new(0.1, 0.7, 0.7), at(bx, TOP + 3.45, z + 0.35) * CFrame.Angles(math.pi, math.pi, 0), VELVET, Enum.Material.Fabric)
	part(m, "BannerRod", Vector3.new(0.12, 0.12, 1.8), at(bx, TOP + 9.05, z), GOLD, Enum.Material.Metal)
	part(m, "BannerEmblem", Vector3.new(0.12, 0.9, 0.9), at(bx - 0.03, TOP + 7.2, z) * CFrame.Angles(math.rad(45), 0, 0), GOLD, Enum.Material.Metal)
	part(m, "BannerEmblemGem", Vector3.new(0.14, 0.55, 0.55), at(bx - 0.05, TOP + 7.2, z) * CFrame.Angles(math.rad(45), 0, 0), GEM, Enum.Material.Neon)
end

-- hanging soul lanterns under the front beam
local function lantern(cf, color)
	part(m, "LanternChain", Vector3.new(0.06, 1.2, 0.06), cf * CFrame.new(0, 1.15, 0), IRON, Enum.Material.Metal)
	part(m, "LanternCap", Vector3.new(0.7, 0.18, 0.7), cf * CFrame.new(0, 0.5, 0), GOLD_DARK, Enum.Material.Metal)
	wedge(m, "LanternRoof", Vector3.new(0.7, 0.3, 0.35), cf * CFrame.new(0, 0.74, -0.175), GOLD_DARK, Enum.Material.Metal)
	wedge(m, "LanternRoof", Vector3.new(0.7, 0.3, 0.35), cf * CFrame.new(0, 0.74, 0.175) * CFrame.Angles(0, math.pi, 0), GOLD_DARK, Enum.Material.Metal)
	part(m, "LanternBase", Vector3.new(0.6, 0.14, 0.6), cf * CFrame.new(0, -0.5, 0), GOLD_DARK, Enum.Material.Metal)
	for _, o in ipairs({ Vector3.new(0.27, 0, 0.27), Vector3.new(-0.27, 0, 0.27), Vector3.new(0.27, 0, -0.27), Vector3.new(-0.27, 0, -0.27) }) do
		part(m, "LanternBar", Vector3.new(0.06, 0.95, 0.06), cf * CFrame.new(o), IRON, Enum.Material.Metal)
	end
	local glass = part(m, "LanternGlass", Vector3.new(0.46, 0.8, 0.46), cf, color, Enum.Material.Glass)
	glass.Transparency = 0.45
	local core = ball(m, "LanternSoul", 0.34, cf, color, Enum.Material.Neon)
	light(core, color, 12, 1)
end
for _, z in ipairs({ -10.0, 10.0 }) do -- by the pillars: anything hanging further in sits in front of a portrait
	lantern(at(FX + 0.2, TOP + FRONT_H - 2.4, z), math.abs(z) < 5 and GEM or GEM_VIOLET)
end

-- ============================================================
-- The counter
-- ============================================================
local CX, CW, CH, CD = -1.6, 13, 3.2, 2.2 -- centre x, length (z), height, depth
solid(m, "Counter", Vector3.new(CD, CH, CW), at(CX, TOP + CH / 2, 0), WOOD_DARK, Enum.Material.Wood)
part(m, "CounterTop", Vector3.new(CD + 0.5, 0.24, CW + 0.5), at(CX, TOP + CH + 0.12, 0), VELVET_DARK, Enum.Material.Fabric)
part(m, "CounterTopEdge", Vector3.new(CD + 0.56, 0.1, CW + 0.56), at(CX, TOP + CH + 0.02, 0), GOLD, Enum.Material.Metal)
part(m, "CounterFoot", Vector3.new(CD + 0.3, 0.35, CW + 0.3), at(CX, TOP + 0.17, 0), BASALT, Enum.Material.Slate)
-- carved front panels with gold mouldings and a gem in each
local FRONTF = CX - CD / 2
for k = -2, 2 do
	local z = k * 2.5
	part(m, "CounterPanel", Vector3.new(0.1, 2.0, 2.0), at(FRONTF - 0.05, TOP + 1.65, z), WOOD, Enum.Material.Wood)
	part(m, "PanelMouldT", Vector3.new(0.12, 0.1, 2.1), at(FRONTF - 0.08, TOP + 2.7, z), GOLD_DARK, Enum.Material.Metal)
	part(m, "PanelMouldB", Vector3.new(0.12, 0.1, 2.1), at(FRONTF - 0.08, TOP + 0.6, z), GOLD_DARK, Enum.Material.Metal)
	part(m, "PanelMouldL", Vector3.new(0.12, 2.1, 0.1), at(FRONTF - 0.08, TOP + 1.65, z - 1.05), GOLD_DARK, Enum.Material.Metal)
	part(m, "PanelMouldR", Vector3.new(0.12, 2.1, 0.1), at(FRONTF - 0.08, TOP + 1.65, z + 1.05), GOLD_DARK, Enum.Material.Metal)
	part(m, "PanelDiamond", Vector3.new(0.12, 0.8, 0.8), at(FRONTF - 0.1, TOP + 1.65, z) * CFrame.Angles(math.rad(45), 0, 0), GOLD, Enum.Material.Metal)
	part(m, "PanelGem", Vector3.new(0.16, 0.42, 0.42), at(FRONTF - 0.13, TOP + 1.65, z) * CFrame.Angles(math.rad(45), 0, 0), k == 0 and GEM or GEM_VIOLET, Enum.Material.Neon)
end
-- counter ends: scrolled gold corbels
for _, s in ipairs({ -1, 1 }) do
	part(m, "CounterEnd", Vector3.new(CD + 0.2, CH, 0.3), at(CX, TOP + CH / 2, s * (CW / 2 + 0.1)), WOOD, Enum.Material.Wood)
	ball(m, "CorbelBall", 0.5, at(FRONTF - 0.2, TOP + CH - 0.3, s * (CW / 2 + 0.1)), GOLD, Enum.Material.Metal)
end
local CT = TOP + CH + 0.24 -- counter top surface

-- on the counter: the brass soul scale, an open ledger, gem piles, coins, potions, candles
do
	local sz = -4.4
	part(m, "ScaleBase", Vector3.new(0.9, 0.16, 0.9), at(CX, CT + 0.08, sz), GOLD_DARK, Enum.Material.Metal)
	part(m, "ScalePost", Vector3.new(0.12, 1.6, 0.12), at(CX, CT + 0.9, sz), GOLD, Enum.Material.Metal)
	part(m, "ScaleBeam", Vector3.new(0.1, 0.1, 1.9), at(CX, CT + 1.7, sz) * CFrame.Angles(0.12, 0, 0), GOLD, Enum.Material.Metal)
	gemstone(m, "ScaleTopGem", 0.22, at(CX, CT + 1.86, sz), GEM)
	for _, s in ipairs({ -1, 1 }) do
		local py = CT + 1.7 - s * 0.11 - 0.7
		part(m, "ScaleString", Vector3.new(0.03, 0.7, 0.03), at(CX, py + 0.35, sz + s * 0.92), GOLD_DARK, Enum.Material.Metal)
		disc(m, "ScalePan", 0.36, 0.06, at(CX, py, sz + s * 0.92), GOLD, Enum.Material.Metal)
	end
	gemstone(m, "ScaleGem", 0.2, at(CX, CT + 0.95 + 0.11, sz - 0.92), GEM)
	ball(m, "ScaleSoul", 0.22, at(CX, CT + 1.18 - 0.11, sz + 0.92), Color3.fromRGB(200, 240, 255), Enum.Material.Neon)
	-- the open ledger with a quill
	part(m, "LedgerOpenL", Vector3.new(0.9, 0.08, 0.7), at(CX - 0.1, CT + 0.06, -2.2) * CFrame.Angles(0.08, 0, 0), BONE, Enum.Material.SmoothPlastic)
	part(m, "LedgerOpenR", Vector3.new(0.9, 0.08, 0.7), at(CX - 0.1, CT + 0.06, -1.5) * CFrame.Angles(-0.08, 0, 0), BONE, Enum.Material.SmoothPlastic)
	part(m, "LedgerCover", Vector3.new(0.98, 0.05, 1.5), at(CX - 0.1, CT + 0.02, -1.85), VELVET, Enum.Material.Fabric)
	for i = 0, 3 do
		part(m, "LedgerLine", Vector3.new(0.6, 0.02, 0.04), at(CX - 0.1, CT + 0.11, -2.4 + i * 0.12), Color3.fromRGB(60, 50, 60), Enum.Material.SmoothPlastic)
	end
	part(m, "Quill", Vector3.new(0.05, 0.05, 1.0), at(CX - 0.2, CT + 0.35, -1.3) * CFrame.Angles(0.6, 0.4, 0), Color3.fromRGB(240, 240, 250), Enum.Material.SmoothPlastic)
	part(m, "Inkwell", Vector3.new(0.22, 0.3, 0.3), at(CX + 0.3, CT + 0.11, -1.0) * UPRIGHT, BASALT, Enum.Material.Glass, Enum.PartType.Cylinder)
	-- gem piles and coin stacks
	local rng = Random.new(7)
	for i = 1, 12 do
		local z = 2.6 + rng:NextNumber(-0.6, 0.6)
		local x = CX + rng:NextNumber(-0.6, 0.6)
		gemstone(m, "PileGem", rng:NextNumber(0.16, 0.3), at(x, CT + 0.12 + rng:NextNumber(0, 0.25), z) * CFrame.Angles(rng:NextNumber(0, 1), rng:NextNumber(0, 6), 0), (i % 3 == 0) and GEM_VIOLET or GEM)
	end
	for i = 0, 2 do
		local h = 0.2 + i * 0.12
		disc(m, "CoinStack", 0.2, h, at(CX + 0.5, CT + h / 2, 3.6 + i * 0.4), GOLD, Enum.Material.Metal)
	end
	for i = 0, 2 do
		local z = 4.6 + i * 0.5
		local b = part(m, "CounterPotion", Vector3.new(0.6, 0.38, 0.38), at(CX - 0.2, CT + 0.3, z) * UPRIGHT, POTION, Enum.Material.Neon, Enum.PartType.Cylinder)
		b.Transparency = 0.15
		part(m, "CounterPotionNeck", Vector3.new(0.2, 0.14, 0.14), at(CX - 0.2, CT + 0.7, z) * UPRIGHT, Color3.fromRGB(200, 220, 230), Enum.Material.Glass, Enum.PartType.Cylinder)
		part(m, "CounterPotionCork", Vector3.new(0.12, 0.16, 0.16), at(CX - 0.2, CT + 0.86, z) * UPRIGHT, WOOD, Enum.Material.Wood, Enum.PartType.Cylinder)
	end
	for _, z in ipairs({ -6.0, 6.0 }) do
		part(m, "CandleDish", Vector3.new(0.5, 0.08, 0.5), at(CX, CT + 0.04, z), GOLD_DARK, Enum.Material.Metal)
		candle(m, at(CX, CT + 0.08, z), 0.9)
		candle(m, at(CX + 0.25, CT + 0.08, z + 0.2), 0.6)
	end
end

-- ============================================================
-- The broker: a tall hooded figure behind the counter, void face, cyan eyes, skeletal hands on the counter
-- ============================================================
do
	local bx = 1.6
	local b = Instance.new("Model")
	b.Name = "Broker"
	b.Parent = m
	-- a simple rig for the client's BrokerKeeper (it walks him round the stall): Root at his feet, the Head and the two
	-- arms are sub-models turning round their attribute Pivot (a position relative to Root); everything else is the body
	local root = part(b, "Root", Vector3.new(1, 1, 1), at(bx, TOP, 0), BONE)
	root.Transparency = 1
	b.PrimaryPart = root
	local head = Instance.new("Model")
	head.Name = "Head"
	head:SetAttribute("Pivot", Vector3.new(0, 7.0, 0)) -- the neck
	head.Parent = b
	-- a round tube from a to b (local positions); Roblox cylinders run along X
	local function tube(parent, name, a, b2, radius, color, material)
		local pa, pb = origin + a, origin + b2
		return part(parent, name, Vector3.new((pb - pa).Magnitude, radius * 2, radius * 2),
			CFrame.lookAt((pa + pb) / 2, pb) * CFrame.Angles(0, math.rad(90), 0), color, material, Enum.PartType.Cylinder)
	end
	-- the robe: tapering tiers with a gold hem and a belt, soft vertical folds
	disc(b, "RobeHem", 2.0, 0.3, at(bx, TOP + 0.15, 0), VELVET_DARK, Enum.Material.Fabric)
	disc(b, "RobeHemTrim", 2.03, 0.08, at(bx, TOP + 0.34, 0), GOLD_DARK, Enum.Material.Metal)
	disc(b, "RobeLow", 1.82, 1.9, at(bx, TOP + 1.25, 0), VELVET_DARK, Enum.Material.Fabric)
	disc(b, "RobeKnee", 1.66, 1.7, at(bx, TOP + 2.95, 0), VELVET_DARK, Enum.Material.Fabric)
	disc(b, "RobeWaist", 1.46, 1.5, at(bx, TOP + 4.45, 0), VELVET, Enum.Material.Fabric)
	for k = 0, 11 do
		local a = k / 12 * 2 * math.pi
		tube(b, "RobeFold", Vector3.new(bx + math.cos(a) * 1.74, TOP + 0.35, math.sin(a) * 1.74),
			Vector3.new(bx + math.cos(a) * 1.5, TOP + 3.9, math.sin(a) * 1.5), 0.16, VELVET, Enum.Material.Fabric)
	end
	disc(b, "Belt", 1.5, 0.22, at(bx, TOP + 4.55, 0), GOLD_DARK, Enum.Material.Metal)
	gemstone(b, "BeltGem", 0.3, at(bx - 1.5, TOP + 4.55, 0), GEM_VIOLET)
	-- chest and shoulders: round, a capelet with a beaded gold edge
	disc(b, "Torso", 1.3, 1.6, at(bx, TOP + 5.4, 0), VELVET, Enum.Material.Fabric)
	ball(b, "Chest", 2.7, at(bx, TOP + 5.8, 0), VELVET, Enum.Material.Fabric)
	tube(b, "ShoulderRoll", Vector3.new(bx, TOP + 6.85, -1.7), Vector3.new(bx, TOP + 6.85, 1.7), 0.7, VELVET_DARK, Enum.Material.Fabric)
	for _, s2 in ipairs({ -1, 1 }) do
		ball(b, "Shoulder", 1.45, at(bx, TOP + 6.85, s2 * 1.75), VELVET_DARK, Enum.Material.Fabric)
	end
	disc(b, "Capelet", 1.95, 0.24, at(bx, TOP + 7.1, 0), VELVET_DARK, Enum.Material.Fabric)
	disc(b, "CapeletDrop", 1.75, 0.5, at(bx, TOP + 6.8, 0), VELVET_DARK, Enum.Material.Fabric)
	for k = 0, 17 do
		local a = k / 18 * 2 * math.pi
		ball(b, "CapeletBead", 0.2, at(bx + math.cos(a) * 1.96, TOP + 6.98, math.sin(a) * 1.96), GOLD, Enum.Material.Metal)
	end
	-- gold-trimmed mantle opening and a hanging gem amulet
	part(b, "MantleTrimL", Vector3.new(0.08, 2.6, 0.16), at(bx - 0.97, TOP + 5.7, -0.35) * CFrame.Angles(0.12, 0, 0), GOLD, Enum.Material.Metal)
	part(b, "MantleTrimR", Vector3.new(0.08, 2.6, 0.16), at(bx - 0.97, TOP + 5.7, 0.35) * CFrame.Angles(-0.12, 0, 0), GOLD, Enum.Material.Metal)
	for i = 0, 5 do
		local t = i / 5
		ball(b, "ChainLink", 0.12, at(bx - 1.0, TOP + 6.9 - t * 0.9, -0.55 + t * 0.55), GOLD, Enum.Material.Metal)
		ball(b, "ChainLink", 0.12, at(bx - 1.0, TOP + 6.9 - t * 0.9, 0.55 - t * 0.55), GOLD, Enum.Material.Metal)
	end
	part(b, "AmuletSetting", Vector3.new(0.12, 0.6, 0.6), at(bx - 1.02, TOP + 5.85, 0) * CFrame.Angles(math.rad(45), 0, 0), GOLD, Enum.Material.Metal)
	local amulet = part(b, "Amulet", Vector3.new(0.16, 0.38, 0.38), at(bx - 1.06, TOP + 5.85, 0) * CFrame.Angles(math.rad(45), 0, 0), GEM, Enum.Material.Neon)
	light(amulet, GEM, 6, 0.8)
	-- the hood: a deep cowl with a black void where the face should be
	ball(head, "Hood", 2.6, at(bx + 0.1, TOP + 8.0, 0), VELVET_DARK, Enum.Material.Fabric)
	ball(head, "HoodBack", 2.2, at(bx + 0.55, TOP + 7.3, 0), VELVET_DARK, Enum.Material.Fabric)
	-- a droopy pointed tip falling back
	ball(head, "HoodTip", 1.5, at(bx + 0.75, TOP + 8.85, 0), VELVET_DARK, Enum.Material.Fabric)
	ball(head, "HoodTip", 1.0, at(bx + 1.25, TOP + 9.15, 0), VELVET_DARK, Enum.Material.Fabric)
	ball(head, "HoodTip", 0.6, at(bx + 1.65, TOP + 9.1, 0), VELVET_DARK, Enum.Material.Fabric)
	ball(head, "HoodTip", 0.34, at(bx + 1.92, TOP + 8.92, 0), GOLD, Enum.Material.Metal)
	-- a soft ring of fabric round the face opening
	for k = 0, 13 do
		local a = k / 14 * 2 * math.pi
		ball(head, "HoodRim", 0.62, at(bx - 0.95, TOP + 7.9 + math.cos(a) * 1.0, math.sin(a) * 0.95), VELVET, Enum.Material.Fabric)
	end
	ball(head, "Void", 1.75, at(bx - 0.45, TOP + 7.85, 0), Color3.fromRGB(4, 2, 8), Enum.Material.SmoothPlastic)
	for _, s in ipairs({ -1, 1 }) do
		local eye = ball(head, "Eye", 0.24, at(bx - 1.25, TOP + 8.0, s * 0.32), GEM, Enum.Material.Neon)
		if s == 1 then light(eye, GEM, 5, 1) end
	end
	-- sleeves from the shoulders down to the counter, skeletal hands resting on it
	for _, s in ipairs({ -1, 1 }) do
		local sh = Vector3.new(bx - 0.2, TOP + 6.6, s * 1.8)
		local el = Vector3.new(bx - 0.6, TOP + 4.6, s * 2.0)
		local wr = Vector3.new(CX + 0.35, CT + 0.35, s * 1.5)
		local arm = Instance.new("Model")
		arm.Name = s < 0 and "ArmL" or "ArmR"
		arm:SetAttribute("Pivot", Vector3.new(sh.X - bx, sh.Y - TOP, sh.Z)) -- the shoulder
		arm:SetAttribute("Side", s)
		arm.Parent = b
		-- round sleeves with an elbow and a wide bell cuff banded in gold
		local dir = (wr - el).Unit
		tube(arm, "UpperSleeve", sh, el, 0.5, VELVET_DARK, Enum.Material.Fabric)
		ball(arm, "Elbow", 1.0, at(el.X, el.Y, el.Z), VELVET_DARK, Enum.Material.Fabric)
		tube(arm, "LowerSleeve", el, wr - dir * 0.5, 0.48, VELVET, Enum.Material.Fabric)
		tube(arm, "SleeveBell", wr - dir * 0.6, wr, 0.68, VELVET, Enum.Material.Fabric)
		tube(arm, "Cuff", wr - dir * 0.08, wr + dir * 0.04, 0.72, GOLD_DARK, Enum.Material.Metal)
		-- hand: palm and four long fingers drumming the counter, a thumb
		local palm = Vector3.new(CX - 0.05, CT + 0.12, s * 1.45)
		part(arm, "Palm", Vector3.new(0.55, 0.14, 0.5), at(palm.X, palm.Y, palm.Z), BONE, Enum.Material.SmoothPlastic)
		for f = 0, 3 do
			local fz = palm.Z - 0.18 + f * 0.12
			local len = 0.42 + ((f == 1 or f == 2) and 0.08 or 0)
			rod(arm, "Finger", Vector3.new(palm.X - 0.25, palm.Y, fz), Vector3.new(palm.X - 0.25 - len, CT + 0.05, fz), 0.07, 0.07, BONE, Enum.Material.SmoothPlastic)
		end
		rod(arm, "Thumb", Vector3.new(palm.X - 0.1, palm.Y, palm.Z - s * 0.25), Vector3.new(palm.X - 0.35, CT + 0.05, palm.Z - s * 0.5), 0.08, 0.08, BONE, Enum.Material.SmoothPlastic)
		-- a ring on one finger
		if s == 1 then gemstone(arm, "Ring", 0.12, at(palm.X - 0.45, palm.Y + 0.05, palm.Z - 0.06), GEM_VIOLET) end
	end
end

-- ============================================================
-- The Curio portrait on an easel, front right of the counter, turned toward the customer
-- ============================================================
do
	local ex, ez = -2.3, 9.4 -- front right, beside the counter end: the Gem Shop's stall view sees this side (its panel covers the right of the screen)
	local turn = CFrame.Angles(0, math.rad(34), 0) -- faces -X, turned toward the stall's centre line
	local base = at(ex, TOP, ez) * turn
	local lean = CFrame.Angles(0, 0, math.rad(-10)) -- the canvas leans back (top toward +X)
	for _, dz in ipairs({ -1.1, 1.1 }) do
		part(m, "EaselLeg", Vector3.new(0.18, 6.0, 0.18), base * CFrame.new(-0.2, 3.0, dz) * lean, WOOD, Enum.Material.Wood)
	end
	part(m, "EaselBackLeg", Vector3.new(0.16, 6.0, 0.16), base * CFrame.new(1.0, 2.9, 0) * CFrame.Angles(0, 0, math.rad(14)), WOOD, Enum.Material.Wood)
	part(m, "EaselLedge", Vector3.new(0.5, 0.16, 2.8), base * CFrame.new(-0.55, 1.75, 0), WOOD, Enum.Material.Wood)
	part(m, "EaselTop", Vector3.new(0.2, 0.2, 2.6), base * CFrame.new(0.25, 5.9, 0), WOOD, Enum.Material.Wood)
	portrait(4, base * CFrame.new(-0.25, 3.75, 0) * lean, 2.6, 3.0)
	-- a velvet cloth draped over the easel's top corner
	part(m, "EaselCloth", Vector3.new(0.1, 1.6, 0.9), base * CFrame.new(-0.05, 5.2, -1.25) * CFrame.Angles(-0.3, 0, 0), VELVET, Enum.Material.Fabric)
end

-- ============================================================
-- Gem chests, a candelabra, floating gems
-- ============================================================
local function chest(cf, scale)
	local s = scale
	part(m, "Chest", Vector3.new(1.4 * s, 1.0 * s, 2.2 * s), cf * CFrame.new(0, 0.5 * s, 0), WOOD, Enum.Material.Wood)
	for _, dz in ipairs({ -0.75, 0, 0.75 }) do
		part(m, "ChestBand", Vector3.new(1.44 * s, 1.04 * s, 0.14 * s), cf * CFrame.new(0, 0.5 * s, dz * s), GOLD_DARK, Enum.Material.Metal)
	end
	part(m, "ChestLock", Vector3.new(0.1, 0.3 * s, 0.26 * s), cf * CFrame.new(-0.74 * s, 0.75 * s, 0), GOLD, Enum.Material.Metal)
	-- open lid, tipped back
	part(m, "ChestLid", Vector3.new(0.16 * s, 1.1 * s, 2.2 * s), cf * CFrame.new(0.78 * s, 1.45 * s, 0) * CFrame.Angles(0, 0, math.rad(-12)), WOOD, Enum.Material.Wood)
	local rng = Random.new(math.floor(cf.Position.Z * 10))
	for i = 1, 14 do
		local p = cf * CFrame.new(rng:NextNumber(-0.5, 0.5) * s, (1.0 + rng:NextNumber(0, 0.35)) * s, rng:NextNumber(-0.9, 0.9) * s)
		gemstone(m, "ChestGem", rng:NextNumber(0.2, 0.34) * s, p * CFrame.Angles(rng:NextNumber(0, 1), rng:NextNumber(0, 6), 0), (i % 4 == 0) and GEM_VIOLET or GEM)
	end
	local glow = part(m, "ChestGlow", Vector3.new(1.2 * s, 0.1, 2.0 * s), cf * CFrame.new(0, 1.0 * s, 0), GEM, Enum.Material.Neon)
	glow.Transparency = 0.3
	light(glow, GEM, 8, 0.7)
	-- a few spilled gems on the floor
	for i = 1, 4 do
		gemstone(m, "SpilledGem", 0.2, cf * CFrame.new(-1.0 * s - rng:NextNumber(0, 0.6), 0.12, rng:NextNumber(-0.9, 0.9) * s), GEM)
	end
end
chest(at(-4.6, TOP, -9.2) * CFrame.Angles(0, math.rad(-20), 0), 1.0) -- (front left)
chest(at(-2.8, TOP, -10.8) * CFrame.Angles(0, math.rad(10), 0), 0.75)
-- stacked crates of bottles behind the right chest
part(m, "Crate", Vector3.new(1.6, 1.4, 1.6), at(-0.6, TOP + 0.7, -10.6), WOOD_DARK, Enum.Material.WoodPlanks)
part(m, "Crate", Vector3.new(1.2, 1.0, 1.2), at(-0.6, TOP + 1.9, -10.5) * CFrame.Angles(0, -0.3, 0), WOOD_DARK, Enum.Material.WoodPlanks)
for i = 0, 2 do
	local b = part(m, "CrateBottle", Vector3.new(0.5, 0.3, 0.3), at(-0.9 + i * 0.3, TOP + 1.65, -10.1) * UPRIGHT, bottleColors[i + 1], Enum.Material.Neon, Enum.PartType.Cylinder)
	b.Transparency = 0.15
end

-- tall candelabras by the counter ends
for _, z in ipairs({ -7.6, 7.6 }) do
	local cb = at(-3.4, TOP, z)
	disc(m, "CandelabraFoot", 0.45, 0.2, cb * CFrame.new(0, 0.1, 0), GOLD_DARK, Enum.Material.Metal)
	part(m, "CandelabraStem", Vector3.new(0.14, 4.2, 0.14), cb * CFrame.new(0, 2.2, 0), GOLD_DARK, Enum.Material.Metal)
	part(m, "CandelabraArms", Vector3.new(0.1, 0.1, 1.6), cb * CFrame.new(0, 4.1, 0), GOLD_DARK, Enum.Material.Metal)
	for _, dz in ipairs({ -0.8, 0, 0.8 }) do
		part(m, "CandelabraCup", Vector3.new(0.3, 0.12, 0.3), cb * CFrame.new(0, 4.2 + (dz == 0 and 0.35 or 0), dz), GOLD, Enum.Material.Metal)
		candle(m, cb * CFrame.new(0, 4.26 + (dz == 0 and 0.35 or 0), dz), 0.7)
	end
end

-- floating gems circling above the chests and in front of the gallery (SpinFx models turned by the client's WorldFx)
local function orbit(name, center, radius, count, speed, size)
	local om = Instance.new("Model")
	om.Name = name
	local hub = part(om, "Hub", Vector3.new(0.2, 0.2, 0.2), center, GEM, Enum.Material.SmoothPlastic)
	hub.Transparency = 1
	om.PrimaryPart = hub
	for k = 0, count - 1 do
		local a = k / count * 2 * math.pi
		local g = gemstone(om, "OrbitGem", size, center * CFrame.Angles(0, a, 0) * CFrame.new(0, math.sin(a * 2) * 0.25, -radius), (k % 2 == 0) and GEM or GEM_VIOLET)
		if k == 0 then light(g, GEM, 6, 0.5) end
	end
	om:SetAttribute("SpinSpeed", speed)
	om.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	CollectionService:AddTag(om, "SpinFx")
	om.Parent = m
end
orbit("GemOrbitChest", at(-4.6, TOP + 2.9, -9.2), 1.1, 5, 0.6, 0.26)
orbit("GemOrbitGallery", at(FACE - 0.9, FEATURED_Y, 0) * CFrame.Angles(0, 0, math.rad(90)), 4.2, 10, -0.18, 0.3) -- upright ring round the Featured frame (its up axis faces the customer)

-- ============================================================
-- Place it on the plaza (local +X points away from the monument) and set the interaction anchor
-- ============================================================
m.ModelStreamingMode = Enum.ModelStreamingMode.Persistent -- always loaded: the portraits are painted on it
m.Parent = decor
local dir = Vector3.new(math.sin(math.rad(DEG)), 0, -math.cos(math.rad(DEG)))
local pos = dir * RADIUS
local cf = CFrame.fromMatrix(Vector3.new(pos.X, floorTop, pos.Z), dir, Vector3.yAxis)
m:PivotTo(cf)

local anchor = shops:FindFirstChild("SoulBroker")
if not anchor then
	anchor = Instance.new("Part")
	anchor.Name = "SoulBroker"
	anchor.Parent = shops
end
anchor.Anchored = true
anchor.CanCollide = false
anchor.Transparency = 1
anchor.Size = Vector3.new(2.4, 1, 6)
anchor.CFrame = cf * CFrame.new(CX - 0.4, TOP + CH + 0.6, 0)
if not anchor:FindFirstChildOfClass("ProximityPrompt") then
	Instance.new("ProximityPrompt").Parent = anchor
end

local count = 0
for _, d in ipairs(m:GetDescendants()) do
	if d:IsA("BasePart") then count += 1 end
end
return "soul broker stall built: " .. count .. " parts"
