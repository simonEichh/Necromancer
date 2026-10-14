-- The Upgrades panel in the world: the camera glides over to your Soul Altar (the island beside your plot, built by
-- tools/studio/build_altar.lua, placed by the server's PlotLook) and the panel stands on the right; your character stays
-- where it is, hidden while the view is open (it could stand between the camera and the altar). Used by UpgradesPanel (like ForgeScene for the Forge). Also puts an "Upgrades" prompt
-- on your own altar's dais.
--
--   AltarScene.available()        -- your altar exists and you are near it (on your plot, the bridge or the island)
--   AltarScene.open(keepGui, onFinish) -> WorldView session (nil if it cannot open)
--   AltarScene.onPrompt = fn       -- called when the altar's prompt is used (UpgradesPanel opens itself)
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local WorldView = require(script.Parent.WorldView)
local AltarFx = require(script.Parent.AltarFx)

local player = Players.LocalPlayer

local AltarScene = {}
AltarScene.onPrompt = nil

local NEAR = 95 -- studs from the altar: your whole plot counts (the plot's centre is ~45 away)
-- the shot, in the altar's frame (floor level at the dais centre, -Z = towards the bridge; +X is on the left as seen
-- from the bridge): from above the bridge end, the altar a little left of the middle (the panel takes the right side)
local CAM_POS = Vector3.new(-2.5, 10, -19)
local CAM_LOOK = Vector3.new(-6.5, 2.5, 0)

local function myAltar()
	for _, a in ipairs(CollectionService:GetTagged("SoulAltar")) do
		if a:GetAttribute("OwnerId") == tostring(player.UserId) and a.Parent then
			return a
		end
	end
	return nil
end

-- the dais' big step gives the altar's frame
local function baseStep(altar)
	local model = altar:FindFirstChild("Altar")
	if not model then
		return nil
	end
	for _, p in ipairs(model:GetChildren()) do
		if p:IsA("BasePart") and p.Name == "Step" and p.Size.X > 7 then
			return p
		end
	end
	return nil
end

local function altarFrame(altar)
	local step = altar and baseStep(altar)
	return step and (step.CFrame * CFrame.new(0, -step.Size.Y / 2, 0))
end

function AltarScene.available()
	local frame = altarFrame(myAltar())
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	return frame ~= nil and hrp ~= nil and (hrp.Position - frame.Position).Magnitude < NEAR
end

local function setCharacterHidden(char, amount)
	for _, d in ipairs(char:GetDescendants()) do
		if d:IsA("BasePart") or d:IsA("Decal") then
			d.LocalTransparencyModifier = amount
		end
	end
end

function AltarScene.open(keepGui, onFinish)
	local frame = altarFrame(myAltar())
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not (frame and hrp) then
		return nil
	end
	local camGoal = CFrame.lookAt((frame * CFrame.new(CAM_POS)).Position, (frame * CFrame.new(CAM_LOOK)).Position)

	local view = WorldView.open({
		keep = { keepGui },
		openTime = 1.1,
		closeTime = 0.9,
		fov = 50,
		goal = function()
			return camGoal
		end,
		onStep = function(s, _, k)
			setCharacterHidden(s.char, k > 0.4 and 1 or 0)
		end,
		onFinish = function(s)
			AltarFx.highlight(nil)
			setCharacterHidden(s.char, 0)
			if onFinish then
				onFinish(s)
			end
		end,
	})
	return view
end

-- ── The prompt on your own altar ────────────────────────────
local function addPrompt(altar)
	if altar:GetAttribute("OwnerId") == nil then
		-- (the attribute can arrive just after the tag)
		altar:GetAttributeChangedSignal("OwnerId"):Once(function()
			addPrompt(altar)
		end)
		return
	end
	if altar:GetAttribute("OwnerId") ~= tostring(player.UserId) then
		return
	end
	local function try()
		local step = baseStep(altar)
		if not step or step:FindFirstChild("AltarPrompt") then
			return step ~= nil
		end
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "AltarPrompt"
		prompt.ActionText = "Upgrades"
		prompt.ObjectText = "Soul Altar"
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.Parent = step
		prompt.Triggered:Connect(function()
			if AltarScene.onPrompt then
				AltarScene.onPrompt()
			end
		end)
		return true
	end
	if not try() then
		-- the dais has not streamed in yet
		local conn
		conn = altar.DescendantAdded:Connect(function()
			if try() then
				conn:Disconnect()
			end
		end)
	end
end

for _, a in ipairs(CollectionService:GetTagged("SoulAltar")) do
	addPrompt(a)
end
CollectionService:GetInstanceAddedSignal("SoulAltar"):Connect(addPrompt)

return AltarScene
