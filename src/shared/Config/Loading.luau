--!strict
return table.freeze({
	-- A full white screen with the Meteor Mining Simulator logo over the progress card (owner, 2026-10-20)
	MinShow = 4, -- at least this long, so the logo is seen and the bar fills at a readable pace
	MaxShow = 35, -- the hard cap: a slow device still gets in (SKIP is there from 2 s)
	TipSeconds = 3.5,
	-- The screen waits up to this long for the logo, the HUD icons and the menus' meshes and sounds (PreloadLimit of
	-- them: pets, art, sounds)
	AssetTimeout = 12,
	PreloadLimit = 1500,
	-- ...and up to this long for the world: the character, the map streamed in around it, the client's code started
	-- and the downloads that map queued finished (the map streams, so without this it popped in after the screen)
	WorldTimeout = 25,
	Weights = { engine = .1, assets = .25, world = .35, state = .2, hud = .1 },
	-- assets/loading/logo-meteor-mining-simulator.png (1024x643, transparent); WordmarkAspect is its height / width
	Wordmark = "rbxassetid://114567546796479",
	WordmarkAspect = 643 / 1024,
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
		"Tap SELL on your HUD to turn bars into cash.",
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
