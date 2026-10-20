--!strict
-- Active gameplay resets (gear levels and the production line included); the pickaxe and backpack tiers, pets, shards, colony
-- perks, index rewards and settings survive. Station Memory keeps part of the production line level and Head Start
-- gives starting cash, a share of the next rebirth's cost (Shared.Perks). Call it before the rebirth count goes up.
-- With keepAll (the Rebirth and Keep Everything product) nothing resets: the rebirth count
-- still goes up (RebirthService), but cash, gear levels, production and carried ore all stay.
-- Keep the profile/maps in place so existing service references remain valid.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Gear = require(ReplicatedStorage.Shared.Gear)
local Perks = require(ReplicatedStorage.Shared.Perks)
local Rebirth = require(ReplicatedStorage.Shared.Rebirth)
local Template = require(script.Parent.ProfileTemplate)
local RebirthReset = {}

function RebirthReset.apply(data: any, now: number, keepAll: boolean?)
	if keepAll then
		data.overflow = 0 -- the overstay shards were paid out already
		data.lastSeen = now
		return
	end
	local perks = Perks.clean(data.perks)
	data.cash = Template.cash + Perks.startCash(perks, Rebirth.cost((data.rebirths or 0) + 1))
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
