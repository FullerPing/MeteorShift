--!strict
-- Redeemable codes (Shared.Codes, CodesService). Each player can redeem each code once; it is saved in their profile.
-- Cash is a stretch of the player's own expected income (like the daily rewards), so a code is as big as their setup is.
export type Code = { Minutes: number?, Shards: number?, Expires: number? }

local Codes = {}

Codes.MaxLength = 32
Codes.CashFloor = 500 -- a code with Minutes never pays less cash than this (the ceiling still wins)
Codes.CashCeilingShare = 0.02 -- of the next rebirth's cost (0.05 let the three starter codes buy tier 3)

-- Add codes here. The name is UPPER CASE letters, digits, "-" and "_" (players may type any case).
--   Minutes  minutes of the player's income paid as cash   (optional)
--   Shards   Core Shards                                   (optional)
--   Expires  os.time() seconds in UTC; the code stops working from that second (optional)
-- A code needs Minutes or Shards. Example:
--   WELCOME = { Minutes = 20, Shards = 5 },
--   LAUNCHDAY = { Shards = 25, Expires = 1790000000 },
-- The starter codes: together they pay 30 Core Shards, one Meteor Egg, so a new player can hatch a first pet early.
Codes.List = {
	RELEASE = { Minutes = 10, Shards = 15 },
	CRATERWORKS = { Minutes = 5, Shards = 10 },
	METEOR = { Minutes = 5, Shards = 5 },

	-- The owner's giveaway codes (2026-10-24), none expiring. Small: a few minutes of cash and a handful of shards.
	STARDUST = { Minutes = 5, Shards = 3 },
	ROCKSOLID = { Minutes = 5, Shards = 3 },
	PICKPOCKET = { Minutes = 5, Shards = 4 },
	DEEPDIG = { Minutes = 5, Shards = 4 },
	SHOOTINGSTAR = { Minutes = 6, Shards = 5 },
	ORERUSH = { Minutes = 8 },
	HOTROCK = { Minutes = 8 },
	CRATERCREW = { Shards = 8 },
	-- Medium: a Meteor Egg's worth of shards (15), some with cash
	SPACEROCK = { Shards = 15 },
	COMETTAIL = { Shards = 15 },
	METEORSHOWER = { Minutes = 10, Shards = 15 },
	QUARTZHOUR = { Minutes = 10, Shards = 15 },
	FOXFRIEND = { Minutes = 10, Shards = 20 },
	ROCKETFUEL = { Minutes = 15, Shards = 20 },
	IMPACT = { Minutes = 15, Shards = 25 },
	-- Big: most of a Crystal Egg (60) or more; keep these for milestones and giveaways
	SUPERNOVA = { Minutes = 20, Shards = 40 },
	BIGBANG = { Minutes = 20, Shards = 50 },
	GALAXYBRAIN = { Minutes = 25, Shards = 60 },
	THANKYOU = { Minutes = 30, Shards = 75 },
	MILLIONMINERS = { Minutes = 30, Shards = 100 },
	-- Launch week only: stops working 2026-10-27 00:00 UTC
	LAUNCHPARTY = { Minutes = 15, Shards = 30, Expires = 1793059200 },
} :: { [string]: Code }

return Codes
