--!strict
-- Authoring for the offer preview (OfferController): the quick look at what a pass or product gives before the Roblox
-- prompt. Cartoon light look (MenuTheme): a ribbon with the offer's name, a big icon well on the left, a tick list of
-- Highlights on the right, a gold BUY button showing the Robux price, and a footer ("Yours forever" for a pass). Drawn
-- whole (NativeUI.fitWhole). OfferController fills it by name: Panel.{IconWell.ItemIcon, Lines.Line1..LINES, Buy, Footer}.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MenuTheme = require(script.Parent.Parent.MenuTheme)
local NativeUI = require(script.Parent.Parent.NativeUI)
local Palette = require(ReplicatedStorage.Shared.MenuPalette)

local OfferPreview = {}
OfferPreview.LAYOUT = 1 -- bumped when the controls change; OfferController rebuilds an older copy
OfferPreview.SIZE = Vector2.new(560, 330)
OfferPreview.LINES = 4

function OfferPreview.build(): ScreenGui
	local gui, panel = MenuTheme.menu("OfferPreviewMenu", "Offer", "store", OfferPreview.SIZE, OfferPreview.LAYOUT)
	gui.DisplayOrder = 30
	-- offer names run long ("Starter Value Pack"): a wider ribbon keeps them on one line
	;(panel:FindFirstChild("Ribbon") :: Frame).Size = UDim2.fromOffset(400, 66)

	local well = MenuTheme.card(panel, "IconWell", Palette.GOLD_TOP, Palette.GOLD_BOTTOM, 18)
	well.Position, well.Size, well.ZIndex = UDim2.fromOffset(28, 66), UDim2.fromOffset(170, 170), 3
	MenuTheme.stroke(well, Palette.NAVY, 3)
	MenuTheme.gloss(well, 0.45, 16)
	MenuTheme.icon(well, "ItemIcon", "store", UDim2.fromScale(0.12, 0.12), UDim2.fromScale(0.76, 0.76))

	local lines = NativeUI.create("Frame", { Name = "Lines", BackgroundTransparency = 1, Position = UDim2.fromOffset(220, 66),
		Size = UDim2.fromOffset(312, 170), ZIndex = 3 }, panel)
	NativeUI.create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Center }, lines)
	for index = 1, OfferPreview.LINES do
		local row = NativeUI.create("Frame", { Name = "Line" .. index, LayoutOrder = index, BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 36), ZIndex = 3 }, lines)
		local tick = MenuTheme.card(row, "Tick", Palette.LIME_TOP, Palette.LIME_BOTTOM, 6)
		-- a plain lime bullet: there is no tick in Config.HudIcons and FredokaOne has no check glyph
		tick.Position, tick.Size, tick.ZIndex = UDim2.fromOffset(4, 10), UDim2.fromOffset(16, 16), 4
		MenuTheme.stroke(tick, Palette.NAVY, 2)
		local text = MenuTheme.label(row, "Text", "", 18, Palette.NAVY, MenuTheme.TITLE_FONT)
		text.Position, text.Size, text.TextWrapped, text.TextScaled = UDim2.fromOffset(30, 0), UDim2.new(1, -34, 1, 0), true, true
		NativeUI.create("UITextSizeConstraint", { MinTextSize = 10, MaxTextSize = 18 }, text)
	end

	local buy = MenuTheme.button(panel, "Buy", "BUY", "gold", 26)
	buy.Position, buy.Size = UDim2.fromOffset(28, 250), UDim2.new(1, -56, 0, 56)

	local footer = MenuTheme.label(panel, "Footer", "", 13, Palette.SECOND, nil, Enum.TextXAlignment.Center)
	footer.Position, footer.Size = UDim2.new(0, 28, 1, -22), UDim2.new(1, -56, 0, 16)
	return gui
end

return OfferPreview
