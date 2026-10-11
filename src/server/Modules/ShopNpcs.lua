-- Shopkeeper prompts (Buy / Sell / Upgrade). The anchor parts in Workspace.Shops are invisible and sit on the
-- stall counters built by tools/studio/build_hub.lua (the stalls carry their own signs).
local Remotes = require(script.Parent.Remotes)

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
		prompt.RequiresLineOfSight = false -- the anchor sits behind the stall counter
		prompt.MaxActivationDistance = 12
		prompt.Triggered:Connect(function(player)
			remote:FireClient(player)
		end)
	end
	wireShop("GraveShopkeeper",   Remotes.OpenGrave,   "Buy")
	wireShop("SellShopkeeper",    Remotes.OpenSell,    "Sell")
	wireShop("UpgradeShopkeeper", Remotes.OpenUpgrade, "Upgrade")
else
	warn("Shops folder not found in Workspace")
end

return {}
