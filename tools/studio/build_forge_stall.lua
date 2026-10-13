-- Builds the Forge stall on the plaza: Workspace.HubDecor.Stall_ForgeKeeper (a magical spirit forge: anvil with a turning
-- magic circle above it, a spirit furnace, a ghostly smith, crucibles of the five dusts, a weapon rack) and the invisible
-- interaction anchor Workspace.Shops.ForgeKeeper (with its ProximityPrompt; the server wires it in ShopNpcs).
-- Run in Edit mode via the Studio MCP execute_luau. Safe to re-run (it replaces both).
-- The two magic circle layers are models tagged "SpinFx" (attribute SpinSpeed, rad/s); the client (Modules/WorldFx) turns
-- them around their PrimaryPart's up axis at runtime.

local CollectionService = game:GetService("CollectionService")

local floorTop = -1.7
local DEG = 202.5 -- plaza angle (same convention as build_coliseum.lua: dirAt(deg) = (sin, 0, -cos)); near the spawn
local RADIUS = 31

local STONE_DARK = Color3.fromRGB(58, 60, 72)
local STONE = Color3.fromRGB(88, 91, 106)
local STONE_LIGHT = Color3.fromRGB(122, 126, 142)
local BASALT = Color3.fromRGB(34, 34, 42)
local IRON = Color3.fromRGB(46, 48, 56)
local IRON_LIGHT = Color3.fromRGB(78, 82, 94)
local BRONZE = Color3.fromRGB(122, 92, 58)
local VERDIGRIS = Color3.fromRGB(86, 150, 130)
local WOOD_DARK = Color3.fromRGB(62, 44, 36)
local LEATHER = Color3.fromRGB(84, 56, 40)
local GLOW = Color3.fromRGB(120, 255, 190)
local GLOW_CYAN = Color3.fromRGB(110, 230, 255)
local SPIRIT = Color3.fromRGB(170, 255, 220)
local DUSTS = {
	Color3.fromRGB(150, 146, 140), -- Stone
	Color3.fromRGB(196, 204, 216), -- Silver
	Color3.fromRGB(232, 190, 90), -- Gold
	Color3.fromRGB(130, 220, 240), -- Diamond
	Color3.fromRGB(226, 150, 255), -- Star
}

local decor = workspace:FindFirstChild("HubDecor")
local shops = workspace:FindFirstChild("Shops")
assert(decor and shops, "HubDecor / Shops missing")
local old = decor:FindFirstChild("Stall_ForgeKeeper")
if old then old:Destroy() end

local origin = Vector3.new(0, floorTop, 0)
local m = Instance.new("Model")
m.Name = "Stall_ForgeKeeper"
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

-- ============================================================
-- Dais
-- ============================================================
solid(m, "DaisStep", Vector3.new(0.25, 15.6, 15.6), at(0, 0.125, 0) * UPRIGHT, STONE_DARK, Enum.Material.Cobblestone, Enum.PartType.Cylinder)
solid(m, "Dais", Vector3.new(0.45, 14.4, 14.4), at(0, 0.35, 0) * UPRIGHT, STONE, Enum.Material.Slate, Enum.PartType.Cylinder)
disc(m, "RuneRingGlow", 6.4, 0.04, at(0, 0.58, 0), GLOW, Enum.Material.Neon)
disc(m, "RuneRingInlay", 6.1, 0.06, at(0, 0.59, 0), STONE_DARK, Enum.Material.Slate)
local TOP = 0.62 -- top of the dais
-- rune marks around the inlay ring
for k = 0, 11 do
	local a = k / 12 * 2 * math.pi
	part(m, "RuneMark", Vector3.new(0.18, 0.05, 0.6), at(0, TOP, 0) * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -6.9), GLOW, Enum.Material.Neon)
end

