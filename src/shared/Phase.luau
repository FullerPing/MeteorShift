--!strict
-- Meteor event states (spec §5.1). The server owns the state machine; clients only read it.

export type Phase = "Countdown" | "Impact" | "Active" | "CoreCracked" | "Cooled" | "Cleanup"

return table.freeze({
	Countdown = "Countdown" :: Phase,
	Impact = "Impact" :: Phase,
	Active = "Active" :: Phase,
	CoreCracked = "CoreCracked" :: Phase,
	Cooled = "Cooled" :: Phase,
	Cleanup = "Cleanup" :: Phase,
})
