--!strict
-- The Rebirth menu. Authored in Studio, but RebirthController swaps in this panel when the saved copy predates it (see Menu.LAYOUT).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)

local Menu = {}
local WHITE, OUTLINE = Color3.fromRGB(255, 255, 255), Color3.fromRGB(12, 18, 25)
local PANEL, GREEN = Color3.fromRGB(43, 44, 49), Color3.fromRGB(105, 240, 103)
local GOLD, MUTED = Color3.fromRGB(255, 219, 100), Color3.fromRGB(211, 228, 240)

local function new(className: string, parent: Instance?, props: { [string]: any }): any
	local object: any = Instance.new(className)
	for key, value in props do object[key] = value end
	object.Parent = parent
	return object
end

local function border(parent: Instance, radius: number, thickness: number)
	new("UICorner", parent, { CornerRadius = UDim.new(0, radius) })
	new("UIStroke", parent, { Color = OUTLINE, Thickness = thickness, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
end

local function texture(parent: Instance, radius: number, transparency: number)
	local image = new("ImageLabel", parent, {
		Name = "StudTexture", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0,
		Image = "rbxassetid://6927295847", ImageColor3 = WHITE, ImageTransparency = transparency,
		ScaleType = Enum.ScaleType.Tile, TileSize = UDim2.fromOffset(128, 128), ZIndex = 0,
		Active = false, Selectable = false,
	})
	new("UICorner", image, { CornerRadius = UDim.new(0, radius) })
end

local function text(parent: Instance, name: string, props: { [string]: any }): TextLabel
	local object: TextLabel = new("TextLabel", parent, {
		Name = name, BackgroundTransparency = 1, Font = Enum.Font.FredokaOne, TextSize = 18,
		TextColor3 = WHITE, TextStrokeColor3 = OUTLINE, TextStrokeTransparency = 0,
	})
	for key, value in props do (object :: any)[key] = value end
	return object
end

local function button(parent: Instance, name: string, props: { [string]: any }): TextButton
	local object: TextButton = new("TextButton", parent, {
		Name = name, BackgroundColor3 = GREEN, BorderSizePixel = 0, AutoButtonColor = true,
		Font = Enum.Font.FredokaOne, TextSize = 20, TextColor3 = WHITE, TextStrokeColor3 = OUTLINE,
		TextStrokeTransparency = 0,
	})
	for key, value in props do (object :: any)[key] = value end
	border(object, 4, 3)
	new("UIGradient", object, { Rotation = 90, Color = ColorSequence.new(WHITE, Color3.fromRGB(235, 235, 235)) })
	return object
end


local function icon(parent: Instance, name: string, kind: string, props: { [string]: any })
	local object = new("ImageLabel", parent, {
		Name = name, BackgroundTransparency = 1, BorderSizePixel = 0,
		Image = Config.HudIcons[kind], ScaleType = Enum.ScaleType.Fit,
	})
	for key, value in props do object[key] = value end
	return object
end

local RED = Color3.fromRGB(255, 101, 106)

-- Body copy: GothamMedium, no outline, wraps and grows with its text
local function body(parent: Instance, name: string, props: { [string]: any }): TextLabel
	local label = text(parent, name, {
		Font = Enum.Font.GothamMedium, TextSize = 14, TextWrapped = true, TextStrokeTransparency = 1, TextColor3 = MUTED,
		TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
		Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
	})
	for key, value in props do (label :: any)[key] = value end
	return label
end

-- A list that grows with its text: a coloured heading over wrapped lines
local function listBox(parent: Instance, name: string, order: number, heading: string, color: Color3): Frame
	local frame = new("Frame", parent, {
		Name = name, LayoutOrder = order, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1, BorderSizePixel = 0,
	})
	new("UIPadding", frame, { PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4), PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 8) })
	new("UIListLayout", frame, { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder })
	text(frame, "Heading", { LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 22), Text = heading, TextSize = 18, TextColor3 = color, TextXAlignment = Enum.TextXAlignment.Left })
	return frame
end

-- One side of the before/after comparison: a small caption over a big multiplier
local function multiplierBox(parent: Instance, name: string, valueName: string, caption: string, position: UDim2, valueColor: Color3, maxSize: number): TextLabel
	local frame = new("Frame", parent, {
		Name = name, Position = position, Size = UDim2.new(0.38, 0, 1, 0), BackgroundColor3 = Color3.fromRGB(67, 69, 77), BorderSizePixel = 0,
	})
	border(frame, 6, 3)
	text(frame, "Caption", { Position = UDim2.fromOffset(0, 6), Size = UDim2.new(1, 0, 0, 20), Text = caption, TextSize = 14 })
	local value = text(frame, valueName, { Position = UDim2.fromOffset(6, 28), Size = UDim2.new(1, -12, 1, -34), Text = "", TextScaled = true, TextColor3 = valueColor })
	new("UITextSizeConstraint", value, { MinTextSize = 18, MaxTextSize = maxSize })
	return value
