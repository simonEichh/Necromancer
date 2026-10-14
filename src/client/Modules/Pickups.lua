-- Client side of the loot drops (server: Modules/Drops). The server creates the coin and dust parts in Workspace.Drops and
-- decides when they are collected; this module only animates them locally:
--   * the burst: each drop flies in an arc from the broken wall (attribute From) to where it landed
--   * idle: coins spin and bob, dust crystals turn and bob
--   * collected (attribute Collected = "player" | "wisp" | "overflow"): the drop flies to the player or the wisp and
--     shrinks, or simply fades (overflow)
-- It also dresses up the Soul Wisp (a trail and soul particles) and shows the first objective (break walls for the wisp).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Theme = require(script.Parent.Theme)
local State = require(script.Parent.State)
local Sync = require(script.Parent.Sync)
local screenGui = require(script.Parent.Gui)

local C = Theme.Color
local COLLECTOR_WALLS = 10 -- keep in sync with Drops.COLLECTOR_WALLS on the server
local ARC_TIME = 0.55
local FLY_TIME = 0.35
local MAX_DISTANCE = 260 -- drops farther from the camera are not animated

local player = Players.LocalPlayer
local dropsRoot = workspace:WaitForChild("Drops", 30)

local tracked = {} -- [part] = { home = Vector3, from = Vector3?, t0 = number, phase = number, collected = string?, c0 = number }

local function wispOf(part)
	local folder = part.Parent
	return folder and folder:FindFirstChild("SoulWisp")
end

-- ============================================================
-- The wisp's look (the server only moves a neon ball)
-- ============================================================
local function dressWisp(w)
	if w:FindFirstChild("WispTrail") then return end
	local a0 = Instance.new("Attachment", w)
	a0.Position = Vector3.new(0, 0.4, 0)
	local a1 = Instance.new("Attachment", w)
	a1.Position = Vector3.new(0, -0.4, 0)
	local trail = Instance.new("Trail")
	trail.Name = "WispTrail"
	trail.Attachment0, trail.Attachment1 = a0, a1
	trail.Color = ColorSequence.new(Color3.fromRGB(200, 255, 230), Color3.fromRGB(60, 160, 110))
	trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
	trail.Lifetime = 0.5
	trail.LightEmission = 1
	trail.FaceCamera = true
	trail.Parent = w
	local e = Instance.new("ParticleEmitter")
	e.Name = "WispSouls"
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(Color3.fromRGB(200, 255, 230), Color3.fromRGB(120, 255, 190))
	e.LightEmission = 1
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0) })
	e.Lifetime = NumberRange.new(0.5, 0.9)
	e.Rate = 14
	e.Speed = NumberRange.new(0.5, 1.5)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Parent = w
end

-- ============================================================
-- Drops
-- ============================================================
local function track(part)
	if not part:IsA("BasePart") then return end
	if part.Name == "SoulWisp" then
		dressWisp(part)
		return
	end
	if tracked[part] then return end
	local spawnTime = part:GetAttribute("SpawnTime") or 0
	local age = workspace:GetServerTimeNow() - spawnTime
	tracked[part] = {
		home = part.Position,
		from = (age < ARC_TIME) and part:GetAttribute("From") or nil,
		t0 = os.clock() - math.max(0, age),
		phase = math.random() * math.pi * 2,
		arc = part:GetAttribute("ArcHeight") or 5, -- how high the burst arc flies (bigger hit coins fly higher)
	}
	part:GetAttributeChangedSignal("Collected"):Connect(function()
		local d = tracked[part]
		if d and not d.collected then
			d.collected = part:GetAttribute("Collected")
			d.c0 = os.clock()
			d.start = part.Position
			d.size0 = part.Size
		end
	end)
end

if dropsRoot then
	for _, d in ipairs(dropsRoot:GetDescendants()) do
		track(d)
	end
	dropsRoot.DescendantAdded:Connect(track)
	dropsRoot.DescendantRemoving:Connect(function(d)
		tracked[d] = nil
	end)
end

RunService.RenderStepped:Connect(function()
	local now = os.clock()
	local camera = workspace.CurrentCamera
	local camPos = camera and camera.CFrame.Position
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	for part, d in pairs(tracked) do
		if not part.Parent then
			tracked[part] = nil
		elseif d.collected then
			local f = math.clamp((now - d.c0) / FLY_TIME, 0, 1)
			local target
			if d.collected == "player" and hrp then
				target = hrp.Position
			elseif d.collected == "wisp" then
				local w = wispOf(part)
				target = w and w.Position
			end
			if target then
				part.CFrame = CFrame.new(d.start:Lerp(target, f * f))
			end
			part.Transparency = f
			part.Size = d.size0 * (1 - 0.6 * f)
		elseif not camPos or (d.home - camPos).Magnitude < MAX_DISTANCE then
			local age = now - d.t0
			local pos
			if d.from and age < ARC_TIME then
				-- the burst: an arc from the wall to the landing spot
				local f = age / ARC_TIME
				pos = d.from:Lerp(d.home, f) + Vector3.new(0, math.sin(f * math.pi) * d.arc, 0)
			else
				pos = d.home + Vector3.new(0, 0.25 + math.sin(now * 2.5 + d.phase) * 0.25, 0)
			end
			local spin = CFrame.Angles(0, now * 2 + d.phase, 0)
			if part.Name == "Coin" then
				part.CFrame = CFrame.new(pos) * spin -- a cylinder runs along X: the coin stands on its edge and turns
			else
				part.CFrame = CFrame.new(pos) * spin * CFrame.Angles(math.rad(45), 0, math.rad(45)) -- a crystal on its tip
			end
		end
	end
end)

-- ============================================================
-- The first objective (until the player owns the Soul Wisp)
-- ============================================================
local banner = Instance.new("Frame")
banner.Name = "ObjectiveBanner"
banner.AnchorPoint = Vector2.new(0.5, 0)
banner.Position = UDim2.new(0.5, 0, 0, 104) -- under the travel tile
banner.Size = UDim2.fromOffset(420, 34)
banner.BackgroundColor3 = C.Void
banner.BackgroundTransparency = 0.25
banner.BorderSizePixel = 0
banner.Visible = false
banner.ZIndex = 5
banner.Parent = screenGui
Theme.corner(banner, Theme.Radius.Small)
Theme.stroke(banner, C.Border, 1)
local bannerText = Theme.label(banner, { text = "", size = "Small", font = "Strong", color = C.Bone, align = Enum.TextXAlignment.Center, frameSize = UDim2.new(1, -12, 1, 0) })
bannerText.Position = UDim2.fromOffset(6, 0)
bannerText.TextSize = 15
bannerText.ZIndex = 6

local function refreshBanner()
	local done = math.min(State.wallsBroken or 0, COLLECTOR_WALLS)
	banner.Visible = State.collector ~= true -- (only called once data arrived)
	bannerText.Text = "Break " .. COLLECTOR_WALLS .. " walls and collect the loot to earn the Soul Wisp   " .. done .. " / " .. COLLECTOR_WALLS
end
Sync.onApplied(refreshBanner)

return {}
