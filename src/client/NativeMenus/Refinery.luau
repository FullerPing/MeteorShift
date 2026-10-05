--!strict
local N = require(script.Parent.Parent.NativeUI)
local Home = require(game:GetService("ReplicatedStorage").Shared.Config.Home)
local Refinery = {}
function Refinery.build(): ScreenGui
	local gui = N.menu("RefineryMenu", "Refinery", N.ORANGE, 620, 570)
	local p = gui.Panel :: any
	p.Header.Size = UDim2.new(1, 0, 0, 44)
	p.Title.Position, p.Title.Size = UDim2.fromOffset(16, 4), UDim2.new(1, -80, 0, 36)
	p.Title.TextSize = 24
	p.Close.Position = UDim2.new(1, -48, 0, 0)
	N.button(p, "refineTab", "REFINE", UDim2.fromOffset(16, 48), UDim2.new(.5, -20, 0, 44), N.CYAN)
	N.button(p, "productionTab", "UPGRADES", UDim2.new(.5, 4, 0, 48), UDim2.new(.5, -20, 0, 44), N.ORANGE)
	for i, action in { "deposit", "claim" } do
		local card = N.create("Frame", { Name = action .. "Card", BackgroundColor3 = N.CARD, BorderSizePixel = 0,
			Position = UDim2.new((i - 1) * .5, if i == 1 then 16 else 4, 0, 108), Size = UDim2.new(.5, -20, 0, 116), ZIndex = 3 }, p)
		N.surface(card)
		N.text(card, "Quantity", "0", UDim2.fromOffset(12, 8), UDim2.new(1, -24, 0, 30)).TextSize = 25
		N.text(card, "Hint", if action == "deposit" then "Ore in backpack" else "Finished bars", UDim2.fromOffset(12, 40), UDim2.new(1, -24, 0, 18), true)
		N.button(card, "Action", if action == "deposit" then "Deposit ore" else "Claim bars", UDim2.new(0, 8, 1, -52), UDim2.new(1, -16, 0, 44), if action == "deposit" then N.ORANGE else N.GREEN)
	end
	N.text(p, "Status", "Ready to work · deposit ore above", UDim2.fromOffset(16, 240), UDim2.new(1, -32, 0, 26)).TextSize = 18
	local progress = N.create("Frame", { Name = "Progress", Position = UDim2.fromOffset(16, 271), Size = UDim2.new(1, -32, 0, 5), BackgroundColor3 = N.CARD, BorderSizePixel = 0, ZIndex = 3 }, p)
	N.create("Frame", { Name = "Fill", Size = UDim2.fromScale(0, 1), BackgroundColor3 = N.GREEN, BorderSizePixel = 0, ZIndex = 4 }, progress)
	N.text(p, "Totals", "REFINING ORDER", UDim2.fromOffset(16, 284), UDim2.new(1, -32, 0, 22), true)
	local function list(name: string, y: number, height: number)
		local frame = N.create("ScrollingFrame", { Name = name, Position = UDim2.fromOffset(16, y), Size = UDim2.new(1, -32, 0, height), BackgroundTransparency = 1,
			BorderSizePixel = 0, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y, ScrollBarThickness = 4, ZIndex = 3 }, p)
		N.create("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, frame)
		return frame
	end
	list("Inventory", 316, 198)
	N.text(p, "Empty", "Mine ore, then deposit it here to start refining.", UDim2.fromOffset(16, 316), UDim2.new(1, -32, 0, 44), true).TextWrapped = true
	N.text(p, "Feedback", "Deposit ore. Claim finished bars.", UDim2.new(0, 16, 1, -54), UDim2.new(1, -168, 0, 44), true).TextWrapped = true
	N.button(p, "ResetPriority", "Reset order", UDim2.new(1, -144, 1, -54), UDim2.fromOffset(128, 44), N.CYAN).TextSize = 13
	N.text(p, "UpgradeWallet", "Your production line", UDim2.fromOffset(16, 100), UDim2.new(1, -32, 0, 24), true)
	local upgrades = list("ProductionUpgrades", 132, 382)
	for i, id in Home.StationOrder do
		local card = N.create("Frame", { Name = id .. "Upgrade", LayoutOrder = i, Size = UDim2.new(1, -4, 0, 118), BackgroundColor3 = N.CARD, BorderSizePixel = 0, ZIndex = 3 }, upgrades)
		N.surface(card)
		N.text(card, "Station", Home.Stations[id].Name, UDim2.fromOffset(12, 8), UDim2.new(1, -24, 0, 22)).TextSize = 16
		N.text(card, "Improvement", "", UDim2.fromOffset(12, 34), UDim2.new(1, -24, 0, 22), true)
		N.text(card, "Purpose", "", UDim2.fromOffset(12, 64), UDim2.new(1, -180, 0, 44), true).TextWrapped = true
		N.button(card, "BuyUpgrade", "UPGRADE", UDim2.new(1, -160, 0, 64), UDim2.fromOffset(148, 44), N.ORANGE).TextSize = 13
	end
	local templates = N.create("Folder", { Name = "Templates" }, gui)
	local row = N.create("Frame", { Name = "OreRow", Visible = false, Size = UDim2.new(1, -4, 0, 60), BackgroundColor3 = N.CARD, BorderSizePixel = 0, ZIndex = 3 }, templates)
	N.surface(row)
	N.text(row, "Type", "Iron", UDim2.fromOffset(10, 6), UDim2.new(1, -114, 0, 22)).TextSize = 16
	N.text(row, "Amount", "", UDim2.fromOffset(10, 30), UDim2.new(1, -114, 0, 22), true)
	N.button(row, "PriorityUp", "↑", UDim2.new(1, -96, 0, 8), UDim2.fromOffset(44, 44), N.CYAN)
	N.button(row, "PriorityDown", "↓", UDim2.new(1, -48, 0, 8), UDim2.fromOffset(44, 44), N.CYAN)
	return gui
end
return Refinery
