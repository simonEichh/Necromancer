-- The Forge: upgrade units with materials, dismantle spare units into materials.
--
-- A "Forge" button on the left (under Graves) or the F key opens it. The list on the left shows the units standing on your
-- graves and the units in your inventory; click one to see its next level, what it costs, the chance of success and press
-- Upgrade. The row at the bottom shows your dusts (one per pair of rarities: a unit is upgraded with the dust of its own
-- rarity, Economy.dustOf). Dismantle turns a spare inventory unit into materials of its rarity. The server does everything (see
-- server UnitUpgrades): this panel only sends UpgradeUnit(kind, index) / DismantleUnit(slot) and shows what comes back.
-- Two tabs in the header: Upgrade (the above) and Buy Dust (gold for dust: Economy.dustPrice, a limited stock that refills
-- with the grave shop every 5 minutes, each dust unlocked at Economy.dustShopUnlock ascensions; the server checks
-- everything in UnitUpgrades, BuyDust). The dust row at the bottom stays visible on both tabs.
-- At the Forge stall the panel opens IN THE WORLD (WorldView + ForgeScene): the camera stands beside the anvil, the
-- selected unit stands on it, the panel moves to the right, and every upgrade / dismantle is played out on the anvil
-- (the DataSync is held until the animation shows the result; Skip button, Quick toggle). Opened anywhere else (Remote
-- Forge) it is the plain panel.
-- Builds its UI when required (no init call).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.Theme)
local State = require(script.Parent.State)
local Sync = require(script.Parent.Sync)
local GameData = require(script.Parent.GameData)
local UnitPortrait = require(script.Parent.UnitPortrait)
local SignatureName = require(script.Parent.SignatureName)
local Format = require(script.Parent.Format)
local WorldView = require(script.Parent.WorldView)
local ForgeScene = require(script.Parent.ForgeScene)
local Economy = require(ReplicatedStorage.Shared.Economy)
local Rarities = require(ReplicatedStorage.Shared.Rarities)

local C = Theme.Color
local Z = 36

local ForgePanel = {}

local upgradeRemote = ReplicatedStorage:WaitForChild("UpgradeUnit", 5)
local dismantleRemote = ReplicatedStorage:WaitForChild("DismantleUnit", 5)
local resultRemote = ReplicatedStorage:WaitForChild("UpgradeResult", 5)
local buyDustRemote = ReplicatedStorage:WaitForChild("BuyDust", 5)
local dustStockRemote = ReplicatedStorage:WaitForChild("DustStockUpdate", 5)

local selected = nil -- { kind = "inv" | "grave", index = number }
local startUpgradeAnim, startDismantleAnim -- (the in-world animations, defined with the wiring below)
local confirmDismantle = false -- the Dismantle button was pressed once and waits for a second press
local useCatalyst = { Fortune = false, Warding = false } -- switched on for the next upgrade attempt
local rowFrames = {} -- row frames by "kind:index", for the selection highlight

-- ============================================================
-- Frame
-- ============================================================
-- (its own ScreenGui: the in-world view switches every other one off)
local forgeGui = Instance.new("ScreenGui")
forgeGui.Name = "ForgeUI"
forgeGui.ResetOnSpawn = false
forgeGui.DisplayOrder = 5
forgeGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
local PANEL_W, PANEL_H = 800, 540
local themed = Theme.panel(forgeGui, { title = "Forge", size = UDim2.fromOffset(PANEL_W, PANEL_H), zIndex = Z })
local panel = themed.frame
panel.Name = "ForgePanel"
panel.Visible = false
require(script.Parent.Windows).register(panel) -- only one window open at a time
local body = themed.body

Theme.stoneButton(panel, {
	text = "X", color = "red", size = UDim2.fromOffset(44, 28),
	position = UDim2.new(1, -62, 0, 6), zIndex = Z + 2,
	onClick = function() panel.Visible = false end,
})

-- the list of units (left)
local list = Instance.new("ScrollingFrame")
list.BackgroundTransparency = 1
list.BorderSizePixel = 0
list.Size = UDim2.new(0, 300, 1, -84)
list.ScrollBarThickness = 6
list.ScrollBarImageColor3 = C.Verdigris
list.CanvasSize = UDim2.new()
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
list.ZIndex = Z + 2
list.Parent = body
local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 4)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = list
-- room round the rows so the selected row's outline is not clipped by the scrolling frame
local listPad = Instance.new("UIPadding")
listPad.PaddingTop = UDim.new(0, 3)
listPad.PaddingBottom = UDim.new(0, 3)
listPad.PaddingLeft = UDim.new(0, 3)
listPad.PaddingRight = UDim.new(0, 3)
listPad.Parent = list

