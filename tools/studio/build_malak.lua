-- Builds Malak, the Envoy (Sovereign, see docs/envoy.md) into ServerStorage.Models.Malak.
-- Run in Edit mode (Studio MCP execute_luau or loadstring from the tools/studio http server), then publish_unit_models.lua.
--
-- After the concept art (Images/Concept/Unit/Malak, der Chrom-Emissaer.png): a tall, slender envoy in black chrome
-- armour with thin cold white-blue light seams, a faceless helmet with one vertical slit of light, a towering high
-- collar, layered pointed pauldrons, a chevroned chest with a hanging chain, and a long armoured coat whose skirt splits
-- into eleven blade-shaped panels (violet lining, silver edges, a glowing seam and a diamond emblem on each). He hovers:
-- pointed sabatons tilted down, a thruster in each heel. Modelled in his nonchalant pose: the left hand behind his back,
-- the right forearm forward with the palm up under a small hologram panel of runes (parts named Holo..., on RHand).
--
-- Rig conventions (see src/client/Modules/UnitAnimator.lua):
--   * front = -Z, character's right = +X, root part = HumanoidRootPart at RootHeight; he floats, so the boot soles are
--     SOLE studs above y = 0 (the floor)
--   * Motor6Ds Root/Waist/Neck/LShoulder/RShoulder/LElbow/RElbow/RWrist/LHip/RHip/LKnee/RKnee, rest rotation identity
--   * attributes Rig = "Procedural", RootHeight, Height, Float
local ServerStorage = game:GetService("ServerStorage")
local models = ServerStorage.Models

local NAME = "Malak"
local old = models:FindFirstChild(NAME)
if old then
	old:Destroy()
end

local SMOOTH = Enum.Material.SmoothPlastic
local NEON = Enum.Material.Neon
local FABRIC = Enum.Material.Fabric

local CHROME = Color3.fromRGB(22, 22, 28)       -- black chrome (with reflectance)
local CHROME_LIGHT = Color3.fromRGB(42, 42, 52)
local UNDERSUIT = Color3.fromRGB(14, 14, 18)
local SILVER = Color3.fromRGB(176, 180, 196)
local SILVER_DARK = Color3.fromRGB(110, 114, 130)
local LINING = Color3.fromRGB(44, 30, 74)       -- violet coat lining
local LINING_DARK = Color3.fromRGB(28, 20, 50)
local GLOW = Color3.fromRGB(165, 180, 255)      -- the cold white-blue light
local GLOW_CORE = Color3.fromRGB(235, 240, 255)
local GLOW_DEEP = Color3.fromRGB(96, 104, 230)

local SOLE = 0.7       -- he hovers this high
local HIP_Y = 3.75

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
		p.Reflectance = 0.18
	elseif color == SILVER or color == SILVER_DARK then
		p.Reflectance = 0.3
	end
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
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

local function deco(to, name, size, at, color, material, shape)
	local p = part(name, size, at, color, material, shape)
	weld(to, p)
	return p
end

-- a box between two points (w x h cross-section), welded to `to`
local function bar(to, name, a, b, w, h, color, material)
	local dir = b - a
	local up = math.abs(dir.Unit.Y) > 0.98 and Vector3.new(0, 0, 1) or Vector3.new(0, 1, 0)
	return deco(to, name, Vector3.new(w, h or w, dir.Magnitude), CFrame.lookAt((a + b) / 2, b, up), color, material)
end

-- a cylinder centred on `c` whose axis runs along `axis`
local function cyl(to, name, c, axis, length, diameter, color, material)
	local cf
	if math.abs(axis.Unit.Y) > 0.98 then
		cf = CFrame.new(c) * CFrame.Angles(0, 0, math.pi / 2)
	else
		cf = CFrame.lookAt(c, c + axis) * CFrame.Angles(0, math.pi / 2, 0)
	end
	return deco(to, name, Vector3.new(length, diameter, diameter), cf, color, material, Enum.PartType.Cylinder)
end

-- a glowing strip (neon) on a surface
local function glow(to, name, size, at, transparency)
	local p = deco(to, name, size, at, GLOW, NEON)
	p.Transparency = transparency or 0
	return p
end

