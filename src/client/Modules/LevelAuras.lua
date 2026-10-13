-- Level auras: a necromantic aura around upgraded units, drawn only on the client from the model attribute `Level`
-- (set by the server in Army.spawnUnit / setUnitLevel). Every tier keeps the layers of the tiers below and adds one:
--   level 3  Grave Mark      souls rising from a ring around the feet
--   level 6  Soul Orbit      + soul orbs with trails circling the body, a soft green light
--   level 9  Necrotic Flame  + dark green flames licking up from the feet, black miasma on the ground
--   level 10 Lich Crown      + a ring of small skulls with glowing eyes circling above the head, a violet core in the
--                            flames, and a flash when the level is reached
-- Same look for every unit (no rarity special cases); sizes follow the unit's bounding box. Auras are only built for
-- units near the camera. Highlights are NOT used (Roblox draws at most 31 per client).
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local TAG = "ProceduralUnit"
local BUILD_DISTANCE = 140 -- auras exist only for units this close to the camera
local CHECK_INTERVAL = 0.5

local SOUL = Color3.fromRGB(120, 255, 190)
local SOUL_PALE = Color3.fromRGB(200, 255, 230)
local NECRO = Color3.fromRGB(40, 150, 80)
local NECRO_DARK = Color3.fromRGB(10, 40, 24)
local VOID = Color3.fromRGB(160, 70, 255)
local BONE = Color3.fromRGB(226, 220, 196)

local TIERS = { 3, 6, 9, 10 }

local auras = {} -- [model] = { level, folder, orbs = {welds}, skulls = {welds}, size, t0 }

local function seq(...)
	local keys = {}
	for _, k in ipairs({ ... }) do
		table.insert(keys, NumberSequenceKeypoint.new(k[1], k[2]))
	end
	return NumberSequence.new(keys)
end

local function tierOf(level)
	local tier = 0
	for i, need in ipairs(TIERS) do
		if (level or 0) >= need then
			tier = i
		end
	end
	return tier
end

local function rootOf(model)
	return model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
end

-- an invisible, massless part welded to the unit's root
local function holder(folder, root, name, size, offset)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Transparency = 1
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = false
	p.CFrame = root.CFrame * offset
	p.Parent = folder
	local w = Instance.new("Weld")
	w.Part0 = root
	w.Part1 = p
	w.C0 = offset
	w.Parent = p
	return p, w
end

local function visiblePart(folder, root, name, size, offset, color, shape, transparency)
	local p, w = holder(folder, root, name, size, offset)
	p.Transparency = transparency or 0
	p.Color = color
	p.Material = Enum.Material.Neon
	if shape then p.Shape = shape end
	return p, w
end

local function emitter(parent, props)
	local e = Instance.new("ParticleEmitter")
	for k, v in pairs(props) do
		e[k] = v
	end
	e.Parent = parent
	return e
end

