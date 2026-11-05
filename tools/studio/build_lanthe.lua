-- Builds Lanthe, the Last Vigil into ServerStorage.Models.Lanthe (Sovereign, MODEL ONLY: no Units entry, no Pose
-- animation yet). Inspired by the Lampmaster (Clair Obscur: Expedition 33), concept art in Images/Concept/Unit/.
-- Run in Edit mode via the Studio MCP execute_luau (or loadstring over a local http.server, see CLAUDE.md). Safe to re-run.
--
-- The keeper of the graveyard lights. She HANGS UPSIDE DOWN like the Hanged Man of the tarot: her right ankle is chained
-- to the crook of a tall wrought-iron lamp-post that floats with her, the left leg folded behind the right knee (a "4").
-- Six thin ashen arms: the low pair and the side pair each hold a lantern, the upper left holds a lamplighter's pole with
-- a lantern at its tip, the upper right a grave-digger's shovel (5 lanterns, the "souls"). A sixth, big lantern (the
-- Vigil Lamp, the finisher's pendulum) hangs from the crook in front of her. A tattered black robe falls DOWN over her
-- torso from the waist, a shaggy black ruff round her shoulders, black hair hanging from the crown toward the ground,
-- the face wrapped in bandages with one glowing slit. Threads of pale light run from each lantern to its wrist.
--
-- Rig: front = -Z, right = +X, built in its final hanging pose (head at the bottom). HumanoidRootPart -> Post (Root,
-- the lamp-post) -> Pelvis (Hang, the pivot at the chained ankle, so the body swings like a pendulum) -> Torso (Waist)
-- -> Head (Neck) -> HairL/HairR/HairB; arms <L|R><1|2|3>Shoulder/Elbow/Wrist; lanterns <L|R><1|2>Lamp, L3Lamp,
-- VigilLamp (Post -> lantern); FoldHip/FoldKnee (the folded leg); Robe1..Robe8 (rag groups on the Pelvis).
-- Flame parts are named "<LampJoint>Flame" (for the later Snuff special).
local ServerStorage = game:GetService("ServerStorage")
local models = ServerStorage.Models

local old = models:FindFirstChild("Lanthe")
if old then old:Destroy() end

local SKIN = Color3.fromRGB(178, 172, 184) -- ashen pale, a little lavender
local SKIN_DARK = Color3.fromRGB(128, 120, 136)
local SKIN_LIGHT = Color3.fromRGB(204, 199, 208)
local BANDAGE = Color3.fromRGB(212, 202, 180)
local BANDAGE_DIRTY = Color3.fromRGB(156, 142, 120)
local ROBE = Color3.fromRGB(20, 18, 24)
local ROBE_EDGE = Color3.fromRGB(42, 36, 46)
local HAIR = Color3.fromRGB(12, 11, 15)
local IRON = Color3.fromRGB(38, 36, 40)
local IRON_LIGHT = Color3.fromRGB(74, 70, 66)
local BRASS = Color3.fromRGB(122, 98, 62)
local GLASS = Color3.fromRGB(255, 220, 160)
local FLAME = Color3.fromRGB(255, 226, 160)
local FLAME_CORE = Color3.fromRGB(255, 250, 235)
local WAX = Color3.fromRGB(226, 216, 196)
local WOOD = Color3.fromRGB(72, 54, 40)
local RUST = Color3.fromRGB(96, 66, 48)
local SPADE = Color3.fromRGB(70, 66, 64)
local DIRT = Color3.fromRGB(58, 46, 36)
local CLAW = Color3.fromRGB(40, 34, 40)
local LIGHT_THREAD = Color3.fromRGB(255, 232, 190)

local rng = Random.new(33)
local model = Instance.new("Model")
model.Name = "Lanthe"

-- ── Helpers ──────────────────────────────────────────────────
local function part(name, size, cf, color, material, shape)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = typeof(cf) == "Vector3" and CFrame.new(cf) or cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.Anchored = false
	p.CastShadow = false
	if shape then p.Shape = shape end
	p.Parent = model
	return p
end

local function motor(name, p0, p1, jointPos)
	local m = Instance.new("Motor6D")
	m.Name = name
	m.Part0 = p0
	m.Part1 = p1
	m.C0 = p0.CFrame:Inverse() * CFrame.new(jointPos)
	m.C1 = p1.CFrame:Inverse() * CFrame.new(jointPos)
	m.Parent = p1
	return m
end

local function weld(p0, p1)
	local w = Instance.new("WeldConstraint")
	w.Part0 = p0
	w.Part1 = p1
	w.Parent = p1
	return p1
end

-- a CFrame at pos whose -Z points along dir
local function look(pos, dir, up)
	dir = dir.Unit
	up = up or ((math.abs(dir.Y) > 0.95) and Vector3.zAxis or Vector3.yAxis)
	return CFrame.lookAt(pos, pos + dir, up)
end

-- a cylinder from a to b
local function rod(name, a, b, r, color, material)
	local len = (b - a).Magnitude
	local cf = look((a + b) / 2, b - a) * CFrame.Angles(0, math.rad(90), 0)
	return part(name, Vector3.new(len, r * 2, r * 2), cf, color, material, Enum.PartType.Cylinder)
end

-- a flat strip from a to b (width across X, thickness Y); up picks how the flat side faces
local function strip(name, a, b, w, t, color, material, up)
	local len = (b - a).Magnitude
	return part(name, Vector3.new(w, t, len), look((a + b) / 2, b - a, up), color, material)
end

local function ball(name, pos, d, color, material)
	local size = typeof(d) == "Vector3" and d or Vector3.new(d, d, d)
	return part(name, size, pos, color, material, Enum.PartType.Ball)
end

-- a disc lying flat (axis Y)
local function disc(name, pos, r, h, color, material)
	return part(name, Vector3.new(h, r * 2, r * 2), CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90)), color, material, Enum.PartType.Cylinder)
