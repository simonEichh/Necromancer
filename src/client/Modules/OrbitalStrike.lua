-- Malak's basic attack, the orbital tag (units whose model has AttackStyle = "OrbitalTag"). The server counts the
-- attack (model attribute AttackCount), sets AimPos (the spot on the wall) and deals the damage hitDelay seconds later
-- (Units.Malak.hitDelay = IMPACT_AT). While he fights, his small hologram pad opens into a BIG hologram in front of him
-- (this module; UnitAnimator's Envoy block hides the pad and frees his hand). On every attack:
--   BOARD_AT   a red targeting ring opens over the big hologram's rune ring, spinning faster and narrowing
--   LASER_AT   the red targeting laser cuts diagonally out of the sky (from the ship's spot, a red glint) onto the wall;
--              where it lands a reticle of rings and brackets opens and closes in on the spot
--   LOCK_AT    the reticle locks (flashes and turns solid) and the hologram flashes red with it
--   TAP_AT     he has lazily raised his arm and presses the hologram once (UnitAnimator): a ripple where he touched it,
--              and the gunship fires right after
--   FIRE_AT    a big muzzle blast far up in the sky (rings rolling out): a white-hot shell comes down the laser's line,
--              tracer behind it, shockwave rings off its path, a sonic boom halfway (IMPACT_AT - ANTICIPATE: the
--              reticle collapses to a point and the laser goes thin and white)
--   IMPACT_AT  the shell hits: a white flash, a fireball, a shockwave ring on the wall, big debris, a dust ring rolling
--              out along the ground, embers, sparks, smoke, a scorch mark that cools, the laser goes out, and a short
--              camera shake for the plot's owner (model attribute OwnerId) when close
-- Purely visual; everything is anchored parts moved locally, nothing is sent over the network.
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local Sfx = require(script.Parent.Sfx)

local TAG = "ProceduralUnit"
local BOARD_AT = 0.5
local LASER_AT = 1.85
local RETICLE_AT = LASER_AT + 0.18 -- (the laser has reached the wall)
local LOCK_AT = 2.8
local TAP_AT = 3.05 -- (= the press in UnitAnimator's Envoy block)
local FIRE_AT = 3.1
local IMPACT_AT = 3.9 -- (= Units.Malak.hitDelay; the shell takes 0.8 s to come down)
local IMPACT_SOUND_LEAD = 0.2 -- the impact sound is started this much before the hit
local ANTICIPATE = 0.22 -- right before the impact the reticle collapses to a point and the laser goes thin and white
local MAX_DISTANCE = 260
-- Where the ship hangs that fires the laser and the shell (relative to the spot on the wall): high up, far off to the
-- side of the lane and a little out in front of the wall face, so the laser cuts DIAGONALLY across the sky onto the
-- front of the wall (seen from the army it comes from the sky ahead and to the side, never from behind the unit, and
-- it clears the top of the wall)
local SKY_HEIGHT = 380 -- (the Absolution, out of sight: as high and far as it hangs in the Fleet Strike)
local SKY_SIDE = 420
local SKY_FORWARD = 18

local RED = Color3.fromRGB(255, 40, 40)
local RED_CORE = Color3.fromRGB(255, 190, 180)
local WHITE = Color3.fromRGB(255, 250, 240)
local HOT = Color3.fromRGB(255, 196, 120)
local FIRE = Color3.fromRGB(255, 110, 40)
local COLD = Color3.fromRGB(165, 180, 255) -- (Malak's own light: the big hologram, the shockwave)
local GLOW_CORE_BOARD = Color3.fromRGB(235, 240, 255)
local SMOKE_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"
local SPARK_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"

local fx = Instance.new("Folder")
fx.Name = "OrbitalStrikeFx"
fx.Parent = workspace

local active = {} -- running effects: functions (now) -> keepGoing

local function newPart(size, color, transparency, shape, material)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = false, false, false, false
	p.Material = material or Enum.Material.Neon
	p.Color = color
	p.Size = size
	p.Transparency = transparency or 0
	if shape then
		p.Shape = shape
	end
	p.CFrame = CFrame.new(0, -5000, 0) -- (parked out of sight until its effect places it, not at the plaza's centre)
	p.Parent = fx
	return p
end

local function smooth(x)
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

-- the wall's outward normal at the aim spot: towards the unit, flattened
local function wallNormal(aim, unitPos)
	local d = unitPos - aim
	d = Vector3.new(d.X, 0, d.Z)
	return d.Magnitude > 0.01 and d.Unit or Vector3.new(0, 0, 1)
end

-- ====================================================================
-- The targeting laser + the reticle on the wall (LASER_AT .. IMPACT_AT)
-- ====================================================================
local function laser(aim, origin, normal, t0)
	local beam = newPart(Vector3.new(0.07, 0.07, 1), RED_CORE)
	local glow = newPart(Vector3.new(0.3, 0.3, 1), RED, 0.6)
	local glint = newPart(Vector3.one * 7, RED_CORE, 1, Enum.PartType.Ball)
	glint.CFrame = CFrame.new(origin)
	local glintHalo = newPart(Vector3.one * 20, RED, 1, Enum.PartType.Ball)
	glintHalo.CFrame = CFrame.new(origin)
	local dot = newPart(Vector3.one * 0.35, RED_CORE, 0, Enum.PartType.Ball)
	local dotGlow = newPart(Vector3.one * 0.9, RED, 0.55, Enum.PartType.Ball)
	local light = Instance.new("PointLight")
	light.Color = RED
	light.Range = 7
	light.Brightness = 1.5
	light.Shadows = false
	light.Parent = dot

	-- the reticle: two segmented rings turning opposite ways and four brackets, closing in until LOCK_AT
	local face = CFrame.lookAt(aim + normal * 0.45, aim + normal * 2)
	local rings = {}
	for ringIndex, ring in ipairs({ { n = 16, r0 = 3.4, r1 = 1.1, spin = 1.6 }, { n = 10, r0 = 2.2, r1 = 0.65, spin = -2.4 } }) do
		for k = 0, ring.n - 1 do
			table.insert(rings, {
				part = newPart(Vector3.new(0.4, 0.06, 0.04), RED),
				a = k / ring.n * math.pi * 2, ring = ring, gap = (k % 4 == 3) and ringIndex == 1,
			})
		end
	end
	local brackets = {}
	for k = 0, 3 do
		local a = k * math.pi / 2 + math.pi / 4
		table.insert(brackets, { a = a, h = newPart(Vector3.new(0.5, 0.07, 0.04), RED), v = newPart(Vector3.new(0.07, 0.5, 0.04), RED) })
	end

	local hum -- (the laser's hum while it burns on the wall)
	local lockPlayed = false
	local function cleanup()
		if hum then
			hum.stop(0.15)
		end
		beam:Destroy()
		glow:Destroy()
		glint:Destroy()
		glintHalo:Destroy()
		dot:Destroy()
		dotGlow:Destroy()
		for _, r in ipairs(rings) do r.part:Destroy() end
		for _, b in ipairs(brackets) do b.h:Destroy() b.v:Destroy() end
	end

	return function(now)
		local st = now - t0
		if st >= IMPACT_AT + 0.08 then
			cleanup()
			return false
		end
		-- the laser's hum starts as it begins to draw down (a moment early: a sound takes a little while to start)
		if not hum and st >= LASER_AT - 0.1 then
			hum = Sfx.loopAt("laser_hum", aim, 160)
			hum.set(1)
		end
		if st < LASER_AT then
			beam.Transparency, glow.Transparency, dot.Transparency, dotGlow.Transparency = 1, 1, 1, 1
			for _, r in ipairs(rings) do r.part.Transparency = 1 end
			for _, b in ipairs(brackets) do b.h.Transparency, b.v.Transparency = 1, 1 end
			return true
		end
		local lt = st - LASER_AT
		-- the beam draws itself down from the sky in 0.18 s, then flickers a little
		local reach = lt > 0 and smooth(lt / 0.18) or 0
		local tip = origin:Lerp(aim, reach)
		local len = math.max(0.1, (tip - origin).Magnitude)
		local cf = CFrame.lookAt(origin, aim) * CFrame.new(0, 0, -len / 2)
		local flick = 0.85 + math.random() * 0.15
		local locked = st >= LOCK_AT
		local pre = smooth((st - (IMPACT_AT - ANTICIPATE)) / (ANTICIPATE * 0.8)) -- (the beat before the impact)
		local width = (locked and 1.25 or 1) * (1 - 0.45 * pre)
		beam.Size = Vector3.new(0.07 * width * flick, 0.07 * width * flick, len)
		glow.Size = Vector3.new(0.3 * width, 0.3 * width, len)
		beam.Color = RED_CORE:Lerp(WHITE, pre)
		beam.CFrame, glow.CFrame = cf, cf
		beam.Transparency = lt > 0 and 0 or 1
		glow.Transparency = lt > 0 and math.min(1, 0.6 + (1 - flick) * 2 + pre * 0.3) or 1
		glint.Transparency = lt > 0 and 0.1 or 1
		glintHalo.Transparency = lt > 0 and (0.7 + (1 - flick)) or 1
		local onWall = reach >= 1
		if locked and not lockPlayed then
			lockPlayed = true
			Sfx.playAt("target_lock", aim, 1, 1, 160)
		end
		dot.Transparency = onWall and 0 or 1
		dotGlow.Transparency = onWall and (0.55 + (1 - flick)) or 1
		dot.CFrame, dotGlow.CFrame = CFrame.new(aim + normal * 0.3), CFrame.new(aim + normal * 0.3)
		dot.Size = Vector3.one * (0.35 + 0.35 * pre)
		dot.Color = RED_CORE:Lerp(WHITE, pre)
		light.Brightness = onWall and 1.5 * flick or 0

		-- reticle: opens where the laser lands, closes in until LOCK_AT, then a lock flash and steady
		local close = smooth((st - RETICLE_AT) / (LOCK_AT - RETICLE_AT))
		local open = smooth((st - RETICLE_AT) / 0.15)
		local reticleOn = st >= RETICLE_AT
		local lockFlash = locked and math.max(0, 1 - (st - LOCK_AT) / 0.2) or 0
		for _, r in ipairs(rings) do
			local ring = r.ring
			local radius = (ring.r0 + (ring.r1 - ring.r0) * close) * (0.3 + 0.7 * open) * (1 - 0.92 * pre)
			local a = r.a + st * ring.spin * (1 - close * 0.8)
			local seg = 2 * radius * math.sin(math.pi / ring.n) * 0.75
			r.part.Size = Vector3.new(seg, locked and 0.09 or 0.06, 0.04)
			r.part.CFrame = face * CFrame.Angles(0, 0, a) * CFrame.new(radius, 0, 0) * CFrame.Angles(0, 0, math.pi / 2)
			r.part.Color = lockFlash > 0 and RED_CORE or RED
			r.part.Transparency = (r.gap or not reticleOn) and 1 or (locked and 0.05 or 0.35 * (1 - close))
		end
		local br = (2.8 + (1.35 - 2.8) * close) * (1 - 0.85 * pre)
		for _, b in ipairs(brackets) do
			local corner = face * CFrame.Angles(0, 0, b.a) * CFrame.new(br, 0, 0)
			b.h.CFrame = corner * CFrame.Angles(0, 0, -b.a) * CFrame.new(math.cos(b.a) > 0 and -0.22 or 0.22, 0, 0)
			b.v.CFrame = corner * CFrame.Angles(0, 0, -b.a) * CFrame.new(0, math.sin(b.a) > 0 and -0.22 or 0.22, 0)
			local tr = not reticleOn and 1 or (locked and 0 or 0.3)
			b.h.Transparency, b.v.Transparency = tr, tr
			b.h.Color = lockFlash > 0 and RED_CORE or RED
			b.v.Color = b.h.Color
		end
		return true
	end
end

-- ====================================================================
-- The big hologram: while he fights (not walking, attacked within BOARD_HOLD s) the small pad on his palm opens into a
-- big hologram floating in front of him at chest height, facing him, tilted back a little; it grows out of the pad
-- (UnitAnimator hides the pad meanwhile) and shrinks back into it when he walks on. Its rune ring turns, a little bar
-- graph flickers. One per Malak, updated every frame (updateBoards).
-- ====================================================================
local BOARD_HOLD = 7.5 -- (= the fighting window in UnitAnimator's Envoy block: attackCD 6.5 + 1)
local BOARD_OFFSET = Vector3.new(0.35, 1.35, -2.4) -- (from his root, times the model scale)
local BOARD_W, BOARD_H = 2.6, 1.9
local RING_X, RING_Y = -0.45, -0.02 -- (the rune ring's centre on the board)
local PAD_SCALE = 0.33 -- (the small pad's size relative to the big board)

local boards = {} -- [model] = board state

local function newBoard(model)
	local b = { model = model, open = 0, last = -math.huge, elements = {}, rings = {}, bars = {} }
	local function el(x, y, w, h, tr, rot, color)
		local e = { part = newPart(Vector3.new(w, h, 0.02), color or COLD, 1), x = x, y = y, w = w, h = h, tr = tr, rot = rot or 0 }
		table.insert(b.elements, e)
		return e
	end
	b.pane = el(0, 0, BOARD_W, BOARD_H, 0.88)
	b.paneColor = COLD
	for _, s in ipairs({ -1, 1 }) do
		el(0, s * BOARD_H / 2, BOARD_W, 0.035, 0.3)
		el(s * BOARD_W / 2, 0, 0.035, BOARD_H, 0.3)
		for _, t in ipairs({ -1, 1 }) do
			el(s * (BOARD_W / 2 - 0.14), t * (BOARD_H / 2 + 0.07), 0.28, 0.05, 0.05)
			el(s * (BOARD_W / 2 + 0.07), t * (BOARD_H / 2 - 0.14), 0.05, 0.28, 0.05)
		end
		el(s * (BOARD_W / 2 + 0.16), 0.3, 0.04, 0.18, 0.2)
		el(s * (BOARD_W / 2 + 0.16), 0.08, 0.06, 0.06, 0.2, math.rad(45))
	end
	el(-0.2, 0.78, 1.8, 0.03, 0.35)
	el(-1.15, 0.78, 0.09, 0.09, 0.1, math.rad(45))
	-- the rune ring: crosshair, core and four ticks (fixed) plus two segmented rings that turn
	el(RING_X, RING_Y, 1.3, 0.02, 0.45)
	el(RING_X, RING_Y, 0.02, 1.3, 0.45)
	el(RING_X, RING_Y, 0.11, 0.11, 0, math.rad(45), GLOW_CORE_BOARD)
	for k = 0, 3 do
		local a = k * math.pi / 2
		el(RING_X + math.cos(a) * 0.66, RING_Y + math.sin(a) * 0.66, 0.07, 0.07, 0.1, math.rad(45))
	end
	for _, ring in ipairs({ { n = 26, r = 0.52, thick = 0.035, spin = 0.25, tr = 0.1 }, { n = 14, r = 0.3, thick = 0.025, spin = -0.5, tr = 0.25 } }) do
		for k = 0, ring.n - 1 do
			table.insert(b.rings, { part = newPart(Vector3.new(0.1, ring.thick, 0.02), COLD, 1), ring = ring, a = (k + 0.5) / ring.n * math.pi * 2 })
		end
	end
	-- data lines on the right, left-aligned, and a small bar graph below them
	for i, w in ipairs({ 0.9, 0.7, 0.8, 0.5, 0.75 }) do
		el(0.2 + w / 2, 0.5 - (i - 1) * 0.12, w, 0.025, 0.35)
	end
	for i = 0, 6 do
		table.insert(b.bars, { part = newPart(Vector3.new(0.07, 0.2, 0.02), COLD, 1), x = 0.28 + i * 0.13, seed = i * 1.7 })
	end
	return b
end

local function destroyBoard(b)
	for _, e in ipairs(b.elements) do e.part:Destroy() end
	for _, r in ipairs(b.rings) do r.part:Destroy() end
	for _, bar in ipairs(b.bars) do bar.part:Destroy() end
end

local function hideBoard(b)
	for _, e in ipairs(b.elements) do e.part.Transparency = 1 end
	for _, r in ipairs(b.rings) do r.part.Transparency = 1 end
	for _, bar in ipairs(b.bars) do bar.part.Transparency = 1 end
end

local function updateBoard(b, now, dt)
	local model = b.model
	local root = model.PrimaryPart
	if not root then return end
	local fighting = model:GetAttribute("State") ~= "walk" and (now - b.last) < BOARD_HOLD
		and not model:GetAttribute("FleetStart") -- (closed during the Fleet Strike cutscene)
	b.open += ((fighting and 1 or 0) - b.open) * math.clamp(dt * 4, 0, 1)
	if fighting and not b.openSound and b.open > 0.05 then
		b.openSound = true
		Sfx.playAt("holo_open", (root.CFrame * CFrame.new(BOARD_OFFSET * model:GetScale())).Position, 1, 1, 90)
	elseif not fighting and b.open < 0.02 then
		b.openSound = false
	end
	if b.open < 0.01 then
		hideBoard(b)
		b.cf = nil
		return
	end
	local scale = model:GetScale()
	local o = smooth(b.open)
	local centre = (root.CFrame * CFrame.new(BOARD_OFFSET * scale)).Position
	local facing = Vector3.new(root.Position.X, centre.Y, root.Position.Z)
	local full = CFrame.lookAt(centre, facing) * CFrame.Angles(0.15, 0, 0) -- (-Z towards him, the top tilted away)
	local pad = model:FindFirstChild("HoloPanel", true)
	local from = pad and (pad.CFrame * CFrame.Angles(0, math.pi, 0)) or full -- (the pad faces the front; turn it to face him)
	local cf = from:Lerp(full, o)
	local k = scale * (PAD_SCALE + (1 - PAD_SCALE) * o)
	local fade = 1 - o -- (fades in as it grows)
	local t = now
	b.cf, b.k = cf, k
	b.ringCF = cf * CFrame.new(RING_X * k, RING_Y * k, -0.01)
	for _, e in ipairs(b.elements) do
		e.part.Size = Vector3.new(e.w * k, e.h * k, 0.02)
		e.part.CFrame = cf * CFrame.new(e.x * k, e.y * k, 0) * CFrame.Angles(0, 0, e.rot)
		e.part.Transparency = e.tr + (1 - e.tr) * fade
	end
	b.pane.part.Color = b.paneColor
	b.pane.part.Transparency = 0.88 + 0.12 * fade + math.sin(t * 2.5) * 0.02
	for _, r in ipairs(b.rings) do
		local ring = r.ring
		local a = r.a + t * ring.spin
		local radius = ring.r * k
		r.part.Size = Vector3.new(2 * radius * math.sin(math.pi / ring.n) * 0.8, ring.thick * k, 0.02)
		r.part.CFrame = b.ringCF * CFrame.Angles(0, 0, a) * CFrame.new(radius, 0, 0) * CFrame.Angles(0, 0, math.pi / 2)
		r.part.Transparency = ring.tr + (1 - ring.tr) * fade
	end
	for _, bar in ipairs(b.bars) do
		local h = 0.1 + 0.35 * (0.5 + 0.5 * math.sin(t * 1.7 + bar.seed) * math.sin(t * 0.6 + bar.seed * 2))
		bar.part.Size = Vector3.new(0.07 * k, h * k, 0.02)
		bar.part.CFrame = cf * CFrame.new(bar.x * k, (-0.75 + h / 2) * k, 0)
		bar.part.Transparency = 0.25 + 0.75 * fade
	end
end

-- ====================================================================
-- The targeting on the big hologram (BOARD_AT .. LOCK_AT + 0.45): a red ring over its rune ring, spinning faster and
-- narrowing, the pane tinted red, a flash at the lock
-- ====================================================================
local function targeting(b, t0)
	local segs = {}
	for k = 0, 17 do
		table.insert(segs, { part = newPart(Vector3.new(0.09, 0.04, 0.02), RED, 1), a = k / 18 * math.pi * 2 })
	end
	local ticks = {}
	for k = 0, 3 do
		table.insert(ticks, { part = newPart(Vector3.new(0.08, 0.08, 0.02), RED_CORE, 1), a = k * math.pi / 2 + math.pi / 4 })
	end
	local function cleanup()
		for _, sg in ipairs(segs) do sg.part:Destroy() end
		for _, tk in ipairs(ticks) do tk.part:Destroy() end
		b.paneColor = COLD
	end
	return function(now)
		local st = now - t0
		if st >= LOCK_AT + 0.45 or not b.model.Parent then
			cleanup()
			return false
		end
		if st < BOARD_AT or not b.cf then
			for _, sg in ipairs(segs) do sg.part.Transparency = 1 end
			for _, tk in ipairs(ticks) do tk.part.Transparency = 1 end
			return true
		end
		local k = b.k
		local open = smooth((st - BOARD_AT) / 0.25)
		local narrow = smooth((st - BOARD_AT) / (LOCK_AT - BOARD_AT))
		local flash = st >= LOCK_AT and math.max(0, 1 - (st - LOCK_AT) / 0.3) or 0
		local fade = smooth((st - LOCK_AT - 0.15) / 0.3)
		local radius = ((0.7 - 0.36 * narrow) * (0.4 + 0.6 * open) + flash * 0.15) * k
		local spin = (st - BOARD_AT) * (2 + 10 * narrow)
		local centre = b.ringCF * CFrame.new(0, 0, -0.01)
		for _, sg in ipairs(segs) do
			sg.part.Size = Vector3.new(2 * radius * math.sin(math.pi / 18) * 0.8, (0.04 + flash * 0.03) * k, 0.02)
			sg.part.CFrame = centre * CFrame.Angles(0, 0, sg.a + spin) * CFrame.new(radius, 0, 0) * CFrame.Angles(0, 0, math.pi / 2)
			sg.part.Color = flash > 0 and RED_CORE or RED
			sg.part.Transparency = 0.1 + 0.9 * fade
		end
		for _, tk in ipairs(ticks) do
			tk.part.Size = Vector3.new(0.08 * k, 0.08 * k, 0.02)
			tk.part.CFrame = centre * CFrame.Angles(0, 0, tk.a - spin * 0.5) * CFrame.new(radius + 0.12 * k, 0, 0) * CFrame.Angles(0, 0, math.rad(45))
			tk.part.Transparency = 0.1 + 0.9 * fade
		end
		local tint = math.min(1, open * (0.35 + 0.65 * flash)) * (1 - fade)
		b.paneColor = COLD:Lerp(RED, tint * 0.6)
		return true
	end
end

-- ====================================================================
-- The tap (TAP_AT): where his fingertip meets the big hologram a small ripple of light spreads over it
-- ====================================================================
local function tapRipple(b, t0)
	local rings = {}
	for i = 1, 2 do
		for k = 0, 11 do
			table.insert(rings, { part = newPart(Vector3.new(0.1, 0.03, 0.02), i == 1 and RED_CORE or RED, 1), a = k / 12 * math.pi * 2, delay = (i - 1) * 0.08 })
		end
	end
	local dot = newPart(Vector3.one * 0.12, RED_CORE, 1, Enum.PartType.Ball)
	local at -- (the touch point on the board, taken at the moment of the tap)
	local function cleanup()
		for _, r in ipairs(rings) do r.part:Destroy() end
		dot:Destroy()
	end
	return function(now)
		local st = now - t0
		if st >= TAP_AT + 0.5 or not b.model.Parent then
			cleanup()
			return false
		end
		if st < TAP_AT or not b.cf then
			return true
		end
		if not at then
			-- the fingertip, pressed onto the board's plane
			local tip = b.model:FindFirstChild("IndexTip", true)
			local p = tip and (tip.CFrame * CFrame.new(0, 0, -tip.Size.Z / 2)).Position or b.ringCF.Position
			local n = b.cf.LookVector
			at = p - n * n:Dot(p - b.cf.Position)
			Sfx.playAt("holo_tap", at, 1, 0.97 + math.random() * 0.06, 90)
		end
		local face = b.cf - b.cf.Position + at
		local k = b.k
		for _, r in ipairs(rings) do
			local f = math.clamp((st - TAP_AT - r.delay) / 0.4, 0, 1)
			local radius = (0.05 + 0.45 * smooth(f)) * k
			r.part.Size = Vector3.new(2 * radius * math.sin(math.pi / 12) * 0.85, 0.03 * k, 0.02)
			r.part.CFrame = face * CFrame.new(0, 0, -0.02) * CFrame.Angles(0, 0, r.a) * CFrame.new(radius, 0, 0) * CFrame.Angles(0, 0, math.pi / 2)
			r.part.Transparency = (f <= 0 or f >= 1) and 1 or f
		end
		local df = (st - TAP_AT) / 0.25
		dot.Size = Vector3.one * (0.12 + 0.2 * df) * k
		dot.CFrame = face
		dot.Transparency = df >= 1 and 1 or df
		return true
	end
end

-- ====================================================================
-- A shockwave ring: a ring of segments round `pos`, square to `dir`, racing out from r0 to r1 and fading over `life`
-- (the sky muzzle blast, the shell's rings along its path, the sonic boom halfway down)
-- ====================================================================
local function shockRing(pos, dir, r0, r1, life, color, thick, n)
	n = n or 18
	local segs = {}
	for k = 0, n - 1 do
		table.insert(segs, { part = newPart(Vector3.new(1, thick, thick), color, 1), a = k / n * math.pi * 2 })
	end
	local face = CFrame.lookAt(pos, pos + dir)
	local t0 = os.clock()
	return function(now)
		local f = (now - t0) / life
		if f >= 1 then
			for _, sg in ipairs(segs) do sg.part:Destroy() end
			return false
		end
		local e = 1 - (1 - f) ^ 3 -- (fast out, slowing)
		local radius = r0 + (r1 - r0) * e
		for _, sg in ipairs(segs) do
			sg.part.Size = Vector3.new(2 * radius * math.sin(math.pi / n) * 0.9, thick * (1 - f * 0.7), thick * (1 - f * 0.7))
			sg.part.CFrame = face * CFrame.Angles(0, 0, sg.a) * CFrame.new(radius, 0, 0) * CFrame.Angles(0, 0, math.pi / 2)
			sg.part.Transparency = 0.15 + 0.85 * f
		end
		return true
	end
end

-- ====================================================================
-- The shot (FIRE_AT .. IMPACT_AT): a big muzzle blast far up in the sky with a ring rolling out, then a white-hot,
-- man-sized slug comes down the laser's line in SHELL_FLIGHT s (slow enough to follow), a long tracer behind it,
-- shockwave rings popping off its path and a sonic boom ring halfway down
-- ====================================================================
local SHELL_RING_EVERY = 22 -- studs between the rings along its path (a long way down now)

local function shell(aim, origin, t0)
	local flash = newPart(Vector3.one, WHITE, 1, Enum.PartType.Ball)
	flash.CFrame = CFrame.new(origin)
	local flashHalo = newPart(Vector3.one, HOT, 1, Enum.PartType.Ball)
	flashHalo.CFrame = CFrame.new(origin)
	local flashLight = Instance.new("PointLight")
	flashLight.Color = HOT
	flashLight.Range = 60
	flashLight.Brightness = 0
	flashLight.Shadows = false
	flashLight.Parent = flash

	local dir = (aim - origin).Unit
	local slug = newPart(Vector3.new(1.1, 1.1, 4.5), WHITE, 1)
	local sheath = newPart(Vector3.new(2.2, 2.2, 7.5), HOT, 1)
	local halo = newPart(Vector3.new(3.6, 3.6, 3.6), FIRE, 1, Enum.PartType.Ball)
	slug.CFrame = CFrame.lookAt(origin, origin + dir) -- (start where it is fired, not at the world origin)
	sheath.CFrame, halo.CFrame = slug.CFrame, slug.CFrame
	local slugLight = Instance.new("PointLight")
	slugLight.Color = HOT
	slugLight.Range = 22
	slugLight.Brightness = 0
	slugLight.Shadows = false
	slugLight.Parent = slug
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, 0.8, 2)
	a0.Parent = slug
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -0.8, 2)
	a1.Parent = slug
	local trail = Instance.new("Trail")
	trail.Attachment0, trail.Attachment1 = a0, a1
	trail.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, WHITE), ColorSequenceKeypoint.new(0.3, HOT), ColorSequenceKeypoint.new(1, FIRE) })
	trail.LightEmission = 1
	trail.Lifetime = 0.45
	trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
	trail.WidthScale = NumberSequence.new(1, 0.15)
	trail.FaceCamera = true
	trail.Enabled = false -- (on once the shell flies: a trail would draw a streak from wherever the part was before)
	trail.Parent = slug

	local flight = IMPACT_AT - FIRE_AT
	local total = (aim - origin).Magnitude
	local nextRing = SHELL_RING_EVERY
	local boomed = false
	local blasted = false
	local whistled = false
	return function(now)
		local st = now - t0
		if st < FIRE_AT then
			return true
		end
		if st >= IMPACT_AT then
			flash:Destroy()
			flashHalo:Destroy()
			slug:Destroy()
			sheath:Destroy()
			halo:Destroy()
			return false
		end
		if not blasted then
			blasted = true
			Sfx.playAt("cannon_far", aim + Vector3.new(0, 40, 0), 1, 0.95 + math.random() * 0.1, 400)
			-- the muzzle blast: a ring rolling out square to the shot, a second wider and fainter one
			table.insert(active, shockRing(origin, dir, 6, 80, 0.8, WHITE, 1.4, 28))
			table.insert(active, shockRing(origin, dir, 4, 52, 1.0, HOT, 2, 22))
		end
		-- the flash in the sky blooms and fades in 0.4 s
		local ft = (st - FIRE_AT) / 0.4
		if ft < 1 then
			flash.Size = Vector3.one * (10 + 40 * smooth(ft))
			flash.Transparency = ft
			flashHalo.Size = Vector3.one * (20 + 70 * smooth(ft))
			flashHalo.Transparency = 0.4 + 0.6 * ft
			flashLight.Brightness = 6 * (1 - ft)
		else
			flash.Transparency, flashHalo.Transparency = 1, 1
			flashLight.Brightness = 0
		end
		if not whistled and st >= IMPACT_AT - 0.8 then
			whistled = true
			Sfx.playAt("shell_whistle", aim + Vector3.new(0, 18, 0), 1, 0.95 + math.random() * 0.1, 260)
		end
		-- the slug: heavy, picking up speed as it falls
		local f = ((st - FIRE_AT) / flight) ^ 1.35
		local pos = origin:Lerp(aim, f)
		local cf = CFrame.lookAt(pos, pos + dir)
		slug.CFrame = cf
		sheath.CFrame = cf * CFrame.new(0, 0, 2)
		halo.CFrame = cf
		trail.Enabled = true
		slug.Transparency = 0
		sheath.Transparency = 0.45 + math.random() * 0.15
		halo.Transparency = 0.75 + math.random() * 0.1
		slugLight.Brightness = 3
		-- rings popping off its path, and the sonic boom halfway down
		local travelled = f * total
		while travelled >= nextRing do
			local at = origin + dir * nextRing
			table.insert(active, shockRing(at, dir, 1.2, 4.5 + nextRing / total * 3, 0.35, HOT, 0.22, 14))
			nextRing += SHELL_RING_EVERY
		end
		if not boomed and f >= 0.5 then
			boomed = true
			table.insert(active, shockRing(pos, dir, 2, 16, 0.6, WHITE, 0.45, 24))
		end
		return true
	end
end

-- ====================================================================
-- The impact (IMPACT_AT): a white flash, a fireball, a shockwave over the wall face, big debris thrown out, a dust ring
-- rolling out along the ground, glowing embers drifting down, sparks and smoke, a scorch mark that cools; and a short
-- camera shake for the plot's owner when they are close
-- ====================================================================
local SHAKE_RANGE = 90
local shakeUntil, shakeStrength = 0, 0

local function impact(aim, normal, ownerId)
	local pos = aim + normal * 0.6
	local face = CFrame.lookAt(pos, pos + normal)

	local core = newPart(Vector3.one, WHITE, 0, Enum.PartType.Ball)
	core.CFrame = CFrame.new(pos)
	local fireball = newPart(Vector3.one, FIRE, 0.15, Enum.PartType.Ball)
	fireball.CFrame = CFrame.new(pos + normal * 1)
	local light = Instance.new("PointLight")
	light.Color = HOT
	light.Range = 34
	light.Brightness = 6
	light.Shadows = false
	light.Parent = core

	-- the shockwave: a ring of segments racing out over the wall face, white-hot with Malak's cold light at the edge
	local ring = {}
	local N = 28
	for k = 0, N - 1 do
		table.insert(ring, { part = newPart(Vector3.new(1, 0.3, 0.1), k % 2 == 0 and WHITE or COLD), a = k / N * math.pi * 2 })
	end

	-- a scorch mark that cools from orange to black and fades
	local scorch = newPart(Vector3.new(0.05, 5.5, 5.5), FIRE, 0, Enum.PartType.Cylinder, Enum.Material.Neon)
	scorch.CFrame = CFrame.lookAt(aim + normal * 0.25, aim + normal * 2) * CFrame.Angles(0, math.pi / 2, 0)

	-- the ground below the hit (for the dust ring)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { fx }
	local down = workspace:Raycast(aim + normal * 3, Vector3.new(0, -30, 0), params)
	local groundPos = down and down.Position or (aim + normal * 3 - Vector3.new(0, 4, 0))

	-- debris: big dark chunks thrown out of the wall, falling with gravity, bouncing once off the ground
	local chunks = {}
	for _ = 1, 14 do
		local size = 0.4 + math.random() * 0.7
		local p = newPart(Vector3.new(size, size * (0.6 + math.random() * 0.6), size), Color3.fromRGB(58, 52, 56), 0, nil, Enum.Material.Slate)
		local spread = Vector3.new(math.random() - 0.5, math.random() * 0.9, math.random() - 0.5) * 2
		local vel = normal * (16 + math.random() * 16) + spread * 11
		table.insert(chunks, { part = p, pos = pos, vel = vel, spin = Vector3.new(math.random(), math.random(), math.random()) * 10, bounced = false })
	end

	-- particles from one emitter part on the wall face, and the dust ring from a flat disc on the ground
	local emitterPart = newPart(Vector3.one * 0.5, WHITE, 1)
	emitterPart.CFrame = face
	local sparks = Instance.new("ParticleEmitter")
	sparks.Texture = SPARK_TEXTURE
	sparks.Color = ColorSequence.new(WHITE, HOT)
	sparks.LightEmission = 1
	sparks.Size = NumberSequence.new(0.45, 0)
	sparks.Lifetime = NumberRange.new(0.5, 1.0)
	sparks.Speed = NumberRange.new(28, 50)
	sparks.SpreadAngle = Vector2.new(75, 75)
	sparks.Acceleration = Vector3.new(0, -40, 0)
	sparks.EmissionDirection = Enum.NormalId.Front
	sparks.Drag = 2
	sparks.Enabled = false
	sparks.Parent = emitterPart
	local flames = Instance.new("ParticleEmitter")
	flames.Texture = SMOKE_TEXTURE
	flames.Color = ColorSequence.new(HOT, FIRE)
	flames.LightEmission = 0.8
	flames.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 5.5) })
	flames.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
	flames.Lifetime = NumberRange.new(0.35, 0.65)
	flames.Speed = NumberRange.new(7, 14)
	flames.SpreadAngle = Vector2.new(60, 60)
	flames.EmissionDirection = Enum.NormalId.Front
	flames.Enabled = false
	flames.Parent = emitterPart
	local smoke = Instance.new("ParticleEmitter")
	smoke.Texture = SMOKE_TEXTURE
	smoke.Color = ColorSequence.new(Color3.fromRGB(40, 36, 40), Color3.fromRGB(80, 74, 78))
	smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2.5), NumberSequenceKeypoint.new(1, 8) })
	smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) })
	smoke.Lifetime = NumberRange.new(1.8, 2.8)
	smoke.Speed = NumberRange.new(3, 8)
	smoke.SpreadAngle = Vector2.new(55, 55)
	smoke.Acceleration = Vector3.new(0, 2.5, 0)
	smoke.Drag = 1.5
	smoke.RotSpeed = NumberRange.new(-40, 40)
	smoke.Rotation = NumberRange.new(0, 360)
	smoke.EmissionDirection = Enum.NormalId.Front
	smoke.Enabled = false
	smoke.Parent = emitterPart
	local embers = Instance.new("ParticleEmitter")
	embers.Texture = SPARK_TEXTURE
	embers.Color = ColorSequence.new(HOT, FIRE)
	embers.LightEmission = 1
	embers.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.22), NumberSequenceKeypoint.new(0.8, 0.15), NumberSequenceKeypoint.new(1, 0) })
	embers.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.7, 0.2), NumberSequenceKeypoint.new(1, 1) })
	embers.Lifetime = NumberRange.new(1.5, 2.6)
	embers.Speed = NumberRange.new(6, 14)
	embers.SpreadAngle = Vector2.new(80, 80)
	embers.Acceleration = Vector3.new(0, -5, 0)
	embers.Drag = 2.5
	embers.RotSpeed = NumberRange.new(-90, 90)
	embers.EmissionDirection = Enum.NormalId.Front
	embers.Enabled = false
	embers.Parent = emitterPart
	sparks:Emit(55)
	flames:Emit(24)
	smoke:Emit(18)
	embers:Emit(36)
	Debris:AddItem(emitterPart, 3.5)

	local dustPart = newPart(Vector3.one * 0.5, WHITE, 1)
	dustPart.CFrame = CFrame.new(groundPos + Vector3.new(0, 0.4, 0))
	local dust = Instance.new("ParticleEmitter")
	dust.Texture = SMOKE_TEXTURE
	dust.Color = ColorSequence.new(Color3.fromRGB(96, 88, 84), Color3.fromRGB(70, 64, 62))
	dust.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.8), NumberSequenceKeypoint.new(1, 5) })
	dust.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1) })
	dust.Lifetime = NumberRange.new(1.2, 1.9)
	dust.Speed = NumberRange.new(16, 26)
	dust.Drag = 3
	dust.Shape = Enum.ParticleEmitterShape.Disc
	dust.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
	dust.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	dust.EmissionDirection = Enum.NormalId.Top
	dust.RotSpeed = NumberRange.new(-30, 30)
	dust.Rotation = NumberRange.new(0, 360)
	dust.Enabled = false
	dust.Parent = dustPart
	dust:Emit(46)
	Debris:AddItem(dustPart, 2.5)

	-- the camera shake: only the plot's owner, and only near the hit
	local me = game:GetService("Players").LocalPlayer
	local camera = workspace.CurrentCamera
	if me and ownerId == tostring(me.UserId) and camera then
		local d = (camera.CFrame.Position - pos).Magnitude
		if d < SHAKE_RANGE then
			shakeStrength = math.max(shakeStrength, 0.55 * (1 - d / SHAKE_RANGE))
			shakeUntil = os.clock() + 0.45
		end
	end

	local t0 = os.clock()
	local last = t0
	local LIFE = 3
	local floorY = groundPos.Y
	return function(now)
		local st = now - t0
		local dt = math.min(now - last, 1 / 20)
		last = now
		if st >= LIFE then
			core:Destroy()
			fireball:Destroy()
			scorch:Destroy()
			for _, r in ipairs(ring) do r.part:Destroy() end
			for _, c in ipairs(chunks) do c.part:Destroy() end
			return false
		end
		-- white flash: pops to full size in 0.06 s, gone by 0.3 s
		local cf = st / 0.3
		if cf < 1 then
			core.Size = Vector3.one * (1 + 9 * math.min(1, st / 0.06))
			core.Transparency = smooth(cf)
		else
			core.Transparency = 1
		end
		-- fireball swells and burns out
		local fb = st / 0.8
		if fb < 1 then
			fireball.Size = Vector3.one * (2.5 + 6.5 * smooth(fb))
			fireball.Transparency = 0.15 + 0.85 * fb
			fireball.Color = HOT:Lerp(FIRE, fb)
		else
			fireball.Transparency = 1
		end
		light.Brightness = 6 * math.max(0, 1 - st / 0.9)
		-- shockwave over the wall face
		local sw = st / 0.5
		for _, r in ipairs(ring) do
			if sw < 1 then
				local radius = 1 + 10 * smooth(sw)
				local seg = 2 * radius * math.sin(math.pi / N) * 0.9
				r.part.Size = Vector3.new(seg, 0.35 * (1 - sw) + 0.05, 0.1)
				r.part.CFrame = face * CFrame.Angles(0, 0, r.a) * CFrame.new(radius, 0, 0) * CFrame.Angles(0, 0, math.pi / 2)
				r.part.Transparency = sw
			else
				r.part.Transparency = 1
			end
		end
		-- scorch: glowing orange, cooling to black, fading out at the end
		local cool = smooth(st / 1.4)
		scorch.Color = FIRE:Lerp(Color3.fromRGB(20, 16, 18), cool)
		scorch.Material = cool > 0.6 and Enum.Material.SmoothPlastic or Enum.Material.Neon
		scorch.Transparency = 0.1 + 0.9 * smooth((st - 2) / 1.0)
		-- debris: falls, bounces once off the ground, then lies and fades
		for _, c in ipairs(chunks) do
			c.vel += Vector3.new(0, -60, 0) * dt
			c.pos += c.vel * dt
			local half = c.part.Size.Y / 2
			if c.pos.Y < floorY + half then
				c.pos = Vector3.new(c.pos.X, floorY + half, c.pos.Z)
				if not c.bounced then
					c.bounced = true
					c.vel = Vector3.new(c.vel.X * 0.4, -c.vel.Y * 0.3, c.vel.Z * 0.4)
				else
					c.vel = Vector3.new(c.vel.X * 0.8, 0, c.vel.Z * 0.8)
				end
			end
			local spin = c.bounced and 0.3 or 1
			c.part.CFrame = CFrame.new(c.pos) * CFrame.Angles(c.spin.X * st * spin, c.spin.Y * st * spin, c.spin.Z * st * spin)
			c.part.Transparency = smooth((st - 2.2) / 0.8)
		end
		return true
	end
