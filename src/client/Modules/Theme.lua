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
Theme.Font = {
	Title = Enum.Font.Garamond, -- headings: engraved, gothic-leaning serif
	Body = Enum.Font.GothamMedium, -- numbers and body text stay highly readable
	Strong = Enum.Font.GothamBold, -- buttons and emphasis
}
Theme.TextSize = { Small = 13, Body = 16, Heading = 22, Title = 30 }

Theme.Radius = { Small = 4, Medium = 8, Large = 12 } -- squarer than a soft app look: carved stone, not bubbles
Theme.Stroke = { Thin = 1, Frame = 2 }
Theme.Tween = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

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
	b.TextSize = Theme.TextSize.Body
	b.TextColor3 = style.text
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
-- opts: title, size (UDim2), position (UDim2), anchor (Vector2). Returns { frame, body, title, setTitle }.
function Theme.panel(parent, opts)
	opts = opts or {}
	local frame = Instance.new("Frame")
	frame.BackgroundColor3 = Theme.Color.Stone
	frame.BorderSizePixel = 0
	frame.Size = opts.size or UDim2.fromOffset(420, 360)
	frame.AnchorPoint = opts.anchor or Vector2.new(0.5, 0.5)
	frame.Position = opts.position or UDim2.fromScale(0.5, 0.5)
	Theme.corner(frame, Theme.Radius.Medium)
	Theme.stroke(frame, Theme.Color.Border, Theme.Stroke.Frame)
	frame.Parent = parent

	local header = Instance.new("Frame")
	header.BackgroundColor3 = Theme.Color.Void
	header.BorderSizePixel = 0
	header.Size = UDim2.new(1, 0, 0, 40)
	Theme.corner(header, Theme.Radius.Medium)
	header.Parent = frame
	-- (square off the header's bottom corners)
	local fill = Instance.new("Frame")
	fill.BackgroundColor3 = Theme.Color.Void
	fill.BorderSizePixel = 0
	fill.Size = UDim2.new(1, 0, 0, 10)
	fill.Position = UDim2.new(0, 0, 1, -10)
	fill.Parent = header
	local line = Instance.new("Frame") -- a thin soul-green rule under the title
	line.BackgroundColor3 = Theme.Color.Verdigris
	line.BorderSizePixel = 0
	line.Size = UDim2.new(1, 0, 0, 1)
	line.Position = UDim2.new(0, 0, 1, 0)
	line.Parent = header

	local title = Theme.label(header, { text = opts.title or "", size = "Heading", font = "Title", frameSize = UDim2.new(1, -24, 1, 0) })
	title.Position = UDim2.fromOffset(14, 0)

	local body = Instance.new("Frame")
	body.BackgroundTransparency = 1
	body.Size = UDim2.new(1, 0, 1, -42)
	body.Position = UDim2.fromOffset(0, 42)
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

return Theme
