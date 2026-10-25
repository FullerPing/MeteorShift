--!strict
-- The like goal hologram (Config.LikeGoal, Shared.LikeGoal). Every RefreshSeconds it reads the game's like count
-- through the mirror in Config.LikeGoal.Url and floats "likes / goal", a thin bar and the reward in a BillboardGui on
-- Map.TownSquare.LikeGoal.Anchor (an invisible part above a glowing projector disc). A map without it (other worlds)
-- does nothing; a failed read shows just the goal, from the last count that worked.
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local LikeGoal = require(ReplicatedStorage.Shared.LikeGoal)
local WorldMap = require(ReplicatedStorage.Shared.WorldMap)
local SafeLoop = require(script.Parent.Parent.Lib.SafeLoop)

local LikeGoalService = Knit.CreateService({ Name = "LikeGoalService", Client = {} })

local GLOW = Color3.fromRGB(150, 225, 255)
local EDGE = Color3.fromRGB(30, 90, 170)

local function create(className: string, props: { [string]: any }, parent: Instance?): any
	local instance = Instance.new(className)
	for key, value in props do (instance :: any)[key] = value end
	instance.Parent = parent
	return instance
end

local function text(name: string, y: number, h: number, parent: Instance): TextLabel
	return create("TextLabel", {
		Name = name, Position = UDim2.fromScale(0, y), Size = UDim2.fromScale(1, h), BackgroundTransparency = 1,
		Font = Enum.Font.FredokaOne, Text = "", TextScaled = true, TextColor3 = GLOW, TextStrokeColor3 = EDGE, TextStrokeTransparency = 0.3,
	}, parent)
end

-- See-through glowing text and a thin bar, sized in studs so it reads like an object in the world
local function buildScreen(anchor: BasePart)
	local old = anchor:FindFirstChild("LikeHologram")
	if old then old:Destroy() end
	local gui = create("BillboardGui", {
		Name = "LikeHologram", Size = UDim2.fromScale(14, 7), LightInfluence = 0, MaxDistance = 200, ResetOnSpawn = false,
	}, anchor)
	local count = text("Count", 0, 0.42, gui)
	local track = create("Frame", {
		Name = "Track", Position = UDim2.fromScale(0.1, 0.48), Size = UDim2.fromScale(0.8, 0.08), BackgroundColor3 = GLOW,
		BackgroundTransparency = 0.8, BorderSizePixel = 0,
	}, gui)
	create("UICorner", { CornerRadius = UDim.new(0.5, 0) }, track)
	create("UIStroke", { Color = GLOW, Thickness = 2, Transparency = 0.3 }, track)
	local fill = create("Frame", { Name = "Fill", Size = UDim2.fromScale(0, 1), BackgroundColor3 = GLOW, BackgroundTransparency = 0.1, BorderSizePixel = 0 }, track)
	create("UICorner", { CornerRadius = UDim.new(0.5, 0) }, fill)
	local reward = text("Reward", 0.64, 0.24, gui)
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

function LikeGoalService:KnitStart()
	task.spawn(function()
		local sign = WorldMap.wait():WaitForChild("TownSquare"):WaitForChild("LikeGoal", 30)
		local part = sign and sign:FindFirstChild("Anchor")
		if not (part and part:IsA("BasePart")) then return end
		local screen = buildScreen(part)
		local likes: number? = nil
		render(screen, likes)
		while true do
			SafeLoop.step("LikeGoalRefresh", function()
				likes = fetch() or likes
				render(screen, likes)
			end)
			task.wait(Config.LikeGoal.RefreshSeconds)
		end
	end)
end

return LikeGoalService
