-- Copies every unit model from ServerStorage.Models into ReplicatedStorage.UnitModels so the CLIENT can show them
-- (3D portraits in ViewportFrames: the gacha reveal, the inventory ...). ServerStorage is not replicated to clients.
-- Run in Studio's command bar / via the Studio MCP execute_luau (Edit mode). Safe to re-run: it replaces the folder.
-- Re-run it after changing or adding a unit model, and save the place. The Tombstone and *_Old models are skipped.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local old = ReplicatedStorage:FindFirstChild("UnitModels")
if old then
	old:Destroy()
end
local folder = Instance.new("Folder")
folder.Name = "UnitModels"

local count = 0
for _, model in ipairs(ServerStorage.Models:GetChildren()) do
	if model:IsA("Model") and model.Name ~= "Tombstone" and not model.Name:find("_Old$") then
		local copy = model:Clone()
		for _, d in ipairs(copy:GetDescendants()) do
			if d:IsA("BaseScript") then
				d:Destroy()
			elseif d:IsA("BasePart") then
				d.Anchored = true -- portraits never simulate
			end
		end
		copy.Parent = folder
		count += 1
	end
end
folder.Parent = ReplicatedStorage
return "UnitModels: " .. count .. " models"
