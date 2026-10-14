-- Moves every plot's GraveSpot1..10 (invisible markers in the place file) into two rows of 5 along the plot's sides,
-- leaving a free path down the middle from the plaza entrance past the spawn to the lane. The tombstones face the path
-- (Plots.addGraveSlot turns them by the side they stand on). Slots fill closest to the lane first, alternating left /
-- right, so the 5 graves a new player has stand near the lane.
-- Run in Edit mode via the Studio MCP execute_luau (or loadstring, see CLAUDE.md). Safe to re-run. Save the place after.
local LATERAL = 13 -- studs from the middle of the plot (the Base is 40 across; a tombstone is about 6 deep)
local ROWS = { 14, 6, -2, -10, -18 } -- forward along the lane (the plot runs from -24 at the plaza to +24 at the lane)

local moved = 0
for i = 1, 8 do
	local plot = workspace.Plots:FindFirstChild("Plot" .. i)
	local base = plot and plot:FindFirstChild("Base")
	if base then
		local frame = base.CFrame * CFrame.new(0, base.Size.Y / 2, 0) -- floor level, local -Z = down the lane
		for k = 1, 10 do
			local spot = plot:FindFirstChild("GraveSpot" .. k)
			if spot then
				local row = ROWS[math.ceil(k / 2)]
				local side = (k % 2 == 1) and -1 or 1
				local y = spot.Position.Y - frame.Position.Y -- keep the marker's height above the floor
				spot.CFrame = frame * CFrame.new(side * LATERAL, y, -row)
				moved += 1
			end
		end
	end
end
return "moved " .. moved .. " grave spots"
