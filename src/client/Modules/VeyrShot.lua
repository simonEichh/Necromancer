-- Veyr's basic attack, DEAD RECKONING (units whose model has AttackStyle = "Marksman"; docs/veyr.md). The server
-- (Army.fireMarksman) publishes AimPos, ShotImpact (server time the round lands) and then ShotAt (server time the
-- performance starts); every beat here is timed on the synced server clock from those, with VeyrTimeline (shared with
-- the server and with MarksmanAnimator, which moves his body):
--   0.5 - 0.9     a glint on the scope as he settles
--   RINGS_FROM    three focusing sights open one after another ahead of the muzzle, counter-rotating and drifting a
--                 little, motes drawn in towards the barrel; a small sight opens on the wall where he aims
--   LOCK          they turn coaxial and stop; QUIET: the centre contracts, a held breath
--   FIRE          a white-violet muzzle flash; one spectral round with a narrow trail, pressure rings off its path; each
--                 sight flashes as it passes
--   ShotImpact    a small blinding puncture, the wall's sight snaps shut on it, chips, violet fracture lines that cool
--                 dark; the weak point (his trait) shows as a faint broken sight on the wall while the server's mark
--                 lasts (WallModel attributes MarkUntil / MarkPos)
--   afterwards    the sights cool and withdraw into the muzzle
-- One set of sights per unit is built once and reused (hidden between shots). Purely visual, nothing is networked.
-- A brief, modest camera shake for the plot's owner only, when the camera is near him.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local VeyrSights = require(script.Parent.VeyrSights)
local Sfx = require(script.Parent.Sfx)
local Shared = ReplicatedStorage:WaitForChild("Shared")
local T = require(Shared:WaitForChild("VeyrTimeline"))
local Units = require(Shared:WaitForChild("Units"))

local TAG = "ProceduralUnit"
local MAX_DISTANCE = 320 -- (beyond this from the camera a shot is not drawn at all)
local SHAKE_RANGE = 70
local RINGS = { -- radius, distance ahead of RingOrigin along the shot axis
	{ r = 0.5, d = 0.5 },
	{ r = 0.72, d = 1.45 },
	{ r = 1.0, d = 2.55 },
}
local RING_STEP = 0.38 -- (s between the sights opening)
local WALL_SIGHT_R = 1.35
local PRESSURE_AT = { 0.06, 0.18, 0.32, 0.48, 0.66 } -- fractions of the flight where a pressure ring rolls off the path
local MOTES = 6

local PALETTES = {
	Base = { color = Color3.fromRGB(118, 86, 255), core = Color3.fromRGB(205, 196, 255), deep = Color3.fromRGB(64, 40, 190), dark = Color3.fromRGB(16, 12, 26) },
	Shadow = { color = Color3.fromRGB(150, 70, 255), core = Color3.fromRGB(226, 190, 255), deep = Color3.fromRGB(90, 30, 210), dark = Color3.fromRGB(12, 6, 22) },
}
local WHITE = Color3.fromRGB(250, 248, 255)

local fx = Instance.new("Folder")
fx.Name = "VeyrShotFx"
fx.Parent = workspace

local kits = {} -- [model] = the unit's reusable parts
local active = {} -- running effects: function(now, serverNow, dt) -> keepGoing
local marks = {} -- [wall model or key] = the weak point drawn on that wall

local function ease(x, a, b)
	local k = math.clamp((x - a) / (b - a), 0, 1)
	return k * k * (3 - 2 * k)
end
local function backOut(k)
	local c = 1.6
	return 1 + (c + 1) * (k - 1) ^ 3 + c * (k - 1) ^ 2
end

local function newPart(size, color, shape)
	local p = Instance.new("Part")
	p.Size = size
	p.Color = color
	p.Material = Enum.Material.Neon
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

