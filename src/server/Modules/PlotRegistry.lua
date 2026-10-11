-- Shared per-player plot state, kept separate so modules can look up plots without circular requires.
local playerPlots = {} -- [userId string] = plotState

local function getPlot(player)
	return playerPlots[tostring(player.UserId)]
end

return {
	playerPlots = playerPlots,
	getPlot = getPlot,
}
