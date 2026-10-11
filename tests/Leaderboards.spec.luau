--!strict
return function(t: any)
	local module = t.shared:FindFirstChild("Leaderboards")
	t.test("leaderboard rules exist", function() t.ok(module, "Leaderboards missing") end)
	if not module then return end
	local Leaderboards = require(module)
	local Config = require(t.shared.Config)

	t.test("every board reads a real profile field", function()
		t.ok(#Config.Leaderboards.Boards >= 1)
		local seen = {}
		for _, board in Config.Leaderboards.Boards do
			t.ok(not seen[board.Id] and not seen[board.Store], board.Id .. " repeats an id or store")
			seen[board.Id], seen[board.Store] = true, true
			t.ok(#board.Path >= 1, board.Id .. " has no path")
		end
		local profile = { stats = { barsSold = 1234.7 }, rebirths = 3 }
		t.eq(Leaderboards.valueOf({ "stats", "barsSold" }, profile), 1234)
		t.eq(Leaderboards.valueOf({ "rebirths" }, profile), 3)
	end)

	t.test("malformed scores read as zero", function()
		t.eq(Leaderboards.valueOf({ "stats", "barsSold" }, {}), 0)
		t.eq(Leaderboards.valueOf({ "stats", "barsSold" }, { stats = 5 }), 0)
		t.eq(Leaderboards.valueOf({ "rebirths" }, { rebirths = -4 }), 0)
		t.eq(Leaderboards.valueOf({ "rebirths" }, { rebirths = 0 / 0 }), 0)
		t.eq(Leaderboards.valueOf({ "rebirths" }, { rebirths = math.huge }), 0)
		t.eq(Leaderboards.valueOf({ "rebirths" }, nil), 0)
	end)

	t.test("ranking is highest first, stable on ties, capped and skips zero", function()
		local ranked = Leaderboards.rank({
			{ userId = 3, name = "c", value = 50 },
			{ userId = 1, name = "a", value = 90 },
			{ userId = 2, name = "b", value = 50 },
			{ userId = 4, name = "d", value = 0 },
			{ userId = 5, name = "e", value = 10 },
		}, 3)
		t.eq(#ranked, 3)
		t.eq(ranked[1].name, "a")
		t.eq(ranked[2].name, "b", "ties go to the lower user id")
		t.eq(ranked[3].name, "c")
		t.eq(#Leaderboards.rank({ { userId = 1, name = "a", value = 0 } }, 10), 0)
	end)
end
