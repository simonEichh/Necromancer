local InventoryPanel = {}

-- ── Private state ────────────────────────────────────────────
local invSortMode   = "DPS"
local invSlotsReady = false
local invSlots      = {}

-- ── UI refs ──────────────────────────────────────────────────
local panel, invTitle, invScroll

-- ── Injected deps ────────────────────────────────────────────
local inventory, UNIT_INFO, RARITY_COLORS, UNIT_DPS, UNIT_ONE_IN
local INVENTORY_MAX, screenGui
local tooltip, ttName, ttRarity, ttDps, ttOneIn
local getSelectedSlot, refreshToolbarFn, updateCarriedUnitFn

-- ── Constants ────────────────────────────────────────────────
local INV_COLS = 9
local INV_SW   = 80
local INV_SH   = 80
local INV_GAP  = 4

-- ── Forward declares ─────────────────────────────────────────
local ensureInvSlots, getInventorySorted, refresh

-- ── Slot pool: lazily built on first open ────────────────────
ensureInvSlots = function()
	if invSlotsReady then return end
	invSlotsReady = true
	for i = 1, INVENTORY_MAX do
		local slot = Instance.new("Frame", invScroll)
		slot.Size = UDim2.new(0, INV_SW, 0, INV_SH)
		slot.BackgroundColor3 = Color3.fromRGB(14, 7, 28)
		slot.BorderSizePixel = 0
		slot.LayoutOrder = i
		slot.ZIndex = 37
		Instance.new("UICorner", slot).CornerRadius = UDim.new(0, 8)

		local stroke = Instance.new("UIStroke", slot)
		stroke.Thickness = 1.5
		stroke.Enabled = false

		local eLbl = Instance.new("TextLabel", slot)
		eLbl.Size = UDim2.new(1, 0, 0.55, 0)
		eLbl.Position = UDim2.new(0, 0, 0.04, 0)
		eLbl.BackgroundTransparency = 1
		eLbl.Text = ""
		eLbl.TextScaled = true
		eLbl.ZIndex = 38

		local nLbl = Instance.new("TextLabel", slot)
		nLbl.Size = UDim2.new(1, -4, 0, 15)
		nLbl.Position = UDim2.new(0, 2, 1, -17)
		nLbl.BackgroundTransparency = 1
		nLbl.Text = ""
		nLbl.TextSize = 10
		nLbl.Font = Enum.Font.Gotham
		nLbl.TextTruncate = Enum.TextTruncate.AtEnd
		nLbl.ZIndex = 38

		local indLbl = Instance.new("TextLabel", slot)
		indLbl.Size = UDim2.new(0, 16, 0, 14)
		indLbl.Position = UDim2.new(0, 2, 0, 2)
		indLbl.BackgroundTransparency = 1
		indLbl.Text = ""
		indLbl.TextSize = 10
		indLbl.Font = Enum.Font.GothamBold
		indLbl.TextColor3 = Color3.fromRGB(255, 255, 200)
		indLbl.ZIndex = 39

		local btn = Instance.new("TextButton", slot)
		btn.Size = UDim2.new(1, 0, 1, 0)
		btn.BackgroundTransparency = 1
		btn.Text = ""
		btn.ZIndex = 39

		local sd = {
			frame = slot, emoji = eLbl, name = nLbl,
			ind = indLbl, btn = btn, stroke = stroke,
			currentInvIdx = nil,
		}
		invSlots[i] = sd

		btn.MouseEnter:Connect(function()
			local invIdx = sd.currentInvIdx
			if not invIdx then tooltip.Visible = false return end
			local u = inventory[invIdx]
			if not u then tooltip.Visible = false return end
			local ui = UNIT_INFO[u.unitType] or {}
			ttName.Text   = (ui.emoji or "❓") .. " " .. u.unitType
			ttRarity.Text = ui.rarity or ""
			ttRarity.TextColor3 = RARITY_COLORS[ui.rarity] or Color3.fromRGB(200, 200, 200)
			ttDps.Text    = (UNIT_DPS[u.unitType] or "?") .. " DPS"
			ttOneIn.Text  = "1 in " .. (u.oneIn or UNIT_ONE_IN[u.unitType] or "?")
			local abs = slot.AbsolutePosition
			local sz  = slot.AbsoluteSize
			local sw  = screenGui.AbsoluteSize.X
			local sh  = screenGui.AbsoluteSize.Y
			local tx = math.clamp(abs.X + sz.X / 2 - 87, 0, sw - 175)
			local ty = math.clamp(abs.Y - 108, 10, sh - 110)
			tooltip.Position = UDim2.new(0, tx, 0, ty)
			tooltip.Visible = true
		end)

		btn.MouseLeave:Connect(function()
			tooltip.Visible = false
		end)

		btn.MouseButton1Click:Connect(function()
			local invIdx = sd.currentInvIdx
			if not invIdx or not inventory[invIdx] then return end
			local sel = getSelectedSlot()
			if invIdx == sel then return end
			local temp = inventory[sel]
			inventory[sel] = inventory[invIdx]
			inventory[invIdx] = temp
			refreshToolbarFn()
			refresh()
			updateCarriedUnitFn()
		end)
	end
