-- The Soul Altar's braziers in the world (tools/studio/build_altar.lua, placed by the server's PlotLook): every altar
-- (tag SoulAltar) carries its owner's realm upgrade levels as attributes Level_<key>; each Brazier model (attribute
-- Upgrade = the key) burns as high as its level: embers at level 0, a tall flame with rising souls near the top. The
-- upgrades with a max level (Swift March, Grasping Souls) reach the full flame at their max, the others (Army Might,
-- Soul Harvest) grow ever more slowly. When a level goes UP the brazier flares and a few souls fly from it into the
-- altar's tome; when the levels reset (a new realm) the flames sink back to embers.
-- The PERMANENT upgrades (Luck Boost, Coin Boost; attributes Perm_<key>) are "written into the tome": both rune rings
-- spin up and pull in, one rune breaks out of the outer ring and stamps into the pages (flash, the pages flutter), then
-- a burst in the upgrade's colour: Luck = emerald sparkles and a four-leaf sigil that sinks into the book, Coin = a
-- spray of gold coins that rains back into it; the rings ease back.
--
--   AltarFx.highlight(key | nil)   -- the in-world Upgrades view: a hovered realm upgrade lights its brazier, a hovered
--                                     permanent one makes the tome glow in its colour
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Economy = require(ReplicatedStorage.Shared.Economy)
local WorldFx = require(script.Parent.WorldFx)

local AltarFx = {}

local MAX_DISTANCE = 260 -- braziers farther from the camera are left alone
local EASE = 2.2 -- how fast a flame grows or sinks to its level (1/s)
local FLARE_TIME = 1.4
local SOUL_FLIGHT = 0.9
local OPEN_GROWTH = 8 -- the levels at which an upgrade without a max reaches ~63 % of the full flame

local braziers = {} -- [Brazier model] = state
local highlighted = nil

-- 0..1 flame size for an upgrade level
local function intensity(key, level)
	local u = Economy.REALM_UPGRADE[key]
	if not u or level <= 0 then
		return 0
	end
	if u.max then
		return math.clamp(level / u.max, 0, 1)
	end
	return 1 - math.exp(-level / OPEN_GROWTH)
end

-- puts the emitters, light and coals at size k (0 = embers .. 1 = full), boost = an extra flare on top
local function apply(st, k, boost)
	st.fire.Size = 1.2 + 6.3 * k + 4 * boost
	st.fire.Heat = 3 + 9 * k + 10 * boost
	if st.souls then
		st.souls.Rate = 0.5 + 6 * k + 10 * boost
	end
	if st.light then
		st.light.Brightness = 0.35 + 1.6 * k + 2 * boost
		st.light.Range = 6 + 9 * k + 6 * boost
	end
	if st.coals then
		st.coals.Transparency = math.clamp(0.55 - 0.55 * k - boost, 0, 1)
	end
end

-- a few souls fly from the brazier into the tome, then a small flash there
local function soulStream(st)
	local altarModel = st.altar
	local tome = altarModel:FindFirstChild("TomeLight", true)
	if not (tome and st.anchor) then
		return
	end
	local from = st.anchor.Position + Vector3.new(0, 1.2, 0)
	local to = tome.Position - Vector3.new(0, 0.5, 0)
	local folder = Instance.new("Folder")
	folder.Name = "AltarSouls"
	folder.Parent = Workspace
	local orbs = {}
	for i = 1, 4 do
		local p = Instance.new("Part")
		p.Shape = Enum.PartType.Ball
		p.Size = Vector3.one * (0.45 - i * 0.05)
		p.Material = Enum.Material.Neon
		p.Color = st.color
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.CFrame = CFrame.new(from)
		p.Parent = folder
		orbs[i] = { part = p, delay = (i - 1) * 0.12, side = (i % 2 == 0) and 1 or -1 }
	end
	local flash
	local t0 = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - t0
		local alive = false
		for _, o in ipairs(orbs) do
			local k = math.clamp((t - o.delay) / SOUL_FLIGHT, 0, 1)
			if k < 1 then
				alive = true
			end
			-- an arc over the dais, swaying sideways
			local pos = from:Lerp(to, k * k * (3 - 2 * k)) + Vector3.new(0, math.sin(math.pi * k) * 2.2, 0)
				+ (to - from):Cross(Vector3.yAxis).Unit * math.sin(math.pi * k * 2) * 0.5 * o.side
			o.part.CFrame = CFrame.new(pos)
			o.part.Transparency = (k <= 0 or k >= 1) and 1 or 0
		end
		if not flash and t > SOUL_FLIGHT then
			flash = Instance.new("Part")
			flash.Shape = Enum.PartType.Ball
			flash.Material = Enum.Material.Neon
			flash.Color = st.color
			flash.Anchored = true
			flash.CanCollide = false
			flash.CanQuery = false
			flash.CanTouch = false
			flash.CastShadow = false
			flash.CFrame = CFrame.new(to)
			flash.Parent = folder
		end
		if flash then
			local f = math.clamp((t - SOUL_FLIGHT) / 0.5, 0, 1)
			flash.Size = Vector3.one * (0.6 + 2.2 * f)
			flash.Transparency = 0.2 + 0.8 * f
		end
		if not alive and t > SOUL_FLIGHT + 0.8 then
			conn:Disconnect()
			folder:Destroy()
		end
	end)
