-- Knell's effects on the clients (the server's Army deals the damage: the basic hit hitDelay 0.55 s after AttackCount
-- changes, the Procession's hits at 0.35 / 7.2 / 10.5 s after SpecialAt). UnitAnimator ("Bellbearer") animates the
-- rope pulls and the bell itself.
--   Basic throw  a glowing charge gathers between its hands while they rest at the hip (the Kamehameha pose,
--                UnitAnimator, streaks of energy sucked into it); on the thrust (0.22 s) the bell clangs and a manga-
--                style blast tears to the wall in ~0.3 s (user's reference Downloads/demonsbane.webp): a blinding white
--                flash and beam core, dozens of speed-line streaks widening into a cone, three tapered crescents of light
--                spinning round the axis, dark debris flung along it, dust dragged on the ground; recoil dust and a
--                camera kick; at the wall (0.55 s) a white flash, a spray of sparks, dust, a dust ring, a shake, and three
--                small souls peel out of the stone and drift back into the bell.
--   Procession   (the special) see its section below: one toll, six headless pallbearers carry a chained coffin to
--                the wall, the chains snap, a black-red claw rakes through the wall and leaves tears that implode.
-- VFX (roblox-vfx skill): organic parts are particle bursts (Emit, faded in and out over their lifetime, holders cleaned
-- up after the longest lifetime): sparks at every clang, rings of particles racing outwards over the ground at every
-- toll (12 emitters aimed outwards round a circle), motes falling from the phantom bell's rim, the soul column; the souls flying
-- back into the bell trail ribbons. Bursts shrink when the camera is far (lod) and stay well under the mobile caps.
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local TAG = "ProceduralUnit"
local TEAL = Color3.fromRGB(230, 30, 46) -- (the names stay from the old teal theme: now Knell is red and black)
local PALE = Color3.fromRGB(255, 170, 170)
local DEEP = Color3.fromRGB(90, 8, 16)
local CANDLE = Color3.fromRGB(255, 196, 120)
local DUST = Color3.fromRGB(120, 112, 100)
local CLANG_AT, HIT_AT = 0.22, 0.55 -- basic throw: the arms are flung forward (UnitAnimator), the wave reaches the wall (hitDelay)
local MAX_DISTANCE = 320

local up = Vector3.yAxis
local active, watched = {}, {}
local fx = Instance.new("Folder")
fx.Name = "KnellFx"
fx.Parent = workspace

local shakeUntil, shakePower = 0, 0

local function smooth(x)
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

local function part(parent, name, size, cf, color, transparency, shape, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Transparency = transparency or 0
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = material or Enum.Material.Neon
	if shape then
		p.Shape = shape
	end
	p.Parent = parent
	return p
end

-- a ring of `count` segments; draw(frame, radius, alpha, turn) lays it in frame's XY plane
local function ring(parent, color, count, width)
	local parts = {}
	for i = 1, count do
		parts[i] = part(parent, "Ring", Vector3.one, CFrame.new(), color, 1)
	end
	return function(frame, radius, alpha, turn)
		for i, p in ipairs(parts) do
			local a = i * 2 * math.pi / count + (turn or 0)
			p.Size = Vector3.new(math.max(0.05, 2 * radius * math.sin(math.pi / count)), width, width)
			p.CFrame = frame * CFrame.new(math.sin(a) * radius, math.cos(a) * radius, 0) * CFrame.Angles(0, 0, -a)
			p.Transparency = alpha
		end
	end
end

-- an arc (a wave front): segments on a half circle standing over the ground, in frame's XY plane
local function arc(parent, color, count, width)
	local parts = {}
	for i = 1, count do
		parts[i] = part(parent, "Wave", Vector3.one, CFrame.new(), color, 1)
	end
	return function(frame, radius, alpha)
		for i, p in ipairs(parts) do
			local a0 = math.rad(12) + (i - 1) / count * math.rad(156)
			local a1 = math.rad(12) + i / count * math.rad(156)
			local pa = Vector3.new(math.cos(a0) * radius, math.sin(a0) * radius, 0)
			local pb = Vector3.new(math.cos(a1) * radius, math.sin(a1) * radius, 0)
			local wa, wb = frame * pa, frame * pb
			p.Size = Vector3.new(width, width, (wb - wa).Magnitude + width)
			p.CFrame = CFrame.lookAt((wa + wb) / 2, wb)
			p.Transparency = alpha
		end
	end
end

local function dustAt(pos, amount, size, speed)
	local holder = part(fx, "Dust", Vector3.one, CFrame.new(pos), DUST, 1)
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	e.Color = ColorSequence.new(DUST)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size * 0.5), NumberSequenceKeypoint.new(1, size * 1.5) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) })
	e.Lifetime = NumberRange.new(1, 1.8)
	e.Speed = NumberRange.new(speed * 0.4, speed)
	e.SpreadAngle = Vector2.new(70, 70)
	e.Drag = 2.5
	e.Rate = 0
	e.EmissionDirection = Enum.NormalId.Top
	e.Parent = holder
	e:Emit(amount)
	Debris:AddItem(holder, 2.5)
end

-- distance LOD: full bursts near the camera, half beyond 140 studs
local function lod(pos)
	local camera = workspace.CurrentCamera
	return (camera and (pos - camera.CFrame.Position).Magnitude > 140) and 0.5 or 1
end

local function fadeSeq(peak)
	return NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.12, peak), NumberSequenceKeypoint.new(0.7, peak + (1 - peak) * 0.4), NumberSequenceKeypoint.new(1, 1) })
end

-- a one-shot particle burst from an invisible holder part (sized / turned for the emitter's shape); cleaned up after
-- the longest lifetime
local function burst(cf, size, count, props)
	local holder = part(fx, "Burst", size, cf, TEAL, 1)
	local e = Instance.new("ParticleEmitter")
	e.Texture = props.texture or "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = props.color or ColorSequence.new(PALE, TEAL)
	e.LightEmission = props.lightEmission or 1
	e.LightInfluence = 0
	e.Size = props.sizeSeq or NumberSequence.new({ NumberSequenceKeypoint.new(0, props.size or 1), NumberSequenceKeypoint.new(1, 0) })
	e.Transparency = props.transparency or fadeSeq(0.1)
	e.Lifetime = props.lifetime or NumberRange.new(0.5, 0.9)
	e.Speed = props.speed or NumberRange.new(4, 10)
	e.SpreadAngle = props.spread or Vector2.new(180, 180)
	e.Acceleration = props.acceleration or Vector3.zero
	e.Drag = props.drag or 0
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-90, 90)
	if props.shape then
		e.Shape = props.shape
		e.ShapeStyle = props.shapeStyle or Enum.ParticleEmitterShapeStyle.Volume
		e.ShapeInOut = props.shapeInOut or Enum.ParticleEmitterShapeInOut.Outward
		e.ShapePartial = props.shapePartial or 1
	end
	e.EmissionDirection = props.direction or Enum.NormalId.Top
	e.Rate = 0
	e.Parent = holder
	e:Emit(math.max(1, math.floor(count * lod(cf.Position))))
	Debris:AddItem(holder, (props.lifetime and props.lifetime.Max or 0.9) + 0.3)
	return holder
end

