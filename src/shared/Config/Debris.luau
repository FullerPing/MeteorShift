--!strict
-- Debris rocks between meteors (spec §5.7). The rocks themselves are placed in
-- Workspace.Map.Debris in Studio; this only tunes their behaviour.

-- What a field's rocks pay. "Cash" pays `Seconds` of the breaker's expected income (Shared.Income, kept
-- between CashFloor and CeilingShare of the next rebirth's cost). "Ore" drops `Ore` into the hopper at
-- `OreMult` of a full hit, scaled by the player's level like a meteor's ore. `Hp` is the hits to break.
export type Reward = {
	Kind: string, -- "Cash" or "Ore"
	Hp: number,
	Seconds: number?,
	CashFloor: number?,
	CeilingShare: number?,
	Ore: string?,
	OreMult: number?,
}
export type Field = { Id: string, Name: string, Color: Color3, Reward: Reward }

return {
	Hp = 4, -- hits to break for the player a rock is sized for (HP is 4 × that pickaxe's Mining Power); the default for rocks outside a field
	RerollInterval = 60, -- untouched rocks re-pick who they are sized for this often
	RespawnMin = 30,
	RespawnMax = 60,
	Ore = "iron",
	YieldFraction = 0.25, -- ore per hit relative to a meteor node

	-- The four ore fields (Workspace.Map.DebrisFields.<Id>): the travel list, each field's colour and what
	-- its rocks pay. A rock's field is its `Field` attribute. Rust Works and Frost Yard sit side by side and
	-- both pay cash, Frost Yard for more hits and a little more per hit; Violet Quarry and Sulfur Ridge pay
	-- better ore than the iron of the meteors' filler, for more hits again. Ore stays well under the same ore
	-- from a meteor node (a meteor hit is worth a full OrePerHit), so the fields never replace the meteors.
	Fields = {
		{ Id = "RustWorks", Name = "Rust Works", Color = Color3.fromRGB(255, 124, 56),
			Reward = { Kind = "Cash", Hp = 4, Seconds = 3, CashFloor = 10, CeilingShare = 0.003 } },
		{ Id = "FrostYard", Name = "Frost Yard", Color = Color3.fromRGB(110, 212, 255),
			Reward = { Kind = "Cash", Hp = 10, Seconds = 9, CashFloor = 30, CeilingShare = 0.01 } },
		{ Id = "VioletQuarry", Name = "Violet Quarry", Color = Color3.fromRGB(184, 116, 255),
			Reward = { Kind = "Ore", Hp = 10, Ore = "frost", OreMult = 0.4 } },
		{ Id = "SulfurRidge", Name = "Sulfur Ridge", Color = Color3.fromRGB(255, 204, 64),
			Reward = { Kind = "Ore", Hp = 16, Ore = "crystal", OreMult = 0.3 } },
	} :: { Field },
	TravelCooldown = 3, -- seconds between teleports
	Rock = {
		TintMix = 0.4, -- how far a rock's stone colour moves toward its field colour
		Studs = false, -- the cartoon map keeps rocks smooth; true restores the studded skin
		LightRange = 9, -- the soft glow each live rock gives off
		LightBrightness = 0.7,
		SparkleRate = 2, -- ambient sparkles a second per rock
		BurstCount = 14, -- chips thrown when a rock breaks
	},
}
