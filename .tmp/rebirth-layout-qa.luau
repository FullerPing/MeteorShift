local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local path = "src/shared/RebirthLayout.luau"
local modules = {}
local environment = {
	Vector2 = roblox.Vector2,
	require = function(name) return assert(modules[name], "Unknown module " .. tostring(name)) end,
}
modules.RebirthLayout = if fs.isFile(path) then luau.load(fs.readFile(path), {
	debugName = path, environment = environment, injectGlobals = true,
})() else {}
local passed, failed = 0, 0
local t = { shared = { RebirthLayout = "RebirthLayout" } }
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
luau.load(fs.readFile("tests/RebirthLayout.spec.luau"), {
	debugName = "RebirthLayout.spec", environment = environment, injectGlobals = true,
})()(t)
print("RebirthLayout: " .. passed .. " passed, " .. failed .. " failed")
assert(failed == 0, "RebirthLayout failures")
print("RebirthLayout and spec compile")
