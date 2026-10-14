-- The necromancer's ritual, shared by the pull cinematics (GraveCinematic, StarSummon, SignatureDescent): the player's own
-- character works dark magic on what the pull comes out of, and absorbs the unit into a spectral grimoire at the end.
--
--   local ritual = NecroRitual.new({ hrp = humanoidRootPart, folder = fxFolder, target = part, smokeAt = part?,
--                                    feet = Vector3, color = rarity colour })
--   ritual.update(weight, shine, aim)   every frame while casting: weight 0..1 (pose, threads, circle, smoke),
--                                       shine 0..1 (the colour goes from violet to the rarity colour),
--                                       aim "forward" (hands towards the target in front) or "up" (raised to the sky)
--   ritual.look(point, weight)          the character looks at `point` (e.g. up at the sky), weight 0..1
--   ritual.absorb(a, unit)              every frame of the absorb, a = 0..1: the grimoire opens at the left hand, the unit
--                                       shrinks into a stream of soul light flying into it, the book snaps shut.
--                                       Returns true on the frame the unit vanished (the caller can flash).
--   ritual.restore()                    removes everything put into the character (call when the cinematic ends)
--
-- The arms are posed with IKControls (R15 only; the joints of current avatars cannot be changed directly), so R6
-- characters keep their pose but still get the threads, the circle and the grimoire. Purely client side.
local MagicCircle = require(script.Parent.MagicCircle)

local NecroRitual = {}

local VIOLET = Color3.fromRGB(150, 70, 255)
local DARK = Color3.fromRGB(70, 30, 110)
local RUNE = Color3.fromRGB(200, 160, 255)
local UP = Vector3.yAxis

local function smooth(x)
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

local function plainPart(parent, name, size)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size
	p.Parent = parent
	return p
end

