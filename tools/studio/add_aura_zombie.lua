-- Example per-unit aura: a Dragon Ball style purple power-up aura on ServerStorage.Models.Zombie.
-- Run in Studio's command bar / via the Studio MCP execute_luau (Edit mode). Safe to re-run
-- (removes the old aura first). Everything lives inside the model, so it follows the unit
-- everywhere and scales with the rig. Delete the "Aura*" children to remove it again.
--
-- Layers: rising flame tongues + hot sparks (ParticleEmitters spread over the whole body),
-- a pale-violet core flicker, a purple point light and a Highlight tint/outline.
local zombie = game:GetService("ServerStorage").Models.Zombie

for _, c in ipairs(zombie:GetDescendants()) do
	if c.Name:sub(1, 4) == "Aura" then
		c:Destroy()
	end
end

local root = zombie.HumanoidRootPart

-- invisible volume the particles are emitted from (covers the body, feet to head)
local volume = Instance.new("Part")
volume.Name = "AuraVolume"
volume.Size = Vector3.new(2.4, 4.6, 1.8)
volume.CFrame = root.CFrame * CFrame.new(0, 0.3, 0)
volume.Transparency = 1
volume.CanCollide = false
volume.CanQuery = false
volume.CanTouch = false
volume.Massless = true
volume.Anchored = false
volume.Parent = zombie
local weld = Instance.new("WeldConstraint")
weld.Part0 = root
weld.Part1 = volume
weld.Parent = volume

local function seq(...)
	local keys = {}
	for _, k in ipairs({ ... }) do
		table.insert(keys, NumberSequenceKeypoint.new(k[1], k[2]))
	end
	return NumberSequence.new(keys)
end

-- big flame tongues licking upwards
local flame = Instance.new("ParticleEmitter")
flame.Name = "AuraFlame"
flame.Texture = "rbxasset://textures/particles/fire_main.dds"
flame.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(215, 140, 255)),
	ColorSequenceKeypoint.new(0.45, Color3.fromRGB(150, 50, 245)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(60, 10, 130)),
})
flame.Size = seq({ 0, 1.2 }, { 0.3, 2.4 }, { 1, 0 })
flame.Transparency = seq({ 0, 0.15 }, { 0.6, 0.45 }, { 1, 1 })
flame.LightEmission = 1
flame.Lifetime = NumberRange.new(0.7, 1.2)
flame.Rate = 70
flame.Speed = NumberRange.new(7, 12)
flame.SpreadAngle = Vector2.new(12, 12)
flame.EmissionDirection = Enum.NormalId.Top
flame.Shape = Enum.ParticleEmitterShape.Box
flame.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
flame.Rotation = NumberRange.new(-12, 12)
flame.RotSpeed = NumberRange.new(-20, 20)
flame.Parent = volume

-- hot white-violet core flicker close to the body
local core = Instance.new("ParticleEmitter")
core.Name = "AuraCore"
core.Texture = "rbxasset://textures/particles/fire_main.dds"
core.Color = ColorSequence.new(Color3.fromRGB(245, 225, 255), Color3.fromRGB(190, 110, 255))
core.Size = seq({ 0, 1.6 }, { 0.5, 2.2 }, { 1, 0 })
core.Transparency = seq({ 0, 0.5 }, { 0.5, 0.65 }, { 1, 1 })
core.LightEmission = 1
core.Lifetime = NumberRange.new(0.3, 0.55)
core.Rate = 30
core.Speed = NumberRange.new(2, 4)
core.EmissionDirection = Enum.NormalId.Top
core.Shape = Enum.ParticleEmitterShape.Box
core.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
core.Parent = volume

-- sparks flying off
local sparks = Instance.new("ParticleEmitter")
sparks.Name = "AuraSparks"
sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
sparks.Color = ColorSequence.new(Color3.fromRGB(255, 240, 255), Color3.fromRGB(190, 110, 255))
sparks.Size = seq({ 0, 0.5 }, { 0.5, 0.35 }, { 1, 0 })
sparks.Transparency = seq({ 0, 0 }, { 0.8, 0.2 }, { 1, 1 })
sparks.LightEmission = 1
sparks.Lifetime = NumberRange.new(0.8, 1.6)
sparks.Rate = 22
sparks.Speed = NumberRange.new(6, 14)
sparks.SpreadAngle = Vector2.new(35, 35)
sparks.Acceleration = Vector3.new(0, 6, 0)
sparks.EmissionDirection = Enum.NormalId.Top
sparks.Shape = Enum.ParticleEmitterShape.Box
sparks.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
sparks.Parent = volume

-- purple glow cast on the ground and nearby units (no shadows, see CLAUDE.md)
local light = Instance.new("PointLight")
light.Name = "AuraLight"
light.Color = Color3.fromRGB(160, 70, 255)
light.Brightness = 3
light.Range = 16
light.Shadows = false
light.Parent = volume

-- soft tint and outline around the whole body
local hl = Instance.new("Highlight")
hl.Name = "AuraHighlight"
hl.FillColor = Color3.fromRGB(150, 60, 255)
hl.FillTransparency = 0.72
hl.OutlineColor = Color3.fromRGB(220, 160, 255)
hl.OutlineTransparency = 0.35
hl.DepthMode = Enum.HighlightDepthMode.Occluded
hl.Parent = zombie

return "aura added to Zombie"
