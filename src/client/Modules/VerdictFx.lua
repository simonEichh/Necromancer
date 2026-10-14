-- The Sigilwright's special, THE VERDICT (Units.Sigilwright.special, kind "Verdict", 13 s; the server pauses its
-- barrage meanwhile and deals the hits at the bolt times). Everything here is client-side drawing from SpecialAt /
-- SpecialAim; UnitAnimator moves the body (rising, writing, a jerk of the hand on every word).
--   0.0-1.5   its palm circle grows to twice its size and spins; it rises and lifts its hand
--   1.5-7.0   five rune circles snap open in an arc over the wall, one per word; inside each a rune is written stroke
--             by stroke in gold (a spark at the pen tip); the palm circle spins faster with every word
--   7.0-9.05  one star after another tears loose from its orbit and flies into a circle's centre (a lock pulse); then
--             all five circles turn to face the wall
--   8.9-11.6  the hood opens into a mouth of light; word by word the rune BURSTS INTO FIRE and fires a hypersonic bolt
--             of judgement at the wall (it breaks the sound barrier: rings of compressed air flash along its path, a
--             boom ring at the circle), faster and faster; the fifth word is the big one (the whole sentence flares,
--             a thicker bolt, a bigger impact, a camera shake)
--   11.7-13   the burning runes crumble to embers, the circles shatter word by word, the stars fly home
-- Bolt times (the server's hits are 0.06 s later): 9.3, 9.9, 10.35, 10.7, 11.3.
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local SpellEffects = require(script.Parent.SpellEffects)

local GOLD = Color3.fromRGB(255, 200, 90)
local WHITE_GOLD = Color3.fromRGB(255, 240, 200)
local FIRE = Color3.fromRGB(255, 120, 30)
local EMBER = Color3.fromRGB(255, 80, 20)
local FIRE_TEXTURE = "rbxasset://textures/particles/fire_main.dds"
local SPARK_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"

local T = { word0 = 1.5, wordStep = 1.1, writeTime = 1.0, slot0 = 7.0, slotStep = 0.35, slotFly = 0.5, turn0 = 8.75,
	turn1 = 9.05, mouth0 = 8.9, mouth1 = 11.6, igniteLead = 0.35, flare = 10.95, echo0 = 11.7, total = 13.0 }
local BOLTS = { 9.3, 9.9, 10.35, 10.7, 11.3 }
local FLIGHT = 0.06 -- hypersonic
local CIRCLE_D = 20 -- (the user wanted the sentence much bigger and higher)
local RS = CIRCLE_D / 7.5 -- (rune strokes, flames and pulses scale with the circles)
local MAX_DISTANCE = 320

-- the five words: strokes { x0, y0, x1, y1 } inside the circle (radius 1)
local WORDS = {
	{ { 0, -0.7, 0, 0.7 }, { -0.45, 0.35, 0.45, 0.35 }, { -0.45, -0.2, 0, -0.55 }, { 0.45, -0.2, 0, -0.55 } },
	{ { -0.5, -0.6, -0.5, 0.6 }, { -0.5, 0.6, 0.5, 0 }, { 0.5, 0, -0.5, -0.6 }, { 0.15, 0.25, 0.55, 0.6 } },
	{ { -0.6, 0.55, 0.6, 0.55 }, { 0, 0.55, 0, -0.65 }, { -0.5, -0.1, 0.5, -0.1 }, { -0.35, -0.65, 0.35, -0.65 } },
	{ { 0, 0.7, 0.6, -0.5 }, { 0.6, -0.5, -0.6, -0.5 }, { -0.6, -0.5, 0, 0.7 }, { 0, 0.15, 0, -0.2 } },
	{ { -0.6, 0.6, 0.6, -0.6 }, { 0.6, 0.6, -0.6, -0.6 }, { 0, 0.75, 0, -0.75 }, { -0.75, 0, 0.75, 0 }, { -0.3, 0.3, 0.3, 0.3 } },
}

local up = Vector3.yAxis
local fx = Instance.new("Folder")
fx.Name = "VerdictFx"
fx.Parent = Workspace

local function smooth(x)
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

local function part(parent, name, size, cf, color, transparency, shape)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Transparency = transparency or 0
	p.Material = Enum.Material.Neon
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	if shape then
		p.Shape = shape
	end
	p.Parent = parent
	return p
end

local function emitBurst(cf, size, count, props)
	local holder = part(fx, "Burst", size, cf, GOLD, 1)
	local e = Instance.new("ParticleEmitter")
	e.Texture = props.texture or SPARK_TEXTURE
	e.Color = props.color or ColorSequence.new(WHITE_GOLD, GOLD)
	e.LightEmission = props.lightEmission or 1
	e.LightInfluence = 0
	e.Size = props.sizeSeq or NumberSequence.new({ NumberSequenceKeypoint.new(0, props.size or 0.8), NumberSequenceKeypoint.new(1, 0) })
	e.Transparency = props.transparency or NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
	e.Lifetime = props.lifetime or NumberRange.new(0.4, 0.8)
	e.Speed = props.speed or NumberRange.new(8, 20)
	e.SpreadAngle = props.spread or Vector2.new(180, 180)
	e.Acceleration = props.acceleration or Vector3.zero
	e.Drag = props.drag or 2
	e.Rotation = NumberRange.new(0, 360)
	e.EmissionDirection = props.direction or Enum.NormalId.Top
	e.Rate = 0
	e.Parent = holder
	e:Emit(count)
	Debris:AddItem(holder, (props.lifetime and props.lifetime.Max or 0.8) + 0.3)
end

-- a hollow ring of segments; draw(frame, radius, transparency) lays it in frame's XY plane
local function ringOf(parent, color, count, width)
	local segs = {}
	for i = 1, count do
		segs[i] = part(parent, "Ring", Vector3.one, CFrame.new(), color, 1)
	end
	return function(frame, radius, alpha)
		for i, p in ipairs(segs) do
			local a = i * 2 * math.pi / count
			p.Size = Vector3.new(math.max(0.05, 2 * radius * math.sin(math.pi / count)), width, width)
			p.CFrame = frame * CFrame.new(math.sin(a) * radius, math.cos(a) * radius, 0) * CFrame.Angles(0, 0, -a)
			p.Transparency = alpha
		end
	end, segs
end

-- the camera shake of the last bolt (nearby players)
local shakeUntil, shakePower = 0, 0
local function shake(power, length)
	shakeUntil = os.clock() + length
	shakePower = math.max(shakePower, power)
end
RunService:BindToRenderStep("VerdictShake", Enum.RenderPriority.Camera.Value + 1, function()
	local now = os.clock()
	if now < shakeUntil then
		local cam = Workspace.CurrentCamera
		local a = shakePower * (shakeUntil - now)
		cam.CFrame = cam.CFrame * CFrame.new((math.random() - 0.5) * a, (math.random() - 0.5) * a, 0)
	else
		shakePower = 0
	end
end)

local active = {}

-- ============================================================
-- A hypersonic bolt: a white core shot from the circle to the wall in FLIGHT seconds, rings of compressed air
-- flashing along its path as it passes, a boom ring at the circle, a burning trail that lingers; the impact
-- ============================================================
local function fireBolt(from, to, big, folder)
	local dir = (to - from)
	local dist = dir.Magnitude
	if dist < 1 then
		return
	end
	dir = dir.Unit
	local thick = big and 1.0 or 0.5
	local core = part(folder, "BoltCore", Vector3.new(thick, thick, 0.1), CFrame.new(from), WHITE_GOLD, 0)
	local glow = part(folder, "BoltGlow", Vector3.new(thick * 2.6, thick * 2.6, 0.1), CFrame.new(from), GOLD, 0.55)
	-- the boom at the muzzle: a ring blown out of the circle
	local boomDraw = ringOf(folder, WHITE_GOLD, 18, big and 0.35 or 0.22)
	-- the rings of the sound barrier along the path (one every 7 studs, lit as the bolt passes)
	local rings = {}
	local spacing = 7
	for d = spacing, dist - 2, spacing do
		local draw = ringOf(folder, (#rings % 2 == 0) and WHITE_GOLD or GOLD, 12, 0.14)
		table.insert(rings, { draw = draw, d = d })
	end
	local frameAlong = function(d)
		return CFrame.lookAt(from + dir * d, from + dir * (d + 1))
	end
	local t0 = os.clock()
	local impacted = false
	table.insert(active, function()
		local a = os.clock() - t0
		if a > 1.2 then
			return false
		end
		local head = math.min(1, a / FLIGHT) * dist
		-- the core: from the circle to its head while flying, then a burning trail that thins and fades
		local fade = math.clamp((a - FLIGHT) / 0.7, 0, 1)
		local w = thick * (1 - fade * 0.8)
		core.Size = Vector3.new(w, w, math.max(0.1, head))
		core.CFrame = CFrame.lookAt(from + dir * head / 2, from + dir * head)
		core.Color = WHITE_GOLD:Lerp(FIRE, fade)
		core.Transparency = fade
		glow.Size = Vector3.new(w * 2.6, w * 2.6, math.max(0.1, head))
		glow.CFrame = core.CFrame
		glow.Color = GOLD:Lerp(EMBER, fade)
		glow.Transparency = 0.55 + 0.45 * fade
		-- the boom ring at the muzzle
		local b = math.clamp(a / 0.35, 0, 1)
		boomDraw(frameAlong(1), (big and 2 or 1.2) + (big and 7 or 4.5) * b, b)
		-- the sound-barrier rings: each flashes as the head passes and spreads out
		for _, r in ipairs(rings) do
			local since = a - (r.d / dist) * FLIGHT
			if since < 0 then
				r.draw(frameAlong(r.d), 0.1, 1)
			else
				local k = math.clamp(since / 0.35, 0, 1)
				r.draw(frameAlong(r.d), (big and 1.4 or 0.9) + (big and 3.6 or 2.4) * k, 0.1 + 0.9 * k)
			end
		end
		if a >= FLIGHT and not impacted then
			impacted = true
			-- the impact: a flash, a gold shell, a shock ring on the wall, sparks, fire and dust
			local flash = part(folder, "Flash", Vector3.one, CFrame.new(to), Color3.new(1, 1, 1), 0, Enum.PartType.Ball)
			local shell = part(folder, "Shell", Vector3.one, CFrame.new(to), GOLD, 0.35, Enum.PartType.Ball)
			local shockDraw = ringOf(folder, WHITE_GOLD, 20, big and 0.45 or 0.25)
			local i0 = os.clock()
			table.insert(active, function()
				local k = (os.clock() - i0) / (big and 0.45 or 0.3)
				if k >= 1 then
					flash:Destroy()
					shell:Destroy()
					shockDraw(CFrame.new(to), 0.1, 1)
					return false
				end
				flash.Size = Vector3.one * (big and (4 + 12 * k) or (2 + 6 * k))
				flash.Transparency = k
				shell.Size = Vector3.one * (big and (3 + 18 * k) or (1.5 + 9 * k))
				shell.Transparency = 0.35 + 0.65 * k
				shockDraw(CFrame.lookAt(to - dir * 0.3, to - dir * 2), (big and 2 or 1) + (big and 14 or 7) * k, k)
				return true
			end)
			emitBurst(CFrame.lookAt(to, to - dir), Vector3.one, big and 70 or 30, {
				direction = Enum.NormalId.Front, spread = Vector2.new(70, 70), speed = NumberRange.new(14, big and 40 or 28),
				size = big and 1.1 or 0.7,
			})
			emitBurst(CFrame.new(to), Vector3.one * 2, big and 40 or 16, {
				texture = FIRE_TEXTURE, color = ColorSequence.new(Color3.fromRGB(255, 220, 140), FIRE), spread = Vector2.new(180, 180),
				speed = NumberRange.new(4, 12), lifetime = NumberRange.new(0.4, big and 1.1 or 0.7), acceleration = Vector3.new(0, 8, 0),
				sizeSeq = NumberSequence.new({ NumberSequenceKeypoint.new(0, big and 3 or 2), NumberSequenceKeypoint.new(1, 0.5) }),
			})
			emitBurst(CFrame.new(to), Vector3.one * 2, big and 30 or 12, {
				texture = SMOKE_TEXTURE, color = ColorSequence.new(Color3.fromRGB(120, 108, 96)), lightEmission = 0,
				speed = NumberRange.new(2, 8), lifetime = NumberRange.new(0.8, 1.4),
				sizeSeq = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, big and 8 or 5) }),
				transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1) }),
			})
			local camera = Workspace.CurrentCamera
			if camera and (camera.CFrame.Position - to).Magnitude < (big and 130 or 80) then
				shake(big and 1.2 or 0.35, big and 0.5 or 0.2)
			end
		end
		return true
	end)
