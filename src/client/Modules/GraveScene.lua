-- The Graves panel in the world: the grave tiers you own rise out of the ground in a shallow arc in front of you, the
-- camera stands behind you, and a small bar at the bottom picks one and opens it. Opening hands the selected grave
-- straight to the grave cinematic: it is already standing, so the cinematic starts on the same spot without the rise.
--
--   local ok = GraveScene.open(ctx)  -- false when there is no free spot (or nothing to show): open the plain panel then
--     ctx.entries   list of { key, name } (the graves to raise, in tier order)
--     ctx.count     function(key) -> owned
--     ctx.hint      function(key) -> the info line ("Best: Rare 2.00%")
--     ctx.selected  the key selected first
--     ctx.onOpen    function(key, count) -> true when the pull was sent to the server (or false, "full")
--     ctx.onList    function() -> the plain panel with every grave (the scene closes first)
--   GraveScene.isOpen() / GraveScene.close()
--   GraveScene.takeStage(graveType)  -- called by GraveRolling when the result arrives: ends the view at once (no glide,
--                                       the cinematic takes over the camera) and returns { G, dir, risen } of the waiting
--                                       grave (graves shown smaller grow to the cinematic's size while the pull is sent)
--   GraveScene.cancel()              -- the server refused the pull: the graves sink, the view glides back
--
-- The free spot: level floor under every grave, their footprints free, open ground between the character and them, a
-- free camera spot with a clear view of all of them, and the grave cinematic's own checks (GraveCinematic.fits) for
-- every grave, so the hand-off never moves the grave; looking ahead first, then round, smaller graves when crowded.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Theme = require(script.Parent.Theme)
local WorldView = require(script.Parent.WorldView)
local GraveOpening = require(script.Parent.GraveOpening)
local MagicCircle = require(script.Parent.MagicCircle)
local GraveCinematic = require(script.Parent.GraveCinematic)

local player = Players.LocalPlayer
local C = Theme.Color
local Z = 10
local MAX_PULL = 10

local GRAVE_SCALE = 1.5 -- the same scale as the grave cinematic, so the hand-off does not pop
local SCALES = { GRAVE_SCALE, 1.15, 0.9 } -- smaller graves when the full-size arc does not fit (crowded plaza)
local MIN_RADIUS = 16 -- studs from the character to the graves (the cinematic's GRAVE_DISTANCE)
local GAP = 3.5 -- studs between two graves
local MAX_SPAN = math.rad(110) -- the widest arc
local MAX_TIGHT_SPAN = math.rad(150) -- the tight arc (tried when the normal one does not fit)
local RISE_TIME = 0.8
local RISE_STAGGER = 0.08
local SINK_TIME = 0.55
local GROW_TIME = 0.5 -- a smaller grave grows to full size when it is opened
local FOV = 55
local MAX_VIEW_ANGLE = math.rad(38) -- the outer graves stay this far inside the view
local WAIT_TIMEOUT = 8 -- seconds to wait for the server's result before giving up
local CIRCLE_GOLD = Color3.fromRGB(120, 255, 190)
local CIRCLE_ACCENT = Color3.fromRGB(60, 170, 130)

local GraveScene = {}

local scene -- the running scene (nil when closed)

local function smooth(x)
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

-- ── The UI (its own ScreenGui: the view switches every other one off) ──
local gui = Instance.new("ScreenGui")
gui.Name = "GraveSceneUI"
gui.ResetOnSpawn = false
gui.DisplayOrder = 5
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

local bar = Instance.new("Frame")
bar.AnchorPoint = Vector2.new(0.5, 1)
bar.Position = UDim2.new(0.5, 0, 1, -24)
bar.Size = UDim2.fromOffset(760, 118)
bar.BackgroundColor3 = C.Void
bar.BackgroundTransparency = 0.15
bar.BorderSizePixel = 0
bar.ZIndex = Z
Theme.corner(bar, Theme.Radius.Small)
Theme.stroke(bar, C.Border, 1)
bar.Parent = gui
do
	local scale = Instance.new("UIScale")
	scale.Parent = bar
	local function fit()
		local w = Workspace.CurrentCamera and Workspace.CurrentCamera.ViewportSize.X or 1000
		scale.Scale = math.min(1, (w - 32) / 760)
	end
	fit()
	if Workspace.CurrentCamera then
		Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
	end
end

local nameLbl = Theme.label(bar, { text = "", size = "Heading", font = "Strong", color = C.Bone, align = Enum.TextXAlignment.Center, frameSize = UDim2.new(0, 300, 0, 30) })
nameLbl.Position = UDim2.fromOffset(66, 12)
nameLbl.ZIndex = Z + 1
Theme.outlineText(nameLbl)
local hintLbl = Theme.label(bar, { text = "", size = "Small", font = "Body", color = C.BoneDim, align = Enum.TextXAlignment.Center, frameSize = UDim2.new(0, 300, 0, 40) })
hintLbl.Position = UDim2.fromOffset(66, 44)
hintLbl.TextWrapped = true
hintLbl.ZIndex = Z + 1

local function stepSelection(delta) end -- (set below)
Theme.stoneButton(bar, {
	text = "<", size = UDim2.fromOffset(48, 46), position = UDim2.fromOffset(12, 18), zIndex = Z + 1,
	onClick = function() stepSelection(-1) end,
})
Theme.stoneButton(bar, {
	text = ">", size = UDim2.fromOffset(48, 46), position = UDim2.fromOffset(372, 18), zIndex = Z + 1,
	onClick = function() stepSelection(1) end,
})
local openOneBtn = Theme.stoneButton(bar, {
	text = "Open x1", size = UDim2.fromOffset(150, 46), position = UDim2.fromOffset(434, 18), zIndex = Z + 1,
	onClick = function() GraveScene.openSelected(1) end,
})
local openManyBtn = Theme.stoneButton(bar, {
	text = "Open x" .. MAX_PULL, color = "gold", size = UDim2.fromOffset(150, 46), position = UDim2.fromOffset(596, 18), zIndex = Z + 1,
	onClick = function() GraveScene.openSelected(MAX_PULL) end,
})
Theme.stoneButton(bar, {
	text = "All graves", size = UDim2.fromOffset(150, 34), position = UDim2.fromOffset(434, 74), zIndex = Z + 1,
	onClick = function()
		if scene and scene.state == "shown" then
			local onList = scene.ctx.onList
			GraveScene.close(onList)
		end
	end,
})
Theme.stoneButton(bar, {
	text = "Close", color = "red", size = UDim2.fromOffset(150, 34), position = UDim2.fromOffset(596, 74), zIndex = Z + 1,
	onClick = function() GraveScene.close() end,
})

-- ── Helpers ──────────────────────────────────────────────────
local function flat(v)
	local f = Vector3.new(v.X, 0, v.Z)
	return f.Magnitude > 0.01 and f.Unit or Vector3.new(0, 0, -1)
end

local function rotate(d, a)
	return Vector3.new(d.X * math.cos(a) - d.Z * math.sin(a), 0, d.X * math.sin(a) + d.Z * math.cos(a))
end

local function charFeet(hrp)
	local hum = hrp.Parent and hrp.Parent:FindFirstChildOfClass("Humanoid")
	return hrp.Position - Vector3.new(0, (hum and hum.HipHeight or 2) + hrp.Size.Y / 2, 0)
end

-- the scaled size of every grave (a throwaway clone)
local sizeCache = {}
local function graveSize(key, scale)
	local cacheKey = key .. "@" .. scale
	if not sizeCache[cacheKey] then
		local m = GraveOpening.template(key):Clone()
		m:ScaleTo(scale)
		m:PivotTo(CFrame.new())
		local _, size = m:GetBoundingBox()
		-- the body without the flat ground patch (PrimaryPart), which is much wider: the graves are spaced by this
		local lo, hi = Vector3.one * math.huge, -Vector3.one * math.huge
		for _, p in ipairs(m:GetDescendants()) do
			if p:IsA("BasePart") and p ~= m.PrimaryPart and p.Transparency < 1 then
				local r = p.CFrame
				local h = p.Size / 2
				local ext = Vector3.new(
					math.abs(r.XVector.X) * h.X + math.abs(r.YVector.X) * h.Y + math.abs(r.ZVector.X) * h.Z,
					0,
					math.abs(r.XVector.Z) * h.X + math.abs(r.YVector.Z) * h.Y + math.abs(r.ZVector.Z) * h.Z)
				lo = lo:Min(p.Position - ext)
				hi = hi:Max(p.Position + ext)
			end
		end
		local body = hi - lo
		sizeCache[cacheKey] = Vector3.new(math.min(body.X, size.X), size.Y, math.min(body.Z, size.Z))
		m:Destroy()
	end
	return sizeCache[cacheKey]
end

-- where the graves stand: a stage { P, dir, spots = { {pos, d} }, cam } or nil
local function findStage(hrp, entries)
	local ignore = {}
	for _, other in ipairs(Players:GetPlayers()) do
		if other.Character then
			table.insert(ignore, other.Character)
		end
	end
	local drops = Workspace:FindFirstChild("Drops")
	if drops then
		table.insert(ignore, drops)
	end
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Exclude
	overlap.FilterDescendantsInstances = ignore
	-- invisible markers / colliders, units and rubble never block the view or the graves' footprints
	local function blocks(part)
		return part.Transparency < 0.9 and part.CollisionGroup ~= "Units" and part.CollisionGroup ~= "Debris"
	end
	local function solidHit(from, to)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		local skip = table.clone(ignore)
		for _ = 1, 8 do
			params.FilterDescendantsInstances = skip
			local hit = Workspace:Raycast(from, to - from, params)
			if not hit or blocks(hit.Instance) then
				return hit
			end
			table.insert(skip, hit.Instance)
		end
		return nil
	end
	local function anyBlocking(parts)
		for _, part in ipairs(parts) do
			if blocks(part) then
				return true
			end
		end
		return false
	end
	local up = Vector3.yAxis
	local feet = charFeet(hrp)
	local P = Vector3.new(hrp.Position.X, feet.Y, hrp.Position.Z)

	GraveScene.lastFail = {} -- (why each layout was refused: for testing)
	for _, scale in ipairs(SCALES) do
		-- the arc: graves side by side, its length from their widths
		local widths, length = {}, 0
		for i, e in ipairs(entries) do
			local s = graveSize(e.key, scale)
			widths[i] = math.max(s.X, s.Z)
			length += widths[i] + (i > 1 and GAP or 0)
		end
		-- layouts to try: the normal arc, a tighter one (a wider spread, it fits in front of obstacles), a wider one;
		-- each in every direction, ahead first
		local baseRadius = math.max(MIN_RADIUS, length / MAX_SPAN)
		local radii = { baseRadius }
		local tight = math.max(13, length / MAX_TIGHT_SPAN)
		if tight < baseRadius - 2 then
			table.insert(radii, tight)
		end
		table.insert(radii, baseRadius + 6)
		local dirs = { 0 }
		for k = 1, 12 do
			table.insert(dirs, 15 * k)
			if k < 12 then
				table.insert(dirs, -15 * k)
			end
		end

			local camera = Workspace.CurrentCamera
		local lookDir = flat(camera and camera.CFrame.LookVector or hrp.CFrame.LookVector)
		for _, radius in ipairs(radii) do
			local span = length / radius
			for _, degrees in ipairs(dirs) do
				local d = rotate(lookDir, math.rad(degrees))
				local spots, ok = {}, true
				local along = -length / 2
				for i, e in ipairs(entries) do
					local a = (along + widths[i] / 2) / radius
					along += widths[i] + GAP
					local gd = rotate(d, a)
					local probe = P + gd * radius
					local hit = solidHit(probe + up * 20, probe - up * 40)
					if not (hit and hit.Normal.Y > 0.9 and math.abs(hit.Position.Y - P.Y) < 0.6) then
						GraveScene.lastFail[scale .. "/" .. math.floor(radius) .. "/" .. degrees] = "floor " .. i .. " " .. (hit and (hit.Instance.Name .. string.format(" %.1f", hit.Position.Y - P.Y)) or "none")
						ok = false
						break
					end
					local g = hit.Position
					local s = graveSize(e.key, scale)
					-- the footprint must be free (a little above the floor, so thin floor decor does not count)
					local box = CFrame.lookAt(g, g + gd) + up * (s.Y / 2 + 0.6)
					local inBox = Workspace:GetPartBoundsInBox(box, Vector3.new(s.X * 0.85, s.Y - 0.8, s.Z * 0.85), overlap)
					if anyBlocking(inBox) then
						local names = {}
						for _, part in ipairs(inBox) do
							if blocks(part) then
								table.insert(names, part:GetFullName())
							end
						end
						GraveScene.lastFail[scale .. "/" .. math.floor(radius) .. "/" .. degrees] = "footprint " .. i .. " " .. table.concat(names, ", ")
						ok = false
						break
					end
					-- open ground between the character and the grave (not behind a monument, a step or a stall)
				local h = solidHit(P + up * 1.2, g + up * 1.2)
				if h then
					GraveScene.lastFail[scale .. "/" .. math.floor(radius) .. "/" .. degrees] = "path " .. i .. " " .. h.Instance.Name
					ok = false
					break
				end
				-- the grave cinematic must be able to play right there (its camera shots), so the hand-off never moves it
				if not GraveCinematic.fits(e.key, g, gd) then
					GraveScene.lastFail[scale .. "/" .. math.floor(radius) .. "/" .. degrees] = "cinematic " .. i
					ok = false
					break
				end
				spots[i] = { pos = g, dir = gd }
				end
				if ok then
					GraveScene.lastFail[scale .. "/" .. math.floor(radius) .. "/" .. degrees] = "camera"
					-- the camera behind the character: back off until the outer graves fit in the view
					local camPos
					local side = Vector3.new(-d.Z, 0, d.X) * 2.5 -- (a little over the shoulder, the character is not in the middle)
					for back = 8, 24, 2 do
						local cp = P - d * back + side + up * (5 + back * 0.25)
						local fits = true
						for _, sp in ipairs(spots) do
							local v = flat(sp.pos - cp)
							if math.acos(math.clamp(v:Dot(d), -1, 1)) > MAX_VIEW_ANGLE then
								fits = false
								break
							end
						end
						if fits then
							local clear = not anyBlocking(Workspace:GetPartBoundsInRadius(cp, 1.3, overlap))
							-- every grave (both sides and the middle) and the ground between them must be in plain view
							local targets = {}
							for i, sp in ipairs(spots) do
								local across = Vector3.new(-sp.dir.Z, 0, sp.dir.X) * widths[i] * 0.4
								-- (from knee height up: a low step or kerb in front of a grave is fine)
								table.insert(targets, sp.pos + up * 2.5)
								table.insert(targets, sp.pos + up * 2.5 + across)
								table.insert(targets, sp.pos + up * 2.5 - across)
								table.insert(targets, sp.pos + up * 4)
							end
							for k = 0, 8 do
								local a = (k / 8 - 0.5) * span
								table.insert(targets, P + rotate(d, a) * radius * 0.6 + up * 2.5)
							table.insert(targets, P + rotate(d, a) * radius + up * 2.5) -- (between the graves too)
							end
							for _, target in ipairs(targets) do
								local h = solidHit(cp, target)
								if h then
									GraveScene.lastFail[scale .. "/" .. math.floor(radius) .. "/" .. degrees] = "view " .. h.Instance:GetFullName()
									clear = false
									break
								end
							end
							if clear then
								camPos = cp
							end
							break -- (backing off further only helps the fit, not the view)
						end
					end
					if camPos then
						return { P = P, dir = d, spots = spots, cam = camPos, span = span, scale = scale }
					end
				end
			end
		end
	end
	return nil
end

-- ── Selection ────────────────────────────────────────────────
local function current()
	return scene and scene.items[scene.sel]
end

local function paintBar()
	local item = current()
	if not item then
		return
	end
	local ctx = scene.ctx
	local count = ctx.count(item.key)
	nameLbl.Text = item.name .. "   x" .. count
	hintLbl.Text = scene.notice or ctx.hint(item.key)
	local many = math.min(MAX_PULL, count)
	openOneBtn.root:SetAttribute("Disabled", count < 1)
	openManyBtn.root:SetAttribute("Disabled", many < 2)
	openManyBtn.label.Text = (many >= 2) and ("Open x" .. many) or ("Open x" .. MAX_PULL)
end

stepSelection = function(delta)
	if not scene or scene.state ~= "shown" then
		return
	end
	local n = #scene.items
	scene.sel = (scene.sel - 1 + delta) % n + 1
	scene.notice = nil
	paintBar()
end

local function selectItem(i)
	if scene and scene.state == "shown" and scene.items[i] then
		scene.sel = i
		scene.notice = nil
		paintBar()
	end
end

-- ── Teardown ─────────────────────────────────────────────────
local function destroyScene(s)
	if s.folder then
		s.folder:Destroy()
	end
	for _, c in ipairs(s.conns) do
		c:Disconnect()
	end
	if scene == s then
		scene = nil
		gui.Enabled = false
	end
end

-- ── Open ─────────────────────────────────────────────────────
function GraveScene.isOpen()
	return scene ~= nil
end

function GraveScene.open(ctx)
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if scene or not hrp or not Workspace.CurrentCamera or #ctx.entries == 0 then
		return false
	end
	local entries = {}
	for _, e in ipairs(ctx.entries) do
		if GraveOpening.template(e.key) then
			table.insert(entries, e)
		end
	end
	if #entries == 0 then
		return false
	end
	local stage = findStage(hrp, entries)
	if not stage then
		return false
	end

	local s = { ctx = ctx, stage = stage, items = {}, sel = 1, state = "rising", clock = 0, conns = {},
		fullSize = stage.scale == GRAVE_SCALE }
	scene = s
	local up = Vector3.yAxis
	s.folder = Instance.new("Folder")
	s.folder.Name = "GraveSceneFX"
	s.folder.Parent = Workspace

	for i, e in ipairs(entries) do
		local sp = stage.spots[i]
		local model = GraveOpening.template(e.key):Clone()
		model:ScaleTo(stage.scale)
		-- the front (-Z) looks back at the character, the pit's centre (Core) on the spot: like the grave cinematic
		local facing = CFrame.lookAt(sp.pos, sp.pos - sp.dir)
		model:PivotTo(facing)
		local core = model:FindFirstChild("Core")
		if core then
			local off = sp.pos - core.Position
			model:PivotTo(facing + Vector3.new(off.X, 0, off.Z))
		end
		-- (neighbours' flat ground patches can overlap: each a hair higher so they do not flicker)
		local rest = model:GetPivot() + up * (i * 0.015)
		local _, size = model:GetBoundingBox()
		model:PivotTo(rest - up * (size.Y + 0.5))
		model.Parent = s.folder
		GraveOpening.attach(model, { scale = stage.scale, world = true })

		-- a nameplate over it
		local anchor = Instance.new("Part")
		anchor.Anchored = true
		anchor.CanCollide = false
		anchor.CanQuery = false
		anchor.CanTouch = false
		anchor.Transparency = 1
		anchor.Size = Vector3.one * 0.2
		anchor.CFrame = CFrame.new(sp.pos + up * (size.Y + 1.2))
		anchor.Parent = s.folder
		local bb = Instance.new("BillboardGui")
		bb.Size = UDim2.fromOffset(180, 44)
		bb.AlwaysOnTop = true
		bb.LightInfluence = 0
		bb.Enabled = false
		bb.Parent = anchor
		local plate = Theme.label(bb, { text = e.name .. "  x" .. ctx.count(e.key), size = "Body", font = "Strong", color = C.Bone, align = Enum.TextXAlignment.Center, frameSize = UDim2.fromScale(1, 1) })
		Theme.outlineText(plate)

		table.insert(s.items, { key = e.key, name = e.name, model = model, rest = rest, depth = size.Y + 0.5,
			size = size, pos = sp.pos, dir = sp.dir, delay = (i - 1) * RISE_STAGGER, plate = plate, bb = bb })
		if e.key == ctx.selected then
			s.sel = i
		end
	end

	-- the selection circle on the ground round the selected grave
	local maxR = 3
	for _, it in ipairs(s.items) do
		maxR = math.max(maxR, math.max(it.size.X, it.size.Z) * 0.55 + 1)
	end
	s.circle = MagicCircle.build(s.folder, maxR, CIRCLE_GOLD, CIRCLE_ACCENT)
	s.circleR = maxR
	s.circlePos = s.items[s.sel].pos
	s.circleScale = 0
	MagicCircle.place(s.circle, CFrame.new(s.circlePos), 0.01, 1)

	-- dust where each grave breaks through
	local function puff(pos)
		local holder = Instance.new("Part")
		holder.Anchored = true
		holder.CanCollide = false
		holder.CanQuery = false
		holder.CanTouch = false
		holder.Transparency = 1
		holder.Size = Vector3.one * 0.5
		holder.CFrame = CFrame.new(pos + up)
		holder.Parent = s.folder
		local e = Instance.new("ParticleEmitter")
		e.Texture = "rbxasset://textures/particles/smoke_main.dds"
		e.Color = ColorSequence.new(Color3.fromRGB(150, 130, 110), Color3.fromRGB(70, 62, 60))
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 6) })
		e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 1) })
		e.Lifetime = NumberRange.new(1, 1.8)
		e.Speed = NumberRange.new(4, 11)
		e.SpreadAngle = Vector2.new(80, 80)
		e.Drag = 2
		e.Rate = 0
		e.Parent = holder
		e:Emit(16)
	end

	local camLookBase = Vector3.zero
	for _, it in ipairs(s.items) do
		camLookBase += it.pos
	end
	camLookBase = camLookBase / #s.items + up * 2.5
	local camLook = camLookBase

	s.view = WorldView.open({
		keep = { gui },
		openTime = 1.0,
		closeTime = 0.8,
		fov = FOV,
		goal = function(_, dt)
			-- a little towards the selected grave, so the eye is drawn to it
			local it = s.items[s.sel]
			local target = camLookBase:Lerp(it.pos + up * 2.5, 0.25)
			camLook = camLook:Lerp(target, 1 - math.exp(-dt * 4))
			return CFrame.lookAt(stage.cam, camLook)
		end,
		onStep = function(view, dt)
			s.clock += dt
			-- the graves push up, staggered, or sink back
			for _, it in ipairs(s.items) do
				local k
				if s.state == "sinking" or (s.state == "waiting" and it ~= s.items[s.sel]) then
					it.sinkAt = it.sinkAt or s.clock
					k = 1 - smooth((s.clock - it.sinkAt) / SINK_TIME)
				else
					k = smooth((s.clock - it.delay) / RISE_TIME)
					if s.clock - dt < it.delay and s.clock >= it.delay then
						puff(it.pos)
					end
				end
				if k ~= it.k then
					it.k = k
					local rumble = (k > 0 and k < 1) and 0.1 or 0
					it.model:PivotTo((it.rest - up * it.depth * (1 - k))
						* CFrame.new((math.random() - 0.5) * rumble, 0, (math.random() - 0.5) * rumble))
				end
				it.bb.Enabled = s.state == "shown" and k >= 1
				it.plate.TextColor3 = (it == s.items[s.sel]) and C.Soul or C.Bone
			end
			-- graves shown smaller (a crowded spot): the chosen one grows to the cinematic's size while the pull is sent
			if s.state == "waiting" and not s.fullSize then
				local it = s.items[s.sel]
				local g = smooth((s.clock - s.waitStart) / GROW_TIME)
				local want = stage.scale + (GRAVE_SCALE - stage.scale) * g
				if math.abs(it.model:GetScale() - want) > 0.001 then
					it.model:ScaleTo(want)
					it.model:PivotTo(it.rest)
				end
			end
			if s.state == "rising" and s.clock >= (#s.items - 1) * RISE_STAGGER + RISE_TIME then
				s.state = "shown"
				gui.Enabled = true
				paintBar()
			end
			-- the circle glides to the selected grave and turns slowly
			local it = s.items[s.sel]
			s.circlePos = s.circlePos:Lerp(it.pos, 1 - math.exp(-dt * 10))
			local want = (s.state == "shown" or s.state == "waiting") and 1 or 0
			s.circleScale += (want - s.circleScale) * (1 - math.exp(-dt * 6))
			local r = (math.max(it.size.X, it.size.Z) * 0.55 + 1) / s.circleR
			MagicCircle.place(s.circle, CFrame.new(s.circlePos + up * 0.12) * CFrame.Angles(0, s.clock * 0.35, 0),
				math.max(0.01, r * s.circleScale), 1 - 0.75 * s.circleScale)
			-- the necromancer turns to the selected grave
			local hrp2 = view.hrp
			local toward = flat(it.pos - hrp2.Position)
			local now = flat(hrp2.CFrame.LookVector)
			local look = now:Lerp(toward, 1 - math.exp(-dt * 8))
			hrp2.CFrame = CFrame.lookAt(hrp2.Position, hrp2.Position + look)
			-- no answer from the server: give up
			if s.state == "waiting" and s.clock - s.waitStart > WAIT_TIMEOUT then
				GraveScene.cancel()
			end
		end,
		onFinish = function()
			destroyScene(s)
		end,
	})
	if not s.view then
		destroyScene(s)
		return false
	end

	-- click / tap a grave to select it
	table.insert(s.conns, UserInputService.InputBegan:Connect(function(input, processed)
		if processed or scene ~= s then
			return
		end
		if input.KeyCode == Enum.KeyCode.Escape then
			GraveScene.close() -- (G is handled by GravesDock, which toggles the scene)
		elseif input.KeyCode == Enum.KeyCode.A or input.KeyCode == Enum.KeyCode.Left then
			stepSelection(-1)
		elseif input.KeyCode == Enum.KeyCode.D or input.KeyCode == Enum.KeyCode.Right then
			stepSelection(1)
		elseif input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			local ray = Workspace.CurrentCamera:ViewportPointToRay(input.Position.X, input.Position.Y)
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Include
			params.FilterDescendantsInstances = { s.folder }
			local hit = Workspace:Raycast(ray.Origin, ray.Direction * 300, params)
			if hit then
				for i, it in ipairs(s.items) do
					if hit.Instance:IsDescendantOf(it.model) then
						selectItem(i)
						break
					end
				end
			end
		end
	end))
	return true
end

-- ── Open / close ─────────────────────────────────────────────
function GraveScene.openSelected(count)
	local s = scene
	local it = current()
	if not it or s.state ~= "shown" then
		return
	end
	count = math.min(count, s.ctx.count(it.key))
	if count < 1 then
		return
	end
	local sent, reason = s.ctx.onOpen(it.key, count)
	if sent then
		-- the others sink, the selected one waits for the cinematic
		s.state = "waiting"
		s.waitStart = s.clock
		s.waitKey = it.key
		gui.Enabled = false
	else
		s.notice = (reason == "full") and "Inventory full" or "Cannot open that now"
		paintBar()
	end
end

-- the graves sink, the view glides back; then(): called once everything is restored
function GraveScene.close(andThen)
	local s = scene
	if not s or s.state == "sinking" then
		return
	end
	s.state = "sinking"
	gui.Enabled = false
	task.delay(math.max(0, SINK_TIME - 0.35), function()
		if s.view then
			if andThen then
				local old = s.view.opts.onFinish
				s.view.opts.onFinish = function(v)
					old(v)
					andThen()
				end
			end
			s.view:close()
		end
	end)
end

function GraveScene.cancel()
	GraveScene.close()
end

function GraveScene.takeStage(graveType)
	local s = scene
	if not s then
		return nil
	end
	local stage
	if s.state == "waiting" and s.waitKey == graveType then
		local it = s.items[s.sel]
		stage = { G = it.pos, dir = it.dir, risen = true }
	end
	-- end the view at once: the cinematic (or the overlay) takes over in the same frame
	s.view:finish()
	return stage
end

return GraveScene
