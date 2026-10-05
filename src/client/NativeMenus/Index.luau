--!strict
-- Edit-time authoring only. Build this ScreenGui into StarterGui; the runtime
-- IndexController binds the cloned controls without constructing the menu.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local HudIcons = require(ReplicatedStorage.Shared.Config.HudIcons)
local HudLayout = require(ReplicatedStorage.Shared.HudLayout)
local IndexLayout = require(ReplicatedStorage.Shared.IndexLayout)
local MineralIndex = require(ReplicatedStorage.Shared.MineralIndex)

local WHITE = Color3.fromRGB(255, 255, 255)
local OUTLINE = Color3.fromRGB(12, 18, 25)
local PANEL = Color3.fromRGB(43, 44, 49)
local PANEL_DARK = Color3.fromRGB(29, 30, 35)
local CARD = Color3.fromRGB(67, 69, 77)
local SUBTEXT = Color3.fromRGB(211, 228, 240)
local CYAN = Color3.fromRGB(66, 190, 255)
local GOLD = Color3.fromRGB(255, 207, 55)
local RED = Color3.fromRGB(235, 70, 70)

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

local function stroke(parent: Instance, thickness: number)
	new("UIStroke", "Outline", parent, { Color = OUTLINE, Thickness = thickness, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
end

local function texture(parent: Instance, radius: number, transparency: number)
	local image = new("ImageLabel", "StudTexture", parent, {
		Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0,
		Image = "rbxassetid://6927295847", ImageTransparency = transparency,
		ScaleType = Enum.ScaleType.Tile, TileSize = UDim2.fromOffset(128, 128),
		ZIndex = 0, Active = false, Selectable = false,
	})
	corner(image, radius)
end

local function fill(parent: Instance, radius: number, thickness: number)
	corner(parent, radius)
	stroke(parent, thickness)
	texture(parent, radius, 0.75)
end

local function label(parent: Instance, name: string, props: { [string]: any }): TextLabel
	local defaults: { [string]: any } = {
		BackgroundTransparency = 1, BorderSizePixel = 0, Font = Enum.Font.FredokaOne,
		TextColor3 = WHITE, TextStrokeColor3 = OUTLINE, TextStrokeTransparency = 0,
		TextSize = 18, Text = "", ZIndex = 1,
	}
	for key, value in props do defaults[key] = value end
	return new("TextLabel", name, parent, defaults)
end

local function body(parent: Instance, name: string, props: { [string]: any }): TextLabel
	local defaults: { [string]: any } = { Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = SUBTEXT, TextStrokeTransparency = 1 }
	for key, value in props do defaults[key] = value end
	return label(parent, name, defaults)
end

local function button(parent: Instance, name: string, props: { [string]: any }): TextButton
	local defaults: { [string]: any } = {
		BackgroundColor3 = GOLD, BorderSizePixel = 0, AutoButtonColor = true,
		Active = true, Selectable = true,
		Font = Enum.Font.FredokaOne, TextSize = 20, TextColor3 = WHITE,
		TextStrokeColor3 = OUTLINE, TextStrokeTransparency = 0, Text = "", ZIndex = 1,
	}
	for key, value in props do defaults[key] = value end
	local result = new("TextButton", name, parent, defaults)
	fill(result, 4, 3)
	return result
end

local function rect(object: GuiObject, box: IndexLayout.Rect)
	object.Position = UDim2.fromOffset(box.x, box.y)
	object.Size = UDim2.fromOffset(box.w, box.h)
end

local function mineralCard(parent: Instance, order: number, mineral: Config.Mineral, geometry: IndexLayout.Layout)
	local card = new("Frame", mineral.Id, parent, {
		LayoutOrder = order, Size = UDim2.fromOffset(geometry.cardWidth, geometry.cardHeight), BackgroundColor3 = CARD, BorderSizePixel = 0,
	})
	fill(card, 4, 3)
	local showcase = new("Frame", "Showcase", card, {
		Position = UDim2.fromOffset(10, 10), Size = UDim2.new(1, -20, 0, 100), BackgroundColor3 = PANEL_DARK, BorderSizePixel = 0,
	})
	corner(showcase, 4)
	stroke(showcase, 3)
	local gem = new("Frame", "Gem", showcase, {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(84, 84), BackgroundTransparency = 1,
	})
	local edge = new("Frame", "Edge", gem, {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.55, 0.57), Size = UDim2.fromScale(0.62, 0.62),
		Rotation = 45, BackgroundColor3 = Color3.fromRGB(20, 14, 12), BorderSizePixel = 0,
	})
	corner(edge, 8)
	local diamond = new("Frame", "Diamond", gem, {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.62, 0.62),
		Rotation = 45, BackgroundColor3 = OUTLINE, BorderSizePixel = 0,
	})
	corner(diamond, 8)
	local shine = new("Frame", "Shine", diamond, {
		Position = UDim2.fromScale(0.14, 0.14), Size = UDim2.fromScale(0.34, 0.34), BackgroundColor3 = WHITE, BackgroundTransparency = 1, BorderSizePixel = 0,
	})
	corner(shine, 4)
	label(gem, "Unknown", { Size = UDim2.fromScale(1, 1), Text = "?", TextSize = 36, TextColor3 = SUBTEXT })
	label(card, "MineralName", { Position = UDim2.fromOffset(8, 116), Size = UDim2.new(1, -16, 0, 40), TextWrapped = true, Text = "???", TextColor3 = SUBTEXT })
	body(card, "Found", { Position = UDim2.fromOffset(8, 158), Size = UDim2.new(1, -16, 0, 18), Text = "Not found yet" })
	body(card, "Odds", {
		Position = UDim2.fromOffset(8, 178), Size = UDim2.new(1, -16, 0, 34), TextWrapped = true,
		Text = MineralIndex.oddsText(mineral), TextColor3 = if mineral.RichOnly then Config.Index.RichColor else SUBTEXT,
	})
