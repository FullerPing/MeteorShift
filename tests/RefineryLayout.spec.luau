--!strict
-- The Foundry as the owner's mockup: three cards and the refining order stay inside the panel on every screen, the order
-- keeps at least one row, and the controls stay touch sized.
return function(t: any)
	local Layout = require(t.shared.RefineryLayout)
	local MenuFit = require(t.shared.MenuFit)
	local screens = { Vector2.new(844, 390), Vector2.new(780, 360), Vector2.new(685, 338), Vector2.new(667, 375),
		Vector2.new(320, 568), Vector2.new(390, 844), Vector2.new(1280, 720), Vector2.new(1920, 1080) }

	-- RefineryController: MenuFit.centred on the virtual screen
	local function panelFor(viewport: Vector2, inset: number): (number, number)
		local view = MenuFit.view(viewport, inset)
		local rect = MenuFit.centred(view, Layout.Size)
		return rect.w, rect.h
	end

	t.test("every piece stays inside the panel and above its lip", function()
		for _, viewport in screens do
			for _, inset in { 36, 58 } do
				local w, h = panelFor(viewport, inset)
				local g = Layout.compute(w, h)
				local name = tostring(viewport)
				for _, box in { g.tabs, g.order, g.feedback, g.upgrades, g.cards[1], g.cards[2], g.cards[3] } do
					t.ok(box.x >= 12 and box.x + box.w <= w - 12, name .. " inside the sides")
					t.ok(box.y >= 0 and box.y + box.h <= h - 7 - 6, name .. " above the lip")
				end
				t.ok(g.cards[1].y + g.cardH + 8 <= g.order.y, name .. " cards clear the order")
				t.ok(g.order.y + g.order.h <= g.feedback.y, name .. " order clears the feedback line")
				if g.short then
					t.ok(g.tabs.x >= Layout.RibbonRight and g.tabs.x + g.tabs.w <= w - 56, name .. " tabs sit between the ribbon and Close")
				else
					t.ok(g.tabs.y >= 50 and g.tabs.y + g.tabs.h <= g.cards[1].y, name .. " tabs clear the ribbon and the cards")
				end
			end
		end
	end)

	t.test("the order keeps at least one row and the actions stay touch sized", function()
		for _, viewport in screens do
			for _, inset in { 36, 58 } do
				local w, h = panelFor(viewport, inset)
				local g = Layout.compute(w, h)
				t.ok(g.order.h >= Layout.OrderHeader + g.row, tostring(viewport) .. " one order row fits")
				t.ok(g.tabs.h >= 40, "tabs are touch sized")
				t.ok(g.cardH >= 140, "cards fit their number, bar and button")
			end
		end
	end)

	t.test("roomy windows show the mockup: wells, tabs under the ribbon, three equal cards", function()
		local g = Layout.compute(860, 572)
		t.eq(g.wells, true)
		t.eq(g.short, false)
		t.eq(g.cards[1].w, g.cards[2].w)
		t.eq(g.cards[2].w, g.cards[3].w)
		t.ok(g.order.h >= Layout.OrderHeader + g.row * 3, "three ore rows show")
	end)

	t.test("short windows drop the wells and move the tabs up", function()
		local g = Layout.compute(860, 375)
		t.eq(g.wells, false)
		t.eq(g.short, true)
		t.ok(g.cards[1].y < 112, "cards move up")
	end)
end
