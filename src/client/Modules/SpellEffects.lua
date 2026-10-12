-- Client-side visuals for units that attack with a magic cast (model attribute AttackStyle = "StaffCast").
--
-- The server only sets attributes on the unit model: AttackCount (incremented per attack) and AimPos (the
-- world position to hit on the wall). Everything you see here is drawn locally, so nothing is sent per frame:
--   1. While the staff is raised (see UnitAnimator.castPose) a turning magic circle fades in just in front of
--      the staff tip: two counter-rotating layers of rings, squares and dots drawn with a SurfaceGui.
--   2. A volley of orbs flies out of the circle one after another. Each orb weaves in its own spiral round
--      the straight line to the wall (so the volley swarms) and converges on the target, leaving a foggy,
--      glowing particle trail behind it. Every orb ends in a small burst.
-- Model attributes used (set in the model's build script): AttackStyle, CastColor (Color3, default violet),
-- CastPart (name of the part at the staff tip that the circle follows, default "StaffOrb").
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local UnitAnimator = require(script.Parent.UnitAnimator)

-- ============================================================
-- Settings
-- ============================================================
local TAG = "ProceduralUnit"
local RENDER_DISTANCE = 220 -- casts further from the camera than this are not drawn
local MAX_CIRCLES = 14
local MAX_PROJECTILES = 90
local SHOTS = 6 -- projectiles per cast (UnitAnimator.castPose pulses the arm once per shot)
local ORB_SPEED = 52 -- studs per second
local DEFAULT_COLOR = Color3.fromRGB(172, 112, 255)
local FOG_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"
local SPARK_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"

local circles = {}
local projectiles = {}
local fxFolder = Instance.new("Folder")
fxFolder.Name = "SpellFX"
fxFolder.Parent = Workspace

local function clamp01(x)
	return math.clamp(x, 0, 1)
end

-- ============================================================
-- Magic circle (SurfaceGui built from frames)
-- ============================================================
local function newFrame(parent, size, fillColor)
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromScale(0.5, 0.5)
	f.Size = UDim2.fromScale(size, size)
	f.BorderSizePixel = 0
	f.BackgroundTransparency = fillColor and 0 or 1
	f.BackgroundColor3 = fillColor or Color3.new(1, 1, 1)
	f.Parent = parent
	return f
end

local function outline(frame, color, thickness, round)
	if round then
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = frame
	end
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = thickness
	stroke.Parent = frame
end

local function dotsOnRing(parent, count, radius, dotSize, color)
	for i = 1, count do
		local a = (i / count) * math.pi * 2
		local dot = newFrame(parent, dotSize, color)
		dot.Position = UDim2.fromScale(0.5 + math.cos(a) * radius, 0.5 + math.sin(a) * radius)
		outline(dot, color, 1, true)
	end
end

-- Builds the circle on both faces of the part (it is seen from behind the caster and from the wall side).
-- Returns a list of { group, outer, inner } (one entry per face) so the update loop can spin and fade it.
local function buildCircle(part, color)
	local layers = {}
	for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
		gui.CanvasSize = Vector2.new(512, 512)
		gui.LightInfluence = 0
		gui.Brightness = 2.5
		gui.Parent = part

		local group = Instance.new("CanvasGroup")
		group.Size = UDim2.fromScale(1, 1)
		group.BackgroundTransparency = 1
		group.GroupTransparency = 1
		group.Parent = gui

		-- outer layer: turns one way (two rings, a ring of dots and an eight-pointed star)
		local outer = newFrame(group, 1)
		outline(newFrame(outer, 0.96), color, 10, true)
		outline(newFrame(outer, 0.84), color, 4, true)
		dotsOnRing(outer, 12, 0.45, 0.04, color)
		outline(newFrame(outer, 0.62), color, 5, false)
		local star = newFrame(outer, 0.62)
		star.Rotation = 45
		outline(star, color, 5, false)

		-- inner layer: turns the other way (a ring, a hexagram-like pair of squares and a glowing core)
		local inner = newFrame(group, 1)
		outline(newFrame(inner, 0.5), color, 6, true)
		local sqA = newFrame(inner, 0.36)
		sqA.Rotation = 20
		outline(sqA, color, 4, false)
		local sqB = newFrame(inner, 0.36)
		sqB.Rotation = 65
		outline(sqB, color, 4, false)
		outline(newFrame(inner, 0.12, color), color, 2, true)

		table.insert(layers, { group = group, outer = outer, inner = inner })
	end
	return layers
end

local function startCircle(model, muzzle, aim, color, scale, dur)
	local from = muzzle.Position
	local flat = Vector3.new(aim.X - from.X, 0, aim.Z - from.Z)
	if flat.Magnitude < 1 then
		return
	end
	local dir = flat.Unit
	local diameter = 4.8 * scale

	local part = Instance.new("Part")
	part.Name = "MagicCircle"
	part.Size = Vector3.new(diameter * 0.4, diameter * 0.4, 0.2)
	part.Transparency = 1
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.CFrame = CFrame.lookAt(from + dir * 1.8 * scale, from + dir * 5 * scale)
	part.Parent = fxFolder

	local layers = buildCircle(part, color)

	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 14 * scale
	light.Brightness = 0
	light.Shadows = false
	light.Parent = part

	-- sparks flying off the flat disc
	local sparks = Instance.new("ParticleEmitter")
	sparks.Texture = SPARK_TEXTURE
	sparks.Color = ColorSequence.new(Color3.new(1, 1, 1), color)
	sparks.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35 * scale), NumberSequenceKeypoint.new(1, 0) })
	sparks.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
	sparks.LightEmission = 1
	sparks.Lifetime = NumberRange.new(0.4, 0.8)
	sparks.Rate = 28
	sparks.Speed = NumberRange.new(1, 4)
	sparks.Shape = Enum.ParticleEmitterShape.Sphere
	sparks.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	sparks.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
	sparks.Parent = part

	local gap = dur * 0.55 / SHOTS
	local circle = {
		part = part,
		layers = layers,
		light = light,
		model = model,
		muzzle = muzzle,
		dir = dir,
		scale = scale,
		diameter = diameter,
		born = os.clock(),
		life = 0.05 + SHOTS * gap + 0.3,
		alive = true,
	}
	table.insert(circles, circle)
	return circle
