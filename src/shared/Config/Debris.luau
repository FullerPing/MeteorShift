--!strict
-- Debris rocks between meteors (spec §5.7). The rocks themselves are placed in
-- Workspace.Map.Debris in Studio; this only tunes their behaviour.

return {
	Hp = 4, -- hits to break for the player a rock is sized for (HP is 4 × that pickaxe's Mining Power)
	RerollInterval = 60, -- untouched rocks re-pick who they are sized for this often
	RespawnMin = 30,
	RespawnMax = 60,
	Ore = "iron",
	YieldFraction = 0.25, -- ore per hit relative to a meteor node
}
