local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

local modules = {}
local function load(path, extra)
	local environment = { Vector2 = roblox.Vector2, require = function(name) return assert(modules[name], "Unknown module " .. tostring(name)) end }
	for key, value in extra or {} do environment[key] = value end
	return luau.load(fs.readFile(path), { debugName = path, environment = environment, injectGlobals = true })()
end
modules.Config = { Hud = load("src/shared/Config/Hud.luau") }
modules.Aim = load("src/shared/Aim.luau")
modules.HudLayout = load("src/shared/HudLayout.luau", { script = { Parent = { Config = "Config" } } })
local passed, failed = 0, 0
local t = { shared = { Config = "Config", Aim = "Aim", HudLayout = "HudLayout" } }
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
load("tests/HudLayout.spec.luau")(t)
print("HudLayout: " .. passed .. " passed, " .. failed .. " failed")
assert(failed == 0, "HudLayout failures")
