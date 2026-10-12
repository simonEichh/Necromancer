-- Unit spawning, placement on grave slots, recall, and the per-frame unit AI.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local Remotes = require(script.Parent.Remotes)
local Walls = require(script.Parent.Walls)
local Collision = require(script.Parent.Collision)
local PlotFrame = require(script.Parent.PlotFrame)
local PlayerData = require(script.Parent.PlayerData)
local PlotRegistry = require(script.Parent.PlotRegistry)
local SharedUnits = require(ReplicatedStorage.Shared.Units)
local Rarities = require(ReplicatedStorage.Shared.Rarities)

local UNITS = SharedUnits.Stats
local UNIT_RARITY = SharedUnits.Rarity
local UNIT_EMOJIS = SharedUnits.Emoji
local getBaseOneIn = SharedUnits.getBaseOneIn
local RARITY_COLOR = Rarities.Color
local playerPlots = PlotRegistry.playerPlots
local getPlot = PlotRegistry.getPlot
local updateWallGui = Walls.updateWallGui
local breakWall = Walls.breakWall

local modelsFolder = ServerStorage:FindFirstChild("Models")

local recallUnitFromSlot
recallUnitFromSlot = function(slotIndex, player, plotState)
	local slot = plotState.graveSlots[slotIndex]
	if not slot or not slot.occupied then return end
	-- Refuse (and keep the unit on the grave) when there is nowhere to put it
	if not PlayerData.hasFreeSlot(player) then
		Remotes.Notice:FireClient(player, "⚠️ Inventory full — can't recall " .. slot.unitType)
		return
	end
	if slot.unitEntry then
		for i = #plotState.activeUnits, 1, -1 do
			if plotState.activeUnits[i] == slot.unitEntry then
				if plotState.activeUnits[i].block and plotState.activeUnits[i].block.Parent then
					plotState.activeUnits[i].block:Destroy()
				end
				table.remove(plotState.activeUnits, i)
				break
			end
		end
	end
	PlayerData.addUnit(player, slot.unitType, getBaseOneIn(slot.unitType))
	slot.occupied = false
	slot.unitType = nil
	slot.unitEntry = nil
	slot.label.Text = "Empty"
	slot.rarityLabel.Text = ""
	slot.dpsLabel.Text = ""
	slot.prompt.ActionText = "Place Unit"
	slot.prompt.ObjectText = "Grave " .. slotIndex
	print("↩️ " .. player.Name .. " recalled unit from grave " .. slotIndex)
end

local nextUnitId = 0 -- ever-growing id of spawned units (orders the units inside a formation row)

