-- Orvoss's basic attack, DOUBLE REPORT (units whose model has Pose = "Admiral"; docs/orvoss.md "Basic attack"). The
-- server (Army, the generic attack) sets AttackAt (server time the attack starts), AimPos and AttackCount; the damage
-- lands at AttackAt + AdmiralTimeline.IMPACT. Every beat here runs on the synced server clock from AttackAt
-- (AdmiralAnimator moves his body on the same clock):
--   FORM_FROM .. FORM_TO    a see-through ghost cannon forms at his left, a little behind, out of sea-green fog and
--                           water dripping UPWARDS: the barrel first, then the carriage
--   FUSE_FROM .. FIRE       stillness; the fuse at the touch hole catches and spits
--   FIRE                    pistol and cannon fire as one: a small flash at the flintlock, a big one at the cannon, smoke
--                           and sparks; the cannon rolls back and settles
--   FIRE .. IMPACT          a glowing ball and the pistol's shot fly to the wall and land together (ONE hit)
--   IMPACT                  a flash, sparks and stone dust on the wall
--   SINK_FROM .. SINK_TO    the cannon sinks back into the fog
-- One cannon per unit is built once and reused (hidden between attacks). Purely visual, nothing is networked.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local AT = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("AdmiralTimeline"))

local TAG = "ProceduralUnit"
local MAX_DISTANCE = 320 -- (beyond this from the camera nothing is drawn)
local CANNON_OFFSET = Vector3.new(-2.9, 0, 1.2) -- (his left, a little behind; studs at scale 1 from his root, on the floor)
local TRUNNION_Y = 1.35
local GHOST_T = 0.5 -- (the cannon's parts at full presence)

local GHOST = Color3.fromRGB(70, 175, 145)
local SOUL = Color3.fromRGB(40, 225, 165)
local CORE = Color3.fromRGB(200, 255, 232)
local FOG = Color3.fromRGB(62, 118, 100)
local SMOKE = Color3.fromRGB(88, 104, 98)
local DUST = Color3.fromRGB(96, 92, 86)
local SMOKE_TEX = "rbxasset://textures/particles/smoke_main.dds"
local SPARK_TEX = "rbxasset://textures/particles/sparkles_main.dds"

local fx = Instance.new("Folder")
fx.Name = "DoubleReportFx"
fx.Parent = workspace

local kits = {} -- [model] = the unit's cannon and state
local active = {} -- running one-shot effects: function(serverNow) -> keepGoing

local function ease(x, a, b)
	local k = math.clamp((x - a) / (b - a), 0, 1)
	return k * k * (3 - 2 * k)
end

local function newPart(name, size, color, material, shape)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	if shape then
		p.Shape = shape
	end
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	return p
end

-- an emitter on a tiny invisible part (it emits out of the part's front face: aim the part)
local function emitterPart(name, props)
	local p = newPart(name, Vector3.new(0.2, 0.2, 0.2), Color3.new(), nil)
	p.Transparency = 1
	local e = Instance.new("ParticleEmitter")
	e.Rate = 0
	e.EmissionDirection = Enum.NormalId.Front
	for k, v in pairs(props) do
		e[k] = v
	end
	e.Parent = p
	return p, e
end

local function seq(a, b)
	return NumberSequence.new(a, b)
end

-- ====================================================================
-- The ghost cannon (built once per unit, at its scale)
-- ====================================================================
local function buildKit(model)
	local s = model:GetScale()
	local cannon = Instance.new("Model")
	cannon.Name = "GhostCannon"
	local kit = { model = model, scale = s, cannon = cannon, barrel = {}, carriage = {} }
	local cyl = Enum.PartType.Cylinder
	local ALONG = CFrame.Angles(0, math.pi / 2, 0) -- (a cylinder's X axis turned onto -Z)
	local ACROSS = CFrame.new() -- (a cylinder lying along X)
	local function add(group, name, size, offset, shape)
		local p = newPart(name, size * s, GHOST, Enum.Material.SmoothPlastic, shape)
		p.Transparency = 1
		p.Parent = cannon
		table.insert(group, { part = p, offset = offset.Rotation + offset.Position * s })
		return p
	end
	-- the barrel, in the frame of the trunnions (-Z out of the muzzle)
	local B = kit.barrel
	kit.barrelPart = add(B, "Barrel", Vector3.new(4.4, 1.15, 1.15), CFrame.new(0, 0, -1) * ALONG, cyl)
	add(B, "Breech", Vector3.new(1.5, 1.5, 1.5), CFrame.new(0, 0, 1.3), Enum.PartType.Ball)
	add(B, "Cascabel", Vector3.new(0.6, 0.6, 0.6), CFrame.new(0, 0, 2.15), Enum.PartType.Ball)
	add(B, "Swell", Vector3.new(0.35, 1.45, 1.45), CFrame.new(0, 0, -3.25) * ALONG, cyl)
	add(B, "Band", Vector3.new(0.3, 1.35, 1.35), CFrame.new(0, 0, 0.6) * ALONG, cyl)
	add(B, "Band", Vector3.new(0.3, 1.3, 1.3), CFrame.new(0, 0, -0.9) * ALONG, cyl)
	add(B, "Trunnions", Vector3.new(1.9, 0.45, 0.45), ACROSS, cyl)
	-- the carriage, in a frame on the floor under the trunnions
	local C = kit.carriage
	for _, x in ipairs({ -0.7, 0.7 }) do
		add(C, "Cheek", Vector3.new(0.35, 1.05, 3.4), CFrame.new(x, 0.95, 0.4))
	end
	add(C, "Bed", Vector3.new(1.4, 0.3, 2.8), CFrame.new(0, 0.5, 0.6))
	for _, z in ipairs({ -0.7, 1.6 }) do
		add(C, "Axle", Vector3.new(2.1, 0.3, 0.3), CFrame.new(0, 0.45, z) * ACROSS, cyl)
		for _, x in ipairs({ -1.05, 1.05 }) do
			add(C, "Wheel", Vector3.new(0.3, z < 0 and 1 or 0.9, z < 0 and 1 or 0.9), CFrame.new(x, z < 0 and 0.5 or 0.45, z) * ACROSS, cyl)
		end
	end
	-- the glow round it: a faint fill and a soul-green outline
	local hl = Instance.new("Highlight")
	hl.DepthMode = Enum.HighlightDepthMode.Occluded
	hl.FillColor = SOUL
	hl.OutlineColor = SOUL
	hl.FillTransparency = 1
	hl.OutlineTransparency = 1
	hl.Adornee = cannon
	hl.Parent = cannon
	kit.highlight = hl
	-- the fuse at the touch hole
	kit.fuse = newPart("Fuse", Vector3.new(0.3, 0.3, 0.3) * s, CORE, Enum.Material.Neon, Enum.PartType.Ball)
	kit.fuse.Transparency = 1
	kit.fuse.Parent = cannon
	cannon.Parent = fx

	-- fog and upward drips over the cannon's footprint (the part faces up: they rise)
	local fog = newPart("FogArea", Vector3.new(3, 0.4, 4.4) * s, Color3.new(), nil)
	fog.Transparency = 1
	fog.Parent = cannon
	local f = Instance.new("ParticleEmitter")
	f.Texture = SMOKE_TEX
	f.Color = ColorSequence.new(FOG)
	f.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.4 * s), NumberSequenceKeypoint.new(1, 3.6 * s) })
	f.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.25, 0.55), NumberSequenceKeypoint.new(1, 1) })
	f.Lifetime = NumberRange.new(1.2, 1.9)
	f.Speed = NumberRange.new(0.4, 1.2)
	f.SpreadAngle = Vector2.new(40, 40)
	f.Acceleration = Vector3.new(0, 0.6, 0)
	f.RotSpeed = NumberRange.new(-20, 20)
	f.Rotation = NumberRange.new(0, 360)
	f.LightEmission = 0.3
	f.LightInfluence = 0.4
	f.EmissionDirection = Enum.NormalId.Top
	f.Rate = 0
	f.Parent = fog
	local d = Instance.new("ParticleEmitter")
	d.Texture = SPARK_TEX
	d.Color = ColorSequence.new(CORE)
	d.Size = seq(0.14 * s, 0.05 * s)
	d.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	d.Lifetime = NumberRange.new(0.6, 1.1)
	d.Speed = NumberRange.new(1, 2.5)
	d.Acceleration = Vector3.new(0, 4, 0) -- (water falling the wrong way)
	d.Orientation = Enum.ParticleOrientation.VelocityParallel
	d.SpreadAngle = Vector2.new(15, 15)
	d.LightEmission = 1
	d.EmissionDirection = Enum.NormalId.Top
	d.Rate = 0
	d.Parent = fog
	kit.fog, kit.fogEmit, kit.dripEmit = fog, f, d
	-- fuse sparks
	local fuseSparks = Instance.new("ParticleEmitter")
	fuseSparks.Texture = SPARK_TEX
	fuseSparks.Color = ColorSequence.new(CORE, SOUL)
	fuseSparks.Size = seq(0.18 * s, 0)
	fuseSparks.Lifetime = NumberRange.new(0.15, 0.35)
	fuseSparks.Speed = NumberRange.new(2, 5)
	fuseSparks.SpreadAngle = Vector2.new(60, 60)
	fuseSparks.Acceleration = Vector3.new(0, -6, 0)
	fuseSparks.LightEmission = 1
	fuseSparks.EmissionDirection = Enum.NormalId.Top
	fuseSparks.Rate = 0
	fuseSparks.Parent = kit.fuse
	kit.fuseSparks = fuseSparks
	-- the muzzle: smoke and sparks out of the front (aimed each frame)
	local muzzle, smoke = emitterPart("MuzzleSmoke", {
		Texture = SMOKE_TEX,
		Color = ColorSequence.new(SMOKE),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2 * s), NumberSequenceKeypoint.new(1, 6 * s) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) }),
		Lifetime = NumberRange.new(1.2, 2.2),
		Speed = NumberRange.new(9, 16),
		Drag = 3.5,
		SpreadAngle = Vector2.new(18, 18),
		Acceleration = Vector3.new(0, 0.8, 0),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-30, 30),
		LightInfluence = 0.6,
	})
	local sparks = Instance.new("ParticleEmitter")
	sparks.Texture = SPARK_TEX
	sparks.Color = ColorSequence.new(CORE, SOUL)
	sparks.Size = seq(0.35 * s, 0)
	sparks.Lifetime = NumberRange.new(0.25, 0.5)
	sparks.Speed = NumberRange.new(18, 34)
	sparks.SpreadAngle = Vector2.new(22, 22)
	sparks.Drag = 2
	sparks.LightEmission = 1
	sparks.EmissionDirection = Enum.NormalId.Front
	sparks.Rate = 0
	sparks.Parent = muzzle
	muzzle.Parent = cannon
	kit.muzzle, kit.muzzleSmoke, kit.muzzleSparks = muzzle, smoke, sparks
	-- the flintlock's own small puff
	local pmuz, psmoke = emitterPart("PistolSmoke", {
		Texture = SMOKE_TEX,
		Color = ColorSequence.new(SMOKE),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4 * s), NumberSequenceKeypoint.new(1, 2 * s) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1) }),
		Lifetime = NumberRange.new(0.8, 1.4),
		Speed = NumberRange.new(4, 7),
		Drag = 4,
		SpreadAngle = Vector2.new(15, 15),
		Rotation = NumberRange.new(0, 360),
		LightInfluence = 0.6,
	})
	pmuz.Parent = cannon
	kit.pistolEmit, kit.pistolSmoke = pmuz, psmoke
	for _, dd in ipairs(model:GetDescendants()) do
		if dd:IsA("Attachment") and dd.Name == "Muzzle" then
			kit.pistolMuzzle = dd
			break
		end
	end
	return kit
