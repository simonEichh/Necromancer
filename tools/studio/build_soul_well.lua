-- The plaza, batch 2 of "The Ossuary Court" (docs/world.md): the Soul Well in the centre. Safe to re-run.
-- Run in Edit mode (Studio MCP execute_luau or loadstring from the tools/studio http server); save the place after.
-- Replaces the old monument (Podium, MonumentBase/Step/Shaft/Cap, Beacon: moved to ServerStorage.RetiredPlaza, not
-- deleted). The well (HubDecor.SoulWell):
--   * a round curb of dark obsidian blocks with bone cap stones and a skull on every other block, candles on the rim
--   * inside it a void: a flat near-black Neon disc (no shading, so it reads as a bottomless hole) with a dim violet
--     glow ring round its edge, souls (particles) spiralling up out of it and a thin pale beam up into the sky
--   * six bone ribs rising from the curb and curving in over the well like a ribcage, meeting under a crown of runes
--     (SoulWellCrown, tagged SpinFx: the client's WorldFx turns it)
-- Later (batch 2b): when anyone pulls something rare or ascends, a big soul bursts out of it and the beam flares.
local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")
local hub = workspace:FindFirstChild("HubDecor")
assert(hub, "HubDecor missing")

local FLOOR_TOP = -1.7
local CENTRE = Vector3.new(0, FLOOR_TOP, 0)

local OBSIDIAN = Color3.fromRGB(34, 30, 40)
local OBSIDIAN_LIGHT = Color3.fromRGB(52, 46, 60)
local BONE = Color3.fromRGB(104, 94, 80) -- (darker than it looks: the well's own violet light washes it out)
local BONE_DARK = Color3.fromRGB(78, 70, 60)
local VOID = Color3.fromRGB(10, 6, 20)
local SOUL = Color3.fromRGB(150, 110, 240)
local SOUL_PALE = Color3.fromRGB(205, 190, 255)
local FLAME = Color3.fromRGB(170, 255, 200)

local R_OUT, R_IN = 7.4, 5.4 -- the curb
local CURB_H = 1.7
local SEGMENTS = 16
local RIBS = 6
local CROWN_Y = 17 -- the crown's height above the floor

-- ── retire the old monument ─────────────────────────────
local retired = ServerStorage:FindFirstChild("RetiredPlaza")
if not retired then
	retired = Instance.new("Folder")
	retired.Name = "RetiredPlaza"
	retired.Parent = ServerStorage
end
for _, name in ipairs({ "Podium", "MonumentBase", "MonumentStep", "MonumentShaft", "MonumentCap", "Beacon" }) do
	local p = hub:FindFirstChild(name)
	if p then
		p.Parent = retired
	end
end
local old = hub:FindFirstChild("SoulWell")
if old then
	old:Destroy()
end

local well = Instance.new("Model")
well.Name = "SoulWell"

local function part(name, size, cf, color, material, shape, parent)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.Slate
	if shape then
		p.Shape = shape
	end
	p.Parent = parent or well
	return p
end
local function flatCylinder(name, diameter, height, y, color, material, parent)
	return part(name, Vector3.new(height, diameter, diameter), CFrame.new(CENTRE + Vector3.new(0, y, 0)) * CFrame.Angles(0, 0, math.pi / 2), color, material, Enum.PartType.Cylinder, parent)
end

-- a skull: cranium, jaw, deep eye sockets, nose, a line of teeth (`cf`: its -Z looks out at the viewer)
local function skull(cf, bone, dark)
	part("Skull", Vector3.new(0.95, 0.95, 0.95), cf * CFrame.new(0, 0.1, 0), bone, Enum.Material.Limestone, Enum.PartType.Ball)
	part("SkullJaw", Vector3.new(0.55, 0.34, 0.5), cf * CFrame.new(0, -0.3, -0.12), bone, Enum.Material.Limestone)
	for _, s in ipairs({ -1, 1 }) do
		part("SkullEye", Vector3.new(0.3, 0.3, 0.3), cf * CFrame.new(s * 0.2, 0.08, -0.33), dark, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	end
	part("SkullNose", Vector3.new(0.12, 0.14, 0.1), cf * CFrame.new(0, -0.1, -0.42), dark, Enum.Material.SmoothPlastic)
	part("SkullTeeth", Vector3.new(0.4, 0.05, 0.05), cf * CFrame.new(0, -0.33, -0.39), dark, Enum.Material.SmoothPlastic)
end

-- ── the base step and the curb ──────────────────────────
-- (a low round step the well stands on; the curb blocks are solid so players walk round it)
local step = flatCylinder("WellStep", R_OUT * 2 + 3, 0.5, 0.25, OBSIDIAN_LIGHT, Enum.Material.Slate)
step.CanCollide = true
local segAngle = math.pi * 2 / SEGMENTS
local rMid = (R_OUT + R_IN) / 2
local segLen = 2 * R_OUT * math.sin(segAngle / 2) + 0.15 -- (the outer face closes; the overlap hides inside)
for k = 0, SEGMENTS - 1 do
	local a = (k + 0.5) * segAngle
	local mid = CENTRE + Vector3.new(math.cos(a) * rMid, 0, math.sin(a) * rMid)
	local frame = CFrame.lookAt(mid, mid - Vector3.new(-math.sin(a), 0, math.cos(a)))
	-- (frame: +X points outwards, Z runs along the curb)
	local block = part("Curb", Vector3.new(R_OUT - R_IN, CURB_H, segLen), frame * CFrame.new(0, 0.5 + CURB_H / 2, 0), k % 2 == 0 and OBSIDIAN or OBSIDIAN_LIGHT, Enum.Material.Basalt)
	block.CanCollide = true
	-- the bone cap stone, a little proud on both sides
	part("CurbCap", Vector3.new(R_OUT - R_IN + 0.5, 0.35, segLen + 0.06), frame * CFrame.new(0, 0.5 + CURB_H + 0.175, 0), BONE_DARK, Enum.Material.Limestone)
	if k % 2 == 0 then
		-- a skull set into the outer face: a dome, two dark eye sockets
		-- (+X of the frame points outwards: turn the skull's -Z that way)
		skull(frame * CFrame.new((R_OUT - R_IN) / 2 + 0.05, 0.5 + CURB_H * 0.5, 0) * CFrame.Angles(0, -math.pi / 2, 0), BONE, VOID)
	else
		-- a candle on the rim
		local base = frame * CFrame.new(0.2, 0.5 + CURB_H + 0.35, 0)
		part("Candle", Vector3.new(0.3, 0.75, 0.3), base * CFrame.new(0, 0.375, 0), Color3.fromRGB(200, 196, 180), Enum.Material.SmoothPlastic)
		local flame = part("CandleFlame", Vector3.new(0.18, 0.3, 0.18), base * CFrame.new(0, 0.9, 0), FLAME, Enum.Material.Neon, Enum.PartType.Ball)
		local l = Instance.new("PointLight")
		l.Color = FLAME
		l.Range = 5
		l.Brightness = 0.6
		l.Shadows = false
		l.Parent = flame
	end
end

-- ── the void ────────────────────────────────────────────
-- (the floor is solid: no real hole, so a flat near-black Neon disc reads as a bottomless one)
local void = flatCylinder("Void", R_IN * 2 + 0.2, 0.2, 0.6, VOID, Enum.Material.Neon)
local glowRing = flatCylinder("VoidGlow", R_IN * 2 + 0.1, 0.12, 0.72, SOUL, Enum.Material.Neon)
glowRing.Transparency = 0.55
flatCylinder("VoidCore", R_IN * 2 - 1.6, 0.12, 0.8, VOID, Enum.Material.Neon) -- (the glow stays a ring at the edge)
local light = Instance.new("PointLight")
light.Color = SOUL
light.Range = 16
light.Brightness = 1
light.Shadows = false
light.Parent = void

-- souls spiralling up out of it, and a faint mist on the surface
local emitterHolder = part("SoulSource", Vector3.new(R_IN * 1.6, 0.2, R_IN * 1.6), CFrame.new(CENTRE + Vector3.new(0, 0.9, 0)), VOID)
emitterHolder.Transparency = 1
local souls = Instance.new("ParticleEmitter")
souls.Name = "Souls"
souls.Texture = "rbxasset://textures/particles/sparkles_main.dds"
souls.Color = ColorSequence.new(SOUL_PALE, SOUL)
souls.LightEmission = 1
souls.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(0.3, 0.7), NumberSequenceKeypoint.new(1, 0) })
souls.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0.1), NumberSequenceKeypoint.new(1, 1) })
souls.Lifetime = NumberRange.new(3, 5)
souls.Speed = NumberRange.new(3, 6)
souls.SpreadAngle = Vector2.new(12, 12)
souls.Rotation = NumberRange.new(0, 360)
souls.RotSpeed = NumberRange.new(-60, 60)
souls.Rate = 14
souls.EmissionDirection = Enum.NormalId.Top
souls.VelocitySpread = 12
souls.Parent = emitterHolder
local swirl = Instance.new("ParticleEmitter")
swirl.Name = "Mist"
swirl.Texture = "rbxasset://textures/particles/smoke_main.dds"
swirl.Color = ColorSequence.new(Color3.fromRGB(70, 50, 120), Color3.fromRGB(30, 20, 50))
swirl.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 5) })
swirl.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.75), NumberSequenceKeypoint.new(1, 1) })
swirl.Lifetime = NumberRange.new(2.5, 4)
swirl.Speed = NumberRange.new(0.5, 1.5)
swirl.Rotation = NumberRange.new(0, 360)
swirl.RotSpeed = NumberRange.new(-25, 25)
swirl.Rate = 5
swirl.LightInfluence = 0.3
swirl.EmissionDirection = Enum.NormalId.Top
swirl.Parent = emitterHolder

