-- Collision groups: units walk through tombstones (and so can start from either grave column),
-- while players still bump into them.
local PhysicsService = game:GetService("PhysicsService")

local UNITS = "Units"
local GRAVES = "Graves"

for _, name in ipairs({ UNITS, GRAVES }) do
	if not PhysicsService:IsCollisionGroupRegistered(name) then
		PhysicsService:RegisterCollisionGroup(name)
	end
end
PhysicsService:CollisionGroupSetCollidable(UNITS, GRAVES, false)

return {
	UNITS = UNITS,
	GRAVES = GRAVES,
}
