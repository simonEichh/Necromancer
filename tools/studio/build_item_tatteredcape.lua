-- Builds the Tattered Cape (outfit item, back slot) into ReplicatedStorage.ItemModels.TatteredCape: a long pleated
-- charcoal cape with a moss-green lining, ragged torn ends and loose threads, a rolled hem across the shoulders with
-- shoulder drapes, a sagging iron chain across the chest between two skull studs, rusty rivets and a faint soul-green
-- sigil embroidered on the back.
-- Run in Edit mode via the Studio MCP execute_luau (or loadstring over a local http.server, see CLAUDE.md). Safe to re-run.
--
-- Built in the R15 UpperTorso's BodyBackAttachment frame (origin on the middle of the back, Y up, +Z out behind the
-- character, +X to its right; shoulders at y 1.06, x +-0.97; chest front at z -1.0; feet at y -3.2).
-- The cape hangs in four rows that can sway: row 1 is welded to the Handle, rows 2-4 to the invisible parts
-- CapePivot1..3, chained by Motor6Ds CapeSway1..3 (client animates their Transform).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local folder = ReplicatedStorage:FindFirstChild("ItemModels")
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "ItemModels"
	folder.Parent = ReplicatedStorage
end
local old = folder:FindFirstChild("TatteredCape")
if old then
	old:Destroy()
end

local CLOTH = Color3.fromRGB(44, 42, 50)
local CLOTH_LIGHT = Color3.fromRGB(58, 54, 64)
local CLOTH_DARK = Color3.fromRGB(34, 32, 38)
local LINING = Color3.fromRGB(54, 72, 48)
local PATCH = Color3.fromRGB(74, 62, 50)
local STITCH = Color3.fromRGB(196, 184, 156)
local IRON = Color3.fromRGB(58, 54, 52)
local IRON_DARK = Color3.fromRGB(40, 38, 38)
local RUST = Color3.fromRGB(104, 64, 42)
local BONE = Color3.fromRGB(214, 204, 178)
local SOCKET = Color3.fromRGB(20, 18, 20)
local SIGIL = Color3.fromRGB(70, 210, 140)

local acc = Instance.new("Accessory")
acc.Name = "TatteredCape"
acc.AccessoryType = Enum.AccessoryType.Back

local seg = 1 -- the row the next parts belong to
local function tag(p)
	if seg > 1 then
		p:SetAttribute("Seg", seg)
	end
	return p
end
local function part(name, size, cf, color, material, shape)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CastShadow = false
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.Fabric
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if shape then
		p.Shape = shape
	end
	p.Parent = acc
	return tag(p)
end
local function wedge(name, size, cf, color, material)
	local p = Instance.new("WedgePart")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CastShadow = false
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.Fabric
	p.Parent = acc
	return tag(p)
end
local function cyl(name, a, b, d, color, material)
	local dir = b - a
	local up = math.abs(dir.Unit.Y) > 0.98 and Vector3.xAxis or Vector3.yAxis
	local cf = CFrame.lookAt((a + b) / 2, b, up) * CFrame.Angles(0, math.rad(90), 0)
	return part(name, Vector3.new(dir.Magnitude, d, d), cf, color, material, Enum.PartType.Cylinder)
end
local function ball(name, pos, d, color, material)
	return part(name, Vector3.new(d, d, d), CFrame.new(pos), color, material or Enum.Material.SmoothPlastic, Enum.PartType.Ball)
end
-- a slab whose long side runs from a to b (bottom to top), w wide, t thick, turned `yaw` round its own length
local function strip(name, a, b, w, t, color, yaw)
	local up = (b - a).Unit
	local right = (Vector3.xAxis - up * up.X).Unit
	local cf = CFrame.fromMatrix((a + b) / 2, right, up) * CFrame.Angles(0, math.rad(yaw or 0), 0)
	return part(name, Vector3.new(w, (b - a).Magnitude, t), cf, color)
end
local function stitches(a, b, n, normal)
	local along = (b - a).Unit
	local across = along:Cross(normal).Unit
	for i = 0, n - 1 do
		local p = a + (b - a) * ((i + 0.5) / n) + normal * 0.012
		part("Stitch", Vector3.new(0.025, 0.025, 0.1), CFrame.lookAt(p, p + across, normal), STITCH, Enum.Material.SmoothPlastic)
	end
