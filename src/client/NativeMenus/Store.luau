--!strict
-- The Store in the owner's "cartoon light" look (MenuTheme / Shared.MenuPalette, like the Gear Shop and Pets): a blue
-- "Store" ribbon, Close on the corner and the reassurance line in the header; a rail of tabs down the left (one per
-- Config.Store section, each with its HudIcons icon) and one scrolling page of titled sections whose cards are white
-- with a navy outline, an icon well tinted by the section, the title, the description, a status line and a chunky
-- price button. Every card is authored here; StoreController binds them by name and only paints their state.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Palette = require(ReplicatedStorage.Shared.MenuPalette)
local N = require(script.Parent.Parent.NativeUI)
local Theme = require(script.Parent.Parent.MenuTheme)
local Menu = {}
Menu.LAYOUT = 3 -- bumped when the panel's controls change; an older authored copy is replaced by StoreController
local Monetization = Config.Monetization
local Sections = Config.Store.Sections
local ICONS: { [string]: string } = {
	TwoXOre = "ore", BiggerBackpack = "backpack", OfflineHours = "bars", AutoDeposit = "foundry", VIP = "premium",
	CallMeteor = "meteor", Overclock = "foundry", TipJar = "premium", PocketChange = "coin",
	MiniOverclock = "foundry", OreRush = "ore", CashBundle = "coin", PetSlot = "plus",
	TwoXCash = "coin", StarterPack = "bars", PetMax = "pets", StreakShield = "premium",
	BossMeteor = "meteorAlien", Shards50 = "crystal", Shards250 = "crystal", Shards1000 = "crystal", RebirthKeep = "rebirth",
	Drillbot = "pets", SolarPhoenix = "pets",
}
Menu.ICONS = ICONS

-- An icon well's gradient and edge for each Config.Store section colour
local WELLS: { [string]: { Color3 } } = {
	gold = { Palette.GOLD_WELL_TOP, Palette.GOLD_WELL_BOTTOM, Palette.EVO_EDGE },
	blue = { Palette.WELL_TOP, Palette.WELL_BOTTOM, Palette.WELL_EDGE },
	orange = { Color3.fromRGB(255, 233, 201), Color3.fromRGB(255, 194, 122), Color3.fromRGB(232, 154, 60) },
	green = { Color3.fromRGB(236, 249, 226), Color3.fromRGB(190, 236, 160), Color3.fromRGB(150, 210, 110) },
	purple = { Color3.fromRGB(243, 232, 255), Color3.fromRGB(214, 184, 255), Color3.fromRGB(167, 116, 232) },
}

local function card(parent: Instance, key: string, order: number, kind: string, definition: any, wide: boolean, color: string)
	local frame = Theme.card(parent, key, Palette.WHITE, Palette.DETAIL_BOTTOM, 14)
	frame.LayoutOrder, frame.Size, frame.ZIndex = order, UDim2.fromOffset(218, 330), 3
	Theme.stroke(frame, Palette.NAVY, 3)
	frame:SetAttribute("Wide", wide)
	local kindText = Theme.label(frame, "Kind", if kind == "pass" then "GAME PASS" else "PRODUCT", 12, Palette.SECOND, nil, Enum.TextXAlignment.Center)
	kindText.Position, kindText.Size = UDim2.fromOffset(4, 8), UDim2.new(1, -8, 0, 14)
	local look = WELLS[color] or WELLS.blue
	local well = N.create("Frame", { Name = "IconWell", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 26),
		Size = UDim2.fromOffset(100, 100), BorderSizePixel = 0, ZIndex = 4 }, frame)
	Theme.round(well, 14)
	Theme.gradient(well, look[1], look[2])
	Theme.stroke(well, look[3], 2.5)
	local icon = Config.HudIcons[ICONS[key] or "premium"]
	-- white icons (the paw, the plus) are tinted navy so they read on the pale well
	local white = ICONS[key] == "pets" or ICONS[key] == "plus"
	N.create("ImageLabel", { Name = "ItemIcon", Image = icon, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.74, 0.74), BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Fit, ZIndex = 5,
		ImageColor3 = if white then Palette.NAVY else Palette.WHITE }, well)
	-- the price is on the button; this stays for bindings and is hidden by the controller
	local price = Theme.label(frame, "Price", if definition.Robux then "R$ " .. Format.number(definition.Robux) else "NOT ON SALE", 16, Palette.NAVY)
	price.Visible = false
	local title = Theme.label(frame, "Title", definition.Name, 24, Palette.NAVY, Theme.TITLE_FONT, Enum.TextXAlignment.Center)
	title.TextScaled, title.TextWrapped = true, true
	N.create("UITextSizeConstraint", { MinTextSize = 12, MaxTextSize = 24 }, title)
	local description = Theme.label(frame, "Description", definition.Description, 14, Palette.SECOND, nil, Enum.TextXAlignment.Center)
	description.TextWrapped, description.TextYAlignment = true, Enum.TextYAlignment.Top
	local status = Theme.label(frame, "Status", "", 13, Palette.GOLD_TEXT, nil, Enum.TextXAlignment.Center)
	status.TextWrapped, status.TextYAlignment = true, Enum.TextYAlignment.Top
	local buy = Theme.button(frame, "Buy", "NOT ON SALE YET", "face", 21)
	buy.AnchorPoint, buy.Size = Vector2.new(0.5, 1), UDim2.fromOffset(190, 50)
