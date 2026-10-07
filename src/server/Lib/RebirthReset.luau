--!strict
-- Active gameplay resets (gear tiers and stat levels included); refinery upgrades, shards, colony perks and index rewards
-- survive. Station Memory keeps part of the hopper, conveyor and collection post levels and Head Start rebuilds the
-- pickaxe and backpack at a higher tier, up to what the player level allows (Shared.Perks).
-- Keep the profile/maps in place so existing service references remain valid.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Gear = require(ReplicatedStorage.Shared.Gear)
local Levels = require(ReplicatedStorage.Shared.Levels)
local Perks = require(ReplicatedStorage.Shared.Perks)
local Template = require(script.Parent.ProfileTemplate)
local RebirthReset = {}

function RebirthReset.apply(data: any, now: number)
	local refineryLevel = data.stations.refinery or Template.stations.refinery
	data.cash = Template.cash
	local perks = Perks.clean(data.perks)
	local playerLevel = data.level or 1
	local oldStations = table.clone(data.stations)
	data.pickaxeTier = Perks.startTier(perks, playerLevel, #Config.Pickaxes, Levels.evolveLevel)
	data.backpackTier = Perks.startTier(perks, playerLevel, #Config.Backpacks, Levels.evolveLevel)
	for stat, level in Gear.freshPickaxeStats(data.pickaxeTier) do
		data.pickaxeStats[stat] = level
	end
	for stat, level in Gear.freshBackpackStats(data.backpackTier) do
		data.backpackStats[stat] = level
	end
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
