--!strict
return function(t: any)
	local Layout = require(t.shared.StoreLayout)
	t.test("phone store retains readable cards and 44px purchase buttons", function()
		for _, size in { Vector2.new(320, 568), Vector2.new(390, 844), Vector2.new(844, 390) } do
			local g = Layout.compute(size, 58, 17)
			t.ok(g.cardWidth >= 220, "card copy has usable width")
			t.ok(g.cardWidth - g.padding * 2 >= 44, "purchase target width")
			t.ok(g.cardWidth * g.columns + (g.columns - 1) * g.gap + 2 * g.paddingList + 6 <= g.width - 28, "grid fits list")
			t.ok(g.height <= size.Y - 58 - 24, "panel clears top bar")
		end
	end)
	t.test("all seventeen store items remain reachable at maximum scroll", function()
		for _, size in { Vector2.new(320, 568), Vector2.new(390, 844), Vector2.new(844, 390), Vector2.new(1375, 659) } do
			local g = Layout.compute(size, 58, 17)
			local lastRow = math.ceil(17 / g.columns) - 1
			local buttonBottom = g.paddingList + lastRow * (g.cardHeight + g.gap) + g.cardHeight - 12
			t.ok(buttonBottom <= g.canvasHeight - g.paddingList, "last button fits canvas")
			t.ok(g.height - 126 >= 44, "visible list can expose a complete target")
		end
	end)
	t.test("store uses one phone column and expands to a desktop grid", function()
		t.eq(Layout.compute(Vector2.new(390, 844), 58, 17).columns, 1)
		t.eq(Layout.compute(Vector2.new(650, 600), 58, 17).columns, 2)
		t.eq(Layout.compute(Vector2.new(1280, 720), 58, 17).columns, 3)
	end)
end