-- ============================================================
-- Building
-- ============================================================
local function build(model, level)
	local root = rootOf(model)
	if not root then return nil end
	local tier = tierOf(level)
	if tier == 0 then return nil end

	-- the unit's size: width and height of its body, and where its feet are relative to the root
	local bbCf, bbSize = model:GetBoundingBox()
	local height = math.max(2, bbSize.Y)
	local width = math.clamp(math.max(bbSize.X, bbSize.Z) * 0.6, 2, 30)
	local feetY = (bbCf.Position.Y - bbSize.Y / 2) - root.Position.Y -- negative: below the root
	local s = math.clamp(height / 5, 0.6, 8) -- particle scale (a Skelly is about 5 tall)

	local folder = Instance.new("Folder")
	folder.Name = "LevelAura"
	folder.Parent = model
	local aura = { level = level, folder = folder, orbs = {}, skulls = {}, t0 = os.clock(), width = width, height = height, feetY = feetY }

	-- 1) Grave Mark: souls rise from a ring around the feet (no visible ground circle: the user did not want one)
	local ringR = width * 0.75 + 0.6
	local rim = holder(folder, root, "AuraRim", Vector3.new(ringR * 2, 0.1, ringR * 2), CFrame.new(0, feetY + 0.15, 0))
	emitter(rim, {
		Name = "Souls",
		Texture = "rbxasset://textures/particles/sparkles_main.dds",
		Color = ColorSequence.new(SOUL_PALE, SOUL),
		LightEmission = 1,
		Size = seq({ 0, 0.25 * s }, { 0.5, 0.35 * s }, { 1, 0 }),
		Transparency = seq({ 0, 0.2 }, { 0.7, 0.4 }, { 1, 1 }),
		Lifetime = NumberRange.new(1.2, 2.0),
		Rate = 10 + 4 * tier,
		Speed = NumberRange.new(1.2 * s, 2.2 * s),
		EmissionDirection = Enum.NormalId.Top,
		Shape = Enum.ParticleEmitterShape.Disc,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
		ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward,
		SpreadAngle = Vector2.new(5, 5),
	})

	-- 2) Soul Orbit: orbs circling the body (moved every frame), a soft light
	if tier >= 2 then
		local orbR = width * 0.6 + 0.8
		for k = 1, 3 do
			local orb, w = visiblePart(folder, root, "AuraOrb", Vector3.new(0.45, 0.45, 0.45) * math.min(s, 3), CFrame.new(), SOUL_PALE, Enum.PartType.Ball, 0.1)
			local a0 = Instance.new("Attachment", orb)
			a0.Position = Vector3.new(0, 0.18 * math.min(s, 3), 0)
			local a1 = Instance.new("Attachment", orb)
			a1.Position = Vector3.new(0, -0.18 * math.min(s, 3), 0)
			local trail = Instance.new("Trail")
			trail.Attachment0, trail.Attachment1 = a0, a1
			trail.Color = ColorSequence.new(SOUL, NECRO)
			trail.Transparency = seq({ 0, 0.2 }, { 1, 1 })
			trail.Lifetime = 0.45
			trail.LightEmission = 1
			trail.FaceCamera = true
			trail.Parent = orb
			table.insert(aura.orbs, { weld = w, radius = orbR, phase = (k - 1) / 3 * 2 * math.pi, y = feetY + height * (0.45 + 0.1 * k) })
		end
		local glow = holder(folder, root, "AuraLight", Vector3.new(0.2, 0.2, 0.2), CFrame.new(0, feetY + height * 0.4, 0))
		local light = Instance.new("PointLight")
		light.Color = SOUL
		light.Range = 6 + width * 2
		light.Brightness = 0.8
		light.Shadows = false
		light.Parent = glow
	end

	-- 3) Necrotic Flame: dark green flames up the body, black miasma at the feet
	if tier >= 3 then
		local body = holder(folder, root, "AuraBody", Vector3.new(width, height * 0.8, width * 0.8), CFrame.new(0, feetY + height * 0.4, 0))
		local flameColor = (tier >= 4)
			and ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(230, 200, 255)), ColorSequenceKeypoint.new(0.35, VOID), ColorSequenceKeypoint.new(0.7, NECRO), ColorSequenceKeypoint.new(1, NECRO_DARK) })
			or ColorSequence.new({ ColorSequenceKeypoint.new(0, SOUL_PALE), ColorSequenceKeypoint.new(0.4, NECRO), ColorSequenceKeypoint.new(1, NECRO_DARK) })
		emitter(body, {
			Name = "Flame",
			Texture = "rbxasset://textures/particles/fire_main.dds",
			Color = flameColor,
			LightEmission = 0.35,
			Size = seq({ 0, 1.6 * s }, { 0.3, 2.6 * s }, { 1, 0.2 * s }),
			Transparency = seq({ 0, 0.2 }, { 0.6, 0.5 }, { 1, 1 }),
			Lifetime = NumberRange.new(0.7, 1.1),
			Rate = 80,
			Speed = NumberRange.new(4 * s, 7 * s),
			SpreadAngle = Vector2.new(10, 10),
			EmissionDirection = Enum.NormalId.Top,
			Shape = Enum.ParticleEmitterShape.Box,
			ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
			Rotation = NumberRange.new(-15, 15),
			RotSpeed = NumberRange.new(-25, 25),
		})
		-- a hot inner core close to the body
		emitter(body, {
			Name = "FlameCore",
			Texture = "rbxasset://textures/particles/fire_main.dds",
			Color = ColorSequence.new((tier >= 4) and Color3.fromRGB(240, 220, 255) or SOUL_PALE, (tier >= 4) and VOID or SOUL),
			LightEmission = 0.4,
			Size = seq({ 0, 1.4 * s }, { 0.5, 1.9 * s }, { 1, 0 }),
			Transparency = seq({ 0, 0.55 }, { 0.5, 0.7 }, { 1, 1 }),
			Lifetime = NumberRange.new(0.35, 0.6),
			Rate = 35,
			Speed = NumberRange.new(2 * s, 3.5 * s),
			EmissionDirection = Enum.NormalId.Top,
			Shape = Enum.ParticleEmitterShape.Box,
			ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
		})
		emitter(rim, {
			Name = "Miasma",
			Texture = "rbxasset://textures/particles/smoke_main.dds",
			Color = ColorSequence.new(Color3.fromRGB(20, 26, 22), Color3.fromRGB(8, 10, 12)),
			LightEmission = 0,
			Size = seq({ 0, 1.0 * s }, { 1, 2.4 * s }),
			Transparency = seq({ 0, 0.35 }, { 1, 1 }),
			Lifetime = NumberRange.new(1.5, 2.5),
			Rate = 20,
			Speed = NumberRange.new(0.3, 0.8),
			EmissionDirection = Enum.NormalId.Top,
			Shape = Enum.ParticleEmitterShape.Disc,
			ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
			Rotation = NumberRange.new(0, 360),
			RotSpeed = NumberRange.new(-15, 15),
		})
	end

	-- 4) Lich Crown: a ring of small skulls above the head
	if tier >= 4 then
		local crownR = math.max(1.1, width * 0.45)
		local sk = math.min(s, 3) * 1.5
		for k = 1, 5 do
			local skull, w = visiblePart(folder, root, "AuraSkull", Vector3.new(0.5, 0.5, 0.5) * sk, CFrame.new(), BONE, Enum.PartType.Ball, 0)
			skull.Material = Enum.Material.SmoothPlastic
			for _, side in ipairs({ -1, 1 }) do
				local eye = Instance.new("Part")
				eye.Name = "AuraSkullEye"
				eye.Shape = Enum.PartType.Ball
				eye.Size = Vector3.new(0.13, 0.13, 0.13) * sk
				eye.Material = Enum.Material.Neon
				eye.Color = SOUL
				eye.CanCollide, eye.CanQuery, eye.CanTouch, eye.Massless, eye.CastShadow = false, false, false, true, false
				eye.CFrame = skull.CFrame * CFrame.new(side * 0.11 * sk, 0.03 * sk, -0.21 * sk)
				eye.Parent = folder
				local ew = Instance.new("Weld")
				ew.Part0, ew.Part1 = skull, eye
				ew.C0 = CFrame.new(side * 0.11 * sk, 0.03 * sk, -0.21 * sk)
				ew.Parent = eye
			end
			local jaw = Instance.new("Part")
			jaw.Name = "AuraSkullJaw"
			jaw.Size = Vector3.new(0.3, 0.14, 0.26) * sk
			jaw.Material = Enum.Material.SmoothPlastic
			jaw.Color = BONE
			jaw.CanCollide, jaw.CanQuery, jaw.CanTouch, jaw.Massless, jaw.CastShadow = false, false, false, true, false
			jaw.Parent = folder
			local jw = Instance.new("Weld")
			jw.Part0, jw.Part1 = skull, jaw
			jw.C0 = CFrame.new(0, -0.24 * sk, -0.06 * sk)
			jw.Parent = jaw
			table.insert(aura.skulls, { weld = w, radius = crownR, phase = (k - 1) / 5 * 2 * math.pi, y = feetY + height + 0.5 * sk })
		end
	end

	return aura
