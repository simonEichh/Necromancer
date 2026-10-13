-- Builds the low-poly rigged Hush into ServerStorage.Models.Hush (Eternal rarity, see Unit ideas.txt).
-- Run in Edit mode via the Studio MCP execute_luau (or loadstring over a local http.server, see CLAUDE.md). Safe to re-run.
--
-- A small, childlike creature in an oversized faded hoodie (hood up, long like a tunic) and a black gas mask with two
-- glowing violet lenses and a filter canister. It floats high above the ground in a crucified pose, as if nailed to an
-- invisible cross: arms spread, nails through the sleeves at the elbows, and from there the oversized empty sleeves hang
-- down limp (no hands visible). Iron shackles with broken chains hang from the sleeves; bare grey feet, the ankles
-- shackled together. A long claw finger hides in the right sleeve on its own joint (RFinger): for the basic attack
-- the sleeve lifts toward the wall and the finger slides out (a small magic circle at the fingertip, a thin beam).
--
-- Rig conventions as build_skelly.lua / UnitAnimator: front = -Z, character's right = +X, root = HumanoidRootPart.
-- The REST pose: arms out along X, sleeves hanging straight down from the elbow joints; UnitAnimator's "Crucified"
-- pose (model attribute Pose) adds the sagging, swaying and twitching. Joints: Root, Waist, Neck, L/RShoulder,
-- L/RElbow + L/RSleeve1 + L/RSleeve2 (the hanging sleeve in three segments), RFinger, L/RHip, L/RKnee. Attributes: Rig = "Procedural", RootHeight, Height, Float, Pose.
local ServerStorage = game:GetService("ServerStorage")
local models = ServerStorage.Models

local old = models:FindFirstChild("Hush")
if old then old:Destroy() end

local HOODIE = Color3.fromRGB(96, 90, 112) -- washed-out grey violet
local HOODIE_DARK = Color3.fromRGB(70, 64, 86)
local HOODIE_LIGHT = Color3.fromRGB(122, 116, 138)
local RUBBER = Color3.fromRGB(34, 34, 38)
local RUBBER_LIGHT = Color3.fromRGB(56, 56, 62)
local METAL = Color3.fromRGB(110, 112, 120)
local LENS = Color3.fromRGB(190, 120, 255)
local SKIN = Color3.fromRGB(150, 152, 168) -- grey, lifeless
local CLAW = Color3.fromRGB(30, 26, 34)
local PANTS = Color3.fromRGB(44, 42, 52)
local SOCK = Color3.fromRGB(196, 192, 184)
local IRON = Color3.fromRGB(58, 56, 60)

local model = Instance.new("Model")
model.Name = "Hush"

local function part(name, size, cf, color, material, shape)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = typeof(cf) == "Vector3" and CFrame.new(cf) or cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = false
	p.CanQuery = false
	p.Massless = true
	p.Anchored = false
	p.CastShadow = false
	if shape then p.Shape = shape end
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
	return p1
end

-- a cylinder along an axis ("X", "Y" or "Z"); Roblox cylinders run along X
local function cyl(name, radius, length, pos, axis, color, material)
	local rot = CFrame.new()
	if axis == "Y" then
		rot = CFrame.Angles(0, 0, math.rad(90))
	elseif axis == "Z" then
		rot = CFrame.Angles(0, math.rad(90), 0)
	end
	return part(name, Vector3.new(length, radius * 2, radius * 2), CFrame.new(pos) * rot, color, material, Enum.PartType.Cylinder)
end

-- ── Core ──────────────────────────────────────────────────────
local ROOT_Y = 4.6
local root = part("HumanoidRootPart", Vector3.new(1, 0.4, 0.8), Vector3.new(0, ROOT_Y, 0), HOODIE)
root.Transparency = 1
model.PrimaryPart = root

local pelvis = part("Pelvis", Vector3.new(1.3, 0.5, 0.9), Vector3.new(0, ROOT_Y, 0), PANTS)
motor("Root", root, pelvis, Vector3.new(0, ROOT_Y, 0))