end

-- ============================================================
-- Permanent upgrades: written into the tome
-- ============================================================
local PERM_COLORS = { luckBoost = Color3.fromRGB(60, 255, 140), coinBoost = Color3.fromRGB(255, 194, 56) }
local RITE_TIME = 2.1 -- the rings' spin-up and back
local STAMP_AT = 0.62 -- the rune lands in the pages
local up = Vector3.yAxis
local altars = {} -- [altar model] = { perm = { [key] = level }, riteUntil, tomeLight, tomeBase, tomeColor }

local function fxPart(parent, size, cf, color, shape, material)
	local p = Instance.new("Part")
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.Neon
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	if shape then
		p.Shape = shape
	end
	p.Parent = parent
	return p
end

local function smooth(x)
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

-- where the tome lies and which way the altar faces (its -Z looks towards the bridge)
local function tomeInfo(altarModel)
	local inner = altarModel:FindFirstChild("Altar")
	local light = inner and inner:FindFirstChild("TomeLight")
	local spine = inner and inner:FindFirstChild("Spine")
	local step
	for _, p in ipairs(inner and inner:GetChildren() or {}) do
		if p:IsA("BasePart") and p.Name == "Step" and p.Size.X > 7 then
			step = p
		end
	end
	if not (light and spine and step) then
		return nil
	end
	return { pos = light.Position - up * 0.75, spine = spine.CFrame, facing = step.CFrame.Rotation }
end

