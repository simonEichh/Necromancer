local ShopPanel = {}

local RunService        = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- ── Private state ────────────────────────────────────────────
local panel
local shopStock      = {}
local shopInRotation = {}
local shopRestockSecs = 0
local restockLabel
local activeTab   = "Graveyard"
local tabButtons  = {}
local tabContents = {}
local graveButtons      = {}
local graveBuyMaxBtns   = {}
local graveLocks        = {}
local graveOwnedLbls    = {}
local graveStockLbls    = {}
local graveRotOverlays  = {}
local graveDataByKey    = {}

-- ── Injected deps ────────────────────────────────────────────
local GRAVE_DATA, ownedGraves
local getGold, spendGold, getRebirthCount, fmtGold, refreshDock

-- ── Forward declares ─────────────────────────────────────────
local updateGraveyard, switchTab

-- ── Helpers ──────────────────────────────────────────────────
function ShopPanel.isGraveLocked(graveType)
	local gd = graveDataByKey[graveType]
	return gd and getRebirthCount() < gd.unlockAscension
end

switchTab = function(name)
	activeTab = name
	for tabName, btn in pairs(tabButtons) do
		local on = (tabName == name)
		btn.BackgroundColor3 = on and Color3.fromRGB(90, 40, 170) or Color3.fromRGB(40, 18, 75)
		btn.TextColor3 = on and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(180, 150, 220)
		tabContents[tabName].Visible = on
	end
end

updateGraveyard = function()
	for _, gd in ipairs(GRAVE_DATA) do
		local locked    = ShopPanel.isGraveLocked(gd.key)
		local inRot     = shopInRotation[gd.key] == true
		local stock     = shopStock[gd.key] or 0
		local canBuy    = not locked and inRot and stock > 0
		local gold      = getGold()
		local canAfford = canBuy and gold >= gd.cost
		local qty       = canBuy and math.min(math.floor(gold / gd.cost), stock) or 0

		local btn = graveButtons[gd.key]
		if btn then
			btn.BackgroundColor3 = canAfford and Color3.fromRGB(80, 40, 150) or Color3.fromRGB(40, 20, 70)
			btn.TextColor3 = canAfford and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(120, 90, 150)
		end

		local maxBtn = graveBuyMaxBtns[gd.key]
		if maxBtn then
			if qty > 1 then
				maxBtn.Text = "Buy x" .. qty .. "\n💰 " .. fmtGold(gd.cost * qty)
				maxBtn.BackgroundColor3 = Color3.fromRGB(40, 110, 40)
				maxBtn.TextColor3 = Color3.fromRGB(200, 255, 200)
			else
				maxBtn.Text = "Buy Max"
				maxBtn.BackgroundColor3 = Color3.fromRGB(30, 55, 30)
				maxBtn.TextColor3 = Color3.fromRGB(100, 140, 100)
			end
		end

		local ol = graveOwnedLbls[gd.key]
		if ol then
			local count = ownedGraves[gd.key] or 0
			ol.Text = "Owned: " .. count
			ol.TextColor3 = count > 0 and Color3.fromRGB(130, 220, 130) or Color3.fromRGB(100, 100, 100)
		end

		local sl = graveStockLbls[gd.key]
		if sl then
			if not inRot then
				sl.Text = ""
			elseif stock == 0 then
				sl.Text = "Sold Out!"
				sl.TextColor3 = Color3.fromRGB(220, 80, 80)
			else
				sl.Text = "Stock: " .. stock
				sl.TextColor3 = stock <= 5 and Color3.fromRGB(255, 160, 60) or Color3.fromRGB(200, 200, 100)
			end
		end

		local ro = graveRotOverlays[gd.key]
		if ro then
			ro.Visible = not locked and not inRot
		end
	end
end

