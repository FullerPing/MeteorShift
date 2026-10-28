--!strict
-- The Gear shop, from the owner's "cartoon light" mockup (2026-10-13; MenuTheme / Shared.MenuPalette): a white-to-pale-blue
-- body with a blue "Gear Shop" ribbon poking out of its top left, a red Close on the top right corner and the gold cash chip
-- under it, two tabs, and per gear kind: the name over a "Tier" pill and the level cap, a blue preview well with a "LEVEL"
-- pill, the highlighted level row over the stat rows, three quantity buttons and Upgrade. The next evolution is a gold
-- column on the right (EvolvePanel; ShopController parents it into the panel on a wide window), or on a small screen its
-- EvolveBody becomes a card under the controls. ShopController binds the named controls and places and sizes everything
-- from Shared.EquipmentShopLayout.
local RS = game:GetService("ReplicatedStorage")
local Icons = require(RS.Shared.Config.HudIcons)
local Palette = require(RS.Shared.MenuPalette)
local N = require(script.Parent.Parent.NativeUI)
local Theme = require(script.Parent.Parent.MenuTheme)
local Shop = {}
Shop.LAYOUT = 9 -- bumped when the panels' controls change; an older authored copy is replaced by ShopController

-- A left label and a right value on one line (stat rows and requirements)
local function pairRow(parent: Instance, name: string, size: number, labelColor: Color3, valueColor: Color3): Frame
	local row = N.create("Frame", { Name = name, BackgroundTransparency = 1, Size = UDim2.fromOffset(200, 28), ZIndex = 5 }, parent)
	local label = Theme.label(row, "Label", "", size, labelColor)
	label.Size, label.TextTruncate = UDim2.fromScale(0.58, 1), Enum.TextTruncate.AtEnd
	local value = Theme.label(row, "Value", "", size, valueColor, nil, Enum.TextXAlignment.Right)
	value.Position, value.Size, value.TextScaled = UDim2.fromScale(0.42, 0), UDim2.fromScale(0.58, 1), true
	N.create("UITextSizeConstraint", { MinTextSize = 8, MaxTextSize = size }, value)
	return row
end

-- The evolution column: its own frame (ShopController puts it inside the panel) holding the body
local function evolvePanel(gui: ScreenGui): Frame
	local panel = N.create("Frame", { Name = "EvolvePanel", BackgroundTransparency = 1, Size = UDim2.fromOffset(245, 355), Visible = false, ZIndex = 3,
		Active = true }, gui)
	panel:SetAttribute(Theme.CUSTOM, true)
	local evolve = N.create("Frame", { Name = "EvolveBody", BackgroundTransparency = 1, Size = UDim2.fromOffset(245, 355), ZIndex = 3 }, panel)
	-- the gold card behind the name, the preview and the requirements
	local card = Theme.card(evolve, "Card", Palette.EVO_TOP, Palette.EVO_BOTTOM, 14)
	card.ZIndex = 2
	Theme.stroke(card, Palette.EVO_EDGE, 3)
	-- the EVOLUTION banner: a gold chunky tab across the card's top edge (its words are Heading, on top)
	local banner = Theme.button(evolve, "Banner", "", "gold", 16)
	banner.Active, banner.Selectable, banner.AutoButtonColor, banner.ZIndex = false, false, false, 4
	local heading = Theme.label(evolve, "Heading", "EVOLUTION", 16, Palette.NAVY, nil, Enum.TextXAlignment.Center)
	local name = Theme.label(evolve, "NextName", "", 20, Palette.NAVY, nil, Enum.TextXAlignment.Center)
	name.TextTruncate = Enum.TextTruncate.AtEnd
	local tier = Theme.label(evolve, "NextTier", "", 13, Palette.GOLD_TEXT, nil, Enum.TextXAlignment.Center)
	for _, label in { heading, name, tier } do label.ZIndex = 9 end
	Theme.well(evolve, "NextWell", Palette.GOLD_WELL_TOP, Palette.GOLD_WELL_BOTTOM, Palette.EVO_EDGE, Palette.EVO_EDGE, 0.55, 0.86).ZIndex = 4
	for index = 1, 2 do pairRow(evolve, "Req" .. index, 14, Palette.NAVY, Palette.MET) end
	Theme.bar(evolve, "ReqBar").ZIndex = 4
	Theme.bar(evolve, "ReqBar2").ZIndex = 4
	-- the captions over the two buttons, and the buttons with just their prices
	Theme.label(evolve, "CapEvolve", "EVOLVE", 12, Palette.GOLD_TEXT, nil, Enum.TextXAlignment.Center)
	Theme.label(evolve, "CapAlt", "EVOLVE NOW", 12, Palette.GOLD_TEXT, nil, Enum.TextXAlignment.Center)
	Theme.button(evolve, "Evolve", "EVOLVE", "lime", 17)
	local alt = Theme.button(evolve, "EvolveNow", "EVOLVE NOW", "gold", 17)
	alt.Visible = false
	return panel
end

