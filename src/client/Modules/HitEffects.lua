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

local SHADOW_GLOW = Color3.fromRGB(120, 60, 255) -- the awakened forms' cuts: the unit's accent in the core, violet round it

local function slash(origin, normal, scale, shadow)
	local glowColor = shadow and SHADOW_GLOW or SLASH_GLOW
	local right = (-normal):Cross(Vector3.yAxis) -- the attacker looks along -normal: its right hand side
	right = right.Magnitude > 0.1 and right.Unit or Vector3.xAxis
	local up = Vector3.yAxis
	local a = origin + (right * 1.35 + up * 1.15) * scale
	local b = origin - (right * 1.35 + up * 1.0) * scale
	local bulge = (right - up).Unit * 0.45 * scale -- the arc of the swing bows out a little
	stroke(normal, a, b, bulge, 0.3, SLASH_COLOR, glowColor, 0, SLASH_SWEEP, scale)

	-- (no flash ball: the cut itself is the hit; the sparks fly from where the edge bites)
	local centre = (a + b) / 2 + bulge + normal * 0.3

	-- sparks fly off along the cut, away from the wall
	local cut = (b - a).Unit
	local emitterPart = newPart("HitEmitter", Vector3.one * 0.2, CFrame.lookAt(centre, centre + normal * 0.7 + cut * 0.7))
	emitterPart.Transparency = 1
	local sparks = Instance.new("ParticleEmitter")
	sparks.Texture = SPARK_TEXTURE
	sparks.Color = ColorSequence.new(SLASH_COLOR, shadow and SHADOW_GLOW or Color3.fromRGB(255, 236, 190))
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
	light.Color = glowColor
	light.Range = 10 * scale
	light.Brightness = 5
	light.Shadows = false
	light.Parent = emitterPart
	TweenService:Create(light, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Brightness = 0 }):Play()

	Debris:AddItem(emitterPart, LIFETIME)
end

-- Style "Claw" (the crawling Ghoul's pounce): three parallel gashes raked down the wall (the outer two a beat behind
-- the middle one, slightly fanned), glowing a sickly yellow-green before they cool into dark scratches; rough stone
-- chips and dust burst off the wall, a dim green light.
local CLAW_COLOR = Color3.fromRGB(222, 244, 150)
local CLAW_GLOW = Color3.fromRGB(140, 190, 60)

local function claw(origin, normal, scale, shadow)
	local coreColor = shadow and Color3.fromRGB(244, 238, 150) or CLAW_COLOR -- (the shadow Ghoul's yellow eyes)
	local glowColor = shadow and SHADOW_GLOW or CLAW_GLOW
	local right = (-normal):Cross(Vector3.yAxis)
	right = right.Magnitude > 0.1 and right.Unit or Vector3.xAxis
	local up = Vector3.yAxis
	for i = -1, 1 do
		local off = right * (i * 0.42 * scale)
		local a = origin + off + (up * 1.1 + right * (0.18 + i * 0.06)) * scale
		local b = origin + off * 1.2 - (up * 1.0 + right * 0.1) * scale
		stroke(normal, a, b, right * 0.12 * scale, 0.16, coreColor, glowColor, math.abs(i) * 0.025, 0.08, scale)
	end

	local emitterPart = newPart("HitEmitter", Vector3.one * 0.2, CFrame.lookAt(origin + normal * 0.3, origin + normal * 1.3 - up * 0.3))
	emitterPart.Transparency = 1
	-- stone chips: dark, not glowing, thrown out and falling fast
	local chips = Instance.new("ParticleEmitter")
	chips.Texture = SPARK_TEXTURE
	chips.Color = ColorSequence.new(Color3.fromRGB(150, 142, 132), Color3.fromRGB(96, 90, 84))
	chips.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.28 * scale), NumberSequenceKeypoint.new(1, 0.12 * scale) })
	chips.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.8, 0.2), NumberSequenceKeypoint.new(1, 1) })
	chips.LightEmission = 0
	chips.LightInfluence = 1
	chips.Lifetime = NumberRange.new(0.35, 0.6)
	chips.Speed = NumberRange.new(8 * scale, 16 * scale)
	chips.SpreadAngle = Vector2.new(50, 50)
	chips.Rotation = NumberRange.new(0, 360)
	chips.RotSpeed = NumberRange.new(-300, 300)
	chips.EmissionDirection = Enum.NormalId.Front
	chips.Acceleration = Vector3.new(0, -50, 0)
	chips.Rate = 0
	chips.Parent = emitterPart

	local dust = Instance.new("ParticleEmitter")
	dust.Texture = DUST_TEXTURE
	dust.Color = ColorSequence.new(Color3.fromRGB(165, 158, 145), Color3.fromRGB(110, 108, 96))
	dust.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.0 * scale), NumberSequenceKeypoint.new(1, 3.0 * scale) })
	dust.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) })
	dust.Lifetime = NumberRange.new(0.5, 0.9)
	dust.Speed = NumberRange.new(2, 5)
	dust.SpreadAngle = Vector2.new(70, 70)
	dust.EmissionDirection = Enum.NormalId.Front
	dust.Rotation = NumberRange.new(0, 360)
	dust.Drag = 2
	dust.LightInfluence = 1
	dust.Rate = 0
	dust.Parent = emitterPart

	chips:Emit(math.floor(8 + 4 * scale))
	dust:Emit(3)

	local light = Instance.new("PointLight")
	light.Color = glowColor
	light.Range = 8 * scale
	light.Brightness = 2.5
	light.Shadows = false
	light.Parent = emitterPart
	TweenService:Create(light, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Brightness = 0 }):Play()

	Debris:AddItem(emitterPart, LIFETIME)
