--!strict
-- Roblox policy is resolved in the background for each session. Paid random
-- items and paid-item trading must use these server checks if introduced;
-- ordinary mining, the current fixed-reward store and gameplay are unaffected.

local Players = game:GetService("Players")
local PolicyService = game:GetService("PolicyService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local PlayerPolicies = require(script.Parent.Parent.Lib.PlayerPolicies)

local PlayerPolicyService = Knit.CreateService({
	Name = "PlayerPolicyService",
	Client = {
		-- Only the owning client receives this sanitized per-player summary.
		Policy = Knit.CreateProperty({
			Status = "loading",
			ArePaidRandomItemsRestricted = true,
			IsPaidItemTradingAllowed = false,
		}),
	},
})

local policies = PlayerPolicies.new({
	lookup = function(player: Player)
		return PolicyService:GetPolicyInfoForPlayerAsync(player)
	end,
	defer = function(callback) task.defer(callback) end,
	delay = function(seconds, callback) task.delay(seconds, callback) end,
	changed = function(player: Player, policy: PlayerPolicies.PolicyInfo)
		PlayerPolicyService.Client.Policy:SetFor(player, policy)
	end,
})

function PlayerPolicyService:GetPolicyInfo(player: Player): PlayerPolicies.PolicyInfo
	return policies:Get(player)
end

function PlayerPolicyService:CanUsePaidRandomItems(player: Player): boolean
	return policies:CanUsePaidRandomItems(player)
end

function PlayerPolicyService:CanTradePaidItems(player: Player): boolean
	return policies:CanTradePaidItems(player)
end

function PlayerPolicyService:KnitStart()
	Players.PlayerAdded:Connect(function(player) policies:Add(player) end)
	Players.PlayerRemoving:Connect(function(player)
		policies:Remove(player)
		-- Knit/Comm removes its per-player property entry on PlayerRemoving.
	end)
	for _, player in Players:GetPlayers() do
		policies:Add(player)
	end
end

return PlayerPolicyService
