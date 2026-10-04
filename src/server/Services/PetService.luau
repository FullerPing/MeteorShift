--!strict
-- Pets (Shared.Pets, Config.Pets): owning, equipping, levelling and what they do.
--
--   miner     every swing of your pickaxe it hits the nearest target in your reach with
--             25% to 40% of your Mining Power and ore (NodeService:PetHit); the ore goes
--             straight to the hopper. It only works while you are mining (a validated swing
--             of yours in the last Config.Pets.MinerWindow seconds) with a target in reach,
--             so it can't farm while you are idle.
--   hauler    moves a share of your backpack capacity to the hopper every second
--   pack, swift, merchant: applied where capacity, swing and sales are computed
--             (PlayerStateService, EconomyService)
--
-- Pets level on your own validated hits (Config.Pets.XpPerHit), never on a pet's. Pets are
-- never random: the starter pet is free and the rest cost Core Shards.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Signal = require(ReplicatedStorage.Packages.Signal)
local Config = require(ReplicatedStorage.Shared.Config)
local Pets = require(ReplicatedStorage.Shared.Pets)
local Price = require(ReplicatedStorage.Shared.Price)

local PetService = Knit.CreateService({
	Name = "PetService",
	Client = {
		Notice = Knit.CreateSignal(), -- (text)
		Leveled = Knit.CreateSignal(), -- (petId, level)
		Bought = Knit.CreateSignal(), -- (petId) a pass pet arrived
		Hatched = Knit.CreateSignal(), -- (eggId, petId, duplicate)
	},
})

PetService.PetBought = Signal.new() -- (player, petId)

local TICK = 0.1
local IDLE_RETRY = 0.4 -- how soon a miner pet looks again when it found nothing in reach

local PlayerStateService
local NodeService
local MonetizationService

-- Per player: when the miner pet swings next, and the fraction of ore the hauler owes
local nextSwing: { [Player]: number } = {}
local haulCarry: { [Player]: number } = {}
local lastRequest: { [Player]: number } = {}

local function slotsFree(data: any): boolean
	return #data.pets.equipped < Pets.slots(data.rebirths)
end

function PetService:Equip(player: Player, petId: string): boolean
	local data = PlayerStateService:Get(player)
	local def = Pets.def(petId)
	if not data or not def or not data.pets.owned[petId] then
		return false
	end
	if table.find(data.pets.equipped, petId) then
		return false
	end
	if not slotsFree(data) then
		self.Client.Notice:Fire(player, string.format("All %d pet slots are in use. Unequip a pet first. Rebirths open more.", Pets.slots(data.rebirths)))
		return false
	end
	table.insert(data.pets.equipped, petId)
	PlayerStateService:ReplicateNow(player)
	return true
end

function PetService:Unequip(player: Player, petId: string): boolean
	local data = PlayerStateService:Get(player)
	if not data then
		return false
	end
	local index = table.find(data.pets.equipped, petId)
	if not index then
		return false
	end
	table.remove(data.pets.equipped, index)
	PlayerStateService:ReplicateNow(player)
	return true
end

-- Buys a pet with Core Shards (never random) and puts it out when a slot is free.
-- Hatches an egg for Core Shards. The pet comes from Pets.roll (the egg's published odds plus
-- its pity count); a duplicate gives DuplicateXp to the pet you own. Returns the pet id.
function PetService:Hatch(player: Player, eggId: string): string?
	local data = PlayerStateService:Get(player)
	local egg = Pets.egg(eggId)
	if not data or not egg then
		return nil
	end
	local shortfall = Price.shortfall(data, 0, egg.Cost, "the " .. egg.Name)
	if shortfall then
		self.Client.Notice:Fire(player, shortfall)
		return nil
	end
	data.shards -= egg.Cost
	local petId, pity = Pets.roll(egg, math.random(), data.pets.hatches[eggId] or 0, math.random())
	data.pets.hatches[eggId] = pity
	local entry = data.pets.owned[petId]
	local duplicate = entry ~= nil
	if entry then
		Pets.addXp(entry, Config.Pets.DuplicateXp)
	else
		data.pets.owned[petId] = { level = 1, xp = 0 }
		if slotsFree(data) then
			table.insert(data.pets.equipped, petId)
		end
		self.PetBought:Fire(player, petId)
	end
	PlayerStateService:ReplicateNow(player)
	self.Client.Hatched:Fire(player, eggId, petId, duplicate)
	return petId
end

