local fs = require("@lune/fs")
local luau = require("@lune/luau")
local path = "src/server/Lib/PlayerPolicies.luau"
local modules = {}
-- An absent implementation resolves to an empty interface so the red run
-- records each missing behavior, rather than aborting at module loading.
modules.PlayerPolicies = if fs.isFile(path) then luau.load(fs.readFile(path), { debugName = path })() else {}
local passed, failed = 0, 0
local t = { lib = { PlayerPolicies = "PlayerPolicies" } }
function t.test(name, callback)
	local ok, err = pcall(callback)
	if ok then passed += 1 else failed += 1; print("FAIL " .. name .. ": " .. tostring(err)) end
end
function t.eq(actual, expected, message)
	assert(actual == expected, (message or "eq") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
function t.ok(value, message) assert(value, message or "expected truthy") end
luau.load(fs.readFile("tests/PlayerPolicies.spec.luau"), {
	debugName = "PlayerPolicies.spec",
	environment = { require = function(name) return assert(modules[name]) end },
	injectGlobals = true,
})()(t)
print("PlayerPolicies: " .. passed .. " passed, " .. failed .. " failed")
assert(failed == 0, "PlayerPolicies failures")

-- Load the real service against only the external engine/network boundaries.
local first, second = {}, {}
local queue, calls, published = {}, {}, {}
local function signal()
	local callbacks = {}
	return {
		Connect = function(_self, callback) table.insert(callbacks, callback) end,
		Fire = function(_self, player) for _, callback in callbacks do callback(player) end end,
	}
end
local players = { PlayerAdded = signal(), PlayerRemoving = signal(), GetPlayers = function() return { first, second } end }
local policyService = {
	GetPolicyInfoForPlayerAsync = function(_self, player)
		table.insert(calls, player)
		return { ArePaidRandomItemsRestricted = player ~= first, IsPaidItemTradingAllowed = player == first }
	end,
}
modules.Knit = {
	CreateService = function(definition) return definition end,
	CreateProperty = function(default)
		return { default = default, SetFor = function(_self, player, policy) published[player] = table.clone(policy) end }
	end,
}
local service = luau.load(fs.readFile("src/server/Services/PlayerPolicyService.luau"), {
	debugName = "PlayerPolicyService",
	environment = {
		game = { GetService = function(_self, name)
			if name == "Players" then return players end
			if name == "PolicyService" then return policyService end
			if name == "ReplicatedStorage" then return { Packages = { Knit = "Knit" } } end
			error("Unexpected service " .. name)
		end },
		script = { Parent = { Parent = { Lib = { PlayerPolicies = "PlayerPolicies" } } } },
		require = function(name) return assert(modules[name]) end,
		task = {
			defer = function(callback) table.insert(queue, callback) end,
			delay = function(_seconds, callback) table.insert(queue, callback) end,
		},
	},
	injectGlobals = true,
})()
service:KnitStart()
assert(#calls == 0, "Policy requests must not block KnitStart")
assert(published[first].Status == "loading" and published[second].Status == "loading")
for _, callback in queue do callback() end
assert(calls[1] == first and calls[2] == second, "Engine policy lookup must receive each actual player")
assert(service:GetPolicyInfo(first).Status == "ready")
assert(service:CanUsePaidRandomItems(first) and service:CanTradePaidItems(first))
assert(not service:CanUsePaidRandomItems(second) and not service:CanTradePaidItems(second))
assert(published[first].IsPaidItemTradingAllowed and not published[second].IsPaidItemTradingAllowed)
players.PlayerRemoving:Fire(first)
assert(not service:CanTradePaidItems(first) and service:GetPolicyInfo(second).Status == "ready")
print("PlayerPolicyService: engine lookup, asynchronous startup, per-player publication and removal smoke passed")