-- a ring of particles racing outwards over the ground from radius r: 12 small emitters round the circle, each aimed
-- outwards along the ground (a Disc emitter's "Outward" goes along its normal, i.e. straight up, not radially)
local function groundRing(pos, r, count, speed, color, texture, lightEmission)
	for k = 1, 12 do
		local a = k / 12 * 2 * math.pi
		local out = Vector3.new(math.cos(a), 0, math.sin(a))
		local at = pos + out * r
		burst(CFrame.lookAt(at, at + out), Vector3.new(2 * math.pi * r / 12, 0.3, 0.3), count / 12, {
			direction = Enum.NormalId.Front, spread = Vector2.new(10, 3),
			speed = NumberRange.new(speed * 0.8, speed), drag = 2.5,
			lifetime = NumberRange.new(0.6, 1.0), size = 1.6, color = color or ColorSequence.new(PALE, TEAL),
			texture = texture, lightEmission = lightEmission,
		})
	end
end

local function effect(update, folder)
	table.insert(active, function(now)
		if not folder.Parent then
			return false
		end
		if update(now) then
			return true
		end
		folder:Destroy()
		return false
	end)
end

local function groundBelow(pos, ignore)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(pos + up * 2, Vector3.new(0, -40, 0), params)
	return hit and hit.Position.Y or (pos.Y - 3)
end

local function nearCamera(...)
	local camera = workspace.CurrentCamera
	if not camera then
		return false
	end
	for _, pos in ipairs({ ... }) do
		if (pos - camera.CFrame.Position).Magnitude < MAX_DISTANCE then
			return true
		end
	end
	return false
end

local function shake(power, length)
	shakeUntil = os.clock() + length
	shakePower = math.max(shakePower, power)
end

-- the clang at the bell's mouth: a flash and a ring bursting round the lip
local function clang(model, strength)
	local mouth = model:FindFirstChild("BellMouth", true)
	if not mouth then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "Clang"
	folder.Parent = fx
	local flash = part(folder, "Flash", Vector3.one, CFrame.new(mouth.Position), PALE, 1, Enum.PartType.Ball)
	local burstRing = ring(folder, TEAL, 18, 0.12 * strength)
	-- sparks thrown off the lip
	burst(CFrame.new(mouth.Position), Vector3.one * 1.5 * strength, 22 * strength, {
		shape = Enum.ParticleEmitterShape.Sphere, speed = NumberRange.new(6 * strength, 13 * strength),
		lifetime = NumberRange.new(0.35, 0.7), size = 0.5 * strength, drag = 3, acceleration = Vector3.new(0, -12, 0),
	})
	local start = os.clock()
	effect(function()
		local a = os.clock() - start
		if a > 0.45 then
			return false
		end
		local f = a / 0.45
		local pos = mouth.Parent and mouth.Position or flash.Position
		flash.CFrame = CFrame.new(pos)
		flash.Size = Vector3.one * (0.8 + 2.4 * f) * strength
		flash.Transparency = 0.2 + 0.8 * f
		burstRing(CFrame.new(pos) * CFrame.Angles(math.pi / 2, 0, 0), (1.5 + 4 * f) * strength, 0.15 + 0.85 * f, a * 3)
		return true
	end, folder)
end

-- ============================================================
-- The basic toll
-- ============================================================
local function basicToll(model)
	local root = model.PrimaryPart
	local mouth = model:FindFirstChild("BellMouth", true)
	if not (root and mouth) then
		return
	end
	task.delay(0.08, function()
		-- (AimPos is set with AttackCount; read it once that update is in)
		local aim = model:GetAttribute("AimPos")
		if not (model.Parent and aim) or not nearCamera(aim, root.Position) then
			return
		end
		local start = os.clock() - 0.08
		local groundY = groundBelow(aim, { fx, model })
		local rHand, lHand = model:FindFirstChild("RHand", true), model:FindFirstChild("LHand", true)
		local from = (rHand and lHand) and (rHand.Position + lHand.Position) / 2 or (root.Position + Vector3.new(0, 1, 0))
		local to = aim
		local dir = (to - from)
		if dir.Magnitude < 1 then
			return
		end
		dir = dir.Unit
		local folder = Instance.new("Folder")
		folder.Name = "BasicToll"
		folder.Parent = fx
		local trail = part(folder, "WaveDust", Vector3.one, CFrame.new(from), DUST, 1)
		local dust = Instance.new("ParticleEmitter")
		dust.Texture = "rbxasset://textures/particles/smoke_main.dds"
		dust.Color = ColorSequence.new(DUST)
		dust.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 3) })
		dust.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1) })
		dust.Lifetime = NumberRange.new(0.6, 1.1)
		dust.Speed = NumberRange.new(1, 3)
		dust.SpreadAngle = Vector2.new(60, 60)
		dust.EmissionDirection = Enum.NormalId.Top
		dust.Rate = 0
		dust.Parent = trail
		local souls, clanged, arrived = {}, false, false
		local blast -- (the manga blast's parts and state, built on the thrust)
		effect(function()
			local a = os.clock() - start
			if a > HIT_AT + 1.4 or not model.Parent then
				return false
			end
			if a >= CLANG_AT and not clanged then
				clanged = true
				clang(model, 1)
				-- the throw leaves from where the hands are at the thrust
				if rHand and lHand then
					from = (rHand.Position + lHand.Position) / 2
					dir = (to - from).Magnitude > 1 and (to - from).Unit or dir
				end
				-- the manga blast (reference: a speed-lined anime shockwave): a blinding white core at the hands, a white
				-- beam core, dozens of speed-line streaks racing to the wall, crescents of light spinning round the axis and
				-- widening, dark debris flung along it; everything reaches the wall in ~0.3 s
				blast = { t0 = os.clock(), from = from, dir = dir, dist = (to - from).Magnitude, parts = {} }
				local right = dir:Cross(up)
				right = right.Magnitude > 0.1 and right.Unit or Vector3.xAxis
				blast.right, blast.upv = right, right:Cross(dir).Unit
				blast.flash = part(folder, "BlastFlash", Vector3.one, CFrame.new(from), Color3.new(1, 1, 1), 0, Enum.PartType.Ball)
				blast.beam = part(folder, "BlastBeam", Vector3.new(1.4, 1.4, 1), CFrame.new(from), PALE, 0, Enum.PartType.Cylinder)
				blast.streaks = {}
				for i = 1, 34 do
					table.insert(blast.streaks, {
						part = part(folder, "Streak", Vector3.new(0.12, 0.12, 1), CFrame.new(from), (i % 3 == 0) and TEAL or Color3.new(1, 1, 1), 1),
						angle = math.random() * 2 * math.pi, r0 = math.random() * 1.2, r1 = 1 + math.random() * 5.5,
						delay = math.random() * 0.12, len = 5 + math.random() * 9, thick = 0.07 + math.random() * 0.16,
						speed = 1.15 + math.random() * 0.5,
					})
				end
				blast.crescents = {}
				for c = 1, 3 do
					local segs = {}
					for i = 1, 14 do
						segs[i] = part(folder, "Crescent", Vector3.one, CFrame.new(from), (c == 2) and TEAL or Color3.new(1, 1, 1), 1)
					end
					table.insert(blast.crescents, { segs = segs, phase = c * 2.1, delay = (c - 1) * 0.05, spin = (c % 2 == 0) and -14 or 12 })
				end
				blast.debris = {}
				for i = 1, 12 do
					local sz = 0.3 + math.random() * 0.7
					local spread = blast.right * (math.random() - 0.5) * 1.2 + blast.upv * (math.random() - 0.3) * 0.9
					table.insert(blast.debris, {
						part = part(folder, "Debris", Vector3.new(sz, sz * 0.7, sz), CFrame.new(from), Color3.fromRGB(28, 26, 30), 0, nil, Enum.Material.Slate),
						vel = (dir + spread).Unit * (45 + math.random() * 40), spin = Vector3.new(math.random(), math.random(), math.random()) * 14,
					})
				end
				-- the recoil: dust blown out at its feet, the camera kicked when near
				groundRing(Vector3.new(root.Position.X, groundY + 0.4, root.Position.Z), 1.5, 36, 14,
					ColorSequence.new(DUST), "rbxasset://textures/particles/smoke_main.dds", 0)
				local camera = workspace.CurrentCamera
				if camera and (camera.CFrame.Position - root.Position).Magnitude < 60 then
					shake(0.7, 0.35)
				end
			end
			if blast then
				local bt = os.clock() - blast.t0
				local F, D = blast.from, blast.dir
				-- the white flash at the hands
				local fk = math.clamp(bt / 0.16, 0, 1)
				blast.flash.Size = Vector3.one * (1 + 7 * fk)
				blast.flash.Transparency = fk
				-- the beam core: a white bolt from the hands to the head of the blast, thinning and fading fast
				local head = math.min(1, bt / 0.25) * blast.dist
				local bk = math.clamp(bt / 0.32, 0, 1)
				blast.beam.Size = Vector3.new(math.max(0.1, head), 1.6 * (1 - bk) + 0.1, 1.6 * (1 - bk) + 0.1)
				blast.beam.CFrame = CFrame.lookAt(F + D * head / 2, F + D * head) * CFrame.Angles(0, math.pi / 2, 0)
				blast.beam.Transparency = 0.05 + 0.95 * bk
				-- speed lines: thin streaks shooting from the hands to the wall, the cone widening as they go
				for _, st in ipairs(blast.streaks) do
					local u = (bt - st.delay) * st.speed / 0.3
					if u <= 0 or u >= 1.15 then
						st.part.Transparency = 1
					else
						local d = math.min(u, 1) * blast.dist
						local r = st.r0 + (st.r1 - st.r0) * math.min(u, 1)
						local off = (blast.right * math.cos(st.angle) + blast.upv * math.sin(st.angle)) * r
						local len = math.min(st.len, d + 0.5)
						local tip = F + D * d + off
						st.part.Size = Vector3.new(st.thick, st.thick, len)
						st.part.CFrame = CFrame.lookAt(tip - D * len / 2, tip)
						st.part.Transparency = u > 0.85 and (u - 0.85) / 0.3 or 0.05
					end
				end
				-- crescents: bright arcs spinning round the axis, flying forward and widening
				for _, cr in ipairs(blast.crescents) do
					local u = (bt - cr.delay) / 0.3
					local vis = (u > 0 and u < 1.2)
					local d = math.min(u, 1) * blast.dist
					local radius = 1.5 + 4.5 * math.min(u, 1)
					local centre = F + D * d
					for i, seg in ipairs(cr.segs) do
						if not vis then
							seg.Transparency = 1
						else
							local a0 = cr.phase + bt * cr.spin + (i - 1) / 14 * math.rad(210)
							local a1 = cr.phase + bt * cr.spin + i / 14 * math.rad(210)
							local p0 = centre + (blast.right * math.cos(a0) + blast.upv * math.sin(a0)) * radius
							local p1 = centre + (blast.right * math.cos(a1) + blast.upv * math.sin(a1)) * radius
							local taper = math.sin((i - 0.5) / 14 * math.pi) -- thick in the middle, a point at both ends
							local th = 0.05 + 0.4 * taper
							seg.Size = Vector3.new(th, th, (p1 - p0).Magnitude + th)
							seg.CFrame = CFrame.lookAt((p0 + p1) / 2, p1)
							seg.Transparency = u > 0.8 and math.clamp((u - 0.8) / 0.4, 0, 1) or 0.05
						end
					end
				end
				-- debris flung along the blast
				for _, db in ipairs(blast.debris) do
					local pos = F + db.vel * bt + Vector3.new(0, -30 * bt * bt, 0)
					db.part.CFrame = CFrame.new(pos) * CFrame.Angles(db.spin.X * bt, db.spin.Y * bt, db.spin.Z * bt)
					db.part.Transparency = math.clamp((bt - 0.45) / 0.3, 0, 1)
				end
			end
			-- the blast flies from the hands to the wall
			local k = math.clamp((a - CLANG_AT) / (HIT_AT - CLANG_AT), 0, 1)
			if a >= CLANG_AT and k < 1 then
				local pos = from:Lerp(to, k)
				-- dust dragged along the ground under the blast
				dust.Rate = 70
				trail.Position = Vector3.new(pos.X, groundY + 0.5, pos.Z)
			else
				dust.Rate = 0
			end
			-- it reaches the wall: a flash and dust, souls peel out of the stone and drift back into the bell
			if k >= 1 and not arrived then
				arrived = true
				dustAt(aim, 30, 5, 16)
				burst(CFrame.lookAt(aim, aim - dir), Vector3.one, 40, {
					direction = Enum.NormalId.Front, spread = Vector2.new(70, 70), speed = NumberRange.new(14, 30),
					lifetime = NumberRange.new(0.3, 0.6), size = 0.8, drag = 3, color = ColorSequence.new(Color3.new(1, 1, 1), TEAL),
				})
				groundRing(Vector3.new(aim.X, groundY + 0.4, aim.Z), 1.5, 24, 12, ColorSequence.new(DUST), "rbxasset://textures/particles/smoke_main.dds", 0)
				local camera = workspace.CurrentCamera
				if camera and (camera.CFrame.Position - aim).Magnitude < 80 then
					shake(0.6, 0.35)
				end
				local flash = part(folder, "HitFlash", Vector3.one, CFrame.new(aim), Color3.new(1, 1, 1), 0, Enum.PartType.Ball)
				souls.flash = flash
				for i = 1, 3 do
					local off = Vector3.new(math.random() - 0.5, math.random() - 0.3, math.random() - 0.5) * 3
					local soulPart = part(folder, "Soul", Vector3.one * 0.45, CFrame.new(aim + off), PALE, 0, Enum.PartType.Ball)
					-- a ghostly ribbon behind it
					local a0 = Instance.new("Attachment")
					a0.Position = Vector3.new(0, 0.2, 0)
					a0.Parent = soulPart
					local a1 = Instance.new("Attachment")
					a1.Position = Vector3.new(0, -0.2, 0)
					a1.Parent = soulPart
					local tr = Instance.new("Trail")
					tr.Attachment0 = a0
					tr.Attachment1 = a1
					tr.Color = ColorSequence.new(PALE, TEAL)
					tr.Transparency = NumberSequence.new(0.35, 1)
					tr.LightEmission = 1
					tr.Lifetime = 0.35
					tr.FaceCamera = true
					tr.Parent = soulPart
					table.insert(souls, { part = soulPart, from = aim + off, delay = (i - 1) * 0.12 })
				end
			end
			if arrived then
				local s = a - HIT_AT
				if souls.flash then
					local f = math.clamp(s / 0.3, 0, 1)
					souls.flash.Size = Vector3.one * (2 + 8 * f)
					souls.flash.Transparency = f
				end
				local target = mouth.Parent and mouth.Position or to
				for _, soul in ipairs(souls) do
					local f = math.clamp((s - soul.delay) / 1.1, 0, 1)
					local e = f * f * (3 - 2 * f)
					local ctrl = (soul.from + target) / 2 + up * 6
					local pos = soul.from:Lerp(ctrl, e):Lerp(ctrl:Lerp(target, e), e)
					soul.part.Position = pos
					soul.part.Size = Vector3.one * (0.45 - 0.25 * f)
					soul.part.Transparency = (f >= 1) and 1 or 0.1 + 0.5 * f
				end
			end
			return true
		end, folder)
	end)
