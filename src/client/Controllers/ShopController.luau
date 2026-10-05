--!strict
-- Bind authored ScreenGui gear controls; purchases and ownership stay server-side.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local MarketplaceService = game:GetService("MarketplaceService")
local TweenService = game:GetService("TweenService")
local Knit = require(RS.Packages.Knit)
local Config = require(RS.Shared.Config)
local Format = require(RS.Shared.Format)
local ShopLayout = require(RS.Shared.EquipmentShopLayout)
local Gear = require(RS.Shared.Gear)
local Levels = require(RS.Shared.Levels)
local Price = require(RS.Shared.Price)
local Pets = require(RS.Shared.Pets)
local N = require(script.Parent.Parent.NativeUI)
local Preview = require(script.Parent.Parent.NativePreview)
local ExactNavButton = require(script.Parent.Parent.ExactNavButton)
local player = Players.LocalPlayer
local Controller = Knit.CreateController({ Name = "ShopController" })
local wantOpen, wantHighlight = false, false
local refresh: (() -> ())? = nil
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
	local shop, pets = Knit.GetService("ShopService"), Knit.GetService("PetService")
	local petVisuals = Knit.GetController("PetVisualController")
	local gui = N.get("GearShop")
	gui.Enabled = true
	local p: any, nav: any = gui.Panel, gui.ShopButton
	local navRefs = ExactNavButton.bind(nav)
	local state: any = nil
	local tab, notice = "pickaxe", ""
	local busyId: string? = nil
	local geometry = ShopLayout.compute(N.hudLayout().viewport, N.hudLayout().inset)
	local previews: { [string]: number } = {}
	local previewOpen = false
	local settingsOf = { pickaxe = Config.Gear.Pickaxe, backpack = Config.Gear.Backpack }
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
	local function statValue(kind: string, stat: string, level: number): string
		if kind == "backpack" then return Format.number(math.floor(Gear.capacity(1, { capacity = level }))) .. " ore" end
		local levels = { power = 1, speed = 1, reach = 1, crit = 1 }
		levels[stat] = level
		local pick = Gear.pickaxe(1, levels)
		return if stat == "power" then string.format("%.2f", pick.Power) elseif stat == "speed" then string.format("%.2fs", pick.Swing)
			elseif stat == "reach" then string.format("%.1f studs", pick.Reach) else string.format("%.1f%%", pick.CritChance * 100)
	end
	local function close() wantOpen = false; player:SetAttribute("ShopOpen", false); update() end
	local function petEntry(id: string): any return state and state.pets and state.pets.owned[id] end
	local function equipped(id: string): boolean return state ~= nil and state.pets ~= nil and table.find(state.pets.equipped, id) ~= nil end
	local function applyBox(object: GuiObject, x: number, y: number, w: number, h: number)
		object.Position, object.Size = UDim2.fromOffset(x, y), UDim2.fromOffset(w, h)
	end
	update = function()
		local g = geometry
		local open = player:GetAttribute("ShopOpen") == true
		p.Visible, gui.Dimmer.Visible = open, open
		nav.Visible = not open
		p.AnchorPoint = Vector2.zero
		p.Position, p.Size = UDim2.fromOffset(g.panel.x, g.panel.y), UDim2.fromOffset(g.panel.w, g.panel.h)
		p.Wallet.Position = if g.narrow then UDim2.fromOffset(12, 50) else UDim2.new(1, -290, 0, 12)
		p.Wallet.Size = UDim2.fromOffset(230, 30)
		p.Title.Size = UDim2.new(1, if g.narrow then -80 else -330, 0, 44)
		p.Wallet.Text = if state then Format.cash(state.cash) .. " · " .. Format.number(state.shards) .. " shards" else "Loading..."
		p.Tabs.Position, p.Tabs.Size = UDim2.fromOffset(g.padding, g.tabsY), UDim2.fromOffset(g.panel.w - g.padding * 2, g.tabsH)
		for _, kind in { "pickaxe", "backpack" } do
			local screen, settings, tiers = p[kind .. "Screen"], settingsOf[kind], tiersOf[kind]
			local tier = if state then state[kind .. "Tier"] or 1 else 1
			local stats = if state then state[kind .. "Stats"] or {} else {}
			screen.Visible = tab == kind
			applyBox(screen, g.padding, g.carouselY, g.panel.w - 2 * g.padding, g.carouselH)
			screen.Showcase.Visible = not g.narrow
			screen.Rows.NarrowHeader.Visible = g.narrow
			screen.Rows.Position = UDim2.fromOffset(if g.narrow then 0 else 208, 0)
			screen.Rows.Size = UDim2.new(1, if g.narrow then 0 else -208, 1, 0)
			for _, display in { screen.Showcase, screen.Rows.NarrowHeader } do
				display.GearName.Text, display.TierText.Text = tiers[tier].Name, "TIER " .. tier .. " / " .. #tiers
			end
			if previews[kind] ~= tier then
				Preview.gear(screen.Showcase.Well.Preview, kind, tier)
				Preview.gear(screen.Rows.NarrowHeader.Well.Preview, kind, tier)
				previews[kind] = tier
			end
			for _, stat in settings.Stats do
				local row, level = screen.Rows[stat .. "Row"], stats[stat] or 1
				local cap = not Gear.canLevel(kind, tier, level)
				row.StatName.Text = settings.Names[stat] .. " LV " .. level
				row.Effect.Text = statValue(kind, stat, level) .. (if cap then "" else " > " .. statValue(kind, stat, level + 1))
				row.Effect.TextTruncate = Enum.TextTruncate.AtEnd
				row.CapStatus.Visible = cap
				row.CapStatus.Text = if tier == #tiers then "MAX LEVEL" else "TIER CAP\nEvolve below"
				for _, limit in { 1, 10 } do
					local b = row["Buy" .. limit]
					local count, total, allowed, allowedTotal = Gear.bulk(kind, tier, stat, level, if state then state.cash else 0, limit)
					b.Visible = not cap
					N.enable(b, state ~= nil and busyId == nil and count >= 1, N.ORANGE)
					b.Text = if allowed == 0 then "EVOLVE" else "+" .. (if count > 0 then count else allowed) .. "\n" .. Format.cash(if count > 0 then total else allowedTotal)
				end
			end
			local e, banner = Gear.evolution(kind, tier, stats), screen.Rows.EvolveBanner
			local ready = e ~= nil and e.ready and state ~= nil and state.level >= Levels.evolveLevel(e.tier)
			local affordable = state ~= nil and e ~= nil and Price.canAfford(state, e.cost, e.shards)
			banner.EvolveTitle.Text = if e then tiers[e.tier].Name else "FULLY EVOLVED"
			banner.GateBar.Visible = e ~= nil
			banner.GateBar.Fill.Size = UDim2.fromScale(math.clamp((stats[settings.Gate] or 1) / Gear.cap(tier), 0, 1), 1)
			banner.Needs.Text = if e then settings.Names[settings.Gate] .. " " .. (stats[settings.Gate] or 1) .. "/" .. Gear.cap(tier)
				.. " · Player level " .. (state and state.level or 1) .. "/" .. Levels.evolveLevel(e.tier) .. "\n" .. Price.text(e.cost, e.shards) else "Nothing left to evolve."
			N.enable(banner.Evolve, ready and affordable and busyId == nil, N.GREEN)
			banner.Evolve.Text = if not e then "MAX" elseif not ready then "LOCKED" elseif affordable then "EVOLVE" else "SAVE UP"
		end
		local pg = ShopLayout.petCards(g)
		local showPets = open and tab == "pets"
		if showPets and not previewOpen then
			petVisuals:ReserveShopPreviews(#Config.Pets.List)
			previewOpen = true
		elseif not showPets and previewOpen then
			for _, def in Config.Pets.List do
				Preview.clear(p.petsCarousel["pet_" .. def.Id].PreviewWell.Preview)
				previews[def.Id] = nil
			end
			petVisuals:ReserveShopPreviews(0)
			previewOpen = false
		end
		local count = #Config.Pets.Eggs + #Config.Pets.List
		p.petsCarousel.Visible = tab == "pets"
		applyBox(p.petsCarousel, g.padding, g.carouselY, g.panel.w - 2 * g.padding, g.carouselH)
		p.petsCarousel.CanvasSize = UDim2.fromOffset(count * (pg.cardWidth + pg.gap) - pg.gap + 8, pg.cardHeight + 8)
		for _, card in p.petsCarousel:GetChildren() do
			if not card:IsA("Frame") then continue end
			local w, h = pg.cardWidth, pg.cardHeight
			card.Size = UDim2.fromOffset(w, h)
			if pg.short then
				applyBox(card.PreviewWell, 12, 38, 128, h - 52)
				applyBox(card.ItemName, 154, 38, w - 168, 28)
				applyBox(card.Stats, 154, 72, w - 168, h - 162)
				applyBox(card.Price, 154, h - 78, w - 168, 22)
				applyBox(card.Purchase, 154, h - 52, w - 168, 44)
			else
				applyBox(card.PreviewWell, 12, 36, w - 24, 88)
				applyBox(card.ItemName, 12, 132, w - 24, 28)
				applyBox(card.Stats, 12, 166, w - 24, h - 252)
				applyBox(card.Price, 12, h - 78, w - 24, 22)
				applyBox(card.Purchase, 12, h - 52, w - 24, 44)
			end
		end
		for _, egg in Config.Pets.Eggs do
			local c = p.petsCarousel["egg_" .. egg.Id]
			local pity = egg.Pity - (if state and state.pets then state.pets.hatches[egg.Id] or 0 else 0)
			c.Tier.Text = "EGG · " .. egg.Cost .. " SHARDS"
			c.PreviewWell.EggIcon.Visible = true
			local odds = {}
			for _, rarity in Config.Pets.RarityOrder do if egg.Odds[rarity] then table.insert(odds, Config.Pets.Rarities[rarity].Name .. " " .. egg.Odds[rarity] .. "%") end end
			c.Stats.Text = "COST: " .. egg.Cost .. " Core Shards\n\nGuaranteed " .. Config.Pets.Rarities[egg.PityFrom].Name .. "+ in " .. pity .. " hatches\n\n" .. table.concat(odds, " · ")
			c.Price.Text = "Core Shards earned in play"
			N.enable(c.Purchase, state ~= nil and busyId == nil and Price.canAfford(state, 0, egg.Cost), N.GREEN)
			c.Purchase.Text = if busyId == "egg_" .. egg.Id then "HATCHING..." elseif state and state.shards >= egg.Cost then "HATCH" else "SAVE SHARDS"
		end
		for _, def in Config.Pets.List do
			local entry, isEquipped = petEntry(def.Id), equipped(def.Id)
			local level = if entry then entry.level else 1
			local c = p.petsCarousel["pet_" .. def.Id]
			local rarity = Config.Pets.Rarities[def.Rarity]
			local pass = if def.Pass then Config.Monetization.Passes[def.Pass] else nil
			local onSale = pass ~= nil and pass.Id ~= 0
			c.Tier.Text, c.Tier.TextColor3 = string.upper(rarity.Name) .. " PET", rarity.Color
			c.PreviewWell.EggIcon.Visible = false
			if showPets and previews[def.Id] ~= level then Preview.pet(c.PreviewWell.Preview, def.Id, level); previews[def.Id] = level end
			local needed = Pets.xpToNext(level)
			local lines = { "LEVEL " .. level .. " / " .. Config.Pets.MaxLevel .. (if entry and needed then " · " .. Format.number(math.floor(entry.xp)) .. "/" .. Format.number(needed) .. " XP" else "") }
			for _, perk in Pets.perksOf(def, level) do
				local role = Config.Pets.Roles[perk.role]
				table.insert(lines, string.format('<font color="#%s">%s</font>: %s', rarity.Color:ToHex(), role.Name, string.format(role.Text, string.format("%g%%", math.floor(perk.value * 10000 + .5) / 100))))
			end
			c.Stats.Text = table.concat(lines, "\n\n")
			c.Price.Text = if entry then def.Blurb elseif pass then "R$ " .. (def.Robux or 0) .. " · fixed price" else "Hatch it from an earned-shard egg"
			N.enable(c.Purchase, state ~= nil and busyId == nil and (entry ~= nil or onSale), rarity.Color)
			c.Purchase.Text = if busyId == "pet_" .. def.Id then "PLEASE WAIT" elseif isEquipped then "PUT AWAY" elseif entry then "EQUIP" elseif pass then (if onSale then "GET FOR R$" .. (def.Robux or 0) else "NOT ON SALE YET") else "FROM EGGS"
		end
		for _, id in { "pickaxe", "backpack", "pets" } do p.Tabs[id .. "Tab"].BackgroundColor3 = if tab == id then (if id == "pickaxe" then N.ORANGE elseif id == "backpack" then N.CYAN else N.GREEN) else N.CARD end
		p.Previous.Visible, p.Next.Visible = tab == "pets", tab == "pets"
		p.Footer.Position, p.Footer.Size = UDim2.fromOffset(if tab == "pets" then 80 else 12, g.footerY), UDim2.fromOffset(g.panel.w - (if tab == "pets" then 160 else 24), 44)
		p.Previous.Position, p.Next.Position = UDim2.fromOffset(12, g.footerY), UDim2.fromOffset(g.panel.w - 68, g.footerY)
		p.Footer.Text = if notice ~= "" then notice elseif not state then "Loading your equipment..."
			elseif tab == "pets" then #state.pets.equipped .. "/" .. state.pets.slots .. " pets out. Rebirth cap 3; Extra Pet Slot +1."
			else "Player level " .. state.level .. (if state.xpNeeded > 0 then string.format(" (%d / %d XP)", math.floor(state.xp), state.xpNeeded) else " (max)")
		navRefs.badge.Visible = wantHighlight
	end
	refresh = update
	for _, kind in { "pickaxe", "backpack" } do
		local settings = settingsOf[kind]
		for _, stat in settings.Stats do
			for _, limit in { 1, 10 } do
				p[kind .. "Screen"].Rows[stat .. "Row"]["Buy" .. limit].Activated:Connect(function()
					if not state or busyId then return end
					local wanted = Gear.bulk(kind, state[kind .. "Tier"], stat, state[kind .. "Stats"][stat], state.cash, limit)
					if wanted < 1 then return end
					purchase(kind .. "_" .. stat, settings.Names[stat] .. " upgraded.", function()
						local any = false
						for i = 1, wanted do if not shop:Upgrade(kind, stat) then break end; any = true; if i < wanted then task.wait(.025) end end
						return any
					end)
				end)
			end
		end
		p[kind .. "Screen"].Rows.EvolveBanner.Evolve.Activated:Connect(function()
			if not state then return end
			local e = Gear.evolution(kind, state[kind .. "Tier"], state[kind .. "Stats"])
			if not e or not e.ready or state.level < Levels.evolveLevel(e.tier) or not Price.canAfford(state, e.cost, e.shards) then return end
			purchase(kind .. "_evolve", "Evolved.", function() return shop:Evolve(kind) end)
		end)
	end
	for _, egg in Config.Pets.Eggs do p.petsCarousel["egg_" .. egg.Id].Purchase.Activated:Connect(function()
		if state and Price.canAfford(state, 0, egg.Cost) then purchase("egg_" .. egg.Id, "", function() return pets:Hatch(egg.Id) end) end
	end) end
	for _, def in Config.Pets.List do p.petsCarousel["pet_" .. def.Id].Purchase.Activated:Connect(function()
		if busyId or not state then return end
		local entry = petEntry(def.Id)
		if not entry then
			local pass = if def.Pass then Config.Monetization.Passes[def.Pass] else nil
			if pass and pass.Id ~= 0 then MarketplaceService:PromptGamePassPurchase(player, pass.Id) end
		elseif equipped(def.Id) then purchase("pet_" .. def.Id, def.Name .. " put away.", function() return pets:Unequip(def.Id) end)
		else purchase("pet_" .. def.Id, def.Name .. " is out.", function() return pets:Equip(def.Id) end) end
	end) end
	local function move(direction: number)
		local list = p.petsCarousel
		local target = Vector2.new(math.clamp(list.CanvasPosition.X + direction * (geometry.cardWidth + geometry.gap), 0, math.max(0, list.AbsoluteCanvasSize.X - list.AbsoluteWindowSize.X)), list.CanvasPosition.Y)
		TweenService:Create(list, TweenInfo.new(.2), { CanvasPosition = target }):Play()
	end
	for _, id in { "pickaxe", "backpack", "pets" } do p.Tabs[id .. "Tab"].Activated:Connect(function() tab, notice = id, ""; p.petsCarousel.CanvasPosition = Vector2.zero; update() end) end
	p.Previous.Activated:Connect(function() if tab == "pets" then move(-1) end end)
	p.Next.Activated:Connect(function() if tab == "pets" then move(1) end end)
	p.Close.Activated:Connect(close); gui.Dimmer.Activated:Connect(close)
	nav.Activated:Connect(function() if player:GetAttribute("ShopOpen") then close() else self:Open() end end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if not player:GetAttribute("ShopOpen") or UserInputService:GetFocusedTextBox() then return end
		if input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB then close()
		elseif not processed and tab == "pets" and input.KeyCode == Enum.KeyCode.Left then move(-1)
		elseif not processed and tab == "pets" and input.KeyCode == Enum.KeyCode.Right then move(1) end
	end)
	shop.Open:Connect(function() self:Open() end)
	shop.Notice:Connect(function(message) notice = message; update() end)
	pets.Notice:Connect(function(message) notice = message; update() end)
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
