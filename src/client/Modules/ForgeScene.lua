-- The Forge in the world: when the Forge panel is opened AT the Forge stall (Workspace.HubDecor.Stall_ForgeKeeper), the
-- camera stands beside the anvil (ForgePanel opens a WorldView with ForgeScene.cameraCFrame), the selected unit stands
-- small on the glowing ingot, and every upgrade attempt is played out on the anvil (client only; the server decides
-- everything in UnitUpgrades):
--   1. pour     the crucible of the unit's dust pours a glowing stream onto it (a gold coin flies in for a Fortune
--               Catalyst, a blue ward ring rises for a Warding Catalyst)
--   2. gather   the Forge's magic circle rises round the unit and spins up, the soul furnace flares, the smith winds up
--               (waits here until the server's answer is in)
--   3. strike   the hammer comes down beside the unit: flash, sparks, a small shake
--   4. swell    the unit's glow swells as if it is about to burst (the same for success and failure: the tease)
--   5. result   success: a burst of soul light, sparks, "Lv N" rises, the level aura lights (model attribute Level,
--               LevelAuras); failure: the glow collapses, grey smoke and ash (with a Warding Catalyst the ward ring
--               shatters and the dust flies back into its crucible)
-- The stall's two-layer magic circle (MagicCircleOuter/Inner, spun by WorldFx) is taken over while the view is open: it
-- shrinks and floats down to lie flat on the anvil round the unit's feet (`setBlend`, with the camera's glide), turns
-- slowly, rises and spins up during an attempt, flares on a success, slows and sinks on a failure, and floats back up.
-- `quick` plays it at QUICK_SPEED; skip() jumps to the end as soon as the answer is in. Dismantle: the unit sinks into
-- the anvil and flies into its crucible as dust.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Economy = require(ReplicatedStorage.Shared.Economy)
local Theme = require(script.Parent.Theme)
local WorldFx = require(script.Parent.WorldFx)

local ForgeScene = {}

local RANGE = 22 -- the scene only plays near the stall (the Remote Forge opens the plain panel elsewhere)
local UNIT_HEIGHT = 2.5 -- how tall the unit stands on the anvil
local QUICK_SPEED = 2.4
local GLOW = Color3.fromRGB(120, 255, 190)
local GOLD = Color3.fromRGB(255, 196, 80)
local WARD = Color3.fromRGB(110, 190, 255)
local ASH = Color3.fromRGB(70, 68, 66)

-- stall-local spots (the stall's pivot frame: the counter side faces -X)
local UNIT_SPOT = Vector3.new(-1.45, 4.48, 0.3) -- the top of the glowing ingot
local SHOULDER = Vector3.new(1.3, 4.0, -1.35) -- the smith's right shoulder (the hammer arm turns round local Z here)
local SOUL_FIRE = Vector3.new(2.85, 2.27, 0)
local CAM_POS = Vector3.new(-7.6, 6.0, -0.6)
local CAM_LOOK = Vector3.new(-0.9, 5.2, -0.6)
local CAM_SHIFT = 2.3 -- the camera slides right so the anvil stands left of the panel
local CIRCLE_REST_SCALE = 0.32 -- the stall's circle lying on the anvil
local CIRCLE_REST_LIFT = 0.12 -- above the ingot
local WINDUP = -0.45 -- radians round the shoulder
local STRIKE = 0.74

-- the timeline of an upgrade (seconds at normal speed)
local T_POUR = 0.9
local T_GATHER = 1.7 -- the strike starts here (held until the answer is in)
local T_IMPACT = 1.95
local T_SWELL = 2.65 -- the swell ends: burst or collapse
local T_END_SUCCESS = 3.9
local T_END_FAIL = 4.3

local function smooth(x)
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end
local function lerp(a, b, f)
	return a + (b - a) * f
end
local function bezier(a, b, c, f)
	return a:Lerp(b, f):Lerp(b:Lerp(c, f), f)
end

local scene -- the running scene (nil when the Forge is not open at the stall)

local function stall()
	local decor = workspace:FindFirstChild("HubDecor")
	return decor and decor:FindFirstChild("Stall_ForgeKeeper")
end

-- true if the player stands at the Forge stall (the in-world Forge is possible)
function ForgeScene.available()
	local m = stall()
	local char = Players.LocalPlayer.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	return m ~= nil and root ~= nil and (root.Position - m:GetPivot().Position).Magnitude < RANGE + 6
end

local function newPart(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = props.material or Enum.Material.Neon
	p.Shape = props.shape or Enum.PartType.Ball
	p.Size = props.size or Vector3.new(0.2, 0.2, 0.2)
	p.Color = props.color or GLOW
	p.Transparency = props.transparency or 0
	p.CFrame = props.cf or CFrame.new()
	p.Parent = scene.folder
	return p
end

local function emitter(props)
	local att = Instance.new("Attachment")
	att.Parent = scene.anchor
	local e = Instance.new("ParticleEmitter")
	e.Enabled = false
	e.Color = ColorSequence.new(props.color)
	e.LightEmission = props.light or 1
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, props.size or 0.2), NumberSequenceKeypoint.new(1, 0) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, props.alpha or 0.1), NumberSequenceKeypoint.new(1, 1) })
	e.Lifetime = props.life or NumberRange.new(0.5, 1)
	e.Speed = props.speed or NumberRange.new(4, 8)
	e.SpreadAngle = props.spread or Vector2.new(180, 180)
	e.Acceleration = props.accel or Vector3.new(0, -12, 0)
	e.Drag = props.drag or 2
	e.EmissionDirection = Enum.NormalId.Top
	e.Parent = att
	return { att = att, e = e }
