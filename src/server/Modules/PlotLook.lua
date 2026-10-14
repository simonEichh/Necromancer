-- The realm's look on a claimed plot (ServerStorage.LaneModels.CemeteryPlot, built by tools/studio/build_plot_cemetery.lua):
-- the plot becomes part of the realm like its lane, so the cut between the neutral plaza stone and the realm sits at the
-- plot's entrance. Applied when a plot is claimed (Plots), removed when the player leaves: the plot's neutral Style parts
-- it replaces (the model's attribute Hides) are hidden meanwhile, and the Base is recoloured (FloorColor / FloorMaterial).
local ServerStorage = game:GetService("ServerStorage")
local Collision = require(script.Parent.Collision)

local PlotLook = {}

-- the look of the plot owner's realm (only Realm 1 exists so far)
local function templateFor(_plotState)
	local folder = ServerStorage:FindFirstChild("LaneModels")
	return folder and folder:FindFirstChild("CemeteryPlot")
end

function PlotLook.clear(plotState)
	local look = plotState.look
	if not look then return end
	plotState.look = nil
	if look.model then
		look.model:Destroy()
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

	local model = template:Clone()
	model.Name = "PlotLook_" .. plotState.plotIndex
	model:PivotTo(plotState.frame)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and d.CanCollide then
			d.CollisionGroup = Collision.DECOR -- (the side walls: players are kept on the plot, units ignore them)
		elseif d:IsA("TextLabel") and d.Name == "PlotNumber" then
			d.Text = "PLOT " .. plotState.plotIndex
		end
	end
	model.Parent = workspace
	look.model = model
	plotState.look = look
end

return PlotLook
