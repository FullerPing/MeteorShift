--!strict
-- Roblox Badges (Config.Badges). `pick` is the pure rule; `award` asks Roblox once per player per session and
-- never throws: a badge failing must not break gameplay.
local BadgeService = game:GetService("BadgeService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Badges = {}

local given: { [Player]: { [string]: boolean } } = {}

-- The badge id to award for `key`, or nil when the badge is off, unknown or already given this session
function Badges.pick(ids: { [string]: number }, key: string, done: { [string]: boolean }): number?
	local id = ids[key]
	if type(id) ~= "number" or id <= 0 or id ~= math.floor(id) or done[key] then
		return nil
	end
	return id
end

function Badges.award(player: Player, key: string)
	local done = given[player]
	if not done then
		done = {}
		given[player] = done
	end
	local id = Badges.pick(Config.Badges, key, done)
	if not id then return end
	done[key] = true
	task.spawn(function()
		local ok, err = pcall(BadgeService.AwardBadge, BadgeService, player.UserId, id)
		if not ok then
			warn("[Badges] could not award " .. key .. ": " .. tostring(err))
		end
	end)
end

Players.PlayerRemoving:Connect(function(player)
	given[player] = nil
end)

return Badges
