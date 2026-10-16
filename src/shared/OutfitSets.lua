-- The Outfit of the Day (Design.md "The Soul Broker"): themed outfit SETS, one Head + Back + Hand piece each (keys of
-- shared Items). One set is offered per day, the same for everyone (picked from the clock: a new one at 00:00 UTC), worn
-- by the mannequin at the Soul Broker's stall and sold in the Gem Shop's Outfit tab: every piece for its gem price, or
-- the whole set for SET_DISCOUNT of the pieces still missing.
-- Only sets whose pieces all exist in Items.Defs AND have a model in ReplicatedStorage.ItemModels are ever offered, so
-- nothing unwearable is sold. The collection is added later; until then Studio offers the TEST_SETS.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Items = require(ReplicatedStorage.Shared.Items)

local OutfitSets = {}

OutfitSets.ROTATION = 86400 -- a new outfit every day (00:00 UTC)
OutfitSets.SET_DISCOUNT = 0.8 -- the full set costs 80 % of the pieces still missing
OutfitSets.PIECE_PRICE = 150 -- Gems per piece unless its Items.Defs entry has a `price`

-- The collection (add sets here once their items are built: Items.Defs entries + build_item_<key>.lua models)
OutfitSets.SETS = {
	-- PlagueDoctor = { name = "Plague Doctor", pieces = { Head = "PlagueMask", Back = "PlagueCloak", Hand = "PlagueCane" } },
}

-- Offered in Studio only while SETS has nothing to offer (the starter pieces, so the system can be tested)
OutfitSets.TEST_SETS = {
	Gravedigger = { name = "Gravedigger (test)", pieces = { Head = "GravediggerHood", Back = "TatteredCape", Hand = "LanternStaff" } },
}

function OutfitSets.day(now)
	return math.floor(now / OutfitSets.ROTATION)
end

function OutfitSets.secondsLeft(now)
	return OutfitSets.ROTATION - now % OutfitSets.ROTATION
end

local function wearable(set)
	local models = ReplicatedStorage:FindFirstChild("ItemModels")
	for _, slot in ipairs(Items.SLOTS) do
		local key = set.pieces[slot]
		if not (key and Items.Defs[key] and models and models:FindFirstChild(key)) then
			return false
		end
	end
	return true
end

-- the keys of the sets that can be offered, in a fixed order
function OutfitSets.pool()
	local keys = {}
	for key, set in pairs(OutfitSets.SETS) do
		if wearable(set) then table.insert(keys, key) end
	end
	if #keys == 0 and RunService:IsStudio() then
		for key, set in pairs(OutfitSets.TEST_SETS) do
			if wearable(set) then table.insert(keys, key) end
		end
	end
	table.sort(keys)
	return keys
end

function OutfitSets.get(key)
	return OutfitSets.SETS[key] or OutfitSets.TEST_SETS[key]
end

-- today's set: key, set (nil when nothing can be offered)
function OutfitSets.today(now)
	local pool = OutfitSets.pool()
	if #pool == 0 then return nil end
	local key = pool[Random.new(OutfitSets.day(now) * 53 + 7):NextInteger(1, #pool)]
	return key, OutfitSets.get(key)
end

function OutfitSets.piecePrice(itemKey)
	local def = Items.Defs[itemKey]
	return def and def.price or OutfitSets.PIECE_PRICE
end

-- the full set's price for someone who owns `owned` ([itemKey] = true); nil when nothing is missing
function OutfitSets.setPrice(set, owned)
	local sum = 0
	for _, slot in ipairs(Items.SLOTS) do
		local key = set.pieces[slot]
		if not owned[key] then sum += OutfitSets.piecePrice(key) end
	end
	if sum == 0 then return nil end
	return math.floor(sum * OutfitSets.SET_DISCOUNT)
end

return OutfitSets
