--!strict
-- Player level (Shared.Levels, Config.Levels). XP arrives as you play: every validated hit
-- on a crust node or the core pays a little (by the meteor's ore), and a cracked core adds a
-- bonus (RewardService). Debris pays nothing. The level and XP are in the profile, survive
-- rebirth, and replicate in State (level, xp, xpNeeded).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Levels = require(ReplicatedStorage.Shared.Levels)

local LevelService = Knit.CreateService({
	Name = "LevelService",
	Client = {
		LevelUp = Knit.CreateSignal(), -- (level)
	},
})

local PlayerStateService
local NodeService
local MeteorService

-- Adds XP to the player's profile. Fires LevelUp for a level gained and replicates State.
function LevelService:AddXp(player: Player, amount: number)
	local data = PlayerStateService:Get(player)
	if not data or amount <= 0 then
		return
	end
	local gained = Levels.addXp(data, amount)
	PlayerStateService:Replicate(player)
	if gained > 0 then
		self.Client.LevelUp:Fire(player, data.level)
	end
end

function LevelService:KnitInit()
	PlayerStateService = Knit.GetService("PlayerStateService")
	NodeService = Knit.GetService("NodeService")
	MeteorService = Knit.GetService("MeteorService")
end

function LevelService:KnitStart()
	NodeService.Hit:Connect(function(player: Player, kind: string)
		local meteorType = MeteorService:GetActiveType()
		if meteorType then
			self:AddXp(player, Levels.hitXp(meteorType.Ore, kind))
		end
	end)
end

return LevelService