end

-- Style "Crush" (the Zombie's club slam; shadow-army look): blunt force. A violet shockwave ring bursts out across the
-- wall face, a spider-web of cracks spreads from the impact (glowing shadow violet, cooling to dark scratches, the inner
-- segments first), black smoke and rubble burst off the wall, and dust rolls out along the ground at the wall's base.
-- two palettes: the base form's rot green and the awakened shadow form's violet (style "CrushShadow")
local CRUSH_PALETTES = {
	base = {
		hot = Color3.fromRGB(200, 255, 140),
		glow = Color3.fromRGB(80, 160, 30),
		smoke = { Color3.fromRGB(70, 74, 52), Color3.fromRGB(110, 112, 90) },
	},
	shadow = {
		hot = Color3.fromRGB(190, 150, 255),
		glow = Color3.fromRGB(110, 50, 230),
		smoke = { Color3.fromRGB(16, 10, 28), Color3.fromRGB(50, 26, 90) },
	},
}
local CRACK_COUNT = 7

local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Exclude

local function crush(origin, normal, scale, shadow)
	local pal = shadow and CRUSH_PALETTES.shadow or CRUSH_PALETTES.base
	local right = (-normal):Cross(Vector3.yAxis)
	right = right.Magnitude > 0.1 and right.Unit or Vector3.xAxis
	local up = normal:Cross(right).Unit
	if up.Y < 0 then
		up = -up
	end

	-- shockwave ring (a thin neon disc on the wall face, growing and fading)
	local ringCF = CFrame.lookAt(origin + normal * 0.08, origin + normal * 1.08) * CFrame.Angles(0, math.rad(90), 0)
	local ring = newPart("CrushRing", Vector3.new(0.06, 0.6 * scale, 0.6 * scale), ringCF)
	ring.Shape = Enum.PartType.Cylinder
	ring.Material = Enum.Material.Neon
	ring.Color = pal.glow
	ring.Transparency = 0.25
	TweenService:Create(ring, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.06, 6 * scale, 6 * scale),
		Transparency = 1,
	}):Play()
	Debris:AddItem(ring, 0.4)

	-- the cracks: CRACK_COUNT jagged lines of 3 segments each, spreading outward
	for i = 1, CRACK_COUNT do
		local angle = (i / CRACK_COUNT) * math.pi * 2 + (math.random() - 0.5) * 0.5
		local dir = (right * math.cos(angle) + up * math.sin(angle)).Unit
		local side = dir:Cross(normal).Unit
		local length = (1.0 + math.random() * 0.8) * scale
		local prev = origin
		for k = 1, 3 do
			local nextP = origin + dir * length * (k / 3) + side * (math.random() - 0.5) * 0.35 * scale
			local seg = nextP - prev
			local mid = (prev + nextP) / 2 + normal * 0.05
			local width = (0.14 - k * 0.03) * scale
			local p = newPart("CrushCrack", Vector3.new(width, 0.05, seg.Magnitude + width), CFrame.lookAt(mid, mid + seg, normal))
			p.Material = Enum.Material.Neon
			p.Color = pal.hot
			p.Transparency = 1
			task.delay((k - 1) * 0.03, function()
				p.Transparency = 0
				local cool = TweenService:Create(p, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					Color = pal.glow,
					Transparency = 0.3,
				})
				cool.Completed:Connect(function()
					p.Material = Enum.Material.SmoothPlastic
					p.Color = SCRATCH_COLOR
					p.Transparency = 0.3
					TweenService:Create(p, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Transparency = 1 }):Play()
				end)
				cool:Play()
			end)
			Debris:AddItem(p, LIFETIME)
			prev = nextP
		end
	end

	-- black smoke and rubble bursting off the wall
	local emitterPart = newPart("HitEmitter", Vector3.one * 0.2, CFrame.lookAt(origin + normal * 0.3, origin + normal * 1.3))
	emitterPart.Transparency = 1
	local smoke = Instance.new("ParticleEmitter")
	smoke.Texture = DUST_TEXTURE
	smoke.Color = ColorSequence.new(pal.smoke[1], pal.smoke[2])
	smoke.LightInfluence = 0
	smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2 * scale), NumberSequenceKeypoint.new(1, 3.6 * scale) })
	smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
	smoke.Lifetime = NumberRange.new(0.6, 1.0)
	smoke.Speed = NumberRange.new(4, 9)
	smoke.SpreadAngle = Vector2.new(80, 80)
	smoke.Drag = 4
	smoke.Rotation = NumberRange.new(0, 360)
	smoke.RotSpeed = NumberRange.new(-60, 60)
	smoke.EmissionDirection = Enum.NormalId.Front
	smoke.Rate = 0
	smoke.Parent = emitterPart

	local rubble = Instance.new("ParticleEmitter")
	rubble.Texture = SPARK_TEXTURE
	rubble.Color = ColorSequence.new(Color3.fromRGB(150, 142, 132), Color3.fromRGB(90, 85, 80))
	rubble.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.42 * scale), NumberSequenceKeypoint.new(1, 0.2 * scale) })
	rubble.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.85, 0.2), NumberSequenceKeypoint.new(1, 1) })
	rubble.LightEmission = 0
	rubble.LightInfluence = 1
	rubble.Lifetime = NumberRange.new(0.5, 0.8)
	rubble.Speed = NumberRange.new(8 * scale, 16 * scale)
	rubble.SpreadAngle = Vector2.new(60, 60)
	rubble.Rotation = NumberRange.new(0, 360)
	rubble.RotSpeed = NumberRange.new(-300, 300)
	rubble.EmissionDirection = Enum.NormalId.Front
	rubble.Acceleration = Vector3.new(0, -60, 0)
	rubble.Rate = 0
	rubble.Parent = emitterPart

	smoke:Emit(7)
	rubble:Emit(math.floor(10 + 4 * scale))

	local light = Instance.new("PointLight")
	light.Color = pal.glow
	light.Range = 12 * scale
	light.Brightness = 4
	light.Shadows = false
	light.Parent = emitterPart
	TweenService:Create(light, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Brightness = 0 }):Play()
	Debris:AddItem(emitterPart, LIFETIME)

	-- dust rolling out along the ground at the wall's base (find the ground just in front of the wall)
	groundParams.FilterDescendantsInstances = { fxFolder }
	local ground = Workspace:Raycast(origin + normal * 1.5, Vector3.new(0, -12, 0), groundParams)
	if ground then
		local base = newPart("HitDust", Vector3.new(4 * scale, 0.2, 0.4), CFrame.lookAt(ground.Position + normal * 0.6 + Vector3.new(0, 0.2, 0), ground.Position + normal * 1.6 + Vector3.new(0, 0.2, 0)))
		base.Transparency = 1
		local dust = Instance.new("ParticleEmitter")
		dust.Texture = DUST_TEXTURE
		dust.Color = ColorSequence.new(Color3.fromRGB(150, 144, 135), Color3.fromRGB(100, 96, 90))
		dust.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8 * scale), NumberSequenceKeypoint.new(1, 2.6 * scale) })
		dust.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1) })
		dust.Lifetime = NumberRange.new(0.6, 1.0)
		dust.Speed = NumberRange.new(4, 8)
		dust.SpreadAngle = Vector2.new(70, 10)
		dust.Drag = 3
		dust.Rotation = NumberRange.new(0, 360)
		dust.LightInfluence = 1
		dust.EmissionDirection = Enum.NormalId.Front
		dust.Rate = 0
		dust.Parent = base
		dust:Emit(8)
		Debris:AddItem(base, LIFETIME)
	end
