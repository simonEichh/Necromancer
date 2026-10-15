-- Sound effects for the cinematics. Every sound id lives here (files and slots: sounds/README.md); a slot without an
-- id is silent, so sounds can be added one at a time. Upload new files with tools/audio/upload_sound.py.
--
--   local h = Sfx.loop(name, parent)   a looping sound in the world on `parent` (a BasePart), starts at volume 0
--     h.set(volume, pitch)             volume 0..1 (times the slot's base volume), pitch = PlaybackSpeed (1 = normal)
--     h.stop(fade)                     fades out over `fade` seconds (0 = at once) and removes it
--   Sfx.play(name, parent, volume, pitch)  a one-shot (parent nil = not in the world, e.g. UI sounds)
--   Sfx.playAt(name, position, volume, pitch, range)  a one-shot at a point in the world (range = the distance it is
--                                    heard to, default 140; far things like a gunship in the sky need more)
--   local h = Sfx.loopAt(name, position, range)  a loop at a point (h.set / h.stop as above; h.move(position))
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Sfx = {}

-- the volume groups (the Settings panel sets them): Master holds Effects and Music, their volumes multiply
local function group(name, parent)
	local g = parent:FindFirstChild(name) or Instance.new("SoundGroup")
	g.Name = name
	g.Parent = parent
	return g
end
Sfx.Master = group("Master", SoundService)
Sfx.Effects = group("Effects", Sfx.Master)
Sfx.Music = group("Music", Sfx.Master)
function Sfx.setVolumes(master, effects, music)
	Sfx.Master.Volume = math.clamp(master or 1, 0, 1)
	Sfx.Effects.Volume = math.clamp(effects or 1, 0, 1)
	Sfx.Music.Volume = math.clamp(music or 1, 0, 1)
end

-- name -> { id = "rbxassetid://...", volume = base volume }
Sfx.Sounds = {
	rumble = { id = "rbxassetid://110236453654824", volume = 0.8 }, -- sounds/loops/rumble.ogg
	-- Malak (sounds/README.md, malak/): his basic attack and the drone
	holo_open = { id = "rbxassetid://134658410245808", volume = 0.6 },
	holo_tap = { id = "rbxassetid://107161022622819", volume = 0.8 },
	target_lock = { id = "rbxassetid://130032888810460", volume = 0.7 },
	laser_hum = { id = "rbxassetid://109042425391276", volume = 0.9 },
	cannon_far = { id = "rbxassetid://131391741535295", volume = 0.9 },
	shell_whistle = { id = "", volume = 0.5 }, -- (silent until a real one exists; the generated placeholder 136986903395796 sounded off)
	shell_impact = { id = "rbxassetid://81958184521977", volume = 1 },
	drone_charge = { id = "rbxassetid://101800259271161", volume = 0.3 },
	drone_bolt = { id = "rbxassetid://77110040590592", volume = 0.6 },
	drone_hit = { id = "rbxassetid://99175078643431", volume = 0.6 },
	-- the Fleet Strike (stereo, played flat; the cue sheet is in FleetStrike.lua)
	voice_call = { id = "rbxassetid://137755688226874", volume = 1 }, -- high_command_passage.ogg
	voice_verdict = { id = "rbxassetid://98769145369327", volume = 1 }, -- corrected: the former opening clip
	voice_defiance = { id = "rbxassetid://105269459367929", volume = 1 }, -- the final standing shot
	rune_click = { id = "rbxassetid://129592415819508", volume = 0.35 },
	rune_confirm = { id = "rbxassetid://80333702320714", volume = 0.7 },
	drone_transform = { id = "rbxassetid://71750103238347", volume = 0.12 },
	transmit_laser = { id = "rbxassetid://92306050351845", volume = 0.5 }, -- (replaces transmit_pulse: the beam into the sky)
	sublift_scanner = { id = "rbxassetid://123365422126618", volume = 0.6 }, -- (under it, up to the open portal)
	tear_rumble = { id = "rbxassetid://100815269897042", volume = 0.6 },
	tear_crack = { id = "rbxassetid://77959564792451", volume = 0.2 },
	tear_open = { id = "rbxassetid://87782507820851", volume = 0.9 },
	portal_hum = { id = "rbxassetid://133901763364756", volume = 0.6 },
	warp_in_suspense = { id = "rbxassetid://84069854063299", volume = 0.8 },
	warp_in_scanner = { id = "rbxassetid://132548472903596", volume = 0.6 },
	warp_in_warhorn = { id = "rbxassetid://83144722290957", volume = 0.9 },
	portal_snap = { id = "rbxassetid://108174408928980", volume = 0.9 },
	ship_hum = { id = "rbxassetid://93352074241039", volume = 0.5 },
	ship_hum2 = { id = "rbxassetid://125935309800038", volume = 0.5 },
	turret_turn = { id = "rbxassetid://124298652524588", volume = 0.35 },
	scan_sweep = { id = "rbxassetid://132910803481650", volume = 0.6 },
	broadside = { id = "", volume = 0.9 },
	missile_launch = { id = "rbxassetid://87074924125787", volume = 0.5 },
	bow_open = { id = "rbxassetid://75819785753943", volume = 0.4 },
	reactor_windup = { id = "rbxassetid://80732352001103", volume = 0.35 },
	reactor_lock = { id = "rbxassetid://109134827602753", volume = 0.8 },
	cannon_charge = { id = "rbxassetid://136468737245177", volume = 0.45 },
	main_beam = { id = "rbxassetid://95516675338021", volume = 1 },
	keeper_roar = { id = "rbxassetid://130529185820696", volume = 0.8 },
	gate_collapse = { id = "rbxassetid://79285090609348", volume = 1 },
	warp_out = { id = "rbxassetid://77036647861580", volume = 0.8 },
	fleet_music = { id = "rbxassetid://74269987308643", volume = 0.5 }, -- (52.5 s, Sfx.music)
}

-- load every sound at the start, so the first time one plays it is not late
task.spawn(function()
	local list = {}
	for _, slot in pairs(Sfx.Sounds) do
		if slot.id ~= "" then
			local s = Instance.new("Sound")
			s.SoundId = slot.id
			table.insert(list, s)
		end
	end
	pcall(function()
		game:GetService("ContentProvider"):PreloadAsync(list)
	end)
end)

local function make(name, parent)
	local slot = Sfx.Sounds[name]
	if not slot or slot.id == "" then
		return nil, slot
	end
	local s = Instance.new("Sound")
	s.Name = "Sfx_" .. name
	s.SoundId = slot.id
	s.RollOffMode = Enum.RollOffMode.InverseTapered
	s.RollOffMinDistance = 12
	s.RollOffMaxDistance = 140
	s.SoundGroup = Sfx.Effects
	s.Parent = parent or SoundService
	return s, slot
end

local NOOP = { set = function() end, stop = function() end }

local handle

function Sfx.loop(name, parent)
	local s, slot = make(name, parent)
	if not s then
		return NOOP
	end
	s.Looped = true
	s.Volume = 0
	s:Play()
	return handle(s, slot)
end

-- a music track (Music group, flat, not looped) from `timePosition` s in, at volume 0: h.set(volume), h.stop(fade)
function Sfx.music(name, timePosition)
	local s, slot = make(name, nil)
	if not s then
		return NOOP
	end
	s.SoundGroup = Sfx.Music
	s.Volume = 0
	s.TimePosition = timePosition or 0
	s:Play()
	return handle(s, slot)
end

function handle(s, slot)
	local h = {}
	local stopped = false
	function h.set(volume, pitch)
		if stopped or not s.Parent then
			return
		end
		s.Volume = slot.volume * math.clamp(volume, 0, 2)
		if pitch then
			s.PlaybackSpeed = pitch
		end
	end
	function h.stop(fade)
		if stopped then
			return
		end
		stopped = true
		if not fade or fade <= 0 or not s.Parent then
			s:Destroy()
			return
		end
		TweenService:Create(s, TweenInfo.new(fade), { Volume = 0 }):Play()
		task.delay(fade + 0.05, function()
			s:Destroy()
		end)
	end
	return h
end

-- an attachment in the world to hold a sound at a point (removed with the sound)
local function anchorAt(position)
	local a = Instance.new("Attachment")
	a.Name = "SfxPoint"
	a.WorldPosition = position
	a.Parent = workspace.Terrain
	return a
end

function Sfx.playAt(name, position, volume, pitch, range)
	local slot = Sfx.Sounds[name]
	if not slot or slot.id == "" then
		return
	end
	local a = anchorAt(position)
	local s = make(name, a)
	if range then
		s.RollOffMaxDistance = range
		s.RollOffMinDistance = math.max(12, range * 0.12)
	end
	s.Volume = slot.volume * (volume or 1)
	s.PlaybackSpeed = pitch or 1
	s.Ended:Connect(function()
		a:Destroy()
	end)
	s:Play()
end

function Sfx.loopAt(name, position, range)
	local slot = Sfx.Sounds[name]
	if not slot or slot.id == "" then
		return { set = function() end, stop = function() end, move = function() end }
	end
	local a = anchorAt(position)
	local h = Sfx.loop(name, a)
	local s = a:FindFirstChildOfClass("Sound")
	if s and range then
		s.RollOffMaxDistance = range
		s.RollOffMinDistance = math.max(12, range * 0.12)
	end
	local stop = h.stop
	function h.stop(fade)
		stop(fade)
		task.delay((fade or 0) + 0.1, function()
			a:Destroy()
		end)
	end
	function h.move(p)
		a.WorldPosition = p
	end
	return h
end

function Sfx.play(name, parent, volume, pitch)
	local s, slot = make(name, parent)
	if not s then
		return
	end
	s.Volume = slot.volume * (volume or 1)
	s.PlaybackSpeed = pitch or 1
	s.PlayOnRemove = false
	s.Ended:Connect(function()
		s:Destroy()
	end)
	s:Play()
end

return Sfx
