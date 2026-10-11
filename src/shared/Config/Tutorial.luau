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
	Icon: string,
	Action: "tap" | "go" | "watch" | "ui",
	Button: string?, -- the HUD button a "ui" step points at (a descendant name under PlayerGui)
}

local Tutorial = {}

Tutorial.Steps = {
	{ Id = "mine_debris", Text = "MINE!", Icon = "⛏️", Action = "tap" },
	{ Id = "meteor_lands", Text = "WATCH!", Icon = "☄️", Action = "watch" },
	{ Id = "reach_crater", Text = "RUN!", Icon = "🏃", Action = "go" },
	{ Id = "mine_node", Text = "MINE IT!", Sub = "Break nodes to open the core", Icon = "⛏️", Action = "tap" },
	{ Id = "hit_core", Text = "HIT THE CORE!", Sub = "Keep hitting until it cracks", Icon = "💥", Action = "tap" },
	{ Id = "core_shards", Text = "CRACK IT!", Icon = "💎", Action = "tap" },
	{ Id = "deposit", Text = "SMELT!", Icon = "🔥", Action = "go" },
	{ Id = "collect_bar", Text = "GET BARS!", Icon = "🧱", Action = "go" },
	{ Id = "sell", Text = "SELL!", Icon = "💰", Action = "ui", Button = "SellBars" },
	{ Id = "buy", Text = "UPGRADE!", Icon = "⬆️", Action = "go" },
} :: { Step }

-- Standing this close (horizontally) to the crater centre during an event counts as "reached"
Tutorial.CraterRadius = 83.2

return Tutorial
