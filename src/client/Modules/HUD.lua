local HUD = {}
local Theme = require(script.Parent.Theme)

local RunService = game:GetService("RunService")

-- ── Private UI refs ──────────────────────────────────────────
local goldLbl, gemsLbl, luckLbl, spinCountLbl, spinBadge
local dustFrame, dustChips = nil, {}

-- ── Injected deps ────────────────────────────────────────────
local getGold, getGems, getSpins, getLuckBuffEnd, getCountdown, fmtNumber

-- the plaza (shops) is the circle round the origin; anywhere else counts as being at your plot / wall
local PLAZA_RADIUS = 60

-- ── Helper: make a side menu tile (square icon tile, see Theme.iconTile / Theme.Image.Icon) ──
-- tiles are 68 px, one every TILE_STEP px down a column (the label hangs over the bottom edge)
local TILE_STEP = 84
local function makeIconBtn(parent, icon, label, row, callback)
	return Theme.iconTile(parent, {
		icon = icon, text = label, position = UDim2.fromOffset(0, row * TILE_STEP), zIndex = 5, onClick = callback,
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

	-- ── Top center: one travel tile that always offers the other place (Shops at your plot, Wall in the plaza) ──
	do
		local inPlaza = nil
		local travel
		travel = Theme.iconTile(screenGui, {
			text = "Shops", anchor = Vector2.new(0.5, 0), position = UDim2.new(0.5, 0, 0, 14), zIndex = 5,
			onClick = function()
				if inPlaza then
					deps.onWall()
				else
					deps.onShops()
				end
			end,
		})
		travel.root.Name = "TravelTile"
		local player = game:GetService("Players").LocalPlayer
		local lastCheck = 0
		RunService.Heartbeat:Connect(function()
			local now = os.clock()
			if now - lastCheck < 0.25 then
				return
			end
			lastCheck = now
			local char = player.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			if not hrp then
				return
			end
			local p = hrp.Position
			local nowInPlaza = Vector2.new(p.X, p.Z).Magnitude < PLAZA_RADIUS
			if nowInPlaza ~= inPlaza then
				inPlaza = nowInPlaza
				travel.label.Text = inPlaza and "Wall" or "Shops"
				travel.icon.Image = (inPlaza and Theme.Image.Icon.Wall or Theme.Image.Icon.Shops) or ""
			end
		end)
	end

	-- ── Top right: spin wheel button ─────────────────────────
	-- an icon tile like the side menus; its label shows the spins or the countdown to the next free spin
	local spinTile = Theme.iconTile(screenGui, {
		icon = Theme.Image.Icon.Wheel, text = "0 spins", size = 76,
		position = UDim2.new(1, -92, 0, 14), zIndex = 5, onClick = deps.onSpin,
	})
	local spinFrame = spinTile.root
	spinCountLbl = spinTile.label

	spinBadge = Instance.new("TextLabel", spinFrame)
	spinBadge.Size = UDim2.new(0, 24, 0, 24)
	spinBadge.Position = UDim2.new(1, -8, 0, -8)
	spinBadge.BackgroundColor3 = Color3.fromRGB(220, 30, 30)
	spinBadge.Text = "0"
	spinBadge.TextColor3 = Color3.fromRGB(255, 255, 255)
	spinBadge.TextScaled = true
	spinBadge.Font = Enum.Font.GothamBold
	spinBadge.BorderSizePixel = 0
	spinBadge.ZIndex = 9
	spinBadge.Visible = false
	Instance.new("UICorner", spinBadge).CornerRadius = UDim.new(0.5, 0)

	-- ── Left side: icon buttons ──────────────────────────────
	local leftPanel = Instance.new("Frame", screenGui)
	leftPanel.Size = UDim2.new(0, 68, 0, 400)
	leftPanel.Position = UDim2.new(0, 16, 0.5, -200) -- GravesDock puts its tile in row 3 (0.5, -32)
	leftPanel.BackgroundTransparency = 1
	leftPanel.ZIndex = 5

	makeIconBtn(leftPanel, Theme.Image.Icon.Ascend, "Ascend", 0, deps.onAscend)
	makeIconBtn(leftPanel, Theme.Image.Icon.Inventory, "Inventory", 1, deps.onInventory)

	-- ── Right side: icon buttons ─────────────────────────────
	local rightPanel = Instance.new("Frame", screenGui)
	rightPanel.Size = UDim2.new(0, 68, 0, 400)
	rightPanel.Position = UDim2.new(1, -84, 0.5, -100)
	rightPanel.BackgroundTransparency = 1
	rightPanel.ZIndex = 5

	makeIconBtn(rightPanel, Theme.Image.Icon.Quests, "Quests", 0, deps.onQuests)
	makeIconBtn(rightPanel, Theme.Image.Icon.Friends, "Friends", 1, deps.onFriends or function() end)

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
		dustFrame.Size = UDim2.new(0, 0, 0, 34)
		dustFrame.Position = UDim2.new(0, 10, 1, -120)
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
			local icon = Instance.new("ImageLabel", chip)
			icon.Size = UDim2.fromOffset(28, 28)
			icon.BackgroundTransparency = 1
			icon.Image = Theme.Image.Dust[dust] or ""
			icon.ZIndex = 6
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

	for i, img in ipairs({ Theme.Image.Icon.Gold, Theme.Image.Icon.Gems }) do
		local icon = Instance.new("ImageLabel", currencyFrame)
		icon.BackgroundTransparency = 1
		icon.Image = img
		icon.AnchorPoint = Vector2.new(0.5, 0.5)
		icon.Size = UDim2.fromOffset(36, 36)
		icon.Position = UDim2.new(0, 22, (i - 0.5) / 2, 0)
		icon.ZIndex = 6
	end

	goldLbl = Instance.new("TextLabel", currencyFrame)
	goldLbl.Size = UDim2.new(1, -50, 0.5, -4)
	goldLbl.Position = UDim2.new(0, 44, 0, 2)
	goldLbl.BackgroundTransparency = 1
	goldLbl.Text = "0"
	goldLbl.TextColor3 = Color3.fromRGB(255, 215, 0)
	goldLbl.TextXAlignment = Enum.TextXAlignment.Left
	goldLbl.TextScaled = true
	goldLbl.Font = Enum.Font.GothamBold
	goldLbl.ZIndex = 6

	gemsLbl = Instance.new("TextLabel", currencyFrame)
	gemsLbl.Size = UDim2.new(1, -50, 0.5, -4)
	gemsLbl.Position = UDim2.new(0, 44, 0.5, 2)
	gemsLbl.BackgroundTransparency = 1
	gemsLbl.Text = "0"
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
		goldLbl.Text = fmtCurrency(getGold())
	end
	if gemsLbl then
		gemsLbl.Text = tostring(getGems())
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