-- ============================================================
-- Anvil (front centre) with ingot and hammer
-- ============================================================
local AX = -1.4
local anvil = Instance.new("Model")
anvil.Name = "Anvil"
anvil.Parent = m
solid(anvil, "Plinth", Vector3.new(2.6, 1.0, 3.4), at(AX, TOP + 0.5, 0), BASALT, Enum.Material.Basalt)
part(anvil, "PlinthBand", Vector3.new(2.7, 0.2, 3.5), at(AX, TOP + 0.85, 0), VERDIGRIS, Enum.Material.Metal)
local A0 = TOP + 1.0
solid(anvil, "Foot", Vector3.new(2.0, 0.45, 2.8), at(AX, A0 + 0.225, 0), IRON, Enum.Material.Metal)
part(anvil, "FootTaper", Vector3.new(1.6, 0.35, 2.2), at(AX, A0 + 0.62, 0), IRON, Enum.Material.Metal)
solid(anvil, "Waist", Vector3.new(1.1, 0.9, 1.6), at(AX, A0 + 1.25, 0), IRON, Enum.Material.Metal)
part(anvil, "Neck", Vector3.new(1.5, 0.3, 2.4), at(AX, A0 + 1.85, 0), IRON, Enum.Material.Metal)
solid(anvil, "Face", Vector3.new(1.9, 0.6, 3.6), at(AX, A0 + 2.3, -0.2), IRON_LIGHT, Enum.Material.Metal)
part(anvil, "Heel", Vector3.new(1.5, 0.45, 0.7), at(AX, A0 + 2.38, 1.9), IRON, Enum.Material.Metal)
-- the horn: a stack of shrinking cylinders pointing along -Z, then a tip
for k = 0, 4 do
	local r = 0.62 - k * 0.11
	part(anvil, "Horn", Vector3.new(0.42, r * 2, r * 2), at(AX, A0 + 2.42 - k * 0.04, -2.2 - k * 0.38) * CFrame.Angles(0, math.rad(90), 0), IRON_LIGHT, Enum.Material.Metal, Enum.PartType.Cylinder)
end
-- glowing runes on the anvil's front (-X) side and on the face
for k, dz in ipairs({ -0.9, 0, 0.9 }) do
	part(anvil, "Rune", Vector3.new(0.05, 0.42, 0.12), at(AX - 0.96, A0 + 2.3, dz - 0.2), GLOW, Enum.Material.Neon)
	part(anvil, "Rune", Vector3.new(0.05, 0.12, 0.34), at(AX - 0.96, A0 + 2.3 + (k % 2 == 0 and 0.12 or -0.12), dz - 0.2), GLOW, Enum.Material.Neon)
end
part(anvil, "WaistRune", Vector3.new(0.05, 0.6, 0.12), at(AX - 0.56, A0 + 1.25, 0), GLOW, Enum.Material.Neon)
local ingot = part(anvil, "Ingot", Vector3.new(0.55, 0.26, 1.3), at(AX - 0.1, A0 + 2.73, 0.3) * CFrame.Angles(0, math.rad(12), 0), GLOW, Enum.Material.Neon)
light(ingot, GLOW, 8, 0.6)
local sparks = Instance.new("ParticleEmitter")
sparks.Name = "Sparks"
sparks.Color = ColorSequence.new(GLOW, GLOW_CYAN)
sparks.LightEmission = 1
sparks.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.18), NumberSequenceKeypoint.new(1, 0) })
sparks.Lifetime = NumberRange.new(0.6, 1.2)
sparks.Rate = 10
sparks.Speed = NumberRange.new(2, 5)
sparks.SpreadAngle = Vector2.new(40, 40)
sparks.Acceleration = Vector3.new(0, -6, 0)
sparks.EmissionDirection = Enum.NormalId.Top
sparks.Parent = ingot
-- hammer lying across the face
part(anvil, "HammerHandle", Vector3.new(0.22, 0.22, 2.0), at(AX + 0.45, A0 + 2.72, -1.0) * CFrame.Angles(0, math.rad(-25), 0), WOOD_DARK, Enum.Material.Wood)
part(anvil, "HammerHead", Vector3.new(0.9, 0.45, 0.45), at(AX + 0.05, A0 + 2.82, -1.85) * CFrame.Angles(0, math.rad(-25), 0), IRON_LIGHT, Enum.Material.Metal)

-- ============================================================
-- Magic circle above the anvil (two layers that turn in opposite directions at runtime)
-- ============================================================
local CY = A0 + 5.6
-- tilted 55 degrees toward the front so players see the circle face-on; the layers spin around this tilted axis
local centre = at(AX, CY, 0) * CFrame.Angles(0, 0, math.rad(55))
local function spinLayer(name, speed)
	local layer = Instance.new("Model")
	layer.Name = name
	local hub = part(layer, "Hub", Vector3.new(0.2, 0.2, 0.2), centre, GLOW, Enum.Material.Neon)
	hub.Transparency = 1
	layer.PrimaryPart = hub
	layer:SetAttribute("SpinSpeed", speed)
	layer.ModelStreamingMode = Enum.ModelStreamingMode.Atomic -- the client spins it: all parts must arrive together
	CollectionService:AddTag(layer, "SpinFx")
	layer.Parent = m
	return layer
