--!strict
-- Native Fusion HUD: live values and actions, responsive to the actual viewport.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Phase = require(ReplicatedStorage.Shared.Phase)
local Rebirth = require(ReplicatedStorage.Shared.Rebirth)
local HudResources = require(ReplicatedStorage.Shared.HudResources)
local HudLayout = require(ReplicatedStorage.Shared.HudLayout)
local UI = require(script.Parent.UI)
local Children, OnEvent = Fusion.Children, Fusion.OnEvent
local player = Players.LocalPlayer
type Scope = UI.Scope
local HudView = {}
local WHITE, ORANGE, CYAN = UI.WHITE, Color3.fromRGB(255, 179, 92), Color3.fromRGB(123, 230, 239)

local function text(scope: Scope, name: string, value: any, x: number, y: number, w: number, h: number, size: any, color: any?, bold: boolean?, floating: boolean?)
	return UI.hudText(scope, {
		Name = name, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h), Text = value,
		Font = if bold then Enum.Font.GothamBold else Enum.Font.GothamMedium,
		TextSize = size, TextColor3 = color or WHITE, TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextStrokeColor3 = Color3.fromRGB(17, 24, 28), TextStrokeTransparency = if floating then 0.4 else 1,
	})
end
local function meter(scope: Scope, name: string, x: number, y: number, w: number, fill: any, color: any, height: number?)
	local animated = scope:Spring(fill, 25, 1)
	return scope:New("Frame")({
		Name = name, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, height or 4),
		BackgroundColor3 = UI.HUD_BORDER, BorderSizePixel = 0,
		[Children] = { UI.corner(scope, 3), scope:New("Frame")({
			Name = "Fill", Size = scope:Computed(function(use) return UDim2.fromScale(math.clamp(use(animated), 0, 1), 1) end),
			BackgroundColor3 = color, BorderSizePixel = 0, [Children] = { UI.corner(scope, 3) },
		}) },
	})
end
local function frame(scope: Scope, hud: any, name: string, baseWidth: number, rectFor: (any) -> any, children: { any }, clear: boolean?)
	return scope:New("Frame")({
		Name = name, BorderSizePixel = 0, BackgroundColor3 = UI.HUD_SURFACE,
		BackgroundTransparency = if clear then 1 else 0.06,
		Position = scope:Computed(function(use) local r = rectFor(use(hud)); return UDim2.fromOffset(r.x, r.y) end),
		Size = scope:Computed(function(use) local r = rectFor(use(hud)); return UDim2.fromOffset(baseWidth, r.h / (r.w / baseWidth)) end),
		[Children] = {
			scope:New("UIScale")({ Scale = scope:Computed(function(use) return rectFor(use(hud)).w / baseWidth end) }),
			if clear then nil else UI.hudFill(scope), children,
		},
	})
end
local function flag(scope: Scope, name: string, default: boolean)
	local function read() return if player:GetAttribute(name) == nil then default else player:GetAttribute(name) == true end
	local value = scope:Value(read())
	table.insert(scope, player:GetAttributeChangedSignal(name):Connect(function() value:set(read()) end))
	return value
end
local function font(scope: Scope, hud: any, baseWidth: number, rectFor: (any) -> any, size: number, minimum: number)
	return scope:Computed(function(use) return math.max(size, minimum / (rectFor(use(hud)).w / baseWidth)) end)
end

