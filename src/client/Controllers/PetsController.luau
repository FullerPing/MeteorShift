--!strict
-- The Pets menu (PetsMenu ScreenGui, built by NativeMenus/Pets): MY PETS shows what you own with each pet's perks and lets you
-- equip or put away; PET INDEX lists every pet in the game, found or not. On a roomy window it is the owner's cartoon light
-- mockup on the Gear Shop's frame (EquipmentShopLayout.view); on small screens Shared.PetsLayout fits it with MenuFit.
-- Eggs hatch at the Hatchery's prompts. Ownership, slots and hatching stay on the server (PetService).
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local UserInputService = game:GetService("UserInputService")
local Knit = require(RS.Packages.Knit)
local Config = require(RS.Shared.Config)
local Format = require(RS.Shared.Format)
local Pets = require(RS.Shared.Pets)
local PetsLayout = require(RS.Shared.PetsLayout)
local ShopLayout = require(RS.Shared.EquipmentShopLayout)
local Palette = require(RS.Shared.MenuPalette)
local N = require(script.Parent.Parent.NativeUI)
local Theme = require(script.Parent.Parent.MenuTheme)
local Preview = require(script.Parent.Parent.NativePreview)
local ExactNavButton = require(script.Parent.Parent.ExactNavButton)
local PetsMenu = require(script.Parent.Parent.NativeMenus.Pets)

local player = Players.LocalPlayer
local Controller = Knit.CreateController({ Name = "PetsController" })
local wantOpen, wantTab = false, nil :: string?
local refresh: (() -> ())? = nil

-- Open the menu, optionally on a tab ("pets" or "index")
function Controller:Open(tab: string?)
	wantOpen, wantTab = true, tab
	player:SetAttribute("PetsOpen", true)
	if refresh then refresh() end
end

local function hex(color: Color3): string return color:ToHex() end
local WHITE = Color3.new(1, 1, 1)

