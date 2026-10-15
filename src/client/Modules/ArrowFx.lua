-- Hollow Archer arrows (client only). UnitAnimator's Bow block calls ArrowFx.fire at the moment of release; every client
-- does that for every archer from the same attack timing, so nothing is sent per arrow. The server lands the damage
-- after the same release time + flight (Units: releaseAt, projectileSpeed), so the wall's HP bar drops when the arrow hits.
--
-- An arrow flies straight from the bow to the real wall surface (a ray towards AimPos; only anchored parts count) at
-- the unit's projectileSpeed:
--   * a burst ring at the bow on release, then a shockwave ring every RING_EVERY studs along the flight (a thin neon disc
--     across the path that bursts outward and fades), a short bright trail behind it;
--   * on arrival it sticks in the stone (the head buried), quivers on a damped wobble, throws chips, dust and a
--     ring, stays a moment and fades.
-- Base form: a bone arrow, pale rings; shadow form (model attribute Form = "Shadow"): an obsidian arrow with a violet
-- head, violet rings and trail. Arrows far from the camera are not drawn.
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local RENDER_DISTANCE = 300
local RING_EVERY = 3.5 -- studs between shockwave rings
local MAX_RINGS = 160 -- rings alive at once (many archers)
local STUCK_TIME = 1.4 -- seconds an arrow stays in the wall before it fades
local CHIP_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"
local DUST_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"

local PALETTES = {
	base = {
		shaft = Color3.fromRGB(214, 204, 176), head = Color3.fromRGB(200, 190, 160), headMat = Enum.Material.SmoothPlastic,
		fletch = Color3.fromRGB(24, 22, 24), ring = Color3.fromRGB(235, 245, 230), trail = Color3.fromRGB(235, 240, 225),
	},
	shadow = {
		shaft = Color3.fromRGB(30, 26, 40), head = Color3.fromRGB(120, 60, 255), headMat = Enum.Material.Neon,
		fletch = Color3.fromRGB(26, 14, 44), ring = Color3.fromRGB(140, 80, 255), trail = Color3.fromRGB(150, 95, 255),
	},
}

local folder = Instance.new("Folder")
folder.Name = "ArrowFX"
folder.Parent = Workspace

local rings = 0
local flying = {} -- arrows in flight: { parts, start, dir, dist, speed, t0, nextRing, pal }

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function newPart(name, size, color, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Parent = folder
	return p
end

-- the first anchored, visible part along the ray (the wall's real surface; units in the way are unanchored)
local function surfaceAlong(from, dir, maxDist)
	local ignore = { folder }
	for _ = 1, 6 do
		rayParams.FilterDescendantsInstances = ignore
		local hit = Workspace:Raycast(from, dir * maxDist, rayParams)
		if not hit then
			return nil
		end
		if hit.Instance.Anchored and hit.Instance.Transparency < 1 then
			return hit.Position
		end
		table.insert(ignore, hit.Instance)
	end
	return nil
end

-- a thin neon disc across the flight path that bursts outward and fades
local function ring(pos, dir, pal, startSize, endSize, time)
	if rings >= MAX_RINGS then
		return
	end
	rings += 1
	local p = newPart("ArrowRing", Vector3.new(0.05, startSize, startSize), pal.ring, Enum.Material.Neon)
	p.Shape = Enum.PartType.Cylinder
	p.Transparency = 0.25
	p.CFrame = CFrame.lookAt(pos, pos + dir) * CFrame.Angles(0, math.rad(90), 0) -- (a cylinder's axis is its X)
	TweenService:Create(p, TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.02, endSize, endSize),
		Transparency = 1,
	}):Play()
	task.delay(time, function()
		rings -= 1
		p:Destroy()
	end)
end

-- the arrow: shaft, head and fletching, placed so that `tip` is the point of the head
local function makeArrow(pal)
	local shaft = newPart("ArrowShaft", Vector3.new(0.07, 0.07, 1.7), pal.shaft)
	local head = newPart("ArrowHead", Vector3.new(0.16, 0.05, 0.3), pal.head, pal.headMat)
	local fletch = newPart("ArrowFletch", Vector3.new(0.02, 0.22, 0.42), pal.fletch)
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, 0, 0.8)
	a0.Parent = shaft
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, 0, -0.8)
	a1.Parent = shaft
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Color = ColorSequence.new(pal.trail)
	trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1) })
	trail.LightEmission = 1
	trail.LightInfluence = 0
	trail.Lifetime = 0.1
	trail.FaceCamera = true
	trail.WidthScale = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) })
	trail.Parent = shaft
	return { shaft = shaft, head = head, fletch = fletch, trail = trail }
end

local function placeArrow(arrow, tip, dir, roll)
	local cf = CFrame.lookAt(tip, tip + dir) * CFrame.Angles(0, 0, roll or 0)
	arrow.head.CFrame = cf * CFrame.new(0, 0, 0.15)
	arrow.shaft.CFrame = cf * CFrame.new(0, 0, 0.3 + 0.85)
	arrow.fletch.CFrame = cf * CFrame.new(0, 0, 0.3 + 1.7 - 0.25)
end

