--!strict
local RS = game:GetService("ReplicatedStorage")
local Config = require(RS.Shared.Config)
local Icons = require(RS.Shared.Config.HudIcons)
local N = require(script.Parent.Parent.NativeUI)
local Shop = {}
local function viewport(parent: Instance): ViewportFrame
	return N.create("ViewportFrame", { Name = "Preview", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0,
		Ambient = Color3.fromRGB(195, 201, 220), LightColor = Color3.fromRGB(255, 240, 216), LightDirection = Vector3.new(1, -1, 2), ZIndex = 4 }, parent)
end
function Shop.build(): ScreenGui
	local gui = N.menu("GearShop", "Gear shop", N.ORANGE, 860, 520)
	gui.DisplayOrder = 20
	local p = gui.Panel :: any
	local nav = N.button(gui, "ShopButton", "", UDim2.fromOffset(14, 100), UDim2.fromOffset(64, 64), N.CYAN)
	N.create("ImageLabel", { Name = "Icon", Image = Icons.equipment, BackgroundTransparency = 1, Size = UDim2.fromScale(.7, .6), Position = UDim2.fromScale(.15, .05), ScaleType = Enum.ScaleType.Fit, ZIndex = 5 }, nav)
	local caption = N.text(nav, "Caption", "GEAR", UDim2.fromScale(0, .66), UDim2.fromScale(1, .3))
	caption.TextXAlignment, caption.TextScaled = Enum.TextXAlignment.Center, true
	N.text(p, "Wallet", "$0 · 0 shards", UDim2.fromOffset(12, 54), UDim2.new(1, -24, 0, 24), true)
	local tabs = N.create("Frame", { Name = "Tabs", BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 66), Size = UDim2.new(1, -24, 0, 44), ZIndex = 3 }, p)
	for i, id in { "pickaxe", "backpack", "pets" } do
		N.button(tabs, id .. "Tab", string.upper(id), UDim2.new((i - 1) / 3, 0, 0, 0), UDim2.new(1 / 3, -4, 1, 0), N.CARD).TextSize = 14
	end
	for _, kind in { "pickaxe", "backpack" } do
		local screen = N.create("Frame", { Name = kind .. "Screen", Size = UDim2.new(1, -24, 0, 300), Position = UDim2.fromOffset(12, 116), BackgroundTransparency = 1, ZIndex = 3 }, p)
		local showcase = N.create("Frame", { Name = "Showcase", Size = UDim2.new(0, 196, 1, 0), BackgroundTransparency = 1 }, screen)
		local well = N.create("Frame", { Name = "Well", Size = UDim2.new(1, 0, 1, -52), BackgroundColor3 = N.CARD, BorderSizePixel = 0, ZIndex = 3 }, showcase)
		N.surface(well); viewport(well)
		N.text(showcase, "GearName", "", UDim2.new(0, 0, 1, -48), UDim2.new(1, 0, 0, 24)).TextSize = 18
		N.text(showcase, "TierText", "TIER 1", UDim2.new(0, 0, 1, -24), UDim2.new(1, 0, 0, 18), true)
		local rows = N.create("ScrollingFrame", { Name = "Rows", Position = UDim2.fromOffset(208, 0), Size = UDim2.new(1, -208, 1, 0), BackgroundTransparency = 1, BorderSizePixel = 0,
			CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y, ScrollBarThickness = 4, ZIndex = 3 }, screen)
		N.create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) }, rows)
		local strip = N.create("Frame", { Name = "NarrowHeader", LayoutOrder = 0, Size = UDim2.new(1, -4, 0, 84), BackgroundTransparency = 1, Visible = false }, rows)
		local tinyWell = N.create("Frame", { Name = "Well", Size = UDim2.fromOffset(84, 84), BackgroundColor3 = N.CARD, BorderSizePixel = 0, ZIndex = 3 }, strip)
		N.surface(tinyWell); viewport(tinyWell)
		N.text(strip, "GearName", "", UDim2.fromOffset(96, 20), UDim2.new(1, -100, 0, 24)).TextSize = 16
		N.text(strip, "TierText", "", UDim2.fromOffset(96, 48), UDim2.new(1, -100, 0, 18), true)
		local settings = if kind == "pickaxe" then Config.Gear.Pickaxe else Config.Gear.Backpack
		for order, stat in settings.Stats do
			local row = N.create("Frame", { Name = stat .. "Row", LayoutOrder = order, Size = UDim2.new(1, -4, 0, 54), BackgroundColor3 = N.CARD, BorderSizePixel = 0, ZIndex = 3 }, rows)
			N.surface(row)
			local title = N.text(row, "StatName", settings.Names[stat], UDim2.fromOffset(10, 6), UDim2.new(1, -156, 0, 20))
			title.TextSize, title.TextScaled = 16, true
			N.create("UITextSizeConstraint", { MinTextSize = 11, MaxTextSize = 16 }, title)
			N.text(row, "Effect", "", UDim2.fromOffset(10, 30), UDim2.new(1, -156, 0, 16), true).TextSize = 12
			for slot, amount in { 1, 10 } do
				local b = N.button(row, "Buy" .. amount, "+" .. amount, UDim2.new(1, if slot == 1 then -136 else -66, .5, -22), UDim2.fromOffset(66, 44), N.ORANGE)
				b.TextSize = 12
			end
			local status = N.text(row, "CapStatus", "TIER CAP\nEvolve below", UDim2.new(1, -142, 0, 5), UDim2.fromOffset(132, 44), true)
			status.TextXAlignment, status.Visible = Enum.TextXAlignment.Center, false
		end
		local banner = N.create("Frame", { Name = "EvolveBanner", LayoutOrder = 100, Size = UDim2.new(1, -4, 0, 84), BackgroundColor3 = N.CARD, BorderSizePixel = 0, ZIndex = 3 }, rows)
		N.surface(banner)
		local title = N.text(banner, "EvolveTitle", "EVOLVE", UDim2.fromOffset(10, 4), UDim2.new(1, -140, 0, 22))
		title.TextScaled = true; N.create("UITextSizeConstraint", { MinTextSize = 12, MaxTextSize = 18 }, title)
		local meter = N.create("Frame", { Name = "GateBar", Position = UDim2.fromOffset(10, 30), Size = UDim2.new(1, -140, 0, 8), BackgroundColor3 = N.PANEL, BorderSizePixel = 0, ZIndex = 3 }, banner)
		N.create("Frame", { Name = "Fill", Size = UDim2.fromScale(0, 1), BackgroundColor3 = N.GREEN, BorderSizePixel = 0, ZIndex = 4 }, meter)
		local needs = N.text(banner, "Needs", "", UDim2.fromOffset(10, 42), UDim2.new(1, -140, 0, 38), true)
		needs.TextWrapped, needs.TextSize = true, 12
		N.button(banner, "Evolve", "EVOLVE", UDim2.new(1, -120, .5, -24), UDim2.fromOffset(112, 48), N.GREEN)
	end
	local pets = N.create("ScrollingFrame", { Name = "petsCarousel", BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(12, 116), Size = UDim2.new(1, -24, 0, 300), CanvasSize = UDim2.fromOffset(5700, 418), ScrollingDirection = Enum.ScrollingDirection.XY, ScrollBarThickness = 4, ZIndex = 3 }, p)
	N.create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 12) }, pets)
	N.create("UIPadding", { PaddingLeft = UDim.new(0, 4), PaddingTop = UDim.new(0, 4) }, pets)
	local function card(id: string, order: number, title: string)
		local c = N.create("Frame", { Name = id, LayoutOrder = order, Size = UDim2.fromOffset(352, 410), BackgroundColor3 = N.CARD, BorderSizePixel = 0, ZIndex = 3 }, pets)
		N.surface(c)
		N.text(c, "Tier", "", UDim2.fromOffset(12, 10), UDim2.new(1, -24, 0, 18), true)
		local well = N.create("Frame", { Name = "PreviewWell", Position = UDim2.fromOffset(12, 36), Size = UDim2.new(1, -24, 0, 88), BackgroundColor3 = N.PANEL, BorderSizePixel = 0, ZIndex = 3 }, c)
		N.surface(well); viewport(well)
		N.create("ImageLabel", { Name = "EggIcon", Image = Icons.crystal, BackgroundTransparency = 1, Size = UDim2.fromScale(.6, .8), Position = UDim2.fromScale(.2, .1), ScaleType = Enum.ScaleType.Fit, Visible = false, ZIndex = 4 }, well)
		N.text(c, "ItemName", title, UDim2.fromOffset(12, 132), UDim2.new(1, -24, 0, 28)).TextSize = 20
		local info = N.text(c, "Stats", "", UDim2.fromOffset(12, 166), UDim2.new(1, -24, 0, 158), true)
		info.RichText, info.TextWrapped, info.TextYAlignment = true, true, Enum.TextYAlignment.Top
		local price = N.text(c, "Price", "", UDim2.new(0, 12, 1, -78), UDim2.new(1, -24, 0, 22), true)
		price.TextWrapped, price.TextSize = true, 11
		N.button(c, "Purchase", "", UDim2.new(0, 12, 1, -52), UDim2.new(1, -24, 0, 44), N.GREEN)
	end
	for order, egg in Config.Pets.Eggs do card("egg_" .. egg.Id, order, egg.Name) end
	for order, pet in Config.Pets.List do card("pet_" .. pet.Id, #Config.Pets.Eggs + order, pet.Name) end
	N.text(p, "Footer", "", UDim2.new(0, 80, 1, -56), UDim2.new(1, -160, 0, 44), true).TextWrapped = true
	N.button(p, "Previous", "‹", UDim2.new(0, 12, 1, -56), UDim2.fromOffset(56, 44), N.CYAN)
	N.button(p, "Next", "›", UDim2.new(1, -68, 1, -56), UDim2.fromOffset(56, 44), N.CYAN)
	return gui
end
return Shop
