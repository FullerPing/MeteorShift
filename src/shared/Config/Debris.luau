--!strict
-- Debris rocks between meteors (spec §5.7). The rocks themselves are placed in
-- Workspace.Map.Debris in Studio; this only tunes their behaviour.

export type Field = { Id: string, Name: string, Color: Color3 }

return {
	Hp = 4, -- hits to break for the player a rock is sized for (HP is 4 × that pickaxe's Mining Power)
	RerollInterval = 60, -- untouched rocks re-pick who they are sized for this often
	RespawnMin = 30,
	RespawnMax = 60,
	Ore = "iron",
	YieldFraction = 0.25, -- ore per hit relative to a meteor node

	-- The four ore fields (Workspace.Map.DebrisFields.<Id>): the travel list and each field's colour
	Fields = {
		{ Id = "RustWorks", Name = "Rust Works", Color = Color3.fromRGB(255, 124, 56) },
		{ Id = "FrostYard", Name = "Frost Yard", Color = Color3.fromRGB(110, 212, 255) },
		{ Id = "VioletQuarry", Name = "Violet Quarry", Color = Color3.fromRGB(184, 116, 255) },
		{ Id = "SulfurRidge", Name = "Sulfur Ridge", Color = Color3.fromRGB(255, 204, 64) },
	},
	TravelCooldown = 3, -- seconds between teleports
	Rock = {
		TintMix = 0.4, -- how far a rock's stone colour moves toward its field colour
		LightRange = 9, -- the soft glow each live rock gives off
		LightBrightness = 0.7,
		SparkleRate = 2, -- ambient sparkles a second per rock
		BurstCount = 14, -- chips thrown when a rock breaks
	},
}
