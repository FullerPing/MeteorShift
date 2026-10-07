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

Perks.Order = { "headStart", "stationMemory", "efficientLine", "offlineTraining", "petBond" }

Perks.List = {
	headStart = {
		Id = "headStart",
		Name = "Head Start",
		Text = "After a rebirth you start with your pickaxe and backpack %s tier(s) up (never past what your level allows).",
		Costs = { 40, 80, 160, 320 },
		Effect = { 1, 2, 3, 4 },
	},
	stationMemory = {
		Id = "stationMemory",
		Name = "Station Memory",
		Text = "A rebirth keeps %s of your hopper, conveyor and collection post levels.",
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
} :: { [string]: Perk }

return Perks
