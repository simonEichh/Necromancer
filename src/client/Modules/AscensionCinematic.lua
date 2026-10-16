-- "The Ascension": the cinematic of a normal ascension (the Ascend button; the realm's last one through the portal gets
-- its own later). About 15 s, Skip. AscendPanel calls AscensionCinematic.play() instead of firing PlayerAscend itself.
--
--   1. (0-4 s) Before the broken gate, facing it and the front line: the necromancer opens the grimoire (as at a
--      pull) and draws every one of their units on the lane into it, the nearest first.
--   2. (4-7.5 s) The rite: the necromancer rises in a rune circle with one ring per ascension; "x1.5 DAMAGE" burns in
--      the air. At ASCEND_AT the client fires PlayerAscend("cinematic"): the server ascends (the run resets, the
--      keeper's hands return, units go back to their graves) but leaves the character where it is.
--   3. (7.5-11.5 s) The reward: the new grave slot's tombstone rises out of the earth; the newly unlocked grave tier's
--      model appears over the plot with its name.
--   4. (11.5-15 s) The realm answers: the camera looks down the lane to the outer wall; the crypt that the ascension
--      opened (server PlotLook) breaks open in a burst of green souls; the keeper's hands rise back over the wall.
--   5. A fade, and the character stands in the plaza (as after every ascension).
-- Camera, controls and the UI are taken over and restored like the other cinematics.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local mainGui = require(script.Parent.Gui)
local Theme = require(script.Parent.Theme)
local NecroRitual = require(script.Parent.NecroRitual)
local GraveOpening = require(script.Parent.GraveOpening)
local MagicCircle = require(script.Parent.MagicCircle)
local Sfx = require(script.Parent.Sfx)
local State = require(script.Parent.State)
local Economy = require(ReplicatedStorage.Shared.Economy)
local Graves = require(ReplicatedStorage.Shared.Graves)

local player = Players.LocalPlayer

local AscensionCinematic = {}
AscensionCinematic.active = false

-- ── Timeline (s) ──────────────────────────────────────────
local FADE = 0.45
local SOULS_FROM, SOULS_TO = 0.9, 3.6 -- the units dissolve one after another; each soul flies SOUL_FLIGHT s
local SOUL_FLIGHT = 1.3
local RITE_FROM = 4.0
local ASCEND_AT = 5.0 -- the server ascends here
local TEXT_FROM = 5.2
local REWARD_FROM = 7.6
local REALM_FROM = 11.6
local CRYPT_AT = 12.6
local END_AT = 15.4

local GOLD = Color3.fromRGB(255, 196, 110)
local VIOLET = Color3.fromRGB(150, 110, 240)
local SOUL = Color3.fromRGB(120, 255, 170)
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"

local function smooth(x)
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
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
local function burst(parent, pos, color, count, speed)
	local holder = newPart(parent, Vector3.one * 0.3, CFrame.new(pos), color)
	holder.Transparency = 1
	local e = Instance.new("ParticleEmitter")
	e.Texture = SPARKLE
	e.Color = ColorSequence.new(Color3.new(1, 1, 1):Lerp(color, 0.4), color)
	e.LightEmission = 1
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(1, 0) })
	e.Lifetime = NumberRange.new(0.8, 1.8)
	e.Speed = NumberRange.new(speed * 0.5, speed)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Drag = 2
	e.Rate = 0
	e.Parent = holder
	e:Emit(count)
	local dust = Instance.new("ParticleEmitter")
	dust.Texture = SMOKE
	dust.Color = ColorSequence.new(Color3.fromRGB(140, 134, 126))
	dust.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 7) })
	dust.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1) })
	dust.Lifetime = NumberRange.new(1.2, 2.2)
	dust.Speed = NumberRange.new(4, 10)
	dust.SpreadAngle = Vector2.new(180, 30)
	dust.Drag = 2
	dust.Rate = 0
	dust.Parent = holder
	dust:Emit(math.floor(count / 2))
