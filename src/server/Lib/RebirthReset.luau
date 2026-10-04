--!strict
-- Active gameplay resets; refinery upgrades, shards and index rewards survive.
-- Keep the profile/maps in place so existing service references remain valid.
local Template = require(script.Parent.ProfileTemplate)
local RebirthReset = {}

function RebirthReset.apply(data: any, now: number)
	local refineryLevel = data.stations.refinery or Template.stations.refinery
	data.cash = Template.cash
	data.pickaxeTier = Template.pickaxeTier
	data.backpackTier = Template.backpackTier
	for _, key in { "backpack", "hopper", "bin", "bars", "decor" } do
		table.clear(data[key])
	end
	for id, level in Template.stations do
		data.stations[id] = if id == "refinery" then refineryLevel else level
	end
	data.progress = Template.progress
	data.lastSeen = now
end

return RebirthReset
