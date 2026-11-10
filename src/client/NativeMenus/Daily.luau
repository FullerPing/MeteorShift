--!strict
-- Authoring for the Daily Rewards panel (Config.Daily) in the cartoon light look (MenuTheme): a "Daily Rewards" ribbon,
-- the 7-day streak (days 1 to 6 as white tiles in a 3 x 2 block, day 7 as a tall jackpot tile beside them, each with a
-- CLAIM button) and the shield line, then today's quests, the all-done bonus and the weekly quest as white rows with a
-- progress bar and a CLAIM button. DailyController binds everything by name and colours today's tile.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Palette = require(ReplicatedStorage.Shared.MenuPalette)
local MenuTheme = require(script.Parent.Parent.MenuTheme)
local NativeUI = require(script.Parent.Parent.NativeUI)
local Daily = {}

Daily.LAYOUT = 2 -- bumped when the controls change; DailyController rebuilds an older copy
Daily.SIZE = Vector2.new(660, 640)
Daily.QUEST_SLOTS = { "Quest1", "Quest2", "Quest3", "Weekly", "Bonus" }

local TILE_COLUMNS = 3

local function questRow(body: ScrollingFrame, name: string, order: number)
	local row = MenuTheme.whiteCard(body, name, 12)
	row.LayoutOrder, row.Size = order, UDim2.new(1, -14, 0, 84)
	local title = MenuTheme.label(row, "Title", "", 18, Palette.NAVY, MenuTheme.TITLE_FONT)
	title.Position, title.Size, title.TextScaled = UDim2.fromOffset(14, 6), UDim2.new(1, -150, 0, 24), true
	NativeUI.create("UITextSizeConstraint", { MinTextSize = 11, MaxTextSize = 18 }, title)
	local bar = MenuTheme.bar(row, "Bar", Palette.LIME_BOTTOM)
	bar.Position, bar.Size = UDim2.fromOffset(14, 36), UDim2.new(1, -250, 0, 12)
	local progress = MenuTheme.label(row, "Progress", "", 14, Palette.SECOND, nil, Enum.TextXAlignment.Right)
	progress.Position, progress.Size = UDim2.new(1, -230, 0, 31), UDim2.fromOffset(94, 22)
	local reward = MenuTheme.label(row, "Reward", "", 15, Palette.GOLD_TEXT, MenuTheme.TITLE_FONT)
	reward.Position, reward.Size = UDim2.fromOffset(14, 56), UDim2.new(1, -150, 0, 22)
	local claim = MenuTheme.button(row, "Claim", "CLAIM", "face", 17)
	claim.Position, claim.Size = UDim2.new(1, -126, 0, 16), UDim2.fromOffset(114, 52)
end

function Daily.build(): ScreenGui
	local gui, panel = MenuTheme.menu("DailyMenu", "Daily Rewards", "daily", Daily.SIZE, Daily.LAYOUT)
	gui.DisplayOrder = 28

	local body = NativeUI.create("ScrollingFrame", {
		Name = "Body", Position = UDim2.fromOffset(12, 50), Size = UDim2.new(1, -24, 1, -64),
		BackgroundTransparency = 1, BorderSizePixel = 0, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y, ScrollBarThickness = 4, ScrollBarImageColor3 = Palette.BLUE_BOTTOM,
		VerticalScrollBarInset = Enum.ScrollBarInset.Always, ElasticBehavior = Enum.ElasticBehavior.WhenScrollable, ZIndex = 4,
	}, panel)
	NativeUI.create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, body)
	NativeUI.create("UIPadding", { PaddingTop = UDim.new(0, 3), PaddingLeft = UDim.new(0, 3) }, body)

	-- The streak card: a heading, the seven reward tiles and the shield line. Each tile has its own CLAIM button; the
	-- controller fills in amounts and states.
	local streak = NativeUI.create("Frame", {
		Name = "StreakCard", LayoutOrder = 1, Size = UDim2.new(1, -14, 0, 418), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 4,
	}, body)
	local heading = MenuTheme.label(streak, "Heading", "", 20, Palette.NAVY, MenuTheme.TITLE_FONT, Enum.TextXAlignment.Center)
	heading.Position, heading.Size = UDim2.fromOffset(4, 2), UDim2.new(1, -8, 0, 28)
	local grid = NativeUI.create("Frame", { Name = "Days", Position = UDim2.fromOffset(0, 36), Size = UDim2.new(1, 0, 0, 334), BackgroundTransparency = 1, ZIndex = 4 }, streak)
	for index, entry in Config.Daily.Days do
		local big = index == Config.Daily.CycleLength
		local column, row = (index - 1) % TILE_COLUMNS, (index - 1) // TILE_COLUMNS
		local tile = MenuTheme.whiteCard(grid, "Day" .. index, 14)
		tile.LayoutOrder = index
		tile.Size = if big then UDim2.new(0.25, -6, 1, 0) else UDim2.new(0.25, -6, 0.5, -4)
		tile.Position = if big then UDim2.fromScale(0.75, 0) else UDim2.new(column * 0.25, 0, row * 0.5, row * 4)
		local title = MenuTheme.label(tile, "Title", "Day " .. index, 20, Palette.NAVY, MenuTheme.TITLE_FONT, Enum.TextXAlignment.Center)
		title.Position, title.Size, title.TextScaled = UDim2.fromOffset(0, 6), UDim2.new(1, 0, 0, 24), true
		NativeUI.create("UITextSizeConstraint", { MinTextSize = 11, MaxTextSize = 22 }, title)
		local iconSize = if big then 104 else 48
		local icon = MenuTheme.icon(tile, "Icon", if entry.Shards > 0 then "crystal" else "coin", UDim2.new(0.5, 0, 0, if big then 44 else 30), UDim2.fromOffset(iconSize, iconSize))
		icon.AnchorPoint = Vector2.new(0.5, 0)
		local prize = MenuTheme.label(tile, "Prize", "", 16, Palette.NAVY, MenuTheme.TITLE_FONT, Enum.TextXAlignment.Center)
		prize.AnchorPoint, prize.Position, prize.Size = Vector2.new(0.5, 1), UDim2.new(0.5, 0, 1, -46), UDim2.new(1, -8, 0, if big then 84 else 34)
		prize.TextWrapped, prize.TextScaled = true, true
		NativeUI.create("UITextSizeConstraint", { MinTextSize = 10, MaxTextSize = if big then 20 else 17 }, prize)
		local claim = MenuTheme.button(tile, "Claim", "LOCKED", "face", 16)
		claim.AnchorPoint, claim.Position, claim.Size = Vector2.new(0.5, 1), UDim2.new(0.5, 0, 1, -6), UDim2.new(1, -14, 0, 38)
	end
	local shields = MenuTheme.label(streak, "Shields", "", 14, Palette.SECOND, nil, Enum.TextXAlignment.Center)
	shields.Position, shields.Size, shields.TextWrapped = UDim2.fromOffset(4, 376), UDim2.new(1, -8, 0, 40), true

	local header = MenuTheme.label(body, "QuestHeader", "TODAY'S QUESTS", 20, Palette.NAVY, MenuTheme.TITLE_FONT)
	header.LayoutOrder, header.Size = 2, UDim2.new(1, -14, 0, 28)
	for order, name in Daily.QUEST_SLOTS do
		questRow(body, name, 2 + order)
	end
	local footer = MenuTheme.label(body, "Footer", "", 14, Palette.SECOND, nil, Enum.TextXAlignment.Center)
	footer.LayoutOrder, footer.Size = 20, UDim2.new(1, -14, 0, 28)
	return gui
end

return Daily
