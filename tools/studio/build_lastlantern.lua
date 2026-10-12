-- Builds the low-poly rigged Last Lantern into ServerStorage.Models.LastLantern.
-- Run in Studio's command bar / via the Studio MCP execute_luau (Edit mode). Safe to re-run.
--
-- The first PRIMORDIAL unit and the first artillery: a colossal ancient tower that rises out of the ground far
-- behind the warband (see Units.LastLantern: static, size 4 so the game scales it x1.8 to ~46 studs) and burns the
-- wall with a ray of souls (AttackStyle = "BeamCast", see Army "Beams" and client SpellEffects).
--
-- Rig: not humanoid. Joint "Root" (HumanoidRootPart -> Body) lets UnitAnimator sink and raise the whole tower
-- (RiseStart / RiseTime). Joints named Spin... (SpinRingA/B/C, attribute SpinSpeed in rad/s) turn the three rune rings
-- round the soul core all the time. Attributes: Rig = "Procedural", RootHeight, Height, AttackStyle = "BeamCast",
-- CastColor (the ray), CastPart = "BeamMuzzle" (the invisible part in front of the core that the ray starts from).
--
-- Colour scheme (the "primordial" look): ancient black basalt and mossy green stone, aged bone, verdigris bronze,
-- spectral soul-green light, dark roots and moss, and a few prismatic gems (violet, gold, cyan, rose) that hint at the
-- shimmering Primordial rarity colour.
-- Layout (y, in model studs before the x1.8 scale): plinth 0-1.65, shaft 1.65-10.8, gallery deck 10.8-11.3, soul lantern
-- (core at 14.2) held by seven bone claws up to 18, crown 18-18.5, spire to 26. Front = -Z (the beam leaves that way).
local ServerStorage = game:GetService("ServerStorage")
local models = ServerStorage.Models

local old = models:FindFirstChild("LastLantern")
if old then
	old:Destroy()
end

local BASALT_D = Color3.fromRGB(20, 22, 26)
local BASALT = Color3.fromRGB(38, 41, 44)
local STONE_G = Color3.fromRGB(46, 54, 50)
local MOSS = Color3.fromRGB(70, 110, 58)
local ROOT = Color3.fromRGB(78, 54, 38)
local ROOT_D = Color3.fromRGB(52, 38, 30)
local BONE = Color3.fromRGB(186, 176, 148)
local BONE_D = Color3.fromRGB(126, 118, 98)
local CLAW_A = Color3.fromRGB(158, 148, 122) -- the bone claws are darker than the other bone so the soul core shines against them
local CLAW_B = Color3.fromRGB(110, 102, 84)
local VERD = Color3.fromRGB(74, 140, 120)
local BRONZE_D = Color3.fromRGB(94, 80, 56)
local VOID = Color3.fromRGB(8, 12, 10)
local SOUL = Color3.fromRGB(120, 255, 170)
local SOUL_PALE = Color3.fromRGB(214, 255, 230)
local GEMS = { Color3.fromRGB(176, 104, 255), Color3.fromRGB(255, 204, 92), Color3.fromRGB(96, 224, 255), Color3.fromRGB(255, 124, 204) }
local NEON = Enum.Material.Neon
local METAL = Enum.Material.Metal

local model = Instance.new("Model")
model.Name = "LastLantern"

local function part(name, size, cf, color, material, transparency)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = typeof(cf) == "Vector3" and CFrame.new(cf) or cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Transparency = transparency or 0
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = false
	p.CanQuery = false
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
	return w
end

local function motor(name, p0, p1, jointPos)
	local m = Instance.new("Motor6D")
	m.Name = name
	m.Part0 = p0
	m.Part1 = p1
	m.C0 = p0.CFrame:Inverse() * CFrame.new(jointPos)
	m.C1 = p1.CFrame:Inverse() * CFrame.new(jointPos)
	m.Parent = p1
	return m
end

-- angle 0 is the front (-Z); angles go clockwise seen from above
local function polar(r, a, y)
	return Vector3.new(math.sin(a) * r, y, -math.cos(a) * r)
end
local function outward(a)
	return Vector3.new(math.sin(a), 0, -math.cos(a))
end
-- a CFrame at `pos` whose front (-Z) points away from the tower's axis
local function facing(pos, a)
	return CFrame.lookAt(pos, pos + outward(a))
end

-- upright cylinder: diameter, height, y of its bottom
local function cylinder(name, diameter, height, bottomY, color, material, transparency)
	local p = part(name, Vector3.new(height, diameter, diameter), CFrame.new(0, bottomY + height / 2, 0) * CFrame.Angles(0, 0, math.rad(90)), color, material, transparency)
	p.Shape = Enum.PartType.Cylinder
	return p
