-- Puts every procedural-rig unit model on display in the plaza so you can walk up and look at it
-- without rolling the unit first. Run in Studio (Edit mode) via the Studio MCP execute_luau.
-- Safe to re-run: it replaces Workspace.ModelPreviews. The row stands just beyond the HubSpawn
-- (the SHOPS teleport point) with the models facing it, at their in-game scale.
-- This is a temporary dev folder: delete Workspace.ModelPreviews before publishing.
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Units = require(ReplicatedStorage.Shared.Units)

local FLOOR_Y = -1.7 -- top of Workspace.HubFloor
local SPACING = 4.6

local old = workspace:FindFirstChild("ModelPreviews")
if old then
	old:Destroy()
end
local folder = Instance.new("Folder")
folder.Name = "ModelPreviews"

local hubSpawn = workspace:GetAttribute("HubSpawn") or Vector3.new(0, 1.3, 18)
local rowZ = hubSpawn.Z + 12

local names = {}
for _, m in ipairs(ServerStorage.Models:GetChildren()) do
	if m:IsA("Model") and m:GetAttribute("Rig") == "Procedural" and Units.Stats[m.Name] then
		table.insert(names, m.Name)
	end
end
table.sort(names)

for i, name in ipairs(names) do
	local c = ServerStorage.Models[name]:Clone()
	local def = Units.Stats[name]
	local scale = (def.size.X / 2) * 0.9
	for _, d in ipairs(c:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
		end
	end
	c.Name = name
	c.Parent = folder
	c:ScaleTo(scale)
	local x = (i - (#names + 1) / 2) * SPACING
	-- units face -Z, so a viewer standing nearer the centre (smaller Z) sees the front
	c:PivotTo(CFrame.new(hubSpawn.X + x, FLOOR_Y + c:GetAttribute("RootHeight") * scale, rowZ))

	local anchor = Instance.new("Part")
	anchor.Name = "Label"
	anchor.Size = Vector3.new(1, 1, 1)
	anchor.Transparency = 1
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.Position = Vector3.new(hubSpawn.X + x, FLOOR_Y + c:GetAttribute("Height") * scale + 1.5, rowZ)
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

folder.Parent = workspace
return "ModelPreviews: " .. table.concat(names, ", ")