end

function Menu.build(): ScreenGui
	local gui = N.create("ScreenGui", { Name = "Store", ResetOnSpawn = false, IgnoreGuiInset = true, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 23 }, nil) :: ScreenGui
	gui:SetAttribute("NativePrefab", true)
	gui:SetAttribute("StoreLayout", Menu.LAYOUT)
	-- the nav tile on the HUD (the owner's tile is cloned over this by ExactNavButton)
	local nav = N.button(gui, "StoreButton", "", UDim2.fromOffset(1112, 502), UDim2.fromOffset(120, 108), Color3.fromRGB(255, 207, 55))
	N.create("UIScale", { Name = "LayoutScale", Scale = 1 }, nav)
	N.create("ImageLabel", { Name = "Icon", Image = Config.HudIcons.store, Position = UDim2.new(0.13, 0, 0.02, 0), Size = UDim2.fromScale(0.74, 0.74),
		BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Fit }, nav)
	local caption = N.text(nav, "Caption", "STORE", UDim2.fromScale(0, 0.70), UDim2.fromScale(1, 0.30))
	caption.TextSize, caption.TextXAlignment = 18, Enum.TextXAlignment.Center
	local tooltip = N.text(nav, "Tooltip", "STORE", UDim2.new(1, 8, 0.5, -16), UDim2.fromOffset(102, 32))
	tooltip.TextSize, tooltip.TextXAlignment = 14, Enum.TextXAlignment.Center
	tooltip.BackgroundTransparency, tooltip.BackgroundColor3, tooltip.Visible, tooltip.ZIndex = 0, Color3.fromRGB(28, 72, 105), false, 2

	-- the screen behind the menu: 20% navy, as behind the Gear Shop
	N.create("TextButton", { Name = "Dimmer", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Palette.NAVY, BackgroundTransparency = 0.8, Text = "",
		AutoButtonColor = false, BorderSizePixel = 0, Visible = false, Modal = true }, gui)
	local panel = Theme.panel(gui, "Panel", UDim2.fromOffset(900, 680)) :: any
	panel.AnchorPoint, panel.Position, panel.Visible = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5), false
	Theme.ribbon(panel, "Store", Config.HudIcons.premium)
	Theme.closeCorner(panel, Config.HudIcons.close)
	local subtitle = Theme.label(panel, "Subtitle", "Passes last forever. Nothing here changes meteor or mineral odds.", 14, Palette.SECOND, nil,
		Enum.TextXAlignment.Right)
	subtitle.TextWrapped, subtitle.TextScaled = true, true
	N.create("UITextSizeConstraint", { MinTextSize = 10, MaxTextSize = 14 }, subtitle)

	local list = N.create("ScrollingFrame", {
		Name = "List", Position = UDim2.fromOffset(164, 58), Size = UDim2.new(1, -178, 1, -72), BackgroundTransparency = 1, BorderSizePixel = 0,
		CanvasSize = UDim2.fromOffset(0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 6, ScrollBarImageColor3 = Palette.BLUE_BOTTOM, VerticalScrollBarInset = Enum.ScrollBarInset.Always, ZIndex = 3,
	}, panel)
	N.create("UIPadding", { Name = "ListPadding", PaddingLeft = UDim.new(0, 12), PaddingTop = UDim.new(0, 12), PaddingRight = UDim.new(0, 12),
		PaddingBottom = UDim.new(0, 12) }, list)
	N.create("UIListLayout", { Name = "Sections", Padding = UDim.new(0, 16), SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center }, list)
	-- one titled section per Config.Store entry: the section's icon and title over a grid of its cards
	for index, section in Sections do
		local frame = N.create("Frame", { Name = "Section_" .. section.Id, LayoutOrder = index, Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, ZIndex = 3 }, list)
		N.create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center }, frame)
		local heading = Theme.label(frame, "SectionTitle", section.Title, 24, Palette.NAVY, Theme.TITLE_FONT)
		heading.LayoutOrder, heading.Size = 0, UDim2.new(1, 0, 0, 34)
		N.create("UIPadding", { PaddingLeft = UDim.new(0, 38) }, heading)
		N.create("ImageLabel", { Name = "Icon", Image = Config.HudIcons[section.Icon], AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, -38, 0.5, 0),
			Size = UDim2.fromOffset(30, 30), BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Fit, ZIndex = 5,
			ImageColor3 = if section.Icon == "pets" then Palette.NAVY else Palette.WHITE }, heading)
		local cards = N.create("Frame", { Name = "Cards", LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1, ZIndex = 3 }, frame)
		N.create("UIGridLayout", { Name = "Grid", FillDirection = Enum.FillDirection.Horizontal, FillDirectionMaxCells = 3,
			HorizontalAlignment = Enum.HorizontalAlignment.Center, CellPadding = UDim2.fromOffset(12, 12), CellSize = UDim2.fromOffset(218, 330),
			SortOrder = Enum.SortOrder.LayoutOrder }, cards)
		for order, key in section.Keys do
			local pass = Monetization.Passes[key]
			card(cards, key, order, if pass then "pass" else "product", pass or Monetization.Products[key], section.Style == "wide", section.Color)
		end
	end
	-- the tab rail on the left: one chunky button per section that has a tab, jumping the page to it
	local tabs = N.create("ScrollingFrame", {
		Name = "Tabs", Position = UDim2.fromOffset(14, 58), Size = UDim2.new(0, 140, 1, -72), BackgroundTransparency = 1, BorderSizePixel = 0,
		CanvasSize = UDim2.fromOffset(0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 0, ScrollingDirection = Enum.ScrollingDirection.Y,
		ZIndex = 3,
	}, panel)
	N.create("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center }, tabs)
	N.create("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8) }, tabs)
	for index, section in Sections do
		if section.Tab then
			local tab = Theme.button(tabs, "Tab_" .. section.Id, section.Tab, if index == 1 then "tabOn" else "tabOff", 16)
			tab.LayoutOrder, tab.Size = index, UDim2.fromOffset(136, 48)
			local face = tab:FindFirstChild("Face") :: Frame
			N.create("ImageLabel", { Name = "Icon", Image = Config.HudIcons[section.Icon], AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 6, 0.5, 0),
				Size = UDim2.fromOffset(28, 28), BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Fit, ZIndex = 8 }, face)
			-- the caption starts after the icon
			local label = face:FindFirstChild("Label") :: TextLabel
			local padding = label:FindFirstChildOfClass("UIPadding") :: UIPadding
			padding.PaddingLeft = UDim.new(0, 36)
			label.TextXAlignment = Enum.TextXAlignment.Left
		end
	end
	return gui
end

return Menu
