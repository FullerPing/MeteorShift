--!strict
-- Spec for Shared.MenuFit: on small screens a menu is laid out for a larger "virtual" screen and drawn smaller,
-- so phones show the same menu a small desktop window does instead of a cramped slice of it.

return function(t: any)
	local MenuFit = require(t.shared.MenuFit)

	local screens = {
		{ "2560x1440", Vector2.new(2560, 1440), 58 },
		{ "1920x1080", Vector2.new(1920, 1080), 58 },
		{ "1280x720", Vector2.new(1280, 720), 58 },
		{ "844x390", Vector2.new(844, 390), 58 },
		{ "749x381", Vector2.new(749, 381), 58 },
		{ "667x375", Vector2.new(667, 375), 58 },
		{ "390x844", Vector2.new(390, 844), 58 },
		{ "360x640", Vector2.new(360, 640), 58 },
	}

	t.test("desktop windows draw menus at full size", function()
		local view = MenuFit.view(Vector2.new(1280, 720), 58)
		t.eq(view.scale, 1)
		t.eq(view.viewport, Vector2.new(1280, 720))
		t.eq(view.inset, 58)
	end)

	t.test("a landscape phone gets a taller virtual screen and a smaller draw scale", function()
		local view = MenuFit.view(Vector2.new(749, 381), 58)
		t.ok(view.scale < 0.9 and view.scale >= MenuFit.MinScale, "scale " .. view.scale)
		t.near(view.viewport.Y, MenuFit.LandscapeMin.Y, 0.01)
		t.near(view.viewport.X * view.scale, 749, 0.01)
		t.near(view.inset * view.scale, 58, 0.01)
	end)

	t.test("portrait phones scale by width only", function()
		local view = MenuFit.view(Vector2.new(390, 844), 58)
		t.near(view.scale, 390 / MenuFit.PortraitMinWidth, 0.001)
	end)

	t.test("screens bigger than 1080p draw menus bigger, in proportion", function()
		t.eq(MenuFit.view(Vector2.new(1920, 1080), 58).scale, 1)
		t.near(MenuFit.view(Vector2.new(2560, 1440), 58).scale, 4 / 3, 0.001)
		t.near(MenuFit.view(Vector2.new(3440, 1440), 58).scale, 4 / 3, 0.001) -- ultrawide: the height decides
		t.eq(MenuFit.view(Vector2.new(3840, 2160), 58).scale, 2)
		t.eq(MenuFit.view(Vector2.new(7680, 4320), 58).scale, MenuFit.MaxScale)
		local view = MenuFit.view(Vector2.new(2560, 1440), 58)
		t.near(view.viewport.X, 1920, 0.01, "laid out like a 1080p screen")
	end)

	t.test("very small screens stop shrinking at the minimum scale", function()
		t.eq(MenuFit.view(Vector2.new(400, 200), 58).scale, MenuFit.MinScale)
	end)

	t.test("a virtual rect's centre lands on the matching real point", function()
		local view = MenuFit.view(Vector2.new(749, 381), 58)
		local centre = MenuFit.centre(view, { x = 100, y = 80, w = 400, h = 200 })
		t.near(centre.X, 300 * view.scale, 0.01)
		t.near(centre.Y, 180 * view.scale, 0.01)
	end)

	t.test("a centred menu keeps its natural size when it fits and stays on screen under the top bar", function()
		t.eq(MenuFit.centred(MenuFit.view(Vector2.new(1920, 1080), 58), Vector2.new(660, 640)).w, 660)
		for _, s in screens do
			local view = MenuFit.view(s[2], s[3])
			for _, natural in { Vector2.new(660, 640), Vector2.new(420, 300), Vector2.new(360, 350) } do
				local r = MenuFit.centred(view, natural)
				local k = view.scale
				t.ok(r.w <= natural.X and r.h <= natural.Y, s[1] .. " no bigger than natural")
				-- the ribbon pokes 16 px above the panel: keep it under the top bar
				t.ok((r.y - 16) * k >= s[3] - 0.5, s[1] .. " below the top bar " .. tostring(natural))
				t.ok(r.x * k >= 0 and (r.x + r.w) * k <= s[2].X + 0.5, s[1] .. " inside horizontally")
				t.ok((r.y + r.h) * k <= s[2].Y + 0.5, s[1] .. " inside vertically")
			end
		end
	end)
end
