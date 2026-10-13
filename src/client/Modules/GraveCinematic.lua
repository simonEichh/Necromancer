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

	local T_ARRIVE = 1.1 -- the grave pushes up out of the ground
	local T_BUILD = 1.2 + 1.4 * t -- it shakes and glows
	local T_RISE = 2.0 + 0.8 * t -- the unit climbs out
	local START_BUILD = T_ARRIVE
	local START_BURST = START_BUILD + T_BUILD
	local START_RISE = START_BURST + 0.45
	local START_HERO = START_BURST + 1.8 -- from here the camera only orbits slowly
	local HOLD_AT = START_RISE + T_RISE
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
	local flatLook = Vector3.new(hrp.CFrame.LookVector.X, 0, hrp.CFrame.LookVector.Z)
	local lookDir = flatLook.Magnitude > 0.1 and flatLook.Unit or Vector3.new(0, 0, -1)
	local dir, right, G
	for _, degrees in ipairs({ 0, 45, -45, 90, -90, 135, -135, 180 }) do
		local a = math.rad(degrees)
		local d = Vector3.new(lookDir.X * math.cos(a) - lookDir.Z * math.sin(a), 0, lookDir.X * math.sin(a) + lookDir.Z * math.cos(a))
		local r = Vector3.new(-d.Z, 0, d.X)
		local hit = Workspace:Raycast(hrp.Position + d * GRAVE_DISTANCE + up * 20, Vector3.new(0, -60, 0), rayParams)
		-- the floor under the character (not a unit, a drop or a wall top): a little below the character's root
		if hit and hit.Normal.Y > 0.9 and hit.Position.Y < hrp.Position.Y - 1.5 and hit.Position.Y > hrp.Position.Y - 6 then
			local g = hit.Position
			local eye = g + up * 3
			if viewIsClear(eye, g - d * 16 + r * 6 + up * 7) and viewIsClear(eye, g - d * 20 + r * 6 + up * 5)
				and viewIsClear(eye, g + up * 12) and viewIsClear(eye, g + d * 6 + up * 3) then
				dir, right, G = d, r, g
				break
			end
		end
	end
	if not G then
		dir = lookDir
		right = Vector3.new(-dir.Z, 0, dir.X)
		G = hrp.Position + dir * GRAVE_DISTANCE - Vector3.new(0, 3, 0) -- (about where the floor is under the character)
		local hum = player.Character:FindFirstChildOfClass("Humanoid")
		if hum then
			G = hrp.Position + dir * GRAVE_DISTANCE - Vector3.new(0, hum.HipHeight + hrp.Size.Y / 2, 0)
		end
	end

	local fxFolder = Instance.new("Folder")
	fxFolder.Name = "GraveCinematicFX"
	fxFolder.Parent = Workspace

	-- ── The grave: its front towards the camera, the pit's centre (Core) on G ──
	local model = template:Clone()
	model:ScaleTo(GRAVE_SCALE)
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
	local grave = GraveOpening.attach(model, { scale = GRAVE_SCALE, world = true })

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
	local unit
	local shakeAmount, shakeStart = 0, 0
	local flashStart

	local function finish()
		if done then
			return
		end
		done = true
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
	local unitTall = 5
	do
		local folder = ReplicatedStorage:FindFirstChild("UnitModels")
		local tpl = folder and folder:FindFirstChild(best.unitType)
		local def = Units.Stats[best.unitType]
		if tpl and tpl:GetAttribute("Height") then
			unitTall = tpl:GetAttribute("Height") * (def and (def.size.X / 2 * 0.9) or 1)
		end
	end
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
		m:PivotTo(CFrame.lookAt(G + up * rootHeight, G + up * rootHeight - dir))
		m:SetAttribute("AttackStyle", nil)
		m:SetAttribute("State", "idle")
		m:SetAttribute("RiseTime", T_RISE)
		m:SetAttribute("RiseStart", Workspace:GetServerTimeNow())
		m.Parent = fxFolder
		CollectionService:AddTag(m, PROP_TAG)
		unit = m
	end

	-- camera positions
	local camArrive = G - dir * 16 + right * 6 + up * 7
	local camClose = G - dir * 10 + right * 3.5 + up * 4.5
	local camHero = G - dir * heroDist + right * 6 + up * heroCamY
	local lookGrave = G + up * 1.6 * GRAVE_SCALE
	local grey = Color3.fromRGB(150, 150, 160)

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
			local rumble = (1 - k) * 0.12 * GRAVE_SCALE
			model:PivotTo((rest - up * (graveSize.Y + 0.5) * (1 - k)) * CFrame.new((math.random() - 0.5) * rumble, 0, (math.random() - 0.5) * rumble))
			if T - dt <= 0 then
				puff("rbxasset://textures/particles/smoke_main.dds", 24, Color3.fromRGB(150, 130, 110), Color3.fromRGB(70, 62, 60), 2, 7, 2, 14)
			end
			shakeAmount, shakeStart = 0.12 * (1 - k), os.clock()
		elseif not burst then
			local p = math.clamp((T - START_BUILD) / T_BUILD, 0, 1)
			local silent = fake and p > 0.84
			local amp = (0.03 + 0.2 * p * (0.5 + t)) * GRAVE_SCALE * (silent and 0.15 or 1)
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
			if p >= 1 then
				burst = true
				model:PivotTo(rest)
				leak.Brightness = 0
				grave.burst(bestColor, t)
				flashStart = { at = os.clock(), length = 0.45 + 0.4 * t }
				flash.BackgroundTransparency = 0.1
				shakeAmount, shakeStart = 1.0 + 1.0 * t, os.clock()
			end
		end

		-- ── The unit ────────────────────────────────────────
		if burst and not risen and T >= START_RISE then
			risen = true
			spawnUnit()
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
		elseif T < START_HERO then
			local k = smooth((T - START_BURST - 0.25) / 1.5)
			camPos = camClose:Lerp(camHero, k)
			local riseK = smooth((T - START_RISE) / T_RISE)
			camLook = lookGrave:Lerp(G + up * (2 + (heroLookY - 2) * riseK), k)
			fov = 52 + (HERO_FOV + 4 - 52) * k
		else
			local orbit = (T - START_HERO) * 0.12
			local riseK = smooth((T - START_RISE) / T_RISE)
			camPos = G + (dir * -heroDist) * math.cos(orbit) + right * (6 * math.cos(orbit) + 14 * math.sin(orbit)) + up * heroCamY
			camLook = G + up * (2 + (heroLookY - 2) * riseK)
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
