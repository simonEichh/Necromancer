-- Builds Malak's shadow form (the awakened form, Economy.AWAKEN_LEVEL 10+) into ServerStorage.Models.Malak_Shadow.
-- Run AFTER build_malak.lua (it copies ServerStorage.Models.Malak and converts the copy), then publish_unit_models.lua.
--
-- "The corrupted envoy" (picked 2026-10-16): the same armour, rig and drone, but
--   * the black chrome turns matte void black, the undersuit near black
--   * the silver edges and trims become dark violet metal, the coat lining a deeper violet
--   * every cold white-blue light (seams, hologram, drone, thrusters) turns violet
--   * his trace of life: the helmet slit keeps its cold white-blue light
--   * the heel thrusters breathe shadow smoke instead of jet flame
--   * the shadow layer every shadow form has: a ForceField shell, dark flames, wisps, a smoke pool, the violet outline
local ServerStorage = game:GetService("ServerStorage")
local models = ServerStorage.Models

local NAME = "Malak_Shadow"
local source = models:FindFirstChild("Malak")
assert(source, "run build_malak.lua first")
local old = models:FindFirstChild(NAME)
if old then
	old:Destroy()
end

local SMOOTH = Enum.Material.SmoothPlastic
local NEON = Enum.Material.Neon
local SMOKE_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"
local FIRE_TEXTURE = "rbxasset://textures/particles/fire_main.dds"

-- the base form's palette (build_malak.lua) -> the shadow form's
local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end
local function key(c)
	return math.floor(c.R * 255 + 0.5) .. "," .. math.floor(c.G * 255 + 0.5) .. "," .. math.floor(c.B * 255 + 0.5)
end
local VIOLET = rgb(140, 70, 255)
local MAP = {
	[key(rgb(22, 22, 28))] = { color = rgb(14, 12, 20), reflect = 0.04 }, -- CHROME -> void black
	[key(rgb(42, 42, 52))] = { color = rgb(26, 22, 36), reflect = 0.04 }, -- CHROME_LIGHT
	[key(rgb(14, 14, 18))] = { color = rgb(9, 8, 13) }, -- UNDERSUIT
	[key(rgb(176, 180, 196))] = { color = rgb(74, 48, 128), reflect = 0.12 }, -- SILVER -> dark violet metal (as neon he glowed all over)
	[key(rgb(110, 114, 130))] = { color = rgb(62, 34, 118), reflect = 0 }, -- SILVER_DARK
	[key(rgb(44, 30, 74))] = { color = rgb(52, 20, 100) }, -- LINING
	[key(rgb(28, 20, 50))] = { color = rgb(30, 12, 60) }, -- LINING_DARK
	[key(rgb(165, 180, 255))] = { color = rgb(150, 75, 255) }, -- GLOW
	[key(rgb(235, 240, 255))] = { color = rgb(215, 180, 255) }, -- GLOW_CORE
	[key(rgb(96, 104, 230))] = { color = rgb(90, 30, 210) }, -- GLOW_DEEP
}
local ACCENT = { Slit = true, SlitGlow = true, SlitTop = true } -- (the helmet slit keeps the cold white-blue)

local model = source:Clone()
model.Name = NAME

local function recolorSequence(seq)
	local kps = {}
	for _, kp in ipairs(seq.Keypoints) do
		local m = MAP[key(kp.Value)]
		table.insert(kps, ColorSequenceKeypoint.new(kp.Time, m and m.color or kp.Value))
	end
	return ColorSequence.new(kps)
end

for _, d in ipairs(model:GetDescendants()) do
	if d:IsA("BasePart") and not ACCENT[d.Name] then
		local m = MAP[key(d.Color)]
		if m then
			d.Color = m.color
			if m.material then
				d.Material = m.material
			end
			if m.reflect then
				d.Reflectance = m.reflect
			end
		elseif d.Material == NEON then
			d.Color = VIOLET
		end
	elseif d:IsA("Light") and not ACCENT[d.Parent and d.Parent.Name or ""] then
		d.Color = rgb(150, 75, 255)
	elseif d:IsA("ParticleEmitter") or d:IsA("Beam") or d:IsA("Trail") then
		d.Color = recolorSequence(d.Color)
	end
end

-- the thrusters breathe shadow smoke: the jet plumes go, a dark smoke stream falls from each heel
for _, d in ipairs(model:GetDescendants()) do
	if d:IsA("BasePart") and (d.Name == "ThrusterPlume" or d.Name == "ThrusterPlumeOuter") then
		d.Transparency = 1
	elseif d:IsA("ParticleEmitter") and d.Name == "ThrusterFlame" then
		d.Name = "ThrusterSmoke"
		d.Texture = SMOKE_TEXTURE
		d.Color = ColorSequence.new(rgb(40, 18, 80), rgb(10, 6, 20))
		d.LightEmission = 0
		d.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(1, 0.6) })
		d.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
		d.Lifetime = NumberRange.new(0.5, 0.9)
		d.Rate = 18
		d.Speed = NumberRange.new(1, 2)
		d.Drag = 2
		d.Rotation = NumberRange.new(0, 360)
		d.RotSpeed = NumberRange.new(-40, 40)
		d.SpreadAngle = Vector2.new(12, 12)
	end
end

