-- Geometry helpers for a plot. Every plot has a frame (plotState.frame): a CFrame at the centre of the
-- plot's floor whose LookVector is the lane direction (outward, away from the hub plaza) and whose
-- RightVector points across the lane. All lane math goes through these helpers so plots can be rotated
-- freely around the plaza.
--   forward: studs along the lane, 0 = plot centre, positive = towards the walls
--   lateral: studs across the lane, positive = to the right
local PlotFrame = {}

function PlotFrame.toWorld(plotState, lateral, forward)
	local frame = plotState.frame
	return frame.Position + frame.RightVector * lateral + frame.LookVector * forward
end

-- Returns lateral, forward for a world position
function PlotFrame.toLocal(plotState, worldPos)
	local frame = plotState.frame
	local d = worldPos - frame.Position
	return d:Dot(frame.RightVector), d:Dot(frame.LookVector)
end

-- The frame's orientation only (no position)
function PlotFrame.rotation(plotState)
	return plotState.frame - plotState.frame.Position
end

-- Lane direction flattened onto the ground plane
function PlotFrame.forwardFlat(plotState)
	local look = plotState.frame.LookVector
	return Vector3.new(look.X, 0, look.Z).Unit
end

return PlotFrame
