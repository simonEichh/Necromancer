-- The look of all UI: dark gothic (dark stone, aged bone, verdigris, soul-green glow, rarity colours as accents).
-- Every panel takes its colours, fonts and shapes from here, and builds its buttons and frames with the helpers,
-- so changing the look means changing this file. No emojis anywhere (icons are drawn or rendered portraits).
--
--   local Theme = require(script.Parent.Theme)
--   local panel = Theme.panel(parent, { title = "Inventory", size = UDim2.fromOffset(420, 360) })
--   local btn = Theme.button(panel.body, { text = "Buy", style = "primary", size = UDim2.fromOffset(120, 36), onClick = fn })
--   Theme.rarityColor("Legendary")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Rarities = require(ReplicatedStorage.Shared.Rarities)

local Theme = {}

-- ============================================================
-- Palette
-- ============================================================
Theme.Color = {
	-- surfaces, dark to light
	Void = Color3.fromRGB(10, 12, 14), -- behind everything
	Stone = Color3.fromRGB(22, 25, 28), -- panel background
	StoneRaised = Color3.fromRGB(34, 38, 42), -- cards, buttons at rest
	StoneHover = Color3.fromRGB(46, 52, 56), -- hovered
	-- lines and text
	Border = Color3.fromRGB(70, 78, 72), -- worn bronze-grey frame lines
	BorderBright = Color3.fromRGB(122, 148, 126), -- focused / selected frame
	Bone = Color3.fromRGB(222, 214, 190), -- main text
	BoneDim = Color3.fromRGB(150, 145, 128), -- secondary text
	-- accents
	Soul = Color3.fromRGB(120, 255, 170), -- the signature spectral green: primary actions, highlights, glow
	SoulDeep = Color3.fromRGB(38, 110, 72), -- primary button fill
	Verdigris = Color3.fromRGB(74, 140, 120),
	Gold = Color3.fromRGB(226, 186, 92), -- gold currency
	Gem = Color3.fromRGB(110, 200, 255), -- gem currency
	Blood = Color3.fromRGB(176, 56, 56), -- danger, destructive actions
	BloodDeep = Color3.fromRGB(96, 28, 30),
	Good = Color3.fromRGB(120, 230, 140),
	Warn = Color3.fromRGB(240, 190, 80),
}

-- Rarity colours come from the shared tables, so adding a rarity there is enough (no per-rarity special cases here).
function Theme.rarityColor(rarity)
	return Rarities.Color[rarity] or Theme.Color.Bone
end

-- ============================================================
-- Type, shape, motion
-- ============================================================
-- FredokaOne is the closest built-in match to Lilita One, the font of the Figma button design (Roblox cannot import font
-- files, so Lilita One itself is not available). Titles and buttons use it; body text and numbers stay Gotham for readability.
Theme.Font = {
	Title = Enum.Font.FredokaOne,
	Body = Enum.Font.GothamMedium,
	Strong = Enum.Font.FredokaOne,
}
Theme.TextSize = { Small = 13, Body = 16, Heading = 22, Title = 30 }

Theme.Radius = { Small = 4, Medium = 8, Large = 12 } -- squarer than a soft app look: carved stone, not bubbles
Theme.Stroke = { Thin = 1, Frame = 2 }
Theme.Tween = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
-- the painted panel frame (Theme.Image.PanelFrame, defined further down) is 9-sliced with these
local PANEL_SLICE = Rect.new(130, 130, 894, 877)
local PANEL_SLICE_SCALE = 0.34 -- the border is about 28 px on screen
local PANEL_FRAME_MARGIN = 28 -- the border hangs outside the panel by this much, so the content area stays the same
-- Panels without an explicit position are centred in the free space between the top travel tile
-- and the hotbar, and shrink (UIScale) when they and their frame do not fit there, so they never cover those.
local PANEL_TOP_RESERVE = 100 -- screen pixels kept free at the top (the travel tile)
local PANEL_BOTTOM_RESERVE = 146 -- and at the bottom (hotbar)
local PANEL_SIDE_RESERVE = 100 -- and at each side (menu tiles)

