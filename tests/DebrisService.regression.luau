-- Run with Lune from the repository root. Executes the real DebrisService with
-- engine/service boundaries replaced, without touching a Studio player profile.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

local modules = {}
local function load(path, extra)
	local environment = {
		Color3 = roblox.Color3,
		Enum = roblox.Enum,
		require = function(name) return assert(modules[name], "Unknown module " .. tostring(name)) end,
	}
	for key, value in extra or {} do environment[key] = value end
	return luau.load(fs.readFile(path), { debugName = path, environment = environment, injectGlobals = true })()
end
modules.Config = { Debris = load("src/shared/Config/Debris.luau") }
modules.DebrisConfig = modules.Config.Debris
if fs.isFile("src/shared/DebrisOre.luau") then
	modules.DebrisOre = load("src/shared/DebrisOre.luau", { script = { Parent = { Config = { Debris = "DebrisConfig" } } } })
end
modules.MiningPower = { power = function(tier) return 1.25 ^ (tier - 1) end }

local passed, failed = 0, 0
local function eq(actual, expected, message)
	assert(actual == expected, (message or "eq") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local function test(name, fn)
	local ok, err = pcall(fn)
	if ok then passed += 1 else failed += 1; print("FAIL " .. name .. ": " .. tostring(err)) end
end

local function fixture(tier)
	local state = { tier = tier, hp = 1, maxHp = 1, delayed = {} }
	local node = {}
	function node:Register(_, def) state.def = def; return 17 end
	function node:SetMaxHp(id, hp) eq(id, 17); state.hp = hp; state.maxHp = hp end
	function node:GetHp() return state.hp, state.maxHp end
	modules.Knit = {
		CreateService = function(def) return def end,
		GetService = function(name)
			if name == "NodeService" then return node end
			if name == "ActivityService" then return { GetActivePickaxes = function() return { { Tier = state.tier, Power = 1.25 ^ (state.tier - 1) } } end } end
			error("Unexpected service " .. name)
		end,
	}
	local shared = { Config = "Config", MiningPower = "MiningPower", DebrisOre = "DebrisOre" }
	local service = load("src/server/Services/DebrisService.luau", {
		game = { GetService = function(_, name) eq(name, "ReplicatedStorage"); return { Packages = { Knit = "Knit" }, Shared = shared } end },
		task = { delay = function(_, fn) table.insert(state.delayed, fn) end },
	})
	local fleck = { Color = roblox.Color3.fromRGB(176, 152, 112), Material = roblox.Enum.Material.Metal, Transparency = 0 }
	function fleck:IsA(name) return name == "BasePart" end
	local attrs = {}
	local part = { Parent = true, Transparency = 0, CanQuery = true, CanCollide = true }
	function part:GetDescendants() return { fleck } end
	function part:SetAttribute(name, value) attrs[name] = value end
	function part:GetAttribute(name) return attrs[name] end
	service:KnitInit()
	service:_track(part)
	local function drop()
		if state.def.OreFor then return state.def.OreFor({}) end
		return state.def.Ore, state.def.OreMult
	end
	return service, state, part, fleck, drop
end

test("blue tier-3 debris keeps its look but drops Iron at its existing yield", function()
	local _, state, part, fleck, drop = fixture(3)
	eq(part:GetAttribute("Tier"), 3)
	eq(fleck.Color, roblox.Color3.fromRGB(90, 200, 220), "blue appearance")
	local ore, mult = drop()
	eq(ore, "iron", "actual registered mining drop")
	eq(mult, 0.25, "debris yield")
	eq(state.def.Kind, "Debris", "mineral index eligibility stays debris")
end)

test("purple tier-5 debris keeps its Iron reward", function()
	local _, _, _, fleck, drop = fixture(5)
	eq(fleck.Color, roblox.Color3.fromRGB(190, 110, 255), "purple appearance")
	eq(drop(), "iron")
end)

test("untouched reroll changes the rock's tier and colour, never its Iron drop", function()
	local service, state, part, fleck, drop = fixture(1)
	eq(drop(), "iron")
	state.tier = 4
	service:_reroll()
	eq(drop(), "iron")
	eq(part:GetAttribute("Tier"), 4)
	eq(fleck.Color, roblox.Color3.fromRGB(90, 200, 220))
end)

test("damaged rocks retain their ore until respawn", function()
	local service, state, part, _, drop = fixture(3)
	state.hp = state.maxHp - 1
	state.tier = 5
	service:_reroll()
	eq(drop(), "iron")
	state.def.OnBroken()
	eq(part.CanQuery, false)
	eq(#state.delayed, 1)
	state.delayed[1]()
	eq(drop(), "iron")
	eq(part.CanQuery, true)
	eq(state.hp, 4 * 1.25 ^ 4, "existing tier HP")
end)

if modules.DebrisOre then
	local t = { shared = { DebrisOre = "DebrisOre" }, test = test, eq = eq }
	load("tests/DebrisOre.spec.luau")(t)
end

print("Debris ore regression: " .. passed .. " passed, " .. failed .. " failed")
assert(failed == 0, "Debris ore regression failures")
