-- The Forgotten Cemetery's outer wall section (realm 1, docs/world.md "outer wall rework"): the 45 degrees of the
-- outer ring behind a claimed plot, dressed as the cemetery's edge. Safe to re-run.
-- Run in Edit mode (Studio MCP execute_luau or loadstring from the tools/studio http server); save the place after.
--
-- It is a facade in FRONT of the neutral wall (build_ring.lua): the neutral wall body stays, its buttresses / course /
-- arrow slits / merlons are hidden while the section stands. Colours: grey fieldstone, moss, rusty iron, lantern gold,
-- green soul light.
--   * the gatehouse: a mausoleum front round the gate tower (two columns, an entablature, a pediment, a weeping stone
--     angel on top, chains), kept clear of the portal's arch and its rune stones (PortalFx), the door untouched
--   * bays every 5 degrees between fieldstone piers: a pointed-arch niche with a crypt in it (two versions: Sealed /
--     Open, the server shows the share of the realm's ascensions done), a band of skulls above, hanging lanterns,
--     gargoyles and stone crosses on the piers, moss, dead ivy, crumbling battlements with rusty spikes
--
-- MODE "full" (default): builds the whole section for compass angle 0 into ServerStorage.LaneModels.WallCemetery
-- (WorldPivot at the arena's centre: the server's PlotLook turns it to the claimed plot's lane, hides that section's
-- neutral decorations, turns its rose window green and gold, and shows as many crypts Open as the share of the realm's
-- ascensions done; bays carry CryptIndex 1.. from the gate outwards). Also removes the preview.
-- MODE "preview": the gatehouse and the two bays beside it on plot 1's section (Workspace.WallCemeteryPreview), for
-- approval; hides that section's neutral decorations (re-running build_ring.lua restores them).
local MODE = "full"

local floorTop = -1.7
local R_IN = 392
local FIELD = Color3.fromRGB(96, 94, 88)
local FIELD_DARK = Color3.fromRGB(66, 64, 60)
local FIELD_LIGHT = Color3.fromRGB(126, 122, 112)
local NICHE = Color3.fromRGB(22, 22, 20)
local MOSS = Color3.fromRGB(58, 82, 44)
local RUST = Color3.fromRGB(78, 48, 36)
local IRON = Color3.fromRGB(34, 32, 30)
local GOLD = Color3.fromRGB(255, 196, 110)
local SOUL = Color3.fromRGB(120, 255, 170)
local BONE = Color3.fromRGB(176, 166, 144)
local STATUE = Color3.fromRGB(150, 148, 140)

local rng = Random.new(1916)

local function dirAt(deg)
	local a = math.rad(deg)
	return Vector3.new(math.sin(a), 0, -math.cos(a))
end
-- like build_ring: at radius r, compass angle deg, height y, facing the centre (-Z = towards the lane, X = along)
local function onRing(r, deg, y)
	local pos = dirAt(deg) * r
	return CFrame.lookAt(Vector3.new(pos.X, y, pos.Z), Vector3.new(0, y, 0))
end

local folderStack = {}
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
	p.Material = material or Enum.Material.Cobblestone
	if shape then
		p.Shape = shape
	end
	p.Parent = folderStack[#folderStack]
	return p
end
local function wedge(name, size, cf, color, material)
	local p = Instance.new("WedgePart")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.Cobblestone
	p.Parent = folderStack[#folderStack]
	return p
end
local function push(name)
	local f = Instance.new("Model")
	f.Name = name
	f.Parent = folderStack[#folderStack]
	table.insert(folderStack, f)
	return f
end
local function pop()
	table.remove(folderStack)
end
local function light(parent, color, range, brightness)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Shadows = false
	l.Parent = parent
	return l
end

-- ============================================================
-- Pieces (every cf: -Z looks at the lane, +Y up)
-- ============================================================
-- a skull: cranium, jaw, eye sockets, nose, teeth
local function skull(cf, s)
	s = s or 1
	part("Skull", Vector3.one * 0.95 * s, cf * CFrame.new(0, 0.1 * s, 0), BONE, Enum.Material.Limestone, Enum.PartType.Ball)
	part("SkullJaw", Vector3.new(0.55, 0.34, 0.5) * s, cf * CFrame.new(0, -0.3 * s, -0.12 * s), BONE, Enum.Material.Limestone)
	for _, k in ipairs({ -1, 1 }) do
		part("SkullEye", Vector3.one * 0.3 * s, cf * CFrame.new(k * 0.2 * s, 0.08 * s, -0.33 * s), NICHE, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	end
	part("SkullNose", Vector3.new(0.12, 0.14, 0.1) * s, cf * CFrame.new(0, -0.1 * s, -0.42 * s), NICHE, Enum.Material.SmoothPlastic)
end

-- a hanging lantern on an iron bracket (cf: the bracket's foot on the face)
local function lantern(cf)
	part("LanternArm", Vector3.new(0.3, 0.3, 2.6), cf * CFrame.new(0, 0, -1.3), IRON, Enum.Material.Metal)
	part("LanternChain", Vector3.new(0.12, 1.2, 0.12), cf * CFrame.new(0, -0.6, -2.5), IRON, Enum.Material.Metal)
	local top = cf * CFrame.new(0, -1.3, -2.5)
	part("LanternCap", Vector3.new(1, 0.3, 1), top * CFrame.Angles(0, math.rad(45), 0), RUST, Enum.Material.Metal)
	for _, c in ipairs({ { -1, -1 }, { -1, 1 }, { 1, -1 }, { 1, 1 } }) do
		part("LanternPost", Vector3.new(0.1, 1.2, 0.1), top * CFrame.new(c[1] * 0.38, -0.75, c[2] * 0.38), RUST, Enum.Material.Metal)
	end
	part("LanternBase", Vector3.new(0.9, 0.15, 0.9), top * CFrame.new(0, -1.4, 0), RUST, Enum.Material.Metal)
	local flame = part("LanternFlame", Vector3.new(0.45, 0.7, 0.45), top * CFrame.new(0, -0.8, 0), GOLD, Enum.Material.Neon)
	light(flame, GOLD, 18, 1.1)
end

-- a weeping angel (cf: its feet, facing -Z): robe, bowed head, hands to the face, half-spread wings
local function angel(cf, s)
	push("WeepingAngel")
	local function p(name, size, off, color, shape)
		return part(name, size * s, cf * CFrame.new(off.X * s, off.Y * s, off.Z * s), color or STATUE, Enum.Material.Limestone, shape)
	end
	p("Robe", Vector3.new(3.2, 4.5, 2.6), Vector3.new(0, 2.25, 0))
	p("RobeMid", Vector3.new(2.7, 3.2, 2.1), Vector3.new(0, 6, 0))
	p("Chest", Vector3.new(2.5, 2.4, 1.8), Vector3.new(0, 8.6, 0))
	part("Head", Vector3.one * 1.5 * s, cf * CFrame.new(0, 10.3 * s, -0.45 * s), STATUE, Enum.Material.Limestone, Enum.PartType.Ball)
	part("Hair", Vector3.new(1.5, 1.6, 1.1) * s, cf * CFrame.new(0, 10.4 * s, 0.1 * s), STATUE, Enum.Material.Limestone)
	-- forearms raised to the bowed face
	for _, k in ipairs({ -1, 1 }) do
		part("UpperArm", Vector3.new(0.6, 2.2, 0.6) * s, cf * CFrame.new(k * 1.35 * s, 8.6 * s, -0.4 * s) * CFrame.Angles(math.rad(35), 0, k * math.rad(-12)), STATUE, Enum.Material.Limestone)
		part("Forearm", Vector3.new(0.55, 2, 0.55) * s, cf * CFrame.new(k * 0.6 * s, 9.6 * s, -1.25 * s) * CFrame.Angles(math.rad(-20), 0, k * math.rad(35)), STATUE, Enum.Material.Limestone)
		-- the wing: a broad shoulder piece and five feathers fanning from up-and-out down to the hem
		local root = cf * CFrame.new(k * 1.1 * s, 9.2 * s, 0.9 * s)
		part("WingRoot", Vector3.new(2.6, 1.6, 0.6) * s, root * CFrame.new(k * 1.1 * s, 0.4 * s, 0) * CFrame.Angles(0, k * math.rad(20), k * math.rad(20)), STATUE, Enum.Material.Limestone)
		for f = 0, 4 do
			local spread = math.rad(25 + f * 26) -- (from steeply up to pointing down)
			local len = 6.5 - math.abs(f - 1) * 0.9
			local fr = root * CFrame.Angles(0, k * math.rad(22), 0) * CFrame.new(k * 1.4 * s, 0.5 * s, 0) * CFrame.Angles(0, 0, k * -spread)
			part("Feather", Vector3.new(1.6, len, 0.4) * s, fr * CFrame.new(0, len / 2 * s, f * 0.05 * s), STATUE, Enum.Material.Limestone)
		end
	end
	-- moss on the robe's hem
	part("Moss", Vector3.new(3.3, 0.5, 2.7) * s, cf * CFrame.new(0, 0.25 * s, 0), MOSS, Enum.Material.LeafyGrass)
	pop()
end

-- a crouching gargoyle (cf: its feet, facing -Z)
local function gargoyle(cf)
	push("Gargoyle")
	part("Body", Vector3.new(1.8, 1.8, 2.4), cf * CFrame.new(0, 1.1, -0.2) * CFrame.Angles(math.rad(-25), 0, 0), FIELD_DARK)
	part("Head", Vector3.new(1.2, 1.1, 1.3), cf * CFrame.new(0, 2.2, -1.4), FIELD_DARK)
	part("Snout", Vector3.new(0.7, 0.5, 0.8), cf * CFrame.new(0, 2, -2.2), FIELD_DARK)
	for _, k in ipairs({ -1, 1 }) do
		part("Horn", Vector3.new(0.2, 0.8, 0.2), cf * CFrame.new(k * 0.4, 2.9, -1.3) * CFrame.Angles(math.rad(-20), 0, k * math.rad(-20)), FIELD_DARK)
		part("Wing", Vector3.new(0.25, 2.2, 1.8), cf * CFrame.new(k * 1, 1.9, 0.6) * CFrame.Angles(math.rad(15), 0, k * math.rad(-25)), FIELD_DARK)
		part("Claw", Vector3.new(0.5, 0.9, 0.6), cf * CFrame.new(k * 0.6, 0.45, -1.1), FIELD_DARK)
	end
	pop()
end

-- a pier between two bays (deg: where it stands); topped by a gargoyle or a stone cross; a lantern on its face
local WALL_TOP = floorTop + 70
local function pier(deg, topper)
	push("Pier")
	local h = WALL_TOP - floorTop - 4
	local base = onRing(R_IN, deg, floorTop)
	part("Pier", Vector3.new(5, h, 4.5), base * CFrame.new(0, h / 2, -2.25), FIELD)
	part("PierFoot", Vector3.new(6, 6, 5.5), base * CFrame.new(0, 3, -2.75), FIELD_DARK)
	part("PierMoss", Vector3.new(6.1, 0.5, 5.6), base * CFrame.new(0, 6.1, -2.75), MOSS, Enum.Material.LeafyGrass)
	part("PierCap", Vector3.new(5.8, 1.2, 5.3), base * CFrame.new(0, h + 0.6, -2.4), FIELD_LIGHT)
	local top = base * CFrame.new(0, h + 1.2, -2.4)
	if topper == "gargoyle" then
		gargoyle(top)
	else
		part("Cross", Vector3.new(0.9, 5, 0.9), top * CFrame.new(0, 2.5, 0), FIELD_LIGHT)
		part("CrossArm", Vector3.new(3, 0.9, 0.9), top * CFrame.new(0, 3.4, 0), FIELD_LIGHT)
	end
	lantern(base * CFrame.new(0, 20, -4.5))
	pop()
end

-- a bay: a pointed-arch niche with a crypt (Sealed / Open versions), skulls above, ivy, a fallen block
local function bay(deg, index)
	local m = push("Bay" .. index)
	m:SetAttribute("CryptIndex", index)
	local base = onRing(R_IN, deg, floorTop)
	local W, H, SPRING = 14, 28, 21 -- the opening's width, apex and where the arch springs
	part("NicheBack", Vector3.new(W, SPRING, 0.4), base * CFrame.new(0, SPRING / 2, -0.3), NICHE, Enum.Material.Slate)
	-- (a square turned 45 degrees with its side corners on the springs: its top corner is the apex, so it fills the
	-- pointed top exactly)
	part("NicheTop", Vector3.new(W / math.sqrt(2), W / math.sqrt(2), 0.4), base * CFrame.new(0, SPRING, -0.3) * CFrame.Angles(0, 0, math.rad(45)), NICHE, Enum.Material.Slate)
	for _, k in ipairs({ -1, 1 }) do
		part("Jamb", Vector3.new(2.2, SPRING, 3), base * CFrame.new(k * (W / 2 + 1.1), SPRING / 2, -1.5), FIELD)
		-- the pointed arch: two leaning blocks meeting at the apex
		local from = Vector3.new(k * (W / 2 + 1.1), SPRING, 0)
		local to = Vector3.new(0, H + 1, 0)
		local mid = (from + to) / 2
		local len = (to - from).Magnitude + 2
		part("ArchStone", Vector3.new(2.2, len, 3), base * CFrame.new(mid.X, mid.Y, -1.5) * CFrame.Angles(0, 0, math.atan2(to.X - from.X, -(to.Y - from.Y)) + math.pi), FIELD_LIGHT)
	end
	part("Keystone", Vector3.new(2.4, 2.8, 3.4), base * CFrame.new(0, H + 1.2, -1.6), FIELD_LIGHT)
	part("Sill", Vector3.new(W + 5, 1, 3.6), base * CFrame.new(0, 0.5, -1.8), FIELD_DARK)
	part("SillMoss", Vector3.new(W + 5, 0.35, 3.6), base * CFrame.new(0, 1.15, -1.8), MOSS, Enum.Material.LeafyGrass)

	-- the crypt, sealed: a stone door with an iron ring and a plaque, two candles
	local sealed = push("Sealed")
	part("CryptDoor", Vector3.new(7, 12, 0.8), base * CFrame.new(0, 7, -0.9), FIELD_DARK, Enum.Material.Slate)
	part("CryptLintel", Vector3.new(9, 1.4, 1.4), base * CFrame.new(0, 13.7, -1.1), FIELD_LIGHT)
	part("Plaque", Vector3.new(3, 1, 0.2), base * CFrame.new(0, 10, -1.4), Color3.fromRGB(90, 76, 52), Enum.Material.Metal)
	part("DoorRing", Vector3.new(0.2, 1, 1), base * CFrame.new(0, 6.5, -1.45) * CFrame.Angles(0, math.rad(90), 0), IRON, Enum.Material.Metal, Enum.PartType.Cylinder)
	for _, k in ipairs({ -1, 1 }) do
		part("Candle", Vector3.new(0.4, 1, 0.4), base * CFrame.new(k * 4.5, 1.5, -2.4), Color3.fromRGB(168, 156, 134), Enum.Material.SmoothPlastic)
		local f = part("CandleFlame", Vector3.new(0.25, 0.4, 0.25), base * CFrame.new(k * 4.5, 2.2, -2.4), GOLD, Enum.Material.Neon, Enum.PartType.Ball)
		if k == 1 then
			light(f, GOLD, 8, 0.6)
		end
	end
	pop()
	-- the crypt, broken open: the door fallen in front, green soul light inside, bones spilling out
	local open = push("Open")
	part("CryptLintel", Vector3.new(9, 1.4, 1.4), base * CFrame.new(0, 13.7, -1.1), FIELD_LIGHT)
	local glow = part("CryptGlow", Vector3.new(6.6, 11.6, 0.2), base * CFrame.new(0, 6.9, -0.55), Color3.fromRGB(60, 150, 96), Enum.Material.Neon)
	light(glow, SOUL, 22, 1.2)
	part("FallenDoor", Vector3.new(7, 0.8, 12), base * CFrame.new(1, 1.5, -6.5) * CFrame.Angles(math.rad(6), math.rad(14), math.rad(4)), FIELD_DARK, Enum.Material.Slate)
	for b = 1, 7 do
		local pos = Vector3.new(rng:NextNumber(-3, 3), 1.2, -rng:NextNumber(1.5, 4))
		part("Bone", Vector3.new(0.25, 0.25, rng:NextNumber(0.8, 1.6)), base * CFrame.new(pos) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0), BONE, Enum.Material.Limestone)
	end
	skull(base * CFrame.new(-1.5, 1.6, -3) * CFrame.Angles(0, math.rad(20), math.rad(10)), 1.1)
	pop()
	sealed:SetAttribute("CryptState", "Sealed")
	open:SetAttribute("CryptState", "Open")

	-- a band of skulls above the arch
	part("SkullBand", Vector3.new(W + 2, 2.6, 1), base * CFrame.new(0, H + 4.8, -0.5), NICHE, Enum.Material.Slate)
	for k = -2, 2 do
		skull(base * CFrame.new(k * 2.6, H + 4.8, -1.3), 1.1)
	end
	-- two tall blind lancets high up, framed in stone
	-- (in the two bays beside the gate the keeper's fingers hang over the outer lancet: only the inner one there)
	local lancets = math.abs(deg) <= 5.5 and { deg > 0 and 1 or -1 } or { -1, 1 } -- (a bay's +X points back towards the gate)
	for _, k in ipairs(lancets) do
		local lw, lb, lt = 3.6, 40, 54 -- width, bottom, spring
		part("Lancet", Vector3.new(lw, lt - lb, 0.3), base * CFrame.new(k * 4.5, (lb + lt) / 2, -0.25), NICHE, Enum.Material.Slate)
		part("LancetTop", Vector3.new(lw / math.sqrt(2), lw / math.sqrt(2), 0.3), base * CFrame.new(k * 4.5, lt, -0.25) * CFrame.Angles(0, 0, math.rad(45)), NICHE, Enum.Material.Slate)
		part("LancetSill", Vector3.new(lw + 1.6, 0.8, 1.4), base * CFrame.new(k * 4.5, lb - 0.4, -0.7), FIELD_LIGHT)
		for _, j in ipairs({ -1, 1 }) do
			part("LancetJamb", Vector3.new(0.8, lt - lb, 1.2), base * CFrame.new(k * 4.5 + j * (lw / 2 + 0.4), (lb + lt) / 2, -0.6), FIELD)
		end
	end
	-- dead ivy hanging from high up, and a fallen block at the foot
	for v = 1, 3 do
		local x = rng:NextNumber(-W / 2 - 3, W / 2 + 3)
		local len = rng:NextNumber(8, 20)
		part("Ivy", Vector3.new(0.35, len, 0.2), base * CFrame.new(x, WALL_TOP - floorTop - 2 - len / 2, -0.2) * CFrame.Angles(0, 0, rng:NextNumber(-0.08, 0.08)), Color3.fromRGB(46, 52, 34), Enum.Material.LeafyGrass)
	end
	part("FallenBlock", Vector3.new(3, 2, 2.4), base * CFrame.new(rng:NextNumber(-9, 9), 1, -rng:NextNumber(6, 9)) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, 3), rng:NextNumber(-0.3, 0.3)), FIELD)
	pop()
end

-- where the keeper's hands rest (build_titan_hands.lua, placed by the server's Titans 8.5 above and 5 behind the
-- wall's inner top edge: palms ~38 studs either side of the lane ON the parapet, fingers curling over its edge)
local HAND_FROM, HAND_TO = 27, 52
-- a worn coping stone on the wall top under each hand, overhanging the inner face a little
local function handLedges(deg)
	push("HandLedges")
	local base = onRing(R_IN, deg, WALL_TOP)
	for _, k in ipairs({ -1, 1 }) do
		local x = k * (HAND_FROM + HAND_TO) / 2
		part("HandCoping", Vector3.new(HAND_TO - HAND_FROM, 1.2, 7.5), base * CFrame.new(x, 2.6, 2.75), FIELD_LIGHT)
		part("HandCopingWear", Vector3.new(HAND_TO - HAND_FROM - 4, 0.2, 5), base * CFrame.new(x, 3.25, 2.4), FIELD, Enum.Material.Slate)
		for c = -2, 2 do
			part("Corbel", Vector3.new(2, 2.4, 2.2), base * CFrame.new(x + c * 5, 0.8, -0.6), FIELD_DARK)
		end
	end
	pop()
end

-- crumbling cemetery battlements from degFrom to degTo: crooked fieldstone merlons, some fallen, rusty spikes between
local function battlements(degFrom, degTo)
	push("Battlements")
	local CORNICE_TOP = WALL_TOP + 2
	local step = 11 / R_IN * 180 / math.pi
	local deg = degFrom
	while deg <= degTo do
		local top = onRing(R_IN + 3.5, deg, CORNICE_TOP)
		local lateral = math.abs(math.sin(math.rad(deg))) * R_IN
		if lateral > HAND_FROM and lateral < HAND_TO then
			-- (the keeper's forearms lie over the wall here: no merlons or spikes)
		elseif rng:NextNumber() > 0.2 then
			local h = rng:NextNumber(3.5, 6.5)
			part("Merlon", Vector3.new(6, h, 4), top * CFrame.new(0, h / 2, 0) * CFrame.Angles(rng:NextNumber(-0.06, 0.06), 0, rng:NextNumber(-0.1, 0.1)), rng:NextNumber() < 0.5 and FIELD or FIELD_DARK)
			if rng:NextNumber() < 0.4 then
				part("MerlonMoss", Vector3.new(6.1, 0.4, 4.1), top * CFrame.new(0, h, 0), MOSS, Enum.Material.LeafyGrass)
			end
		end
		-- rusty spikes in the gap, some bent
		for _, x in ipairs((lateral > HAND_FROM and lateral < HAND_TO) and {} or { 4.6, 6.4 }) do
			local bend = rng:NextNumber() < 0.3 and rng:NextNumber(-0.5, 0.5) or rng:NextNumber(-0.06, 0.06)
			part("Spike", Vector3.new(0.35, 4.5, 0.35), top * CFrame.new(x, 2.25, 0) * CFrame.Angles(0, 0, bend), RUST, Enum.Material.Metal)
		end
		deg += step
	end
	pop()
end

-- the mausoleum front round the gate tower (deg: the lane's angle)
local function gatehouse(deg)
	push("Gatehouse")
	local base = onRing(R_IN, deg, floorTop)
	-- (the portal's arch is 21.4 wide and its rune stones reach ~17.5 from (0, 20): everything stays outside that)
	for _, k in ipairs({ -1, 1 }) do
		local x = k * 19
		part("ColumnBase", Vector3.new(4.4, 3, 4.4), base * CFrame.new(x, 1.5, -2.2), FIELD_DARK)
		part("Column", Vector3.new(36, 3, 3), base * CFrame.new(x, 3 + 18, -2.2) * CFrame.Angles(0, 0, math.rad(90)), FIELD_LIGHT, Enum.Material.Limestone, Enum.PartType.Cylinder)
		part("Capital", Vector3.new(4.2, 1.8, 4.2), base * CFrame.new(x, 39.9, -2.2), FIELD_LIGHT, Enum.Material.Limestone)
		-- chains hanging in a loop from the capital
		for c = 0, 5 do
			local t = c / 5
			local px = x - k * (1 + t * 3)
			local py = 38 - math.sin(t * math.pi) * 6 - t * 6
			part("Chain", Vector3.new(0.35, 1.6, 0.35), base * CFrame.new(px, py, -3.9) * CFrame.Angles(0, 0, k * (0.6 - t * 1.1)), RUST, Enum.Material.Metal)
		end
		part("ColumnMoss", Vector3.new(4.5, 0.5, 4.5), base * CFrame.new(x, 3.2, -2.2), MOSS, Enum.Material.LeafyGrass)
	end
	part("Entablature", Vector3.new(44, 3, 4), base * CFrame.new(0, 42.3, -2.2), FIELD_LIGHT, Enum.Material.Limestone)
	part("Frieze", Vector3.new(40, 1.4, 0.4), base * CFrame.new(0, 42.3, -4.3), FIELD_DARK, Enum.Material.Slate)
	-- the pediment: two wedges meeting at the apex
	for _, k in ipairs({ -1, 1 }) do
		wedge("Pediment", Vector3.new(3.4, 8, 22), base * CFrame.new(k * 11, 47.8, -2) * CFrame.Angles(0, k * math.rad(-90), 0), FIELD_LIGHT, Enum.Material.Limestone)
	end
	-- the weeping angel on the apex, wings against the stained glass behind it
	angel(base * CFrame.new(0, 52, -2.4), 1.25)
	pop()
end

-- ============================================================
-- Build
-- ============================================================
local function restoreNeutral(index)
	local ring = workspace:FindFirstChild("OuterWall")
	local section = ring and ring:FindFirstChild("Section" .. index)
	local HIDE = { Buttress = true, ButtressStep = true, ButtressCap = true, Course = true, ArrowSlit = true, Merlon = true, MerlonSpike = true }
	for _, d in ipairs(section and section:GetDescendants() or {}) do
		if d:IsA("BasePart") and HIDE[d.Name] then
			d.Transparency = 0
		end
	end
	local tower = ring and ring:FindFirstChild("GateTower" .. index)
	for _, d in ipairs(tower and tower:GetDescendants() or {}) do
		if d.Name == "RoseGlass" then
			d.Color = Color3.fromRGB(84, 40, 112)
			local l = d:FindFirstChildOfClass("SurfaceLight")
			if l then l.Color = Color3.fromRGB(150, 110, 240) end
		elseif d.Name == "RoseBoss" then
			d.Color = Color3.fromRGB(104, 98, 110)
			d.Material = Enum.Material.Slate
		end
	end
end

if MODE == "full" then
	local preview = workspace:FindFirstChild("WallCemeteryPreview")
	if preview then
		preview:Destroy()
		restoreNeutral(1)
	end
	local ServerStorage = game:GetService("ServerStorage")
	local lane = ServerStorage:FindFirstChild("LaneModels")
	if not lane then
		lane = Instance.new("Folder")
		lane.Name = "LaneModels"
		lane.Parent = ServerStorage
	end
	local old = lane:FindFirstChild("WallCemetery")
	if old then
		old:Destroy()
	end
	local root = Instance.new("Model")
	root.Name = "WallCemetery"
	folderStack = { root }
	gatehouse(0)
	handLedges(0)
	-- the bays, numbered from the gate outwards (alternating right / left): the crypts open in this order
	local index = 0
	for step = 1, 4 do
		for _, side in ipairs({ 1, -1 }) do
			index += 1
			bay(side * step * 5, index)
		end
	end
	for _, d in ipairs({ 7.5, 12.5, 17.5 }) do
		for _, side in ipairs({ -1, 1 }) do
			pier(side * d, d == 12.5 and "cross" or "gargoyle")
		end
	end
	battlements(-22, -2.2)
	battlements(2.2, 22)
	-- every crypt starts sealed (the server opens them)
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("Model") and d:GetAttribute("CryptState") == "Open" then
			for _, x in ipairs(d:GetDescendants()) do
				if x:IsA("BasePart") then
					x:SetAttribute("BaseTransparency", x.Transparency)
					x.Transparency = 1
				elseif x:IsA("Light") then
					x.Enabled = false
				end
			end
		elseif d:IsA("Model") and d:GetAttribute("CryptState") == "Sealed" then
			for _, x in ipairs(d:GetDescendants()) do
				if x:IsA("BasePart") then
					x:SetAttribute("BaseTransparency", x.Transparency)
				end
			end
		end
	end
	root:SetAttribute("Crypts", index)
	root.WorldPivot = CFrame.new() -- (the arena's centre: the server turns it round the Y axis to the plot's lane)
	root.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	root.Parent = lane
	local n = 0
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("BasePart") then n += 1 end
	end
	return "cemetery wall section: " .. n .. " parts, " .. index .. " crypts"
end

if MODE == "preview" then
	local DEG = 0 -- plot 1's lane
	local old = workspace:FindFirstChild("WallCemeteryPreview")
	if old then
		old:Destroy()
	end
	local root = Instance.new("Model")
	root.Name = "WallCemeteryPreview"
	folderStack = { root }
	gatehouse(DEG)
	bay(DEG - 5, 1)
	bay(DEG + 5, 2)
	pier(DEG - 7.5, "gargoyle")
	pier(DEG + 7.5, "gargoyle")
	battlements(DEG - 8.5, DEG - 2.2)
	battlements(DEG + 2.2, DEG + 8.5)
	-- one sealed, one open
	for _, b in ipairs({ root:FindFirstChild("Bay1"), root:FindFirstChild("Bay2") }) do
		local openIt = b.Name == "Bay2"
		for _, d in ipairs(b:FindFirstChild("Sealed"):GetDescendants()) do
			if d:IsA("BasePart") then d.Transparency = openIt and 1 or d.Transparency end
			if d:IsA("Light") then d.Enabled = not openIt end
		end
		for _, d in ipairs(b:FindFirstChild("Open"):GetDescendants()) do
			if d:IsA("BasePart") then d.Transparency = openIt and d.Transparency or 1 end
			if d:IsA("Light") then d.Enabled = openIt end
		end
	end
	root.Parent = workspace
	-- hide the neutral decorations of plot 1's section, green-gold glass in its rose window
	local ring = workspace:FindFirstChild("OuterWall")
	local section = ring and ring:FindFirstChild("Section1")
	local HIDE = { Buttress = true, ButtressStep = true, ButtressCap = true, Course = true, ArrowSlit = true, Merlon = true, MerlonSpike = true }
	for _, d in ipairs(section and section:GetDescendants() or {}) do
		if d:IsA("BasePart") and HIDE[d.Name] then
			d.Transparency = 1
		end
	end
	local tower = ring and ring:FindFirstChild("GateTower1")
	for _, d in ipairs(tower and tower:GetDescendants() or {}) do
		if d.Name == "RoseGlass" then
			d.Color = Color3.fromRGB(70, 140, 84)
			local l = d:FindFirstChildOfClass("SurfaceLight")
			if l then l.Color = SOUL end
		elseif d.Name == "RoseBoss" then
			d.Color = Color3.fromRGB(200, 160, 80)
			d.Material = Enum.Material.Metal
		end
	end
	local n = 0
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("BasePart") then n += 1 end
	end
	return "cemetery wall preview: " .. n .. " parts"
end
