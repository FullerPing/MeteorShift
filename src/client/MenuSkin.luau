--!strict
-- Runtime cartoon skin for the Studio-authored menus (GearShop, RefineryMenu,
-- MineralIndex, Rebirth, Store, PetHatch, HudSettings, BackpackMenu, WelcomeBack).
--
-- The prefabs keep their names, layout and bindings; this only restyles them
-- when NativeUI.get hands one to a controller:
--   * Panel: white body, thick blue border and an ink outline
--   * Header: a tilted glossy ribbon behind the title, sticking out top-left
--   * Close: a glossy red square with a chunky X
--   * Buttons: saturated glossy faces (shine, gloss stripes, lower shade, light
--     rim), ink outline and an outlined label that mirrors the button's Text
--   * Cards and wells: light blue tiles with ink outlines; bars become pills
--   * All text: chunky FredokaOne with a rounded ink outline
-- Colours the controllers assign later (tab states, disabled buttons) are
-- remapped to the cartoon palette as they change. Idempotent and clone-safe:
-- templates cloned at runtime are re-bound through DescendantAdded.

local TextService = game:GetService("TextService")
local Cartoon = require(script.Parent.Cartoon)

local MenuSkin = {}

local INK = Cartoon.INK
local WHITE = Color3.new(1, 1, 1)
local BORDER_BLUE = Color3.fromRGB(28, 96, 214)
local SKINNED = "CartoonSkin"

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end
local function key(color: Color3): string
	return string.format("%d,%d,%d", math.round(color.R * 255), math.round(color.G * 255), math.round(color.B * 255))
end

-- Old charcoal theme -> cartoon palette, by role.
local BUTTON_COLORS: { [string]: Color3 } = {
	["67,69,77"] = rgb(116, 150, 210), -- CARD: inactive tab / neutral
	["29,30,35"] = rgb(132, 144, 166), -- disabled
	["12,18,25"] = rgb(132, 144, 166), -- outline-coloured buttons
	["73,83,94"] = rgb(132, 144, 166), -- disabled / muted
	["43,44,49"] = rgb(116, 150, 210),
	["105,240,103"] = rgb(84, 214, 38), -- GREEN
	["66,190,255"] = rgb(36, 146, 255), -- CYAN
	["255,174,52"] = rgb(255, 146, 28), -- ORANGE
	["235,70,70"] = rgb(238, 36, 64), -- RED
	["255,219,100"] = rgb(255, 196, 36), -- GOLD
	["255,207,55"] = rgb(255, 190, 30), -- CASH
	["139,240,195"] = rgb(48, 214, 140), -- MINT
}
local TILE_COLORS: { [string]: Color3 } = {
	["67,69,77"] = rgb(226, 240, 255), -- CARD
	["43,44,49"] = rgb(150, 196, 250), -- PANEL used for wells
	["29,30,35"] = rgb(44, 92, 178), -- PANEL_DARK
	["73,83,94"] = rgb(190, 204, 224),
}
local BAR_TRACK = rgb(18, 44, 104)

local bound: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any

local function make(class: string, props: { [string]: any }, parent: Instance?): any
	local item = Instance.new(class)
	for name, value in props do (item :: any)[name] = value end
	item.Parent = parent
	return item
end

local function passive(name: string, parent: Instance, props: { [string]: any }): any
	props.Name, props.BorderSizePixel, props.Active, props.Selectable, props.ZIndex = name, 0, false, false, 0
	return make("Frame", props, parent)
end

local function setCorner(node: Instance, radius: UDim)
	local corner = node:FindFirstChildOfClass("UICorner") or make("UICorner", {}, node)
	corner.CornerRadius = radius
end