local function playRite(altarModel, key, st)
	local tome = tomeInfo(altarModel)
	if not tome then
		return
	end
	local color = PERM_COLORS[key] or Color3.new(1, 1, 1)
	local folder = Instance.new("Folder")
	folder.Name = "TomeRite"
	folder.Parent = Workspace
	local t0 = os.clock()
	local withRings = not (st.riteUntil and t0 < st.riteUntil) -- (a second buy during a rite: only the burst)
	st.riteUntil = t0 + RITE_TIME

	-- the rings: taken over from WorldFx, one extra full turn (so they rejoin it seamlessly), pulled in and down
	local rings = {}
	if withRings then
		for _, name in ipairs({ "RuneRing", "RuneRingInner" }) do
			local ring = altarModel:FindFirstChild(name)
			local base = ring and WorldFx.baseOf(ring)
			if base then
				WorldFx.pause(ring, true)
				local speed = ring:GetAttribute("SpinSpeed") or 0.3
				local pivot = ring:GetPivot()
				local parts = {}
				for _, p in ipairs(ring:GetDescendants()) do
					if p:IsA("BasePart") and p ~= ring.PrimaryPart then
						table.insert(parts, { part = p, offset = pivot:ToObjectSpace(p.CFrame) })
					end
				end
				table.insert(rings, { model = ring, name = name, base = base, speed = speed, parts = parts, sign = speed >= 0 and 1 or -1 })
			end
		end
	end

	-- one rune breaks out of the outer ring: the one nearest the camera
	local flyer
	local outer = rings[1]
	if outer and outer.name == "RuneRing" and #outer.parts > 0 then
		local camPos = Workspace.CurrentCamera.CFrame.Position
		local seed
		for _, e in ipairs(outer.parts) do
			if not seed or (e.part.Position - camPos).Magnitude < (seed.part.Position - camPos).Magnitude then
				seed = e
			end
		end
		local center = seed.part.Position
		local group = {}
		for _, e in ipairs(outer.parts) do
			if (e.part.Position - center).Magnitude < 1.0 then
				table.insert(group, e.part)
			end
		end
		local mid = Vector3.zero
		for _, p in ipairs(group) do
			mid += p.Position
		end
		mid /= #group
		flyer = { from = mid, originals = group, parts = {} }
		for _, p in ipairs(group) do
			local c = p:Clone()
			c.Parent = folder
			table.insert(flyer.parts, { part = c, rel = CFrame.new(mid):ToObjectSpace(p.CFrame) })
			p.LocalTransparencyModifier = 1
		end
	end

	-- the flash, the fluttering pages, the burst (built when the rune lands)
	local flash, pages, sigil, coins
	local light = st.tomeLight

	local conn
	conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - t0

		-- ── the rings ──
		local spin = smooth(t / RITE_TIME)
		local pull = math.sin(math.pi * math.clamp(t / (RITE_TIME * 0.85), 0, 1))
		for _, r in ipairs(rings) do
			local wf = r.base * CFrame.Angles(0, (os.clock() * r.speed) % (2 * math.pi), 0)
			local cf = wf * CFrame.Angles(0, r.sign * 2 * math.pi * spin, 0)
			local scale = 1 - 0.3 * pull
			for _, e in ipairs(r.parts) do
				if e.part.Parent then
					e.part.CFrame = cf * CFrame.new(e.offset.Position * Vector3.new(scale, 1, scale) - up * 0.6 * pull) * e.offset.Rotation
				end
			end
		end

		-- ── the rune swoops down into the pages ──
		if flyer then
			local u = math.clamp((t - 0.12) / (STAMP_AT - 0.12), 0, 1)
			local e = u * u
			local ctrl = (flyer.from + tome.pos) / 2 + up * 3
			local pos = flyer.from:Lerp(ctrl, e):Lerp(ctrl:Lerp(tome.pos, e), e)
			for _, f in ipairs(flyer.parts) do
				f.part.CFrame = CFrame.new(pos) * CFrame.Angles(0, u * 7, 0) * f.rel
				f.part.Transparency = u >= 1 and 1 or 0
			end
		end

		-- ── the stamp: flash, pages, burst ──
		if t >= STAMP_AT and not flash then
			flash = fxPart(folder, Vector3.one * 0.5, CFrame.new(tome.pos + up * 0.2), color, Enum.PartType.Ball)
			pages = {}
			for i = 1, 4 do
				pages[i] = fxPart(folder, Vector3.new(0.95, 0.04, 1.25), tome.spine, Color3.fromRGB(240, 230, 204),
					nil, Enum.Material.SmoothPlastic)
				pages[i].Transparency = 1
			end
			if key == "luckBoost" then
				local holder = fxPart(folder, Vector3.one * 0.3, CFrame.new(tome.pos + up * 0.3), color)
				holder.Transparency = 1
				local e = Instance.new("ParticleEmitter")
				e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
				e.Color = ColorSequence.new(color)
				e.LightEmission = 1
				e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0.05) })
				e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
				e.Lifetime = NumberRange.new(1, 1.7)
				e.Speed = NumberRange.new(2.5, 5.5)
				e.SpreadAngle = Vector2.new(45, 45)
				e.Drag = 1.5
				e.Rate = 0
				e.EmissionDirection = Enum.NormalId.Top
				e.Parent = holder
				e:Emit(45)
				-- the four-leaf sigil: four leaves and a stem, standing upright facing the bridge
				sigil = {}
				for k = 0, 3 do
					local a = k * math.pi / 2 + math.pi / 4
					local rel = CFrame.new(math.cos(a) * 0.48, math.sin(a) * 0.48, 0) * CFrame.Angles(0, 0, a - math.pi / 2)
					table.insert(sigil, { part = fxPart(folder, Vector3.new(0.62, 0.95, 0.12), tome.spine, color, Enum.PartType.Ball), rel = rel })
				end
				table.insert(sigil, { part = fxPart(folder, Vector3.new(0.12, 0.75, 0.12), tome.spine, color),
					rel = CFrame.new(0.16, -0.75, 0) * CFrame.Angles(0, 0, 0.35) })
			else
				coins = {}
				for _ = 1, 16 do
					local a = math.random() * 2 * math.pi
					local coin = fxPart(folder, Vector3.new(0.12, 0.62, 0.62), CFrame.new(tome.pos), Color3.fromRGB(236, 178, 48),
						Enum.PartType.Cylinder, Enum.Material.Metal)
					coin.Transparency = 1
					table.insert(coins, {
						part = coin,
						dir = Vector3.new(math.cos(a), 0, math.sin(a)),
						reach = 1.2 + math.random() * 2.6,
						height = 3 + math.random() * 3.5,
						delay = math.random() * 0.25,
						dur = 0.9 + math.random() * 0.35,
						spin = 8 + math.random() * 10,
					})
				end
			end
		end
		if flash then
			local s = t - STAMP_AT
			local f = math.clamp(s / 0.55, 0, 1)
			flash.Size = Vector3.one * (0.5 + 3.8 * f)
			flash.Transparency = 0.15 + 0.85 * f
			-- the pages flutter over from one side to the other, one after another
			for i, p in ipairs(pages) do
				local k = math.clamp((s - (i - 1) * 0.08) / 0.22, 0, 1)
				p.CFrame = tome.spine * CFrame.new(0, 0.14, 0) * CFrame.Angles(0, 0, math.pi * k) * CFrame.new(0.48, 0, 0)
				p.Transparency = (k <= 0 or k >= 1) and 1 or 0
			end
			if sigil then
				-- rises out of the pages, turns, then sinks back in and fades
				local rise = smooth(s / 0.35)
				local sink = smooth((s - 0.85) / 0.4)
				local h = 0.4 + 1.5 * rise - 1.7 * sink
				local cf = CFrame.new(tome.pos + up * h) * tome.facing * CFrame.Angles(0, s * 2.5, 0)
				local size = 0.3 + 0.7 * rise - 0.5 * sink
				for _, l in ipairs(sigil) do
					l.part.CFrame = cf * CFrame.new(l.rel.Position * size) * l.rel.Rotation
					l.part.Transparency = 0.05 + 0.95 * sink
				end
			end
			if coins then
				for _, c in ipairs(coins) do
					local u = math.clamp((s - c.delay) / c.dur, 0, 1)
					local pos = tome.pos + c.dir * c.reach * math.sin(math.pi * u) + up * (c.height * 4 * u * (1 - u))
					c.part.CFrame = CFrame.new(pos) * CFrame.Angles(s * c.spin, s * c.spin * 0.6, 0)
					c.part.Transparency = (u <= 0 or u >= 1) and 1 or 0
				end
			end
			if light and st.tomeColor then
				local g = math.max(0, 1 - s / 1.2)
				light.Color = st.tomeColor:Lerp(color, math.min(1, g * 2))
				light.Brightness = st.tomeBase + 6 * g
			end
		end

		-- ── the end: the rings rejoin WorldFx, the rune shows again in its place ──
		if t >= RITE_TIME then
			conn:Disconnect()
			for _, r in ipairs(rings) do
				WorldFx.pause(r.model, false)
			end
			if flyer then
				for _, p in ipairs(flyer.originals) do
					p.LocalTransparencyModifier = 0
				end
			end
			if light and st.tomeColor then
				light.Color = st.tomeColor
				light.Brightness = st.tomeBase
			end
			folder:Destroy()
		end
	end)
