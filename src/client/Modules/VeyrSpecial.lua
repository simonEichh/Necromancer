-- Veyr's special, THE LONG GOODBYE (model SpecialKind "LongGoodbye"; docs/veyr.md). Timed on the synced server clock
-- from SpecialAt with VeyrTimeline.SPECIAL (the server lands its hits at IMPACT and COLLAPSE; MarksmanAnimator moves
-- his body and flies his real shards to the stations this module publishes):
--   SHARDS_OUT   his six shards fly down the lane, each to the top of its own station (the keystone of a sigil)
--   SIGIL_FROM   round each shard a big sigil opens: an enlarged relative of his basic sights inside dark gothic
--                brackets (a pointed arch above, its mirror below); drifting, a little out of true
--   LOCK_FROM    one after another they turn coaxial and lock, each with a flash
--   CHAMBER      a spectral round forms in the receiver; BARREL: it runs down the barrel to the muzzle
--   FIRE         a huge muzzle blast; the round crosses the whole corridor in FLIGHT, each sigil flashing white and
--                throwing a pressure ring as it passes; a thick pierced line lingers behind it
--   IMPACT       a large penetrating fracture (flash, shock, a spear of light out the back, cracks, chips, sparks)
--   ...          violet energy gathers into the fracture, a dark core swelling
--   COLLAPSE     the delayed implosion: the core collapses and bursts
--   BREAK        the sigils break up and fade; the shards fly home (MarksmanAnimator)
-- Stationary: everything stays where it was aimed, even if that wall breaks (the server drops the remaining damage).
-- Built per special and destroyed at the end; purely visual.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local VeyrSights = require(script.Parent.VeyrSights)
local Sfx = require(script.Parent.Sfx)
local T = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("VeyrTimeline")).SPECIAL

local TAG = "ProceduralUnit"
local FX_DISTANCE = 420
local FRACTIONS = { 0.1, 0.23, 0.36, 0.5, 0.64, 0.78 } -- where the sigils stand along the muzzle -> wall line
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local WHITE = Color3.fromRGB(250, 248, 255)
local PALETTES = {
	Base = { color = Color3.fromRGB(118, 86, 255), core = Color3.fromRGB(205, 196, 255), deep = Color3.fromRGB(64, 40, 190),
		dark = Color3.fromRGB(16, 12, 26), metal = Color3.fromRGB(26, 24, 36) },
	Shadow = { color = Color3.fromRGB(150, 70, 255), core = Color3.fromRGB(226, 190, 255), deep = Color3.fromRGB(90, 30, 210),
		dark = Color3.fromRGB(12, 6, 22), metal = Color3.fromRGB(14, 10, 22) },
}

local fx = Instance.new("Folder")
fx.Name = "VeyrSpecialFx"
fx.Parent = workspace

local VeyrSpecial = {}
local states = {} -- [model] = the running special's layout (read by MarksmanAnimator for the shard stations)
local running = {}

local function ease(x, a, b)
	local k = math.clamp((x - a) / (b - a), 0, 1)
	return k * k * (3 - 2 * k)
end
local function backOut(k)
	local c = 1.4
	return 1 + (c + 1) * (k - 1) ^ 3 + c * (k - 1) ^ 2
end

local function newPart(size, color, shape, material)
	local p = Instance.new("Part")
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.Neon
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	if shape then
		p.Shape = shape
	end
	p.Transparency = 1
	p.Parent = fx
	return p
end

