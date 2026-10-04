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
local CYAN = Color3.fromRGB(123, 230, 239)
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
local function stateAccent(state: RowState): Color3
	return if state == "equipped" or state == "max" then UI.HUD_MINT elseif state == "next" then UI.HUD_GOLD else UI.HUD_BORDER
end
local function cardFill(scope: Scope, state: Fusion.UsedAs<RowState>)
	return {
		UI.corner(scope, 14),
		scope:New("UIStroke")({
			Thickness = 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Color = scope:Computed(function(use) return stateAccent(use(state)) end),
			Transparency = scope:Computed(function(use) return if use(state) == "locked" or use(state) == "owned" then 0.25 else 0.1 end),
		}),
		scope:New("UIGradient")({ Rotation = 90, Color = ColorSequence.new(UI.WHITE, Color3.fromRGB(216, 226, 234)) }),
	}
end
local function badge(scope: Scope, name: string, text: any, color: any, props: { [any]: any })
	local base: { [any]: any } = { Name = name, BackgroundColor3 = UI.PANEL_DARK, BorderSizePixel = 0 }
	for key, value in props do base[key] = value end
	base[Children] = {
		UI.corner(scope, 6),
		UI.body(scope, { Name = "Caption", Size = UDim2.fromScale(1, 1), Text = text, TextSize = 10, Font = Enum.Font.GothamBold, TextColor3 = color }),
	}
	return scope:New("Frame")(base)
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
		Size = UDim2.new(1, -28, 0, 46), TextSize = 18, AutoButtonColor = enabled, Active = enabled, Selectable = enabled,
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
			return if use(enabled) then UI.OUTLINE elseif state == "equipped" or state == "max" then UI.HUD_MINT else UI.HUD_MUTED
		end),
		BackgroundColor3 = scope:Computed(function(use)
			local state = use(props.State)
			if state == "equipped" or state == "max" then return Color3.fromRGB(42, 67, 59) end
			if use(enabled) then return UI.HUD_GOLD end
			return UI.DISABLED
		end),
		[OnEvent("Activated")] = function() if Fusion.peek(enabled) then props.OnBuy() end end,
	})
end
local function stat(scope: Scope, index: number, title: string, value: string)
	return scope:New("Frame")({
		Name = title, Position = UDim2.new((index - 1) / 3, 0, 0, 0), Size = UDim2.new(1 / 3, -4, 1, 0), BackgroundColor3 = UI.PANEL_DARK, BorderSizePixel = 0,
		[Children] = {
			UI.corner(scope, 8),
			UI.body(scope, { Position = UDim2.fromOffset(0, 5), Size = UDim2.new(1, 0, 0, 14), Text = title, TextSize = 10, TextColor3 = UI.HUD_MUTED }),
			UI.label(scope, { Position = UDim2.fromOffset(0, 23), Size = UDim2.new(1, 0, 0, 22), Text = value, TextSize = 19, TextStrokeTransparency = 1 }),
		},
	})
