-- Place Best button and placing a carried unit on a grave.
-- The server owns the inventory and the graves; these only send requests.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local screenGui = require(script.Parent.Gui)
local State = require(script.Parent.State)

-- ── Place Best button (top-center, just below HUD) ────────────
local Theme = require(script.Parent.Theme)
local placeBest = Theme.stoneButton(screenGui, {
	text = "Place Best", color = "gold", size = UDim2.fromOffset(180, 40),
	position = UDim2.new(0.5, -90, 0, 78), zIndex = 10,
})
placeBest.root.Name = "PlaceBestBtn"
local placeBestBtn = placeBest.button

local placeBestRemote = ReplicatedStorage:WaitForChild("PlaceBest", 5)

placeBestBtn.Activated:Connect(function()
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
