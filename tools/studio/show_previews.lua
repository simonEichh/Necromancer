-- Puts every procedural-rig unit model on display in the plaza so you can walk up and look at it
-- without rolling the unit first. Run in Studio (Edit mode) via the Studio MCP execute_luau.
-- Safe to re-run: it replaces Workspace.ModelPreviews. The first row stands just beyond the HubSpawn
-- (the SHOPS teleport point) with the models facing it, at their in-game scale; extra rows stand behind it.
-- Models are spaced by their rough width, so big ones don't overlap their neighbours.
-- This is a temporary dev folder: delete Workspace.ModelPreviews before publishing.
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Units = require(ReplicatedStorage.Shared.Units)

local FLOOR_Y = -1.7 -- top of Workspace.HubFloor
local GAP = 0.8 -- between neighbouring models
local MAX_ROW = 56 -- a row wraps to a new one behind it when it gets wider than this
local ROW_DEPTH = 8 -- distance between rows

local old = workspace:FindFirstChild("ModelPreviews")
if old then
	old:Destroy()
end
local folder = Instance.new("Folder")
folder.Name = "ModelPreviews"

local hubSpawn = workspace:GetAttribute("HubSpawn") or Vector3.new(0, 1.3, 18)
local firstRowZ = hubSpawn.Z + 12

local names = {}
for _, m in ipairs(ServerStorage.Models:GetChildren()) do
	if m:IsA("Model") and m:GetAttribute("Rig") == "Procedural" and Units.Stats[m.Name] then
		table.insert(names, m.Name)
	end
end
table.sort(names)

local function widthOf(name)
	return 4 * (Units.Stats[name].size.X / 2) * 0.9
end

-- split the models into rows (alphabetical), each at most MAX_ROW wide
local rows, current, currentWidth = {}, {}, 0
for _, name in ipairs(names) do
	local w = widthOf(name)
	if #current > 0 and currentWidth + GAP + w > MAX_ROW then
		table.insert(rows, current)
		current, currentWidth = {}, 0
	end
	currentWidth += (#current > 0 and GAP or 0) + w
	table.insert(current, name)
end
table.insert(rows, current)

local function place(name, x, z)
	local c = ServerStorage.Models[name]:Clone()
	local scale = (Units.Stats[name].size.X / 2) * 0.9
	for _, d in ipairs(c:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
		end
	end
	c.Name = name
	c.Parent = folder
	c:ScaleTo(scale)
	-- units face -Z, so a viewer standing nearer the centre (smaller Z) sees the front
	c:PivotTo(CFrame.new(x, FLOOR_Y + c:GetAttribute("RootHeight") * scale, z))

	local anchor = Instance.new("Part")
	anchor.Name = "Label"
	anchor.Size = Vector3.new(1, 1, 1)
	anchor.Transparency = 1
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.Position = Vector3.new(x, FLOOR_Y + c:GetAttribute("Height") * scale + 1.5, z)
	anchor.Parent = c
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(160, 30)
	gui.AlwaysOnTop = false
	gui.MaxDistance = 60
	gui.Parent = anchor
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.fromScale(1, 1)
	lbl.BackgroundTransparency = 1
	lbl.Text = name
	lbl.TextColor3 = Color3.fromRGB(235, 235, 245)
	lbl.TextStrokeTransparency = 0.4
	lbl.Font = Enum.Font.GothamBold
	lbl.TextSize = 18
	lbl.Parent = gui
end

for rowIndex, rowNames in ipairs(rows) do
	local total = 0
	for i, name in ipairs(rowNames) do
		total += widthOf(name) + (i < #rowNames and GAP or 0)
	end
	local cursor = hubSpawn.X - total / 2
	local z = firstRowZ + (rowIndex - 1) * ROW_DEPTH
	for _, name in ipairs(rowNames) do
		place(name, cursor + widthOf(name) / 2, z)
		cursor += widthOf(name) + GAP
	end
end

folder.Parent = workspace
return ("ModelPreviews: %d models in %d rows: %s"):format(#names, #rows, table.concat(names, ", "))
