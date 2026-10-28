--!strict
-- Shared.GlobalEvents: the clock schedule every server shares, admin overrides and multipliers
return function(t)
	local GlobalEvents = require(t.shared.GlobalEvents)
	local Config = require(t.shared.Config)
	local E = Config.Events

	t.test("events are well formed", function()
		t.ok(E.Duration > 0 and E.Duration < E.Period)
		local kinds = { sales = true, shards = true, xp = true, relics = true, countdown = true }
		for _, list in { E.List, E.AdminOnly } do
			for _, event in list do
				for kind, value in event.Effects do
					t.ok(kinds[kind], event.Id .. " " .. kind)
					t.ok(value > 0, event.Id .. " value")
				end
			end
		end
	end)

	t.test("admin-only events start by /event but never by the schedule", function()
		local party = E.AdminOnly[1]
		t.ok(GlobalEvents.def(party.Id) ~= nil)
		for hour = 0, #E.List * 3 do
			t.ok(GlobalEvents.nextStart(hour * E.Period - 1).id ~= party.Id)
		end
		local base = 1000 * E.Period + E.Duration + 100
		local override = { id = party.Id, startsAt = base - 10, endsAt = base + 60 }
		t.eq(GlobalEvents.mult(GlobalEvents.current(base, override), "sales"), party.Effects.sales)
	end)

	t.test("the schedule runs the first Duration of every Period and rotates the list", function()
		local base = 1000 * E.Period
		local first = GlobalEvents.scheduled(base) :: any
		t.ok(first ~= nil)
		t.eq(first.startsAt, base)
		t.eq(first.endsAt, base + E.Duration)
		t.ok(GlobalEvents.scheduled(base + E.Duration - 1) ~= nil)
		t.eq(GlobalEvents.scheduled(base + E.Duration), nil)
		local second = GlobalEvents.scheduled(base + E.Period) :: any
		t.ok(second.id ~= first.id or #E.List == 1, "the next hour runs the next event")
		-- two servers asking at the same second agree
		t.eq((GlobalEvents.scheduled(base + 30) :: any).id, first.id)
	end)

	t.test("nextStart points at the coming event", function()
		local base = 1000 * E.Period
		local during = GlobalEvents.nextStart(base + 10)
		t.eq(during.startsAt, base + E.Period)
		local before = GlobalEvents.nextStart(base - 5)
		t.eq(before.startsAt, base)
	end)

	t.test("an admin override wins while it lasts, unknown ids never do", function()
		local base = 1000 * E.Period + E.Duration + 100 -- no scheduled event here
		t.eq(GlobalEvents.current(base, nil), nil)
		local override = { id = E.List[1].Id, startsAt = base - 10, endsAt = base + 60 }
		t.eq((GlobalEvents.current(base, override) :: any).id, E.List[1].Id)
		t.eq(GlobalEvents.current(base + 61, override), nil)
		t.eq(GlobalEvents.current(base, { id = "ghost", startsAt = base - 1, endsAt = base + 9 }), nil)
	end)

	t.test("mult gives an event's effect and 1 otherwise", function()
		for _, event in E.List do
			local active = { id = event.Id, startsAt = 0, endsAt = 10 }
			for kind, value in event.Effects do
				t.eq(GlobalEvents.mult(active, kind), value)
			end
			t.eq(GlobalEvents.mult(active, "nothing"), 1)
		end
		t.eq(GlobalEvents.mult(nil, "sales"), 1)
	end)
end