local function spawnUnit(unitType, customPos, plotState)
	local def = UNITS[unitType]
	if not def then return end
	nextUnitId += 1

	-- "lateral" = which lane line across the plot the unit walks along; units face down the lane
	local forward = PlotFrame.forwardFlat(plotState)
	local lateral = customPos and select(1, PlotFrame.toLocal(plotState, customPos)) or math.random(-8, 8)
	local forwardClearance = def.size.X / 2 + 2
	local spawnPos = customPos
		and (customPos + forward * forwardClearance + Vector3.new(0, 2, 0))
		or  (PlotFrame.toWorld(plotState, lateral, plotState.wallFwd - 80) + Vector3.new(0, 5.7, 0))

	local block = Instance.new("Part")
	block.Name = unitType
	block.Size = def.size
	block.CFrame = CFrame.lookAt(spawnPos, spawnPos + forward)
	block.CanCollide = true
	block.CollisionGroup = Collision.UNITS
	block.CastShadow = true

	local walkTrack, attackTrack
	local rigModel -- set for procedurally animated rigs (see client UnitAnimator)
	local labelBase = def.size.Y / 2 + 1.3 -- height of the info label above the block centre
	local unitModelTemplate = modelsFolder and modelsFolder:FindFirstChild(unitType)
	if unitModelTemplate and unitModelTemplate:IsA("Model") then
		block.Transparency = 1
		block.Parent = workspace
		local modelClone = unitModelTemplate:Clone()
		local walkAnimId
		local runAnimId
		local attackAnimId
		local toolslashAnimId
		for _, anim in ipairs(modelClone:GetDescendants()) do
			if anim:IsA("Animation") then
				local n = string.lower(anim.Name)
				if n:find("walk") and not walkAnimId then
					walkAnimId = anim.AnimationId
				elseif n:find("run") and not runAnimId then
					runAnimId = anim.AnimationId
				elseif n:find("attack") and not attackAnimId then
					attackAnimId = anim.AnimationId
				elseif n:find("toolslash") and not toolslashAnimId then
					toolslashAnimId = anim.AnimationId
				end
			end
		end
		if not walkAnimId then walkAnimId = runAnimId end
		if not attackAnimId then attackAnimId = toolslashAnimId end
		for _, s in ipairs(modelClone:GetDescendants()) do
			if s:IsA("Script") or s:IsA("LocalScript") or s:IsA("ModuleScript") then
				s:Destroy()
			end
		end
		-- Creator Store rigs come with a Humanoid. Its floor/state physics fights the BodyVelocity-driven block
		-- (units hover at HipHeight and get stuck), so swap it for an AnimationController, which keeps animations.
		local animHost
		local oldHumanoid = modelClone:FindFirstChildWhichIsA("Humanoid", true)
		if oldHumanoid then
			animHost = Instance.new("AnimationController")
			animHost.Parent = oldHumanoid.Parent
			oldHumanoid:Destroy()
		end
		local procedural = modelClone:GetAttribute("Rig") == "Procedural"
		if procedural and modelClone.PrimaryPart then
			-- Scale the rig to the unit's size, then stand it on the floor under the invisible block
			local scale = (def.size.X / 2) * 0.9
			modelClone:ScaleTo(scale)
			local rootHeight = modelClone:GetAttribute("RootHeight") * scale
			labelBase = modelClone:GetAttribute("Height") * scale - def.size.Y / 2 + 1.2
			modelClone:PivotTo(block.CFrame * CFrame.new(0, rootHeight - def.size.Y / 2, 0))
			modelClone:SetAttribute("State", "walk")
			modelClone:SetAttribute("AttackCount", 0)
			modelClone:SetAttribute("AttackCD", def.attackCD)
			modelClone:SetAttribute("Speed", def.speed)
			rigModel = modelClone
		else
			if modelClone.PrimaryPart then
				modelClone:SetPrimaryPartCFrame(block.CFrame)
			else
				modelClone:MoveTo(spawnPos)
			end
			-- put the model's feet on the floor (the bottom of the block) now that no Humanoid lifts it
			local boxCFrame, boxSize = modelClone:GetBoundingBox()
			local blockBottom = block.Position.Y - def.size.Y / 2
			local shift = blockBottom - (boxCFrame.Position.Y - boxSize.Y / 2)
			modelClone:PivotTo(modelClone:GetPivot() + Vector3.new(0, shift, 0))
			labelBase = (boxCFrame.Position.Y + boxSize.Y / 2 + shift) - block.Position.Y + 1.2
		end
		-- Only weld the root part; limbs stay connected via Motor6D so animations work
		local root = modelClone.PrimaryPart or modelClone:FindFirstChild("HumanoidRootPart", true)
		for _, p in ipairs(modelClone:GetDescendants()) do
			if p:IsA("BasePart") then
				p.Anchored = false
				p.CanCollide = false
			end
		end
		if root then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = block
			weld.Part1 = root
			weld.Parent = block
		end
		modelClone.Parent = block
		if rigModel then
			CollectionService:AddTag(rigModel, "ProceduralUnit")
		end

		-- Load and play animations server-side so they replicate to clients
		if animHost then
			local animator = animHost:FindFirstChildOfClass("Animator") or Instance.new("Animator", animHost)
			if walkAnimId then
				local animObj = Instance.new("Animation")
				animObj.AnimationId = walkAnimId
				walkTrack = animator:LoadAnimation(animObj)
				walkTrack.Looped = true
				walkTrack:Play()
			end
			if attackAnimId then
				local animObj = Instance.new("Animation")
				animObj.AnimationId = attackAnimId
				attackTrack = animator:LoadAnimation(animObj)
				attackTrack.Looped = false
			end
		end
	else
		block.BrickColor = def.color
		block.Material = Enum.Material.SmoothPlastic
		if def.transparent then
			block.Transparency = 0.35
		end
		block.Parent = workspace
	end

	-- BodyVelocity steers the block on X/Z
	-- MaxForce Y = 0 so gravity still pulls it down onto the floor
	local bv = Instance.new("BodyVelocity")
	bv.Velocity = Vector3.new(0, 0, 0)
	bv.MaxForce = Vector3.new(1e5, 0, 1e5)
	bv.P = 1e4
	bv.Parent = block

	-- BodyGyro keeps it upright and facing the wall
	local bg = Instance.new("BodyGyro")
	bg.MaxTorque = Vector3.new(1e5, 1e5, 1e5) -- all axes: the block must never tip over (the CFrame below is always upright)
	bg.P = 1e4
	bg.D = 400
	bg.CFrame = CFrame.lookAt(spawnPos, spawnPos + forward)
	bg.Parent = block

	-- Unit info label (emoji + name / rarity / DPS)

	local unitRarity = UNIT_RARITY[unitType] or "Common"
	local unitDps = math.floor(def.damage / def.attackCD)
	-- Compact two-line tag, sized in studs (so it shrinks with distance), only visible up close and
	-- never drawn through walls. The name is tinted by rarity. The offset is set once (no per-frame bobbing).
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.new(6, 0, 1.9, 0)
	gui.StudsOffset = Vector3.new(0, labelBase, 0)
	gui.AlwaysOnTop = false
	gui.MaxDistance = 45
	gui.LightInfluence = 0
	gui.Parent = block
	local nameLbl = Instance.new("TextLabel", gui)
	nameLbl.Size = UDim2.new(1, 0, 0.55, 0)
	nameLbl.BackgroundTransparency = 1
	nameLbl.Text = (UNIT_EMOJIS[unitType] or "💀") .. " " .. unitType
	nameLbl.TextColor3 = RARITY_COLOR[unitRarity] or Color3.fromRGB(235, 235, 235)
	nameLbl.TextStrokeTransparency = 0.35
	nameLbl.TextScaled = true
	nameLbl.Font = Enum.Font.GothamBold
	local dpsLbl = Instance.new("TextLabel", gui)
	dpsLbl.Size = UDim2.new(1, 0, 0.42, 0)
	dpsLbl.Position = UDim2.new(0, 0, 0.58, 0)
	dpsLbl.BackgroundTransparency = 1
	dpsLbl.Text = unitDps .. " DPS"
	dpsLbl.TextColor3 = Color3.fromRGB(110, 255, 140)
	dpsLbl.TextStrokeTransparency = 0.35
	dpsLbl.TextScaled = true
	dpsLbl.Font = Enum.Font.GothamBold

	table.insert(plotState.activeUnits, {
		block = block, bv = bv, bg = bg, def = def,
		lastAttack = 0, lateral = lateral,
		id = nextUnitId, -- stable order inside a formation row (see layoutFormation)
		walkTrack = walkTrack, attackTrack = attackTrack,
		model = rigModel, labelBase = labelBase,
	})
