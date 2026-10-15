-- The plaza, batch 4 of "The Ossuary Court" (docs/world.md): the atmosphere. Safe to re-run.
-- Run in Edit mode (Studio MCP execute_luau or loadstring from the tools/studio http server) AFTER build_plaza_rim.lua
-- (the crows sit on its rail); save the place after. Everything goes into HubDecor.PlazaAtmosphere:
--   * low ground fog drifting over the plaza (ParticleEmitters in flat invisible boxes)
--   * floating candles: two rings circling the Soul Well in opposite directions (models tagged SpinFx: WorldFx turns
--     them round the well)
--   * dead trees with lanterns hanging from their branches, in the free spots between the stalls (every spot is
--     checked against the stalls' and the wheel's bounds and skipped if it is too close)
--   * crows perched on the balustrade rail
local CollectionService = game:GetService("CollectionService")
local hub = workspace:FindFirstChild("HubDecor")
assert(hub, "HubDecor missing")

local FLOOR_TOP = -1.7
local WOOD = Color3.fromRGB(38, 32, 30)
local WOOD_LIGHT = Color3.fromRGB(56, 48, 44)
local IRON = Color3.fromRGB(32, 30, 34)
local FLAME = Color3.fromRGB(170, 255, 200)
local WAX = Color3.fromRGB(168, 156, 134)
local CROW = Color3.fromRGB(16, 15, 20)

local old = hub:FindFirstChild("PlazaAtmosphere")
if old then
	old:Destroy()
end
local root = Instance.new("Model")
root.Name = "PlazaAtmosphere"

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
	if shape then
		p.Shape = shape
	end
	p.Parent = parent
	return p
end
local function bar(parent, name, a, b, w, color, material)
	return part(parent, name, Vector3.new(w, w, (b - a).Magnitude + w * 0.4), CFrame.lookAt((a + b) / 2, b), color, material)
end
local rng = Random.new(1915)

-- ── fog ─────────────────────────────────────────────────
local fog = Instance.new("Folder")
fog.Name = "Fog"
fog.Parent = root
for k = 0, 7 do
	local a = k / 8 * math.pi * 2 + math.pi / 8
	local pos = Vector3.new(math.cos(a) * 34, FLOOR_TOP + 0.6, math.sin(a) * 34)
	local box = part(fog, "FogBox", Vector3.new(26, 0.5, 26), CFrame.new(pos), Color3.new(1, 1, 1))
	box.Transparency = 1
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	e.Shape = Enum.ParticleEmitterShape.Box
	e.Color = ColorSequence.new(Color3.fromRGB(120, 112, 140), Color3.fromRGB(80, 74, 100))
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 6), NumberSequenceKeypoint.new(1, 12) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.86), NumberSequenceKeypoint.new(0.7, 0.88), NumberSequenceKeypoint.new(1, 1) })
	e.Lifetime = NumberRange.new(8, 12)
	e.Speed = NumberRange.new(0.3, 0.9)
	e.SpreadAngle = Vector2.new(180, 5)
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-6, 6)
	e.Rate = 1.2
	e.LightInfluence = 0.8
	e.EmissionDirection = Enum.NormalId.Top
	e.Acceleration = Vector3.new(0, -0.05, 0)
	e.Parent = box
end

-- ── floating candles round the well ─────────────────────
local function candleRing(name, radius, height, count, speed, lights)
	local m = Instance.new("Model")
	m.Name = name
	local hubPart = part(m, "Hub", Vector3.new(0.3, 0.3, 0.3), CFrame.new(0, FLOOR_TOP + height, 0), FLAME)
	hubPart.Transparency = 1
	m.PrimaryPart = hubPart
	for k = 0, count - 1 do
		local a = k / count * math.pi * 2 + rng:NextNumber(-0.12, 0.12)
		local h = FLOOR_TOP + height + rng:NextNumber(-0.6, 0.6)
		local len = rng:NextNumber(0.4, 0.75)
		local pos = Vector3.new(math.cos(a) * radius, h, math.sin(a) * radius)
		part(m, "Candle", Vector3.new(0.24, len, 0.24), CFrame.new(pos) * CFrame.Angles(rng:NextNumber(-0.08, 0.08), 0, rng:NextNumber(-0.08, 0.08)), WAX)
		local flame = part(m, "CandleFlame", Vector3.new(0.18, 0.32, 0.18), CFrame.new(pos + Vector3.new(0, len / 2 + 0.18, 0)), FLAME, Enum.Material.Neon, Enum.PartType.Ball)
		if k % lights == 0 then
			local l = Instance.new("PointLight")
			l.Color = FLAME
			l.Range = 6
			l.Brightness = 0.5
			l.Shadows = false
			l.Parent = flame
		end
	end
	m:SetAttribute("SpinSpeed", speed)
	m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	m.Parent = root
	CollectionService:AddTag(m, "SpinFx")
