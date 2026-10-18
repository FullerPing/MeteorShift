--!strict
-- Background music and ambience (client/Controllers/MusicController.luau). Tracks are APM
-- library uploads and the beds are Pro Sound Effects loops, all licensed for every experience
-- (docs/guide/audio.md). The hub track plays in calm times; the event track fades in as a meteor
-- approaches (AtmosphereMood's approach weight) and stays while it is down, then hands back.

local Music = {
	Hub = { Id = "rbxassetid://1837464887", Volume = 0.22 }, -- "Tropical Island": marimba, steel drums, guitar
	Event = { Id = "rbxassetid://9040031590", Volume = 0.24 }, -- "Level Up (Alternate 3)": driving drums and synth
	Fade = 2.5, -- seconds for a full crossfade
	DuckTo = 0.35, -- music level (0..1) under a stinger
	DuckFade = 0.25,

	-- Beds: Ambience plays everywhere; the crater hum sits on the active meteor and fades out with distance
	Ambience = { Id = "rbxassetid://9112832288", Volume = 0.12 }, -- "Mountain Birds 1": light, distant birds and air
	CraterHum = { Id = "rbxassetid://9112824733", Volume = 0.35, MinDistance = 25, MaxDistance = 220 }, -- "Low Rumble 2"

	-- The siren sounds this many seconds before impact (with a rising whoosh), as the sky starts to turn
	WarnAt = 12,
}

return Music
