-- Builds the low-poly rigged Lich Acolyte into ServerStorage.Models.LichAcolyte.
-- Run in Studio's command bar / via the Studio MCP execute_luau (Edit mode).
-- The old Creator Store model is kept as LichAcolyte_Old until the new one is approved.
--
-- Same rig conventions as build_skelly.lua (see src/client/Modules/UnitAnimator.lua):
--   * front = -Z, character's right = +X, feet on y = 0, root part = HumanoidRootPart at y = 2.2
--   * Motor6Ds named Root/Waist/Neck/Jaw/LShoulder/RShoulder/LElbow/RElbow/LHip/RHip/LKnee/RKnee
--   * attributes: Rig = "Procedural", RootHeight, Height
-- A robed apprentice necromancer: a bone skull inside a deep purple hood with glowing violet eyes, a
-- mantle and sash with a little skull trinket, wide sleeves and a skull-topped staff with a glowing orb
-- in the right hand (the attack swing raises it like a cast). The robe is split into flaps welded to the
-- legs, so it swings with the stride instead of clipping through it.
-- Spellcaster: the staff hangs off its own RStaff joint (forearm -> StaffRoot) so UnitAnimator can point it forward,
-- and the attributes AttackStyle/CastColor/CastPart make it fire a volley of orbs from a magic circle
-- (see src/client/Modules/SpellEffects.lua).
local ServerStorage = game:GetService("ServerStorage")
local models = ServerStorage.Models

local old = models:FindFirstChild("LichAcolyte")
if old and old:GetAttribute("Rig") ~= "Procedural" then
	old.Name = "LichAcolyte_Old"
elseif old then
	old:Destroy()
end

local ROBE = Color3.fromRGB(62, 36, 98)
local ROBE_DARK = Color3.fromRGB(38, 22, 62)
local BONE = Color3.fromRGB(224, 216, 194)
local BONE_SHADE = Color3.fromRGB(178, 168, 148)
local GLOW = Color3.fromRGB(172, 112, 255)
local WOOD = Color3.fromRGB(72, 54, 46)
local HOLLOW = Color3.fromRGB(22, 14, 34)

local model = Instance.new("Model")
model.Name = "LichAcolyte"

