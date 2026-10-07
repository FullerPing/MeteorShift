--!strict
-- Player level (Shared.Levels, Config.Levels). XP arrives as you play: every validated hit
-- on a crust node or the core pays a little (by the meteor's ore), and a cracked core adds a
-- bonus (RewardService). Debris pays nothing. The level and XP are in the profile, survive
-- rebirth, and replicate in State (level, xp, xpNeeded). Every level gained opens a Supply Crate
-- (Shared.Hooks.crate): a random handful of cash and sometimes shards.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Hooks = require(ReplicatedStorage.Shared.Hooks)
local Levels = require(ReplicatedStorage.Shared.Levels)
local Perks = require(ReplicatedStorage.Shared.Perks)
local Pets = require(ReplicatedStorage.Shared.Pets)
local Purchases = require(ReplicatedStorage.Shared.Purchases)
local Rebirth = require(ReplicatedStorage.Shared.Rebirth)
local Refining = require(script.Parent.Parent.Lib.Refining)

local LevelService = Knit.CreateService({
	Name = "LevelService",
	Client = {
		LevelUp = Knit.CreateSignal(), -- (level)
	},
})

local PlayerStateService
local NodeService
local MeteorService
local ContributionService
local EconomyService
local RewardService

-- Opens one Supply Crate for a level gained (Config.Hooks.SupplyCrate). Its cash is a stretch of the
-- player's own line income, so it is as big as the level they are at, never a flat amount.
local function openCrate(player: Player, data: any)
	local income = Refining.lineRate(data, nil, Perks.lineMult(data.perks)) * Purchases.averageBarPrice(data.level) * EconomyService:SaleMultiplier(player)
	local ceiling = Rebirth.cost(data.rebirths) * Config.Hooks.CrateCeilingShare
	local crate = Hooks.crate(income, ceiling, math.random(), math.random(), math.random())
	if crate.cash > 0 then
		PlayerStateService:AddCash(player, crate.cash)
	end
	if crate.shards > 0 then
		PlayerStateService:AddShards(player, crate.shards)
	end
	local parts = {}
	if crate.cash > 0 then
		table.insert(parts, "+" .. Format.cash(crate.cash))
	end
	if crate.shards > 0 then
		table.insert(parts, "+" .. crate.shards .. " ◆")
	end
	RewardService:Bonus(player, "crate", "Level " .. data.level .. " Supply Crate: " .. table.concat(parts, " and "))
end

-- Adds XP to the player's profile. Returns the validated scholar-adjusted award,
-- even when a level-up consumes XP from the bar. Fires LevelUp and replicates State.
function LevelService:AddXp(player: Player, amount: number): number
	local data = PlayerStateService:Get(player)
	if not data or amount <= 0 then
		return 0
	end
	local awarded = Pets.playerXp(amount, PlayerStateService:GetPetBonuses(player).scholar)
	if awarded <= 0 then return 0 end
	local gained = Levels.addXp(data, awarded)
	Knit.GetService("PetService"):Work(player, "scholar")
	PlayerStateService:Replicate(player)
	if gained > 0 then
		self.Client.LevelUp:Fire(player, data.level)
		openCrate(player, data)
	end
	return awarded
end

function LevelService:KnitInit()
	PlayerStateService = Knit.GetService("PlayerStateService")
	NodeService = Knit.GetService("NodeService")
	MeteorService = Knit.GetService("MeteorService")
	ContributionService = Knit.GetService("ContributionService")
	EconomyService = Knit.GetService("EconomyService")
	RewardService = Knit.GetService("RewardService")
end

function LevelService:KnitStart()
	NodeService.Hit:Connect(function(player: Player, kind: string)
		local meteorType = MeteorService:GetActiveType()
		if meteorType then
			local awarded = self:AddXp(player, Levels.hitXp(meteorType.Ore, kind))
			ContributionService:AddXp(player, awarded)
		end
	end)
end

return LevelService
