-- The Soul Broker's portrait deals (the gem stall in the plaza, Design.md "The Soul Broker").
-- The deals are GLOBAL: every server and client computes the same ones from the clock (one rotation per ROTATION
-- seconds, `BrokerDeals.rotation(now)`); amounts and tiers scale to the player (`BrokerDeals.offer`), like the wheel.
-- Four portraits, each draws one deal from its own pool per rotation. Stock is per player per rotation (server Broker).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Graves = require(ReplicatedStorage.Shared.Graves)
local Economy = require(ReplicatedStorage.Shared.Economy)
local Units = require(ReplicatedStorage.Shared.Units)
local Rarities = require(ReplicatedStorage.Shared.Rarities)

local BrokerDeals = {}

BrokerDeals.ROTATION = 3600 -- seconds per rotation (on the hour)

BrokerDeals.PORTRAITS = {
	{ key = "Bundle", pool = { "FortuneBundle", "WardingBundle", "DustBundle" } },
	{ key = "Potion", pool = { "Potion1", "Potion3" } },
	{ key = "Featured", pool = { "FeaturedUnit" } }, -- the big centre frame
	{ key = "Curio", pool = { "GrandDust", "SeekerKit" } }, -- (exclusive cosmetics join this pool once they exist)
}

-- price in Gems, stock = how many times a player can buy it per rotation, worth = what it would cost without the deal
-- (shop prices; potions count 30 Gems each, dust 2.5 Gems a piece): the portraits show the saving as "-20%"
BrokerDeals.DEALS = {
	FortuneBundle = { name = "Fortune Bundle", price = 120, worth = 150, stock = 2, catalyst = "Fortune", catalystCount = 5 },
	WardingBundle = { name = "Warding Bundle", price = 80, worth = 100, stock = 2, catalyst = "Warding", catalystCount = 5 },
	DustBundle = { name = "Dust Bundle", price = 40, worth = 50, stock = 2, dustCount = 20 },
	Potion1 = { name = "Luck Potion", price = 25, worth = 30, stock = 3, potions = 1 },
	Potion3 = { name = "Three Luck Potions", price = 60, worth = 90, stock = 1, potions = 3 },
	FeaturedUnit = { name = "Featured Unit", stock = 1, unit = true },
	GrandDust = { name = "Grand Dust Hoard", price = 150, worth = 200, stock = 1, dustCount = 80 },
	SeekerKit = { name = "Seeker's Kit", price = 100, worth = 120, stock = 1, potions = 2, catalyst = "Fortune", catalystCount = 2 },
}

-- Gem price of the featured unit by rarity rank (Rare 3 .. Primordial 9): dearer per unit than digging, the draw is
-- getting the one you are missing
BrokerDeals.UNIT_PRICE = { [3] = 40, [4] = 70, [5] = 120, [6] = 200, [7] = 350, [8] = 600, [9] = 1000 }

function BrokerDeals.rotation(now)
	return math.floor(now / BrokerDeals.ROTATION)
end

function BrokerDeals.secondsLeft(now)
	return BrokerDeals.ROTATION - now % BrokerDeals.ROTATION
end

-- The deal key each portrait shows in rotation `rot` (the same everywhere)
function BrokerDeals.dealKey(rot, portrait)
	local pool = BrokerDeals.PORTRAITS[portrait].pool
	return pool[Random.new(rot * 31 + portrait):NextInteger(1, #pool)]
end

local function topGrave(ascension)
	local key, grave = "Mossy", Graves.Mossy
	for k, def in pairs(Graves) do
		if def.unlockAscension <= ascension and def.unlockAscension > grave.unlockAscension then
			key, grave = k, def
		end
	end
	return key, grave
end

local function topDust(ascension)
	local dust = Economy.DUSTS[1]
	for i, key in ipairs(Economy.DUSTS) do
		if ascension >= Economy.dustShopUnlock(i) then dust = key end
	end
	return dust
end

-- The featured unit for this rotation and ascension: one rarity above the pity rarity of the highest unlocked grave,
-- never a Signature or Sovereign, picked by weight with the rotation as the seed
local function featuredUnit(rot, ascension)
	local graveKey, grave = topGrave(ascension)
	local rank = math.min((Rarities.Rank[grave.pityRarity] or 3) + 1, 9)
	for r = rank, 1, -1 do
		local rarity
		for name, k in pairs(Rarities.Rank) do
			if k == r then rarity = name end
		end
		local entries, total = {}, 0
		for _, e in ipairs(Units.Pools[rarity] or {}) do
			if not Units.isSignature(e.unit) and not Units.isSovereign(e.unit) and (not e.graves or e.graves[graveKey]) then
				table.insert(entries, e)
				total += e.weight
			end
		end
		if total > 0 then
			local pick = Random.new(rot * 97 + r):NextNumber() * total
			for _, e in ipairs(entries) do
				pick -= e.weight
				if pick <= 0 then return e.unit, rarity, r end
			end
			return entries[#entries].unit, rarity, r
		end
	end
end

-- What portrait `portrait` offers THIS player in rotation `rot`: { key, name, price, stock, catalyst?, catalystCount?,
-- dust?, dustCount?, potions?, unitType?, rarity? }
function BrokerDeals.offer(rot, portrait, ascension)
	local key = BrokerDeals.dealKey(rot, portrait)
	local def = BrokerDeals.DEALS[key]
	local o = table.clone(def)
	o.key = key
	if def.dustCount then
		o.dust = topDust(ascension)
	end
	if def.unit then
		local unitType, rarity, rank = featuredUnit(rot, ascension)
		o.unitType, o.rarity = unitType, rarity
		o.price = BrokerDeals.UNIT_PRICE[rank] or 40
		o.name = unitType:gsub("(%l)(%u)", "%1 %2") -- "LichAcolyte" -> "Lich Acolyte"
	end
	return o
end

-- The saving in whole percent (20 for "-20%"), or nil when the deal has no normal price (the featured unit)
function BrokerDeals.discount(o)
	if not o.worth or o.worth <= o.price then return nil end
	return math.floor((1 - o.price / o.worth) * 100 + 0.5)
end

-- One line of what the offer contains
function BrokerDeals.describe(o)
	local parts = {}
	if o.unitType then table.insert(parts, o.rarity .. " unit, straight to your inventory") end
	if o.catalyst then table.insert(parts, o.catalystCount .. " " .. Economy.CATALYST_INFO[o.catalyst].name .. "s") end
	if o.dust then table.insert(parts, o.dustCount .. " " .. Economy.DUST_NAMES[o.dust]) end
	if o.potions then table.insert(parts, o.potions .. (o.potions == 1 and " Luck Potion" or " Luck Potions") .. " (2x luck, 5 min)") end
	return table.concat(parts, " + ")
end

return BrokerDeals
