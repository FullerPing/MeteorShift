--!strict
-- Player profiles on DataStoreService with a session lock (spec §12.4).
--
-- * Load: UpdateAsync claims the profile for this server. If another live server
--   holds the lock we retry for a while, then take over once the lock is stale.
-- * Autosave every 60 s, save and release on leave, save everything on shutdown.
-- * Unpublished places (Studio without API access) fall back to an in-memory
--   store so the game still runs; nothing persists across play sessions then.
--   A live server never does: if the DataStore is down at start it turns players
--   away with a retry message instead of running a session that can't save.
-- * Writes for one player run one at a time and a released profile is never written
--   again, so a slow autosave can't undo the final save or re-take the lock.

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Signal = require(ReplicatedStorage.Packages.Signal)
local Config = require(ReplicatedStorage.Shared.Config)
local Gear = require(ReplicatedStorage.Shared.Gear)
local Pets = require(ReplicatedStorage.Shared.Pets)
local Levels = require(ReplicatedStorage.Shared.Levels)
local Template = require(script.Parent.Parent.Lib.ProfileTemplate)

local STORE_NAME = "PlayerData_v1"
local AUTOSAVE_INTERVAL = 60
local LOCK_STALE_AFTER = 30 * 60 -- a lock older than this belongs to a dead server
local LOAD_RETRIES = 8
local RETRY_DELAY = 5

export type Profile = {
	Player: Player,
	Data: typeof(Template),
	Loaded: number, -- os.time() when loaded
	Memory: boolean, -- true when running on the in-memory fallback
}

local DataService = Knit.CreateService({
	Name = "DataService",
	Client = {},
})

DataService.ProfileLoaded = Signal.new() -- (player, profile)
DataService.ProfileReleasing = Signal.new() -- (player, profile), before the final save

local profiles: { [Player]: Profile } = {}
local store: DataStore? = nil
local unavailable = false -- live server whose DataStore never answered
local memoryStore: { [string]: any } = {}
local sessionId = if game.JobId ~= "" then game.JobId else HttpService:GenerateGUID(false)

