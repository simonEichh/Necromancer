-- Orvoss's gate finisher, THE LAST BROADSIDE (docs/orvoss.md "Beat sheet"; timings: shared AdmiralTimeline.FINISHER).
--
--   local started = LastBroadside.play(opts)
--     opts: startAt (server time), unit (his model), gate (Vector3), spectator (another player's), preview (Studio),
--           onDone
--     returns false when it cannot play (no Orvoss of yours, already running, too late to join).
--
-- Started by the SERVER for everyone (Army.checkFinisher; remote LastBroadside): every client plays the world part from
-- the same server time; the owner's camera is taken over (Skip only gives it back), other players see it over the
-- owner's lane and may press Watch (joining late seeks to the shared clock). The server holds the gate and breaks it at
-- GATE_HIT, whatever happens on any screen. The army stands idle (it never flees in this one): on a watcher's screen
-- the owner's units are hidden for the whole finisher (the user's call).
--
-- Built in stages (2026-10-17). STAGE 1: the take-over, the hidden army, every camera shot, the omen (fog rolling
-- down the lane, ship shadows gliding under it, water dripping UP off his coat), the anchor falling out of the clouds
-- beside the gate on its chain. STAGE 2: the sky ocean (a black sea spreading high beyond the gate, tilted towards the
-- battlefield, soul light under it), the fleet breaking out of it bows first with water streaming off them upwards and
-- sailing to their stations (two tiers along the lane's right, broadsides on the gate), the flagship last, crossing in
-- front of him to its station on his left; the ports glowing up deck by deck (loading); everything sails back into
-- the sea and it closes. Next: the travelling broadside, his poses (AdmiralAnimator), the drag and the whirlpool,
-- sounds.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local mainGui = require(script.Parent.Gui)
local Theme = require(script.Parent.Theme)
local CinematicGuard = require(script.Parent.CinematicGuard)
local Sfx = require(script.Parent.Sfx)
local F = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("AdmiralTimeline")).FINISHER

local player = Players.LocalPlayer
local LastBroadside = {}
LastBroadside.active = false
local states = {} -- [his model] = the running finisher (AdmiralAnimator reads it later)