-- ── Row builder ───────────────────────────────────────────────
local function makeGraveRow(parent, order, gd)
	local row = Instance.new("Frame", parent)
	row.Size = UDim2.new(1, -8, 0, 130)
	row.BackgroundColor3 = Color3.fromRGB(28, 12, 55)
	row.BorderSizePixel = 0
	row.LayoutOrder = order
	row.ZIndex = 32
	Instance.new("UICorner", row).CornerRadius = UDim.new(0, 12)

	local imgBox = Instance.new("Frame", row)
	imgBox.Size = UDim2.new(0, 100, 0, 100)
	imgBox.Position = UDim2.new(0, 14, 0.5, -50)
	imgBox.BackgroundTransparency = 1
	imgBox.BorderSizePixel = 0
	imgBox.ZIndex = 33
	imgBox.ClipsDescendants = false
	Instance.new("UICorner", imgBox).CornerRadius = UDim.new(0, 12)

	if gd.image ~= "" then
		local img = Instance.new("ImageLabel", imgBox)
		img.Size = UDim2.new(1, 0, 1, 0)
		img.BackgroundTransparency = 1
		img.Image = gd.image
		img.ScaleType = Enum.ScaleType.Fit
		img.ZIndex = 34
	else
		local eLbl = Instance.new("TextLabel", imgBox)
		eLbl.Size = UDim2.new(1, 0, 1, 0)
		eLbl.BackgroundTransparency = 1
		eLbl.Text = gd.emoji
		eLbl.TextScaled = true
		eLbl.ZIndex = 34
	end

	local nameLbl = Instance.new("TextLabel", row)
	nameLbl.Size = UDim2.new(0, 260, 0, 38)
	nameLbl.Position = UDim2.new(0, 126, 0, 16)
	nameLbl.BackgroundTransparency = 1
	nameLbl.Text = gd.name
	nameLbl.TextColor3 = Color3.fromRGB(240, 220, 255)
	nameLbl.TextXAlignment = Enum.TextXAlignment.Left
	nameLbl.TextScaled = true
	nameLbl.Font = Enum.Font.GothamBold
	nameLbl.ZIndex = 33

	local r, g, b = gd.color.R*255, gd.color.G*255, gd.color.B*255
	local luckColor = Color3.fromRGB(
		math.min(255, math.floor(r*0.5+120)),
		math.min(255, math.floor(g*0.5+160)),
		math.min(255, math.floor(b*0.5+80))
	)
	local luckLbl = Instance.new("TextLabel", row)
	luckLbl.Size = UDim2.new(0, 260, 0, 28)
	luckLbl.Position = UDim2.new(0, 126, 0, 57)
	luckLbl.BackgroundTransparency = 1
	luckLbl.Text = "🍀 " .. gd.luck .. "% Luck"
	luckLbl.TextColor3 = luckColor
	luckLbl.TextXAlignment = Enum.TextXAlignment.Left
	luckLbl.TextScaled = true
	luckLbl.Font = Enum.Font.GothamBold
	luckLbl.ZIndex = 33

	local ownedLbl = Instance.new("TextLabel", row)
	ownedLbl.Size = UDim2.new(0, 130, 0, 24)
	ownedLbl.Position = UDim2.new(0, 126, 0, 90)
	ownedLbl.BackgroundTransparency = 1
	ownedLbl.Text = "Owned: 0"
	ownedLbl.TextColor3 = Color3.fromRGB(130, 210, 130)
	ownedLbl.TextXAlignment = Enum.TextXAlignment.Left
	ownedLbl.TextScaled = true
	ownedLbl.Font = Enum.Font.Gotham
	ownedLbl.ZIndex = 33

	local stockLbl = Instance.new("TextLabel", row)
	stockLbl.Size = UDim2.new(0, 130, 0, 24)
	stockLbl.Position = UDim2.new(0, 260, 0, 90)
	stockLbl.BackgroundTransparency = 1
	stockLbl.Text = "Stock: ?"
	stockLbl.TextColor3 = Color3.fromRGB(200, 200, 100)
	stockLbl.TextXAlignment = Enum.TextXAlignment.Left
	stockLbl.TextScaled = true
	stockLbl.Font = Enum.Font.Gotham
	stockLbl.ZIndex = 33

	local buy1Btn = Instance.new("TextButton", row)
	buy1Btn.Size = UDim2.new(0, 130, 0, 54)
	buy1Btn.Position = UDim2.new(1, -142, 0, 12)
	buy1Btn.BackgroundColor3 = Color3.fromRGB(80, 40, 150)
	buy1Btn.Text = "Buy 1\n💰 " .. fmtGold(gd.cost)
	buy1Btn.TextColor3 = Color3.fromRGB(255, 255, 255)
	buy1Btn.TextScaled = true
	buy1Btn.Font = Enum.Font.GothamBold
	buy1Btn.BorderSizePixel = 0
	buy1Btn.ZIndex = 33
	Instance.new("UICorner", buy1Btn).CornerRadius = UDim.new(0, 10)

	local buyMaxBtn = Instance.new("TextButton", row)
	buyMaxBtn.Size = UDim2.new(0, 130, 0, 54)
	buyMaxBtn.Position = UDim2.new(1, -142, 0, 72)
	buyMaxBtn.BackgroundColor3 = Color3.fromRGB(50, 100, 50)
	buyMaxBtn.Text = "Buy Max"
	buyMaxBtn.TextColor3 = Color3.fromRGB(200, 255, 200)
	buyMaxBtn.TextScaled = true
	buyMaxBtn.Font = Enum.Font.GothamBold
	buyMaxBtn.BorderSizePixel = 0
	buyMaxBtn.ZIndex = 33
	Instance.new("UICorner", buyMaxBtn).CornerRadius = UDim.new(0, 10)

	local rotOverlay = Instance.new("Frame", row)
	rotOverlay.Size = UDim2.new(1, 0, 1, 0)
	rotOverlay.BackgroundColor3 = Color3.fromRGB(5, 2, 15)
	rotOverlay.BackgroundTransparency = 0.3
	rotOverlay.BorderSizePixel = 0
	rotOverlay.ZIndex = 35
	rotOverlay.Visible = false
	Instance.new("UICorner", rotOverlay).CornerRadius = UDim.new(0, 12)
	local rotLbl = Instance.new("TextLabel", rotOverlay)
	rotLbl.Size = UDim2.new(1, 0, 1, 0)
	rotLbl.BackgroundTransparency = 1
	rotLbl.Text = "🚫 Not in stock this rotation"
	rotLbl.TextColor3 = Color3.fromRGB(180, 140, 200)
	rotLbl.TextScaled = true
	rotLbl.Font = Enum.Font.GothamBold
	rotLbl.ZIndex = 36

	return buy1Btn, buyMaxBtn, ownedLbl, stockLbl, rotOverlay
