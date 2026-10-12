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
Remotes.DevSpawnUnit.OnServerEvent:Connect(function(player, unitType)
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

	-- spread across the lane and start inside the unit's attack range, so it attacks the wall right away
	local lateral = ((n - 1) % 7 - 3) * 4.5
	local forward = plotState.wallTargetFwd - math.min(def.attackRange * 0.6, 20)
	Army.spawnUnit(unitType, PlotFrame.toWorld(plotState, lateral, forward), plotState)

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
