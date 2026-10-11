--!strict
-- Pixel geometry keeps the gear shop reachable on every screen: the shop is a narrow panel, and the evolution pops out
-- beside it when there is room, otherwise it stacks inside the shop.
return function(t: any)
	local EquipmentShopLayout = require(t.shared.EquipmentShopLayout)
	local viewports = {
		Vector2.new(320, 568), Vector2.new(390, 667), Vector2.new(430, 932),
		Vector2.new(667, 375), Vector2.new(844, 390), Vector2.new(932, 430),
		Vector2.new(1375, 659), Vector2.new(1920, 1080),
	}
	local function layout(viewport: Vector2, inset: number): any
		t.ok(type(EquipmentShopLayout.compute) == "function", "shop geometry compute is available")
		return EquipmentShopLayout.compute(viewport, inset)
	end

	t.test("shop panel clears the top inset and all screen edges", function()
		for _, viewport in viewports do
			for _, inset in { 36, 58 } do
				local l = layout(viewport, inset)
				local p = l.panel
				local context = tostring(viewport) .. " inset=" .. inset
				t.ok(p.x >= 12 and p.y >= inset + 12, context .. " clears left and top")
				t.ok(p.x + p.w <= viewport.X - 12, context .. " clears right")
				t.ok(p.y + p.h <= viewport.Y - 12, context .. " clears bottom")
				local maxHeight = if l.narrow then 500 else 560
				t.ok(p.w > 0 and p.w <= 560 and p.h > 0 and p.h <= maxHeight, context .. " narrow bounded panel")
			end
		end
	end)

	t.test("the evolution pops out beside the shop only when both fit", function()
		for _, viewport in viewports do
			local l = layout(viewport, 58)
			if l.popout then
				local e = l.evolvePanel
				t.ok(e.x >= l.panel.x + l.panel.w, tostring(viewport) .. " the evolution sits right of the shop")
				t.ok(e.x + e.w <= viewport.X - 12, tostring(viewport) .. " and fits on screen")
				t.ok(e.y == l.panel.y and e.h == l.panel.h, tostring(viewport) .. " and lines up with the shop")
			else
				t.ok(l.panel.x + l.panel.w <= viewport.X - 12, tostring(viewport) .. " the shop alone fits")
			end
		end
		t.ok(layout(Vector2.new(1920, 1080), 58).popout, "a desktop window pops the evolution out")
		t.ok(not layout(Vector2.new(844, 390), 58).popout, "a phone keeps it inside the shop")
		t.ok(not layout(Vector2.new(390, 667), 58).popout, "and so does a portrait phone")
	end)

	t.test("desktop shop and evolution are centered together below the inset", function()
		local l = layout(Vector2.new(1920, 1080), 58)
		t.eq(l.panel.w, 560)
		t.eq(l.panel.h, 560)
		t.eq(l.evolvePanel.w, 300)
		t.near((l.panel.x + l.evolvePanel.x + l.evolvePanel.w) / 2, 960, 0.01, "the pair is centered horizontally")
		t.near(l.panel.y + l.panel.h / 2, 569, 0.01, "center below the inset")
	end)

	t.test("tabs and footer stay outside the scrollable area with 44 px targets", function()
		for _, viewport in viewports do
			for _, inset in { 36, 58 } do
				local l = layout(viewport, inset)
				t.ok(l.padding >= 12, "visible padding")
				t.ok(l.headerH >= 44, "header holds a 44 px close target")
				t.ok(l.tabsY >= l.padding + l.headerH, "tabs clear header")
				t.ok(l.tabsH >= 44, "tabs keep minimum touch height")
				t.ok((l.panel.w - l.padding * 2 - l.gap) / 2 >= 44, "two tabs keep minimum touch width")
				t.ok(l.carouselY >= l.tabsY + l.tabsH + 6, "the screen clears the tabs")
				t.ok(l.carouselH > 0, "the screen has a visible window")
				if l.compact then
					-- phones in landscape: the footer line moves up under the wallet in the header
					t.ok(l.carouselY + l.carouselH <= l.panel.h - l.padding, "the screen clears the panel's bottom padding")
				else
					t.ok(l.carouselY + l.carouselH + 6 <= l.footerY, "the screen clears the footer")
					t.ok(l.footerY + 44 <= l.panel.h - l.padding, "footer is fully reachable")
				end
			end
		end
	end)

	t.test("narrow portraits preserve room for the wallet", function()
		for _, viewport in { Vector2.new(320, 568), Vector2.new(390, 667), Vector2.new(430, 932) } do
			local l = layout(viewport, 58)
			t.ok(l.narrow, "portrait uses the stacked composition")
			t.ok(l.headerH >= 80 and l.headerH <= 84, "wallet fits a compact second header row")
		end
	end)

	t.test("short landscape keeps a window tall enough for the controls", function()
		local smallest = layout(Vector2.new(667, 375), 58)
		t.ok(smallest.compact, "phones in landscape use the compact header")
		t.ok(smallest.carouselH >= 160, "the compact header leaves the screen room for its rows")
	end)
end
