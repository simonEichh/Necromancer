-- Builds the low-poly rigged The Undying into ServerStorage.Models.TheUndying.
-- Run in Studio's command bar / via the Studio MCP execute_luau (Edit mode). Safe to re-run.
--
-- Standard humanoid rig (see build_skelly.lua and src/client/Modules/UnitAnimator.lua): front = -Z, right = +X,
-- feet on y = 0, root part = HumanoidRootPart at y = 2.2, joints Root/Waist/Neck/L,RShoulder/L,RElbow/L,RHip/
-- L,RKnee plus LWing/RWing (flapped by UnitAnimator), attributes Rig = "Procedural", RootHeight, Height.
-- The game scales it to its size (4).
-- The Eternal pharaoh-phoenix: a bandage-wrapped body under a broad blue-and-gold collar, a golden death mask with
-- a striped nemes headdress, cobra and false beard, a blazing sun disc behind the head, gold armour pieces, a
-- was scepter topped with a flame orb, a floating flame orb in the left hand and a pair of flaming feathered
-- wings. The kilt is split into flaps welded to the legs so it follows the stride.
local ServerStorage = game:GetService("ServerStorage")
local models = ServerStorage.Models

local old = models:FindFirstChild("TheUndying")
if old then
	old:Destroy()
end

local BANDAGE = Color3.fromRGB(232, 222, 196)
local BANDAGE_D = Color3.fromRGB(196, 182, 148)
local GOLD = Color3.fromRGB(240, 200, 90)
local GOLD_D = Color3.fromRGB(180, 140, 50)
local BLUE = Color3.fromRGB(40, 80, 190)
local FLAME = Color3.fromRGB(255, 150, 50)
local FLAME_HOT = Color3.fromRGB(255, 222, 130)
local DARK = Color3.fromRGB(20, 14, 18)
local METAL = Enum.Material.Metal
local NEON = Enum.Material.Neon

local model = Instance.new("Model")
model.Name = "TheUndying"

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
local root = part("HumanoidRootPart", Vector3.new(1.5, 0.4, 0.9), Vector3.new(0, 2.2, 0), BANDAGE)
root.Transparency = 1
model.PrimaryPart = root

local pelvis = part("Pelvis", Vector3.new(1.6, 0.45, 0.95), Vector3.new(0, 2.2, 0), BANDAGE_D)
motor("Root", root, pelvis, Vector3.new(0, 2.2, 0))
weld(pelvis, part("Belt", Vector3.new(1.88, 0.22, 1.08), Vector3.new(0, 2.45, 0), GOLD, METAL))

-- torso: bandage wraps, a broad blue-and-gold collar and a glowing scarab
local torso = part("Torso", Vector3.new(1.8, 1.5, 1.0), Vector3.new(0, 3.1, 0), BANDAGE)
motor("Waist", pelvis, torso, Vector3.new(0, 2.4, 0))
for i, y in ipairs({ 2.75, 3.05, 3.35 }) do
	weld(torso, part("Wrap" .. i, Vector3.new(1.86, 0.1, 1.06), Vector3.new(0, y, 0), BANDAGE_D))
end
weld(torso, part("CollarGold1", Vector3.new(2.2, 0.2, 1.3), Vector3.new(0, 3.85, 0), GOLD, METAL))
weld(torso, part("CollarBlue", Vector3.new(1.9, 0.18, 1.15), Vector3.new(0, 3.66, 0), BLUE))
weld(torso, part("CollarGold2", Vector3.new(1.6, 0.16, 1.0), Vector3.new(0, 3.5, 0), GOLD, METAL))
weld(torso, part("ScarabFrame", Vector3.new(0.5, 0.5, 0.08), Vector3.new(0, 3.1, -0.54), GOLD, METAL))
weld(torso, part("Scarab", Vector3.new(0.32, 0.32, 0.1), Vector3.new(0, 3.1, -0.58), Color3.fromRGB(80, 170, 255), NEON))

