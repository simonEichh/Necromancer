-- Builds the Lantern Staff (outfit item, hand slot) into ReplicatedStorage.ItemModels.LanternStaff: a crooked dark wood
-- staff with iron bands, a leather grip, a shepherd's crook at the top and an ornate iron lantern with a soul-green flame
-- hanging from it on a short chain; a bone skull charm and torn rags tied under the hook.
-- Run in Edit mode via the Studio MCP execute_luau (or loadstring over a local http.server, see CLAUDE.md). Safe to re-run.
--
-- Item conventions: an Accessory with an invisible `Handle` at the origin holding an Attachment named after the
-- character attachment it snaps to (here RightGripAttachment on the R15 RightHand). Every other part is welded to the
-- Handle, unanchored, Massless, no collision. Built in a "staff frame" (Y up the staff, -Z forward, grip at the origin)
-- and turned into the grip attachment's frame at the end (its +Z runs up the arm, its +Y points forward).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local folder = ReplicatedStorage:FindFirstChild("ItemModels")
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "ItemModels"
	folder.Parent = ReplicatedStorage
end
local old = folder:FindFirstChild("LanternStaff")
if old then
	old:Destroy()
end

local WOOD = Color3.fromRGB(62, 44, 34)
local WOOD_DARK = Color3.fromRGB(42, 30, 24)
local WOOD_KNOT = Color3.fromRGB(78, 56, 42)
local IRON = Color3.fromRGB(58, 54, 52)
local IRON_DARK = Color3.fromRGB(40, 38, 38)
local RUST = Color3.fromRGB(104, 64, 42)
local LEATHER = Color3.fromRGB(78, 50, 34)
local LEATHER_DARK = Color3.fromRGB(56, 36, 26)
local CLOTH = Color3.fromRGB(46, 44, 52)
local MOSS = Color3.fromRGB(70, 98, 54)
local BONE = Color3.fromRGB(214, 204, 178)
local SOCKET = Color3.fromRGB(20, 18, 20)
local GLASS = Color3.fromRGB(120, 200, 150)
local SOUL = Color3.fromRGB(90, 255, 160)

local acc = Instance.new("Accessory")
acc.Name = "LanternStaff"
acc.AccessoryType = Enum.AccessoryType.Unknown

local function part(name, size, cf, color, material, shape)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CastShadow = false
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
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
	p.Material = material or Enum.Material.SmoothPlastic
	p.Parent = acc
	return p
end
-- a cylinder from a to b
local function cyl(name, a, b, d, color, material)
	local dir = b - a
	local up = math.abs(dir.Unit.Y) > 0.98 and Vector3.xAxis or Vector3.yAxis
	local cf = CFrame.lookAt((a + b) / 2, b, up) * CFrame.Angles(0, math.rad(90), 0)
	return part(name, Vector3.new(dir.Magnitude, d, d), cf, color, material, Enum.PartType.Cylinder)
end
local function ball(name, pos, d, color, material)
	return part(name, Vector3.new(d, d, d), CFrame.new(pos), color, material, Enum.PartType.Ball)
end
-- a ring-shaped chain link (four bars) centred at cf, w wide, h high
local function link(cf, w, h, t, color)
	part("Link", Vector3.new(w, t, t), cf * CFrame.new(0, h / 2 - t / 2, 0), color, Enum.Material.Metal)
	part("Link", Vector3.new(w, t, t), cf * CFrame.new(0, -h / 2 + t / 2, 0), color, Enum.Material.Metal)
	part("Link", Vector3.new(t, h, t), cf * CFrame.new(w / 2 - t / 2, 0, 0), color, Enum.Material.Metal)
	part("Link", Vector3.new(t, h, t), cf * CFrame.new(-w / 2 + t / 2, 0, 0), color, Enum.Material.Metal)
end
-- an iron band round the shaft at height y with rivets
local function band(y, d, w, rivets)
	cyl("Band", Vector3.new(0, y - w / 2, 0), Vector3.new(0, y + w / 2, 0), d, IRON, Enum.Material.Metal)
	for i = 1, rivets do
		local a = (i - 0.5) / rivets * math.pi * 2
		ball("Rivet", Vector3.new(math.cos(a) * d / 2, y, math.sin(a) * d / 2), 0.07, RUST, Enum.Material.Metal)
	end
