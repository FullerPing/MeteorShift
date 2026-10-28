--!strict
-- The Crown plateau (map v3): the Sky Lift up from the end of the north avenue and the Meteor Dive back down
return {
	LiftRebirths = 1, -- rebirths needed to ride the Sky Lift
	DiveApex = 80, -- studs the dive rises above its pad: high enough to clear a meteor in the crater
	DiveTarget = Vector3.new(0, 4, 104), -- the crater's north rim, between the mouth (83) and the ring road (125)
	DiveCooldown = 2, -- seconds between launches for one player
	PromptRange = 10,
}