end

local function pageView(panel: Instance, page: Config.IndexPage, geometry: IndexLayout.Layout)
	local meteor = Config.Meteor.Types[page.Id]
	local glow = if meteor then meteor.GlowColor else GOLD
	local total = #page.Minerals
	local content = new("ScrollingFrame", page.Id .. "Page", panel, {
		BackgroundColor3 = PANEL_DARK, BackgroundTransparency = 1, BorderSizePixel = 0,
		CanvasSize = UDim2.fromOffset(0, IndexLayout.canvasHeight(geometry, total)),
		ScrollingDirection = Enum.ScrollingDirection.Y, ScrollBarThickness = 4, ScrollBarImageColor3 = Color3.fromRGB(255, 219, 100),
		VerticalScrollBarInset = Enum.ScrollBarInset.Always, ElasticBehavior = Enum.ElasticBehavior.WhenScrollable,
		Visible = page.Id == Config.Index.PageOrder[1],
	})
	rect(content, geometry.content)
	corner(content, 4)
	local summaryLeft = geometry.summaryWidth * (if geometry.narrow then 1 else 0.45)
	local bonus = new("Frame", "Bonus", content, {
		Position = UDim2.fromOffset(4, 4), Size = UDim2.fromOffset(geometry.summaryWidth, 44), BackgroundTransparency = 1,
	})
	label(bonus, "SalesBonus", { Position = UDim2.fromOffset(0, 0), Size = UDim2.new(1, 0, 0, 22), TextSize = 17, TextColor3 = GOLD, TextXAlignment = Enum.TextXAlignment.Left, Text = "No index bonus yet" })
	body(bonus, "BestTitle", { Position = UDim2.fromOffset(0, 24), Size = UDim2.new(1, 0, 0, 20), TextXAlignment = Enum.TextXAlignment.Left, Text = "Complete a page for a title" })
	label(content, "PageName", { Position = UDim2.fromOffset(4, 56), Size = UDim2.fromOffset(summaryLeft, 26), Text = string.upper(page.Name) .. " PAGE", TextSize = 22, TextColor3 = glow, TextXAlignment = Enum.TextXAlignment.Left })
	body(content, "FoundCount", { Position = UDim2.fromOffset(4, 86), Size = UDim2.fromOffset(summaryLeft, 20), Text = "0 / " .. total .. " minerals found", TextXAlignment = Enum.TextXAlignment.Left })
	local progress = new("Frame", "Progress", content, { Position = UDim2.fromOffset(4, 112), Size = UDim2.fromOffset(summaryLeft, 6), BackgroundColor3 = OUTLINE, BorderSizePixel = 0 })
	corner(progress, 4)
	local progressFill = new("Frame", "Fill", progress, { Size = UDim2.fromScale(0, 1), BackgroundColor3 = glow, BorderSizePixel = 0 })
	corner(progressFill, 4)
	local tier = if meteor then meteor.RequiredTier else 1
	local drops = if tier <= 1 then "Drops for every pickaxe on " .. page.Name .. " meteors" else "Drops only for Tier " .. tier .. "+ pickaxes on " .. page.Name .. " meteors"
	body(content, "Reward", {
		Position = if geometry.narrow then UDim2.fromOffset(4, 130) else UDim2.fromOffset(4 + geometry.summaryWidth * 0.5, 56),
		Size = UDim2.fromOffset(geometry.summaryWidth * (if geometry.narrow then 1 else 0.5), 66), TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
		Text = "Complete it for +" .. math.floor(page.CashBonus * 100 + 0.5) .. "% bar sales and the title \"" .. page.Title .. "\"\n" .. drops,
	})
	local cards = new("Frame", "Cards", content, {
		Position = UDim2.fromOffset(4, geometry.cardsY), Size = UDim2.fromOffset(geometry.summaryWidth, IndexLayout.gridHeight(geometry, total)), BackgroundTransparency = 1, BorderSizePixel = 0,
	})
	new("UIGridLayout", "Grid", cards, {
		FillDirection = Enum.FillDirection.Horizontal, FillDirectionMaxCells = geometry.columns,
		CellSize = UDim2.fromOffset(geometry.cardWidth, geometry.cardHeight), CellPadding = UDim2.fromOffset(geometry.gap, geometry.gap), SortOrder = Enum.SortOrder.LayoutOrder,
	})
	for order, mineral in page.Minerals do mineralCard(cards, order, mineral, geometry) end
	body(content, "Footer", {
		Position = UDim2.fromOffset(4, geometry.cardsY + IndexLayout.gridHeight(geometry, total) + 12), Size = UDim2.fromOffset(geometry.summaryWidth, 64),
		TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
		Text = "Rich nodes sparkle gold. Only your own pickaxe unlocks a meteor's minerals, and nothing you can buy changes the odds.",
	})
