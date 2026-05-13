local QuestsPanel = {}

local RunService        = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- ── Quest definitions (mirrors server) ───────────────────────
local DAILY_QUESTS = {
	{ id = "d_graves",   label = "Open 50 Graves",      type = "openGraves", target = 50,      reward = 15 },
	{ id = "d_playtime", label = "Play for 30 Minutes", type = "playtime",   target = 1800,    reward = 20 },
	{ id = "d_walls",    label = "Break 5 Walls",       type = "breakWalls", target = 5,       reward = 25 },
}
local WEEKLY_QUESTS = {
	{ id = "w_graves",   label = "Open 300 Graves",     type = "openGraves", target = 300,     reward = 75  },
	{ id = "w_playtime", label = "Play for 3 Hours",    type = "playtime",   target = 10800,   reward = 100 },
	{ id = "w_gold",     label = "Earn 1,000,000 Gold", type = "earnGold",   target = 1000000, reward = 125 },
}

-- ── Private state ────────────────────────────────────────────
local panel
local activeTab     = "Daily"
local tabButtons    = {}
local tabContents   = {}
local questRows     = { Daily = {}, Weekly = {} }
local dailyBadge, weeklyBadge
local resetLabel
local secsToDaily   = 86400
local secsToWeekly  = 604800

-- ── Injected deps ────────────────────────────────────────────
local claimQuestRemote, onGemsAdded

-- ── Helpers ──────────────────────────────────────────────────
local function fmtTime(secs)
	local h = math.floor(secs / 3600)
	local m = math.floor((secs % 3600) / 60)
	local s = math.floor(secs % 60)
	return string.format("%02d:%02d:%02d", h, m, s)
end

local function fmtNum(n)
	if n >= 1e6 then return string.format("%.1fm", n/1e6)
	elseif n >= 1e3 then return string.format("%.1fk", n/1e3)
	else return tostring(math.floor(n)) end
end

local function switchTab(name)
	activeTab = name
	for t, btn in pairs(tabButtons) do
		local on = (t == name)
		btn.BackgroundColor3 = on and Color3.fromRGB(90, 60, 20) or Color3.fromRGB(50, 30, 10)
		btn.TextColor3 = on and Color3.fromRGB(255, 220, 120) or Color3.fromRGB(180, 140, 80)
		tabContents[t].Visible = on
	end
	resetLabel.Text = (name == "Daily")
		and ("Daily resets in: " .. fmtTime(secsToDaily))
		or  ("Weekly resets in: " .. fmtTime(secsToWeekly))
end

local function countClaimable(questList, progress, claimed)
	local n = 0
	for _, q in ipairs(questList) do
		if not claimed[q.id] and (progress[q.id] or 0) >= q.target then
			n += 1
		end
	end
	return n
end

-- ── Build a quest row ─────────────────────────────────────────
local function makeQuestRow(parent, order, q)
	local row = Instance.new("Frame", parent)
	row.Size = UDim2.new(1, -8, 0, 110)
	row.BackgroundColor3 = Color3.fromRGB(20, 15, 10)
	row.BorderSizePixel = 0
	row.LayoutOrder = order
	row.ZIndex = 32
	Instance.new("UICorner", row).CornerRadius = UDim.new(0, 10)

	local title = Instance.new("TextLabel", row)
	title.Size = UDim2.new(1, -160, 0, 34)
	title.Position = UDim2.new(0, 12, 0, 8)
	title.BackgroundTransparency = 1
	title.Text = q.label
	title.TextColor3 = Color3.fromRGB(255, 245, 220)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextScaled = true
	title.Font = Enum.Font.GothamBold
	title.ZIndex = 33

	local progressLbl = Instance.new("TextLabel", row)
	progressLbl.Size = UDim2.new(1, -160, 0, 22)
	progressLbl.Position = UDim2.new(0, 12, 0, 42)
	progressLbl.BackgroundTransparency = 1
	progressLbl.Text = "0 / " .. fmtNum(q.target)
	progressLbl.TextColor3 = Color3.fromRGB(120, 220, 120)
	progressLbl.TextXAlignment = Enum.TextXAlignment.Left
	progressLbl.TextScaled = true
	progressLbl.Font = Enum.Font.Gotham
	progressLbl.ZIndex = 33

	local barBg = Instance.new("Frame", row)
	barBg.Size = UDim2.new(1, -160, 0, 22)
	barBg.Position = UDim2.new(0, 12, 0, 68)
	barBg.BackgroundColor3 = Color3.fromRGB(20, 50, 20)
	barBg.BorderSizePixel = 0
	barBg.ZIndex = 33
	Instance.new("UICorner", barBg).CornerRadius = UDim.new(0, 6)

	local barFill = Instance.new("Frame", barBg)
	barFill.Size = UDim2.new(0, 0, 1, 0)
	barFill.BackgroundColor3 = Color3.fromRGB(80, 220, 80)
	barFill.BorderSizePixel = 0
	barFill.ZIndex = 34
	Instance.new("UICorner", barFill).CornerRadius = UDim.new(0, 6)

	-- Claim button
	local claimBtn = Instance.new("TextButton", row)
	claimBtn.Size = UDim2.new(0, 130, 0, 70)
	claimBtn.Position = UDim2.new(1, -142, 0, 20)
	claimBtn.BackgroundColor3 = Color3.fromRGB(40, 100, 40)
	claimBtn.Text = "Claim\n💎 " .. q.reward
	claimBtn.TextColor3 = Color3.fromRGB(200, 255, 200)
	claimBtn.TextScaled = true
	claimBtn.Font = Enum.Font.GothamBold
	claimBtn.BorderSizePixel = 0
	claimBtn.Visible = false
	claimBtn.ZIndex = 33
	Instance.new("UICorner", claimBtn).CornerRadius = UDim.new(0, 10)

	local claimedLbl = Instance.new("TextLabel", row)
	claimedLbl.Size = UDim2.new(0, 130, 0, 70)
	claimedLbl.Position = UDim2.new(1, -142, 0, 20)
	claimedLbl.BackgroundTransparency = 1
	claimedLbl.Text = "✓ Claimed"
	claimedLbl.TextColor3 = Color3.fromRGB(100, 150, 100)
	claimedLbl.TextScaled = true
	claimedLbl.Font = Enum.Font.GothamBold
	claimedLbl.Visible = false
	claimedLbl.ZIndex = 33

	return { row = row, progressLbl = progressLbl, barFill = barFill, claimBtn = claimBtn, claimedLbl = claimedLbl }
