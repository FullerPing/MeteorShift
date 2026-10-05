--!strict
-- Who counts as active (spec §5.3): players with any input in the last 2 minutes.
-- Meteor HP is sized from active players only, so AFK players don't make the
-- meteor impossible for everyone else.
--
-- Clients ping on input (ActivityController, throttled); swings count too, and a
-- player who just joined starts out active.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Config = require(ReplicatedStorage.Shared.Config)
local Gear = require(ReplicatedStorage.Shared.Gear)
local RequestGate = require(ReplicatedStorage.Shared.RequestGate)

local ActivityService = Knit.CreateService({
	Name = "ActivityService",
	Client = {},
})

local lastInput: { [Player]: number } = {}
local lastPingRequest: { [Player]: number } = {}

function ActivityService:Touch(player: Player)
	lastInput[player] = os.clock()
end

function ActivityService:IsActive(player: Player): boolean
	local last = lastInput[player]
	return last ~= nil and os.clock() - last <= Config.Meteor.ActiveWindow
end

function ActivityService:GetActivePlayers(): { Player }
	local list = {}
	for _, player in Players:GetPlayers() do
		if self:IsActive(player) then
			table.insert(list, player)
		end
	end
	return list
end

-- The active players' pickaxes as they play now (Tier, Power, Swing, ...). In Studio,
-- ServerStorage's DevFakeTiers attribute ("1,1,8") adds pretend active players, each with
-- a fresh pickaxe of that tier, so sizing can be tested solo.
function ActivityService:GetActivePickaxes(): { any }
	local PlayerStateService = Knit.GetService("PlayerStateService")
	local pickaxes = {}
	for _, player in self:GetActivePlayers() do
		table.insert(pickaxes, PlayerStateService:GetPickaxe(player))
	end
	local fake = ServerStorage:GetAttribute("DevFakeTiers")
	if RunService:IsStudio() and typeof(fake) == "string" then
		for tier in string.gmatch(fake, "%d+") do
			local clamped = math.clamp(tonumber(tier) :: number, 1, #Config.Pickaxes)
			table.insert(pickaxes, Gear.pickaxe(clamped, Gear.freshPickaxeStats(clamped)))
		end
	end
	return pickaxes
end

-- Mining Power per second of each active player (meteor sizing, Shared.MiningPower).
function ActivityService:GetActiveRates(): { number }
	local rates = {}
	for _, pickaxe in self:GetActivePickaxes() do
		table.insert(rates, pickaxe.Power / pickaxe.Swing)
	end
	return rates
end

function ActivityService.Client:Ping(player: Player)
	local allowed, stamp = RequestGate.check(lastPingRequest[player], os.clock(), 1)
	lastPingRequest[player] = stamp
	if not allowed then return end
	self.Server:Touch(player)
end

function ActivityService:KnitStart()
	for _, player in Players:GetPlayers() do
		self:Touch(player)
	end
	Players.PlayerAdded:Connect(function(player)
		self:Touch(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastInput[player] = nil
		lastPingRequest[player] = nil
	end)
end

return ActivityService
