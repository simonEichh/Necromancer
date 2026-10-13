-- Builds the grave shop stall on the plaza: Workspace.HubDecor.Stall_GraveShopkeeper (an undertaker's magic grave shop:
-- a sarcophagus counter with a ledger, coins and a crystal ball inside two turning rune rings, a skeletal undertaker in
-- a top hat with a lantern staff, display shelves with one miniature tombstone per grave tier (Mossy..Celestial), a
-- floating ornate tombstone on an altar in front of a turning summoning halo, an iron cemetery fence, coffins, a barrel
-- of shovels, a freshly dug grave with souls rising, floating candles and an iron arch with the GRAVES sign) and places
-- the invisible interaction anchor Workspace.Shops.GraveShopkeeper (with its ProximityPrompt; the server wires it in
-- ShopNpcs).
-- Run in Edit mode via the Studio MCP execute_luau. Safe to re-run (it replaces the stall).
-- The turning parts are models tagged "SpinFx" (attribute SpinSpeed, rad/s); the client (Modules/WorldFx) turns them
-- around their PrimaryPart's up axis at runtime.

local CollectionService = game:GetService("CollectionService")

local floorTop = -1.7
local DEG = 22.5 -- plaza angle (same convention as build_coliseum.lua: dirAt(deg) = (sin, 0, -cos))
local RADIUS = 31

local STONE_DARK = Color3.fromRGB(60, 42, 46)
local STONE = Color3.fromRGB(94, 68, 72)
local STONE_LIGHT = Color3.fromRGB(132, 102, 104)
local BASALT = Color3.fromRGB(38, 26, 30)
local IRON = Color3.fromRGB(40, 42, 50)
local IRON_LIGHT = Color3.fromRGB(78, 82, 94)
local BRONZE = Color3.fromRGB(122, 92, 58)
local GOLD = Color3.fromRGB(232, 190, 90)
local WOOD_DARK = Color3.fromRGB(62, 44, 36)
local WOOD = Color3.fromRGB(86, 62, 46)
local LEATHER = Color3.fromRGB(84, 56, 40)
local MUD = Color3.fromRGB(64, 50, 40)
local MOSS = Color3.fromRGB(70, 40, 38)
local BONE = Color3.fromRGB(222, 212, 188)
local COAT = Color3.fromRGB(30, 28, 38)
local VEST = Color3.fromRGB(110, 26, 32)
local PAPER = Color3.fromRGB(226, 214, 180)
local LAMP = Color3.fromRGB(255, 190, 110)
local GLOW = Color3.fromRGB(255, 60, 50)
local ARCANE = Color3.fromRGB(255, 140, 70)
local SPIRIT = Color3.fromRGB(255, 150, 140)
-- one miniature tombstone per grave tier: stone colour, material, glow colour
local TIERS = {
	{ Color3.fromRGB(86, 112, 78), Enum.Material.Slate, Color3.fromRGB(140, 230, 120) }, -- Mossy
	{ Color3.fromRGB(128, 130, 140), Enum.Material.Slate, Color3.fromRGB(200, 210, 230) }, -- Stone
	{ Color3.fromRGB(160, 136, 96), Enum.Material.Sandstone, Color3.fromRGB(240, 200, 110) }, -- Ancient
	{ Color3.fromRGB(84, 46, 92), Enum.Material.Slate, Color3.fromRGB(220, 110, 255) }, -- Cursed
	{ Color3.fromRGB(36, 36, 52), Enum.Material.Basalt, Color3.fromRGB(150, 150, 255) }, -- Shadow
	{ Color3.fromRGB(96, 34, 22), Enum.Material.Basalt, Color3.fromRGB(255, 110, 60) }, -- Abyssal
	{ Color3.fromRGB(24, 82, 80), Enum.Material.Slate, Color3.fromRGB(90, 255, 220) }, -- Eldritch
	{ Color3.fromRGB(18, 14, 34), Enum.Material.Basalt, Color3.fromRGB(190, 90, 255) }, -- Void
	{ Color3.fromRGB(196, 192, 210), Enum.Material.Marble, Color3.fromRGB(255, 220, 140) }, -- Eternal
	{ Color3.fromRGB(176, 200, 236), Enum.Material.Marble, Color3.fromRGB(200, 235, 255) }, -- Celestial
}

local decor = workspace:FindFirstChild("HubDecor")
local shops = workspace:FindFirstChild("Shops")
assert(decor and shops, "HubDecor / Shops missing")
local old = decor:FindFirstChild("Stall_GraveShopkeeper")
if old then old:Destroy() end

local origin = Vector3.new(0, floorTop, 0)
local m = Instance.new("Model")
m.Name = "Stall_GraveShopkeeper"
m.WorldPivot = CFrame.new(origin)

-- local frame: built around the origin facing -X (the counter side faces the monument after PivotTo)
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
local function light(parent, color, range, brightness)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Shadows = false
	l.Parent = parent
	return l
end
-- a vertical cylinder (Roblox cylinders run along X)
local UPRIGHT = CFrame.Angles(0, 0, math.rad(90))
local function disc(parent, name, radius, height, cf, color, material)
	return part(parent, name, Vector3.new(height, radius * 2, radius * 2), cf * UPRIGHT, color, material, Enum.PartType.Cylinder)
end
-- a ring of thin segments lying flat (in the local XZ plane of `cf`)
local function ring(parent, name, radius, count, width, thick, cf, color, phase)
	local seg = 2 * math.pi * radius / count * 0.86
	for k = 0, count - 1 do
		local a = (k / count) * 2 * math.pi + (phase or 0)
		local c = cf * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -radius)
		part(parent, name, Vector3.new(seg, thick, width), c, color, Enum.Material.Neon)
	end
end
-- a straight neon bar from a to b (both in the local frame of `cf`), lying flat
local function bar(parent, name, a, b, width, thick, cf, color)
	local mid = (a + b) / 2
	local len = (b - a).Magnitude
	local c = cf * CFrame.lookAt(mid, b) -- along -Z of the bar
	return part(parent, name, Vector3.new(width, thick, len), c, color, Enum.Material.Neon)
end
-- a square beam from a to b (stall-local positions; not for exactly vertical beams)
local function seg(parent, name, a, b, thick, color, material)
	local len = (b - a).Magnitude
	local c = CFrame.lookAt(origin + (a + b) / 2, origin + b)
	return part(parent, name, Vector3.new(thick, thick, len), c, color, material)
