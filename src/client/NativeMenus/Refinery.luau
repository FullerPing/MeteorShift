--!strict
-- The Foundry window in the owner's "cartoon light" look (MenuTheme / Shared.MenuPalette), laid out as the owner's mockup
-- (Craterworks Menu Redesign, 2026-10-15): a blue "Foundry" ribbon and Close on the corner, the cash chip, REFINE /
-- UPGRADES tabs, then REFINE shows the production line as three equal cards (ORE HOPPER -> FOUNDRY -> FINISHED BARS, each
-- with the owner's icon on a well, a number row, a bar and an action) and the REFINING ORDER in a soft card under them;
-- UPGRADES shows the production line upgrade view (UpgradePanel, added by the controller). Every icon comes from
-- Config.HudIcons. RefineryController fills and positions everything (Shared.RefineryLayout); an older copy is rebuilt.
local RS = game:GetService("ReplicatedStorage")
local Config = require(RS.Shared.Config)
local Palette = require(RS.Shared.MenuPalette)
local N = require(script.Parent.Parent.NativeUI)
local Theme = require(script.Parent.Parent.MenuTheme)
local Refinery = {}
Refinery.LAYOUT = 3 -- bumped when the controls change; RefineryController rebuilds an older copy

local function text(parent: Instance, name: string, value: string, size: number, color: Color3, title: boolean?, align: Enum.TextXAlignment?): TextLabel
	local label = Theme.label(parent, name, value, size, color, if title then Theme.TITLE_FONT else nil, align)
	label.TextScaled = true
	N.create("UITextSizeConstraint", { MinTextSize = 9, MaxTextSize = size }, label)
	return label
end

-- A wallet chip: a pale fill, a navy outline, the owner's icon and the Amount
local function chip(parent: Instance, name: string, kind: string, fill: Color3): Frame
	local frame = N.create("Frame", { Name = name, Size = UDim2.fromOffset(142, 32), BackgroundColor3 = fill, BorderSizePixel = 0, ZIndex = 4,
		Visible = false }, parent)
	Theme.round(frame, 10)
	Theme.stroke(frame, Palette.NAVY, 2.5)
	Theme.icon(frame, "Icon", kind, UDim2.fromOffset(4, 2), UDim2.fromOffset(28, 28))
	local amount = text(frame, "Amount", "0", 17, Palette.NAVY, true)
	amount.Position, amount.Size = UDim2.fromOffset(36, 0), UDim2.new(1, -42, 1, 0)
	return frame
end

-- The arrow between two cards: a lime shaft and a diamond head, outlined in navy, drawn to any square size
local function arrow(parent: Instance, name: string): Frame
	local frame = N.create("Frame", { Name = name, BackgroundTransparency = 1, Size = UDim2.fromOffset(26, 26), Visible = false, ZIndex = 5 }, parent)
	local shaft = N.create("Frame", { Name = "Shaft", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.fromScale(0.62, 0.42),
		BackgroundColor3 = Palette.LIME_BOTTOM, BorderSizePixel = 0, ZIndex = 5 }, frame)
	Theme.round(shaft, 3)
	Theme.stroke(shaft, Palette.NAVY, 2)
	local head = N.create("Frame", { Name = "Head", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.66, 0.5), Size = UDim2.fromScale(0.56, 0.56),
		Rotation = 45, BackgroundColor3 = Palette.LIME_BOTTOM, BorderSizePixel = 0, ZIndex = 6 }, frame)
	Theme.round(head, 3)
	Theme.stroke(head, Palette.NAVY, 2)
	return frame
end

-- One card of the line: Caption, a Well with the owner's icon, the number row (Quantity on the left, Sub on the right),
-- a Meter and, on the two ends, an Action button (the middle card has a Note instead). RefineryController places them.
local function lineCard(parent: Instance, name: string, caption: string, icon: string, well: string, action: string?): Frame
	local card = Theme.box(parent, name)
	text(card, "Caption", caption, 15, Palette.NAVY, true, Enum.TextXAlignment.Center)
	Theme.iconWell(card, "Well", icon, well)
	text(card, "Quantity", "0", 22, Palette.NAVY, true)
	text(card, "Sub", "", 13, Palette.SECOND, false, Enum.TextXAlignment.Right)
	Theme.bar(card, "Meter", Palette.BAR_FILL)
	if action then
		Theme.button(card, "Action", action, "lime", 17)
	else
		local note = text(card, "Note", "Works while you mine. Faster with Upgrades.", 13, Palette.SECOND, false, Enum.TextXAlignment.Center)
		note.TextWrapped = true
	end
	return card
end

