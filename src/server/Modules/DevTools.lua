-- Studio-only developer tools: spawn any unit next to your wall so you can look at it (and its attack),
-- and clear those units again. Driven by the client's DevPanel. Does nothing outside Studio.
-- Dev units are not tied to graves or the inventory, so they are never saved.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

if not RunService:IsStudio() then
	return {}
end

local Remotes = require(script.Parent.Remotes)
local PlayerData = require(script.Parent.PlayerData)
local Army = require(script.Parent.Army)
local PlotRegistry = require(script.Parent.PlotRegistry)
local PlotFrame = require(script.Parent.PlotFrame)
local Units = require(ReplicatedStorage.Shared.Units)
local Economy = require(ReplicatedStorage.Shared.Economy)

local UNITS = Units.Stats
local spawned = {} -- [UserId] = how many dev units this player spawned (to spread them across the lane)

-- ============================================================
-- Spawn
-- ============================================================
-- atGraves = true: the unit starts behind the lane like a real one and marches to its formation slot;
-- otherwise it starts right next to its row in front of the wall, so it is attacking within a second or two.
Remotes.DevSpawnUnit.OnServerEvent:Connect(function(player, unitType, atGraves, level)
	if type(unitType) ~= "string" or not UNITS[unitType] then
		return
	end
	level = (type(level) == "number" and level == level) and math.clamp(math.floor(level), 0, 10) or 0
	if atGraves == "inventory" then
		-- into the inventory like a pulled unit (it is saved like one; the usual test-save reset clears it)
		PlayerData.addUnit(player, unitType, nil, level, 0)
		return
	end
	local plotState = PlotRegistry.getPlot(player)
	if not plotState then
		return
	end
	local def = UNITS[unitType]
	local n = (spawned[player.UserId] or 0) + 1
	spawned[player.UserId] = n

	if atGraves == true then
		Army.spawnUnit(unitType, nil, plotState, level)
	else
		local lateral = ((n - 1) % 7 - 3) * 4.5
		local forward = Army.standForward(plotState, def)
		Army.spawnUnit(unitType, PlotFrame.toWorld(plotState, lateral, forward), plotState, level)
	end

	local entry = plotState.activeUnits[#plotState.activeUnits]
	if entry then
		entry.dev = true
	end
end)

-- ============================================================
-- Clear
-- ============================================================
Remotes.DevClearUnits.OnServerEvent:Connect(function(player)
	local plotState = PlotRegistry.getPlot(player)
	if not plotState then
		return
	end
	for i = #plotState.activeUnits, 1, -1 do
		local u = plotState.activeUnits[i]
		if u.dev then
			if u.block and u.block.Parent then
				u.block:Destroy()
			end
			table.remove(plotState.activeUnits, i)
		end
	end
	spawned[player.UserId] = 0
end)

-- ============================================================
-- Gems
-- ============================================================
Remotes.DevGiveGems.OnServerEvent:Connect(function(player, amount)
	if type(amount) ~= "number" or amount ~= amount then
		return
	end
	PlayerData.addGems(player, math.clamp(math.floor(amount), 1, 100000))
end)

-- ============================================================
-- Specials: fast (10 s charge, the default in Studio) or real (the units' own cooldowns); a workspace attribute the
-- Army reads when a special starts charging, so units already charging keep their current charge
-- ============================================================
-- the gate just above the Fleet Strike threshold: breaks the walls in front of it (loot and all) until the gate stands,
-- then sets its HP a hair above Economy.FLEET_STRIKE_HP, so the next hit brings it under (Army.checkFleetStrike)
local Walls = require(script.Parent.Walls)
Remotes.DevGateLow.OnServerEvent:Connect(function(player)
	local plotState = PlotRegistry.getPlot(player)
	if not plotState then return end
	local guard = 0
	while plotState.wall and not Economy.isGate(plotState.wallLayer) and guard < 10 do
		guard += 1
		plotState.wallHP = 0
		Walls.breakWall(plotState)
	end
	if plotState.wall and Economy.isGate(plotState.wallLayer) then
		plotState.wallHP = plotState.WALL_MAX_HP * (Economy.FLEET_STRIKE_HP + 0.0001)
		Walls.updateWallGui(plotState)
	end
end)

-- every wall of the run including the gate (loot and all): the gate falls and ascending unlocks
Remotes.DevBreakAll.OnServerEvent:Connect(function(player)
	local plotState = PlotRegistry.getPlot(player)
	if not plotState then return end
	local guard = 0
	while plotState.wall and guard < 10 do
		guard += 1
		plotState.wallHP = 0
		Walls.breakWall(plotState)
	end
end)

-- a Fleet Strike preview (client FleetStrike.lua): the plot's army holds, then flees, Malak stays put
Remotes.DevFleetStrike.OnServerEvent:Connect(function(player, on)
	local plotState = PlotRegistry.getPlot(player)
	if not plotState then return end
	local malak
	for _, u in ipairs(plotState.activeUnits) do
		if u.unitType == "Malak" then
			malak = u
		end
	end
	Army.startFinisher(plotState, malak, 11, 54, on ~= false) -- (FleetStrike.lua: the army flees at 11 s, 54 s long)
end)

Remotes.DevFastSpecials.OnServerEvent:Connect(function(_player, fast)
	workspace:SetAttribute("DevFastSpecials", fast == true)
end)

-- ============================================================
-- Gold
-- ============================================================
Remotes.DevGiveGold.OnServerEvent:Connect(function(player, amount)
	if type(amount) ~= "number" or amount ~= amount then
		return
	end
	PlayerData.addGold(player, math.clamp(math.floor(amount), 1, 1e18))
end)

return {}
