-- The Gem Shop (the Soul Broker's shop, Design.md "The Soul Broker"): everything gems buy, in four tabs:
--   Deals  the Broker's hourly portrait deals (shared BrokerDeals, BuyBrokerDeal(portrait, rotation); stock per player
--          per rotation from DataSync State.broker)
--   Wares  consumables bought again and again: the two Forge catalysts (BuyCatalyst)
--   Unlocks permanent upgrades: the Remote Forge, the Soul Wisp speed levels and the second commander throne
--          (BuyGemItem "RemoteForge" | "WispSpeed" | "CommanderSlot")
--   Skills unlockable skills and finishers: Malak's Fleet Strike (BuyGemItem "FleetStrike"; also sold on his Codex
--          page); the necromancer's spells join it later
-- Opened by the Shop tile in the right HUD column (works anywhere, a plain centred panel) and at the Soul Broker stall
-- (its prompt, OpenBroker, or a click on a portrait, via BrokerKeeper): there `openAtStall` makes it an in-world view like
-- the Forge: the camera glides to the counter, the stall fills the left of the screen, the panel stands on the right, the
-- character is hidden; a click on a portrait (BrokerPortraits) selects that deal's card (`select`).
-- The server checks everything (UnitUpgrades, GemShop, Broker); this panel only sends the requests and
-- paints what DataSync brings back.
-- Also owns the "Forge" tile on the left HUD column that appears once the Remote Forge is bought.
-- Planned: the stall's in-world view (portraits painted with the deals, the wares as real objects on the counter) and a
-- "Get Gems" section with Robux gem packs (Developer Products).
-- Builds its UI when required (no init call).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Theme = require(script.Parent.Theme)
local State = require(script.Parent.State)
local Sync = require(script.Parent.Sync)
local screenGui = require(script.Parent.Gui)
local ForgePanel = require(script.Parent.ForgePanel)
local WorldView = require(script.Parent.WorldView)
local Economy = require(ReplicatedStorage.Shared.Economy)
local BrokerDeals = require(ReplicatedStorage.Shared.BrokerDeals)

local C = Theme.Color
local Z = 36

local GemShopPanel = {}

local buyCatalystRemote = ReplicatedStorage:WaitForChild("BuyCatalyst", 5)
local buyItemRemote = ReplicatedStorage:WaitForChild("BuyGemItem", 5)
local buyDealRemote = ReplicatedStorage:WaitForChild("BuyBrokerDeal", 5)

-- ============================================================
-- Frame
-- ============================================================
-- (its own ScreenGui: the in-world view at the stall switches every other one off)
local shopGui = Instance.new("ScreenGui")
shopGui.Name = "GemShopUI"
shopGui.ResetOnSpawn = false
shopGui.DisplayOrder = 5
shopGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
local PANEL_W, PANEL_H = 600, 600
local themed = Theme.panel(shopGui, { title = "Gem Shop", size = UDim2.fromOffset(PANEL_W, PANEL_H), zIndex = Z })
local panel = themed.frame
panel.Name = "GemShopPanel"
panel.Visible = false
require(script.Parent.Windows).register(panel) -- only one window open at a time
local body = themed.body

Theme.stoneButton(panel, {
	text = "X", color = "red", size = UDim2.fromOffset(44, 28),
	position = UDim2.new(1, -62, 0, 6), zIndex = Z + 2,
	onClick = function() panel.Visible = false end,
})

-- your gems, top right of the header
local gemsIcon = Instance.new("ImageLabel")
gemsIcon.BackgroundTransparency = 1
gemsIcon.Image = Theme.Image.Icon.Gems or ""
gemsIcon.Size = UDim2.fromOffset(30, 30)
gemsIcon.Position = UDim2.new(1, -190, 0, 5)
gemsIcon.ZIndex = Z + 2
gemsIcon.Parent = panel
local gemsLbl = Theme.label(panel, { text = "0", size = "Heading", font = "Strong", color = C.Bone, frameSize = UDim2.fromOffset(110, 40) })
gemsLbl.Position = UDim2.new(1, -156, 0, 0)
gemsLbl.ZIndex = Z + 2

