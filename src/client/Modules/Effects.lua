-- Screen effects: wall-break rewards, floating damage numbers, big announcement text.
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

local function spawnConfetti()
	local colors = {
		Color3.fromRGB(255, 100, 180),
		Color3.fromRGB(100, 200, 255),
		Color3.fromRGB(255, 220, 80),
		Color3.fromRGB(160, 255, 130),
		Color3.fromRGB(200, 130, 255),
	}
	for _ = 1, 35 do
		local p = Instance.new("Frame")
		p.Size = UDim2.new(0, math.random(8, 18), 0, math.random(8, 18))
		p.Position = UDim2.new(math.random(10, 90) / 100, 0, -0.05, 0)
		p.Rotation = math.random(0, 360)
		p.BackgroundColor3 = colors[math.random(#colors)]
		p.BorderSizePixel = 0
		p.ZIndex = 19
		p.Parent = screenGui
		local ft = math.random(12, 22) / 10
		TweenService:Create(p, TweenInfo.new(ft, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = UDim2.new(p.Position.X.Scale, 0, math.random(80, 110) / 100, 0),
			Rotation = p.Rotation + math.random(180, 540),
		}):Play()
		game:GetService("Debris"):AddItem(p, ft + 0.1)
	end
end

local wallBreakEvt = ReplicatedStorage:WaitForChild("WallBreak", 5)
if wallBreakEvt then
	wallBreakEvt.OnClientEvent:Connect(function(goldReward, clearedLayer)
		State.gold += math.floor(goldReward * (State.goldMultiplier + State.coinBoostLevel * 0.5))
		HUD.update()
		screenShake(0.35, 0.6)
		spawnConfetti()
		showBigText(
			"🎉 WALL CLEARED!",
			"Layer " .. (clearedLayer or "?") .. " destroyed!   +" .. goldReward .. " Gold",
			Color3.fromRGB(255, 220, 80),
			Color3.fromRGB(200, 170, 255)
		)
	end)
end

local damageEvt = ReplicatedStorage:WaitForChild("DamageHit", 5)
if damageEvt then
	damageEvt.OnClientEvent:Connect(function(amount, worldPos, isGhost)
		local anchor = Instance.new("Part")
		anchor.Size = Vector3.new(0.1, 0.1, 0.1)
		anchor.Position = worldPos + Vector3.new(-4, 0, 0)
		anchor.Anchored = false
		anchor.CanCollide = false
		anchor.Transparency = 1
		anchor.Parent = workspace

		local bv = Instance.new("BodyVelocity")
		bv.Velocity = Vector3.new(math.random(-2, 2), 8, math.random(-1, 1))
		bv.MaxForce = Vector3.new(1e4, 1e4, 1e4)
		bv.P = 1e4
		bv.Parent = anchor

		local gui = Instance.new("BillboardGui", anchor)
		gui.Size = UDim2.new(0, 80, 0, 45)
		gui.AlwaysOnTop = true
		gui.LightInfluence = 0

		local lbl = Instance.new("TextLabel", gui)
		lbl.Size = UDim2.new(1, 0, 1, 0)
		lbl.BackgroundTransparency = 1
		lbl.Text = "-" .. amount
		lbl.TextScaled = true
		lbl.Font = Enum.Font.GothamBold
		lbl.TextColor3 = isGhost and Color3.fromRGB(29, 59, 255) or Color3.fromRGB(255, 64, 6)

		TweenService
			:Create(lbl, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { TextTransparency = 1 })
			:Play()
		game:GetService("Debris"):AddItem(anchor, 1)
	end)
end

return {
	showBigText = showBigText,
}