end

local function hideKit(kit)
	if kit.hidden then
		return
	end
	kit.hidden = true
	for _, g in ipairs({ kit.barrel, kit.carriage }) do
		for _, e in ipairs(g) do
			e.part.Transparency = 1
		end
	end
	kit.fuse.Transparency = 1
	kit.highlight.FillTransparency = 1
	kit.highlight.OutlineTransparency = 1
	kit.fogEmit.Rate = 0
	kit.dripEmit.Rate = 0
	kit.fuseSparks.Rate = 0
end

-- ====================================================================
-- One-shot pieces: flashes, the two shots, the impact
-- ====================================================================
local function flash(pos, size, color, life, light)
	local p = newPart("Flash", Vector3.one * 0.1, color, Enum.Material.Neon, Enum.PartType.Ball)
	p.Position = pos
	p.Parent = fx
	local l
	if light then
		l = Instance.new("PointLight")
		l.Color = color
		l.Range = light
		l.Brightness = 6
		l.Shadows = false
		l.Parent = p
	end
	local t0 = os.clock()
	table.insert(active, function()
		local k = (os.clock() - t0) / life
		if k >= 1 then
			p:Destroy()
			return false
		end
		local grow = math.min(1, k / 0.15)
		p.Size = Vector3.one * size * (0.3 + 0.7 * grow) * (1 + 0.3 * k)
		p.Transparency = ease(k, 0.15, 1)
		if l then
			l.Brightness = 6 * (1 - k)
		end
		return true
	end)
