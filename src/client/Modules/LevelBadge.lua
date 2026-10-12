-- A small level plate for unit slots (hotbar, inventory): "Lv 4" in the top-right corner of a slot, hidden at level 0 and
-- gold at the maximum level.
--
--   local badge = LevelBadge.attach(slotFrame, zIndex)
--   badge.set(level)   -- nil / 0 hides it
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(script.Parent.Theme)
local Economy = require(ReplicatedStorage.Shared.Economy)

local C = Theme.Color

local LevelBadge = {}

function LevelBadge.attach(slot, zIndex)
	local plate = Instance.new("Frame")
	plate.Name = "LevelBadge"
	plate.AnchorPoint = Vector2.new(1, 0)
	plate.Position = UDim2.new(1, -2, 0, 2)
	plate.Size = UDim2.fromOffset(32, 15)
	plate.BackgroundColor3 = C.Void
	plate.BackgroundTransparency = 0.12
	plate.BorderSizePixel = 0
	plate.Visible = false
	plate.ZIndex = zIndex or 5
	Theme.corner(plate, 4)
	local stroke = Theme.stroke(plate, C.BorderBright, 1)
	plate.Parent = slot

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Theme.Font.Strong
	label.TextSize = 11
	label.TextColor3 = C.Bone
	label.ZIndex = (zIndex or 5) + 1
	label.Parent = plate

	local handle = {}
	function handle.set(level)
		level = level or 0
		if level <= 0 then
			plate.Visible = false
			return
		end
		plate.Visible = true
		label.Text = "Lv " .. level
		local maxed = level >= Economy.MAX_UNIT_LEVEL
		label.TextColor3 = maxed and C.Gold or C.Bone
		stroke.Color = maxed and C.Gold or C.BorderBright
	end
	return handle
end

return LevelBadge
