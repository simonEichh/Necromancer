-- Lucky wheel panel: spin animation, rewards and the spin countdown.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local screenGui = require(script.Parent.Gui)
local State = require(script.Parent.State)
local HUD = require(script.Parent.HUD)
local GravesDock = require(script.Parent.GravesDock)
local Sync = require(script.Parent.Sync)

local wheelPanel

-- Outcome definitions (must match server order exactly; chance % shown on card)
local WHEEL_OUTCOMES = {
	{
		id = "gold_1k",
		label = "+1k Gold",
		emoji = "",
		chance = "50%",
		color = Color3.fromRGB(220, 160, 10),
	},
	{
		id = "luck_buff",
		label = "2x Luck 5min",
		emoji = "",
		chance = "10%",
		color = Color3.fromRGB(30, 150, 30),
	},
	{
		id = "gems_50",
		label = "+50 Gems",
		emoji = "",
		chance = "16%",
		color = Color3.fromRGB(50, 120, 220),
	},
	{
		id = "graves_5",
		label = "+5 Graves",
		emoji = "",
		chance = "10%",
		color = Color3.fromRGB(120, 60, 200),
	},
	{
		id = "gems_100",
		label = "+100 Gems",
		emoji = "",
		chance = "8%",
		color = Color3.fromRGB(20, 70, 200),
	},
	{
		id = "grave_rare",
		label = "+1 Rare Grave",
		emoji = "",
		chance = "5%",
		color = Color3.fromRGB(60, 20, 130),
	},
	{
		id = "lucky_box",
		label = "Lucky Box!",
		emoji = "",
		chance = "1%",
		color = Color3.fromRGB(200, 40, 40),
	},
}
local NUM_OUTCOMES = #WHEEL_OUTCOMES

