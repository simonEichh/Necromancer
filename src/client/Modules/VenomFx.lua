-- The Crypt Spider's venom (client only). UnitAnimator's Spider block calls VenomFx.fire at the moment it spits; every
-- client does that for every spider from the same attack timing, so nothing is sent per glob. The server lands the
-- damage after the same release time + flight (Units: releaseAt, projectileSpeed), so the HP bar drops on the splat.
--
-- A glob flies in a short arc to the real wall surface (a ray towards AimPos; only anchored parts count), dripping a
-- little on the way. On the stone it splatters: a flat blob with droplets round it, a few drips that run down the wall
-- and stretch, acid bubbles that swell and pop, a hiss of acid smoke; then it all fades.
-- Base form: sickly yellow-green venom; shadow form (model attribute Form = "Shadow"): violet. Far ones are not drawn.
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local RENDER_DISTANCE = 300
local ARC_HEIGHT = 1.2 -- studs the glob rises above the straight line at the middle of its flight
local SPLAT_TIME = 1.6 -- seconds the splatter stays before it fades
local DROP_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"

local PALETTES = {
	base = { venom = Color3.fromRGB(170, 220, 40), dark = Color3.fromRGB(90, 120, 20), smoke = Color3.fromRGB(150, 170, 110) },
	shadow = { venom = Color3.fromRGB(130, 70, 255), dark = Color3.fromRGB(50, 20, 110), smoke = Color3.fromRGB(80, 50, 130) },
}

local folder = Instance.new("Folder")
folder.Name = "VenomFX"
folder.Parent = Workspace

local flying = {}

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function newPart(name, size, color, material, shape)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	if shape then
		p.Shape = shape
	end
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
			return hit.Position, hit.Normal
		end
		table.insert(ignore, hit.Instance)
	end
	return nil
end

local function fadeOut(p, time)
	TweenService:Create(p, TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Transparency = 1 }):Play()
	Debris:AddItem(p, time + 0.05)
end

local function splat(at, normal, pal)
	-- the wall's plane: across (right) and up
	local right = normal:Cross(Vector3.yAxis)
	right = right.Magnitude > 0.1 and right.Unit or Vector3.xAxis
	local up = right:Cross(normal).Unit
	if up.Y < 0 then
		up = -up
	end
	local function disc(name, centre, size)
		-- a flat cylinder lying on the wall (its axis, X, along the normal)
		local p = newPart(name, Vector3.new(0.04, size, size), pal.venom, Enum.Material.Neon, Enum.PartType.Cylinder)
		p.CFrame = CFrame.lookAt(centre + normal * 0.05, centre + normal * 1.05) * CFrame.Angles(0, math.rad(90), 0)
		p.Transparency = 0.15
		return p
	end
	-- the blob slaps on (grows from small) and the droplets round it
	local blob = disc("VenomBlob", at, 0.3)
	TweenService:Create(blob, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(0.04, 1.3, 1.3) }):Play()
	local parts = { blob }
	for _ = 1, 6 do
		local a = math.random() * math.pi * 2
		local r = 0.7 + math.random() * 0.6
		table.insert(parts, disc("VenomDrop", at + (right * math.cos(a) + up * math.sin(a)) * r, 0.15 + math.random() * 0.2))
	end
	-- drips running down the wall, stretching as they go
	for _ = 1, 3 do
		local start = at + right * (math.random() - 0.5) * 0.9 - up * 0.3
		local drip = newPart("VenomDrip", Vector3.new(0.14, 0.2, 0.08), pal.venom, Enum.Material.Neon)
		drip.Transparency = 0.15
		local fall = 0.6 + math.random() * 0.8
		local cfA = CFrame.fromMatrix(start + normal * 0.05, right, up, right:Cross(up))
		local cfB = CFrame.fromMatrix(start - up * fall + normal * 0.05, right, up, right:Cross(up))
		drip.CFrame = cfA
		local time = 0.9 + math.random() * 0.6
		TweenService:Create(drip, TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			CFrame = cfB,
			Size = Vector3.new(0.1, 0.45, 0.06),
		}):Play()
		table.insert(parts, drip)
	end
	-- acid bubbles: swell and pop
	for k = 1, 5 do
		task.delay(0.1 + k * 0.18 + math.random() * 0.1, function()
			local pos = at + (right * (math.random() - 0.5) + up * (math.random() - 0.5)) * 0.9 + normal * 0.1
			local b = newPart("VenomBubble", Vector3.one * 0.06, pal.venom, Enum.Material.Neon, Enum.PartType.Ball)
			b.CFrame = CFrame.new(pos)
			b.Transparency = 0.3
			TweenService:Create(b, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Size = Vector3.one * 0.22,
				Transparency = 1,
			}):Play()
			Debris:AddItem(b, 0.3)
		end)
	end
	-- the hiss of acid smoke
	local src = newPart("VenomSmoke", Vector3.new(1, 1, 0.1), pal.venom)
	src.Transparency = 1
	src.CFrame = CFrame.lookAt(at + normal * 0.2, at + normal * 1.2)
	local smoke = Instance.new("ParticleEmitter")
	smoke.Texture = SMOKE_TEXTURE
	smoke.Color = ColorSequence.new(pal.smoke)
	smoke.LightInfluence = 0.5
	smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1.0) })
	smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1) })
	smoke.Lifetime = NumberRange.new(0.6, 1.0)
	smoke.Speed = NumberRange.new(0.5, 1.2)
	smoke.Acceleration = Vector3.new(0, 1.5, 0)
	smoke.EmissionDirection = Enum.NormalId.Front
	smoke.Rate = 10
	smoke.Parent = src
	task.delay(0.9, function()
		smoke.Enabled = false
	end)
	Debris:AddItem(src, 2)
	task.delay(SPLAT_TIME, function()
		for _, p in ipairs(parts) do
			if p.Parent then
				fadeOut(p, 0.5)
			end
		end
	end)
