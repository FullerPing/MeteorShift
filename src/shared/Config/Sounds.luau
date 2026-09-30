--!strict
-- Sound effects (Pro Sound Effects library ids, licensed for all experiences, plus a few
-- built-ins). Played through client/Sfx.luau by name. Volume is 0..1; when PitchMin and
-- PitchMax are set, each play picks a random PlaybackSpeed between them. Cooldown is the
-- shortest gap in seconds between two plays of the same name; Max caps how many copies
-- may sound at once (default 4 for 2D sounds, 6 for sounds placed on a part).

export type Entry = {
	Id: string,
	Volume: number,
	PitchMin: number?,
	PitchMax: number?,
	Cooldown: number?,
	Max: number?,
}

local Sounds: { [string]: Entry } = {
	-- Pickaxe hits alternate between the two variants so rapid swings do not repeat exactly
	HitA = { Id = "rbxassetid://9118630399", Volume = 0.35, PitchMin = 0.9, PitchMax = 1.15 },
	HitB = { Id = "rbxassetid://9118609285", Volume = 0.35, PitchMin = 0.9, PitchMax = 1.15 },
	NodeBreak = { Id = "rbxassetid://9118588165", Volume = 0.6, PitchMin = 0.95, PitchMax = 1.1, Cooldown = 0.08 },
	CoreCrack = { Id = "rbxassetid://9118585250", Volume = 0.9 },
	CoreWhoosh = { Id = "rbxassetid://9119377943", Volume = 0.7 },
	CoreChime = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.5, PitchMin = 0.6, PitchMax = 0.6 },
	MeteorImpact = { Id = "rbxassetid://9114221261", Volume = 1 },
	MeteorRumble = { Id = "rbxasset://sounds/Rocket whoosh 01.wav", Volume = 0.2, PitchMin = 0.5, PitchMax = 0.5 },
	Sell = { Id = "rbxassetid://9113728042", Volume = 0.6, Cooldown = 0.3, Max = 2 },
	Purchase = { Id = "rbxassetid://9113728049", Volume = 0.6, Cooldown = 0.3, Max = 2 },
	Click = { Id = "rbxassetid://9119717523", Volume = 0.4, PitchMin = 0.97, PitchMax = 1.05, Cooldown = 0.05 },
}

return Sounds
