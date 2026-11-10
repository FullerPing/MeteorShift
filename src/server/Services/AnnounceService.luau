--!strict
-- Official announcements from the team (the /announce and /giveall dev commands in Main.server): every client
-- shows a banner "[DEV] Name: message" with the gift under it when there is one (AnnounceController draws it).
-- The message is the admin's own words, so it goes through Roblox text filtering before anyone sees it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

local Knit = require(ReplicatedStorage.Packages.Knit)

local AnnounceService = Knit.CreateService({
	Name = "AnnounceService",
	Client = {
		Dev = Knit.CreateSignal(),
	},
})

local MAX_LENGTH = 120

-- `gift` is what was received ("Received 500 SHARDS!") and `kind` its AdminGive kind, for the icon; only the players
-- in `received` see it (a player who already had the gear gets the message alone). False when the message could
-- not be filtered, so nothing is shown.
function AnnounceService:Dev(from: Player, message: string, gift: string?, kind: string?, received: { [Player]: boolean }?): boolean
	local ok, filtered = pcall(function()
		return TextService:FilterStringAsync(string.sub(message, 1, MAX_LENGTH), from.UserId):GetNonChatStringForBroadcastAsync()
	end)
	if not ok then
		warn("[AnnounceService] could not filter the announcement:", filtered)
		return false
	end
	for _, player in Players:GetPlayers() do
		local got = gift ~= nil and (received == nil or received[player] == true)
		self.Client.Dev:Fire(player, { name = from.Name, message = filtered, gift = if got then gift else nil, kind = kind })
	end
	return true
end

return AnnounceService
