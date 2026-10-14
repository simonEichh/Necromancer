-- Builds the Realm 1 keeper's HANDS into ServerStorage.TitanModels.GravekeeperHands: the Gravekeeper himself stays
-- hidden (his full model, build_titan_gravekeeper.lua, is kept for the world boss); behind every claimed lane two torn
-- rifts hang in the air on either side of the gate tower, his forearms come out of them in tattered sleeves and his
-- bony hands rest on the battlements; high above and behind the gate tower his two eyes glow in a cloud of black fog.
-- Placed by the server module Titans (origin = the outer wall's inner top edge on the lane's axis, -Z towards the
-- arena, +X = to the right as seen from the arena... see below), animated on the clients by Modules/HandsAnimator.
--
-- Rig (Motor6D.Transform is animated; identity = the resting pose baked here):
--   Root (anchored, invisible, PrimaryPart, at the origin)
--   LArm / RArm        Root -> <S>Arm     at the rift's centre; the arm bone's -Z runs along the forearm to the wrist
--   LWrist / RWrist    <S>Arm -> <S>Hand
--   <S>Finger<k>a/b, <S>Thumba/b   like the Gravekeeper's (tips: parts <S>Finger<k>Tip, used by the weave's threads)
-- Rifts: models "RiftL" / "RiftR" (anchored; "Swirl" inside is turned by the client round the rift's normal; part
-- "Motes" and "Mist" carry emitters; attribute Normal), "EyeRift" (no rift any more: part "Fog" with black fog, and
-- models "EyeL" / "EyeR" (part Eye;
-- the client blinks and aims them).
-- Model space: y = 0 is the wall's top, z = 0 its inner face (the arena side), z = +12 its outer face; x = 0 the lane's
-- axis, +x = the model's right (the server mirrors nothing: "L" is at -x).
-- Run in Edit mode via the Studio MCP (or loadstring, see CLAUDE.md). Safe to re-run. Puts a preview on Plot1's lane
-- (Workspace.HandsPreview: delete it before publishing).
local ServerStorage = game:GetService("ServerStorage")

local folder = ServerStorage:FindFirstChild("TitanModels")
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "TitanModels"
	folder.Parent = ServerStorage
end
local old = folder:FindFirstChild("GravekeeperHands")
if old then
	old:Destroy()
end

local HS = 14 -- the Gravekeeper's design units -> studs (his own model uses 12; the hands alone are seen from far away)

-- palette (the Gravekeeper's)
local CLOAK = Color3.fromRGB(80, 104, 62)
local CLOAK_DARK = Color3.fromRGB(58, 74, 48)
local TRIM = Color3.fromRGB(30, 36, 30)
local BONE = Color3.fromRGB(226, 218, 196)
local BONE_DARK = Color3.fromRGB(190, 180, 158)
local NAIL = Color3.fromRGB(120, 110, 92)
local CHARCOAL = Color3.fromRGB(34, 35, 36)
local VOID = Color3.fromRGB(4, 5, 6)
local SOUL = Color3.fromRGB(50, 220, 130) -- saturated: paler greens blow out to white under the bloom
local SOUL_DIM = Color3.fromRGB(26, 110, 66)
local SWIRL = Color3.fromRGB(22, 64, 44)
local FLAP = Color3.fromRGB(16, 18, 16)

local rng = Random.new(7741)
local model = Instance.new("Model")
model.Name = "GravekeeperHands"

local function part(parent, name, size, cf, color, material, shape)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if shape then
		p.Shape = shape
	end
	p.Parent = parent
	return p
end

local function wedge(parent, name, size, cf, color)
	local p = Instance.new("WedgePart")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.Parent = parent
	return p
end

-- a block from a to b (its -Z runs along it), w x h thick
local function span(parent, name, a, b, w, h, color, material, upv)
	local len = (b - a).Magnitude
	return part(parent, name, Vector3.new(w, h or w, len), CFrame.lookAt((a + b) / 2, b, upv or Vector3.yAxis), color, material)
end

local function bone(name, cf)
	local p = part(model, name, Vector3.new(0.6, 0.6, 0.6), cf, CHARCOAL)
	p.Transparency = 1
	return p
end

local function weldAll(list, to)
	for _, p in ipairs(list) do
		if p ~= to then
			local w = Instance.new("WeldConstraint")
			w.Part0 = to
			w.Part1 = p
			w.Parent = p
		end
	end
end

local function joint(name, part0, part1, at)
	local jf = CFrame.new(at) * part1.CFrame.Rotation
	local m = Instance.new("Motor6D")
	m.Name = name
	m.Part0 = part0
	m.Part1 = part1
	m.C0 = part0.CFrame:ToObjectSpace(jf)
	m.C1 = part1.CFrame:ToObjectSpace(jf)
	m.Parent = part0
	return m
end

local function collect(fn)
	local before = {}
	for _, d in ipairs(model:GetDescendants()) do
		before[d] = true
	end
	fn()
	local list = {}
	for _, d in ipairs(model:GetDescendants()) do
		if not before[d] and d:IsA("BasePart") then
			table.insert(list, d)
		end
	end
	return list
end

local function rag(top, w, h, color)
	local cf = top * CFrame.Angles(math.rad(rng:NextNumber(-6, 6)), math.rad(rng:NextNumber(-8, 8)), math.rad(rng:NextNumber(-5, 5)))
	part(model, "Rag", Vector3.new(w, h, 0.18 * HS), cf * CFrame.new(0, -h / 2, 0), color, Enum.Material.Fabric)
	wedge(model, "RagTip", Vector3.new(0.18 * HS, 0.7 * HS, w * 0.5), cf * CFrame.new(rng:NextNumber(-w / 4, w / 4), -h - 0.35 * HS, 0)
		* CFrame.Angles(0, math.rad(90), math.rad(180)), color)
end

-- ============================================================
-- Root
-- ============================================================
local root = part(model, "Root", Vector3.new(1, 1, 1), CFrame.new(), CHARCOAL)
root.Transparency = 1
model.PrimaryPart = root

-- ============================================================
-- A torn rift: a ragged lens of void facing -Z of `cf`, a green rim with torn flaps, a dark swirl, motes, mist
-- ============================================================
local function rift(name, cf, w, h, opts)
	opts = opts or {}
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = model
	m:SetAttribute("Normal", cf.LookVector) -- (towards the arena)
	-- the outline: a lens, narrow at both ends, its edge jittered
	local n = opts.points or 22
	local pts = {}
	for k = 0, n - 1 do
		local a = k / n * 2 * math.pi
		local s = math.sin(a)
		local jitter = rng:NextNumber(0.86, 1.12)
		local x = (w / 2) * math.sign(s) * math.abs(s) ^ 0.8 * jitter
		local y = (h / 2) * math.cos(a) * rng:NextNumber(0.95, 1.04)
		pts[k + 1] = Vector2.new(x, y)
	end
	local function at(p, z)
		return cf * Vector3.new(p.X, p.Y, z or 0)
	end
	-- the void: horizontal slabs whose width follows the lens (deep enough to hide what is behind it)
	local rows = opts.rows or 16
	for i = 0, rows - 1 do
		local y0 = -h / 2 + (i + 0.5) * h / rows
		local half = (w / 2) * (1 - (2 * y0 / h) ^ 2) ^ 0.62 * 0.97
		if half > 0.4 then
			part(m, "Void", Vector3.new(half * 2, h / rows + 0.3, opts.depth or 3), cf * CFrame.new(0, y0, (opts.depth or 3) / 2), VOID)
		end
	end
	-- the rim: neon segments along the outline, a thinner dim one just outside; torn flaps sticking out
	for k = 1, n do
		local a, b = pts[k], pts[k % n + 1]
		local g = span(m, "Glow", at(a, -0.2), at(b, -0.2), opts.rim or 0.9, 0.6, opts.rimColor or SOUL, Enum.Material.Neon, cf.LookVector)
		g.Name = "Glow"
		if k % 2 == 0 then
			span(m, "RimOuter", at(a * 1.06, 0.1), at(b * 1.06, 0.1), (opts.rim or 0.9) * 0.6, 0.5, SOUL_DIM, Enum.Material.Neon, cf.LookVector)
		end
		if k % 3 == 0 then
			local out = (a.Magnitude > 0.01) and a.Unit or Vector2.new(0, 1)
			local len = rng:NextNumber(2.2, 4.6) * (opts.flapScale or 1)
			local base = at(a, 0.2)
			local tip = at(a + out * len, 0.6)
			span(m, "Flap", base, tip, rng:NextNumber(1.2, 2.2) * (opts.flapScale or 1), 0.3, FLAP, Enum.Material.SmoothPlastic, cf.LookVector)
		end
	end
	-- the swirl: dark streaks spiralling in front of the void (turned round the normal by the client)
	local swirl = Instance.new("Model")
	swirl.Name = "Swirl"
	swirl.Parent = m
	local hub = part(swirl, "Hub", Vector3.new(0.5, 0.5, 0.5), cf * CFrame.new(0, 0, -0.4), SWIRL)
	hub.Transparency = 1
	swirl.PrimaryPart = hub
	for arm = 0, (opts.swirlArms or 5) - 1 do
		local prev
		for s = 0, 5 do
			local r = 1 + s * (math.min(w, h) * 0.08)
			local a = arm / (opts.swirlArms or 5) * 2 * math.pi + s * 0.55
			local p = Vector2.new(math.cos(a) * r * (w / math.max(w, h)), math.sin(a) * r * (h / math.max(w, h)))
			local pos = at(p, -0.4)
			if prev then
				span(swirl, "Streak", prev, pos, 0.5 + s * 0.12, 0.2, SWIRL, Enum.Material.Neon, cf.LookVector)
			end
			prev = pos
		end
	end
	-- soul motes drifting out of the depth
	local motes = part(m, "Motes", Vector3.new(w * 0.55, h * 0.6, 0.5), cf * CFrame.new(0, 0, -0.3), SOUL)
	motes.Transparency = 1
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Shape = Enum.ParticleEmitterShape.Box
	e.Color = ColorSequence.new(SOUL)
	e.LightEmission = 1
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(0.5, opts.moteSize or 0.9), NumberSequenceKeypoint.new(1, 0) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.2), NumberSequenceKeypoint.new(1, 1) })
	e.Lifetime = NumberRange.new(3, 5)
	e.Speed = NumberRange.new(0.3, 1.2)
	e.EmissionDirection = Enum.NormalId.Front
	e.Rate = opts.moteRate or 7
	e.Parent = motes
	-- mist spilling out of the bottom and running down
	if opts.mist ~= false then
		local mist = part(m, "Mist", Vector3.new(w * 0.4, 1, 1), cf * CFrame.new(0, -h * 0.38, -0.6), FLAP)
		mist.Transparency = 1
		local me = Instance.new("ParticleEmitter")
		me.Texture = "rbxasset://textures/particles/smoke_main.dds"
		me.Shape = Enum.ParticleEmitterShape.Box
		me.Color = ColorSequence.new(Color3.fromRGB(70, 96, 84))
		me.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 4), NumberSequenceKeypoint.new(1, 13) })
		me.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.75), NumberSequenceKeypoint.new(0.4, 0.6), NumberSequenceKeypoint.new(1, 1) })
		me.Lifetime = NumberRange.new(5, 7)
		me.Speed = NumberRange.new(2, 4)
		me.EmissionDirection = Enum.NormalId.Bottom
		me.Acceleration = Vector3.new(0, -1.5, 0)
		me.Drag = 0.6
		me.Rotation = NumberRange.new(0, 360)
		me.RotSpeed = NumberRange.new(-10, 10)
		me.Rate = 3
		me.Parent = mist
	end
	-- a green glow on the surroundings
	local holder = part(m, "RiftLight", Vector3.new(0.5, 0.5, 0.5), cf * CFrame.new(0, 0, -4), SOUL)
	holder.Transparency = 1
	local light = Instance.new("PointLight")
	light.Color = SOUL
	light.Range = opts.lightRange or 40
	light.Brightness = opts.lightBright or 1.6
	light.Shadows = false
	light.Parent = holder
	return m
