-- Veyr's gate finisher, THE FINAL HORIZON (docs/veyr.md "Finisher"; timings: shared VeyrTimeline.FINISHER).
--
--   local started = VeyrFinisher.play(opts)
--     opts: startAt (server time), unit (his model), gate (Vector3), spectator (another player's), preview (Studio),
--           onDone
--     returns false when it cannot play (no Veyr of yours, already running, too late to join).
--
-- Started by the SERVER for everyone (Army.checkFinisher; remote FinalHorizon): every client plays the world part from
-- the same server time; the owner's camera is taken over (Skip only gives it back), other players see it over the
-- owner's lane and may press Watch (joining late seeks to the shared clock). The server holds the gate and breaks it at
-- GATE_HIT, whatever happens on any screen. The user's version (2026-10-16):
--   MARKSMAN, SEAT       close on him: he seats one round
--   AURA, FLEE           his charge aura: the ground under his perch cracks, debris lifts and circles his energy; the
--                        army clears the line (server)
--   ASCENT               he launches up into the sky, backwards, aiming the whole time (MarksmanAnimator flies him),
--                        the debris spiralling up with him
--   MOON                 the peak: a huge pale moon behind him; the sky darkens (watchers' grading)
--   ARSENAL, GIANTS_*    eight magic circles open in a wheel round his line of fire; out of each slides a giant copy
--                        of his own rifle (cloned from his model, scaled up), and they all swing onto the gate
--   LOCK, SHIELD         nine targeting lasers reach the gate; the keeper raises his hands over it (HandsAnimator)
--   CHARGE               the debris orbits faster, light is drawn up the lasers into the nine muzzles
--   STILL, LIGHT_RUN     everything goes quiet: the debris stops in the air; a faint light runs along every weapon
--                        from stock to barrel; a short pause
--   FIRE, IMPACT         nine rounds at once (impact frames); they hit (impact frames, the scope picture shatters,
--                        the keeper's hands are blown back, the gate vanishes in smoke); a black hole opens there
--   CRUMBLE, TURN        the giant rifles dissolve into falling sparks; the gate still stands, cracks spreading; he
--   DESCEND              lowers the rifle, works the bolt, turns his back and drifts back down to his perch
--   GATE_HIT             the gate erupts behind him (the server breaks it): the black hole swells and swallows the
--                        chunks, implodes to a point and bursts: a shockwave down the lane past him
-- Everything is measured from his real model, the lane and the gate the server sends, so it works on every rotated
-- plot. The scope views lock the camera at his eyepiece (it must not wander while he is still).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local mainGui = require(script.Parent.Gui)
local Theme = require(script.Parent.Theme)
local Sfx = require(script.Parent.Sfx)
local VeyrSights = require(script.Parent.VeyrSights)
local CinematicGuard = require(script.Parent.CinematicGuard)
local F = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("VeyrTimeline")).FINISHER

local player = Players.LocalPlayer
local VeyrFinisher = {}
VeyrFinisher.active = false
local states = {} -- [his model] = the running finisher (MarksmanAnimator reads the gate he aims at)

local DURATION = F.END
local BAR_HEIGHT = 0.1
local BAR_TIME = 0.8
local GIANTS = 8 -- (the user: "like 8")
local GIANT_SCALE = 4.2
local WHEEL_R = 20 -- studs from his line of fire to each giant rifle
local DEBRIS = 40
local WHITE = Color3.fromRGB(250, 248, 255)
local VIOLET = Color3.fromRGB(118, 86, 255)
local VIOLET_CORE = Color3.fromRGB(205, 196, 255)
local VIOLET_DEEP = Color3.fromRGB(64, 40, 190)
local MOON = Color3.fromRGB(222, 222, 240)
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local SPARK = "rbxasset://textures/particles/sparkles_main.dds"

local BEATS = {
	{ at = F.QUIET, name = "The line goes quiet" }, { at = F.MARKSMAN, name = "The marksman" },
	{ at = F.AURA, name = "The aura" }, { at = F.ASCENT_FROM, name = "The ascent" }, { at = F.MOON, name = "The moon" },
	{ at = F.ARSENAL, name = "The arsenal" }, { at = F.LOCK, name = "Lock" }, { at = F.CHARGE, name = "The charge" },
	{ at = F.STILL, name = "Quiet" }, { at = F.FIRE, name = "Fire" }, { at = F.CRUMBLE, name = "Already dead" },
	{ at = F.GATE_HIT, name = "The gate" }, { at = F.FADE, name = "The last sight" },
}

local function smooth(x)
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end
local function ease(x, a, b)
	return smooth((x - a) / (b - a))
end
local function backOut(k)
	local c = 1.5
	return 1 + (c + 1) * (k - 1) ^ 3 + c * (k - 1) ^ 2
end

local function newPart(folder, size, color, transparency, shape, material)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = material or Enum.Material.Neon
	p.Color = color
	p.Size = size
	p.Transparency = transparency or 0
	if shape then
		p.Shape = shape
	end
	p.Parent = folder
	return p
end

local function burst(folder, pos, dir, count, opts)
	local holder = newPart(folder, Vector3.one, WHITE, 1)
	holder.CFrame = CFrame.lookAt(pos, pos + dir) * CFrame.Angles(-math.pi / 2, 0, 0)
	local e = Instance.new("ParticleEmitter")
	e.Texture = opts.texture or SMOKE
	e.Color = ColorSequence.new(opts.color or Color3.fromRGB(70, 64, 84), opts.color2 or opts.color or Color3.fromRGB(30, 28, 36))
	e.LightEmission = opts.emission or 0
	e.LightInfluence = opts.emission and 0 or 1
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, opts.size0 or 1), NumberSequenceKeypoint.new(1, opts.size1 or 4) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, opts.t0 or 0.3), NumberSequenceKeypoint.new(1, 1) })
	e.Lifetime = NumberRange.new(opts.life0 or 0.8, opts.life1 or 1.8)
	e.Speed = NumberRange.new(opts.speed0 or 8, opts.speed1 or 24)
	e.Drag = opts.drag or 2
	e.Acceleration = opts.accel or Vector3.new(0, 2, 0)
	e.SpreadAngle = Vector2.new(opts.spread or 45, opts.spread or 45)
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-60, 60)
	e.Enabled = false
	e.Parent = holder
	e:Emit(count)
	Debris:AddItem(holder, (opts.life1 or 1.8) + 0.3)
end

