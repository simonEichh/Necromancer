-- "The Envoy Arrives": the pull cinematic of the Sovereign units (Malak; docs/envoy.md, "Pull cinematic"). GraveRolling
-- always plays it when a Sovereign is the best pull.
--
--   local started = SovereignArrival.play(results, opts)
--     results: list of { unitType, rarity, pity, oneIn } from the server's RollResult
--     opts:    graveType  the grave that was opened (needs a model in ReplicatedStorage.GraveModels)
--              onDone     function(), called when the cinematic ends (also when it is skipped)
--              speed      playback speed (default 1; for testing)
--     returns false (and does nothing) when it cannot play: no grave model, no ship model, no character, or a cinematic runs.
--
-- What you see (about 35 s, built slow on purpose):
--   1. Bait: the grave rises and shakes like a hand-opened one ... then it freezes. Silence.
--   2. Lock-on: a thin red targeting laser comes down out of the sky onto the grave, a red reticle closes round it and
--      locks (his red: only ever for targeting).
--   3. The sky tears over the plot (the Fleet Strike's tear: rune ring, cracks, vortex, the void). The camera stands low
--      behind the necromancer, looking up.
--   4. Only the front of the Absolution slides out of the portal, nose first, overhead, and stops.
--   5. The bow's helmet halves swing open and a drop pod falls out of the slit (black chrome, silver edges, cold-blue
--      seams, six blade petals like his coat), on a vapour trail; a long lens follows it down.
--   6. It slams into the grave: the grave bursts, a ring of cold-blue runes rolls out over the ground.
--   7. Steam, then the petals fold open like his coat blades; Malak hovers inside. Hero shot, name, his line:
--      "High Command sends its regards. The Envoy has arrived."
--   8. The camera cranes back: the ship pulls back into the portal, which snaps shut. Continue: the usual absorb.
-- Everything stays within ~300 studs of the camera (what low graphics quality still draws, see FleetStrike).
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local mainGui = require(script.Parent.Gui)
local Theme = require(script.Parent.Theme)
local GraveOpening = require(script.Parent.GraveOpening)
local NecroRitual = require(script.Parent.NecroRitual)
local Sfx = require(script.Parent.Sfx)
local FleetStrike = require(script.Parent.FleetStrike)
local SignatureDescent = require(script.Parent.SignatureDescent)
local Units = require(ReplicatedStorage.Shared.Units)

local player = Players.LocalPlayer
local SKY = FleetStrike.sky

local SovereignArrival = {}
SovereignArrival.active = false

-- ============================================================
-- Settings
-- ============================================================
local GRAVE_SCALE = 1.5
local GRAVE_DISTANCE = 16
local PROP_TAG = "ProceduralUnit"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"

-- his palette (docs/envoy.md): black chrome, silver, cold white-blue light, a hint of violet; red only for targeting
local CHROME = Color3.fromRGB(28, 28, 36)
local CHROME_LIGHT = Color3.fromRGB(50, 50, 62)
local SILVER = Color3.fromRGB(176, 180, 196)
local VIOLET = Color3.fromRGB(44, 30, 74)
local GLOW = Color3.fromRGB(165, 180, 255)
local GLOW_CORE = Color3.fromRGB(235, 240, 255)
local RED = Color3.fromRGB(255, 40, 40)