end
local outer = spinLayer("MagicCircleOuter", 0.45)
ring(outer, "OuterRing", 2.9, 44, 0.12, 0.05, centre, GLOW)
ring(outer, "OuterRing2", 2.6, 40, 0.06, 0.05, centre, GLOW_CYAN)
-- rune glyphs between the two outer rings, and small rune stones riding the outer ring
for k = 0, 11 do
	local a = k / 12 * 2 * math.pi
	local c = centre * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -2.75)
	part(outer, "Glyph", Vector3.new(0.08, 0.05, 0.22), c, GLOW, Enum.Material.Neon)
	part(outer, "Glyph", Vector3.new(0.2, 0.05, 0.06), c * CFrame.new(0, 0, (k % 2 == 0) and 0.08 or -0.08), GLOW, Enum.Material.Neon)
end
for k = 0, 5 do
	local a = k / 6 * 2 * math.pi + math.rad(15)
	part(outer, "RuneStone", Vector3.new(0.28, 0.28, 0.28), centre * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -3.25) * CFrame.Angles(math.rad(45), 0, math.rad(45)), GLOW_CYAN, Enum.Material.Neon)
end

local inner = spinLayer("MagicCircleInner", -0.8)
ring(inner, "InnerRing", 1.95, 32, 0.1, 0.05, centre, GLOW)
ring(inner, "CoreRing", 0.6, 14, 0.08, 0.05, centre, GLOW_CYAN)
-- hexagram inscribed in the inner ring
for t = 0, 1 do
	local pts = {}
	for k = 0, 2 do
		local a = (k / 3) * 2 * math.pi + t * math.pi
		pts[k + 1] = Vector3.new(math.sin(a) * 1.9, 0, -math.cos(a) * 1.9)
	end
	for k = 1, 3 do
		bar(inner, "Hexagram", pts[k], pts[k % 3 + 1], 0.07, 0.05, centre, GLOW)
	end
end
-- spokes from the core ring to the inner ring
for k = 0, 5 do
	local a = k / 6 * 2 * math.pi + math.pi / 6
	local d = Vector3.new(math.sin(a), 0, -math.cos(a))
	bar(inner, "Spoke", d * 0.65, d * 1.15, 0.05, 0.05, centre, GLOW_CYAN)
end
-- the beam of light between the circle and the ingot
local beam = part(m, "CircleBeam", Vector3.new(CY - (A0 + 2.8), 0.35, 0.35), at(AX, (CY + A0 + 2.8) / 2, 0) * UPRIGHT, GLOW, Enum.Material.Neon, Enum.PartType.Cylinder)
beam.Transparency = 0.75

-- ============================================================
-- Spirit furnace (back) with chimney and soul fire
-- ============================================================
local FX = 4.4
solid(m, "Furnace", Vector3.new(3.0, 4.6, 5.4), at(FX, TOP + 2.3, 0), STONE_DARK, Enum.Material.Cobblestone)
part(m, "FurnaceCorner", Vector3.new(3.3, 4.8, 0.5), at(FX, TOP + 2.4, -2.75), STONE_LIGHT, Enum.Material.Slate)
part(m, "FurnaceCorner", Vector3.new(3.3, 4.8, 0.5), at(FX, TOP + 2.4, 2.75), STONE_LIGHT, Enum.Material.Slate)
part(m, "FurnaceTop", Vector3.new(3.4, 0.4, 6.0), at(FX, TOP + 4.8, 0), STONE_LIGHT, Enum.Material.Slate)
for _, y in ipairs({ TOP + 1.0, TOP + 3.9 }) do
	part(m, "Band", Vector3.new(3.1, 0.25, 5.5), at(FX, y, 0), VERDIGRIS, Enum.Material.Metal)
