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
-- hatched with Core Shards and visible odds/pity. Where PolicyService restricts paid random items,
-- only shards earned in game open eggs (Shared.ShardWallet). Pass pets are fixed
-- entitlements; no purchase can roll a pet or change odds.

local GroupService = game:GetService("GroupService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Signal = require(ReplicatedStorage.Packages.Signal)
local Config = require(ReplicatedStorage.Shared.Config)
local Pets = require(ReplicatedStorage.Shared.Pets)
local Relics = require(ReplicatedStorage.Shared.Relics)
local Perks = require(ReplicatedStorage.Shared.Perks)
local Price = require(ReplicatedStorage.Shared.Price)
local Purchases = require(ReplicatedStorage.Shared.Purchases)
local ShardWallet = require(ReplicatedStorage.Shared.ShardWallet)
local WorldMap = require(ReplicatedStorage.Shared.WorldMap)

local PetService = Knit.CreateService({
	Name = "PetService",
	Client = {
		Notice = Knit.CreateSignal(), -- (text)
		Leveled = Knit.CreateSignal(), -- (petId, level)
		Bought = Knit.CreateSignal(), -- (petId) a pass pet arrived
		Hatched = Knit.CreateSignal(), -- (eggId, petId, duplicate)
		Working = Knit.CreateSignal(), -- (ownerUserId, role, targetPosition?), presentation only
	},
})

PetService.PetBought = Signal.new() -- (player, petId)
PetService.EggHatched = Signal.new() -- (player, eggId, petId, duplicate) after a hatch

local TICK = 0.1
local IDLE_RETRY = 0.4 -- how soon a miner pet looks again when it found nothing in reach
local WORK_RANGE = 150 -- studs: pet work effects only go to players near enough to see them

local PlayerStateService
local NodeService
local MonetizationService
local PlayerPolicyService

-- Per player: when the miner pet swings next, and the fraction of ore the hauler owes
local nextSwing: { [Player]: number } = {}
local haulCarry: { [Player]: number } = {}
local lastRequest: { [Player]: number } = {}
local lastWork: { [Player]: { [string]: number } } = {}
local lastGroupCheck: { [Player]: number } = {}

local function slotsFree(player: Player, data: any): boolean
	return #data.pets.equipped < PlayerStateService:PetSlots(player)
end

function PetService:Work(player: Player, role: string, targetPosition: Vector3?)
	if (PlayerStateService:GetPetBonuses(player)[role] or 0) <= 0 then return end
	local times = lastWork[player] or {}
	lastWork[player] = times
	local now = os.clock()
	if now - (times[role] or 0) < .25 then return end
	times[role] = now
	-- Presentation only, and frequent while mining: send it to the owner and players close by, not the server
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local origin = if root then root.Position else targetPosition
	for _, other in Players:GetPlayers() do
		local otherCharacter = other.Character
		local otherRoot = otherCharacter and otherCharacter:FindFirstChild("HumanoidRootPart") :: BasePart?
		if other == player or (origin and otherRoot and (otherRoot.Position - origin).Magnitude <= WORK_RANGE) then
			self.Client.Working:Fire(other, player.UserId, role, targetPosition)
		end
	end
end

-- Puts a pet out and spends a banked Pet Max on it (Shared.Purchases.applyPetMaxCredit)
function PetService:_putOut(player: Player, data: any, petId: string)
	table.insert(data.pets.equipped, petId)
	local maxed = Purchases.applyPetMaxCredit(data, petId)
	if maxed then
		self.Client.Leveled:Fire(player, petId, maxed)
		self.Client.Notice:Fire(player, "Your saved Pet Max took this pet to max level!")
	end
end

function PetService:Equip(player: Player, petId: string): boolean
	local data = PlayerStateService:Get(player)
	local def = Pets.def(petId)
	if not data or not def or not data.pets.owned[petId] then
		return false
	end
	if Pets.outCount(data.pets.equipped, petId) >= Pets.copies(data.pets.owned[petId]) then
		return false
	end
	if not slotsFree(player, data) then
		self.Client.Notice:Fire(player, string.format("All %d pet slots are in use. Unequip a pet first. Rebirths, Pet Bond and Extra Pet Slot open more.", PlayerStateService:PetSlots(player)))
		return false
	end
	self:_putOut(player, data, petId)
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

-- Fuses a pet (Config.Pets.Fuse): Copies of it and Relic Fragments make it Fused, its perks x Mult. Extra copies that
-- were out and are now used up go back in the bag.
function PetService:Fuse(player: Player, petId: string): boolean
	local data = PlayerStateService:Get(player)
	local def = Pets.def(petId)
	if not data or not def then return false end
	local entry = data.pets.owned[petId]
	local relics = Relics.clean(data.relics)
	if not Pets.canFuse(def, entry, relics.fragments) then return false end
	relics.fragments -= Pets.fuseCost(def) :: number
	data.relics = relics
	Pets.fuse(entry)
	while Pets.outCount(data.pets.equipped, petId) > Pets.copies(entry) do
		table.remove(data.pets.equipped, table.find(data.pets.equipped, petId) :: number)
	end
	self.Client.Notice:Fire(player, def.Name .. " is now Fused: its perks are x" .. Config.Pets.Fuse.Mult .. "!")
	PlayerStateService:ReplicateNow(player)
	return true
end

-- Buys a pet with Core Shards (never random) and puts it out when a slot is free.
-- Hatches an egg for Core Shards. The pet comes from Pets.roll (the egg's published odds plus
-- its pity count); a duplicate is one more copy of the pet you own. Returns the pet id.
function PetService:Hatch(player: Player, eggId: string): string?
	local data = PlayerStateService:Get(player)
	local egg = Pets.egg(eggId)
	if not data or not egg then
		return nil
	end
	if (data.rebirths or 0) < (egg.MinRebirths or 0) then
		self.Client.Notice:Fire(player, string.format("The %s opens at rebirth %d.", egg.Name, egg.MinRebirths or 0))
		return nil
	end
	local shortfall = Price.shortfall(data, 0, egg.Cost, "the " .. egg.Name)
	if shortfall then
		self.Client.Notice:Fire(player, shortfall)
		return nil
	end
	-- Eggs are random: where paid random items are restricted, Robux-bought shards can't open them
	local restricted = not PlayerPolicyService:CanUsePaidRandomItems(player)
	if ShardWallet.forEggs(data, restricted) < egg.Cost then
		self.Client.Notice:Fire(player, string.format(
			"Eggs open with Core Shards earned in game here. You have %d earned shards; the %s needs %d. Bought shards still buy perks and evolves.",
			ShardWallet.earned(data), egg.Name, egg.Cost))
		return nil
	end
	ShardWallet.spend(data, egg.Cost, true)
	local petId, pity = Pets.roll(egg, math.random(), data.pets.hatches[eggId] or 0, math.random())
	data.pets.hatches[eggId] = pity
	local entry = data.pets.owned[petId]
	local duplicate = entry ~= nil
	if entry then
		entry.copies = Pets.copies(entry) + 1
	else
		data.pets.owned[petId] = { level = 1, xp = 0 }
		self.PetBought:Fire(player, petId)
	end
	if slotsFree(player, data) then
		self:_putOut(player, data, petId)
	end
	PlayerStateService:ReplicateNow(player)
	self.Client.Hatched:Fire(player, eggId, petId, duplicate)
	self.EggHatched:Fire(player, eggId, petId, duplicate)
	return petId
end

-- Gives the player every pet whose pass they own and don't have yet (equipped if a slot is
-- free), and takes back a pass pet whose pass Roblox says they no longer own (refunded or revoked;
-- never on a failed lookup). Called when a profile and the passes are known and when a pass is bought.
function PetService:SyncPassPets(player: Player)
	local data = PlayerStateService:Get(player)
	if not data then
		return
	end
	if MonetizationService:PassesResolved(player) then
		data.pets = Pets.clean(data.pets, data.rebirths, MonetizationService:ExtraPetSlots(player) > 0, Perks.petSlots(data.perks))
	end
	for _, def in Config.Pets.List do
		if def.Pass and data.pets.owned[def.Id] and MonetizationService:PassKnownNotOwned(player, def.Pass) then
			data.pets.owned[def.Id] = nil
			local index = table.find(data.pets.equipped, def.Id)
			if index then table.remove(data.pets.equipped, index) end
		end
	end
	for _, def in Config.Pets.List do
		if def.Pass and not data.pets.owned[def.Id] and MonetizationService:HasPass(player, def.Pass) then
			data.pets.owned[def.Id] = { level = 1, xp = 0 }
			if slotsFree(player, data) then
				self:_putOut(player, data, def.Id)
			end
			PlayerStateService:ReplicateNow(player)
			self.Client.Bought:Fire(player, def.Id)
			self.PetBought:Fire(player, def.Id)
		end
	end
	PlayerStateService:ReplicateNow(player)
