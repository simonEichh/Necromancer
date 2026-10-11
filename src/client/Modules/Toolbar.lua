-- Bottom toolbar (first 10 inventory slots), hover tooltip, carried unit block, inventory helpers.
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local screenGui = require(script.Parent.Gui)
local State = require(script.Parent.State)
local InventoryPanel = require(script.Parent.InventoryPanel)
local GameData = require(script.Parent.GameData)
local UNIT_INFO = GameData.UNIT_INFO
local UNIT_COLORS = GameData.UNIT_COLORS
local UNIT_DPS = GameData.UNIT_DPS
local UNIT_ONE_IN = GameData.UNIT_ONE_IN
local RARITY_COLORS = GameData.RARITY_COLORS

local selectSlot -- forward declared; defined below

local SLOT_SIZE = 58
local SLOT_GAP = 4
local TOOLBAR_W = SLOT_SIZE * 10 + SLOT_GAP * 9 + 12 -- 12 for padding

local toolbarFrame = Instance.new("Frame")
toolbarFrame.Size = UDim2.new(0, TOOLBAR_W, 0, SLOT_SIZE + 10)
toolbarFrame.Position = UDim2.new(0.5, -TOOLBAR_W / 2, 1, -80)
toolbarFrame.BackgroundColor3 = Color3.fromRGB(12, 6, 28)
toolbarFrame.BackgroundTransparency = 0.25
toolbarFrame.BorderSizePixel = 0
toolbarFrame.Parent = screenGui
Instance.new("UICorner", toolbarFrame).CornerRadius = UDim.new(0, 10)

local toolbarLayout = Instance.new("UIListLayout", toolbarFrame)
toolbarLayout.FillDirection = Enum.FillDirection.Horizontal
toolbarLayout.Padding = UDim.new(0, SLOT_GAP)
toolbarLayout.SortOrder = Enum.SortOrder.LayoutOrder
toolbarLayout.VerticalAlignment = Enum.VerticalAlignment.Center
toolbarLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

Instance.new("UIPadding", toolbarFrame).PaddingLeft = UDim.new(0, 6)
local toolbarPad = Instance.new("UIPadding", toolbarFrame)
toolbarPad.PaddingLeft = UDim.new(0, 6)
toolbarPad.PaddingRight = UDim.new(0, 6)

local slotFrames = {}

-- ── INVENTORY HOVER TOOLTIP ───────────────────────────────────
local tooltip = Instance.new("Frame", screenGui)
tooltip.Size = UDim2.new(0, 175, 0, 96)
tooltip.BackgroundColor3 = Color3.fromRGB(18, 8, 38)
tooltip.BackgroundTransparency = 0.08
tooltip.BorderSizePixel = 0
tooltip.Visible = false
tooltip.ZIndex = 60
Instance.new("UICorner", tooltip).CornerRadius = UDim.new(0, 8)
local ttStroke = Instance.new("UIStroke", tooltip)
ttStroke.Color = Color3.fromRGB(80, 40, 140)
ttStroke.Thickness = 1

local ttName = Instance.new("TextLabel", tooltip)
ttName.Size = UDim2.new(1, -10, 0.34, 0)
ttName.Position = UDim2.new(0, 5, 0.02, 0)
ttName.BackgroundTransparency = 1
ttName.TextColor3 = Color3.fromRGB(255, 255, 255)
ttName.TextScaled = true
ttName.Font = Enum.Font.GothamBold
ttName.ZIndex = 61

local ttRarity = Instance.new("TextLabel", tooltip)
ttRarity.Size = UDim2.new(1, -10, 0.24, 0)
ttRarity.Position = UDim2.new(0, 5, 0.36, 0)
ttRarity.BackgroundTransparency = 1
ttRarity.TextScaled = true
ttRarity.Font = Enum.Font.Gotham
ttRarity.ZIndex = 61

