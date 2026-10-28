--!strict
-- The Foreman's quest line (Shared.Quests, QuestService): one long chain of goals, one at a time, that never resets
-- (not even on rebirth). It is the game's "what next" (owner feedback, 2026-10-23: a clear goal to work toward, an NPC
-- with quests like "mine x meteors" and "hatch x eggs"). The current step shows on the HUD tracker; a finished step is
-- claimed in the Quests menu, which opens from the Foreman by the spawn or from the tracker.
-- Each world has its own line with its own save (Shared.Quests.saveKey): Line in World 1, RiftLine in Nebula Rift.
--
-- Kind "event": counts Event from the moment the step starts (Field narrows fieldRock to one field).
--   Events: meteorJoin, coreCrack, crustHit, barsSold, oreDeposited, hatch, fieldRock (DailyService's signals plus
--   DebrisService.RockBroken).
-- Kind "level" / "rebirths" / "pickaxeTier" / "backpackTier" / "petsOwned" / "line": met once the profile value
--   reaches Target, so a step a player already passed is claimable at once.
-- Reward: Shards, plus Minutes of the player's own expected income (Daily's cash rule: Income.grant, capped at
-- CashCeilingShare of the next rebirth's cost).
export type Step = {
	Id: string, Kind: string, Target: number, Title: string, Hint: string, Shards: number, Minutes: number,
	Event: string?, Field: string?,
}

local Quests = {}

Quests.CashFloor = 500
Quests.CashCeilingShare = 0.04

Quests.Line = {
	{ Id = "join3", Kind = "event", Event = "meteorJoin", Target = 3, Title = "Join %d meteors", Hint = "Hit a meteor's crust when one lands in the crater.", Shards = 3, Minutes = 2 },
	{ Id = "sell50", Kind = "event", Event = "barsSold", Target = 50, Title = "Sell %d bars", Hint = "Drop ore in your Refinery hopper, then sell the bars.", Shards = 2, Minutes = 3 },
	{ Id = "level5", Kind = "level", Target = 5, Title = "Reach level %d", Hint = "Meteor hits and the XP Mine give player XP.", Shards = 3, Minutes = 3 },
	{ Id = "rocks20", Kind = "event", Event = "fieldRock", Target = 20, Title = "Break %d ore-field rocks", Hint = "Open the Ore Fields menu and travel to a field.", Shards = 3, Minutes = 4 },
	{ Id = "pick2", Kind = "pickaxeTier", Target = 2, Title = "Get a tier %d pickaxe", Hint = "Max your pickaxe in the Gear menu, then evolve it.", Shards = 4, Minutes = 4 },
	{ Id = "cores2", Kind = "event", Event = "coreCrack", Target = 2, Title = "Help crack %d meteor cores", Hint = "Keep mining after the crust breaks: the core pays shards.", Shards = 5, Minutes = 5 },
	{ Id = "hatch1", Kind = "event", Event = "hatch", Target = 1, Title = "Hatch an egg", Hint = "Spend Core Shards at the Hatchery.", Shards = 5, Minutes = 4 },
	{ Id = "xprocks30", Kind = "event", Event = "fieldRock", Field = "XpMine", Target = 30, Title = "Break %d rocks in the XP Mine", Hint = "The XP Mine sits up the ramp behind the south avenue.", Shards = 5, Minutes = 5 },
	{ Id = "level12", Kind = "level", Target = 12, Title = "Reach level %d", Hint = "Level 12 opens the Violet Quarry.", Shards = 6, Minutes = 6 },
	{ Id = "pack3", Kind = "backpackTier", Target = 3, Title = "Get a tier %d backpack", Hint = "Bigger backpacks mean fewer trips to the hopper.", Shards = 6, Minutes = 6 },
	{ Id = "line3", Kind = "line", Target = 3, Title = "Upgrade your production line to level %d", Hint = "Upgrade it in the Foundry menu.", Shards = 6, Minutes = 6 },
	{ Id = "rebirth1", Kind = "rebirths", Target = 1, Title = "Rebirth", Hint = "Rebirth doubles bar sales and opens Colony Perks.", Shards = 15, Minutes = 8 },
	{ Id = "hatch5", Kind = "event", Event = "hatch", Target = 5, Title = "Hatch %d eggs", Hint = "Shards from cores and quests buy eggs.", Shards = 10, Minutes = 8 },
	{ Id = "level20", Kind = "level", Target = 20, Title = "Reach level %d", Hint = "Level 20 opens Sulfur Ridge.", Shards = 10, Minutes = 8 },
	{ Id = "pets5", Kind = "petsOwned", Target = 5, Title = "Own %d different pets", Hint = "Check the BOOSTS tab in Pets to see what each one adds.", Shards = 12, Minutes = 10 },
	{ Id = "join25", Kind = "event", Event = "meteorJoin", Target = 25, Title = "Join %d meteors", Hint = "Every meteor counts once, from your first hit.", Shards = 12, Minutes = 10 },
	{ Id = "rebirth3", Kind = "rebirths", Target = 3, Title = "Reach rebirth %d", Hint = "Rebirth 3 opens Halo Ledge on the Crown.", Shards = 20, Minutes = 10 },
	{ Id = "level30", Kind = "level", Target = 30, Title = "Reach level %d", Hint = "Level 30 opens Ember Shelf.", Shards = 15, Minutes = 10 },
	{ Id = "pick5", Kind = "pickaxeTier", Target = 5, Title = "Get a tier %d pickaxe", Hint = "Rebirth 3 opens tier 5, which mines Crystal meteors.", Shards = 20, Minutes = 12 },
	{ Id = "rebirth5", Kind = "rebirths", Target = 5, Title = "Reach rebirth %d", Hint = "Colony Perks add up: spend shards on them too.", Shards = 25, Minutes = 12 },
	{ Id = "level40", Kind = "level", Target = 40, Title = "Reach level %d", Hint = "Level 40 opens the Glass Scar.", Shards = 25, Minutes = 12 },
	{ Id = "rebirth10", Kind = "rebirths", Target = 10, Title = "Reach rebirth %d", Hint = "Rebirth 10 opens the road to World 2.", Shards = 50, Minutes = 15 },
} :: { Step }

