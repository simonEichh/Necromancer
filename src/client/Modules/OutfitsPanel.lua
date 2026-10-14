-- The Outfits panel (wardrobe): the camera glides round to the front of the character (upright, no overhead swing),
-- the character stands still and can be turned by dragging, and a stone panel on the right lists the outfit items of
-- one slot (tabs Hand / Head / Back): a card with a turning 3D view per item, its name and description, and
-- Equip / Take off (EquipItem; the server puts the item on the character, see server Modules/Outfits).
-- Opened with the "Outfits" tile (right HUD column, under Codex) or O; Esc / X / O closes. Builds its UI when required.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Theme = require(script.Parent.Theme)
local State = require(script.Parent.State)
local Sync = require(script.Parent.Sync)
local screenGui = require(script.Parent.Gui)
local Items = require(ReplicatedStorage.Shared.Items)
local WorldView = require(script.Parent.WorldView)

local player = Players.LocalPlayer
local C = Theme.Color
local EquipItem = ReplicatedStorage:WaitForChild("EquipItem")

local OutfitsPanel = {}
OutfitsPanel.active = false

local T_MOVE = 0.9 -- the camera glides to the front view
local CAM_DIST = 9.5
local CAM_SHIFT = 2.4 -- the camera slides right so the character stands left of the panel
local CAM_FOV = 50
local DRAG_SPEED = 0.012 -- radians per pixel

-- ============================================================
-- UI
-- ============================================================
local ui = Instance.new("ScreenGui")
ui.Name = "OutfitsUI"
ui.ResetOnSpawn = false
ui.IgnoreGuiInset = true
ui.DisplayOrder = 20
ui.Enabled = false
ui.Parent = player:WaitForChild("PlayerGui")

local PANEL_W, PANEL_H = 380, 560
local panel = Theme.panel(ui, {
	title = "Outfits",
	size = UDim2.fromOffset(PANEL_W, PANEL_H),
	anchor = Vector2.new(1, 0.5),
	position = UDim2.new(1, -70, 0.5, 0),
	zIndex = 10,
})
local frame = panel.frame
local uiScale = Instance.new("UIScale")
uiScale.Parent = frame
local function fit()
	local screen = ui.AbsoluteSize
	if screen.Y > 0 then
		uiScale.Scale = math.clamp(math.min((screen.Y - 80) / (PANEL_H + 56), (screen.X * 0.5) / (PANEL_W + 56)), 0.45, 1)
	end
end
ui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
fit()

Theme.stoneButton(frame, {
	text = "X", color = "red", size = UDim2.fromOffset(44, 32), position = UDim2.new(1, -52, 0, 4), zIndex = 14,
	onClick = function() OutfitsPanel.close() end,
})

local hint = Theme.label(ui, { text = "Drag to turn", color = C.BoneDim, align = Enum.TextXAlignment.Center, frameSize = UDim2.fromOffset(200, 22) })
hint.AnchorPoint = Vector2.new(0.5, 1)
hint.Position = UDim2.new(0.3, 0, 1, -24)
Theme.outlineText(hint)

-- slot tabs (rebuilt on every paint: the stone buttons keep their colour)
local tabRow = Instance.new("Frame")
tabRow.BackgroundTransparency = 1
tabRow.Size = UDim2.new(1, 0, 0, 44)
tabRow.ZIndex = 11
tabRow.Parent = panel.body

-- item cards
local grid = Instance.new("ScrollingFrame")
grid.BackgroundTransparency = 1
grid.BorderSizePixel = 0
grid.Position = UDim2.fromOffset(0, 54)
grid.Size = UDim2.new(1, 0, 0, 250)
grid.ScrollBarThickness = 4
grid.ScrollBarImageColor3 = C.Border
grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
grid.CanvasSize = UDim2.new()
grid.ZIndex = 11
grid.Parent = panel.body
local layout = Instance.new("UIGridLayout")
layout.CellSize = UDim2.fromOffset(108, 118)
layout.CellPadding = UDim2.fromOffset(9, 9)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = grid

-- details of the selected item
local details = Instance.new("Frame")
details.BackgroundColor3 = C.StoneRaised
details.BorderSizePixel = 0
details.Position = UDim2.fromOffset(0, 314)
details.Size = UDim2.new(1, 0, 1, -314)
details.ZIndex = 11
details.Parent = panel.body
Theme.corner(details, Theme.Radius.Medium)
Theme.stroke(details, C.Border, 1)
local nameLbl = Theme.label(details, { text = "", size = "Heading", font = "Title", frameSize = UDim2.new(1, -20, 0, 28) })
nameLbl.Position = UDim2.fromOffset(10, 8)
nameLbl.ZIndex = 12
local slotLbl = Theme.label(details, { text = "", size = "Small", color = C.BoneDim, frameSize = UDim2.new(1, -20, 0, 18) })
slotLbl.Position = UDim2.fromOffset(10, 36)
slotLbl.ZIndex = 12
local descLbl = Theme.label(details, { text = "", color = C.BoneDim, frameSize = UDim2.new(1, -20, 0, 60) })
descLbl.Position = UDim2.fromOffset(10, 58)
descLbl.TextWrapped = true
descLbl.TextYAlignment = Enum.TextYAlignment.Top
descLbl.ZIndex = 12
local actionHolder = Instance.new("Frame")
actionHolder.BackgroundTransparency = 1
actionHolder.AnchorPoint = Vector2.new(0.5, 1)
actionHolder.Position = UDim2.new(0.5, 0, 1, -10)
actionHolder.Size = UDim2.fromOffset(170, 44)
actionHolder.ZIndex = 12
actionHolder.Parent = details

