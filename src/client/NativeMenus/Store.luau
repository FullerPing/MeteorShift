--!strict
-- Author every catalog card in Edit mode; runtime never creates menu controls.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local NativeUI = require(script.Parent.Parent.NativeUI)
local Menu = {}
local Monetization = Config.Monetization
local GOLD, MINT = Color3.fromRGB(255, 219, 100), Color3.fromRGB(139, 240, 195)
local DARK = Color3.fromRGB(29, 30, 35)
local ICONS: { [string]: string } = {
	TwoXOre = "ore", BiggerBackpack = "backpack", OfflineHours = "bars", AutoDeposit = "foundry", VIP = "premium",
	CallMeteor = "meteor", Overclock = "foundry", TipJar = "premium", PocketChange = "coin", PetTreat = "premium",
	MiniOverclock = "foundry", OreRush = "ore", PetFeast = "premium", CashBundle = "coin", ExtraPetSlot = "plus",
}
local ACCENTS: { [string]: Color3 } = {
	TwoXOre = GOLD, BiggerBackpack = NativeUI.CYAN, OfflineHours = MINT, AutoDeposit = MINT, VIP = GOLD,
	CallMeteor = NativeUI.ORANGE, Overclock = NativeUI.CYAN, TipJar = MINT, PocketChange = GOLD, PetTreat = NativeUI.CYAN,
	MiniOverclock = NativeUI.CYAN, OreRush = GOLD, PetFeast = NativeUI.ORANGE, CashBundle = GOLD, ExtraPetSlot = MINT,
}

local function plainBorder(parent: Instance)
	NativeUI.create("UICorner", { CornerRadius = UDim.new(0, 4) }, parent)
	NativeUI.create("UIStroke", { Color = NativeUI.OUTLINE, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, parent)
end

local function icon(parent: Instance, name: string, kind: string, position: UDim2, size: UDim2): ImageLabel
	return NativeUI.create("ImageLabel", {
		Name = name, Image = Config.HudIcons[kind], Position = position, Size = size,
		BackgroundTransparency = 1, BorderSizePixel = 0, ScaleType = Enum.ScaleType.Fit,
	}, parent)
end

local function card(parent: Instance, key: string, order: number, kind: string, definition: any)
	local accent = ACCENTS[key] or NativeUI.CYAN
	local frame = NativeUI.create("Frame", { Name = key, LayoutOrder = order, Size = UDim2.fromOffset(272, 392), BackgroundColor3 = NativeUI.CARD, BorderSizePixel = 0 }, parent)
	plainBorder(frame)
	local kindText = NativeUI.text(frame, "Kind", if kind == "pass" then "GAME PASS" else "PRODUCT", UDim2.fromOffset(4, 8), UDim2.new(1, -8, 0, 14), true)
	kindText.Font, kindText.TextSize, kindText.TextColor3, kindText.TextXAlignment = Enum.Font.GothamBold, 10, accent, Enum.TextXAlignment.Center
	local well = NativeUI.create("Frame", {
		Name = "IconWell", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 28), Size = UDim2.fromOffset(100, 100),
		BackgroundColor3 = DARK, BorderSizePixel = 0,
	}, frame)
	plainBorder(well)
	local artwork = icon(well, "ItemIcon", ICONS[key] or "premium", UDim2.fromScale(0.5, 0.5), UDim2.fromScale(0.88, 0.88))
	artwork.AnchorPoint = Vector2.new(0.5, 0.5)
	local price = NativeUI.text(frame, "Price", if definition.Robux then "R$ " .. Format.number(definition.Robux) else "NOT ON SALE", UDim2.fromOffset(12, 134), UDim2.fromOffset(248, 28))
	price.TextScaled, price.TextWrapped, price.TextXAlignment = true, true, Enum.TextXAlignment.Center
	NativeUI.create("UITextSizeConstraint", { MinTextSize = 12, MaxTextSize = 24 }, price)
	local title = NativeUI.text(frame, "Title", definition.Name, UDim2.fromOffset(12, 168), UDim2.fromOffset(248, 44))
	title.TextScaled, title.TextWrapped, title.TextXAlignment = true, true, Enum.TextXAlignment.Center
	NativeUI.create("UITextSizeConstraint", { MinTextSize = 12, MaxTextSize = 24 }, title)
	local description = NativeUI.text(frame, "Description", definition.Description, UDim2.fromOffset(12, 218), UDim2.fromOffset(248, 64), true)
	description.TextSize, description.TextColor3 = 14, NativeUI.MUTED
	description.TextWrapped, description.TextYAlignment, description.TextXAlignment = true, Enum.TextYAlignment.Top, Enum.TextXAlignment.Center
	local status = NativeUI.text(frame, "Status", "", UDim2.fromOffset(12, 286), UDim2.fromOffset(248, 42), true)
	status.TextSize, status.TextColor3 = 12, NativeUI.ORANGE
	status.TextWrapped, status.TextYAlignment, status.TextXAlignment = true, Enum.TextYAlignment.Top, Enum.TextXAlignment.Center
	local buy = NativeUI.button(frame, "Buy", "NOT ON SALE YET", UDim2.new(0.5, 0, 1, -12), UDim2.fromOffset(248, 44), Color3.fromRGB(73, 83, 94))
	buy.AnchorPoint, buy.TextScaled, buy.TextWrapped = Vector2.new(0.5, 1), true, true
	NativeUI.create("UITextSizeConstraint", { MinTextSize = 10, MaxTextSize = 21 }, buy)
	NativeUI.create("UIPadding", { PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4), PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4) }, buy)
