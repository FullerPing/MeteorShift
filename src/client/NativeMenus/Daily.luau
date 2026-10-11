--!strict
-- Authoring for the Daily Rewards panel (Config.Daily): the 7-day streak with a CLAIM button and shield count,
-- today's quests, the all-done bonus and the weekly quest. DailyController binds everything by name.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local NativeUI = require(script.Parent.Parent.NativeUI)
local Daily = {}

Daily.QUEST_SLOTS = { "Quest1", "Quest2", "Quest3", "Weekly", "Bonus" }

local function questRow(body: ScrollingFrame, name: string, order: number)
	local row = NativeUI.create("Frame", {
		Name = name, LayoutOrder = order, Size = UDim2.new(1, -8, 0, 78), BackgroundColor3 = NativeUI.CARD,
		BorderSizePixel = 0, ZIndex = 4,
	}, body)
	NativeUI.surface(row, 4, .8)
	local title = NativeUI.text(row, "Title", "", UDim2.fromOffset(12, 6), UDim2.new(1, -130, 0, 24))
	title.TextSize, title.TextScaled = 18, true
	NativeUI.create("UITextSizeConstraint", { MinTextSize = 11, MaxTextSize = 18 }, title)
	NativeUI.text(row, "Progress", "", UDim2.fromOffset(12, 32), UDim2.new(1, -130, 0, 18), true).TextColor3 = NativeUI.MUTED
	NativeUI.text(row, "Reward", "", UDim2.fromOffset(12, 52), UDim2.new(1, -130, 0, 18), true).TextColor3 = NativeUI.HUD_GOLD
	local claim = NativeUI.button(row, "Claim", "CLAIM", UDim2.new(1, -118, 0, 17), UDim2.fromOffset(106, 44), NativeUI.GREEN)
	claim.TextSize = 16
end

function Daily.build(): ScreenGui
	local gui = NativeUI.menu("DailyMenu", "Daily Rewards", NativeUI.ORANGE, 430, 600)
	gui.DisplayOrder = 28
	local panel = gui:WaitForChild("Panel") :: Frame
	panel.Size = UDim2.new(0, 430, 0.92, 0)
	NativeUI.create("UISizeConstraint", { MaxSize = Vector2.new(430, 620), MinSize = Vector2.new(280, 300) }, panel)
	local title = panel:WaitForChild("Title") :: TextLabel
	title.TextScaled = true
	NativeUI.create("UITextSizeConstraint", { MinTextSize = 18, MaxTextSize = 28 }, title)

	local body = NativeUI.create("ScrollingFrame", {
		Name = "Body", Position = UDim2.fromOffset(12, 62), Size = UDim2.new(1, -24, 1, -74),
		BackgroundTransparency = 1, BorderSizePixel = 0, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y, ScrollBarThickness = 4, ScrollBarImageColor3 = NativeUI.MUTED,
		VerticalScrollBarInset = Enum.ScrollBarInset.Always, ElasticBehavior = Enum.ElasticBehavior.WhenScrollable, ZIndex = 4,
	}, panel)
	NativeUI.create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, body)

	-- The streak card: seven day chips, what today pays, CLAIM and the shield line
	local streak = NativeUI.create("Frame", {
		Name = "StreakCard", LayoutOrder = 1, Size = UDim2.new(1, -8, 0, 226), BackgroundColor3 = NativeUI.CARD,
		BorderSizePixel = 0, ZIndex = 4,
	}, body)
	NativeUI.surface(streak, 4, .8)
	NativeUI.text(streak, "Heading", "", UDim2.fromOffset(12, 6), UDim2.new(1, -24, 0, 28))
	local days = NativeUI.create("Frame", { Name = "Days", Position = UDim2.fromOffset(8, 40), Size = UDim2.new(1, -16, 0, 74), BackgroundTransparency = 1, ZIndex = 4 }, streak)
	NativeUI.create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, days)
	for index, entry in Config.Daily.Days do
		local chip = NativeUI.create("Frame", { Name = "Day" .. index, LayoutOrder = index, Size = UDim2.new(1 / Config.Daily.CycleLength, -4, 1, 0), BackgroundColor3 = NativeUI.PANEL, BorderSizePixel = 0, ZIndex = 4 }, days)
		NativeUI.surface(chip, 4, .85)
		local number = NativeUI.text(chip, "Number", tostring(index), UDim2.fromOffset(0, 4), UDim2.new(1, 0, 0, 24))
		number.TextXAlignment, number.TextSize = Enum.TextXAlignment.Center, 20
		local prize = if entry.Shards > 0 then "+" .. entry.Shards .. "◆" else "$"
		if entry.Shield > 0 then prize ..= "\n+shield" end
		local label = NativeUI.text(chip, "Prize", prize, UDim2.fromOffset(0, 30), UDim2.new(1, 0, 1, -32), true)
		label.TextXAlignment, label.TextYAlignment, label.TextWrapped, label.TextSize = Enum.TextXAlignment.Center, Enum.TextYAlignment.Top, true, 11
	end
	local reward = NativeUI.text(streak, "Reward", "", UDim2.fromOffset(12, 122), UDim2.new(1, -24, 0, 22), true)
	reward.TextSize, reward.TextColor3 = 15, NativeUI.HUD_GOLD
	local claim = NativeUI.button(streak, "Claim", "CLAIM", UDim2.new(0.5, 0, 0, 150), UDim2.fromOffset(200, 44), NativeUI.GREEN)
	claim.AnchorPoint, claim.TextSize = Vector2.new(0.5, 0), 20
	local shields = NativeUI.text(streak, "Shields", "", UDim2.new(0, 12, 1, -28), UDim2.new(1, -24, 0, 22), true)
	shields.TextSize, shields.TextColor3 = 14, NativeUI.MUTED

	local header = NativeUI.text(body, "QuestHeader", "TODAY'S QUESTS", UDim2.new(), UDim2.new(1, -8, 0, 26))
	header.LayoutOrder = 2
	for order, name in Daily.QUEST_SLOTS do
		questRow(body, name, 2 + order)
	end
	local footer = NativeUI.text(body, "Footer", "", UDim2.new(), UDim2.new(1, -8, 0, 24), true)
	footer.LayoutOrder, footer.TextSize, footer.TextColor3 = 20, 14, NativeUI.MUTED
	return gui
end

return Daily
