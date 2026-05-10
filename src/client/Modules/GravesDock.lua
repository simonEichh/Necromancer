-- GravesDock: SaB-style grave selector (main slot + arrow + side panel)
-- Usage:
--   local GravesDock = require(script.Parent.Modules.GravesDock)
--   GravesDock.init(screenGui, ownedGraves, GRAVE_DATA, openGrave)
--   GravesDock.refresh()  -- call whenever ownedGraves changes

local GravesDock = {}

-- ── Private state ────────────────────────────────────────────
local selectedGraveType = nil
local gravesExpanded    = false
local pendingButtons    = {}   -- other-grave buttons, rebuilt on refresh

-- ── UI refs (created in init) ────────────────────────────────
local dock, mainSlot, mainSlotImg, mainSlotEmoji
local mainSlotCount, mainSlotName, arrowBtn, otherGravesPanel

-- ── Injected deps ────────────────────────────────────────────
local ownedGraves, GRAVE_DATA, GRAVE_INFO, openGraveFn

-- ── Forward declare ──────────────────────────────────────────
local refresh

-- ── init: build UI and wire events ──────────────────────────
function GravesDock.init(screenGui, ownedGravesRef, graveData, openGrave)
	ownedGraves  = ownedGravesRef
	GRAVE_DATA   = graveData
	openGraveFn  = openGrave

	-- Build GRAVE_INFO lookup from GRAVE_DATA
	GRAVE_INFO = {}
	for _, g in ipairs(GRAVE_DATA) do
		GRAVE_INFO[g.key] = { emoji = g.emoji, color = g.color, image = g.image, name = g.name }
	end

	-- ── Container ────────────────────────────────────────────
	dock = Instance.new("Frame")
	dock.Size = UDim2.new(1, 0, 0, 130)
	dock.Position = UDim2.new(0, 0, 1, -230)
	dock.BackgroundTransparency = 1
	dock.ClipsDescendants = false
	dock.Visible = false
	dock.Parent = screenGui

	-- ── Main slot ────────────────────────────────────────────
	mainSlot = Instance.new("Frame")
	mainSlot.AnchorPoint = Vector2.new(0.5, 0)
	mainSlot.Size = UDim2.new(0, 95, 0, 95)
	mainSlot.Position = UDim2.new(0.5, 0, 0, 2)
	mainSlot.BackgroundColor3 = Color3.fromRGB(25, 15, 45)
	mainSlot.BackgroundTransparency = 0.2
	mainSlot.BorderSizePixel = 0
	mainSlot.ZIndex = 4
	mainSlot.Parent = dock
	Instance.new("UICorner", mainSlot).CornerRadius = UDim.new(0, 14)

	do -- btn is not needed outside this block
		local btn = Instance.new("ImageButton", mainSlot)
		btn.Size = UDim2.new(1, 0, 1, 0)
		btn.BackgroundTransparency = 1
		btn.ZIndex = 5

		mainSlotImg = Instance.new("ImageLabel", btn)
		mainSlotImg.Size = UDim2.new(1, -10, 1, -10)
		mainSlotImg.Position = UDim2.new(0, 5, 0, 5)
		mainSlotImg.BackgroundTransparency = 1
		mainSlotImg.ScaleType = Enum.ScaleType.Fit
		mainSlotImg.ZIndex = 6

		mainSlotEmoji = Instance.new("TextLabel", btn)
		mainSlotEmoji.Size = UDim2.new(1, 0, 0.72, 0)
		mainSlotEmoji.Position = UDim2.new(0, 0, 0.10, 0)
		mainSlotEmoji.BackgroundTransparency = 1
		mainSlotEmoji.TextScaled = true
		mainSlotEmoji.ZIndex = 7
		mainSlotEmoji.Visible = false

		btn.MouseButton1Click:Connect(function()
			if selectedGraveType then
				openGraveFn(selectedGraveType)
			end
		end)
	end

	-- ── Count badge ──────────────────────────────────────────
	mainSlotCount = Instance.new("TextLabel", mainSlot)
	mainSlotCount.AnchorPoint = Vector2.new(1, 0)
	mainSlotCount.Size = UDim2.new(0, 38, 0, 24)
	mainSlotCount.Position = UDim2.new(1, 6, 0, -8)
	mainSlotCount.BackgroundColor3 = Color3.fromRGB(15, 10, 30)
	mainSlotCount.BackgroundTransparency = 0.15
	mainSlotCount.Text = "x1"
	mainSlotCount.TextColor3 = Color3.fromRGB(255, 255, 255)
	mainSlotCount.TextScaled = true
	mainSlotCount.Font = Enum.Font.GothamBold
	mainSlotCount.ZIndex = 8
	Instance.new("UICorner", mainSlotCount).CornerRadius = UDim.new(0, 6)

	-- ── Name label ───────────────────────────────────────────
	mainSlotName = Instance.new("TextLabel", dock)
	mainSlotName.AnchorPoint = Vector2.new(0.5, 0)
	mainSlotName.Size = UDim2.new(0, 120, 0, 22)
	mainSlotName.Position = UDim2.new(0.5, 0, 0, 99)
	mainSlotName.BackgroundTransparency = 1
	mainSlotName.TextColor3 = Color3.fromRGB(210, 195, 235)
	mainSlotName.TextScaled = true
	mainSlotName.Font = Enum.Font.GothamBold
	mainSlotName.ZIndex = 5

	-- ── Arrow button ─────────────────────────────────────────
	arrowBtn = Instance.new("TextButton")
	arrowBtn.AnchorPoint = Vector2.new(1, 0)
	arrowBtn.Size = UDim2.new(0, 26, 0, 70)
	arrowBtn.Position = UDim2.new(0.5, -56, 0, 14)
	arrowBtn.BackgroundColor3 = Color3.fromRGB(40, 28, 70)
	arrowBtn.BackgroundTransparency = 0.25
	arrowBtn.BorderSizePixel = 0
	arrowBtn.Text = "◀"
	arrowBtn.TextColor3 = Color3.fromRGB(200, 185, 240)
	arrowBtn.TextScaled = true
	arrowBtn.Font = Enum.Font.GothamBold
	arrowBtn.ZIndex = 5
	arrowBtn.Parent = dock
	Instance.new("UICorner", arrowBtn).CornerRadius = UDim.new(0, 6)

	arrowBtn.MouseButton1Click:Connect(function()
		gravesExpanded = not gravesExpanded
		otherGravesPanel.Visible = gravesExpanded
		arrowBtn.Text = gravesExpanded and "▶" or "◀"
	end)

	-- ── Other graves panel ───────────────────────────────────
	otherGravesPanel = Instance.new("Frame")
	otherGravesPanel.AnchorPoint = Vector2.new(1, 0)
	otherGravesPanel.Size = UDim2.new(0, 0, 0, 88)
	otherGravesPanel.Position = UDim2.new(0.5, -86, 0, 10)
	otherGravesPanel.BackgroundColor3 = Color3.fromRGB(12, 6, 26)
	otherGravesPanel.BackgroundTransparency = 0.25
	otherGravesPanel.BorderSizePixel = 0
	otherGravesPanel.ClipsDescendants = true
	otherGravesPanel.Visible = false
	otherGravesPanel.ZIndex = 4
	otherGravesPanel.Parent = dock
	Instance.new("UICorner", otherGravesPanel).CornerRadius = UDim.new(0, 10)

	do
		local layout = Instance.new("UIListLayout", otherGravesPanel)
		layout.FillDirection = Enum.FillDirection.Horizontal
		layout.Padding = UDim.new(0, 6)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.VerticalAlignment = Enum.VerticalAlignment.Center
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
		local pad = Instance.new("UIPadding", otherGravesPanel)
		pad.PaddingLeft = UDim.new(0, 6)
		pad.PaddingRight = UDim.new(0, 6)
	end