require(script.Parent.Windows).register(frame)

-- ============================================================
-- 3D item views (ViewportFrame, turning slowly while the panel is open)
-- ============================================================
local views = {} -- { model, camera, center, radius }

local function makeView(parent, key)
	local template = ReplicatedStorage:FindFirstChild("ItemModels") and ReplicatedStorage.ItemModels:FindFirstChild(key)
	local vp = Instance.new("ViewportFrame")
	vp.BackgroundTransparency = 1
	vp.Size = UDim2.new(1, -8, 1, -30)
	vp.Position = UDim2.fromOffset(4, 4)
	vp.Ambient = Color3.fromRGB(150, 150, 160)
	vp.LightColor = Color3.fromRGB(255, 240, 220)
	vp.LightDirection = Vector3.new(-1, -1, -1)
	vp.ZIndex = 13
	vp.Parent = parent
	if not template then
		return
	end
	local model = Instance.new("Model")
	for _, child in template:Clone():GetChildren() do
		child.Parent = model
	end
	local turn = Items.SLOT_INFO[Items.Defs[key].slot].viewTurn
	if turn then
		model:PivotTo(turn * model:GetPivot())
	end
	model.Parent = vp
	local cam = Instance.new("Camera")
	cam.FieldOfView = 30
	cam.Parent = vp
	vp.CurrentCamera = cam
	local cf, size = model:GetBoundingBox()
	table.insert(views, { vp = vp, camera = cam, center = cf.Position, radius = size.Magnitude / 2 })
end

local function updateViews(t)
	for i = #views, 1, -1 do
		local v = views[i]
		if not v.vp.Parent then
			table.remove(views, i)
		else
			local a = t * 0.6 + i
			local dist = v.radius / math.tan(math.rad(15)) * 1.05
			local pos = v.center + Vector3.new(math.sin(a) * dist, v.radius * 0.25, math.cos(a) * dist)
			v.camera.CFrame = CFrame.lookAt(pos, v.center)
		end
	end
end

-- ============================================================
-- Painting
-- ============================================================
local currentSlot = Items.SLOTS[1]
local selected = {} -- [slot] = item key picked in that tab
local cards = {}

local function owns(key)
	for _, k in ipairs(State.items or {}) do
		if k == key then
			return true
		end
	end
	return false
end

local function itemsOf(slot)
	local list = {}
	for key, def in pairs(Items.Defs) do
		if def.slot == slot then
			table.insert(list, key)
		end
	end
	table.sort(list, function(a, b)
		return (Items.Defs[a].order or 0) < (Items.Defs[b].order or 0)
	end)
	return list
end

local paint
local function paintTabs()
	for _, c in tabRow:GetChildren() do
		c:Destroy()
	end
	local w = 104
	for i, slot in ipairs(Items.SLOTS) do
		Theme.stoneButton(tabRow, {
			text = Items.SLOT_INFO[slot].name, color = (slot == currentSlot) and "green" or "stone",
			size = UDim2.fromOffset(w, 38), position = UDim2.fromOffset((i - 1) * (w + 10), 2), zIndex = 12,
			onClick = function()
				currentSlot = slot
				paint()
			end,
		})
	end
end

local function paintCards()
	for _, c in cards do
		c:Destroy()
	end
	table.clear(cards)
	for i, key in ipairs(itemsOf(currentSlot)) do
		local def = Items.Defs[key]
		local worn = State.equipped and State.equipped[currentSlot] == key
		local card = Instance.new("TextButton")
		card.AutoButtonColor = false
		card.Text = ""
		card.LayoutOrder = i
		card.BackgroundColor3 = (selected[currentSlot] == key) and C.StoneHover or C.StoneRaised
		card.BorderSizePixel = 0
		card.ZIndex = 12
		card.Parent = grid
		Theme.corner(card, Theme.Radius.Medium)
		Theme.stroke(card, worn and C.Soul or ((selected[currentSlot] == key) and C.BorderBright or C.Border), worn and 2 or 1)
		makeView(card, key)
		local name = Theme.label(card, { text = def.name, size = "Small", font = "Strong", align = Enum.TextXAlignment.Center, frameSize = UDim2.new(1, -6, 0, 22) })
		name.AnchorPoint = Vector2.new(0.5, 1)
		name.Position = UDim2.new(0.5, 0, 1, -3)
		name.TextScaled = true
		name.ZIndex = 14
		name.TextColor3 = owns(key) and C.Bone or C.BoneDim
		if worn then
			local tag = Theme.label(card, { text = "WORN", size = "Small", font = "Strong", color = C.Soul, frameSize = UDim2.fromOffset(60, 16) })
			tag.Position = UDim2.fromOffset(6, 4)
			tag.ZIndex = 14
			Theme.outlineText(tag)
		end
		card.Activated:Connect(function()
			selected[currentSlot] = key
			paint()
		end)
		table.insert(cards, card)
	end