-- ====================================================================
-- The shadow layer (the same as the other shadow forms', build_ghoul.lua / build_zombie.lua)
-- ====================================================================
local function newPart(name, size, cf, color, material, to)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or SMOOTH
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = false
	p.Anchored = false
	p.Parent = model
	local w = Instance.new("WeldConstraint")
	w.Part0 = to
	w.Part1 = p
	w.Parent = p
	return p
end
local function hidden(name, size, cf, to)
	local p = newPart(name, size, cf, Color3.new(), SMOOTH, to)
	p.Transparency = 1
	return p
end

local root = model:FindFirstChild("HumanoidRootPart")
local torso = model:FindFirstChild("Torso")
local pelvis = model:FindFirstChild("Pelvis")
local head = model:FindFirstChild("Head")

-- a ForceField shell over the body
for _, src in ipairs({ torso, pelvis, head }) do
	if src then
		newPart(src.Name .. "Shell", src.Size + Vector3.one * 0.12, src.CFrame, rgb(120, 60, 255), Enum.Material.ForceField, src)
	end
end

-- a smoke pool under him (he hovers: it hangs just under his soles)
do
	local pool = hidden("SmokePool", Vector3.new(2.4, 0.1, 2.4), CFrame.new(root.Position.X, 0.4, root.Position.Z), root)
	local e = Instance.new("ParticleEmitter")
	e.Name = "ShadowPool"
	e.Texture = SMOKE_TEXTURE
	e.Color = ColorSequence.new(rgb(14, 8, 26), rgb(46, 22, 84))
	e.LightInfluence = 0
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(0.5, 1.6), NumberSequenceKeypoint.new(1, 2.2) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0.4), NumberSequenceKeypoint.new(0.7, 0.65), NumberSequenceKeypoint.new(1, 1) })
	e.Lifetime = NumberRange.new(1.4, 2.2)
	e.Rate = 8
	e.Speed = NumberRange.new(0.1, 0.4)
	e.Acceleration = Vector3.new(0, 0.3, 0)
	e.Drag = 1
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-25, 25)
	e.EmissionDirection = Enum.NormalId.Top
	e.Parent = pool
	local g = Instance.new("ParticleEmitter")
	g.Name = "ShadowPoolGlow"
	g.Texture = SMOKE_TEXTURE
	g.Color = ColorSequence.new(rgb(110, 50, 230))
	g.LightEmission = 1
	g.LightInfluence = 0
	g.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1.5) })
	g.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.78), NumberSequenceKeypoint.new(1, 1) })
	g.Lifetime = NumberRange.new(1.0, 1.6)
	g.Rate = 3
	g.Speed = NumberRange.new(0.2, 0.5)
	g.Rotation = NumberRange.new(0, 360)
	g.EmissionDirection = Enum.NormalId.Top
	g.Parent = pool
end

-- wisps off the shoulders and dark flames licking up off the chest and the coat
if torso then
	local src = hidden("WispSource", Vector3.new(1.2, 0.2, 0.6), torso.CFrame * CFrame.new(0, 0.7, 0), torso)
	local e = Instance.new("ParticleEmitter")
	e.Name = "ShadowWisps"
	e.Texture = SMOKE_TEXTURE
	e.Color = ColorSequence.new(rgb(18, 10, 32), rgb(72, 36, 130))
	e.LightInfluence = 0
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0.9) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.25, 0.45), NumberSequenceKeypoint.new(1, 1) })
	e.Lifetime = NumberRange.new(0.8, 1.3)
	e.Rate = 4
	e.Speed = NumberRange.new(0.4, 1.0)
	e.Acceleration = Vector3.new(0, 1.5, 0)
	e.Drag = 1.5
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-40, 40)
	e.SpreadAngle = Vector2.new(30, 30)
	e.EmissionDirection = Enum.NormalId.Top
	e.Parent = src
end
local function darkFlames(to, size, cf, rate)
	if not to then
		return
	end
	local src = hidden("FlameSource", size, cf, to)
	local f = Instance.new("ParticleEmitter")
	f.Name = "ShadowFlames"
	f.Texture = FIRE_TEXTURE
	f.Color = ColorSequence.new(rgb(40, 16, 80), rgb(8, 4, 16))
	f.LightEmission = 0
	f.LightInfluence = 0
	f.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0.1) })
	f.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 1) })
	f.Lifetime = NumberRange.new(0.45, 0.8)
	f.Rate = rate
	f.Speed = NumberRange.new(1.5, 3)
	f.Acceleration = Vector3.new(0, 2, 0)
	f.Rotation = NumberRange.new(-15, 15)
	f.SpreadAngle = Vector2.new(15, 15)
	f.EmissionDirection = Enum.NormalId.Top
	f.Parent = src
	local g = Instance.new("ParticleEmitter")
	g.Name = "ShadowFlameGlow"
	g.Texture = FIRE_TEXTURE
	g.Color = ColorSequence.new(rgb(120, 60, 255))
	g.LightEmission = 1
	g.LightInfluence = 0
	g.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0.05) })
	g.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) })
	g.Lifetime = NumberRange.new(0.25, 0.45)
	g.Rate = rate * 0.6
	g.Speed = NumberRange.new(1, 2)
	g.EmissionDirection = Enum.NormalId.Top
	g.Parent = src
end
darkFlames(torso, Vector3.new(1.0, 0.25, 0.5), torso and torso.CFrame * CFrame.new(0, 0.5, 0), 12)
darkFlames(pelvis, Vector3.new(1.0, 0.25, 0.6), pelvis and pelvis.CFrame * CFrame.new(0, -0.3, 0), 8)

do
	local h = Instance.new("Highlight")
	h.Name = "ShadowOutline"
	h.FillColor = rgb(120, 60, 255)
	h.FillTransparency = 0.92
	h.OutlineColor = rgb(150, 95, 255)
	h.OutlineTransparency = 0.55
	h.DepthMode = Enum.HighlightDepthMode.Occluded
	h.Parent = model
end

model.Parent = models
local parts = 0
for _, d in ipairs(model:GetDescendants()) do
	if d:IsA("BasePart") then
		parts += 1
	end
end
return NAME .. ": " .. parts .. " parts"
