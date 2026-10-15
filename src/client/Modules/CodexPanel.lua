-- The Codex: every pullable unit, read in the necromancer's own grimoire (the book the pull cinematics absorb units into).
-- Opened with the "Codex" tile (right HUD column) or C: the character holds the grimoire up in their left hand, it opens,
-- the camera glides over their shoulder and zooms onto the pages, and the book UI fades in exactly over them. Closing
-- (X, Esc or C) plays it backwards.
-- The book: one spread per rarity (Common .. Primordial), the rarity's units on the two pages: a 3D portrait, the name,
-- "1 in X", base DPS and how many the player has ever pulled. Units never pulled are a black silhouette with "???".
-- Discovered = State.codex (server PlayerData.codex, saved; counted in Digging, older saves filled from the inventory and
-- the graves). Builds its UI when required (no init call).
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
	local name = text(f, { size = UDim2.fromScale(0.58, 0.24), position = UDim2.fromScale(0.4, 0.08) })
	local odds = text(f, { size = UDim2.fromScale(0.58, 0.15), position = UDim2.fromScale(0.4, 0.38), font = Enum.Font.GothamMedium, color = INK_DIM })
	local dps = text(f, { size = UDim2.fromScale(0.58, 0.15), position = UDim2.fromScale(0.4, 0.56), font = Enum.Font.GothamMedium, color = INK_DIM })
	local pulled = text(f, { size = UDim2.fromScale(0.58, 0.15), position = UDim2.fromScale(0.4, 0.74), font = Enum.Font.GothamMedium, color = INK_DIM })
	-- (Malak only, once discovered) his Fleet Strike finisher: buy it here or see that it is owned
	local fleet = Theme.stoneButton(f, {
		text = "", color = "blue", size = UDim2.fromScale(0.5, 0.2),
		position = UDim2.fromScale(0.97, 0.94), anchor = Vector2.new(1, 1), zIndex = 4,
		onClick = function()
			local remote = ReplicatedStorage:FindFirstChild("BuyGemItem")
			if remote and not State.fleetStrike then
				remote:FireServer("FleetStrike")
			end
		end,
	})
	fleet.root.Visible = false
	entries[i] = { frame = f, stroke = stroke, portrait = portrait, name = name, odds = odds, dps = dps, pulled = pulled, fleet = fleet }
end

-- page turning, bookmarks, close
local spread = 1
local paint
local function turn(delta)
	spread = math.clamp(spread + delta, 1, #RARITY_LIST)
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
local bookmarks = {}
for i, rarity in ipairs(RARITY_LIST) do
	local b = Instance.new("TextButton")
	b.AutoButtonColor = false
	b.Text = ""
	b.BorderSizePixel = 0
	b.BackgroundColor3 = Rarities.Color[rarity] or Color3.new(1, 1, 1)
	b.AnchorPoint = Vector2.new(0.5, 1)
	b.Size = UDim2.fromScale(0.035, 0.07)
	b.Position = UDim2.fromScale(0.62 + (i - 1) * 0.04, 0.012)
	b.Parent = book
	Theme.corner(b, 4)
	b.Activated:Connect(function()
		spread = i
		paint()
	end)
	bookmarks[i] = b
end

paint = function()
	local codex = State.codex or {}
	local rarity = RARITY_LIST[spread]
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
	pageLbl.Text = spread .. " / " .. #RARITY_LIST
	for i, b in ipairs(bookmarks) do
		b.Size = (i == spread) and UDim2.fromScale(0.035, 0.1) or UDim2.fromScale(0.035, 0.07)
	end
	for i, entry in ipairs(entries) do
		local e = pool[i]
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
			entry.odds.Text = "1 in " .. fmt(Units.getBaseOneIn(unitType))
			local def = Units.Stats[unitType]
			entry.dps.Text = n and ("Base DPS  " .. fmt(math.floor(def.damage / def.attackCD))) or "Base DPS  ???"
			entry.pulled.Text = n and ("Pulled  " .. n .. "x") or "Not yet discovered"
			entry.fleet.root.Visible = n ~= nil and unitType == "Malak"
			if unitType == "Malak" then
				local price = require(ReplicatedStorage.Shared.Economy).FLEET_STRIKE_PRICE
				entry.fleet.label.Text = State.fleetStrike and "Fleet Strike: owned" or ("Fleet Strike  " .. price .. " Gems")
				entry.fleet.root:SetAttribute("Disabled", State.fleetStrike == true or (State.gems or 0) < price)
			end
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
		CodexPanel.close()
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
