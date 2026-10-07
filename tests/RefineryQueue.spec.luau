--!strict
-- Saved refinery order, request validation, and the contents shown by its GUI.

return function(t: any)
	local module = t.shared:FindFirstChild("RefineryQueue")
	t.test("refinery queue exposes saved priority and live contents", function()
		t.ok(module, "refinery queue module missing")
	end)
	if not module then return end
	local Queue = require(module)

	local function ids(actual: { string }, expected: { string })
		t.eq(#actual, #expected)
		for index, id in expected do t.eq(actual[index], id) end
	end

	t.test("default order keeps the existing refinery order", function()
		ids(Queue.order(nil), { "iron", "frost", "crystal", "alien" })
	end)

	t.test("saved choices come first without duplicates or unknown preferred ids", function()
		ids(Queue.order({ "crystal", "crystal", 17, "unknown", "frost" }), { "crystal", "frost", "iron", "alien" })
	end)

	t.test("malformed saved priority falls back without losing ore types", function()
		for _, malformed in { false, 42, "crystal", { label = "frost" } } do
			ids(Queue.order(malformed), { "iron", "frost", "crystal", "alien" })
		end
	end)

	t.test("future positive stock joins the configured ids alphabetically", function()
		ids(Queue.order({ "frost" }, {
			zeta = 3, amber = 2, iron = 9, empty = 0, invalid = -2, nan = 0 / 0, infinite = math.huge, [1] = 4,
		}), { "frost", "iron", "crystal", "alien", "amber", "zeta" })
	end)

	t.test("valid client priorities normalize partial and reset choices", function()
		ids(Queue.validate({ "crystal" }), { "crystal", "iron", "frost", "alien" })
		ids(Queue.validate({ "frost", "crystal", "iron" }), { "frost", "crystal", "iron", "alien" })
		ids(Queue.validate({}), { "iron", "frost", "crystal", "alien" })
	end)

	t.test("client priorities reject holes dictionaries duplicates and unknown ids", function()
		for _, malformed in {
			false, 42, "iron", { "iron", "iron" }, { "unknown" }, { 9 },
			{ [1] = "iron", [3] = "crystal" }, { [0] = "iron" }, { [1.5] = "iron" },
			{ "iron", label = "frost" }, { "iron", "frost", "crystal", "iron" },
		} do
			t.eq(Queue.validate(malformed), nil, "malformed priority was accepted")
		end
		t.eq(Queue.validate(nil), nil)
	end)

	t.test("returned order never mutates or aliases saved priority", function()
		local priority = { "crystal", "frost" }
		local normalized = Queue.validate(priority)
		t.ok(normalized)
		normalized[1] = "changed"
		t.eq(priority[1], "crystal")
		t.eq(#priority, 2)
		local ordered = Queue.order(priority)
		ordered[2] = "changed"
		t.eq(priority[2], "frost")
	end)

	t.test("refinery contents include waiting ore and stored bars only", function()
		local rows = Queue.rows({ iron = 8, crystal = 2 }, { frost = 5, crystal = 1 }, { "crystal" })
		t.eq(#rows, 3)
		t.eq(rows[1].id, "crystal")
		t.eq(rows[1].name, "Crystal")
		t.eq(rows[1].ore, 2)
		t.eq(rows[1].bars, 1)
		t.eq(rows[2].id, "iron")
		t.eq(rows[2].ore, 8)
		t.eq(rows[2].bars, 0)
		t.eq(rows[3].id, "frost")
		t.eq(rows[3].ore, 0)
		t.eq(rows[3].bars, 5)
	end)

	t.test("empty or invalid contents cannot reveal undiscovered ore rows", function()
		for _, rows in {
			Queue.rows(nil, nil, { "frost" }),
			Queue.rows("loading", false, nil),
			Queue.rows({ iron = 0, frost = -1, crystal = "3", nan = 0 / 0 }, { crystal = math.huge }, nil),
		} do t.eq(#rows, 0) end
	end)

	t.test("unknown stored types have stable names and detached counts", function()
		local hopper = { zeta = 3, amber = 2 }
		local bin = { beta = 4 }
		local rows = Queue.rows(hopper, bin, nil)
		t.eq(#rows, 3)
		t.eq(rows[1].id, "amber")
		t.eq(rows[1].name, "amber")
		t.eq(rows[2].id, "beta")
		t.eq(rows[2].bars, 4)
		t.eq(rows[3].id, "zeta")
		rows[1].ore = 99
		rows[2].bars = 99
		t.eq(hopper.amber, 2)
		t.eq(bin.beta, 4)
	end)

	t.test("next ore skips a depleted preference and falls back to queued stock", function()
		t.eq(Queue.nextOre({ iron = 10, frost = 3, crystal = 0 }, { "crystal", "frost" }), "frost")
		t.eq(Queue.nextOre({ zeta = 3, amber = 2 }, nil), "amber")
		t.eq(Queue.nextOre({ iron = 0, frost = -1, crystal = math.huge }, nil), nil)
		t.eq(Queue.nextOre(nil, nil), nil)
	end)
end
