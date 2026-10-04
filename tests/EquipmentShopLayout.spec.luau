--!strict
-- Pixel geometry keeps the shop controls reachable while the card carousel scrolls.
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
				local maxHeight = if l.narrow then 500 else 520
				t.ok(p.w > 0 and p.w <= 860 and p.h > 0 and p.h <= maxHeight, context .. " compact bounded panel")
			end
		end
	end)

	t.test("desktop panel is centered within the unobstructed viewport", function()
		local p = layout(Vector2.new(1920, 1080), 58).panel
		t.eq(p.w, 860)
		t.eq(p.h, 520)
		t.near(p.x + p.w / 2, 960, 0.01, "horizontal center")
		t.near(p.y + p.h / 2, 569, 0.01, "center below the inset")
	end)

	t.test("tabs and footer stay outside the scrollable card area with 44 px targets", function()
		for _, viewport in viewports do
			for _, inset in { 36, 58 } do
				local l = layout(viewport, inset)
				t.ok(l.padding >= 12, "visible padding")
				t.ok(l.headerH >= 44, "header holds a 44 px close target")
				t.ok(l.tabsY >= l.padding + l.headerH, "tabs clear header")
				t.ok(l.tabsH >= 44, "tabs keep minimum touch height")
				t.ok((l.panel.w - l.padding * 2 - l.gap * 2) / 3 >= 44, "three tabs keep minimum touch width")
				t.ok(l.carouselY >= l.tabsY + l.tabsH + 6, "carousel clears tabs")
				t.ok(l.carouselH > 0, "carousel has a visible window")
				t.ok(l.carouselY + l.carouselH + 6 <= l.footerY, "carousel clears footer")
				t.ok(l.footerY + 44 <= l.panel.h - l.padding, "footer is fully reachable")
			end
		end
	end)

	t.test("narrow portraits preserve room for the wallet and readable vertical cards", function()
		for _, viewport in { Vector2.new(320, 568), Vector2.new(390, 667), Vector2.new(430, 932) } do
			local l = layout(viewport, 58)
			t.ok(l.narrow and not l.short, "portrait uses the vertical card composition")
			t.ok(l.headerH >= 80 and l.headerH <= 84, "wallet fits a compact second header row")
			t.ok(l.cardWidth >= 240 and l.cardWidth <= l.panel.w - l.padding * 2, "one portrait card fits in width")
			t.ok(l.cardHeight >= 270 and l.cardHeight <= 300, "compact preview, name, stats and purchase remain readable")
			t.ok(l.cardHeight + 8 <= l.carouselH - 4, "portrait card canvas fits above the horizontal scrollbar")
		end
		local smallest = layout(Vector2.new(320, 568), 58)
		t.eq(smallest.cardHeight, 270, "small portrait keeps the readable minimum without vertical scrolling")
	end)

	t.test("short landscape uses wide cards with space for a real model and purchase target", function()
		for _, viewport in { Vector2.new(667, 375), Vector2.new(844, 390), Vector2.new(932, 430) } do
			for _, inset in { 36, 58 } do
				local l = layout(viewport, inset)
				t.ok(l.short and not l.narrow, "landscape uses the side by side card composition")
				t.ok(l.headerH >= 54 and l.headerH <= 64, "short header preserves carousel space")
				t.ok(l.cardWidth >= 400 and l.cardWidth <= l.panel.w - l.padding * 2, "wide card fits the carousel width")
				t.ok(l.cardHeight >= 166 and l.cardHeight <= 250, "model and right hand purchase content stay readable")
				t.ok(l.cardWidth - 128 - 48 >= 180, "model and text have separate columns")
			end
		end
		local smallest = layout(Vector2.new(667, 375), 58)
		t.ok(smallest.cardHeight > smallest.carouselH, "short screen scrolls card content without shrinking")
	end)

	t.test("desktop popup shows two compact model and stats cards side by side", function()
		for _, viewport in { Vector2.new(1375, 659), Vector2.new(1920, 1080) } do
			local l = layout(viewport, 58)
			t.ok(not l.short and not l.narrow, "desktop uses the normal side by side card composition")
			t.ok(l.headerH >= 54 and l.headerH <= 58, "desktop header keeps room for the catalogue")
			t.ok(l.cardWidth >= 345 and l.cardWidth <= 360, "desktop card has room for model and stats columns")
			t.ok(l.cardHeight >= 242 and l.cardHeight <= 250, "desktop card has a compact readable height")
			t.ok(l.cardWidth * 2 + l.gap <= l.panel.w - l.padding * 2, "two desktop cards fit beside each other")
			t.ok(l.cardHeight + 8 <= l.carouselH, "desktop card clears the horizontal scrollbar")
		end
	end)

	t.test("ordinary desktop card canvas fits the window above its horizontal scrollbar", function()
		for _, viewport in { Vector2.new(1375, 659), Vector2.new(1920, 1080) } do
			for _, inset in { 36, 58 } do
				local l = layout(viewport, inset)
				-- Studio reserves four pixels of AbsoluteWindowSize for the horizontal bar.
				local windowHeight = l.carouselH - 4
				local cardCanvasHeight = l.cardHeight + 8
				t.ok(cardCanvasHeight <= windowHeight, tostring(viewport) .. " has no unnecessary vertical scrollbar")
				t.ok(l.cardHeight >= 242, "all compact card content remains readable")
			end
		end
	end)

	t.test("short composition begins when the card window cannot hold a 242 px normal card", function()
		local normal = layout(Vector2.new(844, 514), 58)
		local shorter = layout(Vector2.new(844, 513), 58)
		t.ok(not normal.short and normal.carouselH >= 254, "normal card has its content and scrollbar clearance")
		t.ok(shorter.short and shorter.carouselH < 254, "one fewer available pixel selects the short composition")
		t.ok(normal.cardWidth < shorter.cardWidth, "short composition makes more room for horizontal content")
		t.ok(normal.cardHeight + 8 <= normal.carouselH - 4, "last normal height fits the actual scroll window")
	end)

	t.test("twenty equipment cards keep their readable width and overflow horizontally", function()
		for _, viewport in viewports do
			local l = layout(viewport, 58)
			local contentWidth = l.cardWidth * 20 + l.gap * 19
			local visibleWidth = l.panel.w - l.padding * 2
			t.ok(l.gap >= 12, "cards have distinct edges")
			t.ok(contentWidth > visibleWidth, "the carousel scrolls a large catalogue")
			t.ok(contentWidth - visibleWidth > l.cardWidth * 10, "the full catalogue remains reachable without compressing cards")
		end
	end)
end
