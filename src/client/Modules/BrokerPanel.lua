-- The Soul Broker's deals as a plain panel (step 1 of the gem stall, Design.md "The Soul Broker"): four cards, one per
-- portrait, with the offer for this player, the stock left this hour and a Buy button (BuyBrokerDeal(portrait, rot)).
-- Opened from the DEV panel until the stall and its in-world view exist. The deals come from shared BrokerDeals and the
-- clock; the stock used comes from DataSync (State.broker).
-- Builds its UI when required (no init call).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Theme = require(script.Parent.Theme)
local State = require(script.Parent.State)
local Sync = require(script.Parent.Sync)
local screenGui = require(script.Parent.Gui)
local BrokerDeals = require(ReplicatedStorage.Shared.BrokerDeals)

local C = Theme.Color
local Z = 36

local BrokerPanel = {}

local buyRemote = ReplicatedStorage:WaitForChild("BuyBrokerDeal", 5)

-- ============================================================
-- Frame
-- ============================================================
local themed = Theme.panel(screenGui, { title = "Soul Broker", size = UDim2.fromOffset(600, 470), zIndex = Z })
local panel = themed.frame
panel.Name = "BrokerPanel"
panel.Visible = false
require(script.Parent.Windows).register(panel) -- only one window open at a time
local body = themed.body

Theme.stoneButton(panel, {
	text = "X", color = "red", size = UDim2.fromOffset(44, 28),
	position = UDim2.new(1, -62, 0, 6), zIndex = Z + 2,
	onClick = function() panel.Visible = false end,
})

local gemsLbl = Theme.label(panel, { text = "", size = "Heading", font = "Strong", color = C.Bone, frameSize = UDim2.fromOffset(150, 40) })
gemsLbl.Position = UDim2.new(1, -220, 0, 0)
gemsLbl.ZIndex = Z + 2

local countdown = Theme.label(body, { text = "", color = C.BoneDim, frameSize = UDim2.new(1, -24, 0, 24) })
countdown.Position = UDim2.fromOffset(12, 6)
countdown.ZIndex = Z + 2

-- ============================================================
-- Cards
-- ============================================================
local CARD_H, CARD_GAP = 84, 8
local cards = {}
for i = 1, #BrokerDeals.PORTRAITS do
	local f = Instance.new("Frame")
	f.BackgroundColor3 = C.StoneRaised
	f.BorderSizePixel = 0
	f.Position = UDim2.fromOffset(12, 36 + (i - 1) * (CARD_H + CARD_GAP))
	f.Size = UDim2.new(1, -24, 0, CARD_H)
	f.ZIndex = Z + 2
	Theme.corner(f, Theme.Radius.Small)
	Theme.stroke(f, C.Border, 1)
	f.Parent = body
	local t = Theme.label(f, { text = "", size = "Heading", font = "Strong", color = C.Bone, frameSize = UDim2.new(1, -190, 0, 30) })
	t.Position = UDim2.fromOffset(14, 8)
	t.ZIndex = Z + 3
	local d = Theme.label(f, { text = "", size = "Small", color = C.BoneDim, frameSize = UDim2.new(1, -190, 0, 40) })
	d.Position = UDim2.fromOffset(14, 38)
	d.TextWrapped = true
	d.TextYAlignment = Enum.TextYAlignment.Top
	d.ZIndex = Z + 3
	local c = { title = t, desc = d }
	c.button = Theme.stoneButton(f, {
		text = "", color = "blue", size = UDim2.fromOffset(150, 44),
		position = UDim2.new(1, -162, 0.5, 0), anchor = Vector2.new(0, 0.5), zIndex = Z + 3,
		onClick = function()
			if buyRemote then
				buyRemote:FireServer(i, BrokerDeals.rotation(workspace:GetServerTimeNow()))
			end
		end,
	})
	cards[i] = c
end

local function paint()
	local now = workspace:GetServerTimeNow()
	local rot = BrokerDeals.rotation(now)
	local gems = State.gems or 0
	gemsLbl.Text = gems .. " Gems"
	local bought = (State.broker and State.broker.rot == rot) and State.broker.bought or {}
	for i, c in ipairs(cards) do
		local o = BrokerDeals.offer(rot, i, State.rebirthCount or 0)
		local left = o.stock - (bought[i] or 0)
		c.title.Text = BrokerDeals.PORTRAITS[i].key .. ": " .. o.name
		c.desc.Text = BrokerDeals.describe(o) .. "   (" .. left .. " / " .. o.stock .. " left this hour)"
		c.button.label.Text = left > 0 and (o.price .. " Gems") or "Sold out"
		c.button.root:SetAttribute("Disabled", left <= 0 or gems < o.price)
	end
end

local lastSecond = -1
RunService.Heartbeat:Connect(function()
	if not panel.Visible then return end
	local now = workspace:GetServerTimeNow()
	local s = math.floor(BrokerDeals.secondsLeft(now))
	if s ~= lastSecond then
		lastSecond = s
		countdown.Text = string.format("New wares in %d:%02d", s // 60, s % 60)
		if s >= BrokerDeals.ROTATION - 1 then paint() end -- the rotation just turned
	end
end)

function BrokerPanel.toggle()
	panel.Visible = not panel.Visible
end
panel:GetPropertyChangedSignal("Visible"):Connect(function()
	if panel.Visible then paint() end
end)
Sync.onApplied(function()
	if panel.Visible then paint() end
end)

return BrokerPanel
