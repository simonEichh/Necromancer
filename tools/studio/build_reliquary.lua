-- The Reliquary (docs/world.md, the plaza): a showcase pedestal near the Soul Well, facing the spawn. Safe to re-run.
-- Run in Edit mode (Studio MCP execute_luau or loadstring from the tools/studio http server); save the place after.
-- Builds only the pedestal (HubDecor.Reliquary); the client module ReliquaryShowcase puts a big turning copy of a chase
-- unit on it (the Sovereigns and Signatures in turn) and writes its name and real odds on the plate.
--   ShowcaseAnchor  invisible part on top: the unit stands on its top face, facing the anchor's LookVector
--   Plate           the slanted plate on the front; the client puts a SurfaceGui on its front face
local hub = workspace:FindFirstChild("HubDecor")
assert(hub, "HubDecor missing")

local FLOOR_TOP = -1.7
local POS = Vector3.new(13, FLOOR_TOP, 9) -- (front right of the spawn, looking at the well)
local spawn = workspace:GetAttribute("HubSpawn") or Vector3.new(0, 1.3, 18)
local facing = CFrame.lookAt(POS, Vector3.new(spawn.X, POS.Y, spawn.Z)) -- (its front looks at the spawn)

local OBSIDIAN = Color3.fromRGB(34, 30, 40)
local OBSIDIAN_LIGHT = Color3.fromRGB(52, 46, 60)
local BONE = Color3.fromRGB(120, 110, 96)
local SOUL = Color3.fromRGB(150, 110, 240)
local FLAME = Color3.fromRGB(170, 255, 200)
local IRON = Color3.fromRGB(32, 30, 34)

local old = hub:FindFirstChild("Reliquary")
if old then
	old:Destroy()
end
local m = Instance.new("Model")
m.Name = "Reliquary"

local function part(name, size, cf, color, material, shape)
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
	p.Material = material or Enum.Material.Slate
	if shape then
		p.Shape = shape
	end
	p.Parent = m
	return p
end
local function disc(name, diameter, height, y, color, material)
	return part(name, Vector3.new(height, diameter, diameter), facing * CFrame.new(0, y + height / 2, 0) * CFrame.Angles(0, 0, math.pi / 2), color, material, Enum.PartType.Cylinder)
end

-- two round steps, a square plinth with bone corner strips, a bone rim on top
disc("Step1", 9, 0.5, 0, OBSIDIAN_LIGHT).CanCollide = true
disc("Step2", 7.4, 0.5, 0.5, OBSIDIAN).CanCollide = true
local PLINTH_H = 3.2
part("Plinth", Vector3.new(4.6, PLINTH_H, 4.6), facing * CFrame.new(0, 1 + PLINTH_H / 2, 0), OBSIDIAN, Enum.Material.Basalt).CanCollide = true
for _, c in ipairs({ { -1, -1 }, { -1, 1 }, { 1, -1 }, { 1, 1 } }) do
	part("PlinthCorner", Vector3.new(0.6, PLINTH_H, 0.6), facing * CFrame.new(c[1] * 2.3, 1 + PLINTH_H / 2, c[2] * 2.3) * CFrame.Angles(0, math.rad(45), 0), BONE, Enum.Material.Limestone)
end
local TOP = 1 + PLINTH_H
disc("Rim", 6.9, 0.4, TOP, BONE, Enum.Material.Limestone)
disc("Top", 6.2, 0.12, TOP + 0.4, OBSIDIAN, Enum.Material.Basalt)
-- a soul ring inlaid in the top, where the unit stands
local ring = disc("SoulRing", 5.2, 0.06, TOP + 0.5, SOUL, Enum.Material.Neon)
ring.Transparency = 0.2
disc("SoulRingInner", 4.8, 0.08, TOP + 0.5, OBSIDIAN, Enum.Material.Basalt)

-- the anchor the client stands the unit on
local anchor = part("ShowcaseAnchor", Vector3.new(1, 0.2, 1), facing * CFrame.new(0, TOP + 0.62, 0), SOUL)
anchor.Transparency = 1

-- the plate: slanted on the front of the plinth, bone frame round a dark face
local plateCF = facing * CFrame.new(0, 1 + PLINTH_H * 0.55, -2.75) * CFrame.Angles(math.rad(18), 0, 0) -- (its top leans back)
part("PlateFrame", Vector3.new(4.4, 2.3, 0.3), plateCF * CFrame.new(0, 0, 0.12), BONE, Enum.Material.Limestone)
local plate = part("Plate", Vector3.new(4, 1.95, 0.2), plateCF, Color3.fromRGB(18, 16, 22), Enum.Material.Basalt)

-- four candle posts round the steps
for k = 0, 3 do
	local a = math.pi / 4 + k * math.pi / 2
	local base = facing * CFrame.new(math.cos(a) * 4, 0.5, math.sin(a) * 4)
	part("CandlePost", Vector3.new(0.5, 2.4, 0.5), base * CFrame.new(0, 1.2, 0), IRON, Enum.Material.Metal)
	part("CandleDish", Vector3.new(0.9, 0.12, 0.9), base * CFrame.new(0, 2.45, 0), IRON, Enum.Material.Metal)
	part("Candle", Vector3.new(0.3, 0.6, 0.3), base * CFrame.new(0, 2.8, 0), Color3.fromRGB(168, 156, 134), Enum.Material.SmoothPlastic)
	local flame = part("CandleFlame", Vector3.new(0.18, 0.3, 0.18), base * CFrame.new(0, 3.25, 0), FLAME, Enum.Material.Neon, Enum.PartType.Ball)
	if k % 2 == 0 then
		local l = Instance.new("PointLight")
		l.Color = FLAME
		l.Range = 8
		l.Brightness = 0.7
		l.Shadows = false
		l.Parent = flame
	end
end
-- an upward light on the unit
local up = Instance.new("SpotLight")
up.Color = Color3.fromRGB(190, 170, 255)
up.Angle = 50
up.Range = 26
up.Brightness = 2
up.Face = Enum.NormalId.Top
up.Shadows = false
up.Parent = ring

m.PrimaryPart = anchor
m.ModelStreamingMode = Enum.ModelStreamingMode.Persistent -- (the client needs the anchor and the plate)
m.Parent = hub
return "reliquary done"
