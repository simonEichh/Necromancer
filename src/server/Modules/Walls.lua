-- Per-plot wall: HP bar, preview queue, breaking and reset.
local Players = game:GetService("Players")
local Remotes = require(script.Parent.Remotes)
local Quests = require(script.Parent.Quests)
local PlayerData = require(script.Parent.PlayerData)
local Economy = require(game:GetService("ReplicatedStorage").Shared.Economy)

local incrementQuest = Quests.increment
local WALL_SPACING = 60

local LAYER_COLORS = {
	BrickColor.new("Medium stone grey"),
	BrickColor.new("Bright green"),
	BrickColor.new("Bright blue"),
	BrickColor.new("Bright violet"),
	BrickColor.new("Bright pink"),
}
local NUM_PREVIEW_WALLS = 8

local function updateWallGui(plotState)
	local pct = math.clamp(plotState.wallHP / plotState.WALL_MAX_HP, 0, 1)
	plotState.hpFill.Size = UDim2.new(pct, 0, 1, 0)
	plotState.hpFill.BackgroundColor3 = Color3.fromRGB(220, math.floor(60*pct), math.floor(60*pct))
	plotState.hpText.Text = "Layer " .. plotState.wallLayer .. "  " .. math.floor(plotState.wallHP) .. " / " .. plotState.WALL_MAX_HP
end

local function buildWallGui(wallPart, plotState)
	local gui = Instance.new("BillboardGui", wallPart)
	gui.Size = UDim2.new(0, 260, 0, 55)
	gui.StudsOffset = Vector3.new(0, 14, 0)
	gui.AlwaysOnTop = true
	local bg = Instance.new("Frame", gui)
	bg.Size = UDim2.new(1, 0, 0.5, 0)
	bg.Position = UDim2.new(0, 0, 0.1, 0)
	bg.BackgroundColor3 = Color3.fromRGB(60, 20, 20)
	bg.BorderSizePixel = 0
	Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 6)
	plotState.hpFill = Instance.new("Frame", bg)
	plotState.hpFill.Size = UDim2.new(1, 0, 1, 0)
	plotState.hpFill.BackgroundColor3 = Color3.fromRGB(220, 60, 60)
	plotState.hpFill.BorderSizePixel = 0
	Instance.new("UICorner", plotState.hpFill).CornerRadius = UDim.new(0, 6)
	plotState.hpText = Instance.new("TextLabel", gui)
	plotState.hpText.Size = UDim2.new(1, 0, 0.38, 0)
	plotState.hpText.Position = UDim2.new(0, 0, 0.62, 0)
	plotState.hpText.BackgroundTransparency = 1
	plotState.hpText.TextColor3 = Color3.fromRGB(255, 210, 210)
	plotState.hpText.TextScaled = true
	plotState.hpText.Font = Enum.Font.GothamBold
end

local WALL_MATERIALS = {
	Enum.Material.SmoothPlastic, Enum.Material.Brick,   Enum.Material.Cobblestone,
	Enum.Material.Concrete,      Enum.Material.Granite,  Enum.Material.Marble,
	Enum.Material.Sandstone,     Enum.Material.Slate,    Enum.Material.Wood,
	Enum.Material.WoodPlanks,    Enum.Material.Basalt,   Enum.Material.Limestone,
}

