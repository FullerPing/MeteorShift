--!strict
-- Debris rocks between meteors (spec §5.7). The rocks are placed by hand in
-- Workspace.Map.Debris; this service only gives them HP and respawns them.
--
-- Like the meteor, debris adapts to the lobby (spec §5.3): each rock is sized for
-- one active player's pickaxe, picked at random, so it takes that player about
-- Config.Debris.Hp hits. A lone veteran among newcomers still gets rocks worth
-- swinging at, and newcomers still get rocks they break in a few hits. Rocks pick
-- again when they respawn, and untouched rocks re-pick every RerollInterval so a
-- player who just joined or upgraded soon finds rocks sized for them. Tougher
-- rocks get tinted, glowing flecks.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Config = require(ReplicatedStorage.Shared.Config)
local DebrisOre = require(ReplicatedStorage.Shared.DebrisOre)

local DebrisService = Knit.CreateService({
	Name = "DebrisService",
	Client = {},
})

local NodeService
local ActivityService

-- Fleck tint by the tier a rock is sized for; tiers 1-2 keep the flecks as built
local TIER_TINTS: { [number]: Color3 } = {
	[3] = Color3.fromRGB(90, 200, 220),
	[4] = Color3.fromRGB(90, 200, 220),
	[5] = Color3.fromRGB(190, 110, 255),
	[6] = Color3.fromRGB(190, 110, 255),
	[7] = Color3.fromRGB(255, 200, 70),
	[8] = Color3.fromRGB(255, 200, 70),
}

type Rock = {
	Part: BasePart,
	Id: number,
	Flecks: { [BasePart]: { Color: Color3, Material: Enum.Material } },
}

local rocks: { Rock } = {}

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

-- A random active player's pickaxe: its tier and Mining Power per hit (a fresh Basic
-- Pickaxe when nobody is active).
local function pickPickaxe(): (number, number)
	local pickaxes = ActivityService:GetActivePickaxes()
	if #pickaxes == 0 then
		return 1, 1
	end
	local pickaxe = pickaxes[math.random(1, #pickaxes)]
	return pickaxe.Tier, pickaxe.Power
end

-- Sizes a rock for a pickaxe (its tier tints the flecks, its Power sets the HP).
local function size(rock: Rock, tier: number, power: number)
	rock.Part:SetAttribute("Tier", tier)
	NodeService:SetMaxHp(rock.Id, Config.Debris.Hp * power)
	local tint = TIER_TINTS[tier]
	for fleck, original in rock.Flecks do
		fleck.Color = tint or original.Color
		fleck.Material = if tint then Enum.Material.Neon else original.Material
	end
end

function DebrisService:_track(part: BasePart)
	local flecks = {}
	for _, child in part:GetDescendants() do
		if child:IsA("BasePart") then
			flecks[child] = { Color = child.Color, Material = child.Material }
		end
	end

	local rock: Rock
	local id = NodeService:Register(part, {
		Kind = "Debris",
		MaxHp = Config.Debris.Hp,
		Ore = Config.Debris.Ore,
		OreMult = Config.Debris.YieldFraction,
		-- The tier changes on untouched rerolls and respawns. Read its current value
		-- (debris always drops the default ore; the tint only shows how tough a rock is).
		OreFor = function()
			return DebrisOre.forTier(part:GetAttribute("Tier") :: number?), Config.Debris.YieldFraction
		end,
		OnBroken = function()
			setVisible(part, false)
			task.delay(math.random(Config.Debris.RespawnMin, Config.Debris.RespawnMax), function()
				if part.Parent then
					size(rock, pickPickaxe())
					setVisible(part, true)
				end
			end)
		end,
	})
	rock = { Part = part, Id = id, Flecks = flecks }
	size(rock, pickPickaxe())
	table.insert(rocks, rock)
end

-- Re-picks the tier of rocks nobody has hit yet.
function DebrisService:_reroll()
	for _, rock in rocks do
		local hp, maxHp = NodeService:GetHp(rock.Id)
		if hp > 0 and hp >= maxHp then
			size(rock, pickPickaxe())
		end
	end
end

function DebrisService:KnitInit()
	NodeService = Knit.GetService("NodeService")
	ActivityService = Knit.GetService("ActivityService")
end

function DebrisService:KnitStart()
	local folder = workspace:WaitForChild("Map"):WaitForChild("Debris")
	for _, part in folder:GetChildren() do
		if part:IsA("BasePart") then
			self:_track(part)
		end
	end

	task.spawn(function()
		while true do
			task.wait(Config.Debris.RerollInterval)
			self:_reroll()
		end
	end)
end

return DebrisService
