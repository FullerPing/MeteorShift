--!strict
-- The Pets menu, from the owner's "cartoon light" mockup (2026-10-13; MenuTheme / Shared.MenuPalette), the Gear Shop's twin:
-- a blue "Pets" ribbon, Close on the corner, the Core Shards chip, three tabs, then MY PETS (the equipped count, the TEAM BOOST
-- strip and a grid of pet cards) or PET INDEX (every pet, found or not) or BOOSTS (every pet role: your total, its cap, what it does), the selected pet's column on the right (a blue name
-- banner, a rarity pill, the preview, level and XP, the perks) with its action under it, and a hint strip at the bottom.
-- Eggs hatch at the Hatchery's prompts (PetService). PetsController binds the named controls and places everything from
-- Shared.PetsLayout.
local RS = game:GetService("ReplicatedStorage")
local Config = require(RS.Shared.Config)
local Icons = require(RS.Shared.Config.HudIcons)
local Palette = require(RS.Shared.MenuPalette)
local PetsLayout = require(RS.Shared.PetsLayout)
local N = require(script.Parent.Parent.NativeUI)
local Theme = require(script.Parent.Parent.MenuTheme)
local Pets = {}
Pets.LAYOUT = 7 -- bumped when the panel's controls change; an older authored copy is replaced by PetsController

-- One pet tile: a white card with a preview well tinted by rarity, the name and level under it, a lime "EQUIPPED" tab on its
-- top edge while it is out, a blue ring while it is selected and a "?" cover for pets you have not found.
local function petCard(parent: Instance, id: string, order: number)
	local card = N.create("Frame", { Name = "pet_" .. id, LayoutOrder = order, Size = UDim2.fromOffset(136, 168), BackgroundColor3 = Palette.WHITE,
		BorderSizePixel = 0, ZIndex = 3 }, parent)
	Theme.round(card, 14)
	Theme.stroke(card, Palette.NAVY, 3)
	local well = Theme.well(card, "Well", Palette.WELL_TOP, Palette.WELL_BOTTOM, Palette.WELL_EDGE, Palette.WELL_EDGE, 0.6, 0.84)
	well.Position, well.Size, well.ZIndex = UDim2.fromOffset(8, 10), UDim2.new(1, -16, 1, -64), 4
	local name = Theme.label(card, "PetLabel", "", 18, Palette.NAVY, nil, Enum.TextXAlignment.Center)
	name.Position, name.Size, name.TextTruncate, name.TextScaled = UDim2.new(0, 4, 1, -52), UDim2.new(1, -8, 0, 24), Enum.TextTruncate.AtEnd, true
	N.create("UITextSizeConstraint", { MinTextSize = 10, MaxTextSize = 18 }, name)
	local level = Theme.label(card, "Level", "", 14, Palette.SECOND, nil, Enum.TextXAlignment.Center)
	level.Position, level.Size = UDim2.new(0, 4, 1, -28), UDim2.new(1, -8, 0, 18)
	local badge = Theme.card(card, "Equipped", Palette.LIME_TOP, Palette.LIME_BOTTOM, 8)
	badge.AnchorPoint, badge.Position, badge.Size, badge.Visible, badge.ZIndex = Vector2.new(0.5, 0.5), UDim2.new(0.5, 0, 0, 2), UDim2.fromOffset(104, 22), false, 9
	Theme.stroke(badge, Palette.NAVY, 2)
	local tick = Theme.label(badge, "Label", "✓ EQUIPPED", 13, Palette.NAVY, nil, Enum.TextXAlignment.Center)
	tick.Size, tick.ZIndex = UDim2.fromScale(1, 1), 10
	local lock = Theme.card(card, "Lock", Palette.UNSEEN, nil, 12)
	lock.Position, lock.Size, lock.Visible, lock.ZIndex = UDim2.fromOffset(8, 10), UDim2.new(1, -16, 1, -64), false, 9
	local mark = Theme.label(lock, "Mark", "?", 44, Palette.SECOND, nil, Enum.TextXAlignment.Center)
	mark.Size, mark.ZIndex = UDim2.fromScale(1, 1), 10
	local ring = N.create("Frame", { Name = "SelectRing", Position = UDim2.fromOffset(-5, -5), Size = UDim2.new(1, 10, 1, 10), BackgroundTransparency = 1,
		Visible = false, ZIndex = 11 }, card)
	Theme.round(ring, 18)
	Theme.stroke(ring, Palette.BLUE_BOTTOM, 3)
	N.create("TextButton", { Name = "Select", Text = "", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 12 }, card)
	return card