end

-- the camera shake: a small offset on top of wherever the camera was placed this frame
RunService:BindToRenderStep("OrbitalStrikeShake", Enum.RenderPriority.Camera.Value + 1, function()
	local camera = workspace.CurrentCamera
	local left = shakeUntil - os.clock()
	if not camera or left <= 0 then
		return
	end
	local k = shakeStrength * (left / 0.45) ^ 1.5
	local t = os.clock() * 40
	camera.CFrame = camera.CFrame * CFrame.new(math.sin(t) * k * 0.6, math.sin(t * 1.3 + 1) * k, 0)
		* CFrame.Angles(math.sin(t * 0.9) * k * 0.02, 0, math.sin(t * 1.1 + 2) * k * 0.03)
end)

-- ====================================================================
-- The drone's volley (model attributes DroneShot = server time it starts, DroneAim; Army.fireCompanion deals the damage
-- at Units.Malak.companion.hitAt = DRONE_IMPACT). Timed on the synced server clock, like UnitAnimator's ring spread:
--   0 .. 0.9         the rings drift apart into a triangle in front of the drone (UnitAnimator)
--   DRONE_CHARGE     a cold spark gathers in the middle of each ring, flickering, growing
--   DRONE_FIRE       the three rings fire one after the other (DRONE_STAGGER apart): thin cold bolts that start slow
--                    and accelerate, converging on one spot on the wall
--   DRONE_IMPACT     where they meet: a cold flash, a ring over the wall face, sparks, a short light
-- ====================================================================
local DRONE_CHARGE = 0.9
local DRONE_FIRE = 1.6
local DRONE_STAGGER = 0.06
local DRONE_FLIGHT = 0.33
local DRONE_IMPACT = 2.05 -- (= Units.Malak.companion.hitAt; the last bolt arrives just before)
local DRONE_SOUND_LEAD = 0.12 -- the bolt sounds start this much before the bolts leave (a sound takes a moment to start)
local DRONE_COLD = Color3.fromRGB(150, 175, 255)
local DRONE_CORE = Color3.fromRGB(235, 242, 255)

