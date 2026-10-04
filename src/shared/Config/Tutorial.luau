--!strict
-- First-session tutorial (spec §11): arrow-guided, skippable, and every step
-- completes on the real action. Doing a later step's action first counts the
-- steps before it too, so nobody gets stuck behind a meteor they missed.

export type Step = {
	Id: string,
	Text: string,
	Hint: string,
}

local Tutorial = {}

Tutorial.Steps = {
	{ Id = "mine_debris", Text = "Mine a debris rock", Hint = "Hold click (or tap) on a rock near you." },
	{ Id = "meteor_lands", Text = "Watch the meteor land", Hint = "It hits the crater when the timer runs out." },
	{ Id = "reach_crater", Text = "Run to the crater", Hint = "Everyone rushes in. Mine it before it cools!" },
	{ Id = "mine_node", Text = "Mine a crust node", Hint = "Ore from every hit goes straight to your backpack." },
	{ Id = "hit_core", Text = "Hit the core", Hint = "It glows once enough crust is broken." },
	{ Id = "core_shards", Text = "Collect your shards", Hint = "Keep hitting the core until it cracks." },
	{ Id = "deposit", Text = "Deposit your ore", Hint = "Use the refinery in town (or the DROP ORE pad at your plot)." },
	{ Id = "collect_bar", Text = "Collect a bar", Hint = "Your refinery makes bars. Use it again to collect them." },
	{ Id = "sell", Text = "Sell bars", Hint = "Tap your bars at the bottom of the screen, then SELL ALL." },
	{ Id = "buy", Text = "Buy an upgrade", Hint = "Open the SHOP and level up your pickaxe or backpack." },
} :: { Step }

-- Standing this close (horizontally) to the crater centre during an event counts as "reached"
Tutorial.CraterRadius = 80

return Tutorial
