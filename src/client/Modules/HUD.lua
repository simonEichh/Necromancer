local HUD = {}
local Theme = require(script.Parent.Theme)

local RunService = game:GetService("RunService")

-- ── Private UI refs ──────────────────────────────────────────
local goldLbl, gemsLbl, luckLbl, spinCountLbl, spinBadge
local dustFrame, dustChips = nil, {}

-- ── Injected deps ────────────────────────────────────────────
local getGold, getGems, getSpins, getLuckBuffEnd, getCountdown, fmtNumber

-- ── Helper: make a top teleport button (stone button, see Theme) ──
local function makePillBtn(parent, text, color, x, callback)
	return Theme.stoneButton(parent, {
		text = text, color = color, size = UDim2.fromOffset(150, 44),
		position = UDim2.new(0.5, x, 0, 14), zIndex = 5, onClick = callback,
	}).root
end

-- ── Helper: make a side button (stone button; the icon spot is gone until real icons exist) ──
local function makeIconBtn(parent, icon, label, yPos, color, callback)
	return Theme.stoneButton(parent, {
		text = label, color = color, size = UDim2.fromOffset(112, 44),
		position = UDim2.fromOffset(0, yPos), zIndex = 5, onClick = callback,
	}).root
end

-- ── fmt helper (local copy for currency display) ─────────────
local function fmtCurrency(n)
	if fmtNumber then return fmtNumber(n) end
	if n >= 1e15 then return string.format("%.1fQa", n/1e15)
	elseif n >= 1e12 then return string.format("%.1fT", n/1e12)
	elseif n >= 1e9 then return string.format("%.1fB", n/1e9)
	elseif n >= 1e6 then return string.format("%.1fM", n/1e6)
	elseif n >= 1e3 then return string.format("%.1fK", n/1e3)
	else return tostring(math.floor(n)) end
end

