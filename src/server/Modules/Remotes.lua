-- Creates every RemoteEvent/RemoteFunction at server startup.
-- (Remotes must all exist before clients WaitForChild them.)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EVENTS = {
	"AddGems",
	"AddGold",
	"BuyGraveRequest",
	"BuyGraveResult",
	"BuyUpgrade",
	"ClaimQuest",
	"DamageHit",
	"DeployUnit",
	"DigGrave",
	"OpenGrave",
	"OpenSell",
	"OpenUpgrade",
	"PlaceAtGrave",
	"PlaceBest",
	"PlaceBestResult",
	"PlayerAscend",
	"QuestUpdate",
	"RecallUnit",
	"RollResult",
	"SelectGrave",
	"SellUnit",
	"ShopStockUpdate",
	"SpendGold",
	"SummonUnit",
	"UndeployUnit",
	"UpgradeGranted",
	"WallBreak",
	"WheelResult",
	"WheelSpin",
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