end

local function ball(name, diameter, pos, color, material, transparency)
	local p = part(name, Vector3.one * diameter, CFrame.new(pos), color, material, transparency)
	p.Shape = Enum.PartType.Ball
	return p
end

-- ── Core / rig ────────────────────────────────────────────────
local root = part("HumanoidRootPart", Vector3.new(2, 1, 2), Vector3.new(0, 2, 0), BASALT_D)
root.Transparency = 1
model.PrimaryPart = root

-- the central pillar everything hangs from: Root moves it (the whole tower sinks and rises)
local body = cylinder("Body", 4.4, 12.4, 1.6, BASALT_D)
motor("Root", root, body, Vector3.new(0, 2, 0))

-- ── Plinth: three steps, a verdigris rim and a glowing rune ring ──
weld(body, cylinder("Plinth1", 11.6, 0.55, 0.0, BASALT_D))
weld(body, cylinder("Plinth2", 10.4, 0.55, 0.55, BASALT))
weld(body, cylinder("PlinthRim", 10.7, 0.14, 1.05, VERD, METAL))
weld(body, cylinder("Plinth3", 9.2, 0.55, 1.1, STONE_G))
weld(body, cylinder("PlinthRune", 8.7, 0.06, 1.64, SOUL, NEON))

-- ── Shaft: tapering drums separated by bone and bronze bands ──
weld(body, cylinder("Shaft1", 6.8, 3.15, 1.65, BASALT))
weld(body, cylinder("Band1", 7.3, 0.4, 4.6, BONE))
weld(body, cylinder("Shaft2", 6.2, 3.4, 4.8, STONE_G))
weld(body, cylinder("Band2", 6.8, 0.4, 8.0, VERD, METAL))
weld(body, cylinder("Shaft3", 5.6, 2.6, 8.2, BASALT))
weld(body, cylinder("Band3", 6.4, 0.45, 10.6, BONE))
local SHAFT_R = { { 4.8, 3.4 }, { 8.2, 3.1 }, { 10.8, 2.8 } } -- up to this y the shaft has this radius
local function shaftRadius(y)
	for _, s in ipairs(SHAFT_R) do
		if y <= s[1] then
			return s[2]
		end
	end
	return 2.8
end

-- arched windows with glowing soul slits on the first two drums
for section, y in ipairs({ 3.2, 6.3 }) do
	local r = (section == 1) and 3.4 or 3.1
	for i = 0, 7 do
		local a = math.rad(i * 45 + 22.5)
		weld(body, part("WindowFrame", Vector3.new(0.75, 1.8, 0.16), facing(polar(r + 0.02, a, y), a), BRONZE_D, METAL))
		weld(body, part("WindowArch", Vector3.new(0.55, 0.3, 0.2), facing(polar(r + 0.03, a, y + 1.0), a), BONE_D))
		weld(body, part("WindowSlit", Vector3.new(0.3, 1.4, 0.08), facing(polar(r + 0.1, a, y), a), SOUL, NEON))
	end
end

-- a frieze of skulls round the third drum
for i = 0, 9 do
	local a = math.rad(i * 36 + 18)
	local base = polar(2.85, a, 9.4)
	local cf = facing(base, a)
	weld(body, part("Skull", Vector3.new(0.72, 0.7, 0.66), cf, BONE))
	for _, dx in ipairs({ -0.18, 0.18 }) do
		weld(body, part("SkullEye", Vector3.new(0.18, 0.2, 0.1), cf * CFrame.new(dx, 0.08, -0.33), VOID))
	end
	weld(body, part("SkullNose", Vector3.new(0.1, 0.14, 0.1), cf * CFrame.new(0, -0.08, -0.33), VOID))
	weld(body, part("SkullJaw", Vector3.new(0.5, 0.2, 0.5), cf * CFrame.new(0, -0.4, -0.1), BONE_D))
end

-- the front door: bone posts and lintel, a dark doorway with a glowing slit and bronze studs
local doorY = 3.0
weld(body, part("DoorWay", Vector3.new(1.7, 2.7, 0.3), facing(polar(3.4, 0, doorY), 0), VOID))
for _, x in ipairs({ -1.1, 1.1 }) do
	weld(body, part("DoorPost", Vector3.new(0.5, 3.0, 0.55), CFrame.new(x, doorY + 0.1, -3.45), BONE))
