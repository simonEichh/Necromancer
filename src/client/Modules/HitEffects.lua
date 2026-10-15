-- Hit flash on the wall: drawn when the server reports that a unit hit the wall (remote WallHit: position on the
-- wall face, the lane direction, the damage and whether it was a "ghost" unit). It replaces the old plain block that
-- the server used to spawn on the wall and the floating damage numbers (the wall's HP bar shows the damage).
--
-- One hit is made of:
--   1. a bright core flash that swells and fades (neon ball, half in front of the wall face),
--   2. sparks flying out of the wall towards the army and falling in an arc,
--   3. a few puffs of dust,
--   4. a short flicker of light.
-- Bigger hits are bigger (scaled by the logarithm of the damage). Ghost (transparent) units hit in cold blue-white, the
-- others in warm yellow-orange. Everything is local: the server sends one small event per hit and nothing else.
-- (Staff caster barrages do not use this: their orbs draw their own impacts, see SpellEffects.)
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local wallHit = ReplicatedStorage:WaitForChild("WallHit")

local RENDER_DISTANCE = 260 -- hits further from the camera than this are not drawn
local MAX_ACTIVE = 40 -- most flashes alive at once (a big army hits the wall a lot)
local LIFETIME = 1.2
local SPARK_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"
local DUST_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"

local PALETTES = {
	normal = { core = Color3.fromRGB(255, 244, 200), glow = Color3.fromRGB(255, 160, 60) },
	ghost = { core = Color3.fromRGB(215, 235, 255), glow = Color3.fromRGB(110, 170, 255) },
}

local active = 0
local fxFolder = Instance.new("Folder")
fxFolder.Name = "HitFX"
fxFolder.Parent = Workspace

local function newPart(name, size, cf)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Parent = fxFolder
	return p
end

-- Style "Slash" (sword units, unit def hitFx, e.g. Skelly): metal on stone. A bright white crescent sweeps across the
-- wall face the way the blade travels (from the attacker's upper right down to its lower left), flares, thins into a
-- dark scratch that fades; white-hot sparks shower off along the cut, stone dust puffs off the wall.
local SLASH_COLOR = Color3.fromRGB(255, 255, 255)
local SLASH_GLOW = Color3.fromRGB(215, 230, 255)
local SCRATCH_COLOR = Color3.fromRGB(52, 48, 46)
local SLASH_SEGMENTS = 6
local SLASH_SWEEP = 0.07 -- seconds for the cut to cross the wall

-- one glowing cut across the wall face from a to b (bowing out by `bulge` in the middle): SLASH_SEGMENTS neon pieces,
-- thick in the middle and pointed at both ends (a crescent), appearing one after the other over `sweep` seconds from
-- `delay` on, each flaring, thinning and cooling into a dark scratch that fades
local function stroke(normal, a, b, bulge, thickness, coreColor, glowColor, delay, sweep, scale)
	local function at(s)
		return a:Lerp(b, s) + bulge * (4 * s * (1 - s))
	end
	for i = 1, SLASH_SEGMENTS do
		local p0, p1 = at((i - 1) / SLASH_SEGMENTS), at(i / SLASH_SEGMENTS)
		local len = (p1 - p0).Magnitude * 1.15
		local mid = (p0 + p1) / 2
		local width = (0.06 + thickness * math.sin(math.pi * (i - 0.5) / SLASH_SEGMENTS)) * scale
		local cf = CFrame.lookAt(mid + normal * 0.06, mid + normal * 0.06 + (p1 - p0), normal)
		local core = newPart("SlashCore", Vector3.new(width, 0.05, len), cf)
		core.Material = Enum.Material.Neon
		core.Color = coreColor
		core.Transparency = 1
		local glow = newPart("SlashGlow", Vector3.new(width * 2.6 + 0.15, 0.04, len * 1.1), cf + normal * 0.04)
		glow.Material = Enum.Material.Neon
		glow.Color = glowColor
		glow.Transparency = 1
		task.delay(delay + (i - 1) / SLASH_SEGMENTS * sweep, function()
			core.Transparency = 0
			glow.Transparency = 0.5
			TweenService:Create(glow, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Size = Vector3.new(width * 3.6 + 0.2, 0.04, len * 1.2),
				Transparency = 1,
			}):Play()
			local thin = TweenService:Create(core, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Size = Vector3.new(0.06 * scale, 0.05, len),
				Transparency = 0.6,
			})
			thin.Completed:Connect(function()
				-- the white-hot line cools into a scratch in the stone, then fades
				core.Material = Enum.Material.SmoothPlastic
				core.Color = SCRATCH_COLOR
				core.Transparency = 0.35
				TweenService:Create(core, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
					Transparency = 1,
				}):Play()
			end)
			thin:Play()
		end)
		Debris:AddItem(core, LIFETIME)
		Debris:AddItem(glow, 0.4)
	end