end

function Menu.build(): ScreenGui
	local gui: ScreenGui = NativeUI.create("ScreenGui", { Name = "Store", ResetOnSpawn = false, IgnoreGuiInset = true, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 23 }, nil)
	gui:SetAttribute("NativePrefab", true)
	local nav = NativeUI.button(gui, "StoreButton", "", UDim2.fromOffset(1112, 502), UDim2.fromOffset(120, 108), Color3.fromRGB(255, 207, 55))
	NativeUI.create("UIScale", { Name = "LayoutScale", Scale = 1 }, nav)
	icon(nav, "Icon", "store", UDim2.new(0.13, 0, 0.02, 0), UDim2.fromScale(0.74, 0.74))
	local caption = NativeUI.text(nav, "Caption", "STORE", UDim2.fromScale(0, 0.70), UDim2.fromScale(1, 0.30))
	caption.TextSize, caption.TextXAlignment = 18, Enum.TextXAlignment.Center
	local tooltip = NativeUI.text(nav, "Tooltip", "STORE", UDim2.new(1, 8, 0.5, -16), UDim2.fromOffset(102, 32))
	tooltip.TextSize, tooltip.TextXAlignment = 14, Enum.TextXAlignment.Center
	tooltip.BackgroundTransparency, tooltip.BackgroundColor3, tooltip.Visible, tooltip.ZIndex = 0, Color3.fromRGB(28, 72, 105), false, 2
	NativeUI.create("TextButton", { Name = "Dimmer", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(8, 11, 14), BackgroundTransparency = 0.18, Text = "", AutoButtonColor = false, BorderSizePixel = 0, Visible = false, ZIndex = 2, Modal = true }, gui)
	local panel = NativeUI.create("Frame", { Name = "Panel", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(900, 680), BackgroundColor3 = NativeUI.PANEL, BorderSizePixel = 0, Visible = false, ZIndex = 3, Active = true }, gui)
	NativeUI.surface(panel, 6, 0.85)
	local header = NativeUI.create("Frame", { Name = "MenuHeader", Size = UDim2.new(1, 0, 0, 64), BackgroundColor3 = NativeUI.GREEN, BorderSizePixel = 0, ZIndex = 3, Active = false, Selectable = false }, panel)
	NativeUI.surface(header, 6, 0.75)
	icon(panel, "HeaderIcon", "premium", UDim2.fromOffset(20, 17), UDim2.fromOffset(38, 38)).ZIndex = 5
	local title = NativeUI.text(panel, "Title", "STORE", UDim2.fromOffset(66, 12), UDim2.new(1, -138, 0, 46))
	title.TextSize = 36
	local subtitle = NativeUI.text(panel, "Subtitle", "Passes last forever. Nothing here changes meteor or mineral odds.", UDim2.fromOffset(20, 65), UDim2.new(1, -40, 0, 38), true)
	subtitle.TextColor3, subtitle.TextSize, subtitle.TextWrapped, subtitle.TextYAlignment = NativeUI.MUTED, 15, true, Enum.TextYAlignment.Top
	local close = NativeUI.button(panel, "Close", "", UDim2.new(1, -18, 0, 18), UDim2.fromOffset(44, 44), NativeUI.RED)
	close.AnchorPoint = Vector2.new(1, 0)
	icon(close, "Icon", "close", UDim2.fromOffset(10, 10), UDim2.fromOffset(24, 24)).ZIndex = 5
	local list = NativeUI.create("ScrollingFrame", {
		Name = "List", Position = UDim2.fromOffset(14, 112), Size = UDim2.new(1, -28, 1, -126),
		BackgroundTransparency = 1, BorderSizePixel = 0, CanvasSize = UDim2.fromOffset(0, 2436), ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 5, ScrollBarImageColor3 = GOLD, VerticalScrollBarInset = Enum.ScrollBarInset.Always,
	}, panel)
	NativeUI.create("UICorner", { CornerRadius = UDim.new(0, 4) }, list)
	NativeUI.create("UIPadding", { Name = "ListPadding", PaddingLeft = UDim.new(0, 12), PaddingTop = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), PaddingBottom = UDim.new(0, 12) }, list)
	NativeUI.create("UIGridLayout", { Name = "Grid", FillDirection = Enum.FillDirection.Horizontal, FillDirectionMaxCells = 3, HorizontalAlignment = Enum.HorizontalAlignment.Center, CellPadding = UDim2.fromOffset(12, 12), CellSize = UDim2.fromOffset(272, 392), SortOrder = Enum.SortOrder.LayoutOrder }, list)
	for order, key in Monetization.PassOrder do card(list, key, order, "pass", Monetization.Passes[key]) end
	for order, key in Monetization.ProductOrder do card(list, key, #Monetization.PassOrder + order, "product", Monetization.Products[key]) end
	return gui
end

return Menu