end
local function particles(parent, name, color, rate, life, speed, size)
	local e = Instance.new("ParticleEmitter")
	e.Name = name
	e.Color = ColorSequence.new(color)
	e.LightEmission = 0.8
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 1) })
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size), NumberSequenceKeypoint.new(1, 0) })
	e.Lifetime = NumberRange.new(life * 0.7, life)
	e.Rate = rate
	e.Speed = NumberRange.new(speed * 0.5, speed)
	e.SpreadAngle = Vector2.new(15, 15)
	e.EmissionDirection = Enum.NormalId.Top
	e.Parent = parent
	return e
end
local function spinModel(name, hubCf, speed)
	local layer = Instance.new("Model")
	layer.Name = name
	local hub = part(layer, "Hub", Vector3.new(0.2, 0.2, 0.2), hubCf, GLOW, Enum.Material.Neon)
	hub.Transparency = 1
	layer.PrimaryPart = hub
	layer:SetAttribute("SpinSpeed", speed)
	layer.ModelStreamingMode = Enum.ModelStreamingMode.Atomic -- the client spins it: all parts must arrive together
	CollectionService:AddTag(layer, "SpinFx")
	layer.Parent = m
	return layer
end
-- a small iron lantern with a glowing pane, centred at `cf`
local function lantern(parent, cf, color)
	part(parent, "LanternCap", Vector3.new(0.55, 0.12, 0.55), cf * CFrame.new(0, 0.36, 0), IRON, Enum.Material.Metal)
	part(parent, "LanternRoof", Vector3.new(0.32, 0.18, 0.32), cf * CFrame.new(0, 0.5, 0) * CFrame.Angles(0, math.rad(45), 0), IRON, Enum.Material.Metal)
	part(parent, "LanternFoot", Vector3.new(0.55, 0.12, 0.55), cf * CFrame.new(0, -0.36, 0), IRON, Enum.Material.Metal)
	for _, o in ipairs({ { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } }) do
		part(parent, "LanternBar", Vector3.new(0.06, 0.62, 0.06), cf * CFrame.new(o[1] * 0.24, 0, o[2] * 0.24), IRON, Enum.Material.Metal)
	end
	local glass = part(parent, "LanternGlow", Vector3.new(0.38, 0.55, 0.38), cf, color, Enum.Material.Neon)
	glass.Transparency = 0.15
	light(glass, color, 9, 0.6)
	return glass
end

-- ============================================================
-- Dais: mossy stone platform with a glowing rune border and a summoning sigil in front of the counter
-- ============================================================
local DX, DZ = 7.4, 8.0 -- half extents
solid(m, "DaisStep", Vector3.new(DX * 2 + 1.2, 0.25, DZ * 2 + 1.2), at(0, 0.125, 0), STONE_DARK, Enum.Material.Brick)
solid(m, "Dais", Vector3.new(DX * 2, 0.5, DZ * 2), at(0, 0.35, 0), STONE, Enum.Material.Slate)
local TOP = 0.6 -- top of the dais
for _, z in ipairs({ -DZ + 0.5, DZ - 0.5 }) do
	part(m, "RuneBorder", Vector3.new(DX * 2 - 1.0, 0.04, 0.1), at(0, TOP + 0.01, z), GLOW, Enum.Material.Neon)
end
for _, x in ipairs({ -DX + 0.5, DX - 0.5 }) do
	part(m, "RuneBorder", Vector3.new(0.1, 0.04, DZ * 2 - 1.0), at(x, TOP + 0.01, 0), GLOW, Enum.Material.Neon)
end
for _, x in ipairs({ -DX + 0.5, DX - 0.5 }) do
	for _, z in ipairs({ -DZ + 0.5, DZ - 0.5 }) do
		part(m, "RuneCorner", Vector3.new(0.5, 0.05, 0.5), at(x, TOP + 0.02, z) * CFrame.Angles(0, math.rad(45), 0), ARCANE, Enum.Material.Neon)
	end
end
for _, p in ipairs({ { -4.8, -3.6, 2.2 }, { 1.0, -7.0, 2.6 }, { 5.4, 7.0, 2.0 }, { -2.0, 6.6, 1.8 }, { 3.2, -1.6, 1.6 }, { -6.4, 4.6, 1.4 } }) do
	part(m, "Moss", Vector3.new(p[3], 0.04, p[3] * 0.7), at(p[1], TOP + 0.02, p[2]) * CFrame.Angles(0, p[1], 0), MOSS, Enum.Material.Ground)
end
-- summoning sigil where the customer stands
local sigil = at(-5.9, TOP + 0.03, 0)
ring(m, "SigilRing", 1.35, 26, 0.08, 0.04, sigil, GLOW)
ring(m, "SigilRingInner", 1.1, 22, 0.05, 0.04, sigil, ARCANE)
do
	local pts = {}
	for k = 0, 4 do
		local a = (k / 5) * 2 * math.pi
		pts[k + 1] = Vector3.new(math.sin(a) * 1.05, 0, -math.cos(a) * 1.05)
	end
	for k = 1, 5 do
		bar(m, "SigilStar", pts[k], pts[(k + 1) % 5 + 1], 0.05, 0.04, sigil, GLOW)
	end
end

-- ============================================================
-- Counter: a stone sarcophagus with a ledger, coins, candles and a crystal ball in two turning rune rings
-- ============================================================
local CX = -3.0
solid(m, "SarcophagusFoot", Vector3.new(2.6, 0.3, 7.6), at(CX, TOP + 0.15, 0), STONE_DARK, Enum.Material.Slate)
solid(m, "Sarcophagus", Vector3.new(2.2, 1.7, 7.0), at(CX, TOP + 1.15, 0), STONE, Enum.Material.Slate)
solid(m, "SarcophagusLid", Vector3.new(2.6, 0.35, 7.6), at(CX, TOP + 2.175, 0), STONE_LIGHT, Enum.Material.Slate)
local LID = TOP + 2.35 -- top of the lid
for _, z in ipairs({ -3.55, 3.55 }) do
	part(m, "CornerBronze", Vector3.new(2.3, 1.75, 0.2), at(CX, TOP + 1.15, z), BRONZE, Enum.Material.Metal)
