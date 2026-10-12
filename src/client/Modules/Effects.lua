-- Screen effects: wall-break rewards, big announcement text. (Wall hit flashes: HitEffects.)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local screenGui = require(script.Parent.Gui)
local State = require(script.Parent.State)
local HUD = require(script.Parent.HUD)

local camera = workspace.CurrentCamera

local function screenShake(intensity, duration)
	local elapsed = 0
	local conn
	conn = RunService.RenderStepped:Connect(function(dt)
		elapsed += dt
		if elapsed >= duration then
			conn:Disconnect()
			return
		end
		local fade = 1 - (elapsed / duration)
		camera.CFrame = camera.CFrame
			* CFrame.new(
				math.random(-100, 100) / 100 * intensity * fade,
				math.random(-100, 100) / 100 * intensity * fade,
				0
			)
	end)
end

local function showBigText(line1, line2, color1, color2)
	local bd = Instance.new("Frame")
	bd.Size = UDim2.new(0, 500, 0, 160)
	bd.Position = UDim2.new(0.5, -250, 0.35, -80)
	bd.BackgroundColor3 = Color3.fromRGB(15, 5, 35)
	bd.BackgroundTransparency = 0.2
	bd.BorderSizePixel = 0
	bd.ZIndex = 20
	Instance.new("UICorner", bd).CornerRadius = UDim.new(0, 18)
	bd.Parent = screenGui

	local top = Instance.new("TextLabel", bd)
	top.Size = UDim2.new(1, 0, 0.55, 0)
	top.BackgroundTransparency = 1
	top.Text = line1
	top.TextColor3 = color1
	top.TextScaled = true
	top.Font = Enum.Font.GothamBold
	top.ZIndex = 21

	local bot = Instance.new("TextLabel", bd)
	bot.Size = UDim2.new(1, 0, 0.45, 0)
	bot.Position = UDim2.new(0, 0, 0.55, 0)
	bot.BackgroundTransparency = 1
	bot.Text = line2
	bot.TextColor3 = color2
	bot.TextScaled = true
	bot.Font = Enum.Font.Gotham
	bot.ZIndex = 21

	bd.Size = UDim2.new(0, 100, 0, 40)
	bd.Position = UDim2.new(0.5, -50, 0.35, -20)
	TweenService:Create(
		bd,
		TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Size = UDim2.new(0, 500, 0, 160), Position = UDim2.new(0.5, -250, 0.35, -80) }
	):Play()

	task.delay(2.2, function()
		TweenService:Create(bd, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
		TweenService:Create(top, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
		TweenService:Create(bot, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
		task.delay(0.45, function()
			bd:Destroy()
		end)
	end)
end

local wallBreakEvt = ReplicatedStorage:WaitForChild("WallBreak", 5)
if wallBreakEvt then
	-- no banner or confetti (it fires every few seconds once the army is strong): just a light shake
	wallBreakEvt.OnClientEvent:Connect(function()
		screenShake(0.15, 0.3)
	end)
end

-- Short red banner for messages from the server (e.g. "Inventory full")
local noticeEvt = ReplicatedStorage:WaitForChild("Notice", 5)
if noticeEvt then
	noticeEvt.OnClientEvent:Connect(function(text)
		local banner = Instance.new("TextLabel", screenGui)
		banner.Size = UDim2.new(0, 340, 0, 40)
		banner.Position = UDim2.new(0.5, -170, 1, -200)
		banner.BackgroundColor3 = Color3.fromRGB(120, 30, 30)
		banner.BackgroundTransparency = 0.2
		banner.Text = tostring(text)
		banner.TextColor3 = Color3.fromRGB(255, 180, 180)
		banner.TextScaled = true
		banner.Font = Enum.Font.GothamBold
		banner.ZIndex = 50
		banner.BorderSizePixel = 0
		Instance.new("UICorner", banner).CornerRadius = UDim.new(0, 8)
		game:GetService("Debris"):AddItem(banner, 2.5)
	end)
end

return {
	showBigText = showBigText,
}
