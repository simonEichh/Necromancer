-- Place Best button, placing a carried unit on a grave, and recalling units back to the inventory.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local screenGui = require(script.Parent.Gui)
local State = require(script.Parent.State)
local Toolbar = require(script.Parent.Toolbar)
local InventoryPanel = require(script.Parent.InventoryPanel)
local GameData = require(script.Parent.GameData)
local UNIT_ONE_IN = GameData.UNIT_ONE_IN
local refreshToolbar = Toolbar.refresh
local updateCarriedUnit = Toolbar.updateCarried
local addToInventory = Toolbar.add

-- ── Place Best button (top-center, just below HUD) ────────────
local placeBestBtn = Instance.new("TextButton")
placeBestBtn.Name = "PlaceBestBtn"
placeBestBtn.Size = UDim2.new(0, 170, 0, 36)
placeBestBtn.Position = UDim2.new(0.5, -85, 0, 72)
placeBestBtn.BackgroundColor3 = Color3.fromRGB(130, 25, 25)
placeBestBtn.Text = "🏆 Place Best"
placeBestBtn.TextColor3 = Color3.fromRGB(255, 210, 210)
placeBestBtn.TextScaled = true
placeBestBtn.Font = Enum.Font.GothamBold
placeBestBtn.BorderSizePixel = 0
placeBestBtn.ZIndex = 10
Instance.new("UICorner", placeBestBtn).CornerRadius = UDim.new(0, 10)
placeBestBtn.Parent = screenGui

local placeBestRemote = ReplicatedStorage:WaitForChild("PlaceBest", 5)
local placeBestResultEvt = ReplicatedStorage:WaitForChild("PlaceBestResult", 5)

placeBestBtn.MouseButton1Click:Connect(function()
	if not placeBestRemote then
		return
	end
	-- Gather client inventory and send it to the server
	local clientInv = {}
	for i = 1, State.INVENTORY_MAX do
		if State.inventory[i] then
			table.insert(clientInv, { unitType = State.inventory[i].unitType, oneIn = State.inventory[i].oneIn or 1 })
		end
	end
	-- Optimistically clear local inventory; server will return the leftovers
	for i = 1, State.INVENTORY_MAX do
		State.inventory[i] = nil
	end
	refreshToolbar()
	if InventoryPanel.isVisible() then
		InventoryPanel.refresh()
	end
	updateCarriedUnit()
	placeBestRemote:FireServer(clientInv)
end)

-- Server returns units that didn't fit into graves
if placeBestResultEvt then
	placeBestResultEvt.OnClientEvent:Connect(function(remaining)
		for i = 1, State.INVENTORY_MAX do
			State.inventory[i] = nil
		end
		for i, item in ipairs(remaining) do
			State.inventory[i] = {
				unitType = item.unitType,
				oneIn = item.oneIn or UNIT_ONE_IN[item.unitType] or 1,
			}
		end
		refreshToolbar()
		if InventoryPanel.isVisible() then
			InventoryPanel.refresh()
		end
		updateCarriedUnit()
	end)
end

local selectGraveEvt = ReplicatedStorage:WaitForChild("SelectGrave", 5)
local placeAtGraveRemote = ReplicatedStorage:WaitForChild("PlaceAtGrave", 5)

if selectGraveEvt then
	selectGraveEvt.OnClientEvent:Connect(function(gravePos, slotIndex)
		local unit = State.inventory[State.selectedSlot]
		if not unit then
			return
		end -- nothing selected

		-- Deploy unit at this grave
		if placeAtGraveRemote then
			placeAtGraveRemote:FireServer(unit.unitType, gravePos, slotIndex)
		end

		-- Remove from inventory
		State.inventory[State.selectedSlot] = nil
		refreshToolbar()
		updateCarriedUnit()
	end)
end

-- ============================================================
--  RECALL UNIT  (server returns a unit from a grave to inventory)
-- ============================================================
local recallUnitEvt = ReplicatedStorage:WaitForChild("RecallUnit", 5)
if recallUnitEvt then
	recallUnitEvt.OnClientEvent:Connect(function(unitType, oneIn)
		local added = addToInventory(unitType, oneIn)
		if not added then
			local warn = Instance.new("TextLabel", screenGui)
			warn.Size = UDim2.new(0, 280, 0, 40)
			warn.Position = UDim2.new(0.5, -140, 1, -200)
			warn.BackgroundColor3 = Color3.fromRGB(120, 30, 30)
			warn.BackgroundTransparency = 0.2
			warn.Text = "⚠️ Inventory full — " .. unitType .. " lost!"
			warn.TextColor3 = Color3.fromRGB(255, 180, 180)
			warn.TextScaled = true
			warn.Font = Enum.Font.GothamBold
			warn.ZIndex = 50
			warn.BorderSizePixel = 0
			Instance.new("UICorner", warn).CornerRadius = UDim.new(0, 8)
			game:GetService("Debris"):AddItem(warn, 2.5)
		end
	end)
end

return {}
