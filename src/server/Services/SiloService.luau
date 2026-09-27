--!strict
-- Week 1 stand-in for the home hopper: stepping on the Ore Silo pad in the town
-- square empties your backpack so you can keep mining. Week 2 replaces this with
-- per-plot hoppers.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)

local SiloService = Knit.CreateService({
	Name = "SiloService",
	Client = {
		Deposited = Knit.CreateSignal(), -- (amount: number)
	},
})

function SiloService:KnitStart()
	local PlayerStateService = Knit.GetService("PlayerStateService")
	local pad = workspace:WaitForChild("Map"):WaitForChild("TownSquare"):WaitForChild("OreSilo"):WaitForChild("DepositPad") :: BasePart

	local cooldown: { [Player]: number } = {}
	pad.Touched:Connect(function(hit)
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		if not player then
			return
		end
		local t = os.clock()
		if t - (cooldown[player] or 0) < 1 then
			return
		end
		cooldown[player] = t
		local moved = PlayerStateService:DepositAll(player)
		if moved > 0 then
			self.Client.Deposited:Fire(player, moved)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		cooldown[player] = nil
	end)
end

return SiloService
