--!strict
-- Plays the named sounds in Config.Sounds. 2D sounds come from a small pool of Sounds under
-- SoundService (reused, never more than Entry.Max per name); sounds placed on a part are
-- one-shots destroyed when they end, also capped per name. A per-name cooldown drops plays
-- that come too fast, so a held mine button cannot pile up Sounds (spec §12.3).
-- Every sound plays through a SoundGroup (Master > Music, Ambience, SFX, UI); the Settings
-- switches MusicOn and SfxOn mute the groups, and an entry's Duck lowers the music briefly.

local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Config = require(ReplicatedStorage.Shared.Config)

local Sfx = {}

local DEFAULT_MAX_2D = 4
local DEFAULT_MAX_3D = 6
local GROUP_NAMES = { "Music", "Ambience", "SFX", "UI" }

export type SpatialReach = { minDistance: number?, maxDistance: number? }

local pools: { [string]: { Sound } } = {}
local nextIndex: { [string]: number } = {}
local nextVariant: { [string]: number } = {}
local active3d: { [string]: number } = {}
local lastPlayed: { [string]: number } = {}
local groups: { [string]: SoundGroup } = {}

-- The SoundGroup `name` under SoundService.Master, made on first use
function Sfx.group(name: string): SoundGroup
	local existing = groups[name]
	if existing and existing.Parent then
		return existing
	end
	local master = SoundService:FindFirstChild("Master")
	if not master then
		master = Instance.new("SoundGroup")
		master.Name = "Master"
		master.Volume = 1
		master.Parent = SoundService
	end
	local group = master:FindFirstChild(name)
	if not group then
		group = Instance.new("SoundGroup")
		group.Name = name
		group.Volume = 1
		if name == "SFX" then
			-- keeps a burst of hits, coins and a fanfare from clipping together
			local compressor = Instance.new("CompressorSoundEffect")
			compressor.Threshold, compressor.Ratio, compressor.Attack, compressor.Release = -14, 3, 0.01, 0.15
			compressor.Parent = group
		end
		group.Parent = master
	end
	groups[name] = group :: SoundGroup
	return group :: SoundGroup
end

-- A PlaybackSpeed for the entry: random within PitchMin..PitchMax, or 1
function Sfx.pitch(entry: Config.SoundEntry): number
	local low, high = entry.PitchMin, entry.PitchMax
	if low and high then
		return low + math.random() * (high - low)
	end
	return 1
end

-- The id to play this time: the next of Variants, or Id
local function idFor(name: string, entry: Config.SoundEntry): string
	local variants = entry.Variants
	if not variants or #variants == 0 then
		return entry.Id
	end
	local index = (nextVariant[name] or 0) % #variants + 1
	nextVariant[name] = index
	return variants[index]
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

-- Lowers the music for `seconds` (MusicController reads the attribute)
function Sfx.duck(seconds: number)
	local music = Sfx.group("Music")
	local untilTime = os.clock() + seconds
	if (music:GetAttribute("DuckUntil") or 0) < untilTime then
		music:SetAttribute("DuckUntil", untilTime)
	end
end

-- Play `name`. With `parent` (a part or attachment) the sound is heard from there,
-- otherwise it is 2D. Optional reach applies only to this spatial sound; omitted
-- reach retains the existing rolloff. `speed` multiplies the entry's pitch.
-- Returns the Sound, or nil when dropped.
function Sfx.play(name: string, parent: Instance?, reach: SpatialReach?, speed: number?): Sound?
	local entry = Config.Sounds[name]
	if not entry or not ready(name, entry) then
		return nil
	end
	local group = Sfx.group(entry.Group or "SFX")
	if entry.Duck and group.Volume > 0 then
		Sfx.duck(entry.Duck)
	end
	if parent then
		local count = active3d[name] or 0
		if count >= (entry.Max or DEFAULT_MAX_3D) then
			return nil
		end
		active3d[name] = count + 1
		local sound = Instance.new("Sound")
		sound.SoundId = idFor(name, entry)
		sound.Volume = entry.Volume
		sound.PlaybackSpeed = Sfx.pitch(entry) * (speed or 1)
		sound.SoundGroup = group
		sound.RollOffMaxDistance = if reach and reach.maxDistance then reach.maxDistance else 1000
		if reach and reach.minDistance then sound.RollOffMinDistance = reach.minDistance end
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
		sound.Volume = entry.Volume
		sound.SoundGroup = group
		sound.Parent = SoundService
		pool[index] = sound
	end
	nextIndex[name] = index % (entry.Max or DEFAULT_MAX_2D) + 1
	local id = idFor(name, entry)
	if sound.SoundId ~= id then sound.SoundId = id end
	sound.PlaybackSpeed = Sfx.pitch(entry) * (speed or 1)
	sound.TimePosition = 0
	sound:Play()
	return sound
end

-- The Settings switches: MusicOn mutes Music and Ambience, SfxOn mutes SFX and UI
function Sfx.bindSettings()
	local player = Players.LocalPlayer
	for _, name in GROUP_NAMES do
		Sfx.group(name)
	end
	local function apply()
		local music = if player:GetAttribute("MusicOn") == false then 0 else 1
		local sfx = if player:GetAttribute("SfxOn") == false then 0 else 1
		Sfx.group("Music").Volume, Sfx.group("Ambience").Volume = music, music
		Sfx.group("SFX").Volume, Sfx.group("UI").Volume = sfx, sfx
	end
	player:GetAttributeChangedSignal("MusicOn"):Connect(apply)
	player:GetAttributeChangedSignal("SfxOn"):Connect(apply)
	apply()
end

-- Load every configured id once so the first hit does not stall on a download
function Sfx.preload()
	task.spawn(function()
		local items: { Instance } = {}
		local function add(id: string)
			local sound = Instance.new("Sound")
			sound.SoundId = id
			table.insert(items, sound)
		end
		for _, entry in Config.Sounds do
			add(entry.Id)
			for _, id in entry.Variants or {} do
				if id ~= entry.Id then add(id) end
			end
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