local function shockDisc(pos, dir, r0, r1, dur, color, startT)
	local d = newPart(Vector3.new(0.08, r0 * 2, r0 * 2), color, Enum.PartType.Cylinder)
	d.CFrame = CFrame.lookAt(pos, pos + dir) * CFrame.Angles(0, math.pi / 2, 0)
	d.Transparency = startT or 0.4
	TweenService:Create(d, TweenInfo.new(dur, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
		{ Size = Vector3.new(0.02, r1 * 2, r1 * 2), Transparency = 1 }):Play()
	Debris:AddItem(d, dur + 0.05)
end

local function burst(pos, dir, count, opts)
	local a = Instance.new("Attachment")
	a.WorldCFrame = CFrame.lookAt(pos, pos + dir) * CFrame.Angles(-math.pi / 2, 0, 0)
	a.Parent = workspace.Terrain
	local e = Instance.new("ParticleEmitter")
	e.Texture = opts.texture or SMOKE
	e.Color = ColorSequence.new(opts.color or Color3.fromRGB(60, 56, 70), opts.color2 or opts.color or Color3.fromRGB(30, 28, 36))
	e.LightEmission = opts.emission or 0
	e.LightInfluence = opts.emission and 0 or 1
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, opts.size0 or 0.6), NumberSequenceKeypoint.new(1, opts.size1 or 2.2) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, opts.t0 or 0.35), NumberSequenceKeypoint.new(1, 1) })
	e.Lifetime = NumberRange.new(opts.life0 or 0.5, opts.life1 or 1.1)
	e.Speed = NumberRange.new(opts.speed0 or 4, opts.speed1 or 12)
	e.Drag = opts.drag or 4
	e.Acceleration = opts.accel or Vector3.new(0, 1.5, 0)
	e.SpreadAngle = Vector2.new(opts.spread or 30, opts.spread or 30)
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-60, 60)
	e.Enabled = false
	e.Parent = a
	e:Emit(count)
	Debris:AddItem(a, (opts.life1 or 1.1) + 0.2)
end

local function flashBall(pos, color, size0, size1, dur, lightRange, lightBright)
	local f = newPart(Vector3.one * size0, WHITE, Enum.PartType.Ball)
	f.CFrame = CFrame.new(pos)
	f.Transparency = 0
	if lightRange then
		local l = Instance.new("PointLight")
		l.Color = color
		l.Range = lightRange
		l.Brightness = lightBright or 8
		l.Shadows = false
		l.Parent = f
		TweenService:Create(l, TweenInfo.new(dur * 1.8), { Brightness = 0 }):Play()
	end
	TweenService:Create(f, TweenInfo.new(dur, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = Vector3.one * size1, Transparency = 1, Color = color }):Play()
	Debris:AddItem(f, dur * 1.9 + 0.05)
end

local function ownerShake(model, at, strength, dur)
	local me = Players.LocalPlayer
	local camera = workspace.CurrentCamera
	if not (me and camera and model:GetAttribute("OwnerId") == tostring(me.UserId)) then
		return
	end
	local d = (camera.CFrame.Position - at).Magnitude
	if d < 110 then
		VeyrSpecial.shakeStrength = math.max(VeyrSpecial.shakeStrength or 0, strength * (1 - d / 110))
		VeyrSpecial.shakeUntil = os.clock() + (dur or 0.4)
		VeyrSpecial.shakeDur = dur or 0.4
	end
end
RunService:BindToRenderStep("VeyrSpecialShake", Enum.RenderPriority.Camera.Value + 1, function()
	local camera = workspace.CurrentCamera
	local left = (VeyrSpecial.shakeUntil or 0) - os.clock()
	if not camera or left <= 0 then
		return
	end
	local k = (VeyrSpecial.shakeStrength or 0) * (left / (VeyrSpecial.shakeDur or 0.4)) ^ 1.5
	local t = os.clock() * 42
	camera.CFrame = camera.CFrame * CFrame.new(math.sin(t) * k * 0.6, math.sin(t * 1.3 + 1) * k * 0.4, 0)
end)