end

-- ============================================================
-- The arms: from a rift's centre over the battlements, the hand draped over the inner edge
-- ============================================================
local function arm(prefix, side, portalPos, wristPos, handDir, fingerDirs, thumbDirs)
	local armCf = CFrame.lookAt(portalPos, wristPos)
	local length = (wristPos - portalPos).Magnitude
	local armBone = bone(prefix .. "Arm", armCf)
	local armParts = collect(function()
		-- the sleeve comes out of the rift (starting a little behind it) and covers about half the forearm
		-- four overlapping cloth sections, tapering towards the wrist, each a little twisted and offset (not one box)
		local sleeveFrom, sleeveTo = 5, -length * 0.5
		local SECTIONS = 4
		for k = 0, SECTIONS - 1 do
			local a = sleeveFrom + (sleeveTo - sleeveFrom) * (k / SECTIONS)
			local b = sleeveFrom + (sleeveTo - sleeveFrom) * ((k + 1) / SECTIONS)
			local width = (1.85 - 0.12 * k) * HS
			local cf = armCf * CFrame.new(rng:NextNumber(-0.06, 0.06) * HS, rng:NextNumber(-0.06, 0.06) * HS, (a + b) / 2)
				* CFrame.Angles(math.rad(rng:NextNumber(-4, 4)), math.rad(rng:NextNumber(-4, 4)), math.rad(rng:NextNumber(-14, 14)))
			part(model, "Sleeve", Vector3.new(width, width * rng:NextNumber(0.88, 0.98), math.abs(b - a) * 1.18), cf,
				k % 2 == 0 and CLOAK_DARK or CLOAK, Enum.Material.Fabric)
		end
		-- the cuff: a ragged ring of tatters of different lengths hanging over the bare bones
		local cuff = armCf * CFrame.new(0, 0, sleeveTo + 0.1 * HS)
		for k = 0, 7 do
			local a = k / 8 * 2 * math.pi + rng:NextNumber(-0.15, 0.15)
			local r = 0.78 * HS
			local len = rng:NextNumber(0.6, 1.5) * HS
			local root = cuff * CFrame.Angles(0, 0, a) * CFrame.new(0, r, 0)
			-- each tatter points along the arm towards the wrist, flaring out a little
			-- (a wedge's triangle lies in its Y-Z plane, full height at the back: rolled so X is radial, it lies flat on
			-- the sleeve and tapers in width to a point towards the wrist; turned a little outwards)
			wedge(model, "Tatter", Vector3.new(0.12 * HS, rng:NextNumber(0.5, 0.8) * HS, len),
				root * CFrame.Angles(0, 0, math.pi / 2) * CFrame.Angles(0, math.rad(-8), 0) * CFrame.new(0, 0, -len / 2),
				k % 2 == 0 and CLOAK or CLOAK_DARK)
		end
		for k = 1, 5 do
			rag(armCf * CFrame.new((k - 3) * 0.32 * HS, -0.8 * HS, -length * (0.06 + k * 0.08)), 0.6 * HS, rng:NextNumber(1.2, 2.4) * HS, k % 2 == 0 and CLOAK or CLOAK_DARK)
		end
		-- two bare bones from the cuff to the wrist
		for _, off in ipairs({ -0.22, 0.22 }) do
			local a = (armCf * CFrame.new(off * HS, 0, -length * 0.45)).Position
			local b = (CFrame.lookAt(wristPos, wristPos + armCf.LookVector) * CFrame.new(off * 0.6 * HS, 0, 0.2 * HS)).Position
			span(model, "ForearmBone", a, b, 0.34 * HS, 0.34 * HS, BONE)
		end
	end)
	weldAll(armParts, armBone)
	joint(prefix .. "Arm", root, armBone, portalPos)

	-- the hand: a bony palm along `handDir`, its frame's -Y is the palm side
	local handCf = CFrame.lookAt(wristPos, wristPos + handDir)
	local hand = bone(prefix .. "Hand", handCf * CFrame.new(0, 0, -0.75 * HS))
	local handParts = collect(function()
		part(model, "Palm", Vector3.new(1.5 * HS, 0.45 * HS, 1.5 * HS), handCf * CFrame.new(0, 0, -0.75 * HS), BONE)
		part(model, "Wrist", Vector3.new(0.7 * HS, 0.5 * HS, 0.5 * HS), handCf * CFrame.new(0, 0, -0.05 * HS), BONE_DARK)
		for _, x in ipairs({ -0.4, 0.4 }) do
			part(model, "WristBone", Vector3.new(0.32, 0.32, 0.32) * HS, handCf * CFrame.new(x * HS, 0.05 * HS, -0.1 * HS), BONE_DARK, nil, Enum.PartType.Ball)
		end
		-- knuckle ridges on the back of the hand
		for k = 1, 4 do
			part(model, "Ridge", Vector3.new(0.18, 0.12, 0.9) * HS, handCf * CFrame.new(((k - 2.5) * 0.36) * HS, 0.25 * HS, -0.85 * HS), BONE_DARK)
		end
	end)
	weldAll(handParts, hand)
	joint(prefix .. "Wrist", armBone, hand, wristPos)

	local function finger(name, knuckle, d1, d2, len1, len2, thick)
		local a = knuckle
		local b = a + handCf:VectorToWorldSpace(d1.Unit) * len1
		local c = b + handCf:VectorToWorldSpace(d2.Unit) * len2
		local s1 = span(model, name .. "a", a, b, thick, thick, BONE, nil, handCf.UpVector)
		local s2 = span(model, name .. "b", b, c, thick * 0.85, thick * 0.85, BONE, nil, handCf.UpVector)
		local tip = part(model, name .. "Tip", Vector3.new(thick * 0.7, thick * 0.7, 0.36 * HS), CFrame.lookAt(c, c + (c - b)) * CFrame.new(0, 0, -0.12 * HS), NAIL)
		local knob = part(model, name .. "Knuckle", Vector3.one * thick * 1.25, CFrame.new(b), BONE_DARK, nil, Enum.PartType.Ball)
		weldAll({ tip }, s2)
		weldAll({ knob }, s1)
		joint(name .. "a", hand, s1, a)
		joint(name .. "b", s1, s2, b)
	end
	for k = 1, 4 do
		local x = (k - 2.5) * 0.36 * HS
		local d = fingerDirs[k]
		finger(prefix .. "Finger" .. k, (handCf * CFrame.new(x, 0, -1.45 * HS)).Position, d[1], d[2], (0.95 - math.abs(k - 2.5) * 0.08) * HS, 0.85 * HS, 0.3 * HS)
	end
	finger(prefix .. "Thumb", (handCf * CFrame.new(-side * 0.7 * HS, -0.05 * HS, -0.6 * HS)).Position, thumbDirs[1], thumbDirs[2], 0.7 * HS, 0.6 * HS, 0.32 * HS)
	return hand