-- Wheel panel
do
	local CARD_W = 130
	local CARD_H = 150
	local CARD_GAP = 8
	local VISIBLE_CARDS = 7 -- how many cards are visible at once
	local STRIP_W = VISIBLE_CARDS * (CARD_W + CARD_GAP) - CARD_GAP
	local REPEATS = 12 -- how many full loops of outcomes in the strip

	wheelPanel = Instance.new("Frame")
	wheelPanel.Name = "WheelPanel"
	wheelPanel.Size = UDim2.new(0, STRIP_W + 60, 0, 380)
	wheelPanel.Position = UDim2.new(0.5, -(STRIP_W + 60) / 2, 0.5, -190)
	wheelPanel.BackgroundColor3 = Color3.fromRGB(20, 10, 40)
	wheelPanel.BackgroundTransparency = 0.05
	wheelPanel.BorderSizePixel = 0
	wheelPanel.ZIndex = 60
	wheelPanel.Visible = false
	require(script.Parent.Windows).register(wheelPanel) -- only one window open at a time
	wheelPanel.Parent = screenGui
	Instance.new("UICorner", wheelPanel).CornerRadius = UDim.new(0, 18)

	-- Title
	local wTitle = Instance.new("TextLabel", wheelPanel)
	wTitle.Size = UDim2.new(1, 0, 0, 50)
	wTitle.Position = UDim2.new(0, 0, 0, 0)
	wTitle.BackgroundTransparency = 1
	wTitle.Text = "Lucky Wheel"
	wTitle.TextColor3 = Color3.fromRGB(255, 220, 100)
	wTitle.TextScaled = true
	wTitle.Font = Enum.Font.GothamBold
	wTitle.ZIndex = 61

	-- Close button
	local wClose = Instance.new("TextButton", wheelPanel)
	wClose.Size = UDim2.new(0, 36, 0, 36)
	wClose.Position = UDim2.new(1, -44, 0, 8)
	wClose.BackgroundColor3 = Color3.fromRGB(80, 30, 30)
	wClose.Text = "X"
	wClose.TextColor3 = Color3.fromRGB(255, 180, 180)
	wClose.TextScaled = true
	wClose.Font = Enum.Font.GothamBold
	wClose.BorderSizePixel = 0
	wClose.ZIndex = 62
	Instance.new("UICorner", wClose).CornerRadius = UDim.new(0, 8)
	wClose.MouseButton1Click:Connect(function()
		wheelPanel.Visible = false
	end)

	-- Spin count label
	local wSpinCount = Instance.new("TextLabel", wheelPanel)
	wSpinCount.Name = "SpinCount"
	wSpinCount.Size = UDim2.new(1, 0, 0, 26)
	wSpinCount.Position = UDim2.new(0, 0, 0, 48)
	wSpinCount.BackgroundTransparency = 1
	wSpinCount.Text = "Spins available: 0"
	wSpinCount.TextColor3 = Color3.fromRGB(200, 200, 255)
	wSpinCount.TextScaled = true
	wSpinCount.Font = Enum.Font.Gotham
	wSpinCount.ZIndex = 61

	-- Countdown label
	local wCountdown = Instance.new("TextLabel", wheelPanel)
	wCountdown.Name = "Countdown"
	wCountdown.Size = UDim2.new(1, 0, 0, 22)
	wCountdown.Position = UDim2.new(0, 0, 0, 72)
	wCountdown.BackgroundTransparency = 1
	wCountdown.Text = "Next spin in: 15:00"
	wCountdown.TextColor3 = Color3.fromRGB(160, 160, 200)
	wCountdown.TextScaled = true
	wCountdown.Font = Enum.Font.Gotham
	wCountdown.ZIndex = 61

	-- Strip container (clips cards)
	local stripClip = Instance.new("Frame", wheelPanel)
	stripClip.Size = UDim2.new(0, STRIP_W, 0, CARD_H)
	stripClip.Position = UDim2.new(0, 30, 0, 104)
	stripClip.BackgroundTransparency = 1
	stripClip.ClipsDescendants = true
	stripClip.ZIndex = 61

	-- Highlight box (center of strip - shows the "winning" position)
	local highlightBox = Instance.new("Frame", wheelPanel)
	highlightBox.Size = UDim2.new(0, CARD_W + 8, 0, CARD_H + 8)
	highlightBox.Position = UDim2.new(0, 30 + (VISIBLE_CARDS // 2) * (CARD_W + CARD_GAP) - 4, 0, 100)
	highlightBox.BackgroundTransparency = 1
	highlightBox.BorderSizePixel = 3
	highlightBox.ZIndex = 65
	local hlStroke = Instance.new("UIStroke", highlightBox)
	hlStroke.Color = Color3.fromRGB(255, 220, 50)
	hlStroke.Thickness = 3

	-- Build the strip (REPEATS * NUM_OUTCOMES cards)
	local totalCards = REPEATS * NUM_OUTCOMES
	local stripInner = Instance.new("Frame", stripClip)
	stripInner.Name = "StripInner"
	stripInner.Size = UDim2.new(0, totalCards * (CARD_W + CARD_GAP), 0, CARD_H)
	stripInner.Position = UDim2.new(0, 0, 0, 0)
	stripInner.BackgroundTransparency = 1
	stripInner.ZIndex = 62

	for i = 1, totalCards do
		local oi = ((i - 1) % NUM_OUTCOMES) + 1
		local o = WHEEL_OUTCOMES[oi]
		local card = Instance.new("Frame", stripInner)
		card.Size = UDim2.new(0, CARD_W, 0, CARD_H)
		card.Position = UDim2.new(0, (i - 1) * (CARD_W + CARD_GAP), 0, 0)
		card.BackgroundColor3 = o.color
		card.BorderSizePixel = 0
		card.ZIndex = 63
		Instance.new("UICorner", card).CornerRadius = UDim.new(0, 12)

		local emojiLbl = Instance.new("TextLabel", card)
		emojiLbl.Size = UDim2.new(1, 0, 0, 60)
		emojiLbl.Position = UDim2.new(0, 0, 0, 12)
		emojiLbl.BackgroundTransparency = 1
		emojiLbl.Text = o.emoji
		emojiLbl.TextScaled = true
		emojiLbl.Font = Enum.Font.GothamBold
		emojiLbl.ZIndex = 64

		local nameLbl = Instance.new("TextLabel", card)
		nameLbl.Size = UDim2.new(1, -8, 0, 40)
		nameLbl.Position = UDim2.new(0, 4, 0, 74)
		nameLbl.BackgroundTransparency = 1
		nameLbl.Text = o.label
		nameLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
		nameLbl.TextScaled = true
		nameLbl.Font = Enum.Font.GothamBold
		nameLbl.TextWrapped = true
		nameLbl.ZIndex = 64

		local chanceLbl = Instance.new("TextLabel", card)
		chanceLbl.Size = UDim2.new(1, -8, 0, 26)
		chanceLbl.Position = UDim2.new(0, 4, 0, 116)
		chanceLbl.BackgroundTransparency = 1
		chanceLbl.Text = o.chance
		chanceLbl.TextColor3 = Color3.fromRGB(180, 255, 140)
		chanceLbl.TextScaled = true
		chanceLbl.Font = Enum.Font.GothamBold
		chanceLbl.ZIndex = 64
	end

	-- Spin button
	local spinBtn = Instance.new("TextButton", wheelPanel)
	spinBtn.Name = "SpinBtn"
	spinBtn.Size = UDim2.new(0, 200, 0, 50)
	spinBtn.Position = UDim2.new(0.5, -100, 0, 268)
	spinBtn.BackgroundColor3 = Color3.fromRGB(180, 100, 0)
	spinBtn.Text = "SPIN!"
	spinBtn.TextColor3 = Color3.fromRGB(255, 240, 180)
	spinBtn.TextScaled = true
	spinBtn.Font = Enum.Font.GothamBold
	spinBtn.BorderSizePixel = 0
	spinBtn.ZIndex = 61
	Instance.new("UICorner", spinBtn).CornerRadius = UDim.new(0, 12)

	-- Result label (shown after spin)
	local resultLbl = Instance.new("TextLabel", wheelPanel)
	resultLbl.Name = "ResultLbl"
	resultLbl.Size = UDim2.new(1, -20, 0, 42)
	resultLbl.Position = UDim2.new(0, 10, 0, 325)
	resultLbl.BackgroundTransparency = 1
	resultLbl.Text = ""
	resultLbl.TextColor3 = Color3.fromRGB(255, 255, 180)
	resultLbl.TextScaled = true
	resultLbl.Font = Enum.Font.GothamBold
	resultLbl.ZIndex = 61

	-- ── Wheel logic ──────────────────────────────────────────
	local spinning = false
	local pendingSpin = false -- true while waiting for server response

	local function refreshWheelUI()
		local sc = wheelPanel:FindFirstChild("SpinCount")
		if sc then
			sc.Text = "Spins available: " .. State.wheelSpins
		end
		local canSpin = State.wheelSpins > 0 and not spinning and not pendingSpin
		spinBtn.BackgroundColor3 = canSpin and Color3.fromRGB(180, 100, 0) or Color3.fromRGB(60, 40, 20)
		spinBtn.Active = canSpin
	end

	-- Animate strip landing on outcomeIdx (1-based in WHEEL_OUTCOMES)
	local function playSpinAnimation(outcomeIdx, onDone)
		spinning = true
		spinBtn.Active = false
		resultLbl.Text = ""
		stripInner.Position = UDim2.new(0, 0, 0, 0)

		-- The center visible card index (0-based) is VISIBLE_CARDS // 2
		local centerCard = math.floor(VISIBLE_CARDS / 2) -- = 3

		-- We want to land so the card at 'centerCard' position in view
		-- is an outcome card matching outcomeIdx.
		-- In the second-to-last "loop" of repeats, find the matching card index (0-based)
		local targetLoop = REPEATS - 2 -- land somewhere near the end but not last loop
		-- Card index (0-based): targetLoop*NUM_OUTCOMES + (outcomeIdx - 1)
		local targetCardIdx = targetLoop * NUM_OUTCOMES + (outcomeIdx - 1)
		-- The X position where the strip should stop so targetCard is centered:
		-- stripInner.X = -(targetCardIdx * (CARD_W+CARD_GAP)) + centerCard * (CARD_W+CARD_GAP)
		local finalX = -(targetCardIdx * (CARD_W + CARD_GAP)) + centerCard * (CARD_W + CARD_GAP)

		-- Strip scrolls LEFT (X decreases). Stop several full loops BEFORE
		-- finalX so the slow tween continues leftward into the landing position.
		local loopWidth = NUM_OUTCOMES * (CARD_W + CARD_GAP)
		local fastTarget = finalX + 4 * loopWidth -- 4 loops before final landing
		-- First tween: fast linear scroll to a point before landing
		local fastTween = TweenService:Create(
			stripInner,
			TweenInfo.new(2.5, Enum.EasingStyle.Linear),
			{ Position = UDim2.new(0, fastTarget, 0, 0) }
		)
		-- Second tween: slow decelerate the remaining distance to the winning card
		local slowTween = TweenService:Create(
			stripInner,
			TweenInfo.new(1.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Position = UDim2.new(0, finalX, 0, 0) }
		)

		fastTween:Play()
		fastTween.Completed:Connect(function()
			slowTween:Play()
			slowTween.Completed:Connect(function()
				spinning = false
				if onDone then
					onDone()
				end
			end)
		end)
	end

	local wheelSpinRemote = ReplicatedStorage:WaitForChild("WheelSpin", 5)
	local wheelResultEvt = ReplicatedStorage:WaitForChild("WheelResult", 5)
	local wheelSpinsUpdateEvt = ReplicatedStorage:WaitForChild("WheelSpinsUpdate", 5)

	local function updateWheelHudBtn()
		HUD.update()
	end

	if wheelSpinsUpdateEvt then
		wheelSpinsUpdateEvt.OnClientEvent:Connect(function(newSpins, secondsUntilNext)
			State.wheelSpins = newSpins
			State.wheelCountdownSecs = secondsUntilNext or 900
			updateWheelHudBtn()
			refreshWheelUI()
		end)
	end

	if wheelResultEvt then
		wheelResultEvt.OnClientEvent:Connect(function(rewardData)
			pendingSpin = false
			local idx = rewardData.outcomeIdx or 1
			local outcome = WHEEL_OUTCOMES[idx]

			playSpinAnimation(idx, function()
				-- The server already applied the rewards; show the held-back data now
				if rewardData.buffDuration then
					State.luckBuffEnd = tick() + rewardData.buffDuration
				end
				Sync.release()
				HUD.update()

				-- Show result text
				local label = outcome and outcome.label or "???"
				resultLbl.Text = "You got: " .. label .. "!"

				-- Re-enable spin button
				refreshWheelUI()
				updateWheelHudBtn()
			end)
		end)
	end

	spinBtn.MouseButton1Click:Connect(function()
		if spinning or pendingSpin or State.wheelSpins <= 0 then
			return
		end
		if not wheelSpinRemote then
			return
		end
		State.wheelSpins -= 1
		pendingSpin = true
		refreshWheelUI()
		updateWheelHudBtn()
		Sync.hold() -- keep the reward hidden until the animation finishes
		wheelSpinRemote:FireServer()
	end)

	-- Local countdown ticker (client-side, synced from server grants)
	local lastCountdownTick = tick()
	RunService.Heartbeat:Connect(function()
		local now = tick()
		if now - lastCountdownTick >= 1 then
			lastCountdownTick = now
			if State.wheelSpins == 0 then
				State.wheelCountdownSecs = math.max(0, State.wheelCountdownSecs - 1)
			end
			updateWheelHudBtn()
			-- Update countdown label inside panel if visible
			if wheelPanel.Visible then
				local cd = wheelPanel:FindFirstChild("Countdown")
				if cd then
					local m = math.floor(State.wheelCountdownSecs / 60)
					local s = State.wheelCountdownSecs % 60
					cd.Text = string.format("Next spin in: %d:%02d", m, s)
				end
				refreshWheelUI()
			end
			-- Update luck buff label
			if tick() < State.luckBuffEnd or State.luckBuffEnd > 0 then
				HUD.update()
			end
		end
	end)

	updateWheelHudBtn()
	refreshWheelUI()
end -- do-block end

local function toggle()
	wheelPanel.Visible = not wheelPanel.Visible
end

return {
	toggle = toggle,
}
