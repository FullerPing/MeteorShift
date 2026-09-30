--!strict
-- Spec for Shared.HudLayout and Shared.Aim (spec §10): at the phone, tablet and desktop
-- viewports the HUD buttons are at least 44 px, stay on screen under the Roblox top bar,
-- and never overlap each other, the clock, the thumbstick area, the jump button or the
-- MINE button; the MINE button sits above the jump button; every panel fits the screen.

return function(t: any)
	local HudLayout = require(t.shared.HudLayout)
	local Aim = require(t.shared.Aim)
	local Config = require(t.shared.Config)
	local Hud = Config.Hud

	local viewports = {
		{ name = "844x390", size = Vector2.new(844, 390), touch = true },
		-- Small phones in landscape, where the row and the event card are tightest
		{ name = "812x375", size = Vector2.new(812, 375), touch = true },
		{ name = "780x360", size = Vector2.new(780, 360), touch = true },
		{ name = "1334x750", size = Vector2.new(1334, 750), touch = true },
		{ name = "1920x1080", size = Vector2.new(1920, 1080), touch = false },
		-- a small desktop window, the other place the column meets the screen edge
		{ name = "1280x600 mouse", size = Vector2.new(1280, 600), touch = false },
	}

	local function screen(size: Vector2): HudLayout.Rect
		return { x = 0, y = 0, w = size.X, h = size.Y }
	end

	t.test("every HUD button is at least 44 px in both directions", function()
		for _, v in viewports do
			local layout = HudLayout.compute(v.size, v.touch)
			for _, name in Hud.ButtonOrder do
				local rect = layout.buttons[name]
				t.ok(rect.w >= Hud.MinTouch - 1e-6, v.name .. " " .. name .. " width " .. rect.w)
				t.ok(rect.h >= Hud.MinTouch - 1e-6, v.name .. " " .. name .. " height " .. rect.h)
			end
		end
	end)

	t.test("buttons are on screen, under the top bar, and do not overlap each other", function()
		for _, v in viewports do
			local layout = HudLayout.compute(v.size, v.touch)
			for i, name in Hud.ButtonOrder do
				local rect = layout.buttons[name]
				t.ok(HudLayout.inside(rect, screen(v.size)), v.name .. " " .. name .. " on screen")
				t.ok(not HudLayout.overlaps(rect, layout.topBar), v.name .. " " .. name .. " vs top bar")
				for j = i + 1, #Hud.ButtonOrder do
					local other = layout.buttons[Hud.ButtonOrder[j]]
					t.ok(not HudLayout.overlaps(rect, other), v.name .. " " .. name .. " vs " .. Hud.ButtonOrder[j])
				end
			end
		end
	end)

	t.test("buttons keep clear of the clock and the event card", function()
		for _, v in viewports do
			local layout = HudLayout.compute(v.size, v.touch)
			for _, name in Hud.ButtonOrder do
				t.ok(not HudLayout.overlaps(layout.buttons[name], layout.timer), v.name .. " " .. name .. " vs clock")
				t.ok(
					not HudLayout.overlaps(layout.buttons[name], layout.eventPanel),
					v.name .. " " .. name .. " vs event card"
				)
			end
			t.ok(not HudLayout.overlaps(layout.eventPanel, layout.topBar), v.name .. " event card vs top bar")
		end
	end)

	t.test("touch: buttons and MINE keep clear of the thumbstick and the jump button", function()
		for _, v in viewports do
			if v.touch then
				local layout = HudLayout.compute(v.size, true)
				local mine, jump, thumb = layout.mine :: HudLayout.Rect, layout.jump :: HudLayout.Rect, layout.thumbstick :: HudLayout.Rect
				for _, name in Hud.ButtonOrder do
					local rect = layout.buttons[name]
					t.ok(not HudLayout.overlaps(rect, jump), v.name .. " " .. name .. " vs jump")
					t.ok(not HudLayout.overlaps(rect, thumb), v.name .. " " .. name .. " vs thumbstick")
					t.ok(not HudLayout.overlaps(rect, mine), v.name .. " " .. name .. " vs MINE")
				end
				t.ok(not HudLayout.overlaps(mine, jump), v.name .. " MINE vs jump")
				t.ok(not HudLayout.overlaps(mine, thumb), v.name .. " MINE vs thumbstick")
				t.ok(not HudLayout.overlaps(mine, layout.eventPanel), v.name .. " MINE vs event card")
				t.ok(not HudLayout.overlaps(mine, layout.topBar), v.name .. " MINE vs top bar")
				t.ok(HudLayout.inside(mine, screen(v.size)), v.name .. " MINE on screen")
			end
		end
	end)

	t.test("the left cards clear the top bar, the clock, the thumbstick area and each other", function()
		for _, v in viewports do
			local layout = HudLayout.compute(v.size, v.touch)
			local names = { "Resources", "Equipment", "Production" }
			for i, name in names do
				local card = layout.leftCards[name]
				t.ok(HudLayout.inside(card, screen(v.size)), v.name .. " " .. name .. " on screen")
				t.ok(not HudLayout.overlaps(card, layout.topBar), v.name .. " " .. name .. " vs top bar")
				t.ok(not HudLayout.overlaps(card, layout.timer), v.name .. " " .. name .. " vs clock")
				if layout.thumbstick then
					t.ok(not HudLayout.overlaps(card, layout.thumbstick), v.name .. " " .. name .. " vs thumbstick")
				end
				for j = i + 1, #names do
					t.ok(not HudLayout.overlaps(card, layout.leftCards[names[j]]), v.name .. " " .. name .. " vs " .. names[j])
				end
				for _, button in Hud.ButtonOrder do
					t.ok(not HudLayout.overlaps(card, layout.buttons[button]), v.name .. " " .. name .. " vs " .. button)
				end
			end
		end
	end)

	t.test("touch: MINE is directly above the jump button, right edges aligned", function()
		for _, v in viewports do
			if v.touch then
				local layout = HudLayout.compute(v.size, true)
				local mine, jump = layout.mine :: HudLayout.Rect, layout.jump :: HudLayout.Rect
				t.near(mine.x + mine.w, jump.x + jump.w, 1e-6, v.name .. " right edges")
				t.near(mine.y + mine.h, jump.y - Hud.Mine.Gap, 1e-6, v.name .. " gap above jump")
				t.ok(mine.w >= Hud.MinTouch, v.name .. " MINE is a big button")
			end
		end
	end)

	t.test("mouse layout has no MINE button and keeps the SHOP column order", function()
		local layout = HudLayout.compute(Vector2.new(1920, 1080), false)
		t.eq(layout.mine, nil)
		t.eq(layout.jump, nil)
		local previousBottom = -math.huge
		for _, name in Hud.ButtonOrder do
			local rect = layout.buttons[name]
			t.ok(rect.y >= previousBottom, name .. " sits below the button before it")
			previousBottom = rect.y + rect.h
		end
	end)

	t.test("the jump button matches Roblox's small and large placement", function()
		local small = HudLayout.jumpRect(Vector2.new(844, 390))
		t.eq(small.w, 70)
		t.eq(small.x, 844 - 95)
		t.eq(small.y, 390 - 90)
		local large = HudLayout.jumpRect(Vector2.new(1334, 750))
		t.eq(large.w, 120)
		t.eq(large.x, 1334 - 170)
	end)

	t.test("panels fit the screen, under the top bar", function()
		local panels = { { "shop", 940, 600 }, { "index", 740, 520 }, { "rebirth", 620, 470 }, { "store", 620, 470 } }
		for _, v in viewports do
			for _, p in panels do
				local fit = HudLayout.panel(v.size, p[2], p[3])
				t.ok(HudLayout.inside(fit.rect, screen(v.size)), v.name .. " " .. p[1] .. " on screen")
				t.ok(fit.rect.y >= Hud.TopBarInset, v.name .. " " .. p[1] .. " under the top bar")
				t.ok(fit.rect.x >= Hud.Panel.SideMargin - 1e-6, v.name .. " " .. p[1] .. " side margin")
				t.ok(fit.scale <= 1, v.name .. " " .. p[1] .. " never scaled up")
			end
		end
	end)

	t.test("a close button reaches 44 px on screen at the smallest panel scale", function()
		local scale = HudLayout.panel(Vector2.new(844, 390), 940, 600).scale
		t.ok(HudLayout.closeSize(42, scale) * scale >= Hud.MinTouch - 1e-6)
		t.eq(HudLayout.closeSize(42, 1), 44)
	end)

	t.test("Aim picks the nearest target in reach and in front", function()
		local candidates = {
			{ distance = 5, dot = -0.8, core = false }, -- behind
			{ distance = 9, dot = 0.9, core = false },
			{ distance = 6, dot = 0.4, core = false },
			{ distance = 20, dot = 1, core = false }, -- out of reach
		}
		t.eq(Aim.nearest(candidates, 12, 0, 4), 3)
	end)

	t.test("Aim prefers an exposed core over slightly nearer crust", function()
		local candidates = {
			{ distance = 5, dot = 0.9, core = false },
			{ distance = 8, dot = 0.9, core = true },
		}
		t.eq(Aim.nearest(candidates, 12, 0, 4), 2)
		t.eq(Aim.nearest(candidates, 12, 0, 0), 1)
	end)

	t.test("Aim returns nil with nothing in reach or in front", function()
		t.eq(Aim.nearest({}, 12, 0, 4), nil)
		t.eq(Aim.nearest({ { distance = 3, dot = -0.5, core = false } }, 12, 0, 4), nil)
		t.eq(Aim.nearest({ { distance = 13, dot = 1, core = false } }, 12, 0, 4), nil)
	end)
end