end

-- the rifts beside the gate tower (its cornice is 31 wide), behind the wall and above its top, turned a little to the lane
local RIFT_X, RIFT_Y, RIFT_Z = 58, 54, 36 -- (high enough that the void shows above the battlements from the plot)
local RIFT_W, RIFT_H = 34, 50
local ARM_DROP = 13 -- the arms come out of the lower part of the rift, so the void and its swirl show above them
local REST_X = 37 -- where the wrists lie on the battlements
for _, side in ipairs({ -1, 1 }) do
	local prefix = side < 0 and "L" or "R"
	local centre = Vector3.new(side * RIFT_X, RIFT_Y, RIFT_Z)
	-- facing the arena (-Z), turned a little towards the lane's axis and leaning back
	local cf = CFrame.new(centre) * CFrame.Angles(0, side * math.rad(-14), 0) * CFrame.Angles(math.rad(-6), 0, 0)
	rift("Rift" .. prefix, cf, RIFT_W, RIFT_H)
	local wrist = Vector3.new(side * REST_X, 2.2, 3.4)
	-- the hand drapes over the inner edge: palm down and inwards, fingers curling down the arena side (mirrored for L)
	local mx = side
	arm(prefix, side, (cf * CFrame.new(0, -ARM_DROP, 0)).Position, wrist, Vector3.new(0.12 * mx, -0.75, -0.65).Unit, {
		{ Vector3.new(0, -0.6, -1), Vector3.new(0, -1, -0.3) },
		{ Vector3.new(0, -0.6, -1), Vector3.new(0, -1, -0.2) },
		{ Vector3.new(0, -0.5, -1), Vector3.new(0, -1, -0.3) },
		{ Vector3.new(0.1 * mx, -0.5, -1), Vector3.new(0, -1, -0.4) },
	}, { Vector3.new(-0.6 * mx, -0.4, -1), Vector3.new(-0.2 * mx, -1, -0.5) })
