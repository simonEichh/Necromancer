-- Shopkeeper NPC prompts (Buy / Sell / Upgrade) and the sell handler.
local Remotes = require(script.Parent.Remotes)

Remotes.SellUnit.OnServerEvent:Connect(function(player, unitType, oneIn)
	if not unitType or not oneIn then return end
	local sellValue = math.floor(oneIn ^ 1.2 * 5)
	Remotes.AddGold:FireClient(player, sellValue, unitType)
	print("💰 " .. player.Name .. " sold " .. unitType .. " for " .. sellValue .. " gold")
end)

-- Wire up Studio-placed shopkeepers
local shopsFolder = workspace:WaitForChild("Shops", 10)
if shopsFolder then
	local function wireShop(name, remote, label)
		local npc = shopsFolder:FindFirstChild(name)
		if not npc then warn("Shops." .. name .. " not found") return end
		local prompt = npc:FindFirstChildOfClass("ProximityPrompt")
		if not prompt then warn(name .. " has no ProximityPrompt") return end
		prompt.ActionText = "Talk"
		prompt.ObjectText = label
		prompt.Triggered:Connect(function(player)
			remote:FireClient(player)
		end)
		local gui = Instance.new("BillboardGui", npc)
		gui.Size = UDim2.new(0, 120, 0, 40)
		gui.StudsOffset = Vector3.new(0, 4, 0)
		gui.AlwaysOnTop = false
		local lbl = Instance.new("TextLabel", gui)
		lbl.Size = UDim2.new(1, 0, 1, 0)
		lbl.BackgroundTransparency = 1
		lbl.Text = label
		lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
		lbl.TextScaled = true
		lbl.Font = Enum.Font.GothamBold
	end
	wireShop("GraveShopkeeper",   Remotes.OpenGrave,   "Buy")
	wireShop("SellShopkeeper",    Remotes.OpenSell,    "Sell")
	wireShop("UpgradeShopkeeper", Remotes.OpenUpgrade, "Upgrade")
else
	warn("Shops folder not found in Workspace")
end

return {}
