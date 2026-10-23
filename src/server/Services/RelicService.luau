--!strict
-- Relics (Config.Relics, Shared.Relics): rolls a find for every player who shares a cracked core (a boss core rolls
-- higher and always pays Relic Fragments) and for each ore-field rock broken. Owns profile.relics; the boosts reach the
-- game through PlayerStateService:GetPetBonuses, and fragments are spent by PetService:Fuse.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Config = require(ReplicatedStorage.Shared.Config)
local Relics = require(ReplicatedStorage.Shared.Relics)

local RelicService = Knit.CreateService({
	Name = "RelicService",
	Client = {
		Found = Knit.CreateSignal(), -- (relicId, isNew, fragments gained)
	},
})

local PlayerStateService
local RewardService
local TelemetryService
local rng = Random.new()

function RelicService:_roll(player: Player, chance: number, bonusFragments: number?)
	local data = PlayerStateService:Get(player)
	if not data then return end
	data.relics = Relics.clean(data.relics)
	local fragments = 0
	if bonusFragments and bonusFragments > 0 then
		data.relics.fragments += bonusFragments
		fragments += bonusFragments
	end
	local id = Relics.roll(chance, rng:NextNumber(), rng:NextNumber())
	local isNew = false
	if id then
		local before = data.relics.fragments
		isNew = Relics.add(data.relics, id)
		fragments += data.relics.fragments - before
		local def = Relics.def(id) :: Config.Relic
		RewardService:Bonus(player, "relic", if isNew then "Relic found: " .. def.Name .. "!" else def.Name .. " again: +" .. Config.Relics.DuplicateFragments .. " Relic Fragments")
		TelemetryService:custom(player, "relic_found", Relics.count(data.relics), { id, if isNew then "new" else "duplicate" })
	elseif fragments > 0 then
		RewardService:Bonus(player, "relic", "+" .. fragments .. " Relic Fragments")
	end
	if id or fragments > 0 then
		self.Client.Found:Fire(player, id, isNew, fragments)
		PlayerStateService:ReplicateNow(player)
	end
end

function RelicService:KnitInit()
	PlayerStateService = Knit.GetService("PlayerStateService")
	RewardService = Knit.GetService("RewardService")
	TelemetryService = Knit.GetService("TelemetryService")
end

function RelicService:KnitStart()
	local MeteorService = Knit.GetService("MeteorService")
	Knit.GetService("DataService").ProfileLoaded:Connect(function(player: Player)
		local data = PlayerStateService:Get(player)
		if data then data.relics = Relics.clean(data.relics) end
	end)
	RewardService.ShardsAwarded:Connect(function(player: Player)
		local meteorType = MeteorService:GetActiveType()
		local boss = meteorType ~= nil and meteorType.Id == Config.Meteor.Boss.Type
		local events = Knit.GetService("GlobalEventService"):Mult("relics")
		self:_roll(player, (if boss then Config.Relics.BossChance else Config.Relics.CoreChance) * events, if boss then Config.Relics.BossFragments else nil)
	end)
	Knit.GetService("DebrisService").RockBroken:Connect(function(player: Player, field: string)
		if field ~= "Filler" then self:_roll(player, Config.Relics.RockChance * Knit.GetService("GlobalEventService"):Mult("relics")) end
	end)
end

return RelicService