end
candleRing("CandlesLow", 10.5, 6.5, 14, 0.08, 4)
candleRing("CandlesHigh", 12.5, 9.5, 10, -0.06, 5)

-- ── dead trees ──────────────────────────────────────────
-- where the stalls and the wheel are (their bounding boxes, a little bigger): no tree there
local blocked = {}
local function block(model)
	local cf, size = model:GetBoundingBox()
	table.insert(blocked, { cf = cf, half = size / 2 + Vector3.new(8, 0, 8) })
end
for _, c in ipairs(hub:GetChildren()) do
	if c:IsA("Model") and c.Name:match("^Stall_") then
		block(c)
	end
end
local wheel = workspace:FindFirstChild("LuckyWheel")
if wheel then
	block(wheel)
end
local plotAngles = {}
for _, plot in ipairs(workspace.Plots:GetChildren()) do
	local base = plot:FindFirstChild("Base")
	if base then
		table.insert(plotAngles, math.atan2(base.Position.Z, base.Position.X))
	end
end
local function free(pos)
	for _, b in ipairs(blocked) do
		local p = b.cf:PointToObjectSpace(pos)
		if math.abs(p.X) < b.half.X and math.abs(p.Z) < b.half.Z then
			return false
		end
	end
	-- (not on a plot's ray / path: at least 9 studs to the side of it)
	for _, a in ipairs(plotAngles) do
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local along = Vector3.new(pos.X, 0, pos.Z):Dot(dir)
		local side = (Vector3.new(pos.X, 0, pos.Z) - dir * along).Magnitude
		if along > 0 and side < 9 then
			return false
		end
	end
	return true
end

local function hangingLantern(parent, at, drop)
	bar(parent, "Chain", at, at - Vector3.new(0, drop, 0), 0.08, IRON, Enum.Material.Metal)
	local top = at - Vector3.new(0, drop, 0)
	part(parent, "LanternCap", Vector3.new(0.7, 0.25, 0.7), CFrame.new(top - Vector3.new(0, 0.12, 0)) * CFrame.Angles(0, math.rad(45), 0), IRON, Enum.Material.Metal)
	for _, c in ipairs({ { -1, -1 }, { -1, 1 }, { 1, -1 }, { 1, 1 } }) do
		part(parent, "LanternPost", Vector3.new(0.07, 0.8, 0.07), CFrame.new(top + Vector3.new(c[1] * 0.26, -0.65, c[2] * 0.26)), IRON, Enum.Material.Metal)
	end
	part(parent, "LanternBase", Vector3.new(0.65, 0.1, 0.65), CFrame.new(top - Vector3.new(0, 1.1, 0)), IRON, Enum.Material.Metal)
	local flame = part(parent, "LanternFlame", Vector3.new(0.3, 0.45, 0.3), CFrame.new(top - Vector3.new(0, 0.7, 0)), FLAME, Enum.Material.Neon)
	local l = Instance.new("PointLight")
	l.Color = FLAME
	l.Range = 10
	l.Brightness = 0.8
	l.Shadows = false
	l.Parent = flame
end

-- a gnarled dead tree: a leaning trunk in segments, branches forking off it, twigs; lanterns on two branch ends
local function tree(base, seed)
	local r = Random.new(seed)
	local m = Instance.new("Model")
	m.Name = "DeadTree"
	local lean = Vector3.new(r:NextNumber(-0.25, 0.25), 1, r:NextNumber(-0.25, 0.25)).Unit
	local pts = { base }
	local p = base
	local height = r:NextNumber(11, 14)
	for k = 1, 5 do
		local wobble = Vector3.new(r:NextNumber(-0.6, 0.6), 0, r:NextNumber(-0.6, 0.6))
		p = p + lean * (height / 5) + wobble
		table.insert(pts, p)
	end
	for k = 1, 5 do
		bar(m, "Trunk", pts[k], pts[k + 1], 1.5 - k * 0.2, k % 2 == 0 and WOOD_LIGHT or WOOD, Enum.Material.Wood)
	end
	-- roots
	for k = 0, 3 do
		local a = k / 4 * math.pi * 2 + r:NextNumber(-0.4, 0.4)
		local out = Vector3.new(math.cos(a), 0, math.sin(a))
		bar(m, "Root", base + Vector3.new(0, 0.6, 0), base + out * r:NextNumber(1.8, 2.6) + Vector3.new(0, 0.1, 0), 0.55, WOOD, Enum.Material.Wood)
	end
	-- branches from the upper trunk, each with a twig or two; the first two carry a lantern
	local lanterns = 0
	for k = 0, 4 do
		local from = pts[3 + (k % 3)]
		local a = k / 5 * math.pi * 2 + r:NextNumber(-0.4, 0.4)
		local out = Vector3.new(math.cos(a), r:NextNumber(0.25, 0.7), math.sin(a)).Unit
		local len = r:NextNumber(3.5, 5.5)
		local tip = from + out * len
		bar(m, "Branch", from, tip, 0.5, WOOD, Enum.Material.Wood)
		for t = 1, 2 do
			local tw = Vector3.new(out.X + r:NextNumber(-0.7, 0.7), out.Y + r:NextNumber(0, 0.6), out.Z + r:NextNumber(-0.7, 0.7)).Unit
			local start = from:Lerp(tip, r:NextNumber(0.5, 0.9))
			bar(m, "Twig", start, start + tw * r:NextNumber(1.2, 2.2), 0.22, WOOD_LIGHT, Enum.Material.Wood)
		end
		if lanterns < 2 and out.Y < 0.6 then
			lanterns += 1
			hangingLantern(m, tip, r:NextNumber(1.5, 2.5))
		end
	end
	m.Parent = root
	return m
end

local trees = 0
-- (tried in this order so the trees spread round the plaza instead of filling one side)
for _, k in ipairs({ 1, 9, 5, 13, 3, 11, 7, 15 }) do
	if trees >= 4 then
		break
	end
	local a = k / 16 * math.pi * 2 -- (every other one lies halfway between two plot rays)
	local pos = Vector3.new(math.cos(a) * 45, FLOOR_TOP, math.sin(a) * 45)
	if free(pos) then
		tree(pos, 100 + k)
		trees += 1
		-- (keep the next spot at least two steps away)
		table.insert(blocked, { cf = CFrame.new(pos), half = Vector3.new(14, 50, 14) })
	end
end

-- ── crows on the balustrade rail ────────────────────────
local rails = {}
local rimModel = hub:FindFirstChild("PlazaRim")
for _, d in ipairs(rimModel and rimModel:GetChildren() or {}) do
	if d.Name == "RimRail" then
		table.insert(rails, d)
	end
end
local function crow(cf)
	local m = Instance.new("Model")
	m.Name = "Crow"
	part(m, "Body", Vector3.new(0.55, 0.5, 0.95), cf * CFrame.new(0, 0.38, 0) * CFrame.Angles(math.rad(-15), 0, 0), CROW)
	part(m, "Head", Vector3.new(0.42, 0.42, 0.42), cf * CFrame.new(0, 0.78, -0.42), CROW, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	part(m, "Beak", Vector3.new(0.1, 0.12, 0.4), cf * CFrame.new(0, 0.74, -0.75) * CFrame.Angles(math.rad(12), 0, 0), Color3.fromRGB(40, 36, 30))
	part(m, "Eye", Vector3.new(0.07, 0.07, 0.07), cf * CFrame.new(0.17, 0.84, -0.52), Color3.fromRGB(200, 40, 40), Enum.Material.Neon, Enum.PartType.Ball)
	part(m, "Eye", Vector3.new(0.07, 0.07, 0.07), cf * CFrame.new(-0.17, 0.84, -0.52), Color3.fromRGB(200, 40, 40), Enum.Material.Neon, Enum.PartType.Ball)
	part(m, "Tail", Vector3.new(0.35, 0.1, 0.7), cf * CFrame.new(0, 0.32, 0.72) * CFrame.Angles(math.rad(20), 0, 0), CROW)
	for _, s in ipairs({ -1, 1 }) do
		part(m, "Wing", Vector3.new(0.1, 0.4, 0.85), cf * CFrame.new(s * 0.3, 0.42, 0.05) * CFrame.Angles(math.rad(-12), 0, s * math.rad(8)), Color3.fromRGB(24, 22, 30))
		part(m, "Leg", Vector3.new(0.06, 0.2, 0.06), cf * CFrame.new(s * 0.12, 0.1, 0.05), Color3.fromRGB(40, 36, 30))
	end
	m.Parent = root
end
for k = 1, math.min(5, #rails) do
	local rail = rails[rng:NextInteger(1, #rails)]
	local top = rail.CFrame * CFrame.new(0, rail.Size.Y / 2, rng:NextNumber(-0.8, 0.8))
	-- (looking along the rail or over the plaza, slightly turned)
	crow(top * CFrame.Angles(0, (rng:NextNumber() < 0.5 and math.pi / 2 or -math.pi / 2) + rng:NextNumber(-0.6, 0.6), 0))
end

root.Parent = hub
local n = 0
for _, d in ipairs(root:GetDescendants()) do
	if d:IsA("BasePart") then
		n += 1
	end
end
return "plaza atmosphere done: " .. n .. " parts, " .. trees .. " trees, " .. math.min(5, #rails) .. " crows"