end

-- ====================================================================
-- Cape body: four rows of pleated strips, lining underneath
-- ====================================================================
local ROWS = { 1.0, 0.15, -0.75, -1.65, -2.55 } -- joint heights, top to bottom
local N = 6
local function width(y)
	return 2.0 + (1.0 - y) / 3.55 * 0.9
end
local function zBack(y)
	return 0.08 + (1.0 - y) * 0.1
end
local FOLD = { -0.02, 0.07, -0.02, 0.03, 0.07, -0.02 } -- the middle two stay flat for the sigil
local YAW = { -9, 8, -4, 4, -8, 9 }
local RAGGED = { 0.25, -0.22, 0.08, -0.3, 0.14, -0.12 } -- extra length of the bottom row's strips
local COLORS = { CLOTH, CLOTH_LIGHT, CLOTH, CLOTH_DARK, CLOTH_LIGHT, CLOTH }
for r = 1, 4 do
	seg = r
	local yT, yB = ROWS[r], ROWS[r + 1]
	if r > 1 then
		yT += 0.06 -- rows overlap a little so no gap opens when they sway
	end
	for i = 1, N do
		local wT, wB = width(yT), width(yB)
		local xT = -wT / 2 + (i - 0.5) * wT / N
		local xB = -wB / 2 + (i - 0.5) * wB / N
		local yb = yB
		if r == 4 then
			yb = yB - RAGGED[i]
		end
		local f = FOLD[i]
		local a = Vector3.new(xB, yb, zBack(yb) + f + 0.05)
		local b = Vector3.new(xT, yT, zBack(yT) + f + 0.05)
		local w = (wT + wB) / 2 / N * 1.12
		strip("Cloth", a, b, w, 0.07, COLORS[i], YAW[i])
		strip("Lining", a - Vector3.new(0, -0.04, 0.05), b - Vector3.new(0, 0, 0.05), w * 0.96, 0.03, LINING, YAW[i])
		if r == 4 then
			-- torn tip: a slanted wedge under the strip, alternating sides
			local tipLen = 0.3 + (i % 3) * 0.08
			local dir = (b - a).Unit
			local cf = CFrame.fromMatrix(a - dir * (tipLen / 2 - 0.02), (Vector3.xAxis - dir * dir.X).Unit, dir)
				* CFrame.Angles(0, math.rad(YAW[i] + (i % 2 == 0 and 90 or -90)), math.rad(180))
			wedge("Tatter", Vector3.new(0.07, tipLen, w * 0.9), cf, COLORS[i])
			-- loose threads
			local th = a - dir * 0.05 + Vector3.new((i % 2 == 0) and 0.08 or -0.08, 0, 0)
			part("Thread", Vector3.new(0.02, 0.32, 0.02), CFrame.new(th - Vector3.new(0, 0.18, 0)) * CFrame.Angles(0, 0, math.rad(i % 2 == 0 and 8 or -8)), CLOTH_LIGHT)
		end
	end
	-- the side edges roll inwards, showing the lining
	local wT, wB = width(yT), width(yB)
	for side = -1, 1, 2 do
		local a = Vector3.new(side * wB / 2, yB, zBack(yB) + 0.02)
		local b = Vector3.new(side * wT / 2, yT, zBack(yT) + 0.02)
		strip("EdgeRoll", a, b, 0.1, 0.1, LINING, 0)
	end
end

