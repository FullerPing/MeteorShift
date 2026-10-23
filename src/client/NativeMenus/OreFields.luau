--!strict
-- Authoring for the ORE menu (Config.Debris.Fields) in the cartoon light look (MenuTheme): an "Ore Fields" ribbon,
-- a hint, then one white card per field in two columns. A card has the field's colour well with the ore icon, its
-- name, what its rocks pay, and on the right either a blue TRAVEL button or a grey lock pill ("LEVEL 12"). The panel is
-- drawn whole (NativeUI.fitWhole). FieldTravelController binds it by name: Panel.Fields.<Id>.{Travel, Lock, Name, Pays}.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MenuTheme = require(script.Parent.Parent.MenuTheme)
local NativeUI = require(script.Parent.Parent.NativeUI)
local Config = require(ReplicatedStorage.Shared.Config)
local Palette = require(ReplicatedStorage.Shared.MenuPalette)

local OreFields = {}
OreFields.LAYOUT = 1 -- bumped when the controls change; FieldTravelController rebuilds an older copy

local CARD_W, CARD_H, GAP, SIDE, TOP = 290, 78, 12, 24, 92
local ROWS = math.ceil(#Config.Debris.Fields / 2)
OreFields.SIZE = Vector2.new(SIDE * 2 + CARD_W * 2 + GAP, TOP + ROWS * (CARD_H + GAP) + 34)

-- What a field's rocks pay, for its card
function OreFields.pays(field: any): string
	local reward = field.Reward
	if reward.Kind == "Ore" then
		return "Pays " .. (Config.Home.OreNames[reward.Ore] or reward.Ore) .. " ore"
	end
	return "Pays cash"
end

function OreFields.build(): ScreenGui
	local gui, panel = MenuTheme.menu("OreFieldsMenu", "Ore Fields", "ore", OreFields.SIZE, OreFields.LAYOUT)
	gui.DisplayOrder = 28

	local hint = MenuTheme.label(panel, "Hint", "", 16, Palette.NAVY)
	hint.Position, hint.Size, hint.TextWrapped = UDim2.fromOffset(SIDE, 56), UDim2.new(1, -SIDE * 2, 0, 26), true

	local list = NativeUI.create("Frame", { Name = "Fields", BackgroundTransparency = 1, Position = UDim2.fromOffset(SIDE, TOP),
		Size = UDim2.new(1, -SIDE * 2, 0, ROWS * (CARD_H + GAP)), ZIndex = 2 }, panel)
	for index, field in Config.Debris.Fields do
		local column, row = (index - 1) % 2, (index - 1) // 2
		local card = MenuTheme.whiteCard(list, field.Id)
		card.Position, card.Size = UDim2.fromOffset(column * (CARD_W + GAP), row * (CARD_H + GAP)), UDim2.fromOffset(CARD_W, CARD_H)

		local well = MenuTheme.card(card, "Swatch", field.Color, field.Color:Lerp(Palette.NAVY, 0.25), 12)
		well.Position, well.Size, well.ZIndex = UDim2.fromOffset(10, 10), UDim2.fromOffset(CARD_H - 20, CARD_H - 20), 3
		MenuTheme.stroke(well, Palette.NAVY, 2)
		MenuTheme.icon(well, "Icon", "ore", UDim2.fromScale(0.12, 0.12), UDim2.fromScale(0.76, 0.76))

		local name = MenuTheme.label(card, "Name", string.upper(field.Name), 20, Palette.NAVY, MenuTheme.TITLE_FONT)
		name.Position, name.Size = UDim2.fromOffset(CARD_H, 12), UDim2.fromOffset(CARD_W - CARD_H - 110, 26)
		name.TextScaled = true
		NativeUI.create("UITextSizeConstraint", { MinTextSize = 10, MaxTextSize = 20 }, name)
		local pays = MenuTheme.label(card, "Pays", OreFields.pays(field), 14, Palette.SECOND)
		pays.Position, pays.Size = UDim2.fromOffset(CARD_H, 42), UDim2.fromOffset(CARD_W - CARD_H - 110, 20)

		local travel = MenuTheme.button(card, "Travel", "TRAVEL", "blue", 18)
		travel.Position, travel.Size = UDim2.new(1, -106, 0.5, -22), UDim2.fromOffset(96, 44)
		local lock = MenuTheme.pill(card, "Lock", Palette.GREY_TOP, Palette.NAVY, Palette.NAVY, 15)
		lock.Position, lock.Size, lock.Visible = UDim2.new(1, -106, 0.5, -15), UDim2.fromOffset(96, 30), false
	end

	local footer = MenuTheme.label(panel, "Footer", "", 13, Palette.SECOND, nil, Enum.TextXAlignment.Center)
	footer.Position, footer.Size = UDim2.new(0, SIDE, 1, -36), UDim2.new(1, -SIDE * 2, 0, 20)
	return gui
end

return OreFields
