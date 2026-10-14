-- Puts two R15 dummies wearing every outfit item (ReplicatedStorage.ItemModels) behind the hub spawn
-- (Workspace.ItemPreview): one faces the camera side (-Z), one shows its back. Dev-only: delete the folder before
-- publishing; re-run it after changing an item.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local old = workspace:FindFirstChild("ItemPreview")
if old then
	old:Destroy()
end
local folder = Instance.new("Folder")
folder.Name = "ItemPreview"
folder.Parent = workspace

local FLOOR_Y = -1.7
for i, turn in { 0, 180 } do
	local desc = Instance.new("HumanoidDescription")
	local skin = Color3.fromRGB(204, 160, 130)
	desc.HeadColor, desc.TorsoColor, desc.LeftArmColor, desc.RightArmColor = skin, Color3.fromRGB(90, 70, 60), skin, skin
	desc.LeftLegColor, desc.RightLegColor = Color3.fromRGB(60, 56, 64), Color3.fromRGB(60, 56, 64)
	local rig = Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
	rig.Name = "ItemDummy" .. i
	local hum = rig:FindFirstChildOfClass("Humanoid")
	local hrp = rig:FindFirstChild("HumanoidRootPart")
	hrp.Anchored = true
	local rootY = FLOOR_Y + hum.HipHeight + hrp.Size.Y / 2
	rig:PivotTo(CFrame.new((i - 1.5) * 6, rootY, 40) * CFrame.Angles(0, math.rad(turn), 0))
	rig.Parent = folder
	for _, item in ReplicatedStorage.ItemModels:GetChildren() do
		hum:AddAccessory(item:Clone())
	end
end
return "ItemPreview built"
