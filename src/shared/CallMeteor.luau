--!strict
-- Call a Meteor rules (spec §9.2). The product summons the next scheduled meteor
-- early for the whole server, so it may only be bought when that actually helps:
--
--   available      during Countdown with more than MinSecondsLeft to go, at least
--                  Cooldown seconds after the previous CALLED meteor's event ended
--                  (nil when no called meteor has ended yet: no cooldown), and while the server has called fewer than
--                  HourlyCap meteors in the rolling CapWindow. When it isn't, the
--                  second result says why, for the store's disabled button.
--   callsInWindow  how many call times fall inside the rolling window ending now
--
-- Config.Monetization.CallMeteor holds the limits. MeteorService applies the rules
-- (CanCallMeteor / CallMeteor); pure functions only, covered by tests/CallMeteor.spec.

local Monetization = require(script.Parent.Config.Monetization)

local Rules = Monetization.CallMeteor

local CallMeteor = {}

function CallMeteor.available(
	phase: string,
	secondsLeft: number,
	sinceLastEnd: number?,
	callsInLastHour: number
): (boolean, string?)
	if phase ~= "Countdown" then
		return false, "A meteor is already here."
	end
	if secondsLeft <= Rules.MinSecondsLeft then
		return false, "The meteor is almost here."
	end
	if sinceLastEnd and sinceLastEnd < Rules.Cooldown then
		return false, "Too soon after the last meteor."
	end
	if callsInLastHour >= Rules.HourlyCap then
		return false, "This server has called enough meteors this hour."
	end
	return true, nil
end

function CallMeteor.callsInWindow(times: { number }, now: number): number
	local count = 0
	for _, at in times do
		if now - at < Rules.CapWindow then
			count += 1
		end
	end
	return count
end

return CallMeteor
