--!strict
-- Studio-authored ScreenGui prefabs; controllers bind their named controls.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local HudLayout = require(ReplicatedStorage.Shared.HudLayout)
local Sfx = require(script.Parent.Sfx)
local NativeUI = {}
NativeUI.FONT = Enum.Font.FredokaOne
NativeUI.WHITE = Color3.new(1, 1, 1)
NativeUI.OUTLINE = Color3.fromRGB(12, 18, 25)
NativeUI.PANEL = Color3.fromRGB(43, 44, 49)
NativeUI.CARD = Color3.fromRGB(67, 69, 77)
NativeUI.MUTED = Color3.fromRGB(211, 228, 240)
NativeUI.CYAN = Color3.fromRGB(66, 190, 255)
NativeUI.ORANGE = Color3.fromRGB(255, 174, 52)
NativeUI.GREEN = Color3.fromRGB(105, 240, 103)
NativeUI.RED = Color3.fromRGB(235, 70, 70)
NativeUI.BODY_FONT = Enum.Font.GothamMedium
NativeUI.SUBTEXT, NativeUI.HUD_MUTED = NativeUI.MUTED, NativeUI.MUTED
NativeUI.SHARD = NativeUI.CYAN
NativeUI.HUD_GOLD = Color3.fromRGB(255, 219, 100)
NativeUI.HUD_MINT = Color3.fromRGB(139, 240, 195)

-- These authoring helpers run only when building the editable prefabs in Studio.
function NativeUI.create(class: string, props: { [string]: any }, parent: Instance?): any
	local object: any = Instance.new(class)
	for key, value in props do object[key] = value end
	object.Parent = parent
	return object
