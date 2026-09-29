--!strict
-- Networking and hot-path limits (spec §12.3): how often server state reaches
-- clients, and caps on the client effects that network events spawn, so 20
-- players mining at once stays cheap for the server and for every client.

return {
	-- PlayerStateService: Replicate() marks a player dirty and a Heartbeat
	-- accumulator sends every dirty player's State once per this many seconds.
	StateFlushInterval = 0.2,

	-- MiningController: live damage/ore floaters at most (oldest removed first)
	MaxFloaters = 24,
	-- MiningController: live ore fly-in chunks at most (oldest removed first)
	MaxOreChunks = 40,
	-- MiningController: spark emitters reused round-robin, one per recent swing
	SparkPoolSize = 8,
}
