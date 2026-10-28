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
		{ name = "2560x1440", size = Vector2.new(2560, 1440), touch = false },
		{ name = "3840x2160", size = Vector2.new(3840, 2160), touch = false },
		{ name = "1196x679 desktop", size = Vector2.new(1196, 679), touch = false, inset = 58 },
		-- a small desktop window, the other place the column meets the screen edge
		{ name = "1280x600 mouse", size = Vector2.new(1280, 600), touch = false },
		{ name = "960x540 mouse", size = Vector2.new(960, 540), touch = false },
		{ name = "800x450 mouse", size = Vector2.new(800, 450), touch = false },
		{ name = "390x667 short portrait", size = Vector2.new(390, 667), touch = true }, -- the compact foundry button leaves room for the guide
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

	t.test("the HUD keeps its size up to 1080p and grows in proportion past it", function()
		t.eq(HudLayout.scale(Vector2.new(1440, 810)), 1)
		t.eq(HudLayout.scale(Vector2.new(1920, 1080)), 1)
		t.near(HudLayout.scale(Vector2.new(2560, 1440)), 4 / 3, 0.001)
		t.eq(HudLayout.scale(Vector2.new(3840, 2160)), 2)
		t.eq(HudLayout.scale(Vector2.new(7680, 4320)), Hud.ScaleUpMax)
	end)

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

	t.test("every layout places a Daily Rewards button, except a phone too narrow for one more in its row", function()
		for _, v in viewports do
			local l = HudLayout.compute(v.size, v.touch, v.inset)
			-- six 44 px faces with 2 px gaps, the gear and the 12 px margins need 344 px across
			local tooNarrow = v.size.X < v.size.Y and v.size.X < 344
			t.eq(l.buttons.DAILY == nil, tooNarrow, v.name .. " DAILY button")
		end
	end)

	t.test("on a desktop window Daily Rewards sits right above Index when there is room, else ends the left column", function()
		local above, column = 0, 0
		for _, size in { Vector2.new(1920, 1080), Vector2.new(1440, 810), Vector2.new(1196, 679), Vector2.new(1280, 600), Vector2.new(960, 540), Vector2.new(800, 450) } do
			local l = HudLayout.compute(size, false, 58)
			local daily, index, store = l.buttons.DAILY, l.buttons.INDEX, l.buttons.STORE
			if daily.x == index.x then
				above += 1
				t.ok(daily.y + personalButtonBounds(daily).h <= index.y + 1e-6, tostring(size) .. " Daily is above Index")
			else
				column += 1
				t.eq(daily.x, store.x, tostring(size) .. " Daily is in the left column")
				t.ok(daily.y > store.y, tostring(size) .. " Daily is below Store")
			end
		end
		t.ok(above >= 1, "the above-Index placement is exercised (" .. column .. " windows fell back to the column)")
	end)

	local desktopSizes = { Vector2.new(1920, 1080), Vector2.new(1440, 810), Vector2.new(1196, 679), Vector2.new(1280, 600), Vector2.new(960, 540), Vector2.new(800, 450) }

	t.test("on a desktop window Codes sits right under Index, or ends the left column when the stack will not fit", function()
		local under = 0
		for _, size in desktopSizes do
			local l = HudLayout.compute(size, false, 58)
			local codes, index, store = l.buttons.CODES, l.buttons.INDEX, l.buttons.STORE
			t.ok(codes ~= nil, tostring(size) .. " has a CODES button")
			if codes and codes.x == index.x then
				under += 1
				t.ok(codes.y >= index.y + personalButtonBounds(index).h - 1e-6, tostring(size) .. " Codes is under Index")
				t.ok(codes.y - (index.y + personalButtonBounds(index).h) <= 4, tostring(size) .. " Codes is right under Index")
			elseif codes then
				t.eq(codes.x, store.x, tostring(size) .. " Codes is in the left column")
			end
		end
		t.ok(under >= 1, "the under-Index placement is exercised")
	end)

	t.test("on desktop ORE is a column tile under STORE and SPRINT sits in line with the backpack", function()
		local inLine = 0
		for _, size in desktopSizes do
			local l = HudLayout.compute(size, false, 58)
			local sprint, ore, store, pack = l.fastWalk, l.ore, l.buttons.STORE, l.backpack
			local context = tostring(size)
			if not ore then
				t.ok(size.Y <= 600, context .. " only a short window leaves ORE out of the column")
				continue
			end
			t.eq(ore.x, store.x, context .. " ORE is in the left column")
			t.near(ore.w, store.w, 1e-6, context .. " ORE is as wide as STORE")
			t.near(ore.h, store.h, 1e-6, context .. " ORE is as tall as STORE")
			t.ok(ore.y >= store.y + personalButtonBounds(store).h - 1e-6, context .. " ORE is below STORE")
			for buttonName, button in l.buttons do
				if button.x == store.x and button.y > store.y and buttonName ~= "STORE" then
					t.ok(button.y > ore.y, context .. " " .. buttonName .. " comes after ORE")
				end
			end
			t.ok(HudLayout.inside(ore, screen(size)), context .. " ORE on screen")
			for buttonName, button in l.buttons do
				t.ok(not HudLayout.overlaps(personalButtonBounds(ore), personalButtonBounds(button)), context .. " ORE clears " .. buttonName)
			end
			if sprint then
				inLine += 1
				t.near(sprint.y + sprint.h / 2, pack.y + pack.h / 2, 1e-6, context .. " SPRINT is level with the backpack")
				t.ok(sprint.x + sprint.w <= pack.x, context .. " SPRINT is left of the backpack")
				t.ok(HudLayout.inside(sprint, screen(size)), context .. " SPRINT on screen")
				local others = { foundry = l.leftCards.Production, wallet = l.leftCards.Resources, backpack = pack }
				if l.tutorialVisible then others.training = l.tutorial end
				for otherName, other in others do
					t.ok(not HudLayout.overlaps(sprint, other), context .. " SPRINT clears " .. otherName)
				end
			end
		end
		t.ok(inLine >= 4, "most desktop windows get the in-line SPRINT (" .. inLine .. ")")
	end)

	t.test("phones keep SPRINT and ORE where they were", function()
		local l = HudLayout.compute(Vector2.new(844, 390), true, 36)
		t.ok(l.fastWalk ~= nil, "phone landscape still places SPRINT")
		t.eq(l.ore, nil, "ORE stays above SPRINT on phones")
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

	t.test("phones in landscape keep the menu L above the joystick at every inset", function()
		for _, size in { Vector2.new(844, 390), Vector2.new(733, 392) } do
			for _, inset in { 0, 36, 58, 60 } do
				local l = HudLayout.compute(size, true, inset)
				local context = tostring(size) .. " inset=" .. inset
				local gear, index, rebirth, pets, store = l.buttons.SHOP, l.buttons.INDEX, l.buttons.REBIRTH, l.buttons.PETS, l.buttons.STORE
				t.eq(gear.x, 12, context .. " Gear starts the L")
				t.ok(gear.y == index.y and index.y == rebirth.y and gear.x < index.x and index.x < rebirth.x, context .. " Gear, Index, Rebirth share the top row")
				t.ok(pets.x == gear.x and store.x == gear.x and gear.y < pets.y and pets.y < store.y, context .. " Pets and Store go down under Gear")
				t.ok(gear.y >= inset, context .. " the menu clears Roblox's top bar")
				local caption = personalButtonBounds(store)
				t.ok(caption.y + caption.h <= (l.thumbstick :: HudLayout.Rect).y + 1e-6, context .. " Store's caption stops above the joystick")
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
		t.ok(production.h >= 44 and production.w > production.h, "the foundry sell button keeps a full touch target")
		t.ok(wallet.x + wallet.w + 6 <= production.x, "wallet clears production")
		t.ok(production.x + production.w + 6 <= backpack.x, "production clears backpack")
		t.ok(personalButtonBounds(l.buttons.STORE).y + personalButtonBounds(l.buttons.STORE).h < wallet.y, "left captions stop above the wallet")
		t.ok(l.buttons.INDEX.x > production.x + production.w, "Index remains on the right")
		t.eq(l.leftCards.Equipment, l.buttons.SHOP)
		t.ok(l.tutorial.y + l.tutorial.h < production.y, "training clears the production summary")
	end)

	t.test("phones in landscape follow the owner's corner layout", function()
		for _, size in { Vector2.new(844, 390), Vector2.new(733, 392), Vector2.new(780, 360), Vector2.new(685, 338) } do
			for _, inset in { 0, 36, 58 } do
				local l = HudLayout.compute(size, true, inset)
				local context = tostring(size) .. " inset=" .. inset
				local settings = l.settings :: HudLayout.Rect
				local wallet, foundry, backpack = l.leftCards.Resources, l.leftCards.Production, l.backpack
				local jump, mine, sprint = l.jump :: HudLayout.Rect, l.mine :: HudLayout.Rect, l.fastWalk :: HudLayout.Rect
				t.eq(l.levelAbove, true, context .. " the level sits above the wallet")
				t.ok(settings.x + settings.w >= size.X - 12 and settings.y + settings.h <= math.max(inset, 46), context .. " settings in the top-right corner")
				t.near(l.timer.x + l.timer.w / 2, size.X / 2, 1e-6, context .. " clock is centred")
				t.ok(l.timer.x >= 180 and l.timer.x + l.timer.w <= settings.x, context .. " clock clears Roblox and the gear")
				t.eq(wallet.x, 12, context .. " wallet in the bottom-left corner")
				t.near(foundry.x + foundry.w / 2, size.X / 2, 1e-6, context .. " foundry centred")
				t.ok(wallet.x + wallet.w < foundry.x and foundry.x + foundry.w < backpack.x, context .. " wallet, foundry, backpack left to right")
				t.ok(backpack.x + backpack.w <= jump.x, context .. " backpack sits beside the jump button")
				for _, rect in { wallet, foundry, backpack } do t.near(rect.y + rect.h, size.Y - 6, 1e-6, context .. " bottom aligned") end
				t.ok(l.tutorial.y + l.tutorial.h <= foundry.y and math.abs(l.tutorial.x + l.tutorial.w / 2 - size.X / 2) < 1e-6, context .. " training above the foundry")
				t.ok(sprint.y > settings.y + settings.h and (sprint.y + sprint.h <= mine.y or sprint.x + sprint.w <= mine.x), context .. " sprint and ore above MINE, or beside it on short phones")
				t.ok(sprint.x + sprint.w <= size.X, context .. " sprint on screen")
			end
		end
	end)

	t.test("phones in landscape show the meteor objective larger, below the top bar", function()
		for _, size in { Vector2.new(844, 390), Vector2.new(733, 392), Vector2.new(874, 402), Vector2.new(685, 338) } do
			for _, inset in { 36, 58 } do
				local l = HudLayout.compute(size, true, inset)
				local context = tostring(size) .. " inset=" .. inset
				local objective = l.objective :: HudLayout.Rect
				t.ok(objective ~= nil, context .. " has an objective slot")
				t.ok(objective.w > l.timer.w * 1.3, context .. " objective is well above the clock's size")
				t.ok(objective.y >= l.timer.y, context .. " objective at or below the clock's top-bar spot")
				if l.buttons.PETS.y ~= l.buttons.SHOP.y then
					t.ok(objective.y < math.max(inset, l.timer.y + 1), context .. " objective rides high beside the menu buttons")
				end
				t.ok(not HudLayout.overlaps(objective, l.settings :: HudLayout.Rect), context .. " objective clears the settings gear")
				t.near(objective.x + objective.w / 2, size.X / 2, 1e-6, context .. " objective is centred")
				local sprint = l.fastWalk :: HudLayout.Rect
				t.ok(objective.x + objective.w <= math.min(sprint.x, (l.jump :: HudLayout.Rect).x + (l.jump :: HudLayout.Rect).w - 54), context .. " objective clears ORE and SPRINT")
				for _, button in l.buttons do
					t.ok(not HudLayout.overlaps(objective, button), context .. " objective clears the menu buttons")
				end
				t.ok(objective.y + objective.h <= l.tutorial.y, context .. " objective stays above training")
			end
		end
		t.eq(HudLayout.compute(Vector2.new(844, 390), true, 58, true).objective, nil, "the open foundry keeps the clock in the bar")
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
						or (l.levelAbove and item.name == "clock")
					if sharesTopRow then
						t.ok(item.rect.x >= 180, v.name .. " " .. item.name .. " clears Roblox controls on the left")
					else
						t.ok(not HudLayout.overlaps(item.rect, l.topBar), v.name .. " " .. item.name .. " clears top bar")
					end
					for j = i + 1, #active do
						t.ok(not HudLayout.overlaps(item.rect, active[j].rect), v.name .. " " .. item.name .. " vs " .. active[j].name .. " expanded=" .. tostring(expanded))
					end
					for _, control in { l.mine, l.jump, if item.name == "wallet" and l.levelAbove then nil else l.thumbstick } do
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
				local referenceLandscape = l.levelAbove == true
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

	t.test("landscape notices clear the menu captions on narrow phones", function()
		for _, width in { 685, 740, 780 } do
			for _, reward in { false, true } do
				for _, expanded in { false, true } do
					local l = HudLayout.compute(Vector2.new(width, 360), true, 60, expanded, true, reward)
					local context = width .. " reward=" .. tostring(reward) .. " expanded=" .. tostring(expanded)
					t.eq(l.notification.h, if reward then 64 else 48, context .. " notice keeps readable rows")
					t.ok(l.notification.w >= 190, context .. " notice is wide enough")
					for name, button in l.buttons do
						t.ok(not HudLayout.overlaps(l.notification, personalButtonBounds(button)), context .. " notice clears " .. name)
					end
					if expanded then t.eq(l.eventVisible, false, context .. " notice reserves the objective") end
				end
			end
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
				-- (phones in landscape: the owner put the wallet over the joystick area; it takes no touches)
				if layout.thumbstick and not (name == "Resources" and layout.levelAbove) then
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

	t.test("desktop: the bottom cards share one bottom line and the side stacks share one margin", function()
		for _, size in { Vector2.new(1920, 1080), Vector2.new(1366, 768), Vector2.new(2560, 1440) } do
			local l = HudLayout.compute(size, false)
			local resources, production = l.leftCards.Resources, l.leftCards.Production
			t.near(production.y + production.h, resources.y + resources.h, 1e-6, tostring(size) .. " foundry and wallet bottoms")
			t.near(l.backpack.y + l.backpack.h, resources.y + resources.h, 1e-6, tostring(size) .. " backpack and wallet bottoms")
			local index = l.buttons.INDEX
			t.near(size.X - (index.x + index.w), l.buttons.SHOP.x, 1e-6, tostring(size) .. " right stack mirrors the left column")
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
		-- a big window: the Daily / Index / Codes stack leaves the popup its full six rows
		local l = HudLayout.compute(Vector2.new(1920, 1080), false)
		for _, fixture in { { count = 0, height = 72 }, { count = 1, height = 72 }, { count = 2, height = 100 }, { count = 3, height = 128 }, { count = 6, height = 212 }, { count = 9, height = 212 } } do
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
	t.test("HudEdit with nothing set leaves the layout as computed", function()
		local layout = HudLayout.compute(Vector2.new(1920, 1080), false, 36, false, false, false)
		local edited = HudLayout.applyEdits(layout, Config.HudEdit)
		t.eq(edited.timer.x, layout.timer.x)
		t.eq(edited.backpack.y, layout.backpack.y)
		t.eq(edited.buttons.SHOP.x, layout.buttons.SHOP.x)
		t.eq(edited.resourcesVisible, layout.resourcesVisible)
		t.eq(HudLayout.isHidden(edited, "Wallet"), false)
	end)

	t.test("HudEdit nudges, scales and hides the named elements only", function()
		local layout = HudLayout.compute(Vector2.new(1920, 1080), false, 36, false, false, false)
		local edited = HudLayout.applyEdits(layout, {
			Hidden = { "Backpack", "INDEX", "Level" },
			Nudge = { Timer = { x = 40, y = -6, scale = 0.5 }, Wallet = { y = -20 }, FastWalk = { x = 5 } },
		})
		t.eq(edited.timer.x, layout.timer.x + 40)
		t.eq(edited.timer.y, layout.timer.y - 6)
		t.near(edited.timer.w, layout.timer.w * 0.5, 1e-6)
		t.eq(edited.leftCards.Resources.y, layout.leftCards.Resources.y - 20)
		t.eq(edited.leftCards.Production.x, layout.leftCards.Production.x, "the foundry is not touched")
		t.eq(edited.backpackVisible, false)
		t.eq(edited.timerVisible, layout.timerVisible)
		t.ok(edited.buttons.INDEX == nil or edited.buttons.INDEX.x < 0, "a hidden button leaves the screen")
		t.eq(edited.buttons.SHOP.x, layout.buttons.SHOP.x, "other buttons stay put")
		t.eq(HudLayout.isHidden(edited, "Level"), true)
		t.eq(HudLayout.nudged(edited, "FastWalk", { x = 10, y = 10, w = 54, h = 54 }).x, 15)
		t.eq(HudLayout.nudged(edited, "Ore", { x = 10, y = 10, w = 54, h = 54 }).x, 10)
		t.ok(layout.hidden == nil, "the input layout is not mutated")
	end)

	t.test("phones put the offers in line with the menu buttons, clear of everything else", function()
		for _, viewport in viewports do
			if viewport.touch then
				local layout = HudLayout.compute(viewport.size, true, viewport.inset)
				if viewport.size.X > viewport.size.Y then
					t.ok(#layout.offers >= 1, viewport.name .. ": at least one offer cell")
				end
				local stick = layout.thumbstick :: HudLayout.Rect -- (its top 4 px may be grazed)
				local others = { layout.settings, layout.mine, layout.jump, layout.fastWalk, layout.objective,
					{ x = stick.x, y = stick.y + 4, w = stick.w, h = stick.h - 4 } }
				for _, offer in layout.offers do
					local aligned = false
					for _, button in layout.buttons do
						if math.abs(button.x - offer.x) < 0.5 or math.abs(button.y - offer.y) < 0.5 then aligned = true end
						t.ok(not HudLayout.overlaps(offer, button), viewport.name .. ": offer clear of a menu button")
					end
					t.ok(aligned, viewport.name .. ": offer shares a row or column with the menu buttons")
					t.ok(offer.x >= 0 and offer.y >= layout.inset and offer.x + offer.w <= viewport.size.X
						and offer.y + offer.h <= viewport.size.Y, viewport.name .. ": offer on screen")
					for _, other in others do
						t.ok(not HudLayout.overlaps(offer, other), viewport.name .. ": offer clear of the controls")
					end
				end
			end
		end
	end)

	t.test("on a landscape phone the offers fill the two cells under Rebirth, completing the grid", function()
		local layout = HudLayout.compute(Vector2.new(844, 390), true)
		local rebirth = layout.buttons.REBIRTH
		t.eq(#layout.offers, 2) -- a fourth column would squeeze the meteor objective
		t.near(layout.offers[1].x, rebirth.x, 0.5)
		t.near(layout.offers[1].y, layout.buttons.DAILY.y, 0.5)
		t.near(layout.offers[2].x, rebirth.x, 0.5)
		t.near(layout.offers[2].y, layout.buttons.CODES.y, 0.5)
	end)

	t.test("desktop leaves the offers to their column above Index", function()
		t.eq(#HudLayout.compute(Vector2.new(1920, 1080), false).offers, 0)
	end)

end