end

-- ── refresh: rebuild UI from current ownedGraves ─────────────
refresh = function()
	-- Clean up old other-grave buttons
	for _, b in pairs(pendingButtons) do b:Destroy() end
	pendingButtons = {}

	-- Check if any graves are owned
	local hasAny = false
	for _, gd in ipairs(GRAVE_DATA) do
		if (ownedGraves[gd.key] or 0) > 0 then
			hasAny = true
			break
		end
	end

	-- Auto-select first available if current is gone
	if selectedGraveType == nil or (ownedGraves[selectedGraveType] or 0) == 0 then
		selectedGraveType = nil
		for _, gd in ipairs(GRAVE_DATA) do
			if (ownedGraves[gd.key] or 0) > 0 then
				selectedGraveType = gd.key
				break
			end
		end
	end

	dock.Visible = hasAny
	if not selectedGraveType then return end

	-- Update main slot
	local info = GRAVE_INFO[selectedGraveType]
	mainSlot.BackgroundColor3 = info.color
	mainSlotCount.Text = "x" .. (ownedGraves[selectedGraveType] or 0)
	mainSlotName.Text = info.name

	if info.image and info.image ~= "" then
		mainSlotImg.Image = info.image
		mainSlotImg.Visible = true
		mainSlotEmoji.Visible = false
	else
		mainSlotImg.Image = ""
		mainSlotImg.Visible = false
		mainSlotEmoji.Text = info.emoji
		mainSlotEmoji.Visible = true
	end

	-- Build other graves list
	local otherOrder, itemCount = 0, 0
	for _, gd in ipairs(GRAVE_DATA) do
		local graveType = gd.key
		local cnt = ownedGraves[graveType] or 0
		if cnt > 0 and graveType ~= selectedGraveType then
			otherOrder += 1
			itemCount += 1
			local oInfo = GRAVE_INFO[graveType]

			local btn = Instance.new("TextButton", otherGravesPanel)
			btn.Size = UDim2.new(0, 64, 0, 76)
			btn.BackgroundColor3 = oInfo.color
			btn.Text = ""
			btn.BorderSizePixel = 0
			btn.LayoutOrder = otherOrder
			btn.ZIndex = 5
			Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 10)

			if oInfo.image and oInfo.image ~= "" then
				local img = Instance.new("ImageLabel", btn)
				img.Size = UDim2.new(1, -8, 0, 46)
				img.Position = UDim2.new(0, 4, 0, 4)
				img.BackgroundTransparency = 1
				img.Image = oInfo.image
				img.ScaleType = Enum.ScaleType.Fit
				img.ZIndex = 6
			else
				local eLbl = Instance.new("TextLabel", btn)
				eLbl.Size = UDim2.new(1, 0, 0, 46)
				eLbl.Position = UDim2.new(0, 0, 0, 4)
				eLbl.BackgroundTransparency = 1
				eLbl.Text = oInfo.emoji
				eLbl.TextScaled = true
				eLbl.ZIndex = 6
			end

			-- Count badge
			local cLbl = Instance.new("TextLabel", btn)
			cLbl.AnchorPoint = Vector2.new(1, 0)
			cLbl.Size = UDim2.new(0, 30, 0, 20)
			cLbl.Position = UDim2.new(1, 4, 0, -4)
			cLbl.BackgroundColor3 = Color3.fromRGB(15, 10, 30)
			cLbl.BackgroundTransparency = 0.2
			cLbl.Text = "x" .. cnt
			cLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
			cLbl.TextScaled = true
			cLbl.Font = Enum.Font.GothamBold
			cLbl.ZIndex = 7
			Instance.new("UICorner", cLbl).CornerRadius = UDim.new(0, 4)

			-- Name label
			local nLbl = Instance.new("TextLabel", btn)
			nLbl.Size = UDim2.new(1, 0, 0, 22)
			nLbl.Position = UDim2.new(0, 0, 0, 52)
			nLbl.BackgroundTransparency = 1
			nLbl.Text = oInfo.name
			nLbl.TextColor3 = Color3.fromRGB(230, 220, 255)
			nLbl.TextScaled = true
			nLbl.Font = Enum.Font.Gotham
			nLbl.ZIndex = 6

			local gt = graveType
			btn.MouseButton1Click:Connect(function()
				selectedGraveType = gt
				gravesExpanded = false
				otherGravesPanel.Visible = false
				arrowBtn.Text = "◀"
				refresh()
			end)
			table.insert(pendingButtons, btn)
		end
	end

	otherGravesPanel.Size = UDim2.new(0, itemCount * 70 + 12, 0, 88)
	arrowBtn.Visible = itemCount > 0
end

GravesDock.refresh = refresh

return GravesDock