end
function NativeUI.surface(parent: GuiObject, radius: number?, alpha: number?)
	NativeUI.create("UICorner", { CornerRadius = UDim.new(0, radius or 4) }, parent)
	NativeUI.create("UIStroke", { Color = NativeUI.OUTLINE, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, parent)
	NativeUI.create("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(205, 205, 205)) }, parent)
	local texture = NativeUI.create("ImageLabel", {
		Name = "StudTexture", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
		Image = "rbxassetid://6927295847", ImageTransparency = alpha or .72,
		ScaleType = Enum.ScaleType.Tile, TileSize = UDim2.fromOffset(128, 128),
		Active = false, Selectable = false, ZIndex = 0,
	}, parent)
	NativeUI.create("UICorner", { CornerRadius = UDim.new(0, radius or 4) }, texture)
end
function NativeUI.text(parent: Instance, name: string, text: string, position: UDim2, size: UDim2, body: boolean?): TextLabel
	return NativeUI.create("TextLabel", {
		Name = name, Text = text, Position = position, Size = size, BackgroundTransparency = 1,
		Font = if body then Enum.Font.GothamMedium else NativeUI.FONT, TextSize = if body then 13 else 20,
		TextColor3 = NativeUI.WHITE, TextStrokeColor3 = NativeUI.OUTLINE, TextStrokeTransparency = if body then 1 else 0,
		TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 5,
	}, parent)
end
function NativeUI.button(parent: Instance, name: string, text: string, position: UDim2, size: UDim2, color: Color3?): TextButton
	local button = NativeUI.create("TextButton", {
		Name = name, Text = text, Position = position, Size = size, BorderSizePixel = 0,
		BackgroundColor3 = color or NativeUI.CYAN, Font = NativeUI.FONT, TextSize = 17,
		TextColor3 = NativeUI.WHITE, TextStrokeColor3 = NativeUI.OUTLINE, TextStrokeTransparency = 0, ZIndex = 4,
	}, parent)
	NativeUI.surface(button)
	return button
end
function NativeUI.menu(name: string, title: string, color: Color3, width: number, height: number): ScreenGui
	local gui = NativeUI.create("ScreenGui", {
		Name = name, Enabled = false, ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 25,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, nil)
	gui:SetAttribute("NativePrefab", true)
	NativeUI.create("TextButton", { Name = "Dimmer", Text = "", Size = UDim2.fromScale(1, 1), BackgroundColor3 = NativeUI.OUTLINE,
		BackgroundTransparency = .35, BorderSizePixel = 0, AutoButtonColor = false, Modal = true }, gui)
	local panel = NativeUI.create("Frame", { Name = "Panel", Size = UDim2.fromOffset(width, height),
		AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(.5, .5), BackgroundColor3 = NativeUI.PANEL,
		BorderSizePixel = 0, Active = true, ZIndex = 2 }, gui)
	NativeUI.surface(panel, 4, .8)
	local header = NativeUI.create("Frame", { Name = "Header", Size = UDim2.new(1, 0, 0, 52), BackgroundColor3 = color, BorderSizePixel = 0, ZIndex = 3 }, panel)
	NativeUI.surface(header, 4, .58)
	NativeUI.text(panel, "Title", title, UDim2.fromOffset(14, 4), UDim2.new(1, -80, 0, 44)).TextSize = 28
	NativeUI.button(panel, "Close", "X", UDim2.new(1, -48, 0, 4), UDim2.fromOffset(44, 44), NativeUI.RED)
	return gui
end
function NativeUI.get(name: string): ScreenGui
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local gui = playerGui:WaitForChild(name, 15)
	assert(gui and gui:IsA("ScreenGui"), "Missing StarterGui prefab: " .. name .. ". Run tools/build-native-ui.luau in Edit mode.")
	for _, node in gui:GetDescendants() do
		if node:IsA("GuiButton") then
			node.Activated:Connect(function() if node.Active then Sfx.play("Click") end end)
		end
	end
	return gui :: ScreenGui
end
function NativeUI.enable(button: GuiButton, enabled: boolean, color: Color3)
	button.Active, button.Selectable, button.AutoButtonColor = enabled, enabled, enabled
	button.BackgroundColor3 = if enabled then color else Color3.fromRGB(29, 30, 35)
	if button:IsA("TextButton") then
		button.TextColor3 = if enabled then NativeUI.WHITE else NativeUI.MUTED
		button.TextStrokeTransparency = if enabled then 0 else 1
	end
end
function NativeUI.hudLayout(): HudLayout.Layout
	local p = Players.LocalPlayer
	return HudLayout.compute(if workspace.CurrentCamera then workspace.CurrentCamera.ViewportSize else Vector2.new(1280, 720),
		UserInputService.TouchEnabled, GuiService:GetGuiInset().Y, p:GetAttribute("FoundryExpanded") == true,
		p:GetAttribute("HudNotificationActive") == true, p:GetAttribute("HudRewardNotificationActive") == true)
end
function NativeUI.onLayoutChanged(callback: (HudLayout.Layout) -> ()): () -> ()
	local connections: { RBXScriptConnection } = {}
	local cameraConnection: RBXScriptConnection? = nil
	local function update() callback(NativeUI.hudLayout()) end
	local function bindCamera()
		if cameraConnection then cameraConnection:Disconnect() end
		local camera = workspace.CurrentCamera
		cameraConnection = if camera then camera:GetPropertyChangedSignal("ViewportSize"):Connect(update) else nil
		update()
	end
	table.insert(connections, workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bindCamera))
	table.insert(connections, UserInputService:GetPropertyChangedSignal("TouchEnabled"):Connect(update))
	table.insert(connections, GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(update))
	for _, name in { "FoundryExpanded", "HudNotificationActive", "HudRewardNotificationActive" } do
		table.insert(connections, Players.LocalPlayer:GetAttributeChangedSignal(name):Connect(update))
	end
	bindCamera()
	return function()
		if cameraConnection then cameraConnection:Disconnect() end
		for _, connection in connections do connection:Disconnect() end
	end
end
function NativeUI.bindOpen(gui: ScreenGui, attribute: string, close: () -> ())
	local p = Players.LocalPlayer
	local function update() gui.Enabled = p:GetAttribute(attribute) == true end
	p:GetAttributeChangedSignal(attribute):Connect(update)
	local dimmer = gui:WaitForChild("Dimmer") :: GuiButton
	local closeButton = gui:WaitForChild("Panel"):WaitForChild("Close") :: GuiButton
	dimmer.Activated:Connect(close)
	closeButton.Activated:Connect(close)
	UserInputService.InputBegan:Connect(function(input)
		if gui.Enabled and (input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB) then close() end
	end)
	update()
end
return NativeUI
