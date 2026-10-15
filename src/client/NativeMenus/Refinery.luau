--!strict
-- The Foundry window. REFINE shows the production line as three cards (ore hopper -> foundry -> finished bars) with the
-- refining order underneath; UPGRADES shows the production line upgrade view. RefineryController fills and positions everything.
local RS = game:GetService("ReplicatedStorage")
local N = require(script.Parent.Parent.NativeUI)
local Config = require(RS.Shared.Config)
local Refinery = {}

local GOLD = Color3.fromRGB(255, 219, 100)

local function icon(parent: Instance, name: string, kind: string, position: UDim2, size: UDim2): ImageLabel
	return N.create("ImageLabel", {
		Name = name, Image = Config.HudIcons[kind], Position = position, Size = size, ZIndex = 5,
		BackgroundTransparency = 1, BorderSizePixel = 0, ScaleType = Enum.ScaleType.Fit,
	}, parent)
end

local function meter(parent: Instance, name: string, color: Color3): Frame
	local track = N.create("Frame", { Name = name, Size = UDim2.new(1, -24, 0, 12), BackgroundColor3 = N.OUTLINE, BorderSizePixel = 0, ZIndex = 3 }, parent)
	N.create("Frame", { Name = "Fill", Size = UDim2.fromScale(0, 1), BackgroundColor3 = color, BorderSizePixel = 0, ZIndex = 4 }, track)
	return track
end

local function chip(parent: Instance, name: string, kind: string): Frame
	local frame = N.create("Frame", { Name = name, Size = UDim2.fromOffset(142, 32), BackgroundColor3 = N.CARD, BorderSizePixel = 0, ZIndex = 3, Visible = false }, parent)
	N.surface(frame)
	icon(frame, "Icon", kind, UDim2.fromOffset(6, 3), UDim2.fromOffset(26, 26))
	local amount = N.text(frame, "Amount", "0", UDim2.fromOffset(36, 0), UDim2.new(1, -42, 1, 0))
	amount.TextSize = 18
	return frame
end