-- one page per tab, below the tab row
local TOP_Y = 48
local pages = {}
for _, key in ipairs({ "deals", "wares", "unlocks", "skills" }) do
	local f = Instance.new("Frame")
	f.Name = key
	f.BackgroundTransparency = 1
	f.Position = UDim2.fromOffset(0, TOP_Y)
	f.Size = UDim2.new(1, 0, 1, -TOP_Y)
	f.Visible = false
	f.Parent = body
	pages[key] = f
end

-- ============================================================
-- Cards (shared by every tab)
-- ============================================================
local CARD_H, CARD_GAP = 84, 8
local function card(page, i, title, icon, y0)
	local f = Instance.new("Frame")
	f.BackgroundColor3 = C.StoneRaised
	f.BorderSizePixel = 0
	f.Position = UDim2.fromOffset(12, (y0 or 0) + (i - 1) * (CARD_H + CARD_GAP))
	f.Size = UDim2.new(1, -24, 0, CARD_H)
	f.ZIndex = Z + 2
	Theme.corner(f, Theme.Radius.Small)
	local stroke = Theme.stroke(f, C.Border, 1)
	f.Parent = page
	local textX = 14
	if icon then
		local img = Instance.new("ImageLabel")
		img.BackgroundTransparency = 1
		img.Image = icon
		img.Size = UDim2.fromOffset(60, 60)
		img.Position = UDim2.fromOffset(10, 12)
		img.ZIndex = Z + 3
		img.Parent = f
		textX = 82
	end
	local t = Theme.label(f, { text = title, size = "Heading", font = "Strong", color = C.Bone, frameSize = UDim2.new(1, -textX - 170, 0, 30) })
	t.Position = UDim2.fromOffset(textX, 8)
	t.ZIndex = Z + 3
	local d = Theme.label(f, { text = "", size = "Small", color = C.BoneDim, frameSize = UDim2.new(1, -textX - 170, 0, 40) })
	d.Position = UDim2.fromOffset(textX, 38)
	d.TextWrapped = true
	d.TextYAlignment = Enum.TextYAlignment.Top
	d.ZIndex = Z + 3
	return { frame = f, title = t, desc = d, stroke = stroke }
end
local function buyButton(c, onClick)
	c.button = Theme.stoneButton(c.frame, {
		text = "", color = "blue", size = UDim2.fromOffset(150, 44),
		position = UDim2.new(1, -162, 0.5, 0), anchor = Vector2.new(0, 0.5), zIndex = Z + 3,
		onClick = onClick,
	})
end
local function setButton(c, text, disabled)
	c.button.label.Text = text
	c.button.root:SetAttribute("Disabled", disabled)
end

-- ============================================================
-- Deals: the Broker's four portraits, new every hour
-- ============================================================
local countdown = Theme.label(pages.deals, { text = "", color = C.BoneDim, frameSize = UDim2.new(1, -24, 0, 22) })
countdown.Position = UDim2.fromOffset(14, 0)
countdown.ZIndex = Z + 2
local dealCards = {}
for i = 1, #BrokerDeals.PORTRAITS do
	local c = card(pages.deals, i, "", nil, 28)
	buyButton(c, function()
		if buyDealRemote then
			buyDealRemote:FireServer(i, BrokerDeals.rotation(workspace:GetServerTimeNow()))
		end
	end)
	dealCards[i] = c
end

-- ============================================================
-- Wares: consumables
-- ============================================================
local catalystCards = {}
for i, key in ipairs(Economy.CATALYSTS) do
	local c = card(pages.wares, i, Economy.CATALYST_INFO[key].name, Theme.Image.Icon.Luck)
	buyButton(c, function()
		if buyCatalystRemote then
			buyCatalystRemote:FireServer(key, 1)
		end
	end)
	catalystCards[key] = c
end
local function itemCard(page, i, title, icon, item)
	local c = card(page, i, title, icon)
	buyButton(c, function()
		if buyItemRemote then
			buyItemRemote:FireServer(item)
		end
	end)
	return c
