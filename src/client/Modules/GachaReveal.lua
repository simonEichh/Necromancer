-- The gacha reveal: what you see when graves are opened (an overlay that does not cover the whole screen).
--
--   GachaReveal.play(results, opts)
--     results: list of { unitType, rarity, pity, oneIn } (one entry per grave opened, from the server's RollResult)
--     opts:    graveType  the grave that was opened (its picture is the thing that cracks open)
--              autoRoll   function() -> bool, true while Auto Roll is on (the reveal then closes itself shortly after)
--              setAuto    function(bool), called when the player toggles Auto Roll in the overlay
--              onRevealed function(), called when the result is shown (the caller releases held data updates)
--              onClose    function(), called when the overlay closes (Collect, or auto roll continuing)
--              ownedLeft  function() -> number, how many graves of that type the player still has (for "Open x10")
--              openMore   function(count), asks the caller to open `count` more graves
--
-- Phases of one reveal: 1. buildup (the grave shakes and cracks, its glow slowly hints at the rarity, a big rarity may
-- flicker out right before the burst), 2. burst (flash, shockwave rings, sparks, the panel shakes), 3. reveal (a 3D
-- portrait of the unit turns slowly on a stone plinth, with its name, rarity and odds), 4. Collect.
-- With several results the BEST one gets the full dramatic reveal, then a grid with all of them. Skip jumps straight
-- to the revealed state at any time.
--
-- Everything scales smoothly with the rarity RANK (Rarities.Rank) instead of special-casing tiers, so new rarities work
-- without changes here: t = 0 for the lowest rank and t = 1 for the highest.
-- The portraits need the unit models on the client: ReplicatedStorage.UnitModels (tools/studio/publish_unit_models.lua).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.Theme)
local GameData = require(script.Parent.GameData)
local screenGui = require(script.Parent.Gui)
local Rarities = require(ReplicatedStorage.Shared.Rarities)

local C = Theme.Color
local Z = 60 -- base ZIndex (the UI uses global z-ordering; this is above the panels)

local GachaReveal = {}
GachaReveal.active = nil -- the overlay currently shown

-- Sounds: put Roblox sound asset ids here (all optional); the reveal plays them when set.
GachaReveal.Sounds = { buildup = nil, burst = nil, reveal = nil, rare = nil, collect = nil }
local function playSound(name)
	local id = GachaReveal.Sounds[name]
	if id then
		local s = Instance.new("Sound")
		s.SoundId = id
		s.Volume = 0.6
		s.Parent = screenGui
		s:Play()
		game:GetService("Debris"):AddItem(s, 6)
	end
end

local MAX_RANK = 1
for _, r in pairs(Rarities.Rank) do
	MAX_RANK = math.max(MAX_RANK, r)
end

-- 0 .. 1: how rare a rarity is (by rank)
local function tierOf(rarity)
	return math.clamp(((Rarities.Rank[rarity] or 1) - 1) / math.max(1, MAX_RANK - 1), 0, 1)
end

local function rarityColor(rarity)
	return GameData.RARITY_COLORS[rarity] or Rarities.Color[rarity] or C.Bone
end

local function tween(inst, seconds, props, style, direction)
	local t = TweenService:Create(inst, TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out), props)
	t:Play()
	return t
end

