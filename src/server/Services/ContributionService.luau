--!strict
-- Per-event contribution tally (spec §5.5). Lives only on the server; clients get a
-- throttled view with their own rank and the top three.
--
-- Contribution is counted in Mining Power, not displayed damage, so a newcomer who
-- mines the whole event earns a fair shard share next to a veteran (spec §5.3).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Config = require(ReplicatedStorage.Shared.Config)

export type Entry = {
	Player: Player,
	Contribution: number,
	HitCore: boolean,
	Ore: number,
}

local ContributionService = Knit.CreateService({
	Name = "ContributionService",
	Client = {
		-- { rank, contribution, players, top = { { name, contribution } } }
		Standing = Knit.CreateProperty(nil),
	},
})

local entries: { [Player]: Entry } = {}
local tracking = false

-- What each player was last sent, so _publish can skip players whose standing
-- hasn't changed since (spec §12.3: keep remote traffic per client low).
type Sent = { rank: number, contribution: number, ore: number, players: number, top: string }
local lastSent: { [Player]: Sent } = {}

local function entryFor(player: Player): Entry
	local entry = entries[player]
	if not entry then
		entry = { Player = player, Contribution = 0, HitCore = false, Ore = 0 }
		entries[player] = entry
	end
	return entry
end

function ContributionService:Reset()
	table.clear(entries)
	table.clear(lastSent)
	tracking = true
	self.Client.Standing:Set(nil)
end

function ContributionService:Stop()
	tracking = false
end

function ContributionService:AddCrust(player: Player, power: number, ore: number)
	if not tracking then
		return
	end
	local entry = entryFor(player)
	entry.Contribution += power
	entry.Ore += ore
end

function ContributionService:AddCore(player: Player, power: number)
	if not tracking then
		return
	end
	local entry = entryFor(player)
	entry.Contribution += power * Config.Meteor.CoreContributionMult
	entry.HitCore = true
end

function ContributionService:GetEntry(player: Player): Entry?
	return entries[player]
end

-- Everyone who took part this event, highest contribution first.
function ContributionService:GetRanked(): { Entry }
	local list = {}
	for player, entry in entries do
		if player.Parent then
			table.insert(list, entry)
		end
	end
	table.sort(list, function(a, b)
		return a.Contribution > b.Contribution
	end)
	return list
end

-- Every StandingInterval: each player's rank and the top three, sent only to
-- players whose rank, rounded contribution, ore, participant count or top three
-- changed since their last send. The top three compare by name and rounded
-- contribution, since the HUD shows both.
function ContributionService:_publish()
	local ranked = self:GetRanked()
	local top = {}
	local topKeyParts = {}
	for i = 1, math.min(3, #ranked) do
		local entry = ranked[i]
		table.insert(top, { name = entry.Player.DisplayName, contribution = entry.Contribution })
		table.insert(topKeyParts, entry.Player.DisplayName .. "=" .. math.floor(entry.Contribution + 0.5))
	end
	local topKey = table.concat(topKeyParts, "\n")

	local function send(player: Player, rank: number, contribution: number, ore: number)
		local rounded = math.floor(contribution + 0.5)
		local last = lastSent[player]
		if
			last
			and last.rank == rank
			and last.contribution == rounded
			and last.ore == ore
			and last.players == #ranked
			and last.top == topKey
		then
			return
		end
		lastSent[player] = { rank = rank, contribution = rounded, ore = ore, players = #ranked, top = topKey }
		self.Client.Standing:SetFor(player, {
			rank = rank,
			contribution = contribution,
			ore = ore,
			players = #ranked,
			top = top,
		})
	end

	for rank, entry in ranked do
		send(entry.Player, rank, entry.Contribution, entry.Ore)
	end
	-- Players who haven't hit anything yet still see the leaders
	for _, player in Players:GetPlayers() do
		if not entries[player] then
			send(player, 0, 0, 0)
		end
	end
end

function ContributionService:KnitStart()
	task.spawn(function()
		while true do
			task.wait(Config.Meteor.StandingInterval)
			if tracking then
				self:_publish()
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		entries[player] = nil
		lastSent[player] = nil
	end)
end

return ContributionService
