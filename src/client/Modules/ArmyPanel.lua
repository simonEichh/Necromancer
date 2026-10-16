-- The Army screen (Design.md "Unit families, the commander slot and placement"): an in-world view over the player's
-- plot to build the army. Opened with the "Army" tile (left column, under Upgrades) or R; Esc / X / R closes.
--   * the camera rises behind the plot and looks down over the graves and the commander thrones (always upright)
--   * on the right the FAMILIES, like Teamfight Tactics' trait list: per family its count on the plot, the tiers
--     (2 / 4 / 6) and what the active tier gives; above them the COMMANDERS on the thrones with their title (their
--     unique trait). Counted like the server (Units.familyCounts: duplicates once, a shadow-form unit double).
--   * at the bottom the inventory: pick a unit, the graves it may stand on light up (commanders: the open thrones,
--     everyone else: the graves); click one to place it there (PlaceAtGrave). Clicking a unit standing on a grave /
--     throne takes it back (RecallUnit). The sealed throne buys itself (BuyGemItem "CommanderSlot").
--   * Place Best (the family-aware one on the server)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Theme = require(script.Parent.Theme)
local State = require(script.Parent.State)
local Sync = require(script.Parent.Sync)
local screenGui = require(script.Parent.Gui)
local UnitPortrait = require(script.Parent.UnitPortrait)
local WorldView = require(script.Parent.WorldView)
local Units = require(ReplicatedStorage.Shared.Units)
local Economy = require(ReplicatedStorage.Shared.Economy)
local Rarities = require(ReplicatedStorage.Shared.Rarities)

local player = Players.LocalPlayer
local C = Theme.Color

local ArmyPanel = {}
ArmyPanel.active = false

local T_MOVE = 0.9
local CAM_FOV = 55
local PANEL_W = 330
local GOLD = Color3.fromRGB(226, 186, 92)
local FAMILY_COLOR = {
	Bones = Color3.fromRGB(222, 210, 182), Flesh = Color3.fromRGB(196, 110, 100), Spirits = Color3.fromRGB(140, 220, 230),
	Beasts = Color3.fromRGB(200, 160, 100), Arcane = Color3.fromRGB(180, 140, 255),
}
local function prettyName(key)
	return (key:gsub("(%l)(%u)", "%1 %2"))
end
-- what a family's tier gives, in words
local function familyEffect(name, value)
	local fam = Units.Families[name]
	local pct = math.floor(value * 100 + 0.5) .. "%"
	if fam.kind == "damage" then return name .. " units +" .. pct .. " damage" end
	if fam.kind == "gate" then return "+" .. pct .. " damage to the gate" end
	if fam.kind == "gold" then return "+" .. pct .. " gold from hits" end
	if fam.kind == "burst" then return name .. " +" .. pct .. " damage for " .. fam.burstTime .. " s after a wall stands" end
	if fam.kind == "special" then return "Specials charge " .. pct .. " faster" end
	return ""
end

-- ============================================================
-- The UI
-- ============================================================
local ui = Instance.new("ScreenGui")
ui.Name = "ArmyUI"
ui.ResetOnSpawn = false
ui.IgnoreGuiInset = true
ui.DisplayOrder = 20
ui.Enabled = false
ui.Parent = player:WaitForChild("PlayerGui")

-- the right panel: commanders and families
local side = Instance.new("Frame")
side.AnchorPoint = Vector2.new(1, 0.5)
side.Position = UDim2.new(1, PANEL_W + 40, 0.42, 0)
side.Size = UDim2.fromOffset(PANEL_W, 470)
side.BackgroundColor3 = C.Stone
side.BackgroundTransparency = 0.08
side.BorderSizePixel = 0
side.Parent = ui
Theme.corner(side, 10)
Theme.stroke(side, C.Border, 2)
local function text(parent, props)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = props.font or Theme.Font.Strong
	l.TextColor3 = props.color or C.Bone
	l.TextScaled = true
	l.TextXAlignment = props.align or Enum.TextXAlignment.Left
	l.Text = props.text or ""
	l.Size = props.size
	l.Position = props.position
	l.ZIndex = props.z or 3
	l.Parent = parent
	return l