-- ============================================================
-- 3D portrait (ViewportFrame with the unit's real model)
-- ============================================================
local function makePortrait(parent, unitType, size, startAngleDeg)
	local vp = Instance.new("ViewportFrame")
	vp.BackgroundTransparency = 1
	vp.Size = size
	vp.Ambient = Color3.fromRGB(175, 175, 185)
	vp.LightColor = Color3.fromRGB(255, 244, 230)
	vp.LightDirection = Vector3.new(-0.4, -0.7, -0.6)
	vp.ZIndex = Z + 5
	vp.Parent = parent

	local folder = ReplicatedStorage:FindFirstChild("UnitModels")
	local template = folder and folder:FindFirstChild(unitType)
	if not template then
		-- no model on the client: show the name's initials on a plinth-coloured block
		local lbl = Theme.label(vp, { text = unitType:sub(1, 2), size = "Title", font = "Title", align = Enum.TextXAlignment.Center, frameSize = UDim2.fromScale(1, 1) })
		lbl.ZIndex = Z + 6
		return vp, nil
	end

	local model = template:Clone()
	model.Parent = vp
	local _, boxSize = model:GetBoundingBox()
	-- turn the model around the middle of its bounding box (its pivot is the root part, not always the centre)
	local center = model:GetBoundingBox().Position
	local pivot = model:GetPivot()
	local offset = pivot:ToObjectSpace(CFrame.new(center)).Position

	local cam = Instance.new("Camera")
	cam.FieldOfView = 36
	vp.CurrentCamera = cam
	cam.Parent = vp
	local radius = boxSize.Magnitude / 2
	local dist = radius / math.tan(math.rad(cam.FieldOfView / 2)) * 1.0
	cam.CFrame = CFrame.lookAt(Vector3.new(0, 0, -dist), Vector3.zero)

	local state = { model = model, angle = math.rad(startAngleDeg or 200) }
	function state.update(angle)
		state.angle = angle
		-- put the bounding-box centre at the origin and turn around it
		model:PivotTo(CFrame.Angles(0, angle, 0) * CFrame.new(-offset))
	end
	state.update(state.angle)
	return vp, state
end

-- ============================================================
-- Small effect helpers (frames and tweens inside a clipped stage)
-- ============================================================
local function circle(parent, diameter, color, transparency, strokeOnly, thickness)
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromScale(0.5, 0.5)
	f.Size = UDim2.fromOffset(diameter, diameter)
	f.BorderSizePixel = 0
	f.ZIndex = Z + 2
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = f
	if strokeOnly then
		f.BackgroundTransparency = 1
		local s = Instance.new("UIStroke")
		s.Color = color
		s.Thickness = thickness or 4
		s.Transparency = transparency
		s.Parent = f
	else
		f.BackgroundColor3 = color
		f.BackgroundTransparency = transparency
	end
	f.Parent = parent
	return f
end

local function burstSparks(parent, origin, color, count, spread)
	for _ = 1, count do
		local s = Instance.new("Frame")
		local size = math.random(4, 9)
		s.Size = UDim2.fromOffset(size, size)
		s.AnchorPoint = Vector2.new(0.5, 0.5)
		s.Position = origin
		s.Rotation = math.random(0, 90)
		s.BackgroundColor3 = (math.random() < 0.4) and Color3.new(1, 1, 1) or color
		s.BorderSizePixel = 0
		s.ZIndex = Z + 7
		s.Parent = parent
		local ang = math.random() * math.pi * 2
		local dist = spread * (0.35 + math.random() * 0.75)
		local life = 0.5 + math.random() * 0.7
		tween(s, life, {
			Position = origin + UDim2.fromOffset(math.cos(ang) * dist, math.sin(ang) * dist + 60 * life), -- a little gravity
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(1, 1),
		})
		game:GetService("Debris"):AddItem(s, life + 0.1)
	end
end

-- ============================================================
-- The overlay
-- ============================================================
local function closeActive(instant)
	local o = GachaReveal.active
	if not o then
		return
	end
	GachaReveal.active = nil
	o.dead = true
	if o.conn then
		o.conn:Disconnect()
	end
	if instant then
		o.panel:Destroy()
		return
	end
	tween(o.panel, 0.18, { BackgroundTransparency = 1 })
	task.delay(0.2, function()
		o.panel:Destroy()
	end)
end

function GachaReveal.close()
	closeActive(true)
end

function GachaReveal.play(results, opts)
	opts = opts or {}
	closeActive(true)
	if not results or #results == 0 then
		return
	end

	-- the best result gets the dramatic reveal
	local best = results[1]
	for _, r in ipairs(results) do
		if (Rarities.Rank[r.rarity] or 0) > (Rarities.Rank[best.rarity] or 0) then
			best = r
		end
	end
	local multi = #results > 1
	local rc = rarityColor(best.rarity)
	local t = tierOf(best.rarity)

	local o = { dead = false, skipped = false, revealed = false }
	GachaReveal.active = o

	-- ── Panel (a stone slab, not the whole screen) ───────────
	local panel = Instance.new("Frame")
	panel.Name = "GachaReveal"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.4)
	panel.Size = UDim2.fromOffset(multi and 760 or 560, multi and 520 or 470)
	panel.BackgroundColor3 = C.Void
	panel.BorderSizePixel = 0
	panel.ClipsDescendants = true
	panel.ZIndex = Z
	Theme.corner(panel, Theme.Radius.Medium)
	local rim = Theme.stroke(panel, C.Border, Theme.Stroke.Frame)
	panel.Parent = screenGui
	o.panel = panel
	local basePos = panel.Position
	panel.BackgroundTransparency = 1
	tween(panel, 0.2, { BackgroundTransparency = 0 })

	local stage = Instance.new("Frame") -- the area above the buttons
	stage.BackgroundTransparency = 1
	stage.Size = UDim2.new(1, 0, 1, -76)
	stage.ZIndex = Z + 1
	stage.Parent = panel
	local middle = UDim2.fromScale(0.5, 0.5)

	-- a faint rarity-coloured glow at the bottom of the stage, so the whole slab feels lit by what is inside
	local ground = Instance.new("Frame")
	ground.AnchorPoint = Vector2.new(0.5, 1)
	ground.Position = UDim2.fromScale(0.5, 1)
	ground.Size = UDim2.new(1, 0, 0.35, 0)
	ground.BackgroundColor3 = rc
	ground.BackgroundTransparency = 1
	ground.BorderSizePixel = 0
	ground.ZIndex = Z + 1
	local gg = Instance.new("UIGradient")
	gg.Rotation = 90
	gg.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0.55) })
	gg.Parent = ground
	ground.Parent = stage

	-- ── The grave (a picture, or a stone block) ──────────────
	-- (GameData.GRAVE_DATA is an ordered list, so look the grave up by its key)
	local graveUi
	for _, g in ipairs(GameData.GRAVE_DATA or {}) do
		if g.key == opts.graveType then
			graveUi = g
			break
		end
	end
	local grave
	if graveUi and graveUi.image and graveUi.image ~= "" then
		grave = Instance.new("ImageLabel")
		grave.Image = graveUi.image
		grave.BackgroundTransparency = 1
	else
		-- no picture for this grave: a tombstone drawn from a rounded top and a block, with a carved cross
		grave = Instance.new("Frame")
		grave.BackgroundTransparency = 1
		local function stone(size, pos, color, round)
			local f = Instance.new("Frame")
			f.Size = size
			f.Position = pos
			f.BackgroundColor3 = color
			f.BorderSizePixel = 0
			f.ZIndex = Z + 4
			if round then
				Theme.corner(f, 999)
			end
			f.Parent = grave
			return f
		end
		stone(UDim2.fromScale(1, 0.64), UDim2.fromScale(0, 0), C.StoneHover, true)
		stone(UDim2.fromScale(1, 0.62), UDim2.fromScale(0, 0.38), C.StoneHover, false)
		stone(UDim2.fromScale(0.84, 0.54), UDim2.fromScale(0.08, 0.1), C.StoneRaised, true)
		stone(UDim2.fromScale(0.84, 0.54), UDim2.fromScale(0.08, 0.38), C.StoneRaised, false)
		stone(UDim2.fromScale(0.08, 0.36), UDim2.fromScale(0.46, 0.22), C.Border, false)
		stone(UDim2.fromScale(0.26, 0.07), UDim2.fromScale(0.37, 0.3), C.Border, false)
	end
	grave.AnchorPoint = Vector2.new(0.5, 0.5)
	grave.Size = UDim2.fromOffset(140, 170)
	grave.Position = UDim2.fromScale(0.5, 0.46)
	grave.ZIndex = Z + 4
	grave.Parent = stage
	local graveBase = grave.Position

	-- three glow discs behind the grave
	local glows = {}
	for i, d in ipairs({ 190, 250, 320 }) do
		local g = circle(stage, d, C.Border, 1, false)
		g.Position = UDim2.fromScale(0.5, 0.46)
		g.ZIndex = Z + 2
		glows[i] = g
	end

	-- white flash over the stage
	local flash = Instance.new("Frame")
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = Color3.new(1, 1, 1)
	flash.BackgroundTransparency = 1
	flash.BorderSizePixel = 0
	flash.ZIndex = Z + 9
	flash.Parent = panel

	-- ── Result texts and portrait (hidden until the reveal) ──
	local plinth = Instance.new("Frame")
	plinth.AnchorPoint = Vector2.new(0.5, 0.5)
	plinth.Position = UDim2.fromScale(0.5, 0.83)
	plinth.Size = UDim2.fromOffset(210, 14)
	plinth.BackgroundColor3 = C.StoneRaised
	plinth.BorderSizePixel = 0
	plinth.BackgroundTransparency = 1
	plinth.ZIndex = Z + 3
	Theme.corner(plinth, 7)
	plinth.Parent = stage

	local nameLbl = Theme.label(stage, { text = "", size = "Title", font = "Title", color = rc, align = Enum.TextXAlignment.Center, frameSize = UDim2.new(1, 0, 0, 40) })
	nameLbl.Position = UDim2.new(0, 0, 0, 12)
	nameLbl.TextSize = 38
	nameLbl.ZIndex = Z + 8
	Theme.outlineText(nameLbl)
	nameLbl.TextTransparency = 1
	nameLbl.TextStrokeTransparency = 1

	local infoLbl = Theme.label(stage, { text = "", size = "Body", font = "Body", color = C.BoneDim, align = Enum.TextXAlignment.Center, frameSize = UDim2.new(1, 0, 0, 22) })
	infoLbl.Position = UDim2.new(0, 0, 1, -34)
	infoLbl.ZIndex = Z + 8
	infoLbl.TextTransparency = 1

	local rarityLbl = Theme.label(stage, { text = "", size = "Heading", font = "Strong", color = rc, align = Enum.TextXAlignment.Center, frameSize = UDim2.new(1, 0, 0, 26) })
	rarityLbl.Position = UDim2.new(0, 0, 0, 54)
	rarityLbl.ZIndex = Z + 8
	Theme.outlineText(rarityLbl)
	rarityLbl.TextTransparency = 1
	rarityLbl.TextStrokeTransparency = 1

	-- ── Buttons ──────────────────────────────────────────────
	local bar = Instance.new("Frame")
	bar.BackgroundTransparency = 1
	bar.AnchorPoint = Vector2.new(0, 1)
	bar.Position = UDim2.fromScale(0, 1)
	bar.Size = UDim2.new(1, 0, 0, 76)
	bar.ZIndex = Z + 10
	bar.Parent = panel

	local function placeButton(btn, xScale, xOffset)
		btn.root.AnchorPoint = Vector2.new(0.5, 0.5)
		btn.root.Position = UDim2.new(xScale, xOffset, 0.5, 0)
	end
	local primary = Theme.stoneButton(bar, { text = "Skip", color = "stone", size = UDim2.fromOffset(150, 44), zIndex = Z + 11 })
	local autoBtn = Theme.stoneButton(bar, { text = "Auto: OFF", color = "stone", size = UDim2.fromOffset(150, 44), zIndex = Z + 11 })
	local moreBtn = Theme.stoneButton(bar, { text = "Open x10", color = "gold", size = UDim2.fromOffset(150, 44), zIndex = Z + 11 })
	placeButton(primary, 0.5, 0)
	placeButton(autoBtn, 0.5, -170)
	placeButton(moreBtn, 0.5, 170)
	moreBtn.root.Visible = false

	local function refreshAuto()
		local on = opts.autoRoll and opts.autoRoll() or false
		autoBtn.label.Text = on and "Auto: ON" or "Auto: OFF"
	end
	refreshAuto()
	autoBtn.button.Activated:Connect(function()
		if opts.setAuto then
			opts.setAuto(not (opts.autoRoll and opts.autoRoll() or false))
		end
		refreshAuto()
	end)

	-- ── Closing ──────────────────────────────────────────────
	local function finish(thenOpenMore)
		if o.dead then
			return
		end
		playSound("collect")
		closeActive(false)
		if opts.onClose then
			opts.onClose()
		end
		if thenOpenMore and opts.openMore then
			opts.openMore(thenOpenMore)
		end
	end

	-- ── Reveal state (also what Skip jumps to) ───────────────
	local portrait, portraitState
	local function showResultState()
		if o.revealed or o.dead then
			return
		end
		o.revealed = true
		if opts.onRevealed then
			opts.onRevealed()
		end
		grave.Visible = false
		for _, g in ipairs(glows) do
			g.BackgroundColor3 = rc
			tween(g, 0.4, { BackgroundTransparency = 0.88 - 0.1 * t })
		end
		tween(ground, 0.5, { BackgroundTransparency = 0.7 - 0.2 * t })
		tween(rim, 0.4, { Color = rc })
		tween(plinth, 0.4, { BackgroundTransparency = 0 })

		nameLbl.Text = best.unitType
		rarityLbl.Text = tostring(best.rarity):upper()
		infoLbl.Text = "1 in " .. tostring(best.oneIn or GameData.UNIT_ONE_IN[best.unitType] or "?") .. "     Pity " .. tostring(best.pity or 0) .. " / 60"
		tween(nameLbl, 0.35, { TextTransparency = 0, TextStrokeTransparency = 0 })
		tween(rarityLbl, 0.35, { TextTransparency = 0, TextStrokeTransparency = 0 })
		tween(infoLbl, 0.35, { TextTransparency = 0 })

		-- the 3D portrait rises onto the plinth and turns slowly
		local portraitSize = multi and 210 or 240
		portrait, portraitState = makePortrait(stage, best.unitType, UDim2.fromOffset(portraitSize, portraitSize))
		portrait.AnchorPoint = Vector2.new(0.5, 0.5)
		portrait.Position = UDim2.new(0.5, 0, 0.85, 30)
		tween(portrait, 0.55, { Position = UDim2.new(0.5, 0, 0.5, 8) }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		if portraitState then
			local start = os.clock()
			o.conn = RunService.RenderStepped:Connect(function()
				if o.dead then
					return
				end
				portraitState.update(math.rad(200) + (os.clock() - start) * 0.9)
			end)
		end
		playSound(t > 0.5 and "rare" or "reveal")

		primary.label.Text = multi and "Show all" or "Collect"
		primary.root:SetAttribute("Disabled", false)
	end

	-- the grid of all results (after the best unit, for several pulls)
	local function showGrid()
		if o.dead then
			return
		end
		if o.conn then
			o.conn:Disconnect()
			o.conn = nil
		end
		for _, child in ipairs(stage:GetChildren()) do
			if child ~= ground then
				child:Destroy()
			end
		end
		local grid = Instance.new("Frame")
		grid.BackgroundTransparency = 1
		grid.Size = UDim2.new(1, -40, 1, -20)
		grid.Position = UDim2.fromOffset(20, 10)
		grid.ZIndex = Z + 3
		grid.Parent = stage
		local layout = Instance.new("UIGridLayout")
		layout.CellSize = UDim2.fromOffset(128, 196)
		layout.CellPadding = UDim2.fromOffset(10, 12)
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		layout.VerticalAlignment = Enum.VerticalAlignment.Center
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = grid
		for i, r in ipairs(results) do
			local card = Instance.new("Frame")
			card.LayoutOrder = i
			card.BackgroundColor3 = C.Stone:Lerp(rarityColor(r.rarity), 0.14)
			card.BorderSizePixel = 0
			card.ZIndex = Z + 4
			Theme.corner(card, Theme.Radius.Small)
			Theme.stroke(card, rarityColor(r.rarity), r == best and 4 or 2)
			card.Parent = grid
			local vp = makePortrait(card, r.unitType, UDim2.new(1, -8, 0, 130), -25) -- (front view for the grid)
			vp.Position = UDim2.fromOffset(4, 4)
			vp.ZIndex = Z + 5
			local nm = Theme.label(card, { text = r.unitType, size = "Small", font = "Strong", color = rarityColor(r.rarity), align = Enum.TextXAlignment.Center, frameSize = UDim2.new(1, -6, 0, 20) })
			nm.Position = UDim2.new(0, 3, 0, 138)
			nm.ZIndex = Z + 6
			Theme.outlineText(nm)
			local rr = Theme.label(card, { text = tostring(r.rarity), size = "Small", font = "Body", color = C.BoneDim, align = Enum.TextXAlignment.Center, frameSize = UDim2.new(1, -6, 0, 18) })
			rr.Position = UDim2.new(0, 3, 0, 158)
			rr.ZIndex = Z + 6
			-- fade in, one after another
			card.BackgroundTransparency = 1
		end
		for i, card in ipairs(grid:GetChildren()) do
			if card:IsA("Frame") then
				task.delay(0.07 * i, function()
					if not o.dead then
						card.BackgroundTransparency = 0
					end
				end)
			end
		end
		primary.label.Text = "Collect"
		primary.root:SetAttribute("Disabled", false)
		o.gridShown = true
		-- "Open x10" once all results are shown
		local left = opts.ownedLeft and opts.ownedLeft() or 0
		if left > 0 and opts.openMore then
			moreBtn.label.Text = "Open x" .. math.min(10, left)
			moreBtn.root.Visible = true
			moreBtn.button.Activated:Connect(function()
				finish(math.min(10, left))
			end)
		end
	end

	-- the Skip / Collect button
	local function advance()
		if o.dead then
			return
		end
		if not o.revealed then
			o.skipped = true
			showResultState()
		elseif multi and not o.gridShown then
			showGrid()
		else
			finish()
		end
	end
	primary.button.Activated:Connect(advance)
	o.advance = advance -- (also lets tests press the main button)

	-- ── The show: buildup, burst, reveal ─────────────────────
	task.spawn(function()
		local buildup = 0.8 + 1.7 * t -- seconds
		local fake = t > 0.55 -- big rarities flicker out right before the burst
		local start = os.clock()
		local grey = C.BoneDim
		playSound("buildup")
		while not o.dead and not o.skipped do
			local p = (os.clock() - start) / buildup
			if p >= 1 then
				break
			end
			-- shake grows towards the end
			local amp = (2 + 12 * p * (0.5 + t)) * ((fake and p > 0.84) and 0.2 or 1)
			grave.Position = graveBase + UDim2.fromOffset((math.random() - 0.5) * amp, (math.random() - 0.5) * amp)
			grave.Rotation = (math.random() - 0.5) * amp * 0.5
			-- the glow hints at the rarity (more and more) and pulses faster
			local hint = math.clamp((p - 0.25) / 0.75, 0, 1)
			local colour = grey:Lerp(rc, hint ^ 2 * (0.55 + 0.45 * t))
			local pulse = 0.5 + 0.5 * math.sin(os.clock() * (6 + 18 * p))
			local silent = fake and p > 0.84
			for i, g in ipairs(glows) do
				g.BackgroundColor3 = colour
				g.BackgroundTransparency = silent and 1 or (0.93 - (0.18 + 0.12 * pulse) * p * (1 + 0.4 * i / 3))
			end
			RunService.RenderStepped:Wait()
		end
		if o.dead then
			return
		end
		grave.Position = graveBase
		grave.Rotation = 0

		if not o.skipped then
			-- burst: flash, rings, sparks, panel shake
			playSound("burst")
			grave.Visible = false
			flash.BackgroundColor3 = Color3.new(1, 1, 1):Lerp(rc, 0.25)
			flash.BackgroundTransparency = 0.15 - 0.15 * t
			tween(flash, 0.4 + 0.5 * t, { BackgroundTransparency = 1 })
			local rings = 2 + math.floor(3 * t)
			for i = 1, rings do
				task.delay(0.08 * (i - 1), function()
					if o.dead then
						return
					end
					local ring = circle(stage, 60, rc, 0, true, 6 - i * 0.6)
					ring.Position = UDim2.fromScale(0.5, 0.46)
					tween(ring, 0.7 + 0.2 * i, { Size = UDim2.fromOffset(620 + 120 * i, 620 + 120 * i) })
					tween(ring.UIStroke, 0.7 + 0.2 * i, { Transparency = 1 })
					game:GetService("Debris"):AddItem(ring, 1.5)
				end)
			end
			burstSparks(stage, UDim2.fromScale(0.5, 0.46), rc, math.floor(18 + 60 * t), 250 + 140 * t)
			-- shake the whole slab
			local shakeTime = 0.25 + 0.4 * t
			local s0 = os.clock()
			while not o.dead and os.clock() - s0 < shakeTime do
				local k = 1 - (os.clock() - s0) / shakeTime
				panel.Position = basePos + UDim2.fromOffset((math.random() - 0.5) * 14 * k * (1 + t), (math.random() - 0.5) * 14 * k * (1 + t))
				RunService.RenderStepped:Wait()
			end
			panel.Position = basePos
			task.wait(0.12)
		end
		if o.dead then
			return
		end
		showResultState()
		-- auto roll closes by itself shortly after the reveal
		if not multi and opts.autoRoll and opts.autoRoll() then
			task.wait(0.9 + 0.8 * t)
			if not o.dead and opts.autoRoll() then
				finish()
			end
		end
	end)

	return o
end

return GachaReveal
