-- Hush's gate finisher, THE LAST CROSS (docs/hush.md "Beat sheet"): seconds after the server starts it. The server holds
-- the gate until GATE_HIT and ends the finisher at END (Army FINISHERS); the client (HushFinisher) and the unit animator
-- (UnitAnimator, the Crucified pose: the rise and the snapping head) play the rest on the same clock.
local HushTimeline = {}

-- (2026-11-05, the user: the start up to the rifts was too long, and the glow and the lightning must begin while he is
-- still floating up: the first 18 s became 11 s. Then: a solid cross floats up out of a rift in the ground while the chains
-- swarm, and the chains wind themselves round it; only when it is fully wrapped does it fall)
HushTimeline.FINISHER = {
	RISE = 0, -- the army stops, Hush floats up; the sky darkens, the glow and the first lightning begin at STORM, already during the rise
	STORM = 0.4, -- the glow and the lightning start
	SNAP = 5, -- his head twitches, then snaps harder and faster; every snap pulses the glow
	RIFTS = 11, -- huge rifts tear open behind him, one after another
	CHAINS = 18, -- huge chains drift out slowly, then accelerate into a swarm
	GROUND_RIFT = 19.5, -- a wide rift tears open in the lane floor
	CROSS_RISE = 20.5, -- the solid cross floats up out of it while the chains swarm
	CROSS = 27, -- the chains wind themselves round the cross, one after another
	FALL = 38, -- fully wrapped: the cross topples away from him towards the gate
	IMPACT = 45, -- it slams into the gate
	GATE_HIT = 45.4, -- the server breaks the gate (a beat after the hit)
	RAVINE = 45, -- the ravine tears open at the very moment of the hit (2026-11-05, the user), spreading from the impact
	SHOT_RAVINE = 46.6, -- the camera cuts from the impact shot to the ravine shot
	DESCEND = 53, -- the camera goes back to Hush, who floats slowly down
	END = 59,

	SHOT_STORM = 3.5, -- the camera pulls back from the rise shot to the storm shot
	RISE_HEIGHT = 34, -- studs he floats up
	RISE_TIME = 4.5, -- seconds the rise takes
	DESCEND_TIME = 6, -- seconds the descent takes (it ends at END)
	-- the head snaps: when (seconds into the finisher), accelerating (a snap every ~0.7 s down to every ~0.25 s)
	SNAPS = { 5.2, 5.9, 6.5, 7.0, 7.45, 7.85, 8.2, 8.5, 8.8, 9.05, 9.3, 9.55, 9.8 },
}

return HushTimeline
