-- Special attacks, client side (server: Army.startSpecial; unit def `special` in Units.lua).
--   * the charge meter: a thin violet bar above every unit that has a special (model attributes SpecialStart, SpecialCD),
--     filling up over the cooldown and pulsing when full
--   * the effects, drawn from the synced server clock (SpecialAt) and a shared seed (SpecialSeed) so every player sees
--     the same thing at the same time. Kinds:
--       RiftChains (Hush), about 9 s: the unit swings its sleeve out to the side and slashes (UnitAnimator); at 1.0 s a
--       tall torn oval rip snaps open in front of it (light leaking from the edges, frayed spikes, flickering fragments);
--       1.4-5.4 s the chains creep out of it, wriggling; at 5.4 s they suddenly scatter in a wild uneven fan, very high
--       and far apart, converge again coming down and race at the wall, each hitting at its own moment between 6.6 and
--       7.3 s (server hit 1 at 6.95), rattle, and explode 0.6 s after their own hit (server hit 2 at 7.6); 8.0-8.6 s the
--       rip zips shut.
--     The unit's pose (sleeve up, slash, point at the rift) is in UnitAnimator.
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local TAG = "ProceduralUnit"
local METER_DISTANCE = 90
local SPECIAL_DURATION = 8.8 -- seconds a special lasts (the meter shows it firing meanwhile)
local FX_DISTANCE = 320

local VIOLET = Color3.fromRGB(190, 120, 255)
local MAGENTA = Color3.fromRGB(255, 110, 230)
local CORE = Color3.fromRGB(245, 230, 255)
local CHAIN = Color3.fromRGB(110, 40, 190)
local RIFT_DARK = Color3.fromRGB(14, 6, 24)

local fx = Instance.new("Folder")
fx.Name = "SpecialFx"
fx.Parent = workspace

local function serverNow()
	return workspace:GetServerTimeNow()
end

local function smooth(x)
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

local function newPart(size, color, transparency, shape, material)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = false, false, false, false
	p.Material = material or Enum.Material.Neon
	p.Color = color
	p.Size = size
	p.Transparency = transparency or 0
	if shape then p.Shape = shape end
	p.Parent = fx
	return p
end

-- ============================================================
-- Charge meter
-- ============================================================
local meters = {} -- [model] = { gui, fill, glow }

local function makeMeter(model)
	if meters[model] then return end
	local root = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
	if not root then return end
	local scale = model:GetScale()
	local gui = Instance.new("BillboardGui")
	gui.Name = "SpecialMeter"
	gui.Size = UDim2.new(3.4, 0, 0.32, 0)
	gui.StudsOffset = Vector3.new(0, ((model:GetAttribute("Height") or 6) - (model:GetAttribute("RootHeight") or 2)) * scale + 0.55, 0)
	gui.MaxDistance = METER_DISTANCE
	gui.LightInfluence = 0
	gui.Parent = root
	local back = Instance.new("Frame")
	back.Size = UDim2.fromScale(1, 1)
	back.BackgroundColor3 = Color3.fromRGB(18, 12, 26)
	back.BackgroundTransparency = 0.15
	back.BorderSizePixel = 0
	back.Parent = gui
	Instance.new("UICorner", back).CornerRadius = UDim.new(0.5, 0)
	local stroke = Instance.new("UIStroke", back)
	stroke.Color = Color3.fromRGB(90, 60, 130)
	stroke.Thickness = 1
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = VIOLET
	fill.BorderSizePixel = 0
	fill.Parent = back
	Instance.new("UICorner", fill).CornerRadius = UDim.new(0.5, 0)
	meters[model] = { gui = gui, fill = fill, stroke = stroke, root = root }
end

local function updateMeters(now, camPos)
	for model, m in pairs(meters) do
		if not model.Parent or not m.gui.Parent then
			meters[model] = nil
		elseif camPos and (m.root.Position - camPos).Magnitude < METER_DISTANCE then
			local start = model:GetAttribute("SpecialStart") or now
			local cd = model:GetAttribute("SpecialCD") or 1
			local at = model:GetAttribute("SpecialAt")
			local firing = at and now - at >= 0 and now - at < SPECIAL_DURATION
			local f = math.clamp((now - start) / cd, 0, 1)
			if firing then
				f = 1 - math.clamp((now - at) / 0.5, 0, 1) -- empties as the special fires
				m.fill.BackgroundColor3 = CORE
			elseif f >= 1 then
				-- full: pulse while waiting for a wall to fire at
				local p = 0.5 + 0.5 * math.sin(now * 8)
				m.fill.BackgroundColor3 = VIOLET:Lerp(CORE, p)
				m.stroke.Color = VIOLET:Lerp(MAGENTA, p)
			else
				m.fill.BackgroundColor3 = VIOLET
				m.stroke.Color = Color3.fromRGB(90, 60, 130)
			end
			m.fill.Size = UDim2.fromScale(f, 1)
		end
	end