end

-- ====================================================================
-- Shaft: crooked segments with knots, bark ridges and broken branch stubs
-- ====================================================================
local shaft = {
	Vector3.new(0, -2.1, 0), Vector3.new(0.03, -1.2, 0.02), Vector3.new(-0.02, -0.35, 0), Vector3.new(0, 0.55, 0),
	Vector3.new(0.04, 1.45, -0.03), Vector3.new(-0.03, 2.35, 0.02), Vector3.new(0.02, 3.25, 0), Vector3.new(0, 4.15, 0),
}
for i = 1, #shaft - 1 do
	local a, b = shaft[i], shaft[i + 1]
	cyl("Shaft", a, b, i % 2 == 0 and 0.31 or 0.34, WOOD, Enum.Material.Wood)
	-- a bark ridge running along the segment
	local ang = i * 2.1
	local off = Vector3.new(math.cos(ang) * 0.14, 0, math.sin(ang) * 0.14)
	cyl("Bark", a + off + Vector3.new(0, 0.12, 0), b + off - Vector3.new(0, 0.12, 0), 0.07, WOOD_DARK, Enum.Material.Wood)
end
for _, k in { { 2, 0.4, 0.5 }, { 5, 0.42, 2.3 }, { 6, 0.38, 4.2 } } do
	local p = shaft[k[1]]
	ball("Knot", p + Vector3.new(math.cos(k[3]) * 0.08, 0, math.sin(k[3]) * 0.08), k[2], WOOD_KNOT, Enum.Material.Wood)
end
-- broken branch stubs
cyl("Stub", Vector3.new(0.1, 1.85, 0), Vector3.new(0.38, 2.12, 0.06), 0.13, WOOD, Enum.Material.Wood)
ball("StubEnd", Vector3.new(0.38, 2.12, 0.06), 0.13, WOOD_KNOT, Enum.Material.Wood)
cyl("Stub", Vector3.new(-0.08, 2.8, 0.05), Vector3.new(-0.3, 3.0, 0.22), 0.11, WOOD, Enum.Material.Wood)
ball("StubEnd", Vector3.new(-0.3, 3.0, 0.22), 0.11, WOOD_KNOT, Enum.Material.Wood)

-- ====================================================================
-- Foot: iron ferrule and spike
-- ====================================================================
cyl("Ferrule", Vector3.new(0, -2.1, 0), Vector3.new(0, -1.72, 0), 0.38, IRON, Enum.Material.Metal)
cyl("FerruleRing", Vector3.new(0, -1.76, 0), Vector3.new(0, -1.68, 0), 0.43, IRON_DARK, Enum.Material.Metal)
cyl("FerruleRing", Vector3.new(0, -2.04, 0), Vector3.new(0, -1.98, 0), 0.42, IRON_DARK, Enum.Material.Metal)
cyl("Spike", Vector3.new(0, -2.22, 0), Vector3.new(0, -2.1, 0), 0.26, IRON_DARK, Enum.Material.Metal)
cyl("Spike", Vector3.new(0, -2.32, 0), Vector3.new(0, -2.22, 0), 0.15, IRON_DARK, Enum.Material.Metal)
for i = 1, 4 do
	local a = i * math.pi / 2 + math.pi / 4
	ball("Rivet", Vector3.new(math.cos(a) * 0.19, -1.9, math.sin(a) * 0.19), 0.07, RUST, Enum.Material.Metal)
end

-- ====================================================================
-- Grip: wound leather with a dangling strap and a bone bead tassel
-- ====================================================================
for i = 0, 8 do
	local y = -0.45 + i * 0.125
	local tilt = (i % 2 == 0) and 7 or -7
	part("Wrap", Vector3.new(0.11, 0.37, 0.37),
		CFrame.new(0, y, 0) * CFrame.Angles(0, 0, math.rad(90 + tilt)), i % 2 == 0 and LEATHER or LEATHER_DARK,
		Enum.Material.Fabric, Enum.PartType.Cylinder)
