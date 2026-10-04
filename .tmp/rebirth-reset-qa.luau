local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local modules = {}
local shared = { Config = { Index = "Index", Rebirth = "RebirthConfig", Home = "Home" }, MineralIndex = "MineralIndex", Format = "Format", RefineryQueue = "Queue" }
local lib = { ProfileTemplate = "Template", RebirthReset = "Reset", Refining = "Refining" }
local rep = { Shared = shared, Packages = { Knit = "Knit", Signal = "Signal" } }
local function loadModule(name, path, scriptObject)
	modules[name] = luau.load(fs.readFile(path), {
		debugName = path, injectGlobals = true,
		environment = {
			Color3 = roblox.Color3,
			script = scriptObject or { Parent = shared },
			game = { GetService = function(_self, service) assert(service == "ReplicatedStorage") return rep end },
			require = function(id) return assert(modules[id], "Missing module " .. tostring(id)) end,
		},
	})()
end
loadModule("Template", "src/server/Lib/ProfileTemplate.luau")
loadModule("Format", "src/shared/Format.luau")
loadModule("Index", "src/shared/Config/Index.luau")
loadModule("Home", "src/shared/Config/Home.luau")
modules.Config = { Home = modules.Home }
local specConfig = shared.Config
rep.Shared = { Config = "Config", RefineryQueue = "Queue" }
loadModule("Queue", "src/shared/RefineryQueue.luau")
loadModule("MineralIndex", "src/shared/MineralIndex.luau", { Parent = shared })
loadModule("Refining", "src/server/Lib/Refining.luau")
loadModule("RebirthConfig", "src/shared/Config/Rebirth.luau")
loadModule("Rebirth", "src/shared/Rebirth.luau", { Parent = shared })
local resetPath = "src/server/Lib/RebirthReset.luau"
if fs.isFile(resetPath) then loadModule("Reset", resetPath, { Parent = lib }) else modules.Reset = {} end
local passed, failed = 0, 0
local t = { lib = lib, shared = shared }
function t.test(name, callback)
	local ok, err = pcall(callback)
	if ok then passed += 1 else failed += 1; print("FAIL " .. name .. ": " .. tostring(err)) end
end
function t.eq(actual, expected, message) assert(actual == expected, (message or "eq") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual)) end
function t.ok(value, message) assert(value, message or "expected truthy") end
luau.load(fs.readFile("tests/RebirthReset.spec.luau"), {
	debugName = "RebirthReset.spec", injectGlobals = true,
	environment = { require = function(id) return assert(modules[id]) end },
})()(t)
print("RebirthReset: " .. passed .. " passed, " .. failed .. " failed")
assert(failed == 0, "RebirthReset failures")

-- Execute the real service with only profile/network/equipment boundaries stubbed.
local currentData, calls = nil, {}
local function counted(name) calls[name] = (calls[name] or 0) + 1 end
local services = {
	PlayerStateService = {
		Get = function() return currentData end,
		ResetTransientInventory = function() counted("transient") end,
		ReplicateNow = function() counted("replicate") end,
	},
	ShopService = { ApplyPickaxe = function() counted("pickaxe") end },
	RefineryService = { ResetAfterRebirth = function() counted("refinery") end },
	RewardService = { Announce = function() counted("announce") end },
}
modules.Knit = {
	CreateService = function(definition) return definition end,
	CreateSignal = function() return { Fire = function() counted("notice") end } end,
	GetService = function(name) return assert(services[name]) end,
}
modules.Signal = { new = function() return { Fire = function() counted("reborn") end } end }
rep.Shared = { Format = "Format", Rebirth = "Rebirth" }
loadModule("RebirthService", "src/server/Services/RebirthService.luau", { Parent = { Parent = { Lib = { RebirthReset = "Reset" } } } })
local service = modules.RebirthService
service:KnitInit()
local player = { DisplayName = "Fixture Miner" }
local function clone(value)
	if type(value) ~= "table" then return value end
	local out = {}
	for key, item in value do out[key] = clone(item) end
	return out
end
local function equal(a, b)
	if type(a) ~= type(b) then return false end
	if type(a) ~= "table" then return a == b end
	for key, item in a do if not equal(item, b[key]) then return false end end
	for key in b do if a[key] == nil then return false end end
	return true
end
t.test("insufficient cash leaves all profile data and reset hooks untouched", function()
	currentData, calls = clone(modules.Template), {}
	currentData.cash, currentData.hopper.frost, currentData.stations.refinery = 999, 200, 6
	local before = clone(currentData)
	t.eq(service:Rebirth(player), false)
	t.ok(equal(currentData, before), "failed rebirth never resets any data")
	t.eq(calls.notice, 1)
	t.eq(calls.transient, nil)
	t.eq(calls.refinery, nil)
	t.eq(calls.replicate, nil)
end)
t.test("missing profile rejects rebirth without granting rewards", function()
	currentData, calls = nil, {}
	t.eq(service:Rebirth(player), false)
	t.eq(next(calls), nil)
end)
t.test("successful rebirth applies new policy and refreshes services once", function()
	currentData, calls = clone(modules.Template), {}
	currentData.cash, currentData.shards = 25e6, 22
	currentData.stations = { hopper = 5, conveyor = 6, refinery = 7, collector = 4 }
	currentData.backpack.iron, currentData.hopper.frost, currentData.bin.frost, currentData.bars.crystal = 25, 200, 100, 5
	for _, mineral in modules.Index.Pages.Iron.Minerals do currentData.index[mineral.Id] = 1 end
	local beforeBonus = modules.MineralIndex.cashBonus(currentData.index)
	t.eq(service:Rebirth(player), true)
	t.eq(currentData.cash, 0)
	t.eq(currentData.shards, 22)
	t.eq(currentData.stations.refinery, 7)
	t.eq(currentData.stations.hopper, 1)
	t.eq(next(currentData.hopper), nil)
	t.eq(next(currentData.bars), nil)
	t.eq(currentData.rebirths, 1)
	t.eq(modules.MineralIndex.cashBonus(currentData.index), beforeBonus)
	t.eq(modules.Rebirth.multiplier(currentData.rebirths) * beforeBonus, 2 * beforeBonus)
	for _, name in { "transient", "pickaxe", "refinery", "replicate", "announce", "reborn" } do t.eq(calls[name], 1, name) end
end)
print("Rebirth policy + service: " .. passed .. " passed, " .. failed .. " failed")
assert(failed == 0, "Rebirth service failures")
