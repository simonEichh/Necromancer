-- Builds The Absolution, Malak's warship (docs/envoy.md, Fleet Strike), into ReplicatedStorage.ShipModels.Absolution.
-- Run in Edit mode (Studio MCP execute_luau or loadstring from the tools/studio http server).
-- After the concept art (Images/Concept/Unit/Die Absolution – gotisches Ringschlachtschiff.png). Built out of Malak's
-- own visual language at warship scale (~355 studs long):
--   * the BOW is his faceless helmet: two great slanted halves meeting in a vertical front edge with ONE slit of cold
--     light down it, a pointed chin; the halves sit on hinges (BowL / BowR) so the main cannon (joint Cannon, hidden
--     inside) can open out of the slit later
--   * behind it a tall upswept CREST of blades, like his high collar
--   * a long hull whose UNDERSIDE carries X-shaped chevron plates with turrets (his chest chevrons); turrets on the
--     spine too; every turret turns on its own joint (Turret1..)
--   * AMIDSHIPS the hull opens round a glowing core inside a giant ARMILLARY, like his drone: a big ring square to the
--     hull (RingA, turns round the hull's axis), a second one at right angles (RingB) and a smaller tilted inner one
--     (RingC); they can spin up and lock into line for the cannon
--   * the STERN flares into layered blade fins like his coat skirt (silver edges, glowing seam, diamond emblem on
--     each), engines glowing between them
-- Front = -Z, up = +Y, origin = the core. Root part "Root" (PrimaryPart); everything else is welded or on Motor6Ds.
-- Palette: black chrome, silver, cold white-blue light, a hint of violet; no red (that is only for the lasers).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local folder = ReplicatedStorage:FindFirstChild("ShipModels")
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "ShipModels"
	folder.Parent = ReplicatedStorage
end
local NAME = "Absolution"
local old = folder:FindFirstChild(NAME)
if old then
	old:Destroy()
end

local SMOOTH = Enum.Material.SmoothPlastic
local NEON = Enum.Material.Neon
local METAL = Enum.Material.Metal

local CHROME = Color3.fromRGB(28, 28, 36)
local CHROME_LIGHT = Color3.fromRGB(50, 50, 62)
local DARK = Color3.fromRGB(12, 12, 16)
local SILVER = Color3.fromRGB(176, 180, 196)
local SILVER_DARK = Color3.fromRGB(110, 114, 130)
local VIOLET = Color3.fromRGB(44, 30, 74)
local GLOW = Color3.fromRGB(165, 180, 255)
local GLOW_CORE = Color3.fromRGB(235, 240, 255)
local GLOW_DEEP = Color3.fromRGB(96, 104, 230)

local model = Instance.new("Model")
model.Name = NAME

-- ====================================================================
-- Helpers
-- ====================================================================
local function part(name, size, at, color, material, shape)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = typeof(at) == "CFrame" and at or CFrame.new(at)
	p.Color = color
	p.Material = material or SMOOTH
	if shape then
		p.Shape = shape
	end
	if color == CHROME or color == CHROME_LIGHT then
		p.Reflectance = 0.15
	elseif color == SILVER or color == SILVER_DARK then
		p.Reflectance = 0.3
	end
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Massless = true
	p.Anchored = false
	p.Parent = model
	return p
end

local function weld(p0, p1)
	local w = Instance.new("WeldConstraint")
	w.Part0 = p0
	w.Part1 = p1
	w.Parent = p1
end

local function deco(to, name, size, at, color, material, shape)
	local p = part(name, size, at, color, material, shape)
	weld(to, p)
	return p
end

local function glow(to, name, size, at, transparency, color)
	local p = deco(to, name, size, at, color or GLOW, NEON)
	p.Transparency = transparency or 0
	return p
end

-- a box between two points (w x h cross-section; w horizontal when the line is level), welded to `to`
local function bar(to, name, a, b, w, h, color, material)
	local dir = b - a
	local up = math.abs(dir.Unit.Y) > 0.98 and Vector3.new(0, 0, 1) or Vector3.new(0, 1, 0)
	return deco(to, name, Vector3.new(w, h or w, dir.Magnitude), CFrame.lookAt((a + b) / 2, b, up), color, material)
end

local function cyl(to, name, c, axis, length, diameter, color, material)
	local cf
	if math.abs(axis.Unit.Y) > 0.98 then
		cf = CFrame.new(c) * CFrame.Angles(0, 0, math.pi / 2)
	else
		cf = CFrame.lookAt(c, c + axis) * CFrame.Angles(0, math.pi / 2, 0)
	end
	return deco(to, name, Vector3.new(length, diameter, diameter), cf, color, material, Enum.PartType.Cylinder)
end

local function light(p, range, brightness, color)
	local l = Instance.new("PointLight")
	l.Color = color or GLOW
	l.Range = range
	l.Brightness = brightness
	l.Shadows = false
	l.Parent = p
end

-- an invisible hinge part on a Motor6D from `parent`, its frame = cf (animate with Motor6D.Transform)
local function hinge(name, parent, cf)
	local h = part(name .. "Hinge", Vector3.one, cf, CHROME)
	h.Transparency = 1
	local m = Instance.new("Motor6D")
	m.Name = name
	m.Part0 = parent
	m.Part1 = h
	m.C0 = parent.CFrame:Inverse() * cf
	m.C1 = CFrame.new()
	m.Parent = h
	return h
end

-- A blade plate like Malak's coat panels, at ship scale: in the frame `cf` it grows along +Y from the origin and ends
-- in a point at y = L, outer face +Z. Silver edges, a glowing seam down one side and along the point, a diamond emblem,
-- optionally a violet lining on the inner face.
local function blade(to, name, cf, w, L, t, opts)
	opts = opts or {}
	local body = L - w / 2
	local d = w / math.sqrt(2)
	local e = math.max(0.35, w * 0.045)
	deco(to, name, Vector3.new(w, body, t), cf * CFrame.new(0, body / 2, 0), opts.color or CHROME)
	deco(to, name .. "Tip", Vector3.new(d, d, t), cf * CFrame.new(0, body, 0) * CFrame.Angles(0, 0, math.rad(45)), opts.color or CHROME)
	if opts.lining then
		deco(to, name .. "Lining", Vector3.new(w * 0.86, body * 0.95, t * 0.4), cf * CFrame.new(0, body / 2, -t * 0.65), VIOLET)
	end
	for _, s in ipairs({ -1, 1 }) do
		deco(to, name .. "Edge", Vector3.new(e, body, t + e * 0.5), cf * CFrame.new(s * (w / 2 - e / 2), body / 2, 0), SILVER)
		deco(to, name .. "TipEdge", Vector3.new(e, d, t + e * 0.5), cf * CFrame.new(s * w / 4, body + w / 4, 0) * CFrame.Angles(0, 0, s * math.rad(45)), SILVER)
	end
	local side = opts.seamSide or 1
	glow(to, name .. "Seam", Vector3.new(e * 1.6, body * 0.8, 0.3), cf * CFrame.new(side * (w / 2 - e * 3), body * 0.48, t / 2 + 0.1))
	glow(to, name .. "TipSeam", Vector3.new(e * 1.6, d * 0.6, 0.3),
		cf * CFrame.new(side * (w / 4 - e * 2), body + w / 4 - e * 2, t / 2 + 0.1) * CFrame.Angles(0, 0, side * math.rad(45)))
	if opts.emblem ~= false then
		local es = opts.emblemSize or w * 0.22
		local ey = opts.emblemAt or body * 0.62
		deco(to, name .. "Emblem", Vector3.new(es, es, 0.4), cf * CFrame.new(0, ey, t / 2 + 0.15) * CFrame.Angles(0, 0, math.rad(45)), SILVER)
		deco(to, name .. "EmblemInset", Vector3.new(es * 0.7, es * 0.7, 0.4), cf * CFrame.new(0, ey, t / 2 + 0.3) * CFrame.Angles(0, 0, math.rad(45)), CHROME)
		glow(to, name .. "EmblemCore", Vector3.new(es * 0.3, es * 0.3, 0.4), cf * CFrame.new(0, ey, t / 2 + 0.45) * CFrame.Angles(0, 0, math.rad(45)))
	end
end

-- a frame from an outward normal and a growth direction: X = across, Y = grows along `growth`, Z = `outward`
local function frameFrom(pos, growth, outward)
	local y = growth.Unit
	local z = (outward - y * outward:Dot(y)).Unit
	local x = y:Cross(z)
	return CFrame.fromMatrix(pos, x, y, z)
end

-- ====================================================================
-- Root and hull
-- ====================================================================
local root = part("Root", Vector3.new(2, 2, 2), Vector3.zero, CHROME)
root.Transparency = 1
model.PrimaryPart = root

-- the forward hull (bow to the core) and the wider engine hull (core to the stern); the core sits in the gap.
-- Heavy and wide on purpose: it has to read as a warship, not a bird.
local FW, FH = 14, 15 -- fore hull half width / half height
local AW, AH = 21, 18 -- aft hull
deco(root, "ForeHull", Vector3.new(FW * 2, FH * 2, 108), Vector3.new(0, 0, -68), CHROME)
deco(root, "ForeDeck", Vector3.new(FW * 2 - 6, 3, 104), Vector3.new(0, FH + 1.5, -68), CHROME_LIGHT)
deco(root, "ForeKeel", Vector3.new(FW * 2 - 7, 3, 104), Vector3.new(0, -FH - 1.5, -68), CHROME_LIGHT)
deco(root, "AftHull", Vector3.new(AW * 2, AH * 2, 108), Vector3.new(0, 0, 68), CHROME)
deco(root, "AftDeck", Vector3.new(AW * 2 - 8, 3, 100), Vector3.new(0, AH + 1.5, 66), CHROME_LIGHT)
deco(root, "AftKeel", Vector3.new(AW * 2 - 9, 3, 100), Vector3.new(0, -AH - 1.5, 66), CHROME_LIGHT)
-- the collars either side of the core, and the struts that carry the hull through it
for _, z in ipairs({ -14, 14 }) do
	deco(root, "CoreCollar", Vector3.new(36, 36, 4), Vector3.new(0, 0, z), CHROME_LIGHT)
	deco(root, "CoreCollarRim", Vector3.new(38, 38, 1.2), Vector3.new(0, 0, z + (z < 0 and 2.2 or -2.2)), SILVER)
	glow(root, "CoreCollarGlow", Vector3.new(30, 0.8, 0.6), Vector3.new(0, 12, z + (z < 0 and 2.6 or -2.6)), 0.2)
end
for _, x in ipairs({ -1, 1 }) do
	for _, y in ipairs({ -1, 1 }) do
		bar(root, "CoreStrut", Vector3.new(x * 12, y * 12, -14), Vector3.new(x * 12, y * 12, 14), 2, 2, SILVER)
	end
end

-- side detail along both hulls (the scale comes from these): silver rails, rows of small lit windows, heavy sloped
-- belt armour, pipes and vents
local function windowRow(x, y, z0, z1, every, len, transparency)
	local z = z0
	while z + len <= z1 do
		glow(root, "Window", Vector3.new(0.4, 0.9, len), Vector3.new(x, y, z + len / 2), transparency)
		z += every
	end
end
for _, s in ipairs({ -1, 1 }) do
	-- fore hull flank (y -15 .. 15)
	deco(root, "ForeRail", Vector3.new(1.4, 2, 104), Vector3.new(s * (FW + 0.4), 13, -68), SILVER)
	windowRow(s * (FW + 0.25), 10, -118, -18, 5, 2.4, 0.05)
	windowRow(s * (FW + 0.25), 7.2, -116, -20, 5, 2.4, 0.3)
	cyl(root, "Pipe", Vector3.new(s * (FW + 0.9), 4.6, -68), Vector3.new(0, 0, 1), 100, 1.4, SILVER_DARK)
	cyl(root, "PipeThin", Vector3.new(s * (FW + 0.8), 3.2, -70), Vector3.new(0, 0, 1), 92, 0.8, CHROME_LIGHT)
	deco(root, "ForeBelt", Vector3.new(2.4, 12, 102), CFrame.new(s * (FW + 1.4), -3, -68) * CFrame.Angles(0, 0, s * 0.14), CHROME_LIGHT)
	deco(root, "ForeBeltEdge", Vector3.new(2.6, 0.8, 102), Vector3.new(s * (FW + 1.9), 3.1, -68), SILVER)
	for i = 0, 5 do
		local z = -112 + i * 17
		-- vents in the belt: a dark recess with a glowing slit
		deco(root, "Vent", Vector3.new(0.6, 4, 7), Vector3.new(s * (FW + 2.7), -4, z), DARK)
		glow(root, "VentGlow", Vector3.new(0.5, 0.5, 6), Vector3.new(s * (FW + 3), -4, z), 0.25)
		deco(root, "BeltSeam", Vector3.new(0.6, 11, 0.6), Vector3.new(s * (FW + 2.75), -3, z + 8.5), DARK)
	end
	deco(root, "ForeRailLow", Vector3.new(1.4, 2, 104), Vector3.new(s * (FW + 0.4), -11.5, -68), SILVER_DARK)
	windowRow(s * (FW + 0.25), -13.5, -114, -24, 7, 2, 0.45)
	-- aft hull flank (y -18 .. 18)
	deco(root, "AftRail", Vector3.new(1.4, 2.4, 100), Vector3.new(s * (AW + 0.4), 16, 66), SILVER)
	windowRow(s * (AW + 0.25), 13, 20, 116, 5, 2.4, 0.05)
	windowRow(s * (AW + 0.25), 10, 22, 114, 5, 2.4, 0.3)
	deco(root, "AftBelt", Vector3.new(2.6, 14, 96), CFrame.new(s * (AW + 1.5), -7, 68) * CFrame.Angles(0, 0, s * 0.14), CHROME_LIGHT)
	deco(root, "AftBeltEdge", Vector3.new(2.8, 0.9, 96), Vector3.new(s * (AW + 2), 0.2, 68), SILVER)
	for i = 0, 4 do
		local z = 26 + i * 20
		deco(root, "Vent", Vector3.new(0.6, 5, 8), Vector3.new(s * (AW + 2.9), -8, z), DARK)
		glow(root, "VentGlow", Vector3.new(0.5, 0.6, 7), Vector3.new(s * (AW + 3.2), -8, z), 0.25)
		deco(root, "BeltSeam", Vector3.new(0.6, 13, 0.6), Vector3.new(s * (AW + 2.9), -7, z + 10), DARK)
	end
	deco(root, "AftRailLow", Vector3.new(1.4, 2.4, 100), Vector3.new(s * (AW + 0.4), -15.5, 66), SILVER_DARK)
end
-- the deck: a glowing spine line, panel lines across it, and antennas on the aft deck
glow(root, "SpineLight", Vector3.new(0.8, 0.5, 96), Vector3.new(0, FH + 3.1, -68), 0.15)
glow(root, "AftSpineLight", Vector3.new(0.8, 0.5, 90), Vector3.new(0, AH + 3.1, 66), 0.15)
for i = 0, 9 do
	deco(root, "DeckSeam", Vector3.new(FW * 2 - 6.4, 0.3, 0.5), Vector3.new(0, FH + 3.05, -118 + i * 10.5), DARK)
end
for i = 0, 8 do
	deco(root, "AftDeckSeam", Vector3.new(AW * 2 - 8.4, 0.3, 0.5), Vector3.new(0, AH + 3.05, 20 + i * 11.5), DARK)
end
for _, p in ipairs({ { -12, 78 }, { 12, 84 }, { -10, 104 }, { 11, 108 } }) do
	local base = Vector3.new(p[1], AH + 3, p[2])
	bar(root, "Antenna", base, base + Vector3.new(0, 14, 2), 0.6, 0.6, SILVER)
	glow(root, "AntennaTip", Vector3.new(0.9, 0.9, 0.9), base + Vector3.new(0, 14.4, 2.05), 0)
	bar(root, "AntennaArm", base + Vector3.new(-2, 9, 1.3), base + Vector3.new(2, 9, 1.3), 0.4, 0.4, SILVER_DARK)
end

-- ====================================================================
-- Turrets: the main battery (big, triple-barrelled, long guns that read from far away) and smaller secondaries
-- ====================================================================
local turretCount = 0

-- a secondary turret on its own yaw joint: base ring, housing, mantlet, twin barrels forward (-Z), a sight light
local function turret(pos, up, size)
	turretCount += 1
	local k = size or 1
	local flip = up < 0 and CFrame.Angles(0, 0, math.pi) or CFrame.new()
	local base = CFrame.new(pos) * flip
	deco(root, "TurretBase", Vector3.new(1.2 * k, 6 * k, 6 * k), base * CFrame.new(0, 0.6 * k, 0) * CFrame.Angles(0, 0, math.pi / 2), SILVER_DARK, nil, Enum.PartType.Cylinder)
	local h = hinge("Turret" .. turretCount, root, base * CFrame.new(0, 1.2 * k, 0))
	local hcf = h.CFrame
	deco(h, "TurretHousing", Vector3.new(4.6 * k, 2.6 * k, 5.6 * k), hcf * CFrame.new(0, 1.3 * k, 0.4 * k), CHROME_LIGHT)
	deco(h, "TurretRoof", Vector3.new(3.6 * k, 0.6 * k, 4.2 * k), hcf * CFrame.new(0, 2.8 * k, 0.8 * k), CHROME)
	deco(h, "TurretMantlet", Vector3.new(3.8 * k, 2 * k, 1 * k), hcf * CFrame.new(0, 1.3 * k, -2.6 * k), SILVER)
	for _, x in ipairs({ -0.85, 0.85 }) do
		local a = (hcf * CFrame.new(x * k, 1.3 * k, -3 * k)).Position
		local b = (hcf * CFrame.new(x * k, 1.3 * k, -11 * k)).Position
		bar(h, "TurretBarrel", a, b, 0.6 * k, 0.6 * k, CHROME)
		deco(h, "TurretMuzzle", Vector3.new(0.9 * k, 0.9 * k, 1.2 * k), CFrame.lookAt(b, b + (b - a)), SILVER)
	end
	glow(h, "TurretSight", Vector3.new(0.5 * k, 0.5 * k, 0.3 * k), hcf * CFrame.new(1.6 * k, 2 * k, -2.5 * k), 0)
	return h
end

-- a main battery turret: a heavy barbette, an angular housing with a sloped glacis, three long barrels with thick
-- sleeves and silver muzzle brakes, glowing seams; on its own yaw joint (Turret..), the barrels on an elevation
-- joint (Turret..Guns) so they can be raised at the gate
local function mainTurret(pos, up, size, barbette, yaw)
	turretCount += 1
	local k = size or 1
	local flip = up < 0 and CFrame.Angles(0, 0, math.pi) or CFrame.new()
	local base = CFrame.new(pos) * flip * CFrame.Angles(0, yaw or 0, 0) -- (yaw pi: an aft turret, guns to the stern)
	local bh = barbette or 2
	deco(root, "MainBarbette", Vector3.new(bh * k, 15 * k, 15 * k), base * CFrame.new(0, bh * k / 2, 0) * CFrame.Angles(0, 0, math.pi / 2), CHROME_LIGHT, nil, Enum.PartType.Cylinder)
	deco(root, "MainBarbetteRim", Vector3.new(0.8 * k, 15.8 * k, 15.8 * k), base * CFrame.new(0, bh * k, 0) * CFrame.Angles(0, 0, math.pi / 2), SILVER, nil, Enum.PartType.Cylinder)
	local name = "Turret" .. turretCount
	local h = hinge(name, root, base * CFrame.new(0, bh * k, 0))
	local hcf = h.CFrame
	deco(h, "MainHousing", Vector3.new(13 * k, 5.5 * k, 15 * k), hcf * CFrame.new(0, 2.75 * k, 1.5 * k), CHROME)
	deco(h, "MainHousingTop", Vector3.new(11 * k, 1.2 * k, 12 * k), hcf * CFrame.new(0, 6 * k, 2.2 * k), CHROME_LIGHT)
	deco(h, "MainGlacis", Vector3.new(13 * k, 1.4 * k, 7 * k), hcf * CFrame.new(0, 4.6 * k, -7 * k) * CFrame.Angles(-0.45, 0, 0), CHROME_LIGHT)
	deco(h, "MainRear", Vector3.new(12 * k, 4.4 * k, 3 * k), hcf * CFrame.new(0, 2.6 * k, 10 * k), CHROME_LIGHT)
	for _, s in ipairs({ -1, 1 }) do
		deco(h, "MainCheek", Vector3.new(1 * k, 5 * k, 14 * k), hcf * CFrame.new(s * 6.8 * k, 2.6 * k, 1.5 * k) * CFrame.Angles(0, 0, s * 0.18), SILVER_DARK)
		glow(h, "MainSeam", Vector3.new(0.35 * k, 0.4 * k, 12 * k), hcf * CFrame.new(s * 6.1 * k, 4.4 * k, 1.5 * k), 0.1)
	end
	glow(h, "MainSight", Vector3.new(1.2 * k, 0.8 * k, 0.4 * k), hcf * CFrame.new(4 * k, 4.4 * k, -6 * k), 0, GLOW_CORE)
	local guns = hinge(name .. "Guns", h, hcf * CFrame.new(0, 2.8 * k, -5.5 * k))
	local gcf = guns.CFrame
	deco(guns, "MainMantlet", Vector3.new(11 * k, 3.6 * k, 2 * k), gcf, SILVER)
	for _, x in ipairs({ -3, 0, 3 }) do
		local a = (gcf * CFrame.new(x * k, 0, -1 * k)).Position
		local m = (gcf * CFrame.new(x * k, 0, -9 * k)).Position
		local b = (gcf * CFrame.new(x * k, 0, -30 * k)).Position
		bar(guns, "MainSleeve", a, m, 2.2 * k, 2.2 * k, SILVER_DARK)
		bar(guns, "MainBarrel", m, b, 1.5 * k, 1.5 * k, CHROME_LIGHT)
		glow(guns, "MainBarrelSeam", Vector3.new(0.3 * k, 0.3 * k, (b - m).Magnitude * 0.7), CFrame.lookAt(m:Lerp(b, 0.5), b) * CFrame.new(0, 0.8 * k, 0), 0.15)
		bar(guns, "MainBarrelBand", m:Lerp(b, 0.45), m:Lerp(b, 0.48), 1.8 * k, 1.8 * k, SILVER_DARK)
		deco(guns, "MainBrake", Vector3.new(2.3 * k, 2.3 * k, 2.2 * k), CFrame.lookAt(b, b + (b - a)), SILVER)
		glow(guns, "MainMuzzleGlow", Vector3.new(1 * k, 1 * k, 0.4 * k), CFrame.lookAt(b, b + (b - a)) * CFrame.new(0, 0, -1.15 * k), 0.2)
	end
	return h
end

-- the chevron bays on the underside: an X of crossed silver bars round each bay, a diamond frame, glowing lines
local function chevronBay(z, y, half)
	bar(root, "Chevron", Vector3.new(-half, y, z - half * 1.2), Vector3.new(half, y, z + half * 1.2), 2.2, 1, SILVER)
	bar(root, "Chevron", Vector3.new(half, y, z - half * 1.2), Vector3.new(-half, y, z + half * 1.2), 2.2, 1, SILVER)
	for _, s in ipairs({ -1, 1 }) do
		bar(root, "ChevronFrame", Vector3.new(0, y - 0.2, z - half * 1.1), Vector3.new(s * half * 0.8, y - 0.2, z), 1, 0.7, SILVER_DARK)
		bar(root, "ChevronFrame", Vector3.new(s * half * 0.8, y - 0.2, z), Vector3.new(0, y - 0.2, z + half * 1.1), 1, 0.7, SILVER_DARK)
		glow(root, "ChevronGlow", Vector3.new(0.5, 0.4, half * 0.8), CFrame.new(s * half * 0.5, y - 0.4, z) * CFrame.Angles(0, s * 0.6, 0), 0.2)
	end
end
-- main battery: two forward on the deck (the rear one raised to fire over the front one), one aft, two below
-- (the front one stands on a tall barbette so its guns clear the bow; the big one behind fires over it)
mainTurret(Vector3.new(0, FH + 3, -104), 1, 1.35, 6)
mainTurret(Vector3.new(0, FH + 3, -70), 1, 1.9, 9)
mainTurret(Vector3.new(0, AH + 3, 44), 1, 1.5, 3, math.pi)
chevronBay(-86, -FH - 3.1, 13)
mainTurret(Vector3.new(0, -FH - 3.3, -86), -1, 1.45, 2)
chevronBay(54, -AH - 3.1, 18)
mainTurret(Vector3.new(0, -AH - 3.3, 54), -1, 1.6, 2, math.pi)
-- secondaries: in their own chevron bays below, on the flanks and the aft deck
for _, z in ipairs({ -112, -60, -36, 30, 80 }) do
	local y = z < 0 and -FH - 3.1 or -AH - 3.1
	chevronBay(z, y, z < 0 and 9 or 12)
	turret(Vector3.new(0, y - 0.4, z), -1, z < 0 and 1.4 or 1.7)
end
for _, s in ipairs({ -1, 1 }) do
	for _, z in ipairs({ 32, 56, 78 }) do
		local base = CFrame.new(s * (AW + 1.6), 5, z) * CFrame.Angles(0, 0, -s * math.pi / 2)
		turretCount += 1
		deco(root, "SponsonBase", Vector3.new(1.6, 8, 8), base * CFrame.new(0, 0.8, 0) * CFrame.Angles(0, 0, math.pi / 2), SILVER_DARK, nil, Enum.PartType.Cylinder)
		local h = hinge("Turret" .. turretCount, root, base * CFrame.new(0, 1.6, 0))
		local hcf = h.CFrame
		deco(h, "TurretHousing", Vector3.new(6, 3.6, 7.5), hcf * CFrame.new(0, 1.8, 0.4), CHROME_LIGHT)
		for _, x in ipairs({ -1.1, 1.1 }) do
			bar(h, "TurretBarrel", (hcf * CFrame.new(x, 1.8, -3.5)).Position, (hcf * CFrame.new(x, 1.8, -14)).Position, 0.9, 0.9, CHROME)
		end
		glow(h, "TurretSight", Vector3.new(0.7, 0.7, 0.4), hcf * CFrame.new(2.2, 2.8, -3.2), 0)
	end
	for _, z in ipairs({ -88, -54 }) do
		turret(Vector3.new(s * (FW - 4), FH + 3, z), 1, 1.2) -- (on the deck edges, clear of the main barbettes)
	end
end

-- ====================================================================
-- The bow: his faceless helmet. Two halves on hinges meet in a slanted front edge with one slit of light
-- ====================================================================
local BOW_BACK = -122
-- the face: its leading edge slants from the brow (top, set back) down to the chin (bottom, furthest forward), like
-- the helmet seen from the side; each half's side is built from horizontal armour bands whose front ends follow that
-- edge (stepped plates), narrowing towards the front. Bigger than the hull behind it, like a head on a neck.
local BROW = Vector3.new(0, 22, -160)
local CHIN = Vector3.new(0, -22, -194)
local BANDS = 8
local bowHalves = {}
for _, s in ipairs({ -1, 1 }) do
	local hcf = CFrame.new(s * 16, 0, BOW_BACK)
	local h = hinge(s < 0 and "BowL" or "BowR", root, hcf)
	bowHalves[s] = h
	for j = 0, BANDS - 1 do
		local t = (j + 0.5) / BANDS
		local edge = BROW:Lerp(CHIN, t)
		local bandH = (BROW.Y - CHIN.Y) / BANDS + 0.3
		local backX = 21 - math.abs(t - 0.45) * 10
		bar(h, "BowBand", Vector3.new(s * 1.2, edge.Y, edge.Z), Vector3.new(s * backX, edge.Y, BOW_BACK - 2), 2.4, bandH, j % 2 == 0 and CHROME or CHROME_LIGHT)
		if j > 0 then
			bar(h, "BowStep", Vector3.new(s * 1.6, edge.Y + bandH / 2, edge.Z + 0.4), Vector3.new(s * (backX + 0.4), edge.Y + bandH / 2, BOW_BACK - 2), 0.7, 0.5, SILVER_DARK)
		end
	end
	bar(h, "BowBrow", Vector3.new(s * 1.4, BROW.Y + 0.9, BROW.Z + 1.5), Vector3.new(s * 11, BROW.Y + 4.5, BOW_BACK - 1), 14, 2, CHROME_LIGHT)
	bar(h, "BowBrowEdge", Vector3.new(s * 0.9, BROW.Y + 1.2, BROW.Z), Vector3.new(s * 1.8, BROW.Y + 5.4, BOW_BACK - 1), 1.3, 1.3, SILVER)
	bar(h, "BowJaw", Vector3.new(s * 1.4, CHIN.Y - 0.9, CHIN.Z + 3), Vector3.new(s * 12, CHIN.Y - 4.5, BOW_BACK - 1), 12, 2, CHROME_LIGHT)
	bar(h, "BowChin", Vector3.new(s * 0.7, CHIN.Y - 0.6, CHIN.Z - 1.5), Vector3.new(s * 0.7, CHIN.Y - 10, CHIN.Z + 24), 1.8, 3.8, CHROME)
	bar(h, "BowLip", Vector3.new(s * 1.8, BROW.Y + 0.7, BROW.Z - 0.3), Vector3.new(s * 1.8, CHIN.Y - 0.7, CHIN.Z - 0.3), 1.3, 1.8, SILVER)
	bar(h, "BowSlit", Vector3.new(s * 0.5, BROW.Y - 1.5, BROW.Z - 0.9), Vector3.new(s * 0.5, CHIN.Y + 1.5, CHIN.Z - 0.9), 1, 1, GLOW_CORE, NEON)
	local sg = bar(h, "BowSlitGlow", Vector3.new(s * 1.2, BROW.Y - 0.8, BROW.Z - 0.6), Vector3.new(s * 1.2, CHIN.Y + 0.8, CHIN.Z - 0.6), 2.6, 0.6, GLOW, NEON)
	sg.Transparency = 0.45
	bar(h, "BowCheek", Vector3.new(s * 3.8, 8, -170), Vector3.new(s * 20.5, 12, BOW_BACK - 1), 1.3, 2, SILVER)
	bar(h, "BowCheekLow", Vector3.new(s * 3.8, -9, -183), Vector3.new(s * 20, -13.5, BOW_BACK - 1), 1.3, 2, SILVER_DARK)
	glow(h, "BowCheekGlow", Vector3.new(0.8, 0.8, 44), CFrame.new(s * 15, 1.5, -146) * CFrame.Angles(0, -s * 0.2, 0), 0.15)
	local face = CFrame.lookAt(Vector3.new(s * 17.5, 0, -138), Vector3.new(s * 17.5, 0, -138) + Vector3.new(s, 0, -0.18))
	deco(h, "BowEmblem", Vector3.new(7, 7, 0.8), face * CFrame.new(0, 0, -2.6) * CFrame.Angles(0, 0, math.rad(45)), SILVER)
	deco(h, "BowEmblemInset", Vector3.new(4.8, 4.8, 0.8), face * CFrame.new(0, 0, -3) * CFrame.Angles(0, 0, math.rad(45)), CHROME)
	glow(h, "BowEmblemCore", Vector3.new(2.6, 2.6, 0.6), face * CFrame.new(0, 0, -3.4) * CFrame.Angles(0, 0, math.rad(45)))
end
light(bowHalves[1], 90, 2.4) -- (the slit's light; a light in an invisible part still shines)
-- the main cannon, hidden inside the closed bow (joint Cannon slides it out forward)
do
	local h = hinge("Cannon", root, CFrame.new(0, 0, -130))
	cyl(h, "CannonBarrel", Vector3.new(0, 0, -140), Vector3.new(0, 0, 1), 40, 11, CHROME_LIGHT)
	for i = 0, 3 do
		cyl(h, "CannonBand", Vector3.new(0, 0, -126 - i * 9), Vector3.new(0, 0, 1), 1.8, 12.6, SILVER)
	end
	cyl(h, "CannonMuzzle", Vector3.new(0, 0, -160), Vector3.new(0, 0, 1), 2.5, 14, SILVER)
	cyl(h, "CannonCore", Vector3.new(0, 0, -161.5), Vector3.new(0, 0, 1), 0.8, 8, GLOW_CORE, NEON)
end

-- ====================================================================
-- The bridge: a stepped tower on the forward deck, behind the guns. Each level narrower than the one below, a sloped
-- front, a lit window band round it; on top the command cab with a wide glowing window and Malak's vertical slit in
-- the middle of it; sensor masts above
-- ====================================================================
do
	local LEVELS = {
		{ w = 26, h = 10, d = 30, z = -38 },
		{ w = 21, h = 8.5, d = 24, z = -36 },
		{ w = 16, h = 7.5, d = 18, z = -34.5 },
		{ w = 12, h = 6.5, d = 12, z = -33.5 },
	}
	local y = FH + 3
	for i, l in ipairs(LEVELS) do
		local cy = y + l.h / 2
		deco(root, "BridgeLevel" .. i, Vector3.new(l.w, l.h, l.d), Vector3.new(0, cy, l.z), i % 2 == 1 and CHROME or CHROME_LIGHT)
		-- the sloped front face and the silver lip along the top edge
		deco(root, "BridgeFront" .. i, Vector3.new(l.w - 1, l.h * 1.05, 2), CFrame.new(0, cy, l.z - l.d / 2 - 0.4) * CFrame.Angles(-0.3, 0, 0), CHROME_LIGHT)
		deco(root, "BridgeLip" .. i, Vector3.new(l.w + 0.6, 0.6, l.d + 0.6), Vector3.new(0, y + l.h + 0.1, l.z), SILVER)
		-- the window band round the level: front and both sides
		local wy = cy + l.h * 0.12
		glow(root, "BridgeWindows" .. i, Vector3.new(l.w * 0.8, 1, 0.4), CFrame.new(0, wy, l.z - l.d / 2 - 1.5) * CFrame.Angles(-0.3, 0, 0), i == #LEVELS and 0 or 0.1)
		for _, s in ipairs({ -1, 1 }) do
			glow(root, "BridgeWindowsSide" .. i, Vector3.new(0.4, 0.8, l.d * 0.8), Vector3.new(s * (l.w / 2 + 0.15), wy, l.z), 0.15)
			deco(root, "BridgeFin" .. i, Vector3.new(0.8, l.h * 0.9, l.d * 0.6), CFrame.new(s * (l.w / 2 + 0.5), cy, l.z + l.d * 0.1) * CFrame.Angles(0, 0, s * -0.1), SILVER_DARK)
		end
		y += l.h
	end
	-- the command cab's face: a wide window and, in its middle, Malak's slit of light
	local cab = LEVELS[#LEVELS]
	local cabY = y - cab.h / 2
	glow(root, "BridgeSlit", Vector3.new(0.9, cab.h * 0.9, 0.5), CFrame.new(0, cabY, cab.z - cab.d / 2 - 1.8) * CFrame.Angles(-0.3, 0, 0), 0, GLOW_CORE)
	local cabLightPart = glow(root, "BridgeCabGlow", Vector3.new(cab.w * 0.7, 1.4, 0.3), CFrame.new(0, cabY + 0.5, cab.z - cab.d / 2 - 1.7) * CFrame.Angles(-0.3, 0, 0), 0.35)
	light(cabLightPart, 30, 1.5)
	-- sensor masts: a tall centre mast with crossbars, a ring dish and a light, two shorter ones beside it
	local top = Vector3.new(0, y + 0.6, cab.z + 1)
	bar(root, "Mast", top, top + Vector3.new(0, 28, 3), 1.1, 1.1, SILVER)
	for i, h in ipairs({ 9, 16, 22 }) do
		local w = 9 - i * 2
		bar(root, "MastSpar", top + Vector3.new(-w, h, h / 28 * 3), top + Vector3.new(w, h, h / 28 * 3), 0.6, 0.6, SILVER_DARK)
		glow(root, "MastLight", Vector3.new(0.8, 0.8, 0.8), top + Vector3.new(w, h, h / 28 * 3), 0)
		glow(root, "MastLight", Vector3.new(0.8, 0.8, 0.8), top + Vector3.new(-w, h, h / 28 * 3), 0)
	end
	cyl(root, "MastDish", top + Vector3.new(0, 12, 1.3), Vector3.new(0, 1, 0), 0.6, 7, CHROME_LIGHT)
	cyl(root, "MastDishRim", top + Vector3.new(0, 12.4, 1.3), Vector3.new(0, 1, 0), 0.3, 7.6, SILVER)
	glow(root, "MastTip", Vector3.new(1.4, 1.4, 1.4), top + Vector3.new(0, 28.6, 3), 0, GLOW_CORE)
	for _, s in ipairs({ -1, 1 }) do
		local b = Vector3.new(s * 4.5, y + 0.4, cab.z + 3)
		bar(root, "MastSide", b, b + Vector3.new(s * 1.5, 15, 2), 0.7, 0.7, SILVER)
		glow(root, "MastSideTip", Vector3.new(0.9, 0.9, 0.9), b + Vector3.new(s * 1.5, 15.4, 2), 0)
	end
end

-- ====================================================================
-- The crest: upswept blades like his high collar, rising behind the bridge tower and leaning back over the core
-- ====================================================================
local CREST = {
	{ x = 0, z = -20, w = 10, L = 38, back = 0.5, roll = 0 },
	{ x = -7, z = -18, w = 8, L = 32, back = 0.56, roll = -0.24 },
	{ x = 7, z = -18, w = 8, L = 32, back = 0.56, roll = 0.24 },
	{ x = -12, z = -16, w = 6.5, L = 24, back = 0.64, roll = -0.48 },
	{ x = 12, z = -16, w = 6.5, L = 24, back = 0.64, roll = 0.48 },
}
for i, c in ipairs(CREST) do
	local cf = CFrame.new(c.x, FH + 2, c.z) * CFrame.Angles(0, 0, -c.roll) * CFrame.Angles(c.back, 0, 0)
	-- (outer face towards the back: the lining shows to the front, like the collar)
	blade(root, "Crest" .. i, cf, c.w, c.L, 1.4, { lining = true, emblem = i == 1, seamSide = c.x < 0 and -1 or 1 })
end
-- collar wings flaring out from the hull sides behind the bow
for _, s in ipairs({ -1, 1 }) do
	local cf = CFrame.new(s * FW, 6, -110) * CFrame.Angles(0, s * (math.pi / 2 - 0.55), 0) * CFrame.Angles(0.55, 0, 0)
	blade(root, s < 0 and "CollarL" or "CollarR", cf, 11, 40, 1.4, { lining = true, seamSide = -s })
	local low = CFrame.new(s * FW, -9, -106) * CFrame.Angles(0, s * (math.pi / 2 - 0.4), 0) * CFrame.Angles(math.pi - 0.7, 0, 0)
	blade(root, s < 0 and "ChinFinL" or "ChinFinR", low, 8, 24, 1.2, { emblem = false })
end

-- ====================================================================
-- The armillary amidships: the core and three great rings on their own joints
-- ====================================================================
local core = deco(root, "Core", Vector3.one * 30, Vector3.zero, GLOW_CORE, NEON, Enum.PartType.Ball)
local halo = deco(root, "CoreHalo", Vector3.one * 44, Vector3.zero, GLOW, NEON, Enum.PartType.Ball)
halo.Transparency = 0.72
light(core, 80, 3)
-- a cage of thin hoops round the core
local function ringSegments(to, name, frame, r, n, radial, height, color, material)
	for k = 0, n - 1 do
		local a = (k + 0.5) / n * math.pi * 2
		local seg = 2 * r * math.sin(math.pi / n) * 1.03
		deco(to, name, Vector3.new(radial, height, seg), frame * CFrame.Angles(0, -a, 0) * CFrame.new(r, 0, 0), color, material)
	end
end
for i = 0, 2 do
	ringSegments(root, "CoreCage", CFrame.Angles(0, i * math.pi / 3, math.pi / 2), 21.5, 22, 0.9, 0.9, SILVER_DARK)
end

-- a great ring: chrome band, silver faces either side, a glowing inner band, studs of light round it
local function greatRing(name, frame, r, n, radial, height)
	local h = hinge(name, root, frame)
	ringSegments(h, name .. "Band", frame, r, n, radial, height, CHROME)
	ringSegments(h, name .. "FaceA", frame * CFrame.new(0, height / 2 + 0.3, 0), r, n, radial + 0.6, 0.6, SILVER)
	ringSegments(h, name .. "FaceB", frame * CFrame.new(0, -height / 2 - 0.3, 0), r, n, radial + 0.6, 0.6, SILVER)
	ringSegments(h, name .. "Glow", frame, r - radial / 2 - 0.3, n, 0.6, height * 0.5, GLOW, NEON)
	for k = 0, 5 do
		local a = k / 6 * math.pi * 2
		local at = frame * CFrame.Angles(0, -a, 0) * CFrame.new(r + radial / 2 + 0.6, 0, 0)
		deco(h, name .. "Stud", Vector3.new(radial * 0.4, height * 0.7, radial * 0.9), at, SILVER)
		glow(h, name .. "StudGlow", Vector3.new(0.6, height * 0.4, 1.8), at * CFrame.new(0.6, 0, 0))
	end
	return h
end
-- RingA square to the hull (turns round the hull's axis), RingB at right angles to it, RingC smaller and tilted
greatRing("RingA", CFrame.Angles(math.pi / 2, 0, 0), 56, 48, 6, 7)
greatRing("RingB", CFrame.Angles(0, 0, math.pi / 2), 46, 44, 4.6, 5.6)
greatRing("RingC", CFrame.Angles(math.rad(50), 0, math.rad(35)), 34, 34, 3, 4)

-- ====================================================================
-- The stern: layered blade fins flaring back like his coat skirt, engines glowing between them
-- ====================================================================
-- outer fins: eight broad, heavy armour blades round the aft hull, flaring out only a little (armour, not feathers)
for k = 0, 7 do
	local th = math.rad(22.5 + k * 45)
	local out = Vector3.new(math.cos(th), math.sin(th), 0)
	local base = out * 17 + Vector3.new(0, 0, 52 + (k % 2) * 10)
	local flare = 0.12 + (k % 3) * 0.025
	local growth = Vector3.new(0, 0, 1) * math.cos(flare) + out * math.sin(flare)
	local L = 96 + ((k * 5) % 3) * 8
	blade(root, "Fin" .. k, frameFrom(base, growth, out), 30, L, 3.2, { lining = true, emblemAt = L * 0.45, emblemSize = 7, seamSide = (k % 2 == 0) and 1 or -1 })
end
-- inner fins: shorter, between the outer ones
for k = 0, 7 do
	local th = math.rad(k * 45)
	local out = Vector3.new(math.cos(th), math.sin(th), 0)
	local base = out * 14 + Vector3.new(0, 0, 80)
	local growth = Vector3.new(0, 0, 1) * math.cos(0.06) + out * math.sin(0.06)
	blade(root, "InnerFin" .. k, frameFrom(base, growth, out), 20, 70, 2.4, { emblem = false })
end
-- The engine block: a heavy housing closing the aft hull, five great stepped thruster bells (a big one in the middle,
-- four round it) with white-hot cores and long glowing plumes, and a thruster pod on an outrigger to each side. It
-- has to read as THRUST from any angle.
local function thruster(pos, d, plumeLen, withLight)
	-- the bell: three stepped rings widening backwards, a dark throat, a white-hot core, then the plume in layers
	cyl(root, "ThrusterBase", pos, Vector3.new(0, 0, 1), d * 0.5, d * 0.8, CHROME_LIGHT)
	cyl(root, "ThrusterBell1", pos + Vector3.new(0, 0, d * 0.35), Vector3.new(0, 0, 1), d * 0.25, d * 0.9, CHROME)
	cyl(root, "ThrusterBell2", pos + Vector3.new(0, 0, d * 0.58), Vector3.new(0, 0, 1), d * 0.25, d * 1.02, CHROME_LIGHT)
	cyl(root, "ThrusterBell3", pos + Vector3.new(0, 0, d * 0.8), Vector3.new(0, 0, 1), d * 0.22, d * 1.14, CHROME)
	cyl(root, "ThrusterLip", pos + Vector3.new(0, 0, d * 0.93), Vector3.new(0, 0, 1), d * 0.06, d * 1.2, SILVER)
	cyl(root, "ThrusterThroat", pos + Vector3.new(0, 0, d * 0.9), Vector3.new(0, 0, 1), d * 0.1, d * 0.98, DARK)
	local core = cyl(root, "ThrusterCore", pos + Vector3.new(0, 0, d * 0.94), Vector3.new(0, 0, 1), d * 0.05, d * 0.8, GLOW_CORE, NEON)
	local layers = {
		{ len = plumeLen * 0.35, dia = 0.78, tr = 0.15, color = GLOW_CORE },
		{ len = plumeLen * 0.6, dia = 0.66, tr = 0.5, color = GLOW },
		{ len = plumeLen, dia = 0.5, tr = 0.78, color = GLOW_DEEP },
	}
	for i, l in ipairs(layers) do
		local p = cyl(root, "ThrusterPlume" .. i, pos + Vector3.new(0, 0, d * 0.96 + l.len / 2), Vector3.new(0, 0, 1), l.len, d * l.dia, l.color, NEON)
		p.Transparency = l.tr
	end
	local fx = Instance.new("ParticleEmitter")
	fx.Name = "ThrusterFlicker"
	fx.Color = ColorSequence.new(GLOW_CORE, GLOW_DEEP)
	fx.LightEmission = 1
	fx.LightInfluence = 0
	fx.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, d * 0.35), NumberSequenceKeypoint.new(1, d * 0.05) })
	fx.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
	fx.Lifetime = NumberRange.new(0.15, 0.3)
	fx.Rate = 30
	fx.Speed = NumberRange.new(plumeLen * 2, plumeLen * 3)
	fx.SpreadAngle = Vector2.new(4, 4)
	fx.EmissionDirection = Enum.NormalId.Right -- (the cylinder's axis is its X; +X points out of the bell, backwards)
	fx.Parent = core
	if withLight then
		light(core, d * 4, 3)
	end
end
-- the housing: a wide drum closing the aft hull, ribbed, with a glowing seam
cyl(root, "EngineHousing", Vector3.new(0, 0, 126), Vector3.new(0, 0, 1), 10, 44, CHROME)
cyl(root, "EngineHousingRim", Vector3.new(0, 0, 131.2), Vector3.new(0, 0, 1), 1, 46, SILVER)
cyl(root, "EngineHousingGlow", Vector3.new(0, 0, 121.6), Vector3.new(0, 0, 1), 0.8, 44.6, GLOW, NEON)
for k = 0, 11 do
	local th = k / 12 * math.pi * 2
	deco(root, "EngineRib", Vector3.new(2, 2.4, 10.4), CFrame.new(math.cos(th) * 22, math.sin(th) * 22, 126) * CFrame.Angles(0, 0, th), CHROME_LIGHT)
end
thruster(Vector3.new(0, 0, 131), 20, 70, true)
for k = 0, 3 do
	local th = k / 4 * math.pi * 2 + math.pi / 4
	thruster(Vector3.new(math.cos(th) * 14, math.sin(th) * 14, 131), 11, 46, k == 0)
end
-- outrigger pods: a strut out of each flank, a long pod with its own thruster
for _, s in ipairs({ -1, 1 }) do
	local podPos = Vector3.new(s * (AW + 14), -2, 96)
	bar(root, "PodStrut", Vector3.new(s * AW, 2, 86), podPos + Vector3.new(0, 0, -6), 3, 1.6, CHROME_LIGHT)
	bar(root, "PodStrutLow", Vector3.new(s * AW, -10, 100), podPos + Vector3.new(0, 0, 4), 2.4, 1.2, SILVER_DARK)
	cyl(root, "Pod", podPos, Vector3.new(0, 0, 1), 34, 9, CHROME)
	cyl(root, "PodNose", podPos + Vector3.new(0, 0, -18.5), Vector3.new(0, 0, 1), 3, 6.5, CHROME_LIGHT)
	deco(root, "PodNoseTip", Vector3.new(3.8, 3.8, 3.8), CFrame.new(podPos + Vector3.new(0, 0, -20.8)) * CFrame.Angles(math.rad(45), math.rad(45), 0), SILVER)
	for i = 0, 2 do
		cyl(root, "PodBand", podPos + Vector3.new(0, 0, -10 + i * 9), Vector3.new(0, 0, 1), 1, 9.6, SILVER_DARK)
	end
	glow(root, "PodSeam", Vector3.new(0.5, 0.5, 28), podPos + Vector3.new(s * 4.4, 0, 0), 0.1)
	thruster(podPos + Vector3.new(0, 0, 17), 8, 34, false)
end
-- point-defence turrets along the aft deck edges
for _, s in ipairs({ -1, 1 }) do
	for _, z in ipairs({ 22, 66, 100 }) do
		turret(Vector3.new(s * (AW - 5), AH + 3, z), 1, 0.7)
	end
end

-- ====================================================================
model:ScaleTo(1.15) -- (the whole ship a size up: ~420 studs from chin to fin tips)
model:SetAttribute("Length", 420)
model.Parent = folder

local parts, joints = 0, 0
for _, d in ipairs(model:GetDescendants()) do
	if d:IsA("BasePart") then parts += 1 end
	if d:IsA("Motor6D") then joints += 1 end
end
return NAME .. ": " .. parts .. " parts, " .. joints .. " joints, " .. turretCount .. " turrets"
