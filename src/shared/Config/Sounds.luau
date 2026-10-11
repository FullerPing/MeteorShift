--!strict
-- Sound effects, played through client/Sfx.luau by name. Every id is licensed for all
-- experiences: Pro Sound Effects and APM uploads by Roblox's library accounts, Roblox's own
-- UI kit, or a few built-ins (sources in docs/audio.md). Volume is 0..1; when PitchMin and
-- PitchMax are set, each play picks a random PlaybackSpeed between them. Cooldown is the
-- shortest gap in seconds between two plays of the same name; Max caps how many copies may
-- sound at once (default 4 for 2D sounds, 6 for sounds placed on a part). Group is the
-- SoundGroup it plays through (SFX by default; UI for interface sounds), so the Settings
-- switches can mute it. Variants rotate in turn so repeated sounds do not repeat exactly.
-- Duck lowers the music for that many seconds (stingers and fanfares).

export type Entry = {
	Id: string,
	Volume: number,
	PitchMin: number?,
	PitchMax: number?,
	Cooldown: number?,
	Max: number?,
	Group: ("SFX" | "UI")?,
	Variants: { string }?,
	Duck: number?,
}

local Sounds: { [string]: Entry } = {
	-- Pickaxe hits alternate between the two variants so rapid swings do not repeat exactly
	HitA = { Id = "rbxassetid://9118630399", Volume = 0.3, PitchMin = 0.9, PitchMax = 1.15 },
	HitB = { Id = "rbxassetid://9118609285", Volume = 0.3, PitchMin = 0.9, PitchMax = 1.15 },
	Swing = { Id = "rbxassetid://9120972321", Variants = { "rbxassetid://9120972321", "rbxassetid://9126229255" }, Volume = 0.16, PitchMin = 1.1, PitchMax = 1.35, Cooldown = 0.08 },
	CritHit = { Id = "rbxassetid://9113133597", Volume = 0.4, PitchMin = 1.1, PitchMax = 1.3, Cooldown = 0.08 },
	CritSparkle = { Id = "rbxassetid://9126073001", Volume = 0.22, PitchMin = 1.2, PitchMax = 1.45, Cooldown = 0.08 },
	NodeBreak = { Id = "rbxassetid://9118588165", Volume = 0.5, PitchMin = 0.95, PitchMax = 1.1, Cooldown = 0.08 },
	-- Ore landing in the backpack: a cute pop whose pitch climbs with a quick streak (Sfx.play's pitch)
	OrePickup = { Id = "rbxassetid://15675055424", Volume = 0.22, Cooldown = 0.05, Max = 3 },
	BackpackFull = { Id = "rbxassetid://15675062723", Volume = 0.5, Cooldown = 2 },

	-- Meteor
	CoreCrack = { Id = "rbxassetid://9118585250", Volume = 0.7 },
	CoreWhoosh = { Id = "rbxassetid://9119377943", Volume = 0.6 },
	CoreChime = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.5, PitchMin = 0.6, PitchMax = 0.6 },
	CoreStinger = { Id = "rbxassetid://133000497392138", Volume = 0.45, Duck = 5 },
	MeteorImpact = { Id = "rbxassetid://9114221261", Volume = 0.7 },
	MeteorRumble = { Id = "rbxasset://sounds/Rocket whoosh 01.wav", Volume = 0.2, PitchMin = 0.5, PitchMax = 0.5 },
	MeteorSiren = { Id = "rbxassetid://9119162409", Volume = 0.3, PitchMin = 0.95, PitchMax = 0.95, Cooldown = 0.5 },
	MeteorBuild = { Id = "rbxassetid://9125805781", Volume = 0.35 },
	FrostCrackle = { Id = "rbxassetid://9118588165", Volume = 0.5, PitchMin = 1.5, PitchMax = 1.8, Cooldown = 0.05, Max = 3 },
	CrystalChime = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.4, PitchMin = 1.3, PitchMax = 1.6, Cooldown = 0.05, Max = 3 },

	-- Refinery and money
	Deposit = { Id = "rbxassetid://9125885008", Volume = 0.5, PitchMin = 0.95, PitchMax = 1.1, Cooldown = 0.3 },
	Collect = { Id = "rbxassetid://9125509503", Volume = 0.4, PitchMin = 1.05, PitchMax = 1.2, Cooldown = 0.3 },
	CollectCoins = { Id = "rbxassetid://9113849492", Volume = 0.35, Cooldown = 0.3 },
	Sell = { Id = "rbxassetid://9113728042", Volume = 0.35, Cooldown = 0.3, Max = 2 },
	SellCoins = { Id = "rbxassetid://9113704271", Volume = 0.5, PitchMin = 1, PitchMax = 1.12, Cooldown = 0.3, Max = 2 },
	Purchase = { Id = "rbxassetid://9113728049", Volume = 0.4, Cooldown = 0.3, Max = 2 },

	-- Progress
	Upgrade = { Id = "rbxassetid://9117885256", Volume = 0.4, PitchMin = 1, PitchMax = 1.1, Cooldown = 0.1 },
	EvolveRise = { Id = "rbxassetid://9117297453", Volume = 0.3 },
	Evolve = { Id = "rbxassetid://1842141543", Volume = 0.45, Duck = 4.5 },
	LevelUp = { Id = "rbxassetid://1842335078", Volume = 0.5, Duck = 3.5 },
	PetChime = { Id = "rbxassetid://9116394545", Volume = 0.4, Cooldown = 0.2 },
	Bonus = { Id = "rbxassetid://9126072453", Volume = 0.4, PitchMin = 0.95, PitchMax = 1.1, Cooldown = 0.2 },
	RebirthWarp = { Id = "rbxassetid://9126102694", Volume = 0.5 },
	Rebirth = { Id = "rbxassetid://1844584698", Volume = 0.5, Duck = 5 },
	Teleport = { Id = "rbxassetid://9125648149", Volume = 0.45, Cooldown = 0.5 },

	-- Hatching: shell ticks while the egg wobbles, a crack, then a reveal by rarity
	HatchTick = { Id = "rbxassetid://9113959343", Variants = { "rbxassetid://9113959343", "rbxassetid://9113959071" }, Volume = 0.35, PitchMin = 1.15, PitchMax = 1.45, Cooldown = 0.12 },
	HatchCrack = { Id = "rbxassetid://9113958649", Volume = 0.55 },
	RevealCommon = { Id = "rbxassetid://9126073001", Volume = 0.45 },
	RevealRare = { Id = "rbxassetid://9116395089", Volume = 0.5 },
	RevealEpic = { Id = "rbxassetid://9117886786", Volume = 0.5, Duck = 2 },
	RevealLegendary = { Id = "rbxassetid://1845411858", Volume = 0.55, Duck = 5 },

	-- Interface
	Click = { Id = "rbxassetid://9119717523", Volume = 0.3, PitchMin = 0.97, PitchMax = 1.05, Cooldown = 0.05, Group = "UI" },
	MenuOpen = { Id = "rbxassetid://15675028888", Volume = 0.22, PitchMin = 1, PitchMax = 1.08, Cooldown = 0.1, Group = "UI" },
	MenuClose = { Id = "rbxassetid://15675012262", Volume = 0.18, Cooldown = 0.1, Group = "UI" },
	Deny = { Id = "rbxassetid://15675075163", Volume = 0.35, Cooldown = 0.6, Group = "UI" },
	TutorialStep = { Id = "rbxassetid://15675043410", Volume = 0.35, Group = "UI" },
}

return Sounds
