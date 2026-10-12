-- Sell shop panel (opened from the sell shopkeeper).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local screenGui = require(script.Parent.Gui)
local State = require(script.Parent.State)
local HUD = require(script.Parent.HUD)
local Toolbar = require(script.Parent.Toolbar)
local Effects = require(script.Parent.Effects)
local Sync = require(script.Parent.Sync)
local GameData = require(script.Parent.GameData)
local UNIT_INFO = GameData.UNIT_INFO
local UNIT_ONE_IN = GameData.UNIT_ONE_IN
local RARITY_COLORS = GameData.RARITY_COLORS
local refreshToolbar = Toolbar.refresh
local showBigText = Effects.showBigText

local sellUnitRemote = ReplicatedStorage:WaitForChild("SellUnit", 5)
local openSellEvt = ReplicatedStorage:WaitForChild("OpenSell", 5)

local function getSellValue(oneIn)
	return math.floor((oneIn or 1) ^ 1.2 * 5)
end

-- Panel backdrop
local sellPanel = Instance.new("Frame")
sellPanel.Name = "SellPanel"
sellPanel.Size = UDim2.new(0, 420, 0, 480)
sellPanel.Position = UDim2.new(0.5, -210, 0.5, -240)
sellPanel.BackgroundColor3 = Color3.fromRGB(18, 10, 4)
sellPanel.BorderSizePixel = 0
sellPanel.Visible = false
sellPanel.ZIndex = 50
sellPanel.Parent = screenGui
Instance.new("UICorner", sellPanel).CornerRadius = UDim.new(0, 16)

do -- sell panel header setup
	local sellStroke = Instance.new("UIStroke", sellPanel)
	sellStroke.Color = Color3.fromRGB(200, 140, 40)
	sellStroke.Thickness = 2
	local sellTitle = Instance.new("TextLabel", sellPanel)
	sellTitle.Size = UDim2.new(1, -20, 0, 48)
	sellTitle.Position = UDim2.new(0, 10, 0, 8)
	sellTitle.BackgroundTransparency = 1
	sellTitle.Text = "Sell Units"
	sellTitle.TextColor3 = Color3.fromRGB(255, 220, 80)
	sellTitle.TextScaled = true
	sellTitle.Font = Enum.Font.GothamBold
	sellTitle.ZIndex = 51
	local sellCloseBtn = Instance.new("TextButton", sellPanel)
	sellCloseBtn.Size = UDim2.new(0, 36, 0, 36)
	sellCloseBtn.Position = UDim2.new(1, -44, 0, 8)
	sellCloseBtn.BackgroundColor3 = Color3.fromRGB(80, 20, 20)
	sellCloseBtn.Text = "X"
	sellCloseBtn.TextColor3 = Color3.fromRGB(255, 120, 120)
	sellCloseBtn.TextScaled = true
	sellCloseBtn.Font = Enum.Font.GothamBold
	sellCloseBtn.BorderSizePixel = 0
	sellCloseBtn.ZIndex = 52
	Instance.new("UICorner", sellCloseBtn).CornerRadius = UDim.new(0, 8)
	sellCloseBtn.MouseButton1Click:Connect(function()
		sellPanel.Visible = false
	end)
end

-- Scrollable list of inventory slots
local sellScroll = Instance.new("ScrollingFrame", sellPanel)
sellScroll.Size = UDim2.new(1, -20, 1, -70)
sellScroll.Position = UDim2.new(0, 10, 0, 58)
sellScroll.BackgroundTransparency = 1
sellScroll.BorderSizePixel = 0
sellScroll.ScrollBarThickness = 6
sellScroll.ScrollBarImageColor3 = Color3.fromRGB(200, 140, 40)
sellScroll.ZIndex = 51

local sellList = Instance.new("UIListLayout", sellScroll)
sellList.Padding = UDim.new(0, 6)
sellList.SortOrder = Enum.SortOrder.LayoutOrder

