-- A magic circle lying flat, built from neon parts with offsets from its hub (used by SignatureDescent and the Void
-- Sanctum's summon in GraveCinematic).
--
--   local c = MagicCircle.build(parent, radius, gold, accent)   c.parts, c.offsets (CFrames from the hub), c.base, c.radius
--   MagicCircle.place(c, hubCf, scale, transparency)              moves every part to hubCf (the circle opens with `scale`)
local MagicCircle = {}

local function newPart(parent, size, cf, color)
	local p = Instance.new("Part")
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = Enum.Material.Neon
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Parent = parent
	return p
end

function MagicCircle.build(parent, radius, gold, accent)
	local c = { parts = {}, offsets = {}, base = {}, radius = radius }
	local w = math.max(0.16, radius * 0.022)
	local function add(size, offset, color)
		local p = newPart(parent, size, offset, color)
		p.Transparency = 1
		table.insert(c.parts, p)
		table.insert(c.offsets, offset)
		return p
	end
	local function ring(r, count, width, color, phase)
		local seg = 2 * math.pi * r / count * 0.86
		for k = 0, count - 1 do
			local a = (k / count) * 2 * math.pi + (phase or 0)
			add(Vector3.new(seg, 0.08, width), CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -r), color)
		end
	end
	local n = math.clamp(math.floor(radius * 1.6), 24, 64)
	ring(radius, n, w, gold)
	ring(radius * 0.88, n, w * 0.6, accent, 0.05)
	ring(radius * 0.36, math.max(12, math.floor(n / 2)), w * 0.6, accent)
	-- glyphs between the two outer rings
	local m = math.clamp(math.floor(radius * 0.6), 8, 24)
	for k = 0, m - 1 do
		local a = k / m * 2 * math.pi
		local base = CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -radius * 0.94)
		add(Vector3.new(w * 0.7, 0.08, radius * 0.05), base, gold)
		add(Vector3.new(radius * 0.035, 0.08, w * 0.7), base * CFrame.new(0, 0, (k % 2 == 0) and radius * 0.012 or -radius * 0.012), gold)
	end
	-- a hexagram inscribed in the inner ring
	for tri = 0, 1 do
		local pts = {}
		for k = 0, 2 do
			local a = (k / 3) * 2 * math.pi + tri * math.pi
			pts[k + 1] = Vector3.new(math.sin(a), 0, -math.cos(a)) * radius * 0.86
		end
		for k = 1, 3 do
			local a, b = pts[k], pts[k % 3 + 1]
			add(Vector3.new(w * 0.6, 0.08, (b - a).Magnitude), CFrame.lookAt((a + b) / 2, b), gold)
		end
	end
	-- rune stones riding the rim
	for k = 0, 3 do
		local s = math.max(0.5, w * 3)
		add(Vector3.new(s, s, s), CFrame.Angles(0, k / 4 * 2 * math.pi + math.pi / 4, 0) * CFrame.new(0, 0, -radius * 1.06) * CFrame.Angles(math.rad(45), 0, math.rad(45)), accent)
	end
	for i in ipairs(c.parts) do
		c.base[i] = 0
	end
	return c
end

function MagicCircle.place(c, hubCf, scale, transparency)
	scale = scale or 1
	for i, p in ipairs(c.parts) do
		local o = c.offsets[i]
		p.CFrame = hubCf * CFrame.new(o.Position * scale) * o.Rotation
		p.Transparency = transparency
	end
end

return MagicCircle