end

local function invisible(name, pos)
	local p = part(name, Vector3.new(0.2, 0.2, 0.2), pos, IRON)
	p.Transparency = 1
	return p
end

local function attach(p, name, worldPos)
	local a = Instance.new("Attachment")
	a.Name = name
	a.Parent = p
	a.WorldPosition = worldPos
	return a
end

-- a thread of pale light between two attachments (the lantern-to-wrist "chains of light")
local function lightThread(a0, a1, curve)
	local b = Instance.new("Beam")
	b.Name = "LightThread"
	b.Attachment0 = a0
	b.Attachment1 = a1
	b.Color = ColorSequence.new(LIGHT_THREAD)
	b.LightEmission = 1
	b.LightInfluence = 0
	b.Width0 = 0.1
	b.Width1 = 0.05
	b.Segments = 16
	b.FaceCamera = true
	b.CurveSize0 = curve
	b.CurveSize1 = -curve * 0.7
	b.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(0.5, 0.55),
		NumberSequenceKeypoint.new(1, 0.9),
	})
	b.Parent = a0.Parent
	return b
end

-- ── Lantern (hold point at the top of its bail, hangs straight down) ──
-- returns the carrier (invisible part at the hold point; everything is welded to it) and the flame
local function lantern(name, H, s)
	local carrier = invisible(name, H)
	local function w(p) return weld(carrier, p) end
	-- the bail: a little arch of iron the hand (or hook) holds
	local bc = H - Vector3.new(0, 0.2 * s, 0)
	local prev
	for k = 0, 6 do
		local a = math.rad(k * 30)
		local pt = bc + Vector3.new(math.cos(a) * 0.2 * s, math.sin(a) * 0.2 * s, 0)
		if prev then w(rod(name .. "Bail", prev, pt, 0.025 * s, IRON, Enum.Material.Metal)) end
		prev = pt
	end
	-- roof: a stepped dome with a finial
	local y0 = H.Y - 0.25 * s
	w(ball(name .. "Finial", Vector3.new(H.X, y0, H.Z), 0.1 * s, BRASS, Enum.Material.Metal))
	w(disc(name .. "Roof1", Vector3.new(H.X, y0 - 0.08 * s, H.Z), 0.12 * s, 0.07 * s, IRON, Enum.Material.Metal))
	w(disc(name .. "Roof2", Vector3.new(H.X, y0 - 0.15 * s, H.Z), 0.2 * s, 0.07 * s, IRON, Enum.Material.Metal))
	w(disc(name .. "Roof3", Vector3.new(H.X, y0 - 0.22 * s, H.Z), 0.28 * s, 0.07 * s, IRON_LIGHT, Enum.Material.Metal))
	w(disc(name .. "Rim", Vector3.new(H.X, y0 - 0.29 * s, H.Z), 0.36 * s, 0.06 * s, IRON, Enum.Material.Metal))
	-- the cage: four corner posts, glass panes, a mid crossbar on each face
	local yt = y0 - 0.32 * s
	local yb = yt - 0.75 * s
	local ym = (yt + yb) / 2
	local c = 0.25 * s
	for _, cx in ipairs({ -1, 1 }) do
		for _, cz in ipairs({ -1, 1 }) do
			w(part(name .. "Post", Vector3.new(0.06, 0.78, 0.06) * s, Vector3.new(H.X + cx * c, ym, H.Z + cz * c), IRON, Enum.Material.Metal))
		end
	end
	for k = 0, 3 do
		local a = k * math.pi / 2
		local n = Vector3.new(math.sin(a), 0, math.cos(a))
		local cf = CFrame.lookAt(Vector3.new(H.X, ym, H.Z) + n * c, Vector3.new(H.X, ym, H.Z) + n * 2)
		local pane = w(part(name .. "Pane", Vector3.new(0.46 * s, 0.7 * s, 0.02 * s), cf, GLASS, Enum.Material.Glass))
		pane.Transparency = 0.4
		w(part(name .. "Bar", Vector3.new(0.5 * s, 0.04 * s, 0.04 * s), cf * CFrame.new(0, -0.1 * s, -0.02 * s), IRON, Enum.Material.Metal))
		w(part(name .. "BarV", Vector3.new(0.04 * s, 0.7 * s, 0.04 * s), cf * CFrame.new(0, 0, -0.02 * s), IRON, Enum.Material.Metal))
	end
	w(part(name .. "Top", Vector3.new(0.58, 0.06, 0.58) * s, Vector3.new(H.X, yt, H.Z), IRON, Enum.Material.Metal))
	-- the candle and its flame (a trapped soul)
	w(disc(name .. "Wax", Vector3.new(H.X, yb + 0.15 * s, H.Z), 0.08 * s, 0.24 * s, WAX))
	w(part(name .. "WaxDrip", Vector3.new(0.04, 0.12, 0.04) * s, Vector3.new(H.X + 0.07 * s, yb + 0.1 * s, H.Z - 0.03 * s), WAX))
	local flame = w(ball(name .. "Flame", Vector3.new(H.X, yb + 0.4 * s, H.Z), Vector3.new(0.17, 0.3, 0.17) * s, FLAME, Enum.Material.Neon))
	w(ball(name .. "FlameCore", Vector3.new(H.X, yb + 0.37 * s, H.Z), 0.09 * s, FLAME_CORE, Enum.Material.Neon))
	local light = Instance.new("PointLight")
	light.Name = "LampLight"
	light.Color = FLAME
	light.Brightness = 1.2
	light.Range = 7 * s
	light.Shadows = false
	light.Parent = flame
	-- base: a plate, a stepped underside and a drip spike
	w(part(name .. "Base", Vector3.new(0.62, 0.07, 0.62) * s, Vector3.new(H.X, yb, H.Z), IRON, Enum.Material.Metal))
	w(disc(name .. "Under1", Vector3.new(H.X, yb - 0.07 * s, H.Z), 0.22 * s, 0.07 * s, IRON_LIGHT, Enum.Material.Metal))
	w(disc(name .. "Under2", Vector3.new(H.X, yb - 0.13 * s, H.Z), 0.12 * s, 0.07 * s, IRON, Enum.Material.Metal))
	w(ball(name .. "Drip", Vector3.new(H.X, yb - 0.2 * s, H.Z), Vector3.new(0.08, 0.14, 0.08) * s, BRASS, Enum.Material.Metal))
	-- four little corner claws on the base
	for k = 0, 3 do
		local a = math.rad(45 + k * 90)
		local p = Vector3.new(H.X + math.sin(a) * 0.36 * s, yb - 0.03 * s, H.Z + math.cos(a) * 0.36 * s)
		w(rod(name .. "Foot", p, p + Vector3.new(math.sin(a) * 0.08, -0.1, math.cos(a) * 0.08) * s, 0.025 * s, IRON, Enum.Material.Metal))
	end
	return carrier, flame
