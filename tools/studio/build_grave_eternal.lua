-- Builds the Eternal Throne (grave tier 9) into ReplicatedStorage.GraveModels.Eternal, from the concept art
-- Images/Graves/Eternal Throne.png: a throne of white marble and gold on a dais with front steps: a gold-lidded sarcophagus
-- as the seat, a tall spired throne back set with gold gems, a glowing golden halo behind it, armrest walls, front pillars
-- with gold pyramid caps and candles.
-- Run in Edit mode via the Studio MCP execute_luau (or loadstring over a local http.server, see CLAUDE.md). Safe to re-run.
--
-- Grave model conventions: see build_grave_mossy.lua (Body / Lid / Pit / Core, "Glow" parts, OpenStyle).
-- OpenStyle "Levitate" (Modules/GraveOpening): the golden lid lifts up slowly (LiftHeight) and keeps hovering and turning;
-- the risen unit then glides out over the front of the seat and down the steps (HopOut / FloorHeight / WallTop / HopTime).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local folder = ReplicatedStorage:FindFirstChild("GraveModels")
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "GraveModels"
	folder.Parent = ReplicatedStorage
end
local old = folder:FindFirstChild("Eternal")
if old then
	old:Destroy()
end

local MARBLE = Color3.fromRGB(226, 223, 230)
local MARBLE_DARK = Color3.fromRGB(196, 192, 204)
local GOLD = Color3.fromRGB(184, 146, 76)
local GOLD_DARK = Color3.fromRGB(140, 108, 54)
local WAX = Color3.fromRGB(236, 230, 214)
local FLAME = Color3.fromRGB(255, 170, 60)
local GROUND = Color3.fromRGB(60, 54, 50)
local INSIDE = Color3.fromRGB(30, 22, 10)
local GLOW = Color3.fromRGB(255, 176, 40) -- holy gold

local model = Instance.new("Model")
model.Name = "Eternal"
local body = Instance.new("Model")
body.Name = "Body"
body.Parent = model
local lid = Instance.new("Model")
lid.Name = "Lid"
lid.Parent = model
local pit = Instance.new("Model")
pit.Name = "Pit"
pit.Parent = model

local function part(parent, name, size, cf, color, material, shape)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CastShadow = false
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.Marble
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if shape then
		p.Shape = shape
	end
	p.Parent = parent
	return p
end
local function gold(parent, name, size, cf)
	return part(parent, name, size, cf, GOLD, Enum.Material.Metal)
end
local UPRIGHT = CFrame.Angles(0, 0, math.rad(90))
-- a spike: a cube standing on one corner, the top half pointing up
local SPIKE_ROT = CFrame.fromAxisAngle(Vector3.new(1, 1, 1).Unit:Cross(Vector3.yAxis).Unit, math.acos(1 / math.sqrt(3)))
local function spike(parent, pos, size)
	gold(parent, "Spike", Vector3.new(size, size, size), CFrame.new(pos) * SPIKE_ROT)
end
-- a frame lying in a face with outward normal `normal` (X = along the face, Y = up, Z = into the stone)
local function faceFrame(pos, normal)
	return CFrame.fromMatrix(pos, normal:Cross(Vector3.yAxis), Vector3.yAxis)
end
-- a gold gem on a face: a gold diamond frame (taller than wide) with a glowing diamond inside
local function gem(parent, cf, size)
	local d = cf * CFrame.Angles(0, 0, math.rad(45))
	gold(parent, "GemFrame", Vector3.new(size, size, 0.1), cf * CFrame.new(0, 0, -0.03) * CFrame.Angles(0, 0, math.rad(45)))
	part(parent, "Glow", Vector3.new(size * 0.55, size * 0.55, 0.06), d * CFrame.new(0, 0, -0.08), GLOW, Enum.Material.Neon)
end
-- a gold strip from a to b (2D points in the face frame `cf`)
local function strip(parent, cf, a, b, width)
	local mid = (a + b) / 2
	local d = b - a
	return gold(parent, "Trim", Vector3.new(d.Magnitude + width, width, 0.08), cf * CFrame.new(mid.X, mid.Y, -0.04) * CFrame.Angles(0, 0, math.atan2(d.Y, d.X)))
