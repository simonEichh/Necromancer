-- Veyr's focusing sights (docs/veyr.md): the one shape his whole kit is built from. A sight stands upright across the
-- shot axis: a thin outer ring with four diamond nodes on the diagonals, four short ticks pointing in from the
-- cardinals (never reaching the centre), four small pointed spikes outside the cardinals and a dashed inner ring.
-- The basic shot uses small ones at the muzzle, the special big ones down the lane, the finisher huge ones.
--
--   local s = VeyrSights.build(parent, radius, color, core, opts)   opts: segments (16), inner (true), spikes, ticks, nodes (true)
--   VeyrSights.place(s, hubCf, scale, alpha, spin)   hubCf looks along the shot axis; the sight lies in its XY plane;
--                                                    scale opens it, alpha 0..1 fades it, spin turns it about the axis
--   VeyrSights.tint(s, color, coreColor)             recolour (the flash as the round passes)
--   VeyrSights.hide(s)  /  VeyrSights.destroy(s)
-- Everything is anchored neon parts moved locally; build once and reuse (VeyrShot keeps one set per unit).
local VeyrSights = {}

local function newPart(parent, size, color)
	local p = Instance.new("Part")
	p.Size = size
	p.Color = color
	p.Material = Enum.Material.Neon
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Transparency = 1
	p.Parent = parent
	return p
end

function VeyrSights.build(parent, radius, color, core, opts)
	opts = opts or {}
	local s = { parts = {}, offsets = {}, sizes = {}, base = {}, isCore = {}, radius = radius, scale = -1 }
	local w = math.max(0.035, radius * 0.05)
	local thin = math.max(0.02, w * 0.5)
	local function add(size, offset, isCore, baseT)
		local p = newPart(parent, size, isCore and core or color)
		table.insert(s.parts, p)
		table.insert(s.offsets, offset)
		table.insert(s.sizes, size)
		table.insert(s.base, baseT or 0)
		table.insert(s.isCore, isCore or false)
		return p
	end
	-- the outer ring
	local n = opts.segments or 16
	local seg = 2 * math.pi * radius / n * 1.02
	for k = 0, n - 1 do
		local a = k / n * 2 * math.pi
		add(Vector3.new(seg, w, thin), CFrame.Angles(0, 0, a) * CFrame.new(0, radius, 0))
	end
	for k = 0, 3 do
		local a = k * math.pi / 2
		-- the ticks pointing in from the cardinals
		if opts.ticks ~= false then add(Vector3.new(w * 0.8, radius * 0.24, thin), CFrame.Angles(0, 0, a) * CFrame.new(0, radius * 0.8, 0), false, 0.1) end
		-- the diamond nodes on the diagonals
		if opts.nodes ~= false then add(Vector3.new(w * 2.6, w * 2.6, thin * 1.4), CFrame.Angles(0, 0, a + math.pi / 4) * CFrame.new(0, radius, 0)
			* CFrame.Angles(0, 0, math.pi / 4), true) end
		-- the spikes outside the cardinals (a short bar and a finer point)
		if opts.spikes ~= false then
			add(Vector3.new(w * 0.9, radius * 0.16, thin), CFrame.Angles(0, 0, a) * CFrame.new(0, radius * 1.1, 0))
			add(Vector3.new(w * 0.45, radius * 0.12, thin), CFrame.Angles(0, 0, a) * CFrame.new(0, radius * 1.24, 0), true)
		end
	end
	-- the dashed inner ring
	if opts.inner ~= false then
		local r2 = radius * 0.58
		local m = opts.innerCount or 12
		local seg2 = 2 * math.pi * r2 / m * 0.55
		for k = 0, m - 1 do
			local a = (k + 0.5) / m * 2 * math.pi
			add(Vector3.new(seg2, w * 0.7, thin), CFrame.Angles(0, 0, a) * CFrame.new(0, r2, 0), false, 0.25)
		end
	end
	return s
end

function VeyrSights.place(s, hubCf, scale, alpha, spin)
	scale = math.max(scale, 0.01)
	local resize = math.abs(scale - s.scale) > 0.015
	if resize then
		s.scale = scale
	end
	local spun = spin and spin ~= 0 and hubCf * CFrame.Angles(0, 0, spin) or hubCf
	for i, p in ipairs(s.parts) do
		local o = s.offsets[i]
		p.CFrame = spun * (CFrame.new(o.Position * scale) * o.Rotation)
		if resize then
			p.Size = s.sizes[i] * scale
		end
		p.Transparency = 1 - (1 - s.base[i]) * math.clamp(alpha, 0, 1)
	end
end

function VeyrSights.tint(s, color, coreColor)
	for i, p in ipairs(s.parts) do
		p.Color = s.isCore[i] and (coreColor or color) or color
	end
end

function VeyrSights.hide(s)
	for _, p in ipairs(s.parts) do
		p.Transparency = 1
	end
end

function VeyrSights.destroy(s)
	for _, p in ipairs(s.parts) do
		p:Destroy()
	end
	s.parts = {}
end

return VeyrSights
