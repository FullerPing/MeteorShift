local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local modules = {}
local function load(path, extra)
	local environment = { Color3 = roblox.Color3, Vector2 = roblox.Vector2, require = function(name) return assert(modules[name], "Unknown module " .. tostring(name)) end }
	for key, value in extra or {} do environment[key] = value end
	return luau.load(fs.readFile(path), { debugName = path, environment = environment, injectGlobals = true })()
end
modules.Format = load("src/shared/Format.luau")
modules.HudMessages = load("src/shared/HudMessages.luau", { script = { Parent = { Format = "Format" } } })
local passed, failed = 0, 0
local t = { shared = { HudMessages = "HudMessages" } }
function t.test(name, callback)
	local ok, err = pcall(callback)
	if ok then passed += 1 else failed += 1; print("FAIL " .. name .. ": " .. tostring(err)) end
end
function t.eq(actual, expected) assert(actual == expected, "expected " .. tostring(expected) .. ", got " .. tostring(actual)) end
load("tests/HudMessages.spec.luau")(t)
assert(failed == 0, "HudMessages failures")
print("HudMessages: " .. passed .. " passed, " .. failed .. " failed")
for _, path in { "src/client/Controllers/HUDController.luau", "src/client/UI.luau", "src/shared/HudLayout.luau", "src/shared/HudMessages.luau" } do
	luau.load(fs.readFile(path), { debugName = path })
end
print("Notification modules compile")