end

-- ============================================================
-- The eye rift: a dark slit high above and behind the gate tower, two eyes inside
-- ============================================================
do
	local centre = Vector3.new(0, 108, 50) -- (above the gate tower's top as seen from the plot)
	local cf = CFrame.new(centre) * CFrame.Angles(math.rad(-10), 0, 0)
	-- no rift: only the eyes, hanging in a slowly drifting cloud of black fog (a faint green glow tints it near them)
	local m = Instance.new("Model")
	m.Name = "EyeRift"
	m.Parent = model
	local fog = part(m, "Fog", Vector3.new(34, 10, 8), cf * CFrame.new(0, 0, 2), VOID)
	fog.Transparency = 1
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	e.Shape = Enum.ParticleEmitterShape.Box
	e.Color = ColorSequence.new(Color3.fromRGB(8, 10, 9))
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 12), NumberSequenceKeypoint.new(1, 28) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0.12), NumberSequenceKeypoint.new(0.7, 0.3), NumberSequenceKeypoint.new(1, 1) })
	e.Lifetime = NumberRange.new(6, 9)
	e.Speed = NumberRange.new(0.4, 1.4)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-8, 8)
	e.Drag = 0.5
	e.Rate = 16
	e.Parent = fog
	local glow = Instance.new("PointLight")
	glow.Color = SOUL
	glow.Range = 20
	glow.Brightness = 0.7
	glow.Shadows = false
	glow.Parent = fog
	for _, side in ipairs({ -1, 1 }) do
		local eye = Instance.new("Model")
		eye.Name = side < 0 and "EyeL" or "EyeR"
		eye.Parent = m
		-- the Gravekeeper's own eyes: thin slanted soul-green slits (his hood's, scaled up); the client blinks by
		-- squashing them flat and aims them a little towards the player
		local at = cf * CFrame.new(side * 7.7, 0, -1.2)
		part(eye, "Eye", Vector3.new(0.6, 0.17, 0.12) * HS, at * CFrame.Angles(0, 0, math.rad(-side * 14)), SOUL, Enum.Material.Neon)
	end
