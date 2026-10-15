--!strict
-- Spec for Server.Lib.Telemetry (spec §13): custom field building, the hours-away
-- bucket, the per-minute action counter and the meteor event summary rows that
-- TelemetryService hands to Roblox AnalyticsService.

return function(t: any)
	local Telemetry = require(t.lib.Telemetry)
	local Config = require(t.shared.Config.Telemetry)

	local F1 = Enum.AnalyticsCustomFieldKeys.CustomField01.Name
	local F2 = Enum.AnalyticsCustomFieldKeys.CustomField02.Name
	local F3 = Enum.AnalyticsCustomFieldKeys.CustomField03.Name

	t.test("fields map a list onto CustomField01..03", function()
		local fields = Telemetry.fields({ "Iron", "cracked" }) :: any
		t.eq(fields[F1], "Iron")
		t.eq(fields[F2], "cracked")
		t.eq(fields[F3], nil)
	end)

	t.test("fields keep only the first three values", function()
		local fields = Telemetry.fields({ "a", "b", "c", "d" }) :: any
		t.eq(fields[F3], "c")
		local n = 0
		for _ in fields do
			n += 1
		end
		t.eq(n, 3)
	end)

	t.test("no or empty field list gives nil", function()
		t.eq(Telemetry.fields(nil), nil)
		t.eq(Telemetry.fields({}), nil)
	end)

	t.test("hours away round down to whole hours", function()
		t.eq(Telemetry.hoursAway(0, 48), "0")
		t.eq(Telemetry.hoursAway(3599, 48), "0")
		t.eq(Telemetry.hoursAway(3600, 48), "1")
		t.eq(Telemetry.hoursAway(5 * 3600 + 1800, 48), "5")
	end)

	t.test("hours away past the cap share one bucket", function()
		local cap = Config.HoursAwayCap
		t.eq(Telemetry.hoursAway((cap - 1) * 3600, cap), tostring(cap - 1))
		t.eq(Telemetry.hoursAway(cap * 3600, cap), cap .. "+")
		t.eq(Telemetry.hoursAway(30 * 24 * 3600, cap), cap .. "+")
	end)

	t.test("actions count per key and drain clears them", function()
		local counts = {}
		Telemetry.countAction(counts, "a")
		Telemetry.countAction(counts, "a")
		Telemetry.countAction(counts, "b")
		local drained = Telemetry.drainActions(counts)
		t.eq(drained.a, 2)
		t.eq(drained.b, 1)
		t.eq(next(counts), nil)
		t.eq(next(Telemetry.drainActions(counts)), nil)
	end)

	t.test("a key with no actions in the window is not drained", function()
		local counts = {}
		Telemetry.countAction(counts, "a")
		Telemetry.drainActions(counts)
		Telemetry.countAction(counts, "b")
		local drained = Telemetry.drainActions(counts)
		t.eq(drained.a, nil)
		t.eq(drained.b, 1)
	end)

	local function byName(rows: { Telemetry.Row }): { [string]: Telemetry.Row }
		local map = {}
		for _, row in rows do
			map[row.Name] = row
		end
		return map
	end

	t.test("a cracked event logs players, hitters and seconds to crack", function()
		local rows = byName(Telemetry.eventSummary({
			MeteorType = "Ice",
			Cracked = true,
			Players = 12,
			NodeHitters = 9,
			CoreHitters = 5,
			SecondsToCrack = 83.6,
		}))
		t.eq(rows.meteor_event_ended.Value, 1)
		t.eq(rows.meteor_event_players.Value, 12)
		t.eq(rows.meteor_event_node_hitters.Value, 9)
		t.eq(rows.meteor_event_core_hitters.Value, 5)
		t.eq(rows.meteor_event_seconds_to_crack.Value, 84)
		for _, row in rows do
			t.eq(row.Fields[1], "Ice")
			t.eq(row.Fields[2], "cracked")
		end
	end)

	t.test("a cooled event has no seconds to crack", function()
		local rows = byName(Telemetry.eventSummary({
			MeteorType = "Iron",
			Cracked = false,
			Players = 3,
			NodeHitters = 0,
			CoreHitters = 0,
			SecondsToCrack = nil,
		}))
		t.eq(rows.meteor_event_seconds_to_crack, nil)
		t.eq(rows.meteor_event_ended.Fields[2], "cooled")
		t.eq(rows.meteor_event_node_hitters.Value, 0)
	end)

	t.test("session minutes fall into coarse buckets", function()
		t.eq(Telemetry.sessionBucket(0), "0-2")
		t.eq(Telemetry.sessionBucket(119), "0-2")
		t.eq(Telemetry.sessionBucket(120), "2-5")
		t.eq(Telemetry.sessionBucket(9 * 60), "5-10")
		t.eq(Telemetry.sessionBucket(15 * 60), "10-20")
		t.eq(Telemetry.sessionBucket(30 * 60), "20-40")
		t.eq(Telemetry.sessionBucket(40 * 60), "40-90")
		t.eq(Telemetry.sessionBucket(5 * 3600), "90+")
		t.eq(Telemetry.sessionBucket(-5), "0-2")
	end)

	t.test("a leave is filed under the part of the meteor cycle it happened in", function()
		t.eq(Telemetry.leavePhase("Countdown"), "countdown")
		t.eq(Telemetry.leavePhase("Impact"), "meteor")
		t.eq(Telemetry.leavePhase("Active"), "meteor")
		t.eq(Telemetry.leavePhase("CoreCracked"), "aftermath")
		t.eq(Telemetry.leavePhase("Cooled"), "aftermath")
		t.eq(Telemetry.leavePhase("Cleanup"), "aftermath")
		t.eq(Telemetry.leavePhase("Nonsense"), "unknown")
	end)

	t.test("player_left carries minutes played, the cycle phase, the bucket and onboarding", function()
		local row = Telemetry.playerLeft(14 * 60 + 40, "Countdown", true)
		t.eq(row.Name, "player_left")
		t.eq(row.Value, 14)
		t.eq(row.Fields[1], "countdown")
		t.eq(row.Fields[2], "10-20")
		t.eq(row.Fields[3], "tutorial_done")
		t.eq(Telemetry.playerLeft(30, "Active", false).Fields[3], "in_tutorial")
		t.eq(Telemetry.playerLeft(30, "Active", nil).Fields[3], "unknown")
	end)

	t.test("the Studio log line names kind, event, player, value and fields", function()
		t.eq(Telemetry.line("custom", "first_core_reward", "Ana", 7, { "Iron" }), "[Telemetry] custom first_core_reward Ana 7 Iron")
		t.eq(Telemetry.line("funnel", "3 mine_node", "Ana", nil, nil), "[Telemetry] funnel 3 mine_node Ana")
	end)
end
