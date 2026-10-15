--!strict
-- Authoring for the Daily Rewards panel (Config.Daily): the 7-day streak with a CLAIM button and shield count,
-- today's quests, the all-done bonus and the weekly quest. DailyController binds everything by name.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local NativeUI = require(script.Parent.Parent.NativeUI)
local Daily = {}

Daily.QUEST_SLOTS = { "Quest1", "Quest2", "Quest3", "Weekly", "Bonus" }

local TILE_COLUMNS = 3
local BIG_TILE = Color3.fromRGB(176, 128, 255) -- the day 7 jackpot tile stands apart from the blue ones

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
	local gui = NativeUI.menu("DailyMenu", "Daily Rewards", NativeUI.ORANGE, 640, 600)
	gui.DisplayOrder = 28
	local panel = gui:WaitForChild("Panel") :: Frame
	panel.Size = UDim2.new(0.94, 0, 0.92, 0)
	NativeUI.create("UISizeConstraint", { MaxSize = Vector2.new(660, 640), MinSize = Vector2.new(300, 300) }, panel)
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

	-- The streak card: a heading, the seven reward tiles (days 1 to 6 in a 3 x 2 block, day 7 tall beside them) and
	-- the shield line. Each tile has its own status button; the controller fills in amounts and states.
	local streak = NativeUI.create("Frame", {
		Name = "StreakCard", LayoutOrder = 1, Size = UDim2.new(1, -8, 0, 414), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 4,
	}, body)
	local heading = NativeUI.text(streak, "Heading", "", UDim2.fromOffset(4, 4), UDim2.new(1, -8, 0, 28))
	heading.TextXAlignment = Enum.TextXAlignment.Center
	local grid = NativeUI.create("Frame", { Name = "Days", Position = UDim2.fromOffset(0, 38), Size = UDim2.new(1, 0, 0, 330), BackgroundTransparency = 1, ZIndex = 4 }, streak)
	for index, entry in Config.Daily.Days do
		local big = index == Config.Daily.CycleLength
		local column, row = (index - 1) % TILE_COLUMNS, (index - 1) // TILE_COLUMNS
		local tile = NativeUI.create("Frame", {
			Name = "Day" .. index, LayoutOrder = index, BackgroundColor3 = if big then BIG_TILE else NativeUI.CARD, BorderSizePixel = 0, ZIndex = 4,
			Size = if big then UDim2.new(0.25, -6, 1, 0) else UDim2.new(0.25, -6, 0.5, -4),
			Position = if big then UDim2.fromScale(0.75, 0) else UDim2.new(column * 0.25, 0, row * 0.5, row * 4),
		}, grid)
		NativeUI.surface(tile, 4, .8)
		local title = NativeUI.text(tile, "Title", "Day " .. index, UDim2.fromOffset(0, 6), UDim2.new(1, 0, 0, 24))
		title.TextXAlignment, title.TextSize, title.TextScaled = Enum.TextXAlignment.Center, 20, true
		NativeUI.create("UITextSizeConstraint", { MinTextSize = 11, MaxTextSize = 22 }, title)
		local iconSize = if big then 112 else 52
		NativeUI.create("ImageLabel", {
			Name = "Icon", AnchorPoint = Vector2.new(.5, 0), Position = UDim2.new(.5, 0, 0, if big then 48 else 32), Size = UDim2.fromOffset(iconSize, iconSize),
			BackgroundTransparency = 1, Image = if entry.Shards > 0 then Config.HudIcons.crystal else Config.HudIcons.coin,
			ScaleType = Enum.ScaleType.Fit, ZIndex = 5,
		}, tile)
		local prize = NativeUI.text(tile, "Prize", "", UDim2.new(.5, 0, 1, -42), UDim2.new(1, -8, 0, if big then 84 else 34))
		prize.AnchorPoint, prize.TextXAlignment, prize.TextYAlignment = Vector2.new(.5, 1), Enum.TextXAlignment.Center, Enum.TextYAlignment.Center
		prize.TextWrapped, prize.TextScaled, prize.TextSize = true, true, 16
		NativeUI.create("UITextSizeConstraint", { MinTextSize = 10, MaxTextSize = if big then 20 else 17 }, prize)
		local claim = NativeUI.button(tile, "Claim", "LOCKED!", UDim2.new(.5, 0, 1, -6), UDim2.new(1, -16, 0, 30), NativeUI.GREEN)
		claim.AnchorPoint, claim.TextSize = Vector2.new(.5, 1), 16
	end
	local shields = NativeUI.text(streak, "Shields", "", UDim2.fromOffset(4, 372), UDim2.new(1, -8, 0, 40), true)
	shields.TextSize, shields.TextColor3, shields.TextWrapped, shields.TextXAlignment = 14, NativeUI.MUTED, true, Enum.TextXAlignment.Center

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
