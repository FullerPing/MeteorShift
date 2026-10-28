--!strict
-- Authoring for the Colony Perks panel (Config.Perks) in the cartoon light look (MenuTheme), laid out as the owner's mockup
-- (Craterworks Menu Redesign, 2026-10-15): a "Colony Perks" ribbon, a REBIRTH back button and the shard chip on the top
-- right, a line about perks, then one card per perk: the owner's icon on a well, the perk's name over a dot per level, what
-- it does now and next, and a lime buy button with the shard price. PerksController binds the cards by name. It opens
-- from the PERKS button on the Rebirth panel.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Palette = require(ReplicatedStorage.Shared.MenuPalette)
local MenuTheme = require(script.Parent.Parent.MenuTheme)
local NativeUI = require(script.Parent.Parent.NativeUI)
local Perks = {}

Perks.LAYOUT = 4 -- bumped when the controls change; PerksController rebuilds an older copy
Perks.SIZE = Vector2.new(860, 572)
Perks.ROW_HEIGHT = 80
-- the owner's icon for each perk (Config.HudIcons)
Perks.ICONS = { headStart = "equipment", stationMemory = "foundry", efficientLine = "bars", offlineTraining = "ore", petBond = "pets" }

function Perks.build(): ScreenGui
	local gui, panel = MenuTheme.menu("ColonyPerks", "Colony Perks", "crystal", Perks.SIZE, Perks.LAYOUT)
	gui.DisplayOrder = 28

	-- top right, left of Close: back to Rebirth and the shards you have
	local wallet = MenuTheme.chip(panel, "Wallet", Config.HudIcons.crystal, Palette.SHARD_CHIP)
	wallet.AnchorPoint, wallet.Position, wallet.Size = Vector2.new(1, 0), UDim2.new(1, -56, 0, 12), UDim2.fromOffset(120, 32)
	local back = MenuTheme.button(panel, "Back", "REBIRTH", "tabOff", 15)
	back.AnchorPoint, back.Position, back.Size = Vector2.new(1, 0), UDim2.new(1, -184, 0, 8), UDim2.fromOffset(130, 40)
	MenuTheme.withIcon(back, "rebirth", 22)

	local hint = MenuTheme.label(panel, "Footer", "", 14, Palette.SECOND)
	hint.Position, hint.Size, hint.TextTruncate = UDim2.fromOffset(22, 54), UDim2.new(1, -44, 0, 22), Enum.TextTruncate.AtEnd

	local body = NativeUI.create("ScrollingFrame", {
		Name = "Body", Position = UDim2.fromOffset(18, 82), Size = UDim2.new(1, -36, 1, -82 - MenuTheme.LIP - 12),
		BackgroundTransparency = 1, BorderSizePixel = 0,
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y, ScrollBarThickness = 4,
		ScrollBarImageColor3 = Palette.BLUE_BOTTOM, VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
		ElasticBehavior = Enum.ElasticBehavior.WhenScrollable, ZIndex = 4,
	}, panel)
	NativeUI.create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, body)
	NativeUI.create("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4) }, body)

	for order, id in Config.Perks.Order do
		local def = Config.Perks.List[id]
		local card = MenuTheme.box(body, id .. "Row")
		card.LayoutOrder, card.Size = order, UDim2.new(1, 0, 0, Perks.ROW_HEIGHT)
		local well = MenuTheme.iconWell(card, "Well", Perks.ICONS[id] or "crystal")
		well.Position, well.Size, well.ZIndex = UDim2.new(0, 10, 0.5, -32), UDim2.fromOffset(64, 64), 3
		local name = MenuTheme.label(card, "Name", def.Name, 18, Palette.NAVY, MenuTheme.TITLE_FONT)
		name.Position, name.Size, name.TextTruncate = UDim2.fromOffset(88, 14), UDim2.fromOffset(176, 24), Enum.TextTruncate.AtEnd
		-- a dot per level, lime once bought (PerksController)
		local dots = NativeUI.create("Frame", { Name = "Dots", Position = UDim2.fromOffset(88, 46), Size = UDim2.fromOffset(176, 14), BackgroundTransparency = 1, ZIndex = 4 }, card)
		NativeUI.create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, dots)
		for level = 1, #def.Costs do MenuTheme.dot(dots, "Dot" .. level, false).LayoutOrder = level end
		-- what it does now and next; under it, how many shards you still need (rich text, PerksController)
		local text = MenuTheme.label(card, "Text", "", 14, Palette.NAVY)
		text.Position, text.Size = UDim2.fromOffset(276, 8), UDim2.new(1, -276 - 158, 1, -16)
		text.TextWrapped, text.RichText, text.TextScaled = true, true, true
		NativeUI.create("UITextSizeConstraint", { MinTextSize = 10, MaxTextSize = 15 }, text)
		local buy = MenuTheme.button(card, "Buy", "BUY", "lime", 18)
		buy.AnchorPoint, buy.Position, buy.Size = Vector2.new(1, 0.5), UDim2.new(1, -12, 0.5, 0), UDim2.fromOffset(132, 52)
		MenuTheme.withIcon(buy, "crystal", 24)
	end
	return gui
end

return Perks