end

-- ── Hand: palm + four long fingers curled into a grip + thumb ──
local function hand(name, W, dir)
	local cf = look(W + dir * 0.16, dir)
	local palm = part(name .. "Hand", Vector3.new(0.26, 0.1, 0.3), cf, SKIN)
	local up = cf.UpVector
	local right = cf.RightVector
	for f = 1, 4 do
		local off = (f - 2.5) * 0.065
		local k1 = W + dir * 0.3 + right * off
		local k2 = k1 + dir * (0.24 - math.abs(off) * 0.4)
		local k3 = k2 + (dir * 0.3 - up * 0.9).Unit * 0.17
		local k4 = k3 + (-dir * 0.5 - up * 0.8).Unit * 0.11
		weld(palm, rod(name .. "Finger", k1, k2, 0.032, SKIN))
		weld(palm, ball(name .. "Knuckle", k2, 0.075, SKIN_DARK))
		weld(palm, rod(name .. "Finger", k2, k3, 0.029, SKIN))
		weld(palm, rod(name .. "Claw", k3, k4, 0.024, CLAW))
	end
	local t1 = W + dir * 0.12 - right * 0.13
	local t2 = t1 + (dir * 0.6 - right * 0.4 - up * 0.5).Unit * 0.2
	weld(palm, rod(name .. "Thumb", t1, t2, 0.033, SKIN))
	weld(palm, rod(name .. "ThumbClaw", t2, t2 + (dir - up).Unit * 0.09, 0.024, CLAW))
	-- the grip point sits inside the curled fingers
	return palm, W + dir * 0.48 - up * 0.1
end

-- ── Core: root and the lamp-post ─────────────────────────────
local ROOT_Y = 7
local root = part("HumanoidRootPart", Vector3.new(1, 1, 1), Vector3.new(0, ROOT_Y, 0), IRON)
root.Transparency = 1
model.PrimaryPart = root

local POST_Z = 1.5
local SHAFT_TOP = 12.2
local post = rod("Post", Vector3.new(0, 1.2, POST_Z), Vector3.new(0, SHAFT_TOP, POST_Z), 0.11, IRON, Enum.Material.Metal)
local CROOK_C = Vector3.new(0, SHAFT_TOP, 0.2)
local CROOK_R = 1.3
local APEX = Vector3.new(0, CROOK_C.Y + CROOK_R, CROOK_C.Z)
motor("Root", root, post, APEX)
local function pw(p) return weld(post, p) end
-- collars down the shaft, a twisted section near the top, a spiked finial at the foot
for k = 0, 5 do
	local y = 2 + k * 1.9
	pw(disc("PostCollar", Vector3.new(0, y, POST_Z), 0.17, 0.12, IRON_LIGHT, Enum.Material.Metal))
	pw(disc("PostCollarLip", Vector3.new(0, y + 0.09, POST_Z), 0.14, 0.05, BRASS, Enum.Material.Metal))
end
for k = 0, 11 do
	local a = k * math.rad(50)
	local y = 9.4 + k * 0.2
	pw(part("PostTwist", Vector3.new(0.08, 0.22, 0.08), CFrame.new(math.cos(a) * 0.12, y, POST_Z + math.sin(a) * 0.12) * CFrame.Angles(0, -a, math.rad(25)), IRON_LIGHT, Enum.Material.Metal))
end
pw(disc("PostFoot1", Vector3.new(0, 1.2, POST_Z), 0.22, 0.14, IRON_LIGHT, Enum.Material.Metal))
pw(disc("PostFoot2", Vector3.new(0, 1.0, POST_Z), 0.16, 0.14, IRON, Enum.Material.Metal))
pw(ball("PostKnob", Vector3.new(0, 0.82, POST_Z), 0.26, BRASS, Enum.Material.Metal))
pw(rod("PostSpike", Vector3.new(0, 0.7, POST_Z), Vector3.new(0, 0.1, POST_Z), 0.05, IRON, Enum.Material.Metal))
-- three curled iron leaves around the foot
for k = 0, 2 do
	local a = math.rad(k * 120)
	local d = Vector3.new(math.cos(a), 0, math.sin(a))
	local p0 = Vector3.new(0, 1.35, POST_Z) + d * 0.1
	local p1 = p0 + d * 0.35 + Vector3.new(0, 0.3, 0)
	pw(rod("PostLeaf", p0, p1, 0.035, IRON, Enum.Material.Metal))
	pw(rod("PostLeafCurl", p1, p1 - d * 0.12 + Vector3.new(0, 0.14, 0), 0.03, IRON, Enum.Material.Metal))
