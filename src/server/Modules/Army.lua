-- Unit spawning, placement on grave slots, recall, and the per-frame unit AI.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local Remotes = require(script.Parent.Remotes)
local Walls = require(script.Parent.Walls)
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

local function spawnUnit(unitType, customPos, plotState)
	local def = UNITS[unitType]
	if not def then return end

	local ld = plotState.laneDir
	local laneZ = customPos and customPos.Z or (plotState.plotCenterZ + math.random(-8, 8))
	local forwardClearance = def.size.X / 2 + 2
	local spawnPos = customPos
		and Vector3.new(customPos.X + ld * forwardClearance, customPos.Y + 2, customPos.Z)
		or  Vector3.new(plotState.wallOriginX - ld * 80, 4, laneZ)

	local block = Instance.new("Part")
	block.Name = unitType
	block.Size = def.size
	block.Position = spawnPos
	block.CanCollide = true
	block.CastShadow = true

	local walkTrack, attackTrack
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
		if modelClone.PrimaryPart then
			modelClone:SetPrimaryPartCFrame(CFrame.new(spawnPos))
		else
			modelClone:MoveTo(spawnPos)
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

		-- Load and play animations server-side so they replicate to clients
		local humanoid = modelClone:FindFirstChildWhichIsA("Humanoid", true)
		if humanoid then
			local animator = humanoid:FindFirstChildOfClass("Animator")
				or Instance.new("Animator", humanoid)
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
	bg.MaxTorque = Vector3.new(0, 1e5, 0)
	bg.P = 1e4
	bg.D = 400
	bg.CFrame = CFrame.new(spawnPos, Vector3.new(plotState.wallTarget.X, spawnPos.Y, plotState.wallTarget.Z))
	bg.Parent = block

	-- Unit info label (emoji + name / rarity / DPS)

	local unitRarity = UNIT_RARITY[unitType] or "Common"
	local unitDps = math.floor(def.damage / def.attackCD)
	local gui = Instance.new("BillboardGui", block)
	gui.Size = UDim2.new(0, 150, 0, 68)
	gui.StudsOffset = Vector3.new(0, def.size.Y + 1.8, 0)
	gui.AlwaysOnTop = true
	local nameLbl = Instance.new("TextLabel", gui)
	nameLbl.Size = UDim2.new(1, 0, 0.38, 0)
	nameLbl.Position = UDim2.new(0, 0, 0, 0)
	nameLbl.BackgroundTransparency = 1
	nameLbl.Text = (UNIT_EMOJIS[unitType] or "💀") .. " " .. unitType
	nameLbl.TextColor3 = Color3.fromRGB(255, 230, 255)
	nameLbl.TextScaled = true
	nameLbl.Font = Enum.Font.GothamBold
	local rarityLbl = Instance.new("TextLabel", gui)
	rarityLbl.Size = UDim2.new(1, 0, 0.31, 0)
	rarityLbl.Position = UDim2.new(0, 0, 0.38, 0)
	rarityLbl.BackgroundTransparency = 1
	rarityLbl.Text = unitRarity
	rarityLbl.TextColor3 = RARITY_COLOR[unitRarity] or Color3.fromRGB(200, 200, 200)
	rarityLbl.TextScaled = true
	rarityLbl.Font = Enum.Font.Gotham
	local dpsLbl = Instance.new("TextLabel", gui)
	dpsLbl.Size = UDim2.new(1, 0, 0.31, 0)
	dpsLbl.Position = UDim2.new(0, 0, 0.69, 0)
	dpsLbl.BackgroundTransparency = 1
	dpsLbl.Text = unitDps .. " DPS"
	dpsLbl.TextColor3 = Color3.fromRGB(100, 255, 130)
	dpsLbl.TextScaled = true
	dpsLbl.Font = Enum.Font.GothamBold

	table.insert(plotState.activeUnits, {
		block = block, bv = bv, bg = bg, def = def,
		lastAttack = 0, laneZ = laneZ,
		walkTrack = walkTrack, attackTrack = attackTrack,
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

local function flashAttack(isGhost, position, plotState)
	local flash = Instance.new("Part")
	flash.Size = Vector3.new(1.5, 1.5, 0.3)
	flash.CFrame = CFrame.new(
		position or Vector3.new(
			plotState.wall.Position.X - plotState.laneDir * (plotState.wall.Size.X/2 + 0.2),
			1 + math.random(0, 8),
			plotState.plotCenterZ + math.random(-8, 8)
		)
	)
	flash.Anchored = true
	flash.CanCollide = false
	flash.BrickColor = isGhost and BrickColor.new("Pastel blue") or BrickColor.new("Bright yellow")
	flash.Material = Enum.Material.Neon
	flash.Parent = workspace
	game:GetService("Debris"):AddItem(flash, 0.2)
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
		flashAttack(true, targetPos, plotState)
		plotState.wallHP = math.max(0, plotState.wallHP - damage)
		updateWallGui(plotState)
		Remotes.DamageHit:FireAllClients(damage, targetPos, true)
		if plotState.wallHP <= 0 then breakWall(plotState) end
	end)
end

-- Advances every plot's units one frame: walk toward the wall, then attack it.
local function update(now, dt)
	-- Unit AI — iterate over every player's plot
	for _, plotState in pairs(playerPlots) do
		if not plotState.wall or not plotState.wall.Parent then continue end

		for i = #plotState.activeUnits, 1, -1 do
			local u = plotState.activeUnits[i]
			if not u.block.Parent then
				table.remove(plotState.activeUnits, i)
				continue
			end
			if not u.phase then u.phase = math.random() * math.pi * 2 end

			local pos = u.block.Position
			local flatPos    = Vector3.new(pos.X, 0, pos.Z)
			local flatTarget = Vector3.new(plotState.wallTarget.X, 0, u.laneZ)
			local dist = (flatPos - flatTarget).Magnitude

			if dist <= u.def.attackRange then
				u.bv.Velocity = Vector3.new(0, 0, 0)
				u.bg.CFrame = CFrame.new(pos, Vector3.new(plotState.wall.Position.X, pos.Y, pos.Z))

				local gui = u.block:FindFirstChildOfClass("BillboardGui")
				if gui then
					gui.StudsOffset = Vector3.new(0, 1.5 + math.sin(now*3 + u.phase)*0.4, 0)
				end

				if u.block.Name == "Goblin" then
					local poison = UNITS.Goblin.poison or 1
					plotState.wallHP = math.max(0, plotState.wallHP - poison * dt)
					updateWallGui(plotState)
					if plotState.wallHP <= 0 then breakWall(plotState) end
				end

				if u.walkTrack and u.walkTrack.IsPlaying then u.walkTrack:Stop() end
				if now - u.lastAttack >= u.def.attackCD then
					u.lastAttack = now
					if u.attackTrack then u.attackTrack:Play() end
					local fromPos = u.block.Position
					local wallFaceX = plotState.wall.Position.X - plotState.laneDir * plotState.wall.Size.X/2
					local targetPos = Vector3.new(wallFaceX, fromPos.Y + 0.5, fromPos.Z)
					if u.block.Name == "Goblin" then
						shootArrow(fromPos, targetPos, u.def.damage, plotState)
					else
						local impactPos = Vector3.new(
							wallFaceX,
							2 + math.random(0, 7),
							plotState.plotCenterZ + math.random(-8, 8)
						)
						flashAttack(u.def.transparent, impactPos, plotState)
						plotState.wallHP = math.max(0, plotState.wallHP - u.def.damage)
						updateWallGui(plotState)
						Remotes.DamageHit:FireAllClients(u.def.damage, impactPos, u.def.transparent)
						if plotState.wallHP <= 0 then breakWall(plotState) end
					end
				end
			else
				if u.walkTrack and not u.walkTrack.IsPlaying then u.walkTrack:Play() end
				local dir = (flatTarget - flatPos).Unit
				u.bv.Velocity = Vector3.new(dir.X * u.def.speed, 0, dir.Z * u.def.speed)
				u.bg.CFrame = CFrame.new(pos, pos + Vector3.new(dir.X, 0, dir.Z))

				local gui = u.block:FindFirstChildOfClass("BillboardGui")
				if gui then
					gui.StudsOffset = Vector3.new(0, 1.5 + math.abs(math.sin(now*8 + u.phase))*0.3, 0)
				end
			end
		end
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
	update = update,
}