end

-- ============================================================
-- Projectiles (swarming orbs with a foggy trail)
-- ============================================================
local function spawnProjectile(circle, aim, color, scale)
	if #projectiles >= MAX_PROJECTILES then
		return
	end
	local cf = circle.part.CFrame
	local ang = math.random() * math.pi * 2
	local radius = math.random() * circle.diameter * 0.3
	local start = cf.Position + cf.RightVector * math.cos(ang) * radius + cf.UpVector * math.sin(ang) * radius
	local target = aim + cf.RightVector * (math.random() * 5 - 2.5) + Vector3.new(0, math.random() * 5 - 2.5, 0)
	local delta = target - start
	local dist = delta.Magnitude
	if dist < 1 then
		return
	end
	local dir = delta / dist
	local perp1 = dir:Cross(Vector3.yAxis)
	if perp1.Magnitude < 0.1 then
		perp1 = Vector3.xAxis
	end
	perp1 = perp1.Unit
	local perp2 = dir:Cross(perp1).Unit

	local orb = Instance.new("Part")
	orb.Name = "SpellOrb"
	orb.Shape = Enum.PartType.Ball
	orb.Size = Vector3.one * 0.55 * scale
	orb.Color = color
	orb.Material = Enum.Material.Neon
	orb.Anchored = true
	orb.CanCollide = false
	orb.CanQuery = false
	orb.CanTouch = false
	orb.CastShadow = false
	orb.CFrame = CFrame.new(start)
	orb.Parent = fxFolder

	local darker = color:Lerp(Color3.fromRGB(30, 10, 60), 0.6)

	-- foggy trail: soft smoke puffs that swell and fade, left behind in world space
	local fog = Instance.new("ParticleEmitter")
	fog.Texture = FOG_TEXTURE
	fog.Color = ColorSequence.new(color, darker)
	fog.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9 * scale), NumberSequenceKeypoint.new(1, 3.2 * scale) })
	fog.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(0.5, 0.65),
		NumberSequenceKeypoint.new(1, 1),
	})
	fog.Lifetime = NumberRange.new(0.7, 1.1)
	fog.Rate = 60
	fog.Speed = NumberRange.new(0.5, 1.8)
	fog.SpreadAngle = Vector2.new(180, 180)
	fog.Rotation = NumberRange.new(0, 360)
	fog.RotSpeed = NumberRange.new(-50, 50)
	fog.Drag = 3
	fog.LightEmission = 0.6
	fog.LightInfluence = 0
	fog.Parent = orb

	-- bright sparkles inside the fog
	local glints = Instance.new("ParticleEmitter")
	glints.Texture = SPARK_TEXTURE
	glints.Color = ColorSequence.new(Color3.new(1, 1, 1), color)
	glints.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4 * scale), NumberSequenceKeypoint.new(1, 0) })
	glints.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
	glints.LightEmission = 1
	glints.Lifetime = NumberRange.new(0.35, 0.6)
	glints.Rate = 30
	glints.Speed = NumberRange.new(0.5, 2)
	glints.SpreadAngle = Vector2.new(180, 180)
	glints.Parent = orb

	-- a thin glowing ribbon right behind the orb
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, 0.2 * scale, 0)
	a0.Parent = orb
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -0.2 * scale, 0)
	a1.Parent = orb
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Lifetime = 0.3
	trail.Color = ColorSequence.new(color, darker)
	trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
	trail.WidthScale = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0) })
	trail.LightEmission = 1
	trail.FaceCamera = true
	trail.Parent = orb

	local light = Instance.new("PointLight")
	light.Color = color
	light.Brightness = 1.5
	light.Range = 7 * scale
	light.Shadows = false
	light.Parent = orb

	table.insert(projectiles, {
		orb = orb,
		fog = fog,
		glints = glints,
		light = light,
		start = start,
		target = target,
		perp1 = perp1,
		perp2 = perp2,
		t0 = os.clock(),
		duration = math.max(0.4, dist / ORB_SPEED),
		phase = math.random() * math.pi * 2,
		spin = (math.random() < 0.5 and -1 or 1) * (1 + math.random()),
		amp = (1.4 + math.random() * 1.2) * scale,
		color = color,
		scale = scale,
	})
