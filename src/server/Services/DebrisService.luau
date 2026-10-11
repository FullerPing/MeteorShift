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
--
-- A rock's Field attribute puts it in one of the ore fields (Config.Debris.Fields), which set its hits and
-- its reward: cash worth a few seconds of the breaker's expected income (Economy:ExpectedIncome), or a
-- better ore than iron. Rocks outside a field stay plain iron filler.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WorldMap = require(ReplicatedStorage.Shared.WorldMap)
local Knit = require(ReplicatedStorage.Packages.Knit)
local Config = require(ReplicatedStorage.Shared.Config)
local DebrisField = require(ReplicatedStorage.Shared.DebrisField)
local DebrisOre = require(ReplicatedStorage.Shared.DebrisOre)
local FieldTravel = require(ReplicatedStorage.Shared.FieldTravel)
local Format = require(ReplicatedStorage.Shared.Format)
local Levels = require(ReplicatedStorage.Shared.Levels)
local Rebirth = require(ReplicatedStorage.Shared.Rebirth)
local RequestGate = require(ReplicatedStorage.Shared.RequestGate)
local StudSkin = require(ReplicatedStorage.Shared.StudSkin)

local DebrisService = Knit.CreateService({
	Name = "DebrisService",
	Client = {},
})

local lastTravel: { [Player]: number } = {}

local NodeService
local ActivityService
local PlayerStateService
local EconomyService
local RewardService

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
	Reward: DebrisField.Reward?, -- what its field pays, nil for filler
	Hits: number, -- hits to break for the player it is sized for
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
	NodeService:SetMaxHp(rock.Id, rock.Hits * power)
	local tint = TIER_TINTS[tier]
	for fleck, original in rock.Flecks do
		fleck.Color = tint or original.Color
		fleck.Material = if tint then Enum.Material.Neon else original.Material
	end
end

-- Brings a stone rock into the map's look: tinted toward the colour of its ore flecks, smooth (or studded when
-- Config.Debris.Rock.Studs is on). Rocks keep their drops and HP; this is paint only.
local function skin(part: BasePart, flecks: { [BasePart]: any })
	local fleck = next(flecks)
	if fleck then
		part.Color = part.Color:Lerp(fleck.Color, Config.Debris.Rock.TintMix)
	end
	if Config.Debris.Rock.Studs then
		part.Material = Enum.Material.Plastic
		StudSkin.apply(part)
	else
		part.Material = Enum.Material.SmoothPlastic
	end
end

function DebrisService:_track(part: BasePart)
	-- only the ore flecks are tinted by tier; other children (rock chunks) keep their colour
	local flecks = {}
	for _, child in part:GetDescendants() do
		if child:IsA("BasePart") and child.Name == "OreFleck" then
			flecks[child] = { Color = child.Color, Material = child.Material }
		end
	end
	skin(part, flecks)

	-- The field a rock stands in (its Field attribute) decides its hits and what it pays
	local reward = DebrisField.reward(part:GetAttribute("Field"))
	local hits = DebrisField.hits(reward)
	local rock: Rock
	local id = NodeService:Register(part, {
		Kind = "Debris",
		MaxHp = hits,
		Ore = Config.Debris.Ore,
		OreMult = Config.Debris.YieldFraction,
		-- Filler always drops the default ore (the tier tint only shows how tough a rock is). A field's rock
		-- drops its field's ore at the breaker's level, or none when it pays cash.
		OreFor = function(player: Player)
			if not reward then
				return DebrisOre.forTier(part:GetAttribute("Tier") :: number?), Config.Debris.YieldFraction
			end
			local data = PlayerStateService:Get(player)
			local share = if reward.Ore then Levels.oreYield(if data then data.level else 1, reward.Ore) else 1
			return DebrisField.ore(reward, share)
		end,
		OnBroken = function(player: Player)
			if reward then
				self:_payCash(player, reward)
			end
			setVisible(part, false)
			task.delay(math.random(Config.Debris.RespawnMin, Config.Debris.RespawnMax), function()
				if part.Parent then
					size(rock, pickPickaxe())
					setVisible(part, true)
				end
			end)
		end,
	})
	rock = { Part = part, Id = id, Reward = reward, Hits = hits, Flecks = flecks }
	size(rock, pickPickaxe())
	table.insert(rocks, rock)
end

-- A cash rock pays the player who broke it a stretch of their own expected income, so it is as big as
-- their setup is and a veteran can't farm a field of newcomer-sized rocks.
function DebrisService:_payCash(player: Player, reward: DebrisField.Reward)
	local data = PlayerStateService:Get(player)
	if not data then
		return
	end
	local cash = DebrisField.cash(reward, EconomyService:ExpectedIncome(player).perSecond, Rebirth.cost(data.rebirths))
	if cash > 0 then
		PlayerStateService:AddCash(player, cash)
		RewardService:Bonus(player, "fieldCash", "+" .. Format.cash(cash))
	end
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
	PlayerStateService = Knit.GetService("PlayerStateService")
	EconomyService = Knit.GetService("EconomyService")
	RewardService = Knit.GetService("RewardService")
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