end
text(side, { text = "ARMY", size = UDim2.new(1, -70, 0, 30), position = UDim2.fromOffset(14, 10), font = Theme.Font.Title })
Theme.stoneButton(side, {
	text = "X", color = "red", size = UDim2.fromOffset(40, 30), position = UDim2.new(1, -50, 0, 10), zIndex = 5,
	onClick = function() ArmyPanel.close() end,
})
local commanderLbl = text(side, { size = UDim2.new(1, -28, 0, 20), position = UDim2.fromOffset(14, 48), font = Theme.Font.Body, color = GOLD })
local commanderLbl2 = text(side, { size = UDim2.new(1, -28, 0, 20), position = UDim2.fromOffset(14, 70), font = Theme.Font.Body, color = GOLD })
text(side, { text = "FAMILIES", size = UDim2.new(1, -28, 0, 22), position = UDim2.fromOffset(14, 100) })

local rows = {}
for i, name in ipairs(Units.FAMILY_ORDER) do
	local row = Instance.new("Frame")
	row.BackgroundColor3 = C.StoneRaised
	row.BorderSizePixel = 0
	row.Size = UDim2.new(1, -24, 0, 56)
	row.Position = UDim2.fromOffset(12, 128 + (i - 1) * 62)
	row.ZIndex = 2
	row.Parent = side
	Theme.corner(row, 6)
	local stroke = Theme.stroke(row, C.Border, 1)
	local nameLbl = text(row, { text = string.upper(name), size = UDim2.new(0.5, 0, 0, 20), position = UDim2.fromOffset(10, 5), color = FAMILY_COLOR[name] })
	local countLbl = text(row, { size = UDim2.new(0.18, 0, 0, 20), position = UDim2.new(0.5, 0, 0, 5), font = Theme.Font.Strong })
	-- the tiers 2 / 4 / 6 as three pips
	local pips = {}
	for t, need in ipairs(Units.FAMILY_THRESHOLDS) do
		local pip = text(row, { text = tostring(need), size = UDim2.fromOffset(22, 18), position = UDim2.new(1, -86 + (t - 1) * 26, 0, 6), align = Enum.TextXAlignment.Center, font = Theme.Font.Strong })
		pip.BackgroundTransparency = 0
		pip.BackgroundColor3 = C.Void
		Theme.corner(pip, 4)
		pips[t] = pip
	end
	local effectLbl = text(row, { size = UDim2.new(1, -20, 0, 18), position = UDim2.fromOffset(10, 31), font = Theme.Font.Body, color = C.BoneDim })
	rows[name] = { frame = row, stroke = stroke, name = nameLbl, count = countLbl, pips = pips, effect = effectLbl }
end

-- ============================================================
-- Tooltips (hover): a commander's unique trait, a family's three tiers
-- ============================================================
local HIGHLIGHT = "#F2C46B"
local tip = Instance.new("Frame")
tip.BackgroundColor3 = C.Void
tip.BackgroundTransparency = 0.05
tip.BorderSizePixel = 0
tip.Size = UDim2.fromOffset(300, 110)
tip.AnchorPoint = Vector2.new(1, 0)
tip.Visible = false
tip.ZIndex = 50
tip.Parent = ui
Theme.corner(tip, 8)
local tipStroke = Theme.stroke(tip, GOLD, 2)
local tipTitle = text(tip, { size = UDim2.new(1, -20, 0, 22), position = UDim2.fromOffset(10, 8), z = 51 })
local tipBody = text(tip, { size = UDim2.new(1, -20, 1, -40), position = UDim2.fromOffset(10, 34), font = Theme.Font.Body, z = 51 })
tipBody.RichText = true
tipBody.TextWrapped = true
tipBody.TextYAlignment = Enum.TextYAlignment.Top
local tipLimit = Instance.new("UITextSizeConstraint")
tipLimit.MaxTextSize = 16
tipLimit.Parent = tipBody
local function highlight(str)
	str = str:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")
	return (str:gsub("{(.-)}", function(num)
		local kept = num:gsub(" ", "\u{00A0}")
		return '<font color="' .. HIGHLIGHT .. '"><b>' .. kept .. "</b></font>"
	end))
