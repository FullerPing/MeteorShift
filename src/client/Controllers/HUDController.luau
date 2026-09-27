--!strict
-- HUD built with Fusion (spec §10, early version):
--   * countdown / cooling timer and the sky countdown over the crater
--   * cash, shards, backpack meter (red when full), bars, hopper and production line
--   * "While you were away" panel (spec §6.4)
--   * event panel: core HP bar, core lock, your rank, top three
--   * announcement banner, results panel, small toasts

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Format = require(ReplicatedStorage.Shared.Format)
local Phase = require(ReplicatedStorage.Shared.Phase)

local Children = Fusion.Children
local OnEvent = Fusion.OnEvent

local player = Players.LocalPlayer

local HUDController = Knit.CreateController({
	Name = "HUDController",
})

local FONT = Enum.Font.FredokaOne
local WHITE = Color3.fromRGB(255, 255, 255)
local PANEL = Color3.fromRGB(24, 22, 30)
local ORANGE = Color3.fromRGB(255, 150, 60)
local SHARD = Color3.fromRGB(130, 220, 255)
local RED = Color3.fromRGB(235, 70, 70)
local GREEN = Color3.fromRGB(110, 220, 120)
local CASH = Color3.fromRGB(120, 235, 120)
local BAR = Color3.fromRGB(225, 220, 210)

type Scope = Fusion.Scope<typeof(Fusion)>

local function corner(scope: Scope, radius: number)
	return scope:New("UICorner")({ CornerRadius = UDim.new(0, radius) })
end

