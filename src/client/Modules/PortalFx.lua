-- The portal behind the gate (server: Modules/Portal; attributes on the gate tower folders OuterWall...GateTower<n>):
--   PortalOpen   the plot has a run: the tower's sealed door (GateDoor) bursts outwards and falls flat, behind it
--                an arched portal of swirling light appears
--   Sealed       the run's gate still stands: the portal is dim and slow ("THE GATE STILL STANDS"); when it turns
--                false (the gate fell) the portal wakes with a flare
--   RealmDone / RealmSize / Remaining / Ready
--                five rune stones in an arc above the door show the ascensions done in this realm (lit), the one the
--                player can do now pulses; text: "THE WAY OPENS IN N ASCENSIONS" or "THE WAY IS OPEN" (Ready: the
--                portal glows gold and its owner can walk through, which is the ascension)
--   RejectAt     someone was thrown back: the runes flare, a shockwave ring rolls out of the portal
-- Purely cosmetic and client side; the server decides who passes.
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local VOID = Color3.fromRGB(46, 16, 74)
local SWIRL = Color3.fromRGB(170, 90, 255)
local RIM = Color3.fromRGB(150, 80, 230)
local GOLD = Color3.fromRGB(255, 196, 90)
local RUNE_OFF = Color3.fromRGB(56, 54, 66)
local REJECT = Color3.fromRGB(255, 70, 120)
local BONE = Color3.fromRGB(222, 214, 190)
-- the portal is a big arch, a little smaller than the gate (the mausoleum, about 24 x 35); it stands in front of the
-- tower's plinth (which sticks out PLINTH_OUT in front of the old door), so nothing of the tower covers it
local PORTAL_W, PORTAL_H = 20, 30
local PLINTH_OUT = 1.8

local portals = {} -- [tower folder] = state

local function part(parent, name, size, cf, color, material, shape)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.Neon
	if shape then
		p.Shape = shape
	end
	p.Parent = parent
	return p
end

local function dust(pos, amount)
	local holder = part(workspace, "PortalDust", Vector3.new(1, 1, 1), CFrame.new(pos), BONE, Enum.Material.SmoothPlastic)
	holder.Transparency = 1
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	e.Color = ColorSequence.new(Color3.fromRGB(120, 112, 110))
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 3), NumberSequenceKeypoint.new(1, 8) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) })
	e.Lifetime = NumberRange.new(1.5, 2.5)
	e.Speed = NumberRange.new(6, 14)
	e.SpreadAngle = Vector2.new(180, 60)
	e.Drag = 2
	e.Enabled = false
	e.Parent = holder
	e:Emit(amount)
	Debris:AddItem(holder, 3)
end

