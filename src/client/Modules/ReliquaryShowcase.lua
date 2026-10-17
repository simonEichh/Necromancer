-- The Reliquary's showcase (the pedestal: tools/studio/build_reliquary.lua, HubDecor.Reliquary): a big copy of a chase
-- unit turns slowly on the pedestal, playing its idle (UnitAnimator, through the ProceduralUnit tag), and the plate shows
-- its name, title, rarity, its "1 in N" (Units.getBaseOneIn, as in the Codex) and who pulled it last (server
-- ShowcasePulls: attributes on ReplicatedStorage.ShowcasePulls, global across servers). Every SHOW_TIME s it dissolves into
-- souls sinking into the pedestal and the next Sovereign rises (only Sovereigns are shown). Client only: every player builds their own copy.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Units = require(ReplicatedStorage.Shared.Units)
local Rarities = require(ReplicatedStorage.Shared.Rarities)
local GameData = require(script.Parent.GameData)

local SCALE = 3 -- (times the unit's size on the lane)
local SHOW_TIME = 18
local FADE_TIME = 1.4
local TURN_SPEED = 0.25 -- rad/s
local PROP_TAG = "ProceduralUnit"
local SOUL = Color3.fromRGB(150, 110, 240)

-- ============================================================
-- The odds
-- ============================================================
local function withCommas(n)
	local s = tostring(math.floor(n + 0.5))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end

-- ============================================================
-- What is shown, in turn
-- ============================================================
local SHOWN = {} -- (only the Sovereigns, the user's call)
for name in pairs(Units.Stats) do
	if Units.isSovereign(name) then
		table.insert(SHOWN, name)
	end
end
table.sort(SHOWN) -- (a fixed order)
if #SHOWN == 0 then
	return {}
end

-- (in the background: waiting for the pedestal must not hold up the modules required after this one)
task.spawn(function()
	-- ============================================================
	-- The plate
	-- ============================================================
	local reliquary = Workspace:WaitForChild("HubDecor", 30)
	reliquary = reliquary and reliquary:WaitForChild("Reliquary", 30)
	local anchor = reliquary and reliquary:WaitForChild("ShowcaseAnchor", 30)
	local plate = reliquary and reliquary:WaitForChild("Plate", 30)
	if not (anchor and plate) then
		return
	end

	local gui = Instance.new("SurfaceGui")
	gui.Name = "ReliquaryPlate"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 60
	gui.LightInfluence = 0
	gui.MaxDistance = 90
	gui.Parent = plate
	local function label(y, h, font, color)
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Position = UDim2.fromScale(0.05, y)
		l.Size = UDim2.fromScale(0.9, h)
		l.Font = font
		l.TextScaled = true
		l.TextColor3 = color
		l.Text = ""
		l.Parent = gui
		return l
	end
	local nameLbl = label(0.05, 0.26, Enum.Font.Sarpanch, Color3.fromRGB(232, 226, 210))
	local titleLbl = label(0.31, 0.12, Enum.Font.Garamond, Color3.fromRGB(170, 160, 140))
	local classLbl = label(0.44, 0.11, Enum.Font.RobotoMono, Color3.fromRGB(200, 200, 200))
	local oddsLbl = label(0.57, 0.18, Enum.Font.Sarpanch, Color3.fromRGB(205, 190, 255))
	local pulledLbl = label(0.78, 0.13, Enum.Font.Garamond, Color3.fromRGB(190, 180, 160))
	local pulls = ReplicatedStorage:WaitForChild("ShowcasePulls", 30)
	local shownType
	local function writePulled()
		local who = shownType and pulls and pulls:GetAttribute(shownType)
		pulledLbl.Text = who and ("Pulled by " .. who) or "Never pulled yet"
	end
	if pulls then
		pulls.AttributeChanged:Connect(function(name)
			if name == shownType then
				writePulled()
			end
		end)
	end

	local function writePlate(unitType)
		local def = Units.Stats[unitType]
		local rarity = Units.Rarity[unitType] or ""
		nameLbl.Text = (GameData.UNIT_NAMES and GameData.UNIT_NAMES[unitType]) or unitType
		titleLbl.Text = def and def.title or ""
		classLbl.Text = string.upper(rarity) .. "  " .. (Units.isSovereign(unitType) and "SOVEREIGN" or "SIGNATURE")
		classLbl.TextColor3 = Rarities.Color[rarity] or Color3.new(1, 1, 1)
		oddsLbl.Text = "1 in " .. withCommas(Units.getBaseOneIn(unitType))
		shownType = unitType
		writePulled()
	end

	-- ============================================================
	-- The unit on the pedestal
	-- ============================================================
	local current -- { model, root, parts = { {part, base} }, rootHeight, shownAt }
	local index = 0
	local angle = 0

	local soulHolder = Instance.new("Part")
	soulHolder.Name = "ReliquarySouls"
	soulHolder.Anchored = true
	soulHolder.CanCollide = false
	soulHolder.CanQuery = false
	soulHolder.CanTouch = false
	soulHolder.Transparency = 1
	soulHolder.Size = Vector3.new(4, 0.2, 4)
	soulHolder.CFrame = anchor.CFrame
	soulHolder.Parent = Workspace
	local souls = Instance.new("ParticleEmitter")
	souls.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	souls.Shape = Enum.ParticleEmitterShape.Box
	souls.Color = ColorSequence.new(Color3.fromRGB(205, 190, 255), SOUL)
	souls.LightEmission = 1
	souls.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
	souls.Lifetime = NumberRange.new(1, 2)
	souls.Speed = NumberRange.new(2, 6)
	souls.SpreadAngle = Vector2.new(30, 30)
	souls.Rate = 0
	souls.EmissionDirection = Enum.NormalId.Top
	souls.Parent = soulHolder

	local function spawnUnit(unitType)
		local template = ReplicatedStorage:FindFirstChild("UnitModels") and ReplicatedStorage.UnitModels:FindFirstChild(unitType)
		if not template then
			return nil
		end
		local def = Units.Stats[unitType]
		local scale = (def and def.size.X / 2 * 0.9 or 1) * SCALE
		local m = template:Clone()
		local parts = {}
		for _, d in ipairs(m:GetDescendants()) do
			if d:IsA("BaseScript") or d:IsA("Humanoid") then
				d:Destroy()
			elseif d:IsA("BasePart") then
				d.Anchored = false
				d.CanCollide = false
				d.CanQuery = false
				d.CanTouch = false
				table.insert(parts, d)
			end
		end
		m:ScaleTo(scale)
		local root = m.PrimaryPart or m:FindFirstChild("HumanoidRootPart", true)
		if not root then
			m:Destroy()
			return nil
		end
		root.Anchored = true
		m:SetAttribute("AttackStyle", nil)
		m:SetAttribute("State", "idle")
		m.Name = "Reliquary_" .. unitType
		for _, p in ipairs(parts) do
			p.LocalTransparencyModifier = 1
		end
		-- (stand it by its lowest point, not its RootHeight: a hovering unit's hover is tripled too and it would float
		-- far above the pedestal)
		m:PivotTo(CFrame.new(0, 1000, 0))
		local bbCF, bbSize = m:GetBoundingBox()
		local rootHeight = root.Position.Y - (bbCF.Position.Y - bbSize.Y / 2) + 0.3
		m.Parent = Workspace
		CollectionService:AddTag(m, PROP_TAG)
		return { model = m, root = root, parts = parts, rootHeight = rootHeight, shownAt = os.clock() }
	end

	local function nextUnit()
		if current then
			CollectionService:RemoveTag(current.model, PROP_TAG)
			current.model:Destroy()
			current = nil
		end
		for _ = 1, #SHOWN do
			index = index % #SHOWN + 1
			local unitType = SHOWN[index]
			current = spawnUnit(unitType)
			if current then
				writePlate(unitType)
				souls:Emit(40)
				return
			end
		end
	end

	RunService.Heartbeat:Connect(function(dt)
		if not current then
			nextUnit()
			if not current then
				return
			end
		end
		local age = os.clock() - current.shownAt
		-- rises out of the pedestal at the start, sinks back into it at the end, fading in and out
		local rise = math.clamp(age / FADE_TIME, 0, 1)
		local sink = math.clamp((age - (SHOW_TIME - FADE_TIME)) / FADE_TIME, 0, 1)
		local shown = rise * (1 - sink)
		local e = shown * shown * (3 - 2 * shown)
		angle += TURN_SPEED * dt
		local base = anchor.CFrame * CFrame.new(0, anchor.Size.Y / 2, 0)
		current.root.CFrame = base * CFrame.new(0, current.rootHeight - (1 - e) * 3, 0) * CFrame.Angles(0, angle, 0)
		for _, p in ipairs(current.parts) do
			p.LocalTransparencyModifier = 1 - e
		end
		if sink > 0 and souls.Rate == 0 then
			souls.Rate = 30
		elseif sink == 0 and age > FADE_TIME then
			souls.Rate = 0
		end
		if age >= SHOW_TIME then
			souls.Rate = 0
			nextUnit()
		end
	end)
end)

return {}