-- ── Head: golden death mask, striped headdress, cobra, false beard, sun disc ──
local head = part("Head", Vector3.new(1.1, 1.25, 1.0), Vector3.new(0, 4.55, 0), GOLD, METAL)
motor("Neck", torso, head, Vector3.new(0, 3.95, 0))
for _, x in ipairs({ -1, 1 }) do
	weld(head, part("EyeSlit", Vector3.new(0.34, 0.2, 0.1), Vector3.new(x * 0.26, 4.65, -0.52), DARK))
	weld(head, part("EyeFlame", Vector3.new(0.16, 0.1, 0.1), Vector3.new(x * 0.26, 4.65, -0.55), FLAME_HOT, NEON))
	weld(head, part("Kohl", Vector3.new(0.44, 0.07, 0.08), Vector3.new(x * 0.26, 4.82, -0.52), BLUE))
	-- side lappets of the headdress
	weld(head, part("SideLappet", Vector3.new(0.3, 1.5, 0.5), Vector3.new(x * 0.78, 4.0, -0.15), BLUE))
	for i, y in ipairs({ 4.5, 4.1, 3.7 }) do
		weld(head, part("SideStripe" .. i, Vector3.new(0.32, 0.1, 0.52), Vector3.new(x * 0.78, y, -0.15), GOLD, METAL))
	end
end
weld(head, part("Nose", Vector3.new(0.18, 0.4, 0.14), Vector3.new(0, 4.45, -0.56), GOLD_D, METAL))
weld(head, part("MouthLine", Vector3.new(0.4, 0.06, 0.06), Vector3.new(0, 4.1, -0.52), DARK))
weld(head, part("Beard", Vector3.new(0.24, 0.7, 0.24), Vector3.new(0, 3.75, -0.45), BLUE))
weld(head, part("BeardBand1", Vector3.new(0.28, 0.08, 0.28), Vector3.new(0, 3.95, -0.45), GOLD, METAL))
weld(head, part("BeardBand2", Vector3.new(0.28, 0.08, 0.28), Vector3.new(0, 3.65, -0.45), GOLD, METAL))
weld(head, part("HeadTop", Vector3.new(1.5, 0.3, 1.5), Vector3.new(0, 5.25, 0), BLUE))
weld(head, part("HeadBand", Vector3.new(1.52, 0.1, 1.52), Vector3.new(0, 5.05, 0), GOLD, METAL))
weld(head, part("BackLappet", Vector3.new(1.5, 2.0, 0.3), Vector3.new(0, 4.1, 0.62), BLUE))
for i, y in ipairs({ 4.9, 4.5, 4.1, 3.7, 3.3 }) do
	weld(head, part("BackStripe" .. i, Vector3.new(1.52, 0.1, 0.32), Vector3.new(0, y, 0.62), GOLD, METAL))
end
weld(head, part("CobraBase", Vector3.new(0.22, 0.22, 0.14), Vector3.new(0, 5.05, -0.62), GOLD, METAL))
weld(head, part("CobraHood", Vector3.new(0.16, 0.42, 0.1), Vector3.new(0, 5.35, -0.62), GOLD, METAL))
for _, dx in ipairs({ -0.04, 0.04 }) do
	weld(head, part("CobraEye", Vector3.new(0.04, 0.04, 0.04), Vector3.new(dx, 5.42, -0.68), Color3.fromRGB(255, 60, 60), NEON))
end
-- blazing sun disc behind the head
local sun = discFront("SunDisc", 3.0, 0.12, Vector3.new(0, 5.0, 1.1), FLAME_HOT, NEON)
weld(head, sun)

