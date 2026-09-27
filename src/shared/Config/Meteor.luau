--!strict
-- Meteor event tuning (spec §5). Every number here is a starting value for Week 5 balancing.

local Meteor = {}

-- Phase durations, in seconds (spec §5.1)
Meteor.FirstCountdown = 120 -- first meteor after a server starts is ~2 minutes away (spec §4)
Meteor.Countdown = 240
Meteor.ImpactDuration = 3
Meteor.ActiveDuration = 150 -- cooling timer
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
Meteor.FloorPlayers = 4 -- a meteor is never smaller than this many Basic Pickaxes
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
	Radius = 90,
	Speed = 110,
	Lift = 55,
}

export type MeteorType = {
	Id: string,
	DisplayName: string,
	Ore: string,
	YieldMult: number,
	CrustColors: { Color3 },
	CrustMaterial: Enum.Material,
	OreColor: Color3, -- the ore chunks studding each cluster
	OreMaterial: Enum.Material,
	CoreColor: Color3,
	GlowColor: Color3,
	HpMult: number, -- type HP multiplier (spec §5.3)
	Weight: number,
}

Meteor.Types = {
	Iron = {
		Id = "Iron",
		DisplayName = "Iron Meteor",
		Ore = "iron",
		YieldMult = 1,
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
		HpMult = 1,
		Weight = 1,
	} :: MeteorType,
}

Meteor.InertColor = Color3.fromRGB(58, 56, 56)

return Meteor