end

local function petGrid(parent: Instance, name: string, ids: { string }): ScrollingFrame
	local list = N.create("ScrollingFrame", { Name = name, BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromOffset(300, 200),
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y, ScrollBarThickness = 4,
		ScrollBarImageColor3 = Palette.BLUE_BOTTOM, ZIndex = 3 }, parent)
	N.create("UIGridLayout", { CellSize = UDim2.fromOffset(136, 168), CellPadding = UDim2.fromOffset(8, 12), SortOrder = Enum.SortOrder.LayoutOrder }, list)
	-- room for the selection ring and the EQUIPPED tab, which sit outside each card
	N.create("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingTop = UDim.new(0, 14), PaddingRight = UDim.new(0, 6), PaddingBottom = UDim.new(0, 10) }, list)
	for order, id in ids do petCard(list, id, order) end
	return list
end

-- A perk line in the detail: the role on the left, its value on the right
local function perkRow(parent: Instance, index: number)
	local row = N.create("Frame", { Name = "Perk" .. index, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 22), ZIndex = 4 }, parent)
	local role = Theme.label(row, "Role", "", 15, Palette.NAVY)
	role.Size = UDim2.fromScale(0.6, 1)
	local value = Theme.label(row, "Value", "", 15, Palette.UP, nil, Enum.TextXAlignment.Right)
	value.Position, value.Size = UDim2.fromScale(0.4, 0), UDim2.fromScale(0.6, 1)
end