end

-- ── Sort helper ───────────────────────────────────────────────
getInventorySorted = function()
	local list = {}
	for i = 1, INVENTORY_MAX do
		if inventory[i] then
			table.insert(list, { idx = i, unit = inventory[i] })
		end
	end
	if invSortMode == "DPS" then
		table.sort(list, function(a, b)
			return (UNIT_DPS[a.unit.unitType] or 0) > (UNIT_DPS[b.unit.unitType] or 0)
		end)
	elseif invSortMode == "Chance" then
		table.sort(list, function(a, b)
			local ai = a.unit.oneIn or UNIT_ONE_IN[a.unit.unitType] or 1
			local bi = b.unit.oneIn or UNIT_ONE_IN[b.unit.unitType] or 1
			return ai > bi
		end)
	elseif invSortMode == "Letter" then
		table.sort(list, function(a, b)
			return a.unit.unitType < b.unit.unitType
		end)
	end
	return list
end

-- ── Refresh display ───────────────────────────────────────────
refresh = function()
	ensureInvSlots()
	local sorted = getInventorySorted()
	local count = #sorted
	invTitle.Text = "📦 Inventory (" .. count .. " / " .. INVENTORY_MAX .. ")"
	for i = 1, INVENTORY_MAX do
		local sd    = invSlots[i]
		local entry = sorted[i]
		if entry then
			local invIdx = entry.idx
			local unit   = entry.unit
			local info   = UNIT_INFO[unit.unitType] or {}
			local rc     = RARITY_COLORS[info.rarity] or Color3.fromRGB(80, 40, 120)
			local ri, gi, bi = rc.R * 255, rc.G * 255, rc.B * 255
			sd.currentInvIdx = invIdx
			sd.frame.BackgroundColor3 =
				Color3.fromRGB(math.floor(ri*0.16+5), math.floor(gi*0.16+3), math.floor(bi*0.16+10))
			sd.stroke.Color   = rc
			sd.stroke.Enabled = true
			sd.emoji.Text     = info.emoji or "❓"
			sd.name.Text      = unit.unitType
			sd.name.TextColor3 = Color3.fromRGB(210, 195, 235)
			sd.ind.Text       = (invIdx <= 10) and tostring(invIdx % 10) or ""
		else
			sd.currentInvIdx  = nil
			sd.frame.BackgroundColor3 = Color3.fromRGB(14, 7, 28)
			sd.stroke.Enabled = false
			sd.emoji.Text     = ""
			sd.name.Text      = ""
			sd.ind.Text       = ""
		end
	end
end

