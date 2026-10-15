--!strict
-- Authoring for the Codes panel (Config.Codes): a text box and REDEEM, with a line for what happened.
-- CodesController binds everything by name.
local NativeUI = require(script.Parent.Parent.NativeUI)
local Codes = {}

function Codes.build(): ScreenGui
	local gui = NativeUI.menu("CodesMenu", "Codes", NativeUI.CYAN, 420, 300)
	gui.DisplayOrder = 28
	local panel = gui:WaitForChild("Panel") :: Frame
	panel.Size = UDim2.new(0.92, 0, 0, 300)
	NativeUI.create("UISizeConstraint", { MaxSize = Vector2.new(420, 300), MinSize = Vector2.new(280, 280) }, panel)
	local title = panel:WaitForChild("Title") :: TextLabel
	title.TextScaled = true
	NativeUI.create("UITextSizeConstraint", { MinTextSize = 18, MaxTextSize = 28 }, title)

	local hint = NativeUI.text(panel, "Hint", "Enter a code to claim a reward. Every code works once per player.", UDim2.fromOffset(16, 70), UDim2.new(1, -32, 0, 40), true)
	hint.TextSize, hint.TextWrapped, hint.TextXAlignment = 15, true, Enum.TextXAlignment.Center

	local box = NativeUI.create("TextBox", {
		Name = "CodeBox", Position = UDim2.fromOffset(16, 118), Size = UDim2.new(1, -32, 0, 52), Text = "", PlaceholderText = "ENTER CODE",
		PlaceholderColor3 = Color3.fromRGB(120, 134, 160), ClearTextOnFocus = false, Font = NativeUI.FONT, TextSize = 24,
		TextColor3 = NativeUI.OUTLINE, BackgroundColor3 = Color3.fromRGB(240, 246, 255), BorderSizePixel = 0, ZIndex = 5,
		TextXAlignment = Enum.TextXAlignment.Center,
	}, panel)
	NativeUI.create("UICorner", { CornerRadius = UDim.new(0, 12) }, box)
	NativeUI.create("UIStroke", { Color = NativeUI.OUTLINE, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, box)

	local redeem = NativeUI.button(panel, "Redeem", "REDEEM", UDim2.new(0.5, 0, 0, 184), UDim2.fromOffset(200, 48), NativeUI.GREEN)
	redeem.AnchorPoint, redeem.TextSize = Vector2.new(0.5, 0), 22

	local status = NativeUI.text(panel, "Status", "", UDim2.fromOffset(16, 242), UDim2.new(1, -32, 0, 44), true)
	status.TextSize, status.TextWrapped, status.TextXAlignment = 16, true, Enum.TextXAlignment.Center
	return gui
end

return Codes
