--!strict
-- Pixel-based gear showcase. The server still validates every tier and price.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Knit = require(ReplicatedStorage.Packages.Knit)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local ShopLayout = require(ReplicatedStorage.Shared.EquipmentShopLayout)
local Price = require(ReplicatedStorage.Shared.Price)
local Gear = require(ReplicatedStorage.Shared.Gear)
local Levels = require(ReplicatedStorage.Shared.Levels)
local Levels = require(ReplicatedStorage.Shared.Levels)
local Pets = require(ReplicatedStorage.Shared.Pets)
local UI = require(script.Parent.Parent.UI)
local EquipmentPreview = require(script.Parent.Parent.EquipmentPreview)

local Children, OnEvent, OnChange = Fusion.Children, Fusion.OnEvent, Fusion.OnChange
local player = Players.LocalPlayer
local ShopController = Knit.CreateController({ Name = "ShopController" })
type Scope = UI.Scope
type RowState = "owned" | "equipped" | "next" | "locked" | "max"
local TABS = {
	{ Id = "pickaxe", Name = "PICKAXE" },
	{ Id = "backpack", Name = "BACKPACK" },
	{ Id = "pets", Name = "PETS" },
	{ Id = "plot", Name = "PRODUCTION" },
}
local STATION_UNITS = { hopper = "ore", conveyor = "ore/s", refinery = "bars/s", collector = "bars" }
local STATION_ICONS = { hopper = "ore", conveyor = "chevron", refinery = "foundry", collector = "bars" }
local STATE_TEXT = { owned = "OWNED", equipped = "EQUIPPED", next = "NEXT UPGRADE", locked = "LOCKED", max = "MAX LEVEL" }
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

local function stateAccent(state: RowState): Color3
	return if state == "equipped" or state == "max" then UI.HUD_MINT
		elseif state == "next" then UI.HUD_GOLD else UI.HUD_BORDER
end

-- All card coordinates are screen pixels, including on phones.
local function cardBox(g: any, name: string)
	local w, h = g.cardWidth, g.cardHeight
	if g.short then
		local boxes = {
			preview = { 12, 40, 128, h - 52 },
			title = { 154, 12, w - 168, 28 },
			stats = { 154, 46, w - 168, 42 },
			price = { 154, h - 76, w - 168, 22 },
			buy = { 154, h - 52, w - 168, 44 },
			tier = { 12, 12, 128, 20 },
			state = { 12, 12, 128, 20 },
		}
		return boxes[name]
	end
	local boxes = if g.narrow then {
		preview = { 12, 34, w - 24, h - 200 },
		title = { 12, h - 160, w - 24, 28 },
		stats = { 12, h - 126, w - 24, 42 },
		price = { 12, h - 78, w - 24, 18 },
		buy = { 12, h - 54, w - 24, 44 },
		tier = { 12, 10, 76, 18 },
		state = { 88, 10, w - 100, 18 },
	} else {
		preview = { 12, 36, 134, h - 94 },
		title = { 160, 12, w - 172, 44 },
		stats = { 160, 64, w - 172, 90 },
		price = { 160, h - 82, w - 172, 22 },
		buy = { 12, h - 52, w - 24, 44 },
		tier = { 12, 10, 134, 18 },
		state = { 12, 10, 134, 18 },
	}
	return boxes[name]
end

local function boxProperty(scope: Scope, geometry: any, name: string, size: boolean)
	return scope:Computed(function(use)
		local r = cardBox(use(geometry), name)
		return if size then UDim2.fromOffset(r[3], r[4]) else UDim2.fromOffset(r[1], r[2])
	end)
end