local function impact(arrow, tip, dir, pal)
	arrow.trail.Enabled = false
	-- buried a little: the head and a bit of the shaft are in the stone
	local stuck = tip + dir * 0.3
	placeArrow(arrow, stuck, dir)
	-- the quiver: a damped wobble about the buried point
	local t0 = os.clock()
	local axis = dir:Cross(Vector3.yAxis)
	axis = axis.Magnitude > 0.1 and axis.Unit or Vector3.xAxis
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - t0
		if t > 0.5 or not arrow.shaft.Parent then
			conn:Disconnect()
			if arrow.shaft.Parent then
				placeArrow(arrow, stuck, dir)
			end
			return
		end
		local wob = math.sin(t * 55) * math.exp(-t * 9) * 0.12
		local d = (CFrame.fromAxisAngle(axis, wob) * CFrame.fromAxisAngle(Vector3.yAxis, wob * 0.6)):VectorToWorldSpace(dir)
		placeArrow(arrow, stuck, d)
	end)
	-- a flash ring on the stone, chips and dust thrown back towards the archer
	ring(tip - dir * 0.1, dir, pal, 0.4, 2.6, 0.25)
	local src = newPart("ArrowChips", Vector3.one * 0.2, Color3.new())
	src.Transparency = 1
	src.CFrame = CFrame.lookAt(tip - dir * 0.2, tip - dir * 1.2)
	local chips = Instance.new("ParticleEmitter")
	chips.Texture = CHIP_TEXTURE
	chips.Color = ColorSequence.new(Color3.fromRGB(150, 142, 132), Color3.fromRGB(96, 90, 84))
	chips.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.22), NumberSequenceKeypoint.new(1, 0.1) })
	chips.Lifetime = NumberRange.new(0.3, 0.55)
	chips.Speed = NumberRange.new(6, 12)
	chips.SpreadAngle = Vector2.new(45, 45)
	chips.Acceleration = Vector3.new(0, -50, 0)
	chips.EmissionDirection = Enum.NormalId.Front
	chips.LightInfluence = 1
	chips.Rotation = NumberRange.new(0, 360)
	chips.Rate = 0
	chips.Parent = src
	local dust = Instance.new("ParticleEmitter")
	dust.Texture = DUST_TEXTURE
	dust.Color = ColorSequence.new(Color3.fromRGB(160, 152, 140))
	dust.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1.6) })
	dust.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) })
	dust.Lifetime = NumberRange.new(0.4, 0.7)
	dust.Speed = NumberRange.new(1.5, 3.5)
	dust.SpreadAngle = Vector2.new(60, 60)
	dust.EmissionDirection = Enum.NormalId.Front
	dust.LightInfluence = 1
	dust.Rate = 0
	dust.Parent = src
	chips:Emit(8)
	dust:Emit(2)
	Debris:AddItem(src, 1)
	-- it stays a moment, then fades
	task.delay(STUCK_TIME, function()
		for _, key in ipairs({ "shaft", "head", "fletch" }) do
			local p = arrow[key]
			if p.Parent then
				TweenService:Create(p, TweenInfo.new(0.5), { Transparency = 1 }):Play()
				Debris:AddItem(p, 0.55)
			end
		end
	end)
end

local ArrowFx = {}

-- (model, from: the nock point at release, aim: the model's AimPos, speed: studs/s)
function ArrowFx.fire(model, from, aim, speed)
	local camera = Workspace.CurrentCamera
	if camera and (from - camera.CFrame.Position).Magnitude > RENDER_DISTANCE then
		return
	end
	local dir = aim - from
	if dir.Magnitude < 0.5 then
		return
	end
	dir = dir.Unit
	-- fly to the real stone in front of AimPos (stones stick out past the wall's face plane), or AimPos itself
	local maxDist = (aim - from).Magnitude + 3
	local stop = surfaceAlong(from, dir, maxDist) or aim
	local dist = (stop - from).Magnitude
	local pal = model:GetAttribute("Form") == "Shadow" and PALETTES.shadow or PALETTES.base
	local arrow = makeArrow(pal)
	placeArrow(arrow, from + dir * 2.0, dir)
	ring(from + dir * 1.2, dir, pal, 0.3, 3.2, 0.3) -- the release burst
	table.insert(flying, { arrow = arrow, from = from, dir = dir, dist = dist, speed = speed, t0 = os.clock(), nextRing = RING_EVERY, pal = pal })
end

RunService.RenderStepped:Connect(function()
	local now = os.clock()
	for i = #flying, 1, -1 do
		local f = flying[i]
		local travelled = (now - f.t0) * f.speed + 2.0 -- (the tip starts 2 studs ahead of the nock)
		if travelled >= f.dist then
			table.remove(flying, i)
			impact(f.arrow, f.from + f.dir * f.dist, f.dir, f.pal)
		else
			placeArrow(f.arrow, f.from + f.dir * travelled, f.dir)
			while travelled >= f.nextRing do
				ring(f.from + f.dir * (f.nextRing - 0.6), f.dir, f.pal, 0.35, 2.0, 0.22)
				f.nextRing += RING_EVERY
			end
		end
	end
end)

return ArrowFx
