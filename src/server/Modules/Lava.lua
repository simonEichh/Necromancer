-- The lava sea round the lanes (Workspace.Lava.Surface, built by tools/studio/build_lava.lua): a player who touches it
-- burns for a moment and is sent back to their plot (or to the plaza if they have none). No damage, no death.
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")
local Remotes = require(script.Parent.Remotes)
local PlotRegistry = require(script.Parent.PlotRegistry)

local COOLDOWN = 2 -- seconds before the same player can be sent back again
local lastSent = {}

local function spawnFor(player)
	local plotState = PlotRegistry.playerPlots[tostring(player.UserId)]
	local spawnPart = plotState and plotState.plotModel and plotState.plotModel:FindFirstChild("PlayerSpawn")
	if spawnPart then
		return spawnPart.CFrame + Vector3.new(0, 4, 0)
	end
	return CFrame.new(workspace:GetAttribute("HubSpawn") or Vector3.new(0, 3, 24))
end

local function burn(character)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	local fire = Instance.new("Fire")
	fire.Color = Color3.fromRGB(255, 120, 40)
	fire.SecondaryColor = Color3.fromRGB(255, 60, 20)
	fire.Size = 6
	fire.Heat = 12
	fire.Parent = root
	Debris:AddItem(fire, 1.5)
end

local function onTouched(hit)
	local character = hit.Parent
	local player = character and Players:GetPlayerFromCharacter(character)
	if not player then return end
	local now = os.clock()
	if now - (lastSent[player] or 0) < COOLDOWN then return end
	lastSent[player] = now
	burn(character)
	character:PivotTo(spawnFor(player))
	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		root.AssemblyLinearVelocity = Vector3.zero
	end
	Remotes.Notice:FireClient(player, "The lava burns you back to your plot.")
end

task.spawn(function()
	local lava = workspace:WaitForChild("Lava", 30)
	local surface = lava and lava:WaitForChild("Surface", 10)
	if surface then
		surface.Touched:Connect(onTouched)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	lastSent[player] = nil
end)

return {}