local function barViews(scope: Scope, rows: any, scale: any)
	local ids = scope:Computed(function(use) local result = {}; for i, row in use(rows) do result[i] = row.id end; return result end)
	return scope:ForPairs(ids, function(_use: any, rowScope: Scope, index: number, id: string)
		local row = rowScope:Computed(function(use)
			for _, entry in use(rows) do if entry.id == id then return entry end end
			return { name = id, amount = 0, value = 0 }
		end)
		local function rowFont(size: number) return rowScope:Computed(function(use) return math.max(size, 11 / use(scale)) end) end
		local tint = if id == "frost" then CYAN elseif id == "crystal" then Color3.fromRGB(221, 161, 255) else UI.HUD_GOLD
		return index, rowScope:New("Frame")({
			Name = id .. "Bars", LayoutOrder = index, Size = UDim2.new(1, -4, 0, 30), BackgroundTransparency = 1,
			[Children] = {
				UI.hudIcon(rowScope, "barStack", { Position = UDim2.fromOffset(0, 5), Size = UDim2.fromOffset(24, 24), ImageColor3 = tint }),
				text(rowScope, "Type", rowScope:Computed(function(use) return use(row).name end), 34, 5, 150, 24, rowFont(15), tint, true),
				text(rowScope, "Amount", rowScope:Computed(function(use) return Format.number(use(row).amount) end), 194, 5, 68, 24, rowFont(15), WHITE, true),
				text(rowScope, "Value", rowScope:Computed(function(use) return Format.cash(use(row).value) end), 272, 5, 96, 24, rowFont(14), UI.HUD_MINT),
			},
		})
	end)
end