end
band(-0.56, 0.41, 0.08, 4)
band(0.66, 0.41, 0.08, 4)
part("Strap", Vector3.new(0.09, 0.55, 0.03), CFrame.new(0.2, -0.78, -0.05) * CFrame.Angles(0, 0, math.rad(-12)), LEATHER, Enum.Material.Fabric)
part("Strap", Vector3.new(0.08, 0.45, 0.03), CFrame.new(0.3, -1.25, -0.05) * CFrame.Angles(0, 0, math.rad(6)), LEATHER_DARK, Enum.Material.Fabric)
ball("Bead", Vector3.new(0.33, -1.5, -0.05), 0.12, BONE, Enum.Material.SmoothPlastic)
for i = -1, 1 do
	part("Tassel", Vector3.new(0.03, 0.26, 0.03), CFrame.new(0.33 + i * 0.035, -1.68, -0.05) * CFrame.Angles(0, 0, math.rad(i * 12)), LEATHER_DARK, Enum.Material.Fabric)
end

-- ====================================================================
-- Iron bands with soul runes
-- ====================================================================
band(1.5, 0.4, 0.14, 5)
band(2.6, 0.42, 0.18, 6)
band(3.65, 0.4, 0.14, 5)
for i = -1, 1 do
	part("Rune", Vector3.new(0.05, 0.11, 0.02), CFrame.new(i * 0.09, 2.6, -0.215) * CFrame.Angles(0, 0, math.rad(i * 25)), SOUL, Enum.Material.Neon)
end
-- runes carved into the wood above the middle band
for i, y in { 1.95, 2.12, 2.28 } do
	part("Rune", Vector3.new(0.04, 0.09, 0.02), CFrame.new((i - 2) * 0.03, y, -0.17) * CFrame.Angles(0, 0, math.rad(i * 30)), SOUL, Enum.Material.Neon)
end

-- ====================================================================
-- The crook: the shaft curls forward and down at the top
-- ====================================================================
local C, R = Vector3.new(0, 4.15, -0.62), 0.62
local hook = {}
for i = 0, 9 do
	local t = math.rad(i * 25)
	table.insert(hook, C + Vector3.new(0, math.sin(t) * R, math.cos(t) * R))
end
for i = 1, #hook - 1 do
	local d = 0.31 - i * 0.012
	cyl("Hook", hook[i], hook[i + 1], d, WOOD, Enum.Material.Wood)
	ball("HookJoint", hook[i + 1], d, WOOD, Enum.Material.Wood)
