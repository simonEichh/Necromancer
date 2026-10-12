-- Upgrade shop panel (luck boost, coin boost).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local screenGui = require(script.Parent.Gui)
local State = require(script.Parent.State)
local HUD = require(script.Parent.HUD)
local Format = require(script.Parent.Format)
local fmtGold = Format.fmtGold

local Sync = require(script.Parent.Sync)
local Economy = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Economy"))
local luckBoostCost = Economy.luckBoostCost
local coinBoostCost = Economy.coinBoostCost

local buyUpgradeRemote = ReplicatedStorage:WaitForChild("BuyUpgrade", 5)
local openUpgradeEvt = ReplicatedStorage:WaitForChild("OpenUpgrade", 5)

local upgradePanel = Instance.new("Frame")
upgradePanel.Name = "UpgradePanel"
upgradePanel.Size = UDim2.new(0, 420, 0, 320)
upgradePanel.Position = UDim2.new(0.5, -210, 0.5, -160)
upgradePanel.BackgroundColor3 = Color3.fromRGB(6, 18, 20)
upgradePanel.BorderSizePixel = 0
upgradePanel.Visible = false
upgradePanel.ZIndex = 50
upgradePanel.Parent = screenGui
Instance.new("UICorner", upgradePanel).CornerRadius = UDim.new(0, 16)
do -- upgrade panel header setup
	local upStroke = Instance.new("UIStroke", upgradePanel)
	upStroke.Color = Color3.fromRGB(50, 200, 200)
	upStroke.Thickness = 2
	local upTitle = Instance.new("TextLabel", upgradePanel)
	upTitle.Size = UDim2.new(1, -20, 0, 48)
	upTitle.Position = UDim2.new(0, 10, 0, 6)
	upTitle.BackgroundTransparency = 1
	upTitle.Text = "Upgrades"
	upTitle.TextColor3 = Color3.fromRGB(100, 255, 240)
	upTitle.TextScaled = true
	upTitle.Font = Enum.Font.GothamBold
	upTitle.ZIndex = 51
	local upCloseBtn = Instance.new("TextButton", upgradePanel)
	upCloseBtn.Size = UDim2.new(0, 36, 0, 36)
	upCloseBtn.Position = UDim2.new(1, -44, 0, 8)
	upCloseBtn.BackgroundColor3 = Color3.fromRGB(40, 80, 80)
	upCloseBtn.Text = "X"
	upCloseBtn.TextColor3 = Color3.fromRGB(100, 255, 240)
	upCloseBtn.TextScaled = true
	upCloseBtn.Font = Enum.Font.GothamBold
	upCloseBtn.BorderSizePixel = 0
	upCloseBtn.ZIndex = 52
	Instance.new("UICorner", upCloseBtn).CornerRadius = UDim.new(0, 8)
	upCloseBtn.MouseButton1Click:Connect(function()
		upgradePanel.Visible = false
	end)
end

