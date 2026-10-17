-- Builds Veyr's shadow form (the awakened form, Economy.AWAKEN_LEVEL 10+) into ServerStorage.Models.Veyr_Shadow.
-- Run AFTER build_veyr.lua (it copies ServerStorage.Models.Veyr and converts the copy), then publish_unit_models.lua.
--
-- "The marksman beyond the veil": the same cloth, armour, rig, rifle and shards, but
--   * the cloth turns void black with deep violet folds, the blackened steel blacker, the silver trim dark violet metal
--   * the bone hands turn a pale ghostly violet (they stay readable on the rifle), the skull in the hood darker still
--   * every violet light burns stronger (rune channels, shards, gems), the scope lens turns violet
--   * his trace of life: the eyes and the skull token's eyes keep their spectral blue
--   * a few dark armour fragments hang in the air beside the left pauldron and along the barrel
--   * the torn mantle ends and ribbons smoke away into wisps, a thin violet smoke curls from the muzzle
--   * the shadow layer every shadow form has: a ForceField shell, dark flames, wisps, a smoke pool, the violet outline
local ServerStorage = game:GetService("ServerStorage")
local models = ServerStorage.Models

local NAME = "Veyr_Shadow"
local source = models:FindFirstChild("Veyr")
assert(source, "run build_veyr.lua first")
local old = models:FindFirstChild(NAME)
if old then
	old:Destroy()
end

local SMOOTH = Enum.Material.SmoothPlastic
local NEON = Enum.Material.Neon
local SMOKE_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"
local FIRE_TEXTURE = "rbxasset://textures/particles/fire_main.dds"

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end
local function key(c)
	return math.floor(c.R * 255 + 0.5) .. "," .. math.floor(c.G * 255 + 0.5) .. "," .. math.floor(c.B * 255 + 0.5)
end
local VIOLET = rgb(150, 70, 255)
-- the base form's palette (build_veyr.lua) -> the shadow form's
local MAP = {
	[key(rgb(17, 17, 23))] = { color = rgb(9, 7, 14) }, -- CLOTH -> void black
	[key(rgb(38, 38, 52))] = { color = rgb(26, 15, 44) }, -- CLOTH_LIGHT -> deep violet black
	[key(rgb(66, 66, 86))] = { color = rgb(62, 28, 112) }, -- CLOTH_RIM -> violet rim
	[key(rgb(36, 36, 46))] = { color = rgb(17, 13, 26), reflect = 0.03 }, -- STEEL
	[key(rgb(22, 22, 29))] = { color = rgb(10, 8, 15), reflect = 0.02 }, -- STEEL_DARK
	[key(rgb(172, 176, 198))] = { color = rgb(96, 56, 160), reflect = 0.1 }, -- SILVER -> dark violet metal
	[key(rgb(196, 196, 204))] = { color = rgb(150, 128, 196) }, -- BONE -> ghostly violet bone
	[key(rgb(152, 152, 166))] = { color = rgb(92, 70, 136) }, -- BONE_DARK
	[key(rgb(46, 46, 58))] = { color = rgb(22, 16, 34) }, -- SKULL
	[key(rgb(20, 18, 30))] = { color = rgb(8, 6, 13) }, -- SHARD
	[key(rgb(118, 86, 255))] = { color = VIOLET }, -- ENERGY
	[key(rgb(205, 196, 255))] = { color = rgb(226, 190, 255) }, -- ENERGY_CORE
	[key(rgb(64, 40, 190))] = { color = rgb(100, 30, 220) }, -- ENERGY_DEEP
	[key(rgb(40, 90, 200))] = { color = rgb(120, 40, 230) }, -- the scope lens
}
local ACCENT = { Eye = true, TokenEye = true } -- (the eyes keep their spectral blue)

local model = source:Clone()
model.Name = NAME
model:SetAttribute("BuiltBy", "build_veyr_shadow")

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
			if m.reflect then
				d.Reflectance = m.reflect
			end
		elseif d.Material == NEON then
			d.Color = VIOLET
		end
	elseif d:IsA("Light") and not (d.Parent and d.Parent.Name == "EyeLight") then
		d.Color = VIOLET
	elseif d:IsA("ParticleEmitter") or d:IsA("Beam") or d:IsA("Trail") then
		d.Color = recolorSequence(d.Color)
	end
