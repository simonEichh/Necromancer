-- Only one window at a time: every panel registers its root frame here, and when one becomes visible all the other
-- registered windows are hidden (the panels open and close by setting Visible, so nothing else needs to know).
--
--   require(script.Parent.Windows).register(panel)
local Windows = {}

local frames = {}

function Windows.register(frame)
	table.insert(frames, frame)
	frame:GetPropertyChangedSignal("Visible"):Connect(function()
		if not frame.Visible then
			return
		end
		for _, other in ipairs(frames) do
			if other ~= frame and other.Visible then
				other.Visible = false
			end
		end
	end)
end

return Windows
