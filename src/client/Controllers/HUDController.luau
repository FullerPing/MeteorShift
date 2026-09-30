--!strict
-- HUD built with Fusion (spec §10):
--   * countdown / cooling timer and the sky countdown over the crater, titled with
--     the meteor type in its glow colour (spec §8.1)
--   * cash (counts up on every sale, "+$" floater, rebirth multiplier once above
--     ×1, spec §8.3), shards, pickaxe, backpack
--     meter (red when full), bars, hopper and production line
--   * "While you were away" panel (spec §6.4)
--   * event panel: core HP bar, core lock, your rank, top three
--   * announcement banner, results panel, small toasts

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local MeteorTypes = require(ReplicatedStorage.Shared.MeteorTypes)
local Phase = require(ReplicatedStorage.Shared.Phase)
local Rebirth = require(ReplicatedStorage.Shared.Rebirth)
local UI = require(script.Parent.Parent.UI)

local Children = Fusion.Children
local OnEvent = Fusion.OnEvent

local player = Players.LocalPlayer

local HUDController = Knit.CreateController({
	Name = "HUDController",
})

local FONT = UI.FONT
local WHITE = UI.WHITE
local ORANGE = UI.ORANGE
local SHARD = UI.SHARD
local RED = UI.RED
local GREEN = UI.GREEN
local CASH = UI.CASH
local BAR = UI.BAR
local OUTLINE = UI.OUTLINE

type Scope = UI.Scope

-- Shows a small toast; set once the HUD is built (see HUDController:Toast)
local showToastHandler: ((text: string) -> ())? = nil

-- Other controllers post their small toasts here (e.g. "New mineral: X!").
function HUDController:Toast(text: string)
	if showToastHandler then
		showToastHandler(text)
	end
end

local corner = UI.corner
local stroke = UI.stroke
local label = UI.label