-- A blade-shaped armour plate: in the local frame of `cf` it grows along +Y from the origin, ends in a point at y = L,
-- and its outer face is +Z. Silver edges, a glowing seam down one side and along the point, a diamond emblem near the
-- point, and (opts.lining) a violet lining on the inner face. Used for the coat skirt, the collar and the pauldrons.
local function blade(to, name, cf, w, L, t, opts)
	opts = opts or {}
	local body = L - w / 2
	local d = w / math.sqrt(2)
	local plateColor = opts.color or CHROME
	deco(to, name, Vector3.new(w, body, t), cf * CFrame.new(0, body / 2, 0), plateColor)
	-- (no two faces of different colour may share a plane, or they flicker (z-fighting): the tip is a hair thinner than
	-- the plate, its lining thinner than the body's lining, and the silver edges stand a little proud of the plate)
	deco(to, name .. "Tip", Vector3.new(d, d, t * 0.94), cf * CFrame.new(0, body, 0) * CFrame.Angles(0, 0, math.rad(45)), plateColor)
	if opts.lining then
		deco(to, name .. "Lining", Vector3.new(w * 0.86, body - 0.08, t * 0.4),
			cf * CFrame.new(0, body / 2, -t * 0.65), LINING, FABRIC)
		deco(to, name .. "LiningTip", Vector3.new(d * 0.86, d * 0.86, t * 0.24),
			cf * CFrame.new(0, body, -t * 0.65) * CFrame.Angles(0, 0, math.rad(45)), LINING, FABRIC)
	end
	for _, s in ipairs({ -1, 1 }) do
		deco(to, name .. "Edge", Vector3.new(0.045, body + 0.024, t + 0.025), cf * CFrame.new(s * (w / 2 - 0.0105), body / 2, 0), SILVER)
		deco(to, name .. "TipEdge", Vector3.new(0.045, d + 0.03, t + 0.035),
			cf * CFrame.new(s * w / 4, body + w / 4, 0) * CFrame.Angles(0, 0, s * math.rad(45)) * CFrame.new(s * 0.012, 0, 0), SILVER)
	end
	local side = opts.seamSide or 1
	if body > 0.4 then
		glow(to, name .. "Seam", Vector3.new(0.035, body * 0.8, 0.02),
			cf * CFrame.new(side * (w / 2 - 0.13), body * 0.48, t / 2 + 0.008))
	end
	glow(to, name .. "TipSeam", Vector3.new(0.035, d * 0.62, 0.02),
		cf * CFrame.new(side * (w / 4 - 0.08), body + w / 4 - 0.08, t / 2 + 0.008) * CFrame.Angles(0, 0, side * math.rad(45)))
	if opts.emblem ~= false and w >= 0.45 then
		local ey = math.max(body - 0.32, body * 0.6)
		deco(to, name .. "Emblem", Vector3.new(0.17, 0.17, 0.03),
			cf * CFrame.new(0, ey, t / 2 + 0.012) * CFrame.Angles(0, 0, math.rad(45)), SILVER)
		glow(to, name .. "EmblemCore", Vector3.new(0.07, 0.07, 0.03),
			cf * CFrame.new(0, ey, t / 2 + 0.025) * CFrame.Angles(0, 0, math.rad(45)))
	end
end

local function light(parentPart, range, brightness, color)
	local l = Instance.new("PointLight")
	l.Color = color or GLOW
	l.Range = range
	l.Brightness = brightness
	l.Shadows = false
	l.Parent = parentPart
	return l
end

-- ====================================================================
-- Pelvis, belt, coat skirt (eleven blade panels) and the front tabard
-- ====================================================================
local root = part("HumanoidRootPart", Vector3.new(1.2, 0.4, 0.8), Vector3.new(0, HIP_Y, 0), CHROME)
root.Transparency = 1
model.PrimaryPart = root

local pelvis = part("Pelvis", Vector3.new(0.95, 0.5, 0.62), Vector3.new(0, HIP_Y, 0), UNDERSUIT)
motor("Root", root, pelvis, Vector3.new(0, HIP_Y, 0))

deco(pelvis, "Belt", Vector3.new(1.18, 0.17, 0.82), Vector3.new(0, 3.98, 0), CHROME_LIGHT)
deco(pelvis, "BeltTrimTop", Vector3.new(1.2, 0.03, 0.84), Vector3.new(0, 4.07, 0), SILVER)
deco(pelvis, "BeltTrimLow", Vector3.new(1.2, 0.03, 0.84), Vector3.new(0, 3.89, 0), SILVER)
deco(pelvis, "Buckle", Vector3.new(0.3, 0.24, 0.05), Vector3.new(0, 3.98, -0.43), SILVER)
deco(pelvis, "BuckleInset", Vector3.new(0.2, 0.15, 0.05), Vector3.new(0, 3.98, -0.45), CHROME)
glow(pelvis, "BuckleCore", Vector3.new(0.09, 0.09, 0.04), CFrame.new(0, 3.98, -0.47) * CFrame.Angles(0, 0, math.rad(45)))
for _, x in ipairs({ -1, 1 }) do
	-- a hip strap with a ring hangs off each side of the belt
	bar(pelvis, "HipStrap", Vector3.new(x * 0.3, 3.95, -0.44), Vector3.new(x * 0.6, 3.6, -0.3), 0.09, 0.03, CHROME_LIGHT)
	deco(pelvis, "HipRing", Vector3.new(0.12, 0.12, 0.03), CFrame.new(x * 0.62, 3.56, -0.3) * CFrame.Angles(0, 0, math.rad(45)), SILVER)
end

-- the skirt: panels hang from an ellipse round the hips; angle 0 is the front (left open for the legs and tabard)
local SKIRT = {
	{ a = 50, w = 0.66, L = 3.35, flare = 0.2 },
	{ a = 78, w = 0.7, L = 3.0, flare = 0.3 },
	{ a = 106, w = 0.74, L = 3.2, flare = 0.32 },
	{ a = 134, w = 0.7, L = 2.95, flare = 0.3 },
	{ a = 158, w = 0.72, L = 3.25, flare = 0.26 },
}
-- Every panel hangs from its own hinge (an invisible part on a Motor6D named Coat..., attribute CoatAngle = where it
-- hangs round the hips in degrees, 0 = front, 90 = his right): the hinge frame has +Z pointing outward and X along the
-- hips, so a negative X rotation swings the panel's bottom outward (UnitAnimator sways them on springs).
local function coatHinge(jointName, top, out, deg)
	local hingeCF = CFrame.lookAt(top, top - out)
	local hinge = part(jointName .. "Hinge", Vector3.new(0.1, 0.1, 0.1), hingeCF, CHROME)
	hinge.Transparency = 1
	local m = Instance.new("Motor6D")
	m.Name = jointName
	m.Part0 = pelvis
	m.Part1 = hinge
	m.C0 = pelvis.CFrame:Inverse() * hingeCF
	m.C1 = CFrame.new()
	m:SetAttribute("CoatAngle", deg)
	m.Parent = hinge
	return hinge, hingeCF
end
local function skirtPanel(jointName, name, deg, w, L, flare, seamSide)
	local a = math.rad(deg)
	local top = Vector3.new(math.sin(a) * 0.66, 3.92, -math.cos(a) * 0.46)
	local out = Vector3.new(math.sin(a), 0, -math.cos(a))
	local hinge, hingeCF = coatHinge(jointName, top, out, deg)
	-- +Z outward, then flare the bottom out, then flip so +Y hangs down
	local cf = hingeCF * CFrame.Angles(-flare, 0, 0) * CFrame.Angles(0, 0, math.pi)
	blade(hinge, name, cf, w, L, 0.07, { lining = true, seamSide = seamSide })
end
for i, s in ipairs(SKIRT) do
	skirtPanel("CoatR" .. i, "CoatPanelR" .. i, s.a, s.w, s.L, s.flare, -1)
	skirtPanel("CoatL" .. i, "CoatPanelL" .. i, -s.a, s.w, s.L, s.flare, 1)
end
skirtPanel("CoatBack", "CoatPanelBack", 180, 0.78, 3.45, 0.22, 1)

-- the tabard: a long narrow panel down the front between the legs (its own hinge, CoatFront)
do
	local top = Vector3.new(0, 3.9, -0.47)
	local tab = coatHinge("CoatFront", top, Vector3.new(0, 0, -1), 0)
	local cf = CFrame.lookAt(top, top - Vector3.new(0, 0, -1)) * CFrame.Angles(-0.05, 0, 0) * CFrame.Angles(0, 0, math.pi)
	blade(tab, "Tabard", cf, 0.42, 2.7, 0.05, { emblem = false })
	-- chevrons and a diamond down the tabard
	for i, y in ipairs({ 0.45, 0.8 }) do
		for _, s in ipairs({ -1, 1 }) do
			deco(tab, "TabardChevron" .. i, Vector3.new(0.04, 0.24, 0.03),
				cf * CFrame.new(s * 0.08, y, 0.04) * CFrame.Angles(0, 0, s * math.rad(-50)), SILVER)
		end
	end
	deco(tab, "TabardGem", Vector3.new(0.2, 0.2, 0.03), cf * CFrame.new(0, 1.55, 0.035) * CFrame.Angles(0, 0, math.rad(45)), SILVER)
	glow(tab, "TabardGemCore", Vector3.new(0.1, 0.1, 0.03), cf * CFrame.new(0, 1.55, 0.05) * CFrame.Angles(0, 0, math.rad(45)))
	glow(tab, "TabardSeam", Vector3.new(0.025, 0.9, 0.02), cf * CFrame.new(0, 2.0, 0.035))
end

-- ====================================================================
-- Torso: undersuit, chest plates with chevrons and a chain, the upper coat, lapels and the high collar
-- ====================================================================
local torso = part("Torso", Vector3.new(1.16, 1.62, 0.7), Vector3.new(0, 4.82, 0), UNDERSUIT)
motor("Waist", pelvis, torso, Vector3.new(0, 3.98, 0))

-- chest: a black chrome plate, three silver chevrons narrowing to the waist, a glowing diamond below them
deco(torso, "ChestPlate", Vector3.new(0.72, 1.32, 0.08), Vector3.new(0, 4.86, -0.37), CHROME)
deco(torso, "ChestRidge", Vector3.new(0.06, 1.2, 0.05), Vector3.new(0, 4.86, -0.42), CHROME_LIGHT)
for i, y in ipairs({ 5.42, 5.12, 4.82 }) do
	local half = 0.33 - i * 0.03
	for _, s in ipairs({ -1, 1 }) do
		bar(torso, "Chevron" .. i, Vector3.new(s * half, y + 0.13, -0.43), Vector3.new(0, y - 0.1, -0.43), 0.06, 0.04, SILVER)
	end
	if i == 2 then
		for _, s in ipairs({ -1, 1 }) do
			bar(torso, "ChevronGlow", Vector3.new(s * half * 0.8, y + 0.04, -0.452), Vector3.new(s * 0.04, y - 0.13, -0.452), 0.025, 0.02, GLOW, NEON)
		end
	end
end
deco(torso, "ChestGemMount", Vector3.new(0.24, 0.24, 0.04), CFrame.new(0, 4.4, -0.42) * CFrame.Angles(0, 0, math.rad(45)), SILVER)
glow(torso, "ChestGem", Vector3.new(0.13, 0.13, 0.05), CFrame.new(0, 4.4, -0.44) * CFrame.Angles(0, 0, math.rad(45)))
glow(torso, "ChestGemCore", Vector3.new(0.05, 0.05, 0.05), CFrame.new(0, 4.4, -0.46) * CFrame.Angles(0, 0, math.rad(45))).Color = GLOW_CORE
-- abdomen plates below the chest
for i, y in ipairs({ 4.18, 4.32 }) do
	deco(torso, "AbPlate" .. i, Vector3.new(0.6 - i * 0.06, 0.11, 0.06), Vector3.new(0, y, -0.392), CHROME_LIGHT)
end
-- a chain hanging in a sag across the chest, from the left chevron to a pin on the right
do
	local a, b = Vector3.new(-0.3, 5.26, -0.47), Vector3.new(0.3, 5.0, -0.47)
	local n = 9
	for i = 0, n - 1 do
		local t = i / (n - 1)
		local p = a:Lerp(b, t) - Vector3.new(0, math.sin(t * math.pi) * 0.22, 0)
		local link = deco(torso, "ChainLink", Vector3.new(0.07, 0.045, 0.02), CFrame.new(p) * CFrame.Angles(0, (i % 2) * math.rad(90), math.rad(20 - t * 40)), SILVER)
		link.Reflectance = 0.4
	end
	deco(torso, "ChainPin", Vector3.new(0.09, 0.09, 0.04), CFrame.new(0.32, 5.0, -0.46) * CFrame.Angles(0, 0, math.rad(45)), SILVER)
end

-- upper coat: back, sides and the two front halves left open over the chest
deco(torso, "CoatBack", Vector3.new(1.36, 1.72, 0.12), Vector3.new(0, 4.8, 0.4), CHROME)
glow(torso, "CoatBackSeam", Vector3.new(0.03, 1.4, 0.02), Vector3.new(0, 4.75, 0.465))
for _, s in ipairs({ -1, 1 }) do
	glow(torso, "CoatBackSeamSide", Vector3.new(0.03, 1.1, 0.02), Vector3.new(s * 0.4, 4.6, 0.465))
	deco(torso, "CoatSide", Vector3.new(0.12, 1.72, 0.84), Vector3.new(s * 0.67, 4.8, 0.02), CHROME)
	deco(torso, "CoatFront", Vector3.new(0.32, 1.66, 0.1), Vector3.new(s * 0.52, 4.8, -0.4), CHROME)
	deco(torso, "CoatFrontEdge", Vector3.new(0.035, 1.69, 0.12), Vector3.new(s * 0.37, 4.8, -0.4), SILVER)
	glow(torso, "CoatFrontSeam", Vector3.new(0.03, 1.2, 0.02), Vector3.new(s * 0.6, 4.65, -0.455))
	-- buckled straps across the coat front
	for j, y in ipairs({ 4.3, 4.55 }) do
		deco(torso, "CoatStrap" .. j, Vector3.new(0.3, 0.07, 0.03), Vector3.new(s * 0.53, y, -0.46), CHROME_LIGHT)
		deco(torso, "CoatStrapBuckle" .. j, Vector3.new(0.07, 0.09, 0.03), Vector3.new(s * 0.44, y, -0.475), SILVER)
	end
	-- lapels: wide silver-edged plates from the collar down into the V of the coat
	local lapTop, lapLow = Vector3.new(s * 0.28, 5.62, -0.46), Vector3.new(s * 0.4, 4.6, -0.47)
	bar(torso, "Lapel", lapTop + Vector3.new(s * 0.08, 0, 0), lapLow + Vector3.new(s * 0.06, 0, 0), 0.26, 0.05, CHROME_LIGHT)
	bar(torso, "LapelEdge", lapTop, lapLow, 0.04, 0.07, SILVER)
	bar(torso, "LapelGlow", lapTop + Vector3.new(s * 0.18, -0.05, -0.02), lapLow + Vector3.new(s * 0.15, 0.1, -0.02), 0.025, 0.02, GLOW, NEON)
end

-- the high collar: a tall back piece and two side wings flaring out round the helmet, plus two small front points
blade(torso, "CollarBack", CFrame.new(0, 5.5, 0.4) * CFrame.Angles(0.22, 0, 0), 0.92, 1.25, 0.07, { lining = true })
for _, s in ipairs({ -1, 1 }) do
	blade(torso, s < 0 and "CollarL" or "CollarR",
		CFrame.new(s * 0.5, 5.48, 0.12) * CFrame.Angles(0, s * (math.pi / 2 - 0.5), 0) * CFrame.Angles(0.28, 0, 0) * CFrame.Angles(0, 0, s * 0.1),
		0.58, 1.12, 0.07, { lining = true, seamSide = -s })
	blade(torso, s < 0 and "CollarFrontL" or "CollarFrontR",
		CFrame.new(s * 0.36, 5.5, -0.3) * CFrame.Angles(0, s * -0.5 + math.pi, 0) * CFrame.Angles(0.35, 0, 0),
		0.28, 0.48, 0.05, { emblem = false })
end

-- ====================================================================
-- Head: the faceless helmet with its vertical slit of light
-- ====================================================================
local head = part("Head", Vector3.new(0.6, 0.92, 0.7), Vector3.new(0, 6.22, 0.02), CHROME)
motor("Neck", torso, head, Vector3.new(0, 5.66, 0))
cyl(head, "NeckSeal", Vector3.new(0, 5.72, 0.02), Vector3.new(0, 1, 0), 0.24, 0.42, UNDERSUIT)
for i = 1, 3 do
	cyl(head, "NeckRing", Vector3.new(0, 5.64 + i * 0.07, 0.02), Vector3.new(0, 1, 0), 0.025, 0.44, SILVER_DARK)
end

-- faceplate, slightly forward, narrowing into a pointed chin
deco(head, "Faceplate", Vector3.new(0.54, 0.72, 0.1), Vector3.new(0, 6.28, -0.36), CHROME_LIGHT)
deco(head, "Chin", Vector3.new(0.38, 0.38, 0.1), CFrame.new(0, 5.92, -0.35) * CFrame.Angles(0, 0, math.rad(45)), CHROME_LIGHT)
for _, s in ipairs({ -1, 1 }) do
	-- cheek plates angled back along the sides of the face, silver edged
	deco(head, "Cheek", Vector3.new(0.08, 0.6, 0.44), CFrame.new(s * 0.31, 6.15, -0.18) * CFrame.Angles(0, s * 0.25, s * -0.08), CHROME)
	deco(head, "CheekEdge", Vector3.new(0.096, 0.62, 0.03), CFrame.new(s * 0.27, 6.15, -0.392) * CFrame.Angles(0, s * 0.25, s * -0.08), SILVER)
	-- the side module (ear): a disc, a silver ring and a light
	cyl(head, "EarDisc", Vector3.new(s * 0.33, 6.25, 0.08), Vector3.new(1, 0, 0), 0.08, 0.34, CHROME_LIGHT)
	cyl(head, "EarRing", Vector3.new(s * 0.36, 6.25, 0.08), Vector3.new(1, 0, 0), 0.03, 0.3, SILVER)
	cyl(head, "EarCore", Vector3.new(s * 0.375, 6.25, 0.08), Vector3.new(1, 0, 0), 0.02, 0.12, GLOW, NEON)
	bar(head, "EarFin", Vector3.new(s * 0.34, 6.38, 0.18), Vector3.new(s * 0.32, 6.62, 0.38), 0.04, 0.08, SILVER)
	-- the side ridges of the crown, sweeping back
	bar(head, "CrownRidge", Vector3.new(s * 0.22, 6.62, -0.38), Vector3.new(s * 0.26, 6.82, 0.36), 0.05, 0.06, SILVER)
end
-- the slit: a thin white core inside a soft blue glow
glow(head, "SlitGlow", Vector3.new(0.12, 0.66, 0.02), Vector3.new(0, 6.3, -0.415), 0.55)
glow(head, "Slit", Vector3.new(0.045, 0.62, 0.03), Vector3.new(0, 6.3, -0.42)).Color = GLOW_CORE
glow(head, "SlitTop", Vector3.new(0.025, 0.24, 0.03), Vector3.new(0, 6.74, -0.38), 0.2)
light(head, 5, 1.4)

-- the crown: a long dome swept back, a centre crest fin and layered plates at the back down to the neck
deco(head, "Crown", Vector3.new(0.5, 0.22, 0.74), Vector3.new(0, 6.74, 0.04), CHROME)
deco(head, "CrownFront", Vector3.new(0.42, 0.18, 0.12), CFrame.new(0, 6.7, -0.36) * CFrame.Angles(-0.4, 0, 0), CHROME)
bar(head, "Crest", Vector3.new(0, 6.86, -0.3), Vector3.new(0, 7.02, 0.46), 0.06, 0.14, SILVER)
bar(head, "CrestGlow", Vector3.new(0, 6.86, -0.22), Vector3.new(0, 6.97, 0.3), 0.075, 0.03, GLOW, NEON)
for i = 1, 3 do
	deco(head, "BackPlate" .. i, Vector3.new(0.56 - i * 0.06, 0.2, 0.1), CFrame.new(0, 6.6 - i * 0.2, 0.36 + i * 0.02) * CFrame.Angles(0.25, 0, 0), i % 2 == 1 and CHROME_LIGHT or CHROME)
end

-- ====================================================================
-- Arms: layered pauldrons; the right arm forward with the gauntlet, palm up under the hologram; the left behind the back
-- ====================================================================
local function shoulderArmour(upper, s)
	-- three stacked pointed plates, each lower one wider and steeper, plus a spike on top
	for k = 0, 2 do
		local base = Vector3.new(s * (0.66 + k * 0.08), 5.66 - k * 0.17, 0)
		-- the blade grows out over the shoulder (+Y local -> outward and down), its width runs front to back and its
		-- outer face points up and out
		local cf = CFrame.new(base) * CFrame.Angles(0, 0, -s * (math.pi / 2 + 0.35 + k * 0.18)) * CFrame.Angles(0, -s * math.pi / 2, 0)
		local w = 0.86 + k * 0.04
		local L = 0.62 + k * 0.08
		blade(upper, (s < 0 and "PauldronL" or "PauldronR") .. k, cf, w, L, 0.08, { emblem = k == 0, seamSide = 1 })
	end
	bar(upper, "PauldronSpike", Vector3.new(s * 0.72, 5.78, 0.05), Vector3.new(s * 0.86, 6.12, 0.16), 0.08, 0.08, SILVER)
end

-- right upper arm (sleeve)
local R_SHOULDER = Vector3.new(0.82, 5.4, 0)
local R_ELBOW = Vector3.new(0.98, 4.4, 0.02)
local R_WRIST = Vector3.new(1.1, 4.22, -0.96)
local rUpper = part("RUpperArm", Vector3.new(0.32, (R_ELBOW - R_SHOULDER).Magnitude, 0.34),
	CFrame.lookAt((R_SHOULDER + R_ELBOW) / 2, R_ELBOW, Vector3.new(0, 0, -1)) * CFrame.Angles(math.pi / 2, 0, 0), CHROME)
motor("RShoulder", torso, rUpper, R_SHOULDER)
shoulderArmour(rUpper, 1)
cyl(rUpper, "SleeveBand", R_SHOULDER:Lerp(R_ELBOW, 0.7), R_ELBOW - R_SHOULDER, 0.06, 0.38, SILVER_DARK)
cyl(rUpper, "ElbowJoint", R_ELBOW, Vector3.new(1, 0, 0), 0.3, 0.3, UNDERSUIT)

-- right forearm: the gauntlet, segmented rings with glowing bands, a silver spine plate and a flared cuff
local rFore = part("RForearm", Vector3.new(0.3, 0.3, (R_WRIST - R_ELBOW).Magnitude), CFrame.lookAt((R_ELBOW + R_WRIST) / 2, R_WRIST), UNDERSUIT)
motor("RElbow", rUpper, rFore, R_ELBOW)
do
	local dir = (R_WRIST - R_ELBOW).Unit
	local len = (R_WRIST - R_ELBOW).Magnitude
	local up = dir:Cross(Vector3.new(1, 0, 0)).Unit
	if up.Y < 0 then
		up = -up
	end
	deco(rFore, "ElbowCop", Vector3.new(0.3, 0.3, 0.06), CFrame.lookAt(R_ELBOW - dir * 0.05, R_ELBOW - dir, up) * CFrame.Angles(0, 0, math.rad(45)), SILVER)
	for i = 0, 3 do
		local c = R_ELBOW + dir * (0.2 + i * 0.2)
		local d = 0.4 + i * 0.03
		cyl(rFore, "GauntletRing" .. i, c, dir, 0.16, d, i % 2 == 0 and CHROME or CHROME_LIGHT)
		cyl(rFore, "GauntletBand" .. i, c + dir * 0.095, dir, 0.03, d - 0.02, GLOW, NEON)
	end
	-- the cuff flares out at the wrist
	cyl(rFore, "Cuff", R_ELBOW + dir * (len - 0.1), dir, 0.14, 0.46, CHROME)
	cyl(rFore, "CuffRim", R_ELBOW + dir * (len - 0.02), dir, 0.03, 0.48, SILVER)
	-- spine plate on top of the gauntlet, with a long glowing groove and rivets
	local topOff = up * 0.24
	bar(rFore, "GauntletSpine", R_ELBOW + dir * 0.12 + topOff, R_ELBOW + dir * (len - 0.15) + topOff, 0.16, 0.06, SILVER)
	bar(rFore, "GauntletGroove", R_ELBOW + dir * 0.18 + topOff + up * 0.035, R_ELBOW + dir * (len - 0.2) + topOff + up * 0.035, 0.04, 0.02, GLOW, NEON)
	for j = 0, 2 do
		local side = dir:Cross(up).Unit
		for _, s in ipairs({ -1, 1 }) do
			deco(rFore, "Rivet", Vector3.one * 0.045, R_ELBOW + dir * (0.25 + j * 0.25) + topOff + side * s * 0.06 + up * 0.03, SILVER_DARK)
		end
	end
	-- side fins (the panel projector)
	local side = dir:Cross(up).Unit
	bar(rFore, "ProjectorFin", R_ELBOW + dir * 0.3 + side * 0.25, R_ELBOW + dir * 0.7 + side * 0.25 + up * 0.08, 0.04, 0.14, SILVER)
	glow(rFore, "ProjectorLens", Vector3.new(0.07, 0.07, 0.07), R_ELBOW + dir * 0.72 + side * 0.25 + up * 0.1)
end

-- right hand: open, palm up, fingers relaxed and slightly curled; RWrist joint for the rune typing later
local rHand
do
	local dir = (R_WRIST - R_ELBOW).Unit
	local flat = Vector3.new(dir.X, 0, dir.Z).Unit
	local hf = CFrame.lookAt(R_WRIST, R_WRIST + flat) -- -Z = fingers, +Y = up (palm side)
	rHand = part("RHand", Vector3.new(0.3, 0.1, 0.32), hf * CFrame.new(0, 0, -0.17), CHROME_LIGHT)
	motor("RWrist", rFore, rHand, R_WRIST)
	deco(rHand, "PalmGlow", Vector3.new(0.12, 0.02, 0.12), hf * CFrame.new(0, 0.055, -0.18) * CFrame.Angles(0, math.rad(45), 0), GLOW, NEON)
	deco(rHand, "BackPlate", Vector3.new(0.26, 0.04, 0.26), hf * CFrame.new(0, -0.06, -0.17), SILVER_DARK)
	-- pinky, ring and middle finger relaxed and curled (palm up: curled up; when he turns the hand over to point they
	-- read as a loose fist), the index finger (next to the thumb, his outer side) almost straight: it does the pointing
	local FINGERS = { { x = -0.11, l = 0.14, curl = 1 }, { x = -0.035, l = 0.17, curl = 1 }, { x = 0.04, l = 0.18, curl = 1 }, { x = 0.11, l = 0.18, curl = 0.15 } }
	for i, f in ipairs(FINGERS) do
		local a = (hf * CFrame.new(f.x, 0, -0.33)).Position
		local b = (hf * CFrame.new(f.x, 0.04 * f.curl, -0.33 - f.l)).Position
		local c = (hf * CFrame.new(f.x, 0.14 * f.curl, -0.33 - f.l - (f.curl < 1 and 0.14 or 0.11))).Position
		bar(rHand, i == 4 and "IndexFinger" or "Finger" .. i, a, b, 0.065, 0.065, CHROME_LIGHT)
		bar(rHand, i == 4 and "IndexTip" or "FingerTip" .. i, b, c, 0.052, 0.052, SILVER)
	end
	local ta = (hf * CFrame.new(0.16, 0, -0.1)).Position
	local tb = (hf * CFrame.new(0.26, 0.06, -0.24)).Position
	local tc = (hf * CFrame.new(0.29, 0.13, -0.33)).Position
	bar(rHand, "Thumb", ta, tb, 0.07, 0.07, CHROME_LIGHT)
	bar(rHand, "ThumbTip", tb, tc, 0.06, 0.06, SILVER)

	-- ==== the hologram: a small upright panel of runes floating above the palm (Holo... parts) ====
	local P = (hf * CFrame.new(0, 0.86, -0.25)).Position
	local pf = CFrame.lookAt(P, P + Vector3.new(0, 0, -1)) -- faces the front
	local W, H = 0.82, 1.06
	local pane = deco(rHand, "HoloPanel", Vector3.new(W, H, 0.02), pf, GLOW, NEON)
	pane.Transparency = 0.86
	light(pane, 6, 1.1)
	-- each kind of line on its own layer in front of the pane (lines in the pane's own plane flicker: z-fighting)
	local HOLO_DEPTH = {
		HoloFrameV = -0.014, HoloFrameH = -0.016, HoloCornerH = -0.02, HoloCornerV = -0.022, HoloMarker = -0.014,
		HoloMarkerDot = -0.014, HoloRing = -0.026, HoloRingInner = -0.032, HoloCrossH = -0.038,
		HoloCrossV = -0.042, HoloTick = -0.046, HoloCore = -0.052, HoloGlyphs = -0.058,
	}
	local function holo(name, size, cf, transparency, color)
		local p = deco(rHand, name, size, pf * CFrame.new(0, 0, HOLO_DEPTH[name] or -0.014) * cf, color or GLOW, NEON)
		p.Transparency = transparency
		return p
	end
	-- frame with corner brackets
	for _, s in ipairs({ -1, 1 }) do
		holo("HoloFrameV", Vector3.new(0.02, H, 0.02), CFrame.new(s * W / 2, 0, 0), 0.35)
		holo("HoloFrameH", Vector3.new(W, 0.02, 0.02), CFrame.new(0, s * H / 2, 0), 0.35)
		for _, t in ipairs({ -1, 1 }) do
			holo("HoloCornerH", Vector3.new(0.14, 0.035, 0.025), CFrame.new(s * (W / 2 - 0.07), t * (H / 2 + 0.04), 0), 0.05)
			holo("HoloCornerV", Vector3.new(0.035, 0.14, 0.025), CFrame.new(s * (W / 2 + 0.04), t * (H / 2 - 0.07), 0), 0.05)
		end
	end
	-- a rune circle: a segmented ring, an inner ring, a crosshair and four ticks
	local function ring(name, r, n, thick, transparency, cy)
		for k = 0, n - 1 do
			local a = (k + 0.5) / n * math.pi * 2
			local seg = 2 * r * math.sin(math.pi / n) * 0.82
			holo(name, Vector3.new(seg, thick, 0.025), CFrame.new(math.cos(a) * r, cy + math.sin(a) * r, -0.005) * CFrame.Angles(0, 0, a + math.pi / 2), transparency)
		end
	end
	ring("HoloRing", 0.24, 18, 0.03, 0.1, 0.06)
	ring("HoloRingInner", 0.13, 10, 0.022, 0.25, 0.06)
	holo("HoloCrossH", Vector3.new(0.6, 0.015, 0.025), CFrame.new(0, 0.06, -0.006), 0.4)
	holo("HoloCrossV", Vector3.new(0.015, 0.6, 0.025), CFrame.new(0, 0.06, -0.006), 0.4)
	holo("HoloCore", Vector3.new(0.06, 0.06, 0.03), CFrame.new(0, 0.06, -0.01) * CFrame.Angles(0, 0, math.rad(45)), 0, GLOW_CORE)
	for k = 0, 3 do
		local a = k * math.pi / 2
		holo("HoloTick", Vector3.new(0.05, 0.05, 0.025), CFrame.new(math.cos(a) * 0.32, 0.06 + math.sin(a) * 0.32, -0.006) * CFrame.Angles(0, 0, math.rad(45)), 0.1)
	end
	-- glyph lines (text) above and below the circle, and two side markers like the concept
	for k = 0, 2 do
		holo("HoloGlyphs", Vector3.new(0.5 - k * 0.12, 0.022, 0.02), CFrame.new(-0.05 + k * 0.03, 0.44 - k * 0.05, -0.004), 0.3)
	end
	for k = 0, 1 do
		holo("HoloGlyphs", Vector3.new(0.4 - k * 0.14, 0.022, 0.02), CFrame.new(0.06, -0.33 - k * 0.06, -0.004), 0.3)
	end
	for _, s in ipairs({ -1, 1 }) do
		holo("HoloMarker", Vector3.new(0.035, 0.12, 0.02), CFrame.new(s * (W / 2 + 0.12), 0.18, 0), 0.2)
		holo("HoloMarkerDot", Vector3.new(0.04, 0.04, 0.02), CFrame.new(s * (W / 2 + 0.12), 0.02, 0) * CFrame.Angles(0, 0, math.rad(45)), 0.2)
	end
	-- the projection: a faint cone of light rising from the palm into the panel
	local palm = (hf * CFrame.new(0, 0.06, -0.18)).Position
	local beamBase = palm
	local beamTop = P - Vector3.new(0, H / 2, 0)
	local beam = bar(rHand, "HoloBeam", beamBase, beamTop, 0.36, 0.05, GLOW, NEON)
	beam.Transparency = 0.9
	local sparks = Instance.new("ParticleEmitter")
	sparks.Name = "HoloMotes"
	sparks.Color = ColorSequence.new(GLOW)
	sparks.LightEmission = 1
	sparks.LightInfluence = 0
	sparks.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.05), NumberSequenceKeypoint.new(1, 0) })
	sparks.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	sparks.Lifetime = NumberRange.new(0.6, 1.2)
	sparks.Rate = 6
	sparks.Speed = NumberRange.new(0.2, 0.5)
	sparks.SpreadAngle = Vector2.new(180, 180)
	sparks.Parent = pane