-- ── Public API ────────────────────────────────────────────────
function HUD.init(screenGui, deps)
	getGold        = deps.getGold
	getGems        = deps.getGems
	getSpins       = deps.getSpins
	getLuckBuffEnd = deps.getLuckBuffEnd
	fmtNumber      = deps.fmtNumber

	-- ── Top center teleport buttons ──────────────────────────
	makePillBtn(screenGui, "SHOPS", nil, -160, deps.onShops)
	makePillBtn(screenGui, "WALL", "red", 10, deps.onWall)

	-- ── Top right: spin wheel button ─────────────────────────
	local spinFrame = Instance.new("Frame", screenGui)
	spinFrame.Size = UDim2.new(0, 80, 0, 80)
	spinFrame.Position = UDim2.new(1, -90, 0, 10)
	spinFrame.BackgroundColor3 = Color3.fromRGB(180, 80, 10)
	spinFrame.BackgroundTransparency = 0.1
	spinFrame.BorderSizePixel = 0
	spinFrame.ZIndex = 5
	Instance.new("UICorner", spinFrame).CornerRadius = UDim.new(0, 16)

	local spinIcon = Instance.new("TextLabel", spinFrame)
	spinIcon.Size = UDim2.new(1, 0, 0, 50)
	spinIcon.Position = UDim2.new(0, 0, 0, 4)
	spinIcon.BackgroundTransparency = 1
	spinIcon.Text = ""
	spinIcon.TextScaled = true
	spinIcon.ZIndex = 6

	spinCountLbl = Instance.new("TextLabel", spinFrame)
	spinCountLbl.Size = UDim2.new(1, 0, 0, 22)
	spinCountLbl.Position = UDim2.new(0, 0, 0, 54)
	spinCountLbl.BackgroundTransparency = 1
	spinCountLbl.Text = "0 spins"
	spinCountLbl.TextColor3 = Color3.fromRGB(255, 220, 150)
	spinCountLbl.TextScaled = true
	spinCountLbl.Font = Enum.Font.GothamBold
	spinCountLbl.ZIndex = 6

	spinBadge = Instance.new("TextLabel", spinFrame)
	spinBadge.Size = UDim2.new(0, 24, 0, 24)
	spinBadge.Position = UDim2.new(1, -8, 0, -8)
	spinBadge.BackgroundColor3 = Color3.fromRGB(220, 30, 30)
	spinBadge.Text = "0"
	spinBadge.TextColor3 = Color3.fromRGB(255, 255, 255)
	spinBadge.TextScaled = true
	spinBadge.Font = Enum.Font.GothamBold
	spinBadge.BorderSizePixel = 0
	spinBadge.ZIndex = 7
	spinBadge.Visible = false
	Instance.new("UICorner", spinBadge).CornerRadius = UDim.new(0.5, 0)

	do
		local spinBtn = Instance.new("TextButton", spinFrame)
		spinBtn.Size = UDim2.new(1, 0, 1, 0)
		spinBtn.BackgroundTransparency = 1
		spinBtn.Text = ""
		spinBtn.ZIndex = 8
		spinBtn.MouseButton1Click:Connect(deps.onSpin)
	end

	-- ── Left side: icon buttons ──────────────────────────────
	local leftPanel = Instance.new("Frame", screenGui)
	leftPanel.Size = UDim2.new(0, 112, 0, 400)
	leftPanel.Position = UDim2.new(0, 10, 0.5, -150)
	leftPanel.BackgroundTransparency = 1
	leftPanel.ZIndex = 5

	makeIconBtn(leftPanel, "", "Ascend", 0, "purple", deps.onAscend)
	makeIconBtn(leftPanel, "", "Inventory", 62, "blue", deps.onInventory)

	-- ── Right side: icon buttons ─────────────────────────────
	local rightPanel = Instance.new("Frame", screenGui)
	rightPanel.Size = UDim2.new(0, 112, 0, 400)
	rightPanel.Position = UDim2.new(1, -122, 0.5, -50)
	rightPanel.BackgroundTransparency = 1
	rightPanel.ZIndex = 5

	makeIconBtn(rightPanel, "", "Quests", 0, "blue", deps.onQuests)
	makeIconBtn(rightPanel, "", "Friends", 62, nil, deps.onFriends or function() end)

	-- ── Bottom left: currency display ────────────────────────
	local currencyFrame = Instance.new("Frame", screenGui)
	currencyFrame.Size = UDim2.new(0, 200, 0, 70)
	currencyFrame.Position = UDim2.new(0, 10, 1, -80)
	currencyFrame.BackgroundColor3 = Color3.fromRGB(8, 4, 20)
	currencyFrame.BackgroundTransparency = 0.3
	currencyFrame.BorderSizePixel = 0
	currencyFrame.ZIndex = 5
	Instance.new("UICorner", currencyFrame).CornerRadius = UDim.new(0, 12)

	-- dust row above it: a chip per dust the player has (hidden while they have none)
	do
		local Theme = require(script.Parent.Theme)
		local Economy = require(game:GetService("ReplicatedStorage").Shared.Economy)
		dustFrame = Instance.new("Frame", screenGui)
		dustFrame.Name = "DustBar"
		dustFrame.AutomaticSize = Enum.AutomaticSize.X
		dustFrame.Size = UDim2.new(0, 0, 0, 30)
		dustFrame.Position = UDim2.new(0, 10, 1, -116)
		dustFrame.BackgroundColor3 = Color3.fromRGB(8, 4, 20)
		dustFrame.BackgroundTransparency = 0.3
		dustFrame.BorderSizePixel = 0
		dustFrame.ZIndex = 5
		dustFrame.Visible = false
		Instance.new("UICorner", dustFrame).CornerRadius = UDim.new(0, 8)
		local pad = Instance.new("UIPadding", dustFrame)
		pad.PaddingLeft = UDim.new(0, 8)
		pad.PaddingRight = UDim.new(0, 8)
		local list = Instance.new("UIListLayout", dustFrame)
		list.FillDirection = Enum.FillDirection.Horizontal
		list.VerticalAlignment = Enum.VerticalAlignment.Center
		list.Padding = UDim.new(0, 10)
		list.SortOrder = Enum.SortOrder.LayoutOrder
		for i, dust in ipairs(Economy.DUSTS) do
			local chip = Instance.new("Frame", dustFrame)
			chip.BackgroundTransparency = 1
			chip.AutomaticSize = Enum.AutomaticSize.X
			chip.Size = UDim2.new(0, 0, 1, 0)
			chip.LayoutOrder = i
			chip.Visible = false
			local row = Instance.new("UIListLayout", chip)
			row.FillDirection = Enum.FillDirection.Horizontal
			row.VerticalAlignment = Enum.VerticalAlignment.Center
			row.Padding = UDim.new(0, 5)
			local dot = Instance.new("Frame", chip)
			dot.Size = UDim2.fromOffset(12, 12)
			dot.BackgroundColor3 = Theme.DustColor[dust]
			dot.BorderSizePixel = 0
			dot.ZIndex = 6
			dot.Rotation = 45 -- a small diamond
			local count = Instance.new("TextLabel", chip)
			count.AutomaticSize = Enum.AutomaticSize.X
			count.Size = UDim2.new(0, 0, 1, 0)
			count.BackgroundTransparency = 1
			count.Font = Enum.Font.GothamBold
			count.TextSize = 18
			count.TextColor3 = Theme.DustColor[dust]
			count.Text = "0"
			count.ZIndex = 6
			dustChips[dust] = { frame = chip, count = count, name = Economy.DUST_NAMES[dust] }
		end
	end

	goldLbl = Instance.new("TextLabel", currencyFrame)
	goldLbl.Size = UDim2.new(1, -10, 0.5, 0)
	goldLbl.Position = UDim2.new(0, 8, 0, 0)
	goldLbl.BackgroundTransparency = 1
	goldLbl.Text = "Gold 0"
	goldLbl.TextColor3 = Color3.fromRGB(255, 215, 0)
	goldLbl.TextXAlignment = Enum.TextXAlignment.Left
	goldLbl.TextScaled = true
	goldLbl.Font = Enum.Font.GothamBold
	goldLbl.ZIndex = 6

	gemsLbl = Instance.new("TextLabel", currencyFrame)
	gemsLbl.Size = UDim2.new(1, -10, 0.5, 0)
	gemsLbl.Position = UDim2.new(0, 8, 0.5, 0)
	gemsLbl.BackgroundTransparency = 1
	gemsLbl.Text = "Gems 0"
	gemsLbl.TextColor3 = Color3.fromRGB(100, 200, 255)
	gemsLbl.TextXAlignment = Enum.TextXAlignment.Left
	gemsLbl.TextScaled = true
	gemsLbl.Font = Enum.Font.GothamBold
	gemsLbl.ZIndex = 6

	-- ── Luck buff indicator (bottom left, above currency) ────
	luckLbl = Instance.new("TextLabel", screenGui)
	luckLbl.Size = UDim2.new(0, 200, 0, 30)
	luckLbl.Position = UDim2.new(0, 10, 1, -114)
	luckLbl.BackgroundTransparency = 1
	luckLbl.Text = ""
	luckLbl.TextColor3 = Color3.fromRGB(100, 255, 150)
	luckLbl.TextXAlignment = Enum.TextXAlignment.Left
	luckLbl.TextScaled = true
	luckLbl.Font = Enum.Font.GothamBold
	luckLbl.ZIndex = 5

	getCountdown = deps.getCountdown

	-- Wheel countdown ticker (updates every second)
	local lastTick = 0
	RunService.Heartbeat:Connect(function()
		if not spinCountLbl then return end
		local now = tick()
		if now - lastTick < 1 then return end
		lastTick = now
		local n = getSpins()
		if n > 0 then
			spinCountLbl.Text    = n .. " spin" .. (n == 1 and "" or "s")
			spinBadge.Visible    = true
			spinBadge.Text       = tostring(n)
			spinCountLbl.TextColor3 = Color3.fromRGB(255, 220, 150)
		else
			local secs = math.max(0, math.floor(getCountdown()))
			local m    = math.floor(secs / 60)
			local s    = secs % 60
			spinCountLbl.Text    = string.format("%d:%02d", m, s)
			spinBadge.Visible    = false
			spinCountLbl.TextColor3 = Color3.fromRGB(180, 140, 80)
		end
	end)
end

function HUD.update()
	if dustFrame then
		local State = require(script.Parent.State)
		local any = false
		for dust, chip in pairs(dustChips) do
			local n = (State.materials and State.materials[dust]) or 0
			chip.frame.Visible = n > 0
			chip.count.Text = chip.name .. " " .. require(script.Parent.Format).fmtGold(n)
			any = any or n > 0
		end
		dustFrame.Visible = any
	end
	if goldLbl then
		goldLbl.Text = "Gold " .. fmtCurrency(getGold())
	end
	if gemsLbl then
		gemsLbl.Text = "Gems " .. tostring(getGems())
	end
	if spinCountLbl then
		local n = getSpins()
		spinBadge.Text    = tostring(n)
		spinBadge.Visible = n > 0
	end
	if luckLbl then
		local buffEnd = getLuckBuffEnd()
		if buffEnd and tick() < buffEnd then
			local secs = math.ceil(buffEnd - tick())
			luckLbl.Text = "2× Luck (" .. secs .. "s)"
		else
			luckLbl.Text = ""
		end
	end
end

return HUD