-- ── The hoodie (baggy, too big) ─────────────────────────────
local torso = part("Torso", Vector3.new(1.9, 1.75, 1.35), Vector3.new(0, 5.65, 0), HOODIE)
motor("Waist", pelvis, torso, Vector3.new(0, 4.85, 0))
weld(torso, part("Hem", Vector3.new(2.0, 0.3, 1.45), Vector3.new(0, 4.8, 0), HOODIE_DARK))
weld(torso, part("Pocket", Vector3.new(1.15, 0.55, 0.08), Vector3.new(0, 5.2, -0.71), HOODIE_DARK))
weld(torso, part("PocketLip", Vector3.new(1.15, 0.08, 0.1), Vector3.new(0, 5.47, -0.72), HOODIE_LIGHT))
-- slouchy folds at the sides and back
for _, x in ipairs({ -1, 1 }) do
	weld(torso, part("Fold", Vector3.new(0.12, 1.3, 1.1), Vector3.new(x * 0.98, 5.45, 0), HOODIE_DARK))
end
weld(torso, part("BackFold", Vector3.new(1.4, 0.12, 0.08), Vector3.new(0, 5.9, 0.7), HOODIE_DARK))
-- drawstrings hanging from the hood
for _, x in ipairs({ -0.28, 0.28 }) do
	weld(torso, part("Drawstring", Vector3.new(0.07, 0.75, 0.07), Vector3.new(x, 6.05, -0.72), SOCK))
	weld(torso, part("Aglet", Vector3.new(0.09, 0.12, 0.09), Vector3.new(x, 5.62, -0.72), METAL))
end

-- ── Head, hood and gas mask ──────────────────────────────────
local HEAD_Y = 7.25
local head = part("Head", Vector3.new(1.5, 1.5, 1.5), Vector3.new(0, HEAD_Y, 0), SKIN, nil, Enum.PartType.Ball)
motor("Neck", torso, head, Vector3.new(0, 6.5, 0))
-- the hood: a round shell around the head with a dark opening at the front that the mask pokes out of
weld(head, part("Hood", Vector3.new(2.1, 2.1, 2.1), Vector3.new(0, HEAD_Y + 0.12, 0.14), HOODIE, nil, Enum.PartType.Ball))
weld(head, part("HoodPeak", Vector3.new(0.7, 0.5, 0.7), CFrame.new(0, HEAD_Y + 1.02, 0.45) * CFrame.Angles(math.rad(-25), 0, 0), HOODIE_DARK))
weld(head, part("HoodDroop", Vector3.new(0.7, 0.6, 0.4), Vector3.new(0, HEAD_Y - 0.6, 0.95), HOODIE_DARK))
weld(head, cyl("HoodOpening", 0.74, 0.06, Vector3.new(0, HEAD_Y + 0.02, -0.86), "Z", Color3.fromRGB(18, 16, 24)))
weld(head, cyl("HoodRim", 0.82, 0.05, Vector3.new(0, HEAD_Y + 0.02, -0.84), "Z", HOODIE_LIGHT))
-- gas mask
weld(head, part("Mask", Vector3.new(1.05, 1.0, 0.2), Vector3.new(0, HEAD_Y - 0.05, -0.97), RUBBER, Enum.Material.Rubber))
weld(head, part("MaskBrow", Vector3.new(1.1, 0.16, 0.24), Vector3.new(0, HEAD_Y + 0.38, -0.99), RUBBER_LIGHT, Enum.Material.Rubber))
for _, x in ipairs({ -1, 1 }) do
	weld(head, cyl("LensRim", 0.26, 0.12, Vector3.new(x * 0.28, HEAD_Y + 0.1, -1.1), "Z", METAL, Enum.Material.Metal))
	local lens = weld(head, cyl("Lens", 0.2, 0.08, Vector3.new(x * 0.28, HEAD_Y + 0.1, -1.14), "Z", LENS, Enum.Material.Neon))
	lens.Name = (x < 0) and "LLens" or "RLens"
end
-- the filter canister and its snout
weld(head, part("Snout", Vector3.new(0.48, 0.4, 0.3), Vector3.new(0, HEAD_Y - 0.38, -1.15), RUBBER_LIGHT, Enum.Material.Rubber))
weld(head, cyl("Filter", 0.26, 0.5, Vector3.new(0, HEAD_Y - 0.45, -1.48), "Z", METAL, Enum.Material.Metal))
weld(head, cyl("FilterCap", 0.28, 0.08, Vector3.new(0, HEAD_Y - 0.45, -1.75), "Z", RUBBER, Enum.Material.Rubber))
for k = 0, 2 do
	weld(head, cyl("FilterRing", 0.285, 0.04, Vector3.new(0, HEAD_Y - 0.45, -1.31 - k * 0.13), "Z", RUBBER_LIGHT, Enum.Material.Metal))