end

-- Is the player in the game's group (Config.Pets.GroupReward)? `fresh` asks Roblox again (a web call), for someone
-- who joined mid-session; otherwise the membership Roblox cached at join. A failed lookup counts as no.
local function inGroup(player: Player, fresh: boolean): boolean
	local groupId = Config.Pets.GroupReward.GroupId
	if groupId == 0 then
		return false
	end
	local ok, result = pcall(function()
		if not fresh then
			return player:IsInGroup(groupId)
		end
		for _, group in GroupService:GetGroupsAsync(player.UserId) do
			if group.Id == groupId then
				return true
			end
		end
		return false
	end)
	return ok and result == true
end

-- The group reward: a member gets its pet once (equipped if a slot is free). True when they own it afterwards.
function PetService:GiveGroupPet(player: Player, fresh: boolean): boolean
	local data = PlayerStateService:Get(player)
	local petId = Config.Pets.GroupReward.Pet
	if not data then
		return false
	end
	if data.pets.owned[petId] then
		return true
	end
	if not inGroup(player, fresh) then
		return false
	end
	data.pets.owned[petId] = { level = 1, xp = 0 }
	if slotsFree(player, data) then
		self:_putOut(player, data, petId)
	end
	PlayerStateService:ReplicateNow(player)
	self.Client.Bought:Fire(player, petId)
	self.PetBought:Fire(player, petId)
	return true