end

-- ============================================================
-- Unlocks: permanent upgrades
-- ============================================================
local forgeCard = itemCard(pages.unlocks, 1, "Remote Forge", Theme.Image.Dust.Gold, "RemoteForge")
local wispCard = itemCard(pages.unlocks, 2, "Soul Wisp Speed", Theme.Image.Icon.GoldBoost, "WispSpeed")
local throneCard = itemCard(pages.unlocks, 3, "Second Commander Throne", Theme.Image.Icon.Ascend, "CommanderSlot")

-- ============================================================
-- Skills: unlockable skills and finishers
-- ============================================================
local fleetCard = itemCard(pages.skills, 1, "Fleet Strike", Theme.Image.Icon.Gems, "FleetStrike")
local skillsHint = Theme.label(pages.skills, { text = "More finishers and the necromancer's own spells will be sold here.", size = "Small", color = C.BoneDim, frameSize = UDim2.new(1, -24, 0, 24) })
skillsHint.Position = UDim2.fromOffset(14, CARD_H + CARD_GAP + 6)
skillsHint.ZIndex = Z + 2

-- ============================================================
-- Painting
-- ============================================================
local function paintDeals(gems)
	local rot = BrokerDeals.rotation(workspace:GetServerTimeNow())
	local bought = (State.broker and State.broker.rot == rot) and State.broker.bought or {}
	for i, c in ipairs(dealCards) do
		local o = BrokerDeals.offer(rot, i, State.rebirthCount or 0)
		local left = o.stock - (bought[i] or 0)
		local off = BrokerDeals.discount(o)
		c.title.Text = o.name .. (off and ("   -" .. off .. "%") or "")
		c.desc.Text = BrokerDeals.describe(o) .. ".  " .. left .. " of " .. o.stock .. " left this hour."
		setButton(c, left > 0 and (o.price .. " Gems") or "Sold out", left <= 0 or gems < o.price)
	end
end

local function paintWares(gems)
	for key, c in pairs(catalystCards) do
		local info = Economy.CATALYST_INFO[key]
		local owned = (State.catalysts or {})[key] or 0
		c.title.Text = info.name .. "   (you have " .. owned .. ")"
		c.desc.Text = (key == "Fortune")
			and "+25% success chance on one upgrade attempt at the Forge (capped at 100%). Used up by the attempt."
			or "If an upgrade attempt fails, no dust is lost. Only used up when it saves your dust."
		setButton(c, info.price .. " Gems", gems < info.price)
	end
end

local function paintUnlocks(gems)
	if State.remoteForge then
		forgeCard.desc.Text = "Owned. Open the Forge from the Forge button on the left, anywhere."
		setButton(forgeCard, "Owned", true)
	else
		forgeCard.desc.Text = "Upgrade units and buy dust from anywhere: adds a Forge button to the left side of the screen. One-time."
		setButton(forgeCard, Economy.REMOTE_FORGE_PRICE .. " Gems", gems < Economy.REMOTE_FORGE_PRICE)
	end
	local level = State.wispLevel or 0
	if not State.collector then
		wispCard.desc.Text = "Earn the Soul Wisp first (break 2 walls). It collects the loot on your lane."
		setButton(wispCard, "Locked", true)
	elseif level >= Economy.WISP_MAX_LEVEL then
		wispCard.desc.Text = string.format("Level %d / %d (maximum): %.0f studs/s.", level, Economy.WISP_MAX_LEVEL, Economy.wispSpeed(level))
		setButton(wispCard, "Max", true)
	else
		local price = Economy.wispLevelPrice(level)
		wispCard.desc.Text = string.format("Level %d / %d: the wisp flies %.0f -> %.0f studs/s and lingers less after each pick-up.",
			level, Economy.WISP_MAX_LEVEL, Economy.wispSpeed(level), Economy.wispSpeed(level + 1))
		setButton(wispCard, price .. " Gems", gems < price)
	end
	if (State.commanderSlots or 1) >= Economy.MAX_COMMANDER_SLOTS then
		throneCard.desc.Text = "Owned. Two Signatures or Sovereigns can lead your army."
		setButton(throneCard, "Owned", true)
	else
		throneCard.desc.Text = "Unseals the second commander throne on your plot: a second Signature or Sovereign can lead your army. One-time."
		setButton(throneCard, Economy.COMMANDER_SLOT_PRICE .. " Gems", gems < Economy.COMMANDER_SLOT_PRICE)
	end
