-- The Codex: every pullable unit, read in the necromancer's own grimoire (the book the pull cinematics absorb units into).
-- Opened with the "Codex" tile (right HUD column) or C: the character holds the grimoire up in their left hand, it opens,
-- the camera glides over their shoulder and zooms onto the pages, and the book UI fades in exactly over them. Closing
-- (X, Esc or C) plays it backwards.
-- The book: one spread per rarity (Common .. Primordial; a rarity with more than four units runs over onto more spreads), the rarity's units on the two pages: a 3D portrait, the name,
-- "1 in X", base DPS and how many the player has ever pulled. Units never pulled are a black silhouette with "???".
-- Discovered = State.codex (server PlayerData.codex, saved; counted in Digging, older saves filled from the inventory and
-- the graves). Builds its UI when required (no init call).
-- Pressing a unit opens its page over the spread: on the left the unit big (3D), its name, title, rarity, odds, base DPS
-- and how often it was pulled; on the right its abilities (Units.Abilities: name, kind, a short text with the numbers
-- highlighted; locked ones show how to unlock them, e.g. Fleet Strike for gems). Back (or Esc) returns to the spread.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Theme = require(script.Parent.Theme)
local State = require(script.Parent.State)
local Sync = require(script.Parent.Sync)
local screenGui = require(script.Parent.Gui)
local Format = require(script.Parent.Format)
local UnitPortrait = require(script.Parent.UnitPortrait)
local SignatureName = require(script.Parent.SignatureName)
local NecroRitual = require(script.Parent.NecroRitual)
local WorldView = require(script.Parent.WorldView)
local Units = require(ReplicatedStorage.Shared.Units)
local Rarities = require(ReplicatedStorage.Shared.Rarities)
local Economy = require(ReplicatedStorage.Shared.Economy)

local player = Players.LocalPlayer
local C = Theme.Color

local CodexPanel = {}
CodexPanel.active = false

local T_OPEN = 1.2 -- the book is raised and opened, the camera zooms onto it
local T_CLOSE = 0.9
local PAGE = Color3.fromRGB(46, 38, 33)
local PAGE_EDGE = Color3.fromRGB(122, 98, 62)
local INK = Color3.fromRGB(222, 210, 182)
local INK_DIM = Color3.fromRGB(150, 138, 116)
local HIGHLIGHT = "#F2C46B" -- (the numbers in ability texts)
local KIND_COLOR = { Passive = Color3.fromRGB(120, 230, 170), Basic = Color3.fromRGB(222, 210, 182), Special = Color3.fromRGB(190, 150, 255), Finisher = Color3.fromRGB(255, 140, 110) }
local KIND_ORDER = { Passive = 1, Basic = 2, Special = 3, Finisher = 4 } -- (the passive always first)
local KIND_LABEL = { Basic = "BASIC ATTACK" }

local function smooth(x)
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end
local function prettyName(key)
	return (key:gsub("(%l)(%u)", "%1 %2"))
end
local function fmt(n)
	return Format.fmtGold and Format.fmtGold(n) or tostring(n)
end

-- the rarities, lowest first, and their units
local RARITY_LIST = {}
for i = #Rarities.Order, 1, -1 do
	table.insert(RARITY_LIST, Rarities.Order[i])
end
local TOTAL = 0
for _, rarity in ipairs(RARITY_LIST) do
	TOTAL += #(Units.Pools[rarity] or {})
end

-- ============================================================
-- The book UI (a CanvasGroup so it can fade as one)
-- ============================================================
local ui = Instance.new("ScreenGui")
ui.Name = "CodexUI"
ui.ResetOnSpawn = false
ui.IgnoreGuiInset = true
ui.DisplayOrder = 20
ui.Enabled = false
ui.Parent = player:WaitForChild("PlayerGui")

