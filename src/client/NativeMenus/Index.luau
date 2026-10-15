--!strict
-- The Mineral Index in the cartoon light look (MenuTheme): a "Mineral Index" ribbon and Close on the corner, one tab per
-- meteor page, then the page: the index bonus and best title, the page's name, how many minerals are found with a bar,
-- what completing it pays, and a white card per mineral with its gem on a pale blue well, its name, how many you found and
-- its odds. IndexController binds the named controls and lays them out (Shared.IndexLayout). The ScreenGui also owns
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

local function mineralCard(parent: Instance, order: number, mineral: Config.Mineral, geometry: IndexLayout.Layout)
	local card = MenuTheme.whiteCard(parent, mineral.Id, 14)
	card.LayoutOrder, card.Size = order, UDim2.fromOffset(geometry.cardWidth, geometry.cardHeight)
	local showcase = MenuTheme.card(card, "Showcase", Palette.WELL_TOP, Palette.WELL_BOTTOM, 12)
	showcase.Position, showcase.Size = UDim2.fromOffset(10, 10), UDim2.new(1, -20, 0, 100)
	MenuTheme.stroke(showcase, Palette.WELL_EDGE, 2.5)
	local gem = new("Frame", "Gem", showcase, {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(84, 84), BackgroundTransparency = 1, ZIndex = 3,
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
	text(gem, "Unknown", "?", 36, Palette.WHITE, true, { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 6 })
	MenuTheme.ink((gem :: any).Unknown, true, 2.5)
	text(card, "MineralName", "???", 19, Palette.SECOND, true, { Position = UDim2.fromOffset(8, 116), Size = UDim2.new(1, -16, 0, 40), TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Center })
	text(card, "Found", "Not found yet", 14, Palette.SECOND, false, { Position = UDim2.fromOffset(8, 158), Size = UDim2.new(1, -16, 0, 18),
		TextXAlignment = Enum.TextXAlignment.Center })
	text(card, "Odds", MineralIndex.oddsText(mineral), 13, if mineral.RichOnly then Palette.GOLD_TEXT else Palette.SECOND, false, {
		Position = UDim2.fromOffset(8, 178), Size = UDim2.new(1, -16, 0, 34), TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Center,
	})
end

local function pageView(panel: Instance, page: Config.IndexPage, geometry: IndexLayout.Layout)
	local meteor = Config.Meteor.Types[page.Id]
	local glow = if meteor then meteor.GlowColor else Palette.GOLD_BOTTOM
	local total = #page.Minerals
	local content = new("ScrollingFrame", page.Id .. "Page", panel, {
		BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 3,
		CanvasSize = UDim2.fromOffset(0, IndexLayout.canvasHeight(geometry, total)),
		ScrollingDirection = Enum.ScrollingDirection.Y, ScrollBarThickness = 4, ScrollBarImageColor3 = Palette.BLUE_BOTTOM,
		VerticalScrollBarInset = Enum.ScrollBarInset.Always, ElasticBehavior = Enum.ElasticBehavior.WhenScrollable,
		Visible = page.Id == Config.Index.PageOrder[1],
	})
	rect(content, geometry.content)
	local summaryLeft = geometry.summaryWidth * (if geometry.narrow then 1 else 0.45)
	local bonus = new("Frame", "Bonus", content, {
		Position = UDim2.fromOffset(4, 4), Size = UDim2.fromOffset(geometry.summaryWidth, 44), BackgroundTransparency = 1,
	})
	text(bonus, "SalesBonus", "No index bonus yet", 18, Palette.GOLD_TEXT, true, { Size = UDim2.new(1, 0, 0, 22) })
	text(bonus, "BestTitle", "Complete a page for a title", 14, Palette.SECOND, false, { Position = UDim2.fromOffset(0, 24), Size = UDim2.new(1, 0, 0, 20) })
	local name = text(content, "PageName", string.upper(page.Name) .. " PAGE", 22, glow, true, { Position = UDim2.fromOffset(4, 56), Size = UDim2.fromOffset(summaryLeft, 26) })
	MenuTheme.ink(name, true, 2) -- the meteor glow colours are light: the ink keeps them readable on the white body
	text(content, "FoundCount", "0 / " .. total .. " minerals found", 14, Palette.SECOND, false, { Position = UDim2.fromOffset(4, 86), Size = UDim2.fromOffset(summaryLeft, 20) })
	local progress = MenuTheme.bar(content, "Progress", glow)
	progress.Position, progress.Size = UDim2.fromOffset(4, 110), UDim2.fromOffset(summaryLeft, 10)
	local tier = if meteor then meteor.RequiredTier else 1
	local drops = if tier <= 1 then "Drops for every pickaxe on " .. page.Name .. " meteors" else "Drops only for Tier " .. tier .. "+ pickaxes on " .. page.Name .. " meteors"
	text(content, "Reward", "Complete it for +" .. math.floor(page.CashBonus * 100 + 0.5) .. "% bar sales and the title \"" .. page.Title .. "\"\n" .. drops, 14, Palette.NAVY, false, {
		Position = if geometry.narrow then UDim2.fromOffset(4, 130) else UDim2.fromOffset(4 + geometry.summaryWidth * 0.5, 56),
		Size = UDim2.fromOffset(geometry.summaryWidth * (if geometry.narrow then 1 else 0.5), 66), TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
	})
	local cards = new("Frame", "Cards", content, {
		Position = UDim2.fromOffset(4, geometry.cardsY), Size = UDim2.fromOffset(geometry.summaryWidth, IndexLayout.gridHeight(geometry, total)), BackgroundTransparency = 1, BorderSizePixel = 0,
	})
	new("UIGridLayout", "Grid", cards, {
		FillDirection = Enum.FillDirection.Horizontal, FillDirectionMaxCells = geometry.columns,
		CellSize = UDim2.fromOffset(geometry.cardWidth, geometry.cardHeight), CellPadding = UDim2.fromOffset(geometry.gap, geometry.gap), SortOrder = Enum.SortOrder.LayoutOrder,
	})
	for order, mineral in page.Minerals do mineralCard(cards, order, mineral, geometry) end
	text(content, "Footer", "Rich nodes sparkle gold. Only your own pickaxe unlocks a meteor's minerals, and nothing you can buy changes the odds.", 13, Palette.SECOND, false, {
		Position = UDim2.fromOffset(4, geometry.cardsY + IndexLayout.gridHeight(geometry, total) + 12), Size = UDim2.fromOffset(geometry.summaryWidth, 64),
		TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top,
	})
end

local Index = {}
Index.LAYOUT = 2 -- bumped when the controls change; IndexController rebuilds an older copy

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

	-- a subtitle right of the ribbon; Close is the red corner button (IndexController places it by its top left)
	local title = text(panel, "Title", "Find every mineral!", 18, Palette.SECOND, true, { TextScaled = true, TextXAlignment = Enum.TextXAlignment.Right })
	new("UITextSizeConstraint", "Limit", title, { MinTextSize = 10, MaxTextSize = 18 })
	rect(title, geometry.title)
	local close = panel:FindFirstChild("Close") :: TextButton
	close.AnchorPoint = Vector2.zero
	rect(close, geometry.close)
	local tabs = new("Frame", "Tabs", panel, { BackgroundTransparency = 1, ZIndex = 3 })
	rect(tabs, geometry.tabs)
	new("UIListLayout", "List", tabs, { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, geometry.tabGap), SortOrder = Enum.SortOrder.LayoutOrder })
	for order, pageId in Config.Index.PageOrder do
		local page = Config.Index.Pages[pageId]
		local tab = MenuTheme.button(tabs, pageId .. "Tab", string.upper(page.Name) .. "\n0/" .. #page.Minerals, if order == 1 then "tabOn" else "tabOff", 16)
		tab.LayoutOrder, tab.Size = order, UDim2.fromOffset(geometry.tabWidth, geometry.tabs.h)
		pageView(panel, page, geometry)
	end
	new("TextLabel", "RepeatToastTemplate", gui, { AnchorPoint = Vector2.new(1, 0.5), Size = UDim2.fromOffset(280, 30), Text = "", TextSize = 24, Font = Enum.Font.FredokaOne,
		BackgroundTransparency = 1, TextColor3 = WHITE, TextStrokeColor3 = OUTLINE, TextStrokeTransparency = 0, TextXAlignment = Enum.TextXAlignment.Right, Visible = false })
	return gui
end

return Index
