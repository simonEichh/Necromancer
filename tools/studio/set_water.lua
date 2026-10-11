-- Terrain water look (dusk teal). Terrain properties live in the place file, not in default.project.json.
-- Run in Studio's command bar / via the Studio MCP execute_luau (Edit mode).
local T = workspace.Terrain
T.WaterColor = Color3.fromRGB(30, 78, 100)
T.WaterTransparency = 0.45
T.WaterReflectance = 0.6
T.WaterWaveSize = 0.12
T.WaterWaveSpeed = 7
return "water set"