-- the details of the selected unit (right)
local detail = Instance.new("Frame")
detail.BackgroundTransparency = 1
detail.Position = UDim2.fromOffset(312, 0)
detail.Size = UDim2.new(1, -312, 1, -84)
detail.ZIndex = Z + 2
detail.Parent = body

local portrait = UnitPortrait.attach(detail, { position = UDim2.new(0.5, -60, 0, 0), size = UDim2.fromOffset(120, 120), zIndex = Z + 3 })

local function line(y, size, font)
	local l = Theme.label(detail, { text = "", size = size or "Body", font = font or "Body", color = C.Bone, align = Enum.TextXAlignment.Center, frameSize = UDim2.new(1, 0, 0, 24) })
	l.Position = UDim2.fromOffset(0, y)
	l.ZIndex = Z + 3
	return l
end
local nameLbl = line(120, "Heading", "Strong")
local levelLbl = line(146)
local nextLbl = line(166)
local costLbl = line(188)
local chanceLbl = line(208)
local resultLbl = line(234, "Heading", "Strong")
resultLbl.TextTransparency = 1

local upgradeBtn = Theme.stoneButton(detail, {
	text = "Upgrade", color = "green", size = UDim2.fromOffset(150, 46),
	position = UDim2.new(0.5, -158, 0, 306), zIndex = Z + 3,
	onClick = function()
		if selected and upgradeRemote and not ForgeScene.busy() then
			confirmDismantle = false
			startUpgradeAnim()
			upgradeRemote:FireServer(selected.kind, selected.index, useCatalyst.Fortune, useCatalyst.Warding)
		end
	end,
})
-- (declared first: the click handler below refers to the button, and `local x = f(function() x end)` would see nil)
local dismantleBtn
dismantleBtn = Theme.stoneButton(detail, {
	text = "Dismantle", color = "red", size = UDim2.fromOffset(150, 46),
	position = UDim2.new(0.5, 8, 0, 306), zIndex = Z + 3,
	onClick = function()
		if not (selected and selected.kind == "inv" and dismantleRemote) then
			return
		end
		local unit = State.inventory[selected.index]
		if unit and (unit.level or 0) > 0 and not confirmDismantle then
			-- a levelled unit needs a second press (its levels are lost)
			confirmDismantle = true
			dismantleBtn.label.Text = "Sure?"
			task.delay(2, function()
				confirmDismantle = false
				dismantleBtn.label.Text = "Dismantle"
			end)
			return
		end
		confirmDismantle = false
		dismantleBtn.label.Text = "Dismantle"
		if ForgeScene.busy() then
			return
		end
		startDismantleAnim()
		dismantleRemote:FireServer(selected.index)
	end,
})
local hintLbl = Theme.label(detail, {
	text = "A failed upgrade costs half the materials and never lowers the level. Every failure makes the next try more likely.",
	size = "Small", color = C.BoneDim, align = Enum.TextXAlignment.Center, frameSize = UDim2.new(1, -20, 0, 36),
})
hintLbl.Position = UDim2.fromOffset(10, 354)
hintLbl.Size = UDim2.new(1, -20, 0, 34)

-- the catalysts: a toggle chip per catalyst (owned count, what it does; click to use it on the next attempt) and a small
-- Buy button (gems)
local buyCatalystRemote = ReplicatedStorage:WaitForChild("BuyCatalyst", 5)
local catalystUi = {}
local refreshDetails -- (forward-declared: toggling repaints the chance line)
for i, key in ipairs(Economy.CATALYSTS) do
	local info = Economy.CATALYST_INFO[key]
	local x = (i == 1) and 0 or 236
	local chip = Instance.new("TextButton")
	chip.AutoButtonColor = false
	chip.Text = ""
	chip.BackgroundColor3 = C.StoneRaised
	chip.BorderSizePixel = 0
	chip.Position = UDim2.fromOffset(x, 262)
	chip.Size = UDim2.fromOffset(150, 38)
	chip.ZIndex = Z + 3
	chip.Parent = detail
	Theme.corner(chip, Theme.Radius.Small)
	local stroke = Theme.stroke(chip, C.Border, 1)
	local title = Theme.label(chip, { text = info.name, size = "Small", font = "Strong", color = C.Bone, frameSize = UDim2.new(1, -10, 0, 18) })
	title.Position = UDim2.fromOffset(8, 2)
	title.ZIndex = Z + 4
	local sub = Theme.label(chip, { text = info.text, size = "Small", color = C.BoneDim, frameSize = UDim2.new(1, -10, 0, 16) })
	sub.Position = UDim2.fromOffset(8, 19)
	sub.ZIndex = Z + 4
	sub.TextSize = 11
	chip.Activated:Connect(function()
		if ((State.catalysts or {})[key] or 0) > 0 then
			useCatalyst[key] = not useCatalyst[key]
			if refreshDetails then
				refreshDetails()
			end
		end
	end)
	local buy = Theme.stoneButton(detail, {
		text = info.price .. " Gems", color = "blue", size = UDim2.fromOffset(78, 34),
		position = UDim2.fromOffset(x + 154, 264), zIndex = Z + 3,
		onClick = function()
			if buyCatalystRemote then
				buyCatalystRemote:FireServer(key, 1)
			end
		end,
	})
	catalystUi[key] = { chip = chip, stroke = stroke, title = title, sub = sub, buy = buy }
