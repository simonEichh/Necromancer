-- Builds the Soul Altar (the realm upgrades in the world, see CLAUDE.md "The Soul Altar") into ServerStorage.LaneModels:
--   AltarCore            the same in every realm: a stepped stone dais with a carved altar, an open bone tome, candles and a
--                        skull; four tower braziers (one per realm upgrade, models "Brazier" with the attribute Upgrade and
--                        a "FlameAnchor" part carrying the flame emitters + light); two rings of floating runes circling
--                        the altar (SpinFx, turned by the client WorldFx); the BONE BRIDGE (a giant spine as the deck, ribs
--                        as railings, a half-sunk skull at the island end, soul light between the bones) from the lane
--                        shoulder at the plot's front corner out to the island; invisible collision for the deck, rails
--                        and the ramp over the skull.
--   CemeteryAltarIsland  Realm 1's ground: a round island of dark earth and moss on a ring of fieldstone columns standing in
--                        the hazard, flagstones, leaning tombstones, a broken iron fence, rocks and bones.
-- Both are built in the plot frame (like CemeteryPlot): x = across (+ = the plot's right), y = up (0 = the plot floor),
-- forward (down the lane) = -Z. The island stands to the right of the plot beside the lane start. The server module
-- PlotLook clones both onto a claimed plot. A preview copy is put on Plot1 (Workspace.AltarPreview: delete before
-- publishing). Run in Edit mode via the Studio MCP (or loadstring, see CLAUDE.md). Safe to re-run.
local ServerStorage = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")

local folder = ServerStorage:FindFirstChild("LaneModels")
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "LaneModels"
	folder.Parent = ServerStorage
end
for _, name in ipairs({ "AltarCore", "CemeteryAltarIsland" }) do
	local old = folder:FindFirstChild(name)
	if old then
		old:Destroy()
	end
end

-- ============================================================
-- Layout (plot frame)
-- ============================================================
local ISLAND_LAT, ISLAND_FWD = 40, 15 -- centre of the island
local ISLAND_R = 9.5
local BRIDGE_LAT, BRIDGE_FWD = 23.5, 33.5 -- the bridge starts on the lane shoulder, clear of the end of the plot's side wall (fwd 28.3)
local SHOULDER_Y = -0.35 -- top of the lane shoulder

local BONE = Color3.fromRGB(204, 192, 166)
local BONE_MID = Color3.fromRGB(176, 164, 140)
local BONE_DARK = Color3.fromRGB(132, 122, 104)
local SOCKET = Color3.fromRGB(18, 16, 16)
local STONE = { Color3.fromRGB(84, 86, 88), Color3.fromRGB(96, 97, 98), Color3.fromRGB(74, 76, 80) }
local STONE_LIGHT = Color3.fromRGB(122, 122, 118)
local STONE_DARK = Color3.fromRGB(56, 58, 62)
local BASALT = { Color3.fromRGB(46, 47, 54), Color3.fromRGB(56, 57, 64), Color3.fromRGB(40, 41, 48) }
local EARTH = Color3.fromRGB(56, 46, 40)
local MOSS = Color3.fromRGB(72, 94, 52)
local GRASS = Color3.fromRGB(58, 82, 48)
local IRON = Color3.fromRGB(46, 40, 38)
local IRON_DARK = Color3.fromRGB(32, 28, 28)
local LEATHER = Color3.fromRGB(70, 34, 34)
local PAGE = Color3.fromRGB(226, 214, 186)
local CANDLE = Color3.fromRGB(232, 222, 196)
local FLAME_WARM = Color3.fromRGB(255, 176, 90)
local SOUL = Color3.fromRGB(110, 255, 180)
local RUNE_INNER = Color3.fromRGB(176, 120, 255)

-- the four realm upgrades (Economy.REALM_UPGRADES keys) and their flames; side -1 = left, front -1 = towards the bridge
local BRAZIERS = {
	{ key = "might", color = Color3.fromRGB(255, 44, 54), side = -1, front = -1 },
	{ key = "harvest", color = Color3.fromRGB(255, 186, 52), side = -1, front = 1 },
	{ key = "march", color = Color3.fromRGB(80, 255, 130), side = 1, front = 1 },
	{ key = "magnet", color = Color3.fromRGB(176, 84, 255), side = 1, front = -1 },
}

local rng = Random.new(4471)
local up = Vector3.yAxis

local function P(lat, fwd, y)
	return Vector3.new(lat, y or 0, -fwd)
end

local function part(parent, name, size, cf, color, material, shape)
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
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if shape then
		p.Shape = shape
	end
	p.Parent = parent
	return p
end

-- invisible walkable / blocking collision (PlotLook puts every colliding part in the Decor group: players only)
local function collider(parent, name, size, cf)
	local p = part(parent, name, size, cf, STONE_DARK)
	p.Transparency = 1
	p.CanCollide = true
	p.CanQuery = true
	return p
end

-- a block from a to b (bones, ribs, rune strokes)
local function segment(parent, name, a, b, w, h, color, material)
	local len = (b - a).Magnitude
	return part(parent, name, Vector3.new(w, h or w, len + math.min(w, h or w) * 0.5), CFrame.lookAt((a + b) / 2, b), color, material)
end

-- an upright disc (cylinder) of radius r and height h, top at y = top
local function disc(parent, name, center, r, h, top, color, material)
	return part(parent, name, Vector3.new(h, r * 2, r * 2), CFrame.new(center.X, top - h / 2, center.Z) * CFrame.Angles(0, 0, math.pi / 2),
		color, material, Enum.PartType.Cylinder)
end

local function newModel(name, parent)
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

local C = P(ISLAND_LAT, ISLAND_FWD, 0) -- island centre on the floor level
local S = P(BRIDGE_LAT, BRIDGE_FWD, 0) -- bridge start
local toS = (S - C) * Vector3.new(1, 0, 1)
local bridgeOut = toS.Unit -- from the island centre towards the bridge / the plot
local E = C + bridgeOut * (ISLAND_R - 0.5) -- where the bridge meets the island
local altarCF = CFrame.lookAt(C, C + bridgeOut) -- the altar's front (-Z) faces the bridge

-- ============================================================
-- AltarCore
-- ============================================================
local core = Instance.new("Model")
core.Name = "AltarCore"

-- ── The dais and the altar ──────────────────────────────────
local altar = newModel("Altar", core)
local function A(x, y, z)
	return altarCF * CFrame.new(x, y, z)
end
local step1 = part(altar, "Step", Vector3.new(7.4, 0.5, 7.4), A(0, 0.25, 0), STONE[2])
step1.CanCollide = true
local step2 = part(altar, "Step", Vector3.new(5.6, 0.5, 5.6), A(0, 0.75, 0), STONE[1])
step2.CanCollide = true
for _, side in ipairs({ -1, 1 }) do
	-- cracks and chipped corners on the steps
	part(altar, "Crack", Vector3.new(0.12, 0.04, 2.6), A(side * 1.6, 1.01, side * 0.8) * CFrame.Angles(0, side * 0.5, 0), STONE_DARK)
	part(altar, "Chip", Vector3.new(0.9, 0.5, 0.9), A(side * 3.4, 0.2, -side * 3.4) * CFrame.Angles(0, 0.4, 0.15), STONE[3])
end
-- the altar block with trims and corner posts
part(altar, "AltarBody", Vector3.new(4.2, 1.8, 2.4), A(0, 1.9, 0.3), STONE[3])
part(altar, "AltarTrim", Vector3.new(4.7, 0.3, 2.9), A(0, 1.15, 0.3), STONE_DARK)
part(altar, "AltarTop", Vector3.new(4.7, 0.35, 2.9), A(0, 2.95, 0.3), STONE_LIGHT)
for _, sx in ipairs({ -1, 1 }) do
	for _, sz in ipairs({ -1, 1 }) do
		part(altar, "AltarPost", Vector3.new(0.55, 2.0, 0.55), A(sx * 2.15, 1.95, 0.3 + sz * 1.25), STONE[2])
		part(altar, "PostCap", Vector3.new(0.75, 0.3, 0.75), A(sx * 2.15, 3.2, 0.3 + sz * 1.25), STONE_LIGHT)
	end
end
-- a carved skull on the front, its eyes glowing
part(altar, "Relief", Vector3.new(1.0, 0.85, 0.2), A(0, 2.0, -0.95), BONE_DARK)
part(altar, "Relief", Vector3.new(0.6, 0.35, 0.2), A(0, 1.5, -0.95), BONE_DARK)
for _, sx in ipairs({ -1, 1 }) do
	part(altar, "Glow", Vector3.new(0.22, 0.22, 0.1), A(sx * 0.22, 2.08, -1.07), SOUL, Enum.Material.Neon)
	part(altar, "Panel", Vector3.new(0.9, 1.1, 0.12), A(sx * 1.35, 1.9, -0.92), STONE_DARK)
	part(altar, "Glow", Vector3.new(0.08, 0.7, 0.06), A(sx * 1.35, 1.9, -0.99), SOUL, Enum.Material.Neon)
	part(altar, "Glow", Vector3.new(0.45, 0.08, 0.06), A(sx * 1.35, 2.05, -0.99) * CFrame.Angles(0, 0, sx * 0.6), SOUL, Enum.Material.Neon)
end
-- the open bone tome, tilted towards the bridge, runes glowing on its pages
local tome = A(0, 3.2, 0.25) * CFrame.Angles(math.rad(-14), 0, 0)
for _, side in ipairs({ -1, 1 }) do
	local half = tome * CFrame.new(side * 0.55, 0, 0) * CFrame.Angles(0, 0, -side * math.rad(7))
	part(altar, "Cover", Vector3.new(1.15, 0.1, 1.5), half, LEATHER)
	part(altar, "Pages", Vector3.new(1.0, 0.14, 1.36), half * CFrame.new(0, 0.1, 0), PAGE)
	for k = 0, 2 do
		part(altar, "Glow", Vector3.new(0.6 - k * 0.12, 0.03, 0.06), half * CFrame.new(-side * 0.02, 0.18, -0.4 + k * 0.32), SOUL, Enum.Material.Neon)
	end
	for _, sz in ipairs({ -1, 1 }) do
		part(altar, "BoneCorner", Vector3.new(0.2, 0.14, 0.2), half * CFrame.new(side * 0.5, 0.04, sz * 0.68), BONE)
	end
end
part(altar, "Spine", Vector3.new(0.16, 0.16, 1.5), tome * CFrame.new(0, -0.02, 0), BONE_DARK)
do
	local glowHolder = part(altar, "TomeLight", Vector3.new(0.2, 0.2, 0.2), tome * CFrame.new(0, 0.8, 0), SOUL)
	glowHolder.Transparency = 1
	local light = Instance.new("PointLight")
	light.Color = SOUL
	light.Range = 9
	light.Brightness = 1.2
	light.Shadows = false
	light.Parent = glowHolder
end
-- candles on the altar top and the dais, and a skull beside the tome
local function candle(cf, h)
	part(altar, "Candle", Vector3.new(h, 0.26, 0.26), cf * CFrame.new(0, h / 2, 0) * CFrame.Angles(0, 0, math.pi / 2), CANDLE, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	part(altar, "CandleFlame", Vector3.new(0.14, 0.26, 0.14), cf * CFrame.new(0, h + 0.15, 0), FLAME_WARM, Enum.Material.Neon)
end
candle(A(-1.85, 3.12, 1.2), 0.7)
candle(A(-1.5, 3.12, 1.3), 0.45)
candle(A(1.8, 3.12, 1.15), 0.6)
candle(A(-2.4, 1.0, -2.4), 0.9)
candle(A(2.4, 1.0, -2.3), 0.55)
candle(A(2.1, 1.0, 2.5), 0.75)
do
	local warm = part(altar, "CandleLight", Vector3.new(0.2, 0.2, 0.2), A(0, 4.2, 0.9), FLAME_WARM)
	warm.Transparency = 1
	local light = Instance.new("PointLight")
	light.Color = FLAME_WARM
	light.Range = 8
	light.Brightness = 0.8
	light.Shadows = false
	light.Parent = warm
	local skull = A(1.45, 3.4, 0.6) * CFrame.Angles(0, -0.5, 0)
	part(altar, "Skull", Vector3.new(0.62, 0.55, 0.66), skull, BONE)
	part(altar, "SkullJaw", Vector3.new(0.46, 0.18, 0.4), skull * CFrame.new(0, -0.3, -0.1), BONE_MID)
	for _, sx in ipairs({ -1, 1 }) do
		part(altar, "Socket", Vector3.new(0.16, 0.14, 0.06), skull * CFrame.new(sx * 0.14, 0.04, -0.33), SOCKET)
	end
end

-- ── The four braziers ───────────────────────────────────────
local function flameEmitters(anchor, color)
	local fire = Instance.new("ParticleEmitter")
	fire.Name = "Flame"
	fire.Texture = "rbxasset://textures/particles/fire_main.dds"
	fire.Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.35), color)
	fire.LightEmission = 1
	fire.LightInfluence = 0
	fire.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.3), NumberSequenceKeypoint.new(0.6, 0.9), NumberSequenceKeypoint.new(1, 0.1) })
	fire.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(0.7, 0.4), NumberSequenceKeypoint.new(1, 1) })
	fire.Lifetime = NumberRange.new(0.5, 0.9)
	fire.Speed = NumberRange.new(2.5, 4.5)
	fire.SpreadAngle = Vector2.new(12, 12)
	fire.RotSpeed = NumberRange.new(-60, 60)
	fire.Rotation = NumberRange.new(0, 360)
	fire.Rate = 28
	fire.EmissionDirection = Enum.NormalId.Top
	fire.Parent = anchor
	local souls = Instance.new("ParticleEmitter")
	souls.Name = "Souls"
	souls.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	souls.Color = ColorSequence.new(color)
	souls.LightEmission = 1
	souls.LightInfluence = 0
	souls.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0.05) })
	souls.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
	souls.Lifetime = NumberRange.new(1.6, 2.6)
	souls.Speed = NumberRange.new(1.2, 2.4)
	souls.SpreadAngle = Vector2.new(25, 25)
	souls.Rate = 4
	souls.EmissionDirection = Enum.NormalId.Top
	souls.Parent = anchor
	local light = Instance.new("PointLight")
	light.Name = "FlameLight"
	light.Color = color
	light.Range = 12
	light.Brightness = 1.6
	light.Shadows = false
	light.Parent = anchor
