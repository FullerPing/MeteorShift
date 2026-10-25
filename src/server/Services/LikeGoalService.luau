--!strict
-- The like goal sign (Config.LikeGoal, Shared.LikeGoal). Every RefreshSeconds it reads the game's like count through
-- the mirror in Config.LikeGoal.Url and draws "likes / goal", a progress bar and the reward on a SurfaceGui it builds
-- on Map.TownSquare.LikeGoal.Screen. A map without the sign (other worlds) does nothing; a failed read shows just the
-- goal, from the last count that worked.
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local LikeGoal = require(ReplicatedStorage.Shared.LikeGoal)
local WorldMap = require(ReplicatedStorage.Shared.WorldMap)
local SafeLoop = require(script.Parent.Parent.Lib.SafeLoop)

local LikeGoalService = Knit.CreateService({ Name = "LikeGoalService", Client = {} })

local INK = Color3.fromRGB(22, 30, 54)
local WHITE = Color3.new(1, 1, 1)
local BLUE = Color3.fromRGB(64, 156, 255)
local GOLD = Color3.fromRGB(255, 206, 60)

local function create(className: string, props: { [string]: any }, parent: Instance?): any
	local instance = Instance.new(className)
	for key, value in props do (instance :: any)[key] = value end
	instance.Parent = parent
	return instance
end

local function text(name: string, y: number, h: number, color: Color3, parent: Instance): TextLabel
	return create("TextLabel", {
		Name = name, Position = UDim2.fromScale(0, y), Size = UDim2.fromScale(1, h), BackgroundTransparency = 1,
		Font = Enum.Font.FredokaOne, Text = "", TextScaled = true, TextColor3 = color, TextStrokeColor3 = INK, TextStrokeTransparency = 0,
	}, parent)
end

-- The count, a bar and the reward line; named LikeBoard so LeaderboardController (which adopts "Board") leaves it be
local function buildScreen(screen: BasePart)
	local old = screen:FindFirstChild("LikeBoard")
	if old then old:Destroy() end
	local gui = create("SurfaceGui", {
		Name = "LikeBoard", Face = Enum.NormalId.Front, SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud, PixelsPerStud = 50,
		LightInfluence = 0, MaxDistance = 200,
	}, screen)
	local root = create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(24, 34, 70), BorderSizePixel = 0 }, gui)
	create("UIPadding", { PaddingLeft = UDim.new(0.06, 0), PaddingRight = UDim.new(0.06, 0), PaddingTop = UDim.new(0.06, 0), PaddingBottom = UDim.new(0.06, 0) }, root)
	local count = text("Count", 0, 0.34, WHITE, root)
	local track = create("Frame", {
		Name = "Track", Position = UDim2.fromScale(0, 0.4), Size = UDim2.fromScale(1, 0.14), BackgroundColor3 = Color3.fromRGB(40, 56, 104), BorderSizePixel = 0,
	}, root)
	create("UICorner", { CornerRadius = UDim.new(0.5, 0) }, track)
	create("UIStroke", { Color = INK, Thickness = 4 }, track)
	local fill = create("Frame", { Name = "Fill", Size = UDim2.fromScale(0, 1), BackgroundColor3 = BLUE, BorderSizePixel = 0 }, track)
	create("UICorner", { CornerRadius = UDim.new(0.5, 0) }, fill)
	local reward = text("Reward", 0.6, 0.2, GOLD, root)
	local hint = text("Hint", 0.84, 0.14, Color3.fromRGB(150, 200, 255), root)
	hint.Text = "LIKE THE GAME TO HELP!"
	return { count = count, track = track, fill = fill, reward = reward }
end

local function render(screen, likes: number?)
	local settings = Config.LikeGoal
	local goal = LikeGoal.goal(settings.Goals, likes or 0)
	if not goal then
		screen.count.Text = Format.number(likes or 0) .. " LIKES"
		screen.track.Visible = false
		screen.reward.Text = "THANK YOU!"
		return
	end
	screen.track.Visible = likes ~= nil
	screen.count.Text = if likes then Format.number(likes) .. " / " .. Format.number(goal) else Format.number(goal) .. " LIKES"
	screen.fill.Size = UDim2.fromScale(math.clamp((likes or 0) / goal, 0.04, 1), 1)
	screen.reward.Text = "AT " .. Format.number(goal) .. ": " .. settings.Reward
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
		local part = sign and sign:FindFirstChild("Screen")
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
