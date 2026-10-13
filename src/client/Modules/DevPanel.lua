-- Studio-only developer panel: a DEV button on the left opens a list of every unit. Click one to spawn it next
-- to your wall (it attacks right away), "Clear dev units" removes them again. The server (DevTools) enforces
-- Studio-only, so this does nothing in a live game; the panel is not even created there.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

if not RunService:IsStudio() then
	return {}
end

local screenGui = require(script.Parent.Gui)
local Units = require(ReplicatedStorage.Shared.Units)
local Rarities = require(ReplicatedStorage.Shared.Rarities)

local spawnEvent = ReplicatedStorage:WaitForChild("DevSpawnUnit")
local clearEvent = ReplicatedStorage:WaitForChild("DevClearUnits")

local BG = Color3.fromRGB(24, 22, 34)
local BTN = Color3.fromRGB(44, 40, 62)
local BTN_HOVER = Color3.fromRGB(66, 60, 92)

local function round(inst, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = inst
end

local function makeButton(parent, text, color)
	local b = Instance.new("TextButton")
	b.BackgroundColor3 = BTN
	b.AutoButtonColor = false
	b.Text = text
	b.TextColor3 = color or Color3.fromRGB(235, 235, 245)
	b.Font = Enum.Font.GothamBold
	b.TextSize = 14
	b.TextXAlignment = Enum.TextXAlignment.Left
	b.Parent = parent
	round(b, 6)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 8)
	pad.Parent = b
	b.MouseEnter:Connect(function()
		b.BackgroundColor3 = BTN_HOVER
	end)
	b.MouseLeave:Connect(function()
		b.BackgroundColor3 = BTN
	end)
	return b
end

-- ── toggle button ─────────────────────────────────────────────
local toggle = Instance.new("TextButton")
toggle.Name = "DevToggle"
toggle.Size = UDim2.fromOffset(64, 34)
toggle.Position = UDim2.new(0, 8, 0.62, 0)
toggle.BackgroundColor3 = Color3.fromRGB(120, 60, 200)
toggle.Text = "DEV"
toggle.TextColor3 = Color3.new(1, 1, 1)
toggle.Font = Enum.Font.GothamBold
toggle.TextSize = 14
toggle.Parent = screenGui
round(toggle, 8)

-- ── panel ─────────────────────────────────────────────────────
local panel = Instance.new("Frame")
panel.Name = "DevPanel"
panel.Size = UDim2.fromOffset(370, 430)
panel.Position = UDim2.new(0, 80, 0.62, -200)
panel.BackgroundColor3 = BG
panel.BackgroundTransparency = 0.05
panel.Visible = false
panel.Parent = screenGui
round(panel, 10)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -16, 0, 22)
title.Position = UDim2.fromOffset(8, 6)
title.BackgroundTransparency = 1
title.Text = "Spawn a unit at your wall (Studio only)"
title.TextColor3 = Color3.fromRGB(200, 190, 235)
title.Font = Enum.Font.GothamBold
title.TextSize = 14
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = panel

-- where spawned units start: right in front of the wall (attacking at once) or at the graves (they march to their
-- formation slot, so you can watch the army form up)
local atGraves = false -- false = WALL, true = GRAVES, "inventory" = put it in the inventory (to test slots, Forge, ...)
local mode = makeButton(panel, "Spawn at: WALL (click to switch)", Color3.fromRGB(160, 220, 255))
mode.Size = UDim2.new(0.46, -10, 0, 30)
mode.Position = UDim2.fromOffset(8, 32)
mode.MouseButton1Click:Connect(function()
	if atGraves == false then
		atGraves = true
	elseif atGraves == true then
		atGraves = "inventory"
	else
		atGraves = false
	end
	mode.Text = (atGraves == true and "Spawn at: GRAVES (march in)")
		or (atGraves == "inventory" and "Give to: INVENTORY")
		or "Spawn at: WALL (click to switch)"
end)

-- the level spawned units get (to preview the level auras: 3, 6, 9, 10)
local DEV_LEVELS = { 0, 3, 6, 9, 10 }
local devLevelIndex = 1
local levelBtn = makeButton(panel, "Lv 0", Color3.fromRGB(150, 255, 190))
levelBtn.Size = UDim2.new(0.18, -6, 0, 30)
levelBtn.Position = UDim2.new(0.46, 2, 0, 32)
levelBtn.MouseButton1Click:Connect(function()
	devLevelIndex = devLevelIndex % #DEV_LEVELS + 1
	levelBtn.Text = "Lv " .. DEV_LEVELS[devLevelIndex]
end)

local clear = makeButton(panel, "Clear", Color3.fromRGB(255, 130, 130))
clear.Size = UDim2.new(0.36, -10, 0, 30)
clear.Position = UDim2.new(0.64, 4, 0, 32)
clear.MouseButton1Click:Connect(function()
	clearEvent:FireServer()
end)

