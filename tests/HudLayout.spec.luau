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
		{ name = "960x540 mouse", size = Vector2.new(960, 540), touch = false },
		{ name = "800x450 mouse", size = Vector2.new(800, 450), touch = false },
		{ name = "390x844 portrait", size = Vector2.new(390, 844), touch = true },
		{ name = "360x800 portrait", size = Vector2.new(360, 800), touch = true },
		{ name = "780x360 tall inset", size = Vector2.new(780, 360), touch = true, inset = 60 },
		{ name = "360x800 tall inset", size = Vector2.new(360, 800), touch = true, inset = 60 },
		{ name = "390x844 mouse portrait", size = Vector2.new(390, 844), touch = false, inset = 60 },
		{ name = "Galaxy A16 landscape", size = Vector2.new(685, 338), touch = true, inset = 58, reserveCompactNotification = true },
		{ name = "Galaxy A16 portrait", size = Vector2.new(338, 685), touch = true, inset = 58 },
		{ name = "Galaxy A16 landscape no inset", size = Vector2.new(685, 338), touch = true, inset = 0 },
		{ name = "Galaxy A16 portrait no inset", size = Vector2.new(338, 685), touch = true, inset = 0 },
		{ name = "360x780 portrait", size = Vector2.new(360, 780), touch = true, inset = 58 },
	}

	local function screen(size: Vector2): HudLayout.Rect
		return { x = 0, y = 0, w = size.X, h = size.Y }
	end

	t.test("desktop HUD matches the Figma reference frame", function()
		local l = HudLayout.compute(Vector2.new(1440, 810), false)
		t.eq(l.leftCards.Resources.x, 24)
		t.eq(l.leftCards.Resources.y, 676)
		t.eq(l.leftCards.Resources.w, 250)
		t.eq(l.leftCards.Resources.h, 116)
		t.eq(l.timer.w, 593)
		t.eq(l.timer.h, 130)
		t.eq(l.buttons.SHOP.x, 24)
		t.eq(l.buttons.SHOP.y, 280)
		t.eq(l.buttons.SHOP.w, 88)
		t.eq(l.buttons.REBIRTH.y, 368)
		t.eq(l.buttons.STORE.y, 456)
		t.eq(l.buttons.INDEX.x, 1328)
		t.eq(l.leftCards.Equipment, l.buttons.SHOP)
		t.eq(l.leftCards.Production.x, 520)
		t.eq(l.leftCards.Production.y, 712)
		t.eq(l.leftCards.Production.w, 400)
		t.eq(l.leftCards.Production.h, 82)
		t.eq(l.tutorial.x, 554)
		t.eq(l.tutorial.y, 573)
		t.eq(l.backpack.x, 1186)
		t.eq(l.backpack.y, 706)
	end)

	t.test("active HUD cards and navigation clear each other and movement controls", function()
		for _, v in viewports do
			for _, expanded in { false, true } do
				local l = HudLayout.compute(v.size, v.touch, v.inset, expanded)
				local active = {
					{ name = "wallet", rect = l.leftCards.Resources },
					{ name = "foundry", rect = l.leftCards.Production },
					{ name = "backpack", rect = l.backpack },
					{ name = "clock", rect = l.timer },
					{ name = "event", rect = l.eventPanel },
				}
				if l.tutorialVisible then table.insert(active, { name = "training", rect = l.tutorial }) end
				if l.settings then table.insert(active, { name = "settings", rect = l.settings }) end
				for _, name in Hud.ButtonOrder do table.insert(active, { name = name, rect = l.buttons[name] }) end
				for i, item in active do
					t.ok(HudLayout.inside(item.rect, screen(v.size)), v.name .. " " .. item.name .. " fits")
					local sharesTopRow = not (v.touch or l.portrait) and item.name == "settings"
					if sharesTopRow then
						t.ok(item.rect.x >= 180, v.name .. " " .. item.name .. " clears Roblox controls on the left")
					else
						t.ok(not HudLayout.overlaps(item.rect, l.topBar), v.name .. " " .. item.name .. " clears top bar")
					end
					for j = i + 1, #active do
						t.ok(not HudLayout.overlaps(item.rect, active[j].rect), v.name .. " " .. item.name .. " vs " .. active[j].name .. " expanded=" .. tostring(expanded))
					end
					for _, control in { l.mine, l.jump, l.thumbstick } do
						t.ok(not HudLayout.overlaps(item.rect, control), v.name .. " " .. item.name .. " clears movement")
					end
				end
				t.eq(l.tutorialVisible, not (v.touch and expanded))
				local foundryScale = l.leftCards.Production.w / 400
				t.ok(82 * foundryScale >= 44, v.name .. " foundry summary remains a usable target")
				local trainingScale = l.tutorial.w / 332
				t.ok(HudLayout.closeSize(34, trainingScale) * trainingScale >= 44 - 1e-6, v.name .. " training skip target")
				if l.settings then
					t.ok(l.settings.w >= 44 and l.settings.h >= 44, v.name .. " settings target")
				end
			end
		end
	end)

	t.test("expanded foundry stays on screen and clears the tutorial", function()
		for _, v in viewports do
			local l = HudLayout.compute(v.size, v.touch, v.inset, true)
			t.ok(HudLayout.inside(l.leftCards.Production, screen(v.size)), v.name .. " expanded foundry fits")
			if not v.touch then
				t.ok(not HudLayout.overlaps(l.leftCards.Production, l.tutorial), v.name .. " tutorial vs expanded foundry")
			end
		end
	end)

	t.test("brief notifications reserve visible space without covering active HUD controls", function()
		for _, v in viewports do
			for _, expanded in { false, true } do
				local l = HudLayout.compute(v.size, v.touch, v.inset, expanded, true)
				local notice = l.notification
				t.ok(HudLayout.inside(notice, screen(v.size)), v.name .. " notification fits")
				t.ok(notice.w >= 190 and notice.h >= 24, v.name .. " notification readable area")
				local protected = {
					{ name = "clock", rect = l.timer }, { name = "wallet", rect = l.leftCards.Resources },
					{ name = "foundry", rect = l.leftCards.Production }, { name = "backpack", rect = l.backpack },
					{ name = "top bar", rect = l.topBar },
				}
				if l.eventVisible then table.insert(protected, { name = "event", rect = l.eventPanel }) end
				if l.tutorialVisible then table.insert(protected, { name = "training", rect = l.tutorial }) end
				if l.settings then table.insert(protected, { name = "settings", rect = l.settings }) end
				for _, name in Hud.ButtonOrder do table.insert(protected, { name = name, rect = l.buttons[name] }) end
				for name, control in { MINE = l.mine, jump = l.jump, thumbstick = l.thumbstick } do
					table.insert(protected, { name = name, rect = control })
				end
				for _, item in protected do
					t.ok(not HudLayout.overlaps(notice, item.rect), v.name .. " notification vs " .. item.name .. " expanded=" .. tostring(expanded))
				end
				t.eq(l.eventVisible, not (v.touch and expanded and (l.portrait or v.reserveCompactNotification == true)))
			end
		end
	end)

	t.test("meteor reward notifications fit two rows without covering active HUD controls", function()
		local supported = table.clone(viewports)
		table.insert(supported, { name = "390x667 short portrait", size = Vector2.new(390, 667), touch = true })
		table.insert(supported, { name = "667x375 short landscape", size = Vector2.new(667, 375), touch = true, inset = 58 })
		for _, v in supported do
			for _, expanded in { false, true } do
				local l = HudLayout.compute(v.size, v.touch, v.inset, expanded, true, true)
				local notice = l.notification
				local context = v.name .. " reward expanded=" .. tostring(expanded)
				t.ok(HudLayout.inside(notice, screen(v.size)), context .. " fits")
				t.ok(notice.w >= 190 and notice.h >= 48, context .. " has two readable rows")
				local protected = {
					{ name = "clock", rect = l.timer }, { name = "wallet", rect = l.leftCards.Resources },
					{ name = "foundry", rect = l.leftCards.Production }, { name = "backpack", rect = l.backpack },
					{ name = "top bar", rect = l.topBar },
				}
				if l.eventVisible then table.insert(protected, { name = "event", rect = l.eventPanel }) end
				if l.tutorialVisible then table.insert(protected, { name = "training", rect = l.tutorial }) end
				if l.settings then table.insert(protected, { name = "settings", rect = l.settings }) end
				for _, name in Hud.ButtonOrder do table.insert(protected, { name = name, rect = l.buttons[name] }) end
				for name, control in { MINE = l.mine, jump = l.jump, thumbstick = l.thumbstick } do
					table.insert(protected, { name = name, rect = control })
				end
				for _, item in protected do
					t.ok(not HudLayout.overlaps(notice, item.rect), context .. " vs " .. item.name)
				end
			end
		end
	end)

	t.test("reward notifications use full height on ordinary desktop screens", function()
		local l = HudLayout.compute(Vector2.new(1440, 810), false, nil, false, true, true)
		t.eq(l.notification.h, 64)
		t.eq(l.eventVisible, true)
		t.eq(l.tutorialVisible, true)
	end)

	t.test("two reward rows replace the objective when the landscape pocket is too shallow", function()
		local size = Vector2.new(780, 360)
		local single = HudLayout.compute(size, true, 60, true, true, false)
		t.ok(single.notification.h < 48, "single-line notice can use the narrow pocket")
		t.eq(single.eventVisible, true, "single-line notice keeps the objective visible")
		local reward = HudLayout.compute(size, true, 60, true, true, true)
		t.eq(reward.notification.h, 64, "reward keeps both rows readable")
		t.eq(reward.eventVisible, false, "reward temporarily reserves the objective slot")
		t.eq(reward.notification.y, reward.eventPanel.y, "reward uses the objective row")
	end)

	t.test("training card fits and clears the other touch HUD controls", function()
		for _, v in viewports do
			local l = HudLayout.compute(v.size, v.touch, v.inset)
			t.ok(HudLayout.inside(l.tutorial, screen(v.size)), v.name .. " training fits")
			if v.touch then
				for _, rect in { l.timer, l.eventPanel, l.leftCards.Resources, l.leftCards.Production, l.mine, l.jump } do
					t.ok(not HudLayout.overlaps(l.tutorial, rect), v.name .. " training clears controls")
				end
			end
		end
	end)

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
			local names = { "Resources", "Production" }
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
		for _, name in { "SHOP", "REBIRTH", "STORE" } do
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

	t.test("backpack popup stays above its HUD anchor across foundry and notice states", function()
		t.ok(type(HudLayout.backpackPanel) == "function", "backpack menu has no anchored popup layout")
		local supported = {
			{ name = "1440x810 desktop", size = Vector2.new(1440, 810), touch = false },
			{ name = "1196x660 desktop", size = Vector2.new(1196, 660), touch = false },
			{ name = "844x390 touch", size = Vector2.new(844, 390), touch = true },
			{ name = "390x844 touch", size = Vector2.new(390, 844), touch = true },
			{ name = "390x667 touch", size = Vector2.new(390, 667), touch = true },
			{ name = "667x375 touch", size = Vector2.new(667, 375), touch = true },
		}
		for _, v in supported do
			for _, foundry in { false, true } do
				for _, notice in { false, true } do
					local l = HudLayout.compute(v.size, v.touch, nil, foundry, notice)
					local popup = HudLayout.backpackPanel(l)
					local context = v.name .. " foundry=" .. tostring(foundry) .. " notice=" .. tostring(notice)
					local safe = { x = 12, y = l.inset + 12, w = v.size.X - 24, h = v.size.Y - l.inset - 24 }
					t.ok(HudLayout.inside(popup, safe), context .. " popup stays inside screen margins")
					t.near(popup.y + popup.h, l.backpack.y - 8, 1e-6, context .. " popup sits eight pixels above backpack")
					t.near(popup.x + popup.w, l.backpack.x + l.backpack.w, 1e-6, context .. " popup shares backpack right edge")
					t.near(popup.x, l.backpack.x, 1e-6, context .. " popup shares backpack left edge")
					t.near(popup.w, l.backpack.w, 1e-6, context .. " popup uses its full backpack anchor width")
					t.ok(popup.h >= 72 and popup.h <= 128, context .. " header and at least one ore row fit")
					t.ok(not HudLayout.overlaps(popup, l.backpack), context .. " popup leaves its toggle visible")
					for _, button in l.buttons do
						t.ok(not HudLayout.overlaps(popup, button), context .. " popup clears navigation")
					end
					if l.settings then
						t.ok(not HudLayout.overlaps(popup, l.settings), context .. " popup clears settings")
					end
				end
			end
		end
	end)

	t.test("backpack popup fits three ore rows within its desktop anchor width", function()
		local popup = HudLayout.backpackPanel(HudLayout.compute(Vector2.new(1440, 810), false))
		t.eq(popup.x, 1186)
		t.eq(popup.y, 570)
		t.eq(popup.w, 230)
		t.eq(popup.h, 128)
	end)

	t.test("backpack popup height follows visible ore rows and caps future inventories", function()
		local l = HudLayout.compute(Vector2.new(1440, 810), false)
		for _, fixture in { { count = 0, height = 72 }, { count = 1, height = 72 }, { count = 2, height = 100 }, { count = 3, height = 128 }, { count = 7, height = 128 } } do
			local popup = HudLayout.backpackPanel(l, fixture.count)
			t.eq(popup.h, fixture.height, "ore rows=" .. fixture.count)
			t.eq(popup.y + popup.h, 698, "changing row count keeps the popup directly above its anchor")
			t.eq(popup.x, 1186, "changing row count preserves anchor width")
		end
	end)

	t.test("backpack popup shrinks above a high phone anchor while preserving a scroll row", function()
		local l = HudLayout.compute(Vector2.new(390, 667), true)
		local popup = HudLayout.backpackPanel(l)
		t.ok(popup.x >= 12, "left margin survives a narrow right anchor")
		t.near(popup.x + popup.w, l.backpack.x + l.backpack.w, 1e-6, "shrinking preserves right alignment")
		t.near(popup.y, 94, 1e-6, "popup starts below the touch row and its gap")
		t.ok(popup.h >= 72 and popup.h < 80, "shallow popup fits header and one scrollable row")
	end)

	t.test("backpack popup falls back to a visible panel when the anchor leaves no space above", function()
		local l = HudLayout.compute(Vector2.new(390, 667), true)
		l.backpack = { x = 270, y = 100, w = 100, h = 60 }
		local popup = HudLayout.backpackPanel(l)
		local safe = { x = 12, y = l.inset + 12, w = 366, h = 607 }
		t.ok(HudLayout.inside(popup, safe), "fallback popup stays inside the viewport")
		t.ok(popup.h >= 72, "fallback retains room for a header and row")
		t.ok(popup.y >= 94, "fallback clears touch navigation")
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