local function droneSpark(hinge, shotAt, fireAt)
	local spark = newPart(Vector3.one * 0.1, DRONE_CORE, 1, Enum.PartType.Ball)
	local halo = newPart(Vector3.one * 0.3, DRONE_COLD, 1, Enum.PartType.Ball)
	local light = Instance.new("PointLight")
	light.Color = DRONE_COLD
	light.Range = 5
	light.Brightness = 0
	light.Shadows = false
	light.Parent = spark
	return function()
		local st = workspace:GetServerTimeNow() - shotAt
		if st >= fireAt + 0.08 or not hinge.Parent then
			spark:Destroy()
			halo:Destroy()
			return false
		end
		if st < DRONE_CHARGE then
			return true
		end
		local g = smooth((st - DRONE_CHARGE) / (fireAt - DRONE_CHARGE))
		local flick = 0.85 + math.random() * 0.15
		local pos = hinge.Position
		spark.CFrame, halo.CFrame = CFrame.new(pos), CFrame.new(pos)
		spark.Size = Vector3.one * (0.1 + 0.3 * g) * flick
		halo.Size = Vector3.one * (0.3 + 0.7 * g) * flick
		spark.Transparency = 0.1
		halo.Transparency = 0.75 - 0.25 * g
		light.Brightness = 1.5 * g
		return true
	end
