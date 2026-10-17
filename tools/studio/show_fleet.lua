-- Stages a review preview of ReplicatedStorage.ShipModels.BlackwakeFleet in Workspace.FleetPreview (Edit mode): the
-- ships in a row high over the plaza, broadside to the plaza centre. Safe to re-run (replaces the folder). Delete
-- Workspace.FleetPreview before publishing.
local fleet = game:GetService("ReplicatedStorage").ShipModels.BlackwakeFleet
local HEIGHT = 90
local GAP = 230

local old = workspace:FindFirstChild("FleetPreview")
if old then
	old:Destroy()
end
local folder = Instance.new("Folder")
folder.Name = "FleetPreview"
local ships = fleet:GetChildren()
table.sort(ships, function(a, b)
	return a.Name < b.Name
end)
for i, ship in ipairs(ships) do
	local c = ship:Clone()
	-- (turned so the bow points +X: the starboard broadside faces -Z, towards the plaza centre at z = 0 below)
	c:PivotTo(CFrame.new((i - (#ships + 1) / 2) * GAP, HEIGHT, 120) * CFrame.Angles(0, math.pi / 2, 0))
	c.Parent = folder
end
folder.Parent = workspace
return "FleetPreview: " .. #ships .. " ships"
