-- Builds the rigged Crypt Bat (Uncommon; v2 2026-10-15) in its two forms: ServerStorage.Models.CryptBat (base, levels
-- 0-9) and CryptBat_Shadow (the awakened shadow form, level 10+).
-- A big leathery bat: wide torn wings on bony finger struts, a skull-like face with the snout stripped to bare bone, two
-- long white fangs, small amber eyes deep in the sockets, huge notched ears, matted fur, ribs pressing through, clawed
-- hind feet hanging below, a stub of a tail. Base: grey-brown fur, dusky grey-purple wings. Shadow: black, glowing
-- violet struts (veins) through the wings, smoke trailing from the wingtips, the ethereal layer; the white fangs stay
-- (its accent).
-- Run in Studio's command bar / via the Studio MCP execute_luau (Edit mode), then run publish_unit_models.lua.
--
-- Rig (see the Bat block in src/client/Modules/UnitAnimator.lua):
--   * front = -Z, right = +X, it hovers: HumanoidRootPart at y = 3.2 (RootHeight), nothing touches the ground
--   * Motor6Ds: Root (HRP -> Torso), Neck, Jaw, LWing/RWing (the shoulder: the inner wing), LWingTip/RWingTip (the
--     elbow: the outer wing folds there), LLeg/RLeg (the clawed feet); identity rest, turning about the model's axes
--   * the wings are built spread; the membranes are triangles of two WedgeParts each
--   * attributes: Rig = "Procedural", Pose = "Bat", AttackStyle = "Dive", RootHeight, Height
local ServerStorage = game:GetService("ServerStorage")
local models = ServerStorage.Models

local SMOOTH = Enum.Material.SmoothPlastic
local NEON = Enum.Material.Neon
local SMOKE_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"
local FIRE_TEXTURE = "rbxasset://textures/particles/fire_main.dds"