function HudView.main(scope: Scope, hud: any, data: { [string]: any })
	local function state(use: any) return use(data.playerState) end
	local function value(field: string)
		return scope:Computed(function(use) local s = state(use); return Format.number(if s then s[field] or 0 else 0) end)
	end
	local bars, shards = value("bars"), value("shards")
	local carried = scope:Computed(function(use) local s = state(use); return if s then s.carried else 0 end)
	local capacity = scope:Computed(function(use) local s = state(use); return if s then s.capacity else 50 end)
	local full = scope:Computed(function(use) return use(carried) >= use(capacity) end)
	local expanded = flag(scope, "FoundryExpanded", false)
	local function toggle()
		player:SetAttribute("BackpackOpen", false)
		player:SetAttribute("RefineryOpen", false)
		player:SetAttribute("FoundryExpanded", not Fusion.peek(expanded))
	end
	local function lineText(id: string)
		return scope:Computed(function(use)
			local s = state(use); local line = s and s.line and s.line[id]
			return if line then Format.number(line.amount) .. "/" .. Format.number(line.capacity) else "0/2K"
		end)
	end
	local function lineRatio(id: string)
		return scope:Computed(function(use)
			local s = state(use); local line = s and s.line and s.line[id]
			return if line then line.amount / math.max(line.capacity, 1) else 0
		end)
	end
	local function productionFont(size: number, minimum: number)
		return font(scope, hud, 400, function(l) return l.leftCards.Production end, size, minimum)
	end
	local glow = scope:Computed(function(use)
		local s = use(data.meteorState); local kind = s and Config.Meteor.Types[s.type]
		return if kind then kind.GlowColor:Lerp(WHITE, 0.2) else ORANGE
	end)
	local barRows = scope:Computed(function(use) return HudResources.bars(state(use)) end)
	local productionScale = scope:Computed(function(use) return use(hud).leftCards.Production.w / 400 end)
	local rowViews = barViews(scope, barRows, productionScale)
	local canSell = scope:Computed(function(use)
		local s = state(use)
		return s ~= nil and s.bars > 0 and not use(data.saleBusy)
	end)
	local saleHeight = scope:Computed(function(use) return HudLayout.closeSize(44, use(productionScale)) end)
	local summary = scope:New("Frame")({
		Name = "Summary", AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.fromOffset(400, 82), BackgroundTransparency = 1,
		[Children] = {
			UI.hudIcon(scope, "foundry", { Position = UDim2.fromOffset(0, 18), Size = UDim2.fromOffset(58, 58) }),
			text(scope, "ProductionLabel", scope:Computed(function(use) return if use(hud).leftCards.Production.w / 400 < 0.75 then "RATE:" else "PRODUCTION:" end), 70, 5, 105, 22, productionFont(14, 10), WHITE, true, true),
			text(scope, "ProductionRate", scope:Computed(function(use) local s = state(use); return (if s and s.line then Format.number(s.line.rate) else "0") .. "/s" end), 176, 5, 79, 22, productionFont(15, 11), UI.HUD_MINT, true, true),
			UI.hudIcon(scope, "ore", { Position = UDim2.fromOffset(70, 32), Size = UDim2.fromOffset(21, 21) }),
			text(scope, "HopperAmount", lineText("hopper"), 98, 30, 113, 25, productionFont(14, 11), WHITE, true, true),
			UI.hudIcon(scope, "bars", { Position = UDim2.fromOffset(70, 57), Size = UDim2.fromOffset(21, 21) }),
			text(scope, "CollectorAmount", lineText("collector"), 98, 55, 113, 25, productionFont(14, 11), WHITE, true, true),
			UI.hudIcon(scope, "bars", { Position = UDim2.fromOffset(220, 23), Size = UDim2.fromOffset(55, 55) }),
			text(scope, "CarriedBars", scope:Computed(function(use) return "Bars: " .. use(bars) end), 286, 28, 87, 23, productionFont(14, 11), WHITE, true, true),
			text(scope, "SaleValue", scope:Computed(function(use) local s = state(use); return Format.cash(if s then s.barValue else 0) end), 286, 53, 87, 23, productionFont(14, 11), UI.HUD_MINT, true, true),
			scope:New("TextButton")({
				Name = "ToggleFoundry", Size = UDim2.fromScale(1, 1), Text = "", BackgroundTransparency = 1, ZIndex = 2,
				[OnEvent("Activated")] = toggle,
				[Children] = {
					UI.hudIcon(scope, "chevron", { Position = UDim2.fromOffset(375, 29), Size = UDim2.fromOffset(24, 24),
						Rotation = scope:Computed(function(use) return if use(expanded) then 180 else 0 end) }),
					scope:New("TextButton")({ Name = "OpenRefinery", Size = scope:Computed(function(use) return UDim2.new(0, HudLayout.closeSize(64, use(productionScale)), 1, 0) end),
						Text = "", BackgroundTransparency = 1, ZIndex = 3, [OnEvent("Activated")] = function() data.openRefinery() end }),
				},
			}),
		},
	})
	local details = scope:New("Frame")({
		Name = "ExpandedDetails", Size = UDim2.fromOffset(400, 240), BackgroundColor3 = UI.HUD_SURFACE, BorderSizePixel = 0, Visible = expanded, Active = true,
		[Children] = {
			UI.hudFill(scope), text(scope, "Title", "FOUNDRY", 14, 10, 290, 28, productionFont(18, 13), WHITE, true),
			scope:New("ImageButton")({ Name = "CloseDetails", AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0),
				Size = scope:Computed(function(use) local target = HudLayout.closeSize(56, use(hud).leftCards.Production.w / 400); return UDim2.fromOffset(target, target) end),
				Image = "", BackgroundTransparency = 1, [OnEvent("Activated")] = toggle,
				[Children] = { UI.hudIcon(scope, "close", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(20, 20) }) } }),
			text(scope, "HopperLabel", "HOPPER", 14, 48, 90, 20, productionFont(12, 10), UI.HUD_MUTED),
			text(scope, "HopperCapacity", lineText("hopper"), 108, 46, 88, 24, productionFont(14, 11), WHITE, true),
			meter(scope, "HopperMeter", 14, 76, 176, lineRatio("hopper"), ORANGE, 5),
			text(scope, "StorageLabel", "STORAGE", 210, 48, 94, 20, productionFont(12, 10), UI.HUD_MUTED),
			text(scope, "StorageCapacity", lineText("collector"), 310, 46, 76, 24, productionFont(14, 11), WHITE, true),
			meter(scope, "StorageMeter", 210, 76, 176, lineRatio("collector"), UI.HUD_GOLD, 5),
			text(scope, "BarsLabel", "CARRIED BARS", 14, 91, 196, 20, productionFont(12, 10), UI.HUD_MUTED),
			text(scope, "ValueLabel", "SALE VALUE", 280, 91, 110, 20, productionFont(12, 10), UI.HUD_MUTED),
			scope:New("ScrollingFrame")({
				Name = "BarInventory", Position = UDim2.fromOffset(14, 116),
				Size = scope:Computed(function(use) return UDim2.fromOffset(376, math.max(24, 108 - use(saleHeight))) end),
				BackgroundTransparency = 1, BorderSizePixel = 0, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
				ScrollBarThickness = 3, ScrollBarImageColor3 = UI.HUD_MUTED, ScrollingDirection = Enum.ScrollingDirection.Y,
				[Children] = { scope:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder }), rowViews },
			}),
			scope:New("TextButton")({
				Name = "SellAllBars", AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromOffset(14, 236),
				Size = scope:Computed(function(use) return UDim2.fromOffset(372, use(saleHeight)) end),
				BorderSizePixel = 0, Font = Enum.Font.GothamBold, TextSize = productionFont(15, 12),
				Text = scope:Computed(function(use)
					if use(data.saleBusy) then return "SELLING..." end
					local s = state(use)
					if not s then return "LOADING BARS..." end
					if s.bars <= 0 then return "NO BARS TO SELL" end
					return "SELL ALL · " .. Format.cash(s.barValue)
				end),
				BackgroundColor3 = scope:Computed(function(use) return if use(canSell) then UI.HUD_MINT else UI.HUD_BORDER end),
				TextColor3 = scope:Computed(function(use) return if use(canSell) then UI.HUD_SURFACE else UI.HUD_MUTED end),
				AutoButtonColor = canSell, Selectable = canSell, Active = canSell,
				[OnEvent("Activated")] = function() if Fusion.peek(canSell) then data.sellBars() end end,
				[Children] = { UI.corner(scope, 7) },
			}),
		},
	})
	return {
		frame(scope, hud, "Resources", 250, function(l) return l.leftCards.Resources end, {
			UI.hudIcon(scope, "crystal", { Position = UDim2.fromOffset(4, 4), Size = UDim2.fromOffset(39, 39) }),
			text(scope, "Shards", shards, 56, 1, 190, 46, 37, WHITE, true, true),
			UI.hudIcon(scope, "coin", { Position = UDim2.fromOffset(0, 62), Size = UDim2.fromOffset(48, 48) }),
			text(scope, "Cash", scope:Computed(function(use) return Format.cash(use(data.cashShown)) end), 57, 53, 189, 48, 45, WHITE, true, true),
			text(scope, "Multiplier", scope:Computed(function(use)
				local s = state(use); local m = Rebirth.multiplier(if s then s.rebirths else 0)
				return if m > 1 then "×" .. Format.number(m) .. " sales" else ""
			end), 60, 101, 185, 15, 12, UI.HUD_MINT, false, true),
		}, true),
		frame(scope, hud, "Production", 400, function(l) return l.leftCards.Production end, { details, summary }, true),
		frame(scope, hud, "Backpack", 230, function(l) return l.backpack end, {
			UI.hudIcon(scope, "backpack", { Position = UDim2.fromOffset(0, 6), Size = UDim2.fromOffset(61, 68) }),
			text(scope, "Capacity", scope:Computed(function(use) return Format.number(use(carried)) .. " / " .. Format.number(use(capacity)) end), 76, 15, 152, 49, 40,
				scope:Computed(function(use) return if use(full) then UI.RED else WHITE end), true, true),
			meter(scope, "CapacityMeter", 77, 70, 148, scope:Computed(function(use) return use(carried) / math.max(use(capacity), 1) end),
				scope:Computed(function(use) return if use(full) then UI.RED else CYAN end), 5),
			scope:New("TextButton")({
				Name = "OpenBackpack", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", ZIndex = 2,
				[OnEvent("Activated")] = function()
					local opened = player:GetAttribute("BackpackOpen") == true
					player:SetAttribute("FoundryExpanded", false)
					player:SetAttribute("BackpackOpen", not opened)
				end,
			}),
		}, true),
		frame(scope, hud, "Timer", 593, function(l) return l.timer end, {
			meter(scope, "RemainingTime", 0, 0, 593, data.timeProgress, glow, 6),
			UI.hudIcon(scope, "meteor", { Position = UDim2.fromOffset(0, 26), Size = UDim2.fromOffset(74, 74) }),
			text(scope, "MeteorName", scope:Computed(function(use) local s = use(data.meteorState); return if s then string.upper(s.typeName) else "METEOR MINING" end), 82, 18, 316, 30, font(scope, hud, 593, function(l) return l.timer end, 24, 10), glow, true, true),
			text(scope, "Phase", scope:Computed(function(use)
				local p = use(data.phase)
				if p == Phase.Countdown then return "Incoming meteor" end
				if p == Phase.Impact then return "Impact!" end
				if p == Phase.Active then return "Cooling down" end
				if p == Phase.CoreCracked then return "Core cracked!" end
				if p == Phase.Cooled then return "Meteor cooled" end
				return "Next meteor soon"
			end), 82, 54, 312, 49, 36, WHITE, true, true),
			text(scope, "Time", data.timerText, 405, 19, 188, 86, 64, scope:Computed(function(use) local color = use(data.timerColor); return if color ~= UI.WHITE then color else use(glow) end), true, true),
		}, true),
	}