local function stroke(scope: Scope, transparency: number?)
	return scope:New("UIStroke")({
		Color = Color3.fromRGB(0, 0, 0),
		Thickness = 2,
		Transparency = transparency or 0.4,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

local function label(scope: Scope, props: { [any]: any })
	local base = {
		BackgroundTransparency = 1,
		Font = FONT,
		TextColor3 = WHITE,
		TextStrokeTransparency = 0.5,
		TextScaled = false,
	}
	for key, value in props do
		base[key] = value
	end
	return scope:New("TextLabel")(base)
end

local function pill(scope: Scope, order: number, color: Color3, text: Fusion.UsedAs<string>, size: number)
	return scope:New("Frame")({
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, size + 12),
		BackgroundColor3 = PANEL,
		BackgroundTransparency = 0.25,
		[Children] = {
			corner(scope, 10),
			stroke(scope),
			label(scope, {
				Size = UDim2.fromScale(1, 1),
				Text = text,
				TextSize = size,
				TextColor3 = color,
			}),
		},
	})
end

local function bar(scope: Scope, props: {
	Position: UDim2,
	Size: UDim2,
	AnchorPoint: Vector2?,
	LayoutOrder: number?,
	Fill: Fusion.UsedAs<number>,
	Color: Fusion.UsedAs<Color3>,
	Text: Fusion.UsedAs<string>,
})
	local animated = scope:Spring(props.Fill, 25, 1)
	return scope:New("Frame")({
		Position = props.Position,
		Size = props.Size,
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		LayoutOrder = props.LayoutOrder or 0,
		BackgroundColor3 = Color3.fromRGB(12, 10, 16),
		BackgroundTransparency = 0.2,
		[Children] = {
			corner(scope, 8),
			stroke(scope),
			scope:New("Frame")({
				Size = scope:Computed(function(use)
					return UDim2.fromScale(math.clamp(use(animated), 0, 1), 1)
				end),
				BackgroundColor3 = props.Color,
				[Children] = { corner(scope, 8) },
			}),
			label(scope, {
				Size = UDim2.fromScale(1, 1),
				Text = props.Text,
				TextSize = 16,
				ZIndex = 2,
			}),
		},
	})
end

function HUDController:KnitStart()
	local MeteorService = Knit.GetService("MeteorService")
	local ContributionService = Knit.GetService("ContributionService")
	local PlayerStateService = Knit.GetService("PlayerStateService")
	local RewardService = Knit.GetService("RewardService")
	local RefineryService = Knit.GetService("RefineryService")
	local EconomyService = Knit.GetService("EconomyService")
	local UpgradeService = Knit.GetService("UpgradeService")

	local scope = Fusion.scoped(Fusion)

	local meteorState = scope:Value(nil :: any)
	local playerState = scope:Value(nil :: any)
	local standing = scope:Value(nil :: any)
	local serverNow = scope:Value(workspace:GetServerTimeNow())
	local coreHp = scope:Value(0)
	local coreMaxHp = scope:Value(1)
	local announcement = scope:Value(nil :: any)
	local results = scope:Value(nil :: any)
	local toast = scope:Value(nil :: string?)
	local whileAway = scope:Value(nil :: any)

	MeteorService.State:Observe(function(value)
		meteorState:set(value)
	end)
	PlayerStateService.State:Observe(function(value)
		playerState:set(value)
	end)
	ContributionService.Standing:Observe(function(value)
		standing:set(value)
	end)

	local announcementToken = 0
	RewardService.Announcement:Connect(function(message)
		announcementToken += 1
		local token = announcementToken
		announcement:set(message)
		task.delay(6, function()
			if announcementToken == token then
				announcement:set(nil)
			end
		end)
	end)

	local resultsToken = 0
	RewardService.Results:Connect(function(message)
		resultsToken += 1
		local token = resultsToken
		results:set(message)
		task.delay(9, function()
			if resultsToken == token then
				results:set(nil)
			end
		end)
	end)

	local toastToken = 0
	local function showToast(text: string)
		toastToken += 1
		local token = toastToken
		toast:set(text)
		task.delay(2.5, function()
			if toastToken == token then
				toast:set(nil)
			end
		end)
	end
	PlayerStateService.BackpackFull:Connect(function()
		showToast("Backpack full! Take your ore home to your hopper.")
	end)
	RefineryService.Deposited:Connect(function(amount: number, hopperFull: boolean)
		if hopperFull then
			showToast("Hopper full! " .. Format.number(amount) .. " ore in, the rest stays in your backpack.")
		else
			showToast("Deposited " .. Format.number(amount) .. " ore into your hopper")
		end
	end)
	RefineryService.Collected:Connect(function(bars: number)
		showToast("Picked up " .. Format.number(bars) .. " bars. Sell them at the Trading Post!")
	end)
	RefineryService.WhileAway:Connect(function(report)
		if report.bars > 0 then
			whileAway:set(report)
		end
	end)
	RefineryService.Notice:Connect(showToast)
	EconomyService.Notice:Connect(showToast)
	UpgradeService.Notice:Connect(showToast)
	UpgradeService.Upgraded:Connect(function(stationId: string, level: number)
		local names = { hopper = "Hopper", conveyor = "Conveyor", refinery = "Refinery", collector = "Collection Post" }
		showToast((names[stationId] or stationId) .. " upgraded to Lv " .. level .. "!")
	end)
	EconomyService.Sold:Connect(function(bars: number, cash: number)
		showToast("Sold " .. Format.number(bars) .. " bars for +" .. Format.cash(cash))
	end)

	-- Clock and core HP polling (cheap: a handful of attribute reads)
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < 0.1 then
			return
		end
		accumulator = 0
		serverNow:set(workspace:GetServerTimeNow())
		local map = workspace:FindFirstChild("Map")
		local active = map and map:FindFirstChild("Crater") and map.Crater:FindFirstChild("ActiveMeteor")
		local meteor = active and active:FindFirstChildOfClass("Model")
		local core = meteor and meteor.PrimaryPart
		if core then
			coreHp:set(core:GetAttribute("Hp") or 0)
			coreMaxHp:set(core:GetAttribute("MaxHp") or 1)
		end
	end)

	local phase = scope:Computed(function(use)
		local s = use(meteorState)
		return if s then s.phase else Phase.Countdown
	end)
	local secondsLeft = scope:Computed(function(use)
		local s = use(meteorState)
		return if s then math.max(0, s.endsAt - use(serverNow)) else 0
	end)
	local inEvent = scope:Computed(function(use)
		local p = use(phase)
		return p == Phase.Impact or p == Phase.Active
	end)

	local timerTitle = scope:Computed(function(use)
		local s = use(meteorState)
		local p = use(phase)
		if not s then
			return "Waiting for the sky..."
		elseif p == Phase.Countdown then
			return s.typeName .. " incoming"
		elseif p == Phase.Impact then
			return "IMPACT!"
		elseif p == Phase.Active then
			return "Cooling"
		elseif p == Phase.CoreCracked then
			return "Core cracked!"
		elseif p == Phase.Cooled then
			return "Meteor cooled"
		end
		return "Next meteor soon"
	end)
	local timerText = scope:Computed(function(use)
		local p = use(phase)
		if p == Phase.Countdown or p == Phase.Active then
			return Format.time(use(secondsLeft))
		end
		return ""
	end)
	local timerColor = scope:Computed(function(use)
		local p = use(phase)
		local left = use(secondsLeft)
		if p == Phase.Active and left <= 30 then
			return RED
		elseif p == Phase.Countdown and left <= 10 then
			return ORANGE
		end
		return WHITE
	end)

	-- Sky countdown over the crater (the board itself is saved in the map)
	task.spawn(function()
		local board = workspace:WaitForChild("Map"):WaitForChild("Crater"):WaitForChild("SkyTimer"):WaitForChild("Board")
		scope:Hydrate(board:WaitForChild("Title"))({ Text = timerTitle })
		scope:Hydrate(board:WaitForChild("Time"))({ Text = timerText, TextColor3 = timerColor })
	end)

	local carried = scope:Computed(function(use)
		local s = use(playerState)
		return if s then s.carried else 0
	end)
	local capacity = scope:Computed(function(use)
		local s = use(playerState)
		return if s then s.capacity else 50
	end)
	local full = scope:Computed(function(use)
		return use(carried) >= use(capacity)
	end)

	local ui = scope:New("ScreenGui")({
		Name = "MeteorHUD",
		ResetOnSpawn = false,
		IgnoreGuiInset = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
		[Children] = {
			-- Top-centre timer
			scope:New("Frame")({
				Name = "Timer",
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 0, 8),
				Size = UDim2.fromOffset(260, 74),
				BackgroundColor3 = PANEL,
				BackgroundTransparency = 0.25,
				[Children] = {
					corner(scope, 14),
					stroke(scope),
					label(scope, {
						Position = UDim2.fromOffset(0, 6),
						Size = UDim2.new(1, 0, 0, 22),
						Text = timerTitle,
						TextSize = 20,
						TextColor3 = ORANGE,
					}),
					label(scope, {
						Position = UDim2.fromOffset(0, 28),
						Size = UDim2.new(1, 0, 0, 40),
						Text = timerText,
						TextSize = 38,
						TextColor3 = timerColor,
					}),
				},
			}),

			-- Left: currencies, backpack and home
			scope:New("Frame")({
				Name = "Stats",
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 12, 0.5, 0),
				Size = UDim2.fromOffset(240, 280),
				BackgroundTransparency = 1,
				[Children] = {
					scope:New("UIListLayout")({ Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
					pill(
						scope,
						1,
						CASH,
						scope:Computed(function(use)
							local s = use(playerState)
							return Format.cash(if s then s.cash else 0)
						end),
						26
					),
					pill(
						scope,
						2,
						SHARD,
						scope:Computed(function(use)
							local s = use(playerState)
							return "◆ " .. Format.number(if s then s.shards else 0) .. " Core Shards"
						end),
						20
					),
					bar(scope, {
						LayoutOrder = 3,
						Position = UDim2.new(),
						Size = UDim2.new(1, 0, 0, 30),
						Fill = scope:Computed(function(use)
							return use(carried) / math.max(use(capacity), 1)
						end),
						Color = scope:Computed(function(use)
							return if use(full) then RED else Color3.fromRGB(90, 160, 235)
						end),
						Text = scope:Computed(function(use)
							local text = "Backpack " .. Format.number(use(carried)) .. " / " .. Format.number(use(capacity))
							return if use(full) then text .. "  FULL" else text
						end),
					}),
					pill(
						scope,
						4,
						BAR,
						scope:Computed(function(use)
							local s = use(playerState)
							if not s or s.bars == 0 then
								return "No bars yet"
							end
							return Format.number(s.bars) .. " bars · worth " .. Format.cash(s.barValue)
						end),
						17
					),
					bar(scope, {
						LayoutOrder = 5,
						Position = UDim2.new(),
						Size = UDim2.new(1, 0, 0, 26),
						Fill = scope:Computed(function(use)
							local s = use(playerState)
							return if s then s.line.hopper.amount / math.max(s.line.hopper.capacity, 1) else 0
						end),
						Color = Color3.fromRGB(196, 120, 52),
						Text = scope:Computed(function(use)
							local s = use(playerState)
							if not s then
								return "Hopper"
							end
							return "Hopper " .. Format.number(s.line.hopper.amount) .. " / " .. Format.number(s.line.hopper.capacity)
						end),
					}),
					label(scope, {
						LayoutOrder = 6,
						Size = UDim2.new(1, 0, 0, 40),
						Text = scope:Computed(function(use)
							local s = use(playerState)
							if not s then
								return ""
							end
							local line = s.line
							local plot = if s.plotId then "Plot " .. s.plotId else "No plot"
							return string.format(
								"%s · line %g bars/s\nCollection post: %s / %s bars",
								plot,
								line.rate,
								Format.number(line.collector.amount),
								Format.number(line.collector.capacity)
							)
						end),
						TextSize = 15,
						TextWrapped = true,
						TextXAlignment = Enum.TextXAlignment.Left,
					}),
				},
			}),

			-- While you were away (spec §6.4)
			scope:New("Frame")({
				Name = "WhileAway",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(360, 250),
				BackgroundColor3 = PANEL,
				BackgroundTransparency = 0.1,
				Visible = scope:Computed(function(use)
					return use(whileAway) ~= nil
				end),
				[Children] = {
					corner(scope, 16),
					stroke(scope, 0.2),
					label(scope, {
						Position = UDim2.fromOffset(0, 12),
						Size = UDim2.new(1, 0, 0, 34),
						Text = "While you were away",
						TextSize = 28,
						TextColor3 = CASH,
					}),
					label(scope, {
						Position = UDim2.fromOffset(18, 56),
						Size = UDim2.new(1, -36, 1, -110),
						Text = scope:Computed(function(use)
							local r = use(whileAway)
							if not r then
								return ""
							end
							local hours = r.away / 3600
							local awayText = if hours >= 1
								then string.format("%.1f hours", hours)
								else string.format("%d minutes", math.floor(r.away / 60))
							local lines = {
								"You were gone " .. awayText .. ".",
								"Your production line made " .. Format.number(r.bars) .. " bars (" .. Format.cash(r.value) .. ").",
							}
							if r.capped then
								table.insert(lines, "Offline time is capped at " .. math.floor(r.seconds / 3600) .. " hours.")
							end
							if r.blocked == "hopper" then
								table.insert(lines, "Your hopper ran dry. Fill it up before you log off!")
							elseif r.blocked == "collector" then
								table.insert(lines, "Your collection post filled up. Upgrade it to store more!")
							end
							table.insert(lines, "Pick them up at your collection post.")
							return table.concat(lines, "\n")
						end),
						TextSize = 17,
						TextWrapped = true,
						TextXAlignment = Enum.TextXAlignment.Left,
						TextYAlignment = Enum.TextYAlignment.Top,
					}),
					scope:New("TextButton")({
						AnchorPoint = Vector2.new(0.5, 1),
						Position = UDim2.new(0.5, 0, 1, -12),
						Size = UDim2.fromOffset(140, 36),
						BackgroundColor3 = ORANGE,
						Font = FONT,
						Text = "Nice!",
						TextSize = 20,
						TextColor3 = WHITE,
						[OnEvent("Activated")] = function()
							whileAway:set(nil)
						end,
						[Children] = { corner(scope, 10) },
					}),
				},
			}),

			-- Right: event panel (core HP, lock, rank, top three)
			scope:New("Frame")({
				Name = "EventPanel",
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -12, 0, 90),
				Size = UDim2.fromOffset(250, 200),
				BackgroundColor3 = PANEL,
				BackgroundTransparency = 0.25,
				Visible = inEvent,
				[Children] = {
					corner(scope, 12),
					stroke(scope),
					scope:New("UIPadding")({
						PaddingLeft = UDim.new(0, 10),
						PaddingRight = UDim.new(0, 10),
						PaddingTop = UDim.new(0, 8),
					}),
					scope:New("UIListLayout")({ Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
					label(scope, {
						LayoutOrder = 1,
						Size = UDim2.new(1, 0, 0, 22),
						Text = scope:Computed(function(use)
							local s = use(meteorState)
							if not s then
								return ""
							end
							if s.unlocked then
								return "CORE EXPOSED - hit it!"
							end
							local needed = math.ceil(s.crustTotal * 0.6)
							return string.format("Core locked: crust %d/%d", s.crustBroken, needed)
						end),
						TextSize = 18,
						TextColor3 = scope:Computed(function(use)
							local s = use(meteorState)
							return if s and s.unlocked then ORANGE else WHITE
						end),
					}),
					bar(scope, {
						LayoutOrder = 2,
						Position = UDim2.new(),
						Size = UDim2.new(1, 0, 0, 26),
						Fill = scope:Computed(function(use)
							return use(coreHp) / math.max(use(coreMaxHp), 1e-6)
						end),
						Color = scope:Computed(function(use)
							local s = use(meteorState)
							return if s and s.unlocked then ORANGE else Color3.fromRGB(120, 110, 110)
						end),
						Text = scope:Computed(function(use)
							-- HP runs on hidden Mining Power (spec §5.3), so show how much is left
							local fraction = use(coreHp) / math.max(use(coreMaxHp), 1e-6)
							return string.format("Core %d%%", math.ceil(math.clamp(fraction, 0, 1) * 100))
						end),
					}),
					label(scope, {
						LayoutOrder = 3,
						Size = UDim2.new(1, 0, 0, 22),
						Text = scope:Computed(function(use)
							local s = use(standing)
							if not s or s.rank == 0 then
								return "Mine a node to join in!"
							end
							return string.format("You: #%d of %d  ·  %s ore", s.rank, s.players, Format.number(s.ore))
						end),
						TextSize = 17,
						TextColor3 = GREEN,
					}),
					label(scope, {
						LayoutOrder = 4,
						Size = UDim2.new(1, 0, 0, 70),
						Text = scope:Computed(function(use)
							local s = use(standing)
							if not s or #s.top == 0 then
								return ""
							end
							local lines = {}
							for i, entry in s.top do
								table.insert(lines, string.format("%d. %s  %s", i, entry.name, Format.number(entry.contribution)))
							end
							return table.concat(lines, "\n")
						end),
						TextSize = 16,
						TextXAlignment = Enum.TextXAlignment.Left,
						TextYAlignment = Enum.TextYAlignment.Top,
					}),
				},
			}),

			-- Announcement banner
			label(scope, {
				Name = "Banner",
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 0, 92),
				Size = UDim2.new(0.8, 0, 0, 40),
				Text = scope:Computed(function(use)
					local a = use(announcement)
					return if a then a.text else ""
				end),
				TextSize = 30,
				TextColor3 = scope:Computed(function(use)
					local a = use(announcement)
					if a and a.kind == "Cooled" then
						return Color3.fromRGB(170, 200, 230)
					end
					return Color3.fromRGB(255, 215, 90)
				end),
				TextStrokeTransparency = 0,
				Visible = scope:Computed(function(use)
					return use(announcement) ~= nil
				end),
			}),

			-- Results panel
			scope:New("Frame")({
				Name = "Results",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.55),
				Size = UDim2.fromOffset(320, 220),
				BackgroundColor3 = PANEL,
				BackgroundTransparency = 0.15,
				Visible = scope:Computed(function(use)
					return use(results) ~= nil
				end),
				[Children] = {
					corner(scope, 16),
					stroke(scope, 0.2),
					label(scope, {
						Position = UDim2.fromOffset(0, 10),
						Size = UDim2.new(1, 0, 0, 34),
						Text = scope:Computed(function(use)
							local r = use(results)
							return if r and r.cracked then "Core cracked!" else "Meteor cooled"
						end),
						TextSize = 30,
						TextColor3 = ORANGE,
					}),
					label(scope, {
						Position = UDim2.fromOffset(16, 52),
						Size = UDim2.new(1, -32, 1, -100),
						Text = scope:Computed(function(use)
							local r = use(results)
							if not r then
								return ""
							end
							local lines = { "Ore mined: " .. Format.number(r.ore) }
							if r.cracked and r.shards > 0 then
								local shardLine = string.format("Core Shards: +%d  (%d floor + %d share", r.shards, r.floor, r.bonus)
								if r.top > 0 then
									shardLine ..= string.format(" + %d top 3", r.top)
								end
								table.insert(lines, shardLine .. ")")
							elseif r.cracked then
								table.insert(lines, "Hit the core next time to earn Core Shards!")
							else
								table.insert(lines, "No shards this time. Your ore is kept.")
							end
							for _, leader in r.leaders do
								table.insert(lines, string.format("#%d %s  +%d", leader.place, leader.name, leader.shards))
							end
							return table.concat(lines, "\n")
						end),
						TextSize = 18,
						TextWrapped = true,
						TextXAlignment = Enum.TextXAlignment.Left,
						TextYAlignment = Enum.TextYAlignment.Top,
					}),
					scope:New("TextButton")({
						AnchorPoint = Vector2.new(0.5, 1),
						Position = UDim2.new(0.5, 0, 1, -10),
						Size = UDim2.fromOffset(120, 34),
						BackgroundColor3 = ORANGE,
						Font = FONT,
						Text = "Nice!",
						TextSize = 20,
						TextColor3 = WHITE,
						[OnEvent("Activated")] = function()
							results:set(nil)
						end,
						[Children] = { corner(scope, 10) },
					}),
				},
			}),

			-- Toast
			label(scope, {
				Name = "Toast",
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.5, 0, 1, -110),
				Size = UDim2.new(0.8, 0, 0, 30),
				Text = scope:Computed(function(use)
					return use(toast) or ""
				end),
				TextSize = 22,
				TextStrokeTransparency = 0,
				Visible = scope:Computed(function(use)
					return use(toast) ~= nil
				end),
			}),

			-- Studio-only playtest helpers
			if RunService:IsStudio()
				then scope:New("Frame")({
					Name = "Dev",
					AnchorPoint = Vector2.new(1, 1),
					Position = UDim2.new(1, -12, 1, -12),
					Size = UDim2.fromOffset(170, 66),
					BackgroundTransparency = 1,
					[Children] = {
						scope:New("UIListLayout")({
							Padding = UDim.new(0, 6),
							VerticalAlignment = Enum.VerticalAlignment.Bottom,
						}),
						scope:New("TextButton")({
							Name = "DevSkip",
							Size = UDim2.new(1, 0, 0, 30),
							BackgroundColor3 = Color3.fromRGB(80, 60, 120),
							Font = FONT,
							Text = "[Studio] Meteor now",
							TextSize = 16,
							TextColor3 = WHITE,
							Visible = scope:Computed(function(use)
								return use(phase) == Phase.Countdown
							end),
							[OnEvent("Activated")] = function()
								MeteorService:DevSkipCountdown()
							end,
							[Children] = { corner(scope, 8) },
						}),
						scope:New("TextButton")({
							Name = "DevAway",
							Size = UDim2.new(1, 0, 0, 30),
							BackgroundColor3 = Color3.fromRGB(80, 60, 120),
							Font = FONT,
							Text = "[Studio] Away 1 hour",
							TextSize = 16,
							TextColor3 = WHITE,
							[OnEvent("Activated")] = function()
								RefineryService:DevSimulateAway(3600)
							end,
							[Children] = { corner(scope, 8) },
						}),
					},
				})
				else nil,

		},
	})

	self.Gui = ui
end

return HUDController
