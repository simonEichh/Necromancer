-- Malak's special, the REQUISITION (Units.Malak.special, kind "Requisition", 40 s; he keeps attacking meanwhile).
-- Drawn from the synced server clock (SpecialAt) and the shared seed (SpecialSeed), so every player sees the same.
--   1. (0-2.2 s) He taps his hologram; a supply pod (Modules/DropPod, small) drops out of the sky from the Absolution
--      on a vapour trail and slams down beside the army, near the front (dust, sparks, a ring of cold-blue runes).
--   2. (2.5-5 s) Steam out of its vents, then the petals fold open.
--   3. (5.2-9.8 s) A drone dispenser rises out of it (a chrome launch column with a glowing muzzle) and kicks out six
--      drones one after another; each pops up out of the muzzle and swings over to its post in front of the wall.
--   4. (until SWARM_END, 25 s from the first launch) the drones fight: each weaves its own smooth loops round its post in
--      front of the wall (banking into its turns, never standing still) and fires a cold-blue bolt at the wall about once a
--      second (a flash and sparks where it hits). When a wall breaks the server moves SpecialAim on to the next one and
--      the drones glide after it. Cut short by a Fleet Strike or an ascension (server SpecialCut): the timeline jumps on
--      to the recall from that moment.
--   5. (31.8-40 s) The drones fly home one after another in arcs and drop into the muzzle (a flash each), the dispenser
--      sinks back, the petals close, a cold-blue tractor beam comes down from the Absolution and the pod lifts off into
--      the sky, faster and faster, gone in a flash.
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local DropPod = require(script.Parent.DropPod)
local Sfx = require(script.Parent.Sfx)

local FX_DISTANCE = 360 -- (players farther than this from both Malak and the pod do not draw it)
local POD_SCALE = 0.55
local DRONE_SCALE = 1.5
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local GLOW = Color3.fromRGB(165, 180, 255)
local GLOW_CORE = Color3.fromRGB(235, 240, 255)
local CHROME = Color3.fromRGB(28, 28, 36)
local CHROME_LIGHT = Color3.fromRGB(50, 50, 62)
local SILVER = Color3.fromRGB(176, 180, 196)
local UP = Vector3.yAxis

-- ── Timeline (s after SpecialAt) ─────────────────────────────
local DROP_FROM = 0.6 -- the pod appears high in the sky ...
local IMPACT_AT = 2.2 -- ... and lands
local OPEN_FROM, T_OPEN = 3.6, 1.4 -- the petals fold open
local RISE_FROM, T_RISE = 5.2, 1.2 -- the dispenser rises out of the open pod
local LAUNCH_FROM, LAUNCH_GAP = 6.8, 0.6 -- the drones are kicked out one after another
local DRONES = 6
local T_LAUNCH = 1.6 -- a drone's flight from the muzzle to its post
local SWARM_END = LAUNCH_FROM + 25 -- the drones fight for 25 s (from the first launch)
local RECALL_GAP, T_RECALL = 0.35, 2.2 -- the drones fly home one after another (the last lands at ~35.8)
local SINK_FROM, T_SINK = 36.0, 0.8 -- the dispenser sinks back
local PULSE_EVERY = 3 -- while it is up the dispenser pings and sends a shockwave over the ground (the buff)
local PULSE_TIME = 0.9
local PULSE_RADIUS = 20
local CLOSE_FROM, T_CLOSE = 36.8, 0.8 -- the petals close ...
local BEAM_FROM = 37.6 -- ... the tractor beam comes down ...
local LIFT_FROM, T_LIFT = 38.0, 1.4 -- ... and lifts the pod into the sky
local LIFT_HEIGHT = 220
local END_AT = 40

local BOLT_SPEED = 160 -- studs/s
local BOLT_VOLUME = 0.28 -- (every bolt has its sound, quiet: six drones fire about six a second)

local DROP_HEIGHT = 170
local LAND_BACK = 26 -- the pod lands this far in front of the wall (towards the army) ...
local LAND_SIDE = 7 -- ... and this far to one side of Malak's line

local function smooth(x)
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end
local function e(t, a, b)
	return smooth((t - a) / (b - a))
end
local function newPart(parent, size, cf, color, material, shape)
	local p = Instance.new("Part")
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.Neon
	if shape then
		p.Shape = shape
	end
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Parent = parent
	return p
end

local active = {}