end

-- Style "Screech" (the Crypt Bat's dive): three small, sharp gashes raked by its hind claws, then the screech: a pale
-- sound ring bursts out over the wall face and a fainter second one follows; a puff of stone dust. The shadow form's
-- gashes keep a white core (its fangs) with violet round them, and violet rings.
local SCREECH_RING = Color3.fromRGB(220, 226, 240)

local function screech(origin, normal, scale, shadow)
	local right = (-normal):Cross(Vector3.yAxis)
	right = right.Magnitude > 0.1 and right.Unit or Vector3.xAxis
	local up = Vector3.yAxis
	local ringColor = shadow and SHADOW_GLOW or SCREECH_RING
	for i = -1, 1 do
		local off = right * (i * 0.22 * scale)
		local a = origin + off + (up * 0.55 + right * 0.15) * scale
		local b = origin + off - (up * 0.45 + right * 0.05) * scale
		stroke(normal, a, b, right * 0.06 * scale, 0.08, Color3.fromRGB(245, 242, 232), shadow and SHADOW_GLOW or Color3.fromRGB(190, 182, 165), math.abs(i) * 0.02, 0.05, scale)
	end
	for k, delay in ipairs({ 0.03, 0.14 }) do
		task.delay(delay, function()
			local ringCF = CFrame.lookAt(origin + normal * (0.1 + k * 0.05), origin + normal * 1.1) * CFrame.Angles(0, math.rad(90), 0)
			local ring = newPart("ScreechRing", Vector3.new(0.05, 0.6 * scale, 0.6 * scale), ringCF)
			ring.Shape = Enum.PartType.Cylinder
			ring.Material = Enum.Material.Neon
			ring.Color = ringColor
			ring.Transparency = (k == 1) and 0.35 or 0.6
			TweenService:Create(ring, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Size = Vector3.new(0.02, (k == 1 and 5.5 or 7) * scale, (k == 1 and 5.5 or 7) * scale),
				Transparency = 1,
			}):Play()
			Debris:AddItem(ring, 0.4)
		end)
	end
	local emitterPart = newPart("HitEmitter", Vector3.one * 0.2, CFrame.lookAt(origin + normal * 0.3, origin + normal * 1.3))
	emitterPart.Transparency = 1
	local dust = Instance.new("ParticleEmitter")
	dust.Texture = DUST_TEXTURE
	dust.Color = ColorSequence.new(Color3.fromRGB(165, 158, 145))
	dust.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6 * scale), NumberSequenceKeypoint.new(1, 2 * scale) })
	dust.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1) })
	dust.Lifetime = NumberRange.new(0.4, 0.7)
	dust.Speed = NumberRange.new(2, 4)
	dust.SpreadAngle = Vector2.new(60, 60)
	dust.EmissionDirection = Enum.NormalId.Front
	dust.LightInfluence = 1
	dust.Rate = 0
	dust.Parent = emitterPart
	dust:Emit(3)
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
	-- an awakened unit's hits come as "<style>Shadow" (the shadow palette of that hit effect)
	local shadow = type(style) == "string" and style:sub(-6) == "Shadow"
	if shadow then
		style = style:sub(1, -7)
	end
	if style == "Arrow" or style == "Venom" or style == "Orbital" or style == "Marksman" then
		return -- (projectiles draw their own impact when they arrive: ArrowFx, VenomFx, OrbitalStrike, VeyrShot)
	end
	if style == "Slash" or style == "Claw" or style == "Crush" or style == "Screech" then
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
		if style == "Slash" then
			slash(at, normal, scale, shadow)
		elseif style == "Claw" then
			claw(at, normal, scale, shadow)
		elseif style == "Screech" then
			screech(at, normal, scale, shadow)
		else
			crush(at, normal, scale, shadow)
		end
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
