--!strict
-- The "cartoon light" look for native menus (the Gear Shop and Pets), from Shared.MenuPalette and the owner's mockup of
-- 2026-10-13: a white-to-pale-blue body outlined in navy with a lip, a blue title ribbon poking out of its top left, a red
-- Close on the top right corner, chunky buttons (a gradient face with a soft gloss band, a navy outline and lip) and
-- FredokaOne everywhere, white with an ink outline on the blue and red pieces. Builders return plain Instances.
-- Everything it makes sits under a frame marked CartoonCustom, which MenuSkin leaves alone.
local RS = game:GetService("ReplicatedStorage")
local Palette = require(RS.Shared.MenuPalette)
local N = require(script.Parent.NativeUI)

local MenuTheme = {}
MenuTheme.TITLE_FONT = Enum.Font.FredokaOne
MenuTheme.BODY_FONT = Enum.Font.FredokaOne
MenuTheme.CUSTOM = "CartoonCustom"

export type Kind = "lime" | "face" | "orange" | "gold" | "wallet" | "close" | "red" | "blue" | "tabOn" | "tabOff"

-- each kind of button: its face gradient, its text colour and whether that text gets the ink outline
type Look = { top: Color3, bottom: Color3, text: Color3, ink: boolean, gloss: number }
local P = Palette
local KINDS: { [string]: Look } = {
	lime = { top = P.LIME_TOP, bottom = P.LIME_BOTTOM, text = P.NAVY, ink = false, gloss = 0.5 },
	face = { top = P.GREY_TOP, bottom = P.GREY_BOTTOM, text = P.NAVY, ink = false, gloss = 0.8 },
	gold = { top = P.GOLD_TOP, bottom = P.GOLD_BOTTOM, text = P.NAVY, ink = false, gloss = 0.45 },
	wallet = { top = P.GOLD_TOP, bottom = P.GOLD_BOTTOM, text = P.NAVY, ink = false, gloss = 0.45 },
	red = { top = P.RED_TOP, bottom = P.RED_BOTTOM, text = P.WHITE, ink = true, gloss = 0.5 },
	blue = { top = P.BLUE_TOP, bottom = P.BLUE_BOTTOM, text = P.WHITE, ink = true, gloss = 0.5 },
	tabOff = { top = P.OFF_TOP, bottom = P.OFF_BOTTOM, text = P.NAVY, ink = false, gloss = 0.75 },
}
KINDS.orange, KINDS.close, KINDS.tabOn = KINDS.gold, KINDS.red, KINDS.blue

function MenuTheme.round(node: Instance, radius: number)
	local corner = node:FindFirstChildOfClass("UICorner") or N.create("UICorner", {}, node)
	corner.CornerRadius = UDim.new(0, radius)
end

function MenuTheme.stroke(node: Instance, color: Color3, thickness: number, transparency: number?)
	local stroke = node:FindFirstChildOfClass("UIStroke") or N.create("UIStroke", { ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, node)
	stroke.Color, stroke.Thickness, stroke.Transparency, stroke.LineJoinMode = color, thickness, transparency or 0, Enum.LineJoinMode.Round
end

-- A UIGradient's colours are MULTIPLIED with the object's own colour, so the object goes white and the gradient carries
-- the colours (setting both would apply them twice and come out darker and more saturated).
function MenuTheme.gradient(node: Instance, top: Color3, bottom: Color3)
	local gradient = node:FindFirstChildOfClass("UIGradient") or N.create("UIGradient", {}, node)
	gradient.Rotation, gradient.Color = 90, ColorSequence.new(top, bottom)
	if node:IsA("GuiObject") then node.BackgroundColor3 = Color3.new(1, 1, 1) end
end

-- The thick ink outline on white text (a UIStroke on the text, much bolder than TextStroke)
function MenuTheme.ink(label: TextLabel, on: boolean, thickness: number?)
	local stroke = label:FindFirstChild("TextInk") :: UIStroke?
	if not stroke then
		if not on then return end
		stroke = N.create("UIStroke", { Name = "TextInk", Color = Palette.INK, LineJoinMode = Enum.LineJoinMode.Round }, label)
	end
	local s = stroke :: UIStroke
	s.Enabled, s.Thickness = on, thickness or 2
end

-- The highlight on a chunky face: a soft band over its top part, fading from white to clear, inset so it never touches
-- the rounded corners. `strength` is the band's transparency at its top (0 = solid white, 1 = none).
function MenuTheme.gloss(face: GuiObject, strength: number, radius: number?)
	local band = face:FindFirstChild("Gloss") :: Frame?
	if not band then
		band = N.create("Frame", { Name = "Gloss", Position = UDim2.fromOffset(3, 2), Size = UDim2.new(1, -6, 0.46, 0), BackgroundColor3 = Palette.WHITE,
			BorderSizePixel = 0, ZIndex = face.ZIndex, Active = false }, face)
		MenuTheme.round(band :: Frame, radius or 6)
		N.create("UIGradient", { Name = "Fade", Rotation = 90 }, band)
	end
	local fade = (band :: Frame):FindFirstChild("Fade") :: UIGradient
	fade.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, strength), NumberSequenceKeypoint.new(0.7, math.min(1, strength + 0.35)),
		NumberSequenceKeypoint.new(1, 1) })
	return band :: Frame
