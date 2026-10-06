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
		{ name = "1196x679 desktop", size = Vector2.new(1196, 679), touch = false, inset = 58 },
		-- a small desktop window, the other place the column meets the screen edge
		{ name = "1280x600 mouse", size = Vector2.new(1280, 600), touch = false },
		{ name = "960x540 mouse", size = Vector2.new(960, 540), touch = false },
		{ name = "800x450 mouse", size = Vector2.new(800, 450), touch = false },
		{ name = "390x667 short portrait", size = Vector2.new(390, 667), touch = true, tightPortrait = true },
		{ name = "390x844 portrait", size = Vector2.new(390, 844), touch = true },
		{ name = "360x800 portrait", size = Vector2.new(360, 800), touch = true },
		{ name = "780x360 tall inset", size = Vector2.new(780, 360), touch = true, inset = 60, reserveCompactNotification = true },
		{ name = "360x800 tall inset", size = Vector2.new(360, 800), touch = true, inset = 60 },
		{ name = "390x844 mouse portrait", size = Vector2.new(390, 844), touch = false, inset = 60 },
		{ name = "Galaxy A16 landscape", size = Vector2.new(685, 338), touch = true, inset = 58, reserveCompactNotification = true },
		{ name = "Galaxy A16 portrait", size = Vector2.new(338, 685), touch = true, inset = 58 },
		{ name = "Galaxy A16 landscape no inset", size = Vector2.new(685, 338), touch = true, inset = 0 },
		{ name = "Galaxy A16 portrait no inset", size = Vector2.new(338, 685), touch = true, inset = 0 },
		{ name = "360x780 portrait", size = Vector2.new(360, 780), touch = true, inset = 58 },
		{ name = "320x568 portrait", size = Vector2.new(320, 568), touch = true, tightPortrait = true },
		{ name = "320x487 notched portrait", size = Vector2.new(320, 487), touch = true, inset = 58, tightPortrait = true },
	}

	local function screen(size: Vector2): HudLayout.Rect
		return { x = 0, y = 0, w = size.X, h = size.Y }
	end
	local function personalButtonBounds(button: HudLayout.Rect): HudLayout.Rect
		-- The authored face is 80 square; its editable caption ends at y=105.
		return { x = button.x, y = button.y, w = button.w, h = math.max(button.h, button.w * 105 / 80) }
	end

	t.test("desktop meteor banner and plot tag leave room for notifications", function()
		for _, size in { Vector2.new(1440, 810), Vector2.new(1196, 679), Vector2.new(960, 540), Vector2.new(800, 450) } do
			for _, expanded in { false, true } do
				local l = HudLayout.compute(size, false, 58, expanded, true, true)
				local tag = { x = (size.X - 190 * l.scale) / 2, y = l.timer.y + l.timer.h + 10 * l.scale,
					w = 190 * l.scale, h = 40 * l.scale }
				local context = tostring(size) .. " expanded=" .. tostring(expanded)
				t.ok(l.timer.y <= 36, context .. " banner uses the clear centre of the top row")
				t.ok(l.timer.x >= 180, context .. " banner clears Roblox controls on the left")
				t.near(l.timer.x + l.timer.w / 2, size.X / 2, 1e-6, context .. " banner stays centred")
				t.ok(HudLayout.inside(tag, screen(size)), context .. " plot tag fits")
				for name, rect in { notification = l.notification, objective = l.eventPanel, foundry = l.leftCards.Production,
					wallet = l.leftCards.Resources, backpack = l.backpack, training = l.tutorial } do
					t.ok(not HudLayout.overlaps(tag, rect), context .. " plot tag clears " .. name)
				end
			end
		end
	end)

	t.test("personal navigation captions clear visible cards, neighbours and movement", function()
		for _, v in viewports do
			for _, expanded in { false, true } do
				for _, notice in { "none", "brief", "reward" } do
					local l = HudLayout.compute(v.size, v.touch, v.inset, expanded, notice ~= "none", notice == "reward")
					local context = v.name .. " expanded=" .. tostring(expanded) .. " notice=" .. notice
					local protected = { { name = "foundry", rect = l.leftCards.Production } }
					if l.timerVisible then table.insert(protected, { name = "clock", rect = l.timer }) end
					if l.resourcesVisible then table.insert(protected, { name = "wallet", rect = l.leftCards.Resources }) end
					if l.backpackVisible then table.insert(protected, { name = "backpack", rect = l.backpack }) end
					if l.eventVisible then table.insert(protected, { name = "objective", rect = l.eventPanel }) end
					if l.tutorialVisible then table.insert(protected, { name = "training", rect = l.tutorial }) end
					if l.settings then table.insert(protected, { name = "settings", rect = l.settings }) end
					if notice ~= "none" then table.insert(protected, { name = "notification", rect = l.notification }) end
					for name, button in l.buttons do
						local bounds = personalButtonBounds(button)
						t.ok(button.w >= 44 and button.h >= 44, context .. " " .. name .. " face remains a touch target")
						t.ok(HudLayout.inside(bounds, screen(v.size)), context .. " " .. name .. " caption fits")
						for _, item in protected do
							t.ok(not HudLayout.overlaps(bounds, item.rect), context .. " " .. name .. " caption clears " .. item.name)
						end
						for otherName, other in l.buttons do
							if otherName ~= name then t.ok(not HudLayout.overlaps(bounds, personalButtonBounds(other)), context .. " " .. name .. " caption clears " .. otherName) end
						end
						for _, control in { l.mine, l.jump, l.thumbstick } do
							t.ok(not HudLayout.overlaps(bounds, control), context .. " " .. name .. " caption clears movement")
						end
					end
				end
			end
		end
	end)

	t.test("personal captions retain the 844 landscape column at tall insets", function()
		for _, inset in { 0, 36, 58, 60 } do
			local l = HudLayout.compute(Vector2.new(844, 390), true, inset)
			for _, name in { "SHOP", "INDEX", "REBIRTH" } do
				local button = l.buttons[name]
				t.eq(button.x, 12, "left column survives inset=" .. inset)
				t.ok(button.y >= inset, "face clears Roblox inset")
				t.ok(personalButtonBounds(button).y + personalButtonBounds(button).h <= (l.thumbstick :: HudLayout.Rect).y + 1e-6, "caption stops above joystick")
			end
		end
	end)

	t.test("anchored backpack popup clears the personal navigation captions", function()
		for _, size in { Vector2.new(390, 667), Vector2.new(844, 390), Vector2.new(320, 568) } do
			for _, expanded in { false, true } do
				local l = HudLayout.compute(size, true, 36, expanded)
				if l.backpackVisible then
					local popup = HudLayout.backpackPanel(l)
					for name, button in l.buttons do
						t.ok(not HudLayout.overlaps(popup, personalButtonBounds(button)), tostring(size) .. " popup clears " .. name .. " caption")
					end
				end
			end
		end
	end)

	t.test("desktop HUD keeps corner balances and a centred production strip", function()
		local l = HudLayout.compute(Vector2.new(1440, 810), false)
		local wallet, production, backpack = l.leftCards.Resources, l.leftCards.Production, l.backpack
		t.eq(wallet.x, 24, "wallet hugs the left margin")
		t.eq(backpack.x + backpack.w, 1416, "backpack hugs the right margin")
		t.near(wallet.y + wallet.h, backpack.y + backpack.h, 1e-6, "corner panels share a baseline")
		t.near(production.x + production.w / 2, 720, 1e-6, "production stays centred")
		t.ok(production.w > wallet.w and production.w > backpack.w, "production has room for its two totals and sale value")
		t.ok(wallet.x + wallet.w + 6 <= production.x, "wallet clears production")
		t.ok(production.x + production.w + 6 <= backpack.x, "production clears backpack")
		t.ok(personalButtonBounds(l.buttons.STORE).y + personalButtonBounds(l.buttons.STORE).h < wallet.y, "left captions stop above the wallet")
		t.ok(l.buttons.INDEX.x > production.x + production.w, "Index remains on the right")
		t.eq(l.leftCards.Equipment, l.buttons.SHOP)
		t.ok(l.tutorial.y + l.tutorial.h < production.y, "training clears the production summary")
	end)

	t.test("landscape reference stacks left navigation and aligns the bottom status strip", function()
		for _, inset in { 0, 36, 58, 60 } do
			local l = HudLayout.compute(Vector2.new(844, 390), true, inset)
			local gear, index, rebirth, store = l.buttons.SHOP, l.buttons.INDEX, l.buttons.REBIRTH, l.buttons.STORE
			local settings = l.settings :: HudLayout.Rect
			t.eq(gear.x, index.x, "Gear and Index share the left column")
			t.eq(gear.x, rebirth.x, "Rebirth shares the left column")
			t.ok(gear.y + gear.h <= index.y and index.y + index.h <= rebirth.y, "Gear, Index, Rebirth stack vertically")
			t.ok(gear.x <= 24 and gear.y >= inset, "left navigation sits below Roblox")
			t.near(store.y, settings.y, 1e-6, "Store shares the settings row")
			t.ok(store.x + store.w < settings.x, "Store sits immediately left of settings")
			t.ok(settings.x + settings.w >= 844 - 24 and store.x >= 180, "top-right actions clear Roblox's left controls")
			t.ok(l.eventPanel.y >= settings.y + settings.h, "objective is below settings")
			t.near(l.timer.x + l.timer.w / 2, 422, 1e-6, "clock is centered")
			t.ok(l.timer.w >= 400, "clock expands into the freed top row")
			local wallet, foundry, backpack = l.leftCards.Resources, l.leftCards.Production, l.backpack
			t.ok(wallet.x + wallet.w < foundry.x and foundry.x + foundry.w < backpack.x, "wallet, current summary, backpack share left-to-right order")
			t.near(wallet.y + wallet.h, foundry.y + foundry.h, 1e-6, "wallet and summary are bottom aligned")
			t.near(backpack.y + backpack.h, foundry.y + foundry.h, 1e-6, "backpack and summary are bottom aligned")
			t.ok(l.tutorial.y + l.tutorial.h < math.min(wallet.y, foundry.y, backpack.y), "training sits above the strip")
			t.near(l.tutorial.x + l.tutorial.w / 2, 422, 1e-6, "training is centered")
			local thumb = l.thumbstick :: HudLayout.Rect
			t.eq(thumb.w, 160, "landscape reserves the native joystick area")
			t.eq(thumb.h, 156, "landscape reserves the native joystick area")
			t.ok(HudLayout.inside({ x = 29, y = 296, w = 74, h = 74 }, thumb), "live 844x390 joystick circle is protected")
		end
	end)

	t.test("expanded landscape notifications reserve the objective without moving the status order", function()
		for _, reward in { false, true } do
			local l = HudLayout.compute(Vector2.new(844, 390), true, 58, true, true, reward)
			t.eq(l.eventVisible, false, "notification takes the objective slot while details are open")
			t.eq(l.notification.h, if reward then 64 else 48, "notification keeps readable rows")
			t.ok(l.leftCards.Resources.x < l.leftCards.Production.x and l.leftCards.Production.x < l.backpack.x, "expanded foundry keeps status order")
		end
	end)

	t.test("active HUD cards and navigation clear each other and movement controls", function()
		for _, v in viewports do
			for _, expanded in { false, true } do
				local l = HudLayout.compute(v.size, v.touch, v.inset, expanded)
				local active = {
					{ name = "foundry", rect = l.leftCards.Production },
				}
				if l.resourcesVisible ~= false then table.insert(active, { name = "wallet", rect = l.leftCards.Resources }) end
				if l.backpackVisible ~= false then table.insert(active, { name = "backpack", rect = l.backpack }) end
				if l.timerVisible ~= false then table.insert(active, { name = "clock", rect = l.timer }) end
				if l.eventVisible then table.insert(active, { name = "event", rect = l.eventPanel }) end
				if l.tutorialVisible then table.insert(active, { name = "training", rect = l.tutorial }) end
				if l.settings then table.insert(active, { name = "settings", rect = l.settings }) end
				for _, name in Hud.ButtonOrder do table.insert(active, { name = name, rect = l.buttons[name] }) end
				for i, item in active do
					t.ok(HudLayout.inside(item.rect, screen(v.size)), v.name .. " " .. item.name .. " fits")
					local sharesTopRow = not (v.touch or l.portrait) and (item.name == "settings" or item.name == "clock")
						or (v.touch and not l.portrait and (item.name == "settings" or item.name == "STORE") and item.rect.x >= v.size.X - 120)
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
				t.eq(l.tutorialVisible, not (v.touch and expanded) and v.tightPortrait ~= true, v.name .. " guide visibility expanded=" .. tostring(expanded))
				local productionSpec = if not v.touch and not l.portrait then Hud.Desktop.LeftCards.Production else Hud.LeftCards.Production
				local foundryScale = l.leftCards.Production.w / productionSpec.Width
				t.ok(productionSpec.Height * foundryScale >= 44 - 1e-6, v.name .. " foundry summary remains a usable target")
				if expanded and v.touch then
					t.ok(l.leftCards.Production.h - productionSpec.Height * foundryScale >= 44 - 1e-6, v.name .. " scrolling details retain a 44 px close target")
				end
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

	t.test("smallest portrait keeps visible cards and 44 px foundry controls above movement", function()
		for _, height in { 568, 487 } do
			local size = Vector2.new(320, height)
			for _, inset in { 0, 36, 58, 60 } do
				for _, expanded in { false, true } do
					for _, notice in { "none", "brief", "reward" } do
						local l = HudLayout.compute(size, true, inset, expanded, notice ~= "none", notice == "reward")
						local context = "320x" .. height .. " inset=" .. inset .. " expanded=" .. tostring(expanded) .. " notice=" .. notice
						for _, field in { "resourcesVisible", "backpackVisible", "timerVisible" } do
							t.eq(type(l[field]), "boolean", context .. " defines " .. field)
						end
						t.eq(l.eventVisible, false, context .. " replaces the lower-priority objective")
						t.eq(l.tutorialVisible, false, context .. " defers training")
						local active = { { name = "foundry", rect = l.leftCards.Production } }
						if l.resourcesVisible then table.insert(active, { name = "wallet", rect = l.leftCards.Resources }) end
						if l.backpackVisible then table.insert(active, { name = "backpack", rect = l.backpack }) end
						if l.timerVisible then table.insert(active, { name = "clock", rect = l.timer }) end
						if notice ~= "none" then table.insert(active, { name = "notification", rect = l.notification }) end
						for _, name in Hud.ButtonOrder do table.insert(active, { name = name, rect = l.buttons[name] }) end
						if l.settings then table.insert(active, { name = "settings", rect = l.settings }) end
						for i, item in active do
							t.ok(HudLayout.inside(item.rect, screen(size)), context .. " " .. item.name .. " fits")
							t.ok(not HudLayout.overlaps(item.rect, l.topBar), context .. " " .. item.name .. " clears top bar")
							for _, control in { l.mine, l.jump, l.thumbstick } do
								t.ok(not HudLayout.overlaps(item.rect, control), context .. " " .. item.name .. " clears movement/jump")
							end
							for j = i + 1, #active do
								t.ok(not HudLayout.overlaps(item.rect, active[j].rect), context .. " " .. item.name .. " vs " .. active[j].name)
							end
						end
						local foundry = l.leftCards.Production
						local foundryScale = foundry.w / Hud.LeftCards.Production.Width
						t.ok(Hud.LeftCards.Production.Height * foundryScale >= 44 - 1e-6, context .. " foundry toggle remains 44 px")
						if expanded then
							t.ok(foundry.h - Hud.LeftCards.Production.Height * foundryScale >= 44 - 1e-6, context .. " scrollable details retain a 44 px close action")
							t.ok(foundry.h <= Hud.LeftCards.Production.ExpandedHeight * foundryScale + 1e-6, context .. " details never expand beyond their content")
							t.eq(l.resourcesVisible, false, context .. " expanded foundry takes the wallet slot")
							t.eq(l.backpackVisible, false, context .. " expanded foundry takes the backpack slot")
						end
						if notice ~= "none" then
							t.eq(l.timerVisible, false, context .. " notification replaces the timer")
							t.ok(l.notification.w >= 190 and l.notification.h >= 48, context .. " notification stays readable")
						end
						if l.backpackVisible then
							local popup = HudLayout.backpackPanel(l)
							t.ok(HudLayout.inside(popup, screen(size)), context .. " backpack popup fits")
							t.near(popup.y + popup.h, l.backpack.y - 8, 1e-6, context .. " backpack popup stays above its toggle")
							t.near(popup.x, l.backpack.x, 1e-6, context .. " backpack popup keeps its anchor width")
							t.near(popup.w, l.backpack.w, 1e-6, context .. " backpack popup keeps its anchor width")
							t.ok(popup.h >= 72, context .. " backpack popup retains a header and ore row")
						end
					end
				end
			end
		end
	end)

	t.test("compact card visibility defaults to visible outside the smallest portrait", function()
		for _, size in { Vector2.new(1440, 810), Vector2.new(844, 390), Vector2.new(390, 844) } do
			for _, expanded in { false, true } do
				local l = HudLayout.compute(size, true, 36, expanded, true, true)
				t.eq(l.resourcesVisible, true, "wallet remains visible on supported larger screens")
				t.eq(l.backpackVisible, true, "backpack remains visible on supported larger screens")
				t.eq(l.timerVisible, true, "timer remains visible on supported larger screens")
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
					{ name = "foundry", rect = l.leftCards.Production },
					{ name = "top bar", rect = l.topBar },
				}
				if l.timerVisible ~= false then table.insert(protected, { name = "clock", rect = l.timer }) end
				if l.resourcesVisible ~= false then table.insert(protected, { name = "wallet", rect = l.leftCards.Resources }) end
				if l.backpackVisible ~= false then table.insert(protected, { name = "backpack", rect = l.backpack }) end
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
				local referenceLandscape = v.touch and not l.portrait and l.buttons.SHOP.x == l.buttons.INDEX.x
				t.eq(l.eventVisible, v.tightPortrait ~= true and not (v.touch and expanded and (l.portrait or referenceLandscape or v.reserveCompactNotification == true)), v.name .. " objective visibility expanded=" .. tostring(expanded))
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
					{ name = "foundry", rect = l.leftCards.Production },
					{ name = "top bar", rect = l.topBar },
				}
				if l.timerVisible ~= false then table.insert(protected, { name = "clock", rect = l.timer }) end
				if l.resourcesVisible ~= false then table.insert(protected, { name = "wallet", rect = l.leftCards.Resources }) end
				if l.backpackVisible ~= false then table.insert(protected, { name = "backpack", rect = l.backpack }) end
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

	t.test("personal captions reserve the objective when the landscape notice pocket is too shallow", function()
		for _, width in { 740, 780 } do
			local size = Vector2.new(width, 360)
			local single = HudLayout.compute(size, true, 60, true, true, false)
			local caption = personalButtonBounds(single.buttons.SHOP)
			local pocketHeight = (single.thumbstick :: HudLayout.Rect).y - (caption.y + caption.h) - 4
			t.ok(pocketHeight < 24, "personal caption leaves less than a readable notice row")
			t.eq(single.notification.h, 48, "brief notice stays readable below the caption")
			t.eq(single.eventVisible, false, "brief notice reserves the objective when the caption consumes its pocket")
			t.eq(single.notification.y, single.eventPanel.y, "brief notice uses the objective row")
			t.ok(not HudLayout.overlaps(single.notification, caption), "brief notice clears the personal caption")
			local reward = HudLayout.compute(size, true, 60, true, true, true)
			t.eq(reward.notification.h, 64, "reward keeps both rows readable")
			t.eq(reward.eventVisible, false, "reward temporarily reserves the objective slot")
			t.eq(reward.notification.y, reward.eventPanel.y, "reward uses the objective row")
		end
	end)

	t.test("training card fits and clears the other touch HUD controls", function()
		for _, v in viewports do
			local l = HudLayout.compute(v.size, v.touch, v.inset)
			t.ok(HudLayout.inside(l.tutorial, screen(v.size)), v.name .. " training fits")
			if v.touch and l.tutorialVisible then
				local protected = { l.leftCards.Production, l.mine, l.jump }
				if l.timerVisible ~= false then table.insert(protected, l.timer) end
				if l.eventVisible then table.insert(protected, l.eventPanel) end
				if l.resourcesVisible ~= false then table.insert(protected, l.leftCards.Resources) end
				for _, rect in protected do
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
				if name == "STORE" and v.touch and not layout.portrait and rect.x >= v.size.X - 120 then
					t.ok(rect.x >= 180, v.name .. " Store clears Roblox's left controls")
				else
					t.ok(not HudLayout.overlaps(rect, layout.topBar), v.name .. " " .. name .. " vs top bar")
				end
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
				if name == "Resources" and layout.resourcesVisible == false then continue end
				local card = layout.leftCards[name]
				t.ok(HudLayout.inside(card, screen(v.size)), v.name .. " " .. name .. " on screen")
				t.ok(not HudLayout.overlaps(card, layout.topBar), v.name .. " " .. name .. " vs top bar")
				if layout.timerVisible ~= false then
					t.ok(not HudLayout.overlaps(card, layout.timer), v.name .. " " .. name .. " vs clock")
				end
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

	t.test("the level badge sits top-left on mouse screens and clears everything else", function()
		for _, v in viewports do
			local layout = HudLayout.compute(v.size, v.touch, v.inset)
			local level = HudLayout.level(layout)
			if v.touch or v.size.X < v.size.Y then
				t.ok(level == nil, v.name .. " touch and portrait keep the level on the wallet")
				continue
			end
			if not level then continue end
			t.ok(HudLayout.inside(level, screen(v.size)), v.name .. " level on screen")
			t.ok(level.y >= layout.inset, v.name .. " level under the top bar")
			t.ok(level.h >= Hud.Level.MinHeight, v.name .. " level readable")
			for name, rect in { clock = layout.timer, objective = layout.eventPanel, wallet = layout.leftCards.Resources,
				backpack = layout.backpack, notification = layout.notification } do
				t.ok(not HudLayout.overlaps(level, rect), v.name .. " level vs " .. name)
			end
			for name, button in layout.buttons do
				t.ok(not HudLayout.overlaps(level, personalButtonBounds(button)), v.name .. " level vs " .. name)
			end
		end
		local roomy = HudLayout.level(HudLayout.compute(Vector2.new(1920, 1080), false, 58))
		t.ok(roomy ~= nil, "a full HD window shows the level badge")
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
			{ name = "960x540 desktop", size = Vector2.new(960, 540), touch = false },
			{ name = "800x450 desktop", size = Vector2.new(800, 450), touch = false },
			{ name = "800x450 desktop tall inset", size = Vector2.new(800, 450), touch = false, inset = 58 },
			{ name = "844x390 touch", size = Vector2.new(844, 390), touch = true },
			{ name = "390x844 touch", size = Vector2.new(390, 844), touch = true },
			{ name = "390x667 touch", size = Vector2.new(390, 667), touch = true },
			{ name = "667x375 touch", size = Vector2.new(667, 375), touch = true },
		}
		for _, v in supported do
			for _, foundry in { false, true } do
				for _, notice in { false, true } do
					local l = HudLayout.compute(v.size, v.touch, v.inset, foundry, notice)
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
						t.ok(not HudLayout.overlaps(popup, personalButtonBounds(button)), context .. " popup clears navigation captions")
					end
					if l.settings then
						t.ok(not HudLayout.overlaps(popup, l.settings), context .. " popup clears settings")
					end
					if not l.touch and not l.portrait and l.eventVisible then
						t.ok(not HudLayout.overlaps(popup, l.eventPanel), context .. " popup clears the visible objective")
					end
				end
			end
		end
	end)

	t.test("backpack popup fits three ore rows within its desktop anchor width", function()
		local l = HudLayout.compute(Vector2.new(1440, 810), false)
		local popup = HudLayout.backpackPanel(l)
		t.eq(popup.x, l.backpack.x)
		t.eq(popup.y + popup.h, l.backpack.y - 8)
		t.eq(popup.w, l.backpack.w)
		t.eq(popup.h, 128)
	end)

	t.test("backpack popup height follows visible ore rows and caps future inventories", function()
		local l = HudLayout.compute(Vector2.new(1440, 810), false)
		for _, fixture in { { count = 0, height = 72 }, { count = 1, height = 72 }, { count = 2, height = 100 }, { count = 3, height = 128 }, { count = 7, height = 128 } } do
			local popup = HudLayout.backpackPanel(l, fixture.count)
			t.eq(popup.h, fixture.height, "ore rows=" .. fixture.count)
			t.eq(popup.y + popup.h, l.backpack.y - 8, "changing row count keeps the popup directly above its anchor")
			t.eq(popup.x, l.backpack.x, "changing row count preserves anchor width")
		end
	end)

	t.test("backpack popup shrinks above a high phone anchor while preserving a scroll row", function()
		local l = HudLayout.compute(Vector2.new(390, 667), true)
		local popup = HudLayout.backpackPanel(l)
		t.ok(popup.x >= 12, "left margin survives a narrow right anchor")
		t.near(popup.x + popup.w, l.backpack.x + l.backpack.w, 1e-6, "shrinking preserves right alignment")
		t.near(popup.y, 107.75, 1e-6, "popup starts below the personal caption and its gap")
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