local function statCell(scope: Scope, geometry: any, index: number, count: number, title: string, value: any, color: Color3)
	local rows = scope:Computed(function(use) local g = use(geometry) return not g.short and not g.narrow end)
	local single = scope:Computed(function(use) return use(rows) and count == 1 end)
	local labelFraction = if count == 2 then 0.42 else 0.58
	return scope:New("Frame")({
		Name = title,
		Position = scope:Computed(function(use) return if use(rows) then UDim2.new(0, 0, (index - 1) / count, 0) else UDim2.new((index - 1) / count, 0, 0, 0) end),
		Size = scope:Computed(function(use) return if use(rows) then UDim2.new(1, 0, 1 / count, -4) else UDim2.new(1 / count, -4, 1, 0) end),
		BackgroundColor3 = UI.PANEL_DARK, BorderSizePixel = 0,
		[Children] = {
			UI.corner(scope, 8),
			UI.body(scope, {
				Name = "Label",
				Position = scope:Computed(function(use) return if use(single) then UDim2.fromOffset(8, 10) elseif use(rows) then UDim2.fromOffset(8, 0) else UDim2.fromOffset(3, 4) end),
				Size = scope:Computed(function(use) return if use(single) then UDim2.new(1, -16, 0, 18) elseif use(rows) then UDim2.new(labelFraction, -8, 1, 0) else UDim2.new(1, -6, 0, 14) end),
				TextXAlignment = scope:Computed(function(use) return if use(rows) and not use(single) then Enum.TextXAlignment.Left else Enum.TextXAlignment.Center end),
				Text = title, TextSize = 11, TextColor3 = UI.HUD_MUTED,
			}),
			UI.label(scope, {
				Name = "Value",
				Position = scope:Computed(function(use) return if use(single) then UDim2.fromOffset(8, 34) elseif use(rows) then UDim2.fromScale(labelFraction, 0) else UDim2.fromOffset(3, 20) end),
				Size = scope:Computed(function(use) return if use(single) then UDim2.new(1, -16, 1, -42) elseif use(rows) then UDim2.new(1 - labelFraction, -8, 1, 0) else UDim2.new(1, -6, 1, -23) end),
				TextXAlignment = scope:Computed(function(use) return if use(rows) and not use(single) then Enum.TextXAlignment.Right else Enum.TextXAlignment.Center end),
				Text = value, TextScaled = true, TextColor3 = color, TextStrokeTransparency = 1,
				[Children] = { scope:New("UITextSizeConstraint")({ MinTextSize = 14, MaxTextSize = scope:Computed(function(use) return if use(single) then 28 else 21 end) }) },
			}),
		},
	})
end

local function priceText(cash: number, shards: number): string
	if cash <= 0 and shards <= 0 then return "Free" end
	local cashText = if cash > 0 then '<font color="#FFDB64">' .. Format.cash(cash) .. '</font>' else ""
	local shardText = if shards > 0 then '<font color="#71CDFF">' .. Format.number(shards) .. ' shards</font>' else ""
	return cashText .. (if cashText ~= "" and shardText ~= "" then " + " else "") .. shardText
end

