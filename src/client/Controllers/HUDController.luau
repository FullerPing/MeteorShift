--!strict
-- HUD built with Fusion (spec §10):
--   * countdown / cooling timer and the sky countdown over the crater, titled with
--     the meteor type in its glow colour (spec §8.1)
--   * cash (counts up on every sale, "+$" floater, rebirth multiplier once above
--     ×1, spec §8.3), shards, pickaxe, backpack
--     meter (red when full), bars, hopper and production line
--   * "While you were away" panel (spec §6.4)
--   * event panel: core HP bar, core lock and your contribution rank
--   * announcement banner, personal meteor reward line, small toasts

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Config = require(ReplicatedStorage.Shared.Config)
local Pets = require(ReplicatedStorage.Shared.Pets)
local Format = require(ReplicatedStorage.Shared.Format)
local HudMessages = require(ReplicatedStorage.Shared.HudMessages)
local MeteorTypes = require(ReplicatedStorage.Shared.MeteorTypes)
local Phase = require(ReplicatedStorage.Shared.Phase)
local UI = require(script.Parent.Parent.UI)
local HudView = require(script.Parent.Parent.HudView)
local NativeHudMenus = require(script.Parent.Parent.NativeHudMenus)
local Sfx = require(script.Parent.Parent.Sfx)

local Children = Fusion.Children
local OnEvent = Fusion.OnEvent

local player = Players.LocalPlayer

local HUDController = Knit.CreateController({
	Name = "HUDController",
})

local FONT = UI.FONT
local WHITE = UI.WHITE
local ORANGE = UI.ORANGE
local RED = UI.RED
local CASH = UI.CASH
local OUTLINE = UI.OUTLINE


-- Shows a small toast; set once the HUD is built (see HUDController:Toast)
local showToastHandler: ((text: string, color: Color3?, highlighted: string?) -> ())? = nil

-- Other controllers post their small toasts here (e.g. "New mineral: X!").
function HUDController:Toast(text: string, color: Color3?, highlighted: string?)
	if showToastHandler then
		showToastHandler(text, color, highlighted)
	end
end

local corner = UI.corner
local stroke = UI.stroke
local label = UI.label

local function supporterConfetti()
	if player:GetAttribute("ReduceEffects") then return end
	local gui = Instance.new("ScreenGui")
	gui.Name = "SupporterConfetti"
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 50
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")
	for index = 1, 18 do
		local piece = Instance.new("Frame")
		piece.Size = UDim2.fromOffset(6, 10)
		piece.Position = UDim2.fromScale(.5, .4)
		piece.BackgroundColor3 = ({ UI.HUD_GOLD, UI.HUD_MINT, UI.SHARD })[(index - 1) % 3 + 1]
		piece.BorderSizePixel = 0
		piece.Rotation = index * 25
		piece.Parent = gui
		TweenService:Create(piece, TweenInfo.new(1.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = UDim2.fromScale(.08 + index / 21, .8 + (index % 3) * .04), Rotation = index * 65, BackgroundTransparency = 1,
		}):Play()
	end
	task.delay(1.4, function() gui:Destroy() end)
end

