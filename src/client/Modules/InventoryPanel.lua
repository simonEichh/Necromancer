local InventoryPanel = {}
local Theme = require(script.Parent.Theme)
local C = Theme.Color
local UnitPortrait = require(script.Parent.UnitPortrait)
local LevelBadge = require(script.Parent.LevelBadge)
local LevelEconomy = require(game:GetService("ReplicatedStorage").Shared.Economy)

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
local getSelectedSlot, refreshToolbarFn, updateCarriedUnitFn, swapSlotsFn

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
		slot.BackgroundColor3 = C.Void
		slot.BorderSizePixel = 0
		slot.LayoutOrder = i
		slot.ZIndex = 37
		Theme.corner(slot, Theme.Radius.Small)

		local stroke = Instance.new("UIStroke", slot)
		stroke.Thickness = 2
		stroke.Color = C.Border
		stroke.Transparency = 0.6 -- an empty slot: a faint carved outline

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
		nLbl.TextSize = 11
		nLbl.Font = Theme.Font.Body
		nLbl.TextTruncate = Enum.TextTruncate.AtEnd
		nLbl.ZIndex = 38

		local indLbl = Instance.new("TextLabel", slot)
		indLbl.Size = UDim2.new(0, 16, 0, 14)
		indLbl.Position = UDim2.new(0, 2, 0, 2)
		indLbl.BackgroundTransparency = 1
		indLbl.Text = ""
		indLbl.TextSize = 10
		indLbl.Font = Theme.Font.Strong
		indLbl.TextColor3 = C.BoneDim
		indLbl.ZIndex = 39

		local btn = Instance.new("TextButton", slot)
		btn.Size = UDim2.new(1, 0, 1, 0)
		btn.BackgroundTransparency = 1
		btn.Text = ""
		btn.ZIndex = 39

		local sd = {
			frame = slot, emoji = eLbl, name = nLbl, portrait = nil, badge = LevelBadge.attach(slot, 40),
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
			ttName.Text   = u.unitType .. ((u.level or 0) > 0 and ("  Lv " .. u.level) or "")
			ttRarity.Text = ui.rarity or ""
			ttRarity.TextColor3 = RARITY_COLORS[ui.rarity] or Color3.fromRGB(200, 200, 200)
			ttDps.Text    = (UNIT_DPS[u.unitType] and math.floor(UNIT_DPS[u.unitType] * LevelEconomy.levelMultiplier(u.level)) or "?") .. " DPS"
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
			swapSlotsFn(sel, invIdx) -- the server swaps them and the new order comes back via Sync
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
			-- DPS including the unit's level
			local da = (UNIT_DPS[a.unit.unitType] or 0) * LevelEconomy.levelMultiplier(a.unit.level)
			local db = (UNIT_DPS[b.unit.unitType] or 0) * LevelEconomy.levelMultiplier(b.unit.level)
			return da > db
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
	invTitle.Text = "Inventory (" .. count .. " / " .. INVENTORY_MAX .. ")"
	for i = 1, INVENTORY_MAX do
		local sd    = invSlots[i]
		local entry = sorted[i]
		if entry then
			local invIdx = entry.idx
			local unit   = entry.unit
			local info   = UNIT_INFO[unit.unitType] or {}
			local rc     = RARITY_COLORS[info.rarity] or C.Border
			sd.currentInvIdx = invIdx
			sd.frame.BackgroundColor3 = C.Stone:Lerp(rc, 0.16) -- dark stone with a tint of the unit's rarity
			sd.stroke.Color   = rc
			sd.stroke.Transparency = 0
			-- the 3D portrait (made when a slot first holds a unit)
			if not sd.portrait then
				sd.portrait = UnitPortrait.attach(sd.frame, { position = UDim2.new(0, 2, 0, 2), size = UDim2.new(1, -4, 1, -18), zIndex = 38 })
			end
			sd.portrait.set(unit.unitType)
			sd.badge.set(unit.level)
			sd.name.Text      = unit.unitType
			sd.name.TextColor3 = C.Bone
			sd.ind.Text       = (invIdx <= 10) and tostring(invIdx % 10) or ""
		else
			sd.currentInvIdx  = nil
			sd.frame.BackgroundColor3 = C.Void
			sd.stroke.Color = C.Border
			sd.stroke.Transparency = 0.6
			if sd.portrait then
				sd.portrait.set(nil)
			end
			sd.badge.set(0)
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
	swapSlotsFn       = deps.swapSlots

	-- ── Main panel (Theme.panel: stone frame, title bar, body) ──
	local themed = Theme.panel(screenGui, { title = "Inventory (0 / " .. INVENTORY_MAX .. ")", size = UDim2.fromOffset(900, 580), zIndex = 35 })
	panel = themed.frame
	panel.Name = "InventoryPanel"
	panel.Visible = false
	panel.ZIndex = 35
	invTitle = themed.title
	invTitle.TextSize = 26
	local body = themed.body

	do
		-- close button in the title bar
		local closeBtn = Theme.stoneButton(panel, {
			text = "X", color = "red", size = UDim2.fromOffset(44, 28),
			position = UDim2.new(1, -62, 0, 6), zIndex = 37,
			onClick = function() panel.Visible = false end,
		})

		-- ── Sidebar: sort buttons ────────────────────────────
		local sidebar = Instance.new("Frame", body)
		sidebar.Size = UDim2.new(0, 112, 1, 0)
		sidebar.BackgroundColor3 = C.Void
		sidebar.BorderSizePixel = 0
		sidebar.ZIndex = 36
		Theme.corner(sidebar, Theme.Radius.Small)
		Theme.stroke(sidebar, C.Border, Theme.Stroke.Thin)

		local sortByLbl = Theme.label(sidebar, { text = "SORT BY", size = "Small", font = "Strong", color = C.BoneDim, align = Enum.TextXAlignment.Center, frameSize = UDim2.new(1, 0, 0, 24) })
		sortByLbl.Position = UDim2.fromOffset(0, 8)
		sortByLbl.ZIndex = 37

		local SORT_DEFS = {
			{ key = "DPS", label = "DPS" },
			{ key = "Chance", label = "Rarity" },
			{ key = "Letter", label = "A to Z" },
		}
		local sortBtns = {}
		local function paintSortButtons()
			for _, sbtn in ipairs(sortBtns) do
				-- the active choice is green, the others grey
				sbtn.stone.root:SetAttribute("Active", sbtn.key == invSortMode)
				sbtn.refresh()
			end
		end
		for idx, sd in ipairs(SORT_DEFS) do
			local key = sd.key
			local entry = { key = key }
			local function build(color)
				if entry.stone then entry.stone.root:Destroy() end
				entry.stone = Theme.stoneButton(sidebar, {
					text = sd.label, color = color, size = UDim2.fromOffset(90, 40),
					position = UDim2.fromOffset(11, 40 + (idx - 1) * 56), zIndex = 37,
					onClick = function()
						invSortMode = key
						paintSortButtons()
						refresh()
					end,
				})
			end
			entry.refresh = function()
				local wantGreen = key == invSortMode
				if entry.isGreen ~= wantGreen then
					entry.isGreen = wantGreen
					if wantGreen then
						build(nil) -- the active choice is the green button
					else
						build("stone")
					end
				end
			end
			table.insert(sortBtns, entry)
			entry.refresh()
		end
		paintSortButtons()
	end

	-- ── Scroll area ──────────────────────────────────────────
	invScroll = Instance.new("ScrollingFrame", body)
	invScroll.Size = UDim2.new(1, -124, 1, 0)
	invScroll.Position = UDim2.new(0, 124, 0, 0)
	invScroll.BackgroundTransparency = 1
	invScroll.BorderSizePixel = 0
	invScroll.ScrollBarThickness = 6
	invScroll.ScrollBarImageColor3 = C.Verdigris
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
