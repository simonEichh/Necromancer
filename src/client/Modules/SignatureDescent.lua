-- "The Descent": a cinematic for Signature pulls (GraveRolling picks it or the star summon at random).
--
--   local started = SignatureDescent.play(results, opts)
--     results: list of { unitType, rarity, pity, oneIn } from the server's RollResult
--     opts:    graveType  the grave that was opened (needs a model in ReplicatedStorage.GraveModels)
--              onDone     function(), called when the cinematic ends (also when it is skipped)
--              speed      playback speed on top of PACE (default 1; for testing)
--     returns false (and does nothing) when it cannot play: no grave model, no character, or a cinematic runs.
--
-- What you see (normal pulls rise out of the earth; a Signature comes down from the heavens):
--   1. Bait: like a hand-opened grave, the real grave pushes up and starts to shake ... then it stops dead. Silence.
--   2. The circles: a HUGE magic circle flares open high above the grave, then smaller ones snap open below it, faster
--      and faster, down to one the size of the grave right above it. Light lines draw themselves from the top circle's
--      edge down to the grave: a cone (every circle sits exactly on it).
--   3. Charging: the circles spin, each against its neighbour, faster and faster, runes slide down the lines into the
--      grave, the world darkens (a ColorCorrection only this player sees) and the wind whips dust round the grave.
--   4. The portal: the top circle opens into a dark starry sky; the unit's black silhouette appears in it, eyes glowing.
--   4b. The figure slowly sinks out of the void (fading in from nothing, dark wisps trailing from the portal).
--   5. The descent: it drops down the cone; every circle it passes collapses onto it and becomes a spinning halo round
--      its body, so it gathers all the rings on the way down. The camera chases it.
--   6. Landing: it slams onto the grave, which bursts (GraveOpening); all gathered halos burst outwards over the ground as
--      rings of golden runes, sparks rain, the world brightens again. Hero shot, Continue.
--   The camera pulls back from the grave to the side view WHILE the rings build, so they are seen opening from the side.
-- Colours: the Signature ember gold (Units.SIGNATURE_COLOR) with the rarity colour for the details.
-- Camera, controls and every ScreenGui are taken over and restored like the other cinematics (GraveCinematic, StarSummon).
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
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

local SignatureDescent = {}
SignatureDescent.active = false

-- ============================================================
-- Settings
-- ============================================================
local GRAVE_SCALE = 1.5
local GRAVE_DISTANCE = 16
local PROP_TAG = "ProceduralUnit"
local TIP_HEIGHT = 1.2 -- the cone's tip above the floor (the grave)
local TOP_HEIGHT = 160 -- the huge circle's height above the floor
local TOP_RADIUS = 60
local BOTTOM_HEIGHT = 11 -- the smallest circle (about the grave's size: radius ~4)
local CIRCLE_COUNT = 14
local LINE_COUNT = 12
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local PACE = 0.7 -- the whole timeline plays at this speed (lower = slower and grander; shards, flashes and shake keep real time)

local function rarityColor(rarity)
	return GameData.RARITY_COLORS[rarity] or Rarities.Color[rarity] or Color3.new(1, 1, 1)
end
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

-- A magic circle lying flat, built from neon parts with offsets from its hub (moved with BulkMoveTo every frame)
local function buildCircle(parent, radius, gold, accent)
	local c = { parts = {}, offsets = {}, base = {}, radius = radius }
	local w = math.max(0.16, radius * 0.022)
	local function add(size, offset, color)
		local p = newPart(parent, size, offset, color)
		p.Transparency = 1
		table.insert(c.parts, p)
		table.insert(c.offsets, offset)
		return p
	end
	local function ring(r, count, width, color, phase)
		local seg = 2 * math.pi * r / count * 0.86
		for k = 0, count - 1 do
			local a = (k / count) * 2 * math.pi + (phase or 0)
			add(Vector3.new(seg, 0.08, width), CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -r), color)
		end
	end
	local n = math.clamp(math.floor(radius * 1.6), 24, 64)
	ring(radius, n, w, gold)
	ring(radius * 0.88, n, w * 0.6, accent, 0.05)
	ring(radius * 0.36, math.max(12, math.floor(n / 2)), w * 0.6, accent)
	-- glyphs between the two outer rings
	local m = math.clamp(math.floor(radius * 0.6), 8, 24)
	for k = 0, m - 1 do
		local a = k / m * 2 * math.pi
		local base = CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -radius * 0.94)
		add(Vector3.new(w * 0.7, 0.08, radius * 0.05), base, gold)
		add(Vector3.new(radius * 0.035, 0.08, w * 0.7), base * CFrame.new(0, 0, (k % 2 == 0) and radius * 0.012 or -radius * 0.012), gold)
	end
	-- a hexagram inscribed in the inner ring
	for tri = 0, 1 do
		local pts = {}
		for k = 0, 2 do
			local a = (k / 3) * 2 * math.pi + tri * math.pi
			pts[k + 1] = Vector3.new(math.sin(a), 0, -math.cos(a)) * radius * 0.86
		end
		for k = 1, 3 do
			local a, b = pts[k], pts[k % 3 + 1]
			add(Vector3.new(w * 0.6, 0.08, (b - a).Magnitude), CFrame.lookAt((a + b) / 2, b), gold)
		end
	end
	-- rune stones riding the rim
	for k = 0, 3 do
		local s = math.max(0.5, w * 3)
		add(Vector3.new(s, s, s), CFrame.Angles(0, k / 4 * 2 * math.pi + math.pi / 4, 0) * CFrame.new(0, 0, -radius * 1.06) * CFrame.Angles(math.rad(45), 0, math.rad(45)), accent)
	end
	for i, p in ipairs(c.parts) do
		c.base[i] = 0
	end
	return c
