-- Opening a grave's real 3D model (ReplicatedStorage.GraveModels.<key>, built by tools/studio/build_grave_<tier>.lua):
-- the soul-light cracks glow towards the pull's rarity colour, then the grave bursts open.
--
--   GraveOpening.template(graveType)          the model template, or nil when the grave has no model yet
--   local g = GraveOpening.attach(model, opts) drives a grave model that is already placed (in a ViewportFrame or the world)
--     opts.scale   the model's scale (velocities and the light column scale with it), default 1
--     opts.world   true in the 3D world: the burst also lights up the surroundings and throws dust, sparks and souls
--     opts.alive   function() -> bool, the burst stops animating when it returns false (e.g. the reveal closed)
--   g.setGlow(color, amount)    amount 0..1: the soul-light cracks shift towards `color` (the buildup hint)
--   g.burst(color, t)           opens the grave (by its OpenStyle), the pit lights up, a light column rises; t = 0..1
--                               how rare the pull is (more debris, a bigger column, more light for rarer pulls)
--   g.stop()
--   local g = GraveOpening.create(parent, graveType, size, zIndex)  the grave in a ViewportFrame (the reveal overlay);
--     g.frame is the ViewportFrame, g.destroy() removes it
--
-- Model conventions (see build_grave_mossy.lua): front faces -Z, models "Body" / "Lid" / "Pit", part "Core", parts named
-- "Glow" are the soul-light cracks, attributes OpenStyle and GlowColor.
-- TODO (agreed with the user): higher grave tiers get more opening effects; add them here, driven by the tier.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local GraveOpening = {}

local GRAVITY = Vector3.new(0, -38, 0)
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"

function GraveOpening.template(graveType)
	local folder = ReplicatedStorage:FindFirstChild("GraveModels")
	return folder and graveType and folder:FindFirstChild(graveType) or nil
end

local function emitter(parent, texture, c0, c1, size0, size1, life, speed, spread, emission)
	local e = Instance.new("ParticleEmitter")
	e.Texture = texture
	e.Color = ColorSequence.new(c0, c1)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size0), NumberSequenceKeypoint.new(1, size1) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) })
	e.Lifetime = NumberRange.new(life * 0.6, life)
	e.Speed = NumberRange.new(speed * 0.4, speed)
	e.SpreadAngle = Vector2.new(spread, spread)
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-40, 40)
	e.LightEmission = emission
	e.Rate = 0
	e.Parent = parent
	return e
end