end
-- the crook: an arc from the top of the shaft forward over her, ending in a short drop the Vigil Lamp hangs from
local prev = Vector3.new(0, SHAFT_TOP, POST_Z)
for k = 1, 18 do
	local a = math.rad(k * 10)
	local pt = CROOK_C + Vector3.new(0, math.sin(a) * CROOK_R, math.cos(a) * CROOK_R)
	pw(rod("Crook", prev, pt, 0.1 - k * 0.002, IRON, Enum.Material.Metal))
	if k % 3 == 0 and k < 18 then
		pw(ball("CrookStud", pt, 0.2, IRON_LIGHT, Enum.Material.Metal))
	end
	-- little scrolls on top of the arc
	if k == 5 or k == 13 then
		local outward = (pt - CROOK_C).Unit
		local s1 = pt + outward * 0.3 + Vector3.new(0.0, 0, 0)
		pw(rod("CrookScroll", pt, s1, 0.035, IRON, Enum.Material.Metal))
		pw(rod("CrookScrollCurl", s1, s1 + Vector3.new(0, 0, (k == 5) and 0.15 or -0.15), 0.03, IRON, Enum.Material.Metal))
		pw(ball("CrookScrollEnd", s1 + Vector3.new(0, 0, (k == 5) and 0.15 or -0.15), 0.08, BRASS, Enum.Material.Metal))
	end
	prev = pt
end
local CROOK_TIP = CROOK_C + Vector3.new(0, 0, -CROOK_R)
local hookEnd = CROOK_TIP - Vector3.new(0, 0.25, 0)
pw(rod("CrookDrop", CROOK_TIP, hookEnd, 0.08, IRON, Enum.Material.Metal))
pw(ball("CrookDropKnob", hookEnd, 0.15, BRASS, Enum.Material.Metal))

-- the Vigil Lamp: the big lantern hanging from the crook, toward the wall
local VIGIL_H = hookEnd - Vector3.new(0, 0.05, 0)
local vigil, vigilFlame = lantern("VigilLamp", VIGIL_H, 1.7)
motor("VigilLamp", post, vigil, VIGIL_H)
vigilFlame.Name = "VigilLampFlame"

-- ── Body (hanging head-down; the right ankle chained to the crook) ──
local ANKLE = Vector3.new(0.32, 11.25, 0)
local HIP_Y = 7.15
local pelvis = part("Pelvis", Vector3.new(1.1, 0.55, 0.72), Vector3.new(0, 7.0, 0), SKIN)
motor("Hang", post, pelvis, ANKLE)
-- the chain from the crook to the ankle shackle (on the post; the body swings about its lower end)
do
	local top = CROOK_C + Vector3.new(0, math.sin(math.rad(94)) * CROOK_R, math.cos(math.rad(94)) * CROOK_R)
	pw(rod("ChainRing", top + Vector3.new(-0.15, 0, 0), top + Vector3.new(0.15, 0, 0), 0.13, IRON_LIGHT, Enum.Material.Metal))
	local bottom = ANKLE + Vector3.new(0, 0.3, 0)
	local n = 9
	for k = 0, n - 1 do
		local p = top:Lerp(bottom, (k + 0.5) / n)
		local dir = bottom - top
		local cf = look(p, dir) * CFrame.Angles(0, 0, (k % 2) * math.rad(90))
		pw(part("ChainLink", Vector3.new(0.06, 0.16, 0.28), cf, IRON, Enum.Material.Metal))
	end
end

-- the straight right leg, up from the hip to the chained ankle (rigid with the pelvis)
local function pel(p) return weld(pelvis, p) end
local rKnee = Vector3.new(0.3, 9.2, 0.04)
pel(rod("RThigh", Vector3.new(0.3, HIP_Y, 0), rKnee, 0.21, SKIN))
pel(ball("RKneeCap", rKnee + Vector3.new(0, 0, -0.06), 0.36, SKIN_DARK))
pel(rod("RShin", rKnee, ANKLE, 0.16, SKIN))
pel(rod("RShinBone", rKnee + Vector3.new(0, 0.2, -0.13), ANKLE - Vector3.new(0, 0.3, 0.12), 0.05, SKIN_LIGHT))
pel(disc("RShackle", ANKLE + Vector3.new(0, 0.1, 0), 0.22, 0.2, IRON, Enum.Material.Metal))
pel(disc("RShackleRim", ANKLE + Vector3.new(0, 0.22, 0), 0.24, 0.05, IRON_LIGHT, Enum.Material.Metal))
for k = 0, 3 do
	local y = 10.2 + k * 0.2
	pel(part("RLegBandage", Vector3.new(0.38, 0.1, 0.38), CFrame.new(0.31, y, 0) * CFrame.Angles(math.rad(k % 2 == 0 and 12 or -10), 0, math.rad(8)), BANDAGE_DIRTY))
end
-- the foot points up past the shackle
pel(part("RFoot", Vector3.new(0.24, 0.62, 0.3), CFrame.new(0.32, 11.72, -0.08) * CFrame.Angles(math.rad(-12), 0, 0), SKIN))
pel(ball("RHeel", Vector3.new(0.32, 11.5, 0.1), 0.24, SKIN_DARK))
for t = 0, 3 do
	pel(ball("RToe", Vector3.new(0.23 + t * 0.06, 12.07, -0.14), Vector3.new(0.06, 0.1, 0.07), SKIN_DARK))
end
-- the folded left leg (a "4" behind the right knee), on its own joints
local lHip = Vector3.new(-0.3, HIP_Y, 0)
local lKnee = Vector3.new(-1.0, 8.85, 0.18)
local lAnkle = Vector3.new(0.18, 9.35, 0.42)
local lThigh = rod("LThigh", lHip, lKnee, 0.2, SKIN)
motor("FoldHip", pelvis, lThigh, lHip)
weld(lThigh, ball("LKneeCap", lKnee, 0.36, SKIN_DARK))
local lShin = rod("LShin", lKnee, lAnkle, 0.15, SKIN)
motor("FoldKnee", lThigh, lShin, lKnee)
for k = 0, 2 do
	local p = lKnee:Lerp(lAnkle, 0.65 + k * 0.1)
	weld(lShin, part("LLegBandage", Vector3.new(0.34, 0.34, 0.1), look(p, lAnkle - lKnee) * CFrame.Angles(0, 0, math.rad(k * 20)), BANDAGE_DIRTY))