-- ============================================================
-- Small building blocks
-- ============================================================
function Theme.corner(inst, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or Theme.Radius.Medium)
	c.Parent = inst
	return c
end

function Theme.stroke(inst, color, thickness)
	local s = Instance.new("UIStroke")
	s.Color = color or Theme.Color.Border
	s.Thickness = thickness or Theme.Stroke.Thin
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = inst
	return s
end

function Theme.padding(inst, amount)
	local p = Instance.new("UIPadding")
	local u = UDim.new(0, amount or 8)
	p.PaddingTop, p.PaddingBottom, p.PaddingLeft, p.PaddingRight = u, u, u, u
	p.Parent = inst
	return p
end

-- The chunky look of the button text: a thick dark outline (TextStrokeColor3 / TextStrokeTransparency on the label).
Theme.TextStroke = { Color = Color3.fromRGB(8, 24, 16), Transparency = 0 }

function Theme.outlineText(label)
	label.TextStrokeColor3 = Theme.TextStroke.Color
	label.TextStrokeTransparency = Theme.TextStroke.Transparency
end

-- A text label in the theme. opts: text, size ("Small"|"Body"|"Heading"|"Title"), color, font ("Title"|"Body"|"Strong"), align
function Theme.label(parent, opts)
	opts = opts or {}
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Text = opts.text or ""
	l.Font = Theme.Font[opts.font or "Body"]
	l.TextSize = Theme.TextSize[opts.size or "Body"]
	l.TextColor3 = opts.color or Theme.Color.Bone
	l.TextXAlignment = opts.align or Enum.TextXAlignment.Left
	l.Size = opts.frameSize or UDim2.new(1, 0, 0, Theme.TextSize[opts.size or "Body"] + 6)
	l.Parent = parent
	return l
end

-- ============================================================
-- Button
-- ============================================================
-- Styles: "primary" (soul green, the main action), "default" (stone), "danger" (blood red), "ghost" (no fill).
local BUTTON_STYLES = {
	primary = { fill = Theme.Color.SoulDeep, hover = Color3.fromRGB(52, 140, 92), border = Theme.Color.Soul, text = Theme.Color.Bone },
	default = { fill = Theme.Color.StoneRaised, hover = Theme.Color.StoneHover, border = Theme.Color.Border, text = Theme.Color.Bone },
	danger = { fill = Theme.Color.BloodDeep, hover = Color3.fromRGB(130, 40, 42), border = Theme.Color.Blood, text = Theme.Color.Bone },
	ghost = { fill = Theme.Color.Stone, hover = Theme.Color.StoneRaised, border = Theme.Color.Border, text = Theme.Color.BoneDim },
}

-- opts: text, style, size (UDim2), position (UDim2), onClick (function), disabled (bool)
-- Returns the TextButton; button:SetAttribute("Disabled", true/false) enables or disables it later.
function Theme.button(parent, opts)
	opts = opts or {}
	local style = BUTTON_STYLES[opts.style or "default"]
	local b = Instance.new("TextButton")
	b.AutoButtonColor = false
	b.BackgroundColor3 = style.fill
	b.BorderSizePixel = 0
	b.Text = opts.text or ""
	b.Font = Theme.Font.Strong
	b.TextSize = Theme.TextSize.Heading
	b.TextColor3 = style.text
	Theme.outlineText(b)
	b.Size = opts.size or UDim2.fromOffset(120, 36)
	if opts.position then
		b.Position = opts.position
	end
	Theme.corner(b, Theme.Radius.Small)
	local stroke = Theme.stroke(b, style.border, Theme.Stroke.Thin)
	b.Parent = parent

	local function refresh(state)
		local disabled = b:GetAttribute("Disabled") == true
		local fill, strokeColor, text = style.fill, style.border, style.text
		if disabled then
			fill, strokeColor, text = Theme.Color.Stone, Theme.Color.Border, Theme.Color.BoneDim
		elseif state == "hover" then
			fill = style.hover
			strokeColor = Theme.Color.BorderBright
		elseif state == "down" then
			fill = style.fill:Lerp(Theme.Color.Void, 0.3)
		end
		TweenService:Create(b, Theme.Tween, { BackgroundColor3 = fill, TextColor3 = text }):Play()
		TweenService:Create(stroke, Theme.Tween, { Color = strokeColor }):Play()
	end

	b:SetAttribute("Disabled", opts.disabled == true)
	b:GetAttributeChangedSignal("Disabled"):Connect(function()
		refresh("rest")
	end)
	b.MouseEnter:Connect(function() refresh("hover") end)
	b.MouseLeave:Connect(function() refresh("rest") end)
	b.MouseButton1Down:Connect(function() refresh("down") end)
	b.MouseButton1Up:Connect(function() refresh("hover") end)
	b.Activated:Connect(function()
		if b:GetAttribute("Disabled") ~= true and opts.onClick then
			opts.onClick()
		end
	end)
	refresh("rest")
	return b