end

-- A menu: the frame itself is a navy slab (the outline and the lip along the bottom) and its Body child, white fading to pale
-- blue, sits on it 7 px short of the bottom. (With Sibling z-order children always draw over their parent, so the lip has to be
-- the parent, not a child.) Everything else goes in the frame at ZIndex 2 and up, over the Body. Marked so MenuSkin skips it.
-- ClipsDescendants stays off: the title ribbon and Close stick out of it.
MenuTheme.LIP = 7
function MenuTheme.panel(parent: Instance, name: string, size: UDim2): Frame
	local panel = N.create("Frame", { Name = name, Size = size, BackgroundColor3 = Palette.NAVY, BorderSizePixel = 0, Active = true, ZIndex = 1 }, parent)
	panel:SetAttribute(MenuTheme.CUSTOM, true)
	MenuTheme.round(panel, 18)
	local body = N.create("Frame", { Name = "Body", Size = UDim2.new(1, 0, 1, -MenuTheme.LIP), BorderSizePixel = 0, ZIndex = 1 }, panel)
	MenuTheme.round(body, 18)
	MenuTheme.stroke(body, Palette.NAVY, 4)
	MenuTheme.gradient(body, Palette.BODY_TOP, Palette.BODY_BOTTOM)
	return panel
end

-- A filled block with an optional vertical gradient (top to bottom).
function MenuTheme.card(parent: Instance, name: string, top: Color3, bottom: Color3?, radius: number?): Frame
	local card = N.create("Frame", { Name = name, BackgroundColor3 = top, BorderSizePixel = 0, ZIndex = 2 }, parent)
	MenuTheme.round(card, radius or 10)
	if bottom then MenuTheme.gradient(card, top, bottom) end
	return card
end

-- Flat text in FredokaOne. Pass `align` for anything but left-aligned.
function MenuTheme.label(parent: Instance, name: string, text: string, size: number, color: Color3, font: Enum.Font?, align: Enum.TextXAlignment?): TextLabel
	return N.create("TextLabel", {
		Name = name, Text = text, Size = UDim2.fromOffset(100, size + 6), BackgroundTransparency = 1,
		Font = font or MenuTheme.BODY_FONT, TextSize = size, TextColor3 = color,
		TextXAlignment = align or Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center, ZIndex = 5,
	}, parent)
end

