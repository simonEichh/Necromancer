-- ============================================================
--  NECRO BUDDIES — Server bootstrap
--  Wires the server modules together (see src/server/Modules).
-- ============================================================

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Modules = script.Modules

-- Remotes must exist before anything else (clients WaitForChild them).
require(Modules.Remotes)

local PlayerData = require(Modules.PlayerData)
local PlotRegistry = require(Modules.PlotRegistry)
local Quests = require(Modules.Quests)
local Rolling = require(Modules.Rolling)
local Wheel = require(Modules.Wheel)
local GraveShop = require(Modules.GraveShop)
local Walls = require(Modules.Walls)
local Army = require(Modules.Army)
local Plots = require(Modules.Plots)
local Persistence = require(Modules.Persistence)
require(Modules.Upgrades)
require(Modules.Inventory)
require(Modules.UnitUpgrades)
require(Modules.ShopNpcs)
require(Modules.Digging)
require(Modules.DevTools)

local playerPlots = PlotRegistry.playerPlots

-- ============================================================
--  PLAYER LIFECYCLE
-- ============================================================
Players.PlayerAdded:Connect(function(player)
	Wheel.onPlayerAdded(player)
	task.spawn(function()
		-- Load saved data (yields), then wait for the character before assigning a plot
		if not Persistence.load(player) then
			return
		end
		if not player.Character then
			player.CharacterAdded:Wait()
		end
		task.wait(1)
		Plots.initPlotForPlayer(player)
		Persistence.restorePlaced(player)
		GraveShop.generateRotation(player)
		GraveShop.sendShopUpdate(player)
		Quests.sendUpdate(player)
		PlayerData.sync(player)
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	Persistence.save(player) -- before the plot is torn down (the saved data includes placed units)
	Plots.releasePlot(player)
	Wheel.remove(player)
	Rolling.remove(player)
	GraveShop.remove(player)
	Quests.remove(player)
	PlayerData.remove(player)
end)

Persistence.startAutosave()
Persistence.bindToClose()

-- ============================================================
--  MAIN LOOP
-- ============================================================
local lastRegen = tick()
local lastSpinCheck = tick()

RunService.Heartbeat:Connect(function(dt)
	local now = tick()

	-- Wall regen
	if now - lastRegen >= 1 then
		lastRegen = now
		for _, plotState in pairs(playerPlots) do
			Walls.regen(plotState)
		end
	end

	-- Spin grants, shop restocks, quest resets
	if now - lastSpinCheck >= 10 then
		lastSpinCheck = now
		for _, p in ipairs(Players:GetPlayers()) do
			Wheel.grantTick(p, now)
			GraveShop.update(p, now)
			Quests.checkReset(p)
		end
	end

	Quests.tickPlaytime(dt)
	Army.update(now, dt)
end)