end

-- ============================================================
-- The Verdict
-- ============================================================
local function verdict(model)
	local at = model:GetAttribute("SpecialAt")
	local aim = model:GetAttribute("SpecialAim")
	local root = model.PrimaryPart
	local camera = Workspace.CurrentCamera
	if not (at and aim and root and camera) then
		return
	end
	if (aim - camera.CFrame.Position).Magnitude > MAX_DISTANCE and (root.Position - camera.CFrame.Position).Magnitude > MAX_DISTANCE then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "Verdict"
	folder.Parent = fx
	local flat = Vector3.new(aim.X - root.Position.X, 0, aim.Z - root.Position.Z)
	local laneDir = flat.Magnitude > 1 and flat.Unit or Vector3.new(0, 0, -1)
	local right = laneDir:Cross(up).Unit
	local scale = model:GetScale()
	local rng = Random.new(model:GetAttribute("SpecialSeed") or 1)

	-- the sentence: five circles in an arc over the wall, facing the unit
	local centre = aim - laneDir * 48 + up * 42 -- (well in front of the wall, towards the Sigilwright)
	local words = {}
	for k = 1, 5 do
		local pos = centre + right * ((k - 3) * 24) - up * (math.abs(k - 3) * 6)
		local circle = SpellEffects.newSigilCircle(GOLD, CIRCLE_D, 1)
		circle.part.Parent = folder
		local impact = aim + right * ((k - 3) * 3.2) + up * rng:NextNumber(-2.5, 2.5)
		if k == 5 then
			impact = aim
		end
		local strokes = {}
		local total = 0
		for _, st in ipairs(WORDS[k]) do
			local a = Vector2.new(st[1], st[2])
			local b = Vector2.new(st[3], st[4])
			local len = (b - a).Magnitude
			table.insert(strokes, { a = a, b = b, len = len, from = total, part = part(folder, "Rune", Vector3.new(0.24 * RS, 0.24 * RS, 1), CFrame.new(), GOLD, 1) })
			total += len
		end
		-- flames and smoke on the circle (rate 0 until the word ignites)
		local fire = Instance.new("ParticleEmitter")
		fire.Texture = FIRE_TEXTURE
		fire.Color = ColorSequence.new(Color3.fromRGB(255, 230, 160), FIRE)
		fire.LightEmission = 1
		fire.LightInfluence = 0
		fire.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2.2 * RS), NumberSequenceKeypoint.new(1, 0.4 * RS) })
		fire.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
		fire.Lifetime = NumberRange.new(0.5, 0.9)
		fire.Speed = NumberRange.new(1, 3)
		fire.Acceleration = Vector3.new(0, 7, 0)
		fire.SpreadAngle = Vector2.new(180, 180)
		fire.Rate = 0
		fire.Parent = circle.part
		local smoke = Instance.new("ParticleEmitter")
		smoke.Texture = SMOKE_TEXTURE
		smoke.Color = ColorSequence.new(Color3.fromRGB(70, 60, 56))
		smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2 * RS), NumberSequenceKeypoint.new(1, 6 * RS) })
		smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1) })
		smoke.Lifetime = NumberRange.new(1, 1.6)
		smoke.Speed = NumberRange.new(1, 3)
		smoke.Acceleration = Vector3.new(0, 4, 0)
		smoke.Rate = 0
		smoke.Parent = circle.part
		local pen = part(folder, "Pen", Vector3.one * 0.45 * RS, CFrame.new(pos), Color3.new(1, 1, 1), 1, Enum.PartType.Ball)
		local lock = part(folder, "Lock", Vector3.one, CFrame.new(pos), WHITE_GOLD, 1, Enum.PartType.Ball)
		table.insert(words, {
			k = k, pos = pos, circle = circle, strokes = strokes, total = total, impact = impact, fire = fire, smoke = smoke,
			pen = pen, lock = lock, writeAt = T.word0 + (k - 1) * T.wordStep, boltAt = BOLTS[k], spin = 0,
		})
	end

	-- the palm circle (twice the basic attack's) above the lifted hand, lying flat
	local palmPart = model:FindFirstChild(model:GetAttribute("CastPart") or "SigilPoint", true)
	local palm = SpellEffects.newSigilCircle(GOLD, 13 * scale, scale)
	palm.part.Parent = folder
	local palmSpin = 0

	-- the stars: the model's orbit stars are hidden one by one and fly to the circles as clones
	local orbitStars = {}
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and d.Name:match("^OrbitStar") then
			table.insert(orbitStars, d)
		end
	end
	local flyers = {}
	for k = 1, 5 do
		flyers[k] = { part = part(folder, "Star", Vector3.one * 0.6 * RS, CFrame.new(), WHITE_GOLD, 1, Enum.PartType.Ball), src = orbitStars[k] }
	end

	-- the mouth of light in the hood
	local face = model:FindFirstChild("FaceGlow", true)
	local mouth = part(folder, "Mouth", Vector3.new(0.4, 0.1, 0.06), CFrame.new(), WHITE_GOLD, 1)

	local fired, ignited = {}, {}
	local lastT = 0
	table.insert(active, function(now)
		local t = now - at
		if t > T.total or not model.Parent then
			for _, s in ipairs(orbitStars) do
				if s.Parent then
					s.LocalTransparencyModifier = 0
				end
			end
			folder:Destroy()
			return false
		end
		if t < 0 then
			return true
		end
		local dt = math.clamp(t - lastT, 0, 0.1)
		lastT = t

		-- the palm circle: grows in the opening, spins faster with every finished word, shrinks away in the echo
		local wordsDone = math.clamp(math.floor((t - T.word0) / T.wordStep), 0, 5)
		palmSpin += dt * (1 + wordsDone * 0.9 + (t > T.mouth0 and 3 or 0))
		local palmVis = smooth(t / 0.6) * (1 - smooth((t - T.echo0) / 0.8))
		if palmPart and palmPart.Parent then
			local d = 13 * scale * (0.4 + 0.6 * smooth(t / 1.2))
			palm.part.Size = Vector3.new(d, d, 0.2)
			local c = palmPart.Position + up * 1.1 * scale
			palm.part.CFrame = CFrame.lookAt(c, c + up, laneDir)
			SpellEffects.updateSigilCircle(palm, palmVis, palmSpin)
		end

		-- the mouth: opens with the verdict
		local mouthOpen = smooth((t - T.mouth0) / 0.3) * (1 - smooth((t - T.mouth1) / 0.4))
		if face and face.Parent and mouthOpen > 0 then
			local flicker = 1 + math.sin(t * 40) * 0.08
			mouth.Size = Vector3.new(0.45 * scale, (0.08 + 0.5 * mouthOpen) * scale * flicker, 0.06)
			mouth.CFrame = face.CFrame * CFrame.new(0, -0.18 * scale, -0.05)
			mouth.Transparency = 1 - mouthOpen
		else
			mouth.Transparency = 1
		end

		for _, w in ipairs(words) do
			local k = w.k
			-- the circle: snaps open when its word starts, turns to face the wall before the verdict
			local open = smooth((t - w.writeAt + 0.15) / 0.3)
			local shatter = (t - T.echo0 - (k - 1) * 0.12)
			local vis = open * (shatter > 0 and 0 or 1)
			if shatter > 0 and not w.shattered then
				w.shattered = true
				emitBurst(CFrame.new(w.pos), Vector3.one * CIRCLE_D * 0.6, 26, {
					color = ColorSequence.new(WHITE_GOLD, GOLD), speed = NumberRange.new(6, 14), acceleration = Vector3.new(0, -14, 0),
					lifetime = NumberRange.new(0.6, 1.1), size = 0.7,
				})
			end
			local turn = smooth((t - T.turn0) / (T.turn1 - T.turn0))
			local facing = (-laneDir):Lerp((w.impact - w.pos).Unit, turn)
			local cf = CFrame.lookAt(w.pos, w.pos + facing) * CFrame.new(0, math.sin(t * 1.4 + k) * 0.3, 0)
			local d = CIRCLE_D * (0.3 + 0.7 * open)
			w.circle.part.Size = Vector3.new(d, d, 0.2)
			w.circle.part.CFrame = cf
			w.spin += dt * (1 + (t > w.boltAt - T.igniteLead and 4 or 0))
			SpellEffects.updateSigilCircle(w.circle, vis, w.spin + k)

			-- the rune: written stroke by stroke, the pen spark at the tip
			local written = math.clamp((t - w.writeAt) / T.writeTime, 0, 1) * w.total
			local igniteAt = w.boltAt - T.igniteLead
			local burning = t >= igniteAt and 1 or 0
			local flare = (t >= T.flare and t < T.flare + 0.4) and 1 or 0
			local crumble = math.clamp((t - T.echo0 - (k - 1) * 0.12) / 0.5, 0, 1)
			local R = CIRCLE_D * 0.36
			local tip
			for _, st in ipairs(w.strokes) do
				local shown = math.clamp((written - st.from) / st.len, 0, 1)
				if shown <= 0 or crumble >= 1 then
					st.part.Transparency = 1
				else
					local a = cf * Vector3.new(st.a.X * R, st.a.Y * R, -0.2)
					local b = cf * Vector3.new(st.b.X * R, st.b.Y * R, -0.2)
					local e = a:Lerp(b, shown)
					st.part.Size = Vector3.new((0.24 + 0.12 * burning) * RS, (0.24 + 0.12 * burning) * RS, (e - a).Magnitude + 0.2 * RS)
					st.part.CFrame = CFrame.lookAt((a + e) / 2, e)
					local fireFlicker = 0.5 + 0.5 * math.sin(t * 30 + st.from * 7)
					st.part.Color = burning > 0 and FIRE:Lerp(WHITE_GOLD, fireFlicker * 0.6 + flare * 0.4) or GOLD
					st.part.Transparency = crumble
					if shown < 1 then
						tip = e
					end
				end
			end
			if tip and t < w.writeAt + T.writeTime then
				w.pen.CFrame = CFrame.new(tip)
				w.pen.Transparency = 0
				if math.random() < 0.4 then
					emitBurst(CFrame.new(tip), Vector3.one * 0.2, 3, { speed = NumberRange.new(2, 6), size = 0.3, lifetime = NumberRange.new(0.2, 0.4) })
				end
			else
				w.pen.Transparency = 1
			end
			-- ignition: the rune bursts into fire (flames and smoke from the circle)
			if burning > 0 and not ignited[k] then
				ignited[k] = true
				emitBurst(cf, Vector3.new(CIRCLE_D * 0.6, CIRCLE_D * 0.6, 0.4), 30, {
					texture = FIRE_TEXTURE, color = ColorSequence.new(Color3.fromRGB(255, 230, 160), FIRE), speed = NumberRange.new(4, 10),
					acceleration = Vector3.new(0, 10, 0), lifetime = NumberRange.new(0.4, 0.8),
					sizeSeq = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2.5), NumberSequenceKeypoint.new(1, 0.5) }),
				})
			end
			w.fire.Rate = (burning > 0 and crumble < 1) and (30 + flare * 60) or 0
			w.smoke.Rate = (burning > 0 and crumble < 1) and 6 or 0
			if crumble > 0 and not w.crumbled then
				w.crumbled = true
				-- the burning rune crumbles to embers that drift down
				emitBurst(cf, Vector3.new(CIRCLE_D * 0.6, CIRCLE_D * 0.6, 0.3), 40, {
					color = ColorSequence.new(FIRE, EMBER), speed = NumberRange.new(1, 4), acceleration = Vector3.new(0, -5, 0),
					lifetime = NumberRange.new(1, 1.8), size = 0.35, drag = 1,
				})
			end
			-- the bolt of judgement
			if t >= w.boltAt and not fired[k] then
				fired[k] = true
				fireBolt(w.pos + facing * 0.5, w.impact, k == 5, folder)
			end

			-- the star: tears loose from the orbit and flies into the circle's centre
			local fl = flyers[k]
			local slotAt = T.slot0 + (k - 1) * T.slotStep
			local f = (t - slotAt) / T.slotFly
			local home = (fl.src and fl.src.Parent) and fl.src.Position or (root.Position + up * 5 * scale)
			if f >= 0 and f < 1 then
				if fl.src then
					fl.src.LocalTransparencyModifier = 1
				end
				local e = f * f * (3 - 2 * f)
				local ctrl = (home + w.pos) / 2 + up * 14
				fl.part.CFrame = CFrame.new(home:Lerp(ctrl, e):Lerp(ctrl:Lerp(w.pos, e), e))
				fl.part.Transparency = 0
			elseif f >= 1 and t < T.echo0 + 0.5 then
				fl.part.Transparency = 1
				if not w.locked then
					w.locked = true
					w.lockAt = t
				end
			elseif t >= T.echo0 + 0.5 then
				-- flies home after the echo
				local g = math.clamp((t - T.echo0 - 0.5 - (k - 1) * 0.08) / 0.6, 0, 1)
				if g < 1 then
					local e = g * g * (3 - 2 * g)
					local ctrl = (home + w.pos) / 2 + up * 14
					fl.part.CFrame = CFrame.new(w.pos:Lerp(ctrl, e):Lerp(ctrl:Lerp(home, e), e))
					fl.part.Transparency = 0
				else
					fl.part.Transparency = 1
					if fl.src and fl.src.Parent then
						fl.src.LocalTransparencyModifier = 0
					end
				end
			end
			-- the lock pulse when the star sits; the star then glows in the centre until the bolt
			if w.lockAt then
				local p = (t - w.lockAt) / 0.4
				if p < 1 then
					w.lock.Size = Vector3.one * (1 + 5 * p) * RS
					w.lock.Transparency = p
				elseif t < w.boltAt then
					w.lock.Size = Vector3.one * (0.9 + math.sin(t * 8 + k) * 0.15) * RS
					w.lock.Transparency = 0.1
				else
					w.lock.Transparency = 1
				end
				w.lock.CFrame = CFrame.new(w.pos)
			end
		end
		return true
	end)
end

-- ============================================================
-- Watching the Sigilwrights
-- ============================================================
local watched = {}
local function watch(model)
	if watched[model] or model:GetAttribute("AttackStyle") ~= "SigilCast" then
		return
	end
	watched[model] = model:GetAttributeChangedSignal("SpecialAt"):Connect(function()
		if model:GetAttribute("SpecialKind") == "Verdict" then
			verdict(model)
		end
	end)
end
for _, m in ipairs(CollectionService:GetTagged("ProceduralUnit")) do
	watch(m)
end
CollectionService:GetInstanceAddedSignal("ProceduralUnit"):Connect(watch)
CollectionService:GetInstanceRemovedSignal("ProceduralUnit"):Connect(function(m)
	if watched[m] then
		watched[m]:Disconnect()
		watched[m] = nil
	end
end)

RunService.RenderStepped:Connect(function()
	local now = Workspace:GetServerTimeNow()
	for i = #active, 1, -1 do
		local ok, keep = pcall(active[i], now)
		if not ok then
			warn("VerdictFx: " .. tostring(keep))
			table.remove(active, i)
		elseif not keep then
			table.remove(active, i)
		end
	end
end)

return {}
