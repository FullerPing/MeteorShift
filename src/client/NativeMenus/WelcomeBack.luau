--!strict
-- Edit-time authoring for the offline-production report. Runtime binds this
-- saved StarterGui prefab and updates only its text, layout and visibility.

local NativeUI = require(script.Parent.Parent.NativeUI)
local WelcomeBack = {}

function WelcomeBack.build(): ScreenGui
	local gui = NativeUI.menu("WelcomeBack", "While you were away", NativeUI.GREEN, 390, 260)
	gui.DisplayOrder = 30
	local panel = gui:WaitForChild("Panel") :: Frame
	local title = panel:WaitForChild("Title") :: TextLabel
	title.TextScaled = true
	NativeUI.create("UITextSizeConstraint", { MinTextSize = 18, MaxTextSize = 28 }, title)
	local body = NativeUI.create("ScrollingFrame", {
		Name = "Body", Position = UDim2.fromOffset(18, 60), Size = UDim2.new(1, -36, 1, -128),
		BackgroundTransparency = 1, BorderSizePixel = 0,
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y, ScrollBarThickness = 4,
		ScrollBarImageColor3 = NativeUI.MUTED, VerticalScrollBarInset = Enum.ScrollBarInset.Always,
		ElasticBehavior = Enum.ElasticBehavior.WhenScrollable, ZIndex = 4,
	}, panel)
	local report = NativeUI.text(body, "Report", "", UDim2.fromOffset(0, 0), UDim2.new(1, -8, 0, 0), true)
	report.AutomaticSize = Enum.AutomaticSize.Y
	report.TextSize = 17
	report.TextWrapped = true
	report.TextXAlignment = Enum.TextXAlignment.Left
	report.TextYAlignment = Enum.TextYAlignment.Top
	report.TextColor3 = NativeUI.MUTED
	local nice = NativeUI.button(panel, "Nice", "Nice!", UDim2.new(0.5, 0, 1, -12), UDim2.fromOffset(140, 44), Color3.fromRGB(255, 207, 55))
	nice.AnchorPoint = Vector2.new(0.5, 1)
	nice.TextSize = 20
	nice.Active, nice.Selectable = true, true
	return gui
end

return WelcomeBack