end
local lensLight = Instance.new("PointLight")
lensLight.Name = "LensGlow"
lensLight.Color = LENS
lensLight.Brightness = 0.6
lensLight.Range = 7
lensLight.Shadows = false
lensLight.Parent = head

-- ── Arms: out to the sides (crucified), then the oversized sleeves hang down empty from the elbow ──
-- No hands are visible. The right sleeve hides the long pointing finger (joint RFinger); the attack lifts the sleeve
-- toward the wall and slides the finger out of the sleeve opening (UnitAnimator).
local SHOULDER_Y = 6.25
-- a short broken iron chain hanging from `parent` at `pos` (alternating links)
local function chain(parent, name, pos, links)
	for k = 0, links - 1 do
		local link = part(name .. "Link", Vector3.new(0.07, 0.26, 0.17), CFrame.new(pos - Vector3.new(0, 0.13 + k * 0.21, 0)) * CFrame.Angles(0, (k % 2) * math.rad(90), 0), IRON, Enum.Material.Metal)
		weld(parent, link)
	end
end

local UPPER_LEN = 1.35 -- shoulder to elbow; the arm slopes down and out
local UPPER_SLOPE = math.rad(32)
local SEGMENTS = { 1.3, 1.3, 1.25 } -- the hanging sleeve: three loose segments, each a little wider
local SEG_RADIUS = { 0.27, 0.3, 0.33 }

-- returns the elbow position of side x
local function elbowPos(x)
	return Vector3.new(x * (0.95 + math.cos(UPPER_SLOPE) * UPPER_LEN), SHOULDER_Y - math.sin(UPPER_SLOPE) * UPPER_LEN, 0)
end