local function refreshSellPanel()
	-- Clear old rows (keep UIListLayout)
	for _, child in ipairs(sellScroll:GetChildren()) do
		if not child:IsA("UIListLayout") then
			child:Destroy()
		end
	end

	local rowCount = 0
	for i = 1, State.INVENTORY_MAX do
		local unit = State.inventory[i]
		if unit then
			local info = UNIT_INFO[unit.unitType]
			local oneIn = unit.oneIn or UNIT_ONE_IN[unit.unitType] or 1
			local sell = getSellValue(oneIn)
			local rColor = (info and RARITY_COLORS[info.rarity]) or Color3.fromRGB(200, 200, 200)
			local emoji = (info and info.emoji) or ""
			local rarity = (info and info.rarity) or "?"

			local row = Instance.new("Frame", sellScroll)
			row.Size = UDim2.new(1, 0, 0, 54)
			row.BackgroundColor3 = Color3.fromRGB(30, 18, 8)
			row.BorderSizePixel = 0
			row.LayoutOrder = i
			row.ZIndex = 52
			Instance.new("UICorner", row).CornerRadius = UDim.new(0, 8)

			-- Name + rarity
			local nameLbl = Instance.new("TextLabel", row)
			nameLbl.Size = UDim2.new(0.55, 0, 0.5, 0)
			nameLbl.Position = UDim2.new(0, 10, 0, 2)
			nameLbl.BackgroundTransparency = 1
			nameLbl.Text = emoji .. " " .. unit.unitType
			nameLbl.TextColor3 = Color3.fromRGB(240, 230, 210)
			nameLbl.TextScaled = true
			nameLbl.Font = Enum.Font.GothamBold
			nameLbl.TextXAlignment = Enum.TextXAlignment.Left
			nameLbl.ZIndex = 53

			local rarLbl = Instance.new("TextLabel", row)
			rarLbl.Size = UDim2.new(0.55, 0, 0.42, 0)
			rarLbl.Position = UDim2.new(0, 10, 0.52, 0)
			rarLbl.BackgroundTransparency = 1
			rarLbl.Text = rarity .. "  •  1 in " .. oneIn
			rarLbl.TextColor3 = rColor
			rarLbl.TextScaled = true
			rarLbl.Font = Enum.Font.Gotham
			rarLbl.TextXAlignment = Enum.TextXAlignment.Left
			rarLbl.ZIndex = 53

			-- Sell button
			local sellBtn = Instance.new("TextButton", row)
			sellBtn.Size = UDim2.new(0, 110, 0, 36)
			sellBtn.Position = UDim2.new(1, -120, 0.5, -18)
			sellBtn.BackgroundColor3 = Color3.fromRGB(160, 100, 10)
			sellBtn.Text = "Sell " .. sell .. " Gold"
			sellBtn.TextColor3 = Color3.fromRGB(255, 230, 120)
			sellBtn.TextScaled = true
			sellBtn.Font = Enum.Font.GothamBold
			sellBtn.BorderSizePixel = 0
			sellBtn.ZIndex = 53
			Instance.new("UICorner", sellBtn).CornerRadius = UDim.new(0, 8)

			local slotIndex = i
			sellBtn.MouseButton1Click:Connect(function()
				if not State.inventory[slotIndex] then
					return
				end
				-- The server sells it; the updated inventory comes back via Sync
				if sellUnitRemote then
					sellUnitRemote:FireServer(slotIndex)
				end
			end)

			rowCount += 1
		end
	end

	-- Empty state message
	if rowCount == 0 then
		local emptyLbl = Instance.new("TextLabel", sellScroll)
		emptyLbl.Size = UDim2.new(1, 0, 0, 50)
		emptyLbl.BackgroundTransparency = 1
		emptyLbl.Text = "No units in inventory"
		emptyLbl.TextColor3 = Color3.fromRGB(140, 120, 90)
		emptyLbl.TextScaled = true
		emptyLbl.Font = Enum.Font.Gotham
		emptyLbl.ZIndex = 52
	end

	sellScroll.CanvasSize = UDim2.new(0, 0, 0, rowCount * 60)
end


-- AddGold remote — server sends gold reward after a sell
local addGoldEvt = ReplicatedStorage:WaitForChild("AddGold", 5)
if addGoldEvt then
	addGoldEvt.OnClientEvent:Connect(function(amount, unitType)
		showBigText(
			"SOLD!",
			unitType .. "  +  " .. amount .. " Gold",
			Color3.fromRGB(255, 220, 80),
			Color3.fromRGB(200, 170, 60)
		)
	end)
end

Sync.onApplied(function()
	if sellPanel.Visible then
		refreshSellPanel()
	end
end)

if openSellEvt then
	openSellEvt.OnClientEvent:Connect(function()
		refreshSellPanel()
		sellPanel.Visible = true
	end)
end

return {}
