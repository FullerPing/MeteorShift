--!strict
-- Plays the named sounds in Config.Sounds. 2D sounds come from a small pool of Sounds under
-- SoundService (reused, never more than Entry.Max per name); sounds placed on a part are
-- one-shots destroyed when they end, also capped per name. A per-name cooldown drops plays
-- that come too fast, so a held mine button cannot pile up Sounds (spec §12.3).

local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Config = require(ReplicatedStorage.Shared.Config)

local Sfx = {}

local DEFAULT_MAX_2D = 4
local DEFAULT_MAX_3D = 6

local pools: { [string]: { Sound } } = {}
local nextIndex: { [string]: number } = {}
local active3d: { [string]: number } = {}
local lastPlayed: { [string]: number } = {}

-- A PlaybackSpeed for the entry: random within PitchMin..PitchMax, or 1
function Sfx.pitch(entry: Config.SoundEntry): number
	local low, high = entry.PitchMin, entry.PitchMax
	if low and high then
		return low + math.random() * (high - low)
	end
	return 1
end

local function ready(name: string, entry: Config.SoundEntry): boolean
	local now = os.clock()
	local last = lastPlayed[name]
	if last and now - last < (entry.Cooldown or 0) then
		return false
	end
	lastPlayed[name] = now
	return true
end

-- Play `name`. With `parent` (a part or attachment) the sound is heard from there,
-- otherwise it is 2D. Returns the Sound, or nil when dropped.
function Sfx.play(name: string, parent: Instance?): Sound?
	local entry = Config.Sounds[name]
	if not entry or not ready(name, entry) then
		return nil
	end
	if parent then
		local count = active3d[name] or 0
		if count >= (entry.Max or DEFAULT_MAX_3D) then
			return nil
		end
		active3d[name] = count + 1
		local sound = Instance.new("Sound")
		sound.SoundId = entry.Id
		sound.Volume = entry.Volume
		sound.PlaybackSpeed = Sfx.pitch(entry)
		sound.RollOffMaxDistance = 1000
		sound.Parent = parent
		sound:Play()
		local done = false
		local function finish()
			if done then
				return
			end
			done = true
			active3d[name] -= 1
			sound:Destroy()
		end
		sound.Ended:Once(finish)
		task.delay(15, finish)
		return sound
	end

	local pool = pools[name]
	if not pool then
		pool = {}
		pools[name] = pool
	end
	local index = nextIndex[name] or 1
	local sound = pool[index]
	if not sound or sound.Parent ~= SoundService then
		if sound then
			sound:Destroy()
		end
		sound = Instance.new("Sound")
		sound.SoundId = entry.Id
		sound.Volume = entry.Volume
		sound.Parent = SoundService
		pool[index] = sound
	end
	nextIndex[name] = index % (entry.Max or DEFAULT_MAX_2D) + 1
	sound.PlaybackSpeed = Sfx.pitch(entry)
	sound.TimePosition = 0
	sound:Play()
	return sound
end

-- Load every configured id once so the first hit does not stall on a download
function Sfx.preload()
	task.spawn(function()
		local items: { Instance } = {}
		for _, entry in Config.Sounds do
			local sound = Instance.new("Sound")
			sound.SoundId = entry.Id
			table.insert(items, sound)
		end
		pcall(function()
			ContentProvider:PreloadAsync(items)
		end)
		for _, sound in items do
			sound:Destroy()
		end
	end)
end

return Sfx
