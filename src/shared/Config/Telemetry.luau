--!strict
-- Analytics tuning (spec §13), read by TelemetryService and Server.Lib.Telemetry.

return {
	-- Seconds between the per-player "active actions per minute" custom events
	ActionsInterval = 60,
	-- returned_offline_income files hours away into whole-hour buckets, "0" up to
	-- this many; longer absences share one "<cap>+" bucket so the custom field
	-- stays low-cardinality for the analytics dashboard.
	HoursAwayCap = 48,
}
