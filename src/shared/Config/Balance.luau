--!strict
-- Assumptions of the economy pacing model (Shared.Pacing, spec §7.4, docs/balance.md).
-- These describe how a typical free player behaves, not game rules: nothing in
-- gameplay reads them. Prices, rates and meteor timings come from the other Config files.
-- Meteor types: the model also assumes the whole lobby holds the player's own pickaxe tier,
-- so Ice and Crystal come up by Meteor.Types weights as soon as that tier meets theirs
-- (a type the lobby can't mine drops to the next one down, as in Shared.MeteorTypes).

return {
	HitsPerMinuteShare = 0.7, -- share of swing slots that actually land (aiming, walking between nodes)
	TripSeconds = 40, -- walk home, drop the backpack into the hopper, walk back
	DebrisActivityShare = 0.5, -- share of the time between meteors spent mining debris
	ShardsPerMeteor = 10, -- Core Shards a player earns per meteor on average: the 5-shard floor plus a share of the bonus pool, on the meteors that crack (about 13 when it does)
	SellInterval = 60, -- the player collects bars and sells this often, seconds
	StepSeconds = 2, -- simulation step
	SampleInterval = 60, -- timeline snapshot spacing, seconds
	Horizon = 2 * 3600, -- how far a run goes by default, seconds
}