end

-- ============================================================
-- Panel: a framed window with a title bar and a body
-- ============================================================
-- opts: title, size (UDim2), position (UDim2), anchor (Vector2), zIndex (number: the UI uses global z-ordering, so the
-- header and body are put just above the frame). Returns { frame, body, title, setTitle }.
function Theme.panel(parent, opts)
	opts = opts or {}
	local z = opts.zIndex or 1
	local frame = Instance.new("Frame")
	frame.ZIndex = z
	frame.BackgroundColor3 = Theme.Color.Stone
	frame.BorderSizePixel = 0
	frame.Size = opts.size or UDim2.fromOffset(420, 360)
	frame.AnchorPoint = opts.anchor or Vector2.new(0.5, 0.5)
	frame.Position = opts.position or UDim2.fromScale(0.5, 0.5)
	frame.Parent = parent
	local border = Instance.new("ImageLabel") -- the painted stone frame round the panel
	border.Name = "Border"
	border.BackgroundTransparency = 1
	border.Image = Theme.Image.PanelFrame
	border.ScaleType = Enum.ScaleType.Slice
	border.SliceCenter = PANEL_SLICE
	border.SliceScale = PANEL_SLICE_SCALE
	border.ImageTransparency = 0
	border.Size = UDim2.new(1, PANEL_FRAME_MARGIN * 2, 1, PANEL_FRAME_MARGIN * 2)
	border.Position = UDim2.fromOffset(-PANEL_FRAME_MARGIN, -PANEL_FRAME_MARGIN)
	border.ZIndex = z - 1 -- behind the panel: the skull corners and the inner bevel must never cover content near the edge
	border.Parent = frame

	local header = Instance.new("Frame")
	header.BackgroundColor3 = Theme.Color.Void
	header.BorderSizePixel = 0
	header.Size = UDim2.new(1, 0, 0, 40)
	header.ZIndex = z + 1
	header.Parent = frame
	local line = Instance.new("Frame") -- a thin soul-green rule under the title
	line.BackgroundColor3 = Theme.Color.Verdigris
	line.BorderSizePixel = 0
	line.Size = UDim2.new(1, 0, 0, 1)
	line.Position = UDim2.new(0, 0, 1, 0)
	line.ZIndex = z + 2
	line.Parent = header

	if not opts.position then
		local uiScale = Instance.new("UIScale")
		uiScale.Parent = frame
		local function fit()
			local screen = parent.AbsoluteSize
			if screen.Y <= 0 then
				return
			end
			local availH = screen.Y - PANEL_TOP_RESERVE - PANEL_BOTTOM_RESERVE
			local availW = screen.X - PANEL_SIDE_RESERVE * 2
			local needH = frame.Size.Y.Offset + PANEL_FRAME_MARGIN * 2
			local needW = frame.Size.X.Offset + PANEL_FRAME_MARGIN * 2
			uiScale.Scale = math.clamp(math.min(availH / needH, availW / needW), 0.4, 1)
			frame.Position = UDim2.new(0.5, 0, 0, PANEL_TOP_RESERVE + math.max(availH, 0) / 2)
		end
		parent:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
		frame:GetPropertyChangedSignal("Size"):Connect(fit)
		fit()
	end

	local title = Theme.label(header, { text = opts.title or "", size = "Heading", font = "Title", frameSize = UDim2.new(1, -24, 1, 0) })
	title.Position = UDim2.fromOffset(14, 0)
	title.ZIndex = z + 2

	local body = Instance.new("Frame")
	body.BackgroundTransparency = 1
	body.Size = UDim2.new(1, 0, 1, -42)
	body.Position = UDim2.fromOffset(0, 42)
	body.ZIndex = z + 1
	Theme.padding(body, 12)
	body.Parent = frame

	return {
		frame = frame,
		body = body,
		title = title,
		setTitle = function(text)
			title.Text = text
		end,
	}
