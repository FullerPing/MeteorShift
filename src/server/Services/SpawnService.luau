--!strict
-- Spawning by the portal, for maps that ask for it (the Map attribute SpawnNearPortal; Nebula Rift): Roblox drops a
-- new character on any SpawnLocation, then this moves it onto the free pad nearest TownSquare.WorldPortal
-- (Shared.SpawnPick), so everyone lands in the middle by the portal unless someone already stands there. The pads
-- themselves are invisible in the map. World 1 doesn't set the attribute and keeps Roblox's own spawning.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local SpawnPick = require(ReplicatedStorage.Shared.SpawnPick)
local WorldMap = require(ReplicatedStorage.Shared.WorldMap)

local SpawnService = Knit.CreateService({ Name = "SpawnService" })

local OCCUPIED = 4 -- studs: someone this close to a pad's centre is standing on it

local function flat(position: Vector3): SpawnPick.Point
	return { x = position.X, z = position.Z }
end

function SpawnService:_place(character: Model)
	local map = WorldMap.wait()
	local portal = map:FindFirstChild("WorldPortal", true)
	if map:GetAttribute("SpawnNearPortal") ~= true or not (portal and portal:IsA("Model")) then return end
	local pads: { SpawnLocation } = {}
	for _, item in map:GetDescendants() do
		if item:IsA("SpawnLocation") and item.Enabled then table.insert(pads, item) end
	end
	local others = {}
	for _, player in Players:GetPlayers() do
		local root = player.Character and player.Character ~= character and player.Character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then table.insert(others, flat(root.Position)) end
	end
	local points = {}
	for _, pad in pads do table.insert(points, flat(pad.Position)) end
	local index = SpawnPick.choose(points, flat(portal:GetPivot().Position), others, OCCUPIED)
	if not index then return end
	local pad = pads[index]
	-- stand on the pad, facing away from the portal (toward the town)
	local feet = pad.Position + Vector3.new(0, pad.Size.Y / 2 + 3, 0)
	local away = pad.Position - portal:GetPivot().Position
	character:PivotTo(CFrame.lookAt(feet, feet + Vector3.new(away.X, 0, away.Z)))
end

function SpawnService:KnitStart()
	local function watch(player: Player)
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("HumanoidRootPart", 10)
			task.wait() -- after Roblox's own placement on a SpawnLocation
			self:_place(character)
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do watch(player) end
end

return SpawnService
