-- Place Best button and placing a carried unit on a grave.
-- The server owns the inventory and the graves; these only send requests.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local screenGui = require(script.Parent.Gui)
local State = require(script.Parent.State)

-- ── Place Best button (top-center, just below HUD) ────────────
local placeBestBtn = Instance.new("TextButton")
placeBestBtn.Name = "PlaceBestBtn"
placeBestBtn.Size = UDim2.new(0, 170, 0, 36)
placeBestBtn.Position = UDim2.new(0.5, -85, 0, 72)
placeBestBtn.BackgroundColor3 = Color3.fromRGB(130, 25, 25)
placeBestBtn.Text = "Place Best"
placeBestBtn.TextColor3 = Color3.fromRGB(255, 210, 210)
placeBestBtn.TextScaled = true
placeBestBtn.Font = Enum.Font.GothamBold
placeBestBtn.BorderSizePixel = 0
placeBestBtn.ZIndex = 10
Instance.new("UICorner", placeBestBtn).CornerRadius = UDim.new(0, 10)
placeBestBtn.Parent = screenGui

local placeBestRemote = ReplicatedStorage:WaitForChild("PlaceBest", 5)

placeBestBtn.MouseButton1Click:Connect(function()
	if placeBestRemote then
		placeBestRemote:FireServer() -- the server picks the best units from its own inventory
	end
end)

-- ── Grave placement (E on a physical grave in the world) ──────
local selectGraveEvt = ReplicatedStorage:WaitForChild("SelectGrave", 5)
local placeAtGraveRemote = ReplicatedStorage:WaitForChild("PlaceAtGrave", 5)

if selectGraveEvt then
	selectGraveEvt.OnClientEvent:Connect(function(_gravePos, slotIndex)
		if not State.inventory[State.selectedSlot] then
			return -- nothing selected
		end
		if placeAtGraveRemote then
			placeAtGraveRemote:FireServer(State.selectedSlot, slotIndex)
		end
	end)
end

return {}
