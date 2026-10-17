-- Stages a review preview of ServerStorage.Models.Orvoss in Workspace.OrvossPreview (Edit mode), with Malak and Veyr
-- beside him for scale when COMPARE is true. Safe to re-run: it replaces the folder. Only the clones' roots are
-- anchored. Delete Workspace.OrvossPreview before publishing.
local ServerStorage = game:GetService("ServerStorage")

local COMPARE = false
local FLOOR_Y = -1.7 -- top of Workspace.HubFloor
local SPOT = Vector3.new(0, FLOOR_Y, 16) -- on the plaza, facing -Z (towards the plaza centre)

local old = workspace:FindFirstChild("OrvossPreview")
if old then
	old:Destroy()
end
local folder = Instance.new("Folder")
folder.Name = "OrvossPreview"

local function stage(name, offsetX)
	local src = ServerStorage.Models:FindFirstChild(name)
	if not src then
		return nil
	end
	local c = src:Clone()
	c.Name = name .. "Preview"
	c:PivotTo(CFrame.new(SPOT + Vector3.new(offsetX, c:GetAttribute("RootHeight") or 0, 0)))
	c.PrimaryPart.Anchored = true
	c.Parent = folder
	return c
end

stage("Orvoss", 0)
if COMPARE then
	stage("Malak", -5)
	stage("Veyr", 5.5)
end
folder.Parent = workspace
return "OrvossPreview at " .. tostring(SPOT)
