-- Hush's gate finisher, THE LAST CROSS (docs/hush.md "Beat sheet"; timings: shared HushTimeline.FINISHER).
--
--   local started = HushFinisher.play(opts)
--     opts: startAt (server time), unit (his model), gate (Vector3), spectator (another player's), preview (Studio),
--           onDone
--     returns false when it cannot play (no Hush of yours, already running, too late to join).
--
-- Started by the SERVER for everyone (Army.checkFinisher; remote LastCross): every client plays the world part from the
-- same server time; the owner's camera is taken over (Skip only gives it back), other players see it over the owner's
-- lane and may press Watch. The server holds the gate and breaks it at GATE_HIT, whatever happens on any screen. The
-- army stands idle (it never flees in this one): on a watcher's screen the owner's units are hidden for the whole
-- finisher. His own body (the rise, the lifting arms, the snapping head) is UnitAnimator's Crucified pose, driven by the
-- client-only model attributes FinisherAt / FinisherKind this module sets.
--
-- Built in stages (2026-11-04). STAGE 1 (this file): the take-over, the camera shots, the darkening sky (watchers), the
-- purple storm (lightning that strikes more and more often behind him), his purple glow that pulses with every snap.
-- Next: the rifts and the chain swarm, the cross and its fall, the impact and the ravine, the end and the sounds.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local mainGui = require(script.Parent.Gui)
local Theme = require(script.Parent.Theme)
local CinematicGuard = require(script.Parent.CinematicGuard)
local F = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("HushTimeline")).FINISHER

local player = Players.LocalPlayer
local HushFinisher = {}
HushFinisher.active = false

local DURATION = F.END
local BAR_HEIGHT = 0.1
local BAR_TIME = 0.8
local CUT_BLEND = 1.4 -- seconds a camera shot takes to glide over from the one before

local VIOLET = Color3.fromRGB(150, 70, 255)
local VIOLET_PALE = Color3.fromRGB(215, 185, 255)
local VIOLET_DARK = Color3.fromRGB(46, 20, 84)

local BEATS = {
	{ at = F.RISE, name = "The rise" }, { at = F.STORM, name = "The storm" }, { at = F.SNAP, name = "The snapping" },
	{ at = F.RIFTS, name = "The rifts" }, { at = F.CHAINS, name = "The chains" }, { at = F.CROSS_RISE, name = "The cross rises" },
	{ at = F.CROSS, name = "The wrapping" }, { at = F.FALL, name = "The fall" }, { at = F.IMPACT, name = "The impact" },
	{ at = F.RAVINE, name = "The ravine" }, { at = F.DESCEND, name = "The descent" },
}

local function smooth(x)
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end
local function ease(x, a, b)
	return smooth((x - a) / (b - a))
end

local function newPart(folder, size, color, transparency, shape, material)
	local p = Instance.new("Part")
	p.Size = size
	p.Color = color
	p.Transparency = transparency or 0
	p.Material = material or Enum.Material.SmoothPlastic
	if shape then
		p.Shape = shape
	end
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = folder
	return p
end

local function findHush()
	local me = tostring(player.UserId)
	for _, m in ipairs(CollectionService:GetTagged("ProceduralUnit")) do
		if m.Name == "Hush" and m.Parent and m:GetAttribute("OwnerId") == me then
			return m
		end
	end
	return nil
end

-- the owner's army (every unit model of theirs but him), to hide on a watcher's screen
local function armyParts(ownerId, except)
	local parts = {}
	for _, d in ipairs(workspace:GetDescendants()) do
		if d:IsA("Model") and d ~= except and d:GetAttribute("AttackCount") ~= nil and d:GetAttribute("OwnerId") == ownerId then
			for _, p in ipairs(d:GetDescendants()) do
				if p:IsA("BasePart") then
					table.insert(parts, p)
				end
			end
		end
	end
	return parts
end

-- ============================================================
-- Lightning: a jagged bolt from the sky to the ground, a bright core in a wider glow, fading fast, with a flash of light
-- where it lands
-- ============================================================
local function lightning(folder, from, to, rng, width)
	local points = { from }
	local n = 11
	local jag = (from - to).Magnitude * 0.05
	for i = 1, n - 1 do
		local f = i / n
		points[#points + 1] = from:Lerp(to, f) + Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1)) * jag * (1 - 0.25 * f)
	end
	points[#points + 1] = to
	local made = {}
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local len = (b - a).Magnitude
		local cf = CFrame.lookAt((a + b) / 2, b)
		local core = newPart(folder, Vector3.new(width, width, len + 0.4), VIOLET_PALE, 0, nil, Enum.Material.Neon)
		core.CFrame = cf
		local glow = newPart(folder, Vector3.new(width * 3.6, width * 3.6, len + 0.4), VIOLET, 0.55, nil, Enum.Material.Neon)
		glow.CFrame = cf
		table.insert(made, core)
		table.insert(made, glow)
	end
	for _, p in ipairs(made) do
		TweenService:Create(p, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Transparency = 1 }):Play()
		Debris:AddItem(p, 0.6)
	end
	local flash = newPart(folder, Vector3.one * 0.2, VIOLET, 1)
	flash.Position = to + Vector3.new(0, 4, 0)
	local light = Instance.new("PointLight")
	light.Color = VIOLET
	light.Range = 90
	light.Brightness = 7
	light.Parent = flash
	TweenService:Create(light, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Brightness = 0 }):Play()
	Debris:AddItem(flash, 0.7)
end

-- ============================================================
-- The rifts (STAGE 2): the look of his Rift Chains special (SpecialFx.lua: a tall narrow torn oval, light leaking from
-- the rim, frayed spikes, flickering fragments), but huge. Every piece is moved with one BulkMoveTo per frame, so
-- `add(part, cf)` only collects.
-- ============================================================
local RIFT_DARK = Color3.fromRGB(14, 6, 24)
local RIFT_FILL = Color3.fromRGB(58, 14, 110)
local MAGENTA = Color3.fromRGB(230, 70, 200)
local CORE_WHITE = Color3.fromRGB(235, 215, 255)
local CHAIN_COLOR = Color3.fromRGB(135, 60, 225)
local CHAIN_HEAD = Color3.fromRGB(225, 190, 255)

local SLATS = 18

local function buildRift(folder, face, RX, RY, rng, segments, pieceScale)
	local s = pieceScale or (RY / 2.5)
	segments = segments or 20
	local rift = { face = face, RX = RX, RY = RY, rims = {}, spikes = {}, frags = {}, vis = nil, items = {} }
	local function item(part, baseT)
		part.Transparency = 1
		table.insert(rift.items, { part = part, baseT = baseT })
		return part
	end
	-- (a cylinder part draws as a circle at its smaller diameter, so the tall oval is a stack of thin slats instead)
	rift.slats = {}
	for i = 1, SLATS do
		table.insert(rift.slats, {
			-- (a deep violet that glows a little: pure black vanishes against the night sky)
			core = item(newPart(folder, Vector3.new(0.5, 1, 1), RIFT_FILL, 1, nil, Enum.Material.Neon), 0.1),
			glow = item(newPart(folder, Vector3.new(0.4, 1, 1), VIOLET, 1, nil, Enum.Material.Neon), 0.78),
		})
	end
	rift.lightPart = item(newPart(folder, Vector3.one * 0.2, VIOLET, 1), 1)
	local light = Instance.new("PointLight")
	light.Color = VIOLET
	light.Range = 130
	light.Brightness = 0
	light.Shadows = false
	light.Parent = rift.lightPart
	rift.light = light
	for k = 0, segments - 1 do
		local a = k / segments * math.pi * 2
		table.insert(rift.rims, { part = item(newPart(folder, Vector3.new(0.5, 0.1, 0.07) * s, CORE_WHITE, 1, nil, Enum.Material.Neon), 0), a = a, r = 1 + rng:NextNumber(-0.18, 0.18), z = -0.02 * s })
		table.insert(rift.rims, { part = item(newPart(folder, Vector3.new(0.42, 0.14, 0.06) * s, VIOLET, 1, nil, Enum.Material.Neon), 0), a = a + 0.15, r = 1.1 + rng:NextNumber(-0.15, 0.2), z = 0 })
	end
	for _ = 1, 10 do
		local len = rng:NextNumber(0.4, 1.1) * s
		table.insert(rift.spikes, { part = item(newPart(folder, Vector3.new(len, 0.06 * s, 0.05 * s), MAGENTA, 1, nil, Enum.Material.Neon), 0.1), a = rng:NextNumber(0, math.pi * 2), len = len })
	end
	for _ = 1, 8 do
		table.insert(rift.frags, { part = item(newPart(folder, Vector3.new(0.05, 0.25, 0.25) * s, CORE_WHITE, 1, nil, Enum.Material.Neon), 0.2), a = rng:NextNumber(0, math.pi * 2), r = rng:NextNumber(1.3, 2.0), spin = rng:NextNumber(-3, 3), blink = rng:NextNumber(4, 11) })
	end
	return rift
