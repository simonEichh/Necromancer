-- Collision groups: units walk through tombstones (and so can start from either grave column),
-- while players still bump into them.
local PhysicsService = game:GetService("PhysicsService")

local UNITS = "Units"
local GRAVES = "Graves"
local DEBRIS = "Debris"

for _, name in ipairs({ UNITS, GRAVES, DEBRIS }) do
	if not PhysicsService:IsCollisionGroupRegistered(name) then
		PhysicsService:RegisterCollisionGroup(name)
	end
end
PhysicsService:CollisionGroupSetCollidable(UNITS, GRAVES, false)
-- wall rubble falls on the floor but never bumps units, tombstones or other rubble
PhysicsService:CollisionGroupSetCollidable(DEBRIS, UNITS, false)
PhysicsService:CollisionGroupSetCollidable(DEBRIS, GRAVES, false)
PhysicsService:CollisionGroupSetCollidable(DEBRIS, DEBRIS, false)

return {
	UNITS = UNITS,
	GRAVES = GRAVES,
	DEBRIS = DEBRIS,
}