local ttDps = Instance.new("TextLabel", tooltip)
ttDps.Size = UDim2.new(1, -10, 0.2, 0)
ttDps.Position = UDim2.new(0, 5, 0.60, 0)
ttDps.BackgroundTransparency = 1
ttDps.TextColor3 = Color3.fromRGB(100, 255, 130)
ttDps.TextScaled = true
ttDps.Font = Enum.Font.GothamBold
ttDps.ZIndex = 61

local ttOneIn = Instance.new("TextLabel", tooltip)
ttOneIn.Size = UDim2.new(1, -10, 0.2, 0)
ttOneIn.Position = UDim2.new(0, 5, 0.80, 0)
ttOneIn.BackgroundTransparency = 1
ttOneIn.TextColor3 = Color3.fromRGB(190, 165, 255)
ttOneIn.TextScaled = true
ttOneIn.Font = Enum.Font.Gotham
ttOneIn.ZIndex = 61

for i = 1, 10 do
	local slot = Instance.new("Frame", toolbarFrame)
	slot.Size = UDim2.new(0, SLOT_SIZE, 0, SLOT_SIZE)
	slot.BackgroundColor3 = Color3.fromRGB(22, 10, 45)
	slot.BorderSizePixel = 0
	slot.LayoutOrder = i
	Instance.new("UICorner", slot).CornerRadius = UDim.new(0, 8)

	-- Slot number (top-left)
	local numLbl = Instance.new("TextLabel", slot)
	numLbl.Size = UDim2.new(0, 16, 0, 16)
	numLbl.Position = UDim2.new(0, 3, 0, 2)
	numLbl.BackgroundTransparency = 1
	numLbl.Text = tostring(i % 10) -- 1-9 then 0
	numLbl.TextColor3 = Color3.fromRGB(150, 130, 190)
	numLbl.TextScaled = true
	numLbl.Font = Enum.Font.GothamBold
	numLbl.ZIndex = 2

	-- Unit emoji (center)
	local emojiLbl = Instance.new("TextLabel", slot)
	emojiLbl.Size = UDim2.new(1, 0, 0.58, 0)
	emojiLbl.Position = UDim2.new(0, 0, 0.08, 0)
	emojiLbl.BackgroundTransparency = 1
	emojiLbl.Text = ""
	emojiLbl.TextScaled = true
	emojiLbl.ZIndex = 2

	-- Unit name (bottom)
	local nameLbl = Instance.new("TextLabel", slot)
	nameLbl.Size = UDim2.new(1, -2, 0, 13)
	nameLbl.Position = UDim2.new(0, 1, 1, -15)
	nameLbl.BackgroundTransparency = 1
	nameLbl.Text = ""
	nameLbl.TextColor3 = Color3.fromRGB(190, 170, 220)
	nameLbl.TextSize = 9
	nameLbl.Font = Enum.Font.Gotham
	nameLbl.ZIndex = 2

	slotFrames[i] = { frame = slot, emoji = emojiLbl, name = nameLbl }

	-- Click to select
	local btn = Instance.new("TextButton", slot)
	btn.Size = UDim2.new(1, 0, 1, 0)
	btn.BackgroundTransparency = 1
	btn.Text = ""
	btn.ZIndex = 3
	local slotIndex = i
	btn.MouseButton1Click:Connect(function()
		selectSlot(slotIndex)
	end)

	btn.MouseEnter:Connect(function()
		local unit = State.inventory[slotIndex]
		if not unit then
			tooltip.Visible = false
			return
		end
		local info = UNIT_INFO[unit.unitType] or {}
		ttName.Text = (info.emoji or "❓") .. " " .. unit.unitType
		ttRarity.Text = info.rarity or ""
		ttRarity.TextColor3 = RARITY_COLORS[info.rarity] or Color3.fromRGB(200, 200, 200)
		ttDps.Text = (UNIT_DPS[unit.unitType] or "?") .. " DPS"
		ttOneIn.Text = "1 in " .. (unit.oneIn or UNIT_ONE_IN[unit.unitType] or "?")
		local abs = slot.AbsolutePosition
		local sz = slot.AbsoluteSize
		local sw = screenGui.AbsoluteSize.X
		local tx = math.clamp(abs.X + sz.X / 2 - 87, 0, sw - 175)
		tooltip.Position = UDim2.new(0, tx, 0, abs.Y - 104)
		tooltip.Visible = true
	end)

	btn.MouseLeave:Connect(function()
		tooltip.Visible = false
	end)
