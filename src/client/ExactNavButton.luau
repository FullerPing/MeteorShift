--!strict
-- Clone the user's authored design. Appearance comes from StarterGui, not a skin.
local StarterGui = game:GetService("StarterGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HudIcons = require(ReplicatedStorage.Shared.Config.HudIcons)
local ExactNavButton = {}
local REFERENCE = "MY index button"
-- player attributes the full-screen menus set while open (the small Backpack popup leaves the tiles live)
local MenuFlags = require(script.Parent.MenuFlags)
local MENU_ATTRIBUTES = MenuFlags.except("BackpackOpen")

function ExactNavButton.author(parent: Instance, name: string, label: string, icon: string): TextButton
	local reference = StarterGui:FindFirstChild(REFERENCE)
	assert(reference and reference:IsA("ScreenGui"), "Missing StarterGui." .. REFERENCE)
	local source = reference:FindFirstChild("Frame")
	assert(source and source:IsA("Frame"), "Missing authored button Frame")
	local face: ImageLabel? = nil
	for _, child in source:GetChildren() do
		if child:IsA("ImageLabel") and child.Name ~= "Shadow" and child.Image == "rbxassetid://6927295847" then face = child end
	end
	assert(face, "Missing authored stud face")
	local sourceSize = source.Size
	local origin = Vector2.new(face.Position.X.Scale * sourceSize.X.Offset + face.Position.X.Offset,
		face.Position.Y.Scale * sourceSize.Y.Offset + face.Position.Y.Offset)
	local previous = parent:FindFirstChild(name)
	local previousPosition = if previous and previous:IsA("GuiObject") then previous.Position else UDim2.new()
	local button = Instance.new("TextButton")
	button.Name, button.Text = name, ""
	button.Position, button.Size = previousPosition, UDim2.fromOffset(80, 80)
	button.BackgroundTransparency, button.BorderSizePixel, button.AutoButtonColor = 1, 0, false
	button.Active, button.Selectable, button.ZIndex = true, true, 1
	local design = source:Clone()
	design.Name, design.AnchorPoint = "Design", Vector2.zero
	design.Position, design.Size = UDim2.new(), UDim2.fromOffset(80, 80)
	for _, child in design:GetChildren() do
		if child:IsA("GuiObject") then
			-- Remove only the reference's canvas offset; preserve every layer's pixels.
			child.Position = UDim2.fromOffset(child.Position.X.Scale * sourceSize.X.Offset + child.Position.X.Offset - origin.X,
				child.Position.Y.Scale * sourceSize.Y.Offset + child.Position.Y.Offset - origin.Y)
		end
		if child:IsA("TextLabel") then child.Name, child.Text = "Caption", label
		elseif child:IsA("ImageLabel") and child.ZIndex == 5 then
			child.Name = "Icon"
			if name ~= "IndexButton" then child.Image = icon end
		elseif child:IsA("ImageLabel") and child.Name ~= "Shadow" then child.Name = "StudFace"
		elseif child:IsA("Frame") then child.Name = "ColorOverlay" end
	end
	design.Parent = button
	local scale = Instance.new("UIScale"); scale.Name, scale.Parent = "LayoutScale", button
	local badge = Instance.new("Frame")
	badge.Name, badge.Visible, badge.Size = "ReadyBadge", false, UDim2.fromOffset(9, 9)
	badge.AnchorPoint, badge.Position = Vector2.new(1, 0), UDim2.new(1, -4, 0, 4)
	badge.BackgroundColor3, badge.BorderSizePixel, badge.ZIndex = Color3.fromRGB(139, 240, 195), 0, 101
	badge.Parent = button
	local tooltip = Instance.new("TextLabel")
	tooltip.Name, tooltip.Text, tooltip.Visible = "Tooltip", label, false
	tooltip.Position, tooltip.Size = UDim2.new(1, 12, .5, -16), UDim2.fromOffset(102, 32)
	tooltip.BackgroundColor3, tooltip.BorderSizePixel = Color3.fromRGB(29, 30, 35), 0
	tooltip.Font, tooltip.TextSize, tooltip.TextColor3 = Enum.Font.FredokaOne, 14, Color3.new(1, 1, 1)
	tooltip.TextStrokeColor3, tooltip.TextStrokeTransparency, tooltip.ZIndex = Color3.new(), .55, 101
	tooltip.Parent = button
	if previous then previous:Destroy() end
	button.Parent = parent
	return button
end

-- Colour-coded cartoon tiles, like the side buttons in the style references:
-- glossy face, thick ink outline, icon with a drop shadow, caption over the
-- bottom edge. The authored Design stays inside the button (hidden) so its
-- icon and caption remain the source of truth and Studio edits still apply.
-- Experiment: no box around the side-button icons, a bigger icon instead. Set false to bring the tiles back.
local BOXLESS = true
local TILE_KINDS ={ ShopButton = "orange", RebirthButton = "purple", StoreButton = "green", IndexButton = "blue", PetsButton = "red", DailyButton = "gold", CodesButton = "blue" }

-- The prefab buttons no longer carry a "Design" frame (only Gear's still does, and the runtime-authored Pets
-- button): without one, the icon and caption come from here.
local TILE_ICONS = { ShopButton = "equipment", RebirthButton = "rebirth", StoreButton = "store", IndexButton = "index", PetsButton = "pets", DailyButton = "daily", CodesButton = "codes" }
local TILE_CAPTIONS = { ShopButton = "Gear", RebirthButton = "Rebirth", StoreButton = "Store", IndexButton = "Index", PetsButton = "Pets", DailyButton = "Daily", CodesButton = "Codes" }

local function cartoonTile(button: TextButton, design: Frame?, iconOverride: string?, captionOverride: string?)
	local Cartoon = require(script.Parent.Cartoon)
	local caption = if design then design:FindFirstChild("Caption") :: TextLabel? else nil
	local source = if design then design:FindFirstChild("Icon") :: ImageLabel? else nil
	local tile = Instance.new("Frame")
	tile.Name, tile.Size, tile.BackgroundTransparency, tile.ZIndex = "CartoonTile", UDim2.fromOffset(80, 80), 1, 1
	tile.Active = false
	if not BOXLESS then
		Cartoon.surface(TILE_KINDS[button.Name] or "blue", { radius = 16, edge = 3, lip = 5, studs = 0.84, studSize = 27 }).Parent = tile
	end
	local image = iconOverride or (if source then source.Image else HudIcons[TILE_ICONS[button.Name] or ""] or "")
	-- Boxless: the icon is drawn big with an ink outline (four offset copies) and a drop shadow instead
	local glyphSize = if BOXLESS then 74 else 56
	local layers = if BOXLESS
		then { Vector2.new(0, 4), Vector2.new(-2, 0), Vector2.new(2, 0), Vector2.new(0, -2), Vector2.new(0, 2), Vector2.zero }
		else { Vector2.new(0, 3), Vector2.zero }
	for index, offset in layers do
		local top = index == #layers
		local glyph = Instance.new("ImageLabel")
		glyph.Name = if top then "Icon" elseif index == 1 then "IconShadow" else "IconOutline" .. index
		glyph.AnchorPoint, glyph.Position = Vector2.new(0.5, 0.5), UDim2.new(0.5, offset.X, if BOXLESS then 0.4 else 0.42, offset.Y - 4)
		glyph.Size, glyph.BackgroundTransparency, glyph.ScaleType = UDim2.fromOffset(glyphSize, glyphSize), 1, Enum.ScaleType.Fit
		glyph.Image, glyph.ZIndex = image, 2 + index
		glyph.ImageColor3 = if top then Color3.new(1, 1, 1) else Cartoon.INK
		glyph.ImageTransparency = if index == 1 then 0.55 elseif top then 0 else (if BOXLESS then 0.1 else 0)
		glyph.Parent = tile
	end
	local label = Instance.new("TextLabel")
	label.Name, label.BackgroundTransparency = "Caption", 1
	label.AnchorPoint, label.Position, label.Size = Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, if BOXLESS then 58 else 52), UDim2.fromOffset(110, 30)
	label.Font, label.TextSize, label.TextColor3 = Cartoon.FONT, 23, Color3.new(1, 1, 1)
	label.Text, label.ZIndex = captionOverride or (if caption then caption.Text else TILE_CAPTIONS[button.Name] or button.Name), 5
	Cartoon.textStroke(3).Parent = label
	label.Parent = tile
	if design then design.Visible = false end
	tile.Parent = button