function Shop.build(): ScreenGui
	local gui = N.create("ScreenGui", { Name = "GearShop", Enabled = false, ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 20,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, nil)
	gui:SetAttribute("NativePrefab", true)
	gui:SetAttribute("ShopLayout", Shop.LAYOUT)
	-- the screen behind the menu: 20% alpha
	N.create("TextButton", { Name = "Dimmer", Selectable = false, Text = "", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Palette.NAVY,
		BackgroundTransparency = .8, BorderSizePixel = 0, AutoButtonColor = false, Modal = true }, gui)
	local p = Theme.panel(gui, "Panel", UDim2.fromOffset(760, 475)) :: any
	p.AnchorPoint, p.Position = Vector2.new(.5, .5), UDim2.fromScale(.5, .5)

	-- the title ribbon, Close on the corner, the cash chip and the notice line between them
	Theme.ribbon(p, "Gear Shop", Icons.equipment)
	Theme.closeCorner(p, Icons.close)
	Theme.chip(p, "Wallet", Icons.coin, Palette.CASH_CHIP).Text = "$0"
	local footer = Theme.label(p, "Footer", "", 13, Palette.NAVY, nil, Enum.TextXAlignment.Center)
	footer.TextWrapped = true

	-- the nav button on the HUD (the owner's tile is cloned over this by ExactNavButton)
	local nav = N.button(gui, "ShopButton", "", UDim2.fromOffset(14, 100), UDim2.fromOffset(64, 64), N.CYAN)
	N.create("ImageLabel", { Name = "Icon", Image = Icons.equipment, BackgroundTransparency = 1, Size = UDim2.fromScale(.7, .6), Position = UDim2.fromScale(.15, .05), ScaleType = Enum.ScaleType.Fit, ZIndex = 5 }, nav)
	local caption = N.text(nav, "Caption", "GEAR", UDim2.fromScale(0, .66), UDim2.fromScale(1, .3))
	caption.TextXAlignment, caption.TextScaled = Enum.TextXAlignment.Center, true

	-- two tabs across the left column
	local tabs = N.create("Frame", { Name = "Tabs", BackgroundTransparency = 1, Size = UDim2.fromOffset(440, 42), ZIndex = 3 }, p)
	for _, id in { "pickaxe", "backpack" } do
		Theme.button(tabs, id .. "Tab", if id == "pickaxe" then "PICKAXES" else "BACKPACKS", if id == "pickaxe" then "tabOn" else "tabOff", 18)
	end
	for _, kind in { "pickaxe", "backpack" } do
		local screen = N.create("ScrollingFrame", { Name = kind .. "Screen", Size = UDim2.fromOffset(448, 365), BackgroundTransparency = 1, BorderSizePixel = 0,
			CanvasSize = UDim2.new(), ScrollBarThickness = 4, ScrollBarImageColor3 = Palette.BLUE_BOTTOM, ScrollingDirection = Enum.ScrollingDirection.Y, ZIndex = 3 }, p)
		-- the card behind the name and the info (drawn on small screens; on the wide layout everything sits on the body)
		local card = Theme.card(screen, "MainCard", Palette.WHITE, Palette.DETAIL_BOTTOM, 14)
		Theme.stroke(card, Palette.NAVY, 3)
		N.create("Frame", { Name = "InfoCard", BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 3 }, screen)
		local name = Theme.label(screen, "GearName", "", 24, Palette.NAVY, Theme.TITLE_FONT)
		name.TextTruncate = Enum.TextTruncate.AtEnd
		local tier = Theme.label(screen, "TierText", "", 13, Palette.SECOND)
		tier.TextTruncate = Enum.TextTruncate.AtEnd
		Theme.pill(screen, "TierPill", Palette.PILL, Palette.NAVY, Palette.NAVY, 13)
		Theme.label(screen, "CapText", "", 13, Palette.SECOND).TextTruncate = Enum.TextTruncate.AtEnd
		Theme.well(screen, "Well", Palette.WELL_TOP, Palette.WELL_BOTTOM, Palette.WELL_EDGE, Palette.WELL_EDGE, 0.6, 0.84).ZIndex = 4
		Theme.pill(screen, "LevelPill", Palette.PILL, Palette.NAVY, Palette.NAVY, 13).ZIndex = 8
		-- the highlighted level row, then what the chosen quantity adds, with dividers between the rows
		local levelRow = Theme.card(screen, "LevelRow", Palette.LEVEL_ROW, nil, 10)
		levelRow.ZIndex = 3
		Theme.stroke(levelRow, Palette.LEVEL_EDGE, 2)
		Theme.label(screen, "LevelLabel", "Level", 16, Palette.NAVY)
		local levelValue = Theme.label(screen, "LevelValue", "", 20, Palette.UP, Theme.TITLE_FONT, Enum.TextXAlignment.Right)
		levelValue.ZIndex = 5
		for i = 1, 4 do pairRow(screen, "Stat" .. i, 15, Palette.NAVY, Palette.UP) end
		for i = 1, 3 do Theme.divider(screen, "Divider" .. i) end
		Theme.label(screen, "QtyLabel", "Quantity", 16, Palette.NAVY)
		-- the strip behind the quantity choices on small screens (the wide layout has three separate buttons)
		local strip = N.create("Frame", { Name = "QtyStrip", BackgroundColor3 = Palette.STRIP, BorderSizePixel = 0, ZIndex = 3 }, screen)
		Theme.round(strip, 10)
		for i, text in { "1x", "10x", "MAX" } do Theme.button(screen, "Amount" .. i, text, if i == 1 then "lime" else "tabOff", 15) end
		Theme.button(screen, "Upgrade", "UPGRADE", "face", 17)
	end
	evolvePanel(gui)
	return gui
end

return Shop
