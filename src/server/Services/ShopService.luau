--!strict
-- Pickaxe and backpack upgrades (spec §7.1, §7.2, reworked): one of each for the whole
-- game. Each has a single level that goes up with cash; evolving to the next tier (cash, and
-- Core Shards at the top tiers) raises its cap (Shared.Gear). Cash prices carry the player's
-- rebirth price inflation (Shared.Rebirth.priceMult). The server checks the cap and the price.
-- Plot station upgrades are UpgradeService.
--
-- The shop opens from the HUD. A Pickaxe Shop saved in the town square opens it too
-- (Workspace.Map.TownSquare.PickaxeShop: its ProximityPrompt, or one made on its
-- ShopPoint part if none was saved); the current map has none.
--
-- The Pickaxe tool keeps its original handle, grip and input bindings while
-- EquipmentModels gives each purchased tier its own visible geometry.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPack = game:GetService("StarterPack")

local WorldMap = require(ReplicatedStorage.Shared.WorldMap)
local Knit = require(ReplicatedStorage.Packages.Knit)
local Signal = require(ReplicatedStorage.Packages.Signal)
local Config = require(ReplicatedStorage.Shared.Config)
local Price = require(ReplicatedStorage.Shared.Price)
local Format = require(ReplicatedStorage.Shared.Format)
local Rebirth = require(ReplicatedStorage.Shared.Rebirth)
local EquipmentModels = require(ReplicatedStorage.Shared.EquipmentModels)
local Gear = require(ReplicatedStorage.Shared.Gear)
local Levels = require(ReplicatedStorage.Shared.Levels)
local RequestGate = require(ReplicatedStorage.Shared.RequestGate)
local ShardWallet = require(ReplicatedStorage.Shared.ShardWallet)

local ShopService = Knit.CreateService({
	Name = "ShopService",
	Client = {
		Purchased = Knit.CreateSignal(), -- (kind, tier) when an item evolves
		Upgraded = Knit.CreateSignal(), -- (kind, level) when an item levels up
		Notice = Knit.CreateSignal(), -- (text)
		Open = Knit.CreateSignal(), -- () the player used the shop in town
	},
})

ShopService.ItemBought = Signal.new() -- (player, kind, tier) when an item evolves
ShopService.StatUpgraded = Signal.new() -- (player, kind, level, cash) when an item levels up

export type Kind = "pickaxe" | "backpack"

type Item = { Tier: number, Name: string, Cost: number, Shards: number }

local CATALOG: { [string]: { List: { Item }, Key: string } } = {
	pickaxe = { List = Config.Pickaxes :: any, Key = "pickaxeTier" },
	backpack = { List = Config.Backpacks :: any, Key = "backpackTier" },
}

local PlayerStateService
local lastUpgradeRequest: { [Player]: number } = {}
local lastEvolveRequest: { [Player]: number } = {}
-- The per-player and per-character connections watch() makes, dropped on leave / respawn
local playerConnections: { [Player]: { RBXScriptConnection } } = {}
local characterConnection: { [Player]: RBXScriptConnection } = {}

local function styleTool(tool: Tool, pickaxe: typeof(Config.Pickaxes[1]))
	tool.Name = pickaxe.Name
	tool.ToolTip = string.format("%s · %d ore per hit", pickaxe.Name, pickaxe.OrePerHit)
	tool:SetAttribute("Tier", pickaxe.Tier)
	EquipmentModels.applyToTool(tool, pickaxe.Tier)
end

local function isPickaxe(instance: Instance): boolean
	return instance:IsA("Tool") and instance:GetAttribute("Pickaxe") ~= nil
end

-- Restyles the player's pickaxe wherever it is (backpack or in hand).
function ShopService:ApplyPickaxe(player: Player)
	local pickaxe = PlayerStateService:GetPickaxe(player)
	local data = PlayerStateService:Get(player)
	if data and player.Character then
		EquipmentModels.applyToCharacter(player.Character, data.backpackTier)
	end
	for _, container in { player:FindFirstChildOfClass("Backpack"), player.Character } do
		if container then
			for _, child in (container :: Instance):GetChildren() do
				if isPickaxe(child) then
					styleTool(child :: Tool, pickaxe)
				end
			end
		end
	end
end

local LEVEL_KEY = { pickaxe = "pickaxeLevel", backpack = "backpackLevel" }

