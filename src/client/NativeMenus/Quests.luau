--!strict
-- The Foreman's Quests menu (Config.Quests, Shared.Quests) in the cartoon light look (MenuTheme): a "Quests" ribbon,
-- the step count, one card for the current quest (the owner's book icon, its title, a hint, a progress bar and the
-- reward) and a lime CLAIM button. QuestController binds the controls by name and also draws the HUD tracker.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Palette = require(ReplicatedStorage.Shared.MenuPalette)
local MenuTheme = require(script.Parent.Parent.MenuTheme)
local NativeUI = require(script.Parent.Parent.NativeUI)
local Quests = {}

Quests.LAYOUT = 1 -- bumped when the controls change; QuestController rebuilds an older copy
Quests.SIZE = Vector2.new(640, 400)

function Quests.build(): ScreenGui
	local gui, panel = MenuTheme.menu("QuestsMenu", "Quests", "index", Quests.SIZE, Quests.LAYOUT)
	gui.DisplayOrder = 27

	local stepLabel = MenuTheme.label(panel, "Step", "", 16, Palette.SECOND, nil, Enum.TextXAlignment.Right)
	stepLabel.AnchorPoint, stepLabel.Position, stepLabel.Size = Vector2.new(1, 0), UDim2.new(1, -60, 0, 16), UDim2.fromOffset(200, 24)

	local card = MenuTheme.box(panel, "Card")
	card.Position, card.Size, card.ZIndex = UDim2.fromOffset(22, 62), UDim2.new(1, -44, 0, 196), 3
	local well = MenuTheme.iconWell(card, "Well", "index")
	well.Position, well.Size, well.ZIndex = UDim2.fromOffset(16, 16), UDim2.fromOffset(96, 96), 4
	local title = MenuTheme.label(card, "Title", "", 24, Palette.NAVY, MenuTheme.TITLE_FONT)
	title.Position, title.Size, title.TextScaled = UDim2.fromOffset(128, 16), UDim2.new(1, -144, 0, 32), true
	NativeUI.create("UITextSizeConstraint", { MinTextSize = 12, MaxTextSize = 24 }, title)
	local hint = MenuTheme.label(card, "Hint", "", 15, Palette.SECOND)
	hint.Position, hint.Size, hint.TextWrapped, hint.TextYAlignment = UDim2.fromOffset(128, 52), UDim2.new(1, -144, 0, 44), true, Enum.TextYAlignment.Top
	local bar = MenuTheme.bar(card, "Bar", Palette.LIME_BOTTOM)
	bar.Position, bar.Size = UDim2.fromOffset(128, 104), UDim2.new(1, -230, 0, 14)
	local count = MenuTheme.label(card, "Count", "", 16, Palette.NAVY, MenuTheme.TITLE_FONT, Enum.TextXAlignment.Right)
	count.AnchorPoint, count.Position, count.Size = Vector2.new(1, 0), UDim2.new(1, -16, 0, 98), UDim2.fromOffset(90, 26)
	local reward = MenuTheme.goldCard(card, "Reward")
	reward.Position, reward.Size, reward.ZIndex = UDim2.fromOffset(16, 132), UDim2.new(1, -32, 0, 48), 4
	local rewardText = MenuTheme.label(reward, "Label", "", 18, Palette.NAVY, MenuTheme.TITLE_FONT, Enum.TextXAlignment.Center)
	rewardText.Size, rewardText.RichText, rewardText.ZIndex = UDim2.fromScale(1, 1), true, 5

	local claim = MenuTheme.button(panel, "Claim", "CLAIM", "lime", 22)
	claim.AnchorPoint, claim.Position, claim.Size = Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, 274), UDim2.fromOffset(260, 56)
	local footer = MenuTheme.label(panel, "Footer", "Quests come from the Foreman by the spawn. They never reset, not even on rebirth.", 14, Palette.MUTED, nil, Enum.TextXAlignment.Center)
	footer.Position, footer.Size, footer.TextWrapped = UDim2.fromOffset(22, 338), UDim2.new(1, -44, 0, 22), true
	return gui
end

