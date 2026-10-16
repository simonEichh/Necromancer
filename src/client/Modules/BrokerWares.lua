-- The Soul Broker's wares on his counter (Design.md "The Soul Broker"): the Gem Shop's items you buy again and again as
-- real objects (build_broker_stall.lua: models "Ware_<key>" with the attribute Ware and an invisible "Hit" part with a
-- ClickDetector; the two catalyst jars for now). Hovering one outlines it in gold; a click calls
-- `BrokerWares.onPick(key)` (set by BrokerKeeper: opens the stall view and selects that item's card).
-- Builds itself when required (no init call).
local BrokerWares = {}

local GOLD = Color3.fromRGB(255, 214, 140)
local hooked = {} -- [ClickDetector] = true

local function hook(model)
	local key = model:GetAttribute("Ware")
	local hit = model:FindFirstChild("Hit")
	local cd = hit and hit:FindFirstChildOfClass("ClickDetector")
	if not (key and cd) or hooked[cd] then return end
	hooked[cd] = true
	local outline = Instance.new("Highlight")
	outline.Adornee = model
	outline.FillTransparency = 0.85
	outline.FillColor = GOLD
	outline.OutlineColor = GOLD
	outline.DepthMode = Enum.HighlightDepthMode.Occluded
	outline.Enabled = false
	outline.Parent = model
	cd.MouseHoverEnter:Connect(function() outline.Enabled = true end)
	cd.MouseHoverLeave:Connect(function() outline.Enabled = false end)
	cd.MouseClick:Connect(function()
		if BrokerWares.onPick then BrokerWares.onPick(key) end
	end)
end

local function scan()
	local decor = workspace:FindFirstChild("HubDecor")
	local stall = decor and decor:FindFirstChild("Stall_SoulBroker")
	if not stall then return end
	for _, c in ipairs(stall:GetChildren()) do
		if c:IsA("Model") and c:GetAttribute("Ware") then hook(c) end
	end
end

task.spawn(function()
	local decor = workspace:WaitForChild("HubDecor", 60)
	if not decor then return end
	local stall = decor:WaitForChild("Stall_SoulBroker", 60)
	if stall then stall:WaitForChild("Ware_Fortune", 30) end
	scan()
	decor.DescendantAdded:Connect(function(d)
		if d:IsA("ClickDetector") then task.defer(scan) end
	end)
end)

return BrokerWares