end

-- ── Update display ────────────────────────────────────────────
local function refreshQuests(dailyProg, dailyClaimed, weeklyProg, weeklyClaimed)
	-- Daily rows
	for i, q in ipairs(DAILY_QUESTS) do
		local r = questRows.Daily[i]
		if not r then continue end
		local prog    = dailyProg[q.id] or 0
		local claimed = dailyClaimed[q.id]
		local pct     = math.clamp(prog / q.target, 0, 1)
		r.progressLbl.Text = fmtNum(prog) .. " / " .. fmtNum(q.target)
		r.barFill.Size = UDim2.new(pct, 0, 1, 0)
		r.barFill.BackgroundColor3 = pct >= 1 and Color3.fromRGB(80, 220, 80) or Color3.fromRGB(60, 180, 60)
		r.claimBtn.Visible    = not claimed and pct >= 1
		r.claimedLbl.Visible  = claimed
	end
	-- Weekly rows
	for i, q in ipairs(WEEKLY_QUESTS) do
		local r = questRows.Weekly[i]
		if not r then continue end
		local prog    = weeklyProg[q.id] or 0
		local claimed = weeklyClaimed[q.id]
		local pct     = math.clamp(prog / q.target, 0, 1)
		r.progressLbl.Text = fmtNum(prog) .. " / " .. fmtNum(q.target)
		r.barFill.Size = UDim2.new(pct, 0, 1, 0)
		r.barFill.BackgroundColor3 = pct >= 1 and Color3.fromRGB(80, 220, 80) or Color3.fromRGB(60, 180, 60)
		r.claimBtn.Visible    = not claimed and pct >= 1
		r.claimedLbl.Visible  = claimed
	end
	-- Badges
	local dc = countClaimable(DAILY_QUESTS,  dailyProg,  dailyClaimed)
	local wc = countClaimable(WEEKLY_QUESTS, weeklyProg, weeklyClaimed)
	dailyBadge.Text    = tostring(dc)
	dailyBadge.Visible = dc > 0
	weeklyBadge.Text   = tostring(wc)
	weeklyBadge.Visible = wc > 0
end

