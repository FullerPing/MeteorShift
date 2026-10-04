--!strict
-- Pickaxe and backpack upgrades (spec §7.1, §7.2, reworked): one of each for the whole
-- game. Stats level up with cash; evolving to the next tier (cash, and Core Shards at the
-- top tiers) raises their cap (Shared.Gear). The server checks the cap and the price.
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

local Knit = require(ReplicatedStorage.Packages.Knit)
local Signal = require(ReplicatedStorage.Packages.Signal)
local Config = require(ReplicatedStorage.Shared.Config)
local Price = require(ReplicatedStorage.Shared.Price)
local EquipmentModels = require(ReplicatedStorage.Shared.EquipmentModels)
local Gear = require(ReplicatedStorage.Shared.Gear)
local Levels = require(ReplicatedStorage.Shared.Levels)

local ShopService = Knit.CreateService({
	Name = "ShopService",
	Client = {
		Purchased = Knit.CreateSignal(), -- (kind, tier) when an item evolves
		Upgraded = Knit.CreateSignal(), -- (kind, stat, level) when a stat levels up
		Notice = Knit.CreateSignal(), -- (text)
		Open = Knit.CreateSignal(), -- () the player used the shop in town
	},
})

ShopService.ItemBought = Signal.new() -- (player, kind, tier) when an item evolves
ShopService.StatUpgraded = Signal.new() -- (player, kind, stat, level, cash) when a stat levels up

export type Kind = "pickaxe" | "backpack"

type Item = { Tier: number, Name: string, Cost: number, Shards: number }

local CATALOG: { [string]: { List: { Item }, Key: string } } = {
	pickaxe = { List = Config.Pickaxes :: any, Key = "pickaxeTier" },
	backpack = { List = Config.Backpacks :: any, Key = "backpackTier" },
}

local PlayerStateService

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

local STATS_KEY = { pickaxe = "pickaxeStats", backpack = "backpackStats" }

-- Evolves the pickaxe or backpack to its next tier (Shared.Gear): the Gate stat has to be at
-- the tier's cap, then it costs the next tier's cash and Core Shards. Returns true when it went
-- through. Stat levels stay as they are; the new tier raises their cap.
function ShopService:Evolve(player: Player, kind: Kind): boolean
	local entry = CATALOG[kind]
	local data = PlayerStateService:Get(player)
	if not entry or not data then
		return false
	end
	local current = data[entry.Key] :: number
	local evolution = Gear.evolution(kind, current, data[STATS_KEY[kind]])
	if not evolution then
		self.Client.Notice:Fire(player, "Your " .. kind .. " is already fully evolved.")
		return false
	end
	local item = entry.List[evolution.tier]
	if not evolution.ready then
		local gate = Config.Gear[if kind == "pickaxe" then "Pickaxe" else "Backpack"]
		self.Client.Notice:Fire(player, string.format("Level %s to %d before evolving to the %s.", string.lower(gate.Names[gate.Gate]), Gear.cap(current), item.Name))
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
	data.shards -= evolution.shards
	data[entry.Key] = evolution.tier
	self:ApplyPickaxe(player)
	PlayerStateService:ReplicateNow(player)
	self.Client.Purchased:Fire(player, kind, evolution.tier)
	self.ItemBought:Fire(player, kind, evolution.tier)
	return true
end

-- Buys one level of a stat (Shared.Gear) for cash, up to the tier's cap.
function ShopService:UpgradeStat(player: Player, kind: Kind, stat: string): boolean
	local entry = CATALOG[kind]
	local data = PlayerStateService:Get(player)
	if not entry or not data then
		return false
	end
	local stats = data[STATS_KEY[kind]]
	local level = stats[stat]
	if type(level) ~= "number" then
		return false
	end
	local tier = data[entry.Key] :: number
	if not Gear.canLevel(kind, tier, level) then
		local upcoming = entry.List[tier + 1]
		self.Client.Notice:Fire(player, if upcoming then "Evolve to the " .. upcoming.Name .. " to keep leveling this." else "Fully upgraded.")
		return false
	end
	local price = Gear.price(kind, stat, level)
	if not price then
		return false
	end
	local shortfall = Price.shortfall(data, price, 0, "this upgrade")
	if shortfall then
		self.Client.Notice:Fire(player, shortfall)
		return false
	end

	data.cash -= price
	stats[stat] = level + 1
	if kind == "pickaxe" then
		self:ApplyPickaxe(player) -- the tool tip shows the stats
	end
	PlayerStateService:ReplicateNow(player)
	self.Client.Upgraded:Fire(player, kind, stat, level + 1)
	self.StatUpgraded:Fire(player, kind, stat, level + 1, price)
	return true
end

function ShopService.Client:Evolve(player: Player, kind: Kind): boolean
	if typeof(kind) ~= "string" or not CATALOG[kind] then
		return false
	end
	return self.Server:Evolve(player, kind)
end

function ShopService.Client:Upgrade(player: Player, kind: Kind, stat: string): boolean
	if typeof(kind) ~= "string" or not CATALOG[kind] or typeof(stat) ~= "string" then
		return false
	end
	return self.Server:UpgradeStat(player, kind, stat)
end

function ShopService:_connectTownShop()
	local townSquare = workspace:WaitForChild("Map"):FindFirstChild("TownSquare")
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

	-- StarterPack hands out a fresh Basic Pickaxe on every spawn; restyle it
	local function watch(player: Player)
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
		player.DescendantAdded:Connect(added)
		local function characterAdded(character: Model)
			task.spawn(function()
				local torso = character:WaitForChild("UpperTorso", 3) or character:FindFirstChild("Torso")
				if torso and player.Character == character and PlayerStateService:Get(player) then
					self:ApplyPickaxe(player)
				end
			end)
			character.DescendantAdded:Connect(added)
			for _, descendant in character:GetChildren() do
				added(descendant)
			end
		end
		player.CharacterAdded:Connect(characterAdded)
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
	end)

	task.spawn(self._connectTownShop, self)
end

return ShopService
