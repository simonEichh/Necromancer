-- Unit spawning, placement on grave slots, recall, and the per-frame unit AI.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local Remotes = require(script.Parent.Remotes)
local Walls = require(script.Parent.Walls)
local Collision = require(script.Parent.Collision)
local PlotFrame = require(script.Parent.PlotFrame)
local PlayerData = require(script.Parent.PlayerData)
local PlotRegistry = require(script.Parent.PlotRegistry)
local Quests = require(script.Parent.Quests)
local Drops = require(script.Parent.Drops)
local SharedUnits = require(ReplicatedStorage.Shared.Units)
local Economy = require(ReplicatedStorage.Shared.Economy)
local Rarities = require(ReplicatedStorage.Shared.Rarities)
local GraveRune = require(script.Parent.GraveRune)

local UNITS = SharedUnits.Stats
local UNIT_RARITY = SharedUnits.Rarity
local getBaseOneIn = SharedUnits.getBaseOneIn
local RARITY_COLOR = Rarities.Color
local playerPlots = PlotRegistry.playerPlots
local getPlot = PlotRegistry.getPlot
local updateWallGui = Walls.updateWallGui
local breakWall = Walls.breakWall

local modelsFolder = ServerStorage:FindFirstChild("Models")

-- A slot by its index: graves 1..10 (plotState.graveSlots), commander thrones 101, 102 (plotState.commanderSlots, built
-- by Plots: only Signatures and Sovereigns may stand on them, and only there; Design.md "the commander slot")
local COMMANDER_BASE = 100
local function getSlot(plotState, slotIndex)
	if type(slotIndex) ~= "number" then return nil end
	if slotIndex > COMMANDER_BASE then
		local slot = plotState.commanderSlots and plotState.commanderSlots[slotIndex - COMMANDER_BASE]
		return slot and not slot.sealed and slot or nil
	end
	return plotState.graveSlots[slotIndex]
end
local function isCommanderUnit(unitType)
	return SharedUnits.isSignature(unitType) or SharedUnits.isSovereign(unitType)
end

local recallUnitFromSlot
recallUnitFromSlot = function(slotIndex, player, plotState)
	local slot = getSlot(plotState, slotIndex)
	if not slot or not slot.occupied then return end
	-- Refuse (and keep the unit on the grave) when there is nowhere to put it
	if not PlayerData.hasFreeSlot(player) then
		Remotes.Notice:FireClient(player, "Inventory full — can't recall ".. slot.unitType)
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
	PlayerData.addUnit(player, slot.unitType, getBaseOneIn(slot.unitType), slot.level, slot.fails, slot.locked)
	slot.occupied = false
	slot.unitType = nil
	slot.level, slot.fails, slot.locked = nil, nil, nil
	slot.unitEntry = nil
	slot.label.Text = ""
	GraveRune.set(slot, nil) -- (the rune goes dark)
	slot.rarityLabel.Text = ""
	slot.dpsLabel.Text = ""
	slot.prompt.ActionText = "Place Unit"
	slot.prompt.ObjectText = "Grave " .. slotIndex
	print("↩️ " .. player.Name .. " recalled unit from grave " .. slotIndex)
end

local nextUnitId = 0 -- ever-growing id of spawned units (orders the units inside a formation row)
local RISE_TIME = 3.5 -- seconds a static unit (a tower) takes to rise out of the ground when it is placed
-- Units with infiniteRange (the Sigilwright) shoot the wall from any distance, so they do not march after the front:
-- they stand at a fixed post this far down the lane (the plot's Base ends at 24, the first wall is at 105) in a row of their own.
local INFINITE_RANGE_POST_FWD = 62
local INFINITE_STAND = 1000
local standDistance -- (unit def) -> distance in front of the wall where the unit stands; defined with the formation code below

-- Ascensions multiply the damage of every unit (Economy.damageMultiplier). Each spawned unit gets its own copy of its
-- stats so the multiplier can change when the owner ascends (see setDamageMultiplier).
local function ownerDamageMultiplier(plotState)
	local owner = Players:GetPlayerByUserId(tonumber(plotState.ownerId) or 0)
	local profile = owner and PlayerData.get(owner)
	if not profile then
		return 1
	end
	-- ascensions x the realm upgrade Army Might; Swift March is cached here too (read every frame by the movement)
	plotState.marchMult = Economy.realmUpgradeEffect("march", profile.realmUpgrades.march)
	return Economy.damageMultiplier(profile.rebirthCount) * Economy.realmUpgradeEffect("might", profile.realmUpgrades.might)
		* (plotState.auraMult or 1)
end

-- Signature / Sovereign auras (unit def `aura`, e.g. Malak: { damage = 0.10 }): the strongest aura of each kind among
-- the plot's units counts (they do not stack). Only "damage" exists so far.
local function auraMultiplier(plotState)
	local best = 0
	for _, u in ipairs(plotState.activeUnits) do
		local aura = u.def and u.def.aura
		if aura and aura.damage and u.block and u.block.Parent then
			best = math.max(best, aura.damage)
		end
	end
	return 1 + best
end

-- the family bonuses that change a unit's damage (SharedUnits.Families; plotState.famBonus is refreshed every second in
-- update): Flesh for Flesh units, Beasts for Beasts while their burst runs after a wall stood up, Bones for the whole army
-- against the gate
local function familyDamageMultiplier(plotState, u)
	local fam = plotState.famBonus
	if not fam then return 1 end
	local own = SharedUnits.FamilyOf[u.unitType]
	local m = 1
	if own == "Flesh" then m *= 1 + fam.Flesh end
	if own == "Beasts" and plotState.beastBurst then m *= 1 + fam.Beasts end
	if plotState.atGate then m *= 1 + fam.Bones end
	return m
end

local function setDamageMultiplier(plotState)
	local mult = ownerDamageMultiplier(plotState)
	for _, u in ipairs(plotState.activeUnits) do
		if u.baseDamage then
			u.def.damage = u.baseDamage * mult * Economy.levelMultiplier(u.level) * familyDamageMultiplier(plotState, u)
			if u.dpsLbl then
				u.dpsLbl.Text = math.floor(u.def.damage / u.def.attackCD) .. " DPS"
			end
		end
	end
end