end

-- ============================================================
--  TOOLBAR / INVENTORY FUNCTIONS
-- ============================================================
local heldBlock = nil

local function updateCarriedUnit()
	if heldBlock then
		heldBlock:Destroy()
		heldBlock = nil
	end

	local unit = State.inventory[State.selectedSlot]
	if not unit then
		return
	end

	local char = player.Character
	if not char then
		return
	end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return
	end

	heldBlock = Instance.new("Part")
	heldBlock.Size = Vector3.new(0.9, 0.9, 0.9)
	heldBlock.BrickColor = UNIT_COLORS[unit.unitType] or BrickColor.new("Medium stone grey")
	heldBlock.Material = Enum.Material.SmoothPlastic
	heldBlock.CanCollide = false
	heldBlock.CastShadow = false
	heldBlock.Parent = char

	local weld = Instance.new("Weld")
	weld.Part0 = hrp
	weld.Part1 = heldBlock
	weld.C0 = CFrame.new(1.5, -0.4, -0.7)
	weld.Parent = heldBlock
end

local function refreshToolbar()
	for i = 1, 10 do
		local sf = slotFrames[i]
		local unit = State.inventory[i]
		local isSel = (i == State.selectedSlot)

		if unit then
			local info = UNIT_INFO[unit.unitType] or {}
			local rc = RARITY_COLORS[info.rarity] or Color3.fromRGB(80, 40, 120)
			local ri, gi, bi = rc.R * 255, rc.G * 255, rc.B * 255
			sf.emoji.Text = info.emoji or "❓"
			sf.name.Text = unit.unitType
			sf.frame.BackgroundColor3 = isSel
					and Color3.fromRGB(
						math.floor(ri * 0.45 + 25),
						math.floor(gi * 0.45 + 12),
						math.floor(bi * 0.45 + 45)
					)
				or Color3.fromRGB(math.floor(ri * 0.18 + 6), math.floor(gi * 0.18 + 3), math.floor(bi * 0.18 + 12))
		else
			sf.emoji.Text = ""
			sf.name.Text = ""
			sf.frame.BackgroundColor3 = isSel and Color3.fromRGB(55, 30, 90) or Color3.fromRGB(22, 10, 45)
		end
	end
end

function selectSlot(n)
	State.selectedSlot = n
	refreshToolbar()
	updateCarriedUnit()
end

-- Key 1-0 → select slot
local KEY_TO_SLOT = {
	[Enum.KeyCode.One] = 1,
	[Enum.KeyCode.Two] = 2,
	[Enum.KeyCode.Three] = 3,
	[Enum.KeyCode.Four] = 4,
	[Enum.KeyCode.Five] = 5,
	[Enum.KeyCode.Six] = 6,
	[Enum.KeyCode.Seven] = 7,
	[Enum.KeyCode.Eight] = 8,
	[Enum.KeyCode.Nine] = 9,
	[Enum.KeyCode.Zero] = 10,
}
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end
	local slot = KEY_TO_SLOT[input.KeyCode]
	if slot then
		selectSlot(slot)
	end
end)

-- Re-attach held block if character respawns
player.CharacterAdded:Connect(function()
	heldBlock = nil
	task.delay(1, updateCarriedUnit)
end)

-- I key toggles the inventory panel
-- I key toggles the inventory panel
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end
	if input.KeyCode == Enum.KeyCode.I then
		InventoryPanel.toggle()
	end
end)

return {
	refresh = refreshToolbar,
	select = selectSlot,
	updateCarried = updateCarriedUnit,
	tooltip = {
		frame = tooltip,
		name = ttName,
		rarity = ttRarity,
		dps = ttDps,
		oneIn = ttOneIn,
	},
}
