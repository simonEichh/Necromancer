-- Creates every RemoteEvent/RemoteFunction at server startup.
-- (Remotes must all exist before clients WaitForChild them.)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EVENTS = {
	-- client -> server requests
	"BuyGraveRequest",
	"BuyUpgrade",
	"ClaimQuest",
	"DevClearUnits", -- Studio-only dev tools (see DevTools / client DevPanel)
	"DevSpawnUnit",
	"DigGrave",
	"PlaceAtGrave",
	"PlaceBest",
	"PlayerAscend",
	"RequestData",
	"SellUnit",
	"SwapInventory",
	"WheelSpin",
	-- server -> client
	"AddGold", -- sell banner only; gold itself arrives via DataSync
	"BuyGraveResult",
	"DamageHit",
	"DataSync", -- full snapshot of the player's authoritative data
	"DigRejected",
	"Notice", -- short message to show the player
	"OpenGrave",
	"OpenSell",
	"OpenUpgrade",
	"QuestUpdate",
	"RollResult",
	"SelectGrave",
	"ShopStockUpdate",
	"WallBreak",
	"WheelResult",
	"WheelSpinsUpdate",
}

local Remotes = {}

for _, name in ipairs(EVENTS) do
	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = ReplicatedStorage
	Remotes[name] = remote
end

local getWallPos = Instance.new("RemoteFunction")
getWallPos.Name = "GetWallPos"
getWallPos.Parent = ReplicatedStorage
Remotes.GetWallPos = getWallPos

return Remotes
