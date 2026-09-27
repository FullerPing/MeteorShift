--!strict
-- Per-event contribution tally (spec §5.5). Lives only on the server; clients get a
-- throttled view with their own rank and the top three.

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
	tracking = true
	self.Client.Standing:Set(nil)
end

function ContributionService:Stop()
	tracking = false
end

function ContributionService:AddCrust(player: Player, damage: number, ore: number)
	if not tracking then
		return
	end
	local entry = entryFor(player)
	entry.Contribution += damage
	entry.Ore += ore
end

function ContributionService:AddCore(player: Player, damage: number)
	if not tracking then
		return
	end
	local entry = entryFor(player)
	entry.Contribution += damage * Config.Meteor.CoreContributionMult
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

function ContributionService:_publish()
	local ranked = self:GetRanked()
	local top = {}
	for i = 1, math.min(3, #ranked) do
		table.insert(top, { name = ranked[i].Player.DisplayName, contribution = ranked[i].Contribution })
	end
	for rank, entry in ranked do
		self.Client.Standing:SetFor(entry.Player, {
			rank = rank,
			contribution = entry.Contribution,
			ore = entry.Ore,
			players = #ranked,
			top = top,
		})
	end
	-- Players who haven't hit anything yet still see the leaders
	for _, player in Players:GetPlayers() do
		if not entries[player] then
			self.Client.Standing:SetFor(player, { rank = 0, contribution = 0, ore = 0, players = #ranked, top = top })
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
	end)
end

return ContributionService
