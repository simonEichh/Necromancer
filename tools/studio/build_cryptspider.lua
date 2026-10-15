-- Builds the rigged Crypt Spider (Uncommon, replaced the Ghost on 2026-10-15) in its two forms:
-- ServerStorage.Models.CryptSpider (base, levels 0-9) and CryptSpider_Shadow (the awakened shadow form, level 10+).
-- A spider that nested in the crypts and grew into a human skull: low and wide, about a big dog's size, eight long
-- legs whose knees rise above its back; a small armored front body with a cluster of eight red eyes and two curved
-- bone fangs; its abdomen is a cracked human skull whose face looks up and back, one socket packed with old web,
-- threads of web to the hind legs, spinnerets, clumps of grave dirt. Base: aged bone and grey-brown chitin. Shadow:
-- black, the leg joints and the skull's sockets glowing violet, the ethereal layer and a low smoke; the red eyes stay
-- (its accent).
-- Run in Studio's command bar / via the Studio MCP execute_luau (Edit mode), then run publish_unit_models.lua.
--
-- Rig (see the Spider block in src/client/Modules/UnitAnimator.lua):
--   * front = -Z, right = +X, feet on y = 0, HumanoidRootPart at y = 1.4
--   * Motor6Ds: Root (HRP -> Thorax), Pedicel (Thorax -> Abdomen, the skull), LFang/RFang, and per leg n = 1..4
--     (1 = front) on each side L/R: <side><n>Hip (Thorax -> femur), <side><n>Knee (femur -> tibia),
--     <side><n>Ankle (tibia -> tarsus); identity rest; every joint turns about the model's own axes
--   * attributes: Rig = "Procedural", Pose = "Spider", AttackStyle = "Spit", RootHeight, Height
local ServerStorage = game:GetService("ServerStorage")
local models = ServerStorage.Models

local SMOOTH = Enum.Material.SmoothPlastic
local NEON = Enum.Material.Neon
local SMOKE_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"
local FIRE_TEXTURE = "rbxasset://textures/particles/fire_main.dds"