function NecroRitual.new(opts)
	local r = { owned = {}, threads = {}, sparks = {} }
	local hrp = opts.hrp
	local folder = opts.folder
	local color = opts.color or Color3.new(1, 1, 1)
	local c = hrp.Parent
	r.feet = opts.feet or (hrp.Position - Vector3.new(0, 3, 0))

	-- ============================================================
	-- The arms: an IKControl per arm reaches each hand for a target point the ritual moves
	-- ============================================================
	local humanoid = c and c:FindFirstChildOfClass("Humanoid")
	local arms = {}
	for _, spec in ipairs({ { "RightUpperArm", "RightHand", 1 }, { "LeftUpperArm", "LeftHand", -1 } }) do
		local upper, hand = c and c:FindFirstChild(spec[1]), c and c:FindFirstChild(spec[2])
		if humanoid and upper and hand then
			local holder = plainPart(folder, "IKTarget", Vector3.one * 0.2)
			holder.Transparency = 1
			local target = Instance.new("Attachment")
			target.Parent = holder
			local ik = Instance.new("IKControl")
			ik.Type = Enum.IKControlType.Position
			ik.ChainRoot = upper
			ik.EndEffector = hand
			ik.Target = target
			ik.Weight = 0
			ik.Parent = humanoid
			table.insert(arms, { ik = ik, holder = holder, side = spec[3] })
		end
	end
	-- lift 0..1, trembling with the strain; aim "up" raises the hands to the sky; holdLeft: the left hand holds the
	-- grimoire up in front of the chest
	function r.pose(lift, tremble, holdLeft, aim)
		local body = hrp.CFrame
		for _, a in ipairs(arms) do
			local reach
			if holdLeft and a.side == -1 then
				reach = body * CFrame.new(-0.7, 0.5, -1.8)
			elseif aim == "up" then
				reach = body * CFrame.new(a.side * 1.3, 4.2, -1.2) -- both arms raised high, a little forward
			else
				reach = body * CFrame.new(a.side * 1.1, 1.6, -2.6) -- in front, shoulders high, towards the target
			end
			local shiver = Vector3.new(math.sin(os.clock() * 31 + a.side), math.cos(os.clock() * 27 + a.side), 0) * 0.08 * tremble
			a.holder.CFrame = reach + shiver
			a.ik.Weight = (holdLeft and a.side == -1) and 1 or lift
		end
	end

	-- the head: an IKControl from the upper body to the head that makes the character look at a point (look up at the sky)
	local lookIk, lookHolder
	local upperTorso, head = c and c:FindFirstChild("UpperTorso"), c and c:FindFirstChild("Head")
	if humanoid and upperTorso and head then
		lookHolder = plainPart(folder, "LookTarget", Vector3.one * 0.2)
		lookHolder.Transparency = 1
		local target = Instance.new("Attachment")
		target.Parent = lookHolder
		lookIk = Instance.new("IKControl")
		lookIk.Type = Enum.IKControlType.LookAt
		lookIk.ChainRoot = upperTorso
		lookIk.EndEffector = head
		lookIk.Target = target
		lookIk.Weight = 0
		lookIk.Parent = humanoid
	end
	function r.look(point, weight)
		if lookIk then
			lookHolder.CFrame = CFrame.new(point)
			lookIk.Weight = weight
		end
	end

	-- ============================================================
	-- The threads: two wavering ghostly beams from each hand to the target
	-- ============================================================
	local endAt = Instance.new("Attachment")
	endAt.Parent = opts.target
	table.insert(r.owned, endAt)
	local function handPart(r15, r6)
		return c and (c:FindFirstChild(r15) or c:FindFirstChild(r6))
	end
	for _, h in ipairs({ handPart("RightHand", "Right Arm"), handPart("LeftHand", "Left Arm") }) do
		if h then
			local a0 = Instance.new("Attachment")
			a0.Position = Vector3.new(0, -h.Size.Y / 2, 0)
			a0.Parent = h
			table.insert(r.owned, a0)
			for _ = 1, 2 do
				local beam = Instance.new("Beam")
				beam.Attachment0 = a0
				beam.Attachment1 = endAt
				beam.LightEmission = 1
				beam.LightInfluence = 0
				beam.FaceCamera = true
				beam.Width0 = 0.5
				beam.Width1 = 1.1
				beam.Segments = 30
				beam.Texture = "rbxasset://textures/particles/sparkles_main.dds"
				beam.TextureMode = Enum.TextureMode.Wrap
				beam.TextureLength = 4
				beam.TextureSpeed = 2.5
				beam.Transparency = NumberSequence.new(1)
				beam.Parent = h
				table.insert(r.owned, beam)
				table.insert(r.threads, { beam = beam, k = #r.threads + 1 })
			end
			-- soul sparks pouring off the hand
			local e = Instance.new("ParticleEmitter")
			e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
			e.LightEmission = 1
			e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
			e.Lifetime = NumberRange.new(0.4, 0.8)
			e.Speed = NumberRange.new(2, 5)
			e.SpreadAngle = Vector2.new(40, 40)
			e.Rate = 0
			e.Parent = a0
			table.insert(r.owned, e)
			table.insert(r.sparks, e)
		end
	end

	-- dark smoke round the target (optional), a necromantic circle under the necromancer's feet
	if opts.smokeAt then
		local smoke = Instance.new("ParticleEmitter")
		smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
		smoke.Color = ColorSequence.new(DARK, Color3.fromRGB(20, 12, 30))
		smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 5) })
		smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1) })
		smoke.Lifetime = NumberRange.new(1.2, 2)
		smoke.Speed = NumberRange.new(1, 3)
		smoke.SpreadAngle = Vector2.new(180, 180)
		smoke.Rotation = NumberRange.new(0, 360)
		smoke.RotSpeed = NumberRange.new(-60, 60)
		smoke.Rate = 0
		smoke.Parent = opts.smokeAt
		table.insert(r.owned, smoke)
		r.smoke = smoke
	end
	r.circle = MagicCircle.build(folder, 3.6, VIOLET, RUNE)

	function r.update(weight, shine, aim)
		r.pose(weight, weight, false, aim)
		local col = VIOLET:Lerp(color, shine or 0)
		local seq = ColorSequence.new(col:Lerp(Color3.new(1, 1, 1), 0.25), col)
		for _, th in ipairs(r.threads) do
			th.beam.Color = seq
			th.beam.Transparency = NumberSequence.new(1 - weight * (0.75 + 0.15 * math.sin(os.clock() * 7 + th.k)))
			-- the threads waver like smoke
			th.beam.CurveSize0 = math.sin(os.clock() * 2.3 + th.k * 1.7) * 3 * weight
			th.beam.CurveSize1 = math.cos(os.clock() * 1.9 + th.k) * 4 * weight
			th.beam.Width1 = 1.1 + (shine or 0) * 0.8
		end
		for _, e in ipairs(r.sparks) do
			e.Color = ColorSequence.new(col)
			e.Rate = 30 * weight
		end
		if r.smoke then
			r.smoke.Rate = 25 * weight
		end
		MagicCircle.place(r.circle, CFrame.new(r.feet + UP * 0.12) * CFrame.Angles(0, os.clock() * 0.8, 0), 0.4 + 0.6 * weight, 1 - 0.85 * weight)
	end

	-- ============================================================
	-- The grimoire and the absorb
	-- ============================================================
	local function book()
		if r.tome then
			return r.tome
		end
		local m = Instance.new("Model")
		m.Name = "Grimoire"
		local function bpart(name, size, col, material)
			local b = plainPart(m, name, size)
			b.Color = col
			b.Material = material
			return b
		end
		local tome = {
			left = bpart("Cover", Vector3.new(1.3, 0.12, 1.8), Color3.fromRGB(40, 22, 30), Enum.Material.Leather),
			right = bpart("Cover", Vector3.new(1.3, 0.12, 1.8), Color3.fromRGB(40, 22, 30), Enum.Material.Leather),
			pagesL = bpart("Pages", Vector3.new(1.15, 0.18, 1.6), Color3.fromRGB(200, 255, 220), Enum.Material.Neon),
			pagesR = bpart("Pages", Vector3.new(1.15, 0.18, 1.6), Color3.fromRGB(200, 255, 220), Enum.Material.Neon),
			spine = bpart("Spine", Vector3.new(0.2, 0.3, 1.8), Color3.fromRGB(110, 70, 40), Enum.Material.CorrodedMetal),
			circle = MagicCircle.build(folder, 1.6, VIOLET, RUNE),
		}
		local glow = Instance.new("PointLight")
		glow.Color = color
		glow.Range = 12
		glow.Brightness = 0
		glow.Shadows = false
		glow.Parent = tome.spine
		tome.light = glow
		m.Parent = folder
		r.tome = tome
		return tome
	end
	-- places the grimoire in front of the left hand (open 0..1: covers from shut to flat; shown 0..1); returns the point
	-- above its pages
	local function placeBook(open, shown)
		local tome = book()
		local hinge = hrp.CFrame * CFrame.new(-0.9, 0.6, -2.4) * CFrame.Angles(math.rad(-30), 0, 0) -- (tilted to the camera)
		local angle = math.rad(85) * (1 - open)
		tome.spine.CFrame = hinge
		tome.left.CFrame = hinge * CFrame.Angles(0, 0, angle) * CFrame.new(-0.7, 0, 0)
		tome.right.CFrame = hinge * CFrame.Angles(0, 0, -angle) * CFrame.new(0.7, 0, 0)
		tome.pagesL.CFrame = hinge * CFrame.Angles(0, 0, angle) * CFrame.new(-0.62, 0.12, 0)
		tome.pagesR.CFrame = hinge * CFrame.Angles(0, 0, -angle) * CFrame.new(0.62, 0.12, 0)
		for _, part in ipairs({ tome.left, tome.right, tome.pagesL, tome.pagesR, tome.spine }) do
			part.LocalTransparencyModifier = 1 - shown
		end
		tome.light.Brightness = 4 * open
		MagicCircle.place(tome.circle, hinge * CFrame.new(0, -0.6, 0) * CFrame.Angles(0, os.clock() * 1.5, 0), 0.6 + 0.4 * shown, 1 - 0.8 * shown * open)
		return hinge.Position + hinge.UpVector * 0.4
	end

	function r.absorb(a, unit)
		r.update(0, 0)
		r.look(hrp.Position, 0)
		r.pose(0, 0, true)
		local open = smooth(a / 0.25) * (1 - smooth((a - 0.85) / 0.15))
		local bookAt = placeBook(open, smooth(a / 0.2))
		if not (unit and unit.Parent) then
			return false
		end
		local pull = smooth((a - 0.15) / 0.65)
		if not r.unitScale then
			r.unitScale = unit:GetScale()
			r.unitFrom = unit:GetPivot()
			local trail = Instance.new("ParticleEmitter")
			trail.Texture = "rbxasset://textures/particles/sparkles_main.dds"
			trail.Color = ColorSequence.new(color, Color3.new(1, 1, 1))
			trail.LightEmission = 1
			trail.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 0) })
			trail.Lifetime = NumberRange.new(0.3, 0.6)
			trail.Rate = 80
			trail.Speed = NumberRange.new(0.5, 2)
			trail.Parent = unit.PrimaryPart or unit:FindFirstChildWhichIsA("BasePart")
		end
		if pull < 1 then
			unit:ScaleTo(math.max(0.02, r.unitScale * (1 - 0.97 * pull)))
			local pos = r.unitFrom.Position:Lerp(bookAt, pull) + UP * math.sin(pull * math.pi) * 3
			unit:PivotTo(CFrame.new(pos) * r.unitFrom.Rotation * CFrame.Angles(0, pull * 8, 0))
			return false
		end
		unit:Destroy()
		return true
	end

	function r.restore()
		for _, a in ipairs(arms) do
			a.ik:Destroy()
		end
		arms = {}
		if lookIk then
			lookIk:Destroy()
			lookIk = nil
		end
		for _, inst in ipairs(r.owned) do
			inst:Destroy()
		end
		r.owned = {}
	end

	return r
end

return NecroRitual