-- A small rounded tag ("Tier 1 / 8", "LEVEL 1", "Equipped 1 / 1"): a fill, an outline and centred text in Label
function MenuTheme.pill(parent: Instance, name: string, fill: Color3, edge: Color3, textColor: Color3, size: number): Frame
	local pill = N.create("Frame", { Name = name, Size = UDim2.fromOffset(80, 22), BackgroundColor3 = fill, BorderSizePixel = 0, ZIndex = 6 }, parent)
	MenuTheme.round(pill, 8)
	MenuTheme.stroke(pill, edge, 2)
	local label = MenuTheme.label(pill, "Label", "", size, textColor, nil, Enum.TextXAlignment.Center)
	label.Size, label.ZIndex, label.TextScaled = UDim2.fromScale(1, 1), 7, true
	N.create("UITextSizeConstraint", { MinTextSize = 8, MaxTextSize = size }, label)
	N.create("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6), PaddingTop = UDim.new(0, 2), PaddingBottom = UDim.new(0, 2) }, label)
	return pill
end

-- A chunky button. The TextButton itself is the navy outline and lip; its Face child is the coloured part (a gradient and
-- the gloss band) and its Label (on the Face) shows the text, mirroring the button's Text and TextSize, so a controller
-- sets those as usual.
function MenuTheme.button(parent: Instance, name: string, text: string, kind: Kind, size: number?): TextButton
	local button = N.create("TextButton", {
		Name = name, Text = text, Size = UDim2.fromOffset(100, 40), BackgroundColor3 = Palette.NAVY, BorderSizePixel = 0, ZIndex = 4,
		Font = MenuTheme.TITLE_FONT, TextSize = size or 18, AutoButtonColor = false, TextTransparency = 1,
	}, parent)
	MenuTheme.round(button, 10)
	local face = N.create("Frame", { Name = "Face", Position = UDim2.fromOffset(3, 3), Size = UDim2.new(1, -6, 1, -10), BorderSizePixel = 0, ZIndex = 5,
		Active = false }, button)
	MenuTheme.round(face, 8)
	N.create("UIGradient", { Rotation = 90 }, face)
	MenuTheme.gloss(face, 0.5)
	local label = N.create("TextLabel", { Name = "Label", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Font = MenuTheme.TITLE_FONT,
		TextScaled = true, ZIndex = 7, Active = false }, face)
	local limit = N.create("UITextSizeConstraint", { MinTextSize = 8, MaxTextSize = size or 18 }, label)
	N.create("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6), PaddingTop = UDim.new(0, 2), PaddingBottom = UDim.new(0, 2) }, label)
	local function sync()
		button.TextTransparency = 1
		label.Text = button.Text
		limit.MaxTextSize = button.TextSize
	end
	button:GetPropertyChangedSignal("Text"):Connect(sync)
	button:GetPropertyChangedSignal("TextSize"):Connect(sync)
	sync()
	MenuTheme.paint(button, kind)
	return button
end

-- Colours a chunky button for its kind. One that cannot be pressed (`enabled` false) shows the plain grey face.
function MenuTheme.paint(button: GuiButton, kind: Kind, enabled: boolean?)
	local look = KINDS[if enabled == false then "face" else kind] or KINDS.face
	local face = button:FindFirstChild("Face") :: Frame?
	if not face then
		button.BackgroundColor3 = look.bottom
		if button:IsA("TextButton") then button.TextColor3 = look.text end
	else
		face.BackgroundColor3 = Palette.WHITE
		local shade = face:FindFirstChildOfClass("UIGradient")
		if shade then shade.Color = ColorSequence.new(look.top, look.bottom) end
		MenuTheme.gloss(face, look.gloss)
		local label = face:FindFirstChild("Label") :: TextLabel
		label.TextColor3 = look.text
		MenuTheme.ink(label, look.ink, 2)
		button.BackgroundColor3 = Palette.NAVY
	end
	if enabled ~= nil then button.Active, button.Selectable = enabled, enabled end
end

-- A button that is either available (in `kind`) or not (the plain face).
function MenuTheme.state(button: GuiButton, enabled: boolean, kind: Kind)
	MenuTheme.paint(button, kind, enabled)
end

-- A tab: lit blue when selected.
function MenuTheme.tab(button: GuiButton, selected: boolean)
	MenuTheme.paint(button, if selected then "tabOn" else "tabOff")
end

-- A choice among a few (1x / 10x / MAX): a chunky button, lime when selected
function MenuTheme.select(button: GuiButton, selected: boolean)
	MenuTheme.paint(button, if selected then "lime" else "tabOff")
end

-- The title ribbon: a blue tab poking out of the panel's top left, tilted a touch, with the owner's icon and the title
-- in white with an ink outline. It is named Ribbon; its Title and Icon are children.
function MenuTheme.ribbon(panel: Instance, title: string, icon: string): Frame
	local ribbon = N.create("Frame", { Name = "Ribbon", Position = UDim2.fromOffset(10, -24), Size = UDim2.fromOffset(256, 66), Rotation = -1.5,
		BackgroundColor3 = Palette.NAVY, BorderSizePixel = 0, ZIndex = 8 }, panel)
	MenuTheme.round(ribbon, 14)
	local face = N.create("Frame", { Name = "Face", Position = UDim2.fromOffset(4, 4), Size = UDim2.new(1, -8, 1, -12), BackgroundColor3 = Palette.WHITE,
		BorderSizePixel = 0, ZIndex = 9 }, ribbon)
	MenuTheme.round(face, 11)
	MenuTheme.gradient(face, Palette.BLUE_TOP, Palette.BLUE_BOTTOM)
	MenuTheme.gloss(face, 0.45, 9).ZIndex = 9
	N.create("ImageLabel", { Name = "Icon", Image = icon, BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 10, 0.5, 0),
		Size = UDim2.fromOffset(44, 44), ScaleType = Enum.ScaleType.Fit, ZIndex = 11 }, face)
	local label = MenuTheme.label(face, "Title", title, 30, Palette.WHITE, MenuTheme.TITLE_FONT)
	label.Position, label.Size, label.ZIndex, label.TextScaled = UDim2.fromOffset(60, 0), UDim2.new(1, -68, 1, 0), 11, true
	N.create("UITextSizeConstraint", { MinTextSize = 12, MaxTextSize = 30 }, label)
	MenuTheme.ink(label, true, 3)
	return ribbon
end

-- Close: a red chunky button on the panel's top right corner, half outside it, with the owner's close icon
function MenuTheme.closeCorner(panel: Instance, icon: string): TextButton
	local close = MenuTheme.button(panel, "Close", "", "red", 24)
	close.AnchorPoint, close.Position, close.Size, close.ZIndex = Vector2.new(1, 0), UDim2.new(1, 8, 0, -14), UDim2.fromOffset(48, 50), 8
	local face = close:FindFirstChild("Face") :: Frame
	face.ZIndex = 9
	N.create("ImageLabel", { Name = "Icon", Image = icon, BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.62, 0.62), ScaleType = Enum.ScaleType.Fit, ZIndex = 11 }, face)
	return close