end

-- a burst from a throwaway emitter part (aimed along `dir`), cleaned up after its particles die
local function burst(pos, dir, count, props)
	local p, e = emitterPart("Burst", props)
	p.CFrame = CFrame.lookAt(pos, pos + dir)
	p.Parent = fx
	e:Emit(count)
	Debris:AddItem(p, (props.Lifetime and props.Lifetime.Max or 1) + 0.2)
end

-- a glowing ball with a trail, flying from `from` to `to` so it arrives at server time `arriveAt`
local function shot(from, to, startAt, arriveAt, d, color, arc, s, onArrive)
	local ball = newPart("Shot", Vector3.one * d, color, Enum.Material.Neon, Enum.PartType.Ball)
	ball.CFrame = CFrame.new(from)
	local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
	a0.Position = Vector3.new(0, d * 0.5, 0)
	a1.Position = Vector3.new(0, -d * 0.5, 0)
	a0.Parent, a1.Parent = ball, ball
	local tr = Instance.new("Trail")
	tr.Attachment0, tr.Attachment1 = a0, a1
	tr.Color = ColorSequence.new(CORE, SOUL)
	tr.Transparency = NumberSequence.new(0.15, 1)
	tr.WidthScale = NumberSequence.new(1, 0)
	tr.Lifetime = 0.3
	tr.LightEmission = 1
	tr.FaceCamera = true
	tr.Parent = ball
	ball.Parent = fx
	table.insert(active, function(serverNow)
		local k = (serverNow - startAt) / math.max(arriveAt - startAt, 0.05)
		if k >= 1 then
			ball.Transparency = 1
			Debris:AddItem(ball, 0.3)
			if onArrive then
				onArrive()
			end
			return false
		end
		k = math.max(k, 0)
		ball.CFrame = CFrame.new(from:Lerp(to, k) + Vector3.new(0, math.sin(k * math.pi) * arc * s, 0))
		return true
	end)
