--!strict
-- Background music and ambience (Config.Music). A calm hub track plays between meteors; the
-- event track fades in as one approaches (the same approach weight AtmosphereController uses
-- for the sky) and holds while it is down, then hands back. Stingers (Config.Sounds Duck)
-- lower the music for a moment. A low hum sits on the active meteor, a siren warns shortly
-- before impact, and a sting plays when a core cracks. The Settings switch MusicOn mutes the
-- Music and Ambience SoundGroups (client/Sfx).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Config = require(ReplicatedStorage.Shared.Config)
local AtmosphereMood = require(ReplicatedStorage.Shared.AtmosphereMood)
local Sfx = require(script.Parent.Parent.Sfx)

local music = Config.Music

local MusicController = Knit.CreateController({ Name = "MusicController" })

local function loop(spec: { Id: string }, group: string, parent: Instance, looped: boolean?): Sound
	local sound = Instance.new("Sound")
	sound.Name = group .. "Loop"
	sound.SoundId = spec.Id
	sound.Looped = looped ~= false
	sound.Volume = 0
	sound.SoundGroup = Sfx.group(group)
	sound.Parent = parent
	return sound
end

local function approach(current: number, target: number, rate: number): number
	if current < target then return math.min(target, current + rate) end
	return math.max(target, current - rate)
end

function MusicController:KnitStart()
	local MeteorService = Knit.GetService("MeteorService")
	local SoundService = game:GetService("SoundService")
	local hub = loop(music.Hub, "Music", SoundService, false)
	local event = loop(music.Event, "Music", SoundService, false)
	local ambience = loop(music.Ambience, "Ambience", SoundService)
	hub:Play()
	ambience:Play()

	-- a track that ends rests for a while (Music.Gap) instead of starting over straight away
	local restUntil: { [Sound]: number } = {}
	for _, track in { hub, event } do
		track.Ended:Connect(function()
			restUntil[track] = os.clock() + music.Gap[1] + math.random() * (music.Gap[2] - music.Gap[1])
		end)
	end
	local function resting(track: Sound): boolean
		return os.clock() < (restUntil[track] or 0)
	end

	local impactAt: number? = nil
	local warnedFor: number? = nil
	local mix = 0 -- 0 hub .. 1 event
	local duck = 1
	local hum: Sound? = nil
	local musicGroup = Sfx.group("Music")

	MeteorService.Impact:Connect(function()
		impactAt = workspace:GetServerTimeNow()
	end)
	MeteorService.CoreCracked:Connect(function()
		Sfx.play("CoreStinger")
	end)

	local function activeCore(): BasePart?
		local map = workspace:FindFirstChild("Map")
		local active = map and map:FindFirstChild("Crater") and map.Crater:FindFirstChild("ActiveMeteor")
		local meteor = active and active:FindFirstChildOfClass("Model")
		return meteor and meteor.PrimaryPart
	end

	RunService.Heartbeat:Connect(function(dt: number)
		local target = 0
		local state = MeteorService.State:Get()
		local phase = state and state.phase
		if state then
			local now = workspace:GetServerTimeNow()
			local left = math.max(0, state.endsAt - now)
			local sinceImpact = if impactAt then now - impactAt else nil
			local weights = AtmosphereMood.weights(state.phase, left, state.duration, sinceImpact)
			target = math.max(weights.approach, weights.event)
			-- the warning: once per countdown, WarnAt seconds before impact
			if phase == "Countdown" and left <= music.WarnAt and left > music.WarnAt - 2 and warnedFor ~= state.endsAt then
				warnedFor = state.endsAt
				Sfx.play("MeteorSiren")
				Sfx.play("MeteorBuild")
			end
		end

		-- the event track restarts from the top each time it fades in from silence
		if mix <= 0.001 and target > 0 and not resting(event) then
			event.TimePosition = 0
			if not event.IsPlaying then event:Play() end
		end
		mix = approach(mix, target, dt / music.Fade)
		local ducked = os.clock() < (musicGroup:GetAttribute("DuckUntil") or 0)
		duck = approach(duck, if ducked then music.DuckTo else 1, dt / music.DuckFade)
		hub.Volume = music.Hub.Volume * (1 - mix) * duck
		event.Volume = music.Event.Volume * mix * duck
		if mix <= 0.001 and event.IsPlaying then event:Stop() end
		if mix >= 0.999 and hub.IsPlaying then hub:Pause() elseif mix < 0.999 and not hub.IsPlaying and not resting(hub) then hub:Resume() end
		ambience.Volume = music.Ambience.Volume * (1 - 0.6 * mix)

		-- the crater hum rides on the meteor while it is down
		local core = if phase == "Impact" or phase == "Active" then activeCore() else nil
		if core then
			if not hum or hum.Parent ~= core then
				if hum then hum:Destroy() end
				local made = loop(music.CraterHum, "Ambience", core)
				made.Name = "CraterHum"
				made.RollOffMinDistance, made.RollOffMaxDistance = music.CraterHum.MinDistance, music.CraterHum.MaxDistance
				made.Volume = music.CraterHum.Volume
				made:Play()
				hum = made
			end
		elseif hum then
			hum:Destroy()
			hum = nil
		end
	end)
end

return MusicController