end

-- left arm: the upper arm hangs down and back, the forearm crosses the small of the back, a closed fist behind him
local L_SHOULDER = Vector3.new(-0.82, 5.4, 0)
local L_ELBOW = Vector3.new(-0.95, 4.46, 0.32)
local L_WRIST = Vector3.new(-0.3, 4.12, 0.66)
local lUpper = part("LUpperArm", Vector3.new(0.32, (L_ELBOW - L_SHOULDER).Magnitude, 0.34),
	CFrame.lookAt((L_SHOULDER + L_ELBOW) / 2, L_ELBOW, Vector3.new(0, 0, -1)) * CFrame.Angles(math.pi / 2, 0, 0), CHROME)
motor("LShoulder", torso, lUpper, L_SHOULDER)
shoulderArmour(lUpper, -1)
cyl(lUpper, "SleeveBand", L_SHOULDER:Lerp(L_ELBOW, 0.7), L_ELBOW - L_SHOULDER, 0.06, 0.38, SILVER_DARK)
local lFore = part("LForearm", Vector3.new(0.28, 0.28, (L_WRIST - L_ELBOW).Magnitude), CFrame.lookAt((L_ELBOW + L_WRIST) / 2, L_WRIST), CHROME)
motor("LElbow", lUpper, lFore, L_ELBOW)
do
	local dir = (L_WRIST - L_ELBOW).Unit
	for i = 0, 1 do
		cyl(lFore, "Bracer" .. i, L_ELBOW + dir * (0.3 + i * 0.28), dir, 0.05, 0.33, i == 0 and SILVER or GLOW, i == 0 and SMOOTH or NEON)
	end
	cyl(lFore, "Cuff", L_WRIST - dir * 0.06, dir, 0.12, 0.42, CHROME_LIGHT)
	deco(lFore, "LHand", Vector3.new(0.24, 0.26, 0.24), CFrame.lookAt(L_WRIST + dir * 0.14, L_WRIST + dir), CHROME_LIGHT)
	deco(lFore, "Knuckles", Vector3.new(0.26, 0.08, 0.1), CFrame.lookAt(L_WRIST + dir * 0.24, L_WRIST + dir * 2), SILVER)