end

-- the orb has reached the wall: a flash, a puff of fog, then let the particles fade out
local function impact(p)
	p.orb.Position = p.target
	p.fog:Emit(14)
	p.glints:Emit(10)
	p.fog.Enabled = false
	p.glints.Enabled = false
	p.light.Enabled = false
	p.orb.Transparency = 1
	Debris:AddItem(p.orb, 1.4)

	local flash = Instance.new("Part")
	flash.Shape = Enum.PartType.Ball
	flash.Size = Vector3.one * 0.6 * p.scale
	flash.Color = p.color
	flash.Material = Enum.Material.Neon
	flash.Anchored = true
	flash.CanCollide = false
	flash.CanQuery = false
	flash.CanTouch = false
	flash.CastShadow = false
	flash.CFrame = CFrame.new(p.target)
	flash.Parent = fxFolder
	TweenService:Create(flash, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.one * 4 * p.scale,
		Transparency = 1,
	}):Play()
	Debris:AddItem(flash, 0.3)
end

-- ============================================================
-- Per-frame update
-- ============================================================
RunService.RenderStepped:Connect(function()
	local now = os.clock()

	for i = #circles, 1, -1 do
		local c = circles[i]
		local elapsed = now - c.born
		if elapsed >= c.life or not c.model.Parent or not c.muzzle.Parent then
			c.alive = false
			c.part:Destroy()
			table.remove(circles, i)
		else
			local fadeIn = clamp01(elapsed / 0.15)
			local fadeOut = clamp01((c.life - elapsed) / 0.25)
			local vis = math.min(fadeIn, fadeOut)
			local grow = 0.4 + 0.6 * (1 - (1 - fadeIn) ^ 2)
			local d = c.diameter * grow
			c.part.Size = Vector3.new(d, d, 0.2)
			-- follow the staff tip
			local center = c.muzzle.Position + c.dir * 1.8 * c.scale
			c.part.CFrame = CFrame.lookAt(center, center + c.dir)
			c.light.Brightness = 3 * vis
			for _, layer in ipairs(c.layers) do
				layer.group.GroupTransparency = 1 - vis
				layer.outer.Rotation = elapsed * 55
				layer.inner.Rotation = -elapsed * 95
			end
		end
	end

	for i = #projectiles, 1, -1 do
		local p = projectiles[i]
		local t = (now - p.t0) / p.duration
		if t >= 1 or not p.orb.Parent then
			if p.orb.Parent then
				impact(p)
			end
			table.remove(projectiles, i)
		else
			local s = t ^ 1.25
			local base = p.start:Lerp(p.target, s)
			local ang = p.phase + p.spin * math.pi * 2 * t
			local swirl = p.amp * math.sin(math.pi * t) ^ 0.8
			p.orb.Position = base + (p.perp1 * math.cos(ang) + p.perp2 * math.sin(ang)) * swirl
		end
	end
end)

