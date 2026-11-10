--!strict
-- Cash sized as a stretch of a player's expected income (Shared.Pacing.expectedIncome): Robux cash
-- packs and the cash ore fields both pay this way, so a reward is as big as the player's setup is.

local Income = {}

-- `seconds` of `perSecond`, kept between a floor and a ceiling so a tiny or a huge income still gives a
-- sensible amount. The ceiling wins when it is below the floor.
function Income.grant(seconds: number, perSecond: number, floor: number, ceiling: number): number
	local cap = math.max(ceiling, 0)
	return math.floor(math.clamp(seconds * perSecond, math.min(math.max(floor, 0), cap), cap))
end

return Income