end

local function paintSkills(gems)
	if State.fleetStrike then
		fleetCard.desc.Text = "Owned. With Malak on your plot, the Absolution executes the gate at 20%."
		setButton(fleetCard, "Owned", true)
	else
		fleetCard.desc.Text = "Malak's finisher: with Malak on your plot, his warship the Absolution executes the gate at 20%. Everyone in the server sees it. One-time."
		setButton(fleetCard, Economy.FLEET_STRIKE_PRICE .. " Gems", gems < Economy.FLEET_STRIKE_PRICE)
	end
end

local tab = "deals"
local function paint()
	local gems = State.gems or 0
	gemsLbl.Text = tostring(gems)
	if tab == "deals" then
		paintDeals(gems)
	elseif tab == "wares" then
		paintWares(gems)
	elseif tab == "unlocks" then
		paintUnlocks(gems)
	else
		paintSkills(gems)
	end
end

-- ============================================================
-- Tabs: each has a green (selected) and a grey version, one of them shown
-- ============================================================
local tabButtons = {}
local function setTab(name)
	tab = name
	for key, page in pairs(pages) do
		page.Visible = key == name
	end
	for key, t in pairs(tabButtons) do
		t.on.root.Visible = key == name
		t.off.root.Visible = key ~= name
	end
	paint()
end
for i, def in ipairs({ { "deals", "Deals" }, { "wares", "Wares" }, { "unlocks", "Unlocks" }, { "skills", "Skills" } }) do
	local t = {}
	for _, state in ipairs({ "on", "off" }) do
		t[state] = Theme.stoneButton(body, {
			text = def[2], color = state == "on" and "green" or "stone", size = UDim2.fromOffset(120, 32),
			position = UDim2.fromOffset(12 + (i - 1) * 128, 6), zIndex = Z + 2,
			onClick = function() setTab(def[1]) end,
		})
	end
	tabButtons[def[1]] = t
end
setTab("deals")

-- the Deals countdown, and a repaint when the hour turns
local lastSecond = -1
RunService.Heartbeat:Connect(function()
	if not (panel.Visible and tab == "deals") then return end
	local s = math.floor(BrokerDeals.secondsLeft(workspace:GetServerTimeNow()))
	if s ~= lastSecond then
		lastSecond = s
		countdown.Text = string.format("New deals in %d:%02d", s // 60, s % 60)
		if s >= BrokerDeals.ROTATION - 1 then paint() end -- the rotation just turned
	end
end)

-- ============================================================
-- HUD tiles: Shop (right column, third) and Forge (left column, sixth, under Army, once the Remote Forge is owned)
-- ============================================================
Theme.iconTile(screenGui, {
	icon = Theme.Image.Icon.Gems, text = "Shop",
	position = UDim2.new(1, -84, 0.5, -100 + 2 * 84), zIndex = 5,
	onClick = function()
		GemShopPanel.toggle()
	end,
})
local forgeTile = Theme.iconTile(screenGui, {
	icon = Theme.Image.Dust.Gold, text = "Forge",
	position = UDim2.new(0, 16, 0.5, -200 + 5 * 84), zIndex = 5, -- sixth slot, below Army
	onClick = function()
		ForgePanel.toggle()
	end,
})
forgeTile.root.Visible = false

function GemShopPanel.toggle()
	panel.Visible = not panel.Visible
end
-- opens the shop on a tab ("deals" | "wares" | "unlocks" | "skills")
function GemShopPanel.open(tabName)
	setTab(tabName or tab)
	panel.Visible = true
end
panel:GetPropertyChangedSignal("Visible"):Connect(function()
	if panel.Visible then
		paint()
	end
end)
function GemShopPanel.isOpen()
	return panel.Visible
end

-- a deal picked at the stall (a click on its portrait): its card lights up gold
local selectedDeal
function GemShopPanel.select(index)
	selectedDeal = index
	for i, c in ipairs(dealCards) do
		c.stroke.Color = i == index and Color3.fromRGB(232, 196, 120) or C.Border
		c.stroke.Thickness = i == index and 3 or 1
	end
end

-- ============================================================
-- The in-world view at the Soul Broker's stall (like the Forge's)
-- ============================================================
local view
local panelScale = panel:FindFirstChildOfClass("UIScale")
local function layoutInWorld()
	if not view then return end
	local screen = shopGui.AbsoluteSize
	panel.AnchorPoint = Vector2.new(1, 0.5)
	panel.Position = UDim2.new(1, -40, 0.5, 0)
	if panelScale and screen.X > 0 then
		panelScale.Scale = math.clamp(math.min(screen.X * 0.42 / (PANEL_W + 56), (screen.Y - 60) / (PANEL_H + 56)), 0.4, 1)
	end
