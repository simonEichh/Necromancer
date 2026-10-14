-- Damage stages of the modelled walls (models tagged "StagedWall", attribute `Stage` set by the server's Walls.lua from
-- the wall's HP; the model is built by tools/studio/build_wall_cemetery.lua):
--   1 (75 % HP)  the fence bends, some pickets fall, tombstones topple, loose fieldstones drop
--   2 (50 %)     cracks with soul light open in the middle, the cross tilts
--   3 (25 %)     the middle caves in, its coping slides off, the middle fence falls, the lanterns drop
--   4 (broken)   everything collapses, the middle first and the wings last, then it fades (the server removes it)
-- Purely cosmetic and client side. A wall first seen at a later stage gets the earlier stages instantly.
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local MIDDLE_ANGLE = 28 -- degrees: segments / pickets inside this are "the middle" (where the fence stands)
local DUST_COLOR = Color3.fromRGB(120, 112, 100)

-- deterministic 0..1 per piece, so every client bends the same pickets
local function hash(i, k)
	local x = math.sin(i * 12.9898 + k * 78.233) * 43758.5453
	return x - math.floor(x)
end

-- ============================================================
-- Moving helpers
-- ============================================================
local function moveModel(m, target, t, style, dir, delay)
	if t <= 0 then
		m:PivotTo(target)
		return
	end
	local v = Instance.new("CFrameValue")
	v.Value = m:GetPivot()
	v.Changed:Connect(function(cf)
		if m.Parent then
			m:PivotTo(cf)
		end
	end)
	local tw = TweenService:Create(v, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.In, 0, false, delay or 0), { Value = target })
	tw.Completed:Connect(function()
		v:Destroy()
	end)
	tw:Play()
end

local function movePart(p, target, t, style, dir, delay)
	if t <= 0 then
		p.CFrame = target
		return
	end
	TweenService:Create(p, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.In, 0, false, delay or 0), { CFrame = target }):Play()
end

local function fadeOut(inst, t, delay)
	local list = inst:IsA("BasePart") and { inst } or inst:GetDescendants()
	for _, p in ipairs(list) do
		if p:IsA("BasePart") then
			if t <= 0 then
				p.Transparency = 1
			else
				TweenService:Create(p, TweenInfo.new(t, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, 0, false, delay or 0), { Transparency = 1 }):Play()
			end
		elseif p:IsA("Light") then
			p.Enabled = false
		end
	end
end

-- ============================================================
-- Effects (only when animated)
-- ============================================================
local function dust(pos, amount)
	local holder = Instance.new("Part")
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.Transparency = 1
	holder.Size = Vector3.new(1, 1, 1)
	holder.Position = pos
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	e.Color = ColorSequence.new(DUST_COLOR)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2.5), NumberSequenceKeypoint.new(1, 7) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) })
	e.Lifetime = NumberRange.new(1.2, 2.2)
	e.Speed = NumberRange.new(4, 11)
	e.SpreadAngle = Vector2.new(180, 60)
	e.Drag = 2
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-40, 40)
	e.Enabled = false
	e.Parent = holder
	holder.Parent = workspace
	e:Emit(amount or 25)
	Debris:AddItem(holder, 3)
end

local function chunks(pos, front, color, n)
	for _ = 1, n do
		local s = 0.6 + math.random() * 1.2
		local c = Instance.new("Part")
		c.Size = Vector3.new(s, s * 0.8, s)
		c.Color = color
		c.Material = Enum.Material.Slate
		c.CollisionGroup = "Debris"
		c.CFrame = CFrame.new(pos + Vector3.new((math.random() - 0.5) * 6, (math.random() - 0.5) * 3, (math.random() - 0.5) * 2))
		c.AssemblyLinearVelocity = front * (4 + math.random() * 8) + Vector3.new((math.random() - 0.5) * 8, 4 + math.random() * 8, 0)
		c.AssemblyAngularVelocity = Vector3.new(math.random(-6, 6), math.random(-6, 6), math.random(-6, 6))
		c.Parent = workspace
		Debris:AddItem(c, 2.5)
	end
end

-- ============================================================
-- Stages
-- ============================================================
local function angleOf(m)
	return math.abs(m:GetAttribute("Angle") or 0)
end

-- lays a piece flat on the ground a few studs in front of where it stood
local function fallToGround(w, m, i, t)
	local pivot = m:GetPivot()
	local groundY = w.pivot.Position.Y
	local pos = Vector3.new(pivot.Position.X, groundY + 0.3, pivot.Position.Z) + w.front * (2 + hash(i, 7) * 3)
	local target = CFrame.lookAt(pos, pos + w.front) * CFrame.Angles(-math.rad(85), 0, math.rad((hash(i, 8) - 0.5) * 60))
	moveModel(m, target, t, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out, t > 0 and hash(i, 9) * 0.3 or 0)
	m:SetAttribute("Fallen", true)
end

local STAGES = {}