end
local hookEnd = hook[#hook]
cyl("HookCap", hookEnd + Vector3.new(0, 0.06, 0), hookEnd - Vector3.new(0, 0.1, 0), 0.24, IRON, Enum.Material.Metal)
ball("HookCapRivet", hookEnd - Vector3.new(0, 0.1, 0), 0.12, IRON_DARK, Enum.Material.Metal)
-- an iron spiral ornament inside the curl
for i = 0, 5 do
	local t = math.rad(60 + i * 40)
	local r = 0.32 - i * 0.04
	ball("Filigree", C + Vector3.new(0, math.sin(t) * r, math.cos(t) * r), 0.07, IRON, Enum.Material.Metal)
end
-- moss on the crook
for _, m in { { 2, 0.2 }, { 4, 0.18 }, { 6, 0.15 } } do
	part("Moss", Vector3.new(m[2], 0.06, m[2] * 0.8), CFrame.new(hook[m[1]] + Vector3.new(0.04, 0.15, 0)) * CFrame.Angles(0, m[1], 0), MOSS, Enum.Material.Grass)
end
part("Moss", Vector3.new(0.22, 0.05, 0.16), CFrame.new(0.05, 3.74, -0.12), MOSS, Enum.Material.Grass)

-- ====================================================================
-- Rags and the skull charm under the hook
-- ====================================================================
ball("RagKnot", Vector3.new(0, 3.9, 0.17), 0.18, CLOTH, Enum.Material.Fabric)
for i, r in { { -0.08, 0.7, -8, CLOTH }, { 0.04, 0.9, 5, Color3.fromRGB(58, 54, 62) }, { 0.12, 0.55, 14, MOSS } } do
	local x, len, ang, col = r[1], r[2], r[3], r[4]
	local cf = CFrame.new(x, 3.88 - len / 2, 0.22 + i * 0.015) * CFrame.Angles(0, 0, math.rad(ang))
	part("Rag", Vector3.new(0.12, len, 0.02), cf, col, Enum.Material.Fabric)
	wedge("RagTip", Vector3.new(0.02, 0.14, 0.12), cf * CFrame.new(0, -len / 2 - 0.07, 0) * CFrame.Angles(0, math.rad(90), math.rad(180)), col, Enum.Material.Fabric)
end
-- the skull charm hangs at the outer side (+X) from the top band
part("Cord", Vector3.new(0.03, 0.42, 0.03), CFrame.new(0.24, 3.42, 0), LEATHER_DARK, Enum.Material.Fabric)
local skull = CFrame.new(0.27, 3.1, 0) * CFrame.Angles(0, math.rad(-90), 0) -- faces +X
ball("Skull", (skull * CFrame.new(0, 0.03, 0)).Position, 0.26, BONE)
part("SkullFace", Vector3.new(0.2, 0.13, 0.1), skull * CFrame.new(0, -0.06, -0.08), BONE)
part("SkullJaw", Vector3.new(0.15, 0.06, 0.12), skull * CFrame.new(0, -0.15, -0.06), BONE)
ball("Eye", (skull * CFrame.new(-0.055, 0.0, -0.11)).Position, 0.075, SOCKET)
ball("Eye", (skull * CFrame.new(0.055, 0.0, -0.11)).Position, 0.075, SOCKET)
part("Nose", Vector3.new(0.03, 0.04, 0.02), skull * CFrame.new(0, -0.07, -0.135), SOCKET)

-- ====================================================================
-- Chain and lantern
-- ====================================================================
local lx, lz = hookEnd.X, hookEnd.Z
for i = 0, 2 do
	local y = hookEnd.Y - 0.2 - i * 0.15
	link(CFrame.new(lx, y, lz) * CFrame.Angles(0, i % 2 == 0 and 0 or math.rad(90), 0), 0.12, 0.2, 0.035, IRON_DARK)
end
local top = hookEnd.Y - 0.62 -- top of the lantern's handle ring
local L = CFrame.new(lx, top - 0.85, lz) -- centre of the lantern body
-- handle ring and finial
link(L * CFrame.new(0, 0.82, 0), 0.22, 0.2, 0.04, IRON)
ball("Finial", (L * CFrame.new(0, 0.7, 0)).Position, 0.14, IRON, Enum.Material.Metal)
-- roof: stepped plates and four sloped sides
part("RoofPlate", Vector3.new(0.76, 0.06, 0.76), L * CFrame.new(0, 0.38, 0), IRON_DARK, Enum.Material.Metal)
for i = 0, 3 do
	wedge("Roof", Vector3.new(0.7, 0.24, 0.35), L * CFrame.Angles(0, i * math.pi / 2, 0) * CFrame.new(0, 0.53, -0.175), IRON, Enum.Material.Metal)
	-- corner spikes
	local a = i * math.pi / 2 + math.pi / 4
	local c = L * CFrame.new(math.cos(a) * 0.48, 0.42, math.sin(a) * 0.48)
	cyl("RoofSpike", c.Position, c.Position + Vector3.new(math.cos(a) * 0.08, 0.16, math.sin(a) * 0.08), 0.05, IRON_DARK, Enum.Material.Metal)
end
part("RoofCap", Vector3.new(0.2, 0.08, 0.2), L * CFrame.new(0, 0.63, 0), IRON_DARK, Enum.Material.Metal)
-- body: corner posts, top and bottom frames, glass panes with bars
for i = 0, 3 do
	local a = i * math.pi / 2 + math.pi / 4
	local x, z = math.cos(a) * 0.43, math.sin(a) * 0.43
	cyl("Post", (L * CFrame.new(x, -0.37, z)).Position, (L * CFrame.new(x, 0.37, z)).Position, 0.08, IRON, Enum.Material.Metal)
	ball("Foot", (L * CFrame.new(x * 1.12, -0.46, z * 1.12)).Position, 0.1, IRON_DARK, Enum.Material.Metal)
end
part("TopFrame", Vector3.new(0.7, 0.06, 0.7), L * CFrame.new(0, 0.33, 0), IRON, Enum.Material.Metal)
part("BottomFrame", Vector3.new(0.74, 0.08, 0.74), L * CFrame.new(0, -0.38, 0), IRON, Enum.Material.Metal)
part("Base", Vector3.new(0.58, 0.07, 0.58), L * CFrame.new(0, -0.45, 0), IRON_DARK, Enum.Material.Metal)
cyl("BottomSpike", (L * CFrame.new(0, -0.48, 0)).Position, (L * CFrame.new(0, -0.62, 0)).Position, 0.12, IRON_DARK, Enum.Material.Metal)
ball("BottomBall", (L * CFrame.new(0, -0.66, 0)).Position, 0.1, IRON, Enum.Material.Metal)
for i = 0, 3 do
	local face = L * CFrame.Angles(0, i * math.pi / 2, 0) * CFrame.new(0, 0, -0.3)
	local pane = part("Glass", Vector3.new(0.56, 0.66, 0.02), face, GLASS, Enum.Material.Glass)
	pane.Transparency = 0.55
	part("Bar", Vector3.new(0.035, 0.66, 0.035), face * CFrame.new(0, 0, -0.02), IRON_DARK, Enum.Material.Metal)
	part("Bar", Vector3.new(0.56, 0.035, 0.035), face * CFrame.new(0, 0.05, -0.02), IRON_DARK, Enum.Material.Metal)
	-- a gothic point over each pane
	wedge("Arch", Vector3.new(0.02, 0.1, 0.14), face * CFrame.new(-0.07, 0.25, -0.02) * CFrame.Angles(0, math.rad(90), 0), IRON_DARK, Enum.Material.Metal)
	wedge("Arch", Vector3.new(0.02, 0.1, 0.14), face * CFrame.new(0.07, 0.25, -0.02) * CFrame.Angles(0, math.rad(-90), 0), IRON_DARK, Enum.Material.Metal)
end
-- inside: a bone candle with wax drips and the soul flame
cyl("Candle", (L * CFrame.new(0, -0.34, 0)).Position, (L * CFrame.new(0, -0.08, 0)).Position, 0.17, BONE)
ball("Drip", (L * CFrame.new(0.07, -0.12, 0.04)).Position, 0.06, BONE)
ball("Drip", (L * CFrame.new(-0.06, -0.2, -0.05)).Position, 0.05, BONE)
local flame = ball("Flame", (L * CFrame.new(0, 0.04, 0)).Position, 0.2, SOUL, Enum.Material.Neon)
flame.Transparency = 0.15
ball("FlameTip", (L * CFrame.new(0, 0.16, 0)).Position, 0.11, Color3.fromRGB(190, 255, 220), Enum.Material.Neon)
local light = Instance.new("PointLight")
light.Color = SOUL
light.Range = 9
light.Brightness = 1.3
light.Shadows = false
light.Parent = flame
local motes = Instance.new("ParticleEmitter")
motes.Name = "SoulMotes"
motes.Color = ColorSequence.new(SOUL)
motes.LightEmission = 1
motes.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.07), NumberSequenceKeypoint.new(1, 0) })
motes.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
motes.Lifetime = NumberRange.new(1, 1.6)
motes.Rate = 5
motes.Speed = NumberRange.new(0.3, 0.6)
motes.SpreadAngle = Vector2.new(25, 25)
motes.Parent = flame

-- ====================================================================
-- Finish: turn the staff frame into the grip frame, handle, welds
-- ====================================================================
local TO_GRIP = CFrame.Angles(math.rad(90), 0, 0) -- staff +Y -> grip +Z (up the arm), staff -Z -> grip +Y (forward)
for _, p in acc:GetChildren() do
	if p:IsA("BasePart") then
		p.CFrame = TO_GRIP * p.CFrame
	end
end
local handle = part("Handle", Vector3.new(0.2, 0.2, 0.2), CFrame.new(), IRON)
handle.Transparency = 1
local att = Instance.new("Attachment")
att.Name = "RightGripAttachment"
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
return "LanternStaff built, " .. count .. " parts"
