--!strict
-- Horizontal equipment showcase; prices and purchases remain server-authoritative.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Knit = require(ReplicatedStorage.Packages.Knit)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local HudLayout = require(ReplicatedStorage.Shared.HudLayout)
local Price = require(ReplicatedStorage.Shared.Price)
local UI = require(script.Parent.Parent.UI)
local EquipmentPreview = require(script.Parent.Parent.EquipmentPreview)
local Children, OnEvent, OnChange = Fusion.Children, Fusion.OnEvent, Fusion.OnChange
local player = Players.LocalPlayer
local ShopController = Knit.CreateController({ Name = "ShopController" })
type Scope = UI.Scope
type RowState = "owned" | "equipped" | "next" | "locked" | "max"
local TABS = {
	{ Id = "pickaxe", Name = "PICKAXES" },
	{ Id = "backpack", Name = "BACKPACKS" },
	{ Id = "plot", Name = "PRODUCTION" },
}
local STATION_UNITS = { hopper = "ore", conveyor = "ore/s", refinery = "bars/s", collector = "bars" }
local CARD_WIDTH, CARD_GAP = 244, 14
local wantOpen, wantHighlight = false, false
local isOpen: Fusion.Value<boolean>? = nil
local highlight: Fusion.Value<boolean>? = nil

function ShopController:Open()
	wantOpen = true
	if isOpen then isOpen:set(true) end
end
function ShopController:SetHighlight(on: boolean)
	wantHighlight = on
	if highlight then highlight:set(on) end
end
local function tierState(owned: number, tier: number): RowState
	if tier == owned then return "equipped" end
	if tier < owned then return "owned" end
	if tier == owned + 1 then return "next" end
	return "locked"
end

type PurchaseProps = {
	State: Fusion.UsedAs<RowState>, Cost: Fusion.UsedAs<number>, Shards: Fusion.UsedAs<number>,
	Wallet: Fusion.UsedAs<Price.Wallet>, Busy: Fusion.UsedAs<boolean>, OnBuy: () -> (),
}
local function purchaseButton(scope: Scope, props: PurchaseProps)
	local enabled = scope:Computed(function(use)
		return use(props.State) == "next" and Price.canAfford(use(props.Wallet), use(props.Cost), use(props.Shards)) and not use(props.Busy)
	end)
	return UI.button(scope, {
		Name = "Purchase", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -14),
		Size = UDim2.new(1, -28, 0, 46), TextSize = 18, AutoButtonColor = enabled, Selectable = enabled,
		Text = scope:Computed(function(use)
			local state = use(props.State)
			if state == "equipped" then return "EQUIPPED" end
			if state == "owned" then return "OWNED" end
			if state == "max" then return "MAX LEVEL" end
			if state == "next" and use(props.Busy) then return "UPGRADING..." end
			return Price.text(use(props.Cost), use(props.Shards))
		end),
		TextColor3 = scope:Computed(function(use)
			local state = use(props.State)
			return if state == "equipped" or state == "max" or use(enabled) then UI.OUTLINE else UI.WHITE
		end),
		BackgroundColor3 = scope:Computed(function(use)
			local state = use(props.State)
			if state == "equipped" or state == "max" then return UI.GREEN end
			if use(enabled) then return UI.CASH end
			return UI.DISABLED
		end),
		[OnEvent("Activated")] = function() if Fusion.peek(enabled) then props.OnBuy() end end,
	})
end
local function stat(scope: Scope, index: number, title: string, value: string)
	return scope:New("Frame")({
		Name = title, Position = UDim2.new((index - 1) / 3, 0, 0, 0), Size = UDim2.new(1 / 3, 0, 1, 0), BackgroundTransparency = 1,
		[Children] = {
			UI.body(scope, { Size = UDim2.new(1, 0, 0, 17), Text = title, TextSize = 11, TextColor3 = UI.SUBTEXT }),
			UI.label(scope, { Position = UDim2.fromOffset(0, 21), Size = UDim2.new(1, 0, 0, 24), Text = value, TextSize = 21, TextStrokeTransparency = 0.6 }),
		},
	})