local book = Instance.new("CanvasGroup")
book.AnchorPoint = Vector2.new(0.5, 0.5)
book.Position = UDim2.fromScale(0.5, 0.5)
book.Size = UDim2.fromScale(0.86, 0.84)
book.BackgroundTransparency = 1
book.GroupTransparency = 1
book.Parent = ui
local aspect = Instance.new("UIAspectRatioConstraint")
aspect.AspectRatio = 1.55
aspect.Parent = book

local pages = {}
for side = 0, 1 do
	local pg = Instance.new("Frame")
	pg.Position = UDim2.fromScale(side * 0.5, 0)
	pg.Size = UDim2.fromScale(0.5, 1)
	pg.BackgroundColor3 = PAGE
	pg.BorderSizePixel = 0
	pg.Parent = book
	Theme.corner(pg, 10)
	Theme.stroke(pg, PAGE_EDGE, 3)
	-- the spine's shadow on the inner edge
	local shade = Instance.new("Frame")
	shade.BorderSizePixel = 0
	shade.BackgroundColor3 = Color3.new(0, 0, 0)
	shade.Size = UDim2.fromScale(0.08, 1)
	shade.Position = UDim2.fromScale(side == 0 and 0.92 or 0, 0)
	shade.Parent = pg
	local g = Instance.new("UIGradient")
	g.Transparency = NumberSequence.new(side == 0 and 1 or 0.45, side == 0 and 0.45 or 1)
	g.Parent = shade
	pages[side + 1] = pg
end

local function text(parent, props)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = props.font or Enum.Font.FredokaOne
	l.TextColor3 = props.color or INK
	l.TextScaled = true
	l.TextXAlignment = props.align or Enum.TextXAlignment.Left
	l.Text = props.text or ""
	l.Size = props.size
	l.Position = props.position
	l.Parent = parent
	return l
end

-- left page header: the rarity and how many of it are discovered; right page footer: the total
local rarityTitle = text(pages[1], { size = UDim2.fromScale(0.8, 0.09), position = UDim2.fromScale(0.08, 0.04) })
local rarityCount = text(pages[1], { size = UDim2.fromScale(0.8, 0.045), position = UDim2.fromScale(0.08, 0.13), font = Enum.Font.GothamMedium, color = INK_DIM })
local totalLbl = text(pages[2], { size = UDim2.fromScale(0.8, 0.045), position = UDim2.fromScale(0.12, 0.04), font = Enum.Font.GothamMedium, color = INK_DIM, align = Enum.TextXAlignment.Right })
local pageLbl = text(book, { size = UDim2.fromScale(0.12, 0.04), position = UDim2.fromScale(0.44, 0.93), font = Enum.Font.GothamMedium, color = INK_DIM, align = Enum.TextXAlignment.Center })