function Controller:KnitStart()
	local petService = Knit.GetService("PetService")
	local petVisuals = Knit.GetController("PetVisualController")
	-- an older copy of the menu (no or an older PetsLayout mark): swap in the current panel
	local gui = N.getOrBuild("PetsMenu", PetsMenu.build, function(menu)
		if menu:GetAttribute("PetsLayout") == PetsMenu.LAYOUT then return end
		local fresh = PetsMenu.build()
		for _, name in { "Panel", "Dimmer" } do
			local old = menu:FindFirstChild(name)
			if old then old:Destroy() end
			fresh:WaitForChild(name).Parent = menu
		end
		fresh:Destroy()
		menu:SetAttribute("PetsLayout", PetsMenu.LAYOUT)
	end)
	gui.Enabled = true
	gui.DisplayOrder = 30
	local p: any = gui.Panel
	local nav = ExactNavButton.author(gui, "PetsButton", "Pets", Config.HudIcons.pets)
	local navRefs = ExactNavButton.bind(nav)

	local state: any = nil
	local tab, selected, notice = "pets", nil :: string?, ""
	local howOpen = false -- the "How bonuses work" text under the selected pet's perks
	local busyId: string? = nil
	local hud0 = N.hudLayout()
	local view = ShopLayout.view(hud0.viewport, hud0.inset)
	local geometry = PetsLayout.compute(view.viewport, view.inset, view.wide)
	local previews: { [Instance]: string } = {}
	local reserved = 0
	local wasOpen = false
	local update: () -> ()

	local function saved(): any return if state then state.pets else nil end
	local function owned(id: string): any local s = saved(); return s and s.owned[id] end
	local function equipped(id: string): boolean local s = saved(); return s ~= nil and table.find(s.equipped, id) ~= nil end
	local function slotCount(): number local s = saved(); return if s then s.slots else 1 end
	local function box(object: GuiObject, x: number, y: number, w: number, h: number)
		object.Position, object.Size = UDim2.fromOffset(x, y), UDim2.fromOffset(math.max(0, w), math.max(0, h))
	end
	local function rarityOf(id: string): any return Config.Pets.Rarities[(Pets.def(id) :: any).Rarity] end

	local function purchase(id: string, message: string, callback: () -> any)
		if busyId then return end
		busyId, notice = id, ""
		update()
		task.spawn(function()
			local ok, result = pcall(callback)
			busyId = nil
			if not ok then notice = "Couldn't complete that. Please try again." elseif result and message ~= "" then notice = message end
			update()
		end)
	end
	local function close() wantOpen = false; player:SetAttribute("PetsOpen", false); update() end

	-- A model preview is only rebuilt when the pet or its level changes
	local function showPreview(frame: ViewportFrame, id: string?, level: number)
		local key = if id then id .. ":" .. level else ""
		if previews[frame] == key then return end
		previews[frame] = key
		if id then Preview.pet(frame, id, level) else Preview.clear(frame) end
	end

	-- A well tinted by the pet's rarity: a pale wash of its colour fading to a deeper one, with a matching edge
	local function tint(well: Frame, color: Color3)
		Theme.gradient(well, color:Lerp(WHITE, 0.82), color:Lerp(WHITE, 0.5))
		Theme.stroke(well, color:Lerp(WHITE, 0.35), 2.5)
		local shadow = well:FindFirstChild("Shadow") :: Frame?
		if shadow then shadow.BackgroundColor3 = color:Lerp(WHITE, 0.3) end
	end

	-- an equipped pet: a lime outline and the EQUIPPED tab; the selection: a blue ring
	local function paintCard(card: any, id: string, level: number?, isEquipped: boolean, found: boolean, isSelected: boolean, live: boolean, wide: boolean)
		local rarity = rarityOf(id)
		Theme.stroke(card, if isEquipped then Palette.EQUIP_EDGE else Palette.NAVY, if isEquipped then 4 else 3)
		card.SelectRing.Visible = isSelected
		card.Equipped.Visible = isEquipped
		card.Equipped.Label.Text = if wide then "✓ EQUIPPED" else "✓"
		card.Equipped.Size = if wide then UDim2.fromOffset(104, 22) else UDim2.fromOffset(28, 22)
		card.Lock.Visible = not found
		tint(card.Well, if isEquipped then Palette.LIME_BOTTOM else rarity.Color)
		card.PetLabel.Text = if found then (Pets.def(id) :: any).Name else "???"
		card.Level.Text = if found and level then "Level " .. level else string.upper(rarity.Name)
		card.Level.TextColor3 = if found and level then Palette.SECOND else rarity.Color:Lerp(Palette.NAVY, 0.35)
		card.Level.TextSize = if wide then 14 else 12
		showPreview(card.Well.Preview, if found and live then id else nil, level or 1)
	end

	-- The long explanation behind "How bonuses work": what each perk does, where it tops out, and where to find a pet you lack
	local DIM, SOFT = hex(Palette.SECOND), hex(Palette.MUTED)
	local function perkText(def: any, level: number, found: boolean): string
		local rarity = Config.Pets.Rarities[def.Rarity]
		local strong = hex(rarity.Color:Lerp(Palette.NAVY, 0.35))
		local lines: { string } = {}
		if found then
			for _, row in PetsLayout.perkRows(def, level) do
				local atMax = row.now == row.max
				table.insert(lines, string.format('<font color="#%s"><b>%s %s</b></font>%s\n<font color="#%s">%s</font>', strong, row.name, row.now,
					if atMax then "  (max)" else "  → " .. row.max .. " at Lv " .. Config.Pets.MaxLevel, DIM, row.text))
			end
			table.insert(lines, '<font color="#' .. SOFT .. '"><i>' .. def.Blurb .. "</i></font>")
		else
			table.insert(lines, '<font color="#' .. SOFT .. '">Perks: ???</font>')
			table.insert(lines, '<font color="#' .. DIM .. '">' .. (if def.Pass then "A game pass pet: " .. Format.ROBUX .. " " .. (def.Robux or 0) .. ", a fixed price." else "Hatch it from an egg. Eggs that can drop it:") .. "</font>")
			for _, egg in PetsLayout.eggsFor(def) do
				table.insert(lines, string.format('<font color="#%s">• %s</font> (%s%%)', strong, egg.Name, tostring(egg.Odds[def.Rarity])))
			end
		end
		return table.concat(lines, "\n\n")
	end

	local function visibleIds(): { string }
		return if tab == "index" then PetsLayout.indexOrder() else PetsLayout.ownedOrder(saved())
	end

	update = function()
		local g = geometry
		local open = player:GetAttribute("PetsOpen") == true
		if open and not wasOpen then
			tab = wantTab or tab
			wantTab = nil
		end
		wasOpen = open
		p.Visible, gui.Dimmer.Visible = open, open
		nav.Visible = not open
		N.place(p, g.panel, view)

		-- the ribbon, Close and the shard chip
		local ribbon = p.Ribbon
		p.Wallet.Text = if state then Format.number(state.shards) else "..."
		if g.wide then
			ribbon.Position, ribbon.Size, ribbon.Rotation = UDim2.fromOffset(10, -24), UDim2.fromOffset(256, 66), -1.5
			p.Close.Position, p.Close.Size = UDim2.new(1, 8, 0, -14), UDim2.fromOffset(48, 50)
			box(p.Wallet, 533, 20, 165, 31)
		else
			local closeH = if g.compact then 40 else 44
			ribbon.Rotation = 0
			box(ribbon, 6, 4, if g.narrow then 170 else 200, g.headerH - 4)
			p.Close.Position, p.Close.Size = UDim2.new(1, -8, 0, 4 + math.floor((g.headerH - 4 - closeH) / 2)), UDim2.fromOffset(closeH, closeH)
			if g.narrow then box(p.Wallet, g.panel.w - 8 - closeH - 8 - 150, 10, 150, 30)
			else box(p.Wallet, g.panel.w - 8 - closeH - 12 - 180, math.floor((g.headerH - 32) / 2) + 2, 180, 32) end
		end
		local tabsW = math.min(g.panel.w - g.padding * 2, 440)
		box(p.Tabs, if g.wide then g.padding else (g.panel.w - tabsW) / 2, g.tabsY, tabsW, g.tabsH)
		for index, id in { "pets", "index" } do
			local button = p.Tabs[id .. "Tab"]
			button.Position = UDim2.new((index - 1) / 2, if index == 1 then 0 else 4, 0, 0)
			button.Size = UDim2.new(1 / 2, -4, 1, 0)
			button.TextSize = if g.wide then 18 else 16
			Theme.tab(button, tab == id)
		end
		local s = saved()
		local ownedIds = PetsLayout.ownedOrder(s)
		-- keep a valid selection for the tab you are on
		local ids = visibleIds()
		if not selected or (tab == "pets" and not owned(selected)) then selected = ids[1] end

		-- previews: only the visible tab keeps model viewports alive
		local wantReserved = if open then math.min(14, #ids + 1) else 0
		if wantReserved ~= reserved then petVisuals:ReserveShopPreviews(wantReserved); reserved = wantReserved end

		local petsScreen, indexScreen, detail = p.PetsScreen, p.IndexScreen, p.Detail
		petsScreen.Visible, indexScreen.Visible = tab == "pets", tab == "index"

		-- each screen spans the content area: the summary on top, the grid below it
		local list = g.list
		local liveGrid = if tab == "index" then indexScreen.List else petsScreen.List
		local liveScreen = if tab == "index" then indexScreen else petsScreen
		-- the mockup keeps the summary over the grid; smaller layouts run it across the whole panel
		local summaryW = if g.wide then list.w else g.panel.w - g.padding * 2
		box(liveScreen, g.padding, g.contentY, summaryW, g.contentH)
		local wide = g.cellW >= 130
		local slim = g.summaryH < 60
		local headingH = if slim then 0 else 32
		if tab == "pets" then
			local slots = slotCount()
			local totals = if s then Pets.bonuses(s) else {}
			local parts = {}
			local navyHex = hex(Palette.NAVY)
			for _, role in Config.Pets.RoleOrder do
				local value = (totals :: any)[role]
				if value and value > 0 then
					table.insert(parts, string.format('<font color="#%s">%s</font> %s', navyHex, Config.Pets.Roles[role].Name, PetsLayout.percent(value)))
				end
			end
			petsScreen.Heading.Visible = not slim
			box(petsScreen.Heading, 0, 2, summaryW - 140, 28)
			local pill = petsScreen.EquipPill
			pill.Label.Text = "Equipped " .. (if s then #s.equipped else 0) .. " / " .. slots
			local bar = petsScreen.BonusBar
			if slim then
				box(pill, 0, 6, 110, g.summaryH - 12)
				box(bar, 118, 2, summaryW - 118, g.summaryH - 4)
			else
				box(pill, summaryW - 126, 6, 126, 24)
				box(bar, 0, headingH + 8, summaryW, g.summaryH - headingH - 10)
			end
			bar.Label.Visible = summaryW >= 360
			local labelW = if bar.Label.Visible then 122 else 10
			bar.Bonuses.Position, bar.Bonuses.Size = UDim2.fromOffset(labelW, 0), UDim2.new(1, -labelW - 8, 1, 0)
			bar.Bonuses.TextSize = if wide then 16 else 14
			bar.Bonuses.Text = if #parts > 0 then table.concat(parts, "     ") else '<font color="#' .. hex(Palette.SECOND) .. '">Equip a pet to start a boost.</font>'
		else
			local found = PetsLayout.discovered(s)
			indexScreen.Heading.Visible = not slim
			box(indexScreen.Heading, 0, 2, summaryW - 160, 28)
			indexScreen.Progress.Text = "DISCOVERED " .. found .. " / " .. #Config.Pets.List
			box(indexScreen.Progress, if slim then 0 else summaryW - 200, if slim then 0 else 4, if slim then summaryW else 200, 24)
			box(indexScreen.ProgressBar, 0, if slim then 28 else headingH + 22, summaryW, 12)
			indexScreen.ProgressBar.Fill.Size = UDim2.fromScale(found / math.max(#Config.Pets.List, 1), 1)
		end
		box(liveGrid, list.x - g.padding, list.y - g.contentY, list.w, list.h)
		liveGrid.UIGridLayout.CellSize = UDim2.fromOffset(g.cellW, g.cellH)
		petsScreen.Empty.Visible = tab == "pets" and #ownedIds == 0
		box(petsScreen.Empty, list.x - g.padding, list.y - g.contentY + 10, list.w, 60)

		-- cards: MY PETS shows what you own, PET INDEX shows everything
		local order = {}
		for rank, id in ids do order[id] = rank end
		for _, grid in { petsScreen.List, indexScreen.List } do
			local live = grid == liveGrid
			for _, def in Config.Pets.List do
				local card = grid["pet_" .. def.Id]
				local entry = owned(def.Id)
				local show = if grid == petsScreen.List then entry ~= nil else true
				card.Visible = show
				card.LayoutOrder = order[def.Id] or 0
				if show then
					paintCard(card, def.Id, if entry then entry.level else nil, equipped(def.Id), entry ~= nil, live and selected == def.Id, live and open, wide)
				else
					showPreview(card.Well.Preview, nil, 1)
				end
			end
		end

		-- the detail column: the name banner, the rarity pill, preview, level, perks; the action under it
		do
			local d = g.detail
			box(detail, d.x, d.y, d.w, d.h)
			local bannerH = if g.wide then 39 else 36
			local bannerTop = if g.wide then -6 else 0
			box(detail.Banner, if g.wide then 19 else 8, bannerTop, d.w - (if g.wide then 38 else 16), bannerH)
			box(detail.PetName, (if g.wide then 19 else 8) + 8, bannerTop, d.w - (if g.wide then 38 else 16) - 16, bannerH - 7)
			local cardTop = bannerTop + math.floor(bannerH / 2)
			box(detail.Card, 0, cardTop, d.w, d.h - cardTop)
			local body = detail.Body
			local bodyTop = bannerTop + bannerH + 6
			local bodyW, bodyH = math.max(0, d.w - 16), math.max(0, d.h - bodyTop - 6)
			box(body, 8, bodyTop, bodyW, bodyH)
			local def = if selected then Pets.def(selected) else nil
			local entry = if selected then owned(selected) else nil
			local found = entry ~= nil
			for n = 1, 3 do body["Perk" .. n].Visible = false end
			for _, name in { "Rarity", "PreviewWell", "Level", "XpText", "XpBar", "HowButton", "PerkText" } do body[name].Visible = false end
			local action = p.Action
			box(action, g.action.x, g.action.y, g.action.w, g.action.h)
			action.Visible = def ~= nil
			detail.Banner.Visible, detail.PetName.Visible = def ~= nil, def ~= nil
			if def then
				local rarity = Config.Pets.Rarities[def.Rarity]
				local level = if entry then entry.level else 1
				local pass = if def.Pass then Config.Monetization.Passes[def.Pass] else nil
				local perkRows = if found then PetsLayout.perkRows(def, level) else {}
				local scrollbar = 6
				local innerW = bodyW - scrollbar
				detail.PetName.Text = string.upper(if found then def.Name else "???")
				-- the rarity pill: lilac for a premium pet, otherwise a wash of the rarity's colour
				local pill = body.Rarity
				pill.Visible = true
				pill.Label.Text = if def.Pass then "★ PREMIUM PET" else string.upper(rarity.Name)
				if def.Pass then
					pill.BackgroundColor3, pill.UIStroke.Color, pill.Label.TextColor3 = Palette.PREMIUM, Palette.PREMIUM_EDGE, Palette.PREMIUM_TEXT
				else
					pill.BackgroundColor3, pill.UIStroke.Color = rarity.Color:Lerp(WHITE, 0.82), rarity.Color:Lerp(WHITE, 0.3)
					pill.Label.TextColor3 = rarity.Color:Lerp(Palette.NAVY, 0.55)
				end
				local y = 0
				box(pill, (innerW - 150) / 2, y, 150, 23); y += 31

				-- the preview takes whatever height is left after the lines below it
				local below = 8 + 20 + 4 + 10 + 8 + #perkRows * 22 + (if found then 6 + 34 else 0)
				local side = math.clamp(math.min(innerW, bodyH - y - below), 64, 160)
				local wellW = math.min(innerW, math.floor(side * 1.65))
				body.PreviewWell.Visible = true
				box(body.PreviewWell, (innerW - wellW) / 2, y, wellW, side); y += side + 8
				tint(body.PreviewWell, if def.Pass then Palette.BLUE_TOP else rarity.Color)
				showPreview(body.PreviewWell.Preview, if found and open then def.Id else nil, level)

				body.Level.Visible, body.XpBar.Visible, body.XpText.Visible = found, found, found
				if found then
					local needed = Pets.xpToNext(entry.level)
					body.Level.Text = "Level " .. level .. " / " .. Config.Pets.MaxLevel
					body.XpBar.Fill.Size = UDim2.fromScale(if needed then math.clamp(entry.xp / needed, 0, 1) else 1, 1)
					body.XpText.Text = if needed then Format.number(math.floor(entry.xp)) .. " / " .. Format.number(needed) .. " XP" else "MAX LEVEL"
					box(body.Level, 0, y, innerW / 2, 20)
					box(body.XpText, innerW / 2, y, innerW / 2, 20); y += 24
					box(body.XpBar, 1, y, innerW - 2, 10); y += 18
					for n, row in perkRows do
						local perk = body["Perk" .. n]
						perk.Visible = true
						perk.Role.Text, perk.Value.Text = row.name, row.now
						box(perk, 0, y, innerW, 22); y += 22
					end
					y += 6
					body.HowButton.Visible = true
					body.HowButton.Text = if howOpen then "How bonuses work ▲" else "How bonuses work ▼"
					box(body.HowButton, 0, y, innerW, 34); y += 40
				end
				-- an unfound pet always shows where to get it; a found one shows the long text on request
				body.PerkText.Visible = not found or howOpen
				body.PerkText.Text = perkText(def, level, found)
				body.PerkText.Position, body.PerkText.Size = UDim2.fromOffset(0, y), UDim2.fromOffset(innerW, 0)

				-- the action: lime EQUIP for a pet in the bag, red PUT AWAY for one that is out
				local onSale = pass ~= nil and pass.Id ~= 0
				if found then
					local isOut = equipped(def.Id)
					local free = s ~= nil and #s.equipped < slotCount()
					Theme.state(action, busyId == nil and (isOut or free), if isOut then "red" else "lime")
					action.Text = if busyId == "pet_" .. def.Id then "PLEASE WAIT" elseif isOut then "PUT AWAY" elseif free then "EQUIP" else "ALL " .. slotCount() .. " SLOTS IN USE"
				elseif pass then
					Theme.state(action, busyId == nil and onSale, "gold")
					action.Text = if onSale then "GET FOR " .. Format.ROBUX .. " " .. (def.Robux or 0) else "NOT ON SALE YET"
				else
					Theme.state(action, false, "gold")
					action.Text = "HATCH AT THE HATCHERY"
				end
				action.TextSize = if g.wide then 20 else 17
			else
				body.PerkText.Visible = true
				body.PerkText.Text = '<font color="#' .. hex(Palette.SECOND) .. '">Pick a pet to see what it does.</font>'
				body.PerkText.Position, body.PerkText.Size = UDim2.fromOffset(0, 0), UDim2.fromOffset(bodyW - 8, 0)
			end
		end

		-- under the grid: the slots line (roomy layouts) and the hint strip, which also carries notices
		p.MoreSlots.Visible = g.more.w > 0 and tab == "pets"
		box(p.MoreSlots, g.more.x, g.more.y, g.more.w, g.more.h)
		local hint = p.Hint
		hint.Visible = g.footerH > 0
		box(hint, g.padding, g.footerY, if g.wide then g.list.w else g.panel.w - g.padding * 2, g.footerH)
		hint.Footer.Text = if notice ~= "" then notice elseif not s then "Loading your pets..."
			elseif tab == "index" then "Hatch eggs at the Hatchery with Core Shards. Duplicates level up your pet."
			elseif g.wide then "Pets gain XP while you mine!"
			else "Pets gain XP while you mine! More slots: Rebirths · Pet Bond · Extra Pet Slot"
		local free = s ~= nil and #s.equipped < slotCount()
		local spare = false
		if s then for id in s.owned do if not equipped(id) then spare = true end end end
		navRefs.badge.Visible = free and spare
	end
	refresh = update

	-- clicks
	for _, id in { "pets", "index" } do
		p.Tabs[id .. "Tab"].Activated:Connect(function() tab, notice = id, ""; update() end)
	end
	for _, grid in { p.PetsScreen.List, p.IndexScreen.List } do
		for _, def in Config.Pets.List do
			grid["pet_" .. def.Id].Select.Activated:Connect(function() selected, notice = def.Id, ""; update() end)
		end
	end
	p.Detail.Body.HowButton.Activated:Connect(function() howOpen = not howOpen; update() end)
	p.Action.Activated:Connect(function()
		if busyId or not state or not selected then return end
		local def = Pets.def(selected)
		if not def then return end
		if not owned(selected) then
			local pass = if def.Pass then Config.Monetization.Passes[def.Pass] else nil
			if pass and pass.Id ~= 0 then MarketplaceService:PromptGamePassPurchase(player, pass.Id) end
		elseif equipped(selected) then
			purchase("pet_" .. selected, def.Name .. " put away.", function() return petService:Unequip(def.Id) end)
		else
			purchase("pet_" .. selected, def.Name .. " is out.", function() return petService:Equip(def.Id) end)
		end
	end)
	p.Close.Activated:Connect(close)
	gui.Dimmer.Activated:Connect(close)
	nav.Activated:Connect(function() if player:GetAttribute("PetsOpen") then close() else self:Open() end end)
	UserInputService.InputBegan:Connect(function(input)
		if player:GetAttribute("PetsOpen") ~= true or UserInputService:GetFocusedTextBox() then return end
		if input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB then close() end
	end)
	petService.Notice:Connect(function(message) notice = message; update() end)
	petService.Hatched:Connect(function(_eggId: string, petId: string) selected = petId; update() end)
	player:GetAttributeChangedSignal("PetsOpen"):Connect(update)
	Knit.GetService("PlayerStateService").State:Observe(function(snapshot) state = snapshot; update() end)
	N.onLayoutChanged(function(hud)
		view = ShopLayout.view(hud.viewport, hud.inset)
		geometry = PetsLayout.compute(view.viewport, view.inset, view.wide)
		ExactNavButton.layout(nav, hud, "PETS")
		update()
	end)
	player:SetAttribute("PetsOpen", wantOpen)
end

return Controller