-- Nebula Rift's Foreman (World 2, from rebirth 25): its fields, its egg and the late gear tiers. Rewards are bigger in
-- shards (the Nebula Egg costs 500) and in minutes of the Rift's own income.
Quests.RiftLine = {
	{ Id = "rift_join3", Kind = "event", Event = "meteorJoin", Target = 3, Title = "Join %d Rift meteors", Hint = "Nebula, Solar and Eclipse meteors land in the Rift crater.", Shards = 20, Minutes = 5 },
	{ Id = "rift_comet30", Kind = "event", Event = "fieldRock", Field = "CometDrift", Target = 30, Title = "Break %d rocks in Comet Drift", Hint = "Comet Drift is the west field: press TELEPORT.", Shards = 20, Minutes = 5 },
	{ Id = "rift_sell200", Kind = "event", Event = "barsSold", Target = 200, Title = "Sell %d Rift bars", Hint = "Rift ores sell for 3x at the Refinery.", Shards = 25, Minutes = 6 },
	{ Id = "rift_pick13", Kind = "pickaxeTier", Target = 13, Title = "Get a tier %d pickaxe", Hint = "Rebirth 25 opens the Dark Matter Pick in the Gear menu.", Shards = 30, Minutes = 8 },
	{ Id = "rift_cores5", Kind = "event", Event = "coreCrack", Target = 5, Title = "Help crack %d Rift cores", Hint = "Eclipse cores pay twice the shards.", Shards = 30, Minutes = 8 },
	{ Id = "rift_rebirth27", Kind = "rebirths", Target = 27, Title = "Reach rebirth %d", Hint = "Rebirth 27 opens Starlight Shelf.", Shards = 40, Minutes = 10 },
	{ Id = "rift_starlight40", Kind = "event", Event = "fieldRock", Field = "StarlightShelf", Target = 40, Title = "Break %d rocks on Starlight Shelf", Hint = "Starlight Shelf is the east field; its rocks drop Solarite.", Shards = 40, Minutes = 10 },
	{ Id = "rift_hatch3", Kind = "event", Event = "hatch", Target = 3, Title = "Hatch %d Nebula Eggs", Hint = "The Nebula Egg is by the plaza: every Epic and Legendary.", Shards = 50, Minutes = 10 },
	{ Id = "rift_pick14", Kind = "pickaxeTier", Target = 14, Title = "Get a tier %d pickaxe", Hint = "Rebirth 28 opens the Event Horizon Pick.", Shards = 50, Minutes = 12 },
	{ Id = "rift_rebirth30", Kind = "rebirths", Target = 30, Title = "Reach rebirth %d", Hint = "Rebirth 30 opens Event Horizon, the north field.", Shards = 60, Minutes = 12 },
	{ Id = "rift_horizon50", Kind = "event", Event = "fieldRock", Field = "EventHorizon", Target = 50, Title = "Break %d rocks in Event Horizon", Hint = "Event Horizon's rocks drop Eclipse ore.", Shards = 60, Minutes = 15 },
	{ Id = "rift_join50", Kind = "event", Event = "meteorJoin", Target = 50, Title = "Join %d Rift meteors", Hint = "Every meteor counts once, from your first hit.", Shards = 75, Minutes = 15 },
	{ Id = "rift_rebirth34", Kind = "rebirths", Target = 34, Title = "Reach rebirth %d", Hint = "Rebirth 34 opens the last gear tier, the Big Bang Pick.", Shards = 100, Minutes = 15 },
} :: { Step }

-- the line each world's Foreman gives (Config.Worlds ids)
Quests.Lines = { Quests.Line, Quests.RiftLine }

for _, line in Quests.Lines do
	for _, step in line do
		step.Title = string.format(step.Title, step.Target)
	end
end

return Quests