end

for _, b in ipairs(BRAZIERS) do
	local m = newModel("Brazier", core)
	m:SetAttribute("Upgrade", b.key)
	m:SetAttribute("FlameColor", b.color)
	local base = A(b.side * 3.95, 0, b.front * 3.95) * CFrame.Angles(0, b.side * b.front * math.rad(45), 0)
	local function B(x, y, z)
		return base * CFrame.new(x, y, z)
	end
	part(m, "Plinth", Vector3.new(2.3, 0.6, 2.3), B(0, 0.3, 0), STONE_DARK)
	part(m, "Pillar", Vector3.new(1.75, 1.8, 1.75), B(0, 1.5, 0), STONE[rng:NextInteger(1, 3)])
	part(m, "Pillar", Vector3.new(1.5, 1.7, 1.5), B(0, 3.2, 0), STONE[rng:NextInteger(1, 3)])
	part(m, "Band", Vector3.new(1.9, 0.25, 1.9), B(0, 2.42, 0), STONE_DARK)
	part(m, "Cap", Vector3.new(2.2, 0.4, 2.2), B(0, 4.2, 0), STONE_LIGHT)
	-- the iron bowl with corner spikes, coals glowing in the flame's colour
	for k = 0, 3 do
		local face = B(0, 4.75, 0) * CFrame.Angles(0, k * math.pi / 2, 0)
		part(m, "Bowl", Vector3.new(2.1, 0.7, 0.18), face * CFrame.new(0, 0, -0.98) * CFrame.Angles(math.rad(-12), 0, 0), IRON)
		local corner = B(0, 0, 0) * CFrame.Angles(0, k * math.pi / 2 + math.pi / 4, 0)
		part(m, "Spike", Vector3.new(0.18, 0.95, 0.18), corner * CFrame.new(0, 5.35, -1.45) * CFrame.Angles(math.rad(-18), 0, 0), IRON_DARK)
	end
	part(m, "Coals", Vector3.new(1.7, 0.25, 1.7), B(0, 4.65, 0), b.color, Enum.Material.Neon)
	-- a rune carved into the pillar's outer face, glowing in the flame's colour
	local face = B(0, 3.2, 0.76)
	part(m, "Rune", Vector3.new(0.1, 0.9, 0.06), face, b.color, Enum.Material.Neon)
	part(m, "Rune", Vector3.new(0.5, 0.08, 0.06), face * CFrame.new(0, 0.25, 0) * CFrame.Angles(0, 0, 0.6), b.color, Enum.Material.Neon)
	part(m, "Rune", Vector3.new(0.5, 0.08, 0.06), face * CFrame.new(0, -0.15, 0) * CFrame.Angles(0, 0, -0.6), b.color, Enum.Material.Neon)
	local anchor = part(m, "FlameAnchor", Vector3.new(1.4, 0.2, 1.4), B(0, 4.85, 0), b.color)
	anchor.Transparency = 1
	flameEmitters(anchor, b.color)
	local blocker = collider(m, "BrazierCollider", Vector3.new(2.0, 5, 2.0), B(0, 2.5, 0))
	blocker.Name = "BrazierCollider"
