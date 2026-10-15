--!strict
-- Redeemable codes (Shared.Codes, CodesService). Each player can redeem each code once; it is saved in their profile.
-- Cash is a stretch of the player's own expected income (like the daily rewards), so a code is as big as their setup is.
export type Code = { Minutes: number?, Shards: number?, Expires: number? }

local Codes = {}

Codes.MaxLength = 32
Codes.CashFloor = 500 -- a code with Minutes never pays less cash than this (the ceiling still wins)
Codes.CashCeilingShare = 0.05 -- of the next rebirth's cost

-- Add codes here. The name is UPPER CASE letters, digits, "-" and "_" (players may type any case).
--   Minutes  minutes of the player's income paid as cash   (optional)
--   Shards   Core Shards                                   (optional)
--   Expires  os.time() seconds in UTC; the code stops working from that second (optional)
-- A code needs Minutes or Shards. Example:
--   WELCOME = { Minutes = 20, Shards = 5 },
--   LAUNCHDAY = { Shards = 25, Expires = 1790000000 },
Codes.List = {} :: { [string]: Code }

return Codes