end
local lFootDir = Vector3.new(0.35, 0.6, 0.3).Unit
weld(lShin, part("LFoot", Vector3.new(0.22, 0.28, 0.56), look(lAnkle + lFootDir * 0.25, lFootDir), SKIN))
weld(lShin, ball("LHeel", lAnkle, 0.22, SKIN_DARK))

-- ── Torso (emaciated: ribs, spine, sunken belly) ─────────────
local torso = part("Torso", Vector3.new(1.3, 1.35, 0.8), Vector3.new(0, 5.25, 0), SKIN)
motor("Waist", pelvis, torso, Vector3.new(0, 6.85, 0))
local function tw(p) return weld(torso, p) end
tw(part("Belly", Vector3.new(0.95, 1.0, 0.62), Vector3.new(0, 6.35, 0.02), SKIN_DARK))
tw(part("BellyFront", Vector3.new(0.75, 0.75, 0.1), Vector3.new(0, 6.3, -0.29), SKIN))
for _, x in ipairs({ -1, 1 }) do
	-- ribs (inverted body: the ribs sit near the shoulders, below the belly)
	for k = 0, 3 do
		local y = 5.0 + k * 0.24
		local inner = Vector3.new(x * 0.1, y, -0.42)
		local outer = Vector3.new(x * 0.6, y + 0.12, -0.3)
		tw(rod("Rib", inner, outer, 0.04, SKIN_LIGHT))
		tw(rod("RibBack", outer, Vector3.new(x * 0.66, y + 0.18, 0.15), 0.04, SKIN_LIGHT))
	end
	tw(rod("Collarbone", Vector3.new(x * 0.08, 4.68, -0.36), Vector3.new(x * 0.6, 4.62, -0.15), 0.05, SKIN_LIGHT))
	tw(part("Hipbone", Vector3.new(0.18, 0.3, 0.3), Vector3.new(x * 0.5, 6.9, -0.25), SKIN_LIGHT))
end
tw(rod("Sternum", Vector3.new(0, 4.75, -0.42), Vector3.new(0, 5.75, -0.42), 0.05, SKIN_LIGHT))
for k = 0, 7 do
	tw(ball("Vertebra", Vector3.new(0, 4.75 + k * 0.28, 0.41), Vector3.new(0.14, 0.12, 0.12), SKIN_LIGHT))
end
-- the shaggy black ruff round the shoulders, hanging down past the neck
for k = 0, 15 do
	local a = math.rad(k * 22.5 + rng:NextNumber(-6, 6))
	local d = Vector3.new(math.sin(a), 0, -math.cos(a))
	local top = Vector3.new(0, 4.75, 0) + d * 0.62
	local len = 0.7 + rng:NextNumber(0, 0.5)
	local bottom = top + d * (0.35 + rng:NextNumber(0, 0.25)) - Vector3.new(0, len, 0)
	local front = math.abs(a - math.pi * 2) < 0.6 or a < 0.6
	if not front then -- (keep the throat and face clear)
		tw(strip("Ruff", top, bottom, 0.28, 0.06, (k % 3 == 0) and ROBE_EDGE or HAIR, Enum.Material.Fabric))
	end
end

-- ── The robe: tattered black rags falling DOWN over the torso from the waist ──
local robeBelt = disc("RobeBelt", Vector3.new(0, 7.12, 0), 0.68, 0.36, ROBE, Enum.Material.Fabric)
pel(robeBelt)
pel(disc("RobeRope", Vector3.new(0, 7.0, 0), 0.7, 0.08, BANDAGE_DIRTY, Enum.Material.Fabric))
pel(disc("RobeRope2", Vector3.new(0, 7.12, 0), 0.7, 0.06, BANDAGE_DIRTY, Enum.Material.Fabric))
-- charms tied to the rope (bone key, little bell, grave tag), hanging down toward her head
do
	local charms = { { -0.45, "Key" }, { 0.5, "Bell" }, { 0.15, "Tag" } }
	for _, c in ipairs(charms) do
		local x = c[1]
		local z = -math.sqrt(math.max(0.49 - x * x, 0.04))
		local top = Vector3.new(x, 6.96, z - 0.03)
		pel(rod("CharmString", top, top - Vector3.new(0, 0.4, 0.02), 0.012, BANDAGE_DIRTY))
		local cp = top - Vector3.new(0, 0.5, 0.03)
		if c[2] == "Key" then
			pel(part("BoneKey", Vector3.new(0.06, 0.3, 0.04), cp - Vector3.new(0, 0.05, 0), SKIN_LIGHT))
			pel(ball("BoneKeyBow", cp + Vector3.new(0, 0.12, 0), Vector3.new(0.13, 0.13, 0.04), SKIN_LIGHT))
			pel(part("BoneKeyBit", Vector3.new(0.1, 0.05, 0.04), cp - Vector3.new(0.04, 0.17, 0), SKIN_LIGHT))
		elseif c[2] == "Bell" then
			pel(ball("CharmBell", cp, Vector3.new(0.16, 0.18, 0.16), BRASS, Enum.Material.Metal))
			pel(disc("CharmBellLip", cp - Vector3.new(0, 0.08, 0), 0.1, 0.03, BRASS, Enum.Material.Metal))
		else
			pel(part("GraveTag", Vector3.new(0.16, 0.22, 0.03), cp, IRON_LIGHT, Enum.Material.Metal))
		end
	end
end
local robeCarriers = {}
for g = 1, 8 do
	local a = math.rad((g - 1) * 45)
	robeCarriers[g] = invisible("Robe" .. g, Vector3.new(math.sin(a) * 0.7, 7.1, -math.cos(a) * 0.7))
	motor("Robe" .. g, pelvis, robeCarriers[g], Vector3.new(math.sin(a) * 0.7, 7.1, -math.cos(a) * 0.7))
