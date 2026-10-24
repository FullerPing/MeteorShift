--!strict
-- The Foreman's quest line (Shared.Quests, QuestService): one long chain of goals, one at a time, that never resets
-- (not even on rebirth). It is the game's "what next" (owner feedback, 2026-10-23: a clear goal to work toward, an NPC
-- with quests like "mine x meteors" and "hatch x eggs"). The current step shows on the HUD tracker; a finished step is
-- claimed in the Quests menu, which opens from the Foreman by the spawn or from the tracker.
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
	{ Id = "line5", Kind = "line", Target = 5, Title = "Upgrade your production line to level %d", Hint = "Upgrade it in the Foundry menu.", Shards = 6, Minutes = 6 },
	{ Id = "rebirth1", Kind = "rebirths", Target = 1, Title = "Rebirth", Hint = "Rebirth doubles bar sales and opens Colony Perks.", Shards = 15, Minutes = 8 },
	{ Id = "hatch5", Kind = "event", Event = "hatch", Target = 5, Title = "Hatch %d eggs", Hint = "Shards from cores and quests buy eggs.", Shards = 10, Minutes = 8 },
	{ Id = "level20", Kind = "level", Target = 20, Title = "Reach level %d", Hint = "Level 20 opens Sulfur Ridge.", Shards = 10, Minutes = 8 },
	{ Id = "pets5", Kind = "petsOwned", Target = 5, Title = "Own %d different pets", Hint = "Check the BOOSTS tab in Pets to see what each one adds.", Shards = 12, Minutes = 10 },
	{ Id = "join25", Kind = "event", Event = "meteorJoin", Target = 25, Title = "Join %d meteors", Hint = "Every meteor counts once, from your first hit.", Shards = 12, Minutes = 10 },
	{ Id = "rebirth3", Kind = "rebirths", Target = 3, Title = "Reach rebirth %d", Hint = "Rebirth 3 opens Halo Ledge on the Crown.", Shards = 20, Minutes = 10 },
	{ Id = "level30", Kind = "level", Target = 30, Title = "Reach level %d", Hint = "Level 30 opens Ember Shelf.", Shards = 15, Minutes = 10 },
	{ Id = "pick8", Kind = "pickaxeTier", Target = 8, Title = "Get a tier %d pickaxe", Hint = "Higher tiers open with rebirths.", Shards = 20, Minutes = 12 },
	{ Id = "rebirth5", Kind = "rebirths", Target = 5, Title = "Reach rebirth %d", Hint = "Colony Perks add up: spend shards on them too.", Shards = 25, Minutes = 12 },
	{ Id = "level40", Kind = "level", Target = 40, Title = "Reach level %d", Hint = "Level 40 opens the Glass Scar.", Shards = 25, Minutes = 12 },
	{ Id = "rebirth10", Kind = "rebirths", Target = 10, Title = "Reach rebirth %d", Hint = "Rebirth 10 opens the road to World 2.", Shards = 50, Minutes = 15 },
} :: { Step }

for _, step in Quests.Line do
	step.Title = string.format(step.Title, step.Target)
end

return Quests
