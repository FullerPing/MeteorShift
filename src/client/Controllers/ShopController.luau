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
}
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
	if g.pet then
		local boxes = if g.short then {
			preview = { 12, 38, 128, h - 52 }, title = { 154, 38, w - 168, 28 },
			stats = { 154, 72, w - 168, h - 162 }, price = { 154, h - 78, w - 168, 22 },
			buy = { 154, h - 52, w - 168, 44 }, tier = { 12, 10, w - 24, 18 }, state = { 12, 10, w - 24, 18 },
		} else {
			preview = { 12, 36, w - 24, 88 }, title = { 12, 132, w - 24, 28 },
			stats = { 12, 166, w - 24, h - 252 }, price = { 12, h - 78, w - 24, 22 },
			buy = { 12, h - 52, w - 24, 44 }, tier = { 12, 10, w - 24, 18 }, state = { 12, 10, w - 24, 18 },
		}
		return boxes[name]
	end
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
	local accent = scope:Computed(function(use) return props.Accent or stateAccent(use(state)) end)
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
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollingDirection = scope:Computed(function(use)
				local g = use(geometry)
				return if kind == "pets" or g.cardHeight + 8 > g.carouselH - 4 then Enum.ScrollingDirection.XY else Enum.ScrollingDirection.X
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
	-- One screen per gear kind: a big preview of what you hold, a row per stat with +1 and
	-- +10 buttons, and one evolve banner with what is still missing.
	local gearScreens = {}
	local function gearScreen(kind: string)
		local settings, tier, tiers = settingsOf[kind], tierOf[kind], tiersOf[kind]
		local evolution = evolutionOf(kind)
		local gate = settings.Gate
		local compact = scope:Computed(function(use) return use(geometry).narrow end)
		local rows = {}
		for order, stat in settings.Stats do
			local level = levelOf(kind, stat)
			local id = kind .. "_" .. stat
			local atCap = scope:Computed(function(use) return not Gear.canLevel(kind, use(tier), use(level)) end)
			local function bulk(use: any, limit: number)
				return Gear.bulk(kind, use(tier), stat, use(level), use(wallet).cash, limit)
			end
			local function buyButton(name: string, limit: number, slot: number)
				local count = scope:Computed(function(use) return (bulk(use, limit)) end)
				local enabled = scope:Computed(function(use)
					return use(count) >= 1 and use(loaded) and use(busyId) == nil
				end)
				return UI.button(scope, {
					Name = name, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 66 - slot * 70, 0.5, 0), Size = UDim2.fromOffset(66, 44),
					Visible = scope:Computed(function(use) return not use(atCap) end),
					TextScaled = true, AutoButtonColor = enabled, Active = enabled, Selectable = enabled,
					Text = scope:Computed(function(use)
						local n, total, allowed, allowedTotal = bulk(use, limit)
						if allowed == 0 then
							return if Gear.price(kind, stat, use(level)) == nil then "MAX" else "EVOLVE"
						end
						local shown, cost = if n > 0 then n else allowed, if n > 0 then total else allowedTotal
						return "+" .. shown .. "\n" .. Format.cash(cost)
					end),
					TextColor3 = scope:Computed(function(use) return if use(enabled) then UI.OUTLINE else UI.HUD_MUTED end),
					BackgroundColor3 = scope:Computed(function(use) return if use(enabled) then UI.HUD_GOLD else UI.PANEL_DARK end),
					[Children] = { scope:New("UITextSizeConstraint")({ MinTextSize = 9, MaxTextSize = 14 }) },
					[OnEvent("Activated")] = function()
						if not Fusion.peek(enabled) then return end
						local wanted = Fusion.peek(count)
						purchase(id, settings.Names[stat] .. " upgraded.", function()
							local any = false
							for i = 1, wanted do
								if not ShopService:Upgrade(kind, stat) then break end
								-- Keep bulk purchases below the server request limit even on a local connection.
								if i < wanted then task.wait(.025) end
								any = true
							end
							return any
						end)
					end,
				})
			end
			rows[order] = scope:New("Frame")({
				Name = stat .. "Row", LayoutOrder = order, Size = UDim2.new(1, -4, 0, 54),
				BackgroundColor3 = UI.CARD, BorderSizePixel = 0,
				[Children] = {
					UI.corner(scope, 10),
					UI.label(scope, {
						Name = "StatName", Position = UDim2.fromOffset(10, 6), Size = UDim2.new(1, -156, 0, 20),
						Text = scope:Computed(function(use) return settings.Names[stat] .. "  LV " .. use(level) end),
						TextXAlignment = Enum.TextXAlignment.Left, TextScaled = true, TextStrokeTransparency = 1,
						[Children] = { scope:New("UITextSizeConstraint")({ MinTextSize = 11, MaxTextSize = 16 }) },
					}),
					UI.body(scope, {
						Name = "Effect", Position = UDim2.fromOffset(10, 30), Size = UDim2.new(1, -156, 0, 16),
						Text = scope:Computed(function(use)
							local lv = use(level)
							return statValue(kind, stat, lv) .. (if use(atCap) then "" else "  >  " .. statValue(kind, stat, lv + 1))
						end),
						TextXAlignment = Enum.TextXAlignment.Left, TextSize = 12, TextColor3 = UI.HUD_MINT, TextTruncate = Enum.TextTruncate.AtEnd,
					}),
					buyButton("Buy10", 10, 1), buyButton("Buy1", 1, 2),
					UI.body(scope, {
						Name = "CapStatus", AnchorPoint = Vector2.new(1, .5), Position = UDim2.new(1, -10, .5, 0), Size = UDim2.fromOffset(132, 44),
						Visible = atCap, TextSize = 12, TextColor3 = UI.HUD_MINT,
						Text = scope:Computed(function(use) return if use(tier) == #tiers then "MAX LEVEL" else "TIER CAP\nEvolve below" end),
					}),
				},
			})
		end

		local gateLevel = levelOf(kind, gate)
		local function evolveReady(use: any): boolean
			local e, s = use(evolution), use(playerState)
			return e ~= nil and e.ready and s ~= nil and s.level >= Levels.evolveLevel(e.tier)
		end
		local evolveEnabled = scope:Computed(function(use)
			local e = use(evolution)
			return e ~= nil and evolveReady(use) and Price.canAfford(use(wallet), e.cost, e.shards) and use(loaded) and use(busyId) == nil
		end)
		local evolveId = kind .. "_evolve"
		local banner = scope:New("Frame")({
			Name = "EvolveBanner", LayoutOrder = 100, Size = UDim2.new(1, -4, 0, 84),
			BackgroundColor3 = UI.PANEL_DARK, BorderSizePixel = 0,
			[Children] = {
				UI.corner(scope, 10),
				scope:New("UIStroke")({ Color = scope:Computed(function(use) return if use(evolveEnabled) then UI.HUD_GOLD else UI.HUD_BORDER end), Thickness = 1.5 }),
				UI.label(scope, {
					Name = "EvolveTitle", Position = UDim2.fromOffset(10, 4), Size = UDim2.new(1, -140, 0, 22),
					Text = scope:Computed(function(use)
						local e = use(evolution)
						return if e then "EVOLVE: " .. string.upper(tiers[e.tier].Name) else "FULLY EVOLVED"
					end),
					TextXAlignment = Enum.TextXAlignment.Left, TextScaled = true, TextStrokeTransparency = 1, TextColor3 = UI.HUD_GOLD,
					[Children] = { scope:New("UITextSizeConstraint")({ MinTextSize = 12, MaxTextSize = 18 }) },
				}),
				scope:New("Frame")({
					Name = "GateBar", Position = UDim2.fromOffset(10, 30), Size = UDim2.new(1, -140, 0, 8),
					BackgroundColor3 = UI.CARD, BorderSizePixel = 0,
					Visible = scope:Computed(function(use) return use(evolution) ~= nil end),
					[Children] = {
						UI.corner(scope, 4),
						scope:New("Frame")({
							Name = "Fill", BorderSizePixel = 0, BackgroundColor3 = UI.HUD_MINT,
							Size = scope:Computed(function(use) return UDim2.fromScale(math.clamp(use(gateLevel) / Gear.cap(use(tier)), 0, 1), 1) end),
							[Children] = { UI.corner(scope, 4) },
						}),
					},
				}),
				UI.body(scope, {
					Name = "Needs", Position = UDim2.fromOffset(10, 42), Size = UDim2.new(1, -140, 0, 38),
					TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, TextWrapped = true, TextSize = 12, RichText = true,
					Text = scope:Computed(function(use)
						local e, s = use(evolution), use(playerState)
						if not e then return "Nothing left to evolve." end
						local function chip(done: boolean, text: string): string
							return string.format('<font color="%s">%s</font>', if done then "#7EEBBE" else "#B7C2D0", text)
						end
						local needed = Levels.evolveLevel(e.tier)
						return chip(e.ready, settings.Names[gate] .. " " .. use(gateLevel) .. "/" .. Gear.cap(use(tier)))
							.. "   " .. chip(s ~= nil and s.level >= needed, "Player level " .. (if s then s.level else 1) .. "/" .. needed)
							.. "\n" .. priceText(e.cost, e.shards)
					end),
				}),
				UI.button(scope, {
					Name = "Evolve", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(112, 48),
					TextScaled = true, AutoButtonColor = evolveEnabled, Active = evolveEnabled, Selectable = evolveEnabled,
					Text = scope:Computed(function(use)
						local e = use(evolution)
						if not e then return "MAX" end
						if not evolveReady(use) then return "LOCKED" end
						return if Price.canAfford(use(wallet), e.cost, e.shards) then "EVOLVE" else "SAVE UP"
					end),
					TextColor3 = scope:Computed(function(use) return if use(evolveEnabled) then UI.OUTLINE else UI.HUD_MUTED end),
					BackgroundColor3 = scope:Computed(function(use) return if use(evolveEnabled) then UI.HUD_GOLD else UI.CARD end),
					[Children] = { scope:New("UITextSizeConstraint")({ MinTextSize = 12, MaxTextSize = 18 }) },
					[OnEvent("Activated")] = function()
						if Fusion.peek(evolveEnabled) then purchase(evolveId, "Evolved.", function() return ShopService:Evolve(kind) end) end
					end,
				}),
			},
		})

		local function previewWell(size: any)
			-- Each layout owns its viewport. Build only the currently equipped tier.
			local currentTier = scope:Computed(function(use) return { use(tier) } end)
			local previews = scope:ForValues(currentTier, function(_use: any, previewScope: Scope, index: number)
				return EquipmentPreview(previewScope, kind, index, { Size = UDim2.fromScale(1, 1) })
			end)
			return scope:New("Frame")({
				Name = "PreviewWell", BackgroundColor3 = UI.PANEL_DARK, BorderSizePixel = 0, Size = size,
				[Children] = { UI.corner(scope, 10), scope:New("UIStroke")({ Color = UI.HUD_BORDER, Transparency = 0.65 }), previews },
			})
		end
		local function heading()
			return {
				UI.label(scope, {
					Name = "GearName", LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 24), TextScaled = true, TextStrokeTransparency = 1,
					Text = scope:Computed(function(use) return tiers[use(tier)].Name end),
					[Children] = { scope:New("UITextSizeConstraint")({ MinTextSize = 13, MaxTextSize = 20 }) },
				}),
				UI.body(scope, {
					Name = "TierText", LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 18), TextSize = 12, TextColor3 = UI.HUD_GOLD,
					Text = scope:Computed(function(use) return "TIER " .. use(tier) .. " / " .. #tiers end),
				}),
			}
		end
		-- The preview used on wide panels sits left of the rows; on phones it heads the list
		local showcase = scope:New("Frame")({
			Name = "Showcase", BackgroundTransparency = 1, Size = UDim2.new(0, 196, 1, 0), Visible = scope:Computed(function(use) return not use(compact) end),
			[Children] = {
				previewWell(UDim2.new(1, 0, 1, -52)),
				scope:New("Frame")({
					Name = "Heading", BackgroundTransparency = 1, Position = UDim2.new(0, 0, 1, -48), Size = UDim2.new(1, 0, 0, 44),
					[Children] = { scope:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder }), heading() },
				}),
			},
		})
		local strip = scope:New("Frame")({
			Name = "NarrowHeader", LayoutOrder = 0, BackgroundTransparency = 1, Size = UDim2.new(1, -4, 0, 84), Visible = compact,
			[Children] = {
				previewWell(UDim2.fromOffset(84, 84)),
				scope:New("Frame")({
					Name = "Heading", BackgroundTransparency = 1, Position = UDim2.fromOffset(96, 20), Size = UDim2.new(1, -100, 0, 44),
					[Children] = { scope:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder }), heading() },
				}),
			},
		})
		local list = scope:New("ScrollingFrame")({
			Name = "Rows", BackgroundTransparency = 1, BorderSizePixel = 0,
			Position = scope:Computed(function(use) return if use(compact) then UDim2.fromOffset(0, 0) else UDim2.fromOffset(208, 0) end),
			Size = scope:Computed(function(use) return if use(compact) then UDim2.fromScale(1, 1) else UDim2.new(1, -208, 1, 0) end),
			CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y,
			ScrollBarThickness = 4, ScrollBarImageColor3 = UI.HUD_GOLD,
			[Children] = {
				scope:New("UIListLayout")({ Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
				strip, rows, banner,
			},
		})
		gearScreens[kind] = scope:New("Frame")({
			Name = kind .. "Screen", BackgroundTransparency = 1, Visible = scope:Computed(function(use) return use(tab) == kind end),
			Position = scope:Computed(function(use) local g = use(geometry) return UDim2.fromOffset(g.padding, g.carouselY) end),
			Size = scope:Computed(function(use) local g = use(geometry) return UDim2.fromOffset(g.panel.w - 2 * g.padding, g.carouselH) end),
			[Children] = { showcase, list },
		})
		return gearScreens[kind]
	end
	gearScreen("pickaxe")
	gearScreen("backpack")
	-- Pets: owned ones can be put out or away, the rest cost Core Shards (Shared.Pets)
	local petIcons = { miner = "equipment", hauler = "ore", pack = "backpack", swift = "chevron", merchant = "coin", yield = "ore", scholar = "crystal", crit = "equipment", vault = "foundry", shards = "crystal", sprint = "chevron" }
	local petGeometry = scope:Computed(function(use)
		local g = table.clone(use(geometry))
		g.pet = true
		g.cardHeight = if g.short then 310 else 410
		return g
	end)
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
		return string.format("%g%%", math.floor(value * 10000 + 0.5) / 100)
	end
	-- Eggs come first: hatch with Core Shards, odds shown on the card, pity counted
	local eggCount = #Config.Pets.Eggs
	for order, egg in Config.Pets.Eggs do
		local id = "egg_" .. egg.Id
		local pityLeft = scope:Computed(function(use)
			local s = use(playerState)
			return egg.Pity - (if s and s.pets and s.pets.hatches then s.pets.hatches[egg.Id] or 0 else 0)
		end)
		local oddsText = {}
		for _, rarityId in Config.Pets.RarityOrder do
			if egg.Odds[rarityId] then
				table.insert(oddsText, string.format('<font color="#%s">%s %g%%</font>', Config.Pets.Rarities[rarityId].Color:ToHex(), Config.Pets.Rarities[rarityId].Name, egg.Odds[rarityId]))
			end
		end
		petCards[order] = itemCard(scope, geometry, {
			Id = id, Order = order, Title = egg.Name, TitleName = "EggName",
			LevelText = "EGG  ·  " .. egg.Cost .. " SHARDS",
			State = "next",
			Cost = 0, Shards = egg.Cost,
			Wallet = wallet, Loaded = loaded, BusyId = busyId,
			ReadyText = "HATCH",
			PriceText = table.concat(oddsText, "  "),
			Preview = UI.hudIcon(scope, "crystal", {
				AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(0.55, 0.75), ImageColor3 = if egg.Id == "crystalEgg" then UI.SHARD else UI.HUD_GOLD,
			}),
			Stats = {
				statCell(scope, geometry, 1, 2, "COST", tostring(egg.Cost) .. " shards", UI.SHARD),
				statCell(scope, geometry, 2, 2, "GUARANTEED " .. string.upper(Config.Pets.Rarities[egg.PityFrom].Name) .. "+", scope:Computed(function(use) return "in " .. use(pityLeft) end), UI.HUD_MINT),
			},
			OnBuy = function() purchase(id, "", function() return PetService:Hatch(egg.Id) end) end,
		})
	end
	for order, def in Config.Pets.List do
		local entry, equipped = petEntry(def.Id), petEquipped(def.Id)
		local mainRole = def.Perks[1].Role
		local id = "pet_" .. def.Id
		-- A pass pet is bought with Robux through its game pass; Id 0 means not on sale yet
		local pass = if def.Pass then Config.Monetization.Passes[def.Pass] else nil
		local onSale = pass ~= nil and pass.Id ~= 0
		petCards[eggCount + order] = itemCard(scope, petGeometry, {
			Id = id, Order = eggCount + order, Title = def.Name, TitleName = "PetName",
			Accent = Config.Pets.Rarities[def.Rarity].Color,
			LevelText = string.upper(Config.Pets.Rarities[def.Rarity].Name) .. " PET",
			State = scope:Computed(function(use): RowState
				if use(equipped) then return "equipped" end
				return if use(entry) then "owned" else "next"
			end),
			Cost = 0, Shards = 0,
			Wallet = wallet, Loaded = loaded, BusyId = busyId,
			Enabled = scope:Computed(function(use)
				if use(entry) then return true end
				return pass ~= nil and onSale
			end),
			ButtonText = scope:Computed(function(use)
				if use(equipped) then return "PUT AWAY" end
				if use(entry) then return "EQUIP" end
				if pass then return if onSale then "GET FOR R$" .. (def.Robux or "") else "NOT ON SALE YET" end
				return "FROM EGGS"
			end),
			PriceText = scope:Computed(function(use)
				if use(entry) then return def.Blurb end
				if pass then return '<font color="#7EEBBE">R$ ' .. (def.Robux or 0) .. '</font>  fixed price' end
				return "Hatch it from a " .. (if def.Rarity == "common" or def.Rarity == "uncommon" then "Meteor" else "Meteor or Crystal") .. " Egg"
			end),
			ReadyText = "BUY",
			Preview = UI.hudIcon(scope, petIcons[mainRole] or "equipment", {
				AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(0.55, 0.75), ImageColor3 = def.Color,
			}),
			Stats = {
				UI.body(scope, {
					Name = "Perks", Size = UDim2.fromScale(1, 1), TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, TextWrapped = true, RichText = true,
					Text = scope:Computed(function(use)
						local e = use(entry)
						local lv = if e then e.level else 1
						local needed = Pets.xpToNext(lv)
						local lines = { string.format("LEVEL %d / %d%s", lv, Config.Pets.MaxLevel, if e and needed then "  ·  " .. Format.number(math.floor(e.xp)) .. "/" .. Format.number(needed) .. " XP" else "") }
						for _, perk in Pets.perksOf(def, lv) do
							local role = Config.Pets.Roles[perk.role]
							table.insert(lines, string.format('<font color="#%s">%s</font>: %s', Config.Pets.Rarities[def.Rarity].Color:ToHex(), role.Name, string.format(role.Text, percent(perk.value))))
						end
						return table.concat(lines, "\n\n")
					end),
				}),
			},
			OnBuy = function()
				if Fusion.peek(entry) == nil then
					if pass and onSale then game:GetService("MarketplaceService"):PromptGamePassPurchase(player, pass.Id) end
				elseif Fusion.peek(equipped) then
					purchase(id, def.Name .. " put away.", function() return PetService:Unequip(def.Id) end)
				else
					purchase(id, def.Name .. " is out.", function() return PetService:Equip(def.Id) end)
				end
			end,
		})
	end
	local carousels = { makeList("pets", petCards) }
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
			Visible = scope:Computed(function(use) local k = use(tab) return k == "pets" end),
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
					gearScreens.pickaxe, gearScreens.backpack, carousels, navButton("Previous", false, -1), navButton("Next", true, 1),
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
							local gearTab = kind == "pickaxe" or kind == "backpack"
							local count = if kind == "pets" then #petCards else 1
							local first = if gearTab then 1 else math.clamp(math.floor(use(positions[kind]) / (g.cardWidth + g.gap) + 0.5) + 1, 1, count)
							if kind == "pets" then
								local s = use(playerState)
								if s and s.pets then
									return string.format("%d/%d pets out. %d/%d\nRebirth cap 3; Extra Pet Slot +1", #s.pets.equipped, s.pets.slots, first, count)
								end
							end
							local s = use(playerState)
							local levelText = if s then string.format("Player level %d%s   ", s.level, if s.xpNeeded > 0 then string.format(" (%d / %d XP)", math.floor(s.xp), s.xpNeeded) else " (max)") else ""
							return if gearTab then levelText else levelText .. string.format("%d / %d", first, count)
						end),
					}),
				},
			}),
		},
	})
	player:SetAttribute("ShopOpen", Fusion.peek(open))
end

return ShopController