end

local function droneBolt(hinge, aim, shotAt, fireAt)
	local head = newPart(Vector3.new(0.12, 0.12, 1.6), DRONE_CORE, 1)
	local sheath = newPart(Vector3.new(0.32, 0.32, 2.4), DRONE_COLD, 1)
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, 0.1, 0.8)
	a0.Parent = head
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -0.1, 0.8)
	a1.Parent = head
	local trail = Instance.new("Trail")
	trail.Attachment0, trail.Attachment1 = a0, a1
	trail.Color = ColorSequence.new(DRONE_CORE, DRONE_COLD)
	trail.LightEmission = 1
	trail.Lifetime = 0.18
	trail.Transparency = NumberSequence.new(0.1, 1)
	trail.FaceCamera = true
	trail.Enabled = false
	trail.Parent = head
	local from
	return function()
		local st = workspace:GetServerTimeNow() - shotAt
		if st >= fireAt + DRONE_FLIGHT or not hinge.Parent then
			head:Destroy()
			sheath:Destroy()
			return false
		end
		if st < fireAt then
			return true
		end
		if not from then
			from = hinge.Position
			head.CFrame = CFrame.lookAt(from, aim)
			trail.Enabled = true
		end
		local f = ((st - fireAt) / DRONE_FLIGHT) ^ 1.6 -- (starts slow, accelerates hard)
		local pos = from:Lerp(aim, f)
		local cf = CFrame.lookAt(pos, aim)
		head.CFrame = cf
		sheath.CFrame = cf * CFrame.new(0, 0, 0.5)
		head.Transparency = 0
		sheath.Transparency = 0.55 + math.random() * 0.15
		return true
	end
