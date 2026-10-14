-- In-world views: the shared camera part of the panels that take the player into the 3D world (the Codex, Outfits, ...).
-- A view anchors the character, switches off its controls and the game's other ScreenGuis, glides the camera from where
-- it is to the view's goal (always upright, the goal is the panel's business) and back, and restores everything at the
-- end. Only one view runs at a time: opening a new one ends the old one at once.
--
--   local view = WorldView.open({
--       keep = { myScreenGui },             -- ScreenGuis that stay on (the panel's own UI)
--       openTime = 0.9, closeTime = 0.9,    -- glide in / out (seconds)
--       fov = 50,                           -- field of view at the goal
--       goal = function(s, dt) return CFrame end, -- the camera at full blend, every frame
--       blend = function(s) return 0..1 end,      -- optional: own blend curve (default: smooth glide in, hold, glide out)
--       onStep = function(s, dt, k) end,    -- optional: every frame (k = the blend)
--       onShown = function(s) end,          -- optional: the glide in is done
--       onClose = function(s) end,          -- optional: closing starts
--       onFinish = function(s) end,         -- optional: everything restored
--   })
--   view:close()   -- glide back; WorldView.current is the running view
--
-- The session `s` has: phase ("open" | "shown" | "close"), t (seconds in this phase), clock (seconds since open),
-- hrp, char, camera, savedCam.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

local WorldView = {}
WorldView.current = nil

local function smooth(x)
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end
WorldView.smooth = smooth

local Session = {}
Session.__index = Session

function Session:finish()
	if self.finished then
		return
	end
	self.finished = true
	if WorldView.current == self then
		WorldView.current = nil
	end
	self.conn:Disconnect()
	if self.hrp.Parent then
		self.hrp.Anchored = self.savedAnchored
	end
	self.camera.CameraType = (self.savedType == Enum.CameraType.Scriptable) and Enum.CameraType.Custom or self.savedType
	self.camera.FieldOfView = self.savedFov
	for _, g in ipairs(self.hidden) do
		if g.Parent then
			g.Enabled = true
		end
	end
	if self.controls then
		pcall(function()
			self.controls:Enable()
		end)
	end
	if self.opts.onFinish then
		self.opts.onFinish(self)
	end
end

function Session:close()
	if self.finished or self.phase == "close" then
		return
	end
	-- closing during the glide in starts the glide back from where the camera is now
	local k = self:blendNow()
	self.phase = "close"
	self.t = (1 - k) * self.closeTime -- (the default curve picks up at the current blend, roughly)
	if self.opts.onClose then
		self.opts.onClose(self)
	end
end

function Session:blendNow()
	if self.opts.blend then
		return self.opts.blend(self)
	end
	if self.phase == "open" then
		return smooth(self.t / self.openTime)
	elseif self.phase == "shown" then
		return 1
	end
	return 1 - smooth(self.t / self.closeTime)
end

function WorldView.open(opts)
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local camera = workspace.CurrentCamera
	if not hrp or not camera then
		return nil
	end
	if WorldView.current then
		WorldView.current:finish()
	end

	local s = setmetatable({
		opts = opts,
		phase = "open",
		t = 0,
		clock = 0,
		char = char,
		hrp = hrp,
		camera = camera,
		openTime = opts.openTime or 0.9,
		closeTime = opts.closeTime or opts.openTime or 0.9,
		savedCam = camera.CFrame,
		savedType = camera.CameraType,
		savedFov = camera.FieldOfView,
		savedAnchored = hrp.Anchored,
		hidden = {},
	}, Session)
	WorldView.current = s

	hrp.Anchored = true
	pcall(function()
		s.controls = require(player.PlayerScripts:WaitForChild("PlayerModule", 2)):GetControls()
		s.controls:Disable()
	end)
	local keep = {}
	for _, g in ipairs(opts.keep or {}) do
		keep[g] = true
	end
	for _, g in ipairs(player.PlayerGui:GetChildren()) do
		if g:IsA("ScreenGui") and g.Enabled and not keep[g] and g.Name ~= "Freecam" then
			g.Enabled = false
			table.insert(s.hidden, g)
		end
	end
	camera.CameraType = Enum.CameraType.Scriptable

	s.conn = RunService.RenderStepped:Connect(function(dt)
		s.t += dt
		s.clock += dt
		if s.phase == "open" and s.t >= s.openTime then
			s.phase = "shown"
			s.t = 0
			if opts.onShown then
				opts.onShown(s)
			end
		elseif s.phase == "close" and s.t >= s.closeTime then
			s:finish()
			return
		end
		if not s.hrp.Parent then
			s:finish()
			return
		end
		local k = s:blendNow()
		local goal = opts.goal(s, dt)
		-- (re-asserted every frame: other scripts, and the Studio MCP, reset the camera type)
		camera.CameraType = Enum.CameraType.Scriptable
		camera.CFrame = s.savedCam:Lerp(goal, k)
		if opts.fov then
			camera.FieldOfView = s.savedFov + (opts.fov - s.savedFov) * k
		end
		if opts.onStep then
			opts.onStep(s, dt, k)
		end
	end)
	return s
end

-- closes the running view (if any)
function WorldView.close()
	if WorldView.current then
		WorldView.current:close()
	end
end

return WorldView