function GraveOpening.attach(model, opts)
	opts = opts or {}
	local S = opts.scale or 1
	local glowParts, glowBase = {}, {}
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and d.Name == "Glow" then
			table.insert(glowParts, d)
			glowBase[d] = d.Color
		end
	end
	local lid = model:FindFirstChild("Lid")
	local pit = model:FindFirstChild("Pit")
	local function corePos()
		local core = model:FindFirstChild("Core")
		return core and core.Position or model:GetPivot().Position
	end

	local g = { model = model, stopped = false }
	local function alive()
		return not g.stopped and model.Parent ~= nil and (not opts.alive or opts.alive())
	end

	function g.setGlow(color, amount)
		for _, p in ipairs(glowParts) do
			if p.Parent then
				p.Color = glowBase[p]:Lerp(color, math.clamp(amount, 0, 1))
			end
		end
	end

	-- one flying piece: velocity, spin, fade
	local flying = {}
	local rigid = {} -- whole lids flying as one piece
	local LIFE = opts.world and 1.5 or 1
	local function launch(p, vel, spin, fadeTime)
		p.Anchored = true
		table.insert(flying, { part = p, cf = p.CFrame, vel = vel, spin = spin, t0 = os.clock(), trans = p.Transparency, fade = fadeTime })
	end
	local function debris(origin, color, count, speed, sizeMin, sizeMax)
		for _ = 1, count do
			local s = (sizeMin + math.random() * (sizeMax - sizeMin)) * S
			local p = Instance.new("Part")
			p.Size = Vector3.new(s, s * 0.8, s)
			p.Color = color
			p.Material = Enum.Material.Ground
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.CastShadow = false
			p.CFrame = CFrame.new(origin + Vector3.new((math.random() - 0.5) * 2, 0.6, (math.random() - 0.5) * 3) * S)
				* CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6)
			p.Parent = model
			local dir = Vector3.new(math.random() - 0.5, 0, math.random() - 0.5)
			dir = (dir.Magnitude > 0.01 and dir.Unit or Vector3.xAxis) * speed * (0.4 + math.random() * 0.6)
			launch(p, dir + Vector3.new(0, speed * (0.9 + math.random() * 0.8), 0),
				Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 14)
		end
	end

	function g.burst(color, t)
		t = t or 0
		local style = model:GetAttribute("OpenStyle") or "Mound"
		local origin = corePos()
		-- OpenStyle "Lid": the whole lid is blasted off in one piece, tumbling up and away (a rigid group)
		if lid and style == "Lid" then
			local lidCf = lid:GetBoundingBox()
			local side = Vector3.new(math.random() - 0.5, 0, math.random() - 0.5)
			side = side.Magnitude > 0.01 and side.Unit or Vector3.xAxis
			local axis = Vector3.yAxis:Cross(side).Unit
			local group = { center = lidCf, parts = {}, t0 = os.clock(),
				vel = (side * (5 + 3 * t) + Vector3.new(0, 20 + 8 * t, 0)) * math.sqrt(S), axis = axis, spinRate = 4 + 3 * t }
			for _, p in ipairs(lid:GetDescendants()) do
				if p:IsA("BasePart") then
					p.Anchored = true
					table.insert(group.parts, { part = p, offset = lidCf:ToObjectSpace(p.CFrame), trans = p.Transparency })
				end
			end
			table.insert(rigid, group)
		elseif lid then
		-- the lid flies apart: small pieces are thrown out of the middle, the big earth mass vanishes in the flash
			for _, p in ipairs(lid:GetDescendants()) do
				if p:IsA("BasePart") then
					local big = math.max(p.Size.X, p.Size.Y, p.Size.Z) > 2.5 * S
					if big and style == "Mound" then
						launch(p, Vector3.new(0, 1.5 * S, 0), Vector3.zero, 0.15)
					else
						local out = p.Position - origin
						out = Vector3.new(out.X, 0, out.Z)
						out = (out.Magnitude > 0.05 and out.Unit or Vector3.new(math.random() - 0.5, 0, math.random() - 0.5).Unit)
						local speed = (7 + math.random() * 6) * S
						launch(p, out * speed + Vector3.new(0, (11 + math.random() * 9) * math.sqrt(S), 0),
							Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 12)
					end
				end
			end
		end
		-- clods of earth thrown up out of the hole (more for rarer pulls)
		debris(origin, (style == "Mound") and Color3.fromRGB(96, 66, 46) or Color3.fromRGB(110, 112, 124), math.floor(10 + 14 * t), (10 + 6 * t) * math.sqrt(S), 0.25, 0.6)
		-- the pit and the cracks light up in the pull's colour
		if pit then
			for _, p in ipairs(pit:GetDescendants()) do
				if p:IsA("BasePart") and p.Name == "Glow" then
					p.Color = color
				end
			end
		end
		for _, p in ipairs(glowParts) do
			p.Color = color
		end
		-- a column of light out of the grave
		local function columnPart(c, transparency)
			local p = Instance.new("Part")
			p.Shape = Enum.PartType.Cylinder
			p.Material = Enum.Material.Neon
			p.Color = c
			p.Transparency = transparency
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.CastShadow = false
			p.Size = Vector3.new(0.1, 0.6, 0.6)
			p.Parent = model
			return p
		end
		local column = columnPart(color, opts.world and 0.4 or 0.25)
		local inner = columnPart(Color3.new(1, 1, 1):Lerp(color, 0.35), opts.world and 0.2 or 0.1)
		local colStart = os.clock()
		local width = (1.6 + 1.6 * t) * S
		local height = (opts.world and (40 + 40 * t) or (10 + 8 * t)) * S
		local holdColumn = opts.world and 2.2 or 1.2

		-- in the world: a real light, dust, sparks and souls
		local light
		if opts.world then
			local holder = Instance.new("Part")
			holder.Anchored = true
			holder.CanCollide = false
			holder.CanQuery = false
			holder.CanTouch = false
			holder.Transparency = 1
			holder.Size = Vector3.one * 0.5
			holder.CFrame = CFrame.new(origin + Vector3.new(0, 0.5 * S, 0))
			holder.Parent = model
			light = Instance.new("PointLight")
			light.Color = color
			light.Range = 30 + 30 * t
			light.Brightness = 5 + 4 * t
			light.Shadows = false
			light.Parent = holder
			local dust = emitter(holder, SMOKE, Color3.fromRGB(150, 130, 110):Lerp(color, 0.25), Color3.fromRGB(70, 62, 60), 2 * S, 7 * S, 2.2, 22 * S, 80, 0.15)
			dust.Drag = 3
			dust:Emit(18 + math.floor(18 * t))
			local sparks = emitter(holder, SPARKLE, Color3.new(1, 1, 1), color, 0.9 * S, 0, 1.4, 36 * S, 60, 1)
			sparks.Acceleration = Vector3.new(0, -25, 0)
			sparks.Drag = 1
			sparks:Emit(30 + math.floor(60 * t))
			local souls = emitter(holder, SPARKLE, color:Lerp(Color3.new(1, 1, 1), 0.4), color, 0.6 * S, 0, 2.2, 10 * S, 25, 1)
			souls.Rate = 20 + 30 * t
			task.delay(1.6, function()
				souls.Enabled = false
			end)
			-- ground fog: thick white smoke creeping slowly out of the grave in every direction, hugging the ground
			-- (emitters sit just above the floor round the pit and blow sideways, so the smoke never rises)
			local ground = origin.Y - 0.6 * S -- the Core sits 0.6 above the floor in the model
			for k = 0, 7 do
				local a = k / 8 * math.pi * 2
				local outDir = Vector3.new(math.cos(a), 0, math.sin(a))
				local at = Vector3.new(origin.X, ground + 0.15, origin.Z) + outDir * 1.1 * S
				local src = Instance.new("Part")
				src.Anchored = true
				src.CanCollide = false
				src.CanQuery = false
				src.CanTouch = false
				src.Transparency = 1
				src.Size = Vector3.one * 0.3
				src.CFrame = CFrame.lookAt(at, at + outDir) -- its Front face points outwards
				src.Parent = holder
				local fog = emitter(src, SMOKE, Color3.fromRGB(240, 240, 244), Color3.fromRGB(214, 214, 222), 1.1 * S, 3.2 * S, 8, 1.8 * S, 0, 0)
				fog.EmissionDirection = Enum.NormalId.Front
				fog.SpreadAngle = Vector2.new(35, 4)
				fog.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.15, 0.3),
					NumberSequenceKeypoint.new(0.6, 0.4), NumberSequenceKeypoint.new(1, 1) })
				fog.Drag = 0.5
				fog.Acceleration = Vector3.zero
				fog.RotSpeed = NumberRange.new(-8, 8)
				fog.LightInfluence = 0.7
				fog.Rate = 3.5
			end
			Debris:AddItem(holder, 30)
		end

		local conn
		conn = RunService.RenderStepped:Connect(function()
			if not alive() then
				conn:Disconnect()
				return
			end
			local now = os.clock()
			for i = #flying, 1, -1 do
				local f = flying[i]
				local age = now - f.t0
				if f.part.Parent then
					local pos = f.cf.Position + f.vel * age + (f.fade and Vector3.zero or GRAVITY * (0.5 * age * age))
					f.part.CFrame = CFrame.new(pos) * (f.cf - f.cf.Position) * CFrame.Angles(f.spin.X * age, f.spin.Y * age, f.spin.Z * age)
					if f.fade then
						f.part.Transparency = f.trans + (1 - f.trans) * math.clamp(age / f.fade, 0, 1)
					else
						f.part.Transparency = f.trans + (1 - f.trans) * math.clamp((age - (LIFE - 0.65)) / 0.5, 0, 1)
					end
				end
				if age > LIFE then
					f.part:Destroy()
					table.remove(flying, i)
				end
			end
			for i = #rigid, 1, -1 do
				local r = rigid[i]
				local age = now - r.t0
				local pos = r.center.Position + r.vel * age + GRAVITY * (0.5 * age * age)
				local cf = CFrame.new(pos) * CFrame.fromAxisAngle(r.axis, r.spinRate * age) * (r.center - r.center.Position)
				local fade = math.clamp((age - (LIFE - 0.5)) / 0.5, 0, 1)
				for _, e in ipairs(r.parts) do
					if e.part.Parent then
						e.part.CFrame = cf * e.offset
						e.part.Transparency = e.trans + (1 - e.trans) * fade
					end
				end
				if age > LIFE then
					for _, e in ipairs(r.parts) do
						e.part:Destroy()
					end
					table.remove(rigid, i)
				end
			end
			-- the column shoots up, widens, then thins out
			local a = now - colStart
			local up = math.clamp(a / 0.25, 0, 1)
			local h = height * up
			local w = width * (a < 0.3 and (0.4 + 2 * a) or math.max(0.15, 1 - (a - 0.3) * 0.9 / holdColumn))
			column.Size = Vector3.new(h, w, w)
			column.CFrame = CFrame.new(origin + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, 0, math.rad(90))
			inner.Size = Vector3.new(h, w * 0.45, w * 0.45)
			inner.CFrame = column.CFrame
			if a > holdColumn then
				column.Transparency = math.min(1, column.Transparency + 0.03)
				inner.Transparency = math.min(1, inner.Transparency + 0.03)
			end
			if light then
				light.Brightness = (5 + 4 * t) * math.clamp(1 - (a - 0.4) / 2.5, 0.25, 1)
			end
		end)
	end

	function g.stop()
		g.stopped = true
	end

	return g