-- ====================================================================
-- A sigil: a big sight in dark gothic brackets (a pointed arch above it, its mirror below), the shard on top
-- ====================================================================
local function buildSigil(radius, pal)
	local sg = { sight = VeyrSights.build(fx, radius, pal.color, pal.core, { segments = 20, innerCount = 12 }),
		brackets = {}, offsets = {} }
	-- the brackets: each a chain of short dark bars with a neon edge, curving from the ring's sides to a point
	for _, vert in ipairs({ 1, -1 }) do
		for _, side in ipairs({ -1, 1 }) do
			local prev
			for k = 0, 5 do
				local a = (k / 5) * (math.pi / 2) -- from the side of the ring (a = 0) to the apex (a = pi/2)
				local x = side * radius * 1.08 * math.cos(a) * (1 - 0.18 * k / 5)
				local y = vert * (radius * 0.15 + radius * 1.35 * math.sin(a) ^ 1.3)
				local pt = Vector3.new(x, y, 0)
				if prev then
					local mid = (prev + pt) / 2
					local len = (pt - prev).Magnitude
					local cf = CFrame.lookAt(mid, mid + Vector3.new(0, 0, -1), (pt - prev).Unit) -- (bar along local Y)
					local w = radius * 0.07
					local bar = newPart(Vector3.new(w, len + w * 0.6, w * 0.8), pal.metal, nil, Enum.Material.Metal)
					local edge = newPart(Vector3.new(w * 0.28, len + w * 0.4, w * 0.9), pal.color)
					table.insert(sg.brackets, { part = bar, offset = cf, base = 0 })
					table.insert(sg.brackets, { part = edge, offset = cf * CFrame.new(side * w * 0.45, 0, 0), base = 0.15 })
				end
				prev = pt
			end
		end
		-- a small spike at the apex
		local tipCf = CFrame.new(0, vert * radius * 1.62, 0)
		table.insert(sg.brackets, { part = newPart(Vector3.new(radius * 0.06, radius * 0.3, radius * 0.06), pal.core), offset = tipCf, base = 0 })
	end
	return sg
end

local function placeSigil(sg, cf, scale, alpha, spin)
	VeyrSights.place(sg.sight, cf, scale, alpha, spin)
	for _, b in ipairs(sg.brackets) do
		local o = b.offset
		b.part.CFrame = cf * (CFrame.new(o.Position * scale) * o.Rotation)
		b.part.Transparency = 1 - (1 - b.base) * math.clamp(alpha, 0, 1)
	end
end

local function destroySigil(sg)
	VeyrSights.destroy(sg.sight)
	for _, b in ipairs(sg.brackets) do
		b.part:Destroy()
	end
end