local function itemCard(scope: Scope, geometry: any, props: any)
	local state, cost, shards = props.State, props.Cost, props.Shards
	local affordable = scope:Computed(function(use)
		return Price.canAfford(use(props.Wallet), use(cost), use(shards))
	end)
	local enabled = scope:Computed(function(use)
		if props.Enabled then return use(props.Enabled) and use(props.Loaded) and use(props.BusyId) == nil end
		return use(state) == "next" and use(affordable) and use(props.Loaded) and use(props.BusyId) == nil
	end)
	local buyingThis = scope:Computed(function(use) return use(props.BusyId) == props.Id end)
	local accent = scope:Computed(function(use) return stateAccent(use(state)) end)
	return scope:New("Frame")({
		Name = props.Id, LayoutOrder = props.Order,
		Size = scope:Computed(function(use) local g = use(geometry) return UDim2.fromOffset(g.cardWidth, g.cardHeight) end),
		BackgroundColor3 = UI.CARD, BorderSizePixel = 0,
		[Children] = {
			UI.corner(scope, 14),
			scope:New("UIStroke")({ Color = accent, Thickness = 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
			scope:New("Frame")({
				Name = "Accent", Position = UDim2.fromOffset(14, 0), Size = UDim2.new(1, -28, 0, 3),
				BackgroundColor3 = accent, BorderSizePixel = 0, [Children] = { UI.corner(scope, 2) },
			}),
			UI.body(scope, {
				Name = "Tier", Position = boxProperty(scope, geometry, "tier", false), Size = boxProperty(scope, geometry, "tier", true),
				Text = scope:Computed(function(use)
					local level = use(props.LevelText)
					return if not use(geometry).narrow then level .. "  " .. (if use(state) == "next" then "NEXT" elseif use(state) == "equipped" then "EQUIPPED" else "") else level
				end),
				TextSize = 11, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = scope:Computed(function(use) return if use(state) == "locked" then UI.HUD_MUTED else use(accent) end),
			}),
			UI.body(scope, {
				Name = "State", Position = boxProperty(scope, geometry, "state", false), Size = boxProperty(scope, geometry, "state", true),
				Text = scope:Computed(function(use) return STATE_TEXT[use(state)] end), TextSize = 11, Font = Enum.Font.GothamBold,
				TextColor3 = scope:Computed(function(use) return if use(state) == "owned" or use(state) == "locked" then UI.HUD_MUTED else use(accent) end),
				TextXAlignment = Enum.TextXAlignment.Right, Visible = scope:Computed(function(use) return use(geometry).narrow end),
			}),
			scope:New("Frame")({
				Name = "PreviewWell", Position = boxProperty(scope, geometry, "preview", false), Size = boxProperty(scope, geometry, "preview", true),
				BackgroundColor3 = UI.PANEL_DARK, BorderSizePixel = 0,
				[Children] = {
					UI.corner(scope, 10),
					scope:New("UIStroke")({ Color = UI.HUD_BORDER, Transparency = 0.65, Thickness = 1 }),
					props.Preview,
				},
			}),
			UI.label(scope, {
				Name = props.TitleName or "GearName", Position = boxProperty(scope, geometry, "title", false), Size = boxProperty(scope, geometry, "title", true),
				Text = props.Title, TextScaled = true, TextWrapped = true, TextStrokeTransparency = 1,
				TextXAlignment = scope:Computed(function(use) return if use(geometry).narrow then Enum.TextXAlignment.Center else Enum.TextXAlignment.Left end),
				[Children] = { scope:New("UITextSizeConstraint")({ MinTextSize = 17, MaxTextSize = 23 }) },
			}),
			scope:New("Frame")({
				Name = "Stats", Position = boxProperty(scope, geometry, "stats", false), Size = boxProperty(scope, geometry, "stats", true),
				BackgroundTransparency = 1, [Children] = props.Stats,
			}),
			UI.label(scope, {
				Name = "Price", Position = boxProperty(scope, geometry, "price", false), Size = boxProperty(scope, geometry, "price", true),
				RichText = true, TextScaled = true, TextStrokeTransparency = 1,
				Text = scope:Computed(function(use)
					local s = use(state)
					if props.PriceText then return use(props.PriceText) end
					return if s == "equipped" then "Your current gear" elseif s == "owned" then "Already owned"
						elseif s == "max" then "Fully upgraded" else priceText(use(cost), use(shards))
				end),
				TextColor3 = UI.HUD_MUTED,
				[Children] = { scope:New("UITextSizeConstraint")({ MinTextSize = 12, MaxTextSize = 17 }) },
			}),
			UI.button(scope, {
				Name = "Purchase", Position = boxProperty(scope, geometry, "buy", false), Size = boxProperty(scope, geometry, "buy", true),
				TextScaled = true, AutoButtonColor = enabled, Active = enabled, Selectable = enabled,
				Text = scope:Computed(function(use)
					local s = use(state)
					if props.ButtonText then return use(props.ButtonText) end
					if s == "equipped" then return "EQUIPPED" end
					if s == "owned" then return "OWNED" end
					if s == "max" then return "MAX LEVEL" end
					if s == "locked" then return use(props.LockedText or "LOCKED") end
					if not use(props.Loaded) then return "LOADING" end
					if use(buyingThis) then return "UPGRADING..." end
					return if use(affordable) then (props.ReadyText or "UPGRADE") else "SAVE UP"
				end),
				TextColor3 = scope:Computed(function(use)
					return if use(enabled) then UI.OUTLINE elseif use(state) == "equipped" or use(state) == "max" then UI.HUD_MINT else UI.HUD_MUTED
				end),
				BackgroundColor3 = scope:Computed(function(use)
					return if use(enabled) then UI.HUD_GOLD elseif use(state) == "equipped" or use(state) == "max" then Color3.fromRGB(38, 62, 53) else UI.PANEL_DARK
				end),
				[Children] = { scope:New("UITextSizeConstraint")({ MinTextSize = 13, MaxTextSize = 18 }) },
				[OnEvent("Activated")] = function() if Fusion.peek(enabled) then props.OnBuy() end end,
			}),
		},
	})
end

function ShopController:KnitStart()
	local ShopService = Knit.GetService("ShopService")
	local UpgradeService = Knit.GetService("UpgradeService")
	local PetService = Knit.GetService("PetService")
	local PlayerStateService = Knit.GetService("PlayerStateService")
	local scope = Fusion.scoped(Fusion)
	local open, tab, glow = scope:Value(wantOpen), scope:Value("pickaxe"), scope:Value(wantHighlight)
	local busyId, notice = scope:Value(nil :: string?), scope:Value("")
	isOpen, highlight = open, glow
	local hud = UI.hud(scope)
	local geometry = scope:Computed(function(use)
		local l = use(hud)
		return ShopLayout.compute(l.viewport, l.inset)
	end)
	local playerState = scope:Value(nil :: any)
	local loaded = scope:Computed(function(use) return use(playerState) ~= nil end)
	PlayerStateService.State:Observe(function(value) playerState:set(value) end)
	ShopService.Open:Connect(function() open:set(true) end)
	ShopService.Notice:Connect(function(message) notice:set(message) end)
	UpgradeService.Notice:Connect(function(message) notice:set(message) end)
	PetService.Notice:Connect(function(message) notice:set(message) end)
	local wallet = scope:Computed(function(use): Price.Wallet
		local s = use(playerState)
		return { cash = if s then s.cash else 0, shards = if s then s.shards else 0 }
	end)
	local function owned(key: string)
		return scope:Computed(function(use) local s = use(playerState) return if s then s[key] else 1 end)
	end
	local pickaxeTier, backpackTier = owned("pickaxeTier"), owned("backpackTier")
	local function purchase(id: string, message: string, callback: () -> any)
		if Fusion.peek(busyId) ~= nil then return end
		busyId:set(id)
		notice:set("")
		task.spawn(function()
			local ok, result = pcall(callback)
			busyId:set(nil)
			if not ok then notice:set("Couldn't complete the upgrade. Please try again.")
			elseif result then notice:set(message) end
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
			local tween = TweenService:Create(list, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CanvasPosition = target })
			scrollTweens[kind] = tween
			tween:Play()
		else
			list.CanvasPosition = target
		end
	end
	local function makeList(kind: string, cards: { any }): ScrollingFrame
		local position = scope:Value(0)
		positions[kind] = position
		local list = scope:New("ScrollingFrame")({
			Name = kind .. "Carousel",
			Position = scope:Computed(function(use) local g = use(geometry) return UDim2.fromOffset(g.padding, g.carouselY) end),
			Size = scope:Computed(function(use) local g = use(geometry) return UDim2.fromOffset(g.panel.w - 2 * g.padding, g.carouselH) end),
			BackgroundTransparency = 1, BorderSizePixel = 0,
			CanvasSize = scope:Computed(function(use) local g = use(geometry) return UDim2.fromOffset(#cards * (g.cardWidth + g.gap) - g.gap + 8, g.cardHeight + 8) end),
			ScrollingDirection = scope:Computed(function(use)
				local g = use(geometry)
				return if g.cardHeight + 8 > g.carouselH - 4 then Enum.ScrollingDirection.XY else Enum.ScrollingDirection.X
			end),
			ScrollBarThickness = 4, ScrollBarImageColor3 = UI.HUD_GOLD,
			ElasticBehavior = Enum.ElasticBehavior.WhenScrollable, Visible = scope:Computed(function(use) return use(tab) == kind end),
			[OnChange("CanvasPosition")] = function(value: Vector2) position:set(value.X) end,
			[Children] = {
				scope:New("UIPadding")({ PaddingLeft = UDim.new(0, 4), PaddingTop = UDim.new(0, 4), PaddingRight = UDim.new(0, 4) }),
				scope:New("UIListLayout")({
					FillDirection = Enum.FillDirection.Horizontal,
					Padding = scope:Computed(function(use) return UDim.new(0, use(geometry).gap) end),
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
				cards,
			},
		})
		lists[kind] = list
		return list
	end

	local pickaxeCards, backpackCards, stationCards = {}, {}, {}
	local tierOf = { pickaxe = pickaxeTier, backpack = backpackTier }
	local settingsOf = { pickaxe = Config.Gear.Pickaxe, backpack = Config.Gear.Backpack }
	local tiersOf = { pickaxe = Config.Pickaxes, backpack = Config.Backpacks }
	-- Saved stat levels from the server's State (a fresh item's while it loads)
	local function levelOf(kind: string, stat: string)
		return scope:Computed(function(use)
			local s = use(playerState)
			local stats = s and s[kind .. "Stats"]
			return if stats and stats[stat] then stats[stat] else 1
		end)
	end
	local function evolutionOf(kind: string)
		return scope:Computed(function(use)
			local s = use(playerState)
			if not s or not s[kind .. "Stats"] then return nil end
			return Gear.evolution(kind, use(tierOf[kind]), s[kind .. "Stats"])
		end)
	end
	-- What a stat does at a level, as text (the other stats stay at level 1)
	local function statValue(kind: string, stat: string, level: number): string
		if kind == "backpack" then
			return Format.number(math.floor(Gear.capacity(1, { capacity = level }))) .. " ore"
		end
		local levels = { power = 1, speed = 1, reach = 1, crit = 1 }
		levels[stat] = level
		local pickaxe = Gear.pickaxe(1, levels)
		if stat == "power" then return string.format("%.2f", pickaxe.Power)
		elseif stat == "speed" then return string.format("%.2fs", pickaxe.Swing)
		elseif stat == "reach" then return string.format("%.1f studs", pickaxe.Reach)
		end
		return string.format("%.1f%%", pickaxe.CritChance * 100)
	end
	local function statCard(kind: string, stat: string, order: number)
		local level, tier = levelOf(kind, stat), tierOf[kind]
		local price = scope:Computed(function(use) return Gear.price(kind, stat, use(level)) end)
		local settings = settingsOf[kind]
		local id = kind .. "_" .. stat
		return itemCard(scope, geometry, {
			Id = id, Order = order, Title = settings.Names[stat], TitleName = "StatName",
			LevelText = scope:Computed(function(use) return "LEVEL " .. use(level) .. " / " .. Gear.cap(use(tier)) end),
			State = scope:Computed(function(use): RowState
				if use(price) == nil then return "max" end
				return if Gear.canLevel(kind, use(tier), use(level)) then "next" else "locked"
			end),
			LockedText = "EVOLVE FIRST",
			Cost = scope:Computed(function(use) return use(price) or 0 end), Shards = 0,
			Wallet = wallet, Loaded = loaded, BusyId = busyId,
			Preview = UI.hudIcon(scope, if kind == "backpack" then "backpack" else "equipment", {
				AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.55, 0.75),
			}),
			Stats = {
				statCell(scope, geometry, 1, 2, "CURRENT", scope:Computed(function(use) return statValue(kind, stat, use(level)) end), UI.WHITE),
				statCell(scope, geometry, 2, 2, "NEXT LEVEL", scope:Computed(function(use)
					return if use(price) then statValue(kind, stat, use(level) + 1) else "MAX"
				end), UI.HUD_MINT),
			},
			OnBuy = function() purchase(id, settings.Names[stat] .. " upgraded.", function() return ShopService:Upgrade(kind, stat) end) end,
		})
	end
	-- The evolve card shows the next tier's model, price and what it opens up
	local function evolveCard(kind: string, order: number)
		local evolution, tier = evolutionOf(kind), tierOf[kind]
		local tiers, settings = tiersOf[kind], settingsOf[kind]
		local previews = {}
		for index in tiers do
			previews[index] = EquipmentPreview(scope, kind, index, {
				Size = UDim2.fromScale(1, 1),
				Visible = scope:Computed(function(use)
					local e = use(evolution)
					return (if e then e.tier else #tiers) == index
				end),
			})
		end
		local function nextItem(use: any): any
			local e = use(evolution)
			return tiers[if e then e.tier else #tiers]
		end
		local id = kind .. "_evolve"
		return itemCard(scope, geometry, {
			Id = id, Order = order, TitleName = "EvolveName",
			Title = scope:Computed(function(use)
				return if use(evolution) then nextItem(use).Name else "Fully evolved"
			end),
			LevelText = scope:Computed(function(use)
				local e = use(evolution)
				return if e then "EVOLVE: TIER " .. use(tier) .. " TO " .. e.tier else "TIER " .. use(tier)
			end),
			State = scope:Computed(function(use): RowState
				local e = use(evolution)
				if not e then return "max" end
				local s = use(playerState)
				return if e.ready and (s == nil or s.level >= Levels.evolveLevel(e.tier)) then "next" else "locked"
			end),
			LockedText = scope:Computed(function(use)
				local e, s = use(evolution), use(playerState)
				if e and e.ready and s and s.level < Levels.evolveLevel(e.tier) then
					return "NEEDS LEVEL " .. Levels.evolveLevel(e.tier)
				end
				return "MAX " .. string.upper(settings.Names[settings.Gate]) .. " FIRST"
			end),
			ReadyText = "EVOLVE",
			Cost = scope:Computed(function(use) local e = use(evolution) return if e then e.cost else 0 end),
			Shards = scope:Computed(function(use) local e = use(evolution) return if e then e.shards else 0 end),
			Wallet = wallet, Loaded = loaded, BusyId = busyId,
			Preview = previews,
			Stats = {
				statCell(scope, geometry, 1, 2, if kind == "pickaxe" then "ORE / HIT" else "BASE CAPACITY", scope:Computed(function(use)
					local item = nextItem(use)
					return if kind == "pickaxe" then Format.number(item.OrePerHit) else Format.number(item.Capacity) .. " ore"
				end), UI.HUD_GOLD),
				statCell(scope, geometry, 2, 2, "LEVEL CAP", scope:Computed(function(use)
					local e = use(evolution)
					return if e then tostring(Gear.cap(e.tier)) else "MAX"
				end), UI.HUD_MINT),
			},
			OnBuy = function() purchase(id, "Evolved.", function() return ShopService:Evolve(kind) end) end,
		})
	end
	for order, stat in Config.Gear.Pickaxe.Stats do
		pickaxeCards[order] = statCard("pickaxe", stat, order)
	end
	pickaxeCards[#pickaxeCards + 1] = evolveCard("pickaxe", #pickaxeCards + 1)
	for order, stat in Config.Gear.Backpack.Stats do
		backpackCards[order] = statCard("backpack", stat, order)
	end
	backpackCards[#backpackCards + 1] = evolveCard("backpack", #backpackCards + 1)
	-- Pets: owned ones can be put out or away, the rest cost Core Shards (Shared.Pets)
	local petIcons = { miner = "equipment", hauler = "ore", pack = "backpack", swift = "chevron", merchant = "coin" }
	local petCards = {}
	local function petEntry(petId: string)
		return scope:Computed(function(use)
			local s = use(playerState)
			return if s and s.pets then s.pets.owned[petId] else nil
		end)
	end
	local function petEquipped(petId: string)
		return scope:Computed(function(use)
			local s = use(playerState)
			return s ~= nil and s.pets ~= nil and table.find(s.pets.equipped, petId) ~= nil
		end)
	end
	local function percent(value: number): string
		return string.format("%g%%", math.floor(value * 1000 + 0.5) / 10)
	end
	for order, def in Config.Pets.List do
		local entry, equipped = petEntry(def.Id), petEquipped(def.Id)
		local role = Config.Pets.Roles[def.Role]
		local id = "pet_" .. def.Id
		petCards[order] = itemCard(scope, geometry, {
			Id = id, Order = order, Title = def.Name, TitleName = "PetName",
			LevelText = string.upper(role.Name) .. " PET",
			State = scope:Computed(function(use): RowState
				if use(equipped) then return "equipped" end
				return if use(entry) then "owned" else "next"
			end),
			Cost = 0, Shards = def.Cost,
			Wallet = wallet, Loaded = loaded, BusyId = busyId,
			Enabled = scope:Computed(function(use)
				if use(entry) then return true end
				return Price.canAfford(use(wallet), 0, def.Cost)
			end),
			ButtonText = scope:Computed(function(use)
				if use(equipped) then return "PUT AWAY" end
				if use(entry) then return "EQUIP" end
				return if Price.canAfford(use(wallet), 0, def.Cost) then "BUY" else "SAVE UP"
			end),
			PriceText = scope:Computed(function(use)
				if use(entry) then return def.Blurb end
				return priceText(0, def.Cost)
			end),
			ReadyText = "BUY",
			Preview = UI.hudIcon(scope, petIcons[def.Role] or "equipment", {
				AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(0.55, 0.75), ImageColor3 = def.Color,
			}),
			Stats = {
				statCell(scope, geometry, 1, 3, "LEVEL", scope:Computed(function(use)
					local e = use(entry)
					return (if e then e.level else 1) .. " / " .. Config.Pets.MaxLevel
				end), UI.WHITE),
				statCell(scope, geometry, 2, 3, string.upper(role.Name), scope:Computed(function(use)
					local e = use(entry)
					return percent(Pets.perk(def.Role, if e then e.level else 1))
				end), UI.HUD_GOLD),
				statCell(scope, geometry, 3, 3, "NEXT LEVEL", scope:Computed(function(use)
					local e = use(entry)
					local needed = if e then Pets.xpToNext(e.level) else nil
					return if not e then "-" elseif needed then Format.number(math.floor(e.xp)) .. " / " .. Format.number(needed) else "MAX"
				end), UI.HUD_MINT),
			},
			OnBuy = function()
				if Fusion.peek(entry) == nil then
					purchase(id, def.Name .. " joined you.", function() return PetService:Buy(def.Id) end)
				elseif Fusion.peek(equipped) then
					purchase(id, def.Name .. " put away.", function() return PetService:Unequip(def.Id) end)
				else
					purchase(id, def.Name .. " is out.", function() return PetService:Equip(def.Id) end)
				end
			end,
		})
	end
	for order, stationId in Config.Home.StationOrder do
		local station = Config.Home.Stations[stationId]
		local level = scope:Computed(function(use)
			local s = use(playerState)
			return if s and s.line and s.line[stationId] then s.line[stationId].level else 1
		end)
		local nextLevel = scope:Computed(function(use) return station.Levels[use(level) + 1] end)
		local function statText(entry: any)
			local value = entry.Capacity or entry.Rate or 0
			return (if entry.Rate then string.format("%g", value) else Format.number(value)) .. " " .. STATION_UNITS[stationId]
		end
		stationCards[order] = itemCard(scope, geometry, {
			Id = stationId, Order = order, Title = station.Name, TitleName = "StationName",
			LevelText = scope:Computed(function(use) return "LEVEL " .. use(level) end),
			State = scope:Computed(function(use): RowState return if use(nextLevel) then "next" else "max" end),
			Cost = scope:Computed(function(use) local n = use(nextLevel) return if n then n.Cost else 0 end),
			Shards = scope:Computed(function(use) local n = use(nextLevel) return if n then n.Shards else 0 end),
			Wallet = wallet, Loaded = loaded, BusyId = busyId,
			Preview = UI.hudIcon(scope, STATION_ICONS[stationId], {
				AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(0.55, 0.75), ImageColor3 = if stationId == "collector" then UI.HUD_GOLD else UI.WHITE,
			}),
			Stats = {
				statCell(scope, geometry, 1, 2, "CURRENT", scope:Computed(function(use) return statText(station.Levels[use(level)]) end), UI.WHITE),
				statCell(scope, geometry, 2, 2, "NEXT LEVEL", scope:Computed(function(use) local n = use(nextLevel) return if n then statText(n) else "MAX" end), UI.HUD_MINT),
			},
			OnBuy = function() purchase(stationId, station.Name .. " upgraded.", function() return UpgradeService:BuyStation(stationId) end) end,
		})
	end
	local carousels = { makeList("pickaxe", pickaxeCards), makeList("backpack", backpackCards), makeList("pets", petCards), makeList("plot", stationCards) }
	local function move(direction: number)
		local kind = Fusion.peek(tab)
		local list = lists[kind]
		local g = Fusion.peek(geometry)
		if list then scrollTo(kind, list.CanvasPosition.X + direction * (g.cardWidth + g.gap), true) end
	end
	local function focusOwned()
		local kind = Fusion.peek(tab)
		task.defer(function()
			scrollTo(kind, 0, false)
		end)
	end
	scope:Observer(open):onChange(function()
		player:SetAttribute("ShopOpen", Fusion.peek(open))
		if Fusion.peek(open) then focusOwned() end
	end)
	scope:Observer(tab):onChange(function() notice:set("") focusOwned() end)
	scope:Observer(pickaxeTier):onChange(function() if Fusion.peek(tab) == "pickaxe" then focusOwned() end end)
	scope:Observer(backpackTier):onChange(function() if Fusion.peek(tab) == "backpack" then focusOwned() end end)
	local lastGeometry = Fusion.peek(geometry)
	scope:Observer(geometry):onChange(function()
		local g = Fusion.peek(geometry)
		local changed = g.panel.w ~= lastGeometry.panel.w or g.panel.h ~= lastGeometry.panel.h
			or g.cardWidth ~= lastGeometry.cardWidth or g.cardHeight ~= lastGeometry.cardHeight
		lastGeometry = g
		if changed and Fusion.peek(open) then focusOwned() end
	end)
	table.insert(scope, UserInputService.InputBegan:Connect(function(input, processed)
		if not Fusion.peek(open) or UserInputService:GetFocusedTextBox() then return end
		if input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB then open:set(false)
		elseif not processed and input.KeyCode == Enum.KeyCode.Left then move(-1)
		elseif not processed and input.KeyCode == Enum.KeyCode.Right then move(1) end
	end))

	local tabButtons = {}
	for index, info in TABS do
		tabButtons[index] = UI.button(scope, {
			Name = info.Id .. "Tab", LayoutOrder = index, Size = UDim2.new(1 / #TABS, -4, 1, 0),
			Text = info.Name, TextScaled = true,
			BackgroundColor3 = scope:Computed(function(use) return if use(tab) == info.Id then UI.HUD_GOLD else UI.CARD end),
			TextColor3 = scope:Computed(function(use) return if use(tab) == info.Id then UI.OUTLINE else UI.HUD_MUTED end),
			[Children] = { scope:New("UITextSizeConstraint")({ MinTextSize = 11, MaxTextSize = 16 }) },
			[OnEvent("Activated")] = function() tab:set(info.Id) end,
		})
	end
	local function balance(kind: string, offset: number, badgeWidth: number)
		return scope:New("Frame")({
			Name = kind .. "Balance",
			Position = scope:Computed(function(use)
				local g = use(geometry)
				return if g.narrow then UDim2.fromOffset(g.padding + offset, 50)
					else UDim2.fromOffset(g.panel.w - g.padding - 44 - 12 - 266 + offset, 9)
			end),
			Size = UDim2.fromOffset(badgeWidth, 34), BackgroundColor3 = UI.PANEL_DARK, BorderSizePixel = 0,
			[Children] = {
				UI.corner(scope, 8),
				UI.hudIcon(scope, if kind == "cash" then "coin" else "crystal", { Position = UDim2.fromOffset(7, 7), Size = UDim2.fromOffset(20, 20) }),
				UI.label(scope, {
					Name = "Amount", Position = UDim2.fromOffset(34, 0), Size = UDim2.new(1, -42, 1, 0),
					TextXAlignment = Enum.TextXAlignment.Left, TextScaled = true, TextStrokeTransparency = 1,
					TextColor3 = if kind == "cash" then UI.HUD_GOLD else UI.SHARD,
					Text = scope:Computed(function(use) local w = use(wallet) return if kind == "cash" then Format.cash(w.cash) else Format.number(w.shards) end),
					[Children] = { scope:New("UITextSizeConstraint")({ MinTextSize = 12, MaxTextSize = 20 }) },
				}),
			},
		})
	end
	local function navButton(name: string, right: boolean, direction: number)
		return UI.button(scope, {
			Name = name, AnchorPoint = if right then Vector2.new(1, 0) else Vector2.zero,
			Position = scope:Computed(function(use) local g = use(geometry) return UDim2.new(if right then 1 else 0, if right then -g.padding else g.padding, 0, g.footerY) end),
			Size = UDim2.fromOffset(44, 44), Text = "", BackgroundColor3 = UI.CARD,
			[Children] = { UI.hudIcon(scope, "chevron", { Position = UDim2.fromOffset(12, 12), Size = UDim2.fromOffset(20, 20), Rotation = if right then 0 else 180, ImageColor3 = UI.HUD_GOLD }) },
			[OnEvent("Activated")] = function() move(direction) end,
		})
	end

	scope:New("ScreenGui")({
		Name = "Shop", ResetOnSpawn = false, IgnoreGuiInset = true, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 20, Parent = player:WaitForChild("PlayerGui"),
		[Children] = {
			UI.hudButton(scope, hud, "SHOP", 28, {
				Name = "ShopButton", Text = "SHOP",
				BackgroundColor3 = scope:Spring(scope:Computed(function(use) return if use(glow) then UI.HUD_MINT else UI.HUD_GOLD end), 12, 1),
				Visible = scope:Computed(function(use) return not use(open) end),
				[OnEvent("Activated")] = function() open:set(true) end,
			}),
			scope:New("TextButton")({
				Name = "Dimmer", Size = UDim2.fromScale(1, 1), BackgroundColor3 = UI.OUTLINE, BackgroundTransparency = 0.24,
				Text = "", AutoButtonColor = false, BorderSizePixel = 0, Visible = open, ZIndex = 2, Modal = true,
				[OnEvent("Activated")] = function() open:set(false) end,
			}),
			scope:New("Frame")({
				Name = "Panel",
				Position = scope:Computed(function(use) local r = use(geometry).panel return UDim2.fromOffset(r.x, r.y) end),
				Size = scope:Computed(function(use) local r = use(geometry).panel return UDim2.fromOffset(r.w, r.h) end),
				BackgroundColor3 = UI.PANEL, BorderSizePixel = 0, Visible = open, ZIndex = 3, Active = true,
				[Children] = {
					UI.panelFill(scope),
					UI.hudIcon(scope, "equipment", {
						Position = scope:Computed(function(use) local g = use(geometry) return UDim2.fromOffset(g.padding, 10) end),
						Size = UDim2.fromOffset(32, 32),
					}),
					UI.label(scope, {
						Name = "Title",
						Position = scope:Computed(function(use) local g = use(geometry) return UDim2.fromOffset(g.padding + 44, 8) end),
						Size = scope:Computed(function(use) local g = use(geometry) return UDim2.fromOffset(g.panel.w - g.padding * 2 - (if g.narrow then 100 else 378), 36) end),
						Text = "GEAR SHOP", TextScaled = true, TextStrokeTransparency = 1, TextXAlignment = Enum.TextXAlignment.Left,
						[Children] = { scope:New("UITextSizeConstraint")({ MinTextSize = 18, MaxTextSize = 29 }) },
					}),
					balance("cash", 0, 142), balance("shard", 150, 116),
					UI.button(scope, {
						Name = "Close", AnchorPoint = Vector2.new(1, 0),
						Position = scope:Computed(function(use) local g = use(geometry) return UDim2.new(1, -g.padding, 0, 4) end),
						Size = UDim2.fromOffset(44, 44), Text = "", BackgroundColor3 = UI.CARD,
						[Children] = { UI.hudIcon(scope, "close", { Position = UDim2.fromOffset(11, 11), Size = UDim2.fromOffset(22, 22) }) },
						[OnEvent("Activated")] = function() open:set(false) end,
					}),
					scope:New("Frame")({
						Name = "TabRail",
						AnchorPoint = Vector2.new(0.5, 0),
						Position = scope:Computed(function(use) return UDim2.new(0.5, 0, 0, use(geometry).tabsY) end),
						Size = scope:Computed(function(use) local g = use(geometry) return UDim2.fromOffset((g.panel.w - 2 * g.padding) * 0.8, g.tabsH) end),
						BackgroundTransparency = 1,
						[Children] = {
							scope:New("UIListLayout")({ FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
							tabButtons,
						},
					}),
					carousels, navButton("Previous", false, -1), navButton("Next", true, 1),
					UI.body(scope, {
						Name = "Notice",
						Position = scope:Computed(function(use) local g = use(geometry) return UDim2.fromOffset(g.padding + 52, g.footerY) end),
						Size = scope:Computed(function(use) local g = use(geometry) return UDim2.fromOffset(g.panel.w - 2 * g.padding - 104, 44) end),
						TextSize = 12, TextWrapped = true, TextColor3 = UI.HUD_MUTED,
						Text = scope:Computed(function(use)
							local message = use(notice)
							if message ~= "" then return message end
							if not use(loaded) then return "Loading your equipment..." end
							local kind, g = use(tab), use(geometry)
							local count = if kind == "plot" then #stationCards elseif kind == "pickaxe" then #pickaxeCards elseif kind == "pets" then #petCards else #backpackCards
							local first = math.clamp(math.floor(use(positions[kind]) / (g.cardWidth + g.gap) + 0.5) + 1, 1, count)
							if kind == "pets" then
								local s = use(playerState)
								if s and s.pets then
									return string.format("%d / %d pets out. Rebirths open more slots.   %d / %d", #s.pets.equipped, s.pets.slots, first, count)
								end
							end
							local s = use(playerState)
							local levelText = if s then string.format("Player level %d%s   ", s.level, if s.xpNeeded > 0 then string.format(" (%d / %d XP)", math.floor(s.xp), s.xpNeeded) else " (max)") else ""
							return levelText .. string.format("%d / %d", first, count)
						end),
					}),
				},
			}),
		},
	})
	player:SetAttribute("ShopOpen", Fusion.peek(open))
end

return ShopController