end

-- ============================================================
-- Stone button (image based: cut corners, double bevel, diamond ornaments)
-- ============================================================
-- The four green states and a grey master that is tinted for the other colours were drawn by
-- tools/design/make_button_images.py (PNGs in design/buttons/) and uploaded. Each image is 512 x 160 with a 16 px margin
-- round the 480 x 128 button shape (room for the hover glow) and is sliced 9-patch style: the corner pieces (cut corner,
-- bevel, diamonds) stay fixed, the middle stretches. Keep SLICE in sync with the script.
-- Colours of the five upgrade dusts (keys from Economy.DUSTS)
Theme.DustColor = {
	Stone = Color3.fromRGB(150, 146, 140),
	Silver = Color3.fromRGB(196, 204, 216),
	Gold = Color3.fromRGB(232, 190, 90),
	Diamond = Color3.fromRGB(130, 220, 240),
	Star = Color3.fromRGB(226, 150, 255),
}

Theme.Image = {
	StoneButton = {
		Default = "rbxassetid://88492918328761",
		Hover = "rbxassetid://106431478235715",
		Pressed = "rbxassetid://122534593064384",
		Disabled = "rbxassetid://84718582421395",
		Neutral = "rbxassetid://127236828836350", -- grey master, tinted with ImageColor3
	},
	-- painted icons (sources in Images/UI, cropped to 512 px in design/icons, uploaded through the Studio MCP)
	Icon = {
		Ascend = "rbxassetid://76467986926265",
		Friends = "rbxassetid://122891510658917",
		Gems = "rbxassetid://94154571559100",
		Gold = "rbxassetid://103334898656401",
		Graves = "rbxassetid://132018737296754",
		Inventory = "rbxassetid://132970482585009",
		Quests = "rbxassetid://84837079908309",
		Wheel = "rbxassetid://89538272532162",
		Luck = "rbxassetid://138014044391245",
		GoldBoost = "rbxassetid://93908510121447",
		Shops = "rbxassetid://80608883367865",
		Wall = "rbxassetid://93200728049860",
	},
	-- one icon per upgrade dust (keys from Economy.DUSTS)
	Dust = {
		Stone = "rbxassetid://86679516329293",
		Silver = "rbxassetid://106328732077100",
		Gold = "rbxassetid://107926808773315",
		Diamond = "rbxassetid://115639264229256",
		Star = "rbxassetid://81552659651190",
	},
	-- the painted window frame (1024 x 1007: stone border about 84 px wide, bronze skull corners, transparent middle), 9-sliced
	PanelFrame = "rbxassetid://97150066839506",
}
local STONE_SLICE = Rect.new(80, 56, 432, 104)
local STONE_MARGIN, STONE_SHAPE_H = 16, 128

-- Colour variants of the stone button. "green" uses the dedicated state images; the others tint the grey master.
local STONE_TINTS = {
	red = Color3.fromRGB(214, 78, 78),
	gold = Color3.fromRGB(236, 190, 84),
	blue = Color3.fromRGB(96, 168, 236),
	purple = Color3.fromRGB(160, 100, 224),
	stone = Color3.fromRGB(124, 132, 136), -- neutral grey, for inactive choices (tabs, sort buttons)
}