end
weld(body, part("DoorLintel", Vector3.new(2.8, 0.5, 0.6), CFrame.new(0, doorY + 1.75, -3.45), BONE))
weld(body, part("DoorGlow", Vector3.new(0.2, 2.3, 0.06), CFrame.new(0, doorY, -3.6), SOUL, NEON))
for i = 1, 3 do
	weld(body, part("DoorStud", Vector3.new(0.2, 0.2, 0.1), CFrame.new(-0.55, doorY - 0.8 + i * 0.6, -3.62), VERD, METAL))
	weld(body, part("DoorStud", Vector3.new(0.2, 0.2, 0.1), CFrame.new(0.55, doorY - 0.8 + i * 0.6, -3.62), VERD, METAL))
end

-- ── Standing stones round the plinth, each with a glowing rune facing the tower ──
for i = 0, 7 do
	local a = math.rad(i * 45)
	local pos = polar(6.9, a, 0)
	weld(body, part("StandingStone", Vector3.new(0.9, 3.4, 0.9), CFrame.new(pos + Vector3.new(0, 1.7, 0)), BASALT))
	weld(body, part("StoneCap", Vector3.new(0.6, 0.5, 0.6), CFrame.new(pos + Vector3.new(0, 3.65, 0)), BONE_D))
	weld(body, part("StoneMoss", Vector3.new(1.3, 0.16, 1.3), CFrame.new(pos + Vector3.new(0, 0.08, 0)), MOSS))
	local inward = -outward(a)
	local rp = pos + Vector3.new(0, 1.9, 0) + inward * 0.47
	weld(body, part("StoneRune", Vector3.new(0.14, 1.8, 0.06), CFrame.lookAt(rp, rp + inward), SOUL, NEON))
end

-- ── Root buttresses climbing the first drum ──────────────────
for i = 0, 7 do
	local a = math.rad(i * 45 + 22.5)
	weld(body, part("RootA", Vector3.new(1.5, 1.6, 2.4), facing(polar(4.7, a, 1.2), a), ROOT))
	weld(body, part("RootB", Vector3.new(1.1, 1.2, 2.0), facing(polar(3.95, a, 2.5), a), ROOT_D))
	weld(body, part("RootC", Vector3.new(0.8, 0.9, 1.5), facing(polar(3.45, a, 3.6), a), ROOT))
	weld(body, part("RootMoss", Vector3.new(1.3, 0.18, 2.2), facing(polar(4.7, a, 2.05), a), MOSS))
end

-- ── A root and vine spiralling up the shaft, with tufts of moss ──
for i = 0, 29 do
	local y = 1.9 + i * 0.29
	local a = math.rad(i * 36)
	local r = shaftRadius(y) + 0.22
	local pos = polar(r, a, y)
	local tangent = Vector3.new(math.cos(a), 0.45, math.sin(a))
	weld(body, part("Vine", Vector3.new(0.5, 0.5, 1.25), CFrame.lookAt(pos, pos + tangent), (i % 2 == 0) and ROOT or ROOT_D))
	if i % 3 == 0 then
		weld(body, part("VineMoss", Vector3.new(0.6, 0.4, 0.6), CFrame.new(pos + outward(a) * 0.25 + Vector3.new(0, 0.2, 0)), MOSS))
	end
end

-- ── Gallery deck with corbels, a bone rim and hanging chains with small soul lanterns ──
weld(body, cylinder("Deck", 8.6, 0.5, 10.8, BASALT_D))
weld(body, cylinder("DeckRim", 9.0, 0.2, 11.2, BONE_D))
for i = 0, 11 do
	local a = math.rad(i * 30)
	weld(body, part("Corbel", Vector3.new(0.9, 0.9, 1.4), facing(polar(3.55, a, 10.35), a), BASALT))
end
for i = 0, 3 do
	local a = math.rad(i * 90 + 45)
	local top = polar(3.9, a, 10.7)
	for link = 0, 8 do
		local flat = link % 2 == 0
		weld(body, part("ChainLink", flat and Vector3.new(0.18, 0.4, 0.1) or Vector3.new(0.1, 0.4, 0.18), CFrame.new(top.X, 10.6 - link * 0.42, top.Z), BRONZE_D, METAL))
	end
	local ly = 6.55
	weld(body, part("LanternCap", Vector3.new(0.55, 0.15, 0.55), CFrame.new(top.X, ly + 0.5, top.Z), VERD, METAL))
	weld(body, part("LanternGlass", Vector3.new(0.5, 0.7, 0.5), CFrame.new(top.X, ly, top.Z), SOUL, NEON, 0.2))
	weld(body, part("LanternBase", Vector3.new(0.45, 0.15, 0.45), CFrame.new(top.X, ly - 0.42, top.Z), VERD, METAL))