end
-- the runes burn stronger
for _, d in ipairs(model:GetDescendants()) do
	if d:IsA("BasePart") and d.Material == NEON and not ACCENT[d.Name] then
		d.Transparency = math.max(0, d.Transparency - 0.15)
	end
end

-- ====================================================================
-- Helpers
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
local function seq(...)
	local pts = { ... }
	local kps = {}
	for i = 1, #pts, 2 do
		table.insert(kps, NumberSequenceKeypoint.new(pts[i], pts[i + 1]))
	end
	return NumberSequence.new(kps)
end

local root = model:FindFirstChild("HumanoidRootPart")
local torso = model:FindFirstChild("Torso")
local pelvis = model:FindFirstChild("Pelvis")
local head = model:FindFirstChild("Head")
local rifle = model:FindFirstChild("RifleRoot")

-- ====================================================================
-- Suspended fragments: small dark shards of armour hanging beside the left pauldron and along the barrel
-- ====================================================================
local function fragment(to, name, cf, L)
	local w = L * 0.3
	newPart(name, Vector3.new(w, L, w * 0.6), cf, rgb(12, 9, 20), Enum.Material.Metal, to)
	local e = newPart(name .. "Edge", Vector3.new(0.025, L * 0.8, 0.025), cf * CFrame.new(w / 2, 0, 0), VIOLET, NEON, to)
	e.Transparency = 0.2
end
if torso then
	local base = torso.CFrame
	fragment(torso, "Fragment", base * CFrame.new(-1.25, 0.95, -0.15) * CFrame.Angles(0.4, 0.3, 0.9), 0.32)
	fragment(torso, "Fragment", base * CFrame.new(-1.4, 0.45, 0.2) * CFrame.Angles(-0.3, 1.1, 0.5), 0.24)
	fragment(torso, "Fragment", base * CFrame.new(-1.1, 1.35, 0.35) * CFrame.Angles(0.7, -0.4, 1.4), 0.2)
end
if rifle then
	local rf = rifle.CFrame
	fragment(rifle, "Fragment", rf * CFrame.new(0.35, 0.35, -4.4) * CFrame.Angles(0.2, 0.5, 0.7), 0.2)
	fragment(rifle, "Fragment", rf * CFrame.new(-0.32, -0.3, -5.5) * CFrame.Angles(-0.6, 0.2, 1.2), 0.16)
	-- a thin violet smoke curling from the muzzle
	local muzzle = rifle:FindFirstChild("Muzzle")
	if muzzle then
		local e = Instance.new("ParticleEmitter")
		e.Name = "MuzzleSmoke"
		e.Texture = SMOKE_TEXTURE
		e.Color = ColorSequence.new(rgb(120, 60, 230), rgb(30, 12, 60))
		e.LightEmission = 0.4
		e.LightInfluence = 0
		e.Size = seq(0, 0.08, 1, 0.35)
		e.Transparency = seq(0, 1, 0.2, 0.6, 1, 1)
		e.Lifetime = NumberRange.new(0.8, 1.3)
		e.Rate = 5
		e.Speed = NumberRange.new(0.2, 0.5)
		e.Acceleration = Vector3.new(0, 0.8, 0)
		e.Rotation = NumberRange.new(0, 360)
		e.RotSpeed = NumberRange.new(-60, 60)
		e.Parent = muzzle
	end
end

-- ====================================================================
-- The torn ends smoke away: a faint wisp from the last segment of every mantle strip and ribbon
-- ====================================================================
for _, j in ipairs(model:GetDescendants()) do
	if j:IsA("Motor6D") and j:GetAttribute("MantleIndex") then
		local hinge = j.Part1
		local isLast = true
		for _, k in ipairs(model:GetDescendants()) do
			if k:IsA("Motor6D") and k.Part0 == hinge and k:GetAttribute("MantleIndex") then
				isLast = false
				break
			end
		end
		if isLast then
			-- the cloth hangs down the hinge's -Y; find how long it is from the cloth welded to it
			local low = 0.6
			for _, w in ipairs(model:GetDescendants()) do
				if w:IsA("WeldConstraint") and w.Part0 == hinge then
					local y = hinge.CFrame:PointToObjectSpace(w.Part1.Position).Y
					low = math.max(low, -y)
				end
			end
			local src = hidden("WispEnd", Vector3.new(0.3, 0.1, 0.1), hinge.CFrame * CFrame.new(0, -low, 0), hinge)
			local e = Instance.new("ParticleEmitter")
			e.Name = "ClothWisps"
			e.Texture = SMOKE_TEXTURE
			e.Color = ColorSequence.new(rgb(30, 14, 56), rgb(10, 6, 18))
			e.LightInfluence = 0
			e.Size = seq(0, 0.15, 1, 0.5)
			e.Transparency = seq(0, 1, 0.25, 0.5, 1, 1)
			e.Lifetime = NumberRange.new(0.6, 1.1)
			e.Rate = j:GetAttribute("Thin") and 2 or 3
			e.Speed = NumberRange.new(0.2, 0.6)
			e.Acceleration = Vector3.new(0, 0.6, 0)
			e.Drag = 1
			e.Rotation = NumberRange.new(0, 360)
			e.RotSpeed = NumberRange.new(-40, 40)
			e.Parent = src
		end
	end