end

function PetService.Client:ClaimGroupPet(player: Player): boolean
	-- a fresh lookup is a web call: one every 5 s per player
	local now = os.clock()
	if now - (lastGroupCheck[player] or -math.huge) < 5 then
		return false
	end
	lastGroupCheck[player] = now
	return self.Server:GiveGroupPet(player, true)
end

-- Every equipped pet earns XP from one validated hit of the owner's (copies share one level, so once per pet).
function PetService:_award(player: Player, kind: string)
	local xp = Config.Pets.XpPerHit[kind]
	local data = PlayerStateService:Get(player)
	if not xp or not data then
		return
	end
	local seen: { [string]: boolean } = {}
	for _, petId in PlayerStateService:GetActivePets(player) do
		local entry = data.pets.owned[petId]
		if entry and not seen[petId] then
			seen[petId] = true
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
			if moved > 0 then self:Work(player, "hauler") end
			carry = if moved < whole then 0 else carry - whole -- nothing to carry: don't bank it
		end
		haulCarry[player] = carry
	end

	-- Miner: one hit per swing at the nearest target in reach, while the owner is active
	if bonuses.miner > 0 and now >= (nextSwing[player] or 0) then
		local pickaxe = PlayerStateService:GetPickaxe(player)
		local root = rootOf(player)
		local mining = Pets.minerActive(NodeService:GetLastSwing(player), now)
		local id = if root and mining then NodeService:NearestTarget(root.Position, pickaxe.Reach, player) else nil
		local targetPosition = if id then NodeService:TargetPosition(id) else nil
		if id and NodeService:PetHit(player, id, bonuses.miner) then
			self:Work(player, "miner", targetPosition)
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

function PetService.Client:Fuse(player: Player, petId: string): boolean
	if typeof(petId) ~= "string" or throttled(player) then
		return false
	end
	return self.Server:Fuse(player, petId)
end

function PetService.Client:Hatch(player: Player, eggId: string): string?
	if typeof(eggId) ~= "string" or throttled(player) then
		return nil
	end
	return self.Server:Hatch(player, eggId)
end

-- Eggs hatch at the Hatchery (Map.TownSquare.Hatchery.<eggId>): one prompt on each egg's plinth
function PetService:_connectHatchery()
	local townSquare = WorldMap.wait():FindFirstChild("TownSquare")
	local hatchery = if townSquare then townSquare:FindFirstChild("Hatchery") else nil
	if not hatchery then
		warn("[PetService] Map.TownSquare.Hatchery is missing; eggs can't be hatched")
		return
	end
	for _, egg in Config.Pets.Eggs do
		local stand = hatchery:FindFirstChild(egg.Id)
		local anchor = stand and (stand:FindFirstChild("Plinth") or stand:FindFirstChildWhichIsA("BasePart", true))
		if not (anchor and anchor:IsA("BasePart")) then
			warn("[PetService] the Hatchery has no stand for " .. egg.Id)
			continue
		end
		local prompt = anchor:FindFirstChildWhichIsA("ProximityPrompt") or Instance.new("ProximityPrompt")
		prompt.Name = "HatchPrompt"
		prompt.ActionText = "Hatch (" .. egg.Cost .. " shards)"
		prompt.ObjectText = egg.Name
		prompt.HoldDuration = 0.25
		prompt.MaxActivationDistance = 12
		prompt.RequiresLineOfSight = false
		prompt.Parent = anchor
		prompt.Triggered:Connect(function(player)
			if not throttled(player) then self:Hatch(player, egg.Id) end
		end)
	end
end

function PetService:KnitInit()
	PlayerStateService = Knit.GetService("PlayerStateService")
	NodeService = Knit.GetService("NodeService")
	MonetizationService = Knit.GetService("MonetizationService")
	PlayerPolicyService = Knit.GetService("PlayerPolicyService")
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
			self:GiveGroupPet(player, false)
		end)
	end)
	MonetizationService.PassBought:Connect(function(player: Player)
		self:SyncPassPets(player)
	end)
	task.spawn(function() self:_connectHatchery() end)
	MonetizationService.PassesReady:Connect(function(player: Player) self:SyncPassPets(player) end)
	NodeService.Hit:Connect(function(player: Player, kind: string, part: BasePart)
		self:_award(player, kind)
		for _, role in { "yield", "swift", "pack" } do self:Work(player, role, part.Position) end
	end)
	Knit.GetService("EconomyService").BarsSold:Connect(function(player) self:Work(player, "merchant") end)
	Knit.GetService("RefineryService").OreDeposited:Connect(function(player) self:Work(player, "vault") end)
	Knit.GetService("RefineryService").BarsCollected:Connect(function(player) self:Work(player, "vault") end)

	Players.PlayerRemoving:Connect(function(player)
		nextSwing[player] = nil
		haulCarry[player] = nil
		lastRequest[player] = nil
		lastWork[player] = nil
		lastGroupCheck[player] = nil
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