end

-- ====================================================================
-- Legs: armoured thighs and greaves, knee cops with a glowing gem, pointed sabatons tilted down, heel thrusters
-- ====================================================================
local function leg(side, x)
	local thigh = part(side .. "UpperLeg", Vector3.new(0.4, 1.2, 0.44), Vector3.new(x, 3.0, 0), UNDERSUIT)
	motor(side .. "Hip", pelvis, thigh, Vector3.new(x, 3.6, 0))
	deco(thigh, "ThighPlate", Vector3.new(0.36, 0.9, 0.08), Vector3.new(x, 3.05, -0.24), CHROME)
	deco(thigh, "ThighPlateEdge", Vector3.new(0.38, 0.04, 0.1), Vector3.new(x, 2.6, -0.24), SILVER)
	glow(thigh, "ThighSeam", Vector3.new(0.025, 0.6, 0.02), Vector3.new(x + (x > 0 and 0.1 or -0.1), 3.1, -0.285))
	deco(thigh, "ThighSide", Vector3.new(0.06, 0.8, 0.34), Vector3.new(x + (x > 0 and 0.21 or -0.21), 3.05, 0), CHROME_LIGHT)

	local shin = part(side .. "LowerLeg", Vector3.new(0.34, 1.22, 0.4), Vector3.new(x, 1.82, 0.02), UNDERSUIT)
	motor(side .. "Knee", thigh, shin, Vector3.new(x, 2.42, 0))
	-- knee cop: a silver diamond over a chrome cap, a glowing gem in it
	deco(shin, "KneeCap", Vector3.new(0.38, 0.3, 0.16), Vector3.new(x, 2.42, -0.2), CHROME)
	deco(shin, "KneeCop", Vector3.new(0.27, 0.27, 0.06), CFrame.new(x, 2.42, -0.29) * CFrame.Angles(0, 0, math.rad(45)), SILVER)
	glow(shin, "KneeGem", Vector3.new(0.12, 0.12, 0.05), CFrame.new(x, 2.42, -0.32) * CFrame.Angles(0, 0, math.rad(45)))
	-- greave: a long front plate that narrows to the ankle, silver edges and a glowing centre seam
	deco(shin, "Greave", Vector3.new(0.34, 0.95, 0.08), Vector3.new(x, 1.78, -0.22), CHROME)
	deco(shin, "GreaveTip", Vector3.new(0.24, 0.24, 0.08), CFrame.new(x, 1.3, -0.22) * CFrame.Angles(0, 0, math.rad(45)), CHROME)
	for _, s in ipairs({ -1, 1 }) do
		deco(shin, "GreaveEdge", Vector3.new(0.03, 0.83, 0.1), Vector3.new(x + s * 0.16, 1.83, -0.22), SILVER)
	end
	glow(shin, "GreaveSeam", Vector3.new(0.03, 0.7, 0.02), Vector3.new(x, 1.85, -0.265))
	deco(shin, "CalfPlate", Vector3.new(0.32, 0.8, 0.08), Vector3.new(x, 1.9, 0.23), CHROME_LIGHT)

	-- sabaton: tilted down (he hovers), a long pointed toe
	local ankle = Vector3.new(x, 1.15, 0.02)
	local footCF = CFrame.new(ankle) * CFrame.Angles(math.rad(-28), 0, 0) -- toes point forward and down
	deco(shin, "Ankle", Vector3.new(0.36, 0.2, 0.42), CFrame.new(x, 1.2, 0.02), CHROME_LIGHT)
	deco(shin, "AnkleRim", Vector3.new(0.38, 0.04, 0.44), CFrame.new(x, 1.31, 0.02), SILVER)
	deco(shin, "Boot", Vector3.new(0.34, 0.28, 0.56), footCF * CFrame.new(0, -0.2, -0.12), CHROME)
	deco(shin, "BootToe", Vector3.new(0.26, 0.2, 0.3), footCF * CFrame.new(0, -0.24, -0.5), CHROME)
	deco(shin, "BootPoint", Vector3.new(0.18, 0.12, 0.18), footCF * CFrame.new(0, -0.27, -0.66) * CFrame.Angles(0, math.rad(45), 0), SILVER)
	deco(shin, "BootPlate", Vector3.new(0.22, 0.04, 0.4), footCF * CFrame.new(0, -0.05, -0.28), SILVER_DARK)
	glow(shin, "BootSeam", Vector3.new(0.025, 0.02, 0.36), footCF * CFrame.new(0, -0.03, -0.3))
	deco(shin, "Sole", Vector3.new(0.32, 0.05, 0.62), footCF * CFrame.new(0, -0.36, -0.2), SILVER_DARK)

	-- heel thruster: a nozzle under the heel, a glowing core, a short plume and a flicker of light
	local heel = (footCF * CFrame.new(0, -0.36, 0.08)).Position
	cyl(shin, "Thruster", heel + Vector3.new(0, -0.02, 0), Vector3.new(0, 1, 0), 0.14, 0.22, CHROME_LIGHT)
	cyl(shin, "ThrusterRim", heel + Vector3.new(0, -0.09, 0), Vector3.new(0, 1, 0), 0.03, 0.26, SILVER)
	local core = cyl(shin, "ThrusterCore", heel + Vector3.new(0, -0.1, 0), Vector3.new(0, 1, 0), 0.03, 0.16, GLOW_CORE, NEON)
	local plume = cyl(shin, "ThrusterPlume", heel + Vector3.new(0, -0.28, 0), Vector3.new(0, 1, 0), 0.34, 0.14, GLOW, NEON)
	plume.Transparency = 0.45
	local plume2 = cyl(shin, "ThrusterPlumeOuter", heel + Vector3.new(0, -0.36, 0), Vector3.new(0, 1, 0), 0.5, 0.22, GLOW_DEEP, NEON)
	plume2.Transparency = 0.78
	light(core, 4, 1.2)
	local fx = Instance.new("ParticleEmitter")
	fx.Name = "ThrusterFlame"
	fx.Color = ColorSequence.new(GLOW_CORE, GLOW_DEEP)
	fx.LightEmission = 1
	fx.LightInfluence = 0
	fx.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.12), NumberSequenceKeypoint.new(1, 0.02) })
	fx.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	fx.Lifetime = NumberRange.new(0.15, 0.3)
	fx.Rate = 40
	fx.Speed = NumberRange.new(2, 3.5)
	fx.SpreadAngle = Vector2.new(6, 6)
	fx.EmissionDirection = Enum.NormalId.Bottom
	fx.Parent = core
	return thigh, shin