-- The HUD tracker: a small card above the backpack card showing the current quest; clicking it opens the menu
function Quests.buildTracker(): ScreenGui
	local gui = NativeUI.create("ScreenGui", { Name = "QuestTracker", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 4,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, nil) :: ScreenGui
	local button = NativeUI.create("TextButton", { Name = "Card", Text = "", AutoButtonColor = true, Size = UDim2.fromOffset(292, 70),
		BackgroundColor3 = Palette.WHITE, BorderSizePixel = 0, Visible = false }, gui)
	MenuTheme.round(button, 12)
	MenuTheme.stroke(button, Palette.NAVY, 3)
	MenuTheme.gradient(button, Palette.WHITE, Palette.DETAIL_BOTTOM)
	local icon = MenuTheme.icon(button, "Icon", "index", UDim2.fromOffset(8, 9), UDim2.fromOffset(52, 52))
	icon.ZIndex = 2
	local tag = MenuTheme.label(button, "Tag", "QUEST", 13, Palette.SECOND, MenuTheme.TITLE_FONT)
	tag.Position, tag.Size, tag.ZIndex = UDim2.fromOffset(68, 4), UDim2.new(1, -76, 0, 18), 2
	local title = MenuTheme.label(button, "Title", "", 17, Palette.NAVY, MenuTheme.TITLE_FONT)
	title.Position, title.Size, title.TextScaled, title.ZIndex = UDim2.fromOffset(68, 22), UDim2.new(1, -76, 0, 22), true, 2
	NativeUI.create("UITextSizeConstraint", { MinTextSize = 9, MaxTextSize = 17 }, title)
	local bar = MenuTheme.bar(button, "Bar", Palette.LIME_BOTTOM)
	bar.Position, bar.Size, bar.ZIndex = UDim2.fromOffset(68, 50), UDim2.new(1, -140, 0, 10), 2
	local count = MenuTheme.label(button, "Count", "", 14, Palette.NAVY, MenuTheme.TITLE_FONT, Enum.TextXAlignment.Right)
	count.AnchorPoint, count.Position, count.Size, count.ZIndex = Vector2.new(1, 0), UDim2.new(1, -8, 0, 44), UDim2.fromOffset(64, 22), 2
	NativeUI.create("UIScale", { Name = "Fit" }, button)

	-- the game-wide event card and the hourly meteor card (EventController) stack on top of the quest card
	for _, card in { { "EventCard", "meteor" }, { "HourlyCard", "meteorQuartz" } } do
		local event = NativeUI.create("Frame", { Name = card[1], Size = UDim2.fromOffset(292, 56), BackgroundColor3 = Palette.WHITE,
			BorderSizePixel = 0, Visible = false }, gui)
		MenuTheme.round(event, 12)
		MenuTheme.stroke(event, Palette.NAVY, 3)
		MenuTheme.gradient(event, Palette.EVO_TOP, Palette.EVO_BOTTOM)
		local eventIcon = MenuTheme.icon(event, "Icon", card[2], UDim2.fromOffset(8, 6), UDim2.fromOffset(44, 44))
		eventIcon.ZIndex = 2
		local eventTitle = MenuTheme.label(event, "Title", "", 16, Palette.NAVY, MenuTheme.TITLE_FONT)
		eventTitle.Position, eventTitle.Size, eventTitle.TextScaled, eventTitle.ZIndex = UDim2.fromOffset(60, 4), UDim2.new(1, -68, 0, 22), true, 2
		NativeUI.create("UITextSizeConstraint", { MinTextSize = 9, MaxTextSize = 16 }, eventTitle)
		local eventText = MenuTheme.label(event, "Text", "", 13, Palette.NAVY)
		eventText.Position, eventText.Size, eventText.TextScaled, eventText.ZIndex = UDim2.fromOffset(60, 28), UDim2.new(1, -68, 0, 20), true, 2
		NativeUI.create("UITextSizeConstraint", { MinTextSize = 8, MaxTextSize = 13 }, eventText)
		NativeUI.create("UIScale", { Name = "Fit" }, event)
	end
	return gui
end

return Quests
