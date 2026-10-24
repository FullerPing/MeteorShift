--!strict
-- Player feedback (Config.Feedback): FeedbackPromptController asks after half an hour of play and sends what the
-- player writes here. It is filtered, saved to the "Feedback" DataStore inbox (read with /feedback in Main.server)
-- and, when ServerStorage has a FeedbackWebhook attribute (a Discord webhook URL, kept out of git so players can't
-- read it), posted to Discord. HTTP requests must be on in Game Settings > Security for the post.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local TextService = game:GetService("TextService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Config = require(ReplicatedStorage.Shared.Config)
local Feedback = require(script.Parent.Parent.Lib.Feedback)

local FeedbackService = Knit.CreateService({
	Name = "FeedbackService",
	Client = {
		AskFavorite = Knit.CreateSignal(), -- () show Roblox's favorite prompt and the like note, once per player ever
	},
})

local INBOX_KEY = "inbox"
local lastSend: { [Player]: number } = {}
local sent: { [Player]: number } = {}

-- The inbox store; the in-memory one for isolated Studio runs (DevMemoryStore), like DataService
local function store(): any
	local DataStoreService = game:GetService("DataStoreService")
	if RunService:IsStudio() and ServerStorage:GetAttribute("DevMemoryStore") == true then
		return game:GetService("MemoryStoreService"):GetSortedMap("FeedbackDev")
	end
	return DataStoreService:GetDataStore("Feedback")
end

local function save(entry: any)
	local inbox = store()
	local ok, err = pcall(function()
		if inbox:IsA("MemoryStoreSortedMap") then
			inbox:UpdateAsync(INBOX_KEY, function(old) return Feedback.push(old, entry) end, 86400)
		else
			inbox:UpdateAsync(INBOX_KEY, function(old) return Feedback.push(old, entry) end)
		end
	end)
	if not ok then warn("[FeedbackService] could not save feedback:", err) end
end

local function post(entry: any)
	local url = ServerStorage:GetAttribute("FeedbackWebhook")
	if typeof(url) ~= "string" or url == "" then
		return
	end
	local ok, err = pcall(function()
		HttpService:PostAsync(Feedback.proxied(url), HttpService:JSONEncode({
			username = "MeteorShift feedback",
			content = string.format("**%s** (%d, level %s, %d min in): %s", entry.name, entry.userId, tostring(entry.level), entry.minutes, entry.text),
			allowed_mentions = { parse = {} }, -- an @everyone in the text pings nobody
		}))
	end)
	if not ok then warn("[FeedbackService] could not post feedback to Discord:", err) end
end

-- The newest `count` saved messages, newest first
function FeedbackService:Recent(count: number): { any }
	local ok, inbox = pcall(function() return store():GetAsync(INBOX_KEY) end)
	local out = {}
	for index, entry in if ok and type(inbox) == "table" then inbox else {} do
		if index > count then break end
		table.insert(out, entry)
	end
	return out
end

-- The feedback card shows once per player, ever (owner, 2026-10-24): the first session that reaches AskAfter.
-- True the first time it is asked, and marks it asked.
function FeedbackService.Client:ShouldAsk(player: Player): boolean
	local data = Knit.GetService("PlayerStateService"):Get(player)
	if not data or data.flags.feedbackAsked == true then
		return false
	end
	data.flags.feedbackAsked = true
	return true
end

function FeedbackService.Client:Send(player: Player, text: any, minutes: any): boolean
	local clean = Feedback.clean(text)
	local now = os.clock()
	if not clean or now - (lastSend[player] or -math.huge) < Config.Feedback.Cooldown or (sent[player] or 0) >= Config.Feedback.PerSession then
		return false
	end
	lastSend[player], sent[player] = now, (sent[player] or 0) + 1
	-- the team reads it in game (/feedback), so it goes through Roblox text filtering like any shown text
	local ok, filtered = pcall(function()
		return TextService:FilterStringAsync(clean, player.UserId):GetNonChatStringForBroadcastAsync()
	end)
	if not ok then
		warn("[FeedbackService] could not filter feedback:", filtered)
		return false
	end
	local data = Knit.GetService("PlayerStateService"):Get(player)
	local entry = {
		name = player.Name, userId = player.UserId, text = filtered, at = os.time(),
		level = if data then data.level else nil, minutes = if typeof(minutes) == "number" then math.clamp(math.floor(minutes), 0, 100000) else 0,
	}
	task.spawn(save, entry)
	task.spawn(post, entry)
	return true
end

function FeedbackService:KnitStart()
	Players.PlayerRemoving:Connect(function(player)
		lastSend[player], sent[player] = nil, nil
	end)
	-- a rebirth is a happy moment: ask once (ever) to favorite and like the game. Never rewarded: Roblox's rules forbid it
	local PlayerStateService = Knit.GetService("PlayerStateService")
	Knit.GetService("RebirthService").Reborn:Connect(function(player: Player)
		local data = PlayerStateService:Get(player)
		if not data or data.flags.favoriteAsked == true then return end
		data.flags.favoriteAsked = true
		task.delay(Config.Feedback.FavoriteDelay, function()
			if player.Parent then self.Client.AskFavorite:Fire(player) end
		end)
	end)
end

return FeedbackService