end
leg("L", -0.3)
leg("R", 0.3)

-- a faint shimmer of heat under him where the thrusters push against the air
do
	local haze = Instance.new("ParticleEmitter")
	haze.Name = "HoverHaze"
	haze.Texture = "rbxasset://textures/particles/smoke_main.dds"
	haze.Color = ColorSequence.new(GLOW_DEEP)
	haze.LightEmission = 0.6
	haze.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1.2) })
	haze.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.85), NumberSequenceKeypoint.new(1, 1) })
	haze.Lifetime = NumberRange.new(0.6, 1)
	haze.Rate = 6
	haze.Speed = NumberRange.new(0.5, 1)
	haze.EmissionDirection = Enum.NormalId.Bottom
	haze.Parent = pelvis
end

-- ====================================================================
-- The drone: a floating armillary beside his left shoulder (after the concept art). A glowing core in a small cage,
-- three nested chrome rings that turn on their own tilted axes (joints SpinDrone..., attribute SpinSpeed: UnitAnimator
-- turns every Spin... joint around its own Y), a broken outer C-ring with pointed ends, a spike above and below the
-- core with small fins. It hangs on its own joint from the root (Drone), so UnitAnimator can float it with its own
-- bob and let it lag behind his moves. (Later: it attacks on its own, and transforms into the transmitter for the
-- Fleet Strike: the rings lock together and a spire extends.)
-- ====================================================================
local DRONE_POS = Vector3.new(-2.45, 6.95, 0.45) -- (clear of the collar and the left pauldron)
local droneRoot = part("DroneRoot", Vector3.new(0.2, 0.2, 0.2), DRONE_POS, CHROME)
droneRoot.Transparency = 1
motor("Drone", root, droneRoot, DRONE_POS)