end

local VenomFx = {}

-- (model, from: the mouth at the spit, aim: the model's AimPos, speed: studs/s)
function VenomFx.fire(model, from, aim, speed)
	local camera = Workspace.CurrentCamera
	if camera and (from - camera.CFrame.Position).Magnitude > RENDER_DISTANCE then
		return
	end
	local dir = aim - from
	if dir.Magnitude < 0.5 then
		return
	end
	dir = dir.Unit
	local stop, normal = surfaceAlong(from, dir, (aim - from).Magnitude + 3)
	stop = stop or aim
	normal = normal or -dir
	local pal = model:GetAttribute("Form") == "Shadow" and PALETTES.shadow or PALETTES.base
	local glob = newPart("VenomGlob", Vector3.one * 0.42, pal.venom, Enum.Material.Neon, Enum.PartType.Ball)
	glob.Transparency = 0.1
	glob.CFrame = CFrame.new(from)
	-- a few drops falling off it in flight
	local drops = Instance.new("ParticleEmitter")
	drops.Texture = DROP_TEXTURE
	drops.Color = ColorSequence.new(pal.venom, pal.dark)
	drops.LightEmission = 0.6
	drops.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.12), NumberSequenceKeypoint.new(1, 0.04) })
	drops.Lifetime = NumberRange.new(0.3, 0.5)
	drops.Speed = NumberRange.new(0.5, 1.5)
	drops.SpreadAngle = Vector2.new(180, 180)
	drops.Acceleration = Vector3.new(0, -30, 0)
	drops.Rate = 30
	drops.Parent = glob
	local dist = (stop - from).Magnitude
	table.insert(flying, { glob = glob, from = from, stop = stop, normal = normal, time = dist / speed, t0 = os.clock(), pal = pal })
end

RunService.RenderStepped:Connect(function()
	local now = os.clock()
	for i = #flying, 1, -1 do
		local f = flying[i]
		local k = (now - f.t0) / f.time
		if k >= 1 then
			table.remove(flying, i)
			f.glob:Destroy()
			splat(f.stop, f.normal, f.pal)
		else
			-- an arc: the straight line plus a hump in the middle; it wobbles a little as it flies
			local pos = f.from:Lerp(f.stop, k) + Vector3.new(0, 4 * ARC_HEIGHT * k * (1 - k), 0)
			local wob = 1 + math.sin(now * 40) * 0.12
			f.glob.Size = Vector3.new(0.42 * wob, 0.42 / wob, 0.42)
			f.glob.CFrame = CFrame.new(pos)
		end
	end
end)

return VenomFx