function HUDController:KnitStart()
	-- The retired authored counter contains a white test frame and a static $0.
	-- Keep existing places clean when Rojo leaves unknown StarterGui objects intact.
	local legacyCounter = player:WaitForChild("PlayerGui"):FindFirstChild("CashShardDisplay")
	if legacyCounter and legacyCounter:IsA("ScreenGui") then legacyCounter.Enabled = false end
	local MeteorService = Knit.GetService("MeteorService")
	local ContributionService = Knit.GetService("ContributionService")
	local PlayerStateService = Knit.GetService("PlayerStateService")
	local RewardService = Knit.GetService("RewardService")
	local RefineryService = Knit.GetService("RefineryService")
	local EconomyService = Knit.GetService("EconomyService")
	local UpgradeService = Knit.GetService("UpgradeService")
	local ShopService = Knit.GetService("ShopService")
	local PetService = Knit.GetService("PetService")
	local LevelService = Knit.GetService("LevelService")

	local scope = Fusion.scoped(Fusion)
	local hud = UI.hud(scope)
	local hudScale = scope:Computed(function(use)
		return use(hud).scale
	end)
	local function scale()
		return scope:New("UIScale")({ Scale = hudScale })
	end

	local meteorState = scope:Value(nil :: any)
	local playerState = scope:Value(nil :: any)
	local saleBusy = scope:Value(false)
	local function sellBars()
		if Fusion.peek(saleBusy) then return end
		saleBusy:set(true)
		task.spawn(function()
			local ok = pcall(function() EconomyService:SellAll() end)
			saleBusy:set(false)
			if not ok then HUDController:Toast("Could not sell bars. Please try again.") end
		end)
	end
	local standing = scope:Value(nil :: any)
	local serverNow = scope:Value(workspace:GetServerTimeNow())
	local coreHp = scope:Value(0)
	local coreMaxHp = scope:Value(1)
	local announcement = scope:Value(nil :: any)
	local meteorReward = scope:Value(nil :: any)
	local toast = scope:Value(nil :: string?)
	local whileAway = scope:Value(nil :: any)
	local notificationActive = scope:Computed(function(use) return use(toast) ~= nil or use(announcement) ~= nil or use(meteorReward) ~= nil end)
	scope:Observer(notificationActive):onChange(function() player:SetAttribute("HudNotificationActive", Fusion.peek(notificationActive)) end)
	player:SetAttribute("HudNotificationActive", false)
	local rewardActive = scope:Computed(function(use) return use(meteorReward) ~= nil end)
	scope:Observer(rewardActive):onChange(function() player:SetAttribute("HudRewardNotificationActive", Fusion.peek(rewardActive)) end)
	player:SetAttribute("HudRewardNotificationActive", false)

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

	local rewardToken = 0
	RewardService.Results:Connect(function(message)
		rewardToken += 1
		local token = rewardToken
		meteorReward:set(message)
		task.delay(6, function()
			if rewardToken == token then
				meteorReward:set(nil)
			end
		end)
	end)

	local toastToken = 0
	local function showRichToast(text: string)
		toastToken += 1
		local token = toastToken
		toast:set(text)
		task.delay(2.5, function()
			if toastToken == token then
				toast:set(nil)
			end
		end)
	end
	local function showToast(text: string, color: Color3?, highlighted: string?)
		showRichToast(HudMessages.toast(text, color, highlighted))
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
		showToast("Picked up " .. Format.number(bars) .. " bars. Tap your bars below to sell them!")
	end)
	RefineryService.WhileAway:Connect(function(report)
		if report.bars > 0 then
			whileAway:set(report)
		end
	end)
	-- Escape / gamepad B dismiss the welcome-back popup like every other panel
	table.insert(scope, game:GetService("UserInputService").InputBegan:Connect(function(input)
		if Fusion.peek(whileAway) ~= nil and (input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB) then
			whileAway:set(nil)
		end
	end))
	RefineryService.Notice:Connect(showToast)
	EconomyService.Notice:Connect(showToast)
	UpgradeService.Notice:Connect(showToast)
	UpgradeService.Upgraded:Connect(function(stationId: string, level: number)
		local names = { hopper = "Hopper", conveyor = "Conveyor", refinery = "Refinery", collector = "Collection Post" }
		Sfx.play("Purchase")
		showToast((names[stationId] or stationId) .. " upgraded to Lv " .. level .. "!")
	end)
	ShopService.Notice:Connect(showToast)
	ShopService.Purchased:Connect(function(kind: string, tier: number)
		local item = if kind == "pickaxe" then Config.Pickaxes[tier] else Config.Backpacks[tier]
		Sfx.play("Purchase")
		if item then
			showToast("Evolved to the " .. item.Name .. "!")
		end
	end)
	PetService.Notice:Connect(showToast)
	PetService.Bought:Connect(function(petId: string)
		local pet = Pets.def(petId)
		Sfx.play("Purchase")
		if pet then
			showToast("You got " .. pet.Name .. "!")
		end
	end)
	Knit.GetService("MonetizationService").Supporter:Connect(function()
		showToast("Thank you for supporting MeteorShift! Supporter tag active for this session.")
		supporterConfetti()
	end)
	PetService.Leveled:Connect(function(petId: string, level: number)
		local pet = Pets.def(petId)
		if pet then
			showToast(pet.Name .. " reached level " .. level .. "!")
		end
	end)
	LevelService.LevelUp:Connect(function(level: number)
		Sfx.play("Purchase")
		showToast("Player level " .. level .. "!")
	end)
	ShopService.Upgraded:Connect(function(kind: string, stat: string, level: number)
		local names = if kind == "pickaxe" then Config.Gear.Pickaxe.Names else Config.Gear.Backpack.Names
		Sfx.play("Purchase")
		showToast((names[stat] or stat) .. " upgraded to level " .. level .. "!")
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
	local timeProgress = scope:Computed(function(use)
		local s = use(meteorState)
		if not s then return 0 end
		local kind = Config.Meteor.Types[s.type]
		local duration = s.duration or (if s.phase == Phase.Active and kind then kind.ActiveDuration else Config.Meteor.Countdown)
		return math.clamp(use(secondsLeft) / math.max(duration, 1), 0, 1)
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
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
		[Children] = {
			HudView.main(scope, hud, {
				playerState = playerState, cashShown = cashShown, meteorState = meteorState,
				phase = phase, secondsLeft = secondsLeft, timerText = timerText, timerColor = timerColor, timeProgress = timeProgress,
				saleBusy = saleBusy, sellBars = sellBars,
				openRefinery = function() Knit.GetController("RefineryController"):Open() end,
			}),


			HudView.objective(scope, hud, {
				meteorState = meteorState, standing = standing, coreHp = coreHp,
				coreMaxHp = coreMaxHp, inEvent = inEvent,
			}),
			-- One reserved notification area: keep the personal reward directly below
			-- the announcement, with toasts retaining priority in the first row.
			UI.label(scope, {
				Name = "Toast",
				Position = scope:Computed(function(use) local r = use(hud).notification; return UDim2.fromOffset(r.x, r.y) end),
				Size = scope:Computed(function(use) local r = use(hud).notification; return UDim2.fromOffset(r.w, if use(rewardActive) then math.floor((r.h - 4) * 0.55) else r.h) end),
				BackgroundTransparency = 1,
				Font = FONT,
				RichText = true,
				TextScaled = true,
				TextStrokeColor3 = UI.OUTLINE,
				TextStrokeTransparency = 0,
				TextWrapped = true,
				Text = scope:Computed(function(use)
					local personal = use(meteorReward)
					local a = use(announcement)
					return use(toast) or (if personal then HudMessages.meteorOutcome(personal.cracked, personal.ore)
						elseif a then HudMessages.toast(a.text) else "")
				end),
				TextSize = 28,
				TextColor3 = scope:Computed(function(use) return if use(toast) ~= nil then WHITE else ORANGE end),
				Visible = scope:Computed(function(use) return use(toast) ~= nil or use(announcement) ~= nil or use(meteorReward) ~= nil end),
				[Children] = {
					scope:New("UITextSizeConstraint")({ MinTextSize = 12, MaxTextSize = scope:Computed(function(use) return if use(hud).notificationCompact then 18 elseif use(hud).touch then 24 else 28 end) }),
				},
			}),

			UI.label(scope, {
				Name = "MeteorReward",
				Position = scope:Computed(function(use)
					local r = use(hud).notification
					return UDim2.fromOffset(r.x, r.y + math.floor((r.h - 4) * 0.55) + 4)
				end),
				Size = scope:Computed(function(use)
					local r = use(hud).notification
					return UDim2.fromOffset(r.w, r.h - math.floor((r.h - 4) * 0.55) - 4)
				end),
				RichText = true, TextScaled = true, TextWrapped = false,
				TextStrokeColor3 = UI.OUTLINE, TextStrokeTransparency = 0,
				Text = scope:Computed(function(use)
					local r = use(meteorReward)
					return if r then HudMessages.meteorReward(r.shards, r.top, Config.Meteor.TopBonus, r.xp or 0) else ""
				end),
				TextSize = 24, TextColor3 = WHITE, Visible = rewardActive,
				[Children] = { scope:New("UITextSizeConstraint")({
					MinTextSize = 10,
					MaxTextSize = scope:Computed(function(use) return if use(hud).notificationCompact then 16 elseif use(hud).touch then 20 else 24 end),
				}) },
			}),

			-- Studio-only playtest helpers
			if RunService:IsStudio()
				then scope:New("Frame")({
					Name = "Dev",
					AnchorPoint = Vector2.new(1, 1),
					Position = UDim2.new(1, -12, 1, -12),
					Size = UDim2.fromOffset(170, 66),
					BackgroundTransparency = 1,
					Visible = workspace:GetAttribute("DevHudHelpersVisible") == true,
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
	NativeHudMenus.start()
	local showWelcomeBack = require(script.Parent.Parent.NativeWelcomeBack).start(function() whileAway:set(nil) end)
	scope:Observer(whileAway):onBind(function() showWelcomeBack(Fusion.peek(whileAway)) end)

	-- "+$4.8M" rises off the cash counter on every sale
	EconomyService.Sold:Connect(function(bars: number, cash: number)
		Sfx.play("Sell")
		showRichToast(HudMessages.sale(bars, cash))
		local layout = Fusion.peek(hud)
		local card = layout.leftCards.Resources
		local currentScale = card.w / 250
		local cardY = card.y
		local floater = Instance.new("TextLabel")
		floater.BackgroundTransparency = 1
		floater.Position = UDim2.fromOffset(card.x + 57 * currentScale, cardY + 53 * currentScale)
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
			Position = UDim2.fromOffset(card.x + 63 * currentScale, cardY - 18 * currentScale),
			TextTransparency = 1,
			TextStrokeTransparency = 1,
		}):Play()
		task.delay(1.5, function()
			floater:Destroy()
		end)
	end)
end

return HUDController