end

refreshDetails = function()
	ForgePanel.refresh() -- (defined further down; only called on a click)
end

local function paintCatalysts()
	for key, ui in pairs(catalystUi) do
		local info = Economy.CATALYST_INFO[key]
		local owned = (State.catalysts or {})[key] or 0
		if owned < 1 then
			useCatalyst[key] = false
		end
		local on = useCatalyst[key]
		ui.title.Text = info.name .. "  x" .. owned
		ui.title.TextColor3 = owned > 0 and C.Bone or C.BoneDim
		ui.stroke.Color = on and C.Soul or C.Border
		ui.stroke.Thickness = on and 2 or 1
		ui.chip.BackgroundColor3 = on and C.Void or C.StoneRaised
		ui.sub.Text = on and "ON for the next try" or info.text
		ui.sub.TextColor3 = on and C.Good or C.BoneDim
		ui.buy.root:SetAttribute("Disabled", (State.gems or 0) < info.price)
	end
end
hintLbl.TextWrapped = true
hintLbl.ZIndex = Z + 3

-- the materials row (bottom): one chip per dust
local DUST_COLORS = Theme.DustColor
local matBar = Instance.new("Frame")
matBar.BackgroundColor3 = C.Void
matBar.BorderSizePixel = 0
matBar.AnchorPoint = Vector2.new(0, 1)
matBar.Position = UDim2.fromScale(0, 1)
matBar.Size = UDim2.new(1, 0, 0, 74)
matBar.ZIndex = Z + 2
Theme.corner(matBar, Theme.Radius.Small)
Theme.stroke(matBar, C.Border, 1)
matBar.Parent = body
local matLayout = Instance.new("UIListLayout")
matLayout.FillDirection = Enum.FillDirection.Horizontal
matLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
matLayout.VerticalAlignment = Enum.VerticalAlignment.Center
matLayout.Padding = UDim.new(0, 4)
matLayout.Parent = matBar
local chips = {}
for i, dust in ipairs(Economy.DUSTS) do
	local chip = Instance.new("Frame")
	chip.BackgroundColor3 = C.StoneRaised
	chip.BorderSizePixel = 0
	chip.Size = UDim2.fromOffset(120, 58)
	chip.LayoutOrder = i
	chip.ZIndex = Z + 3
	Theme.corner(chip, Theme.Radius.Small)
	local stroke = Theme.stroke(chip, C.Border, 1)
	chip.Parent = matBar
	local color = DUST_COLORS[dust] or C.Bone
	local icon = Instance.new("ImageLabel")
	icon.BackgroundTransparency = 1
	icon.Image = Theme.Image.Dust[dust] or ""
	icon.Size = UDim2.fromOffset(40, 40)
	icon.AnchorPoint = Vector2.new(0, 0.5)
	icon.Position = UDim2.new(0, 2, 0.5, 0)
	icon.ZIndex = Z + 4
	icon.Parent = chip
	local nameText = Theme.label(chip, { text = Economy.DUST_NAMES[dust], size = "Small", font = "Strong", color = color, align = Enum.TextXAlignment.Center, frameSize = UDim2.new(1, -44, 0, 28) })
	nameText.Position = UDim2.fromOffset(42, 3)
	nameText.TextWrapped = true
	nameText.TextSize = 11
	nameText.ZIndex = Z + 4
	local countText = Theme.label(chip, { text = "0", size = "Heading", font = "Strong", color = C.Bone, align = Enum.TextXAlignment.Center, frameSize = UDim2.new(1, -42, 0, 24) })
	countText.Position = UDim2.fromOffset(42, 31)
	countText.ZIndex = Z + 4
	chips[dust] = { frame = chip, stroke = stroke, count = countText }
