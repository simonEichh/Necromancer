-- Builds the Realm 1 titan, THE GRAVEKEEPER, into ServerStorage.TitanModels.Gravekeeper, from the concept art
-- Images/Entity/Der Grabwächter am Festungswall.png (see Design.md, "Realms" / "Realm 1"): a colossal hooded sexton in a
-- tattered moss-green and charcoal cloak, a black face with two slanted soul-green eyes, a gravestone with a cross
-- strapped to his back (roots and moss), a rope belt with iron keys, big bony hands, a lantern on a chain and a rusty
-- shovel. He stands OUTSIDE the outer wall, sunk in the sea to his hips, and leans over the battlements: the right forearm
-- lies on the wall with the hand draped over the inner edge and the lantern hanging into the arena; the left hand is
-- raised over the lane, fingers spread, weaving the walls.
-- Run in Edit mode via the Studio MCP execute_luau (or loadstring over a local http.server, see CLAUDE.md). Safe to re-run.
--
-- Built at 1/SCALE in "design units" (about 18 tall when standing, wall top at WALL_TOP) and scaled up at the end.
-- Rig: an anchored invisible HumanoidRootPart at the hips; bone parts joined by Motor6Ds (Waist, Neck, RShoulder,
-- RElbow, RWrist, LShoulder, LElbow, LWrist, R/LFinger<n>a/b, R/LThumba/b, Lantern) whose C0/C1 bake the pose, so a client
-- module can animate them through Motor6D.Transform; decoration is welded to its bone. Front = -Z, right = +X.
-- The server module Titans places it behind every claimed plot's lane.
local ServerStorage = game:GetService("ServerStorage")

local folder = ServerStorage:FindFirstChild("TitanModels")
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "TitanModels"
	folder.Parent = ServerStorage
end
local old = folder:FindFirstChild("Gravekeeper")
if old then
	old:Destroy()
end

local SCALE = 12
local WALL_TOP = 8.5 -- design units: the outer wall's top relative to his feet (he stands in the sea)
local WALL_FRONT, WALL_BACK = -4.2, -3.0 -- design z of the outer wall's inner face (arena side) and outer face

-- ============================================================
-- Palette
-- ============================================================
local CLOAK = Color3.fromRGB(80, 104, 62)
local CLOAK_DARK = Color3.fromRGB(58, 74, 48)
local CHARCOAL = Color3.fromRGB(34, 35, 36)
local CHARCOAL_2 = Color3.fromRGB(46, 46, 48)
local VOID = Color3.fromRGB(6, 7, 8)
local BONE = Color3.fromRGB(226, 218, 196)
local BONE_DARK = Color3.fromRGB(190, 180, 158)
local ROPE = Color3.fromRGB(110, 80, 52)
local RUST = Color3.fromRGB(132, 72, 40)
local RUST_DARK = Color3.fromRGB(96, 56, 36)
local IRON_DARK = Color3.fromRGB(40, 34, 32)
local STONE = Color3.fromRGB(128, 128, 124)
local STONE_DARK = Color3.fromRGB(100, 100, 98)
local MOSS = Color3.fromRGB(74, 98, 52)
local ROOT = Color3.fromRGB(70, 52, 38)
local LAMP = Color3.fromRGB(255, 190, 110)
local SOUL = Color3.fromRGB(50, 220, 130) -- saturated: paler greens blow out to white under the bloom

local rng = Random.new(9019)

local model = Instance.new("Model")
model.Name = "Gravekeeper"

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

local function wedge(parent, name, size, cf, color, material)
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
	p.Material = material or Enum.Material.SmoothPlastic
	p.Parent = parent
	return p
end

-- a block from a to b (its -Z runs along the bone), thickness w x h
local function span(parent, name, a, b, w, h, color, material, up)
	local len = (b - a).Magnitude
	local cf = CFrame.lookAt((a + b) / 2, b, up or Vector3.yAxis)
	return part(parent, name, Vector3.new(w, h or w, len), cf, color, material)