-- Helper: build one upgrade row, returns a refresh function
local function makeUpgradeRow(parent, yPos, icon, title, getLevel, getMax, getCost, getEffectText)
	local row = Instance.new("Frame", parent)
	row.Size = UDim2.new(1, -20, 0, 100)
	row.Position = UDim2.new(0, 10, 0, yPos)
	row.BackgroundColor3 = Color3.fromRGB(10, 30, 32)
	row.BorderSizePixel = 0
	row.ZIndex = 51
	Instance.new("UICorner", row).CornerRadius = UDim.new(0, 12)

	local iconLbl = Instance.new("TextLabel", row)
	iconLbl.Size = UDim2.new(0, 48, 0, 48)
	iconLbl.Position = UDim2.new(0, 8, 0.5, -24)
	iconLbl.BackgroundColor3 = Color3.fromRGB(15, 50, 52)
	iconLbl.Text = icon
	iconLbl.TextScaled = true
	iconLbl.ZIndex = 52
	Instance.new("UICorner", iconLbl).CornerRadius = UDim.new(0, 10)

	local titleLbl = Instance.new("TextLabel", row)
	titleLbl.Size = UDim2.new(0.55, 0, 0, 26)
	titleLbl.Position = UDim2.new(0, 64, 0, 10)
	titleLbl.BackgroundTransparency = 1
	titleLbl.TextColor3 = Color3.fromRGB(200, 255, 250)
	titleLbl.TextScaled = true
	titleLbl.Font = Enum.Font.GothamBold
	titleLbl.TextXAlignment = Enum.TextXAlignment.Left
	titleLbl.ZIndex = 52

	local effectLbl = Instance.new("TextLabel", row)
	effectLbl.Size = UDim2.new(0.55, 0, 0, 22)
	effectLbl.Position = UDim2.new(0, 64, 0, 38)
	effectLbl.BackgroundTransparency = 1
	effectLbl.TextColor3 = Color3.fromRGB(100, 220, 180)
	effectLbl.TextScaled = true
	effectLbl.Font = Enum.Font.Gotham
	effectLbl.TextXAlignment = Enum.TextXAlignment.Left
	effectLbl.ZIndex = 52

	local nextLbl = Instance.new("TextLabel", row)
	nextLbl.Size = UDim2.new(0.55, 0, 0, 20)
	nextLbl.Position = UDim2.new(0, 64, 0, 62)
	nextLbl.BackgroundTransparency = 1
	nextLbl.TextColor3 = Color3.fromRGB(150, 180, 160)
	nextLbl.TextScaled = true
	nextLbl.Font = Enum.Font.Gotham
	nextLbl.TextXAlignment = Enum.TextXAlignment.Left
	nextLbl.ZIndex = 52

	local buyBtn = Instance.new("TextButton", row)
	buyBtn.Size = UDim2.new(0, 120, 0, 44)
	buyBtn.Position = UDim2.new(1, -130, 0.5, -22)
	buyBtn.BackgroundColor3 = Color3.fromRGB(20, 100, 100)
	buyBtn.TextColor3 = Color3.fromRGB(180, 255, 240)
	buyBtn.TextScaled = true
	buyBtn.Font = Enum.Font.GothamBold
	buyBtn.BorderSizePixel = 0
	buyBtn.ZIndex = 52
	Instance.new("UICorner", buyBtn).CornerRadius = UDim.new(0, 10)

	local function refresh()
		local level = getLevel()
		local max = getMax()
		local cost = getCost(level)
		local maxed = level >= max

		titleLbl.Text = title .. "  (Lv " .. level .. "/" .. max .. ")"
		effectLbl.Text = getEffectText(level)

		if maxed then
			nextLbl.Text = "Maxed out!"
			buyBtn.Text = "MAX"
			buyBtn.BackgroundColor3 = Color3.fromRGB(30, 60, 50)
			buyBtn.TextColor3 = Color3.fromRGB(100, 160, 140)
			buyBtn.Active = false
		else
			nextLbl.Text = "Next: " .. getEffectText(level + 1)
			local canAfford = State.gold >= cost
			buyBtn.Text = "Buy\n" .. fmtGold(cost) .. " Gold"
			buyBtn.BackgroundColor3 = canAfford and Color3.fromRGB(20, 120, 110) or Color3.fromRGB(15, 50, 50)
			buyBtn.TextColor3 = canAfford and Color3.fromRGB(180, 255, 240) or Color3.fromRGB(80, 130, 120)
			buyBtn.Active = true
		end
	end

	return buyBtn, refresh
end

-- Luck Boost row
local luckBuyBtn, refreshLuckRow = makeUpgradeRow(
	upgradePanel,
	62,
	"",
	"Luck Boost",
	function()
		return State.luckBoostLevel
	end,
	function()
		return State.UPGRADE_MAX.luckBoost
	end,
	luckBoostCost,
	function(lv)
		return "+" .. (lv * 10) .. "% luck on all graves"
	end
)

-- Coin Boost row
local coinBuyBtn, refreshCoinRow = makeUpgradeRow(
	upgradePanel,
	172,
	"",
	"Coin Boost",
	function()
		return State.coinBoostLevel
	end,
	function()
		return State.UPGRADE_MAX.coinBoost
	end,
	coinBoostCost,
	function(lv)
		return "+" .. string.format("%.1fx", lv * 0.5) .. " gold multiplier"
	end
)

local function refreshUpgradePanel()
	refreshLuckRow()
	refreshCoinRow()
end

luckBuyBtn.MouseButton1Click:Connect(function()
	if State.luckBoostLevel >= State.UPGRADE_MAX.luckBoost then
		return
	end
	local cost = luckBoostCost(State.luckBoostLevel)
	if State.gold < cost then
		return
	end
	-- The server charges for it and sends back the new level via Sync
	if buyUpgradeRemote then
		buyUpgradeRemote:FireServer("luckBoost")
	end
end)

coinBuyBtn.MouseButton1Click:Connect(function()
	if State.coinBoostLevel >= State.UPGRADE_MAX.coinBoost then
		return
	end
	local cost = coinBoostCost(State.coinBoostLevel)
	if State.gold < cost then
		return
	end
	if buyUpgradeRemote then
		buyUpgradeRemote:FireServer("coinBoost")
	end
end)

Sync.onApplied(function()
	if upgradePanel.Visible then
		refreshUpgradePanel()
	end
end)

if openUpgradeEvt then
	openUpgradeEvt.OnClientEvent:Connect(function()
		refreshUpgradePanel()
		upgradePanel.Visible = true
	end)
end

return {}
