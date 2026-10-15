--!strict
return function(t: any)
	local module = t.shared:FindFirstChild("Codes")
	t.test("shared codes rules exist", function() t.ok(module, "Shared.Codes missing") end)
	if not module then return end
	local Codes = require(module)
	local Config = require(t.shared.Config)

	local list = {
		WELCOME = { Minutes = 20, Shards = 5 },
		["LAUNCH-DAY"] = { Shards = 10 },
		OLDONE = { Minutes = 5, Expires = 1000 },
		CASHLESS = {},
	}

	t.test("normalize trims, upper-cases and rejects odd input", function()
		t.eq(Codes.normalize("  welcome "), "WELCOME")
		t.eq(Codes.normalize("launch-day"), "LAUNCH-DAY")
		t.eq(Codes.normalize("wel come"), nil, "inner spaces")
		t.eq(Codes.normalize(""), nil)
		t.eq(Codes.normalize("   "), nil)
		t.eq(Codes.normalize("bad!code"), nil)
		t.eq(Codes.normalize(string.rep("A", Config.Codes.MaxLength + 1)), nil, "too long")
		t.eq(Codes.normalize(string.rep("A", Config.Codes.MaxLength)), string.rep("A", Config.Codes.MaxLength))
		t.eq(Codes.normalize(nil), nil)
		t.eq(Codes.normalize(42), nil)
		t.eq(Codes.normalize({}), nil)
	end)

	t.test("check says why a code is refused and accepts a good one", function()
		t.eq(Codes.check(list, {}, "welcome", 500).status, "ok")
		t.eq(Codes.check(list, {}, "welcome", 500).key, "WELCOME")
		t.eq(Codes.check(list, {}, "nothing", 500).status, "invalid")
		t.eq(Codes.check(list, {}, "", 500).status, "empty")
		t.eq(Codes.check(list, {}, nil, 500).status, "empty")
		t.eq(Codes.check(list, { WELCOME = true }, "Welcome", 500).status, "used")
		t.eq(Codes.check(list, {}, "oldone", 999).status, "ok", "before it expires")
		t.eq(Codes.check(list, {}, "oldone", 1000).status, "expired", "on the expiry second")
		t.eq(Codes.check(list, {}, "oldone", 5000).status, "expired")
		t.eq(Codes.check(list, { OLDONE = true }, "oldone", 5000).status, "used", "used wins over expired")
		t.eq(Codes.check({}, {}, "welcome", 500).status, "invalid", "the shipped list may be empty")
	end)

	t.test("a code with nothing in it is refused rather than marked used for nothing", function()
		t.eq(Codes.check(list, {}, "cashless", 500).status, "invalid")
	end)

	t.test("reward sizes cash from income between the floor and the ceiling", function()
		local small = Codes.reward(list.WELCOME, 0, 1e12)
		t.eq(small.cash, Config.Codes.CashFloor, "floor when income is tiny")
		t.eq(small.shards, 5)
		local scaled = Codes.reward(list.WELCOME, 100, 1e12)
		t.eq(scaled.cash, 20 * 60 * 100)
		local capped = Codes.reward(list.WELCOME, 1e9, 10000)
		t.eq(capped.cash, 10000, "ceiling wins")
		local shardsOnly = Codes.reward(list["LAUNCH-DAY"], 100, 1e12)
		t.eq(shardsOnly.cash, 0, "no Minutes, no cash")
		t.eq(shardsOnly.shards, 10)
	end)

	t.test("reward survives bad numbers", function()
		local nan = Codes.reward(list.WELCOME, 0 / 0, 0 / 0)
		t.ok(nan.cash == nan.cash and nan.cash >= 0, "NaN income and ceiling give a finite amount")
		local inf = Codes.reward(list.WELCOME, math.huge, math.huge)
		t.ok(inf.cash < math.huge, "infinite income stays finite")
	end)

	t.test("the shipped list only holds well-formed codes", function()
		for key, def in Config.Codes.List do
			t.eq(Codes.normalize(key), key, key .. " is upper case with allowed characters")
			t.ok((def.Minutes or 0) > 0 or (def.Shards or 0) > 0, key .. " gives something")
		end
	end)

	t.test("a fresh profile starts with no redeemed codes", function()
		local Template = require(t.lib.ProfileTemplate)
		t.eq(Template.version, 11)
		t.eq(next(Template.codes), nil)
	end)
end