-- Gives the player every pet whose pass they own and don't have yet (equipped if a slot is
-- free). Called when a profile and the passes are known and when a pass is bought.
function PetService:SyncPassPets(player: Player)
	local data = PlayerStateService:Get(player)
	if not data then
		return
	end
	for _, def in Config.Pets.List do
		if def.Pass and not data.pets.owned[def.Id] and MonetizationService:HasPass(player, def.Pass) then
			data.pets.owned[def.Id] = { level = 1, xp = 0 }
			if slotsFree(data) then
				table.insert(data.pets.equipped, def.Id)
			end
			PlayerStateService:ReplicateNow(player)
			self.Client.Bought:Fire(player, def.Id)
			self.PetBought:Fire(player, def.Id)
		end
	end
end

-- Every equipped pet earns XP from one validated hit of the owner's.
function PetService:_award(player: Player, kind: string)
	local xp = Config.Pets.XpPerHit[kind]
	local data = PlayerStateService:Get(player)
	if not xp or not data then
		return
	end
	for _, petId in data.pets.equipped do
		local entry = data.pets.owned[petId]
		if entry then
			local gained = Pets.addXp(entry, xp)
			if gained > 0 then
				self.Client.Leveled:Fire(player, petId, entry.level)
			end
		end
	end
	PlayerStateService:Replicate(player)
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if root and humanoid and humanoid.Health > 0 then
		return root
	end
	return nil
end

function PetService:_tickPlayer(player: Player, now: number, dt: number)
	local data = PlayerStateService:Get(player)
	if not data or #data.pets.equipped == 0 then
		return
	end
	local bonuses = PlayerStateService:GetPetBonuses(player)

	-- Hauler: a share of the backpack's capacity to the hopper each second
	if bonuses.hauler > 0 then
		local carry = (haulCarry[player] or 0) + PlayerStateService:GetCapacity(player) * bonuses.hauler * dt
		local whole = math.floor(carry)
		if whole >= 1 then
			local moved = PlayerStateService:MoveBackpackToHopper(player, whole)
			carry = if moved < whole then 0 else carry - whole -- nothing to carry: don't bank it
		end
		haulCarry[player] = carry
	end

	-- Miner: one hit per swing at the nearest target in reach, while the owner is active
	if bonuses.miner > 0 and now >= (nextSwing[player] or 0) then
		local pickaxe = PlayerStateService:GetPickaxe(player)
		local root = rootOf(player)
		local mining = now - NodeService:GetLastSwing(player) <= Config.Pets.MinerWindow
		local id = if root and mining then NodeService:NearestTarget(root.Position, pickaxe.Reach, player) else nil
		if id and NodeService:PetHit(player, id, bonuses.miner) then
			nextSwing[player] = now + pickaxe.Swing
		else
			nextSwing[player] = now + IDLE_RETRY
		end
	end
end

local function throttled(player: Player): boolean
	local now = os.clock()
	if now - (lastRequest[player] or 0) < 0.15 then
		return true
	end
	lastRequest[player] = now
	return false
end

function PetService.Client:Equip(player: Player, petId: string): boolean
	if typeof(petId) ~= "string" or throttled(player) then
		return false
	end
	return self.Server:Equip(player, petId)
end

function PetService.Client:Unequip(player: Player, petId: string): boolean
	if typeof(petId) ~= "string" or throttled(player) then
		return false
	end
	return self.Server:Unequip(player, petId)
end

function PetService.Client:Hatch(player: Player, eggId: string): string?
	if typeof(eggId) ~= "string" or throttled(player) then
		return nil
	end
	return self.Server:Hatch(player, eggId)
end

function PetService:KnitInit()
	PlayerStateService = Knit.GetService("PlayerStateService")
	NodeService = Knit.GetService("NodeService")
	MonetizationService = Knit.GetService("MonetizationService")
end

function PetService:KnitStart()
	-- A pass pet is yours whenever you own its pass: on join (once the passes resolve) and on purchase
	Knit.GetService("DataService").ProfileLoaded:Connect(function(player: Player)
		task.spawn(function()
			MonetizationService:WaitForPasses(player)
			for _ = 1, 10 do -- the state may build a moment after the profile loads
				if PlayerStateService:Get(player) or not player.Parent then
					break
				end
				task.wait(0.5)
			end
			self:SyncPassPets(player)
		end)
	end)
	MonetizationService.PassBought:Connect(function(player: Player)
		self:SyncPassPets(player)
	end)
	NodeService.Hit:Connect(function(player: Player, kind: string)
		self:_award(player, kind)
	end)

	Players.PlayerRemoving:Connect(function(player)
		nextSwing[player] = nil
		haulCarry[player] = nil
		lastRequest[player] = nil
	end)

	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(TICK)
			local now = os.clock()
			local dt = now - last
			last = now
			for _, player in Players:GetPlayers() do
				local ok, err = pcall(self._tickPlayer, self, player, now, dt)
				if not ok then
					warn("[PetService] tick failed:", err)
				end
			end
		end
	end)
end

return PetService
