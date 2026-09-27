--!strict
-- Debris rocks between meteors (spec §5.7). The rocks are placed by hand in
-- Workspace.Map.Debris; this service only gives them HP and respawns them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Config = require(ReplicatedStorage.Shared.Config)

local DebrisService = Knit.CreateService({
	Name = "DebrisService",
	Client = {},
})

local NodeService

local function setVisible(rock: BasePart, visible: boolean)
	rock.Transparency = if visible then 0 else 1
	rock.CanCollide = visible
	rock.CanQuery = visible
	-- decorative ore flecks on the rock
	for _, child in rock:GetDescendants() do
		if child:IsA("BasePart") then
			child.Transparency = if visible then 0 else 1
		end
	end
end

function DebrisService:_track(rock: BasePart)
	local id
	id = NodeService:Register(rock, {
		Kind = "Debris",
		MaxHp = Config.Debris.Hp,
		Ore = Config.Debris.Ore,
		OreMult = Config.Debris.YieldFraction,
		OnBroken = function()
			setVisible(rock, false)
			task.delay(math.random(Config.Debris.RespawnMin, Config.Debris.RespawnMax), function()
				if rock.Parent then
					NodeService:SetMaxHp(id, Config.Debris.Hp)
					setVisible(rock, true)
				end
			end)
		end,
	})
end

function DebrisService:KnitInit()
	NodeService = Knit.GetService("NodeService")
end

function DebrisService:KnitStart()
	local folder = workspace:WaitForChild("Map"):WaitForChild("Debris")
	for _, rock in folder:GetChildren() do
		if rock:IsA("BasePart") then
			self:_track(rock)
		end
	end
end

return DebrisService
