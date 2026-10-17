-- "A Sight Beyond the Grave": Veyr's pull cinematic (docs/veyr.md, "Pull cinematic"). SovereignArrival hands a pull to
-- it when Veyr is the Sovereign pulled (SovereignArrival.ARRIVALS), for the puller and for spectators alike.
--
--   local started = VeyrArrival.play(results, opts, shared)
--     results, opts: as SovereignArrival.play (graveType, onDone, speed, spectate)
--     shared:        SovereignArrival (its active / spectating flags, so only one arrival runs per client)
--     returns false (and does nothing) when it cannot play: no grave model, no Veyr model, no character, or a cinematic runs.
--
-- What you see (about 30 s, built slow on purpose):
--   1. Bait: the grave rises and shakes like a hand-opened one ... then it freezes. Silence.
--   2. Already aimed: a small blue-violet sight opens over the grave. Far off and high up, a slim dark opening tears in
--      the air and a cold glint shows in it: something there has already aimed at this spot. A long lens finds his
--      echo, a spectral copy of him, the rifle laid on the grave.
--   3. The field: glint after glint opens in the dark all round the plot, a ring of his echoes, and every one lays a
--      faint line on the grave.
--   4. The corridor: six sights open one after another along the line from his muzzle down into the grave; the camera
--      rides the line back to the grave.
--   5. The shot (the echo fires his real basic shot, VeyrShot), and every echo in the field fires with him; their rounds
--      break apart in flight, only his is real. It crosses every sight, impact frames, the grave bursts (the real
--      GraveOpening). He shot his own grave open. The echoes fade, the opening closes.
--   6. The breach: a narrow shadow slit opens in the ground, low violet fog; skeletal hands claw up out of it and pull it
--      open; his eyes first, then he rises out of it, floating, the rifle already up. His eyes ignite: a ring of light
--      rolls over the ground, his mantle is thrown out like wings, his shards click into place one by one.
--      As he comes out he speaks (a demonic undead voice): "Death is just the distance between us."
--   7. Settle: the last sight shrinks round his muzzle, he works the bolt once; a glassy tink as the line ends.
--   8. Hero shot, name. Continue: the usual absorb. Continue: the usual absorb.
-- Everything stays within ~300 studs of the camera (what low graphics quality still draws).
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
local CinematicGuard = require(script.Parent.CinematicGuard)
local VeyrSights = require(script.Parent.VeyrSights)
local Units = require(ReplicatedStorage.Shared.Units)
local VeyrTimeline = require(ReplicatedStorage.Shared.VeyrTimeline)

local player = Players.LocalPlayer

local VeyrArrival = {}

-- ============================================================
-- Settings
-- ============================================================
local GRAVE_SCALE = 1.5
local GRAVE_DISTANCE = 16
local PROP_TAG = "ProceduralUnit"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"