local function setBorder(node: Instance, color: Color3, thickness: number)
	local stroke: UIStroke? = nil
	for _, child in node:GetChildren() do
		if child:IsA("UIStroke") and child.ApplyStrokeMode == Enum.ApplyStrokeMode.Border then stroke = child end
	end
	if not stroke then
		stroke = make("UIStroke", { ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, node)
	end
	local s = stroke :: UIStroke
	s.Color, s.Thickness, s.Transparency, s.LineJoinMode = color, thickness, 0, Enum.LineJoinMode.Round
end

local function setGradient(node: Instance, top: Color3, bottom: Color3)
	local gradient = node:FindFirstChildOfClass("UIGradient") or make("UIGradient", {}, node)
	gradient.Rotation, gradient.Color = 90, ColorSequence.new(top, bottom)
	gradient.Transparency = NumberSequence.new(0)
end

local function setStuds(node: Instance, transparency: number)
	local texture = node:FindFirstChild("StudTexture")
	if texture and texture:IsA("ImageLabel") then
		texture.ImageTransparency = transparency
		texture.TileSize = UDim2.fromOffset(40, 40)
	end
end

-- Colour-agnostic gloss over any filled surface; the surface's own colour shows through.
local function gloss(node: GuiObject, radius: UDim, stripes: boolean)
	if node:FindFirstChild("SkinShine") then return end
	local inner = UDim.new(radius.Scale, math.max(0, radius.Offset - 3))
	local shine = passive("SkinShine", node, { Position = UDim2.fromOffset(3, 3), Size = UDim2.new(1, -6, 0.48, -3), BackgroundColor3 = WHITE })
	make("UICorner", { CornerRadius = inner }, shine)
	make("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1),
	}) }, shine)
	local shade = passive("SkinShade", node, { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.fromScale(1, 0.34), BackgroundColor3 = Color3.new(0, 0, 0) })
	make("UICorner", { CornerRadius = radius }, shade)
	make("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0.72),
	}) }, shade)
	if stripes then
		local band = passive("SkinStripes", node, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE })
		make("UICorner", { CornerRadius = radius }, band)
		make("UIGradient", { Rotation = -62, Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.52, 1),
			NumberSequenceKeypoint.new(0.521, 0.8), NumberSequenceKeypoint.new(0.62, 0.8),
			NumberSequenceKeypoint.new(0.621, 1), NumberSequenceKeypoint.new(0.68, 1),
			NumberSequenceKeypoint.new(0.681, 0.86), NumberSequenceKeypoint.new(0.72, 0.86),
			NumberSequenceKeypoint.new(0.721, 1), NumberSequenceKeypoint.new(1, 1),
		}) }, band)
	end
	local rim = passive("SkinRim", node, { Position = UDim2.fromOffset(2, 2), Size = UDim2.new(1, -4, 1, -4), BackgroundTransparency = 1 })
	make("UICorner", { CornerRadius = UDim.new(radius.Scale, math.max(0, radius.Offset - 2)) }, rim)
	make("UIStroke", { Color = WHITE, Thickness = 2, Transparency = 0.55, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, rim)
end

local function luminance(color: Color3): number
	return 0.299 * color.R + 0.587 * color.G + 0.114 * color.B
end

local function outlineText(label: TextLabel | TextButton, thickness: number?)
	-- Small body copy was sized for a thin font; give the chunky font room to read.
	if label:GetAttribute("SkinTextSize") == nil then
		label:SetAttribute("SkinTextSize", true)
		if not label.TextScaled and label.TextSize <= 13 then label.TextSize += 2
		elseif not label.TextScaled and label.TextSize <= 15 then label.TextSize += 1 end
	end
	label.Font = Cartoon.FONT
	label.TextStrokeTransparency = 1
	local stroke = label:FindFirstChild("TextOutline") :: UIStroke?
	if not stroke then
		stroke = Cartoon.textStroke(thickness or math.clamp(label.TextSize * 0.12, 1.5, 3.5))
		;(stroke :: UIStroke).Parent = label
	end
	-- Dark text (e.g. ink on a gold tab) reads better without the ink outline.
	(stroke :: UIStroke).Enabled = luminance(label.TextColor3) > 0.35
end

local function remap(node: GuiObject, palette: { [string]: Color3 })
	local mapped = palette[key(node.BackgroundColor3)]
	if mapped then node.BackgroundColor3 = mapped end
end

local function watch(node: GuiObject, palette: { [string]: Color3 })
	node:GetPropertyChangedSignal("BackgroundColor3"):Connect(function() remap(node, palette) end)
end

-- TextButtons draw their own text below their children, so the gloss would
-- cover it. A child label mirrors the button's text above the gloss instead.
local function mirrorText(button: TextButton)
	local label = button:FindFirstChild("SkinLabel") :: TextLabel?
	if not label then
		label = make("TextLabel", {
			Name = "SkinLabel", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 20,
			Active = false, Selectable = false,
		}, button)
		-- Scaled text keeps a margin inside the glossy face and a sane maximum.
		make("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8),
			PaddingTop = UDim.new(0.18, 0), PaddingBottom = UDim.new(0.18, 0) }, label)
		make("UITextSizeConstraint", { MaxTextSize = 26, MinTextSize = 10 }, label)
		label:SetAttribute("SkinTextSize", true)
	end
	local l = label :: TextLabel
	local function sync()
		local text = button.Text
		if text ~= "" then button.TextTransparency = 1 end
		l.Text, l.RichText = text, button.RichText
		l.TextColor3, l.TextSize, l.TextScaled, l.TextWrapped = button.TextColor3, button.TextSize, button.TextScaled, button.TextWrapped
		l.TextXAlignment, l.TextYAlignment, l.LineHeight = button.TextXAlignment, button.TextYAlignment, button.LineHeight
		l.Visible = text ~= ""
		outlineText(l)
	end
	for _, property in { "Text", "TextColor3", "TextSize", "TextScaled", "TextWrapped", "TextXAlignment", "TextYAlignment" } do
		button:GetPropertyChangedSignal(property):Connect(sync)
	end
	sync()
