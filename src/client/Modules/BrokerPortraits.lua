-- The Soul Broker's portraits, painted for THIS player (Design.md "The Soul Broker", step 3a): every canvas of the stall
-- (HubDecor.Stall_SoulBroker, parts named "Canvas" with the attribute Portrait = 1..4) gets a SurfaceGui with the deal
-- this player is offered this hour (shared BrokerDeals): the featured unit turning in 3D in its idle (UnitPortrait), the
-- other deals as their painted icons swaying in a soft glow; the deal's name and the stock left along the bottom, a gem
-- price badge top right, a red "-20%" ribbon top left when the deal is cheaper than its worth (BrokerDeals.discount),
-- and a SOLD OUT stamp once this player's stock is used (State.broker from DataSync). Repaints on DataSync, when the hour
-- turns and when the stall streams in. The SurfaceGuis live in PlayerGui (Adornee = the canvas) so they can take clicks
-- later (step 3b: the in-world view).
-- Builds itself when required (no init call).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Theme = require(script.Parent.Theme)
local State = require(script.Parent.State)
local Sync = require(script.Parent.Sync)
local UnitPortrait = require(script.Parent.UnitPortrait)
local BrokerDeals = require(ReplicatedStorage.Shared.BrokerDeals)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local BrokerPortraits = {}

local GOLD = Color3.fromRGB(232, 196, 120)
local INK = Color3.fromRGB(20, 10, 24)
local GLOW = { -- the soft glow behind the art, by kind of deal
	unit = Color3.fromRGB(110, 210, 255),
	potion = Color3.fromRGB(90, 230, 140),
	catalyst = Color3.fromRGB(190, 120, 255),
	dust = Color3.fromRGB(240, 200, 120),
}

local function kindOf(o)
	if o.unitType then return "unit" end
	if o.potions and not o.catalyst then return "potion" end
	if o.catalyst then return "catalyst" end
	return "dust"
end

local function iconOf(o)
	if o.dust and not o.catalyst and not o.potions then
		return Theme.Image.Dust[o.dust] or ""
	end
	return Theme.Image.Icon.Luck or "" -- (catalysts and potions share the luck art until they get their own icons)
end

local function corner(parent, scale)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(scale, 0)
	c.Parent = parent
end
local function stroke(parent, color, thickness)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness
	s.Parent = parent
	return s
end
local function text(parent, props)
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Font = Theme.Font.Strong
	t.TextScaled = true
	t.TextColor3 = props.color or GOLD
	t.AnchorPoint = props.anchor or Vector2.zero
	t.Position = props.position
	t.Size = props.size
	t.ZIndex = props.zIndex or 4
	t.Parent = parent
	stroke(t, INK, props.strokeWidth or 2)
	return t
end

-- ============================================================
-- One painted portrait (a SurfaceGui on the canvas)
-- ============================================================
local slots = {} -- [portrait] = { canvas, gui, halo, haloGrad, art, portrait, name, stock, badge, price, ribbon, ribbonText, soldOut }

