--!strict
-- Spec for server Lib.ProfileTemplate: the saved-profile defaults (spec §12.4).
-- The version's literal value is deliberately NOT stamped here (Codes/Daily check the same
-- positive-integer rule, not a literal); this pins the shape: the version is a positive integer, every default
-- carries its documented type, deep copies are independent of the template, and
-- a rebirth reset over a fresh default profile drops no template key.
-- Expectations read from ProfileTemplate and from what RebirthReset.apply assigns.

return function(t: any)
	local Template = require(t.lib.ProfileTemplate)
	local Reset = require(t.lib.RebirthReset)

	local function copy(value: any): any
		if type(value) ~= "table" then return value end
		local out = {}
		for key, entry in value do out[key] = copy(entry) end
		return out
	end

	t.test("version is a positive integer", function()
		t.eq(type(Template.version), "number", "version is a number")
		t.ok(Template.version > 0, "a saved schema versions up from 1")
		t.eq(math.floor(Template.version), Template.version, "an integer step, not a float")
	end)

	t.test("the top level covers every saved group", function()
		for _, key in { "version", "cash", "shards", "pickaxeTier", "backpackTier",
			"pickaxeLevel", "backpackLevel", "pets", "level", "xp", "perks", "overflow",
			"backpack", "line", "hopper", "refinePriority", "bin", "progress", "bars",
			"decor", "index", "rebirths", "lastSeen", "tutorialStep", "flags", "credits",
			"receipts", "overclockLeft", "oreBoostLeft", "stats", "daily", "codes", "trialFlag" } do
			t.ok(Template[key] ~= nil, key .. " is in the schema")
		end
	end)

	t.test("scalar defaults: counters at zero, gear and progression at rank 1", function()
		for _, key in { "cash", "shards", "xp", "overflow", "progress", "rebirths",
			"lastSeen", "overclockLeft", "oreBoostLeft" } do
			t.eq(type(Template[key]), "number", key)
			t.eq(Template[key], 0, key .. " starts at zero")
		end
		for _, key in { "pickaxeTier", "backpackTier", "pickaxeLevel", "backpackLevel",
			"level", "line", "tutorialStep" } do
			t.eq(type(Template[key]), "number", key)
			t.ok(Template[key] >= 1, key .. " starts at rank 1 or above")
		end
		t.eq(Template.trialFlag, false, "the trial flag starts unset")
	end)

	t.test("inventory, index and history maps start empty", function()
		for _, key in { "backpack", "hopper", "refinePriority", "bin", "bars", "decor",
			"index", "receipts", "codes" } do
			t.eq(type(Template[key]), "table", key)
			t.eq(next(Template[key]), nil, key .. " starts empty")
		end
		for _, key in { "owned", "equipped", "hatches" } do
			t.eq(type(Template.pets[key]), "table", "pets." .. key)
			t.eq(next(Template.pets[key]), nil, "pets." .. key .. " starts empty")
		end
	end)

	t.test("the fixed-shape groups carry their documented members", function()
		local perkCount = 0
		for _ in Template.perks do perkCount += 1 end
		t.eq(perkCount, 5, "exactly the five colony perks")
		for _, key in { "headStart", "stationMemory", "efficientLine", "offlineTraining", "petBond" } do
			t.eq(Template.perks[key], 0, "perk " .. key .. " starts unbought")
		end
		for key, value in Template.flags do
			t.eq(type(value), "boolean", "flag " .. key)
			t.eq(value, false, "flag " .. key .. " starts unset")
		end
		for _, key in { "callMeteor", "bossMeteor", "rebirthKeep" } do
			t.eq(Template.credits[key], 0, "credit " .. key .. " waits at zero")
		end
		for _, key in { "meteorsJoined", "coresCracked", "barsSold" } do
			t.eq(Template.stats[key], 0, "stat " .. key .. " starts at zero")
		end
		t.eq(type(Template.daily.shields), "number", "daily shields are counted")
		t.eq(type(Template.daily.weekly.id), "string", "the weekly slot is blank before it is picked")
		t.eq(Template.daily.questBonusClaimed, false, "the daily bonus starts unclaimed")
	end)

	t.test("deep copies of the defaults are independent", function()
		local a, b = copy(Template), copy(Template)
		a.cash, a.backpack.iron, a.flags.firstMeteor = 25e6, 40, true
		t.eq(b.cash, 0, "a second copy keeps its own scalars")
		t.eq(next(b.backpack), nil, "a second copy keeps its own maps")
		t.eq(b.flags.firstMeteor, false, "a second copy keeps its own flags")
		t.eq(Template.cash, 0, "the template itself is not in the copy chain")
		t.eq(next(Template.backpack), nil, "nor is any of its maps")
	end)

	t.test("a rebirth reset drops no template key", function()
		local before = copy(Template)
		local data = copy(Template)
		data.cash, data.backpack.iron, data.hopper.iron, data.progress = 25e6, 40, 140, 0.9
		Reset.apply(data, 1000)
		local templateKeys = 0
		for key in before do
			templateKeys += 1
			t.ok(data[key] ~= nil, key .. " survives the rebirth")
		end
		for _, key in { "backpack", "hopper", "bin", "bars", "decor" } do
			t.eq(type(data[key]), "table", key .. " is zeroed, never removed")
			t.eq(next(data[key]), nil, key .. " is emptied in place")
		end
		local dataKeys = 0
		for _ in data do dataKeys += 1 end
		t.eq(dataKeys, templateKeys, "apply only assigns existing keys (RebirthReset lines 23-36)")
		t.eq(data.cash, before.cash, "cash returns to the default read from Template.cash")
		t.eq(data.lastSeen, 1000, "the offline checkpoint is refreshed")
		for key, value in before do
			if type(value) ~= "table" then
				t.eq(Template[key], value, "the reset left the " .. key .. " default alone")
			end
		end
	end)

	t.test("keep-everything preserves the whole shape too", function()
		local data = copy(Template)
		Reset.apply(data, 1000, true)
		local templateKeys, dataKeys = 0, 0
		for key in Template do
			templateKeys += 1
			t.ok(data[key] ~= nil, key)
		end
		for _ in data do dataKeys += 1 end
		t.eq(dataKeys, templateKeys, "same top-level shape")
		t.eq(data.overflow, 0, "only the paid-out overstay counter moves")
		t.eq(data.lastSeen, 1000, "and the checkpoint")
	end)
end
