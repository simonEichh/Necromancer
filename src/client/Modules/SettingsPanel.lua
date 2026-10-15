-- The Settings panel: the sound volumes (Master, Effects, Music) as sliders. A "Settings" tile at the top right (left of
-- the spin wheel tile) opens it. The volumes apply at once (Sfx's sound groups) and are saved on the server when a
-- slider is let go (SaveSettings -> PlayerData.settings, comes back in DataSync on the next join).
-- Builds its UI when required (no init call).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Theme = require(script.Parent.Theme)
local State = require(script.Parent.State)
local Sync = require(script.Parent.Sync)
local Sfx = require(script.Parent.Sfx)
local screenGui = require(script.Parent.Gui)

local C = Theme.Color
local Z = 36

local SettingsPanel = {}

local saveRemote = ReplicatedStorage:WaitForChild("SaveSettings", 5)

-- the volumes on this client (the server's copy arrives with the first DataSync)
local volumes = { master = 1, effects = 1, music = 1 }
local loaded = false
local function apply()
	Sfx.setVolumes(volumes.master, volumes.effects, volumes.music)
end

-- ============================================================
-- Frame
-- ============================================================
local themed = Theme.panel(screenGui, { title = "Settings", size = UDim2.fromOffset(460, 330), zIndex = Z })
local panel = themed.frame
panel.Name = "SettingsPanel"
panel.Visible = false
require(script.Parent.Windows).register(panel) -- only one window open at a time
local body = themed.body

Theme.stoneButton(panel, {
	text = "X", color = "red", size = UDim2.fromOffset(44, 28),
	position = UDim2.new(1, -62, 0, 6), zIndex = Z + 2,
	onClick = function() panel.Visible = false end,
})

local heading = Theme.label(body, { text = "Sound", size = "Heading", font = "Strong", color = C.Bone, frameSize = UDim2.new(1, -24, 0, 30) })
heading.Position = UDim2.fromOffset(12, 6)
heading.ZIndex = Z + 2

-- ============================================================
-- Sliders: a label, a track with a fill and a knob, the percentage
-- ============================================================
local sliders = {}
local dragging -- the slider being dragged
local function slider(i, key, title)
	local y = 46 + (i - 1) * 62
	local lbl = Theme.label(body, { text = title, size = "Body", font = "Strong", color = C.Bone, frameSize = UDim2.fromOffset(150, 26) })
	lbl.Position = UDim2.fromOffset(16, y)
	lbl.ZIndex = Z + 2
	local pct = Theme.label(body, { text = "100%", size = "Body", color = C.BoneDim, frameSize = UDim2.fromOffset(60, 26) })
	pct.Position = UDim2.new(1, -76, 0, y)
	pct.TextXAlignment = Enum.TextXAlignment.Right
	pct.ZIndex = Z + 2
	local track = Instance.new("TextButton")
	track.AutoButtonColor = false
	track.Text = ""
	track.BackgroundColor3 = C.Stone or Color3.fromRGB(30, 28, 34)
	track.BorderSizePixel = 0
	track.Position = UDim2.fromOffset(16, y + 30)
	track.Size = UDim2.new(1, -32, 0, 12)
	track.ZIndex = Z + 2
	track.Parent = body
	Theme.corner(track, 6)
	Theme.stroke(track, C.Border, 1)
	local fill = Instance.new("Frame")
	fill.BackgroundColor3 = C.Soul or Color3.fromRGB(140, 120, 220)
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(1, 1)
	fill.ZIndex = Z + 3
	fill.Parent = track
	Theme.corner(fill, 6)
	local knob = Instance.new("Frame")
	knob.AnchorPoint = Vector2.new(0.5, 0.5)
	knob.Size = UDim2.fromOffset(22, 22)
	knob.Position = UDim2.fromScale(1, 0.5)
	knob.BackgroundColor3 = C.Bone or Color3.fromRGB(230, 220, 200)
	knob.BorderSizePixel = 0
	knob.ZIndex = Z + 4
	knob.Parent = track
	Theme.corner(knob, 11)
	Theme.stroke(knob, C.Border, 2)
	local sl = { key = key, track = track, fill = fill, knob = knob, pct = pct }
	function sl.paint()
		local v = volumes[key]
		fill.Size = UDim2.fromScale(v, 1)
		knob.Position = UDim2.fromScale(v, 0.5)
		pct.Text = math.floor(v * 100 + 0.5) .. "%"
	end
	function sl.setFromX(x)
		local f = (x - track.AbsolutePosition.X) / math.max(1, track.AbsoluteSize.X)
		volumes[key] = math.floor(math.clamp(f, 0, 1) * 100 + 0.5) / 100
		sl.paint()
		apply()
	end
	track.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = sl
			sl.setFromX(input.Position.X)
		end
	end)
	sliders[i] = sl
	return sl
end
slider(1, "master", "Master volume")
slider(2, "effects", "Effects")
slider(3, "music", "Music")

UserInputService.InputChanged:Connect(function(input)
	if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
		dragging.setFromX(input.Position.X)
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if dragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
		dragging = nil
		if saveRemote then
			saveRemote:FireServer(volumes) -- (saved when a slider is let go)
		end
	end
end)

local function paint()
	for _, sl in ipairs(sliders) do
		sl.paint()
	end
end

-- ============================================================
-- The tile: top right, left of the spin wheel tile; three little slider lines as its icon
-- ============================================================
local tile = Theme.iconTile(screenGui, {
	text = "Settings", size = 64,
	position = UDim2.new(1, -170, 0, 20), zIndex = 5,
	onClick = function()
		SettingsPanel.toggle()
	end,
})
for k = 0, 2 do
	local line = Instance.new("Frame")
	line.AnchorPoint = Vector2.new(0.5, 0.5)
	line.Position = UDim2.new(0.5, 0, 0.5, -16 + k * 11)
	line.Size = UDim2.fromOffset(34, 3)
	line.BackgroundColor3 = Color3.fromRGB(235, 225, 205)
	line.BorderSizePixel = 0
	line.ZIndex = 7
	line.Parent = tile.root
	local dot = Instance.new("Frame")
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.Position = UDim2.new(({ 0.3, 0.7, 0.45 })[k + 1], 0, 0.5, 0)
	dot.Size = UDim2.fromOffset(9, 9)
	dot.BackgroundColor3 = C.Soul or Color3.fromRGB(140, 120, 220)
	dot.BorderSizePixel = 0
	dot.ZIndex = 8
	dot.Parent = line
	Theme.corner(dot, 5)
end

function SettingsPanel.toggle()
	panel.Visible = not panel.Visible
	if panel.Visible then
		paint()
	end
end

-- the saved volumes arrive with the first DataSync (later snapshots do not overwrite what the player is changing)
Sync.onApplied(function()
	if loaded or type(State.settings) ~= "table" then
		return
	end
	loaded = true
	for key in pairs(volumes) do
		local v = State.settings[key]
		if type(v) == "number" then
			volumes[key] = math.clamp(v, 0, 1)
		end
	end
	apply()
	paint()
end)
apply()

return SettingsPanel
