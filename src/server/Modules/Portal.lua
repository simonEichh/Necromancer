-- The portal behind the gate (Design.md, "The end of a run"): when a run's gate falls, the sealed door of that lane's
-- gate tower in the outer ring (Workspace.OuterWall...GateTower<plotIndex>, build_ring.lua) bursts open and the portal
-- to the next realm appears behind it. It shows how far the player still is from the next realm (attributes on the
-- tower, drawn by the client Modules/PortalFx) and REJECTS everyone who steps in (a shockwave throws them back) until
-- the realm's last ascension: then its owner can walk through, and that is the ascension (Portal.onPass, set by Plots).
-- Normal ascensions stay on the Ascend button. The portal stands SEALED behind the gate for the whole run (opened
-- sealed when the plot is claimed and after each ascension, by Plots): it can be seen from the lane, rejects
-- everyone and only wakes when the gate falls. It closes when the player leaves.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Remotes = require(script.Parent.Remotes)
local PlayerData = require(script.Parent.PlayerData)
local PlotRegistry = require(script.Parent.PlotRegistry)
local Economy = require(game:GetService("ReplicatedStorage").Shared.Economy)

local Portal = {}

Portal.REALM_SIZE = Economy.ASCENSIONS_PER_REALM -- ascensions per realm (realm 1 = ascensions 0-4)
Portal.MAX_ASCENSIONS = 9 -- (the game has 9 ascensions so far: no realm after the last one)
Portal.onPass = nil -- function(player): ascends through the portal (set by Plots)

local TOUCH_RADIUS = 12 -- studs from the portal's front where it reacts (the portal is 20 wide, Modules/PortalFx)
local TOUCH_HEIGHT = 30
local PUSH_SPEED = 85
local REJECT_COOLDOWN = 1.5

local lastReject = {} -- [player] = os.clock()

local function towerOf(plotState)
	local ring = workspace:FindFirstChild("OuterWall")
	return ring and ring:FindFirstChild("GateTower" .. plotState.plotIndex, true)
end

-- ascensions the player still needs before the portal lets them through (0 = the way is open now)
local function remaining(profile)
	local done = profile.rebirthCount % Portal.REALM_SIZE
	return Portal.REALM_SIZE - 1 - done
end

-- sealed = true: the run's portal while the gate still stands (shown, never lets anyone through)
function Portal.open(plotState, player, sealed)
	local tower = towerOf(plotState)
	local profile = PlayerData.get(player)
	if not (tower and profile) then return end
	local left = remaining(profile)
	tower:SetAttribute("OwnerId", player.UserId)
	tower:SetAttribute("RealmSize", Portal.REALM_SIZE)
	tower:SetAttribute("RealmDone", profile.rebirthCount % Portal.REALM_SIZE)
	tower:SetAttribute("Remaining", left)
	tower:SetAttribute("Ready", not sealed and left == 0 and profile.rebirthCount < Portal.MAX_ASCENSIONS)
	tower:SetAttribute("Sealed", sealed == true)
	if not tower:GetAttribute("PortalOpen") then
		tower:SetAttribute("OpenAt", workspace:GetServerTimeNow()) -- (the door only bursts the first time)
	end
	tower:SetAttribute("PortalOpen", true)
	plotState.portal = { tower = tower, door = tower:FindFirstChild("GateDoor") }
end

function Portal.close(plotState)
	local p = plotState.portal
	if p and p.tower then
		p.tower:SetAttribute("PortalOpen", false)
		p.tower:SetAttribute("Ready", false)
		p.tower:SetAttribute("Sealed", false)
	end
	plotState.portal = nil
end

-- throws a character back out of the portal, towards the lane
local function reject(player, root, door, plotState, notOwner)
	local now = os.clock()
	if now - (lastReject[player] or 0) < REJECT_COOLDOWN then return end
	lastReject[player] = now
	local out = door.CFrame.LookVector -- the door's front (-Z) faces the lane
	root.AssemblyLinearVelocity = Vector3.new(out.X, 0, out.Z).Unit * PUSH_SPEED + Vector3.new(0, 40, 0)
	plotState.portal.tower:SetAttribute("RejectAt", workspace:GetServerTimeNow())
	local left = plotState.portal.tower:GetAttribute("Remaining") or 0
	if notOwner then
		Remotes.Notice:FireClient(player, "This portal does not answer to you.")
	elseif plotState.portal.tower:GetAttribute("Sealed") then
		Remotes.Notice:FireClient(player, "The portal is sealed while the gate stands.")
	elseif left > 0 then
		Remotes.Notice:FireClient(player, "The portal rejects you. It opens in " .. left .. " more ascension" .. (left == 1 and "" or "s") .. ".")
	else
		Remotes.Notice:FireClient(player, "There is no realm beyond this one yet.")
	end
end

local accum = 0
RunService.Heartbeat:Connect(function(dt)
	accum += dt
	if accum < 0.1 then return end
	accum = 0
	for _, plotState in pairs(PlotRegistry.playerPlots) do
		local p = plotState.portal
		local door = p and p.door
		if door then
			local front = (door.CFrame * CFrame.new(0, -door.Size.Y / 2, -4)).Position
			for _, player in ipairs(Players:GetPlayers()) do
				local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
				if root then
					local d = root.Position - front
					if Vector3.new(d.X, 0, d.Z).Magnitude < TOUCH_RADIUS and d.Y > -4 and d.Y < TOUCH_HEIGHT then
						local isOwner = tostring(player.UserId) == plotState.ownerId
						if isOwner and p.tower:GetAttribute("Ready") and Portal.onPass then
							Portal.onPass(player) -- walking through is the ascension into the next realm
						else
							reject(player, root, door, plotState, not isOwner)
						end
					end
				end
			end
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	lastReject[player] = nil
end)

return Portal