-- ── Public API ────────────────────────────────────────────────
function QuestsPanel.init(screenGui, deps)
	claimQuestRemote = deps.claimQuestRemote
	onGemsAdded      = deps.onGemsAdded

	-- ── Main panel ───────────────────────────────────────────
	panel = Instance.new("Frame")
	panel.Name = "QuestsPanel"
	panel.Size = UDim2.new(0, 620, 0, 520)
	panel.Position = UDim2.new(0.5, -310, 0.5, -260)
	panel.BackgroundColor3 = Color3.fromRGB(18, 12, 6)
	panel.BackgroundTransparency = 0.05
	panel.BorderSizePixel = 0
	panel.Visible = false
	panel.ZIndex = 30
	panel.Parent = screenGui
	Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 16)
	Instance.new("UIStroke", panel).Color = Color3.fromRGB(150, 100, 30)

	do
		local title = Instance.new("TextLabel", panel)
		title.Size = UDim2.new(0, 160, 0, 40)
		title.Position = UDim2.new(0, 12, 0, 8)
		title.BackgroundTransparency = 1
		title.Text = "📋 Quests"
		title.TextColor3 = Color3.fromRGB(255, 220, 100)
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.TextScaled = true
		title.Font = Enum.Font.GothamBold
		title.ZIndex = 31

		resetLabel = Instance.new("TextLabel", panel)
		resetLabel.Size = UDim2.new(1, -220, 0, 40)
		resetLabel.Position = UDim2.new(0, 180, 0, 8)
		resetLabel.BackgroundTransparency = 1
		resetLabel.Text = "Daily resets in: 00:00:00"
		resetLabel.TextColor3 = Color3.fromRGB(100, 200, 255)
		resetLabel.TextXAlignment = Enum.TextXAlignment.Left
		resetLabel.TextScaled = true
		resetLabel.Font = Enum.Font.Gotham
		resetLabel.ZIndex = 31

		local closeBtn = Instance.new("TextButton", panel)
		closeBtn.Size = UDim2.new(0, 36, 0, 36)
		closeBtn.Position = UDim2.new(1, -44, 0, 8)
		closeBtn.BackgroundColor3 = Color3.fromRGB(180, 30, 30)
		closeBtn.Text = "X"
		closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
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
	do
		local tabBar = Instance.new("Frame", panel)
		tabBar.Size = UDim2.new(1, -20, 0, 42)
		tabBar.Position = UDim2.new(0, 10, 0, 54)
		tabBar.BackgroundTransparency = 1
		tabBar.ZIndex = 31

		for i, name in ipairs({ "Daily", "Weekly" }) do
			local btn = Instance.new("TextButton", tabBar)
			btn.Size = UDim2.new(0, 140, 1, 0)
			btn.Position = UDim2.new(0, (i-1) * 148, 0, 0)
			btn.BackgroundColor3 = Color3.fromRGB(50, 30, 10)
			btn.Text = name
			btn.TextColor3 = Color3.fromRGB(180, 140, 80)
			btn.TextScaled = true
			btn.Font = Enum.Font.GothamBold
			btn.BorderSizePixel = 0
			btn.ZIndex = 32
			Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
			tabButtons[name] = btn

			-- Badge
			local badge = Instance.new("TextLabel", btn)
			badge.Size = UDim2.new(0, 22, 0, 22)
			badge.Position = UDim2.new(1, -8, 0, -8)
			badge.BackgroundColor3 = Color3.fromRGB(200, 30, 30)
			badge.Text = "0"
			badge.TextColor3 = Color3.fromRGB(255, 255, 255)
			badge.TextScaled = true
			badge.Font = Enum.Font.GothamBold
			badge.ZIndex = 34
			badge.Visible = false
			badge.BorderSizePixel = 0
			Instance.new("UICorner", badge).CornerRadius = UDim.new(0.5, 0)
			if name == "Daily" then dailyBadge = badge else weeklyBadge = badge end

			local content = Instance.new("ScrollingFrame", panel)
			content.Size = UDim2.new(1, -20, 1, -106)
			content.Position = UDim2.new(0, 10, 0, 102)
			content.BackgroundTransparency = 1
			content.BorderSizePixel = 0
			content.ScrollBarThickness = 4
			content.ScrollBarImageColor3 = Color3.fromRGB(150, 100, 30)
			content.Visible = (name == "Daily")
			content.ZIndex = 31
			content.Parent = panel
			tabContents[name] = content

			local layout = Instance.new("UIListLayout", content)
			layout.Padding = UDim.new(0, 8)
			layout.SortOrder = Enum.SortOrder.LayoutOrder
			layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
				content.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 12)
			end)

			btn.MouseButton1Click:Connect(function() switchTab(name) end)
		end
		switchTab("Daily")
	end

	-- ── Quest rows ───────────────────────────────────────────
	for i, q in ipairs(DAILY_QUESTS) do
		local r = makeQuestRow(tabContents["Daily"], i, q)
		questRows.Daily[i] = r
		local questId = q.id
		r.claimBtn.MouseButton1Click:Connect(function()
			claimQuestRemote:FireServer(questId, false)
		end)
	end
	for i, q in ipairs(WEEKLY_QUESTS) do
		local r = makeQuestRow(tabContents["Weekly"], i, q)
		questRows.Weekly[i] = r
		local questId = q.id
		r.claimBtn.MouseButton1Click:Connect(function()
			claimQuestRemote:FireServer(questId, true)
		end)
	end

	-- ── Remote listeners ─────────────────────────────────────
	local questUpdateEvt = ReplicatedStorage:WaitForChild("QuestUpdate", 5)
	if questUpdateEvt then
		questUpdateEvt.OnClientEvent:Connect(function(dp, dc, wp, wc, sToDaily, sToWeekly)
			secsToDaily   = sToDaily
			secsToWeekly  = sToWeekly
			refreshQuests(dp, dc, wp, wc)
		end)
	end

	local addGemsEvt = ReplicatedStorage:WaitForChild("AddGems", 5)
	if addGemsEvt then
		addGemsEvt.OnClientEvent:Connect(function(amount)
			onGemsAdded(amount)
		end)
	end

	-- ── Countdown heartbeat ──────────────────────────────────
	RunService.Heartbeat:Connect(function(dt)
		if not panel.Visible then return end
		secsToDaily  = math.max(0, secsToDaily  - dt)
		secsToWeekly = math.max(0, secsToWeekly - dt)
		resetLabel.Text = (activeTab == "Daily")
			and ("Daily resets in: "  .. fmtTime(secsToDaily))
			or  ("Weekly resets in: " .. fmtTime(secsToWeekly))
	end)
end

function QuestsPanel.show()
	panel.Visible = not panel.Visible
end

return QuestsPanel