end

-- an invisible bone part (what a joint moves) at `cf`
local function bone(name, cf)
	local p = part(model, name, Vector3.new(0.4, 0.4, 0.4), cf, CHARCOAL)
	p.Transparency = 1
	return p
end

-- welds every part in `list` to `to` (they keep their place relative to the bone)
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

-- a Motor6D between two bones at world point `at` (the joint frame takes the child bone's orientation)
local joints = {}
local function joint(name, part0, part1, at)
	local jf = CFrame.new(at) * part1.CFrame.Rotation
	local m = Instance.new("Motor6D")
	m.Name = name
	m.Part0 = part0
	m.Part1 = part1
	m.C0 = part0.CFrame:ToObjectSpace(jf)
	m.C1 = part1.CFrame:ToObjectSpace(jf)
	m.Parent = part0
	table.insert(joints, m)
	return m
end

-- collect the parts made inside `fn` (so they can be welded to a bone)
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

-- a ragged cloak slab hanging from `top` (a CFrame): w wide, h long, slightly turned and tilted
local function rag(parent, top, w, h, color)
	local cf = top * CFrame.Angles(math.rad(rng:NextNumber(-6, 6)), math.rad(rng:NextNumber(-8, 8)), math.rad(rng:NextNumber(-5, 5)))
	part(parent, "Rag", Vector3.new(w, h, 0.18), cf * CFrame.new(0, -h / 2, 0), color, Enum.Material.Fabric)
	-- a jagged tip
	wedge(parent, "RagTip", Vector3.new(0.18, 0.7, w * 0.5), cf * CFrame.new(rng:NextNumber(-w / 4, w / 4), -h - 0.35, 0) * CFrame.Angles(0, math.rad(90), math.rad(180)),
		color, Enum.Material.Fabric)
end

-- ============================================================
-- Root and robe (the lower body stays mostly under the water and behind the wall)
-- ============================================================
local HIP = CFrame.new(0, 8, 0)
local root = part(model, "HumanoidRootPart", Vector3.new(1, 1, 1), HIP, CHARCOAL)
root.Transparency = 1
model.PrimaryPart = root

local robe = collect(function()
	part(model, "Robe", Vector3.new(4.6, 8, 3.4), CFrame.new(0, 4, 0.2), CHARCOAL, Enum.Material.Fabric)
	part(model, "Robe", Vector3.new(4.9, 5, 3.7), CFrame.new(0, 2.4, 0.2), CHARCOAL_2, Enum.Material.Fabric)
	for k = 0, 9 do
		local a = k / 10 * math.pi * 2
		rag(model, CFrame.new(math.cos(a) * 2.3, 6.5, 0.2 + math.sin(a) * 1.7) * CFrame.Angles(0, -a + math.pi / 2, 0), rng:NextNumber(1.2, 1.8), rng:NextNumber(5, 6.5),
			k % 2 == 0 and CLOAK_DARK or CHARCOAL)
	end
end)
weldAll(robe, root)

-- ============================================================
-- Torso (leans over the wall), cloak, belt with keys, the gravestone on his back
-- ============================================================
local LEAN = math.rad(-35)
local T = HIP * CFrame.Angles(LEAN, 0, 0)
local torso = bone("Torso", T * CFrame.new(0, 2.6, 0))
local torsoParts = collect(function()
	part(model, "Chest", Vector3.new(4.2, 5.4, 2.6), T * CFrame.new(0, 2.7, 0), CHARCOAL, Enum.Material.Fabric)
	-- the cloak: a mantle over the shoulders and ragged panels down the front and back
	part(model, "Mantle", Vector3.new(5.6, 1.4, 3.4), T * CFrame.new(0, 4.9, 0) * CFrame.Angles(math.rad(-6), 0, 0), CLOAK, Enum.Material.Fabric)
	for _, side in ipairs({ -1, 1 }) do
		part(model, "Mantle", Vector3.new(1.8, 1.2, 3.2), T * CFrame.new(side * 2.5, 4.5, 0) * CFrame.Angles(0, 0, math.rad(side * -28)), CLOAK, Enum.Material.Fabric)
	end
	for k = -2, 2 do
		rag(model, T * CFrame.new(k * 0.85, 4.6, -1.35), 1, rng:NextNumber(3.5, 5.2), k % 2 == 0 and CLOAK or CLOAK_DARK)
		rag(model, T * CFrame.new(k * 0.85, 4.6, 1.35) * CFrame.Angles(0, math.pi, 0), 1, rng:NextNumber(4, 6), k % 2 == 0 and CLOAK_DARK or CHARCOAL_2)
	end
	-- rope belt with iron keys
	part(model, "Belt", Vector3.new(4.4, 0.35, 2.8), T * CFrame.new(0, 0.9, 0), ROPE, Enum.Material.Fabric)
	part(model, "BeltKnot", Vector3.new(0.6, 0.6, 0.5), T * CFrame.new(1, 0.9, -1.45), ROPE, Enum.Material.Fabric)
	for k = 0, 2 do
		local key = T * CFrame.new(1.1 + k * 0.35, 0.3 - k * 0.25, -1.55) * CFrame.Angles(0, 0, math.rad(rng:NextNumber(-12, 12)))
		part(model, "KeyRing", Vector3.new(0.12, 0.6, 0.6), key * CFrame.Angles(0, math.rad(90), 0), RUST_DARK, Enum.Material.CorrodedMetal, Enum.PartType.Cylinder)
		part(model, "Key", Vector3.new(0.14, 1.1, 0.12), key * CFrame.new(0, -0.8, 0), RUST, Enum.Material.CorrodedMetal)
		part(model, "KeyBit", Vector3.new(0.35, 0.22, 0.12), key * CFrame.new(0.15, -1.25, 0), RUST, Enum.Material.CorrodedMetal)
	end
	-- the gravestone strapped to his back, the cross rising over his left shoulder
	local stone = T * CFrame.new(-0.7, 3.6, 1.75) * CFrame.Angles(0, 0, math.rad(8))
	part(model, "Gravestone", Vector3.new(2.8, 5.6, 0.8), stone, STONE, Enum.Material.Slate)
	part(model, "Gravestone", Vector3.new(1.1, 2.6, 0.8), stone * CFrame.new(0, 3.9, 0), STONE, Enum.Material.Slate)
	part(model, "Gravestone", Vector3.new(2.6, 0.9, 0.8), stone * CFrame.new(0, 4.3, 0), STONE, Enum.Material.Slate)
	part(model, "GravestoneEdge", Vector3.new(3, 0.5, 0.9), stone * CFrame.new(0, -2.6, 0), STONE_DARK, Enum.Material.Slate)
	for _, y in ipairs({ -1.2, 1.2 }) do
		part(model, "Strap", Vector3.new(3.1, 0.3, 1), stone * CFrame.new(0, y, 0), ROPE, Enum.Material.Fabric)
	end
	-- roots wrapping the stone and shoulders, moss clumps
	for _ = 1, 5 do
		local a = (T * CFrame.new(rng:NextNumber(-2.6, 1.6), rng:NextNumber(3, 6.5), rng:NextNumber(0.4, 2.3))).Position
		local b = a + Vector3.new(rng:NextNumber(-1.8, 1.8), rng:NextNumber(-2.2, -0.6), rng:NextNumber(-1, 0.6))
		span(model, "Root", a, b, 0.28, 0.28, ROOT, Enum.Material.Wood)
	end
	for _ = 1, 7 do
		local s = rng:NextNumber(0.6, 1.2)
		part(model, "Moss", Vector3.new(s * 1.3, s * 0.7, s), T * CFrame.new(rng:NextNumber(-2.8, 2.6), rng:NextNumber(4.8, 5.8), rng:NextNumber(-0.8, 1.8))
			* CFrame.Angles(rng:NextNumber(-0.4, 0.4), rng:NextNumber(0, 3), rng:NextNumber(-0.4, 0.4)), MOSS, Enum.Material.Grass)
	end
end)
weldAll(torsoParts, torso)
joint("Waist", root, torso, HIP.Position)

-- ============================================================
-- Head: the hood with a black void and two slanted soul-green eyes (looks down into the lane)
-- ============================================================
local NECK = T * CFrame.new(0, 5.4, 0)
local H = NECK * CFrame.Angles(math.rad(-10), 0, 0)
local head = bone("Head", H * CFrame.new(0, 1.6, 0))
local headParts = collect(function()
	part(model, "Face", Vector3.new(2.4, 2.9, 0.4), H * CFrame.new(0, 1.7, -0.7), VOID, Enum.Material.SmoothPlastic)
	part(model, "Hood", Vector3.new(3.4, 3.8, 0.5), H * CFrame.new(0, 1.9, 1.25), CLOAK, Enum.Material.Fabric)
	for _, side in ipairs({ -1, 1 }) do
		part(model, "Hood", Vector3.new(0.55, 3.9, 2.8), H * CFrame.new(side * 1.55, 1.85, -0.05) * CFrame.Angles(0, math.rad(side * 8), 0), CLOAK, Enum.Material.Fabric)
		part(model, "HoodRoof", Vector3.new(2, 0.5, 3.2), H * CFrame.new(side * 0.85, 3.85, 0.1) * CFrame.Angles(0, 0, math.rad(-side * 32)), CLOAK_DARK, Enum.Material.Fabric)
		part(model, "HoodRim", Vector3.new(0.4, 3.4, 0.5), H * CFrame.new(side * 1.25, 1.7, -1.25) * CFrame.Angles(0, 0, math.rad(side * 6)), CLOAK_DARK, Enum.Material.Fabric)
		part(model, "Eye", Vector3.new(0.6, 0.17, 0.12), H * CFrame.new(side * 0.55, 2.05, -0.95) * CFrame.Angles(0, 0, math.rad(-side * 14)), SOUL, Enum.Material.Neon)
	end
	-- the peak of the hood leans forward over the face
	wedge(model, "HoodPeak", Vector3.new(2.6, 1.3, 1.8), H * CFrame.new(0, 3.55, -1.15) * CFrame.Angles(0, math.pi, 0), CLOAK, Enum.Material.Fabric)
	-- the hood drapes down over the shoulders
	rag(model, H * CFrame.new(0, 0.6, 1.3) * CFrame.Angles(0, math.pi, 0), 2.6, 1.6, CLOAK_DARK)
end)
weldAll(headParts, head)
joint("Neck", torso, head, NECK.Position)

-- ============================================================
-- Arms and hands. Points are in design space; the pose is baked into the joints.
-- ============================================================
local function shoulderPoint(side)
	return (T * CFrame.new(side * 2.3, 4.5, 0)).Position
end

-- builds one arm through the points shoulder -> elbow -> wrist; `fingers` gives each finger's two segment directions
-- in the hand's frame. Returns the hand bone.
local function arm(prefix, side, elbowPos, wristPos, handDir, fingerDirs, thumbDirs)
	local sh = shoulderPoint(side)
	local upper = bone(prefix .. "UpperArm", CFrame.lookAt((sh + elbowPos) / 2, elbowPos))
	local upperParts = collect(function()
		span(model, "Sleeve", sh, elbowPos, 1.5, 1.5, CLOAK, Enum.Material.Fabric)
		local mid = CFrame.lookAt((sh + elbowPos) / 2, elbowPos)
		for k = 1, 3 do
			rag(model, mid * CFrame.new((k - 2) * 0.45, -0.6, (k - 2) * 0.6) * CFrame.Angles(0, 0, 0), 0.6, rng:NextNumber(1.2, 2), k % 2 == 0 and CLOAK_DARK or CLOAK)
		end
	end)
	weldAll(upperParts, upper)
	joint(prefix .. "Shoulder", torso, upper, sh)

	local fore = bone(prefix .. "Forearm", CFrame.lookAt((elbowPos + wristPos) / 2, wristPos))
	local foreParts = collect(function()
		-- the sleeve covers the first half, then two bare bones
		local half = elbowPos:Lerp(wristPos, 0.5)
		span(model, "Sleeve", elbowPos, half, 1.6, 1.6, CLOAK_DARK, Enum.Material.Fabric)
		local cf = CFrame.lookAt(half, wristPos)
		for _, off in ipairs({ -0.22, 0.22 }) do
			local a = (cf * CFrame.new(off, 0, 0)).Position
			local b = (CFrame.lookAt(wristPos, wristPos + (wristPos - half)) * CFrame.new(off * 0.6, 0, 0)).Position
			span(model, "ForearmBone", a, b, 0.32, 0.32, BONE, Enum.Material.SmoothPlastic)
		end
		rag(model, CFrame.lookAt(half, wristPos) * CFrame.new(0, -0.5, 0.3), 1.2, 1.4, CLOAK_DARK)
	end)
	weldAll(foreParts, fore)
	joint(prefix .. "Elbow", upper, fore, elbowPos)

	-- the hand: a bony palm along `handDir`, its frame's -Y is the palm side
	local handCf = CFrame.lookAt(wristPos, wristPos + handDir)
	local hand = bone(prefix .. "Hand", handCf * CFrame.new(0, 0, -0.75))
	local handParts = collect(function()
		part(model, "Palm", Vector3.new(1.5, 0.45, 1.5), handCf * CFrame.new(0, 0, -0.75), BONE, Enum.Material.SmoothPlastic)
		part(model, "Wrist", Vector3.new(0.7, 0.5, 0.5), handCf * CFrame.new(0, 0, -0.05), BONE_DARK, Enum.Material.SmoothPlastic)
	end)
	weldAll(handParts, hand)
	joint(prefix .. "Wrist", fore, hand, wristPos)

	-- fingers: two segments each, knuckles across the front of the palm
	local function finger(name, knuckle, d1, d2, len1, len2, thick)
		local a = knuckle
		local b = a + handCf:VectorToWorldSpace(d1.Unit) * len1
		local c = b + handCf:VectorToWorldSpace(d2.Unit) * len2
		local s1 = span(model, name .. "a", a, b, thick, thick, BONE, Enum.Material.SmoothPlastic, handCf.UpVector)
		local s2 = span(model, name .. "b", b, c, thick * 0.85, thick * 0.85, BONE, Enum.Material.SmoothPlastic, handCf.UpVector)
		local tip = part(model, name .. "Tip", Vector3.new(thick * 0.7, thick * 0.7, 0.3), CFrame.lookAt(c, c + (c - b)) * CFrame.new(0, 0, -0.1), BONE_DARK, Enum.Material.SmoothPlastic)
		weldAll({ tip }, s2)
		joint(name .. "a", hand, s1, a)
		joint(name .. "b", s1, s2, b)
	end
	for k = 1, 4 do
		local x = (k - 2.5) * 0.36
		local d = fingerDirs[k]
		finger(prefix .. "Finger" .. k, (handCf * CFrame.new(x, 0, -1.45)).Position, d[1], d[2], 0.95 - math.abs(k - 2.5) * 0.08, 0.85, 0.3)
	end
	finger(prefix .. "Thumb", (handCf * CFrame.new(-side * 0.7, -0.05, -0.6)).Position, thumbDirs[1], thumbDirs[2], 0.7, 0.6, 0.32)
	return hand
end

-- right arm: the upper arm reaches over the wall, the forearm lies on the battlements, the hand drapes over the inner
-- edge (fingers curl down the arena side)
local rElbow = Vector3.new(5.2, WALL_TOP + 0.7, (WALL_FRONT + WALL_BACK) / 2)
local rWrist = Vector3.new(8.4, WALL_TOP + 0.65, WALL_FRONT + 0.2)
local rHand = arm("R", 1, rElbow, rWrist, Vector3.new(0.15, -0.75, -0.65).Unit, {
	{ Vector3.new(0, -0.6, -1), Vector3.new(0, -1, -0.3) },
	{ Vector3.new(0, -0.6, -1), Vector3.new(0, -1, -0.2) },
	{ Vector3.new(0, -0.5, -1), Vector3.new(0, -1, -0.3) },
	{ Vector3.new(0.1, -0.5, -1), Vector3.new(0, -1, -0.4) },
}, { Vector3.new(-0.6, -0.4, -1), Vector3.new(-0.2, -1, -0.5) })

-- left arm: raised over the lane, palm down, fingers spread and hanging (weaving)
local lElbow = Vector3.new(-3.4, 12.8, -5.9)
local lWrist = Vector3.new(-3.0, 13.6, -9.3)
arm("L", -1, lElbow, lWrist, Vector3.new(0.05, -0.15, -1).Unit, {
	{ Vector3.new(-0.35, -0.7, -1), Vector3.new(-0.1, -1, -0.15) },
	{ Vector3.new(-0.1, -0.75, -1), Vector3.new(0, -1, -0.1) },
	{ Vector3.new(0.1, -0.8, -1), Vector3.new(0, -1, -0.15) },
	{ Vector3.new(0.35, -0.7, -1), Vector3.new(0.1, -1, -0.2) },
}, { Vector3.new(0.9, -0.5, -0.4), Vector3.new(0.3, -1, -0.2) })

-- ============================================================
-- The lantern, hanging on a chain from the right hand into the arena (joint "Lantern" swings it)
-- ============================================================
do
	local top = (rHand.CFrame * CFrame.new(0, -0.2, -1.6)).Position -- clear of the wall's inner face
	local lampPos = top - Vector3.new(0, 2.6, 0)
	local lantern = bone("Lantern", CFrame.new(lampPos))
	local lanternParts = collect(function()
		for k = 0, 3 do
			local p = top - Vector3.new(0, 0.3 + k * 0.42, 0)
			part(model, "Chain", Vector3.new(0.12, 0.45, 0.28), CFrame.new(p) * CFrame.Angles(0, k % 2 == 0 and 0 or math.rad(90), 0), IRON_DARK, Enum.Material.CorrodedMetal)
		end
		local c = CFrame.new(lampPos)
		part(model, "LanternTop", Vector3.new(1.3, 0.3, 1.3), c * CFrame.new(0, 0.85, 0) * CFrame.Angles(0, math.rad(45), 0), RUST_DARK, Enum.Material.CorrodedMetal)
		wedge(model, "LanternRoof", Vector3.new(1.2, 0.5, 0.6), c * CFrame.new(0, 1.25, -0.3), RUST_DARK, Enum.Material.CorrodedMetal)
		wedge(model, "LanternRoof", Vector3.new(1.2, 0.5, 0.6), c * CFrame.new(0, 1.25, 0.3) * CFrame.Angles(0, math.pi, 0), RUST_DARK, Enum.Material.CorrodedMetal)
		part(model, "LanternBottom", Vector3.new(1.2, 0.3, 1.2), c * CFrame.new(0, -0.85, 0) * CFrame.Angles(0, math.rad(45), 0), RUST_DARK, Enum.Material.CorrodedMetal)
		part(model, "LanternSpike", Vector3.new(0.35, 0.6, 0.35), c * CFrame.new(0, -1.25, 0) * CFrame.Angles(0, math.rad(45), math.rad(45)), RUST_DARK, Enum.Material.CorrodedMetal)
		for k = 0, 3 do
			local a = k * math.pi / 2 + math.pi / 4
			part(model, "LanternBar", Vector3.new(0.14, 1.5, 0.14), c * CFrame.new(math.cos(a) * 0.6, 0, math.sin(a) * 0.6), RUST, Enum.Material.CorrodedMetal)
		end
		local glow = part(model, "LanternGlow", Vector3.new(0.85, 1.3, 0.85), c, LAMP, Enum.Material.Neon)
		local light = Instance.new("PointLight")
		light.Name = "LanternLight"
		light.Color = LAMP
		light.Shadows = false
		light.Parent = glow
	end)
	weldAll(lanternParts, lantern)
	joint("Lantern", rHand, lantern, top)
end

-- ============================================================
-- The shovel, leaning against the outer wall at his right (welded to the root, it never moves)
-- ============================================================
do
	local foot = Vector3.new(11.8, 0.5, WALL_BACK + 1.6)
	local topP = Vector3.new(11, WALL_TOP + 2.2, WALL_BACK + 0.4)
	local shovel = collect(function()
		span(model, "ShovelHandle", foot + (topP - foot).Unit * 3.2, topP, 0.35, 0.35, ROPE, Enum.Material.Wood)
		part(model, "ShovelGrip", Vector3.new(1.4, 0.3, 0.3), CFrame.lookAt(topP, topP + (topP - foot)) * CFrame.new(0, 0, -0.1) * CFrame.Angles(0, 0, math.rad(90)), ROPE, Enum.Material.Wood)
		local bladeCf = CFrame.lookAt(foot + (topP - foot).Unit * 1.7, topP)
		part(model, "ShovelBlade", Vector3.new(2.2, 0.15, 3), bladeCf, RUST, Enum.Material.CorrodedMetal)
		wedge(model, "ShovelTip", Vector3.new(0.15, 1, 1.1), bladeCf * CFrame.new(-0.55, 0, 1.95) * CFrame.Angles(0, 0, math.rad(90)), RUST, Enum.Material.CorrodedMetal)
		wedge(model, "ShovelTip", Vector3.new(0.15, 1, 1.1), bladeCf * CFrame.new(0.55, 0, 1.95) * CFrame.Angles(0, 0, math.rad(-90)), RUST, Enum.Material.CorrodedMetal)
	end)
	weldAll(shovel, root)
end

-- ============================================================
-- Unanchor everything but the root (the joints hold the pose), scale up, store
-- ============================================================
for _, d in ipairs(model:GetDescendants()) do
	if d:IsA("BasePart") and d ~= root then
		d.Anchored = false
		d.Massless = true
	end
end
model.Parent = workspace -- (scaling needs the joints active)
model:ScaleTo(SCALE) -- (scales round the root)
root.PivotOffset = CFrame.new(0, -HIP.Position.Y * SCALE, 0) -- the model's pivot is his feet (WorldPivot is ignored with a PrimaryPart)
for _, d in ipairs(model:GetDescendants()) do
	if d:IsA("PointLight") then
		d.Range = 60
		d.Brightness = 2.5
	end
end
local parts = 0
for _, d in ipairs(model:GetDescendants()) do
	if d:IsA("BasePart") then
		parts += 1
	end
end
model:SetAttribute("Realm", 1)
model:SetAttribute("Parts", parts)
model:SetAttribute("WallTop", WALL_TOP * SCALE) -- studs from his feet to the outer wall's top (the placement uses it)
model:SetAttribute("WallBack", -WALL_BACK * SCALE) -- studs from his feet to the outer wall's outer face, forwards
model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent -- seen from everywhere
model.Parent = folder

-- (no preview copy any more: the server module Titans places a titan behind every claimed plot's lane)
local preview = workspace:FindFirstChild("TitanPreview")
if preview then
	preview:Destroy()
end

return "Gravekeeper: " .. parts .. " parts, " .. #joints .. " joints"