end

-- ============================================================
-- The Procession (special): one toll; six headless pallbearers rise with a chained coffin and carry it to the wall,
-- kneel, the chains snap, the lid lifts a crack, an enormous claw of black and red energy rises out of it, winds up
-- and rakes through the wall in one very fast blow (momentum: it keeps going and tears out of sight), leaving four
-- black-red tears that linger, crackle and implode into themselves; the procession crumbles to ash.
-- Timings match Units.Knell.special (hits at 0.35 / 7.2 / 10.5 s) and UnitAnimator's Knell block.
-- ============================================================
local RED = Color3.fromRGB(225, 22, 40)
local BLOOD = Color3.fromRGB(110, 6, 16)
local VOIDBLACK = Color3.fromRGB(6, 4, 6)
local ASH = Color3.fromRGB(40, 36, 40)
local WOOD = Color3.fromRGB(46, 30, 24)
local IRON = Color3.fromRGB(64, 64, 70)
-- (the claw: a long fluent wind-up 6.1..7.1, the strike 7.1..7.22 (hit 7.2), a long follow-through to 8.1; the tear
-- lingers as a void portal until 10.2 and implodes by 10.6 (hit 10.5))
local P = { toll = 0.35, rise0 = 0.6, rise1 = 2.0, march1 = 4.6, kneel1 = 5.2, snap = 5.3, lid0 = 5.5, lid1 = 6.1,
	wind1 = 7.1, strike1 = 7.22, follow1 = 8.1, hit = 7.2, ash = 7.4, implode0 = 10.2, implode1 = 10.6, total = 11.0 }