end

local function paintDetails()
	for _, c in actionHolder:GetChildren() do
		c:Destroy()
	end
	local list = itemsOf(currentSlot)
	local key = selected[currentSlot] or (State.equipped and State.equipped[currentSlot]) or list[1]
	selected[currentSlot] = key
	local def = key and Items.Defs[key]
	if not def then
		nameLbl.Text = "Nothing here yet"
		slotLbl.Text = ""
		descLbl.Text = ""
		return
	end
	nameLbl.Text = def.name
	slotLbl.Text = Items.SLOT_INFO[def.slot].name .. " slot"
	descLbl.Text = def.description or ""
	local worn = State.equipped and State.equipped[currentSlot] == key
	local owned = owns(key)
	Theme.stoneButton(actionHolder, {
		text = (not owned) and "Not owned" or (worn and "Take off" or "Equip"),
		color = worn and "red" or "green",
		disabled = not owned,
		size = UDim2.fromOffset(170, 44), zIndex = 13,
		onClick = function()
			EquipItem:FireServer(currentSlot, (not worn) and key or nil)
		end,
	})
end

paint = function()
	paintTabs()
	paintDetails() -- (first: it picks the default selection the cards highlight)
	paintCards()
end

-- ============================================================
-- Opening and closing: the camera glides round to the front of the character
-- ============================================================
local session -- the running WorldView session
local yaw = 0 -- dragging turns the view round the character

local function viewCFrame(hrp)
	local base = hrp.CFrame * CFrame.Angles(0, yaw, 0)
	local focus = hrp.Position + Vector3.new(0, 0.5, 0)
	local pos = focus + base.LookVector * CAM_DIST + Vector3.new(0, 1.2, 0)
	return CFrame.lookAt(pos, focus) * CFrame.new(CAM_SHIFT, 0, 0)
end

function OutfitsPanel.open()
	if OutfitsPanel.active then
		return
	end
	yaw = 0
	local s = WorldView.open({
		keep = { ui },
		openTime = T_MOVE,
		fov = CAM_FOV,
		goal = function(v)
			return viewCFrame(v.hrp)
		end,
		onStep = function(v)
			updateViews(v.clock)
		end,
		onClose = function()
			TweenService:Create(frame, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = UDim2.new(1, PANEL_W + 80, 0.5, 0) }):Play()
		end,
		onFinish = function(v)
			if session == v then
				session = nil
			end
			ui.Enabled = false
			OutfitsPanel.active = false
		end,
	})
	if not s then
		return
	end
	OutfitsPanel.active = true
	session = s
	selected = {}
	paint()
	ui.Enabled = true
	frame.Visible = true
	frame.Position = UDim2.new(1, PANEL_W, 0.5, 0)
	TweenService:Create(frame, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = UDim2.new(1, -70, 0.5, 0) }):Play()
end

function OutfitsPanel.close()
	if session then
		session:close()
	end
end

function OutfitsPanel.toggle()
	if OutfitsPanel.active then
		OutfitsPanel.close()
	else
		OutfitsPanel.open()
	end
end

-- another window opened (Windows hides this frame): close properly
frame:GetPropertyChangedSignal("Visible"):Connect(function()
	if not frame.Visible and OutfitsPanel.active then
		OutfitsPanel.close()
	end
end)

-- ============================================================
-- The HUD tile (right column, fifth: under Codex), the keys and dragging to turn
-- ============================================================
Theme.iconTile(screenGui, {
	icon = Theme.Image.Icon.Ascend, text = "Outfits", -- placeholder icon until a painted one exists
	position = UDim2.new(1, -84, 0.5, -100 + 4 * 84), zIndex = 5,
	onClick = function()
		OutfitsPanel.toggle()
	end,
})

local dragging = false
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.O then
		OutfitsPanel.toggle()
	elseif OutfitsPanel.active and input.KeyCode == Enum.KeyCode.Escape then
		OutfitsPanel.close()
	elseif OutfitsPanel.active and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
		dragging = true
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragging = false
	end
end)
UserInputService.InputChanged:Connect(function(input)
	if dragging and session and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
		yaw -= input.Delta.X * DRAG_SPEED
	end
end)

Sync.onApplied(function()
	if OutfitsPanel.active then
		paint()
	end
end)

return OutfitsPanel
