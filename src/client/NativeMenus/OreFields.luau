--!strict
-- Authoring for the TELEPORT menu in the cartoon light look (MenuTheme): a "Teleport" ribbon, two tabs (ORE: this
-- world's Config.Debris.Fields; WORLDS: every Config.Worlds entry), then one white card per entry in two columns. A
-- card has the entry's colour well with its icon, its name, what it pays, and on the right either a blue TRAVEL button
-- or a grey pill ("LEVEL 12", "REBIRTH 25", "YOU ARE HERE"). The panel is drawn whole (NativeUI.fitWhole).
-- FieldTravelController binds it by name: Panel.Tabs.{OreTab, WorldsTab}, Panel.{Fields, Worlds}.<Id>.{Travel, Lock}.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MenuTheme = require(script.Parent.Parent.MenuTheme)
local NativeUI = require(script.Parent.Parent.NativeUI)
local Config = require(ReplicatedStorage.Shared.Config)
local Palette = require(ReplicatedStorage.Shared.MenuPalette)

local Worlds = require(ReplicatedStorage.Shared.Worlds)
local FieldTravel = require(ReplicatedStorage.Shared.FieldTravel)

local OreFields = {}
OreFields.LAYOUT = 6 -- bumped when the controls change; FieldTravelController rebuilds an older copy

-- The WORLDS tab's cards: every world, each with its `Destination` (WorldService travels there)
function OreFields.worlds(): { any }
	local list: { any } = {}
	for _, world in Config.Worlds.List do
		table.insert(list, { Id = "World" .. world.Id, Name = world.Name, Color = world.Color, Destination = world })
	end
	return list
end

local FIELDS, WORLDS = FieldTravel.inWorld(Worlds.here().Id), OreFields.worlds()
local CARD_W, CARD_H, GAP, SIDE, TOP = 290, 78, 12, 24, 108
local ROWS = math.ceil(math.max(#FIELDS, #WORLDS) / 2)
OreFields.SIZE = Vector2.new(SIDE * 2 + CARD_W * 2 + GAP, TOP + ROWS * (CARD_H + GAP) + 34)

-- What a field's rocks pay, for its card
function OreFields.pays(field: any): string
	if field.Destination then return "" end
	local reward = field.Reward
	if reward.Kind == "Xp" then
		return "Pays XP to level up"
	elseif reward.Kind == "Ore" then
		return "Pays " .. (Config.Home.OreNames[reward.Ore] or reward.Ore) .. " ore"
	end
	return "Pays cash"
end

local function cards(panel: Frame, name: string, entries: { any })
	local list = NativeUI.create("Frame", { Name = name, BackgroundTransparency = 1, Position = UDim2.fromOffset(SIDE, TOP),
		Size = UDim2.new(1, -SIDE * 2, 0, ROWS * (CARD_H + GAP)), ZIndex = 2 }, panel)
	for index, field in entries do
		local column, row = (index - 1) % 2, (index - 1) // 2
		local card = MenuTheme.whiteCard(list, field.Id)
		card.Position, card.Size = UDim2.fromOffset(column * (CARD_W + GAP), row * (CARD_H + GAP)), UDim2.fromOffset(CARD_W, CARD_H)

		local well = MenuTheme.card(card, "Swatch", field.Color, field.Color:Lerp(Palette.NAVY, 0.25), 12)
		well.Position, well.Size, well.ZIndex = UDim2.fromOffset(10, 10), UDim2.fromOffset(CARD_H - 20, CARD_H - 20), 3
		MenuTheme.stroke(well, Palette.NAVY, 2)
		MenuTheme.icon(well, "Icon", if field.Destination then "meteor" else "ore", UDim2.fromScale(0.12, 0.12), UDim2.fromScale(0.76, 0.76))

		local title = MenuTheme.label(card, "Name", string.upper(field.Name), 20, Palette.NAVY, MenuTheme.TITLE_FONT)
		-- a world card has no "pays" line, so its name sits in the middle
		title.Position = UDim2.fromOffset(CARD_H, if field.Destination then (CARD_H - 26) // 2 else 12)
		title.Size = UDim2.fromOffset(CARD_W - CARD_H - 110, 26)
		title.TextScaled = true
		NativeUI.create("UITextSizeConstraint", { MinTextSize = 10, MaxTextSize = 20 }, title)
		local pays = MenuTheme.label(card, "Pays", OreFields.pays(field), 14, Palette.SECOND)
		pays.Position, pays.Size = UDim2.fromOffset(CARD_H, 42), UDim2.fromOffset(CARD_W - CARD_H - 110, 20)
		pays.TextScaled = true
		NativeUI.create("UITextSizeConstraint", { MinTextSize = 9, MaxTextSize = 14 }, pays)

		local travel = MenuTheme.button(card, "Travel", "TRAVEL", "blue", 18)
		travel.Position, travel.Size = UDim2.new(1, -106, 0.5, -22), UDim2.fromOffset(96, 44)
		local lock = MenuTheme.pill(card, "Lock", Palette.GREY_TOP, Palette.NAVY, Palette.NAVY, 15)
		lock.Position, lock.Size, lock.Visible = UDim2.new(1, -106, 0.5, -15), UDim2.fromOffset(96, 30), false
	end
	return list
end

function OreFields.build(): ScreenGui
	local gui, panel = MenuTheme.menu("OreFieldsMenu", "Teleport", "ore", OreFields.SIZE, OreFields.LAYOUT)
	gui.DisplayOrder = 28

	local tabs = NativeUI.create("Frame", { Name = "Tabs", BackgroundTransparency = 1, Position = UDim2.fromOffset(SIDE, 52),
		Size = UDim2.fromOffset(CARD_W, 42), ZIndex = 3 }, panel)
	NativeUI.create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 10),
		SortOrder = Enum.SortOrder.LayoutOrder }, tabs)
	for order, id in { "Ore", "Worlds" } do
		local tab = MenuTheme.button(tabs, id .. "Tab", string.upper(id), if order == 1 then "tabOn" else "tabOff", 18)
		tab.Size, tab.LayoutOrder = UDim2.fromOffset(130, 42), order
	end

	cards(panel, "Fields", FIELDS)
	cards(panel, "Worlds", WORLDS).Visible = false

	local footer = MenuTheme.label(panel, "Footer", "", 13, Palette.SECOND, nil, Enum.TextXAlignment.Center)
	footer.Position, footer.Size = UDim2.new(0, SIDE, 1, -36), UDim2.new(1, -SIDE * 2, 0, 20)
	return gui
end

return OreFields