-- opts: text, color ("green" default | "red" | "gold" | "blue" | "purple" | "stone"), size (UDim2 of the button SHAPE, offsets only,
-- default 150 x 44), position, anchor, zIndex, onClick, disabled, icon (image id: a big icon overlapping the left end, the
-- text moves right of it). Returns { root, button, label, icon }: place and size `root`;
-- root:SetAttribute("Disabled", true/false) disables or enables it.
function Theme.stoneButton(parent, opts)
	opts = opts or {}
	local size = opts.size or UDim2.fromOffset(150, 44)
	local w, h = size.X.Offset, size.Y.Offset
	local scale = h / STONE_SHAPE_H -- one image pixel is this many UI pixels
	local margin = STONE_MARGIN * scale
	local tint = STONE_TINTS[opts.color or ""]

	local root = Instance.new("Frame") -- exactly the button shape; the image hangs over its edge by the glow margin
	root.BackgroundTransparency = 1
	root.Size = size
	root.Position = opts.position or UDim2.new()
	root.AnchorPoint = opts.anchor or Vector2.new()
	root.ZIndex = opts.zIndex or 1
	root.Parent = parent

	local button = Instance.new("ImageButton")
	button.AutoButtonColor = false
	button.BackgroundTransparency = 1
	button.Size = UDim2.new(1, margin * 2, 1, margin * 2)
	button.Position = UDim2.fromOffset(-margin, -margin)
	button.ScaleType = Enum.ScaleType.Slice
	button.SliceCenter = STONE_SLICE
	button.SliceScale = scale
	button.ZIndex = opts.zIndex or 1
	button.Parent = root

	local textLeft = opts.icon and h * 1.05 or h * 0.55
	local icon
	if opts.icon then
		icon = Instance.new("ImageLabel")
		icon.Name = "Icon"
		icon.BackgroundTransparency = 1
		icon.Image = opts.icon
		icon.AnchorPoint = Vector2.new(0.5, 0.5)
		icon.Size = UDim2.fromOffset(h * 1.3, h * 1.3)
		icon.Position = UDim2.new(0, h * 0.5, 0.5, -2)
		icon.ZIndex = (opts.zIndex or 1) + 2
		icon.Parent = root
	end

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, -(textLeft + h * 0.55), 1, 0) -- keeps the text between the icon/left diamond and the right diamond
	label.Position = UDim2.new(0, textLeft, 0, 0)
	label.Font = Theme.Font.Strong
	label.Text = opts.text or ""
	label.TextScaled = false
	label.TextSize = math.floor(h * 0.52)
	label.TextWrapped = false
	label.ZIndex = (opts.zIndex or 1) + 1
	label.Parent = button

	local textColor = tint and Color3.fromRGB(255, 250, 240) or Color3.fromRGB(214, 255, 230)
	local textStroke = tint and tint:Lerp(Color3.new(0, 0, 0), 0.8) or Theme.TextStroke.Color

	local function show(state)
		local disabled = root:GetAttribute("Disabled") == true
		if disabled then
			state = "Disabled"
		end
		if tint then
			button.Image = Theme.Image.StoneButton.Neutral
			local c = tint
			if state == "Hover" then
				c = tint:Lerp(Color3.new(1, 1, 1), 0.25)
			elseif state == "Pressed" then
				c = tint:Lerp(Color3.new(0, 0, 0), 0.3)
			elseif state == "Disabled" then
				c = Color3.fromRGB(110, 118, 114)
			end
			button.ImageColor3 = c
		else
			button.Image = Theme.Image.StoneButton[state]
			button.ImageColor3 = Color3.new(1, 1, 1)
		end
		label.TextColor3 = (state == "Disabled") and Color3.fromRGB(140, 156, 148) or textColor
		label.TextStrokeColor3 = textStroke
		label.TextStrokeTransparency = (state == "Disabled") and 0.35 or 0
		local sink = (state == "Pressed") and math.max(1, h * 0.03) or 0
		label.Position = UDim2.new(0, textLeft, 0, sink)
		if icon then
			icon.Position = UDim2.new(0, h * 0.5, 0.5, sink - 2)
			icon.Size = UDim2.fromOffset(h * (state == "Hover" and 1.4 or 1.3), h * (state == "Hover" and 1.4 or 1.3))
		end
	end

	root:SetAttribute("Disabled", opts.disabled == true)
	root:GetAttributeChangedSignal("Disabled"):Connect(function()
		show("Default")
	end)
	button.MouseEnter:Connect(function() show("Hover") end)
	button.MouseLeave:Connect(function() show("Default") end)
	button.MouseButton1Down:Connect(function() show("Pressed") end)
	button.MouseButton1Up:Connect(function() show("Hover") end)
	button.Activated:Connect(function()
		if root:GetAttribute("Disabled") ~= true and opts.onClick then
			opts.onClick()
		end
	end)
	show("Default")
	return { root = root, button = button, label = label, icon = icon }
