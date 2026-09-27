--!strict
-- Pickaxe and backpack purchases (spec §7.1, §7.2). Tiers are bought one after
-- another with cash, and Core Shards at the top tiers; the server checks the
-- order and the price. Plot station upgrades are UpgradeService.
--
-- The shop opens from the HUD's SHOP button or from the Pickaxe Shop in the town
-- square (Workspace.Map.TownSquare.PickaxeShop: its ProximityPrompt, or one made
-- on its ShopPoint part if none was saved).
--
-- The Pickaxe tool (StarterPack) is renamed after the tier you own, and parts
-- in it with a Tint attribute take that tier's colour.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Signal = require(ReplicatedStorage.Packages.Signal)
local Config = require(ReplicatedStorage.Shared.Config)
local Price = require(ReplicatedStorage.Shared.Price)

local ShopService = Knit.CreateService({
	Name = "ShopService",
	Client = {
		Purchased = Knit.CreateSignal(), -- (kind, tier)
		Notice = Knit.CreateSignal(), -- (text)
		Open = Knit.CreateSignal(), -- () the player used the shop in town
	},
})

ShopService.ItemBought = Signal.new() -- (player, kind, tier)

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
	for _, part in tool:GetDescendants() do
		if part:IsA("BasePart") and part:GetAttribute("Tint") then
			part.Color = pickaxe.Color
		end
	end
end

local function isPickaxe(instance: Instance): boolean
	return instance:IsA("Tool") and instance:GetAttribute("Pickaxe") ~= nil
end

-- Restyles the player's pickaxe wherever it is (backpack or in hand).
function ShopService:ApplyPickaxe(player: Player)
	local pickaxe = PlayerStateService:GetPickaxe(player)
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

-- Buys the next tier of `kind`. Returns true when the purchase went through.
function ShopService:Buy(player: Player, kind: Kind): boolean
	local entry = CATALOG[kind]
	local data = PlayerStateService:Get(player)
	if not entry or not data then
		return false
	end
	local current = data[entry.Key] :: number
	local item = entry.List[current + 1]
	if not item then
		self.Client.Notice:Fire(player, "You already own the best " .. kind .. ".")
		return false
	end
	local shortfall = Price.shortfall(data, item.Cost, item.Shards, "the " .. item.Name)
	if shortfall then
		self.Client.Notice:Fire(player, shortfall)
		return false
	end

	data.cash -= item.Cost
	data.shards -= item.Shards
	data[entry.Key] = current + 1
	if kind == "pickaxe" then
		self:ApplyPickaxe(player)
	end
	PlayerStateService:Replicate(player)
	self.Client.Purchased:Fire(player, kind, current + 1)
	self.ItemBought:Fire(player, kind, current + 1)
	return true
end

function ShopService.Client:Buy(player: Player, kind: Kind): boolean
	if typeof(kind) ~= "string" or not CATALOG[kind] then
		return false
	end
	return self.Server:Buy(player, kind)
end

function ShopService:_connectTownShop()
	local townSquare = workspace:WaitForChild("Map"):WaitForChild("TownSquare")
	local shop = townSquare:WaitForChild("PickaxeShop", 10)
	if not shop then
		warn("[ShopService] no Map.TownSquare.PickaxeShop; the shop only opens from the HUD")
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
		player.DescendantAdded:Connect(function(descendant)
			if isPickaxe(descendant) and PlayerStateService:Get(player) then
				styleTool(descendant :: Tool, PlayerStateService:GetPickaxe(player))
			end
		end)
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
