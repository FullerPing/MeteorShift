--!strict
-- The Mineral Index as the owner's mockup: the panel, its ribbon and lip stay on screen, the controls are touch targets,
-- the grid and the side column stay inside the panel, and the minerals scroll instead of shrinking.
return function(t: any)
	local IndexLayout = require(t.shared.IndexLayout)
	local viewports = {
		Vector2.new(320, 568), Vector2.new(390, 844), Vector2.new(844, 390), Vector2.new(995, 460),
		Vector2.new(667, 375), Vector2.new(1375, 659), Vector2.new(1920, 1080),
	}

	t.test("index panel clears the inset and every screen edge", function()
		for _, viewport in viewports do
			for _, inset in { 36, 58 } do
				local p = IndexLayout.compute(viewport, inset).panel
				t.ok(p.x >= 12 and p.y - 24 >= inset, "panel and its title ribbon clear left and top")
				t.ok(p.x + p.w <= viewport.X - 12, "panel clears right")
				t.ok(p.y + p.h + 7 <= viewport.Y - 8, "panel and its lip clear bottom")
				t.ok(p.w > 0 and p.w <= 860 and p.h > 0 and p.h <= 572, "bounded panel")
			end
		end
	end)

	t.test("close, the chip and the tabs are touch targets that stay clear of each other", function()
		for _, viewport in viewports do
			for _, inset in { 36, 58 } do
				local l = IndexLayout.compute(viewport, inset)
				t.ok(l.close.w >= 44 and l.close.h >= 44, "close is a touch target")
				t.ok(l.panel.x + l.close.x + l.close.w <= viewport.X, "close stays on screen")
				t.ok(l.panel.y + l.close.y >= inset, "close clears the top bar")
				if l.chip.w > 0 then
					t.ok(l.chip.x >= IndexLayout.RibbonRight and l.chip.x + l.chip.w + 8 <= l.close.x, "chip sits between the ribbon and close")
				end
				t.ok(l.tabs.h >= 44 and l.tabWidth >= 44, "all three tabs are touch targets")
				t.ok(l.tabWidth * 3 + l.tabGap * 2 <= l.tabs.w, "tabs fit one rail")
				t.ok(l.grid.y >= l.tabs.y + l.tabs.h + 8, "grid clears the tabs")
			end
		end
	end)

	t.test("the grid and the side column stay inside the panel, above its lip", function()
		for _, viewport in viewports do
			local l = IndexLayout.compute(viewport, 58)
			for _, box in { l.grid, l.side } do
				if box.w > 0 then
					t.ok(box.x >= 12 and box.x + box.w <= l.panel.w - 12, "inside the sides")
					t.ok(box.y + box.h <= l.panel.h - 7 - 8, "above the lip")
				end
			end
			if not l.narrow then t.ok(l.grid.x + l.grid.w + 8 <= l.side.x, "grid clears the side column") end
		end
	end)

	t.test("mineral cards keep a readable width and wrap into columns", function()
		local desktop = IndexLayout.compute(Vector2.new(1920, 1080), 58)
		t.eq(desktop.columns, 2)
		t.eq(desktop.narrow, false)
		t.eq(IndexLayout.compute(Vector2.new(390, 844), 58).columns, 1)
		t.eq(IndexLayout.compute(Vector2.new(390, 844), 58).narrow, true)
		for _, viewport in viewports do
			local l = IndexLayout.compute(viewport, 58)
			t.ok(l.cardWidth >= (if l.columns > 1 then IndexLayout.MinCard else 200), "cards stay readable")
			t.eq(l.cardHeight, IndexLayout.CardHeight, "card content does not scale with screen height")
			t.ok(l.columns * l.cardWidth + (l.columns - 1) * l.gap <= l.grid.w - IndexLayout.Scrollbar, "grid clears the scrollbar")
		end
	end)

	t.test("every mineral stays reachable through the scrolling grid", function()
		local l = IndexLayout.compute(Vector2.new(390, 844), 58)
		t.eq(IndexLayout.gridHeight(l, 0), 0)
		t.eq(IndexLayout.gridHeight(l, 1), IndexLayout.CardHeight)
		t.eq(IndexLayout.gridHeight(l, 3), IndexLayout.CardHeight * 3 + l.gap * 2)
		t.ok(IndexLayout.canvasHeight(l, 4) >= IndexLayout.gridHeight(l, 4) + 40, "the odds note fits under the cards")
		local landscape = IndexLayout.compute(Vector2.new(844, 390), 58)
		t.ok(IndexLayout.canvasHeight(landscape, 4) > landscape.grid.h, "short screens scroll instead of shrinking")
	end)

	t.test("desktop panel is the mockup's size, centred beneath the top inset", function()
		local p = IndexLayout.compute(Vector2.new(1920, 1080), 58).panel
		t.eq(p.w, 860)
		t.eq(p.h, 572)
		t.near(p.x + p.w / 2, 960, 0.01)
		t.near(p.y + p.h / 2, 58 + 28 + (1080 - 58 - 28 - 15) / 2, 0.01)
	end)
end
