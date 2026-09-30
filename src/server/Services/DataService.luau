--!strict
-- Player profiles on DataStoreService with a session lock (spec §12.4).
--
-- * Load: UpdateAsync claims the profile for this server. If another live server
--   holds the lock we retry for a while, then take over once the lock is stale.
-- * Autosave every 60 s, save and release on leave, save everything on shutdown.
-- * Unpublished places (Studio without API access) fall back to an in-memory
--   store so the game still runs; nothing persists across play sessions then.

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Signal = require(ReplicatedStorage.Packages.Signal)
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

local function write(profile: Profile, release: boolean): boolean
	local key = keyFor(profile.Player.UserId)
	local data = deepCopy(profile.Data)
	if profile.Memory or not store then
		memoryStore[key] = data
		return true
	end
	local ok, err = pcall(function()
		(store :: DataStore):UpdateAsync(key, function(record)
			record = record or {}
			local lock = record.lock
			if lock and lock.session ~= sessionId then
				-- Another server took the profile over; never overwrite its data
				return nil
			end
			record.data = data
			record.lock = if release then nil else { session = sessionId, time = os.time() }
			return record
		end)
	end)
	if not ok then
		warn("[DataService] save failed for", profile.Player.Name, err)
	end
	return ok
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
	write(profile, true)
end

function DataService:KnitInit()
	local ok, result = pcall(function()
		local s = DataStoreService:GetDataStore(STORE_NAME)
		-- Probe once: unpublished places throw here
		s:GetAsync("__probe")
		return s
	end)
	if ok then
		store = result
	else
		warn("[DataService] DataStores unavailable, using in-memory profiles:", result)
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
		local pending = 0
		for player in profiles do
			pending += 1
			task.spawn(function()
				self:_release(player)
				pending -= 1
			end)
		end
		local started = os.clock()
		while pending > 0 and os.clock() - started < 25 do
			task.wait(0.1)
		end
	end)

	if RunService:IsStudio() and store == nil then
		print("[DataService] Studio: profiles are in memory only for this play session")
	end
end

return DataService
