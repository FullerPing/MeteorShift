--!strict
-- The leaderboards beside the Foundry (Config.Leaderboards). Every RefreshInterval it saves each online player's
-- score to the board's OrderedDataStore (only when it changed) and reloads the top rows, so the boards show every
-- server. Without DataStores (an unpublished Studio place, or the DevMemoryStore opt-in) it ranks this server's
-- players instead. The rows are a SurfaceGui the server builds on Map.TownSquare.Leaderboards.<Id>.Screen.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Leaderboards = require(ReplicatedStorage.Shared.Leaderboards)
local WorldMap = require(ReplicatedStorage.Shared.WorldMap)
local SafeLoop = require(script.Parent.Parent.Lib.SafeLoop)

local LeaderboardService = Knit.CreateService({ Name = "LeaderboardService", Client = {} })

local PlayerStateService

local INK = Color3.fromRGB(22, 30, 54)
local WHITE = Color3.new(1, 1, 1)
local MEDALS = { Color3.fromRGB(255, 206, 60), Color3.fromRGB(214, 224, 238), Color3.fromRGB(236, 150, 84) }
local ROW_A, ROW_B = Color3.fromRGB(40, 56, 104), Color3.fromRGB(32, 46, 88)

local stores: { [string]: OrderedDataStore } = {}
local saved: { [string]: { [number]: number } } = {} -- board id -> user id -> last score written
local names: { [number]: string } = {}

local function nameOf(userId: number): string
	if names[userId] then return names[userId] end
	local online = Players:GetPlayerByUserId(userId)
	if online then
		names[userId] = online.DisplayName
		return online.DisplayName
	end
	local ok, name = pcall(Players.GetNameFromUserIdAsync, Players, userId)
	names[userId] = if ok and name then name else "Player"
	return names[userId]
end

local function create(className: string, props: { [string]: any }, parent: Instance?): any
	local instance = Instance.new(className)
	for key, value in props do (instance :: any)[key] = value end
	instance.Parent = parent
	return instance
end

-- The board's screen: a title strip and a scrolling list of `Rows` rows of rank, name and score, `Visible` at a time
local function buildScreen(screen: BasePart, board: Config.LeaderboardBoard): { { TextLabel } }
	local old = screen:FindFirstChild("Board")
	if old then old:Destroy() end
	local gui = create("SurfaceGui", {
		Name = "Board", Face = Enum.NormalId.Front, SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud, PixelsPerStud = 50,
		LightInfluence = 0, MaxDistance = 160, ResetOnSpawn = false,
	}, screen)
	local root = create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(24, 34, 70), BorderSizePixel = 0 }, gui)
	create("UIPadding", { PaddingLeft = UDim.new(0.04, 0), PaddingRight = UDim.new(0.04, 0), PaddingTop = UDim.new(0.03, 0), PaddingBottom = UDim.new(0.03, 0) }, root)
	create("TextLabel", {
		Name = "Unit", Size = UDim2.fromScale(1, 0.08), BackgroundTransparency = 1, Font = Enum.Font.FredokaOne,
		Text = string.upper(board.Unit), TextScaled = true, TextColor3 = Color3.fromRGB(150, 200, 255),
	}, root)
	-- each player scrolls their own copy (a client's CanvasPosition doesn't replicate); rows are sized in pixels so
	-- `Visible` of them fill the list (PixelsPerStud x the screen's height, less the padding and the title)
	local list = create("ScrollingFrame", {
		Name = "List", Position = UDim2.fromScale(0, 0.1), Size = UDim2.fromScale(1, 0.9), BackgroundTransparency = 1,
		BorderSizePixel = 0, ScrollBarThickness = 14, ScrollBarImageColor3 = Color3.fromRGB(150, 200, 255),
		ScrollingDirection = Enum.ScrollingDirection.Y, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
	}, root)
	local rowHeight = screen.Size.Y * gui.PixelsPerStud * 0.94 * 0.9 / Config.Leaderboards.Visible
	create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, math.floor(rowHeight * 0.1)) }, list)
	local rows = {}
	local count = Config.Leaderboards.Rows
	for index = 1, count do
		local row = create("Frame", {
			Name = "Row" .. index, LayoutOrder = index, Size = UDim2.new(1, -18, 0, math.floor(rowHeight * 0.9)),
			BackgroundColor3 = if index % 2 == 1 then ROW_A else ROW_B, BorderSizePixel = 0,
		}, list)
		create("UICorner", { CornerRadius = UDim.new(0.3, 0) }, row)
		local function cell(name: string, x: number, w: number, align: Enum.TextXAlignment, color: Color3): TextLabel
			return create("TextLabel", {
				Name = name, Position = UDim2.fromScale(x, 0.1), Size = UDim2.fromScale(w, 0.8), BackgroundTransparency = 1,
				Font = Enum.Font.FredokaOne, Text = "", TextScaled = true, TextXAlignment = align, TextColor3 = color,
				TextStrokeColor3 = INK, TextStrokeTransparency = 0,
			}, row)
		end
		local medal = MEDALS[index]
		table.insert(rows, {
			cell("Rank", 0.02, 0.1, Enum.TextXAlignment.Center, medal or WHITE),
			cell("Name", 0.15, 0.55, Enum.TextXAlignment.Left, medal or WHITE),
			cell("Score", 0.7, 0.28, Enum.TextXAlignment.Right, medal or WHITE),
		})
	end
	return rows
