-- The 3D grave in the gacha reveal: a ViewportFrame with the grave's real model (ReplicatedStorage.GraveModels.<key>,
-- built by tools/studio/build_grave_<tier>.lua) that glows and bursts open.
--
--   local g = GraveOpening.create(parent, graveType, size, zIndex)  -- nil when the grave has no model yet
--   g.frame                     the ViewportFrame (place, shake and fade it like any GUI object)
--   g.setGlow(color, amount)    amount 0..1: the soul-light cracks shift towards `color` (the buildup hint)
--   g.burst(color, t)           opens the grave (by its OpenStyle), the pit lights up, a light column rises; t = 0..1
--                               how rare the pull is (more debris and a bigger column for rarer pulls)
--   g.destroy()
--
-- Model conventions (see build_grave_mossy.lua): front faces -Z, models "Body" / "Lid" / "Pit", part "Core", parts named
-- "Glow" are the soul-light cracks, attributes OpenStyle and GlowColor.
-- TODO (agreed with the user): higher grave tiers get more opening effects; add them here, driven by the tier.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GraveOpening = {}

local GRAVITY = Vector3.new(0, -38, 0)

function GraveOpening.create(parent, graveType, size, zIndex)
	local folder = ReplicatedStorage:FindFirstChild("GraveModels")
	local template = folder and graveType and folder:FindFirstChild(graveType)
	if not template then
		return nil
	end

	local vp = Instance.new("ViewportFrame")
	vp.BackgroundTransparency = 1
	vp.Size = size
	vp.Ambient = Color3.fromRGB(150, 150, 165)
	vp.LightColor = Color3.fromRGB(255, 240, 225)
	vp.LightDirection = Vector3.new(0.5, -0.8, 0.4)
	vp.ZIndex = zIndex or 1
	vp.Parent = parent

	local model = template:Clone()
	model:PivotTo(CFrame.new())
	model.Parent = vp

	-- camera: front three-quarter view from above (the front of a grave faces -Z), framing the whole model
	local boxCf, boxSize = model:GetBoundingBox()
	local center = boxCf.Position
	local cam = Instance.new("Camera")
	cam.FieldOfView = 32
	local radius = boxSize.Magnitude / 2
	local dist = radius / math.tan(math.rad(cam.FieldOfView / 2)) * 0.82
	cam.CFrame = CFrame.lookAt(center + Vector3.new(-0.45, 0.62, -1).Unit * dist, center)
	cam.Parent = vp
	vp.CurrentCamera = cam

	local glowParts, glowBase = {}, {}
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and d.Name == "Glow" then
			table.insert(glowParts, d)
			glowBase[d] = d.Color
		end
	end
	local core = model:FindFirstChild("Core")
	local corePos = core and core.Position or center
	local lid = model:FindFirstChild("Lid")
	local pit = model:FindFirstChild("Pit")

	local g = { frame = vp, model = model, dead = false }

	function g.setGlow(color, amount)
		for _, p in ipairs(glowParts) do
			if p.Parent then
				p.Color = glowBase[p]:Lerp(color, math.clamp(amount, 0, 1))
			end
		end
	end

	-- one flying piece: velocity, spin, fade
	local flying = {}
	local function launch(p, vel, spin, fadeTime)
		p.Anchored = true
		table.insert(flying, { part = p, cf = p.CFrame, vel = vel, spin = spin, t0 = os.clock(), trans = p.Transparency, fade = fadeTime })
	end
	local function debris(color, count, speed, sizeMin, sizeMax)
		for _ = 1, count do
			local s = sizeMin + math.random() * (sizeMax - sizeMin)
			local p = Instance.new("Part")
			p.Size = Vector3.new(s, s * 0.8, s)
			p.Color = color
			p.Material = Enum.Material.Ground
			p.CFrame = CFrame.new(corePos + Vector3.new((math.random() - 0.5) * 2, 0.6, (math.random() - 0.5) * 3))
				* CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6)
			p.Parent = model
			local dir = Vector3.new(math.random() - 0.5, 0, math.random() - 0.5)
			dir = (dir.Magnitude > 0.01 and dir.Unit or Vector3.xAxis) * speed * (0.4 + math.random() * 0.6)
			launch(p, dir + Vector3.new(0, speed * (0.9 + math.random() * 0.8), 0),
				Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 14)
		end
	end

	function g.burst(color, t)
		t = t or 0
		local style = model:GetAttribute("OpenStyle") or "Mound"
		-- the lid flies apart: small pieces are thrown out of the middle, the big earth masses collapse into the pit
		if lid then
			for _, p in ipairs(lid:GetDescendants()) do
				if p:IsA("BasePart") then
					local big = math.max(p.Size.X, p.Size.Y, p.Size.Z) > 2.5
					if big and style == "Mound" then
						launch(p, Vector3.new(0, 1.5, 0), Vector3.zero, 0.15) -- the mound itself vanishes in the burst (the flash hides it)
					else
						local out = p.Position - corePos
						out = Vector3.new(out.X, 0, out.Z)
						out = (out.Magnitude > 0.05 and out.Unit or Vector3.new(math.random() - 0.5, 0, math.random() - 0.5).Unit)
						local speed = 7 + math.random() * 6
						launch(p, out * speed + Vector3.new(0, 11 + math.random() * 9, 0),
							Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 12)
					end
				end
			end
		end
		-- clods of earth thrown up out of the hole (more for rarer pulls)
		debris(Color3.fromRGB(96, 66, 46), math.floor(10 + 14 * t), 10 + 6 * t, 0.25, 0.6)
		-- the pit lights up in the pull's colour
		if pit then
			for _, p in ipairs(pit:GetDescendants()) do
				if p:IsA("BasePart") and p.Name == "Glow" then
					p.Color = color
				end
			end
		end
		for _, p in ipairs(glowParts) do
			p.Color = color
		end
		-- a column of light out of the grave
		local column = Instance.new("Part")
		column.Shape = Enum.PartType.Cylinder
		column.Material = Enum.Material.Neon
		column.Color = color
		column.Transparency = 0.25
		column.Size = Vector3.new(0.1, 0.6, 0.6)
		column.Parent = model
		local inner = column:Clone()
		inner.Color = Color3.new(1, 1, 1):Lerp(color, 0.35)
		inner.Transparency = 0.1
		inner.Parent = model
		local colStart = os.clock()
		local width = 1.6 + 1.6 * t
		local height = 10 + 8 * t

		local conn
		conn = RunService.RenderStepped:Connect(function()
			if g.dead or not vp.Parent then -- destroyed, or the reveal closed
				conn:Disconnect()
				return
			end
			local now = os.clock()
			for i = #flying, 1, -1 do
				local f = flying[i]
				local age = now - f.t0
				if f.part.Parent then
					local pos = f.cf.Position + f.vel * age + (f.fade and Vector3.zero or GRAVITY * (0.5 * age * age))
					f.part.CFrame = CFrame.new(pos) * (f.cf - f.cf.Position) * CFrame.Angles(f.spin.X * age, f.spin.Y * age, f.spin.Z * age)
					if f.fade then
						f.part.Transparency = f.trans + (1 - f.trans) * math.clamp(age / f.fade, 0, 1)
					else
						f.part.Transparency = f.trans + (1 - f.trans) * math.clamp((age - 0.35) / 0.5, 0, 1)
					end
				end
				if age > 1 then
					f.part:Destroy()
					table.remove(flying, i)
				end
			end
			-- the column shoots up, widens, then thins out
			local a = now - colStart
			local up = math.clamp(a / 0.25, 0, 1)
			local h = height * up
			local w = width * (a < 0.3 and (0.4 + 2 * a) or math.max(0.15, 1 - (a - 0.3) * 0.9))
			column.Size = Vector3.new(h, w, w)
			column.CFrame = CFrame.new(corePos + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, 0, math.rad(90))
			inner.Size = Vector3.new(h, w * 0.45, w * 0.45)
			inner.CFrame = column.CFrame
			if a > 1.2 then
				column.Transparency = math.min(1, column.Transparency + 0.04)
				inner.Transparency = math.min(1, inner.Transparency + 0.04)
			end
		end)
	end

	function g.destroy()
		g.dead = true
		vp:Destroy()
	end

	return g
end

return GraveOpening