end

local function addAltarState(altarModel)
	if altars[altarModel] then
		return
	end
	local st = { perm = {} }
	altars[altarModel] = st
	local function findLight()
		local inner = altarModel:FindFirstChild("Altar")
		local holder = inner and inner:FindFirstChild("TomeLight")
		local light = holder and holder:FindFirstChildOfClass("PointLight")
		if light and not st.tomeLight then
			st.tomeLight = light
			st.tomeBase = light.Brightness
			st.tomeColor = light.Color
		end
	end
	findLight()
	altarModel.DescendantAdded:Connect(findLight)
end

-- ── Registering braziers (they can stream in after the altar) ──
local function addBrazier(altarModel, m)
	if braziers[m] or not m:IsA("Model") or m.Name ~= "Brazier" then
		return
	end
	local anchor = m:FindFirstChild("FlameAnchor")
	local fire = anchor and anchor:FindFirstChild("Flame")
	if not fire then
		-- not streamed in completely yet: try again when parts arrive
		return
	end
	-- the flame itself is a built-in Fire (the particle flame is too faint in the dusk light); the particle emitter
	-- only bursts on a flare (many bright particles add up to white under the bloom: keep the colour strong)
	local color = m:GetAttribute("FlameColor") or Color3.new(1, 1, 1)
	fire.Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.12), color)
	fire.LightEmission = 0.55
	fire.Rate = 0
	local flame = anchor:FindFirstChild("AltarFire") or Instance.new("Fire")
	flame.Name = "AltarFire"
	flame.Color = color
	flame.SecondaryColor = color:Lerp(Color3.new(0, 0, 0), 0.45)
	flame.Parent = anchor
	braziers[m] = {
		spark = fire,
		altar = altarModel,
		key = m:GetAttribute("Upgrade"),
		color = m:GetAttribute("FlameColor") or Color3.new(1, 1, 1),
		anchor = anchor,
		fire = flame,
		souls = anchor:FindFirstChild("Souls"),
		light = anchor:FindFirstChild("FlameLight"),
		coals = m:FindFirstChild("Coals"),
		k = nil, -- the shown size (eases towards the level)
		level = nil, -- the level last seen (nil = not known yet: no flare for the first value)
		flareAt = nil,
	}