end

function SignatureDescent.play(results, opts)
	opts = opts or {}
	local template = GraveOpening.template(opts.graveType)
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local camera = Workspace.CurrentCamera
	if SignatureDescent.active or not template or not hrp or not camera or not results or #results == 0 then
		return false
	end
	SignatureDescent.active = true

	-- ── The best result ──────────────────────────────────────
	local best = results[1]
	for _, r in ipairs(results) do
		local rr, rb = Rarities.Rank[r.rarity] or 0, Rarities.Rank[best.rarity] or 0
		if rr > rb or (rr == rb and Units.isSignature(r.unitType) and not Units.isSignature(best.unitType)) then
			best = r
		end
	end
	-- (a deeper gold than the pale SIGNATURE_COLOR: neon blows pale colours out to white under the bloom)
	local GOLD = Color3.fromRGB(255, 168, 56)
	local ACCENT = rarityColor(best.rarity)

	-- ── Timeline ─────────────────────────────────────────────
	local START_SILENCE = 2.3 -- the bait: the grave stops shaking
	local START_CIRCLES = 2.7
	local T_CIRCLES = 2.9 -- they snap open one after another, faster and faster (gaps shrink with a square root)
	local START_LINES = START_CIRCLES + T_CIRCLES + 0.3
	local START_CHARGE = START_LINES + 1.2
	local T_CHARGE = 2.6
	local START_PORTAL = START_CHARGE + T_CHARGE
	local START_SILHOUETTE = START_PORTAL + 0.9 -- the figure slowly sinks out of the void
	local T_EMERGE = 2.7
	local START_DESCENT = START_SILHOUETTE + T_EMERGE + 0.2
	local T_FALL = 2.2
	local START_LAND = START_DESCENT + T_FALL
	local HOLD_AT = START_LAND + 1.6
	local endTime = math.huge

	-- ── The place (like the grave cinematic, but the cone needs a clear sky above too) ──
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
			if viewIsClear(eye, g - d * 16 + r * 6 + up * 7) and viewIsClear(eye, g - d * 20 + r * 6 + up * 5) and viewIsClear(eye, g + up * 60) then
				dir, right, G = d, r, g
				break
			end
		end
	end
	if not G then
		dir = lookDir
		right = Vector3.new(-dir.Z, 0, dir.X)
		G = hrp.Position + dir * GRAVE_DISTANCE - Vector3.new(0, 3, 0)
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum then
			G = hrp.Position + dir * GRAVE_DISTANCE - Vector3.new(0, hum.HipHeight + hrp.Size.Y / 2, 0)
		end
	end

	local fxFolder = Instance.new("Folder")
	fxFolder.Name = "SignatureDescentFX"
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

	-- ── The circles, the cone lines, the runes ───────────────
	local tip = G + up * TIP_HEIGHT
	local q = ((BOTTOM_HEIGHT - TIP_HEIGHT) / (TOP_HEIGHT - TIP_HEIGHT)) ^ (1 / (CIRCLE_COUNT - 1))
	local circles = {}
	for i = 1, CIRCLE_COUNT do
		local rel = (TOP_HEIGHT - TIP_HEIGHT) * q ^ (i - 1) -- height above the tip
		local radius = TOP_RADIUS * rel / (TOP_HEIGHT - TIP_HEIGHT)
		local c = buildCircle(fxFolder, radius, GOLD, ACCENT)
		c.center = tip + up * rel
		c.appearAt = START_CIRCLES + T_CIRCLES * math.sqrt((i - 1) / (CIRCLE_COUNT - 1))
		c.angle = math.random() * 6
		c.spinDir = (i % 2 == 0) and -1 or 1
		circles[i] = c
	end
	local top = circles[1]
	local lines = {}
	for k = 0, LINE_COUNT - 1 do
		local a = k / LINE_COUNT * 2 * math.pi
		local from = top.center + Vector3.new(math.cos(a), 0, math.sin(a)) * TOP_RADIUS
		local p = newPart(fxFolder, Vector3.new(0.3, 0.3, 0.1), CFrame.new(from), GOLD:Lerp(ACCENT, 0.3))
		p.Transparency = 1
		lines[k + 1] = { part = p, from = from, delay = k * 0.05 }
	end
	local runes = {}
	for i = 1, 40 do
		local p = newPart(fxFolder, Vector3.one * 0.7, CFrame.new(tip), (i % 2 == 0) and GOLD or ACCENT)
		p.Transparency = 1
		runes[i] = { part = p, alive = false }
	end

	-- the portal in the top circle: a dark disc with stars, growing open
	local portal = newPart(fxFolder, Vector3.new(0.3, 0.1, 0.1), CFrame.new(top.center - up * 0.3) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(64, 30, 104), Enum.Material.Neon, Enum.PartType.Cylinder) -- (a deep glowing void: the black figure must stand out against it)
	portal.Transparency = 1
	local portalRim = newPart(fxFolder, Vector3.new(0.2, 0.1, 0.1), portal.CFrame * CFrame.new(0.6, 0, 0), ACCENT, Enum.Material.Neon, Enum.PartType.Cylinder) -- (above the dark disc: from below only its edge shows)
	portalRim.Transparency = 1
	-- dark wisps trailing down out of the void while the figure emerges (the portal's local -X points down)
	local voidWisps = Instance.new("ParticleEmitter")
	voidWisps.Texture = SMOKE
	voidWisps.Color = ColorSequence.new(Color3.fromRGB(24, 18, 36), Color3.fromRGB(60, 44, 80))
	voidWisps.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 3), NumberSequenceKeypoint.new(1, 9) })
	voidWisps.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1) })
	voidWisps.Lifetime = NumberRange.new(2, 3.5)
	voidWisps.Speed = NumberRange.new(3, 7)
	voidWisps.SpreadAngle = Vector2.new(25, 25)
	voidWisps.EmissionDirection = Enum.NormalId.Left
	voidWisps.RotSpeed = NumberRange.new(-20, 20)
	voidWisps.Rate = 18
	voidWisps.Enabled = false
	voidWisps.Parent = portal
	local stars = {}
	for i = 1, 45 do
		local a, d = math.random() * math.pi * 2, math.sqrt(math.random())
		local p = newPart(fxFolder, Vector3.one * (0.3 + math.random() * 0.5), CFrame.new(top.center), Color3.new(1, 1, 1):Lerp(ACCENT, math.random() * 0.4), Enum.Material.Neon, Enum.PartType.Ball)
		p.Transparency = 1
		stars[i] = { part = p, a = a, d = d }
	end

	-- the darkening (only on this screen)
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "SignatureDescentCC"
	cc.Parent = Lighting

	-- the wind round the grave
	local windHolders = {}
	for k = 0, 5 do
		local a = k / 6 * math.pi * 2
		local pos = G + Vector3.new(math.cos(a), 0, math.sin(a)) * 7 + up * 0.6
		local tangent = Vector3.new(-math.sin(a), 0, math.cos(a))
		local h = newPart(fxFolder, Vector3.one * 0.3, CFrame.lookAt(pos, pos + tangent), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic)
		h.Transparency = 1
		local e = Instance.new("ParticleEmitter")
		e.Texture = SMOKE
		e.Color = ColorSequence.new(Color3.fromRGB(170, 160, 150), Color3.fromRGB(110, 100, 96))
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 3.5) })
		e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1) })
		e.Lifetime = NumberRange.new(0.8, 1.4)
		e.Speed = NumberRange.new(14, 22)
		e.SpreadAngle = Vector2.new(15, 6)
		e.EmissionDirection = Enum.NormalId.Front
		e.Rate = 0
		e.Parent = h
		windHolders[k + 1] = e
	end

	-- the falling unit: first a black silhouette (its neon parts keep glowing: the eyes), the real one after the landing
	local unitTemplate = ReplicatedStorage:FindFirstChild("UnitModels") and ReplicatedStorage.UnitModels:FindFirstChild(best.unitType)
	local def = Units.Stats[best.unitType]
	local unitScale = def and (def.size.X / 2 * 0.9) or 1
	local function cloneUnit(silhouette)
		if not unitTemplate then
			return nil
		end
		local m = unitTemplate:Clone()
		for _, d in ipairs(m:GetDescendants()) do
			if d:IsA("BaseScript") or d:IsA("Humanoid") then
				d:Destroy()
			elseif d:IsA("BasePart") then
				d.Anchored = true
				d.CanCollide = false
				d.CanQuery = false
				d.CanTouch = false
				if silhouette and d.Transparency < 1 then
					if d.Material == Enum.Material.Neon then
						d.Color = GOLD
					else
						d.Color = Color3.fromRGB(6, 4, 10)
						d.Material = Enum.Material.SmoothPlastic
					end
				end
			elseif silhouette and (d:IsA("Decal") or d:IsA("Texture")) then
				d:Destroy()
			end
		end
		m:ScaleTo(unitScale)
		return m
	end
	local rootHeight = 2.2 * unitScale
	if unitTemplate then
		rootHeight = (unitTemplate:GetAttribute("RootHeight") or 2.2) * unitScale
	end
	local unitTall = 5
	if unitTemplate and unitTemplate:GetAttribute("Height") then
		unitTall = unitTemplate:GetAttribute("Height") * unitScale
	end
	local landPivot = CFrame.lookAt(G + up * rootHeight, G + up * rootHeight - dir)
	local skyPivot = landPivot + up * (TOP_HEIGHT - rootHeight - unitTall * 0.6)
	local silhouette = cloneUnit(true)
	if silhouette then
		silhouette:PivotTo(skyPivot)
		for _, d in ipairs(silhouette:GetDescendants()) do
			if d:IsA("BasePart") then
				d.LocalTransparencyModifier = 1
			end
		end
		silhouette.Parent = fxFolder
		-- a gold rim light so the black figure stands out against the dark portal
		local rimLight = Instance.new("PointLight")
		rimLight.Color = GOLD
		rimLight.Range = unitTall * 2.5 + 6
		rimLight.Brightness = 4
		rimLight.Shadows = false
		rimLight.Parent = silhouette.PrimaryPart or silhouette:FindFirstChildWhichIsA("BasePart", true)
	end
	local unit -- the real one, after the landing

	-- ── Take over camera, controls and the UI ────────────────
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

	local ui = Instance.new("ScreenGui")
	ui.Name = "SignatureDescentUI"
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
	flash.BackgroundColor3 = Color3.new(1, 1, 1):Lerp(GOLD, 0.3)
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
	nameLbl.TextColor3 = ACCENT
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
		rarityLbl.RichText = true
		local sc = Units.SIGNATURE_COLOR
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
	local shakeAmount, shakeStart = 0, 0
	local flashStart
	local silenced, portalShown, landed = false, false, false
	local shards = {} -- flying pieces of shattered circles and raining sparks

	local function startFlash(seconds, transparency)
		flashStart = { at = os.clock(), length = seconds }
		flash.BackgroundTransparency = transparency or 0
	end

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
		cc:Destroy()
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
		SignatureDescent.active = false
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

	-- every circle the falling figure passes collapses onto it and becomes a small spinning halo round its body
	local halos = {}
	local haloR = math.max(2, unitTall * 0.42)
	local bodyMid = unitTall * 0.5 - rootHeight -- the middle of the body, relative to the unit's pivot
	local function absorb(c)
		c.absorbed = true
		c.absorbT = T
		local index = #halos
		local h = { parts = {}, offsets = {}, angle = math.random() * 6, spin = (index % 2 == 0) and 6 or -6, t0 = T,
			tilt = CFrame.Angles((math.random() - 0.5) * 0.7, 0, (math.random() - 0.5) * 0.7),
			y = bodyMid + ((index % 5) - 2) * unitTall * 0.16, ring = index % 3 }
		local n = 22
		local color = (index % 2 == 0) and GOLD or ACCENT
		for k = 0, n - 1 do
			local p = newPart(fxFolder, Vector3.new(2 * math.pi * haloR / n * 0.8, 0.12, 0.16), CFrame.new(c.center), color)
			p.Transparency = 1
			table.insert(h.parts, p)
			table.insert(h.offsets, k / n * 2 * math.pi)
		end
		for k = 0, 2 do
			local p = newPart(fxFolder, Vector3.one * 0.35, CFrame.new(c.center), Color3.new(1, 1, 1):Lerp(color, 0.4))
			p.Transparency = 1
			table.insert(h.parts, p)
			table.insert(h.offsets, k / 3 * 2 * math.pi + 0.3)
		end
		table.insert(halos, h)
		shakeAmount, shakeStart = 0.18 + c.radius * 0.004, os.clock()
	end

	local function land()
		landed = true
		model:PivotTo(rest)
		grave.burst(ACCENT, 1)
		startFlash(0.9)
		shakeAmount, shakeStart = 2.4, os.clock()
		if silhouette then
			silhouette:Destroy()
			silhouette = nil
		end
		unit = cloneUnit(false)
		if unit then
			for _, d in ipairs(unit:GetDescendants()) do
				if d:IsA("BasePart") then
					d.Anchored = false
				end
			end
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
		-- every gathered halo bursts outwards over the ground (moved in the frame loop)
		for _, h in ipairs(halos) do
			h.releaseT = T
		end
		-- a shockwave over the ground
		for i = 1, 1 do
			local wave = newPart(fxFolder, Vector3.new(0.3, 4, 4), CFrame.new(G + up * (0.2 + i * 0.05)) * CFrame.Angles(0, 0, math.rad(90)), Color3.new(1, 1, 1):Lerp(GOLD, 0.3 + 0.3 * i), Enum.Material.Neon, Enum.PartType.Cylinder)
			wave.Transparency = 0.15
			TweenService:Create(wave, TweenInfo.new(0.7 + 0.25 * i, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Size = Vector3.new(0.3, 90 + 30 * i, 90 + 30 * i), Transparency = 1,
			}):Play()
		end
		-- golden sparks raining down
		for _ = 1, 40 do
			local a, d = math.random() * math.pi * 2, math.random() * 26
			local p = newPart(fxFolder, Vector3.one * (0.25 + math.random() * 0.35), CFrame.new(G + Vector3.new(math.cos(a) * d, 18 + math.random() * 20, math.sin(a) * d)), (math.random() < 0.5) and GOLD or ACCENT)
			table.insert(shards, { part = p, cf = p.CFrame, t0 = os.clock() + math.random() * 0.6, life = 2.6, vel = Vector3.zero, spin = Vector3.zero, gravity = 9 })
		end
		-- the world comes back
		TweenService:Create(cc, TweenInfo.new(1.6, Enum.EasingStyle.Quad), { Brightness = 0, Contrast = 0, Saturation = 0, TintColor = Color3.new(1, 1, 1) }):Play()
	end

	-- the camera framing of the landed unit
	local HERO_FOV = 50
	local heroLookY = math.max(3, unitTall * 0.55)
	local heroDist = math.max(16, (unitTall * 0.5 + 2) / math.tan(math.rad(HERO_FOV / 2)) * 1.15)
	local heroCamY = math.max(3.5, unitTall * 0.4)
	local camArrive = G - dir * 16 + right * 6 + up * 7
	local camClose = G - dir * 10 + right * 3.5 + up * 4.5
	local lookGrave = G + up * 1.6 * GRAVE_SCALE
	local camWide = G - dir * 215 + right * 65 + up * 60
	local camPortal = top.center - up * (unitTall * 0.7) - dir * 88 + right * 26 -- (outside the cone, level with the figure: never below it)
	local portalDist = (camPortal - (skyPivot.Position + up * bodyMid)).Magnitude
	local ZOOM_FOV = math.deg(2 * math.atan(unitTall * 1.7 / (2 * portalDist))) -- the figure fills most of the frame -- (inside the cone, well below the portal: the void, the figure and the next ring frame the shot)

	-- ── Per-frame timeline ───────────────────────────────────
	local speed = (opts.speed or 1) * PACE
	local moveParts, moveCFrames = {}, {}
	connection = RunService.RenderStepped:Connect(function(realDt)
		if done then
			return
		end
		local dt = realDt * speed
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

		-- ── 1. The grave: rises, shakes ... and stops dead ──
		if T < 1.1 then
			local k = smooth(T / 0.95)
			local rumble = (1 - k) * 0.12 * GRAVE_SCALE
			model:PivotTo((rest - up * (graveSize.Y + 0.5) * (1 - k)) * CFrame.new((math.random() - 0.5) * rumble, 0, (math.random() - 0.5) * rumble))
		elseif T < START_SILENCE then
			local p = (T - 1.1) / (START_SILENCE - 1.1)
			local amp = (0.03 + 0.16 * p) * GRAVE_SCALE
			model:PivotTo(rest * CFrame.new((math.random() - 0.5) * amp, 0, (math.random() - 0.5) * amp))
			grave.setGlow(ACCENT, p * p * 0.6)
			shakeAmount, shakeStart = 0.04 + 0.1 * p, os.clock()
		elseif not silenced then
			silenced = true
			model:PivotTo(rest)
			grave.setGlow(ACCENT, 0)
			shakeAmount = 0
		end
		-- while charging the grave pulses gold
		if T >= START_CHARGE and not landed then
			local k = smooth((T - START_CHARGE) / T_CHARGE)
			grave.setGlow(GOLD, 0.3 + 0.7 * k * (0.7 + 0.3 * math.sin(T * 14)))
		end

		-- where the figure is (it emerges from the void, then falls); the circles and halos follow it
		local unitPivot
		if landed then
			unitPivot = landPivot
		elseif T >= START_DESCENT then
			local f = math.clamp((T - START_DESCENT) / T_FALL, 0, 1)
			unitPivot = skyPivot:Lerp(landPivot, f * f)
		elseif T >= START_SILHOUETTE then
			unitPivot = skyPivot + up * ((unitTall + 1.5) * (1 - smooth((T - START_SILHOUETTE) / T_EMERGE)))
		else
			unitPivot = skyPivot + up * (unitTall + 1.5)
		end
		local unitPos = unitPivot.Position

		-- ── 2. + 3. The circles ─────────────────────────────
		local charge = smooth((T - START_CHARGE) / T_CHARGE)
		table.clear(moveParts)
		table.clear(moveCFrames)
		for i, c in ipairs(circles) do
			if c.absorbed and not c.hidden and T - c.absorbT > 0.3 then
				c.hidden = true
				for _, p in ipairs(c.parts) do
					p.Transparency = 1
				end
			end
			local collapse = c.absorbed and smooth((T - c.absorbT) / 0.28) or 0
			if collapse < 1 and T >= c.appearAt then
				local a = smooth((T - c.appearAt) / 0.35)
				local scale = 0.2 + 0.8 * (1 - (1 - a) ^ 3) + 0.08 * math.sin(math.clamp((T - c.appearAt) / 0.35, 0, 1) * math.pi)
				scale = scale + (haloR / c.radius - scale) * collapse -- (it collapses onto the figure)
				-- spin: slow, then faster and faster while charging (neighbours turn against each other)
				local rate = (0.25 + 2.6 * charge * charge) * c.spinDir * (1 + 0.15 * i)
				c.angle += rate * dt
				local hubPos = c.absorbed and c.center:Lerp(unitPos + up * bodyMid, collapse) or c.center
				local hub = CFrame.new(hubPos) * CFrame.Angles(0, c.angle, 0)
				local fade = math.max(1 - a, collapse)
				for k, p in ipairs(c.parts) do
					local off = c.offsets[k]
					moveParts[#moveParts + 1] = p
					moveCFrames[#moveCFrames + 1] = hub * (off - off.Position + off.Position * scale)
					p.Transparency = fade
				end
				if T - dt < c.appearAt then
					shakeAmount, shakeStart = 0.15 + c.radius * 0.004, os.clock()
				end
			end
		end
		for _, h in ipairs(halos) do
			h.angle += h.spin * dt
			local appear = smooth((T - h.t0 - 0.12) / 0.25)
			local center, radius, tilt, trans = unitPos + up * h.y, haloR, h.tilt, 0.1 + 0.9 * (1 - appear)
			if h.releaseT then
				-- after the landing: flattened, sinking to the ground and racing outwards as a ring of runes
				local r = T - h.releaseT
				center = G + up * (0.4 + math.max(0, h.y + rootHeight - 0.4) * math.max(0, 1 - r * 4))
				radius = haloR + r * (32 + 7 * h.ring)
				tilt = CFrame.identity
				trans = math.clamp(0.1 + r * 0.75, 0, 1)
			end
			local hub = CFrame.new(center) * tilt * CFrame.Angles(0, h.angle, 0)
			for k, p in ipairs(h.parts) do
				local isRune = k > #h.parts - 3
				moveParts[#moveParts + 1] = p
				moveCFrames[#moveCFrames + 1] = hub * CFrame.Angles(0, h.offsets[k], 0) * CFrame.new(0, 0, -radius * (isRune and 1.12 or 1))
				p.Transparency = trans
				if h.releaseT and not isRune then
					p.Size = Vector3.new(2 * math.pi * radius / 22 * 0.55, 0.12, 0.16)
				end
			end
		end
		if #moveParts > 0 then
			Workspace:BulkMoveTo(moveParts, moveCFrames, Enum.BulkMoveMode.FireCFrameChanged)
		end

		-- the cone lines draw themselves from the top circle's edge down to the grave
		for _, l in ipairs(lines) do
			local f = smooth((T - START_LINES - l.delay) / 0.9)
			if f > 0 and not landed then
				local to = l.from:Lerp(tip, f)
				local len = (to - l.from).Magnitude
				local width = 0.3 + 0.25 * charge
				l.part.Size = Vector3.new(width, width, math.max(0.1, len))
				l.part.CFrame = CFrame.lookAt((l.from + to) / 2, to)
				l.part.Transparency = 0.15 - 0.1 * charge * (0.5 + 0.5 * math.sin(T * 20))
			elseif landed then
				l.part.Transparency = math.min(1, l.part.Transparency + dt * 2.5)
			end
		end

		-- runes slide down the lines into the grave while charging
		if T >= START_CHARGE and T < START_DESCENT then
			if math.random() < dt * (8 + 40 * charge) then
				for _, r in ipairs(runes) do
					if not r.alive then
						r.alive = true
						r.line = lines[math.random(#lines)]
						r.t0 = T
						r.dur = 1.3 - 0.6 * charge
						break
					end
				end
			end
		end
		for _, r in ipairs(runes) do
			if r.alive then
				local f = (T - r.t0) / r.dur
				if f >= 1 or landed then
					r.alive = false
					r.part.Transparency = 1
				else
					local pos = r.line.from:Lerp(tip, f ^ 1.4)
					r.part.CFrame = CFrame.new(pos) * CFrame.Angles(T * 3, T * 4, 0)
					r.part.Transparency = 0.1
				end
			end
		end

		-- the darkening and the wind
		if T >= START_CHARGE and not landed then
			cc.Brightness = -0.18 * charge
			cc.Contrast = 0.2 * charge
			cc.Saturation = -0.45 * charge
			cc.TintColor = Color3.new(1, 1, 1):Lerp(Color3.fromRGB(236, 230, 246), charge) -- (a faint tint: a strong one turns the gold lilac)
			for _, e in ipairs(windHolders) do
				e.Rate = 6 + 26 * charge
			end
		elseif landed then
			for _, e in ipairs(windHolders) do
				e.Rate = 0
			end
		end

		-- ── 4. The portal ───────────────────────────────────
		if T >= START_PORTAL and not landed then
			local k = smooth((T - START_PORTAL) / 0.8)
			local r = top.radius * 0.8 * k
			if not top.absorbed then
				portal.Size = Vector3.new(0.3, r * 2 + 0.1, r * 2 + 0.1)
				portal.Transparency = 0.05
				portalRim.Size = Vector3.new(0.2, r * 2 + 1.2, r * 2 + 1.2)
				portalRim.Transparency = 0.3
				for _, s in ipairs(stars) do
					local twinkle = 0.3 + 0.4 * math.sin(T * 3 + s.a * 5)
					s.part.CFrame = CFrame.new(top.center - up * 0.6 + Vector3.new(math.cos(s.a + T * 0.1), 0, math.sin(s.a + T * 0.1)) * r * 0.95 * s.d)
					s.part.Transparency = 1 - k * (1 - twinkle)
				end
			end
			if T >= START_SILHOUETTE and silhouette and T < START_DESCENT then
				-- it slowly sinks out of the void, fading in from nothing
				local e = smooth((T - START_SILHOUETTE) / T_EMERGE)
				silhouette:PivotTo(unitPivot)
				for _, d in ipairs(silhouette:GetDescendants()) do
					if d:IsA("BasePart") then
						d.LocalTransparencyModifier = 1 - e
					end
				end
				if not portalShown then
					portalShown = true
					voidWisps.Enabled = true
				end
			end
		end

		-- ── 5. The descent ─────────────────────────────────
		if T >= START_DESCENT and not landed then
			local f = math.clamp((T - START_DESCENT) / T_FALL, 0, 1)
			voidWisps.Enabled = false
			if silhouette then
				silhouette:PivotTo(unitPivot)
				for _, d in ipairs(silhouette:GetDescendants()) do
					if d:IsA("BasePart") then
						d.LocalTransparencyModifier = 0
					end
				end
			end
			-- the portal closes behind it
			portal.Transparency = math.min(1, portal.Transparency + dt * 2)
			portalRim.Transparency = math.min(1, portalRim.Transparency + dt * 2)
			for _, s in ipairs(stars) do
				s.part.Transparency = math.min(1, s.part.Transparency + dt * 2)
			end
			-- every circle it passes collapses onto it and becomes a halo
			for _, c in ipairs(circles) do
				if not c.absorbed and unitPos.Y + bodyMid < c.center.Y then
					absorb(c)
				end
			end
			if f >= 1 then
				for _, c in ipairs(circles) do
					if not c.absorbed then
						absorb(c)
					end
				end
				land()
			end
		end

		-- flying shards and raining sparks
		local now = os.clock()
		for i = #shards, 1, -1 do
			local s = shards[i]
			local age = now - s.t0
			if age >= 0 then
				local pos = s.cf.Position + s.vel * age - up * (0.5 * s.gravity * age * age)
				s.part.CFrame = CFrame.new(pos) * (s.cf - s.cf.Position) * CFrame.Angles(s.spin.X * age, s.spin.Y * age, s.spin.Z * age)
				s.part.Transparency = math.clamp((age - s.life * 0.5) / (s.life * 0.5), 0, 1)
			end
			if age > s.life then
				s.part:Destroy()
				table.remove(shards, i)
			end
		end

		-- the name once the unit is down
		if landed then
			local k = smooth((T - START_LAND - 0.6) / 0.7)
			nameLbl.TextTransparency = 1 - k
			nameLbl.TextStrokeTransparency = 1 - k
			rarityLbl.TextTransparency = 1 - k
			rarityLbl.TextStrokeTransparency = 1 - k
		end

		-- ── Camera ──────────────────────────────────────────
		local camPos, camLook, fov
		local roll = 0
		if T < START_CIRCLES then
			-- the bait: exactly like a hand-opened grave
			local k = smooth(T / START_CIRCLES)
			local fromStart = smooth(T / 0.8)
			camPos = startCam.Position:Lerp(camArrive:Lerp(camClose, k), fromStart)
			camLook = (startCam.Position + startCam.LookVector * 20):Lerp(lookGrave, fromStart)
			fov = 62 - 10 * k
		elseif T < START_LINES then
			-- the rings build: the camera pulls back from the grave to the side view (arching up a little) so they are seen
			-- opening from the side; the look climbs from the grave to the middle of the spire
			local k = smooth((T - START_CIRCLES) / (START_LINES - START_CIRCLES))
			camPos = camClose:Lerp(camWide, k) + up * math.sin(k * math.pi) * 18
			camLook = lookGrave:Lerp(G + up * (TOP_HEIGHT * 0.5), smooth(math.min(1, k * 1.25)))
			fov = 52 + 8 * k
		elseif T < START_PORTAL then
			-- the whole spire, wide, drifting slowly round
			local drift = (T - START_LINES) * 0.05
			camPos = G + CFrame.Angles(0, drift, 0) * (camWide - G)
			camLook = G + up * (TOP_HEIGHT * 0.5)
			fov = 60
			shakeAmount, shakeStart = math.max(shakeAmount * math.exp(-dt * 4), 0.06 * charge), os.clock()
		elseif T < START_DESCENT then
			-- up to the portal
			local k = smooth((T - START_PORTAL) / 0.9)
			local drift = (START_PORTAL - START_LINES) * 0.05
			local wide = G + CFrame.Angles(0, drift, 0) * (camWide - G)
			-- then a slow zoom onto the figure while it comes out of the void (the look follows it down)
			local zoom = smooth((T - START_SILHOUETTE) / (T_EMERGE + 0.2))
			camPos = wide:Lerp(camPortal, k)
			camLook = (G + up * (TOP_HEIGHT * 0.5)):Lerp(unitPos + up * bodyMid, k)
			fov = 60 + (ZOOM_FOV - 60) * zoom
		elseif not landed then
			-- the fall: the camera spirals round the falling figure, from above it looking down into the cone, round about
			-- 270 degrees while the halos gather, ending low on the ground looking up as it slams into the grave
			local f = math.clamp((T - START_DESCENT) / T_FALL, 0, 1)
			local e = smooth(f)
			local body = unitPos + up * bodyMid
			local a = math.rad(-35) + e * math.rad(270)
			local around = (-dir * math.cos(a) + right * math.sin(a))
			local orbitPos = body + around * (24 - 10 * e) + up * (12 - 20 * e)
			-- the last stretch eases into a fixed low shot by the grave (it would otherwise dive into the ground)
			local low = G - dir * 17 + right * 7 + up * 1.6
			local k = smooth((f - 0.72) / 0.28)
			camPos = orbitPos:Lerp(low, k)
			camLook = body:Lerp(G + up * (unitTall * 0.6), k * 0.6)
			fov = 66 + 18 * math.sin(f * math.pi) + 6 * k
			roll = math.sin(f * math.pi) * 0.22 -- (a slight tilt into the turn)
		else
			-- the hero shot after the landing, slowly orbiting
			local k = smooth((T - START_LAND) / 1.2)
			local orbit = math.max(0, T - START_LAND - 1.2) * 0.1
			local hero = G + (dir * -heroDist) * math.cos(orbit) + right * (6 * math.cos(orbit) + 14 * math.sin(orbit)) + up * heroCamY
			camPos = (G - dir * 12 + right * 4 + up * 7):Lerp(hero, k)
			camLook = G + up * heroLookY
			fov = 82 + (HERO_FOV - 82) * k
		end
		local shake = shakeAmount * math.exp(-(os.clock() - shakeStart) * (landed and 3 or 6))
		local jitter = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 2 * shake
		camera.CFrame = CFrame.lookAt(camPos + jitter, camLook + jitter * 0.5) * CFrame.Angles(0, 0, roll)
		camera.FieldOfView = fov
	end)
	return true
end

return SignatureDescent
