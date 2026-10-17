-- Orvoss's basic attack, DOUBLE REPORT (docs/orvoss.md "Basic attack"): the beats in seconds after the server's
-- AttackAt (model attribute, server time the attack starts). Shared by the server (Units.Orvoss.hitDelay = IMPACT: the
-- damage lands when the ball arrives) and the client (AdmiralAnimator moves him, DoubleReport draws the cannon and the
-- shots). First pass deliberately slow.
return {
	AIM_FROM = 0.1, -- the flintlock swings up, he turns side-on like a duellist
	AIM_TO = 1.0,
	FORM_FROM = 0.4, -- the ghost cannon forms at his left out of fog and upward drips: the barrel first...
	BARREL_TO = 1.1,
	CARRIAGE_FROM = 0.9, -- ...then the carriage
	FORM_TO = 1.6,
	COCK_FROM = 1.7, -- stillness; his thumb draws the hammer back, the fuse catches
	COCK_TO = 2.05,
	FUSE_FROM = 1.8,
	FIRE = 2.4, -- pistol and cannon fire as one
	IMPACT = 2.6, -- the ball and the shot land together: ONE hit (a fast, hard flight)
	SINK_FROM = 3.2, -- the cannon sinks back into the fog
	SINK_TO = 4.4,
	LOWER_FROM = 3.0, -- he lowers the pistol slowly
	LOWER_TO = 5.0,
	-- his gate finisher, THE LAST BROADSIDE (docs/orvoss.md "Beat sheet"): seconds after the server starts it. The
	-- server holds the gate until GATE_HIT and ends the finisher at END (Army FINISHERS); the client (LastBroadside)
	-- plays the rest on the same clock.
	FINISHER = {
		CALL = 0, -- he snaps his compass shut and looks up; a distant bell
		OMEN = 4, -- water drips upwards off his coat, black fog rolls down the lane, ship shadows glide under it
		ANCHOR = 9, -- an anchor falls out of the clouds...
		ANCHOR_HIT = 10.6, -- ...and slams into the ground beside the gate
		SEA = 13, -- the black ocean opens in the sky beyond the gate, the fleet breaks out of it
		FLAGSHIP = 20, -- the flagship tears out last and crosses in front of him
		LINE = 28, -- the fleet swings into line, broadsides on the gate, the ports glow up (loading)
		ORDER = 34, -- spectral rigging, he rises, raises his cutlass; silence
		ORDER_LINE = 37.5, -- "Give them the deep."
		BROADSIDE = 40, -- the travelling broadside: from the farthest ship towards the camera
		FLAG_FIRE = 48, -- the flagship fires last and loudest
		GATE_HIT = 52, -- the server breaks the gate
		DRAG = 52.5, -- the chains pull taut, the fleet drags the ruins into a whirlpool
		CLOSE = 58, -- the ocean closes, the fog lifts
		LAND = 63, -- he drops back down, catches his hat
		END = 67,
	},
}
