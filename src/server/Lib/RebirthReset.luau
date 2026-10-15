--!strict
-- Active gameplay resets (gear levels and the production line included); the pickaxe and backpack tiers, pets, shards, colony
-- perks and index rewards survive. Station Memory keeps part of the production line level and Head Start
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
	data.cash = Template.cash
	local perks = Perks.clean(data.perks)
	local playerLevel = data.level or 1
	data.pickaxeTier = math.max(data.pickaxeTier or 1, Perks.startTier(perks, playerLevel, #Config.Pickaxes, Levels.evolveLevel))
	data.backpackTier = math.max(data.backpackTier or 1, Perks.startTier(perks, playerLevel, #Config.Backpacks, Levels.evolveLevel))
	data.pickaxeLevel = Gear.levelsForTier(data.pickaxeTier)
	data.backpackLevel = Gear.levelsForTier(data.backpackTier)
	for _, key in { "backpack", "hopper", "bin", "bars", "decor" } do
		table.clear(data[key])
	end
	data.line = Perks.keptStation(perks, data.line or Template.line)
	data.progress = Template.progress
	data.overflow = 0
	data.lastSeen = now
end

return RebirthReset
