-- Per-player grave shop stock rotation and purchases. Also holds the dust shop's stock (the Forge's Buy Dust tab, bought
-- in UnitUpgrades): it refills with the same 5-minute rotation.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(script.Parent.Remotes)
local PlayerData = require(script.Parent.PlayerData)
local Graves = require(ReplicatedStorage.Shared.Graves)
local Economy = require(ReplicatedStorage.Shared.Economy)

-- Tuned with tools/sim/economy_sim.py: cheap graves are limited too, so pulls come from gold earned, not from spam.
local GRAVE_STOCK_BASE = {
	Mossy = 40, Stone = 25, Ancient = 20, Cursed = 15,
	Shadow = 12, Abyssal = 8, Eldritch = 5,
	Void = 3, Eternal = 2, Celestial = 1,
}
local GRAVE_ROTATION_CHANCE = {
	Mossy = 1.0, Stone = 0.9, Ancient = 0.8, Cursed = 0.7,
	Shadow = 0.6, Abyssal = 0.5, Eldritch = 0.4,
	Void = 0.3, Eternal = 0.2, Celestial = 0.1,
}
local SHOP_RESTOCK_TIME = 300
local playerShopData = {}

local function generateRotation(player)
	local id = tostring(player.UserId)
	local stock, inRotation = {}, {}
	for key, baseStock in pairs(GRAVE_STOCK_BASE) do
		local chance = GRAVE_ROTATION_CHANCE[key] or 1
		if math.random() <= chance then
			stock[key] = baseStock
			inRotation[key] = true
		else
			stock[key] = 0
			inRotation[key] = false
		end
	end
	local dustStock = {}
	for _, dust in ipairs(Economy.DUSTS) do
		dustStock[dust] = Economy.DUST_SHOP_STOCK
	end
	playerShopData[id] = {
		stock = stock,
		inRotation = inRotation,
		dustStock = dustStock,
		nextRestock = tick() + SHOP_RESTOCK_TIME,
	}
end

local function sendShopUpdate(player)
	local id = tostring(player.UserId)
	local data = playerShopData[id]
	if not data then return end
	local secsLeft = math.max(0, math.floor(data.nextRestock - tick()))
	Remotes.ShopStockUpdate:FireClient(player, data.stock, data.inRotation, secsLeft)
	Remotes.DustStockUpdate:FireClient(player, data.dustStock, secsLeft)
end

-- the dust shop's stock table of a player (nil before their first rotation)
local function dustStock(player)
	local data = playerShopData[tostring(player.UserId)]
	return data and data.dustStock
end
local function sendDustStock(player)
	local data = playerShopData[tostring(player.UserId)]
	if data then
		Remotes.DustStockUpdate:FireClient(player, data.dustStock, math.max(0, math.floor(data.nextRestock - tick())))
	end
end

Remotes.BuyGraveRequest.OnServerEvent:Connect(function(player, graveType, qty)
	if type(graveType) ~= "string" or type(qty) ~= "number" or qty ~= qty then return end
	local profile = PlayerData.get(player)
	local grave = Graves[graveType]
	local data = playerShopData[tostring(player.UserId)]
	if not profile or not grave or not data or not data.inRotation[graveType] then return end
	if profile.rebirthCount < grave.unlockAscension then return end -- tier not unlocked yet
	local available = data.stock[graveType] or 0
	local affordable = math.floor(profile.gold / grave.cost)
	local approved = math.min(math.floor(math.min(qty, available)), affordable)
	if approved <= 0 then return end
	if not PlayerData.spendGold(player, grave.cost * approved) then return end
	PlayerData.addGraves(player, graveType, approved)
	data.stock[graveType] = available - approved
	Remotes.BuyGraveResult:FireClient(player, graveType, approved, data.stock[graveType])
end)

-- Restocks when the rotation timer has elapsed; call periodically.
local function update(p, now)
	local sd = playerShopData[tostring(p.UserId)]
	if sd and now >= sd.nextRestock then
		generateRotation(p)
		sendShopUpdate(p)
	end
end

local function remove(player)
	playerShopData[tostring(player.UserId)] = nil
end

return {
	generateRotation = generateRotation,
	sendShopUpdate = sendShopUpdate,
	update = update,
	remove = remove,
	dustStock = dustStock,
	sendDustStock = sendDustStock,
}