end

-- ====================================================================
-- The shadow layer (the same as the other shadow forms', build_malak_shadow.lua)
-- ====================================================================
-- a thin ForceField shell over the body (not the head: it would cloud the hood's opening and the eyes)
for _, src in ipairs({ torso, pelvis }) do
	if src then
		newPart(src.Name .. "Shell", src.Size + Vector3.one * 0.12, src.CFrame, rgb(120, 60, 255), Enum.Material.ForceField, src)
	end
end

-- a low smoke pool under him (he floats: it hangs just under his feet)
do
	local pool = hidden("SmokePool", Vector3.new(2.4, 0.1, 2.4), CFrame.new(root.Position.X, 0.2, root.Position.Z), root)
	local e = Instance.new("ParticleEmitter")
	e.Name = "ShadowPool"
	e.Texture = SMOKE_TEXTURE
	e.Color = ColorSequence.new(rgb(14, 8, 26), rgb(46, 22, 84))
	e.LightInfluence = 0
	e.Size = seq(0, 0.8, 0.5, 1.6, 1, 2.2)
	e.Transparency = seq(0, 1, 0.2, 0.45, 0.7, 0.7, 1, 1)
	e.Lifetime = NumberRange.new(1.4, 2.2)
	e.Rate = 8
	e.Speed = NumberRange.new(0.1, 0.4)
	e.Acceleration = Vector3.new(0, 0.2, 0)
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
	g.Size = seq(0, 0.6, 1, 1.5)
	g.Transparency = seq(0, 1, 0.3, 0.8, 1, 1)
	g.Lifetime = NumberRange.new(1.0, 1.6)
	g.Rate = 3
	g.Speed = NumberRange.new(0.2, 0.5)
	g.Rotation = NumberRange.new(0, 360)
	g.EmissionDirection = Enum.NormalId.Top
	g.Parent = pool
end

-- wisps off the shoulders, dark flames licking up off the back and the hips (behind him, clear of the rifle)
if torso then
	local src = hidden("WispSource", Vector3.new(1.2, 0.2, 0.6), torso.CFrame * CFrame.new(0, 0.7, 0.2), torso)
	local e = Instance.new("ParticleEmitter")
	e.Name = "ShadowWisps"
	e.Texture = SMOKE_TEXTURE
	e.Color = ColorSequence.new(rgb(18, 10, 32), rgb(72, 36, 130))
	e.LightInfluence = 0
	e.Size = seq(0, 0.3, 1, 0.9)
	e.Transparency = seq(0, 1, 0.25, 0.5, 1, 1)
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
	f.Size = seq(0, 0.5, 1, 0.1)
	f.Transparency = seq(0, 0.25, 1, 1)
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
	g.Size = seq(0, 0.3, 1, 0.05)
	g.Transparency = seq(0, 0.55, 1, 1)
	g.Lifetime = NumberRange.new(0.25, 0.45)
	g.Rate = rate * 0.6
	g.Speed = NumberRange.new(1, 2)
	g.EmissionDirection = Enum.NormalId.Top
	g.Parent = src
end
darkFlames(torso, Vector3.new(0.9, 0.25, 0.4), torso and torso.CFrame * CFrame.new(0, 0.55, 0.3), 10)
darkFlames(pelvis, Vector3.new(0.9, 0.25, 0.5), pelvis and pelvis.CFrame * CFrame.new(0, -0.3, 0.15), 7)

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
