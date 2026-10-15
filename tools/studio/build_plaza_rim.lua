-- The plaza, batch 3 of "The Ossuary Court" (docs/world.md): the rim. Safe to re-run.
-- Run in Edit mode (Studio MCP execute_luau or loadstring from the tools/studio http server); save the place after.
-- Replaces the plain rim wall (HubDecor Rim / RimCap) and the 16 lamp posts on it (moved to ServerStorage.RetiredPlaza,
-- not deleted) with a gothic balustrade (HubDecor.PlazaRim): a dark plinth, diamond balusters and a bone-stone
-- handrail, broken by the 8 plot entrances. Tall piers flank every entrance and stand halfway between them, each
-- crowned by a small iron lantern with a pale soul flame. The plot arches beyond the entrances belong to the plots and
-- are not touched; neither are the lamp posts on the plots or the stalls.
local ServerStorage = game:GetService("ServerStorage")
local hub = workspace:FindFirstChild("HubDecor")
local plots = workspace:FindFirstChild("Plots")
assert(hub and plots, "HubDecor / Plots missing")

local FLOOR_TOP = -1.7
local R = 54.8 -- (where the old rim stood)
local GAP_HALF = 6.2 -- half the width of a plot entrance, in studs along the rim
local SEG_LEN = 3.6

local PLINTH = Color3.fromRGB(50, 46, 54)
local STONE = Color3.fromRGB(64, 60, 68)
local BONE = Color3.fromRGB(120, 110, 96)
local IRON = Color3.fromRGB(32, 30, 34)
local FLAME = Color3.fromRGB(170, 255, 200)

-- ── retire the old rim and its lamps ────────────────────
local retired = ServerStorage:FindFirstChild("RetiredPlaza")
if not retired then
	retired = Instance.new("Folder")
	retired.Name = "RetiredPlaza"
	retired.Parent = ServerStorage
end
for _, c in ipairs(hub:GetChildren()) do
	local pos = c:IsA("BasePart") and c.Position or (c:IsA("Model") and c:GetPivot().Position)
	local r = pos and math.sqrt(pos.X * pos.X + pos.Z * pos.Z)
	if c.Name == "Rim" or c.Name == "RimCap" or (c.Name == "LampPost" and r and r < 58) then
		c.Parent = retired
	end
end
local old = hub:FindFirstChild("PlazaRim")
if old then
	old:Destroy()
end
local rim = Instance.new("Model")
rim.Name = "PlazaRim"

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
	p.Parent = rim
	return p
end
local function at(a, r, y)
	return Vector3.new(math.cos(a) * r, y or FLOOR_TOP, math.sin(a) * r)
end

-- the entrances: one per plot, in the direction of its Base
local gates = {}
for _, plot in ipairs(plots:GetChildren()) do
	local base = plot:FindFirstChild("Base")
	if base and plot.Name:match("^Plot%d+$") then
		table.insert(gates, math.atan2(base.Position.Z, base.Position.X))
	end
end
table.sort(gates)
local gapAngle = GAP_HALF / R

-- ── the pieces ──────────────────────────────────────────
local PLINTH_H, BALUSTER_H, RAIL_H = 0.6, 2, 0.35
local function segment(a0, a1)
	local p0, p1 = at(a0, R), at(a1, R)
	local mid = (p0 + p1) / 2
	local len = (p1 - p0).Magnitude
	local frame = CFrame.lookAt(mid, p1) -- (Z along the rim)
	local plinth = part("RimPlinth", Vector3.new(1.4, PLINTH_H, len + 0.04), frame * CFrame.new(0, PLINTH_H / 2, 0), PLINTH)
	plinth.CanCollide = true
	local rail = part("RimRail", Vector3.new(1.15, RAIL_H, len + 0.06), frame * CFrame.new(0, PLINTH_H + BALUSTER_H + RAIL_H / 2, 0), BONE, Enum.Material.Limestone)
	rail.CanCollide = true
	-- (an invisible wall up to the rail, so nobody squeezes between the balusters)
	local block = part("RimBlock", Vector3.new(0.5, BALUSTER_H, len), frame * CFrame.new(0, PLINTH_H + BALUSTER_H / 2, 0), STONE)
	block.Transparency = 1
	block.CanCollide = true
	local n = math.max(2, math.floor(len / 0.9))
	for k = 1, n do
		local z = (k - 0.5) / n * len - len / 2
		part("Baluster", Vector3.new(0.42, BALUSTER_H, 0.42), frame * CFrame.new(0, PLINTH_H + BALUSTER_H / 2, z) * CFrame.Angles(0, math.rad(45), 0), STONE)
	end