end

function HudView.backpack(scope: Scope, hud: any, playerState: any)
	local opened = flag(scope, "BackpackOpen", false)
	local function close() player:SetAttribute("BackpackOpen", false) end
	local rows = scope:Computed(function(use) return HudResources.ores(use(playerState)) end)
	local rect = scope:Computed(function(use) return HudLayout.backpackPanel(use(hud), #use(rows)) end)
	local scrolling = scope:Computed(function(use) return #use(rows) * 28 > use(rect).h - 44 end)
	local wide = scope:Computed(function(use) return use(rect).w >= 150 end)
	local ids = scope:Computed(function(use) local result = {}; for i, row in use(rows) do result[i] = row.id end; return result end)
	local rowViews = scope:ForPairs(ids, function(_use: any, rowScope: Scope, index: number, id: string)
		local row = rowScope:Computed(function(use)
			for _, entry in use(rows) do if entry.id == id then return entry end end
			return { name = id, amount = 0 }
		end)
		local tint = if id == "frost" then CYAN elseif id == "crystal" then Color3.fromRGB(221, 161, 255) else UI.HUD_GOLD
		return index, rowScope:New("Frame")({
			Name = id .. "Ore", LayoutOrder = index, Size = UDim2.new(1, -4, 0, 28), BackgroundTransparency = 1,
			[Children] = {
				UI.hudIcon(rowScope, "ore", { Position = UDim2.fromOffset(0, 4), Size = UDim2.fromOffset(20, 20), ImageColor3 = tint, Visible = wide }),
				UI.hudText(rowScope, {
					Name = "Type", Position = rowScope:Computed(function(use) return UDim2.fromOffset(if use(wide) then 26 else 0, 2) end),
					Size = rowScope:Computed(function(use) return UDim2.new(1, -(if use(wide) then 76 else 38), 0, 24) end),
					Text = rowScope:Computed(function(use) return use(row).name end), Font = Enum.Font.GothamBold,
					TextSize = rowScope:Computed(function(use) return if use(wide) then 14 else 12 end),
					TextColor3 = tint, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
				}),
				UI.hudText(rowScope, {
					Name = "Amount", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -4, 0, 2),
					Size = rowScope:Computed(function(use) return UDim2.fromOffset(if use(wide) then 44 else 32, 24) end),
					Text = rowScope:Computed(function(use) return Format.number(use(row).amount) end), Font = Enum.Font.GothamBold,
					TextSize = rowScope:Computed(function(use) return if use(wide) then 16 else 12 end),
					TextColor3 = WHITE, TextXAlignment = Enum.TextXAlignment.Right,
				}),
			},
		})
	end)
	table.insert(scope, UserInputService.InputBegan:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB then close() end
	end))
	for _, name in { "ShopOpen", "IndexOpen", "RebirthOpen", "StoreOpen", "SettingsOpen", "RefineryOpen" } do
		table.insert(scope, player:GetAttributeChangedSignal(name):Connect(function()
			if player:GetAttribute(name) == true then close() end
		end))
	end
	return scope:New("ScreenGui")({
		Name = "BackpackMenu", ResetOnSpawn = false, IgnoreGuiInset = true,
		DisplayOrder = 9, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Enabled = opened, Parent = player.PlayerGui,
		[Children] = {
			scope:New("Frame")({
				Name = "Panel", Position = scope:Computed(function(use) local r = use(rect); return UDim2.fromOffset(r.x, r.y) end),
				Size = scope:Computed(function(use) local r = use(rect); return UDim2.fromOffset(r.w, r.h) end),
				BackgroundColor3 = UI.HUD_SURFACE, Active = false, ZIndex = 2,
				[Children] = {
					UI.hudFill(scope),
					UI.hudText(scope, { Name = "Title", Position = UDim2.fromOffset(8, 6), Size = UDim2.new(1, -52, 0, 28),
						Text = scope:Computed(function(use) return if use(wide) then "BACKPACK" else "BAG" end),
						Font = Enum.Font.GothamBold, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left }),
					scope:New("ImageButton")({ Name = "Close", AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0),
						Size = UDim2.fromOffset(44, 44),
						Image = "", BackgroundTransparency = 1, [OnEvent("Activated")] = close,
						[Children] = { UI.hudIcon(scope, "close", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(20, 20) }) } }),
					scope:New("ScrollingFrame")({
						Name = "OreInventory", Position = UDim2.fromOffset(8, 40), Size = UDim2.new(1, -16, 1, -44),
						Active = scrolling, ScrollingEnabled = scrolling,
						BackgroundTransparency = 1, BorderSizePixel = 0, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
						ScrollBarThickness = 3, ScrollBarImageColor3 = UI.HUD_MUTED, ScrollingDirection = Enum.ScrollingDirection.Y,
						[Children] = { scope:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder }), rowViews },
					}),
					UI.hudText(scope, { Name = "Empty", Position = UDim2.fromOffset(8, 40), Size = UDim2.new(1, -16, 0, 28),
						Text = "Empty", TextSize = 14, TextColor3 = UI.HUD_MUTED,
						Visible = scope:Computed(function(use) return #use(rows) == 0 end) }),
				},
			}),
		},
	})