-- the beam into the sky (a Beam between the void and a point high above: thin, pale, flickering softly)
local a0 = Instance.new("Attachment")
a0.Name = "BeamBottom"
a0.Parent = emitterHolder
local skyAnchor = part("BeamTop", Vector3.new(0.2, 0.2, 0.2), CFrame.new(CENTRE + Vector3.new(0, 140, 0)), VOID)
skyAnchor.Transparency = 1
local a1 = Instance.new("Attachment")
a1.Name = "BeamTopAttachment"
a1.Parent = skyAnchor
local beam = Instance.new("Beam")
beam.Name = "SoulBeam"
beam.Attachment0 = a0
beam.Attachment1 = a1
beam.Color = ColorSequence.new(SOUL_PALE, SOUL)
beam.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(0.6, 0.7), NumberSequenceKeypoint.new(1, 1) })
beam.Width0 = 1.6
beam.Width1 = 0.6
beam.LightEmission = 1
beam.LightInfluence = 0
beam.FaceCamera = true
beam.Segments = 2
beam.Parent = emitterHolder

-- ── the ribs ────────────────────────────────────────────
-- each rib leaves the curb's top, rises and bends in over the well to meet the others under the crown
local RIB_SEGS = 9
for r = 0, RIBS - 1 do
	local a = r / RIBS * math.pi * 2 + segAngle / 2
	local out = Vector3.new(math.cos(a), 0, math.sin(a))
	local pts = {}
	for k = 0, RIB_SEGS do
		local t = k / RIB_SEGS
		-- radius from the curb in to the crown, height up a quarter-ellipse (steep at first, curling in at the top)
		local radius = rMid + (1.6 - rMid) * (1 - math.cos(t * math.pi / 2))
		local y = 0.5 + CURB_H + 0.3 + (CROWN_Y - 1.2 - CURB_H) * math.sin(t * math.pi / 2)
		table.insert(pts, CENTRE + out * radius + Vector3.new(0, y, 0))
	end
	for k = 1, RIB_SEGS do
		local p0, p1 = pts[k], pts[k + 1]
		local thick = 1.05 - 0.55 * (k / RIB_SEGS)
		part("Rib", Vector3.new(thick, thick * 0.8, (p1 - p0).Magnitude + thick * 0.6), CFrame.lookAt((p0 + p1) / 2, p1), k % 3 == 0 and BONE_DARK or BONE, Enum.Material.Limestone)
	end
	-- a knuckle where the rib leaves the curb
	part("RibKnuckle", Vector3.new(1.1, 1.1, 1.1), CFrame.new(pts[1]), BONE_DARK, Enum.Material.Limestone, Enum.PartType.Ball)