end

-- one frame of a rift: `st` seconds since it started opening, `closeF` 0..1 while it zips shut; returns whether it shows
local function updateRift(rift, now, st, closeF, add)
	local face, RX, RY = rift.face, rift.RX, rift.RY
	local snap = math.clamp(st / 0.5, 0, 1)
	local openY = snap < 1 and (1 - (1 - snap) ^ 3) * 1.08 or 1
	local sx = (snap > 0 and 1 or 0) * (1 - smooth(closeF * 1.4)) * (1 + math.sin(now * 11) * 0.06)
	local sy = openY * (1 - smooth(math.max(0, closeF - 0.3) / 0.7))
	local visible = sx > 0.01 and sy > 0.01
	if visible ~= rift.vis then
		rift.vis = visible
		for _, it in ipairs(rift.items) do
			it.part.Transparency = visible and it.baseT or 1
		end
	end
	rift.light.Brightness = visible and 3.5 * sy or 0
	add(rift.lightPart, face)
	for i, slat in ipairs(rift.slats) do
		local u = ((i - 0.5) / SLATS) * 2 - 1
		local half = math.sqrt(math.max(0, 1 - u * u))
		local h = (2 * RY * sy / SLATS) * 1.08 + 0.01
		local y = u * RY * sy
		-- (the face's local Z is its normal: a slat is wide along X, tall along Y and thin along Z)
		slat.core.Size = Vector3.new(2 * RX * sx * half + 0.01, h, 0.5)
		add(slat.core, face * CFrame.new(0, y, 0))
		slat.glow.Size = Vector3.new(2.6 * RX * sx * math.sqrt(math.max(0, 1 - (u * 0.92) ^ 2)) + 0.01, h, 0.4)
		add(slat.glow, face * CFrame.new(0, y, 0.5))
	end
	for _, r in ipairs(rift.rims) do
		local jitter = 1 + math.sin(now * 17 + r.a * 7) * 0.07
		local pos = Vector3.new(math.cos(r.a) * RX * sx * r.r * jitter, math.sin(r.a) * RY * sy * r.r * jitter, r.z)
		local tangent = Vector3.new(-math.sin(r.a) * RX * sx, math.cos(r.a) * RY * sy, 0)
		add(r.part, face * CFrame.new(pos) * CFrame.Angles(0, 0, math.atan2(tangent.Y, tangent.X)))
	end
	for _, sp in ipairs(rift.spikes) do
		local edge = Vector3.new(math.cos(sp.a) * RX * sx, math.sin(sp.a) * RY * sy, 0)
		local out = Vector3.new(math.cos(sp.a) * RY, math.sin(sp.a) * RX, 0).Unit
		local len = sp.len * (0.7 + 0.3 * math.sin(now * 12 + sp.a * 3))
		sp.part.Size = Vector3.new(len, sp.part.Size.Y, sp.part.Size.Z)
		add(sp.part, face * CFrame.new(edge + out * len / 2) * CFrame.Angles(0, 0, math.atan2(out.Y, out.X)))
	end
	for _, fr in ipairs(rift.frags) do
		local a = fr.a + now * 0.6
		local pos = Vector3.new(math.cos(a) * RX * fr.r * 1.6 * sx, math.sin(a) * RY * fr.r * 0.7 * sy, 1.2)
		add(fr.part, face * CFrame.new(pos) * CFrame.Angles(now * fr.spin, now * fr.spin * 0.6, 0))
		fr.part.Transparency = (visible and math.sin(now * fr.blink + fr.a) > -0.3) and 0.2 or 1
	end
	return visible
end

-- ============================================================
-- The chains (STAGE 2): huge chains of glowing links creep out of the rifts, slowly and heavy, wriggling; then they
-- speed up and whip round the sky in a wild swarm. A chain is the path its head flew (precomputed) with links trailing
-- at a fixed spacing along it (alternate links turned 90 degrees). The swarm hands over to the cross in stage 3.
-- ============================================================
local LINK_SPACING = 4.6
local LINK_COUNT = 56 -- long enough to wind several times round a beam
local SAMPLE_DT = 1 / 45
local APPROACH_TIME = 1.4 -- seconds a chain's head takes to fly from the swarm to the start of its spiral round the cross
local WIND_TIME = 4.5 -- seconds its head takes to wind along the spiral
local CROSS_HOVER = 5 -- studs the cross floats above the floor once it has risen

-- the point `d` studs along the chain's path (clamped), and a point a little further on (to aim the link)
local function along(c, d)
	local dist, samples = c.dist, c.samples
	local hi = #dist
	if d <= 0 then
		return samples[1], samples[math.min(2, hi)]
	end
	if d >= dist[hi] then
		return samples[hi], samples[hi] + (samples[hi] - samples[math.max(1, hi - 1)])
	end
	local lo = 1
	while hi - lo > 1 do
		local mid = (lo + hi) // 2
		if dist[mid] < d then
			lo = mid
		else
			hi = mid
		end
	end
	local f = (d - dist[lo]) / math.max(1e-6, dist[hi] - dist[lo])
	return samples[lo]:Lerp(samples[hi], f), samples[hi]
end

local function bezier(p0, p1, p2, p3, s)
	local u = 1 - s
	return p0 * (u * u * u) + p1 * (3 * u * u * s) + p2 * (3 * u * s * s) + p3 * (s * s * s)
end

-- a point of the spiral a chain winds round the cross, in the cross's own frame (x across the lane, y up, z depth): u 0..1
-- along its beam, `rx` / `rz` the radii round the beam, `turns` how often it goes round
local function spiralPoint(c, u)
	local phi = c.phase + c.sign * c.turns * 2 * math.pi * u
	if c.vertical then
		return Vector3.new(c.rx * math.cos(phi), u * c.axis, c.rz * math.sin(phi))
	end
	return Vector3.new((u - 0.5) * c.axis, c.armY + c.rx * math.cos(phi), c.rz * math.sin(phi))
end

-- A chain is the path its HEAD flew (precomputed) with the links trailing at a fixed spacing along it. The head creeps out
-- of a sky rift, speeds up into the swarm, and at `c.tc` is handed to the cross: it flies to the start of its spiral and
-- winds round a beam (the whole chain ends up lying on the spiral: `c.slots` are the links' resting places in the
-- cross's frame, used once it has finished so the cross can fall with them).
local function buildChain(folder, c, rng, ctx)
	c.fx = { rng:NextNumber(0.9, 1.2), rng:NextNumber(1.2, 1.6), rng:NextNumber(1.5, 2.0) }
	c.ph = { rng:NextNumber(0, 6.28), rng:NextNumber(0, 6.28), rng:NextNumber(0, 6.28) }
	c.amp = { rng:NextNumber(55, 85), rng:NextNumber(25, 42), rng:NextNumber(55, 90) }
	local function creepPos(t)
		local s = math.max(0, t - c.t0)
		local reach = 4.5 * s + 0.45 * s * s
		local f = math.min(1, s / 3)
		local wiggle = c.side * math.sin(s * c.wFreq + c.wPhase) * 2.4 * f + Vector3.yAxis * math.sin(s * c.wFreq * 0.8 + c.wPhase * 1.7) * 1.6 * f
		return c.origin + c.dir * reach + wiggle
	end
	local function swarmPos(t)
		local s = math.max(0, t - c.tSwarm)
		local theta = 0.22 * s + 0.075 * s * s
		return ctx.swarmCentre
			+ ctx.right * (c.amp[1] * math.sin(c.fx[1] * theta + c.ph[1]))
			+ Vector3.yAxis * (c.amp[2] * math.sin(c.fx[2] * theta + c.ph[2]))
			+ ctx.front * (c.amp[3] * math.sin(c.fx[3] * theta + c.ph[3]))
	end
	local function swarmHead(t)
		local b = smooth((t - c.tSwarm) / 3)
		if b <= 0 then
			return creepPos(t)
		end
		return creepPos(t):Lerp(swarmPos(t), b)
	end

	-- the spiral: long enough for the whole chain (10 % spare), its arc length tabulated
	local S = (LINK_COUNT - 1) * LINK_SPACING * 1.1
	c.turns = math.sqrt(math.max(0, S * S - c.axis * c.axis)) / (2 * math.pi * (c.rx + c.rz) / 2)
	local STEPS = 600
	local arc, prev, total = { 0 }, spiralPoint(c, 0), 0
	for i = 1, STEPS do
		local p = spiralPoint(c, i / STEPS)
		total += (p - prev).Magnitude
		arc[i + 1] = total
		prev = p
	end
	local function uAt(len)
		local lo, hi = 1, STEPS + 1
		while hi - lo > 1 do
			local mid = (lo + hi) // 2
			if arc[mid] < len then
				lo = mid
			else
				hi = mid
			end
		end
		return ((lo - 1) + (len - arc[lo]) / math.max(1e-6, arc[hi] - arc[lo])) / STEPS
	end
	local frame = ctx.crossStatic
	local function spiralWorld(len)
		return frame * spiralPoint(c, uAt(math.clamp(len, 0, total)))
	end

	c.tWind = c.tc + APPROACH_TIME
	c.tEnd = c.tWind + WIND_TIME + 0.1
	local p0 = swarmHead(c.tc)
	local vel = (swarmHead(c.tc + 0.05) - p0) / 0.05
	local startP = spiralWorld(0)
	local startTan = (spiralWorld(2) - startP).Unit
	local function head(t)
		if t < c.tc then
			return swarmHead(t)
		elseif t < c.tWind then
			local x = (t - c.tc) / APPROACH_TIME
			local f = 0.5 * x + 0.5 * smooth(x) -- (it does not stop dead: the swarm is fast)
			return bezier(p0, p0 + vel * 0.5, startP - startTan * 14, startP, f)
		end
		return spiralWorld(total * smooth((t - c.tWind) / WIND_TIME))
	end

	c.samples, c.dist = {}, {}
	local run, last = 0, nil
	local t = c.t0
	while t <= c.tEnd do
		local p = head(t)
		if last then
			run += (p - last).Magnitude
		end
		c.samples[#c.samples + 1] = p
		c.dist[#c.dist + 1] = run
		last = p
		t += SAMPLE_DT
	end
	c.links = {}
	for j = 1, LINK_COUNT do
		local big = j == 1
		local part = newPart(folder, big and Vector3.new(1.8, 1.8, 5.2) or Vector3.new(1.0, 3.2, 4.4), big and CHAIN_HEAD or CHAIN_COLOR, 1, nil, Enum.Material.Neon)
		c.links[j] = { part = part, shown = false }
	end
	-- the resting places: where each link lies when the head has finished (in the cross's frame)
	c.slots = {}
	local inverse = frame:Inverse()
	for j = 1, LINK_COUNT do
		local d = run - (j - 1) * LINK_SPACING
		local p = along(c, d)
		local q = along(c, d + 1.2)
		if (q - p).Magnitude < 1e-3 then
			q = p + Vector3.zAxis
		end
		c.slots[j] = inverse * (CFrame.lookAt(p, q) * CFrame.Angles(0, 0, (j % 2 == 0) and math.pi / 2 or 0))
	end
	return c
end

-- ============================================================
-- The cross itself (STAGE 3, rebuilt 2026-11-05): a solid cross of black stone with iron bands, a boss at the crossing and
-- runes glowing violet along its faces, in its own frame (x across the lane, y up the beam from the foot, z depth). It
-- floats up out of a rift in the ground; the chains then wind round it.
-- ============================================================
local STONE = Color3.fromRGB(88, 74, 112) -- (black stone vanishes against the night sky: a dim violet-grey stone, lit by lights)
local IRON = Color3.fromRGB(130, 118, 150)

local function buildCrossModel(folder, L, ARM)
	local parts = {}
	local armY = 0.7 * L
	local function block(size, cf, color, material, baseT)
		local p = newPart(folder, size, color, 0, nil, material)
		table.insert(parts, { part = p, cf = cf, baseT = baseT or 0 })
		if baseT then
			p.Transparency = baseT
		end
	end
	block(Vector3.new(16, L, 10), CFrame.new(0, L / 2, 0), STONE, Enum.Material.Slate)
	block(Vector3.new(ARM, 14, 10), CFrame.new(0, armY, 0), STONE, Enum.Material.Slate)
	block(Vector3.new(20, 5, 12), CFrame.new(0, L + 2.5, 0), IRON, Enum.Material.Metal) -- the cap on the top
	for _, side in ipairs({ -1, 1 }) do
		block(Vector3.new(5, 17, 12), CFrame.new(side * (ARM / 2 + 2.5), armY, 0), IRON, Enum.Material.Metal) -- the caps on the arms
	end
	block(Vector3.new(24, 24, 12.5), CFrame.new(0, armY, 0), IRON, Enum.Material.Metal) -- the boss at the crossing
	block(Vector3.new(12, 10, 8), CFrame.new(0, -3, 0), IRON, Enum.Material.Metal) -- the foot
	block(Vector3.new(6, 16, 6), CFrame.new(0, -14, 0), IRON, Enum.Material.Metal)
	for _, y in ipairs({ 0.12 * L, 0.34 * L, 0.88 * L }) do
		block(Vector3.new(18.6, 3, 11.6), CFrame.new(0, y, 0), IRON, Enum.Material.Metal) -- bands round the beam
	end
	for _, x in ipairs({ -0.38 * ARM, -0.2 * ARM, 0.2 * ARM, 0.38 * ARM }) do
		block(Vector3.new(3, 16.6, 11.6), CFrame.new(x, armY, 0), IRON, Enum.Material.Metal) -- bands round the arms
	end
	for _, z in ipairs({ -5.15, 5.15 }) do
		block(Vector3.new(1.2, L - 16, 0.5), CFrame.new(0, L / 2, z), VIOLET, Enum.Material.Neon, 0.1) -- the runes
		block(Vector3.new(ARM - 34, 1.2, 0.5), CFrame.new(0, armY, z), VIOLET, Enum.Material.Neon, 0.1)
		for i = 1, 7 do
			block(Vector3.new(3, 3, 0.5), CFrame.new(((i % 2 == 0) and 3.5 or -3.5), (i / 8) * L, z * 1.02), VIOLET_PALE, Enum.Material.Neon, 0.15)
		end
	end
	-- violet lights on both faces so the stone and the iron can be seen
	for _, z in ipairs({ -15, 15 }) do
		for _, y in ipairs({ 0.12 * L, 0.38 * L, armY, 0.9 * L }) do
			local lp = newPart(folder, Vector3.one * 0.4, VIOLET, 1)
			local light = Instance.new("PointLight")
			light.Color = Color3.fromRGB(190, 130, 255)
			light.Range = 70
			light.Brightness = 2.2
			light.Shadows = false
			light.Parent = lp
			table.insert(parts, { part = lp, cf = CFrame.new(0, y, z), baseT = 1 })
		end
	end
	return parts
end

-- ============================================================
-- The impact (STAGE 4): the cross's tip hits the gate at IMPACT: a white flash, lightning from the tip, a dust cloud,
-- chunks of stone thrown back down the lane, a hard shake
-- ============================================================
local function buildImpact(folder, ctx, rng)
	local tip = (CFrame.new(0, CROSS_HOVER, 0) * ctx.crossBase * CFrame.Angles(-ctx.thetaHit, 0, 0) * CFrame.new(0, ctx.crossL, 0)).Position
	ctx.tip = tip
	local done = false
	local debris = {}
	local function fire()
		done = true
		ctx.flash = 0.8
		local ball = newPart(folder, Vector3.one * 8, VIOLET_PALE, 0.25, Enum.PartType.Ball, Enum.Material.Neon)
		ball.Position = tip
		TweenService:Create(ball, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.one * 70, Transparency = 1 }):Play()
		Debris:AddItem(ball, 0.8)
		local lightPart = newPart(folder, Vector3.one * 0.2, VIOLET, 1)
		lightPart.Position = tip
		local light = Instance.new("PointLight")
		light.Color = VIOLET
		light.Range = 160
		light.Brightness = 8
		light.Parent = lightPart
		TweenService:Create(light, TweenInfo.new(1.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Brightness = 0 }):Play()
		Debris:AddItem(lightPart, 1.6)
		local dust = newPart(folder, Vector3.one * 0.2, VIOLET, 1)
		dust.Position = tip
		local em = Instance.new("ParticleEmitter")
		em.Texture = "rbxasset://textures/particles/smoke_main.dds"
		em.Color = ColorSequence.new(Color3.fromRGB(96, 70, 130), Color3.fromRGB(24, 18, 34))
		em.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 10), NumberSequenceKeypoint.new(1, 42) })
		em.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) })
		em.Lifetime = NumberRange.new(2, 3.4)
		em.Speed = NumberRange.new(18, 60)
		em.SpreadAngle = Vector2.new(180, 180)
		em.Rotation = NumberRange.new(0, 360)
		em.Drag = 1.2
		em.Rate = 0
		em.Parent = dust
		em:Emit(90)
		Debris:AddItem(dust, 4)
		for _ = 1, 7 do
			local dir = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(0.1, 1), rng:NextNumber(-1, 1)).Unit
			lightning(folder, tip + dir * rng:NextNumber(45, 90), tip, rng, 1.4)
		end
		for i = 1, 26 do
			local part = newPart(folder, Vector3.new(rng:NextNumber(1, 3.5), rng:NextNumber(1, 3), rng:NextNumber(1, 3.5)), Color3.fromRGB(46, 38, 52), 0)
			debris[i] = {
				part = part,
				pos = tip + ctx.right * rng:NextNumber(-12, 12) + Vector3.new(0, rng:NextNumber(-6, 6), 0),
				vel = -ctx.front * rng:NextNumber(10, 50) + ctx.right * rng:NextNumber(-35, 35) + Vector3.new(0, rng:NextNumber(5, 45), 0),
				spin = Vector3.new(rng:NextNumber(-5, 5), rng:NextNumber(-5, 5), rng:NextNumber(-5, 5)),
				rot = CFrame.new(),
			}
		end
	end
	return {
		update = function(T, dt)
			if not done and T >= F.IMPACT then
				if T - F.IMPACT < 1.5 then
					fire()
				else
					done = true -- (joined too late to see it)
				end
			end
			local t = T - F.IMPACT
			if t >= 0 and t < 3 then
				ctx.shake = math.max(ctx.shake or 0, 3 * math.exp(-t * 2.2))
			end
			for _, d in ipairs(debris) do
				if d.part.Parent then
					if t > 3.2 then
						d.part:Destroy()
					else
						if d.pos.Y > ctx.ground.Y + 1 then
							d.vel += Vector3.new(0, -90 * dt, 0)
							d.pos += d.vel * dt
							d.rot = CFrame.Angles(d.spin.X * dt, d.spin.Y * dt, d.spin.Z * dt) * d.rot
						end
						d.part.CFrame = CFrame.new(d.pos) * d.rot
						d.part.Transparency = smooth((t - 2.4) / 0.8)
					end
				end
			end
		end,
	}
