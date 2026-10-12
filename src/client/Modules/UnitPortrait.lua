-- A small 3D portrait of a unit (its real model in a ViewportFrame), for slots in the hotbar and the inventory.
--
--   local p = UnitPortrait.attach(slotFrame, { position = UDim2.new(0, 0, 0.06, 0), size = UDim2.new(1, 0, 0.62, 0), zIndex = 3 })
--   p.set("Skelly")  -- shows the model (does nothing if it already shows it)
--   p.set(nil)       -- clears it
--
-- The models come from ReplicatedStorage.UnitModels (tools/studio/publish_unit_models.lua). A slot keeps its ViewportFrame
-- and camera and only swaps the model when the unit type changes, so refreshing a full inventory is cheap.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UnitPortrait = {}

local VIEW_ANGLE = math.rad(-25) -- a slight turn from the front, so the unit looks 3D
local FOV = 36

function UnitPortrait.attach(parent, opts)
	opts = opts or {}
	local vp = Instance.new("ViewportFrame")
	vp.BackgroundTransparency = 1
	vp.Size = opts.size or UDim2.fromScale(1, 1)
	vp.Position = opts.position or UDim2.new()
	vp.Ambient = Color3.fromRGB(175, 175, 185)
	vp.LightColor = Color3.fromRGB(255, 244, 230)
	vp.LightDirection = Vector3.new(-0.4, -0.7, -0.6)
	vp.ZIndex = opts.zIndex or 2
	vp.Visible = false
	vp.Parent = parent

	local cam = Instance.new("Camera")
	cam.FieldOfView = FOV
	cam.Parent = vp
	vp.CurrentCamera = cam

	local handle = { viewport = vp }
	local shown = nil -- the unit type currently in the viewport
	local model = nil

	function handle.set(unitType)
		if unitType == shown then
			return
		end
		shown = unitType
		if model then
			model:Destroy()
			model = nil
		end
		if not unitType then
			vp.Visible = false
			return
		end
		local folder = ReplicatedStorage:FindFirstChild("UnitModels")
		local template = folder and folder:FindFirstChild(unitType)
		if not template then
			vp.Visible = false
			return
		end
		model = template:Clone()
		model.Parent = vp
		-- centre the model's bounding box on the origin and look at it from the front
		local boxCFrame, boxSize = model:GetBoundingBox()
		local offset = model:GetPivot():ToObjectSpace(boxCFrame).Position
		model:PivotTo(CFrame.Angles(0, VIEW_ANGLE, 0) * CFrame.new(-offset))
		local radius = boxSize.Magnitude / 2
		local dist = radius / math.tan(math.rad(FOV / 2)) * 1.0
		cam.CFrame = CFrame.lookAt(Vector3.new(0, 0, -dist), Vector3.zero)
		vp.Visible = true
	end

	return handle
end

return UnitPortrait
