-- Subtle cape motion on every player's equipped Tattered Cape; no server physics or remotes.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CapeSway = {}

local capes = {}
local scanAt = 0

local function discover()
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not (root and humanoid) then continue end
		for _, accessory in character:GetChildren() do
			if not accessory:IsA("Accessory") or accessory:GetAttribute("OutfitItem") ~= "TatteredCape"
				or capes[accessory] then continue end
			local joints = {}
			for i = 1, 3 do
				local joint = accessory:FindFirstChild("CapeSway" .. i, true)
				if joint and joint:IsA("Motor6D") then joints[i] = joint end
			end
			-- Replication/streaming can bring the joints in after the accessory.
			if joints[1] and joints[2] and joints[3] then
				capes[accessory] = { character = character, root = root, humanoid = humanoid,
					joints = joints, speed = 0, phase = player.UserId % 17 }
			end
		end
	end
end

-- Motor6D.Transform is applied in the simulation step, after avatar animation has been evaluated.
RunService.PreSimulation:Connect(function(dt)
	scanAt -= dt
	if scanAt <= 0 then
		scanAt = 0.5
		discover()
	end
	for accessory, s in pairs(capes) do
		if accessory.Parent ~= s.character or not s.root:IsDescendantOf(workspace)
			or not s.humanoid.Parent then
			capes[accessory] = nil
			continue
		end
		local velocity = s.root.AssemblyLinearVelocity
		local horizontal = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
		local moving = not s.root.Anchored and s.humanoid.Health > 0
		local speed = moving and math.clamp(horizontal / 16, 0, 1.5) or 0
		local step = math.min(dt, 0.1)
		s.speed += (speed - s.speed) * (1 - math.exp(-6 * step))
		s.phase += step * (1.2 + s.speed * 6)
		for i, joint in ipairs(s.joints) do
			if not joint:IsDescendantOf(accessory) then
				capes[accessory] = nil
				break
			end
			local phase = s.phase - (i - 1) * 0.65
			local amplitude = math.rad(2.5 + s.speed * 9) * (1 + (i - 1) * 0.35)
			local pitch = -math.rad(18) * s.speed + math.sin(phase) * amplitude
			local roll = math.sin(phase * 0.7) * math.rad(1.5 + s.speed * 4)
			joint.Transform = CFrame.Angles(pitch, 0, roll)
		end
	end
end)

CapeSway.count = function() local n = 0 for _ in pairs(capes) do n += 1 end return n end

return CapeSway