local CLAW_SCALE = 1.5

-- a list of parts with offsets in some frame; place(frame) moves them
local function rig()
	local r = { items = {} }
	function r.add(p, offset, data)
		local item = { part = p, offset = offset, base = p.Transparency }
		if data then
			for k, v in pairs(data) do
				item[k] = v
			end
		end
		table.insert(r.items, item)
		return item
	end
	return r
end

-- black core with a red glow shell (the claw's look)
local function energyPart(folder, size)
	local core = part(folder, "ClawCore", size, CFrame.new(), VOIDBLACK, 1, nil, Enum.Material.SmoothPlastic)
	local glow = part(folder, "ClawGlow", size * 1.18, CFrame.new(), RED, 1) -- (a thin red rim round the black core)
	return core, glow
end

local function procession(model)
	local at = model:GetAttribute("SpecialAt")
	local aim = model:GetAttribute("SpecialAim")
	local root = model.PrimaryPart
	if not (at and aim and root) or #active > 16 or not nearCamera(aim, root.Position) then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "Procession"
	folder.Parent = fx
	local groundY = groundBelow(aim, { fx, model })
	local unitGround = Vector3.new(root.Position.X, groundY, root.Position.Z)
	local wallGround = Vector3.new(aim.X, groundY, aim.Z)
	local lane = (wallGround - unitGround) * Vector3.new(1, 0, 1)
	local laneDir = lane.Magnitude > 1 and lane.Unit or Vector3.new(0, 0, -1)
	local right = laneDir:Cross(up).Unit
	local dist = lane.Magnitude
	local startC = unitGround + laneDir * 5
	local stopC = wallGround - laneDir * 9
	if (stopC - unitGround):Dot(laneDir) < 7 then
		stopC = startC + laneDir * 2
	end
	local rng = Random.new(model:GetAttribute("SpecialSeed") or 1)

	-- ── the coffin (frame: centre, -Z towards the wall) ──
	local coffin = rig()
	coffin.add(part(folder, "Coffin", Vector3.new(2.4, 1.3, 6), CFrame.new(), WOOD, 0, nil, Enum.Material.Wood), CFrame.new())
	coffin.add(part(folder, "CoffinTrim", Vector3.new(2.55, 0.18, 6.15), CFrame.new(), Color3.fromRGB(30, 20, 18), 0, nil, Enum.Material.Wood), CFrame.new(0, -0.62, 0))
	local seam = coffin.add(part(folder, "Seam", Vector3.new(2.3, 0.08, 0.1), CFrame.new(), RED, 1), CFrame.new(0, 0.66, -2.95))
	local lidParts = {}
	table.insert(lidParts, part(folder, "Lid", Vector3.new(2.6, 0.32, 6.2), CFrame.new(), WOOD, 0, nil, Enum.Material.Wood))
	table.insert(lidParts, part(folder, "LidCross", Vector3.new(0.3, 0.1, 2.6), CFrame.new(), IRON, 0, nil, Enum.Material.Metal))
	table.insert(lidParts, part(folder, "LidCross", Vector3.new(1.4, 0.1, 0.3), CFrame.new(), IRON, 0, nil, Enum.Material.Metal))
	local lidOffsets = { CFrame.new(0, 0, 0), CFrame.new(0, 0.2, 0.4), CFrame.new(0, 0.2, -0.3) }
	-- the chains: two bands of links round the coffin
	local links = {}
	for _, z in ipairs({ -1.7, 1.7 }) do
		local path = {}
		for i = 0, 5 do
			table.insert(path, CFrame.new(-1.25 + i * 0.5, 1.02, z) * CFrame.Angles(0, math.pi / 2, (i % 2) * math.pi / 2))
		end
		for _, side in ipairs({ -1, 1 }) do
			for i = 0, 3 do
				table.insert(path, CFrame.new(side * 1.33, 0.75 - i * 0.45, z) * CFrame.Angles(math.pi / 2, 0, (i % 2) * math.pi / 2))
			end
		end
		for _, off in ipairs(path) do
			table.insert(links, { part = part(folder, "ChainLink", Vector3.new(0.26, 0.12, 0.5), CFrame.new(), IRON, 0, nil, Enum.Material.Metal),
				offset = off, vel = nil })
		end
	end
	local glowHolder = part(folder, "CoffinGlow", Vector3.one * 0.3, CFrame.new(), RED, 1)
	local glowLight = Instance.new("PointLight")
	glowLight.Color = RED
	glowLight.Range = 14
	glowLight.Brightness = 0
	glowLight.Shadows = false
	glowLight.Parent = glowHolder
	local smoke = Instance.new("ParticleEmitter")
	smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
	smoke.Color = ColorSequence.new(Color3.fromRGB(20, 10, 12), BLOOD)
	smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 3.5) })
	smoke.Transparency = fadeSeq(0.35)
	smoke.Lifetime = NumberRange.new(0.8, 1.4)
	smoke.Speed = NumberRange.new(1, 3)
	smoke.SpreadAngle = Vector2.new(40, 40)
	smoke.EmissionDirection = Enum.NormalId.Top
	smoke.Rate = 0
	smoke.Parent = glowHolder

	-- ── six headless pallbearers (frame: on the ground, -Z towards the wall) ──
	local bearers = {}
	for _, side in ipairs({ -1, 1 }) do
		for _, z in ipairs({ -2.2, 0, 2.2 }) do
			local b = rig()
			b.local0 = CFrame.new(side * 1.75, 0, z)
			b.add(part(folder, "Robe", Vector3.new(1.4, 2.2, 1.0), CFrame.new(), ASH, 0.1), CFrame.new(0, 3.2, 0))
			b.add(part(folder, "Chest", Vector3.new(1.7, 1.0, 1.05), CFrame.new(), ASH, 0.1), CFrame.new(0, 4.5, 0))
			b.add(part(folder, "Stump", Vector3.new(0.3, 0.55, 0.55), CFrame.new(), RED, 0, Enum.PartType.Cylinder), CFrame.new(0, 5.05, 0) * CFrame.Angles(0, 0, math.pi / 2))
			b.add(part(folder, "Arm", Vector3.new(0.38, 1.1, 0.38), CFrame.new(), ASH, 0.1), CFrame.new(-side * 0.55, 5.4, 0))
			b.add(part(folder, "Arm", Vector3.new(0.38, 0.9, 0.38), CFrame.new(), ASH, 0.1), CFrame.new(side * 0.6, 5.2, 0.2))
			b.legs = {}
			for _, lx in ipairs({ -0.35, 0.35 }) do
				table.insert(b.legs, b.add(part(folder, "Leg", Vector3.new(0.5, 2.2, 0.5), CFrame.new(), ASH, 0.1), CFrame.new(lx, 2.2, 0), { leg = lx }))
			end
			b.ashDelay = rng:NextNumber(0, 0.5)
			table.insert(bearers, b)
		end
	end

	-- ── the claw (frame: the wrist, -Z = the fingers, -Y = the palm) ──
	local S = CLAW_SCALE
	local claw = { segs = {}, all = {} }
	local function clawPart(size)
		local core, glow = energyPart(folder, size)
		table.insert(claw.all, core)
		table.insert(claw.all, glow)
		return { core = core, glow = glow }
	end
	claw.palm = clawPart(Vector3.new(3.4, 0.9, 2.6) * S)
	claw.arm = clawPart(Vector3.new(1.7, 1.7, 1) * S)
	for f = 1, 4 do
		claw.segs[f] = {}
		for k, len in ipairs({ 2.2, 1.8, 1.4 }) do
			local w = (0.62 - k * 0.12) * S
			claw.segs[f][k] = { len = len * S, p = clawPart(Vector3.new(w, w, len * S)) }
		end
		local talon = part(folder, "Talon", Vector3.new(0.22, 0.22, 1.3) * S, CFrame.new(), RED, 1)
		table.insert(claw.all, talon)
		claw.segs[f].talon = talon
		-- a red ribbon behind every talon (the rake's momentum made visible)
		local a0 = Instance.new("Attachment")
		a0.Position = Vector3.new(0.12, 0, 0)
		a0.Parent = talon
		local a1 = Instance.new("Attachment")
		a1.Position = Vector3.new(-0.12, 0, 0)
		a1.Parent = talon
		local tr = Instance.new("Trail")
		tr.Attachment0 = a0
		tr.Attachment1 = a1
		tr.Color = ColorSequence.new(RED, BLOOD)
		tr.Transparency = NumberSequence.new(0.1, 1)
		tr.LightEmission = 1
		tr.Lifetime = 0.25
		tr.WidthScale = NumberSequence.new(1, 0)
		tr.FaceCamera = true
		tr.Enabled = false
		tr.Parent = talon
		claw.segs[f].trail = tr
	end
	local clawSmoke = Instance.new("ParticleEmitter")
	clawSmoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
	clawSmoke.Color = ColorSequence.new(VOIDBLACK, BLOOD)
	clawSmoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 5) })
	clawSmoke.Transparency = fadeSeq(0.3)
	clawSmoke.Lifetime = NumberRange.new(0.5, 0.9)
	clawSmoke.Speed = NumberRange.new(0.5, 2)
	clawSmoke.SpreadAngle = Vector2.new(180, 180)
	clawSmoke.Rate = 0
	clawSmoke.Parent = claw.palm.glow
	local function placeClaw(wrist, curl, vis)
		local function put(p, cf)
			p.core.CFrame = cf
			p.glow.CFrame = cf
			p.core.Transparency = 1 - vis * 0.95
			p.glow.Transparency = 1 - vis * 0.28
		end
		put(claw.palm, wrist * CFrame.new(0, 0, -1.3 * S))
		for f = 1, 4 do
			local spread = (f - 2.5) * 0.13 * (1 - curl * 0.5)
			local cf = wrist * CFrame.new((f - 2.5) * 0.85 * S, 0, -2.6 * S) * CFrame.Angles(0, -spread, 0)
			for k = 1, 3 do
				local seg = claw.segs[f][k]
				cf = cf * CFrame.Angles(-(0.12 + curl * 0.6), 0, 0)
				put(seg.p, cf * CFrame.new(0, 0, -seg.len / 2))
				cf = cf * CFrame.new(0, 0, -seg.len)
			end
			local talon = claw.segs[f].talon
			talon.CFrame = cf * CFrame.Angles(-(0.3 + curl * 0.5), 0, 0) * CFrame.new(0, 0, -0.55 * S)
			talon.Transparency = 1 - vis
		end
	end

	-- ── the tear: four diagonal slashes (top right to bottom left, the way the claw rakes) that become a void portal:
	-- wide black cores, red rims, a dark haze drawn into them, red lightning crackling over them, everything jittering ──
	local face = aim - laneDir * 1.1 -- (the wall model's stones stand ~0.4 in front of the aim point)
	local diagTop, diagBottom = up * 7.5 + right * 6, -up * 7 - right * 6
	local tears = {}
	for k = 1, 4 do
		local off = (k - 2.5) * 1.8 * S
		local shift = right * off * 0.7 - up * off * 0.55 -- (the slashes lie side by side across the diagonal)
		local top = face + diagTop + shift
		local bottom = face + diagBottom + shift
		local slash = { segs = {}, delay = (k - 1) * 0.012, top = top, bottom = bottom }
		local prev = top
		for i = 1, 9 do
			local p = top:Lerp(bottom, i / 9) + (right + up) * rng:NextNumber(-0.3, 0.3)
			local width = math.sin(i / 9 * math.pi) * 1.4 + 0.25 -- (widest in the middle: a gaping wound)
			local mid = (prev + p) / 2
			local rim = part(folder, "TearRim", Vector3.new(width * 1.5, 0.2, (p - prev).Magnitude + 0.25), CFrame.lookAt(mid, p, laneDir), RED, 1)
			local core = part(folder, "TearCore", Vector3.new(width * 1.05, 0.3, (p - prev).Magnitude + 0.15), CFrame.lookAt(mid - laneDir * 0.12, p - laneDir * 0.12, laneDir), VOIDBLACK, 1, nil, Enum.Material.SmoothPlastic)
			table.insert(slash.segs, { rim = rim, core = core, rimCf = rim.CFrame, coreCf = core.CFrame, rimSize = rim.Size, coreSize = core.Size, frac = i / 9, seed = rng:NextNumber(0, 10) })
			prev = p
		end
		table.insert(tears, slash)
	end
	local tearCentre = face
	-- red lightning: bolts of jagged segments, re-struck every few frames between points along the slashes
	local bolts = {}
	for b = 1, 7 do
		local segs = {}
		for i = 1, 6 do
			segs[i] = part(folder, "Lightning", Vector3.new(0.12, 0.12, 1), CFrame.new(), (i % 2 == 0) and RED or Color3.fromRGB(255, 120, 120), 1)
		end
		table.insert(bolts, { segs = segs, nextAt = 0 })
	end
	local function strikeBolt(bolt)
		local sa, sb = tears[rng:NextInteger(1, #tears)], tears[rng:NextInteger(1, #tears)]
		local a = sa.top:Lerp(sa.bottom, rng:NextNumber(0.1, 0.9)) - laneDir * 0.4
		local b = sb.top:Lerp(sb.bottom, rng:NextNumber(0.1, 0.9)) - laneDir * rng:NextNumber(0.4, 2.5) + (right * rng:NextNumber(-2, 2) + up * rng:NextNumber(-2, 2))
		local prev = a
		for i, seg in ipairs(bolt.segs) do
			local p = a:Lerp(b, i / #bolt.segs) + (i < #bolt.segs and (right * rng:NextNumber(-0.7, 0.7) + up * rng:NextNumber(-0.7, 0.7) - laneDir * rng:NextNumber(0, 0.5)) or Vector3.zero)
			seg.Size = Vector3.new(0.12, 0.12, (p - prev).Magnitude + 0.1)
			seg.CFrame = CFrame.lookAt((prev + p) / 2, p)
			prev = p
		end
		bolt.nextAt = os.clock() + rng:NextNumber(0.05, 0.14)
		bolt.litUntil = os.clock() + rng:NextNumber(0.04, 0.09)
	end
	-- the dark haze drawn into the portal (a sphere emitter, inward)
	local hazeHolder = part(folder, "VoidHaze", Vector3.one * 16, CFrame.new(face), VOIDBLACK, 1)
	local haze = Instance.new("ParticleEmitter")
	haze.Texture = "rbxasset://textures/particles/smoke_main.dds"
	haze.Color = ColorSequence.new(VOIDBLACK, BLOOD)
	haze.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 3), NumberSequenceKeypoint.new(1, 0.5) })
	haze.Transparency = fadeSeq(0.35)
	haze.Lifetime = NumberRange.new(0.7, 1.1)
	haze.Speed = NumberRange.new(6, 10)
	haze.Shape = Enum.ParticleEmitterShape.Sphere
	haze.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	haze.ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward
	haze.Rate = 0
	haze.Parent = hazeHolder
	local voidLight = Instance.new("PointLight")
	voidLight.Color = RED
	voidLight.Range = 24
	voidLight.Brightness = 0
	voidLight.Shadows = false
	voidLight.Parent = hazeHolder

	local snapped, ashed, imploded, tolled, struck = false, false, false, false, false
	local lastT = 0
	effect(function(now)
		local t = now - at
		if t > P.total or not model.Parent then
			return false
		end
		if t < 0 then
			return true
		end
		local dt = math.clamp(t - lastT, 0, 0.1)
		lastT = t

		-- the one toll
		if t >= P.toll and not tolled then
			tolled = true
			clang(model, 2.2)
			groundRing(Vector3.new(root.Position.X, groundY + 0.4, root.Position.Z), 2, 120, 34)
			dustAt(startC + up, 26, 5, 14)
		end

		-- where the procession is: rising, marching, kneeling
		local riseK = smooth((t - P.rise0) / (P.rise1 - P.rise0))
		local marchK = smooth((t - P.rise1) / (P.march1 - P.rise1))
		local kneelK = smooth((t - P.march1) / (P.kneel1 - P.march1))
		local centre = startC:Lerp(stopC, marchK) - up * 7.5 * (1 - riseK)
		local marching = (t > P.rise1 and t < P.march1) and 1 or 0
		local phase = (t - P.rise1) * 2 * math.pi * 1.1
		local bob = math.abs(math.sin(phase)) * 0.18 * marching
		local frame = CFrame.lookAt(centre, centre + laneDir) + up * (bob - 1.4 * kneelK)
		if t >= P.rise0 and t - dt < P.rise0 then
			dustAt(startC + up, 30, 6, 12)
		end

		-- the bearers: legs swing in step, kneel at the stop; crumble to ash after the strike
		for _, b in ipairs(bearers) do
			local bf = frame * b.local0
			local ash = smooth((t - P.ash - b.ashDelay) / 0.9)
			if t >= P.ash + b.ashDelay and not b.ashed then
				b.ashed = true
				burst(bf + up * 3.5, Vector3.new(1.5, 4, 1.5), 22, {
					texture = "rbxasset://textures/particles/smoke_main.dds", color = ColorSequence.new(ASH, Color3.fromRGB(70, 64, 66)),
					lightEmission = 0, speed = NumberRange.new(1, 4), spread = Vector2.new(60, 60), lifetime = NumberRange.new(1, 1.8),
					sizeSeq = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 2.5) }),
					acceleration = Vector3.new(0, 1.5, 0),
				})
			end
			for _, item in ipairs(b.items) do
				local off = item.offset
				if item.leg then
					local swing = math.sin(phase + (item.leg < 0 and 0 or math.pi)) * 0.45 * marching
					off = CFrame.new(item.leg, 2.2, 0) * CFrame.Angles(swing - 1.1 * kneelK * (item.leg < 0 and 1 or 0.4), 0, 0) * CFrame.new(0, -1.1, 0)
				end
				item.part.CFrame = bf * off - up * 1.6 * ash * ash
				item.part.Transparency = item.base + (1 - item.base) * ash
			end
		end

		-- the coffin on their shoulders, swaying with the steps
		local cf = frame * CFrame.new(0, 5.95, 0) * CFrame.Angles(0, 0, math.sin(phase) * 0.04 * marching)
		local coffinAsh = smooth((t - P.ash - 0.25) / 1.0)
		for _, item in ipairs(coffin.items) do
			item.part.CFrame = cf * item.offset - up * 1.2 * coffinAsh
			if item ~= seam then
				item.part.Transparency = coffinAsh
			end
		end
		-- the lid: trembles, then lifts a crack at its front end (hinged at the back)
		local tremble = (t > P.snap and t < P.lid0 + 0.1) and math.sin(t * 60) * 0.02 or 0
		local lidA = smooth((t - P.lid0) / (P.lid1 - P.lid0)) * 0.42 + tremble
		local lidCf = cf * CFrame.new(0, 0.81, 3.1) * CFrame.Angles(lidA, 0, 0) * CFrame.new(0, 0, -3.1)
		for i, lp in ipairs(lidParts) do
			lp.CFrame = lidCf * lidOffsets[i] - up * 1.2 * coffinAsh
			lp.Transparency = coffinAsh
		end
		local gap = (cf * CFrame.new(0, 0.9, -2.6)).Position
		glowHolder.Position = gap
		local open = smooth((t - P.lid0) / 0.4) * (1 - smooth((t - P.ash) / 0.8))
		glowLight.Brightness = 4 * open
		seam.part.Transparency = 1 - 0.9 * open
		smoke.Rate = 30 * open

		-- the chains: wrapped round the coffin, then they snap and fly apart
		if t >= P.snap and not snapped then
			snapped = true
			for _, l in ipairs(links) do
				local outward = (l.part.Position - cf.Position)
				outward = Vector3.new(outward.X, 0, outward.Z).Unit
				l.vel = outward * rng:NextNumber(10, 22) + up * rng:NextNumber(8, 16)
			end
			burst(cf, Vector3.new(2.4, 1.3, 6), 40, { color = ColorSequence.new(RED, BLOOD), speed = NumberRange.new(6, 14), size = 0.6 })
			shake(0.4, 0.3)
		end
		for _, l in ipairs(links) do
			if l.vel then
				l.vel += Vector3.new(0, -50, 0) * dt
				l.part.CFrame = (l.part.CFrame + l.vel * dt) * CFrame.Angles(dt * 9, dt * 7, 0)
				l.part.Transparency = math.clamp((t - P.snap - 0.5) / 0.6, 0, 1)
			else
				l.part.CFrame = cf * l.offset
			end
		end

		-- the claw: rises out of the crack and swings far back and up to the side in one fluent arc (never stopping:
		-- it keeps drifting back while it trembles), rakes DIAGONALLY down through the wall very fast (top right to bottom
		-- left), and its momentum carries it on in a long decelerating curve before it fades
		local vis = 0
		local wrist, curl
		local rise = gap + up * 7 + right * 3
		local cocked = gap + up * 19 + right * 13 - laneDir * 9 -- far back, high, out to the right
		local contact = face + diagTop * 0.75 - laneDir * 1.5
		local through = face + diagBottom * 0.8 + laneDir * 1.2
		local diag = (through - contact).Unit
		local function hand(pos, fd)
			return CFrame.lookAt(pos, pos + fd.Unit, -laneDir + up * 0.1)
		end
		local cockedFd = up * 0.4 - laneDir * 0.7 + right * 0.6 -- the fingers point back, away from the wall
		local rakeFd = diag + laneDir * 0.7 -- into the wall, along the rake
		if t >= P.lid1 and t < P.wind1 then
			local u = (t - P.lid1) / (P.wind1 - P.lid1)
			local e = smooth(u)
			-- a curve gap -> rise -> cocked, then a slow drift further back (the coil keeps tightening)
			local a1 = math.min(e / 0.4, 1)
			local a2 = math.clamp((e - 0.25) / 0.75, 0, 1)
			local pos = gap:Lerp(rise, smooth(a1)):Lerp(rise:Lerp(cocked, smooth(a2)), smooth(a2))
			pos += (cocked - gap).Unit * 1.5 * math.max(0, u - 0.7) / 0.3 -- (still drifting back at the end)
			local shiver = u > 0.75 and math.sin(t * 50) * 0.25 * (u - 0.75) / 0.25 or 0
			wrist = hand(pos + right * shiver, (up:Lerp(cockedFd, e)))
			curl = 0.35 - 0.33 * e -- opens wide while it rises
			vis = smooth((t - P.lid1) / 0.25)
			clawSmoke.Rate = 25
		elseif t >= P.wind1 and t < P.strike1 then
			local u = (t - P.wind1) / (P.strike1 - P.wind1)
			local s = u ^ 1.6 -- accelerating into the wall: strong, not eased to a stop
			local pos = cocked:Lerp(contact, s):Lerp(contact:Lerp(through, s), s)
			wrist = hand(pos, cockedFd:Lerp(rakeFd, math.min(1, s * 1.3)))
			curl = 0.02 + 0.85 * s -- the rake: the fingers close as they tear through
			vis = 1
			clawSmoke.Rate = 160
			if not struck then
				struck = true
				for _, f in ipairs(claw.segs) do
					f.trail.Enabled = true
				end
			end
		elseif t >= P.strike1 and t < P.follow1 then
			local f = (t - P.strike1) / (P.follow1 - P.strike1)
			local e = 1 - (1 - f) ^ 3 -- the momentum lingers: fast at first, a long slow drift
			-- carries on along the rake, curving away from the wall and down
			local pos = through + diag * 11 * e - laneDir * 4 * e * e - up * 2 * e
			wrist = hand(pos, rakeFd:Lerp(diag - laneDir * 0.3, e))
			curl = 0.87 - 0.2 * e
			vis = 1 - smooth((f - 0.35) / 0.65)
			clawSmoke.Rate = 90 * (1 - f)
		else
			clawSmoke.Rate = 0
		end
		if wrist then
			placeClaw(wrist, curl, vis)
			-- the forearm reaching back into the coffin
			local armLen = (wrist.Position - gap).Magnitude
			local armCf = CFrame.lookAt((wrist.Position + gap) / 2, wrist.Position)
			claw.arm.core.Size = Vector3.new(1.7 * S, 1.7 * S, armLen)
			claw.arm.glow.Size = Vector3.new(2.1 * S, 2.1 * S, armLen)
			claw.arm.core.CFrame = armCf
			claw.arm.glow.CFrame = armCf
			claw.arm.core.Transparency = 1 - vis * 0.95
			claw.arm.glow.Transparency = 1 - vis * 0.28
		else
			for _, p in ipairs(claw.all) do
				p.Transparency = 1
			end
			for _, f in ipairs(claw.segs) do
				f.trail.Enabled = false
			end
		end
		if t >= P.hit and t - dt < P.hit then
			-- the blow lands: debris, red sparks, a hard shake
			dustAt(aim, 40, 6, 22)
			voidLight.Brightness = 5
			burst(CFrame.lookAt(aim, aim - laneDir), Vector3.new(10, 12, 1), 90, {
				direction = Enum.NormalId.Front, spread = Vector2.new(60, 60), speed = NumberRange.new(16, 34), drag = 2.5,
				lifetime = NumberRange.new(0.4, 0.8), size = 0.9, color = ColorSequence.new(RED, BLOOD),
			})
			local camera = workspace.CurrentCamera
			if camera and (camera.CFrame.Position - aim).Magnitude < 120 then
				shake(1.1, 0.5)
			end
		end

		-- the tear: drawn along the rake as the talons pass; a void portal that jitters, crackles with red lightning and
		-- draws a dark haze in; then it implodes into itself
		local reveal = math.clamp((t - P.wind1 - 0.03) / (P.strike1 - P.wind1), 0, 1)
		local implode = smooth((t - P.implode0) / (P.implode1 - P.implode0))
		local open = (t >= P.strike1 and implode < 1) and 1 or 0
		for _, slash in ipairs(tears) do
			local r = math.clamp(reveal - slash.delay * 4, 0, 1)
			for _, seg in ipairs(slash.segs) do
				local shown = seg.frac <= r + 0.001
				if not shown or implode >= 1 then
					seg.rim.Transparency = 1
					seg.core.Transparency = 1
				else
					local jitter = (right * math.sin(t * 53 + seg.seed) + up * math.cos(t * 47 + seg.seed * 2)) * 0.12 * (1 - implode)
					local pulse = 1 + 0.12 * math.sin(t * 9 + seg.seed) -- (it breathes)
					local scale = (1 - implode) * pulse
					seg.rim.CFrame = seg.rimCf:Lerp(CFrame.new(tearCentre) * seg.rimCf.Rotation, implode) + jitter
					seg.core.CFrame = seg.coreCf:Lerp(CFrame.new(tearCentre) * seg.coreCf.Rotation, implode) + jitter
					seg.rim.Size = seg.rimSize * Vector3.new(scale, 1, math.max(0.05, 1 - implode))
					seg.core.Size = seg.coreSize * Vector3.new(scale, 1, math.max(0.05, 1 - implode))
					seg.rim.Transparency = 0.05 + math.max(0, 0.25 * math.sin(t * 31 + seg.seed))
					seg.core.Transparency = 0
				end
			end
		end
		haze.Rate = 40 * open
		voidLight.Brightness = open * (1.8 + math.sin(t * 13) * 0.6)
		for _, bolt in ipairs(bolts) do
			if open > 0 and t > P.strike1 + 0.05 then
				if os.clock() >= bolt.nextAt then
					strikeBolt(bolt)
				end
				local lit = os.clock() < (bolt.litUntil or 0)
				for _, seg in ipairs(bolt.segs) do
					seg.Transparency = lit and 0 or 1
				end
			else
				for _, seg in ipairs(bolt.segs) do
					seg.Transparency = 1
				end
			end
		end
		if open > 0 and math.random() < 0.25 then
			-- red crackle along the tears
			local slash = tears[math.random(#tears)]
			local seg = slash.segs[math.random(#slash.segs)]
			burst(seg.rimCf, Vector3.one * 0.6, 4, { color = ColorSequence.new(RED, BLOOD), speed = NumberRange.new(3, 8), size = 0.4, lifetime = NumberRange.new(0.2, 0.4) })
		end
		if implode >= 1 and not imploded then
			imploded = true
			local flash = part(folder, "ImplodeFlash", Vector3.one, CFrame.new(tearCentre), RED, 0, Enum.PartType.Ball)
			local flashStart = os.clock()
			effect(function()
				local f = (os.clock() - flashStart) / 0.3
				if f >= 1 then
					flash:Destroy()
					return false
				end
				flash.Size = Vector3.one * (8 * (1 - f) + 0.5)
				flash.Color = RED:Lerp(VOIDBLACK, f)
				flash.Transparency = f
				return true
			end, folder)
			burst(CFrame.new(tearCentre), Vector3.one * 2, 50, {
				shape = Enum.ParticleEmitterShape.Sphere, color = ColorSequence.new(RED, VOIDBLACK),
				speed = NumberRange.new(10, 24), drag = 3, size = 1, lifetime = NumberRange.new(0.3, 0.6),
			})
			local camera = workspace.CurrentCamera
			if camera and (camera.CFrame.Position - aim).Magnitude < 100 then
				shake(0.5, 0.3)
			end
		end
		return true
	end, folder)
end

-- ============================================================
-- The charge: a glowing orb gathers between the hands while they rest at the hip (1.3 s after a throw until the next)
-- ============================================================
local charges = {} -- [model] = { orb, light, lastAttack }

local function chargeOf(model)
	local c = charges[model]
	if not c then
		local orb = part(fx, "Charge", Vector3.one * 0.3, CFrame.new(), PALE, 1, Enum.PartType.Ball)
		local light = Instance.new("PointLight")
		light.Color = TEAL
		light.Range = 8
		light.Brightness = 0
		light.Shadows = false
		light.Parent = orb
		c = { orb = orb, light = light, inflow = {} }
		for i = 1, 10 do
			c.inflow[i] = { part = part(fx, "Inflow", Vector3.new(0.08, 0.08, 1), CFrame.new(), (i % 2 == 0) and TEAL or PALE, 1),
				dir = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5).Unit, phase = math.random() }
		end
		charges[model] = c
	end
	return c
end

local function updateCharges()
	local camera = workspace.CurrentCamera
	for model, c in pairs(charges) do
		if not model.Parent then
			c.orb:Destroy()
			for _, f in ipairs(c.inflow) do
				f.part:Destroy()
			end
			charges[model] = nil
		else
			local rHand, lHand = model:FindFirstChild("RHand", true), model:FindFirstChild("LHand", true)
			local a = c.lastAttack and (os.clock() - c.lastAttack) or math.huge
			local grow = math.clamp((a - 1.3) / 0.5, 0, 1) * (a < 2.6 and 1 or 0)
			-- (it is spent in the thrust: the next attack resets lastAttack, and the orb collapses at once)
			if rHand and lHand and grow > 0 and camera and (rHand.Position - camera.CFrame.Position).Magnitude < MAX_DISTANCE then
				local flicker = 1 + math.sin(os.clock() * 30) * 0.08
				c.orb.Position = (rHand.Position + lHand.Position) / 2
				c.orb.Size = Vector3.one * (0.3 + 1.1 * grow) * flicker
				c.orb.Transparency = 0.55 - 0.35 * grow
				c.light.Brightness = 1.5 * grow
				-- streaks of energy sucked in from all around, faster as it fills
				for _, f in ipairs(c.inflow) do
					local u = (os.clock() * (1.2 + grow * 1.6) + f.phase) % 1
					local from = c.orb.Position + f.dir * (6 - 5.5 * u)
					local len = 1.5 + 1.5 * (1 - u)
					f.part.Size = Vector3.new(0.08, 0.08, len)
					f.part.CFrame = CFrame.lookAt(from + f.dir * len / 2, c.orb.Position)
					f.part.Transparency = 0.2 + 0.8 * (1 - grow) + (u > 0.85 and (u - 0.85) * 5 or 0)
				end
			else
				c.orb.Transparency = 1
				c.light.Brightness = 0
				for _, f in ipairs(c.inflow) do
					f.part.Transparency = 1
				end
			end
		end
	end
end

-- ============================================================
-- Watching Knells
-- ============================================================
local function watch(model)
	if watched[model] or model.Name ~= "Knell" then
		return
	end
	watched[model] = {
		model:GetAttributeChangedSignal("AttackCount"):Connect(function()
			chargeOf(model).lastAttack = os.clock()
			basicToll(model)
		end),
		model:GetAttributeChangedSignal("SpecialAt"):Connect(function()
			procession(model)
		end),
	}
end
for _, model in ipairs(CollectionService:GetTagged(TAG)) do
	watch(model)
end
CollectionService:GetInstanceAddedSignal(TAG):Connect(watch)
CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(model)
	local connections = watched[model]
	if connections then
		for _, connection in ipairs(connections) do
			connection:Disconnect()
		end
	end
	watched[model] = nil
end)

RunService.RenderStepped:Connect(function()
	updateCharges()
	local now = workspace:GetServerTimeNow()
	for i = #active, 1, -1 do
		if not active[i](now) then
			table.remove(active, i)
		end
	end
end)

-- the camera shake of the last toll (nearby players), after the camera scripts have placed the camera
RunService:BindToRenderStep("KnellShake", Enum.RenderPriority.Camera.Value + 1, function()
	local now = os.clock()
	if now < shakeUntil then
		local cam = workspace.CurrentCamera
		local a = shakePower * (shakeUntil - now)
		cam.CFrame = cam.CFrame * CFrame.new((math.random() - 0.5) * a, (math.random() - 0.5) * a, 0)
	else
		shakePower = 0
	end
end)

return {}