end
-- a skull: cranium, jaw, deep eye sockets, nose, a line of teeth (`cf`: its -Z looks out at the viewer)
local function skull(cf, bone, dark)
	part("Skull", Vector3.new(0.95, 0.95, 0.95), cf * CFrame.new(0, 0.1, 0), bone, Enum.Material.Limestone, Enum.PartType.Ball)
	part("SkullJaw", Vector3.new(0.55, 0.34, 0.5), cf * CFrame.new(0, -0.3, -0.12), bone, Enum.Material.Limestone)
	for _, s in ipairs({ -1, 1 }) do
		part("SkullEye", Vector3.new(0.3, 0.3, 0.3), cf * CFrame.new(s * 0.2, 0.08, -0.33), dark, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	end
	part("SkullNose", Vector3.new(0.12, 0.14, 0.1), cf * CFrame.new(0, -0.1, -0.42), dark, Enum.Material.SmoothPlastic)
	part("SkullTeeth", Vector3.new(0.4, 0.05, 0.05), cf * CFrame.new(0, -0.33, -0.39), dark, Enum.Material.SmoothPlastic)
end

local function lantern(top)
	-- an iron lantern: a base plate, four corner posts, a pointed roof, the soul flame inside
	part("LanternBase", Vector3.new(1, 0.15, 1), CFrame.new(top + Vector3.new(0, 0.075, 0)), IRON, Enum.Material.Metal)
	for _, c in ipairs({ { -1, -1 }, { -1, 1 }, { 1, -1 }, { 1, 1 } }) do
		part("LanternPost", Vector3.new(0.1, 1.1, 0.1), CFrame.new(top + Vector3.new(c[1] * 0.42, 0.7, c[2] * 0.42)), IRON, Enum.Material.Metal)
	end
	part("LanternRoof", Vector3.new(1.1, 0.12, 1.1), CFrame.new(top + Vector3.new(0, 1.3, 0)), IRON, Enum.Material.Metal)
	part("LanternRoofTop", Vector3.new(0.6, 0.4, 0.6), CFrame.new(top + Vector3.new(0, 1.55, 0)) * CFrame.Angles(0, math.rad(45), 0), IRON, Enum.Material.Metal)
	local flame = part("LanternFlame", Vector3.new(0.45, 0.6, 0.45), CFrame.new(top + Vector3.new(0, 0.6, 0)), FLAME, Enum.Material.Neon)
	local l = Instance.new("PointLight")
	l.Color = FLAME
	l.Range = 12
	l.Brightness = 0.9
	l.Shadows = false
	l.Parent = flame
end
local function pier(a, tall)
	local h = tall and 5.4 or 4.2
	local base = at(a, R)
	local frame = CFrame.lookAt(base, Vector3.new(0, base.Y, 0)) -- (facing the well)
	local w = tall and 2 or 1.7
	local p = part("Pier", Vector3.new(w, h, w), frame * CFrame.new(0, h / 2, 0), PLINTH)
	p.CanCollide = true
	part("PierBand", Vector3.new(w + 0.2, 0.3, w + 0.2), frame * CFrame.new(0, PLINTH_H + 0.15, 0), STONE)
	part("PierCap", Vector3.new(w + 0.35, 0.4, w + 0.35), frame * CFrame.new(0, h + 0.2, 0), BONE, Enum.Material.Limestone)
	if tall then
		-- a skull on the face of the entrance piers
		skull(frame * CFrame.new(0, h * 0.62, -w / 2 - 0.05), BONE, Color3.fromRGB(10, 6, 20))
	end
	lantern((frame * CFrame.new(0, h + 0.4, 0)).Position)
end

-- ── build: between every two entrances, an arc of balustrade with a pier at each end and one halfway ──
for k = 1, #gates do
	local from = gates[k] + gapAngle
	local to = (k < #gates and gates[k + 1] or gates[1] + math.pi * 2) - gapAngle
	local arc = (to - from) * R
	local n = math.max(1, math.floor(arc / SEG_LEN + 0.5))
	local step = (to - from) / n
	for s = 0, n - 1 do
		segment(from + s * step, from + (s + 1) * step)
	end
	pier(from, true)
	pier(to, true)
	pier((from + to) / 2, false)
end

rim.Parent = hub
local count = 0
for _, d in ipairs(rim:GetDescendants()) do
	if d:IsA("BasePart") then
		count += 1
	end
end
return "plaza rim done: " .. count .. " parts, " .. #gates .. " entrances"
