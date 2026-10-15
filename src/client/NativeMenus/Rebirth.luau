--!strict
-- The Rebirth menu in the owner's "cartoon light" look (MenuTheme / Shared.MenuPalette, like the Gear Shop and Pets):
-- a blue "Rebirth" ribbon, Close on the corner and the cash chip; the body (the NOW -> AFTER bar value card, the price
-- note, and what resets / what you keep side by side) scrolls in Content; the requirement card, REBIRTH, the note under
-- it, the gold "Rebirth and Keep Everything" card and PERKS are separate. Every icon comes from Config.HudIcons.
-- RebirthController places everything from Shared.RebirthLayout and swaps this panel into the saved menu when the saved
-- copy's RebirthLayout mark is older than LAYOUT.
local RS = game:GetService("ReplicatedStorage")
local Icons = require(RS.Shared.Config.HudIcons)
local Palette = require(RS.Shared.MenuPalette)
local N = require(script.Parent.Parent.NativeUI)
local Theme = require(script.Parent.Parent.MenuTheme)

local Menu = {}
Menu.LAYOUT = 4 -- bumped when the panel's controls change; an older authored copy is replaced by RebirthController

-- One side of the NOW -> AFTER card: a small caption over a big multiplier
local function side(parent: Instance, name: string, valueName: string, caption: string, captionColor: Color3, maxSize: number): TextLabel
	local frame = N.create("Frame", { Name = name, BackgroundTransparency = 1, Size = UDim2.fromScale(0.4, 1), ZIndex = 4 }, parent)
	local top = Theme.label(frame, "Caption", caption, 14, captionColor, nil, Enum.TextXAlignment.Center)
	top.Position, top.Size = UDim2.fromOffset(0, 30), UDim2.new(1, 0, 0, 18)
	local value = Theme.label(frame, valueName, "", maxSize, Palette.NAVY, Theme.TITLE_FONT, Enum.TextXAlignment.Center)
	value.Position, value.Size, value.TextScaled = UDim2.fromOffset(0, 50), UDim2.new(1, 0, 1, -58), true
	N.create("UITextSizeConstraint", { MinTextSize = 16, MaxTextSize = maxSize }, value)
	return value
end

-- What resets or what you keep: a pale card with a heading and one row per line, each with the owner's icon
local function list(parent: Instance, name: string, order: number, heading: string, headingColor: Color3, fill: Color3, edge: Color3, rows: { { string } })
	local box = Theme.card(parent, name, fill, nil, 12)
	box.LayoutOrder, box.ZIndex = order, 3
	Theme.stroke(box, edge, 2)
	local title = Theme.label(box, "Heading", heading, 16, headingColor)
	title.Position, title.Size = UDim2.fromOffset(12, 8), UDim2.new(1, -24, 0, 20)
	for index, row in rows do
		local line = N.create("Frame", { Name = "Row" .. index, BackgroundTransparency = 1, Position = UDim2.fromOffset(10, 6 + index * 28),
			Size = UDim2.new(1, -20, 0, 24), ZIndex = 4 }, box)
		N.create("ImageLabel", { Name = "Icon", Image = Icons[row[1]], BackgroundTransparency = 1, Size = UDim2.fromOffset(24, 24),
			ScaleType = Enum.ScaleType.Fit, ImageColor3 = if row[1] == "pets" then Palette.BLUE_BOTTOM else Palette.WHITE, ZIndex = 5 }, line)
		local text = Theme.label(line, "Text", row[2], 15, Palette.NAVY)
		text.Position, text.Size, text.TextTruncate = UDim2.fromOffset(32, -3), UDim2.new(1, -32, 1, 6), Enum.TextTruncate.AtEnd
	end
end

