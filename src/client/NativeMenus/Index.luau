--!strict
-- The Mineral Index in the cartoon light look (MenuTheme), laid out as the owner's mockup (Craterworks Menu Redesign,
-- 2026-10-15): a "Mineral Index" ribbon and Close on the corner, the index bonus chip, one tab per meteor page (its meteor
-- icon and count), then the page's minerals as a scrolling grid of wide cards (the gem on a pale well, the name, the odds
-- pill and how many you found) and a side column: a gold card with the page's progress and what completing it pays, and
-- your best title. IndexController binds the named controls and lays them out (Shared.IndexLayout). The ScreenGui also owns
-- the INDEX button on the HUD (ExactNavButton styles it).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local HudIcons = require(ReplicatedStorage.Shared.Config.HudIcons)
local HudLayout = require(ReplicatedStorage.Shared.HudLayout)
local IndexLayout = require(ReplicatedStorage.Shared.IndexLayout)
local MineralIndex = require(ReplicatedStorage.Shared.MineralIndex)
local Palette = require(ReplicatedStorage.Shared.MenuPalette)
local MenuTheme = require(script.Parent.Parent.MenuTheme)
local ExactNavButton = require(script.Parent.Parent.ExactNavButton)

local WHITE = Color3.fromRGB(255, 255, 255)
local OUTLINE = Color3.fromRGB(12, 18, 25)

local Index = {}
Index.LAYOUT = 3 -- bumped when the controls change; IndexController rebuilds an older copy
-- each page's tab icon (Config.HudIcons)
Index.PAGE_ICONS = { Iron = "meteor", Ice = "meteorIce", Crystal = "meteorCrystal" }

local function new(className: string, name: string, parent: Instance?, props: { [string]: any }): any
	local object = Instance.new(className)
	object.Name = name
	for property, value in props do (object :: any)[property] = value end
	object.Parent = parent
	return object
end

local function corner(parent: Instance, radius: number)
	new("UICorner", "Corner", parent, { CornerRadius = UDim.new(0, radius) })
end

local function rect(object: GuiObject, box: IndexLayout.Rect)
	object.Position = UDim2.fromOffset(box.x, box.y)
	object.Size = UDim2.fromOffset(box.w, box.h)
end

-- text on the light body
local function text(parent: Instance, name: string, value: string, size: number, color: Color3, title: boolean?, props: { [string]: any }?): TextLabel
	local label = MenuTheme.label(parent, name, value, size, color, if title then MenuTheme.TITLE_FONT else nil)
	for key, prop in props or {} do (label :: any)[key] = prop end
	return label
end

-- a vertical stack inside a card or column
local function stack(parent: Instance, padding: number)
	new("UIListLayout", "List", parent, { Padding = UDim.new(0, padding), SortOrder = Enum.SortOrder.LayoutOrder })
end

local function mineralCard(parent: Instance, order: number, mineral: Config.Mineral, geometry: IndexLayout.Layout)
	local card = MenuTheme.box(parent, mineral.Id)
	card.LayoutOrder, card.Size = order, UDim2.fromOffset(geometry.cardWidth, geometry.cardHeight)
	local showcase = MenuTheme.card(card, "Showcase", Palette.WELL_TOP, Palette.WELL_BOTTOM, 12)
	showcase.Position, showcase.Size = UDim2.fromOffset(10, 10), UDim2.fromOffset(92, 92)
	MenuTheme.stroke(showcase, Palette.WELL_EDGE, 2.5)
	local gem = new("Frame", "Gem", showcase, {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(70, 70), BackgroundTransparency = 1, ZIndex = 3,
	})
	-- the gem: a rotated square with a darker edge behind it and a shine; IndexController colours it once found
	local edge = new("Frame", "Edge", gem, {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.55, 0.57), Size = UDim2.fromScale(0.62, 0.62),
		Rotation = 45, BackgroundColor3 = Palette.NAVY, BorderSizePixel = 0, ZIndex = 3,
	})
	corner(edge, 8)
	local diamond = new("Frame", "Diamond", gem, {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.62, 0.62),
		Rotation = 45, BackgroundColor3 = Palette.GREY_BOTTOM, BorderSizePixel = 0, ZIndex = 4,
	})
	corner(diamond, 8)
	MenuTheme.stroke(diamond, Palette.NAVY, 2.5)
	local shine = new("Frame", "Shine", diamond, {
		Position = UDim2.fromScale(0.14, 0.14), Size = UDim2.fromScale(0.34, 0.34), BackgroundColor3 = WHITE, BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 5,
	})
	corner(shine, 4)
	text(gem, "Unknown", "?", 30, Palette.WHITE, true, { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 6 })
	MenuTheme.ink((gem :: any).Unknown, true, 2.5)
	-- right of the well: the name, the odds pill and the found line
	text(card, "MineralName", "???", 19, Palette.SECOND, true, { Position = UDim2.fromOffset(114, 12), Size = UDim2.new(1, -124, 0, 24),
		TextScaled = true, TextTruncate = Enum.TextTruncate.AtEnd })
	new("UITextSizeConstraint", "Limit", (card :: any).MineralName, { MinTextSize = 12, MaxTextSize = 19 })
	local odds = MenuTheme.pill(card, "Odds", if mineral.RichOnly then Palette.CASH_CHIP else Palette.PILL, Palette.NAVY, Palette.NAVY, 13)
	odds.Position, odds.Size = UDim2.fromOffset(114, 42), UDim2.new(1, -124, 0, 22)
	local oddsLabel = odds:FindFirstChild("Label") :: TextLabel
	oddsLabel.Text, oddsLabel.TextXAlignment = MineralIndex.oddsText(mineral), Enum.TextXAlignment.Left
	text(card, "Found", "Not found yet", 14, Palette.SECOND, false, { Position = UDim2.fromOffset(114, 70), Size = UDim2.new(1, -124, 0, 34),
		TextWrapped = true, TextScaled = true, TextYAlignment = Enum.TextYAlignment.Top })
	new("UITextSizeConstraint", "Limit", (card :: any).Found, { MinTextSize = 10, MaxTextSize = 14 })