end

local function addAltar(altarModel)
	addAltarState(altarModel)
	for _, d in ipairs(altarModel:GetDescendants()) do
		if d:IsA("Model") and d.Name == "Brazier" then
			addBrazier(altarModel, d)
		end
	end
	altarModel.DescendantAdded:Connect(function(d)
		-- a brazier or one of its emitters arrived (StreamingEnabled)
		local m = d:IsA("Model") and d.Name == "Brazier" and d or d:FindFirstAncestor("Brazier")
		if m and m:IsDescendantOf(altarModel) then
			task.defer(addBrazier, altarModel, m)
		end
	end)
end

for _, a in ipairs(CollectionService:GetTagged("SoulAltar")) do
	addAltar(a)
end
CollectionService:GetInstanceAddedSignal("SoulAltar"):Connect(addAltar)

-- ── Every frame: ease the flames to their levels, flare on a new level ──
RunService.Heartbeat:Connect(function(dt)
	local camera = Workspace.CurrentCamera
	local camPos = camera and camera.CFrame.Position
	local now = os.clock()
	for m, st in pairs(braziers) do
		if not m.Parent or not st.anchor.Parent then
			braziers[m] = nil
		elseif not camPos or (st.anchor.Position - camPos).Magnitude < MAX_DISTANCE then
			local level = st.altar:GetAttribute("Level_" .. tostring(st.key)) or 0
			if st.level and level > st.level then
				st.flareAt = now
				st.spark:Emit(14)
				if st.souls then
					st.souls:Emit(10)
				end
				soulStream(st)
			end
			st.level = level
			local target = intensity(st.key, level)
			if highlighted == st.key then
				target = math.max(target, 0.25)
			end
			st.k = st.k and (st.k + (target - st.k) * (1 - math.exp(-dt * EASE))) or target
			local boost = 0
			if st.flareAt then
				local f = (now - st.flareAt) / FLARE_TIME
				if f >= 1 then
					st.flareAt = nil
				else
					boost = math.sin(math.pi * math.min(1, f * 3)) * 0.4 + (1 - f) * 0.6
				end
			end
			if highlighted == st.key then
				boost += 0.35 + 0.12 * math.sin(now * 6)
			end
			-- a hovered card: the other braziers sink to embers so the hovered one (or the tome) stands out
			local dimTarget = (highlighted ~= nil and highlighted ~= st.key) and 1 or 0
			st.dim = (st.dim or 0) + (dimTarget - (st.dim or 0)) * (1 - math.exp(-dt * 6))
			apply(st, st.k * (1 - 0.8 * st.dim), boost * (1 - st.dim))
		end
	end
	-- the permanent upgrades: a new level is written into the tome; a hovered one makes the tome glow
	for altarModel, st in pairs(altars) do
		if not altarModel.Parent then
			altars[altarModel] = nil
		else
			for key in pairs(PERM_COLORS) do
				local level = altarModel:GetAttribute("Perm_" .. key)
				if level and st.perm[key] and level > st.perm[key] then
					local tome = tomeInfo(altarModel)
					if tome and camPos and (tome.pos - camPos).Magnitude < MAX_DISTANCE then
						playRite(altarModel, key, st)
					end
				end
				st.perm[key] = level
			end
			local riteRunning = st.riteUntil and now < st.riteUntil
			if st.tomeLight and not riteRunning then
				local hover = PERM_COLORS[highlighted]
				st.tomeLight.Color = hover and st.tomeColor:Lerp(hover, 0.85) or st.tomeColor
				st.tomeLight.Brightness = st.tomeBase + (hover and (1.8 + 0.6 * math.sin(now * 5)) or 0)
			end
		end
	end
end)

function AltarFx.highlight(key)
	highlighted = key
end

return AltarFx
