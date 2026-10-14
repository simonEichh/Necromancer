-- The Soul Altar's braziers in the world (tools/studio/build_altar.lua, placed by the server's PlotLook): every altar
-- (tag SoulAltar) carries its owner's realm upgrade levels as attributes Level_<key>; each Brazier model (attribute
-- Upgrade = the key) burns as high as its level: embers at level 0, a tall flame with rising souls near the top. The
-- upgrades with a max level (Swift March, Grasping Souls) reach the full flame at their max, the others (Army Might,
-- Soul Harvest) grow ever more slowly. When a level goes UP the brazier flares and a few souls fly from it into the
-- altar's tome; when the levels reset (a new realm) the flames sink back to embers.
--
--   AltarFx.highlight(key | nil)   -- the in-world Upgrades view lights one brazier while its card is hovered (step 3)
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Economy = require(ReplicatedStorage.Shared.Economy)

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
				boost += 0.25 + 0.1 * math.sin(now * 6)
			end
			apply(st, st.k, boost)
		end
	end
end)

function AltarFx.highlight(key)
	highlighted = key
end

return AltarFx