function Refinery.build(): ScreenGui
	local gui = N.create("ScreenGui", { Name = "RefineryMenu", Enabled = false, ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 25,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, nil) :: ScreenGui
	gui:SetAttribute("NativePrefab", true)
	gui:SetAttribute("RefineryLayout", Refinery.LAYOUT)
	-- the screen behind the menu: 20% navy, as behind the Gear Shop
	N.create("TextButton", { Name = "Dimmer", Text = "", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Palette.NAVY, BackgroundTransparency = 0.8,
		BorderSizePixel = 0, AutoButtonColor = false, Modal = true }, gui)
	local p = Theme.panel(gui, "Panel", UDim2.fromOffset(860, 572)) :: any
	p.AnchorPoint, p.Position = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5)
	Theme.ribbon(p, "Foundry", Config.HudIcons.foundry)
	Theme.closeCorner(p, Config.HudIcons.close)
	Theme.button(p, "refineTab", "REFINE", "tabOn", 18)
	Theme.button(p, "productionTab", "UPGRADES", "tabOff", 18)

	-- the production line: ore hopper -> foundry -> finished bars
	lineCard(p, "depositCard", "ORE HOPPER", "ore", "blue", "DEPOSIT ORE")
	local middle = lineCard(p, "FoundryCard", "FOUNDRY", "foundry", "warm", nil)
	;((middle:FindFirstChild("Meter") :: Frame):FindFirstChild("Fill") :: Frame).BackgroundColor3 = Palette.ORANGE_FILL
	lineCard(p, "claimCard", "FINISHED BARS", "barStack", "gold", "CLAIM BARS")
	arrow(p, "FlowArrow1")
	arrow(p, "FlowArrow2")

	-- the refining order: a heading row (title, how it works, Reset order) and the rows, top first
	local order = Theme.soft(p, "Order")
	local totals = text(order, "Totals", "REFINING ORDER", 16, Palette.NAVY, true)
	totals.Position, totals.Size = UDim2.fromOffset(14, 8), UDim2.fromOffset(170, 26)
	local how = text(order, "How", "Top first. Move the ore you want sold soonest up.", 13, Palette.SECOND)
	how.Position, how.Size = UDim2.fromOffset(186, 8), UDim2.new(1, -186 - 150, 0, 26)
	local reset = Theme.button(order, "ResetPriority", "Reset order", "tabOff", 14)
	reset.AnchorPoint, reset.Position, reset.Size = Vector2.new(1, 0), UDim2.new(1, -10, 0, 4), UDim2.fromOffset(130, 36)
	local list = N.create("ScrollingFrame", { Name = "Inventory", Position = UDim2.fromOffset(10, 40), Size = UDim2.new(1, -20, 1, -46),
		BackgroundTransparency = 1, BorderSizePixel = 0, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y, ScrollBarThickness = 4, ScrollBarImageColor3 = Palette.BLUE_BOTTOM,
		VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar, ZIndex = 3 }, order)
	N.create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }, list)
	local empty = Theme.label(order, "Empty", "Nothing queued yet. Mine ore in the fields, then deposit it here.", 15, Palette.SECOND, nil, Enum.TextXAlignment.Center)
	empty.Position, empty.Size, empty.TextWrapped = UDim2.fromOffset(10, 40), UDim2.new(1, -20, 1, -46), true
	local feedback = text(p, "Feedback", "", 14, Palette.SECOND)

	-- UPGRADES page: the wallet chips; RefineryController adds the line view (UpgradePanel) below the tabs
	local wallet = text(p, "UpgradeWallet", "Your production line", 18, Palette.NAVY, true)
	wallet.Visible = false
	chip(p, "CashChip", "coin", Palette.CASH_CHIP)
	chip(p, "ShardChip", "crystal", Palette.SHARD_CHIP)
	feedback.ZIndex = 5

	-- one row of the refining order: its place, the ore's icon, its name, how much is queued, and up / down
	local templates = N.create("Folder", { Name = "Templates" }, gui)
	local row = N.create("Frame", { Name = "OreRow", Visible = false, Size = UDim2.new(1, -4, 0, 38), BackgroundTransparency = 1, ZIndex = 3 }, templates)
	row:SetAttribute(Theme.CUSTOM, true) -- it sits outside the panel until it is cloned: keep MenuSkin off it
	local place = text(row, "Place", "1", 16, Palette.SECOND, true, Enum.TextXAlignment.Center)
	place.Position, place.Size = UDim2.fromOffset(2, 6), UDim2.fromOffset(20, 26)
	Theme.icon(row, "Icon", "ore", UDim2.fromOffset(28, 6), UDim2.fromOffset(26, 26))
	local kind = text(row, "Type", "Iron ore", 16, Palette.NAVY, true)
	kind.Position, kind.Size = UDim2.fromOffset(62, 6), UDim2.new(0.38, -62, 0, 26)
	local amount = text(row, "Amount", "", 14, Palette.SECOND)
	amount.Position, amount.Size = UDim2.new(0.38, 0, 0, 6), UDim2.new(0.62, -104, 0, 26)
	local up = Theme.button(row, "PriorityUp", "↑", "tabOff", 18)
	up.AnchorPoint, up.Position, up.Size = Vector2.new(1, 0), UDim2.new(1, -50, 0, 1), UDim2.fromOffset(42, 36)
	local down = Theme.button(row, "PriorityDown", "↓", "tabOff", 18)
	down.AnchorPoint, down.Position, down.Size = Vector2.new(1, 0), UDim2.new(1, -2, 0, 1), UDim2.fromOffset(42, 36)
	local line = Theme.divider(row, "Divider")
	line.Position = UDim2.new(0, 0, 1, -2)
	return gui
end
return Refinery
