-- Small client-side animations of world decoration (the server never moves these parts).
-- Models tagged "SpinFx" (with a PrimaryPart and the attribute SpinSpeed in rad/s) turn forever around their PrimaryPart's
-- up axis, e.g. the two magic circle layers above the Forge anvil (tools/studio/build_forge_stall.lua). Such models must
-- use ModelStreamingMode Atomic, otherwise a part streamed in later would keep its unrotated server position.
-- WorldFx.pause(model, true) hands a spinner over to another script (the Forge view moves the Forge's circles itself);
-- WorldFx.baseOf(model) is its resting pivot.
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local MAX_DISTANCE = 220 -- do not animate spinners farther away than this from the camera

local WorldFx = {}
local spinners = {} -- [model] = { base = CFrame, speed = number, paused = bool }

local function add(model)
	if not model:IsA("Model") then
		return
	end
	if not model.PrimaryPart then
		-- with StreamingEnabled the model can arrive before its parts: wait for the PrimaryPart
		local conn
		conn = model:GetPropertyChangedSignal("PrimaryPart"):Connect(function()
			if model.PrimaryPart then
				conn:Disconnect()
				add(model)
			end
		end)
		return
	end
	spinners[model] = { base = model:GetPivot(), speed = model:GetAttribute("SpinSpeed") or 0.5 }
end

for _, model in ipairs(CollectionService:GetTagged("SpinFx")) do
	add(model)
end
CollectionService:GetInstanceAddedSignal("SpinFx"):Connect(add)
CollectionService:GetInstanceRemovedSignal("SpinFx"):Connect(function(model)
	spinners[model] = nil
end)

RunService.RenderStepped:Connect(function()
	local camera = workspace.CurrentCamera
	local camPos = camera and camera.CFrame.Position
	local t = os.clock()
	for model, s in pairs(spinners) do
		if not model.Parent then
			spinners[model] = nil
		elseif s.paused then
			continue
		elseif not camPos or (s.base.Position - camPos).Magnitude < MAX_DISTANCE then
			model:PivotTo(s.base * CFrame.Angles(0, (t * s.speed) % (2 * math.pi), 0))
		end
	end
end)

function WorldFx.pause(model, paused)
	local s = spinners[model]
	if s then
		s.paused = paused
	end
end

function WorldFx.baseOf(model)
	local s = spinners[model]
	return s and s.base
end

return WorldFx
