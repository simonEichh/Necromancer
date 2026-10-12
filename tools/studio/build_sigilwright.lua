-- Builds the low-poly rigged Sigilwright (Primordial) into ServerStorage.Models.Sigilwright.
-- Run in Studio's command bar / via the Studio MCP execute_luau (Edit mode), then run tools/studio/publish_unit_models.lua.
--
-- Same rig conventions as build_lichacolyte.lua (see src/client/Modules/UnitAnimator.lua):
--   * front = -Z, character's right = +X, feet on y = 0, root part = HumanoidRootPart (RootHeight)
--   * Motor6Ds named Root/Waist/Neck/Jaw/LShoulder/RShoulder/LElbow/RElbow, attributes Rig/RootHeight/Height
-- A tall, thin floating oracle: an indigo robe that tapers into tattered ribbons instead of legs (it hovers, attribute
-- Float), a hood with no face, only a cold white-gold glow, a ring of tiny stars turning round the head (SpinStars joint)
-- and a halo of fine gold rings behind the back. One bare bone hand covered in gold sigils: it is lifted for the cast.
-- Spellcaster with AttackStyle "SigilCast" (see SpellEffects): the raised hand (part SigilPoint) carries a big rune circle
-- above it, and a handful of small sigil circles open at the wall and fire the barrage.
local ServerStorage = game:GetService("ServerStorage")
local models = ServerStorage.Models

local old = models:FindFirstChild("Sigilwright")
if old then
	old:Destroy()
end

local INDIGO = Color3.fromRGB(34, 30, 76)
local INDIGO_DARK = Color3.fromRGB(20, 18, 48)
local INDIGO_LIGHT = Color3.fromRGB(58, 52, 120)
local BONE = Color3.fromRGB(226, 218, 196)
local GOLD = Color3.fromRGB(255, 226, 150)
local GOLD_DEEP = Color3.fromRGB(214, 168, 78)
local VOID = Color3.fromRGB(10, 8, 22)

local model = Instance.new("Model")
model.Name = "Sigilwright"

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

local function weld(p0, p1)
	local w = Instance.new("WeldConstraint")
	w.Part0 = p0
	w.Part1 = p1
	w.Parent = p1
	return w
end

local NEON = Enum.Material.Neon

-- ── Core ──────────────────────────────────────────────────────
local PELVIS_Y = 2.7
local root = part("HumanoidRootPart", Vector3.new(1.2, 0.4, 0.8), Vector3.new(0, PELVIS_Y, 0), INDIGO, nil, 1)
model.PrimaryPart = root

local pelvis = part("Pelvis", Vector3.new(1.3, 0.5, 0.85), Vector3.new(0, PELVIS_Y, 0), INDIGO_DARK)
motor("Root", root, pelvis, Vector3.new(0, PELVIS_Y, 0))

-- robe skirt: four stacked, widening boxes that hang from the pelvis, a gold hem and tattered ribbons below it
local skirt = {
	{ y = 2.2, w = 1.45, d = 0.95, h = 0.75 },
	{ y = 1.5, w = 1.7, d = 1.1, h = 0.75 },
	{ y = 0.85, w = 1.95, d = 1.25, h = 0.65 },
}
for i, s in ipairs(skirt) do
	weld(pelvis, part("Skirt" .. i, Vector3.new(s.w, s.h, s.d), Vector3.new(0, s.y, 0), i % 2 == 1 and INDIGO or INDIGO_DARK))