end

-- ============================================================
-- Unanchor the arms (the joints hold the pose), store
-- ============================================================
for _, d in ipairs(model:GetDescendants()) do
	if d:IsA("BasePart") and d ~= root then
		-- the rifts are static decoration: anchored; everything moved by a joint (the arms) unanchored
		local inRift = d:FindFirstAncestor("RiftL") or d:FindFirstAncestor("RiftR") or d:FindFirstAncestor("EyeRift")
		d.Anchored = inRift ~= nil
		d.Massless = true
	end
end
model:SetAttribute("Kind", "Hands")
-- the whole keeper streams in as one piece: the client scales the rifts open / shut, and a part arriving later at its
-- full size would be scaled along with the others
model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
model.Parent = folder

-- ============================================================
-- Preview on Plot1's lane end (delete Workspace.HandsPreview before publishing)
-- ============================================================
local oldPreview = workspace:FindFirstChild("HandsPreview")
if oldPreview then
	oldPreview:Destroy()
end
local base = workspace:FindFirstChild("Plots") and workspace.Plots:FindFirstChild("Plot1") and workspace.Plots.Plot1:FindFirstChild("Base")
if base then
	local look = base.CFrame.LookVector
	local laneDir = Vector3.new(look.X, 0, look.Z).Unit
	local origin = laneDir * 392 + Vector3.new(0, -1.7 + 70, 0)
	local preview = model:Clone()
	preview.Name = "HandsPreview"
	preview:PivotTo(CFrame.lookAt(origin, origin - laneDir))
	preview.Parent = workspace
end

local n = 0
for _, d in ipairs(model:GetDescendants()) do
	if d:IsA("BasePart") then
		n += 1
	end
end
return "GravekeeperHands built: " .. n .. " parts"
