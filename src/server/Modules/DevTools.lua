-- Studio-only developer tools: spawn any unit next to your wall so you can look at it (and its attack),
-- and clear those units again. Driven by the client's DevPanel. Does nothing outside Studio.
-- Dev units are not tied to graves or the inventory, so they are never saved.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

if not RunService:IsStudio() then
	return {}
end

local Remotes = require(script.Parent.Remotes)
local Army = require(script.Parent.Army)
local PlotRegistry = require(script.Parent.PlotRegistry)
local PlotFrame = require(script.Parent.PlotFrame)
local Units = require(ReplicatedStorage.Shared.Units)

local UNITS = Units.Stats
local spawned = {} -- [UserId] = how many dev units this player spawned (to spread them across the lane)

-- ============================================================
-- Spawn
-- ============================================================
-- atGraves = true: the unit starts behind the lane like a real one and marches to its formation slot;
-- otherwise it starts right next to its row in front of the wall, so it is attacking within a second or two.
Remotes.DevSpawnUnit.OnServerEvent:Connect(function(player, unitType, atGraves)
	if type(unitType) ~= "string" or not UNITS[unitType] then
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
		Army.spawnUnit(unitType, nil, plotState)
	else
		local lateral = ((n - 1) % 7 - 3) * 4.5
		local forward = plotState.wallTargetFwd - math.max(1.5, def.attackRange - 1.5)
		Army.spawnUnit(unitType, PlotFrame.toWorld(plotState, lateral, forward), plotState)
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

return {}
