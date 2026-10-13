-- The grave cinematic: opening graves by hand plays this in the 3D world instead of the overlay's short show.
--
--   local started = GraveCinematic.play(results, opts)
--     results: list of { unitType, rarity, pity, oneIn } from the server's RollResult (one entry per grave opened)
--     opts:    graveType  the grave that was opened (needs a model in ReplicatedStorage.GraveModels)
--              onDone     function(), called when the cinematic ends (also when it is skipped)
--     returns false (and does nothing) when it cannot play: no model for that grave, no character, or a cinematic runs.
--
-- What you see: the camera eases into a three-quarter view as the real grave pushes up out of the ground in front of you,
-- it shakes harder and harder while its soul-light cracks shift to the pull's rarity colour (big rarities flicker out
-- right before the burst), then it bursts open (GraveOpening with world effects: flying earth, a light column, a real light,
-- dust, sparks, souls), the camera shakes, and the BEST unit of the pull rises out of the pit. A Continue button (or Space /
-- Enter / E) ends it; Skip ends it at once. The caller then shows the overlay straight at the result (the grid for x10).
-- Everything scales with the best result's rarity rank (t = 0..1). Only the player who pulled sees it; camera, controls and
-- the main UI are taken over and restored like the star summon (Modules/StarSummon, which this mirrors).
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local GameData = require(script.Parent.GameData)
local mainGui = require(script.Parent.Gui)
local Theme = require(script.Parent.Theme)
local SignatureName = require(script.Parent.SignatureName)
local GraveOpening = require(script.Parent.GraveOpening)
local MagicCircle = require(script.Parent.MagicCircle)
local Sfx = require(script.Parent.Sfx)
local Rarities = require(ReplicatedStorage.Shared.Rarities)
local Units = require(ReplicatedStorage.Shared.Units)

local player = Players.LocalPlayer

local GraveCinematic = {}
GraveCinematic.active = false

local GRAVE_SCALE = 1.5 -- the grave is shown a bit bigger than its model
local GRAVE_DISTANCE = 16 -- studs in front of the player
local PROP_TAG = "ProceduralUnit"

local MAX_RANK = 1
for _, rank in pairs(Rarities.Rank) do
	MAX_RANK = math.max(MAX_RANK, rank)
end
local function tierOf(rarity)
	return math.clamp(((Rarities.Rank[rarity] or 1) - 1) / math.max(1, MAX_RANK - 1), 0, 1)
end
local function rarityColor(rarity)
	return GameData.RARITY_COLORS[rarity] or Rarities.Color[rarity] or Color3.new(1, 1, 1)
end
local function smooth(x)
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