-- ── Arms: wrapped, with gold pauldrons, vambraces and gauntlets (character's right = +X) ──
local function arm(side, x)
	local upper = part(side .. "UpperArm", Vector3.new(0.5, 0.95, 0.5), Vector3.new(x, 3.075, 0), BANDAGE)
	motor(side .. "Shoulder", torso, upper, Vector3.new(x, 3.6, 0))
	weld(upper, part(side .. "Pauldron", Vector3.new(0.9, 0.3, 0.9), Vector3.new(x, 3.72, 0), GOLD, METAL))
	local fore = part(side .. "Forearm", Vector3.new(0.45, 0.9, 0.45), Vector3.new(x, 2.15, 0), BANDAGE_D)
	motor(side .. "Elbow", upper, fore, Vector3.new(x, 2.6, 0))
	weld(fore, part(side .. "Vambrace", Vector3.new(0.56, 0.5, 0.56), Vector3.new(x, 2.0, 0), GOLD, METAL))
	local gauntlet = part(side .. "Gauntlet", Vector3.new(0.5, 0.35, 0.5), Vector3.new(x, 1.55, 0), GOLD, METAL)
	weld(fore, gauntlet)
	return fore, gauntlet
end
local lFore = arm("L", -1.3)
local _, rHand = arm("R", 1.3)

-- was scepter in the right hand: a gold shaft with prongs holding a flame orb
weld(rHand, part("ScepterShaft", Vector3.new(0.16, 4.8, 0.16), Vector3.new(1.3, 2.4, -0.05), GOLD, METAL))
for _, dx in ipairs({ -0.3, 0.3 }) do
	weld(rHand, part("ScepterProng", Vector3.new(0.14, 0.7, 0.14), Vector3.new(1.3 + dx, 5.0, -0.05), GOLD, METAL))
end
local orb = part("ScepterOrb", Vector3.new(0.6, 0.6, 0.6), Vector3.new(1.3, 5.15, -0.05), FLAME, NEON)
orb.Shape = Enum.PartType.Ball
weld(rHand, orb)
-- a flame orb floating at the left hand
local lorb = part("HandOrb", Vector3.new(0.45, 0.45, 0.45), Vector3.new(-1.3, 1.0, -0.45), FLAME, NEON)
lorb.Shape = Enum.PartType.Ball
weld(lFore, lorb)

-- ── Wings of flame: a gold bar with feathers of fire, flapped by LWing/RWing ──
local function wing(side, sx)
	local rootPart = part(side .. "WingRoot", Vector3.new(0.3, 0.3, 0.3), Vector3.new(sx * 0.8, 4.0, 0.6), GOLD_D, METAL)
	motor(side .. "Wing", torso, rootPart, Vector3.new(sx * 0.7, 4.0, 0.55))
	weld(rootPart, part(side .. "WingBar", Vector3.new(2.8, 0.16, 0.16), Vector3.new(sx * 2.1, 4.3, 0.6), GOLD, METAL))
	for i, d in ipairs({ { 1.0, 3.0 }, { 1.5, 2.8 }, { 2.0, 2.5 }, { 2.5, 2.1 }, { 3.0, 1.7 }, { 3.5, 1.3 } }) do
		weld(rootPart, part(side .. "Feather" .. i, Vector3.new(0.34, d[2], 0.06), Vector3.new(sx * d[1], 4.3 - d[2] / 2, 0.6), i % 2 == 0 and FLAME_HOT or FLAME, NEON))
	end
end
wing("L", -1)
wing("R", 1)

-- ── Legs: kilt flaps follow the stride, gold hems and sandals ──
local function leg(side, x)
	local upper = part(side .. "UpperLeg", Vector3.new(0.75, 0.9, 0.95), Vector3.new(x, 1.55, 0), BANDAGE)
	motor(side .. "Hip", pelvis, upper, Vector3.new(x, 2.0, 0))
	local lower = part(side .. "LowerLeg", Vector3.new(0.65, 0.8, 0.9), Vector3.new(x, 0.7, 0), BANDAGE_D)
	motor(side .. "Knee", upper, lower, Vector3.new(x, 1.1, 0))
	weld(lower, part("Hem" .. side, Vector3.new(0.7, 0.1, 0.92), Vector3.new(x, 0.32, 0), GOLD, METAL))
	weld(lower, part("Sandal" .. side, Vector3.new(0.5, 0.2, 0.85), Vector3.new(x, 0.1, -0.2), GOLD, METAL))
end
leg("L", -0.42)
leg("R", 0.42)

-- warm glow from the sun disc, wings and orbs (no shadows, see CLAUDE.md)
local light = Instance.new("PointLight")
light.Name = "SunLight"
light.Color = FLAME_HOT
light.Brightness = 1.2
light.Range = 14
light.Shadows = false
light.Parent = torso

model:SetAttribute("Rig", "Procedural")
model:SetAttribute("RootHeight", 2.2)
model:SetAttribute("Height", 6.8)
model.Parent = models

local count = 0
for _, d in ipairs(model:GetDescendants()) do
	if d:IsA("Motor6D") then count += 1 end
end
return "TheUndying built: " .. #model:GetChildren() .. " parts, " .. count .. " joints"