end

function Menu.build(): ScreenGui
	local gui: ScreenGui = new("ScreenGui", nil, {
		Name = "Rebirth", ResetOnSpawn = false, IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 22,
	})
	gui:SetAttribute("NativePrefab", true)
	gui:SetAttribute("RebirthLayout", Menu.LAYOUT)
	local nav = button(gui, "RebirthButton", { Text = "", Position = UDim2.fromOffset(1112, 382), Size = UDim2.fromOffset(120, 108), BackgroundColor3 = GREEN })
	new("UIScale", nav, { Name = "LayoutScale", Scale = 1 })
	texture(nav, 4, 0.75)
	icon(nav, "Icon", "rebirth", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.02), Size = UDim2.fromScale(0.74, 0.74) })
	text(nav, "Caption", { Text = "REBIRTH", Position = UDim2.fromScale(0, 0.70), Size = UDim2.fromScale(1, 0.30), TextSize = 18 })
	local badge = new("Frame", nav, { Name = "ReadyBadge", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -4, 0, 4), Size = UDim2.fromOffset(9, 9), BackgroundColor3 = Color3.fromRGB(139, 240, 195), BorderSizePixel = 0, Visible = false })
	new("UICorner", badge, { CornerRadius = UDim.new(0, 9) })
	text(nav, "Tooltip", { Text = "REBIRTH", Position = UDim2.new(1, 8, 0.5, -16), Size = UDim2.fromOffset(102, 32), TextSize = 14, BackgroundTransparency = 0, BackgroundColor3 = Color3.fromRGB(28, 72, 105), Visible = false, ZIndex = 2 })
	new("TextButton", gui, {
		Name = "Dimmer", Size = UDim2.fromScale(1, 1), BackgroundColor3 = OUTLINE, BackgroundTransparency = 0.25,
		Text = "", AutoButtonColor = false, BorderSizePixel = 0, Visible = false, ZIndex = 2, Modal = true,
	})
	local panel = new("Frame", gui, {
		Name = "Panel", Position = UDim2.fromOffset(420, 40), Size = UDim2.fromOffset(440, 640),
		BackgroundColor3 = PANEL, BorderSizePixel = 0, Visible = false, ZIndex = 3, Active = true,
	})
	border(panel, 6, 4)
	texture(panel, 6, 0.85)
	local header = new("Frame", panel, { Name = "MenuHeader", Size = UDim2.new(1, 0, 0, 56), BackgroundColor3 = GREEN, BorderSizePixel = 0, ZIndex = 0, Active = false, Selectable = false })
	new("UICorner", header, { CornerRadius = UDim.new(0, 6) })
	texture(header, 6, 0.75)
	new("Frame", header, { Name = "Divider", AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 4), BackgroundColor3 = OUTLINE, BorderSizePixel = 0, ZIndex = 0 })
	icon(panel, "HeaderIcon", "rebirth", { Position = UDim2.fromOffset(20, 17), Size = UDim2.fromOffset(38, 38), ZIndex = 5 })
	text(panel, "Title", { Position = UDim2.fromOffset(66, 12), Size = UDim2.new(1, -230, 0, 38), Text = "REBIRTH", TextSize = 26, TextXAlignment = Enum.TextXAlignment.Left })
	local close = button(panel, "Close", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 8), Size = UDim2.fromOffset(44, 44), Text = "", BackgroundColor3 = Color3.fromRGB(235, 70, 70) })
	icon(close, "Icon", "close", { Position = UDim2.fromOffset(12, 12), Size = UDim2.fromOffset(20, 20) })
	-- PerksController wires this one up
	button(panel, "PerksButton", { Position = UDim2.new(1, -156, 0, 8), Size = UDim2.fromOffset(100, 44), Text = "PERKS", TextSize = 18 })

	-- The scrolling body: the reward first, then the consequences and the progress
	local content = new("ScrollingFrame", panel, {
		Name = "Content", Position = UDim2.fromOffset(16, 68), Size = UDim2.new(1, -32, 0, 380), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1, BorderSizePixel = 0, ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 3, ScrollBarImageColor3 = GOLD, VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
	})
	new("UIListLayout", content, { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center })
	text(content, "Headline", { LayoutOrder = 1, Size = UDim2.new(1, -4, 0, 26), Text = "INCREASE YOUR BAR VALUE", TextSize = 20 })

	local compare = new("Frame", content, { Name = "Compare", LayoutOrder = 2, Size = UDim2.new(1, -4, 0, 88), BackgroundTransparency = 1 })
	multiplierBox(compare, "CurrentBox", "CurrentMultiplier", "CURRENT", UDim2.new(), WHITE, 40)
	text(compare, "Arrow", { Position = UDim2.fromScale(0.38, 0), Size = UDim2.fromScale(0.24, 1), Text = "→", Font = Enum.Font.GothamBold, TextSize = 40, TextColor3 = GOLD, TextStrokeTransparency = 1 })
	multiplierBox(compare, "AfterBox", "NextMultiplier", "AFTER", UDim2.fromScale(0.62, 0), GREEN, 64)

	local keep = listBox(content, "KeepBox", 3, "✓ YOU KEEP", GREEN)
	body(keep, "Body", { LayoutOrder = 2, Text = "Pets · Foundry levels · Core shards · Index bonuses · Pickaxe & backpack tiers · Colony perks" })
	-- The exact things RebirthReset.apply clears (Station Memory and Head Start can keep part of the last two)
	local resets = listBox(content, "ResetBox", 4, "RESETS", RED)
	body(resets, "Body", { LayoutOrder = 2, Text = "Cash · Pickaxe & backpack upgrades · Carried, hopper & post ore and bars · Placed decor · Hopper, Conveyor & Collection Post levels" })
	body(resets, "PriceNote", { LayoutOrder = 3, Text = "Upgrade prices rise", TextColor3 = RED })

	local requirement = new("Frame", content, { Name = "Requirement", LayoutOrder = 5, Size = UDim2.new(1, -4, 0, 48), BackgroundTransparency = 1 })
	text(requirement, "ReqLabel", { Size = UDim2.new(0.5, 0, 0, 20), Text = "Rebirth requirement", Font = Enum.Font.GothamMedium, TextSize = 14, TextStrokeTransparency = 1, TextColor3 = MUTED, TextXAlignment = Enum.TextXAlignment.Left })
	text(requirement, "CashProgress", { Position = UDim2.fromScale(0.5, 0), Size = UDim2.new(0.5, 0, 0, 20), Text = "", TextSize = 16, TextXAlignment = Enum.TextXAlignment.Right })
	local bar = new("Frame", requirement, { Name = "ProgressBar", Position = UDim2.fromOffset(0, 28), Size = UDim2.new(1, -52, 0, 12), BackgroundColor3 = PANEL, BorderSizePixel = 0 })
	new("Frame", bar, { Name = "Fill", Size = UDim2.fromScale(0, 1), BackgroundColor3 = GREEN, BorderSizePixel = 0, ZIndex = 2 })
	text(requirement, "Percent", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 22), Size = UDim2.fromOffset(46, 24), Text = "0%", TextSize = 16, TextXAlignment = Enum.TextXAlignment.Right })

	-- Pinned below the body. The main action is grey until it can be used; the premium one is gold and a little lighter.
	local confirm = button(panel, "Confirm", { Position = UDim2.fromOffset(16, 462), Size = UDim2.new(1, -32, 0, 50), Text = "REBIRTH", TextScaled = true })
	new("UITextSizeConstraint", confirm, { MinTextSize = 15, MaxTextSize = 24 })
	text(panel, "Footer", { Position = UDim2.fromOffset(16, 516), Size = UDim2.new(1, -32, 0, 34), Font = Enum.Font.GothamMedium, TextSize = 14, TextWrapped = true, TextStrokeTransparency = 1, TextColor3 = MUTED, Text = "" })
	local divider = new("Frame", panel, { Name = "PremiumDivider", Position = UDim2.fromOffset(16, 554), Size = UDim2.new(1, -32, 0, 18), BackgroundTransparency = 1 })
	new("Frame", divider, { Name = "SkinLineLeft", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.new(0.5, -48, 0, 2), BackgroundColor3 = GOLD, BackgroundTransparency = 0.3, BorderSizePixel = 0 })
	new("Frame", divider, { Name = "SkinLineRight", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromScale(1, 0.5), Size = UDim2.new(0.5, -48, 0, 2), BackgroundColor3 = GOLD, BackgroundTransparency = 0.3, BorderSizePixel = 0 })
	text(divider, "Label", { Size = UDim2.fromScale(1, 1), Text = "PREMIUM", TextSize = 14, TextColor3 = GOLD })
	local keepButton = button(panel, "Keep", { Position = UDim2.fromOffset(16, 580), Size = UDim2.new(1, -32, 0, 44), Text = "REBIRTH & KEEP EVERYTHING", TextScaled = true, BackgroundColor3 = GOLD })
	new("UITextSizeConstraint", keepButton, { MinTextSize = 11, MaxTextSize = 18 })
	return gui
end

Menu.LAYOUT = 2 -- bumped when the panel's controls change; an older authored copy is replaced by RebirthController

return Menu