local function build(FORM)
	local SHADOW = FORM == "Shadow"
	local NAME = SHADOW and "CryptBat_Shadow" or "CryptBat"

	local old = models:FindFirstChild(NAME)
	if old then
		old:Destroy()
	end

	-- (shadow form or base form)
	local FUR = SHADOW and Color3.fromRGB(18, 16, 24) or Color3.fromRGB(70, 60, 54)
	local FUR_DARK = SHADOW and Color3.fromRGB(11, 10, 15) or Color3.fromRGB(46, 40, 36)
	local MEMBRANE = SHADOW and Color3.fromRGB(26, 18, 40) or Color3.fromRGB(78, 64, 80)
	local STRUT = SHADOW and Color3.fromRGB(100, 45, 220) or Color3.fromRGB(150, 138, 120) -- (shadow: violet veins)
	local STRUT_MAT = SHADOW and NEON or SMOOTH
	local BONE = SHADOW and Color3.fromRGB(34, 30, 44) or Color3.fromRGB(206, 196, 170)
	local FANG = Color3.fromRGB(240, 236, 222) -- (white in both forms: the shadow form's accent)
	local EYE = SHADOW and Color3.fromRGB(150, 95, 255) or Color3.fromRGB(255, 170, 40)
	local EAR_INNER = SHADOW and Color3.fromRGB(40, 26, 64) or Color3.fromRGB(112, 74, 76)
	local SOCKET = Color3.fromRGB(12, 10, 12)

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

	local function wedgePart(name, size, cf, color)
		local p = Instance.new("WedgePart")
		p.Name = name
		p.Size = size
		p.CFrame = cf
		p.Color = color
		p.Material = SMOOTH
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

	-- a flat triangle a-b-c from two WedgeParts (the classic two-wedge method), welded to `to`
	local function triangle(name, a, b, c, thick, color, to)
		local ab, ac, bc = b - a, c - a, c - b
		local abd, acd, bcd = ab:Dot(ab), ac:Dot(ac), bc:Dot(bc)
		if abd > acd and abd > bcd then
			c, a = a, c
		elseif acd > bcd and acd > abd then
			a, b = b, a
		end
		ab, ac, bc = b - a, c - a, c - b
		local right = ac:Cross(ab).Unit
		local up = bc:Cross(right).Unit
		local back = bc.Unit
		local height = math.abs(ab:Dot(up))
		local w1 = wedgePart(name, Vector3.new(thick, height, math.abs(ab:Dot(back))), CFrame.fromMatrix((a + b) / 2, right, up, back), color)
		local w2 = wedgePart(name, Vector3.new(thick, height, math.abs(ac:Dot(back))), CFrame.fromMatrix((a + c) / 2, -right, up, -back), color)
		weld(to, w1)
		weld(to, w2)
	end

	-- ── Body ──────────────────────────────────────────────────────
	local root = part("HumanoidRootPart", Vector3.new(1.0, 0.4, 1.0), Vector3.new(0, 3.2, 0), FUR)
	root.Transparency = 1
	model.PrimaryPart = root

	local torso = part("Torso", Vector3.new(0.88, 0.82, 1.3), CFrame.new(0, 3.2, 0.12) * CFrame.Angles(0.15, 0, 0), FUR, Enum.Material.Fabric)
	motor("Root", root, torso, Vector3.new(0, 3.2, 0))
	deco(torso, "Chest", Vector3.new(0.8, 0.6, 0.5), Vector3.new(0, 3.3, -0.42), FUR, Enum.Material.Fabric)
	for _, x in ipairs({ -1, 1 }) do
		for i = 0, 2 do
			bar("Rib", Vector3.new(x * 0.45, 3.42 - i * 0.14, -0.2 + i * 0.18), Vector3.new(x * 0.45, 3.0 - i * 0.1, -0.05 + i * 0.18), 0.05, 0.06, FUR_DARK, torso)
		end
	end
	for _, t in ipairs({ { -0.15, 3.66, 0.2 }, { 0.18, 3.62, 0.45 }, { 0, 3.58, 0.7 } }) do
		deco(torso, "Tuft", Vector3.new(0.3, 0.14, 0.26), CFrame.new(t[1], t[2], t[3]) * CFrame.Angles(0.3, t[1], 0.2), FUR_DARK, Enum.Material.Fabric)
	end
	bar("Tail", Vector3.new(0, 3.0, 0.75), Vector3.new(0, 2.85, 1.12), 0.12, 0.1, FUR_DARK, torso)

	-- ── Head: a skull-like face, the snout bare bone ─────────────
	local head = part("Head", Vector3.new(0.72, 0.66, 0.58), Vector3.new(0, 3.62, -0.82), FUR, Enum.Material.Fabric)
	motor("Neck", torso, head, Vector3.new(0, 3.5, -0.55))
	deco(head, "Snout", Vector3.new(0.44, 0.34, 0.42), Vector3.new(0, 3.48, -1.18), BONE)
	deco(head, "Brow", Vector3.new(0.6, 0.12, 0.14), Vector3.new(0, 3.82, -1.08), BONE)
	deco(head, "NoseHole", Vector3.new(0.16, 0.08, 0.04), Vector3.new(0, 3.56, -1.4), SOCKET)
	for _, x in ipairs({ -1, 1 }) do
		deco(head, "Socket", Vector3.new(0.18, 0.15, 0.06), Vector3.new(x * 0.17, 3.7, -1.1), SOCKET)
		deco(head, "Eye", Vector3.one * 0.08, Vector3.new(x * 0.17, 3.7, -1.13), EYE, NEON, Enum.PartType.Ball)
		-- the fangs
		bar("Fang", Vector3.new(x * 0.11, 3.34, -1.34), Vector3.new(x * 0.1, 3.06, -1.38), 0.07, 0.07, FANG, head)
		-- the ears: tall, flared out, a notch torn from the top
		local earCF = CFrame.new(x * 0.28, 4.12, -0.78) * CFrame.Angles(-0.15, 0, -x * 0.35)
		deco(head, "Ear", Vector3.new(0.34, 0.78, 0.06), earCF, FUR, Enum.Material.Fabric)
		deco(head, "EarInner", Vector3.new(0.2, 0.55, 0.04), earCF * CFrame.new(0, -0.04, -0.04), EAR_INNER)
		deco(head, "EarNotch", Vector3.new(0.1, 0.12, 0.08), earCF * CFrame.new(x * 0.09, 0.34, 0), SOCKET)
	end
	local eyeLight = Instance.new("PointLight")
	eyeLight.Color = EYE
	eyeLight.Range = 2.5
	eyeLight.Brightness = 0.6
	eyeLight.Shadows = false
	eyeLight.Parent = head
	local jaw = part("Jaw", Vector3.new(0.38, 0.12, 0.36), Vector3.new(0, 3.26, -1.16), BONE)
	motor("Jaw", head, jaw, Vector3.new(0, 3.32, -0.98))
	for i = 0, 3 do
		deco(jaw, "Tooth", Vector3.new(0.05, 0.08, 0.04), Vector3.new(-0.12 + i * 0.08, 3.34, -1.32), FANG)
	end

	-- ── Wings: the shoulder joint carries the inner wing, the elbow joint the outer wing ──
	local wingTips = {}
	for _, side in ipairs({ -1, 1 }) do
		local s = side < 0 and "L" or "R"
		local function P(x, y, z)
			return Vector3.new(side * x, y, z)
		end
		local S, E, W = P(0.42, 3.42, -0.25), P(1.35, 3.62, 0.05), P(2.45, 3.7, -0.1)
		local F1, F2, F3, B = P(3.35, 3.5, 0.4), P(3.05, 3.42, 1.05), P(2.15, 3.36, 1.35), P(0.42, 3.2, 0.75)
		local inner = bar(s .. "WingBone", S, E, 0.12, 0.12, STRUT, nil, STRUT_MAT)
		motor(s .. "Wing", torso, inner, S)
		local outer = bar(s .. "WingForearm", E, W, 0.1, 0.1, STRUT, nil, STRUT_MAT)
		motor(s .. "WingTip", inner, outer, E)
		deco(inner, "ElbowKnob", Vector3.one * 0.16, E, BONE, nil, Enum.PartType.Ball)
		-- the finger struts and a hooked thumb claw
		for _, f in ipairs({ F1, F2, F3 }) do
			bar("Finger", W, f, 0.06, 0.06, STRUT, outer, STRUT_MAT)
		end
		bar("Thumb", W, W + P(0.05, 0.16, -0.22), 0.05, 0.05, BONE, outer)
		-- the membranes
		triangle("Membrane", S, E, B, 0.04, MEMBRANE, inner)
		triangle("Membrane", B, E, F3, 0.04, MEMBRANE, outer)
		triangle("Membrane", E, W, F3, 0.04, MEMBRANE, outer)
		triangle("Membrane", W, F2, F3, 0.04, MEMBRANE, outer)
		triangle("Membrane", W, F1, F2, 0.04, MEMBRANE, outer)
		table.insert(wingTips, { outer = outer, points = { F1, F2 } })

		-- the clawed hind feet
		local hip = P(0.22, 2.95, 0.6)
		local foot = P(0.26, 2.55, 0.85)
		local leg = bar(s .. "LegBone", hip, foot, 0.1, 0.1, FUR_DARK)
		motor(s .. "Leg", torso, leg, hip)
		for k = -1, 1 do
			bar("Claw", foot, foot + P(k * 0.06, -0.12, -0.14), 0.04, 0.04, BONE, leg)
		end
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
		-- smoke trailing from the wingtips
		for _, wt in ipairs(wingTips) do
			for _, p in ipairs(wt.points) do
				local src = deco(wt.outer, "TipSmoke", Vector3.one * 0.2, p, Color3.new())
				src.Transparency = 1
				emitter(src, {
					Name = "ShadowWisps", Texture = SMOKE_TEXTURE, LightInfluence = 0,
					Color = ColorSequence.new(Color3.fromRGB(18, 10, 32), Color3.fromRGB(72, 36, 130)),
					Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 0.7) }),
					Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) }),
					Lifetime = NumberRange.new(0.5, 0.9), Rate = 8, Speed = NumberRange.new(0.1, 0.4), Drag = 2,
					Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-40, 40),
				})
			end
		end
		-- dark flames off the back
		local back = deco(torso, "FxSource", Vector3.new(0.6, 0.2, 0.8), Vector3.new(0, 3.62, 0.25), Color3.new())
		back.Transparency = 1
		emitter(back, {
			Name = "ShadowFlames", Texture = FIRE_TEXTURE, LightEmission = 0, LightInfluence = 0,
			Color = ColorSequence.new(Color3.fromRGB(40, 16, 80), Color3.fromRGB(8, 4, 16)),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 0.08) }),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 1) }),
			Lifetime = NumberRange.new(0.4, 0.7), Rate = 10, Speed = NumberRange.new(1.5, 3), Acceleration = Vector3.new(0, 2, 0),
			Rotation = NumberRange.new(-15, 15), SpreadAngle = Vector2.new(15, 15), EmissionDirection = Enum.NormalId.Top,
		})
		emitter(back, {
			Name = "ShadowFlameGlow", Texture = FIRE_TEXTURE, LightEmission = 1, LightInfluence = 0,
			Color = ColorSequence.new(Color3.fromRGB(120, 60, 255)),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 0.04) }),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) }),
			Lifetime = NumberRange.new(0.25, 0.4), Rate = 6, Speed = NumberRange.new(1, 2), EmissionDirection = Enum.NormalId.Top,
		})
		-- the ForceField shimmer over the body and the head
		for _, name in ipairs({ "Torso", "Head" }) do
			local p = model:FindFirstChild(name)
			local sh = part(name .. "Shell", p.Size + Vector3.one * 0.1, p.CFrame, Color3.fromRGB(120, 60, 255), Enum.Material.ForceField)
			sh.CastShadow = false
			weld(p, sh)
		end
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
	model:SetAttribute("Pose", "Bat")
	model:SetAttribute("AttackStyle", "Dive")
	model:SetAttribute("RootHeight", 3.2)
	model:SetAttribute("Height", 4.6)
	model.Parent = models

	local parts, joints = 0, 0
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then parts += 1 end
		if d:IsA("Motor6D") then joints += 1 end
	end
	return NAME .. ": " .. parts .. " parts, " .. joints .. " joints"
end

return build("Base") .. " | " .. build("Shadow")
