-- Every client animates the real plaza wheel from the server's timestamp and landing angle.
local RunService = game:GetService("RunService")
local Rewards = require(game:GetService("ReplicatedStorage").Shared.WheelRewards)
local WorldView = require(script.Parent.WorldView)
local WheelScene = {}
local cachedModel, rotor, rest, pointer, pointerRest

function WheelScene.model()
	local model = workspace:FindFirstChild("LuckyWheel")
	local found = model and model:FindFirstChild("Rotor")
	if not found then return nil end
	if model ~= cachedModel or found ~= rotor then
		cachedModel, rotor = model, found
		rest = rotor:GetPivot()
		pointer = model:FindFirstChild("Pointer")
		pointerRest = pointer and pointer.CFrame
	end
	return model
end

function WheelScene.busy()
	local model = WheelScene.model()
	if not model then return false end
	return workspace:GetServerTimeNow() < (model:GetAttribute("SpinAt") or 0) + (model:GetAttribute("SpinDuration") or 5)
end

function WheelScene.open(gui, onFinish)
	local model = WheelScene.model()
	if not model then return nil end
	local frame = model:GetPivot()
	return WorldView.open({
		keep = { gui }, openTime = 0.8, closeTime = 0.55, fov = 48,
		goal = function()
			return CFrame.lookAt((frame * CFrame.new(3.4, 7.2, -23)).Position,
				(frame * CFrame.new(3.4, 7.2, 0)).Position)
		end,
		onFinish = onFinish,
	})
end

RunService.RenderStepped:Connect(function()
	local model = WheelScene.model()
	if not model then return end
	local from, to = model:GetAttribute("SpinFrom") or 0, model:GetAttribute("SpinTo") or 0
	local elapsed = workspace:GetServerTimeNow() - (model:GetAttribute("SpinAt") or 0)
	local duration = model:GetAttribute("SpinDuration") or 5
	local t = math.clamp(elapsed / duration, 0, 1)
	local eased = 1 - (1 - t) ^ 3
	local angle = from + (to - from) * eased
	rotor:PivotTo(rest * CFrame.Angles(0, 0, angle))
	if pointer then
		local moving = t > 0 and t < 1
		local kick = 0
		if moving then
			for _, reward in ipairs(Rewards) do
				local distance = math.abs((angle - reward.centerAngle + math.pi) % (2 * math.pi) - math.pi)
				kick = math.max(kick, math.max(0, 1 - distance / 0.14))
			end
		end
		local tickAngle = kick * math.rad(10) * (1 - t)
		pointer.CFrame = pointerRest * CFrame.Angles(0, 0, tickAngle)
	end
end)

return WheelScene
