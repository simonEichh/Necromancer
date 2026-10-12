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

local function flash(position, forward, damage, isGhost)
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
