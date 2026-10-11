--!strict
-- The foundry's live signs: billboards over Map.TownSquare.Refinery.RefinerySign and over the Commissary's sign
-- (TownSquare.Commissary.CommissarySign) with your ore waiting in the hopper,
-- the bars waiting at the collector and what stops the line (NEEDS ORE / STORAGE FULL). The HUD keeps only the sell
-- button; this is where the meters live. Local to each player, from the production line the server sends.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Format = require(ReplicatedStorage.Shared.Format)
local WorldMap = require(ReplicatedStorage.Shared.WorldMap)
local Cartoon = require(script.Parent.Parent.Cartoon)

local FoundrySignController = Knit.CreateController({ Name = "FoundrySignController" })

local INK = Cartoon.INK
local WHITE = Color3.new(1, 1, 1)
local ORANGE = Color3.fromRGB(255, 179, 92)
local GOLD = Cartoon.GOLD
local RED = Color3.fromRGB(255, 96, 96)
local BLUE = Color3.fromRGB(110, 205, 255)
local LIME = Cartoon.LIME

local function create(className: string, props: { [string]: any }, parent: Instance?): any
	local instance = Instance.new(className)
	for key, value in props do (instance :: any)[key] = value end
	instance.Parent = parent
	return instance
end

local function label(parent: Instance, name: string, y: number, h: number, color: Color3): TextLabel
	return create("TextLabel", {
		Name = name, Position = UDim2.fromScale(0.05, y), Size = UDim2.fromScale(0.9, h), BackgroundTransparency = 1,
		Font = Cartoon.FONT, Text = "", TextScaled = true, TextColor3 = color, TextStrokeColor3 = INK, TextStrokeTransparency = 0,
	}, parent)
end

-- A pill meter with its caption inside: returns the fill and the caption
local function meter(parent: Instance, name: string, y: number, color: Color3): (Frame, TextLabel)
	local track = create("Frame", {
		Name = name, Position = UDim2.fromScale(0.05, y), Size = UDim2.fromScale(0.9, 0.26),
		BackgroundColor3 = Color3.fromRGB(10, 26, 70), BorderSizePixel = 0,
	}, parent)
	create("UICorner", { CornerRadius = UDim.new(0.5, 0) }, track)
	create("UIStroke", { Color = INK, Thickness = 3 }, track)
	local fill = create("Frame", { Name = "Fill", Size = UDim2.fromScale(0, 1), BackgroundColor3 = color, BorderSizePixel = 0 }, track)
	create("UICorner", { CornerRadius = UDim.new(0.5, 0) }, fill)
	local caption = create("TextLabel", {
		Name = "Caption", Position = UDim2.fromScale(0.04, 0.08), Size = UDim2.fromScale(0.92, 0.84), BackgroundTransparency = 1, ZIndex = 2,
		Font = Cartoon.FONT, Text = "", TextScaled = true, TextColor3 = WHITE, TextStrokeColor3 = INK, TextStrokeTransparency = 0,
	}, track)
	return fill, caption
end

-- Where the signs hang: the Foundry's own sign in town and the Commissary's in the north (each a part in the map)
local SPOTS = {
	{ building = "Refinery", sign = "RefinerySign", lift = 3.4 },
	{ building = "Commissary", sign = "CommissarySign", lift = 4.6 },
}

function FoundrySignController:KnitStart()
	local player = Players.LocalPlayer
	local gui = player:WaitForChild("PlayerGui")
	local boards = {}
	for _, spot in SPOTS do
		local board = create("BillboardGui", {
			Name = "FoundrySign" .. (if spot.building == "Refinery" then "" else spot.building), Size = UDim2.fromScale(13, 5.6),
			LightInfluence = 0, MaxDistance = 150, AlwaysOnTop = false, ResetOnSpawn = false, ClipsDescendants = false,
		}, gui)
		local panel = create("Frame", { Name = "Panel", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(28, 44, 96),
			BackgroundTransparency = 0.15, BorderSizePixel = 0 }, board)
		create("UICorner", { CornerRadius = UDim.new(0.16, 0) }, panel)
		create("UIStroke", { Color = INK, Thickness = 4 }, panel)
		local oreFill, oreText = meter(panel, "Ore", 0.36, ORANGE)
		local barFill, barText = meter(panel, "Bars", 0.68, GOLD)
		table.insert(boards, {
			spot = spot, board = board, status = label(panel, "Status", 0.04, 0.26, LIME),
			oreFill = oreFill, oreText = oreText, barFill = barFill, barText = barText,
		})
	end

	local function render(state: any)
		local line = state and state.line
		for _, b in boards do
			if not line then
				b.board.Enabled = false
				continue
			end
			local function show(fill: Frame, caption: TextLabel, entry: any, word: string)
				local amount, capacity = if entry then entry.amount else 0, if entry then math.max(entry.capacity, 1) else 1
				fill.Size = UDim2.fromScale(math.clamp(amount / capacity, 0, 1), 1)
				caption.Text = word .. "  " .. Format.number(amount) .. " / " .. Format.number(capacity)
			end
			show(b.oreFill, b.oreText, line.hopper, "ORE")
			show(b.barFill, b.barText, line.collector, "BARS")
			local blocked = line.refinery and line.refinery.blocked
			b.barFill.BackgroundColor3 = if blocked == "collector" then RED else GOLD
			b.status.Text = if blocked == "collector" then "STORAGE FULL - COLLECT!" elseif blocked == "hopper" then "NEEDS ORE"
				else "REFINING " .. Format.rate(line.rate or 0) .. "/s"
			b.status.TextColor3 = if blocked == "collector" then RED elseif blocked == "hopper" then BLUE else LIME
			b.board.Enabled = b.board.Adornee ~= nil
		end
	end

	-- The map streams: re-find each sign whenever it is gone
	local latest: any = nil
	task.spawn(function()
		while true do
			for _, b in boards do
				local adornee = b.board.Adornee
				if not (adornee and adornee:IsDescendantOf(workspace)) then
					local map = WorldMap.find()
					local town = map and map:FindFirstChild("TownSquare")
					local building = town and town:FindFirstChild(b.spot.building)
					local sign = building and building:FindFirstChild(b.spot.sign)
					if sign and sign:IsA("BasePart") then
						b.board.Adornee = sign
						b.board.StudsOffsetWorldSpace = Vector3.new(0, sign.Size.Y / 2 + b.spot.lift, 0)
					else
						b.board.Adornee = nil
					end
					render(latest)
				end
			end
			task.wait(1)
		end
	end)
	Knit.GetService("PlayerStateService").State:Observe(function(state)
		latest = state
		render(state)
	end)
end

return FoundrySignController