end
collider(altar, "AltarCollider", Vector3.new(4.7, 2.4, 2.9), A(0, 2.2, 0.3))

-- ── Floating runes circling the altar ───────────────────────
-- each glyph: strokes (x0, y0, x1, y1) in a box -0.5..0.5 x -0.7..0.7
local GLYPHS = {
	{ { 0, -0.7, 0, 0.7 }, { 0, 0.3, 0.45, 0.65 }, { 0, 0.3, -0.45, 0.65 } },
	{ { -0.3, -0.7, -0.3, 0.7 }, { -0.3, 0.7, 0.35, 0.2 }, { 0.35, 0.2, -0.3, -0.1 } },
	{ { 0, -0.7, 0, 0.7 }, { 0, 0.7, 0.45, 0.35 }, { 0, 0.25, 0.45, -0.1 } },
	{ { -0.35, -0.7, -0.35, 0.7 }, { 0.35, -0.7, 0.35, 0.7 }, { -0.35, 0.3, 0.35, -0.3 } },
	{ { -0.4, 0.7, 0.4, -0.7 }, { 0.4, 0.7, -0.4, -0.7 } },
	{ { 0, -0.7, 0, 0.7 }, { -0.4, 0.4, 0.4, -0.1 } },
	{ { -0.4, 0.7, 0, 0 }, { 0, 0, 0.4, 0.7 }, { 0, 0, 0, -0.7 } },
	{ { 0, 0.65, 0.4, 0 }, { 0.4, 0, 0, -0.65 }, { 0, -0.65, -0.4, 0 }, { -0.4, 0, 0, 0.65 } },
}
local function rune(parent, cf, glyph, scale, color)
	for _, s in ipairs(glyph) do
		local a = cf * Vector3.new(s[1] * scale, s[2] * scale, 0)
		local b = cf * Vector3.new(s[3] * scale, s[4] * scale, 0)
		local len = (b - a).Magnitude
		local mid = (a + b) / 2
		-- the stroke lies in the rune's plane (its up = the rune's facing)
		part(parent, "Rune", Vector3.new(0.13 * scale, 0.07 * scale, len + 0.1 * scale),
			CFrame.lookAt(mid, b, cf.LookVector), color, Enum.Material.Neon)
	end