end
-- front (-X) face: two rune panels and a carved skull in the middle
local FX = CX - 1.1
for _, z in ipairs({ -2.0, 2.0 }) do
	part(m, "Panel", Vector3.new(0.06, 1.1, 2.4), at(FX - 0.02, TOP + 1.15, z), STONE_DARK, Enum.Material.Slate)
	part(m, "PanelRune", Vector3.new(0.05, 0.6, 0.1), at(FX - 0.06, TOP + 1.15, z), GLOW, Enum.Material.Neon)
	part(m, "PanelRune", Vector3.new(0.05, 0.1, 0.5), at(FX - 0.06, TOP + 1.3, z), GLOW, Enum.Material.Neon)
	part(m, "PanelRune", Vector3.new(0.05, 0.1, 0.3), at(FX - 0.06, TOP + 0.95, z + (z < 0 and 0.15 or -0.15)), GLOW, Enum.Material.Neon)
end
part(m, "RuneBand", Vector3.new(0.05, 0.08, 6.6), at(FX - 0.03, TOP + 1.9, 0), GLOW, Enum.Material.Neon)
part(m, "Skull", Vector3.new(0.4, 0.75, 0.8), at(FX - 0.15, TOP + 1.2, 0), BONE, Enum.Material.Marble)
part(m, "SkullJaw", Vector3.new(0.35, 0.25, 0.5), at(FX - 0.15, TOP + 0.75, 0), BONE, Enum.Material.Marble)
for _, z in ipairs({ -0.18, 0.18 }) do
	part(m, "SkullEye", Vector3.new(0.05, 0.18, 0.18), at(FX - 0.36, TOP + 1.25, z), GLOW, Enum.Material.Neon)
end
for _, s in ipairs({ -1, 1 }) do
	part(m, "Bone", Vector3.new(0.14, 0.14, 1.3), at(FX - 0.1, TOP + 1.0, 0) * CFrame.Angles(math.rad(35 * s), 0, 0), BONE, Enum.Material.Marble)
end
-- the open ledger with a quill and an inkwell
part(m, "LedgerCover", Vector3.new(1.3, 0.1, 1.8), at(CX, LID + 0.05, -2.0), LEATHER, Enum.Material.Fabric)
for _, s in ipairs({ -1, 1 }) do
	part(m, "LedgerPage", Vector3.new(1.1, 0.08, 0.8), at(CX, LID + 0.15, -2.0 + s * 0.42) * CFrame.Angles(math.rad(-5 * s), 0, 0), PAPER, Enum.Material.SmoothPlastic)
	for k = 0, 1 do
		part(m, "LedgerInk", Vector3.new(0.05, 0.02, 0.5), at(CX - 0.2 + k * 0.3, LID + 0.2, -2.0 + s * 0.42), GLOW, Enum.Material.Neon)
	end
end
disc(m, "Inkwell", 0.18, 0.25, at(CX + 0.4, LID + 0.125, -0.9), BASALT, Enum.Material.Glass)
seg(m, "Quill", Vector3.new(CX + 0.4, LID + 0.15, -0.9), Vector3.new(CX + 0.15, LID + 1.0, -0.6), 0.08, PAPER, Enum.Material.SmoothPlastic)
-- coin stacks and loose coins
for k, c in ipairs({ { -0.4, -0.2, 0.3 }, { 0.15, -0.35, 0.5 }, { -0.25, 0.25, 0.2 } }) do
	disc(m, "Coins", 0.2, c[3], at(CX + c[1], LID + c[3] / 2, c[2] - 0.1), GOLD, Enum.Material.Metal)
	part(m, "Coin", Vector3.new(0.04, 0.34, 0.34), at(CX + 0.5 - k * 0.3, LID + 0.03, 0.4 - k * 0.15) * UPRIGHT * CFrame.Angles(math.rad(k * 40), 0, 0), GOLD, Enum.Material.Metal, Enum.PartType.Cylinder)
end
-- candles
for k, c in ipairs({ { 0.3, 2.9, 0.8 }, { -0.2, 3.2, 0.55 }, { 0.2, 3.4, 0.35 } }) do
	disc(m, "Candle", 0.1, c[3], at(CX + c[1], LID + c[3] / 2, c[2]), BONE, Enum.Material.SmoothPlastic)
	local flame = part(m, "CandleFlame", Vector3.new(0.1, 0.2, 0.1), at(CX + c[1], LID + c[3] + 0.12, c[2]), LAMP, Enum.Material.Neon)
	if k == 1 then light(flame, LAMP, 8, 0.6) end
end
-- crystal ball on a claw stand
local BZ = 1.4
local BY = LID + 0.65
disc(m, "OrbStand", 0.35, 0.15, at(CX, LID + 0.075, BZ), BRONZE, Enum.Material.Metal)
for k = 0, 2 do
	local a = k / 3 * 2 * math.pi
	local d = Vector3.new(math.sin(a), 0, -math.cos(a))
	seg(m, "OrbClaw", Vector3.new(CX, LID + 0.12, BZ) + d * 0.25, Vector3.new(CX, BY - 0.15, BZ) + d * 0.45, 0.08, BRONZE, Enum.Material.Metal)
end
local orb = part(m, "CrystalBall", Vector3.new(1.0, 1.0, 1.0), at(CX, BY, BZ), ARCANE, Enum.Material.Glass, Enum.PartType.Ball)
orb.Transparency = 0.4
local core = part(m, "OrbCore", Vector3.new(0.45, 0.45, 0.45), at(CX, BY, BZ), GLOW, Enum.Material.Neon, Enum.PartType.Ball)
light(core, ARCANE, 10, 0.8)
local orbRingA = spinModel("OrbRingA", at(CX, BY, BZ) * CFrame.Angles(math.rad(22), 0, 0), 0.9)
ring(orbRingA, "OrbRing", 0.85, 22, 0.05, 0.04, orbRingA.PrimaryPart.CFrame, ARCANE)
for k = 0, 2 do
	part(orbRingA, "OrbRune", Vector3.new(0.12, 0.12, 0.12), orbRingA.PrimaryPart.CFrame * CFrame.Angles(0, k / 3 * 2 * math.pi, 0) * CFrame.new(0, 0, -0.85) * CFrame.Angles(math.rad(45), 0, math.rad(45)), GLOW, Enum.Material.Neon)
end
local orbRingB = spinModel("OrbRingB", at(CX, BY, BZ) * CFrame.Angles(math.rad(-30), 0, math.rad(15)), -0.6)
ring(orbRingB, "OrbRing", 1.0, 26, 0.05, 0.04, orbRingB.PrimaryPart.CFrame, GLOW)

