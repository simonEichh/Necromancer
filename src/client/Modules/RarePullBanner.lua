-- The server-wide banner for a chase pull: when anyone pulls a Signature or a Sovereign (server Digging fires
-- RarePull to every client), the others see a banner slide down at the top of the screen for a few seconds:
--   NAME SUMMONED
--   MALAK, THE ENVOY
--   SOVEREIGN  -  1 IN 50,000,000
-- The puller gets nothing here (they have the pull cinematic). Several pulls queue up and show one after another.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Units = require(ReplicatedStorage.Shared.Units)
local Theme = require(script.Parent.Theme)
local screenGui = require(script.Parent.Gui)

local player = Players.LocalPlayer

local SHOW_TIME = 6
local SOVEREIGN_COLOR = Color3.fromRGB(200, 170, 255)

-- "DeathIncarnate" -> "DEATH INCARNATE"
local function displayName(unitType)
	return (unitType:gsub("(%l)(%u)", "%1 %2")):upper()
end
-- 50000000 -> "50,000,000"
local function grouped(n)
	local s = tostring(math.floor(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end

-- ============================================================
-- The banner
-- ============================================================
local root = Instance.new("Frame")
root.Name = "RarePullBanner"
root.AnchorPoint = Vector2.new(0.5, 1)
root.Position = UDim2.new(0.5, 0, 0, -10)
root.Size = UDim2.fromOffset(460, 96)
root.BackgroundColor3 = Theme.Color.Void
root.BackgroundTransparency = 0.12
root.Visible = false
root.ZIndex = 50
root.Parent = screenGui
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, Theme.Radius.Medium)
corner.Parent = root
local stroke = Instance.new("UIStroke")
stroke.Thickness = Theme.Stroke.Frame
stroke.Color = SOVEREIGN_COLOR
stroke.Parent = root
local sizeLimit = Instance.new("UISizeConstraint")
sizeLimit.MaxSize = Vector2.new(460, 96)
sizeLimit.Parent = root

local function label(y, h, font, color)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Position = UDim2.new(0, 12, 0, y)
	l.Size = UDim2.new(1, -24, 0, h)
	l.Font = font
	l.TextScaled = true
	l.TextColor3 = color
	l.TextStrokeTransparency = 0.6
	l.ZIndex = 51
	l.Parent = root
	return l
end
local whoLbl = label(8, 18, Theme.Font.Body, Theme.Color.BoneDim)
local unitLbl = label(28, 36, Theme.Font.Title, SOVEREIGN_COLOR)
local infoLbl = label(68, 18, Theme.Font.Body, Theme.Color.Bone)

-- ============================================================
-- The queue
-- ============================================================
local queue = {}
local showing = false

local function showNext()
	local data = table.remove(queue, 1)
	if not data then
		showing = false
		return
	end
	showing = true
	local sovereign = Units.isSovereign(data.unitType)
	local color = sovereign and SOVEREIGN_COLOR or Units.SIGNATURE_COLOR
	local def = Units.Stats[data.unitType]
	local title = def and def.title
	whoLbl.Text = string.upper(tostring(data.name)) .. " SUMMONED"
	unitLbl.Text = displayName(data.unitType) .. (title and (", " .. string.upper(title)) or "")
	unitLbl.TextColor3 = color
	stroke.Color = color
	infoLbl.Text = (sovereign and "SOVEREIGN" or "SIGNATURE") .. "  -  1 IN " .. grouped(data.oneIn or 0)

	root.Position = UDim2.new(0.5, 0, 0, -10)
	root.Visible = true
	local inInfo = TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	TweenService:Create(root, inInfo, { Position = UDim2.new(0.5, 0, 0, 110) }):Play()
	task.delay(SHOW_TIME, function()
		local out = TweenService:Create(root, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = UDim2.new(0.5, 0, 0, -10) })
		out:Play()
		out.Completed:Wait()
		root.Visible = false
		task.wait(0.3)
		showNext()
	end)
end

local remote = ReplicatedStorage:WaitForChild("RarePull", 10)
if remote then
	remote.OnClientEvent:Connect(function(data)
		if type(data) ~= "table" or type(data.unitType) ~= "string" then
			return
		end
		if data.userId == player.UserId then
			return -- (the puller has the cinematic)
		end
		table.insert(queue, data)
		if not showing then
			showNext()
		end
	end)
end

return {}