end

-- ============================================================
-- Rift Chains
-- ============================================================
-- Timeline (seconds after SpecialAt; keep in sync with Units.Hush.special and UnitAnimator):
local RIP_AT = 1.0 -- the slash ends: the rip snaps open
local EMERGE_AT, BURST_AT = 1.4, 5.4 -- the chains creep out, wriggling, for 4 s, then suddenly scatter
local IMPACT_FROM, IMPACT_TO = 6.6, 7.3 -- every chain hits the wall at its own moment in here (server hit 1 at 6.95)
local BOOM_DELAY = 0.6 -- each chain explodes this long after its own impact (server hit 2 at 7.6)
local CLOSE_AT, END_AT = 8.0, 8.6 -- the rip zips shut
local CHAINS = 7
local LINK_SPACING = 0.7 -- studs between links
local CHAIN_LENGTH = 14 -- studs of chain behind the head
local SAMPLE_DT = 1 / 90 -- the head's path is precomputed at this rate

local function bezier(p0, p1, p2, p3, s)
	local u = 1 - s
	return p0 * (u * u * u) + p1 * (3 * u * u * s) + p2 * (3 * u * s * s) + p3 * (s * s * s)
end

-- the head of one chain over time: inside the rip until EMERGE_AT, creeping out and wriggling until BURST_AT, then a
-- wild arc (up and out, then bending down) to its impact point, faster and faster
local function chainHead(c, t)
	if t <= EMERGE_AT then
		return c.origin
	elseif t <= BURST_AT then
		local f = (t - EMERGE_AT) / (BURST_AT - EMERGE_AT)
		local reach = c.creep * (1 - (1 - f) ^ 2) -- eases out
		local wiggle = c.side * math.sin(t * c.wFreq + c.wPhase) * 0.45 * math.min(1, f * 3)
			+ Vector3.yAxis * math.sin(t * c.wFreq * 0.8 + c.wPhase * 1.7) * 0.3 * math.min(1, f * 3)
		return c.origin + c.dir * reach + wiggle
	else
		local f = math.clamp((t - BURST_AT) / (c.impact - BURST_AT), 0, 1)
		local s = f ^ 1.9 -- slow out of the burst, then racing at the wall
		local pos = bezier(c.p0, c.p1, c.p2, c.p3, s)
		-- a little wildness that fades out before the hit
		local wild = c.side * math.sin(t * 9 + c.wPhase) * 0.8 * (1 - f)
		return pos + wild
	end
end

