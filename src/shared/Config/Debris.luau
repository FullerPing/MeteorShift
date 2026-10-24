--!strict
-- Debris rocks between meteors (spec §5.7). The rocks themselves are placed in
-- Workspace.Map.Debris in Studio; this only tunes their behaviour.

-- What a field's rocks pay. "Cash" pays `Seconds` of the breaker's expected income, scaled by their swing against the
-- Basic Pickaxe's (a faster pickaxe breaks rocks sooner, so each pays for the time it took; Shared.Income, kept
-- between CashFloor and CeilingShare of the next rebirth's cost). "Ore" drops `Ore` into the hopper at
-- `OreMult` of a full hit, scaled by the player's level like a meteor's ore. `Hp` is the hits to break.
export type Reward = {
	Kind: string, -- "Cash", "Ore" or "Xp"
	Hp: number,
	Seconds: number?, -- cash: seconds of income a rock pays (Cash rocks, and XP rocks that pay a little cash too)
	CashFloor: number?,
	CeilingShare: number?,
	Ore: string?,
	OreMult: number?,
	XpPerHit: number?, -- an "Xp" rock pays Hp x XpPerHit player XP (a meteor crust hit is 0.25)
}
-- What opens a field (Shared.FieldGate): a player level, or a number of rebirths. No Unlock means always open.
export type Unlock = { Level: number?, Rebirths: number? }
export type Field = { Id: string, Name: string, Color: Color3, Reward: Reward, Unlock: Unlock? }

return {
	Hp = 4, -- hits to break for the player a rock is sized for (HP is 4 × that pickaxe's Mining Power); the default for rocks outside a field
	RerollInterval = 60, -- untouched rocks re-pick who they are sized for this often
	RespawnMin = 30,
	RespawnMax = 60,
	-- A full server shares the same rocks: past RespawnCrowd players the wait shrinks in proportion
	-- (6 players = half, 12 = a quarter), never below RespawnFloor seconds (DebrisField.respawnSeconds).
	RespawnCrowd = 3,
	RespawnFloor = 6,
	Ore = "iron",
	YieldFraction = 0.25, -- ore per hit relative to a meteor node

	-- The eight ore fields (Workspace.Map.DebrisFields.<Id>), one rung of the map's height ladder each: the travel
	-- list, each field's colour, what its rocks pay and what opens it. A rock's field is its `Field` attribute.
	-- Rust Works and Frost Yard (the town tier) pay cash; Violet Quarry and Sulfur Ridge (T1) pay better ore than
	-- the meteors' iron filler; Ember Shelf and Glass Scar (T2) pay big cash and alien ore; Starfall and Halo Ledge
	-- on the Crown open by rebirth. Ore stays well under the same ore from a meteor node (a meteor hit is worth a
	-- full OrePerHit), so the fields never replace the meteors. Gates open only through play.
	-- The line refines any ore into a bar at the same speed, so what an ore field is worth is its ore's bar price, not
	-- its ore per hit: at 0.4/0.3/0.4/0.6 Halo Ledge's Alien ore (1,800 a bar) filled the line at about 13x the meteors'
	-- income. Owner, 2026-10-22: a field should be a little better than the meteors, about 1.5x. OreMult is set so each
	-- ore field mined nonstop pays about 1.2 to 1.7x the player's expected income (Violet tops out where it fills the
	-- line), and the cash fields' Seconds the same (Rust Works' quick rocks a little less; tests/DebrisField.spec keeps
	-- every field under 2x). A Halo rock still drops a few Alien ore, not a backpack of it.
	Fields = {
		{ Id = "RustWorks", Name = "Rust Works", Color = Color3.fromRGB(255, 124, 56),
			Reward = { Kind = "Cash", Hp = 4, Seconds = 6.8, CashFloor = 20, CeilingShare = 0.006 } },
		{ Id = "FrostYard", Name = "Frost Yard", Color = Color3.fromRGB(110, 212, 255),
			Reward = { Kind = "Cash", Hp = 10, Seconds = 17.5, CashFloor = 60, CeilingShare = 0.02 }, Unlock = { Level = 5 } },
		-- The XP Mine on the south of T2: its rocks pay player XP (Hp x XpPerHit, about 20 XP a minute of steady
		-- mining against ~35 hitting a meteor), open to everyone, so the countdown always moves your level along.
		-- They also pay some cash (owner, 2026-10-24): 4 s of income per 12-hit rock, about a fifth of Rust Works' rate
		{ Id = "XpMine", Name = "XP Mine", Color = Color3.fromRGB(122, 140, 255),
			Reward = { Kind = "Xp", Hp = 12, XpPerHit = 0.2, Seconds = 4, CashFloor = 20, CeilingShare = 0.006 } },
		{ Id = "VioletQuarry", Name = "Violet Quarry", Color = Color3.fromRGB(184, 116, 255),
			Reward = { Kind = "Ore", Hp = 10, Ore = "frost", OreMult = 0.48 }, Unlock = { Level = 12 } },
		{ Id = "SulfurRidge", Name = "Sulfur Ridge", Color = Color3.fromRGB(255, 204, 64),
			Reward = { Kind = "Ore", Hp = 16, Ore = "crystal", OreMult = 0.17 }, Unlock = { Level = 20 } },
		{ Id = "EmberShelf", Name = "Ember Shelf", Color = Color3.fromRGB(255, 106, 78),
			Reward = { Kind = "Cash", Hp = 20, Seconds = 30, CashFloor = 120, CeilingShare = 0.04 }, Unlock = { Level = 30 } },
		{ Id = "GlassScar", Name = "Glass Scar", Color = Color3.fromRGB(111, 240, 224),
			Reward = { Kind = "Ore", Hp = 24, Ore = "alien", OreMult = 0.042 }, Unlock = { Level = 40 } },
		{ Id = "Starfall", Name = "Starfall", Color = Color3.fromRGB(255, 143, 200),
			Reward = { Kind = "Cash", Hp = 28, Seconds = 40, CashFloor = 400, CeilingShare = 0.06 }, Unlock = { Rebirths = 1 } },
		{ Id = "HaloLedge", Name = "Halo Ledge", Color = Color3.fromRGB(255, 213, 74),
			Reward = { Kind = "Ore", Hp = 32, Ore = "alien", OreMult = 0.045 }, Unlock = { Rebirths = 3 } },
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
