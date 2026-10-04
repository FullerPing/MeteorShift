--!nocheck
-- Temporary Studio server Script. Inject for one play session, then remove.
-- Exercises the real client sale entry point and real economy calculations.
-- Profile access, replication, and outbound effects use unparented Folder
-- identity keys so no live profile, DataStore, pass ownership, tutorial or analytics
-- record changes. Interceptions are synchronous and always restored.
-- Creating Players requires Roblox's WritePlayer capability; the real sale
-- path only needs an identity key once those fixture boundaries are intercepted.

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local HttpService = game:GetService("HttpService")
local result = { ok = false, cases = {}, assertions = 0 }
local cleanup = function() end

local function check(condition, message)
	result.assertions += 1
	assert(condition, message)
end

local function eq(actual, expected, message)
	check(actual == expected, message .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

local function copy(value)
	if type(value) ~= "table" then return value end
	local cloned = {}
	for key, item in value do cloned[key] = copy(item) end
	return cloned
end

local function same(actual, expected)
	if type(actual) ~= type(expected) then return false end
	if type(actual) ~= "table" then return actual == expected end
	for key, item in actual do if not same(item, expected[key]) then return false end end
	for key in expected do if actual[key] == nil then return false end end
	return true
end

local ok, err = xpcall(function()
	assert(RunService:IsStudio() and RunService:IsServer(), "Bar sale QA is Studio server only")
	local Knit = require(ReplicatedStorage.Packages.Knit)
	local started, startError = Knit.OnStart():timeout(20):await()
	assert(started, "Knit did not start: " .. tostring(startError))
	local Economy = Knit.GetService("EconomyService")
	local State = Knit.GetService("PlayerStateService")
	local Monetization = Knit.GetService("MonetizationService")
	local Signal = require(ReplicatedStorage.Packages.Signal)
	local Template = require(ServerScriptService.Server.Lib.ProfileTemplate)

	-- This is the feature's red assertion, before any temporary mutation.
	check(type(Economy.Client.SellAll) == "function", "Foundry cannot sell: EconomyService.Client.SellAll remote missing")
	table.insert(result.cases, "client sale entry point exists")

	local actor = Instance.new("Folder")
	actor.Name = "BarSaleQAIsolatedIdentity"
	local missing = Instance.new("Folder")
	missing.Name = "BarSaleQANoProfileIdentity"
	local fixture = copy(Template)
	fixture.cash = 1234
	fixture.bars = { iron = 10, frost = 2, crystal = 1 }
	fixture.backpack = { iron = 9, frost = 4 }
	fixture.hopper = { crystal = 7 }
	fixture.bin = { iron = 17, frost = 6, crystal = 5 }
	fixture.rebirths = 2
	fixture.index = { magnetite = 1, hematiteRose = 1, meteoricNickel = 1, starfallIron = 1 }
	fixture.stats.barsSold = 7
	local before = copy(fixture)
	local old = {
		Get = State.Get, Replicate = State.Replicate, ReplicateNow = State.ReplicateNow,
		VIPMult = Monetization.VIPMult,
		Sold = Economy.Client.Sold, Notice = Economy.Client.Notice, BarsSold = Economy.BarsSold,
	}
	local sold, notices, events = {}, {}, {}
	local queuedReplications, immediateReplications = 0, 0
	local testBarsSold = Signal.new()
	local eventConnection = testBarsSold:Connect(function(player, bars, cash)
		table.insert(events, { player = player, bars = bars, cash = cash })
	end)
	cleanup = function()
		State.Get, State.Replicate, State.ReplicateNow = old.Get, old.Replicate, old.ReplicateNow
		Monetization.VIPMult = old.VIPMult
		Economy.Client.Sold, Economy.Client.Notice, Economy.BarsSold = old.Sold, old.Notice, old.BarsSold
		eventConnection:Disconnect()
		testBarsSold:Destroy()
		actor:Destroy()
		missing:Destroy()
		result.restored = State.Get == old.Get and State.Replicate == old.Replicate
			and State.ReplicateNow == old.ReplicateNow and Monetization.VIPMult == old.VIPMult
			and Economy.Client.Sold == old.Sold and Economy.Client.Notice == old.Notice
			and Economy.BarsSold == old.BarsSold
	end

	State.Get = function(self, player)
		if player == actor then return fixture end
		if player == missing then return nil end
		return old.Get(self, player)
	end
	State.Replicate = function(self, player)
		if player == actor then queuedReplications += 1; return end
		return old.Replicate(self, player)
	end
	State.ReplicateNow = function(self, player)
		if player == actor then immediateReplications += 1; return end
		return old.ReplicateNow(self, player)
	end
	Monetization.VIPMult = function(self, player)
		if player == actor then return 1.1 end
		return old.VIPMult(self, player)
	end
	Economy.Client.Sold = { Fire = function(_, player, bars, cash)
		table.insert(sold, { player = player, bars = bars, cash = cash })
	end }
	Economy.Client.Notice = { Fire = function(_, player, text)
		table.insert(notices, { player = player, text = text })
	end }
	Economy.BarsSold = testBarsSold

	-- Hand checked: (10*5 + 2*120 + 1*3000) * 4 * 1.02 * 1.1
	-- = 14765.52, floored once to 14765; 13 carried bars, 1234 initial cash.
	check(math.abs(Economy:SaleMultiplier(actor) - 4.488) < 1e-9, "sale uses rebirth, index and VIP multipliers")
	eq(Economy.Client:SellAll(actor), 14765, "mixed bar sale returns exact adjusted cash")
	eq(fixture.cash, 15999, "cash credited exactly once")
	eq(next(fixture.bars), nil, "carried bars cleared")
	eq(fixture.stats.barsSold, 20, "sold count added to lifetime stats")
	check(same(fixture.backpack, before.backpack), "raw backpack ore unchanged")
	check(same(fixture.hopper, before.hopper), "hopper ore unchanged")
	check(same(fixture.bin, before.bin), "collector bars unchanged")
	check(same(fixture.index, before.index), "mineral index unchanged")
	eq(fixture.rebirths, before.rebirths, "rebirths unchanged")
	eq(immediateReplications, 1, "sale result replicated immediately once")
	eq(queuedReplications, 1, "real AddCash queues the changed balance")
	eq(#sold, 1, "one client sale signal")
	eq(sold[1].player, actor, "client sale targets the seller")
	eq(sold[1].bars, 13, "client sale reports actual bar count")
	eq(sold[1].cash, 14765, "client sale reports actual cash")
	eq(#events, 1, "one BarsSold event")
	eq(events[1].player, actor, "BarsSold targets the seller")
	eq(events[1].bars, 13, "BarsSold reports actual bar count")
	eq(events[1].cash, 14765, "BarsSold reports actual cash")
	table.insert(result.cases, "mixed bars sell for exact multiplier-adjusted cash without selling ore or stored bars")

	eq(Economy.Client:SellAll(actor), 0, "repeat sale returns zero")
	eq(fixture.cash, 15999, "repeat sale does not credit cash twice")
	eq(fixture.stats.barsSold, 20, "repeat sale does not count bars twice")
	eq(#sold, 1, "repeat sale emits no successful sale signal")
	eq(#events, 1, "repeat sale emits no BarsSold event")
	eq(immediateReplications, 1, "empty sale does not replicate a change")
	eq(#notices, 1, "empty sale reports a notice")
	eq(notices[1].player, actor, "empty notice targets the seller")
	check(type(notices[1].text) == "string" and #notices[1].text > 0, "empty notice explains no bars")
	table.insert(result.cases, "repeat sale cannot pay or count bars twice")

	eq(Economy.Client:SellAll(missing), 0, "missing profile safely returns zero")
	eq(#sold, 1, "missing profile emits no sale")
	eq(#events, 1, "missing profile emits no BarsSold event")
	eq(#notices, 1, "missing profile does not use the loaded player's notice")
	table.insert(result.cases, "missing profile safely returns zero")
end, debug.traceback)

local cleanupOk, cleanupError = pcall(cleanup)
result.ok = ok and cleanupOk and result.restored == true
if not ok then result.error = tostring(err) end
if not cleanupOk then result.cleanupError = tostring(cleanupError) end
workspace:SetAttribute("BarSaleRuntimeQA", HttpService:JSONEncode(result))
print("[BarSaleRuntimeQA] " .. HttpService:JSONEncode(result))