function GraveCinematic.play(results, opts)
	opts = opts or {}
	local template = GraveOpening.template(opts.graveType)
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local camera = Workspace.CurrentCamera
	if GraveCinematic.active or not template or not hrp or not camera or not results or #results == 0 then
		return false
	end
	GraveCinematic.active = true

	-- ── The best result and the timeline ─────────────────────
	local best = results[1]
	for _, r in ipairs(results) do
		if (Rarities.Rank[r.rarity] or 0) > (Rarities.Rank[best.rarity] or 0) then
			best = r
		end
	end
	local t = tierOf(best.rarity)
	local bestColor = rarityColor(best.rarity)
	local fake = t > 0.55 -- big rarities flicker out right before the burst
	-- OpenStyle "Door" (crypts): the door falls, the unit WALKS out; the crypt is scaled up so the unit fits through the door
	local isDoor = template:GetAttribute("OpenStyle") == "Door"
	-- box graves (coffins, tombs) with HopOut: the risen unit hops out over the front wall, so the walls never hide its legs
	local hopOut = not isDoor and template:GetAttribute("HopOut")
	-- OpenStyle "Summon" (the Void Sanctum): nothing bursts; the floating grave casts a magic circle on the ground in front
	-- of it, the camera looks up at a beam gathering in the sky, the beam strikes the circle (the camera follows it down)
	-- and the unit materializes on the circle, from its feet up
	local isSummon = template:GetAttribute("OpenStyle") == "Summon"
	local graveDistance = isSummon and 24 or GRAVE_DISTANCE
	-- UnitInside (the Celestial Abyss, an upright coffin): the unit is already standing inside, it is seen when the door opens
	local unitInside = hopOut and template:GetAttribute("UnitInside")
	local HOP_TIME = template:GetAttribute("HopTime") or 0.75 -- (the Eternal Throne glides down its steps more slowly)
	local unitTall = 5
	do
		local folder = ReplicatedStorage:FindFirstChild("UnitModels")
		local tpl = folder and folder:FindFirstChild(best.unitType)
		local def = Units.Stats[best.unitType]
		if tpl and tpl:GetAttribute("Height") then
			unitTall = tpl:GetAttribute("Height") * (def and (def.size.X / 2 * 0.9) or 1)
		end
	end
	local graveScale = GRAVE_SCALE
	if isDoor and template:GetAttribute("DoorHeight") then
		graveScale = math.clamp(unitTall * 1.15 / template:GetAttribute("DoorHeight"), GRAVE_SCALE, 3)
	end

	local T_ARRIVE = 1.1 -- the grave pushes up out of the ground
	local T_BUILD = 1.2 + 1.4 * t -- it shakes and glows
	local T_RISE = isDoor and (2.6 + 0.6 * t) or (2.0 + 0.8 * t) -- the unit climbs (or walks) out
	local START_BUILD = T_ARRIVE
	local START_BURST = START_BUILD + T_BUILD
	local START_RISE = START_BURST + (isDoor and 0.7 or 0.45)
	local START_HERO = START_BURST + 1.8 -- from here the camera only orbits slowly
	local HOLD_AT = START_RISE + T_RISE + (hopOut and HOP_TIME or 0)
	local SUMMON_CAST = START_BURST -- the circle opens on the ground
	local SUMMON_SKY = SUMMON_CAST + 1.5 -- the camera looks up: the beam gathers in the sky
	local SUMMON_STRIKE = SUMMON_SKY + 1.8 -- the beam shoots down
	local SUMMON_HIT = SUMMON_STRIKE + 0.3 -- it hits the circle, the unit materializes
	if unitInside then
		-- the unit is already inside: it appears standing under the burst's flash (no rise), holds a moment, then glides out
		START_RISE = START_BURST + 0.05
		T_RISE = 0.9
		HOLD_AT = START_RISE + T_RISE + HOP_TIME
	end
	if isSummon then
		T_RISE = 2.2
		START_RISE = SUMMON_HIT
		START_HERO = SUMMON_HIT + 1.7
		HOLD_AT = START_RISE + T_RISE
	end
	local endTime = math.huge

	-- ── The place: in front of the player, with a clear view ──
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
	-- a camera spot must also be free space (a ray can slip between fence bars while the camera sits inside the fence)
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Exclude
	overlap.FilterDescendantsInstances = ignore
	local function spotIsFree(pos)
		return #Workspace:GetPartBoundsInRadius(pos, 1.3, overlap) == 0
	end
	local flatLook = Vector3.new(hrp.CFrame.LookVector.X, 0, hrp.CFrame.LookVector.Z)
	local lookDir = flatLook.Magnitude > 0.1 and flatLook.Unit or Vector3.new(0, 0, -1)
	local dir, right, G
	for _, degrees in ipairs({ 0, 45, -45, 90, -90, 135, -135, 180 }) do
		local a = math.rad(degrees)
		local d = Vector3.new(lookDir.X * math.cos(a) - lookDir.Z * math.sin(a), 0, lookDir.X * math.sin(a) + lookDir.Z * math.cos(a))
		local r = Vector3.new(-d.Z, 0, d.X)
		local hit = Workspace:Raycast(hrp.Position + d * graveDistance + up * 20, Vector3.new(0, -60, 0), rayParams)
		-- the floor under the character (not a unit, a drop or a wall top): a little below the character's root
		if hit and hit.Normal.Y > 0.9 and hit.Position.Y < hrp.Position.Y - 1.5 and hit.Position.Y > hrp.Position.Y - 6 then
			local g = hit.Position
			local eye = g + up * 3
			local ok = viewIsClear(eye, g - d * 16 + r * 6 + up * 7) and viewIsClear(eye, g - d * 20 + r * 6 + up * 5)
				and viewIsClear(eye, g + up * 12) and viewIsClear(eye, g + d * 6 + up * 3)
			-- graves the unit leaves (hops or walks out): the hero shot is taken further forward, check that view too
			local sd = (hopOut or (isDoor and template:GetAttribute("WalkOut")) or 0) * graveScale
			if ok and sd > 0 then
				ok = viewIsClear(g - d * sd + up * 3, g - d * (sd + 15) + r * 6 + up * 4)
			end
			-- the camera spots: arriving, close, the hero shot and both ends of its sway
			if ok then
				local s0 = g - d * sd
				for _, spot in ipairs({ g - d * 16 + r * 6 + up * 7, g - d * 10 + r * 3.5 + up * 4.5,
					s0 - d * 14 + r * 6 + up * 4, s0 - d * 12 + r * 12.4 + up * 4, s0 - d * 12 - r * 2.2 + up * 4 }) do
					if not spotIsFree(spot) then
						ok = false
						break
					end
				end
			end
			if ok and isSummon then
				-- the summon also needs flat floor where the circle opens, a clear side and low view of it, and open sky
				local c = g - d * 12
				local cHit = Workspace:Raycast(c + up * 20, Vector3.new(0, -60, 0), rayParams)
				ok = cHit ~= nil and math.abs(cHit.Position.Y - g.Y) < 1 and viewIsClear(eye, c + up * 3)
					and viewIsClear(c + up * 2, c + r * 17 - d * 4 + up * 6)
					and viewIsClear(c + up * 2, c - d * 15 + r * 6 + up * 2.2)
					and viewIsClear(c + up * 3, c + up * 80)
			end
			if ok then
				dir, right, G = d, r, g
				break
			end
		end
	end
	if not G then
		dir = lookDir
		right = Vector3.new(-dir.Z, 0, dir.X)
		G = hrp.Position + dir * graveDistance - Vector3.new(0, 3, 0) -- (about where the floor is under the character)
		local hum = player.Character:FindFirstChildOfClass("Humanoid")
		if hum then
			G = hrp.Position + dir * graveDistance - Vector3.new(0, hum.HipHeight + hrp.Size.Y / 2, 0)
		end
	end

	local fxFolder = Instance.new("Folder")
	fxFolder.Name = "GraveCinematicFX"
	fxFolder.Parent = Workspace

	-- ── The grave: its front towards the camera, the pit's centre (Core) on G ──
	local model = template:Clone()
	model:ScaleTo(graveScale)
	local facing = CFrame.lookAt(G, G - dir) -- -Z (the grave's front) looks back towards the player / camera
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
	local grave = GraveOpening.attach(model, { scale = graveScale, world = true })
	-- doors: the unit starts on the chamber floor at the Core and walks out to `stand`; `focus` is where it is now
	local floorLift = (isDoor or hopOut) and (template:GetAttribute("FloorHeight") or 0) * graveScale or 0
	local stand = isDoor and (G - dir * (template:GetAttribute("WalkOut") or 5) * graveScale)
		or hopOut and (G - dir * hopOut * graveScale) or G
	-- how high the hop arcs above the straight line: clears the walls (WallTop) with a little room
	local hopArc = hopOut and ((template:GetAttribute("WallTop") or 1.5) - (template:GetAttribute("FloorHeight") or 0)) * graveScale + 0.8 or 0
	local focus = G
	-- the summon circle: on the ground in front of the grave, big enough for the unit
	local circleRadius = math.max(3.2, unitTall * 0.55)
	local circleAt = G - dir * (math.max(graveSize.X, graveSize.Z) * 0.5 + circleRadius + 1)
	if isSummon then
		stand = circleAt
		focus = circleAt
	end

	-- light leaking out of the cracks during the buildup
	local leakHolder = Instance.new("Part")
	leakHolder.Anchored = true
	leakHolder.CanCollide = false
	leakHolder.CanQuery = false
	leakHolder.CanTouch = false
	leakHolder.Transparency = 1
	leakHolder.Size = Vector3.one * 0.5
	leakHolder.CFrame = CFrame.new(G + up * 2)
	leakHolder.Parent = fxFolder
	local leak = Instance.new("PointLight")
	leak.Range = 16
	leak.Brightness = 0
	leak.Shadows = false
	leak.Parent = leakHolder
	-- the rumble while the grave pushes up and shakes (stops at the burst)
	local rumbleSfx = Sfx.loop("rumble", leakHolder)
	-- dust when the grave pushes up, pebbles jumping during the buildup
	local function puff(texture, count, c0, c1, size0, size1, life, speed)
		local e = Instance.new("ParticleEmitter")
		e.Texture = texture
		e.Color = ColorSequence.new(c0, c1)
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size0), NumberSequenceKeypoint.new(1, size1) })
		e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1) })
		e.Lifetime = NumberRange.new(life * 0.6, life)
		e.Speed = NumberRange.new(speed * 0.4, speed)
		e.SpreadAngle = Vector2.new(80, 80)
		e.Drag = 2
		e.Rate = 0
		e.Parent = leakHolder
		e:Emit(count)
		return e
	end

	-- ── Take over camera, controls and the UI ────────────────
	local saved = { cameraType = camera.CameraType, fov = camera.FieldOfView, guiEnabled = mainGui.Enabled }
	local controls
	pcall(function()
		controls = require(player.PlayerScripts:WaitForChild("PlayerModule", 2)):GetControls()
		controls:Disable()
	end)
	mainGui.Enabled = false
	-- every other ScreenGui of the game is switched off (there is more than one), restored at the end
	local hiddenGuis = {}
	for _, g in ipairs(player:WaitForChild("PlayerGui"):GetChildren()) do
		if g:IsA("ScreenGui") and g.Enabled and g.Name ~= "Freecam" then
			g.Enabled = false
			table.insert(hiddenGuis, g)
		end
	end
	camera.CameraType = Enum.CameraType.Scriptable
	local function hideCharacter(hidden)
		local c = player.Character
		if not c then return end
		for _, d in ipairs(c:GetDescendants()) do
			if d:IsA("BasePart") or d:IsA("Decal") then
				d.LocalTransparencyModifier = hidden and 1 or 0
			end
		end
	end
	hideCharacter(true)
	local startCam = camera.CFrame

	-- black bars, flash, name, rarity, Skip and Continue
	local ui = Instance.new("ScreenGui")
	ui.Name = "GraveCinematicUI"
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
	flash.BackgroundColor3 = Color3.new(1, 1, 1):Lerp(bestColor, 0.3)
	flash.BackgroundTransparency = 1
	flash.BorderSizePixel = 0
	flash.ZIndex = 5
	flash.Parent = ui
	local nameLbl = Instance.new("TextLabel")
	nameLbl.AnchorPoint = Vector2.new(0.5, 1)
	nameLbl.Position = UDim2.fromScale(0.5, 0.86)
	nameLbl.Size = UDim2.fromOffset(700, 54)
	nameLbl.BackgroundTransparency = 1
	nameLbl.Font = Enum.Font.FredokaOne
	nameLbl.TextSize = 44
	nameLbl.TextColor3 = bestColor
	nameLbl.TextStrokeColor3 = Color3.new(0, 0, 0)
	nameLbl.TextTransparency = 1
	nameLbl.TextStrokeTransparency = 1
	nameLbl.Text = best.unitType
	SignatureName.apply(nameLbl, best.unitType)
	nameLbl.ZIndex = 6
	nameLbl.Parent = ui
	local rarityLbl = nameLbl:Clone()
	rarityLbl.Position = UDim2.fromScale(0.5, 0.9)
	rarityLbl.TextSize = 24
	rarityLbl.Text = string.upper(best.rarity)
	if Units.isSignature(best.unitType) then
		local sc = Units.SIGNATURE_COLOR
		rarityLbl.RichText = true
		rarityLbl.Text = string.upper(best.rarity) .. string.format('  <font color="rgb(%d,%d,%d)">SIGNATURE</font>', sc.R * 255, sc.G * 255, sc.B * 255)
	end
	rarityLbl.Parent = ui
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
	local done = false
	local connection, keyConn
	local burst, risen = false, false
	local unit, unitRootHeight, arrived
	local unitParts, unitGlow -- the summon: the unit's parts (materializing) and its glow
	local shakeAmount, shakeStart = 0, 0
	local flashStart

	local function finish()
		if done then
			return
		end
		done = true
		rumbleSfx.stop(0)
		if connection then connection:Disconnect() end
		if keyConn then keyConn:Disconnect() end
		grave.stop()
		if unit then
			CollectionService:RemoveTag(unit, PROP_TAG)
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
		if controls then
			pcall(function() controls:Enable() end)
		end
		GraveCinematic.active = false
		if opts.onDone then
			opts.onDone()
		end
	end
	skipBtn.button.Activated:Connect(finish)
	local function continue()
		if endTime == math.huge and continueBtn.root.Visible then
			endTime = T + 0.5
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

	-- framing the risen unit (floating units included)
	local HERO_FOV = 50
	local heroLookY = math.max(3, unitTall * 0.55)
	local heroDist = math.max(14, (unitTall * 0.5 + 2) / math.tan(math.rad(HERO_FOV / 2)) * 1.15)
	local heroCamY = math.max(3.5, unitTall * 0.4)

	local function spawnUnit()
		local folder = ReplicatedStorage:FindFirstChild("UnitModels")
		local tpl = folder and folder:FindFirstChild(best.unitType)
		if not tpl then
			return
		end
		local m = tpl:Clone()
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
		local root = m.PrimaryPart or m:FindFirstChild("HumanoidRootPart", true)
		if not root then
			m:Destroy()
			return
		end
		root.Anchored = true
		local def = Units.Stats[best.unitType]
		local scale = def and (def.size.X / 2 * 0.9) or 1
		m:ScaleTo(scale)
		local rootHeight = (m:GetAttribute("RootHeight") or 2.2) * scale
		unitRootHeight = rootHeight
		m:SetAttribute("AttackStyle", nil)
		if isSummon then
			-- materializes on the circle: every part starts invisible (shown from the feet up), a glow wraps it
			local at = stand + up * rootHeight
			m:PivotTo(CFrame.lookAt(at, at - dir))
			m:SetAttribute("State", "idle")
			unitParts = {}
			for _, d in ipairs(m:GetDescendants()) do
				if d:IsA("BasePart") then
					d.LocalTransparencyModifier = 1
					table.insert(unitParts, d)
				end
			end
			unitGlow = Instance.new("Highlight")
			unitGlow.FillColor = bestColor
			unitGlow.OutlineColor = Color3.new(1, 1, 1):Lerp(bestColor, 0.3)
			unitGlow.FillTransparency = 0.05
			unitGlow.OutlineTransparency = 0
			unitGlow.DepthMode = Enum.HighlightDepthMode.Occluded
			unitGlow.Adornee = m
			unitGlow.Parent = m
		elseif isDoor then
			local at = G + up * (rootHeight + floorLift)
			m:PivotTo(CFrame.lookAt(at, at - dir))
			m:SetAttribute("State", "walk")
			m:SetAttribute("Speed", 4)
		else
			local at = G + up * (rootHeight + floorLift)
			m:PivotTo(CFrame.lookAt(at, at - dir))
			m:SetAttribute("State", "idle")
			if not unitInside then
				m:SetAttribute("RiseTime", T_RISE)
				m:SetAttribute("RiseStart", Workspace:GetServerTimeNow())
			end
		end
		m.Parent = fxFolder
		CollectionService:AddTag(m, PROP_TAG)
		unit = m
	end

	-- camera positions
	-- crypts and tall graves (the floating Void Sanctum) get a wider camera
	local zoom = isDoor and graveScale / GRAVE_SCALE * 1.25 or math.max(1, graveSize.Y / 7)
	local camArrive = G + (-dir * 16 + right * 6 + up * 7) * zoom
	local camClose = G + (-dir * 10 + right * 3.5 + up * 4.5) * zoom
	local camHero = stand - dir * heroDist + right * 6 + up * heroCamY
	local lookGrave = G + up * (isDoor and graveSize.Y * 0.35 or math.max(1.6 * graveScale, graveSize.Y * 0.35))
	local grey = Color3.fromRGB(150, 150, 160)

	-- ── The summon (OpenStyle "Summon") ─────────────────────
	local SKY_HEIGHT = 62
	local skyPoint = circleAt + up * SKY_HEIGHT
	local graveMid = G + up * graveSize.Y * 0.45
	local camCast = circleAt:Lerp(G, 0.4) + right * (circleRadius * 2 + 10) - dir * 8 + up * 6
	local camLow = circleAt - dir * (circleRadius + 11) + right * 6 + up * 2.2
	local summon
	local function fxPart(shape, color, transparency)
		local p = Instance.new("Part")
		p.Shape = shape
		p.Material = Enum.Material.Neon
		p.Color = color
		p.Transparency = transparency
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Size = Vector3.one * 0.2
		p.Parent = fxFolder
		return p
	end
	-- a cylinder from a to b (hidden when too short)
	local function segment(p, a, b, width, transparency)
		if (b - a).Magnitude < 0.05 or width < 0.02 then
			p.Transparency = 1
			return
		end
		p.Size = Vector3.new((b - a).Magnitude, width, width)
		p.CFrame = CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.rad(90), 0)
		p.Transparency = transparency
	end
	local function startSummon()
		local accent = bestColor:Lerp(Color3.new(1, 1, 1), 0.45)
		summon = {
			circle = MagicCircle.build(fxFolder, circleRadius, bestColor, accent),
			sky = MagicCircle.build(fxFolder, 14, bestColor, accent),
			line = fxPart(Enum.PartType.Cylinder, accent, 1),
			beam = fxPart(Enum.PartType.Cylinder, bestColor, 1),
			core = fxPart(Enum.PartType.Cylinder, Color3.new(1, 1, 1):Lerp(bestColor, 0.25), 1),
			orb = fxPart(Enum.PartType.Ball, Color3.new(1, 1, 1):Lerp(bestColor, 0.4), 1),
			shock = fxPart(Enum.PartType.Cylinder, accent, 1),
		}
		local skyLight = Instance.new("PointLight")
		skyLight.Color = bestColor
		skyLight.Range = 40
		skyLight.Brightness = 0
		skyLight.Shadows = false
		skyLight.Parent = summon.orb
		summon.skyLight = skyLight
		local holder = fxPart(Enum.PartType.Ball, bestColor, 1)
		holder.CFrame = CFrame.new(circleAt + up * 1.5)
		local groundLight = Instance.new("PointLight")
		groundLight.Color = bestColor
		groundLight.Range = 26
		groundLight.Brightness = 0
		groundLight.Shadows = false
		groundLight.Parent = holder
		summon.groundLight = groundLight
		grave.setGlow(bestColor, 1)
		flashStart = { at = os.clock(), length = 0.35 }
		flash.BackgroundTransparency = 0.55
		shakeAmount, shakeStart = 0.35, os.clock()
	end
	local function updateSummon()
		local sm = summon
		-- the circle on the ground opens, turns, and fades out a while after the unit is there
		local castK = smooth((T - SUMMON_CAST) / 0.9)
		local fadeOut = math.clamp((T - SUMMON_HIT - 1.8) / 1.2, 0, 1)
		MagicCircle.place(sm.circle, CFrame.new(circleAt + up * 0.12) * CFrame.Angles(0, T * 0.5, 0), 0.3 + 0.7 * castK,
			1 - castK * 0.9 + fadeOut * 0.9)
		-- the cast: a thread of light from the grave down to the circle
		local lineK = (T - SUMMON_CAST) / 0.9
		segment(sm.line, graveMid, circleAt + up * 0.2, 0.25 * (1 - math.clamp(lineK, 0, 1)) + 0.04,
			lineK < 1.2 and 0.2 + 0.6 * math.clamp(lineK, 0, 1) or 1)
		-- the sky: a second circle and an orb of light gathering high above, drained by the beam
		local strikeK = math.clamp((T - SUMMON_STRIKE) / (SUMMON_HIT - SUMMON_STRIKE), 0, 1)
		local after = math.max(0, T - SUMMON_HIT)
		if T >= SUMMON_SKY then
			local skyK = smooth((T - SUMMON_SKY) / 1.2)
			local skyFade = math.clamp(after / 1.4, 0, 1)
			MagicCircle.place(sm.sky, CFrame.new(skyPoint) * CFrame.Angles(0, -T * 1.6, 0), 0.4 + 0.6 * skyK, 1 - skyK * 0.85 + skyFade * 0.85)
			local pulse = 1 + 0.1 * math.sin(T * 28)
			sm.orb.Size = Vector3.one * (0.8 + 10 * skyK) * pulse * (1 - 0.7 * strikeK)
			sm.orb.CFrame = CFrame.new(skyPoint)
			sm.orb.Transparency = 0.1 + 0.9 * skyFade
			sm.skyLight.Brightness = 6 * skyK * (1 - skyFade)
		end
		-- the strike: the beam shoots down faster and faster, burns, then thins out
		if T >= SUMMON_STRIKE then
			local tip = skyPoint:Lerp(circleAt, strikeK ^ 1.7)
			local width = circleRadius * 1.3 * (after < 0.5 and (1 + 0.3 * (1 - after / 0.5)) or math.max(0, 1 - (after - 0.5) / 1.0))
			segment(sm.beam, skyPoint, tip, width, 0.35)
			segment(sm.core, skyPoint, tip, width * 0.45, 0.1)
		end
		if T >= SUMMON_HIT and not sm.hit then
			sm.hit = true
			flashStart = { at = os.clock(), length = 0.6 + 0.3 * t }
			flash.BackgroundTransparency = 0.05
			shakeAmount, shakeStart = 1.0 + 0.8 * t, os.clock()
			leakHolder.CFrame = CFrame.new(circleAt + up * 0.6)
			puff("rbxasset://textures/particles/smoke_main.dds", 26, grey:Lerp(bestColor, 0.4), Color3.fromRGB(60, 56, 66), 2, 6, 2, 16)
			puff("rbxasset://textures/particles/sparkles_main.dds", 50, Color3.new(1, 1, 1), bestColor, 0.8, 0, 1.6, 22)
		end
		if sm.hit then
			-- a shock ring racing out over the ground, the ground light fading
			local k = math.clamp(after / 0.7, 0, 1)
			local d = circleRadius * (1.2 + 5 * k)
			sm.shock.Size = Vector3.new(0.12, d, d)
			sm.shock.CFrame = CFrame.new(circleAt + up * 0.2) * CFrame.Angles(0, 0, math.rad(90))
			sm.shock.Transparency = 0.2 + 0.8 * k
			sm.groundLight.Brightness = 8 * math.max(0, 1 - after / 2.5)
		end
	end

	-- ── Per-frame timeline ───────────────────────────────────
	connection = RunService.RenderStepped:Connect(function(dt)
		if done then
			return
		end
		T += dt
		hideCharacter(true)
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

		-- ── The grave ───────────────────────────────────────
		if T < START_BUILD then
			-- pushes up out of the ground with a rumble
			local k = smooth(T / (T_ARRIVE * 0.85))
			local rumble = (1 - k) * 0.12 * graveScale
			model:PivotTo((rest - up * (graveSize.Y + 0.5) * (1 - k)) * CFrame.new((math.random() - 0.5) * rumble, 0, (math.random() - 0.5) * rumble))
			if T - dt <= 0 then
				puff("rbxasset://textures/particles/smoke_main.dds", 24, Color3.fromRGB(150, 130, 110), Color3.fromRGB(70, 62, 60), 2, 7, 2, 14)
			end
			shakeAmount, shakeStart = 0.12 * (1 - k), os.clock()
			rumbleSfx.set(0.35 + 0.65 * (1 - k), 0.85)
		elseif not burst then
			local p = math.clamp((T - START_BUILD) / T_BUILD, 0, 1)
			local silent = fake and p > 0.84
			local amp = (0.03 + 0.2 * p * (0.5 + t)) * graveScale * (silent and 0.15 or 1)
			model:PivotTo(rest * CFrame.new((math.random() - 0.5) * amp, 0, (math.random() - 0.5) * amp)
				* CFrame.Angles(0, 0, (math.random() - 0.5) * amp * 0.08))
			local hint = math.clamp((p - 0.2) / 0.8, 0, 1)
			local amount = silent and 0 or hint ^ 2 * (0.55 + 0.45 * t)
			grave.setGlow(bestColor, amount)
			leak.Color = grey:Lerp(bestColor, amount)
			leak.Brightness = silent and 0 or (0.5 + 3 * p) * (0.8 + 0.4 * math.sin(T * (8 + 20 * p)))
			if math.random() < dt * (3 + 10 * p) then
				puff("rbxasset://textures/particles/smoke_main.dds", 2, Color3.fromRGB(120, 100, 84), Color3.fromRGB(70, 62, 60), 0.8, 2.5, 0.8, 6)
			end
			shakeAmount, shakeStart = 0.04 + 0.12 * p * p, os.clock()
			-- louder and a little higher as it shakes harder; silent in the fake-out before big bursts
			rumbleSfx.set(silent and 0 or (0.3 + 0.7 * p) * (0.8 + 0.4 * t), 0.88 + 0.25 * p)
			if p >= 1 then
				rumbleSfx.stop(0.3)
			end
			if p >= 1 and isSummon then
				burst = true -- (no burst: the summon starts)
				model:PivotTo(rest)
				leak.Brightness = 0
				startSummon()
			elseif p >= 1 then
				burst = true
				model:PivotTo(rest)
				leak.Brightness = 0
				grave.burst(bestColor, t)
				flashStart = { at = os.clock(), length = 0.45 + 0.4 * t }
				flash.BackgroundTransparency = 0.1
				shakeAmount, shakeStart = 1.0 + 1.0 * t, os.clock()
			end
		end

		if summon then
			updateSummon()
		end

		-- ── The unit ────────────────────────────────────────
		if burst and not risen and T >= START_RISE then
			risen = true
			spawnUnit()
		end
		if risen and isSummon and unitParts then
			-- materializes from the feet up out of the beam's light, the glow fading as the real colours come through
			local k = (T - START_RISE) / 1.5
			local footY = stand.Y
			for _, p in ipairs(unitParts) do
				local h = (p.Position.Y - footY) / math.max(1, unitTall)
				p.LocalTransparencyModifier = 1 - math.clamp(k * 1.6 - h * 0.6, 0, 1)
			end
			if unitGlow then
				unitGlow.FillTransparency = 0.05 + 0.95 * math.clamp((k - 0.5) / 0.8, 0, 1)
				unitGlow.OutlineTransparency = math.clamp((k - 0.8) / 0.8, 0, 1)
				if k >= 1.7 then
					unitGlow:Destroy()
					unitGlow = nil
				end
			end
			if k >= 1.7 then
				for _, p in ipairs(unitParts) do
					p.LocalTransparencyModifier = 0
				end
				unitParts = nil
			end
		end
		if risen and isDoor and unit and unit.Parent then
			-- walks out of the dark chamber, steps down over the fallen door and stops in front of it
			local k = math.clamp((T - START_RISE) / T_RISE, 0, 1)
			local f = 1.25 * k - 0.25 * k * k
			local lift = floorLift * (1 - smooth(math.clamp((k - 0.35) / 0.4, 0, 1)))
			focus = G:Lerp(stand, f)
			local at = focus + up * (unitRootHeight + lift)
			unit:PivotTo(CFrame.lookAt(at, at - dir))
			if k >= 1 and not arrived then
				arrived = true
				unit:SetAttribute("State", "idle")
				shakeAmount, shakeStart = 0.35, os.clock()
				leakHolder.CFrame = CFrame.new(stand + up * 0.4)
				puff("rbxasset://textures/particles/smoke_main.dds", 16, grey:Lerp(bestColor, 0.4), Color3.fromRGB(60, 56, 66), 1.2, 4, 1.4, 9)
			end
		end
		-- box graves (HopOut): once risen the unit jumps out over the front wall and lands in front of the grave
		if risen and hopOut and unit and unit.Parent then
			local h = (T - START_RISE - T_RISE * 0.95) / HOP_TIME
			if h > 0 then
				h = math.clamp(h, 0, 1)
				focus = G:Lerp(stand, smooth(h))
				local at = focus + up * (unitRootHeight + floorLift * (1 - h) + 4 * h * (1 - h) * hopArc)
				unit:PivotTo(CFrame.lookAt(at, at - dir))
				if h >= 1 and not arrived then
					arrived = true
					shakeAmount, shakeStart = 0.3, os.clock()
					leakHolder.CFrame = CFrame.new(stand + up * 0.4)
					puff("rbxasset://textures/particles/smoke_main.dds", 14, grey:Lerp(bestColor, 0.4), Color3.fromRGB(60, 56, 66), 1.2, 4, 1.4, 9)
				end
			end
		end
		if risen then
			local k = smooth((T - START_RISE - T_RISE * 0.55) / 0.7)
			nameLbl.TextTransparency = 1 - k
			nameLbl.TextStrokeTransparency = 1 - k
			rarityLbl.TextTransparency = 1 - k
			rarityLbl.TextStrokeTransparency = 1 - k
		end

		-- ── Camera ──────────────────────────────────────────
		local camPos, camLook, fov
		if not burst then
			local k = smooth(T / START_BURST)
			local fromStart = smooth(T / 0.8)
			local path = camArrive:Lerp(camClose, k)
			camPos = startCam.Position:Lerp(path, fromStart)
			camLook = (startCam.Position + startCam.LookVector * 20):Lerp(lookGrave, fromStart)
			fov = 62 - 10 * k
		elseif isSummon and T < START_HERO then
			if T < SUMMON_SKY then
				-- the cast: swing round to a side view of the grave and the opening circle
				local k = smooth((T - SUMMON_CAST) / 1.2)
				camPos = camClose:Lerp(camCast, k)
				camLook = lookGrave:Lerp(circleAt:Lerp(G, 0.35) + up * 2, k)
				fov = 52 + 8 * k
			elseif T < SUMMON_STRIKE then
				-- down low by the circle, tilting up to the beam gathering in the sky
				local k = smooth((T - SUMMON_SKY) / 1.0)
				camPos = camCast:Lerp(camLow, k)
				camLook = (circleAt:Lerp(G, 0.35) + up * 2):Lerp(skyPoint, k)
				fov = 60 + 6 * k
			elseif T < SUMMON_HIT + 0.2 then
				-- the strike: the camera follows the beam's tip down to the circle
				local k = math.clamp((T - SUMMON_STRIKE) / (SUMMON_HIT + 0.2 - SUMMON_STRIKE), 0, 1)
				camPos = camLow
				camLook = skyPoint:Lerp(circleAt + up * 1.5, smooth(k) ^ 0.8)
				fov = 66 - 8 * k
			else
				-- the unit materializes: ease in to the hero shot
				local k = smooth((T - SUMMON_HIT - 0.2) / (START_HERO - SUMMON_HIT - 0.2))
				camPos = camLow:Lerp(camHero, k)
				camLook = (circleAt + up * 1.5):Lerp(stand + up * heroLookY, k)
				fov = 58 + (HERO_FOV - 58) * k
			end
		elseif T < START_HERO then
			local k = smooth((T - START_BURST - 0.25) / 1.5)
			camPos = camClose:Lerp(camHero, k)
			local riseK = (isDoor or unitInside) and 1 or smooth((T - START_RISE) / T_RISE)
			camLook = lookGrave:Lerp(focus + up * (2 + (heroLookY - 2) * riseK), k)
			fov = 52 + (HERO_FOV + 4 - 52) * k
		else
			-- a slow sway round the unit, never a full orbit (it would end up behind the unit or inside the grave)
			local orbit = 0.55 * math.sin((T - START_HERO) * 0.12 / 0.55)
			local riseK = (isDoor or isSummon or unitInside) and 1 or smooth((T - START_RISE) / T_RISE)
			camPos = stand + (dir * -heroDist) * math.cos(orbit) + right * (6 * math.cos(orbit) + 14 * math.sin(orbit)) + up * heroCamY
			camLook = focus + up * (2 + (heroLookY - 2) * riseK)
			fov = HERO_FOV + 4 - 4 * riseK
		end
		local shake = shakeAmount * math.exp(-(os.clock() - shakeStart) * (burst and 3.5 or 12))
		local jitter = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 2 * shake
		camera.CFrame = CFrame.lookAt(camPos + jitter, camLook + jitter * 0.5)
		camera.FieldOfView = fov
	end)
	return true
end

return GraveCinematic
