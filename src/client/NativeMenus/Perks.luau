--!strict
-- Authoring for the Colony Perks panel (Config.Perks) in the cartoon light look (MenuTheme): a "Colony Perks" ribbon,
-- a shard wallet chip, then one white card per perk with its name, a level pill, what the next level does, its price in
-- shards and a lime BUY button. The runtime binds the cards by name (PerksController). It is opened from a PERKS button
-- on the Rebirth panel.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Palette = require(ReplicatedStorage.Shared.MenuPalette)
local MenuTheme = require(script.Parent.Parent.MenuTheme)
local NativeUI = require(script.Parent.Parent.NativeUI)
local Perks = {}

Perks.LAYOUT = 2 -- bumped when the controls change; PerksController rebuilds an older copy
Perks.SIZE = Vector2.new(440, 560)
Perks.ROW_HEIGHT = 96

function Perks.build(): ScreenGui
	local gui, panel = MenuTheme.menu("ColonyPerks", "Colony Perks", "crystal", Perks.SIZE, Perks.LAYOUT)
	gui.DisplayOrder = 28

	local wallet = MenuTheme.chip(panel, "Wallet", Config.HudIcons.crystal, Palette.SHARD_CHIP)
	wallet.Position, wallet.Size = UDim2.fromOffset(16, 52), UDim2.fromOffset(200, 34)

	local body = NativeUI.create("ScrollingFrame", {
		Name = "Body", Position = UDim2.fromOffset(14, 96), Size = UDim2.new(1, -28, 1, -144),
		BackgroundTransparency = 1, BorderSizePixel = 0,
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y, ScrollBarThickness = 4,
		ScrollBarImageColor3 = Palette.BLUE_BOTTOM, VerticalScrollBarInset = Enum.ScrollBarInset.Always,
		ElasticBehavior = Enum.ElasticBehavior.WhenScrollable, ZIndex = 4,
	}, panel)
	NativeUI.create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, body)
	NativeUI.create("UIPadding", { PaddingTop = UDim.new(0, 3), PaddingLeft = UDim.new(0, 3) }, body)

	for order, id in Config.Perks.Order do
		local card = MenuTheme.whiteCard(body, id .. "Row", 12)
		card.LayoutOrder, card.Size = order, UDim2.new(1, -14, 0, Perks.ROW_HEIGHT)
		local name = MenuTheme.label(card, "Name", Config.Perks.List[id].Name, 19, Palette.NAVY, MenuTheme.TITLE_FONT)
		name.Position, name.Size, name.TextTruncate = UDim2.fromOffset(12, 6), UDim2.new(1, -230, 0, 26), Enum.TextTruncate.AtEnd
		local level = MenuTheme.label(card, "Level", "", 14, Palette.SECOND, nil, Enum.TextXAlignment.Right)
		level.Position, level.Size = UDim2.new(1, -226, 0, 8), UDim2.fromOffset(104, 22)
		local text = MenuTheme.label(card, "Text", "", 15, Palette.SECOND)
		text.Position, text.Size = UDim2.fromOffset(12, 34), UDim2.new(1, -140, 0, 56)
		text.TextWrapped, text.TextYAlignment = true, Enum.TextYAlignment.Top
		-- the longer perk lines shrink to stay inside the card instead of being cut off
		text.TextScaled = true
		NativeUI.create("UITextSizeConstraint", { MinTextSize = 10, MaxTextSize = 15 }, text)
		-- the price in shards over the button: the owner's crystal and the amount
		local price = MenuTheme.label(card, "Price", "", 17, Palette.NAVY, MenuTheme.TITLE_FONT, Enum.TextXAlignment.Right)
		price.Position, price.Size = UDim2.new(1, -118, 0, 6), UDim2.fromOffset(78, 26)
		MenuTheme.icon(card, "PriceIcon", "crystal", UDim2.new(1, -36, 0, 5), UDim2.fromOffset(26, 26))
		local buy = MenuTheme.button(card, "Buy", "BUY", "lime", 18)
		buy.Position, buy.Size = UDim2.new(1, -118, 0, 38), UDim2.fromOffset(106, 50)
	end

	local footer = MenuTheme.label(panel, "Footer", "", 14, Palette.SECOND, nil, Enum.TextXAlignment.Center)
	footer.Position, footer.Size, footer.TextWrapped = UDim2.new(0, 16, 1, -44), UDim2.new(1, -32, 0, 30), true
	return gui
end

return Perks
