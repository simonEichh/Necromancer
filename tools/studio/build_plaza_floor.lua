-- The plaza, batch 1 of "The Ossuary Court" (docs/world.md): the floor and the colour pass. Safe to re-run.
-- Run in Edit mode (Studio MCP execute_luau or loadstring from the tools/studio http server); save the place after.
--   * the floor: dark worn flagstone, the old blue inlay rings become dark stone bands with a bone trim
--   * a necromantic sigil inlaid in dim violet (HubDecor.PlazaSigil): an outer and an inner ring, an eight-pointed star,
--     rune marks, and 8 rays, each pointing down one plot's lane (aimed at the plot's real Base, never assumed) and
--     running out to its gate path. The rays are named SigilRay<plotIndex> (attribute PlotIndex) so a later batch can
--     light them up for owned plots.
--   * the colour pass: the turquoise beacon and the pale green-cyan rune circles / arch glow of the empty plots
--     (Plots.Plot<n>.Style: SpawnRing, SpawnRune, ArchGlow) become soul violet; the gate paths dark stone.
-- The stalls are not touched.
local hub = workspace:FindFirstChild("HubDecor")
local floor = workspace:FindFirstChild("HubFloor")
assert(hub and floor, "HubDecor / HubFloor missing")

local FLOOR_TOP = -1.7
local SIGIL_Y = FLOOR_TOP + 0.185 -- (the sigil sits on top of the inlay discs, whose tops are ~0.15 above the floor)
local SIGIL_H = 0.06
local INLAY_R = 27 -- (beyond the inlay discs the floor is lower: the rays drop onto it there)
local LOW_Y = FLOOR_TOP + 0.03

