-- Shopkeeper prompts (Buy / Sell / Upgrade). The anchor parts in Workspace.Shops are invisible and sit on the
-- stall counters built by tools/studio/build_hub.lua (the stalls carry their own signs).
local Remotes = require(script.Parent.Remotes)

local ShopNpcs = {}
local FORGE_RANGE = 25 -- studs from the Forge anvil within which the Forge works

-- True when the player stands at the Forge stall (upgrading and buying dust only work there).
function ShopNpcs.nearForge(player)
	local shops = workspace:FindFirstChild("Shops")
	local anchor = shops and shops:FindFirstChild("ForgeKeeper")
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not anchor then
		return true -- no stall in this place: do not lock the Forge
	end
	return root ~= nil and (root.Position - anchor.Position).Magnitude <= FORGE_RANGE
end

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
	wireShop("ForgeKeeper",       Remotes.OpenForge,   "Forge") -- stall built by tools/studio/build_forge_stall.lua
else
	warn("Shops folder not found in Workspace")
end

return ShopNpcs