-- ============================================================
-- Building the portal (in front of the tower's face, where the door was)
-- ============================================================
local function build(state)
	local door = state.door
	local folder = Instance.new("Folder")
	folder.Name = "PortalFx"
	folder.Parent = workspace
	state.folder = folder
	local base = state.doorCf * CFrame.new(0, -door.Size.Y / 2, -PLINTH_OUT) -- below the door, in front of the plinth
	state.base = base
	local w, h = PORTAL_W, PORTAL_H
	local straight = h - w / 2 -- the arch: a block below, a half disc on top
	local turn = CFrame.Angles(0, math.rad(90), 0) -- (cylinder axis X -> local Z, facing the lane)
	-- the rim, the dark void, the glowing swirl layer
	state.rim = {
		part(folder, "Rim", Vector3.new(w + 1.4, straight, 0.3), base * CFrame.new(0, straight / 2, -0.05), RIM),
		part(folder, "Rim", Vector3.new(0.3, w + 1.4, w + 1.4), base * CFrame.new(0, straight, -0.05) * turn, RIM, nil, Enum.PartType.Cylinder),
	}
	state.void = {
		part(folder, "Void", Vector3.new(w, straight, 0.3), base * CFrame.new(0, straight / 2, -0.25), VOID),
		part(folder, "Void", Vector3.new(0.3, w, w), base * CFrame.new(0, straight, -0.25) * turn, VOID, nil, Enum.PartType.Cylinder),
	}
	-- swirling strokes turning round the centre of the arch's disc
	state.centre = base * CFrame.new(0, straight, -0.45)
	state.swirl = {}
	local scale = w / 10
	for k = 1, 14 do
		local s = part(folder, "Swirl", Vector3.new(0.35, (2.6 + (k % 3)) * scale * 0.8, 0.1), state.centre, SWIRL)
		s.Transparency = 0.25
		table.insert(state.swirl, { part = s, radius = (1 + (k % 4) * 1.1) * scale * 0.9, phase = k / 14 * math.pi * 2, speed = 0.8 + (k % 3) * 0.35 })
	end
	local light = Instance.new("PointLight")
	light.Color = SWIRL
	light.Range = 50
	light.Brightness = 1.6
	light.Shadows = false
	light.Parent = state.void[2]
	state.light = light
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(SWIRL, GOLD)
	e.LightEmission = 1
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(1, 0) })
	e.Lifetime = NumberRange.new(1.2, 2.2)
	e.Speed = NumberRange.new(1, 4)
	e.SpreadAngle = Vector2.new(40, 40)
	e.Rate = 60
	e.EmissionDirection = Enum.NormalId.Front
	e.Parent = state.void[1]
	state.sparks = e

	-- five rune stones in an arc above the door frame
	state.runes = {}
	local size = state.tower:GetAttribute("RealmSize") or 5
	local arcCentre = base * CFrame.new(0, h - w / 2, -0.9) -- the centre of the arch's round top
	local arcRadius = w / 2 + 5
	for k = 1, size do
		local a = math.rad(160 - (k - 1) * (140 / math.max(1, size - 1)))
		local pos = arcCentre * CFrame.new(math.cos(a) * arcRadius, math.sin(a) * arcRadius, 0)
		local stone = part(folder, "RuneStone", Vector3.new(3, 4.2, 0.9), pos * CFrame.Angles(0, 0, a - math.pi / 2), Color3.fromRGB(70, 70, 82), Enum.Material.Slate)
		local glyph = part(folder, "Rune", Vector3.new(0.6, 2.7, 0.2), stone.CFrame * CFrame.new(0, 0, -0.5), RUNE_OFF)
		local bar = part(folder, "Rune", Vector3.new(1.6, 0.45, 0.2), stone.CFrame * CFrame.new(0, 0.4, -0.5) * CFrame.Angles(0, 0, math.rad(k * 37)), RUNE_OFF)
		table.insert(state.runes, { glyph, bar })
	end

	-- the text over the runes
	local holder = part(folder, "PortalText", Vector3.new(1, 1, 1), base * CFrame.new(0, h + 17, -1), BONE, Enum.Material.SmoothPlastic) -- (above the PLOT sign)
	holder.Transparency = 1
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.new(0, 520, 0, 60)
	gui.MaxDistance = 160
	gui.LightInfluence = 0
	gui.Parent = holder
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = BONE
	label.TextStrokeColor3 = Color3.fromRGB(8, 8, 12)
	label.TextStrokeTransparency = 0
	label.Parent = gui
	state.label = label
end

local function destroy(state)
	if state.folder then
		state.folder:Destroy()
		state.folder = nil
	end
	-- the door stands sealed again
	state.door.CFrame = state.doorCf
	state.door.Transparency = state.doorTransparency
end

-- the sealed door bursts outwards and falls flat towards the lane (instantly when `animate` is false)
local function burstDoor(state, animate)
	local door = state.door
	local hinge = state.doorCf * CFrame.new(0, -door.Size.Y / 2, -door.Size.Z / 2) -- its bottom front edge
	local lying = hinge * CFrame.Angles(math.rad(-90), 0, 0) * CFrame.new(0, door.Size.Y / 2, door.Size.Z / 2) * CFrame.new(0, 0, -1.5)
	if animate then
		door.CFrame = state.doorCf * CFrame.new(0, 0, -1.2)
		TweenService:Create(door, TweenInfo.new(0.9, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out), { CFrame = lying }):Play()
		dust((state.doorCf * CFrame.new(0, -door.Size.Y / 2 + 2, -4)).Position, 40)
	else
		door.CFrame = lying
	end
end

-- ============================================================
-- Per tower
-- ============================================================
local function update(state, open)
	local tower = state.tower
	if open and not state.folder then
		local fresh = workspace:GetServerTimeNow() - (tower:GetAttribute("OpenAt") or 0) < 3
		burstDoor(state, fresh)
		build(state)
	elseif not open and state.folder then
		destroy(state)
	end
end