end

-- ============================================================
-- Buy Dust tab: one row per dust (icon, name, price, stock, Buy 1 / Buy 10), the restock timer on top
-- ============================================================
local dustStock = {} -- from the server (DustStockUpdate)
local restockAt = nil -- os.clock() of the next restock
local shop = Instance.new("Frame")
shop.BackgroundTransparency = 1
shop.Size = UDim2.new(1, 0, 1, -84)
shop.ZIndex = Z + 2
shop.Visible = false
shop.Parent = body
local restockLbl = Theme.label(shop, { text = "", size = "Body", color = C.BoneDim, align = Enum.TextXAlignment.Center, frameSize = UDim2.new(1, 0, 0, 24) })
restockLbl.ZIndex = Z + 3
local shopRows = {}
local paintShop -- (forward-declared: the Buy buttons repaint)
for i, dust in ipairs(Economy.DUSTS) do
	local row = Instance.new("Frame")
	row.BackgroundColor3 = C.StoneRaised
	row.BorderSizePixel = 0
	row.Position = UDim2.fromOffset(20, 30 + (i - 1) * 70)
	row.Size = UDim2.new(1, -40, 0, 62)
	row.ZIndex = Z + 3
	Theme.corner(row, Theme.Radius.Small)
	Theme.stroke(row, C.Border, 1)
	row.Parent = shop
	local color = DUST_COLORS[dust] or C.Bone
	local icon = Instance.new("ImageLabel")
	icon.BackgroundTransparency = 1
	icon.Image = Theme.Image.Dust[dust] or ""
	icon.Size = UDim2.fromOffset(50, 50)
	icon.Position = UDim2.fromOffset(8, 6)
	icon.ZIndex = Z + 4
	icon.Parent = row
	local nameText = Theme.label(row, { text = Economy.DUST_NAMES[dust], size = "Heading", font = "Strong", color = color, frameSize = UDim2.new(0, 190, 0, 30) })
	nameText.Position = UDim2.fromOffset(68, 4)
	nameText.ZIndex = Z + 4
	local priceText = Theme.label(row, { text = "", size = "Body", color = C.Bone, frameSize = UDim2.new(0, 190, 0, 24) })
	priceText.Position = UDim2.fromOffset(68, 32)
	priceText.ZIndex = Z + 4
	local stockText = Theme.label(row, { text = "", size = "Body", font = "Strong", color = C.Bone, align = Enum.TextXAlignment.Center, frameSize = UDim2.new(0, 120, 1, 0) })
	stockText.Position = UDim2.fromOffset(268, 0)
	stockText.ZIndex = Z + 4
	local function buy(qty)
		if buyDustRemote then
			buyDustRemote:FireServer(dust, qty)
		end
	end
	local buy1 = Theme.stoneButton(row, {
		text = "Buy 1", color = "green", size = UDim2.fromOffset(96, 40),
		position = UDim2.new(1, -212, 0.5, 0), anchor = Vector2.new(0, 0.5), zIndex = Z + 4,
		onClick = function() buy(1) end,
	})
	local buyAll = Theme.stoneButton(row, {
		text = "Buy 10", color = "gold", size = UDim2.fromOffset(96, 40),
		position = UDim2.new(1, -108, 0.5, 0), anchor = Vector2.new(0, 0.5), zIndex = Z + 4,
		onClick = function() buy(Economy.DUST_SHOP_STOCK) end,
	})
	shopRows[dust] = { index = i, row = row, price = priceText, stock = stockText, buy1 = buy1, buyAll = buyAll, name = nameText, icon = icon }
end

