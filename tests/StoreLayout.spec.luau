--!strict
-- Spec for the sectioned Store: the section catalog and the layout maths on phones and desktop.
return function(t: any)
	local Config = require(t.shared.Config)
	local Layout = require(t.shared.StoreLayout)
	local SIZES = { Vector2.new(320, 568), Vector2.new(390, 844), Vector2.new(844, 390), Vector2.new(1375, 659) }

	t.test("every pass and product is in exactly one store section or sold elsewhere", function()
		local seen: { [string]: string } = {}
		for key in Config.Store.Elsewhere do
			t.ok(Config.Monetization.Passes[key] ~= nil or Config.Monetization.Products[key] ~= nil, key .. " is a pass or product")
			seen[key] = "elsewhere"
		end
		for _, section in Config.Store.Sections do
			t.ok(#section.Keys > 0, section.Id .. " has cards")
			t.ok(Config.HudIcons[section.Icon] ~= nil, section.Id .. " icon exists")
			for _, key in section.Keys do
				t.ok(Config.Monetization.Passes[key] ~= nil or Config.Monetization.Products[key] ~= nil, key .. " is a pass or product")
				t.eq(seen[key], nil, key .. " is in two sections")
				seen[key] = section.Id
			end
		end
		for _, key in Config.Monetization.PassOrder do t.ok(seen[key] ~= nil, key .. " has a section") end
		for _, key in Config.Monetization.ProductOrder do t.ok(seen[key] ~= nil, key .. " has a section") end
	end)

	t.test("section ids are unique and the tabs have captions", function()
		local ids: { [string]: boolean } = {}
		for _, section in Config.Store.Sections do
			t.eq(ids[section.Id], nil, section.Id)
			ids[section.Id] = true
			if section.Tab then t.ok(#section.Tab <= 8, section.Id .. " tab caption fits") end
		end
	end)

	t.test("phone store retains readable cards and 44px purchase buttons", function()
		for _, size in SIZES do
			local g = Layout.compute(size, 58)
			for _, style in { "tile", "wide" } do
				local columns = Layout.columns(g, style, 8)
				local c = Layout.card(Layout.cardWidth(g, columns), style, g.short)
				t.ok(c.cardWidth >= 200, style .. " card copy has usable width " .. c.cardWidth)
				t.ok(c.cardWidth - c.padding * 2 >= 44, "purchase target width")
				t.ok(c.buttonHeight >= 42, "purchase target height")
				t.ok(c.textWidth >= 60, style .. " text column")
				t.ok(c.statusY + c.statusHeight + c.buttonHeight <= c.cardHeight, style .. " button inside card")
				t.ok(columns * c.cardWidth + (columns - 1) * g.gap <= g.inner, style .. " row fits")
			end
			t.ok(g.height <= size.Y - 58 - 24 or g.top ~= nil, "panel clears top bar")
			t.ok(g.listWidth + (if g.tabWidth > 0 then g.tabWidth + 10 else 0) <= g.width - 28, "list and tabs fit the panel")
		end
	end)

	t.test("one phone column, icon-only tabs on short screens, and a desktop grid", function()
		local phone = Layout.compute(Vector2.new(390, 844), 58)
		t.eq(phone.tileColumns, 1)
		t.eq(phone.wideColumns, 1)
		t.eq(phone.tabWidth, 0, "no tab strip on a narrow phone")
		local landscape = Layout.compute(Vector2.new(844, 390), 58)
		t.eq(landscape.tileColumns, 3)
		t.eq(landscape.tabCaptions, false)
		t.ok(landscape.tabWidth > 0)
		local desktop = Layout.compute(Vector2.new(1280, 720), 58)
		t.eq(desktop.tileColumns, 3)
		t.eq(desktop.wideColumns, 2)
		t.eq(desktop.tabCaptions, true)
	end)

	t.test("a lone wide card is a full-width banner", function()
		local g = Layout.compute(Vector2.new(1280, 720), 58)
		t.eq(Layout.columns(g, "wide", 1), 1)
		t.eq(Layout.columns(g, "wide", 8), 2)
		t.eq(Layout.cardWidth(g, 1), g.inner)
	end)
end
