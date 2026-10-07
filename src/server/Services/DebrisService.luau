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

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WorldMap = require(ReplicatedStorage.Shared.WorldMap)
local Knit = require(ReplicatedStorage.Packages.Knit)
local Config = require(ReplicatedStorage.Shared.Config)
local DebrisOre = require(ReplicatedStorage.Shared.DebrisOre)
local FieldTravel = require(ReplicatedStorage.Shared.FieldTravel)
local RequestGate = require(ReplicatedStorage.Shared.RequestGate)
local StudSkin = require(ReplicatedStorage.Shared.StudSkin)

local DebrisService = Knit.CreateService({
	Name = "DebrisService",
	Client = {},
})

local lastTravel: { [Player]: number } = {}

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

-- Brings a grey stone rock into the bright studded look: plastic, tinted toward the colour of its
-- ore flecks, with the map's studs on top. Rocks keep their drops and HP; this is paint only.
local function skin(part: BasePart, flecks: { [BasePart]: any })
	local fleck = next(flecks)
	if fleck then
		part.Color = part.Color:Lerp(fleck.Color, Config.Debris.Rock.TintMix)
	end
	part.Material = Enum.Material.Plastic
	StudSkin.apply(part)
end

function DebrisService:_track(part: BasePart)
	local flecks = {}
	for _, child in part:GetDescendants() do
		if child:IsA("BasePart") then
			flecks[child] = { Color = child.Color, Material = child.Material }
		end
	end
	skin(part, flecks)

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

-- Where on a field to land: the first aisle spot with nothing in the way, on top of the floor.
function DebrisService:_fieldSpot(id: string): Vector3?
	local fields = WorldMap.find() and WorldMap.find():FindFirstChild("DebrisFields")
	local field = fields and fields:FindFirstChild(id)
	local floor = field and (field :: Model).PrimaryPart or (field and field:FindFirstChild("FieldFloor"))
	if not (floor and floor:IsA("BasePart")) then return nil end
	local top = floor.Position.Y + floor.Size.Y / 2
	local params = OverlapParams.new()
	params.RespectCanCollide = true
	local function free(dx: number, dz: number): boolean
		local at = Vector3.new(floor.Position.X + dx, top + 3.6, floor.Position.Z + dz)
		return #workspace:GetPartBoundsInBox(CFrame.new(at), Vector3.new(5, 6.8, 5), params) == 0
	end
	local dx, dz = FieldTravel.pick(free)
	return Vector3.new(floor.Position.X + dx, top + 3.6, floor.Position.Z + dz)
end

-- Teleports a player to an ore field; false when the request is refused.
function DebrisService:TravelTo(player: Player, id: any): boolean
	if not FieldTravel.find(id) then return false end
	local character = player.Character
	if not character then return false end
	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not (root and root:IsA("BasePart") and humanoid and humanoid.Health > 0) then return false end
	local spot = self:_fieldSpot(id)
	if not spot then return false end
	character:PivotTo(CFrame.new(spot))
	root.AssemblyLinearVelocity = Vector3.zero
	return true
end

function DebrisService.Client:TravelTo(player: Player, id: string): boolean
	local allowed, stamp = RequestGate.check(lastTravel[player], os.clock(), Config.Debris.TravelCooldown)
	lastTravel[player] = stamp
	if not allowed then return false end
	return self.Server:TravelTo(player, id)
end

function DebrisService:KnitInit()
	NodeService = Knit.GetService("NodeService")
	ActivityService = Knit.GetService("ActivityService")
end

function DebrisService:KnitStart()
	Players.PlayerRemoving:Connect(function(player)
		lastTravel[player] = nil
	end)
	local folder = WorldMap.wait():WaitForChild("Debris")
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
