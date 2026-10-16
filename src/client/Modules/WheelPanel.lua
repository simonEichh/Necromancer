-- The real plaza wheel, viewed in the world. The server rolls and awards every reward.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Theme = require(script.Parent.Theme)
local State = require(script.Parent.State)
local HUD = require(script.Parent.HUD)
local Sync = require(script.Parent.Sync)
local WheelScene = require(script.Parent.WheelScene)
local Rewards = require(ReplicatedStorage.Shared.WheelRewards)
local WheelPrizes = require(ReplicatedStorage.Shared.WheelPrizes)
local Format = require(script.Parent.Format)
local C, Z = Theme.Color, 60
local player = Players.LocalPlayer
local WheelPanel = {}
local view, spinning, pendingSpin, pendingAt, reward, finishAt
local hiddenParts = {}
local wheelSpinRemote = ReplicatedStorage:WaitForChild("WheelSpin")

-- ============================================================
-- In-world controls
-- ============================================================
local gui = Instance.new("ScreenGui")
gui.Name = "WheelUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 20
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")
local themed = Theme.panel(gui, {
	title = "Lucky Wheel", size = UDim2.fromOffset(400, 660),
	anchor = Vector2.new(1, 0.5), position = UDim2.new(1, -70, 0.5, 0), zIndex = Z,
})
local panel = themed.frame
require(script.Parent.Windows).register(panel)
panel.Name = "WheelPanel"
panel.Visible = false
local body = themed.body
local scale = Instance.new("UIScale", panel)
local function fit()
	local size = gui.AbsoluteSize
	if size.Y > 0 then scale.Scale = math.clamp(math.min((size.Y - 100) / 716, size.X * 0.4 / 456), 0.4, 1) end
end
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
fit()

local function text(name, value, color, y, height, font)
	local label = Theme.label(body, {
		text = value, color = color, font = font or "Body", frameSize = UDim2.new(1, 0, 0, height),
	})
	label.Name = name
	label.Position = UDim2.fromOffset(0, y)
	label.ZIndex = Z + 3
	return label
end
local countLabel = text("SpinCount", "Spins available: 0", C.Bone, 0, 28, "Strong")
local countdown = text("Countdown", "Next spin in: 15:00", C.BoneDim, 32, 22)
local resultLabel = text("ResultLbl", "Turn the wheel and let fate decide.", C.Soul, 65, 48)
resultLabel.TextWrapped = true
text("RewardsHeading", "Rewards and chances", C.BoneDim, 110, 22)
local rewardRows = {}
for i, outcome in ipairs(Rewards) do
	local row = Instance.new("Frame", body)
	row.Name = "Outcome" .. i
	row.Size = UDim2.new(1, 0, 0, 44)
	row.Position = UDim2.fromOffset(0, 138 + (i - 1) * 48)
	row.BackgroundColor3 = C.StoneRaised
	row.BorderSizePixel = 0
	row.ZIndex = Z + 2
	Theme.corner(row, Theme.Radius.Small)
	local border = Theme.stroke(row, C.Border)
	local name = Theme.label(row, { text = outcome.label, color = C.Bone, frameSize = UDim2.new(1, -66, 0, 22) })
	name.Position = UDim2.fromOffset(8, 1)
	name.ZIndex = Z + 3
	local detail = Theme.label(row, { text = "", size = "Small", color = C.BoneDim, frameSize = UDim2.new(1, -16, 0, 20) })
	detail.Position = UDim2.fromOffset(8, 22)
	detail.ZIndex = Z + 3
	local chance = Theme.label(row, { text = outcome.weight .. "%", color = C.Gold,
		align = Enum.TextXAlignment.Right, frameSize = UDim2.new(0, 48, 1, 0) })
	chance.Position = UDim2.new(1, -56, 0, 0)
	chance.ZIndex = Z + 3
	rewardRows[i] = { frame = row, border = border, detail = detail }
end
local spinButton
local function refresh()
	local crownOwned = table.find(State.items, "SpectralCrown") ~= nil
	local income = WheelPrizes.armyIncome(State.placed, State.rebirthCount, State.coinBoostLevel, State.realmUpgrades.harvest)
	for i, outcome in ipairs(Rewards) do
		local prize = WheelPrizes.resolve(outcome, State.rebirthCount, income, crownOwned)
		rewardRows[i].detail.Text = prize.itemKey and not prize.duplicate and "Unlock Spectral Crown"
			or WheelPrizes.describe(prize, Format.fmtGold)
	end
	countLabel.Text = "Spins available: " .. State.wheelSpins
	local seconds = math.max(0, math.floor(State.wheelCountdownSecs))
	countdown.Text = string.format("Next spin in: %d:%02d", math.floor(seconds / 60), seconds % 60)
	local busy = WheelScene.busy()
	spinButton.root:SetAttribute("Disabled", State.wheelSpins <= 0 or spinning or pendingSpin or busy)
	spinButton.label.Text = (spinning or busy) and "Spinning..." or pendingSpin and "Waiting..." or "Spin"