-- ============================================================
-- Hooking up to unit models
-- ============================================================
local function castStaff(model)
	local camera = Workspace.CurrentCamera
	if camera and (model:GetPivot().Position - camera.CFrame.Position).Magnitude > RENDER_DISTANCE then
		return
	end
	if #circles >= MAX_CIRCLES then
		return
	end
	local aim = model:GetAttribute("AimPos")
	if typeof(aim) ~= "Vector3" then
		return
	end
	local muzzle = model:FindFirstChild(model:GetAttribute("CastPart") or "StaffOrb", true)
	if not muzzle then
		return
	end
	local color = model:GetAttribute("CastColor")
	if typeof(color) ~= "Color3" then
		color = DEFAULT_COLOR
	end
	local scale = model:GetScale()
	local dur = UnitAnimator.attackDuration(model)

	-- wait until the staff is up (the animator raises it during the first 22% of the attack)
	task.delay(dur * 0.22, function()
		if not model.Parent or not muzzle.Parent then
			return
		end
		local circle = startCircle(model, muzzle, aim, color, scale, dur)
		if circle then
			local gap = dur * 0.55 / SHOTS
			for i = 1, SHOTS do
				task.delay((i - 1) * gap + 0.05, function()
					if circle.alive then
						spawnProjectile(circle, aim, color, scale)
					end
				end)
			end
		end
	end)
end

local watched = {} -- [model] = connection

local function watch(model)
	if watched[model] then
		return
	end
	local last = model:GetAttribute("AttackCount") or 0
	watched[model] = model:GetAttributeChangedSignal("AttackCount"):Connect(function()
		local count = model:GetAttribute("AttackCount") or 0
		if count == last then
			return
		end
		last = count
		if model:GetAttribute("AttackStyle") == "StaffCast" then
			castStaff(model)
		end
	end)
end

CollectionService:GetInstanceAddedSignal(TAG):Connect(watch)
CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(model)
	local conn = watched[model]
	if conn then
		conn:Disconnect()
		watched[model] = nil
	end
end)
for _, model in ipairs(CollectionService:GetTagged(TAG)) do
	watch(model)
end

return {}