-- Spawns a dim preview wall showing an upcoming layer number
local function spawnPreviewWall(x, layerNum, plotState)
	local wallPart = Instance.new("Part")
	wallPart.Name = "PreviewWall_" .. plotState.plotIndex
	wallPart.Size = Vector3.new(4, 20, 40)
	wallPart.Position = Vector3.new(x, plotState.plotGroundY + 10, plotState.plotCenterZ)
	wallPart.Anchored = true
	wallPart.BrickColor = BrickColor.new("Dark stone grey")
	wallPart.Transparency = 0
	wallPart.Material = WALL_MATERIALS[math.random(#WALL_MATERIALS)]
	wallPart.Parent = workspace
	local gui = Instance.new("BillboardGui", wallPart)
	gui.Name = "PreviewGui"
	gui.Size = UDim2.new(0, 0, 0, 0)
	return wallPart
end

-- Promotes a preview wall to the active wall (full color + HP bar)
local function activateWall(wallPart, plotState)
	wallPart.Name = "TheWall_" .. plotState.plotIndex
	wallPart.BrickColor = LAYER_COLORS[((plotState.wallLayer - 1) % #LAYER_COLORS) + 1]
	wallPart.Transparency = 0
	local previewGui = wallPart:FindFirstChild("PreviewGui")
	if previewGui then previewGui:Destroy() end
	buildWallGui(wallPart, plotState)
end

-- Spawns initial ground slab + 8 walls, activates the first one
local function initWallQueue(plotState)
	-- Initial ground covering all preview walls
	local ld = plotState.laneDir
	local groundLen = (NUM_PREVIEW_WALLS + 1) * WALL_SPACING
	local initGround = Instance.new("Part")
	initGround.Name = "GroundExt"
	initGround.Size = Vector3.new(groundLen, 2, 40)
	initGround.Position = Vector3.new(
		plotState.wallOriginX + ld * groundLen / 2,
		plotState.plotGroundY - 1,
		plotState.plotCenterZ
	)
	initGround.Anchored = true
	initGround.Color = Color3.fromRGB(165, 8, 8)
	initGround.Material = Enum.Material.Carpet
	initGround.TopSurface = Enum.SurfaceType.Smooth
	initGround.Parent = workspace
	table.insert(plotState.groundExtensions, initGround)
	plotState.plotLaneEndX = plotState.wallOriginX + ld * groundLen

	-- Spawn 8 preview walls
	plotState.wallQueue = {}
	for i = 1, NUM_PREVIEW_WALLS do
		local x = plotState.wallOriginX + ld * (i - 1) * WALL_SPACING
		local wallPart = spawnPreviewWall(x, plotState.wallLayer + (i - 1), plotState)
		table.insert(plotState.wallQueue, wallPart)
	end

	-- Activate the front wall
	activateWall(plotState.wallQueue[1], plotState)
	plotState.wall = plotState.wallQueue[1]
	plotState.wallTarget = Vector3.new(plotState.wall.Position.X - ld * (plotState.wall.Size.X/2 + 3), 0, plotState.plotCenterZ)
	updateWallGui(plotState)
end

local function breakWall(plotState)
	plotState.wallLayer += 1
	plotState.WALL_MAX_HP = math.floor(500 * (2 ^ (plotState.wallLayer - 1)))
	plotState.wallHP = plotState.WALL_MAX_HP
	plotState.wallRegen = plotState.wallLayer * 2

	-- Flash and destroy active wall
	plotState.wallQueue[1].BrickColor = BrickColor.new("White")
	plotState.wallQueue[1]:Destroy()
	table.remove(plotState.wallQueue, 1)

	-- Spawn new preview at the far end
	local ld = plotState.laneDir
	local lastWall = plotState.wallQueue[#plotState.wallQueue]
	local newPreviewX = lastWall.Position.X + ld * WALL_SPACING
	local newPreview = spawnPreviewWall(newPreviewX, plotState.wallLayer + #plotState.wallQueue - 1, plotState)
	table.insert(plotState.wallQueue, newPreview)

	-- Ground extension if beyond initial coverage
	if (newPreviewX - plotState.plotLaneEndX) * ld > 0 then
		local groundExt = Instance.new("Part")
		groundExt.Name = "GroundExt"
		groundExt.Size = Vector3.new(WALL_SPACING, 2, 40)
		groundExt.Position = Vector3.new(newPreviewX - ld * WALL_SPACING/2, plotState.plotGroundY - 1, plotState.plotCenterZ)
		groundExt.Anchored = true
		groundExt.Color = Color3.fromRGB(165, 8, 8)
		groundExt.Material = Enum.Material.Carpet
		groundExt.TopSurface = Enum.SurfaceType.Smooth
		groundExt.Parent = workspace
		table.insert(plotState.groundExtensions, groundExt)
		plotState.plotLaneEndX = newPreviewX
	end

	-- Activate the new front wall
	activateWall(plotState.wallQueue[1], plotState)
	plotState.wall = plotState.wallQueue[1]
	plotState.wallTarget = Vector3.new(plotState.wall.Position.X - ld * (plotState.wall.Size.X/2 + 3), 0, plotState.plotCenterZ)
	updateWallGui(plotState)

	local goldReward = math.floor(1000 * plotState.wallLayer * plotState.goldMultiplier)
	for _, p in ipairs(Players:GetPlayers()) do
		if tostring(p.UserId) == plotState.ownerId then
			local profile = PlayerData.get(p)
			if profile then
				local mult = Economy.wallGoldMultiplier(profile.rebirthCount, profile.upgrades.coinBoost)
				PlayerData.addGold(p, math.floor(goldReward * mult))
			end
			Remotes.WallBreak:FireClient(p, goldReward, plotState.wallLayer - 1)
			incrementQuest(p, "breakWalls", 1)
			incrementQuest(p, "earnGold", goldReward)
			break
		end
	end
	print("🎉 Plot" .. plotState.plotIndex .. " wall " .. (plotState.wallLayer-1) .. " broken!")
end

local function resetWall(plotState)
	for _, w in ipairs(plotState.wallQueue or {}) do
		if w and w.Parent then w:Destroy() end
	end
	plotState.wallQueue = {}
	for _, ext in ipairs(plotState.groundExtensions) do
		if ext and ext.Parent then ext:Destroy() end
	end
	plotState.groundExtensions = {}
	plotState.wallLayer = 1
	plotState.WALL_MAX_HP = 500
	plotState.wallHP = plotState.WALL_MAX_HP
	plotState.wallRegen = 1
	initWallQueue(plotState)
end

-- Once-a-second wall HP regeneration for one plot.
local function regen(plotState)
			if plotState.wallHP < plotState.WALL_MAX_HP then
				plotState.wallHP = math.min(plotState.wallHP + plotState.wallRegen, plotState.WALL_MAX_HP)
			end
			updateWallGui(plotState)
end

return {
	updateWallGui = updateWallGui,
	initWallQueue = initWallQueue,
	breakWall = breakWall,
	resetWall = resetWall,
	regen = regen,
}
