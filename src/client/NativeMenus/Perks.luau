--!strict
-- Authoring for the Colony Perks panel (Config.Perks): one card per perk with its level, what the
-- next level does and a BUY button. The runtime binds the cards by name (PerksController).
-- It is opened from a PERKS button on the Rebirth panel.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local NativeUI = require(script.Parent.Parent.NativeUI)
local Perks = {}

Perks.ROW_HEIGHT = 92

function Perks.build(): ScreenGui
	local gui = NativeUI.menu("ColonyPerks", "Colony Perks", NativeUI.GREEN, 430, 540)
	gui.DisplayOrder = 28
	local panel = gui:WaitForChild("Panel") :: Frame
	panel.Size = UDim2.new(0, 430, 0.9, 0)
	NativeUI.create("UISizeConstraint", { MaxSize = Vector2.new(430, 560), MinSize = Vector2.new(280, 280) }, panel)
	local title = panel:WaitForChild("Title") :: TextLabel
	title.TextScaled = true
	NativeUI.create("UITextSizeConstraint", { MinTextSize = 18, MaxTextSize = 28 }, title)

	local wallet = NativeUI.text(panel, "Wallet", "", UDim2.fromOffset(16, 58), UDim2.new(1, -32, 0, 24), true)
	wallet.TextSize = 16
	wallet.TextColor3 = NativeUI.MUTED

	local body = NativeUI.create("ScrollingFrame", {
		Name = "Body", Position = UDim2.fromOffset(12, 88), Size = UDim2.new(1, -24, 1, -128),
		BackgroundTransparency = 1, BorderSizePixel = 0,
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y, ScrollBarThickness = 4,
		ScrollBarImageColor3 = NativeUI.MUTED, VerticalScrollBarInset = Enum.ScrollBarInset.Always,
		ElasticBehavior = Enum.ElasticBehavior.WhenScrollable, ZIndex = 4,
	}, panel)
	NativeUI.create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, body)

	for order, id in Config.Perks.Order do
		local card = NativeUI.create("Frame", {
			Name = id .. "Row", LayoutOrder = order, Size = UDim2.new(1, -8, 0, Perks.ROW_HEIGHT),
			BackgroundColor3 = NativeUI.CARD, BorderSizePixel = 0, ZIndex = 4,
		}, body)
		NativeUI.surface(card, 4, .8)
		NativeUI.text(card, "Name", Config.Perks.List[id].Name, UDim2.fromOffset(12, 6), UDim2.new(1, -130, 0, 26))
		NativeUI.text(card, "Level", "", UDim2.new(1, -118, 0, 8), UDim2.fromOffset(106, 22), true).TextXAlignment = Enum.TextXAlignment.Right
		local text = NativeUI.text(card, "Text", "", UDim2.fromOffset(12, 34), UDim2.new(1, -140, 0, 52), true)
		text.TextWrapped = true
		text.TextYAlignment = Enum.TextYAlignment.Top
		text.TextColor3 = NativeUI.MUTED
		local buy = NativeUI.button(card, "Buy", "BUY", UDim2.new(1, -118, 0, 36), UDim2.fromOffset(106, 44), NativeUI.GREEN)
		buy.TextSize = 16
		buy.TextWrapped = true
	end

	local footer = NativeUI.text(panel, "Footer", "", UDim2.new(0, 16, 1, -34), UDim2.new(1, -32, 0, 24), true)
	footer.TextSize = 14
	footer.TextColor3 = NativeUI.MUTED
	return gui
end

return Perks
