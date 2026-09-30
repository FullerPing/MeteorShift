--!strict
-- Spec for Config.Net (spec §12.3): the networking and hot-path limits are
-- registered in Config and hold the values the improvement plan fixes (State
-- flushed every 0.2 s, at most 24 live floaters), with usable effect caps.

return function(t: any)
	local Config = require(t.shared.Config)

	t.test("Config exposes Net", function()
		t.ok(type(Config.Net) == "table", "Config.Net missing")
	end)

	t.test("State flushes every 0.2 s and floaters cap at 24", function()
		t.eq(Config.Net.StateFlushInterval, 0.2)
		t.eq(Config.Net.MaxFloaters, 24)
	end)

	t.test("effect caps are positive whole numbers", function()
		for _, key in { "MaxFloaters", "MaxOreChunks", "SparkPoolSize" } do
			local value = Config.Net[key]
			t.ok(type(value) == "number" and value >= 1 and value % 1 == 0, key .. " = " .. tostring(value))
		end
	end)
end