-- ====================================================================
-- One special
-- ====================================================================
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function start(model)
	local at = model:GetAttribute("SpecialAt")
	local aim = model:GetAttribute("SpecialAim")
	local root = model.PrimaryPart
	local rifle = model:FindFirstChild("RifleRoot")
	local ringOrigin = rifle and rifle:FindFirstChild("RingOrigin")
	local muzzle = rifle and rifle:FindFirstChild("Muzzle")
	local chamber = rifle and rifle:FindFirstChild("Chamber")
	if not (at and aim and root and ringOrigin and muzzle) then return end
	local camera = workspace.CurrentCamera
	if camera and (root.Position - camera.CFrame.Position).Magnitude > FX_DISTANCE
		and (aim - camera.CFrame.Position).Magnitude > FX_DISTANCE then
		return
	end
	local sNow0 = workspace:GetServerTimeNow()
	if sNow0 - at > T.END then return end
	local pal = PALETTES[model:GetAttribute("Form") == "Shadow" and "Shadow" or "Base"]

	-- the corridor is laid out once he has planted (LAYOUT, before the shards leave): from where his muzzle really is
	-- then (up on his perch) straight to the spot on the wall's real surface, diagonally down the lane. MarksmanAnimator aims the
	-- rifle exactly down this axis for the rest of the special, so the round, the sigils and the barrel are one line.
	local st = { at = at, ready = false, centers = {}, radii = {}, stations = {}, frames = {} }
	local sigils = {} -- (built by layout: their size depends on the corridor's length)
	local normal
	local function layout()
		local look = root.CFrame.LookVector
		normal = -Vector3.new(look.X, 0, look.Z).Unit
		local o = ringOrigin.WorldPosition
		-- (from his perch the line runs down and across to the spot the server aimed at, on the wall's real surface)
		rayParams.FilterDescendantsInstances = { fx, model }
		local hit = workspace:Raycast(aim + normal * 8, -normal * 14, rayParams) -- (from well out: some stones stick out far)
		local surface = hit and hit.Position or aim
		local fwd = (surface - o).Unit
		local dist = (surface - o).Magnitude
		st.origin, st.surface, st.axis = o, surface, CFrame.lookAt(o, o + fwd)
		-- (from his overwatch post the corridor is ~70 studs to the first wall and ~270 to the gate: the sigils grow
		-- with it so the far ones still read)
		local grow = math.clamp(dist / 70, 1, 4) ^ 0.75
		for i = 1, T.SIGILS do
			st.radii[i] = (1.5 + 0.38 * i) * grow
			sigils[i] = buildSigil(st.radii[i], pal)
		end
		for i, f in ipairs(FRACTIONS) do
			local c = o + fwd * dist * f
			st.centers[i] = c
			st.frames[i] = CFrame.lookAt(c, c + fwd)
			st.stations[i] = c + Vector3.new(0, st.radii[i] * 1.75, 0) -- (the shard hangs above the arch's point)
		end
		st.ready = true
		states[model] = st
	end

	local orb = newPart(Vector3.one * 0.1, pal.core, Enum.PartType.Ball) -- the round in the chamber / barrel
	local round = newPart(Vector3.new(0.4, 0.4, 2.6), WHITE)
	local roundGlow = newPart(Vector3.new(1.2, 1.2, 3.6), pal.color, Enum.PartType.Ball)
	local trail = newPart(Vector3.new(0.3, 0.3, 1), WHITE)
	local trailGlow = newPart(Vector3.new(1, 1, 1), pal.color)
	local core = newPart(Vector3.one * 0.1, pal.dark, Enum.PartType.Ball) -- the gathering core in the fracture
	local coreGlow = newPart(Vector3.one * 0.1, pal.color, Enum.PartType.Ball)
	local gather -- (the particles drawn into the fracture)
	local spins, locked, passed = {}, {}, {}
	local fired, impacted, collapsed, broke = false, false, false, false
	local fireFrom
	local extra = { orb, round, roundGlow, trail, trailGlow, core, coreGlow }

	local function finish()
		for _, sg in ipairs(sigils) do destroySigil(sg) end
		for _, p in ipairs(extra) do p:Destroy() end
		if gather then gather:Destroy() end
		if states[model] == st then states[model] = nil end
	end

	return { finish = finish, step = function(now, sNow, dt)
		local t = sNow - at
		if t > T.END + 0.5 then
			finish()
			return false
		end
		if model:GetAttribute("SpecialAt") ~= at then
			finish()
			return false
		end
		if not st.ready then
			if t < T.LAYOUT then
				return true -- (nothing to draw until he has planted)
			end
			layout()
		end

		-- ── the sigils
		for i, sg in ipairs(sigils) do
			local openAt = T.SIGIL_FROM + (i - 1) * T.SIGIL_STEP
			local lockAt = T.LOCK_FROM + (i - 1) * T.LOCK_STEP
			local open = ease(t, openAt, openAt + 0.6)
			if open <= 0 then
				placeSigil(sg, st.frames[i], 0.01, 0, 0)
			else
				local unlocked = 1 - ease(t, lockAt - 0.25, lockAt)
				spins[i] = (spins[i] or i) + dt * (i % 2 == 0 and 1 or -1) * (0.12 + 0.9 * unlocked)
				local drift = Vector3.new(math.sin(t * 1.1 + i) * 0.5, math.cos(t * 0.9 + i * 2) * 0.35, 0) * unlocked
				local tilt = math.sin(t * 0.8 + i) * 0.18 * unlocked
				local lockFlash = ease(t, lockAt, lockAt + 0.05) * (1 - ease(t, lockAt + 0.08, lockAt + 0.4))
				if not locked[i] and t >= lockAt then
					locked[i] = true
					Sfx.playAt("veyr_ring", st.centers[i], 1, 0.8 + i * 0.06, 160)
				end
				-- the gathering: they draw in a little before the shot; the round's pass: a flash and a pulse
				local draw = ease(t, T.BARREL, T.FIRE) * 0.08
				local passT = T.FIRE + FRACTIONS[i] * T.FLIGHT
				local pass = ease(t, passT, passT + 0.02) * (1 - ease(t, passT + 0.05, passT + 0.4))
				if not passed[i] and t >= passT and fired then
					passed[i] = true
					shockDisc(st.centers[i], st.axis.LookVector, st.radii[i] * 0.6, st.radii[i] * 2.4, 0.45, pal.core, 0.45)
				end
				-- breaking up: fade, spread a little, the brackets crack apart
				local brk = ease(t, T.BREAK + (T.SIGILS - i) * 0.12, T.BREAK + (T.SIGILS - i) * 0.12 + 0.9)
				local scale = (0.2 + 0.8 * backOut(open)) * (1 - draw + 0.25 * pass) * (1 + 0.35 * brk)
				local alpha = math.min(1, open * 1.3) * (1 - brk)
				local cf = st.frames[i] * CFrame.new(drift) * CFrame.Angles(tilt, tilt * 0.7, 0)
				placeSigil(sg, cf, scale, alpha, spins[i])
				if pass > 0.35 or lockFlash > 0.35 then
					VeyrSights.tint(sg.sight, pal.core, WHITE)
				else
					VeyrSights.tint(sg.sight, pal.color, pal.core)
				end
			end
		end

		-- ── the round forms in the chamber, then runs down the barrel to the muzzle
		if t >= T.CHAMBER and t < T.FIRE and chamber then
			local form = ease(t, T.CHAMBER, T.BARREL)
			local run = ease(t, T.BARREL, T.FIRE - 0.15)
			local pos = chamber.WorldPosition:Lerp(muzzle.WorldPosition, run)
			orb.CFrame = CFrame.new(pos)
			orb.Size = Vector3.one * (0.12 + 0.35 * form + 0.06 * math.sin(now * 30))
			orb.Transparency = 0.1
			if not st.chargeSound then
				st.chargeSound = true
				Sfx.playAt("veyr_charge", pos, 1, 1, 160)
			end
		else
			orb.Transparency = 1
		end

		-- ── the shot
		if not fired and t >= T.FIRE then
			fired = true
			fireFrom = muzzle.WorldPosition
			if t < T.FIRE + 0.4 then
				local ax = st.axis.LookVector
				flashBall(fireFrom + ax * 0.6, pal.color, 1.4, 6, 0.22, 34, 12)
				shockDisc(fireFrom + ax * 0.8, ax, 0.6, 8, 0.4, pal.core, 0.5)
				task.delay(0.05, function() shockDisc(fireFrom + ax * 2.5, ax, 0.5, 5.5, 0.35, pal.color, 0.55) end)
				burst(fireFrom + ax, ax, 26, { color = Color3.fromRGB(70, 60, 96), size0 = 0.8, size1 = 3.6, speed0 = 4,
					speed1 = 14, spread = 40, life0 = 0.7, life1 = 1.6, t0 = 0.4 })
				local below = workspace:Raycast(fireFrom, Vector3.new(0, -12, 0), rayParams)
				if below then
					burst(below.Position + Vector3.new(0, 0.2, 0), Vector3.yAxis, 34, { color = Color3.fromRGB(84, 78, 72),
						size0 = 1, size1 = 4.5, speed0 = 8, speed1 = 20, spread = 88, life0 = 0.6, life1 = 1.3, accel = Vector3.new(0, 0.5, 0), t0 = 0.45 })
				end
				Sfx.playAt("veyr_crack", fireFrom, 1, 0.85, 320)
				ownerShake(model, fireFrom, 0.5, 0.45)
			end
		end
		if fired and fireFrom then
			local p = math.clamp((t - T.FIRE) / T.FLIGHT, 0, 1)
			local dir = st.surface - fireFrom
			local tip = fireFrom + dir * (p ^ 1.6) -- (it leaves fast and is faster still at the end)
			if p < 1 then
				round.CFrame = CFrame.lookAt(tip, tip + dir)
				round.Transparency = 0
				roundGlow.CFrame = round.CFrame
				roundGlow.Transparency = 0.3
			else
				round.Transparency = 1
				roundGlow.Transparency = 1
			end
			local fade = p < 1 and 0 or ease(t, T.IMPACT, T.IMPACT + 1.4)
			local len = math.max(0.2, (tip - fireFrom).Magnitude)
			local mid = CFrame.lookAt(fireFrom:Lerp(tip, 0.5), tip)
			trail.Size = Vector3.new(0.3 * (1 - fade) + 0.02, 0.3 * (1 - fade) + 0.02, len)
			trail.CFrame = mid
			trail.Transparency = 0.02 + 0.98 * fade
			trailGlow.Size = Vector3.new(1.1 * (1 - fade * 0.5), 1.1 * (1 - fade * 0.5), len)
			trailGlow.CFrame = mid
			trailGlow.Transparency = 0.5 + 0.5 * fade
		end

		-- ── the fracture
		local pos, n = st.surface, normal
		if not impacted and t >= T.IMPACT then
			impacted = true
			if t < T.IMPACT + 0.5 then
				flashBall(pos + n * 0.2, pal.color, 1, 9, 0.3, 40, 12)
				shockDisc(pos + n * 0.15, n, 0.6, 14, 0.55, pal.core, 0.4)
				task.delay(0.08, function() shockDisc(pos + n * 0.12, n, 0.5, 9, 0.7, pal.color, 0.45) end)
				local spear = newPart(Vector3.new(0.9, 0.9, 34), WHITE)
				spear.CFrame = CFrame.lookAt(pos - n * 17, pos - n * 34)
				spear.Transparency = 0
				TweenService:Create(spear, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{ Size = Vector3.new(0.05, 0.05, 44), Transparency = 1, Color = pal.color }):Play()
				Debris:AddItem(spear, 0.45)
				burst(pos + n * 0.4, n, 30, { color = Color3.fromRGB(88, 82, 78), size0 = 1, size1 = 4.5, speed0 = 8,
					speed1 = 22, spread = 60, life0 = 0.7, life1 = 1.6, t0 = 0.35 })
				burst(pos + n * 0.4, n, 46, { texture = SPARK, color = pal.core, color2 = pal.color, emission = 1,
					size0 = 0.5, size1 = 0.05, speed0 = 14, speed1 = 36, spread = 70, life0 = 0.3, life1 = 0.8, drag = 2.5,
					accel = Vector3.new(0, -24, 0), t0 = 0 })
				-- the fracture: long cracks over the wall face, hot, then violet, staying while the core gathers
				local face = CFrame.lookAt(pos + n * 0.06, pos + n * 2)
				for i = 1, 16 do
					local a = (i / 16) * 2 * math.pi + math.random() * 0.3
					local len = 2 + math.random() * 3.5
					local crack = newPart(Vector3.new(0.12, len, 0.05), pal.core)
					crack.CFrame = face * CFrame.Angles(0, 0, a) * CFrame.new(0, 0.4 + len / 2, 0) * CFrame.Angles(0, 0, (math.random() - 0.5) * 0.35)
					crack.Transparency = 0
					TweenService:Create(crack, TweenInfo.new(0.6), { Color = pal.color }):Play()
					task.delay(T.COLLAPSE - T.IMPACT + 0.2, function()
						if crack.Parent then
							TweenService:Create(crack, TweenInfo.new(1.8), { Color = pal.dark, Transparency = 0.3 }):Play()
						end
					end)
					task.delay(T.COLLAPSE - T.IMPACT + 2.4, function()
						if crack.Parent then
							TweenService:Create(crack, TweenInfo.new(1.2), { Transparency = 1 }):Play()
						end
					end)
					Debris:AddItem(crack, T.COLLAPSE - T.IMPACT + 3.8)
				end
				Sfx.playAt("veyr_impact", pos, 1.6, 0.8, 300)
				ownerShake(model, pos, 0.4, 0.4)
				-- violet energy drawn into the fracture until the collapse
				local a = newPart(Vector3.one * 7, pal.color, Enum.PartType.Ball) -- (an invisible shell: they spawn on it)
				a.CFrame = CFrame.new(pos + n * 0.6)
				local e = Instance.new("ParticleEmitter")
				e.Texture = SPARK
				e.Color = ColorSequence.new(pal.core, pal.color)
				e.LightEmission = 1
				e.LightInfluence = 0
				e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0.05) })
				e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.2), NumberSequenceKeypoint.new(1, 0.6) })
				e.Lifetime = NumberRange.new(0.5, 0.7)
				e.Rate = 90
				e.Speed = NumberRange.new(-12, -9) -- (they fly IN: spawned on a shell round the core)
				e.Shape = Enum.ParticleEmitterShape.Sphere
				e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
				e.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
				e.Parent = a
				gather = a
			end
		end
		if impacted and not collapsed then
			local g = ease(t, T.IMPACT + 0.1, T.COLLAPSE - 0.15)
			local implode = ease(t, T.COLLAPSE - 0.15, T.COLLAPSE)
			local r = (0.3 + 2.6 * g) * (1 - implode) + 0.05 * math.sin(now * 26)
			core.CFrame = CFrame.new(pos + n * 0.6)
			core.Size = Vector3.one * math.max(0.05, r)
			core.Transparency = 0.05
			coreGlow.CFrame = core.CFrame
			coreGlow.Size = Vector3.one * math.max(0.05, r * 1.35)
			coreGlow.Transparency = 0.55
		end
		if impacted and not collapsed and t >= T.COLLAPSE then
			collapsed = true
			core.Transparency = 1
			coreGlow.Transparency = 1
			if gather then gather:Destroy() gather = nil end
			if t < T.COLLAPSE + 0.5 then
				flashBall(pos + n * 0.6, pal.deep, 0.5, 8, 0.35, 34, 10)
				shockDisc(pos + n * 0.2, n, 0.5, 11, 0.6, pal.color, 0.35)
				burst(pos + n * 0.6, n, 36, { color = pal.dark, color2 = Color3.fromRGB(40, 20, 70), size0 = 1.2, size1 = 5,
					speed0 = 6, speed1 = 16, spread = 80, life0 = 0.8, life1 = 1.8, t0 = 0.3 })
				Sfx.playAt("veyr_collapse", pos, 1, 1, 300)
				ownerShake(model, pos, 0.35, 0.35)
			end
		end
		if not broke and t >= T.BREAK then
			broke = true
		end
		return true
	end }