end
weld(pelvis, part("Hem", Vector3.new(2.0, 0.1, 1.3), Vector3.new(0, 0.5, 0), GOLD, NEON))
local ribbonLengths = { 0.5, 0.75, 0.4, 0.8, 0.55, 0.7, 0.45 }
for i, len in ipairs(ribbonLengths) do
	local x = -0.85 + (i - 1) * (1.7 / (#ribbonLengths - 1))
	local z = (i % 2 == 0) and 0.38 or -0.38
	weld(pelvis, part("Ribbon" .. i, Vector3.new(0.2, len, 0.06), Vector3.new(x, 0.5 - len / 2, z), INDIGO_DARK))
end

local torso = part("Torso", Vector3.new(1.35, 1.5, 0.85), Vector3.new(0, 3.75, 0), INDIGO)
motor("Waist", pelvis, torso, Vector3.new(0, PELVIS_Y + 0.25, 0))
weld(torso, part("Mantle", Vector3.new(1.8, 0.35, 1.05), Vector3.new(0, 4.4, 0), INDIGO_DARK))
weld(torso, part("MantleTrim", Vector3.new(1.84, 0.07, 1.09), Vector3.new(0, 4.58, 0), GOLD_DEEP, NEON))
weld(torso, part("Sash", Vector3.new(1.42, 0.18, 0.92), Vector3.new(0, 3.2, 0), GOLD_DEEP))

-- a constellation drawn across the chest: gold stars joined by thin lines
local stars = {
	Vector3.new(-0.42, 4.05, 0), Vector3.new(-0.1, 3.8, 0), Vector3.new(0.25, 4.0, 0),
	Vector3.new(0.45, 3.65, 0), Vector3.new(0.05, 3.45, 0),
}
for i, pos in ipairs(stars) do
	weld(torso, part("ChestStar" .. i, Vector3.new(0.13, 0.13, 0.05), CFrame.new(pos.X, pos.Y, -0.45) * CFrame.Angles(0, 0, math.rad(45)), GOLD, NEON))
	local nxt = stars[i + 1]
	if nxt then
		local a, b = Vector3.new(pos.X, pos.Y, -0.44), Vector3.new(nxt.X, nxt.Y, -0.44)
		local len = (b - a).Magnitude
		local mid = (a + b) / 2
		weld(torso, part("ChestLine" .. i, Vector3.new(0.035, len, 0.03), CFrame.new(mid) * CFrame.Angles(0, 0, math.atan2(-(b.X - a.X), b.Y - a.Y)), GOLD, NEON))
	end
end

-- ── Head: a hood with nothing in it but a cold glow ───────────
local head = part("Head", Vector3.new(0.95, 1.0, 0.9), Vector3.new(0, 5.15, 0), VOID)
motor("Neck", torso, head, Vector3.new(0, 4.5, 0))
weld(head, part("HoodBack", Vector3.new(1.3, 1.5, 0.3), Vector3.new(0, 5.2, 0.55), INDIGO))
weld(head, part("HoodTop", Vector3.new(1.3, 0.3, 1.45), Vector3.new(0, 5.85, 0.08), INDIGO))
weld(head, part("HoodPeak", Vector3.new(0.45, 0.8, 0.45), CFrame.new(0, 6.3, 0.5) * CFrame.Angles(math.rad(-25), 0, 0), INDIGO_DARK))
for _, x in ipairs({ -1, 1 }) do
	weld(head, part("HoodSide", Vector3.new(0.24, 1.5, 1.2), Vector3.new(x * 0.58, 5.2, 0.0), INDIGO))
	weld(head, part("HoodTrim", Vector3.new(0.06, 1.5, 0.06), Vector3.new(x * 0.5, 5.2, -0.62), GOLD_DEEP, NEON))
end
weld(head, part("HoodBrow", Vector3.new(1.0, 0.07, 0.06), Vector3.new(0, 5.92, -0.62), GOLD_DEEP, NEON))
-- the glow where a face would be
weld(head, part("FaceGlow", Vector3.new(0.6, 0.78, 0.05), Vector3.new(0, 5.12, -0.4), GOLD, NEON, 0.1))
weld(head, part("FaceCore", Vector3.new(0.22, 0.34, 0.06), Vector3.new(0, 5.12, -0.43), Color3.new(1, 1, 1), NEON))
-- (UnitAnimator wiggles a Jaw joint on every rig; this one has no jaw, so there is nothing to join)

-- ring of tiny stars turning round the head (a joint named Spin... turns forever around Y)
local starRoot = part("StarRoot", Vector3.new(0.2, 0.2, 0.2), Vector3.new(0, 5.15, 0), GOLD, nil, 1)
local spin = motor("SpinStars", head, starRoot, Vector3.new(0, 5.15, 0))
spin:SetAttribute("SpinSpeed", 1.1)
for i = 1, 6 do
	local a = (i / 6) * math.pi * 2
	weld(starRoot, part("OrbitStar" .. i, Vector3.new(0.17, 0.17, 0.17),
		CFrame.new(math.cos(a) * 1.15, 5.15 + ((i % 2 == 0) and 0.3 or -0.1), math.sin(a) * 1.15) * CFrame.Angles(math.rad(45), math.rad(45), 0),
		GOLD, NEON))
end

-- ── Halo: three fine gold rings standing behind the back (each ring is a circle of thin neon segments) ──
for i, d in ipairs({ 4.0, 3.3, 2.6 }) do
	local radius, segments = d / 2, 18
	local chord = 2 * math.pi * radius / segments * 1.04
	for k = 1, segments do
		local a = (k / segments) * math.pi * 2
		local cf = CFrame.new(math.cos(a) * radius, 4.2 + math.sin(a) * radius, 0.75 + i * 0.07) * CFrame.Angles(0, 0, a + math.pi / 2)
		weld(torso, part("Halo" .. i .. "_" .. k, Vector3.new(chord, 0.05, 0.05), cf, GOLD_DEEP, NEON, 0.15))
	end
end

-- ── Arms: wide sleeves, the right forearm and hand are bare bone with gold sigils ──
local function sleeve(side, x)
	local upper = part(side .. "UpperArm", Vector3.new(0.45, 0.95, 0.45), Vector3.new(x, 4.05, 0), INDIGO)
	motor(side .. "Shoulder", torso, upper, Vector3.new(x, 4.5, 0))
	return upper
end
local lUpper = sleeve("L", -1.0)
local rUpper = sleeve("R", 1.0)

local lFore = part("LForearm", Vector3.new(0.55, 0.9, 0.55), Vector3.new(-1.0, 3.15, 0), INDIGO_DARK)
motor("LElbow", lUpper, lFore, Vector3.new(-1.0, 3.6, 0))
local lHand = part("LHand", Vector3.new(0.26, 0.3, 0.26), Vector3.new(-1.0, 2.55, 0), BONE)
weld(lFore, lHand)
weld(lFore, part("LCuff", Vector3.new(0.6, 0.07, 0.6), Vector3.new(-1.0, 2.7, 0), GOLD_DEEP, NEON))
-- a little star floating over the left palm
weld(lHand, part("PalmStar", Vector3.new(0.2, 0.2, 0.2), CFrame.new(-1.0, 2.95, -0.15) * CFrame.Angles(math.rad(45), math.rad(45), 0), GOLD, NEON))

-- the right forearm: bone, with gold bands, sigils and a palm glow that carries the big circle
local rFore = part("RForearm", Vector3.new(0.3, 0.9, 0.3), Vector3.new(1.0, 3.15, 0), BONE)
motor("RElbow", rUpper, rFore, Vector3.new(1.0, 3.6, 0))
weld(rFore, part("RSleeveEnd", Vector3.new(0.6, 0.3, 0.6), Vector3.new(1.0, 3.5, 0), INDIGO_DARK))
for i = 0, 2 do
	weld(rFore, part("RBand" .. i, Vector3.new(0.36, 0.05, 0.36), Vector3.new(1.0, 3.15 - i * 0.22, 0), GOLD, NEON))
end
local rHand = part("RHand", Vector3.new(0.3, 0.34, 0.3), Vector3.new(1.0, 2.55, 0), BONE)
weld(rFore, rHand)
for _, dx in ipairs({ -0.1, 0, 0.1 }) do
	weld(rHand, part("RFinger", Vector3.new(0.06, 0.26, 0.06), Vector3.new(1.0 + dx, 2.3, -0.02), BONE))
end
weld(rHand, part("PalmGlow", Vector3.new(0.3, 0.3, 0.3), Vector3.new(1.0, 2.5, -0.2), GOLD, NEON, 0.15))
-- the point the big rune circle follows (the lifted palm)
local sigilPoint = part("SigilPoint", Vector3.new(0.2, 0.2, 0.2), Vector3.new(1.0, 2.5, -0.15), GOLD, nil, 1)
weld(rHand, sigilPoint)

model:SetAttribute("Rig", "Procedural")
model:SetAttribute("RootHeight", PELVIS_Y)
model:SetAttribute("Height", 6.6)
model:SetAttribute("Float", 0.22)
model:SetAttribute("AttackStyle", "SigilCast")
model:SetAttribute("CastColor", GOLD)
model:SetAttribute("CastPart", "SigilPoint")
model.Parent = models

local count = 0
for _, d in ipairs(model:GetDescendants()) do
	if d:IsA("Motor6D") then count += 1 end
end
return "Sigilwright built: " .. #model:GetChildren() .. " parts, " .. count .. " joints"