function paintShop()
	local ascension = State.rebirthCount or 0
	local gold = State.gold or 0
	for dust, r in pairs(shopRows) do
		local price = Economy.dustPrice(r.index)
		local unlock = Economy.dustShopUnlock(r.index)
		local left = dustStock[dust] or 0
		if ascension < unlock then
			r.price.Text = "Unlocks at ascension " .. unlock
			r.stock.Text = ""
			r.name.TextTransparency = 0.5
			r.icon.ImageTransparency = 0.6
			r.buy1.root.Visible = false
			r.buyAll.root.Visible = false
		else
			r.price.Text = Format.fmtGold(price) .. " Gold each"
			r.stock.Text = left > 0 and (left .. " / " .. Economy.DUST_SHOP_STOCK .. " left") or "Sold out"
			r.stock.TextColor3 = left > 0 and C.Bone or C.BoneDim
			r.name.TextTransparency = 0
			r.icon.ImageTransparency = 0
			r.buy1.root.Visible = true
			r.buyAll.root.Visible = true
			local most = math.min(left, math.floor(gold / price))
			r.buy1.root:SetAttribute("Disabled", most < 1)
			r.buyAll.root:SetAttribute("Disabled", most < 1)
			-- the second button buys as many as you can (up to the stock left); sold out it keeps its full label
			r.buyAll.label.Text = "Buy " .. ((most >= 1) and most or Economy.DUST_SHOP_STOCK)
		end
	end
end

