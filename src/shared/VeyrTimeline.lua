-- Veyr's timing contract (docs/veyr.md): the beats of his basic attack, DEAD RECKONING, in seconds from the
-- server-authorized attack start (model attribute ShotAt = server time). Read by the server (when the round lands)
-- and by the client (MarksmanAnimator for his body, VeyrShot for the rings, the round and the impact), so the visible
-- hit and the HP loss cannot drift apart.
local T = {
	AIM_IN = 0.9, -- the rifle settles into the shoulder, the off-hand settles, the posture narrows
	RINGS_FROM = 0.9, -- the focusing rings materialize one after another ahead of the muzzle
	RINGS_TO = 2.2,
	LOCK = 2.2, -- the rings turn coaxial and stop drifting; breathing, cloth and aim settle
	QUIET = 3.15, -- the quiet beat ends
	FIRE = 3.2, -- the shot
	RECOIL_END = 4.5, -- the recoil is absorbed (rifle -> shoulder -> torso -> cloth)
	BOLT_FROM = 4.6, -- the right hand works the bolt (lift, back, forward, down)
	BOLT_TO = 5.9,
	SETTLE_END = 6.4, -- back in the held posture; stillness until the next shot
	ROUND_SPEED = 600, -- studs/s: the round's flight (~0.1 s over his 60-stud firing row)
	HOLD = 9, -- after the last shot he keeps the rifle up this long before he lowers it to the low ready
}

-- His gate finisher, THE FINAL HORIZON (seconds from the server's start; Army.checkFinisher holds the gate and breaks it
-- at GATE_HIT; client VeyrFinisher plays it, MarksmanAnimator flies him; docs/veyr.md "Finisher"). The user's version
-- (2026-10-16): the charge aura with orbiting debris, the ascent, the moon, two giant rifles, the lasers, the quiet,
-- three rounds at once with impact frames, "already dead".
T.FINISHER = {
	QUIET = 0, -- the line goes quiet: letterbox, the camera leaves the player
	MARKSMAN = 2, -- close on him: he seats one round
	SEAT = 4.2, -- the round slides into the chamber
	AURA = 5.5, -- his charge aura: the ground under his perch cracks, debris lifts and starts to circle his energy
	FLEE = 6, -- the army clears the line (server: the army runs back to the graves)
	ASCENT_FROM = 7.5, -- he launches up into the sky, backwards, aiming the whole time, tilted forward by the momentum
	ASCENT_TO = 11,
	PEAK_HEIGHT = 70, -- (studs above his perch)
	PEAK_BACK = 26, -- (studs back up the lane)
	MOON = 10.5, -- the peak: the moon behind him, the sky darkens
	ARSENAL = 13, -- two magic circles open on either side of him
	GIANTS_OUT = 14.5, -- two giant copies of his rifle slide out of them ...
	GIANTS_AIM = 17, -- ... and swing into aim with him
	LOCK = 18, -- three targeting lasers reach the gate (LASER_STEP apart) and converge
	LASER_STEP = 0.4,
	SHIELD = 19.5, -- the keeper raises his hands over the gate
	SCOPE_1 = 18.9, -- (watchers) the first look through his scope: locked on the gate
	SCOPE_1_END = 20.6,
	CHARGE = 21, -- the charge: the debris orbits faster, light is drawn up the lasers into the three muzzles
	STILL = 27, -- everything goes quiet: the debris stops in the air
	LIGHT_RUN = 27.6, -- a faint light runs along each weapon, stock to barrel ...
	LIGHT_END = 29, -- ... then a short pause
	SCOPE_2 = 28.2, -- (watchers) back into his scope until the hit
	FIRE = 30, -- three massive rounds at once: impact frames
	IMPACT = 30.45, -- they hit: impact frames, the scope shatters, the keeper's hands are blown back; only a pinhole
	CRUMBLE = 32, -- the giant rifles dissolve into falling sparks
	TURN = 32.5, -- (after the hit; he no longer turns his back, the user's call: the camera cuts back to him) ...
	DESCEND_FROM = 33, -- ... and drifts back down to his perch
	DESCEND_TO = 37.5,
	GATE_HIT = 38,
	RELOAD = 42.3, -- the last beat (the user: no turning his back): still on the gate, he works the bolt, slowly
	RELOAD_SLOW = 0.65, -- (the bolt plays at this speed: ~2 s, heavier than after a basic shot) -- the gate (still standing, cracks glowing) erupts behind him: the server breaks it here
	FADE = 40, -- the moon fades, the light comes back
	END = 45,
}

-- seconds from the attack start until the round lands, for a shot of `distance` studs (muzzle to aim point)
function T.impactAt(distance)
	return T.FIRE + math.max(0, distance) / T.ROUND_SPEED
end

-- His special, THE LONG GOODBYE (seconds from SpecialAt; Units.Veyr.special, Army.startSpecial, client VeyrSpecial and
-- MarksmanAnimator). The round's flight is a fixed cinematic FLIGHT whatever the distance, so the hits are fixed too.
T.SPECIAL = {
	PLANT = 1.0, -- he leaves his aiming cycle and plants a firmer stance (aimed down the corridor by 0.8)
	LAYOUT = 1.15, -- the corridor is laid out along his settled aim (VeyrSpecial), before the shards leave
	SHARDS_OUT = 1.3, -- his shards fly down the lane to their stations (one after another, SHARD_STEP apart)
	SHARD_STEP = 0.15,
	SHARD_FLY = 1.1,
	SIGILS = 6, -- (one per shard)
	SIGIL_FROM = 1.8, -- the sigils open one after another round the shards, SIGIL_STEP apart
	SIGIL_STEP = 0.45,
	LOCK_FROM = 5.0, -- they turn coaxial and lock one after another, LOCK_STEP apart
	LOCK_STEP = 0.28,
	CHAMBER = 7.0, -- a spectral round forms in the chamber
	BARREL = 8.0, -- it runs down the barrel to the muzzle
	FIRE = 8.8, -- the shot
	FLIGHT = 0.25, -- (through every sigil to the wall)
	IMPACT = 9.05, -- the penetrating fracture: the first hit (80 %)
	COLLAPSE = 10.4, -- the delayed implosion: the second hit (20 %)
	BREAK = 10.7, -- the sigils break up; the shards fly home
	SHARDS_HOME = 12.6,
	END = 13.5,
}

return T