-- ============================================================
-- The undertaker: a skeleton in a long coat and top hat, one hand on the ledger, a lantern staff in the other
-- ============================================================
local KX = -0.6
local function v(x, y, z) return Vector3.new(x, y, z) end
solid(m, "Coat", Vector3.new(1.8, 3.0, 1.8), at(KX, TOP + 1.7, 0), COAT, Enum.Material.Fabric)
part(m, "CoatTails", Vector3.new(2.2, 0.8, 2.2), at(KX, TOP + 0.4, 0), COAT, Enum.Material.Fabric)
part(m, "Vest", Vector3.new(0.08, 1.4, 0.8), at(KX - 0.92, TOP + 2.3, 0), VEST, Enum.Material.Fabric)
for k = 0, 2 do
	part(m, "Button", Vector3.new(0.06, 0.12, 0.12), at(KX - 0.97, TOP + 1.85 + k * 0.4, 0), GOLD, Enum.Material.Metal)
end
part(m, "Shoulders", Vector3.new(1.9, 0.6, 2.6), at(KX, TOP + 3.3, 0), COAT, Enum.Material.Fabric)
part(m, "Cravat", Vector3.new(0.1, 0.5, 0.4), at(KX - 0.96, TOP + 3.3, 0), BONE, Enum.Material.Fabric)
part(m, "Neck", Vector3.new(0.4, 0.4, 0.4), at(KX, TOP + 3.75, 0), BONE, Enum.Material.Marble)
local HY = TOP + 4.4
part(m, "Head", Vector3.new(1.15, 1.2, 1.05), at(KX, HY, 0), BONE, Enum.Material.Marble)
part(m, "Jaw", Vector3.new(0.85, 0.3, 0.8), at(KX - 0.05, HY - 0.7, 0), BONE, Enum.Material.Marble)
part(m, "Teeth", Vector3.new(0.05, 0.12, 0.6), at(KX - 0.49, HY - 0.6, 0), Color3.fromRGB(20, 18, 22), Enum.Material.SmoothPlastic)
part(m, "Nose", Vector3.new(0.05, 0.22, 0.14), at(KX - 0.59, HY - 0.15, 0), Color3.fromRGB(20, 18, 22), Enum.Material.SmoothPlastic)
for _, z in ipairs({ -0.25, 0.25 }) do
	part(m, "EyeSocket", Vector3.new(0.05, 0.32, 0.3), at(KX - 0.59, HY + 0.12, z), Color3.fromRGB(12, 10, 14), Enum.Material.SmoothPlastic)
	part(m, "Eye", Vector3.new(0.05, 0.14, 0.14), at(KX - 0.62, HY + 0.12, z), GLOW, Enum.Material.Neon)
end
disc(m, "HatBrim", 1.0, 0.12, at(KX, HY + 0.62, 0), COAT, Enum.Material.Fabric)
disc(m, "HatBand", 0.64, 0.2, at(KX, HY + 0.78, 0), GLOW, Enum.Material.Neon)
disc(m, "Hat", 0.62, 1.5, at(KX, HY + 1.43, 0), COAT, Enum.Material.Fabric)
-- left arm: hand resting on the ledger
seg(m, "ArmL", v(KX - 0.1, TOP + 3.2, -1.2), v(KX - 0.7, TOP + 2.5, -1.45), 0.5, COAT, Enum.Material.Fabric)
seg(m, "ForearmL", v(KX - 0.7, TOP + 2.5, -1.45), v(-1.95, LID + 0.15, -1.35), 0.42, COAT, Enum.Material.Fabric)
part(m, "HandL", Vector3.new(0.45, 0.14, 0.4), at(-2.2, LID + 0.08, -1.35), BONE, Enum.Material.Marble)
for k = -1, 1 do
	part(m, "FingerL", Vector3.new(0.4, 0.07, 0.07), at(-2.55, LID + 0.05, -1.35 + k * 0.13), BONE, Enum.Material.Marble)
end
-- right arm holding the lantern staff
local STAFF = v(KX - 0.9, 0, 1.7)
seg(m, "ArmR", v(KX - 0.1, TOP + 3.2, 1.2), v(KX - 0.4, TOP + 2.5, 1.6), 0.5, COAT, Enum.Material.Fabric)
seg(m, "ForearmR", v(KX - 0.4, TOP + 2.5, 1.6), v(STAFF.X + 0.1, TOP + 3.0, STAFF.Z), 0.42, COAT, Enum.Material.Fabric)
part(m, "HandR", Vector3.new(0.35, 0.4, 0.35), at(STAFF.X, TOP + 3.0, STAFF.Z), BONE, Enum.Material.Marble)
part(m, "Staff", Vector3.new(0.16, 6.0, 0.16), at(STAFF.X, TOP + 3.0, STAFF.Z), WOOD_DARK, Enum.Material.Wood)
seg(m, "StaffCrook", v(STAFF.X, TOP + 5.95, STAFF.Z), v(STAFF.X - 0.5, TOP + 6.35, STAFF.Z), 0.14, WOOD_DARK, Enum.Material.Wood)
seg(m, "StaffCrook", v(STAFF.X - 0.5, TOP + 6.35, STAFF.Z), v(STAFF.X - 0.85, TOP + 6.0, STAFF.Z), 0.14, WOOD_DARK, Enum.Material.Wood)
part(m, "LanternChain", Vector3.new(0.05, 0.35, 0.05), at(STAFF.X - 0.85, TOP + 5.82, STAFF.Z), IRON, Enum.Material.Metal)
lantern(m, at(STAFF.X - 0.85, TOP + 5.1, STAFF.Z), GLOW)
particles(m:FindFirstChild("CoatTails"), "Wisps", SPIRIT, 3, 2, 0.6, 0.35)