function Pets.build(): ScreenGui
	local gui = N.create("ScreenGui", { Name = "PetsMenu", Enabled = false, ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 20,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, nil)
	gui:SetAttribute("NativePrefab", true)
	gui:SetAttribute("PetsLayout", Pets.LAYOUT)
	N.create("TextButton", { Name = "Dimmer", Selectable = false, Text = "", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Palette.NAVY,
		BackgroundTransparency = .8, BorderSizePixel = 0, AutoButtonColor = false, Modal = true, Visible = false }, gui)
	local p = Theme.panel(gui, "Panel", UDim2.fromOffset(760, 475)) :: any
	p.Visible = false
	local nav = N.button(gui, "PetsButton", "", UDim2.fromOffset(14, 170), UDim2.fromOffset(64, 64), N.GREEN)
	N.create("ImageLabel", { Name = "Icon", Image = Icons.pets, BackgroundTransparency = 1, Size = UDim2.fromScale(.7, .6), Position = UDim2.fromScale(.15, .05), ScaleType = Enum.ScaleType.Fit, ZIndex = 5 }, nav)

	Theme.ribbon(p, "Pets", Icons.pets)
	Theme.closeCorner(p, Icons.close)
	Theme.chip(p, "Wallet", Icons.crystal, Palette.SHARD_CHIP).Text = "0"
	local tabs = N.create("Frame", { Name = "Tabs", BackgroundTransparency = 1, Size = UDim2.fromOffset(440, 42), ZIndex = 3 }, p)
	for _, id in { "pets", "index", "boosts" } do
		Theme.button(tabs, id .. "Tab", if id == "pets" then "MY PETS" elseif id == "index" then "PET INDEX" else "BOOSTS", if id == "pets" then "tabOn" else "tabOff", 18)
	end

	-- MY PETS: the heading and equipped count, the TEAM BOOST strip, then everything you own
	local petsScreen = N.create("Frame", { Name = "PetsScreen", BackgroundTransparency = 1, Size = UDim2.fromOffset(400, 300), ZIndex = 3 }, p)
	Theme.label(petsScreen, "Heading", "Your pets!", 24, Palette.NAVY, Theme.TITLE_FONT)
	local count = Theme.pill(petsScreen, "EquipPill", Palette.EQUIP_PILL, Palette.EQUIP_EDGE, Palette.NAVY, 14)
	count.Size = UDim2.fromOffset(126, 24)
	local boost = Theme.card(petsScreen, "BonusBar", Palette.BOOST, nil, 10)
	boost.ZIndex = 3
	Theme.stroke(boost, Palette.BOOST_EDGE, 2)
	local boostLabel = Theme.label(boost, "Label", "TEAM BOOST", 13, Palette.BOOST_TEXT)
	boostLabel.Position, boostLabel.Size = UDim2.fromOffset(12, 0), UDim2.new(0, 110, 1, 0)
	local bonuses = Theme.label(boost, "Bonuses", "", 16, Palette.UP)
	bonuses.Position, bonuses.Size, bonuses.RichText, bonuses.TextTruncate = UDim2.fromOffset(122, 0), UDim2.new(1, -130, 1, 0), true, Enum.TextTruncate.AtEnd
	petGrid(petsScreen, "List", (function() local ids = {} for _, def in Config.Pets.List do table.insert(ids, def.Id) end return ids end)())
	local empty = Theme.label(petsScreen, "Empty", "No pets yet. Hatch an egg at the Hatchery in town!", 16, Palette.SECOND, nil, Enum.TextXAlignment.Center)
	empty.TextWrapped = true

	-- PET INDEX: every pet in the game, found or not
	local index = N.create("Frame", { Name = "IndexScreen", BackgroundTransparency = 1, Size = UDim2.fromOffset(400, 300), ZIndex = 3 }, p)
	Theme.label(index, "Heading", "Pet index", 24, Palette.NAVY, Theme.TITLE_FONT)
	Theme.label(index, "Progress", "DISCOVERED 0/0", 14, Palette.SECOND, nil, Enum.TextXAlignment.Right)
	Theme.bar(index, "ProgressBar", Palette.LIME_BOTTOM)
	petGrid(index, "List", PetsLayout.indexOrder())

	-- BOOSTS: one row per pet role (PetsLayout.boostRows), filled by PetsController
	local boosts = N.create("Frame", { Name = "BoostsScreen", BackgroundTransparency = 1, Size = UDim2.fromOffset(400, 300), ZIndex = 3 }, p)
	local boostList = N.create("ScrollingFrame", { Name = "List", BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y, ScrollBarThickness = 4,
		ScrollBarImageColor3 = Palette.BLUE_BOTTOM, ZIndex = 3 }, boosts)
	N.create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, boostList)
	N.create("UIPadding", { PaddingLeft = UDim.new(0, 4), PaddingTop = UDim.new(0, 4), PaddingRight = UDim.new(0, 10), PaddingBottom = UDim.new(0, 8) }, boostList)
	for order, role in Config.Pets.RoleOrder do
		local row = Theme.card(boostList, "boost_" .. role, Palette.WHITE, nil, 12)
		row.LayoutOrder, row.Size, row.ZIndex = order, UDim2.new(1, 0, 0, 74), 3
		Theme.stroke(row, Palette.WELL_EDGE, 2)
		local name = Theme.label(row, "RoleName", "", 18, Palette.NAVY, Theme.TITLE_FONT)
		name.Position, name.Size = UDim2.fromOffset(12, 6), UDim2.new(0.5, -12, 0, 24)
		local total = Theme.label(row, "Total", "", 16, Palette.UP, nil, Enum.TextXAlignment.Right)
		total.Position, total.Size, total.RichText = UDim2.new(0.5, 0, 0, 6), UDim2.new(0.5, -12, 0, 24), true
		local bar = Theme.bar(row, "Bar", Palette.LIME_BOTTOM)
		bar.Position, bar.Size = UDim2.fromOffset(12, 32), UDim2.new(1, -24, 0, 8)
		local text = Theme.label(row, "Text", "", 14, Palette.SECOND)
		text.Position, text.Size, text.RichText, text.TextTruncate = UDim2.fromOffset(12, 44), UDim2.new(1, -24, 0, 24), true, Enum.TextTruncate.AtEnd
	end
	-- under the roles: the relics (Config.Relics), found or not, and your Relic Fragments
	local relicHead = Theme.label(boostList, "RelicsHeader", "RELICS", 20, Palette.NAVY, Theme.TITLE_FONT)
	relicHead.LayoutOrder, relicHead.Size, relicHead.RichText = 100, UDim2.new(1, 0, 0, 34), true
	for order, relic in Config.Relics.List do
		local row = Theme.card(boostList, "relic_" .. relic.Id, Palette.WHITE, nil, 12)
		row.LayoutOrder, row.Size, row.ZIndex = 100 + order, UDim2.new(1, 0, 0, 52), 3
		Theme.stroke(row, Palette.WELL_EDGE, 2)
		local name = Theme.label(row, "RelicName", relic.Name, 17, Palette.NAVY, Theme.TITLE_FONT)
		name.Position, name.Size = UDim2.fromOffset(12, 4), UDim2.new(0.6, -12, 0, 22)
		local value = Theme.label(row, "Value", "", 15, Palette.UP, nil, Enum.TextXAlignment.Right)
		value.Position, value.Size = UDim2.new(0.6, 0, 0, 4), UDim2.new(0.4, -12, 0, 22)
		local blurb = Theme.label(row, "Blurb", "", 13, Palette.SECOND)
		blurb.Position, blurb.Size, blurb.TextTruncate = UDim2.fromOffset(12, 26), UDim2.new(1, -24, 0, 20), Enum.TextTruncate.AtEnd
	end

	-- under the grid: where more slots come from, and the hint strip that also carries notices
	Theme.label(p, "MoreSlots", "More slots: Rebirths · Pet Bond · Extra Pet Slot", 13, Palette.MUTED)
	local hint = Theme.card(p, "Hint", Palette.INFO, nil, 10)
	hint.ZIndex = 3
	local dot = Theme.card(hint, "Dot", Palette.INFO_DOT, nil, 100)
	dot.AnchorPoint, dot.Position, dot.Size, dot.ZIndex = Vector2.new(0, 0.5), UDim2.new(0, 10, 0.5, 0), UDim2.fromOffset(20, 20), 4
	local i = Theme.label(dot, "I", "i", 15, Palette.WHITE, nil, Enum.TextXAlignment.Center)
	i.Size, i.ZIndex = UDim2.fromScale(1, 1), 5
	local footer = Theme.label(hint, "Footer", "", 16, Palette.NAVY)
	footer.Position, footer.Size, footer.TextWrapped, footer.TextScaled = UDim2.fromOffset(40, 0), UDim2.new(1, -48, 1, 0), true, true
	N.create("UITextSizeConstraint", { MinTextSize = 10, MaxTextSize = 16 }, footer)

	-- Detail: the selected pet. A blue name banner over a pale card; the body scrolls where the column is short.
	local detail = N.create("Frame", { Name = "Detail", Size = UDim2.fromOffset(245, 296), BackgroundTransparency = 1, ZIndex = 3 }, p)
	local card = Theme.card(detail, "Card", Palette.DETAIL_TOP, Palette.DETAIL_BOTTOM, 14)
	card.ZIndex = 2
	Theme.stroke(card, Palette.WELL_EDGE, 3)
	local banner = Theme.button(detail, "Banner", "", "blue", 20)
	banner.Active, banner.Selectable, banner.ZIndex = false, false, 4
	local name = Theme.label(detail, "PetName", "", 20, Palette.WHITE, Theme.TITLE_FONT, Enum.TextXAlignment.Center)
	name.TextScaled, name.ZIndex = true, 9
	N.create("UITextSizeConstraint", { MinTextSize = 10, MaxTextSize = 20 }, name)
	Theme.ink(name, true, 2.5)
	local body = N.create("ScrollingFrame", { Name = "Body", BackgroundTransparency = 1, BorderSizePixel = 0, CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 4, ScrollBarImageColor3 = Palette.BLUE_BOTTOM,
		ScrollingDirection = Enum.ScrollingDirection.Y, ZIndex = 3 }, detail)
	Theme.pill(body, "Rarity", Palette.PREMIUM, Palette.PREMIUM_EDGE, Palette.PREMIUM_TEXT, 13)
	Theme.well(body, "PreviewWell", Palette.WELL_TOP, Palette.WELL_BOTTOM, Palette.WELL_EDGE, Palette.WELL_EDGE, 0.6, 0.86)
	Theme.label(body, "Level", "", 15, Palette.NAVY)
	Theme.label(body, "XpText", "", 13, Palette.SECOND, nil, Enum.TextXAlignment.Right)
	Theme.bar(body, "XpBar", Palette.XP_FILL)
	for n = 1, 3 do perkRow(body, n) end
	Theme.button(body, "FuseButton", "FUSE", "gold", 14) -- Config.Pets.Fuse: copies and Relic Fragments make it Fused
	Theme.button(body, "HowButton", "How bonuses work ▼", "tabOff", 14)
	local perkText = Theme.label(body, "PerkText", "", 14, Palette.NAVY)
	perkText.RichText, perkText.TextWrapped, perkText.AutomaticSize, perkText.TextYAlignment = true, true, Enum.AutomaticSize.Y, Enum.TextYAlignment.Top
	Theme.button(p, "Action", "", "lime", 20)
	Theme.button(p, "PutAway", "PUT AWAY", "red", 20).Visible = false -- beside EQUIP +1 when a duplicate copy is in the bag
	return gui
end

return Pets