end
local function equipmentCard(scope: Scope, kind: string, tier: number, item: any, owned: any, wallet: any, busy: any, onBuy: () -> ())
	local state = scope:Computed(function(use) return tierState(use(owned), tier) end)
	local tint = if kind == "pickaxe" then item.Color:Lerp(UI.WHITE, 0.25) else UI.SHARD:Lerp(UI.WHITE, (tier - 1) * 0.05)
	local stats = if kind == "pickaxe" then {
		stat(scope, 1, "Ore/hit", Format.number(item.OrePerHit)),
		stat(scope, 2, "Swing time", string.format("%.2fs", item.Swing)),
		stat(scope, 3, "Damage", Format.number(item.Damage)),
	} else {
		UI.body(scope, { Size = UDim2.new(1, 0, 0, 18), Text = "ORE CAPACITY", TextSize = 12, TextColor3 = UI.SUBTEXT }),
		UI.label(scope, { Position = UDim2.fromOffset(0, 21), Size = UDim2.new(1, 0, 0, 26), Text = Format.number(item.Capacity) .. " ore", TextSize = 24, TextColor3 = UI.SHARD }),
	}
	return scope:New("Frame")({
		Name = kind .. "Tier" .. tier, LayoutOrder = tier, Size = UDim2.new(0, CARD_WIDTH, 1, -12), BackgroundColor3 = UI.CARD,
		[Children] = {
			UI.corner(scope, 14),
			scope:New("UIStroke")({ Thickness = 2, Color = scope:Computed(function(use)
				local s = use(state)
				return if s == "equipped" then UI.GREEN elseif s == "next" then UI.CASH else UI.OUTLINE
			end) }),
			scope:New("Frame")({
				Position = UDim2.fromOffset(10, 10), Size = UDim2.new(1, -20, 0, 151), BackgroundColor3 = UI.PANEL_DARK,
				[Children] = {
					UI.corner(scope, 10),
					EquipmentPreview(scope, kind, tier, { Position = UDim2.fromOffset(0, 6), Size = UDim2.new(1, 0, 1, -6) }),
					UI.body(scope, { Position = UDim2.fromOffset(10, 8), Size = UDim2.fromOffset(66, 18), Text = "TIER " .. tier, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = tint }),
				},
			}),
			UI.label(scope, { Position = UDim2.fromOffset(10, 173), Size = UDim2.new(1, -20, 0, 29), Text = item.Name, TextSize = 22, TextColor3 = tint, TextStrokeTransparency = 0.35 }),
			scope:New("Frame")({ Position = UDim2.fromOffset(12, 216), Size = UDim2.new(1, -24, 0, 49), BackgroundTransparency = 1, [Children] = stats }),
			UI.body(scope, {
				AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -68), Size = UDim2.new(1, -20, 0, 19), TextSize = 12, TextColor3 = UI.SUBTEXT,
				Text = scope:Computed(function(use)
					local s = use(state)
					if s == "locked" then return "Unlock Tier " .. (tier - 1) .. " first" end
					if s == "equipped" then return "Your current gear" end
					if s == "owned" then return "Already in your collection" end
					return if Price.canAfford(use(wallet), item.Cost, item.Shards) then "Ready for an upgrade!" else "Save up for this upgrade"
				end),
			}),
			purchaseButton(scope, { State = state, Cost = item.Cost, Shards = item.Shards, Wallet = wallet, Busy = busy, OnBuy = onBuy }),
		},
	})
end

