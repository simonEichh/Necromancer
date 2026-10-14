-- Builds the Gravedigger's Hood (outfit item, head slot) into ReplicatedStorage.ItemModels.GravediggerHood: a deep,
-- worn charcoal hood with a rolled rim and a drooping brim over the face, a long tail hanging down the back, patched and
-- stitched cloth, a short cowl on the shoulders, an iron skull clasp at the throat and drawstrings with bone beads.
-- The hood covers the hair: equipping it hides the avatar's hat and hair accessories (server Outfits module).
-- Run in Edit mode via the Studio MCP execute_luau (or loadstring over a local http.server, see CLAUDE.md). Safe to re-run.
--
-- Built in the R15 Head's HatAttachment frame (origin = top of the head, Y up, front -Z) for the default head
-- (about 1.16 studs, centre 0.59 below the origin); the server scales it to the avatar's head.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local folder = ReplicatedStorage:FindFirstChild("ItemModels")
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "ItemModels"
	folder.Parent = ReplicatedStorage
end
local old = folder:FindFirstChild("GravediggerHood")
if old then
	old:Destroy()
end

local CLOTH = Color3.fromRGB(46, 44, 52)
local CLOTH_LIGHT = Color3.fromRGB(60, 56, 64)
local CLOTH_DARK = Color3.fromRGB(36, 34, 40)
local LINING = Color3.fromRGB(20, 18, 24)
local PATCH = Color3.fromRGB(74, 62, 50)
local MOSS = Color3.fromRGB(62, 82, 52)
local STITCH = Color3.fromRGB(196, 184, 156)
local IRON = Color3.fromRGB(58, 54, 52)
local IRON_DARK = Color3.fromRGB(40, 38, 38)
local RUST = Color3.fromRGB(104, 64, 42)
local BONE = Color3.fromRGB(214, 204, 178)
local SOCKET = Color3.fromRGB(20, 18, 20)
local LEATHER = Color3.fromRGB(70, 46, 32)