end

-- Draws the same tile (CartoonTile, 80 x 80) on any button with one of the owner's icons and a caption, for buttons
-- that are not menu buttons (the Offers): scale it with a UIScale for other sizes
function ExactNavButton.tile(button: TextButton, icon: string, caption: string): Frame
	cartoonTile(button, nil, HudIcons[icon] or icon, caption)
	return button:FindFirstChild("CartoonTile") :: Frame
end

function ExactNavButton.bind(button: TextButton)
	local design = button:FindFirstChild("Design") :: Frame?
	if not button:FindFirstChild("CartoonTile") then cartoonTile(button, design) end
	local tile = button:FindFirstChild("CartoonTile") :: Frame?
	-- the badge rides inside the tile, so hiding the tile under an open menu hides the badge too
	local badge = ((if tile then tile:FindFirstChild("ReadyBadge") else nil) or button:WaitForChild("ReadyBadge")) :: Frame
	if tile then badge.Parent = tile end
	if not badge:FindFirstChildOfClass("UIStroke") then
		local round = Instance.new("UICorner"); round.CornerRadius, round.Parent = UDim.new(0.5, 0), badge
		local ink = Instance.new("UIStroke"); ink.Color, ink.Thickness, ink.Parent = Color3.fromRGB(14, 24, 52), 2, badge
		badge.Size, badge.Position = UDim2.fromOffset(16, 16), UDim2.new(1, 4, 0, -6)
		badge.BackgroundColor3 = Color3.fromRGB(255, 60, 80)
	end
	-- Each menu lives in its own ScreenGui, so a higher DisplayOrder would draw this tile over another open
	-- menu: hide the tile (and take no taps) while any full menu is open. Its own controller still hides the
	-- button outright while its own menu is open.
	local player = game:GetService("Players").LocalPlayer
	local function covered()
		local open = MenuFlags.anyOpen(MENU_ATTRIBUTES)
		if tile then tile.Visible = not open end
		button.Interactable = not open
	end
	for _, name in MENU_ATTRIBUTES do player:GetAttributeChangedSignal(name):Connect(covered) end
	covered()
	-- the tile lifts under the pointer and dips while pressed (position only, so its text never re-sizes; off with Reduce Effects)
	if tile and not button:GetAttribute("Pressable") then
		button:SetAttribute("Pressable", true)
		local TweenService = game:GetService("TweenService")
		local feel = TweenInfo.new(0.09, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		local hovered, held = false, false
		local function go()
			local target = UDim2.fromOffset(0, if held then 3 elseif hovered then -2 else 0)
			if player:GetAttribute("ReduceEffects") == true then tile.Position = target else TweenService:Create(tile, feel, { Position = target }):Play() end
		end
		local function isPress(input: InputObject): boolean
			return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch or input.KeyCode == Enum.KeyCode.ButtonA
		end
		button.MouseEnter:Connect(function() hovered = true; go() end)
		button.MouseLeave:Connect(function() hovered, held = false, false; go() end)
		button.InputBegan:Connect(function(input) if isPress(input) then held = true; go() end end)
		button.InputEnded:Connect(function(input) if isPress(input) then held = false; go() end end)
	end
	local tooltip = button:WaitForChild("Tooltip") :: TextLabel
	if not tooltip:FindFirstChild("TextOutline") then
		local Cartoon = require(script.Parent.Cartoon)
		tooltip.BackgroundColor3, tooltip.TextSize = Color3.fromRGB(30, 104, 232), 16
		local round = Instance.new("UICorner"); round.CornerRadius, round.Parent = UDim.new(0, 10), tooltip
		local edge = Instance.new("UIStroke"); edge.Color, edge.Thickness = Cartoon.INK, 3
		edge.ApplyStrokeMode, edge.Parent = Enum.ApplyStrokeMode.Border, tooltip
		Cartoon.outlineLabel(tooltip, 2)
	end
	return {
		caption = (button:FindFirstChild("CartoonTile") :: Frame):WaitForChild("Caption") :: TextLabel,
		tooltip = button:WaitForChild("Tooltip") :: TextLabel,
		badge = badge,
		scale = button:WaitForChild("LayoutScale") :: UIScale,
	}
end

function ExactNavButton.layout(button: TextButton, hud: any, key: string)
	local rect = hud.buttons[key]
	button.AnchorPoint = Vector2.zero
	button.Position, button.Size = UDim2.fromOffset(rect.x, rect.y), UDim2.fromOffset(80, 80)
	local scale = button:FindFirstChild("LayoutScale") :: UIScale
	scale.Scale = rect.w / 80
end

return ExactNavButton
