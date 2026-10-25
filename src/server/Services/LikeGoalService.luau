--!strict
-- The like goal hologram (Config.LikeGoal, Shared.LikeGoal). Every RefreshSeconds it reads the game's like count
-- through the mirror in Config.LikeGoal.Url and floats "likes / goal", a thin bar and the reward in a BillboardGui on
-- Map.TownSquare.LikeGoal.Anchor (an invisible part above a glowing projector disc). A map without it (other worlds)
-- does nothing. When the mirror fails it shows the count an admin typed with /likes, else the last count that
-- worked, else just the goal.
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local LikeGoal = require(ReplicatedStorage.Shared.LikeGoal)
local WorldMap = require(ReplicatedStorage.Shared.WorldMap)
local SafeLoop = require(script.Parent.Parent.Lib.SafeLoop)

local LikeGoalService = Knit.CreateService({ Name = "LikeGoalService", Client = {} })

local WHITE = Color3.new(1, 1, 1)
local GLOW = Color3.fromRGB(110, 210, 255)
local GOLD = Color3.fromRGB(255, 214, 70)
local INK = Color3.fromRGB(16, 28, 66) -- outlines and the bar's backing: keeps it readable against bright sky and grass

local function create(className: string, props: { [string]: any }, parent: Instance?): any
	local instance = Instance.new(className)
	for key, value in props do (instance :: any)[key] = value end
	instance.Parent = parent
	return instance
end

local function text(name: string, y: number, h: number, color: Color3, parent: Instance): TextLabel
	local label = create("TextLabel", {
		Name = name, Position = UDim2.fromScale(0, y), Size = UDim2.fromScale(1, h), BackgroundTransparency = 1,
		Font = Enum.Font.FredokaOne, Text = "", TextScaled = true, TextColor3 = color,
	}, parent)
	create("UIStroke", { Color = INK, Thickness = 4, LineJoinMode = Enum.LineJoinMode.Round }, label)
	return label
end

-- Floating text and a bar with no panel behind them, sized in studs so it reads like an object in the world
local function buildScreen(anchor: BasePart)
	local old = anchor:FindFirstChild("LikeHologram")
	if old then old:Destroy() end
	local gui = create("BillboardGui", {
		Name = "LikeHologram", Size = UDim2.fromScale(18, 11), LightInfluence = 0, MaxDistance = 250, ResetOnSpawn = false,
	}, anchor)
	local count = text("Count", 0, 0.36, WHITE, gui)
	local track = create("Frame", {
		Name = "Track", Position = UDim2.fromScale(0.08, 0.41), Size = UDim2.fromScale(0.84, 0.11), BackgroundColor3 = INK,
		BackgroundTransparency = 0.15, BorderSizePixel = 0,
	}, gui)
	create("UICorner", { CornerRadius = UDim.new(0.5, 0) }, track)
	create("UIStroke", { Color = WHITE, Thickness = 3 }, track)
	local fill = create("Frame", { Name = "Fill", Size = UDim2.fromScale(0, 1), BackgroundColor3 = GLOW, BorderSizePixel = 0 }, track)
	create("UICorner", { CornerRadius = UDim.new(0.5, 0) }, fill)
	local reward = text("Reward", 0.56, 0.2, GOLD, gui)
	text("Codes", 0.8, 0.17, WHITE, gui).Text = "CURRENT CODES: " .. table.concat(Config.LikeGoal.Codes, ", ")
	return { count = count, track = track, fill = fill, reward = reward }
end

local function render(screen, likes: number?)
	local settings = Config.LikeGoal
	local goal = LikeGoal.goal(settings.Goals, likes or 0)
	if not goal then
		screen.count.Text = "👍 " .. Format.number(likes or 0)
		screen.track.Visible = false
		screen.reward.Text = "THANK YOU!"
		return
	end
	screen.track.Visible = likes ~= nil
	screen.count.Text = if likes then "👍 " .. Format.number(likes) .. " / " .. Format.number(goal) else "👍 GOAL: " .. Format.number(goal)
	screen.fill.Size = UDim2.fromScale(math.clamp((likes or 0) / goal, 0.04, 1), 1)
	screen.reward.Text = settings.Reward
end

-- The like count, or nil when the mirror is down or answers with something else
local function fetch(): number?
	local ok, body = pcall(HttpService.GetAsync, HttpService, string.format(Config.LikeGoal.Url, game.GameId))
	if not ok then return nil end
	local decoded, reply = pcall(HttpService.JSONDecode, HttpService, body)
	return if decoded then LikeGoal.likes(reply) else nil
end

-- The count an admin set with /likes, shared by every server through a DataStore; used when the mirror fails
local store: DataStore? = nil
local function typed(): number?
	if not store then return nil end
	local ok, value = pcall(store.GetAsync, store, "likes")
	return if ok and type(value) == "number" then value else nil
end

local screen = nil
local likes: number? = nil

-- /likes <count>: shows `count` here now and on the other servers at their next refresh, unless the live count loads
function LikeGoalService:SetLikes(count: number): boolean
	likes = count
	if screen then render(screen, likes) end
	return store ~= nil and (pcall(store.SetAsync, store, "likes", count))
end

function LikeGoalService:KnitStart()
	if not (RunService:IsStudio() and ServerStorage:GetAttribute("DevMemoryStore") == true) then
		local ok, result = pcall(DataStoreService.GetDataStore, DataStoreService, "LikeGoal")
		store = if ok then result else nil
	end
	task.spawn(function()
		local sign = WorldMap.wait():WaitForChild("TownSquare"):WaitForChild("LikeGoal", 30)
		local part = sign and sign:FindFirstChild("Anchor")
		if not (part and part:IsA("BasePart")) then return end
		screen = buildScreen(part)
		render(screen, likes)
		while true do
			SafeLoop.step("LikeGoalRefresh", function()
				likes = fetch() or typed() or likes
				render(screen, likes)
			end)
			task.wait(Config.LikeGoal.RefreshSeconds)
		end
	end)
end

return LikeGoalService