-- ============================================================
-- Display shelves at the back: a miniature tombstone for every grave tier, a glowing orb above each
-- ============================================================
-- style 1 rounded slab, 2 cross, 3 obelisk; stands on `yb`, faces -X
local function miniTomb(x, yb, z, tier, style)
	local stone, mat, glow = tier[1], tier[2], tier[3]
	part(m, "TombBase", Vector3.new(0.7, 0.18, 1.2), at(x, yb + 0.09, z), stone, mat)
	local b = yb + 0.18
	local topY
	if style == 1 then
		part(m, "TombSlab", Vector3.new(0.3, 1.0, 0.9), at(x, b + 0.5, z), stone, mat)
		part(m, "TombArch", Vector3.new(0.3, 0.9, 0.9), at(x, b + 1.0, z), stone, mat, Enum.PartType.Cylinder)
		part(m, "Epitaph", Vector3.new(0.04, 0.08, 0.5), at(x - 0.17, b + 0.75, z), glow, Enum.Material.Neon)
		part(m, "Epitaph", Vector3.new(0.04, 0.08, 0.34), at(x - 0.17, b + 0.5, z), glow, Enum.Material.Neon)
		topY = b + 1.45
	elseif style == 2 then
		part(m, "TombCross", Vector3.new(0.3, 1.5, 0.3), at(x, b + 0.75, z), stone, mat)
		part(m, "TombCrossArm", Vector3.new(0.3, 0.3, 1.0), at(x, b + 1.05, z), stone, mat)
		part(m, "Epitaph", Vector3.new(0.04, 0.16, 0.16), at(x - 0.17, b + 1.05, z) * CFrame.Angles(math.rad(45), 0, 0), glow, Enum.Material.Neon)
		topY = b + 1.5
	else
		part(m, "TombObelisk", Vector3.new(0.45, 1.2, 0.45), at(x, b + 0.6, z), stone, mat)
		part(m, "TombTip", Vector3.new(0.32, 0.32, 0.32), at(x, b + 1.25, z) * CFrame.Angles(math.rad(45), 0, 0), stone, mat)
		part(m, "Epitaph", Vector3.new(0.04, 0.6, 0.08), at(x - 0.24, b + 0.6, z), glow, Enum.Material.Neon)
		topY = b + 1.5
	end
	part(m, "TierOrb", Vector3.new(0.22, 0.22, 0.22), at(x, topY + 0.45, z), glow, Enum.Material.Neon, Enum.PartType.Ball)
end
local T1, T2 = TOP + 0.7, TOP + 1.5 -- shelf tops
for _, s in ipairs({ -1, 1 }) do
	solid(m, "ShelfLow", Vector3.new(1.4, 0.7, 4.6), at(3.2, TOP + 0.35, s * 4.4), STONE_DARK, Enum.Material.Slate)
	solid(m, "ShelfHigh", Vector3.new(1.4, 1.5, 4.6), at(4.6, TOP + 0.75, s * 4.4), STONE_DARK, Enum.Material.Slate)
	part(m, "ShelfTrim", Vector3.new(0.05, 0.08, 4.4), at(2.48, T1 - 0.12, s * 4.4), GLOW, Enum.Material.Neon)
	part(m, "ShelfTrim", Vector3.new(0.05, 0.08, 4.4), at(3.88, T2 - 0.12, s * 4.4), GLOW, Enum.Material.Neon)
	part(m, "ShelfMoss", Vector3.new(0.6, 0.05, 1.4), at(3.0, T1 + 0.02, s * 6.0), MOSS, Enum.Material.Ground)
	-- left side holds tiers 1-5 (outside in), the right side tiers 6-10
	local first = s < 0 and 0 or 5
	local lows = { 5.9, 4.4, 2.9 }
	local highs = { 5.2, 3.6 }
	for k = 1, 3 do
		miniTomb(3.2, T1, s * lows[k], TIERS[first + k], k)
	end
	for k = 1, 2 do
		miniTomb(4.6, T2, s * highs[k], TIERS[first + 3 + k], k + 1)
	end
end

-- ============================================================
-- Altar at the back centre: an ornate tombstone floats and turns above it, a summoning halo turns behind it
-- ============================================================
local AX = 4.4
disc(m, "AltarStep", 1.6, 0.4, at(AX, TOP + 0.2, 0), STONE_LIGHT, Enum.Material.Slate)
disc(m, "AltarStep2", 1.2, 0.5, at(AX, TOP + 0.65, 0), STONE, Enum.Material.Slate)
solid(m, "AltarColumn", Vector3.new(1.2, 1.6, 1.2), at(AX, TOP + 1.7, 0), BASALT, Enum.Material.Basalt)
part(m, "AltarRune", Vector3.new(0.05, 1.0, 0.12), at(AX - 0.62, TOP + 1.7, 0), ARCANE, Enum.Material.Neon)
disc(m, "AltarCap", 1.0, 0.3, at(AX, TOP + 2.65, 0), STONE_LIGHT, Enum.Material.Slate)
local altarGlow = disc(m, "AltarGlow", 0.85, 0.04, at(AX, TOP + 2.82, 0), GLOW, Enum.Material.Neon)
particles(altarGlow, "Souls", SPIRIT, 6, 2.2, 1.6, 0.4).EmissionDirection = Enum.NormalId.Right -- the disc's local +X points up
local FY = TOP + 8.0 -- floats above the undertaker's hat
local beam = part(m, "AltarBeam", Vector3.new(FY - 1.35 - (TOP + 2.82), 0.6, 0.6), at(AX, (FY - 1.35 + TOP + 2.82) / 2, 0) * UPRIGHT, GLOW, Enum.Material.Neon, Enum.PartType.Cylinder)
beam.Transparency = 0.8

local grave = spinModel("FloatingGrave", at(AX, FY, 0), 0.35)
local GRAVE_STONE = Color3.fromRGB(206, 210, 228)
local function g(name, size, cf, color, material, shape)
	return part(grave, name, size, cf, color or GRAVE_STONE, material or Enum.Material.Marble, shape)
end
g("Slab", Vector3.new(0.45, 2.0, 1.5), at(AX, FY, 0))
g("Arch", Vector3.new(0.45, 1.5, 1.5), at(AX, FY + 1.0, 0), nil, nil, Enum.PartType.Cylinder)
g("Plinth", Vector3.new(0.8, 0.35, 1.9), at(AX, FY - 1.17, 0))
for _, z in ipairs({ -0.78, 0.78 }) do
	g("Pilaster", Vector3.new(0.6, 1.9, 0.2), at(AX, FY - 0.05, z))
	g("PilasterCap", Vector3.new(0.7, 0.2, 0.3), at(AX, FY + 0.95, z), GOLD, Enum.Material.Metal)
end
for _, s in ipairs({ -1, 1 }) do
	g("Ankh", Vector3.new(0.04, 1.0, 0.12), at(AX + s * 0.24, FY - 0.2, 0), GLOW, Enum.Material.Neon)
	g("Ankh", Vector3.new(0.04, 0.12, 0.6), at(AX + s * 0.24, FY + 0.15, 0), GLOW, Enum.Material.Neon)
	g("AnkhLoop", Vector3.new(0.04, 0.4, 0.4), at(AX + s * 0.24, FY + 0.5, 0), GLOW, Enum.Material.Neon, Enum.PartType.Cylinder).Transparency = 0.2
end
local star = g("Finial", Vector3.new(0.4, 0.4, 0.4), at(AX, FY + 1.95, 0) * CFrame.Angles(math.rad(45), 0, math.rad(45)), GOLD, Enum.Material.Neon)
light(star, GOLD, 8, 0.6)