local function shockDisc(folder, pos, dir, r0, r1, dur, color, startT)
	local d = newPart(folder, Vector3.new(0.1, r0 * 2, r0 * 2), color, startT or 0.4, Enum.PartType.Cylinder)
	d.CFrame = CFrame.lookAt(pos, pos + dir) * CFrame.Angles(0, math.pi / 2, 0)
	TweenService:Create(d, TweenInfo.new(dur, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
		{ Size = Vector3.new(0.02, r1 * 2, r1 * 2), Transparency = 1 }):Play()
	Debris:AddItem(d, dur + 0.05)
end

local function flash(folder, pos, color, s0, s1, dur, range, bright)
	local f = newPart(folder, Vector3.one * s0, WHITE, 0, Enum.PartType.Ball)
	f.CFrame = CFrame.new(pos)
	if range then
		local l = Instance.new("PointLight")
		l.Color = color
		l.Range = math.min(range, 60)
		l.Brightness = bright or 8
		l.Shadows = false
		l.Parent = f
		TweenService:Create(l, TweenInfo.new(dur * 2), { Brightness = 0 }):Play()
	end
	TweenService:Create(f, TweenInfo.new(dur, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = Vector3.one * s1, Transparency = 1, Color = color }):Play()
	Debris:AddItem(f, dur * 2 + 0.1)
end

-- the player's own Veyr (the nearest, if several)
local function findVeyr()
	local me = tostring(player.UserId)
	local best, bestD
	local char = player.Character
	local from = char and char.PrimaryPart and char.PrimaryPart.Position or Vector3.zero
	for _, m in ipairs(CollectionService:GetTagged("ProceduralUnit")) do
		if m.Name == "Veyr" and m.Parent and m:GetAttribute("OwnerId") == me then
			local d = (m:GetPivot().Position - from).Magnitude
			if not bestD or d < bestD then
				best, bestD = m, d
			end
		end
	end
	return best
end

local function keeperOf(gate)
	local best, bestD
	for _, k in ipairs(CollectionService:GetTagged("RealmHands")) do
		local d = (k:GetPivot().Position - gate).Magnitude
		if not bestD or d < bestD then
			best, bestD = k, d
		end
	end
	return best
end

-- ============================================================
-- A giant rifle: every part of his own rifle (cloned from his model template: the parts welded to RifleRoot and the
-- bolt), scaled up. Offsets are kept in the rifle's frame (bore along -Z), so it is placed like his own.
-- ============================================================
local function rifleTemplate()
	local tpl = ReplicatedStorage:FindFirstChild("UnitModels") and ReplicatedStorage.UnitModels:FindFirstChild("Veyr")
	local rr = tpl and tpl:FindFirstChild("RifleRoot")
	if not rr then
		return nil
	end
	local list = {}
	local boltRoot = tpl:FindFirstChild("BoltRoot")
	local roots = { [rr] = true }
	if boltRoot then
		roots[boltRoot] = true
		table.insert(list, boltRoot)
	end
	for _, d in ipairs(tpl:GetDescendants()) do
		if d:IsA("WeldConstraint") and roots[d.Part0] and d.Parent:IsA("BasePart") then
			table.insert(list, d.Parent)
		end
	end
	local muzzle = rr:FindFirstChild("Muzzle")
	return { root = rr, parts = list, muzzle = muzzle and muzzle.CFrame or CFrame.new(0, 0.02, -6.9) }
end

local function buildGiant(folder, tpl)
	local g = { parts = {} }
	for _, src in ipairs(tpl.parts) do
		local p = src:Clone()
		for _, c in ipairs(p:GetChildren()) do
			if not c:IsA("DataModelMesh") then
				c:Destroy()
			end
		end
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Size = src.Size * GIANT_SCALE
		local off = tpl.root.CFrame:ToObjectSpace(src.CFrame)
		local base = src.Transparency
		if p.Material == Enum.Material.Neon then
			p.Color = p.Color:Lerp(VIOLET, 0.35)
		end
		p.Transparency = 1
		p.Parent = folder
		table.insert(g.parts, { part = p, offset = CFrame.new(off.Position * GIANT_SCALE) * off.Rotation, base = base })
	end
	g.muzzle = CFrame.new(tpl.muzzle.Position * GIANT_SCALE)
	g.length = 7.3 * GIANT_SCALE
	return g
end

local function placeGiant(g, cf, alpha)
	for _, p in ipairs(g.parts) do
		p.part.CFrame = cf * p.offset
		p.part.Transparency = 1 - (1 - p.base) * math.clamp(alpha, 0, 1)
	end
end

-- ============================================================
-- The camera: ONE continuous path (FleetStrike's monotone Hermite: never overshoots). Keys are functions of ctx:
-- chest (his chest, live), H (his frame at the start), L (the lane, level, his ground spot -> gate), side (out to his
-- perch side), gate, peak (where his chest will be at the top), start (the player's camera).
-- ============================================================
local function chestAt(c)
	return c.chest and c.chest.Position or c.H.Position
end
-- the scope views are HIS view: the camera locked at his eyepiece (captured when the window opens), on the gate
local function scopeEye(c, which)
	local cap = c["eye" .. which]
	if not cap then
		local att = c.scopeEye
		local p = att and att.WorldPosition or chestAt(c)
		local look = (c.gate - p).Unit
		cap = p - look * 0.35 + Vector3.new(0, 0.05, 0)
		c["eye" .. which] = cap
	end
	return cap
end
local function scopeLook(c) return c.gate + Vector3.new(0, 3, 0) end
local function orbit(c, deg, r, up)
	local a = math.rad(deg)
	local dir = c.L.LookVector * math.cos(a) + c.side * math.sin(a)
	return c.peak + dir * r + Vector3.new(0, up, 0)
end

local KEYS = {
	-- the line goes quiet: from the player's view to wide behind him on his perch
	{ t = 0, pos = function(c) return c.start.Position end, look = function(c) return c.start.Position + c.start.LookVector * 20 end, fov = 70 },
	{ t = 1.8, pos = function(c) return chestAt(c) - c.L.LookVector * 16 - c.side * 6 + Vector3.new(0, 6, 0) end, look = function(c) return chestAt(c):Lerp(c.gate, 0.3) end, fov = 66 },
	-- the marksman: close on the receiver as he seats the round
	{ t = 3.2, pos = function(c) return (c.H * CFrame.new(2.4, 1.2, -3)).Position end, look = function(c) return (c.H * CFrame.new(0.3, 0.8, -0.9)).Position end, fov = 56 },
	{ t = 4.8, pos = function(c) return (c.H * CFrame.new(2.1, 0.7, -2.5)).Position end, look = function(c) return (c.H * CFrame.new(0.4, 0.5, -1.2)).Position end, fov = 50 },
	-- the aura: low, from the lane in front, looking up at him, the debris lifting round him
	{ t = 6.6, pos = function(c) return c.ground + c.L.LookVector * 18 - c.side * 8 + Vector3.new(0, 2, 0) end, look = function(c) return chestAt(c) end, fov = 64 },
	-- the ascent: the camera rises after him, looking up
	{ t = 9.2, pos = function(c) return chestAt(c) + c.L.LookVector * 22 - c.side * 10 - Vector3.new(0, 10, 0) end, look = function(c) return chestAt(c) end, fov = 62 },
	-- the peak: from in front and below, the moon right behind him
	{ t = 11.4, pos = function(c) return c.peakCam end, look = function(c) return c.peak end, fov = 48 },
	{ t = 12.8, pos = function(c) return c.peakCam + Vector3.new(0, 1, 0) end, look = function(c) return c.peak end, fov = 46 },
	-- the arsenal: pulling back and wide, the wheel of circles opening round him
	{ t = 15.0, pos = function(c) return c.peak + c.L.LookVector * 62 - c.side * 14 - Vector3.new(0, 4, 0) end, look = function(c) return c.peak end, fov = 66 },
	{ t = 17.2, pos = function(c) return c.peak + c.L.LookVector * 58 - c.side * 26 + Vector3.new(0, 4, 0) end, look = function(c) return c.peak end, fov = 66 },
	-- the lock: high behind him, down the lasers onto the gate
	{ t = 18.4, pos = function(c) return c.peak - c.L.LookVector * 30 + Vector3.new(0, 16, 0) end, look = function(c) return c.gate end, fov = 52 },
	-- the first look through his scope: locked
	{ t = 20.4, pos = function(c) return c.peak - c.L.LookVector * 26 + c.side * 6 + Vector3.new(0, 12, 0) end, look = function(c) return c.gate:Lerp(c.peak, 0.15) end, fov = 46 },
	-- the charge: a slow orbit round him and his wheel of guns
	{ t = 21.8, pos = function(c) return orbit(c, 40, 46, 6) end, look = function(c) return c.peak end, fov = 64 },
	{ t = 23.6, pos = function(c) return orbit(c, 100, 44, 9) end, look = function(c) return c.peak end, fov = 64 },
	{ t = 25.4, pos = function(c) return orbit(c, 160, 44, 12) end, look = function(c) return c.peak:Lerp(c.gate, 0.15) end, fov = 62 },
	-- quiet: close on his eyes ...
	{ t = 27.3, pos = function(c) return (CFrame.lookAt(chestAt(c), c.gate) * CFrame.new(1.1, 1.5, -2.2)).Position end, look = function(c) return (CFrame.lookAt(chestAt(c), c.gate) * CFrame.new(0.1, 1.4, -0.2)).Position end, fov = 34 },
	-- ... then into his scope until the hit
	{ t = F.SCOPE_2, pos = function(c) return scopeEye(c, 2) end, look = scopeLook, fov = 30 },
	{ t = F.IMPACT, pos = function(c) return scopeEye(c, 2) end, look = scopeLook, fov = 30 },
	-- the smoke on the gate (a cut right after the hit's impact frames): still standing
	{ t = F.IMPACT + 0.25, cut = true, pos = function(c) return c.gate - c.L.LookVector * 46 + Vector3.new(0, 12, 0) end, look = function(c) return c.gate + Vector3.new(0, 5, 0) end, fov = 58 },
	{ t = 32.7, pos = function(c) return c.gate - c.L.LookVector * 52 + Vector3.new(0, 13, 0) end, look = function(c) return c.gate + Vector3.new(0, 5, 0) end, fov = 56 },
	-- already dead (a cut back up to him): in front of him as he lowers the rifle and turns his back, then following
	-- him down at the same distance
	{ t = 32.8, cut = true, pos = function(c) return chestAt(c) + c.L.LookVector * 11 - c.side * 7 + Vector3.new(0, 1.5, 0) end, look = function(c) return chestAt(c) + Vector3.new(0, 0.5, 0) end, fov = 56 },
	{ t = 35.0, pos = function(c) return chestAt(c) + c.L.LookVector * 11 - c.side * 9 + Vector3.new(0, 1.5, 0) end, look = function(c) return chestAt(c) + Vector3.new(0, 0.5, 0) end, fov = 58 },
	{ t = 36.8, pos = function(c) return chestAt(c) + c.L.LookVector * 11 - c.side * 13 + Vector3.new(0, 1.2, 0) end, look = function(c) return chestAt(c):Lerp(c.gate, 0.2) end, fov = 62 },
	-- the gate erupts behind him: him in front, the gate far behind
	{ t = 38.4, pos = function(c) return chestAt(c) + c.L.LookVector * 9 - c.side * 15 + Vector3.new(0, 1.2, 0) end, look = function(c) return chestAt(c):Lerp(c.gate, 0.26) end, fov = 62 },
	{ t = 39.6, pos = function(c) return chestAt(c) + c.L.LookVector * 8 - c.side * 14 + Vector3.new(0, 1.4, 0) end, look = function(c) return chestAt(c):Lerp(c.gate, 0.55) end, fov = 44 },
	{ t = 41.4, pos = function(c) return chestAt(c) + c.L.LookVector * 7 - c.side * 12 + Vector3.new(0, 1.5, 0) end, look = function(c) return chestAt(c):Lerp(c.gate, 0.25) end, fov = 56 },
	{ t = 44.0, pos = function(c) return chestAt(c) + c.L.LookVector * 4.5 - c.side * 6 + Vector3.new(0, 0.6, 0) end, look = function(c) return chestAt(c) + Vector3.new(0, 0.6, 0) end, fov = 50 },
	{ t = 45.0, pos = function(c) return chestAt(c) + c.L.LookVector * 4.2 - c.side * 5.6 + Vector3.new(0, 0.6, 0) end, look = function(c) return chestAt(c) + Vector3.new(0, 0.6, 0) end, fov = 49 },
}

local function cameraAt(T, c)
	local n = #KEYS
	local i = 1
	while i < n - 1 and KEYS[i + 1].t <= T do
		i += 1
	end
	local k0, k1 = KEYS[i], KEYS[i + 1]
	-- (a cut: the shot before it holds its last key until the cut; the next shot starts fresh)
	if k1.cut and T < k1.t then
		local p, l = k0.pos(c), k0.look(c)
		return p, l, k0.fov
	end
	if T >= k1.t and i + 1 == n then
		return k1.pos(c), k1.look(c), k1.fov
	end
	local kp = (k0.cut or i == 1) and k0 or KEYS[i - 1]
	local kn = (i + 2 > n or KEYS[i + 2].cut) and k1 or KEYS[i + 2]
	local h = k1.t - k0.t
	local s = math.clamp((T - k0.t) / h, 0, 1)
	local s2, s3 = s * s, s * s * s
	local h00, h10, h01, h11 = 2 * s3 - 3 * s2 + 1, s3 - 2 * s2 + s, -2 * s3 + 3 * s2, s3 - s2
	local function slope(dPrev, dNext)
		if dPrev * dNext <= 0 then
			return 0
		end
		return 2 * dPrev * dNext / (dPrev + dNext)
	end
	local function spline1(p0, p1, pp, pn)
		local d = (p1 - p0) / h
		local first = kp == k0
		local last = kn == k1
		local dPrev = first and d or (p0 - pp) / math.max(0.001, k0.t - kp.t)
		local dNext = last and d or (pn - p1) / math.max(0.001, kn.t - k1.t)
		local m0 = first and d or slope(dPrev, d)
		local m1 = last and d or slope(d, dNext)
		return p0 * h00 + m0 * h * h10 + p1 * h01 + m1 * h * h11
	end
	local function spline3(get)
		local p0, p1, pp, pn = get(k0), get(k1), get(kp), get(kn)
		return Vector3.new(spline1(p0.X, p1.X, pp.X, pn.X), spline1(p0.Y, p1.Y, pp.Y, pn.Y), spline1(p0.Z, p1.Z, pp.Z, pn.Z))
	end
	local pos = spline3(function(k) return k.pos(c) end)
	local look = spline3(function(k) return k.look(c) end)
	return pos, look, math.clamp(spline1(k0.fov, k1.fov, kp.fov, kn.fov), 20, 90)
end

-- ============================================================
-- The world part (every player)
-- ============================================================
local function world(folder, ctx)
	local st = {}
	-- the round he seats
	local seated = newPart(folder, Vector3.new(0.09, 0.09, 0.3), VIOLET_CORE, 1)

	-- ── the aura: cracks on the ground under his perch, debris that lifts and then circles his energy
	local cracks = {}
	for i = 1, 10 do
		local a = (i / 10) * math.pi * 2 + math.random() * 0.4
		local len = 3 + math.random() * 6
		local c = newPart(folder, Vector3.new(0.25, 0.08, len), VIOLET_CORE, 1)
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		c.CFrame = CFrame.lookAt(ctx.floor + dir * (1 + len / 2) + Vector3.new(0, 0.06, 0), ctx.floor + dir * (2 + len))
		cracks[i] = c
	end
	local rocks = {}
	for i = 1, DEBRIS do
		local s = 0.4 + math.random() ^ 2 * 1.6
		local r = newPart(folder, Vector3.new(s, s * (0.6 + math.random() * 0.6), s * (0.7 + math.random() * 0.5)),
			Color3.fromRGB(56 + math.random(0, 18), 52 + math.random(0, 14), 60 + math.random(0, 16)), 1, nil, Enum.Material.Slate)
		local a = math.random() * math.pi * 2
		local start = ctx.floor + Vector3.new(math.cos(a), 0, math.sin(a)) * (3 + math.random() * 10) + Vector3.new(0, s * 0.3, 0)
		rocks[i] = { part = r, start = start, lift = 1 + math.random() * 4, radius = 6 + math.random() * 12,
			tilt = (math.random() - 0.5) * 1.4, phase = math.random() * math.pi * 2, speed = (0.5 + math.random() * 0.6) * (math.random() < 0.5 and -1 or 1),
			spin = Vector3.new(math.random(), math.random(), math.random()) * 2, angle = 0, height = (math.random() - 0.5) * 10,
			vel = nil, pos = start }
	end
	-- the aura's light round him (sparks rising off him while he charges)
	local auraHolder = newPart(folder, Vector3.one * 4, WHITE, 1, Enum.PartType.Ball)
	local auraFx = Instance.new("ParticleEmitter")
	auraFx.Texture = SPARK
	auraFx.Color = ColorSequence.new(VIOLET_CORE, VIOLET)
	auraFx.LightEmission = 1
	auraFx.LightInfluence = 0
	auraFx.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0.05) })
	auraFx.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	auraFx.Lifetime = NumberRange.new(0.6, 1.2)
	auraFx.Speed = NumberRange.new(3, 8)
	auraFx.Acceleration = Vector3.new(0, 6, 0)
	auraFx.SpreadAngle = Vector2.new(180, 180)
	auraFx.Shape = Enum.ParticleEmitterShape.Sphere
	auraFx.Rate = 0
	auraFx.Parent = auraHolder
	local auraLight = Instance.new("PointLight")
	auraLight.Color = VIOLET
	auraLight.Range = 24
	auraLight.Brightness = 0
	auraLight.Shadows = false
	auraLight.Parent = auraHolder

	-- ── the moon: behind him as seen from the peak shot
	local moon = newPart(folder, Vector3.new(0.5, ctx.moonR * 2, ctx.moonR * 2), MOON, 1, Enum.PartType.Cylinder)
	moon.CFrame = CFrame.lookAt(ctx.moonAt, ctx.moonAt - ctx.moonDir) * CFrame.Angles(0, math.pi / 2, 0)
	local moonHalo = newPart(folder, Vector3.new(0.4, ctx.moonR * 2.5, ctx.moonR * 2.5), VIOLET_DEEP, 1, Enum.PartType.Cylinder)
	moonHalo.CFrame = moon.CFrame * CFrame.new(0.4, 0, 0)

	-- ── the arsenal: a wheel of giant rifles round his line of fire, each in its own magic circle
	local tpl = rifleTemplate()
	local giants = {}
	for i = 1, (tpl and GIANTS or 0) do
		local a = (i - 0.5) / GIANTS * math.pi * 2
		giants[i] = {
			rifle = buildGiant(folder, tpl),
			circle = VeyrSights.build(folder, 6.5, VIOLET, VIOLET_CORE, { segments = 28, innerCount = 16 }),
			circle2 = VeyrSights.build(folder, 4.6, VIOLET_DEEP, VIOLET_CORE, { segments = 20, inner = false, spikes = false }),
			a = a, born = F.ARSENAL + (i - 1) * 0.18, out = F.GIANTS_OUT + (i - 1) * 0.15,
			laser = newPart(folder, Vector3.new(0.25, 0.25, 1), VIOLET_CORE, 1),
			round = newPart(folder, Vector3.new(1.6, 1.6, 14), WHITE, 1),
			roundGlow = newPart(folder, Vector3.new(4, 4, 18), VIOLET, 1, Enum.PartType.Ball),
			light = newPart(folder, Vector3.one * 2.4, VIOLET_CORE, 1, Enum.PartType.Ball),
		}
	end
	-- his own: laser, round, the light along his rifle
	local myLaser = newPart(folder, Vector3.new(0.07, 0.07, 1), VIOLET_CORE, 1)
	local myRound = newPart(folder, Vector3.new(0.35, 0.35, 3), WHITE, 1)
	local myGlow = newPart(folder, Vector3.new(1.2, 1.2, 4), VIOLET, 1, Enum.PartType.Ball)
	local myLight = newPart(folder, Vector3.one * 0.5, VIOLET_CORE, 1, Enum.PartType.Ball)
	-- the energy drawn up the lasers (dashes running from the gate to the muzzles)
	local dashes = {}
	for i = 1, (GIANTS + 1) * 2 do
		dashes[i] = newPart(folder, Vector3.new(0.4, 0.4, 3), WHITE, 1)
	end
	-- the gate's cracks after the hit
	local gateCracks = {}
	for i = 1, 14 do
		local a = (i / 14) * math.pi * 2 + math.random() * 0.3
		gateCracks[i] = { part = newPart(folder, Vector3.new(0.4, 1, 0.2), VIOLET_CORE, 1), a = a, len = 4 + math.random() * 8 }
	end
	-- the black hole where the rounds strike: a black core, a glowing rim facing the camera, two tilted accretion rings,
	-- smoke and sparks drawn in; it grows, swallows the gate's debris, implodes and bursts
	local hole = {
		core = newPart(folder, Vector3.one, Color3.new(0, 0, 0), 1, Enum.PartType.Ball, Enum.Material.SmoothPlastic),
		rim = VeyrSights.build(folder, 1, VIOLET_CORE, WHITE, { segments = 36, inner = false, spikes = false, ticks = false, nodes = false }),
		disc1 = VeyrSights.build(folder, 1, VIOLET, VIOLET_CORE, { segments = 44, innerCount = 18, spikes = false, ticks = false }),
		disc2 = VeyrSights.build(folder, 1, VIOLET_DEEP, VIOLET, { segments = 36, inner = false, spikes = false, ticks = false, nodes = false }),
		shell = newPart(folder, Vector3.one * 8, WHITE, 1, Enum.PartType.Ball),
		spin = 0,
	}
	do
		local e = Instance.new("ParticleEmitter")
		e.Texture = SPARK
		e.Color = ColorSequence.new(VIOLET_CORE, VIOLET)
		e.LightEmission = 1
		e.LightInfluence = 0
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 0.1) })
		e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.2), NumberSequenceKeypoint.new(1, 0.7) })
		e.Lifetime = NumberRange.new(0.6, 0.9)
		e.Speed = NumberRange.new(-14, -9) -- (in: they spawn on the shell)
		e.Shape = Enum.ParticleEmitterShape.Sphere
		e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
		e.Rate = 0
		e.Parent = hole.shell
		hole.sparks = e
		local m = Instance.new("ParticleEmitter")
		m.Texture = SMOKE
		m.Color = ColorSequence.new(Color3.fromRGB(40, 30, 64), Color3.fromRGB(10, 8, 16))
		m.LightInfluence = 0
		m.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 3), NumberSequenceKeypoint.new(1, 0.6) })
		m.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.45), NumberSequenceKeypoint.new(1, 0.9) })
		m.Lifetime = NumberRange.new(0.8, 1.2)
		m.Speed = NumberRange.new(-10, -6)
		m.Shape = Enum.ParticleEmitterShape.Sphere
		m.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
		m.RotSpeed = NumberRange.new(-90, 90)
		m.Rate = 0
		m.Parent = hole.shell
		hole.smoke = m
	end
	-- the gate's chunks (thrown out when it erupts, then swallowed)
	local chunks = {}
	for i = 1, 46 do
		local sz = 1 + math.random() * 2.8
		chunks[i] = { part = newPart(folder, Vector3.new(sz, sz * (0.5 + math.random() * 0.6), sz * (0.6 + math.random() * 0.5)),
			Color3.fromRGB(116 + math.random(0, 30), 108 + math.random(0, 26), 98 + math.random(0, 22)), 1, nil, Enum.Material.Slate),
			spin = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 6 }
	end
	local fired, impacted, erupted, crumbled = false, false, false, false
	local hiddenGate = {}

	-- where each giant sits: round his line of fire (the wheel's axis = his aim), a little behind him
	local function giantCF(g, T)
		local chest = ctx.chest and ctx.chest.Position or ctx.peak
		local aimDir = (ctx.gate - chest).Unit
		local right = aimDir:Cross(Vector3.yAxis).Unit
		local up = right:Cross(aimDir).Unit
		local wheelSpin = 0.12 * math.sin(T * 0.4) * (1 - ease(T, F.STILL - 0.5, F.STILL))
		local a = g.a + wheelSpin
		local centre = chest + (right * math.cos(a) + up * math.sin(a)) * WHEEL_R - aimDir * 6
		-- sliding out of its circle along its aim, then swinging from pointing up into the line of fire
		local out = ease(T, g.out, g.out + 1.4)
		local swing = ease(T, F.GIANTS_AIM - 0.4 + (g.a % 1) * 0.3, F.GIANTS_AIM + 0.8)
		local aimAt = ctx.gate + Vector3.new(0, 3, 0)
		local finalDir = (aimAt - centre).Unit
		local raised = (finalDir + up * 1.4).Unit
		local dir = raised:Lerp(finalDir, swing).Unit
		local back = (1 - out) * g.rifle.length * 0.9
		local pos = centre - dir * back
		return CFrame.lookAt(pos, pos + dir), centre, dir
	end

	local function laserTo(part, from, to, width, alpha)
		local d = (to - from).Magnitude
		part.Size = Vector3.new(width, width, math.max(0.1, d))
		part.CFrame = CFrame.lookAt(from:Lerp(to, 0.5), to)
		part.Transparency = 1 - alpha
	end

	local function update(T, dt)
		local chest = ctx.chest and ctx.chest.Position or ctx.peak
		-- ── the round he seats
		local ej = ctx.ejection
		if ej and T >= F.MARKSMAN + 0.8 and T < F.SEAT + 0.2 then
			local k = ease(T, F.MARKSMAN + 1.0, F.SEAT)
			local into = ej.WorldPosition
			local from = into + ej.WorldCFrame.RightVector * 0.6 + Vector3.new(0, 0.25, 0)
			seated.CFrame = CFrame.lookAt(from:Lerp(into, k), into + ej.WorldCFrame.LookVector)
			seated.Transparency = 0.1 + 0.6 * ease(T, F.SEAT - 0.1, F.SEAT + 0.2)
		else
			seated.Transparency = 1
		end

		-- ── the aura
		local auraOn = ease(T, F.AURA, F.AURA + 1.5) * (1 - ease(T, F.FIRE, F.FIRE + 0.5))
		for _, c in ipairs(cracks) do
			c.Transparency = 1 - 0.85 * ease(T, F.AURA, F.AURA + 0.8) * (1 - ease(T, F.ASCENT_FROM + 2, F.ASCENT_FROM + 5))
		end
		local charge = ease(T, F.CHARGE, F.STILL)
		local still = ease(T, F.STILL, F.STILL + 0.3) * (1 - ease(T, F.FIRE, F.FIRE + 0.02))
		auraHolder.CFrame = CFrame.new(chest)
		auraFx.Rate = (20 + 80 * charge) * auraOn * (1 - still)
		auraLight.Brightness = (1.5 + 4 * charge) * auraOn * (1 - 0.7 * still)
		if not st.auraStarted and T >= F.AURA then
			st.auraStarted = true
			if T < F.AURA + 1 then
				burst(folder, ctx.floor + Vector3.new(0, 0.5, 0), Vector3.yAxis, 30, { color = Color3.fromRGB(80, 74, 70),
					size0 = 1.4, size1 = 5, speed0 = 6, speed1 = 16, spread = 85, life0 = 1, life1 = 2, t0 = 0.4 })
			end
		end
		-- the debris: lifts off the ground, then follows him up and circles his energy; still in the quiet; blown away
		local follow = ease(T, F.ASCENT_FROM - 0.4, F.ASCENT_FROM + 2.4)
		local speedMul = (1 + 2.2 * charge) * (1 - still)
		for _, r in ipairs(rocks) do
			if T < F.AURA then
				r.part.Transparency = 1
			elseif r.vel then
				-- (blown outward by the shot)
				r.vel += Vector3.new(0, -30, 0) * dt
				r.pos += r.vel * dt
				r.part.CFrame = CFrame.new(r.pos) * CFrame.Angles(T * r.spin.X * 4, T * r.spin.Y * 4, 0)
				r.part.Transparency = ease(T, F.FIRE + 0.4, F.FIRE + 1.6)
			else
				r.angle += r.speed * speedMul * dt
				local lifted = r.start + Vector3.new(0, r.lift * ease(T, F.AURA, F.AURA + 2) + math.sin(T * 2 + r.phase) * 0.3 * (1 - still), 0)
				local a = r.angle + r.phase
				local ring = CFrame.Angles(r.tilt, 0, 0) * Vector3.new(math.cos(a) * r.radius, r.height * 0.3, math.sin(a) * r.radius)
				local orbitPos = chest + ring
				r.pos = lifted:Lerp(orbitPos, follow)
				r.part.CFrame = CFrame.new(r.pos) * CFrame.Angles(r.angle * r.spin.X, r.angle * r.spin.Y, 0)
				r.part.Transparency = 1 - ease(T, F.AURA, F.AURA + 0.6)
				if T >= F.FIRE then
					r.vel = (r.pos - chest).Unit * (30 + math.random() * 40)
				end
			end
		end

		-- ── the moon
		local mIn = ease(T, F.MOON - 0.5, F.MOON + 1.5) * (1 - ease(T, F.FADE, F.FADE + 3))
		moon.Transparency = 1 - 0.97 * mIn
		moonHalo.Transparency = 1 - 0.5 * mIn

		-- ── the arsenal
		local crumble = ease(T, F.CRUMBLE, F.CRUMBLE + 1.8)
		for gi, g in ipairs(giants) do
			local cf, centre, dir = giantCF(g, T)
			local open = ease(T, g.born, g.born + 0.6)
			local circleAlpha = math.min(1, open * 1.3) * (1 - crumble) * (1 - 0.6 * ease(T, g.out + 1.2, g.out + 2.4))
			if circleAlpha > 0.001 then
				local ccf = CFrame.lookAt(centre + dir * g.rifle.length * 0.1, centre + dir * 2)
				g.spin = (g.spin or gi) + dt * (1.5 * (1 - charge * 0.3) * (1 - still) + 0.05)
				VeyrSights.place(g.circle, ccf, 0.2 + 0.8 * backOut(math.clamp(open, 0, 1)), circleAlpha, g.spin)
				VeyrSights.place(g.circle2, ccf * CFrame.new(0, 0, -0.3), 0.2 + 0.8 * math.clamp(open, 0, 1), circleAlpha * 0.9, -g.spin * 1.4)
			else
				VeyrSights.hide(g.circle)
				VeyrSights.hide(g.circle2)
			end
			local shown = ease(T, g.out, g.out + 0.6) * (1 - crumble)
			placeGiant(g.rifle, cf, shown)
			local muzzle = (cf * g.rifle.muzzle).Position
			g.muzzlePos = muzzle
			-- its laser
			local lOn = ease(T, F.LOCK + gi * 0.06, F.LOCK + gi * 0.06 + 0.25) * (1 - ease(T, F.FIRE - 0.05, F.FIRE))
			if lOn > 0.001 then
				local flick = 0.75 + 0.25 * math.sin(T * 30 + gi)
				laserTo(g.laser, muzzle, ctx.gate + Vector3.new(0, 3, 0), 0.25, lOn * (0.85 - 0.6 * still) * flick)
			else
				g.laser.Transparency = 1
			end
			-- the light running along it, stock to barrel, in the quiet
			local run = (T - F.LIGHT_RUN - gi * 0.04) / (F.LIGHT_END - F.LIGHT_RUN - 0.3)
			if run > 0 and run < 1 then
				g.light.CFrame = CFrame.new(cf.Position:Lerp(muzzle, run))
				g.light.Transparency = 0.15 + 0.5 * math.abs(run - 0.5)
			else
				g.light.Transparency = 1
			end
			-- crumbling: sparks pour off it as it fades
			if crumble > 0 and not g.crumbled then
				g.crumbled = true
				for k = 0, 3 do
					burst(folder, cf.Position:Lerp(muzzle, k / 3), Vector3.new(0, -1, 0), 22, { texture = SPARK, color = VIOLET_CORE,
						color2 = VIOLET, emission = 1, size0 = 0.6, size1 = 0.05, speed0 = 2, speed1 = 8, spread = 60, life0 = 1.2,
						life1 = 2.4, drag = 0.5, accel = Vector3.new(0, -18, 0), t0 = 0 })
				end
			end
		end
		-- his own laser and light
		local myMuzzle = ctx.muzzle and ctx.muzzle.WorldPosition or chest
		local myOn = ease(T, F.LOCK, F.LOCK + 0.25) * (1 - ease(T, F.FIRE - 0.05, F.FIRE))
		if myOn > 0.001 then
			laserTo(myLaser, myMuzzle, ctx.gate + Vector3.new(0, 3, 0), 0.07, myOn * (0.9 - 0.5 * still))
		else
			myLaser.Transparency = 1
		end
		local myRun = (T - F.LIGHT_RUN) / (F.LIGHT_END - F.LIGHT_RUN - 0.3)
		if myRun > 0 and myRun < 1 and ctx.rifleRoot then
			myLight.CFrame = CFrame.new(ctx.rifleRoot.Position:Lerp(myMuzzle, myRun))
			myLight.Transparency = 0.2
		else
			myLight.Transparency = 1
		end
		-- the energy drawn up the lasers into the muzzles while he charges
		local draw = charge * (1 - still) * (1 - ease(T, F.FIRE - 0.05, F.FIRE))
		local muzzles = { myMuzzle }
		for _, g in ipairs(giants) do
			table.insert(muzzles, g.muzzlePos or myMuzzle)
		end
		for i, d in ipairs(dashes) do
			local m = muzzles[(i - 1) % #muzzles + 1]
			if draw > 0.01 and m then
				local u = (T * 0.9 + i * 0.37) % 1
				local to = ctx.gate + Vector3.new(0, 3, 0)
				local at = to:Lerp(m, u)
				d.CFrame = CFrame.lookAt(at, m)
				d.Transparency = 1 - draw * 0.8 * math.sin(u * math.pi)
			else
				d.Transparency = 1
			end
		end

		-- ── fire: every weapon at once
		if not fired and T >= F.FIRE then
			fired = true
			st.froms = { myMuzzle }
			for _, g in ipairs(giants) do
				table.insert(st.froms, g.muzzlePos or myMuzzle)
			end
			if T < F.FIRE + 0.5 then
				for k, p in ipairs(st.froms) do
					flash(folder, p, VIOLET, k == 1 and 1 or 3, k == 1 and 5 or 14, 0.2, 40, 8)
				end
				shockDisc(folder, chest, (ctx.gate - chest).Unit, 4, WHEEL_R * 2.8, 0.6, VIOLET_CORE, 0.45)
				Sfx.playAt("veyr_crack", chest, 1.5, 0.7, 900)
				ctx.shake = 0.6
			end
		end
		if fired then
			local flight = F.IMPACT - F.FIRE
			local p = math.clamp((T - F.FIRE) / flight, 0, 1)
			local to = ctx.gate + Vector3.new(0, 3, 0)
			local function fly(core, glow, from)
				if p < 1 then
					local at = from:Lerp(to, p ^ 1.3)
					core.CFrame = CFrame.lookAt(at, to)
					glow.CFrame = core.CFrame
					core.Transparency = 0
					glow.Transparency = 0.35
				else
					core.Transparency = 1
					glow.Transparency = 1
				end
			end
			fly(myRound, myGlow, st.froms[1])
			for gi, g in ipairs(giants) do
				fly(g.round, g.roundGlow, st.froms[gi + 1])
			end
		end
		-- ── the hit: the keeper's hands are blown back, the gate vanishes in smoke; it still stands
		if not impacted and T >= F.IMPACT then
			impacted = true
			if T < F.IMPACT + 0.6 then
				local g = ctx.gate
				local n = -ctx.L.LookVector
				flash(folder, g + n * 2, VIOLET, 6, 40, 0.5, 60, 14)
				shockDisc(folder, g + n, n, 3, 42, 0.8, VIOLET_CORE, 0.35)
				burst(folder, g + n * 2 + Vector3.new(0, 4, 0), n, 90, { color = Color3.fromRGB(60, 54, 70), color2 = Color3.fromRGB(26, 22, 34),
					size0 = 6, size1 = 18, speed0 = 10, speed1 = 30, spread = 70, life0 = 2.2, life1 = 3.6, drag = 1.6, accel = Vector3.new(0, 1, 0), t0 = 0.15 })
				burst(folder, g + n * 2, n, 80, { texture = SPARK, color = WHITE, color2 = VIOLET, emission = 1, size0 = 1.2,
					size1 = 0.1, speed0 = 30, speed1 = 90, spread = 75, life0 = 0.5, life1 = 1.2, drag = 1.5, accel = Vector3.new(0, -40, 0), t0 = 0 })
				Sfx.playAt("veyr_impact", g, 1.6, 0.7, 900)
				Sfx.playAt("gate_collapse", g, 0.5, 1.3, 900)
				ctx.shake = 1
			end
		end
		-- the cracks spreading over the gate, brighter and brighter until it erupts
		local spread = ease(T, F.IMPACT + 1, F.GATE_HIT - 0.3)
		local hot = ease(T, F.GATE_HIT - 1.2, F.GATE_HIT) * (1 - ease(T, F.GATE_HIT, F.GATE_HIT + 0.2))
		for _, c in ipairs(gateCracks) do
			if spread > 0.01 and T < F.GATE_HIT + 0.1 then
				local len = c.len * spread
				local face = CFrame.lookAt(ctx.gate + Vector3.new(0, 5, 0) - ctx.L.LookVector * 0.9, ctx.gate + Vector3.new(0, 5, 0) - ctx.L.LookVector * 5)
				c.part.Size = Vector3.new(0.35 + 0.3 * hot, len, 0.2)
				c.part.CFrame = face * CFrame.Angles(0, 0, c.a) * CFrame.new(0, 0.5 + len / 2, 0)
				c.part.Transparency = 0.35 - 0.3 * hot
				c.part.Color = hot > 0.5 and WHITE or VIOLET_CORE
			else
				c.part.Transparency = 1
			end
		end
		if not crumbled and T >= F.CRUMBLE then
			crumbled = true
		end
		-- ── the black hole: opens where the rounds struck, grows while he turns away; when the gate erupts (the server
		-- breaks it now) it swells, swallows the chunks, implodes to a point and bursts (a shockwave down the lane)
		-- (the user: more massive, and massive early: it tears open right after the hit, is already huge while he
		-- descends, and swells to swallow the whole gate when it erupts)
		local IMPLODE, BURST = F.GATE_HIT + 2.2, F.GATE_HIT + 2.6
		local r = 0
		if T >= F.IMPACT then
			r = 3 + 13 * ease(T, F.IMPACT, F.IMPACT + 2.2) + 6 * ease(T, F.IMPACT + 2.2, F.GATE_HIT) + 20 * ease(T, F.GATE_HIT, F.GATE_HIT + 1.6)
			r *= 1 - ease(T, IMPLODE, BURST) ^ 0.6
			r += math.sin(T * 9) * 0.05 * r * (1 - ease(T, IMPLODE, BURST))
		end
		-- (it rises as it grows, so it never sinks into the ground)
		local holeAt = ctx.gate + Vector3.new(0, 4 + r * 0.55, 0) - ctx.L.LookVector * 2
		local camPos = workspace.CurrentCamera and workspace.CurrentCamera.CFrame.Position or ctx.peak
		if r > 0.05 and T < BURST then
			hole.spin += dt * (0.8 + 3 * ease(T, F.GATE_HIT, IMPLODE))
			hole.core.Size = Vector3.one * (r * 2)
			hole.core.CFrame = CFrame.new(holeAt)
			hole.core.Transparency = 0
			local facing = CFrame.lookAt(holeAt, camPos)
			VeyrSights.place(hole.rim, facing, r * 1.08, 0.9, hole.spin * 0.3)
			local tilt = CFrame.new(holeAt) * CFrame.Angles(math.rad(72), hole.spin * 0.2, math.rad(12))
			VeyrSights.place(hole.disc1, tilt * CFrame.Angles(math.pi / 2, 0, 0), r * 2.3, 0.85, hole.spin)
			VeyrSights.place(hole.disc2, tilt * CFrame.Angles(math.pi / 2, 0, 0), r * 1.7, 0.7, -hole.spin * 1.6)
			hole.shell.Size = Vector3.one * math.max(4, r * 5)
			hole.shell.CFrame = CFrame.new(holeAt)
			local pull = ease(T, F.IMPACT, F.IMPACT + 1) * (1 + 2.5 * ease(T, F.GATE_HIT, F.GATE_HIT + 1))
			hole.sparks.Rate = 40 * pull
			hole.smoke.Rate = 18 * pull
			hole.sparks.Speed = NumberRange.new(-r * 3.2, -r * 2.2)
			hole.smoke.Speed = NumberRange.new(-r * 2.2, -r * 1.5)
		else
			hole.core.Transparency = 1
			VeyrSights.hide(hole.rim)
			VeyrSights.hide(hole.disc1)
			VeyrSights.hide(hole.disc2)
			hole.sparks.Rate = 0
			hole.smoke.Rate = 0
		end
		-- the eruption: the gate's chunks burst out, then curve back and are swallowed
		if not erupted and T >= F.GATE_HIT then
			erupted = true
			if T < F.GATE_HIT + 1 then
				local g = ctx.gate
				local n = -ctx.L.LookVector
				flash(folder, holeAt, VIOLET, 4, 26, 0.4, 60, 10)
				for _, c in ipairs(chunks) do
					local start = g + ctx.L.RightVector * (math.random() - 0.5) * 36 + Vector3.new(0, 1 + math.random() * 16, 0)
					c.pos = start
					c.vel = (start - holeAt).Unit * (18 + math.random() * 22) + n * (6 + math.random() * 14) + Vector3.new(0, 8, 0)
					c.alive = true
				end
				burst(folder, g + n * 2, n, 60, { color = Color3.fromRGB(96, 90, 86), size0 = 3, size1 = 12, speed0 = 16,
					speed1 = 40, spread = 75, life0 = 1, life1 = 2.2, t0 = 0.3 })
				Sfx.playAt("gate_collapse", g, 1, 1, 900)
				Sfx.playAt("veyr_collapse", holeAt, 1, 0.7, 900)
				task.delay(0.6, function() Sfx.playAt("keeper_roar", g + Vector3.new(0, 30, 0), 0.9, 1, 900) end)
				ctx.shake = 0.8
				-- (preview: the gate is only hidden on this screen; for real the server breaks it at this very moment)
				if ctx.preview then
					local params = OverlapParams.new()
					params.FilterType = Enum.RaycastFilterType.Exclude
					params.FilterDescendantsInstances = { folder }
					for _, part in ipairs(workspace:GetPartBoundsInBox(CFrame.new(g + Vector3.new(0, 9, 0)), Vector3.new(44, 30, 14), params)) do
						if part.Size.Magnitude < 90 and part.LocalTransparencyModifier < 1 then
							part.LocalTransparencyModifier = 1
							table.insert(hiddenGate, part)
						end
					end
				end
			end
		end
		for _, c in ipairs(chunks) do
			if c.alive then
				local toHole = holeAt - c.pos
				local d = toHole.Magnitude
				local age = T - F.GATE_HIT
				-- (thrown out first, then the pull wins: harder and harder, the chunks spiral in)
				local pullK = ease(age, 0.25, 1.1)
				c.vel += toHole.Unit * (140 * pullK) * dt + toHole.Unit:Cross(Vector3.yAxis) * (30 * pullK) * dt
				c.vel *= 1 - math.min(0.9, dt * 1.2 * pullK)
				c.pos += c.vel * dt
				local shrink = math.clamp(d / math.max(1, r * 1.6), 0, 1)
				c.part.CFrame = CFrame.new(c.pos) * CFrame.Angles(age * c.spin.X, age * c.spin.Y, age * c.spin.Z)
				c.part.Transparency = 1 - shrink
				if d < r * 0.9 or T >= IMPLODE then
					c.alive = false
					c.part.Transparency = 1
				end
			end
		end
		-- the implosion's burst: a flash, a shockwave down the lane past his perch, sparks, the dust wall reaching him
		if not st.burst and T >= BURST then
			st.burst = true
			if T < BURST + 1 then
				local g = ctx.gate
				flash(folder, holeAt, VIOLET, 2, 46, 0.5, 60, 14)
				shockDisc(folder, g + Vector3.new(0, 1, 0), Vector3.yAxis, 2, ctx.laneDist + 30, 1.6, VIOLET, 0.3)
				shockDisc(folder, holeAt, (camPos - holeAt).Unit, 2, 50, 0.8, VIOLET_CORE, 0.3)
				burst(folder, holeAt, Vector3.yAxis, 120, { texture = SPARK, color = WHITE, color2 = VIOLET, emission = 1,
					size0 = 1.4, size1 = 0.1, speed0 = 40, speed1 = 110, spread = 180, life0 = 0.6, life1 = 1.6, drag = 1.5,
					accel = Vector3.new(0, -20, 0), t0 = 0 })
				Sfx.playAt("veyr_collapse", holeAt, 1.6, 1.1, 900)
				ctx.shake = 1
				task.delay(math.clamp(ctx.laneDist / 180, 0.4, 1.6), function()
					if folder.Parent then
						burst(folder, ctx.floor + Vector3.new(0, 1, 0), ctx.L.LookVector * -1, 40, { color = Color3.fromRGB(90, 84, 80),
							size0 = 4, size1 = 12, speed0 = 30, speed1 = 60, spread = 40, life0 = 1, life1 = 2, t0 = 0.4 })
					end
				end)
			end
		end
		if ctx.shake then
			ctx.shake = math.max(0, ctx.shake - dt * 0.9)
		end
	end
	local function cleanup()
		for _, p in ipairs(hiddenGate) do
			if p.Parent then
				p.LocalTransparencyModifier = 0
			end
		end
	end
	return update, cleanup
end

-- ============================================================
-- The watchers' screen: the scope vignette, the impact frames, the shatter
-- ============================================================
local function screen(ui)
	local scope = Instance.new("Frame")
	scope.AnchorPoint = Vector2.new(0.5, 0.5)
	scope.Position = UDim2.fromScale(0.5, 0.5)
	scope.BackgroundTransparency = 1
	scope.Visible = false
	scope.ZIndex = 3
	scope.Parent = ui
	Instance.new("UICorner", scope).CornerRadius = UDim.new(0.5, 0)
	local edge = Instance.new("UIStroke")
	edge.Color = Color3.new(0, 0, 0)
	edge.Thickness = 2400
	edge.Parent = scope
	local rimFrame = Instance.new("Frame")
	rimFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	rimFrame.Position = UDim2.fromScale(0.5, 0.5)
	rimFrame.Size = UDim2.fromScale(1, 1)
	rimFrame.BackgroundTransparency = 1
	rimFrame.Parent = scope
	Instance.new("UICorner", rimFrame).CornerRadius = UDim.new(0.5, 0)
	local rim = Instance.new("UIStroke")
	rim.Color = VIOLET
	rim.Thickness = 2
	rim.Transparency = 0.3
	rim.Parent = rimFrame
	local reticle = {}
	for k = 0, 3 do
		local f = Instance.new("Frame")
		f.BackgroundColor3 = Color3.new(0, 0, 0)
		f.BackgroundTransparency = 0.25
		f.BorderSizePixel = 0
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		local horizontal = k % 2 == 0
		f.Size = horizontal and UDim2.new(0.38, 0, 0, 2) or UDim2.new(0, 2, 0.38, 0)
		local off = 0.31 * ((k < 2) and -1 or 1)
		f.Position = horizontal and UDim2.fromScale(0.5 + off, 0.5) or UDim2.fromScale(0.5, 0.5 + off)
		f.Parent = scope
		table.insert(reticle, f)
	end
	-- the impact frames: a white frame, a black frame with white speed lines, then the grade (in play)
	local whiteF = Instance.new("Frame")
	whiteF.Size = UDim2.fromScale(1, 1)
	whiteF.BackgroundColor3 = WHITE
	whiteF.BackgroundTransparency = 1
	whiteF.BorderSizePixel = 0
	whiteF.ZIndex = 6
	whiteF.Parent = ui
	local blackF = Instance.new("Frame")
	blackF.Size = UDim2.fromScale(1, 1)
	blackF.BackgroundColor3 = Color3.new(0, 0, 0)
	blackF.BackgroundTransparency = 1
	blackF.BorderSizePixel = 0
	blackF.ZIndex = 6
	blackF.Parent = ui
	local lines = {}
	for i = 1, 40 do
		local l = Instance.new("Frame")
		l.AnchorPoint = Vector2.new(0, 0.5)
		l.BackgroundColor3 = WHITE
		l.BorderSizePixel = 0
		local rot = (i / 40) * 360 + math.random() * 5
		l.Rotation = rot
		l.Position = UDim2.new(0.5 + math.cos(math.rad(rot)) * 0.08, 0, 0.5 + math.sin(math.rad(rot)) * 0.14, 0)
		l.Size = UDim2.new(0.3 + math.random() * 0.4, 0, 0, math.random(2, 5))
		l.BackgroundTransparency = 1
		l.ZIndex = 7
		l.Parent = ui
		lines[i] = l
	end
	-- the shatter of the scope picture at the hit
	local shards = {}
	for i = 1, 22 do
		local s = Instance.new("Frame")
		s.AnchorPoint = Vector2.new(0.5, 0.5)
		s.BackgroundColor3 = Color3.fromRGB(180, 170, 230)
		s.BackgroundTransparency = 1
		s.BorderSizePixel = 0
		s.Size = UDim2.fromOffset(math.random(40, 160), math.random(20, 90))
		s.ZIndex = 8
		s.Parent = ui
		local st = Instance.new("UIStroke")
		st.Color = WHITE
		st.Transparency = 1
		st.Parent = s
		local a = math.random() * math.pi * 2
		shards[i] = { frame = s, stroke = st, dir = Vector2.new(math.cos(a), math.sin(a)), spin = (math.random() - 0.5) * 400,
			speed = 0.4 + math.random() * 0.9, rot = math.random() * 360 }
	end

	-- one impact frame sequence at t0: 0 .. 0.05 white, 0.05 .. 0.13 black with lines, 0.13 .. 0.2 lines fading
	local function impactFrame(T, t0, strength)
		local s = T - t0
		if s < 0 or s > 0.22 then
			return 0, 0, 0
		end
		if s < 0.05 then
			return 1, 0, 0
		elseif s < 0.13 then
			return 0, strength, 1
		end
		return 0, 0, 1 - (s - 0.13) / 0.09
	end

	return function(T, watching)
		local cam = workspace.CurrentCamera
		local vp = cam and cam.ViewportSize or Vector2.new(1920, 1080)
		-- the scope: only inside the two windows, where the camera is locked at his eyepiece
		local w1 = 0 -- (the user: one scope view is enough, right before the shot)
		local w2 = ease(T, F.SCOPE_2 + 0.05, F.SCOPE_2 + 0.4) * (1 - ease(T, F.IMPACT, F.IMPACT + 0.02))
		local close = watching and math.max(w1, w2) or 0
		scope.Visible = close > 0.001
		if scope.Visible then
			local d = vp.Y * (0.92 + 2.6 * (1 - close))
			scope.Size = UDim2.fromOffset(d, d)
			edge.Transparency = 0.02 + 0.98 * (1 - close)
			for _, f in ipairs(reticle) do
				f.BackgroundTransparency = 1 - 0.75 * close
			end
		end
		-- the impact frames (the shot, then the hit, stronger)
		local w, b, l = 0, 0, 0
		if watching then
			local w1f, b1, l1 = impactFrame(T, F.FIRE, 0.85)
			local w2f, b2, l2 = impactFrame(T, F.IMPACT, 1)
			w, b, l = math.max(w1f, w2f), math.max(b1, b2), math.max(l1, l2)
		end
		whiteF.BackgroundTransparency = 1 - w
		blackF.BackgroundTransparency = 1 - b
		for _, line in ipairs(lines) do
			line.BackgroundTransparency = 1 - l * 0.9
		end
		-- the shatter right after the hit's impact frames
		local s = watching and T - (F.IMPACT + 0.2) or -1
		local live = s >= 0 and s < 0.9
		for _, sh in ipairs(shards) do
			if live then
				local dist = sh.speed * s * 0.9
				sh.frame.Position = UDim2.fromScale(0.5 + sh.dir.X * dist, 0.5 + sh.dir.Y * dist)
				sh.frame.Rotation = sh.rot + sh.spin * s
				sh.frame.BackgroundTransparency = 0.55 + 0.45 * (s / 0.9)
				sh.stroke.Transparency = 0.2 + 0.8 * (s / 0.9)
			else
				sh.frame.BackgroundTransparency = 1
				sh.stroke.Transparency = 1
			end
		end
		return l -- (the grade goes hard black and white with the lines)
	end
end

-- ============================================================
-- Play
-- ============================================================
function VeyrFinisher.play(opts)
	opts = opts or {}
	if VeyrFinisher.active then
		return false
	end
	local startAt = opts.startAt or workspace:GetServerTimeNow()
	if workspace:GetServerTimeNow() - startAt >= DURATION - 1 then
		return false -- (too late to join)
	end
	local veyr = opts.unit
	if not veyr or not veyr.Parent then
		veyr = (not opts.spectator) and findVeyr() or nil
	end
	if not veyr then
		warn("VeyrFinisher: no Veyr in the world")
		return false
	end
	VeyrFinisher.active = true
	local camera = workspace.CurrentCamera
	local spectator = opts.spectator == true

	-- the layout: his chest, the lane (level, from his ground spot to the gate), his side, the floor under his perch
	local chest = veyr:FindFirstChild("Torso")
	local root = veyr.PrimaryPart
	local gate = opts.gate or veyr:GetAttribute("AimPos") or (root.CFrame * CFrame.new(0, 4, -80)).Position
	local V = chest and chest.Position or root.Position
	local ground = root.Position
	local L = CFrame.lookAt(ground, Vector3.new(gate.X, ground.Y, gate.Z))
	local H = CFrame.lookAt(V, Vector3.new(gate.X, V.Y, gate.Z))
	local sideSign = veyr:GetAttribute("PerchSide") or 1
	local side = L.RightVector * sideSign
	local laneDist = (Vector3.new(gate.X, 0, gate.Z) - Vector3.new(ground.X, 0, ground.Z)).Magnitude
	local scale = veyr:GetScale()
	local rifleRootPart = veyr:FindFirstChild("RifleRoot")
	local ctx = {
		chest = chest, H = H, L = L, side = side, gate = gate, ground = ground, laneDist = laneDist,
		start = camera.CFrame,
		preview = opts.preview == true,
		muzzle = veyr:FindFirstChild("Muzzle", true),
		ejection = veyr:FindFirstChild("Ejection", true),
		scopeEye = veyr:FindFirstChild("ScopeEye", true),
		rifleRoot = rifleRootPart,
	}
	-- the floor under his perch (for the aura's cracks and the debris)
	do
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { veyr }
		local hit = workspace:Raycast(V, Vector3.new(0, -60, 0), params)
		ctx.floor = hit and hit.Position or Vector3.new(V.X, ground.Y - 2, V.Z)
	end
	-- where his chest will be at the top (MarksmanAnimator flies him there: up and back along the lane)
	ctx.peak = V + Vector3.new(0, F.PEAK_HEIGHT * scale, 0) - L.LookVector * F.PEAK_BACK * scale
	-- the peak shot looks up at him from in front and below; the moon hangs behind him on that line
	ctx.peakCam = ctx.peak + L.LookVector * 30 - side * 4 - Vector3.new(0, 12, 0)
	ctx.moonDir = (ctx.peak - ctx.peakCam).Unit
	ctx.moonR = 34
	ctx.moonAt = ctx.peak + ctx.moonDir * 170
	ctx.scopeParts = {}
	for _, d in ipairs(veyr:GetDescendants()) do
		if d:IsA("BasePart") then
			table.insert(ctx.scopeParts, d)
		end
	end
	states[veyr] = { at = startAt, gate = gate }

	local fxFolder = Instance.new("Folder")
	fxFolder.Name = "FinalHorizonFx_" .. tostring(veyr:GetAttribute("OwnerId") or "?") .. "_" .. math.floor(startAt)
	fxFolder.Parent = workspace
	local worldUpdate, worldCleanup = world(fxFolder, ctx)
	-- (client-only, read by MarksmanAnimator: his poses and his flight on the same clock)
	veyr:SetAttribute("FinisherAt", startAt)
	local keeper = keeperOf(gate)
	if keeper then
		keeper:SetAttribute("SummonKind", "FinalHorizon")
		keeper:SetAttribute("SummonAt", startAt)
	end
	local devRemote = ctx.preview and RunService:IsStudio() and ReplicatedStorage:FindFirstChild("DevFinalHorizon")
	if devRemote then
		devRemote:FireServer(true)
	end

	-- ── the take-over: the owner at once, others when they press Watch ──
	local ui = Instance.new("ScreenGui")
	ui.Name = "FinalHorizonUI"
	ui.ResetOnSpawn = false
	ui.IgnoreGuiInset = true
	ui.DisplayOrder = 100
	ui.Parent = player:WaitForChild("PlayerGui")
	local updateScreen = screen(ui)
	local function bar(anchorY)
		local f = Instance.new("Frame")
		f.AnchorPoint = Vector2.new(0, anchorY)
		f.Position = UDim2.fromScale(0, anchorY)
		f.Size = UDim2.fromScale(1, 0)
		f.BackgroundColor3 = Color3.new(0, 0, 0)
		f.BorderSizePixel = 0
		f.ZIndex = 9
		f.Parent = ui
		return f
	end
	local barTop, barBottom = bar(0), bar(1)
	local skipBtn = Theme.stoneButton(ui, {
		text = "Skip", color = "stone", size = UDim2.fromOffset(120, 40),
		position = UDim2.new(1, -24, 1, -20), anchor = Vector2.new(1, 1), zIndex = 10,
	})
	skipBtn.root.Visible = false
	local watchBtn = Theme.stoneButton(ui, {
		text = "Watch the Final Horizon", color = "blue", size = UDim2.fromOffset(280, 44),
		position = UDim2.new(0.5, 0, 0, 90), anchor = Vector2.new(0.5, 0), zIndex = 10,
	})
	watchBtn.root.Visible = false
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
		caption.ZIndex = 11
		caption.Visible = false
		caption.Parent = ui
	end

	local watching = false
	local watchStart = 0
	local saved, controls
	local hiddenGuis, hiddenBoards = {}, {}
	-- the watchers' grade: darker from the ascent, hard black and white in the impact frames (restored afterwards)
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "FinalHorizonGrade"
	cc.Enabled = false
	cc.Parent = Lighting
	local function takeOver()
		if watching or not CinematicGuard.claim("FinalHorizon") then
			return
		end
		watching = true
		watchStart = workspace:GetServerTimeNow() - startAt
		saved = { cameraType = camera.CameraType, fov = camera.FieldOfView, guiEnabled = mainGui.Enabled, subject = camera.CameraSubject }
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
		for _, d in ipairs(workspace:GetDescendants()) do
			if d:IsA("BillboardGui") and d.Enabled then
				d.Enabled = false
				table.insert(hiddenBoards, d)
			end
		end
		camera.CameraType = Enum.CameraType.Scriptable
		cc.Enabled = true
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
		for _, p in ipairs(ctx.scopeParts) do
			if p.Parent then
				p.LocalTransparencyModifier = 0
			end
		end
		ctx.scopeHidden = false
		for _, b in ipairs(hiddenBoards) do
			if b.Parent then
				b.Enabled = true
			end
		end
		hiddenBoards = {}
		camera.CameraType = saved.cameraType == Enum.CameraType.Scriptable and Enum.CameraType.Custom or saved.cameraType
		if saved.subject and saved.subject.Parent then
			camera.CameraSubject = saved.subject
		end
		camera.FieldOfView = saved.fov
		mainGui.Enabled = saved.guiEnabled
		for _, g in ipairs(hiddenGuis) do
			if g.Parent then
				g.Enabled = true
			end
		end
		hiddenGuis = {}
		if controls then
			pcall(function() controls:Enable() end)
		end
		cc.Enabled = false
		skipBtn.root.Visible = false
		if caption then
			caption.Visible = false
		end
		CinematicGuard.release("FinalHorizon")
	end
	if spectator then
		watchBtn.root.Visible = true
		watchBtn.button.Activated:Connect(takeOver)
	else
		takeOver()
		if not watching then
			watchBtn.root.Visible = true -- (another cinematic holds the camera: they can watch when it is free)
			watchBtn.button.Activated:Connect(takeOver)
		end
	end

	local T = workspace:GetServerTimeNow() - startAt
	local done = false
	local BIND = "FinalHorizonCamera_" .. math.floor(startAt * 10)
	local lastClock = os.clock()

	local function finish()
		if done then
			return
		end
		done = true
		RunService:UnbindFromRenderStep(BIND)
		giveBack()
		ui:Destroy()
		cc:Destroy()
		worldCleanup()
		fxFolder:Destroy()
		if veyr.Parent then
			veyr:SetAttribute("FinisherAt", nil)
		end
		states[veyr] = nil
		-- (preview) the keeper comes back; for real the server's gate break has made him retreat
		if ctx.preview and keeper and keeper.Parent then
			keeper:SetAttribute("SummonKind", "Return")
			keeper:SetAttribute("SummonAt", workspace:GetServerTimeNow())
		end
		if devRemote then
			devRemote:FireServer(false)
		end
		VeyrFinisher.active = false
		if opts.onDone then
			opts.onDone()
		end
	end
	skipBtn.button.Activated:Connect(giveBack)
	veyr.AncestryChanged:Connect(function()
		if not veyr.Parent then
			giveBack()
		end
	end)

	RunService:BindToRenderStep(BIND, Enum.RenderPriority.Camera.Value + 1, function()
		if done then
			return
		end
		local now = os.clock()
		local dt = math.min(now - lastClock, 0.1)
		lastClock = now
		T = workspace:GetServerTimeNow() - startAt
		if T >= DURATION then
			finish()
			return
		end
		local ok, err = pcall(worldUpdate, T, dt)
		if not ok then
			warn("VeyrFinisher: " .. tostring(err))
		end
		local impactLines = updateScreen(T, watching)
		if watchBtn.root.Visible and T >= F.GATE_HIT - 2 then
			watchBtn.root.Visible = false
		end
		local h = watching and BAR_HEIGHT * smooth((T - watchStart) / BAR_TIME) * smooth((DURATION - T) / BAR_TIME) or 0
		barTop.Size = UDim2.fromScale(1, h)
		barBottom.Size = UDim2.fromScale(1, h)
		if not watching then
			return
		end
		local dark = ease(T, F.ASCENT_FROM, F.MOON + 1) * (1 - ease(T, F.FADE, F.END - 0.5))
		local hard = impactLines or 0
		cc.Brightness = -0.1 * dark + 0.1 * hard
		cc.Contrast = 0.12 * dark + 0.9 * hard
		cc.Saturation = -0.2 * dark - 1 * hard
		cc.TintColor = Color3.new(1, 1, 1):Lerp(Color3.fromRGB(200, 190, 255), 0.55 * dark * (1 - hard))
		if camera.CameraType ~= Enum.CameraType.Scriptable then
			camera.CameraType = Enum.CameraType.Scriptable
		end
		-- (looking through his scope = through his eye: his whole model is hidden on this screen meanwhile)
		local inScope = T >= F.SCOPE_2 - 0.1 and T < F.IMPACT
		if inScope ~= ctx.scopeHidden then
			ctx.scopeHidden = inScope
			for _, p in ipairs(ctx.scopeParts) do
				if p.Parent then
					p.LocalTransparencyModifier = inScope and 1 or 0
				end
			end
		end
		local pos, look, fov = cameraAt(T, ctx)
		camera.CFrame = CFrame.lookAt(pos, look)
		camera.FieldOfView = fov
		local shake = ctx.shake or 0
		if shake > 0 then
			local tt = os.clock() * 37
			camera.CFrame *= CFrame.new(math.sin(tt) * shake * 0.7, math.sin(tt * 1.3 + 1) * shake * 0.7, 0)
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

-- MarksmanAnimator: the running finisher (the gate he aims at)
function VeyrFinisher.state(model)
	return states[model]
end

-- the server starts it for everyone (Army.checkFinisher)
local remote = ReplicatedStorage:WaitForChild("FinalHorizon", 10)
if remote then
	remote.OnClientEvent:Connect(function(data)
		if type(data) ~= "table" or not data.startAt then
			return
		end
		VeyrFinisher.play({
			startAt = data.startAt,
			unit = data.unit,
			gate = data.gate,
			spectator = data.owner ~= tostring(player.UserId),
		})
	end)
end

return VeyrFinisher