local function stat(
	scope: Scope,
	order: number,
	kind: string,
	color: Color3,
	value: Fusion.UsedAs<string>,
	caption: Fusion.UsedAs<string>
)
	return scope:New("Frame")({
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, 51),
		BackgroundTransparency = 1,
		[Children] = {
			UI.icon(scope, kind, {
				Name = "Icon",
				Position = UDim2.fromOffset(0, 6),
				Size = UDim2.fromOffset(38, 38),
			}),
			label(scope, {
				Position = UDim2.fromOffset(49, 1),
				Size = UDim2.new(1, -49, 0, 29),
				Text = value,
				TextSize = 28,
				TextColor3 = color,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			UI.body(scope, {
				Position = UDim2.fromOffset(50, 30),
				Size = UDim2.new(1, -50, 0, 17),
				Text = caption,
				TextSize = 12,
				TextColor3 = UI.SUBTEXT,
				TextXAlignment = Enum.TextXAlignment.Left,
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
		BackgroundTransparency = 1,
		[Children] = {
			scope:New("Frame")({
				Position = UDim2.new(0, 0, 1, -10),
				Size = UDim2.new(1, 0, 0, 10),
				BackgroundColor3 = OUTLINE,
				BorderSizePixel = 0,
				[Children] = {
					corner(scope, 5),
					scope:New("Frame")({
						Size = scope:Computed(function(use)
							return UDim2.fromScale(math.clamp(use(animated), 0, 1), 1)
						end),
						BackgroundColor3 = props.Color,
						BorderSizePixel = 0,
						[Children] = { corner(scope, 5) },
					}),
				},
			}),
			UI.body(scope, {
				Size = UDim2.new(1, 0, 1, -13),
				Text = props.Text,
				TextSize = 14,
				TextXAlignment = Enum.TextXAlignment.Left,
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
	local ShopService = Knit.GetService("ShopService")

	local scope = Fusion.scoped(Fusion)
	local hud = UI.hud(scope)
	local hudScale = scope:Computed(function(use)
		return use(hud).scale
	end)
	local function scale()
		return scope:New("UIScale")({ Scale = hudScale })
	end
	local function leftPosition(y: number)
		return scope:Computed(function(use)
			return UDim2.fromOffset(14, y * use(hudScale))
		end)
	end

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
	showToastHandler = showToast
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
	ShopService.Notice:Connect(showToast)
	ShopService.Purchased:Connect(function(kind: string, tier: number)
		local item = if kind == "pickaxe" then Config.Pickaxes[tier] else Config.Backpacks[tier]
		if item then
			showToast("You got the " .. item.Name .. "!")
		end
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
			return s.typeName .. " cooling"
		elseif p == Phase.CoreCracked then
			return "Core cracked!"
		elseif p == Phase.Cooled then
			return s.typeName .. " cooled"
		end
		return "Next meteor soon"
	end)
	-- The title glows in the meteor type's colour (Iron orange, Ice cyan, Crystal magenta)
	local titleColor = scope:Computed(function(use)
		local s = use(meteorState)
		local meteorType = s and Config.Meteor.Types[s.type]
		return if meteorType then meteorType.GlowColor else ORANGE
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
		scope:Hydrate(board:WaitForChild("Title"))({
			Text = timerTitle,
			Font = FONT,
			TextColor3 = titleColor,
			TextStrokeColor3 = OUTLINE,
			TextStrokeTransparency = 0,
		})
		scope:Hydrate(board:WaitForChild("Time"))({
			Text = timerText,
			Font = FONT,
			TextColor3 = timerColor,
			TextStrokeColor3 = OUTLINE,
			TextStrokeTransparency = 0,
		})
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

	-- The cash counter counts up to the new total instead of jumping (spec §7.5)
	local cashShown = scope:Tween(
		scope:Computed(function(use)
			local s = use(playerState)
			return if s then s.cash else 0
		end),
		TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	)

	local ui = scope:New("ScreenGui")({
		Name = "MeteorHUD",
		ResetOnSpawn = false,
		IgnoreGuiInset = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
		[Children] = {
			-- Floating event clock
			scope:New("Frame")({
				Name = "Timer",
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 0, 10),
				Size = UDim2.fromOffset(250, 66),
				BackgroundColor3 = UI.PANEL_DARK,
				BackgroundTransparency = 0.12,
				[Children] = {
					scale(),
					UI.cardFill(scope),
					label(scope, {
						Position = UDim2.fromOffset(0, 4),
						Size = UDim2.new(1, 0, 0, 21),
						Text = timerTitle,
						TextSize = 18,
						TextColor3 = titleColor,
					}),
					label(scope, {
						Position = UDim2.fromOffset(0, 22),
						Size = UDim2.new(1, 0, 0, 40),
						Text = timerText,
						TextSize = 36,
						TextColor3 = timerColor,
					}),
				},
			}),

			-- Resources share one quiet backing; equipment and the factory get their own cards.
			scope:New("Frame")({
				Name = "Resources",
				Position = leftPosition(80),
				Size = UDim2.fromOffset(236, 266),
				BackgroundColor3 = UI.PANEL_DARK,
				BackgroundTransparency = 0.08,
				[Children] = {
					scale(),
					UI.cardFill(scope),
					UI.body(scope, {
						Position = UDim2.fromOffset(14, 11),
						Size = UDim2.new(1, -28, 0, 16),
						Text = "RESOURCES",
						TextSize = 12,
						TextColor3 = UI.SUBTEXT,
						TextXAlignment = Enum.TextXAlignment.Left,
					}),
					scope:New("Frame")({
						Position = UDim2.fromOffset(14, 31),
						Size = UDim2.new(1, -28, 0, 216),
						BackgroundTransparency = 1,
						[Children] = {
							scope:New("UIListLayout")({ Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
							stat(scope, 1, "cash", CASH, scope:Computed(function(use)
								return Format.number(use(cashShown))
							end), scope:Computed(function(use)
								-- The rebirth cash multiplier, once there is one (spec §8.3)
								local s = use(playerState)
								local multiplier = Rebirth.multiplier(if s then s.rebirths else 0)
								return if multiplier > 1 then "CASH  ·  REBIRTH ×" .. Format.number(multiplier) else "CASH"
							end)),
							stat(scope, 2, "shard", SHARD, scope:Computed(function(use)
								local s = use(playerState)
								return Format.number(if s then s.shards else 0)
							end), "CORE SHARDS"),
							stat(scope, 3, "ore", WHITE, scope:Computed(function(use)
								return Format.number(use(carried))
							end), scope:Computed(function(use)
								return "ORE  /  " .. Format.number(use(capacity)) .. (if use(full) then "  FULL!" else " CAPACITY")
							end)),
							stat(scope, 4, "bar", BAR, scope:Computed(function(use)
								local s = use(playerState)
								return Format.number(if s then s.bars else 0)
							end), scope:Computed(function(use)
								local s = use(playerState)
								return "BARS  ·  " .. Format.cash(if s then s.barValue else 0)
							end)),
						},
					}),
					scope:New("Frame")({
						Position = UDim2.fromOffset(64, 196),
						Size = UDim2.new(1, -78, 0, 4),
						BackgroundColor3 = OUTLINE,
						BorderSizePixel = 0,
						[Children] = {
							corner(scope, 3),
							scope:New("Frame")({
								Size = scope:Computed(function(use)
									return UDim2.fromScale(math.clamp(use(carried) / math.max(use(capacity), 1), 0, 1), 1)
								end),
								BackgroundColor3 = scope:Computed(function(use)
									return if use(full) then RED else GREEN
								end),
								BorderSizePixel = 0,
								[Children] = { corner(scope, 3) },
							}),
						},
					}),
				},
			}),
			scope:New("Frame")({
				Name = "Equipment",
				Position = leftPosition(356),
				Size = UDim2.fromOffset(236, 70),
				BackgroundColor3 = UI.PANEL_DARK,
				BackgroundTransparency = 0.08,
				[Children] = {
					scale(),
					UI.cardFill(scope),
					label(scope, {
						Position = UDim2.fromOffset(8, 10),
						Size = UDim2.fromOffset(44, 46),
						Text = "⚒",
						TextSize = 33,
						TextColor3 = Color3.fromRGB(205, 216, 228),
					}),
					UI.body(scope, {
						Position = UDim2.fromOffset(62, 10),
						Size = UDim2.new(1, -74, 0, 16),
						Text = scope:Computed(function(use)
							local s = use(playerState)
							return "EQUIPPED  ·  TIER " .. (if s then s.pickaxeTier else 1)
						end),
						TextSize = 11,
						TextColor3 = UI.SUBTEXT,
						TextXAlignment = Enum.TextXAlignment.Left,
					}),
					label(scope, {
						Position = UDim2.fromOffset(62, 27),
						Size = UDim2.new(1, -74, 0, 33),
						Text = scope:Computed(function(use)
							local s = use(playerState)
							return (Config.Pickaxes[if s then s.pickaxeTier else 1] or Config.Pickaxes[1]).Name
						end),
						TextSize = 18,
						TextWrapped = true,
						TextXAlignment = Enum.TextXAlignment.Left,
					}),
				},
			}),
			scope:New("Frame")({
				Name = "Production",
				Position = leftPosition(436),
				Size = UDim2.fromOffset(236, 142),
				BackgroundColor3 = UI.PANEL_DARK,
				BackgroundTransparency = 0.08,
				[Children] = {
					scale(),
					UI.cardFill(scope),
					label(scope, {
						Position = UDim2.fromOffset(14, 9),
						Size = UDim2.fromOffset(118, 23),
						Text = "PRODUCTION",
						TextSize = 17,
						TextXAlignment = Enum.TextXAlignment.Left,
					}),
					UI.body(scope, {
						AnchorPoint = Vector2.new(1, 0),
						Position = UDim2.new(1, -14, 0, 12),
						Size = UDim2.fromOffset(78, 18),
						Text = scope:Computed(function(use)
							local s = use(playerState)
							return if s then string.format("%g bars/s", s.line.rate) else "0 bars/s"
						end),
						TextSize = 13,
						TextColor3 = GREEN,
						TextXAlignment = Enum.TextXAlignment.Right,
					}),
					bar(scope, {
						Position = UDim2.fromOffset(14, 39),
						Size = UDim2.new(1, -28, 0, 34),
						Fill = scope:Computed(function(use)
							local s = use(playerState)
							return if s then s.line.hopper.amount / math.max(s.line.hopper.capacity, 1) else 0
						end),
						Color = ORANGE,
						Text = scope:Computed(function(use)
							local s = use(playerState)
							return if s then "Hopper  " .. Format.number(s.line.hopper.amount) .. " / " .. Format.number(s.line.hopper.capacity) else "Hopper  0 / 0"
						end),
					}),
					bar(scope, {
						Position = UDim2.fromOffset(14, 83),
						Size = UDim2.new(1, -28, 0, 34),
						Fill = scope:Computed(function(use)
							local s = use(playerState)
							return if s then s.line.collector.amount / math.max(s.line.collector.capacity, 1) else 0
						end),
						Color = BAR,
						Text = scope:Computed(function(use)
							local s = use(playerState)
							return if s then "Storage  " .. Format.number(s.line.collector.amount) .. " / " .. Format.number(s.line.collector.capacity) else "Storage  0 / 0"
						end),
					}),
					UI.body(scope, {
						Position = UDim2.fromOffset(14, 121),
						Size = UDim2.new(1, -28, 0, 14),
						Text = scope:Computed(function(use)
							local s = use(playerState)
							if not s or not s.plotId then return "Claim a plot to start refining" end
							if s.line.collector.amount >= s.line.collector.capacity then return "Storage full · collect your bars!" end
							if s.line.hopper.amount <= 0 then return "Add ore to keep your line running" end
							return "Plot " .. s.plotId .. " · refining ore into bars"
						end),
						TextSize = 11,
						TextColor3 = UI.SUBTEXT,
						TextXAlignment = Enum.TextXAlignment.Left,
					}),
				},
			}),
			-- While you were away (spec §6.4)
			scope:New("Frame")({
				Name = "WhileAway",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(390, 260),
				BackgroundColor3 = UI.PANEL_DARK,
				Visible = scope:Computed(function(use)
					return use(whileAway) ~= nil
				end),
				[Children] = {
					scale(),
					UI.cardFill(scope),
					label(scope, {
						Position = UDim2.fromOffset(0, 12),
						Size = UDim2.new(1, 0, 0, 34),
						Text = "While you were away",
						TextSize = 28,
						TextColor3 = CASH,
					}),
					UI.body(scope, {
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
						BackgroundColor3 = CASH,
						Font = FONT,
						Text = "Nice!",
						TextSize = 20,
						TextColor3 = OUTLINE,
						[OnEvent("Activated")] = function()
							whileAway:set(nil)
						end,
						[Children] = { corner(scope, 10), stroke(scope) },
					}),
				},
			}),

			-- One objective card keeps the action, core progress and standings together.
			scope:New("Frame")({
				Name = "EventPanel",
				AnchorPoint = Vector2.new(1, 0),
				Position = scope:Computed(function(use)
					local rect = HudLayout.toGui(use(hud).eventPanel, use(hud).inset)
					return UDim2.new(1, -Config.Hud.EdgeMargin, 0, rect.y)
				end),
				Size = UDim2.fromOffset(278, 204),
				BackgroundColor3 = UI.PANEL_DARK,
				BackgroundTransparency = 0.06,
				Visible = inEvent,
				[Children] = {
					scale(),
					UI.cardFill(scope),
					UI.body(scope, {
						Position = UDim2.fromOffset(14, 11),
						Size = UDim2.new(1, -28, 0, 15),
						Text = "METEOR OBJECTIVE",
						TextSize = 12,
						TextColor3 = ORANGE,
						TextXAlignment = Enum.TextXAlignment.Left,
					}),
					label(scope, {
						Position = UDim2.fromOffset(14, 29),
						Size = UDim2.new(1, -28, 0, 43),
						Text = scope:Computed(function(use)
							local meteor = use(meteorState)
							local rank = use(standing)
							if meteor and meteor.unlocked then return "Strike the exposed core!" end
							if not rank or rank.rank == 0 then return "Mine a node to join in!" end
							return "Break crust to reach the core!"
						end),
						TextSize = 21,
						TextWrapped = true,
						TextXAlignment = Enum.TextXAlignment.Left,
						TextYAlignment = Enum.TextYAlignment.Center,
					}),
					UI.body(scope, {
						Position = UDim2.fromOffset(14, 78),
						Size = UDim2.new(1, -28, 0, 16),
						Text = scope:Computed(function(use)
							local s = use(meteorState)
							return if s and s.unlocked then "CORE EXPOSED · earn Core Shards" else "CORE LOCKED · break the outer nodes"
						end),
						TextSize = 12,
						TextColor3 = UI.SUBTEXT,
						TextXAlignment = Enum.TextXAlignment.Left,
					}),
					bar(scope, {
						Position = UDim2.fromOffset(14, 99),
						Size = UDim2.new(1, -28, 0, 30),
						Fill = scope:Computed(function(use)
							local s = use(meteorState)
							if s and not s.unlocked then
								return s.crustBroken / math.max(math.ceil(s.crustTotal * 0.6), 1)
							end
							return use(coreHp) / math.max(use(coreMaxHp), 1e-6)
						end),
						Color = ORANGE,
						Text = scope:Computed(function(use)
							local s = use(meteorState)
							if s and not s.unlocked then
								return string.format("Nodes broken  %d / %d", s.crustBroken, math.ceil(s.crustTotal * 0.6))
							end
							local fraction = use(coreHp) / math.max(use(coreMaxHp), 1e-6)
							return string.format("Core strength  %d%%", math.ceil(math.clamp(fraction, 0, 1) * 100))
						end),
					}),
					UI.body(scope, {
						Position = UDim2.fromOffset(14, 135),
						Size = UDim2.new(1, -28, 0, 18),
						Text = scope:Computed(function(use)
							local s = use(standing)
							if not s or s.rank == 0 then return "Your first hit starts your contribution" end
							return string.format("You: #%d of %d  ·  %s ore", s.rank, s.players, Format.number(s.ore))
						end),
						TextSize = 13,
						TextColor3 = GREEN,
						TextXAlignment = Enum.TextXAlignment.Left,
					}),
					UI.body(scope, {
						Position = UDim2.fromOffset(14, 159),
						Size = UDim2.new(1, -28, 0, 39),
						Text = scope:Computed(function(use)
							local s = use(standing)
							if not s or #s.top == 0 then return "Mine together. Everyone contributes!" end
							local lines = {}
							for i, entry in s.top do
								table.insert(lines, string.format("#%d  %s   %s", i, entry.name, Format.number(entry.contribution)))
							end
							return table.concat(lines, "\n")
						end),
						TextSize = 12,
						TextColor3 = UI.SUBTEXT,
						TextXAlignment = Enum.TextXAlignment.Left,
						TextYAlignment = Enum.TextYAlignment.Top,
						TextTruncate = Enum.TextTruncate.AtEnd,
					}),
				},
			}),
			-- Announcement banner
			label(scope, {
				Name = "Banner",
				AnchorPoint = Vector2.new(0.5, 0),
				Position = scope:Computed(function(use)
					local l = use(hud)
					-- Under the touch button row, which reaches into the usual spot
					return UDim2.new(0.5, 0, 0, if l.touch then l.eventPanel.y - l.inset else 92 * l.scale)
				end),
				Size = UDim2.fromOffset(480, 38),
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
				[Children] = { scale() },
			}),

			-- Results panel
			scope:New("Frame")({
				Name = "Results",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.55),
				Size = UDim2.fromOffset(370, 270),
				BackgroundColor3 = UI.PANEL_DARK,
				Visible = scope:Computed(function(use)
					return use(results) ~= nil
				end),
				[Children] = {
					scale(),
					UI.cardFill(scope),
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
					UI.body(scope, {
						Position = UDim2.fromOffset(16, 52),
						Size = UDim2.new(1, -32, 1, -100),
						Text = scope:Computed(function(use)
							local r = use(results)
							if not r then
								return ""
							end
							local oreName = r.oreType and Config.Home.OreNames[r.oreType]
							local lines = { (if oreName then oreName .. " ore" else "Ore") .. " mined: " .. Format.number(r.ore) }
							-- Under-tier players see what a better pickaxe mines here (spec §8.1)
							if r.missed then
								table.insert(lines, MeteorTypes.missedHint(r.missed))
							end
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
						BackgroundColor3 = CASH,
						Font = FONT,
						Text = "Nice!",
						TextSize = 20,
						TextColor3 = OUTLINE,
						[OnEvent("Activated")] = function()
							results:set(nil)
						end,
						[Children] = { corner(scope, 10), stroke(scope) },
					}),
				},
			}),

			-- Toast
			UI.body(scope, {
				Name = "Toast",
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.5, 0, 1, -86),
				Size = UDim2.new(0.66, 0, 0, 52),
				BackgroundColor3 = UI.PANEL_DARK,
				BackgroundTransparency = 0.05,
				TextWrapped = true,
				Text = scope:Computed(function(use)
					return use(toast) or ""
				end),
				TextSize = 17,
				Visible = scope:Computed(function(use)
					return use(toast) ~= nil
				end),
				[Children] = {
					UI.cardFill(scope),
					scope:New("UIPadding")({ PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14) }),
				},
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
							BackgroundColor3 = Color3.fromRGB(164, 118, 82),
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
							[Children] = { corner(scope, 8), stroke(scope) },
						}),
						scope:New("TextButton")({
							Name = "DevAway",
							Size = UDim2.new(1, 0, 0, 30),
							BackgroundColor3 = Color3.fromRGB(164, 118, 82),
							Font = FONT,
							Text = "[Studio] Away 1 hour",
							TextSize = 16,
							TextColor3 = WHITE,
							[OnEvent("Activated")] = function()
								RefineryService:DevSimulateAway(3600)
							end,
							[Children] = { corner(scope, 8), stroke(scope) },
						}),
					},
				})
				else nil,

		},
	})

	self.Gui = ui

	-- "+$4.8M" rises off the cash counter on every sale
	EconomyService.Sold:Connect(function(bars: number, cash: number)
		showToast("Sold " .. Format.number(bars) .. " bars")
		local currentScale = Fusion.peek(hudScale)
		local floater = Instance.new("TextLabel")
		floater.BackgroundTransparency = 1
		floater.Position = UDim2.fromOffset(14 + 63 * currentScale, 104 * currentScale)
		floater.Size = UDim2.fromOffset(200, 36)
		floater.Font = FONT
		floater.Text = "+" .. Format.cash(cash)
		floater.TextSize = 30 * currentScale
		floater.TextColor3 = CASH
		floater.TextStrokeColor3 = OUTLINE
		floater.TextStrokeTransparency = 0
		floater.TextXAlignment = Enum.TextXAlignment.Left
		floater.Parent = ui
		local info = TweenInfo.new(1.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		TweenService:Create(floater, info, {
			Position = UDim2.fromOffset(14 + 63 * currentScale, 62 * currentScale),
			TextTransparency = 1,
			TextStrokeTransparency = 1,
		}):Play()
		task.delay(1.5, function()
			floater:Destroy()
		end)
	end)
end

return HUDController