end

-- ── Seven bone claws cradling the lantern (the front stays open for the ray) ──
local CLAW = { -- radius, bottom y, height, width
	{ 3.9, 11.3, 1.8, 0.95 },
	{ 3.5, 13.1, 1.6, 0.85 },
	{ 3.0, 14.7, 1.4, 0.75 },
	{ 2.4, 16.1, 1.1, 0.6 },
	{ 1.8, 17.2, 0.8, 0.4 },
}
for i = 1, 7 do
	local a = math.rad(i * 360 / 8)
	for n, seg in ipairs(CLAW) do
		local r, y0, h, w = seg[1], seg[2], seg[3], seg[4]
		local cf = facing(polar(r, a, y0 + h / 2), a)
		weld(body, part("ClawBone", Vector3.new(w, h, w), cf, (n % 2 == 1) and CLAW_A or CLAW_B))
		weld(body, part("ClawRidge", Vector3.new(w * 0.2, h * 0.9, 0.12), cf * CFrame.new(0, 0, -(w / 2 + 0.04)), BONE_D))
		if n <= 3 then
			weld(body, part("ClawSeam", Vector3.new(0.08, h * 0.85, 0.05), cf * CFrame.new(0, 0, w / 2 + 0.02), SOUL, NEON))
		end
	end
end

-- ── Crown and spire ───────────────────────────────────────────
weld(body, cylinder("Crown", 4.2, 0.5, 18.0, BASALT_D))
weld(body, cylinder("CrownRim", 4.6, 0.2, 18.3, BONE))
for i = 0, 7 do
	local a = math.rad(i * 45)
	weld(body, part("CrownSpike", Vector3.new(0.3, 1.0, 0.3), CFrame.new(polar(2.1, a, 19.0)), BONE))
end
local spire = {
	{ 1.4, 2.2, 18.5 },
	{ 1.0, 2.0, 20.7 },
	{ 0.6, 1.6, 22.7 },
}
for n, seg in ipairs(spire) do
	local w, h, y0 = seg[1], seg[2], seg[3]
	weld(body, part("Spire", Vector3.new(w, h, w), CFrame.new(0, y0 + h / 2, 0), (n % 2 == 1) and BASALT or STONE_G))
	weld(body, part("SpireTurn", Vector3.new(w, h, w), CFrame.new(0, y0 + h / 2, 0) * CFrame.Angles(0, math.rad(45), 0), (n % 2 == 1) and STONE_G or BASALT))
	if n <= 2 then
		for k = 0, 3 do
			local ka = math.rad(k * 90)
			weld(body, part("SpireRune", Vector3.new(0.12, h * 0.75, 0.06), facing(polar(w / 2 + 0.03, ka, y0 + h / 2), ka), SOUL, NEON))
		end
	end
end
weld(body, part("SpireNeedle", Vector3.new(0.25, 1.2, 0.25), CFrame.new(0, 24.9, 0), VERD, METAL))
for k = 1, 4 do
	local a = math.rad(k * 90 + 20)
	weld(body, part("PrismGem", Vector3.new(0.38, 0.38, 0.38), CFrame.new(polar(0.85, a, 25.0 + (k % 2) * 0.5)) * CFrame.Angles(math.rad(35), math.rad(k * 20), math.rad(35)), GEMS[k], NEON))
end

-- ── The lantern: pedestal, soul core with a slit pupil, three turning rune rings ──
weld(body, cylinder("Pedestal1", 3.4, 0.4, 11.3, BONE_D))
weld(body, cylinder("Pedestal2", 2.6, 0.5, 11.7, BONE))
weld(body, cylinder("Pedestal3", 1.6, 0.6, 12.2, BONE_D))
local core = ball("SoulCore", 2.7, Vector3.new(0, 14.2, 0), SOUL, NEON)
weld(body, core)
weld(body, ball("SoulShell", 3.5, Vector3.new(0, 14.2, 0), SOUL, NEON, 0.78))
weld(body, part("Pupil", Vector3.new(0.32, 2.0, 0.12), CFrame.new(0, 14.2, -1.38), VOID))
local iris = part("Iris", Vector3.new(0.1, 2.3, 2.3), CFrame.new(0, 14.2, -1.3) * CFrame.Angles(0, math.rad(90), 0), SOUL_PALE, NEON)
iris.Shape = Enum.PartType.Cylinder
weld(body, iris)
local muzzle = part("BeamMuzzle", Vector3.new(0.5, 0.5, 0.5), CFrame.new(0, 14.2, -1.9), SOUL, NEON)
muzzle.Transparency = 1
weld(body, muzzle)

