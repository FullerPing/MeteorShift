--!strict
-- Colony Perks (economy rework, S1): the permanent things Core Shards buy besides pets. Each is
-- bought once per level and kept through every rebirth. None of them touches mineral or egg odds.
-- Shared.Perks holds the rules, PerkService the purchases. Unlocked by rebirth 1.

local Perks = {}

export type Perk = {
	Id: string,
	Name: string,
	Text: string, -- shown in the panel; %s is filled with the effect at the next level
	Costs: { number }, -- shards for level 1, 2, ... (its length is the max level)
	Effect: { number }, -- the effect at level 1, 2, ...
}

Perks.UnlockRebirths = 1

Perks.Order = { "headStart", "stationMemory", "efficientLine", "offlineTraining", "petBond", "critChance", "critPower", "fieldExpert", "shardSense" }

Perks.List = {
	headStart = {
		Id = "headStart",
		Name = "Head Start",
		-- Starting cash after a rebirth, as a percent of the next rebirth's cost. (It used to floor the gear tiers,
		-- but tiers survive a rebirth anyway, so it almost never did anything.)
		Text = "After a rebirth you start with %s%% of the next rebirth's cost in cash.",
		Costs = { 40, 80, 160, 320 },
		Effect = { 3, 6, 10, 15 },
	},
	stationMemory = {
		Id = "stationMemory",
		Name = "Station Memory",
		Text = "A rebirth keeps %s of your production line level.",
		Costs = { 30, 60, 120, 240 },
		Effect = { 0.25, 0.5, 0.75, 1 },
	},
	efficientLine = {
		Id = "efficientLine",
		Name = "Efficient Line",
		Text = "Your production line runs %s faster.",
		Costs = { 25, 35, 49, 69, 96 },
		Effect = { 0.04, 0.08, 0.12, 0.16, 0.20 },
	},
	offlineTraining = {
		Id = "offlineTraining",
		Name = "Offline Training",
		Text = "Your plot keeps working %s minutes longer while you're away.",
		Costs = { 50, 100, 200 },
		Effect = { 40, 80, 120 },
	},
	petBond = {
		Id = "petBond",
		Name = "Pet Bond",
		Text = "%s more pet slot(s).",
		Costs = { 100, 250 },
		Effect = { 1, 2 },
	},
	-- Mining perks (owner feedback, 2026-10-23: more perks, e.g. crit chance and damage). Crits land extra Mining
	-- Power on meteors, and meteor sizing counts them (MiningPower.playerRate), so they speed you up, not the lobby.
	critChance = {
		Id = "critChance",
		Name = "Lucky Strike",
		Text = "Adds %s to your pickaxe's critical-hit chance.",
		Costs = { 40, 80, 140, 220, 320 },
		Effect = { 0.01, 0.02, 0.03, 0.04, 0.05 },
	},
	critPower = {
		Id = "critPower",
		Name = "Heavy Hitter",
		Text = "Critical hits deal %s more damage.",
		Costs = { 60, 120, 200, 300 },
		Effect = { 0.25, 0.5, 0.75, 1 },
	},
	fieldExpert = {
		Id = "fieldExpert",
		Name = "Field Expert",
		Text = "Ore-field rocks pay %s more cash and XP.",
		Costs = { 50, 100, 180, 280 },
		Effect = { 0.1, 0.2, 0.3, 0.4 },
	},
	shardSense = {
		Id = "shardSense",
		Name = "Shard Sense",
		Text = "Meteor cores give you %s more Core Shards.",
		Costs = { 80, 160, 280, 420 },
		Effect = { 0.05, 0.1, 0.15, 0.2 },
	},
} :: { [string]: Perk }

return Perks