end

-- ── Buy logic ─────────────────────────────────────────────────
local buyGraveRequestRemote

local function buyGrave(graveType, qty)
	if ShopPanel.isGraveLocked(graveType) then return end
	if not shopInRotation[graveType] then return end
	local gd = graveDataByKey[graveType]
	if not gd then return end
	qty = qty or 1
	local maxAffordable = math.floor(getGold() / gd.cost)
	local inStock = shopStock[graveType] or 0
	qty = math.min(qty, maxAffordable, inStock)
	if qty <= 0 then return end
	buyGraveRequestRemote:FireServer(graveType, qty)
end

local function buyGraveMax(graveType)
	if ShopPanel.isGraveLocked(graveType) then return end
	if not shopInRotation[graveType] then return end
	local gd = graveDataByKey[graveType]
	if not gd then return end
	local maxAffordable = math.floor(getGold() / gd.cost)
	local inStock = shopStock[graveType] or 0
	local qty = math.min(maxAffordable, inStock)
	if qty <= 0 then return end
	buyGraveRequestRemote:FireServer(graveType, qty)
end

-- ── Public API ────────────────────────────────────────────────
function ShopPanel.init(screenGui, deps)
	GRAVE_DATA       = deps.GRAVE_DATA
	ownedGraves      = deps.ownedGraves
	getGold          = deps.getGold
	spendGold        = deps.spendGold
	getRebirthCount  = deps.getRebirthCount
	fmtGold          = deps.fmtGold
	refreshDock      = deps.refreshDock

	for _, gd in ipairs(GRAVE_DATA) do
		graveDataByKey[gd.key] = gd
	end

	-- ── Main panel ───────────────────────────────────────────
	panel = Instance.new("Frame")
	panel.Name = "ShopPanel"
	panel.Size = UDim2.new(0, 640, 0, 560)
	panel.Position = UDim2.new(0.5, -320, 0.5, -280)
	panel.BackgroundColor3 = Color3.fromRGB(18, 8, 38)
	panel.BorderSizePixel = 0
	panel.Visible = false
	panel.ZIndex = 30
	panel.Parent = screenGui
	Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 16)

	do
		local title = Instance.new("TextLabel", panel)
		title.Size = UDim2.new(1, -50, 0, 44)
		title.Position = UDim2.new(0, 10, 0, 8)
		title.BackgroundTransparency = 1
		title.Text = "🛒 SHOP"
		title.TextColor3 = Color3.fromRGB(230, 200, 255)
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.TextScaled = true
		title.Font = Enum.Font.GothamBold
		title.ZIndex = 31

		local closeBtn = Instance.new("TextButton", panel)
		closeBtn.Size = UDim2.new(0, 36, 0, 36)
		closeBtn.Position = UDim2.new(1, -44, 0, 8)
		closeBtn.BackgroundColor3 = Color3.fromRGB(80, 30, 120)
		closeBtn.Text = "X"
		closeBtn.TextColor3 = Color3.fromRGB(255, 200, 255)
		closeBtn.TextScaled = true
		closeBtn.Font = Enum.Font.GothamBold
		closeBtn.BorderSizePixel = 0
		closeBtn.ZIndex = 31
		Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 8)
		closeBtn.MouseButton1Click:Connect(function()
			panel.Visible = false
		end)
	end

	-- ── Tabs ────────────────────────────────────────────────
	local TAB_NAMES = { "Graveyard" }
	do
		local tabBar = Instance.new("Frame", panel)
		tabBar.Size = UDim2.new(1, -20, 0, 40)
		tabBar.Position = UDim2.new(0, 10, 0, 54)
		tabBar.BackgroundTransparency = 1
		tabBar.ZIndex = 31

		local tabWidth = 1 / #TAB_NAMES
		for i, name in ipairs(TAB_NAMES) do
			local btn = Instance.new("TextButton", tabBar)
			btn.Size = UDim2.new(tabWidth, -4, 1, 0)
			btn.Position = UDim2.new((i-1)*tabWidth, 2, 0, 0)
			btn.BackgroundColor3 = Color3.fromRGB(40, 18, 75)
			btn.Text = name
			btn.TextColor3 = Color3.fromRGB(180, 150, 220)
			btn.TextScaled = true
			btn.Font = Enum.Font.GothamBold
			btn.BorderSizePixel = 0
			btn.ZIndex = 32
			Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
			tabButtons[name] = btn

			local content = Instance.new("ScrollingFrame", panel)
			content.Name = name .. "Content"
			content.Size = UDim2.new(1, -20, 1, -110)
			content.Position = UDim2.new(0, 10, 0, 100)
			content.BackgroundTransparency = 1
			content.BorderSizePixel = 0
			content.ScrollBarThickness = 4
			content.ScrollBarImageColor3 = Color3.fromRGB(120, 60, 200)
			content.Visible = (name == "Graveyard")
			content.ZIndex = 31
			content.Parent = panel
			tabContents[name] = content

			local layout = Instance.new("UIListLayout", content)
			layout.Padding = UDim.new(0, 8)
			layout.SortOrder = Enum.SortOrder.LayoutOrder
			layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
				content.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 12)
			end)

			btn.MouseButton1Click:Connect(function()
				switchTab(name)
			end)
		end
		switchTab("Graveyard")
	end

	-- ── Restock countdown ────────────────────────────────────
	local graveyardTab = tabContents["Graveyard"]
	restockLabel = Instance.new("TextLabel")
	restockLabel.Size = UDim2.new(1, 0, 0, 28)
	restockLabel.BackgroundTransparency = 1
	restockLabel.Text = "🔄 Restocks in: --:--"
	restockLabel.TextColor3 = Color3.fromRGB(180, 160, 220)
	restockLabel.TextScaled = true
	restockLabel.Font = Enum.Font.Gotham
	restockLabel.ZIndex = 33
	restockLabel.LayoutOrder = 0
	restockLabel.Parent = graveyardTab

	-- ── Grave rows ───────────────────────────────────────────
	for i, gd in ipairs(GRAVE_DATA) do
		local buy1Btn, buyMaxBtn, ownedLbl, stockLbl, rotOverlay =
			makeGraveRow(graveyardTab, i + 1, gd)
		graveButtons[gd.key]     = buy1Btn
		graveBuyMaxBtns[gd.key]  = buyMaxBtn
		graveOwnedLbls[gd.key]   = ownedLbl
		graveStockLbls[gd.key]   = stockLbl
		graveRotOverlays[gd.key] = rotOverlay

		if gd.unlockAscension > 0 then
			local row = buy1Btn.Parent
			local lockFrame = Instance.new("Frame", row)
			lockFrame.Size = UDim2.new(1, 0, 1, 0)
			lockFrame.BackgroundColor3 = Color3.fromRGB(10, 5, 25)
			lockFrame.BackgroundTransparency = 0.25
			lockFrame.BorderSizePixel = 0
			lockFrame.ZIndex = 35
			Instance.new("UICorner", lockFrame).CornerRadius = UDim.new(0, 12)
			local lockLbl = Instance.new("TextLabel", lockFrame)
			lockLbl.Size = UDim2.new(1, 0, 1, 0)
			lockLbl.BackgroundTransparency = 1
			lockLbl.Text = "🔒  Unlock at Ascension " .. gd.unlockAscension
			lockLbl.TextColor3 = Color3.fromRGB(200, 180, 255)
			lockLbl.TextScaled = true
			lockLbl.Font = Enum.Font.GothamBold
			lockLbl.ZIndex = 36
			graveLocks[gd.key] = lockFrame
		end

		local key = gd.key
		buy1Btn.MouseButton1Click:Connect(function()
			buyGrave(key, 1)
		end)
		buyMaxBtn.MouseButton1Click:Connect(function()
			buyGraveMax(key)
		end)
	end

	-- ── Remotes ──────────────────────────────────────────────
	buyGraveRequestRemote = ReplicatedStorage:WaitForChild("BuyGraveRequest", 5)

	local buyGraveResultRemote = ReplicatedStorage:WaitForChild("BuyGraveResult", 5)
	if buyGraveResultRemote then
		buyGraveResultRemote.OnClientEvent:Connect(function(graveType, confirmedQty, newStock)
			if confirmedQty <= 0 then return end
			local gd = graveDataByKey[graveType]
			if not gd then return end
			spendGold(gd.cost * confirmedQty)
			ownedGraves[graveType] = (ownedGraves[graveType] or 0) + confirmedQty
			shopStock[graveType] = newStock
			refreshDock()
			updateGraveyard()
		end)
	end

	local shopStockUpdateEvt = ReplicatedStorage:WaitForChild("ShopStockUpdate", 5)
	if shopStockUpdateEvt then
		shopStockUpdateEvt.OnClientEvent:Connect(function(stock, inRotation, secsLeft)
			shopStock        = stock
			shopInRotation   = inRotation
			shopRestockSecs  = secsLeft
			updateGraveyard()
		end)
	end

	-- ── Heartbeat: countdown + graveyard refresh ─────────────
	RunService.Heartbeat:Connect(function(dt)
		shopRestockSecs = math.max(0, shopRestockSecs - dt)
		local mins = math.floor(shopRestockSecs / 60)
		local secs = math.floor(shopRestockSecs % 60)
		restockLabel.Text = string.format("🔄 Restocks in: %d:%02d", mins, secs)
		updateGraveyard()
	end)
end

function ShopPanel.unlockGrave(graveType)
	local lf = graveLocks[graveType]
	if lf and lf.Parent then
		lf:Destroy()
		graveLocks[graveType] = nil
	end
end

function ShopPanel.show()
	panel.Visible = true
	switchTab("Graveyard")
end

function ShopPanel.updateGraveyard()
	updateGraveyard()
end

return ShopPanel