end

local function slash(origin, normal, scale)
	local right = (-normal):Cross(Vector3.yAxis) -- the attacker looks along -normal: its right hand side
	right = right.Magnitude > 0.1 and right.Unit or Vector3.xAxis
	local up = Vector3.yAxis
	local a = origin + (right * 1.35 + up * 1.15) * scale
	local b = origin - (right * 1.35 + up * 1.0) * scale
	local bulge = (right - up).Unit * 0.45 * scale -- the arc of the swing bows out a little
	stroke(normal, a, b, bulge, 0.3, SLASH_COLOR, SLASH_GLOW, 0, SLASH_SWEEP, scale)

	-- the flash where the edge bites (the middle of the cut)
	local centre = (a + b) / 2 + bulge + normal * 0.3
	local core = newPart("HitCore", Vector3.one * 0.5 * scale, CFrame.new(centre))
	core.Shape = Enum.PartType.Ball
	core.Color = SLASH_COLOR
	core.Material = Enum.Material.Neon
	core.Transparency = 0.1
	TweenService:Create(core, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.one * 2.2 * scale,
		Transparency = 1,
	}):Play()
	Debris:AddItem(core, 0.25)

	-- sparks fly off along the cut, away from the wall
	local cut = (b - a).Unit
	local emitterPart = newPart("HitEmitter", Vector3.one * 0.2, CFrame.lookAt(centre, centre + normal * 0.7 + cut * 0.7))
	emitterPart.Transparency = 1
	local sparks = Instance.new("ParticleEmitter")
	sparks.Texture = SPARK_TEXTURE
	sparks.Color = ColorSequence.new(SLASH_COLOR, Color3.fromRGB(255, 236, 190))
	sparks.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.32 * scale), NumberSequenceKeypoint.new(1, 0) })
	sparks.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
	sparks.LightEmission = 1
	sparks.LightInfluence = 0
	sparks.Orientation = Enum.ParticleOrientation.VelocityParallel
	sparks.Lifetime = NumberRange.new(0.2, 0.45)
	sparks.Speed = NumberRange.new(18 * scale, 34 * scale)
	sparks.SpreadAngle = Vector2.new(35, 35)
	sparks.EmissionDirection = Enum.NormalId.Front
	sparks.Acceleration = Vector3.new(0, -45, 0)
	sparks.Rate = 0
	sparks.Parent = emitterPart

	local dust = Instance.new("ParticleEmitter")
	dust.Texture = DUST_TEXTURE
	dust.Color = ColorSequence.new(Color3.fromRGB(170, 160, 150), Color3.fromRGB(110, 105, 100))
	dust.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7 * scale), NumberSequenceKeypoint.new(1, 2.4 * scale) })
	dust.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1) })
	dust.Lifetime = NumberRange.new(0.4, 0.8)
	dust.Speed = NumberRange.new(2, 5)
	dust.SpreadAngle = Vector2.new(60, 60)
	dust.EmissionDirection = Enum.NormalId.Front
	dust.Rotation = NumberRange.new(0, 360)
	dust.Drag = 2
	dust.LightInfluence = 1
	dust.Rate = 0
	dust.Parent = emitterPart

	sparks:Emit(math.floor(12 + 6 * scale))
	dust:Emit(2)

	local light = Instance.new("PointLight")
	light.Color = SLASH_GLOW
	light.Range = 10 * scale
	light.Brightness = 5
	light.Shadows = false
	light.Parent = emitterPart
	TweenService:Create(light, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Brightness = 0 }):Play()

	Debris:AddItem(emitterPart, LIFETIME)
end

-- The server sends a point on the wall's nominal face plane, but the wall models have stones sticking out past it, so a
-- flat cut drawn there sits inside the stone. Cast a ray from in front of the wall back along -normal and return the
-- real surface point (only anchored parts count: the units in the way are unanchored); nil if nothing was hit.
local surfaceParams = RaycastParams.new()
surfaceParams.FilterType = Enum.RaycastFilterType.Exclude

local function wallSurface(position, normal)
	local ignore = { fxFolder }
	local from = position + normal * 6
	for _ = 1, 5 do
		surfaceParams.FilterDescendantsInstances = ignore
		local hit = Workspace:Raycast(from, -normal * 9, surfaceParams)
		if not hit then
			return nil
		end
		if hit.Instance.Anchored and hit.Instance.Transparency < 1 then
			return hit.Position
		end
		table.insert(ignore, hit.Instance)
	end
	return nil