local function deepCopy<T>(value: T): T
	if typeof(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in value :: any do
		copy[k] = deepCopy(v)
	end
	return copy :: any
end

-- Fills keys missing from `data` with template defaults, recursively for
-- dictionaries. Arrays (like refineries) are left as the player has them.
local function reconcile(data: { [any]: any }, template: { [any]: any })
	for key, default in template do
		if data[key] == nil then
			data[key] = deepCopy(default)
		elseif typeof(default) == "table" and typeof(data[key]) == "table" and #default == 0 then
			reconcile(data[key], default)
		end
	end
end

local function migrate(data: { [any]: any }): { [any]: any }
	-- v1 -> v2: six refinery slots became one hopper -> conveyor -> refinery ->
	-- collection post line. Keep the hopper and refinery levels, pour every
	-- refinery bin into the collection post.
	if (data.version or 1) < 2 then
		local refineries = data.refineries or {}
		local bin = {}
		for _, refinery in refineries do
			for oreType, n in refinery.bin or {} do
				bin[oreType] = (bin[oreType] or 0) + n
			end
		end
		data.stations = {
			hopper = data.hopperLevel or 1,
			conveyor = 1,
			refinery = if refineries[1] then refineries[1].level else 1,
			collector = 1,
		}
		data.bin = bin
		data.progress = 0
		data.refineries = nil
		data.hopperLevel = nil
		data.version = 2
	end
	-- v2 -> v3: the pickaxe and backpack tiers became evolution tiers with stat levels.
	-- Everyone starts at the first level of the tier they already own, which is the
	-- same Mining Power, swing, damage and capacity as before.
	if (data.version or 1) < 3 then
		data.pickaxeStats = Gear.freshPickaxeStats(data.pickaxeTier or 1)
		data.backpackStats = Gear.freshBackpackStats(data.backpackTier or 1)
		data.version = 3
	end
	data.pickaxeTier = math.clamp(math.floor(data.pickaxeTier or 1), 1, #Config.Pickaxes)
	data.backpackTier = math.clamp(math.floor(data.backpackTier or 1), 1, #Config.Backpacks)
	data.pickaxeStats = Gear.cleanPickaxeStats(data.pickaxeTier, data.pickaxeStats)
	data.backpackStats = Gear.cleanBackpackStats(data.backpackTier, data.backpackStats)
	-- Preserve a possible fourth slot until the server resolves the pass entitlement.
	data.pets = Pets.clean(data.pets, data.rebirths, true)
	local oreBoost = data.oreBoostLeft
	data.oreBoostLeft = if type(oreBoost) == "number" and oreBoost == oreBoost and oreBoost < math.huge then math.max(oreBoost, 0) else 0
	-- v4 -> v5: player level and XP (everyone starts at level 1)
	local progress = Levels.clean(data.level, data.xp)
	data.level, data.xp = progress.level, progress.xp
	data.version = Template.version
	return data
end

local function keyFor(userId: number): string
	return "player_" .. userId
end

-- One UpdateAsync that claims (or keeps) the lock. Returns data or nil + reason.
local function claim(key: string): ({ [any]: any }?, string?)
	if not store then
		local record = memoryStore[key]
		return if record then deepCopy(record) else nil, nil
	end

	local result, reason = nil, nil
	local ok, err = pcall(function()
		(store :: DataStore):UpdateAsync(key, function(record)
			record = record or { data = nil, lock = nil }
			local lock = record.lock
			if lock and lock.session ~= sessionId and os.time() - lock.time < LOCK_STALE_AFTER then
				reason = "locked"
				return nil -- abort the write, someone else has it
			end
			record.lock = { session = sessionId, time = os.time() }
			result = record.data
			reason = nil
			return record
		end)
	end)
	if not ok then
		return nil, "error: " .. tostring(err)
	end
	return result, reason
end

local busyWriting: { [Profile]: boolean } = {}
local released: { [Profile]: boolean } = {}
local inFlightReleases = 0

local function write(profile: Profile, release: boolean): boolean
	-- One write at a time per profile; the snapshot is taken once it is this write's turn
	while busyWriting[profile] do
		task.wait(0.05)
	end
	if released[profile] and not release then
		return false -- the final save already happened
	end
	busyWriting[profile] = true
	if release then
		released[profile] = true
	end
	local key = keyFor(profile.Player.UserId)
	local data = deepCopy(profile.Data)
	if profile.Memory or not store then
		memoryStore[key] = data
		busyWriting[profile] = nil
		return true
	end
	local aborted = false
	local ok, err = pcall(function()
		(store :: DataStore):UpdateAsync(key, function(record)
			record = record or {}
			local lock = record.lock
			if lock and lock.session ~= sessionId then
				-- Another server took the profile over; never overwrite its data
				aborted = true
				return nil
			end
			record.data = data
			record.lock = if release then nil else { session = sessionId, time = os.time() }
			return record
		end)
	end)
	if not ok then
		warn("[DataService] save failed for", profile.Player.Name, err)
	elseif aborted then
		warn("[DataService] save skipped for", profile.Player.Name, "(another server holds the profile)")
	end
	busyWriting[profile] = nil
	return ok and not aborted
end

function DataService:GetProfile(player: Player): Profile?
	return profiles[player]
end

-- Saves the player's profile now and keeps the lock. Returns whether the save went
-- through (always true on the in-memory store). MonetizationService saves after a
-- developer product grant so a processed receipt is on disk before Roblox is told.
function DataService:Save(player: Player): boolean
	local profile = profiles[player]
	if not profile then
		return false
	end
	return write(profile, false)
end

function DataService:_load(player: Player)
	if unavailable then
		player:Kick("Saving is unavailable right now, so your progress would be lost. Please rejoin in a few minutes.")
		return
	end
	local key = keyFor(player.UserId)
	local data, reason = nil, nil
	for attempt = 1, LOAD_RETRIES do
		data, reason = claim(key)
		if reason == nil then
			break
		end
		warn(string.format("[DataService] %s profile %s (attempt %d)", player.Name, reason, attempt))
		task.wait(RETRY_DELAY)
		if not player.Parent then
			return
		end
	end
	if reason ~= nil then
		player:Kick("Your save is still open on another server. Please rejoin in a minute.")
		return
	end
	if not player.Parent then
		-- Left while loading: give the lock back
		if store then
			write({ Player = player, Data = data or deepCopy(Template), Loaded = os.time(), Memory = false }, true)
		end
		return
	end

	local profileData = migrate(data or deepCopy(Template))
	reconcile(profileData, Template)

	local profile: Profile = {
		Player = player,
		Data = profileData :: any,
		Loaded = os.time(),
		Memory = store == nil,
	}
	profiles[player] = profile
	self.ProfileLoaded:Fire(player, profile)
end

function DataService:_release(player: Player)
	local profile = profiles[player]
	if not profile then
		return
	end
	self.ProfileReleasing:Fire(player, profile)
	profile.Data.lastSeen = os.time()
	profiles[player] = nil
	-- The final save is retried a few times; shutdown waits for it (inFlightReleases)
	inFlightReleases += 1
	for attempt = 1, 4 do
		released[profile] = nil -- a failed attempt may be tried again
		if write(profile, true) then
			break
		end
		task.wait(2 ^ attempt * 0.5)
	end
	inFlightReleases -= 1
end

function DataService:KnitInit()
	-- Explicit, temporary Studio opt-in lets acceptance checks avoid every live DataStore.
	if RunService:IsStudio() and ServerStorage:GetAttribute("DevMemoryStore") == true then
		return
	end
	-- Probe: unpublished places throw here. A live server tries a few times before giving up.
	local attempts = if RunService:IsStudio() then 1 else 4
	local ok: boolean, result: any = false, nil
	for attempt = 1, attempts do
		ok, result = pcall(function()
			local s = DataStoreService:GetDataStore(STORE_NAME)
			s:GetAsync("__probe")
			return s
		end)
		if ok then
			break
		end
		if attempt < attempts then
			task.wait(attempt * 2)
		end
	end
	if ok then
		store = result
	elseif RunService:IsStudio() then
		warn("[DataService] DataStores unavailable, using in-memory profiles:", result)
	else
		unavailable = true
		warn("[DataService] DataStores unavailable on a live server; players are turned away:", result)
	end
end

function DataService:KnitStart()
	Players.PlayerAdded:Connect(function(player)
		self:_load(player)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(self._load, self, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		self:_release(player)
	end)

	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_INTERVAL)
			for _, profile in profiles do
				profile.Data.lastSeen = os.time()
				task.spawn(write, profile, false)
			end
		end
	end)

	game:BindToClose(function()
		for player in profiles do
			task.spawn(function()
				self:_release(player)
			end)
		end
		task.wait() -- let the releases above start counting
		local started = os.clock()
		while inFlightReleases > 0 and os.clock() - started < 25 do
			task.wait(0.1)
		end
	end)

	if RunService:IsStudio() and store == nil then
		print("[DataService] Studio: profiles are in memory only for this play session")
	end
end

return DataService