-- four unit entries: two on each page
local entries = {}
local ENTRY_SLOTS = {
	{ page = 1, y = 0.22 }, { page = 1, y = 0.56 }, { page = 2, y = 0.12 }, { page = 2, y = 0.48 },
}
for i, slot in ipairs(ENTRY_SLOTS) do
	local f = Instance.new("Frame")
	f.BackgroundColor3 = Color3.fromRGB(34, 28, 25)
	f.BorderSizePixel = 0
	f.Position = UDim2.fromScale(0.07, slot.y)
	f.Size = UDim2.fromScale(0.86, 0.31)
	f.Parent = pages[slot.page]
	Theme.corner(f, 8)
	local stroke = Theme.stroke(f, PAGE_EDGE, 2)
	local portraitHolder = Instance.new("Frame")
	portraitHolder.BackgroundTransparency = 1
	portraitHolder.Size = UDim2.fromScale(0.36, 0.92)
	portraitHolder.Position = UDim2.fromScale(0.02, 0.04)
	portraitHolder.Parent = f
	local portrait = UnitPortrait.attach(portraitHolder, { size = UDim2.fromScale(1, 1), zIndex = 3 })
	local name = text(f, { size = UDim2.fromScale(0.58, 0.22), position = UDim2.fromScale(0.4, 0.05) })
	-- the unit's title under its name, like a Dead by Daylight killer's ("The Envoy"; `title` in its def; also shown undiscovered)
	local title = text(f, { size = UDim2.fromScale(0.58, 0.1), position = UDim2.fromScale(0.4, 0.26), font = Enum.Font.Garamond, color = INK_DIM })
	local odds = text(f, { size = UDim2.fromScale(0.58, 0.15), position = UDim2.fromScale(0.4, 0.38), font = Enum.Font.GothamMedium, color = INK_DIM })
	local dps = text(f, { size = UDim2.fromScale(0.58, 0.15), position = UDim2.fromScale(0.4, 0.56), font = Enum.Font.GothamMedium, color = INK_DIM })
	local pulled = text(f, { size = UDim2.fromScale(0.58, 0.15), position = UDim2.fromScale(0.4, 0.74), font = Enum.Font.GothamMedium, color = INK_DIM })
	-- the whole entry opens the unit's page
	local open = Instance.new("TextButton")
	open.BackgroundTransparency = 1
	open.Text = ""
	open.Size = UDim2.fromScale(1, 1)
	open.ZIndex = 6
	open.Parent = f
	local hint = text(f, { size = UDim2.fromScale(0.3, 0.1), position = UDim2.fromScale(0.67, 0.86), font = Enum.Font.GothamMedium, color = INK_DIM, align = Enum.TextXAlignment.Right })
	hint.Text = "Read more"
	entries[i] = { frame = f, stroke = stroke, portrait = portrait, name = name, title = title, odds = odds, dps = dps, pulled = pulled, open = open, hint = hint }
end

-- page turning, bookmarks, close
-- the spreads: four entries each, so a rarity with more units gets several ({ rarity, first = index of its first unit })
local SPREADS = {}
for _, rarity in ipairs(RARITY_LIST) do
	local count = #(Units.Pools[rarity] or {})
	for first = 1, math.max(1, count), #ENTRY_SLOTS do
		table.insert(SPREADS, { rarity = rarity, first = first })
	end
