--!strict
return table.freeze({
	MinShow = 1.5, -- long enough to read the logo, short enough not to feel like a wait
	MaxShow = 20,
	TipSeconds = 3.5,
	AssetTimeout = 5, -- the loading art and HUD icons only; meshes keep loading after the screen closes
	Weights = { engine = .15, assets = .45, state = .25, hud = .15 },
	-- Owner uploads assets/marketing/v2/loading/*.png and supplies Image IDs.
	-- Empty or unavailable images use the built-in sky, title and shape art.
	Background = "rbxassetid://100691423203440", -- craterworks-background-space.png (1376x768)
	Wordmark = "rbxassetid://91648609810870",
	Cloud = "rbxassetid://101223363381824",
	Trail = "rbxassetid://140237715248790",
	-- The space background carries its own glowing meteor in the middle (Showpiece): the live logo sits above it and the
	-- clouds, the flying meteor and the meteor-type strip stay off so the picture is the show.
	-- The older sky background (rbxassetid://132108322743684, craterworks-background-v5-sky.png, 1672x941) had the logo
	-- painted in: set LogoBaked = true for that one and LogoWide = Vector2.new(.21, .15). For a background with a crater,
	-- leave both off and set Crater (where the meteor lands, as a fraction of the image) and LogoWide (logo position).
	BackgroundSize = Vector2.new(1376, 768),
	LogoBaked = false,
	Showpiece = true,
	LogoWide = Vector2.new(.5, .16),
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
