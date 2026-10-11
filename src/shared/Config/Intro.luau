--!strict
-- The "How to play" intro shown once to a brand-new player before the hands-on
-- tutorial: a few swipeable pages, one idea each. Copy only; Shared/Intro decides
-- who sees it and IntroController draws it.

export type Page = {
	Icon: string, -- emoji glyph, drawn big
	Title: string,
	Body: string,
}

local Intro = {}

Intro.Pages = {
	{ Icon = "☄️", Title = "WELCOME, MINER!", Body = "Meteors crash into the crater. Break them open, smelt the ore and get rich." },
	{ Icon = "⛏️", Title = "MINE THE METEOR", Body = "Break the nodes to uncover the core, then crack it for shards. Bigger meteors drop rarer ore." },
	{ Icon = "🔥", Title = "SMELT AND SELL", Body = "Drop ore in the foundry, collect the bars and sell them for cash." },
	{ Icon = "⬆️", Title = "UPGRADE", Body = "Buy a better pickaxe and backpack, hatch pets, then rebirth for permanent bonuses." },
	{ Icon = "🚀", Title = "READY?", Body = "Your first meteor is on its way. We'll show you the rest as you go!" },
} :: { Page }

return Intro