end

local function droneImpact(aim, normal)
	local pos = aim + normal * 0.4
	local face = CFrame.lookAt(pos, pos + normal)
	local flash = newPart(Vector3.one, DRONE_CORE, 0, Enum.PartType.Ball)
	flash.CFrame = CFrame.new(pos)
	local light = Instance.new("PointLight")
	light.Color = DRONE_COLD
	light.Range = 14
	light.Brightness = 3
	light.Shadows = false
	light.Parent = flash
	local ring = {}
	for k = 0, 15 do
		table.insert(ring, { part = newPart(Vector3.new(0.4, 0.12, 0.06), DRONE_COLD, 1), a = k / 16 * math.pi * 2 })
	end
	local emitterPart = newPart(Vector3.one * 0.4, DRONE_CORE, 1)
	emitterPart.CFrame = face
	local sparks = Instance.new("ParticleEmitter")
	sparks.Texture = SPARK_TEXTURE
	sparks.Color = ColorSequence.new(DRONE_CORE, DRONE_COLD)
	sparks.LightEmission = 1
	sparks.Size = NumberSequence.new(0.25, 0)
	sparks.Lifetime = NumberRange.new(0.3, 0.6)
	sparks.Speed = NumberRange.new(14, 26)
	sparks.SpreadAngle = Vector2.new(70, 70)
	sparks.Acceleration = Vector3.new(0, -30, 0)
	sparks.Drag = 2
	sparks.EmissionDirection = Enum.NormalId.Front
	sparks.Enabled = false
	sparks.Parent = emitterPart
	sparks:Emit(24)
	Debris:AddItem(emitterPart, 1.5)
	local t0 = os.clock()
	return function(now)
		local st = now - t0
		if st >= 0.6 then
			flash:Destroy()
			for _, r in ipairs(ring) do r.part:Destroy() end
			return false
		end
		local f = st / 0.25
		flash.Size = Vector3.one * (0.6 + 2.6 * math.min(1, st / 0.05))
		flash.Transparency = math.min(1, f)
		light.Brightness = 3 * math.max(0, 1 - st / 0.4)
		local rf = st / 0.4
		for _, r in ipairs(ring) do
			if rf < 1 then
				local radius = 0.4 + 3 * smooth(rf)
				r.part.Size = Vector3.new(2 * radius * math.sin(math.pi / 16) * 0.85, 0.14 * (1 - rf) + 0.03, 0.06)
				r.part.CFrame = face * CFrame.Angles(0, 0, r.a) * CFrame.new(radius, 0, 0) * CFrame.Angles(0, 0, math.pi / 2)
				r.part.Transparency = rf
			else
				r.part.Transparency = 1
			end
		end
		return true
	end
