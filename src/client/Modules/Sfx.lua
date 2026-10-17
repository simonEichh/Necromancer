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
	voice_arrival = { id = "rbxassetid://139893314350646", volume = 1 }, -- his pull (SovereignArrival): "High Command sends its regards. The Envoy has arrived."
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
	-- Veyr (docs/veyr.md "Sound", sounds/README.md "veyr/"; originals in sounds/_source/veyr, trimmed 2026-10-17)
	veyr_ring = { id = "rbxassetid://117887968343713", volume = 0.4 }, -- ring.ogg: the glassy tink (sights, shards, the bolt's end)
	veyr_crack = { id = "rbxassetid://99961533538277", volume = 1 }, -- crack.ogg: his rifle shot
	veyr_bolt = { id = "rbxassetid://76462665268038", volume = 0.7 }, -- bolt.ogg: the bolt worked
	veyr_impact = { id = "rbxassetid://136696684974250", volume = 0.8 }, -- impact.ogg: the round lands
	veyr_charge = { id = "rbxassetid://129929686412363", volume = 0.7 }, -- charge.ogg: the rising inward charge (special, finisher, pull)
	veyr_collapse = { id = "rbxassetid://92603837472906", volume = 0.8 }, -- collapse.ogg: the deep implosion (special, the gate's break)
	veyr_ash = { id = "rbxassetid://136943880026332", volume = 0.8 }, -- ash.ogg: the gate turning to ash (finisher)
	veyr_claws = { id = "rbxassetid://127179090907939", volume = 0.7 }, -- claws.ogg: the hands tearing the slit open, an undead howl in it (pull)
	veyr_ignite = { id = "rbxassetid://114521740751265", volume = 0.9 }, -- ignite.ogg: his eyes ignite (pull)
	veyr_cloth = { id = "rbxassetid://89294116958275", volume = 0.8 }, -- cloth.ogg: the mantle flaring out (pull)
	veyr_glint = { id = "rbxassetid://120054004729730", volume = 0.6 }, -- glint.ogg: a scope glint (pull: his echo, the field)
	veyr_rift = { id = "rbxassetid://135288900082496", volume = 0.8 }, -- rift.ogg: the far opening tears (pull)
	-- his finisher's own (sounds/veyr/, 2026-10-17): the beds loop under it for whoever watches, the rest are one-shots
	veyr_ambience = { id = "rbxassetid://129605371290568", volume = 0.35 }, -- ambience.ogg: the dark bed (24 s loop)
	veyr_aura = { id = "rbxassetid://132362248991955", volume = 0.35 }, -- aura.ogg: his charge aura (8 s loop)
	veyr_moon = { id = "rbxassetid://90021862324143", volume = 0.2 }, -- moon.ogg: the drone under the moon (8 s loop)
	veyr_buildup = { id = "rbxassetid://109012853809461", volume = 0.8 }, -- buildup.ogg: 5.1 s, cut off at its peak on the shot
	veyr_launch = { id = "rbxassetid://99664322421160", volume = 0.9 }, -- launch.ogg: he launches into the sky
	veyr_rifle_slide = { id = "rbxassetid://137086389136349", volume = 0.25 }, -- rifle_slide.ogg: a giant rifle slides out
	veyr_circle = { id = "rbxassetid://110729038430714", volume = 0.5 }, -- circle.ogg: a magic circle opens
	veyr_laser = { id = "rbxassetid://87496554133026", volume = 0.6 }, -- laser.ogg: the lasers lock on the gate
	veyr_wind = { id = "rbxassetid://113389733640268", volume = 0.9 }, -- wind.ogg: the ash wave rushing past him
	veyr_rocks = { id = "rbxassetid://76085057308662", volume = 0.8 }, -- rocks.ogg: the ground cracks, the rocks lift
	veyr_breath = { id = "rbxassetid://82719739571060", volume = 0.8 }, -- breath.ogg: his exhale in the stillness
	voice_veyr_seat = { id = "rbxassetid://70545838114962", volume = 1 }, -- his finisher (VeyrFinisher): "One round. That is all you deserve."
	voice_veyr_bang = { id = "rbxassetid://82860162572332", volume = 1 }, -- his finisher, just before the shot: "Bang."
	voice_veyr_arrival = { id = "rbxassetid://110588920076095", volume = 1 }, -- his pull (VeyrArrival), a demonic undead voice: "Death is just the distance between us."
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
	local h = { sound = s } -- (sound: for effects on it, e.g. an equalizer)
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

-- (timePosition: start that many seconds in; returns the Sound, which destroys itself when it ends)
function Sfx.play(name, parent, volume, pitch, timePosition)
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
	if timePosition and timePosition > 0 then
		s.TimePosition = timePosition
	end
	s:Play()
	return s
end

return Sfx