end

-- a ring of light spreading flat on the wall from the impact
local function shockwave(pos, normal, size, life)
	local ring = newPart("Shockwave", Vector3.new(0.2, 1, 1), SOUL, Enum.Material.Neon, Enum.PartType.Cylinder)
	ring.CFrame = CFrame.lookAt(pos, pos + normal) * CFrame.Angles(0, math.pi / 2, 0) -- (the disc faces out of the wall)
	ring.Parent = fx
	local t0 = os.clock()
	table.insert(active, function()
		local k = (os.clock() - t0) / life
		if k >= 1 then
			ring:Destroy()
			return false
		end
		local r = size * (1 - (1 - k) ^ 3)
		ring.Size = Vector3.new(0.2, r, r)
		ring.Transparency = 0.35 + 0.65 * k
		return true
	end)
end

-- stone chunks knocked off the wall: they fly out, fall and tumble, then fade
local function chunks(pos, normal, count, s)
	for _ = 1, count do
		local c = newPart("Chunk", Vector3.new(math.random() * 0.6 + 0.4, math.random() * 0.5 + 0.3, math.random() * 0.6 + 0.4) * s, DUST, Enum.Material.Slate)
		local p = pos + normal * 0.5
		c.CFrame = CFrame.new(p)
		c.Parent = fx
		local side = normal:Cross(Vector3.yAxis)
		side = side.Magnitude > 0.01 and side.Unit or Vector3.xAxis
		local v = (normal * (12 + math.random() * 14) + side * (math.random() - 0.5) * 22 + Vector3.new(0, 6 + math.random() * 12, 0)) * s
		local spin = CFrame.Angles(math.random() * 8 - 4, math.random() * 8 - 4, math.random() * 8 - 4)
		local t0, last = os.clock(), os.clock()
		table.insert(active, function()
			local now = os.clock()
			local dt, age = now - last, now - t0
			last = now
			if age > 1.6 then
				c:Destroy()
				return false
			end
			v += Vector3.new(0, -60 * s, 0) * dt
			p += v * dt
			c.CFrame = CFrame.new(p) * (c.CFrame - c.CFrame.Position):Lerp(spin * (c.CFrame - c.CFrame.Position), dt * 2)
			c.Transparency = ease(age, 1.1, 1.6)
			return true
		end)
	end
