-- The realm's look on a claimed plot (ServerStorage.LaneModels.CemeteryPlot, built by tools/studio/build_plot_cemetery.lua):
-- the plot becomes part of the realm like its lane, so the cut between the neutral plaza stone and the realm sits at the
-- plot's entrance. Applied when a plot is claimed (Plots), removed when the player leaves: the plot's neutral Style parts
-- it replaces (the model's attribute Hides) are hidden meanwhile, and the Base is recoloured (FloorColor / FloorMaterial).
-- It also places the Soul Altar beside the plot (tools/studio/build_altar.lua): LaneModels.AltarCore (the same in every
-- realm: altar, braziers, floating runes, the bone bridge) and the realm's island (LaneModels.CemeteryAltarIsland).
-- The altar (tag SoulAltar) carries the owner's realm upgrade levels as attributes Level_<key> and the permanent ones as
-- Perm_<key>, kept up to date after every data sync; the client module AltarFx sizes the braziers' flames from them and
-- writes a new permanent level into the tome.
-- And the realm's outer wall section (LaneModels.WallCemetery, tools/studio/build_wall_cemetery.lua): turned round the
-- arena's centre to the plot's lane, in front of the neutral OuterWall.Section<i> (whose decorations are hidden), the
-- gate tower's rose window turned green and gold; its crypts open with the realm's progress (updateCrypts).
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Collision = require(script.Parent.Collision)
local PlayerData = require(script.Parent.PlayerData)
local PlotRegistry = require(script.Parent.PlotRegistry)
local Economy = require(ReplicatedStorage.Shared.Economy)

local PlotLook = {}

-- the look of the plot owner's realm (only Realm 1 exists so far)
local function templateFor(_plotState)
	local folder = ServerStorage:FindFirstChild("LaneModels")
	return folder and folder:FindFirstChild("CemeteryPlot")
end

-- the Soul Altar's models for the owner's realm
local function altarTemplates(_plotState)
	local folder = ServerStorage:FindFirstChild("LaneModels")
	return { folder and folder:FindFirstChild("AltarCore"), folder and folder:FindFirstChild("CemeteryAltarIsland") }
end

-- a clone pivoted to the plot frame; colliding parts go into the Decor group (players collide, units ignore them)
local function place(template, plotState, name)
	local model = template:Clone()
	model.Name = name
	model:PivotTo(plotState.frame)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and d.CanCollide then
			d.CollisionGroup = Collision.DECOR
		elseif d:IsA("TextLabel") and d.Name == "PlotNumber" then
			d.Text = "PLOT " .. plotState.plotIndex
		end
	end
	model.Parent = workspace
	return model
end

-- the owner's realm upgrade levels onto the altar (only the ones that changed)
local function updateAltar(plotState, profile)
	local altar = plotState.look and plotState.look.altar and plotState.look.altar[1]
	if not altar or not profile then
		return
	end
	for _, u in ipairs(Economy.REALM_UPGRADES) do
		local level = profile.realmUpgrades[u.key] or 0
		if altar:GetAttribute("Level_" .. u.key) ~= level then
			altar:SetAttribute("Level_" .. u.key, level)
		end
	end
	-- the permanent upgrades (Luck Boost, Coin Boost): a new level is written into the altar's tome (AltarFx)
	for key in pairs(Economy.UPGRADE_MAX) do
		local level = profile.upgrades[key] or 0
		if altar:GetAttribute("Perm_" .. key) ~= level then
			altar:SetAttribute("Perm_" .. key, level)
		end
	end
end

-- the wall section's crypts: as many Open as the share of the realm's ascensions done (all open at its last one)
local function updateCrypts(plotState, profile)
	local wall = plotState.look and plotState.look.wall
	if not wall or not profile then
		return
	end
	local crypts = wall:GetAttribute("Crypts") or 0
	local size = Economy.ASCENSIONS_PER_REALM
	local done = profile.rebirthCount % size
	local open = size <= 1 and crypts or math.floor(done / (size - 1) * crypts + 0.5)
	if plotState.look.cryptsOpen == open then
		return
	end
	plotState.look.cryptsOpen = open
	for _, bay in ipairs(wall:GetDescendants()) do
		local index = bay:IsA("Model") and bay:GetAttribute("CryptIndex")
		if index then
			local isOpen = index <= open
			for _, version in ipairs(bay:GetChildren()) do
				local state = version:GetAttribute("CryptState")
				if state then
					local show = (state == "Open") == isOpen
					for _, d in ipairs(version:GetDescendants()) do
						if d:IsA("BasePart") then
							d.Transparency = show and (d:GetAttribute("BaseTransparency") or 0) or 1
						elseif d:IsA("Light") then
							d.Enabled = show
						end
					end
				end
			end
		end
	end
end

table.insert(PlayerData.onSync, function(player, profile)
	local plotState = PlotRegistry.getPlot(player)
	if plotState then
		updateAltar(plotState, profile)
		updateCrypts(plotState, profile)
	end
end)

-- the realm's wall section behind the plot's lane (returns the model; hidden / recoloured parts go into `look`)
local WALL_DECOR = { Buttress = true, ButtressStep = true, ButtressCap = true, Course = true, ArrowSlit = true, Merlon = true, MerlonSpike = true }
local function placeWall(plotState, look)
	local folder = ServerStorage:FindFirstChild("LaneModels")
	local template = folder and folder:FindFirstChild("WallCemetery")
	local ring = workspace:FindFirstChild("OuterWall")
	if not (template and ring) then
		return nil
	end
	-- the lane's compass angle (build_ring: 0 = -Z, clockwise seen from above)
	local dir = plotState.frame.LookVector
	local deg = math.deg(math.atan2(dir.X, -dir.Z))
	local wall = template:Clone()
	wall.Name = "RealmWall_" .. plotState.plotIndex
	wall:PivotTo(CFrame.Angles(0, -math.rad(deg), 0))
	wall.Parent = workspace
	local section = ring:FindFirstChild("Section" .. plotState.plotIndex)
	for _, d in ipairs(section and section:GetDescendants() or {}) do
		if d:IsA("BasePart") and WALL_DECOR[d.Name] then
			table.insert(look.hidden, { inst = d, transparency = d.Transparency, canCollide = d.CanCollide })
			d.Transparency = 1
			d.CanCollide = false
		end
	end
	look.recoloured = {}
	local tower = ring:FindFirstChild("GateTower" .. plotState.plotIndex)
	for _, d in ipairs(tower and tower:GetDescendants() or {}) do
		if d.Name == "RoseGlass" or d.Name == "RoseBoss" then
			local l = d:FindFirstChildOfClass("SurfaceLight")
			table.insert(look.recoloured, { inst = d, color = d.Color, material = d.Material, light = l, lightColor = l and l.Color })
			if d.Name == "RoseGlass" then
				d.Color = Color3.fromRGB(70, 140, 84)
				if l then l.Color = Color3.fromRGB(120, 255, 170) end
			else
				d.Color = Color3.fromRGB(200, 160, 80)
				d.Material = Enum.Material.Metal
			end
		end
	end
	return wall
end

function PlotLook.clear(plotState)
	local look = plotState.look
	if not look then return end
	plotState.look = nil
	if look.model then
		look.model:Destroy()
	end
	if look.wall then
		look.wall:Destroy()
	end
	for _, r in ipairs(look.recoloured or {}) do
		r.inst.Color = r.color
		r.inst.Material = r.material
		if r.light then
			r.light.Color = r.lightColor
		end
	end
	for _, m in ipairs(look.altar or {}) do
		m:Destroy()
	end
	for _, h in ipairs(look.hidden) do
		if h.inst.Parent then
			if h.inst:IsA("BasePart") then
				h.inst.Transparency = h.transparency
				h.inst.CanCollide = h.canCollide
			else
				h.inst.Enabled = true
			end
		end
	end
	local base = plotState.plotModel and plotState.plotModel:FindFirstChild("Base")
	if base then
		base.Color = look.baseColor
		base.Material = look.baseMaterial
	end
end

function PlotLook.apply(plotState)
	PlotLook.clear(plotState)
	local template = templateFor(plotState)
	local plot = plotState.plotModel
	local base = plot and plot:FindFirstChild("Base")
	if not (template and base) then return end
	local look = { hidden = {}, baseColor = base.Color, baseMaterial = base.Material }

	-- hide the neutral parts this look replaces (and their signs)
	local names = {}
	for name in string.gmatch(template:GetAttribute("Hides") or "", "[^,]+") do
		names[name] = true
	end
	local style = plot:FindFirstChild("Style")
	for _, d in ipairs(style and style:GetDescendants() or {}) do
		if d:IsA("BasePart") and names[d.Name] then
			table.insert(look.hidden, { inst = d, transparency = d.Transparency, canCollide = d.CanCollide })
			d.Transparency = 1
			d.CanCollide = false
			for _, gui in ipairs(d:GetChildren()) do
				if gui:IsA("SurfaceGui") and gui.Enabled then
					table.insert(look.hidden, { inst = gui })
					gui.Enabled = false
				end
			end
		end
	end
	base.Color = template:GetAttribute("FloorColor") or base.Color
	local mat = template:GetAttribute("FloorMaterial")
	if mat then
		base.Material = Enum.Material[mat]
	end

	look.model = place(template, plotState, "PlotLook_" .. plotState.plotIndex)
	look.altar = {}
	for i, t in ipairs(altarTemplates(plotState)) do
		if t then
			table.insert(look.altar, place(t, plotState, (i == 1 and "PlotAltar_" or "PlotAltarIsland_") .. plotState.plotIndex))
		end
	end
	local core = look.altar[1]
	if core and core.Name:find("^PlotAltar_") then
		CollectionService:AddTag(core, "SoulAltar")
		core:SetAttribute("OwnerId", plotState.ownerId)
	end
	look.wall = placeWall(plotState, look)
	plotState.look = look
	local owner = Players:GetPlayerByUserId(tonumber(plotState.ownerId) or 0)
	updateAltar(plotState, owner and PlayerData.get(owner))
	updateCrypts(plotState, owner and PlayerData.get(owner))
end

return PlotLook
