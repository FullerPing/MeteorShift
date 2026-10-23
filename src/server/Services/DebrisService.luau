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
--
-- A field may be locked behind a level or a rebirth count (Shared.FieldGate). The server is the gate: a locked
-- field's rocks refuse the player's swings and pets (NodeService CanHit), ORE travel there is refused, and anyone
-- standing on its floor is put back at its Entrance. The gate models on the map are the client's picture of it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WorldMap = require(ReplicatedStorage.Shared.WorldMap)
local Knit = require(ReplicatedStorage.Packages.Knit)
local Signal = require(ReplicatedStorage.Packages.Signal)
local Config = require(ReplicatedStorage.Shared.Config)
local DebrisField = require(ReplicatedStorage.Shared.DebrisField)
local DebrisOre = require(ReplicatedStorage.Shared.DebrisOre)
local FieldGate = require(ReplicatedStorage.Shared.FieldGate)
local FieldTravel = require(ReplicatedStorage.Shared.FieldTravel)
local Format = require(ReplicatedStorage.Shared.Format)
local Levels = require(ReplicatedStorage.Shared.Levels)
local Rebirth = require(ReplicatedStorage.Shared.Rebirth)
local RequestGate = require(ReplicatedStorage.Shared.RequestGate)
local StudSkin = require(ReplicatedStorage.Shared.StudSkin)
local SafeLoop = require(script.Parent.Parent.Lib.SafeLoop)

local DebrisService = Knit.CreateService({
	Name = "DebrisService",
	Client = {},
})

-- (player: Player, field: string) a rock was broken; field is its ore field's id, or "Filler" outside the fields
DebrisService.RockBroken = Signal.new()

local lastTravel: { [Player]: number } = {}
local lastRefusal: { [Player]: number } = {} -- the last "this field is locked" notice, so swings don't spam it
local warnedNoGates = false

local NodeService
local ActivityService
local PlayerStateService
local EconomyService
local RewardService
local TelemetryService

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
	local gated = FieldTravel.find(part:GetAttribute("Field"))
	local rock: Rock
	local id = NodeService:Register(part, {
		Kind = "Debris",
		CanHit = if gated and gated.Unlock then function(player: Player) return self:IsFieldOpen(player, gated.Id) end else nil,
		OnRefused = if gated and gated.Unlock then function(player: Player)
			local now = os.clock()
			if lastRefusal[player] and now - lastRefusal[player] < 3 then return end
			lastRefusal[player] = now
			RewardService:Bonus(player, "locked", gated.Name .. " opens at " .. FieldGate.label(gated))
		end else nil,
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
				self:_payCash(player, reward, rock)
			end
			local field = part:GetAttribute("Field")
			self.RockBroken:Fire(player, if reward and type(field) == "string" then field else "Filler")
			setVisible(part, false)
			task.delay(DebrisField.respawnSeconds(#Players:GetPlayers(), math.random()), function()
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

-- A cash rock pays the player who broke it a stretch of their own expected income, cut to the share of
-- their pickaxe the rock was sized for (DebrisField.sizedShare): a veteran one-shotting a rock sized for a
-- newcomer earns that small share, not seconds of their own big income.
function DebrisService:_payCash(player: Player, reward: DebrisField.Reward, rock: Rock)
	local data = PlayerStateService:Get(player)
	if not data then
		return
	end
	local _, maxHp = NodeService:GetHp(rock.Id)
	local pickaxe = PlayerStateService:GetPickaxe(player)
	local share = DebrisField.sizedShare(maxHp, rock.Hits, pickaxe.Power)
	local cash = DebrisField.cash(reward, EconomyService:ExpectedIncome(player).perSecond * share, Rebirth.cost(data.rebirths), pickaxe.Swing)
	if cash > 0 then
		PlayerStateService:AddCash(player, cash)
		TelemetryService:earned(player, "field_cash", cash, 0)
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

-- Whether the ore field `id` is open to the player (their saved level and rebirths). A gated field on a map
-- without its Gates folder stays locked (fail closed, warned once): a missing folder must not open every gate.
function DebrisService:IsFieldOpen(player: Player, id: string): boolean
	local field = FieldTravel.find(id)
	if not field then return false end
	if not field.Unlock then return true end
	local map = WorldMap.find()
	if not (map and map:FindFirstChild("Gates")) then
		if not warnedNoGates then
			warnedNoGates = true
			warn("[DebrisService] Map.Gates is missing: gated ore fields stay locked")
		end
		return false
	end
	local data = PlayerStateService:Get(player)
	return data ~= nil and FieldGate.isOpen(field, data.level or 1, data.rebirths or 0)
end

-- Puts anyone standing on a field that is locked to them back at its Entrance (they walked, slid or were thrown in)
function DebrisService:_ejectLocked()
	local map = WorldMap.find()
	local fields = map and map:FindFirstChild("DebrisFields")
	if not fields then return end
	for _, player in Players:GetPlayers() do
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if not (root and root:IsA("BasePart")) then continue end
		for _, field in Config.Debris.Fields do
			if not field.Unlock then continue end
			local model = fields:FindFirstChild(field.Id)
			local entrance = model and model:FindFirstChild("Entrance")
			if not (entrance and entrance:IsA("BasePart")) then continue end
			-- one FieldFloor per block (Rust and Frost have a block each side of their avenue)
			local inside = false
			for _, floor in (model :: Instance):GetChildren() do
				if floor.Name == "FieldFloor" and floor:IsA("BasePart") then
					local p = floor.CFrame:PointToObjectSpace(root.Position)
					inside = inside or (math.abs(p.X) <= floor.Size.X / 2 + 2 and math.abs(p.Z) <= floor.Size.Z / 2 + 2
						and p.Y >= -floor.Size.Y / 2 - 2 and p.Y <= floor.Size.Y / 2 + 40)
				end
			end
			if inside and not self:IsFieldOpen(player, field.Id) then
				player.Character:PivotTo(entrance.CFrame + Vector3.new(0, 4, 0))
				root.AssemblyLinearVelocity = Vector3.zero
			end
		end
	end
end

-- Teleports a player to an ore field; false when the request is refused.
function DebrisService:TravelTo(player: Player, id: any): boolean
	if not FieldTravel.find(id) then return false end
	if not self:IsFieldOpen(player, id) then return false end
	local character = player.Character
	if not character then return false end
	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not (root and root:IsA("BasePart") and humanoid and humanoid.Health > 0) then return false end
	local spot = self:_fieldSpot(id)
	if not spot then return false end
	character:PivotTo(CFrame.new(spot))
	root.AssemblyLinearVelocity = Vector3.zero
	TelemetryService:custom(player, "field_travel", 1, { id })
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
	TelemetryService = Knit.GetService("TelemetryService")
end

function DebrisService:KnitStart()
	Players.PlayerRemoving:Connect(function(player)
		lastTravel[player] = nil
		lastRefusal[player] = nil
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
			SafeLoop.step("DebrisReroll", function()
				self:_reroll()
			end)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(0.5)
			SafeLoop.step("DebrisEject", function()
				self:_ejectLocked()
			end)
		end
	end)
end

return DebrisService
