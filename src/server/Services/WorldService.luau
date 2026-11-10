--!strict
-- Travel between the worlds (Config.Worlds), each its own place in this universe. The portal in each town
-- (Map.TownSquare.WorldPortal, its part named Prompt; a `World` attribute picks the destination, else the other
-- world) and the client's Travel remote both land here: the server checks the unlock, saves and releases the
-- profile (DataService:ReleaseForTeleport), then teleports. Teleports don't run in Studio.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local WorldsConfig = require(ReplicatedStorage.Shared.Config.Worlds)
local Worlds = require(ReplicatedStorage.Shared.Worlds)
local WorldMap = require(ReplicatedStorage.Shared.WorldMap)
local RequestGate = require(ReplicatedStorage.Shared.RequestGate)

local DataService

local WorldService = Knit.CreateService({ Name = "WorldService", Client = {
	Notice = Knit.CreateSignal(), -- (text) why a travel didn't happen
} })

local traveling: { [Player]: boolean } = {}
local lastRequest: { [Player]: number } = {}

function WorldService:Current(): WorldsConfig.World
	return Worlds.current(game.PlaceId, RunService:IsStudio(), workspace:GetAttribute("DevWorld"))
end

-- Sends the player to world `worldId`. Returns nil once the teleport is under way, else why it can't happen.
function WorldService:Travel(player: Player, worldId: any): string?
	local world = Worlds.find(worldId)
	if not world or world.Id == self:Current().Id then return "You are already here" end
	if traveling[player] then return nil end
	local profile = DataService:GetProfile(player)
	if not profile then return "Still loading, try again in a moment" end
	if not Worlds.isOpen(world, profile.Data.rebirths or 0) then
		return string.format("%s opens at Rebirth %d", world.Name, (world.Unlock :: any).Rebirths)
	end
	if RunService:IsStudio() then return "Teleports only work in the live game" end
	local placeId = Worlds.destination(world, game.PlaceId)
	if not placeId then return world.Name .. " isn't open yet" end
	traveling[player] = true
	DataService:ReleaseForTeleport(player)
	local ok, err = pcall(TeleportService.TeleportAsync, TeleportService, placeId, { player })
	if not ok then
		warn("[WorldService] teleport failed for", player.Name, err)
		traveling[player] = nil
		DataService:Hold(player)
		return "The teleport failed, try again"
	end
	return nil
end

function WorldService:_request(player: Player, worldId: any)
	local allowed, stamp = RequestGate.check(lastRequest[player], os.clock(), 3)
	lastRequest[player] = stamp
	if not allowed then return end
	local why = self:Travel(player, worldId)
	if why then self.Client.Notice:Fire(player, why) end
end

function WorldService.Client:Travel(player: Player, worldId: any)
	self.Server:_request(player, worldId)
end

function WorldService:_wirePortal(portal: Instance)
	local part = portal:FindFirstChild("Prompt", true)
	if not part or not part:IsA("BasePart") or part:FindFirstChild("WorldPrompt") then return end
	local here = self:Current()
	local target = Worlds.find(portal:GetAttribute("World")) or Worlds.find(if here.Id == 1 then 2 else 1)
	if not target then return end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "WorldPrompt"
	prompt.ActionText = "Travel"
	prompt.ObjectText = target.Name
	prompt.HoldDuration = 0.5
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = part
	prompt.Triggered:Connect(function(player) self:_request(player, target.Id) end)
end

function WorldService:KnitInit()
	DataService = Knit.GetService("DataService")
end

function WorldService:KnitStart()
	TeleportService.TeleportInitFailed:Connect(function(player, _result, message)
		if not traveling[player] then return end
		warn("[WorldService] teleport didn't start for", player.Name, message)
		traveling[player] = nil
		DataService:Hold(player)
		self.Client.Notice:Fire(player, "The teleport failed, try again")
	end)
	Players.PlayerRemoving:Connect(function(player)
		traveling[player] = nil
		lastRequest[player] = nil
	end)
	task.spawn(function()
		local map = WorldMap.wait()
		for _, d in map:GetDescendants() do
			if d.Name == "WorldPortal" then self:_wirePortal(d) end
		end
		map.DescendantAdded:Connect(function(d)
			if d.Name == "WorldPortal" then task.defer(function() self:_wirePortal(d) end) end
		end)
	end)
end

return WorldService