end

local function isBar(node: GuiObject): boolean
	return node.Size.Y.Scale == 0 and node.Size.Y.Offset > 0 and node.Size.Y.Offset <= 12
end

local function skinButton(button: GuiButton, first: boolean)
	-- Clones may carry an old colour set before they were bound; remap every time.
	remap(button, BUTTON_COLORS)
	if first then
		local radius = if button.Name == "Close" or button.Name == "HeaderClose" then UDim.new(0, 10) else UDim.new(0, 12)
		setCorner(button, radius)
		setBorder(button, INK, 3)
		setGradient(button, WHITE, rgb(178, 178, 178))
		setStuds(button, 0.84)
		gloss(button, radius, true)
	end
	watch(button, BUTTON_COLORS)
	if button:IsA("TextButton") then mirrorText(button) end
end

local function skinTile(frame: GuiObject, first: boolean)
	if not isBar(frame) then remap(frame, TILE_COLORS) end
	if first then
		if isBar(frame) then
			local key0 = key(frame.BackgroundColor3)
			if TILE_COLORS[key0] or key0 == "12,18,25" or key0 == "14,24,52" then frame.BackgroundColor3 = BAR_TRACK end
			setCorner(frame, UDim.new(0.5, 0))
			setBorder(frame, INK, 2)
			for _, child in frame:GetChildren() do
				if child:IsA("Frame") then setCorner(child, UDim.new(0.5, 0)) end
			end
			return
		end
		setCorner(frame, UDim.new(0, 12))
		setBorder(frame, INK, 2.5)
		setGradient(frame, WHITE, rgb(222, 230, 244))
		setStuds(frame, 0.93)
	end
	watch(frame, TILE_COLORS)
end