function Menu.build(): ScreenGui
	local gui = N.create("ScreenGui", { Name = "Rebirth", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 22,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, nil) :: ScreenGui
	gui:SetAttribute("NativePrefab", true)
	gui:SetAttribute("RebirthLayout", Menu.LAYOUT)

	-- the nav tile on the HUD (the owner's tile is cloned over this by ExactNavButton)
	local nav = N.button(gui, "RebirthButton", "", UDim2.fromOffset(1112, 382), UDim2.fromOffset(120, 108), N.GREEN)
	N.create("UIScale", { Name = "LayoutScale", Scale = 1 }, nav)
	N.create("ImageLabel", { Name = "Icon", Image = Icons.rebirth, BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.02), Size = UDim2.fromScale(0.74, 0.74), ScaleType = Enum.ScaleType.Fit, ZIndex = 5 }, nav)
	local caption = N.text(nav, "Caption", "REBIRTH", UDim2.fromScale(0, 0.7), UDim2.fromScale(1, 0.3))
	caption.TextXAlignment, caption.TextScaled = Enum.TextXAlignment.Center, true
	local badge = N.create("Frame", { Name = "ReadyBadge", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -4, 0, 4),
		Size = UDim2.fromOffset(9, 9), BackgroundColor3 = Palette.LIME_BOTTOM, BorderSizePixel = 0, Visible = false }, nav)
	Theme.round(badge, 9)
	local tooltip = N.text(nav, "Tooltip", "REBIRTH", UDim2.new(1, 8, 0.5, -16), UDim2.fromOffset(102, 32))
	tooltip.Visible, tooltip.ZIndex = false, 2

	-- the screen behind the menu: 20% navy, as behind the Gear Shop
	N.create("TextButton", { Name = "Dimmer", Text = "", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Palette.NAVY,
		BackgroundTransparency = 0.8, BorderSizePixel = 0, AutoButtonColor = false, Visible = false, Modal = true }, gui)
	local p = Theme.panel(gui, "Panel", UDim2.fromOffset(760, 475)) :: any
	p.AnchorPoint, p.Position, p.Visible = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5), false
	Theme.ribbon(p, "Rebirth", Icons.rebirth)
	Theme.closeCorner(p, Icons.close)
	Theme.chip(p, "Wallet", Icons.coin, Palette.CASH_CHIP).Text = "$0"

	-- the scrolling body
	local content = N.create("ScrollingFrame", { Name = "Content", Size = UDim2.fromOffset(440, 396), BackgroundTransparency = 1, BorderSizePixel = 0,
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 4, ScrollBarImageColor3 = Palette.BLUE_BOTTOM,
		ScrollingDirection = Enum.ScrollingDirection.Y, VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar, ZIndex = 3 }, p)
	N.create("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }, content)

	-- the reward: BAR VALUE, NOW x1 -> AFTER x5
	local compare = Theme.card(content, "Compare", Palette.WHITE, Palette.DETAIL_BOTTOM, 14)
	compare.LayoutOrder, compare.Size, compare.ZIndex = 1, UDim2.new(1, -6, 0, 150), 3
	Theme.stroke(compare, Palette.NAVY, 3)
	local heading = Theme.label(compare, "Headline", "BAR VALUE", 16, Palette.NAVY, nil, Enum.TextXAlignment.Center)
	heading.Position, heading.Size = UDim2.fromOffset(0, 8), UDim2.new(1, 0, 0, 20)
	side(compare, "CurrentBox", "CurrentMultiplier", "NOW", Palette.SECOND, 48).Parent.Position = UDim2.fromScale(0.04, 0)
	local after = side(compare, "AfterBox", "NextMultiplier", "AFTER REBIRTH", Palette.UP, 64)
	after.Parent.Position = UDim2.fromScale(0.56, 0)
	after.TextColor3 = Palette.WHITE
	Theme.ink(after, true, 4)
	-- the arrow between them: a lime shaft and a diamond head, outlined in navy (no icon in HudIcons is an arrow)
	local arrow = N.create("Frame", { Name = "Arrow", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 14), Size = UDim2.fromOffset(50, 34), ZIndex = 5 }, compare)
	local shaft = N.create("Frame", { Name = "Shaft", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.fromOffset(32, 14), BackgroundColor3 = Palette.LIME_BOTTOM, BorderSizePixel = 0, ZIndex = 5 }, arrow)
	Theme.round(shaft, 4)
	Theme.stroke(shaft, Palette.NAVY, 2.5)
	local head = N.create("Frame", { Name = "Head", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -14, 0.5, 0),
		Size = UDim2.fromOffset(24, 24), Rotation = 45, BackgroundColor3 = Palette.LIME_BOTTOM, BorderSizePixel = 0, ZIndex = 6 }, arrow)
	Theme.round(head, 4)
	Theme.stroke(head, Palette.NAVY, 2.5)
	local note = Theme.label(content, "PriceNote", "", 14, Palette.SECOND, nil, Enum.TextXAlignment.Center)
	note.LayoutOrder, note.Size, note.AutomaticSize, note.TextWrapped = 2, UDim2.new(1, -6, 0, 0), Enum.AutomaticSize.Y, true

	-- what resets and what you keep, side by side (RebirthReset.apply: tiers, pets, shards, perks and index rewards survive)
	local lists = N.create("Frame", { Name = "Lists", LayoutOrder = 3, BackgroundTransparency = 1, Size = UDim2.new(1, -6, 0, 152), ZIndex = 3 }, content)
	N.create("UIGridLayout", { CellSize = UDim2.new(0.5, -6, 1, 0), CellPadding = UDim2.fromOffset(12, 0), SortOrder = Enum.SortOrder.LayoutOrder }, lists)
	list(lists, "ResetBox", 1, "RESETS", Palette.UNMET, Color3.fromRGB(255, 246, 247), Color3.fromRGB(242, 184, 194),
		{ { "coin", "Cash" }, { "equipment", "Gear levels" }, { "foundry", "Production line level" }, { "ore", "Ore and bars" } })
	list(lists, "KeepBox", 2, "YOU KEEP", Palette.UP, Color3.fromRGB(244, 252, 238), Color3.fromRGB(184, 226, 156),
		{ { "pets", "Pets" }, { "crystal", "Shards and perks" }, { "index", "Index bonuses" }, { "premium", "Gear tiers and passes" } })

	-- the requirement: the cost, a bar and how far along you are
	local requirement = Theme.card(p, "Requirement", Palette.WHITE, Palette.DETAIL_BOTTOM, 12)
	Theme.stroke(requirement, Palette.NAVY, 3)
	Theme.label(requirement, "ReqLabel", "REQUIREMENT", 16, Palette.NAVY)
	Theme.label(requirement, "Percent", "0%", 16, Palette.UP, Theme.TITLE_FONT, Enum.TextXAlignment.Right)
	local cash = Theme.label(requirement, "CashProgress", "", 15, Palette.SECOND)
	cash.TextScaled = true
	N.create("UITextSizeConstraint", { MinTextSize = 9, MaxTextSize = 15 }, cash)
	Theme.bar(requirement, "ProgressBar", Palette.LIME_BOTTOM)

	Theme.button(p, "Confirm", "REBIRTH", "lime", 26)
	local footer = Theme.label(p, "Footer", "", 13, Palette.SECOND, nil, Enum.TextXAlignment.Center)
	footer.TextWrapped, footer.TextScaled = true, true
	N.create("UITextSizeConstraint", { MinTextSize = 9, MaxTextSize = 14 }, footer)

	-- the premium card: gold, under the main action and lighter than it
	local keepCard = Theme.card(p, "KeepCard", Palette.EVO_TOP, Palette.EVO_BOTTOM, 14)
	Theme.stroke(keepCard, Palette.EVO_EDGE, 3)
	N.create("ImageLabel", { Name = "Icon", Image = Icons.premium, BackgroundTransparency = 1, Position = UDim2.fromOffset(10, 8),
		Size = UDim2.fromOffset(28, 28), ScaleType = Enum.ScaleType.Fit, ZIndex = 4 }, keepCard)
	local keepTitle = Theme.label(keepCard, "Heading", "Rebirth and Keep Everything", 16, Palette.NAVY)
	keepTitle.Position, keepTitle.Size, keepTitle.TextScaled = UDim2.fromOffset(44, 8), UDim2.new(1, -52, 0, 28), true
	N.create("UITextSizeConstraint", { MinTextSize = 10, MaxTextSize = 16 }, keepTitle)
	local keepBody = Theme.label(keepCard, "Body", "Keeps cash, gear, production, ore and bars. The multiplier still goes up.", 13, Palette.GOLD_TEXT)
	keepBody.Position, keepBody.Size, keepBody.TextWrapped = UDim2.fromOffset(12, 36), UDim2.new(1, -24, 0, 34), true
	keepBody.TextYAlignment = Enum.TextYAlignment.Top
	Theme.button(p, "Keep", "KEEP EVERYTHING", "gold", 18).ZIndex = 6

	-- PerksController wires this one up
	local perks = Theme.button(p, "PerksButton", "COLONY PERKS", "blue", 18)
	local face = perks:FindFirstChild("Face") :: Frame
	N.create("ImageLabel", { Name = "Icon", Image = Icons.crystal, BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 8, 0.5, 0), Size = UDim2.fromOffset(26, 26), ScaleType = Enum.ScaleType.Fit, ZIndex = 8 }, face)
	return gui
end

return Menu
