--!strict
-- Active gameplay resets (gear levels included); the pickaxe and backpack tiers, pets, refinery upgrades, shards, colony
-- perks and index rewards survive. Station Memory keeps part of the hopper, conveyor and collection post levels and Head Start
-- is a floor for the gear tier, up to what the player level allows (Shared.Perks), for players who own less than that.
-- With keepAll (the Rebirth and Keep Everything product) nothing resets: the rebirth count
-- still goes up (RebirthService), but cash, gear levels, production and carried ore all stay.
-- Keep the profile/maps in place so existing service references remain valid.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Gear = require(ReplicatedStorage.Shared.Gear)
local Levels = require(ReplicatedStorage.Shared.Levels)
local Perks = require(ReplicatedStorage.Shared.Perks)
local Template = require(script.Parent.ProfileTemplate)
local RebirthReset = {}

function RebirthReset.apply(data: any, now: number, keepAll: boolean?)
	if keepAll then
		data.overflow = 0 -- the overstay shards were paid out already
		data.lastSeen = now
		return
	end
	local refineryLevel = data.stations.refinery or Template.stations.refinery
	data.cash = Template.cash
	local perks = Perks.clean(data.perks)
	local playerLevel = data.level or 1
	local oldStations = table.clone(data.stations)
	data.pickaxeTier = math.max(data.pickaxeTier or 1, Perks.startTier(perks, playerLevel, #Config.Pickaxes, Levels.evolveLevel))
	data.backpackTier = math.max(data.backpackTier or 1, Perks.startTier(perks, playerLevel, #Config.Backpacks, Levels.evolveLevel))
	data.pickaxeLevel = Gear.levelsForTier(data.pickaxeTier)
	data.backpackLevel = Gear.levelsForTier(data.backpackTier)
	for _, key in { "backpack", "hopper", "bin", "bars", "decor" } do
		table.clear(data[key])
	end
	for id, level in Template.stations do
		data.stations[id] = if id == "refinery" then refineryLevel else Perks.keptStation(perks, oldStations[id] or level)
	end
	data.progress = Template.progress
	data.overflow = 0
	data.lastSeen = now
end

return RebirthReset