end

function HudView.objective(scope: Scope, hud: any, data: { [string]: any })
	local tips = flag(scope, "HudShowEventTips", true)
	local function eventFont(size: number, minimum: number) return font(scope, hud, 284, function(l) return l.eventPanel end, size, minimum) end
	local progress = scope:Computed(function(use)
		local s = use(data.meteorState)
		if s and not s.unlocked then return s.crustBroken / math.max(math.ceil(s.crustTotal * Config.Meteor.CoreUnlockFraction), 1) end
		return use(data.coreHp) / math.max(use(data.coreMaxHp), 1)
	end)
	local card = frame(scope, hud, "EventPanel", 284, function(l) return l.eventPanel end, {
		UI.hudIcon(scope, "meteor", { Position = UDim2.fromOffset(16, 14), Size = UDim2.fromOffset(27, 27) }),
		text(scope, "Title", scope:Computed(function(use) local s = use(data.meteorState); return if s and s.unlocked then "STRIKE THE CORE" else "BREAK THE CRUST" end), 52, 19, 216, 22, eventFont(12, 10), ORANGE, true),
		text(scope, "Objective", scope:Computed(function(use)
			local s, rank = use(data.meteorState), use(data.standing)
			if s and s.unlocked then return "Strike the exposed core!" end
			return if not rank or rank.rank == 0 then "Mine a node to join in" else "Break crust to expose core"
		end), 16, 53, 252, 29, eventFont(19, 12), WHITE, true),
		text(scope, "Progress", scope:Computed(function(use)
			local s = use(data.meteorState)
			if s and not s.unlocked then return "NODES BROKEN  " .. s.crustBroken .. " / " .. math.ceil(s.crustTotal * Config.Meteor.CoreUnlockFraction) end
			return "CORE STRENGTH  " .. math.ceil(math.clamp(use(progress), 0, 1) * 100) .. "%"
		end), 16, 93, 252, 23, eventFont(13, 10), UI.HUD_MUTED),
		meter(scope, "ProgressMeter", 16, 122, 252, progress, ORANGE),
		text(scope, "Standing", scope:Computed(function(use)
			local rank = use(data.standing)
			if not rank or rank.rank == 0 then return "First hit joins the event." end
			return "You: #" .. rank.rank .. " / " .. rank.players .. " · " .. Format.number(rank.ore) .. " ore"
		end), 16, 138, 252, 22, eventFont(12, 10), UI.HUD_MINT),
	})
	scope:Hydrate(card)({ Visible = scope:Computed(function(use) return use(data.inEvent) and use(tips) and use(hud).eventVisible end) })
	return card