-- the halo: a vertical summoning circle facing the customers (local up axis = world -X)
local halo = at(AX + 1.0, FY + 0.3, 0) * CFrame.Angles(0, 0, math.rad(90))
local haloOuter = spinModel("HaloOuter", halo, 0.3)
ring(haloOuter, "HaloRing", 2.45, 44, 0.12, 0.05, halo, GLOW)
ring(haloOuter, "HaloRing2", 2.15, 40, 0.06, 0.05, halo, ARCANE)
for k = 0, 11 do
	local c = halo * CFrame.Angles(0, k / 12 * 2 * math.pi, 0) * CFrame.new(0, 0, -2.3)
	part(haloOuter, "Glyph", Vector3.new(0.08, 0.05, 0.22), c, GLOW, Enum.Material.Neon)
	part(haloOuter, "Glyph", Vector3.new(0.2, 0.05, 0.06), c * CFrame.new(0, 0, (k % 2 == 0) and 0.08 or -0.08), GLOW, Enum.Material.Neon)
end
for k = 0, 3 do
	part(haloOuter, "HaloStone", Vector3.new(0.3, 0.3, 0.3), halo * CFrame.Angles(0, k / 4 * 2 * math.pi + math.rad(45), 0) * CFrame.new(0, 0, -2.8) * CFrame.Angles(math.rad(45), 0, math.rad(45)), ARCANE, Enum.Material.Neon)
end
local haloInner = spinModel("HaloInner", halo, -0.55)
ring(haloInner, "HaloInnerRing", 1.6, 30, 0.08, 0.05, halo, GLOW)
do
	local pts = {}
	for k = 0, 4 do
		local a = (k / 5) * 2 * math.pi
		pts[k + 1] = Vector3.new(math.sin(a) * 1.55, 0, -math.cos(a) * 1.55)
	end
	for k = 1, 5 do
		bar(haloInner, "HaloStar", pts[k], pts[(k + 1) % 5 + 1], 0.06, 0.05, halo, ARCANE)
	end
end

-- ============================================================
-- Iron cemetery fence along the back with stone end pillars
-- ============================================================
local FENCE_X = 6.3
for _, y in ipairs({ TOP + 0.6, TOP + 3.6 }) do
	part(m, "FenceRail", Vector3.new(0.15, 0.15, 14.2), at(FENCE_X, y, 0), IRON, Enum.Material.Metal)
end
for k = 0, 20 do
	local z = -7.0 + k * 0.7
	part(m, "FenceBar", Vector3.new(0.12, 4.0, 0.12), at(FENCE_X, TOP + 2.2, z), IRON, Enum.Material.Metal)
	part(m, "FenceSpike", Vector3.new(0.12, 0.22, 0.22), at(FENCE_X, TOP + 4.3, z) * CFrame.Angles(math.rad(45), 0, 0), IRON_LIGHT, Enum.Material.Metal)
end
for _, z in ipairs({ -7.4, 7.4 }) do
	solid(m, "FencePillar", Vector3.new(1.0, 5.0, 1.0), at(FENCE_X, TOP + 2.5, z), STONE, Enum.Material.Brick)
	part(m, "FencePillarCap", Vector3.new(1.2, 0.3, 1.2), at(FENCE_X, TOP + 5.15, z), STONE_LIGHT, Enum.Material.Slate)
	part(m, "FencePillarBall", Vector3.new(0.8, 0.8, 0.8), at(FENCE_X, TOP + 5.7, z), STONE_LIGHT, Enum.Material.Slate, Enum.PartType.Ball)
	part(m, "FencePillarRune", Vector3.new(0.05, 1.4, 0.15), at(FENCE_X - 0.52, TOP + 2.8, z), GLOW, Enum.Material.Neon)
end

-- ============================================================
-- Left side (-Z): stacked coffins, an open coffin standing up, a barrel of shovels
-- ============================================================
-- a coffin along the local Z of `cf` (head at -Z), lid on local +Y; `open` shows a glowing inside instead of a lid
local function coffin(cf, len, wid, hgt, open)
	part(m, "CoffinHead", Vector3.new(wid, hgt, len * 0.55), cf * CFrame.new(0, 0, -len * 0.225), WOOD, Enum.Material.Wood)
	part(m, "CoffinFoot", Vector3.new(wid * 0.78, hgt, len * 0.45), cf * CFrame.new(0, 0, len * 0.275), WOOD, Enum.Material.Wood)
	if open then
		local inside = part(m, "CoffinGlow", Vector3.new(wid * 0.7, 0.05, len * 0.85), cf * CFrame.new(0, hgt / 2 + 0.01, 0), GLOW, Enum.Material.Neon)
		inside.Transparency = 0.3
		light(inside, GLOW, 8, 0.5)
		particles(inside, "Souls", SPIRIT, 3, 1.6, 1.0, 0.3)
		return
	end
	part(m, "CoffinLid", Vector3.new(wid + 0.1, 0.12, len * 0.55 + 0.1), cf * CFrame.new(0, hgt / 2 + 0.06, -len * 0.225), WOOD_DARK, Enum.Material.Wood)
	part(m, "CoffinLid", Vector3.new(wid * 0.78 + 0.1, 0.12, len * 0.45 + 0.1), cf * CFrame.new(0, hgt / 2 + 0.06, len * 0.275), WOOD_DARK, Enum.Material.Wood)
	part(m, "CoffinCross", Vector3.new(0.12, 0.05, len * 0.5), cf * CFrame.new(0, hgt / 2 + 0.14, -len * 0.05), BRONZE, Enum.Material.Metal)
	part(m, "CoffinCross", Vector3.new(wid * 0.5, 0.05, 0.12), cf * CFrame.new(0, hgt / 2 + 0.14, -len * 0.18), BRONZE, Enum.Material.Metal)