function Refinery.build(): ScreenGui
	local gui = N.menu("RefineryMenu", "Foundry", N.ORANGE, 620, 570)
	local p = gui.Panel :: any
	p.Header.Size = UDim2.new(1, 0, 0, 44)
	icon(p, "HeaderIcon", "foundry", UDim2.fromOffset(18, 4), UDim2.fromOffset(38, 38))
	p.Title.Position, p.Title.Size = UDim2.fromOffset(64, 4), UDim2.new(1, -120, 0, 36)
	p.Title.TextSize = 26
	p.Close.Position = UDim2.new(1, -48, 0, 0)
	N.button(p, "refineTab", "REFINE", UDim2.fromOffset(16, 48), UDim2.new(.5, -20, 0, 44), N.CYAN)
	N.button(p, "productionTab", "UPGRADES", UDim2.new(.5, 4, 0, 48), UDim2.new(.5, -20, 0, 44), N.ORANGE)

	-- the two ends of the line: what you can put in (ore from the backpack) and what you can take out (finished bars)
	for i, action in { "deposit", "claim" } do
		local deposit = action == "deposit"
		local card = N.create("Frame", { Name = action .. "Card", BackgroundColor3 = N.CARD, BorderSizePixel = 0,
			Position = UDim2.new((i - 1) * .5, if i == 1 then 16 else 4, 0, 108), Size = UDim2.new(.5, -20, 0, 116), ZIndex = 3 }, p)
		N.surface(card)
		icon(card, "Icon", if deposit then "ore" else "bars", UDim2.fromOffset(10, 8), UDim2.fromOffset(46, 46))
		local caption = N.text(card, "Caption", if deposit then "ORE HOPPER" else "FINISHED BARS", UDim2.fromOffset(62, 10), UDim2.new(1, -72, 0, 22))
		caption.TextSize, caption.TextColor3 = 16, GOLD
		N.text(card, "Hint", if deposit then "in your backpack" else "ready to claim", UDim2.fromOffset(62, 32), UDim2.new(1, -72, 0, 18), true).TextSize = 16
		N.text(card, "Quantity", "0", UDim2.fromOffset(12, 60), UDim2.new(1, -24, 0, 44)).TextSize = 38
		local track = meter(card, "Meter", if deposit then N.ORANGE else GOLD)
		track.Position = UDim2.fromOffset(12, 112)
		N.text(card, "MeterText", "", UDim2.fromOffset(12, 128), UDim2.new(1, -24, 0, 18), true).TextSize = 16
		N.button(card, "Action", if deposit then "Deposit ore" else "Claim bars", UDim2.new(0, 8, 1, -52), UDim2.new(1, -16, 0, 44), if deposit then N.ORANGE else N.GREEN)
	end

	-- the middle of the line: the foundry itself, its status and progress
	local middle = N.create("Frame", { Name = "FoundryCard", BackgroundColor3 = N.CARD, BorderSizePixel = 0, Visible = false, ZIndex = 3 }, p)
	N.surface(middle)
	icon(middle, "Icon", "foundry", UDim2.fromOffset(40, 10), UDim2.fromOffset(72, 72))
	local rate = N.text(middle, "Rate", "", UDim2.fromOffset(8, 176), UDim2.new(1, -16, 0, 22), true)
	rate.TextXAlignment, rate.TextSize = Enum.TextXAlignment.Center, 16
	for index = 1, 2 do
		local arrow = N.text(p, "FlowArrow" .. index, "→", UDim2.fromOffset(0, 0), UDim2.fromOffset(26, 26))
		arrow.TextSize, arrow.TextColor3, arrow.TextXAlignment, arrow.Visible = 30, GOLD, Enum.TextXAlignment.Center, false
	end

	N.text(p, "Status", "Ready to work · deposit ore above", UDim2.fromOffset(16, 240), UDim2.new(1, -32, 0, 26)).TextSize = 18
	local progress = N.create("Frame", { Name = "Progress", Position = UDim2.fromOffset(16, 271), Size = UDim2.new(1, -32, 0, 5), BackgroundColor3 = N.CARD, BorderSizePixel = 0, ZIndex = 4 }, p)
	N.create("Frame", { Name = "Fill", Size = UDim2.fromScale(0, 1), BackgroundColor3 = N.GREEN, BorderSizePixel = 0, ZIndex = 5 }, progress)
	N.text(p, "Totals", "REFINING ORDER", UDim2.fromOffset(16, 284), UDim2.new(1, -32, 0, 22), true).TextSize = 16
	local function list(name: string, y: number, height: number)
		local frame = N.create("ScrollingFrame", { Name = name, Position = UDim2.fromOffset(16, y), Size = UDim2.new(1, -32, 0, height), BackgroundTransparency = 1,
			BorderSizePixel = 0, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y, ScrollBarThickness = 4, ZIndex = 3 }, p)
		N.create("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, frame)
		return frame
	end
	list("Inventory", 316, 198)
	local empty = N.text(p, "Empty", "Nothing queued yet. Mine ore in the fields, then deposit it here.", UDim2.fromOffset(16, 316), UDim2.new(1, -32, 0, 44), true)
	empty.TextWrapped, empty.TextSize, empty.TextXAlignment = true, 17, Enum.TextXAlignment.Center
	local feedback = N.text(p, "Feedback", "Mine ore, deposit it, claim the bars, then sell them at the Trading Post.", UDim2.new(0, 16, 1, -54), UDim2.new(1, -168, 0, 44), true)
	feedback.TextWrapped, feedback.TextSize = true, 15
	N.button(p, "ResetPriority", "Reset order", UDim2.new(1, -144, 1, -54), UDim2.fromOffset(128, 44), N.CYAN).TextSize = 13

	-- UPGRADES page: the wallet on the right; RefineryController adds the line view (UpgradePanel) below
	N.text(p, "UpgradeWallet", "Your production line", UDim2.fromOffset(16, 100), UDim2.new(1, -32, 0, 24), true)
	chip(p, "CashChip", "coin")
	chip(p, "ShardChip", "crystal")

	local templates = N.create("Folder", { Name = "Templates" }, gui)
	local row = N.create("Frame", { Name = "OreRow", Visible = false, Size = UDim2.new(1, -4, 0, 60), BackgroundColor3 = N.CARD, BorderSizePixel = 0, ZIndex = 3 }, templates)
	N.surface(row)
	icon(row, "Icon", "barStack", UDim2.fromOffset(8, 8), UDim2.fromOffset(40, 40))
	N.text(row, "Type", "Iron", UDim2.fromOffset(56, 6), UDim2.new(1, -160, 0, 22)).TextSize = 16
	N.text(row, "Amount", "", UDim2.fromOffset(56, 30), UDim2.new(1, -160, 0, 22), true).TextSize = 15
	N.button(row, "PriorityUp", "↑", UDim2.new(1, -96, 0, 8), UDim2.fromOffset(44, 44), N.CYAN)
	N.button(row, "PriorityDown", "↓", UDim2.new(1, -48, 0, 8), UDim2.fromOffset(44, 44), N.CYAN)
	return gui
end
return Refinery