-- ── Public API ────────────────────────────────────────────────
function InventoryPanel.init(sg, deps)
	screenGui         = sg
	inventory         = deps.inventory
	UNIT_INFO         = deps.UNIT_INFO
	RARITY_COLORS     = deps.RARITY_COLORS
	UNIT_DPS          = deps.UNIT_DPS
	UNIT_ONE_IN       = deps.UNIT_ONE_IN
	INVENTORY_MAX     = deps.INVENTORY_MAX
	tooltip           = deps.tooltip
	ttName            = deps.ttName
	ttRarity          = deps.ttRarity
	ttDps             = deps.ttDps
	ttOneIn           = deps.ttOneIn
	getSelectedSlot   = deps.getSelectedSlot
	refreshToolbarFn  = deps.refreshToolbar
	updateCarriedUnitFn = deps.updateCarriedUnit

	-- ── Main panel ───────────────────────────────────────────
	panel = Instance.new("Frame")
	panel.Name = "InventoryPanel"
	panel.Size = UDim2.new(0, 900, 0, 580)
	panel.Position = UDim2.new(0.5, -450, 0.5, -290)
	panel.BackgroundColor3 = Color3.fromRGB(8, 4, 20)
	panel.BackgroundTransparency = 0.05
	panel.BorderSizePixel = 0
	panel.Visible = false
	panel.ZIndex = 35
	panel.Parent = screenGui
	Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 16)

	do
		local stroke = Instance.new("UIStroke", panel)
		stroke.Color = Color3.fromRGB(80, 40, 140)
		stroke.Thickness = 2

		invTitle = Instance.new("TextLabel", panel)
		invTitle.Size = UDim2.new(1, -60, 0, 44)
		invTitle.Position = UDim2.new(0, 14, 0, 4)
		invTitle.BackgroundTransparency = 1
		invTitle.Text = "📦 Inventory (0 / " .. INVENTORY_MAX .. ")"
		invTitle.TextColor3 = Color3.fromRGB(220, 195, 255)
		invTitle.TextScaled = true
		invTitle.Font = Enum.Font.GothamBold
		invTitle.TextXAlignment = Enum.TextXAlignment.Left
		invTitle.ZIndex = 36

		local closeBtn = Instance.new("TextButton", panel)
		closeBtn.Size = UDim2.new(0, 36, 0, 36)
		closeBtn.Position = UDim2.new(1, -44, 0, 6)
		closeBtn.BackgroundColor3 = Color3.fromRGB(60, 20, 80)
		closeBtn.Text = "✕"
		closeBtn.TextColor3 = Color3.fromRGB(210, 160, 255)
		closeBtn.TextScaled = true
		closeBtn.Font = Enum.Font.GothamBold
		closeBtn.BorderSizePixel = 0
		closeBtn.ZIndex = 37
		Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 8)
		closeBtn.MouseButton1Click:Connect(function()
			panel.Visible = false
		end)

		-- ── Sidebar: sort buttons ────────────────────────────
		local sidebar = Instance.new("Frame", panel)
		sidebar.Size = UDim2.new(0, 106, 1, -52)
		sidebar.Position = UDim2.new(0, 6, 0, 50)
		sidebar.BackgroundColor3 = Color3.fromRGB(12, 6, 26)
		sidebar.BorderSizePixel = 0
		sidebar.ZIndex = 36
		Instance.new("UICorner", sidebar).CornerRadius = UDim.new(0, 10)

		local sortByLbl = Instance.new("TextLabel", sidebar)
		sortByLbl.Size = UDim2.new(1, 0, 0, 26)
		sortByLbl.Position = UDim2.new(0, 0, 0, 4)
		sortByLbl.BackgroundTransparency = 1
		sortByLbl.Text = "Sort by:"
		sortByLbl.TextColor3 = Color3.fromRGB(150, 130, 190)
		sortByLbl.TextScaled = true
		sortByLbl.Font = Enum.Font.Gotham
		sortByLbl.ZIndex = 37

		local SORT_DEFS = {
			{ key = "DPS",    label = "⚔️ DPS",    color = Color3.fromRGB(100, 255, 130) },
			{ key = "Chance", label = "⭐ Chance", color = Color3.fromRGB(255, 220, 80)  },
			{ key = "Letter", label = "🔤 Letter", color = Color3.fromRGB(180, 170, 255) },
		}
		local sortBtns = {}
		for idx, sd in ipairs(SORT_DEFS) do
			local sb = Instance.new("TextButton", sidebar)
			sb.Size = UDim2.new(1, -10, 0, 68)
			sb.Position = UDim2.new(0, 5, 0, 32 + (idx-1)*76)
			sb.BorderSizePixel = 0
			sb.TextScaled = true
			sb.Font = Enum.Font.GothamBold
			sb.ZIndex = 37
			sb.Text = sd.label
			Instance.new("UICorner", sb).CornerRadius = UDim.new(0, 10)
			table.insert(sortBtns, { btn = sb, key = sd.key, color = sd.color })
			local key = sd.key
			sb.MouseButton1Click:Connect(function()
				invSortMode = key
				for _, s in ipairs(sortBtns) do
					local act = s.key == invSortMode
					s.btn.BackgroundColor3 = act and Color3.fromRGB(55, 22, 90) or Color3.fromRGB(22, 10, 44)
					s.btn.TextColor3 = act and s.color or Color3.fromRGB(120, 100, 155)
				end
				refresh()
			end)
		end
		for _, s in ipairs(sortBtns) do
			local act = s.key == invSortMode
			s.btn.BackgroundColor3 = act and Color3.fromRGB(55, 22, 90) or Color3.fromRGB(22, 10, 44)
			s.btn.TextColor3 = act and s.color or Color3.fromRGB(120, 100, 155)
		end
	end

	-- ── Scroll area ──────────────────────────────────────────
	invScroll = Instance.new("ScrollingFrame", panel)
	invScroll.Size = UDim2.new(1, -120, 1, -52)
	invScroll.Position = UDim2.new(0, 116, 0, 50)
	invScroll.BackgroundTransparency = 1
	invScroll.BorderSizePixel = 0
	invScroll.ScrollBarThickness = 6
	invScroll.ScrollBarImageColor3 = Color3.fromRGB(100, 60, 180)
	invScroll.ZIndex = 36

	do
		local grid = Instance.new("UIGridLayout", invScroll)
		grid.CellSize = UDim2.new(0, INV_SW, 0, INV_SH)
		grid.CellPadding = UDim2.new(0, INV_GAP, 0, INV_GAP)
		grid.SortOrder = Enum.SortOrder.LayoutOrder
		grid.FillDirection = Enum.FillDirection.Horizontal
		grid.HorizontalAlignment = Enum.HorizontalAlignment.Left
		Instance.new("UIPadding", invScroll).PaddingLeft = UDim.new(0, 4)
		local rows = math.ceil(INVENTORY_MAX / INV_COLS)
		invScroll.CanvasSize = UDim2.new(0, 0, 0, rows * (INV_SH + INV_GAP) + INV_GAP)
	end
end

function InventoryPanel.refresh()
	refresh()
end

function InventoryPanel.toggle()
	panel.Visible = not panel.Visible
	if panel.Visible then
		refresh()
	end
end

function InventoryPanel.isVisible()
	return panel ~= nil and panel.Visible
end

return InventoryPanel
