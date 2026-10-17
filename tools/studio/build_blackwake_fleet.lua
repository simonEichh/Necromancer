-- Builds the Blackwake's drowned fleet (docs/orvoss.md, "Agreed finisher concept: The Last Broadside") into
-- ReplicatedStorage.ShipModels.BlackwakeFleet: five warship variants and the FLAGSHIP from ONE builder. Run in Edit mode (Studio MCP execute_luau or loadstring from the tools/studio http server).
-- Seeded random: a rebuild gives the same ships. Safe to re-run (replaces the folder).
--
-- The look: ghost galleons that sank with Orvoss. Dark wet timber, greener and barnacled below, a tumblehome hull
-- with raised castles fore and aft; the broadside carries one to three gun decks (ports glowing sea-green from inside,
-- lids hinged up, barrels run out) because the finisher shows the ships SIDE-ON. Breaches in the hull are held together
-- by ghost light (soul-green ribs over a glowing inside); thin glowing cracks elsewhere. Torn translucent sails on
-- three-section masts (some snapped), shrouds, a skull figurehead under the bowsprit, a lit stern gallery and lanterns.
--
-- Contract (for the finisher): front = -Z (bow), up = +Y, side = +/-X, origin = the waterline amidships. Root part
-- "Root" (anchored PrimaryPart, invisible); everything else is welded to it (move the ship by moving Root).
--   * gun ports: parts "PortGlow" (Neon, attributes Deck 1.., Index 1.. bow to stern, Side -1/1) - light them bow to
--     stern for a rolling broadside; their barrels "Gun" carry an Attachment "Muzzle" (LookVector out of the bore)
--   * the bow: Attachment "Hawse" on Root (where an anchor chain leaves the ship); the stern lantern has a PointLight
--   * model attributes: Length, Variant, GunDecks, PortsPerSide
--
-- The flagship (Orvoss's own ship, `flagship = true`): ~1.5x the Man-o'-War, three tall gun decks of bigger ports, a
-- drowned copper bottom gone verdigris, a soul-light seam along the waterline holding the whole hull together, Orvoss
-- himself as the figurehead (tricorn, cutlass thrust forward), a great black main course with a bone skull-and-anchor,
-- a three-row stern gallery, two anchors hanging from catheads on chains, lanterns along the rails. Extra contract:
-- Attachment "Bridge" on Root (where Orvoss stands on the quarterdeck, facing the bow), "HawseL" / "HawseR".
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local shipFolder = ReplicatedStorage:FindFirstChild("ShipModels")
if not shipFolder then
	shipFolder = Instance.new("Folder")
	shipFolder.Name = "ShipModels"
	shipFolder.Parent = ReplicatedStorage
end
local old = shipFolder:FindFirstChild("BlackwakeFleet")
if old then
	old:Destroy()
end
local fleet = Instance.new("Folder")
fleet.Name = "BlackwakeFleet"

local WOOD = Enum.Material.Wood
local SMOOTH = Enum.Material.SmoothPlastic
local NEON = Enum.Material.Neon
local METAL = Enum.Material.Metal
local FABRIC = Enum.Material.Fabric

-- palette (Orvoss's: dark sea timber, verdigris, bone, soul green)
local TIMBER = Color3.fromRGB(46, 47, 43)
local TIMBER_DARK = Color3.fromRGB(24, 26, 25)
local TIMBER_GREEN = Color3.fromRGB(28, 42, 38)
local DECK = Color3.fromRGB(48, 46, 40)
local WALE = Color3.fromRGB(16, 18, 18)
local IRON = Color3.fromRGB(42, 48, 48)
local BRASS = Color3.fromRGB(137, 111, 64)
local BONE = Color3.fromRGB(184, 179, 151)
local VERDIGRIS = Color3.fromRGB(50, 90, 77)
local ROPE = Color3.fromRGB(30, 30, 27)
local SAIL = Color3.fromRGB(104, 132, 116)
local SAIL_DARK = Color3.fromRGB(76, 100, 88)
local BRASS_DARK = Color3.fromRGB(104, 86, 50)
local WEED = Color3.fromRGB(26, 52, 40)
local BARNACLE = Color3.fromRGB(100, 97, 83)
local SOUL = Color3.fromRGB(40, 225, 165)
local SOUL_CORE = Color3.fromRGB(200, 255, 232)
local SOUL_DEEP = Color3.fromRGB(26, 140, 104)
local PORT_GLOW = Color3.fromRGB(34, 190, 140)
local BONE_OLD = Color3.fromRGB(142, 136, 110)
local COPPER_GREEN = Color3.fromRGB(58, 104, 88)
local SAIL_BLACK = Color3.fromRGB(20, 22, 22)

local function smooth(a, b, x)
	local k = math.clamp((x - a) / (b - a), 0, 1)
	return k * k * (3 - 2 * k)
end

-- ====================================================================
-- The variants
-- ====================================================================
-- L length, B half-beam, H rail height at the waist (above the waterline), D keel depth, sheer (extra height at the
-- ends), fore / stern castle heights, decks (gun decks), masts { s (-1 bow .. 1 stern), height share of L, broken
-- share of its height or nil }, breaches { s, v (0 keel .. 1 rail), rs, rv, side }, tear (share of sail strips lost)
local VARIANTS = {
	{ name = "Frigate", seed = 11, L = 150, B = 16, H = 15, D = 12, sheer = 3, fore = 5, stern = 9, decks = 2,
		masts = { { -0.5, 0.62 }, { -0.04, 0.72 }, { 0.44, 0.52 } },
		breaches = { { 0.18, 0.42, 0.12, 0.2, 1 } }, tear = 0.25 },
	{ name = "ManOWar", seed = 23, L = 195, B = 21, H = 22, D = 15, sheer = 4, fore = 6, stern = 12, decks = 3,
		masts = { { -0.5, 0.6 }, { -0.04, 0.7 }, { 0.44, 0.5 } },
		breaches = { { -0.3, 0.35, 0.1, 0.22, -1 }, { 0.3, 0.55, 0.08, 0.18, 1 } }, tear = 0.3 },
	{ name = "Galleon", seed = 37, L = 175, B = 20, H = 17, D = 14, sheer = 5, fore = 7, stern = 17, decks = 2,
		masts = { { -0.52, 0.6 }, { -0.06, 0.7 }, { 0.42, 0.5, 0.45 } },
		breaches = { { 0.05, 0.3, 0.12, 0.2, -1 } }, tear = 0.35 },
	{ name = "Wreck", seed = 41, L = 165, B = 18, H = 16, D = 13, sheer = 4, fore = 5, stern = 11, decks = 2,
		masts = { { -0.5, 0.6 }, { -0.04, 0.7, 0.4 }, { 0.44, 0.5 } },
		breaches = { { -0.45, 0.4, 0.1, 0.25, 1 }, { 0.12, 0.3, 0.14, 0.22, 1 }, { 0.25, 0.6, 0.1, 0.2, -1 } },
		tear = 0.6 },
	{ name = "Brig", seed = 53, L = 120, B = 13, H = 13, D = 10, sheer = 3, fore = 4, stern = 7, decks = 1,
		masts = { { -0.32, 0.68 }, { 0.22, 0.62 } },
		breaches = { { 0.0, 0.45, 0.12, 0.25, -1 } }, tear = 0.3 },
	-- Orvoss's own ship (portScale: bigger, wider spaced ports; yardScale: the yards' width against the length)
	{ name = "Flagship", seed = 71, L = 290, B = 30, H = 32, D = 20, sheer = 7, fore = 10, stern = 24, decks = 3,
		flagship = true, galleryRows = 3, portScale = 1.4, yardScale = 0.95,
		masts = { { -0.5, 0.56 }, { -0.04, 0.64 }, { 0.42, 0.47 } },
		breaches = { { 0.22, 0.3, 0.06, 0.14, -1 } }, tear = 0.12 },
}

-- ====================================================================
-- One ship
-- ====================================================================
local function buildShip(cfg)
	local rng = Random.new(cfg.seed)
	local L, B = cfg.L, cfg.B
	local model = Instance.new("Model")
	model.Name = cfg.name
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(2, 2, 2)
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
		p.Material = material or WOOD
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
	-- a box from a to b (w x h cross-section)
	local function bar(name, a, b, w, h, color, material, opts)
		local dir = b - a
		local up = math.abs(dir.Unit.Y) > 0.98 and Vector3.new(0, 0, 1) or Vector3.new(0, 1, 0)
		return part(name, Vector3.new(w, h or w, dir.Magnitude), CFrame.lookAt((a + b) / 2, b, up), color, material, opts)
	end
	-- a cylinder from a to b
	local function cyl(name, a, b, d, color, material, opts)
		local dir = b - a
		local cf = CFrame.lookAt((a + b) / 2, b, math.abs(dir.Unit.Y) > 0.98 and Vector3.new(0, 0, 1) or Vector3.new(0, 1, 0))
			* CFrame.Angles(0, math.pi / 2, 0)
		opts = opts or {}
		opts.shape = Enum.PartType.Cylinder
		return part(name, Vector3.new(dir.Magnitude, d, d), cf, color, material, opts)
	end
	local function ball(name, c, d, color, material, opts)
		opts = opts or {}
		opts.shape = Enum.PartType.Ball
		return part(name, Vector3.new(d, d, d), CFrame.new(c), color, material, opts)
	end

	-- ── the hull's shape: s = -1 bow .. 1 stern, v = 0 keel .. 1 rail
	local function halfBeam(s)
		local s0 = -0.05
		if s < s0 then
			local k = (s0 - s) / (1 + s0)
			return B * math.max(0, 1 - k ^ 1.5) ^ 0.75
		end
		local k = (s - s0) / (1 - s0)
		return B * (1 - 0.3 * k * k)
	end
	local function railY(s) -- the rail line: sheer plus the castles
		return cfg.H + cfg.sheer * s * s + cfg.fore * smooth(-0.6, -0.75, s) + cfg.stern * smooth(0.45, 0.62, s)
	end
	local function keelY(s)
		return -cfg.D * (1 - 0.75 * smooth(-0.7, -1, s) - 0.15 * smooth(0.8, 1, s))
	end
	local function widthAt(v) -- share of the half-beam at height v: rounded bilge, tumblehome above
		if v < 0.42 then
			return math.max(0.06, math.sin(v / 0.42 * math.pi / 2) ^ 0.7)
		end
		return 1 - 0.16 * ((v - 0.42) / 0.58) ^ 2
	end
	local function point(s, v, side)
		local yk, yt = keelY(s), railY(s)
		return Vector3.new(side * math.max(0.25, halfBeam(s) * widthAt(v)), yk + v * (yt - yk), s * L / 2)
	end
	local function vAtY(s, y)
		local yk, yt = keelY(s), railY(s)
		return (y - yk) / (yt - yk)
	end
	-- a frame on the hull surface: X out of the hull, Y up along it, Z along it
	local function surfaceFrame(s, v, side)
		local ds, dv = 0.01, 0.01
		local p = point(s, v, side)
		local a = point(s + ds, v, side) - point(s - ds, v, side)
		local b = point(s, v + dv, side) - point(s, v - dv, side)
		local z = a.Unit * side
		local y = (b - z * b:Dot(z)).Unit
		local x = y:Cross(z)
		return CFrame.fromMatrix(p, x, y, z)
	end

	-- breaches: inside an ellipse in (s, v) on one side
	local function breachAt(s, v, side)
		for _, br in ipairs(cfg.breaches) do
			if br[5] == side then
				local ds, dv = (s - br[1]) / br[3], (v - br[2]) / br[4]
				-- a ragged edge
				if ds * ds + dv * dv < 1 + 0.25 * math.sin(s * 37 + v * 23) then
					return true
				end
			end
		end
		return false
	end

	-- ── the planking: bands round the hull, segments denser at the bow
	local N = 16
	local SEG = {}
	for i = 0, N do
		SEG[i] = -1 + 2 * (i / N) ^ 1.25
	end
	local BANDS = { 0, 0.09, 0.2, 0.32, 0.44, 0.56, 0.68, 0.8, 0.9, 1 }
	local WALES = { [5] = true, [8] = true } -- dark heavy strakes
	for _, side in ipairs({ -1, 1 }) do
		for i = 0, N - 1 do
			local s0, s1 = SEG[i], SEG[i + 1]
			for j = 1, #BANDS - 1 do
				local v0, v1 = BANDS[j], BANDS[j + 1]
				local sm, vm = (s0 + s1) / 2, (v0 + v1) / 2
				local p00, p10 = point(s0, v0, side), point(s1, v0, side)
				local p01, p11 = point(s0, v1, side), point(s1, v1, side)
				local a = ((p10 + p11) - (p00 + p01)) / 2
				local b = ((p01 + p11) - (p00 + p10)) / 2
				local c = (p00 + p10 + p01 + p11) / 4
				local z = a.Unit * side
				local y = (b - z * b:Dot(z)).Unit
				local x = y:Cross(z)
				local cf = CFrame.fromMatrix(c, x, y, z)
				local size = Vector3.new(1.1, b.Magnitude + 0.5, a.Magnitude + 0.5)
				if breachAt(sm, vm, side) then
					-- the breach: the planks are gone; the inside glows and ribs of ghost light hold the hole together
					part("BreachGlow", size * Vector3.new(0.5, 1, 1), cf * CFrame.new(-1.6, 0, 0), SOUL_DEEP, NEON, { transparency = 0.15, noShadow = true })
					if (i + j) % 2 == 0 then
						part("SoulRib", Vector3.new(0.5, b.Magnitude + 0.9, 0.7), cf * CFrame.new(-0.2, 0, 0), SOUL, NEON, { noShadow = true })
					end
				else
					local col
					if WALES[j] then
						col = WALE
					elseif cfg.flagship and vm < 0.42 then
						col = COPPER_GREEN:Lerp(VERDIGRIS, rng:NextNumber(0, 0.6))
					elseif vm < 0.3 then
						col = TIMBER_GREEN:Lerp(TIMBER, rng:NextNumber(0, 0.35))
					else
						col = TIMBER:Lerp(TIMBER_DARK, rng:NextNumber(0, 0.45))
					end
					local p = part("Plank", size + (WALES[j] and Vector3.new(0.5, 0, 0) or Vector3.zero), cf, col,
						(cfg.flagship and vm < 0.42 and not WALES[j]) and METAL or WOOD)
					p:SetAttribute("Band", j)
				end
			end
		end
	end
	-- the keel and the stem (where the planking meets at the bow)
	for i = 0, N - 1 do
		local s0, s1 = SEG[i], SEG[i + 1]
		bar("Keel", Vector3.new(0, keelY(s0) - 0.6, s0 * L / 2), Vector3.new(0, keelY(s1) - 0.6, s1 * L / 2), 1.6, 2, TIMBER_DARK)
	end
	local stemTop = Vector3.new(0, railY(-1) + 2, -L / 2 - 1.5)
	bar("Stem", Vector3.new(0, keelY(-1), -L / 2), stemTop, 1.8, 1.8, TIMBER_DARK)
	if cfg.flagship then
		-- the soul seam: a line of ghost light along the top of the copper, bow to stern, both sides
		for _, side in ipairs({ -1, 1 }) do
			for i = 1, N - 1 do
				local a = (surfaceFrame(SEG[i], 0.42, side) * CFrame.new(0.75, 0, 0)).Position
				local b = (surfaceFrame(SEG[i + 1] - 0.001, 0.42, side) * CFrame.new(0.75, 0, 0)).Position
				bar("SoulSeam", a, b, 0.5, 0.5, SOUL, NEON, { noShadow = true })
			end
		end
	end

	-- ── the decks (one flat board per segment, under the rail) and the rail cap
	for i = 0, N - 1 do
		local s0, s1 = SEG[i], SEG[i + 1]
		local sm = (s0 + s1) / 2
		local dy = railY(sm) - 3
		local w = 2 * halfBeam(sm) * widthAt(vAtY(sm, dy)) - 1.4
		if w > 1 then
			part("Deck", Vector3.new(w, 1, (s1 - s0) * L / 2 + 0.3), CFrame.new(0, dy, sm * L / 2), DECK, WOOD)
		end
		for _, side in ipairs({ -1, 1 }) do
			bar("Rail", point(s0, 1, side) + Vector3.new(0, 0.4, 0), point(s1, 1, side) + Vector3.new(0, 0.4, 0), 1.6, 0.8, TIMBER_DARK)
			bar("RailTop", point(s0, 1, side) + Vector3.new(0, 2.6, 0), point(s1, 1, side) + Vector3.new(0, 2.6, 0), 0.6, 0.5, TIMBER_DARK)
			local post = point(s0, 1, side)
			cyl("RailPost", post + Vector3.new(0, 0.6, 0), post + Vector3.new(0, 2.8, 0), 0.7, BRASS_DARK, METAL)
			if cfg.flagship and i % 2 == 1 and i > 1 then
				part("RailLantern", Vector3.new(1, 1.5, 1), CFrame.new(post + Vector3.new(0, 3.7, 0)), SOUL, NEON, { noShadow = true })
				part("RailLanternCap", Vector3.new(1.4, 0.4, 1.4), CFrame.new(post + Vector3.new(0, 4.6, 0)), BRASS, METAL)
			end
		end
	end
	-- the step down from each castle to the waist: a bulkhead across the deck
	for _, sEdge in ipairs({ -0.62, 0.5 }) do
		local dy = railY(sEdge) - 3
		local w = 2 * halfBeam(sEdge) * widthAt(0.9) - 1
		part("Bulkhead", Vector3.new(w, (sEdge < 0 and cfg.fore or cfg.stern) + 1, 1), CFrame.new(0, cfg.H - 3 + (sEdge < 0 and cfg.fore or cfg.stern) / 2, sEdge * L / 2), TIMBER_DARK, WOOD)
	end

	-- ── the stern: a flat transom with the lit gallery, a rudder, the lanterns
	local sternZ = L / 2
	for j = 1, #BANDS - 1 do
		local v0, v1 = BANDS[j], BANDS[j + 1]
		local w = 2 * halfBeam(1) * widthAt((v0 + v1) / 2)
		local y0 = keelY(1) + v0 * (railY(1) - keelY(1))
		local y1 = keelY(1) + v1 * (railY(1) - keelY(1))
		part("Transom", Vector3.new(w + 0.8, y1 - y0 + 0.4, 1.2), CFrame.new(0, (y0 + y1) / 2, sternZ), j >= 7 and TIMBER_DARK or TIMBER, WOOD)
	end
	local galY = railY(1) - cfg.stern * 0.45
	local galW = 2 * halfBeam(1) * 0.8
	part("GalleryBeam", Vector3.new(galW + 2, 1.2, 3), CFrame.new(0, galY - 3.2, sternZ + 1), TIMBER_DARK, WOOD)
	part("GalleryRoof", Vector3.new(galW + 2, 1, 3), CFrame.new(0, galY + 3.4, sternZ + 1), TIMBER_DARK, WOOD)
	local panes = math.max(3, math.floor(galW / 4))
	for k = 1, panes do
		local x = -galW / 2 + (k - 0.5) * galW / panes
		part("GalleryWindow", Vector3.new(galW / panes - 1, 5, 0.6), CFrame.new(x, galY, sternZ + 0.7), k % 2 == 0 and SOUL or SOUL_DEEP, NEON, { noShadow = true })
	end
	part("Rudder", Vector3.new(1.6, cfg.D + 4, 6), CFrame.new(0, keelY(1) + (cfg.D + 4) / 2 - 1, sternZ + 3.2), TIMBER_DARK, WOOD)
	for _, side in ipairs({ -1, 1 }) do
		local sq = 0.84
		local qx = side * (halfBeam(sq) * widthAt(0.9) + 1.6)
		local qTop = railY(sq) + 1
		local qh = cfg.stern + 5
		local qw = L * 0.1
		local qz = sq * L / 2
		part("QuarterGallery", Vector3.new(3.2, qh, qw), CFrame.new(qx, qTop - qh / 2, qz), TIMBER_DARK, WOOD)
		part("QuarterBase", Vector3.new(4, 2, qw + 1), CFrame.new(qx, qTop - qh - 0.6, qz), TIMBER_DARK, WOOD)
		for tIdx = 0, (cfg.galleryRows or 2) do
			local ty = tIdx / (cfg.galleryRows or 2)
			part("QuarterTrim", Vector3.new(3.8, 0.6, qw + 0.8), CFrame.new(qx, qTop - qh * ty, qz), BRASS_DARK, METAL)
		end
		local rows = cfg.galleryRows or 2
		for row = 1, rows do
			for col = 1, 3 do
				local wz = qz + (col - 2) * qw * 0.3
				local wy = qTop - qh * (row - 0.5) / rows
				part("GalleryWindow", Vector3.new(0.5, qh * 0.48 / rows, qw * 0.13), CFrame.new(qx + side * 1.5, wy, wz), PORT_GLOW, NEON, { noShadow = true })
			end
		end
	end
	local emblem = Vector3.new(0, railY(1) - 1.5, sternZ + 1.2)
	ball("SternSkull", emblem, 3.4, BONE, SMOOTH)
	for _, sx in ipairs({ -1, 1 }) do
		part("SternSkullEye", Vector3.new(0.8, 0.7, 0.3), CFrame.new(emblem + Vector3.new(sx * 0.7, 0.2, 1.55)), SOUL, NEON, { noShadow = true })
	end
	for _, x in ipairs({ -0.85, 0, 0.85 }) do
		local big = x == 0
		local base = Vector3.new(x * galW / 2, railY(1) + 1, sternZ - 1)
		local postH = big and 7 or 5
		cyl("LanternPost", base, base + Vector3.new(0, postH, 0), 0.6, BRASS_DARK, METAL)
		local k = big and 1.3 or 1
		local lp = base + Vector3.new(0, postH + 1.6 * k, 0)
		part("LanternBase", Vector3.new(2.2 * k, 0.5, 2.2 * k), CFrame.new(lp - Vector3.new(0, 1.5 * k, 0)), BRASS, METAL)
		local lamp = part("Lantern", Vector3.new(1.7 * k, 2.6 * k, 1.7 * k), CFrame.new(lp), SOUL, NEON, { noShadow = true })
		part("LanternCap", Vector3.new(2.4 * k, 0.7, 2.4 * k), CFrame.new(lp + Vector3.new(0, 1.55 * k, 0)), BRASS, METAL)
		part("LanternFinial", Vector3.new(0.6, 1.2 * k, 0.6), CFrame.new(lp + Vector3.new(0, 2.3 * k, 0)), BRASS, METAL)
		if big then
			local l = Instance.new("PointLight")
			l.Color = SOUL
			l.Range = 40
			l.Brightness = 2
			l.Shadows = false
			l.Parent = lamp
		end
	end

	-- ── the bow: bowsprit, skull figurehead, the hawse
	local spritBase = Vector3.new(0, railY(-1) - 1, -L / 2 + 2)
	local spritTip = spritBase + Vector3.new(0, math.sin(math.rad(22)), -math.cos(math.rad(22))) * L * 0.28
	cyl("Bowsprit", spritBase, spritTip, 2.2, TIMBER_DARK, WOOD)
	local sk = L / 150 -- (the figurehead grows with the ship)
	if cfg.flagship then
		-- Orvoss himself, carved: leaning out from the stem under the bowsprit, tricorn on, cutlass thrust forward
		local fig = CFrame.new(0, railY(-1) - 6 * sk, -L / 2 - 2 * sk) * CFrame.Angles(-0.55, 0, 0)
		local function at(x, y, z)
			return (fig * CFrame.new(x * sk, y * sk, z * sk)).Position
		end
		part("FigureCoat", Vector3.new(3.4, 5.4, 2.4) * sk, fig * CFrame.new(0, 2.6 * sk, 0), TIMBER_DARK, WOOD)
		part("FigureTails", Vector3.new(3.8, 4, 2) * sk, fig * CFrame.new(0, -1.4 * sk, 0.4 * sk) * CFrame.Angles(0.15, 0, 0), TIMBER_DARK, WOOD)
		part("FigureLapels", Vector3.new(2.2, 3.6, 0.4) * sk, fig * CFrame.new(0, 3.2 * sk, -1.25 * sk), BRASS_DARK, METAL)
		part("FigureRibs", Vector3.new(1.4, 2.6, 0.4) * sk, fig * CFrame.new(0, 3.3 * sk, -1.45 * sk), BONE_OLD, SMOOTH)
		for _, sx in ipairs({ -1, 1 }) do
			part("FigureEpaulette", Vector3.new(1.6, 0.6, 1.6) * sk, fig * CFrame.new(sx * 1.9 * sk, 5.3 * sk, 0), BRASS, METAL)
		end
		local head = at(0, 6.9, -0.3)
		ball("FigureSkull", head, 2.6 * sk, BONE, SMOOTH)
		part("FigureJaw", Vector3.new(1.6, 0.7, 1.4) * sk, fig * CFrame.new(0, 5.7 * sk, -0.9 * sk), BONE, SMOOTH)
		for _, sx in ipairs({ -1, 1 }) do
			part("FigureEye", Vector3.new(0.6, 0.5, 0.3) * sk, fig * CFrame.new(sx * 0.5 * sk, 7 * sk, -1.55 * sk), SOUL, NEON, { noShadow = true })
		end
		cyl("FigureHatBrim", at(0, 8, -0.3), at(0, 8.45, -0.3), 4.6 * sk, TIMBER_DARK, WOOD)
		part("FigureHatCrown", Vector3.new(2.6, 1.5, 2.4) * sk, fig * CFrame.new(0, 8.9 * sk, -0.3 * sk), TIMBER_DARK, WOOD)
		part("FigureHatBand", Vector3.new(2.7, 0.35, 2.5) * sk, fig * CFrame.new(0, 8.5 * sk, -0.3 * sk), BRASS, METAL)
		-- the sword arm thrust forward and up; the other arm swept back
		local hand = at(2, 6.2, -4.6)
		bar("FigureArm", at(1.9, 4.8, 0), hand, 1.1 * sk, 1.1 * sk, TIMBER_DARK, WOOD)
		ball("FigureFist", hand, 1.2 * sk, BONE, SMOOTH)
		local tip = at(2, 9.8, -11.5)
		bar("FigureCutlass", hand, tip, 0.25 * sk, 0.9 * sk, BRASS, METAL)
		bar("FigureCutlassEdge", at(2, 6.3, -4.8), at(2, 9.5, -11.3), 0.3 * sk, 0.2 * sk, BONE_OLD, METAL)
		part("FigureGuard", Vector3.new(0.5, 1.4, 0.5) * sk, CFrame.new(hand) * (fig - fig.Position), BRASS, METAL)
		bar("FigureArmBack", at(-1.9, 4.8, 0), at(-2.3, 2, 2), 1.1 * sk, 1.1 * sk, TIMBER_DARK, WOOD)
	else
	local skullC = Vector3.new(0, railY(-1) - 5 * sk, -L / 2 - 4 * sk)
	ball("FigureSkull", skullC, 7 * sk, BONE, SMOOTH)
	part("FigureBrow", Vector3.new(6 * sk, 1.4 * sk, 3 * sk), CFrame.new(skullC + Vector3.new(0, 1.4 * sk, -2.4 * sk)) * CFrame.Angles(0.3, 0, 0), BONE, SMOOTH)
	part("FigureSnout", Vector3.new(4.4 * sk, 3 * sk, 4 * sk), CFrame.new(skullC + Vector3.new(0, -1.4 * sk, -3 * sk)), BONE, SMOOTH)
	part("FigureJaw", Vector3.new(4.2 * sk, 1.4 * sk, 4.6 * sk), CFrame.new(skullC + Vector3.new(0, -4 * sk, -2.4 * sk)) * CFrame.Angles(0.35, 0, 0), BONE, SMOOTH)
	for k = -2, 2 do
		part("FigureTooth", Vector3.new(0.6 * sk, 1.2 * sk, 0.6 * sk), CFrame.new(skullC + Vector3.new(k * 0.85 * sk, -3 * sk, -4.7 * sk)), BONE, SMOOTH)
	end
	for _, sx in ipairs({ -1, 1 }) do
		part("FigureSocket", Vector3.new(1.9 * sk, 1.6 * sk, 0.4), CFrame.new(skullC + Vector3.new(sx * 1.5 * sk, 0.3 * sk, -3.3 * sk)), TIMBER_DARK, SMOOTH)
		part("FigureEye", Vector3.new(1.3 * sk, 1.1 * sk, 0.4), CFrame.new(skullC + Vector3.new(sx * 1.5 * sk, 0.3 * sk, -3.5 * sk)), SOUL, NEON, { noShadow = true })
		-- the horns sweep back and up
		local h0 = skullC + Vector3.new(sx * 2.6 * sk, 2 * sk, 0)
		local h1 = skullC + Vector3.new(sx * 4.6 * sk, 4 * sk, 3 * sk)
		local h2 = skullC + Vector3.new(sx * 4.4 * sk, 6.6 * sk, 6.5 * sk)
		bar("FigureHorn", h0, h1, 1.5 * sk, 1.5 * sk, BONE, SMOOTH)
		bar("FigureHorn", h1, h2, 1 * sk, 1 * sk, BONE, SMOOTH)
		-- ribs: curved bones from the stem down the bow's side, as if the skull's body is fused into the hull
		for k = 1, 3 do
			local sA = -0.97 + k * 0.05
			local a = (surfaceFrame(sA, 0.92, sx) * CFrame.new(0.9, 0, 0)).Position
			local m = (surfaceFrame(sA + 0.02, 0.72, sx) * CFrame.new(1.3, 0, 0)).Position
			local b = (surfaceFrame(sA + 0.05, 0.52, sx) * CFrame.new(0.9, 0, 0)).Position
			bar("FigureRib", a, m, 0.8 * sk, 0.8 * sk, BONE_OLD, SMOOTH)
			bar("FigureRib", m, b, 0.55 * sk, 0.55 * sk, BONE_OLD, SMOOTH)
		end
	end
	end -- (the skull figurehead)
	local hawse = Instance.new("Attachment")
	hawse.Name = "Hawse"
	hawse.CFrame = CFrame.lookAt(point(-0.86, 0.75, 1), point(-0.86, 0.75, 1) + Vector3.new(0.4, -0.3, -1))
	hawse.Parent = root
	if cfg.flagship then
		-- two anchors hanging from the catheads on short chains
		local A = L * 0.075
		for _, side in ipairs({ -1, 1 }) do
			local base = point(-0.8, 0.96, side)
			local tipC = base + Vector3.new(side * 7, 1, -2)
			bar("Cathead", base - Vector3.new(side * 2, 0, 0), tipC, 2, 2, TIMBER_DARK, WOOD)
			local ring = tipC - Vector3.new(0, 5, 0)
			for k = 0, 3 do
				local y0 = tipC.Y - 0.4 - k * 1.2
				part("ChainLink", Vector3.new(k % 2 == 0 and 0.4 or 1.1, 1.5, k % 2 == 0 and 1.1 or 0.4), CFrame.new(tipC.X, y0 - 0.6, tipC.Z), IRON, METAL)
			end
			cyl("AnchorRing", ring + Vector3.new(0, 0.4, 0), ring - Vector3.new(0, 0.4, 0), 2.4, IRON, METAL)
			local crown = ring - Vector3.new(0, A, 0)
			bar("AnchorShank", ring, crown, 1.4, 1.4, IRON, METAL)
			bar("AnchorStock", ring - Vector3.new(0, 1.6, A * 0.32), ring - Vector3.new(0, 1.6, -A * 0.32), 1.1, 1.1, TIMBER_DARK, WOOD)
			for _, dz in ipairs({ -1, 1 }) do
				local armEnd = crown + Vector3.new(side * 0.6, A * 0.3, dz * A * 0.32)
				bar("AnchorArm", crown, armEnd, 1.2, 1.2, IRON, METAL)
				part("AnchorFluke", Vector3.new(0.5, A * 0.14, A * 0.1), CFrame.lookAt(armEnd, armEnd + Vector3.new(0, 1, dz * 0.4)) * CFrame.new(0, 0, -A * 0.02), IRON, METAL)
			end
			ball("AnchorBarnacle", crown + Vector3.new(0, 0.6, 0), 1.6, BARNACLE, SMOOTH, { noShadow = true })
			local hw = Instance.new("Attachment")
			hw.Name = side < 0 and "HawseL" or "HawseR"
			hw.CFrame = CFrame.new(ring)
			hw.Parent = root
		end
		local bridge = Instance.new("Attachment")
		bridge.Name = "Bridge"
		bridge.CFrame = CFrame.new(0, railY(0.75) - 2.5, 0.75 * L / 2)
		bridge.Parent = root
	end

	-- ── the gun decks: brass-framed ports along the waist, glowing from inside, barrels out
	local portsPerSide = 0
	for deck = 1, cfg.decks do
		local ps = cfg.portScale or 1
		local count = math.floor((0.5 + 0.6) * L / 2 / (10 * ps))
		portsPerSide = math.max(portsPerSide, count)
		for _, side in ipairs({ -1, 1 }) do
			for k = 1, count do
				local s = -0.6 + (k - 0.5) / count * 1.1 + (deck % 2 == 0 and 0.5 / count or 0) * 0.6
				local y = cfg.H + cfg.sheer * s * s - 6 * ps - (deck - 1) * 6.2 * ps
				local v = vAtY(s, y)
				if v > 0.25 and not breachAt(s, v, side) then
					local fr = surfaceFrame(s, v, side)
					-- (out past the heavy wales, so no strake hides a port; a brass frame round the light)
					part("PortFrame", Vector3.new(0.6, 4.8 * ps, 4.8 * ps), fr * CFrame.new(0.9, 0, 0), BRASS_DARK, METAL)
					local glowP = part("PortGlow", Vector3.new(0.4, 3.6 * ps, 3.6 * ps), fr * CFrame.new(1.1, 0, 0), PORT_GLOW, NEON, { noShadow = true })
					glowP:SetAttribute("Deck", deck)
					glowP:SetAttribute("Index", k)
					glowP:SetAttribute("Side", side)
					local gun = cyl("Gun", (fr * CFrame.new(0.4, 0, 0)).Position, (fr * CFrame.new(3.6 * ps, 0, 0)).Position, 1.3 * ps, IRON, METAL)
					local muzzle = Instance.new("Attachment")
					muzzle.Name = "Muzzle"
					-- (the cylinder's +X runs along the barrel: the muzzle looks out along it)
					muzzle.CFrame = CFrame.new(gun.Size.X / 2, 0, 0) * CFrame.Angles(0, -math.pi / 2, 0)
					muzzle.Parent = gun
				end
			end
		end
	end

	-- ── splinters round each breach: broken plank ends sticking out of its edge
	for _, br in ipairs(cfg.breaches) do
		for k = 1, 9 do
			local a = k / 9 * math.pi * 2 + rng:NextNumber(-0.2, 0.2)
			local bs, bv = br[1] + br[3] * math.cos(a), br[2] + br[4] * math.sin(a)
			if bv > 0.05 and bv < 0.98 then
				local fr = surfaceFrame(bs, bv, br[5])
				part("Splinter", Vector3.new(0.7, rng:NextNumber(2, 4.5), rng:NextNumber(1.2, 2.4)),
					fr * CFrame.new(0.4, 0, 0) * CFrame.Angles(rng:NextNumber(-0.8, 0.8), rng:NextNumber(-0.4, 0.4), rng:NextNumber(-0.5, 0.5)),
					TIMBER:Lerp(TIMBER_DARK, rng:NextNumber()), WOOD)
			end
		end
	end
	-- ── glowing cracks over the intact hull (ghost light holding the planks together)
	for _ = 1, 8 do
		local side = rng:NextNumber() < 0.5 and -1 or 1
		local s = rng:NextNumber(-0.7, 0.7)
		local v = rng:NextNumber(0.15, 0.85)
		if not breachAt(s, v, side) then
			local fr = surfaceFrame(s, v, side)
			part("SoulCrack", Vector3.new(0.4, rng:NextNumber(4, 9), 0.35), fr * CFrame.new(0.55, 0, 0) * CFrame.Angles(rng:NextNumber(-0.5, 0.5), 0, 0), SOUL, NEON, { noShadow = true })
		end
	end
	-- ── weed hanging off the bottom, the wales and the bowsprit
	local function weed(p, len, sideTilt)
		part("Weed", Vector3.new(0.35, len, rng:NextNumber(0.7, 1.5)), CFrame.new(p + Vector3.new(0, -len / 2 + 0.4, 0)) * CFrame.Angles(0, 0, sideTilt),
			rng:NextNumber() < 0.7 and WEED or VERDIGRIS, FABRIC, { noShadow = true })
	end
	for _ = 1, 16 do
		local side = rng:NextNumber() < 0.5 and -1 or 1
		weed(point(rng:NextNumber(-0.8, 0.85), rng:NextNumber(0.05, 0.25), side), rng:NextNumber(5, 13), side * rng:NextNumber(0, 0.25))
	end
	for _ = 1, 14 do
		local side = rng:NextNumber() < 0.5 and -1 or 1
		local fr = surfaceFrame(rng:NextNumber(-0.75, 0.8), rng:NextNumber(0.42, 0.46), side)
		weed((fr * CFrame.new(1, 0, 0)).Position, rng:NextNumber(2.5, 7), side * rng:NextNumber(0, 0.15))
	end
	for k = 1, 4 do
		weed(spritBase:Lerp(spritTip, k / 5), rng:NextNumber(3, 7), rng:NextNumber(-0.1, 0.1))
	end
	-- ── barnacle clusters with drowned skulls among them, in a band along the lower hull
	for _ = 1, 11 do
		local side = rng:NextNumber() < 0.5 and -1 or 1
		local s0 = rng:NextNumber(-0.8, 0.8)
		local v0 = rng:NextNumber(0.2, 0.36)
		for _ = 1, 4 do
			local s1, v1 = s0 + rng:NextNumber(-0.025, 0.025), v0 + rng:NextNumber(-0.04, 0.04)
			if not breachAt(s1, v1, side) then
				local fr = surfaceFrame(s1, v1, side)
				local skull = rng:NextNumber() < 0.3
				ball(skull and "DrownedSkull" or "Barnacle", (fr * CFrame.new(0.6, 0, 0)).Position, rng:NextNumber(1, 1.9),
					skull and BONE or BARNACLE, SMOOTH, { noShadow = true })
			end
		end
	end

	-- ── the masts: three sections, two tops, yards, torn sails, shrouds; a broken mast ends in splinters
	local tops = {}
	for mi, m in ipairs(cfg.masts) do
		local s, hShare, broken = m[1], m[2], m[3]
		local z = s * L / 2
		local foot = railY(s) - 3
		local h = hShare * L
		local stop = broken and h * broken or h
		local r = L / 85
		local sections = { { 0, 0.46, r }, { 0.43, 0.76, r * 0.72 }, { 0.73, 1, r * 0.48 } }
		for _, sec in ipairs(sections) do
			local y0, y1 = sec[1] * h, math.min(sec[2] * h, stop)
			if y1 > y0 then
				cyl("Mast", Vector3.new(0, foot + y0, z), Vector3.new(0, foot + y1, z), sec[3] * 2, TIMBER_DARK, WOOD)
				if sec[1] == 0 then
					for _, by in ipairs({ 0.12, 0.26, 0.4 }) do
						if by * h < stop then
							cyl("MastBand", Vector3.new(0, foot + by * h - 0.4, z), Vector3.new(0, foot + by * h + 0.4, z), sec[3] * 2.25, BRASS_DARK, METAL)
						end
					end
				end
			end
		end
		if broken then
			for k = 1, 3 do
				local a = k / 3 * math.pi * 2
				part("Splinter", Vector3.new(r * 0.7, rng:NextNumber(2, 5), r * 0.5), CFrame.new(math.cos(a) * r * 0.5, foot + stop + 1.2, z + math.sin(a) * r * 0.5) * CFrame.Angles(math.cos(a) * 0.3, 0, math.sin(a) * 0.3), TIMBER_DARK, WOOD)
			end
		end
		for _, ty in ipairs({ 0.45, 0.75 }) do
			if ty * h < stop then
				cyl("Top", Vector3.new(0, foot + ty * h - 0.4, z), Vector3.new(0, foot + ty * h + 0.4, z), r * 5, TIMBER_DARK, WOOD)
			end
		end
		tops[mi] = { z = z, foot = foot, h = h, stop = stop }
		-- yards and sails: course, topsail, topgallant
		local yards = { { 0.3, 0.55, 0.08 }, { 0.6, 0.44, 0.33 }, { 0.88, 0.32, 0.63 } }
		for yi, yd in ipairs(yards) do
			local yy = yd[1] * h
			if yy < stop - 1 then
				local half = yd[2] * L / 2 * (cfg.yardScale or cfg.B / 20)
				half = math.max(half, L * 0.12)
				cyl("Yard", Vector3.new(-half, foot + yy, z - r), Vector3.new(half, foot + yy, z - r), r * (1.1 - yi * 0.2), TIMBER_DARK, WOOD)
				-- the sail: one canvas bellied forward (a centre panel and two angled wings), cut off ragged; torn
				-- strips hang below it to different lengths, and on the worst ships a wing is gone
				local bottom = (yd[3] * h)
				local full = yy - bottom
				local W = half * 1.9
				local z0 = z - r - 1
				local belly = 2.6 * (yi == 1 and 1.5 or 1)
				local body = full * rng:NextNumber(0.5, 0.8) * (1 - cfg.tear * 0.35)
				local midY = foot + yy - 0.5 - body / 2
				local function sailZ(x) -- the canvas's depth at x across it
					local k = math.clamp((W / 2 - math.abs(x)) / (W * 0.3), 0, 1)
					return z0 - belly * k
				end
				local ensign = cfg.flagship and mi == 2 and yi == 1 -- (the flagship's great black main course)
				if ensign then
					body = full * 0.82
					midY = foot + yy - 0.5 - body / 2
				end
				local sailOpts = { transparency = ensign and 0.05 or 0.3, noShadow = true }
				part("Sail", Vector3.new(W * 0.4 + 0.4, body, 0.3), CFrame.new(0, midY, z0 - belly), ensign and SAIL_BLACK or SAIL, FABRIC, sailOpts)
				for _, sx in ipairs({ -1, 1 }) do
					if ensign or rng:NextNumber() > cfg.tear * 0.5 then
						bar("Sail", Vector3.new(sx * W / 2, midY, z0), Vector3.new(sx * W * 0.2, midY, z0 - belly), 0.3, body, ensign and SAIL_BLACK or SAIL_DARK, FABRIC, { transparency = ensign and 0.05 or 0.3, noShadow = true })
					end
				end
				if ensign then
					-- the skull and anchor in bone on the canvas's front
					local ez = z0 - belly - 0.5
					local e = body * 0.08
					ball("EmblemSkull", Vector3.new(0, midY + body * 0.12, ez - e * 0.4), e * 2.2, BONE, SMOOTH, { noShadow = true })
					part("EmblemJaw", Vector3.new(e * 1.4, e * 0.5, e * 0.6), CFrame.new(0, midY + body * 0.12 - e * 1.2, ez - e * 0.4), BONE, SMOOTH, { noShadow = true })
					for _, sx in ipairs({ -1, 1 }) do
						part("EmblemEye", Vector3.new(e * 0.5, e * 0.45, 0.3), CFrame.new(sx * e * 0.42, midY + body * 0.12 + e * 0.1, ez - e * 1.5), SAIL_BLACK, SMOOTH, { noShadow = true })
					end
					part("EmblemShank", Vector3.new(e * 0.35, body * 0.62, 0.3), CFrame.new(0, midY - body * 0.02, ez), BONE, SMOOTH, { noShadow = true })
					part("EmblemStock", Vector3.new(e * 2.6, e * 0.3, 0.3), CFrame.new(0, midY + body * 0.27, ez), BONE, SMOOTH, { noShadow = true })
					for _, sx in ipairs({ -1, 1 }) do
						local c0 = Vector3.new(0, midY - body * 0.32, ez)
						local c1 = Vector3.new(sx * e * 2.2, midY - body * 0.2, ez)
						bar("EmblemArm", c0, c1, 0.3, e * 0.35, BONE, SMOOTH, { noShadow = true })
						part("EmblemFluke", Vector3.new(e * 0.7, e * 0.7, 0.3), CFrame.new(c1) * CFrame.Angles(0, 0, math.rad(45)), BONE, SMOOTH, { noShadow = true })
					end
				end
				local strips = 6
				for k = 1, strips do
					local x = -W / 2 + (k - 0.5) * W / strips
					local len = (full - body) * rng:NextNumber(0, 1 - cfg.tear * 0.5)
					if len > 1.5 and not ensign then
						part("SailRag", Vector3.new(W / strips * rng:NextNumber(0.55, 0.9), len, 0.25),
							CFrame.new(x, midY - body / 2 - len / 2 + 0.2, sailZ(x)) * CFrame.Angles(0, 0, rng:NextNumber(-0.05, 0.05)),
							k % 2 == 0 and SAIL or SAIL_DARK, FABRIC, { transparency = 0.35, noShadow = true })
					end
				end
			end
		end
		-- shrouds: from the lower top down to the rail on each side, with ratlines across them
		local topY = foot + math.min(0.45 * h, stop - 1)
		for _, side in ipairs({ -1, 1 }) do
			local ends = {}
			for k = -1, 1 do
				local sz = s + k * 0.035
				local railP = point(sz, 1, side) + Vector3.new(side * 1.2, 0.5, 0)
				local topP = Vector3.new(side * r * 1.5, topY, z + k * r)
				bar("Shroud", topP, railP, 0.35, 0.35, ROPE, FABRIC, { noShadow = true })
				ends[k] = { topP, railP }
			end
			for _, f in ipairs({ 0.2, 0.4, 0.6, 0.8 }) do
				bar("Ratline", ends[-1][2]:Lerp(ends[-1][1], f), ends[1][2]:Lerp(ends[1][1], f), 0.25, 0.25, ROPE, FABRIC, { noShadow = true })
			end
		end
	end
	-- stays: bowsprit tip to the fore mast, and each mast's top to the foot of the one ahead
	if tops[1] then
		bar("Stay", spritTip, Vector3.new(0, tops[1].foot + math.min(0.75 * tops[1].h, tops[1].stop), tops[1].z), 0.4, 0.4, ROPE, FABRIC, { noShadow = true })
	end
	for mi = 2, #tops do
		local a, b = tops[mi], tops[mi - 1]
		bar("Stay", Vector3.new(0, a.foot + math.min(0.74 * a.h, a.stop), a.z), Vector3.new(0, b.foot + 4, b.z), 0.4, 0.4, ROPE, FABRIC, { noShadow = true })
	end
	-- a torn black pennant at the tallest standing masthead
	local best
	for _, t in ipairs(tops) do
		if not best or t.stop > best.stop then
			best = t
		end
	end
	if best then
		for k = 1, 4 do
			local len = 12 - k * 2
			part("Pennant", Vector3.new(0.2, 1.6, len), CFrame.new(0, best.foot + best.stop - 1 - k * 1.7, best.z + len / 2 + 1) * CFrame.Angles(rng:NextNumber(-0.08, 0.08), 0, 0), TIMBER_DARK, FABRIC, { noShadow = true })
		end
	end

	model:SetAttribute("Length", L)
	model:SetAttribute("Variant", cfg.name)
	model:SetAttribute("GunDecks", cfg.decks)
	model:SetAttribute("PortsPerSide", portsPerSide)
	return model
end

-- ====================================================================
local report = {}
for _, cfg in ipairs(VARIANTS) do
	local m = buildShip(cfg)
	local n = 0
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			n += 1
		end
	end
	m.Parent = fleet
	table.insert(report, cfg.name .. " " .. n)
	task.wait()
end
fleet.Parent = shipFolder
return "BlackwakeFleet: " .. table.concat(report, ", ")
