-- Builds the low-poly rigged Pale Sovereign (a colossal prismatic unicorn, top rarity) into ServerStorage.Models.PaleSovereign.
-- Run in Studio's command bar / via the Studio MCP execute_luau (Edit mode). Safe to re-run.
--
-- A FOUR-LEGGED rig like build_shadowhound.lua (see src/client/Modules/UnitAnimator.lua): front = -Z, feet on y = 0, root
-- part = HumanoidRootPart at RootHeight. Hind legs: LHip/RHip + LKnee/RKnee on the pelvis; front legs: LShoulder/RShoulder +
-- LElbow/RElbow on the torso. Root/Waist/Neck/Jaw as usual.
-- Look (from the user's reference picture): a MIGHTY horse of black faceted obsidian, cracked all over with glowing rainbow
-- veins; a huge mane and tail of prismatic fire; a white star for an eye; a long crystal horn shading through the rainbow;
-- heavy hooves on rainbow light; and a BROKEN RING of dark stone blocks with glowing rainbow rims hovering round its head and
-- neck, slowly turning in its own plane (the SpinHalo joint, see UnitAnimator spinners), with floating rocks around it.
-- The horn tip is the part HornTip (for the planned spiral beam).
local ServerStorage = game:GetService("ServerStorage")
local models = ServerStorage.Models

local old = models:FindFirstChild("PaleSovereign")
if old then
	old:Destroy()
end

local OBSIDIAN = Color3.fromRGB(24, 20, 32)
local OBSIDIAN_EDGE = Color3.fromRGB(46, 40, 60)
local STAR = Color3.fromRGB(255, 255, 255)
local RAINBOW = {
	Color3.fromRGB(255, 60, 90), -- red
	Color3.fromRGB(255, 150, 40), -- orange
	Color3.fromRGB(255, 232, 70), -- yellow
	Color3.fromRGB(80, 255, 130), -- green
	Color3.fromRGB(60, 220, 255), -- cyan
	Color3.fromRGB(90, 110, 255), -- blue
	Color3.fromRGB(190, 80, 255), -- violet
	Color3.fromRGB(255, 90, 220), -- pink
}
local NEON = Enum.Material.Neon
local STONE = Enum.Material.Basalt

local model = Instance.new("Model")
model.Name = "PaleSovereign"

local function part(name, size, cf, color, material, transparency, class)
	local p = Instance.new(class or "Part")
	p.Name = name
	p.Size = size
	p.CFrame = typeof(cf) == "Vector3" and CFrame.new(cf) or cf
	p.Color = color
	p.Material = material or STONE
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

-- joint at a position (or a full CFrame: the joint's axes then follow it, used to spin the ring in its own plane)
local function motor(name, p0, p1, joint)
	local cf = typeof(joint) == "Vector3" and CFrame.new(joint) or joint
	local m = Instance.new("Motor6D")
	m.Name = name
	m.Part0 = p0
	m.Part1 = p1
	m.C0 = p0.CFrame:Inverse() * cf
	m.C1 = p1.CFrame:Inverse() * cf
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

-- a glowing crack: a jagged line of thin neon segments through the given points (world positions)
local crackCount = 0
local function crack(parent, points, color)
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local len = (b - a).Magnitude
		crackCount += 1
		weld(parent, part("Crack" .. crackCount, Vector3.new(0.09, 0.09, len + 0.05), CFrame.lookAt((a + b) / 2, b), color, NEON))
	end
end

-- a flame tongue of prismatic fire
local function flame(parent, name, size, cf, color, transparency)
	weld(parent, part(name, size, cf, color, NEON, transparency, "WedgePart"))
end

-- ── Body: a massive faceted chest and hindquarters ───────────
local ROOT_Y = 4.2
local root = part("HumanoidRootPart", Vector3.new(2.0, 0.6, 2.4), Vector3.new(0, ROOT_Y, 0.6), OBSIDIAN, nil, 1)
model.PrimaryPart = root

local pelvis = part("Pelvis", Vector3.new(2.5, 2.2, 2.6), Vector3.new(0, 4.7, 2.1), OBSIDIAN)
motor("Root", root, pelvis, Vector3.new(0, ROOT_Y, 0.6))
weld(pelvis, part("Rump", Vector3.new(2.2, 1.0, 2.0), CFrame.new(0, 5.85, 2.3) * CFrame.Angles(math.rad(-8), 0, 0), OBSIDIAN_EDGE))
weld(pelvis, part("Haunch", Vector3.new(2.7, 1.6, 1.4), CFrame.new(0, 4.4, 3.2) * CFrame.Angles(math.rad(20), 0, 0), OBSIDIAN))

local torso = part("Torso", Vector3.new(2.7, 2.7, 3.5), Vector3.new(0, 5.0, -0.9), OBSIDIAN)
motor("Waist", pelvis, torso, Vector3.new(0, 4.8, 0.9))
weld(torso, part("Chest", Vector3.new(2.4, 2.4, 1.2), CFrame.new(0, 4.6, -2.8) * CFrame.Angles(math.rad(-14), 0, 0), OBSIDIAN))
weld(torso, part("Belly", Vector3.new(2.2, 0.8, 3.6), Vector3.new(0, 3.75, -0.4), OBSIDIAN_EDGE))
weld(torso, part("Withers", Vector3.new(1.6, 0.9, 2.2), CFrame.new(0, 6.45, -1.6) * CFrame.Angles(math.rad(10), 0, 0), OBSIDIAN_EDGE))
-- a crest of black shards down the spine
for i, z in ipairs({ -1.2, -0.2, 0.8, 1.8, 2.8 }) do
	local h = 1.3 - math.abs(i - 2) * 0.2
	weld(i <= 2 and torso or pelvis, part("Shard" .. i, Vector3.new(0.4, h, 0.9),
		CFrame.new(0, 6.3 + h * 0.35, z) * CFrame.Angles(math.rad(-25), 0, 0), OBSIDIAN_EDGE, STONE, 0, "WedgePart"))
end

-- ── Neck and head ────────────────────────────────────────────
local neckCf = CFrame.new(0, 7.1, -3.0) * CFrame.Angles(math.rad(-28), 0, 0)
weld(torso, part("NeckPart", Vector3.new(1.6, 3.6, 1.9), neckCf, OBSIDIAN))
weld(torso, part("NeckFront", Vector3.new(1.2, 3.0, 0.6), neckCf * CFrame.new(0, -0.2, -0.95), OBSIDIAN_EDGE))

local HEAD_JOINT = Vector3.new(0, 8.5, -3.9)
local headTilt = CFrame.Angles(math.rad(18), 0, 0)
local head = part("Head", Vector3.new(1.4, 1.6, 2.2), CFrame.new(0, 8.9, -4.3) * headTilt, OBSIDIAN)
motor("Neck", torso, head, HEAD_JOINT)
weld(head, part("Brow", Vector3.new(1.5, 0.5, 1.4), CFrame.new(0, 9.65, -4.1) * headTilt, OBSIDIAN_EDGE))
weld(head, part("Muzzle", Vector3.new(1.1, 1.1, 1.7), CFrame.new(0, 8.2, -5.4) * headTilt, OBSIDIAN))
weld(head, part("Nose", Vector3.new(1.0, 0.5, 0.6), CFrame.new(0, 7.95, -6.15) * headTilt, OBSIDIAN_EDGE))
for _, x in ipairs({ -1, 1 }) do
	weld(head, part("Ear", Vector3.new(0.35, 1.1, 0.5), CFrame.new(x * 0.5, 10.1, -3.6) * CFrame.Angles(math.rad(-12), 0, x * math.rad(-10)), OBSIDIAN_EDGE, STONE, 0, "WedgePart"))
	-- the eye: a white star
	local eyePos = Vector3.new(x * 0.72, 9.05, -4.65)
	weld(head, part("Eye", Vector3.new(0.12, 0.26, 0.26), eyePos, STAR, NEON))
	weld(head, part("EyeRayV", Vector3.new(0.06, 0.75, 0.08), eyePos + Vector3.new(x * 0.03, 0, 0), STAR, NEON))
	weld(head, part("EyeRayH", Vector3.new(0.06, 0.08, 0.75), eyePos + Vector3.new(x * 0.03, 0, 0), STAR, NEON))
end
local jaw = part("Jaw", Vector3.new(0.95, 0.35, 1.5), CFrame.new(0, 7.55, -5.3) * headTilt, OBSIDIAN_EDGE)
motor("Jaw", head, jaw, Vector3.new(0, 7.8, -4.6))

-- the horn: a long crystal shading through the rainbow from the base (warm) to the tip (violet)
local HORN_BASE = Vector3.new(0, 10.0, -4.75)
local hornTilt = CFrame.Angles(math.rad(-38), 0, 0)
local hornAxis = (hornTilt * CFrame.new(0, 1, 0)).Position
local HORN_SEGMENTS = 8
for i = 0, HORN_SEGMENTS - 1 do
	local w = 0.62 - i * 0.065
	local color = RAINBOW[math.min(#RAINBOW, 2 + i)]
	weld(head, part("Horn" .. i, Vector3.new(w, 0.58, w), CFrame.new(HORN_BASE + hornAxis * (0.3 + i * 0.52)) * hornTilt * CFrame.Angles(0, math.rad(45 + i * 20), 0), color, NEON, 0.05))
end
local tip = part("HornTip", Vector3.new(0.14, 0.6, 0.14), CFrame.new(HORN_BASE + hornAxis * 4.6) * hornTilt, STAR, NEON)
weld(head, tip)
local hornLight = Instance.new("PointLight")
hornLight.Name = "HornLight"
hornLight.Color = RAINBOW[7]
hornLight.Brightness = 2
hornLight.Range = 16
hornLight.Shadows = false
hornLight.Parent = tip

-- ── The mane and tail: prismatic fire ────────────────────────
-- mane: flame tongues along the back of the neck and over the head, red at the front to violet at the withers
for i = 1, 8 do
	local k = (i - 1) / 7
	local cf = neckCf * CFrame.new(0, 1.9 - k * 3.6, 1.1 + k * 0.3) * CFrame.Angles(math.rad(-60 + k * 20), 0, 0)
	flame(torso, "Mane" .. i, Vector3.new(1.1, 2.4 + math.sin(i) * 0.5, 2.6 + k * 0.8), cf, RAINBOW[i], 0.15 + k * 0.15)
end
flame(head, "Forelock", Vector3.new(0.4, 1.2, 1.2), CFrame.new(0, 10.3, -3.3) * CFrame.Angles(math.rad(-70), 0, 0), RAINBOW[1], 0.2)
-- tail: a long plume flowing back and down
for i = 1, 7 do
	local k = (i - 1) / 6
	local cf = CFrame.new(0, 6.0 - k * 2.8, 3.6 + k * 2.4) * CFrame.Angles(math.rad(-35 - k * 40), 0, 0)
	flame(pelvis, "Tail" .. i, Vector3.new(1.4 - k * 0.4, 2.8 - k * 0.6, 3.0), cf, RAINBOW[#RAINBOW - i + 1], 0.12 + k * 0.25)
end
-- living flames on top of the solid tongues
local function fireEmitter(parent, size, rate)
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/fire_main.dds"
	local keys = {}
	for i, c in ipairs(RAINBOW) do
		table.insert(keys, ColorSequenceKeypoint.new((i - 1) / (#RAINBOW - 1), c))
	end
	e.Color = ColorSequence.new(keys)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size), NumberSequenceKeypoint.new(1, 0) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
	e.Lifetime = NumberRange.new(0.5, 0.9)
	e.Rate = rate
	e.Speed = NumberRange.new(1, 3)
	e.SpreadAngle = Vector2.new(25, 25)
	e.LightEmission = 1
	e.Acceleration = Vector3.new(0, 3, 0)
	e.Parent = parent
end
for _, name in ipairs({ "Mane2", "Mane4", "Mane6", "Mane8", "Tail1", "Tail3", "Tail5" }) do
	fireEmitter(model:FindFirstChild(name), 3.2, 26)
end

-- ── Rainbow cracks over the whole body ───────────────────────
for _, x in ipairs({ -1, 1 }) do
	local sx = x * 1.37
	crack(torso, { Vector3.new(sx, 6.0, -2.2), Vector3.new(sx, 5.3, -1.6), Vector3.new(sx, 5.5, -0.9), Vector3.new(sx, 4.5, -0.2) }, RAINBOW[x == 1 and 7 or 5])
	crack(torso, { Vector3.new(sx, 4.4, -2.1), Vector3.new(sx, 4.0, -1.2), Vector3.new(sx, 4.3, 0.4) }, RAINBOW[x == 1 and 2 or 8])
	local px = x * 1.27
	crack(pelvis, { Vector3.new(px, 5.6, 1.2), Vector3.new(px, 4.9, 1.9), Vector3.new(px, 5.1, 2.6), Vector3.new(px, 4.1, 3.1) }, RAINBOW[x == 1 and 3 or 6])
	crack(torso, { neckCf * Vector3.new(x * 0.82, 1.2, 0), neckCf * Vector3.new(x * 0.82, 0.2, 0.3), neckCf * Vector3.new(x * 0.82, -0.6, -0.2), neckCf * Vector3.new(x * 0.82, -1.5, 0.2) }, RAINBOW[x == 1 and 4 or 1])
	crack(head, { Vector3.new(x * 0.72, 9.6, -3.6), Vector3.new(x * 0.72, 9.2, -4.1), Vector3.new(x * 0.58, 8.4, -4.9) }, RAINBOW[7])
end
crack(torso, { Vector3.new(-0.6, 5.2, -3.42), Vector3.new(0, 4.6, -3.45), Vector3.new(0.5, 3.9, -3.3) }, RAINBOW[2])

-- ── Legs: thick pillars on heavy hooves of rainbow light ─────
local function leg(side, x, z, parent, hipName, kneeName, tag, colorIndex)
	local upper = part(tag .. side .. "Upper", Vector3.new(0.95, 2.3, 1.15), Vector3.new(x, 3.15, z), OBSIDIAN)
	motor(side .. hipName, parent, upper, Vector3.new(x, 4.2, z))
	local lower = part(tag .. side .. "Lower", Vector3.new(0.75, 2.3, 0.9), Vector3.new(x, 1.35, z), OBSIDIAN)
	motor(side .. kneeName, upper, lower, Vector3.new(x, 2.1, z))
	weld(lower, part(tag .. side .. "Knee", Vector3.new(0.95, 0.6, 1.05), Vector3.new(x, 2.1, z), OBSIDIAN_EDGE))
	weld(lower, part(tag .. side .. "Hoof", Vector3.new(1.25, 0.75, 1.35), Vector3.new(x, 0.42, z - 0.08), OBSIDIAN_EDGE))
	weld(lower, part(tag .. side .. "HoofGlow", Vector3.new(1.32, 0.16, 1.42), Vector3.new(x, 0.08, z - 0.08), RAINBOW[colorIndex], NEON))
	local fx = x + (x > 0 and 0.38 or -0.38)
	crack(upper, { Vector3.new(fx, 4.0, z - 0.2), Vector3.new(fx, 3.3, z + 0.15), Vector3.new(fx, 2.6, z - 0.1) }, RAINBOW[colorIndex])
	crack(lower, { Vector3.new(x, 2.0, z - 0.46), Vector3.new(x + 0.1, 1.2, z - 0.46), Vector3.new(x - 0.1, 0.8, z - 0.46) }, RAINBOW[(colorIndex % #RAINBOW) + 1])
end
leg("L", -0.85, 2.6, pelvis, "Hip", "Knee", "Hind", 6)
leg("R", 0.85, 2.6, pelvis, "Hip", "Knee", "Hind", 3)
leg("L", -0.85, -2.1, torso, "Shoulder", "Elbow", "Fore", 8)
leg("R", 0.85, -2.1, torso, "Shoulder", "Elbow", "Fore", 5)

-- ── The broken ring: dark stone blocks with glowing rims, round the head and neck, turning in its own plane ──
local RING_CENTER = Vector3.new(0, 8.6, -2.2)
local RING_RADIUS = 4.6
local ringRoot = part("RingRoot", Vector3.new(0.3, 0.3, 0.3), RING_CENTER, OBSIDIAN, nil, 1)
-- the joint's Y axis points along the ring's normal (Z), so the spinner turns the ring in its own plane
local spin = motor("SpinHalo", torso, ringRoot, CFrame.new(RING_CENTER) * CFrame.Angles(math.rad(90), 0, 0))
spin:SetAttribute("SpinSpeed", 0.25)
local SLOTS = 12
local GAPS = { [3] = true, [7] = true, [8] = true, [11] = true } -- the ring is broken here
local chord = 2 * math.pi * RING_RADIUS / SLOTS * 0.86
for s = 1, SLOTS do
	if not GAPS[s] then
		local a = (s / SLOTS) * math.pi * 2
		local center = RING_CENTER + Vector3.new(math.cos(a) * RING_RADIUS, math.sin(a) * RING_RADIUS, 0)
		local cf = CFrame.new(center) * CFrame.Angles(0, 0, a + math.pi / 2) -- X along the ring, Y pointing outwards
		weld(ringRoot, part("RingBlock" .. s, Vector3.new(chord, 0.75, 0.8), cf, OBSIDIAN_EDGE))
		weld(ringRoot, part("RingRim" .. s, Vector3.new(chord * 0.96, 0.14, 0.84), cf * CFrame.new(0, -0.42, 0), RAINBOW[(s % #RAINBOW) + 1], NEON))
	end
end
-- rocks floating round the ring
for i = 1, 6 do
	local a = (i / 6) * math.pi * 2 + 0.4
	local r = RING_RADIUS + 1.3 + (i % 2) * 0.8
	local size = 0.5 + (i % 3) * 0.25
	local pos = RING_CENTER + Vector3.new(math.cos(a) * r, math.sin(a) * r, (i % 2 == 0) and 0.8 or -0.8)
	weld(ringRoot, part("Rock" .. i, Vector3.one * size, CFrame.new(pos) * CFrame.Angles(a, a * 2, a * 3), OBSIDIAN_EDGE))
	weld(ringRoot, part("RockGlow" .. i, Vector3.one * (size * 0.35), CFrame.new(pos + Vector3.new(0, size * 0.4, 0)) * CFrame.Angles(a, a, 0), RAINBOW[i + 1], NEON))
end

-- a soft prismatic glow from the chest
local chestLight = Instance.new("PointLight")
chestLight.Name = "ChestLight"
chestLight.Color = RAINBOW[8]
chestLight.Brightness = 1.2
chestLight.Range = 14
chestLight.Shadows = false
chestLight.Parent = torso

model:SetAttribute("Rig", "Procedural")
model:SetAttribute("RootHeight", ROOT_Y)
model:SetAttribute("Height", 13)
model:SetAttribute("CastColor", RAINBOW[7])
model:SetAttribute("CastPart", "HornTip")
model.Parent = models

local count = 0
for _, d in ipairs(model:GetDescendants()) do
	if d:IsA("Motor6D") then count += 1 end
end
return "PaleSovereign built: " .. #model:GetChildren() .. " parts, " .. count .. " joints"