end
coffin(at(0.0, TOP + 0.45, -6.0) * CFrame.Angles(0, math.rad(90), 0), 3.2, 1.3, 0.9)
coffin(at(0.2, TOP + 1.3, -6.0) * CFrame.Angles(0, math.rad(98), 0), 3.0, 1.2, 0.8)
-- standing open coffin leaning back, lid propped beside it
local upright = at(-2.5, TOP + 1.75, -7.0) * CFrame.Angles(0, 0, math.rad(-8)) * CFrame.Angles(0, math.rad(-90), 0) * CFrame.Angles(math.rad(90), 0, 0)
coffin(upright, 3.4, 1.3, 0.8, true)
part(m, "CoffinLidLoose", Vector3.new(0.12, 3.3, 1.3), at(-3.9, TOP + 1.6, -7.2) * CFrame.Angles(math.rad(-10), 0, math.rad(-14)), WOOD_DARK, Enum.Material.Wood)
-- barrel of shovels
local BRL = v(-5.2, 0, -6.4)
disc(m, "Barrel", 0.65, 1.3, at(BRL.X, TOP + 0.65, BRL.Z), WOOD, Enum.Material.Wood)
for _, y in ipairs({ TOP + 0.25, TOP + 1.05 }) do
	disc(m, "BarrelBand", 0.68, 0.1, at(BRL.X, y, BRL.Z), IRON, Enum.Material.Metal)
end
disc(m, "BarrelDark", 0.55, 0.04, at(BRL.X, TOP + 1.29, BRL.Z), BASALT, Enum.Material.SmoothPlastic)
for k, o in ipairs({ { 0.2, 0.15, 0.5, 0.3 }, { -0.2, 0.1, -0.4, 0.5 }, { 0.05, -0.25, 0.2, -0.6 } }) do
	local a = v(BRL.X + o[1], TOP + 1.0, BRL.Z + o[2])
	local b = v(BRL.X + o[3], TOP + 3.0 + k * 0.15, BRL.Z + o[4])
	seg(m, "ShovelHandle", a, b, 0.14, WOOD_DARK, Enum.Material.Wood)
	part(m, "ShovelGrip", Vector3.new(0.5, 0.12, 0.12), CFrame.lookAt(origin + b, origin + b + (b - a)) * CFrame.Angles(0, math.rad(90), 0), IRON_LIGHT, Enum.Material.Metal)
end

-- ============================================================
-- Right side (+Z): a freshly dug grave with souls rising, a shovel in the earth mound, a crooked lantern post
-- ============================================================
local hole = part(m, "GraveHole", Vector3.new(2.8, 0.03, 1.4), at(0.3, TOP + 0.015, 5.0), Color3.fromRGB(8, 6, 10), Enum.Material.SmoothPlastic)
particles(hole, "Souls", SPIRIT, 3, 2.4, 1.4, 0.45)
light(hole, GLOW, 6, 0.4)
for _, z in ipairs({ 4.2, 5.8 }) do
	part(m, "HoleRim", Vector3.new(3.0, 0.14, 0.22), at(0.3, TOP + 0.07, z), MUD, Enum.Material.Mud)
end
for _, x in ipairs({ -1.2, 1.8 }) do
	part(m, "HoleRim", Vector3.new(0.22, 0.14, 1.6), at(x, TOP + 0.07, 5.0), MUD, Enum.Material.Mud)
end
part(m, "Mound", Vector3.new(2.8, 0.5, 1.3), at(0.3, TOP + 0.25, 6.9), MUD, Enum.Material.Mud)
part(m, "MoundTop", Vector3.new(2.1, 0.35, 0.9), at(0.4, TOP + 0.6, 6.9) * CFrame.Angles(0, math.rad(6), 0), MUD, Enum.Material.Mud)
for k, c in ipairs({ { -0.8, 6.2 }, { 1.4, 6.3 }, { -1.5, 7.3 } }) do
	part(m, "Clod", Vector3.new(0.35, 0.25, 0.3), at(c[1], TOP + 0.12, c[2]) * CFrame.Angles(0, k, 0.3), MUD, Enum.Material.Mud)
end
seg(m, "ShovelHandle", v(1.0, TOP + 0.8, 6.85), v(1.5, TOP + 3.1, 6.4), 0.14, WOOD_DARK, Enum.Material.Wood)
part(m, "ShovelGrip", Vector3.new(0.5, 0.12, 0.12), at(1.5, TOP + 3.15, 6.4), IRON_LIGHT, Enum.Material.Metal)
part(m, "ShovelBlade", Vector3.new(0.5, 0.6, 0.08), at(0.95, TOP + 0.65, 6.9) * CFrame.Angles(0, math.rad(-40), math.rad(-12)), IRON_LIGHT, Enum.Material.Metal)
-- a wooden marker cross at the head of the hole
part(m, "MarkerCross", Vector3.new(0.15, 1.6, 0.15), at(-1.75, TOP + 0.8, 5.0) * CFrame.Angles(math.rad(6), 0, 0), WOOD, Enum.Material.Wood)
part(m, "MarkerCrossArm", Vector3.new(0.15, 0.15, 0.8), at(-1.75, TOP + 1.2, 5.03) * CFrame.Angles(math.rad(6), 0, 0), WOOD, Enum.Material.Wood)
-- crooked lantern post leaning over the path
seg(m, "LampPost", v(-3.8, TOP, 6.8), v(-3.6, TOP + 5.0, 6.6), 0.3, WOOD_DARK, Enum.Material.Wood)
seg(m, "LampArm", v(-3.6, TOP + 4.7, 6.7), v(-3.6, TOP + 4.75, 5.0), 0.2, WOOD_DARK, Enum.Material.Wood)
seg(m, "LampBrace", v(-3.65, TOP + 3.9, 6.65), v(-3.6, TOP + 4.7, 5.9), 0.14, WOOD_DARK, Enum.Material.Wood)
part(m, "LampChain", Vector3.new(0.05, 0.5, 0.05), at(-3.6, TOP + 4.45, 5.15), IRON, Enum.Material.Metal)
lantern(m, at(-3.6, TOP + 3.75, 5.15), GLOW)

-- ============================================================
-- Floating candles around the shopkeeper
-- ============================================================
for _, c in ipairs({ { -1.4, 6.3, -2.6 }, { 0.8, 7.0, -1.6 }, { 1.2, 6.6, 2.4 }, { -1.8, 7.3, 3.4 }, { 2.4, 7.8, 0.6 } }) do
	disc(m, "FloatingCandle", 0.11, 0.6, at(c[1], TOP + c[2], c[3]), BONE, Enum.Material.SmoothPlastic)
	disc(m, "CandleDrip", 0.14, 0.08, at(c[1], TOP + c[2] - 0.28, c[3]), BONE, Enum.Material.SmoothPlastic)
	part(m, "CandleFlame", Vector3.new(0.1, 0.22, 0.1), at(c[1], TOP + c[2] + 0.42, c[3]), GLOW, Enum.Material.Neon)
end

