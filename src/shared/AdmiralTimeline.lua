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
}