end
for k = 0, 29 do
	local deg = k * 12 + rng:NextNumber(-4, 4)
	local degN = deg % 360
	-- leave room for the arms at the sides (they come out of the rags there)
	local side = (degN > 62 and degN < 118) or (degN > 242 and degN < 298)
	local front = degN < 48 or degN > 312
	if not side then
		local a = math.rad(deg)
		local d = Vector3.new(math.sin(a), 0, -math.cos(a))
		local top = Vector3.new(0, 7.1, 0) + d * 0.66
		local bottomY = front and (6.0 + rng:NextNumber(-0.2, 0.25)) or (3.7 + rng:NextNumber(-0.5, 0.6))
		local flare = front and 0.18 or (0.55 + rng:NextNumber(0, 0.45))
		local mid = top + d * (flare * 0.45) - Vector3.new(0, (7.1 - bottomY) * 0.5, 0)
		local bottom = top + d * flare - Vector3.new(0, 7.1 - bottomY, 0)
		local g = math.floor(((degN + 22.5) % 360) / 45) + 1
		local carrier = robeCarriers[g]
		local up = Vector3.yAxis:Cross(d).Unit -- the flat side faces outward
		local col = (k % 4 == 0) and ROBE_EDGE or ROBE
		local w = 0.36 + rng:NextNumber(0, 0.12)
		weld(carrier, strip("Rag", top, mid, w, 0.05, col, Enum.Material.Fabric, d))
		weld(carrier, strip("Rag", mid, bottom, w * 0.8, 0.05, col, Enum.Material.Fabric, d))
		-- a torn tip: a narrow shred hanging a little further
		if rng:NextNumber() < 0.6 then
			local shredEnd = bottom + d * 0.08 - Vector3.new(0, 0.25 + rng:NextNumber(0, 0.3), 0) + up * rng:NextNumber(-0.1, 0.1)
			weld(carrier, strip("RagShred", bottom, shredEnd, w * 0.3, 0.04, ROBE_EDGE, Enum.Material.Fabric, d))
		end
	end
end

-- ── Head: bandaged, one glowing slit, hair hanging from the crown ──
local HEAD_Y = 3.35
local neckTop, neckBottom = Vector3.new(0, 4.62, 0.02), Vector3.new(0, 3.9, 0.04)
tw(rod("NeckBone", neckTop, neckBottom, 0.17, SKIN))
tw(rod("NeckTendon", neckTop + Vector3.new(0.1, 0, -0.08), neckBottom + Vector3.new(0.08, 0, -0.1), 0.04, SKIN_LIGHT))
tw(rod("NeckTendon", neckTop + Vector3.new(-0.1, 0, -0.08), neckBottom + Vector3.new(-0.08, 0, -0.1), 0.04, SKIN_LIGHT))
local head = ball("Head", Vector3.new(0, HEAD_Y, 0), Vector3.new(1.2, 1.3, 1.25), SKIN)
motor("Neck", torso, head, Vector3.new(0, 4.2, 0.02))
local function hw(p) return weld(head, p) end
-- the jaw (inverted: the chin points up)
hw(part("Jaw", Vector3.new(0.7, 0.3, 0.55), Vector3.new(0, 3.95, -0.3), SKIN_DARK))
-- bandage wraps round the head at odd angles
for k = 0, 5 do
	local y = 2.95 + k * 0.17
	local r = 0.63 - math.abs(k - 2.5) * 0.04
	local tilt = math.rad(rng:NextNumber(-14, 14))
	local roll = math.rad(rng:NextNumber(-10, 10))
	hw(part("FaceWrap", Vector3.new(0.13, r * 2, r * 2), CFrame.new(0, y, 0.01) * CFrame.Angles(tilt, 0, math.rad(90) + roll), (k % 2 == 0) and BANDAGE or BANDAGE_DIRTY, Enum.Material.Fabric, Enum.PartType.Cylinder))
end
-- the slit (inverted face: the eyes are below the middle) and the candle-flame eye inside it
hw(part("EyeSlit", Vector3.new(0.62, 0.1, 0.12), CFrame.new(0, 3.18, -0.6) * CFrame.Angles(0, 0, math.rad(4)), Color3.fromRGB(10, 8, 12)))
local eye = hw(part("Eye", Vector3.new(0.22, 0.06, 0.06), CFrame.new(0.08, 3.18, -0.665) * CFrame.Angles(0, 0, math.rad(4)), FLAME, Enum.Material.Neon))
local eyeLight = Instance.new("PointLight")
eyeLight.Name = "EyeGlow"
eyeLight.Color = FLAME
eyeLight.Brightness = 0.8
eyeLight.Range = 5
eyeLight.Shadows = false
eyeLight.Parent = eye
-- loose bandage tails hanging down from the head
for _, x in ipairs({ -0.35, 0.42 }) do
	local top = Vector3.new(x, 2.95, -0.45)
	hw(strip("BandageTail", top, top + Vector3.new(x * 0.3, -1.1, -0.15), 0.12, 0.03, BANDAGE_DIRTY, Enum.Material.Fabric))
	hw(strip("BandageTail", top + Vector3.new(x * 0.3, -1.1, -0.15), top + Vector3.new(x * 0.45, -1.7, -0.05), 0.1, 0.03, BANDAGE_DIRTY, Enum.Material.Fabric))
end
-- hair: long black strands from round the crown, hanging toward the ground (three groups for sway)
local hairCarriers = {
	L = invisible("HairL", Vector3.new(-0.4, 2.85, 0.1)),
	R = invisible("HairR", Vector3.new(0.4, 2.85, 0.1)),
	B = invisible("HairB", Vector3.new(0, 2.85, 0.45)),
}
for key, c in pairs(hairCarriers) do
	motor("Hair" .. key, head, c, c.Position)
