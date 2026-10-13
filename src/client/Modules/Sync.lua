-- Mirrors the server's authoritative player data (gold, gems, inventory, graves, upgrades,
-- ascension) into State and refreshes the UI. The client never changes these values itself.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local State = require(script.Parent.State)
local GameData = require(script.Parent.GameData)
local Toolbar = require(script.Parent.Toolbar)
local InventoryPanel = require(script.Parent.InventoryPanel)
local GravesDock = require(script.Parent.GravesDock)
local ShopPanel = require(script.Parent.ShopPanel)
local HUD = require(script.Parent.HUD)

local HOLD_TIMEOUT = 10 -- never keep UI updates held back longer than this

local Sync = {}

local listeners = {} -- called as fn(ascended) after a snapshot has been applied
local started = false
local held = false
local holdUntil = 0
local pending = nil -- latest snapshot received while started == false or held == true
local lastRebirth = nil

-- Registers a function to run after every applied snapshot. It receives `true` if the player just ascended.
function Sync.onApplied(fn)
	table.insert(listeners, fn)
end

local function apply(snap)
	State.gold = snap.gold
	State.gems = snap.gems
	State.rebirthCount = snap.rebirthCount
	State.gateCleared = snap.gateCleared == true
	State.goldMultiplier = snap.goldMultiplier
	State.luckBoostLevel = snap.luckBoostLevel
	State.coinBoostLevel = snap.coinBoostLevel

	-- Other modules hold references to these tables, so update them in place
	for graveType in pairs(State.ownedGraves) do
		State.ownedGraves[graveType] = snap.ownedGraves[graveType] or 0
	end
	table.clear(State.inventory)
	for _, entry in ipairs(snap.inventory) do
		State.inventory[entry.slot] = { unitType = entry.unitType, oneIn = entry.oneIn, level = entry.level or 0, fails = entry.fails or 0, locked = entry.locked == true }
	end
	State.placed = snap.placed or {}
	State.materials = snap.materials or {}

	local ascended = lastRebirth ~= nil and snap.rebirthCount > lastRebirth
	lastRebirth = snap.rebirthCount

	-- Unlock the grave tiers this ascension level has reached
	for _, gd in ipairs(GameData.GRAVE_DATA) do
		if gd.unlockAscension <= State.rebirthCount then
			ShopPanel.unlockGrave(gd.key)
		end
	end

	Toolbar.refresh()
	Toolbar.updateCarried()
	if InventoryPanel.isVisible() then
		InventoryPanel.refresh()
	end
	GravesDock.refresh()
	ShopPanel.updateGraveyard()
	HUD.update()

	for _, fn in ipairs(listeners) do
		local ok, err = pcall(fn, ascended)
		if not ok then
			warn("Sync listener failed:", err)
		end
	end
end

local function flush()
	if pending and started and not held then
		local snap = pending
		pending = nil
		apply(snap)
	end
end

-- Holds UI updates back (e.g. while a roll animation hides the result). The latest snapshot
-- is applied by release(), or automatically after HOLD_TIMEOUT seconds.
function Sync.hold()
	held = true
	holdUntil = os.clock() + HOLD_TIMEOUT
	task.delay(HOLD_TIMEOUT + 0.1, function()
		if held and os.clock() >= holdUntil then
			held = false
			flush()
		end
	end)
end

function Sync.release()
	held = false
	flush()
end

-- Begins applying snapshots. Call once every panel exists.
function Sync.start()
	if started then
		return
	end
	started = true
	local dataSync = ReplicatedStorage:WaitForChild("DataSync")
	dataSync.OnClientEvent:Connect(function(snap)
		pending = snap
		flush()
	end)
	flush()
	local requestData = ReplicatedStorage:WaitForChild("RequestData", 5)
	if requestData then
		requestData:FireServer()
	end
end

return Sync
