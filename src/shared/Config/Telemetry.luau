--!strict
-- Analytics tuning (spec §13), read by TelemetryService and Server.Lib.Telemetry.

return {
	-- Seconds between the per-player "active actions per minute" custom events
	ActionsInterval = 60,
	-- returned_offline_income files hours away into whole-hour buckets, "0" up to
	-- this many; longer absences share one "<cap>+" bucket so the custom field
	-- stays low-cardinality for the analytics dashboard.
	HoursAwayCap = 48,
	-- Menus whose opens are counted (menu_opened): the client watches the "<Name>Open" player attribute of each
	-- and reports a false-to-true change; the server ignores names not listed here.
	Menus = { "Shop", "Pets", "Hatch", "Rebirth", "Store", "Index", "Daily", "Codes", "Settings", "Refinery", "Backpack", "Perks", "OreFields" },
	-- The most menu opens one player can report per ActionsInterval; more are dropped (a spamming client
	-- can't flood the analytics)
	MenuOpensCap = 120,
}