end
-- a block whose length runs along the 2D (x, y) direction `d` in the front plane, centred at (x, y, z)
local function slopeBlock(parent, name, len, thick, depth, x, y, z, d, color, material)
	local along = Vector3.new(d.X, d.Y, 0).Unit
	local upv = Vector3.new(-along.Y, along.X, 0)
	if upv.Y < 0 then
		upv = -upv
	end
	return part(parent, name, Vector3.new(len, thick, depth), CFrame.fromMatrix(Vector3.new(x, y, z), along, upv), color, material)
end

local DAIS = 1.0 -- top of the dais
local FLOOR = DAIS + 0.1 -- the floor inside the sarcophagus
local SX, SZ0, SZ1 = 1.6, -1.6, 1.0 -- the sarcophagus: x +-SX, z from SZ0 (front) to SZ1
local SEAT_TOP = 2.3

-- ============================================================
-- Ground patch (PrimaryPart), the dais with gold trim and front steps
-- ============================================================
local base = part(body, "Base", Vector3.new(0.2, 10, 10), CFrame.new(0, 0.1, 0) * UPRIGHT, GROUND, Enum.Material.Ground, Enum.PartType.Cylinder)
model.PrimaryPart = base
base.PivotOffset = base.CFrame:Inverse() -- pivot on the floor centre, upright
part(body, "Dais", Vector3.new(7.0, DAIS - 0.2, 6.0), CFrame.new(0, (DAIS + 0.2) / 2, 0.2), MARBLE)
gold(body, "DaisTrim", Vector3.new(7.1, 0.12, 6.1), CFrame.new(0, DAIS - 0.06, 0.2))
for i, st in ipairs({ { 0.47, -3.9 }, { 0.73, -3.6 } }) do
	local y0 = (i == 1) and 0.2 or 0.47
	local depth = -2.8 - st[2]
	part(body, "Step", Vector3.new(3.8, st[1] - y0, depth), CFrame.new(0, (st[1] + y0) / 2, st[2] + depth / 2), (i == 1) and MARBLE_DARK or MARBLE)
	gold(body, "StepTrim", Vector3.new(3.85, 0.06, 0.06), CFrame.new(0, st[1] - 0.03, st[2] - 0.02))
end
gem(body, faceFrame(Vector3.new(0, 0.6, -3.62), Vector3.new(0, 0, -1)), 0.42)

-- ============================================================
-- The seat: a marble sarcophagus in a gold frame, the dark inside (Pit)
-- ============================================================
local WT = 0.3
local SEAT_H = SEAT_TOP - DAIS
local SEAT_YC = DAIS + SEAT_H / 2
local SZC, SD = (SZ0 + SZ1) / 2, SZ1 - SZ0
for _, s in ipairs({ -1, 1 }) do
	part(body, "Seat", Vector3.new(WT, SEAT_H, SD), CFrame.new(s * (SX - WT / 2), SEAT_YC, SZC), MARBLE)
	gold(body, "SeatTrim", Vector3.new(0.14, SEAT_H, 0.14), CFrame.new(s * SX, SEAT_YC, SZ0))