-- ====================================================================
-- Sigil embroidered on the back (row 2)
-- ====================================================================
seg = 2
do
	local yc = -0.3
	local up = (Vector3.new(0, ROWS[2], zBack(ROWS[2])) - Vector3.new(0, ROWS[3], zBack(ROWS[3]))).Unit
	local right = Vector3.xAxis
	local S = CFrame.fromMatrix(Vector3.new(0, yc, zBack(yc) + 0.025 + 0.05 + 0.04), right, up) -- +Z = outward
	for i = 0, 13 do
		local a = i / 14 * math.pi * 2
		local p = S * CFrame.new(math.cos(a) * 0.36, math.sin(a) * 0.36, 0) * CFrame.Angles(0, 0, a + math.pi / 2)
		part("Sigil", Vector3.new(0.13, 0.035, 0.02), p, SIGIL, Enum.Material.Neon)
	end
	for i = 0, 2 do -- inverted triangle
		local a1 = math.rad(90 + i * 120 + 180)
		local a2 = math.rad(90 + (i + 1) * 120 + 180)
		local p1 = Vector3.new(math.cos(a1) * 0.3, math.sin(a1) * 0.3, 0)
		local p2 = Vector3.new(math.cos(a2) * 0.3, math.sin(a2) * 0.3, 0)
		local d = p2 - p1
		part("Sigil", Vector3.new(d.Magnitude, 0.03, 0.02), S * CFrame.new((p1 + p2) / 2) * CFrame.Angles(0, 0, math.atan2(d.Y, d.X)), SIGIL, Enum.Material.Neon)
	end
	-- a small skull stitched in bone thread in the middle
	part("SigilSkull", Vector3.new(0.2, 0.17, 0.02), S * CFrame.new(0, 0.02, 0), BONE, Enum.Material.Fabric)
	part("SigilJaw", Vector3.new(0.12, 0.06, 0.02), S * CFrame.new(0, -0.09, 0), BONE, Enum.Material.Fabric)
	part("SigilEye", Vector3.new(0.05, 0.05, 0.022), S * CFrame.new(-0.05, 0.03, 0.003), SIGIL, Enum.Material.Neon)
	part("SigilEye", Vector3.new(0.05, 0.05, 0.022), S * CFrame.new(0.05, 0.03, 0.003), SIGIL, Enum.Material.Neon)
end

-- ====================================================================
-- A patch on row 3
-- ====================================================================
seg = 3
do
	local y = -1.25
	local up = (Vector3.new(0, ROWS[3], zBack(ROWS[3])) - Vector3.new(0, ROWS[4], zBack(ROWS[4]))).Unit
	local P = CFrame.fromMatrix(Vector3.new(-0.55, y, zBack(y) + 0.12), Vector3.xAxis, up) * CFrame.Angles(0, 0, math.rad(7))
	part("Patch", Vector3.new(0.42, 0.36, 0.03), P, PATCH)
	local n = P.LookVector * -1
	local c = function(x, yy)
		return (P * CFrame.new(x, yy, 0.015)).Position
	end
	stitches(c(-0.21, 0.18), c(0.21, 0.18), 4, n)
	stitches(c(-0.21, -0.18), c(0.21, -0.18), 4, n)
	stitches(c(-0.21, -0.18), c(-0.21, 0.18), 3, n)
	stitches(c(0.21, -0.18), c(0.21, 0.18), 3, n)
end

-- ====================================================================
-- Shoulders: rolled hem, rivets, shoulder drapes
-- ====================================================================
seg = 1
cyl("Hem", Vector3.new(-1.08, 1.02, 0.12), Vector3.new(1.08, 1.02, 0.12), 0.22, CLOTH_LIGHT)
for i = -3, 3 do
	local p = Vector3.new(i * 0.3, 1.02, 0.23)
	cyl("Rivet", p - Vector3.new(0, 0, 0.02), p + Vector3.new(0, 0, 0.03), 0.09, RUST, Enum.Material.Metal)
end
for side = -1, 1, 2 do
	part("Drape", Vector3.new(0.62, 0.1, 0.9), CFrame.new(side * 0.7, 1.12, -0.38) * CFrame.Angles(0, 0, math.rad(-side * 14)), CLOTH)
	part("Drape", Vector3.new(0.5, 0.08, 0.6), CFrame.new(side * 1.02, 1.0, -0.4) * CFrame.Angles(0, 0, math.rad(-side * 48)), CLOTH_DARK)
	-- the drape's front edge hangs over the chest
	part("DrapeFront", Vector3.new(0.5, 0.42, 0.08), CFrame.new(side * 0.72, 0.92, -1.06) * CFrame.Angles(math.rad(-8), 0, 0), CLOTH)
	wedge("DrapeTip", Vector3.new(0.08, 0.2, 0.5), CFrame.new(side * 0.72, 0.62, -1.08) * CFrame.Angles(0, math.rad(90), math.rad(180)), CLOTH)