local function spawnUnit(unitType, customPos, plotState, level)
	local baseDef = UNITS[unitType]
	if not baseDef then return end
	local def = table.clone(baseDef)
	def.damage = baseDef.damage * ownerDamageMultiplier(plotState) * Economy.levelMultiplier(level)
	nextUnitId += 1

	-- "lateral" = which lane line across the plot the unit walks along; units face down the lane
	local forward = PlotFrame.forwardFlat(plotState)
	local lateral = customPos and select(1, PlotFrame.toLocal(plotState, customPos)) or math.random(-8, 8)
	local forwardClearance = def.size.X / 2 + 2
	local spawnPos = customPos
		and (customPos + forward * forwardClearance + Vector3.new(0, 2, 0))
		or  (PlotFrame.toWorld(plotState, lateral, plotState.wallFwd - 80) + Vector3.new(0, 5.7, 0))

	if def.static then
		-- static units (towers, ...) never walk: they rise straight out of the ground at their slot in the formation
		lateral = 0
		spawnPos = PlotFrame.toWorld(plotState, lateral, plotState.wallTargetFwd - standDistance(def))
			+ Vector3.new(0, def.size.Y / 2 + 1, 0)
	end

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
	-- an awakened unit (Economy.AWAKEN_LEVEL+) appears in its shadow form when it has one ("<Unit>_Shadow"); the form is
	-- picked when it spawns (a unit levelled up while standing on a grave changes when it is placed again)
	local shadowTemplate = nil
	if modelsFolder and (level or 0) >= Economy.AWAKEN_LEVEL then
		shadowTemplate = modelsFolder:FindFirstChild(unitType .. "_Shadow")
	end
	local unitModelTemplate = shadowTemplate or (modelsFolder and modelsFolder:FindFirstChild(unitType))
	if unitModelTemplate and unitModelTemplate:IsA("Model") then
		block.Transparency = 1
		block.Parent = workspace
		local modelClone = unitModelTemplate:Clone()
		modelClone.Name = unitType -- (a shadow form keeps the unit's own name; the attribute Form tells them apart)
		modelClone:SetAttribute("Form", shadowTemplate and "Shadow" or "Base")
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
			modelClone:SetAttribute("Level", level or 0) -- (auras at level milestones read this)
			modelClone:SetAttribute("OwnerId", plotState and plotState.ownerId or "") -- (client effects meant only for the owner, e.g. camera shake)
			if def.static then
				-- the client lifts the model out of the ground over RiseTime seconds (see UnitAnimator)
				modelClone:SetAttribute("RiseStart", workspace:GetServerTimeNow())
				modelClone:SetAttribute("RiseTime", RISE_TIME)
			end
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
	gui.MaxDistance = def.static and 160 or 45
	gui.LightInfluence = 0
	gui.Parent = block
	local nameLbl = Instance.new("TextLabel", gui)
	nameLbl.Size = UDim2.new(1, 0, 0.55, 0)
	nameLbl.BackgroundTransparency = 1
	nameLbl.Text = unitType -- (no emojis: the UI overhaul replaces them with real icons, see the UI roadmap)
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
		block = block, bv = bv, bg = bg, def = def, unitType = unitType, baseDamage = baseDef.damage, level = level or 0, dpsLbl = dpsLbl,
		lastAttack = 0, lateral = lateral,
		id = nextUnitId, -- stable order inside a formation row (see layoutFormation)
		walkTrack = walkTrack, attackTrack = attackTrack,
		model = rigModel, labelBase = labelBase,
		shadowForm = shadowTemplate ~= nil, -- (its hits use the shadow version of its hit effect: "<hitFx>Shadow")
	})
end

-- The name line on a grave: the unit and, once upgraded, its level
local function graveTitle(unitType, level)
	if (level or 0) > 0 then
		return unitType .. "  Lv " .. level
	end
	return unitType
end