end

-- MarksmanAnimator reads the stations (where each shard flies) while a special plays
function VeyrSpecial.state(model)
	return states[model]
end

-- ============================================================
-- Watching the units
-- ============================================================
local watched = {}
local function watch(model)
	if watched[model] then return end
	watched[model] = true
	model:GetAttributeChangedSignal("SpecialAt"):Connect(function()
		if model:GetAttribute("SpecialKind") == "LongGoodbye" then
			local sp = start(model)
			if sp then
				table.insert(running, sp)
			end
		end
	end)
end
for _, model in ipairs(CollectionService:GetTagged(TAG)) do
	watch(model)
end
CollectionService:GetInstanceAddedSignal(TAG):Connect(watch)
CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(model)
	watched[model] = nil
	states[model] = nil
end)

local lastFrame = os.clock()
RunService.RenderStepped:Connect(function()
	local now = os.clock()
	local dt = math.min(now - lastFrame, 0.1)
	lastFrame = now
	local sNow = workspace:GetServerTimeNow()
	for i = #running, 1, -1 do
		local sp = running[i]
		local ok, keep = pcall(sp.step, now, sNow, dt)
		if not ok then
			warn("VeyrSpecial: " .. tostring(keep))
			pcall(sp.finish) -- (never leave a broken special's parts behind)
			keep = false
		end
		if not keep then
			table.remove(running, i)
		end
	end
end)

return VeyrSpecial
