-- Builds the rigged Ghoul in its two forms: ServerStorage.Models.Ghoul (base, levels 0-9) and Ghoul_Shadow (the awakened
-- shadow form, Economy.AWAKEN_LEVEL+): one shape and rig, so the same animations.
-- Shadow form: a black crawler that keeps its yellow eyes (its accent); violet glowing claws, mouth and stitched wound;
-- a ForceField shimmer over the body, dark flames along its spine, the outline, and a wide low smoke it crawls through.
-- v2 (2026-10-15): a starved crawler on all fours. Long front arms (shoulders high, hips low), a hunched spine with
-- vertebrae through the skin, ribs on the flanks, a stitched wound, bruises and rags; a narrow skull head hanging low
-- with a wide needle-toothed jaw, small pale yellow eyes deep in the sockets and a few long strands of black hair;
-- three long yellowed claws per hand and dog-like hind legs.
-- Run in Studio's command bar / via the Studio MCP execute_luau (Edit mode), then run publish_unit_models.lua.
--
-- Rig (see the Crawler block in src/client/Modules/UnitAnimator.lua):
--   * front = -Z, right = +X, feet on y = 0, root part = HumanoidRootPart at y = 2.0
--   * Motor6Ds (identity rest, built in the standing pose): Root (HRP -> Hips), Spine (Hips -> Chest), Neck, Jaw,
--     LShoulder/LElbow/LWrist, RShoulder/RElbow/RWrist (front limbs), LHip/LKnee/LAnkle, RHip/RKnee/RAnkle (hind)
--   * every joint turns about the model's own axes: + X swings a limb forward (and pitches the chest / head up)
--   * attributes: Rig = "Procedural", Pose = "Crawler", AttackStyle = "Pounce", RootHeight, Height
local ServerStorage = game:GetService("ServerStorage")
local models = ServerStorage.Models