end

-- ============================================================
-- Icon tile: a square menu button (dark stone plate with a bronze rim, the painted icon filling it, a short outlined
-- label across the bottom edge). Used for the menu buttons on the sides of the screen; actions keep the stone buttons.
-- opts: icon (image id), text, size (pixels, default 68), position, anchor, zIndex, onClick.
-- Returns { root, button, label, icon }: badges can be parented to `root`.
-- ============================================================
local BRONZE_RIM = Color3.fromRGB(122, 92, 58)

function Theme.iconTile(parent, opts)
	opts = opts or {}
	local s = opts.size or 68
	local z = opts.zIndex or 1

	local root = Instance.new("Frame")
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromOffset(s, s)
	root.Position = opts.position or UDim2.new()
	root.AnchorPoint = opts.anchor or Vector2.new()
	root.ZIndex = z
	root.Parent = parent

	local button = Instance.new("TextButton")
	button.AutoButtonColor = false
	button.Text = ""
	button.Size = UDim2.fromScale(1, 1)
	button.BackgroundColor3 = Theme.Color.StoneRaised
	button.BackgroundTransparency = 0.12
	button.BorderSizePixel = 0
	button.ZIndex = z
	button.Parent = root
	Theme.corner(button, Theme.Radius.Large)
	local rim = Theme.stroke(button, BRONZE_RIM, 2)
	local shade = Instance.new("UIGradient")
	shade.Rotation = 90
	shade.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(150, 150, 160))
	shade.Parent = button

	local icon = Instance.new("ImageLabel")
	icon.Name = "Icon"
	icon.BackgroundTransparency = 1
	icon.Image = opts.icon or ""
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.ZIndex = z + 1
	icon.Parent = root

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Size = UDim2.new(1, 40, 0, 18)
	label.Font = Theme.Font.Strong
	label.Text = opts.text or ""
	label.TextSize = math.floor(s * 0.24)
	label.TextColor3 = Color3.fromRGB(255, 250, 240)
	label.ZIndex = z + 2
	Theme.outlineText(label)
	label.Parent = root

	local function show(state)
		local sink = (state == "Pressed") and 2 or 0
		local grow = (state == "Hover") and 0.98 or 0.88
		icon.Size = UDim2.fromOffset(s * grow, s * grow)
		icon.Position = UDim2.new(0.5, 0, 0.5, sink - 5)
		label.Position = UDim2.new(0.5, 0, 1, sink - 3)
		rim.Color = (state == "Default") and BRONZE_RIM or Theme.Color.Soul
		button.BackgroundColor3 = (state == "Default") and Theme.Color.StoneRaised or Theme.Color.StoneHover
	end
	button.MouseEnter:Connect(function() show("Hover") end)
	button.MouseLeave:Connect(function() show("Default") end)
	button.MouseButton1Down:Connect(function() show("Pressed") end)
	button.MouseButton1Up:Connect(function() show("Hover") end)
	button.Activated:Connect(function()
		if opts.onClick then opts.onClick() end
	end)
	show("Default")
	return { root = root, button = button, label = label, icon = icon }
end

return Theme