end

local function render(rows: { { TextLabel } }, ranked: { Leaderboards.Entry }, board: Config.LeaderboardBoard)
	for index, row in rows do
		local entry = ranked[index]
		row[1].Text = "#" .. index
		row[2].Text = if entry then entry.name else "-"
		row[3].Text = if entry then Leaderboards.display(board, entry.value, Format.number) else ""
	end
end

-- This server's players, ranked: the fallback without DataStores
local function localTop(board: Config.LeaderboardBoard): { Leaderboards.Entry }
	local entries = {}
	for _, player in Players:GetPlayers() do
		local data = PlayerStateService:Get(player)
		if data then
			table.insert(entries, { userId = player.UserId, name = player.DisplayName, value = Leaderboards.valueOf(board.Path, data) })
		end
	end
	return Leaderboards.rank(entries, Config.Leaderboards.Rows)
end

-- Saves changed scores, then reads the top rows of every server; nil when the store fails
local function globalTop(board: Config.LeaderboardBoard): { Leaderboards.Entry }?
	local store = stores[board.Id]
	if not store then return nil end
	local written = saved[board.Id]
	for _, player in Players:GetPlayers() do
		local data = PlayerStateService:Get(player)
		local value = if data then Leaderboards.valueOf(board.Path, data) else 0
		if data and value > 0 and written[player.UserId] ~= value then
			local ok = pcall(store.SetAsync, store, tostring(player.UserId), value)
			if ok then written[player.UserId] = value end
		end
	end
	local ok, page = pcall(function()
		return store:GetSortedAsync(false, Config.Leaderboards.Rows):GetCurrentPage()
	end)
	if not ok then return nil end
	local entries = {}
	for _, item in page do
		local userId = tonumber(item.key)
		if userId then table.insert(entries, { userId = userId, name = nameOf(userId), value = item.value }) end
	end
	return Leaderboards.rank(entries, Config.Leaderboards.Rows)
end

function LeaderboardService:KnitInit()
	PlayerStateService = Knit.GetService("PlayerStateService")
end

function LeaderboardService:KnitStart()
	local memoryOnly = RunService:IsStudio() and ServerStorage:GetAttribute("DevMemoryStore") == true
	for _, board in Config.Leaderboards.Boards do
		saved[board.Id] = {}
		if not memoryOnly then
			local ok, store = pcall(DataStoreService.GetOrderedDataStore, DataStoreService, board.Store)
			if ok then stores[board.Id] = store end
		end
	end
	Players.PlayerRemoving:Connect(function(player)
		names[player.UserId] = nil
		for _, written in saved do
			written[player.UserId] = nil
		end
	end)

	task.spawn(function()
		local map = WorldMap.wait()
		local town = map:WaitForChild("TownSquare")
		local folder = town:WaitForChild("Leaderboards", 30)
		if not folder then
			warn("[LeaderboardService] Map.TownSquare.Leaderboards is missing")
			return
		end
		local screens = {}
		local placed: { Model } = {}
		for _, board in Config.Leaderboards.Boards do
			local model = folder:FindFirstChild(board.Id)
			-- a board the map has no stand for: a copy of the last stand, set beside it on the side away from the others
			-- shortcut: the spot is worked out, not designed; place a real stand in Studio (tools/map-v2/Leaderboards) to choose it
			if not model and #placed >= 2 then
				local last, before = placed[#placed], placed[#placed - 1]
				local copy = last:Clone()
				copy.Name = board.Id
				local pivot = last:GetPivot()
				local side = Vector3.new(pivot.RightVector.X, 0, pivot.RightVector.Z).Unit
				if side:Dot(pivot.Position - before:GetPivot().Position) < 0 then side = -side end
				copy:PivotTo(pivot + side * (copy:GetExtentsSize().X + 3))
				for _, item in copy:GetDescendants() do
					local previous = Config.Leaderboards.Boards[#placed].Title
					if (item:IsA("TextLabel") or item:IsA("TextButton")) and item.Text == previous then item.Text = board.Title end
				end
				copy.Parent = folder
				model = copy
			end
			if model and model:IsA("Model") then table.insert(placed, model) end
			local screen = model and model:FindFirstChild("Screen")
			if screen and screen:IsA("BasePart") then
				screens[board.Id] = buildScreen(screen, board)
			else
				warn("[LeaderboardService] no screen for board " .. board.Id)
			end
		end
		task.wait(5) -- let the first profiles load
		while true do
			SafeLoop.step("LeaderboardRefresh", function()
				for _, board in Config.Leaderboards.Boards do
					local rows = screens[board.Id]
					if rows then
						local top = globalTop(board)
						render(rows, top or localTop(board), board)
					end
				end
			end)
			task.wait(Config.Leaderboards.RefreshInterval)
		end
	end)
end

return LeaderboardService
