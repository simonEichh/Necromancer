local InventoryPanel = {}
local Theme = require(script.Parent.Theme)
local C = Theme.Color
local UnitPortrait = require(script.Parent.UnitPortrait)
local LevelBadge = require(script.Parent.LevelBadge)
local SignatureName = require(script.Parent.SignatureName)
local Units = require(game:GetService("ReplicatedStorage").Shared.Units)
local LevelEconomy = require(game:GetService("ReplicatedStorage").Shared.Economy)
local Rarities = require(game:GetService("ReplicatedStorage").Shared.Rarities)
local State = require(script.Parent.State)
local Format = require(script.Parent.Format)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local sellAllRemote = ReplicatedStorage:WaitForChild("SellAll", 10)
local toggleLockRemote = ReplicatedStorage:WaitForChild("ToggleLock", 10)

-- ── Private state ────────────────────────────────────────────
local invSortMode   = "DPS"
local invSlotsReady = false
local invSlots      = {}
-- sell all / lock
local sellMaxRank   = 1     -- sell units of this rarity rank or lower (1 = Common)
local keepUpgraded  = true  -- never sell units above level 0
local lockMode      = false -- clicking a slot locks/unlocks it instead of picking it
local confirmSell   = false -- the Sell button was pressed once and asks "Sure?"
local updateSellSummary

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

		-- "LOCK" tag on locked units
		local lockLbl = Instance.new("TextLabel", slot)
		lockLbl.Size = UDim2.new(0, 34, 0, 13)
		lockLbl.Position = UDim2.new(0, 2, 0, 16)
		lockLbl.BackgroundColor3 = C.Void
		lockLbl.BackgroundTransparency = 0.2
		lockLbl.BorderSizePixel = 0
		lockLbl.Text = "LOCK"
		lockLbl.TextSize = 10
		lockLbl.Font = Theme.Font.Strong
		lockLbl.TextColor3 = Color3.fromRGB(236, 190, 84)
		lockLbl.Visible = false
		lockLbl.ZIndex = 39
		Theme.corner(lockLbl, 3)

		local sd = {
			frame = slot, emoji = eLbl, name = nLbl, portrait = nil, badge = LevelBadge.attach(slot, 40),
			ind = indLbl, btn = btn, stroke = stroke, lock = lockLbl,
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
			SignatureName.apply(ttName, u.unitType)
			ttRarity.Text = (ui.rarity or "") .. (Units.isSignature(u.unitType) and "  ·  Signature" or "")
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
			if lockMode then
				if toggleLockRemote then toggleLockRemote:FireServer(invIdx) end -- the new state comes back via Sync
				return
			end
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
			SignatureName.apply(sd.name, unit.unitType)
			sd.ind.Text       = (invIdx <= 10) and tostring(invIdx % 10) or ""
			sd.lock.Visible   = unit.locked == true
		else
			sd.currentInvIdx  = nil
			sd.frame.BackgroundColor3 = C.Void
			sd.stroke.Color = C.Border
			sd.stroke.Transparency = 0.6
			if sd.portrait then
				sd.portrait.set(nil)
			end
			sd.badge.set(0)
			SignatureName.apply(sd.name, nil)
			sd.name.Text      = ""
			sd.ind.Text       = ""
			sd.lock.Visible   = false
		end
	end
	if updateSellSummary then
		updateSellSummary()
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
	local themed = Theme.panel(screenGui, { title = "Inventory (0 / " .. INVENTORY_MAX .. ")", size = UDim2.fromOffset(960, 580), zIndex = 35 })
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
		sidebar.Size = UDim2.new(0, 170, 1, 0)
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
					text = sd.label, color = color, size = UDim2.fromOffset(150, 38),
					position = UDim2.fromOffset(10, 36 + (idx - 1) * 46), zIndex = 37,
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

		-- ── Sidebar: sell all (rarity filter, keep upgraded) and lock mode ──
		local function header(text, y)
			local l = Theme.label(sidebar, { text = text, size = "Small", font = "Strong", color = C.BoneDim, align = Enum.TextXAlignment.Center, frameSize = UDim2.new(1, 0, 0, 20) })
			l.Position = UDim2.fromOffset(0, y)
			l.ZIndex = 37
			return l
		end
		-- a stone button that is rebuilt when its colour has to change (green = on, grey = off)
		local function choiceButton(y, getText, isOn, color, onClick)
			local entry = {}
			entry.refresh = function()
				local want = isOn and (isOn() and "on" or "off") or (color or "stone")
				if entry.state ~= want then
					entry.state = want
					if entry.stone then entry.stone.root:Destroy() end
					entry.stone = Theme.stoneButton(sidebar, {
						text = getText(), color = (want == "on") and nil or (want == "off" and "stone" or want),
						size = UDim2.fromOffset(150, 38), position = UDim2.fromOffset(10, y), zIndex = 37,
						onClick = onClick,
					})
				end
				entry.stone.label.Text = getText()
			end
			entry.refresh()
			return entry
		end

		header("SELL ALL", 182)
		header("up to", 202).TextSize = 12
		local rarityBtn, keepBtn, sellBtn, lockBtn
		rarityBtn = choiceButton(220, function()
			return LevelEconomy.RARITIES_ASC[sellMaxRank]
		end, nil, "stone", function()
			sellMaxRank = sellMaxRank % #LevelEconomy.RARITIES_ASC + 1
			confirmSell = false
			rarityBtn.refresh()
			updateSellSummary()
		end)
		keepBtn = choiceButton(266, function()
			return "Keep Lv 1+"
		end, function() return keepUpgraded end, nil, function()
			keepUpgraded = not keepUpgraded
			confirmSell = false
			keepBtn.refresh()
			updateSellSummary()
		end)
		local summary = Theme.label(sidebar, { text = "", size = "Small", color = C.Bone, align = Enum.TextXAlignment.Center, frameSize = UDim2.new(1, -8, 0, 34) })
		summary.Position = UDim2.fromOffset(4, 308)
		summary.TextWrapped = true
		summary.ZIndex = 37
		sellBtn = choiceButton(346, function()
			return confirmSell and "Sure?" or "Sell"
		end, nil, "red", function()
			if not confirmSell then
				confirmSell = true
				sellBtn.refresh()
				task.delay(3, function()
					if confirmSell then
						confirmSell = false
						sellBtn.refresh()
					end
				end)
				return
			end
			confirmSell = false
			sellBtn.refresh()
			if sellAllRemote then sellAllRemote:FireServer(sellMaxRank, keepUpgraded) end
		end)

		header("LOCK", 396)
		local lockHint
		lockBtn = choiceButton(416, function()
			return "Lock mode"
		end, function() return lockMode end, nil, function()
			lockMode = not lockMode
			lockBtn.refresh()
			lockHint.Visible = lockMode
		end)
		lockHint = Theme.label(sidebar, { text = "Click units to lock or unlock them. Locked units are never sold.", size = "Small", color = C.BoneDim, align = Enum.TextXAlignment.Center, frameSize = UDim2.new(1, -8, 0, 48) })
		lockHint.Position = UDim2.fromOffset(4, 458)
		lockHint.TextWrapped = true
		lockHint.TextSize = 12
		lockHint.Visible = false
		lockHint.ZIndex = 37

		-- what "Sell" would do right now
		updateSellSummary = function()
			local count, gold = 0, 0
			local mult = LevelEconomy.sellGoldMultiplier(State.coinBoostLevel or 0)
			for i = 1, INVENTORY_MAX do
				local u = inventory[i]
				if u and not u.locked then
					local info = UNIT_INFO[u.unitType] or {}
					local rank = Rarities.Rank[info.rarity] or 1
					if rank <= sellMaxRank and not (keepUpgraded and (u.level or 0) > 0) then
						count += 1
						gold += math.floor(LevelEconomy.sellValue(u.oneIn or UNIT_ONE_IN[u.unitType] or 1) * mult)
					end
				end
			end
			summary.Text = count .. " units\n" .. Format.fmtGold(gold) .. " Gold"
			sellBtn.stone.root:SetAttribute("Disabled", count == 0)
		end
		updateSellSummary()
	end

	-- ── Scroll area ──────────────────────────────────────────
	invScroll = Instance.new("ScrollingFrame", body)
	invScroll.Size = UDim2.new(1, -182, 1, 0)
	invScroll.Position = UDim2.new(0, 182, 0, 0)
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
