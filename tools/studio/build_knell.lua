-- Knell, the Mourning Bell (Legendary Signature): a floating funeral executioner who carries its own belfry. A huge
-- cracked bronze bell (bigger than its body) hangs from an iron yoke rising from its shoulders, its clapper a skull on a
-- chain; a bell rope runs from the bell's lip down to the right hand (a Beam, so it follows every pull). A deep hood
-- with one glowing slit, a long mourning veil trailing behind, a ragged robe instead of legs, small funeral bells on
-- chains at the belt.
-- Rig (procedural, see CLAUDE.md "Models and rigs"): Root, Waist, Neck, L/RShoulder, L/RElbow, Veil, BellSwing (the bell,
-- round the yoke's crossbar), BellClapper (the skull clapper inside it). Parts used by Modules/KnellFx: BellMouth (the
-- centre of the bell's mouth), RopeHand. Attributes: Pose "Bellbearer" (UnitAnimator), AttackStyle "BellCast".
-- Front = -Z, right = +X, design units (the rig is scaled to def.size.X / 2 * 0.9 on spawn).
-- Run in Edit mode via the Studio MCP (or loadstring, see CLAUDE.md); replaces ServerStorage.Models.Knell. Run
-- tools/studio/publish_unit_models.lua afterwards and save the place.
local models = game.ServerStorage.Models
local model = Instance.new("Model")
model.Name = "Knell"

-- red and black (the user's theme for Knell): black cloth with crimson folds, a blackened bell with crimson streaks,
-- crimson soul light
local CLOTH = Color3.fromRGB(18, 14, 16)
local FOLD = Color3.fromRGB(58, 14, 20)
local VEIL = Color3.fromRGB(10, 8, 9)
local BONE = Color3.fromRGB(200, 188, 172)
local BONE_DARK = Color3.fromRGB(150, 136, 122)
local IRON = Color3.fromRGB(44, 40, 42)
local IRON_DARK = Color3.fromRGB(26, 24, 26)
local BRONZE = Color3.fromRGB(40, 30, 32)
local BRONZE_DARK = Color3.fromRGB(22, 16, 18)
local PATINA = Color3.fromRGB(120, 16, 26)
local ROPE = Color3.fromRGB(76, 22, 26)
local SOUL = Color3.fromRGB(235, 32, 48) -- (saturated: paler reds blow out to white under the bloom)
local HOLLOW = Color3.fromRGB(8, 10, 12)

local rng = Random.new(5512)
local into = model -- where new parts go (the bell is built in its own model first and scaled up as one piece)

local function part(name, size, at, color, material, shape)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = typeof(at) == "Vector3" and CFrame.new(at) or at
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = false
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Massless = true
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if shape then
		p.Shape = shape
	end
	p.Parent = into
	return p
end
local function weld(base, p)
	local w = Instance.new("WeldConstraint")
	w.Part0 = base
	w.Part1 = p
	w.Parent = p
	return p
end
local function detail(base, name, size, at, color, mat, shape)
	return weld(base, part(name, size, at, color, mat, shape))
end
local function wedge(base, name, size, cf, color)
	local p = detail(base, name, size, cf, color)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Wedge
	mesh.Parent = p
	return p
end
local function motor(name, p0, p1, pivot)
	local joint = Instance.new("Motor6D")
	joint.Name = name
	joint.Part0 = p0
	joint.Part1 = p1
	joint.C0 = p0.CFrame:Inverse() * CFrame.new(pivot)
	joint.C1 = p1.CFrame:Inverse() * CFrame.new(pivot)
	joint.Parent = p1
	return joint
end
local function rod(base, name, a, b, width, color, mat)
	return detail(base, name, Vector3.new(width, width, (b - a).Magnitude), CFrame.lookAt((a + b) / 2, b), color, mat or Enum.Material.Metal)
end

-- ============================================================
-- Body: root, pelvis, torso
-- ============================================================
local root = part("HumanoidRootPart", Vector3.new(1, 0.4, 1), Vector3.new(0, 3.8, 0), CLOTH)
root.Transparency = 1
model.PrimaryPart = root
local pelvis = part("Pelvis", Vector3.new(1.35, 0.5, 1), Vector3.new(0, 3.8, 0), CLOTH)
motor("Root", root, pelvis, pelvis.Position)
local torso = part("Torso", Vector3.new(1.6, 1.8, 1.05), Vector3.new(0, 4.95, 0), CLOTH)
motor("Waist", pelvis, torso, Vector3.new(0, 3.95, 0))
detail(torso, "Mantle", Vector3.new(2.5, 0.5, 1.45), Vector3.new(0, 5.7, 0), FOLD)
detail(torso, "Sternum", Vector3.new(0.16, 1.3, 0.14), Vector3.new(0, 5.0, -0.56), IRON, Enum.Material.Metal)
detail(pelvis, "Belt", Vector3.new(1.7, 0.26, 1.2), Vector3.new(0, 3.85, 0), IRON_DARK, Enum.Material.Metal)

-- the ragged robe: three tiers of pleats flaring out and down, pointed tatters at the hem (no legs)
for i = 0, 11 do
	local a = i * 2 * math.pi / 12
	for k = 1, 3 do
		local radius = 0.66 + k * 0.17
		local y = 3.55 - k * 0.92
		local width = 0.5 + k * 0.12
		local cf = CFrame.new(math.sin(a) * radius, y, math.cos(a) * radius) * CFrame.Angles(0, a, 0) * CFrame.Angles(math.rad(-6), 0, 0)
		detail(pelvis, "RobePleat", Vector3.new(width, 1.05, 0.14), cf, (i + k) % 2 == 0 and CLOTH or FOLD)
	end
	local len = rng:NextNumber(0.8, 1.6)
	local cf = CFrame.new(math.sin(a) * 1.18, 0.55 - len * 0.3, math.cos(a) * 1.18) * CFrame.Angles(0, a, 0) * CFrame.Angles(0, 0, math.pi)
	wedge(pelvis, "Tatter", Vector3.new(0.14, len, 0.62), cf * CFrame.Angles(0, math.pi / 2, 0), i % 2 == 0 and CLOTH or FOLD)
end

-- funeral bells on chains at the belt
for _, x in ipairs({ -0.7, -0.25, 0.3, 0.72 }) do
	local top = Vector3.new(x, 3.7, -0.6)
	local drop = rng:NextNumber(0.5, 0.9)
	rod(pelvis, "BeltChain", top, top - Vector3.new(0, drop, 0), 0.05, IRON)
	local b = top - Vector3.new(0, drop + 0.15, 0)
	detail(pelvis, "FuneralBell", Vector3.new(0.18, 0.3, 0.3), CFrame.new(b) * CFrame.Angles(0, 0, math.pi / 2), BRONZE, Enum.Material.Metal, Enum.PartType.Cylinder)
	detail(pelvis, "FuneralBellLip", Vector3.new(0.06, 0.38, 0.38), CFrame.new(b - Vector3.new(0, 0.12, 0)) * CFrame.Angles(0, 0, math.pi / 2), BRONZE_DARK, Enum.Material.Metal, Enum.PartType.Cylinder)
end

-- ============================================================
-- Head: a deep hood, a void face, one glowing slit; a broken crown of bronze spikes
-- ============================================================
local head = part("Head", Vector3.new(1.15, 1.3, 0.9), Vector3.new(0, 6.6, -0.12), HOLLOW)
motor("Neck", torso, head, Vector3.new(0, 6.0, 0))
detail(head, "HoodBack", Vector3.new(1.75, 1.8, 0.7), Vector3.new(0, 6.75, 0.35), CLOTH)
detail(head, "HoodCrown", Vector3.new(1.6, 0.4, 1.6), CFrame.new(0, 7.55, -0.05) * CFrame.Angles(math.rad(-8), 0, 0), FOLD)
detail(head, "HoodPeak", Vector3.new(1.0, 0.5, 1.0), CFrame.new(0, 7.75, -0.5) * CFrame.Angles(math.rad(-25), 0, 0), CLOTH)
for _, side in ipairs({ -1, 1 }) do
	detail(head, "HoodSide", Vector3.new(0.3, 1.85, 1.5), CFrame.new(side * 0.78, 6.62, -0.2) * CFrame.Angles(0, side * 0.12, -side * 0.06), CLOTH)
end
-- one wide slit of soul light across the void, slightly crooked
detail(head, "EyeSlit", Vector3.new(0.8, 0.08, 0.06), CFrame.new(0.04, 6.82, -0.6) * CFrame.Angles(0, 0, math.rad(-7)), SOUL, Enum.Material.Neon)
for i = -2, 2 do
	detail(head, "CrownSpike", Vector3.new(0.12, 0.5 + 0.28 * (2 - math.abs(i)), 0.14), CFrame.new(i * 0.24, 7.95, -0.15) * CFrame.Angles(0, 0, -i * 0.12), BRONZE, Enum.Material.Metal)
end

-- the mourning veil: long black strips from the back of the hood, trailing behind and down to the hem
-- (on its own joint "Veil" at the back of the hood: UnitAnimator lets it trail behind the body like cloth)
local veilRoot = part("VeilRoot", Vector3.one * 0.2, Vector3.new(0, 7.2, 0.62), VEIL)
veilRoot.Transparency = 1
motor("Veil", head, veilRoot, Vector3.new(0, 7.2, 0.62))
for i = -3, 3 do
	local len = 4.6 + rng:NextNumber(-0.6, 0.6)
	local top = CFrame.new(i * 0.24, 7.2, 0.62) * CFrame.Angles(math.rad(14 + math.abs(i) * 2), math.rad(i * 3), 0)
	detail(veilRoot, "Veil", Vector3.new(0.3, len, 0.06), top * CFrame.new(0, -len / 2, 0), i % 2 == 0 and VEIL or CLOTH)
end

-- ============================================================
-- Arms: long tattered sleeves, bony hands with long fingers (the right hand holds the bell rope)
-- ============================================================
local hands = {}
for _, side in ipairs({ "L", "R" }) do
	local sign = side == "L" and -1 or 1
	local upper = part(side .. "UpperArm", Vector3.new(0.62, 1.4, 0.68), Vector3.new(sign * 1.3, 5.0, 0), CLOTH)
	motor(side .. "Shoulder", torso, upper, Vector3.new(sign * 1.05, 5.62, 0))
	detail(upper, "Pauldron", Vector3.new(0.95, 0.5, 0.9), Vector3.new(sign * 1.32, 5.55, 0), IRON, Enum.Material.Metal)
	local forearm = part(side .. "Forearm", Vector3.new(0.58, 1.3, 0.66), Vector3.new(sign * 1.3, 3.8, 0), FOLD)
	motor(side .. "Elbow", upper, forearm, Vector3.new(sign * 1.3, 4.35, 0))
	-- a wide ragged sleeve end
	for k = -1, 1 do
		wedge(forearm, "SleeveTatter", Vector3.new(0.12, 0.7, 0.4), CFrame.new(sign * 1.3 + k * 0.22, 3.0, 0.1) * CFrame.Angles(0, math.pi / 2, math.pi), k == 0 and CLOTH or FOLD)
	end
	local hand = detail(forearm, side .. "Hand", Vector3.new(0.38, 0.45, 0.34), Vector3.new(sign * 1.3, 2.85, -0.05), BONE)
	for i = -1, 2 do
		detail(forearm, "LongFinger", Vector3.new(0.085, 0.72, 0.1), CFrame.new(sign * 1.3 + (i - 0.5) * 0.12, 2.35, -0.14) * CFrame.Angles(-0.25, 0, (i - 0.5) * 0.06), BONE)
		detail(forearm, "Fingertip", Vector3.new(0.07, 0.22, 0.08), CFrame.new(sign * 1.3 + (i - 0.5) * 0.12, 1.93, -0.25) * CFrame.Angles(-0.6, 0, 0), BONE_DARK)
	end
	hands[side] = hand
end
local ropeHand = Instance.new("Attachment")
ropeHand.Name = "RopeHand"
ropeHand.Parent = hands.R

-- ============================================================
-- The belfry: an iron yoke from the shoulders up to a crossbar above and behind the head
-- ============================================================
local BELL_Z = 3.1 -- (the bell's design position; it is scaled by BELL_SCALE round the crossbar and moved below)
local BAR_Y = 10.6 -- (the bell's design crossbar)
local BELL_SCALE = 1.22 -- the bell is bigger than the body
local FINAL_Z, FINAL_BAR = 3.75, 11.25 -- where the scaled bell hangs (its lip clears the shoulders)
local BY = 0.3 -- the bell's profile below is lifted by this much
for _, sign in ipairs({ -1, 1 }) do
	local from = Vector3.new(sign * 0.85, 5.4, 0.5)
	local to = Vector3.new(sign * 1.7, FINAL_BAR, FINAL_Z)
	rod(torso, "YokePost", from, to, 0.26, IRON_DARK)
	-- iron straps round the post
	for k = 1, 3 do
		local p = from:Lerp(to, k / 4)
		detail(torso, "YokeStrap", Vector3.new(0.34, 0.12, 0.34), CFrame.lookAt(p, to) * CFrame.Angles(math.pi / 2, 0, 0), IRON, Enum.Material.Metal)
	end
	detail(torso, "YokeSpike", Vector3.new(0.14, 0.6, 0.14), CFrame.new(sign * 2.15, FINAL_BAR + 0.25, FINAL_Z) * CFrame.Angles(0, 0, -sign * 0.5), IRON, Enum.Material.Metal)
end
detail(torso, "Crossbar", Vector3.new(4.2, 0.34, 0.38), Vector3.new(0, FINAL_BAR, FINAL_Z), IRON_DARK, Enum.Material.Metal)
detail(torso, "CrossbarCap", Vector3.new(4.4, 0.1, 0.48), Vector3.new(0, FINAL_BAR + 0.2, FINAL_Z), IRON, Enum.Material.Metal)

-- ============================================================
-- The bell: hollow stepped panels, a heavy flared lip, patina, a crack of soul light, a rune band
-- ============================================================
local bellModel = Instance.new("Model")
bellModel.Name = "BellBuild"
bellModel.Parent = model
into = bellModel
local bellRoot = part("BellRoot", Vector3.one * 0.2, Vector3.new(0, BAR_Y - 0.4, BELL_Z), BRONZE)
bellRoot.Transparency = 1
detail(bellRoot, "BellHanger", Vector3.new(0.5, 0.55, 0.5), Vector3.new(0, BAR_Y - 0.3, BELL_Z), IRON, Enum.Material.Metal)
-- { y, radius, height } from the crown down to the lip
-- a smooth bell curve: a rounded shoulder, a long waist, a flared lip
local rings = {}
for k = 1, 9 do
	local f = (k - 1) / 8
	local r = 0.62 + 1.2 * f ^ 0.5 + math.max(0, f - 0.78) * 2.6
	table.insert(rings, { 9.62 - f * 4.0, r, 0.56 })
end
local SIDES = 14
for k, spec in ipairs(rings) do
	local y, r, h = spec[1] + BY, spec[2], spec[3]
	for i = 0, SIDES - 1 do
		local a = (i + 0.5) * 2 * math.pi / SIDES
		-- patina in vertical streaks running down from the waist; a dark band near the lip
		local streak = (i % 4 == 1) and k >= 4 or (i % 7 == 3 and k >= 6)
		local color = streak and PATINA or ((k == #rings - 1 or k == 2) and BRONZE_DARK or BRONZE)
		local cf = CFrame.new(math.sin(a) * r, y, BELL_Z + math.cos(a) * r) * CFrame.Angles(0, a, 0)
		detail(bellRoot, "BellPanel", Vector3.new(2 * r * math.tan(math.pi / SIDES) * 1.02, h, 0.18), cf, color, Enum.Material.Metal)
		if k == 6 and i % 2 == 0 then
			detail(bellRoot, "BellRune", Vector3.new(0.09, 0.32, 0.04), cf * CFrame.new(0, 0, 0.11), SOUL, Enum.Material.Neon)
		end
	end
end
detail(bellRoot, "BellCrownCap", Vector3.new(0.3, 1.25, 1.25), CFrame.new(0, 9.85 + BY, BELL_Z) * CFrame.Angles(0, 0, math.pi / 2), BRONZE_DARK, Enum.Material.Metal, Enum.PartType.Cylinder)
-- a jagged crack of soul light down the front-left of the shell
local prev = Vector3.new(-0.55, 9.3 + BY, BELL_Z - 0.85)
for k = 1, 6 do
	local y = 9.3 + BY - k * 0.6
	local r = 1.0 + k * 0.2
	local a = math.rad(220 + (k % 2 == 0 and 8 or -8))
	local p = Vector3.new(math.sin(a) * r, y, BELL_Z + math.cos(a) * r) * Vector3.new(1, 1, 1)
	rod(bellRoot, "BellCrack", prev, p, 0.09, SOUL, Enum.Material.Neon)
	prev = p
end
-- the centre of the mouth (Modules/KnellFx: the clang's flash and the souls fly back in here)
local mouth = detail(bellRoot, "BellMouth", Vector3.one * 0.2, Vector3.new(0, 5.6 + BY, BELL_Z), SOUL)
mouth.Transparency = 1
local light = Instance.new("PointLight")
light.Color = SOUL
light.Range = 10
light.Brightness = 0.9
light.Shadows = false
light.Parent = mouth
-- the rope hangs from the lip's front-right
local ropeBell = Instance.new("Attachment")
ropeBell.Name = "RopeBell"
ropeBell.Parent = bellRoot
ropeBell.WorldPosition = Vector3.new(1.55, 5.6 + BY, BELL_Z - 1.55)

-- the clapper: a skull on a chain
local clapper = part("Clapper", Vector3.new(0.18, 2.6, 0.18), Vector3.new(0, 8.0 + BY, BELL_Z), IRON, Enum.Material.Metal)
local clapperPivot = Instance.new("Attachment") -- (marks the clapper's hinge through the scaling)
clapperPivot.Name = "ClapperPivot"
clapperPivot.Parent = clapper
clapperPivot.WorldPosition = Vector3.new(0, 9.3 + BY, BELL_Z)
local skullAt = CFrame.new(0, 6.3 + BY, BELL_Z)
detail(clapper, "ClapperSkull", Vector3.new(0.72, 0.68, 0.78), skullAt, BONE)
detail(clapper, "ClapperJaw", Vector3.new(0.5, 0.2, 0.46), skullAt * CFrame.new(0, -0.38, -0.12), BONE_DARK)
for _, side in ipairs({ -1, 1 }) do
	detail(clapper, "ClapperSocket", Vector3.new(0.18, 0.16, 0.06), skullAt * CFrame.new(side * 0.17, 0.05, -0.39), SOUL, Enum.Material.Neon)
end

-- the bell rope (a Beam: it follows the bell and the hand wherever they move)
local rope = Instance.new("Beam")
rope.Name = "BellRope"
rope.Attachment0 = ropeBell
rope.Attachment1 = ropeHand
rope.Color = ColorSequence.new(ROPE)
rope.Width0 = 0.22
rope.Width1 = 0.22
rope.Segments = 12
rope.CurveSize0 = 0.6
rope.CurveSize1 = -0.4
rope.FaceCamera = true
rope.LightInfluence = 1
rope.Parent = bellRoot

-- scale the bell up round its crossbar, hang it from the real crossbar, then join it to the rig
bellModel.WorldPivot = CFrame.new(0, BAR_Y, BELL_Z)
bellModel:ScaleTo(BELL_SCALE)
bellModel:PivotTo(CFrame.new(0, FINAL_BAR, FINAL_Z))
for _, d in ipairs(bellModel:GetChildren()) do
	d.Parent = model
end
bellModel:Destroy()
into = model
motor("BellSwing", torso, bellRoot, Vector3.new(0, FINAL_BAR, FINAL_Z))
motor("BellClapper", bellRoot, clapper, clapperPivot.WorldPosition)
clapperPivot:Destroy()

model:SetAttribute("Rig", "Procedural")
model:SetAttribute("Pose", "Bellbearer")
model:SetAttribute("AttackStyle", "BellCast")
model:SetAttribute("AttackAnim", 0.9)
model:SetAttribute("RootHeight", 5.0)
model:SetAttribute("Height", 12.0)
model:SetAttribute("Float", 0.28)
model:SetAttribute("SpecialDuration", 11.0)
local old = models:FindFirstChild("Knell")
if old then
	old:Destroy()
end
model.Parent = models
local n = 0
for _, d in ipairs(model:GetDescendants()) do
	if d:IsA("BasePart") then
		n += 1
	end
end
return "Knell built: " .. n .. " parts"