end

local function pageView(panel: Instance, page: Config.IndexPage, geometry: IndexLayout.Layout)
	local total = #page.Minerals
	local content = new("ScrollingFrame", page.Id .. "Page", panel, {
		BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 3,
		CanvasSize = UDim2.fromOffset(0, IndexLayout.canvasHeight(geometry, total)),
		ScrollingDirection = Enum.ScrollingDirection.Y, ScrollBarThickness = 4, ScrollBarImageColor3 = Palette.BLUE_BOTTOM,
		VerticalScrollBarInset = Enum.ScrollBarInset.Always, ElasticBehavior = Enum.ElasticBehavior.WhenScrollable,
		Visible = page.Id == Config.Index.PageOrder[1],
	})
	rect(content, geometry.grid)
	local cards = new("Frame", "Cards", content, {
		Position = UDim2.fromOffset(4, 4), Size = UDim2.fromOffset(geometry.grid.w - IndexLayout.Scrollbar, IndexLayout.gridHeight(geometry, total)),
		BackgroundTransparency = 1, BorderSizePixel = 0,
	})
	new("UIGridLayout", "Grid", cards, {
		FillDirection = Enum.FillDirection.Horizontal, FillDirectionMaxCells = geometry.columns,
		CellSize = UDim2.fromOffset(geometry.cardWidth, geometry.cardHeight), CellPadding = UDim2.fromOffset(geometry.gap, geometry.gap), SortOrder = Enum.SortOrder.LayoutOrder,
	})
	for order, mineral in page.Minerals do mineralCard(cards, order, mineral, geometry) end
	text(content, "Footer", "Rich nodes sparkle gold. Only your own pickaxe unlocks a meteor's minerals, and nothing you can buy changes the odds.", 13, Palette.SECOND, false, {
		Position = UDim2.fromOffset(4, 12 + IndexLayout.gridHeight(geometry, total)), Size = UDim2.fromOffset(geometry.grid.w - IndexLayout.Scrollbar, 48),
		TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top,
	})
end