end

local function destroy(model)
	local aura = auras[model]
	if aura then
		aura.folder:Destroy()
		auras[model] = nil
	end
end

-- a short burst of souls and a flash when a unit reaches the top level
local function maxLevelFlash(model)
	local root = rootOf(model)
	if not root then return end
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = false, false, false, false
	p.Shape = Enum.PartType.Ball
	p.Material = Enum.Material.Neon
	p.Color = SOUL_PALE
	p.Size = Vector3.new(1, 1, 1)
	p.CFrame = root.CFrame
	p.Parent = workspace
	local e = emitter(p, {
		Texture = "rbxasset://textures/particles/sparkles_main.dds",
		Color = ColorSequence.new(SOUL_PALE, VOID),
		LightEmission = 1,
		Size = seq({ 0, 0.8 }, { 1, 0 }),
		Lifetime = NumberRange.new(0.8, 1.4),
		Speed = NumberRange.new(10, 22),
		SpreadAngle = Vector2.new(180, 180),
		Rate = 0,
	})
	e:Emit(60)
	local t0 = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local f = (os.clock() - t0) / 0.5
		if f >= 1 then
			p.Transparency = 1
			conn:Disconnect()
			task.delay(1.6, function() p:Destroy() end)
			return
		end
		p.Size = Vector3.new(1, 1, 1) * (1 + 14 * f)
		p.Transparency = f
	end)
