-- The finger-beam attack (units whose model has AttackStyle = "FingerBeam", e.g. Hush). The server counts the attack
-- (model attribute AttackCount), sets AimPos (the spot on the wall) and deals the damage hitDelay seconds later; the
-- animation (UnitAnimator) points the sleeve at the wall and slides the claw finger out. This module draws, timed to that
-- animation: a small turning magic circle at the fingertip (part FingerTip), then a thin beam from the tip to AimPos with
-- a flash where it hits. Purely visual.
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local TAG = "ProceduralUnit"
local CIRCLE_AT = 0.42 -- seconds after the attack starts: the circle opens (the finger is out by then)
local FIRE_AT = 0.5 -- the beam fires (matches Units.Hush.hitDelay)
local CIRCLE_LIFE = 0.55
local BEAM_LIFE = 0.28
local MAX_DISTANCE = 220

local VIOLET = Color3.fromRGB(190, 120, 255)
local CORE = Color3.fromRGB(245, 230, 255)

local fx = Instance.new("Folder")
fx.Name = "FingerBeamFx"
fx.Parent = workspace

local active = {} -- running effects: { update = function(now) -> keepGoing }

local function newPart(size, color, transparency, shape)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = false, false, false, false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Size = size
	p.Transparency = transparency or 0
	if shape then p.Shape = shape end
	p.Parent = fx
	return p
end

-- a small magic circle (outer ring, inner ring, a triangle) at the fingertip, facing the wall, turning
local function magicCircle(tip, aimPos)
	local parts = {}
	local R1, R2 = 0.75, 0.5
	for k = 0, 13 do
		table.insert(parts, { part = newPart(Vector3.new(0.3, 0.05, 0.06), VIOLET), r = R1, a = k / 14 * math.pi * 2 })
	end
	for k = 0, 9 do
		table.insert(parts, { part = newPart(Vector3.new(0.27, 0.04, 0.05), CORE), r = R2, a = k / 10 * math.pi * 2 })
	end
	local tri = {}
	for k = 0, 2 do
		table.insert(tri, newPart(Vector3.new(0.85, 0.04, 0.04), VIOLET))
	end
	local t0 = os.clock()
	return function(now)
		local f = (now - t0) / CIRCLE_LIFE
		if f >= 1 or not tip.Parent then
			for _, p in ipairs(parts) do p.part:Destroy() end
			for _, p in ipairs(tri) do p:Destroy() end
			return false
		end
		local grow = math.min(1, f / 0.25) -- opens quickly
		local fade = f > 0.7 and (f - 0.7) / 0.3 or 0
		local pos = tip.Position
		-- the circle stands upright between the finger and the wall, a little in front of the tip
		local facing = CFrame.lookAt(pos, aimPos)
		local base = facing * CFrame.new(0, 0, -0.35) * CFrame.Angles(0, 0, now * 4)
		for _, p in ipairs(parts) do
			local r = p.r * grow
			p.part.CFrame = base * CFrame.Angles(0, 0, p.a) * CFrame.new(r, 0, 0) * CFrame.Angles(0, 0, math.rad(90))
			p.part.Transparency = fade
		end
		for k, p in ipairs(tri) do
			local a = (k - 1) / 3 * math.pi * 2 - now * 6
			local r = R2 * 0.5 * grow
			p.CFrame = base * CFrame.Angles(0, 0, a) * CFrame.new(0, r, 0)
			p.Size = Vector3.new(0.85 * grow, 0.04, 0.04)
			p.Transparency = fade
		end
		return true
	end
end

-- the beam: a hot core and a soft violet sheath from the tip to the wall, then a flash on the wall
local function beam(tip, aimPos)
	local from = tip.Position
	local len = (aimPos - from).Magnitude
	local cf = CFrame.lookAt(from, aimPos) * CFrame.new(0, 0, -len / 2)
	local core = newPart(Vector3.new(0.12, 0.12, len), CORE)
	local sheath = newPart(Vector3.new(0.4, 0.4, len), VIOLET, 0.45)
	core.CFrame, sheath.CFrame = cf, cf
	local flash = newPart(Vector3.new(1, 1, 1), CORE, 0, Enum.PartType.Ball)
	flash.CFrame = CFrame.new(aimPos)
	local light = Instance.new("PointLight")
	light.Color = VIOLET
	light.Range = 12
	light.Brightness = 2
	light.Shadows = false
	light.Parent = flash
	local t0 = os.clock()
	return function(now)
		local f = (now - t0) / BEAM_LIFE
		if f >= 1 then
			core:Destroy()
			sheath:Destroy()
			flash:Destroy()
			return false
		end
		local w = 1 - f
		core.Size = Vector3.new(0.12 * w + 0.02, 0.12 * w + 0.02, len)
		sheath.Size = Vector3.new(0.4 * w + 0.05, 0.4 * w + 0.05, len)
		sheath.Transparency = 0.45 + 0.55 * f
		flash.Size = Vector3.one * (1 + 3 * f)
		flash.Transparency = f
		light.Brightness = 2 * w
		return true
	end
end

-- ============================================================
-- Watching the units
-- ============================================================
local function onAttack(model)
	local tip = model:FindFirstChild("FingerTip", true)
	if not tip then return end
	local camera = workspace.CurrentCamera
	if camera and (tip.Position - camera.CFrame.Position).Magnitude > MAX_DISTANCE then return end
	task.delay(CIRCLE_AT, function()
		local aim = model:GetAttribute("AimPos")
		if aim and tip.Parent then
			table.insert(active, magicCircle(tip, aim))
		end
	end)
	task.delay(FIRE_AT, function()
		local aim = model:GetAttribute("AimPos")
		if aim and tip.Parent then
			table.insert(active, beam(tip, aim))
		end
	end)
end

local watched = {}
local function watch(model)
	if watched[model] then return end
	watched[model] = true
	model:GetAttributeChangedSignal("AttackCount"):Connect(function()
		if model:GetAttribute("AttackStyle") == "FingerBeam" then
			onAttack(model)
		end
	end)
end
for _, model in ipairs(CollectionService:GetTagged(TAG)) do
	watch(model)
end
CollectionService:GetInstanceAddedSignal(TAG):Connect(watch)
CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(model)
	watched[model] = nil
end)

RunService.RenderStepped:Connect(function()
	local now = os.clock()
	for i = #active, 1, -1 do
		if not active[i](now) then
			table.remove(active, i)
		end
	end
end)

return {}
