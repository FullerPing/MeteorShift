--!nocheck
-- Inject as a temporary Studio server Script for one play session. This runs
-- the real server API, production simulation, and State snapshot builder with
-- isolated profile/plot identities. All interception is synchronous and restored.
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local HttpService = game:GetService("HttpService")
local result = { ok = false, cases = {}, assertions = 0 }
local cleanup = function() result.restored = true end

local function check(condition, message)
	result.assertions += 1
	assert(condition, message)
end
local function eq(actual, expected, message)
	check(actual == expected, message .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local function copy(value)
	if type(value) ~= "table" then return value end
	local out = {}
	for key, item in value do out[key] = copy(item) end
	return out
end
local function same(actual, expected)
	if type(actual) ~= type(expected) then return false end
	if type(actual) ~= "table" then return actual == expected end
	for key, item in actual do if not same(item, expected[key]) then return false end end
	for key in expected do if actual[key] == nil then return false end end
	return true
end

local ok, err = xpcall(function()
	assert(RunService:IsStudio() and RunService:IsServer(), "Refinery QA is Studio server only")
	local Knit = require(ReplicatedStorage.Packages.Knit)
	local started, startError = Knit.OnStart():timeout(20):await()
	assert(started, "Knit did not start: " .. tostring(startError))
	local Refinery = Knit.GetService("RefineryService")
	local State = Knit.GetService("PlayerStateService")
	local Plot = Knit.GetService("PlotService")
	local Template = require(ServerScriptService.Server.Lib.ProfileTemplate)
	local Refining = require(ServerScriptService.Server.Lib.Refining)
	check(type(Refinery.Client.SetPriority) == "function", "Refinery cannot select ore priority: SetPriority remote missing")
	check(type(Template.refinePriority) == "table" and next(Template.refinePriority) == nil, "old profiles need the default refinery priority")
	table.insert(result.cases, "priority entry point and reconciled profile default exist")

	local actor = Instance.new("Folder")
	actor.Name = "RefineryQAIsolatedOwner"
	local noPlot = Instance.new("Folder")
	noPlot.Name = "RefineryQAWithoutPlot"
	local missing = Instance.new("Folder")
	missing.Name = "RefineryQAWithoutProfile"
	local fixtures = { [actor] = copy(Template), [noPlot] = copy(Template) }
	local fixture = fixtures[actor]
	fixture.hopper = { iron = 4, frost = 2, crystal = 1 }
	fixture.backpack = { iron = 19 }
	fixture.bars = { crystal = 3 }
	fixture.bin = { frost = 2 }
	fixture.progress = 0.4
	fixture.stations.refinery = 4 -- 8 bars/s
	fixture.stations.conveyor = 4 -- 10 ore/s
	local stations = Instance.new("Model")
	stations.Name = "RefineryQAStations"
	for _, id in { "hopper", "conveyor", "refinery", "collector" } do
		local model = Instance.new("Model")
		model.Name = id
		model:SetAttribute("StationId", id)
		model.Parent = stations
		if id == "refinery" then
			local part = Instance.new("Part")
			part.Anchored = true
			part.Parent = model
			model.PrimaryPart = part
		end
	end
	local old = { Get = State.Get, GetCapacity = State.GetCapacity, State = State.Client.State, GetStations = Plot.GetStations }
	local snapshots = {}
	cleanup = function()
		State.Get, State.GetCapacity, State.Client.State = old.Get, old.GetCapacity, old.State
		Plot.GetStations = old.GetStations
		actor:Destroy(); noPlot:Destroy(); missing:Destroy(); stations:Destroy()
		result.restored = State.Get == old.Get and State.GetCapacity == old.GetCapacity
			and State.Client.State == old.State and Plot.GetStations == old.GetStations
	end
	State.Get = function(self, player)
		if fixtures[player] then return fixtures[player] end
		if player == missing then return nil end
		return old.Get(self, player)
	end
	State.GetCapacity = function(self, player)
		if fixtures[player] then return 50 end
		return old.GetCapacity(self, player)
	end
	Plot.GetStations = function(self, player)
		if player == actor then return stations end
		if player == noPlot or player == missing then return nil end
		return old.GetStations(self, player)
	end
	State.Client.State = { SetFor = function(_, player, snapshot)
		if fixtures[player] then snapshots[player] = snapshot; return end
		old.State:SetFor(player, snapshot)
	end }

	local requested = { "crystal", "frost", "iron" }
	eq(Refinery.Client:SetPriority(actor, requested), true, "owner can set refinery order")
	check(same(fixture.refinePriority, { "crystal", "frost", "iron" }), "priority saved in profile in chosen order")
	check(fixture.refinePriority ~= requested, "saved priority detached from caller input")
	requested[1] = "iron"
	eq(fixture.refinePriority[1], "crystal", "caller cannot mutate saved priority after return")
	local snapshot = snapshots[actor]
	check(snapshot ~= nil, "successful change immediately sends state")
	check(same(snapshot.hopperInventory, { iron = 4, frost = 2, crystal = 1 }), "snapshot shows only stored hopper ore")
	check(snapshot.hopperInventory ~= fixture.hopper, "snapshot hopper detached from profile")
	check(same(snapshot.refinePriority, { "crystal", "frost", "iron" }), "snapshot carries chosen order")
	check(snapshot.refinePriority ~= fixture.refinePriority, "snapshot order detached from profile")
	eq(snapshot.line.refinery.activeOre, "crystal", "current ore follows requested priority")
	eq(snapshot.line.refinery.progress, 0.4, "snapshot exposes real fractional progress")
	eq(snapshot.line.refinery.blocked, nil, "stock with collector room is running")
	eq(snapshot.hopper, 7, "existing hopper total stays correct")
	eq(snapshot.bars, 3, "carried bars stay separate from hopper")
	table.insert(result.cases, "owner priority persists and immediately replicates detached hopper and status")

	local before = copy(fixture)
	for _, malformed in { "crystal", { "crystal", "crystal" }, { "unknown" }, { 12 }, { [2] = "frost" }, { extra = "iron" } } do
		eq(Refinery:SetPriority(actor, malformed), false, "malformed order rejected")
		check(same(fixture, before), "malformed order cannot mutate production profile")
	end
	eq(Refinery:SetPriority(noPlot, { "frost" }), false, "profile without own plot denied")
	eq(Refinery:SetPriority(missing, { "frost" }), false, "missing profile denied")
	check(same(fixtures[noPlot].refinePriority, {}), "no-plot profile order unchanged")
	eq(Refinery.Client:SetPriority(actor, { "iron" }), false, "rapid repeat change rate limited")
	eq(Refinery.Client:SetPriority(noPlot, actor), false, "caller cannot supply another identity as order")
	check(same(fixture.refinePriority, { "crystal", "frost", "iron" }), "unauthorized and repeated changes leave owner's priority intact")
	table.insert(result.cases, "malformed orders, missing plot/profile, cross-owner input and rapid repeats cannot mutate priority")

	fixture.bin = {}
	fixture.progress = 0
	local made, count = Refining.run(fixture, 0.125)
	check(same(made, { crystal = 1 }) and count == 1, "first online tick refines chosen crystal first")
	made, count = Refining.run(fixture, 0.25)
	check(same(made, { frost = 2 }) and count == 2, "depleted crystal falls through to frost")
	made, count = Refining.run(fixture, 0.125)
	check(same(made, { iron = 1 }) and count == 1, "depleted frost falls through to iron")
	eq(fixture.hopper.iron, 3, "priority consumes exact hopper count")
	check(same(fixture.bin, { crystal = 1, frost = 2, iron = 1 }), "bars retain their original ore types")
	check(same(fixture.backpack, { iron = 19 }), "production leaves raw backpack ore untouched")
	check(same(fixture.bars, { crystal = 3 }), "production leaves carried bars untouched")
	check(same(fixture.refinePriority, { "crystal", "frost", "iron" }), "depletion does not erase saved choice")
	State:ReplicateNow(actor)
	eq(snapshots[actor].line.refinery.activeOre, "iron", "current ore status falls through after depletion")
	table.insert(result.cases, "real refining honors saved priority, falls through depletion, and preserves carried inventories")

	fixture.progress = 3
	fixture.bin = { iron = 2000 }
	State:ReplicateNow(actor)
	eq(snapshots[actor].line.refinery.blocked, "collector", "full collector status blocks line")
	eq(snapshots[actor].line.refinery.progress, 1, "progress is clamped for UI")
	fixture.hopper = {}
	fixture.bin = {}
	fixture.progress = -1
	State:ReplicateNow(actor)
	eq(snapshots[actor].line.refinery.blocked, "hopper", "empty hopper status blocks line")
	eq(snapshots[actor].line.refinery.activeOre, nil, "empty hopper has no active ore")
	eq(snapshots[actor].line.refinery.progress, 0, "negative progress clamped for UI")
	eq(Refinery:SetPriority(actor, {}), true, "empty order resets default")
	check(same(fixture.refinePriority, { "iron", "frost", "crystal" }), "reset restores configured default priority")
	check(same(snapshots[actor].refinePriority, { "iron", "frost", "crystal" }), "default order immediately replicated")
	table.insert(result.cases, "current hopper/collector status, bounded progress, and default reset remain accurate")

	Refinery:_connectStations(actor, stations)
	local prompt = stations:FindFirstChild("ManageRefinery", true)
	check(prompt and prompt:IsA("ProximityPrompt"), "physical refinery has management prompt")
	eq(prompt.KeyboardKeyCode, Enum.KeyCode.R, "management does not share upgrade key")
	eq(prompt.HoldDuration, 0, "management opens immediately")
	check(prompt.MaxActivationDistance > 0 and prompt.MaxActivationDistance <= 12, "management stays near refinery")
	check(prompt.UIOffset.Y > 0, "management prompt separates from upgrade prompt")
	table.insert(result.cases, "physical refinery exposes a separate nearby management prompt")
end, debug.traceback)

local cleanupOk, cleanupError = pcall(cleanup)
result.ok = ok and cleanupOk and result.restored == true
if not ok then result.error = tostring(err) end
if not cleanupOk then result.cleanupError = tostring(cleanupError) end
workspace:SetAttribute("RefineryPriorityRuntimeQA", HttpService:JSONEncode(result))
print("[RefineryPriorityRuntimeQA] " .. HttpService:JSONEncode(result))
