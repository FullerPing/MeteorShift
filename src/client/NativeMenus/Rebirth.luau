--!strict
-- Edit-mode authoring only. Runtime binds the saved StarterGui hierarchy.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Rebirth = require(ReplicatedStorage.Shared.Rebirth)

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

function Menu.build(): ScreenGui
	local gui: ScreenGui = new("ScreenGui", nil, {
		Name = "Rebirth", ResetOnSpawn = false, IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 22,
	})
	gui:SetAttribute("NativePrefab", true)
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
		Name = "Panel", Position = UDim2.fromOffset(440, 180), Size = UDim2.fromOffset(400, 400),
		BackgroundColor3 = PANEL, BorderSizePixel = 0, Visible = false, ZIndex = 3, Active = true,
	})
	border(panel, 6, 4)
	texture(panel, 6, 0.85)
	local header = new("Frame", panel, { Name = "MenuHeader", Size = UDim2.new(1, 0, 0, 56), BackgroundColor3 = GREEN, BorderSizePixel = 0, ZIndex = 0, Active = false, Selectable = false })
	new("UICorner", header, { CornerRadius = UDim.new(0, 6) })
	texture(header, 6, 0.75)
	new("Frame", header, { Name = "Divider", AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 4), BackgroundColor3 = OUTLINE, BorderSizePixel = 0, ZIndex = 0 })
	text(panel, "Title", { Position = UDim2.fromOffset(20, 12), Size = UDim2.new(1, -92, 0, 38), Text = "REBIRTH", TextSize = 26, TextXAlignment = Enum.TextXAlignment.Left })
	local close = button(panel, "Close", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 8), Size = UDim2.fromOffset(44, 44), Text = "", BackgroundColor3 = Color3.fromRGB(235, 70, 70) })
	icon(close, "Icon", "close", { Position = UDim2.fromOffset(12, 12), Size = UDim2.fromOffset(20, 20) })
	local content = new("ScrollingFrame", panel, {
		Name = "Content", Position = UDim2.fromOffset(16, 64), Size = UDim2.new(1, -32, 0, 232), CanvasSize = UDim2.fromOffset(0, 226),
		BackgroundTransparency = 1, BorderSizePixel = 0, ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 3, ScrollBarImageColor3 = GOLD, VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
	})
	local rules = text(content, "Rules", {
		Size = UDim2.new(1, -4, 0, 86), RichText = true, TextWrapped = true, TextScaled = true,
		Text = '<font color="#FF656A">Resets</font> cash, gear, resources and other upgrades.\nYou keep <font color="#FFDB64">refinery levels</font>, <font color="#FFDB64">core shards</font> and <font color="#FFDB64">index bonuses</font>.',
		TextStrokeTransparency = 1, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
	})
	new("UITextSizeConstraint", rules, { MinTextSize = 15, MaxTextSize = 18 })
	text(content, "MultiplierCaption", { Position = UDim2.fromOffset(0, 96), Size = UDim2.new(1, -4, 0, 20), Text = "Bar sale multiplier", TextSize = 18, TextStrokeTransparency = 1 })
	local current = text(content, "CurrentMultiplier", { Position = UDim2.fromOffset(0, 122), Size = UDim2.new(0.4, -4, 0, 68), Text = "1×", TextScaled = true })
	new("UITextSizeConstraint", current, { MinTextSize = 22, MaxTextSize = 56 })
	text(content, "Arrow", { Position = UDim2.new(0.4, 0, 0, 122), Size = UDim2.new(0.2, -4, 0, 68), Text = "→", Font = Enum.Font.GothamBold, TextSize = 40, TextColor3 = GOLD, TextStrokeTransparency = 1 })
	local nextValue = text(content, "NextMultiplier", { Position = UDim2.new(0.6, 0, 0, 122), Size = UDim2.new(0.4, -4, 0, 68), Text = tostring(Rebirth.multiplier(1)) .. "×", TextScaled = true, TextColor3 = GREEN })
	new("UITextSizeConstraint", nextValue, { MinTextSize = 22, MaxTextSize = 56 })
	local cash = text(content, "CashProgress", { Position = UDim2.fromOffset(0, 202), Size = UDim2.new(1, -4, 0, 20), Text = "", TextScaled = true, Font = Enum.Font.GothamMedium, TextStrokeTransparency = 1, TextColor3 = MUTED })
	new("UITextSizeConstraint", cash, { MinTextSize = 10, MaxTextSize = 12 })
	local confirm = button(panel, "Confirm", { Position = UDim2.fromOffset(16, 308), Size = UDim2.new(1, -32, 0, 48), Text = "Rebirth", TextScaled = true })
	new("UITextSizeConstraint", confirm, { MinTextSize = 15, MaxTextSize = 23 })
	text(panel, "Footer", { Position = UDim2.fromOffset(16, 362), Size = UDim2.new(1, -32, 0, 26), Font = Enum.Font.GothamMedium, TextSize = 11, TextWrapped = true, TextStrokeTransparency = 1, TextColor3 = MUTED, Text = "Index bonuses stay and stack with this multiplier." })
	return gui
end

return Menu
