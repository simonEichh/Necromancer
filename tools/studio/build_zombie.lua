-- Builds the rigged Zombie in its two forms: ServerStorage.Models.Zombie (the base form, levels 0-9) and
-- ServerStorage.Models.Zombie_Shadow (the awakened shadow form, Economy.AWAKEN_LEVEL+; Army picks it at spawn).
-- Both share one shape and rig, so the animations are the same; only colours, materials and effects differ.
-- Base: a rotting grey-green corpse with bone shards, festering green wounds, a buzz of flies.
-- Shadow (v2, 2026-10-15, the first unit in the shadow-army art direction, Design.md): a raised corpse turned to shadow.
-- A lopsided brute: the right arm grotesquely swollen into a huge club of fused flesh with obsidian shards growing out
-- of it, the left arm withered to bone; a bloated, hunched body with a hump; a small head sunk low and forward with a
-- crooked, hanging jaw. Black / obsidian body; the shadow light (violet) burns in the eyes, the mouth and a core seen
-- through a tear in the chest; its accent, what it was in life, is the rot: sickly green glowing through the cracks and
-- the stitched belly. Rags of a burial suit and a snapped suspender. Shadow smoke pools at its feet and wisps off it.
-- Run in Studio's command bar / via the Studio MCP execute_luau (Edit mode), then run publish_unit_models.lua.
--
-- Rig conventions (see src/client/Modules/UnitAnimator.lua):
--   * front = -Z, character's right = +X, feet on y = 0, root part = HumanoidRootPart at y = 2.4
--   * Motor6Ds Root/Waist/Neck/Jaw/LShoulder/RShoulder/LElbow/RElbow/LHip/RHip/LKnee/RKnee, identity rest
--   * the big club arm is the RIGHT arm (the generic swing animates it)
--   * attributes: Rig = "Procedural", RootHeight, Height
local ServerStorage = game:GetService("ServerStorage")
local models = ServerStorage.Models

local SMOOTH = Enum.Material.SmoothPlastic
local NEON = Enum.Material.Neon
local SMOKE_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"
local SPARK_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"

