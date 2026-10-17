-- Who owns the camera right now (docs/veyr.md): the finishers (FleetStrike, VeyrFinisher) claim it before they take
-- the camera over and release it when they give it back, so two of them never fight over one camera. A cinematic that
-- cannot claim it still plays its world part (it just does not take the camera; spectators may Watch later).
--
--   if CinematicGuard.claim("FinalHorizon") then ... end
--   CinematicGuard.release("FinalHorizon")
local CinematicGuard = {}

local owner = nil

function CinematicGuard.claim(name)
	if owner ~= nil and owner ~= name then
		return false
	end
	owner = name
	return true
end

function CinematicGuard.release(name)
	if owner == name then
		owner = nil
	end
end

function CinematicGuard.owner()
	return owner
end

return CinematicGuard
