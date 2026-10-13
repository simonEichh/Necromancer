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

local GachaReveal = require(script.Parent.GachaReveal)
local StarSummon = require(script.Parent.StarSummon)
local GraveCinematic = require(script.Parent.GraveCinematic)
local Rarities = require(ReplicatedStorage.Shared.Rarities)
local Units = require(ReplicatedStorage.Shared.Units)
local Economy = require(ReplicatedStorage.Shared.Economy)

-- Pulls whose best result has at least this rarity rank (5 = Legendary) play the star summon cinematic first; the
-- overlay then shows the result (Collect, odds, the results grid). Lower pulls keep the short overlay show.
local STAR_MIN_RANK = 5

local isRolling = false
local autoRollActive = false
local currentRollGraveType = nil
local openGrave -- forward declared: the reveal's "Open x10" button calls it

-- Shows the reveal for the server's results (a list: one entry per grave opened)
local function playRollAnimation(results)
	local graveType = currentRollGraveType
	local function showOverlay(skipShow)
		GachaReveal.play(results, {
			graveType = graveType,
			skipShow = skipShow,
			autoRoll = function() return autoRollActive end,
			setAuto = function(on) autoRollActive = on end,
			ownedLeft = function() return graveType and State.ownedGraves[graveType] or 0 end,
			openMore = function(count) openGrave(graveType, count) end,
			onRevealed = function()
				-- The server already stored the units; show the data it held back until now
				Sync.release()
			end,
			onClose = function()
				if autoRollActive and graveType and (State.ownedGraves[graveType] or 0) > 0 and #results == 1 then
					-- auto roll: open the next one right away (the server uses up the grave)
					Sync.hold()
					local remote = ReplicatedStorage:FindFirstChild("DigGrave")
					if remote then
						remote:FireServer(graveType, 1)
					end
					-- isRolling stays true; the next RollResult plays the next reveal
				else
					isRolling = false
					autoRollActive = false
				end
			end,
		})
	end

	local bestRank = 0
	for _, r in ipairs(results) do
		bestRank = math.max(bestRank, Rarities.Rank[r.rarity] or 0)
	end
	-- Signature units always get the cinematic (when one of them is the best pull)
	local signatureBest = false
	for _, r in ipairs(results) do
		if (Rarities.Rank[r.rarity] or 0) == bestRank and Units.isSignature(r.unitType) then
			signatureBest = true
		end
	end
	if bestRank >= STAR_MIN_RANK or signatureBest then
		-- a rare pull: the cinematic first (the data update stays held back), then the result in the overlay
		local ok = pcall(StarSummon.play, results, {
			graveType = graveType, -- the star crashes into this grave's real model (when it has one), which then bursts
			onDone = function()
				showOverlay(true)
			end,
		})
		if not ok then
			showOverlay(false)
		end
	elseif not autoRollActive then
		-- opened by hand: the grave cinematic in the world (the best unit rises out of the real grave), then the result;
		-- graves without a 3D model, or when it cannot play, keep the overlay's short show. Auto Roll always uses the overlay.
		local okCall, started = pcall(GraveCinematic.play, results, {
			graveType = graveType,
			onDone = function()
				showOverlay(true)
			end,
		})
		if not (okCall and started) then
			showOverlay(false)
		end
	else
		showOverlay(false)
	end
end

openGrave = function(graveType, count)
	count = count or 1
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
	for i = 1, Economy.INVENTORY_MAX do -- the whole inventory (the server is the real judge)
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
		warn.Text = "Inventory full!"
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
		remote:FireServer(graveType, count)
	end
end

local rollResultEvt = ReplicatedStorage:WaitForChild("RollResult", 5)
if rollResultEvt then
	rollResultEvt.OnClientEvent:Connect(function(results)
		playRollAnimation(results)
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
