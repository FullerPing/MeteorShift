--!strict
-- Assumptions of the economy pacing model (Shared.Pacing, spec §7.4, docs/balance.md).
-- These describe how a typical free player behaves, not game rules: nothing in
-- gameplay reads them. Prices, rates and meteor timings come from the other Config files.

return {
	HitsPerMinuteShare = 0.7, -- share of swing slots that actually land (aiming, walking between nodes)
	TripSeconds = 40, -- walk home, drop the backpack into the hopper, walk back
	DebrisActivityShare = 0.5, -- share of the time between meteors spent mining debris
	SellInterval = 60, -- the player collects bars and sells this often, seconds
	StepSeconds = 2, -- simulation step
	SampleInterval = 60, -- timeline snapshot spacing, seconds
	Horizon = 2 * 3600, -- how far a run goes by default, seconds
}
