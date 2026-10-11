--!strict
-- The Gear shop: the item's name and a large preview with a card for its level and what the next upgrade gives, a
-- quantity picker and the Upgrade button. The next evolution (requirements and the two evolve buttons) lives in the
-- EvolvePanel that pops out beside the shop; on a narrow screen ShopController moves its EvolveBody into the shop as a
-- card instead. ShopController binds the named controls and places everything from Shared.EquipmentShopLayout.
local RS = game:GetService("ReplicatedStorage")
local Icons = require(RS.Shared.Config.HudIcons)
local N = require(script.Parent.Parent.NativeUI)
local Shop = {}
Shop.LAYOUT = 3 -- bumped when the panels' controls change; an older authored copy is replaced by ShopController

-- dark text for the light cards: no outline needed, much easier to scan than white on pale blue
local NAVY = Color3.fromRGB(22, 50, 118)
local MINT = Color3.fromRGB(14, 122, 82)

local function viewport(parent: Instance): ViewportFrame
	return N.create("ViewportFrame", { Name = "Preview", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0,
		Ambient = Color3.fromRGB(195, 201, 220), LightColor = Color3.fromRGB(255, 240, 216), LightDirection = Vector3.new(1, -1, 2), ZIndex = 4 }, parent)
end

local function body(parent: Instance, name: string, size: number): TextLabel
	local label = N.text(parent, name, "", UDim2.new(), UDim2.fromOffset(100, 20), true)
	label.TextSize, label.TextWrapped, label.TextYAlignment = size, true, Enum.TextYAlignment.Top
	return label
end

-- A left label and a right value on one line, in dark ink
local function pairRow(parent: Instance, name: string, size: number): Frame
	local row = N.create("Frame", { Name = name, BackgroundTransparency = 1, Size = UDim2.fromOffset(200, 28), ZIndex = 3 }, parent)
	local label = N.text(row, "Label", "", UDim2.new(), UDim2.fromScale(0.58, 1))
	label.TextSize, label.TextColor3, label.TextTruncate = size, NAVY, Enum.TextTruncate.AtEnd
	local value = N.text(row, "Value", "", UDim2.fromScale(0.42, 0), UDim2.fromScale(0.58, 1))
	value.TextSize, value.TextColor3, value.TextXAlignment = size, MINT, Enum.TextXAlignment.Right
	value.Position = UDim2.fromScale(0.42, 0)
	value.TextScaled = true
	N.create("UITextSizeConstraint", { MinTextSize = 11, MaxTextSize = size }, value)
	return row
end

