-- Collision groups: units walk through tombstones (and so can start from either grave column),
-- while players still bump into them.
local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")

local UNITS = "Units"
local GRAVES = "Graves"
local DEBRIS = "Debris"
local PLAYERS = "Players"
local DECOR = "Decor"

for _, name in ipairs({ UNITS, GRAVES, DEBRIS, PLAYERS, DECOR }) do
	if not PhysicsService:IsCollisionGroupRegistered(name) then
		PhysicsService:RegisterCollisionGroup(name)
	end
end
PhysicsService:CollisionGroupSetCollidable(UNITS, GRAVES, false)
-- units never block or stack on each other (they overlap a little when crowded, but nothing gets stuck)
PhysicsService:CollisionGroupSetCollidable(UNITS, UNITS, false)
-- wall rubble falls on the floor but never bumps units, tombstones or other rubble
PhysicsService:CollisionGroupSetCollidable(DEBRIS, UNITS, false)
PhysicsService:CollisionGroupSetCollidable(DEBRIS, GRAVES, false)
PhysicsService:CollisionGroupSetCollidable(DEBRIS, DEBRIS, false)
-- a player standing in a lane must not block the units (or get pushed by rubble)
PhysicsService:CollisionGroupSetCollidable(PLAYERS, UNITS, false)
PhysicsService:CollisionGroupSetCollidable(PLAYERS, DEBRIS, false)
-- thin floor decoration (spawn pad, rune, grass/mud patches) is a 0.1-0.2 stud ledge that would catch the
-- unit blocks like a wall: units ignore it, players can still walk on it
PhysicsService:CollisionGroupSetCollidable(DECOR, UNITS, false)
PhysicsService:CollisionGroupSetCollidable(DECOR, DEBRIS, false)

local FLOOR_DECOR = { SpawnRing = true, SpawnDisc = true, SpawnRune = true, GraveMud = true, GraveGrass = true, PlayerSpawn = true }
local plots = workspace:WaitForChild("Plots", 10)
if plots then
	for _, d in ipairs(plots:GetDescendants()) do
		if d:IsA("BasePart") and FLOOR_DECOR[d.Name] then
			d.CollisionGroup = DECOR
		end
	end
end

local function setCharacterGroup(character)
	for _, d in ipairs(character:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CollisionGroup = PLAYERS
		end
	end
	character.DescendantAdded:Connect(function(d)
		if d:IsA("BasePart") then
			d.CollisionGroup = PLAYERS
		end
	end)
end

local function onPlayer(player)
	player.CharacterAdded:Connect(setCharacterGroup)
	if player.Character then
		setCharacterGroup(player.Character)
	end
end
Players.PlayerAdded:Connect(onPlayer)
for _, player in ipairs(Players:GetPlayers()) do
	onPlayer(player)
end

return {
	UNITS = UNITS,
	GRAVES = GRAVES,
	DEBRIS = DEBRIS,
	PLAYERS = PLAYERS,
	DECOR = DECOR,
}