local function register(tower)
	if portals[tower] then return end
	local door = tower:FindFirstChild("GateDoor")
	if not door then return end
	local state = { tower = tower, door = door, doorCf = door.CFrame, doorTransparency = door.Transparency }
	portals[tower] = state
	update(state, tower:GetAttribute("PortalOpen") == true)
	tower:GetAttributeChangedSignal("PortalOpen"):Connect(function()
		update(state, tower:GetAttribute("PortalOpen") == true)
	end)
	tower:GetAttributeChangedSignal("Sealed"):Connect(function()
		if not tower:GetAttribute("Sealed") and state.folder then
			state.wakeAt = os.clock()
			state.sparks:Emit(80)
		end
	end)
	tower:GetAttributeChangedSignal("RejectAt"):Connect(function()
		state.rejectAt = os.clock()
		if state.base then
			-- a shockwave ring rolls out of the portal along the floor
			local ring = part(state.folder or workspace, "Shockwave", Vector3.new(0.4, 6, 6), state.base * CFrame.new(0, 1, -3) * CFrame.Angles(0, 0, math.rad(90)), REJECT, Enum.Material.Neon, Enum.PartType.Cylinder)
			ring.Transparency = 0.2
			TweenService:Create(ring, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(0.4, 48, 48), Transparency = 1 }):Play()
			Debris:AddItem(ring, 0.8)
		end
	end)
end

local function scan()
	local ring = workspace:FindFirstChild("OuterWall")
	if not ring then return end
	for _, d in ipairs(ring:GetDescendants()) do
		if d.Name:match("^GateTower%d") then
			register(d)
		end
	end
end
scan()
task.delay(5, scan) -- (the outer wall may still be streaming in)

RunService.RenderStepped:Connect(function()
	local now = os.clock()
	for _, state in pairs(portals) do
		if state.folder then
			local tower = state.tower
			local ready = tower:GetAttribute("Ready") == true
			local done = tower:GetAttribute("RealmDone") or 0
			local left = tower:GetAttribute("Remaining") or 0
			local sealed = tower:GetAttribute("Sealed") == true
			local flare = state.rejectAt and math.max(0, 1 - (now - state.rejectAt) / 0.8) or 0
			local wake = state.wakeAt and math.max(0, 1 - (now - state.wakeAt) / 1.5) or 0
			-- the swirl turns (slow and dim while sealed), faster and golden when the way is open
			local c = state.centre
			state.spin = (state.spin or 0) + (now - (state.lastNow or now)) * (sealed and 0.35 or ready and 1.8 or 1)
			state.lastNow = now
			for _, s in ipairs(state.swirl) do
				local a = s.phase + state.spin * s.speed
				s.part.CFrame = c * CFrame.Angles(0, 0, a) * CFrame.new(0, s.radius, 0) * CFrame.Angles(0, 0, math.rad(70))
				s.part.Color = ready and GOLD or SWIRL
				s.part.Transparency = sealed and 0.65 or 0.25
			end
			state.sparks.Rate = sealed and 12 or 60
			for _, p in ipairs(state.rim) do
				p.Color = (ready and GOLD or RIM):Lerp(REJECT, flare)
			end
			state.light.Color = ready and GOLD or SWIRL
			state.light.Brightness = (sealed and 0.6 or 1.4) + math.sin(now * 2) * 0.3 + flare * 3 + wake * 4
			-- runes: lit = done in this realm; the one the player can do now pulses; all lit when the way is open
			local pulse = 0.5 + 0.5 * math.sin(now * 4)
			for k, r in ipairs(state.runes) do
				local color
				if ready or k <= done then
					color = GOLD
				elseif k == done + 1 then
					color = RUNE_OFF:Lerp(GOLD, pulse)
				else
					color = RUNE_OFF
				end
				color = color:Lerp(REJECT, flare)
				r[1].Color = color
				r[2].Color = color
			end
			if sealed then
				state.label.Text = "THE GATE STILL STANDS"
				state.label.TextColor3 = BONE:Lerp(REJECT, flare)
			elseif ready then
				state.label.Text = "THE WAY IS OPEN"
				state.label.TextColor3 = GOLD
			else
				state.label.Text = "THE WAY OPENS IN " .. left .. " ASCENSION" .. (left == 1 and "" or "S")
				state.label.TextColor3 = BONE:Lerp(REJECT, flare)
			end
		end
	end
end)

return {}
