-- Shared potion control for the wheel and both grave views; all consumption is server-authoritative.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Theme = require(script.Parent.Theme)
local State = require(script.Parent.State)
local usePotion = ReplicatedStorage:WaitForChild("UseLuckPotion")

local LuckPotionButton = {}

function LuckPotionButton.create(parent, props)
	local pendingUntil = 0
	local button = Theme.stoneButton(parent, {
		text = "Luck Potions: 0", color = "green", size = props.size, position = props.position,
		anchor = props.anchor, zIndex = props.zIndex,
		onClick = function()
			if State.luckPotions < 1 or os.clock() < pendingUntil then return end
			pendingUntil = os.clock() + 0.75
			usePotion:FireServer()
		end,
	})
	button.root.Name = "UseLuckPotion"
	button.label.TextScaled = true
	local function refresh()
		local remaining = math.max(0, math.ceil(State.luckBuffEnd - workspace:GetServerTimeNow()))
		local timer = string.format("%d:%02d", math.floor(remaining / 60), remaining % 60)
		button.label.Text = remaining > 0 and ("2x Luck " .. timer .. " | +5m (" .. State.luckPotions .. ")")
			or ("Use Luck Potion (" .. State.luckPotions .. ")")
		button.root:SetAttribute("Disabled", State.luckPotions < 1 or os.clock() < pendingUntil)
	end
	refresh()
	local elapsed = 0
	local connection
	connection = RunService.Heartbeat:Connect(function(dt)
		if not button.root.Parent then connection:Disconnect() return end
		elapsed += dt
		if elapsed >= 0.25 then elapsed = 0 refresh() end
	end)
	return button
end

return LuckPotionButton
