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

function ExactNavButton.bind(button: TextButton)
	return {
		caption = button:WaitForChild("Design"):WaitForChild("Caption") :: TextLabel,
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
