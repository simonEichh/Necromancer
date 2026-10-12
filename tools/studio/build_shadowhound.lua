-- Builds the low-poly rigged Shadow Hound into ServerStorage.Models.ShadowHound.
-- Run in Studio's command bar / via the Studio MCP execute_luau (Edit mode). Safe to re-run.
--
-- A FOUR-LEGGED rig (see src/client/Modules/UnitAnimator.lua): front = -Z, feet on y = 0, root part =
-- HumanoidRootPart at y = 1.8 (RootHeight 1.8). The body runs along Z. The hind legs use LHip/RHip + LKnee/
-- RKnee on the pelvis (rear), the front legs use LShoulder/RShoulder + LElbow/RElbow on the torso (front),
-- so the humanoid walk cycle becomes a trot (and the attack swipes a front paw). Root/Waist/Neck/Jaw as usual.
-- A lean black hound of living shadow: spiky mane along the spine, pointed ears, burning red eyes and
-- a glowing ember maw.
local ServerStorage = game:GetService("ServerStorage")
local models = ServerStorage.Models

local old = models:FindFirstChild("ShadowHound")
if old then
	old:Destroy()
end

local FUR = Color3.fromRGB(34, 28, 46)
local FUR_DARK = Color3.fromRGB(20, 16, 30)
local SPIKE = Color3.fromRGB(86, 60, 120)
local EYE = Color3.fromRGB(255, 70, 50)
local EMBER = Color3.fromRGB(255, 120, 60)
local TEETH = Color3.fromRGB(240, 236, 226)
local CLAW = Color3.fromRGB(200, 190, 200)

local model = Instance.new("Model")
model.Name = "ShadowHound"

local function part(name, size, pos, color, material, transparency)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = CFrame.new(pos)
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Transparency = transparency or 0
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = false
	p.CanQuery = false
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

-- ── Body: pelvis at the rear, torso (chest) at the front ──────
local root = part("HumanoidRootPart", Vector3.new(1.0, 0.4, 1.4), Vector3.new(0, 1.8, 0.5), FUR)
root.Transparency = 1
model.PrimaryPart = root

local pelvis = part("Pelvis", Vector3.new(1.0, 1.0, 1.2), Vector3.new(0, 1.8, 0.7), FUR)
motor("Root", root, pelvis, Vector3.new(0, 1.8, 0.5))

local torso = part("Torso", Vector3.new(1.2, 1.2, 1.4), Vector3.new(0, 1.9, -0.5), FUR)
motor("Waist", pelvis, torso, Vector3.new(0, 1.8, 0.15))
weld(torso, part("Chest", Vector3.new(0.8, 0.7, 0.2), Vector3.new(0, 1.65, -1.15), FUR_DARK))
-- spiky mane down the spine and a tail with a spiky tip
for i, z in ipairs({ -1.0, -0.5, 0.0 }) do
	weld(torso, part("ManeSpike" .. i, Vector3.new(0.2, 0.55 - i * 0.05, 0.28), Vector3.new(0, 2.7, z), SPIKE))
end
for i, z in ipairs({ 0.4, 0.9 }) do
	weld(pelvis, part("BackSpike" .. i, Vector3.new(0.18, 0.4, 0.26), Vector3.new(0, 2.5, z), SPIKE))
end
weld(pelvis, part("Tail1", Vector3.new(0.3, 0.3, 0.8), Vector3.new(0, 2.0, 1.55), FUR))
weld(pelvis, part("Tail2", Vector3.new(0.24, 0.7, 0.24), Vector3.new(0, 2.4, 1.9), FUR))
weld(pelvis, part("TailSpike", Vector3.new(0.2, 0.4, 0.2), Vector3.new(0, 2.9, 1.9), SPIKE))

