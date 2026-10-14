-- The realm titans (Design.md, "Realms"): every claimed plot gets its realm's titan (ServerStorage.TitanModels, built by
-- tools/studio/build_titan_gravekeeper.lua) standing outside the outer wall beside its lane's gate tower, leaning over
-- the battlements and turned a little towards the lane. Each player has their own; empty plots have none; it is removed
-- when the player leaves. The coliseum is centred on the origin.
local ServerStorage = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")

local Titans = {}

local RING_OUTER = 404 -- outer face of the outer wall (build_ring.lua R_IN + THICK)
local WALL_TOP_Y = -1.7 + 70 -- top of the outer wall
local LATERAL = -66 -- studs beside the lane axis (clear of the 125-high gate tower), on the side of his weaving hand
local TURN = math.rad(12) -- turned a little towards the lane

local function flat(v)
	return Vector3.new(v.X, 0, v.Z).Unit
end

-- the titan of the plot owner's realm (only Realm 1 exists so far)
local function templateFor(_plotState)
	local folder = ServerStorage:FindFirstChild("TitanModels")
	return folder and folder:FindFirstChild("Gravekeeper")
end

function Titans.remove(plotState)
	if plotState.titan then
		plotState.titan:Destroy()
		plotState.titan = nil
	end
end

function Titans.spawn(plotState)
	Titans.remove(plotState)
	local template = templateFor(plotState)
	if not template then return end
	local laneDir = flat(plotState.frame.LookVector)
	local right = flat(plotState.frame.RightVector)
	-- the model knows how far in front of his feet the wall's outer face is and how high its top is (WallBack, WallTop);
	-- the radial distance is chosen so his distance from the centre, sideways offset included, is right
	local wallBack = template:GetAttribute("WallBack") or 36
	local wallTop = template:GetAttribute("WallTop") or 102
	local radial = math.sqrt((RING_OUTER + wallBack) ^ 2 - LATERAL ^ 2)
	local spot = laneDir * radial + right * LATERAL
	local feet = Vector3.new(spot.X, WALL_TOP_Y - wallTop, spot.Z)
	local facing = -laneDir * math.cos(TURN) + right * math.sin(TURN)
	local titan = template:Clone()
	titan.Name = "Titan_" .. plotState.plotIndex
	titan:PivotTo(CFrame.lookAt(feet, feet + facing))
	-- for the clients: whose titan it is (only its owner feels the slam's camera shake) and the lane the tremor runs
	-- down (from the lane's end at the outer wall back towards the plot)
	titan:SetAttribute("OwnerId", tonumber(plotState.ownerId))
	local laneEnd = plotState.frame.Position + laneDir * 308
	titan:SetAttribute("LaneEnd", laneEnd)
	titan:SetAttribute("LaneBack", -laneDir)
	titan:SetAttribute("LaneLength", 308 - 24)
	CollectionService:AddTag(titan, "RealmTitan") -- animated on the clients (Modules/TitanAnimator)
	titan.Parent = workspace
	plotState.titan = titan
	Titans.setFocus(plotState)
end

-- Where the titan looks: the wall the army is fighting (Walls.setFront calls this when the front moves)
function Titans.setFocus(plotState)
	if plotState.titan and plotState.wallTarget then
		plotState.titan:SetAttribute("Focus", plotState.wallTarget + Vector3.new(0, 10, 0))
	end
end

return Titans