end

local function impact(pos, normal, s)
	flash(pos + normal * 0.5, 9 * s, SOUL, 0.5, 45)
	flash(pos + normal * 0.7, 4.5 * s, CORE, 0.28)
	shockwave(pos + normal * 0.3, normal, 16 * s, 0.55)
	chunks(pos, normal, 9, s)
	-- a soul-green fireball rolling out of the wall
	burst(pos + normal * 0.8, normal, 18, {
		Texture = "rbxasset://textures/particles/fire_main.dds",
		Color = ColorSequence.new(CORE, SOUL),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2.5 * s), NumberSequenceKeypoint.new(1, 6 * s) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) }),
		Lifetime = NumberRange.new(0.35, 0.6),
		Speed = NumberRange.new(6, 14),
		SpreadAngle = Vector2.new(60, 60),
		Drag = 4,
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-90, 90),
		LightEmission = 1,
	})
	burst(pos + normal * 0.4, normal, 60, {
		Texture = SPARK_TEX,
		Color = ColorSequence.new(CORE, SOUL),
		Size = seq(0.55 * s, 0),
		Lifetime = NumberRange.new(0.35, 0.8),
		Speed = NumberRange.new(22, 48),
		SpreadAngle = Vector2.new(75, 75),
		Acceleration = Vector3.new(0, -35, 0),
		Drag = 1.5,
		LightEmission = 1,
	})
	burst(pos + normal * 0.4, normal, 26, {
		Texture = SMOKE_TEX,
		Color = ColorSequence.new(DUST),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 3 * s), NumberSequenceKeypoint.new(1, 10 * s) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 1) }),
		Lifetime = NumberRange.new(1.4, 2.4),
		Speed = NumberRange.new(6, 14),
		SpreadAngle = Vector2.new(65, 65),
		Drag = 2.5,
		Acceleration = Vector3.new(0, -1.5, 0),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-20, 20),
		LightInfluence = 0.8,
	})