local function skinPanel(panel: GuiObject)
	panel.BackgroundColor3 = rgb(246, 251, 255)
	setCorner(panel, UDim.new(0, 18))
	setBorder(panel, BORDER_BLUE, 6)
	setGradient(panel, WHITE, rgb(208, 228, 252))
	setStuds(panel, 0.95)
	if not panel:FindFirstChild("SkinOuterInk") then
		local outer = passive("SkinOuterInk", panel, { Position = UDim2.fromOffset(-6, -6), Size = UDim2.new(1, 12, 1, 12), BackgroundTransparency = 1 })
		make("UICorner", { CornerRadius = UDim.new(0, 24) }, outer)
		make("UIStroke", { Color = INK, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, outer)
	end
end

local function skinHeader(panel: GuiObject, header: GuiObject)
	local title = panel:FindFirstChild("Title")
	header.BackgroundColor3 = BUTTON_COLORS[key(header.BackgroundColor3)] or header.BackgroundColor3
	header.BackgroundTransparency, header.Rotation, header.ZIndex = 0, -2, 4
	header.ClipsDescendants = false
	setCorner(header, UDim.new(0, 12))
	setBorder(header, INK, 3.5)
	setGradient(header, WHITE, rgb(176, 176, 176))
	setStuds(header, 0.8)
	gloss(header, UDim.new(0, 12), true)
	local divider = header:FindFirstChild("Divider")
	if divider and divider:IsA("GuiObject") then divider.Visible = false end
	local width = 260
	local centred = false
	-- Short popups (the backpack list) get a slimmer ribbon so it doesn't bury them.
	local compact = panel.Size.Y.Scale == 0 and panel.Size.Y.Offset < 160
	local height = if compact then 40 else 60
	local top = if compact then -12 else -16
	if title and title:IsA("TextLabel") then
		title.TextSize = if compact then math.min(title.TextSize, 22) else math.max(title.TextSize, 28)
		title.Rotation, title.ZIndex = -2, math.max(title.ZIndex, 6)
		outlineText(title, 3.5)
		local bounds = TextService:GetTextSize(title.Text, title.TextSize, title.Font, Vector2.new(2000, 200))
		width = title.Position.X.Offset + bounds.X + 56
		centred = title.TextXAlignment == Enum.TextXAlignment.Center
	end
	-- Centre the title (and the Store's icon) on the ribbon, keeping their X.
	-- Layout code may move them again later, so keep them pinned to the ribbon.
	local function centreOnRibbon(item: GuiObject)
		local function apply()
			if item.Size.Y.Scale ~= 0 or item.AnchorPoint.Y ~= 0 then return end
			local y = top + math.floor((height - item.Size.Y.Offset) / 2) - 2
			if item.Position.Y.Scale ~= 0 or item.Position.Y.Offset ~= y then
				item.Position = UDim2.new(item.Position.X.Scale, item.Position.X.Offset, 0, y)
			end
		end
		item:GetPropertyChangedSignal("Position"):Connect(apply)
		item:GetPropertyChangedSignal("Size"):Connect(apply)
		apply()
	end
	if title and title:IsA("TextLabel") then centreOnRibbon(title) end
	local icon = panel:FindFirstChild("HeaderIcon")
	if icon and icon:IsA("GuiObject") then
		icon.ZIndex = math.max(icon.ZIndex, 6); icon.Rotation = -2
		centreOnRibbon(icon)
	end
	if centred then
		width = math.min(width + 40, 420)
		header.AnchorPoint, header.Position, header.Size = Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, top), UDim2.fromOffset(width, height)
	else
		header.AnchorPoint, header.Position, header.Size = Vector2.zero, UDim2.fromOffset(-18, top), UDim2.fromOffset(width + 18, height)
	end
end

-- A menu body: a top-level frame named "...Panel", or one that carries a header
-- (the pet hatch result card).
local function isPanel(frame: Instance): boolean
	return string.sub(frame.Name, -5) == "Panel" or frame:FindFirstChild("Header") ~= nil or frame:FindFirstChild("MenuHeader") ~= nil
end

local function skinNode(node: Instance, gui: ScreenGui)
	if not node:IsA("GuiObject") or bound[node] then return end
	-- The navigation tiles style themselves (ExactNavButton); skip their layers.
	local ancestor: Instance? = node
	while ancestor and ancestor ~= gui do
		local name = ancestor.Name
		if name == "Design" or name == "CartoonTile" or name == "Tooltip" or name == "ReadyBadge" or name == "Dimmer" then return end
		if string.sub(name, 1, 4) == "Skin" or string.sub(name, -8) == "Backdrop" then return end
		ancestor = ancestor.Parent
	end
	if node:IsA("GuiButton") and node.Parent and node.Parent:IsA("ScreenGui") and string.find(node.Name, "Button") then return end
	bound[node] = true
	local first = node:GetAttribute(SKINNED) == nil
	node:SetAttribute(SKINNED, true)
	local parent = node.Parent
	if node:IsA("Frame") and parent == gui and isPanel(node) then
		if first then skinPanel(node) end
		return
	end
	if (node.Name == "Header" or node.Name == "MenuHeader") and parent and parent:IsA("Frame") and parent.Parent == gui and isPanel(parent) then
		if first then skinHeader(parent, node) end
		return
	end
	if node:IsA("TextLabel") then
		if first then
			outlineText(node)
			-- Filled labels (ON/OFF chips, price tags) become small glossy chips.
			if node.BackgroundTransparency < 1 then
				remap(node, BUTTON_COLORS)
				setCorner(node, UDim.new(0, 10))
				setBorder(node, INK, 2.5)
			end
		end
		if node.BackgroundTransparency < 1 then watch(node, BUTTON_COLORS) end
		node:GetPropertyChangedSignal("TextColor3"):Connect(function() outlineText(node) end)
		return
	end
	if node:IsA("GuiButton") then
		if node.BackgroundTransparency < 1 then skinButton(node, first)
		elseif node:IsA("TextButton") and node.Text ~= "" then
			if first then outlineText(node) end
		end
		return
	end
	if node:IsA("ScrollingFrame") then
		node.ScrollBarImageColor3 = BORDER_BLUE
		-- Outlines sit outside each row; a small inset stops the scroll clip
		-- from shaving the first row's top edge.
		if first and not node:FindFirstChildOfClass("UIPadding")
			and node:FindFirstChildOfClass("UIListLayout") then
			make("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4),
				PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4) }, node)
		end
		return
	end
	if node.ClassName == "Frame" and node.BackgroundTransparency < 1 and node.Rotation == 0 and node.Name ~= "Fill" then
		skinTile(node, first)
	end
end

function MenuSkin.apply(gui: ScreenGui)
	if gui:GetAttribute("CartoonSkinBound") then return end
	gui:SetAttribute("CartoonSkinBound", true)
	-- Parents before children: the header needs the title's final font.
	for _, node in gui:GetDescendants() do
		if node.Name == "Title" then skinNode(node, gui) end
	end
	for _, node in gui:GetDescendants() do skinNode(node, gui) end
	gui.DescendantAdded:Connect(function(node)
		-- Wait a frame so a cloned template's children exist before binding.
		task.defer(function()
			if node.Parent then
				skinNode(node, gui)
				for _, child in node:GetDescendants() do skinNode(child, gui) end
			end
		end)
	end)
end

return MenuSkin