STAGES[1] = function(w, t)
	for i, p in ipairs(w.pickets) do
		if hash(i, 1) < 0.15 then
			fallToGround(w, p, i, t * 1.2)
		elseif hash(i, 1) < 0.5 then
			local bend = p:GetPivot() * CFrame.Angles(math.rad((hash(i, 2) - 0.5) * 70), 0, math.rad((hash(i, 3) - 0.5) * 30))
			moveModel(p, bend, t, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		end
	end
	for i, g in ipairs(w.graves) do
		local topple = g:GetPivot() * CFrame.Angles(-math.rad(20 + hash(i, 4) * 30), 0, math.rad((hash(i, 5) - 0.5) * 20))
		moveModel(g, topple, t, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out)
	end
	for i, f in ipairs(w.fieldstones) do
		if hash(i, 6) < 0.5 then
			f.Parent = w.model -- leaves its segment (it must not move with it later)
			local pos = Vector3.new(f.Position.X, w.pivot.Position.Y + 0.5, f.Position.Z) + w.front * (1.5 + hash(i, 7) * 2)
			movePart(f, CFrame.new(pos) * CFrame.Angles(hash(i, 8) * 3, hash(i, 9) * 6, 0), t, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out)
		end
	end
	if t > 0 then
		dust(w.center + Vector3.new(0, 4, 0) + w.front * 3, 20)
		chunks(w.center + Vector3.new(0, 14, 0), w.front, w.stoneColor, 4)
	end
end

STAGES[2] = function(w, t)
	local soul = w.model:GetAttribute("SoulColor") or Color3.fromRGB(120, 255, 190)
	for i, seg in ipairs(w.segments) do
		if angleOf(seg) <= MIDDLE_ANGLE then
			local h = seg:GetAttribute("Height") or 20
			local th = seg:GetAttribute("Thickness") or 4
			local width = seg:GetAttribute("Width") or 6
			local foot = seg:GetPivot()
			-- a zigzag of 3 short neon strokes on the front face
			local x = (hash(i, 10) - 0.5) * (width - 2)
			local y = 3 + hash(i, 11) * (h - 8)
			for k = 1, 3 do
				local len = 2 + hash(i, 12 + k) * 2.5
				local ang = (k % 2 == 0 and 1 or -1) * (25 + hash(i, 15 + k) * 30)
				local crack = Instance.new("Part")
				crack.Name = "Crack"
				crack.Anchored = true
				crack.CanCollide = false
				crack.CanQuery = false
				crack.CastShadow = false
				crack.Material = Enum.Material.Neon
				crack.Color = soul
				crack.Size = Vector3.new(0.22, len, 0.12)
				crack.CFrame = foot * CFrame.new(x, y, -th / 2 - 0.08) * CFrame.Angles(0, 0, math.rad(ang)) * CFrame.new(0, len / 2, 0)
				crack.Transparency = t > 0 and 1 or 0
				crack.Parent = seg
				if t > 0 then
					TweenService:Create(crack, TweenInfo.new(t * 0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, k * 0.12), { Transparency = 0 }):Play()
				end
				local tip = crack.CFrame * CFrame.new(0, len / 2, 0)
				x, y = (foot:PointToObjectSpace(tip.Position)).X, (foot:PointToObjectSpace(tip.Position)).Y
			end
		end
	end
	local light = Instance.new("PointLight")
	light.Color = soul
	light.Range = 18
	light.Brightness = 1.2
	light.Shadows = false
	local holder = w.segments[math.ceil(#w.segments / 2)]
	local lightPart = holder and holder:FindFirstChild("Stone")
	if lightPart then
		light.Parent = lightPart
	end
	if w.cross then
		moveModel(w.cross, w.cross:GetPivot() * CFrame.Angles(0, 0, math.rad(18)), t, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	end
	if t > 0 then
		dust(w.center + Vector3.new(0, 8, 0) + w.front * 2, 25)
		chunks(w.center + Vector3.new(0, 12, 0), w.front, w.stoneColor, 6)
	end
end

STAGES[3] = function(w, t)
	for i, seg in ipairs(w.segments) do
		if angleOf(seg) <= MIDDLE_ANGLE then
			local h = seg:GetAttribute("Height") or 20
			local coping = seg:FindFirstChild("Coping")
			if coping then
				coping.Parent = w.model -- slides off on its own
				local pos = Vector3.new(coping.Position.X, w.pivot.Position.Y + 0.5, coping.Position.Z) + w.front * (2 + hash(i, 20) * 3)
				movePart(coping, CFrame.lookAt(pos, pos + w.front) * CFrame.Angles(0, 0, math.rad((hash(i, 21) - 0.5) * 30)), t * 1.2,
					Enum.EasingStyle.Bounce, Enum.EasingDirection.Out)
			end
			local sink = seg:GetPivot() * CFrame.new(0, -h * (0.35 + hash(i, 22) * 0.2), 0)
				* CFrame.Angles(math.rad((hash(i, 23) - 0.5) * 10), 0, math.rad((hash(i, 24) - 0.5) * 10))
			moveModel(seg, sink, t, Enum.EasingStyle.Quad, Enum.EasingDirection.In, t > 0 and hash(i, 25) * 0.25 or 0)
		end
	end
	for i, p in ipairs(w.pickets) do
		if angleOf(p) <= MIDDLE_ANGLE and not p:GetAttribute("Fallen") then
			fallToGround(w, p, i, t)
		end
	end
	if w.cross then
		fallToGround(w, w.cross, 99, t)
	end
	for i, l in ipairs(w.lanterns) do
		local drop = l:GetAttribute("Drop") or 8
		moveModel(l, l:GetPivot() * CFrame.new(0, -drop + 0.6, 0) * CFrame.Angles(math.rad(70), 0, 0), t * 0.8, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out)
		local glow = l:FindFirstChild("LanternGlow")
		if glow then
			glow.Color = Color3.fromRGB(60, 50, 40)
			glow.Material = Enum.Material.Glass
			local light = glow:FindFirstChildOfClass("PointLight")
			if light then
				light.Enabled = false
			end
		end
	end
	if t > 0 then
		dust(w.center + w.front * 2, 40)
		chunks(w.center + Vector3.new(0, 10, 0), w.front, w.stoneColor, 10)
	end
end

STAGES[4] = function(w, t)
	if t <= 0 then
		fadeOut(w.model, 0)
		return
	end
	for i, seg in ipairs(w.segments) do
		local h = seg:GetAttribute("Height") or 20
		local delay = angleOf(seg) / 50 * 0.8 -- the middle first, the wings last
		local down = seg:GetPivot() * CFrame.new(0, -(h + 1), 0) * CFrame.Angles(math.rad((hash(i, 30) - 0.5) * 16), 0, math.rad((hash(i, 31) - 0.5) * 16))
		moveModel(seg, down, 0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.In, delay)
		if i % 3 == 0 then
			task.delay(delay, function()
				dust(seg:GetPivot().Position + Vector3.new(0, 3, 0), 15)
			end)
		end
	end
	for i, p in ipairs(w.pickets) do
		if not p:GetAttribute("Fallen") then
			fallToGround(w, p, i, 0.8)
		end
	end
	for i, g in ipairs(w.graves) do
		moveModel(g, g:GetPivot() * CFrame.Angles(-math.rad(60), 0, 0), 0.7, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out, 0.3 + hash(i, 32) * 0.4)
	end
	dust(w.center + w.front * 3, 50)
	chunks(w.center + Vector3.new(0, 8, 0), w.front, w.stoneColor, 14)
	fadeOut(w.model, 0.8, 1.6)
end

-- ============================================================
-- Registering walls
-- ============================================================
local registered = setmetatable({}, { __mode = "k" })

local function register(model)
	if registered[model] then return end
	registered[model] = true
	-- the tag can arrive before all the model's parts have replicated: wait for them (the build script stores the count)
	local want = model:GetAttribute("Parts") or 0
	local deadline = os.clock() + 10
	while model.Parent and os.clock() < deadline do
		local n = 0
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("BasePart") then
				n += 1
			end
		end
		if n >= want then
			break
		end
		task.wait(0.2)
	end
	if not model.Parent then return end
	local w = { model = model, applied = 0, segments = {}, pickets = {}, graves = {}, lanterns = {}, fieldstones = {} }
	w.pivot = model:GetPivot()
	w.front = w.pivot.LookVector -- the model's front (-Z) faces the army
	w.center = w.pivot.Position
	w.stoneColor = Color3.fromRGB(110, 111, 104)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("Model") then
			if d.Name == "Segment" then
				table.insert(w.segments, d)
			elseif d.Name == "Picket" then
				table.insert(w.pickets, d)
			elseif d.Name == "Grave" then
				table.insert(w.graves, d)
			elseif d.Name == "Lantern" then
				table.insert(w.lanterns, d)
			elseif d.Name == "Cross" then
				w.cross = d
			end
		elseif d.Name == "Fieldstone" then
			table.insert(w.fieldstones, d)
		end
	end

	local function apply(animate)
		local target = model:GetAttribute("Stage") or 0
		while w.applied < target do
			w.applied += 1
			local stage = STAGES[w.applied]
			if stage then
				-- several stages at once (a fast army): only the last one is animated
				local ok, err = pcall(stage, w, (animate and w.applied == target) and 0.7 or 0)
				if not ok then
					warn("WallStages: " .. tostring(err))
				end
			end
		end
	end
	apply(false)
	model:GetAttributeChangedSignal("Stage"):Connect(function()
		apply(true)
	end)
end

for _, m in ipairs(CollectionService:GetTagged("StagedWall")) do
	task.spawn(register, m)
end
CollectionService:GetInstanceAddedSignal("StagedWall"):Connect(function(m)
	task.spawn(register, m)
end)

return {}