end

-- ============================================================
-- Tracking: build/destroy auras by level and distance, animate orbs and skulls
-- ============================================================
local tracked = {} -- [model] = true

local function refresh(model)
	local level = model:GetAttribute("Level") or 0
	local camera = workspace.CurrentCamera
	local root = rootOf(model)
	local near = camera and root and (root.Position - camera.CFrame.Position).Magnitude < BUILD_DISTANCE
	local want = (near and tierOf(level) > 0) and tierOf(level) or 0
	local have = auras[model] and tierOf(auras[model].level) or 0
	if want ~= have then
		destroy(model)
		if want > 0 then
			auras[model] = build(model, level)
		end
	end
end

local function track(model)
	if tracked[model] or not model:IsA("Model") then return end
	tracked[model] = true
	model:GetAttributeChangedSignal("Level"):Connect(function()
		local before = auras[model] and auras[model].level or 0
		refresh(model)
		local level = model:GetAttribute("Level") or 0
		if level >= TIERS[#TIERS] and before < TIERS[#TIERS] and auras[model] then
			maxLevelFlash(model)
		end
	end)
	refresh(model)
end

for _, model in ipairs(CollectionService:GetTagged(TAG)) do
	track(model)
end
CollectionService:GetInstanceAddedSignal(TAG):Connect(track)
CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(model)
	destroy(model)
	tracked[model] = nil
end)

-- every half second: build or drop auras as units come into or leave the camera's range
task.spawn(function()
	while true do
		task.wait(CHECK_INTERVAL)
		for model in pairs(tracked) do
			if model.Parent then
				refresh(model)
			else
				destroy(model)
				tracked[model] = nil
			end
		end
	end
end)

RunService.RenderStepped:Connect(function()
	local t = os.clock()
	for _, aura in pairs(auras) do
		for _, orb in ipairs(aura.orbs) do
			local a = t * 2.2 + orb.phase
			orb.weld.C0 = CFrame.new(math.cos(a) * orb.radius, orb.y + math.sin(t * 3 + orb.phase) * 0.25, math.sin(a) * orb.radius)
		end
		for _, skull in ipairs(aura.skulls) do
			local a = -t * 1.1 + skull.phase
			local pos = Vector3.new(math.cos(a) * skull.radius, skull.y + math.sin(t * 2 + skull.phase) * 0.1, math.sin(a) * skull.radius)
			-- each skull looks outward
			skull.weld.C0 = CFrame.lookAt(pos, pos + Vector3.new(pos.X, 0, pos.Z))
		end
	end
end)

return {}
