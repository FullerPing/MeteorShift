--!strict
return table.freeze({
	MinShow = 1.5, -- long enough to read the logo, short enough not to feel like a wait
	MaxShow = 20,
	TipSeconds = 3.5,
	AssetTimeout = 5, -- the loading art and HUD icons only; meshes keep loading after the screen closes
	Weights = { engine = .15, assets = .45, state = .25, hud = .15 },
	-- Owner uploads assets/marketing/v2/loading/*.png and supplies Image IDs.
	-- Empty or unavailable images use the built-in sky, title and shape art.
	Background = "rbxassetid://132108322743684",
	Wordmark = "rbxassetid://91648609810870",
	Cloud = "rbxassetid://101223363381824",
	Trail = "rbxassetid://140237715248790",
	-- The sky background is 1672x941 (craterworks-background-v5-sky.png) with the logo painted in, so the live logo and
	-- clouds are hidden (LogoBaked) and the meteor crosses the whole screen instead of landing. For a background with a crater,
	-- drop LogoBaked and set Crater (where the meteor lands, as a fraction of the image) and LogoWide (logo position).
	BackgroundSize = Vector2.new(1672, 941),
	LogoBaked = true,
	LogoWide = Vector2.new(.21, .15),
	Preload = {},
	StatusThresholds = {
		{ Percent = 0, Text = "Waking up the crater..." },
		{ Percent = 15, Text = "Polishing the pickaxes..." },
		{ Percent = 55, Text = "Counting your ore..." },
		{ Percent = 85, Text = "Firing up the foundry..." },
		{ Percent = 100, Text = "Ready!" },
	},
	Tips = {
		"Mine the glowing rocks between meteors.",
		"A meteor lands every few minutes. Run to the crater!",
		"Hit the core together to earn Core Shards.",
		"Deposit ore at the Foundry, then claim your bars.",
		"Sell bars at the Trading Post for cash.",
		"Hold SPRINT to run faster.",
		"Tap ORE to teleport to an ore field.",
		"Hatch eggs with Core Shards you earn by playing.",
		"Pets level up while you mine.",
		"Evolve your pickaxe at the Gear Hall.",
		"Rebirth to multiply your cash and unlock more pet slots.",
		"Ice meteors refreeze, so keep hitting them!",
		"Crystal meteors get stronger when friends join in.",
		"Bigger backpacks mean longer mining trips.",
	},
})
