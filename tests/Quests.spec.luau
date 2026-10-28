--!strict
-- Shared.Quests: the Foreman's quest line
return function(t)
	local Quests = require(t.shared.Quests)
	local Config = require(t.shared.Config)

	t.test("every step is well formed and ids are unique", function()
		local seen = {}
		local kinds = { event = true, level = true, rebirths = true, pickaxeTier = true, backpackTier = true, petsOwned = true, line = true }
		local fields = {}
		for _, field in Config.Debris.Fields do fields[field.Id] = field end
		for world, line in Config.Quests.Lines do
			for _, def in line do
				t.ok(not seen[def.Id], "duplicate " .. def.Id)
				seen[def.Id] = true
				t.ok(kinds[def.Kind], def.Id .. " kind")
				t.ok(def.Target >= 1 and def.Shards >= 0 and def.Minutes >= 0, def.Id .. " numbers")
				t.ok(def.Kind ~= "event" or type(def.Event) == "string", def.Id .. " needs an Event")
				t.ok(not string.find(def.Title, "%%"), def.Id .. " title is filled")
				-- a field step names a field in its own world
				t.ok(not def.Field or (fields[def.Field] and (fields[def.Field].World or 1) == world), def.Id .. " field in world " .. world)
			end
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

	t.test("each world keeps its own line and save: World 1 profile.quest, Nebula Rift profile.riftQuest", function()
		t.eq(Quests.saveKey(1), "quest")
		t.eq(Quests.saveKey(2), "riftQuest")
		local data = { quest = { step = 3, progress = 0 }, riftQuest = { step = 1, progress = 0 }, level = 1, rebirths = 25 }
		local rift = Quests.summary(data, 10, 1e6, 2) :: any
		t.eq(rift.id, Config.Quests.RiftLine[1].Id)
		t.eq(rift.count, #Config.Quests.RiftLine)
		t.eq((Quests.summary(data, 10, 1e6) :: any).id, Config.Quests.Line[3].Id)
		-- Rift events count toward the Rift line only
		local state = Quests.clean(data.riftQuest)
		t.ok(Quests.addProgress(state, "meteorJoin", 1, nil, 2))
		t.ok(not Quests.addProgress(Quests.clean({ step = 2, progress = 0 }), "fieldRock", 1, "CometDrift", 1), "World 1 step 2 is not a field step")
	end)

	t.test("rewards pay minutes of income between the floor and the ceiling", function()
		local def = Config.Quests.Line[1]
		t.eq(Quests.reward(def, 0, 1e9).cash, Config.Quests.CashFloor)
		t.eq(Quests.reward(def, 1e9, 1234).cash, 1234)
		t.eq(Quests.reward(def, 10, 1e9).cash, math.max(Config.Quests.CashFloor, def.Minutes * 60 * 10))
		t.eq(Quests.reward(def, 0 / 0, 0 / 0).cash, 0)
	end)
end