local function riftChains(model, at, aim, seed)
	local root = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
	if not root then return nil end
	local rng = Random.new(seed)
	local scale = model:GetScale()
	local pivot = model:GetPivot()
	local look = Vector3.new(pivot.LookVector.X, 0, pivot.LookVector.Z).Unit
	local right = look:Cross(Vector3.yAxis).Unit
	local centre = root.Position + look * 4.5 * scale + Vector3.new(0, 1.0 * scale, 0)
	-- the rip faces the wall, tilted along the slash
	local face = CFrame.lookAt(centre, Vector3.new(aim.X, centre.Y, aim.Z)) * CFrame.Angles(0, 0, math.rad(-24))

	-- ── the rip: a tall narrow torn oval, light leaking from the edges, frayed spikes, flickering fragments ──
	local RX, RY = 0.6 * scale, 2.5 * scale
	local core = newPart(Vector3.new(0.08, 1, 1), RIFT_DARK, 0.02, Enum.PartType.Cylinder)
	local glow = newPart(Vector3.new(0.06, 1, 1), VIOLET, 0.55, Enum.PartType.Cylinder)
	local rims = {}
	for k = 0, 25 do
		local a = k / 26 * math.pi * 2
		table.insert(rims, { part = newPart(Vector3.new(0.5, 0.1, 0.07), CORE), a = a, r = 1 + rng:NextNumber(-0.18, 0.18), z = -0.02 })
		table.insert(rims, { part = newPart(Vector3.new(0.42, 0.14, 0.06), VIOLET), a = a + 0.12, r = 1.1 + rng:NextNumber(-0.15, 0.2), z = 0 })
	end
	local spikes = {}
	for k = 1, 12 do
		local a = rng:NextNumber(0, math.pi * 2)
		table.insert(spikes, { part = newPart(Vector3.new(rng:NextNumber(0.4, 1.1), 0.06, 0.05), MAGENTA), a = a, len = rng:NextNumber(0.4, 1.1) })
	end
	local frags = {}
	for k = 1, 10 do
		table.insert(frags, { part = newPart(Vector3.new(0.05, 0.25, 0.25), CORE, 0.2), a = rng:NextNumber(0, math.pi * 2), r = rng:NextNumber(1.3, 2.0), spin = rng:NextNumber(-4, 4), blink = rng:NextNumber(5, 14) })
	end
	local riftLight = Instance.new("PointLight")
	riftLight.Color = VIOLET
	riftLight.Range = 16
	riftLight.Brightness = 0
	riftLight.Shadows = false
	riftLight.Parent = core

	-- ── the chains ──
	local chains = {}
	local impacts = {}
	for i = 1, CHAINS do
		impacts[i] = IMPACT_FROM + (IMPACT_TO - IMPACT_FROM) * ((i - 1) / (CHAINS - 1)) + rng:NextNumber(-0.06, 0.06)
	end
	for i = CHAINS, 2, -1 do -- shuffle which chain hits when
		local j = rng:NextInteger(1, i)
		impacts[i], impacts[j] = impacts[j], impacts[i]
	end
	for i = 1, CHAINS do
		local c = {}
		-- where it comes out of the rip and which way it creeps (mostly toward the wall, a little spread)
		c.origin = centre + (face.UpVector * rng:NextNumber(-0.8, 0.8) * RY * 0.6) + face.RightVector * rng:NextNumber(-0.2, 0.2) * RX
		c.dir = (look + right * rng:NextNumber(-0.6, 0.6) + Vector3.yAxis * rng:NextNumber(-0.25, 0.45)).Unit
		c.side = (c.dir:Cross(Vector3.yAxis).Magnitude > 0 and c.dir:Cross(Vector3.yAxis).Unit) or right
		c.creep = rng:NextNumber(4, 7) * scale
		c.wFreq = rng:NextNumber(3.2, 5.5) -- slow, creepy wriggle
		c.wPhase = rng:NextNumber(0, math.pi * 2)
		c.impact = impacts[i]
		c.boom = c.impact + BOOM_DELAY + rng:NextNumber(-0.08, 0.08)
		-- the wild arc: a big uneven fan up and out, then bending down at the wall
		c.p0 = chainHead(c, BURST_AT)
		local spread = rng:NextNumber(-1, 1)
		spread = (spread >= 0 and 1 or -1) * math.abs(spread) ^ 0.6 -- pushed outward: fewer chains in the middle
		-- far apart on the way up (high, wide, and spread toward / away from the wall too) ...
		c.p1 = c.p0 + Vector3.new(0, rng:NextNumber(24, 44), 0) + right * spread * rng:NextNumber(24, 44) + look * rng:NextNumber(-14, 16)
		-- ... then they converge, coming down steeply onto the impact area
		c.p3 = aim + right * rng:NextNumber(-4.5, 4.5) + Vector3.new(0, rng:NextNumber(-3, 3), 0)
		c.p2 = c.p3 - look * rng:NextNumber(6, 16) + Vector3.new(0, rng:NextNumber(12, 24), 0) + right * spread * rng:NextNumber(1, 5)
		-- precompute the head's path and its length so far, so the links can trail it at fixed spacing
		c.samples, c.dist = {}, {}
		local total, prev = 0, nil
		local t = EMERGE_AT
		while t <= c.impact + 1e-6 do
			local p = chainHead(c, t)
			if prev then total += (p - prev).Magnitude end
			table.insert(c.samples, p)
			table.insert(c.dist, total)
			prev = p
			t += SAMPLE_DT
		end
		c.links = {}
		local n = math.floor(CHAIN_LENGTH / LINK_SPACING)
		for j = 1, n do
			local head = j == 1
			c.links[j] = newPart(head and Vector3.new(0.32, 0.32, 0.8) or Vector3.new(0.14, 0.42, 0.62), head and CORE or CHAIN, 1)
		end
		c.fly = {}
		chains[i] = c
	end
	local booms = {}

	-- the point `d` studs along chain c's path (clamped to the path)
	local function along(c, d)
		local dist, samples = c.dist, c.samples
		if d <= 0 then return samples[1], samples[math.min(2, #samples)] end
		local lo, hi = 1, #dist
		if d >= dist[hi] then return samples[hi], samples[hi] + (samples[hi] - samples[math.max(1, hi - 1)]) end
		while hi - lo > 1 do
			local mid = (lo + hi) // 2
			if dist[mid] < d then lo = mid else hi = mid end
		end
		local f = (d - dist[lo]) / math.max(1e-6, dist[hi] - dist[lo])
		return samples[lo]:Lerp(samples[hi], f), samples[hi]
	end

	local function destroyAll()
		core:Destroy()
		glow:Destroy()
		for _, r in ipairs(rims) do r.part:Destroy() end
		for _, sp in ipairs(spikes) do sp.part:Destroy() end
		for _, fr in ipairs(frags) do fr.part:Destroy() end
		for _, c in ipairs(chains) do
			for _, l in ipairs(c.links) do l:Destroy() end
		end
		for _, b in ipairs(booms) do
			b.ball:Destroy()
			b.ring:Destroy()
		end
	end

	return function(now)
		local st = now - at
		if st >= END_AT + 0.4 or not model.Parent then
			destroyAll()
			return false
		end

		-- ── the rip: snaps open, wavers, zips shut (narrowing first) ──
		local snap = math.clamp((st - RIP_AT) / 0.14, 0, 1)
		local openY = snap < 1 and (1 - (1 - snap) ^ 3) * 1.08 or 1
		local closeF = math.clamp((st - CLOSE_AT) / (END_AT - CLOSE_AT), 0, 1)
		local sx = (snap > 0 and 1 or 0) * (1 - smooth(closeF * 1.4)) * (1 + math.sin(now * 19) * 0.08)
		local sy = openY * (1 - smooth(math.max(0, closeF - 0.3) / 0.7))
		local visible = sx > 0.01 and sy > 0.01
		core.Size = Vector3.new(0.08, RY * 2 * sy + 0.01, RX * 2 * sx + 0.01)
		core.CFrame = face * CFrame.Angles(0, math.rad(90), 0)
		core.Transparency = visible and 0.02 or 1
		glow.Size = Vector3.new(0.06, RY * 2.5 * sy + 0.01, RX * 3.2 * sx + 0.01)
		glow.CFrame = face * CFrame.new(0, 0, 0.05) * CFrame.Angles(0, math.rad(90), 0)
		glow.Transparency = visible and (0.55 + math.sin(now * 13) * 0.1) or 1
		riftLight.Brightness = visible and 3 * sy or 0
		for _, r in ipairs(rims) do
			local jitter = 1 + math.sin(now * 23 + r.a * 7) * 0.08
			local pos = Vector3.new(math.cos(r.a) * RX * sx * r.r * jitter, math.sin(r.a) * RY * sy * r.r * jitter, r.z)
			local tangent = Vector3.new(-math.sin(r.a) * RX * sx, math.cos(r.a) * RY * sy, 0)
			r.part.CFrame = face * CFrame.new(pos) * CFrame.Angles(0, 0, math.atan2(tangent.Y, tangent.X))
			r.part.Transparency = visible and 0 or 1
		end
		for _, sp in ipairs(spikes) do
			-- frayed tongues sticking out of the edge, flickering in length
			local edge = Vector3.new(math.cos(sp.a) * RX * sx, math.sin(sp.a) * RY * sy, 0)
			local out = Vector3.new(math.cos(sp.a) * RY, math.sin(sp.a) * RX, 0).Unit
			local len = sp.len * (0.7 + 0.3 * math.sin(now * 15 + sp.a * 3))
			sp.part.Size = Vector3.new(len, 0.06, 0.05)
			sp.part.CFrame = face * CFrame.new(edge + out * len / 2) * CFrame.Angles(0, 0, math.atan2(out.Y, out.X))
			sp.part.Transparency = visible and 0.1 or 1
		end
		for _, fr in ipairs(frags) do
			local a = fr.a + now * 0.9
			local pos = Vector3.new(math.cos(a) * RX * fr.r * 1.6 * sx, math.sin(a) * RY * fr.r * 0.7 * sy, 0.3)
			fr.part.CFrame = face * CFrame.new(pos) * CFrame.Angles(now * fr.spin, now * fr.spin * 0.6, 0)
			fr.part.Transparency = (visible and math.sin(now * fr.blink + fr.a) > -0.3) and 0.2 or 1
		end

		-- ── the chains ──
		for i, c in ipairs(chains) do
			if st < EMERGE_AT then
				-- still inside the rip
			elseif st < c.boom then
				local tHead = math.min(st, c.impact)
				local headD = c.dist[math.clamp(math.floor((tHead - EMERGE_AT) / SAMPLE_DT) + 1, 1, #c.dist)]
				local rattle = (st >= c.impact) and 0.1 or 0
				for j, l in ipairs(c.links) do
					local d = headD - (j - 1) * LINK_SPACING
					if d <= 0.05 then
						l.Transparency = 1 -- not out of the rip yet
					else
						local pos, ahead = along(c, d)
						if (ahead - pos).Magnitude < 1e-3 then ahead = pos + look end
						local jitter = Vector3.new(math.sin(now * 41 + j + i), math.sin(now * 37 + j * 2), math.sin(now * 43 + i * 3)) * rattle
						l.CFrame = CFrame.lookAt(pos + jitter, ahead + jitter) * CFrame.Angles(0, 0, (j % 2) * math.rad(90))
						l.Transparency = (j == 1) and 0 or 0.05
					end
				end
			else
				-- this chain explodes: a flash and a ring at its tip, the links fly apart and fade
				if not c.exploded then
					c.exploded = true
					local hit = c.p3
					local ball = newPart(Vector3.one, CORE, 0, Enum.PartType.Ball)
					ball.CFrame = CFrame.new(hit)
					local ring = newPart(Vector3.new(0.1, 1, 1), MAGENTA, 0.2, Enum.PartType.Cylinder)
					ring.CFrame = CFrame.lookAt(hit, hit - look) * CFrame.Angles(0, math.rad(90), 0)
					local l = Instance.new("PointLight")
					l.Color = VIOLET
					l.Range = 16
					l.Brightness = 3
					l.Shadows = false
					l.Parent = ball
					table.insert(booms, { ball = ball, ring = ring, light = l, at = c.boom })
					for j, link in ipairs(c.links) do
						c.fly[j] = { from = link.Position, vel = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-0.3, 1), rng:NextNumber(-1, 1)) * 14 }
					end
				end
				local f = math.clamp((st - c.boom) / 0.45, 0, 1)
				for j, link in ipairs(c.links) do
					local fl = c.fly[j]
					if fl then
						link.Position = fl.from + fl.vel * (st - c.boom)
					end
					link.Transparency = math.max(link.Transparency, f)
				end
			end
		end
		for _, b in ipairs(booms) do
			local f = math.clamp((st - b.at) / 0.5, 0, 1)
			b.ball.Size = Vector3.one * (0.5 + 4.5 * f)
			b.ball.Transparency = f
			b.ring.Size = Vector3.new(0.1, 1 + 8 * f, 1 + 8 * f)
			b.ring.Transparency = 0.2 + 0.8 * f
			b.light.Brightness = 3 * (1 - f)
		end
		return true
	end
end

-- ============================================================
-- Watching the units
-- ============================================================
local running = {}
local watched = {}

local function onSpecial(model)
	local at = model:GetAttribute("SpecialAt")
	local aim = model:GetAttribute("SpecialAim")
	if not at or not aim then return end
	local camera = workspace.CurrentCamera
	local root = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
	if camera and root and (root.Position - camera.CFrame.Position).Magnitude > FX_DISTANCE
		and (aim - camera.CFrame.Position).Magnitude > FX_DISTANCE then
		return
	end
	if model:GetAttribute("SpecialKind") == "RiftChains" then
		local fn = riftChains(model, at, aim, model:GetAttribute("SpecialSeed") or 1)
		if fn then table.insert(running, fn) end
	end
end

local function watch(model)
	if watched[model] then return end
	watched[model] = true
	if model:GetAttribute("SpecialCD") then makeMeter(model) end
	model:GetAttributeChangedSignal("SpecialCD"):Connect(function() makeMeter(model) end)
	model:GetAttributeChangedSignal("SpecialAt"):Connect(function() onSpecial(model) end)
end
for _, model in ipairs(CollectionService:GetTagged(TAG)) do
	watch(model)
end
CollectionService:GetInstanceAddedSignal(TAG):Connect(watch)
CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(model)
	watched[model] = nil
	meters[model] = nil
end)

RunService.RenderStepped:Connect(function()
	local now = serverNow()
	local camera = workspace.CurrentCamera
	updateMeters(now, camera and camera.CFrame.Position)
	for i = #running, 1, -1 do
		if not running[i](now) then
			table.remove(running, i)
		end
	end
end)

return {}
