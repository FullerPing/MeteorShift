--!strict
-- Shared.Quests: the Foreman's quest line
return function(t)
	local Quests = require(t.shared.Quests)
	local Config = require(t.shared.Config)

	t.test("every step is well formed and ids are unique", function()
		local seen = {}
		local kinds = { event = true, level = true, rebirths = true, pickaxeTier = true, backpackTier = true, petsOwned = true, line = true }
		for _, def in Config.Quests.Line do
			t.ok(not seen[def.Id], "duplicate " .. def.Id)
			seen[def.Id] = true
			t.ok(kinds[def.Kind], def.Id .. " kind")
			t.ok(def.Target >= 1 and def.Shards >= 0 and def.Minutes >= 0, def.Id .. " numbers")
			t.ok(def.Kind ~= "event" or type(def.Event) == "string", def.Id .. " needs an Event")
			t.ok(not string.find(def.Title, "%%"), def.Id .. " title is filled")
		end
	end)

	t.test("clean repairs a missing or bad save", function()
		local s = Quests.clean(nil)
		t.eq(s.step, 1)
		t.eq(s.progress, 0)
		s = Quests.clean({ step = 0 / 0, progress = -3 })
		t.eq(s.step, 1)
		t.eq(s.progress, 0)
	end)

	t.test("event steps count only their own event and field, up to the target", function()
		local state = Quests.clean(nil)
		local first = Quests.step(state)
		t.eq(first.Kind, "event")
		t.ok(not Quests.addProgress(state, "nonsense", 1), "other events do nothing")
		t.ok(Quests.addProgress(state, first.Event, 1))
		t.eq(state.progress, 1)
		Quests.addProgress(state, first.Event, 999)
		t.eq(state.progress, first.Target)
		t.ok(not Quests.addProgress(state, first.Event, 1), "full")
		t.ok(Quests.done(first, {}, state.progress))
		-- a field-bound step ignores rocks from other fields
		for index, def in Config.Quests.Line do
			if def.Field then
				local s = { step = index, progress = 0 }
				t.ok(not Quests.addProgress(s, "fieldRock", 1, "RustWorks"))
				t.ok(Quests.addProgress(s, "fieldRock", 1, def.Field))
			end
		end
	end)

	t.test("state steps read the profile, so a step already passed is done at once", function()
		for index, def in Config.Quests.Line do
			if def.Kind == "level" then
				t.ok(not Quests.done(def, { level = def.Target - 1 }, 0))
				t.ok(Quests.done(def, { level = def.Target }, 0))
			elseif def.Kind == "petsOwned" then
				local owned = {}
				for n = 1, def.Target do owned["pet" .. n] = { level = 1, xp = 0 } end
				t.ok(Quests.done(def, { pets = { owned = owned } }, 0))
				t.ok(not Quests.done(def, { pets = { owned = {} } }, 0))
			end
			t.ok(index >= 1)
		end
	end)

	t.test("advance moves on and the line ends with no summary", function()
		local data = { quest = { step = #Config.Quests.Line, progress = 5 }, level = 1, rebirths = 0 }
		local summary = Quests.summary(data, 10, 1e6)
		t.ok(summary ~= nil)
		t.eq(summary.count, #Config.Quests.Line)
		local state = Quests.clean(data.quest)
		Quests.advance(state)
		t.eq(state.progress, 0)
		data.quest = state
		t.eq(Quests.summary(data, 10, 1e6), nil)
	end)

	t.test("rewards pay minutes of income between the floor and the ceiling", function()
		local def = Config.Quests.Line[1]
		t.eq(Quests.reward(def, 0, 1e9).cash, Config.Quests.CashFloor)
		t.eq(Quests.reward(def, 1e9, 1234).cash, 1234)
		t.eq(Quests.reward(def, 10, 1e9).cash, math.max(Config.Quests.CashFloor, def.Minutes * 60 * 10))
		t.eq(Quests.reward(def, 0 / 0, 0 / 0).cash, 0)
	end)
end
