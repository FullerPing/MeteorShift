--!strict
-- Spec for Shared.PetsLayout: the Pets menu fits every screen, its lists are ordered the way the
-- menu shows them, and the perk lines match Config.Pets.

return function(t: any)
	local PetsLayout = require(t.shared.PetsLayout)
	local Pets = require(t.shared.Pets)
	local Config = require(t.shared.Config)

	local viewports = {
		{ "1920x1080", Vector2.new(1920, 1080), 36 },
		{ "1280x720", Vector2.new(1280, 720), 36 },
		{ "844x390", Vector2.new(844, 390), 0 },
		{ "812x375", Vector2.new(812, 375), 0 },
		{ "390x844", Vector2.new(390, 844), 47 },
		{ "360x640", Vector2.new(360, 640), 24 },
	}

	t.test("the panel and its regions fit inside every screen", function()
		for _, v in viewports do
			local l = PetsLayout.compute(v[2], v[3])
			t.ok(l.panel.x >= 0 and l.panel.x + l.panel.w <= v[2].X + 1e-6, v[1] .. " panel inside horizontally")
			t.ok(l.panel.y >= v[3] and l.panel.y + l.panel.h <= v[2].Y + 1e-6, v[1] .. " panel inside vertically")
			for _, r in { l.list, l.detail } do
				t.ok(r.x >= 0 and r.x + r.w <= l.panel.w + 1e-6, v[1] .. " region inside the panel's width")
				t.ok(r.y >= l.contentY and r.y + r.h <= l.footerY + 1e-6, v[1] .. " region between tabs and footer")
			end
			t.ok(l.columns >= 1, v[1] .. " at least one column")
		end
	end)

	t.test("the list and the detail never overlap", function()
		for _, v in viewports do
			local l = PetsLayout.compute(v[2], v[3])
			local sideBySide = l.list.x + l.list.w <= l.detail.x + 1e-6
			local stacked = l.list.y + l.list.h <= l.detail.y + 1e-6
			t.ok(sideBySide or stacked, v[1] .. " list and detail are separate")
		end
	end)

	t.test("the summary sits above the grid and the detail", function()
		for _, v in viewports do
			local l = PetsLayout.compute(v[2], v[3])
			t.ok(l.summaryH >= 40, v[1] .. " room for the equipped line and bonuses")
			t.ok(l.list.y >= l.contentY + l.summaryH and l.detail.y >= l.contentY + l.summaryH, v[1] .. " grid and detail start below the summary")
		end
		local desktop = PetsLayout.compute(Vector2.new(1280, 720), 36)
		t.ok(desktop.summaryH > PetsLayout.compute(Vector2.new(390, 844), 47).summaryH, "a desktop panel gets the two-row summary")
		t.ok(desktop.cellW > PetsLayout.compute(Vector2.new(390, 844), 47).cellW, "and roomier cards")
	end)

	t.test("wide screens put the grid beside the detail, narrow ones stack them", function()
		t.eq(PetsLayout.compute(Vector2.new(1280, 720), 36).narrow, false)
		t.eq(PetsLayout.compute(Vector2.new(390, 844), 47).narrow, true)
	end)

	t.test("the owned list puts equipped pets first, then rarest, then highest level", function()
		local saved = {
			owned = {
				pebblePup = { level = 9, xp = 0 }, packMule = { level = 1, xp = 0 }, meteorDrake = { level = 2, xp = 0 },
				scrapSparrow = { level = 4, xp = 0 }, bogus = { level = 1, xp = 0 },
			},
			equipped = { "scrapSparrow" },
			hatches = {},
		}
		local order = PetsLayout.ownedOrder(saved)
		t.eq(#order, 4, "unknown ids are dropped")
		t.eq(order[1], "scrapSparrow", "the equipped one leads")
		t.eq(order[2], "meteorDrake", "then the rarest")
		t.eq(order[3], "packMule")
		t.eq(order[4], "pebblePup")
		t.eq(#PetsLayout.ownedOrder(nil), 0)
	end)

	t.test("the index lists every pet once, commonest first", function()
		local order = PetsLayout.indexOrder()
		t.eq(#order, #Config.Pets.List)
		local seen: { [string]: boolean } = {}
		local last = 0
		local rarityRank: { [string]: number } = {}
		for index, id in Config.Pets.RarityOrder do rarityRank[id] = index end
		for _, id in order do
			t.ok(not seen[id], "listed twice")
			seen[id] = true
			local rank = rarityRank[(Pets.def(id) :: any).Rarity]
			t.ok(rank >= last, "rarity never goes backwards")
			last = rank
		end
	end)

	t.test("discovered counts the catalogue pets you own", function()
		t.eq(PetsLayout.discovered(nil), 0)
		t.eq(PetsLayout.discovered({ owned = { pebblePup = { level = 1, xp = 0 }, nope = { level = 1, xp = 0 } }, equipped = {}, hatches = {} }), 1)
	end)

	t.test("perk rows show the value now and at max level", function()
		local def = Pets.def("crystalStag") :: any
		local rows = PetsLayout.perkRows(def, 1)
		t.eq(#rows, 2)
		t.eq(rows[1].role, "crit")
		t.eq(rows[1].now, "+4%")
		t.eq(rows[1].max, "+10%")
		t.eq(rows[2].name, "Miner")
		local top = PetsLayout.perkRows(def, Config.Pets.MaxLevel)
		t.eq(top[1].now, top[1].max, "level 10 is the max")
		t.eq(PetsLayout.percent(0.075), "+7.5%")
	end)

	t.test("every pet has perk rows and a way to get it", function()
		for _, def in Config.Pets.List do
			t.ok(#PetsLayout.perkRows(def, 1) >= 1, def.Id .. " has perks")
			t.ok(def.Pass ~= nil or #PetsLayout.eggsFor(def) >= 1, def.Id .. " is in an egg or a pass")
		end
	end)
end
