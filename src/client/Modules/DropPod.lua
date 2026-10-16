-- Malak's drop pod (black chrome, silver edges, cold-blue seams, six blade petals like his coat), shared by his pull
-- cinematic (SovereignArrival, full size) and his special, the Requisition (RequisitionFx, smaller).
--
--   local pod = DropPod.build(folder, scale)
--   pod.place(baseCF, open, glow)   baseCF = the pod's floor centre (LookVector = its front); open 0..1 (closed .. petals
--                                   folded out flat; a little overshoot can be baked in by the caller); glow 0..1 (seams)
--   pod.setHidden(hidden)
--   pod.ports, pod.inner, pod.light, pod.crown, pod.seams, pod.parts
--   pod.radius, pod.height, pod.base (the scaled sizes)
local Workspace = game:GetService("Workspace")

local DropPod = {}

DropPod.PETALS = 6
DropPod.RADIUS = 4.6 -- (the base ring, at scale 1)
DropPod.HEIGHT = 14 -- (crown tip above the base ring)
DropPod.BASE = 1.4 -- (the base ring's height)
local OPEN = math.rad(92) -- (how far each petal folds out: down flat onto the ground)

local CHROME = Color3.fromRGB(28, 28, 36)
local SILVER = Color3.fromRGB(176, 180, 196)
local VIOLET = Color3.fromRGB(44, 30, 74)
local GLOW = Color3.fromRGB(165, 180, 255)
local GLOW_CORE = Color3.fromRGB(235, 240, 255)

local function newPart(parent, size, color, material, shape)
	local p = Instance.new("Part")
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.Neon
	if shape then
		p.Shape = shape
	end
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Parent = parent
	return p
end

function DropPod.build(folder, scale)
	scale = scale or 1
	local R, H, B = DropPod.RADIUS * scale, DropPod.HEIGHT * scale, DropPod.BASE * scale
	local PETALS = DropPod.PETALS
	local pod = { parts = {}, offsets = {}, petalOf = {}, radius = R, height = H, base = B }
	local function add(p, petal, offset)
		table.insert(pod.parts, p)
		pod.offsets[p] = offset
		pod.petalOf[p] = petal
	end
	-- the base ring: dark chrome, a silver rim, glowing thruster ports underneath
	add(newPart(folder, Vector3.new(B, R * 2.15, R * 2.15), CHROME, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder), nil,
		CFrame.new(0, B / 2, 0) * CFrame.Angles(0, 0, math.pi / 2))
	add(newPart(folder, Vector3.new(0.35 * scale, R * 2.3, R * 2.3), SILVER, Enum.Material.Metal, Enum.PartType.Cylinder), nil,
		CFrame.new(0, B + 0.05 * scale, 0) * CFrame.Angles(0, 0, math.pi / 2))
	pod.ports = {}
	for k = 0, PETALS - 1 do
		local a = (k + 0.5) / PETALS * math.pi * 2
		local port = newPart(folder, Vector3.new(0.3, 1.3, 1.3) * scale, GLOW, Enum.Material.Neon, Enum.PartType.Cylinder)
		add(port, nil, CFrame.new(math.cos(a) * R * 0.6, -0.12 * scale, math.sin(a) * R * 0.6) * CFrame.Angles(0, 0, math.pi / 2))
		table.insert(pod.ports, port)
	end
	-- the core light inside (seen when the petals open)
	local inner = newPart(folder, Vector3.new(0.2 * scale, R * 1.6, R * 1.6), GLOW_CORE, Enum.Material.Neon, Enum.PartType.Cylinder)
	add(inner, nil, CFrame.new(0, B + 0.2 * scale, 0) * CFrame.Angles(0, 0, math.pi / 2))
	pod.inner = inner
	local light = Instance.new("PointLight")
	light.Color = GLOW
	light.Range = 18 * scale
	light.Brightness = 0
	light.Shadows = false
	light.Parent = inner
	pod.light = light

	-- the petals: blade plates leaning in from the base ring to the crown. Each petal's parts are placed in its own
	-- frame: origin at the hinge on the ring, +Y up the blade, +Z its outer face, X across.
	local L = math.sqrt(R ^ 2 + H ^ 2)
	local w = 2 * R * math.tan(math.pi / PETALS) * 1.12 -- (a little wider than the gaps: no light shows through)
	local t = 0.5 * scale
	pod.lean = math.atan2(R, H)
	pod.seams = {}
	for k = 0, PETALS - 1 do
		local petal = { angle = k / PETALS * math.pi * 2 }
		add(newPart(folder, Vector3.new(w, L, t), CHROME, Enum.Material.SmoothPlastic), petal, CFrame.new(0, L / 2, 0))
		-- the inner violet lining (seen when it opens), the silver edges standing proud, the cold seam down the middle
		add(newPart(folder, Vector3.new(w * 0.82, L * 0.9, 0.12 * scale), VIOLET, Enum.Material.SmoothPlastic), petal, CFrame.new(0, L * 0.46, -t / 2 - 0.04 * scale))
		for _, s in ipairs({ -1, 1 }) do
			add(newPart(folder, Vector3.new(0.32 * scale, L - 0.4 * scale, t + 0.16 * scale), SILVER, Enum.Material.Metal), petal, CFrame.new(s * (w / 2 + 0.04 * scale), L / 2 - 0.1 * scale, 0))
		end
		local seam = newPart(folder, Vector3.new(0.28 * scale, L * 0.78, 0.14 * scale), GLOW, Enum.Material.Neon)
		add(seam, petal, CFrame.new(0, L * 0.45, t / 2 + 0.05 * scale))
		table.insert(pod.seams, seam)
		-- his diamond emblem low on each petal
		add(newPart(folder, Vector3.new(1.1 * scale, 1.1 * scale, 0.2 * scale), SILVER, Enum.Material.Metal), petal, CFrame.new(0, L * 0.2, t / 2 + 0.1 * scale) * CFrame.Angles(0, 0, math.rad(45)))
	end
	-- the crown: a glowing spike where the tips meet (it falls away when the petals open)
	local crown = newPart(folder, Vector3.new(0.9, 2.6, 0.9) * scale, GLOW_CORE, Enum.Material.Neon)
	add(crown, nil, CFrame.new(0, B + H + 0.9 * scale, 0))
	pod.crown = crown

	function pod.place(baseCF, open, glow)
		local moveParts, moveCFrames = {}, {}
		local floor = baseCF * CFrame.new(0, B, 0)
		for _, p in ipairs(pod.parts) do
			local petal = pod.petalOf[p]
			local cf
			if petal then
				-- hinge on the ring, facing out; closed it leans in, open it folds out and down
				local hinge = floor * CFrame.Angles(0, -petal.angle, 0) * CFrame.new(0, 0, -R) * CFrame.Angles(0, math.pi, 0)
				local tilt = -pod.lean + (pod.lean + OPEN) * open
				cf = hinge * CFrame.Angles(tilt, 0, 0) * pod.offsets[p]
			else
				cf = baseCF * pod.offsets[p]
			end
			table.insert(moveParts, p)
			table.insert(moveCFrames, cf)
		end
		Workspace:BulkMoveTo(moveParts, moveCFrames, Enum.BulkMoveMode.FireCFrameChanged)
		for _, s in ipairs(pod.seams) do
			s.Transparency = 0.45 - 0.4 * glow
		end
		pod.crown.Transparency = math.clamp(open * 3, 0, 1)
	end
	function pod.setHidden(hidden)
		for _, p in ipairs(pod.parts) do
			p.LocalTransparencyModifier = hidden and 1 or 0
		end
	end
	return pod
end

return DropPod