local DURATION = F.END
local BAR_HEIGHT = 0.1
local BAR_TIME = 0.8
local ANCHOR_SCALE = 1.5
local ANCHOR_SIDE = 22 -- studs from the lane's middle, beside the gate
local CHAIN_LINKS = 46
local FOG_BANKS = 6
-- the fleet's stations, farthest first (the travelling broadside fires in this order, the flagship last): the ship,
-- its distance past the gate along the lane, its offset to the lane's right, its height above the floor. Every ship
-- heads back towards him, the way it came out of the sea (no turning round): the fleet on the lane's right shows the
-- lane its starboard, the flagship on his left its port side
local FLEET = {
	{ ship = "ManOWar", along = 560, side = 170, up = 80 },
	{ ship = "Galleon", along = 450, side = 240, up = 165 },
	{ ship = "Frigate", along = 330, side = 165, up = 70 },
	{ ship = "Wreck", along = 220, side = 235, up = 150 },
	{ ship = "Brig", along = 110, side = 160, up = 62 },
}
local FLAGSHIP_STATION = { along = -10, side = -95, up = 52 }
local OCEAN = { along = 520, side = 60, up = 260, radius = 3200 } -- (its centre past the gate, and how far it spreads)
local OCEAN_COLOR = Color3.fromRGB(6, 16, 18)
-- the travelling broadside: s between one fleet ship's volley and the next, how long a ship's stern-to-bow ripple
-- takes, the flagship's; how fast the balls fly; the cracks the hits leave on the gate (at most)
local FLEET_GAP, FLEET_SPAN, FLAG_SPAN = 1.6, 1.5, 2.6
local BALL_SPEED = 240
local GATE_AIM_UP = 15 -- (the ships aim at the gate's face this high above the floor)
local MAX_CRACKS = 70
local PORT_EMBER = Color3.fromRGB(34, 190, 140)
local SHIP_TURN = 0.55 -- (how fast a hull's heading follows its path: slow, they are huge)
local HIDDEN = CFrame.new(0, -5000, 0) -- (where a ship waits before it breaks out of the sea, and after it is back in)
local SOUL_DEEP = Color3.fromRGB(18, 90, 70)
local SOUL = Color3.fromRGB(40, 225, 165)
local CORE = Color3.fromRGB(200, 255, 232)
local FOG = Color3.fromRGB(58, 82, 78) -- (a grey sea-green that reads against the night)
local DUST = Color3.fromRGB(70, 66, 62)
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local SPARK = "rbxasset://textures/particles/sparkles_main.dds"

-- his line (a subtitle only until the voice file exists)
local LINES = {
	{ at = F.ORDER_LINE, length = 2.2, phrases = { { at = 0, text = "GIVE THEM THE DEEP.", reveal = 1.1 } } },
}
for _, l in ipairs(LINES) do
	l.text = ""
	for _, ph in ipairs(l.phrases) do
		ph.count = utf8.len(ph.text)
		l.text ..= ph.text
	end
end

-- one-shot sounds (watchers): the sound slot, when, volume, pitch
local CUES = {
	{ sound = "orvoss_bell", at = F.CALL + 0.3, volume = 1 },
	{ sound = "orvoss_chain", at = F.ANCHOR + 0.2, volume = 0.6, pitch = 0.85 }, -- (the chain rattling as it falls)
	{ sound = "orvoss_anchor", at = F.ANCHOR_HIT - 0.05, volume = 1.3 },
	{ sound = "orvoss_sea", at = F.SEA + 0.2, volume = 1, pitch = 0.8 },
	{ sound = "orvoss_chain", at = F.DRAG, volume = 1.1, pitch = 0.7 }, -- (the chains pulling taut)
	{ sound = "orvoss_sea", at = F.CLOSE, volume = 0.8, pitch = 0.6 },
}
-- the ambience bed under it (watchers): in from the omen, dipping almost to silence for the order, out at the end
local BED = { sound = "orvoss_ambience", from = F.OMEN, to = F.LAND + 2, fadeIn = 3, fadeOut = 3, duck = 0.85 }

local BEATS = {
	{ at = F.CALL, name = "The call" }, { at = F.OMEN, name = "The omen" }, { at = F.ANCHOR, name = "The anchor" },
	{ at = F.SEA, name = "The sea opens" }, { at = F.FLAGSHIP, name = "The flagship" }, { at = F.LINE, name = "Into line" },
	{ at = F.ORDER, name = "The order" }, { at = F.BROADSIDE, name = "The broadside" }, { at = F.FLAG_FIRE, name = "The flagship fires" },
	{ at = F.GATE_HIT, name = "The gate" }, { at = F.DRAG, name = "The drag" }, { at = F.CLOSE, name = "The ocean closes" },
	{ at = F.LAND, name = "The hat" },
}

local function smooth(x)
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end
local function ease(x, a, b)
	return smooth((x - a) / (b - a))
end

local function newPart(folder, size, color, transparency, shape, material)
	local p = Instance.new("Part")
	p.Size = size
	p.Color = color
	p.Transparency = transparency or 0
	p.Material = material or Enum.Material.SmoothPlastic
	if shape then
		p.Shape = shape
	end
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = folder
	return p
end

-- an emitter on an invisible part (part-parented: it emits out of the part's volume towards its front face)
local function emitter(folder, size, props)
	local p = newPart(folder, size, Color3.new(), 1)
	local e = Instance.new("ParticleEmitter")
	e.Rate = 0
	e.EmissionDirection = Enum.NormalId.Front
	for k, v in pairs(props) do
		e[k] = v
	end
	e.Parent = p
	return p, e
end

local function findOrvoss()
	local me = tostring(player.UserId)
	for _, m in ipairs(CollectionService:GetTagged("ProceduralUnit")) do
		if m.Name == "Orvoss" and m.Parent and m:GetAttribute("OwnerId") == me then
			return m
		end
	end
	return nil
end

-- the owner's army (every unit model of theirs but him), to hide on a watcher's screen
local function armyParts(ownerId, except)
	local parts = {}
	for _, d in ipairs(workspace:GetDescendants()) do
		if d:IsA("Model") and d ~= except and d:GetAttribute("AttackCount") ~= nil and d:GetAttribute("OwnerId") == ownerId then
			for _, p in ipairs(d:GetDescendants()) do
				if p:IsA("BasePart") then
					table.insert(parts, p)
				end
			end
		end
	end
	return parts
end

-- ============================================================
-- The world part (everyone sees it, watching or not)
-- ============================================================
local function world(folder, ctx)
	local L = ctx.L
	local fwd, right = L.LookVector, L.RightVector
	local floorY = ctx.floor.Y

	-- ── the omen: banks of black fog rolling from the gate down the lane towards him
	local banks = {}
	for k = 1, FOG_BANKS do
		local along = 1 - (k - 1) / (FOG_BANKS - 1) -- (1 = at the gate, 0 = at him)
		local at = ctx.ground:Lerp(Vector3.new(ctx.gate.X, ctx.ground.Y, ctx.gate.Z), along * 0.95) + Vector3.new(0, 2, 0)
		local p, e = emitter(folder, Vector3.new(46, 2, 16), {
			Texture = SMOKE,
			Color = ColorSequence.new(FOG),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 9), NumberSequenceKeypoint.new(1, 18) }),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0.35), NumberSequenceKeypoint.new(1, 1) }),
			Lifetime = NumberRange.new(4, 6),
			Speed = NumberRange.new(2, 5),
			SpreadAngle = Vector2.new(30, 10),
			Rotation = NumberRange.new(0, 360),
			RotSpeed = NumberRange.new(-10, 10),
			LightInfluence = 0.3,
			LightEmission = 0.15, -- (a faint glow of its own)
		})
		p.CFrame = CFrame.lookAt(at, at - fwd) -- (rolling towards him)
		banks[k] = { e = e, along = along }
	end
	-- ship shadows gliding over the ground under the fog, from the gate past him (a hull: a long body, a pointed bow)
	local shadows = {}
	for k, lat in ipairs({ -16, 6, 22 }) do
		local body = newPart(folder, Vector3.new(16, 0.2, 70), Color3.new(0, 0, 0), 1)
		local bow = newPart(folder, Vector3.new(11.3, 0.2, 11.3), Color3.new(0, 0, 0), 1)
		shadows[k] = { body = body, bow = bow, lat = lat, from = F.OMEN + 0.4 + (k - 1) * 1.3, dur = 4.2 + k * 0.4 }
	end
	-- water dripping UP off his coat
	local dripPart, drips = emitter(folder, Vector3.new(2.6, 4, 2.6) * ctx.scale, {
		Texture = SPARK,
		Color = ColorSequence.new(CORE),
		Size = NumberSequence.new(0.16, 0.05),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) }),
		Lifetime = NumberRange.new(0.8, 1.4),
		Speed = NumberRange.new(1, 3),
		Acceleration = Vector3.new(0, 5, 0),
		Orientation = Enum.ParticleOrientation.VelocityParallel,
		SpreadAngle = Vector2.new(12, 12),
		LightEmission = 1,
	})
	dripPart:FindFirstChildOfClass("ParticleEmitter").EmissionDirection = Enum.NormalId.Top
	-- a soft soul-green light on him for the whole finisher (the scene is a night lane)
	local glow = Instance.new("PointLight")
	glow.Color = SOUL
	glow.Range = 24
	glow.Brightness = 0
	glow.Shadows = false
	glow.Parent = dripPart

	-- ── the anchor: out of the clouds beside the gate on its chain, crown first into the ground
	local anchor, links
	local SM = ReplicatedStorage:FindFirstChild("ShipModels")
	local landAt = Vector3.new(ctx.gate.X, floorY, ctx.gate.Z) + right * ANCHOR_SIDE - fwd * 8
	local anchorH, pitch = 25, 2.56
	if SM and SM:FindFirstChild("BlackwakeAnchor") and SM:FindFirstChild("BlackwakeChainLink") then
		anchor = SM.BlackwakeAnchor:Clone()
		anchor:ScaleTo(ANCHOR_SCALE)
		anchorH = (anchor:GetAttribute("Height") or 25) * ANCHOR_SCALE
		anchor.Parent = folder
		links = {}
		local tpl = SM.BlackwakeChainLink:Clone()
		tpl:ScaleTo(ANCHOR_SCALE)
		pitch = (tpl:GetAttribute("Pitch") or 2.56) * ANCHOR_SCALE
		for k = 1, CHAIN_LINKS do
			local l = tpl:Clone()
			l.Parent = folder
			links[k] = l
		end
		tpl:Destroy()
	end
	-- (landed: tilted a little, the crown sunk into the ground; the ring is the model's origin)
	local tilt = CFrame.fromAxisAngle(fwd, math.rad(9)) * CFrame.fromAxisAngle(right, math.rad(-5))
	local sink = 3
	local ringLanded = landAt + Vector3.new(0, anchorH - 1.8 * ANCHOR_SCALE - sink, 0)
	local yaw = CFrame.fromMatrix(Vector3.zero, right, Vector3.yAxis) -- (its arms across the lane: the stock along it)
	local hitDone = false

	local function anchorCF(T)
		local k = math.clamp((T - F.ANCHOR) / (F.ANCHOR_HIT - F.ANCHOR), 0, 1)
		local drop = (1 - k * k) * 320 -- (falling faster and faster)
		local wobble = (1 - k) * 0.25 * math.sin(T * 3)
		return CFrame.new(ringLanded + Vector3.new(0, drop, 0)) * tilt:Lerp(CFrame.new(), 1 - k) * yaw * CFrame.Angles(0, 0, wobble)
	end

	local function impact()
		ctx.shake = 1.4
		local c = landAt + Vector3.new(0, 1, 0)
		local f = newPart(folder, Vector3.one, CORE, 0, Enum.PartType.Ball, Enum.Material.Neon)
		f.Position = c
		local l = Instance.new("PointLight")
		l.Color = SOUL
		l.Range = 50
		l.Brightness = 5
		l.Parent = f
		local ring = newPart(folder, Vector3.new(0.3, 1, 1), SOUL, 0.3, Enum.PartType.Cylinder, Enum.Material.Neon)
		ring.CFrame = CFrame.new(c - Vector3.new(0, 0.8, 0)) * CFrame.Angles(0, 0, math.pi / 2)
		ctx.ringFx = { f = f, l = l, ring = ring, at = F.ANCHOR_HIT }
		-- (a faint green glow stays round the anchor)
		if anchor and anchor.PrimaryPart then
			local stay = Instance.new("PointLight")
			stay.Color = SOUL
			stay.Range = 30
			stay.Brightness = 0.9
			stay.Shadows = false
			stay.Parent = anchor.PrimaryPart
		end
		-- cracks in the ground round it
		for k = 1, 9 do
			local a = k / 9 * math.pi * 2 + math.random() * 0.4
			local dir = Vector3.new(math.cos(a), 0, math.sin(a))
			local len = 8 + math.random() * 10
			local crack = newPart(folder, Vector3.new(0.6, 0.15, len), Color3.fromRGB(10, 12, 12), 0)
			crack.CFrame = CFrame.lookAt(landAt + dir * (len / 2 + 2) + Vector3.new(0, 0.08, 0), landAt + dir * (len + 2) + Vector3.new(0, 0.08, 0))
			local glow = newPart(folder, Vector3.new(0.2, 0.17, len * 0.8), SOUL, 0.4, nil, Enum.Material.Neon)
			glow.CFrame = crack.CFrame
		end
		local dustP, dust = emitter(folder, Vector3.new(10, 1, 10), {
			Texture = SMOKE,
			Color = ColorSequence.new(DUST),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 6), NumberSequenceKeypoint.new(1, 20) }),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) }),
			Lifetime = NumberRange.new(2, 3.5),
			Speed = NumberRange.new(14, 30),
			SpreadAngle = Vector2.new(80, 80),
			Drag = 2.5,
			Rotation = NumberRange.new(0, 360),
			RotSpeed = NumberRange.new(-20, 20),
			LightInfluence = 0.7,
		})
		dustP.CFrame = CFrame.lookAt(landAt, landAt + Vector3.yAxis)
		dust:Emit(40)
		local sparkP, sparks = emitter(folder, Vector3.new(4, 1, 4), {
			Texture = SPARK,
			Color = ColorSequence.new(CORE, SOUL),
			Size = NumberSequence.new(0.6, 0),
			Lifetime = NumberRange.new(0.4, 0.9),
			Speed = NumberRange.new(30, 60),
			SpreadAngle = Vector2.new(70, 70),
			Acceleration = Vector3.new(0, -40, 0),
			LightEmission = 1,
		})
		sparkP.CFrame = CFrame.lookAt(landAt, landAt + Vector3.yAxis)
		sparks:Emit(60)
	end


	-- ── the sky ocean: a disc of black sea spreading across the sky beyond the gate, tilted towards the battlefield
	local gateFloor = Vector3.new(ctx.gate.X, floorY, ctx.gate.Z)
	local function at(along, side, up)
		return gateFloor + fwd * along + right * side + Vector3.new(0, up, 0)
	end
	local oceanC = at(OCEAN.along, OCEAN.side, OCEAN.up)
	local oceanN = ((ctx.ground + Vector3.new(0, 30, 0)) - oceanC).Unit -- (its face looks at the battlefield)
	local oceanFrame = CFrame.lookAt(oceanC, oceanC + oceanN) -- (-Z out of the sea towards us)
	ctx.oceanC = oceanC
	local function disc(size, color, transparency, offset, material)
		local d = newPart(folder, Vector3.new(0.4, size, size), color, transparency, Enum.PartType.Cylinder, material)
		d.CFrame = oceanFrame * CFrame.new(0, 0, -(offset or 0)) * CFrame.Angles(0, math.pi / 2, 0)
		return d
	end
	local sea = disc(1, OCEAN_COLOR, 1, 0, Enum.Material.Glass)
	sea.Reflectance = 0.15
	-- (a faint, animated spectral sheen on its face: the ForceField material shimmers on its own)
	local sheen = disc(1, SOUL_DEEP, 1, 1, Enum.Material.ForceField)
	local ripples = {}
	local function ripple(pos, T)
		local r = newPart(folder, Vector3.new(0.3, 1, 1), SOUL, 1, Enum.PartType.Cylinder, Enum.Material.Neon)
		r.CFrame = CFrame.lookAt(pos, pos + oceanN) * CFrame.new(0, 0, -3) * CFrame.Angles(0, math.pi / 2, 0)
		table.insert(ripples, { part = r, at = T })
	end

	-- ── the fleet
	local shipsFolder = SM and SM:FindFirstChild("BlackwakeFleet")
	local ships = {}
	local function addShip(name, station, heading, emergeAt, arriveAt, out, fireSide)
		local tpl = shipsFolder and shipsFolder:FindFirstChild(name)
		if not tpl then
			return
		end
		local m = tpl:Clone()
		m.Parent = folder
		local stationCF = CFrame.lookAt(station, station + heading)
		-- at its station the hull turns and rolls so its firing side looks straight at the gate (a ghost ship can list
		-- like that): the shortest turn from that side's outward direction onto the line to the gate's middle
		local outward = stationCF.RightVector * (fireSide or 1)
		local toGate = ((gateFloor + Vector3.new(0, GATE_AIM_UP, 0)) - station).Unit
		local axis = outward:Cross(toGate)
		if axis.Magnitude > 1e-4 then
			local turn = CFrame.fromAxisAngle(axis.Unit, math.acos(math.clamp(outward:Dot(toGate), -1, 1)))
			stationCF = CFrame.new(station) * turn * stationCF.Rotation
		end
		local len = m:GetAttribute("Length") or 160
		-- where it breaks out of the sea: straight back along its heading and up from the station, where that line meets
		-- the surface. It glides out along that straight line, nose a little down, and levels out as it arrives: it never
		-- turns sideways (`out` shifts the exit point across the sea)
		local back = (-heading + Vector3.new(0, 0.45, 0)).Unit
		local denom = back:Dot(oceanN)
		local t = math.abs(denom) > 0.05 and (oceanC - station):Dot(oceanN) / denom or 400
		t = math.clamp(t, 150, 900)
		local exitPos = station + back * t + out
		-- the ports, bow to stern per deck (the travelling broadside lights them in this order)
		local ports = {}
		for _, d in ipairs(m:GetDescendants()) do
			if d.Name == "PortGlow" and d:GetAttribute("Side") == (fireSide or 1) then
				table.insert(ports, d)
			end
		end
		table.sort(ports, function(a, b)
			local ia, ib = a:GetAttribute("Index") or 0, b:GetAttribute("Index") or 0
			if ia ~= ib then
				return ia < ib
			end
			return (a:GetAttribute("Deck") or 0) < (b:GetAttribute("Deck") or 0)
		end)
		local allPorts = {}
		for _, d in ipairs(m:GetDescendants()) do
			if d.Name == "PortGlow" then
				d.Transparency = 0.85 -- (dark until they load)
				table.insert(allPorts, d)
			end
		end
		-- water streaming off the hull upwards as it breaks out
		local streamP, stream = emitter(folder, Vector3.new(len * 0.18, 4, len * 0.8), {
			Texture = SPARK,
			Color = ColorSequence.new(CORE, SOUL),
			Size = NumberSequence.new(1.1, 0.3),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) }),
			Lifetime = NumberRange.new(1.2, 2.2),
			Speed = NumberRange.new(4, 10),
			Acceleration = Vector3.new(0, 14, 0),
			Orientation = Enum.ParticleOrientation.VelocityParallel,
			SpreadAngle = Vector2.new(10, 10),
			LightEmission = 0.8,
		})
		stream.EmissionDirection = Enum.NormalId.Top
		local ship = {
			model = m, station = stationCF, exitPos = exitPos, len = len, emergeAt = emergeAt, arriveAt = arriveAt,
			ports = ports, allPorts = allPorts, stream = stream, streamP = streamP, rippled = false,
			-- the path: from inside the sea (behind the exit point) straight to the station; `via` bends it (the flagship)
			p0 = exitPos + back * len * 0.7, p3 = station,
		}
		table.insert(ships, ship)
		return ship
	end
	for i, f in ipairs(FLEET) do
		local station = at(ctx.laneDist * 0 + f.along, f.side, f.up)
		local emerge = F.SEA + 2 + (i - 1) * 1.0 -- (once the sea has spread wide enough to come out of)
		addShip(f.ship, station, -fwd, emerge, F.LINE + 3 + (i - 1) * 0.4, Vector3.zero)
	end
	-- the flagship: out last, heading towards him; it passes in front of him a little overhead and settles on his left,
	-- still heading the same way (one long, gentle curve; its port side faces the lane and fires)
	local flagStation = at(FLAGSHIP_STATION.along, FLAGSHIP_STATION.side, FLAGSHIP_STATION.up)
	local flagship = addShip("Flagship", flagStation, -fwd, F.FLAGSHIP - 1.5, F.LINE + 5, Vector3.new(0, 0, 0), -1)
	if flagship then
		-- (one gentle bend: out of the sea, over the lane in front of him, then across to his left)
		flagship.via = flagStation + fwd * 140 + right * 55 + Vector3.new(0, 35, 0)
		ctx.flagship = flagship
	end

	-- a point on the ship's path at k (0 = inside the sea, 1 = at its station) and the direction of travel there: a
	-- straight line, or a quadratic curve through `via`
	local function bezier(sh, k)
		if sh.via then
			local u = 1 - k
			local pos = sh.p0 * (u * u) + sh.via * (2 * u * k) + sh.p3 * (k * k)
			local d = (sh.via - sh.p0) * (2 * u) + (sh.p3 - sh.via) * (2 * k)
			return pos, d.Magnitude > 1e-3 and d.Unit or sh.station.LookVector
		end
		local d = sh.p3 - sh.p0
		return sh.p0:Lerp(sh.p3, k), d.Magnitude > 1e-3 and d.Unit or sh.station.LookVector
	end

	local function updateFleet(T, dt)
		-- the sea: spreads open, holds, closes
		local open = ease(T, F.SEA, F.SEA + 4) * (1 - ease(T, F.CLOSE, F.CLOSE + 4))
		local r = OCEAN.radius * math.max(0.001, open)
		sea.Size = Vector3.new(0.4, r * 2, r * 2)
		sea.Transparency = 1 - 0.9 * math.min(1, open * 1.5)
		sheen.Size = Vector3.new(0.4, r * 2, r * 2)
		sheen.Transparency = 1 - 0.6 * math.min(1, open * 1.5)
		for i = #ripples, 1, -1 do
			local rp = ripples[i]
			local k = (T - rp.at) / 2.5
			if k >= 1 then
				rp.part:Destroy()
				table.remove(ripples, i)
			else
				local d = 20 + 260 * (1 - (1 - k) ^ 2)
				rp.part.Size = Vector3.new(0.3, d, d)
				rp.part.Transparency = 0.2 + 0.8 * k
			end
		end
		for _, sh in ipairs(ships) do
			local root = sh.model.PrimaryPart
			if root then
				local cf
				if T < sh.emergeAt or T >= F.CLOSE + 2 then
					cf = HIDDEN -- (not out of the sea yet / back in it)
				elseif T < sh.arriveAt then
					local k = smooth((T - sh.emergeAt) / (sh.arriveAt - sh.emergeAt))
					local pos, dir = bezier(sh, k)
					-- (the bow follows the path, levelling out as it nears its station)
					local level = ease(k, 0.5, 1)
					local target = dir:Lerp(sh.station.LookVector, level).Unit
					sh.look = sh.look and sh.look:Lerp(target, 1 - math.exp(-dt * SHIP_TURN)).Unit or target
					cf = CFrame.lookAt(pos, pos + sh.look)
					-- (it leans into its aim at the gate over the last stretch, so it never snaps into it on arrival)
					cf = cf:Lerp(CFrame.new(pos) * sh.station.Rotation, ease(k, 0.55, 1))
					if not sh.rippled then
						sh.rippled = true
						ripple(sh.exitPos, T)
					end
				elseif T < F.DRAG then
					-- at station: a slow ghostly bob
					local bob = math.sin(T * 0.7 + sh.len) * 1.5
					cf = sh.station * CFrame.new(0, bob, 0) * CFrame.Angles(0, 0, math.sin(T * 0.5 + sh.len) * 0.02)
					sh.look = sh.station.LookVector
				else
					-- back into the sea (the path in reverse, faster)
					local k = 1 - smooth((T - F.DRAG) / (F.CLOSE + 2 - F.DRAG))
					local pos, dir = bezier(sh, k)
					-- (the deep pulls it back stern first: it keeps facing the way it came, never turns round)
					cf = CFrame.new(pos) * sh.station.Rotation -- (and keeps its list)
				end
				root.CFrame = cf
				sh.cf = cf
				-- water streaming off it while it is near the sea
				local near = T >= sh.emergeAt and T < sh.emergeAt + 3.5
				sh.streamP.CFrame = cf * CFrame.Angles(0, 0, 0)
				sh.stream.Rate = near and 120 or 0
				-- the ports load deck by deck while the fleet swings into line (the broadside takes them over)
				if T < F.BROADSIDE then
					local load = ease(T, F.LINE + 1, F.LINE + 5.5)
					for _, pg in ipairs(sh.allPorts) do
						local deck = pg:GetAttribute("Deck") or 1
						local kk = math.clamp(load * 3 - (deck - 1), 0, 1)
						pg.Transparency = 0.85 - 0.6 * kk -- (glowing, not yet firing)
					end
				end
			end
		end
	end


	-- ── the travelling broadside (BROADSIDE .. GATE_HIT): ship after ship, farthest first, each from stern to bow (the
	-- bows point at him, so the wave rolls towards the camera); the flagship last, slower, louder, deeper. A port column
	-- fires as one: its ports flare, a muzzle flash and a puff of smoke at each, one glowing ball per column into the
	-- gate's face (a flash, sparks, dust, a soul-green crack left on the stone)
	local gateFace = Vector3.new(ctx.gate.X, floorY, ctx.gate.Z)
	local volleys = {}
	local order = 0
	for _, sh in ipairs(ships) do
		local columns, maxIdx = {}, 0
		for _, pg in ipairs(sh.ports) do
			local idx = pg:GetAttribute("Index") or 1
			columns[idx] = columns[idx] or {}
			table.insert(columns[idx], pg)
			maxIdx = math.max(maxIdx, idx)
		end
		local isFlag = sh == ctx.flagship
		local start, span = F.FLAG_FIRE, FLAG_SPAN
		if not isFlag then
			start, span = F.BROADSIDE + order * FLEET_GAP, FLEET_SPAN
			order += 1
		end
		local cols = {}
		for idx = maxIdx, 1, -1 do -- (stern first: index 1 is the bow)
			if columns[idx] then
				table.insert(cols, columns[idx])
			end
		end
		for k, col in ipairs(cols) do
			table.insert(volleys, { at = start + (#cols > 1 and (k - 1) / (#cols - 1) or 0) * span, ship = sh, ports = col,
				flag = isFlag, k = k })
		end
	end
	local smokeP, smoke = emitter(folder, Vector3.new(1, 1, 1), {
		Texture = SMOKE,
		Color = ColorSequence.new(Color3.fromRGB(96, 110, 106)),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 3), NumberSequenceKeypoint.new(1, 13) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) }),
		Lifetime = NumberRange.new(1.6, 2.8),
		Speed = NumberRange.new(10, 18),
		Drag = 3,
		SpreadAngle = Vector2.new(14, 14),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-25, 25),
		LightInfluence = 0.6,
	})
	local sparkP, sparks = emitter(folder, Vector3.new(1, 1, 1), {
		Texture = SPARK,
		Color = ColorSequence.new(CORE, SOUL),
		Size = NumberSequence.new(0.7, 0),
		Lifetime = NumberRange.new(0.35, 0.8),
		Speed = NumberRange.new(20, 45),
		SpreadAngle = Vector2.new(70, 70),
		Acceleration = Vector3.new(0, -40, 0),
		LightEmission = 1,
	})
	local dustP, dust = emitter(folder, Vector3.new(1, 1, 1), {
		Texture = SMOKE,
		Color = ColorSequence.new(DUST),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 4), NumberSequenceKeypoint.new(1, 12) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) }),
		Lifetime = NumberRange.new(1.2, 2),
		Speed = NumberRange.new(6, 14),
		SpreadAngle = Vector2.new(60, 60),
		Drag = 2.5,
		Rotation = NumberRange.new(0, 360),
		LightInfluence = 0.7,
	})
	local flashes, balls, flaring = {}, {}, {}
	local cracks = 0
	local function flash(pos, size, color, life, light)
		local f = newPart(folder, Vector3.one * 0.2, color, 0, Enum.PartType.Ball, Enum.Material.Neon)
		f.Position = pos
		local l
		if light then
			l = Instance.new("PointLight")
			l.Color = SOUL
			l.Range = light
			l.Brightness = 4
			l.Shadows = false
			l.Parent = f
		end
		table.insert(flashes, { part = f, light = l, size = size, life = life, t0 = os.clock() })
	end
	local function gateImpact(pos, big)
		local out = -fwd
		flash(pos + out * 1.5, big and 12 or 7, SOUL, 0.45, big and 40 or nil)
		flash(pos + out * 1.8, big and 5 or 3, CORE, 0.2)
		sparkP.CFrame = CFrame.lookAt(pos + out, pos + out * 2)
		sparks:Emit(big and 22 or 10)
		dustP.CFrame = CFrame.lookAt(pos + out, pos + out * 2)
		dust:Emit(big and 6 or 3)
		if cracks < MAX_CRACKS then
			cracks += 1
			local len = 4 + math.random() * 7
			local c = newPart(folder, Vector3.new(0.35, len, 0.25), SOUL, 0.1, nil, Enum.Material.Neon)
			c.CFrame = CFrame.lookAt(pos + out * 0.4, pos) * CFrame.Angles(0, 0, math.random() * math.pi)
		end
		if ctx.watching then
			ctx.shake = math.max(ctx.shake or 0, big and 0.9 or 0.35)
		end
	end
	local function fireVolley(v, T)
		local muzzles = {}
		for _, pg in ipairs(v.ports) do
			if pg.Parent then
				local out = pg.CFrame.RightVector -- (a port's X points out of the hull)
				local m = pg.Position + out * 3.5
				table.insert(muzzles, m)
				pg.Color = CORE
				pg.Transparency = 0
				table.insert(flaring, { part = pg, t0 = T })
				flash(m, v.flag and 6 or 4, CORE, 0.25)
				smokeP.CFrame = CFrame.lookAt(m, m + out)
				smoke:Emit(v.flag and 3 or 2)
			end
		end
		if #muzzles == 0 then
			return
		end
		-- one ball per column, from its middle muzzle into the gate's face
		local from = muzzles[math.ceil(#muzzles / 2)]
		local to = gateFace + right * ((math.random() - 0.5) * 36) + Vector3.new(0, 4 + math.random() * 22, 0)
		local flight = math.clamp((to - from).Magnitude / BALL_SPEED, 0.25, 2)
		local b = newPart(folder, Vector3.one * (v.flag and 2.2 or 1.6), CORE, 0, Enum.PartType.Ball, Enum.Material.Neon)
		b.Position = from
		local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
		a0.Position, a1.Position = Vector3.new(0, 0.7, 0), Vector3.new(0, -0.7, 0)
		a0.Parent, a1.Parent = b, b
		local tr = Instance.new("Trail")
		tr.Attachment0, tr.Attachment1 = a0, a1
		tr.Color = ColorSequence.new(CORE, SOUL)
		tr.Transparency = NumberSequence.new(0.1, 1)
		tr.WidthScale = NumberSequence.new(1, 0)
		tr.Lifetime = 0.35
		tr.LightEmission = 1
		tr.FaceCamera = true
		tr.Parent = b
		table.insert(balls, { part = b, from = from, to = to, t0 = T, t1 = T + flight, big = v.flag })
		-- the report (watchers): every other column of the fleet, every column of the flagship, deeper and louder
		if ctx.watching and (v.flag or v.k % 2 == 1) then
			if v.flag then
				Sfx.play("orvoss_cannon", nil, 1.1, 0.72 + math.random() * 0.08)
			else
				Sfx.play("orvoss_cannon", nil, 0.35 + math.random() * 0.25, 0.88 + math.random() * 0.18)
			end
		end
	end

	local function updateBroadside(T, dt)
		for _, v in ipairs(volleys) do
			if not v.fired and T >= v.at then
				v.fired = true
				if T - v.at < 0.5 then -- (joined late: skip the volleys that are long past)
					fireVolley(v, T)
				end
			end
		end
		local now = os.clock()
		for i = #flashes, 1, -1 do
			local f = flashes[i]
			local k = (now - f.t0) / f.life
			if k >= 1 then
				f.part:Destroy()
				table.remove(flashes, i)
			else
				f.part.Size = Vector3.one * f.size * (0.3 + 0.7 * math.min(1, k / 0.15)) * (1 + 0.3 * k)
				f.part.Transparency = ease(k, 0.15, 1)
				if f.light then
					f.light.Brightness = 4 * (1 - k)
				end
			end
		end
		for i = #balls, 1, -1 do
			local b = balls[i]
			local k = (T - b.t0) / (b.t1 - b.t0)
			if k >= 1 then
				b.part.Transparency = 1
				Debris:AddItem(b.part, 0.4)
				table.remove(balls, i)
				gateImpact(b.to, b.big)
			else
				b.part.Position = b.from:Lerp(b.to, k) -- (straight: the ships aim their broadsides at the gate)
			end
		end
		-- a fired port dies back from a white flare to embers
		for i = #flaring, 1, -1 do
			local f = flaring[i]
			local k = math.clamp((T - f.t0) / 0.7, 0, 1)
			f.part.Color = CORE:Lerp(PORT_EMBER, k)
			f.part.Transparency = 0.45 * k
			if k >= 1 then
				table.remove(flaring, i)
			end
		end
	end

	local function update(T, dt)
		updateFleet(T, dt)
		updateBroadside(T, dt)
		-- the fog front reaches each bank in turn; it lifts at CLOSE
		local front = ease(T, F.OMEN, F.OMEN + 5)
		for _, b in ipairs(banks) do
			local on = front >= (1 - b.along) and T < F.CLOSE
			b.e.Rate = on and 5 or 0
		end
		-- the shadows: sliding from beyond the gate back past him, fading in and out
		for _, s in ipairs(shadows) do
			local k = (T - s.from) / s.dur
			local vis = (k > 0 and k < 1) and math.sin(k * math.pi) or 0
			local along = ctx.laneDist * (1.1 - 1.4 * k)
			local c = Vector3.new(ctx.ground.X, floorY + 0.25, ctx.ground.Z) + fwd * along + right * s.lat
			local cf = CFrame.lookAt(c, c - fwd) -- (sailing towards him: the bow first)
			s.body.CFrame = cf
			s.bow.CFrame = cf * CFrame.new(0, 0, -35) * CFrame.Angles(0, math.rad(45), 0)
			s.body.Transparency = 1 - 0.55 * vis
			s.bow.Transparency = 1 - 0.55 * vis
		end
		-- the drips: from the omen until the sea opens
		local root = ctx.unit.PrimaryPart
		if root then
			dripPart.CFrame = root.CFrame
		end
		drips.Rate = (T >= F.OMEN and T < F.SEA + 3) and 40 or 0
		glow.Brightness = 1.4 * ease(T, 0, 1.5) * (1 - ease(T, F.END - 1.5, F.END))
		-- the anchor and its chain
		if anchor and anchor.PrimaryPart then
			local cf = T < F.ANCHOR and CFrame.new(ringLanded + Vector3.new(0, 400, 0)) or anchorCF(T)
			anchor.PrimaryPart.CFrame = cf
			local ringTop = cf * CFrame.new(0, 1.8 * ANCHOR_SCALE, 0)
			local up = ringTop.UpVector:Lerp(Vector3.yAxis, 0.6).Unit
			for k, l in ipairs(links) do
				local p = ringTop.Position + up * (k - 0.5) * pitch
				-- (the link's long axis Y along the chain; every other one turned a quarter about it)
				l.PrimaryPart.CFrame = CFrame.lookAt(p, p + fwd, up) * CFrame.Angles(0, k % 2 == 0 and 0 or math.pi / 2, 0)
			end
			if T >= F.ANCHOR_HIT and not hitDone then
				hitDone = true
				impact()
			end
		end
		local rf = ctx.ringFx
		if rf then
			local k = (T - rf.at) / 0.9
			if k >= 1 then
				rf.f:Destroy()
				rf.ring:Destroy()
				ctx.ringFx = nil
			else
				rf.f.Size = Vector3.one * (4 + 16 * k)
				rf.f.Transparency = k
				rf.l.Brightness = 5 * (1 - k)
				local r = 4 + 70 * (1 - (1 - k) ^ 3)
				rf.ring.Size = Vector3.new(0.3, r, r)
				rf.ring.Transparency = 0.3 + 0.7 * k
			end
		end
		ctx.shake = math.max(0, (ctx.shake or 0) - dt * 2.2)
	end

	local function cleanup() end
	return update, cleanup
end

-- ============================================================
-- The camera: one shot per beat (cuts between them, slow moves inside)
-- ============================================================
local function cameraAt(T, c)
	local L = c.L
	local fwd, right, up = L.LookVector, L.RightVector, Vector3.yAxis
	local O, G, chest = c.ground, c.gate, c.chestPos
	local D = c.laneDist
	local function shot(from, to)
		return T >= from and T < to, math.clamp((T - from) / (to - from), 0, 1)
	end
	local on, k
	on, k = shot(F.CALL, F.OMEN)
	if on then
		-- close three-quarter on him, low, a slow push in
		local pos = chest + fwd * (8 - 1.5 * k) + right * 5 - up * 1.2
		return pos, chest + up * 1.4, 50
	end
	on, k = shot(F.OMEN, F.ANCHOR)
	if on then
		-- low behind him, down the lane, the fog coming at us
		local pos = O - fwd * (10 - 3 * k) + right * 2.5 + up * 4
		return pos, G + up * 8, 60
	end
	on, k = shot(F.ANCHOR, F.SEA)
	if on then
		-- low in front of the gate, looking up as the anchor drops into frame
		local land = Vector3.new(G.X, O.Y, G.Z) + right * ANCHOR_SIDE - fwd * 8
		local pos = land - fwd * 42 - right * 14 + up * (4 + 1.5 * k)
		return pos, land + up * 18, 64
	end
	on, k = shot(F.SEA, F.FLAGSHIP)
	if on then
		-- a slow tilt up from the gate to the sea in the sky
		local pos = O - fwd * 16 + up * 6 - right * 3
		local look = (G + up * 10):Lerp(c.oceanC or (G + fwd * 140 + up * 160), smooth(math.min(1, k * 1.4)))
		return pos, look, 70
	end
	on, k = shot(F.FLAGSHIP, F.LINE)
	if on then
		-- low three-quarter from behind him, looking up past him at the flagship crossing
		local pos = O - fwd * 9 - right * 7 + up * 1.5
		local target = c.flagship and c.flagship.cf and c.flagship.cf.Position or (O + fwd * 40 + up * 40)
		c.flagLook = c.flagLook and c.flagLook:Lerp(target, 0.06) or target -- (a smooth follow)
		return pos, c.flagLook, 72
	end
	on, k = shot(F.LINE, F.ORDER)
	if on then
		-- behind the near end of the fleet's line, outside the line of fire, looking diagonally along the broadsides
		local pos = G - fwd * 60 + right * 230 + up * (95 + 6 * k)
		return pos, G + fwd * 330 + right * 150 + up * 80, 64
	end
	on, k = shot(F.ORDER, F.BROADSIDE)
	if on then
		-- close and low on him, the flagship behind
		local pos = chest + fwd * (7 - k) - right * 3 - up * 2.5
		return pos, chest + up * (2 + 3 * k), 55
	end
	on, k = shot(F.BROADSIDE, F.FLAG_FIRE)
	if on then
		-- diagonal along the line as the wave comes at us (the same side as the line shot, lower)
		-- (turned enough that the gate stays in the left of the frame: the balls land in shot)
		local pos = G - fwd * 70 + right * 215 + up * (70 - 6 * k)
		return pos, G + fwd * 110 + right * 55 + up * 28, 72
	end
	on, k = shot(F.FLAG_FIRE, F.GATE_HIT)
	if on then
		-- tracking alongside the flagship, outside it on his left, from its stern towards its bow
		local fcf = c.flagship and c.flagship.cf
		if fcf then
			-- (on its FIRING side, its port side on the lane (-RightVector): a little above and outboard of the hull,
			-- sliding from stern to bow and looking along the gun decks as the ports fire)
			local pos = fcf.Position - fcf.RightVector * 55 + fcf.LookVector * (-150 + 160 * k) + up * 30
			return pos, fcf.Position - fcf.RightVector * 12 + fcf.LookVector * (40 + 60 * k), 62
		end
		local pos = O - right * 45 + up * 34 + fwd * (D * (0.1 + 0.35 * k))
		return pos, G + up * 14, 62
	end
	on, k = shot(F.GATE_HIT, F.DRAG + 1.5)
	if on then
		-- wide on the gate
		local pos = G - fwd * 75 + right * 28 + up * 16
		return pos, G + up * 10, 60
	end
	on, k = shot(F.DRAG + 1.5, F.CLOSE)
	if on then
		-- wide from behind him: the fleet dragging the ruins
		local pos = O - fwd * 13 + up * 7 + right * 3
		return pos, G + up * (20 + 30 * k), 64
	end
	on, k = shot(F.CLOSE, F.LAND)
	if on then
		-- a slow pull back
		local pos = O - fwd * (13 + 22 * smooth(k)) + up * (7 + 10 * smooth(k)) + right * 3
		return pos, G + up * 40, 64
	end
	-- the hat: close on him
	k = math.clamp((T - F.LAND) / (F.END - F.LAND), 0, 1)
	local pos = chest + fwd * (6.5 + k) + right * 3 + up * 0.4
	return pos, chest + up * 1.2, 50
end

-- ============================================================
-- Play
-- ============================================================
function LastBroadside.play(opts)
	opts = opts or {}
	if LastBroadside.active then
		return false
	end
	local startAt = opts.startAt or workspace:GetServerTimeNow()
	if workspace:GetServerTimeNow() - startAt >= DURATION - 1 then
		return false -- (too late to join)
	end
	local orvoss = opts.unit
	if not orvoss or not orvoss.Parent then
		orvoss = (not opts.spectator) and findOrvoss() or nil
	end
	if not orvoss or not orvoss.PrimaryPart then
		warn("LastBroadside: no Orvoss in the world")
		return false
	end
	LastBroadside.active = true
	local camera = workspace.CurrentCamera
	local spectator = opts.spectator == true
	local ownerId = orvoss:GetAttribute("OwnerId")

	local root = orvoss.PrimaryPart
	local gate = opts.gate or orvoss:GetAttribute("AimPos") or (root.CFrame * CFrame.new(0, 4, -80)).Position
	local scale = orvoss:GetScale()
	local ground = root.Position - Vector3.new(0, (orvoss:GetAttribute("RootHeight") or 3.7) * scale, 0)
	local L = CFrame.lookAt(ground, Vector3.new(gate.X, ground.Y, gate.Z))
	local ctx = {
		unit = orvoss, gate = gate, ground = ground, L = L, scale = scale, preview = opts.preview == true,
		chestPos = root.Position + Vector3.new(0, 1.6 * scale, 0),
		laneDist = (Vector3.new(gate.X, 0, gate.Z) - Vector3.new(ground.X, 0, ground.Z)).Magnitude,
	}
	do
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { orvoss }
		local hit = workspace:Raycast(root.Position, Vector3.new(0, -60, 0), params)
		ctx.floor = hit and hit.Position or ground
	end
	states[orvoss] = { at = startAt, gate = gate }

	local fxFolder = Instance.new("Folder")
	fxFolder.Name = "LastBroadsideFx_" .. tostring(ownerId or "?") .. "_" .. math.floor(startAt)
	fxFolder.Parent = workspace
	local worldUpdate, worldCleanup = world(fxFolder, ctx)
	-- (client-only, for AdmiralAnimator later: his poses on the same clock)
	orvoss:SetAttribute("FinisherAt", startAt)
	local devRemote = ctx.preview and RunService:IsStudio() and ReplicatedStorage:FindFirstChild("DevLastBroadside")
	if devRemote then
		devRemote:FireServer(true)
	end

	-- ── the take-over: the owner at once, others when they press Watch ──
	local ui = Instance.new("ScreenGui")
	ui.Name = "LastBroadsideUI"
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
		f.ZIndex = 9
		f.Parent = ui
		return f
	end
	local barTop, barBottom = bar(0), bar(1)
	local skipBtn = Theme.stoneButton(ui, {
		text = "Skip", color = "stone", size = UDim2.fromOffset(120, 40),
		position = UDim2.new(1, -24, 1, -20), anchor = Vector2.new(1, 1), zIndex = 10,
	})
	skipBtn.root.Visible = false
	local watchBtn = Theme.stoneButton(ui, {
		text = "Watch the Last Broadside", color = "blue", size = UDim2.fromOffset(300, 44),
		position = UDim2.new(0.5, 0, 0, 90), anchor = Vector2.new(0.5, 0), zIndex = 10,
	})
	watchBtn.root.Visible = false
	local caption
	if RunService:IsStudio() then
		caption = Instance.new("TextLabel")
		caption.Position = UDim2.new(0, 16, BAR_HEIGHT, 8)
		caption.Size = UDim2.fromOffset(520, 26)
		caption.BackgroundTransparency = 1
		caption.Font = Enum.Font.GothamMedium
		caption.TextSize = 18
		caption.TextXAlignment = Enum.TextXAlignment.Left
		caption.TextColor3 = Color3.fromRGB(200, 230, 220)
		caption.TextStrokeTransparency = 0.4
		caption.ZIndex = 11
		caption.Visible = false
		caption.Parent = ui
	end
	-- his line's subtitle (the same layout as the other finishers)
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
	speaker.Text = "ORVOSS"
	speaker.TextColor3 = Color3.fromRGB(120, 220, 185)
	speaker.TextScaled = true
	speaker.ZIndex = 10
	speaker.Parent = subs
	local speakerSize = Instance.new("UITextSizeConstraint")
	speakerSize.MaxTextSize = 14
	speakerSize.Parent = speaker
	local subLine = Instance.new("TextLabel")
	subLine.Position = UDim2.fromScale(0, 0.3)
	subLine.Size = UDim2.fromScale(1, 0.68)
	subLine.BackgroundTransparency = 1
	subLine.Font = Enum.Font.Sarpanch
	subLine.TextColor3 = Color3.fromRGB(226, 240, 234)
	subLine.TextScaled = true
	subLine.TextWrapped = true
	subLine.ZIndex = 10
	subLine.Parent = subs
	local subSize = Instance.new("UITextSizeConstraint")
	subSize.MaxTextSize = 30
	subSize.Parent = subLine
	local subStroke = Instance.new("UIStroke")
	subStroke.Color = Color3.fromRGB(4, 10, 8)
	subStroke.Thickness = 1.5
	subStroke.Transparency = 0.15
	subStroke.Parent = subLine

	local watching = false
	local watchStart = 0
	local saved, controls
	local hiddenGuis, hiddenBoards, hiddenArmy = {}, {}, {}
	-- the watchers' grade: a little brighter and sea-green while the sea is open
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "LastBroadsideGrade"
	cc.Enabled = false
	cc.Parent = Lighting
	local function takeOver()
		if watching or not CinematicGuard.claim("LastBroadside") then
			return
		end
		watching = true
		watchStart = workspace:GetServerTimeNow() - startAt
		saved = { cameraType = camera.CameraType, fov = camera.FieldOfView, guiEnabled = mainGui.Enabled, subject = camera.CameraSubject }
		pcall(function()
			controls = require(player.PlayerScripts:WaitForChild("PlayerModule", 2)):GetControls()
			controls:Disable()
		end)
		mainGui.Enabled = false
		for _, g in ipairs(player:WaitForChild("PlayerGui"):GetChildren()) do
			if g:IsA("ScreenGui") and g.Enabled and g ~= ui and g.Name ~= "Freecam" then
				g.Enabled = false
				table.insert(hiddenGuis, g)
			end
		end
		for _, d in ipairs(workspace:GetDescendants()) do
			if d:IsA("BillboardGui") and d.Enabled then
				d.Enabled = false
				table.insert(hiddenBoards, d)
			end
		end
		-- the army: hidden on this screen for the whole finisher (it stands idle on the server)
		for _, p in ipairs(armyParts(ownerId, orvoss)) do
			if p.LocalTransparencyModifier < 1 then
				p.LocalTransparencyModifier = 1
				table.insert(hiddenArmy, p)
			end
		end
		camera.CameraType = Enum.CameraType.Scriptable
		cc.Enabled = true
		watchBtn.root.Visible = false
		skipBtn.root.Visible = true
		if caption then
			caption.Visible = true
		end
	end
	local function giveBack()
		if not watching then
			return
		end
		watching = false
		for _, p in ipairs(hiddenArmy) do
			if p.Parent then
				p.LocalTransparencyModifier = 0
			end
		end
		hiddenArmy = {}
		for _, b in ipairs(hiddenBoards) do
			if b.Parent then
				b.Enabled = true
			end
		end
		hiddenBoards = {}
		camera.CameraType = saved.cameraType == Enum.CameraType.Scriptable and Enum.CameraType.Custom or saved.cameraType
		if saved.subject and saved.subject.Parent then
			camera.CameraSubject = saved.subject
		end
		camera.FieldOfView = saved.fov
		mainGui.Enabled = saved.guiEnabled
		for _, g in ipairs(hiddenGuis) do
			if g.Parent then
				g.Enabled = true
			end
		end
		hiddenGuis = {}
		if controls then
			pcall(function() controls:Enable() end)
		end
		cc.Enabled = false
		skipBtn.root.Visible = false
		if caption then
			caption.Visible = false
		end
		CinematicGuard.release("LastBroadside")
	end
	if spectator then
		watchBtn.root.Visible = true
		watchBtn.button.Activated:Connect(takeOver)
	else
		takeOver()
		if not watching then
			watchBtn.root.Visible = true -- (another cinematic holds the camera: they can watch when it is free)
			watchBtn.button.Activated:Connect(takeOver)
		end
	end

	local T = workspace:GetServerTimeNow() - startAt
	local done = false
	local BIND = "LastBroadsideCamera_" .. math.floor(startAt * 10)
	local cuesPlayed, bed = {}, nil
	local lastClock = os.clock()

	local function finish()
		if done then
			return
		end
		done = true
		RunService:UnbindFromRenderStep(BIND)
		if bed then
			bed.stop(0.5)
		end
		giveBack()
		ui:Destroy()
		cc:Destroy()
		pcall(worldCleanup)
		fxFolder:Destroy()
		if orvoss.Parent then
			orvoss:SetAttribute("FinisherAt", nil)
		end
		states[orvoss] = nil
		if devRemote then
			devRemote:FireServer(false)
		end
		LastBroadside.active = false
		if opts.onDone then
			opts.onDone()
		end
	end
	skipBtn.button.Activated:Connect(giveBack)
	orvoss.AncestryChanged:Connect(function()
		if not orvoss.Parent then
			giveBack()
		end
	end)

	RunService:BindToRenderStep(BIND, Enum.RenderPriority.Camera.Value + 1, function()
		if done then
			return
		end
		local now = os.clock()
		local dt = math.min(now - lastClock, 0.1)
		lastClock = now
		T = workspace:GetServerTimeNow() - startAt
		if T >= DURATION then
			finish()
			return
		end
		ctx.watching = watching
		local ok, err = pcall(worldUpdate, T, dt)
		if not ok then
			warn("LastBroadside: " .. tostring(err))
		end
		-- the sounds (watchers only; a cue already past when they start watching is skipped)
		for _, c in ipairs(CUES) do
			if not cuesPlayed[c] and T >= c.at then
				cuesPlayed[c] = true
				if watching and T - c.at < 0.4 then
					Sfx.play(c.sound, nil, c.volume, c.pitch)
				end
			end
		end
		local bedV = 0
		if watching then
			bedV = ease(T, BED.from, BED.from + BED.fadeIn) * (1 - ease(T, BED.to - BED.fadeOut, BED.to))
			bedV *= 1 - BED.duck * ease(T, F.ORDER - 0.5, F.ORDER + 0.5) * (1 - ease(T, F.BROADSIDE - 0.2, F.BROADSIDE + 0.5))
		end
		if bedV > 0.001 and not bed then
			bed = Sfx.loop(BED.sound)
		end
		if bed then
			bed.set(bedV)
		end
		-- his line's subtitle (watchers only)
		local current
		for _, l in ipairs(LINES) do
			local elapsed = T - l.at
			if elapsed >= 0 and elapsed < l.length + 0.65 then
				current = l
			end
		end
		if watching and current then
			local elapsed = T - current.at
			local visible = 0
			for _, ph in ipairs(current.phrases) do
				visible += math.floor(ph.count * math.clamp((elapsed - ph.at) / ph.reveal, 0, 1))
			end
			subLine.Text = current.text
			subLine.MaxVisibleGraphemes = visible
			subs.GroupTransparency = smooth((elapsed - current.length - 0.45) / 0.2)
			subs.Visible = true
		else
			subs.Visible = false
		end
		if watchBtn.root.Visible and T >= F.GATE_HIT - 2 then
			watchBtn.root.Visible = false
		end
		local h = watching and BAR_HEIGHT * smooth((T - watchStart) / BAR_TIME) * smooth((DURATION - T) / BAR_TIME) or 0
		barTop.Size = UDim2.fromScale(1, h)
		barBottom.Size = UDim2.fromScale(1, h)
		if not watching then
			return
		end
		local dark = ease(T, F.OMEN, F.SEA) * (1 - ease(T, F.CLOSE, F.LAND))
		-- (brighter, not darker: the lane is already night; a faint sea-green tint)
		cc.Brightness = 0.07 * dark
		cc.Contrast = 0.08 * dark
		cc.Saturation = -0.08 * dark
		cc.TintColor = Color3.new(1, 1, 1):Lerp(Color3.fromRGB(215, 245, 235), 0.5 * dark)
		if camera.CameraType ~= Enum.CameraType.Scriptable then
			camera.CameraType = Enum.CameraType.Scriptable
		end
		local pos, look, fov = cameraAt(T, ctx)
		camera.CFrame = CFrame.lookAt(pos, look)
		camera.FieldOfView = fov
		local shake = ctx.shake or 0
		if shake > 0 then
			local tt = os.clock() * 37
			camera.CFrame *= CFrame.new(math.sin(tt) * shake * 0.7, math.sin(tt * 1.3 + 1) * shake * 0.7, 0)
		end
		if caption then
			local index = 1
			for i, b in ipairs(BEATS) do
				if T >= b.at then
					index = i
				end
			end
			caption.Position = UDim2.new(0, 16, h, 8)
			caption.Text = string.format("%d / %d  %s   (%.1f s)", index, #BEATS, BEATS[index].name, T)
		end
	end)
	return true
end

-- AdmiralAnimator (later): the running finisher
function LastBroadside.state(model)
	return states[model]
end

-- the server starts it for everyone (Army.checkFinisher)
local remote = ReplicatedStorage:WaitForChild("LastBroadside", 10)
if remote then
	remote.OnClientEvent:Connect(function(data)
		if type(data) ~= "table" or not data.startAt then
			return
		end
		LastBroadside.play({
			startAt = data.startAt,
			unit = data.unit,
			gate = data.gate,
			spectator = data.owner ~= tostring(player.UserId),
		})
	end)
end

return LastBroadside
