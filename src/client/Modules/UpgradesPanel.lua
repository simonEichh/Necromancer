-- The Upgrades panel: everything gold makes stronger, reachable anywhere from the "Upgrades" tile in the left HUD column
-- (a badge shows how many levels you can afford right now) and from the upgrade stall in the plaza (OpenUpgrade).
--   Realm upgrades (Economy.REALM_UPGRADES: Army Might, Soul Harvest, Swift March, Grasping Souls): kept through the
--   ascensions of a realm, reset with the gold when a new realm starts (BuyRealmUpgrade).
--   Permanent: Luck Boost and Coin Boost (BuyUpgrade, the old upgrade panel's).
-- The server checks everything (Upgrades); this panel only sends the requests and paints what DataSync brings back.
-- Near your Soul Altar (your plot, the bridge, the island; Modules/AltarScene) it opens in the world: the camera glides
-- to the altar, the panel stands on the right, hovering a realm upgrade lights its brazier (AltarFx), buying makes it
-- flare. Elsewhere (and at the plaza's upgrade stall) it is the plain centred panel. The altar's prompt opens it too.
-- Builds its UI when required (no init call).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(script.Parent.Theme)
local State = require(script.Parent.State)
local Sync = require(script.Parent.Sync)
local screenGui = require(script.Parent.Gui)
local Format = require(script.Parent.Format)
local Economy = require(ReplicatedStorage.Shared.Economy)
local AltarScene = require(script.Parent.AltarScene)
local AltarFx = require(script.Parent.AltarFx)

local C = Theme.Color
local Z = 36

local UpgradesPanel = {}

local buyRealmRemote = ReplicatedStorage:WaitForChild("BuyRealmUpgrade", 5)
local buyUpgradeRemote = ReplicatedStorage:WaitForChild("BuyUpgrade", 5)
local openUpgradeEvt = ReplicatedStorage:WaitForChild("OpenUpgrade", 5)

local function fmt(n)
	return Format.fmtGold and Format.fmtGold(n) or tostring(math.floor(n))
end

-- ============================================================
-- Frame
-- ============================================================
-- (its own ScreenGui: the in-world view switches every other one off; the tile stays in the main one)
local upgradesGui = Instance.new("ScreenGui")
upgradesGui.Name = "UpgradesUI"
upgradesGui.ResetOnSpawn = false
upgradesGui.DisplayOrder = 5
upgradesGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
local PANEL_W, PANEL_H = 640, 600
local themed = Theme.panel(upgradesGui, { title = "Upgrades", size = UDim2.fromOffset(PANEL_W, PANEL_H), zIndex = Z })
local panel = themed.frame
panel.Name = "UpgradesPanel"
panel.Visible = false
require(script.Parent.Windows).register(panel) -- only one window open at a time
local body = themed.body

Theme.stoneButton(panel, {
	text = "X", color = "red", size = UDim2.fromOffset(44, 28),
	position = UDim2.new(1, -62, 0, 6), zIndex = Z + 2,
	onClick = function() panel.Visible = false end,
})

-- your gold, top right of the header
local goldIcon = Instance.new("ImageLabel")
goldIcon.BackgroundTransparency = 1
goldIcon.Image = Theme.Image.Icon.Gold or ""
goldIcon.Size = UDim2.fromOffset(30, 30)
goldIcon.Position = UDim2.new(1, -210, 0, 5)
goldIcon.ZIndex = Z + 2
goldIcon.Parent = panel
local goldLbl = Theme.label(panel, { text = "0", size = "Heading", font = "Strong", color = C.Bone, frameSize = UDim2.fromOffset(130, 40) })
goldLbl.Position = UDim2.new(1, -176, 0, 0)
goldLbl.ZIndex = Z + 2

-- ============================================================
-- Sections and cards
-- ============================================================
local CARD_H, CARD_GAP = 70, 6
local y = 8

local function section(text, sub)
	local t = Theme.label(body, { text = text, size = "Heading", font = "Strong", color = C.Bone, frameSize = UDim2.new(1, -24, 0, 26) })
	t.Position = UDim2.fromOffset(14, y)
	t.ZIndex = Z + 2
	local s = Theme.label(body, { text = sub, size = "Small", color = C.BoneDim, frameSize = UDim2.new(1, -24, 0, 18) })
	s.Position = UDim2.fromOffset(14, y + 26)
	s.ZIndex = Z + 2
	y += 48
end

local function card(title, icon, onBuy)
	local f = Instance.new("Frame")
	f.BackgroundColor3 = C.StoneRaised
	f.BorderSizePixel = 0
	f.Position = UDim2.fromOffset(12, y)
	f.Size = UDim2.new(1, -24, 0, CARD_H)
	f.ZIndex = Z + 2
	Theme.corner(f, Theme.Radius.Small)
	Theme.stroke(f, C.Border, 1)
	f.Parent = body
	y += CARD_H + CARD_GAP
	local img = Instance.new("ImageLabel")
	img.BackgroundTransparency = 1
	img.Image = icon or ""
	img.Size = UDim2.fromOffset(50, 50)
	img.Position = UDim2.fromOffset(10, 10)
	img.ZIndex = Z + 3
	img.Parent = f
	local t = Theme.label(f, { text = title, size = "Body", font = "Strong", color = C.Bone, frameSize = UDim2.new(1, -250, 0, 26) })
	t.Position = UDim2.fromOffset(72, 6)
	t.ZIndex = Z + 3
	local d = Theme.label(f, { text = "", size = "Small", color = C.BoneDim, frameSize = UDim2.new(1, -250, 0, 34) })
	d.Position = UDim2.fromOffset(72, 32)
	d.TextWrapped = true
	d.TextYAlignment = Enum.TextYAlignment.Top
	d.ZIndex = Z + 3
	local button = Theme.stoneButton(f, {
		text = "", color = "gold", size = UDim2.fromOffset(160, 44),
		position = UDim2.new(1, -172, 0.5, 0), anchor = Vector2.new(0, 0.5), zIndex = Z + 3,
		onClick = onBuy,
	})
	return { frame = f, title = t, desc = d, button = button, name = title }
end

local REALM_ICONS = {
	might = Theme.Image.Icon.Ascend,
	harvest = Theme.Image.Icon.Gold,
	march = Theme.Image.Icon.Inventory,
	magnet = Theme.Image.Icon.GoldBoost,
}

section("Realm upgrades", "Kept until you enter a new realm (they reset with your Gold).")
local realmCards = {}
for _, u in ipairs(Economy.REALM_UPGRADES) do
	realmCards[u.key] = card(u.name, REALM_ICONS[u.key], function()
		if buyRealmRemote then
			buyRealmRemote:FireServer(u.key)
		end
	end)
	-- in the world: hovering the card lights its brazier on the altar
	local f = realmCards[u.key].frame
	f.MouseEnter:Connect(function()
		AltarFx.highlight(u.key)
	end)
	f.MouseLeave:Connect(function()
		AltarFx.highlight(nil)
	end)
end

y += 6
section("Permanent", "Never reset.")
local permCards = {
	luckBoost = card("Luck Boost", Theme.Image.Icon.Luck, function()
		if buyUpgradeRemote then
			buyUpgradeRemote:FireServer("luckBoost")
		end
	end),
	coinBoost = card("Coin Boost", Theme.Image.Icon.GoldBoost, function()
		if buyUpgradeRemote then
			buyUpgradeRemote:FireServer("coinBoost")
		end
	end),
}

-- ============================================================
-- Painting
-- ============================================================
local function effectText(u, level)
	if u.studs then
		return string.format("+%.1f studs %s", Economy.realmUpgradeEffect(u.key, level), u.text)
	end
	return string.format("+%d%% %s", math.floor((Economy.realmUpgradeEffect(u.key, level) - 1) * 100 + 0.5), u.text)
end

-- how many levels the player can afford right now (the HUD tile's badge)
function UpgradesPanel.affordable()
	local gold = State.gold or 0
	local n = 0
	for _, u in ipairs(Economy.REALM_UPGRADES) do
		local cost = Economy.realmUpgradeCost(u.key, (State.realmUpgrades or {})[u.key] or 0, State.rebirthCount or 0)
		if cost and cost <= gold then
			n += 1
		end
	end
	for key, max in pairs(Economy.UPGRADE_MAX) do
		local level = State[key .. "Level"] or 0
		if level < max and Economy.upgradeCost(key, level) <= gold then
			n += 1
		end
	end
	return n
end

local function paint()
	local gold = State.gold or 0
	goldLbl.Text = fmt(gold)
	for _, u in ipairs(Economy.REALM_UPGRADES) do
		local c = realmCards[u.key]
		local level = (State.realmUpgrades or {})[u.key] or 0
		local cost = Economy.realmUpgradeCost(u.key, level, State.rebirthCount or 0)
		c.title.Text = u.name .. "   Lv " .. level .. (u.max and (" / " .. u.max) or "")
		if cost then
			c.desc.Text = "Now " .. effectText(u, level) .. "  ->  " .. effectText(u, level + 1)
			c.button.label.Text = fmt(cost) .. " Gold"
			c.button.root:SetAttribute("Disabled", gold < cost)
		else
			c.desc.Text = effectText(u, level) .. " (maximum)"
			c.button.label.Text = "Max"
			c.button.root:SetAttribute("Disabled", true)
		end
	end
	for key, c in pairs(permCards) do
		local level = State[key .. "Level"] or 0
		local max = Economy.UPGRADE_MAX[key]
		c.title.Text = c.name .. "   Lv " .. level .. " / " .. max
		if key == "luckBoost" then
			c.desc.Text = string.format("+%d%% chance for Rare and better pulls  ->  +%d%%", level * 10, (level + 1) * 10)
		else
			c.desc.Text = string.format("+%d%% Gold from walls, hits and selling  ->  +%d%%", level * 50, (level + 1) * 50)
		end
		if level >= max then
			c.desc.Text = "Maximum reached."
			c.button.label.Text = "Max"
			c.button.root:SetAttribute("Disabled", true)
		else
			local cost = Economy.upgradeCost(key, level)
			c.button.label.Text = fmt(cost) .. " Gold"
			c.button.root:SetAttribute("Disabled", gold < cost)
		end
	end
end

-- ============================================================
-- The HUD tile (left column, fourth: under Graves) with a badge of affordable levels
-- ============================================================
local tile = Theme.iconTile(screenGui, {
	icon = Theme.Image.Icon.Ascend, text = "Upgrades",
	position = UDim2.new(0, 16, 0.5, -200 + 3 * 84), zIndex = 5,
	onClick = function()
		UpgradesPanel.toggle()
	end,
})
local badge = Instance.new("Frame")
badge.AnchorPoint = Vector2.new(1, 0)
badge.Position = UDim2.new(1, 8, 0, -8)
badge.Size = UDim2.fromOffset(30, 22)
badge.BackgroundColor3 = C.Blood
badge.BorderSizePixel = 0
badge.ZIndex = 9
badge.Visible = false
Theme.corner(badge, 11)
Theme.stroke(badge, C.Void, 2)
badge.Parent = tile.root
local badgeText = Theme.label(badge, { text = "0", size = "Small", font = "Strong", color = C.Bone, align = Enum.TextXAlignment.Center, frameSize = UDim2.fromScale(1, 1) })
badgeText.ZIndex = 10

local function refresh()
	local n = UpgradesPanel.affordable()
	badge.Visible = n > 0
	badgeText.Text = tostring(n)
	if panel.Visible then
		paint()
	end
end

-- ============================================================
-- In the world (at your Soul Altar)
-- ============================================================
local view = nil
local panelScale = panel:FindFirstChildOfClass("UIScale")

local function layoutInWorld()
	if not view then
		return
	end
	local screen = upgradesGui.AbsoluteSize
	panel.AnchorPoint = Vector2.new(1, 0.5)
	panel.Position = UDim2.new(1, -40, 0.5, 0)
	if panelScale and screen.X > 0 then
		panelScale.Scale = math.clamp(math.min(screen.X * 0.5 / (PANEL_W + 56), (screen.Y - 60) / (PANEL_H + 56)), 0.4, 1)
	end
end
upgradesGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
	task.defer(layoutInWorld) -- (after Theme's own fit)
end)

local function openInWorld()
	if view or not AltarScene.available() then
		return
	end
	view = AltarScene.open(upgradesGui, function(v)
		if view == v then
			view = nil
		end
		panel.Visible = false
		-- back to the plain centred panel: nudging the size makes Theme's fit place and scale it again
		panel.AnchorPoint = Vector2.new(0.5, 0.5)
		panel.Size = UDim2.fromOffset(PANEL_W, PANEL_H + 1)
		panel.Size = UDim2.fromOffset(PANEL_W, PANEL_H)
	end)
	layoutInWorld()
end

panel:GetPropertyChangedSignal("Visible"):Connect(function()
	if panel.Visible then
		openInWorld()
	else
		AltarFx.highlight(nil)
		if view then
			view:close()
		end
	end
end)

AltarScene.onPrompt = function()
	UpgradesPanel.open()
end

function UpgradesPanel.toggle()
	panel.Visible = not panel.Visible
	if panel.Visible then
		paint()
	end
end

function UpgradesPanel.open()
	panel.Visible = true
	paint()
end

Sync.onApplied(refresh)
if openUpgradeEvt then
	openUpgradeEvt.OnClientEvent:Connect(UpgradesPanel.open) -- the upgrade stall in the plaza
end
refresh()

return UpgradesPanel