end

-- Spawns a unit on a grave slot and updates the slot's labels/prompt.
-- Returns false if the slot is missing or already occupied.
local function placeInSlot(plotState, slotIndex, unitType)
	local slot = plotState.graveSlots[slotIndex]
	local graveSpot = plotState.plotModel:FindFirstChild("GraveSpot" .. tostring(slotIndex))
	if not slot or slot.occupied or not graveSpot or not UNITS[unitType] then
		return false
	end
	spawnUnit(unitType, graveSpot.Position + Vector3.new(0, 2, 0), plotState)
	slot.occupied = true
	slot.unitType = unitType
	slot.unitEntry = plotState.activeUnits[#plotState.activeUnits]
	local dps = math.floor(UNITS[unitType].damage / UNITS[unitType].attackCD)
	local rarity = UNIT_RARITY[unitType] or "Common"
	slot.label.Text = "⚔️ " .. unitType
	slot.rarityLabel.Text = rarity
	slot.rarityLabel.TextColor3 = RARITY_COLOR[rarity] or Color3.fromRGB(200, 200, 200)
	slot.dpsLabel.Text = dps .. " DPS"
	slot.prompt.ActionText = "Recall"
	slot.prompt.ObjectText = "Grave " .. slotIndex .. " (" .. unitType .. ")"
	return true
end

-- Client asks to place the unit from inventory slot `invIndex` on grave slot `slotIndex`.
Remotes.PlaceAtGrave.OnServerEvent:Connect(function(player, invIndex, slotIndex)
	local plotState = getPlot(player)
	if not plotState or type(slotIndex) ~= "number" then return end
	local slot = plotState.graveSlots[slotIndex]
	local unit = PlayerData.getUnit(player, invIndex)
	if not slot or slot.occupied or not unit then return end
	if not placeInSlot(plotState, slotIndex, unit.unitType) then return end
	PlayerData.takeUnit(player, invIndex)
	print("🪦 " .. player.Name .. " placed " .. unit.unitType .. " at grave " .. slotIndex)
end)

local function clearSlot(i, plotState)
	local slot = plotState.graveSlots[i]
	if not slot or not slot.occupied then return nil end
	local unitType = slot.unitType
	if slot.unitEntry then
		for j = #plotState.activeUnits, 1, -1 do
			if plotState.activeUnits[j] == slot.unitEntry then
				if plotState.activeUnits[j].block and plotState.activeUnits[j].block.Parent then
					plotState.activeUnits[j].block:Destroy()
				end
				table.remove(plotState.activeUnits, j)
				break
			end
		end
	end
	slot.occupied = false
	slot.unitType = nil
	slot.unitEntry = nil
	slot.label.Text = "Empty"
	slot.rarityLabel.Text = ""
	slot.dpsLabel.Text = ""
	slot.prompt.ActionText = "Place Unit"
	slot.prompt.ObjectText = "Grave " .. i
	return { unitType = unitType, oneIn = getBaseOneIn(unitType) }
end

-- Re-deploys the strongest units (from the graves and the server-side inventory) onto the graves.
Remotes.PlaceBest.OnServerEvent:Connect(function(player)
	local plotState = getPlot(player)
	if not plotState or not PlayerData.get(player) then return end
	local pool = {}
	for i = 1, #plotState.graveSlots do
		local item = clearSlot(i, plotState)
		if item then table.insert(pool, item) end
	end
	for _, item in ipairs(PlayerData.inventoryList(player)) do
		table.insert(pool, { unitType = item.unitType, oneIn = item.oneIn })
	end
	table.sort(pool, function(a, b)
		local dA = UNITS[a.unitType] and (UNITS[a.unitType].damage / UNITS[a.unitType].attackCD) or 0
		local dB = UNITS[b.unitType] and (UNITS[b.unitType].damage / UNITS[b.unitType].attackCD) or 0
		return dA > dB
	end)
	local slotCount = #plotState.graveSlots
	local remaining = {}
	local deployed = 0
	for i, item in ipairs(pool) do
		if i <= slotCount and placeInSlot(plotState, i, item.unitType) then
			deployed += 1
		else
			table.insert(remaining, item)
		end
	end
	PlayerData.setInventoryList(player, remaining)
	print("🏆 " .. player.Name .. " used Place Best — deployed " .. deployed .. " units")
end)

-- Tells the clients a unit hit the wall at `position` (they draw the hit flash, see client HitEffects). Nothing is
-- spawned on the server; `forward` is the lane direction, i.e. which way the wall's front face points away from.
local function sendWallHit(plotState, position, damage, isGhost)
	Remotes.WallHit:FireAllClients(position, PlotFrame.forwardFlat(plotState), damage, isGhost)
end

local function shootArrow(fromPos, targetPos, damage, plotState)
	local arrowStart = fromPos + Vector3.new(0, 0.5, 0)
	local arrow = Instance.new("Part")
	arrow.Size = Vector3.new(0.2, 0.2, 1.5)
	arrow.BrickColor = BrickColor.new("Bright green")
	arrow.Material = Enum.Material.Neon
	arrow.CastShadow = false
	arrow.CanCollide = false
	arrow.Anchored = true
	arrow.CFrame = CFrame.lookAt(arrowStart, targetPos)
	arrow.Parent = workspace
	local travelTime = (targetPos - arrowStart).Magnitude / 60
	TweenService:Create(
		arrow,
		TweenInfo.new(travelTime, Enum.EasingStyle.Linear),
		{ CFrame = CFrame.lookAt(targetPos, targetPos + (targetPos - arrowStart).Unit) }
	):Play()
	task.delay(travelTime, function()
		if arrow and arrow.Parent then arrow:Destroy() end
		plotState.wallHP = math.max(0, plotState.wallHP - damage)
		updateWallGui(plotState)
		sendWallHit(plotState, targetPos, damage, true)
		if plotState.wallHP <= 0 then breakWall(plotState) end
	end)
end

-- Tells the client how to animate a procedural rig (no-op for other models).
local function setState(u, state)
	if u.model and u.state ~= state then
		u.state = state
		u.model:SetAttribute("State", state)
	end
end

-- ── Formation ─────────────────────────────────────────────────
-- Units do not collide with each other, so without a plan they would all pile up on the same few spots. Each plot's
-- army forms rows facing the wall: a unit's row follows from its attack range (melee at the wall, mages about 20 studs
-- back, long-range artillery further), and inside a row the units spread across the lane, centre first and then
-- alternating right/left, so a newly arrived unit never makes the ones already standing move.
-- Every unit gets slotLat (across the lane) and slotStand (distance in front of the wall's target line).
local FORMATION_BAND = 5         -- studs between two formation rows (a unit's stand distance is its range rounded down to this)
local FORMATION_MIN_STAND = 1.5  -- nearest a unit stands to the wall's target line
local FORMATION_HALF_WIDTH = 16  -- units stay this close to the lane's centre line (the lane is 40 wide)
local ARRIVE_RADIUS = 1.2        -- how close a unit must get to its slot before it stops and attacks
local STAY_RADIUS = 3            -- a unit that has arrived keeps attacking unless it is pushed further than this

-- Where a unit stands: melee and short-range units (range up to FORMATION_SHORT_RANGE) just inside their range; beyond
-- that every extra stud of range moves the unit FORMATION_LONG_SCALE studs further back, so mages and archers fight from
-- far away and their projectiles have a long way to travel (range 15 -> 15, 20 -> 30, 25 -> 40, 30 -> 55 studs from the wall).
local FORMATION_SHORT_RANGE = 12
local FORMATION_LONG_SCALE = 2.5

local function standDistance(def)
	local range = def.attackRange - 1.5
	if def.attackRange > FORMATION_SHORT_RANGE then
		range = (FORMATION_SHORT_RANGE - 1.5) + (def.attackRange - FORMATION_SHORT_RANGE) * FORMATION_LONG_SCALE
	end
	return math.max(FORMATION_MIN_STAND, math.floor(range / FORMATION_BAND) * FORMATION_BAND)
end

local function layoutFormation(plotState)
	local rows, stands = {}, {}
	for _, u in ipairs(plotState.activeUnits) do
		local stand = standDistance(u.def)
		if not rows[stand] then
			rows[stand] = {}
			table.insert(stands, stand)
		end
		table.insert(rows[stand], u)
	end
	table.sort(stands)

	for rowIndex, stand in ipairs(stands) do
		local row = rows[stand]
		table.sort(row, function(a, b) return a.id < b.id end)
		-- wide units need more room; squeeze the row if it would not fit across the lane
		local spacing = 0
		for _, u in ipairs(row) do
			spacing = math.max(spacing, u.def.size.X * 1.7)
		end
		local reach = math.ceil((#row - 1) / 2)
		if reach > 0 and reach * spacing > FORMATION_HALF_WIDTH then
			spacing = FORMATION_HALF_WIDTH / reach
		end
		local shift = (rowIndex % 2 == 0) and spacing / 2 or 0 -- stagger every other row, like a proper battle line
		for i, u in ipairs(row) do
			local k = i - 1 -- slot 0 is the centre, then +1, -1, +2, -2 ...
			local side = (k % 2 == 1) and 1 or -1
			local lat = (k == 0) and 0 or side * math.ceil(k / 2) * spacing
			u.slotLat = math.clamp(lat + shift, -FORMATION_HALF_WIDTH, FORMATION_HALF_WIDTH)
			u.slotStand = stand
		end
	end
end

local function formationSignature(units)
	local sig = #units * 1000003
	for _, u in ipairs(units) do
		sig += u.id
	end
	return sig
end

-- ── Spell barrages (AttackStyle = "StaffCast") ────────────────────
-- A staff caster does not attack once per cooldown. While it stands in its slot it fires a continuous BARRAGE: shots at a
-- fixed rate, each one a visible orb that flies to the wall. Nothing is sent per shot. When a barrage starts or stops the
-- server sets a few attributes on the unit model (Barrage, BarrageStart, BarrageRate, ShotTime, AimPos) and every client works out
-- the same shot schedule from them with the synced server clock (workspace:GetServerTimeNow(), see client SpellEffects):
-- shot k (k = 0, 1, 2 ...) is fired at BarrageStart + k / BarrageRate and lands ShotTime seconds later.
-- The server settles the damage on the same schedule: the damage of all shots that landed since the last tick is applied
-- to the wall in batches (BATCH_INTERVAL); the wall's HP bar shows the hits and the orbs draw their own impacts, so
-- barrage shots send no WallHit. The damage per
-- second stays the unit's normal DPS (damage / attackCD), so this changes how it looks and feels, not the balance.
local DEFAULT_SHOTS_PER_SECOND = 6 -- a unit def can override it with shotsPerSecond
local SPELL_ORB_SPEED = 30         -- studs per second: sets the flight time of a shot
local BARRAGE_LEAD = 0.4           -- the first shot is fired this long after the barrage starts, while the staff is raised
local BATCH_INTERVAL = 0.1         -- wall damage of landed shots is applied in batches this often

-- how many shots of the barrage have been fired by (server) time t
local function shotsFiredBy(b, t)
	if t < b.start then
		return 0
	end
	return math.floor((t - b.start) * b.rate) + 1
end

local function startBarrage(u, plotState, lat)
	if not u.model then return end
	-- shots of an earlier barrage that are still in the air land right away, so no damage is lost
	local old = u.barrage
	if old and old.endTime then
		local remaining = math.max(0, shotsFiredBy(old, old.endTime) - old.landed)
		plotState.barrageBuffer = (plotState.barrageBuffer or 0) + remaining * old.shotDamage
	end

	local rate = u.def.shotsPerSecond or DEFAULT_SHOTS_PER_SECOND
	local face = PlotFrame.toWorld(plotState, lat, plotState.wallFaceFwd)
	local flatUnit = Vector3.new(u.block.Position.X, 0, u.block.Position.Z)
	local flatFace = Vector3.new(face.X, 0, face.Z)
	-- the orbs start a few studs in front of the caster
	local flight = math.max(0.5, math.max(1, (flatUnit - flatFace).Magnitude - 4) / SPELL_ORB_SPEED)
	local start = workspace:GetServerTimeNow() + BARRAGE_LEAD
	u.barrage = {
		start = start,
		rate = rate,
		flight = flight,
		shotDamage = (u.def.damage / u.def.attackCD) / rate,
		landed = 0, -- shots whose damage has been applied
		endTime = nil, -- set when the barrage stops (shots already fired still land)
	}
	u.model:SetAttribute("AimPos", face + Vector3.new(0, 6, 0)) -- where the orbs fly to (wall face in this lane, mid-height)
	u.model:SetAttribute("ShotTime", flight)
	u.model:SetAttribute("BarrageRate", rate)
	u.model:SetAttribute("BarrageStart", start)
	u.model:SetAttribute("Barrage", true) -- last, so a client that sees it also sees the rest
end

local function stopBarrage(u)
	local b = u.barrage
	if not b or b.endTime then return end
	b.endTime = workspace:GetServerTimeNow()
	if u.model then
		u.model:SetAttribute("Barrage", false)
	end
end

-- Applies the damage of every shot that has landed (called once per plot per frame).
local function settleBarrages(plotState, now)
	local t = workspace:GetServerTimeNow()
	local damage = 0
	for _, u in ipairs(plotState.activeUnits) do
		local b = u.barrage
		if b then
			local firedBy = b.endTime and math.min(t - b.flight, b.endTime) or (t - b.flight)
			local landed = shotsFiredBy(b, firedBy)
			if landed > b.landed then
				damage += (landed - b.landed) * b.shotDamage
				b.landed = landed
			end
			if b.endTime and b.landed >= shotsFiredBy(b, b.endTime) then
				u.barrage = nil -- everything fired has landed
			end
		end
	end
	if damage > 0 then
		plotState.barrageBuffer = (plotState.barrageBuffer or 0) + damage
	end

	-- apply the wall damage in small batches
	if (plotState.barrageBuffer or 0) > 0 and now - (plotState.lastBatchAt or 0) >= BATCH_INTERVAL then
		local amount = plotState.barrageBuffer
		plotState.barrageBuffer = 0
		plotState.lastBatchAt = now
		plotState.wallHP = math.max(0, plotState.wallHP - amount)
		updateWallGui(plotState)
		if plotState.wallHP <= 0 then breakWall(plotState) end
	end
end

-- Advances every plot's units one frame: walk to the formation slot facing the wall, then attack it.
local function update(now, dt)
	-- Unit AI — iterate over every player's plot
	for _, plotState in pairs(playerPlots) do
		if not plotState.wall or not plotState.wall.Parent then continue end

		-- (re)plan the formation whenever units were added or removed
		local signature = formationSignature(plotState.activeUnits)
		if signature ~= plotState.formationSignature then
			plotState.formationSignature = signature
			layoutFormation(plotState)
		end

		for i = #plotState.activeUnits, 1, -1 do
			local u = plotState.activeUnits[i]
			if not u.block.Parent then
				table.remove(plotState.activeUnits, i)
				continue
			end
			if not u.phase then u.phase = math.random() * math.pi * 2 end

			local pos = u.block.Position
			local flatPos    = Vector3.new(pos.X, 0, pos.Z)
			-- the unit's slot in the formation (falls back to the lane it was placed in until the first layout)
			local lat = u.slotLat or u.lateral
			local target     = PlotFrame.toWorld(plotState, lat, plotState.wallTargetFwd - (u.slotStand or FORMATION_MIN_STAND))
			local flatTarget = Vector3.new(target.X, 0, target.Z)
			local dist = (flatPos - flatTarget).Magnitude
			local forward = PlotFrame.forwardFlat(plotState)

			-- arrived = stand in the slot and attack (units that are already in place stay put unless pushed away;
			-- the arrival radius grows with speed so a fast unit cannot overshoot its slot forever)
			u.arrived = dist <= (u.arrived and STAY_RADIUS or math.max(ARRIVE_RADIUS, u.def.speed * dt * 1.5))

			if u.arrived then
				u.bv.Velocity = Vector3.new(0, 0, 0)
				u.bg.CFrame = CFrame.lookAt(pos, pos + forward)

				if u.block.Name == "Goblin" then
					local poison = UNITS.Goblin.poison or 1
					plotState.wallHP = math.max(0, plotState.wallHP - poison * dt)
					updateWallGui(plotState)
					if plotState.wallHP <= 0 then breakWall(plotState) end
				end

				if u.walkTrack and u.walkTrack.IsPlaying then u.walkTrack:Stop() end
				setState(u, "idle")
				if u.model and u.model:GetAttribute("AttackStyle") == "StaffCast" then
					-- staff casters fire a continuous barrage instead of one attack per cooldown (see startBarrage)
					if not u.barrage or u.barrage.endTime then
						startBarrage(u, plotState, lat)
					end
				elseif now - u.lastAttack >= u.def.attackCD then
					u.lastAttack = now
					if u.model then
						u.model:SetAttribute("AttackCount", (u.model:GetAttribute("AttackCount") or 0) + 1)
					end
					if u.attackTrack then u.attackTrack:Play() end
					local fromPos = u.block.Position
					local face = PlotFrame.toWorld(plotState, lat, plotState.wallFaceFwd)
					local targetPos = Vector3.new(face.X, fromPos.Y + 0.5, face.Z)
					if u.block.Name == "Goblin" then
						shootArrow(fromPos, targetPos, u.def.damage, plotState)
					else
						-- somewhere on the wall face in front of this unit
						local impactPos = PlotFrame.toWorld(plotState, lat + math.random(-3, 3), plotState.wallFaceFwd)
							+ Vector3.new(0, 3.7 + math.random(0, 7), 0)
						plotState.wallHP = math.max(0, plotState.wallHP - u.def.damage)
						updateWallGui(plotState)
						sendWallHit(plotState, impactPos, u.def.damage, u.def.transparent)
						if plotState.wallHP <= 0 then breakWall(plotState) end
					end
				end
			else
				if u.barrage and not u.barrage.endTime then stopBarrage(u) end
				if u.walkTrack and not u.walkTrack.IsPlaying then u.walkTrack:Play() end
				setState(u, "walk")
				local dir = (flatTarget - flatPos).Unit
				u.bv.Velocity = Vector3.new(dir.X * u.def.speed, 0, dir.Z * u.def.speed)
				u.bg.CFrame = CFrame.new(pos, pos + Vector3.new(dir.X, 0, dir.Z))
			end
		end

		settleBarrages(plotState, now)
	end
end

-- Debug: /give UnitType spawns a unit directly at your plot
Players.PlayerAdded:Connect(function(player)
	if not game:GetService("RunService"):IsStudio() then return end
	player.Chatted:Connect(function(msg)
		if msg:sub(1,6):lower() ~= "/give " then return end
		local unitType = msg:sub(7)
		if not UNITS[unitType] then return end
		local plotState = getPlot(player)
		if plotState then spawnUnit(unitType, nil, plotState) end
	end)
end)

return {
	recallUnitFromSlot = recallUnitFromSlot,
	placeInSlot = placeInSlot,
	spawnUnit = spawnUnit,
	standDistance = standDistance, -- (unit def) -> distance in front of the wall where the unit stands
	update = update,
}
