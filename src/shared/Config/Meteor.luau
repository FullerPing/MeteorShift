--!strict
-- Meteor event tuning (spec §5) and meteor types (spec §8.1). Every number here is a
-- starting value for Week 5 balancing.

local Meteor = {}

-- Phase durations, in seconds (spec §5.1)
Meteor.FirstCountdown = 120 -- first meteor after a server starts is ~2 minutes away (spec §4)
Meteor.Countdown = 240
Meteor.ImpactDuration = 3
-- The cooling timer (Active) is per type: Meteor.Types[id].ActiveDuration
Meteor.CrackedDuration = 5
Meteor.CooledDuration = 5
Meteor.CleanupDuration = 5
Meteor.StreakLeadTime = 10 -- streak is visible for the last N seconds of the countdown

-- Shorter countdown while playtesting in Studio. Set to nil to use the real timings.
Meteor.StudioCountdown = 25 :: number?

-- HP sizing at impact, in Mining Power (spec §5.3, see Shared.MiningPower)
Meteor.PowerGrowth = 1.25 -- Mining Power per pickaxe tier: tier 1 = 1.0, tier 4 ≈ 2.0, tier 8 ≈ 4.8
Meteor.CrustSeconds = 70
Meteor.CoreSeconds = 45
Meteor.CoreUnlockFraction = 0.6
Meteor.ActiveWindow = 120 -- players with no input for this long don't count toward HP
Meteor.FloorPlayers = 1 -- a meteor is never smaller than this many Basic Pickaxes (HP scales with power, so the event lasts the same for any lobby size; a floor above the real player count made 1-3 players unable to crack it)
Meteor.RescaleThreshold = 0.15 -- rescale remaining HP when server power drifts more than this
Meteor.RescaleCooldown = 10 -- at most one rescale per this many seconds
Meteor.RescaleCheckInterval = 1

-- Contribution and rewards (spec §5.5, §5.6)
Meteor.CoreContributionMult = 2
Meteor.ShardFloor = 5
Meteor.ShardBonusPerHitter = 8
Meteor.TopBonus = { 10, 6, 3 }

-- Mining validation (spec §12.2)
Meteor.MineRange = 12
Meteor.SwingTolerance = 0.8 -- accept swings up to 20% faster than the pickaxe allows (latency jitter)
Meteor.HpFlushInterval = 0.1 -- node HP replication rate (10 Hz)
Meteor.StandingInterval = 1 -- how often clients get their rank and the top three

-- Shockwave: knockback only, no damage (spec §5.1)
Meteor.Knockback = {
	Radius = 180,
	Speed = 110,
	Lift = 55,
}

-- Meteor types (spec §8.1): every type is the same event with the ore, the required
-- pickaxe tier, one twist and the multipliers swapped. Shared.MeteorTypes holds the
-- rules (odds, twist math). Everyone mines every type; the refinery's clearance
-- by player level (Config.Levels) is what keeps it fair. Alien Boss and Seasonal
-- meteors are not built yet.
Meteor.TypeOrder = { "Iron", "Ice", "Crystal" } -- lowest to highest

Meteor.Twists = {
	-- Ice: a node nobody has hit for IdleSeconds regains RegenPerSecond of its max HP per second.
	-- The server applies the regen every Tick seconds.
	Refreeze = { IdleSeconds = 5, RegenPerSecond = 0.02, Tick = 0.5 },
	-- Crystal: each extra player on the same node adds BonusPerExtra Mining Power to everyone
	-- on it, up to MaxBonus. A hitter counts as "on" a node for Window seconds after a hit.
	Resonance = { Window = 1.5, BonusPerExtra = 0.2, MaxBonus = 0.6 },
}

export type Twist = "None" | "Refreeze" | "Resonance"

export type MeteorType = {
	Id: string,
	DisplayName: string,
	Ore: string,
	RequiredTier: number, -- pickaxe tier that mines this ore (spec §8.1)
	YieldMult: number,
	HpMult: number, -- type HP multiplier (spec §5.3)
	ActiveDuration: number, -- cooling timer, seconds
	ShardMult: number, -- shard bonus pool multiplier (spec §5.6)
	Weight: number, -- schedule odds, before the eligibility check
	Twist: Twist,
	CrustColors: { Color3 },
	CrustMaterial: Enum.Material,
	OreColor: Color3, -- the ore chunks studding each cluster
	OreMaterial: Enum.Material,
	CoreColor: Color3,
	GlowColor: Color3,
}

Meteor.Types = {
	Iron = {
		Id = "Iron",
		DisplayName = "Iron Meteor",
		Ore = "iron",
		RequiredTier = 1,
		YieldMult = 1,
		HpMult = 1,
		ActiveDuration = 150,
		ShardMult = 1,
		Weight = 60,
		Twist = "None",
		CrustColors = {
			Color3.fromRGB(86, 78, 74),
			Color3.fromRGB(104, 92, 84),
			Color3.fromRGB(70, 64, 62),
		},
		CrustMaterial = Enum.Material.Basalt,
		OreColor = Color3.fromRGB(196, 170, 150),
		OreMaterial = Enum.Material.Metal,
		CoreColor = Color3.fromRGB(215, 78, 24),
		GlowColor = Color3.fromRGB(255, 150, 60),
	} :: MeteorType,
	Ice = {
		Id = "Ice",
		DisplayName = "Ice Meteor",
		Ore = "frost",
		RequiredTier = 3,
		YieldMult = 1,
		HpMult = 1.1,
		ActiveDuration = 150,
		ShardMult = 1.5,
		Weight = 25,
		Twist = "Refreeze",
		CrustColors = {
			Color3.fromRGB(176, 208, 232),
			Color3.fromRGB(150, 188, 220),
			Color3.fromRGB(200, 226, 244),
		},
		CrustMaterial = Enum.Material.Glacier,
		OreColor = Color3.fromRGB(96, 226, 255),
		OreMaterial = Enum.Material.Ice,
		CoreColor = Color3.fromRGB(40, 160, 235),
		GlowColor = Color3.fromRGB(120, 236, 255),
	} :: MeteorType,
	Crystal = {
		Id = "Crystal",
		DisplayName = "Crystal Meteor",
		Ore = "crystal",
		RequiredTier = 5,
		YieldMult = 1,
		HpMult = 1.2,
		ActiveDuration = 150,
		ShardMult = 2,
		Weight = 15,
		Twist = "Resonance",
		CrustColors = {
			Color3.fromRGB(116, 78, 138),
			Color3.fromRGB(138, 88, 150),
			Color3.fromRGB(98, 64, 118),
		},
		CrustMaterial = Enum.Material.Rock,
		OreColor = Color3.fromRGB(255, 122, 214),
		OreMaterial = Enum.Material.Glass,
		CoreColor = Color3.fromRGB(205, 50, 190),
		GlowColor = Color3.fromRGB(255, 86, 232),
	} :: MeteorType,
} :: { [string]: MeteorType }

Meteor.InertColor = Color3.fromRGB(58, 56, 56)

return Meteor
