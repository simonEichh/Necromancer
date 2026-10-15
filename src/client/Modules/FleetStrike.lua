-- Malak's finisher, "Fleet Strike" (docs/envoy.md): the cutscene in which the Absolution executes the gate.
--
--   local started = FleetStrike.play(opts)
--     opts: onDone   function(), called when the cutscene ends (also when it is skipped)
--     returns false (and does nothing) when it cannot play: no Malak of yours in the world, or it is already running.
--
-- BUILT IN STEPS (each one approved before the next):
-- Started by the SERVER for everyone (Army.checkFleetStrike: the gate at 20% HP, the owner bought it, a Malak on the
-- plot; remote FleetStrike): every client plays the world part from the same server time; the owner's camera is taken
-- over (Skip only gives it back), the other players see it in the sky and may press Watch. The DEV panel previews it
-- (opts.preview: the army is held through DevFleetStrike, the gate is only hidden on this screen).
--   1. the frame (done): camera / controls / UI taken over and restored like the other cinematics (SignatureDescent,
--      StarSummon), letterbox bars, Skip, the timeline of beats and a placeholder camera shot for each beat; in Studio
--      a caption names the beat that is playing, to judge the pacing before anything is built
--   2. Malak's beats (done): the left hand types on the runes rising from his gauntlet, the drone becomes a transmitter
--      and sends a pulse into the sky, the army flees (server: Army.startFinisher, started here in Studio through the
--      DevFleetStrike remote), every nameplate is hidden and his big attack hologram closes
--   3. the sky tears, the portal, the warp-in (done)
--   4. scan + barrage (done)
--   5. the main cannon, the beam strikes the realm keeper and sweeps down onto the gate, the gate falls (done)
--   7. gameplay (done): the server trigger, the gate held and broken for real, the Gem Shop / Codex unlock, everyone sees it
--   6. the ending (done): the drone unfolds, the ship lingers over the arena and leaves backwards through a portal      5. main cannon + beam + the gate breaks
--   6. the ending, the ship lingers and warps out  7. gameplay (trigger at 20% gate HP, gems unlock, toggle)  8. sound
-- Nothing here touches real gameplay yet: it is started from the DEV panel (Anim: Fleet, Play).
-- The timeline runs on the server's clock (workspace:GetServerTimeNow() - startAt), so every client is in step.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local mainGui = require(script.Parent.Gui)
local Theme = require(script.Parent.Theme)
local Sfx = require(script.Parent.Sfx)

local player = Players.LocalPlayer

local FleetStrike = {}
FleetStrike.active = false

-- ============================================================
-- Settings
-- ============================================================
local DURATION = 54
local BAR_HEIGHT = 0.1 -- the letterbox bars, as a fraction of the screen height each
local BAR_TIME = 0.8
-- Where the tear opens and the ship hangs: NOT over the player but diagonally away, high up, off to the side of the lane
-- (Malak's left: the side his basic attack's red laser comes from) and down the lane towards the gate, so from his
-- spot the ship is seen side-on, not from below
-- The whole sky scene (the ship, the portal and its tear, the warp-out) is built at SKY_SCALE of its design size and
-- that much closer: it looks the same from the camera, but stays inside what low graphics quality still draws (measured
-- 2026-10-15: Level 1 draws to ~300-350 studs, Level 5 ~450, Level 10 ~700; at full size the ship sat ~800 away and
-- vanished whenever Automatic quality dropped). Every sky distance / size below is multiplied by it.
local SKY_SCALE = 1 / 3
-- The ship itself is a little bigger than that (the user: "it should look a bit bigger"): its own size and every
-- offset measured on it (bow, muzzle, missile tubes, the cannon slide, the warp travel) use SHIP_SCALE
local SHIP_SCALE = 0.55
local SKY_HEIGHT = 400 * SKY_SCALE -- (far away and not too steep: the player sees the whole broadside, not the belly)
local SKY_SIDE = 650 * SKY_SCALE
local SKY_LEFT = 150 * SKY_SCALE -- (then shifted this far to the left as seen from Malak)
local PORTAL_BEHIND = 250 * SHIP_SCALE -- the portal's distance behind the ship's final place (ship-sized: its stern must clear the portal)
local SKY_ALONG = 0.75 -- (of the way from Malak to the gate)

-- The beats (docs/envoy.md, "Fleet Strike cutscene"): start time and name (the Studio caption; the camera runs on its
-- own continuous path, KEYS below).
local BEATS = {
	{ at = 0, name = "The trigger" },
	{ at = 1.5, name = "The left hand" },
	{ at = 6, name = "The drone transforms" },
	{ at = 11, name = "The army flees" },
	{ at = 13, name = "The sky tears" },
	{ at = 19, name = "The warp-in" },
	{ at = 31, name = "Scanning" },
	{ at = 36, name = "Barrage" },
	{ at = 42, name = "The main cannon" },
	{ at = 46, name = "The beam" },
	{ at = 49.4, name = "The gate falls" },
	{ at = 51, name = "Back to Malak" },
}

local function smooth(x)
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

-- the player's own Malak (the nearest one, if there are several)
local function findMalak()
	local me = tostring(player.UserId)
	local best, bestDist
	local char = player.Character
	local from = char and char.PrimaryPart and char.PrimaryPart.Position or Vector3.zero
	for _, m in ipairs(CollectionService:GetTagged("ProceduralUnit")) do
		if m.Name == "Malak" and m.Parent and m:GetAttribute("OwnerId") == me then
			local d = (m:GetPivot().Position - from).Magnitude
			if not bestDist or d < bestDist then
				best, bestDist = m, d
			end
		end
	end
	return best
end

-- ============================================================
-- The camera: ONE continuous path through keyframes over the whole cutscene (not a shot per beat), so it never stops
-- and restarts between beats. Position, look-at point and field of view each run through a time-based Catmull-Rom
-- spline (smooth speed through every key). Keys are functions of ctx: M (Malak's frame, LookVector = towards the
-- gate), D (level, from Malak along the line to the tear), gate, sky (the ship's spot), portal, drone (his drone's
-- part, live), start (the player's camera). From the drone to the warp-in the camera stays on the line D, behind him,
-- so it mostly drifts and tilts instead of panning.
-- ============================================================
local function droneAt(c)
	return c.drone and c.drone.Position or (c.M * CFrame.new(-2.4, 3.2, 0.4)).Position
end
-- a point on a level circle round the drone, between "on his left" (0) and "behind the drone on the line D" (1)
local function droneOrbit(c, f, r, h)
	local from = -c.M.RightVector
	local to = -c.D
	local a0, a1 = math.atan2(from.Z, from.X), math.atan2(to.Z, to.X)
	local delta = (a1 - a0 + math.pi) % (2 * math.pi) - math.pi
	local th = a0 + delta * f
	return droneAt(c) + Vector3.new(math.cos(th), 0, math.sin(th)) * r + Vector3.new(0, h, 0)
end
local function behind(c, back, up)
	return c.M.Position - c.D * back + Vector3.new(0, up, 0)
end
local function ahead(c)
	-- (eye level along the line to the tear: the army runs across the frame past him)
	return c.M.Position + c.D * 30 + Vector3.new(0, 6, 0)
end
local function wide(c, extra)
	return c.M.Position - c.D * (40 + extra) + c.M.RightVector * (20 + extra * 0.4) + Vector3.new(0, 26 + extra * 0.5, 0)
end
local function wideLook(c)
	return c.sky:Lerp(c.gate, 0.6)
end
local function gateView(c, drift)
	return c.gate - c.M.LookVector * (42 + drift) - c.M.RightVector * 16 + Vector3.new(0, 9, 0)
end

local KEYS = {
	-- the trigger: from the player's view into a wide shot behind Malak
	{ t = 0, pos = function(c) return c.start.Position end, look = function(c) return c.start.Position + c.start.LookVector * 20 end, fov = 70 },
	{ t = 1.6, pos = function(c) return (c.M * CFrame.new(5, 5, 15)).Position end, look = function(c) return (c.M * CFrame.new(0, 2, -20)).Position end, fov = 70 },
	-- the left hand: close in front of his chest and gauntlet, a slow push in
	{ t = 2.8, pos = function(c) return (c.M * CFrame.new(2.6, 1.7, -6)).Position end, look = function(c) return (c.M * CFrame.new(0.5, 1.1, -0.8)).Position end, fov = 70 },
	{ t = 5.6, pos = function(c) return (c.M * CFrame.new(2.2, 1.6, -4.7)).Position end, look = function(c) return (c.M * CFrame.new(0.4, 1.1, -0.8)).Position end, fov = 68 },
	-- the drone: round his left side to behind the drone, looking at it ...
	{ t = 7.0, pos = function(c) return droneOrbit(c, 0, 8, 1) end, look = function(c) return droneAt(c) end, fov = 66 },
	{ t = 8.4, pos = function(c) return droneOrbit(c, 0.6, 9, 0.7) end, look = function(c) return droneAt(c) + Vector3.new(0, 2, 0) end, fov = 66 },
	-- ... and up after the pulse (9.0) to the transmission rings climbing into the sky
	{ t = 9.6, pos = function(c) return droneOrbit(c, 1, 10, 0) end, look = function(c) return droneAt(c) + Vector3.new(0, 14, 0) end, fov = 68 },
	{ t = 10.9, pos = function(c) return droneOrbit(c, 1, 11, -0.6) end, look = function(c) return droneAt(c) + Vector3.new(0, 32, 0) + c.D * 4 end, fov = 70 },
	-- the army flees: tilt down to the ground ahead, the army running back past him
	{ t = 12.6, pos = function(c) return behind(c, 13, 3) end, look = ahead, fov = 70 },
	{ t = 14.2, pos = function(c) return behind(c, 15, 3.4) end, look = function(c) return ahead(c) + Vector3.new(0, 3, 0) end, fov = 70 },
	-- the sky tears: tilt up to the tear (it is on the line), pulling back a little
	{ t = 17.2, pos = function(c) return behind(c, 17, 4.2) end, look = function(c) return c.portal.Position end, fov = 66 },
	-- the warp-in: a long lens that follows the ship out of the portal
	{ t = 20.0, pos = function(c) return behind(c, 18, 4.5) end, look = function(c) return c.portal.Position end, fov = 52 },
	{ t = 23.5, pos = function(c) return behind(c, 17, 4.5) end, look = function(c) return c.portal.Position:Lerp(c.sky, 0.45) end, fov = 42 },
	{ t = 28.5, pos = function(c) return behind(c, 15.5, 4.5) end, look = function(c) return c.sky end, fov = 38 },
	-- scanning: on the ship while its turrets turn and the fan sweeps, then down the fan to the reticles on the gate
	{ t = 32.4, pos = function(c) return behind(c, 15, 4.5) end, look = function(c) return c.sky:Lerp(c.gate, 0.15) end, fov = 38 },
	{ t = 34.6, pos = function(c) return gateView(c, 0) end, look = function(c) return c.gate + Vector3.new(0, 5, 0) end, fov = 58 },
	{ t = 35.8, pos = function(c) return gateView(c, 3) end, look = function(c) return c.gate + Vector3.new(0, 5, 0) end, fov = 60 },
	-- back and wide before the barrage (38): the ship and the gate both in frame, then a slow drift through the fire
	{ t = 37.8, pos = function(c) return wide(c, 0) end, look = wideLook, fov = 76 },
	{ t = 42.0, pos = function(c) return wide(c, 8) end, look = wideLook, fov = 78 },
	-- the main cannon: a long lens on the bow as it opens and the cannon comes out
	-- (the ship has turned its nose round towards the keeper and the camera: the opened bow and the cannon head-on)
	{ t = 44.0, pos = function(c) return behind(c, 16, 4.5) end, look = function(c) return c.bow end, fov = 30 },
	{ t = 45.4, pos = function(c) return behind(c, 16, 4.5) end, look = function(c) return c.bow end, fov = 22 },
	-- the beam: wide, from behind him, the ship on one side and the keeper on the other, the beam between them ...
	{ t = 46.2, pos = function(c) return behind(c, 24, 9) end, look = function(c) return c.bow:Lerp(c.keeper, 0.5) end, fov = 76 },
	{ t = 47.6, pos = function(c) return behind(c, 25, 9) end, look = function(c) return c.bow:Lerp(c.keeper, 0.62) end, fov = 76 },
	-- ... following it down the outer wall onto the gate
	{ t = 49.4, pos = function(c) return behind(c, 20, 6) end, look = function(c) return c.keeper:Lerp(c.gate + Vector3.new(0, 6, 0), 0.85) end, fov = 64 },
	-- the gate falls; then over his shoulder, unbothered, at what is left of it
	{ t = 50.8, pos = function(c) return behind(c, 17, 5) end, look = function(c) return c.gate + Vector3.new(0, 4, 0) end, fov = 58 },
	{ t = 52.4, pos = function(c) return (c.M * CFrame.new(-3.5, 2.6, 7.5)).Position end, look = function(c) return (c.M * CFrame.new(0, 2, -30)).Position end, fov = 62 },
	{ t = 54.0, pos = function(c) return (c.M * CFrame.new(-3, 2.6, 6.2)).Position end, look = function(c) return (c.M * CFrame.new(0, 2, -30)).Position end, fov = 60 },
}

-- the camera at time T: cubic Hermite through the keys with MONOTONE tangents, per component (Fritsch-Carlson): it
-- moves smoothly through every key but never overshoots past them, so it cannot dip below the lowest key (into the
-- floor) or swing past a look target; it only eases to a stop where a motion reverses
local function cameraAt(T, c)
	local n = #KEYS
	local i = 1
	while i < n - 1 and KEYS[i + 1].t <= T do
		i += 1
	end
	local k0, k1 = KEYS[i], KEYS[i + 1]
	local kp, kn = KEYS[math.max(1, i - 1)], KEYS[math.min(n, i + 2)]
	local h = k1.t - k0.t
	local s = math.clamp((T - k0.t) / h, 0, 1)
	local s2, s3 = s * s, s * s * s
	local h00, h10, h01, h11 = 2 * s3 - 3 * s2 + 1, s3 - 2 * s2 + s, -2 * s3 + 3 * s2, s3 - s2
	-- the slope into a key from the slopes of the segments either side: zero where they disagree in sign (a turning
	-- point), their harmonic mean otherwise (no overshoot)
	local function slope(dPrev, dNext)
		if dPrev * dNext <= 0 then
			return 0
		end
		return 2 * dPrev * dNext / (dPrev + dNext)
	end
	local function spline1(p0, p1, pp, pn)
		local d = (p1 - p0) / h
		local dPrev = (i == 1) and d or (p0 - pp) / math.max(0.001, k0.t - kp.t)
		local dNext = (i + 1 == n) and d or (pn - p1) / math.max(0.001, kn.t - k1.t)
		local m0 = (i == 1) and d or slope(dPrev, d)
		local m1 = (i + 1 == n) and d or slope(d, dNext)
		return p0 * h00 + m0 * h * h10 + p1 * h01 + m1 * h * h11
	end
	local function spline3(get)
		local p0, p1, pp, pn = get(k0), get(k1), get(kp), get(kn)
		return Vector3.new(
			spline1(p0.X, p1.X, pp.X, pn.X),
			spline1(p0.Y, p1.Y, pp.Y, pn.Y),
			spline1(p0.Z, p1.Z, pp.Z, pn.Z)
		)
	end
	local pos = spline3(function(k) return k.pos(c) end)
	local look = spline3(function(k) return k.look(c) end)
	local fov = spline1(k0.fov, k1.fov, kp.fov, kn.fov)
	return pos, look, math.clamp(fov, 20, 90)
end

-- ============================================================
-- Step 2: Malak's beats (his poses are in UnitAnimator's Envoy block, driven by the model attribute FleetStart)
-- ============================================================
local GLOW = Color3.fromRGB(165, 180, 255)
local GLOW_CORE = Color3.fromRGB(235, 240, 255)
local GLOW_DEEP = Color3.fromRGB(96, 104, 230)