end

local Index = {}

function Index.build(): ScreenGui
	local geometry = IndexLayout.compute(Vector2.new(1280, 720), 36)
	local hud = HudLayout.compute(Vector2.new(1280, 720), false, 36)
	local gui = new("ScreenGui", "MineralIndex", nil, { Enabled = true, ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 21, ZIndexBehavior = Enum.ZIndexBehavior.Sibling })
	gui:SetAttribute("NativePrefab", true)
	local nav = new("TextButton", "IndexButton", gui, {
		Position = UDim2.fromOffset(hud.buttons.INDEX.x, hud.buttons.INDEX.y), Size = UDim2.fromOffset(hud.buttonBase.X, hud.buttonBase.Y),
		Text = "", BackgroundColor3 = CYAN, BorderSizePixel = 0, AutoButtonColor = false, Active = true, Selectable = true,
	})
	fill(nav, 16, 2 / hud.buttonScale)
	new("UIScale", "Scale", nav, { Scale = hud.buttonScale })
	new("ImageLabel", "Icon", nav, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.02), Size = UDim2.fromScale(0.74, 0.74), Image = HudIcons.index, BackgroundTransparency = 1, BorderSizePixel = 0 })
	label(nav, "Caption", { Position = UDim2.fromScale(0, 0.70), Size = UDim2.fromScale(1, 0.30), Text = "INDEX", TextSize = hud.buttonTextSize or math.max(18, 11 / hud.buttonScale) })
	local badge = new("Frame", "ReadyBadge", nav, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -4, 0, 4), Size = UDim2.fromOffset(9, 9), BackgroundColor3 = Color3.fromRGB(105, 240, 103), BorderSizePixel = 0, Visible = false })
	corner(badge, 9)
	local tooltip = body(nav, "Tooltip", { Position = UDim2.new(0, -110, 0.5, -16), Size = UDim2.fromOffset(102, 32), Text = "INDEX", TextSize = 14, BackgroundTransparency = 0, BackgroundColor3 = Color3.fromRGB(28, 72, 105), Visible = false, ZIndex = 2 })
	corner(tooltip, 6)
	new("TextButton", "Dimmer", gui, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(9, 10, 16), BackgroundTransparency = 0.28, Text = "", AutoButtonColor = false, BorderSizePixel = 0, Visible = false, ZIndex = 2, Modal = true, Active = true })
	local panel = new("Frame", "Panel", gui, { BackgroundColor3 = PANEL, BorderSizePixel = 0, Visible = false, ZIndex = 3, Active = true })
	rect(panel, geometry.panel)
	fill(panel, 6, 4)
	local header = new("Frame", "MenuHeader", panel, { Size = UDim2.new(1, 0, 0, 52), BackgroundColor3 = CYAN, BorderSizePixel = 0, ZIndex = 0, Active = false })
	corner(header, 6)
	texture(header, 6, 0.65)
	new("Frame", "Divider", header, { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 4), BackgroundColor3 = OUTLINE, BorderSizePixel = 0, ZIndex = 0 })
	local title = label(panel, "Title", { Text = "MINERAL INDEX", TextSize = if geometry.narrow then 22 else 26, TextXAlignment = Enum.TextXAlignment.Left })
	rect(title, geometry.title)
	local close = button(panel, "Close", { BackgroundColor3 = RED })
	rect(close, geometry.close)
	new("ImageLabel", "Icon", close, { Position = UDim2.fromOffset(11, 11), Size = UDim2.fromOffset(22, 22), Image = HudIcons.close, BackgroundTransparency = 1, BorderSizePixel = 0 })
	local tabs = new("Frame", "Tabs", panel, { BackgroundTransparency = 1 })
	rect(tabs, geometry.tabs)
	new("UIListLayout", "List", tabs, { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, geometry.tabGap), SortOrder = Enum.SortOrder.LayoutOrder })
	for order, pageId in Config.Index.PageOrder do
		local page = Config.Index.Pages[pageId]
		button(tabs, pageId .. "Tab", { LayoutOrder = order, Size = UDim2.fromOffset(geometry.tabWidth, 44), TextSize = 14, TextWrapped = true, Text = string.upper(page.Name) .. "\n0/" .. #page.Minerals, BackgroundColor3 = if order == 1 then GOLD else CARD, TextColor3 = if order == 1 then OUTLINE else SUBTEXT })
		pageView(panel, page, geometry)
	end
	label(gui, "RepeatToastTemplate", { AnchorPoint = Vector2.new(1, 0.5), Size = UDim2.fromOffset(280, 30), Text = "", TextSize = 24, TextXAlignment = Enum.TextXAlignment.Right, Visible = false })
	return gui
end

return Index