end
part(body, "Seat", Vector3.new(2 * SX - 2 * WT, SEAT_H, WT), CFrame.new(0, SEAT_YC, SZ0 + WT / 2), MARBLE)
part(body, "Seat", Vector3.new(2 * SX - 2 * WT, SEAT_H, WT), CFrame.new(0, SEAT_YC, SZ1 - WT / 2), MARBLE)
gold(body, "SeatTrim", Vector3.new(2 * SX + 0.1, 0.16, 0.12), CFrame.new(0, SEAT_TOP - 0.08, SZ0 - 0.02))
gold(body, "SeatTrim", Vector3.new(2 * SX + 0.1, 0.16, 0.12), CFrame.new(0, DAIS + 0.08, SZ0 - 0.02))
-- the front panel: a gold chevron frame over two marble panes
local fcf = faceFrame(Vector3.new(0, DAIS, SZ0 - 0.01), Vector3.new(0, 0, -1))
strip(body, fcf, Vector2.new(-1.3, 0.35), Vector2.new(1.3, 0.35), 0.1)
strip(body, fcf, Vector2.new(-1.3, 0.35), Vector2.new(-1.3, 1.0), 0.1)
strip(body, fcf, Vector2.new(1.3, 0.35), Vector2.new(1.3, 1.0), 0.1)
strip(body, fcf, Vector2.new(-1.3, 1.0), Vector2.new(0, 0.62), 0.1)
strip(body, fcf, Vector2.new(1.3, 1.0), Vector2.new(0, 0.62), 0.1)
-- the light seam under the lid
part(body, "Glow", Vector3.new(2 * SX - 0.2, 0.06, 0.06), CFrame.new(0, SEAT_TOP + 0.03, SZ0 - 0.04), GLOW, Enum.Material.Neon)
for _, s in ipairs({ -1, 1 }) do
	part(body, "Glow", Vector3.new(0.06, 0.06, SD - 0.2), CFrame.new(s * (SX + 0.04), SEAT_TOP + 0.03, SZC), GLOW, Enum.Material.Neon)
end
part(pit, "PitFloor", Vector3.new(2 * SX - 2 * WT, 0.05, SD - 2 * WT), CFrame.new(0, FLOOR, SZC), INSIDE, Enum.Material.SmoothPlastic)
for _, c in ipairs({ { -0.6, -0.5, 1.0, 30 }, { 0.5, 0.0, 0.9, -40 } }) do
	part(pit, "Glow", Vector3.new(c[3], 0.03, 0.07), CFrame.new(c[1], FLOOR + 0.04, c[2]) * CFrame.Angles(0, math.rad(c[4]), 0), GLOW, Enum.Material.Neon)
end
local core = part(model, "Core", Vector3.new(0.4, 0.4, 0.4), CFrame.new(0, FLOOR + 0.4, SZC), GLOW, Enum.Material.Neon)
core.Transparency = 1

-- ============================================================
-- The throne back: a tall marble slab with a pointed top, gold gothic frames and gems, side spires
-- ============================================================
local BZ = 1.7 -- the back's centre (z)
local BD = 0.8
part(body, "Back", Vector3.new(3.4, 3.6, BD), CFrame.new(0, DAIS + 1.8, BZ), MARBLE)
for _, s in ipairs({ -1, 1 }) do
	local a, b = Vector2.new(s * 1.7, 4.6), Vector2.new(0, 6.3)
	local d = (b - a).Unit
	local n = Vector2.new(-d.Y, d.X)
	if n.Y < 0 then n = -n end
	local mid = (a + b) / 2 - n * 0.6
	slopeBlock(body, "Back", (b - a).Magnitude, 1.2, BD, mid.X, mid.Y, BZ, d, MARBLE)
	local gm = (a + b) / 2 + n * 0.05
	slopeBlock(body, "Trim", (b - a).Magnitude + 0.1, 0.14, BD + 0.08, gm.X, gm.Y, BZ, d, GOLD, Enum.Material.Metal)
	-- the side spires on the back
	gold(body, "SpireBase", Vector3.new(0.55, 0.3, 0.6), CFrame.new(s * 1.25, 4.95, BZ - 0.1))
	part(body, "Spire", Vector3.new(0.4, 0.5, 0.45), CFrame.new(s * 1.25, 5.35, BZ - 0.1), MARBLE)
	spike(body, Vector3.new(s * 1.25, 5.65, BZ - 0.1), 0.45)
end
spike(body, Vector3.new(0, 6.35, BZ), 0.55)
-- gold gothic frames and gems on the front of the back
local bcf = faceFrame(Vector3.new(0, 0, BZ - BD / 2 - 0.01), Vector3.new(0, 0, -1))
for _, s in ipairs({ -1, 1 }) do
	strip(body, bcf, Vector2.new(s * 1.45, 2.4), Vector2.new(s * 1.45, 4.4), 0.1)
	strip(body, bcf, Vector2.new(s * 0.95, 2.4), Vector2.new(s * 0.95, 4.2), 0.1)
	strip(body, bcf, Vector2.new(s * 0.95, 4.2), Vector2.new(0, 5.5), 0.1)
