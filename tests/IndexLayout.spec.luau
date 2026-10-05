--!strict
-- Index controls keep screen-pixel touch targets; content scrolls without shrinking.
return function(t: any)
	local IndexLayout = require(t.shared.IndexLayout)
	local viewports = {
		Vector2.new(320, 568), Vector2.new(390, 844), Vector2.new(844, 390),
		Vector2.new(667, 375), Vector2.new(1375, 659), Vector2.new(1920, 1080),
	}

	t.test("index panel clears the inset and every screen edge", function()
		for _, viewport in viewports do
			for _, inset in { 36, 58 } do
				local p = IndexLayout.compute(viewport, inset).panel
				t.ok(p.x >= 12 and p.y >= inset + 12, "panel clears left and top")
				t.ok(p.x + p.w <= viewport.X - 12, "panel clears right")
				t.ok(p.y + p.h <= viewport.Y - 12, "panel clears bottom")
				t.ok(p.w > 0 and p.w <= 740 and p.h > 0 and p.h <= 620, "bounded panel")
			end
		end
	end)

	t.test("close and every filter keep 44 pixel targets outside the scrolling content", function()
		for _, viewport in viewports do
			for _, inset in { 36, 58 } do
				local l = IndexLayout.compute(viewport, inset)
				t.eq(l.close.w, 44)
				t.eq(l.close.h, 44)
				t.ok(l.title.x + l.title.w + 8 <= l.close.x, "title clears close")
				t.ok(l.close.x + l.close.w <= l.panel.w - l.padding, "close is inside panel")
				t.ok(l.tabs.h >= 44 and l.tabWidth >= 44, "all three filters are touch targets")
				t.ok(l.tabs.y >= l.close.y + l.close.h + 8, "filters clear header")
				t.ok(l.tabWidth * 3 + l.tabGap * 2 <= l.tabs.w, "filters fit one rail")
				t.ok(l.content.y >= l.tabs.y + l.tabs.h + 12, "content clears filters")
				t.ok(l.content.h > 0 and l.content.y + l.content.h <= l.panel.h - l.padding, "content has a bounded visible window")
			end
		end
	end)

	t.test("mineral cards wrap into readable pixel columns at the target phone sizes", function()
		for _, inset in { 36, 58 } do
			local small = IndexLayout.compute(Vector2.new(320, 568), inset)
			local portrait = IndexLayout.compute(Vector2.new(390, 844), inset)
			local landscape = IndexLayout.compute(Vector2.new(844, 390), inset)
			t.eq(small.columns, 1)
			t.eq(portrait.columns, 2)
			t.eq(landscape.columns, 4)
			for _, l in { small, portrait, landscape } do
				t.ok(l.cardWidth >= 156, "mineral name and published odds remain readable")
				t.eq(l.cardHeight, 222, "card content does not scale with screen height")
				t.ok(l.columns * l.cardWidth + (l.columns - 1) * l.gap <= l.summaryWidth, "grid clears the vertical scrollbar")
			end
		end
	end)

	t.test("summaries and every mineral stay reachable through the vertical canvas", function()
		for _, viewport in viewports do
			local l = IndexLayout.compute(viewport, 58)
			local rows = math.ceil(4 / l.columns)
			local gridHeight = IndexLayout.gridHeight(l, 4)
			t.eq(gridHeight, rows * l.cardHeight + (rows - 1) * l.gap)
			local height = IndexLayout.canvasHeight(l, 4)
			t.ok(height >= l.cardsY + gridHeight + 76, "all cards and the odds footer fit the canvas")
			t.ok(l.cardsY >= (if l.narrow then 200 else 128), "cards clear reward and tier lines")
		end
		local landscape = IndexLayout.compute(Vector2.new(844, 390), 58)
		t.ok(IndexLayout.canvasHeight(landscape, 4) > landscape.content.h, "short screens scroll instead of shrinking")
	end)

	t.test("grid and canvas support an empty page and additional rows", function()
		local l = IndexLayout.compute(Vector2.new(390, 844), 58)
		t.eq(IndexLayout.gridHeight(l, 0), 0)
		t.eq(IndexLayout.gridHeight(l, 1), 222)
		t.eq(IndexLayout.gridHeight(l, 3), 456)
		t.ok(IndexLayout.canvasHeight(l, 20) > IndexLayout.canvasHeight(l, 4), "larger catalogue stays scrollable")
	end)

	t.test("desktop panel is centered beneath the top inset", function()
		local p = IndexLayout.compute(Vector2.new(1920, 1080), 58).panel
		t.eq(p.w, 740)
		t.eq(p.h, 620)
		t.near(p.x + p.w / 2, 960, 0.01)
		t.near(p.y + p.h / 2, 569, 0.01)
	end)
end