local function newPart(folder, size, color, transparency, shape)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = false, false, false, false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Size = size
	p.Transparency = transparency or 0
	if shape then
		p.Shape = shape
	end
	p.CFrame = CFrame.new(0, -5000, 0)
	p.Parent = folder
	return p
end

-- The rune panel (1.5 .. 6.6): rises out of the right gauntlet and faces his helmet. Two rows of runes; during the
-- drag one rune slides along the row into its place; at 5.3 the last one clicks home: the panel flashes and a confirm
-- ring spreads round it; then it folds back down into the gauntlet.
local function runePanel(folder, malak, scale)
	local fore = malak:FindFirstChild("RForearm", true)
	local head = malak:FindFirstChild("Head", true)
	local W, H = 1.0 * scale, 0.6 * scale
	local pane = newPart(folder, Vector3.new(W, H, 0.02), GLOW, 1)
	local edges = {}
	for i = 1, 4 do
		edges[i] = newPart(folder, Vector3.new(0.02, 0.02, 0.02), GLOW, 1)
	end
	local runes = {}
	for row = 0, 1 do
		for k = 0, 4 do
			table.insert(runes, { part = newPart(folder, Vector3.one * 0.07 * scale, GLOW_CORE, 1), x = -0.36 + k * 0.18, y = 0.11 - row * 0.22 })
		end
	end
	local dragged = runes[2] -- (the one he drags across)
	local ring = {}
	for k = 0, 15 do
		table.insert(ring, { part = newPart(folder, Vector3.new(0.05, 0.02, 0.02), GLOW_CORE, 1), a = k / 16 * math.pi * 2 })
	end
	return function(ft)
		if not fore or not fore.Parent or not head then
			return
		end
		local function e(a, b)
			local x = math.clamp((ft - a) / (b - a), 0, 1)
			return x * x * (3 - 2 * x)
		end
		local show = e(1.7, 2.5) * (1 - e(6.0, 6.6))
		local rise = 0.15 + 0.4 * show
		local pos = fore.Position + Vector3.new(0, rise * scale, 0)
		local cf = CFrame.lookAt(pos, head.Position)
		local k = 0.35 + 0.65 * show -- (it grows as it rises)
		local fade = 1 - show
		pane.Size = Vector3.new(W * k, H * k, 0.02)
		pane.CFrame = cf
		pane.Transparency = 0.82 + 0.18 * fade
		local corners = { { -1, 0 }, { 1, 0 }, { 0, -1 }, { 0, 1 } }
		for i, c in ipairs(corners) do
			local horizontal = c[2] ~= 0
			edges[i].Size = horizontal and Vector3.new(W * k, 0.02, 0.02) or Vector3.new(0.02, H * k, 0.02)
			edges[i].CFrame = cf * CFrame.new(c[1] * W * k / 2, c[2] * H * k / 2, -0.01)
			edges[i].Transparency = 0.25 + 0.75 * fade
		end
		local click = ft >= 5.3 and math.max(0, 1 - (ft - 5.3) / 0.35) or 0
		for _, r in ipairs(runes) do
			local x, y = r.x, r.y
			if r == dragged then
				-- slides from its spot in the top row down into the bottom row's far end, slowly
				local d = e(3.3, 4.8)
				x = x + (0.36 - x) * d
				y = y + (-0.11 - y) * d
			end
			local flick = (ft > 2.6 and ft < 5.2 and math.random() < 0.04) and 0.6 or 0
			r.part.Size = Vector3.one * (0.07 + click * 0.04) * scale * k
			r.part.CFrame = cf * CFrame.new(x * scale * k, y * scale * k, -0.02) * CFrame.Angles(0, 0, math.rad(45))
			r.part.Transparency = math.min(1, 0.1 + flick + 0.9 * fade)
		end
		-- the confirm ring
		local rf = (ft - 5.3) / 0.6
		for _, sg in ipairs(ring) do
			if rf > 0 and rf < 1 then
				local radius = (0.3 + 0.6 * rf) * scale
				sg.part.Size = Vector3.new(2 * radius * math.sin(math.pi / 16) * 0.85, 0.025 * scale, 0.02)
				sg.part.CFrame = cf * CFrame.Angles(0, 0, sg.a) * CFrame.new(radius, 0, -0.03) * CFrame.Angles(0, 0, math.pi / 2)
				sg.part.Transparency = rf
			else
				sg.part.Transparency = 1
			end
		end
	end
end

-- The transmitter (6.6 .. end): a spire grows out of the drone's top spike; from 7.3 the core charges (a swelling
-- glow); at 8.6 a thin beam shoots straight up into the sky and transmission rings rise after it.
local PULSE_AT = 9.0
local function transmitter(folder, malak, scale)
	local droneRoot = malak:FindFirstChild("DroneRoot", true)
	local core = malak:FindFirstChild("DroneCore", true)
	local spire = newPart(folder, Vector3.new(0.09, 0.1, 0.09) * scale, Color3.fromRGB(176, 180, 196), 1)
	spire.Material = Enum.Material.SmoothPlastic
	spire.Reflectance = 0.3
	local spireTip = newPart(folder, Vector3.one * 0.12 * scale, GLOW_CORE, 1)
	local charge = newPart(folder, Vector3.one, GLOW_CORE, 1, Enum.PartType.Ball)
	local chargeHalo = newPart(folder, Vector3.one, GLOW, 1, Enum.PartType.Ball)
	local light = Instance.new("PointLight")
	light.Color = GLOW
	light.Range = 10
	light.Brightness = 0
	light.Shadows = false
	light.Parent = charge
	local beam = newPart(folder, Vector3.new(0.25, 1, 0.25), GLOW_CORE, 1)
	local beamGlow = newPart(folder, Vector3.new(0.9, 1, 0.9), GLOW, 1)
	local rings = {}
	for i = 0, 5 do
		local segs = {}
		for k = 0, 13 do
			table.insert(segs, { part = newPart(folder, Vector3.new(0.4, 0.08, 0.08), i % 2 == 0 and GLOW_CORE or GLOW, 1), a = k / 14 * math.pi * 2 })
		end
		table.insert(rings, { segs = segs, at = PULSE_AT + i * 0.3 })
	end
	local BEAM_LEN = 720 * SKY_SCALE -- (up past the height of the tear)
	return function(ft)
		if not droneRoot or not droneRoot.Parent then
			return
		end
		local function e(a, b)
			local x = math.clamp((ft - a) / (b - a), 0, 1)
			return x * x * (3 - 2 * x)
		end
		local top = droneRoot.Position + Vector3.new(0, 1.15 * scale, 0)
		-- the spire
		local grow = e(6.6, 7.6) * (1 - e(50.4, 51.8)) * 2.6 * scale -- (back in when the drone unfolds)
		spire.Size = Vector3.new(0.09 * scale, math.max(0.05, grow), 0.09 * scale)
		spire.CFrame = CFrame.new(top + Vector3.new(0, grow / 2, 0))
		spire.Transparency = grow > 0.06 and 0 or 1
		spireTip.CFrame = CFrame.new(top + Vector3.new(0, grow, 0)) * CFrame.Angles(math.rad(45), math.rad(45), 0)
		spireTip.Transparency = grow > 0.06 and 0 or 1
		-- the core charging, then the flash of the pulse
		local c = core and core.Position or droneRoot.Position
		local ch = e(7.3, PULSE_AT)
		local after = ft >= PULSE_AT and math.max(0, 1 - (ft - PULSE_AT) / 0.5) or 0
		local size = (0.2 + 0.28 * ch + after * 0.6) * scale
		charge.Size = Vector3.one * size
		chargeHalo.Size = Vector3.one * size * 1.6
		charge.CFrame, chargeHalo.CFrame = CFrame.new(c), CFrame.new(c)
		local lit = ch > 0 and (ft < PULSE_AT + 0.5) and 1 or 0
		charge.Transparency = lit == 1 and (0.2 - 0.2 * after) or 1
		chargeHalo.Transparency = lit == 1 and (0.7 - 0.3 * after) or 1
		light.Brightness = lit * (1 + 3 * ch + 4 * after)
		-- the beam: shoots up in 0.15 s, burns, thins and fades out by 9.8
		local bt = ft - PULSE_AT
		local tipTop = top + Vector3.new(0, grow, 0)
		if bt > 0 and bt < 2.2 then
			local len = BEAM_LEN * math.min(1, bt / 0.25)
			local thin = 1 - math.clamp((bt - 1.0) / 1.2, 0, 1)
			beam.Size = Vector3.new(0.25 * scale * thin + 0.02, len, 0.25 * scale * thin + 0.02)
			beamGlow.Size = Vector3.new(0.9 * scale * thin + 0.05, len, 0.9 * scale * thin + 0.05)
			beam.CFrame = CFrame.new(tipTop + Vector3.new(0, len / 2, 0))
			beamGlow.CFrame = beam.CFrame
			beam.Transparency = 0
			beamGlow.Transparency = 0.55 + 0.45 * (1 - thin)
		else
			beam.Transparency, beamGlow.Transparency = 1, 1
		end
		-- transmission rings rising after it, widening and fading
		for _, r in ipairs(rings) do
			local rt = ft - r.at
			for _, sg in ipairs(r.segs) do
				if rt > 0 and rt < 2.2 then
					local f = rt / 2.2
					local radius = (0.6 + 4.5 * f) * scale
					local y = 1.5 * scale + 22 * rt
					sg.part.Size = Vector3.new(2 * radius * math.sin(math.pi / 14) * 0.85, 0.08 * scale, 0.08 * scale)
					sg.part.CFrame = CFrame.new(tipTop + Vector3.new(0, y, 0)) * CFrame.Angles(0, sg.a, 0) * CFrame.new(radius, 0, 0) * CFrame.Angles(0, math.pi / 2, 0)
					sg.part.Transparency = 0.1 + 0.9 * f
				else
					sg.part.Transparency = 1
				end
			end
		end
	end
end

-- ============================================================
-- Step 3: the sky tears (13 .. 19) and the warp-in (19 .. 28)
-- ============================================================
local TEAR_AT = 13
local RING_AT = 14.2 -- the rune ring starts to etch itself
local CRACKS_AT = 15.2
local OPEN_AT = 17.4 -- the inside tears open into the void
local WARP_AT = 19
local EMERGE_FROM = 20 -- the bow touches the portal ...
local EMERGE_TO = 29.5 -- ... and the stern clears it (slow and ominous)
local SNAP_AT = 29.8 -- the portal snaps shut
local PORTAL_RADIUS = 190 * SKY_SCALE -- (big: it opens far away)
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local VOID = Color3.fromRGB(14, 10, 30)
local VORTEX = Color3.fromRGB(70, 56, 110)

local function ringPoint(frame, radius, a)
	return (frame * CFrame.Angles(0, 0, a) * CFrame.new(radius, 0, 0)).Position
end

