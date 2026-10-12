-- The Graves panel (the module keeps its old name "GravesDock" so Sync, ShopPanel and WheelPanel keep calling refresh()).
--
-- A small "Graves" stone button on the left side (under Inventory) shows how many graves you own in total, as a badge.
-- Clicking it (or pressing G) opens a stone panel with a card for EVERY grave type: picture, name, how many you own, its luck
-- and, for graves you cannot use yet, the ascension that unlocks them. Select a card, then "Open x1" or "Open xN"
-- (N = min(10, owned)). The panel closes when an opening starts so the reveal has the stage. Nothing sits in the middle of
-- the screen while you are not opening graves.
--
--   GravesDock.init(screenGui, ownedGraves, GRAVE_DATA, openGrave)   openGrave(graveType, count)
--   GravesDock.refresh()   -- call whenever ownedGraves changes
--   GravesDock.toggle() / GravesDock.isVisible()
-- "Open all" is planned as a paid feature: it would be a third button next to Open xN.
local UserInputService = game:GetService("UserInputService")

local Theme = require(script.Parent.Theme)
local State = require(script.Parent.State)

local C = Theme.Color
local Z = 35 -- base ZIndex of the panel (the UI uses global z-ordering)
local MAX_PULL = 10

local GravesDock = {}

local ownedGraves, GRAVE_DATA, openGraveFn
local panel, themed, cards, openOneBtn, openManyBtn, hintLbl, badge, badgeText, graveButton
local selected = nil -- the selected grave key
local built = false

local function owned(key)
	return ownedGraves[key] or 0
end

local function isLocked(gd)
	return (State.rebirthCount or 0) < gd.unlockAscension
end

local function totalOwned()
	local n = 0
	for _, gd in ipairs(GRAVE_DATA) do
		n += owned(gd.key)
	end
	return n
end

-- ── Select ───────────────────────────────────────────────────
local function paintCards()
	for _, gd in ipairs(GRAVE_DATA) do
		local card = cards[gd.key]
		local count = owned(gd.key)
		local locked = isLocked(gd)
		local isSel = (gd.key == selected)
		card.stroke.Color = isSel and C.Soul or C.Border
		card.stroke.Thickness = isSel and 3 or 1
		card.frame.BackgroundColor3 = isSel and C.StoneHover or C.StoneRaised
		card.count.Text = "x" .. count
		card.count.TextColor3 = (count > 0) and C.Bone or C.BoneDim
		card.lock.Visible = locked
		card.lock.Text = "Ascension " .. gd.unlockAscension
		-- unowned or locked graves are dimmed
		local dim = (count == 0 or locked) and 0.55 or 0
		card.image.ImageTransparency = dim
		card.name.TextTransparency = dim * 0.6
	end
end

function GravesDock.updateButtons()
	if not built then
		return
	end
	local count = selected and owned(selected) or 0
	local gd
	for _, g in ipairs(GRAVE_DATA) do
		if g.key == selected then
			gd = g
		end
	end
	local usable = gd and count > 0 and not isLocked(gd)
	local many = math.min(MAX_PULL, count)
	openOneBtn.root:SetAttribute("Disabled", not usable)
	openManyBtn.root:SetAttribute("Disabled", not (usable and many >= 2))
	openManyBtn.label.Text = (many >= 2) and ("Open x" .. many) or ("Open x" .. MAX_PULL)
	if not gd then
		hintLbl.Text = "Select a grave"
	elseif isLocked(gd) then
		hintLbl.Text = gd.name .. " unlocks at Ascension " .. gd.unlockAscension
	elseif count == 0 then
		hintLbl.Text = "You have no " .. gd.name .. " left. Buy more in the shop."
	else
		hintLbl.Text = gd.name .. "   Best: " .. gd.bestRarity .. " " .. string.format("%.2f", gd.bestPercent) .. "%"
	end
end