-- Spawns a unit on a grave slot and updates the slot's labels/prompt.
-- Returns false if the slot is missing or already occupied. `locked` travels with the unit (see Inventory: ToggleLock).
local function placeInSlot(plotState, slotIndex, unitType, level, fails, locked)
	local slot = getSlot(plotState, slotIndex)
	local graveSpot = plotState.plotModel:FindFirstChild("GraveSpot" .. tostring(slotIndex))
	local spawnPos = slot and (slot.spawnPos or (graveSpot and graveSpot.Position + Vector3.new(0, 2, 0)))
	if not slot or slot.occupied or not spawnPos or not UNITS[unitType] then
		return false
	end
	-- commanders (Signatures / Sovereigns) on the thrones, everyone else on the graves
	if (slot.commander == true) ~= isCommanderUnit(unitType) then
		return false, slot.commander and "Only Signatures and Sovereigns can sit on the commander throne." or "Signatures and Sovereigns lead from the commander throne."
	end
	spawnUnit(unitType, spawnPos, plotState, level)
	slot.occupied = true
	slot.unitType = unitType
	slot.level = level or 0
	slot.fails = fails or 0
	slot.locked = locked == true or nil
	slot.unitEntry = plotState.activeUnits[#plotState.activeUnits]
	local dps = math.floor(UNITS[unitType].damage * ownerDamageMultiplier(plotState) * Economy.levelMultiplier(level) / UNITS[unitType].attackCD)
	local rarity = UNIT_RARITY[unitType] or "Common"
	slot.label.Text = graveTitle(unitType, level)
	slot.rarityLabel.Text = rarity
	slot.rarityLabel.TextColor3 = RARITY_COLOR[rarity] or Color3.fromRGB(200, 200, 200)
	GraveRune.set(slot, RARITY_COLOR[rarity] or Color3.fromRGB(200, 200, 200)) -- (the tombstone's rune lights up)
	slot.dpsLabel.Text = dps .. " DPS"
	slot.prompt.ActionText = "Recall"
	slot.prompt.ObjectText = "Grave " .. slotIndex .. " (" .. unitType .. ")"
	return true
end

-- Sets the level (and the failed-upgrade streak) of the unit standing on a grave: its damage, DPS labels and model attribute.
local function setUnitLevel(plotState, slotIndex, level, fails)
	local slot = getSlot(plotState, slotIndex)
	if not slot or not slot.occupied then return false end
	slot.level, slot.fails = level, fails or 0
	local u = slot.unitEntry
	if u then
		u.level = level
		u.def.damage = u.baseDamage * ownerDamageMultiplier(plotState) * Economy.levelMultiplier(level)
		local dps = math.floor(u.def.damage / u.def.attackCD)
		if u.dpsLbl then u.dpsLbl.Text = dps .. " DPS" end
		slot.dpsLabel.Text = dps .. " DPS"
		if u.model then u.model:SetAttribute("Level", level) end
	end
	if slot.unitType then
		slot.label.Text = graveTitle(slot.unitType, level)
	end
	return true
end

-- The units standing on the graves of a player's plot, for the data snapshot (PlayerData.snapshot): { slot, unitType, level, fails, locked }
-- every unit standing on a grave or a throne: { slot, unitType, level, fails, locked } (for the snapshot and saving)
local function placedList(plotState)
	local list = {}
	local function add(slotIndex, slot)
		if slot.occupied and slot.unitType then
			table.insert(list, { slot = slotIndex, unitType = slot.unitType, level = slot.level or 0, fails = slot.fails or 0, locked = slot.locked == true })
		end
	end
	for slotIndex, slot in pairs(plotState.graveSlots) do
		add(slotIndex, slot)
	end
	for k, slot in pairs(plotState.commanderSlots or {}) do
		add(COMMANDER_BASE + k, slot)
	end
	table.sort(list, function(a, b) return a.slot < b.slot end)
	return list
end
PlayerData.placedProvider = function(player)
	local plotState = getPlot(player)
	return plotState and placedList(plotState) or {}
end

-- Client asks to place the unit from inventory slot `invIndex` on grave slot `slotIndex`.
Remotes.PlaceAtGrave.OnServerEvent:Connect(function(player, invIndex, slotIndex)
	local plotState = getPlot(player)
	if not plotState or type(slotIndex) ~= "number" then return end
	local slot = getSlot(plotState, slotIndex)
	local unit = PlayerData.getUnit(player, invIndex)
	if not slot or slot.occupied or not unit then return end
	local ok, why = placeInSlot(plotState, slotIndex, unit.unitType, unit.level, unit.fails, unit.locked)
	if not ok then
		if why then Remotes.Notice:FireClient(player, why) end
		return
	end
	PlayerData.takeUnit(player, invIndex)
	print("🪦 " .. player.Name .. " placed " .. unit.unitType .. " at grave " .. slotIndex)
end)

local function clearSlot(i, plotState)
	local slot = getSlot(plotState, i)
	if not slot or not slot.occupied then return nil end
	local unitType, level, fails, locked = slot.unitType, slot.level, slot.fails, slot.locked
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
	slot.level, slot.fails, slot.locked = nil, nil, nil
	slot.unitEntry = nil
	slot.label.Text = ""
	GraveRune.set(slot, nil) -- (the rune goes dark)
	slot.rarityLabel.Text = ""
	slot.dpsLabel.Text = ""
	slot.prompt.ActionText = "Place Unit"
	slot.prompt.ObjectText = slot.commander and "Commander Throne" or ("Grave " .. i)
	return { unitType = unitType, oneIn = getBaseOneIn(unitType), level = level, fails = fails, locked = locked }
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
	for k in pairs(plotState.commanderSlots or {}) do
		local item = clearSlot(COMMANDER_BASE + k, plotState)
		if item then table.insert(pool, item) end
	end
	for _, item in ipairs(PlayerData.inventoryList(player)) do
		table.insert(pool, { unitType = item.unitType, oneIn = item.oneIn, level = item.level, fails = item.fails, locked = item.locked })
	end
	table.sort(pool, function(a, b)
		local dA = UNITS[a.unitType] and (UNITS[a.unitType].damage / UNITS[a.unitType].attackCD * Economy.levelMultiplier(a.level)) or 0
		local dB = UNITS[b.unitType] and (UNITS[b.unitType].damage / UNITS[b.unitType].attackCD * Economy.levelMultiplier(b.level)) or 0
		return dA > dB
	end)
	-- the strongest commanders onto the open thrones, the strongest of the rest onto the graves
	local thrones = {}
	for k, slot in pairs(plotState.commanderSlots or {}) do
		if not slot.sealed then table.insert(thrones, COMMANDER_BASE + k) end
	end
	table.sort(thrones)
	local slotCount = #plotState.graveSlots
	local remaining = {}
	local deployed = 0
	local nextGrave, nextThrone = 1, 1
	for _, item in ipairs(pool) do
		local target
		if isCommanderUnit(item.unitType) then
			target = thrones[nextThrone]
			if target then nextThrone += 1 end
		elseif nextGrave <= slotCount then
			target = nextGrave
			nextGrave += 1
		end
		if target and placeInSlot(plotState, target, item.unitType, item.level, item.fails, item.locked) then
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
-- `style` (optional, the unit def's hitFx) picks a different hit effect, e.g. "Slash" for sword units.
local function sendWallHit(plotState, position, damage, isGhost, style)
	Remotes.WallHit:FireAllClients(position, PlotFrame.forwardFlat(plotState), damage, isGhost, style)
end

-- ============================================================
-- Hit income: every hit on the wall also earns gold for its owner, ON TOP of the break gold (Economy.hitIncome).
-- Damage is turned into gold at the unit's income / DPS, so every attack style (hits, arrows, barrages, beams,
-- specials) pays the same gold per second. Each unit collects its own; every HIT_COIN_INTERVAL seconds it pops out of
-- the wall where that unit hits as a few coins (Drops.spawnHitCoins) that the player or the Soul Wisp has to pick up.
-- Stronger units (rarity rank, level) throw more and bigger coins; the gold per second is the same either way.
-- ============================================================
local HIT_COIN_INTERVAL = 3.5
local HIT_PAY_CHECK = 0.5 -- how often a plot looks for units whose coins are due
local MAX_RANK = 0
for _, r in pairs(Rarities.Rank) do MAX_RANK = math.max(MAX_RANK, r) end

local function earnHitGold(plotState, u, damage)
	local dps = u.def.damage / u.def.attackCD
	if not (dps > 0 and damage > 0) then return end
	local rank = Rarities.Rank[UNIT_RARITY[u.block.Name]] or 1
	-- (ascension and coin boost are applied when the coins drop)
	local spirits = 1 + (plotState.famBonus and plotState.famBonus.Spirits or 0) -- (the Spirits' harvest)
	u.hitGold = (u.hitGold or 0) + damage / dps * Economy.hitIncome(rank, u.level, 0) * spirits
	u.hitGoldSince = u.hitGoldSince or os.clock()
end

local function payHitGold(plotState, now)
	if now - (plotState.hitGoldAt or 0) < HIT_PAY_CHECK then return end
	plotState.hitGoldAt = now
	local owner, profile
	for _, u in ipairs(plotState.activeUnits) do
		if (u.hitGold or 0) > 0 and os.clock() - u.hitGoldSince >= HIT_COIN_INTERVAL then
			if not owner then
				for _, p in ipairs(Players:GetPlayers()) do
					if tostring(p.UserId) == plotState.ownerId then owner = p break end
				end
				profile = owner and PlayerData.get(owner)
				if not profile then return end
			end
			-- whole gold only; the fraction stays with the unit for its next coins
			local mult = Economy.hitIncomeStep(profile.rebirthCount)
				* Economy.wallGoldMultiplier(profile.rebirthCount, profile.upgrades.coinBoost)
				* Economy.realmUpgradeEffect("harvest", profile.realmUpgrades.harvest) -- (realm upgrade Soul Harvest)
			local exact = u.hitGold * mult
			local gold = math.floor(exact)
			u.hitGold = (exact - gold) / mult
			u.hitGoldSince = os.clock()
			if gold > 0 then
				local rank = Rarities.Rank[UNIT_RARITY[u.block.Name]] or 1
				local t = math.clamp((rank - 1) / math.max(1, MAX_RANK - 1) + (u.level or 0) * 0.02, 0, 1)
				local count = 1 + math.floor((rank - 1) / 3) + ((u.level or 0) >= 5 and 1 or 0)
				Drops.spawnHitCoins(owner, plotState, gold, u.slotLat or u.lateral or 0, count, t)
				Quests.increment(owner, "earnGold", gold)
			end
		end
	end
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
local FORMATION_HALF_WIDTH = 17  -- units stay this close to the lane's centre line (the lane is 40 wide)
local FORMATION_SPACING_SCALE = 2.6 -- studs between two units in a row, times the widest unit's body width
local FORMATION_MIN_SPACING = 6  -- never closer than this across the lane
local FORMATION_RANK_DEPTH = 3.5 -- a full row puts its extra units into another rank this far behind it
local ARRIVE_RADIUS = 1.2        -- how close a unit must get to its slot before it stops and attacks
local STAY_RADIUS = 3            -- a unit that has arrived keeps attacking unless it is pushed further than this
RANGED_STAY_RADIUS = 10    -- ranged units (they stand 15+ studs back) re-march only when the front is this far off: the walls
                           -- are only about 6 studs apart, so they do not have to walk after every single break
RANGED_STAND = 15

-- Where a unit stands: melee and short-range units (range up to FORMATION_SHORT_RANGE) just inside their range; beyond
-- that every extra stud of range moves the unit FORMATION_LONG_SCALE studs further back, so mages and archers fight from
-- far away and their projectiles have a long way to travel (range 15 -> 15, 20 -> 30, 25 -> 40, 30 -> 55 studs from the wall).
local FORMATION_SHORT_RANGE = 12
local FORMATION_LONG_SCALE = 2.5

standDistance = function(def)
	if def.infiniteRange then
		return INFINITE_STAND
	end
	local range = def.attackRange - 1.5
	if def.attackRange > FORMATION_SHORT_RANGE then
		range = (FORMATION_SHORT_RANGE - 1.5) + (def.attackRange - FORMATION_SHORT_RANGE) * FORMATION_LONG_SCALE
	end
	return math.max(FORMATION_MIN_STAND, math.floor(range / FORMATION_BAND) * FORMATION_BAND)
end

local function layoutFormation(plotState)
	local rows, stands, statics = {}, {}, {}
	for _, u in ipairs(plotState.activeUnits) do
		if u.def.static then
			table.insert(statics, u)
		else
			local stand = standDistance(u.def)
			if not rows[stand] then
				rows[stand] = {}
				table.insert(stands, stand)
			end
			table.insert(rows[stand], u)
		end
	end
	table.sort(stands)

	-- static units (towers) stand on the centre line of the lane, centre first, a few body widths apart, and are
	-- never part of a row; one that was not spawned on its final slot is moved there once
	table.sort(statics, function(a, b) return a.id < b.id end)
	for i, u in ipairs(statics) do
		local k = i - 1
		local side = (k % 2 == 1) and 1 or -1
		local lat = (k == 0) and 0 or side * math.ceil(k / 2) * u.def.size.X * 5
		u.slotLat = math.clamp(lat, -FORMATION_HALF_WIDTH, FORMATION_HALF_WIDTH)
		u.slotStand = standDistance(u.def)
		if not u.placed then
			u.placed = true
			if math.abs(u.slotLat - (u.lateral or 0)) > 0.5 then
				local pos = PlotFrame.toWorld(plotState, u.slotLat, plotState.wallTargetFwd - u.slotStand)
					+ Vector3.new(0, u.def.size.Y / 2 + 1, 0)
				u.block.CFrame = CFrame.lookAt(pos, pos + PlotFrame.forwardFlat(plotState))
			end
		end
	end

	for rowIndex, stand in ipairs(stands) do
		local row = rows[stand]
		table.sort(row, function(a, b) return a.id < b.id end)
		-- wide units need more room; a row that would not fit across the lane is never squeezed, the extra units
		-- form another rank just behind it (staggered against the one in front)
		local spacing = FORMATION_MIN_SPACING
		for _, u in ipairs(row) do
			spacing = math.max(spacing, u.def.size.X * FORMATION_SPACING_SCALE)
		end
		local perRank = math.max(1, math.floor(FORMATION_HALF_WIDTH / spacing) * 2 + 1)
		for i, u in ipairs(row) do
			local rank = math.floor((i - 1) / perRank)
			local k = (i - 1) % perRank -- slot 0 is the centre, then +1, -1, +2, -2 ...
			local side = (k % 2 == 1) and 1 or -1
			local lat = (k == 0) and 0 or side * math.ceil(k / 2) * spacing
			-- stagger every other row and every other rank, like a proper battle line
			local shift = ((rowIndex + rank) % 2 == 0) and spacing / 2 or 0
			u.slotLat = math.clamp(lat + shift, -FORMATION_HALF_WIDTH, FORMATION_HALF_WIDTH)
			u.slotStand = stand + rank * FORMATION_RANK_DEPTH
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
	if u.def.shotFlight then
		flight = u.def.shotFlight -- sigil casters fire from small circles right next to the wall: a short flight
	end
	local start = workspace:GetServerTimeNow() + BARRAGE_LEAD
	u.barrage = {
		start = start,
		rate = rate,
		flight = flight,
		-- (a unit with a special deals only the rest of its damage with its barrage)
		shotDamage = (u.def.damage / u.def.attackCD) / rate * (u.def.special and (1 - u.def.special.share) or 1),
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

-- ── Beams (AttackStyle = "BeamCast") ───────────────────────────────
-- Artillery like the Last Lantern burns the wall with a ray: a beam of BEAM_DURATION seconds, then a pause, every
-- attackCD seconds (the first one after the unit has finished rising). Same idea as the barrages: the server only
-- sets the model attributes Beam, BeamStart (server time of the first beam), BeamPeriod, BeamDuration and AimPos, and
-- the clients draw the cycle from them with the synced server clock (see SpellEffects). The damage of one beam is
-- the unit's `damage`, dealt evenly while the beam burns, so the DPS is damage / attackCD like every other unit.
local BEAM_DURATION = 1.0 -- seconds one beam burns
local BEAM_LEAD = 1.0 -- the first beam starts this long after the unit finished rising
local BEAM_AIM_HEIGHT = 9 -- studs above the floor on the wall face that the beam hits

-- total damage a beam cycle has dealt by (server) time t
local function beamDamageBy(b, t)
	local elapsed = t - b.start
	if elapsed <= 0 then
		return 0
	end
	local cycles = math.floor(elapsed / b.period)
	local into = elapsed - cycles * b.period
	return (cycles + math.min(into, b.duration) / b.duration) * b.perBeam
end

local function startBeam(u, plotState, lat)
	if not u.model then return end
	local face = PlotFrame.toWorld(plotState, lat, plotState.wallFaceFwd)
	local riseEnd = (u.model:GetAttribute("RiseStart") or 0) + (u.model:GetAttribute("RiseTime") or 0)
	local start = math.max(workspace:GetServerTimeNow(), riseEnd) + BEAM_LEAD
	u.beam = {
		start = start,
		period = math.max(u.def.attackCD, BEAM_DURATION + 0.5),
		duration = BEAM_DURATION,
		perBeam = u.def.damage,
		dealt = 0,
		endTime = nil,
	}
	u.model:SetAttribute("AimPos", face + Vector3.new(0, BEAM_AIM_HEIGHT, 0))
	u.model:SetAttribute("BeamStart", start)
	u.model:SetAttribute("BeamPeriod", u.beam.period)
	u.model:SetAttribute("BeamDuration", BEAM_DURATION)
	u.model:SetAttribute("Beam", true) -- last, so a client that sees it also sees the rest
end

local function stopBeam(u)
	local b = u.beam
	if not b or b.endTime then return end
	b.endTime = workspace:GetServerTimeNow()
	if u.model then
		u.model:SetAttribute("Beam", false)
	end
end

-- Applies the damage of every shot that has landed (called once per plot per frame).
-- ── Special attacks (unit def `special`, e.g. Hush's Rift Chains) ─────────
-- A unit with a special charges it for `cooldown` seconds (shown on the client as a meter from the model attributes
-- SpecialStart = server time the charge began and SpecialCD), then, while it has a wall to fight, fires it: the model
-- gets SpecialAt (server time it starts), SpecialKind, SpecialAim (the spot on the wall) and SpecialSeed (so every client
-- draws the same chains); basic attacks pause for `duration`, and the damage lands at the `hits` moments. The special
-- deals `share` of the unit's damage per cycle and basic attacks the rest, so the unit's DPS stays damage / attackCD.
local SPECIAL_TEST_COOLDOWN = 10 -- in Studio specials charge this fast, to test them (DEV panel: "Specials: fast / real")
local function specialCooldown(def, plotState)
	local fast = game:GetService("RunService"):IsStudio() and workspace:GetAttribute("DevFastSpecials") ~= false
	local arcane = plotState and plotState.famBonus and plotState.famBonus.Arcane or 0 -- (the Arcane rites)
	return (fast and SPECIAL_TEST_COOLDOWN or def.special.cooldown) * (1 - arcane)
end

local function chargeSpecial(u, now, cooldown)
	u.specialReady = now + cooldown
	if u.model then
		u.model:SetAttribute("SpecialStart", workspace:GetServerTimeNow())
		u.model:SetAttribute("SpecialCD", cooldown)
	end
end

local function initSpecial(u, now, plotState)
	-- each unit starts somewhere in its charge, so several specials do not fire at the same moment
	local cd = specialCooldown(u.def, plotState)
	local head = cd * math.random() * 0.4
	u.specialReady = now + cd - head
	if u.model then
		u.model:SetAttribute("SpecialStart", workspace:GetServerTimeNow() - head)
		u.model:SetAttribute("SpecialCD", cd)
	end
end

-- Malak's drone swarm (special `swarm`): from `from` to `to` seconds after the start it deals `armySeconds` seconds of
-- the whole army's current DPS (every unit on the plot, his own included), in ticks of `tick` seconds, always on the
-- wall being fought (the drones follow the front). Cut short by a Fleet Strike or an ascension (the run restarts): the
-- model gets SpecialCut (server time) and the client sends the drones home at once.
local function wallRising(plotState)
	local m = plotState.wall and plotState.wall:FindFirstChild("WallModel")
	local riseStart = m and m:GetAttribute("RiseStart")
	return riseStart ~= nil and workspace:GetServerTimeNow() < riseStart + (m:GetAttribute("RiseTime") or 0)
end

local function startSwarm(u, plotState, swarm)
	local startLayer = plotState.wallLayer
	local ticks = math.max(1, math.floor((swarm.to - swarm.from) / swarm.tick))
	local stopped = false
	task.spawn(function()
		task.wait(swarm.from)
		local dealt = 0 -- (in ticks' worth: ticks held while a wall rises are made up over the rest of the swarm)
		for i = 1, ticks do
			if stopped or not u.block or not u.block.Parent then
				return
			end
			if plotState.finisher or (plotState.wallLayer or 0) < (startLayer or 0) then
				if u.model then
					u.model:SetAttribute("SpecialHold", nil)
				end
				stopped = true
				if u.model then
					u.model:SetAttribute("SpecialCut", workspace:GetServerTimeNow())
				end
				return
			end
			-- (the drones hold their fire while the next wall is still rising: SpecialHold for the clients)
			local hold = not plotState.wall or wallRising(plotState)
			if u.model and (u.model:GetAttribute("SpecialHold") or false) ~= hold then
				u.model:SetAttribute("SpecialHold", hold)
			end
			if not hold and plotState.wallHP > 0 then
				local armyDps = 0
				for _, other in ipairs(plotState.activeUnits) do
					if other.def and other.block and other.block.Parent then
						armyDps += other.def.damage / other.def.attackCD
					end
				end
				local share = (ticks - dealt) / (ticks - i + 1)
				dealt += share
				local dmg = armyDps * swarm.armySeconds / ticks * share
				plotState.wallHP = math.max(0, plotState.wallHP - dmg)
				earnHitGold(plotState, u, dmg)
				updateWallGui(plotState)
				if plotState.wallHP <= 0 then breakWall(plotState) end
			end
			task.wait(swarm.tick)
		end
		if u.model then
			u.model:SetAttribute("SpecialHold", nil)
		end
	end)
end

local function startSpecial(u, plotState, lat, now)
	local sp = u.def.special
	local targetWall = plotState.wall
	local cd = specialCooldown(u.def, plotState)
	local aim = PlotFrame.toWorld(plotState, lat, plotState.wallFaceFwd) + Vector3.new(0, 7, 0)
	if u.model then
		u.model:SetAttribute("SpecialKind", sp.kind)
		u.model:SetAttribute("SpecialAim", aim)
		u.model:SetAttribute("SpecialSeed", math.random(1, 1e6))
		u.model:SetAttribute("SpecialAt", workspace:GetServerTimeNow())
	end
	-- basic attacks resume when the special is over (a special that keepAttacking runs beside them: Malak's drones)
	if not sp.keepAttacking then
		u.lastAttack = now + sp.duration - u.def.attackCD
	else
		u.keepSpecialUntil = now + sp.duration -- (its aim follows the front meanwhile, see the update loop)
	end
	-- the damage of one cycle: the special's share of (DPS x cooldown)
	local total = (u.def.damage / u.def.attackCD) * sp.share * cd
	if sp.swarm then
		startSwarm(u, plotState, sp.swarm)
	end
	for _, h in ipairs(sp.hits) do
		task.delay(h.at, function()
			if not plotState.wall or not u.block or not u.block.Parent then return end
			if plotState.wall ~= targetWall then return end -- the remaining spectacle belongs to the old wall
			local dmg = total * h.share
			plotState.wallHP = math.max(0, plotState.wallHP - dmg)
			earnHitGold(plotState, u, dmg)
			updateWallGui(plotState)
			if plotState.wallHP <= 0 then breakWall(plotState) end
		end)
	end
	-- the next charge starts when this special is over
	task.delay(sp.duration, function()
		if u.block and u.block.Parent then
			chargeSpecial(u, now + sp.duration, cd) -- (`now` is the loop clock at the start)
		end
	end)
	u.specialReady = math.huge -- until the charge restarts
end

local function settleBarrages(plotState, now)
	local t = workspace:GetServerTimeNow()
	local damage = 0
	for _, u in ipairs(plotState.activeUnits) do
		local beam = u.beam
		if beam then
			local total = beamDamageBy(beam, math.min(t, beam.endTime or t))
			if total > beam.dealt then
				damage += total - beam.dealt
				earnHitGold(plotState, u, total - beam.dealt)
				beam.dealt = total
			end
			if beam.endTime then
				u.beam = nil -- stopped: its last damage has been counted
			end
		end
		local b = u.barrage
		if b then
			local firedBy = b.endTime and math.min(t - b.flight, b.endTime) or (t - b.flight)
			local landed = shotsFiredBy(b, firedBy)
			if landed > b.landed then
				damage += (landed - b.landed) * b.shotDamage
				earnHitGold(plotState, u, (landed - b.landed) * b.shotDamage)
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

-- A companion's volley (unit def `companion`, e.g. Malak's drone): its own slow attack on its own clock while the unit
-- fights, dealing `share` of the unit's damage (its basic attacks deal the rest, so DPS stays damage / attackCD). The
-- client draws it from the model attributes DroneAim and DroneShot (server time the volley starts); the damage lands
-- `hitAt` seconds later on the wall that was being fought (nothing if that wall broke meanwhile).
local function fireCompanion(u, plotState)
	local c = u.def.companion
	local wallAtStart = plotState.wall
	local standLat = PlotFrame.toLocal(plotState, u.block.Position)
	local aim = PlotFrame.toWorld(plotState, standLat + (math.random() - 0.5) * 4, plotState.wallFaceFwd)
		+ Vector3.new(0, (c.hitHeight or 6) * (0.9 + math.random() * 0.2), 0)
	local damage = (u.def.damage / u.def.attackCD) * c.share * c.period
	if u.model then
		u.model:SetAttribute("DroneAim", aim)
		u.model:SetAttribute("DroneShot", workspace:GetServerTimeNow()) -- (last: a client that sees it also sees the aim)
	end
	task.delay(c.hitAt, function()
		if plotState.wall ~= wallAtStart or not plotState.wall then return end
		plotState.wallHP = math.max(0, plotState.wallHP - damage)
		earnHitGold(plotState, u, damage)
		updateWallGui(plotState)
		sendWallHit(plotState, aim, damage, u.def.transparent, "Orbital") -- (the client draws its own impact)
		if plotState.wallHP <= 0 then breakWall(plotState) end
	end)
end

-- Malak's Fleet Strike: where the fleeing army runs to (forward distance from the plot's centre: by the graves) and
-- how much faster than their march they run
local FINISHER_FLEE_FWD = 8
local FINISHER_FLEE_SPEED = 1.7

-- Starts (or, with on = false, ends) a finisher cutscene on the plot (see the `finisher` block in update). `unit` is the
-- Sovereign's entry (he stays put); fleeAt / length in seconds from now.
-- The cutscene's camera flies to the lane's end (the gate, the keeper behind the outer wall) while the owner's character
-- may stand far away (the plaza): with StreamingEnabled those parts might not be loaded on their client. So while a
-- finisher runs the owner's streaming focus (Player.ReplicationFocus) is a point at the gate, and the server asks for
-- the area round it at once; it goes back to the character when the finisher ends.
local function setFinisherFocus(plotState, on)
	local owner = Players:GetPlayerByUserId(tonumber(plotState.ownerId) or 0)
	if plotState.finisherFocus then
		plotState.finisherFocus:Destroy()
		plotState.finisherFocus = nil
	end
	if not owner then
		return
	end
	if not on then
		if owner.ReplicationFocus == nil or not owner.ReplicationFocus.Parent then
			owner.ReplicationFocus = nil
		end
		return
	end
	local at = PlotFrame.toWorld(plotState, 0, plotState.wallFaceFwd) + Vector3.new(0, 20, 0)
	local focus = Instance.new("Part")
	focus.Name = "FinisherFocus"
	focus.Anchored = true
	focus.CanCollide, focus.CanQuery, focus.CanTouch = false, false, false
	focus.Transparency = 1
	focus.Size = Vector3.one
	focus.Position = at
	focus.Parent = workspace
	plotState.finisherFocus = focus
	owner.ReplicationFocus = focus
	task.spawn(function()
		pcall(function()
			owner:RequestStreamAroundAsync(at, 5)
		end)
	end)
end

local function startFinisher(plotState, unit, fleeAt, length, on)
	if on == false then
		if plotState.finisher and plotState.finisher.holdHP then
			return -- (a real Fleet Strike is not stopped by the Studio preview's Skip)
		end
		plotState.finisher = nil
		setFinisherFocus(plotState, false)
		return
	end
	local start = workspace:GetServerTimeNow()
	local finisher = { start = start, fleeAt = fleeAt, untilT = start + length, unit = unit }
	plotState.finisher = finisher
	setFinisherFocus(plotState, true)
	-- (the focus goes back when it runs out, even if nobody ends it)
	task.delay(length + 1, function()
		if plotState.finisher == finisher then
			setFinisherFocus(plotState, false)
		end
	end)
	return finisher
end

-- Malak's Fleet Strike (docs/envoy.md, client FleetStrike.lua): when the gate is down to Economy.FLEET_STRIKE_HP of its
-- HP, the owner has unlocked it and a Malak fights on the plot, the gate is HELD there, every client plays the
-- cutscene from the same server time (FleetStrike remote), and at FLEET_GATE_HIT s, when the beam reaches it, the gate
-- breaks for real (the keeper's Defeat, the loot, the portal: Walls.breakWall). Once per gate.
local FLEET_FLEE_AT = 11
local FLEET_LENGTH = 54
local FLEET_GATE_HIT = 49.4
local function checkFleetStrike(plotState, serverNow)
	local fin = plotState.finisher
	if fin and fin.kind == "FleetStrike" then
		if not fin.allowBreak then
			plotState.wallHP = math.max(plotState.wallHP, fin.holdHP) -- (the gate holds)
			if serverNow >= fin.start + FLEET_GATE_HIT and plotState.wall then
				fin.allowBreak = true
				plotState.wallHP = 0
				updateWallGui(plotState)
				breakWall(plotState)
			end
		end
		return
	end
	local wall = plotState.wall
	if not wall or not Economy.isGate(plotState.wallLayer) or plotState.fleetStrikeWall == wall then
		return
	end
	local maxHP = plotState.WALL_MAX_HP or 0
	if maxHP <= 0 or plotState.wallHP > maxHP * Economy.FLEET_STRIKE_HP then
		return
	end
	local owner = Players:GetPlayerByUserId(tonumber(plotState.ownerId) or 0)
	local profile = owner and PlayerData.get(owner)
	if not profile or not profile.fleetStrike then
		return
	end
	local malak
	for _, u in ipairs(plotState.activeUnits) do
		if u.unitType == "Malak" and u.model and u.block.Parent then
			malak = u
			break
		end
	end
	if not malak then
		return
	end
	plotState.fleetStrikeWall = wall -- (once per gate)
	local started = startFinisher(plotState, malak, FLEET_FLEE_AT, FLEET_LENGTH)
	started.kind = "FleetStrike"
	started.holdHP = math.max(1, plotState.wallHP)
	local gate = PlotFrame.toWorld(plotState, 0, plotState.wallFaceFwd) + Vector3.new(0, 4, 0)
	Remotes.FleetStrike:FireAllClients({
		owner = plotState.ownerId, startAt = started.start, malak = malak.model, gate = gate,
		malakCF = malak.model:GetPivot(),
	})
	print("Fleet Strike on plot " .. tostring(plotState.plotIndex))
end

-- Advances every plot's units one frame: walk to the formation slot facing the wall, then attack it.
-- the plot's units for the family count: everyone fighting on it (dev units too, to test)
local function refreshBonuses(plotState)
	local list = {}
	for _, u in ipairs(plotState.activeUnits) do
		if u.block and u.block.Parent then
			table.insert(list, { unitType = u.unitType, level = u.level })
		end
	end
	local bonus, counts = SharedUnits.familyBonuses(list, Economy.AWAKEN_LEVEL)
	local atGate = plotState.wall ~= nil and Economy.isGate(plotState.wallLayer)
	-- the Beasts' burst: for burstTime s after the wall being fought has finished rising
	local burst = false
	local m = plotState.wall and plotState.wall:FindFirstChild("WallModel")
	local riseStart = m and m:GetAttribute("RiseStart")
	if riseStart then
		local stood = riseStart + (m:GetAttribute("RiseTime") or 0)
		local t = workspace:GetServerTimeNow()
		burst = t >= stood and t < stood + SharedUnits.Families.Beasts.burstTime
	end
	local aura = auraMultiplier(plotState)
	local key = table.concat({ aura, tostring(atGate), tostring(burst), bonus.Bones, bonus.Flesh, bonus.Spirits, bonus.Beasts, bonus.Arcane }, "|")
	if key ~= plotState.bonusKey then
		plotState.bonusKey = key
		plotState.auraMult = aura
		plotState.famBonus = bonus
		plotState.atGate = atGate
		plotState.beastBurst = burst
		setDamageMultiplier(plotState)
		-- for the clients (the placement screen, later): the family counts on the plot model, e.g. "Bones=3,Spirits=2"
		if plotState.plotModel then
			local parts = {}
			for name, n in pairs(counts) do
				table.insert(parts, name .. "=" .. n)
			end
			table.sort(parts)
			plotState.plotModel:SetAttribute("FamilyCounts", table.concat(parts, ","))
		end
	end
end

local function update(now, dt)
	local serverNow = workspace:GetServerTimeNow()
	-- Unit AI — iterate over every player's plot
	for _, plotState in pairs(playerPlots) do
		checkFleetStrike(plotState, serverNow)
		-- auras (Malak's +10% damage) and the families (SharedUnits.familyBonuses): re-apply the damage of every unit when the
		-- strongest aura, a family tier, the gate or the Beasts' burst changes
		if now - (plotState.auraCheckAt or 0) >= 1 then
			plotState.auraCheckAt = now
			refreshBonuses(plotState)
		end
		if not plotState.wall or not plotState.wall.Parent then
			-- the gate has fallen (or the lane is being rebuilt): nothing left to shoot, so everyone stands down
			for _, u in ipairs(plotState.activeUnits) do
				if u.barrage and not u.barrage.endTime then stopBarrage(u) end
				if u.beam and not u.beam.endTime then stopBeam(u) end
				u.barrage, u.beam = nil, nil -- shots still in the air are dropped
				if u.block.Parent then
					u.bv.Velocity = Vector3.new(0, 0, 0)
				end
				if u.walkTrack and u.walkTrack.IsPlaying then u.walkTrack:Stop() end
				setState(u, "idle")
			end
			plotState.barrageBuffer = 0
			continue
		end

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
			-- stunned by the titan's tremor (plotState.stun, set by Walls when he slams the outer wall): from the moment
			-- the tremor reaches the unit until the new wall stands it does nothing; the clients bind it (StunFx) and
			-- freeze its animation (UnitAnimator) from the attributes StunFrom / StunUntil
			local stun = plotState.stun
			if stun and serverNow < stun.untilT then
				local _, fwd = PlotFrame.toLocal(plotState, pos)
				local from = stun.impact + math.max(0, stun.originFwd - fwd) / stun.speed
				if serverNow >= from then
					if u.stunId ~= stun.id then
						u.stunId = stun.id
						if u.model then
							u.model:SetAttribute("StunFrom", from)
							u.model:SetAttribute("StunUntil", stun.untilT)
						end
					end
					if u.barrage and not u.barrage.endTime then stopBarrage(u) end
					if u.beam and not u.beam.endTime then stopBeam(u) end
					u.bv.Velocity = Vector3.new(0, 0, 0)
					if u.walkTrack and u.walkTrack.IsPlaying then u.walkTrack:Stop() end
					u.lastAttack = now -- the attack timer starts again after the stun
					continue
				end
			end
			-- a finisher cutscene (Malak's Fleet Strike; plotState.finisher = { start, fleeAt, untilT, unit }): nobody
			-- attacks; from fleeAt the rest of the army turns and runs back towards the graves (and cowers there) while
			-- the Sovereign stays where he is; when it ends they march back to the wall as usual
			local fin = plotState.finisher
			if fin and serverNow < fin.untilT then
				if u.barrage and not u.barrage.endTime then stopBarrage(u) end
				if u.beam and not u.beam.endTime then stopBeam(u) end
				u.lastAttack = now
				u.arrived = false
				local fleeing = u ~= fin.unit and not u.def.static and serverNow >= fin.start + fin.fleeAt
				local fleeTarget = fleeing and PlotFrame.toWorld(plotState, (u.slotLat or u.lateral) * 0.6, FINISHER_FLEE_FWD)
				local away = fleeTarget and Vector3.new(fleeTarget.X - pos.X, 0, fleeTarget.Z - pos.Z)
				if away and away.Magnitude > 3 then
					local dir = away.Unit
					local speed = u.def.speed * FINISHER_FLEE_SPEED
					u.bv.Velocity = Vector3.new(dir.X * speed, 0, dir.Z * speed)
					u.bg.CFrame = CFrame.new(pos, pos + dir)
					if u.walkTrack and not u.walkTrack.IsPlaying then u.walkTrack:Play() end
					setState(u, "walk")
				else
					u.bv.Velocity = Vector3.new(0, 0, 0)
					if fleeing then
						-- huddled by the graves, looking back at the wall
						u.bg.CFrame = CFrame.lookAt(pos, pos + PlotFrame.forwardFlat(plotState))
					end
					if u.walkTrack and u.walkTrack.IsPlaying then u.walkTrack:Stop() end
					setState(u, "idle")
				end
				continue
			end
			local flatPos    = Vector3.new(pos.X, 0, pos.Z)
			-- the unit's slot in the formation (falls back to the lane it was placed in until the first layout)
			local lat = u.slotLat or u.lateral
			-- the front wall advances down the lane as walls break and the army marches after it; a static unit (a tower)
			-- cannot march, so it keeps the spot it rose at
			local standFwd = plotState.wallTargetFwd - (u.slotStand or FORMATION_MIN_STAND)
			if u.def.infiniteRange then
				standFwd = INFINITE_RANGE_POST_FWD
			end
			if u.def.static then
				u.staticFwd = u.staticFwd or standFwd
				standFwd = u.staticFwd
			end
			local target     = PlotFrame.toWorld(plotState, lat, standFwd)
			local flatTarget = Vector3.new(target.X, 0, target.Z)
			local dist = (flatPos - flatTarget).Magnitude
			local forward = PlotFrame.forwardFlat(plotState)

			-- arrived = stand in the slot and attack (units that are already in place stay put unless pushed away;
			-- the arrival radius grows with speed so a fast unit cannot overshoot its slot forever)
			local stayRadius = ((u.slotStand or 0) >= RANGED_STAND) and RANGED_STAY_RADIUS or STAY_RADIUS
			u.arrived = dist <= (u.arrived and stayRadius or math.max(ARRIVE_RADIUS, u.def.speed * dt * 1.5))

			-- a special that runs beside the attacks (Malak's drones) follows the front: its aim moves on with the wall
			if u.keepSpecialUntil and u.model and plotState.wall then
				if now < u.keepSpecialUntil then
					local aim = PlotFrame.toWorld(plotState, lat, plotState.wallFaceFwd) + Vector3.new(0, 7, 0)
					if (u.model:GetAttribute("SpecialAim") or aim) ~= aim then
						u.model:SetAttribute("SpecialAim", aim)
					end
				else
					u.keepSpecialUntil = nil
				end
			end

			if u.arrived then
				u.bv.Velocity = Vector3.new(0, 0, 0)
				u.bg.CFrame = CFrame.lookAt(pos, pos + forward)

				if u.walkTrack and u.walkTrack.IsPlaying then u.walkTrack:Stop() end
				setState(u, "idle")
				local attackStyle = u.model and u.model:GetAttribute("AttackStyle")
				if u.def.special and not u.specialReady then
					initSpecial(u, now, plotState)
				end
				-- a companion (Malak's drone) fires its own slow volley on its own clock while the unit fights
				if u.def.companion and plotState.wall then
					u.companionNext = u.companionNext or (now + u.def.companion.firstDelay)
					if now >= u.companionNext then
						u.companionNext = now + u.def.companion.period
						fireCompanion(u, plotState)
					end
				end
				if attackStyle == "StaffCast" or attackStyle == "SigilCast" then
					-- staff casters fire a continuous barrage instead of one attack per cooldown (see startBarrage);
					-- a caster with a special (the Sigilwright's Verdict) stops the barrage while it plays
					if u.def.special and plotState.wall and now >= u.specialReady then
						if u.barrage and not u.barrage.endTime then stopBarrage(u) end
						startSpecial(u, plotState, lat, now)
						u.specialUntil = now + u.def.special.duration
					elseif now < (u.specialUntil or 0) then
						-- the special is playing: no barrage
					elseif not u.barrage or u.barrage.endTime then
						startBarrage(u, plotState, lat)
					elseif u.model then
						-- the front wall moves on when a wall breaks: keep the barrage aimed at the wall being fought
						u.model:SetAttribute("AimPos", PlotFrame.toWorld(plotState, lat, plotState.wallFaceFwd) + Vector3.new(0, 6, 0))
					end
				elseif attackStyle == "BeamCast" then
					-- artillery burns the wall with a beam on a fixed cycle (see startBeam)
					if not u.beam or u.beam.endTime then
						startBeam(u, plotState, lat)
					elseif u.model then
						-- the front wall moves on when a wall breaks: keep the beam aimed at the wall being fought
						u.model:SetAttribute("AimPos", PlotFrame.toWorld(plotState, lat, plotState.wallFaceFwd)
							+ Vector3.new(0, BEAM_AIM_HEIGHT, 0))
					end
				elseif u.def.special and plotState.wall and now >= u.specialReady then
					startSpecial(u, plotState, lat, now)
				elseif now - u.lastAttack >= u.def.attackCD then
					u.lastAttack = now
					if u.model then
						u.model:SetAttribute("AttackCount", (u.model:GetAttribute("AttackCount") or 0) + 1)
					end
					if u.attackTrack then u.attackTrack:Play() end
					local fromPos = u.block.Position
					-- on the wall face right in front of this unit, around chest height, with a little jitter
					local unitHeight = u.model and (u.model:GetAttribute("Height") or 5) * u.model:GetScale()
						or u.def.size.Y * 1.6
					-- (a unit def's hitHeight, in studs above the floor, overrides it: e.g. the crawling Ghoul leaps and rakes high,
					-- above the wall's plinth)
					local hitY = u.def.hitHeight and u.def.hitHeight * (0.95 + math.random() * 0.1)
						or unitHeight * (0.5 + math.random() * 0.2)
					-- (from where the unit really stands, not its slot: a fast unit stops up to ~2 studs off it; units with their own
					-- hit effect scatter less, so the cut lines up with the claws / blade)
					local standLat = PlotFrame.toLocal(plotState, fromPos)
					local jitter = u.def.hitFx and 0.6 or 2.4
					local impactPos = PlotFrame.toWorld(plotState, standLat + (math.random() - 0.5) * jitter, plotState.wallFaceFwd)
						+ Vector3.new(0, hitY, 0)
					-- (a unit with a special deals only the rest of its damage with basic attacks)
					local damage = u.def.damage * (u.def.special and (1 - u.def.special.share) or 1)
						* (u.def.companion and (1 - u.def.companion.share) or 1) -- (and a companion's share)
					local function hit()
						if not plotState.wall then return end -- the gate already fell
						plotState.wallHP = math.max(0, plotState.wallHP - damage)
						earnHitGold(plotState, u, damage)
						updateWallGui(plotState)
						sendWallHit(plotState, impactPos, damage, u.def.transparent,
							u.def.hitFx and (u.shadowForm and u.def.hitFx .. "Shadow" or u.def.hitFx))
						if plotState.wallHP <= 0 then breakWall(plotState) end
					end
					-- a delayed hit: the attack animation shoots something first (Hush's finger beam, the Hollow Archer's arrow, the Crypt Spider's venom): the
					-- client aims it at AimPos and the damage lands when it arrives. An archer's delay is its release time plus the
					-- arrow's flight (projectileSpeed studs/s from where it stands)
					local delay = u.def.hitDelay
					if u.def.projectileSpeed then
						delay = (u.def.releaseAt or 0) + (impactPos - fromPos).Magnitude / u.def.projectileSpeed
					end
					if delay then
						if u.model then u.model:SetAttribute("AimPos", impactPos) end
						task.delay(delay, hit)
					else
						hit()
					end
				end
			else
				if u.barrage and not u.barrage.endTime then stopBarrage(u) end
				if u.beam and not u.beam.endTime then stopBeam(u) end
				if u.walkTrack and not u.walkTrack.IsPlaying then u.walkTrack:Play() end
				setState(u, "walk")
				local dir = (flatTarget - flatPos).Unit
				local speed = u.def.speed * (plotState.marchMult or 1) -- (realm upgrade Swift March)
				u.bv.Velocity = Vector3.new(dir.X * speed, 0, dir.Z * speed)
				u.bg.CFrame = CFrame.new(pos, pos + Vector3.new(dir.X, 0, dir.Z))
			end
		end

		settleBarrages(plotState, now)
		payHitGold(plotState, now)
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
	startFinisher = startFinisher, -- (plotState, unit entry, fleeAt, length, on) a finisher cutscene: see update
	placeInSlot = placeInSlot,
	getSlot = getSlot,
	placedList = placedList,
	isCommanderUnit = isCommanderUnit,
	COMMANDER_BASE = COMMANDER_BASE,
	spawnUnit = spawnUnit,
	setDamageMultiplier = setDamageMultiplier,
	setUnitLevel = setUnitLevel,
	standDistance = standDistance, -- (unit def) -> distance in front of the wall where the unit stands
	standForward = function(plotState, def) -- (plotState, unit def) -> forward position (along the lane) where the unit stands
		if def.infiniteRange then
			return INFINITE_RANGE_POST_FWD
		end
		return plotState.wallTargetFwd - standDistance(def)
	end,
	update = update,
}
