--!strict
-- Pixel geometry keeps the gear shop reachable on every screen: a roomy window draws the owner's 760 x 501 frame scaled
-- to the screen; a small one draws a single 560-wide column with the evolution stacked inside it.
return function(t: any)
	local EquipmentShopLayout = require(t.shared.EquipmentShopLayout)
	local viewports = {
		Vector2.new(320, 568), Vector2.new(390, 667), Vector2.new(430, 932),
		Vector2.new(667, 375), Vector2.new(844, 390), Vector2.new(932, 430),
		Vector2.new(1375, 659), Vector2.new(1920, 1080),
	}
	local function column(viewport: Vector2, inset: number): any
		t.ok(type(EquipmentShopLayout.compute) == "function", "shop geometry compute is available")
		return EquipmentShopLayout.compute(viewport, inset, false)
	end

	t.test("the single column clears the top inset and all screen edges", function()
		for _, viewport in viewports do
			for _, inset in { 36, 58 } do
				local l = column(viewport, inset)
				local p = l.panel
				local context = tostring(viewport) .. " inset=" .. inset
				t.ok(p.x >= 12 and p.y >= inset + 12, context .. " clears left and top")
				t.ok(p.x + p.w <= viewport.X - 12, context .. " clears right")
				t.ok(p.y + p.h <= viewport.Y - 12, context .. " clears bottom")
				local maxHeight = if l.narrow then 500 else 520
				t.ok(p.w > 0 and p.w <= 560 and p.h > 0 and p.h <= maxHeight, context .. " bounded panel")
				t.ok(not l.popout and l.evolvePanel.w == 0, context .. " the evolution is stacked, not a column")
				t.eq(l.contentW, p.w - l.padding * 2, context .. " the content is the panel's width")
			end
		end
	end)

	t.test("the view draws the owner's frame scaled to the screen when there is room", function()
		local desktop = EquipmentShopLayout.view(Vector2.new(1920, 1080), 58)
		t.ok(desktop.wide, "a 1080p window is wide")
		t.near(desktop.scale, 1.621, 0.01, "at 64% of the width, like the owner's frame")
		t.near(desktop.viewport.X * desktop.scale, 1920, 0.01, "the virtual viewport covers the real one")
		local small = EquipmentShopLayout.view(Vector2.new(1280, 720), 58)
		t.ok(small.wide, "a 720p window is wide")
		t.near(small.scale, 1.081, 0.01, "and scaled down")
		for _, phone in { Vector2.new(844, 390), Vector2.new(667, 375), Vector2.new(390, 844), Vector2.new(360, 640) } do
			t.ok(not EquipmentShopLayout.view(phone, 58).wide, tostring(phone) .. " keeps the single column")
		end
		-- the panel is never taller than 75% of the screen or wider than 64% of it
		for _, viewport in { Vector2.new(1920, 1080), Vector2.new(1280, 720), Vector2.new(1597, 639), Vector2.new(1024, 768) } do
			local v = EquipmentShopLayout.view(viewport, 58)
			if v.wide then
				t.ok(EquipmentShopLayout.WIDE_W * v.scale <= viewport.X * 0.6417 + 1e-3, tostring(viewport) .. " the width share")
				t.ok(EquipmentShopLayout.WIDE_H * v.scale <= viewport.Y * 0.7519 + 1e-3, tostring(viewport) .. " the height share")
			end
		end
	end)

	t.test("the wide panel is the owner's frame, centred, with the evolution as a column", function()
		local view = EquipmentShopLayout.view(Vector2.new(1920, 1080), 58)
		local l = EquipmentShopLayout.compute(view.viewport, view.inset, true)
		local R = EquipmentShopLayout.RIBBON
		t.eq(l.panel.w, 760)
		t.eq(l.panel.h + R, 501, "the body plus the ribbon above it is the frame")
		t.near(l.panel.x + l.panel.w / 2, view.viewport.X / 2, 0.01, "centred horizontally")
		t.near(l.panel.y - R + 501 / 2, view.viewport.Y / 2, 0.01, "and vertically, ribbon included")
		t.ok(l.popout and not l.narrow and not l.compact, "the wide layout")
		local e = l.evolvePanel
		t.ok(e.x >= l.padding + l.contentW, "the column sits right of the tabs and the card")
		t.ok(e.x + e.w <= l.panel.w, "and inside the panel")
		t.ok(e.y >= l.tabsY + l.tabsH, "and starts below the tabs")
		t.ok(e.y + e.h <= l.panel.h, "and ends inside the panel")
		t.ok(l.carouselY >= l.tabsY + l.tabsH and l.carouselY + l.carouselH <= l.panel.h, "the screen sits between the tabs and the bottom")
		t.ok(l.headerTop + l.headerH <= l.tabsY, "the tabs clear the header")
	end)

	t.test("the single column's header, tabs and footer keep 44 px targets", function()
		for _, viewport in viewports do
			for _, inset in { 36, 58 } do
				local l = column(viewport, inset)
				t.ok(l.padding >= 12, "visible padding")
				t.ok(l.headerH >= 44, "header holds a 44 px close target")
				t.ok(l.tabsY >= l.headerTop + l.headerH, "tabs clear the header")
				t.ok(l.tabsH >= 44, "tabs keep minimum touch height")
				t.ok((l.contentW - l.gap) / 2 >= 44, "two tabs keep minimum touch width")
				t.ok(l.carouselY >= l.tabsY + l.tabsH + 6, "the screen clears the tabs")
				t.ok(l.carouselH > 0, "the screen has a visible window")
				if l.compact then
					-- phones in landscape: the footer line moves up into the header
					t.ok(l.carouselY + l.carouselH <= l.panel.h - l.padding, "the screen clears the panel's bottom padding")
				else
					t.ok(l.carouselY + l.carouselH + 6 <= l.footerY, "the screen clears the footer")
					t.ok(l.footerY + l.footerH <= l.panel.h, "footer is fully inside the panel")
				end
			end
		end
	end)

	t.test("narrow portraits preserve room for the wallet", function()
		for _, viewport in { Vector2.new(320, 568), Vector2.new(390, 667), Vector2.new(430, 932) } do
			local l = column(viewport, 58)
			t.ok(l.narrow, "portrait uses the stacked composition")
			t.ok(l.headerH >= 80 and l.headerH <= 84, "wallet fits a compact second header row")
		end
	end)

	t.test("short landscape keeps a window tall enough for the controls", function()
		local smallest = column(Vector2.new(667, 375), 58)
		t.ok(smallest.compact, "phones in landscape use the compact header")
		t.ok(smallest.carouselH >= 160, "the compact header leaves the screen room for its rows")
	end)

	t.test("the wide screen holds the card, the quantity strip and Upgrade without scrolling", function()
		local l = EquipmentShopLayout.compute(Vector2.new(1184, 780), 36, true)
		-- ShopController gives the wide screen the content width plus its 4 px margins, and the carousel plus its margins
		local screen = EquipmentShopLayout.screen(l.contentW + 8, l.carouselH + 8, false, false, 4, true)
		t.ok(screen.canvasH <= l.carouselH + 8 + 1e-6, "the screen fits its window (" .. screen.canvasH .. " of " .. l.carouselH + 8 .. ")")
		t.eq(screen.card.w, l.contentW, "the card is as wide as the tabs")
		local body = EquipmentShopLayout.evolve(l.evolvePanel.w, false, true)
		t.ok(body.height <= l.evolvePanel.h + 1e-6, "the evolution body fits its column (" .. body.height .. " of " .. l.evolvePanel.h .. ")")
	end)
end