end

-- ============================================================
-- The ravine (STAGE 4): at the very moment the cross hits, a crack tears open at the gate, climbs the gate tower and races back down the lane under the fallen cross to his post; formerly it ran from his post, through the gate and
-- up the outer wall's gate tower (only ~8 studs behind the gate). Laid on the floor and the wall face: a black core
-- with a glowing violet heart, glowing rim strips that flash white when it opens, chunks of broken stone along the lips,
-- side cracks, rising embers. Every piece is static (made once, revealed by the front).
-- ============================================================
local RAVINE_FLOOR_TIME = 2.6 -- seconds the front takes from the gate back to his post
local RAVINE_WALL_TIME = 1.5 -- ... and up the wall
local WALL_HEIGHT = 70

local function buildRavine(folder, ctx, rng)
	local up = Vector3.yAxis
	local front, right = ctx.front, ctx.right
	local floorY = ctx.ground.Y + 0.12
	local gateFlat = Vector3.new(ctx.gate.X, floorY, ctx.gate.Z)
	local startFlat = Vector3.new(ctx.ground.X, floorY, ctx.ground.Z) + front * 8
	-- the outer wall's face behind the gate
	local face, normal = gateFlat + front * 14, -front
	do
		local outer = workspace:FindFirstChild("OuterWall")
		local params = RaycastParams.new()
		if outer then
			params.FilterType = Enum.RaycastFilterType.Include
			params.FilterDescendantsInstances = { outer }
		else
			params.FilterType = Enum.RaycastFilterType.Exclude
			params.FilterDescendantsInstances = { folder }
		end
		local hit = workspace:Raycast(gateFlat + up * 10, front * 140, params)
		if hit then
			face = Vector3.new(hit.Position.X, floorY, hit.Position.Z)
			normal = Vector3.new(hit.Normal.X, 0, hit.Normal.Z)
			normal = normal.Magnitude > 0.1 and normal.Unit or -front
		end
	end
	local ravine = { gateFloor = gateFlat, wallBase = face + normal * 0.4, normal = normal }
	ctx.ravine = ravine

	local pieces = {}
	local emitters = {}
	local function piece(size, color, cf, material, baseT, revealAt, edge)
		local p = newPart(folder, size, color, 1, nil, material)
		p.CFrame = cf
		table.insert(pieces, { part = p, baseT = baseT, at = revealAt, edge = edge, shown = false })
		return p
	end
	local DARK = Color3.fromRGB(8, 4, 14)
	local HEART = Color3.fromRGB(235, 95, 255)
	local LIP = Color3.fromRGB(26, 20, 34)
	local function lips(cf, w, len, revealAt, count, onWall)
		for _ = 1, count do
			local side = rng:NextInteger(0, 1) == 0 and -1 or 1
			local size = Vector3.new(rng:NextNumber(0.8, 2.2), rng:NextNumber(0.6, 1.7), rng:NextNumber(1.2, 2.8))
			local along = rng:NextNumber(-len / 2, len / 2)
			local at = onWall and CFrame.new(side * (w / 2 + rng:NextNumber(0.3, 1.2)), along, 0.7) or CFrame.new(side * (w / 2 + rng:NextNumber(0.3, 1.2)), 0.4, along)
			piece(size, LIP, cf * at * CFrame.Angles(rng:NextNumber(-0.4, 0.4), rng:NextNumber(-0.6, 0.6), rng:NextNumber(-0.5, 0.5)), nil, 0, revealAt)
		end
	end
	local function floorSeg(a, b, w, revealAt, withLips)
		local dir = b - a
		local len = dir.Magnitude
		if len < 0.5 then
			return
		end
		local mid = (a + b) / 2
		local cf = CFrame.lookAt(mid, mid + dir)
		piece(Vector3.new(w, 0.2, len + 1.5), DARK, cf, nil, 0, revealAt)
		piece(Vector3.new(w * 0.6, 0.25, len + 0.5), HEART, cf * CFrame.new(0, 0.06, 0), Enum.Material.Neon, 0.05, revealAt)
		for _, s in ipairs({ -1, 1 }) do
			piece(Vector3.new(0.8, 0.35, len + 1.2), VIOLET, cf * CFrame.new(s * w / 2, 0.08, 0), Enum.Material.Neon, 0, revealAt, true)
		end
		if withLips then
			lips(cf, w, len, revealAt, 2, false)
		end
		return mid
	end
	local function wallSeg(centre, w, len, revealAt, withLips)
		local t = up:Cross(normal).Unit
		local cf = CFrame.fromMatrix(centre, t, up, normal)
		piece(Vector3.new(w, len + 1.5, 0.25), DARK, cf, nil, 0, revealAt)
		piece(Vector3.new(w * 0.6, len + 0.5, 0.3), HEART, cf * CFrame.new(0, 0, 0.08), Enum.Material.Neon, 0.05, revealAt)
		for _, s in ipairs({ -1, 1 }) do
			piece(Vector3.new(0.8, len + 1.2, 0.35), VIOLET, cf * CFrame.new(s * w / 2, 0, 0.1), Enum.Material.Neon, 0, revealAt, true)
		end
		if withLips then
			lips(cf, w, len, revealAt, 2, true)
		end
	end
	local function embers(at, revealAt)
		local p = newPart(folder, Vector3.new(2, 0.2, 2), VIOLET, 1)
		p.Position = at + up * 0.5
		local sparks = Instance.new("ParticleEmitter")
		sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		sparks.Color = ColorSequence.new(CORE_WHITE, VIOLET)
		sparks.LightEmission = 1
		sparks.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.1), NumberSequenceKeypoint.new(1, 0) })
		sparks.Lifetime = NumberRange.new(1.5, 2.8)
		sparks.Speed = NumberRange.new(6, 16)
		sparks.SpreadAngle = Vector2.new(30, 30)
		sparks.EmissionDirection = Enum.NormalId.Top
		sparks.Acceleration = Vector3.new(0, 4, 0)
		sparks.Rate = 0
		sparks.Parent = p
		local glowLight = Instance.new("PointLight")
		glowLight.Color = VIOLET
		glowLight.Range = 34
		glowLight.Brightness = 0
		glowLight.Shadows = false
		glowLight.Parent = p
		table.insert(emitters, { sparks = sparks, light = glowLight, at = revealAt })
	end

	-- ── the floor: from his post to the gate ──
	local total = (gateFlat - startFlat):Dot(front)
	local n = math.max(2, math.ceil(total / 7))
	local points, widths, reveals = {}, {}, {}
	local lat = 0
	for i = 0, n do
		local f = i / n
		lat = math.clamp(lat + rng:NextNumber(-1.6, 1.6), -5, 5) * (i == n and 0 or 1)
		points[i] = startFlat + front * (total * f) + right * lat
		widths[i] = 4.5 + rng:NextNumber(0, 3.5) + 9 * f ^ 3
		reveals[i] = F.RAVINE + RAVINE_FLOOR_TIME * (1 - f) ^ 0.85 -- (from the gate back towards him)
	end
	for i = 0, n - 1 do
		local mid = floorSeg(points[i], points[i + 1], widths[i], reveals[i], true)
		if mid and i % 3 == 0 then
			embers(mid, reveals[i])
		end
	end
	-- side cracks branching off at random points
	for _ = 1, 14 do
		local i = rng:NextInteger(2, n - 2)
		local side = rng:NextInteger(0, 1) == 0 and -1 or 1
		local angle = math.rad(rng:NextNumber(35, 70)) * side
		local dir = (CFrame.Angles(0, angle, 0) * CFrame.lookAt(Vector3.zero, front)).LookVector
		local p = points[i]
		local w = rng:NextNumber(1.6, 2.8)
		for k = 1, rng:NextInteger(3, 6) do
			local nextP = p + (dir + right * rng:NextNumber(-0.25, 0.25)).Unit * rng:NextNumber(5, 8)
			floorSeg(p, nextP, w, reveals[i] + 0.12 * k, false)
			p = nextP
			w = math.max(0.8, w * 0.82)
		end
	end

	-- ── the wall: up the gate tower ──
	local base = face + normal * 0.4
	local t = up:Cross(normal).Unit
	local wallLat = 0
	local SEG = 6
	for h = 0, WALL_HEIGHT - SEG, SEG do
		wallLat = math.clamp(wallLat + rng:NextNumber(-1.8, 1.8), -4, 4)
		local f = h / WALL_HEIGHT
		wallSeg(base + t * wallLat + up * (h + SEG / 2), 10 - 5.5 * f + rng:NextNumber(0, 1.5), SEG, F.RAVINE + RAVINE_WALL_TIME * f, true)
		if h % 12 == 0 then
			embers(base + t * wallLat + up * h, F.RAVINE + RAVINE_WALL_TIME * f)
		end
	end
	for _ = 1, 6 do
		local h = rng:NextNumber(8, WALL_HEIGHT - 12)
		local side = rng:NextInteger(0, 1) == 0 and -1 or 1
		local x = side * 3
		local y = h
		for k = 1, rng:NextInteger(3, 5) do
			local nx, ny = x + side * rng:NextNumber(3, 6), y + rng:NextNumber(-2, 5)
			wallSeg(base + t * ((x + nx) / 2) + up * ((y + ny) / 2), 1.8, 6, F.RAVINE + RAVINE_WALL_TIME * (h / WALL_HEIGHT) + 0.12 * k, false)
			x, y = nx, ny
		end
	end

	function ravine.update(T)
		local fadeOut = ease(T, F.DESCEND, F.END - 1)
		for _, pc in ipairs(pieces) do
			if T >= pc.at then
				if not pc.shown then
					pc.shown = true
					if pc.edge then
						-- the rim flares white as it tears open, then cools to violet
						pc.part.Color = CORE_WHITE
						TweenService:Create(pc.part, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Color = VIOLET }):Play()
					end
				end
				pc.part.Transparency = pc.baseT + (1 - pc.baseT) * fadeOut
			end
		end
		for _, e in ipairs(emitters) do
			if T >= e.at and not e.on then
				e.on = true
				e.sparks:Emit(10)
			end
			if e.on then
				e.sparks.Rate = 5 * (1 - fadeOut)
				e.light.Brightness = 1.8 * (1 - fadeOut)
			end
		end
	end
	return ravine