end
-- the arched mouth on the front (-X) face
local MX = FX - 1.52
part(m, "MouthBack", Vector3.new(0.1, 2.0, 2.4), at(MX + 0.02, TOP + 1.9, 0), BASALT, Enum.Material.Basalt)
local fireGlow = part(m, "SoulFire", Vector3.new(0.08, 1.4, 2.0), at(MX - 0.03, TOP + 1.65, 0), GLOW, Enum.Material.Neon)
for k = 0, 6 do
	local a = math.rad(-90 + k * 30)
	local x, y = math.sin(a) * 1.35, math.cos(a) * 1.35
	part(m, "ArchStone", Vector3.new(0.35, 0.45, 0.5), at(MX - 0.12, TOP + 2.85 + y * 0.75, x) * CFrame.Angles(-a, 0, 0), STONE_LIGHT, Enum.Material.Slate)
end
part(m, "ArchKey", Vector3.new(0.4, 0.55, 0.55), at(MX - 0.15, TOP + 3.95, 0), VERDIGRIS, Enum.Material.Metal)
part(m, "Sill", Vector3.new(0.6, 0.25, 2.8), at(MX - 0.2, TOP + 0.85, 0), STONE_LIGHT, Enum.Material.Slate)
local fire = Instance.new("Fire")
fire.Color = GLOW
fire.SecondaryColor = GLOW_CYAN
fire.Heat = 6
fire.Size = 4
fire.Parent = fireGlow
light(fireGlow, GLOW, 10, 0.8)
-- rune columns on the furnace sides
for _, side in ipairs({ -1, 1 }) do
	for k = 0, 3 do
		part(m, "FurnaceRune", Vector3.new(0.6, 0.12, 0.05), at(FX, TOP + 1.4 + k * 0.7, side * 2.73), GLOW, Enum.Material.Neon)
	end
end
-- chimney
part(m, "Chimney", Vector3.new(2.0, 4.2, 2.6), at(FX + 0.3, TOP + 7.1, 0), STONE, Enum.Material.Cobblestone)
part(m, "ChimneyBand", Vector3.new(2.15, 0.25, 2.75), at(FX + 0.3, TOP + 6.0, 0), VERDIGRIS, Enum.Material.Metal)
part(m, "ChimneyCap", Vector3.new(2.6, 0.4, 3.2), at(FX + 0.3, TOP + 9.4, 0), STONE_LIGHT, Enum.Material.Slate)
local flue = part(m, "Flue", Vector3.new(1.4, 0.1, 1.8), at(FX + 0.3, TOP + 9.62, 0), GLOW, Enum.Material.Neon)
local smoke = Instance.new("ParticleEmitter")
smoke.Name = "SoulSmoke"
smoke.Color = ColorSequence.new(GLOW, Color3.fromRGB(40, 70, 70))
smoke.LightEmission = 0.6
smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1) })
smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 2.2) })
smoke.Lifetime = NumberRange.new(2.5, 4)
smoke.Rate = 6
smoke.Speed = NumberRange.new(1.5, 2.5)
smoke.SpreadAngle = Vector2.new(12, 12)
smoke.Rotation = NumberRange.new(0, 360)
smoke.RotSpeed = NumberRange.new(-30, 30)
smoke.EmissionDirection = Enum.NormalId.Top
smoke.Parent = flue

-- ============================================================
-- The ghostly smith (between anvil and furnace), hammer raised
-- ============================================================
local SX = 1.3
local function ghost(name, size, cf, color)
	local p = part(m, name, size, cf, color or SPIRIT, Enum.Material.SmoothPlastic)
	p.Transparency = 0.35
	return p
end
ghost("Robe", Vector3.new(1.8, 2.8, 1.8), at(SX, TOP + 1.5, 0))
ghost("RobeHem", Vector3.new(2.2, 0.6, 2.2), at(SX, TOP + 0.35, 0))
part(m, "Apron", Vector3.new(0.12, 2.2, 1.2), at(SX - 0.95, TOP + 1.6, 0), LEATHER, Enum.Material.Fabric)
ghost("Shoulders", Vector3.new(2.0, 0.7, 2.6), at(SX, TOP + 3.2, 0))
ghost("Hood", Vector3.new(1.6, 1.6, 1.6), at(SX, TOP + 4.15, 0))
part(m, "Face", Vector3.new(0.1, 1.0, 1.1), at(SX - 0.78, TOP + 4.05, 0), Color3.fromRGB(10, 14, 16), Enum.Material.SmoothPlastic)
for _, dz in ipairs({ -0.26, 0.26 }) do
	part(m, "Eye", Vector3.new(0.1, 0.2, 0.24), at(SX - 0.82, TOP + 4.1, dz), GLOW, Enum.Material.Neon)
