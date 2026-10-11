--!strict
-- The Pets menu (PetsMenu ScreenGui, built by NativeMenus/Pets when the place has no authored copy): PETS shows what
-- you own with each pet's perks and lets you equip or put away; INDEX lists every pet in the game, found or not.
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
local N = require(script.Parent.Parent.NativeUI)
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

function Controller:KnitStart()
	local petService = Knit.GetService("PetService")
	local petVisuals = Knit.GetController("PetVisualController")
	-- an authored copy from before the redesign has no PetsLayout mark: swap in the current panel
	local gui = N.getOrBuild("PetsMenu", PetsMenu.build, function(menu)
		if menu:GetAttribute("PetsLayout") == PetsMenu.LAYOUT then return end
		local fresh = PetsMenu.build()
		menu:WaitForChild("Panel"):Destroy()
		fresh:WaitForChild("Panel").Parent = menu
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
	local geometry = PetsLayout.compute(N.hudLayout().viewport, N.hudLayout().inset)
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

	-- lime for the pets that are out, a brighter blue ring for the selection, the rarity as a small accent
	local EQUIPPED_LIME = Color3.fromRGB(150, 255, 40)
	local function paintCard(card: Frame, id: string, level: number?, isEquipped: boolean, found: boolean, isSelected: boolean, live: boolean, wide: boolean)
		local rarity = rarityOf(id)
		local stroke = card:FindFirstChildOfClass("UIStroke")
		if stroke then stroke.Color, stroke.Thickness = if isEquipped then EQUIPPED_LIME else N.OUTLINE, if isEquipped then 4 else 3 end
		card.SelectRing.Visible = isSelected
		card.Equipped.Visible = isEquipped
		card.Equipped.Text = if wide then "✓ EQUIPPED" else "✓"
		card.Equipped.Size = if wide then UDim2.fromOffset(88, 20) else UDim2.fromOffset(24, 20)
		card.Lock.Visible = not found
		local well = card.Well
		well.BackgroundColor3 = if found then Color3.fromRGB(43, 44, 49) else Color3.fromRGB(20, 22, 28)
		card.SkinRarity.BackgroundColor3 = rarity.Color
		card.PetLabel.Text = if found then (Pets.def(id) :: any).Name else "???"
		card.PetLabel.TextSize = if wide then 16 else 14
		card.Level.Text = if found and level then "Lv. " .. level else string.upper(rarity.Name)
		card.Level.TextColor3 = if found and level then N.WHITE else rarity.Color
		showPreview(well.Preview, if found and live then id else nil, level or 1)
	end

	-- The long explanation behind "How bonuses work": what each perk does, where it tops out, and where to find a pet you lack
	local function perkText(def: any, level: number, found: boolean): string
		local rarity = Config.Pets.Rarities[def.Rarity]
		local lines: { string } = {}
		if found then
			for _, row in PetsLayout.perkRows(def, level) do
				local atMax = row.now == row.max
				table.insert(lines, string.format('<font color="#%s"><b>%s %s</b></font>%s\n<font color="#B9C6D2">%s</font>', hex(rarity.Color), row.name, row.now,
					if atMax then "  (max)" else "  → " .. row.max .. " at Lv " .. Config.Pets.MaxLevel, row.text))
			end
			table.insert(lines, '<font color="#8FA0B2"><i>' .. def.Blurb .. "</i></font>")
		else
			table.insert(lines, '<font color="#8FA0B2">Perks: ???</font>')
			table.insert(lines, '<font color="#B9C6D2">' .. (if def.Pass then "A game pass pet: R$ " .. (def.Robux or 0) .. ", a fixed price." else "Hatch it from an egg. Eggs that can drop it:") .. "</font>")
			for _, egg in PetsLayout.eggsFor(def) do
				table.insert(lines, string.format('<font color="#%s">• %s</font> (%s%%)', hex(rarity.Color), egg.Name, tostring(egg.Odds[def.Rarity])))
			end
		end
		return table.concat(lines, "\n\n")
	end

	local function visibleIds(): { string }
		return if tab == "index" then PetsLayout.indexOrder() else PetsLayout.ownedOrder(saved())
	end

	local footerSize: number? = nil
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
		p.AnchorPoint = Vector2.zero
		box(p, g.panel.x, g.panel.y, g.panel.w, g.panel.h)
		p.Title.Size = UDim2.new(1, -330, 0, 44)
		p.Wallet.Position, p.Wallet.Size = if g.narrow then UDim2.fromOffset(12, 50) elseif g.compact then UDim2.new(1, -290, 0, 4) else UDim2.new(1, -290, 0, 12),
			UDim2.fromOffset(230, if g.compact then 26 else 30)
		if g.narrow then p.Title.Size = UDim2.new(1, -80, 0, 44) end
		p.Wallet.Text = if state then Format.number(state.shards) .. " Core Shards" else "Loading..."
		-- two centred tabs rather than a full-width bar
		local tabsW = math.min(g.panel.w - g.padding * 2, 440)
		box(p.Tabs, (g.panel.w - tabsW) / 2, g.tabsY, tabsW, g.tabsH)
		for _, id in { "pets", "index" } do
			p.Tabs[id .. "Tab"].BackgroundColor3 = if tab == id then (if id == "pets" then N.GREEN else N.CYAN) else N.CARD
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

		-- each screen spans the content area: the summary on top, the grid below it beside (or above) the detail
		local list = g.list
		local liveGrid = if tab == "index" then indexScreen.List else petsScreen.List
		local liveScreen = if tab == "index" then indexScreen else petsScreen
		box(liveScreen, g.padding, g.contentY, g.panel.w - g.padding * 2, g.contentH)
		local wide = g.cellW >= 130
		local summaryW = g.panel.w - g.padding * 2
		if tab == "pets" then
			local slots = slotCount()
			local slim = g.summaryH < 60
			local totals = if s then Pets.bonuses(s) else {}
			local parts = {}
			for _, role in Config.Pets.RoleOrder do
				local value = (totals :: any)[role]
				if value and value > 0 then table.insert(parts, Config.Pets.Roles[role].Name .. " " .. PetsLayout.percent(value)) end
			end
			local label = p.PetsScreen.Slots.Title
			label.Text = "Equipped: " .. (if s then #s.equipped else 0) .. " / " .. slots
			label.TextSize = if slim then 14 else 16
			local labelW = if slim then 108 else summaryW
			box(p.PetsScreen.Slots, 0, 0, labelW, if slim then g.summaryH else 22)
			local bar = p.PetsScreen.BonusBar
			if slim then box(bar, labelW + 6, 2, summaryW - labelW - 6, g.summaryH - 4) else box(bar, 0, 26, summaryW, g.summaryH - 26) end
			p.PetsScreen.BonusBar.Bonuses.Text = if #parts > 0 then (if slim then "" else '<font color="#8BF0C3"><b>ACTIVE BONUSES</b></font>   ') .. table.concat(parts, "  ·  ")
				else "No bonuses yet. Equip a pet to start."
		else
			p.IndexScreen.Progress.Text = "DISCOVERED " .. PetsLayout.discovered(s) .. "/" .. #Config.Pets.List
			p.IndexScreen.ProgressBar.Fill.Size = UDim2.fromScale(PetsLayout.discovered(s) / math.max(#Config.Pets.List, 1), 1)
			box(p.IndexScreen.Progress, 0, 0, summaryW, 22)
			box(p.IndexScreen.ProgressBar, 0, 28, summaryW, 12)
		end
		box(liveGrid, list.x - g.padding, list.y - g.contentY, list.w, list.h)
		liveGrid.UIGridLayout.CellSize = UDim2.fromOffset(g.cellW, g.cellH)
		p.PetsScreen.Empty.Visible = tab == "pets" and #ownedIds == 0
		box(p.PetsScreen.Empty, list.x - g.padding, list.y - g.contentY + 10, list.w, 60)

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

		-- the detail panel: name, rarity, preview, level, perks and the action. The body scrolls when it does not fit.
		do
			box(detail, g.detail.x, g.detail.y, g.detail.w, g.detail.h)
			local body = detail.Body
			local def = if selected then Pets.def(selected) else nil
			local entry = if selected then owned(selected) else nil
			local found = entry ~= nil
			local bodyW, bodyH = math.max(0, g.detail.w - 20), math.max(0, g.detail.h - 64)
			box(body, 10, 8, g.detail.w - 20, bodyH)
			for i = 1, 3 do body["Perk" .. i].Visible = false end
			for _, name in { "PetName", "Rarity", "PreviewWell", "Level", "XpText", "XpBar", "HowButton", "PerkText" } do body[name].Visible = false end
			local action = detail.Action
			box(action, 10, g.detail.h - 52, g.detail.w - 20, 44)
			action.Visible = def ~= nil
			if def then
				local rarity = Config.Pets.Rarities[def.Rarity]
				local level = if entry then entry.level else 1
				local pass = if def.Pass then Config.Monetization.Passes[def.Pass] else nil
				local perkRows = if found then PetsLayout.perkRows(def, level) else {}
				local scrollbar = 8
				local y = 0
				for _, name in { "PetName", "Rarity" } do body[name].Visible = true end
				box(body.PetName, 0, y, bodyW - scrollbar, 28); y += 28
				box(body.Rarity, 0, y, bodyW - scrollbar, 18); y += 24
				body.PetName.Text = if found then def.Name else "???"
				body.Rarity.Text = (if def.Pass then "PREMIUM PET" else string.upper(rarity.Name)) .. (if found and equipped(def.Id) then "  ·  EQUIPPED" else "")
				body.Rarity.TextColor3 = rarity.Color

				-- the preview takes whatever height is left after the lines below it
				local below = 8 + 18 + 4 + 12 + 8 + #perkRows * 26 + (if found then 6 + 30 else 0)
				local side = math.clamp(math.min(bodyW - scrollbar, bodyH - y - below), 64, 150)
				body.PreviewWell.Visible = true
				box(body.PreviewWell, (bodyW - scrollbar - side) / 2, y, side, side); y += side + 8
				showPreview(body.PreviewWell.Preview, if found and open then def.Id else nil, level)

				body.Level.Visible, body.XpBar.Visible, body.XpText.Visible = found, found, found
				if found then
					local needed = Pets.xpToNext(entry.level)
					body.Level.Text = "Level " .. level .. " / " .. Config.Pets.MaxLevel
					body.XpBar.Fill.Size = UDim2.fromScale(if needed then math.clamp(entry.xp / needed, 0, 1) else 1, 1)
					body.XpText.Text = if needed then Format.number(math.floor(entry.xp)) .. " / " .. Format.number(needed) .. " XP" else "MAX LEVEL"
					box(body.Level, 0, y, (bodyW - scrollbar) / 2, 18)
					box(body.XpText, (bodyW - scrollbar) / 2, y, (bodyW - scrollbar) / 2, 18); y += 22
					box(body.XpBar, 0, y, bodyW - scrollbar, 12); y += 20
					for index, row in perkRows do
						local perk = body["Perk" .. index]
						perk.Visible = true
						perk.Role.Text, perk.Value.Text = row.name, row.now
						perk.Value.TextColor3 = rarity.Color
						box(perk, 0, y, bodyW - scrollbar, 24); y += 26
					end
					y += 6
					body.HowButton.Visible = true
					body.HowButton.Text = if howOpen then "How bonuses work ▲" else "How bonuses work ▼"
					box(body.HowButton, 0, y, bodyW - scrollbar, 30); y += 36
				end
				-- an unfound pet always shows where to get it; a found one shows the long text on request
				body.PerkText.Visible = not found or howOpen
				body.PerkText.Text = perkText(def, level, found)
				body.PerkText.Position, body.PerkText.Size = UDim2.fromOffset(0, y), UDim2.fromOffset(bodyW - scrollbar, 0)

				-- the action: a green EQUIP for a pet that is in the bag, PUT AWAY for one that is out
				local onSale = pass ~= nil and pass.Id ~= 0
				if found then
					local isOut = equipped(def.Id)
					local free = s ~= nil and #s.equipped < slotCount()
					N.enable(action, busyId == nil and (isOut or free), if isOut then N.RED else N.GREEN)
					action.Text = if busyId == "pet_" .. def.Id then "PLEASE WAIT" elseif isOut then "PUT AWAY" elseif free then "EQUIP" else "ALL " .. slotCount() .. " SLOTS IN USE"
				elseif pass then
					N.enable(action, busyId == nil and onSale, rarity.Color)
					action.Text = if onSale then "GET FOR R$" .. (def.Robux or 0) else "NOT ON SALE YET"
				else
					N.enable(action, false, N.ORANGE)
					action.Text = "HATCH AT THE HATCHERY"
				end
			else
				body.PerkText.Visible = true
				body.PerkText.Text = '<font color="#B9C6D2">Pick a pet to see what it does.</font>'
				body.PerkText.Position, body.PerkText.Size = UDim2.fromOffset(0, 0), UDim2.fromOffset(bodyW - 8, 0)
			end
		end

		footerSize = footerSize or p.Footer.TextSize
		if g.compact then
			-- phones in landscape: a short line under the wallet in the header
			p.Footer.Position, p.Footer.Size = UDim2.new(1, -290, 0, 30), UDim2.fromOffset(230, 20)
			p.Footer.TextSize, p.Footer.TextTruncate = 14, Enum.TextTruncate.AtEnd
		else
			box(p.Footer, g.padding, g.footerY, g.panel.w - g.padding * 2, g.footerH)
			p.Footer.TextSize = footerSize
		end
		p.Footer.Text = if notice ~= "" then notice elseif not s then "Loading your pets..."
			elseif g.compact then (if tab == "index" then "Hatch eggs at the Hatchery" else #s.equipped .. "/" .. slotCount() .. " pets out · they level as you mine")
			elseif tab == "index" then "Hatch eggs at the Hatchery in town with Core Shards. Duplicates level up the pet you already have."
			else "Pets gain XP while you mine.\nMore slots: Rebirths · Pet Bond · Extra Pet Slot"
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
	p.Detail.Action.Activated:Connect(function()
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
		geometry = PetsLayout.compute(hud.viewport, hud.inset)
		ExactNavButton.layout(nav, hud, "PETS")
		update()
	end)
	player:SetAttribute("PetsOpen", wantOpen)
end

return Controller