end
for k = 0, 21 do
	local a = math.rad(k * (360 / 22) + rng:NextNumber(-5, 5))
	local d = Vector3.new(math.sin(a), 0, -math.cos(a))
	local degN = math.deg(a) % 360
	-- front strands are shorter (a ragged fringe under the face), the back ones are the long curtain
	local front = degN < 40 or degN > 320
	local top = Vector3.new(0, 2.95, 0) + d * 0.52
	local len = front and rng:NextNumber(0.6, 0.9) or rng:NextNumber(1.6, 2.4)
	local mid = top + d * 0.12 - Vector3.new(0, len * 0.5, 0)
	local bottom = top + d * (0.2 + rng:NextNumber(0, 0.2)) - Vector3.new(0, len, 0)
	local c = (degN > 135 and degN < 225) and hairCarriers.B or ((degN >= 180) and hairCarriers.L or hairCarriers.R)
	weld(c, strip("Hair", top, mid, 0.24, 0.05, HAIR, Enum.Material.Fabric, d))
	weld(c, strip("Hair", mid, bottom, 0.18, 0.05, HAIR, Enum.Material.Fabric, d))
end

-- ── Six arms ─────────────────────────────────────────────────
local wristAttach = {}
-- tag e.g. "L1": shoulder S, elbow E, wrist W, hand direction dir; returns the palm and the grip point
local function arm(tag, S, E, W, dir)
	local upper = rod(tag .. "UpperArm", S, E, 0.15, SKIN)
	motor(tag .. "Shoulder", torso, upper, S)
	weld(upper, ball(tag .. "ShoulderKnob", S, 0.34, SKIN_DARK))
	local fore = rod(tag .. "Forearm", E, W, 0.12, SKIN)
	motor(tag .. "Elbow", upper, fore, E)
	weld(fore, ball(tag .. "ElbowKnob", E, 0.28, SKIN_DARK))
	weld(fore, rod(tag .. "Ulna", E:Lerp(W, 0.1) + Vector3.new(0, 0, 0.08), E:Lerp(W, 0.85) + Vector3.new(0, 0, 0.08), 0.035, SKIN_LIGHT))
	-- bandages round the wrist, one loose end
	for k = 0, 2 do
		local p = E:Lerp(W, 0.72 + k * 0.1)
		weld(fore, part(tag .. "WristWrap", Vector3.new(0.29, 0.29, 0.09), look(p, W - E) * CFrame.Angles(0, 0, math.rad(k * 30)) * CFrame.Angles(math.rad(k % 2 == 0 and 10 or -10), 0, 0), BANDAGE, Enum.Material.Fabric))
	end
	local tail = E:Lerp(W, 0.8)
	weld(fore, strip(tag .. "WrapTail", tail, tail + Vector3.new(0, -0.5, 0.05), 0.08, 0.02, BANDAGE_DIRTY, Enum.Material.Fabric))
	local palm, grip = hand(tag, W, dir)
	motor(tag .. "Wrist", fore, palm, W)
	wristAttach[tag] = attach(fore, tag .. "WristLight", W)
	return palm, grip
end

local function lanternArm(tag, S, E, W, dir)
	local palm, grip = arm(tag, S, E, W, dir)
	local lamp, flame = lantern(tag .. "Lamp", grip, 1)
	motor(tag .. "Lamp", palm, lamp, grip)
	flame.Name = tag .. "LampFlame"
	local a0 = attach(lamp, "ThreadStart", grip - Vector3.new(0, 0.6, 0))
	lightThread(a0, wristAttach[tag], 1.2)
	return lamp
end

for _, s in ipairs({ -1, 1 }) do
	local side = (s < 0) and "L" or "R"
	-- low pair: reaching down and out, lanterns near the ground
	do
		local S, E, W = Vector3.new(s * 0.62, 4.85, 0), Vector3.new(s * 1.55, 3.7, -0.35), Vector3.new(s * 2.25, 2.55, -0.55)
		lanternArm(side .. "1", S, E, W, (W - E).Unit)
	end
	-- side pair: out to the sides, the elbow lifted, lanterns at the hips of the silhouette
	do
		local S, E, W = Vector3.new(s * 0.66, 5.55, 0.05), Vector3.new(s * 1.85, 6.0, 0.15), Vector3.new(s * 3.0, 5.35, -0.2)
		lanternArm(side .. "2", S, E, W, ((W - E).Unit + Vector3.new(0, -1, 0)).Unit)
	end
end

-- upper left: the lamplighter's pole, a lantern dangling from its hook
do
	local S, E, W = Vector3.new(-0.6, 6.35, 0.1), Vector3.new(-1.7, 7.35, 0.35), Vector3.new(-2.55, 8.6, 0.15)
	local palm, grip = arm("L3", S, E, W, (W - E).Unit)
	local d = Vector3.new(-0.85, 0.55, -0.1).Unit
	local tip = grip + d * 2.3
	weld(palm, rod("Pole", grip - d * 0.6, tip, 0.06, WOOD, Enum.Material.Wood))
	weld(palm, disc("PoleCap", grip - d * 0.62, 0.07, 0.06, BRASS, Enum.Material.Metal))
	for k = 1, 3 do
		weld(palm, rod("PoleFerrule", grip + d * (k * 0.6 - 0.05), grip + d * (k * 0.6 + 0.05), 0.075, BRASS, Enum.Material.Metal))
	end
	local hookTop = tip + d * 0.15 + Vector3.new(0, 0.15, 0)
	weld(palm, rod("PoleHook", tip, hookTop, 0.04, IRON, Enum.Material.Metal))
	local hookEndL = hookTop + Vector3.new(-0.18, -0.12, 0)
	weld(palm, rod("PoleHookCurl", hookTop, hookEndL, 0.035, IRON, Enum.Material.Metal))
	local H = hookEndL - Vector3.new(0, 0.05, 0)
	local lamp, flame = lantern("L3Lamp", H, 1)
	motor("L3Lamp", palm, lamp, H)
	flame.Name = "L3LampFlame"
	lightThread(attach(lamp, "ThreadStart", H - Vector3.new(0, 0.6, 0)), wristAttach.L3, 1.6)