end

local function onDroneShot(model)
	local shotAt = model:GetAttribute("DroneShot")
	local aim = model:GetAttribute("DroneAim")
	local root = model.PrimaryPart
	if not shotAt or not aim or not root then return end
	local camera = workspace.CurrentCamera
	if camera and (root.Position - camera.CFrame.Position).Magnitude > MAX_DISTANCE then return end
	local normal = wallNormal(aim, root.Position)
	for i = 1, 3 do
		local hinge = model:FindFirstChild("DroneRingHinge" .. i, true)
		if hinge then
			local fireAt = DRONE_FIRE + (i - 1) * DRONE_STAGGER
			table.insert(active, droneSpark(hinge, shotAt, fireAt))
			table.insert(active, droneBolt(hinge, aim, shotAt, fireAt))
		end
	end
	-- sounds: three rising charge blips from the rings, a bolt per ring, the hit where they meet
	local elapsed = workspace:GetServerTimeNow() - shotAt
	for i = 1, 3 do
		local hinge = model:FindFirstChild("DroneRingHinge" .. i, true)
		task.delay(math.max(0, DRONE_CHARGE + (i - 1) * 0.2 - elapsed), function()
			if hinge and hinge.Parent then
				Sfx.playAt("drone_charge", hinge.Position, 1, 1 + (i - 1) * 0.12, 120)
			end
		end)
		task.delay(math.max(0, DRONE_FIRE + (i - 1) * DRONE_STAGGER - DRONE_SOUND_LEAD - elapsed), function()
			if hinge and hinge.Parent then
				Sfx.playAt("drone_bolt", hinge.Position, 1, 0.94 + (i - 1) * 0.06, 120)
			end
		end)
	end
	local wait = DRONE_FIRE + 2 * DRONE_STAGGER + DRONE_FLIGHT - (workspace:GetServerTimeNow() - shotAt)
	task.delay(math.max(0, wait), function()
		table.insert(active, droneImpact(aim, normal))
		Sfx.playAt("drone_hit", aim, 1, 0.95 + math.random() * 0.1, 160)
	end)
