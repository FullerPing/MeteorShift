--!strict
-- Authoring for the Codes panel (Config.Codes) in the cartoon light look (MenuTheme): a "Codes" ribbon, a line about
-- codes, a white text box and a lime REDEEM, with a line for what happened. CodesController binds everything by name.
local MenuTheme = require(script.Parent.Parent.MenuTheme)
local NativeUI = require(script.Parent.Parent.NativeUI)
local Palette = require(game:GetService("ReplicatedStorage").Shared.MenuPalette)
local Codes = {}
Codes.LAYOUT = 2 -- bumped when the controls change; CodesController rebuilds an older copy

function Codes.build(): ScreenGui
	local gui, panel = MenuTheme.menu("CodesMenu", "Codes", "codes", Vector2.new(420, 300), Codes.LAYOUT)
	gui.DisplayOrder = 28

	local hint = MenuTheme.label(panel, "Hint", "Enter a code to claim a reward. Every code works once per player.", 16, Palette.SECOND, nil, Enum.TextXAlignment.Center)
	hint.Position, hint.Size, hint.TextWrapped = UDim2.fromOffset(20, 50), UDim2.new(1, -40, 0, 40), true

	local box = NativeUI.create("TextBox", {
		Name = "CodeBox", Position = UDim2.fromOffset(20, 98), Size = UDim2.new(1, -40, 0, 54), Text = "", PlaceholderText = "ENTER CODE",
		PlaceholderColor3 = Palette.GREY_BOTTOM, ClearTextOnFocus = false, Font = MenuTheme.TITLE_FONT, TextSize = 26,
		TextColor3 = Palette.NAVY, BackgroundColor3 = Palette.WHITE, BorderSizePixel = 0, ZIndex = 5,
		TextXAlignment = Enum.TextXAlignment.Center,
	}, panel)
	MenuTheme.round(box, 12)
	MenuTheme.stroke(box, Palette.NAVY, 3)

	local redeem = MenuTheme.button(panel, "Redeem", "REDEEM", "lime", 22)
	redeem.AnchorPoint, redeem.Position, redeem.Size = Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, 166), UDim2.fromOffset(210, 54)

	local status = MenuTheme.label(panel, "Status", "", 16, Palette.SECOND, nil, Enum.TextXAlignment.Center)
	status.Position, status.Size, status.TextWrapped = UDim2.fromOffset(20, 228), UDim2.new(1, -40, 0, 50), true
	return gui
end

return Codes
