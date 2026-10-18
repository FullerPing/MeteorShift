--!strict
-- Spec for Shared.Phase: the meteor state vocabulary (spec §5.1) is the wire
-- contract the server replicates and clients/Telemetry key off. These cases
-- lock the six names and prove the table cannot be edited at runtime.

return function(t: any)
	local Phase = require(t.shared.Phase)

	t.test("exactly six states, each value a string equal to its key", function()
		local count, names = 0, {}
		for key, value in Phase do
			count += 1
			t.eq(type(value), "string", key .. " value is a string")
			t.eq(value, key, key .. " value matches its key")
			table.insert(names, value)
		end
		t.eq(count, 6, "six states, no extras")
		table.sort(names)
		local expected = { "Active", "Cleanup", "Cooled", "CoreCracked", "Countdown", "Impact" }
		for i, name in expected do
			t.eq(names[i], name, "sorted state " .. i)
		end
	end)

	t.test("the documented phases are readable and nothing else is", function()
		for _, name in { "Countdown", "Impact", "Active", "CoreCracked", "Cooled", "Cleanup" } do
			t.eq(Phase[name], name, name)
		end
		t.eq(Phase.Exploded, nil, "no off-contract state")
	end)

	t.test("the table is frozen", function()
		local okWrite = pcall(function()
			Phase.Countdown = "Hijacked"
		end)
		t.eq(okWrite, false, "rewriting a state errors")
		local okAdd = pcall(function()
			Phase.Hijacked = "Hijacked"
		end)
		t.eq(okAdd, false, "adding a state errors")
		t.eq(Phase.Countdown, "Countdown", "the value survived the attempt")
	end)
end