-- a flat shock disc across `dir` at `pos` that grows from r0 to r1 studs and fades over `dur`
local function shockDisc(pos, dir, r0, r1, dur, color, startT)
	local d = newPart(Vector3.new(0.06, r0 * 2, r0 * 2), color, Enum.PartType.Cylinder)
	d.CFrame = CFrame.lookAt(pos, pos + dir) * CFrame.Angles(0, math.pi / 2, 0)
	d.Transparency = startT or 0.25
	TweenService:Create(d, TweenInfo.new(dur, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
		{ Size = Vector3.new(0.02, r1 * 2, r1 * 2), Transparency = 1 }):Play()
	Debris:AddItem(d, dur + 0.05)
	return d
end

-- a one-shot particle burst at `pos` (smoke / dust / sparks), spraying along `dir` with `spread` degrees
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local function burst(pos, dir, count, opts)
	local a = Instance.new("Attachment")
	a.WorldCFrame = CFrame.lookAt(pos, pos + dir) * CFrame.Angles(-math.pi / 2, 0, 0) -- (the emitter sprays along +Y)
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

local function paletteOf(model)
	return PALETTES[model:GetAttribute("Form") == "Shadow" and "Shadow" or "Base"]
end

-- ====================================================================
-- The unit's kit: its sights, the wall's sight, the pressure rings, motes, the round, its trail, the scope glint
-- ====================================================================
local function buildKit(model)
	local pal = paletteOf(model)
	local kit = { form = model:GetAttribute("Form"), sights = {}, pressure = {}, motes = {} }
	for i, r in ipairs(RINGS) do
		kit.sights[i] = VeyrSights.build(fx, r.r, pal.color, pal.core, { segments = 12, innerCount = 8, spikes = i == #RINGS })
	end
	kit.wall = VeyrSights.build(fx, WALL_SIGHT_R, pal.color, pal.core, { segments = 14, innerCount = 8 })
	for i = 1, #PRESSURE_AT do
		kit.pressure[i] = VeyrSights.build(fx, 0.55, pal.color, pal.core, { segments = 10, inner = false, spikes = false, ticks = false, nodes = false })
	end
	for i = 1, MOTES do
		kit.motes[i] = newPart(Vector3.one * 0.09, pal.core, Enum.PartType.Ball)
	end
	kit.round = newPart(Vector3.new(0.2, 0.2, 1.4), WHITE)
	kit.roundGlow = newPart(Vector3.new(0.6, 0.6, 2.2), pal.color, Enum.PartType.Ball)
	kit.trail = newPart(Vector3.new(0.12, 0.12, 1), WHITE)
	kit.trailGlow = newPart(Vector3.new(0.4, 0.4, 1), pal.color)
	kit.glint = newPart(Vector3.one * 0.3, WHITE, Enum.PartType.Ball)
	kit.glintBar = newPart(Vector3.new(1.2, 0.04, 0.04), WHITE)
	return kit
end

local function hideKit(kit)
	for _, s in ipairs(kit.sights) do VeyrSights.hide(s) end
	for _, s in ipairs(kit.pressure) do VeyrSights.hide(s) end
	VeyrSights.hide(kit.wall)
	for _, m in ipairs(kit.motes) do m.Transparency = 1 end
	kit.round.Transparency = 1
	kit.roundGlow.Transparency = 1
	kit.trail.Transparency = 1
	kit.trailGlow.Transparency = 1
	kit.glint.Transparency = 1
	kit.glintBar.Transparency = 1
end

local function destroyKit(kit)
	for _, s in ipairs(kit.sights) do VeyrSights.destroy(s) end
	for _, s in ipairs(kit.pressure) do VeyrSights.destroy(s) end
	VeyrSights.destroy(kit.wall)
	for _, m in ipairs(kit.motes) do m:Destroy() end
	kit.round:Destroy()
	kit.roundGlow:Destroy()
	kit.trail:Destroy()
	kit.trailGlow:Destroy()
	kit.glint:Destroy()
	kit.glintBar:Destroy()
end

local function getKit(model)
	local kit = kits[model]
	if kit and kit.form ~= model:GetAttribute("Form") then
		destroyKit(kit) -- (levelled into the shadow form while we watched: rebuild in its palette)
		kit = nil
	end
	if not kit then
		kit = buildKit(model)
		kits[model] = kit
	end
	return kit
end

-- ====================================================================
-- The owner's camera shake (brief, modest, only near him)
-- ====================================================================
local shakeUntil, shakeStrength = 0, 0
RunService:BindToRenderStep("VeyrShotShake", Enum.RenderPriority.Camera.Value + 1, function()
	local camera = workspace.CurrentCamera
	local left = shakeUntil - os.clock()
	if not camera or left <= 0 then
		return
	end
	local k = shakeStrength * (left / 0.3) ^ 1.6
	local t = os.clock() * 46
	camera.CFrame = camera.CFrame * CFrame.new(math.sin(t) * k * 0.5, math.sin(t * 1.3 + 1) * k * 0.35, 0)
end)
local function ownerShake(model, at, strength)
	local me = Players.LocalPlayer
	local camera = workspace.CurrentCamera
	if not (me and camera and model:GetAttribute("OwnerId") == tostring(me.UserId)) then
		return
	end
	local d = (camera.CFrame.Position - at).Magnitude
	if d < SHAKE_RANGE then
		shakeStrength = math.max(shakeStrength, strength * (1 - d / SHAKE_RANGE))
		shakeUntil = os.clock() + 0.3
	end
end

-- ====================================================================
-- The weak point (his trait): a faint broken sight on the wall while the server's mark lasts
-- ====================================================================
local MARK_DURATION = (Units.Stats.Veyr and Units.Stats.Veyr.trait and Units.Stats.Veyr.trait.duration) or 6
local function showMark(wallModel, pos, normal, pal)
	local key = wallModel or "nowall"
	local mk = marks[key]
	if not mk then
		mk = { parts = {}, born = os.clock() }
		for c = 0, 3 do
			for b = 0, 1 do
				local p = newPart(Vector3.new(0.05, 0.42, 0.05), pal.deep)
				mk.parts[c * 2 + b + 1] = { part = p, corner = c, horizontal = b == 1 }
			end
		end
		marks[key] = mk
	end
	mk.wallModel = wallModel
	mk.pos = pos
	mk.normal = normal
	mk.localUntil = workspace:GetServerTimeNow() + MARK_DURATION
	mk.pulse = os.clock()
end

local function updateMarks(now, serverNow)
	for key, mk in pairs(marks) do
		local wm = mk.wallModel
		local untilT = wm and wm:GetAttribute("MarkUntil") or mk.localUntil
		local gone = (wm and not wm.Parent) or serverNow > untilT + 0.4
		if gone then
			for _, b in ipairs(mk.parts) do b.part:Destroy() end
			marks[key] = nil
		else
			local alpha = ease(now - mk.born, 0, 0.3) * (1 - ease(serverNow, untilT - 0.6, untilT + 0.3))
			local pulse = 1 - ease(now - mk.pulse, 0, 0.5) -- (each refresh flashes it once)
			local hub = CFrame.lookAt(mk.pos + mk.normal * 0.06, mk.pos + mk.normal * 2) * CFrame.Angles(0, 0, now * 0.25)
			local reach = 0.95 + 0.06 * math.sin(now * 2.2)
			for _, b in ipairs(mk.parts) do
				local a = b.corner * math.pi / 2 + math.pi / 4
				-- an L-shaped bracket at each diagonal, its two arms pointing along the frame's axes, with a gap at the corner
				local corner = hub * CFrame.Angles(0, 0, a - math.pi / 4) * CFrame.new(reach, reach, 0)
				local arm = b.horizontal and (corner * CFrame.new(-0.3, 0, 0) * CFrame.Angles(0, 0, math.pi / 2))
					or (corner * CFrame.new(0, -0.3, 0))
				b.part.CFrame = arm
				b.part.Transparency = 1 - (0.62 + 0.3 * pulse) * alpha
			end
		end
	end
end

-- ====================================================================
-- The impact: the puncture, chips, fracture lines that cool dark
-- ====================================================================
local function impact(model, pos, normal, pal, wallModel, markPos)
	local flash = newPart(Vector3.one * 0.3, WHITE, Enum.PartType.Ball)
	flash.CFrame = CFrame.new(pos + normal * 0.1)
	flash.Transparency = 0
	local light = Instance.new("PointLight")
	light.Color = pal.color
	light.Range = 12
	light.Brightness = 5
	light.Shadows = false
	light.Parent = flash
	light.Range = 24
	light.Brightness = 9
	TweenService:Create(flash, TweenInfo.new(0.24, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = Vector3.one * 3.4, Transparency = 1, Color = pal.color }):Play()
	TweenService:Create(light, TweenInfo.new(0.45), { Brightness = 0 }):Play()
	Debris:AddItem(flash, 0.5)
	-- the shock rolling out over the wall face, a second slower one behind it
	shockDisc(pos + normal * 0.12, normal, 0.4, 6.5, 0.4, pal.core, 0.45)
	task.delay(0.06, function()
		shockDisc(pos + normal * 0.1, normal, 0.3, 4, 0.5, pal.color, 0.3)
	end)
	-- it does not stop at the stone: a spear of light punches straight through and out the back of the wall
	local spear = newPart(Vector3.new(0.35, 0.35, 16), WHITE)
	spear.CFrame = CFrame.lookAt(pos - normal * 8, pos - normal * 16)
	spear.Transparency = 0
	TweenService:Create(spear, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = Vector3.new(0.02, 0.02, 22), Transparency = 1, Color = pal.color }):Play()
	Debris:AddItem(spear, 0.3)
	-- dust and sparks sprayed out of the hole
	burst(pos + normal * 0.3, normal, 18, { color = Color3.fromRGB(88, 82, 78), size0 = 0.6, size1 = 2.8, speed0 = 6,
		speed1 = 16, spread = 55, life0 = 0.6, life1 = 1.3, t0 = 0.4 })
	burst(pos + normal * 0.3, normal, 24, { texture = SPARK, color = pal.core, color2 = pal.color, emission = 1,
		size0 = 0.35, size1 = 0.05, speed0 = 10, speed1 = 26, spread = 60, life0 = 0.25, life1 = 0.55, drag = 3,
		accel = Vector3.new(0, -20, 0), t0 = 0 })

	-- fracture lines on the wall's plane, radiating from the hole: hot, then violet, then dark
	local face = CFrame.lookAt(pos + normal * 0.05, pos + normal * 2)
	for i = 1, 9 do
		local a = (i / 9) * 2 * math.pi + math.random() * 0.5
		local len = 0.8 + math.random() * 1.6
		local crack = newPart(Vector3.new(0.05, len, 0.03), pal.core)
		crack.CFrame = face * CFrame.Angles(0, 0, a) * CFrame.new(0, 0.15 + len / 2, 0) * CFrame.Angles(0, 0, (math.random() - 0.5) * 0.3)
		crack.Transparency = 0
		TweenService:Create(crack, TweenInfo.new(0.5), { Color = pal.color }):Play()
		task.delay(0.5, function()
			if crack.Parent then
				TweenService:Create(crack, TweenInfo.new(1.6), { Color = pal.dark, Transparency = 0.2 }):Play()
			end
		end)
		task.delay(2.4, function()
			if crack.Parent then
				TweenService:Create(crack, TweenInfo.new(1.2), { Transparency = 1 }):Play()
			end
		end)
		Debris:AddItem(crack, 3.8)
	end

	-- chips of stone thrown out of the hole
	local chips = {}
	for i = 1, 14 do
		local c = Instance.new("Part")
		c.Size = Vector3.one * (0.14 + math.random() * 0.3)
		c.Color = Color3.fromRGB(46, 44, 52)
		c.Material = Enum.Material.Slate
		c.Anchored = true
		c.CanCollide = false
		c.CanQuery = false
		c.CanTouch = false
		c.CastShadow = false
		c.CFrame = CFrame.new(pos + normal * 0.15)
		c.Parent = fx
		local side = normal:Cross(Vector3.yAxis)
		side = side.Magnitude > 0.1 and side.Unit or Vector3.xAxis
		chips[i] = { part = c, pos = c.Position,
			vel = normal * (8 + math.random() * 10) + side * (math.random() - 0.5) * 12 + Vector3.new(0, 3 + math.random() * 6, 0),
			spin = Vector3.new(math.random(), math.random(), math.random()) * 12 }
		Debris:AddItem(c, 1.1)
	end
	local t0 = os.clock()
	table.insert(active, function(now, _, dt)
		local st = now - t0
		for _, c in ipairs(chips) do
			c.vel += Vector3.new(0, -32, 0) * dt
			c.pos += c.vel * dt
			c.part.CFrame = CFrame.new(c.pos) * CFrame.Angles(c.spin.X * st, c.spin.Y * st, c.spin.Z * st)
			c.part.Transparency = ease(st, 0.6, 1.0)
		end
		return st < 1.05
	end)

	showMark(wallModel, markPos or pos, normal, pal)
	-- (no impact sound on the basic shot: the user found the borrowed shell impact too massive for it)
	ownerShake(model, pos, 0.32)
end

-- ====================================================================
-- One shot
-- ====================================================================
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function wallModelOf(part)
	local p = part
	while p and p ~= workspace do
		if p.Name == "WallModel" then
			return p
		end
		p = p.Parent
	end
	return nil
end

local function onShot(model)
	local shotAt = model:GetAttribute("ShotAt")
	local aim = model:GetAttribute("AimPos")
	local root = model.PrimaryPart
	if not (shotAt and aim and root) then return end
	local serverNow = workspace:GetServerTimeNow()
	if serverNow - shotAt > T.FIRE + 0.3 then return end -- (joined late: no half shot)
	local camera = workspace.CurrentCamera
	if camera and (root.Position - camera.CFrame.Position).Magnitude > MAX_DISTANCE then return end
	local rifle = model:FindFirstChild("RifleRoot")
	local ringOrigin = rifle and rifle:FindFirstChild("RingOrigin")
	local muzzle = rifle and rifle:FindFirstChild("Muzzle")
	local scopeLens = rifle and rifle:FindFirstChild("ScopeLens")
	if not (ringOrigin and muzzle) then return end
	local impactT = model:GetAttribute("ShotImpact") or (shotAt + T.impactAt(60))
	local pal = paletteOf(model)
	local kit = getKit(model)
	kit.shot = shotAt -- (a newer shot takes over the kit)

	-- the wall's real surface where the round lands (the stones stick out past the nominal face)
	local look = root.CFrame.LookVector
	local normal = -Vector3.new(look.X, 0, look.Z).Unit
	rayParams.FilterDescendantsInstances = { fx, model }
	local hit = workspace:Raycast(aim + normal * 8, -normal * 14, rayParams) -- (from well out: some stones stick out far)
	local surface = hit and hit.Position or aim
	local wallModel = hit and wallModelOf(hit.Instance)
	-- the stones round the spot stick out unevenly: the wall's sight (and the mark) stand just in front of the one that
	-- sticks out furthest, so no stone hides half of it
	local across = normal:Cross(Vector3.yAxis)
	across = across.Magnitude > 0.1 and across.Unit or Vector3.xAxis
	local front = 0
	for _, o in ipairs({ across * 1.4, -across * 1.4, Vector3.new(0, 1.4, 0), Vector3.new(0, -1.4, 0),
		across * 1, -across * 1, Vector3.new(0, 0.9, 0) }) do
		local h = workspace:Raycast(surface + o + normal * 8, -normal * 14, rayParams)
		if h then
			front = math.max(front, (h.Position - surface):Dot(normal))
		end
	end
	local sightPos = surface + normal * (front + 0.3)

	local spins = { 0, 0, 0 }
	local fired, impacted = false, false
	local fireFrom -- the muzzle position at the shot (the round flies from there)
	local lastWallSpin = 0
	Sfx.playAt("veyr_ring", root.Position, 0.6, 1.0, 120)

	table.insert(active, function(now, sNow, dt)
		if kits[model] ~= kit or kit.shot ~= shotAt or not model.Parent then
			return false -- (the unit is gone, or a newer shot owns the kit now)
		end
		local t = sNow - shotAt
		local o = ringOrigin.WorldPosition
		local hub = CFrame.lookAt(o, surface)

		-- the scope glint as he settles in
		local g = ease(t, 0.5, 0.65) * (1 - ease(t, 0.7, 0.95))
		if scopeLens and g > 0.01 and camera then
			local lp = scopeLens.WorldPosition
			kit.glint.CFrame = CFrame.new(lp)
			kit.glint.Size = Vector3.one * (0.15 + 0.3 * g)
			kit.glint.Transparency = 1 - g
			kit.glintBar.CFrame = CFrame.lookAt(lp, camera.CFrame.Position) * CFrame.Angles(0, 0, 0.3)
			kit.glintBar.Size = Vector3.new(0.3 + 1.4 * g, 0.03, 0.03)
			kit.glintBar.Transparency = 1 - g
		else
			kit.glint.Transparency = 1
			kit.glintBar.Transparency = 1
		end

		-- the sights at the muzzle
		local drift = 1 - ease(t, T.LOCK, T.LOCK + 0.6)
		local contract = ease(t, T.LOCK + 0.4, T.QUIET)
		local flightTime = math.max(0.02, impactT - shotAt - T.FIRE)
		for i, r in ipairs(RINGS) do
			local appear = T.RINGS_FROM + (i - 1) * RING_STEP
			local open = ease(t, appear, appear + 0.4)
			local s = kit.sights[i]
			if open <= 0 then
				VeyrSights.hide(s)
			else
				spins[i] += (i % 2 == 0 and 1 or -1) * (0.15 + 1.6 * drift) * dt
				local ox = math.sin(t * 2.1 + i) * 0.1 * drift * r.r
				local oy = math.cos(t * 1.7 + i * 2) * 0.08 * drift * r.r
				local tilt = math.sin(t * 1.3 + i) * 0.22 * drift
				-- the round passes the sight: a flash and a short pulse outward
				local passT = T.FIRE + r.d / 600
				local pass = ease(t, passT, passT + 0.03) * (1 - ease(t, passT + 0.05, passT + 0.3))
				-- the blast throws each sight forward down the line and wide open as it fades (the farther, the farther)
				local blown = ease(t, passT, passT + 0.5)
				local scale = (0.35 + 0.65 * backOut(open)) * (1 - 0.12 * contract) * (1 + 0.3 * pass) * (1 + 1.8 * blown)
				local d = r.d + blown * (1.5 + 2.2 * i)
				local cf = hub * CFrame.new(ox, oy, -d) * CFrame.Angles(tilt, tilt * 0.6, 0)
				VeyrSights.place(s, cf, scale, math.min(1, open * 1.2) * (1 - blown), spins[i] + blown * (i % 2 == 0 and 1.2 or -1.2))
				if pass > 0.4 then
					VeyrSights.tint(s, pal.core, WHITE)
				else
					VeyrSights.tint(s, pal.color, pal.core)
				end
			end
		end

		-- motes drawn in towards the barrel while they focus
		local moteA = ease(t, T.RINGS_FROM + 0.3, T.RINGS_FROM + 0.8) * (1 - ease(t, T.LOCK + 0.3, T.QUIET))
		for i, m in ipairs(kit.motes) do
			if moteA > 0.01 then
				local u = (t * 0.55 + i / MOTES) % 1
				local rad = RINGS[3].r * 1.25 * (1 - u)
				local a = i * 1.7 + u * 3
				m.CFrame = hub * CFrame.new(math.cos(a) * rad, math.sin(a) * rad, -RINGS[3].d * (1 - u) - 0.2)
				m.Transparency = 1 - moteA * math.sin(u * math.pi)
			else
				m.Transparency = 1
			end
		end

		-- the small sight on the wall where he aims: opens, tightens, snaps shut on the hit
		local wOpen = ease(t, 1.3, 1.9)
		local shut = impacted and ease(sNow, impactT, impactT + 0.22) or 0
		if wOpen > 0 and shut < 1 then
			lastWallSpin += dt * (0.6 * (1 - contract) + 0.05)
			local scale = (1.35 - 0.35 * ease(t, T.LOCK, T.QUIET)) * (1 - shut)
			local wcf = CFrame.lookAt(sightPos, sightPos + normal * 2)
			VeyrSights.place(kit.wall, wcf, scale, wOpen * 0.85 * (1 - shut), lastWallSpin)
		else
			VeyrSights.hide(kit.wall)
		end

		-- the shot
		if not fired and t >= T.FIRE then
			fired = true
			fireFrom = muzzle.WorldPosition
			if t < T.FIRE + 0.3 then
				local axis = hub.LookVector
				-- the blast: a white-hot core, a four-pointed star across the bore, a long spike of flame forward
				local mf = newPart(Vector3.one * 0.9, WHITE, Enum.PartType.Ball)
				mf.CFrame = CFrame.new(fireFrom + axis * 0.4)
				mf.Transparency = 0
				local l = Instance.new("PointLight")
				l.Color = pal.color
				l.Range = 22
				l.Brightness = 9
				l.Shadows = false
				l.Parent = mf
				TweenService:Create(mf, TweenInfo.new(0.16), { Size = Vector3.one * 3.2, Transparency = 1, Color = pal.color }):Play()
				TweenService:Create(l, TweenInfo.new(0.35), { Brightness = 0 }):Play()
				Debris:AddItem(mf, 0.4)
				local across = CFrame.lookAt(fireFrom + axis * 0.5, fireFrom + axis * 2)
				for k = 0, 3 do
					local ray = newPart(Vector3.new(0.12, 2.6, 0.05), WHITE)
					ray.CFrame = across * CFrame.Angles(0, 0, k * math.pi / 2 + math.pi / 4) * CFrame.new(0, 1.3, 0)
					ray.Transparency = 0
					TweenService:Create(ray, TweenInfo.new(0.13), { Size = Vector3.new(0.02, 4.2, 0.02), Transparency = 1 }):Play()
					Debris:AddItem(ray, 0.2)
				end
				local spike = newPart(Vector3.new(0.5, 0.5, 4), pal.core)
				spike.CFrame = CFrame.lookAt(fireFrom + axis * 2.2, fireFrom + axis * 5)
				spike.Transparency = 0.05
				TweenService:Create(spike, TweenInfo.new(0.12), { Size = Vector3.new(0.05, 0.05, 7), Transparency = 1 }):Play()
				Debris:AddItem(spike, 0.2)
				-- two shock discs rolling out of the muzzle, a burst of smoke, the dust kicked off the ground below
				shockDisc(fireFrom + axis * 0.6, axis, 0.5, 4.8, 0.32, pal.core, 0.55)
				task.delay(0.05, function()
					shockDisc(fireFrom + axis * 1.6, axis, 0.4, 3.2, 0.3, pal.color, 0.6)
				end)
				burst(fireFrom + axis * 0.8, axis, 14, { color = Color3.fromRGB(70, 60, 96), size0 = 0.5, size1 = 2.6,
					speed0 = 3, speed1 = 9, spread = 35, life0 = 0.6, life1 = 1.4, t0 = 0.45 })
				local below = workspace:Raycast(fireFrom, Vector3.new(0, -12, 0), rayParams)
				if below then
					burst(below.Position + Vector3.new(0, 0.2, 0), Vector3.yAxis, 20, { color = Color3.fromRGB(84, 78, 72),
						size0 = 0.8, size1 = 3, speed0 = 6, speed1 = 14, spread = 85, life0 = 0.5, life1 = 1.1, accel = Vector3.new(0, 0.5, 0), t0 = 0.5 })
				end
				Sfx.playAt("veyr_crack", fireFrom, 1, 0.97 + math.random() * 0.06, 260)
				ownerShake(model, fireFrom, 0.3)
			end
		end
		if fired and fireFrom then
			local p = math.clamp((t - T.FIRE) / flightTime, 0, 1)
			local dir = (surface - fireFrom)
			local tip = p < 1 and (fireFrom + dir * p) or surface
			if p < 1 then
				kit.round.CFrame = CFrame.lookAt(tip, tip + dir)
				kit.round.Transparency = 0
				kit.roundGlow.CFrame = CFrame.lookAt(tip, tip + dir)
				kit.roundGlow.Transparency = 0.35
			else
				kit.round.Transparency = 1
				kit.roundGlow.Transparency = 1
			end
			-- the pierced line: bright while the round flies, then it lingers along the whole path, thinning out
			local fade = p < 1 and 0 or ease(sNow, impactT, impactT + 0.7)
			local len = math.max(0.2, (tip - fireFrom).Magnitude)
			local mid = CFrame.lookAt(fireFrom:Lerp(tip, 0.5), tip)
			kit.trail.Size = Vector3.new(0.12 * (1 - fade) + 0.01, 0.12 * (1 - fade) + 0.01, len)
			kit.trail.CFrame = mid
			kit.trail.Transparency = 0.05 + 0.95 * fade
			kit.trailGlow.Size = Vector3.new(0.45 * (1 - fade * 0.6), 0.45 * (1 - fade * 0.6), len)
			kit.trailGlow.CFrame = mid
			kit.trailGlow.Transparency = 0.55 + 0.45 * fade
			-- pressure rings roll off the path as the round passes
			for i, f in ipairs(PRESSURE_AT) do
				local born = T.FIRE + f * flightTime
				local k = ease(t, born, born + 0.4)
				local s = kit.pressure[i]
				if t >= born and k < 1 then
					local at = fireFrom + dir * f
					VeyrSights.place(s, CFrame.lookAt(at, at + dir), 0.5 + 2.6 * k, 0.8 * (1 - k), 0)
				else
					VeyrSights.hide(s)
				end
			end
		end

		if not impacted and sNow >= impactT and fired then
			impacted = true
			impact(model, surface, normal, pal, wallModel, sightPos)
		end

		if kit.bolted ~= shotAt and t >= T.BOLT_FROM + 0.3 then
			kit.bolted = shotAt -- (the bolt: MarksmanAnimator moves it; the sound slot is empty until recorded)
			Sfx.playAt("veyr_bolt", root.Position, 1, 1, 90)
		end

		if t > T.SETTLE_END then
			hideKit(kit)
			return false
		end
		return true
	end)
end

-- ============================================================
-- Watching the units
-- ============================================================
local watched = {}
local function watch(model)
	if watched[model] then return end
	watched[model] = true
	model:GetAttributeChangedSignal("ShotAt"):Connect(function()
		if model:GetAttribute("AttackStyle") == "Marksman" then
			onShot(model)
		end
	end)
end
for _, model in ipairs(CollectionService:GetTagged(TAG)) do
	watch(model)
end
CollectionService:GetInstanceAddedSignal(TAG):Connect(watch)
CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(model)
	watched[model] = nil
	if kits[model] then
		destroyKit(kits[model])
		kits[model] = nil
	end
end)

local lastFrame = os.clock()
RunService.RenderStepped:Connect(function()
	local now = os.clock()
	local dt = math.min(now - lastFrame, 0.1)
	lastFrame = now
	local serverNow = workspace:GetServerTimeNow()
	for i = #active, 1, -1 do
		local ok, keep = pcall(active[i], now, serverNow, dt)
		if not ok then
			warn("VeyrShot: " .. tostring(keep))
			keep = false
		end
		if not keep then
			table.remove(active, i)
		end
	end
	updateMarks(now, serverNow)
	for model, kit in pairs(kits) do
		if not model.Parent then
			destroyKit(kit)
			kits[model] = nil
		end
	end
end)

return {}
