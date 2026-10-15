-- Who last pulled each showcase unit (the Signatures and Sovereigns), for the plaza's Reliquary ("Pulled by NAME").
-- Global across servers: one DataStore key holds { [unitType] = { name, at } }. Every server reads it at start and
-- every REFRESH s; a pull here updates it at once. The result is published as attributes on
-- ReplicatedStorage.ShowcasePulls (attribute <unitType> = the player's display name), read by the client's
-- ReliquaryShowcase. Without DataStore access (Studio without API access) it still works for this server only.
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Units = require(ReplicatedStorage.Shared.Units)

local ShowcasePulls = {}

local KEY = "latest"
local REFRESH = 120

local store
pcall(function()
	store = DataStoreService:GetDataStore("ShowcasePulls_v1")
end)

local folder = Instance.new("Folder")
folder.Name = "ShowcasePulls"
folder.Parent = ReplicatedStorage

local function publish(data)
	for unitType, entry in pairs(data or {}) do
		if type(entry) == "table" and type(entry.name) == "string" then
			folder:SetAttribute(unitType, entry.name)
		end
	end
end

local function load()
	if not store then
		return
	end
	local ok, data = pcall(function()
		return store:GetAsync(KEY)
	end)
	if ok then
		publish(data)
	end
end

-- a player pulled a unit: remembered if it is a showcase unit (Signature or Sovereign)
function ShowcasePulls.record(player, unitType)
	if not (Units.isSignature(unitType) or Units.isSovereign(unitType)) then
		return
	end
	local name = player.DisplayName
	folder:SetAttribute(unitType, name)
	if not store then
		return
	end
	task.spawn(function()
		pcall(function()
			store:UpdateAsync(KEY, function(data)
				data = type(data) == "table" and data or {}
				data[unitType] = { name = name, at = os.time() }
				return data
			end)
		end)
	end)
end

task.spawn(function()
	while true do
		load()
		task.wait(REFRESH)
	end
end)

return ShowcasePulls