local function build(index, canvas)
	local s = { canvas = canvas }
	local g = Instance.new("SurfaceGui")
	g.Name = "BrokerPortrait" .. index
	g.Adornee = canvas
	g.Face = Enum.NormalId.Left -- the canvas faces -X of the stall frame, toward the customer
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = 60
	g.LightInfluence = 0.15
	g.Brightness = 1.2
	g.ResetOnSpawn = false
	g.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	g.Parent = playerGui
	s.gui = g

	-- a dark painted ground with a coloured glow in the middle
	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = Color3.fromRGB(18, 14, 26)
	bg.BorderSizePixel = 0
	bg.ClipsDescendants = true
	bg.Parent = g
	local grad = Instance.new("UIGradient")
	grad.Color = ColorSequence.new(Color3.fromRGB(40, 30, 58), Color3.fromRGB(10, 8, 16))
	grad.Rotation = 90
	grad.Parent = bg
	local halo = Instance.new("Frame")
	halo.AnchorPoint = Vector2.new(0.5, 0.5)
	halo.Position = UDim2.fromScale(0.5, 0.45)
	halo.Size = UDim2.fromScale(0.95, 0.72)
	halo.BorderSizePixel = 0
	halo.ZIndex = 2
	halo.Parent = bg
	corner(halo, 0.5)
	local hg = Instance.new("UIGradient")
	hg.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(0.5, 0.8), NumberSequenceKeypoint.new(1, 1),
	})
	hg.Parent = halo
	s.halo, s.haloGrad = halo, hg

	-- the art: an icon (swaying) or the unit in 3D
	s.art = Instance.new("ImageLabel")
	s.art.BackgroundTransparency = 1
	s.art.AnchorPoint = Vector2.new(0.5, 0.5)
	s.art.Position = UDim2.fromScale(0.5, 0.45)
	s.art.Size = UDim2.fromScale(0.7, 0.55)
	s.art.ScaleType = Enum.ScaleType.Fit
	s.art.ZIndex = 3
	s.art.Parent = bg
	s.portrait = UnitPortrait.attach(bg, {
		position = UDim2.fromScale(0.04, 0.08), size = UDim2.fromScale(0.92, 0.7), zIndex = 3, animate = true,
	})

	-- the name and the stock left along the bottom
	s.name = text(bg, { anchor = Vector2.new(0.5, 1), position = UDim2.fromScale(0.5, 0.91), size = UDim2.fromScale(0.92, 0.12) })
	s.stock = text(bg, {
		anchor = Vector2.new(0.5, 1), position = UDim2.fromScale(0.5, 0.985), size = UDim2.fromScale(0.6, 0.065),
		color = Color3.fromRGB(205, 195, 215), strokeWidth = 1.5,
	})

	-- the gem price badge, top right: a dark pill with the gem icon and the price
	local badge = Instance.new("Frame")
	badge.AnchorPoint = Vector2.new(1, 0)
	badge.Position = UDim2.fromScale(0.97, 0.025)
	badge.Size = UDim2.fromScale(0.46, 0.13)
	badge.BackgroundColor3 = Color3.fromRGB(22, 16, 34)
	badge.BackgroundTransparency = 0.1
	badge.ZIndex = 5
	badge.Parent = bg
	corner(badge, 0.5)
	stroke(badge, GOLD, 2)
	local gem = Instance.new("ImageLabel")
	gem.BackgroundTransparency = 1
	gem.Image = Theme.Image.Icon.Gems or ""
	gem.ScaleType = Enum.ScaleType.Fit
	gem.Position = UDim2.fromScale(0.03, 0.05)
	gem.Size = UDim2.fromScale(0.34, 0.9)
	gem.ZIndex = 6
	gem.Parent = badge
	s.price = text(badge, { position = UDim2.fromScale(0.36, 0.12), size = UDim2.fromScale(0.58, 0.76), color = Color3.fromRGB(255, 255, 255), zIndex = 6 })
	s.badge = badge

	-- the sale ribbon, top left: a red band across the corner
	local ribbon = Instance.new("Frame")
	ribbon.AnchorPoint = Vector2.new(0.5, 0.5)
	ribbon.Position = UDim2.fromScale(0.15, 0.11)
	ribbon.Size = UDim2.fromScale(0.8, 0.13)
	ribbon.Rotation = -38
	ribbon.BackgroundColor3 = Color3.fromRGB(196, 40, 52)
	ribbon.BorderSizePixel = 0
	ribbon.ZIndex = 5
	ribbon.Parent = bg
	stroke(ribbon, Color3.fromRGB(255, 210, 150), 1.5)
	s.ribbonText = text(ribbon, { position = UDim2.fromScale(0.22, 0.04), size = UDim2.fromScale(0.56, 0.92), color = Color3.fromRGB(255, 255, 255), zIndex = 6, strokeWidth = 1.5 })
	s.ribbon = ribbon

	-- the SOLD OUT stamp
	local stamp = Instance.new("Frame")
	stamp.AnchorPoint = Vector2.new(0.5, 0.5)
	stamp.Position = UDim2.fromScale(0.5, 0.45)
	stamp.Size = UDim2.fromScale(1.1, 0.16)
	stamp.Rotation = -18
	stamp.BackgroundColor3 = Color3.fromRGB(30, 10, 14)
	stamp.BackgroundTransparency = 0.15
	stamp.BorderSizePixel = 0
	stamp.ZIndex = 7
	stamp.Visible = false
	stamp.Parent = bg
	stroke(stamp, Color3.fromRGB(196, 40, 52), 3)
	text(stamp, { position = UDim2.fromScale(0.15, 0.1), size = UDim2.fromScale(0.7, 0.8), color = Color3.fromRGB(230, 70, 80), zIndex = 8 }).Text = "SOLD OUT"
	s.soldOut = stamp

	slots[index] = s
	return s