-- where the ship hangs: its bow tip BOW_UP above the grave and BOW_OUT beyond it (seen from the necromancer), nose
-- pointing back at them and dipping BOW_PITCH; only BOW_SHARE of its length is out of the portal
local BOW_UP = 55
local BOW_OUT = 18
local BOW_PITCH = math.rad(12)
local SHIP_LENGTH = 435 -- (the model's length at ship scale 1, chin to fin tips, before SKY.SHIP_SCALE)
local BOW_SHARE = 0.38

-- the drop pod: six blade petals round a base ring, their tips meeting in a crown
local POD_PETALS = 6
local POD_RADIUS = 4.6 -- (the base ring)
local POD_HEIGHT = 14 -- (crown tip above the base ring)
local POD_BASE = 1.4 -- (the base ring's height)
local POD_OPEN = math.rad(92) -- (how far each petal folds out: down flat onto the ground, so they never stand in front of the camera)

-- ── Timeline (s) ──────────────────────────────────────────
local START_SILENCE = 2.6 -- the grave freezes
local LASER_FROM = 3.3 -- the red targeting laser
local LOCK_AT = 5.4 -- the reticle locks
local TEAR_FROM = 6.2 -- the tear's clock: SKY.TEAR_AT .. SKY.EMERGE_FROM over 7 s
local EMERGE_FROM = 13.2 -- the bow slides out ...
local EMERGE_TO = 19.2 -- ... and stops
local BOW_OPEN_FROM, BOW_OPEN_TO = 19.6, 21.0
local RELEASE_AT = 21.3 -- the pod leaves the slit
local T_FALL = 2.6
local IMPACT_AT = RELEASE_AT + T_FALL
local PETALS_FROM = IMPACT_AT + 1.5 -- steam first, then the petals fold open
local T_PETALS = 2.2
local VOICE_AT = PETALS_FROM + T_PETALS + 0.4
local VOICE_LENGTH = 5.97
local CRANE_FROM = VOICE_AT + 2.3 -- the camera cranes back while he speaks on
local RETREAT_FROM = VOICE_AT + 2.6 -- the ship pulls back into the portal ...
local RETREAT_TO = RETREAT_FROM + 4.6
local SNAP_AT = RETREAT_TO + 0.2 -- ... and it snaps shut
local HOLD_AT = SNAP_AT + 1.2 -- Continue
local ABSORB_TIME = 1.9

local PHRASES = {
	{ at = 0, text = "HIGH COMMAND SENDS ITS REGARDS. ", reveal = 2.5 },
	{ at = 3.89, text = "THE ENVOY HAS ARRIVED.", reveal = 1.8 },
}

local function smooth(x)
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end
local function e(T, a, b)
	return smooth((T - a) / (b - a))
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

-- the tear's and the ship's clocks (FleetStrike's beats) for this cinematic's time T
local function tearClock(T)
	if T < TEAR_FROM then
		return SKY.TEAR_AT - 0.1
	elseif T < EMERGE_FROM then
		return SKY.TEAR_AT + (T - TEAR_FROM) / (EMERGE_FROM - TEAR_FROM) * (SKY.EMERGE_FROM - SKY.TEAR_AT)
	elseif T < RETREAT_FROM then
		-- (held open: the cracks fade slowly)
		return SKY.EMERGE_FROM + (T - EMERGE_FROM) / (RETREAT_FROM - EMERGE_FROM) * 5
	elseif T < SNAP_AT then
		local from = SKY.EMERGE_FROM + 5
		return from + (SKY.SNAP_AT - from) * math.clamp((T - RETREAT_FROM) / (SNAP_AT - RETREAT_FROM), 0, 1)
	end
	return SKY.SNAP_AT + (T - SNAP_AT)
end
local function warpClock(T)
	local span = SKY.EMERGE_TO - SKY.EMERGE_FROM
	if T < RETREAT_FROM then
		return SKY.EMERGE_FROM + span * math.clamp((T - EMERGE_FROM) / (EMERGE_TO - EMERGE_FROM), 0, 1)
	end
	-- back into the portal: slow to start (the heavy ship), then it slides in
	local k = math.clamp((T - RETREAT_FROM) / (RETREAT_TO - RETREAT_FROM), 0, 1)
	return SKY.EMERGE_FROM - 0.1 + (span + 0.1) * (1 - k * k * (3 - 2 * k))
end

-- ============================================================
-- The drop pod (built here: it only exists in this cinematic)
-- ============================================================
-- Returns { parts, place(baseCF, open, glow) }: baseCF is the pod's floor centre (LookVector = its front), open 0..1
local function buildPod(folder)
	local pod = { parts = {}, offsets = {}, petalOf = {} }
	local function add(p, petal, offset)
		table.insert(pod.parts, p)
		pod.offsets[p] = offset
		pod.petalOf[p] = petal
	end
	-- the base ring: dark chrome, a silver rim, glowing thruster ports underneath
	local base = newPart(folder, Vector3.new(POD_BASE, POD_RADIUS * 2.15, POD_RADIUS * 2.15), CFrame.new(), CHROME, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	add(base, nil, CFrame.new(0, POD_BASE / 2, 0) * CFrame.Angles(0, 0, math.pi / 2))
	local rim = newPart(folder, Vector3.new(0.35, POD_RADIUS * 2.3, POD_RADIUS * 2.3), CFrame.new(), SILVER, Enum.Material.Metal, Enum.PartType.Cylinder)
	add(rim, nil, CFrame.new(0, POD_BASE + 0.05, 0) * CFrame.Angles(0, 0, math.pi / 2))
	pod.ports = {}
	for k = 0, POD_PETALS - 1 do
		local a = (k + 0.5) / POD_PETALS * math.pi * 2
		local port = newPart(folder, Vector3.new(0.3, 1.3, 1.3), CFrame.new(), GLOW, Enum.Material.Neon, Enum.PartType.Cylinder)
		add(port, nil, CFrame.new(math.cos(a) * POD_RADIUS * 0.6, -0.12, math.sin(a) * POD_RADIUS * 0.6) * CFrame.Angles(0, 0, math.pi / 2))
		table.insert(pod.ports, port)
	end
	-- the core light inside (seen when the petals open)
	local inner = newPart(folder, Vector3.new(0.2, POD_RADIUS * 1.6, POD_RADIUS * 1.6), CFrame.new(), GLOW_CORE, Enum.Material.Neon, Enum.PartType.Cylinder)
	add(inner, nil, CFrame.new(0, POD_BASE + 0.2, 0) * CFrame.Angles(0, 0, math.pi / 2))
	pod.inner = inner
	local light = Instance.new("PointLight")
	light.Color = GLOW
	light.Range = 18
	light.Brightness = 0
	light.Shadows = false
	light.Parent = inner
	pod.light = light

	-- the petals: blade plates leaning in from the base ring to the crown. Each petal's parts are placed in its own
	-- frame: origin at the hinge on the ring, +Y up the blade, +Z its outer face, X across.
	local L = math.sqrt(POD_RADIUS ^ 2 + POD_HEIGHT ^ 2)
	local w = 2 * POD_RADIUS * math.tan(math.pi / POD_PETALS) * 1.12 -- (a little wider than the gaps: no light shows through)
	local t = 0.5
	pod.lean = math.atan2(POD_RADIUS, POD_HEIGHT)
	pod.seams = {}
	for k = 0, POD_PETALS - 1 do
		local petal = { angle = k / POD_PETALS * math.pi * 2 }
		add(newPart(folder, Vector3.new(w, L, t), CFrame.new(), CHROME, Enum.Material.SmoothPlastic), petal, CFrame.new(0, L / 2, 0))
		-- the inner violet lining (seen when it opens), the silver edges standing proud, the cold seam down the middle
		add(newPart(folder, Vector3.new(w * 0.82, L * 0.9, 0.12), CFrame.new(), VIOLET, Enum.Material.SmoothPlastic), petal, CFrame.new(0, L * 0.46, -t / 2 - 0.04))
		for _, s in ipairs({ -1, 1 }) do
			add(newPart(folder, Vector3.new(0.32, L - 0.4, t + 0.16), CFrame.new(), SILVER, Enum.Material.Metal), petal, CFrame.new(s * (w / 2 + 0.04), L / 2 - 0.1, 0))
		end
		local seam = newPart(folder, Vector3.new(0.28, L * 0.78, 0.14), CFrame.new(), GLOW, Enum.Material.Neon)
		add(seam, petal, CFrame.new(0, L * 0.45, t / 2 + 0.05))
		table.insert(pod.seams, seam)
		-- his diamond emblem low on each petal
		add(newPart(folder, Vector3.new(1.1, 1.1, 0.2), CFrame.new(), SILVER, Enum.Material.Metal), petal, CFrame.new(0, L * 0.2, t / 2 + 0.1) * CFrame.Angles(0, 0, math.rad(45)))
	end
	-- the crown: a glowing spike where the tips meet (it falls away when the petals open)
	local crown = newPart(folder, Vector3.new(0.9, 2.6, 0.9), CFrame.new(), GLOW_CORE, Enum.Material.Neon)
	add(crown, nil, CFrame.new(0, POD_BASE + POD_HEIGHT + 0.9, 0))
	pod.crown = crown

	function pod.place(baseCF, open, glow)
		local moveParts, moveCFrames = {}, {}
		local floor = baseCF * CFrame.new(0, POD_BASE, 0)
		for _, p in ipairs(pod.parts) do
			local petal = pod.petalOf[p]
			local cf
			if petal then
				-- hinge on the ring, facing out; closed it leans in, open it folds out and down (with a little overshoot
				-- baked into `open` by the caller)
				local hinge = floor * CFrame.Angles(0, -petal.angle, 0) * CFrame.new(0, 0, -POD_RADIUS) * CFrame.Angles(0, math.pi, 0)
				local tilt = -pod.lean + (pod.lean + POD_OPEN) * open
				cf = hinge * CFrame.Angles(tilt, 0, 0) * pod.offsets[p]
			else
				cf = baseCF * pod.offsets[p]
			end
			table.insert(moveParts, p)
			table.insert(moveCFrames, cf)
		end
		Workspace:BulkMoveTo(moveParts, moveCFrames, Enum.BulkMoveMode.FireCFrameChanged)
		for _, s in ipairs(pod.seams) do
			s.Transparency = 0.45 - 0.4 * glow
		end
		pod.crown.Transparency = math.clamp(open * 3, 0, 1)
	end
	function pod.setHidden(hidden)
		for _, p in ipairs(pod.parts) do
			p.LocalTransparencyModifier = hidden and 1 or 0
		end
	end
	return pod
end

-- ============================================================
-- Play
-- ============================================================
function SovereignArrival.play(results, opts)
	opts = opts or {}
	local template = GraveOpening.template(opts.graveType)
	local shipModels = ReplicatedStorage:FindFirstChild("ShipModels")
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local camera = Workspace.CurrentCamera
	if SovereignArrival.active or SignatureDescent.active or FleetStrike.active or not template or not (shipModels and shipModels:FindFirstChild("Absolution"))
		or not hrp or not camera or not results or #results == 0 then
		return false
	end
	SovereignArrival.active = true

	-- the Sovereign among the results (the best one)
	local best = results[1]
	for _, r in ipairs(results) do
		if Units.isSovereign(r.unitType) and not Units.isSovereign(best.unitType) then
			best = r
		end
	end

	-- ── The place: like The Descent (a clear view round the grave) ──
	local up = Vector3.yAxis
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	local ignore = {}
	for _, other in ipairs(Players:GetPlayers()) do
		if other.Character then
			table.insert(ignore, other.Character)
		end
	end
	rayParams.FilterDescendantsInstances = ignore
	local function viewIsClear(from, to)
		return Workspace:Raycast(from, to - from, rayParams) == nil
	end
	local flatLook = Vector3.new(hrp.CFrame.LookVector.X, 0, hrp.CFrame.LookVector.Z)
	local lookDir = flatLook.Magnitude > 0.1 and flatLook.Unit or Vector3.new(0, 0, -1)
	local dir, right, G
	for _, degrees in ipairs({ 0, 45, -45, 90, -90, 135, -135, 180 }) do
		local a = math.rad(degrees)
		local d = Vector3.new(lookDir.X * math.cos(a) - lookDir.Z * math.sin(a), 0, lookDir.X * math.sin(a) + lookDir.Z * math.cos(a))
		local r = Vector3.new(-d.Z, 0, d.X)
		local hit = Workspace:Raycast(hrp.Position + d * GRAVE_DISTANCE + up * 20, Vector3.new(0, -60, 0), rayParams)
		if hit and hit.Normal.Y > 0.9 and hit.Position.Y < hrp.Position.Y - 1.5 and hit.Position.Y > hrp.Position.Y - 6 then
			local g = hit.Position
			local eye = g + up * 3
			if viewIsClear(eye, g - d * 16 + r * 6 + up * 7) and viewIsClear(eye, g + up * BOW_UP) then
				dir, right, G = d, r, g
				break
			end
		end
	end
	if not G then
		dir = lookDir
		right = Vector3.new(-dir.Z, 0, dir.X)
		local hum = char:FindFirstChildOfClass("Humanoid")
		G = hrp.Position + dir * GRAVE_DISTANCE - Vector3.new(0, (hum and hum.HipHeight or 2) + hrp.Size.Y / 2, 0)
	end

	local fxFolder = Instance.new("Folder")
	fxFolder.Name = "SovereignArrivalFX"
	fxFolder.Parent = Workspace

	-- ── The grave ────────────────────────────────────────────
	local model = template:Clone()
	model:ScaleTo(GRAVE_SCALE)
	local facing = CFrame.lookAt(G, G - dir)
	model:PivotTo(facing)
	local core = model:FindFirstChild("Core")
	if core then
		local off = G - core.Position
		model:PivotTo(facing + Vector3.new(off.X, 0, off.Z))
	end
	local rest = model:GetPivot()
	local _, graveSize = model:GetBoundingBox()
	model:PivotTo(rest - up * (graveSize.Y + 0.5))
	model.Parent = fxFolder
	local grave = GraveOpening.attach(model, { scale = GRAVE_SCALE, world = true })

	-- ── The ship and the portal ──────────────────────────────
	-- the bow tip ends up over the grave, nose pointing back at the necromancer and dipping a little
	local axis = (-dir * math.cos(BOW_PITCH) - up * math.sin(BOW_PITCH)).Unit
	local bowTip = G + dir * BOW_OUT + up * BOW_UP
	local outLength = SHIP_LENGTH * SKY.SHIP_SCALE * BOW_SHARE
	local portalPos = bowTip - axis * outLength
	local portalCF = CFrame.lookAt(portalPos, portalPos + axis)
	-- (warpIn's "final" place is where the ship stops: its core outLength - 225 x scale beyond the portal)
	local shipCore = portalPos + axis * (outLength - 225 * SKY.SHIP_SCALE)
	local shipFinal = CFrame.lookAt(shipCore, shipCore + axis)
	local shipCtx = {}
	local tearUpdate, tearCleanup = SKY.tear(fxFolder, portalCF)
	local warpUpdate, warpCleanup = SKY.warpIn(fxFolder, portalCF, shipFinal, shipCtx)
	local ship = fxFolder:FindFirstChild("Absolution")
	local bowL = ship and ship:FindFirstChild("BowL", true)
	local bowR = ship and ship:FindFirstChild("BowR", true)
	local shipGone = false

	-- ── The targeting laser and the reticle (red) ────────────
	local laser = newPart(fxFolder, Vector3.new(0.18, 0.18, 1), CFrame.new(G), RED)
	laser.Transparency = 1
	local laserFrom = portalPos + right * 6
	local reticle = {}
	for ring = 1, 3 do
		local n = 4 + ring * 2
		for k = 0, n - 1 do
			local p = newPart(fxFolder, Vector3.new(0.12, 0.3, 1), CFrame.new(G), RED)
			p.Transparency = 1
			table.insert(reticle, { part = p, ring = ring, a = k / n * math.pi * 2, n = n })
		end
	end
	local cross = {}
	for k = 0, 3 do
		local p = newPart(fxFolder, Vector3.new(0.12, 0.3, 2.2), CFrame.new(G), RED)
		p.Transparency = 1
		table.insert(cross, { part = p, a = k / 4 * math.pi * 2 })
	end

	-- ── The pod ──────────────────────────────────────────────
	local pod = buildPod(fxFolder)
	pod.setHidden(true)
	pod.place(CFrame.new(0, -5000, 0), 0, 0)
	-- the vapour trail it leaves behind, and the steam out of its vents after the landing
	local trailHolder = newPart(fxFolder, Vector3.one * 0.3, CFrame.new(0, -5000, 0), GLOW, Enum.Material.SmoothPlastic)
	trailHolder.Transparency = 1
	local trail = Instance.new("ParticleEmitter")
	trail.Texture = SMOKE
	trail.Color = ColorSequence.new(Color3.fromRGB(220, 226, 240), Color3.fromRGB(120, 126, 150))
	trail.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2.5), NumberSequenceKeypoint.new(1, 7) })
	trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) })
	trail.Lifetime = NumberRange.new(1.4, 2.2)
	trail.Speed = NumberRange.new(0.5, 2)
	trail.SpreadAngle = Vector2.new(20, 20)
	trail.RotSpeed = NumberRange.new(-30, 30)
	trail.Rate = 0
	trail.LightInfluence = 0.4
	trail.Parent = trailHolder
	local steam = {}
	for k = 0, POD_PETALS - 1 do
		local a = (k + 0.5) / POD_PETALS * math.pi * 2
		local pos = G + Vector3.new(math.cos(a), 0, math.sin(a)) * (POD_RADIUS + 0.6) + up * (POD_BASE + 0.4)
		local h = newPart(fxFolder, Vector3.one * 0.3, CFrame.lookAt(pos, pos + Vector3.new(math.cos(a), 0.6, math.sin(a))), GLOW, Enum.Material.SmoothPlastic)
		h.Transparency = 1
		local em = Instance.new("ParticleEmitter")
		em.Texture = SMOKE
		em.Color = ColorSequence.new(Color3.fromRGB(230, 234, 245))
		em.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 5) })
		em.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
		em.Lifetime = NumberRange.new(0.9, 1.6)
		em.Speed = NumberRange.new(10, 16)
		em.SpreadAngle = Vector2.new(10, 10)
		em.Drag = 3
		em.EmissionDirection = Enum.NormalId.Front
		em.Rate = 0
		em.Parent = h
		table.insert(steam, em)
	end
	-- the rune ring rolling out over the ground at the impact
	local wave = {}
	for k = 0, 47 do
		local isRune = k % 6 == 0
		local p = newPart(fxFolder, isRune and Vector3.new(1.2, 0.15, 1.2) or Vector3.new(1, 0.15, 0.45), CFrame.new(G), isRune and GLOW_CORE or GLOW)
		p.Transparency = 1
		table.insert(wave, { part = p, a = k / 48 * math.pi * 2, rune = isRune })
	end
	local dust = newPart(fxFolder, Vector3.one * 0.3, CFrame.new(G + up * 0.5), GLOW, Enum.Material.SmoothPlastic)
	dust.Transparency = 1
	local dustEm = Instance.new("ParticleEmitter")
	dustEm.Texture = SMOKE
	dustEm.Color = ColorSequence.new(Color3.fromRGB(150, 140, 135), Color3.fromRGB(90, 86, 92))
	dustEm.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 3), NumberSequenceKeypoint.new(1, 10) })
	dustEm.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
	dustEm.Lifetime = NumberRange.new(1.5, 2.6)
	dustEm.Speed = NumberRange.new(14, 26)
	dustEm.SpreadAngle = Vector2.new(180, 15)
	dustEm.Drag = 2.5
	dustEm.Rate = 0
	dustEm.EmissionDirection = Enum.NormalId.Top
	dustEm.Parent = dust
	local sparks = Instance.new("ParticleEmitter")
	sparks.Texture = SPARKLE
	sparks.Color = ColorSequence.new(GLOW_CORE, GLOW)
	sparks.LightEmission = 1
	sparks.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) })
	sparks.Lifetime = NumberRange.new(0.8, 1.6)
	sparks.Speed = NumberRange.new(20, 40)
	sparks.SpreadAngle = Vector2.new(80, 80)
	sparks.Acceleration = Vector3.new(0, -30, 0)
	sparks.Rate = 0
	sparks.EmissionDirection = Enum.NormalId.Top
	sparks.Parent = dust

	-- ── The unit (inside the pod from the impact on) ─────────
	local unitTemplate = ReplicatedStorage:FindFirstChild("UnitModels") and ReplicatedStorage.UnitModels:FindFirstChild(best.unitType)
	local def = Units.Stats[best.unitType]
	local unitScale = def and (def.size.X / 2 * 0.9) or 1
	local rootHeight = (unitTemplate and unitTemplate:GetAttribute("RootHeight") or 2.2) * unitScale
	local unitTall = (unitTemplate and unitTemplate:GetAttribute("Height") or 6) * unitScale
	local podBase = CFrame.lookAt(G, G - dir)
	local landPivot = CFrame.lookAt(G + up * (rootHeight + POD_BASE), G + up * (rootHeight + POD_BASE) - dir)
	local unit
	local function spawnUnit()
		if not unitTemplate then
			return
		end
		unit = unitTemplate:Clone()
		for _, d in ipairs(unit:GetDescendants()) do
			if d:IsA("BaseScript") or d:IsA("Humanoid") then
				d:Destroy()
			elseif d:IsA("BasePart") then
				d.Anchored = false
				d.CanCollide = false
				d.CanQuery = false
				d.CanTouch = false
			end
		end
		unit:ScaleTo(unitScale)
		local root = unit.PrimaryPart or unit:FindFirstChild("HumanoidRootPart", true)
		if root then
			root.Anchored = true
		end
		unit:PivotTo(landPivot)
		unit:SetAttribute("AttackStyle", nil)
		unit:SetAttribute("State", "idle")
		unit.Parent = fxFolder
		CollectionService:AddTag(unit, PROP_TAG)
	end

	-- ── Take over camera, controls and the UI (like The Descent) ──
	local saved = { cameraType = camera.CameraType, fov = camera.FieldOfView, guiEnabled = mainGui.Enabled }
	local controls
	pcall(function()
		controls = require(player.PlayerScripts:WaitForChild("PlayerModule", 2)):GetControls()
		controls:Disable()
	end)
	mainGui.Enabled = false
	local hiddenGuis = {}
	for _, g in ipairs(player:WaitForChild("PlayerGui"):GetChildren()) do
		if g:IsA("ScreenGui") and g.Enabled and g.Name ~= "Freecam" then
			g.Enabled = false
			table.insert(hiddenGuis, g)
		end
	end
	camera.CameraType = Enum.CameraType.Scriptable
	local characterHidden = false
	local function hideCharacter(hidden)
		if hidden == characterHidden then
			return
		end
		characterHidden = hidden
		local c = player.Character
		if not c then return end
		for _, d in ipairs(c:GetDescendants()) do
			if d:IsA("BasePart") or d:IsA("Decal") then
				d.LocalTransparencyModifier = hidden and 1 or 0
			end
		end
	end
	local startCam = camera.CFrame
	local charHum = hrp.Parent and hrp.Parent:FindFirstChildOfClass("Humanoid")
	local charFeet = hrp.Position - Vector3.new(0, (charHum and charHum.HipHeight or 2) + hrp.Size.Y / 2, 0)
	local savedAnchored = hrp.Anchored
	hrp.CFrame = CFrame.lookAt(hrp.Position, Vector3.new(G.X, hrp.Position.Y, G.Z))
	hrp.Anchored = true
	local graveTarget = newPart(fxFolder, Vector3.one * 0.3, CFrame.new(G + up * 2), GLOW, Enum.Material.SmoothPlastic)
	graveTarget.Transparency = 1
	local ritual = NecroRitual.new({ hrp = hrp, folder = fxFolder, target = graveTarget, smokeAt = graveTarget, feet = charFeet, color = GLOW })

	local ui = Instance.new("ScreenGui")
	ui.Name = "SovereignArrivalUI"
	ui.ResetOnSpawn = false
	ui.IgnoreGuiInset = true
	ui.DisplayOrder = 100
	ui.Parent = player:WaitForChild("PlayerGui")
	local function bar(anchorY)
		local f = Instance.new("Frame")
		f.AnchorPoint = Vector2.new(0, anchorY)
		f.Position = UDim2.fromScale(0, anchorY)
		f.Size = UDim2.fromScale(1, 0)
		f.BackgroundColor3 = Color3.new(0, 0, 0)
		f.BorderSizePixel = 0
		f.Parent = ui
		return f
	end
	local barTop, barBottom = bar(0), bar(1)
	local flash = Instance.new("Frame")
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = GLOW_CORE
	flash.BackgroundTransparency = 1
	flash.BorderSizePixel = 0
	flash.ZIndex = 5
	flash.Parent = ui
	-- the name and the class over the top bar's edge (the subtitles take the bottom)
	local nameLbl = Instance.new("TextLabel")
	nameLbl.AnchorPoint = Vector2.new(0.5, 0)
	nameLbl.Position = UDim2.fromScale(0.5, 0.13)
	nameLbl.Size = UDim2.fromOffset(900, 72)
	nameLbl.BackgroundTransparency = 1
	nameLbl.Font = Enum.Font.Sarpanch
	nameLbl.TextSize = 62
	nameLbl.TextColor3 = GLOW_CORE
	nameLbl.TextStrokeColor3 = Color3.new(0, 0, 0)
	nameLbl.TextTransparency = 1
	nameLbl.TextStrokeTransparency = 1
	nameLbl.Text = best.unitType .. (def and def.title and (" - " .. def.title) or "") -- ("Malak - The Envoy")
	nameLbl.ZIndex = 6
	nameLbl.Parent = ui
	local classLbl = nameLbl:Clone()
	classLbl.Position = UDim2.fromScale(0.5, 0.13)
	classLbl.Size = UDim2.fromOffset(700, 26)
	classLbl.TextSize = 20
	classLbl.Font = Enum.Font.RobotoMono
	classLbl.TextColor3 = GLOW
	classLbl.Text = string.upper(best.rarity) .. "  SOVEREIGN"
	classLbl.Parent = ui
	nameLbl.Position = UDim2.new(0.5, 0, 0.13, 26)
	-- his line: the Fleet Strike's military subtitle style (a speaker label, pale text, a dark outline)
	local subs = Instance.new("CanvasGroup")
	subs.AnchorPoint = Vector2.new(0.5, 1)
	subs.Position = UDim2.fromScale(0.5, 0.885)
	subs.Size = UDim2.fromScale(0.84, 0.13)
	subs.BackgroundTransparency = 1
	subs.Visible = false
	subs.ZIndex = 10
	subs.Parent = ui
	local speaker = Instance.new("TextLabel")
	speaker.Size = UDim2.fromScale(1, 0.24)
	speaker.BackgroundTransparency = 1
	speaker.Font = Enum.Font.RobotoMono
	speaker.Text = "MALAK"
	speaker.TextColor3 = Color3.fromRGB(165, 188, 205)
	speaker.TextScaled = true
	speaker.ZIndex = 10
	speaker.Parent = subs
	local speakerSize = Instance.new("UITextSizeConstraint")
	speakerSize.MaxTextSize = 14
	speakerSize.Parent = speaker
	local line = Instance.new("TextLabel")
	line.Position = UDim2.fromScale(0, 0.3)
	line.Size = UDim2.fromScale(1, 0.68)
	line.BackgroundTransparency = 1
	line.Font = Enum.Font.Sarpanch
	line.TextColor3 = Color3.fromRGB(232, 238, 242)
	line.TextScaled = true
	line.TextWrapped = true
	line.MaxVisibleGraphemes = 0
	line.ZIndex = 10
	line.Parent = subs
	local lineSize = Instance.new("UITextSizeConstraint")
	lineSize.MaxTextSize = 30
	lineSize.Parent = line
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(6, 9, 13)
	stroke.Thickness = 1.5
	stroke.Transparency = 0.15
	stroke.Parent = line
	local fullText = ""
	for _, ph in ipairs(PHRASES) do
		ph.count = utf8.len(ph.text)
		fullText ..= ph.text
	end
	line.Text = fullText

	local skipBtn = Theme.stoneButton(ui, {
		text = "Skip", color = "stone", size = UDim2.fromOffset(120, 40),
		position = UDim2.new(1, -24, 1, -20), anchor = Vector2.new(1, 1), zIndex = 8,
	})
	local continueBtn = Theme.stoneButton(ui, {
		text = "Continue", size = UDim2.fromOffset(180, 48),
		position = UDim2.new(0.5, 0, 1, -8), anchor = Vector2.new(0.5, 1), zIndex = 8,
	})
	continueBtn.root.Visible = false

	-- ── State ────────────────────────────────────────────────
	local T = 0
	local endTime = math.huge
	local absorbStart
	local done = false
	local connection, keyConn
	local rumbleSfx, humSfx, shipSfx
	local shakeAmount, shakeStart = 0, 0
	local flashStart
	local silenced, released, impacted = false, false, false
	local cues = {}
	local function cue(name, at, volume, pitch)
		table.insert(cues, { name = name, at = at, volume = volume, pitch = pitch })
	end
	cue("target_lock", LASER_FROM + 0.1, 0.6, 0.9)
	cue("target_lock", LOCK_AT - 0.9, 0.7, 1)
	cue("target_lock", LOCK_AT - 0.45, 0.8, 1.05)
	cue("target_lock", LOCK_AT, 1, 1.12)
	cue("tear_rumble", TEAR_FROM)
	cue("tear_crack", TEAR_FROM + (SKY.CRACKS_AT - SKY.TEAR_AT) * (EMERGE_FROM - TEAR_FROM) / (SKY.EMERGE_FROM - SKY.TEAR_AT))
	cue("warp_in_suspense", EMERGE_FROM - 1)
	cue("warp_in_scanner", EMERGE_FROM)
	cue("warp_in_warhorn", EMERGE_FROM + 1.4)
	cue("bow_open", BOW_OPEN_FROM)
	cue("drone_transform", RELEASE_AT - 0.3, 3, 0.8) -- (the pod's clamps letting go)
	cue("gate_collapse", IMPACT_AT, 0.7, 1.1)
	cue("shell_impact", IMPACT_AT, 1, 0.6)
	cue("reactor_lock", PETALS_FROM - 0.25, 0.8, 0.9) -- (the locks release)
	cue("bow_open", PETALS_FROM, 0.9, 1.25)
	cue("voice_arrival", VOICE_AT)
	cue("portal_snap", SNAP_AT)

	local function startFlash(seconds, transparency)
		flashStart = { at = os.clock(), length = seconds }
		flash.BackgroundTransparency = transparency or 0
	end

	local function finish()
		if done then
			return
		end
		done = true
		for _, s in pairs({ rumbleSfx, humSfx, shipSfx }) do
			s.stop(0.2)
		end
		if connection then connection:Disconnect() end
		if keyConn then keyConn:Disconnect() end
		grave.stop()
		if unit then
			CollectionService:RemoveTag(unit, PROP_TAG)
		end
		tearCleanup()
		if not shipGone then
			warpCleanup()
		end
		fxFolder:Destroy()
		ui:Destroy()
		camera.CameraType = saved.cameraType == Enum.CameraType.Scriptable and Enum.CameraType.Custom or saved.cameraType
		camera.FieldOfView = saved.fov
		mainGui.Enabled = saved.guiEnabled
		for _, g in ipairs(hiddenGuis) do
			if g.Parent then
				g.Enabled = true
			end
		end
		hideCharacter(false)
		ritual.restore()
		if hrp.Parent then
			hrp.Anchored = savedAnchored
		end
		if controls then
			pcall(function() controls:Enable() end)
		end
		SovereignArrival.active = false
		if opts.onDone then
			opts.onDone()
		end
	end
	skipBtn.button.Activated:Connect(finish)
	local function continue()
		if endTime == math.huge and continueBtn.root.Visible then
			absorbStart = T
			endTime = T + ABSORB_TIME + 0.5
			continueBtn.root.Visible = false
		end
	end
	continueBtn.button.Activated:Connect(continue)
	keyConn = UserInputService.InputBegan:Connect(function(input)
		local key = input.KeyCode
		if key == Enum.KeyCode.Space or key == Enum.KeyCode.Return or key == Enum.KeyCode.E or key == Enum.KeyCode.ButtonA then
			continue()
		end
	end)
	rumbleSfx = Sfx.loop("rumble", model.PrimaryPart)

	-- the pod's path: out of the bow slit, a short push forward, then down onto the grave (gravity, faster and faster)
	local podFrom
	local function podPosition(f)
		local to = G
		local mid = podFrom + axis * 6 - up * 4
		local a = podFrom:Lerp(mid, f)
		local b = mid:Lerp(to, f)
		return a:Lerp(b, f)
	end

	-- the cameras
	local camChannel = charFeet - dir * 3 + right * 11 + up * 4
	local channelLook = charFeet:Lerp(G, 0.5) + up * 3
	if not viewIsClear(camChannel, channelLook) then
		camChannel = charFeet - dir * 3 - right * 11 + up * 4
	end
	local camLow = charFeet - dir * 8 + right * 3.5 + up * 2.2 -- low behind the necromancer, looking up
	local camLong = G - dir * 26 + right * 46 + up * 4 -- the long lens for the fall (off to the side, near the ground)
	local HERO_FOV = 50
	local heroLookY = math.max(3, unitTall * 0.55) + POD_BASE
	local heroDist = math.max(16, (unitTall * 0.5 + 2) / math.tan(math.rad(HERO_FOV / 2)) * 1.25)
	local camHero = G - dir * heroDist + right * 5 + up * math.max(3, unitTall * 0.35)
	local camCrane = charFeet - dir * 12 + right * 9 + up * 5
	local lastCamPos, lastCamLook = camChannel, channelLook

	-- ── Per-frame ────────────────────────────────────────────
	local speed = opts.speed or 1
	connection = RunService.RenderStepped:Connect(function(realDt)
		if done then
			return
		end
		local dt = realDt * speed
		T += dt
		if absorbStart then
			hideCharacter(false)
			if ritual.absorb((T - absorbStart) / ABSORB_TIME, unit) then
				unit = nil
				startFlash(0.4, 0.4)
			end
		else
			-- the bait (they work on the grave), then they stop and look up into the sky
			local weight = smooth((T - 0.9) / 0.6) * (1 - smooth((T - START_SILENCE) / 0.5))
			local p = math.clamp((T - 1.1) / (START_SILENCE - 1.1), 0, 1)
			ritual.update(weight, p * p * 0.6, "forward")
			local lookAt = T < IMPACT_AT and portalPos:Lerp(bowTip, smooth((T - EMERGE_FROM) / 6)) or G + up * 4
			ritual.look(lookAt, smooth((T - START_SILENCE - 0.4) / 1.2))
			-- hidden while the camera stands where they are (the fall and the hero shot)
			hideCharacter(T >= RELEASE_AT and T < CRANE_FROM)
		end
		if T >= endTime then
			finish()
			return
		end
		if T >= HOLD_AT and endTime == math.huge and not continueBtn.root.Visible then
			continueBtn.root.Visible = true
			skipBtn.root.Visible = false
		end
		local barSize = 0.11 * smooth(T / 0.5) * smooth((endTime - T) / 0.5)
		barTop.Size = UDim2.fromScale(1, barSize)
		barBottom.Size = UDim2.fromScale(1, barSize)
		if flashStart then
			local k = (os.clock() - flashStart.at) / flashStart.length
			flash.BackgroundTransparency = math.clamp(k, 0, 1) ^ 0.7
			if k >= 1 then
				flashStart = nil
			end
		end
		for _, c in ipairs(cues) do
			if not c.fired and T >= c.at then
				c.fired = true
				if T - c.at < 0.5 then
					Sfx.play(c.name, nil, c.volume or 1, c.pitch)
				end
			end
		end

		-- ── 1. The grave rises, shakes ... and freezes ──
		if T < 1.1 then
			local k = smooth(T / 0.95)
			rumbleSfx.set(0.35 + 0.65 * (1 - k), 0.85)
			local rumble = (1 - k) * 0.12 * GRAVE_SCALE
			model:PivotTo((rest - up * (graveSize.Y + 0.5) * (1 - k)) * CFrame.new((math.random() - 0.5) * rumble, 0, (math.random() - 0.5) * rumble))
		elseif T < START_SILENCE then
			local p = (T - 1.1) / (START_SILENCE - 1.1)
			rumbleSfx.set(0.3 + 0.7 * p, 0.88 + 0.25 * p)
			local amp = (0.03 + 0.16 * p) * GRAVE_SCALE
			model:PivotTo(rest * CFrame.new((math.random() - 0.5) * amp, 0, (math.random() - 0.5) * amp))
			grave.setGlow(GLOW, p * p * 0.5)
			shakeAmount, shakeStart = 0.04 + 0.1 * p, os.clock()
		elseif not silenced then
			silenced = true
			rumbleSfx.stop(0.04)
			model:PivotTo(rest)
			grave.setGlow(GLOW, 0)
			shakeAmount = 0
		end

		-- ── 2. The targeting laser and the reticle ──
		local laserOn = e(T, LASER_FROM, LASER_FROM + 0.25) * (1 - e(T, TEAR_FROM + 0.6, TEAR_FROM + 1.4))
		if laserOn > 0 then
			local len = (G - laserFrom).Magnitude
			local flicker = math.random() < 0.06 and 0.5 or 0
			laser.Size = Vector3.new(0.18, 0.18, len)
			laser.CFrame = CFrame.lookAt((laserFrom + G) / 2, G)
			laser.Transparency = 1 - laserOn * (0.85 - flicker)
		else
			laser.Transparency = 1
		end
		local close = e(T, LASER_FROM + 0.3, LOCK_AT) -- the rings close in ...
		local locked = T >= LOCK_AT
		local reticleOn = laserOn * (locked and (0.75 + 0.25 * math.sin(T * 30)) or 0.7)
		for _, r in ipairs(reticle) do
			local radius = (3 + r.ring * 2.2) * (1 + 1.6 * (1 - close))
			local spin = (locked and 0 or (T - LASER_FROM) * (r.ring % 2 == 0 and -1.4 or 1.1) * (1 - close)) + r.a
			local seg = 2 * radius * math.sin(math.pi / r.n) * 0.55
			r.part.Size = Vector3.new(0.12, 0.3, seg)
			r.part.CFrame = CFrame.new(G + up * (0.25 + r.ring * 0.03)) * CFrame.Angles(0, spin, 0) * CFrame.new(radius, 0, 0)
			r.part.Transparency = 1 - reticleOn
		end
		for _, c in ipairs(cross) do
			local radius = 1.6 + 6 * (1 - close)
			c.part.CFrame = CFrame.new(G + up * 0.3) * CFrame.Angles(0, c.a + math.pi / 4, 0) * CFrame.new(0, 0, -radius - 1.1)
			c.part.Transparency = 1 - reticleOn
		end
		if locked and T - dt < LOCK_AT then
			startFlash(0.25, 0.85)
		end

		-- ── 3. + 4. The tear, the ship ──
		tearUpdate(tearClock(T))
		if not shipGone then
			shipCtx.spinT = T
			shipCtx.windowRun = T >= EMERGE_FROM + 1 and 2 or nil -- (its windows lit as it comes out)
			warpUpdate(warpClock(T))
			if T >= RETREAT_TO + 0.1 then
				shipGone = true
				warpCleanup()
			end
		end
		-- the portal hums while it is open; the ship's engines while it is out
		local hum = e(T, TEAR_FROM + 3, TEAR_FROM + 5) * (1 - e(T, SNAP_AT - 0.3, SNAP_AT))
		if hum > 0 and not humSfx then
			humSfx = Sfx.loop("portal_hum")
		end
		if humSfx then
			humSfx.set(hum)
		end
		local engines = e(T, EMERGE_FROM, EMERGE_FROM + 3) * (1 - e(T, RETREAT_FROM + 2, RETREAT_TO))
		if engines > 0 and not shipSfx then
			shipSfx = Sfx.loop("ship_hum")
		end
		if shipSfx then
			shipSfx.set(engines)
		end
		-- the bow's helmet halves swing aside (and close again before it leaves)
		local bowOpen = e(T, BOW_OPEN_FROM, BOW_OPEN_TO) * (1 - e(T, RETREAT_FROM - 1.5, RETREAT_FROM))
		if bowL and bowR then
			bowL.Transform = CFrame.Angles(0, SKY.BOW_OPEN_ANGLE * bowOpen, 0)
			bowR.Transform = CFrame.Angles(0, -SKY.BOW_OPEN_ANGLE * bowOpen, 0)
		end

		-- ── 5. The drop ──
		local podCF
		if T >= RELEASE_AT and not impacted then
			if not released then
				released = true
				podFrom = (shipCtx.bow or bowTip) - up * 3
				pod.setHidden(false)
				trail.Rate = 60
			end
			local f = math.clamp((T - RELEASE_AT) / T_FALL, 0, 1)
			local pos = podPosition(f * f)
			-- (upright, turning slowly, swaying a little)
			podCF = CFrame.new(pos) * CFrame.Angles(0, T * 0.9, 0) * CFrame.Angles(math.sin(T * 2.3) * 0.05, 0, math.cos(T * 1.9) * 0.05)
			pod.place(podCF, 0, 1)
			trailHolder.CFrame = podCF * CFrame.new(0, POD_HEIGHT * 0.5, 0)
			for _, port in ipairs(pod.ports) do
				port.Transparency = 0
			end
			if f >= 1 then
				-- ── 6. Impact ──
				impacted = true
				trail.Rate = 0
				model:PivotTo(rest)
				grave.burst(GLOW, 1)
				startFlash(0.8)
				shakeAmount, shakeStart = 2.6, os.clock()
				dustEm:Emit(70)
				sparks:Emit(60)
				spawnUnit()
				pod.place(podBase, 0, 1)
			end
		end
		if impacted then
			local r = T - IMPACT_AT
			-- the rune ring rolling out over the ground
			for _, w in ipairs(wave) do
				local radius = POD_RADIUS + 46 * (1 - (1 - math.clamp(r / 1.5, 0, 1)) ^ 3)
				w.part.CFrame = CFrame.new(G + up * 0.2) * CFrame.Angles(0, w.a + r * 0.3, 0) * CFrame.new(0, 0, -radius) * (w.rune and CFrame.Angles(0, math.rad(45), 0) or CFrame.identity)
				w.part.Transparency = r < 1.5 and math.clamp(0.1 + r / 1.5 * 0.9, 0, 1) or 1
			end
			-- steam out of the vents, then the petals fold open (fast at first, a little past, settling back)
			local vent = e(T, IMPACT_AT + 0.3, IMPACT_AT + 0.6) * (1 - e(T, PETALS_FROM + 0.8, PETALS_FROM + 1.6))
			for _, em in ipairs(steam) do
				em.Rate = 30 * vent
			end
			local o = math.clamp((T - PETALS_FROM) / T_PETALS, 0, 1)
			local open = 0
			if o > 0 then
				local eased = 1 - (1 - o) ^ 3
				open = eased + math.sin(o * math.pi) * 0.04
			end
			pod.place(podBase, open, 1 - 0.5 * o)
			pod.light.Brightness = 3 * smooth(o * 2) * (1 - 0.6 * o)
			pod.inner.Transparency = 0.2 + 0.8 * o
			for _, port in ipairs(pod.ports) do
				port.Transparency = math.clamp(r / 1.5, 0, 1)
			end
		end

		-- the name and the class once he is out; his line
		local nameK = e(T, PETALS_FROM + T_PETALS * 0.6, PETALS_FROM + T_PETALS + 0.4)
		for _, l in ipairs({ nameLbl, classLbl }) do
			l.TextTransparency = 1 - nameK
			l.TextStrokeTransparency = 1 - nameK
		end
		local elapsed = T - VOICE_AT
		if not absorbStart and elapsed >= 0 and elapsed < VOICE_LENGTH + 0.65 then
			local visible = 0
			for _, ph in ipairs(PHRASES) do
				visible += math.floor(ph.count * math.clamp((elapsed - ph.at) / ph.reveal, 0, 1))
			end
			line.MaxVisibleGraphemes = visible
			subs.GroupTransparency = smooth((elapsed - VOICE_LENGTH - 0.45) / 0.2)
			subs.Visible = true
		else
			subs.Visible = false
		end

		-- ── Camera ──────────────────────────────────────────
		local camPos, camLook, fov
		if absorbStart then
			local mid = charFeet:Lerp(G, 0.45)
			local k = smooth((T - absorbStart) / 0.7)
			camPos = lastCamPos:Lerp(mid + right * 20 - dir * 3 + up * 6, k)
			camLook = lastCamLook:Lerp(mid + up * 3, k)
			fov = 60
		elseif T < LASER_FROM then
			-- the bait: the grave arrives, then the side view of the necromancer working on it
			local fromStart = smooth(T / 0.8)
			local k = smooth((T - 1.1) / 0.9)
			local arrive = G - dir * 16 + right * 6 + up * 7
			camPos = startCam.Position:Lerp(arrive, fromStart):Lerp(camChannel, k)
			camLook = (startCam.Position + startCam.LookVector * 20):Lerp(G + up * 2.4, fromStart):Lerp(channelLook, k)
			fov = 62 - 4 * k
		elseif T < TEAR_FROM then
			-- the laser: down low behind them, following the red line up into the sky
			local k = smooth((T - LASER_FROM) / 1.6)
			camPos = camChannel:Lerp(camLow, k)
			local up1 = smooth((T - LASER_FROM - 0.8) / 2.2)
			camLook = channelLook:Lerp(G + up * 1, k):Lerp(G:Lerp(laserFrom, 0.35), up1 * 0.6)
			fov = 58 + 8 * k
		elseif T < RELEASE_AT then
			-- the tear and the bow: looking up past the necromancer into the sky, slowly pushing in; the look slides
			-- from the portal to the bow as it comes out
			local k = smooth((T - TEAR_FROM) / 2.5)
			local laserLook = G:Lerp(laserFrom, 0.21)
			local skyLook = portalPos:Lerp(bowTip, 0.55 * smooth((T - EMERGE_FROM) / (EMERGE_TO - EMERGE_FROM)))
			camLook = laserLook:Lerp(skyLook, k)
			local push = smooth((T - TEAR_FROM) / (RELEASE_AT - TEAR_FROM))
			camPos = camLow + dir * 2.5 * push - up * 0.4 * push
			fov = 66 + 8 * k - 6 * push
			if T >= EMERGE_FROM and T < EMERGE_TO then
				shakeAmount, shakeStart = math.max(shakeAmount * math.exp(-dt * 4), 0.05), os.clock()
			end
		elseif not impacted then
			-- the fall: a long lens near the ground off to the side, keeping the pod big in the frame
			local f = math.clamp((T - RELEASE_AT) / T_FALL, 0, 1)
			local podPos = podPosition(f * f) + up * (POD_HEIGHT * 0.5)
			camPos = camLong + up * 6 * (1 - f)
			camLook = podPos
			local dist = (podPos - camPos).Magnitude
			fov = math.clamp(math.deg(2 * math.atan((POD_HEIGHT * 3.2) / (2 * dist))), 14, 60)
		elseif T < CRANE_FROM then
			-- the impact, then the hero shot on him in the open pod
			local k = smooth((T - IMPACT_AT) / 2.4)
			local afterImpact = G - dir * 20 + right * 14 + up * 6
			camPos = afterImpact:Lerp(camHero, k)
			local orbit = math.max(0, T - IMPACT_AT - 2.4) * 0.05
			camPos = G + CFrame.Angles(0, -orbit, 0) * (camPos - G)
			camLook = (G + up * 5):Lerp(G + up * heroLookY, k)
			fov = 70 + (HERO_FOV - 70) * k
		else
			-- the crane: back and up behind the necromancer, so he, the pod and the ship sliding back into the portal
			-- are all in the frame
			local k = smooth((T - CRANE_FROM) / 3.2)
			local orbit = (CRANE_FROM - IMPACT_AT - 2.4) * 0.05
			local hero = G + CFrame.Angles(0, -orbit, 0) * (camHero - G)
			camPos = hero:Lerp(camCrane, k)
			camLook = (G + up * heroLookY):Lerp(G:Lerp(portalPos, 0.42), k)
			fov = HERO_FOV + (64 - HERO_FOV) * k
		end
		if not absorbStart then
			lastCamPos, lastCamLook = camPos, camLook
		end
		local shake = shakeAmount * math.exp(-(os.clock() - shakeStart) * (impacted and 3 or 6))
		local jitter = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 2 * shake
		if camera.CameraType ~= Enum.CameraType.Scriptable then
			camera.CameraType = Enum.CameraType.Scriptable
		end
		camera.CFrame = CFrame.lookAt(camPos + jitter, camLook + jitter * 0.5)
		camera.FieldOfView = fov
	end)
	return true
end

return SovereignArrival
