--!strict
-- Debris rocks between meteors (spec §5.7). The rocks themselves are placed in
-- Workspace.Map.Debris in Studio; this only tunes their behaviour.

return {
	Hp = 20, -- 4 hits with the Basic Pickaxe
	RespawnMin = 30,
	RespawnMax = 60,
	Ore = "iron",
	YieldFraction = 0.25, -- ore per hit relative to a meteor node
}
