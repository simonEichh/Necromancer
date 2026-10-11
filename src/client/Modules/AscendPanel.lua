-- Ascend (rebirth) confirmation panel.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local screenGui = require(script.Parent.Gui)
local State = require(script.Parent.State)
local HUD = require(script.Parent.HUD)
local ShopPanel = require(script.Parent.ShopPanel)
local Effects = require(script.Parent.Effects)
local Format = require(script.Parent.Format)
local GameData = require(script.Parent.GameData)
local GRAVE_DATA = GameData.GRAVE_DATA
local fmt = Format.fmt
local showBigText = Effects.showBigText

local ascendPanel
local updateAscendPanel

ascendPanel = Instance.new("Frame")
ascendPanel.Name = "AscendPanel"
ascendPanel.Size = UDim2.new(0, 420, 0, 280)
ascendPanel.Position = UDim2.new(0.5, -210, 0.5, -140)
ascendPanel.BackgroundColor3 = Color3.fromRGB(20, 8, 5)
ascendPanel.BorderSizePixel = 0
ascendPanel.Visible = false
ascendPanel.ZIndex = 50
ascendPanel.Parent = screenGui
Instance.new("UICorner", ascendPanel).CornerRadius = UDim.new(0, 16)

local ascendTitle = Instance.new("TextLabel", ascendPanel)
ascendTitle.Size = UDim2.new(1, -20, 0, 50)
ascendTitle.Position = UDim2.new(0, 10, 0, 10)
ascendTitle.BackgroundTransparency = 1
ascendTitle.Text = "⬆️ ASCEND"
ascendTitle.TextColor3 = Color3.fromRGB(255, 190, 80)
ascendTitle.TextScaled = true
ascendTitle.Font = Enum.Font.GothamBold
ascendTitle.ZIndex = 51

local ascendWarning = Instance.new("TextLabel", ascendPanel)
ascendWarning.Size = UDim2.new(1, -20, 0, 36)
ascendWarning.Position = UDim2.new(0, 10, 0, 62)
ascendWarning.BackgroundTransparency = 1
ascendWarning.Text = "⚠️ You will lose all your Gold!"
ascendWarning.TextColor3 = Color3.fromRGB(255, 120, 80)
ascendWarning.TextScaled = true
ascendWarning.Font = Enum.Font.GothamBold
ascendWarning.ZIndex = 51

local ascendInfoLbl = Instance.new("TextLabel", ascendPanel)
ascendInfoLbl.Size = UDim2.new(1, -20, 0, 80)
ascendInfoLbl.Position = UDim2.new(0, 10, 0, 104)
ascendInfoLbl.BackgroundTransparency = 1
ascendInfoLbl.TextColor3 = Color3.fromRGB(220, 200, 255)
ascendInfoLbl.TextScaled = true
ascendInfoLbl.Font = Enum.Font.Gotham
ascendInfoLbl.TextWrapped = true
ascendInfoLbl.ZIndex = 51

local ascendConfirmBtn = Instance.new("TextButton", ascendPanel)
ascendConfirmBtn.Size = UDim2.new(0, 170, 0, 44)
ascendConfirmBtn.Position = UDim2.new(0, 20, 1, -60)
ascendConfirmBtn.BackgroundColor3 = Color3.fromRGB(140, 60, 10)
ascendConfirmBtn.Text = "✅ Confirm Ascend"
ascendConfirmBtn.TextColor3 = Color3.fromRGB(255, 230, 150)
ascendConfirmBtn.TextScaled = true
ascendConfirmBtn.Font = Enum.Font.GothamBold
ascendConfirmBtn.BorderSizePixel = 0
ascendConfirmBtn.ZIndex = 51
Instance.new("UICorner", ascendConfirmBtn).CornerRadius = UDim.new(0, 10)

local ascendCancelBtn = Instance.new("TextButton", ascendPanel)
ascendCancelBtn.Size = UDim2.new(0, 170, 0, 44)
ascendCancelBtn.Position = UDim2.new(1, -190, 1, -60)
ascendCancelBtn.BackgroundColor3 = Color3.fromRGB(50, 25, 25)
ascendCancelBtn.Text = "X Cancel"
ascendCancelBtn.TextColor3 = Color3.fromRGB(200, 150, 150)
ascendCancelBtn.TextScaled = true
ascendCancelBtn.Font = Enum.Font.GothamBold
ascendCancelBtn.BorderSizePixel = 0
ascendCancelBtn.ZIndex = 51
Instance.new("UICorner", ascendCancelBtn).CornerRadius = UDim.new(0, 10)

local ASCEND_UNLOCKS = {
	[1] = "Unlocks: Stone Coffin grave",
	[2] = "Unlocks: Ancient Tomb grave",
}

updateAscendPanel = function()
	local tier = State.rebirthCount + 1
	local cost = State.ASCEND_COSTS[math.min(tier, #State.ASCEND_COSTS)]
	local unlockText = ASCEND_UNLOCKS[tier] or "No new unlocks — gold multiplier only"
	local newMult = 1.0 + (State.rebirthCount + 1)
	ascendInfoLbl.Text =
		string.format("Cost: 💰 %s Gold\n%s\nNew gold multiplier: %.0fx", fmt(cost), unlockText, newMult)
	local canAfford = State.gold >= cost
	ascendConfirmBtn.BackgroundColor3 = canAfford and Color3.fromRGB(140, 60, 10) or Color3.fromRGB(50, 25, 10)
	ascendConfirmBtn.TextColor3 = canAfford and Color3.fromRGB(255, 230, 150) or Color3.fromRGB(130, 100, 60)
end

ascendCancelBtn.MouseButton1Click:Connect(function()
	ascendPanel.Visible = false
end)

ascendConfirmBtn.MouseButton1Click:Connect(function()
	local tier = State.rebirthCount + 1
	local cost = State.ASCEND_COSTS[math.min(tier, #State.ASCEND_COSTS)]
	if State.gold < cost then
		return
	end

	State.gold = 0
	State.rebirthCount += 1
	State.goldMultiplier = 1.0 + State.rebirthCount

	-- Remove the lock overlay for whichever grave tier just unlocked
	for _, gd in ipairs(GRAVE_DATA) do
		if gd.unlockAscension == State.rebirthCount then
			ShopPanel.unlockGrave(gd.key)
		end
	end

	ascendPanel.Visible = false
	HUD.update()
	ShopPanel.updateGraveyard()

	local ascendRemote = ReplicatedStorage:FindFirstChild("PlayerAscend")
	if ascendRemote then
		ascendRemote:FireServer()
	end

	showBigText(
		"⬆️ ASCENDED!",
		"Ascension " .. State.rebirthCount .. "  |  " .. string.format("%.0fx", State.goldMultiplier) .. " Gold Multiplier",
		Color3.fromRGB(255, 190, 80),
		Color3.fromRGB(255, 220, 150)
	)
end)

local function toggle()
	if not ascendPanel.Visible then
		updateAscendPanel()
	end
	ascendPanel.Visible = not ascendPanel.Visible
end

return {
	toggle = toggle,
}