-- preview the gacha reveal without rolling (random units; the rarity picks how dramatic it is)
local GachaReveal = require(script.Parent.GachaReveal)
local function randomResults(count, rarityName)
	local results = {}
	for _ = 1, count do
		local pool = {}
		for name in pairs(Units.Stats) do
			if not rarityName or Units.Rarity[name] == rarityName then
				table.insert(pool, name)
			end
		end
		local unit = pool[math.random(#pool)]
		table.insert(results, { unitType = unit, rarity = Units.Rarity[unit], pity = math.random(0, 59), oneIn = Units.getBaseOneIn(unit) })
	end
	return results
end
local previewRarity = nil -- nil = any
local previewBtn = makeButton(panel, "Reveal x1", Color3.fromRGB(200, 255, 210))
previewBtn.Size = UDim2.new(0.3, -8, 0, 28)
previewBtn.Position = UDim2.fromOffset(8, 66)
-- like a pull opened by hand: the grave cinematic in the world, then the overlay at the result
local GraveCinematic = require(script.Parent.GraveCinematic)
local function previewOpening(count)
	local results = randomResults(count, previewRarity)
	panel.Visible = false
	local started = GraveCinematic.play(results, { graveType = "Mossy", onDone = function()
		panel.Visible = true
		GachaReveal.play(results, { graveType = "Mossy", skipShow = true })
	end })
	if not started then
		panel.Visible = true
		GachaReveal.play(results, { graveType = "Mossy" })
	end
end
previewBtn.MouseButton1Click:Connect(function()
	previewOpening(1)
end)
local previewBtn10 = makeButton(panel, "Reveal x10", Color3.fromRGB(200, 255, 210))
previewBtn10.Size = UDim2.new(0.3, -8, 0, 28)
previewBtn10.Position = UDim2.new(0.3, 4, 0, 66)
previewBtn10.MouseButton1Click:Connect(function()
	previewOpening(10)
end)
local rarityBtn = makeButton(panel, "Rarity: any", Color3.fromRGB(255, 230, 160))
rarityBtn.Size = UDim2.new(0.4, -8, 0, 28)
rarityBtn.Position = UDim2.new(0.6, 4, 0, 66)
rarityBtn.MouseButton1Click:Connect(function()
	-- cycle: any, then every rarity from the lowest to the highest
	local order = {}
	for r in pairs(Rarities.Rank) do
		table.insert(order, r)
	end
	table.sort(order, function(a, b) return Rarities.Rank[a] < Rarities.Rank[b] end)
	local nextIndex = 1
	for i, r in ipairs(order) do
		if r == previewRarity then
			nextIndex = i + 1
		end
	end
	previewRarity = order[nextIndex] -- nil after the last one: back to "any"
	rarityBtn.Text = "Rarity: " .. (previewRarity or "any")
end)

-- preview the star summon cinematic
local StarSummon = require(script.Parent.StarSummon)
local starBtn = makeButton(panel, "Star x1", Color3.fromRGB(255, 240, 170))
starBtn.Size = UDim2.new(0.3, -8, 0, 28)
starBtn.Position = UDim2.fromOffset(8, 100)
starBtn.MouseButton1Click:Connect(function()
	panel.Visible = false
	StarSummon.play(randomResults(1, previewRarity), { graveType = "Mossy", onDone = function() panel.Visible = true end })
end)
local starBtn10 = makeButton(panel, "Star x10", Color3.fromRGB(255, 240, 170))
starBtn10.Size = UDim2.new(0.3, -8, 0, 28)
starBtn10.Position = UDim2.new(0.3, 4, 0, 100)
starBtn10.MouseButton1Click:Connect(function()
	panel.Visible = false
	StarSummon.play(randomResults(10, previewRarity), { graveType = "Mossy", onDone = function() panel.Visible = true end })
end)

local list = Instance.new("ScrollingFrame")
list.Size = UDim2.new(1, -16, 1, -142)
list.Position = UDim2.fromOffset(8, 136)
list.BackgroundTransparency = 1
list.BorderSizePixel = 0
list.ScrollBarThickness = 6
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
list.CanvasSize = UDim2.new()
list.Parent = panel

local grid = Instance.new("UIGridLayout")
grid.CellSize = UDim2.new(0.5, -4, 0, 32)
grid.CellPadding = UDim2.fromOffset(6, 6)
grid.SortOrder = Enum.SortOrder.LayoutOrder
grid.Parent = list

-- units grouped by rarity, common first, then by name
local names = {}
for name in pairs(Units.Stats) do
	table.insert(names, name)
end
local rank = {}
for i, rarity in ipairs(Rarities.Order) do
	rank[rarity] = #Rarities.Order - i -- Order is strongest first
end
table.sort(names, function(a, b)
	local ra, rb = rank[Units.Rarity[a]] or 0, rank[Units.Rarity[b]] or 0
	if ra ~= rb then
		return ra < rb
	end
	return a < b
end)

for i, name in ipairs(names) do
	local rarity = Units.Rarity[name]
	local button = makeButton(list, name, Rarities.Color[rarity])
	button.LayoutOrder = i
	button.MouseButton1Click:Connect(function()
		spawnEvent:FireServer(name, atGraves, DEV_LEVELS[devLevelIndex])
	end)
end

toggle.MouseButton1Click:Connect(function()
	panel.Visible = not panel.Visible
end)

return {}
