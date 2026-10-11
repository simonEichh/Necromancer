-- Per-player grave shop stock rotation and purchases.
local Remotes = require(script.Parent.Remotes)

local GRAVE_STOCK_BASE = {
	Mossy = 999, Stone = 50, Ancient = 30, Cursed = 20,
	Shadow = 15, Abyssal = 10, Eldritch = 5,
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
	playerShopData[id] = {
		stock = stock,
		inRotation = inRotation,
		nextRestock = tick() + SHOP_RESTOCK_TIME,
	}
end

local function sendShopUpdate(player)
	local id = tostring(player.UserId)
	local data = playerShopData[id]
	if not data then return end
	local secsLeft = math.max(0, math.floor(data.nextRestock - tick()))
	Remotes.ShopStockUpdate:FireClient(player, data.stock, data.inRotation, secsLeft)
end

Remotes.BuyGraveRequest.OnServerEvent:Connect(function(player, graveType, qty)
	if type(graveType) ~= "string" or type(qty) ~= "number" then return end
	local id = tostring(player.UserId)
	local data = playerShopData[id]
	if not data or not data.inRotation[graveType] then return end
	local available = data.stock[graveType] or 0
	local approved = math.min(math.floor(qty), available)
	if approved <= 0 then return end
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
}
