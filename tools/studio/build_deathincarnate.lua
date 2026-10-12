-- Builds the low-poly rigged Death Incarnate into ServerStorage.Models.DeathIncarnate.
-- Run in Studio's command bar / via the Studio MCP execute_luau (Edit mode). Safe to re-run.
--
-- Standard humanoid rig (see build_skelly.lua and src/client/Modules/UnitAnimator.lua): front = -Z, right = +X,
-- feet on y = 0, root part = HumanoidRootPart at y = 2.2, joints Root/Waist/Neck/Jaw/L,RShoulder/L,RElbow/
-- L,RHip/L,RKnee, attributes Rig = "Procedural", RootHeight, Height. The game scales it to its size (5).
-- The Eternal-tier Death: a towering hooded figure in a starry night-black robe with gold trim, an antlered
-- skull with burning gold eyes and a halo of eternity behind the hood, an open ribcage with a glowing
-- hourglass for a heart, bony arms with gold bracers and a giant golden-edged scythe (the attack sweeps it).
local ServerStorage = game:GetService("ServerStorage")
local models = ServerStorage.Models

local old = models:FindFirstChild("DeathIncarnate")
if old then
	old:Destroy()
end

local ROBE = Color3.fromRGB(14, 12, 28)
local ROBE_L = Color3.fromRGB(34, 28, 62)
local VOID = Color3.fromRGB(6, 4, 12)
local BONE = Color3.fromRGB(236, 230, 214)
local BONE_SHADE = Color3.fromRGB(184, 176, 158)
local GOLD = Color3.fromRGB(232, 196, 96)
local GLOW = Color3.fromRGB(255, 226, 130)
local STAR = Color3.fromRGB(255, 255, 255)
local BLADE = Color3.fromRGB(232, 238, 255)
local METAL = Enum.Material.Metal
local NEON = Enum.Material.Neon

local model = Instance.new("Model")
model.Name = "DeathIncarnate"

