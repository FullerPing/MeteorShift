--!strict
-- The Foundry window in the owner's "cartoon light" look (MenuTheme / Shared.MenuPalette, like the Gear Shop and Pets):
-- a blue "Foundry" ribbon and Close on the corner, REFINE / UPGRADES tabs, then REFINE shows the production line as three
-- cards (ore hopper -> foundry -> finished bars, with drawn arrows between them) and the refining order under them;
-- UPGRADES shows the production line upgrade view (UpgradePanel, added by the controller). Every icon comes from
-- Config.HudIcons. RefineryController fills and positions everything; a built copy older than LAYOUT is rebuilt.
local RS = game:GetService("ReplicatedStorage")
local Config = require(RS.Shared.Config)
local Palette = require(RS.Shared.MenuPalette)
local N = require(script.Parent.Parent.NativeUI)
local Theme = require(script.Parent.Parent.MenuTheme)
local Refinery = {}
Refinery.LAYOUT = 2 -- bumped when the controls change; RefineryController rebuilds an older copy

local function icon(parent: Instance, name: string, kind: string, position: UDim2, size: UDim2): ImageLabel
	return N.create("ImageLabel", {
		Name = name, Image = Config.HudIcons[kind], Position = position, Size = size, ZIndex = 5,
		BackgroundTransparency = 1, BorderSizePixel = 0, ScaleType = Enum.ScaleType.Fit,
	}, parent)
end

local function text(parent: Instance, name: string, value: string, size: number, color: Color3, title: boolean?): TextLabel
	local label = Theme.label(parent, name, value, size, color, if title then Theme.TITLE_FONT else nil)
	label.TextTruncate = Enum.TextTruncate.AtEnd
	return label
end

-- A wallet chip on the UPGRADES page: a pale fill, a navy outline, the owner's icon and the Amount
local function chip(parent: Instance, name: string, kind: string, fill: Color3): Frame
	local frame = N.create("Frame", { Name = name, Size = UDim2.fromOffset(142, 32), BackgroundColor3 = fill, BorderSizePixel = 0, ZIndex = 4,
		Visible = false }, parent)
	Theme.round(frame, 10)
	Theme.stroke(frame, Palette.NAVY, 2.5)
	icon(frame, "Icon", kind, UDim2.fromOffset(4, 2), UDim2.fromOffset(28, 28))
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