-- ============================================================
-- Front: two obelisks with lanterns, an iron arch between them with a skull crest and the GRAVES sign
-- ============================================================
local OX, OZ = -6.4, 6.9
for _, s in ipairs({ -1, 1 }) do
	local z = s * OZ
	solid(m, "ObeliskBase", Vector3.new(1.8, 0.6, 1.8), at(OX, TOP + 0.3, z), STONE_LIGHT, Enum.Material.Slate)
	solid(m, "Obelisk", Vector3.new(1.3, 4.0, 1.3), at(OX, TOP + 2.6, z), STONE, Enum.Material.Brick)
	part(m, "ObeliskRune", Vector3.new(0.05, 2.2, 0.2), at(OX - 0.67, TOP + 2.8, z), GLOW, Enum.Material.Neon)
	part(m, "ObeliskRune", Vector3.new(0.05, 0.2, 0.6), at(OX - 0.67, TOP + 3.4, z), GLOW, Enum.Material.Neon)
	part(m, "ObeliskUpper", Vector3.new(1.0, 2.4, 1.0), at(OX, TOP + 5.8, z), STONE, Enum.Material.Brick)
	part(m, "ObeliskBand", Vector3.new(1.15, 0.2, 1.15), at(OX, TOP + 4.7, z), IRON, Enum.Material.Metal)
	part(m, "ObeliskLedge", Vector3.new(1.4, 0.3, 1.4), at(OX, TOP + 7.15, z), STONE_LIGHT, Enum.Material.Slate)
	local glow = lantern(m, at(OX, TOP + 7.75, z), GLOW)
	local f = Instance.new("Fire")
	f.Color = GLOW
	f.SecondaryColor = ARCANE
	f.Heat = 3
	f.Size = 1.5
	f.Parent = glow
end
-- the arch: two iron arcs from obelisk to obelisk with struts between them
local function archY(z, base, rise)
	local t = (z + 6.4) / 12.8
	return base + rise * math.sin(math.pi * t)
end
local N = 14
for k = 0, N - 1 do
	local z0, z1 = -6.4 + 12.8 * k / N, -6.4 + 12.8 * (k + 1) / N
	seg(m, "ArchOuter", v(OX, archY(z0, TOP + 8.4, 2.8), z0), v(OX, archY(z1, TOP + 8.4, 2.8), z1), 0.22, IRON, Enum.Material.Metal)
	seg(m, "ArchInner", v(OX, archY(z0, TOP + 7.8, 2.6), z0), v(OX, archY(z1, TOP + 7.8, 2.6), z1), 0.16, IRON, Enum.Material.Metal)
	if k % 2 == 1 then
		local yo, yi = archY(z1, TOP + 8.4, 2.8), archY(z1, TOP + 7.8, 2.6)
		part(m, "ArchStrut", Vector3.new(0.1, yo - yi, 0.1), at(OX, (yo + yi) / 2, z1), IRON, Enum.Material.Metal)
		part(m, "ArchRune", Vector3.new(0.12, 0.12, 0.12), at(OX, (yo + yi) / 2, z1) * CFrame.Angles(math.rad(45), 0, 0), GLOW, Enum.Material.Neon)
	end
end
local SKY = TOP + 11.55
part(m, "CrestSkull", Vector3.new(0.9, 0.95, 1.0), at(OX, SKY, 0), BONE, Enum.Material.Marble)
part(m, "CrestJaw", Vector3.new(0.7, 0.3, 0.7), at(OX - 0.05, SKY - 0.55, 0), BONE, Enum.Material.Marble)
for _, z in ipairs({ -0.22, 0.22 }) do
	part(m, "CrestEye", Vector3.new(0.05, 0.22, 0.22), at(OX - 0.46, SKY + 0.05, z), GLOW, Enum.Material.Neon)
end
for _, s in ipairs({ -1, 1 }) do
	part(m, "CrestWing", Vector3.new(0.12, 0.35, 1.4), at(OX, SKY - 0.1, s * 1.1) * CFrame.Angles(math.rad(-20 * s), 0, 0), IRON_LIGHT, Enum.Material.Metal)
end
-- the hanging sign
local sign = part(m, "Sign", Vector3.new(0.25, 1.3, 5.6), at(OX, TOP + 8.6, 0), BASALT, Enum.Material.Basalt)
part(m, "SignTrim", Vector3.new(0.3, 0.14, 5.8), at(OX, TOP + 7.95, 0), BRONZE, Enum.Material.Metal)
part(m, "SignTrim", Vector3.new(0.3, 0.14, 5.8), at(OX, TOP + 9.25, 0), BRONZE, Enum.Material.Metal)
for _, z in ipairs({ -2.2, 2.2 }) do
	local yTop = archY(z, TOP + 7.8, 2.6)
	part(m, "SignChain", Vector3.new(0.06, yTop - (TOP + 9.25), 0.06), at(OX, (yTop + TOP + 9.25) / 2, z), IRON, Enum.Material.Metal)
end
local gui = Instance.new("SurfaceGui")
gui.Face = Enum.NormalId.Left
gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
gui.PixelsPerStud = 60
gui.LightInfluence = 0
gui.Parent = sign
local text = Instance.new("TextLabel")
text.Size = UDim2.new(1, 0, 1, 0)
text.BackgroundTransparency = 1
text.Text = "GRAVES"
text.TextColor3 = GLOW
text.TextScaled = true
text.Font = Enum.Font.GothamBlack
text.Parent = gui

-- ============================================================
-- Place it on the plaza (local +X points away from the monument) and set the interaction anchor
-- ============================================================
m.Parent = decor
local dir = Vector3.new(math.sin(math.rad(DEG)), 0, -math.cos(math.rad(DEG)))
local pos = dir * RADIUS
local cf = CFrame.fromMatrix(Vector3.new(pos.X, floorTop, pos.Z), dir, Vector3.yAxis)
m:PivotTo(cf)

local anchor = shops:FindFirstChild("GraveShopkeeper")
if not anchor then
	anchor = Instance.new("Part")
	anchor.Name = "GraveShopkeeper"
	anchor.Parent = shops
end
anchor.Anchored = true
anchor.CanCollide = false
anchor.Transparency = 1
anchor.Size = Vector3.new(2.6, 1, 7)
anchor.CFrame = cf * CFrame.new(CX, 3.6, 0)
if not anchor:FindFirstChildOfClass("ProximityPrompt") then
	Instance.new("ProximityPrompt").Parent = anchor
end

local count = 0
for _, d in ipairs(m:GetDescendants()) do
	if d:IsA("BasePart") then count += 1 end
end
return "grave stall built: " .. count .. " parts"