end
gem(body, bcf * CFrame.new(0, 4.55, 0), 0.9)
gem(body, bcf * CFrame.new(0, 3.3, 0), 0.5)

-- ============================================================
-- Armrest walls, back pillars, front pillars with gold caps and gems
-- ============================================================
for _, s in ipairs({ -1, 1 }) do
	-- the armrest wall along each side
	part(body, "Arm", Vector3.new(0.6, 1.4, 3.4), CFrame.new(s * 2.55, DAIS + 0.7, -0.4), MARBLE)
	gold(body, "ArmCap", Vector3.new(0.7, 0.14, 3.5), CFrame.new(s * 2.55, DAIS + 1.47, -0.4))
	gem(body, faceFrame(Vector3.new(s * 2.86, DAIS + 0.7, -0.4), Vector3.new(s, 0, 0)), 0.55)
	-- back pillars beside the throne back
	part(body, "Pillar", Vector3.new(0.9, 3.6, 0.9), CFrame.new(s * 2.4, DAIS + 1.8, BZ), MARBLE)
	gold(body, "PillarCap", Vector3.new(1.1, 0.3, 1.1), CFrame.new(s * 2.4, DAIS + 3.75, BZ))
	spike(body, Vector3.new(s * 2.4, DAIS + 4.15, BZ), 0.75)
	gem(body, faceFrame(Vector3.new(s * 2.4, DAIS + 2.6, BZ - 0.46), Vector3.new(0, 0, -1)), 0.4)
	-- front pillars on gold feet
	local fx, fz = s * 2.75, -2.4
	gold(body, "PillarFoot", Vector3.new(1.4, 0.8, 1.4), CFrame.new(fx, 0.6, fz))
	part(body, "Pillar", Vector3.new(0.9, 2.0, 0.9), CFrame.new(fx, DAIS + 1.0, fz), MARBLE)
	gold(body, "PillarCap", Vector3.new(1.1, 0.3, 1.1), CFrame.new(fx, DAIS + 2.15, fz))
	spike(body, Vector3.new(fx, DAIS + 2.55, fz), 0.8)
	for _, y in ipairs({ DAIS + 0.55, DAIS + 1.35 }) do
		gem(body, faceFrame(Vector3.new(fx, y, fz - 0.46), Vector3.new(0, 0, -1)), 0.42)
	end
end

-- ============================================================
-- Candles: on gold holders at the front corners and on the armrests
-- ============================================================
local function candle(pos, h)
	gold(body, "CandleHolder", Vector3.new(0.12, 0.6, 0.6), CFrame.new(pos + Vector3.new(0, 0.06, 0)) * UPRIGHT).Shape = Enum.PartType.Cylinder
	part(body, "Candle", Vector3.new(h, 0.32, 0.32), CFrame.new(pos + Vector3.new(0, 0.12 + h / 2, 0)) * UPRIGHT, WAX, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	local flame = part(body, "Flame", Vector3.new(0.16, 0.16, 0.16), CFrame.new(pos + Vector3.new(0, 0.22 + h, 0)), FLAME, Enum.Material.Neon, Enum.PartType.Ball)
	local light = Instance.new("PointLight")
	light.Color = FLAME
	light.Range = 6
	light.Brightness = 0.8
	light.Shadows = false
	light.Parent = flame
end
for _, s in ipairs({ -1, 1 }) do
	candle(Vector3.new(s * 3.65, 0.2, -3.3), 0.5)
	candle(Vector3.new(s * 2.55, DAIS + 1.54, 0.9), 0.4)
end

-- ============================================================
-- The golden halo behind the throne back (Glow arcs), motes of light
-- ============================================================
local HC = Vector3.new(0, 4.5, BZ + 0.6)
for ring, r in ipairs({ 3.1, 3.5 }) do
	local count = 22
	for i = 0, count - 1 do
		local a0 = math.rad(-15 + i * (210 / count))
		local a1 = math.rad(-15 + (i + 1) * (210 / count))
		local p0 = HC + Vector3.new(math.cos(a0) * r, math.sin(a0) * r, 0)
		local p1 = HC + Vector3.new(math.cos(a1) * r, math.sin(a1) * r, 0)
		local w = (ring == 1) and 0.16 or 0.08
		part(body, "Glow", Vector3.new((p1 - p0).Magnitude + w * 0.5, w, w), CFrame.lookAt((p0 + p1) / 2, p1) * CFrame.Angles(0, math.rad(90), 0), GLOW, Enum.Material.Neon)
	end
end
spike(body, HC + Vector3.new(0, 3.6, 0), 0.5)
local src = part(body, "Motes", Vector3.new(6, 0.2, 2), CFrame.new(0, 3.8, BZ + 0.6), GLOW, Enum.Material.SmoothPlastic)
src.Transparency = 1
local motes = Instance.new("ParticleEmitter")
motes.Texture = "rbxasset://textures/particles/sparkles_main.dds"
motes.Color = ColorSequence.new(Color3.fromRGB(255, 220, 140))
motes.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 0) })
motes.Lifetime = NumberRange.new(2, 3)
motes.Speed = NumberRange.new(0.4, 1.0)
motes.SpreadAngle = Vector2.new(40, 40)
motes.LightEmission = 1
motes.Rate = 5
motes.Parent = src

