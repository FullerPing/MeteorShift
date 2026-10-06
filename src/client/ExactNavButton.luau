--!strict
-- Clone the user's authored design. Appearance comes from StarterGui, not a skin.
local StarterGui = game:GetService("StarterGui")
local ExactNavButton = {}
local REFERENCE = "MY index button"

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
local TILE_KINDS = { ShopButton = "orange", RebirthButton = "purple", StoreButton = "green", IndexButton = "blue" }

local function cartoonTile(button: TextButton, design: Frame)
	local Cartoon = require(script.Parent.Cartoon)
	local caption = design:FindFirstChild("Caption") :: TextLabel?
	local source = design:FindFirstChild("Icon") :: ImageLabel?
	local tile = Instance.new("Frame")
	tile.Name, tile.Size, tile.BackgroundTransparency, tile.ZIndex = "CartoonTile", UDim2.fromOffset(80, 80), 1, 1
	tile.Active = false
	Cartoon.surface(TILE_KINDS[button.Name] or "blue", { radius = 16, edge = 3, lip = 5, studs = 0.84, studSize = 27 }).Parent = tile
	local image = if source then source.Image else ""
	for index, offset in { Vector2.new(0, 3), Vector2.zero } do
		local glyph = Instance.new("ImageLabel")
		glyph.Name = if index == 1 then "IconShadow" else "Icon"
		glyph.AnchorPoint, glyph.Position = Vector2.new(0.5, 0.5), UDim2.new(0.5, offset.X, 0.42, offset.Y - 4)
		glyph.Size, glyph.BackgroundTransparency, glyph.ScaleType = UDim2.fromOffset(56, 56), 1, Enum.ScaleType.Fit
		glyph.Image, glyph.ZIndex = image, 2 + index
		glyph.ImageColor3 = if index == 1 then Cartoon.INK else Color3.new(1, 1, 1)
		glyph.ImageTransparency = if index == 1 then 0.55 else 0
		glyph.Parent = tile
	end
	local label = Instance.new("TextLabel")
	label.Name, label.BackgroundTransparency = "Caption", 1
	label.AnchorPoint, label.Position, label.Size = Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, 52), UDim2.fromOffset(110, 30)
	label.Font, label.TextSize, label.TextColor3 = Cartoon.FONT, 23, Color3.new(1, 1, 1)
	label.Text, label.ZIndex = if caption then caption.Text else button.Name, 5
	Cartoon.textStroke(3).Parent = label
	label.Parent = tile
	design.Visible = false
	tile.Parent = button
end

function ExactNavButton.bind(button: TextButton)
	local design = button:WaitForChild("Design") :: Frame
	if not button:FindFirstChild("CartoonTile") then cartoonTile(button, design) end
	local badge = button:WaitForChild("ReadyBadge") :: Frame
	if not badge:FindFirstChildOfClass("UIStroke") then
		local round = Instance.new("UICorner"); round.CornerRadius, round.Parent = UDim.new(0.5, 0), badge
		local ink = Instance.new("UIStroke"); ink.Color, ink.Thickness, ink.Parent = Color3.fromRGB(14, 24, 52), 2, badge
		badge.Size, badge.Position = UDim2.fromOffset(16, 16), UDim2.new(1, 4, 0, -6)
		badge.BackgroundColor3 = Color3.fromRGB(255, 60, 80)
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
		caption = design:WaitForChild("Caption") :: TextLabel,
		tooltip = button:WaitForChild("Tooltip") :: TextLabel,
		badge = button:WaitForChild("ReadyBadge") :: Frame,
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