local function part(name, size, pos, color, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = CFrame.new(pos)
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

-- ── Core ──────────────────────────────────────────────────────
local root = part("HumanoidRootPart", Vector3.new(1.2, 0.4, 0.8), Vector3.new(0, 2.2, 0), ROBE)
root.Transparency = 1
model.PrimaryPart = root

local pelvis = part("Pelvis", Vector3.new(1.4, 0.4, 0.9), Vector3.new(0, 2.2, 0), ROBE_DARK)
motor("Root", root, pelvis, Vector3.new(0, 2.2, 0))

local torso = part("Torso", Vector3.new(1.5, 1.3, 0.9), Vector3.new(0, 3.05, 0), ROBE)
motor("Waist", pelvis, torso, Vector3.new(0, 2.4, 0))
weld(torso, part("Mantle", Vector3.new(1.95, 0.3, 1.1), Vector3.new(0, 3.65, 0), ROBE_DARK))
weld(torso, part("Sash", Vector3.new(1.58, 0.2, 0.98), Vector3.new(0, 2.55, 0), GLOW, Enum.Material.Neon))
-- little skull hanging from the sash
weld(torso, part("TrinketSkull", Vector3.new(0.3, 0.3, 0.2), Vector3.new(0.5, 2.25, -0.5), BONE))
for _, dx in ipairs({ -0.07, 0.07 }) do
	weld(torso, part("TrinketEye", Vector3.new(0.07, 0.08, 0.05), Vector3.new(0.5 + dx, 2.28, -0.61), HOLLOW))
end

-- ── Head: skull in a deep hood ────────────────────────────────
local head = part("Head", Vector3.new(0.95, 1.0, 0.95), Vector3.new(0, 4.35, 0), BONE)
motor("Neck", torso, head, Vector3.new(0, 3.7, 0))
weld(head, part("HoodBack", Vector3.new(1.35, 1.35, 0.3), Vector3.new(0, 4.4, 0.55), ROBE))
weld(head, part("HoodTop", Vector3.new(1.35, 0.3, 1.45), Vector3.new(0, 5.0, 0.08), ROBE))
weld(head, part("HoodPeak", Vector3.new(0.5, 0.35, 0.5), Vector3.new(0, 5.25, 0.35), ROBE_DARK))
for _, x in ipairs({ -1, 1 }) do
	weld(head, part("HoodSide", Vector3.new(0.24, 1.35, 1.2), Vector3.new(x * 0.6, 4.4, 0.0), ROBE))
	weld(head, part("EyeSocket", Vector3.new(0.3, 0.3, 0.1), Vector3.new(x * 0.22, 4.45, -0.48), HOLLOW))
	weld(head, part("EyeGlow", Vector3.new(0.14, 0.14, 0.1), Vector3.new(x * 0.22, 4.45, -0.53), GLOW, Enum.Material.Neon))
end
weld(head, part("NoseHole", Vector3.new(0.12, 0.18, 0.08), Vector3.new(0, 4.25, -0.49), HOLLOW))
local jaw = part("Jaw", Vector3.new(0.78, 0.26, 0.7), Vector3.new(0, 3.92, -0.08), BONE_SHADE)
motor("Jaw", head, jaw, Vector3.new(0, 4.0, 0.28))

-- ── Arms: wide sleeves and bone hands (character's right = +X) ──
local function arm(side, x)
	local upper = part(side .. "UpperArm", Vector3.new(0.45, 0.95, 0.45), Vector3.new(x, 3.075, 0), ROBE)
	motor(side .. "Shoulder", torso, upper, Vector3.new(x, 3.55, 0))
	local fore = part(side .. "Forearm", Vector3.new(0.55, 0.9, 0.55), Vector3.new(x, 2.15, 0), ROBE_DARK)
	motor(side .. "Elbow", upper, fore, Vector3.new(x, 2.6, 0))
	local hand = part(side .. "Hand", Vector3.new(0.28, 0.3, 0.28), Vector3.new(x, 1.58, 0), BONE)
	weld(fore, hand)
	return hand, fore
end
local lHand = arm("L", -1.05)
local _, rFore = arm("R", 1.05)

-- staff in the right hand: wooden shaft, skull on top and a glowing orb above it. All its parts hang off an invisible
-- StaffRoot that is joined to the forearm by the RStaff joint (pivot = the hand), so the animator can point it forward.
local staffRoot = part("StaffRoot", Vector3.new(0.2, 0.2, 0.2), Vector3.new(1.05, 1.58, -0.05), WOOD)
staffRoot.Transparency = 1
motor("RStaff", rFore, staffRoot, Vector3.new(1.05, 1.58, -0.05))
weld(staffRoot, part("StaffShaft", Vector3.new(0.14, 3.8, 0.14), Vector3.new(1.05, 2.0, -0.05), WOOD))
weld(staffRoot, part("StaffSkull", Vector3.new(0.5, 0.5, 0.45), Vector3.new(1.05, 4.15, -0.05), BONE))
for _, dx in ipairs({ -0.12, 0.12 }) do
	weld(staffRoot, part("StaffSkullEye", Vector3.new(0.12, 0.12, 0.05), Vector3.new(1.05 + dx, 4.18, -0.3), GLOW, Enum.Material.Neon))
end
weld(staffRoot, part("StaffOrb", Vector3.new(0.5, 0.5, 0.5), Vector3.new(1.05, 4.72, -0.05), GLOW, Enum.Material.Neon))

-- a small violet wisp hovering over the left hand
weld(lHand, part("Wisp", Vector3.new(0.3, 0.3, 0.3), Vector3.new(-1.05, 1.15, -0.3), GLOW, Enum.Material.Neon))

-- ── Legs: robe flaps follow the stride ─────────────────────────
local function leg(side, x)
	local upper = part(side .. "UpperLeg", Vector3.new(0.7, 0.9, 0.9), Vector3.new(x, 1.55, 0), ROBE)
	motor(side .. "Hip", pelvis, upper, Vector3.new(x, 2.0, 0))
	local lower = part(side .. "LowerLeg", Vector3.new(0.66, 0.8, 0.85), Vector3.new(x, 0.7, 0), ROBE_DARK)
	motor(side .. "Knee", upper, lower, Vector3.new(x, 1.1, 0))
	weld(lower, part("Hem" .. side, Vector3.new(0.7, 0.12, 0.9), Vector3.new(x, 0.3, 0), GLOW, Enum.Material.Neon))
	weld(lower, part("Boot" .. side, Vector3.new(0.5, 0.25, 0.8), Vector3.new(x, 0.12, -0.2), BONE_SHADE))
end
leg("L", -0.4)
leg("R", 0.4)

model:SetAttribute("Rig", "Procedural")
model:SetAttribute("RootHeight", 2.2)
model:SetAttribute("Height", 5.4)
model:SetAttribute("AttackStyle", "StaffCast")
model:SetAttribute("CastColor", GLOW)
model:SetAttribute("CastPart", "StaffOrb")
model.Parent = models

local count = 0
for _, d in ipairs(model:GetDescendants()) do
	if d:IsA("Motor6D") then count += 1 end
end
return "LichAcolyte built: " .. #model:GetChildren() .. " parts, " .. count .. " joints"
