--!strict
-- Personal production upgrades purchased at the shared refinery: one level for the whole line
-- (hopper, conveyor, refinery and collection post together; Shared.Line).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Config = require(ReplicatedStorage.Shared.Config)
local Line = require(ReplicatedStorage.Shared.Line)
local Price = require(ReplicatedStorage.Shared.Price)
local Rebirth = require(ReplicatedStorage.Shared.Rebirth)
local Signal = require(ReplicatedStorage.Packages.Signal)
local RequestGate = require(ReplicatedStorage.Shared.RequestGate)

local UpgradeService = Knit.CreateService({
	Name = "UpgradeService",
	Client = {
		Upgraded = Knit.CreateSignal(), -- (newLevel) once per purchase, however many levels it took
		Notice = Knit.CreateSignal(), -- (text)
	},
})

UpgradeService.LineUpgraded = Signal.new() -- (player, newLevel, cash) for every level bought

local PlayerStateService
local RefineryService
local lastBuyRequest: { [Player]: number } = {}

-- Buys up to `count` line levels in a row, stopping at the top, at a player-level gate
-- (Config.Levels.EvolveLevel) or when the cash runs out. A notice only explains why nothing at
-- all was bought. Returns true when at least one level went through.
function UpgradeService:BuyLine(player: Player, count: number?): boolean
	local data = PlayerStateService:Get(player)
	if not data then
		return false
	end
	local name = Config.Home.Line.Name
	local level = Line.clean(data.line)
	local priceMult = Rebirth.priceMult(data.rebirths)
	local bought, _, stop = Line.plan(level, math.max(count or 1, 1), data.cash, data.level or 1, priceMult)
	if bought == 0 then
		local target = level + 1
		if stop == "max" then
			self.Client.Notice:Fire(player, name .. " is already at max level.")
		elseif stop == "level" then
			self.Client.Notice:Fire(player, string.format("Reach player level %d for %s Lv %d. Take part in meteors to earn XP.", Line.levelNeeded(target), name, target))
		else
			self.Client.Notice:Fire(player, Price.shortfall(data, Line.cost(target, priceMult) or 0, 0, name .. " Lv " .. target) or "Couldn't upgrade.")
		end
		return false
	end
	for target = level + 1, level + bought do
		local price = Line.cost(target, priceMult) :: number
		data.cash -= price
		data.line = target
		-- TelemetryService hears LineUpgraded and sets flags.firstRefinery with
		-- first_refinery_bought (spec §13)
		self.LineUpgraded:Fire(player, target, price)
	end
	self.Client.Upgraded:Fire(player, data.line)
	RefineryService:Refresh(player, true)
	return true
end

-- Production menu purchases require the shared refinery. `count` is how many levels the
-- menu's 1x / 5x / MAX wants; the server prices and checks each one.
function UpgradeService.Client:BuyLine(player: Player, count: number?): boolean
	local allowed, stamp = RequestGate.check(lastBuyRequest[player], os.clock(), 0.15)
	lastBuyRequest[player] = stamp
	if not allowed then return false end
	local wanted = 1
	if typeof(count) == "number" and count == count then
		wanted = math.clamp(math.floor(count), 1, Line.max())
	end
	if not RefineryService:CanUseMenu(player) then
		self.Server.Client.Notice:Fire(player, "Move closer to the refinery to upgrade production.")
		return false
	end
	return self.Server:BuyLine(player, wanted)
end

function UpgradeService:KnitInit()
	PlayerStateService = Knit.GetService("PlayerStateService")
	RefineryService = Knit.GetService("RefineryService")
end

function UpgradeService:KnitStart()
	Players.PlayerRemoving:Connect(function(player)
		lastBuyRequest[player] = nil
	end)
end

return UpgradeService