end
local function burst(em, pos, count)
	em.att.WorldPosition = pos
	em.e:Emit(count)
end

-- ============================================================
-- Opening / closing
-- ============================================================
function ForgeScene.start()
	ForgeScene.stop()
	local m = stall()
	if not m then
		return false
	end
	local folder = Instance.new("Folder")
	folder.Name = "ForgeSceneFX"
	folder.Parent = workspace
	scene = { stall = m, pivot = m:GetPivot(), folder = folder, shake = 0, armAngle = 0 }
	scene.anchor = newPart({ size = Vector3.new(0.1, 0.1, 0.1), transparency = 1 })
	scene.sparks = emitter({ color = GOLD, size = 0.14, life = NumberRange.new(0.4, 0.9), speed = NumberRange.new(6, 14) })
	scene.soulSparks = emitter({ color = GLOW, size = 0.18, life = NumberRange.new(0.6, 1.2), speed = NumberRange.new(5, 11), accel = Vector3.new(0, 4, 0) })
	scene.smoke = emitter({ color = Color3.fromRGB(96, 98, 102), light = 0, size = 0.9, alpha = 0.35, life = NumberRange.new(1.2, 2),
		speed = NumberRange.new(1, 2.5), accel = Vector3.new(0, 2, 0), drag = 3 })
	scene.ash = emitter({ color = ASH, light = 0, size = 0.12, alpha = 0, life = NumberRange.new(1, 1.6), speed = NumberRange.new(1, 3),
		accel = Vector3.new(0, -6, 0), spread = Vector2.new(70, 70) })
	scene.puff = emitter({ color = Color3.fromRGB(150, 230, 200), light = 0.4, size = 0.6, alpha = 0.4, life = NumberRange.new(0.5, 0.9),
		speed = NumberRange.new(1.5, 3), accel = Vector3.new(0, 2, 0) })
	-- the smith's hammer arm (static stall parts, moved on this client only)
	scene.arm = {}
	for _, name in ipairs({ "ArmR", "RaisedHammerHandle", "RaisedHammerHead" }) do
		local p = m:FindFirstChild(name)
		if p then
			table.insert(scene.arm, { part = p, base = p.CFrame })
		end
	end
	-- the stall's magic circle (it hangs in the camera's line of sight): taken over from WorldFx, see setBlend
	scene.circles = {}
	scene.blend = 0
	scene.circleLift, scene.circleSpin, scene.circleScale = 0, 1, 1 -- (set by the attempts, eased every frame)
	scene.liftNow, scene.spinNow, scene.scaleNow = 0, 1, 1
	for _, name in ipairs({ "MagicCircleOuter", "MagicCircleInner" }) do
		local c = m:FindFirstChild(name)
		if c and c.PrimaryPart then
			local base = WorldFx.baseOf(c) or c:GetPivot()
			WorldFx.pause(c, true)
			local axis = base:VectorToWorldSpace(Vector3.yAxis) -- the spin axis (WorldFx turns round the pivot's Y)
			local flat = CFrame.fromRotationBetweenVectors(axis, Vector3.yAxis) * base.Rotation
			table.insert(scene.circles, {
				model = c, base = base, flat = flat, speed = c:GetAttribute("SpinSpeed") or 0.5,
				angle = (os.clock() * (c:GetAttribute("SpinSpeed") or 0.5)) % (2 * math.pi), scale = 1,
			})
		end
	end
	-- the soul furnace's light
	scene.fireLight = Instance.new("PointLight")
	scene.fireLight.Color = GLOW
	scene.fireLight.Range = 14
	scene.fireLight.Brightness = 0
	scene.fireLight.Shadows = false
	local holder = newPart({ size = Vector3.new(0.1, 0.1, 0.1), transparency = 1, cf = scene.pivot * CFrame.new(SOUL_FIRE) })
	scene.fireLight.Parent = holder
	scene.crucibles = {}
	for _, d in ipairs(m:GetChildren()) do
		if d.Name == "Dust" and d:IsA("BasePart") then
			local x = scene.pivot:PointToObjectSpace(d.Position).X
			scene.crucibles[math.floor(x + 0.5) + 3] = d -- local x -2..2 = dust 1..5 (Economy.DUSTS order)
		end
	end
	return true
end

local function setArm(angle)
	if not scene then
		return
	end
	scene.armAngle = angle
	local P = scene.pivot
	local turn = CFrame.new(SHOULDER) * CFrame.Angles(0, 0, angle) * CFrame.new(-SHOULDER)
	for _, a in ipairs(scene.arm) do
		if a.part.Parent then
			a.part.CFrame = P * turn * P:ToObjectSpace(a.base)
		end
	end
end

function ForgeScene.stop()
	if not scene then
		return
	end
	setArm(0)
	for _, c in ipairs(scene.circles) do
		if c.model.Parent then
			c.model:ScaleTo(1)
			c.model:PivotTo(c.base)
		end
		WorldFx.pause(c.model, false)
	end
	if scene.anim and scene.anim.onDone then
		local done = scene.anim.onDone
		scene.anim.onDone = nil
		done(scene.anim.result)
	end
	scene.folder:Destroy()
	scene = nil
end

-- how far the view is open (0..1, from the WorldView glide): the circle floats between its place and the anvil
function ForgeScene.setBlend(k)
	if scene then
		scene.blend = k
	end
end

local function updateCircles(dt)
	local ease = math.min(1, dt * 6)
	scene.liftNow += (scene.circleLift - scene.liftNow) * ease
	scene.spinNow += (scene.circleSpin - scene.spinNow) * math.min(1, dt * 3)
	scene.scaleNow += (scene.circleScale - scene.scaleNow) * ease
	local k = smooth(scene.blend)
	local spot = (scene.pivot * CFrame.new(UNIT_SPOT)).Position
	for _, c in ipairs(scene.circles) do
		if c.model.Parent then
			c.angle = (c.angle + dt * c.speed * scene.spinNow) % (2 * math.pi)
			local rest = CFrame.new(spot + Vector3.new(0, CIRCLE_REST_LIFT + scene.liftNow, 0)) * c.flat
			local scale = lerp(1, CIRCLE_REST_SCALE * scene.scaleNow, k)
			if math.abs(scale - c.scale) > 0.002 then
				c.scale = scale
				c.model:ScaleTo(scale)
			end
			c.model:PivotTo(c.base:Lerp(rest, k) * CFrame.Angles(0, c.angle, 0))
		end
	end
end

-- the player's own character is hidden while the camera looks past it at the anvil
function ForgeScene.hideCharacter(char, hidden)
	if not char then
		return
	end
	-- (every frame: the default camera scripts reset LocalTransparencyModifier)
	for _, d in ipairs(char:GetDescendants()) do
		if d:IsA("BasePart") or d:IsA("Decal") then
			d.LocalTransparencyModifier = hidden and 1 or 0
		end
	end
end

function ForgeScene.active()
	return scene ~= nil
end

-- the camera beside the anvil (with the strike's shake)
function ForgeScene.cameraCFrame()
	if not scene then
		return workspace.CurrentCamera.CFrame
	end
	local P = scene.pivot
	local cf = CFrame.lookAt((P * CFrame.new(CAM_POS)).Position, (P * CFrame.new(CAM_LOOK)).Position) * CFrame.new(CAM_SHIFT, 0, 0)
	if scene.shake > 0 then
		local a = scene.shake * 0.18
		cf = cf * CFrame.new((math.random() - 0.5) * a, (math.random() - 0.5) * a, 0)
	end
	return cf
end

local function spotWorld()
	return (scene.pivot * CFrame.new(UNIT_SPOT)).Position
end

-- ============================================================
-- The unit on the anvil
-- ============================================================
local function clearUnit()
	if scene and scene.unit then
		scene.unit:Destroy()
		scene.unit = nil
	end
end

function ForgeScene.showUnit(unitType, level)
	if not scene then
		return
	end
	if scene.unitType == unitType and scene.unit and scene.unitLevel == level then
		return
	end
	local swapped = scene.unitType ~= nil and scene.unitType ~= unitType
	scene.unitType = unitType
	scene.unitLevel = level
	clearUnit()
	if swapped or not scene.unitShownOnce then
		burst(scene.puff, spotWorld() + Vector3.new(0, 0.6, 0), 14)
	end
	scene.unitShownOnce = true
	if not unitType then
		return
	end
	local folder = ReplicatedStorage:FindFirstChild("UnitModels")
	local template = folder and folder:FindFirstChild(unitType)
	if not template then
		return
	end
	local model = template:Clone()
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BaseScript") or d:IsA("Humanoid") or d:IsA("BillboardGui") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = false
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
		end
	end
	local root = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart", true)
	if not root then
		model:Destroy()
		return
	end
	root.Anchored = true
	local height = model:GetExtentsSize().Y
	model:ScaleTo(model:GetScale() * UNIT_HEIGHT / math.max(height, 0.1))
	local rootHeight = (model:GetAttribute("RootHeight") or 2.2) * model:GetScale()
	local at = spotWorld() + Vector3.new(0, rootHeight, 0)
	local front = (scene.pivot * CFrame.new(UNIT_SPOT + Vector3.new(-6, 0, -0.6))).Position
	model:PivotTo(CFrame.lookAt(at, Vector3.new(front.X, at.Y, front.Z)))
	model:SetAttribute("AttackStyle", nil)
	model:SetAttribute("State", "idle")
	model:SetAttribute("Level", level or 0)
	model.Parent = scene.folder
	CollectionService:AddTag(model, "ProceduralUnit")
	scene.unit = model
	scene.unitBase = model:GetPivot()
end

local function setUnitFade(f)
	if not (scene and scene.unit) then
		return
	end
	for _, d in ipairs(scene.unit:GetDescendants()) do
		if d:IsA("BasePart") or d:IsA("Decal") then
			d.LocalTransparencyModifier = f
		end
	end
end

-- ============================================================
-- An upgrade attempt
-- ============================================================
-- opts: dust (key from Economy.DUSTS), fortune, warding, quick, onDone(result)
-- returns the attempt: resolve(success, newLevel) when the server answers, skip()
function ForgeScene.playUpgrade(opts)
	if not scene then
		return nil
	end
	if scene.anim then
		ForgeScene.finishAnim()
	end
	local dustIndex = table.find(Economy.DUSTS, opts.dust) or 1
	local dustColor = Theme.DustColor[opts.dust] or GLOW
	local crucible = scene.crucibles[dustIndex]
	local from = crucible and (crucible.Position + Vector3.new(0, 0.3, 0)) or (spotWorld() + Vector3.new(-2, 3, -3))
	local to = spotWorld() + Vector3.new(0, 1.0, 0)
	local mid = from:Lerp(to, 0.5) + Vector3.new(0, 3.2, 0)
	local anim = {
		kind = "upgrade", t = 0, speed = opts.quick and QUICK_SPEED or 1, opts = opts, onDone = opts.onDone,
		resolved = false, waited = 0, parts = {}, from = from, mid = mid, to = to, dustColor = dustColor,
	}
	-- the stream of dust motes
	anim.motes = {}
	for i = 1, 16 do
		anim.motes[i] = newPart({ size = Vector3.new(0.22, 0.22, 0.22), color = dustColor, transparency = 1 })
	end
	anim.charge = newPart({ size = Vector3.new(1, 1, 1), color = GLOW, transparency = 1 })
	if opts.fortune then
		anim.coin = newPart({ shape = Enum.PartType.Cylinder, size = Vector3.new(0.08, 0.55, 0.55), color = GOLD, transparency = 1 })
	end
	if opts.warding then
		anim.ward = {}
		for i = 1, 12 do
			anim.ward[i] = newPart({ shape = Enum.PartType.Block, size = Vector3.new(0.42, 0.06, 0.1), color = WARD, transparency = 1 })
		end
	end
	function anim.resolve(success, level)
		anim.resolved = true
		anim.success = success
		anim.level = level
		anim.result = { success = success, level = level }
	end
	function anim.skip()
		anim.skipping = true
	end
	scene.anim = anim
	return anim
end

-- dismantle: the unit sinks into the anvil and flies into its crucible as dust
function ForgeScene.playDismantle(opts)
	if not (scene and scene.unit) then
		if opts.onDone then
			opts.onDone()
		end
		return nil
	end
	if scene.anim then
		ForgeScene.finishAnim()
	end
	local dustIndex = table.find(Economy.DUSTS, opts.dust) or 1
	local crucible = scene.crucibles[dustIndex]
	local dustColor = Theme.DustColor[opts.dust] or GLOW
	local from = spotWorld() + Vector3.new(0, 0.6, 0)
	local to = crucible and (crucible.Position + Vector3.new(0, 0.3, 0)) or (from + Vector3.new(-2, 2, -3))
	local anim = {
		kind = "dismantle", t = 0, speed = opts.quick and QUICK_SPEED or 1, onDone = opts.onDone, resolved = true,
		from = from, mid = from:Lerp(to, 0.5) + Vector3.new(0, 3, 0), to = to, motes = {},
	}
	for i = 1, 14 do
		anim.motes[i] = newPart({ size = Vector3.new(0.22, 0.22, 0.22), color = dustColor, transparency = 1 })
	end
	anim.flash = newPart({ size = Vector3.new(1, 1, 1), color = dustColor, transparency = 1 })
	function anim.skip()
		anim.skipping = true
	end
	scene.anim = anim
	return anim
end

-- ends the running animation at once (its final state, then onDone)
function ForgeScene.finishAnim()
	local anim = scene and scene.anim
	if not anim then
		return
	end
	scene.anim = nil
	for _, list in ipairs({ anim.motes or {}, anim.ward or {} }) do
		for _, p in ipairs(list) do
			p:Destroy()
		end
	end
	for _, p in ipairs({ anim.charge, anim.coin, anim.flash, anim.label }) do
		if p then
			p:Destroy()
		end
	end
	setArm(0)
	scene.circleLift, scene.circleSpin, scene.circleScale = 0, 1, 1
	scene.fireLight.Brightness = 0
	if anim.kind == "upgrade" and anim.success and scene.unit then
		scene.unit:SetAttribute("Level", anim.level)
		scene.unitLevel = anim.level
	elseif anim.kind == "dismantle" then
		clearUnit()
		scene.unitType = nil
	end
	setUnitFade(0)
	local done = anim.onDone
	anim.onDone = nil
	if done then
		done(anim.result)
	end
end

-- motes along the arc: `f` is the stream's progress (0..1), each mote a little behind the one before
local function placeMotes(motes, a, b, c, f, reverse)
	local n = #motes
	for i, p in ipairs(motes) do
		local k = f * 1.6 - (i - 1) / n * 0.6
		if k <= 0 or k >= 1 then
			p.Transparency = 1
		else
			local g = reverse and (1 - k) or k
			p.CFrame = CFrame.new(bezier(a, b, c, g) + Vector3.new(math.sin(i * 7.3) * 0.12, math.cos(i * 3.1) * 0.12, 0))
			p.Transparency = 0.1
		end
	end
end

local function hideMotes(motes)
	for _, p in ipairs(motes) do
		p.Transparency = 1
	end
end

local function levelLabel(level)
	local holder = newPart({ size = Vector3.new(0.1, 0.1, 0.1), transparency = 1, cf = CFrame.new(spotWorld() + Vector3.new(0, UNIT_HEIGHT + 0.4, 0)) })
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(160, 60)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Parent = holder
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = UDim2.fromScale(1, 1)
	l.Font = Theme.Font.Title
	l.TextScaled = true
	l.Text = "Lv " .. tostring(level)
	l.TextColor3 = level >= Economy.MAX_UNIT_LEVEL and GOLD or GLOW
	l.TextStrokeTransparency = 0
	l.TextStrokeColor3 = Color3.new(0, 0, 0)
	l.Parent = gui
	return holder, l
end

local function stepUpgrade(anim, dt)
	local T = anim.t
	local spot = spotWorld()
	-- wait for the server's answer before the strike
	if T >= T_GATHER and not anim.resolved then
		anim.t = T_GATHER
		T = T_GATHER
		anim.waited += dt
		if anim.waited > 8 then
			ForgeScene.finishAnim() -- no answer: end quietly
			return
		end
	end
	if anim.skipping and anim.resolved then
		ForgeScene.finishAnim()
		return
	end

	-- 1. the dust pours from its crucible
	placeMotes(anim.motes, anim.from, anim.mid, anim.to, T / T_POUR)
	if anim.coin then
		local f = smooth(T / T_POUR)
		local start = spot + Vector3.new(-1.5, 5, -3)
		anim.coin.CFrame = CFrame.new(start:Lerp(spot + Vector3.new(0, 1.5, 0), f)) * CFrame.Angles(0, T * 12, 0)
		anim.coin.Transparency = (T < T_POUR) and 0 or 1
	end
	if anim.ward then
		local fade = smooth((T - 0.4) / 0.5)
		local shatter = anim.resolved and not anim.success and T > T_SWELL
		for i, p in ipairs(anim.ward) do
			local a = (i / #anim.ward) * math.pi * 2 + T * 1.5
			local r = 1.05
			local y = 0.9
			if shatter then
				local k = (T - T_SWELL) / 0.6
				r = 1.05 + k * 3
				y = 0.9 + k * 1.2 - k * k * 2
				p.Transparency = math.clamp(k, 0, 1)
			else
				p.Transparency = 1 - fade * 0.9
			end
			p.CFrame = CFrame.new(spot + Vector3.new(math.cos(a) * r, y, math.sin(a) * r)) * CFrame.Angles(0, -a, 0)
		end
	end

	-- 2. the Forge's circle rises round the unit and spins up, the furnace flares, the smith winds up
	local rise = smooth((T - 0.5) / 0.9)
	scene.circleLift = rise * 1.0
	scene.circleSpin = 1 + rise * 5 + smooth((T - T_IMPACT) / 0.5) * 4
	scene.circleScale = 1
	if anim.resolved and T > T_SWELL then
		if anim.success then
			-- it flares up and out, then settles back
			local k = T - T_SWELL
			scene.circleLift = 1.0 + 0.8 * math.sin(math.min(k / 1.0, 1) * math.pi)
			scene.circleScale = 1 + 0.45 * math.sin(math.min(k / 1.0, 1) * math.pi)
			scene.circleSpin = 14 * (1 - smooth(k / 1.2)) + 1
		else
			-- it falters and sinks back onto the anvil
			scene.circleLift = 0
			scene.circleSpin = 0.25
			scene.circleScale = 0.9
		end
	end
	scene.fireLight.Brightness = smooth((T - 0.7) / 0.8) * 3 * (1 - smooth((T - T_IMPACT) / 1.2))
	local arm
	if T < T_GATHER then
		arm = WINDUP * smooth((T - 0.8) / 0.9)
	elseif T < T_IMPACT then
		local f = (T - T_GATHER) / (T_IMPACT - T_GATHER)
		arm = WINDUP + (STRIKE - WINDUP) * f * f
	else
		arm = STRIKE * (1 - smooth((T - T_IMPACT) / 0.7))
	end
	setArm(arm)

	-- 3. the strike
	if T >= T_IMPACT and not anim.struck then
		anim.struck = true
		local head = scene.stall:FindFirstChild("RaisedHammerHead")
		local hit = head and head.Position or spot
		burst(scene.sparks, hit, 40)
		anim.flash = newPart({ size = Vector3.new(0.7, 0.7, 0.7), color = Color3.fromRGB(255, 230, 180), cf = CFrame.new(hit), transparency = 0.3 })
		anim.flashAt = T
		scene.shake = 1
	end
	if anim.flash and anim.flashAt then
		local k = (T - anim.flashAt) / 0.25
		anim.flash.Size = Vector3.one * (0.7 + k * 1.3)
		anim.flash.Transparency = math.clamp(0.3 + k, 0, 1)
	end

	-- 4. the swell (the tease: the same for success and failure) and 5. the result
	local swell = smooth((T - T_IMPACT) / (T_SWELL - T_IMPACT))
	local gatherGlow = smooth((T - 0.8) / 0.9)
	local size = 0.6 + gatherGlow * 0.3 + swell * 0.8
	local alpha = 0.9 - gatherGlow * 0.15 - swell * 0.35
	if T > T_IMPACT and T < T_SWELL then
		alpha += math.sin(T * 40) * 0.08 * swell -- it flickers as it strains
	end
	if anim.resolved and T >= T_SWELL then
		local k = (T - T_SWELL)
		if anim.success then
			-- a burst of soul light
			size = 1.7 + k * 5
			alpha = math.clamp(0.4 + k * 1.6, 0, 1)
			if not anim.burst then
				anim.burst = true
				burst(scene.soulSparks, spot + Vector3.new(0, 1, 0), 60)
				burst(scene.sparks, spot + Vector3.new(0, 1, 0), 30)
				if scene.unit then
					scene.unit:SetAttribute("Level", anim.level)
					scene.unitLevel = anim.level
				end
				anim.label, anim.labelText = levelLabel(anim.level)
			end
			if anim.label then
				anim.label.CFrame = CFrame.new(spot + Vector3.new(0, UNIT_HEIGHT + 0.4 + k * 1.2, 0))
				anim.labelText.TextTransparency = smooth((k - 0.7) / 0.5)
				anim.labelText.TextStrokeTransparency = anim.labelText.TextTransparency
			end
		else
			-- the glow collapses into smoke and ash
			size = math.max(0, 1.7 * (1 - k / 0.25))
			alpha = 0.4 + smooth(k / 0.25) * 0.6
			if not anim.fizzled then
				anim.fizzled = true
				burst(scene.smoke, spot + Vector3.new(0, 0.8, 0), 22)
				burst(scene.ash, spot + Vector3.new(0, 1.4, 0), 30)
			end
			if anim.ward and not anim.returning then
				anim.returning = true
				anim.returnAt = T
			end
		end
	end
	anim.charge.Size = Vector3.one * math.max(size, 0.01)
	anim.charge.CFrame = CFrame.new(spot + Vector3.new(0, 0.95, 0))
	anim.charge.Color = (anim.resolved and not anim.success and T > T_SWELL) and ASH or GLOW:Lerp(Color3.new(1, 1, 1), swell * 0.15)
	anim.charge.Transparency = math.clamp(alpha, 0, 1)
	-- a Warding Catalyst saved the dust: it flies back into its crucible
	if anim.returning then
		placeMotes(anim.motes, anim.from, anim.mid, anim.to, (T - anim.returnAt - 0.3) / 0.9, true)
	elseif T > T_POUR then
		hideMotes(anim.motes)
	end

	local endAt = anim.resolved and (anim.success and T_END_SUCCESS or T_END_FAIL) or math.huge
	if T >= endAt then
		ForgeScene.finishAnim()
	end
end

local function stepDismantle(anim)
	local T = anim.t
	if anim.skipping then
		ForgeScene.finishAnim()
		return
	end
	-- the unit sinks into the anvil and fades, a flash, then the dust flies into its crucible
	local sink = smooth(T / 0.7)
	if scene.unit and scene.unitBase then
		scene.unit:PivotTo(scene.unitBase * CFrame.new(0, -sink * UNIT_HEIGHT * 0.8, 0))
		setUnitFade(sink)
	end
	local k = (T - 0.55) / 0.3
	anim.flash.CFrame = CFrame.new(anim.from)
	anim.flash.Size = Vector3.one * (0.5 + math.clamp(k, 0, 1) * 2.5)
	anim.flash.Transparency = (k > 0 and k < 1) and (0.2 + k * 0.8) or 1
	placeMotes(anim.motes, anim.from, anim.mid, anim.to, (T - 0.65) / 0.8)
	if T >= 1.7 then
		ForgeScene.finishAnim()
	end
end

-- every frame while the scene runs
RunService.RenderStepped:Connect(function(dt)
	if not scene then
		return
	end
	scene.shake = math.max(0, scene.shake - dt * 3.5)
	updateCircles(dt)
	local anim = scene.anim
	if anim then
		anim.t += dt * anim.speed
		if anim.kind == "upgrade" then
			stepUpgrade(anim, dt)
		else
			stepDismantle(anim)
		end
	end
end)

function ForgeScene.busy()
	return scene ~= nil and scene.anim ~= nil
end

function ForgeScene.skip()
	if scene and scene.anim then
		scene.anim.skip()
	end
end

return ForgeScene
