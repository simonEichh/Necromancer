-- The Signature mark on unit names: the name of a Signature unit (Units.isSignature: a unit with its own special attack)
-- burns, an ember gradient (deep orange, gold, white-gold) slowly sweeping through the letters, with a warm dark outline.
-- Used wherever a unit's name is shown: hotbar and inventory slots, tooltips, the reveal, the star cinematic, the Forge,
-- and the nameplate over the unit in the world (found automatically for every unit model).
--
--   SignatureName.apply(textLabel, unitType)   -- burning for a Signature unit, restored to normal otherwise (or nil)
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Units = require(ReplicatedStorage.Shared.Units)

local SignatureName = {}

local EMBER = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 104, 36)),
	ColorSequenceKeypoint.new(0.3, Color3.fromRGB(255, 196, 84)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 250, 226)),
	ColorSequenceKeypoint.new(0.7, Color3.fromRGB(255, 196, 84)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 104, 36)),
})
local STROKE = Color3.fromRGB(90, 28, 0)

local active = setmetatable({}, { __mode = "k" }) -- [UIGradient] = phase

function SignatureName.apply(label, unitType)
	if not label then return end
	local on = unitType ~= nil and Units.isSignature(unitType)
	local gradient = label:FindFirstChild("SignatureShimmer")
	if on then
		if not gradient then
			-- remember how the label looked, to restore it when the slot shows a normal unit again
			label:SetAttribute("SigColor", label.TextColor3)
			label:SetAttribute("SigStroke", label.TextStrokeColor3)
			label:SetAttribute("SigStrokeT", label.TextStrokeTransparency)
			gradient = Instance.new("UIGradient")
			gradient.Name = "SignatureShimmer"
			gradient.Color = EMBER
			gradient.Rotation = 12
			gradient.Parent = label
			active[gradient] = math.random() * 2
		end
		label.TextColor3 = Color3.new(1, 1, 1) -- (the gradient tints the text)
		label.TextStrokeColor3 = STROKE
		label.TextStrokeTransparency = math.min(label:GetAttribute("SigStrokeT") or 0.3, 0.3)
	elseif gradient then
		active[gradient] = nil
		gradient:Destroy()
		label.TextColor3 = label:GetAttribute("SigColor") or label.TextColor3
		label.TextStrokeColor3 = label:GetAttribute("SigStroke") or label.TextStrokeColor3
		label.TextStrokeTransparency = label:GetAttribute("SigStrokeT") or label.TextStrokeTransparency
	end
end

-- the shimmer: the gradient sweeps through the letters, with a slight flicker like a flame
RunService.RenderStepped:Connect(function()
	local t = os.clock()
	for gradient, phase in pairs(active) do
		if gradient.Parent then
			local x = ((t * 0.45 + phase) % 2) - 1
			gradient.Offset = Vector2.new(x, math.sin(t * 7 + phase * 3) * 0.06)
		else
			active[gradient] = nil
		end
	end
end)

-- the nameplate over every unit in the world (made by the server, Army.spawnUnit: the unit's model sits inside its
-- block, which carries a BillboardGui whose first line is the unit's name)
local function decorate(model)
	if not Units.isSignature(model.Name) then return end
	local block = model.Parent
	if not (block and block:IsA("BasePart")) then return end
	local gui = block:FindFirstChildOfClass("BillboardGui")
	if not gui then return end
	for _, l in ipairs(gui:GetChildren()) do
		if l:IsA("TextLabel") and l.Text == model.Name then
			SignatureName.apply(l, model.Name)
		end
	end
end
for _, model in ipairs(CollectionService:GetTagged("ProceduralUnit")) do
	task.defer(decorate, model)
end
CollectionService:GetInstanceAddedSignal("ProceduralUnit"):Connect(function(model)
	task.delay(0.2, decorate, model) -- (the nameplate may replicate a moment later)
end)

return SignatureName
