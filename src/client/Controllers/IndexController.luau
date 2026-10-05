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

local player = Players.LocalPlayer
local Pages = Config.Index.Pages
local PageOrder = Config.Index.PageOrder
local GOLD = Color3.fromRGB(255, 207, 55)
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

local function percent(fraction: number): string
	return "+" .. Format.number(math.floor(fraction * 100 + 0.5)) .. "%"
end

function IndexController:KnitStart()
	local IndexService = Knit.GetService("IndexService")
	local PlayerStateService = Knit.GetService("PlayerStateService")
	local HUDController = Knit.GetController("HUDController")
	local gui = NativeUI.get("MineralIndex")
	local nav: TextButton = child(gui, "IndexButton", "TextButton")
	local navRefs = ExactNavButton.bind(nav)
	local badge, tooltip = navRefs.badge, navRefs.tooltip
	local dimmer: TextButton = child(gui, "Dimmer", "TextButton")
	local panel: Frame = child(gui, "Panel", "Frame")
	local title: TextLabel = child(panel, "Title", "TextLabel")
	local close: TextButton = child(panel, "Close", "TextButton")
	local tabs: Frame = child(panel, "Tabs", "Frame")
	local tabList: UIListLayout = child(tabs, "List", "UIListLayout")
	local repeatTemplate: TextLabel = child(gui, "RepeatToastTemplate", "TextLabel")
	local pageControls: { [string]: any } = {}
	local tabButtons: { [string]: TextButton } = {}
	local open, fresh, hovering = false, false, false
	local selectedPage = PageOrder[1]
	local index: MineralIndex.PlayerIndex = {}
	local layout = NativeUI.hudLayout()

	for _, pageId in PageOrder do
		local page: ScrollingFrame = child(panel, pageId .. "Page", "ScrollingFrame")
		local bonus: Frame = child(page, "Bonus", "Frame")
		local progress: Frame = child(page, "Progress", "Frame")
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
			page = page, bonus = bonus, sales = child(bonus, "SalesBonus", "TextLabel"), bestTitle = child(bonus, "BestTitle", "TextLabel"),
			name = child(page, "PageName", "TextLabel"), found = child(page, "FoundCount", "TextLabel"), progress = progress,
			fill = child(progress, "Fill", "Frame"), reward = child(page, "Reward", "TextLabel"), cards = cards,
			grid = child(cards, "Grid", "UIGridLayout"), footer = child(page, "Footer", "TextLabel"), minerals = minerals,
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
		for _, pageId in PageOrder do
			local page = Pages[pageId]
			local controls = pageControls[pageId]
			local total, found = #page.Minerals, MineralIndex.found(index, pageId)
			local complete = found >= total
			local meteor = Config.Meteor.Types[pageId]
			local glow = if meteor then meteor.GlowColor else NativeUI.ORANGE
			local tier = if meteor then meteor.RequiredTier else 1
			local drops = if tier <= 1 then "Drops for every pickaxe on " .. page.Name .. " meteors"
				else "Drops only for Tier " .. tier .. "+ pickaxes on " .. page.Name .. " meteors"
			controls.page.Visible = selectedPage == pageId
			controls.sales.Text = if bonus > 0 then percent(bonus) .. " bar sales" else "No index bonus yet"
			controls.bestTitle.Text = if best then "Title: " .. best else "Complete a page for a title"
			controls.found.Text = if complete then "PAGE COMPLETE!" else Format.number(found) .. " / " .. Format.number(total) .. " minerals found"
			controls.found.TextColor3 = if complete then NativeUI.GREEN else NativeUI.MUTED
			controls.fill.Size = UDim2.fromScale(found / math.max(total, 1), 1)
			controls.fill.BackgroundColor3 = if complete then NativeUI.GREEN else glow
			controls.reward.Text = (if complete then "Earned: " else "Complete it for ") .. percent(page.CashBonus)
				.. " bar sales and the title \"" .. page.Title .. "\"\n" .. drops
			local tab = tabButtons[pageId]
			tab.Text = string.upper(page.Name) .. "\n" .. Format.number(found) .. "/" .. Format.number(total)
			tab.BackgroundColor3 = if selectedPage == pageId then GOLD else NativeUI.CARD
			tab.TextColor3 = if selectedPage == pageId then NativeUI.OUTLINE else NativeUI.MUTED
			for _, mineral in page.Minerals do
				local card = controls.minerals[mineral.Id]
				local count = index[mineral.Id] or 0
				local known = count > 0
				card.name.Text = if known then mineral.Name else "???"
				card.name.TextColor3 = if known then mineral.Color:Lerp(NativeUI.WHITE, 0.35) else NativeUI.MUTED
				card.found.Text = if known then "Found ×" .. Format.number(count) else "Not found yet"
				card.found.TextColor3 = if known then NativeUI.GREEN else NativeUI.MUTED
				card.edge.BackgroundColor3 = if known then mineral.Color:Lerp(Color3.new(0, 0, 0), 0.5) else Color3.fromRGB(20, 14, 12)
				card.diamond.BackgroundColor3 = if known then mineral.Color else NativeUI.OUTLINE
				card.shine.BackgroundTransparency = if known then 0.45 else 1
				card.unknown.Visible = not known
			end
		end
	end

	local function setOpen(value: boolean)
		open = value
		panel.Visible, dimmer.Visible = value, value
		player:SetAttribute("IndexOpen", value)
		if value then fresh = false end
		refreshButton()
	end

	local function updateLayout(nextLayout: HudLayout.Layout)
		layout = nextLayout
		local geometry = IndexLayout.compute(layout.viewport, layout.inset)
		rect(panel, geometry.panel)
		rect(title, geometry.title)
		rect(close, geometry.close)
		rect(tabs, geometry.tabs)
		title.TextSize = if geometry.narrow then 22 else 26
		tabList.Padding = UDim.new(0, geometry.tabGap)
		ExactNavButton.layout(nav, layout, "INDEX")
		for _, pageId in PageOrder do
			local controls = pageControls[pageId]
			local total = #Pages[pageId].Minerals
			local leftWidth = geometry.summaryWidth * (if geometry.narrow then 1 else 0.45)
			tabButtons[pageId].Size = UDim2.fromOffset(geometry.tabWidth, 44)
			rect(controls.page, geometry.content)
			controls.page.CanvasSize = UDim2.fromOffset(0, IndexLayout.canvasHeight(geometry, total))
			controls.bonus.Size = UDim2.fromOffset(geometry.summaryWidth, 44)
			controls.name.Size = UDim2.fromOffset(leftWidth, 26)
			controls.found.Size = UDim2.fromOffset(leftWidth, 20)
			controls.progress.Size = UDim2.fromOffset(leftWidth, 6)
			controls.reward.Position = if geometry.narrow then UDim2.fromOffset(4, 130) else UDim2.fromOffset(4 + geometry.summaryWidth * 0.5, 56)
			controls.reward.Size = UDim2.fromOffset(geometry.summaryWidth * (if geometry.narrow then 1 else 0.5), 66)
			controls.cards.Position = UDim2.fromOffset(4, geometry.cardsY)
			controls.cards.Size = UDim2.fromOffset(geometry.summaryWidth, IndexLayout.gridHeight(geometry, total))
			controls.grid.FillDirectionMaxCells = geometry.columns
			controls.grid.CellSize = UDim2.fromOffset(geometry.cardWidth, geometry.cardHeight)
			controls.grid.CellPadding = UDim2.fromOffset(geometry.gap, geometry.gap)
			for _, mineral in Pages[pageId].Minerals do
				controls.minerals[mineral.Id].card.Size = UDim2.fromOffset(geometry.cardWidth, geometry.cardHeight)
			end
			controls.footer.Position = UDim2.fromOffset(4, geometry.cardsY + IndexLayout.gridHeight(geometry, total) + 12)
			controls.footer.Size = UDim2.fromOffset(geometry.summaryWidth, 64)
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
		refreshIndex()
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