-- his palette (VeyrShot's base palette): blue-violet soul light, a pale core, deep violet, near black; blue eyes
local VIOLET = Color3.fromRGB(118, 86, 255)
local CORE = Color3.fromRGB(205, 196, 255)
local DEEP = Color3.fromRGB(64, 40, 190)
local DARK = Color3.fromRGB(16, 12, 26)
local WHITE = Color3.fromRGB(250, 248, 255)
local EYE = Color3.fromRGB(140, 200, 255)

-- where his echo aims from: ECHO_OUT beyond the grave (seen from the necromancer), ECHO_UP above it, ECHO_SIDE across
local ECHO_OUT = 150
local ECHO_UP = 46
local ECHO_SIDE = 22
local ECHO_SIZE = 1.6 -- (times his normal scale: readable that far away)
local NEARBY_HIDE = 45 -- (studs round the grave) the army's units there are hidden on this screen while it plays
local SIGHTS = 6 -- the corridor
local SIGHT_RADIUS = 3

-- ── Timeline (s) ──────────────────────────────────────────
local START_SILENCE = 2.6 -- the grave freezes
local SIGHT_AT = 3.2 -- the small sight over the grave
local RIFT_FROM, RIFT_TO = 4.4, 5.6 -- the slim dark opening far away
local GLINT_AT = 6.0 -- the scope glint in it
local LENS_FROM = 7.0 -- the long lens on the echo
local FIELD_FROM = 8.4 -- a field of glints opens in the dark all round the plot, a ring of his echoes ...
local FIELD_STEP = 0.07
local FIELD_LOCK = 10.4 -- ... and every one lays a faint line on the grave
local FIELDS = 26
local FIELD_R0, FIELD_R1 = 105, 165 -- (studs from the grave)
local CORRIDOR_FROM = 11.8 -- the sights open one after another ...
local CORRIDOR_STEP = 0.45
local RIDE_FROM, RIDE_TO = 11.8, 15.0 -- (the camera rides the line back to the grave)
local SHOT_AT = 15.8 -- the echo fires (VeyrTimeline.FIRE into his shot), and every echo in the field with him
-- (IMPACT_AT follows from the distance: VeyrTimeline.ROUND_SPEED)
local BREACH_DELAY = 1.0 -- the slit opens this long after the impact
local HAND_DELAY = 0.3 -- (after the breach) skeletal hands claw up out of the slit and pull it open
local HANDS = 4
local EYES_DELAY = 1.6 -- (after the breach) his eyes in the slit
local RISE_DELAY = 2.4 -- (after the breach) he rises ...
local T_RISE = 4.2
local SETTLE_DELAY = 1.4 -- (after the rise) the last sight shrinks round the muzzle
local BOLT_DELAY = 1.3 -- (after the settle) he works the bolt
local VOICE_LEAD = 1.5 -- his line starts this long before he is fully out of the slit
local ORBIT_DELAY = 1.0 -- (after his line starts) the camera starts revolving round him into the hero shot
local ORBIT_BLEND = 2.2
local ORBIT_SPEED = 0.12 -- rad/s once it is going
local VOICE_LENGTH = 4.68 -- (sounds/veyr/voice_arrival.ogg; the second phrase at 2.65 s)
local ABSORB_TIME = 1.9
local BONE = Color3.fromRGB(206, 198, 180)

local PHRASES = {
	{ at = 0, text = "DEATH IS JUST ", reveal = 1.8 },
	{ at = 2.65, text = "THE DISTANCE BETWEEN US.", reveal = 1.8 },
}

local function smooth(x)
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end
local function e(T, a, b)
	return smooth((T - a) / (b - a))
end
local function backOut(k)
	k = math.clamp(k, 0, 1)
	local s = 1.7
	k -= 1
	return 1 + k * k * ((s + 1) * k + s)
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

-- a star-shaped glint that stays the same size on screen (a scope catching the light)
local function makeGlint(parent, px)
	local holder = newPart(parent, Vector3.one * 0.2, CFrame.new(0, -5000, 0), WHITE, Enum.Material.SmoothPlastic)
	holder.Transparency = 1
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(px or 160, px or 160)
	gui.LightInfluence = 0
	gui.Adornee = holder
	gui.Parent = holder
	local bits = {}
	local function bar(w, h, color)
		local f = Instance.new("Frame")
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Position = UDim2.fromScale(0.5, 0.5)
		f.Size = UDim2.fromScale(w, h)
		f.BackgroundColor3 = color
		f.BorderSizePixel = 0
		f.BackgroundTransparency = 1
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = f
		f.Parent = gui
		table.insert(bits, { frame = f, w = w, h = h })
		return f
	end
	bar(0.28, 0.28, VIOLET)
	bar(1, 0.035, CORE)
	bar(0.035, 0.7, CORE)
	bar(0.1, 0.1, WHITE)
	local g = { part = holder }
	function g.set(pos, alpha, size)
		holder.CFrame = CFrame.new(pos)
		for i, b in ipairs(bits) do
			b.frame.Size = UDim2.fromScale(b.w * size, b.h * size)
			b.frame.BackgroundTransparency = 1 - alpha * (i == 1 and 0.5 or 1)
		end
		gui.Enabled = alpha > 0.01
	end
	return g
end

-- a stripped copy of his model, ready to be animated (UnitAnimator / MarksmanAnimator via the tag)
local function cloneUnit(template, scale)
	local m = template:Clone()
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BaseScript") or d:IsA("Humanoid") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = false
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
		end
	end
	m:ScaleTo(scale)
	local root = m.PrimaryPart or m:FindFirstChild("HumanoidRootPart", true)
	if root then
		root.Anchored = true
	end
	m:SetAttribute("AttackStyle", nil)
	m:SetAttribute("State", "idle")
	return m
end

-- a skeletal hand and forearm: palm, two forearm bones, four fingers and a thumb of jointed bones
local FINGERS = {
	{ x = -0.3, yaw = 0.12, lens = { 0.42, 0.32, 0.24 } },
	{ x = -0.1, yaw = 0.03, lens = { 0.48, 0.36, 0.26 } },
	{ x = 0.1, yaw = -0.03, lens = { 0.46, 0.34, 0.25 } },
	{ x = 0.3, yaw = -0.12, lens = { 0.38, 0.28, 0.22 } },
	{ x = 0.42, yaw = -0.8, z = 0.25, lens = { 0.36, 0.28 } }, -- (the thumb)
}
local function buildHand(parent, s)
	local function bone(size)
		local p = Instance.new("Part")
		p.Size = size * s
		p.Color = BONE
		p.Material = Enum.Material.SmoothPlastic
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Transparency = 1
		p.Parent = parent
		return p
	end
	local h = { s = s, palm = bone(Vector3.new(0.8, 0.18, 0.85)), arm = { bone(Vector3.new(0.14, 0.14, 2.4)), bone(Vector3.new(0.12, 0.12, 2.4)) }, fingers = {} }
	for i, f in ipairs(FINGERS) do
		h.fingers[i] = {}
		for k, len in ipairs(f.lens) do
			h.fingers[i][k] = bone(Vector3.new(0.13, 0.13, len))
		end
	end
	return h
end
-- cf: the palm (-Z = the fingers, +Y = the back of the hand); curl 0 open .. 1 a claw
local function placeHand(h, cf, curl, alpha)
	local s = h.s
	local t = 1 - alpha
	h.palm.CFrame = cf
	h.palm.Transparency = t
	for i, b in ipairs(h.arm) do
		b.CFrame = cf * CFrame.new((i == 1 and -0.16 or 0.16) * s, 0, (0.42 + 1.2) * s)
		b.Transparency = t
	end
	for i, f in ipairs(FINGERS) do
		local c = cf * CFrame.new(f.x * s, 0, -(f.z or 0.42) * s) * CFrame.Angles(0, f.yaw, 0)
		for k, len in ipairs(f.lens) do
			c = c * CFrame.Angles(-curl * (k == 1 and 0.55 or 1.05), 0, 0)
			local part = h.fingers[i][k]
			part.CFrame = c * CFrame.new(0, 0, -len * s / 2)
			part.Transparency = t
			c = c * CFrame.new(0, 0, -len * s)
		end
	end
end

local function attachmentPos(model, name)
	local rifle = model and model:FindFirstChild("RifleRoot", true)
	local att = rifle and rifle:FindFirstChild(name)
	return att and att.WorldPosition
end

-- ============================================================
-- Play
-- ============================================================
function VeyrArrival.play(results, opts, shared)
	opts = opts or {}
	local spectate = opts.spectate -- { G, dir, feet, startAt } (another player's arrival)
	local template = GraveOpening.template(opts.graveType)
	local unitModels = ReplicatedStorage:FindFirstChild("UnitModels")
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local camera = Workspace.CurrentCamera

	-- Veyr among the results
	local best
	for _, r in ipairs(results or {}) do
		if r.unitType == "Veyr" then
			best = r
			break
		end
	end
	local unitTemplate = best and unitModels and unitModels:FindFirstChild(best.unitType)
	if spectate then
		if shared.active or shared.spectating or not template or not unitTemplate or not camera then
			return false
		end
	else
		if shared.spectating then
			shared.spectating.stop() -- (their own pull wins over watching someone else's)
		end
		if shared.active or SignatureDescent.active or FleetStrike.active or not template or not unitTemplate
			or not hrp or not camera then
			return false
		end
		shared.active = true
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
	local dir, right, G
	local lookDir = Vector3.new(0, 0, -1)
	if spectate then
		G, dir = spectate.G, spectate.dir
		right = Vector3.new(-dir.Z, 0, dir.X)
	else
		local flatLook = Vector3.new(hrp.CFrame.LookVector.X, 0, hrp.CFrame.LookVector.Z)
		lookDir = flatLook.Magnitude > 0.1 and flatLook.Unit or lookDir
	end
	for _, degrees in ipairs(spectate and {} or { 0, 45, -45, 90, -90, 135, -135, 180 }) do
		local a = math.rad(degrees)
		local d = Vector3.new(lookDir.X * math.cos(a) - lookDir.Z * math.sin(a), 0, lookDir.X * math.sin(a) + lookDir.Z * math.cos(a))
		local r = Vector3.new(-d.Z, 0, d.X)
		local hit = Workspace:Raycast(hrp.Position + d * GRAVE_DISTANCE + up * 20, Vector3.new(0, -60, 0), rayParams)
		if hit and hit.Normal.Y > 0.9 and hit.Position.Y < hrp.Position.Y - 1.5 and hit.Position.Y > hrp.Position.Y - 6 then
			local g = hit.Position
			local eye = g + up * 3
			local echo = g + d * ECHO_OUT + r * ECHO_SIDE + up * ECHO_UP
			if viewIsClear(eye, g - d * 16 + r * 6 + up * 7) and viewIsClear(eye, echo) then
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
	fxFolder.Name = "VeyrArrivalFX"
	fxFolder.Parent = Workspace

	-- the army's units round the grave are hidden on this screen while it plays (they stood in the camera's way): a
	-- unit is a block straight under Workspace named after its unit (Army), its model inside
	local hiddenParts, hiddenLabels = {}, {}
	do
		local seen = {}
		for _, part in ipairs(Workspace:GetPartBoundsInRadius(G, NEARBY_HIDE)) do
			local top = part
			while top.Parent and top.Parent ~= Workspace do
				top = top.Parent
			end
			if not seen[top] and top.Parent == Workspace and top:IsA("BasePart") and not top:IsA("Terrain") and Units.Stats[top.Name] then
				seen[top] = true
				for _, d in ipairs(top:GetDescendants()) do
					if d:IsA("BasePart") and d.LocalTransparencyModifier < 1 then
						d.LocalTransparencyModifier = 1
						table.insert(hiddenParts, d)
					elseif d:IsA("BillboardGui") and d.Enabled then
						d.Enabled = false
						table.insert(hiddenLabels, d)
					end
				end
				if top:IsA("BasePart") and top.LocalTransparencyModifier < 1 then
					top.LocalTransparencyModifier = 1
					table.insert(hiddenParts, top)
				end
			end
		end
	end

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

	-- ── The line of the shot: from his echo far away down into the grave ──
	local def = Units.Stats[best.unitType]
	local unitScale = def and (def.size.X / 2 * 0.9) or 1
	local rootHeight = (unitTemplate:GetAttribute("RootHeight") or 2.2) * unitScale
	local unitTall = (unitTemplate:GetAttribute("Height") or 6) * unitScale
	local aimPoint = G + up * 1.5
	local echoPos = G + dir * ECHO_OUT + right * ECHO_SIDE + up * ECHO_UP
	local lineDir = (aimPoint - echoPos).Unit
	local lineFlat = Vector3.new(lineDir.X, 0, lineDir.Z).Unit
	local flight = (aimPoint - echoPos).Magnitude / VeyrTimeline.ROUND_SPEED
	local IMPACT_AT = SHOT_AT + flight
	local BREACH_FROM = IMPACT_AT + BREACH_DELAY
	local EYES_AT = BREACH_FROM + EYES_DELAY
	local RISE_FROM = BREACH_FROM + RISE_DELAY
	local RISE_TO = RISE_FROM + T_RISE
	local SETTLE_AT = RISE_TO + SETTLE_DELAY
	local BOLT_AT = SETTLE_AT + BOLT_DELAY
	local TINK_AT = BOLT_AT + (VeyrTimeline.BOLT_TO - VeyrTimeline.BOLT_FROM)
	local NAME_AT = TINK_AT + 0.2
	local VOICE_AT = RISE_TO - VOICE_LEAD -- (the user: he speaks as he comes out of the grave)
	local ORBIT_AT = VOICE_AT + ORBIT_DELAY
	local HANDS_FROM = BREACH_FROM + HAND_DELAY
	local PULL_FROM, PULL_TO = HANDS_FROM + 1.1, HANDS_FROM + 2.1 -- (the hands pull the slit open)
	local IGNITE_AT = RISE_TO - 0.3 -- his eyes ignite: a ring of light over the ground, the mantle thrown out like wings
	local SHARDS_AT = IGNITE_AT + 0.6 -- the shards click into place one by one
	local HOLD_AT = math.max(VOICE_AT + VOICE_LENGTH, TINK_AT) + 1.2 -- Continue

	-- the server clock of this cinematic's T = 0 (his model's ShotAt is server time)
	local serverStart = spectate and spectate.startAt or Workspace:GetServerTimeNow()
	local function serverAt(T)
		return serverStart + T
	end

	-- ── The small sight over the grave ───────────────────────
	local graveSight = VeyrSights.build(fxFolder, 2.2, VIOLET, CORE)
	local graveSightCF = CFrame.lookAt(aimPoint + up * 1.7, aimPoint + up * 1.7 + lineDir)

	-- ── The slim dark opening far away, and his echo in it ───
	local riftCF = CFrame.lookAt(echoPos - lineFlat * 2.5, echoPos - lineFlat * 2.5 + lineFlat)
	local RIFT_TALL = 22
	local rift = newPart(fxFolder, Vector3.new(0.1, RIFT_TALL, 0.2), riftCF, DARK, Enum.Material.SmoothPlastic)
	rift.Transparency = 1
	local riftEdges = {}
	for _, side in ipairs({ -1, 1 }) do
		local p = newPart(fxFolder, Vector3.new(0.18, RIFT_TALL, 0.25), riftCF, VIOLET)
		p.Transparency = 1
		table.insert(riftEdges, { part = p, side = side })
	end
	local riftLight = Instance.new("PointLight")
	riftLight.Color = VIOLET
	riftLight.Range = 30
	riftLight.Brightness = 0
	riftLight.Shadows = false
	riftLight.Parent = rift

	local echo = cloneUnit(unitTemplate, unitScale * ECHO_SIZE)
	echo:PivotTo(CFrame.lookAt(echoPos, Vector3.new(aimPoint.X, echoPos.Y, aimPoint.Z)))
	-- a ghost: dark cloth and metal, his own neon kept, a violet outline
	local echoParts = {}
	for _, d in ipairs(echo:GetDescendants()) do
		if d:IsA("BasePart") then
			if d.Material ~= Enum.Material.Neon then
				d.Color = DARK
				d.Material = Enum.Material.SmoothPlastic
			end
			table.insert(echoParts, { part = d, base = d.Transparency < 1 and math.max(d.Transparency, d.Material == Enum.Material.Neon and 0 or 0.3) or 1 })
			d.Transparency = 1
		elseif d:IsA("Decal") or d:IsA("Texture") then
			d.Transparency = 1
		elseif d:IsA("ParticleEmitter") or d:IsA("Light") then
			d.Enabled = false
		end
	end
	local echoOutline = Instance.new("Highlight")
	echoOutline.FillTransparency = 1
	echoOutline.OutlineColor = VIOLET
	echoOutline.OutlineTransparency = 1
	echoOutline.DepthMode = Enum.HighlightDepthMode.Occluded
	echoOutline.Parent = echo
	echo:SetAttribute("AimPos", aimPoint)
	echo:SetAttribute("ShotAt", serverAt(0) - VeyrTimeline.SETTLE_END - 0.5) -- (held at aim from the start)
	echo.Parent = fxFolder
	CollectionService:AddTag(echo, PROP_TAG)
	local echoAlpha = -1
	local function setEchoAlpha(a)
		if math.abs(a - echoAlpha) < 0.01 then
			return
		end
		echoAlpha = a
		for _, ep in ipairs(echoParts) do
			ep.part.Transparency = ep.base + (1 - ep.base) * (1 - a)
		end
		echoOutline.OutlineTransparency = 1 - a * 0.6
	end
	local glint = makeGlint(fxFolder)

	-- ── The corridor of sights, and the faint line through them ──
	local corridor = {}
	for k = 1, SIGHTS do
		table.insert(corridor, { sight = VeyrSights.build(fxFolder, SIGHT_RADIUS, VIOLET, CORE), f = k / (SIGHTS + 1), at = CORRIDOR_FROM + (k - 1) * CORRIDOR_STEP })
	end
	local guide = newPart(fxFolder, Vector3.new(0.08, 0.08, 1), CFrame.new(G), CORE)
	guide.Transparency = 1
	local muzzleFrom -- (the echo's muzzle, taken as the corridor opens)

	-- ── The field of echoes: glints all round the plot (the same layout on every screen: seeded by the grave's spot) ──
	local field = {}
	local rng = Random.new(math.floor(G.X * 7 + G.Z * 13) % 1000003)
	local order = {}
	for k = 1, FIELDS do
		order[k] = k
	end
	for k = FIELDS, 2, -1 do
		local j = rng:NextInteger(1, k)
		order[k], order[j] = order[j], order[k]
	end
	for k = 1, FIELDS do
		local a = (k / FIELDS) * math.pi * 2 + rng:NextNumber(-0.12, 0.12)
		local pos = G + Vector3.new(math.cos(a), 0, math.sin(a)) * rng:NextNumber(FIELD_R0, FIELD_R1) + up * rng:NextNumber(18, 60)
		local f = { pos = pos, at = FIELD_FROM + (order[k] - 1) * FIELD_STEP, glint = makeGlint(fxFolder, 90),
			line = newPart(fxFolder, Vector3.new(0.06, 0.06, 1), CFrame.new(G), CORE),
			round = newPart(fxFolder, Vector3.new(0.3, 0.3, 4), CFrame.new(G), CORE),
			breakAt = rng:NextNumber(0.4, 0.8), flight = (aimPoint - pos).Magnitude / VeyrTimeline.ROUND_SPEED }
		f.line.Transparency = 1
		f.round.Transparency = 1
		field[k] = f
	end
	local fieldSparksAt = newPart(fxFolder, Vector3.one * 0.2, CFrame.new(G), WHITE, Enum.Material.SmoothPlastic)
	fieldSparksAt.Transparency = 1
	local fieldSparks = Instance.new("ParticleEmitter")
	fieldSparks.Texture = SPARKLE
	fieldSparks.Color = ColorSequence.new(CORE, VIOLET)
	fieldSparks.LightEmission = 1
	fieldSparks.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(1, 0) })
	fieldSparks.Lifetime = NumberRange.new(0.4, 0.9)
	fieldSparks.Speed = NumberRange.new(6, 18)
	fieldSparks.SpreadAngle = Vector2.new(180, 180)
	fieldSparks.Drag = 2
	fieldSparks.Enabled = false
	fieldSparks.Parent = fieldSparksAt

	-- ── The hands that pull the slit open ──
	local hands = {}
	for j = 1, HANDS do
		hands[j] = { hand = buildHand(fxFolder, 1.35), side = j % 2 == 0 and 1 or -1, along = (j <= 2 and -1.5 or 1.5) + (j % 3) * 0.3,
			t0 = 0 }
	end

	-- ── The ring of light when his eyes ignite ──
	local igniteRing = {}
	for k = 0, 47 do
		local p = newPart(fxFolder, Vector3.new(1, 0.12, 0.4), CFrame.new(G), k % 6 == 0 and CORE or VIOLET)
		p.Transparency = 1
		igniteRing[k + 1] = { part = p, a = k / 48 * math.pi * 2 }
	end

	-- ── The impact: dust and sparks ──────────────────────────
	local dust = newPart(fxFolder, Vector3.one * 0.3, CFrame.new(G + up * 0.5), VIOLET, Enum.Material.SmoothPlastic)
	dust.Transparency = 1
	local dustEm = Instance.new("ParticleEmitter")
	dustEm.Texture = SMOKE
	dustEm.Color = ColorSequence.new(Color3.fromRGB(120, 110, 135), Color3.fromRGB(60, 52, 76))
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
	sparks.Color = ColorSequence.new(CORE, VIOLET)
	sparks.LightEmission = 1
	sparks.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) })
	sparks.Lifetime = NumberRange.new(0.8, 1.6)
	sparks.Speed = NumberRange.new(20, 40)
	sparks.SpreadAngle = Vector2.new(80, 80)
	sparks.Acceleration = Vector3.new(0, -30, 0)
	sparks.Rate = 0
	sparks.EmissionDirection = Enum.NormalId.Top
	sparks.Parent = dust

	-- ── The breach: a narrow shadow slit across the view, low fog ──
	local SLIT_LENGTH = 7
	local slitCF = CFrame.lookAt(G + up * 0.08, G + up * 0.08 + right) -- (its length runs across the view)
	local slit = newPart(fxFolder, Vector3.new(0.05, 0.1, SLIT_LENGTH), slitCF, DARK, Enum.Material.SmoothPlastic)
	slit.Transparency = 1
	local slitEdges = {}
	for _, side in ipairs({ -1, 1 }) do
		local p = newPart(fxFolder, Vector3.new(0.14, 0.12, SLIT_LENGTH), slitCF, VIOLET)
		p.Transparency = 1
		table.insert(slitEdges, { part = p, side = side })
	end
	local slitLight = Instance.new("PointLight")
	slitLight.Color = VIOLET
	slitLight.Range = 16
	slitLight.Brightness = 0
	slitLight.Shadows = false
	slitLight.Parent = slit
	local fog = Instance.new("ParticleEmitter")
	fog.Texture = SMOKE
	fog.Color = ColorSequence.new(Color3.fromRGB(70, 50, 120), Color3.fromRGB(26, 18, 44))
	fog.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 3), NumberSequenceKeypoint.new(1, 9) })
	fog.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.25, 0.55), NumberSequenceKeypoint.new(1, 1) })
	fog.Lifetime = NumberRange.new(3, 4.5)
	fog.Speed = NumberRange.new(2, 5)
	fog.SpreadAngle = Vector2.new(180, 8)
	fog.Drag = 1.2
	fog.RotSpeed = NumberRange.new(-15, 15)
	fog.LightEmission = 0.15
	fog.Rate = 0
	fog.EmissionDirection = Enum.NormalId.Top
	fog.Parent = slit
	local wisps = Instance.new("ParticleEmitter")
	wisps.Texture = SPARKLE
	wisps.Color = ColorSequence.new(CORE, VIOLET)
	wisps.LightEmission = 1
	wisps.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0) })
	wisps.Lifetime = NumberRange.new(1.5, 2.5)
	wisps.Speed = NumberRange.new(2, 5)
	wisps.SpreadAngle = Vector2.new(15, 15)
	wisps.Rate = 0
	wisps.EmissionDirection = Enum.NormalId.Top
	wisps.Parent = slit

	-- ── Veyr himself (out of the slit from RISE_FROM on) ─────
	local landPivot = CFrame.lookAt(G + up * rootHeight, G + up * rootHeight - dir)
	local belowPivot = landPivot - up * (unitTall + 3)
	local unit, eyeLight, eyeBase
	local muzzleSight = VeyrSights.build(fxFolder, 1, VIOLET, CORE)
	local function spawnUnit()
		unit = cloneUnit(unitTemplate, unitScale)
		unit:PivotTo(belowPivot)
		-- the rifle laid over the necromancer's shoulder, out past them
		unit:SetAttribute("AimPos", G - dir * 60 + right * 7 + up * 5)
		unit:SetAttribute("ShotAt", Workspace:GetServerTimeNow() - VeyrTimeline.SETTLE_END - 0.2) -- (already up, held)
		unit:SetAttribute("ShardsGatherAt", serverAt(SHARDS_AT)) -- (MarksmanAnimator: they circle wide, then click in)
		local head = unit:FindFirstChild("Head", true)
		local att = head and head:FindFirstChild("EyeLight")
		eyeLight = att and att:FindFirstChildWhichIsA("Light")
		eyeBase = eyeLight and eyeLight.Brightness
		unit.Parent = fxFolder
		CollectionService:AddTag(unit, PROP_TAG)
	end

	-- ── Take over camera, controls and the UI (like The Descent) ──
	local saved, controls, hiddenGuis
	local function takeOver()
		CinematicGuard.claim("VeyrArrival")
		saved = { cameraType = camera.CameraType, fov = camera.FieldOfView, guiEnabled = mainGui.Enabled }
		pcall(function()
			controls = require(player.PlayerScripts:WaitForChild("PlayerModule", 2)):GetControls()
			controls:Disable()
		end)
		mainGui.Enabled = false
		hiddenGuis = {}
		for _, g in ipairs(player:WaitForChild("PlayerGui"):GetChildren()) do
			if g:IsA("ScreenGui") and g.Enabled and g.Name ~= "Freecam" and g.Name ~= "VeyrArrivalUI" and g.Name ~= "ArrivalWatchUI" then
				g.Enabled = false
				table.insert(hiddenGuis, g)
			end
		end
		camera.CameraType = Enum.CameraType.Scriptable
	end
	local function giveBack()
		if not saved then
			return
		end
		camera.CameraType = saved.cameraType == Enum.CameraType.Scriptable and Enum.CameraType.Custom or saved.cameraType
		camera.FieldOfView = saved.fov
		mainGui.Enabled = saved.guiEnabled
		for _, g in ipairs(hiddenGuis) do
			if g.Parent then
				g.Enabled = true
			end
		end
		if controls then
			pcall(function() controls:Enable() end)
		end
		saved = nil
		CinematicGuard.release("VeyrArrival")
	end
	if not spectate then
		takeOver()
	end
	local characterHidden = false
	local function hideCharacter(hidden)
		if spectate or hidden == characterHidden then
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
	local charFeet, savedAnchored, ritual
	if spectate then
		charFeet = spectate.feet
	else
		local charHum = hrp.Parent and hrp.Parent:FindFirstChildOfClass("Humanoid")
		charFeet = hrp.Position - Vector3.new(0, (charHum and charHum.HipHeight or 2) + hrp.Size.Y / 2, 0)
		savedAnchored = hrp.Anchored
		hrp.CFrame = CFrame.lookAt(hrp.Position, Vector3.new(G.X, hrp.Position.Y, G.Z))
		hrp.Anchored = true
		local graveTarget = newPart(fxFolder, Vector3.one * 0.3, CFrame.new(G + up * 2), VIOLET, Enum.Material.SmoothPlastic)
		graveTarget.Transparency = 1
		ritual = NecroRitual.new({ hrp = hrp, folder = fxFolder, target = graveTarget, smokeAt = graveTarget, feet = charFeet, color = VIOLET })
		-- the other players see it too (the server checks it against the Sovereign just pulled)
		local started = ReplicatedStorage:FindFirstChild("ArrivalStarted")
		if started then
			started:FireServer({ G = G, dir = dir, feet = charFeet })
		end
	end

	local ui = Instance.new("ScreenGui")
	ui.Name = "VeyrArrivalUI"
	ui.ResetOnSpawn = false
	ui.IgnoreGuiInset = true
	ui.DisplayOrder = 100
	ui.Enabled = not spectate -- (spectators: only while watching)
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
	flash.BackgroundColor3 = CORE
	flash.BackgroundTransparency = 1
	flash.BorderSizePixel = 0
	flash.ZIndex = 5
	flash.Parent = ui
	-- the impact frames: a white frame, then a black one (like his finisher)
	local impactFrame = Instance.new("Frame")
	impactFrame.Size = UDim2.fromScale(1, 1)
	impactFrame.BorderSizePixel = 0
	impactFrame.Visible = false
	impactFrame.ZIndex = 7
	impactFrame.Parent = ui
	-- the name and the class over the top bar's edge (the subtitles take the bottom)
	local nameLbl = Instance.new("TextLabel")
	nameLbl.AnchorPoint = Vector2.new(0.5, 0)
	nameLbl.Position = UDim2.new(0.5, 0, 0.13, 26)
	nameLbl.Size = UDim2.fromOffset(900, 72)
	nameLbl.BackgroundTransparency = 1
	nameLbl.Font = Enum.Font.Sarpanch
	nameLbl.TextSize = 62
	nameLbl.TextColor3 = CORE
	nameLbl.TextStrokeColor3 = Color3.new(0, 0, 0)
	nameLbl.TextTransparency = 1
	nameLbl.TextStrokeTransparency = 1
	nameLbl.Text = best.unitType .. (def and def.title and (" - " .. def.title) or "") -- ("Veyr - The Last Sight")
	nameLbl.ZIndex = 6
	nameLbl.Parent = ui
	local classLbl = nameLbl:Clone()
	classLbl.Position = UDim2.fromScale(0.5, 0.13)
	classLbl.Size = UDim2.fromOffset(700, 26)
	classLbl.TextSize = 20
	classLbl.Font = Enum.Font.RobotoMono
	classLbl.TextColor3 = VIOLET
	local oneIn = best.oneIn and (tostring(math.floor(best.oneIn)):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")) or nil
	classLbl.Text = string.upper(best.rarity or "") .. "  SOVEREIGN" .. (oneIn and ("  -  1 IN " .. oneIn) or "")
	classLbl.Parent = ui
	-- his line: the same subtitle layout as Malak's, in his colours
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
	speaker.Text = "VEYR"
	speaker.TextColor3 = Color3.fromRGB(170, 155, 230)
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
	line.TextColor3 = Color3.fromRGB(232, 228, 245)
	line.TextScaled = true
	line.TextWrapped = true
	line.MaxVisibleGraphemes = 0
	line.ZIndex = 10
	line.Parent = subs
	local lineSize = Instance.new("UITextSizeConstraint")
	lineSize.MaxTextSize = 30
	lineSize.Parent = line
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(8, 5, 14)
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
		text = spectate and "Leave" or "Skip", color = "stone", size = UDim2.fromOffset(120, 40),
		position = UDim2.new(1, -24, 1, -20), anchor = Vector2.new(1, 1), zIndex = 8,
	})
	local continueBtn = Theme.stoneButton(ui, {
		text = "Continue", size = UDim2.fromOffset(180, 48),
		position = UDim2.new(0.5, 0, 1, -8), anchor = Vector2.new(0.5, 1), zIndex = 8,
	})
	continueBtn.root.Visible = false

	-- ── State ────────────────────────────────────────────────
	local T = 0
	local endTime = spectate and (HOLD_AT + 1.5) or math.huge
	local watching = not spectate
	local voiceSfx -- his line (only while watching: a late Watch joins it mid-line, Leave stops it)
	local function volume()
		return watching and 1 or shared.SPECTATOR_VOLUME
	end
	local absorbStart
	local done = false
	local connection, keyConn
	local rumbleSfx, humSfx
	local shakeAmount, shakeStart = 0, 0
	local flashStart
	local silenced, impacted, shotStarted, risen, bolted, echoHeld = false, false, false, false, false, false
	local ignited = false
	local lastFlare = -1
	local cues = {}
	local function cue(name, at, vol, pitch)
		table.insert(cues, { name = name, at = at, volume = vol, pitch = pitch })
	end
	cue("veyr_ring", SIGHT_AT, 1.4, 1.3)
	cue("veyr_rift", RIFT_FROM - 0.6) -- (it builds up into the opening)
	cue("veyr_glint", GLINT_AT, 1.4)
	for k = 1, SIGHTS do
		cue("veyr_ring", CORRIDOR_FROM + (k - 1) * CORRIDOR_STEP, 1.2, 1.0 + k * 0.08)
	end
	cue("veyr_charge", SHOT_AT - 2.2)
	cue("veyr_crack", SHOT_AT)
	cue("gate_collapse", IMPACT_AT, 0.6, 1.15)
	cue("veyr_impact", IMPACT_AT, 1.6, 0.7)
	cue("tear_rumble", BREACH_FROM, 0.7, 0.8)
	cue("portal_snap", IMPACT_AT + 1.4, 0.5, 1.2) -- (the far opening closes)
	cue("veyr_bolt", BOLT_AT)
	cue("veyr_ring", TINK_AT, 1.8, 1.8) -- the glassy tink as the bolt closes
	for k = 1, FIELDS, 3 do
		cue("veyr_glint", FIELD_FROM + (k - 1) * FIELD_STEP, 0.6, 0.9 + (k % 5) * 0.06)
	end
	cue("veyr_claws", HANDS_FROM + 0.2) -- (the hands claw up and grip the edges)
	cue("tear_rumble", PULL_FROM, 0.6, 0.7) -- (and tear the slit open)
	cue("veyr_ignite", IGNITE_AT) -- his eyes ignite
	cue("veyr_cloth", IGNITE_AT + 0.1) -- (the mantle flares out)
	for k = 0, 5 do
		cue("veyr_ring", SHARDS_AT + k * 0.28, 1.0, 1.2 + k * 0.1) -- (each shard clicks in)
	end


	local function startFlash(seconds, transparency)
		flashStart = { at = os.clock(), length = seconds }
		flash.BackgroundTransparency = transparency or 0
	end

	local watchUi
	local function finish()
		if done then
			return
		end
		done = true
		for _, s in pairs({ rumbleSfx, humSfx }) do
			s.stop(0.2)
		end
		if connection then connection:Disconnect() end
		if keyConn then keyConn:Disconnect() end
		grave.stop()
		CollectionService:RemoveTag(echo, PROP_TAG)
		if unit then
			CollectionService:RemoveTag(unit, PROP_TAG)
		end
		fxFolder:Destroy()
		for _, d in ipairs(hiddenParts) do
			if d.Parent then
				d.LocalTransparencyModifier = 0
			end
		end
		for _, d in ipairs(hiddenLabels) do
			if d.Parent then
				d.Enabled = true
			end
		end
		ui:Destroy()
		if watchUi then
			watchUi:Destroy()
		end
		giveBack()
		if voiceSfx and voiceSfx.Parent then
			voiceSfx:Destroy()
		end
		if spectate then
			shared.spectating = nil
		else
			hideCharacter(false)
			ritual.restore()
			if hrp.Parent then
				hrp.Anchored = savedAnchored
			end
			shared.active = false
		end
		if opts.onDone then
			opts.onDone()
		end
	end
	-- spectators: Watch takes over the camera, Leave gives it back (Watch stays there until the end)
	local watchBtn
	if spectate then
		watchUi = Instance.new("ScreenGui")
		watchUi.Name = "ArrivalWatchUI"
		watchUi.ResetOnSpawn = false
		watchUi.DisplayOrder = 99
		watchUi.Parent = player:WaitForChild("PlayerGui")
		watchBtn = Theme.stoneButton(watchUi, {
			text = "Watch", size = UDim2.fromOffset(150, 44),
			position = UDim2.new(0.5, 0, 0, 122), anchor = Vector2.new(0.5, 0), zIndex = 8,
		})
		watchBtn.button.Activated:Connect(function()
			if watching or done or shared.active or SignatureDescent.active or FleetStrike.active
				or not CinematicGuard.claim("VeyrArrival") then
				return
			end
			watching = true
			startCam = camera.CFrame
			takeOver()
			ui.Enabled = true
			watchBtn.root.Visible = false
		end)
		skipBtn.button.Activated:Connect(function()
			if not watching then
				return
			end
			watching = false
			ui.Enabled = false
			giveBack()
			watchBtn.root.Visible = true
		end)
		shared.spectating = { stop = finish }
	else
		skipBtn.button.Activated:Connect(finish)
	end
	local function continue()
		if spectate then
			return
		end
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

	-- the cameras
	local camChannel = charFeet - dir * 3 + right * 11 + up * 4
	local channelLook = charFeet:Lerp(G, 0.5) + up * 3
	if not viewIsClear(camChannel, channelLook) then
		camChannel = charFeet - dir * 3 - right * 11 + up * 4
	end
	local camLow = charFeet - dir * 8 - right * 3.5 + up * 2.2 -- low behind the necromancer, looking past the grave up at the echo
	local camLens = charFeet - dir * 2 - right * 2 + up * 5 -- the long lens on the echo
	local camBehind = aimPoint - lineFlat * 13 + right * 4 + up * 2 -- next to the grave, looking up the line at the echo
	local HERO_FOV = 50
	local heroLookY = math.max(3, unitTall * 0.55)
	local heroDist = math.max(16, (unitTall * 0.5 + 2) / math.tan(math.rad(HERO_FOV / 2)) * 1.25)
	local camHero = G - dir * heroDist - right * 5 + up * math.max(3, unitTall * 0.35)
	local camSlit = G - dir * 9 + right * 4 + up * 1.3 -- low and close on the slit
	local lastCamPos, lastCamLook = camChannel, channelLook
	-- the rise and the revolving hero shot
	local function orbitCam(T)
		-- he rises: looking up at him from low, slowly pushing in ...
		local k = smooth((T - RISE_FROM) / (RISE_TO - RISE_FROM))
		local camPos = camSlit:Lerp(G - dir * 13 + right * 5 + up * 1.2, k)
		local camLook = (G + up * 0.5):Lerp(G + up * heroLookY, k)
		local fov = 52 + 4 * k
		-- ... and while he is still speaking the camera starts revolving round him into the hero shot
		if T >= ORBIT_AT then
			local b = smooth((T - ORBIT_AT) / ORBIT_BLEND)
			local o = T - ORBIT_AT
			-- (the turn eases in over the blend, then keeps a steady speed)
			local orbit = ORBIT_SPEED * (o < ORBIT_BLEND and o * o / (2 * ORBIT_BLEND) or o - ORBIT_BLEND / 2)
			local hero = G + CFrame.Angles(0, orbit, 0) * (camHero - G)
			camPos = camPos:Lerp(hero, b)
			camLook = camLook:Lerp(G + up * heroLookY, b)
			fov = fov + (HERO_FOV - fov) * b
		end
		return camPos, camLook, fov
	end

	-- ── Per-frame ────────────────────────────────────────────
	local speed = opts.speed or 1
	connection = RunService.RenderStepped:Connect(function(realDt)
		if done then
			return
		end
		local dt = realDt * speed
		if spectate then
			T = math.max(0, Workspace:GetServerTimeNow() - spectate.startAt)
		else
			T += dt
		end
		if spectate then
			-- (no ritual for the other players)
		elseif absorbStart then
			hideCharacter(false)
			if ritual.absorb((T - absorbStart) / ABSORB_TIME, unit) then
				unit = nil
				startFlash(0.4, 0.4)
			end
		else
			-- the bait (they work on the grave), then they stop and look up at the far opening, then at him
			local weight = smooth((T - 0.9) / 0.6) * (1 - smooth((T - START_SILENCE) / 0.5))
			local p = math.clamp((T - 1.1) / (START_SILENCE - 1.1), 0, 1)
			ritual.update(weight, p * p * 0.6, "forward")
			local lookAt = T < IMPACT_AT and echoPos or G + up * math.min(unitTall * 0.8, 1 + (T - RISE_FROM) * 1.5)
			ritual.look(lookAt, smooth((T - START_SILENCE - 0.4) / 1.2))
			-- hidden while the camera stands where they are (the long lens)
			hideCharacter(T >= LENS_FROM - 0.1 and T < RIDE_FROM)
		end
		if T >= endTime then
			finish()
			return
		end
		if not spectate and T >= HOLD_AT and endTime == math.huge and not continueBtn.root.Visible then
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
					Sfx.play(c.name, nil, (c.volume or 1) * volume(), c.pitch)
				end
			end
		end
		if watching and not voiceSfx and T >= VOICE_AT and T < VOICE_AT + VOICE_LENGTH - 0.3 then
			voiceSfx = Sfx.play("voice_veyr_arrival", nil, 1, nil, T - VOICE_AT)
		elseif voiceSfx and not watching then
			if voiceSfx.Parent then
				voiceSfx:Destroy()
			end
			voiceSfx = nil
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
			grave.setGlow(VIOLET, p * p * 0.5)
			shakeAmount, shakeStart = 0.04 + 0.1 * p, os.clock()
		elseif not silenced then
			silenced = true
			rumbleSfx.stop(0.04)
			model:PivotTo(rest)
			grave.setGlow(VIOLET, 0)
			shakeAmount = 0
		end

		-- ── 2. The small sight over the grave (blown away by the round) ──
		local gsOpen = backOut((T - SIGHT_AT) / 0.7)
		local gsAlpha = e(T, SIGHT_AT, SIGHT_AT + 0.4) * (1 - e(T, IMPACT_AT, IMPACT_AT + 0.3))
		if gsAlpha > 0 then
			local blown = e(T, IMPACT_AT, IMPACT_AT + 0.3)
			local spin = T < GLINT_AT and (T - SIGHT_AT) * 0.8 or (GLINT_AT - SIGHT_AT) * 0.8
			VeyrSights.place(graveSight, graveSightCF, math.max(0.01, gsOpen * (1 + blown * 1.5)), gsAlpha, spin)
		else
			VeyrSights.hide(graveSight)
		end

		-- ── The far opening and the echo in it ──
		local riftOpen = e(T, RIFT_FROM, RIFT_TO) * (1 - e(T, IMPACT_AT + 0.6, IMPACT_AT + 1.6))
		if riftOpen > 0 then
			local w = 0.1 + 3.6 * riftOpen
			local tall = RIFT_TALL * (0.4 + 0.6 * e(T, RIFT_FROM, RIFT_FROM + 0.6)) * (0.3 + 0.7 * riftOpen)
			rift.Size = Vector3.new(w, tall, 0.2)
			rift.CFrame = riftCF
			rift.Transparency = 0.05
			for _, edge in ipairs(riftEdges) do
				edge.part.Size = Vector3.new(0.18, tall, 0.25)
				edge.part.CFrame = riftCF * CFrame.new(edge.side * w / 2, 0, 0)
				edge.part.Transparency = 1 - riftOpen * (0.75 + 0.2 * math.sin(T * 9 + edge.side))
			end
			riftLight.Brightness = 2 * riftOpen
		else
			rift.Transparency = 1
			for _, edge in ipairs(riftEdges) do
				edge.part.Transparency = 1
			end
			riftLight.Brightness = 0
		end
		if not echoHeld and T >= RIFT_FROM then
			-- (held at aim again as he appears: a held rifle lowers VeyrTimeline.HOLD s after his last shot)
			echoHeld = true
			echo:SetAttribute("ShotAt", serverAt(RIFT_FROM) - VeyrTimeline.SETTLE_END - 0.2)
		end
		setEchoAlpha(e(T, RIFT_TO - 0.3, LENS_FROM + 0.4) * (1 - e(T, IMPACT_AT + 0.3, IMPACT_AT + 1.9)))
		-- his real basic shot, on the cinematic's clock: the rings at his muzzle, the blast, the round (VeyrShot)
		if not shotStarted and T >= SHOT_AT - VeyrTimeline.FIRE then
			shotStarted = true
			echo:SetAttribute("ShotImpact", serverAt(IMPACT_AT))
			echo:SetAttribute("ShotAt", serverAt(SHOT_AT - VeyrTimeline.FIRE))
		end
		-- the glint: once as he is found, a twinkle as he fires
		local scope = attachmentPos(echo, "ScopeLens") or echoPos
		local glintA = math.max(e(T, GLINT_AT, GLINT_AT + 0.12) * (1 - e(T, GLINT_AT + 0.25, GLINT_AT + 1.4)),
			0.35 * e(T, GLINT_AT + 0.6, GLINT_AT + 1.4) * (1 - e(T, SHOT_AT - 0.2, SHOT_AT)),
			e(T, SHOT_AT - 0.35, SHOT_AT - 0.1) * (1 - e(T, SHOT_AT, SHOT_AT + 0.3)))
		local glintS = 0.5 + 0.5 * math.max(1 - math.abs(T - GLINT_AT - 0.15) * 3, 0) + 0.06 * math.sin(T * 11)
		glint.set(scope, glintA, glintS)

		-- ── 3. The corridor of sights ──
		if T >= CORRIDOR_FROM - 0.05 and not muzzleFrom then
			muzzleFrom = attachmentPos(echo, "Muzzle") or echoPos
		end
		local from = muzzleFrom or echoPos
		local corridorDir = (aimPoint - from).Unit
		for k, c in ipairs(corridor) do
			local open = backOut((T - c.at) / 0.55)
			local passAt = SHOT_AT + flight * c.f
			local passed = T - passAt
			local alpha = e(T, c.at, c.at + 0.25) * (passed > 0 and (1 - math.clamp(passed / 0.4, 0, 1)) or 1)
			if alpha > 0 and T >= c.at then
				local pos = from:Lerp(aimPoint, c.f)
				local locked = math.clamp((T - (SHOT_AT - 0.8)) / 0.4, 0, 1)
				local spin = (k % 2 == 0 and -1 or 1) * (math.min(T, SHOT_AT - 0.8) - c.at) * 0.9
				local scale = math.max(0.01, open * (passed > 0 and (1 + passed * 2.5) or 1) * (1 - 0.1 * locked))
				VeyrSights.place(c.sight, CFrame.lookAt(pos, pos + corridorDir), scale, alpha, spin)
				if passed > 0 and passed < 0.15 then
					VeyrSights.tint(c.sight, WHITE, WHITE)
				elseif passed >= 0.15 and not c.retinted then
					c.retinted = true
					VeyrSights.tint(c.sight, VIOLET, CORE)
				end
			else
				VeyrSights.hide(c.sight)
			end
		end
		local guideA = e(T, CORRIDOR_FROM + SIGHTS * CORRIDOR_STEP, SHOT_AT - 0.5) * (1 - e(T, SHOT_AT, SHOT_AT + 0.1))
		if guideA > 0 then
			local len = (aimPoint - from).Magnitude
			guide.Size = Vector3.new(0.08, 0.08, len)
			guide.CFrame = CFrame.lookAt((from + aimPoint) / 2, aimPoint)
			guide.Transparency = 1 - 0.3 * guideA
		else
			guide.Transparency = 1
		end

		-- ── The field: the glints pop up all round, lay their lines on the grave, fire with him; their rounds break
		-- apart in flight (only his is real) and the echoes fade
		for _, f in ipairs(field) do
			local pop = e(T, f.at, f.at + 0.1)
			local ga = math.max(pop * (1 - 0.45 * e(T, f.at + 0.15, f.at + 0.6)),
				e(T, SHOT_AT - 0.15, SHOT_AT - 0.02) * (1 - e(T, SHOT_AT + 0.05, SHOT_AT + 0.3))) * (1 - e(T, SHOT_AT + 0.3, SHOT_AT + 1.0))
			f.glint.set(f.pos, ga, 0.5 + 0.5 * math.max(0, 1 - math.abs(T - f.at - 0.05) * 6) + 0.05 * math.sin(T * 9 + f.at * 20))
			local la = e(T, FIELD_LOCK + f.at - FIELD_FROM, FIELD_LOCK + f.at - FIELD_FROM + 0.3) * (1 - e(T, SHOT_AT, SHOT_AT + 0.15))
			if la > 0 then
				local len = (aimPoint - f.pos).Magnitude
				f.line.Size = Vector3.new(0.06, 0.06, len)
				f.line.CFrame = CFrame.lookAt((f.pos + aimPoint) / 2, aimPoint)
				f.line.Transparency = 1 - 0.22 * la
			else
				f.line.Transparency = 1
			end
			local fr = (T - SHOT_AT) / f.flight
			if fr >= 0 and fr < f.breakAt then
				local at = f.pos:Lerp(aimPoint, fr)
				f.round.CFrame = CFrame.lookAt(at, aimPoint)
				f.round.Transparency = 0.1
			elseif fr >= f.breakAt and not f.broken then
				f.broken = true
				f.round.Transparency = 1
				fieldSparksAt.CFrame = CFrame.new(f.pos:Lerp(aimPoint, f.breakAt))
				fieldSparks:Emit(14)
			end
		end

		-- ── 4. Impact: he shot his own grave open ──
		if not impacted and T >= IMPACT_AT then
			impacted = true
			model:PivotTo(rest)
			grave.burst(VIOLET, 1)
			startFlash(0.8, 0.3)
			shakeAmount, shakeStart = 2.4, os.clock()
			dustEm:Emit(70)
			sparks:Emit(60)
		end
		local sinceImpact = T - IMPACT_AT
		if sinceImpact >= 0 and sinceImpact < 0.2 then
			impactFrame.Visible = true
			impactFrame.BackgroundColor3 = sinceImpact < 0.07 and WHITE or Color3.new(0, 0, 0)
		else
			impactFrame.Visible = false
		end

		-- ── 5. The breach, his eyes, the rise ──
		local slitOpen = e(T, BREACH_FROM, BREACH_FROM + 1.2) * (1 - e(T, RISE_TO + 1, RISE_TO + 3))
		-- (a crack first, then the hands tear it open)
		local slitW = (0.5 * e(T, BREACH_FROM, BREACH_FROM + 0.6) + 2.6 * e(T, PULL_FROM, PULL_TO)) * (1 - e(T, RISE_TO + 1, RISE_TO + 3))
		if slitOpen > 0 then
			local w = math.max(0.05, slitW)
			slit.Size = Vector3.new(math.max(0.05, w), 0.1, SLIT_LENGTH * (0.5 + 0.5 * slitOpen))
			slit.Transparency = 0
			for _, edge in ipairs(slitEdges) do
				edge.part.Size = Vector3.new(0.14, 0.12, slit.Size.Z)
				edge.part.CFrame = slitCF * CFrame.new(edge.side * w / 2, 0, 0)
				edge.part.Transparency = 1 - slitOpen * (0.7 + 0.2 * math.sin(T * 7 + edge.side))
			end
			slitLight.Brightness = 3 * slitOpen
			fog.Rate = 22 * slitOpen
			wisps.Rate = 12 * slitOpen
		else
			slit.Transparency = 1
			for _, edge in ipairs(slitEdges) do
				edge.part.Transparency = 1
			end
			slitLight.Brightness = 0
			fog.Rate = 0
			wisps.Rate = 0
		end
		if not unit and not absorbStart and T >= EYES_AT - 0.5 and not risen then
			risen = true
			spawnUnit()
		end
		if unit and not absorbStart then
			-- up out of the slit: the head (and his eyes) first, slow, easing into his float
			local k = e(T, RISE_FROM, RISE_TO)
			local peek = 0.18 * e(T, EYES_AT, EYES_AT + 0.8) -- (just the eyes above the ground first)
			local rise = math.max(peek, k)
			local pivot = belowPivot:Lerp(landPivot, rise)
			unit:PivotTo(pivot)
		end

		-- the hands: up out of the slit, fingers trembling, then they grip its edges and tear it open; they sink back as
		-- he rises
		local outward = slitCF.RightVector
		for j, h in ipairs(hands) do
			local t0 = HANDS_FROM + (j - 1) * 0.18
			local sinkFrom = RISE_FROM + 0.6 + j * 0.1
			local alpha = e(T, t0, t0 + 0.15) * (1 - e(T, sinkFrom + 0.7, sinkFrom + 1.0))
			if alpha > 0 then
				local upK = e(T, t0, t0 + 0.6)
				local grab = e(T, t0 + 0.55, t0 + 0.9)
				local sink = e(T, sinkFrom, sinkFrom + 1.0)
				local out = outward * h.side
				local edge = (slitCF * CFrame.new(h.side * slitW / 2, 0, h.along)).Position
				local p1 = edge - out * 0.3 + up * (-2.8 + 3.3 * upK)
				local p2 = edge + out * 0.3 + up * 0.35
				local emerge = CFrame.lookAt(p1, p1 + up, out)
				local grip = CFrame.lookAt(p2, p2 + out - up * 0.4, up)
				local cf = emerge:Lerp(grip, grab) - up * (3 * sink)
				local curl = 0.12 + 0.1 * math.sin(T * 14 + j) * (1 - grab) + 0.8 * grab * (1 - 0.6 * sink)
				placeHand(h.hand, cf, curl, alpha)
			else
				placeHand(h.hand, CFrame.new(G - up * 20), 0, 0)
			end
		end
		-- his eyes ignite: a flash, a ring of light rolling out over the ground, the mantle thrown out like wings
		if not ignited and T >= IGNITE_AT then
			ignited = true
			if T < IGNITE_AT + 0.5 then
				startFlash(0.35, 0.55)
				shakeAmount, shakeStart = 0.8, os.clock()
			end
		end
		local rk = (T - IGNITE_AT) / 1.5
		for _, r in ipairs(igniteRing) do
			if rk >= 0 and rk < 1 then
				local radius = 2 + 40 * (1 - (1 - rk) ^ 3)
				r.part.CFrame = CFrame.new(G + up * 0.15) * CFrame.Angles(0, r.a + rk * 0.4, 0) * CFrame.new(0, 0, -radius)
				r.part.Size = Vector3.new(2 * math.pi * radius / 48 * 0.8, 0.12, 0.4)
				r.part.Transparency = 0.1 + 0.9 * rk
			else
				r.part.Transparency = 1
			end
		end
		if unit and not absorbStart then
			local flare = e(T, IGNITE_AT, IGNITE_AT + 0.35) * (1 - e(T, IGNITE_AT + 1.6, IGNITE_AT + 3.6))
			if math.abs(flare - lastFlare) > 0.005 then
				lastFlare = flare
				unit:SetAttribute("MantleFlare", flare)
			end
			if eyeLight then
				eyeLight.Brightness = (eyeBase or 1) * (1 + 3 * e(T, EYES_AT, EYES_AT + 0.5) * (1 - e(T, RISE_TO, RISE_TO + 1.5))
					+ 6 * e(T, IGNITE_AT, IGNITE_AT + 0.1) * (1 - e(T, IGNITE_AT + 0.2, IGNITE_AT + 1.2)))
			end
		end

		-- ── 6. Settle: the last sight shrinks round the muzzle, the bolt ──
		local msA = e(T, SETTLE_AT, SETTLE_AT + 0.3) * (1 - e(T, SETTLE_AT + 1.1, SETTLE_AT + 1.4))
		local muzzle = unit and attachmentPos(unit, "Muzzle")
		local ringOrigin = unit and attachmentPos(unit, "RingOrigin")
		if msA > 0 and muzzle and ringOrigin and (muzzle - ringOrigin).Magnitude > 0.01 then
			local shrink = 1 - e(T, SETTLE_AT, SETTLE_AT + 1.3)
			VeyrSights.place(muzzleSight, CFrame.lookAt(muzzle, muzzle + (muzzle - ringOrigin).Unit), 0.35 + 2.4 * shrink, msA, (T - SETTLE_AT) * 2)
		else
			VeyrSights.hide(muzzleSight)
		end
		if unit and not bolted and T >= BOLT_AT then
			bolted = true
			-- (his basic shot's bolt beat: the animator plays it from here)
			unit:SetAttribute("ShotAt", Workspace:GetServerTimeNow() - VeyrTimeline.BOLT_FROM + 0.05)
		end

		-- ── 7. The name and the class once he stands; his line ──
		local nameK = e(T, NAME_AT, NAME_AT + 0.8)
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
		if not watching then
			return -- (a spectator's own camera)
		end
		local camPos, camLook, fov
		if absorbStart then
			local mid = charFeet:Lerp(G, 0.45)
			local k = smooth((T - absorbStart) / 0.7)
			camPos = lastCamPos:Lerp(mid + right * 20 - dir * 3 + up * 6, k)
			camLook = lastCamLook:Lerp(mid + up * 3, k)
			fov = 60
		elseif T < SIGHT_AT then
			-- the bait: the grave arrives, then the side view of the necromancer working on it
			local fromStart = smooth(T / 0.8)
			local k = smooth((T - 1.1) / 0.9)
			local arrive = G - dir * 16 + right * 6 + up * 7
			camPos = startCam.Position:Lerp(arrive, fromStart):Lerp(camChannel, k)
			camLook = (startCam.Position + startCam.LookVector * 20):Lerp(G + up * 2.4, fromStart):Lerp(channelLook, k)
			fov = 62 - 4 * k
		elseif T < RIFT_FROM then
			-- the sight over the grave: closer in on it
			local k = smooth((T - SIGHT_AT) / 1.2)
			camPos = camChannel:Lerp(G - dir * 9 + right * 5 + up * 4, k)
			camLook = channelLook:Lerp(aimPoint + up * 1.7, k)
			fov = 58 - 6 * k
		elseif T < LENS_FROM then
			-- low behind the necromancer: past the grave, up to the far opening
			local k = smooth((T - RIFT_FROM) / 1.4)
			local close = G - dir * 9 + right * 5 + up * 4
			camPos = close:Lerp(camLow, k)
			camLook = (aimPoint + up * 1.7):Lerp(G:Lerp(echoPos, 0.6), k)
			fov = 52 + 14 * k
		elseif T < FIELD_FROM then
			-- the long lens: his echo in the opening, the rifle laid on the grave
			local k = smooth((T - LENS_FROM) / 1.1)
			camPos = camLens
			camLook = G:Lerp(echoPos, 0.6):Lerp(echoPos + up * unitTall * ECHO_SIZE * 0.25, k)
			local dist = (echoPos - camLens).Magnitude
			local tight = math.deg(2 * math.atan((unitTall * ECHO_SIZE * 2.2) / (2 * dist)))
			fov = 66 + (tight - 66) * k
		elseif T < RIDE_FROM then
			-- the field: high over the grave, turning to find glint after glint in the dark all round ...
			local k = smooth((T - FIELD_FROM) / (FIELD_LOCK + 0.3 - FIELD_FROM))
			local base = math.atan2(dir.Z, dir.X)
			local a = base - 1.6 + 3.2 * k
			local pan = G + up * 24 - dir * 4
			local panLook = pan + Vector3.new(math.cos(a), 0, math.sin(a)) * 100 + up * 12
			-- ... then up high, looking down: every line converging on the grave
			local d = smooth((T - FIELD_LOCK) / 1.0)
			local high = G - dir * 30 + right * 8 + up * 55
			camPos = pan:Lerp(high, d)
			camLook = panLook:Lerp(G, d)
			fov = 78 - 8 * d
		elseif T < RIDE_TO then
			-- ride the line back: from beside his echo down the corridor to the grave
			local k = smooth((T - RIDE_FROM) / (RIDE_TO - RIDE_FROM))
			local along = 0.06 + 0.8 * k
			local side = right * 6 + up * 3
			camPos = from:Lerp(aimPoint, along) + side
			camLook = from:Lerp(aimPoint, math.min(1, along + 0.25)) + side * 0.3
			fov = 70
		elseif T < IMPACT_AT + 0.6 then
			-- next to the grave, looking up the line at him: the round comes straight at us
			local k = smooth((T - RIDE_TO) / 0.5)
			camPos = (aimPoint - lineFlat * 6 + right * 6 + up * 3):Lerp(camBehind, k)
			camLook = aimPoint:Lerp(from, 0.5)
			fov = 62
		elseif T < RISE_FROM then
			-- low and close on the slit
			local k = smooth((T - IMPACT_AT - 0.6) / 1.4)
			camPos = camBehind:Lerp(camSlit, k)
			camLook = aimPoint:Lerp(G + up * 0.5, k)
			fov = 62 - 10 * k
		else
			camPos, camLook, fov = orbitCam(T)
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

return VeyrArrival
