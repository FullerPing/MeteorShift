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
local Price = require(RS.Shared.Price)
local Rebirth = require(RS.Shared.Rebirth)
local N = require(script.Parent.Parent.NativeUI)
local Preview = require(script.Parent.Parent.NativePreview)
local ExactNavButton = require(script.Parent.Parent.ExactNavButton)
local ShopMenu = require(script.Parent.Parent.NativeMenus.Shop)
local player = Players.LocalPlayer
local Controller = Knit.CreateController({ Name = "ShopController" })
local wantOpen, wantHighlight = false, false
local refresh: (() -> ())? = nil
local MET, UNMET = Color3.fromRGB(14, 122, 82), Color3.fromRGB(190, 40, 50) -- requirement values on the light cards
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
		-- the ribbon goes blue like the other menus
		local header = shopGui.Panel:FindFirstChild("Header")
		if header and header:IsA("GuiObject") then header.BackgroundColor3 = N.CYAN end
	end)
	gui.Enabled = true
	local p: any, nav: any = gui.Panel, gui.ShopButton
	local evolvePanel: any = gui.EvolvePanel
	local body: any = evolvePanel.EvolveBody
	local navRefs = ExactNavButton.bind(nav)
	local state: any = nil
	local tab, notice = "pickaxe", ""
	local busyId: string? = nil
	local geometry = ShopLayout.compute(N.hudLayout().viewport, N.hudLayout().inset)
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
	local footerSize: number? = nil
	local function put(object: GuiObject, r: ShopLayout.Rect)
		object.Position, object.Size = UDim2.fromOffset(r.x, r.y), UDim2.fromOffset(r.w, r.h)
	end
	-- The EVOLVE NOW button: the Robux price on the same line once known, usable at any time (the level cap is skipped)
	local function skipAlt(kind: string, tier: number, e: any): { text: string, enabled: boolean }?
		local product = if e then skipProduct(kind, tier) else nil
		if not product then return nil end
		loadRobux(product.Id, update)
		local price = robux[product.Id]
		return {
			text = "EVOLVE NOW · R$ " .. (if type(price) == "number" then Format.number(price) else "..."),
			enabled = type(price) == "number" and busyId == nil,
		}
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
			return {
				{ name = "Capacity", value = "+" .. Format.number(math.floor(after - now + 0.5)) .. " ore" },
				{ name = "New capacity", value = Format.number(math.floor(now)) .. " → " .. Format.number(math.floor(after)) },
			}
		end
		local a, b = Gear.pickaxe(tier, level), Gear.pickaxe(tier, to)
		local rows = { { name = "Mining power", value = string.format("+%.1f%%", (b.Power / a.Power - 1) * 100) } }
		if b.Swing > 0 and b.Swing < a.Swing then table.insert(rows, { name = "Swing speed", value = string.format("+%.1f%%", (a.Swing / b.Swing - 1) * 100) }) end
		table.insert(rows, { name = "Reach", value = string.format("+%.2f studs", b.Reach - a.Reach) })
		table.insert(rows, { name = "Crit chance", value = string.format("+%.1f%%", (b.CritChance - a.CritChance) * 100) })
		return rows
	end
	local function requirement(row: any, label: string, value: string, met: boolean)
		row.Label.Text = label
		row.Value.Text = (if met then "✓ " else "") .. value
		row.Value.TextColor3 = if met then MET else UNMET
	end
	update = function()
		local g = geometry
		local open = player:GetAttribute("ShopOpen") == true
		p.Visible, gui.Dimmer.Visible = open, open
		nav.Visible = not open
		p.AnchorPoint = Vector2.zero
		p.Position, p.Size = UDim2.fromOffset(g.panel.x, g.panel.y), UDim2.fromOffset(g.panel.w, g.panel.h)
		-- the gold wallet chip: beside the close button, or under the title on a phone
		p.Wallet.Position = if g.narrow then UDim2.fromOffset(g.padding + 24, g.padding + 44) elseif g.compact then UDim2.new(1, -216, 0, 6) else UDim2.new(1, -216, 0, 10)
		p.Wallet.Size = UDim2.fromOffset(150, if g.compact or g.narrow then 30 else 34)
		p.Wallet.Text = if state then Format.cash(state.cash) else "..."
		p.Title.Size = UDim2.new(1, if g.narrow then -80 else -330, 0, 44)
		-- two centred tabs rather than a full-width bar
		local tabsW = math.min(g.panel.w - g.padding * 2, 440)
		p.Tabs.Position, p.Tabs.Size = UDim2.fromOffset((g.panel.w - tabsW) / 2, g.tabsY), UDim2.fromOffset(tabsW, g.tabsH)
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
			local box = ShopLayout.screen(g.panel.w - 2 * g.padding - 8, g.carouselH, g.narrow, not g.popout and kind == tab, #rows)
			screen.Visible = tab == kind
			put(screen, { x = g.padding, y = g.carouselY, w = g.panel.w - 2 * g.padding, h = g.carouselH })
			screen.CanvasSize = UDim2.fromOffset(0, box.canvasH)
			for key, object in { GearName = box.name, TierText = box.tier, Well = box.well, InfoCard = box.info, LevelLabel = box.levelLabel,
				LevelValue = box.levelValue, QtyLabel = box.qtyLabel, Upgrade = box.upgrade } do
				put(screen[key], object)
			end
			for index, rect in box.amounts do put(screen["Amount" .. index], rect) end
			screen.QtyLabel.Visible = not g.narrow and not capped
			screen.GearName.Text = tiers[tier].Name
			screen.GearName.TextSize = if g.narrow then 24 else 32
			screen.TierText.Text = "Tier " .. tier .. " of " .. #tiers .. "  ·  Level cap " .. Gear.cap(tier)
			local want = kind .. ":" .. tier
			if previews[kind] ~= want then Preview.gear(screen.Well.Preview, kind, tier); previews[kind] = want end

			-- the level and the stat rows: the whole purchase, e.g. "1 → 10" with MAX
			screen.LevelValue.Text = if capped then "Lv. " .. level else level .. " → " .. (level + steps)
			for index = 1, 4 do
				local row = screen["Stat" .. index]
				row.Visible = rows[index] ~= nil
				if rows[index] then
					put(row, box.stats[index])
					row.Label.Text, row.Value.Text = rows[index].name, rows[index].value
					row.Label.Size = if rows[index].value == "" then UDim2.fromScale(1, 1) else UDim2.fromScale(0.58, 1)
				end
			end
			for index = 1, 3 do
				screen["Amount" .. index].BackgroundColor3 = if index == amountOf[kind] then N.GREEN else N.CARD
				screen["Amount" .. index].Visible = not capped
			end
			local canBuy = state ~= nil and busyId == nil and not capped and count >= 1
			N.enable(screen.Upgrade, canBuy, N.GREEN)
			screen.Upgrade.Text = if busyId == kind .. "_level" then "UPGRADING..."
				elseif capped then (if tier == #tiers then "MAX LEVEL" else "TIER CAP · EVOLVE")
				elseif count > 1 then string.format("UPGRADE %d LEVELS · %s", count, Format.cash(total))
				else "UPGRADE · " .. Format.cash(if count > 0 then total else single or 0)

			-- the next evolution, for the tab on show: beside the shop, or stacked under its controls
			if kind == tab then
				evolveShown = e ~= nil
				body.Visible = e ~= nil
				if e then
					local ready = e.ready and state ~= nil and state.level >= Levels.evolveLevel(e.tier)
					local affordable = state ~= nil and Price.canAfford(state, e.cost, e.shards)
					local alt = skipAlt(kind, tier, e)
					local inner = if g.popout then g.evolvePanel.w - 32 else box.evolve.w
					local L = ShopLayout.evolve(inner, not g.popout, alt ~= nil)
					if g.popout then
						body.Parent = evolvePanel
						body.Position, body.Size = UDim2.fromOffset(16, 78), UDim2.fromOffset(inner, L.height)
					else
						body.Parent = screen
						put(body, box.evolve)
					end
					body.Card.Visible, body.Heading.Visible = not g.popout, not g.popout
					for key, object in { Heading = L.heading, NextWell = L.well, NextName = L.name, NextTier = L.tier, Evolve = L.evolve, EvolveNow = L.alt } do
						put(body[key], object)
					end
					for index, r in L.rows do put(body["Req" .. index], r) end
					local nextItem = tiers[e.tier]
					body.NextName.Text = nextItem.Name
					body.NextTier.Text = "Tier " .. e.tier .. " of " .. #tiers
					local nextWant = kind .. ":" .. e.tier
					if previews.next ~= nextWant then Preview.gear(body.NextWell.Preview, kind, e.tier); previews.next = nextWant end
					local needLevel = Levels.evolveLevel(e.tier)
					requirement(body.Req1, "Required gear level", level .. " / " .. Gear.cap(tier), level >= Gear.cap(tier))
					requirement(body.Req2, "Required player level", (state and state.level or 1) .. " / " .. needLevel, state ~= nil and state.level >= needLevel)
					requirement(body.Req3, "Cost", Price.text(e.cost, e.shards), affordable)
					N.enable(body.Evolve, ready and affordable and busyId == nil, N.GREEN)
					body.Evolve.Text = if busyId == kind .. "_evolve" then "EVOLVING..." else "EVOLVE"
					body.EvolveNow.Visible = alt ~= nil
					if alt then
						body.EvolveNow.Text = alt.text
						N.enable(body.EvolveNow, alt.enabled, N.ORANGE)
					end
				end
			end
		end
		evolvePanel.Visible = open and g.popout and evolveShown
		put(evolvePanel, g.evolvePanel)
		for index, id in { "pickaxe", "backpack" } do
			local tabButton = p.Tabs[id .. "Tab"]
			tabButton.Position, tabButton.Size = UDim2.new((index - 1) / 2, if index == 1 then 0 else 4, 0, 0), UDim2.new(1 / 2, -4, 1, 0)
			tabButton.BackgroundColor3 = if tab == id then (if id == "pickaxe" then N.ORANGE else N.CYAN) else N.CARD
		end
		-- the footer only carries notices now: the player level sits with the evolution requirements
		footerSize = footerSize or p.Footer.TextSize
		if g.compact then
			p.Footer.Position, p.Footer.Size = UDim2.new(1, -290, 0, 30), UDim2.fromOffset(230, 20)
			p.Footer.TextSize = 14
		else
			p.Footer.Position, p.Footer.Size = UDim2.fromOffset(12, g.footerY), UDim2.fromOffset(g.panel.w - 24, 44)
			p.Footer.TextSize = footerSize
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
		purchase(kind .. "_level", (if kind == "pickaxe" then "Pickaxe" else "Backpack") .. " upgraded.", function()
			local any = false
			for i = 1, wanted do if not shop:Upgrade(kind) then break end; any = true; if i < wanted then task.wait(.025) end end
			return any
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
	player:GetAttributeChangedSignal("ShopOpen"):Connect(update)
	Knit.GetService("PlayerStateService").State:Observe(function(snapshot) state = snapshot; update() end)
	N.onLayoutChanged(function(hud)
		geometry = ShopLayout.compute(hud.viewport, hud.inset)
		ExactNavButton.layout(nav, hud, "SHOP")
		update()
	end)
	player:SetAttribute("ShopOpen", wantOpen)
end
return Controller