local function build(FORM)
	local SHADOW = FORM == "Shadow"
	local NAME = SHADOW and "CryptSpider_Shadow" or "CryptSpider"

	local old = models:FindFirstChild(NAME)
	if old then
		old:Destroy()
	end

	-- (shadow form or base form)
	local BONE = SHADOW and Color3.fromRGB(28, 26, 36) or Color3.fromRGB(206, 196, 168)
	local BONE_SHADE = SHADOW and Color3.fromRGB(40, 36, 52) or Color3.fromRGB(168, 158, 132)
	local CHITIN = SHADOW and Color3.fromRGB(16, 14, 22) or Color3.fromRGB(62, 54, 48)
	local CHITIN_DARK = SHADOW and Color3.fromRGB(10, 9, 14) or Color3.fromRGB(40, 34, 30)
	local SOCKET = SHADOW and Color3.fromRGB(100, 45, 220) or Color3.fromRGB(16, 13, 12) -- (shadow: the sockets burn violet)
	local SOCKET_MAT = SHADOW and NEON or SMOOTH
	local WEB = SHADOW and Color3.fromRGB(70, 40, 120) or Color3.fromRGB(200, 198, 190)
	local DIRT = SHADOW and Color3.fromRGB(20, 16, 26) or Color3.fromRGB(70, 56, 42)
	local JOINT = SHADOW and Color3.fromRGB(100, 45, 220) or Color3.fromRGB(150, 140, 116) -- (shadow: violet knees)
	local JOINT_MAT = SHADOW and NEON or SMOOTH
	local EYE = Color3.fromRGB(255, 40, 40) -- (red in both forms: the shadow form's accent)

	local model = Instance.new("Model")
	model.Name = NAME

	local function part(name, size, at, color, material, shape)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = typeof(at) == "CFrame" and at or CFrame.new(at)
		p.Color = color
		p.Material = material or SMOOTH
		if shape then
			p.Shape = shape
		end
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Massless = true
		p.Anchored = false
		p.Parent = model
		return p
	end

	local function motor(name, p0, p1, jointPos)
		local m = Instance.new("Motor6D")
		m.Name = name
		m.Part0 = p0
		m.Part1 = p1
		m.C0 = p0.CFrame:Inverse() * CFrame.new(jointPos)
		m.C1 = p1.CFrame:Inverse() * CFrame.new(jointPos)
		m.Parent = p1
		return m
	end

	local function weld(p0, p1)
		local w = Instance.new("WeldConstraint")
		w.Part0 = p0
		w.Part1 = p1
		w.Parent = p1
		return w
	end

	local function deco(to, name, size, at, color, material, shape)
		local p = part(name, size, at, color, material, shape)
		weld(to, p)
		return p
	end

	-- a part stretched between two points (w x h cross-section), welded to `to` unless it is nil
	local function bar(name, a, b, w, h, color, to, material)
		local up = math.abs((b - a).Unit.Y) > 0.95 and Vector3.xAxis or Vector3.yAxis
		local p = part(name, Vector3.new(w, h or w, (b - a).Magnitude), CFrame.lookAt((a + b) / 2, b, up), color, material)
		if to then
			weld(to, p)
		end
		return p
	end

	-- ── Front body: armored, eight red eyes, two fangs ───────────
	local root = part("HumanoidRootPart", Vector3.new(1.2, 0.4, 1.6), Vector3.new(0, 1.4, 0), CHITIN)
	root.Transparency = 1
	model.PrimaryPart = root

	local thorax = part("Thorax", Vector3.new(0.92, 0.46, 0.95), Vector3.new(0, 1.38, -0.32), CHITIN)
	motor("Root", root, thorax, Vector3.new(0, 1.4, 0))
	deco(thorax, "Carapace", Vector3.new(0.8, 0.16, 0.85), CFrame.new(0, 1.66, -0.34) * CFrame.Angles(0.08, 0, 0), CHITIN_DARK)
	deco(thorax, "Ridge", Vector3.new(0.12, 0.1, 0.8), Vector3.new(0, 1.77, -0.32), BONE_SHADE)
	deco(thorax, "Head", Vector3.new(0.6, 0.38, 0.32), Vector3.new(0, 1.42, -0.86), CHITIN)
	-- the eyes: two big ones in front, six small ones in rows above and beside them
	for _, e in ipairs({
		{ -0.1, 1.5, 0.11 }, { 0.1, 1.5, 0.11 },
		{ -0.24, 1.55, 0.06 }, { 0.24, 1.55, 0.06 }, { -0.16, 1.62, 0.055 }, { 0.16, 1.62, 0.055 },
		{ -0.06, 1.63, 0.05 }, { 0.06, 1.63, 0.05 },
	}) do
		deco(thorax, "Eye", Vector3.one * e[3], Vector3.new(e[1], e[2], -1.02), EYE, NEON, Enum.PartType.Ball)
	end
	local eyeLight = Instance.new("PointLight")
	eyeLight.Color = EYE
	eyeLight.Range = 3
	eyeLight.Brightness = 0.8
	eyeLight.Shadows = false
	eyeLight.Parent = thorax
	for _, x in ipairs({ -1, 1 }) do
		local fangRoot = Vector3.new(x * 0.13, 1.28, -0.98)
		local fang = bar(x < 0 and "LFangPart" or "RFangPart", fangRoot, fangRoot + Vector3.new(-x * 0.06, -0.3, -0.1), 0.08, 0.08, BONE)
		motor(x < 0 and "LFang" or "RFang", thorax, fang, fangRoot)
		bar("FangTip", fangRoot + Vector3.new(-x * 0.06, -0.3, -0.1), fangRoot + Vector3.new(-x * 0.1, -0.38, -0.02), 0.05, 0.05, BONE, fang)
	end

	-- ── The abdomen: a cracked human skull, its face looking up and back ──
	local skullCF = CFrame.new(0, 1.82, 0.82) * CFrame.Angles(-0.55, 0, 0) -- (the face is its +Z side, tipped up)
	local abdomen = part("Abdomen", Vector3.new(1.3, 1.15, 1.35), skullCF, BONE)
	motor("Pedicel", thorax, abdomen, Vector3.new(0, 1.45, 0.12))
	local function onSkull(name, size, offset, color, material, shape)
		return deco(abdomen, name, size, skullCF * offset, color, material, shape)
	end
	onSkull("Cranium", Vector3.new(1.18, 0.3, 1.2), CFrame.new(0, 0.66, -0.05), BONE)
	onSkull("Brow", Vector3.new(1.2, 0.16, 0.22), CFrame.new(0, 0.22, 0.66), BONE_SHADE)
	for _, x in ipairs({ -1, 1 }) do
		onSkull("Socket", Vector3.new(0.36, 0.3, 0.08), CFrame.new(x * 0.28, 0.02, 0.68), SOCKET, SOCKET_MAT)
		onSkull("Cheekbone", Vector3.new(0.2, 0.16, 0.3), CFrame.new(x * 0.56, -0.18, 0.56), BONE_SHADE)
	end
	onSkull("Nose", Vector3.new(0.14, 0.2, 0.08), CFrame.new(0, -0.22, 0.68), SOCKET, SOCKET_MAT)
	onSkull("Jaw", Vector3.new(0.84, 0.18, 0.5), CFrame.new(0, -0.6, 0.45), BONE_SHADE)
	for i = 0, 5 do
		if i ~= 2 then
			onSkull("Tooth", Vector3.new(0.09, 0.12, 0.06), CFrame.new(-0.25 + i * 0.1, -0.45, 0.69), BONE)
		end
	end
	-- cracks over the cranium
	for _, c in ipairs({ { Vector3.new(0.2, 0.82, 0.3), Vector3.new(0.4, 0.5, 0.62) }, { Vector3.new(-0.3, 0.8, -0.2), Vector3.new(-0.5, 0.4, 0.2) } }) do
		local a, b = skullCF * c[1], skullCF * c[2]
		bar("Crack", a, b, 0.04, 0.04, SHADOW and Color3.fromRGB(100, 45, 220) or Color3.fromRGB(30, 26, 22), abdomen, SHADOW and NEON or SMOOTH)
	end
	-- old web packed in the left socket, spinnerets at the back, grave dirt in the creases
	for k = -1, 1 do
		local a = skullCF * Vector3.new(-0.42, 0.02 + k * 0.08, 0.73)
		local b = skullCF * Vector3.new(-0.14, 0.02 - k * 0.08, 0.73)
		bar("SocketWeb", a, b, 0.02, 0.02, WEB, abdomen)
	end
	for _, x in ipairs({ -0.12, 0, 0.12 }) do
		onSkull("Spinneret", Vector3.new(0.08, 0.08, 0.2), CFrame.new(x, -0.55, -0.6) * CFrame.Angles(0.6, 0, 0), CHITIN)
	end
	for _, d in ipairs({ { 0.45, 0.55, -0.4 }, { -0.5, 0.45, -0.3 }, { 0.1, -0.5, -0.55 } }) do
		onSkull("Dirt", Vector3.new(0.26, 0.12, 0.22), CFrame.new(d[1], d[2], d[3]) * CFrame.Angles(0.3, d[1], 0.2), DIRT)
	end

	-- ── Legs: four per side, long bone segments, the knees above the back ──
	-- per leg: root z on the thorax, the fore/aft lean (front legs reach forward, hind legs back)
	local LEGS = { { -0.62, -0.75 }, { -0.4, -0.25 }, { -0.16, 0.2 }, { 0.08, 0.65 } }
	local hindTips = {}
	for n, leg in ipairs(LEGS) do
		for _, side in ipairs({ -1, 1 }) do
			local s = side < 0 and "L" or "R"
			local z, lean = leg[1], leg[2]
			local hip = Vector3.new(side * 0.44, 1.42, z)
			local knee = Vector3.new(side * 1.05, 2.15, z + lean * 0.55)
			local ankle = Vector3.new(side * 1.7, 0.75, z + lean * 1.1)
			local tip = Vector3.new(side * 1.85, 0.02, z + lean * 1.3)
			local femur = bar(s .. n .. "Femur", hip, knee, 0.14, 0.14, BONE)
			motor(s .. n .. "Hip", thorax, femur, hip)
			bar("FemurPlate", hip:Lerp(knee, 0.2), hip:Lerp(knee, 0.75), 0.18, 0.12, CHITIN, femur)
			deco(femur, "KneeKnob", Vector3.one * 0.2, knee, JOINT, JOINT_MAT, Enum.PartType.Ball)
			local tibia = bar(s .. n .. "Tibia", knee, ankle, 0.11, 0.11, BONE)
			motor(s .. n .. "Knee", femur, tibia, knee)
			bar("TibiaPlate", knee:Lerp(ankle, 0.1), knee:Lerp(ankle, 0.5), 0.14, 0.09, CHITIN_DARK, tibia)
			deco(tibia, "AnkleKnob", Vector3.one * 0.14, ankle, JOINT, JOINT_MAT, Enum.PartType.Ball)
			local tarsus = bar(s .. n .. "Tarsus", ankle, tip, 0.08, 0.08, BONE_SHADE)
			motor(s .. n .. "Ankle", tibia, tarsus, ankle)
			if n == 4 then
				table.insert(hindTips, { tibia = tibia, point = knee:Lerp(ankle, 0.4) })
			end
		end
	end
	-- threads of web from the skull to the hind legs
	for _, h in ipairs(hindTips) do
		local from = skullCF * Vector3.new(h.point.X > 0 and 0.55 or -0.55, -0.3, -0.3)
		bar("WebThread", from, h.point, 0.02, 0.02, WEB, abdomen)
	end

	-- ── Shadow form extras ────────────────────────────────────────
	if SHADOW then
		local function emitter(src, props)
			local e = Instance.new("ParticleEmitter")
			for k, v in pairs(props) do
				e[k] = v
			end
			e.Parent = src
			return e
		end
		-- a wide, low smoke it skitters through
		local pool = part("SmokePool", Vector3.new(3.2, 0.1, 2.8), Vector3.new(0, 0.15, 0.1), Color3.new())
		pool.Transparency = 1
		weld(root, pool)
		emitter(pool, {
			Name = "ShadowPool", Texture = SMOKE_TEXTURE, LightInfluence = 0,
			Color = ColorSequence.new(Color3.fromRGB(14, 8, 26), Color3.fromRGB(46, 22, 84)),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(0.5, 1.6), NumberSequenceKeypoint.new(1, 2.2) }),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0.35), NumberSequenceKeypoint.new(0.7, 0.6), NumberSequenceKeypoint.new(1, 1) }),
			Lifetime = NumberRange.new(1.2, 2.0), Rate = 10, Speed = NumberRange.new(0.1, 0.4), Acceleration = Vector3.new(0, 0.2, 0),
			Drag = 1, Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-25, 25), EmissionDirection = Enum.NormalId.Top,
		})
		-- dark flames off the skull
		local src = deco(abdomen, "FxSource", Vector3.new(0.9, 0.2, 0.9), skullCF * CFrame.new(0, 0.75, 0), Color3.new())
		src.Transparency = 1
		emitter(src, {
			Name = "ShadowFlames", Texture = FIRE_TEXTURE, LightEmission = 0, LightInfluence = 0,
			Color = ColorSequence.new(Color3.fromRGB(40, 16, 80), Color3.fromRGB(8, 4, 16)),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0.1) }),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 1) }),
			Lifetime = NumberRange.new(0.45, 0.8), Rate = 12, Speed = NumberRange.new(1.5, 3), Acceleration = Vector3.new(0, 2, 0),
			Rotation = NumberRange.new(-15, 15), SpreadAngle = Vector2.new(15, 15), EmissionDirection = Enum.NormalId.Top,
		})
		emitter(src, {
			Name = "ShadowFlameGlow", Texture = FIRE_TEXTURE, LightEmission = 1, LightInfluence = 0,
			Color = ColorSequence.new(Color3.fromRGB(120, 60, 255)),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0.05) }),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) }),
			Lifetime = NumberRange.new(0.25, 0.45), Rate = 7, Speed = NumberRange.new(1, 2), EmissionDirection = Enum.NormalId.Top,
		})
		-- the ForceField shimmer over the body and the skull
		for _, name in ipairs({ "Thorax", "Abdomen" }) do
			local p = model:FindFirstChild(name)
			local sh = part(name .. "Shell", p.Size + Vector3.one * 0.12, p.CFrame, Color3.fromRGB(120, 60, 255), Enum.Material.ForceField)
			sh.CastShadow = false
			weld(p, sh)
		end
		-- the outline with its faint violet fill
		local h = Instance.new("Highlight")
		h.Name = "ShadowOutline"
		h.FillColor = Color3.fromRGB(120, 60, 255)
		h.FillTransparency = 0.92
		h.OutlineColor = Color3.fromRGB(150, 95, 255)
		h.OutlineTransparency = 0.55
		h.DepthMode = Enum.HighlightDepthMode.Occluded
		h.Parent = model
	end

	model:SetAttribute("Rig", "Procedural")
	model:SetAttribute("Pose", "Spider")
	model:SetAttribute("AttackStyle", "Spit")
	model:SetAttribute("RootHeight", 1.4)
	model:SetAttribute("Height", 2.6)
	model.Parent = models

	local parts, joints = 0, 0
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then parts += 1 end
		if d:IsA("Motor6D") then joints += 1 end
	end
	return NAME .. ": " .. parts .. " parts, " .. joints .. " joints"
end

return build("Base") .. " | " .. build("Shadow")
