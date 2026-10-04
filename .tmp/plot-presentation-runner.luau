local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local modules = {}
local function load(path)
	return luau.load(fs.readFile(path), {
		debugName = path,
		environment = { Color3 = roblox.Color3, require = function(name) return assert(modules[name], "Unknown module " .. tostring(name)) end },
		injectGlobals = true,
	})()
end
if fs.isFile("src/shared/PlotPresentation.luau") then modules.PlotPresentation = load("src/shared/PlotPresentation.luau") end
local shared = { PlotPresentation = "PlotPresentation" }
function shared:FindFirstChild(name) return if modules[name] then name else nil end
local passed, failed = 0, 0
local t = { shared = shared }
function t.test(name, callback)
	local ok, err = pcall(callback)
	if ok then passed += 1 else failed += 1; print("FAIL " .. name .. ": " .. tostring(err)) end
end
function t.eq(actual, expected, message) assert(actual == expected, (message or "eq") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual)) end
function t.near(actual, expected, epsilon, message) assert(math.abs(actual - expected) <= epsilon, message or "not near") end
function t.ok(value, message) assert(value, message or "expected truthy") end
load("tests/PlotPresentation.spec.luau")(t)
print("Plot presentation: " .. passed .. " passed, " .. failed .. " failed")
assert(failed == 0, "Plot presentation failures")