-- The pop-out: a header like the shop's, and the body that holds everything
local function evolvePanel(gui: ScreenGui): Frame
	local panel = N.create("Frame", { Name = "EvolvePanel", Size = UDim2.fromOffset(300, 560), BackgroundColor3 = N.PANEL, BorderSizePixel = 0, Active = true, Visible = false, ZIndex = 2 }, gui)
	N.surface(panel, 4, .8)
	local header = N.create("Frame", { Name = "Header", Size = UDim2.new(1, 0, 0, 52), BackgroundColor3 = N.GREEN, BorderSizePixel = 0, ZIndex = 3 }, panel)
	N.surface(header, 4, .58)
	N.text(panel, "Title", "Evolution", UDim2.fromOffset(14, 4), UDim2.new(1, -28, 0, 44)).TextSize = 28
	local evolve = N.create("Frame", { Name = "EvolveBody", BackgroundTransparency = 1, Position = UDim2.fromOffset(16, 78), Size = UDim2.fromOffset(268, 440), ZIndex = 3 }, panel)
	-- the card and heading only show when the body is stacked inside the shop
	local card = N.create("Frame", { Name = "Card", Size = UDim2.fromScale(1, 1), BackgroundColor3 = N.CARD, BorderSizePixel = 0, Visible = false, ZIndex = 3 }, evolve)
	N.surface(card)
	local heading = N.text(evolve, "Heading", "Next evolution", UDim2.new(), UDim2.fromOffset(200, 20))
	heading.TextSize, heading.Visible = 17, false
	local well = N.create("Frame", { Name = "NextWell", Size = UDim2.fromOffset(150, 150), BackgroundColor3 = N.PANEL, BorderSizePixel = 0, ZIndex = 3 }, evolve)
	N.surface(well); viewport(well)
	local name = N.text(evolve, "NextName", "", UDim2.new(), UDim2.fromOffset(200, 32))
	name.TextSize, name.TextXAlignment, name.TextTruncate = 26, Enum.TextXAlignment.Center, Enum.TextTruncate.AtEnd
	local tier = body(evolve, "NextTier", 16)
	tier.TextXAlignment = Enum.TextXAlignment.Center
	for i = 1, 3 do pairRow(evolve, "Req" .. i, 17) end
	local go = N.button(evolve, "Evolve", "EVOLVE", UDim2.new(), UDim2.fromOffset(268, 46), N.GREEN)
	local alt = N.button(evolve, "EvolveNow", "EVOLVE NOW", UDim2.new(), UDim2.fromOffset(268, 46), N.ORANGE)
	alt.Visible = false
	for _, b in { go, alt } do
		b.TextScaled, b.TextWrapped = true, true
		N.create("UITextSizeConstraint", { MinTextSize = 11, MaxTextSize = 22 }, b)
		N.create("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }, b)
	end
	return panel
end

function Shop.build(): ScreenGui
	local gui = N.menu("GearShop", "Gear shop", N.ORANGE, 560, 560)
	gui.DisplayOrder = 20
	gui:SetAttribute("ShopLayout", Shop.LAYOUT)
	local p = gui.Panel :: any
	local nav = N.button(gui, "ShopButton", "", UDim2.fromOffset(14, 100), UDim2.fromOffset(64, 64), N.CYAN)
	N.create("ImageLabel", { Name = "Icon", Image = Icons.equipment, BackgroundTransparency = 1, Size = UDim2.fromScale(.7, .6), Position = UDim2.fromScale(.15, .05), ScaleType = Enum.ScaleType.Fit, ZIndex = 5 }, nav)
	local caption = N.text(nav, "Caption", "GEAR", UDim2.fromScale(0, .66), UDim2.fromScale(1, .3))
	caption.TextXAlignment, caption.TextScaled = Enum.TextXAlignment.Center, true
	-- the wallet is a gold chip with a coin, beside the close button
	local wallet = N.create("TextLabel", { Name = "Wallet", Text = "$0", Position = UDim2.new(1, -216, 0, 10), Size = UDim2.fromOffset(150, 34), BackgroundColor3 = Color3.fromRGB(255, 207, 55),
		Font = N.FONT, TextSize = 20, TextColor3 = N.WHITE, BorderSizePixel = 0, ZIndex = 5 }, p)
	N.create("UICorner", { CornerRadius = UDim.new(0.5, 0) }, wallet)
	N.create("UIPadding", { PaddingLeft = UDim.new(0, 26) }, wallet)
	N.create("ImageLabel", { Name = "Coin", Image = Icons.coin, BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, -20, 0.5, 0),
		Size = UDim2.fromOffset(22, 22), ScaleType = Enum.ScaleType.Fit, ZIndex = 6 }, wallet)
	-- two centred tabs
	local tabs = N.create("Frame", { Name = "Tabs", BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 66), Size = UDim2.new(1, -24, 0, 44), ZIndex = 3 }, p)
	for i, id in { "pickaxe", "backpack" } do
		local tab = N.button(tabs, id .. "Tab", if id == "pickaxe" then "PICKAXES" else "BACKPACKS", UDim2.new((i - 1) / 2, if i == 1 then 0 else 4, 0, 0), UDim2.new(1 / 2, -4, 1, 0), N.CARD)
		tab.TextSize = 16
	end
	for _, kind in { "pickaxe", "backpack" } do
		local screen = N.create("ScrollingFrame", { Name = kind .. "Screen", Size = UDim2.new(1, -24, 0, 300), Position = UDim2.fromOffset(12, 116), BackgroundTransparency = 1, BorderSizePixel = 0,
			CanvasSize = UDim2.new(), ScrollBarThickness = 4, ScrollingDirection = Enum.ScrollingDirection.Y, ZIndex = 3 }, p)
		N.surface(N.create("Frame", { Name = "InfoCard", BackgroundColor3 = N.CARD, BorderSizePixel = 0, ZIndex = 3 }, screen))
		local name = N.text(screen, "GearName", "", UDim2.new(), UDim2.fromOffset(200, 36))
		name.TextSize, name.TextTruncate = 32, Enum.TextTruncate.AtEnd
		local tier = body(screen, "TierText", 18)
		tier.TextTruncate = Enum.TextTruncate.AtEnd
		local well = N.create("Frame", { Name = "Well", Size = UDim2.fromOffset(180, 180), BackgroundColor3 = N.PANEL, BorderSizePixel = 0, ZIndex = 3 }, screen)
		N.surface(well); viewport(well)
		-- on the info card: the level, then what the chosen quantity adds, in dark ink with aligned values
		local levelLabel = N.text(screen, "LevelLabel", "Level", UDim2.new(), UDim2.fromOffset(100, 36))
		levelLabel.TextSize, levelLabel.TextColor3 = 24, NAVY
		local levelValue = N.text(screen, "LevelValue", "", UDim2.new(), UDim2.fromOffset(100, 36))
		levelValue.TextSize, levelValue.TextXAlignment, levelValue.TextColor3 = 32, Enum.TextXAlignment.Right, MINT
		for i = 1, 4 do pairRow(screen, "Stat" .. i, 18) end
		N.text(screen, "QtyLabel", "Quantity", UDim2.new(), UDim2.fromOffset(100, 40)).TextSize = 20
		for i, text in { "1×", "10×", "MAX" } do
			N.button(screen, "Amount" .. i, text, UDim2.new(), UDim2.fromOffset(60, 40), N.CARD).TextSize = 18
		end
		local upgrade = N.button(screen, "Upgrade", "UPGRADE", UDim2.new(), UDim2.fromOffset(300, 52), N.GREEN)
		upgrade.TextScaled = true
		N.create("UITextSizeConstraint", { MinTextSize = 12, MaxTextSize = 26 }, upgrade)
		N.create("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }, upgrade)
	end
	N.text(p, "Footer", "", UDim2.new(0, 12, 1, -56), UDim2.new(1, -24, 0, 44), true).TextWrapped = true
	evolvePanel(gui)
	return gui
end

return Shop