end

function HudView.settings(scope: Scope, hud: any)
	local opened, guide, tips = scope:Value(false), flag(scope, "HudShowGuide", true), flag(scope, "HudShowEventTips", true)
	scope:Observer(opened):onChange(function() player:SetAttribute("SettingsOpen", Fusion.peek(opened)) end)
	player:SetAttribute("SettingsOpen", false)
	local fit = scope:Computed(function(use) local l = use(hud); local p = HudLayout.panel(l.viewport, 360, 220, l.inset); p.scale = math.min(p.scale, (l.viewport.X - 24) / 360); return p end)
	local toggles = {}
	for i, item in { { "HudShowGuide", "Training guide", guide }, { "HudShowEventTips", "Meteor objective", tips } } do
		table.insert(toggles, scope:New("TextButton")({
			Name = item[1], Position = scope:Computed(function(use) local height = HudLayout.closeSize(48, use(fit).scale); return UDim2.fromOffset(16, 64 + (i - 1) * (height + 10)) end),
			Size = scope:Computed(function(use) return UDim2.fromOffset(328, HudLayout.closeSize(48, use(fit).scale)) end),
			Text = "", BackgroundColor3 = Color3.fromRGB(36, 43, 49), BorderSizePixel = 0,
			[OnEvent("Activated")] = function() player:SetAttribute(item[1], not Fusion.peek(item[3])) end,
			[Children] = { UI.corner(scope, 7),
				text(scope, "Label", item[2], 12, 10, 228, 28, 17, WHITE, true),
				text(scope, "State", scope:Computed(function(use) return if use(item[3]) then "ON" else "OFF" end), 260, 10, 58, 28, 17, UI.HUD_MINT, true),
			},
		}))
	end
	return {
		frame(scope, hud, "Settings", 44, function(l) return l.settings end, {
			scope:New("ImageButton")({ Name = "OpenSettings", Size = UDim2.fromScale(1, 1), BackgroundColor3 = UI.HUD_SURFACE, Image = "", BorderSizePixel = 0,
				[OnEvent("Activated")] = function() opened:set(not Fusion.peek(opened)) end,
				[Children] = { UI.hudFill(scope), UI.hudIcon(scope, "settings", { Position = UDim2.fromOffset(10, 10), Size = UDim2.fromOffset(24, 24) }) } }),
		}, true),
		scope:New("Frame")({
			Name = "SettingsPanel", AnchorPoint = Vector2.new(0.5, 0.5), Position = scope:Computed(function(use) local l = use(hud); return UDim2.new(0.5, 0, 0.5, l.inset / 2) end),
			Size = UDim2.fromOffset(360, 220), BackgroundColor3 = UI.HUD_SURFACE, Visible = opened, ZIndex = 5, Active = true,
			[Children] = { UI.hudFill(scope), scope:New("UIScale")({ Scale = scope:Computed(function(use) return use(fit).scale end) }),
				text(scope, "Title", "HUD SETTINGS", 16, 14, 268, 32, 22, WHITE, true),
				scope:New("ImageButton")({ Name = "Close", AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = scope:Computed(function(use) local target = HudLayout.closeSize(48, use(fit).scale); return UDim2.fromOffset(target, target) end), BackgroundTransparency = 1, Image = "",
					[OnEvent("Activated")] = function() opened:set(false) end,
					[Children] = { UI.hudIcon(scope, "close", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(20, 20) }) } }),
				toggles, text(scope, "Hint", "Preferences apply during this session.", 16, 185, 328, 24, 13, UI.HUD_MUTED),
			},
		}),
	}
end
return HudView