end

-- A wallet chip on the body: a pale fill, a navy outline, the owner's icon on the left and the amount (the chip's Text)
function MenuTheme.chip(parent: Instance, name: string, icon: string, fill: Color3): TextLabel
	local chip = N.create("TextLabel", { Name = name, Text = "", Size = UDim2.fromOffset(150, 32), BackgroundColor3 = fill, BorderSizePixel = 0, ZIndex = 6,
		Font = MenuTheme.TITLE_FONT, TextSize = 17, TextColor3 = Palette.NAVY, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left }, parent)
	MenuTheme.round(chip, 10)
	MenuTheme.stroke(chip, Palette.NAVY, 2.5)
	N.create("UITextSizeConstraint", { MinTextSize = 9, MaxTextSize = 17 }, chip)
	N.create("UIPadding", { PaddingLeft = UDim.new(0, 40), PaddingRight = UDim.new(0, 10), PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4) }, chip)
	-- the UIPadding moves children too: -34 puts the icon 6 px from the chip's real left edge, clear of the text
	N.create("ImageLabel", { Name = "Icon", Image = icon, BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, -34, 0.5, 0),
		Size = UDim2.fromOffset(28, 28), ScaleType = Enum.ScaleType.Fit, ZIndex = 7 }, chip)
	return chip
end

-- A preview well: a rounded block fading top to bottom with an outline, an ellipse shadow near its bottom and a
-- ViewportFrame (Preview) on top.
function MenuTheme.well(parent: Instance, name: string, top: Color3, bottom: Color3, edge: Color3, shadow: Color3, shadowWidth: number, shadowY: number): Frame
	local frame = N.create("Frame", { Name = name, Size = UDim2.fromOffset(150, 150), BorderSizePixel = 0, ZIndex = 3 }, parent)
	MenuTheme.round(frame, 14)
	MenuTheme.gradient(frame, top, bottom)
	MenuTheme.stroke(frame, edge, 2.5)
	local ellipse = N.create("Frame", { Name = "Shadow", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, shadowY),
		Size = UDim2.fromScale(shadowWidth, 0.09), BackgroundColor3 = shadow, BackgroundTransparency = 0.45, BorderSizePixel = 0, ZIndex = 3 }, frame)
	MenuTheme.round(ellipse, 100)
	local view = N.create("ViewportFrame", { Name = "Preview", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0,
		Ambient = Color3.fromRGB(195, 201, 220), LightColor = Color3.fromRGB(255, 240, 216), LightDirection = Vector3.new(1, -1, 2), ZIndex = 4 }, frame)
	MenuTheme.round(view, 14)
	return frame
end

-- A rounded track with an outline and a Fill child; the controller sets the fill's width as a scale.
function MenuTheme.bar(parent: Instance, name: string, fill: Color3?): Frame
	local track = N.create("Frame", { Name = name, Size = UDim2.fromOffset(100, 8), BackgroundColor3 = Palette.BAR_TRACK, BorderSizePixel = 0, ZIndex = 4 }, parent)
	MenuTheme.round(track, 5)
	MenuTheme.stroke(track, Palette.NAVY, 1.5, 0.4)
	local bar = N.create("Frame", { Name = "Fill", Size = UDim2.fromScale(0, 1), BackgroundColor3 = fill or Palette.BAR_FILL, BorderSizePixel = 0, ZIndex = 5 }, track)
	MenuTheme.round(bar, 5)
	return track
end

-- A thin divider line between rows
function MenuTheme.divider(parent: Instance, name: string): Frame
	return N.create("Frame", { Name = name, Size = UDim2.new(1, 0, 0, 2), BackgroundColor3 = Palette.DIVIDER, BorderSizePixel = 0, ZIndex = 4 }, parent)
end

return MenuTheme
