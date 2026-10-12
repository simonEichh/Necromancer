-- The star summon: a cinematic, rendered in the 3D world, for a pull (replaces the overlay's build-up for rare pulls).
--
--   StarSummon.play(results, opts)
--     results: list of { unitType, rarity, pity, oneIn } from the server's RollResult (one entry per grave opened)
--     opts:    onDone  function(), called when the cinematic ends (also when it is skipped)
--              speed   playback speed (default 1; 0.25 = slow motion, for testing)
--
-- What you see: the camera looks up into the sky above a grave in front of you, one star per result lights up (tinted by
-- its rarity). The BEST star gets an aura in its rarity colour that swells, flares out and then comes crashing down: a
-- cut to a chase camera that zooms in on the star falling with fire and smoke, the star crashes on the grave
-- (shockwave, dust, debris, a crater, a white flash, a shaking camera) and the unit pulled rises out of the ground.
-- Everything scales smoothly with the rarity RANK (Rarities.Rank, t = 0 .. 1): bigger aura, longer fall, harder impact, so
-- new rarities work without changes here.
--
-- It only exists on the screen of the player who pulled: the camera is scripted, the controls and the UI are switched off
-- while it runs and everything is restored at the end. The skip button ends it at once. The unit models come from
-- ReplicatedStorage.UnitModels (tools/studio/publish_unit_models.lua); a unit without a model just does not appear.
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local GameData = require(script.Parent.GameData)
local mainGui = require(script.Parent.Gui)
local Rarities = require(ReplicatedStorage.Shared.Rarities)
local Units = require(ReplicatedStorage.Shared.Units)

local player = Players.LocalPlayer

local StarSummon = {}
StarSummon.active = false

-- ============================================================
-- Settings
-- ============================================================
local SKY_DISTANCE = 520 -- how far away the stars hang
local STAR_ELEVATION = math.rad(38) -- the middle of the star field is this high above the horizon
local STAR_SPREAD = math.rad(34) -- the stars of a multi pull fan out this far to each side
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

local function clamp01(x)
	return math.clamp(x, 0, 1)
end

local function smooth(x)
	x = clamp01(x)
	return x * x * (3 - 2 * x)
end

-- ============================================================
-- Small builders
-- ============================================================
local function newPart(parent, size, cf, color, material, shape)
	local p = Instance.new("Part")
	p.Size = size
	p.CFrame = cf
	p.Color = color or Color3.new(1, 1, 1)
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

-- a flare drawn on a billboard: four crossed light bars, a ring that pulses and a bright core
local function buildFlare(parent, color, studs)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.new(studs, 0, studs, 0)
	gui.AlwaysOnTop = false
	gui.LightInfluence = 0
	gui.Parent = parent
	local bars = {}
	for i = 0, 3 do
		local bar = Instance.new("Frame")
		bar.AnchorPoint = Vector2.new(0.5, 0.5)
		bar.Position = UDim2.fromScale(0.5, 0.5)
		bar.Size = UDim2.fromScale(1, i % 2 == 0 and 0.022 or 0.012)
		bar.Rotation = i * 45
		bar.BackgroundColor3 = color:Lerp(Color3.new(1, 1, 1), 0.35)
		bar.BorderSizePixel = 0
		local grad = Instance.new("UIGradient")
		grad.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.5, 0),
			NumberSequenceKeypoint.new(1, 1),
		})
		grad.Parent = bar
		bar.Parent = gui
		bars[i + 1] = bar
	end
	local rings = {}
	for i = 1, 3 do
		local ring = Instance.new("Frame")
		ring.AnchorPoint = Vector2.new(0.5, 0.5)
		ring.Position = UDim2.fromScale(0.5, 0.5)
		ring.Size = UDim2.fromScale(0.2, 0.2)
		ring.BackgroundTransparency = 1
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = ring
		local stroke = Instance.new("UIStroke")
		stroke.Color = color
		stroke.Thickness = 4
		stroke.Transparency = 1
		stroke.Parent = ring
		ring.Parent = gui
		rings[i] = { frame = ring, stroke = stroke }
	end
	local core = Instance.new("Frame")
	core.AnchorPoint = Vector2.new(0.5, 0.5)
	core.Position = UDim2.fromScale(0.5, 0.5)
	core.Size = UDim2.fromScale(0.13, 0.13)
	core.BackgroundColor3 = Color3.new(1, 1, 1)
	core.BorderSizePixel = 0
	local coreCorner = Instance.new("UICorner")
	coreCorner.CornerRadius = UDim.new(1, 0)
	coreCorner.Parent = core
	core.Parent = gui
	local coreGlow = Instance.new("UIStroke")
	coreGlow.Color = color
	coreGlow.Thickness = 6
	coreGlow.Transparency = 0.3
	coreGlow.Parent = core
	return { gui = gui, bars = bars, rings = rings, core = core }