local STONE = Color3.fromRGB(66, 62, 70) -- (lighter than the lava sea's dark rock, or the plaza melts into it)
local STONE_DARK = Color3.fromRGB(48, 45, 52)
local STONE_MID = Color3.fromRGB(58, 54, 62)
local BONE = Color3.fromRGB(120, 110, 96)
local SIGIL = Color3.fromRGB(54, 38, 94) -- (a dark Neon: a faint glow, not a bright line; brighter ones blaze at ground level)
local SIGIL_RAY = Color3.fromRGB(66, 46, 114)
local SOUL_VIOLET = Color3.fromRGB(150, 110, 240)

-- ── the colour pass ─────────────────────────────────────
floor.Color = STONE
floor.Material = Enum.Material.Slate
local recolour = {
	InlayOuter = STONE_DARK,
	InlayRing = BONE,
	InlayInner = STONE_MID,
	GatePath = Color3.fromRGB(48, 45, 52),
	GateEdge = BONE,
}
for _, d in ipairs(hub:GetChildren()) do
	if d:IsA("BasePart") and recolour[d.Name] then
		d.Color = recolour[d.Name]
		d.Material = Enum.Material.Slate
	end
end
local beacon = hub:FindFirstChild("Beacon")
if beacon then
	beacon.Color = SOUL_VIOLET
	-- (its light tinted the whole centre turquoise)
	for _, l in ipairs(beacon:GetChildren()) do
		if l:IsA("Light") then
			l.Color = SOUL_VIOLET
		end
	end
end
local plots = workspace:FindFirstChild("Plots")
for _, plot in ipairs(plots and plots:GetChildren() or {}) do
	local style = plot:FindFirstChild("Style")
	for _, d in ipairs(style and style:GetDescendants() or {}) do
		if d:IsA("BasePart") and (d.Name == "SpawnRing" or d.Name == "SpawnRune" or d.Name == "ArchGlow") then
			d.Color = SOUL_VIOLET
		end
	end
end

-- ── the sigil ───────────────────────────────────────────
local old = hub:FindFirstChild("PlazaSigil")
if old then
	old:Destroy()
end
local sigil = Instance.new("Model")
sigil.Name = "PlazaSigil"

local function bar(name, a, b, width, color, y)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = color or SIGIL
	y = y or SIGIL_Y
	a = Vector3.new(a.X, y, a.Z)
	b = Vector3.new(b.X, y, b.Z)
	p.Size = Vector3.new(width, SIGIL_H, (b - a).Magnitude + width * 0.3)
	p.CFrame = CFrame.lookAt((a + b) / 2, b)
	p.Parent = sigil
	return p
end
local function at(angle, r)
	return Vector3.new(math.cos(angle) * r, 0, math.sin(angle) * r)
end
local function ring(name, r, width, segments)
	for k = 0, segments - 1 do
		local a0, a1 = k / segments * math.pi * 2, (k + 1) / segments * math.pi * 2
		bar(name, at(a0, r), at(a1, r), width)
	end
end

-- the plots' directions from the centre (from their real Base parts)
local plotAngles = {}
for _, plot in ipairs(plots and plots:GetChildren() or {}) do
	local index = tonumber(plot.Name:match("^Plot(%d+)$"))
	local base = plot:FindFirstChild("Base")
	if index and base then
		plotAngles[index] = math.atan2(base.Position.Z, base.Position.X)
	end
end

local R_OUTER, R_INNER = 21.5, 12
local R_RAY_END = 48.5 -- (where the gate paths begin)
ring("SigilRingOuter", R_OUTER, 0.9, 64)
ring("SigilRingInner", R_INNER, 0.7, 40)
-- the eight-pointed star {8/3} between the plot directions (its chords pass under the monument's podium)
local angles = {}
for index, a in pairs(plotAngles) do
	table.insert(angles, a)
end
table.sort(angles)
for k = 1, #angles do
	local j = (k + 2) % #angles + 1
	bar("SigilStar", at(angles[k], R_OUTER), at(angles[j], R_OUTER), 0.55)
end
-- the rays: one down each plot's lane, from the inner ring out to its gate path
for index, a in pairs(plotAngles) do
	local ray = bar("SigilRay" .. index, at(a, R_INNER), at(a, INLAY_R - 0.3), 0.7, SIGIL_RAY)
	ray:SetAttribute("PlotIndex", index)
	local outer = bar("SigilRay" .. index, at(a, INLAY_R - 0.1), at(a, R_RAY_END), 0.7, SIGIL_RAY, LOW_Y)
	outer:SetAttribute("PlotIndex", index)
	-- a small diamond where the ray crosses the outer ring, and one at its end
	for _, r in ipairs({ R_OUTER, R_RAY_END - 0.6 }) do
		local p = at(a, r)
		local d = bar("SigilNode", p - Vector3.new(0, 0, 0), p + Vector3.new(0.01, 0, 0), 2, SIGIL_RAY)
		d.Size = Vector3.new(2, SIGIL_H + 0.01, 2)
		d.CFrame = CFrame.new(p.X, (r > INLAY_R and LOW_Y or SIGIL_Y) + 0.005, p.Z) * CFrame.Angles(0, a + math.pi / 4, 0)
	end
end
-- rune marks between the rays, just outside the outer ring
for k = 0, 15 do
	local a = (#angles > 0 and angles[1] or 0) + math.pi / 8 + k * math.pi / 8
	local p = at(a, R_OUTER + 2.2)
	local tick = bar("SigilRune", p, p + Vector3.new(0.01, 0, 0), 0.45)
	tick.Size = Vector3.new(0.45, SIGIL_H, k % 2 == 0 and 2 or 1.2)
	tick.CFrame = CFrame.new(p.X, SIGIL_Y, p.Z) * CFrame.Angles(0, -a, 0)
end

sigil.Parent = hub
local n = 0
for _, d in ipairs(sigil:GetDescendants()) do
	if d:IsA("BasePart") then
		n += 1
	end
end
return "plaza floor done: sigil " .. n .. " parts, " .. #angles .. " rays"
