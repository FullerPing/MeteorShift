--!strict
-- Mineral index (spec §8.2): rare minerals from meteor hits, kept in the profile's
-- `index` (mineral id -> count found), and the page rewards.
--
-- Every validated hit on a meteor's crust or core rolls the meteor type's page
-- (Shared.MineralIndex.roll) at the fixed odds in Config.Index, for players whose
-- own pickaxe meets the meteor's RequiredTier only (spec §8.1). Debris never rolls.
-- The rarest mineral of a page needs a rich crust node (MeteorService marks them
-- with a Rich attribute). Nothing purchasable changes the odds: 2x Ore doubles ore,
-- never minerals (spec §9.4). The one thing that moves them is play: after a long streak
-- without finding a mineral you don't have, those minerals' odds rise (Shared.Hooks.pityMult).
--
-- A completed page is announced to the server; it adds its bonus to bar sales
-- (EconomyService:SaleMultiplier) and its title. The player's best title is kept in
-- their Title attribute, set again from the saved index when they join.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Config = require(ReplicatedStorage.Shared.Config)
local Hooks = require(ReplicatedStorage.Shared.Hooks)
local MineralIndex = require(ReplicatedStorage.Shared.MineralIndex)

local IndexService = Knit.CreateService({
	Name = "IndexService",
	Client = {
		-- (mineralId, count, isNew) to the finder; count is their total of that mineral
		Discovered = Knit.CreateSignal(),
	},
})

local PlayerStateService
local MeteorService
local RewardService

-- Validated hits since the player last found a mineral they didn't have (soft pity, not saved)
local dryHits: { [Player]: number } = {}

local random = Random.new()
local function roll(): number
	return random:NextNumber()
end

-- Sets the Title attribute to the best title the player's index has earned.
local function applyTitle(player: Player, index: MineralIndex.PlayerIndex)
	local titles = MineralIndex.titles(index)
	player:SetAttribute("Title", titles[#titles])
end

-- One validated hit: maybe a mineral for the index.
function IndexService:_onHit(player: Player, kind: string, part: BasePart)
	if kind ~= "Crust" and kind ~= "Core" then
		return -- debris never drops minerals
	end
	local meteorType = MeteorService:GetActiveType()
	local page = meteorType and Config.Index.Pages[meteorType.Id]
	if not meteorType or not page then
		return
	end
	-- Only your own pickaxe unlocks a meteor's minerals (spec §8.1)
	if PlayerStateService:GetPickaxe(player).Tier < meteorType.RequiredTier then
		return
	end
	local data = PlayerStateService:Get(player)
	if not data then
		return
	end
	local dry = (dryHits[player] or 0) + 1
	dryHits[player] = dry
	local mineralId = MineralIndex.roll(page.Id, part:GetAttribute("Rich") == true, roll, data.index, Hooks.pityMult(dry))
	if mineralId then
		if (data.index[mineralId] or 0) == 0 then
			dryHits[player] = 0
		end
		self:Award(player, mineralId)
	end
end

-- Adds one `mineralId` to the player's index and tells them; a first find that
-- completes its page is announced and updates their title.
function IndexService:Award(player: Player, mineralId: string)
	local data = PlayerStateService:Get(player)
	local _, page = MineralIndex.find(mineralId)
	if not data or not page then
		return
	end
	local count = (data.index[mineralId] or 0) + 1
	data.index[mineralId] = count
	local isNew = count == 1
	PlayerStateService:Replicate(player)
	self.Client.Discovered:Fire(player, mineralId, count, isNew)

	if isNew and MineralIndex.pageComplete(data.index, page.Id) then
		RewardService:Announce("Index", string.format("%s completed the %s page!", player.DisplayName, page.Name))
		applyTitle(player, data.index)
	end
end

function IndexService:KnitInit()
	PlayerStateService = Knit.GetService("PlayerStateService")
	MeteorService = Knit.GetService("MeteorService")
	RewardService = Knit.GetService("RewardService")
end

function IndexService:KnitStart()
	local DataService = Knit.GetService("DataService")
	local NodeService = Knit.GetService("NodeService")

	local function restoreTitle(player: Player)
		local data = PlayerStateService:Get(player)
		if data then
			applyTitle(player, data.index)
		end
	end
	DataService.ProfileLoaded:Connect(restoreTitle)
	for _, player in Players:GetPlayers() do
		restoreTitle(player) -- profiles loaded before this service started
	end

	Players.PlayerRemoving:Connect(function(player)
		dryHits[player] = nil
	end)

	NodeService.Hit:Connect(function(player: Player, kind: string, part: BasePart)
		self:_onHit(player, kind, part)
	end)
end

return IndexService
