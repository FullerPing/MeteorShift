local fs = require("@lune/fs")
local luau = require("@lune/luau")

local modules = {}
local function load(path, extra)
	local environment = { require = function(name) return assert(modules[name], "Unknown module " .. tostring(name)) end }
	for key, value in extra or {} do environment[key] = value end
	return luau.load(fs.readFile(path), { debugName = path, environment = environment, injectGlobals = true })()
end
modules.Home = load("src/shared/Config/Home.luau")
modules.Config = { Home = modules.Home }
local shared = { Config = "Config", RefineryQueue = "RefineryQueue" }
function shared:FindFirstChild(name)
	return if fs.isFile("src/shared/" .. name .. ".luau") then self[name] else nil
end
if fs.isFile("src/shared/RefineryQueue.luau") then
	modules.RefineryQueue = load("src/shared/RefineryQueue.luau", { script = { Parent = { Config = { Home = "Home" } } } })
end
modules.Refining = load("src/server/Lib/Refining.luau", {
	game = { GetService = function(_, name) assert(name == "ReplicatedStorage"); return { Shared = shared } end },
})
local passed, failed = 0, 0
local t = { shared = shared, lib = { Refining = "Refining" } }
function t.test(name, callback)
	local ok, err = pcall(callback)
	if ok then passed += 1 else failed += 1; print("FAIL " .. name .. ": " .. tostring(err)) end
end
function t.eq(actual, expected, message)
	assert(actual == expected, (message or "eq") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
function t.near(actual, expected, epsilon, message)
	assert(math.abs(actual - expected) <= epsilon, (message or "near") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
function t.ok(value, message) assert(value, message or "expected truthy") end
load("tests/RefineryQueue.spec.luau")(t)
load("tests/Refining.spec.luau")(t)
print("Refinery logic: " .. passed .. " passed, " .. failed .. " failed")
assert(failed == 0, "Refinery logic failures")