end

-- upper right: the grave-digger's shovel, blade up like a weapon
do
	local S, E, W = Vector3.new(0.6, 6.35, 0.1), Vector3.new(1.7, 7.35, 0.35), Vector3.new(2.55, 8.6, 0.15)
	local palm, grip = arm("R3", S, E, W, (W - E).Unit)
	local d = Vector3.new(0.42, 1, -0.08).Unit
	local bottom, top = grip - d * 1.3, grip + d * 2.5
	weld(palm, rod("ShovelHandle", bottom, top, 0.075, WOOD, Enum.Material.Wood))
	-- D-grip at the lower end
	local gripDir = Vector3.new(1, -0.42, 0).Unit
	weld(palm, rod("ShovelGripL", bottom, bottom - d * 0.3 + gripDir * 0.15, 0.04, WOOD, Enum.Material.Wood))
	weld(palm, rod("ShovelGripR", bottom, bottom - d * 0.3 - gripDir * 0.15, 0.04, WOOD, Enum.Material.Wood))
	weld(palm, rod("ShovelGripBar", bottom - d * 0.3 + gripDir * 0.15, bottom - d * 0.3 - gripDir * 0.15, 0.045, WOOD, Enum.Material.Wood))
	-- iron socket and the worn spade
	weld(palm, rod("ShovelSocket", top - d * 0.25, top + d * 0.3, 0.09, SPADE, Enum.Material.Metal))
	local up = Vector3.new(0, 0, -1)
	local bladeC = top + d * 0.85
	weld(palm, part("ShovelStep", Vector3.new(0.86, 0.1, 0.1), look(top + d * 0.32, d, up), SPADE, Enum.Material.Metal))
	weld(palm, part("ShovelBlade", Vector3.new(0.8, 0.06, 1.0), look(bladeC, d, up), SPADE, Enum.Material.Metal))
	weld(palm, part("ShovelTip", Vector3.new(0.58, 0.06, 0.22), look(bladeC + d * 0.6, d, up), SPADE, Enum.Material.Metal))
	weld(palm, part("ShovelPoint", Vector3.new(0.3, 0.06, 0.14), look(bladeC + d * 0.76, d, up), SPADE, Enum.Material.Metal))
	weld(palm, part("ShovelEdge", Vector3.new(0.6, 0.07, 0.04), look(bladeC + d * 0.71, d, up), IRON_LIGHT, Enum.Material.Metal))
	weld(palm, part("ShovelRib", Vector3.new(0.08, 0.08, 0.9), look(bladeC, d, up), IRON, Enum.Material.Metal))
	-- rust and old grave dirt
	for k = 1, 5 do
		local off = look(bladeC, d, up) * CFrame.new(rng:NextNumber(-0.3, 0.3), -0.035, rng:NextNumber(-0.4, 0.4))
		weld(palm, part("ShovelRust", Vector3.new(rng:NextNumber(0.1, 0.22), 0.02, rng:NextNumber(0.1, 0.22)), off, RUST, Enum.Material.CorrodedMetal))
	end
	for k = 1, 4 do
		local off = look(bladeC, d, up) * CFrame.new(rng:NextNumber(-0.28, 0.28), -0.05, rng:NextNumber(-0.1, 0.45))
		weld(palm, ball("GraveDirt", off.Position, rng:NextNumber(0.1, 0.17), DIRT, Enum.Material.Ground))
	end
end

-- a thread of light from the Vigil Lamp down to the chained ankle
lightThread(attach(vigil, "ThreadStart", VIGIL_H - Vector3.new(0, 1.0, 0)), attach(pelvis, "AnkleLight", ANKLE), 0.8)

-- ── Ambience: ash drifting off the hair and rags, motes round the Vigil Lamp ──
do
	local ashSrc = invisible("AshSource", Vector3.new(0, 1.2, 0.1))
	weld(head, ashSrc)
	local ash = Instance.new("ParticleEmitter")
	ash.Name = "Ash"
	ash.Color = ColorSequence.new(Color3.fromRGB(120, 114, 120))
	ash.LightEmission = 0
	ash.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.12), NumberSequenceKeypoint.new(1, 0.04) })
	ash.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1) })
	ash.Lifetime = NumberRange.new(1.5, 2.5)
	ash.Rate = 8
	ash.Speed = NumberRange.new(0.5, 1.2)
	ash.SpreadAngle = Vector2.new(40, 40)
	ash.Acceleration = Vector3.new(0, -1.5, 0)
	ash.EmissionDirection = Enum.NormalId.Bottom
	ash.Parent = ashSrc

	local motes = Instance.new("ParticleEmitter")
	motes.Name = "LampMotes"
	motes.Color = ColorSequence.new(FLAME)
	motes.LightEmission = 1
	motes.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 0) })
	motes.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	motes.Lifetime = NumberRange.new(1.2, 2)
	motes.Rate = 6
	motes.Speed = NumberRange.new(0.3, 0.8)
	motes.SpreadAngle = Vector2.new(180, 180)
	motes.Acceleration = Vector3.new(0, 0.6, 0)
	motes.Parent = vigilFlame
end

model:SetAttribute("Rig", "Procedural")
model:SetAttribute("RootHeight", ROOT_Y)
model:SetAttribute("Height", 14.3)
model:SetAttribute("Float", 0.25)
model.Parent = models

local parts, joints = 0, 0
for _, dd in ipairs(model:GetDescendants()) do
	if dd:IsA("BasePart") then parts += 1 end
	if dd:IsA("Motor6D") then joints += 1 end
end
return "Lanthe built: " .. parts .. " parts, " .. joints .. " joints"