end
local function equipmentCard(scope: Scope, kind: string, tier: number, item: any, owned: any, wallet: any, busy: any, onBuy: () -> ())
	local state = scope:Computed(function(use) return tierState(use(owned), tier) end)
	local tint = if kind == "pickaxe" then item.Color:Lerp(UI.WHITE, 0.35) else CYAN
	local stats = if kind == "pickaxe" then {
		stat(scope, 1, "Ore/hit", Format.number(item.OrePerHit)),
		stat(scope, 2, "Swing time", string.format("%.2fs", item.Swing)),
		stat(scope, 3, "Damage", Format.number(item.Damage)),
	} else {
		scope:New("Frame")({
			Name = "Capacity", Size = UDim2.fromScale(1, 1), BackgroundColor3 = UI.PANEL_DARK, BorderSizePixel = 0,
			[Children] = {
				UI.corner(scope, 8),
				UI.hudIcon(scope, "ore", { Position = UDim2.fromOffset(11, 12), Size = UDim2.fromOffset(28, 28) }),
				UI.body(scope, { Position = UDim2.fromOffset(48, 5), Size = UDim2.new(1, -58, 0, 14), Text = "ORE CAPACITY", TextSize = 10, TextColor3 = UI.HUD_MUTED, TextXAlignment = Enum.TextXAlignment.Left }),
				UI.label(scope, { Position = UDim2.fromOffset(48, 23), Size = UDim2.new(1, -58, 0, 24), Text = Format.number(item.Capacity) .. " ore", TextSize = 22, TextColor3 = CYAN, TextXAlignment = Enum.TextXAlignment.Left, TextStrokeTransparency = 1 }),
			},
		}),
	}
	return scope:New("Frame")({
		Name = kind .. "Tier" .. tier, LayoutOrder = tier, Size = UDim2.new(0, CARD_WIDTH, 1, -12), BackgroundColor3 = UI.CARD, BorderSizePixel = 0,
		[Children] = {
			cardFill(scope, state),
			scope:New("Frame")({
				Name = "PreviewWell", Position = UDim2.fromOffset(12, 12), Size = UDim2.new(1, -24, 0, 144), BackgroundColor3 = UI.PANEL_DARK, BorderSizePixel = 0,
				[Children] = {
					UI.corner(scope, 10),
					scope:New("UIGradient")({ Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(204, 221, 231), UI.WHITE) }),
					EquipmentPreview(scope, kind, tier, { Position = UDim2.fromOffset(0, 14), Size = UDim2.new(1, 0, 1, -14) }),
					badge(scope, "Tier", "TIER " .. tier, tint, { Position = UDim2.fromOffset(8, 8), Size = UDim2.fromOffset(57, 20) }),
					badge(scope, "State", scope:Computed(function(use)
						local s = use(state)
						return if s == "equipped" then "EQUIPPED" elseif s == "next" then "NEXT UP" elseif s == "owned" then "OWNED" else "LOCKED"
					end), scope:Computed(function(use) local s = use(state) return if s == "owned" or s == "locked" then UI.HUD_MUTED else stateAccent(s) end), { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 8), Size = UDim2.fromOffset(76, 20) }),
				},
			}),
			UI.label(scope, { Name = "GearName", Position = UDim2.fromOffset(12, 168), Size = UDim2.new(1, -24, 0, 30), Text = item.Name, TextSize = 23, TextColor3 = UI.WHITE, TextStrokeTransparency = 0.75 }),
			scope:New("Frame")({ Name = "Stats", Position = UDim2.fromOffset(12, 208), Size = UDim2.new(1, -24, 0, 50), BackgroundTransparency = 1, [Children] = stats }),
			UI.body(scope, {
				Name = "UpgradeHint", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -70), Size = UDim2.new(1, -24, 0, 18), TextSize = 11,
				TextColor3 = scope:Computed(function(use) return if use(state) == "equipped" then UI.HUD_MINT elseif use(state) == "next" and Price.canAfford(use(wallet), item.Cost, item.Shards) then UI.HUD_GOLD else UI.HUD_MUTED end),
				Text = scope:Computed(function(use)
					local s = use(state)
					if s == "locked" then return "Unlock Tier " .. (tier - 1) .. " first" end
					if s == "equipped" then return "Your current gear" end
					if s == "owned" then return "Already in your collection" end
					return if Price.canAfford(use(wallet), item.Cost, item.Shards) then "Ready for your next upgrade" else "Save up for this upgrade"
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
	local compact = scope:Computed(function(use) return use(width) < 740 end)
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
			ScrollingDirection = Enum.ScrollingDirection.X, ScrollBarThickness = 4, ScrollBarImageColor3 = UI.HUD_GOLD,
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
		local state = scope:Computed(function(use): RowState return if use(nextLevel) then "next" else "max" end)
		local function statText(entry: Config.Level): string
			local value = entry.Capacity or entry.Rate or 0
			return (if entry.Rate then string.format("%g", value) else Format.number(value)) .. " " .. STATION_UNITS[stationId]
		end
		local function stationStat(isNext: boolean)
			return scope:New("Frame")({
				Name = if isNext then "NextStat" else "CurrentStat", Position = if isNext then UDim2.new(0.5, 3, 0, 0) else UDim2.fromOffset(0, 0),
				Size = UDim2.new(0.5, -3, 1, 0), BackgroundColor3 = UI.PANEL_DARK, BorderSizePixel = 0,
				[Children] = {
					UI.corner(scope, 8),
					UI.body(scope, { Position = UDim2.fromOffset(0, 5), Size = UDim2.new(1, 0, 0, 14), Text = if isNext then "NEXT LEVEL" else "CURRENT", TextSize = 10, TextColor3 = UI.HUD_MUTED }),
					UI.label(scope, { Position = UDim2.fromOffset(4, 23), Size = UDim2.new(1, -8, 0, 22), TextSize = 17, TextStrokeTransparency = 1, TextColor3 = if isNext then UI.HUD_MINT else UI.WHITE,
						Text = scope:Computed(function(use) local upcoming = use(nextLevel) return if isNext then (if upcoming then statText(upcoming) else "MAX") else statText(station.Levels[use(level)]) end),
					}),
				},
			})
		end
		local stationIcon = if stationId == "refinery" then "foundry" elseif stationId == "collector" then "barStack" elseif stationId == "conveyor" then "chevron" else "ore"
		stationCards[order] = scope:New("Frame")({
			Name = stationId, LayoutOrder = order, Size = UDim2.new(0, CARD_WIDTH, 1, -12), BackgroundColor3 = UI.CARD, BorderSizePixel = 0,
			[Children] = {
				cardFill(scope, state),
				scope:New("Frame")({
					Name = "PreviewWell", Position = UDim2.fromOffset(12, 12), Size = UDim2.new(1, -24, 0, 144), BackgroundColor3 = UI.PANEL_DARK, BorderSizePixel = 0,
					[Children] = {
						UI.corner(scope, 10),
						scope:New("UIGradient")({ Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(204, 221, 231), UI.WHITE) }),
						UI.hudIcon(scope, stationIcon, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 12), Size = UDim2.fromOffset(84, 84), ImageColor3 = if stationId == "collector" then UI.HUD_GOLD else UI.WHITE }),
						badge(scope, "Level", scope:Computed(function(use) return string.format("LEVEL %d / %d", use(level), #station.Levels) end), UI.HUD_GOLD, { Position = UDim2.fromOffset(8, 8), Size = UDim2.fromOffset(83, 20) }),
						badge(scope, "State", scope:Computed(function(use) return if use(nextLevel) then "UPGRADE" else "MAXED" end), scope:Computed(function(use) return stateAccent(use(state)) end), { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 8), Size = UDim2.fromOffset(76, 20) }),
					},
				}),
				UI.label(scope, { Name = "StationName", Position = UDim2.fromOffset(12, 168), Size = UDim2.new(1, -24, 0, 30), Text = station.Name, TextSize = 23, TextStrokeTransparency = 0.75 }),
				scope:New("Frame")({ Name = "Stats", Position = UDim2.fromOffset(12, 208), Size = UDim2.new(1, -24, 0, 50), BackgroundTransparency = 1, [Children] = { stationStat(false), stationStat(true) } }),
				UI.body(scope, { Name = "UpgradeHint", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -70), Size = UDim2.new(1, -24, 0, 18), TextSize = 11, TextColor3 = UI.HUD_MUTED,
					Text = scope:Computed(function(use)
						local upcoming = use(nextLevel)
						if not upcoming then return "Production fully upgraded" end
						return if Price.canAfford(use(wallet), upcoming.Cost, upcoming.Shards) then "Ready to boost production" else "Save up for the next level"
					end),
				}),
				purchaseButton(scope, {
					State = state,
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
			Name = info.Id .. "Tab", LayoutOrder = index, Size = UDim2.new(1 / 3, -6, 1, 0), Text = info.Name,
			TextSize = scope:Computed(function(use) return if use(width) < 430 then 12 elseif use(width) < 650 then 14 else 15 end),
			BackgroundColor3 = scope:Computed(function(use) return if use(tab) == info.Id then UI.HUD_GOLD else UI.CARD end),
			TextColor3 = scope:Computed(function(use) return if use(tab) == info.Id then UI.OUTLINE else UI.HUD_MUTED end),
			[OnEvent("Activated")] = function() tab:set(info.Id) end,
		})
	end
	local function balance(kind: string, offset: number, badgeWidth: number)
		return scope:New("Frame")({
			Name = kind .. "Balance", Position = scope:Computed(function(use)
				local compactScale = math.min(1, (use(width) - 40) / 282)
				return if use(compact) then UDim2.fromOffset(20 + offset * compactScale, 64) else UDim2.new(1, -HudLayout.closeSize(42, use(scale)) - 314 + offset, 0, 24)
			end), Size = scope:Computed(function(use) local factor = if use(compact) then math.min(1, (use(width) - 40) / 282) else 1 return UDim2.fromOffset(badgeWidth * factor, 36) end), BackgroundColor3 = UI.PANEL_DARK, BorderSizePixel = 0,
			[Children] = {
				UI.hudFill(scope), UI.hudIcon(scope, if kind == "cash" then "coin" else "crystal", { Position = UDim2.fromOffset(6, 5), Size = UDim2.fromOffset(26, 26) }),
				UI.label(scope, { Name = "Amount", Position = UDim2.fromOffset(40, 0), Size = UDim2.new(1, -46, 1, 0), TextXAlignment = Enum.TextXAlignment.Left, TextSize = 19, TextStrokeTransparency = 1, TextColor3 = if kind == "cash" then UI.HUD_GOLD else CYAN,
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
				BackgroundColor3 = scope:Spring(scope:Computed(function(use) return if use(glow) then UI.HUD_MINT else UI.HUD_GOLD end), 12, 1),
				Visible = scope:Computed(function(use) return not use(open) end),
				[OnEvent("Activated")] = function() open:set(true) end,
			}),
			scope:New("TextButton")({
				Name = "Dimmer", Size = UDim2.fromScale(1, 1), BackgroundColor3 = UI.OUTLINE, BackgroundTransparency = 0.28,
				Text = "", AutoButtonColor = false, BorderSizePixel = 0, Visible = open, ZIndex = 2, Modal = true,
				[OnEvent("Activated")] = function() open:set(false) end,
			}),
			scope:New("Frame")({
				Name = "Panel", AnchorPoint = Vector2.new(0.5, 0.5), Position = scope:Computed(function(use) return UDim2.new(0.5, 0, 0.5, use(hud).inset / 2) end),
				Size = scope:Computed(function(use) return UDim2.fromOffset(use(width), 600) end), BackgroundColor3 = UI.PANEL, BorderSizePixel = 0, Visible = open, ZIndex = 3, Active = true,
				[Children] = {
					UI.panelFill(scope), scope:New("UIScale")({ Scale = scale }),
					scope:New("Frame")({ Name = "Interior", Position = UDim2.fromOffset(10, 108), Size = UDim2.new(1, -20, 1, -118), BackgroundColor3 = UI.PANEL_DARK, BorderSizePixel = 0, [Children] = { UI.corner(scope, 12) } }),
					UI.hudIcon(scope, "equipment", { Position = UDim2.fromOffset(22, 16), Size = UDim2.fromOffset(38, 38) }),
					UI.label(scope, {
						Name = "Title", Position = UDim2.fromOffset(70, 14), Size = scope:Computed(function(use) return UDim2.new(1, if use(compact) then -92 - HudLayout.closeSize(42, use(scale)) else -396 - HudLayout.closeSize(42, use(scale)), 0, 40) end),
						Text = "GEAR SHOP", TextSize = scope:Computed(function(use) return if use(compact) then 27 else 32 end), TextColor3 = UI.WHITE, TextStrokeTransparency = 0.7, TextXAlignment = Enum.TextXAlignment.Left,
					}),
					UI.body(scope, { Name = "Subtitle", Position = UDim2.fromOffset(72, 56), Size = UDim2.new(1, -410, 0, 20), Text = "Mine bigger. Build faster.", TextSize = 13, TextColor3 = UI.HUD_MUTED, TextXAlignment = Enum.TextXAlignment.Left, Visible = scope:Computed(function(use) return not use(compact) end) }),
					balance("cash", 0, 146), balance("shard", 156, 126),
					UI.button(scope, { Name = "Close", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -18, 0, 18), Size = scope:Computed(function(use) local s = HudLayout.closeSize(42, use(scale)) return UDim2.fromOffset(s, s) end), Text = "", BackgroundColor3 = UI.CARD,
						[Children] = { UI.hudIcon(scope, "close", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(22, 22) }) }, [OnEvent("Activated")] = function() open:set(false) end,
					}),
					scope:New("Frame")({ Name = "TabRail", Position = UDim2.fromOffset(20, 112), Size = UDim2.new(1, -40, 0, 40), BackgroundTransparency = 1,
						[Children] = { scope:New("UIListLayout")({ FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 9), SortOrder = Enum.SortOrder.LayoutOrder }), tabButtons },
					}),
					carousels,
					UI.button(scope, { Name = "Previous", Position = UDim2.new(0, 22, 1, -50), Size = UDim2.fromOffset(44, 36), Text = "", BackgroundColor3 = UI.CARD,
						[Children] = { UI.hudIcon(scope, "chevron", { Position = UDim2.fromOffset(12, 8), Size = UDim2.fromOffset(20, 20), Rotation = 180, ImageColor3 = UI.HUD_GOLD }) }, [OnEvent("Activated")] = function() move(-1) end,
					}),
					UI.button(scope, { Name = "Next", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -22, 1, -50), Size = UDim2.fromOffset(44, 36), Text = "", BackgroundColor3 = UI.CARD,
						[Children] = { UI.hudIcon(scope, "chevron", { Position = UDim2.fromOffset(12, 8), Size = UDim2.fromOffset(20, 20), ImageColor3 = UI.HUD_GOLD }) }, [OnEvent("Activated")] = function() move(1) end,
					}),
					UI.body(scope, { Name = "Notice", Position = UDim2.new(0, 76, 1, -50), Size = UDim2.new(1, -152, 0, 36), TextSize = 12, TextWrapped = true, TextColor3 = UI.HUD_MUTED,
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