-- the core: a white-hot centre, a soft blue halo, a light, and a small cage of four thin silver hoops round it
local droneCore = deco(droneRoot, "DroneCore", Vector3.one * 0.3, DRONE_POS, GLOW_CORE, NEON, Enum.PartType.Ball)
local droneHalo = deco(droneRoot, "DroneHalo", Vector3.one * 0.5, DRONE_POS, GLOW, NEON, Enum.PartType.Ball)
droneHalo.Transparency = 0.65
light(droneCore, 7, 1.6)

-- a ring of n segments round the local Y axis of `frame`, welded to `to`; w = radial width, h = height
local function ringSegments(to, name, frame, r, n, w, h, color, material, gapFrom, gapTo)
	for k = 0, n - 1 do
		local a = (k + 0.5) / n * math.pi * 2
		local skip = gapFrom and a > gapFrom and a < gapTo
		if not skip then
			local seg = 2 * r * math.sin(math.pi / n) * 1.04
			deco(to, name, Vector3.new(w, h, seg),
				frame * CFrame.Angles(0, -a, 0) * CFrame.new(r, 0, 0), color, material)
		end
	end
end

-- a spinning ring: an invisible hinge on a Spin joint whose frame is tilted, so the ring turns in its own plane
local function droneRing(index, tilt, speed)
	local frame = CFrame.new(DRONE_POS) * tilt
	local hinge = part("DroneRingHinge" .. index, Vector3.new(0.1, 0.1, 0.1), frame, CHROME)
	hinge.Transparency = 1
	local m = Instance.new("Motor6D")
	m.Name = "SpinDrone" .. index
	m.Part0 = droneRoot
	m.Part1 = hinge
	m.C0 = droneRoot.CFrame:Inverse() * frame
	m.C1 = CFrame.new()
	m:SetAttribute("SpinSpeed", speed)
	m.Parent = hinge
	return hinge, frame