-- The tear: a local darkening of the world, a vortex of smoke spiralling in, the rune ring etching itself, cracks of
-- light spreading from it, the void opening inside; at the warp-in the void flares, then the portal snaps shut and
-- a shockwave rolls out. `portal` is a CFrame at the portal's centre whose LookVector is the ship's way out.
local function skyTear(folder, portal)
	local Lighting = game:GetService("Lighting")
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "FleetStrikeDark"
	cc.Parent = Lighting
	-- the map's haze would wash the ship out at that height: it thins for the cutscene (only on this screen)
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	local savedDensity = atmosphere and atmosphere.Density
	local savedHaze = atmosphere and atmosphere.Haze
	local face = portal * CFrame.Angles(0, math.pi, 0) -- (faces back along the way out: towards the camera side)

	-- the vortex: smoke emitters circling the portal, spiralling inwards (their smoke stays behind: spiral streaks)
	local swirl = {}
	for i = 1, 14 do
		local p = newPart(folder, Vector3.one, VORTEX, 1)
		local em = Instance.new("ParticleEmitter")
		em.Texture = SMOKE
		em.Color = ColorSequence.new(VORTEX, Color3.fromRGB(30, 24, 52))
		em.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 28 * SKY_SCALE), NumberSequenceKeypoint.new(1, 60 * SKY_SCALE) })
		em.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) })
		em.Lifetime = NumberRange.new(2, 3)
		em.Speed = NumberRange.new(0, 2 * SKY_SCALE)
		em.Rate = 0
		em.LightInfluence = 0.3
		em.Rotation = NumberRange.new(0, 360)
		em.RotSpeed = NumberRange.new(-20, 20)
		em.Parent = p
		table.insert(swirl, { part = p, em = em, a = i / 14 * math.pi * 2, r = (420 + (i % 3) * 50) * SKY_SCALE })
	end
	-- the rune ring: an outer band of segments that etch themselves one after another, an inner counter-turning ring,
	-- rune marks outside the band
	local N = 64
	local band, inner, marks = {}, {}, {}
	for k = 0, N - 1 do
		table.insert(band, newPart(folder, Vector3.new(1, 4, 2.4) * SKY_SCALE, GLOW, 1))
		if k % 2 == 0 then
			table.insert(inner, newPart(folder, Vector3.new(1, 2.2, 1.6) * SKY_SCALE, GLOW_CORE, 1))
		end
		if k % 4 == 0 then
			table.insert(marks, newPart(folder, Vector3.new(7, 7, 1.6) * SKY_SCALE, GLOW, 1))
		end
	end
	-- the cracks: jagged lines of light growing outwards from the ring
	local cracks = {}
	for c = 1, 12 do
		local a = c / 12 * math.pi * 2 + (c % 3) * 0.13
		local pts = { ringPoint(face, PORTAL_RADIUS + 3 * SKY_SCALE, a) }
		local dir = a
		for j = 1, 4 do
			dir += (math.random() - 0.5) * 0.7
			local len = (30 + math.random() * 40) * SKY_SCALE
			local prev = pts[#pts]
			local out = (face * CFrame.Angles(0, 0, dir) * CFrame.new(len, 0, 0)).Position - face.Position
			table.insert(pts, prev + out)
		end
		local segs = {}
		for j = 1, #pts - 1 do
			table.insert(segs, { part = newPart(folder, Vector3.new(2.4, 2.4, 1), GLOW_CORE, 1), a = pts[j], b = pts[j + 1] })
		end
		table.insert(cracks, { segs = segs, delay = (c % 4) * 0.5 })
	end
	-- the void inside the ring, its glowing rim, the light pouring out at the warp-in
	local void = newPart(folder, Vector3.new(0.5, 1, 1), VOID, 1, Enum.PartType.Cylinder)
	-- (Neon: not lit by lamps. As SmoothPlastic, close up it caught the edge of the area round the camera in which lights
	-- are computed: a lit half circle with a hard straight edge. At this near-black colour Neon stays dark.)
	void.Material = Enum.Material.Neon
	local voidGlow = newPart(folder, Vector3.new(0.4, 1, 1), GLOW, 1, Enum.PartType.Cylinder)
	local voidLight = Instance.new("PointLight")
	voidLight.Color = GLOW
	voidLight.Range = 120 * SKY_SCALE
	voidLight.Brightness = 0
	voidLight.Shadows = false
	voidLight.Parent = voidGlow
	-- the shockwave when it snaps shut
	local shock = {}
	for k = 0, 39 do
		table.insert(shock, { part = newPart(folder, Vector3.new(1, 3, 3), GLOW_CORE, 1), a = k / 40 * math.pi * 2 })
	end

	return function(T)
		local function e(a, b)
			local x = math.clamp((T - a) / (b - a), 0, 1)
			return x * x * (3 - 2 * x)
		end
		local snapped = T >= SNAP_AT
		local snap = snapped and math.clamp((T - SNAP_AT) / 0.35, 0, 1) or 0 -- (the ring collapsing inwards)
		local alive = T >= TEAR_AT and snap < 1
		-- the darkening (eases back after the portal closes)
		local dark = e(TEAR_AT, TEAR_AT + 3) * (1 - e(SNAP_AT + 0.5, SNAP_AT + 4))
		cc.Brightness = -0.12 * dark
		cc.Saturation = -0.35 * dark
		cc.TintColor = Color3.new(1, 1, 1):Lerp(Color3.fromRGB(205, 210, 255), dark)
		if atmosphere then
			local thin = e(TEAR_AT, TEAR_AT + 3)
			atmosphere.Density = savedDensity + (math.min(savedDensity, 0.08) - savedDensity) * thin
			atmosphere.Haze = savedHaze + (math.min(savedHaze, 0.2) - savedHaze) * thin
		end
		-- the vortex
		local sw = e(TEAR_AT, TEAR_AT + 2) * (1 - e(SNAP_AT, SNAP_AT + 1))
		for i, s in ipairs(swirl) do
			local spin = (T - TEAR_AT) * 0.35
			local r = s.r * (1 - 0.45 * e(TEAR_AT, WARP_AT))
			s.part.CFrame = CFrame.new(ringPoint(face, r, s.a + spin))
			s.em.Rate = sw * 6
		end
		-- the rune ring etching itself (and spinning slowly), collapsing at the snap
		local etched = e(RING_AT, RING_AT + 2.6)
		local ringR = PORTAL_RADIUS * (1 - snap)
		local turn = (T - RING_AT) * 0.06
		for k, p in ipairs(band) do
			local a = (k - 0.5) / N * math.pi * 2 + turn
			local on = alive and (k / N) <= etched
			local seg = 2 * ringR * math.sin(math.pi / N) * 0.92
			p.Size = Vector3.new(math.max(0.1, seg), 4 * SKY_SCALE, 2.4 * SKY_SCALE)
			p.CFrame = face * CFrame.Angles(0, 0, a) * CFrame.new(ringR, 0, 0) * CFrame.Angles(0, 0, math.pi / 2)
			p.Transparency = on and (T > OPEN_AT and 0 or 0.2) or 1
		end
		for k, p in ipairs(inner) do
			local a = (k - 0.5) / #inner * math.pi * 2 - turn * 2.5
			local r = ringR * 0.9
			p.Size = Vector3.new(math.max(0.1, 2 * r * math.sin(math.pi / #inner) * 0.6), 2.2 * SKY_SCALE, 1.6 * SKY_SCALE)
			p.CFrame = face * CFrame.Angles(0, 0, a) * CFrame.new(r, 0, 0) * CFrame.Angles(0, 0, math.pi / 2)
			p.Transparency = (alive and etched >= 1) and 0.3 or 1
		end
		for k, p in ipairs(marks) do
			local a = (k - 0.5) / #marks * math.pi * 2 + turn
			p.CFrame = face * CFrame.Angles(0, 0, a) * CFrame.new(ringR + 10 * SKY_SCALE, 0, 0) * CFrame.Angles(0, 0, math.rad(45))
			p.Transparency = (alive and (k / #marks) <= etched) and 0.15 or 1
		end
		-- the cracks of light
		for _, c in ipairs(cracks) do
			local grow = e(CRACKS_AT + c.delay, CRACKS_AT + c.delay + 2.2)
			local n = #c.segs
			for j, sgm in ipairs(c.segs) do
				local f = math.clamp(grow * n - (j - 1), 0, 1)
				local b = sgm.a:Lerp(sgm.b, math.max(0.02, f))
				sgm.part.Size = Vector3.new((2.6 - j * 0.45) * SKY_SCALE, (2.6 - j * 0.45) * SKY_SCALE, (b - sgm.a).Magnitude)
				sgm.part.CFrame = CFrame.lookAt((sgm.a + b) / 2, b)
				local flick = math.random() < 0.08 and 0.5 or 0
				sgm.part.Transparency = (alive and f > 0) and math.min(1, 0.05 + flick + 0.9 * e(WARP_AT + 1, SNAP_AT)) or 1
			end
		end
		-- the void and the light pouring out of it
		local open = e(OPEN_AT, WARP_AT) * (1 - snap)
		local voidR = ringR * 2 * open
		void.Size = Vector3.new(0.5, math.max(0.1, voidR * 0.98), math.max(0.1, voidR * 0.98))
		void.CFrame = face * CFrame.new(0, 0, 0.6) * CFrame.Angles(0, math.pi / 2, 0)
		void.Transparency = open > 0.01 and 0.05 or 1
		local flare = e(WARP_AT, EMERGE_FROM) * (1 - e(EMERGE_TO - 1, SNAP_AT))
		voidGlow.Size = Vector3.new(0.4, math.max(0.1, voidR * 0.9), math.max(0.1, voidR * 0.9))
		voidGlow.CFrame = face * CFrame.new(0, 0, 0.3) * CFrame.Angles(0, math.pi / 2, 0)
		voidGlow.Transparency = open > 0.01 and (0.85 - 0.6 * flare + math.sin(T * 6) * 0.04) or 1
		voidLight.Brightness = open * (1 + 4 * flare)
		-- the shockwave rolling out when it snaps shut
		local sf = (T - SNAP_AT - 0.2) / 1.6
		for _, s in ipairs(shock) do
			if sf > 0 and sf < 1 then
				local r = (20 + 420 * (1 - (1 - sf) ^ 3)) * SKY_SCALE
				s.part.Size = Vector3.new(2 * r * math.sin(math.pi / 40) * 0.9, (3 * (1 - sf) + 0.3) * SKY_SCALE, 3 * SKY_SCALE)
				s.part.CFrame = face * CFrame.Angles(0, 0, s.a) * CFrame.new(r, 0, 0) * CFrame.Angles(0, 0, math.pi / 2)
				s.part.Transparency = 0.2 + 0.8 * sf
			else
				s.part.Transparency = 1
			end
		end
	end, function()
		cc:Destroy()
		if atmosphere then
			atmosphere.Density = savedDensity
			atmosphere.Haze = savedHaze
		end
	end
end

-- The warp-in: the Absolution slides out of the portal, bow first, slowly, decelerating; every part still behind the
-- portal's plane is hidden (LocalTransparencyModifier), so it really comes out of it. After the snap its window
-- lights come on from bow to stern.
-- After the barrage the ship turns, slowly and heavily, until its nose points (almost) at the keeper: so the beam
-- leaves the bow instead of crossing the hull, and the player looks into the opened bow and the cannon.
local TURN_FROM, TURN_TO = 41.6, 44.4
local TURN_SHARE = 0.9 -- (of the way; the cannon's swivel does the rest)
local TURN_MAX_PITCH = math.rad(25) -- (the nose dips at most this much)

local function warpIn(folder, portal, shipFinal, ctx)
	local template = game:GetService("ReplicatedStorage"):FindFirstChild("ShipModels")
	template = template and template:FindFirstChild("Absolution")
	if not template then
		warn("FleetStrike: ReplicatedStorage.ShipModels.Absolution is missing")
		return function() end, function() end
	end
	local ship = template:Clone()
	ship:ScaleTo(ship:GetScale() * SHIP_SCALE)
	-- (ScaleTo leaves the lights' ranges alone: at full reach the bow light lit up the portal's dark void)
	for _, d in ipairs(ship:GetDescendants()) do
		if d:IsA("Light") then
			d.Range *= SHIP_SCALE
		end
	end
	ship.PrimaryPart.Anchored = true
	ship:PivotTo(CFrame.new(0, -5000, 0))
	ship.Parent = folder
	local parts = {}
	local windows = {}
	for _, d in ipairs(ship:GetDescendants()) do
		if d:IsA("BasePart") then
			table.insert(parts, { part = d, hidden = false })
			if d.Name == "Window" then
				-- (dark until the lights run down the hull; its place along the hull, 0 = bow .. 1 = stern)
				local z = (ship.PrimaryPart.CFrame:PointToObjectSpace(d.Position)).Z
				table.insert(windows, { part = d, base = d.Transparency, along = math.clamp((z + 140 * SHIP_SCALE) / (280 * SHIP_SCALE), 0, 1) })
				d.Transparency = 1
			end
		end
	end
	-- the reactor: the three rings turn slowly on their own axes (their joints spin round the hinge's Y: in the ring's
	-- own plane), the core and its halo pulse; step 5 spins them up and locks them into line for the main cannon
	local rings = {}
	for i, name in ipairs({ "RingA", "RingB", "RingC" }) do
		local j = ship:FindFirstChild(name, true)
		if j and j:IsA("Motor6D") then
			table.insert(rings, { joint = j, speed = ({ 0.12, -0.18, 0.3 })[i] })
		end
	end
	local core = ship:FindFirstChild("Core", true)
	local coreHalo = ship:FindFirstChild("CoreHalo", true)
	local coreSize = core and core.Size
	local haloSize = coreHalo and coreHalo.Size
	local haloBase = coreHalo and coreHalo.Transparency
	local axis = shipFinal.LookVector
	-- the bow tip sits ~225 studs (x SHIP_SCALE) ahead of the core, the stern ~210 behind: from "bow touching the portal" to "stern
	-- just clear of it"
	local startCF = shipFinal - axis * (portal.Position - shipFinal.Position):Dot(-axis) - axis * 225 * SHIP_SCALE
	local travel = (shipFinal.Position - startCF.Position).Magnitude
	return function(T)
		if T < EMERGE_FROM - 0.2 then
			return
		end
		local u = math.clamp((T - EMERGE_FROM) / (EMERGE_TO - EMERGE_FROM), 0, 1)
		local s = u < 0.15 and (u / 0.15) ^ 2 * 0.075 or 0.075 + (1 - (1 - (u - 0.15) / 0.85) ^ 1.5) * 0.925 -- (eases in, keeps coming slowly, settles gently)
		local cf = startCF + axis * travel * s
		local turn = smooth((T - TURN_FROM) / (TURN_TO - TURN_FROM))
		if turn > 0 and ctx.keeper then
			local to = ctx.keeper - cf.Position
			local flat = Vector3.new(to.X, 0, to.Z)
			local pitch = math.min(math.atan2(-to.Y, flat.Magnitude), TURN_MAX_PITCH)
			local dir = flat.Unit * math.cos(pitch) - Vector3.new(0, math.sin(pitch), 0)
			cf = cf:Lerp(CFrame.lookAt(cf.Position, cf.Position + dir), turn * TURN_SHARE)
		end
		ship:PivotTo(cf)
		ctx.bow = (cf * CFrame.new(0, 0, -215 * SHIP_SCALE)).Position -- (the camera follows the bow round)
		-- (ctx.spinT / ctx.windowRun: SovereignArrival holds the ship still on this clock, but its rings keep turning)
		local spinT = ctx.spinT or T
		for _, r in ipairs(rings) do
			r.joint.Transform = CFrame.Angles(0, spinT * r.speed, 0)
		end
		if core then
			local pulse = 0.5 + 0.5 * math.sin(spinT * 1.6)
			core.Size = coreSize * (0.96 + 0.06 * pulse)
			coreHalo.Size = haloSize * (0.94 + 0.12 * pulse)
			coreHalo.Transparency = haloBase + 0.08 * (1 - pulse)
		end
		-- hide what is still behind the portal
		local pp = portal.Position
		local behindCheck = T < SNAP_AT + 0.5
		for _, p in ipairs(parts) do
			local behind = behindCheck and (p.part.Position - pp):Dot(axis) < 0
			if behind ~= p.hidden then
				p.hidden = behind
				p.part.LocalTransparencyModifier = behind and 1 or 0
			end
		end
		-- the window lights running from bow to stern after the snap
		local run = ctx.windowRun or (T - SNAP_AT - 0.3) / 1.6
		for _, w in ipairs(windows) do
			if run >= w.along then
				w.part.Transparency = w.base
			end
		end
	end, function()
		ship:Destroy()
	end
end

-- ============================================================
-- Step 4: scanning (31 .. 36) and the barrage (36 .. 40)
-- ============================================================
local TURRETS_FROM = 31.3 -- the turrets turn to the gate one after another
local TURRET_STAGGER = 0.14
local TURRET_TURN = 1.4
local FAN_FROM, FAN_TO = 32.0, 35.6 -- the red scan fan sweeps the gate
local LOCKS = { 33.9, 34.3, 34.7, 35.1, 35.5 } -- the reticles locking on, one by one
local BARRAGE_AT = 38 -- (the camera is back on the ship first: the first salvo is seen leaving the guns)
local BARRAGE_END = 42
local SALVO_EVERY = 0.55 -- a main turret fires every ... s (they take turns)
local TRACERS_PER_SECOND = 26
local MISSILES = 12
local SHELL_SPEED = 900 * SKY_SCALE -- (the same flight times as at full size)
local RED = Color3.fromRGB(255, 40, 40)
local RED_CORE = Color3.fromRGB(255, 190, 180)
local HOT = Color3.fromRGB(255, 196, 120)
local FIRE = Color3.fromRGB(255, 110, 40)
local SPARK = "rbxasset://textures/particles/sparkles_main.dds"

-- a point spread over the gate's face (lateral -1..1, height 0..1), a little in front of it
local function gatePoint(ctx, lx, hy)
	return ctx.gate + ctx.M.RightVector * (lx * 13) + Vector3.new(0, -3 + hy * 16, 0) - ctx.M.LookVector * 0.8
end

-- an explosion on the gate: flash, fireball, sparks, a puff of smoke (size k)
local function blast(folder, active, pos, k, color)
	local flash = newPart(folder, Vector3.one, Color3.new(1, 1, 1), 0, Enum.PartType.Ball)
	flash.CFrame = CFrame.new(pos)
	local ball = newPart(folder, Vector3.one, color or FIRE, 0.2, Enum.PartType.Ball)
	ball.CFrame = CFrame.new(pos)
	local em = Instance.new("ParticleEmitter")
	em.Texture = SPARK
	em.Color = ColorSequence.new(Color3.new(1, 1, 1), HOT)
	em.LightEmission = 1
	em.Size = NumberSequence.new(0.4 * k, 0)
	em.Lifetime = NumberRange.new(0.3, 0.7)
	em.Speed = NumberRange.new(20 * k, 40 * k)
	em.SpreadAngle = Vector2.new(180, 180)
	em.Acceleration = Vector3.new(0, -40, 0)
	em.Enabled = false
	em.Parent = flash
	em:Emit(math.floor(12 * k))
	local t0 = os.clock()
	table.insert(active, function(now)
		local f = (now - t0) / 0.6
		if f >= 1 then
			flash:Destroy()
			ball:Destroy()
			return false
		end
		flash.Size = Vector3.one * (1 + 6 * k * math.min(1, f * 5))
		flash.Transparency = math.min(1, f * 3)
		ball.Size = Vector3.one * (2 + 5 * k * f)
		ball.Transparency = 0.2 + 0.8 * f
		return true
	end)
end

-- an explosion's sound where a shell or missile hits the gate (his basic attack's impact, a little lower: far away);
-- the hits come in bunches, so at most one every 0.12 s. ctx.soundLoud is set by the soundtrack (watching or not).
local lastBoom = 0
local function boom(ctx, volume)
	local now = os.clock()
	if now - lastBoom < 0.12 then
		return
	end
	lastBoom = now
	Sfx.play("shell_impact", nil, (ctx.soundLoud or 0.35) * volume, 0.8 + math.random() * 0.2)
end

-- a projectile from `from` to `to` in `flight` s: a glowing head and a trail; calls onHit at the end
local function projectile(folder, active, from, to, flight, size, color, onHit, curve)
	local head = newPart(folder, Vector3.new(size, size, size * 4), color, 0)
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, size * 0.4, size * 2)
	a0.Parent = head
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -size * 0.4, size * 2)
	a1.Parent = head
	local trail = Instance.new("Trail")
	trail.Attachment0, trail.Attachment1 = a0, a1
	trail.Color = ColorSequence.new(Color3.new(1, 1, 1), color)
	trail.LightEmission = 1
	trail.FaceCamera = true
	trail.Lifetime = 0.18
	trail.Transparency = NumberSequence.new(0.1, 1)
	trail.Enabled = false
	trail.Parent = head
	head.CFrame = CFrame.lookAt(from, to)
	local t0 = os.clock()
	local last = from
	table.insert(active, function(now)
		local f = (now - t0) / flight
		if f >= 1 then
			head:Destroy()
			if onHit then onHit() end
			return false
		end
		local p = from:Lerp(to, f)
		if curve then
			p = curve(f)
		end
		if (p - last).Magnitude > 0.01 then
			head.CFrame = CFrame.lookAt(p, p + (p - last))
		end
		last = p
		trail.Enabled = true
		return true
	end)
end

local function barrage(folder, ctx)
	local active = {}
	local ship -- (the warp-in's clone, found on the first frame it exists)
	local turrets = {} -- { joint, guns, order }
	local mainMuzzles = {} -- MainBrake parts (main turrets)
	local secondaryMuzzles = {} -- TurretMuzzle / TurretBarrel parts (secondaries)
	local finTips = {} -- missile launch points
	local nextSalvo, salvoIndex = BARRAGE_AT, 0
	local tracerDebt = 0
	local missileLaunched = 0
	local lastT
	-- the red scan fan: lines from the bow to a sweeping row across the gate
	local fan = {}
	for i = 1, 14 do
		table.insert(fan, newPart(folder, Vector3.new(0.18, 0.18, 1), RED, 1))
	end
	-- where the fan touches the gate: a bright red scan line across its face
	local scanLine = newPart(folder, Vector3.new(30, 0.35, 0.2), RED_CORE, 1)
	local scanGlow = newPart(folder, Vector3.new(31, 1.4, 0.15), RED, 1)
	-- the reticles that lock onto the gate
	local reticles = {}
	for i, at in ipairs(LOCKS) do
		local segs = {}
		for k = 0, 9 do
			table.insert(segs, { part = newPart(folder, Vector3.new(1, 0.25, 0.15), RED, 1), a = k / 10 * math.pi * 2 })
		end
		table.insert(reticles, { at = at, segs = segs, lx = ({ -0.6, 0.45, -0.15, 0.7, 0.05 })[i], hy = ({ 0.55, 0.75, 0.3, 0.4, 0.85 })[i] })
	end
	-- fire and smoke building on the gate during the barrage
	local burns = {}
	for i = 1, 5 do
		local p = newPart(folder, Vector3.one, FIRE, 1)
		p.CFrame = CFrame.new(gatePoint(ctx, (i - 3) * 0.42, 0.25 + (i % 3) * 0.25))
		local fireEm = Instance.new("ParticleEmitter")
		fireEm.Texture = SMOKE
		fireEm.Color = ColorSequence.new(HOT, FIRE)
		fireEm.LightEmission = 0.8
		fireEm.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 5) })
		fireEm.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
		fireEm.Lifetime = NumberRange.new(0.5, 0.9)
		fireEm.Speed = NumberRange.new(4, 8)
		fireEm.Acceleration = Vector3.new(0, 8, 0)
		fireEm.Rate = 0
		fireEm.Parent = p
		local smokeEm = Instance.new("ParticleEmitter")
		smokeEm.Texture = SMOKE
		smokeEm.Color = ColorSequence.new(Color3.fromRGB(30, 26, 30), Color3.fromRGB(70, 64, 66))
		smokeEm.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 4), NumberSequenceKeypoint.new(1, 14) })
		smokeEm.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1) })
		smokeEm.Lifetime = NumberRange.new(2.5, 4)
		smokeEm.Speed = NumberRange.new(4, 9)
		smokeEm.Acceleration = Vector3.new(0, 5, 0)
		smokeEm.Rotation = NumberRange.new(0, 360)
		smokeEm.RotSpeed = NumberRange.new(-30, 30)
		smokeEm.Rate = 0
		smokeEm.Parent = p
		table.insert(burns, { fire = fireEm, smoke = smokeEm })
	end

	local function findShip()
		ship = folder:FindFirstChild("Absolution")
		if not ship then return end
		local order = 0
		for _, d in ipairs(ship:GetDescendants()) do
			if d:IsA("Motor6D") and d.Name:match("^Turret%d+$") then
				order += 1
				local guns = ship:FindFirstChild(d.Name .. "Guns", true)
				table.insert(turrets, { joint = d, guns = guns, order = order })
			elseif d:IsA("BasePart") then
				if d.Name == "MainBrake" then
					table.insert(mainMuzzles, d)
				elseif d.Name == "TurretMuzzle" or d.Name == "TurretBarrel" then
					table.insert(secondaryMuzzles, d)
				elseif d.Name:match("^FinTip") or d.Name:match("^Fin%dTip$") then
					table.insert(finTips, d)
				end
			end
		end
		table.sort(turrets, function(a, b)
			return tonumber(a.joint.Name:match("%d+")) < tonumber(b.joint.Name:match("%d+"))
		end)
	end

	-- the yaw (and gun elevation) that points a turret at the gate, from its joint's frame
	local function aimTurret(t, w)
		local j = t.joint
		local base = j.Part0.CFrame * j.C0
		local lp = base:PointToObjectSpace(ctx.gate)
		local yaw = math.atan2(-lp.X, -lp.Z)
		j.Transform = CFrame.Angles(0, yaw * w, 0)
		if t.guns then
			local g = t.guns
			local gunsBase = base * CFrame.Angles(0, yaw * w, 0) * g.C0
			local gp = gunsBase:PointToObjectSpace(ctx.gate)
			local pitch = math.atan2(gp.Y, -gp.Z)
			g.Transform = CFrame.Angles(math.clamp(pitch, -0.6, 0.9) * w, 0, 0)
		end
	end

	local shake = 0
	ctx.barrageShake = function()
		return shake
	end

	return function(T)
		local now = os.clock()
		local dt = lastT and math.max(0, T - lastT) or 0
		lastT = T
		if not ship and T >= TURRETS_FROM - 1 then
			findShip()
		end
		-- the turrets turning to the gate, one after another (they hold their aim afterwards)
		if ship and T >= TURRETS_FROM then
			for _, t in ipairs(turrets) do
				local w = smooth((T - TURRETS_FROM - (t.order - 1) * TURRET_STAGGER) / TURRET_TURN)
				aimTurret(t, w)
			end
		end
		-- the scan fan: from the bow over the gate, sweeping down and up twice
		local bow = ship and ship.PrimaryPart and (ship.PrimaryPart.CFrame * CFrame.new(0, 0, -200 * SHIP_SCALE)).Position
		local fanOn = bow and T >= FAN_FROM and T < FAN_TO
		local sweep = fanOn and (0.5 - 0.5 * math.cos((T - FAN_FROM) / (FAN_TO - FAN_FROM) * math.pi * 4)) or 0
		for i, p in ipairs(fan) do
			if fanOn then
				local target = gatePoint(ctx, -1.1 + (i - 1) / (#fan - 1) * 2.2, sweep)
				local len = (target - bow).Magnitude
				p.Size = Vector3.new(0.18, 0.18, len)
				p.CFrame = CFrame.lookAt(bow, target) * CFrame.new(0, 0, -len / 2)
				p.Transparency = 0.6 + math.random() * 0.15
			else
				p.Transparency = 1
			end
		end
		if fanOn then
			local mid = gatePoint(ctx, 0, sweep)
			local cf = CFrame.lookAt(mid, mid - ctx.M.LookVector)
			scanLine.CFrame, scanGlow.CFrame = cf, cf
			scanLine.Transparency = 0.05
			scanGlow.Transparency = 0.55 + math.random() * 0.1
		else
			scanLine.Transparency, scanGlow.Transparency = 1, 1
		end
		-- the reticles: each closes in and locks at its time, holds red through the barrage
		for _, r in ipairs(reticles) do
			local center = gatePoint(ctx, r.lx, r.hy)
			local face = CFrame.lookAt(center, center - ctx.M.LookVector)
			local f = (T - (r.at - 0.5)) / 0.5
			local on = f > 0 and T < BARRAGE_END
			local radius = on and (2 + 4 * (1 - smooth(f))) or 2
			local flash = (T >= r.at and T < r.at + 0.2) and 1 or 0
			for _, sg in ipairs(r.segs) do
				sg.part.Size = Vector3.new(2 * radius * math.sin(math.pi / 10) * 0.7, 0.25 + flash * 0.2, 0.15)
				sg.part.CFrame = face * CFrame.Angles(0, 0, sg.a + T * (T < r.at and 2 or 0)) * CFrame.new(radius, 0, 0) * CFrame.Angles(0, 0, math.pi / 2)
				sg.part.Color = flash > 0 and RED_CORE or RED
				sg.part.Transparency = on and (T >= r.at and 0.1 or 0.4) or 1
			end
		end
		-- the barrage
		if ship and T >= BARRAGE_AT and T < BARRAGE_END then
			-- main salvos: one turret's three barrels at a time, heavy shells
			if T >= nextSalvo and #mainMuzzles > 0 then
				nextSalvo += SALVO_EVERY
				salvoIndex += 1
				for b = 0, 2 do
					local m = mainMuzzles[((salvoIndex - 1) * 3 + b) % #mainMuzzles + 1]
					local from = m.Position
					local to = gatePoint(ctx, (math.random() - 0.5) * 1.8, math.random())
					blast(folder, active, from, 1.4 * SHIP_SCALE, HOT) -- (the muzzle flash)
					projectile(folder, active, from, to, (to - from).Magnitude / SHELL_SPEED, 1.4, HOT, function()
						blast(folder, active, to, 2.2)
						boom(ctx, 0.7)
						shake = math.max(shake, 0.6)
					end)
				end
			end
			-- tracer streams from the secondaries
			tracerDebt += dt * TRACERS_PER_SECOND
			while tracerDebt >= 1 and #secondaryMuzzles > 0 do
				tracerDebt -= 1
				local m = secondaryMuzzles[math.random(1, #secondaryMuzzles)]
				local to = gatePoint(ctx, (math.random() - 0.5) * 2.2, math.random())
				projectile(folder, active, m.Position, to, (to - m.Position).Magnitude / (1400 * SKY_SCALE), 0.5, RED_CORE, function()
					if math.random() < 0.35 then
						blast(folder, active, to, 0.6, RED_CORE)
					end
				end)
			end
			-- missiles from the stern: rise out, then curve down onto the gate
			local due = math.floor(math.clamp((T - BARRAGE_AT - 0.4) / 1.6, 0, 1) * MISSILES)
			while missileLaunched < due do
				missileLaunched += 1
				local root = ship.PrimaryPart.CFrame
				local from = (root * CFrame.new(Vector3.new((missileLaunched % 2 == 0 and 1 or -1) * 30, 25, 120 + (missileLaunched % 4) * 12) * SHIP_SCALE)).Position
				local to = gatePoint(ctx, (math.random() - 0.5) * 1.8, 0.2 + math.random() * 0.7)
				local up = from + (Vector3.new(0, 90, 0) + root.RightVector * ((missileLaunched % 2 == 0) and 60 or -60)) * SHIP_SCALE
				local mid = up:Lerp(to, 0.5) + Vector3.new(0, 60 * SKY_SCALE, 0)
				local function curve(f)
					local a = from:Lerp(up, f)
					local b = up:Lerp(mid, f)
					local c = mid:Lerp(to, f)
					return a:Lerp(b, f):Lerp(b:Lerp(c, f), f)
				end
				projectile(folder, active, from, to, 2.4, 1.1, Color3.fromRGB(200, 210, 255), function()
					blast(folder, active, to, 1.8)
					boom(ctx, 0.45)
					shake = math.max(shake, 0.4)
				end, curve)
			end
		end
		-- fire and smoke building up on the gate
		local build = smooth((T - BARRAGE_AT - 0.5) / 3)
		for _, b in ipairs(burns) do
			b.fire.Rate = build * 14
			b.smoke.Rate = build * 5
		end
		shake = math.max(0, shake - dt * 2.5)
		for i = #active, 1, -1 do
			if not active[i](now) then
				table.remove(active, i)
			end
		end
	end
end

-- ============================================================
-- Step 5: the main cannon (42 .. 46), the beam (46 .. 49.4), the gate falls (49.4)
-- The keeper's side of it is HandsAnimator's FleetStrike behaviour (set locally here at the start).
-- ============================================================
local BOW_OPEN_FROM, BOW_OPEN_TO = 42.2, 43.8 -- the helmet bow's halves swing aside
local CANNON_OUT_FROM, CANNON_OUT_TO = 43.4, 44.8 -- the cannon slides out and swivels onto the keeper
local RINGS_SPIN_FROM, RINGS_LOCK_AT = 42.4, 45.0 -- the reactor rings spin up, then lock coaxial with the hull
local CHARGE_FROM = 44.4 -- light and debris pulled into the muzzle
local FIRE_AT = 46.0 -- the beam: into the keeper's raised hands and eyes ...
local SWEEP_FROM = 47.6 -- ... then dragged down the outer wall ...
local SWEEP_MID = 48.6
local GATE_HIT = 49.4 -- ... onto the gate, which falls
local BEAM_OFF = 50.3
local BOW_OPEN_ANGLE = 0.62
local CANNON_SLIDE = 30 * SHIP_SCALE
local BEAM_WIDTH = 0.6 -- (the beam's thickness: between full size and SKY_SCALE, as it ends on the keeper close by)
local WHITE = Color3.fromRGB(255, 255, 255)

local function finale(folder, ctx)
	local active = {}
	local ship, rings, bowL, bowR, cannonJ, muzzle, core, coreHalo
	local keeper, eyes = nil, {}
	local saved -- (the keeper's attributes before the cutscene: restored at the end)
	local hiddenGate = {}
	local gateDone = false
	local scorches = {}
	local lastScorch

	-- the keeper of this lane: the RealmHands model nearest the gate
	local best
	for _, m in ipairs(game:GetService("CollectionService"):GetTagged("RealmHands")) do
		local d = (m:GetPivot().Position - ctx.gate).Magnitude
		if not best or d < best then
			best, keeper = d, m
		end
	end
	if keeper then
		saved = { kind = keeper:GetAttribute("SummonKind"), at = keeper:GetAttribute("SummonAt") }
		keeper:SetAttribute("SummonKind", "FleetStrike")
		keeper:SetAttribute("SummonAt", workspace:GetServerTimeNow()) -- (the cutscene starts now: its times are his)
		for _, d in ipairs(keeper:GetDescendants()) do
			if d:IsA("BasePart") and d.Name == "Eye" then
				table.insert(eyes, d)
			end
		end
	end
	local function eyesPos()
		if #eyes == 0 then
			return keeper and keeper:GetPivot().Position + Vector3.new(0, 60, 0) or ctx.gate + Vector3.new(0, 80, 0)
		end
		local sum = Vector3.zero
		for _, e in ipairs(eyes) do
			sum += e.Position
		end
		return sum / #eyes
	end
	-- where the beam strikes first: his raised palms (between his two hands, which he holds up as a shield in front
	-- of his eyes), a little towards his eyes
	local wrists = {}
	if keeper then
		for _, name in ipairs({ "LWrist", "RWrist" }) do
			local j = keeper:FindFirstChild(name, true)
			if j and j:IsA("Motor6D") and j.Part1 then
				table.insert(wrists, j.Part1)
			end
		end
	end
	local function keeperTarget()
		if #wrists == 2 then
			local palms = (wrists[1].Position + wrists[2].Position) / 2
			return palms:Lerp(eyesPos(), 0.15)
		end
		return eyesPos() - ctx.M.LookVector * 10
	end

	local function findShip()
		ship = folder:FindFirstChild("Absolution")
		if not ship then return end
		rings = {}
		for _, name in ipairs({ "RingA", "RingB", "RingC" }) do
			local j = ship:FindFirstChild(name, true)
			if j and j:IsA("Motor6D") then
				table.insert(rings, { joint = j, angle = 0, speed = 0 })
			end
		end
		bowL = ship:FindFirstChild("BowL", true)
		bowR = ship:FindFirstChild("BowR", true)
		cannonJ = ship:FindFirstChild("Cannon", true)
		muzzle = ship:FindFirstChild("CannonCore", true)
		core = ship:FindFirstChild("Core", true)
		coreHalo = ship:FindFirstChild("CoreHalo", true)
	end

	-- the charge at the muzzle: a swelling white-blue ball, light and motes pulled in from all round
	local charge = newPart(folder, Vector3.one, WHITE, 1, Enum.PartType.Ball)
	local chargeHalo = newPart(folder, Vector3.one, GLOW, 1, Enum.PartType.Ball)
	local chargeLight = Instance.new("PointLight")
	chargeLight.Color = GLOW
	chargeLight.Range = 60 * SHIP_SCALE
	chargeLight.Brightness = 0
	chargeLight.Shadows = false
	chargeLight.Parent = charge
	local pull = Instance.new("ParticleEmitter")
	pull.Texture = SPARK
	pull.Color = ColorSequence.new(GLOW_CORE, GLOW)
	pull.LightEmission = 1
	pull.Size = NumberSequence.new(1.6 * SHIP_SCALE, 0.2 * SHIP_SCALE)
	pull.Lifetime = NumberRange.new(0.5, 0.8)
	pull.Speed = NumberRange.new(40 * SHIP_SCALE, 60 * SHIP_SCALE)
	pull.Shape = Enum.ParticleEmitterShape.Sphere
	pull.ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward
	pull.Rate = 0
	pull.Parent = charge
	-- the beam: a white core in a cold blue sheath, a flare at the muzzle, a burning spot where it strikes
	local beamCore = newPart(folder, Vector3.new(4, 4, 1), WHITE, 1)
	local beamSheath = newPart(folder, Vector3.new(10, 10, 1), GLOW, 1)
	local beamOuter = newPart(folder, Vector3.new(18, 18, 1), GLOW_DEEP, 1)
	local strike = newPart(folder, Vector3.one, WHITE, 1, Enum.PartType.Ball)
	local strikeLight = Instance.new("PointLight")
	strikeLight.Color = GLOW
	strikeLight.Range = 70
	strikeLight.Brightness = 0
	strikeLight.Shadows = false
	strikeLight.Parent = strike
	local strikeSparks = Instance.new("ParticleEmitter")
	strikeSparks.Texture = SPARK
	strikeSparks.Color = ColorSequence.new(WHITE, GLOW)
	strikeSparks.LightEmission = 1
	strikeSparks.Size = NumberSequence.new(1.2, 0)
	strikeSparks.Lifetime = NumberRange.new(0.4, 0.9)
	strikeSparks.Speed = NumberRange.new(40, 80)
	strikeSparks.SpreadAngle = Vector2.new(180, 180)
	strikeSparks.Acceleration = Vector3.new(0, -60, 0)
	strikeSparks.Rate = 0
	strikeSparks.Parent = strike

	-- the gate falling (preview: hidden on this screen only; the real break comes with the gameplay step)
	local function breakGate()
		gateDone = true
		local box = CFrame.lookAt(ctx.gate, ctx.gate + ctx.M.LookVector) * CFrame.new(0, 7, -4)
		local params = OverlapParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		local exclude = { folder }
		local char = game:GetService("Players").LocalPlayer.Character
		if char then table.insert(exclude, char) end
		for _, m in ipairs(game:GetService("CollectionService"):GetTagged("ProceduralUnit")) do
			table.insert(exclude, m)
		end
		params.FilterDescendantsInstances = exclude
		-- (preview: the gate is only hidden on this screen; for real the server breaks it at this very moment)
		for _, p in ipairs(ctx.preview and workspace:GetPartBoundsInBox(box, Vector3.new(36, 26, 12), params) or {}) do
			if p.Size.Magnitude < 80 and p.Position.Y > ctx.gate.Y - 3.2 and p.LocalTransparencyModifier < 1 then
				table.insert(hiddenGate, p)
				p.LocalTransparencyModifier = 1
			end
		end
		-- the blast and the stone thrown out of it
		for k = 1, 4 do
			blast(folder, active, ctx.gate + ctx.M.RightVector * ((k - 2.5) * 7) + Vector3.new(0, 4 + (k % 2) * 6, 0), 4.5, k % 2 == 0 and HOT or GLOW_CORE)
		end
		for k = 1, 34 do
			local size = 1 + math.random() * 2.6
			local p = newPart(folder, Vector3.new(size, size * (0.6 + math.random() * 0.6), size), Color3.fromRGB(96, 92, 100), 0)
			p.Material = Enum.Material.Slate
			local pos = ctx.gate + ctx.M.RightVector * ((math.random() - 0.5) * 30) + Vector3.new(0, math.random() * 16, 0)
			local vel = -ctx.M.LookVector * (10 + math.random() * 30) + ctx.M.LookVector * (math.random() * 20)
				+ ctx.M.RightVector * ((math.random() - 0.5) * 40) + Vector3.new(0, 18 + math.random() * 34, 0)
			local spin = Vector3.new(math.random(), math.random(), math.random()) * 6
			local t0, last = os.clock(), os.clock()
			local floorY = ctx.gate.Y - 4
			table.insert(active, function(now)
				local st = now - t0
				local dt = math.min(now - last, 1 / 20)
				last = now
				if st > 4 then
					p:Destroy()
					return false
				end
				vel += Vector3.new(0, -70, 0) * dt
				pos += vel * dt
				if pos.Y < floorY + size / 2 then
					pos = Vector3.new(pos.X, floorY + size / 2, pos.Z)
					vel = Vector3.new(vel.X * 0.5, math.abs(vel.Y) * 0.25, vel.Z * 0.5)
				end
				p.CFrame = CFrame.new(pos) * CFrame.Angles(spin.X * st, spin.Y * st, spin.Z * st)
				p.Transparency = smooth((st - 3) / 1)
				return true
			end)
		end
		local dustPart = newPart(folder, Vector3.one, WHITE, 1)
		dustPart.CFrame = CFrame.new(ctx.gate + Vector3.new(0, -2, 0))
		local dust = Instance.new("ParticleEmitter")
		dust.Texture = SMOKE
		dust.Color = ColorSequence.new(Color3.fromRGB(110, 102, 98), Color3.fromRGB(70, 64, 62))
		dust.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 6), NumberSequenceKeypoint.new(1, 18) })
		dust.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
		dust.Lifetime = NumberRange.new(2, 3.2)
		dust.Speed = NumberRange.new(20, 40)
		dust.Drag = 2.5
		dust.Shape = Enum.ParticleEmitterShape.Disc
		dust.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
		dust.EmissionDirection = Enum.NormalId.Top
		dust.Rotation = NumberRange.new(0, 360)
		dust.RotSpeed = NumberRange.new(-30, 30)
		dust.Enabled = false
		dust.Parent = dustPart
		dust:Emit(60)
	end

	local lastT
	ctx.finaleShake = 0
	return function(T)
		local now = os.clock()
		local dt = lastT and math.max(0, T - lastT) or 0
		lastT = T
		if not ship then
			if T < BOW_OPEN_FROM - 2 then return end
			findShip()
			if not ship then return end
		end
		local root = ship.PrimaryPart.CFrame
		local function e(a, b)
			return smooth((T - a) / (b - a))
		end

		-- the bow opens: the helmet's halves swing aside round their hinges at the back
		local open = e(BOW_OPEN_FROM, BOW_OPEN_TO)
		if bowL and bowR then
			bowL.Transform = CFrame.Angles(0, BOW_OPEN_ANGLE * open, 0)
			bowR.Transform = CFrame.Angles(0, -BOW_OPEN_ANGLE * open, 0)
		end

		-- the target the cannon tracks: the keeper, then the sweep down the outer wall onto the gate
		local kTarget = keeperTarget()
		local wallPoint = (keeper and keeper:GetPivot().Position or kTarget) - Vector3.new(0, 18, 0) - ctx.M.LookVector * 2
		local gatePoint = ctx.gate + Vector3.new(0, 6, 0)
		local target = kTarget
		if T >= SWEEP_FROM then
			local f1 = e(SWEEP_FROM, SWEEP_MID)
			local f2 = math.clamp((T - SWEEP_MID) / (GATE_HIT - SWEEP_MID), 0, 1) ^ 1.4
			target = kTarget:Lerp(wallPoint, f1):Lerp(gatePoint, f2)
		end

		-- the cannon: slides out of the opened bow, then swivels onto the target
		if cannonJ then
			local slide = e(CANNON_OUT_FROM, CANNON_OUT_TO)
			local base = cannonJ.Part0.CFrame * cannonJ.C0
			local localDir = base:VectorToObjectSpace((target - (base * CFrame.new(0, 0, -CANNON_SLIDE * slide)).Position).Unit)
			local aim = CFrame.lookAt(Vector3.zero, localDir)
			local swivel = e(CANNON_OUT_TO - 0.4, CANNON_OUT_TO + 0.8)
			cannonJ.Transform = CFrame.new(0, 0, -CANNON_SLIDE * slide) * CFrame.new():Lerp(aim, swivel)
		end

		-- the reactor: the rings spin up faster and faster, then lock coaxial with the hull (a target of rings round
		-- the core); the core flares with the charge
		if rings and T >= RINGS_SPIN_FROM then
			local lock = e(RINGS_LOCK_AT, RINGS_LOCK_AT + 0.6)
			for i, r in ipairs(rings) do
				r.speed = 0.3 + 7 * e(RINGS_SPIN_FROM, RINGS_LOCK_AT - 0.3)
				r.angle += dt * r.speed * (i == 2 and -1 or 1) * (1 - lock)
				local j = r.joint
				local wantY = j.C0.Rotation:Inverse() * Vector3.new(0, 0, 1) -- (the hull's axis, in the ring's frame)
				local axis = Vector3.new(0, 1, 0):Cross(wantY)
				local align = axis.Magnitude > 1e-4 and CFrame.fromAxisAngle(axis.Unit, math.acos(math.clamp(wantY.Y, -1, 1))) or CFrame.new()
				j.Transform = CFrame.new():Lerp(align, lock) * CFrame.Angles(0, r.angle, 0)
			end
		end
		if core and coreHalo and T >= CHARGE_FROM then
			local flare = e(CHARGE_FROM, FIRE_AT) * (1 - e(BEAM_OFF, BEAM_OFF + 1))
			coreHalo.Transparency = math.max(0.3, coreHalo.Transparency - 0.4 * flare)
		end

		-- the charge at the muzzle
		local mz = muzzle and muzzle.Position or (root * CFrame.new(0, 0, -200 * SHIP_SCALE)).Position
		local ch = e(CHARGE_FROM, FIRE_AT)
		local firing = T >= FIRE_AT and T < BEAM_OFF
		if T >= CHARGE_FROM and T < BEAM_OFF then
			local size = (4 + 14 * ch + (firing and 6 or 0)) * SHIP_SCALE
			charge.Size = Vector3.one * size
			chargeHalo.Size = Vector3.one * size * 1.8
			charge.CFrame, chargeHalo.CFrame = CFrame.new(mz), CFrame.new(mz)
			charge.Transparency = 0.1
			chargeHalo.Transparency = 0.6
			chargeLight.Brightness = 2 + 6 * ch
			pull.Rate = firing and 0 or 80 * ch
		else
			charge.Transparency, chargeHalo.Transparency = 1, 1
			chargeLight.Brightness = 0
			pull.Rate = 0
		end

		-- the beam
		if firing then
			local len = (target - mz).Magnitude
			local cf = CFrame.lookAt(mz, target) * CFrame.new(0, 0, -len / 2)
			local burst = BEAM_WIDTH * (1 + 0.6 * math.max(0, 1 - (T - FIRE_AT) / 0.3)) -- (it slams out wide, then settles)
			local fade = 1 - e(GATE_HIT + 0.3, BEAM_OFF)
			local flick = 0.9 + math.random() * 0.1
			beamCore.Size = Vector3.new(4 * burst * fade * flick + 0.1, 4 * burst * fade * flick + 0.1, len)
			beamSheath.Size = Vector3.new(10 * burst * fade + 0.2, 10 * burst * fade + 0.2, len)
			beamOuter.Size = Vector3.new(18 * burst * fade + 0.3, 18 * burst * fade + 0.3, len)
			beamCore.CFrame, beamSheath.CFrame, beamOuter.CFrame = cf, cf, cf
			beamCore.Transparency = 0
			beamSheath.Transparency = 0.35
			beamOuter.Transparency = 0.75
			strike.Size = Vector3.one * (8 + 6 * burst) * fade
			strike.CFrame = CFrame.new(target)
			strike.Transparency = 0.05
			strikeLight.Brightness = 6 * fade
			strikeSparks.Rate = 160 * fade
			ctx.finaleShake = math.max(ctx.finaleShake, 0.45 * fade)
			-- a glowing scar left along the sweep down the outer wall, cooling
			if T >= SWEEP_FROM and T < GATE_HIT and (not lastScorch or (target - lastScorch).Magnitude > 3) then
				local from = lastScorch or target
				local s = newPart(folder, Vector3.new(3.2, 3.2, math.max(0.5, (target - from).Magnitude)), HOT, 0)
				s.CFrame = CFrame.lookAt((from + target) / 2, target)
				table.insert(scorches, { part = s, at = now })
				lastScorch = target
			end
		else
			beamCore.Transparency, beamSheath.Transparency, beamOuter.Transparency = 1, 1, 1
			strike.Transparency = 1
			strikeLight.Brightness = 0
			strikeSparks.Rate = 0
		end
		for _, sc in ipairs(scorches) do
			local age = now - sc.at
			sc.part.Color = HOT:Lerp(Color3.fromRGB(30, 22, 20), math.clamp(age / 2.5, 0, 1))
			sc.part.Transparency = smooth((age - 3) / 2)
		end

		-- the gate falls
		if not gateDone and T >= GATE_HIT then
			breakGate()
			ctx.finaleShake = 1.2
		end
		ctx.finaleShake = math.max(0, ctx.finaleShake - dt * 0.9)
		for i = #active, 1, -1 do
			if not active[i](now) then
				table.remove(active, i)
			end
		end
	end, function()
		for _, p in ipairs(hiddenGate) do
			if p.Parent then
				p.LocalTransparencyModifier = 0
			end
		end
	end, function(comeBack)
		-- (preview) the keeper: back to what he was doing, or (after the ship has gone) out of his rifts again
		if keeper and keeper.Parent and saved then
			if comeBack then
				keeper:SetAttribute("SummonKind", "Return")
				keeper:SetAttribute("SummonAt", workspace:GetServerTimeNow())
			else
				keeper:SetAttribute("SummonKind", saved.kind)
				keeper:SetAttribute("SummonAt", saved.at)
			end
		end
	end
end

-- ============================================================
-- Step 8: sound (sounds/README.md, malak/ "The Fleet Strike"; ids in Sfx). A slot without an id stays silent.
-- Everything plays flat (a score, not from a spot in the world): full volume for whoever watches, quieter for the
-- players who only see it in the sky. `near` cues are Malak's own small sounds, only heard while watching.
-- ============================================================
local SHIP_HUM = "ship_hum" -- (two versions to compare: "ship_hum" or "ship_hum2")
local SKY_VOLUME = 0.35 -- (for players who are not watching, and for the ship lingering after the cutscene)
-- The recordings keep their original pitch and pauses. Finish the call before the drone transmits, and the
-- verdict before the half-second of silence ahead of the laser. Update these lengths if the recordings change.
local VOICE_CALL_LENGTH, VOICE_VERDICT_LENGTH = 3.38, 3.81
local VOICE_DEFIANCE_LENGTH = 2.06
local CUES = {
	{
		at = PULSE_AT - VOICE_CALL_LENGTH - 0.25, name = "voice_call", near = true, voice = true, duration = VOICE_CALL_LENGTH,
		phrases = {
			{ at = 0, text = "HIGH COMMAND. ", reveal = 0.9 },
			{ at = 2.0, text = "GRANT US PASSAGE.", reveal = 1.25 },
		},
	},
	{
		at = FIRE_AT - VOICE_VERDICT_LENGTH - 0.5, name = "voice_verdict", near = true, voice = true, duration = VOICE_VERDICT_LENGTH,
		phrases = {
			{ at = 0, text = "ABSOLUTION. ", reveal = 0.95 },
			{ at = 2.1, text = "DELIVER MY VERDICT.", reveal = 1.5 },
		},
	},
	{
		at = 51, name = "voice_defiance", near = true, voice = true, duration = VOICE_DEFIANCE_LENGTH,
		phrases = {
			{ at = 0, text = "THEIR DEFIANCE ", reveal = 0.9 },
			{ at = 0.95, text = "WAS NOTED.", reveal = 0.8 },
		},
	},
	{ at = 5.3, name = "rune_confirm", near = true },
	{ at = 6.0, name = "drone_transform", near = true },
	-- the transmission: the laser into the sky (fades out by ~17 s) and the sublift hum under it, which fades out once
	-- the void opens (17.4-18.9 s)
	{ at = PULSE_AT, name = "transmit_laser" },
	{ at = PULSE_AT, name = "sublift_scanner" },
	-- the tear: the sky groans (under all of it), the cracks spread (tear_open, the sucking swell, was taken out)
	{ at = TEAR_AT, name = "tear_rumble" },
	{ at = CRACKS_AT, name = "tear_crack" },
	{ at = WARP_AT, name = "warp_in_suspense" },
	{ at = EMERGE_FROM, name = "warp_in_scanner" },
	{ at = 21.5, name = "warp_in_warhorn" },
	{ at = SNAP_AT, name = "portal_snap" },
	{ at = 32, name = "scan_sweep" },
	{ at = BOW_OPEN_FROM, name = "bow_open" }, -- (its second clunk 1.35 s in: the bow is open)
	{ at = RINGS_SPIN_FROM, name = "reactor_windup", pitch = 1.5 }, -- (4 s at 1.5x: up to the lock)
	{ at = RINGS_LOCK_AT, name = "reactor_lock" },
	-- the charge's build (4.35 s) at 1.25x, cut off at its peak half a second before the beam: the silence
	{ at = FIRE_AT - 0.5 - 4.35 / 1.25, name = "cannon_charge", pitch = 1.25 },
	{ at = FIRE_AT, name = "main_beam" },
	{ at = FIRE_AT, name = "keeper_roar" },
	{ at = GATE_HIT, name = "gate_collapse" },
}
do
	local rng = Random.new(7)
	-- his left hand (UnitAnimator's Envoy block): a click at each tap's lowest point (its dips are
	-- sin(ft * 6.5) ^ 6 between 2.6 and 5 s), a softer one where the drag starts (3.3); the press home is rune_confirm
	for k = 0, 10 do
		local at = (math.pi / 2 + k * 2 * math.pi) / 6.5
		if at > 2.6 and at < 5 then
			table.insert(CUES, { at = at - 0.03, name = "rune_click", near = true, pitch = rng:NextNumber(0.95, 1.1) })
		end
	end
	table.insert(CUES, { at = 3.3, name = "rune_click", near = true, volume = 0.6, pitch = 0.85 })
	-- the reticles locking onto the gate after the scan fan, one by one, each a little higher
	for i, at in ipairs(LOCKS) do
		table.insert(CUES, { at = at, name = "target_lock", pitch = 1 + (i - 1) * 0.04 })
	end
	-- the barrage: one distant gun per salvo (his basic attack's gunship sound; no missile sounds, only the cannons)
	for s = BARRAGE_AT, BARRAGE_END - 0.1, SALVO_EVERY do
		table.insert(CUES, { at = s, name = "cannon_far", pitch = rng:NextNumber(0.92, 1.05) })
	end
end

-- Military transmission subtitles. Reveal whole graphemes on the cutscene clock, so Skip, late watching and
-- cleanup need no extra tasks or tweens. Each phrase keeps the deliberate pause in the recording.
local function subtitleTrack(ui)
	local group = Instance.new("CanvasGroup")
	group.Name = "MalakSubtitles"
	group.AnchorPoint = Vector2.new(0.5, 1)
	group.Position = UDim2.fromScale(0.5, 0.885)
	group.Size = UDim2.fromScale(0.84, 0.13)
	group.BackgroundTransparency = 1
	group.Visible = false
	group.ZIndex = 10
	group.Parent = ui

	local speaker = Instance.new("TextLabel")
	speaker.Name = "Speaker"
	speaker.Size = UDim2.fromScale(1, 0.24)
	speaker.BackgroundTransparency = 1
	speaker.Font = Enum.Font.RobotoMono
	speaker.Text = "MALAK"
	speaker.TextColor3 = Color3.fromRGB(165, 188, 205)
	speaker.TextScaled = true
	speaker.ZIndex = 10
	speaker.Parent = group
	local speakerSize = Instance.new("UITextSizeConstraint")
	speakerSize.MaxTextSize = 14
	speakerSize.Parent = speaker

	local line = Instance.new("TextLabel")
	line.Name = "Dialogue"
	line.Position = UDim2.fromScale(0, 0.3)
	line.Size = UDim2.fromScale(1, 0.68)
	line.BackgroundTransparency = 1
	line.Font = Enum.Font.Sarpanch
	line.TextColor3 = Color3.fromRGB(232, 238, 242)
	line.TextScaled = true
	line.TextWrapped = true
	line.MaxVisibleGraphemes = 0
	line.ZIndex = 10
	line.Parent = group
	local lineSize = Instance.new("UITextSizeConstraint")
	lineSize.MaxTextSize = 30
	lineSize.Parent = line
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(6, 9, 13)
	stroke.Thickness = 1.5
	stroke.Transparency = 0.15
	stroke.Parent = line

	local dialogue = {}
	for _, cue in ipairs(CUES) do
		if cue.phrases then
			local entry = { cue = cue, text = "", phrases = {} }
			for _, phrase in ipairs(cue.phrases) do
				local count = 0
				for _ in utf8.graphemes(phrase.text) do
					count += 1
				end
				entry.text ..= phrase.text
				table.insert(entry.phrases, { at = phrase.at, reveal = phrase.reveal, count = count })
			end
			table.insert(dialogue, entry)
		end
	end
	return function(T, watching)
		group.Visible = false
		if not watching then
			return
		end
		for _, entry in ipairs(dialogue) do
			local elapsed = T - entry.cue.at
			if elapsed >= 0 and elapsed < entry.cue.duration + 0.65 then
				local visible = 0
				for _, phrase in ipairs(entry.phrases) do
					visible += math.floor(phrase.count * math.clamp((elapsed - phrase.at) / phrase.reveal, 0, 1))
				end
				line.Text = entry.text
				line.MaxVisibleGraphemes = visible
				group.GroupTransparency = smooth((elapsed - entry.cue.duration - 0.45) / 0.2)
				group.Visible = true
				return
			end
		end
	end
end

-- update(T, watching) every frame; stop() at the end; takeHum() hands the ship's hum to lingerShip
local MUSIC_AT = 1.5 -- the music (52.5 s, only for whoever watches) starts once the silence has fallen

local function soundtrack(ctx)
	local fired = {}
	local portalHum, shipHum, music
	local musicVol, lastClock = 0, os.clock()
	local s = {}
	function s.update(T, watching)
		local loud = watching and 1 or SKY_VOLUME
		ctx.soundLoud = loud
		-- the music: fades in / out with watching; silent for the half second before the beam, back with it
		local now = os.clock()
		musicVol += ((watching and 1 or 0) - musicVol) * math.min(1, (now - lastClock) * 3)
		lastClock = now
		if T >= MUSIC_AT and not music then
			music = Sfx.music("fleet_music", T - MUSIC_AT)
		end
		if music then
			local duck = (T >= FIRE_AT - 0.8 and T < FIRE_AT) and 1 - smooth((T - FIRE_AT + 0.8) / 0.3) or 1
			-- Keep his quiet delivery clear: lower the score during each line, with short fades at either end.
			local voiceDuck = 1
			for _, c in ipairs(CUES) do
				if c.voice then
					local speaking = smooth((T - c.at + 0.15) / 0.15) * (1 - smooth((T - c.at - c.duration) / 0.2))
					voiceDuck = math.min(voiceDuck, 1 - 0.7 * speaking)
				end
			end
			music.set(musicVol * duck * voiceDuck)
		end
		for i, c in ipairs(CUES) do
			if not fired[i] and T >= c.at then
				fired[i] = true
				if T - c.at < 0.5 and (watching or not c.near) then -- (joined late: past cues stay silent)
					Sfx.play(c.name, nil, loud * (c.volume or 1), c.pitch)
				end
			end
		end
		-- the portal hums while it is open
		if T >= OPEN_AT - 1 and T < SNAP_AT then
			portalHum = portalHum or Sfx.loop("portal_hum")
			portalHum.set(smooth((T - OPEN_AT + 1) / 2) * loud)
		elseif portalHum then
			portalHum.stop(0.3)
			portalHum = nil
		end
		-- the ship's engines from the moment it slides out
		if T >= EMERGE_FROM then
			shipHum = shipHum or Sfx.loop(SHIP_HUM)
			shipHum.set(smooth((T - EMERGE_FROM) / 4) * loud)
		end
	end
	function s.takeHum()
		local h = shipHum
		shipHum = nil
		return h
	end
	function s.stop()
		if music then
			music.stop(1)
		end
		if portalHum then
			portalHum.stop(0.3)
		end
		if shipHum then
			shipHum.stop(1)
		end
	end
	return s
end

-- ============================================================
-- Step 6: after the cutscene the Absolution lingers over the arena, then leaves backwards through a portal
-- ============================================================
local LINGER = 16 -- s it stays after the cutscene before the portal opens behind it
local SETTLE = 3 -- s to close the bow, pull the cannon in, turn the turrets home, let the rings go
local WARP_OUT_TEAR = 3 -- the portal tears open behind its stern ...
local WARP_OUT_DRIFT = 10 -- ... it drifts in backwards, stern first, slowly, then faster ...
local WARP_OUT_AFTER = 4 -- ... the portal snaps shut; then everything is cleaned up
local RING_IDLE = { RingA = 0.12, RingB = -0.18, RingC = 0.3 }

-- `ship` is the warp-in's clone (moved out of the cutscene's folder); `deferred` are the cutscene's cleanups that must
-- wait until the ship is gone (the haze stays thin while it is in the sky); `onGone` runs at the very end; `hum` is the
-- engines' loop from the soundtrack (or nil).
local function lingerShip(ship, deferred, onGone, hum)
	local folder = Instance.new("Folder")
	folder.Name = "FleetStrikeLinger"
	folder.Parent = workspace
	ship.Parent = folder
	local cf0 = ship.PrimaryPart.CFrame
	local look = cf0.LookVector
	-- the portal opens behind its stern, facing it (its own tear: rune ring, cracks, void, the snap)
	local portal = CFrame.lookAt(cf0.Position - look * PORTAL_BEHIND, cf0.Position)
	local tearUpdate, tearCleanup = skyTear(folder, portal)
	local joints, parts = {}, {}
	for _, d in ipairs(ship:GetDescendants()) do
		if d:IsA("Motor6D") then
			table.insert(joints, { j = d, from = d.Transform, idle = RING_IDLE[d.Name] })
		elseif d:IsA("BasePart") then
			table.insert(parts, { part = d, hidden = false })
		end
	end
	local core = ship:FindFirstChild("Core", true)
	local coreHalo = ship:FindFirstChild("CoreHalo", true)
	local coreSize, haloSize = core and core.Size, coreHalo and coreHalo.Size
	local t0 = os.clock()
	local portalHum
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local lt = os.clock() - t0
		-- sound: the engines go quiet (the cutscene is over); the warp-out portal hums, the ship fades into it, the boom
		local wo0 = lt - LINGER
		local into = math.clamp((wo0 - WARP_OUT_TEAR) / WARP_OUT_DRIFT, 0, 1)
		if hum then
			hum.set(SKY_VOLUME * (1 - smooth(lt / 2) * 0.3) * (1 - into))
		end
		if wo0 > 0 and wo0 < WARP_OUT_TEAR + WARP_OUT_DRIFT then
			portalHum = portalHum or Sfx.loop("portal_hum")
			portalHum.set(smooth(wo0 / 2) * SKY_VOLUME)
		elseif portalHum then
			portalHum.stop(0.3)
			portalHum = nil
			Sfx.play("warp_out", nil, SKY_VOLUME)
		end
		-- settle: the bow closes, the cannon slides back in, the turrets turn home, the rings unlock and turn slowly
		local k = smooth(lt / SETTLE)
		for _, s in ipairs(joints) do
			if s.j.Parent then
				local rest = s.idle and CFrame.Angles(0, lt * s.idle, 0) or CFrame.new()
				s.j.Transform = s.from:Lerp(rest, k)
			end
		end
		if core then
			local pulse = 0.5 + 0.5 * math.sin(lt * 1.6)
			core.Size = coreSize * (0.96 + 0.06 * pulse)
			coreHalo.Size = haloSize * (0.94 + 0.12 * pulse)
		end
		-- the warp-out: the tear behind it (the warp-in's timeline, re-timed), the drift backwards, hidden past the plane
		local wo = lt - LINGER
		if wo > 0 then
			local tt
			if wo < WARP_OUT_TEAR then
				tt = TEAR_AT + wo / WARP_OUT_TEAR * (WARP_AT - TEAR_AT)
			elseif wo < WARP_OUT_TEAR + WARP_OUT_DRIFT then
				tt = WARP_AT + (wo - WARP_OUT_TEAR) / WARP_OUT_DRIFT * (EMERGE_TO - WARP_AT)
			else
				tt = SNAP_AT + (wo - WARP_OUT_TEAR - WARP_OUT_DRIFT)
			end
			tearUpdate(tt)
			local u = math.clamp((wo - WARP_OUT_TEAR) / WARP_OUT_DRIFT, 0, 1)
			ship:PivotTo(cf0 - look * 480 * SHIP_SCALE * u ^ 1.7) -- (slow to start, the heavy ship gathering way)
			local pp = portal.Position
			for _, p in ipairs(parts) do
				local behind = (p.part.Position - pp):Dot(look) < 0
				if behind ~= p.hidden then
					p.hidden = behind
					p.part.LocalTransparencyModifier = behind and 1 or 0
				end
			end
		end
		if wo > WARP_OUT_TEAR + WARP_OUT_DRIFT + WARP_OUT_AFTER then
			conn:Disconnect()
			if hum then
				hum.stop(0)
			end
			tearCleanup()
			for _, c in ipairs(deferred) do
				c()
			end
			folder:Destroy()
			if onGone then
				onGone()
			end
		end
	end)
end

-- ============================================================
-- Play
-- ============================================================
function FleetStrike.play(opts)
	opts = opts or {}
	if FleetStrike.active then
		return false
	end
	-- the server's start time (every client plays from it, so they all see the same moment); a preview starts now
	local startAt = opts.startAt or workspace:GetServerTimeNow()
	if workspace:GetServerTimeNow() - startAt >= DURATION - 1 then
		return false -- (too late to join)
	end
	local malak = opts.malak
	if not opts.malakCF then
		malak = malak or findMalak()
		if not malak then
			warn("FleetStrike: no Malak of yours in the world")
			return false
		end
	end
	if malak and not malak.Parent then
		malak = nil -- (streamed out on this client: the world part plays without his poses)
	end
	FleetStrike.active = true
	local camera = workspace.CurrentCamera
	local spectator = opts.spectator == true -- (another player's finisher: no camera take-over unless they Watch)

	local M = opts.malakCF or malak:GetPivot()
	M = CFrame.lookAt(M.Position, M.Position + Vector3.new(M.LookVector.X, 0, M.LookVector.Z)) -- (level)
	local gate = opts.gate or (malak and malak:GetAttribute("AimPos")) or (M * CFrame.new(0, 4, -60)).Position
	local ctx = {
		M = M,
		gate = gate,
		sky = M.Position:Lerp(Vector3.new(gate.X, M.Position.Y, gate.Z), SKY_ALONG) - M.RightVector * SKY_SIDE + Vector3.new(0, SKY_HEIGHT, 0),
		drone = malak and malak:FindFirstChild("DroneRoot", true),
		start = camera.CFrame,
		preview = opts.preview == true,
	}
	-- the ship comes in from LEFT to RIGHT as seen from Malak: side-on, square to his line of sight, the nose only a
	-- little down; the portal is behind it (to the left on screen). It does not point at the gate: its turrets and
	-- the main cannon turn to it on their own joints.
	local view = Vector3.new(ctx.sky.X - M.Position.X, 0, ctx.sky.Z - M.Position.Z).Unit
	local axisFlat = view:Cross(Vector3.new(0, 1, 0)).Unit
	ctx.sky -= axisFlat * SKY_LEFT
	local axis = (axisFlat * math.cos(0.08) - Vector3.new(0, math.sin(0.08), 0)).Unit
	ctx.shipCF = CFrame.lookAt(ctx.sky, ctx.sky + axis)
	-- the camera's line from the drone to the warp-in: from Malak towards the tear, level
	local toTear = ctx.sky - axis * PORTAL_BEHIND - M.Position
	ctx.D = Vector3.new(toTear.X, 0, toTear.Z).Unit
	ctx.portal = CFrame.lookAt(ctx.sky - axis * PORTAL_BEHIND, ctx.sky)
	ctx.bow = (ctx.shipCF * CFrame.new(0, 0, -215 * SHIP_SCALE)).Position
	-- the realm keeper's eyes (the beam's first target), for the camera; the keeper nearest the gate
	ctx.keeper = gate + Vector3.new(0, 80, 0)
	do
		local bestD
		for _, k in ipairs(CollectionService:GetTagged("RealmHands")) do
			local d = (k:GetPivot().Position - gate).Magnitude
			if not bestD or d < bestD then
				bestD = d
				local sum, n = Vector3.zero, 0
				for _, part in ipairs(k:GetDescendants()) do
					if part:IsA("BasePart") and part.Name == "Eye" then
						sum += part.Position
						n += 1
					end
				end
				ctx.keeper = n > 0 and sum / n or k:GetPivot().Position + Vector3.new(0, 60, 0)
			end
		end
	end

	-- ── The world part (every player): Malak's poses (UnitAnimator), the effects ──
	local fxFolder = Instance.new("Folder")
	fxFolder.Name = "FleetStrikeFx"
	fxFolder.Parent = workspace
	local tearUpdate, tearCleanup = skyTear(fxFolder, ctx.portal)
	local warpUpdate, warpCleanup = warpIn(fxFolder, ctx.portal, ctx.shipCF, ctx)
	local finaleUpdate, finaleCleanup, keeperRestore = finale(fxFolder, ctx)
	local effects = { tearUpdate, warpUpdate, barrage(fxFolder, ctx), finaleUpdate }
	if malak then
		local scale = malak:GetScale()
		table.insert(effects, runePanel(fxFolder, malak, scale))
		table.insert(effects, transmitter(fxFolder, malak, scale))
		-- (client-only: drives his poses in UnitAnimator's Envoy block, on the same clock as the cutscene)
		malak:SetAttribute("FleetStart", os.clock() - (workspace:GetServerTimeNow() - startAt))
	end
	local cleanups = { tearCleanup, warpCleanup, finaleCleanup }
	-- (Studio preview: the server holds the army and lets it flee; the real finisher is started by the server itself)
	local devRemote = ctx.preview and RunService:IsStudio() and game:GetService("ReplicatedStorage"):FindFirstChild("DevFleetStrike")
	if devRemote then
		devRemote:FireServer(true)
	end

	-- ── The camera take-over: the owner at once, other players when they press Watch ──
	local ui = Instance.new("ScreenGui")
	ui.Name = "FleetStrikeUI"
	ui.ResetOnSpawn = false
	ui.IgnoreGuiInset = true
	ui.DisplayOrder = 100
	ui.Parent = player:WaitForChild("PlayerGui")
	local updateSubtitles = subtitleTrack(ui)
	local function bar(anchorY)
		local f = Instance.new("Frame")
		f.AnchorPoint = Vector2.new(0, anchorY)
		f.Position = UDim2.fromScale(0, anchorY)
		f.Size = UDim2.fromScale(1, 0)
		f.BackgroundColor3 = Color3.new(0, 0, 0)
		f.BorderSizePixel = 0
		f.Parent = ui
		return f
	end
	local barTop, barBottom = bar(0), bar(1)
	local skipBtn = Theme.stoneButton(ui, {
		text = "Skip", color = "stone", size = UDim2.fromOffset(120, 40),
		position = UDim2.new(1, -24, 1, -20), anchor = Vector2.new(1, 1), zIndex = 8,
	})
	skipBtn.root.Visible = false
	local watchBtn = Theme.stoneButton(ui, {
		text = "Watch the Fleet Strike", color = "blue", size = UDim2.fromOffset(260, 44),
		position = UDim2.new(0.5, 0, 0, 90), anchor = Vector2.new(0.5, 0), zIndex = 8,
	})
	watchBtn.root.Visible = false
	-- (Studio only) the beat that is playing, to judge the pacing
	local caption
	if RunService:IsStudio() then
		caption = Instance.new("TextLabel")
		caption.Position = UDim2.new(0, 16, BAR_HEIGHT, 8)
		caption.Size = UDim2.fromOffset(520, 26)
		caption.BackgroundTransparency = 1
		caption.Font = Enum.Font.GothamMedium
		caption.TextSize = 18
		caption.TextXAlignment = Enum.TextXAlignment.Left
		caption.TextColor3 = Color3.fromRGB(200, 205, 230)
		caption.TextStrokeTransparency = 0.4
		caption.ZIndex = 9
		caption.Visible = false
		caption.Parent = ui
	end

	local watching = false
	local watchStart = 0
	local saved, controls
	local hiddenGuis, hiddenBoards = {}, {}
	local function takeOver()
		if watching then
			return
		end
		watching = true
		watchStart = workspace:GetServerTimeNow() - startAt
		saved = { cameraType = camera.CameraType, fov = camera.FieldOfView, guiEnabled = mainGui.Enabled }
		ctx.start = camera.CFrame
		pcall(function()
			controls = require(player.PlayerScripts:WaitForChild("PlayerModule", 2)):GetControls()
			controls:Disable()
		end)
		mainGui.Enabled = false
		for _, g in ipairs(player:WaitForChild("PlayerGui"):GetChildren()) do
			if g:IsA("ScreenGui") and g.Enabled and g ~= ui and g.Name ~= "Freecam" then
				g.Enabled = false
				table.insert(hiddenGuis, g)
			end
		end
		-- every nameplate and bar in the world is hidden while watching
		for _, d in ipairs(workspace:GetDescendants()) do
			if d:IsA("BillboardGui") and d.Enabled then
				d.Enabled = false
				table.insert(hiddenBoards, d)
			end
		end
		camera.CameraType = Enum.CameraType.Scriptable
		watchBtn.root.Visible = false
		skipBtn.root.Visible = true
		if caption then
			caption.Visible = true
		end
	end
	local function giveBack()
		if not watching then
			return
		end
		watching = false
		for _, b in ipairs(hiddenBoards) do
			if b.Parent then
				b.Enabled = true
			end
		end
		camera.CameraType = saved.cameraType == Enum.CameraType.Scriptable and Enum.CameraType.Custom or saved.cameraType
		camera.FieldOfView = saved.fov
		mainGui.Enabled = saved.guiEnabled
		for _, g in ipairs(hiddenGuis) do
			if g.Parent then
				g.Enabled = true
			end
		end
		if controls then
			pcall(function() controls:Enable() end)
		end
	end
	if spectator then
		watchBtn.root.Visible = true
		watchBtn.button.Activated:Connect(takeOver)
	else
		takeOver()
	end

	-- ── Run ──────────────────────────────────────────────────
	local T = workspace:GetServerTimeNow() - startAt
	local done = false
	local BIND = "FleetStrikeCamera"
	local sound = soundtrack(ctx)

	local function finish()
		if done then
			return
		end
		done = true
		RunService:UnbindFromRenderStep(BIND)
		giveBack()
		ui:Destroy()
		-- once it is out of the portal the ship stays: it lingers over the arena, then leaves backwards (lingerShip);
		-- the thin haze waits until it is gone; (preview) the keeper comes back after it
		local ship = fxFolder:FindFirstChild("Absolution")
		if ship and T >= EMERGE_TO then
			for _, c in ipairs(cleanups) do
				if c ~= tearCleanup and c ~= warpCleanup then
					c()
				end
			end
			lingerShip(ship, { tearCleanup }, function()
				if ctx.preview then
					keeperRestore(true)
				end
			end, sound.takeHum())
		else
			for _, c in ipairs(cleanups) do
				c()
			end
			if ctx.preview then
				keeperRestore(false)
			end
		end
		sound.stop()
		fxFolder:Destroy()
		if malak and malak.Parent then
			malak:SetAttribute("FleetStart", nil)
		end
		if devRemote then
			devRemote:FireServer(false)
		end
		FleetStrike.active = false
		if opts.onDone then
			opts.onDone()
		end
	end
	-- Skip only gives the camera back: the world part (the ship, the gate falling) still plays out for everyone
	skipBtn.button.Activated:Connect(function()
		giveBack()
		skipBtn.root.Visible = false
		if caption then
			caption.Visible = false
		end
	end)

	RunService:BindToRenderStep(BIND, Enum.RenderPriority.Camera.Value + 1, function()
		if done then
			return
		end
		T = workspace:GetServerTimeNow() - startAt -- (the server's clock: every client sees the same moment)
		if T >= DURATION then
			finish()
			return
		end
		for _, effect in ipairs(effects) do
			effect(T)
		end
		sound.update(T, watching)
		updateSubtitles(T, watching)
		if watchBtn.root.Visible and T >= 44 then
			watchBtn.root.Visible = false -- (too late to start watching)
		end
		-- letterbox bars: in at the start (or when they start watching), out at the end
		local h = watching and BAR_HEIGHT * smooth((T - watchStart) / BAR_TIME) * smooth((DURATION - T) / BAR_TIME) or 0
		barTop.Size = UDim2.fromScale(1, h)
		barBottom.Size = UDim2.fromScale(1, h)
		if not watching then
			return
		end
		if camera.CameraType ~= Enum.CameraType.Scriptable then
			camera.CameraType = Enum.CameraType.Scriptable -- (something may have reset it; the default camera would take over)
		end
		local pos, look, fov = cameraAt(T, ctx)
		camera.CFrame = CFrame.lookAt(pos, look)
		camera.FieldOfView = fov
		-- impacts on the gate shake the camera a little
		local shake = math.max(ctx.barrageShake and ctx.barrageShake() or 0, ctx.finaleShake or 0)
		if shake > 0 then
			local tt = os.clock() * 37
			camera.CFrame *= CFrame.new(math.sin(tt) * shake * 0.5, math.sin(tt * 1.3 + 1) * shake * 0.5, 0)
				* CFrame.Angles(0, 0, math.sin(tt * 0.9) * shake * 0.01)
		end
		if caption then
			local index = 1
			for i, b in ipairs(BEATS) do
				if T >= b.at then
					index = i
				end
			end
			caption.Position = UDim2.new(0, 16, h, 8)
			caption.Text = string.format("%d / %d  %s   (%.1f s)", index, #BEATS, BEATS[index].name, T)
		end
	end)
	return true
end

-- the server starts a Fleet Strike for everyone (Army.checkFleetStrike): the owner watches it, the others see it in the
-- sky and may Watch
local fleetRemote = game:GetService("ReplicatedStorage"):WaitForChild("FleetStrike", 10)
if fleetRemote then
	fleetRemote.OnClientEvent:Connect(function(data)
		if type(data) ~= "table" or not data.startAt then
			return
		end
		FleetStrike.play({
			startAt = data.startAt,
			malak = data.malak,
			malakCF = data.malakCF,
			gate = data.gate,
			spectator = data.owner ~= tostring(player.UserId),
		})
	end)
end

-- the sky scene for other cinematics (SovereignArrival: Malak's pull): the tear and the warp-in run on this file's
-- clock, so the caller maps its own time onto these beats
FleetStrike.sky = {
	tear = skyTear, -- skyTear(folder, portalCF) -> update(T), cleanup()
	warpIn = warpIn, -- warpIn(folder, portalCF, shipFinalCF, ctx) -> update(T), cleanup()
	TEAR_AT = TEAR_AT, CRACKS_AT = CRACKS_AT, OPEN_AT = OPEN_AT, WARP_AT = WARP_AT,
	EMERGE_FROM = EMERGE_FROM, EMERGE_TO = EMERGE_TO, SNAP_AT = SNAP_AT,
	SHIP_SCALE = SHIP_SCALE, BOW_OPEN_ANGLE = BOW_OPEN_ANGLE,
}

return FleetStrike