local function build(FORM)
	local SHADOW = FORM == "Shadow"
	local NAME = SHADOW and "Zombie_Shadow" or "Zombie"

	local old = models:FindFirstChild(NAME)
	if old and old:GetAttribute("Rig") ~= "Procedural" then
		old.Name = NAME .. "_Old"
	elseif old then
		old:Destroy()
	end

	-- (the names come from the shadow form; the base form's colours are in the second column)
	local VOID = SHADOW and Color3.fromRGB(14, 13, 19) or Color3.fromRGB(78, 86, 66) -- the body / rotten grey-green flesh
	local OBSIDIAN = SHADOW and Color3.fromRGB(30, 28, 40) or Color3.fromRGB(58, 62, 50) -- plates, a second black / bruised flesh
	local RIM = SHADOW and Color3.fromRGB(48, 44, 62) or Color3.fromRGB(214, 204, 176) -- edges, tips, teeth / bone
	local SHARD = SHADOW and OBSIDIAN or Color3.fromRGB(200, 190, 160) -- the shards: obsidian / bone breaking through
	local RAG = SHADOW and Color3.fromRGB(24, 21, 28) or Color3.fromRGB(56, 50, 58) -- the burial suit
	local VIOLET = SHADOW and Color3.fromRGB(96, 40, 210) or Color3.fromRGB(92, 22, 26) -- chest core, mouth / raw flesh
	local VIOLET_HOT = SHADOW and Color3.fromRGB(150, 95, 255) or Color3.fromRGB(205, 215, 120) -- the eyes / sickly yellow-green
	local GLOW = SHADOW and NEON or SMOOTH -- (the base form's core and mouth are flesh, they do not shine)
	local ROT = Color3.fromRGB(70, 150, 25) -- the accent in both forms: rot glowing through the cracks

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

	-- a part stretched between two points (w x h cross-section), welded to `to`
	local function bar(name, a, b, w, h, color, to, material)
		local up = math.abs((b - a).Unit.Y) > 0.95 and Vector3.xAxis or Vector3.yAxis
		local p = part(name, Vector3.new(w, h or w, (b - a).Magnitude), CFrame.lookAt((a + b) / 2, b, up), color, material)
		weld(to, p)
		return p
	end

	-- a jagged glowing crack: a few short neon bars zig-zagging from a to b, a hair proud of the surface
	local function crack(to, a, b, color, segments, jag)
		local prev = a
		for i = 1, segments do
			local f = i / segments
			local nextP = a:Lerp(b, f)
			if i < segments then
				nextP += Vector3.new((i % 2 == 0 and 1 or -1) * jag, 0, (i % 2 == 0 and -1 or 1) * jag * 0.5)
			end
			bar("Crack", prev, nextP, 0.06, 0.06, color, to, NEON)
			prev = nextP
		end
	end

	local function light(parentPart, color, range, brightness)
		local l = Instance.new("PointLight")
		l.Color = color
		l.Range = range
		l.Brightness = brightness
		l.Shadows = false
		l.Parent = parentPart
		return l
	end

	-- ── Core ──────────────────────────────────────────────────────
	local root = part("HumanoidRootPart", Vector3.new(1.6, 0.4, 1.0), Vector3.new(0, 2.4, 0), VOID)
	root.Transparency = 1
	model.PrimaryPart = root

	local pelvis = part("Pelvis", Vector3.new(1.4, 0.55, 1.0), Vector3.new(0, 2.25, 0), VOID)
	motor("Root", root, pelvis, Vector3.new(0, 2.4, 0))
	-- burial-suit trousers hanging in tatters over the hips
	deco(pelvis, "Trousers", Vector3.new(1.48, 0.4, 1.06), Vector3.new(0, 2.15, 0), RAG, Enum.Material.Fabric)
	for i, s in ipairs({ { -0.5, 0.45, -0.52 }, { 0.15, 0.6, -0.52 }, { 0.55, 0.38, 0.52 }, { -0.25, 0.5, 0.52 } }) do
		local x, h, z = s[1], s[2], s[3]
		deco(pelvis, "Tatter" .. i, Vector3.new(0.3, h, 0.04), CFrame.new(x, 1.95 - h / 2, z) * CFrame.Angles(0, 0, (i % 2 == 0) and 0.12 or -0.1), RAG, Enum.Material.Fabric)
	end

	-- ── Body: bloated belly, a broad hunched chest, a hump, the right side swollen ──
	local torso = part("Torso", Vector3.new(1.75, 1.25, 1.35), Vector3.new(0, 3.05, -0.12), VOID)
	motor("Waist", pelvis, torso, Vector3.new(0, 2.5, 0))
	deco(torso, "Chest", Vector3.new(1.95, 0.95, 1.2), CFrame.new(0.15, 3.8, 0.02) * CFrame.Angles(-0.22, 0, -0.08), VOID)
	deco(torso, "Hump", Vector3.new(1.35, 0.75, 0.85), CFrame.new(0.2, 4.2, 0.45) * CFrame.Angles(-0.4, 0, -0.1), OBSIDIAN)
	deco(torso, "RightMass", Vector3.new(1.05, 0.95, 1.15), CFrame.new(0.95, 4.02, 0.02) * CFrame.Angles(0, 0, -0.25), VOID)
	deco(torso, "LeftShoulder", Vector3.new(0.55, 0.45, 0.6), CFrame.new(-0.82, 3.82, 0.02) * CFrame.Angles(0, 0, 0.3), OBSIDIAN)
	-- obsidian plates grown over the back and the swollen shoulder
	for i, s in ipairs({ { 0.1, 4.55, 0.55, -0.6 }, { 0.55, 4.45, 0.4, -0.5 }, { -0.3, 4.35, 0.62, -0.7 }, { 1.05, 4.5, 0.05, -0.2 } }) do
		deco(torso, "Plate" .. i, Vector3.new(0.5, 0.18, 0.6), CFrame.new(s[1], s[2], s[3]) * CFrame.Angles(s[4], 0.2 * i, 0.15), RIM)
	end
	-- shards breaking out along the spine
	for i, s in ipairs({ { 0.05, 4.62, 0.75, 0.35 }, { 0.35, 4.5, 0.82, 0.45 }, { -0.25, 4.3, 0.85, 0.4 } }) do
		deco(torso, "SpineShard" .. i, Vector3.new(0.14, 0.6 - i * 0.08, 0.14), CFrame.new(s[1], s[2], s[3]) * CFrame.Angles(s[4] + 0.5, 0, 0), SHARD)
	end

	-- the stitched belly: a rot-green seam held shut by black stitches
	local seamTop, seamBottom = Vector3.new(-0.15, 3.45, -0.8), Vector3.new(0.05, 2.55, -0.8)
	bar("BellySeam", seamTop, seamBottom, 0.08, 0.08, ROT, torso, NEON)
	for i = 0, 4 do
		local p = seamTop:Lerp(seamBottom, (i + 0.5) / 5)
		deco(torso, "Stitch", Vector3.new(0.3, 0.05, 0.05), CFrame.new(p + Vector3.new(0, 0, -0.02)) * CFrame.Angles(0, 0, 0.5), VOID)
	end
	crack(torso, Vector3.new(0.6, 3.3, -0.79), Vector3.new(0.85, 2.7, -0.7), ROT, 3, 0.07)
	crack(torso, Vector3.new(-0.88, 3.5, -0.3), Vector3.new(-0.89, 2.8, -0.1), ROT, 3, 0.05)

	-- a tear in the chest: dark ribs over the violet shadow core
	deco(torso, "ChestTear", Vector3.new(0.7, 0.55, 0.08), CFrame.new(-0.3, 3.72, -0.62) * CFrame.Angles(-0.22, 0, 0.1), Color3.fromRGB(4, 3, 8))
	local core = deco(torso, "Core", Vector3.new(0.5, 0.36, 0.06), CFrame.new(-0.3, 3.72, -0.6) * CFrame.Angles(-0.22, 0, 0.1), VIOLET, GLOW)
	for i = 0, 2 do
		deco(torso, "Rib", Vector3.new(0.78, 0.07, 0.07), CFrame.new(-0.3, 3.86 - i * 0.15, -0.68 + i * 0.03) * CFrame.Angles(-0.22, 0, 0.1), OBSIDIAN)
	end
	if SHADOW then
		light(core, VIOLET, 6, 1.4)
	end

	-- the snapped suspender of the burial suit: over the left shoulder, the other strap hanging loose
	bar("Suspender", Vector3.new(-0.55, 4.05, -0.6), Vector3.new(-0.4, 2.5, -0.74), 0.1, 0.04, RAG, torso, Enum.Material.Fabric)
	bar("SuspenderBroken", Vector3.new(0.5, 2.55, -0.74), Vector3.new(0.62, 1.95, -0.62), 0.1, 0.04, RAG, torso, Enum.Material.Fabric)

	-- ── Head: small for the body, sunk low and forward, the jaw hanging crooked ──
	local head = part("Head", Vector3.new(0.8, 0.72, 0.8), Vector3.new(-0.12, 4.38, -0.68), VOID)
	motor("Neck", torso, head, Vector3.new(-0.08, 4.2, -0.35))
	deco(head, "Brow", Vector3.new(0.86, 0.16, 0.24), CFrame.new(-0.12, 4.56, -1.02) * CFrame.Angles(0, 0, -0.08), OBSIDIAN)
	deco(head, "Skullcap", Vector3.new(0.7, 0.18, 0.66), Vector3.new(-0.14, 4.8, -0.64), OBSIDIAN)
	-- the eyes: lopsided, the left one bigger; the shadow light burns in both
	local eyeL = deco(head, "Eye", Vector3.new(0.2, 0.13, 0.06), CFrame.new(-0.32, 4.42, -1.08) * CFrame.Angles(0, 0, -0.15), VIOLET_HOT, NEON)
	deco(head, "Eye", Vector3.new(0.13, 0.08, 0.06), CFrame.new(0.06, 4.45, -1.08) * CFrame.Angles(0, 0, 0.2), VIOLET_HOT, NEON)
	light(eyeL, SHADOW and VIOLET or Color3.fromRGB(150, 200, 60), 3.5, SHADOW and 1.2 or 0.6)
	crack(head, Vector3.new(0.12, 4.88, -0.9), Vector3.new(0.25, 4.5, -1.07), ROT, 2, 0.04)

	local jaw = part("Jaw", Vector3.new(0.66, 0.2, 0.62), CFrame.new(-0.18, 3.98, -0.8) * CFrame.Angles(0.15, 0, 0.22), OBSIDIAN)
	motor("Jaw", head, jaw, Vector3.new(-0.12, 4.15, -0.5))
	-- the mouth glows from inside, jagged teeth in front of it
	deco(jaw, "MouthGlow", Vector3.new(0.5, 0.06, 0.4), CFrame.new(-0.16, 4.1, -0.86) * CFrame.Angles(0.15, 0, 0.22), VIOLET, GLOW)
	for i = 0, 4 do
		deco(jaw, "Tooth", Vector3.new(0.07, 0.16, 0.07), CFrame.new(-0.36 + i * 0.1, 4.15 + i * 0.022, -1.08) * CFrame.Angles(0, 0, 0.22 + (i % 2) * 0.2), RIM)
	end

	-- ── Right arm: the club ──────────────────────────────────────
	local rUpper = part("RUpperArm", Vector3.new(0.9, 1.25, 0.95), CFrame.new(1.42, 3.3, 0) * CFrame.Angles(0, 0, 0.08), VOID)
	motor("RShoulder", torso, rUpper, Vector3.new(1.2, 3.95, 0))
	deco(rUpper, "ElbowMass", Vector3.new(0.95, 0.6, 0.95), Vector3.new(1.5, 2.65, 0.05), OBSIDIAN)
	local rFore = part("RForearm", Vector3.new(1.2, 1.4, 1.15), CFrame.new(1.55, 1.95, -0.05) * CFrame.Angles(0, 0, -0.04), VOID)
	motor("RElbow", rUpper, rFore, Vector3.new(1.5, 2.65, 0))
	-- the fused fist: a knuckled mass of flesh and obsidian
	local fist = deco(rFore, "Fist", Vector3.new(1.35, 0.75, 1.3), Vector3.new(1.58, 1.05, -0.08), VOID)
	if SHADOW then
	-- a dark violet smoke trail behind the fist: invisible at rest, a smear of shadow when the club swings
	local trailA = Instance.new("Attachment")
	trailA.Name = "TrailTop"
	trailA.Position = Vector3.new(0, 0.3, 0)
	trailA.Parent = fist
	local trailB = Instance.new("Attachment")
	trailB.Name = "TrailBottom"
	trailB.Position = Vector3.new(0, -0.45, 0)
	trailB.Parent = fist
	local trail = Instance.new("Trail")
	trail.Name = "ShadowSmear"
	trail.Attachment0 = trailA
	trail.Attachment1 = trailB
	trail.Color = ColorSequence.new(Color3.fromRGB(110, 50, 230), Color3.fromRGB(20, 10, 36))
	trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) })
	trail.LightEmission = 0.4
	trail.LightInfluence = 0
	trail.Lifetime = 0.22
	trail.MinLength = 0.05
	trail.WidthScale = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0.3) })
	trail.FaceCamera = false
	trail.Parent = fist
	end
	for i = 0, 3 do
		deco(rFore, "Knuckle", Vector3.new(0.3, 0.3, 0.32), Vector3.new(1.1 + i * 0.31, 0.95, -0.7), OBSIDIAN)
	end
	-- obsidian shards growing out of the outside and the back of the arm
	for i, s in ipairs({
		{ Vector3.new(2.08, 2.2, 0.0), CFrame.Angles(0, 0, -1.1), 0.75 },
		{ Vector3.new(2.1, 1.6, 0.25), CFrame.Angles(0.3, 0, -1.2), 0.6 },
		{ Vector3.new(1.75, 2.3, 0.6), CFrame.Angles(1.1, 0, -0.3), 0.7 },
		{ Vector3.new(1.95, 3.6, 0.3), CFrame.Angles(0.5, 0, -0.9), 0.55 },
		{ Vector3.new(1.6, 1.3, 0.62), CFrame.Angles(1.2, 0, 0.1), 0.5 },
	}) do
		local to = (s[1].Y > 2.65) and rUpper or rFore
		deco(to, "Shard" .. i, Vector3.new(0.16, s[3], 0.16), CFrame.new(s[1]) * s[2], SHARD)
		deco(to, "ShardTip" .. i, Vector3.new(0.1, 0.12, 0.1), CFrame.new(s[1]) * s[2] * CFrame.new(0, s[3] / 2, 0), RIM)
	end
	-- rot cracks running down the club
	crack(rFore, Vector3.new(1.0, 2.5, -0.5), Vector3.new(1.1, 1.3, -0.62), ROT, 4, 0.08)
	crack(rFore, Vector3.new(2.13, 2.45, -0.3), Vector3.new(2.2, 1.35, -0.2), ROT, 3, 0.06)
	crack(rUpper, Vector3.new(1.4, 3.85, -0.48), Vector3.new(1.55, 2.95, -0.48), ROT, 3, 0.06)

	-- ── Left arm: withered to bone ────────────────────────────────
	local lUpper = part("LUpperArm", Vector3.new(0.26, 0.95, 0.26), Vector3.new(-0.95, 3.2, 0), VOID)
	motor("LShoulder", torso, lUpper, Vector3.new(-0.95, 3.68, 0))
	deco(lUpper, "ElbowKnob", Vector3.new(0.3, 0.26, 0.3), Vector3.new(-0.95, 2.72, 0.02), OBSIDIAN)
	local lFore = part("LForearm", Vector3.new(0.2, 0.92, 0.2), Vector3.new(-0.97, 2.25, -0.02), VOID)
	motor("LElbow", lUpper, lFore, Vector3.new(-0.95, 2.72, 0))
	deco(lFore, "LHand", Vector3.new(0.26, 0.22, 0.24), Vector3.new(-0.98, 1.7, -0.04), OBSIDIAN)
	for i, z in ipairs({ -0.08, 0, 0.08 }) do
		bar("Finger", Vector3.new(-0.98, 1.6, z - 0.04), Vector3.new(-1.0 - 0.02 * i, 1.3, z - 0.14), 0.05, 0.05, OBSIDIAN, lFore)
	end

	-- ── Legs: short and thick, the right one heavier ──────────────
	local function leg(side, x, thick)
		local upper = part(side .. "UpperLeg", Vector3.new(0.62 * thick, 0.95, 0.62 * thick), Vector3.new(x, 1.6, 0), VOID)
		motor(side .. "Hip", pelvis, upper, Vector3.new(x, 2.05, 0))
		deco(upper, "Knee", Vector3.new(0.5 * thick, 0.3, 0.45), Vector3.new(x, 1.14, -0.12), OBSIDIAN)
		local lower = part(side .. "LowerLeg", Vector3.new(0.52 * thick, 0.95, 0.52 * thick), Vector3.new(x, 0.62, 0), VOID)
		motor(side .. "Knee", upper, lower, Vector3.new(x, 1.12, 0))
		deco(lower, "Foot" .. side, Vector3.new(0.62 * thick, 0.24, 0.95), Vector3.new(x, 0.12, -0.18), OBSIDIAN)
		deco(lower, "Rag", Vector3.new(0.58 * thick, 0.35, 0.58 * thick), Vector3.new(x, 0.95, 0), RAG, Enum.Material.Fabric)
		return lower
	end
	leg("L", -0.48, 1.0)
	local rLower = leg("R", 0.5, 1.2)
	crack(rLower, Vector3.new(0.82, 0.95, -0.2), Vector3.new(0.84, 0.35, -0.25), ROT, 2, 0.05)

	-- ── Shadow smoke (shadow form only) ───────────────────────────
	if SHADOW then
	-- 1. a pool of black smoke at its feet (an invisible slab on the root, so it follows the body but not the limbs)
	local pool = part("SmokePool", Vector3.new(2.6, 0.1, 2.0), Vector3.new(0.2, 0.15, 0), VOID)
	pool.Transparency = 1
	weld(root, pool)
	local poolSmoke = Instance.new("ParticleEmitter")
	poolSmoke.Name = "ShadowPool"
	poolSmoke.Texture = SMOKE_TEXTURE
	poolSmoke.Color = ColorSequence.new(Color3.fromRGB(14, 8, 26), Color3.fromRGB(46, 22, 84))
	poolSmoke.LightInfluence = 0 -- (unlit: it keeps its own dark violet instead of vanishing into the dark scene)
	poolSmoke.LightEmission = 0
	poolSmoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.0), NumberSequenceKeypoint.new(0.5, 2.0), NumberSequenceKeypoint.new(1, 2.7) })
	poolSmoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0.3), NumberSequenceKeypoint.new(0.7, 0.55), NumberSequenceKeypoint.new(1, 1) })
	poolSmoke.Lifetime = NumberRange.new(1.6, 2.4)
	poolSmoke.Rate = 10
	poolSmoke.Speed = NumberRange.new(0.1, 0.4)
	poolSmoke.Acceleration = Vector3.new(0, 0.3, 0)
	poolSmoke.Drag = 1
	poolSmoke.Rotation = NumberRange.new(0, 360)
	poolSmoke.RotSpeed = NumberRange.new(-25, 25)
	poolSmoke.EmissionDirection = Enum.NormalId.Top
	poolSmoke.Parent = pool
	-- a faint violet glow inside the pool
	local poolGlow = Instance.new("ParticleEmitter")
	poolGlow.Name = "ShadowPoolGlow"
	poolGlow.Texture = SMOKE_TEXTURE
	poolGlow.Color = ColorSequence.new(Color3.fromRGB(110, 50, 230))
	poolGlow.LightEmission = 1
	poolGlow.LightInfluence = 0
	poolGlow.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 1.9) })
	poolGlow.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.72), NumberSequenceKeypoint.new(1, 1) })
	poolGlow.Lifetime = NumberRange.new(1.2, 1.8)
	poolGlow.Rate = 5
	poolGlow.Speed = NumberRange.new(0.2, 0.5)
	poolGlow.Rotation = NumberRange.new(0, 360)
	poolGlow.EmissionDirection = Enum.NormalId.Top
	poolGlow.Parent = pool

	-- 2. dark vapour wisping off the body and the club (rises, drifts back as it walks)
	local function wisps(to, name, size, at, rate)
		local src = deco(to, name, size, at, VOID)
		src.Transparency = 1
		local e = Instance.new("ParticleEmitter")
		e.Name = "ShadowWisps"
		e.Texture = SMOKE_TEXTURE
		e.Color = ColorSequence.new(Color3.fromRGB(18, 10, 32), Color3.fromRGB(72, 36, 130))
		e.LightInfluence = 0
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1.1) })
		e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.25, 0.4), NumberSequenceKeypoint.new(1, 1) })
		e.Lifetime = NumberRange.new(0.9, 1.5)
		e.Rate = rate
		e.Speed = NumberRange.new(0.4, 1.0)
		e.Acceleration = Vector3.new(0, 1.6, 0)
		e.Drag = 1.5
		e.Rotation = NumberRange.new(0, 360)
		e.RotSpeed = NumberRange.new(-40, 40)
		e.SpreadAngle = Vector2.new(30, 30)
		e.EmissionDirection = Enum.NormalId.Top
		e.Parent = src
		return e
	end
	wisps(torso, "WispsBack", Vector3.new(1.2, 0.3, 0.6), Vector3.new(0.2, 4.5, 0.45), 4)
	wisps(rFore, "WispsClub", Vector3.new(1.0, 0.8, 0.9), Vector3.new(1.58, 1.6, -0.05), 3)

	end

	-- the base form: a buzz of flies round its head
	if not SHADOW then
		local fliesSrc = deco(head, "Flies", Vector3.new(1.2, 0.8, 1.2), Vector3.new(-0.12, 4.6, -0.6), VOID)
		fliesSrc.Transparency = 1
		local flies = Instance.new("ParticleEmitter")
		flies.Name = "Flies"
		flies.Texture = SPARK_TEXTURE
		flies.Color = ColorSequence.new(Color3.fromRGB(10, 10, 10))
		flies.LightEmission = 0
		flies.LightInfluence = 1
		flies.Size = NumberSequence.new(0.09)
		flies.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.8, 0), NumberSequenceKeypoint.new(1, 1) })
		flies.Lifetime = NumberRange.new(0.5, 0.9)
		flies.Rate = 7
		flies.Speed = NumberRange.new(2, 3.5)
		flies.SpreadAngle = Vector2.new(180, 180)
		flies.Drag = 4
		flies.RotSpeed = NumberRange.new(-200, 200)
		flies.Parent = fliesSrc
	end

	-- 3. rot motes: a few green embers drifting up from the club's cracks
	local motesSrc = deco(rFore, "RotMotes", Vector3.new(1.1, 1.2, 1.1), Vector3.new(1.55, 1.9, -0.05), VOID)
	motesSrc.Transparency = 1
	local motes = Instance.new("ParticleEmitter")
	motes.Name = "RotMotes"
	motes.Texture = SPARK_TEXTURE
	motes.Color = ColorSequence.new(ROT)
	motes.LightEmission = 1
	motes.LightInfluence = 0
	motes.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.12), NumberSequenceKeypoint.new(1, 0) })
	motes.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	motes.Lifetime = NumberRange.new(0.8, 1.4)
	motes.Rate = 3
	motes.Speed = NumberRange.new(0.3, 0.8)
	motes.Acceleration = Vector3.new(0, 1.2, 0)
	motes.SpreadAngle = Vector2.new(60, 60)
	motes.EmissionDirection = Enum.NormalId.Top
	motes.Parent = motesSrc

	-- ── Ethereal layer (set ETHEREAL = false for the plain version, commit e891592) ──
	-- 1. a ForceField shell: slightly larger violet copies of the big masses, shimmering over the black
	-- 2. dark flames licking up off the shoulders, the hump and the club
	-- 3. a faint violet fill over the whole body (on the outline Highlight below)
	local ETHEREAL = SHADOW -- (true = the ethereal layer on the shadow form)
	if ETHEREAL then
		local SHELL = { "Torso", "Chest", "Hump", "RightMass", "RUpperArm", "RForearm", "Fist", "ElbowMass", "Head" }
		local SHELL_GROW = 0.12 -- studs added on every axis
		for _, name in ipairs(SHELL) do
			local src = model:FindFirstChild(name)
			if src then
				local shell = part(name .. "Shell", src.Size + Vector3.one * SHELL_GROW, src.CFrame, Color3.fromRGB(120, 60, 255), Enum.Material.ForceField)
				shell.CastShadow = false
				weld(src, shell)
			end
		end

		local FIRE_TEXTURE = "rbxasset://textures/particles/fire_main.dds"
		local function darkFlames(to, name, size, at, rate)
			local src = deco(to, name, size, at, VOID)
			src.Transparency = 1
			-- black-violet tongues (unlit, so they stay dark against anything) ...
			local f = Instance.new("ParticleEmitter")
			f.Name = "ShadowFlames"
			f.Texture = FIRE_TEXTURE
			f.Color = ColorSequence.new(Color3.fromRGB(40, 16, 80), Color3.fromRGB(8, 4, 16))
			f.LightEmission = 0
			f.LightInfluence = 0
			f.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 0.1) })
			f.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 1) })
			f.Lifetime = NumberRange.new(0.45, 0.8)
			f.Rate = rate
			f.Speed = NumberRange.new(1.5, 3)
			f.Acceleration = Vector3.new(0, 2, 0)
			f.Rotation = NumberRange.new(-15, 15)
			f.SpreadAngle = Vector2.new(15, 15)
			f.EmissionDirection = Enum.NormalId.Top
			f.Parent = src
			-- ... with a thin violet glow at their roots
			local g = Instance.new("ParticleEmitter")
			g.Name = "ShadowFlameGlow"
			g.Texture = FIRE_TEXTURE
			g.Color = ColorSequence.new(Color3.fromRGB(120, 60, 255))
			g.LightEmission = 1
			g.LightInfluence = 0
			g.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0.05) })
			g.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) })
			g.Lifetime = NumberRange.new(0.25, 0.45)
			g.Rate = rate * 0.6
			g.Speed = NumberRange.new(1, 2)
			g.EmissionDirection = Enum.NormalId.Top
			g.Parent = src
		end
		darkFlames(torso, "FlamesBack", Vector3.new(1.6, 0.3, 0.8), Vector3.new(0.2, 4.6, 0.3), 14)
		darkFlames(torso, "FlamesShoulder", Vector3.new(0.9, 0.3, 0.9), Vector3.new(1.0, 4.45, 0), 8)
		darkFlames(rFore, "FlamesClub", Vector3.new(1.1, 0.4, 1.0), Vector3.new(1.58, 2.3, -0.05), 8)
	end

	-- the shadow's edge: a faint violet outline so the black body reads against a dark scene (shadow form only)
	if SHADOW then
	local outline = Instance.new("Highlight")
	outline.Name = "ShadowOutline"
	outline.FillColor = Color3.fromRGB(120, 60, 255)
	outline.FillTransparency = ETHEREAL and 0.9 or 1
	outline.OutlineColor = Color3.fromRGB(150, 95, 255)
	outline.OutlineTransparency = 0.55
	outline.DepthMode = Enum.HighlightDepthMode.Occluded
	outline.Parent = model
	end

	model:SetAttribute("Rig", "Procedural")
	model:SetAttribute("AttackStyle", "Slam")
	model:SetAttribute("RootHeight", 2.4)
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