function Refinery.build(): ScreenGui
	local gui = N.create("ScreenGui", { Name = "RefineryMenu", Enabled = false, ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 25,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, nil) :: ScreenGui
	gui:SetAttribute("NativePrefab", true)
	gui:SetAttribute("RefineryLayout", Refinery.LAYOUT)
	-- the screen behind the menu: 20% navy, as behind the Gear Shop
	N.create("TextButton", { Name = "Dimmer", Text = "", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Palette.NAVY, BackgroundTransparency = 0.8,
		BorderSizePixel = 0, AutoButtonColor = false, Modal = true }, gui)
	local p = Theme.panel(gui, "Panel", UDim2.fromOffset(620, 570)) :: any
	p.AnchorPoint, p.Position = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5)
	Theme.ribbon(p, "Foundry", Config.HudIcons.foundry)
	Theme.closeCorner(p, Config.HudIcons.close)
	local refineTab = Theme.button(p, "refineTab", "REFINE", "tabOn", 18)
	refineTab.Position, refineTab.Size = UDim2.fromOffset(16, 50), UDim2.new(0.5, -20, 0, 46)
	local productionTab = Theme.button(p, "productionTab", "UPGRADES", "tabOff", 18)
	productionTab.Position, productionTab.Size = UDim2.new(0.5, 4, 0, 50), UDim2.new(0.5, -20, 0, 46)

	-- the two ends of the line: what you can put in (ore from the backpack) and what you can take out (finished bars)
	for i, action in { "deposit", "claim" } do
		local deposit = action == "deposit"
		local card = Theme.card(p, action .. "Card", Palette.WHITE, Palette.DETAIL_BOTTOM, 14)
		card.Position, card.Size = UDim2.new((i - 1) * .5, if i == 1 then 16 else 4, 0, 108), UDim2.new(.5, -20, 0, 116)
		Theme.stroke(card, Palette.NAVY, 3)
		icon(card, "Icon", if deposit then "ore" else "bars", UDim2.fromOffset(10, 8), UDim2.fromOffset(46, 46))
		local caption = text(card, "Caption", if deposit then "ORE HOPPER" else "FINISHED BARS", 16, Palette.NAVY, true)
		caption.Position, caption.Size = UDim2.fromOffset(62, 10), UDim2.new(1, -72, 0, 22)
		local hint = text(card, "Hint", if deposit then "in your backpack" else "ready to claim", 14, Palette.GOLD_TEXT)
		hint.Position, hint.Size = UDim2.fromOffset(62, 32), UDim2.new(1, -72, 0, 18)
		local quantity = text(card, "Quantity", "0", 38, Palette.NAVY, true)
		quantity.Position, quantity.Size = UDim2.fromOffset(12, 60), UDim2.new(1, -24, 0, 44)
		local meter = Theme.bar(card, "Meter", if deposit then Palette.BAR_FILL else Palette.GOLD_BOTTOM)
		meter.Position, meter.Size = UDim2.fromOffset(12, 112), UDim2.new(1, -24, 0, 12)
		local meterText = text(card, "MeterText", "", 14, Palette.SECOND)
		meterText.Position, meterText.Size = UDim2.fromOffset(12, 128), UDim2.new(1, -24, 0, 18)
		local button = Theme.button(card, "Action", if deposit then "Deposit ore" else "Claim bars", "lime", 18)
		button.Position, button.Size = UDim2.new(0, 8, 1, -52), UDim2.new(1, -16, 0, 44)
	end

	-- the middle of the line: the foundry itself (a warm card), its status and progress
	local middle = Theme.card(p, "FoundryCard", Color3.fromRGB(255, 246, 232), Color3.fromRGB(255, 222, 182), 14)
	middle.Visible = false
	Theme.stroke(middle, Palette.NAVY, 3)
	icon(middle, "Icon", "foundry", UDim2.fromOffset(40, 10), UDim2.fromOffset(72, 72))
	local rate = text(middle, "Rate", "", 14, Palette.UP)
	rate.Position, rate.Size, rate.TextXAlignment = UDim2.fromOffset(8, 176), UDim2.new(1, -16, 0, 22), Enum.TextXAlignment.Center
	arrow(p, "FlowArrow1")
	arrow(p, "FlowArrow2")

	local status = text(p, "Status", "Ready to work · deposit ore above", 18, Palette.NAVY, true)
	status.Position, status.Size = UDim2.fromOffset(16, 240), UDim2.new(1, -32, 0, 26)
	local progress = Theme.bar(p, "Progress", Palette.LIME_BOTTOM)
	progress.Position, progress.Size = UDim2.fromOffset(16, 271), UDim2.new(1, -32, 0, 6)
	local totals = text(p, "Totals", "REFINING ORDER", 16, Palette.NAVY, true)
	totals.Position, totals.Size = UDim2.fromOffset(16, 284), UDim2.new(1, -32, 0, 22)
	local list = N.create("ScrollingFrame", { Name = "Inventory", Position = UDim2.fromOffset(16, 316), Size = UDim2.new(1, -32, 0, 198),
		BackgroundTransparency = 1, BorderSizePixel = 0, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y, ScrollBarThickness = 4, ScrollBarImageColor3 = Palette.BLUE_BOTTOM, ZIndex = 3 }, p)
	N.create("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, list)
	local empty = Theme.label(p, "Empty", "Nothing queued yet. Mine ore in the fields, then deposit it here.", 16, Palette.SECOND, nil, Enum.TextXAlignment.Center)
	empty.Position, empty.Size, empty.TextWrapped = UDim2.fromOffset(16, 316), UDim2.new(1, -32, 0, 44), true
	local feedback = Theme.label(p, "Feedback", "Mine ore, deposit it, claim the bars, then sell them at the Trading Post.", 14, Palette.SECOND)
	feedback.Position, feedback.Size, feedback.TextWrapped = UDim2.new(0, 16, 1, -58), UDim2.new(1, -168, 0, 44), true
	local reset = Theme.button(p, "ResetPriority", "Reset order", "blue", 15)
	reset.Position, reset.Size = UDim2.new(1, -144, 1, -60), UDim2.fromOffset(128, 46)

	-- UPGRADES page: the wallet on the right; RefineryController adds the line view (UpgradePanel) below
	local wallet = text(p, "UpgradeWallet", "Your production line", 18, Palette.NAVY, true)
	wallet.Position, wallet.Size = UDim2.fromOffset(16, 100), UDim2.new(1, -32, 0, 24)
	chip(p, "CashChip", "coin", Palette.CASH_CHIP)
	chip(p, "ShardChip", "crystal", Palette.SHARD_CHIP)

	-- one row of the refining order: the ore's bars, its name and amounts, and two buttons to move it up or down
	local templates = N.create("Folder", { Name = "Templates" }, gui)
	local row = Theme.card(templates, "OreRow", Palette.WHITE, Palette.DETAIL_TOP, 10)
	row.Visible, row.Size = false, UDim2.new(1, -4, 0, 60)
	row:SetAttribute(Theme.CUSTOM, true) -- it sits outside the panel until it is cloned: keep MenuSkin off it
	Theme.stroke(row, Palette.LEVEL_EDGE, 2)
	icon(row, "Icon", "barStack", UDim2.fromOffset(8, 8), UDim2.fromOffset(40, 40))
	local kind = text(row, "Type", "Iron", 17, Palette.NAVY, true)
	kind.Position, kind.Size = UDim2.fromOffset(56, 6), UDim2.new(1, -160, 0, 22)
	local amount = text(row, "Amount", "", 14, Palette.SECOND)
	amount.Position, amount.Size = UDim2.fromOffset(56, 30), UDim2.new(1, -160, 0, 22)
	local up = Theme.button(row, "PriorityUp", "↑", "blue", 22)
	up.Position, up.Size = UDim2.new(1, -96, 0, 8), UDim2.fromOffset(44, 44)
	local down = Theme.button(row, "PriorityDown", "↓", "blue", 22)
	down.Position, down.Size = UDim2.new(1, -48, 0, 8), UDim2.fromOffset(44, 44)
	return gui
end
return Refinery