-- Evolves the pickaxe or backpack to its next tier (Shared.Gear): the level has to be at
-- the tier's cap, then it costs the next tier's cash and Core Shards. Returns true when it went
-- through. The new tier starts over at level 1 and has more levels.
function ShopService:Evolve(player: Player, kind: Kind): boolean
	local entry = CATALOG[kind]
	local data = PlayerStateService:Get(player)
	if not entry or not data then
		return false
	end
	local current = data[entry.Key] :: number
	local evolution = Gear.evolution(kind, current, data[LEVEL_KEY[kind]], Rebirth.priceMult(data.rebirths))
	if not evolution then
		self.Client.Notice:Fire(player, "Your " .. kind .. " is already fully evolved.")
		return false
	end
	local item = entry.List[evolution.tier]
	if not evolution.ready then
		self.Client.Notice:Fire(player, string.format("Reach level %d before evolving to the %s.", Gear.cap(current), item.Name))
		return false
	end
	local levelNeeded = Levels.evolveLevel(evolution.tier)
	if data.level < levelNeeded then
		self.Client.Notice:Fire(player, string.format("Reach player level %d to evolve to the %s. Take part in meteors to earn XP.", levelNeeded, item.Name))
		return false
	end
	local shortfall = Price.shortfall(data, evolution.cost, evolution.shards, "the " .. item.Name)
	if shortfall then
		self.Client.Notice:Fire(player, shortfall)
		return false
	end

	data.cash -= evolution.cost
	ShardWallet.spend(data, evolution.shards)
	data[entry.Key] = evolution.tier
	data[LEVEL_KEY[kind]] = Gear.levelsForTier(evolution.tier)
	self:ApplyPickaxe(player)
	PlayerStateService:ReplicateNow(player)
	self.Client.Purchased:Fire(player, kind, evolution.tier)
	self.ItemBought:Fire(player, kind, evolution.tier)
	return true
end

-- Buys up to `count` levels (Shared.Gear) for cash, one at a time, stopping at the tier's cap or
-- when the cash runs out. A notice only explains why nothing at all was bought. The client hears
-- one Upgraded for the whole batch; StatUpgraded still fires per level for the listeners.
function ShopService:UpgradeLevel(player: Player, kind: Kind, count: number?): boolean
	local entry = CATALOG[kind]
	local data = PlayerStateService:Get(player)
	if not entry or not data then
		return false
	end
	local tier = data[entry.Key] :: number
	local priceMult = Rebirth.priceMult(data.rebirths)
	local bought = 0
	for _ = 1, math.max(count or 1, 1) do
		local level = data[LEVEL_KEY[kind]]
		if type(level) ~= "number" then
			break
		end
		if not Gear.canLevel(kind, tier, level) then
			if bought == 0 then
				local upcoming = entry.List[tier + 1]
				self.Client.Notice:Fire(player, if upcoming then "Evolve to the " .. upcoming.Name .. " to keep leveling this." else "Fully upgraded.")
			end
			break
		end
		local price = Gear.price(kind, tier, level, priceMult)
		if not price then
			break
		end
		local shortfall = Price.shortfall(data, price, 0, "this upgrade")
		if shortfall then
			if bought == 0 then
				self.Client.Notice:Fire(player, shortfall)
			end
			break
		end
		data.cash -= price
		data[LEVEL_KEY[kind]] = level + 1
		bought += 1
		self.StatUpgraded:Fire(player, kind, level + 1, price)
	end
	if bought == 0 then
		return false
	end
	if kind == "pickaxe" then
		self:ApplyPickaxe(player) -- the tool tip shows the stats
	end
	PlayerStateService:ReplicateNow(player)
	self.Client.Upgraded:Fire(player, kind, data[LEVEL_KEY[kind]])
	return true
end

function ShopService.Client:Evolve(player: Player, kind: Kind): boolean
	local allowed, stamp = RequestGate.check(lastEvolveRequest[player], os.clock(), 0.15)
	lastEvolveRequest[player] = stamp
	if not allowed then return false end
	if typeof(kind) ~= "string" or not CATALOG[kind] then
		return false
	end
	return self.Server:Evolve(player, kind)
end