local function build(FORM)
	local SHADOW = FORM == "Shadow"
	local NAME = SHADOW and "Ghoul_Shadow" or "Ghoul"

	local old = models:FindFirstChild(NAME)
	if old and old:GetAttribute("Rig") ~= "Procedural" then
		old.Name = NAME .. "_Old"
	elseif old then
		old:Destroy()
	end

	local SMOOTH = Enum.Material.SmoothPlastic
	local NEON = Enum.Material.Neon
	local SMOKE_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"

	-- (shadow form or base form)
	local SKIN = SHADOW and Color3.fromRGB(18, 16, 24) or Color3.fromRGB(122, 134, 112)
	local SKIN_DARK = SHADOW and Color3.fromRGB(32, 28, 42) or Color3.fromRGB(86, 96, 80)
	local BRUISE = SHADOW and Color3.fromRGB(50, 30, 84) or Color3.fromRGB(82, 66, 78)
	local BONE = SHADOW and Color3.fromRGB(46, 42, 60) or Color3.fromRGB(212, 202, 172)
	local CLAW = SHADOW and Color3.fromRGB(100, 45, 220) or Color3.fromRGB(196, 176, 124)
	local CLAW_MAT = SHADOW and NEON or SMOOTH
	local EYE = Color3.fromRGB(244, 238, 130) -- (the yellow eyes in both forms: the shadow form's accent)
	local MOUTH = SHADOW and Color3.fromRGB(100, 45, 220) or Color3.fromRGB(40, 14, 18)
	local MOUTH_MAT = SHADOW and NEON or SMOOTH
	local SOCKET = Color3.fromRGB(18, 16, 16)
	local HAIR = Color3.fromRGB(20, 18, 20)
	local RAG = SHADOW and Color3.fromRGB(24, 20, 28) or Color3.fromRGB(58, 44, 36)
	local WOUND = SHADOW and Color3.fromRGB(100, 45, 220) or Color3.fromRGB(100, 30, 32)
	local WOUND_MAT = SHADOW and NEON or SMOOTH
	local STITCH = Color3.fromRGB(24, 20, 18)

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

	-- a part stretched between two points (w x h cross-section); welded to `to` unless it is nil
	local function bar(name, a, b, w, h, color, to, material)
		local up = math.abs((b - a).Unit.Y) > 0.95 and Vector3.xAxis or Vector3.yAxis
		local p = part(name, Vector3.new(w, h or w, (b - a).Magnitude), CFrame.lookAt((a + b) / 2, b, up), color, material)
		if to then
			weld(to, p)
		end
		return p
	end

	local function deco(to, name, size, at, color, material, shape)
		local p = part(name, size, at, color, material, shape)
		weld(to, p)
		return p
	end

	-- ── Body ──────────────────────────────────────────────────────
	local root = part("HumanoidRootPart", Vector3.new(1.0, 0.4, 1.6), Vector3.new(0, 2.0, 0), SKIN)
	root.Transparency = 1
	model.PrimaryPart = root

	local hips = part("Hips", Vector3.new(0.78, 0.55, 0.8), CFrame.new(0, 1.72, 0.95) * CFrame.Angles(0.15, 0, 0), SKIN)
	motor("Root", root, hips, Vector3.new(0, 1.8, 0.55))

	-- the chest slopes up towards the high shoulders
	local chest = part("Chest", Vector3.new(0.98, 0.78, 1.5), CFrame.new(0, 2.12, -0.2) * CFrame.Angles(0.36, 0, 0), SKIN)
	motor("Spine", hips, chest, Vector3.new(0, 1.85, 0.55))
	deco(chest, "Shoulders", Vector3.new(1.1, 0.5, 0.55), CFrame.new(0, 2.38, -0.62) * CFrame.Angles(0.36, 0, 0), SKIN)
	deco(chest, "Belly", Vector3.new(0.7, 0.3, 1.0), CFrame.new(0, 1.78, -0.1) * CFrame.Angles(0.3, 0, 0), SKIN_DARK)

	-- the hunched spine: vertebrae through the skin along the arch (chest ones on the chest, the rest on the hips)
	local SPINE = {
		{ 2.7, -0.75, chest }, { 2.74, -0.45, chest }, { 2.7, -0.15, chest }, { 2.6, 0.15, chest },
		{ 2.42, 0.45, chest }, { 2.1, 0.75, hips }, { 2.02, 1.05, hips }, { 1.92, 1.32, hips },
	}
	for i, v in ipairs(SPINE) do
		local s = 1 - i * 0.05
		deco(v[3], "Vertebra", Vector3.new(0.16 * s + 0.04, 0.16, 0.2), CFrame.new(0, v[1], v[2]) * CFrame.Angles(0.3, 0, 0), BONE)
	end

	-- ribs pressing out of the flanks, bruises on the back
	for _, x in ipairs({ -1, 1 }) do
		for i = 0, 3 do
			local z = -0.75 + i * 0.3
			local y = 2.3 + z * 0.3
			bar("Rib", Vector3.new(x * 0.5, y + 0.2, z), Vector3.new(x * 0.47, y - 0.32, z + 0.12), 0.06, 0.08, SKIN_DARK, chest)
		end
	end
	deco(chest, "Bruise", Vector3.new(0.4, 0.06, 0.45), CFrame.new(0.22, 2.55, -0.05) * CFrame.Angles(0.36, 0, 0.2), BRUISE)
	deco(hips, "Bruise", Vector3.new(0.32, 0.5, 0.06), CFrame.new(-0.3, 1.7, 1.36) * CFrame.Angles(0.1, 0.4, 0), BRUISE)

	-- a stitched wound down the left flank
	bar("Wound", Vector3.new(-0.5, 2.38, -0.3), Vector3.new(-0.5, 1.92, 0.15), 0.05, 0.06, WOUND, chest, WOUND_MAT)
	for i = 0, 3 do
		local p = Vector3.new(-0.51, 2.38, -0.3):Lerp(Vector3.new(-0.51, 1.92, 0.15), (i + 0.5) / 4)
		deco(chest, "Stitch", Vector3.new(0.04, 0.04, 0.2), CFrame.new(p) * CFrame.Angles(-0.8, 0, 0), STITCH)
	end

	-- rags tied round the hips, hanging in torn strips
	deco(hips, "RagBelt", Vector3.new(0.84, 0.14, 0.86), CFrame.new(0, 1.72, 0.72) * CFrame.Angles(0.15, 0, 0), RAG, Enum.Material.Fabric)
	for i, s in ipairs({ { -0.36, 0.5, 0.95 }, { 0.36, 0.42, 0.8 }, { -0.12, 0.38, 1.36 }, { 0.18, 0.52, 1.35 } }) do
		local x, h, z = s[1], s[2], s[3]
		local back = z > 1.2
		deco(hips, "Rag" .. i, back and Vector3.new(0.22, h, 0.04) or Vector3.new(0.04, h, 0.24),
			CFrame.new(back and x or x * 1.17, 1.66 - h / 2, z) * CFrame.Angles(back and 0.15 or 0, 0, back and 0 or x * 0.2), RAG, Enum.Material.Fabric)
	end

	-- ── Head: hangs low in front of the shoulders ─────────────────
	local head = part("Head", Vector3.new(0.6, 0.48, 0.7), Vector3.new(0, 2.08, -1.6), SKIN)
	motor("Neck", chest, head, Vector3.new(0, 2.42, -0.95))
	bar("NeckSkin", Vector3.new(0, 2.45, -0.95), Vector3.new(0, 2.15, -1.4), 0.36, 0.34, SKIN_DARK, head)
	deco(head, "Cranium", Vector3.new(0.66, 0.24, 0.62), Vector3.new(0, 2.36, -1.52), SKIN)
	deco(head, "Brow", Vector3.new(0.62, 0.1, 0.12), Vector3.new(0, 2.24, -1.94), SKIN_DARK)
	deco(head, "Cheeks", Vector3.new(0.7, 0.18, 0.4), Vector3.new(0, 1.98, -1.68), SKIN_DARK)
	for _, x in ipairs({ -1, 1 }) do
		deco(head, "Socket", Vector3.new(0.17, 0.12, 0.06), Vector3.new(x * 0.15, 2.13, -1.94), SOCKET)
		deco(head, "Eye", Vector3.one * 0.07, Vector3.new(x * 0.15, 2.13, -1.94), EYE, Enum.Material.Neon, Enum.PartType.Ball)
		-- a slit where the nose was
		deco(head, "NoseSlit", Vector3.new(0.03, 0.1, 0.04), Vector3.new(x * 0.035, 2.0, -1.96), SOCKET)
	end
	local eyeLight = Instance.new("PointLight")
	eyeLight.Color = EYE
	eyeLight.Range = 2.5
	eyeLight.Brightness = 0.7
	eyeLight.Shadows = false
	eyeLight.Parent = head
	deco(head, "UpperMouth", Vector3.new(0.5, 0.06, 0.12), Vector3.new(0, 1.86, -1.88), MOUTH, MOUTH_MAT)
	for i = 0, 6 do
		-- needle teeth pointing down
		deco(head, "Tooth", Vector3.new(0.03, 0.13, 0.03), Vector3.new(-0.21 + i * 0.07, 1.8, -1.9 + math.abs(i - 3) * 0.02), BONE)
	end
	-- a few long strands of black hair from the scalp, hanging down past the face
	for i, s in ipairs({ { -0.2, -1.45, -0.25 }, { 0.05, -1.35, 0.1 }, { 0.24, -1.55, 0.3 }, { -0.05, -1.7, -0.05 } }) do
		local x, z, sway = s[1], s[2], s[3]
		bar("Hair", Vector3.new(x, 2.48, z), Vector3.new(x + sway * 0.5, 1.75 - i * 0.05, z - 0.25), 0.04, 0.04, HAIR, head)
	end

	local jaw = part("Jaw", Vector3.new(0.5, 0.12, 0.56), Vector3.new(0, 1.72, -1.66), SKIN_DARK)
	motor("Jaw", head, jaw, Vector3.new(0, 1.86, -1.36))
	deco(jaw, "LowerMouth", Vector3.new(0.44, 0.04, 0.4), Vector3.new(0, 1.79, -1.68), MOUTH, MOUTH_MAT)
	for i = 0, 5 do
		deco(jaw, "LowerTooth", Vector3.new(0.03, 0.12, 0.03), Vector3.new(-0.18 + i * 0.072, 1.84, -1.9 + math.abs(i - 2.5) * 0.03), BONE)
	end

	-- ── Front limbs: long, elbows out, three claws per hand ────────
	local function frontLimb(side, x)
		local shoulder = Vector3.new(x * 0.52, 2.3, -0.7)
		local elbow = Vector3.new(x * 0.78, 1.32, -0.75)
		local wrist = Vector3.new(x * 0.7, 0.22, -1.05)
		local upper = bar(side .. "UpperArm", shoulder, elbow, 0.24, 0.24, SKIN)
		motor(side .. "Shoulder", chest, upper, shoulder)
		deco(upper, "ShoulderKnob", Vector3.one * 0.3, shoulder, SKIN, nil, Enum.PartType.Ball)
		deco(upper, "ElbowKnob", Vector3.new(0.2, 0.2, 0.2), elbow + Vector3.new(x * 0.05, 0, 0.06), BONE)
		local fore = bar(side .. "Forearm", elbow, wrist, 0.18, 0.18, SKIN)
		motor(side .. "Elbow", upper, fore, elbow)
		local hand = part(side .. "Hand", Vector3.new(0.3, 0.12, 0.34), Vector3.new(x * 0.7, 0.12, -1.15), SKIN_DARK)
		motor(side .. "Wrist", fore, hand, wrist)
		for i, o in ipairs({ -0.1, 0, 0.1 }) do
			local base = Vector3.new(x * 0.7 + o, 0.12, -1.3)
			local len = (i == 2) and 0.55 or 0.45
			local knuckle = base + Vector3.new(o * 0.3, 0.04, -0.12)
			bar("Finger", base, knuckle, 0.06, 0.06, SKIN_DARK, hand)
			bar("Claw", knuckle, knuckle + Vector3.new(o * 0.4, -0.1, -len), 0.05, 0.06, CLAW, hand, CLAW_MAT)
		end
	end
	frontLimb("L", -1)
	frontLimb("R", 1)

	-- ── Hind legs: dog-like (knee forward, hock back) ─────────────
	local function hindLeg(side, x)
		local hip = Vector3.new(x * 0.4, 1.68, 1.0)
		local knee = Vector3.new(x * 0.5, 1.0, 0.72)
		local ankle = Vector3.new(x * 0.5, 0.42, 1.22)
		local toe = Vector3.new(x * 0.5, 0.08, 0.98)
		local thigh = bar(side .. "Thigh", hip, knee, 0.3, 0.3, SKIN)
		motor(side .. "Hip", hips, thigh, hip)
		deco(thigh, "KneeKnob", Vector3.new(0.22, 0.2, 0.2), knee + Vector3.new(0, 0, -0.05), BONE)
		local shin = bar(side .. "Shin", knee, ankle, 0.18, 0.18, SKIN)
		motor(side .. "Knee", thigh, shin, knee)
		-- a bone showing through the shin
		bar("ShinBone", knee + Vector3.new(x * 0.08, -0.08, 0.02), ankle + Vector3.new(x * 0.08, 0.12, 0), 0.06, 0.06, BONE, shin)
		local foot = bar(side .. "Foot", ankle, toe, 0.16, 0.16, SKIN_DARK)
		motor(side .. "Ankle", shin, foot, ankle)
		deco(foot, "Heel", Vector3.new(0.14, 0.12, 0.14), ankle, BONE)
		for _, o in ipairs({ -0.08, 0, 0.08 }) do
			bar("Toe", toe + Vector3.new(o, 0, 0), toe + Vector3.new(o * 1.5, -0.04, -0.28), 0.06, 0.06, CLAW, foot)
		end
	end
	hindLeg("L", -1)
	hindLeg("R", 1)

	-- ── Shadow form extras ────────────────────────────────────────
	if SHADOW then
		-- shadow smoke: a pool at the feet (on the root, so it follows the body but not the limbs) and wisps off the body
		local function smokePool(size, at, rate)
			local pool = part("SmokePool", size, at, Color3.new(), SMOOTH)
			pool.Transparency = 1
			weld(root, pool)
			local e = Instance.new("ParticleEmitter")
			e.Name = "ShadowPool"
			e.Texture = SMOKE_TEXTURE
			e.Color = ColorSequence.new(Color3.fromRGB(14, 8, 26), Color3.fromRGB(46, 22, 84))
			e.LightInfluence = 0
			e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(0.5, 1.6), NumberSequenceKeypoint.new(1, 2.2) })
			e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0.35), NumberSequenceKeypoint.new(0.7, 0.6), NumberSequenceKeypoint.new(1, 1) })
			e.Lifetime = NumberRange.new(1.4, 2.2)
			e.Rate = rate
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
			g.Color = ColorSequence.new(Color3.fromRGB(110, 50, 230))
			g.LightEmission = 1
			g.LightInfluence = 0
			g.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1.5) })
			g.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.75), NumberSequenceKeypoint.new(1, 1) })
			g.Lifetime = NumberRange.new(1.0, 1.6)
			g.Rate = math.max(2, rate * 0.4)
			g.Speed = NumberRange.new(0.2, 0.5)
			g.Rotation = NumberRange.new(0, 360)
			g.EmissionDirection = Enum.NormalId.Top
			g.Parent = pool
		end
		local function wisps(to, size, at, rate)
			local src = deco(to, "WispSource", size, at, Color3.new(), SMOOTH)
			src.Transparency = 1
			local e = Instance.new("ParticleEmitter")
			e.Name = "ShadowWisps"
			e.Texture = SMOKE_TEXTURE
			e.Color = ColorSequence.new(Color3.fromRGB(18, 10, 32), Color3.fromRGB(72, 36, 130))
			e.LightInfluence = 0
			e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0.9) })
			e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.25, 0.45), NumberSequenceKeypoint.new(1, 1) })
			e.Lifetime = NumberRange.new(0.8, 1.3)
			e.Rate = rate
			e.Speed = NumberRange.new(0.4, 1.0)
			e.Acceleration = Vector3.new(0, 1.5, 0)
			e.Drag = 1.5
			e.Rotation = NumberRange.new(0, 360)
			e.RotSpeed = NumberRange.new(-40, 40)
			e.SpreadAngle = Vector2.new(30, 30)
			e.EmissionDirection = Enum.NormalId.Top
			e.Parent = src
		end
		local function outline()
			local h = Instance.new("Highlight")
			h.Name = "ShadowOutline"
			h.FillColor = Color3.fromRGB(120, 60, 255)
			h.FillTransparency = 0.92
			h.OutlineColor = Color3.fromRGB(150, 95, 255)
			h.OutlineTransparency = 0.55
			h.DepthMode = Enum.HighlightDepthMode.Occluded
			h.Parent = model
		end
		local function shell(names, grow)
			for _, name in ipairs(names) do
				local src = model:FindFirstChild(name)
				if src then
					local sh = part(name .. "Shell", src.Size + Vector3.one * grow, src.CFrame, Color3.fromRGB(120, 60, 255), Enum.Material.ForceField)
					sh.CastShadow = false
					weld(src, sh)
				end
			end
		end

		shell({ "Chest", "Hips", "Head" }, 0.12)
		smokePool(Vector3.new(2.0, 0.1, 3.4), Vector3.new(0, 0.15, -0.1), 10)
		wisps(chest, Vector3.new(0.6, 0.2, 1.2), Vector3.new(0, 2.7, -0.2), 3)
		-- dark flames licking up off the body (the same ethereal layer as the Zombie's shadow form)
		local FIRE_TEXTURE = "rbxasset://textures/particles/fire_main.dds"
		local function darkFlames(to, size, at, rate)
			local src = deco(to, "FlameSource", size, at, Color3.new(), SMOOTH)
			src.Transparency = 1
			local f = Instance.new("ParticleEmitter")
			f.Name = "ShadowFlames"
			f.Texture = FIRE_TEXTURE
			f.Color = ColorSequence.new(Color3.fromRGB(40, 16, 80), Color3.fromRGB(8, 4, 16))
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
			g.Color = ColorSequence.new(Color3.fromRGB(120, 60, 255))
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
		darkFlames(chest, Vector3.new(0.5, 0.25, 1.2), Vector3.new(0, 2.78, -0.3), 12)
		darkFlames(hips, Vector3.new(0.6, 0.25, 0.6), Vector3.new(0, 2.05, 1.0), 6)
		outline()
	end

	model:SetAttribute("Rig", "Procedural")
	model:SetAttribute("Pose", "Crawler")
	model:SetAttribute("AttackStyle", "Pounce")
	model:SetAttribute("RootHeight", 2.0)
	model:SetAttribute("Height", 2.9)
	model.Parent = models

	local parts, joints = 0, 0
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then parts += 1 end
		if d:IsA("Motor6D") then joints += 1 end
	end
	return NAME .. ": " .. parts .. " parts, " .. joints .. " joints"
end

return build("Base") .. " | " .. build("Shadow")
