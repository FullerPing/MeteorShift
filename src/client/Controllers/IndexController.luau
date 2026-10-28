--!strict
-- Bind the editable StarterGui.MineralIndex prefab. IndexService owns mineral
-- rolls and collection state; this controller only updates native controls.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local HudLayout = require(ReplicatedStorage.Shared.HudLayout)
local IndexLayout = require(ReplicatedStorage.Shared.IndexLayout)
local MineralIndex = require(ReplicatedStorage.Shared.MineralIndex)
local NativeUI = require(script.Parent.Parent.NativeUI)
local ExactNavButton = require(script.Parent.Parent.ExactNavButton)
local MenuTheme = require(script.Parent.Parent.MenuTheme)
local IndexMenu = require(script.Parent.Parent.NativeMenus.Index)
local Palette = require(ReplicatedStorage.Shared.MenuPalette)

local player = Players.LocalPlayer
local Pages = Config.Index.Pages
local PageOrder = Config.Index.PageOrder
local IndexController = Knit.CreateController({ Name = "IndexController" })

local function child(parent: Instance, name: string, className: string): any
	local object = parent:WaitForChild(name)
	assert(object:IsA(className), parent:GetFullName() .. "." .. name .. " must be a " .. className)
	return object
end

local function rect(object: GuiObject, box: IndexLayout.Rect)
	object.Position = UDim2.fromOffset(box.x, box.y)
	object.Size = UDim2.fromOffset(box.w, box.h)
end

local function tier(pageId: string): number
	local meteor = Config.Meteor.Types[pageId]
	return if meteor then meteor.RequiredTier else 1
end

local function percent(fraction: number): string
	return "+" .. Format.number(math.floor(fraction * 100 + 0.5)) .. "%"
end

