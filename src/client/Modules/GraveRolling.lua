-- Opening graves: the roll animation popup, auto-roll chain and the RollResult handler.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local screenGui = require(script.Parent.Gui)
local State = require(script.Parent.State)
local Toolbar = require(script.Parent.Toolbar)
local GravesDock = require(script.Parent.GravesDock)
local ShopPanel = require(script.Parent.ShopPanel)
local GameData = require(script.Parent.GameData)
local UNIT_INFO = GameData.UNIT_INFO
local UNIT_ONE_IN = GameData.UNIT_ONE_IN
local RARITY_COLORS = GameData.RARITY_COLORS
local ALL_UNIT_KEYS = GameData.ALL_UNIT_KEYS
local Sync = require(script.Parent.Sync)

local activeRollPopup = nil
local isRolling = false
local autoRollActive = false
local currentRollGraveType = nil
local skipCycling = false

local function playRollAnimation(unitType, rarity, pity, oneIn)
	if activeRollPopup and activeRollPopup.Parent then
		activeRollPopup:Destroy()
		activeRollPopup = nil
	end
	skipCycling = false

	-- Backdrop (taller to fit buttons)
	local backdrop = Instance.new("Frame", screenGui)
	backdrop.Size = UDim2.new(0, 480, 0, 290)
	backdrop.Position = UDim2.new(0.5, -240, 0.35, -145)
	backdrop.BackgroundColor3 = Color3.fromRGB(12, 5, 30)
	backdrop.BackgroundTransparency = 0.1
	backdrop.BorderSizePixel = 0
	backdrop.ZIndex = 40
	Instance.new("UICorner", backdrop).CornerRadius = UDim.new(0, 16)
	activeRollPopup = backdrop

	local rollingLbl = Instance.new("TextLabel", backdrop)
	rollingLbl.Size = UDim2.new(1, -20, 0, 90)
	rollingLbl.Position = UDim2.new(0, 10, 0, 10)
	rollingLbl.BackgroundTransparency = 1
	rollingLbl.TextScaled = true
	rollingLbl.Font = Enum.Font.GothamBold
	rollingLbl.ZIndex = 41

	local subLbl = Instance.new("TextLabel", backdrop)
	subLbl.Size = UDim2.new(1, -20, 0, 60)
	subLbl.Position = UDim2.new(0, 10, 0, 108)
	subLbl.BackgroundTransparency = 1
	subLbl.TextColor3 = Color3.fromRGB(170, 150, 210)
	subLbl.TextScaled = false
	subLbl.TextSize = 19
	subLbl.TextWrapped = true
	subLbl.Font = Enum.Font.Gotham
	subLbl.ZIndex = 41

	-- ── Buttons ──────────────────────────────────────────────
	local skipBtn = Instance.new("TextButton", backdrop)
	skipBtn.Size = UDim2.new(0.44, -8, 0, 58)
	skipBtn.Position = UDim2.new(0, 10, 1, -68)
	skipBtn.BackgroundColor3 = Color3.fromRGB(40, 20, 80)
	skipBtn.Text = "⏭  Skip"
	skipBtn.TextColor3 = Color3.fromRGB(200, 180, 255)
	skipBtn.TextScaled = true
	skipBtn.Font = Enum.Font.GothamBold
	skipBtn.BorderSizePixel = 0
	skipBtn.ZIndex = 42
	Instance.new("UICorner", skipBtn).CornerRadius = UDim.new(0, 12)

	local autoBtn = Instance.new("TextButton", backdrop)
	autoBtn.Size = UDim2.new(0.56, -12, 0, 58)
	autoBtn.Position = UDim2.new(0.44, 2, 1, -68)
	autoBtn.TextScaled = true
	autoBtn.Font = Enum.Font.GothamBold
	autoBtn.BorderSizePixel = 0
	autoBtn.ZIndex = 42
	Instance.new("UICorner", autoBtn).CornerRadius = UDim.new(0, 12)

	local function updateAutoBtn()
		autoBtn.Text = autoRollActive and "⟳  Auto Roll  ON" or "⟳  Auto Roll  OFF"
		autoBtn.BackgroundColor3 = autoRollActive and Color3.fromRGB(20, 110, 40) or Color3.fromRGB(40, 20, 70)
		autoBtn.TextColor3 = autoRollActive and Color3.fromRGB(140, 255, 140) or Color3.fromRGB(180, 150, 220)
	end
	updateAutoBtn()
	autoBtn.MouseButton1Click:Connect(function()
		autoRollActive = not autoRollActive
		updateAutoBtn()
	end)

	-- Fade in
	backdrop.Size = UDim2.new(0, 120, 0, 50)
	backdrop.Position = UDim2.new(0.5, -60, 0.35, -25)
	TweenService:Create(
		backdrop,
		TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Size = UDim2.new(0, 480, 0, 290), Position = UDim2.new(0.5, -240, 0.35, -145) }
	):Play()

	-- ── Close / auto-roll-next helper ────────────────────────
	local function closeAndContinue()
		local gt = currentRollGraveType
		backdrop:Destroy()
		if activeRollPopup == backdrop then
			activeRollPopup = nil
		end
		if autoRollActive and gt and (State.ownedGraves[gt] or 0) > 0 then
			-- Fire next roll in the chain (the server uses up the grave)
			Sync.hold()
			local remote = ReplicatedStorage:FindFirstChild("DigGrave")
			if remote then
				remote:FireServer(gt)
			end
			-- isRolling stays true; next RollResult restarts playRollAnimation
		else
			isRolling = false
			autoRollActive = false
		end
	end

	-- ── Result reveal ─────────────────────────────────────────
	local resultShown = false
	local function showResult()
		if resultShown then
			return
		end
		resultShown = true
		skipCycling = false

		local info = UNIT_INFO[unitType] or {}
		local rc = RARITY_COLORS[rarity] or Color3.fromRGB(255, 255, 255)
		rollingLbl.Text = (info.emoji or "❓") .. "  " .. unitType
		rollingLbl.TextColor3 = rc
		subLbl.TextColor3 = rc
		subLbl.Text = rarity:upper()
			.. "   •   1 in "
			.. (oneIn or UNIT_ONE_IN[unitType] or "?")
			.. "   (Pity: "
			.. (pity or 0)
			.. " / 60)"

		-- The server already stored the unit; show the data it held back until now
		Sync.release()

		-- Skip becomes Close
		skipBtn.Text = "X  Close"
		skipBtn.BackgroundColor3 = Color3.fromRGB(80, 20, 20)
		skipBtn.TextColor3 = Color3.fromRGB(255, 150, 150)

		if autoRollActive then
			-- Auto-proceed quickly
			task.delay(0.6, function()
				if backdrop.Parent then
					closeAndContinue()
				end
			end)
		end
	end

	-- ── Skip button ───────────────────────────────────────────
	skipBtn.MouseButton1Click:Connect(function()
		if not resultShown then
			skipCycling = true -- cycling loop will call showResult next tick
		else
			closeAndContinue() -- continue auto roll chain (or just close if auto roll is off)
		end
	end)

	-- ── Cycling animation ─────────────────────────────────────
	local cycles = 0
	local MAX_CYCLES = 16

	local function tick()
		if not backdrop.Parent then
			return
		end
		if cycles >= MAX_CYCLES or skipCycling then
			showResult()
			return
		end
		cycles += 1
		local rand = ALL_UNIT_KEYS[math.random(#ALL_UNIT_KEYS)]
		local info = UNIT_INFO[rand] or {}
		rollingLbl.Text = (info.emoji or "❓") .. "  " .. rand
		rollingLbl.TextColor3 = RARITY_COLORS[info.rarity] or Color3.fromRGB(220, 200, 255)
		subLbl.TextColor3 = Color3.fromRGB(170, 150, 210)
		subLbl.Text = (info.rarity or "?") .. "   •   1 in " .. (UNIT_ONE_IN[rand] or "?")
		local delay = 0.06 + (cycles / MAX_CYCLES) * 0.22
		task.delay(delay, tick)
	end

	tick()
end

local function openGrave(graveType)
	if isRolling then
		return
	end -- locked while animation is active
	if ShopPanel.isGraveLocked(graveType) then
		return
	end
	if (State.ownedGraves[graveType] or 0) <= 0 then
		return
	end

	-- Check for inventory space
	local hasSpace = false
	for i = 1, 10 do
		if State.inventory[i] == nil then
			hasSpace = true
			break
		end
	end
	if not hasSpace then
		local warn = Instance.new("TextLabel", screenGui)
		warn.Size = UDim2.new(0, 260, 0, 40)
		warn.Position = UDim2.new(0.5, -130, 1, -310)
		warn.BackgroundColor3 = Color3.fromRGB(120, 30, 30)
		warn.BackgroundTransparency = 0.2
		warn.Text = "⚠️ Inventory full!"
		warn.TextColor3 = Color3.fromRGB(255, 180, 180)
		warn.TextScaled = true
		warn.Font = Enum.Font.GothamBold
		warn.ZIndex = 50
		warn.BorderSizePixel = 0
		Instance.new("UICorner", warn).CornerRadius = UDim.new(0, 8)
		game:GetService("Debris"):AddItem(warn, 2)
		return
	end

	-- Lock and track grave type for auto-roll chain
	isRolling = true
	currentRollGraveType = graveType
	autoRollActive = false -- always start a fresh session with auto roll off

	-- The server uses up the grave and rolls; hold its data update back until the reveal
	Sync.hold()
	local remote = ReplicatedStorage:FindFirstChild("DigGrave")
	if remote then
		remote:FireServer(graveType)
	end
end

local rollResultEvt = ReplicatedStorage:WaitForChild("RollResult", 5)
if rollResultEvt then
	rollResultEvt.OnClientEvent:Connect(function(unitType, rarity, pity, oneIn)
		playRollAnimation(unitType, rarity, pity, oneIn)
	end)
end

-- The server refused the dig (no grave owned / inventory full): unlock and show the real data
local digRejectedEvt = ReplicatedStorage:WaitForChild("DigRejected", 5)
if digRejectedEvt then
	digRejectedEvt.OnClientEvent:Connect(function()
		isRolling = false
		autoRollActive = false
		Sync.release()
	end)
end

return {
	openGrave = openGrave,
}