-- rings: each hangs off its own invisible root joined to the body by a Spin joint (UnitAnimator turns them)
local function ring(name, y, diameter, speed)
	local spinRoot = part(name .. "Root", Vector3.new(0.3, 0.3, 0.3), CFrame.new(0, y, 0), BONE)
	spinRoot.Transparency = 1
	local m = motor("Spin" .. name, body, spinRoot, Vector3.new(0, y, 0))
	m:SetAttribute("SpinSpeed", speed)
	local disc = cylinder(name .. "Disc", diameter, 0.14, y - 0.07, SOUL_PALE, NEON, 0.25)
	weld(spinRoot, disc)
	return spinRoot
end

local ringA = ring("RingA", 14.2, 5.4, 0.7)
for i = 0, 11 do
	local a = math.rad(i * 30)
	local pos = polar(2.7, a, 14.2)
	weld(ringA, part("RingRune", Vector3.new(0.32, 0.16, 0.5), facing(pos, a), (i % 3 == 0) and GEMS[(i // 3) % 4 + 1] or VERD, (i % 3 == 0) and NEON or METAL))
end
local ringB = ring("RingB", 15.3, 4.4, -1.1)
for i = 0, 7 do
	local a = math.rad(i * 45 + 10)
	weld(ringB, part("RingCrystal", Vector3.new(0.2, 0.6, 0.2), CFrame.new(polar(2.2, a, 15.6)), GEMS[i % 4 + 1], NEON))
end
local ringC = ring("RingC", 13.1, 4.0, 1.6)
for i = 0, 5 do
	local a = math.rad(i * 60)
	weld(ringC, part("RingDiamond", Vector3.new(0.3, 0.3, 0.3), CFrame.new(polar(2.0, a, 13.1)) * CFrame.Angles(math.rad(45), math.rad(45), 0), GEMS[(i + 1) % 4 + 1], NEON))
end

-- ── Ambient life: green light, rising soul sparks, a low mist round the plinth ──
local light = Instance.new("PointLight")
light.Name = "LanternLight"
light.Color = SOUL
light.Range = 35
light.Brightness = 0.7
light.Shadows = false
light.Parent = core

local sparks = Instance.new("ParticleEmitter")
sparks.Name = "SoulSparks"
sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
sparks.Color = ColorSequence.new(SOUL_PALE, SOUL)
sparks.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
sparks.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
sparks.LightEmission = 1
sparks.Lifetime = NumberRange.new(1.5, 2.8)
sparks.Rate = 9
sparks.Speed = NumberRange.new(1, 3)
sparks.EmissionDirection = Enum.NormalId.Top
sparks.SpreadAngle = Vector2.new(40, 40)
sparks.Shape = Enum.ParticleEmitterShape.Sphere
sparks.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
sparks.Parent = core

local mistPart = part("BaseMist", Vector3.new(11, 0.5, 11), CFrame.new(0, 1.9, 0), SOUL, nil, 1)
weld(body, mistPart)
local mist = Instance.new("ParticleEmitter")
mist.Name = "BaseMist"
mist.Texture = "rbxasset://textures/particles/smoke_main.dds"
mist.Color = ColorSequence.new(Color3.fromRGB(150, 230, 190), Color3.fromRGB(60, 120, 90))
mist.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 4), NumberSequenceKeypoint.new(1, 9) })
mist.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(0.5, 0.82), NumberSequenceKeypoint.new(1, 1) })
mist.Lifetime = NumberRange.new(3, 5)
mist.Rate = 4
mist.Speed = NumberRange.new(0.3, 1.2)
mist.SpreadAngle = Vector2.new(180, 180)
mist.Rotation = NumberRange.new(0, 360)
mist.RotSpeed = NumberRange.new(-8, 8)
mist.LightEmission = 0.35
mist.LightInfluence = 0.5
mist.Shape = Enum.ParticleEmitterShape.Box
mist.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
mist.Parent = mistPart

model:SetAttribute("Rig", "Procedural")
model:SetAttribute("RootHeight", 2)
model:SetAttribute("Height", 26)
model:SetAttribute("AttackStyle", "BeamCast")
model:SetAttribute("CastColor", SOUL)
model:SetAttribute("CastPart", "BeamMuzzle")
model.Parent = models

local count, joints = 0, 0
for _, d in ipairs(model:GetDescendants()) do
	if d:IsA("BasePart") then count += 1 end
	if d:IsA("Motor6D") then joints += 1 end
end
return "LastLantern built: " .. count .. " parts, " .. joints .. " joints"