end

-- ============================================================
-- Painting
-- ============================================================
local function paint()
	local rot = BrokerDeals.rotation(workspace:GetServerTimeNow())
	local bought = (State.broker and State.broker.rot == rot) and State.broker.bought or {}
	for index, s in pairs(slots) do
		if s.canvas.Parent then
			local o = BrokerDeals.offer(rot, index, State.rebirthCount or 0)
			local kind = kindOf(o)
			local left = o.stock - (bought[index] or 0)
			local color = kind == "unit" and Theme.rarityColor(o.rarity) or GOLD
			s.halo.BackgroundColor3 = kind == "unit" and color or GLOW[kind]
			if o.unitType then
				s.art.Visible = false
				s.portrait.set(o.unitType)
			else
				s.portrait.set(nil)
				s.art.Image = iconOf(o)
				s.art.Visible = true
			end
			s.name.Text = string.upper(o.name)
			s.name.TextColor3 = color
			s.stock.Text = left > 0 and (left .. " of " .. o.stock .. " left") or ""
			s.price.Text = tostring(o.price)
			local off = BrokerDeals.discount(o)
			s.ribbon.Visible = off ~= nil and left > 0
			s.ribbonText.Text = off and ("-" .. off .. "%") or ""
			s.soldOut.Visible = left <= 0
			s.badge.Visible = left > 0
		end
	end
end

-- the icons sway and breathe a little, the glow drifts (four labels: cheap enough to run always)
RunService.RenderStepped:Connect(function()
	local t = os.clock()
	for index, s in pairs(slots) do
		if s.art.Visible then
			s.art.Rotation = math.sin(t * 0.8 + index) * 6
			local k = 1 + math.sin(t * 1.3 + index * 2) * 0.04
			s.art.Size = UDim2.fromScale(0.7 * k, 0.55 * k)
		end
		s.haloGrad.Offset = Vector2.new(0, math.sin(t * 0.9 + index) * 0.04)
	end
end)

-- ============================================================
-- Find the stall's canvases (the stall streams in; it may be rebuilt)
-- ============================================================
local function scan()
	local decor = workspace:FindFirstChild("HubDecor")
	local stall = decor and decor:FindFirstChild("Stall_SoulBroker")
	if not stall then return end
	for _, frame in ipairs(stall:GetChildren()) do
		local index = frame:IsA("Model") and tonumber(frame.Name:match("^Portrait(%d)$"))
		local canvas = index and frame:FindFirstChild("Canvas")
		if canvas and not (slots[index] and slots[index].canvas == canvas) then
			if slots[index] then
				slots[index].gui:Destroy()
			end
			build(index, canvas)
		end
	end
	paint()
end

task.spawn(function()
	local decor = workspace:WaitForChild("HubDecor", 60)
	if not decor then return end
	scan()
	decor.DescendantAdded:Connect(function(d)
		if d.Name == "Canvas" then
			task.defer(scan)
		end
	end)
end)

Sync.onApplied(paint)

-- repaint when the hour turns
local lastRot = -1
task.spawn(function()
	while true do
		local rot = BrokerDeals.rotation(workspace:GetServerTimeNow())
		if rot ~= lastRot then
			lastRot = rot
			paint()
		end
		task.wait(1)
	end
end)

BrokerPortraits.paint = paint
return BrokerPortraits