end

-- ====================================================================
-- Chest chain between two skull studs
-- ====================================================================
for side = -1, 1, 2 do
	local c = CFrame.new(side * 0.62, 0.52, -1.12)
	cyl("Stud", (c * CFrame.new(0, 0, 0.03)).Position, (c * CFrame.new(0, 0, -0.04)).Position, 0.36, IRON, Enum.Material.Metal)
	cyl("StudRim", (c * CFrame.new(0, 0, 0.05)).Position, c.Position, 0.42, RUST, Enum.Material.Metal)
	local s = c * CFrame.new(0, 0.01, -0.09)
	ball("Skull", (s * CFrame.new(0, 0.02, 0)).Position, 0.18, BONE)
	part("SkullFace", Vector3.new(0.14, 0.08, 0.06), s * CFrame.new(0, -0.04, -0.05), BONE, Enum.Material.SmoothPlastic)
	part("SkullJaw", Vector3.new(0.1, 0.04, 0.06), s * CFrame.new(0, -0.1, -0.04), BONE, Enum.Material.SmoothPlastic)
	ball("Eye", (s * CFrame.new(-0.037, 0.0, -0.08)).Position, 0.05, SOCKET)
	ball("Eye", (s * CFrame.new(0.037, 0.0, -0.08)).Position, 0.05, SOCKET)
end
local LINKS = 8
for i = 1, LINKS do
	local t = (i - 0.5) / LINKS
	local x = -0.44 + t * 0.88
	local y = 0.48 - 0.14 * (1 - (x / 0.44) ^ 2)
	local cf = CFrame.new(x, y, -1.14) * CFrame.Angles(i % 2 == 0 and math.rad(90) or 0, 0, 0)
	local w, h, th = 0.15, 0.09, 0.03
	part("Link", Vector3.new(w, th, th), cf * CFrame.new(0, h / 2, 0), IRON_DARK, Enum.Material.Metal)
	part("Link", Vector3.new(w, th, th), cf * CFrame.new(0, -h / 2, 0), IRON_DARK, Enum.Material.Metal)
	part("Link", Vector3.new(th, h, th), cf * CFrame.new(w / 2, 0, 0), IRON_DARK, Enum.Material.Metal)
	part("Link", Vector3.new(th, h, th), cf * CFrame.new(-w / 2, 0, 0), IRON_DARK, Enum.Material.Metal)
end

-- ====================================================================
-- Finish: handle, pivots + Motor6Ds for the sway, welds
-- ====================================================================
seg = 1
local handle = part("Handle", Vector3.new(0.2, 0.2, 0.2), CFrame.new(), CLOTH)
handle.Transparency = 1
local att = Instance.new("Attachment")
att.Name = "BodyBackAttachment"
att.Parent = handle
local pivots = {}
local prev = handle
for k = 1, 3 do
	local y = ROWS[k + 1]
	local p = part("CapePivot" .. k, Vector3.new(0.2, 0.2, 0.2), CFrame.new(0, y, zBack(y) + 0.05), CLOTH)
	p.Transparency = 1
	p:SetAttribute("Seg", nil)
	p:SetAttribute("Pivot", true)
	pivots[k] = p
	local m = Instance.new("Motor6D")
	m.Name = "CapeSway" .. k
	m.Part0 = prev
	m.Part1 = p
	m.C0 = prev.CFrame:Inverse() * p.CFrame
	m.C1 = CFrame.new()
	m.Parent = prev
	prev = p
end
local count = 0
for _, p in acc:GetChildren() do
	if p:IsA("BasePart") then
		count += 1
		p.Anchored = false
		p.CanQuery = false
		p.CanTouch = false
		p.Massless = true
		if p ~= handle and not p:GetAttribute("Pivot") then
			local s = p:GetAttribute("Seg")
			local w = Instance.new("WeldConstraint")
			w.Part0 = (s and s > 1) and pivots[s - 1] or handle
			w.Part1 = p
			w.Parent = p
		end
	end
end
acc.Parent = folder
return "TatteredCape built, " .. count .. " parts"
