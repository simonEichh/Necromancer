-- Builds the rigged Hollow Archer (Uncommon, replaced the Goblin on 2026-10-15) in its two forms:
-- ServerStorage.Models.HollowArcher (base, levels 0-9) and HollowArcher_Shadow (the awakened shadow form, level 10+).
-- A dead archer who still keeps his post: tall, gaunt and stooped, a deep moss-green hood with a long pointed tip, only
-- the lower half of a dried, lipless face and two small pale green eyes showing in its shadow; a cracked leather
-- jerkin, a bracer, a knife and a pouch on the belt, a ragged cloak down the back, bandaged legs and worn boots; a quiver
-- of bone arrows with black feathers over the right shoulder; a huge longbow of two lashed bones and sinew in the left
-- hand. Shadow form: black, the cloak's hem smoking, an obsidian bow with a violet string, the ethereal layer
-- (shimmer, dark flames, outline); the pale green eyes are its accent.
-- Run in Studio's command bar / via the Studio MCP execute_luau (Edit mode), then run publish_unit_models.lua.
--
-- Rig (see the Bow block in src/client/Modules/UnitAnimator.lua, which places the hands with IK; its ARCHER table
-- must match these numbers):
--   * front = -Z, right = +X, feet on y = 0, HumanoidRootPart at y = 2.6
--   * Motor6Ds Root/Waist/Neck, LShoulder/LElbow/LWrist (the bow hand), RShoulder/RElbow, LHip/LKnee/RHip/RKnee;
--     shoulders at (+-0.6, 3.85, 0), upper arm 0.85, forearm 0.85 (the wrists at y 2.15), identity rest
--   * the bow is welded to LHand (the LWrist part), its grip at the hand centre; attachments on LHand: TipTop,
--     TipBottom and Nock (the string's middle, 0.34 behind the grip); the string is two Beams through Nock, which the
--     client moves back as it draws
--   * attributes: Rig = "Procedural", AttackStyle = "Bow", RootHeight, Height
local ServerStorage = game:GetService("ServerStorage")
local models = ServerStorage.Models

local SMOOTH = Enum.Material.SmoothPlastic
local NEON = Enum.Material.Neon
local SMOKE_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"
local FIRE_TEXTURE = "rbxasset://textures/particles/fire_main.dds"

local function build(FORM)
	local SHADOW = FORM == "Shadow"
	local NAME = SHADOW and "HollowArcher_Shadow" or "HollowArcher"

	local old = models:FindFirstChild(NAME)
	if old then
		old:Destroy()
	end

	-- (shadow form or base form)
	local HOOD = SHADOW and Color3.fromRGB(20, 18, 26) or Color3.fromRGB(52, 66, 44)
	local HOOD_DARK = SHADOW and Color3.fromRGB(13, 12, 17) or Color3.fromRGB(37, 47, 31)
	local LEATHER = SHADOW and Color3.fromRGB(30, 26, 36) or Color3.fromRGB(88, 62, 42)
	local LEATHER_DARK = SHADOW and Color3.fromRGB(20, 18, 24) or Color3.fromRGB(54, 38, 28)
	local SKIN = SHADOW and Color3.fromRGB(26, 24, 32) or Color3.fromRGB(128, 130, 118)
	local SKIN_DARK = SHADOW and Color3.fromRGB(18, 16, 22) or Color3.fromRGB(96, 98, 88)
	local BONE = SHADOW and Color3.fromRGB(34, 30, 44) or Color3.fromRGB(214, 204, 176) -- the bow, the arrows
	local WRAP = SHADOW and Color3.fromRGB(28, 24, 34) or Color3.fromRGB(150, 140, 118)
	local BOOT = SHADOW and Color3.fromRGB(16, 14, 20) or Color3.fromRGB(46, 36, 30)
	local FEATHER = SHADOW and Color3.fromRGB(26, 14, 44) or Color3.fromRGB(24, 22, 24)
	local STRING = SHADOW and Color3.fromRGB(150, 95, 255) or Color3.fromRGB(220, 210, 180)
	local EYE = Color3.fromRGB(170, 255, 170) -- (pale green in both forms: the shadow form's accent)
	local SHADE = Color3.fromRGB(6, 5, 8) -- the dark inside the hood

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

	-- ── Core ──────────────────────────────────────────────────────
	local root = part("HumanoidRootPart", Vector3.new(1.0, 0.4, 0.6), Vector3.new(0, 2.6, 0), LEATHER)
	root.Transparency = 1
	model.PrimaryPart = root

	local pelvis = part("Pelvis", Vector3.new(0.8, 0.35, 0.45), Vector3.new(0, 2.55, 0), LEATHER_DARK)
	motor("Root", root, pelvis, Vector3.new(0, 2.6, 0))
	deco(pelvis, "Belt", Vector3.new(0.92, 0.12, 0.52), Vector3.new(0, 2.74, 0), LEATHER_DARK, Enum.Material.Leather)
	deco(pelvis, "Buckle", Vector3.new(0.14, 0.14, 0.04), Vector3.new(-0.1, 2.74, -0.27), BONE)
	deco(pelvis, "Pouch", Vector3.new(0.22, 0.24, 0.12), Vector3.new(-0.32, 2.58, -0.27), LEATHER, Enum.Material.Leather)
	deco(pelvis, "Sheath", Vector3.new(0.1, 0.46, 0.14), CFrame.new(0.47, 2.5, -0.06) * CFrame.Angles(0, 0, 0.15), LEATHER_DARK, Enum.Material.Leather)
	deco(pelvis, "KnifeHandle", Vector3.new(0.07, 0.2, 0.07), CFrame.new(0.44, 2.82, -0.06) * CFrame.Angles(0, 0, 0.15), BONE)

	-- ── Torso: a cracked leather jerkin over a starved chest ───────
	local torso = part("Torso", Vector3.new(0.9, 1.25, 0.5), Vector3.new(0, 3.33, 0), LEATHER, Enum.Material.Leather)
	motor("Waist", pelvis, torso, Vector3.new(0, 2.72, 0))
	deco(torso, "Collar", Vector3.new(0.34, 0.2, 0.32), Vector3.new(0, 4.0, 0), SKIN_DARK)
	for i = 0, 3 do
		-- the lacing down the front
		deco(torso, "Lace", Vector3.new(0.26, 0.04, 0.04), CFrame.new(0, 3.75 - i * 0.18, -0.26) * CFrame.Angles(0, 0, (i % 2 == 0) and 0.4 or -0.4), LEATHER_DARK)
	end
	bar("Crack", Vector3.new(0.28, 3.6, -0.26), Vector3.new(0.18, 3.1, -0.26), 0.03, 0.03, LEATHER_DARK, torso)
	-- a hooded mantle over the shoulders, a ragged cloak down the back
	deco(torso, "Mantle", Vector3.new(1.28, 0.24, 0.72), Vector3.new(0, 3.9, 0.04), HOOD, Enum.Material.Fabric)
	deco(torso, "MantleFront", Vector3.new(0.7, 0.3, 0.06), CFrame.new(0, 3.72, -0.33) * CFrame.Angles(0.1, 0, 0), HOOD, Enum.Material.Fabric)
	local hemY = {}
	for i, s in ipairs({ { -0.5, 2.15, -0.06 }, { -0.25, 2.5, 0.03 }, { 0, 2.3, 0 }, { 0.25, 2.55, -0.03 }, { 0.5, 2.05, 0.06 } }) do
		local x, len, roll = s[1], s[2], s[3]
		deco(torso, "Cloak" .. i, Vector3.new(0.27, len, 0.05), CFrame.new(x, 3.85 - len / 2, 0.33 + len * 0.04) * CFrame.Angles(-0.06, 0, roll), HOOD_DARK, Enum.Material.Fabric)
		table.insert(hemY, 3.85 - len)
	end

	-- the quiver over the right shoulder, the fletched ends of the bone arrows sticking out
	local qBottom, qTop = Vector3.new(-0.22, 2.85, 0.42), Vector3.new(0.3, 4.12, 0.46)
	bar("Quiver", qBottom, qTop, 0.3, 0.3, LEATHER_DARK, torso, Enum.Material.Leather)
	bar("QuiverStrap", Vector3.new(-0.42, 3.95, -0.27), Vector3.new(0.38, 2.85, -0.27), 0.09, 0.03, LEATHER, torso, Enum.Material.Leather)
	local qDir = (qTop - qBottom).Unit
	deco(torso, "QuiverRim", Vector3.new(0.34, 0.08, 0.34), CFrame.lookAt(qTop, qTop + qDir) * CFrame.Angles(math.rad(90), 0, 0), BONE)
	for i, o in ipairs({ Vector3.new(-0.06, 0, -0.05), Vector3.new(0.06, 0, 0.04), Vector3.new(0, 0, 0.08), Vector3.new(0.05, 0, -0.07) }) do
		local base = qTop + o
		local tip = base + qDir * (0.42 + i * 0.03)
		bar("ArrowShaft", base, tip, 0.04, 0.04, BONE, torso)
		bar("Fletching", tip - qDir * 0.22, tip, 0.12, 0.02, FEATHER, torso)
	end

	-- ── Head: a deep hood with a long tip; only a dried jaw and two eyes show ──
	local head = part("Head", Vector3.new(0.55, 0.6, 0.55), Vector3.new(0, 4.4, -0.02), SKIN)
	motor("Neck", torso, head, Vector3.new(0, 4.02, 0))
	deco(head, "HoodTop", Vector3.new(0.86, 0.16, 0.86), Vector3.new(0, 4.86, 0.02), HOOD, Enum.Material.Fabric)
	for _, x in ipairs({ -1, 1 }) do
		deco(head, "HoodSide", Vector3.new(0.12, 0.8, 0.84), Vector3.new(x * 0.42, 4.5, 0.02), HOOD, Enum.Material.Fabric)
	end
	deco(head, "HoodBack", Vector3.new(0.86, 0.82, 0.12), Vector3.new(0, 4.48, 0.42), HOOD, Enum.Material.Fabric)
	deco(head, "HoodBrim", Vector3.new(0.86, 0.14, 0.24), CFrame.new(0, 4.8, -0.42) * CFrame.Angles(-0.25, 0, 0), HOOD, Enum.Material.Fabric)
	bar("HoodTip", Vector3.new(0, 4.86, 0.42), Vector3.new(0, 4.05, 0.8), 0.3, 0.26, HOOD, head, Enum.Material.Fabric)
	bar("HoodTipEnd", Vector3.new(0, 4.1, 0.78), Vector3.new(0, 3.45, 0.92), 0.18, 0.14, HOOD, head, Enum.Material.Fabric)
	deco(head, "FaceShadow", Vector3.new(0.64, 0.5, 0.04), Vector3.new(0, 4.52, -0.33), SHADE)
	deco(head, "Jaw", Vector3.new(0.44, 0.22, 0.12), Vector3.new(0, 4.18, -0.3), SKIN)
	deco(head, "Cheek", Vector3.new(0.52, 0.12, 0.1), Vector3.new(0, 4.3, -0.31), SKIN_DARK)
	deco(head, "Mouth", Vector3.new(0.26, 0.035, 0.02), Vector3.new(0, 4.17, -0.37), SHADE)
	for _, x in ipairs({ -1, 1 }) do
		local eye = deco(head, "Eye", Vector3.one * 0.075, Vector3.new(x * 0.11, 4.46, -0.36), EYE, NEON, Enum.PartType.Ball)
		eye.Transparency = 0.2
	end
	local eyeLight = Instance.new("PointLight")
	eyeLight.Color = EYE
	eyeLight.Range = 3
	eyeLight.Brightness = 0.6
	eyeLight.Shadows = false
	eyeLight.Parent = head

	-- ── Arms ──────────────────────────────────────────────────────
	local function arm(side, x)
		local upper = part(side .. "UpperArm", Vector3.new(0.2, 0.85, 0.2), Vector3.new(x, 3.425, 0), SKIN)
		motor(side .. "Shoulder", torso, upper, Vector3.new(x, 3.85, 0))
		local fore = part(side .. "Forearm", Vector3.new(0.17, 0.85, 0.17), Vector3.new(x, 2.575, 0), SKIN)
		motor(side .. "Elbow", upper, fore, Vector3.new(x, 3.0, 0))
		deco(upper, "ElbowKnob", Vector3.new(0.21, 0.16, 0.21), Vector3.new(x, 3.0, 0.02), SKIN_DARK)
		return upper, fore
	end
	local _, lFore = arm("L", -0.6)
	local _, rFore = arm("R", 0.6)
	deco(lFore, "Bracer", Vector3.new(0.23, 0.42, 0.23), Vector3.new(-0.6, 2.42, 0), LEATHER_DARK, Enum.Material.Leather)
	-- the draw hand: two fingers worn down to bone by the string
	deco(rFore, "RHand", Vector3.new(0.2, 0.24, 0.2), Vector3.new(0.6, 2.03, 0), SKIN)
	deco(rFore, "BoneFinger", Vector3.new(0.045, 0.14, 0.045), Vector3.new(0.56, 1.86, -0.07), BONE)
	deco(rFore, "BoneFinger", Vector3.new(0.045, 0.13, 0.045), Vector3.new(0.62, 1.86, -0.07), BONE)

	-- the bow hand on its wrist joint, the bow welded to it (grip at the hand's centre)
	local grip = Vector3.new(-0.6, 2.03, 0)
	local lHand = part("LHand", Vector3.new(0.22, 0.24, 0.22), grip, SKIN)
	motor("LWrist", lFore, lHand, Vector3.new(-0.6, 2.15, 0))
	-- the limbs: two long bones bending back towards the string side (+Z) at the tips
	local profile = { { 0, 0 }, { 0.25, 0.02 }, { 0.75, 0.1 }, { 1.2, 0.22 }, { 1.45, 0.34 } }
	for _, dir in ipairs({ 1, -1 }) do
		for k = 1, #profile - 1 do
			local a = grip + Vector3.new(0, dir * profile[k][1], profile[k][2])
			local b = grip + Vector3.new(0, dir * profile[k + 1][1], profile[k + 1][2])
			bar("BowLimb", a, b, 0.2 - k * 0.025, 0.22 - k * 0.025, BONE, lHand)
		end
		-- a carved hook at the tip and a sinew lashing halfway
		local tip = grip + Vector3.new(0, dir * 1.45, 0.34)
		bar("BowTip", tip, tip + Vector3.new(0, dir * 0.12, -0.08), 0.06, 0.06, BONE, lHand)
		deco(lHand, "Lashing", Vector3.new(0.14, 0.08, 0.16), grip + Vector3.new(0, dir * 0.75, 0.1), LEATHER_DARK)
	end
	deco(lHand, "BowGrip", Vector3.new(0.16, 0.44, 0.17), grip, LEATHER_DARK, Enum.Material.Leather)

	-- the string: two beams through the nock point
	local function attach(name, pos)
		local a = Instance.new("Attachment")
		a.Name = name
		a.Position = pos -- (LHand is not rotated: local = offset from the grip)
		a.Parent = lHand
		return a
	end
	local tipTop = attach("TipTop", Vector3.new(0, 1.45, 0.34))
	local tipBottom = attach("TipBottom", Vector3.new(0, -1.45, 0.34))
	local nock = attach("Nock", Vector3.new(0, 0, 0.34))
	for i, ends in ipairs({ { tipTop, nock }, { nock, tipBottom } }) do
		local s = Instance.new("Beam")
		s.Name = "String" .. i
		s.Attachment0 = ends[1]
		s.Attachment1 = ends[2]
		s.Color = ColorSequence.new(STRING)
		s.Width0 = 0.035
		s.Width1 = 0.035
		s.FaceCamera = true
		s.Segments = 1
		s.LightEmission = SHADOW and 1 or 0
		s.LightInfluence = SHADOW and 0 or 1
		s.Transparency = NumberSequence.new(0)
		s.Parent = lHand
	end

	-- ── Legs: bandaged, in worn boots ─────────────────────────────
	local function leg(side, x)
		local upper = part(side .. "UpperLeg", Vector3.new(0.26, 1.05, 0.26), Vector3.new(x, 1.92, 0), LEATHER_DARK, Enum.Material.Fabric)
		motor(side .. "Hip", pelvis, upper, Vector3.new(x, 2.45, 0))
		local lower = part(side .. "LowerLeg", Vector3.new(0.22, 1.0, 0.22), Vector3.new(x, 0.9, 0), WRAP, Enum.Material.Fabric)
		motor(side .. "Knee", upper, lower, Vector3.new(x, 1.4, 0))
		for i = 0, 2 do
			deco(lower, "Wrap", Vector3.new(0.25, 0.05, 0.25), CFrame.new(x, 1.25 - i * 0.22, 0) * CFrame.Angles(0, 0, (i % 2 == 0) and 0.18 or -0.18), SKIN_DARK)
		end
		deco(lower, "Boot", Vector3.new(0.3, 0.42, 0.5), Vector3.new(x, 0.21, -0.08), BOOT, Enum.Material.Leather)
		deco(lower, "Knee", Vector3.new(0.22, 0.16, 0.12), Vector3.new(x, 1.4, -0.12), SKIN_DARK)
	end
	leg("L", -0.3)
	leg("R", 0.3)

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
		local function source(to, size, at)
			local src = deco(to, "FxSource", size, at, Color3.new())
			src.Transparency = 1
			return src
		end
		-- smoke pooling at the feet
		local pool = part("SmokePool", Vector3.new(1.6, 0.1, 1.4), Vector3.new(0, 0.15, 0.1), Color3.new())
		pool.Transparency = 1
		weld(root, pool)
		emitter(pool, {
			Name = "ShadowPool", Texture = SMOKE_TEXTURE, LightInfluence = 0,
			Color = ColorSequence.new(Color3.fromRGB(14, 8, 26), Color3.fromRGB(46, 22, 84)),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(0.5, 1.6), NumberSequenceKeypoint.new(1, 2.2) }),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0.35), NumberSequenceKeypoint.new(0.7, 0.6), NumberSequenceKeypoint.new(1, 1) }),
			Lifetime = NumberRange.new(1.4, 2.2), Rate = 7, Speed = NumberRange.new(0.1, 0.4), Acceleration = Vector3.new(0, 0.3, 0),
			Drag = 1, Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-25, 25), EmissionDirection = Enum.NormalId.Top,
		})
		-- the cloak's hem dissolving into smoke
		local hem = source(torso, Vector3.new(1.2, 0.2, 0.2), Vector3.new(0, math.min(table.unpack(hemY)) + 0.25, 0.42))
		emitter(hem, {
			Name = "HemSmoke", Texture = SMOKE_TEXTURE, LightInfluence = 0,
			Color = ColorSequence.new(Color3.fromRGB(18, 10, 32), Color3.fromRGB(72, 36, 130)),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0.9) }),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.25, 0.4), NumberSequenceKeypoint.new(1, 1) }),
			Lifetime = NumberRange.new(0.8, 1.3), Rate = 6, Speed = NumberRange.new(0.2, 0.6), Acceleration = Vector3.new(0, -0.4, 0.6),
			Drag = 1.5, Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-40, 40), EmissionDirection = Enum.NormalId.Bottom,
		})
		-- dark flames off the shoulders and the hood's tip
		local function darkFlames(src, rate)
			emitter(src, {
				Name = "ShadowFlames", Texture = FIRE_TEXTURE, LightEmission = 0, LightInfluence = 0,
				Color = ColorSequence.new(Color3.fromRGB(40, 16, 80), Color3.fromRGB(8, 4, 16)),
				Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 0.1) }),
				Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 1) }),
				Lifetime = NumberRange.new(0.45, 0.8), Rate = rate, Speed = NumberRange.new(1.5, 3), Acceleration = Vector3.new(0, 2, 0),
				Rotation = NumberRange.new(-15, 15), SpreadAngle = Vector2.new(15, 15), EmissionDirection = Enum.NormalId.Top,
			})
			emitter(src, {
				Name = "ShadowFlameGlow", Texture = FIRE_TEXTURE, LightEmission = 1, LightInfluence = 0,
				Color = ColorSequence.new(Color3.fromRGB(120, 60, 255)),
				Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0.05) }),
				Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) }),
				Lifetime = NumberRange.new(0.25, 0.45), Rate = rate * 0.6, Speed = NumberRange.new(1, 2), EmissionDirection = Enum.NormalId.Top,
			})
		end
		darkFlames(source(torso, Vector3.new(1.2, 0.2, 0.5), Vector3.new(0, 4.0, 0.05)), 10)
		darkFlames(source(head, Vector3.new(0.3, 0.2, 0.3), Vector3.new(0, 4.92, 0.1)), 5)
		-- the ForceField shimmer
		for _, name in ipairs({ "Torso", "Head", "LUpperArm", "RUpperArm", "LForearm", "RForearm", "LUpperLeg", "RUpperLeg", "LLowerLeg", "RLowerLeg" }) do
			local src = model:FindFirstChild(name)
			if src then
				local sh = part(name .. "Shell", src.Size + Vector3.one * 0.1, src.CFrame, Color3.fromRGB(120, 60, 255), Enum.Material.ForceField)
				sh.CastShadow = false
				weld(src, sh)
			end
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
	model:SetAttribute("AttackStyle", "Bow")
	model:SetAttribute("RootHeight", 2.6)
	model:SetAttribute("Height", 5.0)
	model.Parent = models

	local parts, joints = 0, 0
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then parts += 1 end
		if d:IsA("Motor6D") then joints += 1 end
	end
	return NAME .. ": " .. parts .. " parts, " .. joints .. " joints"
end

return build("Base") .. " | " .. build("Shadow")