end
local function showTip(anchor, title, body, color)
	tipTitle.Text = title
	tipTitle.TextColor3 = color or GOLD
	tipStroke.Color = color or GOLD
	tipBody.Text = body
	local pos = anchor.AbsolutePosition
	tip.Position = UDim2.fromOffset(pos.X - 10, pos.Y)
	tip.Visible = true
end
local function hideTip()
	tip.Visible = false
end
-- a commander's unique trait: its title and its passive's text (Units.Abilities kind "Passive")
local commanderTypes = {} -- [1|2] = unitType on that throne
local function commanderTip(k, anchor)
	local unitType = commanderTypes[k]
	if not unitType then return end
	local def = Units.Stats[unitType]
	local body = "No unique trait yet."
	for _, ab in ipairs(Units.Abilities[unitType] or {}) do
		if ab.kind == "Passive" then
			local ok, str = pcall(ab.text, def, Economy)
			if ok then body = highlight(str) end
		end
	end
	showTip(anchor, (def.title or prettyName(unitType)) .. "  (unique trait)", body, GOLD)
end
local function hoverable(gui, onEnter)
	gui.Active = true
	gui.MouseEnter:Connect(onEnter)
	gui.MouseLeave:Connect(hideTip)
end
hoverable(commanderLbl, function() commanderTip(1, commanderLbl) end)
hoverable(commanderLbl2, function() commanderTip(2, commanderLbl2) end)
for _, name in ipairs(Units.FAMILY_ORDER) do
	local r = rows[name]
	hoverable(r.frame, function()
		local fam = Units.Families[name]
		local lines = {}
		for t, need in ipairs(Units.FAMILY_THRESHOLDS) do
			table.insert(lines, "{" .. need .. "}:  " .. familyEffect(name, fam.tiers[t]))
		end
		table.insert(lines, "Duplicates count once, a unit in its shadow form counts double.")
		showTip(r.frame, string.upper(name) .. "  -  " .. fam.blurb, highlight(table.concat(lines, "\n")), FAMILY_COLOR[name])
	end)
end

-- the inventory strip at the bottom
local strip = Instance.new("Frame")
strip.AnchorPoint = Vector2.new(0.5, 1)
strip.Position = UDim2.new(0.5, 0, 1, 200)
strip.Size = UDim2.new(1, -60, 0, 150)
strip.BackgroundColor3 = C.Stone
strip.BackgroundTransparency = 0.08
strip.BorderSizePixel = 0
strip.Parent = ui
Theme.corner(strip, 10)
Theme.stroke(strip, C.Border, 2)
local hint = text(strip, { size = UDim2.new(0.6, 0, 0, 20), position = UDim2.fromOffset(14, 6), font = Theme.Font.Body, color = C.BoneDim })
Theme.stoneButton(strip, {
	text = "Place Best", color = "gold", size = UDim2.fromOffset(150, 34), position = UDim2.new(1, -14, 0, 4), anchor = Vector2.new(1, 0), zIndex = 5,
	onClick = function()
		local r = ReplicatedStorage:FindFirstChild("PlaceBest")
		if r then r:FireServer() end
	end,
})
local cards = Instance.new("ScrollingFrame")
cards.BackgroundTransparency = 1
cards.BorderSizePixel = 0
cards.Position = UDim2.fromOffset(10, 42)
cards.Size = UDim2.new(1, -20, 1, -48)
cards.ScrollingDirection = Enum.ScrollingDirection.X
cards.AutomaticCanvasSize = Enum.AutomaticSize.X
cards.CanvasSize = UDim2.new()
cards.ScrollBarThickness = 6
cards.ZIndex = 3
cards.Parent = strip
local cardLayout = Instance.new("UIListLayout")
cardLayout.FillDirection = Enum.FillDirection.Horizontal
cardLayout.Padding = UDim.new(0, 8)
cardLayout.SortOrder = Enum.SortOrder.LayoutOrder
cardLayout.Parent = cards