end

-- ============================================================
-- Watching the units
-- ============================================================
local function onAttack(model)
	local root = model.PrimaryPart
	if not root then return end
	local camera = workspace.CurrentCamera
	if camera and (root.Position - camera.CFrame.Position).Magnitude > MAX_DISTANCE then return end
	local t0 = os.clock()
	-- the big hologram opens (or stays open) while he fights; the targeting and the tap play on it
	local b = boards[model]
	if not b then
		b = newBoard(model)
		boards[model] = b
	end
	b.last = t0
	table.insert(active, targeting(b, t0))
	table.insert(active, tapRipple(b, t0))
	-- (AimPos arrives with the attack; read it a moment later so it is the new spot)
	task.delay(0.2, function()
		local aim = model:GetAttribute("AimPos")
		if not aim or not model.Parent then return end
		local unitPos = root.Position
		local normal = wallNormal(aim, unitPos)
		local side = normal:Cross(Vector3.new(0, 1, 0)).Unit
		local origin = aim + Vector3.new(0, SKY_HEIGHT, 0) + normal * SKY_FORWARD + side * SKY_SIDE
		table.insert(active, laser(aim, origin, normal, t0))
		table.insert(active, shell(aim, origin, t0))
		task.delay(math.max(0, IMPACT_AT - (os.clock() - t0)), function()
			table.insert(active, impact(aim, normal, model:GetAttribute("OwnerId")))
		end)
		-- (the impact sound starts a moment early: a sound takes a little while to start, it would land late)
		task.delay(math.max(0, IMPACT_AT - IMPACT_SOUND_LEAD - (os.clock() - t0)), function()
			Sfx.playAt("shell_impact", aim + normal * 0.6, 1, 0.95 + math.random() * 0.1, 260)
		end)
	end)
end

local watched = {}
local function watch(model)
	if watched[model] then return end
	watched[model] = true
	model:GetAttributeChangedSignal("DroneShot"):Connect(function()
		onDroneShot(model)
	end)
	model:GetAttributeChangedSignal("AttackCount"):Connect(function()
		if model:GetAttribute("AttackStyle") == "OrbitalTag" then
			onAttack(model)
		end
	end)
end
for _, model in ipairs(CollectionService:GetTagged(TAG)) do
	watch(model)
end
CollectionService:GetInstanceAddedSignal(TAG):Connect(watch)
CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(model)
	watched[model] = nil
	if boards[model] then
		destroyBoard(boards[model])
		boards[model] = nil
	end
end)

local lastFrame = os.clock()
RunService.RenderStepped:Connect(function()
	local now = os.clock()
	local dt = now - lastFrame
	lastFrame = now
	for model, b in pairs(boards) do
		if model.Parent then
			updateBoard(b, now, dt)
		else
			destroyBoard(b)
			boards[model] = nil
		end
	end
	for i = #active, 1, -1 do
		if not active[i](now) then
			table.remove(active, i)
		end
	end
end)

return {
	IMPACT_AT = IMPACT_AT,
}