-- The side column: the selected page's gold card (progress, reward) and your best title
local function sideColumn(panel: Instance, geometry: IndexLayout.Layout)
	local side = new("ScrollingFrame", "Side", panel, {
		BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 3, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y, ScrollBarThickness = 3, ScrollBarImageColor3 = Palette.BLUE_BOTTOM,
	})
	rect(side, geometry.side)
	stack(side, 10)
	new("UIPadding", "Padding", side, { PaddingTop = UDim.new(0, 3), PaddingLeft = UDim.new(0, 3), PaddingRight = UDim.new(0, 3), PaddingBottom = UDim.new(0, 3) })
	local gold = MenuTheme.goldCard(side, "PageCard")
	gold.LayoutOrder, gold.Size, gold.AutomaticSize = 1, UDim2.new(1, 0, 0, 0), Enum.AutomaticSize.Y
	stack(gold, 6)
	new("UIPadding", "Padding", gold, { PaddingTop = UDim.new(0, 12), PaddingBottom = UDim.new(0, 12), PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14) })
	text(gold, "PageName", "IRON PAGE", 16, Palette.NAVY, true, { LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 20) })
	local count = new("Frame", "Count", gold, { LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 34), BackgroundTransparency = 1 })
	text(count, "FoundCount", "0 / 0", 28, Palette.NAVY, true, { Size = UDim2.new(0.65, 0, 1, 0) })
	text(count, "FoundLabel", "found", 13, Palette.GOLD_TEXT, false, { Position = UDim2.fromScale(0.65, 0), Size = UDim2.new(0.35, 0, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Right })
	local bar = MenuTheme.bar(gold, "Progress", Palette.BAR_FILL)
	bar.LayoutOrder, bar.Size = 3, UDim2.new(1, 0, 0, 14)
	local divider = MenuTheme.divider(gold, "Divider")
	divider.LayoutOrder, divider.BackgroundColor3 = 4, Palette.GOLD_DIVIDER
	text(gold, "RewardCaption", "COMPLETE IT FOR", 13, Palette.GOLD_TEXT, false, { LayoutOrder = 5, Size = UDim2.new(1, 0, 0, 16) })
	text(gold, "Reward", "", 18, Palette.NAVY, true, { LayoutOrder = 6, Size = UDim2.new(1, 0, 0, 22) })
	text(gold, "RewardTitle", "", 15, Palette.NAVY, true, { LayoutOrder = 7, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
		TextWrapped = true, RichText = true })
	text(gold, "Drops", "", 13, Palette.GOLD_TEXT, false, { LayoutOrder = 8, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
		TextWrapped = true })

	local titles = MenuTheme.soft(side, "TitleCard")
	titles.LayoutOrder, titles.Size, titles.AutomaticSize = 2, UDim2.new(1, 0, 0, 0), Enum.AutomaticSize.Y
	stack(titles, 4)
	new("UIPadding", "Padding", titles, { PaddingTop = UDim.new(0, 12), PaddingBottom = UDim.new(0, 12), PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) })
	text(titles, "Heading", "YOUR BEST TITLE", 15, Palette.NAVY, true, { LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 18) })
	text(titles, "BestTitle", "None yet", 18, Palette.BLUE_BOTTOM, true, { LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 22) })
	text(titles, "Caption", "Shown over your head. Complete a page for a title.", 13, Palette.SECOND, false, { LayoutOrder = 3,
		Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextWrapped = true })
end

function Index.build(): ScreenGui
	local geometry = IndexLayout.compute(Vector2.new(1280, 720), 36)
	local hud = HudLayout.compute(Vector2.new(1280, 720), false, 36)
	local gui, panel = MenuTheme.menu("MineralIndex", "Mineral Index", "index", Vector2.new(geometry.panel.w, geometry.panel.h), Index.LAYOUT)
	gui.Enabled, gui.DisplayOrder = true, 21
	panel.Visible, panel.ZIndex = false, 3
	rect(panel, geometry.panel)
	panel.AnchorPoint = Vector2.zero
	local dimmer = gui:FindFirstChild("Dimmer") :: TextButton
	dimmer.Visible, dimmer.ZIndex = false, 2
	-- the INDEX button on the HUD lives in this ScreenGui: the same tile as the other menu buttons (ExactNavButton)
	local nav = ExactNavButton.author(gui, "IndexButton", "Index", HudIcons.index)
	nav.Position = UDim2.fromOffset(hud.buttons.INDEX.x, hud.buttons.INDEX.y)

	-- Close is the red corner button (IndexController places it by its top left); the index bonus chip sits left of it
	local close = panel:FindFirstChild("Close") :: TextButton
	close.AnchorPoint = Vector2.zero
	rect(close, geometry.close)
	local chip = MenuTheme.chip(panel, "Bonus", HudIcons.bars, Palette.BOOST)
	chip.Text = "No bonus yet"
	rect(chip, geometry.chip)
	local tabs = new("Frame", "Tabs", panel, { BackgroundTransparency = 1, ZIndex = 3 })
	rect(tabs, geometry.tabs)
	new("UIListLayout", "List", tabs, { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, geometry.tabGap), SortOrder = Enum.SortOrder.LayoutOrder })
	for order, pageId in Config.Index.PageOrder do
		local page = Config.Index.Pages[pageId]
		local tab = MenuTheme.button(tabs, pageId .. "Tab", string.upper(page.Name) .. " 0/" .. #page.Minerals, if order == 1 then "tabOn" else "tabOff", 17)
		tab.LayoutOrder, tab.Size = order, UDim2.fromOffset(geometry.tabWidth, geometry.tabs.h)
		MenuTheme.withIcon(tab, Index.PAGE_ICONS[pageId] or "meteor", 26)
		pageView(panel, page, geometry)
	end
	sideColumn(panel, geometry)
	new("TextLabel", "RepeatToastTemplate", gui, { AnchorPoint = Vector2.new(1, 0.5), Size = UDim2.fromOffset(280, 30), Text = "", TextSize = 24, Font = Enum.Font.FredokaOne,
		BackgroundTransparency = 1, TextColor3 = WHITE, TextStrokeColor3 = OUTLINE, TextStrokeTransparency = 0, TextXAlignment = Enum.TextXAlignment.Right, Visible = false })
	return gui
end

return Index
