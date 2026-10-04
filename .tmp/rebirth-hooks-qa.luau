-- Standalone QA of the real services with engine/network boundaries replaced.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local modules, services, profiles, plots = {}, {}, {}, {}
local function signal()
	local callbacks = {}
	return {
		Connect = function(_, callback) table.insert(callbacks, callback) end,
		Fire = function(_, ...) for _, callback in callbacks do callback(...) end end,
	}
end
local players = { PlayerAdded = signal(), PlayerRemoving = signal(), GetPlayers = function() return {} end }
local storage = { Packages = { Knit = "Knit", Signal = "Signal" }, Shared = { Config = "Config", Format = "Format", Price = "Price", RefineryQueue = "RefineryQueue" } }
local game = { GetService = function(_, name)
	if name == "Players" then return players end
	if name == "ReplicatedStorage" then return storage end
	if name == "RunService" then return { Heartbeat = signal() } end
	error("Unexpected engine service: " .. name)
end }
local function load(path, scriptObject)
	return luau.load(fs.readFile(path), {
		debugName = path,
		environment = {
			game = game,
			script = scriptObject or { Parent = { Parent = { Lib = { Refining = "Refining" } } } },
			require = function(name) return assert(modules[name], "Unknown module " .. tostring(name)) end,
			task = { spawn = function() end },
			os = { clock = function() return 100 end, time = function() return 1000 end },
		},
		injectGlobals = true,
	})()
end
modules.Knit = {
	CreateService = function(definition) definition.Client.Server = definition; return definition end,
	CreateSignal = signal,
	CreateProperty = function() return {} end,
	GetService = function(name) return assert(services[name]) end,
}
modules.Signal = { new = signal }
modules.Home = load("src/shared/Config/Home.luau")
modules.Config = { Home = modules.Home, Net = { StateFlushInterval = 0.1 } }
modules.Format = load("src/shared/Format.luau")
modules.Price = load("src/shared/Price.luau", { Parent = { Format = "Format" } })
modules.RefineryQueue = load("src/shared/RefineryQueue.luau", { Parent = { Config = { Home = "Home" } } })
modules.Refining = load("src/server/Lib/Refining.luau")
local template = load("src/server/Lib/ProfileTemplate.luau")
local function copy(value)
	if type(value) ~= "table" then return value end
	local result = {}
	for key, item in value do result[key] = copy(item) end
	return result
end
local assigned, loaded = signal(), signal()
local waitEffect = function() end
services.DataService = { ProfileLoaded = loaded, GetProfile = function(_, player) return profiles[player] end }
services.MonetizationService = {
	HasAutoDeposit = function() return false end,
	RefinerySpeedMult = function() return 1 end,
	OfflineCap = function() return 7200 end,
	WaitForPasses = function(player) waitEffect(player) end,
}
services.EconomyService = { SaleMultiplier = function() return 1 end }
services.PlotService = { PlotAssigned = assigned, GetStations = function(_, player) return plots[player] end }
local state = load("src/server/Services/PlayerStateService.luau")
services.PlayerStateService = state
local replications = 0
state.ReplicateNow = function() replications += 1 end
state.GetCapacity = function() return 50 end
state:KnitInit()
state:KnitStart()
local refinery = load("src/server/Services/RefineryService.luau")
refinery:KnitInit()
refinery:KnitStart()
local actor = {}
local data = copy(template)
profiles[actor] = { Data = data }
local attributes = {}
plots[actor] = {
	GetChildren = function() return {} end,
	GetAttributes = function() return table.clone(attributes) end,
	SetAttribute = function(_, key, value) attributes[key] = value end,
}
loaded:Fire(actor, profiles[actor])
local passed, failed = 0, 0
local function test(name, callback)
	local ok, message = pcall(callback)
	if ok then passed += 1; print("PASS " .. name)
	else failed += 1; print("FAIL " .. name .. ": " .. tostring(message)) end
end
test("rebirth prevents fractional ore from the old life becoming fresh ore", function()
	assert(state:AddOre(actor, "iron", 0.75) == 0)
	assert(type(state.ResetTransientInventory) == "function", "Missing rebirth transient inventory reset")
	state:ResetTransientInventory(actor)
	assert(state:AddOre(actor, "iron", 0.25) == 0, "Old fractional ore carried through rebirth")
	assert(state:AddOre(actor, "iron", 0.75) == 1, "Fresh fractional mining should continue")
end)
test("reset creates missing transient inventory and renews full-backpack notice", function()
	assert(type(state.ResetTransientInventory) == "function", "Missing rebirth transient inventory reset")
	local other = {}
	profiles[other] = { Data = copy(template) }
	state:ResetTransientInventory(other)
	assert(state:AddOre(other, "iron", 1) == 1, "Absent remainder map disabled fresh mining")
	local notices = 0
	state.Client.BackpackFull:Connect(function(player) if player == other then notices += 1 end end)
	profiles[other].Data.backpack.iron = 50
	state:AddOre(other, "iron", 1)
	state:AddOre(other, "iron", 1)
	assert(notices == 1, "Old-life notice should be rate limited")
	state:ResetTransientInventory(other)
	state:AddOre(other, "iron", 1)
	assert(notices == 2, "Old-life cooldown hid new-life full notice")
end)
test("reset removes stale collector block and priority cooldown without replication", function()
	data.hopper = { iron = 1 }
	data.bin = { iron = 1e9 }
	refinery:CatchUp(actor, 10)
	refinery:RefreshPlot(actor)
	assert(attributes.Running == false, "Full collector should block conveyor")
	data.bin = {}
	assert(refinery.Client:SetPriority(actor, { "iron" }) == true)
	assert(refinery.Client:SetPriority(actor, { "frost" }) == false)
	assert(type(refinery.ResetAfterRebirth) == "function", "Missing rebirth refinery reset")
	local before = replications
	refinery:ResetAfterRebirth(actor)
	assert(replications == before, "Reset hook duplicated state replication")
	assert(attributes.Running == true, "Stale full-collector cache blocked fresh ore")
	assert(refinery.Client:SetPriority(actor, { "frost" }) == true, "Old-life priority cooldown survived")
end)
test("pending offline time cannot process ore acquired after a rebirth", function()
	data.hopper, data.bin, data.progress, data.lastSeen = { iron = 1 }, {}, 0, 900
	waitEffect = function() data.rebirths += 1 end
	loaded:Fire(actor, profiles[actor])
	assert(data.hopper.iron == 1 and next(data.bin) == nil, "Stale offline catch-up processed fresh-life ore")
end)
test("unchanged life still receives normal offline production", function()
	data.hopper, data.bin, data.progress, data.lastSeen = { iron = 1 }, {}, 0, 900
	waitEffect = function() end
	loaded:Fire(actor, profiles[actor])
	assert(data.bin.iron == 1 and next(data.hopper) == nil, "Normal offline production was suppressed")
end)
for _, path in { "src/server/Services/PlayerStateService.luau", "src/server/Services/RefineryService.luau" } do
	luau.load(fs.readFile(path), { debugName = path })
	print("Syntax OK: " .. path)
end
print("Rebirth hooks: " .. passed .. " passed, " .. failed .. " failed")
assert(failed == 0, "Rebirth transient/offline hook failures")
