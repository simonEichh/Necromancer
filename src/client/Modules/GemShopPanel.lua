-- The Gem Shop: everything gems buy, usable anywhere. A "Shop" tile on the right HUD column opens it (third tile, under
-- Quests and Friends). Cards: the two Forge catalysts (BuyCatalyst), the Remote Forge (BuyGemItem "RemoteForge",
-- one-time) and the Soul Wisp speed levels (BuyGemItem "WispSpeed"). The server checks everything (UnitUpgrades,
-- GemShop); this panel only sends the requests and paints what DataSync brings back.
-- Also owns the "Forge" tile on the left HUD column that appears once the Remote Forge is bought.
-- Planned: a "Get Gems" section with Robux gem packs (Developer Products).
-- Builds its UI when required (no init call).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(script.Parent.Theme)
local State = require(script.Parent.State)
local Sync = require(script.Parent.Sync)
local screenGui = require(script.Parent.Gui)
local ForgePanel = require(script.Parent.ForgePanel)
local Economy = require(ReplicatedStorage.Shared.Economy)

local C = Theme.Color
local Z = 36

local GemShopPanel = {}

local buyCatalystRemote = ReplicatedStorage:WaitForChild("BuyCatalyst", 5)
local buyItemRemote = ReplicatedStorage:WaitForChild("BuyGemItem", 5)

-- ============================================================
-- Frame
-- ============================================================
local themed = Theme.panel(screenGui, { title = "Gem Shop", size = UDim2.fromOffset(600, 470), zIndex = Z })
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

-- ============================================================
-- Cards
-- ============================================================
local CARD_H, CARD_GAP = 84, 8
local cards = {}
local function card(i, title, icon)
	local f = Instance.new("Frame")
	f.BackgroundColor3 = C.StoneRaised
	f.BorderSizePixel = 0
	f.Position = UDim2.fromOffset(12, 10 + (i - 1) * (CARD_H + CARD_GAP))
	f.Size = UDim2.new(1, -24, 0, CARD_H)
	f.ZIndex = Z + 2
	Theme.corner(f, Theme.Radius.Small)
	Theme.stroke(f, C.Border, 1)
	f.Parent = body
	local img = Instance.new("ImageLabel")
	img.BackgroundTransparency = 1
	img.Image = icon or ""
	img.Size = UDim2.fromOffset(60, 60)
	img.Position = UDim2.fromOffset(10, 12)
	img.ZIndex = Z + 3
	img.Parent = f
	local t = Theme.label(f, { text = title, size = "Heading", font = "Strong", color = C.Bone, frameSize = UDim2.new(1, -250, 0, 30) })
	t.Position = UDim2.fromOffset(82, 8)
	t.ZIndex = Z + 3
	local d = Theme.label(f, { text = "", size = "Small", color = C.BoneDim, frameSize = UDim2.new(1, -250, 0, 40) })
	d.Position = UDim2.fromOffset(82, 38)
	d.TextWrapped = true
	d.TextYAlignment = Enum.TextYAlignment.Top
	d.ZIndex = Z + 3
	local c = { frame = f, title = t, desc = d }
	cards[i] = c
	return c
end
local function buyButton(c, onClick)
	c.button = Theme.stoneButton(c.frame, {
		text = "", color = "blue", size = UDim2.fromOffset(150, 44),
		position = UDim2.new(1, -162, 0.5, 0), anchor = Vector2.new(0, 0.5), zIndex = Z + 3,
		onClick = onClick,
	})
end

local catalystCards = {}
for i, key in ipairs(Economy.CATALYSTS) do
	local info = Economy.CATALYST_INFO[key]
	local c = card(i, info.name, Theme.Image.Icon.Luck)
	buyButton(c, function()
		if buyCatalystRemote then
			buyCatalystRemote:FireServer(key, 1)
		end
	end)
	catalystCards[key] = c
end
local forgeCard = card(#Economy.CATALYSTS + 1, "Remote Forge", Theme.Image.Dust.Gold)
buyButton(forgeCard, function()
	if buyItemRemote then
		buyItemRemote:FireServer("RemoteForge")
	end
end)
local wispCard = card(#Economy.CATALYSTS + 2, "Soul Wisp Speed", Theme.Image.Icon.GoldBoost)
buyButton(wispCard, function()
	if buyItemRemote then
		buyItemRemote:FireServer("WispSpeed")
	end
end)

local function paint()
	local gems = State.gems or 0
	gemsLbl.Text = tostring(gems)
	for key, c in pairs(catalystCards) do
		local info = Economy.CATALYST_INFO[key]
		local owned = (State.catalysts or {})[key] or 0
		c.title.Text = info.name .. "   (you have " .. owned .. ")"
		c.desc.Text = (key == "Fortune")
			and "+25% success chance on one upgrade attempt at the Forge (capped at 100%). Used up by the attempt."
			or "If an upgrade attempt fails, no dust is lost. Only used up when it saves your dust."
		c.button.label.Text = info.price .. " Gems"
		c.button.root:SetAttribute("Disabled", gems < info.price)
	end
	if State.remoteForge then
		forgeCard.desc.Text = "Owned. Open the Forge from the Forge button on the left, anywhere."
		forgeCard.button.label.Text = "Owned"
		forgeCard.button.root:SetAttribute("Disabled", true)
	else
		forgeCard.desc.Text = "Upgrade units and buy dust from anywhere: adds a Forge button to the left side of the screen. One-time."
		forgeCard.button.label.Text = Economy.REMOTE_FORGE_PRICE .. " Gems"
		forgeCard.button.root:SetAttribute("Disabled", gems < Economy.REMOTE_FORGE_PRICE)
	end
	local level = State.wispLevel or 0
	if not State.collector then
		wispCard.desc.Text = "Earn the Soul Wisp first (break 2 walls). It collects the loot on your lane."
		wispCard.button.label.Text = "Locked"
		wispCard.button.root:SetAttribute("Disabled", true)
	elseif level >= Economy.WISP_MAX_LEVEL then
		wispCard.desc.Text = string.format("Level %d / %d (maximum): %.0f studs/s.", level, Economy.WISP_MAX_LEVEL, Economy.wispSpeed(level))
		wispCard.button.label.Text = "Max"
		wispCard.button.root:SetAttribute("Disabled", true)
	else
		local price = Economy.wispLevelPrice(level)
		wispCard.desc.Text = string.format("Level %d / %d: the wisp flies %.0f -> %.0f studs/s and lingers less after each pick-up.",
			level, Economy.WISP_MAX_LEVEL, Economy.wispSpeed(level), Economy.wispSpeed(level + 1))
		wispCard.button.label.Text = price .. " Gems"
		wispCard.button.root:SetAttribute("Disabled", gems < price)
	end
end

-- ============================================================
-- HUD tiles: Shop (right column, third) and Forge (left column, under Upgrades, once the Remote Forge is owned)
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
	position = UDim2.new(0, 16, 0.5, -200 + 4 * 84), zIndex = 5, -- (under the Upgrades tile)
	onClick = function()
		ForgePanel.toggle()
	end,
})
forgeTile.root.Visible = false

function GemShopPanel.toggle()
	panel.Visible = not panel.Visible
end
panel:GetPropertyChangedSignal("Visible"):Connect(function()
	if panel.Visible then
		paint()
	end
end)

Sync.onApplied(function()
	forgeTile.root.Visible = State.remoteForge == true
	if panel.Visible then
		paint()
	end
end)

return GemShopPanel
