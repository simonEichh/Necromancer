-- The realm titans (Design.md, "Realms"): every claimed plot gets its realm's titan (ServerStorage.TitanModels, built by
-- tools/studio/build_titan_gravekeeper.lua) standing outside the outer wall beside its lane's gate tower, leaning over
-- the battlements and turned a little towards the lane. Each player has their own; empty plots have none; it is removed
-- when the player leaves. The coliseum is centred on the origin.
-- A player's titan first waits sunk behind the wall ("Waiting"; walls that break meanwhile just rise, see
-- plotState.titanBusyUntil in Walls) and climbs up over it ("Enter") the first time the owner steps onto their plot
-- (players join on the plaza, see Plots).
-- Realm 1's keeper is now only seen as HANDS (ServerStorage.TitanModels.GravekeeperHands, build_titan_hands.lua): two
-- torn rifts behind the lane's end, his forearms resting on the battlements, his eyes in black fog above the gate tower
-- (tag RealmHands, animated by the client Modules/HandsAnimator). His full model (Gravekeeper, Modules/TitanAnimator)
-- is kept for the world boss; it is only used here when the hands model is missing.
local ServerStorage = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local PlotRegistry = require(script.Parent.PlotRegistry)
local PlotFrame = require(script.Parent.PlotFrame)

local Titans = {}

local RING_INNER = 392 -- inner face of the outer wall (build_ring.lua R_IN): the hands model's origin
local RING_OUTER = 404 -- outer face of the outer wall (build_ring.lua R_IN + THICK)
local WALL_TOP_Y = -1.7 + 70 -- top of the outer wall
local LATERAL = -66 -- studs beside the lane axis (clear of the 125-high gate tower), on the side of his weaving hand
local TURN = math.rad(12) -- turned a little towards the lane
local ENTER_TIME = 8.8 -- the "Enter" climb (its timeline in TitanAnimator; keep in sync)
local PLOT_HALF_LENGTH = 24 -- the plot Base runs -24..24 along the lane from its centre
local PLOT_HALF_WIDTH = 20

local function flat(v)
	return Vector3.new(v.X, 0, v.Z).Unit
end

-- the titan of the plot owner's realm (only Realm 1 exists so far)
local function templateFor(_plotState)
	local folder = ServerStorage:FindFirstChild("TitanModels")
	return folder and (folder:FindFirstChild("GravekeeperHands") or folder:FindFirstChild("Gravekeeper"))
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
	local titan = template:Clone()
	titan.Name = "Titan_" .. plotState.plotIndex
	local isHands = template:GetAttribute("Kind") == "Hands"
	if isHands then
		-- the hands: origin on the outer wall's inner top edge on the lane's axis, facing the arena
		local origin = laneDir * RING_INNER + Vector3.new(0, WALL_TOP_Y, 0)
		titan:PivotTo(CFrame.lookAt(origin, origin - laneDir))
	end
	-- the model knows how far in front of his feet the wall's outer face is and how high its top is (WallBack, WallTop);
	-- the radial distance is chosen so his distance from the centre, sideways offset included, is right
	local wallBack = template:GetAttribute("WallBack") or 36
	local wallTop = template:GetAttribute("WallTop") or 102
	local radial = math.sqrt((RING_OUTER + wallBack) ^ 2 - LATERAL ^ 2)
	local spot = laneDir * radial + right * LATERAL
	local feet = Vector3.new(spot.X, WALL_TOP_Y - wallTop, spot.Z)
	local facing = -laneDir * math.cos(TURN) + right * math.sin(TURN)
	if not isHands then
		titan:PivotTo(CFrame.lookAt(feet, feet + facing))
	end
	-- for the clients: whose titan it is (only its owner feels the slam's camera shake) and the lane the tremor runs
	-- down (from the lane's end at the outer wall back towards the plot)
	titan:SetAttribute("OwnerId", tonumber(plotState.ownerId))
	local laneEnd = plotState.frame.Position + laneDir * 308
	titan:SetAttribute("LaneEnd", laneEnd)
	titan:SetAttribute("LaneBack", -laneDir)
	titan:SetAttribute("LaneLength", 308 - 24)
	CollectionService:AddTag(titan, isHands and "RealmHands" or "RealmTitan") -- animated on the clients (HandsAnimator / TitanAnimator)
	-- he waits out of sight until the owner first steps onto the plot
	titan:SetAttribute("SummonKind", "Waiting")
	titan:SetAttribute("SummonAt", workspace:GetServerTimeNow())
	plotState.titanWaiting = true
	-- (a grace period: right after the join the server can still see the character where it spawned for a moment,
	-- before the teleport to the plaza has come back from the client)
	plotState.titanWatchFrom = os.clock() + 3
	plotState.titanOnPlot = 0
	plotState.titanBusyUntil = math.huge
	titan.Parent = workspace
	plotState.titan = titan
	Titans.setFocus(plotState)
end

-- the owner stepped onto the plot: he climbs up over the wall
local function enter(plotState)
	plotState.titanWaiting = false
	if plotState.titan then
		plotState.titan:SetAttribute("SummonKind", "Enter")
		plotState.titan:SetAttribute("SummonAt", workspace:GetServerTimeNow())
	end
	plotState.titanBusyUntil = os.clock() + ENTER_TIME
end

local lastCheck = 0
RunService.Heartbeat:Connect(function()
	local now = os.clock()
	if now - lastCheck < 0.25 then
		return
	end
	lastCheck = now
	for ownerId, plotState in pairs(PlotRegistry.playerPlots) do
		if plotState.titanWaiting and now >= (plotState.titanWatchFrom or 0) then
			local player = Players:GetPlayerByUserId(tonumber(ownerId))
			local root = player and player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if root then
				local lateral, forward = PlotFrame.toLocal(plotState, root.Position)
				if math.abs(lateral) < PLOT_HALF_WIDTH and forward > -PLOT_HALF_LENGTH and forward < PLOT_HALF_LENGTH + 40 then
					plotState.titanOnPlot += 1
					if plotState.titanOnPlot >= 2 then -- (two checks in a row)
						enter(plotState)
					end
				else
					plotState.titanOnPlot = 0
				end
			end
		end
	end
end)

-- Where the titan looks: the wall the army is fighting (Walls.setFront calls this when the front moves)
function Titans.setFocus(plotState)
	if plotState.titan and plotState.wallTarget then
		plotState.titan:SetAttribute("Focus", plotState.wallTarget + Vector3.new(0, 10, 0))
	end
end

return Titans