end

local function close()
	panel.Visible = false
	if view then view:close() else gui.Enabled = false end
end
Theme.stoneButton(panel, {
	text = "X", color = "red", size = UDim2.fromOffset(44, 28),
	position = UDim2.new(1, -62, 0, 6), zIndex = Z + 2, onClick = close,
})
spinButton = Theme.stoneButton(body, {
	text = "Spin", color = "gold", size = UDim2.fromOffset(200, 44),
	position = UDim2.new(0.5, 0, 0, 482), anchor = Vector2.new(0.5, 0), zIndex = Z + 3,
	onClick = function()
		if spinning or pendingSpin or State.wheelSpins <= 0 or WheelScene.busy() then return end
		pendingSpin, pendingAt = true, os.clock()
		resultLabel.Text = "The wheel awakens..."
		for _, r in ipairs(rewardRows) do r.border.Color = C.Border end
		Sync.hold()
		refresh()
		wheelSpinRemote:FireServer()
	end,
})
require(script.Parent.LuckPotionButton).create(body, {
	size = UDim2.fromOffset(300, 36), position = UDim2.new(0.5, 0, 0, 538),
	anchor = Vector2.new(0.5, 0), zIndex = Z + 3,
})

function WheelPanel.open()
	if view or not WheelScene.model() then return end
	local character = player.Character
	if not character or not character:FindFirstChild("HumanoidRootPart") then return end
	gui.Enabled = true
	panel.Visible = true
	if character then
		for _, p in character:GetDescendants() do
			if p:IsA("BasePart") then hiddenParts[p] = p.LocalTransparencyModifier p.LocalTransparencyModifier = 1 end
		end
	end
	view = WheelScene.open(gui, function()
		for p, value in pairs(hiddenParts) do if p.Parent then p.LocalTransparencyModifier = value end end
		table.clear(hiddenParts)
		view = nil
		panel.Visible = false
		gui.Enabled = false
	end)
	refresh()
end
function WheelPanel.toggle()
	if panel.Visible then close() else WheelPanel.open() end
end
panel:GetPropertyChangedSignal("Visible"):Connect(function()
	if not panel.Visible and view then view:close() end
end)
ReplicatedStorage:WaitForChild("OpenWheel").OnClientEvent:Connect(WheelPanel.open)

-- ============================================================
-- Server results and countdown
-- ============================================================
ReplicatedStorage:WaitForChild("WheelSpinsUpdate").OnClientEvent:Connect(function(newSpins, secondsUntilNext)
	State.wheelSpins = newSpins
	State.wheelCountdownSecs = secondsUntilNext or 900
	HUD.update()
	refresh()
end)
ReplicatedStorage:WaitForChild("WheelRejected").OnClientEvent:Connect(function(reason)
	if spinning then return end -- a second rejected request must not interrupt the accepted spin
	pendingSpin = false
	Sync.release()
	resultLabel.Text = reason
	refresh()
end)
ReplicatedStorage:WaitForChild("WheelResult").OnClientEvent:Connect(function(data)
	pendingSpin = false
	spinning = true
	reward = data
	finishAt = (data.spinAt or workspace:GetServerTimeNow()) + (data.spinDuration or 5)
	resultLabel.Text = "The wheel is turning..."
	refresh()
end)
local lastCountdownTick = tick()
RunService.Heartbeat:Connect(function()
	if spinning and workspace:GetServerTimeNow() >= finishAt then
		spinning = false
		local outcome = Rewards[reward.outcomeIdx or 1]
		Sync.release()
		resultLabel.Text = "You got: " .. (reward.prize and WheelPrizes.describe(reward.prize, Format.fmtGold) or outcome.label)
		local row = rewardRows[reward.outcomeIdx or 1]
		if row then row.border.Color = C.Soul end
		reward = nil
		HUD.update()
		refresh()
	end
	if pendingSpin and os.clock() - pendingAt > 6 then
		pendingSpin = false
		Sync.release()
		resultLabel.Text = "The wheel did not answer. Try again."
		refresh()
	end
	local now = tick()
	if now - lastCountdownTick >= 1 then
		lastCountdownTick = now
		State.wheelCountdownSecs = math.max(0, State.wheelCountdownSecs - 1)
		HUD.update()
		if panel.Visible then refresh() end
	end
end)
Sync.onApplied(function() if panel.Visible then refresh() end end)
refresh()
return WheelPanel