local function part(name, size, cf, color, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = typeof(cf) == "Vector3" and CFrame.new(cf) or cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = false
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

-- a flat disc (Cylinder part) facing the front (-Z)
local FACE_FRONT = CFrame.Angles(0, math.rad(90), 0)
local function discFront(name, diameter, thickness, pos, color, material)
	local p = part(name, Vector3.new(thickness, diameter, diameter), CFrame.new(pos) * FACE_FRONT, color, material)
	p.Shape = Enum.PartType.Cylinder
	return p
end

-- ── Core ──────────────────────────────────────────────────────
local root = part("HumanoidRootPart", Vector3.new(1.3, 0.4, 0.9), Vector3.new(0, 2.2, 0), ROBE)
root.Transparency = 1
model.PrimaryPart = root

local pelvis = part("Pelvis", Vector3.new(1.4, 0.4, 0.9), Vector3.new(0, 2.2, 0), ROBE_L)
motor("Root", root, pelvis, Vector3.new(0, 2.2, 0))

local torso = part("Torso", Vector3.new(1.9, 1.6, 1.05), Vector3.new(0, 3.15, 0), ROBE)
motor("Waist", pelvis, torso, Vector3.new(0, 2.4, 0))
-- open robe: a dark hollow with bare ribs and a glowing hourglass heart
weld(torso, part("ChestHollow", Vector3.new(1.0, 1.3, 0.1), Vector3.new(0, 3.2, -0.56), VOID))
for i, y in ipairs({ 3.65, 3.4, 3.15, 2.9 }) do
	weld(torso, part("Rib" .. i, Vector3.new(0.9, 0.1, 0.08), Vector3.new(0, y, -0.62), BONE))
end
weld(torso, part("HourglassTop", Vector3.new(0.4, 0.06, 0.3), Vector3.new(0, 3.54, -0.68), GOLD, METAL))
weld(torso, part("HourglassBottom", Vector3.new(0.4, 0.06, 0.3), Vector3.new(0, 2.86, -0.68), GOLD, METAL))
weld(torso, part("HourglassGlass", Vector3.new(0.2, 0.6, 0.18), Vector3.new(0, 3.2, -0.68), GLOW, NEON))
for _, x in ipairs({ -1, 1 }) do
	weld(torso, part("RobeFlap", Vector3.new(0.55, 1.5, 0.1), Vector3.new(x * 0.72, 3.15, -0.57), ROBE_L))
	weld(torso, part("RobeEdge", Vector3.new(0.06, 1.5, 0.12), Vector3.new(x * 0.42, 3.15, -0.58), GOLD, METAL))
end
weld(torso, part("Mantle", Vector3.new(2.5, 0.4, 1.3), Vector3.new(0, 3.95, 0), ROBE_L))
weld(torso, part("MantleTrim", Vector3.new(2.56, 0.08, 1.36), Vector3.new(0, 3.76, 0), GOLD, METAL))
-- tattered cape and starry specks
weld(torso, part("Cape", Vector3.new(2.0, 3.0, 0.12), Vector3.new(0, 2.4, 0.85), ROBE))
for i, x in ipairs({ -0.7, 0, 0.7 }) do
	weld(torso, part("CapeTatter" .. i, Vector3.new(0.55, 0.9 + (i % 2) * 0.5, 0.12), Vector3.new(x, 0.55 - (i % 2) * 0.25, 0.85), ROBE))
end
for i, p in ipairs({ { -0.7, 3.4, -0.58 }, { 0.75, 2.9, -0.58 }, { -0.8, 2.6, -0.58 }, { -0.5, 4.0, 0.0 }, { 0.6, 4.0, -0.3 }, { 0.3, 2.5, 0.92 }, { -0.6, 3.2, 0.92 } }) do
	weld(torso, part("Star" .. i, Vector3.new(0.1, 0.1, 0.1), Vector3.new(p[1], p[2], p[3]), STAR, NEON))
end

-- ── Head: antlered skull in a deep hood, halo of eternity behind ──
local head = part("Head", Vector3.new(1.0, 1.05, 1.0), Vector3.new(0, 4.5, 0), BONE)
motor("Neck", torso, head, Vector3.new(0, 3.95, 0))
weld(head, part("HoodBack", Vector3.new(1.5, 1.5, 0.3), Vector3.new(0, 4.6, 0.58), ROBE))
weld(head, part("HoodTop", Vector3.new(1.5, 0.3, 1.6), Vector3.new(0, 5.2, 0.1), ROBE))
weld(head, part("HoodPeak", Vector3.new(0.6, 0.5, 0.6), Vector3.new(0, 5.55, 0.4), ROBE_L))
for _, x in ipairs({ -1, 1 }) do
	weld(head, part("HoodSide", Vector3.new(0.28, 1.5, 1.3), Vector3.new(x * 0.68, 4.6, 0.0), ROBE))
	weld(head, part("HoodRimSide", Vector3.new(0.1, 1.25, 0.1), Vector3.new(x * 0.55, 4.6, -0.66), GOLD, METAL))
	weld(head, part("EyeSocket", Vector3.new(0.32, 0.32, 0.1), Vector3.new(x * 0.24, 4.58, -0.5), VOID))
	weld(head, part("EyeGlow", Vector3.new(0.18, 0.18, 0.1), Vector3.new(x * 0.24, 4.58, -0.54), GLOW, NEON))
	-- antlers: a main beam with three tines, golden tips
	weld(head, part("AntlerBeam", Vector3.new(0.18, 1.1, 0.18), Vector3.new(x * 0.55, 6.0, 0.15), BONE))
	weld(head, part("AntlerTineA", Vector3.new(0.14, 0.55, 0.14), Vector3.new(x * 0.85, 6.3, 0.15), BONE))
	weld(head, part("AntlerTineB", Vector3.new(0.14, 0.5, 0.14), Vector3.new(x * 0.3, 6.45, 0.15), BONE))
	weld(head, part("AntlerTineC", Vector3.new(0.12, 0.4, 0.12), Vector3.new(x * 1.0, 6.7, 0.15), BONE))
	weld(head, part("AntlerTipA", Vector3.new(0.14, 0.14, 0.14), Vector3.new(x * 0.55, 6.62, 0.15), GLOW, NEON))
	weld(head, part("AntlerTipB", Vector3.new(0.14, 0.14, 0.14), Vector3.new(x * 1.0, 6.98, 0.15), GLOW, NEON))
end
weld(head, part("HoodRimTop", Vector3.new(1.2, 0.1, 0.1), Vector3.new(0, 5.05, -0.66), GOLD, METAL))
weld(head, part("NoseHole", Vector3.new(0.12, 0.18, 0.08), Vector3.new(0, 4.4, -0.5), VOID))
local halo = discFront("Halo", 2.8, 0.1, Vector3.new(0, 5.1, 1.05), GLOW, NEON)
weld(head, halo)
local jaw = part("Jaw", Vector3.new(0.8, 0.26, 0.72), Vector3.new(0, 4.05, -0.08), BONE_SHADE)
motor("Jaw", head, jaw, Vector3.new(0, 4.13, 0.28))
for i, x in ipairs({ -0.3, -0.15, 0, 0.15, 0.3 }) do
	weld(jaw, part("Tooth" .. i, Vector3.new(0.1, 0.12 + (i % 2) * 0.1, 0.06), Vector3.new(x, 4.16, -0.45), BONE))
end

-- ── Arms: ragged sleeves, bare bone forearms with gold bracers (character's right = +X) ──
local function arm(side, x)
	local upper = part(side .. "UpperArm", Vector3.new(0.5, 1.0, 0.5), Vector3.new(x, 3.2, 0), ROBE_L)
	motor(side .. "Shoulder", torso, upper, Vector3.new(x, 3.7, 0))
	local fore = part(side .. "Forearm", Vector3.new(0.3, 0.95, 0.3), Vector3.new(x, 2.2, 0), BONE_SHADE)
	motor(side .. "Elbow", upper, fore, Vector3.new(x, 2.7, 0))
	weld(fore, part(side .. "Cuff", Vector3.new(0.7, 0.4, 0.7), Vector3.new(x, 2.55, 0), ROBE))
	weld(fore, part(side .. "Bracer", Vector3.new(0.45, 0.35, 0.45), Vector3.new(x, 1.95, 0), GOLD, METAL))
	local hand = part(side .. "Hand", Vector3.new(0.3, 0.3, 0.3), Vector3.new(x, 1.65, 0), BONE)
	weld(fore, hand)
	for _, dx in ipairs({ -0.1, 0, 0.1 }) do
		weld(fore, part(side .. "Finger", Vector3.new(0.05, 0.35, 0.05), Vector3.new(x + dx, 1.35, -0.06), BONE))
	end
	return hand
end
arm("L", -1.3)
local rHand = arm("R", 1.3)

-- giant scythe: gold-ringed shaft, a pale blade with a glowing edge curving forward from the top
weld(rHand, part("ScytheShaft", Vector3.new(0.16, 5.6, 0.16), Vector3.new(1.3, 2.8, -0.05), BONE_SHADE))
for i, y in ipairs({ 1.2, 3.0, 4.6 }) do
	weld(rHand, part("ScytheRing" .. i, Vector3.new(0.28, 0.12, 0.28), Vector3.new(1.3, y, -0.05), GOLD, METAL))
end
weld(rHand, part("ScytheCap", Vector3.new(0.3, 0.24, 0.3), Vector3.new(1.3, 5.7, -0.05), GOLD, METAL))
weld(rHand, part("BladeTop", Vector3.new(0.14, 0.32, 1.5), Vector3.new(1.3, 5.5, -0.75), BLADE, METAL))
weld(rHand, part("BladeDrop", Vector3.new(0.14, 0.7, 0.32), Vector3.new(1.3, 5.1, -1.45), BLADE, METAL))
weld(rHand, part("BladeTip", Vector3.new(0.12, 0.25, 0.5), Vector3.new(1.3, 4.65, -1.3), BLADE, METAL))
weld(rHand, part("BladeEdge", Vector3.new(0.06, 0.06, 1.5), Vector3.new(1.3, 5.32, -0.75), GLOW, NEON))

-- ── Legs: robe flaps follow the stride, gold hems ─────────────
local function leg(side, x)
	local upper = part(side .. "UpperLeg", Vector3.new(0.8, 0.9, 1.0), Vector3.new(x, 1.55, 0), ROBE)
	motor(side .. "Hip", pelvis, upper, Vector3.new(x, 2.0, 0))
	local lower = part(side .. "LowerLeg", Vector3.new(0.7, 0.8, 0.9), Vector3.new(x, 0.7, 0), ROBE_L)
	motor(side .. "Knee", upper, lower, Vector3.new(x, 1.1, 0))
	weld(lower, part("Hem" .. side, Vector3.new(0.74, 0.1, 0.94), Vector3.new(x, 0.32, 0), GOLD, METAL))
	weld(lower, part("Boot" .. side, Vector3.new(0.5, 0.22, 0.85), Vector3.new(x, 0.11, -0.2), BONE_SHADE))
end
leg("L", -0.45)
leg("R", 0.45)

-- golden glow from the eyes, halo and hourglass (no shadows, see CLAUDE.md)
local light = Instance.new("PointLight")
light.Name = "DeathLight"
light.Color = GLOW
light.Brightness = 1
light.Range = 12
light.Shadows = false
light.Parent = torso

model:SetAttribute("Rig", "Procedural")
model:SetAttribute("RootHeight", 2.2)
model:SetAttribute("Height", 7.2)
model.Parent = models

local count = 0
for _, d in ipairs(model:GetDescendants()) do
	if d:IsA("Motor6D") then count += 1 end
end
return "DeathIncarnate built: " .. #model:GetChildren() .. " parts, " .. count .. " joints"
