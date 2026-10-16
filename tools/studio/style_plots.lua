-- Styles the 8 EMPTY (neutral) plots in the plaza's look (the Ossuary Court: flagstone, bone stone, soul violet), so an
-- unclaimed plot reads as a sealed yard of the plaza, waiting; clearly not the Realm 1 cemetery a claimed plot gets
-- (server PlotLook). Safe to re-run. Run in Edit mode (Studio MCP execute_luau or loadstring from the tools/studio
-- http server), after tools/studio/build_coliseum.lua has placed the plots. Save the place afterwards.
--
-- Everything is built relative to each plot's frame (floor-level centre of the Base, local -Z = lane direction,
-- outward) into the plot's "Style" folder, so the server's named lookups (Base, WallOrigin, PlayerSpawn, GraveSpotN)
-- are unaffected:
--   Style.Spawn*      the spawn point's summoning circle (stays on claimed plots too; its glyph band and hexagram
--                     are SpinFx models that the client WorldFx turns slowly, in opposite directions)
--   Style.Neutral     everything else: hidden (parts, lights, emitters, signs) while a player owns the plot (PlotLook)
--     * a bone-stone border and two bone bands down the middle of the flagstone floor
--     * low balustrades along both sides (the plaza rim's: dark plinth, diamond balusters, bone rail, an invisible wall)
--       with piers and soul lanterns
--     * the entrance from the plaza: two tall piers with skulls and lanterns, a pointed bone arch with the plot number
--     * ten sealed ledger stones where the graves will stand (GraveSpot positions), a faint violet rune on each
--     * two obelisks where the lane begins, candles by the ledgers, a low violet ground mist
local FLOOR = Color3.fromRGB(62, 58, 66)
local PLINTH = Color3.fromRGB(50, 46, 54)
local STONE = Color3.fromRGB(64, 60, 68)
local STONE_DARK = Color3.fromRGB(40, 37, 44)
local BONE = Color3.fromRGB(120, 110, 96)
local IRON = Color3.fromRGB(32, 30, 34)
local FLAME = Color3.fromRGB(170, 255, 200) -- (the plaza rim's soul lanterns)
local SOUL_VIOLET = Color3.fromRGB(150, 110, 240)
local RUNE = Color3.fromRGB(66, 46, 114) -- (a dark Neon: a faint glow, like the plaza sigil)
local SKULL_DARK = Color3.fromRGB(10, 6, 20)
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"

local UP = CFrame.Angles(0, 0, math.rad(90)) -- turns a cylinder's axis (X) to point up
local GRAVE_FWD = { 14, 6, -2, -10, -18 }
local GRAVE_LAT = 13

local total = 0
for i = 1, 8 do
	local model = workspace.Plots["Plot" .. i]
	local old = model:FindFirstChild("Style")
	if old then
		old:Destroy()
	end
	local style = Instance.new("Folder")
	style.Name = "Style"
	style.Parent = model
	local neutral = Instance.new("Folder")
	neutral.Name = "Neutral"
	neutral.Parent = style

	local base = model.Base
	base.Material = Enum.Material.Slate
	base.Color = FLOOR
	local frame = base.CFrame * CFrame.new(0, base.Size.Y / 2, 0)
	local halfW, halfL = base.Size.X / 2, base.Size.Z / 2

	-- CFrame at (forward along the lane, lateral across, height above the floor), facing down the lane
	local function at(forward, lateral, y)
		return frame * CFrame.new(lateral, y, -forward)
	end
	local function part(name, size, cframe, color, material, shape, parent)
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Size = size
		p.CFrame = cframe
		p.Color = color
		p.Material = material or Enum.Material.Slate
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		if shape then
			p.Shape = shape
		end
		p.Parent = parent or neutral
		total += 1
		return p
	end
	local function flatDisc(name, radius, thickness, forward, y, color, material, parent)
		return part(name, Vector3.new(thickness, radius * 2, radius * 2), at(forward, 0, y) * UP, color, material, Enum.PartType.Cylinder, parent)
	end

	-- ── the spawn point: a summoning circle (kept on claimed plots) ──
	-- a dark stone disc; two outer rings with a band of rune glyphs between them (turning slowly), a hexagram with a
	-- glowing dot at each point (turning the other way), an inner ring and a glowing core with souls rising off it
	local centre = at(8, 0, 0)
	flatDisc("SpawnDisc", 5.9, 0.1, 8, 0.05, STONE_DARK, Enum.Material.Slate, style)
	-- a ring of short bars on `parent` (radius r, n segments, bar width w, height y)
	local function ring(parent, name, r, n, w, y, color)
		local len = 2 * math.pi * r / n + 0.04
		for k = 0, n - 1 do
			local a = (k + 0.5) / n * math.pi * 2
			part(name, Vector3.new(w, 0.04, len), centre * CFrame.Angles(0, a, 0) * CFrame.new(r, y, 0), color, Enum.Material.Neon, nil, parent)
		end
	end
	-- a spinning group: a model round an invisible centre part, tagged SpinFx (client WorldFx turns it)
	local function spinner(name, speed)
		local m = Instance.new("Model")
		m.Name = name
		local hub = part(name .. "Hub", Vector3.new(0.2, 0.2, 0.2), centre * CFrame.new(0, 0.1, 0), STONE_DARK, Enum.Material.SmoothPlastic, nil, m)
		hub.Transparency = 1
		m.PrimaryPart = hub
		m:SetAttribute("SpinSpeed", speed)
		m.Parent = style
		game:GetService("CollectionService"):AddTag(m, "SpinFx")
		return m
	end
	ring(style, "SpawnRing", 5.6, 28, 0.22, 0.12, SOUL_VIOLET)
	ring(style, "SpawnRing", 4.75, 24, 0.12, 0.12, SOUL_VIOLET)
	-- the rune band: a glyph of two or three strokes every 22.5 degrees
	local glyphs = spinner("SpawnGlyphs", 0.12)
	local GLYPH = Color3.fromRGB(120, 90, 210)
	local SHAPES = { { { 0, 0.5, 0 }, { 0, -0.1, 50 } }, { { -0.12, 0.45, 0 }, { 0.12, 0.45, 0 }, { 0, 0.3, 90 } },
		{ { 0, 0.5, 30 }, { 0, 0.5, -30 } }, { { 0, 0.55, 0 }, { 0, 0.25, 90 }, { 0.1, 0.2, 45 } } }
	for k = 0, 15 do
		local a = k / 16 * math.pi * 2
		local cf = centre * CFrame.Angles(0, a, 0) * CFrame.new(5.18, 0.13, 0)
		for _, s in ipairs(SHAPES[k % #SHAPES + 1]) do
			part("SpawnGlyph", Vector3.new(0.09, 0.04, s[2]), cf * CFrame.new(0, 0, s[1]) * CFrame.Angles(0, math.rad(s[3]), 0), GLYPH, Enum.Material.Neon, nil, glyphs)
		end
	end
	-- the hexagram: two triangles, a dot at each point
	local star = spinner("SpawnStar", -0.07)
	local R = 4.55
	for t = 0, 1 do
		for k = 0, 2 do
			local a0 = (k / 3 + t / 6) * math.pi * 2
			local a1 = ((k + 1) / 3 + t / 6) * math.pi * 2
			local p0 = (centre * CFrame.new(math.cos(a0) * R, 0.14, math.sin(a0) * R)).Position
			local p1 = (centre * CFrame.new(math.cos(a1) * R, 0.14, math.sin(a1) * R)).Position
			part("SpawnStarLine", Vector3.new(0.14, 0.04, (p1 - p0).Magnitude), CFrame.lookAt((p0 + p1) / 2, p1), SOUL_VIOLET, Enum.Material.Neon, nil, star)
		end
	end
	for k = 0, 5 do
		local a = k / 6 * math.pi * 2
		local p = centre * CFrame.new(math.cos(a) * R, 0.15, math.sin(a) * R)
		part("SpawnStarDot", Vector3.new(0.05, 0.75, 0.75), p * UP, Color3.fromRGB(200, 170, 255), Enum.Material.Neon, Enum.PartType.Cylinder, star)
	end
	ring(star, "SpawnInnerRing", 2.1, 16, 0.12, 0.14, SOUL_VIOLET)
	-- the core: a small glowing disc, a soft light, souls rising slowly
	local core = part("SpawnCore", Vector3.new(0.06, 1.3, 1.3), centre * CFrame.new(0, 0.15, 0) * UP, Color3.fromRGB(200, 170, 255), Enum.Material.Neon, Enum.PartType.Cylinder, style)
	local light = Instance.new("PointLight")
	light.Color = SOUL_VIOLET
	light.Range = 14
	light.Brightness = 0.8
	light.Shadows = false
	light.Parent = core
	local souls = Instance.new("ParticleEmitter")
	souls.Name = "SpawnSouls"
	souls.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	souls.Color = ColorSequence.new(Color3.fromRGB(200, 170, 255), SOUL_VIOLET)
	souls.LightEmission = 1
	souls.LightInfluence = 0
	souls.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 0) })
	souls.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
	souls.Lifetime = NumberRange.new(2, 3.5)
	souls.Rate = 4
	souls.Speed = NumberRange.new(0.6, 1.4)
	souls.SpreadAngle = Vector2.new(25, 25)
	souls.Shape = Enum.ParticleEmitterShape.Disc
	souls.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	souls.EmissionDirection = Enum.NormalId.Right -- (the cylinder's axis points up)
	souls.Parent = core

	-- ── the floor: a bone border, two bands down the middle ──
	for _, s in ipairs({ -1, 1 }) do
		part("FloorTrim", Vector3.new(0.5, 0.06, base.Size.Z - 1), at(0, s * (halfW - 0.6), 0.03), BONE, Enum.Material.Limestone)
		part("FloorTrim", Vector3.new(base.Size.X - 1, 0.06, 0.5), at(s * (halfL - 0.6), 0, 0.03), BONE, Enum.Material.Limestone)
		part("FloorBand", Vector3.new(0.35, 0.05, base.Size.Z - 2), at(0, s * 3.2, 0.025), BONE, Enum.Material.Limestone)
	end

	-- a skull: cranium, jaw, deep eye sockets, nose, teeth (`cf`: its -Z looks out at the viewer)
	local function skull(cf)
		part("Skull", Vector3.new(0.95, 0.95, 0.95), cf * CFrame.new(0, 0.1, 0), BONE, Enum.Material.Limestone, Enum.PartType.Ball)
		part("SkullJaw", Vector3.new(0.55, 0.34, 0.5), cf * CFrame.new(0, -0.3, -0.12), BONE, Enum.Material.Limestone)
		for _, s in ipairs({ -1, 1 }) do
			part("SkullEye", Vector3.new(0.3, 0.3, 0.3), cf * CFrame.new(s * 0.2, 0.08, -0.33), SKULL_DARK, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		end
		part("SkullNose", Vector3.new(0.12, 0.14, 0.1), cf * CFrame.new(0, -0.1, -0.42), SKULL_DARK, Enum.Material.SmoothPlastic)
		part("SkullTeeth", Vector3.new(0.4, 0.05, 0.05), cf * CFrame.new(0, -0.33, -0.39), SKULL_DARK, Enum.Material.SmoothPlastic)
	end
	-- an iron soul lantern standing on `top` (a world position)
	local function lantern(top)
		part("LanternBase", Vector3.new(1, 0.15, 1), CFrame.new(top + Vector3.new(0, 0.075, 0)), IRON, Enum.Material.Metal)
		for _, c in ipairs({ { -1, -1 }, { -1, 1 }, { 1, -1 }, { 1, 1 } }) do
			part("LanternPost", Vector3.new(0.1, 1.1, 0.1), CFrame.new(top + Vector3.new(c[1] * 0.42, 0.7, c[2] * 0.42)), IRON, Enum.Material.Metal)
		end
		part("LanternRoof", Vector3.new(1.1, 0.12, 1.1), CFrame.new(top + Vector3.new(0, 1.3, 0)), IRON, Enum.Material.Metal)
		part("LanternRoofTop", Vector3.new(0.6, 0.4, 0.6), CFrame.new(top + Vector3.new(0, 1.55, 0)) * CFrame.Angles(0, math.rad(45), 0), IRON, Enum.Material.Metal)
		local flame = part("LanternFlame", Vector3.new(0.45, 0.6, 0.45), CFrame.new(top + Vector3.new(0, 0.6, 0)), FLAME, Enum.Material.Neon)
		local l = Instance.new("PointLight")
		l.Color = FLAME
		l.Range = 12
		l.Brightness = 0.9
		l.Shadows = false
		l.Parent = flame
	end
	-- a pier at (forward, lateral); `face` = the direction its skull looks (a CFrame rotation), `tall` for the entrance
	local function pier(forward, lateral, tall, face)
		local h = tall and 5.4 or 3.6
		local w = tall and 2 or 1.6
		local cf = at(forward, lateral, 0) * (face or CFrame.identity)
		local p = part("Pier", Vector3.new(w, h, w), cf * CFrame.new(0, h / 2, 0), PLINTH)
		p.CanCollide = true
		part("PierBand", Vector3.new(w + 0.2, 0.3, w + 0.2), cf * CFrame.new(0, 0.75, 0), STONE)
		part("PierCap", Vector3.new(w + 0.35, 0.4, w + 0.35), cf * CFrame.new(0, h + 0.2, 0), BONE, Enum.Material.Limestone)
		if tall then
			skull(cf * CFrame.new(0, h * 0.62, -w / 2 - 0.05))
		end
		lantern((cf * CFrame.new(0, h + 0.4, 0)).Position)
	end

	-- ── the side balustrades (the plaza rim's) ───────────────
	local PLINTH_H, BALUSTER_H, RAIL_H = 0.6, 2, 0.35
	local railFrom, railTo = -halfL + 2.2, halfL
	local railLen = railTo - railFrom
	local railMid = (railFrom + railTo) / 2
	for _, s in ipairs({ -1, 1 }) do
		local lat = s * (halfW + 0.2)
		local plinth = part("RailPlinth", Vector3.new(1.4, PLINTH_H, railLen), at(railMid, lat, PLINTH_H / 2), PLINTH)
		plinth.CanCollide = true
		local rail = part("RailTop", Vector3.new(1.15, RAIL_H, railLen), at(railMid, lat, PLINTH_H + BALUSTER_H + RAIL_H / 2), BONE, Enum.Material.Limestone)
		rail.CanCollide = true
		local block = part("RailBlock", Vector3.new(0.5, BALUSTER_H, railLen), at(railMid, lat, PLINTH_H + BALUSTER_H / 2), STONE)
		block.Transparency = 1
		block.CanCollide = true
		local n = math.floor(railLen / 1.25)
		for k = 1, n do
			local f = railFrom + (k - 0.5) / n * railLen
			part("Baluster", Vector3.new(0.42, BALUSTER_H, 0.42), at(f, lat, PLINTH_H + BALUSTER_H / 2) * CFrame.Angles(0, math.rad(45), 0), STONE)
		end
		-- low piers along the rail, the last one where the lane begins
		for _, f in ipairs({ -6, 10, halfL - 0.8 }) do
			pier(f, lat, false)
		end
	end

	-- ── the entrance from the plaza ──────────────────────────
	local ENTRY = -halfL + 0.8
	local toPlaza = CFrame.Angles(0, math.pi, 0) -- (the skulls look out at the plaza)
	for _, s in ipairs({ -1, 1 }) do
		pier(ENTRY, s * 9.6, true, toPlaza)
	end
	-- a pointed arch of two bone beams meeting over the middle, the plot number hanging from it
	local apex = at(ENTRY, 0, 9.6).Position
	for _, s in ipairs({ -1, 1 }) do
		local foot = at(ENTRY, s * 9.6, 6).Position
		local len = (apex - foot).Magnitude
		part("ArchBeam", Vector3.new(0.7, 0.7, len + 0.4), CFrame.lookAt((apex + foot) / 2, apex), BONE, Enum.Material.Limestone)
	end
	part("ArchKey", Vector3.new(1.1, 1.1, 1.1), at(ENTRY, 0, 9.7) * CFrame.Angles(0, 0, math.rad(45)), BONE, Enum.Material.Limestone)
	local sign = part("ArchSign", Vector3.new(5.4, 1.3, 0.25), at(ENTRY, 0, 7.4), STONE_DARK)
	for _, s in ipairs({ -1, 1 }) do
		part("ArchChain", Vector3.new(0.08, 1.2, 0.08), at(ENTRY, s * 2.2, 8.6), IRON, Enum.Material.Metal)
	end
	for _, face in ipairs({ Enum.NormalId.Back, Enum.NormalId.Front }) do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 60
		gui.LightInfluence = 0
		gui.Parent = sign
		local text = Instance.new("TextLabel")
		text.Size = UDim2.fromScale(1, 1)
		text.BackgroundTransparency = 1
		text.Text = "PLOT " .. i
		text.TextColor3 = SOUL_VIOLET
		text.TextScaled = true
		text.Font = Enum.Font.Fantasy
		text.Parent = gui
	end

	-- ── the sealed ledger stones where the graves will stand ─
	for _, f in ipairs(GRAVE_FWD) do
		for _, s in ipairs({ -1, 1 }) do
			local lat = s * GRAVE_LAT
			part("LedgerBorder", Vector3.new(4.8, 0.14, 6), at(f, lat, 0.07), BONE, Enum.Material.Limestone)
			part("Ledger", Vector3.new(4.2, 0.2, 5.4), at(f, lat, 0.1), STONE_DARK, Enum.Material.Slate)
			-- a faint rune: a ring with a cross through it
			part("LedgerRune", Vector3.new(0.04, 2.6, 2.6), at(f, lat, 0.21) * UP, RUNE, Enum.Material.Neon, Enum.PartType.Cylinder)
			part("LedgerRuneCut", Vector3.new(0.05, 2.3, 2.3), at(f, lat, 0.215) * UP, STONE_DARK, Enum.Material.Slate, Enum.PartType.Cylinder)
			part("LedgerRuneBar", Vector3.new(0.18, 0.04, 3.4), at(f, lat, 0.22), RUNE, Enum.Material.Neon)
			part("LedgerRuneBar", Vector3.new(2.2, 0.04, 0.18), at(f + 0.5, lat, 0.22), RUNE, Enum.Material.Neon)
		end
	end
	-- candles by some of the ledgers (towards the middle path)
	for k, f in ipairs(GRAVE_FWD) do
		for _, s in ipairs({ -1, 1 }) do
			if (k + (s > 0 and 1 or 0)) % 2 == 0 then
				local c = at(f + 2.2, s * (GRAVE_LAT - 3.1), 0)
				for j, h in ipairs({ 0.9, 0.6, 0.75 }) do
					local off = CFrame.new((j - 2) * 0.35, 0, (j % 2) * 0.3)
					part("Candle", Vector3.new(0.22, h, 0.22), c * off * CFrame.new(0, h / 2, 0), BONE, Enum.Material.SmoothPlastic)
					part("CandleFlame", Vector3.new(0.12, 0.2, 0.12), c * off * CFrame.new(0, h + 0.1, 0), FLAME, Enum.Material.Neon)
				end
			end
		end
	end

	-- ── two obelisks where the lane begins ──────────────────
	for _, s in ipairs({ -1, 1 }) do
		local cf = at(halfL - 3, s * 15.5, 0)
		part("ObeliskBase", Vector3.new(2.2, 0.8, 2.2), cf * CFrame.new(0, 0.4, 0), PLINTH)
		part("Obelisk", Vector3.new(1.3, 6.5, 1.3), cf * CFrame.new(0, 4.05, 0), STONE)
		part("ObeliskBand", Vector3.new(1.45, 0.25, 1.45), cf * CFrame.new(0, 2.2, 0), BONE, Enum.Material.Limestone)
		part("ObeliskTip", Vector3.new(0.92, 0.92, 0.92), cf * CFrame.new(0, 7.6, 0) * CFrame.Angles(math.rad(45), 0, math.rad(45)), BONE, Enum.Material.Limestone)
		local glyph = part("ObeliskGlyph", Vector3.new(0.3, 1.6, 0.06), cf * CFrame.new(0, 4.6, 0.66), SOUL_VIOLET, Enum.Material.Neon)
		local l = Instance.new("PointLight")
		l.Color = SOUL_VIOLET
		l.Range = 8
		l.Brightness = 0.6
		l.Shadows = false
		l.Parent = glyph
	end

	-- ── a low violet ground mist over the yard ───────────────
	local mist = part("Mist", Vector3.new(base.Size.X - 4, 0.2, base.Size.Z - 4), at(0, 0, 0.3), Color3.new(), Enum.Material.SmoothPlastic)
	mist.Transparency = 1
	local e = Instance.new("ParticleEmitter")
	e.Name = "GroundMist"
	e.Texture = SMOKE
	e.Color = ColorSequence.new(Color3.fromRGB(70, 56, 110), Color3.fromRGB(40, 34, 60))
	e.LightInfluence = 0
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 3), NumberSequenceKeypoint.new(1, 6) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.4, 0.88), NumberSequenceKeypoint.new(1, 1) })
	e.Lifetime = NumberRange.new(5, 8)
	e.Rate = 3
	e.Speed = NumberRange.new(0.2, 0.5)
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-8, 8)
	e.EmissionDirection = Enum.NormalId.Top
	e.Parent = mist
end

return "neutral plots styled: " .. total .. " parts"