end
-- left arm resting toward the anvil, right arm raising a hammer
ghost("ArmL", Vector3.new(1.7, 0.5, 0.5), at(SX - 0.8, TOP + 2.9, 1.3) * CFrame.Angles(0, 0, math.rad(-20)))
ghost("ArmR", Vector3.new(0.5, 1.7, 0.5), at(SX - 0.3, TOP + 4.0, -1.35) * CFrame.Angles(math.rad(-10), 0, math.rad(25)))
part(m, "RaisedHammerHandle", Vector3.new(0.2, 2.0, 0.2), at(SX - 0.9, TOP + 5.0, -1.45) * CFrame.Angles(0, 0, math.rad(55)), WOOD_DARK, Enum.Material.Wood)
part(m, "RaisedHammerHead", Vector3.new(0.5, 0.5, 1.0), at(SX - 1.7, TOP + 5.6, -1.45) * CFrame.Angles(0, 0, math.rad(55)), IRON_LIGHT, Enum.Material.Metal)
local wisps = Instance.new("ParticleEmitter")
wisps.Name = "Wisps"
wisps.Color = ColorSequence.new(SPIRIT)
wisps.LightEmission = 0.8
wisps.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1) })
wisps.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 0) })
wisps.Lifetime = NumberRange.new(1, 2)
wisps.Rate = 5
wisps.Speed = NumberRange.new(0.3, 0.8)
wisps.EmissionDirection = Enum.NormalId.Top
wisps.Parent = m:FindFirstChild("RobeHem")

-- ============================================================
-- Left side (-Z): shelf with crucibles of the five dusts
-- ============================================================
local SZ = -5.2
part(m, "ShelfLeg", Vector3.new(0.35, 2.4, 0.35), at(-2.2, TOP + 1.2, SZ), WOOD_DARK, Enum.Material.Wood)
part(m, "ShelfLeg", Vector3.new(0.35, 2.4, 0.35), at(2.2, TOP + 1.2, SZ), WOOD_DARK, Enum.Material.Wood)
solid(m, "Shelf", Vector3.new(5.0, 0.25, 1.4), at(0, TOP + 2.4, SZ), WOOD_DARK, Enum.Material.Wood)
part(m, "ShelfLow", Vector3.new(5.0, 0.2, 1.4), at(0, TOP + 0.9, SZ), WOOD_DARK, Enum.Material.Wood)
for k, color in ipairs(DUSTS) do
	local x = -2.0 + (k - 1) * 1.0
	disc(m, "Crucible", 0.38, 0.5, at(x, TOP + 2.77, SZ), IRON, Enum.Material.Metal)
	disc(m, "CrucibleRim", 0.43, 0.08, at(x, TOP + 3.02, SZ), BRONZE, Enum.Material.Metal)
	local dust = part(m, "Dust", Vector3.new(0.5, 0.5, 0.5), at(x, TOP + 3.05, SZ), color, Enum.Material.Neon, Enum.PartType.Ball)
	dust.Size = Vector3.new(0.6, 0.3, 0.6)
	-- sacks on the low shelf
	part(m, "Sack", Vector3.new(0.7, 0.8, 0.7), at(x, TOP + 1.4, SZ) * CFrame.Angles(0, math.rad(k * 23), 0), Color3.fromRGB(96, 80, 62), Enum.Material.Fabric)
	part(m, "SackTie", Vector3.new(0.4, 0.15, 0.4), at(x, TOP + 1.85, SZ), color, Enum.Material.Neon)
end

-- ============================================================
-- Right side (+Z): weapon rack and quench trough
-- ============================================================
local RZ = 5.2
for _, x in ipairs({ -1.8, 1.8 }) do
	part(m, "RackPost", Vector3.new(0.3, 3.4, 0.3), at(x, TOP + 1.7, RZ), WOOD_DARK, Enum.Material.Wood)
