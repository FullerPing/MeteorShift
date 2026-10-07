--!strict
-- Meteor event tuning (spec §5) and meteor types (spec §8.1). Every number here is a
-- starting value for Week 5 balancing.

local Meteor = {}

-- Phase durations, in seconds (spec §5.1)
Meteor.FirstCountdown = 90 -- first meteor after a server starts is ~1.5 minutes away (spec §4)
Meteor.Countdown = 180 -- 3 minutes: a 343 s cycle gives a new player four meteors in the first 19 minutes (docs/economy-rework.md)
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
	Radius = 117,
	Speed = 110,
	Lift = 55,
}

-- Meteor types (spec §8.1): every type is the same event with the ore, the required
-- pickaxe tier, one twist and the multipliers swapped. Shared.MeteorTypes holds the
-- rules (odds, twist math). Everyone mines every type; what a hit yields by player level
-- (Config.Levels, Shared.Levels.oreYield) is what keeps it fair. The Alien boss is not in
-- the weighted schedule: Meteor.Boss brings it in. Seasonal meteors are not built yet.
Meteor.TypeOrder = { "Iron", "Ice", "Crystal" } -- lowest to highest, the weighted schedule

-- The Alien boss meteor: every EveryMeteors-th meteor (about hourly) on a server where someone
-- has at least MinRebirths rebirths (the rebirth 3 unlock). It pays a new, rarer ore.
Meteor.Boss = { Type = "Alien", EveryMeteors = 10, MinRebirths = 3 }

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
	Golden: boolean?, -- a golden variant of a scheduled type (Shared.MeteorTypes.golden)
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
			Color3.fromRGB(184, 118, 84),
			Color3.fromRGB(204, 138, 98),
			Color3.fromRGB(156, 98, 72),
		},
		CrustMaterial = Enum.Material.Plastic,
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
			Color3.fromRGB(150, 214, 255),
			Color3.fromRGB(122, 194, 246),
			Color3.fromRGB(192, 232, 255),
		},
		CrustMaterial = Enum.Material.Plastic,
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
			Color3.fromRGB(158, 108, 204),
			Color3.fromRGB(182, 126, 220),
			Color3.fromRGB(132, 90, 180),
		},
		CrustMaterial = Enum.Material.Plastic,
		OreColor = Color3.fromRGB(255, 122, 214),
		OreMaterial = Enum.Material.Glass,
		CoreColor = Color3.fromRGB(205, 50, 190),
		GlowColor = Color3.fromRGB(255, 86, 232),
	} :: MeteorType,
	Alien = {
		Id = "Alien",
		DisplayName = "Alien Boss Meteor",
		Ore = "alien",
		RequiredTier = 5,
		YieldMult = 1,
		HpMult = 1.5,
		ActiveDuration = 180,
		ShardMult = 3,
		Weight = 0, -- never in the weighted schedule: Meteor.Boss
		Twist = "None",
		CrustColors = {
			Color3.fromRGB(62, 176, 126),
			Color3.fromRGB(86, 204, 148),
			Color3.fromRGB(48, 150, 110),
		},
		CrustMaterial = Enum.Material.Plastic,
		OreColor = Color3.fromRGB(120, 255, 150),
		OreMaterial = Enum.Material.Neon,
		CoreColor = Color3.fromRGB(70, 235, 120),
		GlowColor = Color3.fromRGB(110, 255, 160),
	} :: MeteorType,
} :: { [string]: MeteorType }

-- A cooled meteor: a dull toy grey, dark enough to read as spent against the bright map
Meteor.InertColor = Color3.fromRGB(104, 100, 106)

return Meteor