local function selectGrave(key)
	selected = key
	paintCards()
	GravesDock.updateButtons()
end

local function openSelected(count)
	if not selected then
		return
	end
	panel.Visible = false -- the reveal takes the stage
	openGraveFn(selected, count)
end

-- ── Build ────────────────────────────────────────────────────
local function build(screenGui)
	themed = Theme.panel(screenGui, { title = "Graves", size = UDim2.fromOffset(700, 470), zIndex = Z })
	panel = themed.frame
	panel.Name = "GravesPanel"
	panel.Visible = false
	local body = themed.body

	Theme.stoneButton(panel, {
		text = "X", color = "red", size = UDim2.fromOffset(44, 28),
		position = UDim2.new(1, -62, 0, 6), zIndex = Z + 2,
		onClick = function() panel.Visible = false end,
	})

	-- the grid of grave cards
	local grid = Instance.new("ScrollingFrame")
	grid.BackgroundTransparency = 1
	grid.BorderSizePixel = 0
	grid.Size = UDim2.new(1, 0, 1, -92)
	grid.ScrollBarThickness = 6
	grid.ScrollBarImageColor3 = C.Verdigris
	grid.CanvasSize = UDim2.new()
	grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
	grid.ZIndex = Z + 2
	grid.Parent = body
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.fromOffset(120, 150)
	layout.CellPadding = UDim2.fromOffset(8, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Parent = grid

	cards = {}
	for i, gd in ipairs(GRAVE_DATA) do
		local frame = Instance.new("Frame")
		frame.LayoutOrder = i
		frame.BackgroundColor3 = C.StoneRaised
		frame.BorderSizePixel = 0
		frame.ZIndex = Z + 3
		Theme.corner(frame, Theme.Radius.Small)
		local stroke = Theme.stroke(frame, C.Border, 1)
		frame.Parent = grid

		local image = Instance.new("ImageLabel")
		image.BackgroundTransparency = 1
		image.Image = gd.image or ""
		image.ScaleType = Enum.ScaleType.Fit
		image.Size = UDim2.new(1, -16, 0, 72)
		image.Position = UDim2.fromOffset(8, 8)
		image.ZIndex = Z + 4
		image.Parent = frame

		local nameLbl = Theme.label(frame, { text = gd.name, size = "Small", font = "Strong", color = C.Bone, align = Enum.TextXAlignment.Center, frameSize = UDim2.new(1, -8, 0, 32) })
		nameLbl.Position = UDim2.fromOffset(4, 84)
		nameLbl.TextWrapped = true
		nameLbl.ZIndex = Z + 4

		local countLbl = Theme.label(frame, { text = "x0", size = "Heading", font = "Strong", color = C.Bone, align = Enum.TextXAlignment.Center, frameSize = UDim2.new(1, 0, 0, 26) })
		countLbl.Position = UDim2.new(0, 0, 1, -32)
		countLbl.ZIndex = Z + 4
		Theme.outlineText(countLbl)

		local lockLbl = Theme.label(frame, { text = "", size = "Small", font = "Strong", color = C.Warn, align = Enum.TextXAlignment.Center, frameSize = UDim2.new(1, 0, 0, 16) })
		lockLbl.Position = UDim2.new(0, 0, 0, 64)
		lockLbl.ZIndex = Z + 5
		lockLbl.BackgroundColor3 = C.Void
		lockLbl.BackgroundTransparency = 0.25
		lockLbl.Visible = false

		local btn = Instance.new("TextButton")
		btn.BackgroundTransparency = 1
		btn.Text = ""
		btn.Size = UDim2.fromScale(1, 1)
		btn.ZIndex = Z + 6
		btn.Parent = frame
		local key = gd.key
		btn.Activated:Connect(function()
			selectGrave(key)
		end)

		cards[gd.key] = { frame = frame, stroke = stroke, image = image, name = nameLbl, count = countLbl, lock = lockLbl }
	end

	-- the bar under the grid: what is selected, and the open buttons
	local bar = Instance.new("Frame")
	bar.BackgroundColor3 = C.Void
	bar.BorderSizePixel = 0
	bar.AnchorPoint = Vector2.new(0, 1)
	bar.Position = UDim2.fromScale(0, 1)
	bar.Size = UDim2.new(1, 0, 0, 80)
	bar.ZIndex = Z + 2
	Theme.corner(bar, Theme.Radius.Small)
	Theme.stroke(bar, C.Border, 1)
	bar.Parent = body

	hintLbl = Theme.label(bar, { text = "", size = "Body", font = "Body", color = C.BoneDim, frameSize = UDim2.new(0.42, 0, 1, 0) })
	hintLbl.Position = UDim2.fromOffset(14, 0)
	hintLbl.TextWrapped = true
	hintLbl.ZIndex = Z + 3

	openOneBtn = Theme.stoneButton(bar, {
		text = "Open x1", size = UDim2.fromOffset(150, 46),
		position = UDim2.new(1, -332, 0.5, -23), zIndex = Z + 3,
		onClick = function() openSelected(1) end,
	})
	openManyBtn = Theme.stoneButton(bar, {
		text = "Open x" .. MAX_PULL, color = "gold", size = UDim2.fromOffset(150, 46),
		position = UDim2.new(1, -168, 0.5, -23), zIndex = Z + 3,
		onClick = function()
			openSelected(math.min(MAX_PULL, selected and owned(selected) or 0))
		end,
	})
	built = true
end

-- ── Public API ───────────────────────────────────────────────
function GravesDock.init(screenGui, ownedGravesRef, graveData, openGrave)
	ownedGraves = ownedGravesRef
	GRAVE_DATA = graveData
	openGraveFn = openGrave
	build(screenGui)

	-- the small side button with a badge showing how many graves you own
	-- (the left HUD column starts at 0.5, -150 with Ascend and Inventory, 62 studs apart: this one comes third)
	graveButton = Theme.stoneButton(screenGui, {
		text = "Graves", color = "gold", size = UDim2.fromOffset(112, 44),
		position = UDim2.new(0, 10, 0.5, -26), zIndex = 5,
		onClick = function() GravesDock.toggle() end,
	})
	badge = Instance.new("Frame")
	badge.AnchorPoint = Vector2.new(1, 0)
	badge.Position = UDim2.new(1, 8, 0, -8)
	badge.Size = UDim2.fromOffset(40, 22)
	badge.BackgroundColor3 = C.Blood
	badge.BorderSizePixel = 0
	badge.ZIndex = 9
	Theme.corner(badge, 11)
	Theme.stroke(badge, C.Void, 2)
	badge.Parent = graveButton.root
	badgeText = Theme.label(badge, { text = "0", size = "Small", font = "Strong", color = C.Bone, align = Enum.TextXAlignment.Center, frameSize = UDim2.fromScale(1, 1) })
	badgeText.ZIndex = 10

	-- G toggles the panel
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.G then
			GravesDock.toggle()
		end
	end)
end

function GravesDock.refresh()
	if not built then
		return
	end
	-- keep the selection on a grave you own (the first owned one when the selected one runs out)
	if not selected or owned(selected) == 0 then
		selected = nil
		for _, gd in ipairs(GRAVE_DATA) do
			if owned(gd.key) > 0 and not isLocked(gd) then
				selected = gd.key
				break
			end
		end
	end
	paintCards()
	GravesDock.updateButtons()
	local total = totalOwned()
	badgeText.Text = total > 999 and "999+" or tostring(total)
	badge.Visible = total > 0
	themed.setTitle("Graves  (" .. total .. ")")
end

function GravesDock.toggle()
	panel.Visible = not panel.Visible
	if panel.Visible then
		GravesDock.refresh()
	end
end

function GravesDock.isVisible()
	return panel ~= nil and panel.Visible
end

return GravesDock
