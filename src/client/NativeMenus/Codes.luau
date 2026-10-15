--!strict
-- Authoring for the Codes panel (Config.Codes) in the cartoon light look (MenuTheme), laid out as the owner's mockup
-- (Craterworks Menu Redesign, 2026-10-15): a "Codes" ribbon, a line about codes, an ENTER CODE label over a big white
-- text box, a full-width lime REDEEM, a strip with what happened (Result, its Status line) and a footer. The panel is
-- drawn whole (NativeUI.fitWhole). CodesController binds everything by name.
local MenuTheme = require(script.Parent.Parent.MenuTheme)
local NativeUI = require(script.Parent.Parent.NativeUI)
local Palette = require(game:GetService("ReplicatedStorage").Shared.MenuPalette)
local Codes = {}
Codes.LAYOUT = 3 -- bumped when the controls change; CodesController rebuilds an older copy
Codes.SIZE = Vector2.new(560, 400)

function Codes.build(): ScreenGui
	local gui, panel = MenuTheme.menu("CodesMenu", "Codes", "codes", Codes.SIZE, Codes.LAYOUT)
	gui.DisplayOrder = 28

	local intro = MenuTheme.label(panel, "Hint", "Got a code from a video, the group or an update? Type it here.", 16, Palette.NAVY)
	intro.Position, intro.Size, intro.TextWrapped = UDim2.fromOffset(24, 56), UDim2.new(1, -48, 0, 26), true
	local caption = MenuTheme.label(panel, "Caption", "ENTER CODE", 14, Palette.SECOND, MenuTheme.TITLE_FONT)
	caption.Position, caption.Size = UDim2.fromOffset(24, 92), UDim2.new(1, -48, 0, 18)

	local box = NativeUI.create("TextBox", {
		Name = "CodeBox", Position = UDim2.fromOffset(24, 114), Size = UDim2.new(1, -48, 0, 58), Text = "", PlaceholderText = "Type a code",
		PlaceholderColor3 = Palette.GREY_BOTTOM, ClearTextOnFocus = false, Font = MenuTheme.TITLE_FONT, TextSize = 24,
		TextColor3 = Palette.NAVY, BackgroundColor3 = Palette.WHITE, BorderSizePixel = 0, ZIndex = 5,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, panel)
	MenuTheme.round(box, 14)
	MenuTheme.stroke(box, Palette.NAVY, 3)
	NativeUI.create("UIPadding", { PaddingLeft = UDim.new(0, 18), PaddingRight = UDim.new(0, 18) }, box)

	local redeem = MenuTheme.button(panel, "Redeem", "REDEEM", "lime", 24)
	redeem.Position, redeem.Size = UDim2.fromOffset(24, 186), UDim2.new(1, -48, 0, 60)

	-- what happened: green when a code paid, pink when it did not (CodesController colours it); hidden until then
	local result = MenuTheme.soft(panel, "Result")
	result.Position, result.Size, result.Visible = UDim2.fromOffset(24, 260), UDim2.new(1, -48, 0, 50), false
	local status = MenuTheme.label(result, "Status", "", 16, Palette.NAVY, MenuTheme.TITLE_FONT, Enum.TextXAlignment.Center)
	status.Position, status.Size, status.TextWrapped, status.TextScaled = UDim2.fromOffset(12, 4), UDim2.new(1, -24, 1, -8), true, true
	NativeUI.create("UITextSizeConstraint", { MinTextSize = 10, MaxTextSize = 16 }, status)

	local footer = MenuTheme.label(panel, "Footer", "Every code works once per player.", 13, Palette.SECOND, nil, Enum.TextXAlignment.Center)
	footer.Position, footer.Size = UDim2.new(0, 24, 1, -46), UDim2.new(1, -48, 0, 20)
	return gui
end

return Codes