end

-- ── the crown of runes (turned by the client's WorldFx) ──
local crown = Instance.new("Model")
crown.Name = "SoulWellCrown"
local hubPart = part("CrownHub", Vector3.new(0.4, 0.4, 0.4), CFrame.new(CENTRE + Vector3.new(0, CROWN_Y, 0)), SOUL, Enum.Material.Neon, nil, crown)
hubPart.Transparency = 1
crown.PrimaryPart = hubPart
local CROWN_R = 2.6
for k = 0, 23 do
	local a0c, a1c = k / 24 * math.pi * 2, (k + 1) / 24 * math.pi * 2
	local p0 = CENTRE + Vector3.new(math.cos(a0c) * CROWN_R, CROWN_Y, math.sin(a0c) * CROWN_R)
	local p1 = CENTRE + Vector3.new(math.cos(a1c) * CROWN_R, CROWN_Y, math.sin(a1c) * CROWN_R)
	part("CrownRing", Vector3.new(0.18, 0.18, (p1 - p0).Magnitude + 0.05), CFrame.lookAt((p0 + p1) / 2, p1), SOUL, Enum.Material.Neon, nil, crown)
	if k % 3 == 0 then
		local p = CENTRE + Vector3.new(math.cos(a0c) * (CROWN_R + 0.5), CROWN_Y, math.sin(a0c) * (CROWN_R + 0.5))
		part("CrownRune", Vector3.new(0.12, 0.7, 0.35), CFrame.lookAt(p, CENTRE + Vector3.new(0, CROWN_Y, 0)), SOUL_PALE, Enum.Material.Neon, nil, crown)
	end
end
-- a soul flame held in the crown
local heart = part("CrownHeart", Vector3.new(1.1, 1.1, 1.1), CFrame.new(CENTRE + Vector3.new(0, CROWN_Y, 0)), SOUL_PALE, Enum.Material.Neon, Enum.PartType.Ball, crown)
heart.Transparency = 0.15
local heartLight = Instance.new("PointLight")
heartLight.Color = SOUL
heartLight.Range = 14
heartLight.Brightness = 0.6
heartLight.Shadows = false
heartLight.Parent = heart
crown:SetAttribute("SpinSpeed", 0.35)
crown.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
crown.Parent = well
CollectionService:AddTag(crown, "SpinFx")

well.ModelStreamingMode = Enum.ModelStreamingMode.Persistent -- (the centre of the map: always there)
well.Parent = hub
local n = 0
for _, d in ipairs(well:GetDescendants()) do
	if d:IsA("BasePart") then
		n += 1
	end
end
return "soul well done: " .. n .. " parts"