end

-- the cage: four thin hoops at 45 degrees to each other, fixed round the core
for i = 0, 3 do
	local frame = CFrame.new(DRONE_POS) * CFrame.Angles(0, i * math.pi / 4, math.pi / 2)
	ringSegments(droneRoot, "DroneCage", frame, 0.27, 12, 0.025, 0.025, SILVER_DARK)
end

-- ring 1: small, steeply tilted, chrome with a glowing inner line
do
	local hinge, frame = droneRing(1, CFrame.Angles(math.rad(62), 0, math.rad(15)), 1.7)
	ringSegments(hinge, "DroneRing1", frame, 0.46, 22, 0.06, 0.1, CHROME_LIGHT)
	ringSegments(hinge, "DroneRing1Glow", frame, 0.425, 22, 0.02, 0.04, GLOW, NEON)
end
-- ring 2: wider, tilted the other way, silver edged, three glowing nodes on it
do
	local hinge, frame = droneRing(2, CFrame.Angles(math.rad(-20), 0, math.rad(-38)), -1.1)
	ringSegments(hinge, "DroneRing2", frame, 0.62, 28, 0.07, 0.12, CHROME)
	ringSegments(hinge, "DroneRing2Edge", frame, 0.62, 31, 0.085, 0.025, SILVER) -- (31 segments: their joins never line up with the band's)
	for k = 0, 2 do
		local a = k / 3 * math.pi * 2
		local at = frame * CFrame.Angles(0, -a, 0) * CFrame.new(0.62, 0, 0)
		deco(hinge, "DroneNode", Vector3.new(0.12, 0.16, 0.12), at, SILVER)
		glow(hinge, "DroneNodeGlow", Vector3.new(0.07, 0.08, 0.13), at * CFrame.new(0.03, 0, 0)) -- (a hair proud of the node)
	end
end
-- ring 3: the broken outer C-ring, nearly upright, turning slowly; pointed ends at the gap
do
	local hinge, frame = droneRing(3, CFrame.Angles(math.rad(78), 0, math.rad(-8)), 0.45)
	local R = 0.82
	local gapFrom, gapTo = math.rad(300), math.rad(350)
	ringSegments(hinge, "DroneRing3", frame, R, 32, 0.08, 0.14, CHROME, nil, gapFrom, gapTo)
	ringSegments(hinge, "DroneRing3Glow", frame, R + 0.045, 32, 0.02, 0.05, GLOW, NEON, gapFrom, gapTo)
	for _, a in ipairs({ gapFrom, gapTo }) do
		local dir = (a == gapFrom) and 1 or -1
		local at = frame * CFrame.Angles(0, -a, 0) * CFrame.new(R, 0, 0)
		-- a pointed cap: a small diamond turned along the ring, a silver tip
		deco(hinge, "DroneRing3Cap", Vector3.new(0.12, 0.12, 0.18), at * CFrame.Angles(math.rad(45), 0, 0), SILVER)
		deco(hinge, "DroneRing3Tip", Vector3.new(0.05, 0.05, 0.16), at * CFrame.new(0, 0, dir * -0.14), SILVER)
	end
end

-- the spikes: a long one above the core, a shorter one below, each a tapering chrome shaft with a silver point and a
-- glowing collar, with four small fins round its base
for _, s in ipairs({ { dir = 1, len = 0.85 }, { dir = -1, len = 0.6 } }) do
	local d = s.dir
	local base = DRONE_POS + Vector3.new(0, d * 0.3, 0)
	local mid = DRONE_POS + Vector3.new(0, d * (0.3 + s.len * 0.55), 0)
	local tip = DRONE_POS + Vector3.new(0, d * (0.3 + s.len), 0)
	deco(droneRoot, "DroneSpike", Vector3.new(0.09, (mid - base).Magnitude, 0.09), CFrame.new((base + mid) / 2), CHROME_LIGHT)
	deco(droneRoot, "DroneSpikeTop", Vector3.new(0.055, (tip - mid).Magnitude, 0.055), CFrame.new((mid + tip) / 2), SILVER)
	deco(droneRoot, "DroneSpikePoint", Vector3.new(0.07, 0.07, 0.07), CFrame.new(tip) * CFrame.Angles(math.rad(45), 0, math.rad(45)), SILVER)
	cyl(droneRoot, "DroneSpikeCollar", base + Vector3.new(0, d * 0.05, 0), Vector3.new(0, 1, 0), 0.04, 0.16, GLOW, NEON)
	for k = 0, 3 do
		local a = k * math.pi / 2 + math.pi / 4
		local out = Vector3.new(math.cos(a), 0, math.sin(a))
		bar(droneRoot, "DroneFin", base + out * 0.05, base + out * 0.2 + Vector3.new(0, d * 0.18, 0), 0.03, 0.06, SILVER_DARK)
	end
end

model:SetAttribute("Rig", "Procedural")
model:SetAttribute("RootHeight", HIP_Y)
model:SetAttribute("Height", 7.1)
model:SetAttribute("Float", 0.12)
model:SetAttribute("AttackStyle", "OrbitalTag") -- points at the wall; OrbitalStrike.lua draws the laser + shell
model:SetAttribute("Pose", "Envoy") -- UnitAnimator's Envoy block (idle, hover, coat on springs)
model.Parent = models

local parts, joints = 0, 0
for _, d in ipairs(model:GetDescendants()) do
	if d:IsA("BasePart") then parts += 1 end
	if d:IsA("Motor6D") then joints += 1 end
end
return NAME .. ": " .. parts .. " parts, " .. joints .. " joints"