-- ============================================================
-- One requisition
-- ============================================================
local function requisition(model)
	local at = model:GetAttribute("SpecialAt")
	local aim = model:GetAttribute("SpecialAim")
	local root = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
	local camera = Workspace.CurrentCamera
	if not (at and aim and root and camera) then
		return
	end
	local rng = Random.new(model:GetAttribute("SpecialSeed") or 1)

	-- where it lands: in front of the wall towards the army, a little to one side, on the floor (the aim is 7 above
	-- it). Measured from the wall, not from Malak (he can still be walking to his slot); he faces the wall.
	local floorY = aim.Y - 7
	local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	local dir = look.Magnitude > 0.1 and look.Unit or Vector3.new(0, 0, -1)
	local side = Vector3.new(-dir.Z, 0, dir.X) * (rng:NextNumber() < 0.5 and -1 or 1)
	local land = Vector3.new(aim.X, floorY, aim.Z) - dir * LAND_BACK + side * LAND_SIDE
	local camPos = camera.CFrame.Position
	if (camPos - land).Magnitude > FX_DISTANCE and (camPos - root.Position).Magnitude > FX_DISTANCE then
		return
	end
	local podBase = CFrame.lookAt(land, land - dir) -- (its front looks back at the army)
	-- it comes down from behind the army, out of the sky
	local skyFrom = land - dir * 40 + UP * DROP_HEIGHT

	local folder = Instance.new("Folder")
	folder.Name = "Requisition"
	folder.Parent = Workspace

	local pod = DropPod.build(folder, POD_SCALE)
	pod.setHidden(true)
	pod.place(CFrame.new(0, -5000, 0), 0, 0)
	local R, H = pod.radius, pod.height

	-- the vapour trail on the way down
	local trailHolder = newPart(folder, Vector3.one * 0.3, CFrame.new(0, -5000, 0), GLOW, Enum.Material.SmoothPlastic)
	trailHolder.Transparency = 1
	local trail = Instance.new("ParticleEmitter")
	trail.Texture = SMOKE
	trail.Color = ColorSequence.new(Color3.fromRGB(220, 226, 240), Color3.fromRGB(120, 126, 150))
	trail.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.4), NumberSequenceKeypoint.new(1, 4) })
	trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) })
	trail.Lifetime = NumberRange.new(1, 1.6)
	trail.Speed = NumberRange.new(0.5, 2)
	trail.SpreadAngle = Vector2.new(20, 20)
	trail.RotSpeed = NumberRange.new(-30, 30)
	trail.Rate = 0
	trail.LightInfluence = 0.4
	trail.Parent = trailHolder

	-- the impact: dust, sparks, a flash of light, the rune ring rolling out
	local ground = newPart(folder, Vector3.one * 0.3, CFrame.new(land + UP * 0.5), GLOW, Enum.Material.SmoothPlastic)
	ground.Transparency = 1
	local dust = Instance.new("ParticleEmitter")
	dust.Texture = SMOKE
	dust.Color = ColorSequence.new(Color3.fromRGB(150, 140, 135), Color3.fromRGB(90, 86, 92))
	dust.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 6) })
	dust.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) })
	dust.Lifetime = NumberRange.new(1.2, 2)
	dust.Speed = NumberRange.new(10, 18)
	dust.SpreadAngle = Vector2.new(180, 15)
	dust.Drag = 2.5
	dust.Rate = 0
	dust.EmissionDirection = Enum.NormalId.Top
	dust.Parent = ground
	local sparks = Instance.new("ParticleEmitter")
	sparks.Texture = SPARKLE
	sparks.Color = ColorSequence.new(GLOW_CORE, GLOW)
	sparks.LightEmission = 1
	sparks.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 0) })
	sparks.Lifetime = NumberRange.new(0.6, 1.2)
	sparks.Speed = NumberRange.new(14, 28)
	sparks.SpreadAngle = Vector2.new(80, 80)
	sparks.Acceleration = Vector3.new(0, -30, 0)
	sparks.Rate = 0
	sparks.EmissionDirection = Enum.NormalId.Top
	sparks.Parent = ground
	local flash = Instance.new("PointLight")
	flash.Color = GLOW
	flash.Range = 26
	flash.Brightness = 0
	flash.Shadows = false
	flash.Parent = ground
	local wave = {}
	for k = 0, 29 do
		local isRune = k % 5 == 0
		local p = newPart(folder, isRune and Vector3.new(0.8, 0.12, 0.8) or Vector3.new(0.7, 0.12, 0.3), CFrame.new(land), isRune and GLOW_CORE or GLOW)
		p.Transparency = 1
		table.insert(wave, { part = p, a = k / 30 * math.pi * 2, rune = isRune })
	end
	-- steam out of the vents after the landing
	local steam = {}
	for k = 0, DropPod.PETALS - 1 do
		local a = (k + 0.5) / DropPod.PETALS * math.pi * 2
		local out = Vector3.new(math.cos(a), 0, math.sin(a))
		local pos = land + out * (R + 0.4) + UP * (pod.base + 0.3)
		local h = newPart(folder, Vector3.one * 0.3, CFrame.lookAt(pos, pos + out + UP * 0.6), GLOW, Enum.Material.SmoothPlastic)
		h.Transparency = 1
		local em = Instance.new("ParticleEmitter")
		em.Texture = SMOKE
		em.Color = ColorSequence.new(Color3.fromRGB(230, 234, 245))
		em.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 3) })
		em.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
		em.Lifetime = NumberRange.new(0.8, 1.4)
		em.Speed = NumberRange.new(7, 11)
		em.SpreadAngle = Vector2.new(10, 10)
		em.Drag = 3
		em.EmissionDirection = Enum.NormalId.Front
		em.Rate = 0
		em.Parent = h
		table.insert(steam, em)
	end

	-- ── the dispenser: a chrome launch column that rises out of the pod floor, silver bands, a glowing muzzle ──
	local DISP_H = 4.2
	local disp = {}
	local function dispPart(size, offset, color, material, shape)
		local p = newPart(folder, size, CFrame.new(0, -5000, 0), color, material or Enum.Material.SmoothPlastic, shape)
		table.insert(disp, { part = p, offset = offset })
		return p
	end
	local turn = CFrame.Angles(0, 0, math.pi / 2) -- (a cylinder's axis up)
	dispPart(Vector3.new(DISP_H, 1.7, 1.7), CFrame.new(0, DISP_H / 2, 0) * turn, CHROME, nil, Enum.PartType.Cylinder)
	for _, y in ipairs({ 0.6, DISP_H * 0.55 }) do
		dispPart(Vector3.new(0.25, 1.95, 1.95), CFrame.new(0, y, 0) * turn, SILVER, Enum.Material.Metal, Enum.PartType.Cylinder)
	end
	for k = 0, 2 do
		local a = k / 3 * math.pi * 2
		dispPart(Vector3.new(0.2, DISP_H * 0.6, 0.12), CFrame.new(math.cos(a) * 0.86, DISP_H * 0.5, math.sin(a) * 0.86) * CFrame.Angles(0, -a, 0), GLOW, Enum.Material.Neon)
	end
	dispPart(Vector3.new(0.5, 2.2, 2.2), CFrame.new(0, DISP_H + 0.1, 0) * turn, CHROME_LIGHT, nil, Enum.PartType.Cylinder)
	local muzzle = dispPart(Vector3.new(0.12, 1.3, 1.3), CFrame.new(0, DISP_H + 0.38, 0) * turn, GLOW_CORE, Enum.Material.Neon, Enum.PartType.Cylinder)
	local muzzleLight = Instance.new("PointLight")
	muzzleLight.Color = GLOW
	muzzleLight.Range = 10
	muzzleLight.Brightness = 0
	muzzleLight.Shadows = false
	muzzleLight.Parent = muzzle
	local podFloor = land + UP * pod.base
	local function placeDispenser(h)
		-- h 0..1: sunk in the pod floor .. fully up
		local cf = CFrame.new(podFloor - UP * (DISP_H + 0.6) * (1 - h)) * podBase.Rotation
		local ps, cfs = {}, {}
		for _, d in ipairs(disp) do
			table.insert(ps, d.part)
			table.insert(cfs, cf * d.offset)
		end
		Workspace:BulkMoveTo(ps, cfs, Enum.BulkMoveMode.FireCFrameChanged)
		for _, d in ipairs(disp) do
			d.part.LocalTransparencyModifier = h > 0.02 and 0 or 1
		end
	end
	placeDispenser(0)
	local muzzleTop = podFloor + UP * (DISP_H + 0.5)
	-- the buff pulse: a ring of cold-blue segments rolling out over the ground from the pod
	local pulseRing = {}
	for k = 0, 35 do
		local p = newPart(folder, Vector3.new(1, 0.1, 0.35), CFrame.new(0, -5000, 0), k % 6 == 0 and GLOW_CORE or GLOW)
		p.Transparency = 1
		table.insert(pulseRing, { part = p, a = k / 36 * math.pi * 2 })
	end
	-- the tractor beam: a bright core and a wide faint sheath from the pod up into the sky
	local beamCore = newPart(folder, Vector3.new(LIFT_HEIGHT + 60, 1.6, 1.6), CFrame.new(0, -5000, 0), GLOW_CORE, Enum.Material.Neon, Enum.PartType.Cylinder)
	local beamSheath = newPart(folder, Vector3.new(LIFT_HEIGHT + 60, 5, 5), CFrame.new(0, -5000, 0), GLOW, Enum.Material.Neon, Enum.PartType.Cylinder)
	beamCore.Transparency, beamSheath.Transparency = 1, 1
	local gonePoint = newPart(folder, Vector3.one * 0.3, CFrame.new(land + UP * (LIFT_HEIGHT + 20)), GLOW, Enum.Material.SmoothPlastic)
	gonePoint.Transparency = 1
	local goneFlash = Instance.new("PointLight")
	goneFlash.Color = GLOW
	goneFlash.Range = 60
	goneFlash.Brightness = 0
	goneFlash.Shadows = false
	goneFlash.Parent = gonePoint
	local pulseTimes = {}
	for pt = RISE_FROM + T_RISE + 0.4, SINK_FROM - 0.5, PULSE_EVERY do
		table.insert(pulseTimes, pt)
	end

	-- ── the drones: a chrome body, a glowing core, three arms with silver tips (turning), a hover glow under it ──
	local wallFloor = Vector3.new(aim.X, floorY, aim.Z)
	local drones = {}
	for i = 1, DRONES do
		local dr = { parts = {}, launchAt = LAUNCH_FROM + (i - 1) * LAUNCH_GAP, phase = rng:NextNumber() * math.pi * 2 }
		local function add(size, offset, color, material, shape, spins)
			local p = newPart(folder, size * DRONE_SCALE, CFrame.new(0, -5000, 0), color, material or Enum.Material.SmoothPlastic, shape)
			offset = offset - offset.Position + offset.Position * DRONE_SCALE
			table.insert(dr.parts, { part = p, offset = offset, spins = spins })
			return p
		end
		add(Vector3.new(0.9, 0.9, 0.9), CFrame.new(), CHROME, nil, Enum.PartType.Ball)
		add(Vector3.new(0.5, 0.5, 0.5), CFrame.new(0, 0, -0.28), GLOW_CORE, Enum.Material.Neon, Enum.PartType.Ball)
		for k = 0, 2 do
			local a = k / 3 * math.pi * 2
			add(Vector3.new(0.9, 0.1, 0.18), CFrame.Angles(0, a, 0) * CFrame.new(0.75, 0, 0), CHROME_LIGHT, nil, nil, true)
			add(Vector3.new(0.18, 0.14, 0.24), CFrame.Angles(0, a, 0) * CFrame.new(1.2, 0, 0), SILVER, Enum.Material.Metal, nil, true)
		end
		local glow = add(Vector3.new(0.06, 1.5, 1.5), CFrame.new(0, -0.45, 0) * turn, GLOW, Enum.Material.Neon, Enum.PartType.Cylinder)
		glow.Transparency = 0.55
		-- its post in front of the wall (relative to the wall, which moves on when it breaks): spread across, at three
		-- heights; the loops it weaves round it; its own firing clock
		-- (high up and well back from the wall, so their bolts fly a long way down to it)
		dr.postOff = -dir * (22 + (i % 2) * 6) + side * ((i - (DRONES + 1) / 2) * 4) + UP * (15 + (i % 3) * 3)
		dr.post = wallFloor + dr.postOff
		dr.loop = {
			ax = 2.2 + rng:NextNumber() * 1.6, wx = 0.55 + rng:NextNumber() * 0.35, px = rng:NextNumber() * math.pi * 2,
			ay = 1.0 + rng:NextNumber() * 0.9, wy = 0.8 + rng:NextNumber() * 0.5, py = rng:NextNumber() * math.pi * 2,
			az = 1.6 + rng:NextNumber() * 1.2, wz = 0.4 + rng:NextNumber() * 0.3, pz = rng:NextNumber() * math.pi * 2,
		}
		dr.firePeriod = 0.95 + rng:NextNumber() * 0.3
		dr.pitch = 1.05 + (i - 1) * 0.07 -- (each drone its own voice)
		dr.fireOffset = rng:NextNumber() * dr.firePeriod
		dr.shots = 0
		drones[i] = dr
	end
	local function placeDrone(dr, pos, faceTo, spin, hidden, roll)
		local cf = CFrame.lookAt(pos, Vector3.new(faceTo.X, pos.Y, faceTo.Z)) * CFrame.Angles(0, 0, roll or 0)
		local ps, cfs = {}, {}
		for _, d in ipairs(dr.parts) do
			table.insert(ps, d.part)
			table.insert(cfs, d.spins and (cf * CFrame.Angles(0, spin, 0) * d.offset) or (cf * d.offset))
		end
		Workspace:BulkMoveTo(ps, cfs, Enum.BulkMoveMode.FireCFrameChanged)
		for _, d in ipairs(dr.parts) do
			d.part.LocalTransparencyModifier = hidden
		end
	end
	for _, dr in ipairs(drones) do
		placeDrone(dr, muzzleTop, wallFloor, 0, 1)
	end

	-- ── the bolts and their hits ──
	local bolts = {}
	local hitHolder = newPart(folder, Vector3.one * 0.3, CFrame.new(0, -5000, 0), GLOW, Enum.Material.SmoothPlastic)
	hitHolder.Transparency = 1
	local hitSparks = Instance.new("ParticleEmitter")
	hitSparks.Texture = SPARKLE
	hitSparks.Color = ColorSequence.new(GLOW_CORE, GLOW)
	hitSparks.LightEmission = 1
	hitSparks.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0) })
	hitSparks.Lifetime = NumberRange.new(0.25, 0.5)
	hitSparks.Speed = NumberRange.new(8, 16)
	hitSparks.SpreadAngle = Vector2.new(70, 70)
	hitSparks.Acceleration = Vector3.new(0, -20, 0)
	hitSparks.Rate = 0
	hitSparks.Parent = hitHolder
	local function fire(dr, from, to)
		local length = (to - from).Magnitude
		local core = newPart(folder, Vector3.new(0.16, 0.16, 2.2), CFrame.lookAt(from, to), GLOW_CORE)
		local halo = newPart(folder, Vector3.new(0.4, 0.4, 2.6), CFrame.lookAt(from, to), GLOW)
		halo.Transparency = 0.6
		table.insert(bolts, { core = core, halo = halo, from = from, to = to, start = nil, length = length })
		dr.shots += 1
		Sfx.play("drone_bolt", dr.parts[1].part, BOLT_VOLUME, dr.pitch + (rng:NextNumber() - 0.5) * 0.06)
	end
	local function hit(at)
		hitHolder.CFrame = CFrame.new(at)
		hitSparks:Emit(6)
		local flash = newPart(folder, Vector3.one * 0.6, CFrame.new(at), GLOW_CORE, Enum.Material.Neon, Enum.PartType.Ball)
		table.insert(bolts, { flash = flash, born = nil })
	end

	-- the sounds, from where they happen
	local cues = {
		{ name = "holo_tap", at = 0, parent = root, volume = 0.8 },
		{ name = "drone_transform", at = DROP_FROM - 0.2, parent = root, volume = 2, pitch = 0.8 }, -- (the clamps letting go, far above)
		{ name = "shell_impact", at = IMPACT_AT, parent = ground, volume = 0.7, pitch = 0.8 },
		{ name = "reactor_lock", at = OPEN_FROM - 0.25, parent = ground, volume = 0.6, pitch = 1.1 },
		{ name = "bow_open", at = OPEN_FROM, parent = ground, volume = 0.6, pitch = 1.4 },
		{ name = "reactor_windup", at = RISE_FROM, parent = ground, volume = 0.35, pitch = 1.5, cut = T_RISE - 0.15 }, -- (it ran on after the column was up)
	}
	table.insert(cues, { name = "sublift_scanner", at = BEAM_FROM, parent = ground, volume = 0.6, pitch = 1.2, cut = 2.0 })
	table.insert(cues, { name = "warp_out", at = LIFT_FROM + T_LIFT - 0.3, parent = ground, volume = 0.7, pitch = 1.3 })
	for i = 1, DRONES do
		table.insert(cues, { name = "rune_click", at = SWARM_END + (DRONES - i) * RECALL_GAP + T_RECALL, parent = muzzle, volume = 0.5, pitch = 1.4 + i * 0.05 })
	end
	for _, pt in ipairs(pulseTimes) do
		table.insert(cues, { name = "rune_confirm", at = pt, parent = muzzle, volume = 0.45, pitch = 1.7, cut = 0.5 }) -- (the ping)
	end
	for i = 1, DRONES do
		-- (cut short: the missile sound's long tail dragged on)
		table.insert(cues, { name = "missile_launch", at = LAUNCH_FROM + (i - 1) * LAUNCH_GAP, parent = muzzle, volume = 0.3, pitch = 1.5 + i * 0.04, cut = 0.45 })
	end

	local impacted = false
	local lastT
	local wallNow = wallFloor
	table.insert(active, function(now)
		local t = now - at
		-- cut short (a Fleet Strike, an ascension: server SpecialCut): the timeline jumps on to the recall from that moment
		local cutAt = model.Parent and model:GetAttribute("SpecialCut")
		if type(cutAt) == "number" and cutAt > at and cutAt - at < SWARM_END and t >= cutAt - at then
			t += SWARM_END - (cutAt - at)
		end
		local dt = lastT and math.clamp(t - lastT, 0, 0.1) or 0
		lastT = t
		-- the wall being fought (the server moves the aim on when a wall breaks)
		local aimNow = model.Parent and model:GetAttribute("SpecialAim")
		if typeof(aimNow) == "Vector3" then
			wallNow = Vector3.new(aimNow.X, aimNow.Y - 7, aimNow.Z)
		end
		if t >= END_AT or not folder.Parent then
			folder:Destroy()
			return false
		end
		for _, c in ipairs(cues) do
			if not c.fired and t >= c.at then
				c.fired = true
				if t - c.at < 0.5 and c.parent and c.parent.Parent then
					local sound = Sfx.play(c.name, c.parent, c.volume, c.pitch)
					if sound and c.cut then
						-- a quick fade, then gone
						task.delay(c.cut, function()
							if sound.Parent then
								TweenService:Create(sound, TweenInfo.new(0.15), { Volume = 0 }):Play()
								task.delay(0.16, function()
									if sound.Parent then
										sound:Destroy()
									end
								end)
							end
						end)
					end
				end
			end
		end

		-- ── 1. the drop ──
		if t < DROP_FROM then
			return true
		end
		if t < IMPACT_AT then
			local f = (t - DROP_FROM) / (IMPACT_AT - DROP_FROM)
			local pos = skyFrom:Lerp(land, f * f) -- (faster and faster)
			local cf = CFrame.new(pos) * podBase.Rotation * CFrame.Angles(0, t * 1.2, 0)
				* CFrame.Angles(math.sin(t * 2.3) * 0.05, 0, math.cos(t * 1.9) * 0.05)
			pod.setHidden(false)
			pod.place(cf, 0, 1)
			for _, port in ipairs(pod.ports) do
				port.Transparency = 0
			end
			trailHolder.CFrame = cf * CFrame.new(0, H * 0.5, 0)
			trail.Rate = 45
			return true
		end
		if not impacted then
			impacted = true
			trail.Rate = 0
			pod.setHidden(false)
			dust:Emit(40)
			sparks:Emit(35)
		end

		-- ── 2. the landing, the steam, the petals ──
		local r = t - IMPACT_AT
		flash.Brightness = 6 * math.max(0, 1 - r / 0.5)
		for _, w in ipairs(wave) do
			local radius = R + 16 * (1 - (1 - math.clamp(r / 1.2, 0, 1)) ^ 3)
			w.part.CFrame = CFrame.new(land + UP * 0.15) * CFrame.Angles(0, w.a + r * 0.3, 0) * CFrame.new(0, 0, -radius)
				* (w.rune and CFrame.Angles(0, math.rad(45), 0) or CFrame.identity)
			w.part.Transparency = r < 1.2 and math.clamp(0.1 + r / 1.2 * 0.9, 0, 1) or 1
		end
		local vent = e(t, IMPACT_AT + 0.3, IMPACT_AT + 0.6) * (1 - e(t, OPEN_FROM + 0.6, OPEN_FROM + 1.4))
		for _, em in ipairs(steam) do
			em.Rate = 25 * vent
		end
		local o = math.clamp((t - OPEN_FROM) / T_OPEN, 0, 1)
		local c = math.clamp((t - CLOSE_FROM) / T_CLOSE, 0, 1)
		local open = 0
		if o > 0 then
			open = (1 - (1 - o) ^ 3) + math.sin(o * math.pi) * 0.04
		end
		open *= 1 - smooth(c)
		local lift = math.clamp((t - LIFT_FROM) / T_LIFT, 0, 1)
		local liftH = LIFT_HEIGHT * lift ^ 2.4 -- (slow off the ground, then away)
		local shudder = (t >= BEAM_FROM and lift < 0.15) and CFrame.new((math.random() - 0.5) * 0.12, 0, (math.random() - 0.5) * 0.12) or CFrame.identity
		pod.place((podBase + UP * liftH) * shudder * CFrame.Angles(0, lift * lift * 4, 0), open, 1 - 0.5 * o)
		pod.light.Brightness = 2.5 * smooth(o * 2) * (1 - 0.6 * o) * (1 - c)
		pod.inner.Transparency = 0.2 + 0.8 * o
		for _, port in ipairs(pod.ports) do
			port.Transparency = t >= BEAM_FROM and 0 or math.clamp(r / 1.5, 0, 1)
		end
		if lift > 0 then
			trailHolder.CFrame = CFrame.new(land + UP * liftH)
			trail.Rate = lift < 0.95 and 40 or 0
		end
		if lift >= 1 then
			pod.setHidden(true)
		end
		-- ── 5b. the tractor beam ──
		local beamOn = e(t, BEAM_FROM, BEAM_FROM + 0.35) * (1 - e(t, LIFT_FROM + T_LIFT - 0.2, LIFT_FROM + T_LIFT + 0.4))
		if beamOn > 0 then
			local top = land + UP * (LIFT_HEIGHT + 60)
			local mid = (land + top) / 2
			local beamCF = CFrame.new(mid) * CFrame.Angles(0, 0, math.pi / 2)
			local wob = 1 + math.sin(t * 22) * 0.06
			beamCore.Size = Vector3.new(LIFT_HEIGHT + 60, 1.6 * wob, 1.6 * wob)
			beamCore.CFrame = beamCF
			beamSheath.CFrame = beamCF
			beamCore.Transparency = 1 - beamOn * 0.75
			beamSheath.Transparency = 1 - beamOn * 0.25
		else
			beamCore.Transparency, beamSheath.Transparency = 1, 1
		end
		goneFlash.Brightness = 8 * math.max(0, 1 - math.abs(t - (LIFT_FROM + T_LIFT)) / 0.35)
		-- ── 3. the dispenser, the launches ──
		local rise = e(t, RISE_FROM, RISE_FROM + T_RISE) * (1 - e(t, SINK_FROM, SINK_FROM + T_SINK))
		placeDispenser(rise)
		local flashK = 0
		for i, dr in ipairs(drones) do
			local f = (t - dr.launchAt) / T_LAUNCH
			if t >= dr.launchAt and t < dr.launchAt + 0.25 then
				flashK = math.max(flashK, 1 - (t - dr.launchAt) / 0.25) -- (the muzzle flashes at each launch)
			end
			if f <= 0 then
				placeDrone(dr, muzzleTop, wallFloor, 0, 1)
			else
				-- the post glides after the wall when it moves on
				local target = wallNow + dr.postOff
				dr.post = dr.post:Lerp(target, math.min(1, dt * 1.1))
				-- its loops round the post (eased in after the launch flight, so the motion runs on without a jolt)
				local tau = t - (dr.launchAt + T_LAUNCH)
				local L = dr.loop
				local ease = smooth(tau / 1.5)
				local loopOff = (side * (L.ax * math.sin(L.wx * tau + L.px) - L.ax * math.sin(L.px))
					+ UP * (L.ay * math.sin(L.wy * tau + L.py) - L.ay * math.sin(L.py))
					+ dir * (L.az * math.sin(L.wz * tau + L.pz) - L.az * math.sin(L.pz))) * ease
				local pos
				if f < 1 then
					-- popped up out of the muzzle, then a swinging arc over to its post
					local k = smooth(f)
					local pop = muzzleTop + UP * 7 + side * ((i - (DRONES + 1) / 2) * 1.2)
					pos = muzzleTop:Lerp(pop, k):Lerp(pop:Lerp(dr.post, k), k)
				else
					pos = dr.post + loopOff
				end
				-- banking into its turns: roll with its sideways speed
				local lastPos = dr.lastPos or pos
				local vel = dt > 0 and (pos - lastPos) / dt or Vector3.zero
				dr.lastPos = pos
				dr.roll = (dr.roll or 0) + (math.clamp(-vel:Dot(side) * 0.05, -0.5, 0.5) - (dr.roll or 0)) * math.min(1, dt * 6)
				local spin = t * 14 + dr.phase
				-- ── 5. home: an arc back into the muzzle, the last launched first ──
				local recallAt = SWARM_END + (DRONES - i) * RECALL_GAP
				local hidden = 0
				local faceTo = pos + dir * 10
				if t >= recallAt then
					dr.recallFrom = dr.recallFrom or pos
					local k = math.clamp((t - recallAt) / T_RECALL, 0, 1)
					local ek = k * k * (3 - 2 * k)
					local top = dr.recallFrom:Lerp(muzzleTop, 0.5) + UP * 9
					pos = dr.recallFrom:Lerp(top, ek):Lerp(top:Lerp(muzzleTop + UP * 0.4, ek), ek)
					faceTo = muzzleTop
					if k >= 1 then
						hidden = 1
						if not dr.home then
							dr.home = true
							flashK = 1
						end
					end
				end
				placeDrone(dr, pos, faceTo, spin, hidden, dr.roll)
				-- firing: about once a second on its own clock, while the swarm runs
				if f >= 1 and t < SWARM_END and not model:GetAttribute("SpecialHold") then
					local shot = math.floor((tau + dr.fireOffset) / dr.firePeriod)
					if shot > (dr.lastShot or 0) then
						dr.lastShot = shot
						local d = (wallNow - pos):Dot(dir)
						local aimAt = pos + dir * math.max(1, d - 0.5)
						aimAt = Vector3.new(aimAt.X, math.clamp(aimAt.Y, floorY + 2, floorY + 15), aimAt.Z)
							+ side * (rng:NextNumber() - 0.5) * 1.5
						fire(dr, pos + dir * 0.8, aimAt)
					end
				end
			end
		end
		-- the bolts fly, then flash where they hit
		for k = #bolts, 1, -1 do
			local b = bolts[k]
			if b.flash then
				b.born = b.born or t
				local a = (t - b.born) / 0.18
				if a >= 1 then
					b.flash:Destroy()
					table.remove(bolts, k)
				else
					b.flash.Size = Vector3.one * (0.6 + a * 1.6)
					b.flash.Transparency = a
				end
			else
				b.start = b.start or t
				local travelled = (t - b.start) * BOLT_SPEED
				if travelled >= b.length then
					b.core:Destroy()
					b.halo:Destroy()
					table.remove(bolts, k)
					hit(b.to)
				else
					local p = b.from:Lerp(b.to, travelled / b.length)
					local cf = CFrame.lookAt(p, b.to)
					b.core.CFrame = cf
					b.halo.CFrame = cf
				end
			end
		end
		-- the buff pulse
		local pulseK
		for _, pt in ipairs(pulseTimes) do
			if t >= pt and t < pt + PULSE_TIME then
				pulseK = (t - pt) / PULSE_TIME
			end
		end
		for _, seg in ipairs(pulseRing) do
			if pulseK then
				local radius = 1.5 + PULSE_RADIUS * (1 - (1 - pulseK) ^ 2)
				local len = 2 * math.pi * radius / #pulseRing * 0.7
				seg.part.Size = Vector3.new(len, 0.1, 0.35 + 0.3 * (1 - pulseK))
				seg.part.CFrame = CFrame.new(land + UP * 0.2) * CFrame.Angles(0, seg.a, 0) * CFrame.new(0, 0, -radius) -- (its X runs along the ring)
				seg.part.Transparency = 0.15 + 0.85 * pulseK
			elseif seg.part.Transparency < 1 then
				seg.part.Transparency = 1
			end
		end
		if pulseK and pulseK < 0.3 then
			flashK = math.max(flashK, 1 - pulseK / 0.3)
		end
		muzzleLight.Brightness = rise * (1.2 + 5 * flashK)
		muzzle.Transparency = 0.4 - 0.4 * flashK

		return true
	end)
end

-- ============================================================
-- Watching the Malaks
-- ============================================================
local watched = {}
local function watch(model)
	if watched[model] or model:GetAttribute("AttackStyle") ~= "OrbitalTag" then
		return
	end
	watched[model] = model:GetAttributeChangedSignal("SpecialAt"):Connect(function()
		if model:GetAttribute("SpecialKind") == "Requisition" then
			requisition(model)
		end
	end)
end
for _, m in ipairs(CollectionService:GetTagged("ProceduralUnit")) do
	watch(m)
end
CollectionService:GetInstanceAddedSignal("ProceduralUnit"):Connect(watch)
CollectionService:GetInstanceRemovedSignal("ProceduralUnit"):Connect(function(m)
	if watched[m] then
		watched[m]:Disconnect()
		watched[m] = nil
	end
end)

RunService.RenderStepped:Connect(function()
	local now = Workspace:GetServerTimeNow()
	for i = #active, 1, -1 do
		local ok, keep = pcall(active[i], now)
		if not ok then
			warn("RequisitionFx: " .. tostring(keep))
			table.remove(active, i)
		elseif not keep then
			table.remove(active, i)
		end
	end
end)

return {}
