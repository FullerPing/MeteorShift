--!strict
-- Redeemable codes (Config.Codes, Shared.Codes). The client only sends what the player typed; this service
-- normalises it, checks it against the list and the profile's redeemed codes, marks it redeemed BEFORE paying, then
-- pays cash (sized from the player's income) and shards and announces it in the reward feed.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Codes = require(ReplicatedStorage.Shared.Codes)
local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Rebirth = require(ReplicatedStorage.Shared.Rebirth)
local RequestGate = require(ReplicatedStorage.Shared.RequestGate)

local CodesService = Knit.CreateService({
	Name = "CodesService",
	Client = {},
})

local PlayerStateService
local EconomyService
local RewardService
local TelemetryService

local lastRequest: { [Player]: number } = {}

local MESSAGES = {
	empty = "Type a code first.",
	invalid = "That code doesn't exist.",
	used = "You already used that code.",
	expired = "That code has expired.",
}

-- Returns whether the code paid and what to tell the player
function CodesService:Redeem(player: Player, text: any): (boolean, string)
	local data = PlayerStateService:Get(player)
	if not data then return false, "Your data is still loading." end
	local result = Codes.check(Config.Codes.List, data.codes, text, os.time())
	if result.status ~= "ok" then
		return false, MESSAGES[result.status] or "That code can't be used."
	end
	local key, def = result.key :: string, result.def :: any
	-- the redeemed mark goes in first: whatever happens while paying, the code cannot be used twice
	data.codes[key] = true
	local perSecond = EconomyService:ExpectedIncome(player).perSecond
	local reward = Codes.reward(def, perSecond, Rebirth.cost(data.rebirths) * Config.Codes.CashCeilingShare)
	if reward.cash > 0 then PlayerStateService:AddCash(player, reward.cash) end
	if reward.shards > 0 then PlayerStateService:AddShards(player, reward.shards) end
	TelemetryService:earned(player, "code", reward.cash, reward.shards)
	local parts = {}
	if reward.cash > 0 then table.insert(parts, "+" .. Format.cash(reward.cash)) end
	if reward.shards > 0 then table.insert(parts, "+" .. reward.shards .. " \u{25C6}") end
	local summary = table.concat(parts, " and ")
	RewardService:Bonus(player, "code", "Code " .. key .. ": " .. summary)
	TelemetryService:custom(player, "code_redeemed", 1, { key })
	PlayerStateService:ReplicateNow(player)
	return true, "Code accepted! " .. summary
end

function CodesService.Client:Redeem(player: Player, text: any): (boolean, string)
	-- one try a second per player: a wrong guess costs time, and the call stays cheap to refuse
	local allowed, stamp = RequestGate.check(lastRequest[player], os.clock(), 1)
	lastRequest[player] = stamp
	if not allowed then return false, "Slow down a moment." end
	if type(text) ~= "string" or #text > 200 then return false, MESSAGES.invalid end
	return self.Server:Redeem(player, text)
end

function CodesService:KnitInit()
	PlayerStateService = Knit.GetService("PlayerStateService")
	EconomyService = Knit.GetService("EconomyService")
	RewardService = Knit.GetService("RewardService")
	TelemetryService = Knit.GetService("TelemetryService")
end

function CodesService:KnitStart()
	game:GetService("Players").PlayerRemoving:Connect(function(player)
		lastRequest[player] = nil
	end)
end

return CodesService