-- ============================================================
-- State: the selected inventory unit, highlights on the graves
-- ============================================================
local selected -- inventory slot index
local highlights = {}
local cardPool = {} -- [i] = card (reused)

local function myGraves()
	-- every grave / throne on the plot: { [slotIndex] = instance }
	local list = {}
	for _, inst in ipairs(Workspace:GetDescendants()) do
		local idx = inst:GetAttribute("GraveSlot")
		if idx and inst:GetAttribute("OwnerId") == player.UserId and (inst:IsA("Model") or not list[idx]) then
			list[idx] = inst
		end
	end
	return list
end
local function occupiedSlots()
	local occ = {}
	for _, p in ipairs(State.placed or {}) do
		occ[p.slot] = p
	end
	return occ
end
local function clearHighlights()
	for _, h in ipairs(highlights) do
		h:Destroy()
	end
	highlights = {}
end
local function showTargets()
	clearHighlights()
	local unit = selected and State.inventory[selected]
	if not unit then
		return
	end
	local commander = Units.isSignature(unit.unitType) or Units.isSovereign(unit.unitType)
	local occ = occupiedSlots()
	for idx, inst in pairs(myGraves()) do
		local isThrone = idx > 100
		if isThrone == commander and not occ[idx] and not inst:GetAttribute("Sealed") then
			local h = Instance.new("Highlight")
			h.FillColor = commander and GOLD or Color3.fromRGB(120, 255, 170)
			h.FillTransparency = 0.7
			h.OutlineColor = h.FillColor
			h.OutlineTransparency = 0.1
			h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
			h.Adornee = inst:IsA("Model") and inst or inst.Parent
			h.Parent = ui
			table.insert(highlights, h)
		end
	end
end

