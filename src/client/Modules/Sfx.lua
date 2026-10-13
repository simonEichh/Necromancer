-- Sound effects for the cinematics. Every sound id lives here (files and slots: sounds/README.md); a slot without an
-- id is silent, so sounds can be added one at a time. Upload new files with tools/audio/upload_sound.py.
--
--   local h = Sfx.loop(name, parent)   a looping sound in the world on `parent` (a BasePart), starts at volume 0
--     h.set(volume, pitch)             volume 0..1 (times the slot's base volume), pitch = PlaybackSpeed (1 = normal)
--     h.stop(fade)                     fades out over `fade` seconds (0 = at once) and removes it
--   Sfx.play(name, parent, volume, pitch)  a one-shot (parent nil = not in the world, e.g. UI sounds)
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Sfx = {}

-- name -> { id = "rbxassetid://...", volume = base volume }
Sfx.Sounds = {
	rumble = { id = "rbxassetid://110236453654824", volume = 0.8 }, -- sounds/loops/rumble.ogg
}

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
	s.Parent = parent or SoundService
	return s, slot
end

local NOOP = { set = function() end, stop = function() end }

function Sfx.loop(name, parent)
	local s, slot = make(name, parent)
	if not s then
		return NOOP
	end
	s.Looped = true
	s.Volume = 0
	s:Play()
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