local function arm(side, x)
	-- the arm part of the sleeve, sloping down and out from the shoulder
	local shoulder = Vector3.new(x * 0.95, SHOULDER_Y, 0)
	local elbow = elbowPos(x)
	local mid = (shoulder + elbow) / 2
	local slope = CFrame.new(mid) * CFrame.Angles(0, 0, -x * UPPER_SLOPE)
	local upper = part(side .. "UpperArm", Vector3.new(UPPER_LEN + 0.2, 0.58, 0.58), slope, HOODIE, nil, Enum.PartType.Cylinder)
	motor(side .. "Shoulder", torso, upper, shoulder)
	weld(upper, part(side .. "SleeveFold", Vector3.new(0.12, 0.64, 0.64), slope * CFrame.new(-x * 0.25, 0, 0), HOODIE_DARK, nil, Enum.PartType.Cylinder))
	-- the nail through the sleeve near the elbow, glowing where it pierces
	local nail = shoulder:Lerp(elbow, 0.72)
	weld(upper, part(side .. "Nail", Vector3.new(0.09, 1.0, 0.09), nail + Vector3.new(0, 0.12, 0), IRON, Enum.Material.Metal))
	weld(upper, part(side .. "NailHead", Vector3.new(0.22, 0.08, 0.22), nail + Vector3.new(0, 0.62, 0), IRON, Enum.Material.Metal))
	weld(upper, part(side .. "Wound", Vector3.new(0.2, 0.04, 0.2), nail + Vector3.new(0, 0.3, 0), LENS, Enum.Material.Neon))

	-- the empty sleeve hanging from the elbow in three loose segments (joints Elbow, Sleeve1, Sleeve2), with folds
	local parent, top = upper, elbow
	local names = { side .. "Elbow", side .. "Sleeve1", side .. "Sleeve2" }
	local segs = {}
	for k, len in ipairs(SEGMENTS) do
		local r = SEG_RADIUS[k]
		local seg = cyl(side .. "Sleeve" .. k, r, len + 0.1, top - Vector3.new(0, len / 2, 0), "Y", HOODIE)
		motor(names[k], parent, seg, top)
		-- a bunched fold where this segment hangs from the one above, slightly askew
		weld(seg, part(side .. "SleeveBunch" .. k, Vector3.new(0.14, r * 2 + 0.1, r * 2 + 0.1), CFrame.new(top - Vector3.new(0, 0.08, 0)) * CFrame.Angles(math.rad(k % 2 == 0 and 10 or -8), 0, math.rad(90 + x * (k * 7))), HOODIE_DARK, nil, Enum.PartType.Cylinder))
		segs[k] = seg
		parent, top = seg, top - Vector3.new(0, len, 0)
	end
	local last = segs[#segs]
	weld(last, cyl(side .. "Cuff", 0.37, 0.22, top + Vector3.new(0, 0.1, 0), "Y", HOODIE_DARK))
	weld(last, cyl(side .. "SleeveOpening", 0.28, 0.04, top - Vector3.new(0, 0.02, 0), "Y", Color3.fromRGB(14, 12, 18)))
	-- an iron shackle around the sleeve above the cuff, a broken chain hanging from it
	weld(last, cyl(side .. "Shackle", 0.37, 0.16, top + Vector3.new(0, 0.55, 0), "Y", IRON, Enum.Material.Metal))
	chain(last, side .. "Chain", top + Vector3.new(x * 0.36, 0.5, 0), 4)
	return last, top
end
arm("L", -1)
local rLast, rOpening = arm("R", 1)
-- the long pointing finger, hidden inside the end of the right sleeve (pointing down it); the attack slides it out
-- (fully inside the sleeve at rest; the attack slides it about 1.6 studs out of the opening)
local FX = rOpening.X
local finger = part("RFingerLong", Vector3.new(0.07, 1.0, 0.07), Vector3.new(FX, rOpening.Y + 0.85, 0), CLAW)
motor("RFinger", rLast, finger, Vector3.new(FX, rOpening.Y + 1.35, 0))
weld(finger, part("RFingerNail", Vector3.new(0.05, 0.3, 0.05), Vector3.new(FX, rOpening.Y + 0.2, 0), CLAW))
local tip = part("FingerTip", Vector3.new(0.1, 0.1, 0.1), Vector3.new(FX, rOpening.Y + 0.1, 0), LENS, Enum.Material.Neon)
tip.Transparency = 1
weld(finger, tip)

-- the hoodie is long, down to mid-thigh
weld(torso, part("LongHem", Vector3.new(1.95, 0.7, 1.4), Vector3.new(0, 4.35, 0), HOODIE))
weld(torso, part("LongHemEdge", Vector3.new(2.0, 0.16, 1.45), Vector3.new(0, 4.03, 0), HOODIE_DARK))

-- ── Legs: thin, bare grey feet pointing down, the ankles bound together ──
local function leg(side, x)
	local thigh = part(side .. "Thigh", Vector3.new(0.4, 0.85, 0.42), Vector3.new(x * 0.3, ROOT_Y - 0.6, 0), PANTS)
	motor(side .. "Hip", pelvis, thigh, Vector3.new(x * 0.3, ROOT_Y - 0.2, 0))
	local shin = part(side .. "Shin", Vector3.new(0.32, 0.9, 0.34), Vector3.new(x * 0.3, ROOT_Y - 1.47, 0), PANTS)
	motor(side .. "Knee", thigh, shin, Vector3.new(x * 0.3, ROOT_Y - 1.02, 0))
	-- bare foot hanging, toes pointing down
	weld(shin, part(side .. "Foot", Vector3.new(0.3, 0.26, 0.62), CFrame.new(x * 0.3, ROOT_Y - 2.12, -0.1) * CFrame.Angles(math.rad(-62), 0, 0), SKIN))
	weld(shin, part(side .. "AnkleShackle", Vector3.new(0.4, 0.14, 0.42), Vector3.new(x * 0.3, ROOT_Y - 1.85, 0), IRON, Enum.Material.Metal))
	return shin
end
leg("L", -1)
local rShin = leg("R", 1)
-- a short chain between the ankle shackles, and a broken end hanging down
for k = 0, 2 do
	weld(rShin, part("AnkleChainLink", Vector3.new(0.2, 0.07, 0.14), CFrame.new(-0.2 + k * 0.2, ROOT_Y - 1.86, -0.02) * CFrame.Angles((k % 2) * math.rad(90), 0, 0), IRON, Enum.Material.Metal))
end
chain(rShin, "AnkleChain", Vector3.new(0.3, ROOT_Y - 1.92, 0.18), 3)

model:SetAttribute("Rig", "Procedural")
model:SetAttribute("RootHeight", ROOT_Y + 5) -- it floats high: the feet hang about 5.3 studs above the ground
model:SetAttribute("Height", 13.6)
model:SetAttribute("Float", 0.3)
model:SetAttribute("Pose", "Crucified")
model:SetAttribute("AttackStyle", "FingerBeam") -- sleeve points at the wall, finger slides out, circle + beam (FingerBeam)
model.Parent = models

local parts, joints = 0, 0
for _, d in ipairs(model:GetDescendants()) do
	if d:IsA("BasePart") then parts += 1 end
	if d:IsA("Motor6D") then joints += 1 end
end
return "Hush built: " .. parts .. " parts, " .. joints .. " joints"