local paint
local function paintCards()
	-- the inventory, strongest first
	local list = {}
	for slot, u in pairs(State.inventory or {}) do
		table.insert(list, { slot = slot, unit = u })
	end
	local function dps(e)
		local d = Units.Stats[e.unit.unitType]
		return d and d.damage / d.attackCD * Economy.levelMultiplier(e.unit.level or 0) or 0
	end
	table.sort(list, function(a, b) return dps(a) > dps(b) end)
	if selected and not State.inventory[selected] then
		selected = nil
	end
	for i, e in ipairs(list) do
		local card = cardPool[i]
		if not card then
			card = {}
			local f = Instance.new("TextButton")
			f.AutoButtonColor = false
			f.Text = ""
			f.Size = UDim2.fromOffset(92, 96)
			f.BackgroundColor3 = C.StoneRaised
			f.BorderSizePixel = 0
			f.ZIndex = 4
			f.Parent = cards
			Theme.corner(f, 6)
			card.stroke = Theme.stroke(f, C.Border, 2)
			local holder = Instance.new("Frame")
			holder.BackgroundTransparency = 1
			holder.Size = UDim2.new(1, 0, 0, 56)
			holder.ZIndex = 5
			holder.Parent = f
			card.portrait = UnitPortrait.attach(holder, { size = UDim2.fromScale(1, 1), zIndex = 6 })
			card.name = text(f, { size = UDim2.new(1, -8, 0, 16), position = UDim2.fromOffset(4, 56), align = Enum.TextXAlignment.Center, z = 6 })
			card.info = text(f, { size = UDim2.new(1, -8, 0, 14), position = UDim2.fromOffset(4, 76), align = Enum.TextXAlignment.Center, font = Theme.Font.Body, z = 6 })
			card.frame = f
			f.Activated:Connect(function()
				selected = (selected == card.slot) and nil or card.slot
				paint()
			end)
			cardPool[i] = card
		end
		card.slot = e.slot
		card.frame.Visible = true
		card.frame.LayoutOrder = i
		card.portrait.set(e.unit.unitType)
		card.name.Text = prettyName(e.unit.unitType)
		local fam = Units.FamilyOf[e.unit.unitType]
		local commander = Units.isSignature(e.unit.unitType) or Units.isSovereign(e.unit.unitType)
		card.info.Text = (commander and "Commander" or (fam or "")) .. "  Lv " .. (e.unit.level or 0)
		card.info.TextColor3 = commander and GOLD or (FAMILY_COLOR[fam] or C.BoneDim)
		local rarity = Units.Rarity[e.unit.unitType]
		card.stroke.Color = (selected == e.slot) and C.Soul or (Rarities.Color[rarity] or C.Border)
		card.stroke.Thickness = (selected == e.slot) and 3 or 2
	end
	for i = #list + 1, #cardPool do
		cardPool[i].frame.Visible = false
		cardPool[i].slot = nil
	end
	hint.Text = selected and "Click a glowing grave to place it" or (#list > 0 and "Pick a unit, or click one on a grave to take it back" or "Click a unit on a grave to take it back")
end

local function paintSide()
	local placed = State.placed or {}
	local counts = Units.familyCounts(placed, Economy.AWAKEN_LEVEL)
	for _, name in ipairs(Units.FAMILY_ORDER) do
		local r = rows[name]
		local n = counts[name] or 0
		local tier = Units.familyTier(n)
		local fam = Units.Families[name]
		local nextNeed = Units.FAMILY_THRESHOLDS[tier + 1]
		r.count.Text = tostring(n)
		r.count.TextColor3 = tier > 0 and FAMILY_COLOR[name] or C.BoneDim
		for t, pip in ipairs(r.pips) do
			pip.BackgroundColor3 = t <= tier and FAMILY_COLOR[name] or C.Void
			pip.TextColor3 = t <= tier and C.Void or C.BoneDim
		end
		if tier > 0 then
			r.effect.Text = familyEffect(name, fam.tiers[tier])
			r.effect.TextColor3 = C.Bone
		else
			r.effect.Text = nextNeed and (nextNeed .. " for: " .. familyEffect(name, fam.tiers[1])) or ""
			r.effect.TextColor3 = C.BoneDim
		end
		r.stroke.Color = tier > 0 and FAMILY_COLOR[name] or C.Border
	end
	-- the commanders on the thrones, with their title (their unique trait)
	local cmd = {}
	table.clear(commanderTypes)
	for _, p in ipairs(placed) do
		if p.slot > 100 then
			local def = Units.Stats[p.unitType]
			cmd[p.slot - 100] = prettyName(p.unitType) .. (def and def.title and ("  -  " .. def.title) or "")
			commanderTypes[p.slot - 100] = p.unitType
		end
	end
	local owned = State.commanderSlots or 1
	commanderLbl.Text = "Commander:  " .. (cmd[1] or "empty throne")
	commanderLbl2.Text = owned >= 2 and ("Commander:  " .. (cmd[2] or "empty throne"))
		or ("Second throne:  " .. Economy.COMMANDER_SLOT_PRICE .. " Gems (click it)")
	commanderLbl2.TextColor3 = owned >= 2 and GOLD or C.BoneDim
end

paint = function()
	paintCards()
	paintSide()
	showTargets()
end

-- ============================================================
-- Clicking the graves in the world
-- ============================================================
local function graveAt(screenPos)
	local camera = Workspace.CurrentCamera
	local ray = camera:ScreenPointToRay(screenPos.X, screenPos.Y) -- (input positions are screen points: the top bar inset is taken care of)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character }
	local hit = Workspace:Raycast(ray.Origin, ray.Direction * 400, params)
	local inst = hit and hit.Instance
	while inst and inst ~= Workspace do
		local idx = inst:GetAttribute("GraveSlot")
		if idx and inst:GetAttribute("OwnerId") == player.UserId then
			return idx, inst
		end
		inst = inst.Parent
	end
	return nil