end

-- ============================================================
-- The cinematic
-- ============================================================
function StarSummon.play(results, opts)
	opts = opts or {}
	if StarSummon.active or not results or #results == 0 then
		if opts.onDone then
			opts.onDone()
		end
		return
	end
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local camera = Workspace.CurrentCamera
	if not hrp or not camera then
		if opts.onDone then
			opts.onDone()
		end
		return
	end
	StarSummon.active = true

	-- ── The best result, its tier and the timeline ───────────
	local bestIndex = 1
	for i, r in ipairs(results) do
		if (Rarities.Rank[r.rarity] or 0) > (Rarities.Rank[results[bestIndex].rarity] or 0) then
			bestIndex = i
		end
	end
	local best = results[bestIndex]
	local t = tierOf(best.rarity)
	local bestColor = rarityColor(best.rarity)
	local count = math.min(#results, 10)

	local T_INTRO = 1.5 -- the stars light up one by one
	local T_BUILD = 2.2 + 1.6 * t -- the best star's aura swells
	local T_FLARE = 0.9 -- it shines even bigger
	local T_FALL = 1.5 + 0.9 * t -- the crash down
	local T_SHAKE = 1.1 -- the impact rocks the camera
	local T_RISE = 2.4 + 1.0 * t -- the unit climbs out
	local T_HOLD = 2.4
	local START_BUILD = T_INTRO
	local START_FLARE = START_BUILD + T_BUILD
	local START_FALL = START_FLARE + T_FLARE
	local START_IMPACT = START_FALL + T_FALL
	local START_RISE = START_IMPACT + 0.7
	local START_HERO = START_IMPACT + T_SHAKE + 1.2 -- from here the camera only orbits the grave slowly
	local END_TIME = START_RISE + T_RISE + T_HOLD

	-- ── The place: a spot on the ground near the player with a clear view ──
	-- The grave stands about 30 studs away from the player; the cinematic cameras sit behind it and above it, so the spot
	-- is only used when nothing (a wall, a stall) is between the grave and those camera positions. The player's own look
	-- direction is tried first, then the others around them.
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

	local flatLook = Vector3.new(hrp.CFrame.LookVector.X, 0, hrp.CFrame.LookVector.Z)
	local lookDir = flatLook.Magnitude > 0.1 and flatLook.Unit or Vector3.new(0, 0, -1)
	local function viewIsClear(from, to)
		return Workspace:Raycast(from, to - from, rayParams) == nil
	end
	local dir, right, G
	for _, degrees in ipairs({ 0, 45, -45, 90, -90, 135, -135, 180 }) do
		local a = math.rad(degrees)
		local d = Vector3.new(lookDir.X * math.cos(a) - lookDir.Z * math.sin(a), 0, lookDir.X * math.sin(a) + lookDir.Z * math.cos(a))
		local r = Vector3.new(-d.Z, 0, d.X)
		local hit = Workspace:Raycast(hrp.Position + d * 30 + Vector3.new(0, 30, 0), Vector3.new(0, -80, 0), rayParams)
		if hit and math.abs(hit.Position.Y - hrp.Position.Y) < 8 then
			local g = hit.Position
			local eye = g + up * 3
			local cameraBehind = g - d * 34 + up * 4.5
			local cameraHero = g - d * 18 + r * 6 + up * 4
			if viewIsClear(eye, cameraBehind) and viewIsClear(eye, cameraHero) and viewIsClear(eye, g + d * 10 + up * 3) then
				dir, right, G = d, r, g
				break
			end
		end
	end
	if not G then
		-- no clear spot found: use the player's look direction anyway
		dir = lookDir
		right = Vector3.new(-dir.Z, 0, dir.X)
		local hit = Workspace:Raycast(hrp.Position + dir * 30 + Vector3.new(0, 30, 0), Vector3.new(0, -80, 0), rayParams)
		G = hit and hit.Position or (hrp.Position + dir * 30 - Vector3.new(0, 3, 0))
	end

	local fxFolder = Instance.new("Folder")
	fxFolder.Name = "StarSummonFX"
	fxFolder.Parent = Workspace

	-- ── Save and switch off what the cinematic takes over ────
	local saved = {
		cameraType = camera.CameraType,
		cframe = camera.CFrame,
		fov = camera.FieldOfView,
		guiEnabled = mainGui.Enabled,
	}
	local controls
	pcall(function()
		controls = require(player.PlayerScripts:WaitForChild("PlayerModule", 2)):GetControls()
		controls:Disable()
	end)
	mainGui.Enabled = false
	camera.CameraType = Enum.CameraType.Scriptable

	-- its own little UI: black bars, the white flash, the unit's name and the skip button
	local ui = Instance.new("ScreenGui")
	ui.Name = "StarSummonUI"
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
	flash.BackgroundColor3 = Color3.new(1, 1, 1)
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
	nameLbl.TextStrokeTransparency = 0
	nameLbl.TextStrokeColor3 = Color3.new(0, 0, 0)
	nameLbl.TextTransparency = 1
	nameLbl.TextStrokeTransparency = 1
	nameLbl.Text = best.unitType
	nameLbl.ZIndex = 6
	nameLbl.Parent = ui
	local rarityLbl = nameLbl:Clone()
	rarityLbl.Position = UDim2.fromScale(0.5, 0.9)
	rarityLbl.TextSize = 24
	rarityLbl.Text = string.upper(best.rarity)
	rarityLbl.TextTransparency = 1
	rarityLbl.TextStrokeTransparency = 1
	rarityLbl.Parent = ui
	local skipBtn = Instance.new("TextButton")
	skipBtn.AnchorPoint = Vector2.new(1, 1)
	skipBtn.Position = UDim2.new(1, -24, 1, -20)
	skipBtn.Size = UDim2.fromOffset(110, 40)
	skipBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
	skipBtn.BackgroundTransparency = 0.3
	skipBtn.Font = Enum.Font.FredokaOne
	skipBtn.TextSize = 22
	skipBtn.TextColor3 = Color3.new(1, 1, 1)
	skipBtn.Text = "Skip"
	skipBtn.ZIndex = 7
	skipBtn.Parent = ui
	local skipCorner = Instance.new("UICorner")
	skipCorner.CornerRadius = UDim.new(0, 8)
	skipCorner.Parent = skipBtn

	-- ── The grave (a simple tombstone drawn from parts) ──────
	local grave = Instance.new("Model")
	grave.Name = "SummonGrave"
	grave.Parent = fxFolder
	local STONE = Color3.fromRGB(96, 98, 112)
	local stoneBase = newPart(grave, Vector3.new(4.4, 0.5, 2.2), CFrame.new(G + Vector3.new(0, 0.25, 0)) * CFrame.lookAt(Vector3.zero, -dir).Rotation, STONE, Enum.Material.Slate, Enum.PartType.Block)
	local slab = newPart(grave, Vector3.new(3.4, 4.2, 0.9), stoneBase.CFrame * CFrame.new(0, 2.35, 0), STONE:Lerp(Color3.new(1, 1, 1), 0.08), Enum.Material.Slate)
	local top = newPart(grave, Vector3.new(0.9, 3.4, 3.4), stoneBase.CFrame * CFrame.new(0, 4.45, 0) * CFrame.Angles(0, math.rad(90), 0), STONE:Lerp(Color3.new(1, 1, 1), 0.08), Enum.Material.Slate, Enum.PartType.Cylinder)
	local crossV = newPart(grave, Vector3.new(0.22, 1.7, 0.1), slab.CFrame * CFrame.new(0, 0.5, -0.5), Color3.fromRGB(60, 62, 74), Enum.Material.Slate)
	local crossH = newPart(grave, Vector3.new(1.0, 0.22, 0.1), slab.CFrame * CFrame.new(0, 0.9, -0.5), Color3.fromRGB(60, 62, 74), Enum.Material.Slate)
	local graveGlow = newPart(grave, Vector3.new(0.12, 0.12, 0.12), CFrame.new(G + Vector3.new(0, 1.5, 0)), bestColor, Enum.Material.Neon)
	graveGlow.Transparency = 1
	local graveParts = { stoneBase, slab, top, crossV, crossH }
	local graveRest = {}
	for _, p in ipairs(graveParts) do
		graveRest[p] = p.CFrame
	end

	-- ── The stars ────────────────────────────────────────────
	local stars = {}
	for i = 1, count do
		local spread = count == 1 and 0 or ((i - 1) / (count - 1) * 2 - 1)
		local az = spread * STAR_SPREAD
		local el = STAR_ELEVATION + math.rad(((i * 7) % 5) * 3 - 6)
		local toStar = (dir * math.cos(az) + right * math.sin(az)) * math.cos(el) + up * math.sin(el)
		local rarity = results[i].rarity
		local color = rarityColor(rarity)
		local isBest = (i == bestIndex)
		local pos = G + toStar * SKY_DISTANCE
		local part = newPart(fxFolder, Vector3.one * (isBest and 10 or 6), CFrame.new(pos), color:Lerp(Color3.new(1, 1, 1), 0.5), Enum.Material.Neon, Enum.PartType.Ball)
		local flare = buildFlare(part, color, isBest and 120 or 70)
		stars[i] = {
			part = part,
			flare = flare,
			pos = pos,
			color = color,
			isBest = isBest,
			delay = 0.15 + (i - 1) * 0.1 + (isBest and 0.2 or 0),
			twinkle = math.random() * 6,
			tier = tierOf(rarity),
		}
	end
	local star = stars[bestIndex]
	local starCenter = G + (dir * math.cos(STAR_ELEVATION) + up * math.sin(STAR_ELEVATION)) * SKY_DISTANCE

	-- the falling star itself: a fiery ball with a trail of fire and smoke, only visible during the fall
	local fall = newPart(fxFolder, Vector3.one * 8, CFrame.new(star.pos), bestColor:Lerp(Color3.new(1, 1, 1), 0.6), Enum.Material.Neon, Enum.PartType.Ball)
	fall.Transparency = 1
	local fallLight = Instance.new("PointLight")
	fallLight.Color = bestColor
	fallLight.Range = 0
	fallLight.Brightness = 8
	fallLight.Shadows = false
	fallLight.Parent = fall
	local function emitter(texture, lifetime, rate, startSize, endSize, speed, c0, c1, emission)
		local e = Instance.new("ParticleEmitter")
		e.Texture = texture
		e.Color = ColorSequence.new(c0, c1)
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, startSize), NumberSequenceKeypoint.new(1, endSize) })
		e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(0.6, 0.55), NumberSequenceKeypoint.new(1, 1) })
		e.Lifetime = NumberRange.new(lifetime * 0.7, lifetime)
		e.Rate = rate
		e.Speed = NumberRange.new(speed * 0.5, speed)
		e.SpreadAngle = Vector2.new(25, 25)
		e.LightEmission = emission
		e.LightInfluence = 0
		e.Rotation = NumberRange.new(0, 360)
		e.RotSpeed = NumberRange.new(-60, 60)
		e.Enabled = false
		e.Parent = fall
		return e
	end
	local FIRE = "rbxasset://textures/particles/fire_main.dds"
	local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
	local fire = emitter(FIRE, 0.7, 90, 16, 3, 10, Color3.fromRGB(255, 240, 200), bestColor, 1)
	local smoke = emitter(SMOKE, 1.1, 22, 5, 15, 6, bestColor:Lerp(Color3.new(0, 0, 0), 0.4), Color3.fromRGB(30, 26, 36), 0.1)
	local sparks = emitter("rbxasset://textures/particles/sparkles_main.dds", 0.8, 60, 3, 0, 28, Color3.new(1, 1, 1), bestColor, 1)
	fire.EmissionDirection = Enum.NormalId.Back
	smoke.EmissionDirection = Enum.NormalId.Back
	sparks.EmissionDirection = Enum.NormalId.Back

	-- ── State of the run ─────────────────────────────────────
	local T = 0
	local done = false
	local connection
	local impacted = false
	local risen = false
	local unit -- the model that climbs out
	local shakeAmount, shakeStart = 0, 0
	local lastChasePos, lastChaseLook = camera.CFrame.Position, G
	local flashStart = nil

	local function finish()
		if done then
			return
		end
		done = true
		if connection then
			connection:Disconnect()
		end
		if unit then
			CollectionService:RemoveTag(unit, PROP_TAG)
		end
		fxFolder:Destroy()
		ui:Destroy()
		camera.CameraType = saved.cameraType == Enum.CameraType.Scriptable and Enum.CameraType.Custom or saved.cameraType
		camera.FieldOfView = saved.fov
		mainGui.Enabled = saved.guiEnabled
		if controls then
			pcall(function()
				controls:Enable()
			end)
		end
		StarSummon.active = false
		if opts.onDone then
			opts.onDone()
		end
	end
	skipBtn.Activated:Connect(finish)

	local function startFlash(seconds)
		flashStart = { at = os.clock(), length = seconds }
		flash.BackgroundTransparency = 0
	end

	-- the unit rises out of the grave (its own rise animation: UnitAnimator turns RiseStart/RiseTime into a sinking offset
	-- and SpellEffects kicks up dust)
	local function spawnUnit()
		local folder = ReplicatedStorage:FindFirstChild("UnitModels")
		local template = folder and folder:FindFirstChild(best.unitType)
		if not template then
			return
		end
		local model = template:Clone()
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("BaseScript") or d:IsA("Humanoid") then
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
		local def = Units.Stats[best.unitType]
		local scale = def and (def.size.X / 2 * 0.9) or 1
		model:ScaleTo(scale)
		local rootHeight = (model:GetAttribute("RootHeight") or 2.2) * scale
		model:PivotTo(CFrame.lookAt(G + Vector3.new(0, rootHeight, 0), G + Vector3.new(0, rootHeight, 0) - dir))
		-- no attacking from the cinematic: only the rise animation and the idle pose
		model:SetAttribute("AttackStyle", nil)
		model:SetAttribute("State", "idle")
		model:SetAttribute("RiseTime", T_RISE)
		model:SetAttribute("RiseStart", Workspace:GetServerTimeNow())
		model.Parent = fxFolder
		CollectionService:AddTag(model, PROP_TAG)
		unit = model
	end

	local function impact()
		impacted = true
		fall.Transparency = 1
		fallLight.Enabled = false
		fire.Enabled, smoke.Enabled, sparks.Enabled = false, false, false
		-- the grave is blown apart: its stones jump and vanish, the unit climbs out of the crater
		for _, p in ipairs(graveParts) do
			TweenService:Create(p, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Transparency = 1,
				CFrame = p.CFrame * CFrame.new((math.random() - 0.5) * 6, 2 + math.random() * 4, (math.random() - 0.5) * 6)
					* CFrame.Angles(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5),
			}):Play()
		end
		startFlash(1.1)
		shakeAmount, shakeStart = 1.6 + 1.2 * t, os.clock()

		-- shock rings on the ground, a scorched crater with a glowing rim
		for i = 1, 3 do
			local ring = newPart(fxFolder, Vector3.new(0.4, 2, 2), CFrame.new(G + Vector3.new(0, 0.3 + i * 0.05, 0)) * CFrame.Angles(0, 0, math.rad(90)), bestColor:Lerp(Color3.new(1, 1, 1), 0.3), Enum.Material.Neon, Enum.PartType.Cylinder)
			local size = 70 + 70 * t + i * 18
			TweenService:Create(ring, TweenInfo.new(0.55 + i * 0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Size = Vector3.new(0.4, size, size),
				Transparency = 1,
			}):Play()
		end
		local crater = newPart(fxFolder, Vector3.new(0.2, 14, 14), CFrame.new(G + Vector3.new(0, 0.06, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(16, 14, 20), Enum.Material.Slate, Enum.PartType.Cylinder)
		local rim = newPart(fxFolder, Vector3.new(0.2, 15.5, 15.5), CFrame.new(G + Vector3.new(0, 0.04, 0)) * CFrame.Angles(0, 0, math.rad(90)), bestColor, Enum.Material.Neon, Enum.PartType.Cylinder)
		TweenService:Create(rim, TweenInfo.new(5, Enum.EasingStyle.Quad), { Transparency = 1 }):Play()

		-- light, dust and flying debris
		local light = Instance.new("PointLight")
		light.Color = bestColor
		light.Range = 70
		light.Brightness = 7
		light.Shadows = false
		light.Parent = crater
		TweenService:Create(light, TweenInfo.new(1.6), { Brightness = 0 }):Play()
		local holder = newPart(fxFolder, Vector3.one * 0.5, CFrame.new(G + Vector3.new(0, 1, 0)), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic)
		holder.Transparency = 1
		local dust = Instance.new("ParticleEmitter")
		dust.Texture = SMOKE
		dust.Color = ColorSequence.new(bestColor:Lerp(Color3.new(1, 1, 1), 0.6), Color3.fromRGB(86, 80, 96))
		dust.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 3), NumberSequenceKeypoint.new(1, 13) })
		dust.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 1) })
		dust.Lifetime = NumberRange.new(1.2, 2.4)
		dust.Speed = NumberRange.new(20, 55)
		dust.SpreadAngle = Vector2.new(70, 360)
		dust.Drag = 3
		dust.LightEmission = 0.4
		dust.LightInfluence = 0.3
		dust.Rate = 0
		dust.Parent = holder
		dust:Emit(36)
		local embers = Instance.new("ParticleEmitter")
		embers.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		embers.Color = ColorSequence.new(Color3.new(1, 1, 1), bestColor)
		embers.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.6), NumberSequenceKeypoint.new(1, 0) })
		embers.Lifetime = NumberRange.new(0.8, 1.8)
		embers.Speed = NumberRange.new(25, 70)
		embers.SpreadAngle = Vector2.new(90, 360)
		embers.Drag = 1.2
		embers.Acceleration = Vector3.new(0, -30, 0)
		embers.LightEmission = 1
		embers.Rate = 0
		embers.Parent = holder
		embers:Emit(60 + math.floor(60 * t))
		Debris:AddItem(holder, 3.5)
		for _ = 1, 16 do
			local size = 0.8 + math.random() * 1.6
			local chunk = Instance.new("Part")
			chunk.Size = Vector3.new(size, size, size)
			chunk.Color = Color3.fromRGB(70, 66, 80)
			chunk.Material = Enum.Material.Slate
			chunk.CanQuery = false
			chunk.CanTouch = false
			pcall(function()
				chunk.CollisionGroup = "Debris" -- (rubble does not collide with players)
			end)
			chunk.CFrame = CFrame.new(G + Vector3.new(0, 1.5, 0)) * CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6)
			chunk.AssemblyLinearVelocity = Vector3.new((math.random() - 0.5) * 70, 28 + math.random() * 36, (math.random() - 0.5) * 70)
			chunk.AssemblyAngularVelocity = Vector3.new(math.random() * 12, math.random() * 12, math.random() * 12)
			chunk.Parent = fxFolder
			Debris:AddItem(chunk, 4)
		end
		-- the grave is thrown about and its glow comes on
		graveGlow.Transparency = 0
		TweenService:Create(graveGlow, TweenInfo.new(2), { Transparency = 1 }):Play()
	end

	-- ── Per-frame timeline ───────────────────────────────────
	local speed = opts.speed or 1 -- (testing: 0.25 plays the cinematic in slow motion)
	connection = RunService.RenderStepped:Connect(function(realDt)
		if done then
			return
		end
		local dt = realDt * speed
		T += dt
		if T >= END_TIME then
			finish()
			return
		end

		-- black bars slide in at the start and out at the end
		local barSize = 0.11 * smooth(T / 0.6) * smooth((END_TIME - T) / 0.6)
		barTop.Size = UDim2.fromScale(1, barSize)
		barBottom.Size = UDim2.fromScale(1, barSize)

		-- the white flash fades
		if flashStart then
			local k = (os.clock() - flashStart.at) / flashStart.length
			flash.BackgroundTransparency = clamp01(k) ^ 0.7
			if k >= 1 then
				flashStart = nil
			end
		end

		-- the stars: they light up one by one, twinkle, and the best one grows its aura
		for _, s in ipairs(stars) do
			local appear = smooth((T - s.delay) / 0.5)
			local twinkle = 0.85 + 0.15 * math.sin(T * 5 + s.twinkle)
			local scale = appear * twinkle
			local dim = 1
			if not s.isBest and T > START_BUILD then
				dim = 1 - 0.45 * smooth((T - START_BUILD) / 1.2) -- the others step back while the best one shines
			end
			local build = s.isBest and smooth((T - START_BUILD) / T_BUILD) or 0
			local flare = s.isBest and smooth((T - START_FLARE) / T_FLARE) or 0
			local grow = 1 + build * (0.6 + 0.9 * t) + flare * (1.4 + 1.0 * t)
			local visible = not (s.isBest and T >= START_FALL)
			s.part.Transparency = visible and (1 - appear * dim) or 1
			s.flare.gui.Enabled = visible
			s.flare.gui.Size = UDim2.new((s.isBest and 120 or 70) * scale * grow * dim, 0, (s.isBest and 120 or 70) * scale * grow * dim, 0)
			s.part.Size = Vector3.one * ((s.isBest and 10 or 6) * scale * (1 + 0.5 * build + 1.2 * flare))
			for i, bar in ipairs(s.flare.bars) do
				bar.BackgroundTransparency = 1 - appear * dim
			end
			s.flare.core.BackgroundTransparency = 1 - appear * dim
			-- aura rings (the best star): rings of its rarity colour that pulse outwards faster and wider as it builds up
			for i, ring in ipairs(s.flare.rings) do
				if s.isBest and build > 0 then
					local phase = ((T * (0.6 + 0.9 * build) + i / 3) % 1)
					ring.frame.Size = UDim2.fromScale(0.15 + phase * (0.55 + 0.4 * build), 0.15 + phase * (0.55 + 0.4 * build))
					ring.stroke.Transparency = 1 - (1 - phase) * (0.35 + 0.6 * build)
					ring.stroke.Thickness = 3 + 6 * build
				else
					ring.stroke.Transparency = 1
				end
			end
		end

		-- ── Camera ──────────────────────────────────────────
		local camPos, camLook, fov
		if T < START_FALL then
			-- on the ground, looking up: a slow dolly forward, the look swings from the middle of the field to the best star
			local dolly = T * 1.6
			camPos = G - dir * 34 + up * 4.5 + dir * dolly
			local aim = smooth((T - START_BUILD * 0.6) / (T_BUILD + 0.4))
			camLook = starCenter:Lerp(star.pos, aim)
			fov = 72 - 20 * smooth((T - START_BUILD) / T_BUILD) - 16 * smooth((T - START_FLARE) / T_FLARE)
			if T > START_FLARE then
				local k = smooth((T - START_FLARE) / T_FLARE)
				shakeAmount, shakeStart = 0.25 * k, os.clock()
			end
		elseif T < START_HERO then
			local tau = clamp01((T - START_FALL) / T_FALL)
			if not impacted then
				if T - dt < START_FALL then
					startFlash(0.5) -- the flare blinds, then the cut to the falling star
					fall.Transparency = 0
					fire.Enabled, smoke.Enabled, sparks.Enabled = true, true, true
				end
				local ease = tau ^ 2.2
				local sPos = star.pos:Lerp(G + Vector3.new(0, 1.5, 0), ease)
				local toSky = (star.pos - G).Unit
				local chase = 46 - 28 * tau
				camPos = sPos + toSky * chase + right * (20 - 10 * tau) + up * (5 - 3 * tau)
				camLook = sPos
				fov = 64 + 28 * tau
				fall.CFrame = CFrame.lookAt(sPos, sPos - toSky) -- the trail comes out of the back (-Z of the part is the front)
				local size = 4 + 3 * tau + 3 * t
				fall.Size = Vector3.one * size
				fallLight.Range = 40 + 80 * tau
				shakeAmount, shakeStart = 0.15 + 0.9 * tau * tau, os.clock()
				lastChasePos, lastChaseLook = camPos, camLook
				if tau >= 1 then
					impact()
				end
			else
				-- after the crash: the camera sweeps from the chase position to a low hero shot of the grave
				local k = smooth((T - START_IMPACT) / 1.9)
				local hero = G - dir * (15 + 3 * t) + right * 6 + up * 4
				camPos = lastChasePos:Lerp(hero, k)
				camLook = lastChaseLook:Lerp(G + up * 3.5, k)
				fov = (92 - 38 * k)
			end
		else
			-- the hero shot: slowly orbiting a little while the unit climbs out
			local orbit = (T - START_HERO) * 0.12
			camPos = G + (dir * -(15 + 3 * t)) * math.cos(orbit) + right * (6 * math.cos(orbit) + 14 * math.sin(orbit)) + up * 4
			camLook = G + up * (3.4 + 0.6 * smooth((T - START_RISE) / T_RISE))
			fov = 54 - 6 * smooth((T - START_RISE) / T_RISE)
		end

		-- camera shake
		local shakeAge = os.clock() - shakeStart
		local shake = shakeAmount * math.exp(-shakeAge * (impacted and 3.2 or 12))
		local jitter = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 2 * shake
		camera.CFrame = CFrame.lookAt(camPos + jitter, camLook + jitter * 0.5)
		camera.FieldOfView = fov

		-- the unit climbs out
		if impacted and not risen and T >= START_RISE then
			risen = true
			spawnUnit()
		end
		-- name and rarity fade in once the unit is up
		if risen then
			local k = smooth((T - START_RISE - T_RISE * 0.55) / 0.7)
			nameLbl.TextTransparency = 1 - k
			nameLbl.TextStrokeTransparency = 1 - k
			rarityLbl.TextTransparency = 1 - k
			rarityLbl.TextStrokeTransparency = 1 - k
		end
	end)
end

return StarSummon