end

-- The grave in a ViewportFrame (the reveal overlay)
function GraveOpening.create(parent, graveType, size, zIndex)
	local template = GraveOpening.template(graveType)
	if not template then
		return nil
	end

	local vp = Instance.new("ViewportFrame")
	vp.BackgroundTransparency = 1
	vp.Size = size
	vp.Ambient = Color3.fromRGB(150, 150, 165)
	vp.LightColor = Color3.fromRGB(255, 240, 225)
	vp.LightDirection = Vector3.new(0.5, -0.8, 0.4)
	vp.ZIndex = zIndex or 1
	vp.Parent = parent

	local model = template:Clone()
	model:PivotTo(CFrame.new())
	model.Parent = vp

	-- camera: front three-quarter view from above (the front of a grave faces -Z), framing the whole model
	local boxCf, boxSize = model:GetBoundingBox()
	local center = boxCf.Position
	local cam = Instance.new("Camera")
	cam.FieldOfView = 32
	local radius = boxSize.Magnitude / 2
	local dist = radius / math.tan(math.rad(cam.FieldOfView / 2)) * 0.82
	cam.CFrame = CFrame.lookAt(center + Vector3.new(-0.45, 0.62, -1).Unit * dist, center)
	cam.Parent = vp
	vp.CurrentCamera = cam

	local g = GraveOpening.attach(model, { alive = function() return vp.Parent ~= nil end })
	g.frame = vp
	function g.destroy()
		g.stop()
		vp:Destroy()
	end
	return g
end

return GraveOpening