end
local function clickWorld(screenPos)
	local idx, inst = graveAt(screenPos)
	if not idx then
		return
	end
	if inst:GetAttribute("Sealed") then
		local r = ReplicatedStorage:FindFirstChild("BuyGemItem")
		if r then r:FireServer("CommanderSlot") end
		return
	end
	if occupiedSlots()[idx] then
		local r = ReplicatedStorage:FindFirstChild("RecallUnit")
		if r then r:FireServer(idx) end
		return
	end
	if selected then
		local r = ReplicatedStorage:FindFirstChild("PlaceAtGrave")
		if r then r:FireServer(selected, idx) end
		selected = nil
		clearHighlights()
	end
end

-- ============================================================
-- Opening and closing
-- ============================================================
local session
local function myPlotFrame()
	for _, plot in ipairs((Workspace:FindFirstChild("Plots") or Workspace):GetChildren()) do
		if plot:GetAttribute("OwnerId") == player.UserId then
			local base = plot:FindFirstChild("Base")
			if base then
				return base.CFrame * CFrame.new(0, base.Size.Y / 2, 0)
			end
		end
	end
	return nil
end

function ArmyPanel.open()
	if ArmyPanel.active then return end
	local frame = myPlotFrame()
	if not frame then return end
	-- behind the plot (towards the plaza) and high up, looking down over the graves to the thrones; upright
	local look = Vector3.new(frame.LookVector.X, 0, frame.LookVector.Z).Unit
	local camPos = frame.Position - look * 22 + Vector3.new(0, 38, 0)
	local camLook = frame.Position + look * 6
	local s = WorldView.open({
		keep = { ui },
		openTime = T_MOVE,
		fov = CAM_FOV,
		goal = function()
			return CFrame.lookAt(camPos, camLook)
		end,
		onClose = function()
			clearHighlights()
			hideTip()
			TweenService:Create(side, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = UDim2.new(1, PANEL_W + 40, 0.42, 0) }):Play()
			TweenService:Create(strip, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = UDim2.new(0.5, 0, 1, 200) }):Play()
		end,
		onFinish = function(v)
			if session == v then
				session = nil
			end
			ui.Enabled = false
			ArmyPanel.active = false
		end,
	})
	if not s then return end
	ArmyPanel.active = true
	session = s
	selected = nil
	ui.Enabled = true
	paint()
	TweenService:Create(side, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = UDim2.new(1, -20, 0.42, 0) }):Play()
	TweenService:Create(strip, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = UDim2.new(0.5, 0, 1, -14) }):Play()
end

function ArmyPanel.close()
	if session then
		session:close()
	end
end

function ArmyPanel.toggle()
	if ArmyPanel.active then
		ArmyPanel.close()
	else
		ArmyPanel.open()
	end
end

-- ============================================================
-- The HUD tile (left column, fifth: under Upgrades), the keys, clicks
-- ============================================================
Theme.iconTile(screenGui, {
	icon = Theme.Image.Icon.Graves, text = "Army", -- (placeholder icon until a painted one exists)
	position = UDim2.new(0, 16, 0.5, -200 + 4 * 84), zIndex = 5,
	onClick = function()
		ArmyPanel.toggle()
	end,
})
UserInputService.InputBegan:Connect(function(input, processed)
	if input.KeyCode == Enum.KeyCode.R and not processed then
		ArmyPanel.toggle()
	elseif ArmyPanel.active and input.KeyCode == Enum.KeyCode.Escape then
		ArmyPanel.close()
	elseif ArmyPanel.active and not processed
		and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
		clickWorld(Vector2.new(input.Position.X, input.Position.Y))
	end
end)
Sync.onApplied(function()
	if ArmyPanel.active then
		paint()
	end
end)

return ArmyPanel