end
local spread = 1
local paint
local showDetail
local function turn(delta)
	spread = math.clamp(spread + delta, 1, #SPREADS)
	if showDetail then
		showDetail(nil)
	end
	paint()
end
Theme.stoneButton(book, {
	text = "<", size = UDim2.fromOffset(60, 40), position = UDim2.fromScale(0.03, 0.91), zIndex = 5,
	onClick = function() turn(-1) end,
})
Theme.stoneButton(book, {
	text = ">", size = UDim2.fromOffset(60, 40), position = UDim2.new(0.97, -60, 0.91, 0), zIndex = 5,
	onClick = function() turn(1) end,
})
Theme.stoneButton(book, {
	text = "X", color = "red", size = UDim2.fromOffset(44, 32), position = UDim2.new(1, -54, 0, 8), zIndex = 5,
	onClick = function() CodexPanel.close() end,
})
-- the bookmarks stick out above the book: a CanvasGroup cuts off what lies outside it (they could hardly be seen or
-- clicked), so they sit in a plain frame laid over the book and fade with it
local tabLayer = Instance.new("Frame")
tabLayer.AnchorPoint = book.AnchorPoint
tabLayer.Position = book.Position
tabLayer.Size = book.Size
tabLayer.BackgroundTransparency = 1
tabLayer.Parent = ui
local tabAspect = aspect:Clone()
tabAspect.Parent = tabLayer
local bookmarks = {}
book:GetPropertyChangedSignal("GroupTransparency"):Connect(function()
	for _, b in ipairs(bookmarks) do
		b.BackgroundTransparency = book.GroupTransparency
		b.Visible = book.GroupTransparency < 0.99
	end
end)
for i, rarity in ipairs(RARITY_LIST) do
	local b = Instance.new("TextButton")
	b.AutoButtonColor = false
	b.Text = ""
	b.BorderSizePixel = 0
	b.BackgroundColor3 = Rarities.Color[rarity] or Color3.new(1, 1, 1)
	b.AnchorPoint = Vector2.new(0.5, 1)
	b.Size = UDim2.fromScale(0.035, 0.07)
	b.Position = UDim2.fromScale(0.62 + (i - 1) * 0.04, 0.012)
	b.BackgroundTransparency = book.GroupTransparency
	b.Visible = false
	b.Parent = tabLayer
	Theme.corner(b, 4)
	b.Activated:Connect(function()
		for k, sp in ipairs(SPREADS) do
			if sp.rarity == rarity then
				spread = k
				break
			end
		end
		if showDetail then
			showDetail(nil)
		end
		paint()
	end)
	bookmarks[i] = b
end

-- ============================================================
-- The unit page (over the spread)
-- ============================================================
local detail = { unitType = nil }
local function detailPage(pageFrame)
	local f = Instance.new("Frame")
	f.BackgroundColor3 = PAGE
	f.BorderSizePixel = 0
	f.Size = UDim2.fromScale(1, 1)
	f.ZIndex = 10
	f.Visible = false
	f.Parent = pageFrame
	Theme.corner(f, 10)
	return f
end
local detailLeft, detailRight = detailPage(pages[1]), detailPage(pages[2])
local function dtext(parent, props)
	local l = text(parent, props)
	l.ZIndex = 11
	return l
end
local bigHolder = Instance.new("Frame")
bigHolder.BackgroundTransparency = 1
bigHolder.Size = UDim2.fromScale(0.84, 0.38)
bigHolder.Position = UDim2.fromScale(0.08, 0.03)
bigHolder.ZIndex = 11
bigHolder.Parent = detailLeft
local bigPortrait = UnitPortrait.attach(bigHolder, { size = UDim2.fromScale(1, 1), zIndex = 12, animate = true }) -- (plays its idle)
local dName = dtext(detailLeft, { size = UDim2.fromScale(0.84, 0.07), position = UDim2.fromScale(0.08, 0.42), align = Enum.TextXAlignment.Center })
local dTitle = dtext(detailLeft, { size = UDim2.fromScale(0.84, 0.04), position = UDim2.fromScale(0.08, 0.495), font = Enum.Font.Garamond, color = INK_DIM, align = Enum.TextXAlignment.Center })
local dRarity = dtext(detailLeft, { size = UDim2.fromScale(0.84, 0.04), position = UDim2.fromScale(0.08, 0.54), font = Enum.Font.GothamBold, align = Enum.TextXAlignment.Center })
local dStats = {}
for k = 1, 3 do
	dStats[k] = dtext(detailLeft, { size = UDim2.fromScale(0.27, 0.035), position = UDim2.fromScale(0.08 + (k - 1) * 0.285, 0.595), font = Enum.Font.GothamMedium, color = INK_DIM, align = Enum.TextXAlignment.Center })
end
-- the description (Units.Descriptions): a plain line for normal units, a little lore for Signatures and Sovereigns
local descBox = Instance.new("Frame")
descBox.BackgroundColor3 = Color3.fromRGB(34, 28, 25)
descBox.BorderSizePixel = 0
descBox.Size = UDim2.fromScale(0.84, 0.26)
descBox.Position = UDim2.fromScale(0.08, 0.65)
descBox.ZIndex = 11
descBox.Parent = detailLeft
Theme.corner(descBox, 8)
Theme.stroke(descBox, PAGE_EDGE, 1)
local dDesc = dtext(descBox, { size = UDim2.fromScale(0.9, 0.84), position = UDim2.fromScale(0.05, 0.08), font = Enum.Font.Garamond, color = INK })
dDesc.ZIndex = 12
dDesc.TextWrapped = true
dDesc.TextYAlignment = Enum.TextYAlignment.Top
local descLimit = Instance.new("UITextSizeConstraint")
descLimit.MaxTextSize = 30
descLimit.Parent = dDesc
local backBtn = Theme.stoneButton(detailLeft, {
	text = "< Back", size = UDim2.fromOffset(110, 36), position = UDim2.fromScale(0.04, 0.985), anchor = Vector2.new(0, 1), zIndex = 13,
	onClick = function() CodexPanel.back() end,
})
dtext(detailRight, { text = "ABILITIES", size = UDim2.fromScale(0.5, 0.07), position = UDim2.fromScale(0.08, 0.04) })
-- base numbers (a level 0 unit, no ascension) or YOUR numbers (your ascensions, Army Might, your best copy's level and
-- the strongest aura among your placed units: the same factors as the server's Army.ownerDamageMultiplier)
local showYours = false
local paintDetail
local yoursBtn = Theme.stoneButton(detailRight, {
	text = "Base damage", size = UDim2.fromOffset(170, 34), position = UDim2.fromScale(0.93, 0.045), anchor = Vector2.new(1, 0), zIndex = 13,
	onClick = function()
		showYours = not showYours
		paintDetail()
	end,
})
local function bestLevel(unitType)
	local best
	for _, u in pairs(State.inventory or {}) do
		if u.unitType == unitType then best = math.max(best or 0, u.level or 0) end
	end
	for _, u in ipairs(State.placed or {}) do
		if u.unitType == unitType then best = math.max(best or 0, u.level or 0) end
	end
	return best
end
local function yourMultiplier(unitType)
	local mult = Economy.damageMultiplier(State.rebirthCount or 0)
		* Economy.realmUpgradeEffect("might", (State.realmUpgrades or {}).might or 0)
		* Economy.levelMultiplier(bestLevel(unitType) or 0)
	local aura = 0
	for _, u in ipairs(State.placed or {}) do
		local d = Units.Stats[u.unitType]
		if d and d.aura and d.aura.damage then aura = math.max(aura, d.aura.damage) end
	end
	return mult * (1 + aura)
end
local abilityList = Instance.new("Frame")
abilityList.BackgroundTransparency = 1
abilityList.Size = UDim2.fromScale(0.86, 0.84)
abilityList.Position = UDim2.fromScale(0.07, 0.13)
abilityList.ZIndex = 11
abilityList.Parent = detailRight
local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0.025, 0)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = abilityList

-- "{25 s}" -> the number highlighted (rich text)
local function highlight(str)
	str = str:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")
	return (str:gsub("{(.-)}", function(num)
		-- (a non-breaking space inside, so "4.5 s" never breaks over two lines)
		local kept = num:gsub(" ", "\u{00A0}")
		return '<font color="' .. HIGHLIGHT .. '"><b>' .. kept .. "</b></font>"
	end))
end

local function abilityCard(order, ab, def, discovered, height)
	local unlock = ab.unlock
	local locked = unlock ~= nil and not State[unlock.state]
	local card = Instance.new("Frame")
	card.BackgroundColor3 = Color3.fromRGB(34, 28, 25)
	card.BorderSizePixel = 0
	card.Size = UDim2.fromScale(1, height)
	card.LayoutOrder = order
	card.ZIndex = 11
	card.Parent = abilityList
	Theme.corner(card, 8)
	Theme.stroke(card, locked and PAGE_EDGE or (KIND_COLOR[ab.kind] or PAGE_EDGE), 2)
	local kindColor = KIND_COLOR[ab.kind] or INK
	local nameLbl = dtext(card, { text = discovered and string.upper(ab.name) or "???", size = UDim2.fromScale(0.54, 0.2), position = UDim2.fromScale(0.04, 0.06), color = locked and INK_DIM or kindColor })
	nameLbl.ZIndex = 12
	local tag = dtext(card, { text = (KIND_LABEL[ab.kind] or string.upper(ab.kind)) .. (locked and "  -  LOCKED" or ""), size = UDim2.fromScale(0.36, 0.11), position = UDim2.fromScale(0.6, 0.09), font = Enum.Font.GothamBold, color = locked and INK_DIM or kindColor, align = Enum.TextXAlignment.Right })
	tag.ZIndex = 12
	local body = dtext(card, { size = UDim2.fromScale(0.92, locked and 0.42 or 0.66), position = UDim2.fromScale(0.04, 0.3), font = Enum.Font.GothamMedium, color = locked and INK_DIM or INK })
	body.ZIndex = 12
	body.RichText = true
	body.TextWrapped = true
	body.TextYAlignment = Enum.TextYAlignment.Top
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = 24
	limit.Parent = body
	if discovered then
		local ok, str = pcall(ab.text, def, Economy)
		body.Text = ok and highlight(str) or ""
	else
		body.Text = "Discover this unit to read its abilities."
	end
	if locked and discovered then
		local price = Economy[unlock.price] or 0
		local buy = Theme.stoneButton(card, {
			text = "Unlock  " .. price .. " Gems", color = "blue", size = UDim2.fromOffset(190, 34), -- (stone buttons need a pixel size)
			position = UDim2.fromScale(0.96, 0.94), anchor = Vector2.new(1, 1), zIndex = 13,
			onClick = function()
				local remote = ReplicatedStorage:FindFirstChild("BuyGemItem")
				if remote and not State[unlock.state] then
					remote:FireServer(unlock.buy)
				end
			end,
		})
		buy.root:SetAttribute("Disabled", (State.gems or 0) < price)
		local how = dtext(card, { text = "Unlockable ability", size = UDim2.fromScale(0.4, 0.1), position = UDim2.fromScale(0.04, 0.82), font = Enum.Font.GothamMedium, color = INK_DIM })
		how.ZIndex = 12
	end
end

paintDetail = function()
	local unitType = detail.unitType
	if not unitType then
		return
	end
	local baseDef = Units.Stats[unitType]
	local def = baseDef
	local level = bestLevel(unitType)
	if showYours then
		def = table.clone(baseDef)
		def.damage = baseDef.damage * yourMultiplier(unitType)
	end
	yoursBtn.label.Text = showYours and ("Your damage" .. (level and ("  Lv " .. level) or "")) or "Base damage"
	local n = (State.codex or {})[unitType]
	local rarity = Units.Rarity[unitType] or "Common"
	local color = Rarities.Color[rarity] or INK
	bigPortrait.set(unitType)
	bigPortrait.viewport.ImageColor3 = n and Color3.new(1, 1, 1) or Color3.new(0, 0, 0)
	dName.Text = n and prettyName(unitType) or "???"
	dName.TextColor3 = n and INK or INK_DIM
	if n and Units.isSignature(unitType) then
		SignatureName.apply(dName, unitType)
	end
	dTitle.Text = def.title or ""
	dRarity.Text = string.upper(rarity) .. (Units.isSovereign(unitType) and "  SOVEREIGN" or (Units.isSignature(unitType) and "  SIGNATURE" or ""))
	dRarity.TextColor3 = color
	dStats[1].Text = "1 in " .. fmt(Units.getBaseOneIn(unitType))
	dStats[2].Text = n and ((showYours and "DPS  " or "Base DPS  ") .. fmt(math.floor(def.damage / def.attackCD))) or "Base DPS  ???"
	dStats[3].Text = n and ("Pulled  " .. n .. "x") or "Not yet discovered"
	dDesc.Text = n and (Units.Descriptions[unitType] or "") or "Discover this unit to read about it."
	dDesc.TextColor3 = n and INK or INK_DIM
	for _, c in ipairs(abilityList:GetChildren()) do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	-- the passive first, then the basic attack, the special and the finisher
	local ordered = {}
	local basic = Units.basicAttack(unitType)
	if basic then
		table.insert(ordered, basic)
	end
	for _, ab in ipairs(Units.Abilities[unitType] or {}) do
		table.insert(ordered, ab)
	end
	table.sort(ordered, function(a, b) return (KIND_ORDER[a.kind] or 9) < (KIND_ORDER[b.kind] or 9) end)
	-- the cards share the page (a locked one is a little taller for its Unlock button); never taller than 0.29
	local lockedCount = 0
	for _, ab in ipairs(ordered) do
		if ab.unlock and not State[ab.unlock.state] then
			lockedCount += 1
		end
	end
	local gap = 0.025
	local unit = math.min(0.29, (1 - gap * (#ordered - 1)) / (#ordered + lockedCount * 0.25))
	for i, ab in ipairs(ordered) do
		local locked = ab.unlock and not State[ab.unlock.state]
		abilityCard(i, ab, def, n ~= nil, locked and unit * 1.25 or unit)
	end
end

showDetail = function(unitType)
	detail.unitType = unitType
	detailLeft.Visible = unitType ~= nil
	detailRight.Visible = unitType ~= nil
	paintDetail()
end
function CodexPanel.back()
	showDetail(nil)
end
-- (opens a unit's page directly, e.g. from elsewhere later; the Codex must be open)
function CodexPanel.showUnit(unitType)
	if Units.Stats[unitType] then
		showDetail(unitType)
	end
end
for _, entry in ipairs(entries) do
	entry.open.Activated:Connect(function()
		if entry.unitType then
			showDetail(entry.unitType)
		end
	end)
end

paint = function()
	paintDetail()
	local codex = State.codex or {}
	local rarity = SPREADS[spread].rarity
	local first = SPREADS[spread].first
	local pool = Units.Pools[rarity] or {}
	local color = Rarities.Color[rarity] or INK
	rarityTitle.Text = string.upper(rarity)
	rarityTitle.TextColor3 = color
	local found, all = 0, 0
	for _, r in ipairs(RARITY_LIST) do
		for _, e in ipairs(Units.Pools[r] or {}) do
			if codex[e.unit] then
				all += 1
				if r == rarity then
					found += 1
				end
			end
		end
	end
	rarityCount.Text = found .. " / " .. #pool .. " discovered"
	totalLbl.Text = "Codex  " .. all .. " / " .. TOTAL
	pageLbl.Text = spread .. " / " .. #SPREADS
	for i, b in ipairs(bookmarks) do
		b.Size = (RARITY_LIST[i] == rarity) and UDim2.fromScale(0.035, 0.1) or UDim2.fromScale(0.035, 0.07)
	end
	for i, entry in ipairs(entries) do
		local e = pool[first + i - 1]
		entry.frame.Visible = e ~= nil
		if e then
			local unitType = e.unit
			local n = codex[unitType]
			entry.portrait.set(unitType)
			entry.portrait.viewport.ImageColor3 = n and Color3.new(1, 1, 1) or Color3.new(0, 0, 0) -- undiscovered: a silhouette
			entry.stroke.Color = n and color or PAGE_EDGE
			entry.name.TextColor3 = n and INK or INK_DIM
			entry.name.Text = n and prettyName(unitType) or "???"
			if n and Units.isSignature and Units.isSignature(unitType) then
				SignatureName.apply(entry.name, unitType)
			end
			local def = Units.Stats[unitType]
			entry.title.Text = def.title or "" -- (shown even before the unit is discovered: "??? / The Envoy" makes players curious)
			entry.odds.Text = "1 in " .. fmt(Units.getBaseOneIn(unitType))
			entry.dps.Text = n and ("Base DPS  " .. fmt(math.floor(def.damage / def.attackCD))) or "Base DPS  ???"
			entry.pulled.Text = n and ("Pulled  " .. n .. "x") or "Not yet discovered"
			entry.unitType = unitType
		end
	end
end

-- ============================================================
-- Opening and closing: the grimoire in the character's hand, the camera zooms onto its pages
-- ============================================================
local session -- the running WorldView session (open / read / close)

local function hideCharacter(char, hidden)
	for _, d in ipairs(char:GetDescendants()) do
		if d:IsA("BasePart") or d:IsA("Decal") then
			d.LocalTransparencyModifier = hidden and 1 or 0
		end
	end
end

function CodexPanel.open()
	if CodexPanel.active then return end
	local ritual
	local s = WorldView.open({
		keep = { ui },
		openTime = T_OPEN,
		closeTime = T_CLOSE,
		fov = 50,
		-- the camera's zoom onto the pages starts a little after the book is raised
		blend = function(v)
			if v.phase == "open" then
				return smooth((v.t - 0.25) / (T_OPEN - 0.25))
			elseif v.phase == "shown" then
				return 1
			end
			return 1 - smooth(v.t / T_CLOSE / 0.8)
		end,
		goal = function(v)
			local open, shown
			if v.phase == "open" then
				shown = smooth(v.t / 0.4)
				open = smooth((v.t - 0.3) / 0.5)
			elseif v.phase == "shown" then
				open, shown = 1, 1
			else
				local k = v.t / T_CLOSE
				open = 1 - smooth((k - 0.3) / 0.4)
				shown = 1 - smooth((k - 0.7) / 0.3)
			end
			ritual.update(0, 0)
			ritual.pose(0, 0, true)
			-- the grimoire is held up in front of the chest like a book being read, tipped towards the reader (the pages face
			-- them); the camera glides to just behind the eyes and looks straight at the pages, always upright
			local held = v.hrp.CFrame * CFrame.new(0, 1.2, -1.9) * CFrame.Angles(math.rad(65), 0, 0)
			local _, hinge = ritual.placeBook(open, shown, held)
			local eye = hinge.Position + hinge.UpVector * 2.6
			return CFrame.lookAt(eye, hinge.Position, Vector3.yAxis)
		end,
		onStep = function(v, _, zoom)
			hideCharacter(v.char, zoom > 0.55) -- (the head would block the view)
		end,
		onShown = function()
			ui.Enabled = true
			TweenService:Create(book, TweenInfo.new(0.25), { GroupTransparency = 0 }):Play()
		end,
		onClose = function(v)
			TweenService:Create(book, TweenInfo.new(0.2), { GroupTransparency = 1 }):Play()
			task.delay(0.2, function()
				if session ~= v then return end
				ui.Enabled = false
			end)
		end,
		onFinish = function(v)
			if session == v then
				session = nil
			end
			ritual.restore()
			v.folder:Destroy()
			ui.Enabled = false
			book.GroupTransparency = 1
			hideCharacter(v.char, false)
			CodexPanel.active = false
		end,
	})
	if not s then return end
	CodexPanel.active = true
	session = s
	s.folder = Instance.new("Folder")
	s.folder.Name = "CodexFX"
	s.folder.Parent = workspace
	local hum = s.char:FindFirstChildOfClass("Humanoid")
	local feet = s.hrp.Position - Vector3.new(0, (hum and hum.HipHeight or 2) + s.hrp.Size.Y / 2, 0)
	ritual = NecroRitual.new({ hrp = s.hrp, folder = s.folder, target = s.hrp, feet = feet, color = Color3.fromRGB(150, 70, 255) })
	paint()
end

function CodexPanel.close()
	if session then
		session:close()
	end
end

function CodexPanel.toggle()
	if CodexPanel.active then
		CodexPanel.close()
	else
		CodexPanel.open()
	end
end

-- ============================================================
-- The HUD tile (right column, fourth: under Shop) and the keys
-- ============================================================
Theme.iconTile(screenGui, {
	icon = Theme.Image.Icon.Inventory, text = "Codex",
	position = UDim2.new(1, -84, 0.5, -100 + 3 * 84), zIndex = 5,
	onClick = function()
		CodexPanel.toggle()
	end,
})
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	local key = input.KeyCode
	if key == Enum.KeyCode.C then
		CodexPanel.toggle()
	elseif CodexPanel.active and key == Enum.KeyCode.Escape then
		if detail.unitType then
			CodexPanel.back()
		else
			CodexPanel.close()
		end
	elseif CodexPanel.active and (key == Enum.KeyCode.Right or key == Enum.KeyCode.D) then
		turn(1)
	elseif CodexPanel.active and (key == Enum.KeyCode.Left or key == Enum.KeyCode.A) then
		turn(-1)
	end
end)
Sync.onApplied(function()
	if CodexPanel.active then
		paint()
	end
end)

return CodexPanel