end
local function runeRing(name, radius, height, count, scale, color, speed, wobble)
	local ring = newModel(name, core)
	local hub = part(ring, "Hub", Vector3.new(0.2, 0.2, 0.2), altarCF * CFrame.new(0, height, 0.3), color)
	hub.Transparency = 1
	ring.PrimaryPart = hub
	ring.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	ring:SetAttribute("SpinSpeed", speed)
	CollectionService:AddTag(ring, "SpinFx")
	for k = 0, count - 1 do
		local a = k / count * 2 * math.pi
		local out = Vector3.new(math.cos(a), 0, math.sin(a))
		local pos = hub.Position + out * radius + up * (math.sin(a * 3) * wobble)
		-- the glyph faces outwards, leaning in a little like a ring of cards
		local cf = CFrame.lookAt(pos, pos + out) * CFrame.Angles(math.rad(-8), 0, 0)
		rune(ring, cf, GLYPHS[(k % #GLYPHS) + 1], scale, color)
	end
	return ring
end
runeRing("RuneRing", 4.6, 3.6, 14, 0.95, SOUL, 0.22, 0.35)
runeRing("RuneRingInner", 2.9, 5.0, 9, 0.6, RUNE_INNER, -0.38, 0.2)

-- ── The bone bridge ─────────────────────────────────────────
local bridge = newModel("BoneBridge", core)
local Sb = S + up * SHOULDER_Y
local Eb = E
local dir = ((Eb - Sb) * Vector3.new(1, 0, 1)).Unit
local length = ((Eb - Sb) * Vector3.new(1, 0, 1)).Magnitude
local ARCH = 0.9
local function deckY(s)
	local t = s / length
	return SHOULDER_Y * (1 - t) + 0 * t + ARCH * math.sin(math.pi * t)
end
local function deckPos(s)
	local flat = Sb * Vector3.new(1, 0, 1) + dir * s
	return Vector3.new(flat.X, deckY(s), flat.Z)
end
local function deckCF(s)
	local a, b = deckPos(math.max(0, s - 0.2)), deckPos(math.min(length, s + 0.2))
	return CFrame.lookAt(deckPos(s), deckPos(s) + (b - a).Unit)
end
local VERTEBRAE = 10
local spacing = length / VERTEBRAE
for k = 0, VERTEBRAE - 1 do
	local s = (k + 0.5) * spacing
	local cf = deckCF(s)
	local sink = (k == 0) and 0.35 or 0 -- the first one sinks into the shoulder
	local v = cf * CFrame.new(0, -0.42 - sink, 0)
	part(bridge, "Vertebra", Vector3.new(3.3, 0.8, spacing - 0.22), v, (k % 2 == 0) and BONE or BONE_MID)
	part(bridge, "Centrum", Vector3.new(2.0, 0.9, spacing - 0.5), v * CFrame.new(0, -0.75, 0), BONE_MID)
	part(bridge, "Disc", Vector3.new(2.3, 0.6, 0.28), v * CFrame.new(0, -0.25, -spacing / 2), BONE_DARK)
	for _, side in ipairs({ -1, 1 }) do
		part(bridge, "Process", Vector3.new(0.9, 0.45, 0.6), v * CFrame.new(side * 2.0, -0.2, 0) * CFrame.Angles(0, 0, side * 0.25), BONE_MID)
	end
	-- ribs: rising out and up, curving in above the path (smaller near the ends)
	if k >= 1 then
		local size = 0.75 + 0.35 * math.sin(math.pi * (k + 0.5) / VERTEBRAE)
		for _, side in ipairs({ -1, 1 }) do
			local pts = {
				Vector3.new(side * 2.1, -0.3, 0),
				Vector3.new(side * 3.0, 1.4 * size, 0.25),
				Vector3.new(side * 3.15, 3.2 * size, 0.45),
				Vector3.new(side * 2.55, 4.6 * size, 0.55),
				Vector3.new(side * 1.75, 5.25 * size, 0.5),
			}
			for i = 1, #pts - 1 do
				local w = 0.62 - i * 0.08
				segment(bridge, "Rib", v * pts[i], v * pts[i + 1], w, w * 0.85, (i % 2 == 1) and BONE or BONE_MID)
			end
		end
	end
	-- soul light seeping out between the bones
	if k % 2 == 1 then
		part(bridge, "Glow", Vector3.new(1.5, 0.15, 0.2), v * CFrame.new(0, -0.5, -spacing / 2 + 0.05), SOUL, Enum.Material.Neon)
	end
end
-- the soul light under the deck
part(bridge, "Glow", Vector3.new(0.4, 0.2, length - 1.5), deckCF(length / 2) * CFrame.new(0, -1.55, 0), SOUL, Enum.Material.Neon)
do
	local holder = part(bridge, "SoulLight", Vector3.new(0.2, 0.2, 0.2), deckCF(length / 2) * CFrame.new(0, -1.2, 0), SOUL)
	holder.Transparency = 1
	local light = Instance.new("PointLight")
	light.Color = SOUL
	light.Range = 12
	light.Brightness = 1
	light.Shadows = false
	light.Parent = holder
end
-- walkable deck and railings (invisible)
local DECK_SEGMENTS = 6
for k = 0, DECK_SEGMENTS - 1 do
	local a = deckPos(k / DECK_SEGMENTS * length)
	local b = deckPos((k + 1) / DECK_SEGMENTS * length)
	local cf = CFrame.lookAt((a + b) / 2, b) * CFrame.new(0, -0.2, 0)
	collider(bridge, "BridgeDeck", Vector3.new(3.4, 0.4, (b - a).Magnitude + 0.3), cf)
	if k >= 1 then
		for _, side in ipairs({ -1, 1 }) do
			collider(bridge, "BridgeRail", Vector3.new(0.4, 3, (b - a).Magnitude + 0.3), cf * CFrame.new(side * 1.9, 1.7, 0))
		end
	end
end

-- the skull at the island end: half sunk, facing the bridge, the spine running into its teeth
local skullCF = CFrame.lookAt(Eb - dir * -1.7 + up * 0, Eb - dir * -1.7 - dir) -- (front, -Z, towards the bridge)
local skull = newModel("Skull", bridge)
local function K(x, y, z)
	return skullCF * CFrame.new(x, y, z)
end
part(skull, "Cranium", Vector3.new(4.2, 2.6, 3.6), K(0, -0.5, 0.2), BONE)
part(skull, "Dome", Vector3.new(3.3, 0.55, 2.9), K(0, 1.05, 0.4), BONE)
part(skull, "Brow", Vector3.new(4.4, 0.45, 0.6), K(0, 0.75, -1.55), BONE_MID)
part(skull, "Maxilla", Vector3.new(3.0, 0.7, 1.2), K(0, -1.05, -1.75), BONE_MID)
for _, sx in ipairs({ -1, 1 }) do
	-- round, deep sockets with a soul spark far inside (flat dark blocks read as sunglasses)
	part(skull, "SocketRim", Vector3.new(1.35, 1.2, 0.7), K(sx * 0.95, 0.12, -1.5), BONE_MID, Enum.Material.Slate, Enum.PartType.Ball)
	part(skull, "Socket", Vector3.new(1.1, 1.0, 0.9), K(sx * 0.95, 0.1, -1.55), SOCKET, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	part(skull, "Glow", Vector3.new(0.28, 0.28, 0.28), K(sx * 0.95, 0.05, -1.75), SOUL, Enum.Material.Neon, Enum.PartType.Ball)
	part(skull, "Cheek", Vector3.new(0.8, 0.7, 1.6), K(sx * 2.05, -0.35, -0.9) * CFrame.Angles(0, sx * 0.2, 0), BONE_MID)
	part(skull, "Horn", Vector3.new(0.5, 0.5, 1.4), K(sx * 1.9, 0.6, 1.4) * CFrame.Angles(math.rad(-30), sx * 0.4, 0), BONE_DARK)
end
part(skull, "Nasal", Vector3.new(0.3, 0.7, 0.4), K(-0.14, -0.5, -1.8) * CFrame.Angles(0, 0, -0.35), SOCKET)
part(skull, "Nasal", Vector3.new(0.3, 0.7, 0.4), K(0.14, -0.5, -1.8) * CFrame.Angles(0, 0, 0.35), SOCKET)
for t = -3, 3 do
	part(skull, "Tooth", Vector3.new(0.3, 0.65, 0.3), K(t * 0.4, -1.55, -2.2), (t % 2 == 0) and BONE or BONE_MID)
end
-- a ramp over the skull onto the island
do
	local a = deckPos(length) + dir * -0.2
	local top1 = Eb + dir * 0.9 + up * 1.35
	local top2 = Eb + dir * 2.6 + up * 1.35
	local down = Eb + dir * 4.1 + up * 0.5
	for _, seg in ipairs({ { a, top1 }, { top1, top2 }, { top2, down } }) do
		local cf = CFrame.lookAt((seg[1] + seg[2]) / 2, seg[2]) * CFrame.new(0, -0.2, 0)
		collider(skull, "SkullRamp", Vector3.new(3.4, 0.4, (seg[2] - seg[1]).Magnitude + 0.3), cf)
	end
end

core.WorldPivot = CFrame.new()

-- ============================================================
-- CemeteryAltarIsland (Realm 1's ground)
-- ============================================================
local island = Instance.new("Model")
island.Name = "CemeteryAltarIsland"
local bridgeAngle = math.atan2(bridgeOut.Z, bridgeOut.X)
local function onIsland(angle, r, y)
	return C + Vector3.new(math.cos(angle) * r, y or 0, math.sin(angle) * r)
end

-- the ground (walkable) and its earth top
local ground = disc(island, "Ground", C, ISLAND_R - 0.4, 1.2, 0, EARTH, Enum.Material.Ground)
ground.CanCollide = true
disc(island, "Underside", C, ISLAND_R - 1.5, 6, -1.2, BASALT[3], Enum.Material.Slate)
-- a ring of fieldstone columns forms the cliff (none where the skull lies)
local columns = math.floor(2 * math.pi * ISLAND_R / 1.9)
for k = 0, columns - 1 do
	local a = k / columns * 2 * math.pi + rng:NextNumber(-0.05, 0.05)
	local diff = math.abs(((a - bridgeAngle + math.pi) % (2 * math.pi)) - math.pi)
	local w = rng:NextNumber(1.8, 2.5)
	local h = rng:NextNumber(6, 8.5)
	local top = (diff < 0.32) and -1.4 or rng:NextNumber(-0.35, 0.45)
	local pos = onIsland(a, ISLAND_R - 0.6 + rng:NextNumber(-0.2, 0.3), top - h / 2)
	part(island, "Column", Vector3.new(w, h, rng:NextNumber(2.0, 2.7)), CFrame.lookAt(pos, C * Vector3.new(1, 0, 1) + up * pos.Y)
		* CFrame.Angles(rng:NextNumber(-0.06, 0.06), 0, rng:NextNumber(-0.06, 0.06)), BASALT[rng:NextInteger(1, 3)], Enum.Material.Slate)
	if rng:NextNumber() < 0.4 then
		-- a lower column outside the ring: a ragged foot
		local p2 = onIsland(a + 0.08, ISLAND_R + 0.7, -1.6 - h / 2)
		part(island, "Column", Vector3.new(w * 0.9, h, 1.8), CFrame.lookAt(p2, C * Vector3.new(1, 0, 1) + up * p2.Y), BASALT[rng:NextInteger(1, 3)], Enum.Material.Slate)
	end
end
-- moss and grass patches
for _ = 1, 9 do
	local a = rng:NextNumber(0, 2 * math.pi)
	local r = rng:NextNumber(4.2, ISLAND_R - 1.5)
	local p = onIsland(a, r, 0.03)
	part(island, (rng:NextNumber() < 0.5) and "Moss" or "Grass", Vector3.new(rng:NextNumber(1.5, 3.2), 0.12, rng:NextNumber(1.2, 2.6)),
		CFrame.new(p) * CFrame.Angles(0, rng:NextNumber(0, 6), 0), (rng:NextNumber() < 0.5) and MOSS or GRASS, Enum.Material.Grass)
end
-- flagstones from the skull to the dais
for k = 1, 4 do
	local p = C + bridgeOut * (5.6 - k * 0.2) + Vector3.new(0, 0.04, 0) + bridgeOut:Cross(up) * ((k % 2 == 0) and 1.6 or -1.7)
	part(island, "Flagstone", Vector3.new(rng:NextNumber(1.2, 1.8), 0.14, rng:NextNumber(1.0, 1.5)), CFrame.new(p) * CFrame.Angles(0, rng:NextNumber(0, 6), 0),
		STONE[rng:NextInteger(1, 3)], Enum.Material.Slate)
end
-- leaning tombstones near the back and the sides
for _, spec in ipairs({ { 2.3, 7.4, 0.25 }, { 3.2, 7.6, -0.2 }, { -1.9, 7.3, 0.15 } }) do
	local a = bridgeAngle + spec[1]
	local p = onIsland(a, spec[2], 0)
	local face = CFrame.lookAt(p, C * Vector3.new(1, 0, 1)) * CFrame.Angles(math.rad(-6), 0, spec[3])
	part(island, "Tombstone", Vector3.new(1.5, 2.1, 0.4), face * CFrame.new(0, 1.0, 0), STONE[rng:NextInteger(1, 3)], Enum.Material.Slate)
	part(island, "Tombstone", Vector3.new(0.4, 1.5, 1.5), face * CFrame.new(0, 2.05, 0) * CFrame.Angles(0, math.pi / 2, math.pi / 2), STONE[2], Enum.Material.Slate, Enum.PartType.Cylinder)
	part(island, "Mound", Vector3.new(1.8, 0.4, 2.4), face * CFrame.new(0, 0.1, 1.2), EARTH, Enum.Material.Ground)
end
-- a broken iron fence piece on the right
do
	local a = bridgeAngle - 1.5
	local p = onIsland(a, ISLAND_R - 1.6, 0)
	local f = CFrame.lookAt(p, C * Vector3.new(1, 0, 1)) * CFrame.Angles(0, math.pi / 2, 0)
	for i = -2, 2 do
		local h = (i == 2) and 1.6 or 2.6
		part(island, "FenceBar", Vector3.new(0.14, h, 0.14), f * CFrame.new(i * 0.55, h / 2, 0) * CFrame.Angles(0, 0, (i == 2) and 0.3 or 0), IRON)
		part(island, "FenceSpike", Vector3.new(0.12, 0.35, 0.12), f * CFrame.new(i * 0.55, h + 0.12, 0) * CFrame.Angles(0, math.pi / 4, 0), IRON_DARK)
	end
	part(island, "FenceRail", Vector3.new(2.6, 0.14, 0.12), f * CFrame.new(-0.3, 2.0, 0), IRON)
	part(island, "FenceRail", Vector3.new(2.9, 0.14, 0.12), f * CFrame.new(0, 0.6, 0), IRON)
	part(island, "FencePost", Vector3.new(0.35, 3.0, 0.35), f * CFrame.new(-1.4, 1.5, 0), IRON_DARK)
end
-- rocks and scattered bones
for _ = 1, 5 do
	local a = rng:NextNumber(0, 2 * math.pi)
	local diff = math.abs(((a - bridgeAngle + math.pi) % (2 * math.pi)) - math.pi)
	if diff > 0.5 then
		local s = rng:NextNumber(0.8, 1.6)
		part(island, "Rock", Vector3.new(s * 1.3, s * 0.8, s), CFrame.new(onIsland(a, rng:NextNumber(6.5, ISLAND_R - 1), 0.2))
			* CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, 6), rng:NextNumber(-0.3, 0.3)), BASALT[rng:NextInteger(1, 3)], Enum.Material.Slate)
	end
end
for _ = 1, 4 do
	local a = rng:NextNumber(0, 2 * math.pi)
	local p = onIsland(a, rng:NextNumber(5.5, ISLAND_R - 1.5), 0.12)
	local cf = CFrame.new(p) * CFrame.Angles(0, rng:NextNumber(0, 6), 0)
	part(island, "Bone", Vector3.new(0.2, 0.2, 1.2), cf, BONE_MID)
	part(island, "Bone", Vector3.new(0.35, 0.3, 0.3), cf * CFrame.new(0, 0, 0.6), BONE)
	part(island, "Bone", Vector3.new(0.35, 0.3, 0.3), cf * CFrame.new(0, 0, -0.6), BONE)
end
island.WorldPivot = CFrame.new()

core.Parent = folder
island.Parent = folder

-- ============================================================
-- Preview on Plot1 (delete Workspace.AltarPreview before publishing)
-- ============================================================
local oldPreview = workspace:FindFirstChild("AltarPreview")
if oldPreview then
	oldPreview:Destroy()
end
local base = workspace:FindFirstChild("Plots") and workspace.Plots:FindFirstChild("Plot1") and workspace.Plots.Plot1:FindFirstChild("Base")
if base then
	local frame = base.CFrame * CFrame.new(0, base.Size.Y / 2, 0)
	local preview = Instance.new("Folder")
	preview.Name = "AltarPreview"
	for _, m in ipairs({ core, island }) do
		local c = m:Clone()
		c:PivotTo(frame)
		c.Parent = preview
	end
	preview.Parent = workspace
end

local n = 0
for _, m in ipairs({ core, island }) do
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			n += 1
		end
	end
end
return "Soul Altar built: " .. n .. " parts"