-- ── Head: skull, long snout, pointed ears, burning eyes, ember maw ──
local head = part("Head", Vector3.new(0.9, 0.85, 0.95), Vector3.new(0, 2.45, -1.55), FUR)
motor("Neck", torso, head, Vector3.new(0, 2.2, -1.1))
weld(head, part("Snout", Vector3.new(0.55, 0.42, 0.7), Vector3.new(0, 2.3, -2.2), FUR_DARK))
weld(head, part("Nose", Vector3.new(0.3, 0.2, 0.12), Vector3.new(0, 2.42, -2.58), CLAW))
for _, x in ipairs({ -1, 1 }) do
	weld(head, part("Ear", Vector3.new(0.22, 0.65, 0.22), Vector3.new(x * 0.3, 3.1, -1.35), FUR_DARK))
	weld(head, part("EarTip", Vector3.new(0.14, 0.3, 0.14), Vector3.new(x * 0.3, 3.5, -1.35), SPIKE))
	weld(head, part("Eye", Vector3.new(0.2, 0.18, 0.1), Vector3.new(x * 0.28, 2.58, -2.0), EYE, Enum.Material.Neon))
end
local jaw = part("Jaw", Vector3.new(0.5, 0.15, 0.7), Vector3.new(0, 2.08, -2.15), FUR_DARK)
motor("Jaw", head, jaw, Vector3.new(0, 2.15, -1.8))
weld(jaw, part("Maw", Vector3.new(0.4, 0.06, 0.55), Vector3.new(0, 2.17, -2.15), EMBER, Enum.Material.Neon))
for _, x in ipairs({ -0.17, 0.17 }) do
	weld(jaw, part("Fang", Vector3.new(0.07, 0.2, 0.07), Vector3.new(x, 2.22, -2.45), TEETH))
end

-- ── Legs ───────────────────────────────────────────────────────
-- hind legs: pelvis -> upper (Hip) -> lower (Knee); front legs: torso -> upper (Shoulder) -> lower (Elbow)
local function leg(side, x, z, parent, hipName, kneeName, tag)
	local upper = part(tag .. side .. "Upper", Vector3.new(0.38, 0.75, 0.42), Vector3.new(x, 1.025, z), FUR)
	motor(side .. hipName, parent, upper, Vector3.new(x, 1.4, z))
	local lower = part(tag .. side .. "Lower", Vector3.new(0.3, 0.7, 0.34), Vector3.new(x, 0.4, z), FUR_DARK)
	motor(side .. kneeName, upper, lower, Vector3.new(x, 0.65, z))
	weld(lower, part(tag .. side .. "Paw", Vector3.new(0.4, 0.16, 0.6), Vector3.new(x, 0.08, z - 0.12), FUR))
	for _, dx in ipairs({ -0.1, 0.1 }) do
		weld(lower, part(tag .. side .. "Claw", Vector3.new(0.06, 0.08, 0.14), Vector3.new(x + dx, 0.06, z - 0.46), CLAW))
	end
end
leg("L", -0.4, 0.85, pelvis, "Hip", "Knee", "Hind")
leg("R", 0.4, 0.85, pelvis, "Hip", "Knee", "Hind")
leg("L", -0.4, -0.95, torso, "Shoulder", "Elbow", "Fore")
leg("R", 0.4, -0.95, torso, "Shoulder", "Elbow", "Fore")

-- faint ember glow from the eyes and maw (no shadows, see CLAUDE.md)
local light = Instance.new("PointLight")
light.Name = "HoundLight"
light.Color = Color3.fromRGB(255, 90, 60)
light.Brightness = 0.7
light.Range = 8
light.Shadows = false
light.Parent = head

model:SetAttribute("Rig", "Procedural")
model:SetAttribute("RootHeight", 1.8)
model:SetAttribute("Height", 3.6)
model.Parent = models

local count = 0
for _, d in ipairs(model:GetDescendants()) do
	if d:IsA("Motor6D") then count += 1 end
end
return "ShadowHound built: " .. #model:GetChildren() .. " parts, " .. count .. " joints"