-- `count` is how many levels the shop's 1x / 10x / MAX wants in one request (default 1). The
-- server still prices and checks every level, and no tier has more levels than the last one's cap.
function ShopService.Client:Upgrade(player: Player, kind: Kind, count: number?): boolean
	local allowed, stamp = RequestGate.check(lastUpgradeRequest[player], os.clock(), 0.1)
	lastUpgradeRequest[player] = stamp
	if not allowed then return false end
	if typeof(kind) ~= "string" or not CATALOG[kind] then
		return false
	end
	local wanted = 1
	if typeof(count) == "number" and count == count then
		wanted = math.clamp(math.floor(count), 1, Gear.cap(#CATALOG[kind].List))
	end
	return self.Server:UpgradeLevel(player, kind, wanted)
end

function ShopService:_connectTownShop()
	local townSquare = WorldMap.wait():FindFirstChild("TownSquare")
	local shop = if townSquare then townSquare:FindFirstChild("PickaxeShop") else nil
	if not shop then
		return
	end
	local prompt = shop:FindFirstChildWhichIsA("ProximityPrompt", true)
	if not prompt then
		local point = shop:FindFirstChild("ShopPoint", true)
		if not (point and point:IsA("BasePart")) then
			warn("[ShopService] PickaxeShop has no ProximityPrompt or ShopPoint part; the shop only opens from the HUD")
			return
		end
		local made = Instance.new("ProximityPrompt")
		made.ActionText = "Shop"
		made.ObjectText = "Pickaxes & Backpacks"
		made.HoldDuration = 0
		made.MaxActivationDistance = 12
		made.Parent = point
		prompt = made
	end
	(prompt :: ProximityPrompt).Triggered:Connect(function(player)
		self.Client.Open:Fire(player)
	end)
end

function ShopService:KnitInit()
	PlayerStateService = Knit.GetService("PlayerStateService")
end

function ShopService:KnitStart()
	local DataService = Knit.GetService("DataService")
	Players.PlayerRemoving:Connect(function(player)
		lastUpgradeRequest[player] = nil
		lastEvolveRequest[player] = nil
		for _, connection in playerConnections[player] or {} do
			connection:Disconnect()
		end
		playerConnections[player] = nil
		if characterConnection[player] then
			characterConnection[player]:Disconnect()
			characterConnection[player] = nil
		end
	end)

	-- StarterPack hands out a fresh Basic Pickaxe on every spawn; restyle it
	local function watch(player: Player)
		if playerConnections[player] then return end -- PlayerAdded and the startup sweep can both see a player
		local function added(descendant: Instance)
			-- Generated model parts never schedule another restyle. A deferred
			-- call also lets a newly cloned Tool finish receiving its Handle.
			local tool = if isPickaxe(descendant) then descendant
				elseif descendant.Name == "Handle" and descendant.Parent and isPickaxe(descendant.Parent)
				then descendant.Parent else nil
			if tool then
				task.defer(function()
					if tool.Parent and PlayerStateService:Get(player) then
						styleTool(tool :: Tool, PlayerStateService:GetPickaxe(player))
					end
				end)
			end
		end
		local function characterAdded(character: Model)
			task.spawn(function()
				local torso = character:WaitForChild("UpperTorso", 3) or character:FindFirstChild("Torso")
				if torso and player.Character == character and PlayerStateService:Get(player) then
					self:ApplyPickaxe(player)
				end
			end)
			-- Safety net: a spawn that ends up with no pickaxe at all (StarterPack hand-out lost to a
			-- slow load or a quick respawn) gets a fresh one
			task.delay(2, function()
				if player.Character ~= character or not character.Parent or not PlayerStateService:Get(player) then return end
				local backpack = player:FindFirstChildOfClass("Backpack")
				for _, container in { backpack, character } do
					if container then
						for _, child in (container :: Instance):GetChildren() do
							if isPickaxe(child) then return end
						end
					end
				end
				local template = StarterPack:FindFirstChild("Pickaxe")
				if template and backpack then
					template:Clone().Parent = backpack
					self:ApplyPickaxe(player)
				end
			end)
			if characterConnection[player] then characterConnection[player]:Disconnect() end
			characterConnection[player] = character.DescendantAdded:Connect(added)
			for _, descendant in character:GetChildren() do
				added(descendant)
			end
		end
		playerConnections[player] = { player.DescendantAdded:Connect(added), player.CharacterAdded:Connect(characterAdded) }
		if player.Character then
			characterAdded(player.Character)
		end
		if PlayerStateService:Get(player) then
			self:ApplyPickaxe(player)
		end
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	DataService.ProfileLoaded:Connect(function(player)
		self:ApplyPickaxe(player)
		-- profiles converted from the four-stat gear (Lib.GearMigration) hear about the refund once
		local data = PlayerStateService:Get(player)
		local refund = if data and data.flags then data.flags.gearRefund else nil
		if type(refund) == "number" and refund > 0 then
			data.flags.gearRefund = nil
			self.Client.Notice:Fire(player, string.format("Gear upgrades are now one level. You got %s back for the Speed, Reach and Crit levels you bought.", Format.cash(refund)))
		end
	end)

	task.spawn(self._connectTownShop, self)
end

return ShopService
