local QuestsPanel = {}

local RunService        = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Theme = require(script.Parent.Theme)
local C = Theme.Color
local Z = 30

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
		btn.on.root.Visible = on
		btn.off.root.Visible = not on
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
	row.Name = q.id
	row.Size = UDim2.new(1, -8, 0, 116)
	row.BackgroundColor3 = C.StoneRaised
	row.BorderSizePixel = 0
	row.LayoutOrder = order
	row.ZIndex = Z + 2
	Theme.corner(row, Theme.Radius.Medium)
	Theme.stroke(row, C.Border, Theme.Stroke.Thin)

	local title = Theme.label(row, {
		text = q.label, font = "Strong", color = C.Bone,
		frameSize = UDim2.new(1, -176, 0, 28),
	})
	title.Position = UDim2.fromOffset(14, 12)
	title.ZIndex = Z + 3

	local progressLbl = Theme.label(row, {
		text = "0 / " .. fmtNum(q.target), color = C.Soul,
		frameSize = UDim2.new(1, -176, 0, 22),
	})
	progressLbl.Name = "Progress"
	progressLbl.Position = UDim2.fromOffset(14, 47)
	progressLbl.ZIndex = Z + 3

	local barBg = Instance.new("Frame", row)
	barBg.Name = "ProgressTrack"
	barBg.Size = UDim2.new(1, -176, 0, 10)
	barBg.Position = UDim2.fromOffset(14, 83)
	barBg.BackgroundColor3 = C.Void
	barBg.BorderSizePixel = 0
	barBg.ZIndex = Z + 3
	Theme.corner(barBg, Theme.Radius.Small)
	Theme.stroke(barBg, C.Border, Theme.Stroke.Thin)

	local barFill = Instance.new("Frame", barBg)
	barFill.Size = UDim2.new(0, 0, 1, 0)
	barFill.Name = "ProgressFill"
	barFill.BackgroundColor3 = C.Soul
	barFill.BorderSizePixel = 0
	barFill.ZIndex = Z + 4
	Theme.corner(barFill, Theme.Radius.Small)

	local reward = Theme.label(row, {
		text = q.reward .. " Gems", font = "Strong", color = C.Gold,
		align = Enum.TextXAlignment.Center, frameSize = UDim2.fromOffset(132, 26),
	})
	reward.Name = "Reward"
	reward.Position = UDim2.new(1, -146, 0, 14)
	reward.ZIndex = Z + 3

	-- Claim button
	local claim = Theme.stoneButton(row, {
		text = "Claim", color = "gold", size = UDim2.fromOffset(132, 36),
		position = UDim2.new(1, -146, 0, 56), zIndex = Z + 3, disabled = true,
	})
	claim.root.Name = "ClaimButton"
	local claimBtn = claim.button
	claimBtn.Visible = false

	local claimedLbl = Theme.label(row, {
		text = "Claimed", color = C.BoneDim,
		align = Enum.TextXAlignment.Center, frameSize = UDim2.fromOffset(132, 36),
	})
	claimedLbl.Position = UDim2.new(1, -146, 0, 56)
	claimedLbl.Visible = false
	claimedLbl.ZIndex = Z + 3

	return { row = row, progressLbl = progressLbl, barFill = barFill, claimBtn = claimBtn,
		claimRoot = claim.root, claimedLbl = claimedLbl }
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
		r.barFill.BackgroundColor3 = pct >= 1 and C.Soul or C.Verdigris
		r.claimRoot:SetAttribute("Disabled", claimed == true or pct < 1)
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
		r.barFill.BackgroundColor3 = pct >= 1 and C.Soul or C.Verdigris
		r.claimRoot:SetAttribute("Disabled", claimed == true or pct < 1)
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
	local themed = Theme.panel(screenGui, { title = "Quests", size = UDim2.fromOffset(620, 520), zIndex = Z })
	panel = themed.frame
	require(script.Parent.Windows).register(panel) -- only one window open at a time
	panel.Name = "QuestsPanel"
	panel.Visible = false
	local body = themed.body

	do
		resetLabel = Theme.label(body, {
			text = "Daily resets in: 00:00:00", size = "Small", color = C.BoneDim,
			align = Enum.TextXAlignment.Right, frameSize = UDim2.new(1, -306, 0, 36),
		})
		resetLabel.Position = UDim2.fromOffset(306, 0)
		resetLabel.ZIndex = Z + 3

		Theme.stoneButton(panel, {
			text = "X", color = "red", size = UDim2.fromOffset(44, 28),
			position = UDim2.new(1, -62, 0, 6), zIndex = Z + 2,
			onClick = function() panel.Visible = false end,
		})
	end

	-- ── Tabs ────────────────────────────────────────────────
	do
		local tabBar = Instance.new("Frame", body)
		tabBar.Size = UDim2.fromOffset(292, 36)
		tabBar.Position = UDim2.fromOffset(0, 0)
		tabBar.BackgroundTransparency = 1
		tabBar.ZIndex = Z + 2

		for i, name in ipairs({ "Daily", "Weekly" }) do
			local buttons = {}
			for _, state in ipairs({ "on", "off" }) do
				buttons[state] = Theme.stoneButton(tabBar, {
					text = name, color = state == "on" and "green" or "stone",
					size = UDim2.fromOffset(140, 36), position = UDim2.fromOffset((i - 1) * 148, 0),
					zIndex = Z + 3, onClick = function() switchTab(name) end,
				})
			end
			tabButtons[name] = buttons

			-- Badge
			local badge = Theme.label(tabBar, {
				text = "0", font = "Strong", size = "Small", color = C.Bone,
				align = Enum.TextXAlignment.Center, frameSize = UDim2.fromOffset(22, 22),
			})
			badge.Position = UDim2.fromOffset((i - 1) * 148 + 126, -5)
			badge.BackgroundTransparency = 0
			badge.BackgroundColor3 = C.BloodDeep
			badge.ZIndex = Z + 6
			badge.Visible = false
			badge.BorderSizePixel = 0
			Theme.corner(badge, Theme.Radius.Small)
			Theme.stroke(badge, C.Border, Theme.Stroke.Thin)
			if name == "Daily" then dailyBadge = badge else weeklyBadge = badge end

			local content = Instance.new("ScrollingFrame", body)
			content.Name = name .. "Quests"
			content.Size = UDim2.new(1, 0, 1, -50)
			content.Position = UDim2.fromOffset(0, 50)
			content.BackgroundTransparency = 1
			content.BorderSizePixel = 0
			content.ScrollBarThickness = 4
			content.ScrollBarImageColor3 = C.Border
			content.Visible = (name == "Daily")
			content.ZIndex = Z + 1
			tabContents[name] = content

			local layout = Instance.new("UIListLayout", content)
			layout.Padding = UDim.new(0, 8)
			layout.SortOrder = Enum.SortOrder.LayoutOrder
			layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
				content.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 12)
			end)

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