end
part(m, "RackBar", Vector3.new(4.0, 0.25, 0.25), at(0, TOP + 3.3, RZ), WOOD_DARK, Enum.Material.Wood)
for k, x in ipairs({ -1.0, 0, 1.0 }) do
	local tilt = CFrame.Angles(0, 0, math.rad((k - 2) * 6))
	part(m, "Blade", Vector3.new(0.2, 2.2, 0.06), at(x, TOP + 2.0, RZ - 0.18) * tilt, IRON_LIGHT, Enum.Material.Metal)
	part(m, "Guard", Vector3.new(0.7, 0.14, 0.14), at(x, TOP + 3.15, RZ - 0.18) * tilt, BRONZE, Enum.Material.Metal)
	part(m, "Grip", Vector3.new(0.14, 0.5, 0.14), at(x, TOP + 3.45, RZ - 0.18) * tilt, LEATHER, Enum.Material.Fabric)
	part(m, "BladeRune", Vector3.new(0.06, 1.2, 0.07), at(x, TOP + 2.1, RZ - 0.2) * tilt, GLOW, Enum.Material.Neon)
end
solid(m, "Trough", Vector3.new(2.6, 0.9, 1.2), at(-3.6, TOP + 0.45, RZ - 0.4), STONE, Enum.Material.Slate)
local water = part(m, "QuenchWater", Vector3.new(2.3, 0.08, 0.9), at(-3.6, TOP + 0.86, RZ - 0.4), GLOW_CYAN, Enum.Material.Neon)
water.Transparency = 0.35

-- ============================================================
-- Front pillars with braziers and the FORGE lintel
-- ============================================================
for _, z in ipairs({ -6.0, 6.0 }) do
	solid(m, "PillarBase", Vector3.new(1.6, 0.6, 1.6), at(-5.2, TOP + 0.3, z), STONE_LIGHT, Enum.Material.Slate)
	solid(m, "Pillar", Vector3.new(1.1, 8.4, 1.1), at(-5.2, TOP + 4.8, z), STONE, Enum.Material.Cobblestone)
	part(m, "PillarBand", Vector3.new(1.25, 0.25, 1.25), at(-5.2, TOP + 3.0, z), VERDIGRIS, Enum.Material.Metal)
	part(m, "PillarRune", Vector3.new(0.05, 1.6, 0.18), at(-5.78, TOP + 4.6, z), GLOW, Enum.Material.Neon)
	disc(m, "Brazier", 0.75, 0.5, at(-5.2, TOP + 9.25, z), BRONZE, Enum.Material.Metal)
	local flame = part(m, "BrazierFlame", Vector3.new(0.7, 0.7, 0.7), at(-5.2, TOP + 9.75, z), GLOW, Enum.Material.Neon, Enum.PartType.Ball)
	light(flame, GLOW, 8, 0.5)
	local f = Instance.new("Fire")
	f.Color = GLOW
	f.SecondaryColor = GLOW_CYAN
	f.Heat = 4
	f.Size = 2
	f.Parent = flame
end
local sign = solid(m, "Lintel", Vector3.new(1.2, 1.1, 13.2), at(-5.2, TOP + 8.4, 0), BASALT, Enum.Material.Basalt)
part(m, "LintelTrim", Vector3.new(1.3, 0.2, 13.4), at(-5.2, TOP + 7.75, 0), VERDIGRIS, Enum.Material.Metal)
local gui = Instance.new("SurfaceGui")
gui.Face = Enum.NormalId.Left
gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
gui.PixelsPerStud = 60
gui.LightInfluence = 0
gui.Parent = sign
local text = Instance.new("TextLabel")
text.Size = UDim2.new(1, 0, 1, 0)
text.BackgroundTransparency = 1
text.Text = "FORGE"
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

local anchor = shops:FindFirstChild("ForgeKeeper")
if not anchor then
	anchor = Instance.new("Part")
	anchor.Name = "ForgeKeeper"
	anchor.Parent = shops
end
anchor.Anchored = true
anchor.CanCollide = false
anchor.Transparency = 1
anchor.Size = Vector3.new(2.6, 1, 4)
anchor.CFrame = cf * CFrame.new(AX, 3.6, 0)
if not anchor:FindFirstChildOfClass("ProximityPrompt") then
	Instance.new("ProximityPrompt").Parent = anchor
end

local count = 0
for _, d in ipairs(m:GetDescendants()) do
	if d:IsA("BasePart") then count += 1 end
end
return "forge stall built: " .. count .. " parts"
