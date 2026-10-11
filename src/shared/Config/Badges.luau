--!strict
-- Roblox Badge ids by key (DailyService awards them). 0 means the badge does not exist yet: nothing is awarded.
-- Create each badge in Creator Hub > Badges, then paste its id here.
return {
	firstMeteor = 0, -- first hit on a meteor
	firstCore = 0, -- first shared core crack
	firstRebirth = 0,
	rebirth10 = 0,
	level25 = 0,
	level50 = 0,
	pageIron = 0, -- completed a mineral index page
	pageIce = 0,
	pageCrystal = 0,
	legendaryPet = 0, -- owns a Legendary pet
	streak7 = 0, -- claimed day 7 of the daily streak
} :: { [string]: number }