function ShopController:KnitStart()
	local ShopService = Knit.GetService("ShopService")
	local UpgradeService = Knit.GetService("UpgradeService")
	local PlayerStateService = Knit.GetService("PlayerStateService")
	local scope = Fusion.scoped(Fusion)
	local open, tab, glow = scope:Value(wantOpen), scope:Value("pickaxe"), scope:Value(wantHighlight)
	local busy, notice = scope:Value(false), scope:Value("")
	isOpen, highlight = open, glow
	local hud = UI.hud(scope)
	local panelFit = scope:Computed(function(use) local l = use(hud) return HudLayout.panel(l.viewport, 940, 600, l.inset) end)
	local scale = scope:Computed(function(use) return use(panelFit).scale end)
	local width = scope:Computed(function(use) return use(panelFit).width end)
	local compact = scope:Computed(function(use) return use(width) < 650 end)
	local playerState = scope:Value(nil :: any)
	PlayerStateService.State:Observe(function(value) playerState:set(value) end)
	ShopService.Open:Connect(function() open:set(true) end)
	ShopService.Notice:Connect(function(message) notice:set(message) end)
	local wallet = scope:Computed(function(use): Price.Wallet
		local s = use(playerState)
		return { cash = if s then s.cash else 0, shards = if s then s.shards else 0 }
	end)
	local function owned(key: string)
		return scope:Computed(function(use) local s = use(playerState) return if s then s[key] else 1 end)
	end
	local pickaxeTier, backpackTier = owned("pickaxeTier"), owned("backpackTier")
	local function purchase(callback: () -> any)
		if Fusion.peek(busy) then return end
		busy:set(true)
		notice:set("")
		task.spawn(function()
			local ok, result = pcall(callback)
			busy:set(false)
			if not ok then notice:set("Couldn't complete the upgrade. Please try again.")
			elseif result then notice:set("Upgraded! Your new gear is ready.") end
		end)
	end
	local lists: { [string]: ScrollingFrame } = {}
	local positions: { [string]: any } = {}
	local scrollTweens: { [string]: Tween } = {}
	local function scrollTo(kind: string, x: number, animate: boolean)
		local list = lists[kind]
		if not list then return end
		if scrollTweens[kind] then scrollTweens[kind]:Cancel() end
		local limit = math.max(0, list.AbsoluteCanvasSize.X - list.AbsoluteWindowSize.X)
		local target = Vector2.new(math.clamp(x, 0, limit), 0)
		if animate then
			local tween = TweenService:Create(list, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CanvasPosition = target })
			scrollTweens[kind] = tween
			tween:Play()
		else list.CanvasPosition = target end
	end
	local function makeList(kind: string, cards: { any }): ScrollingFrame
		local position = scope:Value(0)
		positions[kind] = position
		local list = scope:New("ScrollingFrame")({
			Name = kind .. "Carousel", Position = UDim2.fromOffset(20, 176), Size = UDim2.new(1, -40, 1, -234),
			BackgroundTransparency = 1, BorderSizePixel = 0, CanvasSize = UDim2.fromOffset(#cards * (CARD_WIDTH + CARD_GAP) - CARD_GAP + 8, 0),
			ScrollingDirection = Enum.ScrollingDirection.X, ScrollBarThickness = 5, ScrollBarImageColor3 = UI.CASH,
			ElasticBehavior = Enum.ElasticBehavior.WhenScrollable, Visible = scope:Computed(function(use) return use(tab) == kind end),
			[OnChange("CanvasPosition")] = function(value: Vector2) position:set(value.X) end,
			[Children] = {
				scope:New("UIPadding")({ PaddingLeft = UDim.new(0, 4), PaddingTop = UDim.new(0, 3), PaddingRight = UDim.new(0, 4) }),
				scope:New("UIListLayout")({ FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, CARD_GAP), SortOrder = Enum.SortOrder.LayoutOrder }), cards,
			},
		})
		lists[kind] = list
		return list
	end
	local pickaxeCards, backpackCards = {}, {}
	for tier, item in Config.Pickaxes do
		pickaxeCards[tier] = equipmentCard(scope, "pickaxe", tier, item, pickaxeTier, wallet, busy, function() purchase(function() return ShopService:Buy("pickaxe") end) end)
	end
	for tier, item in Config.Backpacks do
		backpackCards[tier] = equipmentCard(scope, "backpack", tier, item, backpackTier, wallet, busy, function() purchase(function() return ShopService:Buy("backpack") end) end)
	end
	local stationCards = {}
	for order, stationId in Config.Home.StationOrder do
		local station = Config.Home.Stations[stationId]
		local level = scope:Computed(function(use) local s = use(playerState) return if s then s.line[stationId].level else 1 end)
		local nextLevel = scope:Computed(function(use) return station.Levels[use(level) + 1] end)
		local function statText(entry: Config.Level): string
			local value = entry.Capacity or entry.Rate or 0
			return (if entry.Rate then string.format("%g", value) else Format.number(value)) .. " " .. STATION_UNITS[stationId]
		end
		stationCards[order] = scope:New("Frame")({
			Name = stationId, LayoutOrder = order, Size = UDim2.new(0, CARD_WIDTH, 1, -12), BackgroundColor3 = UI.CARD,
			[Children] = {
				UI.corner(scope, 14), UI.stroke(scope),
				UI.icon(scope, if stationId == "collector" or stationId == "refinery" then "bar" else "ore", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 20), Size = UDim2.fromOffset(78, 78) }),
				UI.label(scope, { Position = UDim2.fromOffset(10, 116), Size = UDim2.new(1, -20, 0, 30), Text = station.Name, TextSize = 23 }),
				UI.body(scope, { Position = UDim2.fromOffset(10, 153), Size = UDim2.new(1, -20, 0, 20), TextSize = 14, TextColor3 = UI.CASH, Text = scope:Computed(function(use) return string.format("LEVEL %d / %d", use(level), #station.Levels) end) }),
				UI.body(scope, { Position = UDim2.fromOffset(10, 194), Size = UDim2.new(1, -20, 0, 20), TextSize = 13, TextColor3 = UI.SUBTEXT, Text = "CURRENT  →  NEXT" }),
				UI.label(scope, { Position = UDim2.fromOffset(10, 223), Size = UDim2.new(1, -20, 0, 42), TextSize = 20, TextWrapped = true, TextStrokeTransparency = 0.7,
					Text = scope:Computed(function(use) local upcoming = use(nextLevel) return statText(station.Levels[use(level)]) .. (if upcoming then "  →  " .. statText(upcoming) else "  ·  MAX") end),
				}),
				purchaseButton(scope, {
					State = scope:Computed(function(use): RowState return if use(nextLevel) then "next" else "max" end),
					Cost = scope:Computed(function(use) local n = use(nextLevel) return if n then n.Cost else 0 end),
					Shards = scope:Computed(function(use) local n = use(nextLevel) return if n then n.Shards else 0 end),
					Wallet = wallet, Busy = busy, OnBuy = function() purchase(function() return UpgradeService:BuyStation(stationId) end) end,
				}),
			},
		})
	end
	local carousels = { makeList("pickaxe", pickaxeCards), makeList("backpack", backpackCards), makeList("plot", stationCards) }
	local function move(direction: number)
		local kind = Fusion.peek(tab)
		local list = lists[kind]
		if list then scrollTo(kind, list.CanvasPosition.X + direction * (CARD_WIDTH + CARD_GAP) * Fusion.peek(scale), true) end
	end
	local function focusOwned()
		local kind = Fusion.peek(tab)
		local tier = if kind == "pickaxe" then Fusion.peek(pickaxeTier) elseif kind == "backpack" then Fusion.peek(backpackTier) else 1
		task.defer(function() scrollTo(kind, (tier - 1) * (CARD_WIDTH + CARD_GAP) * Fusion.peek(scale), false) end)
	end
	scope:Observer(open):onChange(function()
		player:SetAttribute("ShopOpen", Fusion.peek(open))
		if Fusion.peek(open) then focusOwned() end
	end)
	scope:Observer(tab):onChange(function() notice:set("") focusOwned() end)
	scope:Observer(pickaxeTier):onChange(function() if Fusion.peek(tab) == "pickaxe" then focusOwned() end end)
	scope:Observer(backpackTier):onChange(function() if Fusion.peek(tab) == "backpack" then focusOwned() end end)
	table.insert(scope, UserInputService.InputBegan:Connect(function(input, processed)
		if not Fusion.peek(open) or UserInputService:GetFocusedTextBox() then return end
		if input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB then open:set(false)
		elseif not processed and input.KeyCode == Enum.KeyCode.Left then move(-1)
		elseif not processed and input.KeyCode == Enum.KeyCode.Right then move(1) end
	end))
	local tabButtons = {}
	for index, info in TABS do
		tabButtons[index] = UI.button(scope, {
			Name = info.Id .. "Tab", LayoutOrder = index, Size = UDim2.new(1 / 3, -6, 1, 0), Text = info.Name, TextSize = 16,
			BackgroundColor3 = scope:Computed(function(use) return if use(tab) == info.Id then UI.CASH else UI.CARD end),
			TextColor3 = scope:Computed(function(use) return if use(tab) == info.Id then UI.OUTLINE else UI.SUBTEXT end),
			[OnEvent("Activated")] = function() tab:set(info.Id) end,
		})
	end
	local function balance(kind: string, offset: number, badgeWidth: number)
		return scope:New("Frame")({
			Name = kind .. "Balance", Position = scope:Computed(function(use)
				return if use(compact) then UDim2.fromOffset(20 + offset, 60) else UDim2.new(1, -354 + offset, 0, 22)
			end), Size = UDim2.fromOffset(badgeWidth, 36), BackgroundColor3 = UI.PANEL_DARK,
			[Children] = {
				UI.corner(scope, 10), UI.icon(scope, kind, { Position = UDim2.fromOffset(4, 4), Size = UDim2.fromOffset(28, 28) }),
				UI.label(scope, { Position = UDim2.fromOffset(38, 0), Size = UDim2.new(1, -44, 1, 0), TextXAlignment = Enum.TextXAlignment.Left, TextSize = 19, TextColor3 = if kind == "cash" then UI.CASH else UI.SHARD,
					Text = scope:Computed(function(use) local w = use(wallet) return if kind == "cash" then Format.cash(w.cash) else Format.number(w.shards) end),
				}),
			},
		})
	end
	scope:New("ScreenGui")({
		Name = "Shop", ResetOnSpawn = false, IgnoreGuiInset = true, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 20, Parent = player:WaitForChild("PlayerGui"),
		[Children] = {
			UI.hudButton(scope, hud, "SHOP", 28, {
				Name = "ShopButton", Text = "SHOP",
				BackgroundColor3 = scope:Spring(scope:Computed(function(use) return if use(glow) then UI.GREEN else UI.CASH end), 12, 1),
				Visible = scope:Computed(function(use) return not use(open) end),
				[OnEvent("Activated")] = function() open:set(true) end,
			}),
			scope:New("TextButton")({
				Name = "Dimmer", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(9, 10, 16), BackgroundTransparency = 0.28,
				Text = "", AutoButtonColor = false, BorderSizePixel = 0, Visible = open, ZIndex = 2, Modal = true,
				[OnEvent("Activated")] = function() open:set(false) end,
			}),
			scope:New("Frame")({
				Name = "Panel", AnchorPoint = Vector2.new(0.5, 0.5), Position = scope:Computed(function(use) return UDim2.new(0.5, 0, 0.5, use(hud).inset / 2) end),
				Size = scope:Computed(function(use) return UDim2.fromOffset(use(width), 600) end), BackgroundColor3 = UI.PANEL, Visible = open, ZIndex = 3, Active = true,
				[Children] = {
					UI.panelFill(scope), scope:New("UIScale")({ Scale = scale }),
					scope:New("Frame")({ Name = "Interior", Position = UDim2.fromOffset(9, 104), Size = UDim2.new(1, -18, 1, -113), BackgroundColor3 = UI.PANEL_DARK, [Children] = { UI.corner(scope, 12) } }),
					UI.label(scope, { Position = UDim2.fromOffset(22, 12), Size = UDim2.fromOffset(246, 37), Text = "GEAR SHOP", TextSize = 32, TextColor3 = UI.CASH, TextXAlignment = Enum.TextXAlignment.Left }),
					UI.body(scope, { Position = UDim2.fromOffset(24, 53), Size = UDim2.fromOffset(240, 24), Text = "Mine bigger. Build faster.", TextSize = 15, TextXAlignment = Enum.TextXAlignment.Left, Visible = scope:Computed(function(use) return not use(compact) end) }),
					balance("cash", 0, 146), balance("shard", 156, 126),
					UI.button(scope, { Name = "Close", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -18, 0, 18), Size = scope:Computed(function(use) local s = HudLayout.closeSize(42, use(scale)) return UDim2.fromOffset(s, s) end), Text = "X", TextSize = 23, BackgroundColor3 = UI.RED, TextColor3 = UI.WHITE, [OnEvent("Activated")] = function() open:set(false) end }),
					scope:New("Frame")({ Position = UDim2.fromOffset(20, 112), Size = UDim2.new(1, -40, 0, 40), BackgroundTransparency = 1,
						[Children] = { scope:New("UIListLayout")({ FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 9), SortOrder = Enum.SortOrder.LayoutOrder }), tabButtons },
					}),
					carousels,
					UI.button(scope, { Name = "Previous", Position = UDim2.new(0, 22, 1, -48), Size = UDim2.fromOffset(40, 32), Text = "‹", TextSize = 27, [OnEvent("Activated")] = function() move(-1) end }),
					UI.button(scope, { Name = "Next", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -22, 1, -48), Size = UDim2.fromOffset(40, 32), Text = "›", TextSize = 27, [OnEvent("Activated")] = function() move(1) end }),
					UI.body(scope, { Position = UDim2.new(0, 70, 1, -48), Size = UDim2.new(1, -140, 0, 33), TextSize = 13, TextWrapped = true, TextColor3 = UI.SUBTEXT,
						Text = scope:Computed(function(use)
							local message = use(notice)
							if message ~= "" then return message end
							local kind = use(tab)
							local count = if kind == "plot" then #stationCards elseif kind == "pickaxe" then #pickaxeCards else #backpackCards
							local first = math.clamp(math.floor(use(positions[kind]) / ((CARD_WIDTH + CARD_GAP) * use(scale)) + 0.5) + 1, 1, count)
							return string.format("%d / %d  ·  Swipe or use arrows", first, count)
						end),
					}),
				},
			}),
		},
	})
	player:SetAttribute("ShopOpen", Fusion.peek(open))
end
return ShopController
