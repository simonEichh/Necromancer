-- The titan's tremor binds the army (server: Army stops stunned units; it sets StunFrom / StunUntil, server times, on
-- each unit model it reaches). For every kind of unit (walking, floating, towers, later vehicles) the effect is sized to
-- the model's bounding box: a ring of glowing runes circles the unit at mid-height, a second slower ring turns at its
-- feet, a faint green shimmer rises from it. UnitAnimator freezes the unit's animation meanwhile (isStunned). When the
-- stun ends the rings burst into sparks.
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local SOUL = Color3.fromRGB(80, 255, 160)
local RUNES_TOP, RUNES_FEET = 10, 14

local StunFx = {}

-- true while the server has `model` stunned (UnitAnimator holds its pose)
function StunFx.isStunned(model, serverNow)
	local from, untilT = model:GetAttribute("StunFrom"), model:GetAttribute("StunUntil")
	return from ~= nil and untilT ~= nil and serverNow >= from and serverNow < untilT
end

local active = {} -- [model] = { folder, rings = { { parts, radius, y, speed } }, untilT }

local function rune(folder, size)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = SOUL
	p.Size = size
	p.Transparency = 1
	p.Parent = folder
	TweenService:Create(p, TweenInfo.new(0.4), { Transparency = 0.15 }):Play()
	return p
end

-- the box the rings are sized to: the model's bounding box, or (model attributes StunCore = a part's name, StunSize) a
-- box round that part, for models whose bounding box is not their body (Veyr: his long rifle, and he floats high
-- above his root part on his perch)
local function bounds(model)
	local coreName = model:GetAttribute("StunCore")
	local core = coreName and model:FindFirstChild(coreName)
	if core and core:IsA("BasePart") then
		return CFrame.new(core.Position), (model:GetAttribute("StunSize") or Vector3.new(3, 6, 3)) * model:GetScale()
	end
	return model:GetBoundingBox()
end

local function bind(model, untilT)
	local cf, size = bounds(model)
	local folder = Instance.new("Folder")
	folder.Name = "StunFx"
	folder.Parent = workspace
	local radius = math.max(size.X, size.Z) / 2 + 1.2
	local rings = {}
	-- a ring of runes round the middle of the body, a wider slower one at the feet
	for _, spec in ipairs({ { RUNES_TOP, radius, 0, 1.4 }, { RUNES_FEET, radius + 1, -size.Y / 2 + 0.3, -0.6 } }) do
		local count, r, y, speed = spec[1], spec[2], spec[3], spec[4]
		local parts = {}
		for k = 1, count do
			local tall = (k % 2 == 0) and 0.9 or 0.55
			table.insert(parts, rune(folder, Vector3.new(0.18, tall + r * 0.04, 0.5 + r * 0.03)))
		end
		table.insert(rings, { parts = parts, radius = r, y = y, speed = speed })
	end
	local holder = Instance.new("Part")
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.Transparency = 1
	holder.Size = Vector3.new(size.X, 0.5, size.Z)
	holder.CFrame = cf * CFrame.new(0, -size.Y / 2, 0)
	holder.Parent = folder
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(SOUL)
	e.LightEmission = 1
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
	e.Lifetime = NumberRange.new(1, 1.8)
	e.Speed = NumberRange.new(1, 3)
	e.SpreadAngle = Vector2.new(10, 10)
	e.Acceleration = Vector3.new(0, 2, 0)
	e.Rate = math.clamp(size.X * size.Z * 0.15, 4, 30)
	e.Shape = Enum.ParticleEmitterShape.Box
	e.EmissionDirection = Enum.NormalId.Top
	e.Parent = holder
	active[model] = { folder = folder, rings = rings, untilT = untilT, centre = cf.Position, height = size.Y, emitter = e }
end

local function release(model, burst)
	local a = active[model]
	if not a then return end
	active[model] = nil
	a.emitter.Enabled = false
	for _, ring in ipairs(a.rings) do
		for _, p in ipairs(ring.parts) do
			if burst then
				-- the runes fly apart and fade
				local out = (p.Position - a.centre)
				out = Vector3.new(out.X, 0, out.Z).Unit * 4 + Vector3.new(0, 2, 0)
				TweenService:Create(p, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = p.CFrame + out, Transparency = 1 }):Play()
			else
				p.Transparency = 1
			end
		end
	end
	Debris:AddItem(a.folder, 0.8)
end

RunService.RenderStepped:Connect(function()
	local serverNow = workspace:GetServerTimeNow()
	local clock = os.clock()
	-- start: every unit model with a running stun (all units are procedural rigs tagged ProceduralUnit)
	for _, model in ipairs(CollectionService:GetTagged("ProceduralUnit")) do
		if not active[model] then
			local untilT = model:GetAttribute("StunUntil")
			if untilT and serverNow < untilT and StunFx.isStunned(model, serverNow) then
				bind(model, untilT)
			end
		end
	end
	for model, a in pairs(active) do
		if not model.Parent or serverNow >= a.untilT then
			release(model, model.Parent ~= nil)
		else
			local cf = bounds(model)
			a.centre = cf.Position
			for _, ring in ipairs(a.rings) do
				local n = #ring.parts
				for k, p in ipairs(ring.parts) do
					local ang = clock * ring.speed + (k / n) * math.pi * 2
					local pos = cf.Position + Vector3.new(math.cos(ang) * ring.radius, ring.y + math.sin(clock * 2 + k) * 0.15, math.sin(ang) * ring.radius)
					p.CFrame = CFrame.lookAt(pos, Vector3.new(cf.Position.X, pos.Y, cf.Position.Z))
				end
			end
		end
	end
end)

return StunFx
