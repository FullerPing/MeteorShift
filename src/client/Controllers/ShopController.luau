--!strict
-- Bind the Gear shop (GearShop ScreenGui); purchases and ownership stay server-side. One screen per gear kind: the
-- name and preview with a card for the level and what the upgrade gives, a quantity and Upgrade. The next evolution
-- (EvolvePanel's body) pops out beside the shop on a wide window and is stacked under the controls on a narrow one.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Knit = require(RS.Packages.Knit)
local Config = require(RS.Shared.Config)
local Format = require(RS.Shared.Format)
local ShopLayout = require(RS.Shared.EquipmentShopLayout)
local Gear = require(RS.Shared.Gear)
local Levels = require(RS.Shared.Levels)
local Palette = require(RS.Shared.MenuPalette)
local Price = require(RS.Shared.Price)
local Rebirth = require(RS.Shared.Rebirth)
local N = require(script.Parent.Parent.NativeUI)
local Preview = require(script.Parent.Parent.NativePreview)
local ExactNavButton = require(script.Parent.Parent.ExactNavButton)
local ShopMenu = require(script.Parent.Parent.NativeMenus.Shop)
local Theme = require(script.Parent.Parent.MenuTheme)
local player = Players.LocalPlayer
local Controller = Knit.CreateController({ Name = "ShopController" })
local wantOpen, wantHighlight = false, false
local refresh: (() -> ())? = nil
local MET, UNMET = Palette.MET, Palette.UNMET -- requirement values on the evolution column
local ROBUX = Format.ROBUX
function Controller:Open()
	wantOpen = true
	player:SetAttribute("ShopOpen", true)
	if refresh then refresh() end
end
function Controller:SetHighlight(on: boolean)
	wantHighlight = on
	if refresh then refresh() end
end
function Controller:KnitStart()
	local shop = Knit.GetService("ShopService")
	local gui = N.get("GearShop", function(shopGui)
		-- An authored copy from before the redesign has no ShopLayout mark: swap in the current panels
		if shopGui:GetAttribute("ShopLayout") ~= ShopMenu.LAYOUT then
			local fresh = ShopMenu.build()
			for _, name in { "Panel", "EvolvePanel" } do
				local old = shopGui:FindFirstChild(name)
				if old then old:Destroy() end
			end
			for _, name in { "Panel", "EvolvePanel" } do fresh:WaitForChild(name).Parent = shopGui end
			fresh:Destroy()
			shopGui:SetAttribute("ShopLayout", ShopMenu.LAYOUT)
		end
		-- the screen behind the menu is 20% alpha (an older saved copy still has the heavier dim)
		local dimmer = shopGui:FindFirstChild("Dimmer")
		if dimmer and dimmer:IsA("GuiObject") then dimmer.BackgroundTransparency = .8 end
	end)
	gui.Enabled = true
	local p: any, nav: any = gui.Panel, gui.ShopButton
	local evolvePanel: any = gui.EvolvePanel
	local body: any = evolvePanel.EvolveBody
	local navRefs = ExactNavButton.bind(nav)
	local state: any = nil
	local tab, notice = "pickaxe", ""
	local busyId: string? = nil
	local hud0 = N.hudLayout()
	local view = ShopLayout.view(hud0.viewport, hud0.inset)
	local geometry = ShopLayout.compute(view.viewport, view.inset, view.wide)
	local previews: { [string]: string } = {}
	-- EVOLVE NOW: the tier-up developer product for the item's current tier (Config.Monetization), if it is on sale
	local robux: { [number]: number | boolean } = {} -- product id -> price in Robux, false once a lookup failed
	local function skipProduct(kind: string, tier: number): any
		local product = Config.Monetization.Products[(if kind == "pickaxe" then "PickaxeT" else "BackpackT") .. tier]
		return if product and product.Id ~= 0 then product else nil
	end
	local function loadRobux(id: number, update: () -> ())
		if robux[id] ~= nil then return end
		robux[id] = false
		task.spawn(function()
			local ok, info = pcall(function() return MarketplaceService:GetProductInfoAsync(id, Enum.InfoType.Product) end)
			if ok and type(info) == "table" and type(info.PriceInRobux) == "number" and info.IsForSale ~= false then robux[id] = info.PriceInRobux end
			update()
		end)
	end
	local tiersOf = { pickaxe = Config.Pickaxes, backpack = Config.Backpacks }
	local update: () -> ()
	local function purchase(id: string, message: string, callback: () -> any)
		if busyId then return end
		busyId, notice = id, ""; update()
		task.spawn(function()
			local ok, result = pcall(callback)
			busyId = nil
			if not ok then notice = "Couldn't complete that. Please try again." elseif result then notice = message end
			update()
		end)
	end
	-- the quantity picker: 1x, 10x or as many as you can afford
	local AMOUNTS = { 1, 10, math.huge }
	local amountOf = { pickaxe = 1, backpack = 1 }
	local function close() wantOpen = false; player:SetAttribute("ShopOpen", false); update() end
	local function put(object: GuiObject, r: ShopLayout.Rect)
		object.Position, object.Size = UDim2.fromOffset(r.x, r.y), UDim2.fromOffset(r.w, r.h)
	end
	-- The EVOLVE NOW button: the Robux price on the same line once known, usable at any time (the level cap is skipped)
	local function skipAlt(kind: string, tier: number, e: any): { text: string, price: string, enabled: boolean }?
		local product = if e then skipProduct(kind, tier) else nil
		if not product then return nil end
		loadRobux(product.Id, update)
		local price = robux[product.Id]
		local amount = ROBUX .. " " .. (if type(price) == "number" then Format.number(price) else "...")
		return { text = "EVOLVE NOW · " .. amount, price = amount, enabled = type(price) == "number" and busyId == nil }
	end
	-- What the chosen quantity adds, as aligned name / value rows, from the item's stats at the two levels
	local function stats(kind: string, tier: number, level: number, steps: number, capped: boolean): { { name: string, value: string } }
		if capped then
			return if tier == #tiersOf[kind] then { { name = "Fully upgraded.", value = "" } }
				else { { name = "At the tier cap.", value = "" }, { name = "Evolve to keep growing.", value = "" } }
		end
		local to = level + steps
		if kind == "backpack" then
			local now, after = Gear.capacity(tier, level), Gear.capacity(tier, to)
			return { { name = "Capacity", value = Format.number(math.floor(now)) .. " → " .. Format.number(math.floor(after)) } }
		end
		local a, b = Gear.pickaxe(tier, level), Gear.pickaxe(tier, to)
		local rows = { { name = "Mining power", value = string.format("+%.1f%%", (b.Power / a.Power - 1) * 100) } }
		if b.Swing > 0 and b.Swing < a.Swing then table.insert(rows, { name = "Swing speed", value = string.format("+%.1f%%", (a.Swing / b.Swing - 1) * 100) }) end
		return rows
	end
	local function requirement(row: any, label: string, value: string, met: boolean)
		row.Label.Text = label
		row.Value.Text = (if met then "✓ " else "") .. value
		row.Value.TextColor3 = if met then MET else UNMET
	end
	-- Text sizes. The owner's mockup is a 760 px panel drawn scaled up, so its sizes are small numbers (measured from the
	-- mockup's cap heights); the single column (small screens) is drawn near 1:1 and needs bigger ones.
	local SIZES = {
		wide = { title = 30, wallet = 16, tab = 18, name = 24, tier = 13, level = 16, levelValue = 20, stat = 15, statValue = 16, qty = 16, seg = 15,
			upgrade = 17, heading = 16, nextName = 20, nextTier = 13, req = 14, evolve = 17, evolveNow = 17, notice = 13 },
		column = { title = 26, wallet = 18, tab = 16, name = 26, tier = 14, level = 17, levelValue = 24, stat = 16, statValue = 16, qty = 15, seg = 16,
			upgrade = 20, heading = 12, nextName = 22, nextTier = 13, req = 15, evolve = 17, evolveNow = 16, notice = 14 },
	}
	local function rowSize(row: any, size: number, valueSize: number?)
		row.Label.TextSize = size
		row.Value.TextSize = valueSize or size
		local limit = row.Value:FindFirstChildOfClass("UITextSizeConstraint")
		if limit then limit.MaxTextSize = valueSize or size end
	end
	update = function()
		local g = geometry
		local S = if g.popout then SIZES.wide else SIZES.column
		local open = player:GetAttribute("ShopOpen") == true
		p.Visible, gui.Dimmer.Visible = open, open
		nav.Visible = not open
		N.place(p, g.panel, view)
		-- the title ribbon, Close, the cash chip
		local top = g.headerTop
		local ribbon = p.Ribbon
		p.Wallet.Text = if state then Format.cash(state.cash) else "..."
		if g.popout then
			-- the mockup: the ribbon pokes out of the top left, Close sits on the corner, the chip under it
			ribbon.Position, ribbon.Size, ribbon.Rotation = UDim2.fromOffset(10, -24), UDim2.fromOffset(256, 66), -1.5
			p.Close.Position, p.Close.Size = UDim2.new(1, 8, 0, -14), UDim2.fromOffset(48, 50)
			p.Wallet.Position, p.Wallet.Size = UDim2.fromOffset(557, g.footerY), UDim2.fromOffset(141, 31)
		else
			-- a phone: the ribbon inside the top band, the wallet beside Close, or under the ribbon on a portrait screen
			local titleRow = if g.narrow then 48 else g.headerH
			local closeH = if g.compact then 44 else 50
			ribbon.Rotation = 0
			ribbon.Position, ribbon.Size = UDim2.fromOffset(top + 2, top), UDim2.fromOffset(if g.narrow then 190 else 220, titleRow)
			p.Close.Size = UDim2.fromOffset(closeH, closeH)
			p.Close.Position = UDim2.new(1, -(top + 6), 0, top + math.floor((titleRow - closeH) / 2))
			local walletH = if g.narrow then 30 elseif g.compact then 36 else 40
			p.Wallet.Size = UDim2.fromOffset(140, walletH)
			p.Wallet.Position = if g.narrow then UDim2.fromOffset(top + 16, top + 50)
				else UDim2.new(1, -(top + 6 + closeH + 2 + 12 + 140), 0, top + math.floor((g.headerH - walletH) / 2))
		end
		-- two tabs across the left column
		p.Tabs.Position, p.Tabs.Size = UDim2.fromOffset(g.padding, g.tabsY), UDim2.fromOffset(g.contentW, g.tabsH)
		local priceMult = Rebirth.priceMult(if state then state.rebirths else 0)
		local cash = if state then state.cash else 0
		local evolveShown = false
		for _, kind in { "pickaxe", "backpack" } do
			local screen, tiers = p[kind .. "Screen"], tiersOf[kind]
			local tier = if state then state[kind .. "Tier"] or 1 else 1
			local level = if state then state[kind .. "Level"] or 1 else 1
			local e = Gear.evolution(kind, tier, level, priceMult)
			local capped = not Gear.canLevel(kind, tier, level)
			local count, total = Gear.bulk(kind, tier, level, cash, AMOUNTS[amountOf[kind]], priceMult)
			local single = Gear.price(kind, tier, level, priceMult)
			local steps = math.max(count, 1) -- the levels the stats preview: what the amount would buy, or the next one
			local rows = stats(kind, tier, level, steps, capped)
			local box, frame
			if g.popout then
				-- the owner's frame to the pixel: the screen is the card's width plus its 4 px margins
				box = ShopLayout.screen(g.contentW + 8, g.carouselH + 8, false, false, #rows, true)
				frame = { x = g.padding - 4, y = g.carouselY - 4, w = g.contentW + 8, h = g.carouselH + 8 }
			else
				box = ShopLayout.screen(g.contentW - 8, g.carouselH, g.narrow, kind == tab, #rows)
				frame = { x = g.padding, y = g.carouselY, w = g.contentW, h = g.carouselH }
			end
			screen.Visible = tab == kind
			put(screen, frame)
			screen.CanvasSize = UDim2.fromOffset(0, box.canvasH)
			for key, object in { MainCard = box.card, GearName = box.name, TierText = box.tier, TierPill = box.tier, CapText = box.cap, Well = box.well,
				LevelPill = box.levelPill, InfoCard = box.info, LevelRow = box.levelRow, LevelLabel = box.levelLabel, LevelValue = box.levelValue,
				QtyLabel = box.qtyLabel, QtyStrip = box.strip, Upgrade = box.upgrade } do
				put(screen[key], object)
			end
			for index, rect in box.amounts do put(screen["Amount" .. index], rect) end
			for index = 1, 3 do
				local divider = screen["Divider" .. index]
				divider.Visible = box.dividers[index] ~= nil and not capped
				if box.dividers[index] then put(divider, box.dividers[index]) end
			end
			-- the wide layout sits straight on the body; small screens keep the white card behind the name and the info
			screen.MainCard.BackgroundTransparency = if g.popout then 1 else 0
			screen.MainCard.UIStroke.Enabled = not g.popout
			screen.QtyLabel.Visible = box.qtyLabel.w > 0 and not capped
			screen.QtyLabel.TextSize = S.qty
			screen.QtyStrip.Visible = not capped and not g.popout
			screen.GearName.Text = tiers[tier].Name
			screen.GearName.TextSize = if g.narrow then 24 elseif g.compact then 28 else S.name
			-- the tier: a pill and the level cap beside it on the wide layout, one line on small screens
			screen.TierText.Visible = not g.popout
			screen.TierPill.Visible, screen.CapText.Visible, screen.LevelPill.Visible = g.popout, false, g.popout
			screen.TierText.Text = "Tier " .. tier .. " / " .. #tiers
			screen.TierText.TextSize = S.tier
			screen.TierPill.Label.Text = "Tier " .. tier .. " / " .. #tiers
			screen.CapText.Text = "Level cap " .. Gear.cap(tier)
			screen.CapText.TextSize = S.tier
			screen.LevelPill.Label.Text = "LEVEL " .. level
			screen.LevelLabel.TextSize, screen.LevelValue.TextSize = S.level, S.levelValue
			local want = kind .. ":" .. tier
			if previews[kind] ~= want then Preview.gear(screen.Well.Preview, kind, tier); previews[kind] = want end

			-- the level and the stat rows: the whole purchase, e.g. "1 → 10" with MAX
			screen.LevelValue.Text = if capped then "Lv. " .. level else level .. " → " .. (level + steps)
			for index = 1, 4 do
				local row = screen["Stat" .. index]
				row.Visible = rows[index] ~= nil
				if rows[index] then
					put(row, box.stats[index])
					rowSize(row, S.stat, S.statValue)
					row.Label.Text, row.Value.Text = rows[index].name, rows[index].value
					row.Label.Size = if rows[index].value == "" then UDim2.fromScale(1, 1) else UDim2.fromScale(0.58, 1)
				end
			end
			for index = 1, 3 do
				local amount = screen["Amount" .. index]
				Theme.select(amount, index == amountOf[kind])
				amount.TextSize = S.seg
				amount.Visible = not capped
			end
			local canBuy = state ~= nil and busyId == nil and not capped and count >= 1
			Theme.state(screen.Upgrade, canBuy, "lime")
			screen.Upgrade.TextSize = S.upgrade
			screen.Upgrade.Text = if busyId == kind .. "_level" then "UPGRADING..."
				elseif capped then (if tier == #tiers then "MAX LEVEL" else "TIER CAP · EVOLVE")
				elseif count > 1 then string.format("UPGRADE %d LEVELS · %s", count, Format.cash(total))
				else "UPGRADE · " .. Format.cash(if count > 0 then total else single or 0)

			-- the next evolution, for the tab on show: the panel's right column, or stacked under the controls
			if kind == tab then
				evolveShown = e ~= nil
				body.Visible = e ~= nil
				if e then
					local ready = e.ready and state ~= nil and state.level >= Levels.evolveLevel(e.tier)
					local affordable = state ~= nil and Price.canAfford(state, e.cost, e.shards)
					local alt = skipAlt(kind, tier, e)
					local inner = if g.popout then g.evolvePanel.w else box.evolve.w
					local L = ShopLayout.evolve(inner, not g.popout, alt ~= nil)
					if g.popout then
						body.Parent = evolvePanel
						body.Position, body.Size = UDim2.new(), UDim2.fromOffset(inner, g.evolvePanel.h)
					else
						body.Parent = screen
						put(body, box.evolve)
					end
					for key, object in { Card = L.card, Banner = L.banner, Heading = L.heading, NextWell = L.well, NextName = L.name, NextTier = L.tier,
						ReqBar = L.bar, ReqBar2 = L.bar2, Evolve = L.evolve, EvolveNow = L.alt, CapEvolve = L.capEvolve, CapAlt = L.capAlt } do
						put(body[key], object)
					end
					-- the column: captions over two buttons that carry only their prices; stacked, the buttons carry the words
					body.ReqBar2.Visible = L.bar2.h > 0
					body.CapEvolve.Visible = L.capEvolve.w > 0
					body.CapAlt.Visible = L.capAlt.w > 0 and alt ~= nil
					for index, r in L.rows do put(body["Req" .. index], r); rowSize(body["Req" .. index], S.req) end
					body.Heading.TextSize, body.NextName.TextSize, body.NextTier.TextSize = S.heading, S.nextName, S.nextTier
					local nextItem = tiers[e.tier]
					body.NextName.Text = nextItem.Name
					body.NextTier.Text = "Tier " .. e.tier .. " / " .. #tiers
					local nextWant = kind .. ":" .. e.tier
					if previews.next ~= nextWant then Preview.gear(body.NextWell.Preview, kind, e.tier); previews.next = nextWant end
					local needLevel = Levels.evolveLevel(e.tier)
					requirement(body.Req1, "Gear level", level .. " / " .. Gear.cap(tier), level >= Gear.cap(tier))
					requirement(body.Req2, "Player level", (state and state.level or 1) .. " / " .. needLevel, state ~= nil and state.level >= needLevel)
					body.ReqBar.Fill.Size = UDim2.fromScale(math.clamp(level / Gear.cap(tier), 0, 1), 1)
					body.ReqBar2.Fill.Size = UDim2.fromScale(math.clamp((state and state.level or 1) / needLevel, 0, 1), 1)
					-- the cost is on the button, which shows the plain face until the item is ready and you can pay
					Theme.state(body.Evolve, ready and affordable and busyId == nil, "lime")
					body.Evolve.TextSize = S.evolve
					body.Evolve.Text = if busyId == kind .. "_evolve" then "EVOLVING..."
						elseif g.popout then Price.text(e.cost, e.shards) else "EVOLVE · " .. Price.text(e.cost, e.shards)
					body.EvolveNow.Visible = alt ~= nil
					body.EvolveNow.TextSize = S.evolveNow
					if alt then
						body.EvolveNow.Text = if g.popout then alt.price else alt.text
						Theme.state(body.EvolveNow, alt.enabled, "gold")
					end
				end
			end
		end
		-- on a wide window the evolution is a column inside the panel; otherwise its body is in the screen and the column is unused
		evolvePanel.Parent = if g.popout then p else gui
		if g.popout then
			evolvePanel.Position, evolvePanel.Size = UDim2.fromOffset(g.evolvePanel.x, g.evolvePanel.y), UDim2.fromOffset(g.evolvePanel.w, g.evolvePanel.h)
		end
		evolvePanel.Visible = open and g.popout and evolveShown
		local gap = if g.popout then 12 else 8
		for index, id in { "pickaxe", "backpack" } do
			local tabButton = p.Tabs[id .. "Tab"]
			tabButton.Position = UDim2.new((index - 1) / 2, if index == 1 then 0 else gap / 2, 0, 0)
			tabButton.Size = UDim2.new(1 / 2, -gap / 2, 1, 0)
			tabButton.TextSize = S.tab
			Theme.tab(tabButton, tab == id)
		end
		-- the footer only carries notices now: the player level sits with the evolution requirements
		if g.popout then
			-- the mockup has no line under the screen: the notice goes between the ribbon and the cash chip
			p.Footer.Position, p.Footer.Size = UDim2.fromOffset(280, g.footerY), UDim2.fromOffset(266, g.footerH)
			p.Footer.TextSize, p.Footer.TextColor3 = S.notice, Palette.NAVY
		elseif g.compact then
			-- a phone in landscape has no room under the screen: the notice goes in the header bar, between the title and the wallet
			p.Footer.Position, p.Footer.Size = UDim2.fromOffset(top + 190, top), UDim2.fromOffset(math.max(0, g.panel.w - 190 - 240 - top), g.headerH)
			p.Footer.TextSize, p.Footer.TextColor3 = S.notice, Palette.NAVY
		else
			p.Footer.Position, p.Footer.Size = UDim2.fromOffset(g.padding, g.footerY), UDim2.fromOffset(g.contentW, g.footerH)
			p.Footer.TextSize, p.Footer.TextColor3 = S.notice, Palette.MUTED
		end
		p.Footer.Text = if notice ~= "" then notice elseif not state then "Loading your equipment..." else ""
		navRefs.badge.Visible = wantHighlight
	end
	refresh = update
	local function upgrade(kind: string)
		if not state or busyId then return end
		local tier, level, priceMult = state[kind .. "Tier"], state[kind .. "Level"] or 1, Rebirth.priceMult(state.rebirths)
		local wanted = Gear.bulk(kind, tier, level, state.cash, AMOUNTS[amountOf[kind]], priceMult)
		if wanted < 1 then return end
		-- one request for the whole batch: the server buys the levels in a row
		purchase(kind .. "_level", (if kind == "pickaxe" then "Pickaxe" else "Backpack") .. " upgraded.", function()
			return shop:Upgrade(kind, wanted)
		end)
	end
	local function evolve(kind: string)
		if not state or busyId then return end
		local e = Gear.evolution(kind, state[kind .. "Tier"], state[kind .. "Level"] or 1, Rebirth.priceMult(state.rebirths))
		if not e or not e.ready or state.level < Levels.evolveLevel(e.tier) or not Price.canAfford(state, e.cost, e.shards) then return end
		purchase(kind .. "_evolve", "Evolved.", function() return shop:Evolve(kind) end)
	end
	local function evolveNow(kind: string)
		if not state then return end
		local product = skipProduct(kind, state[kind .. "Tier"] or 1)
		local e = Gear.evolution(kind, state[kind .. "Tier"] or 1, state[kind .. "Level"] or 1, 1)
		if not product or not e or type(robux[product.Id]) ~= "number" then return end
		local ok, err = pcall(function() MarketplaceService:PromptProductPurchase(player, product.Id) end)
		if not ok then warn("[ShopController] purchase prompt failed:", err) end
	end
	for _, kind in { "pickaxe", "backpack" } do
		local screen = p[kind .. "Screen"]
		screen.Upgrade.Activated:Connect(function() upgrade(kind) end)
		for index = 1, 3 do
			screen["Amount" .. index].Activated:Connect(function() amountOf[kind] = index; update() end)
		end
	end
	-- the body moves between the pop-out and the shop, so its buttons act on the tab on show
	body.Evolve.Activated:Connect(function() evolve(tab) end)
	body.EvolveNow.Activated:Connect(function() evolveNow(tab) end)
	for _, id in { "pickaxe", "backpack" } do p.Tabs[id .. "Tab"].Activated:Connect(function() tab, notice = id, ""; update() end) end
	p.Close.Activated:Connect(close); gui.Dimmer.Activated:Connect(close)
	nav.Activated:Connect(function() if player:GetAttribute("ShopOpen") then close() else self:Open() end end)
	UserInputService.InputBegan:Connect(function(input)
		if not player:GetAttribute("ShopOpen") or UserInputService:GetFocusedTextBox() then return end
		if input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB then close() end
	end)
	shop.Open:Connect(function() self:Open() end)
	shop.Notice:Connect(function(message) notice = message; update() end)
	-- a closed shop drops its notice and skips State flushes; opening renders the latest snapshot
	player:GetAttributeChangedSignal("ShopOpen"):Connect(function()
		if player:GetAttribute("ShopOpen") ~= true then notice = "" end
		update()
	end)
	Knit.GetService("PlayerStateService").State:Observe(function(snapshot)
		state = snapshot
		if player:GetAttribute("ShopOpen") == true then update() end
	end)
	N.onLayoutChanged(function(hud)
		view = ShopLayout.view(hud.viewport, hud.inset)
		geometry = ShopLayout.compute(view.viewport, view.inset, view.wide)
		ExactNavButton.layout(nav, hud, "SHOP")
		update()
	end)
	player:SetAttribute("ShopOpen", wantOpen)
end
return Controller