end

local function flash(position, forward, damage, isGhost, style)
	local camera = Workspace.CurrentCamera
	if camera and (position - camera.CFrame.Position).Magnitude > RENDER_DISTANCE then
		return
	end
	if active >= MAX_ACTIVE then
		return
	end
	active += 1
	task.delay(LIFETIME, function()
		active -= 1
	end)

	local palette = isGhost and PALETTES.ghost or PALETTES.normal
	-- bigger hits are bigger: 12 damage ~ 1.0, 1000 ~ 1.45, 12000 ~ 1.75 (capped)
	local scale = math.clamp(0.7 + math.log10(math.max(damage or 1, 1)) * 0.25, 0.8, 2.0)
	-- the wall's front face looks back towards the army: against the lane direction
	local normal = -(typeof(forward) == "Vector3" and forward.Magnitude > 0.1 and forward.Unit or Vector3.zAxis)
	local origin = position + normal * 0.4
	local facing = CFrame.lookAt(origin, origin + normal)
	if style == "Slash" then
		-- the cuts lie flat on the wall: sample the real (bumpy) surface across the area they cover and put them just in
		-- front of the stone that sticks out furthest
		local right = (-normal):Cross(Vector3.yAxis)
		right = right.Magnitude > 0.1 and right.Unit or Vector3.xAxis
		local depth = 0
		for _, o in ipairs({ Vector3.zero, right * 1.3, -right * 1.3, Vector3.yAxis * 1.1, -Vector3.yAxis * 1.0 }) do
			local surface = wallSurface(position + o * scale, normal)
			if surface then
				depth = math.max(depth, (surface - position):Dot(normal))
			end
		end
		local at = position + normal * (depth + 0.2)
		slash(at, normal, scale)
		return
	end

	-- 1. core flash
	local core = newPart("HitCore", Vector3.one * 0.8 * scale, CFrame.new(origin))
	core.Shape = Enum.PartType.Ball
	core.Color = palette.core
	core.Material = Enum.Material.Neon
	core.Transparency = 0.05
	TweenService:Create(core, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.one * 3.6 * scale,
		Transparency = 1,
	}):Play()
	Debris:AddItem(core, 0.3)

	-- 2 + 3. sparks and dust, emitted from a tiny invisible part facing away from the wall
	local emitterPart = newPart("HitEmitter", Vector3.one * 0.2, facing)
	emitterPart.Transparency = 1

	local sparks = Instance.new("ParticleEmitter")
	sparks.Texture = SPARK_TEXTURE
	sparks.Color = ColorSequence.new(palette.core, palette.glow)
	sparks.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55 * scale), NumberSequenceKeypoint.new(1, 0) })
	sparks.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
	sparks.LightEmission = 1
	sparks.Lifetime = NumberRange.new(0.25, 0.55)
	sparks.Speed = NumberRange.new(14 * scale, 28 * scale)
	sparks.SpreadAngle = Vector2.new(55, 55)
	sparks.EmissionDirection = Enum.NormalId.Front
	sparks.Acceleration = Vector3.new(0, -35, 0)
	sparks.Rate = 0
	sparks.Parent = emitterPart

	local dust = Instance.new("ParticleEmitter")
	dust.Texture = DUST_TEXTURE
	dust.Color = ColorSequence.new(Color3.fromRGB(170, 160, 150), Color3.fromRGB(110, 105, 100))
	dust.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.0 * scale), NumberSequenceKeypoint.new(1, 3.4 * scale) })
	dust.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) })
	dust.Lifetime = NumberRange.new(0.5, 0.9)
	dust.Speed = NumberRange.new(2, 6)
	dust.SpreadAngle = Vector2.new(70, 70)
	dust.EmissionDirection = Enum.NormalId.Front
	dust.Rotation = NumberRange.new(0, 360)
	dust.RotSpeed = NumberRange.new(-40, 40)
	dust.Drag = 2
	dust.LightInfluence = 1
	dust.Rate = 0
	dust.Parent = emitterPart

	sparks:Emit(math.floor(9 + 5 * scale))
	dust:Emit(math.floor(2 + scale))

	-- 4. light flicker
	local light = Instance.new("PointLight")
	light.Color = palette.glow
	light.Range = 12 * scale
	light.Brightness = 4 * scale
	light.Shadows = false
	light.Parent = emitterPart
	TweenService:Create(light, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Brightness = 0 }):Play()

	Debris:AddItem(emitterPart, LIFETIME)
end

wallHit.OnClientEvent:Connect(flash)

return {}