-- ============================================================
-- The golden lid (Lid): a heavy gold slab with a bevelled top and a great gem; lifts up and hovers
-- ============================================================
local LID_Y0 = SEAT_TOP + 0.06
gold(lid, "LidSlab", Vector3.new(2 * SX + 0.3, 0.35, SD + 0.3), CFrame.new(0, LID_Y0 + 0.175, SZC))
gold(lid, "LidTop", Vector3.new(2 * SX - 0.2, 0.25, SD - 0.2), CFrame.new(0, LID_Y0 + 0.47, SZC))
part(lid, "LidEdge", Vector3.new(2 * SX + 0.34, 0.06, SD + 0.34), CFrame.new(0, LID_Y0 + 0.36, SZC), GOLD_DARK, Enum.Material.Metal)
local top = CFrame.new(0, LID_Y0 + 0.62, SZC) * CFrame.Angles(math.rad(90), 0, 0)
gold(lid, "LidGemFrame", Vector3.new(0.9, 0.9, 0.16), top * CFrame.Angles(0, 0, math.rad(45)))
part(lid, "Glow", Vector3.new(0.5, 0.5, 0.12), top * CFrame.new(0, 0, -0.06) * CFrame.Angles(0, 0, math.rad(45)), GLOW, Enum.Material.Neon)
-- a ridge running along the lid's top
gold(lid, "LidRidge", Vector3.new(2 * SX - 0.6, 0.12, 0.18), CFrame.new(0, LID_Y0 + 0.65, SZC))

-- ============================================================
-- Attributes and placement
-- ============================================================
model:SetAttribute("OpenStyle", "Levitate")
model:SetAttribute("GlowColor", GLOW)
model:SetAttribute("DebrisColor", GOLD)
model:SetAttribute("Height", 8.0)
model:SetAttribute("LiftHeight", 3.6)
-- the risen unit glides out over the front of the seat and down the steps (Modules/GraveCinematic)
model:SetAttribute("HopOut", 4.6)
model:SetAttribute("FloorHeight", FLOOR)
model:SetAttribute("WallTop", SEAT_TOP)
model:SetAttribute("HopTime", 1.15)
model.Parent = folder

-- a preview next to the other graves' (behind the hub spawn); delete Workspace.GravePreview before publishing
local preview = workspace:FindFirstChild("GravePreview")
if not preview then
	preview = Instance.new("Folder")
	preview.Name = "GravePreview"
	preview.Parent = workspace
end
local oldCopy = preview:FindFirstChild("Eternal")
if oldCopy then
	oldCopy:Destroy()
end
local copy = model:Clone()
copy:PivotTo(CFrame.new(-42, -1.7, 40))
copy.Parent = preview

local count = 0
for _, d in ipairs(model:GetDescendants()) do
	if d:IsA("BasePart") then count += 1 end
end
return "Eternal throne built: " .. count .. " parts"
