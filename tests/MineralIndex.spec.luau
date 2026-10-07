--!strict
-- Spec for Shared.MineralIndex (spec §8.2): rolling a hit for a mineral, page
-- completion, the page rewards (cash bonus, titles), the published odds text and
-- the pick of rich nodes. Rolls use a deterministic rng that hands out a fixed
-- list of numbers and counts the calls. Odds, bonuses and titles are read from
-- Config.Index so a retune doesn't break these cases.

return function(t: any)
	local MineralIndex = require(t.shared.MineralIndex)
	local Index = require(t.shared.Config.Index)
	local Meteor = require(t.shared.Config.Meteor)

	-- An rng that returns `values` in order (repeating the last one) and counts its calls
	local function sequence(values: { number })
		local rng = { calls = 0 }
		function rng.next(): number
			rng.calls += 1
			return values[math.min(rng.calls, #values)]
		end
		return rng
	end

	-- Minerals of a page sorted rarest first, the order roll draws them in
	local function rarestFirst(pageId: string)
		local sorted = table.clone(Index.Pages[pageId].Minerals)
		table.sort(sorted, function(a, b)
			return a.Odds < b.Odds
		end)
		return sorted
	end

	-- An index with every mineral of these pages found `count` times
	local function completed(pageIds: { string }, count: number?): { [string]: number }
		local index = {}
		for _, pageId in pageIds do
			for _, mineral in Index.Pages[pageId].Minerals do
				index[mineral.Id] = count or 1
			end
		end
		return index
	end

	t.test("config: one page per meteor type, each with one rich-only mineral that is its rarest", function()
		local seen = {}
		for _, pageId in Index.PageOrder do
			local page = Index.Pages[pageId]
			t.ok(page, "missing page " .. pageId)
			t.eq(page.Id, pageId, "Id of " .. pageId)
			t.ok(Meteor.Types[pageId], pageId .. " is not a meteor type")
			t.ok(#page.Minerals >= 3 and #page.Minerals <= 5, pageId .. " needs 3-5 minerals (spec 8.2)")
			t.ok(page.CashBonus > 0, pageId .. " CashBonus")
			t.ok(page.Title ~= "", pageId .. " Title")
			local richOnly = 0
			for _, mineral in page.Minerals do
				t.ok(not seen[mineral.Id], "mineral id used twice: " .. mineral.Id)
				seen[mineral.Id] = true
				t.ok(mineral.Odds > 0 and mineral.Odds < 1, mineral.Id .. " odds")
				if mineral.RichOnly then
					richOnly += 1
				end
			end
			t.eq(richOnly, 1, pageId .. " rich-only minerals")
			t.ok(rarestFirst(pageId)[1].RichOnly, pageId .. ": the rarest mineral must be the rich-only one")
		end
		for pageId in Index.Pages do
			t.ok(table.find(Index.PageOrder, pageId), pageId .. " missing from PageOrder")
		end
		t.ok(Index.RichNodesPerMeteor >= 1, "RichNodesPerMeteor")
	end)

	t.test("a roll of 0 drops the rarest mineral the node allows", function()
		for _, pageId in Index.PageOrder do
			local sorted = rarestFirst(pageId)
			t.eq(MineralIndex.roll(pageId, true, sequence({ 0 }).next), sorted[1].Id, pageId .. " rich node")
			t.eq(MineralIndex.roll(pageId, false, sequence({ 0 }).next), sorted[2].Id, pageId .. " plain node")
		end
	end)

	t.test("each mineral rolls on its own, rarest first, and the first hit ends the roll", function()
		local sorted = rarestFirst("Iron")
		-- Rarest misses, second rarest hits: one drop, and no further rolls
		local rng = sequence({ 0.99, 0 })
		t.eq(MineralIndex.roll("Iron", true, rng.next), sorted[2].Id, "second rarest")
		t.eq(rng.calls, 2, "rolls stop after a hit")
		-- Only the most common one hits
		local last = {}
		for i = 1, #sorted - 1 do
			last[i] = 0.99
		end
		table.insert(last, 0)
		t.eq(MineralIndex.roll("Iron", true, sequence(last).next), sorted[#sorted].Id, "most common")
	end)

	t.test("every roll missing drops nothing; rich nodes roll every mineral, plain ones skip the rich-only one", function()
		local count = #Index.Pages.Ice.Minerals
		local rich = sequence({ 0.99 })
		t.eq(MineralIndex.roll("Ice", true, rich.next), nil, "rich node, all miss")
		t.eq(rich.calls, count, "rich node rolls")
		local plain = sequence({ 0.99 })
		t.eq(MineralIndex.roll("Ice", false, plain.next), nil, "plain node, all miss")
		t.eq(plain.calls, count - 1, "plain node rolls")
	end)

	t.test("a plain node never drops the rich-only mineral, whatever the roll", function()
		for _, pageId in Index.PageOrder do
			local richOnly = rarestFirst(pageId)[1]
			for step = 0, 99 do
				t.ok(MineralIndex.roll(pageId, false, sequence({ step / 100 }).next) ~= richOnly.Id, pageId .. " roll " .. step / 100)
			end
		end
	end)

	t.test("a mineral drops when the roll is under its odds, not at them", function()
		local common = rarestFirst("Crystal")
		local mostCommon = common[#common]
		local misses = {}
		for i = 1, #common - 1 do
			misses[i] = 0.99
		end
		local under = table.clone(misses)
		table.insert(under, mostCommon.Odds - 1e-9)
		local at = table.clone(misses)
		table.insert(at, mostCommon.Odds)
		t.eq(MineralIndex.roll("Crystal", true, sequence(under).next), mostCommon.Id, "just under the odds")
		t.eq(MineralIndex.roll("Crystal", true, sequence(at).next), nil, "exactly at the odds")
	end)

	t.test("an unknown page drops nothing and rolls nothing", function()
		local rng = sequence({ 0 })
		t.eq(MineralIndex.roll("Alien", true, rng.next), nil, "unknown page")
		t.eq(rng.calls, 0, "no rolls")
	end)

	t.test("a page is complete once every mineral on it is found", function()
		t.eq(MineralIndex.pageComplete({}, "Iron"), false, "empty index")
		local index = completed({ "Iron" })
		t.eq(MineralIndex.pageComplete(index, "Iron"), true, "all found")
		t.eq(MineralIndex.found(index, "Iron"), #Index.Pages.Iron.Minerals, "found count")
		t.eq(MineralIndex.pageComplete(index, "Ice"), false, "other page")
		index[rarestFirst("Iron")[1].Id] = nil
		t.eq(MineralIndex.pageComplete(index, "Iron"), false, "one missing")
		t.eq(MineralIndex.found(index, "Iron"), #Index.Pages.Iron.Minerals - 1, "found count, one missing")
		index[rarestFirst("Iron")[1].Id] = 0
		t.eq(MineralIndex.pageComplete(index, "Iron"), false, "a count of 0 is not found")
		t.eq(MineralIndex.pageComplete(completed({ "Iron" }), "Alien"), false, "unknown page")
		t.eq(MineralIndex.found({}, "Alien"), 0, "unknown page found count")
	end)

	t.test("the cash bonus adds each completed page's bonus to 1", function()
		local Pages = Index.Pages
		t.eq(MineralIndex.cashBonus({}), 1, "nothing completed")
		t.near(MineralIndex.cashBonus(completed({ "Iron" }, 7)), 1 + Pages.Iron.CashBonus, 1e-9, "Iron page")
		t.near(MineralIndex.cashBonus(completed({ "Iron", "Ice" })), 1 + Pages.Iron.CashBonus + Pages.Ice.CashBonus, 1e-9, "Iron and Ice pages: additive")
		t.near(
			MineralIndex.cashBonus(completed(Index.PageOrder)),
			1 + Pages.Iron.CashBonus + Pages.Ice.CashBonus + Pages.Crystal.CashBonus,
			1e-9,
			"every page"
		)
		local partial = completed({ "Ice" })
		partial[rarestFirst("Crystal")[2].Id] = 3
		t.near(MineralIndex.cashBonus(partial), 1 + Pages.Ice.CashBonus, 1e-9, "a partial page pays nothing")
	end)

	t.test("titles lists completed pages' titles in page order", function()
		local Pages = Index.Pages
		t.eq(#MineralIndex.titles({}), 0, "nothing completed")
		local ice = MineralIndex.titles(completed({ "Ice" }))
		t.eq(#ice, 1, "Ice only")
		t.eq(ice[1], Pages.Ice.Title, "Ice title")
		local both = MineralIndex.titles(completed({ "Crystal", "Iron" }))
		t.eq(#both, 2, "Iron and Crystal")
		t.eq(both[1], Pages.Iron.Title, "Iron first")
		t.eq(both[2], Pages.Crystal.Title, "Crystal last: the best")
	end)

	t.test("find returns a mineral and its page", function()
		local mineral = Index.Pages.Ice.Minerals[2]
		local found, page = MineralIndex.find(mineral.Id)
		t.eq(found, mineral, "mineral")
		t.eq(page, Index.Pages.Ice, "page")
		local none, noPage = MineralIndex.find("pebble")
		t.eq(none, nil, "unknown mineral")
		t.eq(noPage, nil, "unknown mineral's page")
	end)

	t.test("odds text publishes 1 in N, and says when a mineral needs a rich node", function()
		t.eq(MineralIndex.oddsText({ Odds = 1 / 25, RichOnly = false }), "1 in 25", "1/25")
		t.eq(MineralIndex.oddsText({ Odds = 1 / 600, RichOnly = true }), "1 in 600, rich nodes only", "1/600 rich")
		t.eq(MineralIndex.oddsText({ Odds = 1 / 2500, RichOnly = false }), "1 in 2.5K", "1/2500 through Format")
		t.eq(MineralIndex.oddsText({ Odds = 1 / 3, RichOnly = false }), "1 in 3", "1/3 rounds, never 1 in 2")
	end)

	t.test("pickRichNodes picks RichNodesPerMeteor distinct nodes in range", function()
		local want = Index.RichNodesPerMeteor
		for seed = 1, 20 do
			local random = Random.new(seed)
			local rich = MineralIndex.pickRichNodes(36, function()
				return random:NextNumber()
			end)
			local count = 0
			for node, isRich in rich do
				t.ok(isRich == true, "set value")
				t.ok(node >= 1 and node <= 36 and node == math.floor(node), "node " .. node .. " out of range")
				count += 1
			end
			t.eq(count, want, "seed " .. seed)
		end
		local edge = 0
		for node in MineralIndex.pickRichNodes(36, function()
			return 1 - 1e-12
		end) do
			t.ok(node >= 1 and node <= 36, "roll near 1: node " .. node)
			edge += 1
		end
		t.eq(edge, want, "roll near 1")
	end)

	t.test("pickRichNodes on a meteor with fewer nodes than that makes them all rich", function()
		local few = math.max(Index.RichNodesPerMeteor - 1, 0)
		local rich = MineralIndex.pickRichNodes(few, function()
			return 0.5
		end)
		local count = 0
		for _ in rich do
			count += 1
		end
		t.eq(count, few, "all nodes")
		t.eq(next(MineralIndex.pickRichNodes(0, function()
			return 0.5
		end)), nil, "no nodes")
	end)

	t.test("soft pity raises the odds of minerals not yet found, never of ones already owned", function()
		local sorted = rarestFirst("Iron")
		local rare = sorted[1]
		local calls = {}
		local function rng(): number
			table.insert(calls, 1)
			return rare.Odds * 1.5 -- misses at the plain odds, hits at 2x
		end
		t.eq(MineralIndex.roll("Iron", true, rng, {}, nil) ~= rare.Id, true, "no pity: a miss")
		t.eq(MineralIndex.roll("Iron", true, rng, {}, 2), rare.Id, "pity doubles an unfound mineral")
		t.eq(MineralIndex.roll("Iron", true, rng, { [rare.Id] = 1 }, 2) ~= rare.Id, true, "owned minerals get no pity")
	end)
end