end

local function myPlot()
	local plots = Workspace:FindFirstChild("Plots")
	for _, plot in ipairs(plots and plots:GetChildren() or {}) do
		if plot:GetAttribute("OwnerId") == player.UserId then
			return plot
		end
	end
	return nil
end

-- returns false (and does nothing) when it cannot play: then the caller ascends the plain way.
-- opts.preview (the DEV panel): plays it without ascending
function AscensionCinematic.play(opts)
	opts = opts or {}
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local camera = Workspace.CurrentCamera
	local plot = myPlot()
	local base = plot and plot:FindFirstChild("Base")
	local remote = ReplicatedStorage:FindFirstChild("PlayerAscend")
	if AscensionCinematic.active or not (hrp and camera and base and remote) then
		return false
	end
	AscensionCinematic.active = true
	local up = Vector3.yAxis
	local plotIndex = tonumber(plot.Name:match("(%d+)$")) or 0
	local frame = base.CFrame * CFrame.new(0, base.Size.Y / 2, 0)
	local forward = Vector3.new(frame.LookVector.X, 0, frame.LookVector.Z).Unit -- (the Base's -Z points down the lane)
	local right = Vector3.new(-forward.Z, 0, forward.X)
	local plotCentre = frame.Position
	-- the rite happens where the run ended: just before the broken gate (the front the server fights at), the
	-- necromancer facing the fallen gate and the front line
	local stand = plotCentre + forward * 20
	local okWall, wallCF = pcall(function()
		return ReplicatedStorage:WaitForChild("GetWallPos", 2):InvokeServer()
	end)
	if okWall and typeof(wallCF) == "CFrame" then
		stand = Vector3.new(wallCF.Position.X, plotCentre.Y, wallCF.Position.Z)
	end
	local face = forward -- (facing the gate: the melee front line stands between him and it)
	local newCount = (State.rebirthCount or 0) + 1
	local fxFolder = Instance.new("Folder")
	fxFolder.Name = "AscensionFX"
	fxFolder.Parent = Workspace

	-- what the ascension brings: the new grave slot (5 + ascensions, at most 10) and the newly unlocked grave tier
	local newSlot = Economy.MAX_GRAVE_SLOTS and math.min(5 + newCount, Economy.MAX_GRAVE_SLOTS) or math.min(5 + newCount, 10)
	local slotSpot = 5 + newCount <= 10 and plot:FindFirstChild("GraveSpot" .. newSlot)
	local newTier, newTierName
	for key, g in pairs(Graves) do
		if g.unlockAscension == newCount then
			newTier, newTierName = key, g.name
		end
	end

	-- ── take over camera, controls and the UI ───────────────
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
	local savedAnchored = hrp.Anchored

	local ui = Instance.new("ScreenGui")
	ui.Name = "AscensionUI"
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
	local black = Instance.new("Frame")
	black.Size = UDim2.fromScale(1, 1)
	black.BackgroundColor3 = Color3.new(0, 0, 0)
	black.BackgroundTransparency = 1
	black.BorderSizePixel = 0
	black.ZIndex = 20
	black.Parent = ui
	local function label(y, h, font, color, text)
		local l = Instance.new("TextLabel")
		l.AnchorPoint = Vector2.new(0.5, 0.5)
		l.Position = UDim2.fromScale(0.5, y)
		l.Size = UDim2.fromScale(0.8, h)
		l.BackgroundTransparency = 1
		l.Font = font
		l.TextScaled = true
		l.TextColor3 = color
		l.TextStrokeColor3 = Color3.new(0, 0, 0)
		l.TextTransparency = 1
		l.TextStrokeTransparency = 1
		l.Text = text
		l.ZIndex = 6
		l.Parent = ui
		return l
	end
	local mult = Economy.damageMultiplier and Economy.damageMultiplier(newCount) or (1.5 ^ newCount)
	local bigLbl = label(0.22, 0.09, Enum.Font.Sarpanch, GOLD, string.format("x%.1f DAMAGE", 1.5))
	local subLbl = label(0.3, 0.045, Enum.Font.Garamond, Color3.fromRGB(220, 210, 190), "ASCENSION " .. newCount .. "   " .. string.format("%.1fx", mult) .. " in all")
	local rewardLbl = label(0.2, 0.06, Enum.Font.Sarpanch, Color3.fromRGB(232, 226, 210), "")
	local rewardSub = label(0.27, 0.04, Enum.Font.Garamond, Color3.fromRGB(200, 190, 170), "")
	local skipBtn = Theme.stoneButton(ui, {
		text = "Skip", color = "stone", size = UDim2.fromOffset(120, 40),
		position = UDim2.new(1, -24, 1, -20), anchor = Vector2.new(1, 1), zIndex = 8,
	})

	-- ── state ────────────────────────────────────────────────
	local T = 0
	local ascended = false
	local placed = false
	local done = false
	local connection
	local ritual
	local endAt = END_AT
	local function fireAscend()
		if not ascended then
			ascended = true
			if not opts.preview then
				remote:FireServer("cinematic")
			end
		end
	end

	-- the units: every one of the player's units on the lane
	local units = {}
	for _, m in ipairs(CollectionService:GetTagged("ProceduralUnit")) do
		if m.Parent and tostring(m:GetAttribute("OwnerId")) == tostring(player.UserId) and m:IsDescendantOf(Workspace) then
			local pos = m:GetPivot().Position
			if (pos - plotCentre):Dot(forward) > 22 then -- (on the lane, not on the graves)
				table.insert(units, { model = m, pos = pos })
			end
		end
	end
	table.sort(units, function(a, b) return (a.pos - stand).Magnitude < (b.pos - stand).Magnitude end) -- (the nearest first)
	for i, u in ipairs(units) do
		u.leaveAt = SOULS_FROM + (SOULS_TO - SOULS_FROM) * (#units > 1 and (i - 1) / (#units - 1) or 0)
		u.parts = {}
		for _, d in ipairs(u.model:GetDescendants()) do
			if d:IsA("BasePart") or d:IsA("Decal") then
				table.insert(u.parts, d)
			end
		end
	end
	-- every nameplate in the world (the units' name / DPS labels) is hidden for the whole cinematic
	local hiddenBoards = {}
	for _, d in ipairs(Workspace:GetDescendants()) do
		if d:IsA("BillboardGui") and d.Enabled then
			d.Enabled = false
			table.insert(hiddenBoards, d)
		end
	end
	-- shot 1 looks at the army from behind the necromancer: at the front line (the melee units), or at all of them
	local armyLook = stand + face * 30
	do
		local sum, n = Vector3.zero, 0
		for _, u in ipairs(units) do
			if (u.pos - stand).Magnitude < 25 then
				sum += u.pos
				n += 1
			end
		end
		if n == 0 then
			for _, u in ipairs(units) do
				sum += u.pos
				n += 1
			end
		end
		if n > 0 then
			armyLook = sum / n
		end
	end
	local function setUnitFade(u, f)
		for _, d in ipairs(u.parts) do
			if d.Parent then
				d.LocalTransparencyModifier = f
			end
		end
	end

	-- the rune circle: one ring per ascension (at most 9)
	local rings = {}
	for k = 1, math.min(newCount, 9) do
		local c = MagicCircle.build(fxFolder, 3.2 + k * 1.6, GOLD, VIOLET)
		c.appearAt = RITE_FROM + 0.35 + (k - 1) * 0.28
		c.angle = k * 0.7
		c.spin = (k % 2 == 0 and -1 or 1) * (0.5 + k * 0.08)
		table.insert(rings, c)
	end

	-- the crypts of the realm wall: which ones are open now (the ascension may open another one)
	local wall = Workspace:FindFirstChild("RealmWall_" .. plotIndex)
	local bays = {}
	for _, b in ipairs(wall and wall:GetDescendants() or {}) do
		if b:IsA("Model") and b:GetAttribute("CryptIndex") then
			local open = b:FindFirstChild("Open")
			local glow = open and open:FindFirstChild("CryptGlow")
			table.insert(bays, { model = b, wasOpen = glow and glow.Transparency < 1, glow = glow })
		end
	end
	local cryptBurstDone = false
	local function isOpenNow(bay)
		return bay.glow and bay.glow.Transparency < 1
	end
	-- (until CRYPT_AT a crypt the server just opened still looks sealed here, then it bursts open)
	local function holdCrypt(bay, hold)
		for _, version in ipairs(bay.model:GetChildren()) do
			local state = version:GetAttribute("CryptState")
			if state then
				for _, d in ipairs(version:GetDescendants()) do
					if d:IsA("BasePart") then
						if state == "Open" then
							d.LocalTransparencyModifier = hold and 1 or 0
						elseif hold then
							d.Transparency = d:GetAttribute("BaseTransparency") or 0
						else
							d.Transparency = 1
						end
					elseif d:IsA("Light") then
						if state == "Open" then
							d.Enabled = not hold
						end
					end
				end
			end
		end
	end

	-- the new tombstone (the server places it when it ascends) and the new tier's model
	local tombstone, tombRest
	local ritualTarget
	local tierModel
	local tierBase

	local lastCamPos, lastCamLook, lastFov
	local currentShot, blendFrom

	local function finish()
		if done then
			return
		end
		done = true
		fireAscend()
		if connection then
			connection:Disconnect()
		end
		for _, u in ipairs(units) do
			setUnitFade(u, 0)
		end
		for _, b in ipairs(hiddenBoards) do
			if b.Parent then
				b.Enabled = true
			end
		end
		for _, b in ipairs(bays) do
			if b.held then
				holdCrypt(b, false)
			end
		end
		if tombstone and tombRest then
			tombstone:PivotTo(tombRest)
		end
		if ritual then
			ritual.restore()
		end
		fxFolder:Destroy()
		ui:Destroy()
		-- to the plaza (as after every ascension)
		if hrp.Parent then
			local hub = Workspace:GetAttribute("HubSpawn") or Vector3.new(0, 3, 24)
			hrp.CFrame = CFrame.lookAt(hub, hub + Vector3.new(0, 0, -1))
			hrp.Anchored = savedAnchored
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
		AscensionCinematic.active = false
	end
	skipBtn.button.Activated:Connect(function()
		if T < endAt - FADE then
			endAt = T + FADE -- (a quick fade out, then the plaza)
		end
	end)

	Sfx.play("rune_confirm", nil, 0.8, 0.8)

	connection = RunService.RenderStepped:Connect(function(dt)
		if done then
			return
		end
		T += dt
		if T >= endAt then
			finish()
			return
		end
		-- into black, then out of it on the plot; into black again at the end
		if T < FADE then
			black.BackgroundTransparency = 1 - smooth(T / FADE)
		else
			black.BackgroundTransparency = 1 - math.max(1 - smooth((T - FADE) / FADE), smooth((T - (endAt - FADE)) / FADE))
		end
		if T >= FADE and not placed then
			-- (in the black: the character onto the plot, facing the lane)
			placed = true
			hrp.Anchored = true
			hrp.CFrame = CFrame.lookAt(stand + up * 3, stand + up * 3 + face)
			local hum = char:FindFirstChildOfClass("Humanoid")
			local feet = hrp.Position - Vector3.new(0, (hum and hum.HipHeight or 2) + hrp.Size.Y / 2, 0)
			local target = newPart(fxFolder, Vector3.one * 0.3, CFrame.new(stand + face * 60 + up * 8), GOLD)
			target.Transparency = 1
			ritual = NecroRitual.new({ hrp = hrp, folder = fxFolder, target = target, feet = feet, color = VIOLET })
			ritualTarget = target
		end
		local barSize = 0.11 * smooth((T - FADE) / 0.5)
		barTop.Size = UDim2.fromScale(1, barSize)
		barBottom.Size = UDim2.fromScale(1, barSize)
		if not placed then
			return
		end

		-- ── the necromancer: calls the souls, then rises in the rite ──
		local rise = smooth((T - RITE_FROM) / 2.2) * (1 - smooth((T - REWARD_FROM - 0.4) / 1.4))
		hrp.CFrame = CFrame.lookAt(stand + up * (3 + rise * 2.6), stand + up * (3 + rise * 2.6) + face)
		local weight = smooth((T - 0.6) / 0.6) * (1 - smooth((T - REWARD_FROM) / 0.8))
		ritual.update(weight, smooth((T - RITE_FROM) / 2), T < RITE_FROM and "forward" or "up")
		ritual.look(T < RITE_FROM and (stand + face * 50 + up * 4) or (stand + up * 30), smooth((T - 0.6) / 0.8))

		-- ── 1. the souls: the grimoire opens in the left hand and draws the units in one after another (as at a pull) ──
		local bookOpen = smooth((T - SOULS_FROM + 0.5) / 0.4) * (1 - smooth((T - RITE_FROM + 0.3) / 0.3))
		local bookAt = ritual.placeBook(bookOpen, bookOpen)
		if bookOpen > 0 then
			ritual.pose(weight, weight, true, "forward")
		end
		local pulling
		for _, u in ipairs(units) do
			local f = (T - u.leaveAt) / SOUL_FLIGHT
			if f > 0 and not u.ghost and not u.gone then
				-- (a client copy of the unit flies, the real one is hidden: the server owns it)
				local ok, ghost = pcall(function() return u.model:Clone() end)
				if ok and ghost then
					for _, d in ipairs(ghost:GetDescendants()) do
						if d:IsA("BaseScript") or d:IsA("BillboardGui") or d:IsA("ParticleEmitter") or d:IsA("Sound") then
							d:Destroy()
						elseif d:IsA("BasePart") then
							d.Anchored = true
							d.CanCollide = false
							d.CanQuery = false
							d.LocalTransparencyModifier = 0
						end
					end
					for _, tag in ipairs(CollectionService:GetTags(ghost)) do
						CollectionService:RemoveTag(ghost, tag)
					end
					ghost.Parent = fxFolder
					u.ghost = ghost
					u.ghostScale = ghost:GetScale()
					u.ghostFrom = ghost:GetPivot()
					local sparkle = Instance.new("ParticleEmitter")
					sparkle.Texture = SPARKLE
					sparkle.Color = ColorSequence.new(SOUL, Color3.new(1, 1, 1))
					sparkle.LightEmission = 1
					sparkle.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 0) })
					sparkle.Lifetime = NumberRange.new(0.3, 0.6)
					sparkle.Rate = 80
					sparkle.Speed = NumberRange.new(0.5, 2)
					sparkle.Parent = ghost.PrimaryPart or ghost:FindFirstChildWhichIsA("BasePart", true)
				else
					u.gone = true
				end
				setUnitFade(u, 1)
				burst(fxFolder, u.pos + up * 3, SOUL, 14, 8)
			end
			if u.ghost then
				if f >= 1 then
					u.ghost:Destroy()
					u.ghost = nil
					u.gone = true
					burst(fxFolder, bookAt, SOUL, 10, 5)
				else
					local pull = smooth(f)
					u.ghost:ScaleTo(math.max(0.02, u.ghostScale * (1 - 0.97 * pull)))
					local pos = u.ghostFrom.Position:Lerp(bookAt, pull) + up * math.sin(pull * math.pi) * 3
					u.ghost:PivotTo(CFrame.new(pos) * u.ghostFrom.Rotation * CFrame.Angles(0, pull * 8, 0))
					pulling = pos
				end
			end
		end

		-- (the ritual's threads reach for the souls he is pulling in, then up into the sky for the rite)
		if ritualTarget then
			local aimAt
			if T < RITE_FROM then
				aimAt = pulling or bookAt + face * 6
			else
				aimAt = stand + up * 30
			end
			local cur = ritualTarget.Position
			ritualTarget.CFrame = CFrame.new(cur:Lerp(aimAt, math.min(1, dt * 6)))
		end

		-- ── 2. the rite: the rune rings open round the necromancer's feet ──
		local feetPos = stand + up * (0.25 + rise * 2.6 * 0.5)
		for _, c in ipairs(rings) do
			if T >= c.appearAt then
				c.angle += c.spin * dt
				local open = smooth((T - c.appearAt) / 0.45)
				local fade = smooth((T - REWARD_FROM - 0.6) / 1.2)
				MagicCircle.place(c, CFrame.new(feetPos) * CFrame.Angles(0, c.angle, 0), 0.2 + 0.8 * open, math.max(1 - open, fade))
			end
		end
		if T >= ASCEND_AT then
			fireAscend()
		end
		local textIn = smooth((T - TEXT_FROM) / 0.7) * (1 - smooth((T - REWARD_FROM + 0.4) / 0.5))
		for _, l in ipairs({ bigLbl, subLbl }) do
			l.TextTransparency = 1 - textIn
			l.TextStrokeTransparency = 1 - textIn
		end
		for _, b in ipairs(bays) do
			-- (a crypt the ascension just opened: kept sealed here until its moment)
			if not b.wasOpen and not b.held and not cryptBurstDone and isOpenNow(b) then
				b.held = true
				holdCrypt(b, true)
			end
		end

		-- ── 3. the reward ──
		if slotSpot and ascended and not tombstone then
			-- the server's new tombstone at the new grave spot
			for _, d in ipairs(Workspace:GetChildren()) do
				if d:IsA("Model") and d.Name:find("Tombstone") and (d:GetPivot().Position - slotSpot.Position).Magnitude < 6 then
					tombstone = d
					tombRest = d:GetPivot()
					tombstone:PivotTo(tombRest - up * 7)
				end
			end
		end
		if T >= REWARD_FROM then
			local k = smooth((T - REWARD_FROM - 0.6) / 1.8)
			if tombstone and tombRest then
				local shake = (k > 0 and k < 1) and CFrame.new((math.random() - 0.5) * 0.25, 0, (math.random() - 0.5) * 0.25) or CFrame.identity
				tombstone:PivotTo((tombRest - up * 7 * (1 - k)) * shake)
				if k > 0 and not tombstone:GetAttribute("AscBurst") then
					tombstone:SetAttribute("AscBurst", true)
					burst(fxFolder, tombRest.Position + up * 0.5, GOLD, 20, 10)
					Sfx.play("rumble", nil, 0.6, 0.8)
				end
			end
			if newTier and not tierModel then
				local template = GraveOpening.template(newTier)
				if template then
					tierModel = template:Clone()
					tierModel:ScaleTo(1.6)
					tierBase = plotCentre + forward * 6 + up * 4
					tierModel:PivotTo(CFrame.new(tierBase - up * 30))
					for _, d in ipairs(tierModel:GetDescendants()) do
						if d:IsA("BasePart") then
							d.Anchored = true
							d.CanCollide = false
						end
					end
					tierModel.Parent = fxFolder
				end
			end
			if tierModel then
				local a = smooth((T - REWARD_FROM - 1.2) / 1.4)
				tierModel:PivotTo(CFrame.new(tierBase - up * 6 * (1 - a)) * CFrame.Angles(0, T * 0.6, 0))
				for _, d in ipairs(tierModel:GetDescendants()) do
					if d:IsA("BasePart") then
						d.LocalTransparencyModifier = 1 - a
					end
				end
			end
			local lines = {}
			if tombstone then
				table.insert(lines, "A NEW GRAVE")
			end
			if newTierName then
				table.insert(lines, string.upper(newTierName) .. " UNLOCKED")
			end
			rewardLbl.Text = lines[1] or ""
			rewardSub.Text = lines[2] or ""
			local rIn = smooth((T - REWARD_FROM - 1) / 0.6) * (1 - smooth((T - REALM_FROM + 0.4) / 0.5))
			for _, l in ipairs({ rewardLbl, rewardSub }) do
				l.TextTransparency = 1 - rIn
				l.TextStrokeTransparency = 1 - rIn
			end
		end

		-- ── 4. the realm answers: the new crypt bursts open ──
		if T >= CRYPT_AT and not cryptBurstDone then
			cryptBurstDone = true
			for _, b in ipairs(bays) do
				if b.held then
					holdCrypt(b, false)
					local pos = b.model:GetBoundingBox().Position
					burst(fxFolder, pos, SOUL, 50, 18)
					Sfx.play("gate_collapse", nil, 0.5, 1.3)
				end
			end
		end

		-- ── camera: four shots, each blending in from wherever the camera was ──
		local shot, camPos, camLook, fov
		local laneEnd = plotCentre + forward * 308 + up * 40
		if T < RITE_FROM then
			-- behind and above the necromancer, looking back up the lane at the army
			-- (a still, wide side shot: the necromancer and the army in front of him, drawn into the grimoire; not from
			-- behind him, that is inside the gate's portal)
			local mid = stand:Lerp(armyLook, 0.45)
			shot, camPos, camLook, fov = 1, mid + right * 24 + up * 9, mid + up * 2, 66
		elseif T < REWARD_FROM then
			-- slowly round the rising necromancer, low
			local a = (T - RITE_FROM) * 0.32 + 0.6
			shot = 2
			-- (far and high enough that the rune rings round the feet are in the frame)
			camPos = stand + (forward * math.cos(a) + right * math.sin(a)) * 18 + up * (7 + rise * 2)
			camLook = stand + up * (2.2 + rise * 2.6)
			fov = 58
		elseif T < REALM_FROM then
			-- the graves: the new tombstone rising, the new tier over the plot
			local focus = (slotSpot and slotSpot.Position) or (plotCentre + forward * 6)
			local side = (focus - plotCentre):Dot(right) >= 0 and -1 or 1
			shot = 3
			camPos = plotCentre + right * side * 6 + forward * 22 + up * 9
			camLook = focus:Lerp(plotCentre + forward * 6 + up * 4, 0.35) + up * 2
			fov = 62
		else
			-- down the lane to the outer wall: the crypts, the keeper's hands coming back
			shot, camPos, camLook, fov = 4, plotCentre + forward * 150 + right * 10 + up * 32, laneEnd, 64
		end
		if shot ~= currentShot then
			currentShot = shot
			blendFrom = lastCamPos and { pos = lastCamPos, look = lastCamLook, fov = lastFov, at = T } or nil
		end
		-- (a hard cut when the new shot is far away, e.g. from the gate to the graves, instead of a long sweep)
		if blendFrom and (camPos - blendFrom.pos).Magnitude > 120 then
			blendFrom = nil
		end
		if blendFrom and shot > 1 then
			local k = smooth((T - blendFrom.at) / 1.2)
			camPos = blendFrom.pos:Lerp(camPos, k)
			camLook = blendFrom.look:Lerp(camLook, k)
			fov = blendFrom.fov + (fov - blendFrom.fov) * k
		end
		lastCamPos, lastCamLook, lastFov = camPos, camLook, fov
		if camera.CameraType ~= Enum.CameraType.Scriptable then
			camera.CameraType = Enum.CameraType.Scriptable
		end
		camera.CFrame = CFrame.lookAt(camPos, camLook)
		camera.FieldOfView = fov
	end)
	return true
end

return AscensionCinematic
