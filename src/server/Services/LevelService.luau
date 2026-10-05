--!strict
-- Player level (Shared.Levels, Config.Levels). XP arrives as you play: every validated hit
-- on a crust node or the core pays a little (by the meteor's ore), and a cracked core adds a
-- bonus (RewardService). Debris pays nothing. The level and XP are in the profile, survive
-- rebirth, and replicate in State (level, xp, xpNeeded).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Levels = require(ReplicatedStorage.Shared.Levels)
local Pets = require(ReplicatedStorage.Shared.Pets)

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
	end
	return awarded
end

function LevelService:KnitInit()
	PlayerStateService = Knit.GetService("PlayerStateService")
	NodeService = Knit.GetService("NodeService")
	MeteorService = Knit.GetService("MeteorService")
	ContributionService = Knit.GetService("ContributionService")
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