end

-- ====================================================================
-- Every frame
-- ====================================================================
local function fire(kit, cannonMuzzle, cannonDir, aimPos, s)
	local model = kit.model
	local start = kit.start
	-- the cannon: a big flash, smoke and sparks out of the bore
	flash(cannonMuzzle, 3.2 * s, SOUL, 0.32, 24)
	flash(cannonMuzzle, 1.6 * s, CORE, 0.16)
	kit.muzzle.CFrame = CFrame.lookAt(cannonMuzzle, cannonMuzzle + cannonDir)
	kit.muzzleSmoke:Emit(22)
	kit.muzzleSparks:Emit(24)
	local hrp = model.PrimaryPart
	local normal = hrp and Vector3.new(hrp.Position.X - aimPos.X, 0, hrp.Position.Z - aimPos.Z) or Vector3.zero
	normal = normal.Magnitude > 0.1 and normal.Unit or -cannonDir
	shot(cannonMuzzle, aimPos, start + AT.FIRE, start + AT.IMPACT, 1.3 * s, CORE, 0.5, s, function()
		impact(aimPos, normal, s)
	end)
	-- the flintlock: a small flash and puff, its shot flying beside the ball (a little to one side, landing together)
	local pm = kit.pistolMuzzle
	if pm and pm.Parent then
		local mcf = pm.WorldCFrame
		flash(mcf.Position, 0.9 * s, CORE, 0.14, 10)
		kit.pistolEmit.CFrame = CFrame.lookAt(mcf.Position, mcf.Position + mcf.LookVector)
		kit.pistolSmoke:Emit(7)
		local side = (aimPos - mcf.Position):Cross(Vector3.yAxis)
		side = side.Magnitude > 0.01 and side.Unit or Vector3.zero
		shot(mcf.Position, aimPos + side * 0.8 * s + Vector3.new(0, 0.5 * s, 0), start + AT.FIRE, start + AT.IMPACT, 0.3 * s, CORE, 0.3, s)
	end
end

