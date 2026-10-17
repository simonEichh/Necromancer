-- Builds Orvoss's anchor and one chain link (docs/orvoss.md, the finisher The Last Broadside and the arrival idea:
-- an anchor lands beside the gate / the grave, its chain pulls taut, the fleet drags the gate away) into
-- ReplicatedStorage.ShipModels.BlackwakeAnchor and ReplicatedStorage.ShipModels.BlackwakeChainLink. Run in Edit mode
-- (Studio MCP execute_luau or loadstring from the tools/studio http server). Seeded random: a rebuild gives the same
-- models. Safe to re-run (replaces both).
--
-- The anchor: a drowned admiralty anchor, ~24 studs from ring to crown. A tapered iron shank, the ring at the top, a
-- wooden stock bound in iron bands across it (square to the arms), two curved arms ending in spade flukes with pointed
-- bills; barnacles, hanging weed, verdigris, a few soul-light cracks and a soul glow round the ring (it is a ghost
-- fleet's anchor). Contract: origin = the ring's centre (it hangs from there), up +Y, arms along X, stock along Z.
-- Root part "Root" (anchored PrimaryPart, invisible), everything welded to it. Attachments on Root: "Ring" (where the
-- chain meets it), "Crown" (the bottom, where it strikes the ground). Attribute Height (ring to crown tip).
--
-- The chain link: one oval iron link, long axis +Y, centred on its Root. Lay a chain by stepping `Pitch` studs (model
-- attribute) along the chain and turning every other link 90 degrees about Y. ScaleTo both together for bigger chains.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local shipFolder = ReplicatedStorage:FindFirstChild("ShipModels")
if not shipFolder then
	shipFolder = Instance.new("Folder")
	shipFolder.Name = "ShipModels"
	shipFolder.Parent = ReplicatedStorage
end
for _, n in ipairs({ "BlackwakeAnchor", "BlackwakeChainLink" }) do
	local old = shipFolder:FindFirstChild(n)
	if old then
		old:Destroy()
	end
end

local WOOD = Enum.Material.Wood
local SMOOTH = Enum.Material.SmoothPlastic
local NEON = Enum.Material.Neon
local METAL = Enum.Material.Metal
local FABRIC = Enum.Material.Fabric

local IRON = Color3.fromRGB(42, 48, 48)
local IRON_DARK = Color3.fromRGB(28, 32, 32)
local VERDIGRIS = Color3.fromRGB(50, 90, 77)
local TIMBER_DARK = Color3.fromRGB(24, 26, 25)
local BARNACLE = Color3.fromRGB(100, 97, 83)
local WEED = Color3.fromRGB(26, 52, 40)
local SOUL = Color3.fromRGB(40, 225, 165)

local rng = Random.new(83)

local function newModel(name)
	local model = Instance.new("Model")
	model.Name = name
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(1, 1, 1)
	root.CFrame = CFrame.new()
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	root.Parent = model
	model.PrimaryPart = root
	local function part(name, size, cf, color, material, opts)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = Vector3.new(math.max(size.X, 0.1), math.max(size.Y, 0.1), math.max(size.Z, 0.1))
		p.CFrame = cf
		p.Color = color
		p.Material = material or METAL
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Massless = true
		p.Anchored = false
		if opts then
			if opts.shape then
				p.Shape = opts.shape
			end
			if opts.transparency then
				p.Transparency = opts.transparency
			end
			if opts.noShadow then
				p.CastShadow = false
			end
		end
		local w = Instance.new("WeldConstraint")
		w.Part0 = root
		w.Part1 = p
		w.Parent = p
		p.Parent = model
		return p
	end
	local function bar(name, a, b, w, h, color, material, opts)
		local dir = b - a
		local up = math.abs(dir.Unit.Y) > 0.98 and Vector3.new(0, 0, 1) or Vector3.new(0, 1, 0)
		return part(name, Vector3.new(w, h or w, dir.Magnitude), CFrame.lookAt((a + b) / 2, b, up), color, material, opts)
	end
	local function ball(name, c, d, color, material, opts)
		opts = opts or {}
		opts.shape = Enum.PartType.Ball
		return part(name, Vector3.new(d, d, d), CFrame.new(c), color, material, opts)
	end
	-- a ring of `n` short bars round `c` in the plane with normal `axis` (radius r, bar thickness t)
	local function ring(name, c, axis, r, t, n, color, material, opts)
		local a0 = axis:Cross(Vector3.yAxis)
		if a0.Magnitude < 0.01 then
			a0 = axis:Cross(Vector3.xAxis)
		end
		a0 = a0.Unit
		local b0 = axis:Cross(a0).Unit
		local pts = {}
		for k = 0, n - 1 do
			local th = k / n * math.pi * 2
			pts[k] = c + (a0 * math.cos(th) + b0 * math.sin(th)) * r
		end
		for k = 0, n - 1 do
			local a, b = pts[k], pts[(k + 1) % n]
			-- (a little longer than the chord, so the joints close)
			local dir = (b - a).Unit
			bar(name, a - dir * t * 0.3, b + dir * t * 0.3, t, t, color, material, opts)
		end
	end
	return model, root, part, bar, ball, ring
end

-- ====================================================================
-- The anchor
-- ====================================================================
local anchor, aRoot, part, bar, ball, ring = newModel("BlackwakeAnchor")
local H = 22 -- ring centre down to the crown's centre
local crownY = -H
-- the ring (and the soul glow round it)
ring("Ring", Vector3.zero, Vector3.zAxis, 2.2, 0.8, 12, IRON, METAL)
ring("RingGlow", Vector3.zero, Vector3.zAxis, 2.2, 0.95, 12, SOUL, NEON, { transparency = 0.88, noShadow = true })
-- the shank: thick at the crown, tapering towards the ring; a square boss where the stock passes through
bar("ShankTop", Vector3.new(0, -1.6, 0), Vector3.new(0, -10, 0), 1.5, 1.5, IRON, METAL)
bar("ShankLow", Vector3.new(0, -9.6, 0), Vector3.new(0, crownY + 1, 0), 2, 2, IRON, METAL)
part("ShankEye", Vector3.new(2.2, 2.4, 2.2), CFrame.new(0, -1.8, 0), IRON_DARK, METAL)
-- the stock: a wooden beam square to the arms, tapering out to both ends, iron bands round it
local stockY = -4.2
part("Stock", Vector3.new(1.9, 2.1, 6.5), CFrame.new(0, stockY, 0), TIMBER_DARK, WOOD)
for _, sz in ipairs({ -1, 1 }) do
	bar("StockArm", Vector3.new(0, stockY, sz * 3), Vector3.new(0, stockY - 0.3, sz * 8.2), 1.6, 1.7, TIMBER_DARK, WOOD)
	bar("StockTip", Vector3.new(0, stockY - 0.3, sz * 8), Vector3.new(0, stockY - 0.45, sz * 9.4), 1.2, 1.3, TIMBER_DARK, WOOD)
	for _, bz in ipairs({ 2.6, 5.4, 8.4 }) do
		part("StockBand", Vector3.new(2.1 - bz * 0.06, 2.3 - bz * 0.06, 0.45), CFrame.new(0, stockY - bz * 0.04, sz * bz), IRON_DARK, METAL)
	end
end
-- the crown and the two arms curving up and out to the flukes
part("Crown", Vector3.new(3.2, 2.4, 2.4), CFrame.new(0, crownY + 0.4, 0), IRON, METAL)
local tipPos = Vector3.new(0, crownY - 1.6, 0)
part("CrownTip", Vector3.new(1.6, 1.6, 1.6), CFrame.new(0, crownY - 0.9, 0) * CFrame.Angles(0, 0, math.rad(45)), IRON_DARK, METAL)
for _, sx in ipairs({ -1, 1 }) do
	-- the arm's curve: an arc centred above the crown, out and up to the fluke
	local pts = {}
	for k = 0, 4 do
		local phi = math.rad(k * 17)
		pts[k] = Vector3.new(sx * 8 * math.sin(phi), crownY + 8 - 8 * math.cos(phi) + 0.6, 0)
	end
	for k = 0, 3 do
		local w = 1.9 - k * 0.22
		bar("Arm", pts[k], pts[k + 1], w, w * 1.1, IRON, METAL)
	end
	-- the fluke: a spade plate on the arm's end, facing out and up; a pointed bill beyond it
	local tip = pts[4]
	local dir = (pts[4] - pts[3]).Unit
	local flukeC = tip - dir * 1.2
	local fcf = CFrame.lookAt(flukeC, flukeC + dir) -- (-Z along the arm)
	-- (the plate spreads across the arms' plane, +-Z, and along the arm; thin in the arms' plane)
	part("Fluke", Vector3.new(4.2, 0.7, 4.6), fcf, IRON, METAL)
	part("FlukeEdge", Vector3.new(3.2, 0.6, 1.2), fcf * CFrame.new(0, 0, -2.6), IRON_DARK, METAL)
	bar("Bill", tip, tip + dir * 2.6, 0.9, 0.9, IRON_DARK, METAL)
end
-- drowned: verdigris patches, barnacles, weed hanging off the stock and the arms, soul-light cracks
for _ = 1, 8 do
	local y = rng:NextNumber(crownY + 2, -6)
	local face = rng:NextInteger(0, 3)
	local off = ({ Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(0, 0, -1) })[face + 1]
	part("Verdigris", Vector3.new(off.X ~= 0 and 0.2 or rng:NextNumber(0.8, 1.6), rng:NextNumber(1, 2.6), off.Z ~= 0 and 0.2 or rng:NextNumber(0.8, 1.6)),
		CFrame.new(off * (y < -9.6 and 1.02 or 0.77) + Vector3.new(0, y, 0)), VERDIGRIS, SMOOTH, { noShadow = true })
end
for _ = 1, 16 do
	local onArm = rng:NextNumber() < 0.5
	local p
	if onArm then
		local sx = rng:NextNumber() < 0.5 and -1 or 1
		local phi = math.rad(rng:NextNumber(5, 60))
		p = Vector3.new(sx * 8 * math.sin(phi), crownY + 8 - 8 * math.cos(phi) + 0.6, rng:NextNumber(-0.9, 0.9))
			+ Vector3.new(0, -0.8, 0)
	else
		local y = rng:NextNumber(crownY + 1, -11)
		local a = rng:NextNumber(0, math.pi * 2)
		p = Vector3.new(math.cos(a) * 1.05, y, math.sin(a) * 1.05)
	end
	ball("Barnacle", p, rng:NextNumber(0.5, 1), BARNACLE, SMOOTH, { noShadow = true })
end
for _ = 1, 9 do
	local onStock = rng:NextNumber() < 0.6
	local top = onStock and Vector3.new(rng:NextNumber(-0.8, 0.8), stockY - 1, rng:NextNumber(-8.5, 8.5))
		or Vector3.new((rng:NextNumber() < 0.5 and -1 or 1) * rng:NextNumber(3, 7), crownY + 2.5, rng:NextNumber(-0.6, 0.6))
	local len = rng:NextNumber(2.5, 6)
	part("Weed", Vector3.new(0.25, len, rng:NextNumber(0.5, 1.1)), CFrame.new(top - Vector3.new(0, len / 2, 0)) * CFrame.Angles(0, rng:NextNumber(0, 3), rng:NextNumber(-0.12, 0.12)), WEED, FABRIC, { noShadow = true })
end
for _ = 1, 4 do
	local y = rng:NextNumber(crownY + 3, -7)
	local a = rng:NextInteger(0, 3) * math.pi / 2
	part("SoulCrack", Vector3.new(0.25, rng:NextNumber(1.5, 3.2), 0.25), CFrame.new(math.cos(a) * 1.02, y, math.sin(a) * 1.02) * CFrame.Angles(0, -a, rng:NextNumber(-0.4, 0.4)), SOUL, NEON, { noShadow = true })
end
local att = Instance.new("Attachment")
att.Name = "Ring"
att.CFrame = CFrame.new(0, 1.8, 0)
att.Parent = aRoot
local crownAtt = Instance.new("Attachment")
crownAtt.Name = "Crown"
crownAtt.CFrame = CFrame.new(tipPos)
crownAtt.Parent = aRoot
anchor:SetAttribute("Height", 1.8 + H + 1.6)
anchor.Parent = shipFolder

-- ====================================================================
-- One chain link (oval, long axis +Y)
-- ====================================================================
local link, _, lpart, lbar = newModel("BlackwakeChainLink")
local LEN, WID, T = 3.4, 2, 0.6
for _, sx in ipairs({ -1, 1 }) do
	lbar("Side", Vector3.new(sx * WID / 2, -LEN / 2 + WID / 2, 0), Vector3.new(sx * WID / 2, LEN / 2 - WID / 2, 0), T, T, IRON, METAL)
end
for _, sy in ipairs({ -1, 1 }) do
	local c = Vector3.new(0, sy * (LEN / 2 - WID / 2), 0)
	local pts = {}
	for k = 0, 4 do
		local th = k / 4 * math.pi
		pts[k] = c + Vector3.new(math.cos(th) * WID / 2, sy * math.sin(th) * WID / 2, 0)
	end
	for k = 0, 3 do
		local dir = (pts[k + 1] - pts[k]).Unit
		lbar("End", pts[k] - dir * 0.15, pts[k + 1] + dir * 0.15, T, T, IRON, METAL)
	end
end
lpart("Rust", Vector3.new(0.2, 0.9, T * 1.05), CFrame.new(WID / 2, 0.2, 0), VERDIGRIS, SMOOTH, { noShadow = true })
link:SetAttribute("Pitch", LEN - T * 1.4) -- (each link reaches into the next)
link.Parent = shipFolder

local function count(m)
	local n = 0
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			n += 1
		end
	end
	return n
end
return ("BlackwakeAnchor %d parts (height %.1f), BlackwakeChainLink %d parts (pitch %.2f)"):format(count(anchor), anchor:GetAttribute("Height"), count(link), link:GetAttribute("Pitch"))