end
shopGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
	task.defer(layoutInWorld) -- (after Theme's own fit)
end)

local function stallPivot()
	local decor = workspace:FindFirstChild("HubDecor")
	local stall = decor and decor:FindFirstChild("Stall_SoulBroker")
	return stall and stall:GetPivot()
end
local function hideCharacter(char, hidden)
	if not char then return end
	-- (every frame: the default camera scripts reset LocalTransparencyModifier)
	for _, d in ipairs(char:GetDescendants()) do
		if d:IsA("BasePart") or d:IsA("Decal") then
			d.LocalTransparencyModifier = hidden and 1 or 0
		end
	end
end

-- the camera stands in front of the counter, a little to the right, so the stall fills the left of the screen
local CAM_POS = Vector3.new(-16.5, 8.6, 2.5) -- in the stall's frame (it faces -X)
local CAM_LOOK = Vector3.new(3, 9.2, 2.5)
local CAM_SHIFT = 4.0 -- studs to the right in camera space

function GemShopPanel.openAtStall(tabName)
	setTab(tabName or "deals")
	if view then
		panel.Visible = true
		return
	end
	local P = stallPivot()
	if not P then
		panel.Visible = true -- (no stall in this place: the plain panel)
		return
	end
	view = WorldView.open({
		keep = { shopGui },
		openTime = 0.9,
		fov = 50,
		goal = function()
			return CFrame.lookAt((P * CFrame.new(CAM_POS)).Position, (P * CFrame.new(CAM_LOOK)).Position) * CFrame.new(CAM_SHIFT, 0, 0)
		end,
		onStep = function(v, _, k)
			hideCharacter(v.char, k > 0.4) -- (the character stands between the camera and the counter)
		end,
		onFinish = function(v)
			hideCharacter(v.char, false)
			if view == v then view = nil end
			panel.Visible = false
			GemShopPanel.select(nil)
			-- back to the plain centred panel: nudging the size makes Theme's fit place and scale it again
			panel.AnchorPoint = Vector2.new(0.5, 0.5)
			panel.Size = UDim2.fromOffset(PANEL_W, PANEL_H + 1)
			panel.Size = UDim2.fromOffset(PANEL_W, PANEL_H)
		end,
	})
	panel.Visible = true
	layoutInWorld()
end
function GemShopPanel.atStall()
	return view ~= nil
end
panel:GetPropertyChangedSignal("Visible"):Connect(function()
	if not panel.Visible and view then
		view:close()
	end
end)
-- (the Soul Broker stall's prompt, OpenBroker, is handled by BrokerKeeper: the broker walks to his counter first and
-- then opens the shop on Deals)

Sync.onApplied(function()
	forgeTile.root.Visible = State.remoteForge == true
	if panel.Visible then
		paint()
	end
end)

return GemShopPanel