local function step(kit, serverNow, camPos)
	local model = kit.model
	local hrp = model.PrimaryPart
	if not hrp then
		hideKit(kit)
		return
	end
	-- a new attack
	local count = model:GetAttribute("AttackCount") or 0
	if kit.count == nil then
		kit.count = count
	elseif count ~= kit.count then
		kit.count = count
		local at = model:GetAttribute("AttackAt")
		kit.start = (type(at) == "number" and math.abs(serverNow - at) < 5) and at or serverNow
		kit.fired = serverNow - kit.start > AT.FIRE + 0.1 -- (joined mid-attack: no late shot)
	end
	local ta = kit.start and (serverNow - kit.start) or 99
	if ta > AT.SINK_TO + 0.3 or (hrp.Position - camPos).Magnitude > MAX_DISTANCE then
		hideKit(kit)
		return
	end
	kit.hidden = false
	local s = kit.scale
	local aimPos = model:GetAttribute("AimPos")
	if typeof(aimPos) ~= "Vector3" then
		aimPos = hrp.Position + hrp.CFrame.LookVector * 40
	end

	-- where the cannon stands: his left, a little behind, on the floor; turned to the aim point; rolled back by the shot
	local rootH = (model:GetAttribute("RootHeight") or 3.7) * s
	local base = hrp.CFrame * CFrame.new(CANNON_OFFSET.X * s, -rootH, CANNON_OFFSET.Z * s)
	local flatAim = Vector3.new(aimPos.X, base.Y, aimPos.Z)
	local carriageCF = CFrame.lookAt(base.Position, flatAim)
	local rk = ta >= AT.FIRE and (ease(ta, AT.FIRE, AT.FIRE + 0.1) * (1 - ease(ta, AT.FIRE + 0.25, AT.FIRE + 1.2))) or 0
	local form = ease(ta, AT.FORM_FROM, AT.BARREL_TO)
	local formC = ease(ta, AT.CARRIAGE_FROM, AT.FORM_TO)
	local sink = ease(ta, AT.SINK_FROM, AT.SINK_TO)
	carriageCF = carriageCF * CFrame.new(0, (-1.2 * (1 - formC) - 1.6 * sink) * s, 1.6 * rk * s)
	-- (the barrel forms at its full height while the carriage still rises under it: it never dips)
	local trunnion = (carriageCF * CFrame.new(0, TRUNNION_Y * s + 1.2 * (form - formC) * s, 0)).Position
	local barrelCF = CFrame.lookAt(trunnion, aimPos) * CFrame.Angles(0.12 * rk, 0, 0) -- (the muzzle jumps a little)
	local presB = form * (1 - sink)
	local presC = formC * (1 - sink)
	for _, e in ipairs(kit.barrel) do
		e.part.CFrame = barrelCF * e.offset
		e.part.Transparency = 1 - (1 - GHOST_T) * presB
	end
	for _, e in ipairs(kit.carriage) do
		e.part.CFrame = carriageCF * e.offset
		e.part.Transparency = 1 - (1 - GHOST_T) * presC
	end
	local pres = math.max(presB, presC)
	kit.highlight.FillTransparency = 1 - 0.18 * pres
	kit.highlight.OutlineTransparency = 1 - 0.75 * pres
	kit.fog.CFrame = carriageCF * CFrame.new(0, 0.3 * s, 0.4 * s)
	local forming = ta >= AT.FORM_FROM and ta < AT.FORM_TO
	local sinking = ta >= AT.SINK_FROM and ta < AT.SINK_TO
	kit.fogEmit.Rate = (forming or sinking) and 16 or 0
	kit.dripEmit.Rate = forming and 40 or (sinking and 20 or 0)
	-- the fuse: catches, flickers and spits until the shot
	local fuseOn = ta >= AT.FUSE_FROM and ta < AT.FIRE
	kit.fuse.CFrame = barrelCF * CFrame.new(0, 0.62 * s, 1.0 * s)
	kit.fuse.Transparency = fuseOn and (0.1 + 0.3 * math.random()) or 1
	kit.fuseSparks.Rate = fuseOn and 30 or 0

	if ta >= AT.FIRE and not kit.fired then
		kit.fired = true
		local muzzlePos = (barrelCF * CFrame.new(0, 0, -3.5 * s)).Position
		fire(kit, muzzlePos, barrelCF.LookVector, aimPos, s)
	end
end

local function watch(model)
	if kits[model] or not model:IsA("Model") then
		return
	end
	local function try()
		if kits[model] or model:GetAttribute("Pose") ~= "Admiral" or not model:IsDescendantOf(workspace) then
			return
		end
		-- (only army units: the plaza preview and portraits never attack)
		kits[model] = buildKit(model)
	end
	try()
	model:GetAttributeChangedSignal("AttackCount"):Connect(try)
end

for _, model in ipairs(CollectionService:GetTagged(TAG)) do
	watch(model)
end
CollectionService:GetInstanceAddedSignal(TAG):Connect(watch)

RunService.RenderStepped:Connect(function()
	local serverNow = workspace:GetServerTimeNow()
	local cam = workspace.CurrentCamera
	local camPos = cam and cam.CFrame.Position or Vector3.zero
	for model, kit in pairs(kits) do
		if not model.Parent or not model:IsDescendantOf(workspace) then
			kit.cannon:Destroy()
			kits[model] = nil
		else
			local ok, err = pcall(step, kit, serverNow, camPos)
			if not ok then
				warn("DoubleReport: " .. tostring(err))
				hideKit(kit)
			end
		end
	end
	for i = #active, 1, -1 do
		local ok, keep = pcall(active[i], serverNow)
		if not ok or not keep then
			table.remove(active, i)
		end
	end
end)

return {}