local acc = Instance.new("Accessory")
acc.Name = "GravediggerHood"
acc.AccessoryType = Enum.AccessoryType.Hat

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
	return p
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
	return p
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
-- a row of stitches from a to b, each crossing the seam (normal = the cloth's outward direction)
local function stitches(a, b, n, normal)
	local along = (b - a).Unit
	local across = along:Cross(normal).Unit
	for i = 0, n - 1 do
		local p = a + (b - a) * ((i + 0.5) / n) + normal * 0.012
		part("Stitch", Vector3.new(0.025, 0.025, 0.1), CFrame.lookAt(p, p + across, normal), STITCH, Enum.Material.SmoothPlastic)
	end
end
-- a patch sewn onto the cloth: centre cf (its -Z faces outward), w x h, stitched round the edges
local function patch(cf, w, h, color)
	part("Patch", Vector3.new(w, h, 0.03), cf, color)
	local n = cf.LookVector
	local c = function(x, y)
		return (cf * CFrame.new(x, y, -0.015)).Position
	end
	stitches(c(-w / 2, h / 2), c(w / 2, h / 2), 4, n)
	stitches(c(-w / 2, -h / 2), c(w / 2, -h / 2), 4, n)
	stitches(c(-w / 2, -h / 2), c(-w / 2, h / 2), 3, n)
	stitches(c(w / 2, -h / 2), c(w / 2, h / 2), 3, n)
end

-- ====================================================================
-- Shell: crown, sloped roof, sides, back, rounded back corners
-- ====================================================================
part("Crown", Vector3.new(0.86, 0.14, 1.32), CFrame.new(0, 0.13, 0.06) * CFrame.Angles(math.rad(-4), 0, 0), CLOTH)
part("Roof", Vector3.new(0.44, 0.14, 1.3), CFrame.new(-0.56, 0.02, 0.06) * CFrame.Angles(0, 0, math.rad(32)), CLOTH_LIGHT)
part("Roof", Vector3.new(0.44, 0.14, 1.3), CFrame.new(0.56, 0.02, 0.06) * CFrame.Angles(0, 0, math.rad(-32)), CLOTH)
part("Side", Vector3.new(0.14, 1.12, 1.24), CFrame.new(-0.74, -0.6, 0.08) * CFrame.Angles(0, 0, math.rad(-4)), CLOTH)
part("Side", Vector3.new(0.14, 1.12, 1.24), CFrame.new(0.74, -0.6, 0.08) * CFrame.Angles(0, 0, math.rad(4)), CLOTH_LIGHT)
part("Back", Vector3.new(1.2, 1.18, 0.14), CFrame.new(0, -0.55, 0.74) * CFrame.Angles(math.rad(4), 0, 0), CLOTH)
part("BackTop", Vector3.new(1.16, 0.14, 0.5), CFrame.new(0, -0.02, 0.62) * CFrame.Angles(math.rad(42), 0, 0), CLOTH_DARK)
part("Corner", Vector3.new(0.14, 1.2, 0.42), CFrame.new(-0.62, -0.55, 0.6) * CFrame.Angles(0, math.rad(-45), 0), CLOTH_DARK)
part("Corner", Vector3.new(0.14, 1.2, 0.42), CFrame.new(0.62, -0.55, 0.6) * CFrame.Angles(0, math.rad(45), 0), CLOTH_DARK)
part("RoofCorner", Vector3.new(0.42, 0.14, 0.42), CFrame.new(-0.5, -0.05, 0.55) * CFrame.Angles(math.rad(35), math.rad(-45), math.rad(30)), CLOTH)
part("RoofCorner", Vector3.new(0.42, 0.14, 0.42), CFrame.new(0.5, -0.05, 0.55) * CFrame.Angles(math.rad(35), math.rad(45), math.rad(-30)), CLOTH)
-- loose folds hanging over the sides
part("Fold", Vector3.new(0.06, 0.9, 0.34), CFrame.new(-0.82, -0.66, 0.28) * CFrame.Angles(0, math.rad(-8), math.rad(-5)), CLOTH_DARK)
part("Fold", Vector3.new(0.06, 0.8, 0.3), CFrame.new(0.82, -0.7, 0.36) * CFrame.Angles(0, math.rad(10), math.rad(6)), CLOTH_DARK)
-- dark lining just inside the face opening
part("Lining", Vector3.new(0.04, 1.12, 0.3), CFrame.new(-0.66, -0.58, -0.47), LINING)
part("Lining", Vector3.new(0.04, 1.12, 0.3), CFrame.new(0.66, -0.58, -0.47), LINING)
part("Lining", Vector3.new(1.3, 0.04, 0.32), CFrame.new(0, 0.05, -0.46), LINING)

-- ====================================================================
-- Face opening: a rolled rim in a pointed arch that comes down over the forehead, cloth filling the space above it,
-- dark lining inside, and the hood's tip dipping over the brow
-- ====================================================================
local function arch(t)
	local s = math.sin(t)
	-- a pointed arch: the top is pulled up into a point; it leans forward towards the top
	return Vector3.new(0.64 * math.cos(t), -1.15 + 0.95 * s + 0.12 * s ^ 8, -0.64 - 0.1 * s)
end
local ARCH_N = 12
for i = 0, ARCH_N - 1 do
	local a, b = arch(math.pi * i / ARCH_N), arch(math.pi * (i + 1) / ARCH_N)
	cyl("Rim", a, b, 0.21, CLOTH_LIGHT)
	ball("RimJoint", b, 0.21, CLOTH_LIGHT, Enum.Material.Fabric)
	cyl("RimLining", a * Vector3.new(0.9, 1, 1) + Vector3.new(0, 0.04, 0.09), b * Vector3.new(0.9, 1, 1) + Vector3.new(0, 0.04, 0.09), 0.12, LINING)
	local mid = (a + b) / 2
	if mid.Y > -0.95 then
		-- cloth from the rim up to the crown
		local top = 0.16
		part("Front", Vector3.new(math.abs(b.X - a.X) + 0.1, top - mid.Y, 0.12), CFrame.new(mid.X, (top + mid.Y) / 2, mid.Z + 0.03), i % 3 == 0 and CLOTH_DARK or CLOTH)
	end
end
ball("RimJoint", arch(0), 0.21, CLOTH_LIGHT, Enum.Material.Fabric)
local apex = arch(math.pi / 2)
wedge("BrowPoint", Vector3.new(0.08, 0.2, 0.24), CFrame.new(apex + Vector3.new(0, -0.14, -0.04)) * CFrame.Angles(0, math.rad(90), math.rad(180)), CLOTH_DARK)
-- grommets round the rim
for i = 1, 5 do
	local p = arch(math.pi * (i + 0.5) / 7) + Vector3.new(0, 0, -0.09)
	cyl("Grommet", p - Vector3.new(0, 0, 0.02), p + Vector3.new(0, 0, 0.02), 0.07, RUST, Enum.Material.Metal)
end
-- the pointed peak on top, leaning back
wedge("Peak", Vector3.new(0.62, 0.4, 0.75), CFrame.new(0, 0.38, 0.32), CLOTH)
wedge("Peak", Vector3.new(0.4, 0.26, 0.5), CFrame.new(0, 0.66, 0.5), CLOTH_DARK)

-- ====================================================================
-- The tail (liripipe) hanging down the back, with a rusty bell at the tip
-- ====================================================================
local tail = {
	{ Vector3.new(0, 0.02, 0.86), Vector3.new(0.72, 0.5, 0.36), -32 },
	{ Vector3.new(0, -0.36, 1.0), Vector3.new(0.52, 0.42, 0.32), -12 },
	{ Vector3.new(0.03, -0.76, 1.05), Vector3.new(0.38, 0.42, 0.28), -4 },
	{ Vector3.new(0.06, -1.14, 1.05), Vector3.new(0.26, 0.38, 0.22), 4 },
}
for i, t in tail do
	part("Tail", t[2], CFrame.new(t[1]) * CFrame.Angles(math.rad(t[3]), 0, math.rad(i * 3)), i % 2 == 0 and CLOTH_DARK or CLOTH)
end
wedge("TailTip", Vector3.new(0.2, 0.3, 0.18), CFrame.new(0.08, -1.47, 1.04) * CFrame.Angles(0, 0, math.rad(180)), CLOTH)
cyl("BellRing", Vector3.new(0.08, -1.6, 1.0), Vector3.new(0.08, -1.6, 1.08), 0.09, IRON_DARK, Enum.Material.Metal)
cyl("Bell", Vector3.new(0.08, -1.64, 1.04), Vector3.new(0.08, -1.8, 1.04), 0.14, RUST, Enum.Material.Metal)
cyl("BellLip", Vector3.new(0.08, -1.79, 1.04), Vector3.new(0.08, -1.83, 1.04), 0.19, RUST, Enum.Material.Metal)
ball("Clapper", Vector3.new(0.08, -1.86, 1.04), 0.06, IRON_DARK, Enum.Material.Metal)

-- ====================================================================
-- Patches, seams and stitches
-- ====================================================================
stitches(Vector3.new(0, 0.205, -0.55), Vector3.new(0, 0.18, 0.66), 8, Vector3.yAxis)
patch(CFrame.new(-0.82, -0.45, -0.05) * CFrame.Angles(0, math.rad(90), math.rad(8)), 0.4, 0.32, PATCH)
patch(CFrame.new(0.2, -0.75, 0.825) * CFrame.Angles(0, math.rad(180), math.rad(-6)), 0.36, 0.3, MOSS)
patch(CFrame.new(0.35, 0.215, 0.25) * CFrame.Angles(math.rad(-90), 0, 0), 0.24, 0.3, CLOTH_LIGHT)
stitches(Vector3.new(-0.82, -1.1, 0.5), Vector3.new(-0.81, -0.75, 0.62), 3, -Vector3.xAxis)

-- ====================================================================
-- Cowl: short ragged collar lying on the shoulders
-- ====================================================================
for i = 0, 11 do
	local a = (i + 0.5) / 12 * math.pi * 2
	if math.sin(a) > -0.9 then -- leave the throat (front, -Z) open
		local x, z = math.cos(a) * 0.78, math.sin(a) * 0.62
		local cf = CFrame.lookAt(Vector3.new(x, -1.2, z), Vector3.new(x * 2, -1.2, z * 2)) * CFrame.Angles(math.rad(-58), 0, 0)
		part("Cowl", Vector3.new(0.46, 0.5, 0.08), cf, i % 2 == 0 and CLOTH or CLOTH_DARK)
		if i % 2 == 0 then
			wedge("CowlTip", Vector3.new(0.08, 0.16, 0.22), cf * CFrame.new(-0.1, -0.32, 0) * CFrame.Angles(0, math.rad(90), math.rad(180)), CLOTH)
		end
	end
end

-- ====================================================================
-- Throat clasp with a skull, and drawstrings with bone beads
-- ====================================================================
local clasp = CFrame.new(0, -1.22, -0.68)
cyl("Clasp", (clasp * CFrame.new(0, 0, 0.03)).Position, (clasp * CFrame.new(0, 0, -0.03)).Position, 0.34, IRON, Enum.Material.Metal)
cyl("ClaspRim", (clasp * CFrame.new(0, 0, 0.05)).Position, (clasp * CFrame.new(0, 0, 0.0)).Position, 0.4, RUST, Enum.Material.Metal)
for i = 0, 5 do
	local a = i / 6 * math.pi * 2
	ball("ClaspRivet", (clasp * CFrame.new(math.cos(a) * 0.15, math.sin(a) * 0.15, -0.035)).Position, 0.05, IRON_DARK, Enum.Material.Metal)
end
local s = clasp * CFrame.new(0, 0.01, -0.08)
ball("Skull", (s * CFrame.new(0, 0.02, 0)).Position, 0.17, BONE)
part("SkullFace", Vector3.new(0.13, 0.08, 0.06), s * CFrame.new(0, -0.04, -0.05), BONE, Enum.Material.SmoothPlastic)
part("SkullJaw", Vector3.new(0.1, 0.04, 0.06), s * CFrame.new(0, -0.1, -0.04), BONE, Enum.Material.SmoothPlastic)
ball("Eye", (s * CFrame.new(-0.035, 0.0, -0.075)).Position, 0.05, SOCKET)
ball("Eye", (s * CFrame.new(0.035, 0.0, -0.075)).Position, 0.05, SOCKET)
-- chain links from the clasp to the hood's rim
for side = -1, 1, 2 do
	for i = 1, 2 do
		local p = clasp.Position + Vector3.new(side * (0.2 + i * 0.12), 0.06 + i * 0.05, 0.03)
		cyl("ClaspLink", p - Vector3.new(side * 0.05, 0, 0), p + Vector3.new(side * 0.05, 0, 0), 0.06, IRON_DARK, Enum.Material.Metal)
	end
	-- drawstring
	local top = Vector3.new(side * 0.32, -1.15, -0.66)
	local bottom = top + Vector3.new(side * 0.04, -0.42, -0.02)
	cyl("Drawstring", top, bottom, 0.035, LEATHER)
	ball("Bead", bottom, 0.1, BONE)
	part("Fray", Vector3.new(0.02, 0.1, 0.02), CFrame.new(bottom + Vector3.new(0, -0.1, 0)) * CFrame.Angles(0, 0, math.rad(side * 10)), LEATHER)
end

-- ====================================================================
-- Finish: handle, welds
-- ====================================================================
local handle = part("Handle", Vector3.new(0.2, 0.2, 0.2), CFrame.new(), CLOTH)
handle.Transparency = 1
local att = Instance.new("Attachment")
att.Name = "HatAttachment"
att.Parent = handle
local count = 0
for _, p in acc:GetChildren() do
	if p:IsA("BasePart") then
		count += 1
		p.Anchored = false
		p.CanQuery = false
		p.CanTouch = false
		p.Massless = true
		if p ~= handle then
			local w = Instance.new("WeldConstraint")
			w.Part0 = handle
			w.Part1 = p
			w.Parent = p
		end
	end
end
acc.Parent = folder
return "GravediggerHood built, " .. count .. " parts"