function IndexController:KnitStart()
	local IndexService = Knit.GetService("IndexService")
	local PlayerStateService = Knit.GetService("PlayerStateService")
	local HUDController = Knit.GetController("HUDController")
	local gui = NativeUI.getFresh("MineralIndex", IndexMenu.build, IndexMenu.LAYOUT)
	local nav: TextButton = child(gui, "IndexButton", "TextButton")
	local navRefs = ExactNavButton.bind(nav)
	local badge, tooltip = navRefs.badge, navRefs.tooltip
	local dimmer: TextButton = child(gui, "Dimmer", "TextButton")
	local panel: Frame = child(gui, "Panel", "Frame")
	local close: TextButton = child(panel, "Close", "TextButton")
	local chip: TextLabel = child(panel, "Bonus", "TextLabel")
	local tabs: Frame = child(panel, "Tabs", "Frame")
	local tabList: UIListLayout = child(tabs, "List", "UIListLayout")
	local side: ScrollingFrame = child(panel, "Side", "ScrollingFrame")
	local pageCard: Frame = child(side, "PageCard", "Frame")
	local count: Frame = child(pageCard, "Count", "Frame")
	local sideControls = {
		name = child(pageCard, "PageName", "TextLabel"), found = child(count, "FoundCount", "TextLabel"),
		fill = child(child(pageCard, "Progress", "Frame"), "Fill", "Frame"), caption = child(pageCard, "RewardCaption", "TextLabel"),
		reward = child(pageCard, "Reward", "TextLabel"), title = child(pageCard, "RewardTitle", "TextLabel"),
		drops = child(pageCard, "Drops", "TextLabel"), best = child(child(side, "TitleCard", "Frame"), "BestTitle", "TextLabel"),
	}
	local repeatTemplate: TextLabel = child(gui, "RepeatToastTemplate", "TextLabel")
	local pageControls: { [string]: any } = {}
	local tabButtons: { [string]: TextButton } = {}
	local open, fresh, hovering = false, false, false
	local selectedPage = PageOrder[1]
	local index: MineralIndex.PlayerIndex = {}
	local layout = NativeUI.hudLayout()

	for _, pageId in PageOrder do
		local page: ScrollingFrame = child(panel, pageId .. "Page", "ScrollingFrame")
		local cards: Frame = child(page, "Cards", "Frame")
		local minerals: { [string]: any } = {}
		for _, mineral in Pages[pageId].Minerals do
			local card: Frame = child(cards, mineral.Id, "Frame")
			local gem: Frame = child(child(card, "Showcase", "Frame"), "Gem", "Frame")
			local diamond: Frame = child(gem, "Diamond", "Frame")
			minerals[mineral.Id] = {
				card = card, name = child(card, "MineralName", "TextLabel"), found = child(card, "Found", "TextLabel"),
				edge = child(gem, "Edge", "Frame"), diamond = diamond,
				shine = child(diamond, "Shine", "Frame"), unknown = child(gem, "Unknown", "TextLabel"),
			}
		end
		pageControls[pageId] = {
			page = page, cards = cards, grid = child(cards, "Grid", "UIGridLayout"), footer = child(page, "Footer", "TextLabel"), minerals = minerals,
		}
		tabButtons[pageId] = child(tabs, pageId .. "Tab", "TextButton")
	end

	local function refreshButton()
		nav.Visible = not open and player:GetAttribute("ShopOpen") ~= true and player:GetAttribute("TutorialCardInColumn") ~= true
		badge.Visible = fresh
		tooltip.Visible = hovering and not layout.touch and nav.Visible
	end

	local function refreshIndex()
		local bonus = MineralIndex.cashBonus(index) - 1
		local titles = MineralIndex.titles(index)
		local best = titles[#titles]
		chip.Text = if bonus > 0 then percent(bonus) .. " bar sales" else "No bonus yet"
		sideControls.best.Text = best or "None yet"
		sideControls.best.TextColor3 = if best then Palette.BLUE_BOTTOM else Palette.SECOND
		for _, pageId in PageOrder do
			local page = Pages[pageId]
			local controls = pageControls[pageId]
			local total, found = #page.Minerals, MineralIndex.found(index, pageId)
			local complete = found >= total
			controls.page.Visible = selectedPage == pageId
			local tab = tabButtons[pageId]
			tab.Text = string.upper(page.Name) .. " " .. Format.number(found) .. "/" .. Format.number(total)
			MenuTheme.tab(tab, selectedPage == pageId)
			if selectedPage == pageId then
				-- the side column follows the selected page
				local meteor = Config.Meteor.Types[pageId]
				local tier = if meteor then meteor.RequiredTier else 1
				sideControls.name.Text = string.upper(page.Name) .. " PAGE"
				sideControls.found.Text = Format.number(found) .. " / " .. Format.number(total)
				sideControls.fill.Size = UDim2.fromScale(found / math.max(total, 1), 1)
				sideControls.fill.BackgroundColor3 = if complete then Palette.LIME_BOTTOM else Palette.BAR_FILL
				sideControls.caption.Text = if complete then "PAGE COMPLETE! YOU EARNED" else "COMPLETE IT FOR"
				sideControls.reward.Text = percent(page.CashBonus) .. " bar sales"
				sideControls.title.Text = string.format("and the title <font color=\"#%s\">%s</font>", Palette.GOLD_TEXT:ToHex(), page.Title)
				sideControls.drops.Text = if tier <= 1 then "Drops for every pickaxe on " .. page.Name .. " meteors."
					else "Drops only for Tier " .. tier .. "+ pickaxes on " .. page.Name .. " meteors."
			end
			for _, mineral in page.Minerals do
				local card = controls.minerals[mineral.Id]
				local count = index[mineral.Id] or 0
				local known = count > 0
				card.name.Text = if known then mineral.Name else "???"
				-- names in the mineral's colour, darkened toward navy so they read on the white card
				card.name.TextColor3 = if known then mineral.Color:Lerp(Palette.NAVY, 0.45) else Palette.SECOND
				card.found.Text = if known then "Found ×" .. Format.number(count)
					elseif tier(pageId) > 1 then "Not found yet. Drops for Tier " .. tier(pageId) .. "+ pickaxes."
					else "Not found yet"
				card.found.TextColor3 = if known then Palette.MET else Palette.SECOND
				-- an unknown mineral's card is greyed
				MenuTheme.gradient(card.card, if known then Palette.WHITE else Palette.OFF_TOP, if known then Palette.DETAIL_BOTTOM else Palette.OFF_BOTTOM)
				card.edge.BackgroundColor3 = if known then mineral.Color:Lerp(Palette.NAVY, 0.5) else Palette.NAVY
				card.diamond.BackgroundColor3 = if known then mineral.Color else Palette.GREY_BOTTOM
				card.shine.BackgroundTransparency = if known then 0.45 else 1
				card.unknown.Visible = not known
			end
		end
	end

	local function setOpen(value: boolean)
		open = value
		panel.Visible, dimmer.Visible = value, value
		player:SetAttribute("IndexOpen", value)
		if value then fresh = false; refreshIndex() end -- a closed Index skips State flushes (below)
		refreshButton()
	end

	local function updateLayout(nextLayout: HudLayout.Layout)
		layout = nextLayout
		local view = NativeUI.menuView(layout)
		local geometry = IndexLayout.compute(view.viewport, view.inset)
		NativeUI.place(panel, geometry.panel, view)
		rect(close, geometry.close)
		rect(tabs, geometry.tabs)
		rect(chip, geometry.chip)
		chip.Visible = geometry.chip.w > 0
		rect(side, geometry.side)
		side.Visible = geometry.side.w > 0
		tabList.Padding = UDim.new(0, geometry.tabGap)
		ExactNavButton.layout(nav, layout, "INDEX")
		for _, pageId in PageOrder do
			local controls = pageControls[pageId]
			local total = #Pages[pageId].Minerals
			local cardsW = geometry.grid.w - IndexLayout.Scrollbar
			tabButtons[pageId].Size = UDim2.fromOffset(geometry.tabWidth, geometry.tabs.h)
			rect(controls.page, geometry.grid)
			controls.page.CanvasSize = UDim2.fromOffset(0, IndexLayout.canvasHeight(geometry, total))
			controls.cards.Size = UDim2.fromOffset(cardsW, IndexLayout.gridHeight(geometry, total))
			controls.grid.FillDirectionMaxCells = geometry.columns
			controls.grid.CellSize = UDim2.fromOffset(geometry.cardWidth, geometry.cardHeight)
			controls.grid.CellPadding = UDim2.fromOffset(geometry.gap, geometry.gap)
			for _, mineral in Pages[pageId].Minerals do
				controls.minerals[mineral.Id].card.Size = UDim2.fromOffset(geometry.cardWidth, geometry.cardHeight)
			end
			controls.footer.Visible = false -- no small print under the grid
			controls.footer.Position = UDim2.fromOffset(4, 12 + IndexLayout.gridHeight(geometry, total))
			controls.footer.Size = UDim2.fromOffset(cardsW, 48)
		end
		refreshButton()
	end

	for _, pageId in PageOrder do
		tabButtons[pageId].Activated:Connect(function()
			selectedPage = pageId
			refreshIndex()
		end)
	end
	nav.Activated:Connect(function() setOpen(true) end)
	close.Activated:Connect(function() setOpen(false) end)
	dimmer.Activated:Connect(function() setOpen(false) end)
	local function hover(value: boolean) hovering = value; refreshButton() end
	nav.MouseEnter:Connect(function() hover(true) end)
	nav.MouseLeave:Connect(function() hover(false) end)
	nav.SelectionGained:Connect(function() hover(true) end)
	nav.SelectionLost:Connect(function() hover(false) end)
	for _, flag in { "ShopOpen", "TutorialCardInColumn" } do
		player:GetAttributeChangedSignal(flag):Connect(refreshButton)
	end
	UserInputService.InputBegan:Connect(function(input)
		if open and (input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB) then setOpen(false) end
	end)
	self._layoutCleanup = NativeUI.onLayoutChanged(updateLayout)
	gui.Enabled = true -- The same ScreenGui also owns the closed-menu INDEX button.
	setOpen(false)
	refreshIndex()
	PlayerStateService.State:Observe(function(value)
		index = if value and value.index then value.index else {}
		if open then refreshIndex() end
	end)

	local function floatUp(text: string, color: Color3)
		local scale, box = layout.scale, layout.buttons.INDEX
		local label = repeatTemplate:Clone()
		label.Name, label.Visible = "RepeatToast", true
		label.Position = if layout.touch then UDim2.fromOffset(box.x + box.w, box.y + box.h + 18)
			else UDim2.fromOffset(box.x - 8, box.y + box.h / 2)
		label.Text, label.TextColor3, label.TextSize = text, color, 24 * scale
		label.Parent = gui
		TweenService:Create(label, TweenInfo.new(1.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = label.Position - UDim2.fromOffset(0, 40 * scale), TextTransparency = 1, TextStrokeTransparency = 1,
		}):Play()
		task.delay(1.5, function() label:Destroy() end)
	end
	IndexService.Discovered:Connect(function(mineralId: string, _count: number, isNew: boolean)
		local mineral, page = MineralIndex.find(mineralId)
		if not mineral or not page then return end
		if isNew then
			HUDController:Toast("New mineral: " .. mineral.Name .. "!", mineral.Color, mineral.Name)
			if not open then
				fresh, selectedPage = true, page.Id
				refreshIndex()
				refreshButton()
			end
		elseif nav.Visible then
			floatUp("+1 " .. mineral.Name, mineral.Color:Lerp(NativeUI.WHITE, 0.3))
		end
	end)
end

return IndexController
