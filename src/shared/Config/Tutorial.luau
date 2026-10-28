--!strict
-- First-session tutorial (spec §11): show, don't tell. Each step is a short verb and
-- an icon on the card; the world does the explaining (a glowing trail to the target,
-- an outline on it and a tapping hand or bouncing arrow over it, a pointing hand on
-- HUD buttons). Skippable, and every step completes on the real action. Doing a later
-- step's action first counts the steps before it too, so nobody gets stuck behind a
-- meteor they missed.

-- Action: "tap" = hit the target (tapping hand), "go" = walk to it (arrow),
-- "watch" = look at it (arrow, timer), "ui" = press a HUD button (pointing hand on it).
export type Step = {
	Id: string,
	Text: string,
	Sub: string?, -- small line under the verb (the card's orange line); a waiting meteor step shows the countdown instead
	Icon: string, -- a Config.HudIcons key, drawn on the card
	Action: "tap" | "go" | "watch" | "ui",
	Button: string?, -- the HUD button a "ui" step points at (a descendant name under PlayerGui)
}

local Tutorial = {}

Tutorial.Steps = {
	{ Id = "mine_debris", Text = "MINE!", Icon = "ore", Action = "tap" },
	-- A quick win while the first meteor is on its way: the rocks' cash buys a pickaxe level. Never a wait: the meteor
	-- landing completes it too (TutorialService), so nobody sits on an empty step.
	{ Id = "first_upgrade", Text = "UPGRADE!", Sub = "Tap GEAR to power up your pickaxe", Icon = "equipment", Action = "ui", Button = "ShopButton" },
	{ Id = "reach_crater", Text = "RUN!", Sub = "Follow the trail to the crater", Icon = "meteor", Action = "go" },
	{ Id = "mine_node", Text = "MINE IT!", Sub = "Break nodes to open the core", Icon = "ore", Action = "tap" },
	{ Id = "hit_core", Text = "HIT THE CORE!", Sub = "Keep hitting until it cracks", Icon = "meteorCrystal", Action = "tap" },
	{ Id = "core_shards", Text = "CRACK IT!", Icon = "crystal", Action = "tap" },
	{ Id = "deposit", Text = "SMELT!", Icon = "foundry", Action = "go" },
	{ Id = "collect_bar", Text = "GET BARS!", Icon = "bars", Action = "go" },
	{ Id = "sell", Text = "SELL!", Icon = "coin", Action = "ui", Button = "SellBars" },
	-- Points at the HUD Gear button: the gear shop only opens from there
	{ Id = "buy", Text = "UPGRADE!", Sub = "Tap GEAR - it works from anywhere", Icon = "equipment", Action = "ui", Button = "ShopButton" },
} :: { Step }

-- The ore field a new player starts in and is pointed at for "MINE!": Rust Works has the softest rocks (Config.Debris).
-- A player who still has that step to do spawns there (TutorialService), not on the town plaza, whose nearest fields
-- (Sulfur Ridge, Violet Quarry) are the hardest ones.
Tutorial.StarterField = "RustWorks"

-- Standing this close (horizontally) to the crater centre during an event counts as "reached"
Tutorial.CraterRadius = 83.2
-- A player who skips the tutorial and is still playing this many seconds later counts as having passed every
-- funnel step left (TutorialService logs them then); one who leaves sooner doesn't
Tutorial.SkipCreditSeconds = 300

return Tutorial