end

-- ============================================================
-- The world part (everyone sees it, watching or not)
-- ============================================================
local function world(folder, ctx)
	local unit = ctx.unit
	local L = ctx.L
	local behind = -L.LookVector
	local right = L.RightVector
	local rng = Random.new(math.floor(ctx.startAt))

	-- his glow: a purple fill that swells with the storm and pulses with every snap, and the light it throws
	local highlight = Instance.new("Highlight")
	highlight.Adornee = unit
	highlight.FillColor = VIOLET
	highlight.OutlineColor = VIOLET_PALE
	highlight.FillTransparency = 1
	highlight.OutlineTransparency = 1
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = folder
	local glowPart = newPart(folder, Vector3.one * 0.2, VIOLET, 1)
	local glowLight = Instance.new("PointLight")
	glowLight.Color = VIOLET
	glowLight.Range = 46
	glowLight.Brightness = 0
	glowLight.Parent = glowPart

	-- the storm: strikes behind him, further apart at first, then every few tenths of a second; a strike on every snap
	local strikes = {}
	local t = F.STORM + 0.3
	while t < F.IMPACT - 2 do
		table.insert(strikes, { at = t, fired = false })
		local k = ease(t, F.STORM, F.SNAP + 4)
		t += (1.5 - 1.15 * k) * (0.75 + rng:NextNumber() * 0.5)
	end
	for _, s in ipairs(F.SNAPS) do
		table.insert(strikes, { at = s + 0.02, fired = false, big = true })
	end

	local function glowAmount(T)
		return ease(T, F.STORM, F.STORM + 3) * (1 - ease(T, F.END - 8, F.END - 1))
	end
	local function snapPulse(T)
		local sum = 0
		for _, s in ipairs(F.SNAPS) do
			local d = T - s
			if d >= 0 and d < 1.5 then
				sum += math.exp(-d * 5)
			end
		end
		return math.min(sum, 1.3)
	end

	-- ── STAGE 2: the rifts and the chains, built once he has risen (so they sit round where he really hangs) ──
	local bulkParts, bulkCFs, nBulk = {}, {}, 0
	local function add(part, cf)
		nBulk += 1
		bulkParts[nBulk] = part
		bulkCFs[nBulk] = cf
	end
	local rifts, chains, ravine, impact, crossParts, groundSparks
	local function buildStage2()
		local top = ctx.H
		ctx.swarmCentre = top + ctx.front * math.min(ctx.laneDist * 0.35, 70) + Vector3.new(0, 14, 0)
		rifts, chains = {}, {}

		-- ── the cross's place first (the chains wind round it). It stands on the lane, its foot far enough before the gate
		-- that, hinged at the foot and toppling forward, its top lands on the gate face (a tree felled onto a wall). ──
		local L = math.clamp((ctx.laneDist - 40) / math.sin(math.rad(70)), 100, 150)
		ctx.crossL = L
		ctx.thetaHit = math.rad(70)
		ctx.armSpan = 0.64 * L
		local gateFlat = Vector3.new(ctx.gate.X, ctx.ground.Y, ctx.gate.Z)
		local foot = gateFlat - ctx.front * (L * math.sin(ctx.thetaHit)) + Vector3.new(0, -1, 0)
		ctx.crossFoot = foot
		ctx.crossBase = CFrame.fromMatrix(foot, ctx.right, Vector3.yAxis, -ctx.front)
		ctx.crossStatic = CFrame.new(0, CROSS_HOVER, 0) * ctx.crossBase
		-- how high the whole cross is lifted: deep under the floor until CROSS_RISE, then it floats up out of the rift
		function ctx.crossLift(t)
			return -(L + 14) + (L + 14 + CROSS_HOVER) * ease(t, F.CROSS_RISE, F.CROSS - 0.5)
		end

		-- the rift in the lane floor the cross rises out of: wide enough for its arms
		local groundFace = CFrame.fromMatrix(foot + Vector3.new(0, 1.4, 0), ctx.right, ctx.front, Vector3.yAxis)
		table.insert(rifts, { rift = buildRift(folder, groundFace, 54, 15, rng, 56, 7), openAt = F.GROUND_RIFT })
		groundSparks = {}
		for i = -4, 4 do
			local part = newPart(folder, Vector3.new(6, 0.2, 6), VIOLET, 1)
			part.Position = foot + ctx.right * (i * 12) + Vector3.new(0, 2, 0)
			local sparks = Instance.new("ParticleEmitter")
			sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
			sparks.Color = ColorSequence.new(CORE_WHITE, VIOLET)
			sparks.LightEmission = 1
			sparks.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.6), NumberSequenceKeypoint.new(1, 0) })
			sparks.Lifetime = NumberRange.new(1.6, 2.8)
			sparks.Speed = NumberRange.new(25, 55)
			sparks.SpreadAngle = Vector2.new(16, 16)
			sparks.EmissionDirection = Enum.NormalId.Top
			sparks.Acceleration = Vector3.new(0, 6, 0)
			sparks.Rate = 0
			sparks.Parent = part
			table.insert(groundSparks, sparks)
		end
		crossParts = buildCrossModel(folder, L, ctx.armSpan)

		-- ── five rifts in the sky behind him (the middle one first, then outwards) and the chains that come out of them ──
		local slots = {
			{ lat = 0, dist = 48, tilt = 0, order = 0 }, { lat = -48, dist = 55, tilt = 12, order = 1 }, { lat = 48, dist = 55, tilt = -10, order = 2 },
			{ lat = -95, dist = 70, tilt = -18, order = 3 }, { lat = 95, dist = 70, tilt = 20, order = 4 },
		}
		local perRift = { 2, 3, 3, 2, 2 }
		for k, slot in ipairs(slots) do
			local centre = top + behind * slot.dist + right * slot.lat + Vector3.new(0, rng:NextNumber(-6, 22), 0)
			local face = CFrame.lookAt(centre, centre + ctx.front) * CFrame.Angles(0, 0, math.rad(slot.tilt))
			local RX, RY = 7, 30
			local rift = buildRift(folder, face, RX, RY, rng)
			local openAt = F.RIFTS + slot.order * 1.2
			table.insert(rifts, { rift = rift, openAt = openAt })
			for _ = 1, perRift[k] do
				local c = {}
				local n = #chains + 1
				c.t0 = openAt + 1.6 + rng:NextNumber(0, 1.6)
				c.origin = centre + face.UpVector * rng:NextNumber(-0.5, 0.5) * RY + face.RightVector * rng:NextNumber(-0.3, 0.3) * RX
				c.dir = (ctx.front + right * rng:NextNumber(-0.7, 0.7) + Vector3.yAxis * rng:NextNumber(-0.15, 0.5)).Unit
				c.side = c.dir:Cross(Vector3.yAxis).Unit
				c.wFreq = rng:NextNumber(1.4, 2.6)
				c.wPhase = rng:NextNumber(0, math.pi * 2)
				c.tSwarm = F.CHAINS + 3.5 + rng:NextNumber(0, 1.5)
				-- which beam it winds round: six chains the upright, six the arms, interleaved and winding both ways
				c.tc = F.CROSS + (n - 1) * 0.3
				c.vertical = n <= 6
				local b = c.vertical and n or n - 6
				c.sign = (b % 2 == 0) and 1 or -1
				c.phase = (b - 1) * (math.pi / 3)
				if c.vertical then
					c.axis, c.rx, c.rz = L, 10.5, 7.8
				else
					c.axis, c.armY, c.rx, c.rz = ctx.armSpan, 0.7 * L, 9.8, 7.8
				end
				table.insert(chains, buildChain(folder, c, rng, ctx))
			end
		end

		-- ── STAGE 4: the impact and the ravine ──
		impact = buildImpact(folder, ctx, rng)
		ravine = buildRavine(folder, ctx, rng)
	end

	local function update(T, dt)
		-- where he is now (the animator floats him up): the camera and the light follow
		-- (his bounding box is 38 studs tall with the hanging chains and sleeves: its centre is nowhere near him, so his
		-- chest, a little below the head, is the point the camera and the light use)
		local head = unit:FindFirstChild("Head", true)
		local centre = head and (head.Position - Vector3.new(0, 2.5 * ctx.scale, 0)) or unit:GetBoundingBox().Position
		local cf = CFrame.new(centre)
		ctx.H = ctx.H and ctx.H:Lerp(centre, 1 - math.exp(-6 * dt)) or centre
		local g, pulse = glowAmount(T), snapPulse(T)
		highlight.FillTransparency = 1 - math.clamp(0.4 * g + 0.4 * pulse * g, 0, 0.85)
		highlight.OutlineTransparency = 1 - math.clamp(g, 0, 1)
		glowPart.Position = cf.Position
		glowLight.Brightness = 2.2 * g + 5 * pulse * g
		ctx.glow = g
		ctx.pulse = pulse
		ctx.shake = 0.5 * pulse * g

		-- the rifts and the chains
		if not rifts and T >= F.RIFTS - 2 then
			buildStage2()
		end
		if rifts then
			nBulk = 0
			local now = os.clock()
			local closeF = ease(T, F.DESCEND - 3, F.DESCEND)
			for _, r in ipairs(rifts) do
				updateRift(r.rift, now, T - r.openAt, closeF, add)
			end
			local fade = ease(T, F.RAVINE + 1.5, F.RAVINE + 3.5)
			-- the cross: it floats up out of the ground rift (CROSS_RISE .. CROSS) while the chains swarm, hovers while they
			-- wind round it, trembles, leans back a little, then topples forward, hinged at its foot, slowly and then
			-- faster and faster until it lands on the gate at IMPACT
			local fallS = math.clamp((T - F.FALL) / (F.IMPACT - F.FALL), 0, 1)
			local sway = math.sin(ease(T, F.FALL - 1.5, F.FALL) * math.pi) * 0.04
			local theta = ctx.thetaHit * fallS ^ 2.4 - sway
			ctx.crossTheta = theta
			local hold = ease(T, F.CROSS + 9.5, F.CROSS + 10.5) * (1 - ease(T, F.FALL, F.FALL + 1))
			local crossCF = CFrame.new(0, ctx.crossLift(T), 0) * ctx.crossBase * CFrame.Angles(-theta, 0, 0)
				* CFrame.Angles(math.sin(now * 23) * 0.004 * hold, math.sin(now * 19) * 0.004 * hold, math.sin(now * 31) * 0.003 * hold)
			for _, cp in ipairs(crossParts) do
				add(cp.part, crossCF * cp.cf)
				if fade > 0 then
					cp.part.Transparency = cp.baseT + (1 - cp.baseT) * fade
				end
			end
			local sparkAmount = ease(T, F.GROUND_RIFT, F.GROUND_RIFT + 1.5) * (1 - ease(T, F.CROSS + 6, F.CROSS + 9))
			for _, sp in ipairs(groundSparks) do
				sp.Rate = 20 * sparkAmount
			end
			for ci, c in ipairs(chains) do
				local idx = math.clamp(math.floor((T - c.t0) / SAMPLE_DT) + 1, 1, #c.dist)
				local headD = T >= c.t0 and c.dist[idx] or -1
				local resting = T >= c.tEnd -- (the head has finished winding: the links lie in their slots, rigid with the cross)
				for j, l in ipairs(c.links) do
					local d = headD - (j - 1) * LINK_SPACING
					if d <= 0.05 or fade >= 1 then
						if l.shown then
							l.part.Transparency = 1
							l.shown = false
						end
						add(l.part, CFrame.new(c.origin))
					else
						if not l.shown or fade > 0 then
							l.part.Transparency = fade
							l.shown = true
						end
						if resting then
							local wobble = Vector3.new(math.sin(now * 13 + j * 1.7 + ci), math.sin(now * 11 + j * 2.3 + ci * 0.7), 0) * 0.25 * hold
							add(l.part, crossCF * c.slots[j] * CFrame.new(wobble))
						else
							local p = along(c, d)
							local q = along(c, d + 1.2)
							if (q - p).Magnitude < 1e-3 then
								q = p + Vector3.zAxis
							end
							add(l.part, CFrame.lookAt(p, q) * CFrame.Angles(0, 0, (j % 2 == 0) and math.pi / 2 or 0))
						end
					end
				end
			end
			workspace:BulkMoveTo(bulkParts, bulkCFs, Enum.BulkMoveMode.FireCFrameChanged)
			impact.update(T, dt)
			ravine.update(T)
		end
		for _, s in ipairs(strikes) do
			if not s.fired and T >= s.at then
				s.fired = true
				if T - s.at < 0.5 then
					-- behind him and to the side, from the clouds to the ground
					local dist = rng:NextNumber(70, 230)
					local side = rng:NextNumber(-200, 200)
					local base = ctx.ground + behind * dist + right * side
					local top = base + Vector3.new(rng:NextNumber(-40, 40), 260, rng:NextNumber(-40, 40))
					lightning(folder, top, base + Vector3.new(0, rng:NextNumber(0, 25), 0), rng, s.big and 1.3 or 0.8)
					ctx.flash = math.max(ctx.flash or 0, s.big and 1 or 0.6)
				end
			end
		end
	end
	local function cleanup() end
	return update, cleanup
end

-- ============================================================
-- The camera shots (Hush's centre is ctx.H, it rises with him; `front` points down the lane at the gate)
-- ============================================================
local SHOTS = {
	{ kind = "rise", from = F.RISE, to = F.SHOT_STORM }, -- close and low in front of him, looking up as he lifts (the glow and the lightning already start)
	{ kind = "storm", from = F.SHOT_STORM, to = F.SNAP }, -- pulling back, higher, the storm in the sky behind him
	{ kind = "snap", from = F.SNAP, to = F.RIFTS }, -- a slow push-in on his face
	{ kind = "rifts", from = F.RIFTS, to = F.CHAINS }, -- wide, in front of him, looking back at the arc of rifts opening behind him
	{ kind = "chains", from = F.CHAINS, to = F.CROSS_RISE }, -- higher and wider, sweeping across the swarm
	{ kind = "emerge", from = F.CROSS_RISE, to = F.CROSS }, -- low on the lane: the ground rift and the cross floating up out of it
	{ kind = "wrap", from = F.CROSS, to = F.FALL }, -- a slow orbit round the cross while the chains wind themselves round it
	{ kind = "fall", from = F.FALL, to = F.IMPACT }, -- it topples away from the camera, the camera following the tip
	{ kind = "impact", from = F.IMPACT, to = F.SHOT_RAVINE }, -- the tip hits the gate
	{ kind = "ravine", from = F.SHOT_RAVINE, to = F.DESCEND }, -- wide, from the lane in front of the gate, watching the crack race in and climb the tower
	{ kind = "descend", from = F.DESCEND, to = F.END }, -- in front of him again, slowly settling
}

local function shotPose(i, T, c)
	local s = SHOTS[i]
	local kind = s.kind
	local a = math.clamp((T - s.from) / (s.to - s.from), 0, 1)
	local H, front, right = c.H, c.front, c.right
	local up = Vector3.yAxis
	local foot, L = c.crossFoot, c.crossL
	if kind == "rise" then
		return H + front * (26 - 2 * a) + right * (6 + 3 * a) + up * (2 + 3 * a), H + up * 1, 55 - 5 * a
	elseif kind == "storm" then
		return H + front * (30 + 14 * a) + right * (9 + 5 * a) + up * (5 + 7 * a), H + up * (6 + 4 * a), 58 + 6 * a
	elseif kind == "snap" then
		return H + front * (22 - 13 * a) + right * (2 + 1.5 * a) + up * (-2 + 2.5 * a), H + up * 2.4, 48 - 12 * a
	elseif kind == "rifts" then
		return H + front * 75 + right * (40 - 15 * a) + up * (4 + 6 * a), H - front * 30 + up * (14 + 8 * a), 68
	elseif kind == "chains" then
		return H + front * 100 + right * (25 - 50 * a) + up * (14 + 10 * a), H - front * 5 + up * 24, 72 + 4 * a
	elseif kind == "emerge" and foot then
		-- low on the lane in front of the rift, looking up at the top of the cross as it floats up
		local topY = c.crossLift(T) + L
		return foot - front * (115 - 15 * a) + right * (45 - 20 * a) + up * (14 + 18 * a), foot + up * math.clamp(topY * 0.7, 8, L * 0.6), 74
	elseif kind == "wrap" and foot then
		local centre = foot + up * (0.5 * L + CROSS_HOVER)
		local offset = CFrame.Angles(0, math.rad(-40 + 80 * a), 0) * (-front * 200)
		return centre + offset + up * 55, centre + up * 5, 66
	elseif kind == "fall" and foot then
		local theta = c.crossTheta or 0
		local tip = up * math.cos(theta) + front * math.sin(theta)
		return foot - front * 85 + right * 30 + up * (34 + 10 * a), foot + up * CROSS_HOVER + tip * (L * 0.6), 70 - 8 * a
	elseif kind == "impact" and foot then
		return foot - front * 45 + right * 55 + up * 38, c.gate + up * 12, 66
	elseif kind == "ravine" and c.ravine then
		local g = c.ravine.gateFloor
		return g - front * (100 - 18 * a) + right * (48 - 14 * a) + up * (44 + 8 * a), g + up * (26 + 8 * a), 72
	elseif kind ~= "descend" then
		return H + front * 115 + right * (-25 + 10 * a) + up * 30, H + up * 20, 70
	end
	return H + front * (34 - 6 * a) + right * (8 - 3 * a) + up * (4 + 2 * a), H + up * 1, 52
end

local function cameraAt(T, c)
	local index = 1
	for i, s in ipairs(SHOTS) do
		if T >= s.from then
			index = i
		end
	end
	local pos, look, fov = shotPose(index, T, c)
	local since = T - SHOTS[index].from
	if index > 1 and since < CUT_BLEND then
		-- glide over from the shot before (its last pose, on his current position)
		local pPos, pLook, pFov = shotPose(index - 1, T, c)
		local k = smooth(since / CUT_BLEND)
		pos, look, fov = pPos:Lerp(pos, k), pLook:Lerp(look, k), pFov + (fov - pFov) * k
	end
	return pos, look, fov
end

-- ============================================================
-- Play
-- ============================================================
function HushFinisher.play(opts)
	opts = opts or {}
	if HushFinisher.active then
		return false
	end
	local startAt = opts.startAt or workspace:GetServerTimeNow()
	if workspace:GetServerTimeNow() - startAt >= DURATION - 1 then
		return false -- (too late to join)
	end
	local hush = opts.unit
	if not hush or not hush.Parent then
		hush = (not opts.spectator) and findHush() or nil
	end
	if not hush or not hush.PrimaryPart then
		warn("HushFinisher: no Hush in the world")
		return false
	end
	HushFinisher.active = true
	local camera = workspace.CurrentCamera
	local spectator = opts.spectator == true
	local ownerId = hush:GetAttribute("OwnerId")

	local root = hush.PrimaryPart
	local gate = opts.gate or hush:GetAttribute("AimPos") or (root.CFrame * CFrame.new(0, 4, -80)).Position
	local scale = hush:GetScale()
	local ground = root.Position - Vector3.new(0, (hush:GetAttribute("RootHeight") or 9.6) * scale, 0)
	-- (the Studio preview runs on whatever wall you are fighting, often a near one: the real gate is ~240+ studs down the
	-- lane, so a nearer one is moved out to 240, along the same line)
	if opts.preview then
		local flat = Vector3.new(gate.X - ground.X, 0, gate.Z - ground.Z)
		if flat.Magnitude > 1 and flat.Magnitude < 230 then
			gate = ground + flat.Unit * 240 + Vector3.new(0, 4, 0)
		end
	end
	local L = CFrame.lookAt(ground, Vector3.new(gate.X, ground.Y, gate.Z))
	local ctx = {
		unit = hush, gate = gate, ground = ground, L = L, scale = scale, preview = opts.preview == true, startAt = startAt,
		front = L.LookVector, right = L.RightVector,
		laneDist = (Vector3.new(gate.X, 0, gate.Z) - Vector3.new(ground.X, 0, ground.Z)).Magnitude,
	}

	local fxFolder = Instance.new("Folder")
	fxFolder.Name = "LastCrossFx_" .. tostring(ownerId or "?") .. "_" .. math.floor(startAt)
	fxFolder.Parent = workspace
	local worldUpdate, worldCleanup = world(fxFolder, ctx)
	-- (client-only, for UnitAnimator: his rise and his head on the same clock)
	hush:SetAttribute("FinisherAt", startAt)
	hush:SetAttribute("FinisherKind", "LastCross")
	local devRemote = ctx.preview and RunService:IsStudio() and ReplicatedStorage:FindFirstChild("DevLastCross")
	if devRemote then
		devRemote:FireServer(true)
	end

	-- ── the take-over: the owner at once, others when they press Watch ──
	local ui = Instance.new("ScreenGui")
	ui.Name = "LastCrossUI"
	ui.ResetOnSpawn = false
	ui.IgnoreGuiInset = true
	ui.DisplayOrder = 100
	ui.Parent = player:WaitForChild("PlayerGui")
	local function bar(anchorY)
		local f = Instance.new("Frame")
		f.AnchorPoint = Vector2.new(0, anchorY)
		f.Position = UDim2.fromScale(0, anchorY)
		f.Size = UDim2.fromScale(1, 0)
		f.BackgroundColor3 = Color3.new(0, 0, 0)
		f.BorderSizePixel = 0
		f.ZIndex = 9
		f.Parent = ui
		return f
	end
	local barTop, barBottom = bar(0), bar(1)
	local skipBtn = Theme.stoneButton(ui, {
		text = "Skip", color = "stone", size = UDim2.fromOffset(120, 40),
		position = UDim2.new(1, -24, 1, -20), anchor = Vector2.new(1, 1), zIndex = 10,
	})
	skipBtn.root.Visible = false
	local watchBtn = Theme.stoneButton(ui, {
		text = "Watch the Last Cross", color = "blue", size = UDim2.fromOffset(300, 44),
		position = UDim2.new(0.5, 0, 0, 90), anchor = Vector2.new(0.5, 0), zIndex = 10,
	})
	watchBtn.root.Visible = false
	local caption
	if RunService:IsStudio() then
		caption = Instance.new("TextLabel")
		caption.Position = UDim2.new(0, 16, BAR_HEIGHT, 8)
		caption.Size = UDim2.fromOffset(520, 26)
		caption.BackgroundTransparency = 1
		caption.Font = Enum.Font.GothamMedium
		caption.TextSize = 18
		caption.TextXAlignment = Enum.TextXAlignment.Left
		caption.TextColor3 = Color3.fromRGB(220, 200, 255)
		caption.TextStrokeTransparency = 0.4
		caption.ZIndex = 11
		caption.Visible = false
		caption.Parent = ui
	end

	local watching = false
	local watchStart = 0
	local saved, controls
	local hiddenGuis, hiddenBoards, hiddenArmy = {}, {}, {}
	-- the watchers' sky: darker and violet while the storm gathers (a colour grade only: this map's Atmosphere haze is
	-- already 0.9, raising its density whites the whole screen out)
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "LastCrossGrade"
	cc.Enabled = false
	cc.Parent = Lighting
	local function takeOver()
		if watching or not CinematicGuard.claim("LastCross") then
			return
		end
		watching = true
		watchStart = workspace:GetServerTimeNow() - startAt
		saved = { cameraType = camera.CameraType, fov = camera.FieldOfView, guiEnabled = mainGui.Enabled, subject = camera.CameraSubject }
		pcall(function()
			controls = require(player.PlayerScripts:WaitForChild("PlayerModule", 2)):GetControls()
			controls:Disable()
		end)
		mainGui.Enabled = false
		for _, g in ipairs(player:WaitForChild("PlayerGui"):GetChildren()) do
			if g:IsA("ScreenGui") and g.Enabled and g ~= ui and g.Name ~= "Freecam" then
				g.Enabled = false
				table.insert(hiddenGuis, g)
			end
		end
		for _, d in ipairs(workspace:GetDescendants()) do
			if d:IsA("BillboardGui") and d.Enabled then
				d.Enabled = false
				table.insert(hiddenBoards, d)
			end
		end
		-- the army: hidden on this screen for the whole finisher (it stands idle on the server)
		for _, p in ipairs(armyParts(ownerId, hush)) do
			if p.LocalTransparencyModifier < 1 then
				p.LocalTransparencyModifier = 1
				table.insert(hiddenArmy, p)
			end
		end
		camera.CameraType = Enum.CameraType.Scriptable
		cc.Enabled = true
		watchBtn.root.Visible = false
		skipBtn.root.Visible = true
		if caption then
			caption.Visible = true
		end
	end
	local function giveBack()
		if not watching then
			return
		end
		watching = false
		for _, p in ipairs(hiddenArmy) do
			if p.Parent then
				p.LocalTransparencyModifier = 0
			end
		end
		hiddenArmy = {}
		for _, b in ipairs(hiddenBoards) do
			if b.Parent then
				b.Enabled = true
			end
		end
		hiddenBoards = {}
		camera.CameraType = saved.cameraType == Enum.CameraType.Scriptable and Enum.CameraType.Custom or saved.cameraType
		if saved.subject and saved.subject.Parent then
			camera.CameraSubject = saved.subject
		end
		camera.FieldOfView = saved.fov
		mainGui.Enabled = saved.guiEnabled
		for _, g in ipairs(hiddenGuis) do
			if g.Parent then
				g.Enabled = true
			end
		end
		hiddenGuis = {}
		if controls then
			pcall(function() controls:Enable() end)
		end
		cc.Enabled = false
		skipBtn.root.Visible = false
		if caption then
			caption.Visible = false
		end
		CinematicGuard.release("LastCross")
	end
	if spectator then
		watchBtn.root.Visible = true
		watchBtn.button.Activated:Connect(takeOver)
	else
		takeOver()
		if not watching then
			watchBtn.root.Visible = true -- (another cinematic holds the camera: they can watch when it is free)
			watchBtn.button.Activated:Connect(takeOver)
		end
	end

	local T = workspace:GetServerTimeNow() - startAt
	local done = false
	local BIND = "LastCrossCamera_" .. math.floor(startAt * 10)
	local lastClock = os.clock()

	local function finish()
		if done then
			return
		end
		done = true
		RunService:UnbindFromRenderStep(BIND)
		giveBack()
		ui:Destroy()
		cc:Destroy()
		pcall(worldCleanup)
		fxFolder:Destroy()
		if hush.Parent then
			hush:SetAttribute("FinisherAt", nil)
			hush:SetAttribute("FinisherKind", nil)
		end
		if devRemote then
			devRemote:FireServer(false)
		end
		HushFinisher.active = false
		if opts.onDone then
			opts.onDone()
		end
	end
	skipBtn.button.Activated:Connect(giveBack)
	hush.AncestryChanged:Connect(function()
		if not hush.Parent then
			giveBack()
		end
	end)

	RunService:BindToRenderStep(BIND, Enum.RenderPriority.Camera.Value + 1, function()
		if done then
			return
		end
		local now = os.clock()
		local dt = math.min(now - lastClock, 0.1)
		lastClock = now
		T = workspace:GetServerTimeNow() - startAt
		if T >= DURATION then
			finish()
			return
		end
		ctx.watching = watching
		ctx.flash = (ctx.flash or 0) * math.exp(-9 * dt)
		local ok, err = pcall(worldUpdate, T, dt)
		if not ok then
			warn("HushFinisher: " .. tostring(err))
		end
		if watchBtn.root.Visible and T >= F.GATE_HIT - 2 then
			watchBtn.root.Visible = false
		end
		local h = watching and BAR_HEIGHT * smooth((T - watchStart) / BAR_TIME) * smooth((DURATION - T) / BAR_TIME) or 0
		barTop.Size = UDim2.fromScale(1, h)
		barBottom.Size = UDim2.fromScale(1, h)
		if not watching then
			return
		end
		-- the sky: it darkens over the first 10 s and clears again over the last 6; every strike flashes it
		local dark = ease(T, F.RISE, F.RISE + 6) * (1 - ease(T, F.END - 6, F.END))
		cc.Brightness = -0.28 * dark + 0.22 * (ctx.flash or 0)
		cc.Contrast = 0.12 * dark
		cc.Saturation = -0.3 * dark
		cc.TintColor = Color3.new(1, 1, 1):Lerp(Color3.fromRGB(205, 175, 255), 0.55 * dark)
		if camera.CameraType ~= Enum.CameraType.Scriptable then
			camera.CameraType = Enum.CameraType.Scriptable
		end
		if ctx.H then
			local pos, look, fov = cameraAt(T, ctx)
			camera.CFrame = CFrame.lookAt(pos, look)
			camera.FieldOfView = fov
			local shake = ctx.shake or 0
			if shake > 0 then
				local tt = os.clock() * 37
				camera.CFrame *= CFrame.new(math.sin(tt) * shake * 0.7, math.sin(tt * 1.3 + 1) * shake * 0.7, 0)
			end
		end
		if caption then
			local index = 1
			for i, b in ipairs(BEATS) do
				if T >= b.at then
					index = i
				end
			end
			caption.Position = UDim2.new(0, 16, h, 8)
			caption.Text = string.format("%d / %d  %s   (%.1f s)", index, #BEATS, BEATS[index].name, T)
		end
	end)
	return true
end

-- the server starts it for everyone (Army.checkFinisher)
local remote = ReplicatedStorage:WaitForChild("LastCross", 10)
if remote then
	remote.OnClientEvent:Connect(function(data)
		if type(data) ~= "table" or not data.startAt then
			return
		end
		HushFinisher.play({
			startAt = data.startAt,
			unit = data.unit,
			gate = data.gate,
			spectator = data.owner ~= tostring(player.UserId),
		})
	end)
end

return HushFinisher