local function paintRestock()
	if not restockAt then
		restockLbl.Text = ""
		return
	end
	local secs = math.max(0, math.floor(restockAt - os.clock()))
	restockLbl.Text = string.format("Restocks in %d:%02d", secs // 60, secs % 60)
end

if dustStockRemote then
	dustStockRemote.OnClientEvent:Connect(function(stock, secsLeft)
		dustStock = stock or {}
		restockAt = os.clock() + (secsLeft or 0)
		paintShop()
		paintRestock()
	end)
end

-- the two tabs in the header: each has a green (selected) and a grey version, one of them shown
local tab = "upgrade"
local tabButtons = {}
local setTab
local function makeTab(key, text, x)
	local t = {}
	for _, state in ipairs({ "on", "off" }) do
		t[state] = Theme.stoneButton(panel, {
			text = text, color = state == "on" and "green" or "stone", size = UDim2.fromOffset(120, 30),
			position = UDim2.fromOffset(x, 5), zIndex = Z + 2,
			onClick = function() setTab(key) end,
		})
	end
	tabButtons[key] = t
end
function setTab(name)
	tab = name
	list.Visible = name == "upgrade"
	detail.Visible = name == "upgrade"
	shop.Visible = name == "dust"
	for key, t in pairs(tabButtons) do
		t.on.root.Visible = key == name
		t.off.root.Visible = key ~= name
	end
	if name == "dust" then
		paintShop()
		paintRestock()
	end
end
makeTab("upgrade", "Upgrade", 110)
makeTab("dust", "Buy Dust", 238)
setTab("upgrade")

-- ============================================================
-- Data
-- ============================================================
local function rarityOf(unitType)
	local info = GameData.UNIT_INFO[unitType]
	return info and info.rarity or "Common"
end

-- every unit you can upgrade: the ones on the graves first, then the inventory (best rarity and level first)
local function collectEntries()
	local entries = {}
	for _, p in ipairs(State.placed or {}) do
		table.insert(entries, { kind = "grave", index = p.slot, unitType = p.unitType, level = p.level or 0, fails = p.fails or 0 })
	end
	local inv = {}
	for slot, unit in pairs(State.inventory) do
		table.insert(inv, { kind = "inv", index = slot, unitType = unit.unitType, level = unit.level or 0, fails = unit.fails or 0 })
	end
	table.sort(inv, function(a, b)
		local ra, rb = Rarities.Rank[rarityOf(a.unitType)] or 0, Rarities.Rank[rarityOf(b.unitType)] or 0
		if ra ~= rb then
			return ra > rb
		end
		if a.level ~= b.level then
			return a.level > b.level
		end
		return a.index < b.index
	end)
	for _, e in ipairs(inv) do
		table.insert(entries, e)
	end
	return entries
end

local function findEntry(entries)
	for _, e in ipairs(entries) do
		if selected and e.kind == selected.kind and e.index == selected.index then
			return e
		end
	end
	return nil
end

-- ============================================================
-- Drawing
-- ============================================================
local function showDetails(entry)
	paintCatalysts()
	for _, ui in pairs(catalystUi) do
		ui.chip.Visible = entry ~= nil
		ui.buy.root.Visible = entry ~= nil
	end
	if not entry then
		portrait.set(nil)
		nameLbl.Text = "Select a unit"
		nameLbl.TextColor3 = C.BoneDim
		levelLbl.Text, nextLbl.Text, costLbl.Text, chanceLbl.Text = "", "", "", ""
		upgradeBtn.root.Visible = false
		dismantleBtn.root.Visible = false
		return
	end
	local rarity = rarityOf(entry.unitType)
	local dust = Economy.dustOf(rarity)
	local material = Economy.DUST_NAMES[dust]
	portrait.set(entry.unitType)
	nameLbl.Text = entry.unitType
	SignatureName.apply(nameLbl, nil) -- (reset, then the rarity colour below, then the burn for Signature units)
	nameLbl.TextColor3 = Theme.rarityColor(rarity)
	SignatureName.apply(nameLbl, entry.unitType)
	upgradeBtn.root.Visible = true
	dismantleBtn.root.Visible = (entry.kind == "inv")

	if entry.level >= Economy.MAX_UNIT_LEVEL then
		levelLbl.Text = "Level " .. entry.level .. " / " .. Economy.MAX_UNIT_LEVEL .. "   (maximum)   Damage x" .. string.format("%.1f", Economy.levelMultiplier(entry.level))
		nextLbl.Text, costLbl.Text, chanceLbl.Text = "", "", ""
		upgradeBtn.root:SetAttribute("Disabled", true)
	else
		local cost = Economy.unitUpgradeCost(entry.level, rarity)
		local have = (State.materials and State.materials[dust]) or 0
		local chance = Economy.upgradeChance(entry.level, entry.fails)
		local boosted = useCatalyst.Fortune and chance < 1
		if boosted then
			chance = math.min(1, chance + Economy.FORTUNE_BONUS)
		end
		levelLbl.Text = "Level " .. entry.level .. " / " .. Economy.MAX_UNIT_LEVEL .. "   Damage x" .. string.format("%.1f", Economy.levelMultiplier(entry.level))
		nextLbl.Text = "Next level: damage x" .. string.format("%.1f", Economy.levelMultiplier(entry.level + 1))
		costLbl.Text = "Costs " .. cost .. " " .. material .. "   (you have " .. have .. ")"
		costLbl.TextColor3 = (have >= cost) and C.Bone or C.Warn
		chanceLbl.Text = "Success chance " .. math.floor(chance * 100 + 0.5) .. "%" .. (entry.fails > 0 and ("   (+" .. entry.fails * 10 .. "% from failed tries)") or "")
			.. (boosted and "   (Fortune +25%)" or "")
		chanceLbl.TextColor3 = chance >= 0.7 and C.Good or (chance >= 0.45 and C.Bone or C.Warn)
		upgradeBtn.root:SetAttribute("Disabled", have < cost)
	end
	if entry.kind == "inv" then
		local rank = Rarities.Rank[rarity] or 1
		dismantleBtn.label.Text = confirmDismantle and "Sure?" or "Dismantle"
		hintLbl.Text = "Dismantle gives " .. Economy.dismantleYield(rank) .. " " .. material .. ". A failed upgrade costs half the materials and never lowers the level; every failure makes the next try more likely."
	else
		hintLbl.Text = "A failed upgrade costs half the materials and never lowers the level. Every failure makes the next try more likely. (Units on graves cannot be dismantled.)"
	end
end

local function paintMaterials(entry)
	local selectedDust = entry and Economy.dustOf(rarityOf(entry.unitType))
	for dust, chip in pairs(chips) do
		local count = (State.materials and State.materials[dust]) or 0
		chip.count.Text = tostring(count)
		chip.count.TextColor3 = count > 0 and C.Bone or C.BoneDim
		chip.stroke.Color = (dust == selectedDust) and C.Soul or C.Border
		chip.stroke.Thickness = (dust == selectedDust) and 2 or 1
	end
end

local function select(kind, index)
	if ForgeScene.busy() then
		return
	end
	selected = { kind = kind, index = index }
	confirmDismantle = false
	ForgePanel.refresh()
end

function ForgePanel.refresh()
	if not panel.Visible then
		return
	end
	local entries = collectEntries()
	if not findEntry(entries) then
		selected = entries[1] and { kind = entries[1].kind, index = entries[1].index } or nil
	end
	local entry = findEntry(entries)

	-- rebuild the rows (cheap: plain frames and text, no portraits)
	for _, row in pairs(rowFrames) do
		row:Destroy()
	end
	table.clear(rowFrames)
	for i, e in ipairs(entries) do
		local rarity = rarityOf(e.unitType)
		local isSel = entry and e.kind == entry.kind and e.index == entry.index
		local row = Instance.new("TextButton")
		row.Text = ""
		row.AutoButtonColor = false
		row.LayoutOrder = i
		row.Size = UDim2.new(1, -8, 0, 38)
		row.BackgroundColor3 = isSel and C.StoneHover or C.StoneRaised
		row.BorderSizePixel = 0
		row.ZIndex = Z + 3
		Theme.corner(row, Theme.Radius.Small)
		Theme.stroke(row, isSel and C.Soul or C.Border, isSel and 2 or 1)
		row.Parent = list
		local bar = Instance.new("Frame")
		bar.BackgroundColor3 = Theme.rarityColor(rarity)
		bar.BorderSizePixel = 0
		bar.Size = UDim2.new(0, 5, 1, -8)
		bar.Position = UDim2.fromOffset(5, 4)
		bar.ZIndex = Z + 4
		bar.Parent = row
		local name = Theme.label(row, { text = e.unitType, size = "Body", font = "Strong", color = C.Bone, frameSize = UDim2.new(1, -120, 1, 0) })
		name.Position = UDim2.fromOffset(18, 0)
		name.ZIndex = Z + 4
		local tag = Theme.label(row, {
			text = (e.kind == "grave" and "Grave  " or "") .. "Lv " .. e.level,
			size = "Small", font = "Strong", color = e.level >= Economy.MAX_UNIT_LEVEL and C.Gold or C.BoneDim, align = Enum.TextXAlignment.Right,
			frameSize = UDim2.new(0, 110, 1, 0),
		})
		tag.Position = UDim2.new(1, -118, 0, 0)
		tag.ZIndex = Z + 4
		local key = e.kind
		local index = e.index
		row.Activated:Connect(function()
			select(key, index)
		end)
		rowFrames[i] = row
	end
	showDetails(entry)
	paintMaterials(entry)
	if ForgeScene.active() and not ForgeScene.busy() then
		ForgeScene.showUnit(entry and entry.unitType, entry and entry.level or 0)
	end
end

function ForgePanel.toggle()
	panel.Visible = not panel.Visible
	if panel.Visible then
		ForgePanel.refresh()
	end
end

function ForgePanel.isVisible()
	return panel.Visible
end

-- ============================================================
-- Wiring
-- ============================================================
-- The Forge only opens at the Forge stall (its prompt fires OpenForge) and closes when the player walks away.
-- (A "Remote Forge" premium purchase could later open it from anywhere.)
local FORGE_RANGE = 22 -- a bit less than the server's range, so the panel closes before requests would be refused
local openForgeRemote = ReplicatedStorage:WaitForChild("OpenForge", 10)
if openForgeRemote then
	openForgeRemote.OnClientEvent:Connect(function()
		if not panel.Visible then
			ForgePanel.toggle()
		end
	end)
end
task.spawn(function()
	while true do
		task.wait(0.5)
		if panel.Visible and tab == "dust" then
			paintRestock()
		end
		if panel.Visible then
			local shops = workspace:FindFirstChild("Shops")
			local anchor = shops and shops:FindFirstChild("ForgeKeeper")
			local character = Players.LocalPlayer.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if anchor and root and not State.remoteForge and (root.Position - anchor.Position).Magnitude > FORGE_RANGE then
				panel.Visible = false
			end
		end
	end
end)

-- ============================================================
-- In the world (at the Forge stall)
-- ============================================================
local view -- the WorldView session while the Forge is open at the stall
local quick = false -- the Quick toggle: shorter animations
local pendingAnim -- the in-world upgrade waiting for the server's answer
local showResult -- (defined with the result handler below)

-- the panel stands on the right while the anvil fills the left of the screen
local panelScale = panel:FindFirstChildOfClass("UIScale")
local function layoutInWorld()
	if not view then
		return
	end
	local screen = forgeGui.AbsoluteSize
	panel.AnchorPoint = Vector2.new(1, 0.5)
	panel.Position = UDim2.new(1, -40, 0.5, 0)
	if panelScale and screen.X > 0 then
		panelScale.Scale = math.clamp(math.min(screen.X * 0.56 / (PANEL_W + 56), (screen.Y - 60) / (PANEL_H + 56)), 0.4, 1)
	end
end
forgeGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
	task.defer(layoutInWorld) -- (after Theme's own fit)
end)

local skipBtn = Theme.stoneButton(forgeGui, {
	text = "Skip", color = "stone", size = UDim2.fromOffset(110, 40),
	anchor = Vector2.new(0, 1), position = UDim2.new(0, 40, 1, -40), zIndex = Z + 4,
	onClick = function()
		ForgeScene.skip()
	end,
})
skipBtn.root.Visible = false
local quickBtn
local function paintQuick()
	quickBtn.label.Text = quick and "Quick: On" or "Quick: Off"
end
quickBtn = Theme.stoneButton(detail, {
	text = "Quick: Off", color = "stone", size = UDim2.fromOffset(120, 30),
	position = UDim2.new(1, -124, 0, 0), zIndex = Z + 4,
	onClick = function()
		quick = not quick
		paintQuick()
	end,
})
quickBtn.root.Visible = false

local function setBusy(busy)
	skipBtn.root.Visible = busy
	if busy then
		upgradeBtn.root:SetAttribute("Disabled", true)
		dismantleBtn.root:SetAttribute("Disabled", true)
	else
		dismantleBtn.root:SetAttribute("Disabled", false)
	end
end

local function selectedEntry()
	return selected and findEntry(collectEntries())
end

startUpgradeAnim = function()
	local entry = selectedEntry()
	if not (ForgeScene.active() and entry) then
		return
	end
	Sync.hold()
	setBusy(true)
	pendingAnim = ForgeScene.playUpgrade({
		dust = Economy.dustOf(rarityOf(entry.unitType)),
		fortune = useCatalyst.Fortune,
		warding = useCatalyst.Warding,
		quick = quick,
		onDone = function()
			local anim = pendingAnim
			pendingAnim = nil
			setBusy(false)
			Sync.release()
			if anim and anim.text then
				showResult(table.unpack(anim.text))
			end
			ForgePanel.refresh()
		end,
	})
end

startDismantleAnim = function()
	local entry = selectedEntry()
	if not (ForgeScene.active() and entry) then
		return
	end
	Sync.hold()
	setBusy(true)
	ForgeScene.playDismantle({
		dust = Economy.dustOf(rarityOf(entry.unitType)),
		quick = quick,
		onDone = function()
			setBusy(false)
			Sync.release()
			ForgePanel.refresh()
		end,
	})
end

local function openInWorld()
	if view or not ForgeScene.available() or not ForgeScene.start() then
		return
	end
	view = WorldView.open({
		keep = { forgeGui },
		openTime = 0.9,
		fov = 50,
		goal = function()
			return ForgeScene.cameraCFrame()
		end,
		onStep = function(v, _, k)
			ForgeScene.hideCharacter(v.char, k > 0.4) -- (the character stands between the camera and the anvil)
			ForgeScene.setBlend(k) -- (the Forge's magic circle floats down onto the anvil with the glide)
		end,
		onFinish = function(v)
			ForgeScene.hideCharacter(v.char, false)
			if view == v then
				view = nil
			end
			ForgeScene.stop()
			pendingAnim = nil
			setBusy(false)
			Sync.release()
			quickBtn.root.Visible = false
			panel.Visible = false
			-- back to the plain centred panel: nudging the size makes Theme's fit place and scale it again
			panel.AnchorPoint = Vector2.new(0.5, 0.5)
			panel.Size = UDim2.fromOffset(PANEL_W, PANEL_H + 1)
			panel.Size = UDim2.fromOffset(PANEL_W, PANEL_H)
		end,
	})
	if not view then
		ForgeScene.stop()
		return
	end
	quickBtn.root.Visible = true
	paintQuick()
	layoutInWorld()
	ForgePanel.refresh()
end

panel:GetPropertyChangedSignal("Visible"):Connect(function()
	if panel.Visible then
		openInWorld()
	elseif view then
		view:close()
	end
end)

-- new data from the server: redraw (also keeps the numbers right after an upgrade)
Sync.onApplied(function()
	ForgePanel.refresh()
	if tab == "dust" then
		paintShop()
	end
end)

-- the result of an upgrade attempt
if resultRemote then
	resultRemote.OnClientEvent:Connect(function(success, unitType, level, chance)
		if pendingAnim then
			-- the anvil shows it first; the text follows when the animation ends
			pendingAnim.resolve(success, level)
			pendingAnim.text = { success, unitType, level, chance }
			return
		end
		showResult(success, unitType, level, chance)
	end)
end

function showResult(success, unitType, level, chance)
	do
		resultLbl.TextTransparency = 0
		if success then
			resultLbl.Text = "SUCCESS!  " .. unitType .. " is now level " .. level
			resultLbl.TextColor3 = C.Good
		else
			resultLbl.Text = "Failed (" .. math.floor((chance or 0) * 100 + 0.5) .. "% chance). The next try is more likely."
			resultLbl.TextColor3 = C.Blood
		end
		TweenService:Create(resultLbl, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 2), { TextTransparency = 1 }):Play()
	end
end

return ForgePanel
