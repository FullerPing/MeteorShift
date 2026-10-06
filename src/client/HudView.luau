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
		Font = if bold then UI.FONT else UI.BODY_FONT,
		TextSize = size, TextColor3 = color or WHITE, TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextStrokeColor3 = UI.OUTLINE, TextStrokeTransparency = if bold then 0.15 else 0.4,
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
		Visible = scope:Computed(function(use)
			local layout = use(hud)
			if name == "Resources" then return layout.resourcesVisible end
			if name == "Backpack" then return layout.backpackVisible end
			if name == "Timer" then return layout.timerVisible end
			return true
		end),
		BackgroundTransparency = if clear then 1 else 0,
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
				text(rowScope, "Type", rowScope:Computed(function(use) return use(row).name end), 34, 5, 224, 24, rowFont(17), tint, true),
				text(rowScope, "Amount", rowScope:Computed(function(use) return Format.number(use(row).amount) end), 284, 5, 88, 24, rowFont(17), WHITE, true),
				text(rowScope, "Value", rowScope:Computed(function(use) return Format.cash(use(row).value) end), 400, 5, 112, 24, rowFont(17), WHITE, true),
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
		return font(scope, hud, 550, function(l) return l.leftCards.Production end, size, minimum)
	end
	local glow = scope:Computed(function(use)
		local s = use(data.meteorState); local kind = s and Config.Meteor.Types[s.type]
		return if kind then kind.GlowColor:Lerp(WHITE, 0.2) else ORANGE
	end)
	local barRows = scope:Computed(function(use) return HudResources.bars(state(use)) end)
	local productionScale = scope:Computed(function(use) return use(hud).leftCards.Production.w / 550 end)
	local rowViews = barViews(scope, barRows, productionScale)
	local canSell = scope:Computed(function(use)
		local s = state(use)
		return s ~= nil and s.bars > 0 and not use(data.saleBusy)
	end)
	local saleHeight = scope:Computed(function(use) return HudLayout.closeSize(44, use(productionScale)) end)
	local saleText = scope:Computed(function(use)
		if use(data.saleBusy) then return "SELLING..." end
		local s = state(use)
		if not s then return "LOADING BARS..." end
		if s.bars <= 0 then return "NO BARS TO SELL" end
		return "SELL ALL · " .. Format.cash(s.barValue)
	end)
	local summary = scope:New("Frame")({
		Name = "Summary", AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.fromOffset(550, 116), BackgroundTransparency = 1,
		[Children] = {
			UI.hudIcon(scope, "foundry", { Position = UDim2.fromOffset(20, 36), Size = UDim2.fromOffset(62, 68) }),
			text(scope, "ProductionLabel", "PRODUCTION", 100, 12, 148, 27, productionFont(19, 12), WHITE, true, true),
			text(scope, "ProductionRate", scope:Computed(function(use) local s = state(use); return (if s and s.line then Format.number(s.line.rate) else "0") .. "/s" end), 352, 8, 125, 32, productionFont(28, 14), WHITE, true, true),
			scope:New("Frame")({ Name = "Divider", Position = UDim2.fromOffset(262, 14), Size = UDim2.fromOffset(2, 88), BackgroundColor3 = UI.OUTLINE, BackgroundTransparency = 0.7, BorderSizePixel = 0 }),
			UI.hudIcon(scope, "ore", { Position = UDim2.fromOffset(101, 49), Size = UDim2.fromOffset(26, 26) }),
			text(scope, "HopperAmount", lineText("hopper"), 136, 45, 118, 30, productionFont(21, 12), WHITE, true, true),
			UI.hudIcon(scope, "bars", { Position = UDim2.fromOffset(101, 83), Size = UDim2.fromOffset(26, 26) }),
			text(scope, "CollectorAmount", lineText("collector"), 136, 79, 118, 30, productionFont(21, 12), WHITE, true, true),
			UI.hudIcon(scope, "bars", { Position = UDim2.fromOffset(283, 52), Size = UDim2.fromOffset(60, 60) }),
			text(scope, "CarriedBars", scope:Computed(function(use) return "Bars: " .. use(bars) end), 352, 46, 130, 29, productionFont(21, 12), WHITE, true, true),
			text(scope, "SaleValue", scope:Computed(function(use) local s = state(use); return Format.cash(if s then s.barValue else 0) end), 352, 77, 130, 31, productionFont(25, 12), WHITE, true, true),
			scope:New("TextButton")({
				Name = "ToggleFoundry", Size = UDim2.fromScale(1, 1), Text = "", BackgroundTransparency = 1, ZIndex = 2,
				[OnEvent("Activated")] = toggle,
				[Children] = {
					scope:New("Frame")({ Name = "ExpandFace", Position = UDim2.fromOffset(496, 31), Size = UDim2.fromOffset(44, 60), BackgroundColor3 = UI.HUD_SURFACE, BorderSizePixel = 0,
						[Children] = { UI.corner(scope, 4), scope:New("UIStroke")({ Color = WHITE, Transparency = 0.5, Thickness = 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }) } }),
					UI.hudIcon(scope, "chevron", { Position = UDim2.fromOffset(502, 44), Size = UDim2.fromOffset(32, 32),
						Rotation = scope:Computed(function(use) return if use(expanded) then 180 else 0 end) }),
					scope:New("TextButton")({ Name = "OpenRefinery", Size = scope:Computed(function(use) return UDim2.new(0, HudLayout.closeSize(90, use(productionScale)), 1, 0) end),
						Text = "", BackgroundTransparency = 1, ZIndex = 3, [OnEvent("Activated")] = function() data.openRefinery() end }),
				},
			}),
		},
	})
	local details = scope:New("ScrollingFrame")({
		Name = "ExpandedDetails", Size = scope:Computed(function(use)
			return UDim2.fromOffset(550, math.max(0, use(hud).leftCards.Production.h / use(productionScale) - 116))
		end), BackgroundColor3 = UI.HUD_SURFACE, BorderSizePixel = 0, Visible = expanded, Active = true,
		CanvasSize = UDim2.fromOffset(550, 240), ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 3, ScrollBarImageColor3 = UI.HUD_MUTED,
		[Children] = {
			UI.hudFill(scope), text(scope, "Title", "FOUNDRY", 14, 10, 290, 28, productionFont(18, 13), WHITE, true),
			scope:New("ImageButton")({ Name = "CloseDetails", AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0),
				Size = scope:Computed(function(use) local target = HudLayout.closeSize(56, use(productionScale)); return UDim2.fromOffset(target, target) end),
				Image = "", BackgroundTransparency = 1, [OnEvent("Activated")] = toggle,
				[Children] = { UI.hudIcon(scope, "close", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(20, 20) }) } }),
			text(scope, "HopperLabel", "HOPPER", 14, 48, 90, 20, productionFont(12, 10), UI.HUD_MUTED),
			text(scope, "HopperCapacity", lineText("hopper"), 120, 46, 126, 24, productionFont(16, 11), WHITE, true),
			meter(scope, "HopperMeter", 14, 76, 238, lineRatio("hopper"), ORANGE, 5),
			text(scope, "StorageLabel", "STORAGE", 286, 48, 100, 20, productionFont(12, 10), UI.HUD_MUTED),
			text(scope, "StorageCapacity", lineText("collector"), 408, 46, 124, 24, productionFont(16, 11), WHITE, true),
			meter(scope, "StorageMeter", 286, 76, 238, lineRatio("collector"), UI.HUD_GOLD, 5),
			text(scope, "BarsLabel", "CARRIED BARS", 14, 91, 196, 20, productionFont(12, 10), UI.HUD_MUTED),
			text(scope, "ValueLabel", "SALE VALUE", 410, 91, 124, 20, productionFont(12, 10), UI.HUD_MUTED),
			scope:New("ScrollingFrame")({
				Name = "BarInventory", Position = UDim2.fromOffset(14, 116),
				Size = scope:Computed(function(use) return UDim2.fromOffset(522, math.max(24, 108 - use(saleHeight))) end),
				BackgroundTransparency = 1, BorderSizePixel = 0, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
				ScrollBarThickness = 3, ScrollBarImageColor3 = UI.HUD_MUTED, ScrollingDirection = Enum.ScrollingDirection.Y,
				[Children] = { scope:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder }), rowViews },
			}),
			scope:New("TextButton")({
				Name = "SellAllBars", AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromOffset(14, 236),
				Size = scope:Computed(function(use) return UDim2.fromOffset(522, use(saleHeight)) end),
				BorderSizePixel = 0, Font = UI.FONT, TextStrokeColor3 = UI.OUTLINE, TextStrokeTransparency = 0, TextSize = productionFont(15, 12),
				Text = "",
				BackgroundColor3 = scope:Computed(function(use) return if use(canSell) then UI.HUD_MINT else UI.HUD_BORDER end),
				TextColor3 = scope:Computed(function(use) return if use(canSell) then WHITE else UI.HUD_MUTED end),
				AutoButtonColor = canSell, Selectable = canSell, Active = canSell,
				[OnEvent("Activated")] = function() if Fusion.peek(canSell) then data.sellBars() end end,
				[Children] = { UI.hudFill(scope), UI.hudText(scope, {
					Name = "Label", Size = UDim2.fromScale(1, 1), Text = saleText, Font = UI.FONT,
					TextSize = productionFont(17, 12), TextStrokeColor3 = UI.OUTLINE, TextStrokeTransparency = 0,
					TextColor3 = scope:Computed(function(use) return if use(canSell) then WHITE else UI.HUD_MUTED end),
				}) },
			}),
		},
	})
	return {
		frame(scope, hud, "Resources", 292, function(l) return l.leftCards.Resources end, {
			UI.hudIcon(scope, "crystal", { Position = UDim2.fromOffset(16, 17), Size = UDim2.fromOffset(35, 35) }),
			text(scope, "Shards", shards, 62, 9, 212, 42, 34, WHITE, true, true),
			UI.hudIcon(scope, "coin", { Position = UDim2.fromOffset(16, 59), Size = UDim2.fromOffset(35, 35) }),
			text(scope, "Cash", scope:Computed(function(use) return Format.cash(use(data.cashShown)) end), 62, 48, 216, 45, 39, WHITE, true, true),
			-- Player level: "LV 5", an XP bar that fills as you hit, then the rebirth sale multiplier
			text(scope, "Level", scope:Computed(function(use) local s = state(use); return "LV " .. (if s and s.level then s.level else 1) end), 14, 96, 46, 18, 15, UI.HUD_GOLD, true, true),
			meter(scope, "LevelMeter", 64, 102, 110, scope:Computed(function(use)
				local s = state(use)
				return if s and s.xpNeeded and s.xpNeeded > 0 then s.xp / s.xpNeeded else 1
			end), UI.HUD_GOLD, 6),
			text(scope, "Multiplier", scope:Computed(function(use)
				local s = state(use); local m = Rebirth.multiplier(if s then s.rebirths else 0)
				return if m > 1 then "×" .. Format.number(m) .. " sales" else ""
			end), 182, 96, 104, 18, 14, WHITE, true, true),
		}, false),
		frame(scope, hud, "Production", 550, function(l) return l.leftCards.Production end, { details, summary }, false),
		frame(scope, hud, "Backpack", 292, function(l) return l.backpack end, {
			UI.hudIcon(scope, "backpack", { Position = UDim2.fromOffset(18, 38), Size = UDim2.fromOffset(49, 58) }),
			text(scope, "BackpackLabel", "BACKPACK", 82, 11, 194, 25, 18, WHITE, true, true),
			text(scope, "Capacity", scope:Computed(function(use) return Format.number(use(carried)) .. " / " .. Format.number(use(capacity)) end), 82, 34, 194, 39, 32,
				scope:Computed(function(use) return if use(full) then UI.RED else WHITE end), true, true),
			meter(scope, "CapacityMeter", 82, 80, 194, scope:Computed(function(use) return use(carried) / math.max(use(capacity), 1) end),
				scope:Computed(function(use) return if use(full) then UI.RED else CYAN end), 8),
			UI.hudText(scope, {
				Name = "CapacityPercent", Position = UDim2.fromOffset(82, 94), Size = UDim2.fromOffset(194, 18),
				Text = scope:Computed(function(use) return tostring(math.floor(math.clamp(use(carried) / math.max(use(capacity), 1), 0, 1) * 100 + 0.5)) .. "% full" end),
				Font = UI.FONT, TextSize = 15, TextColor3 = WHITE, TextStrokeColor3 = UI.OUTLINE, TextStrokeTransparency = 0.15,
			}),
			scope:New("TextButton")({
				Name = "OpenBackpack", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", ZIndex = 2,
				[OnEvent("Activated")] = function()
					local opened = player:GetAttribute("BackpackOpen") == true
					player:SetAttribute("FoundryExpanded", false)
					player:SetAttribute("BackpackOpen", not opened)
				end,
			}),
		}, false),
		frame(scope, hud, "Timer", 560, function(l) return l.timer end, {
			meter(scope, "RemainingTime", 12, 100, 536, data.timeProgress, glow, 4),
			UI.hudIcon(scope, "meteor", { Position = UDim2.fromOffset(18, 23), Size = UDim2.fromOffset(66, 66) }),
			text(scope, "MeteorName", scope:Computed(function(use) local s = use(data.meteorState); return if s then string.upper(s.typeName) else "METEOR MINING" end), 100, 16, 332, 27, font(scope, hud, 560, function(l) return l.timer end, 22, 12), glow, true, true),
			text(scope, "Phase", scope:Computed(function(use)
				local p = use(data.phase)
				if p == Phase.Countdown then return "Incoming meteor" end
				if p == Phase.Impact then return "Impact!" end
				if p == Phase.Active then return "Cooling down" end
				if p == Phase.CoreCracked then return "Core cracked!" end
				if p == Phase.Cooled then return "Meteor cooled" end
				return "Next meteor soon"
			end), 100, 46, 332, 44, 32, WHITE, true, true),
			UI.hudText(scope, {
				Name = "TimerLabel", Position = UDim2.fromOffset(440, 18), Size = UDim2.fromOffset(112, 22), Font = UI.FONT,
				Text = scope:Computed(function(use) local p = use(data.phase); return if p == Phase.Active then "COOLS IN" elseif p == Phase.Countdown then "ARRIVES IN" else "NEXT EVENT" end),
				TextSize = 14, TextColor3 = WHITE, TextStrokeColor3 = UI.OUTLINE, TextStrokeTransparency = 0.15,
			}),
			UI.hudText(scope, {
				Name = "Time", Position = UDim2.fromOffset(438, 42), Size = UDim2.fromOffset(114, 46), Font = UI.FONT,
				Text = scope:Computed(function(use) local value = use(data.timerText); return if value == "" then "--:--" else value end),
				TextSize = 40, TextColor3 = scope:Computed(function(use) local color = use(data.timerColor); return if color ~= UI.WHITE then color else UI.HUD_GOLD end),
				TextStrokeColor3 = UI.OUTLINE, TextStrokeTransparency = 0.15,
			}),
		}, false),
		scope:New("Frame")({
			Name = "YourPlot", BorderSizePixel = 0, BackgroundColor3 = UI.HUD_SURFACE,
			Visible = scope:Computed(function(use) local l = use(hud); return l.timerVisible and not l.touch and not l.portrait end),
			Position = scope:Computed(function(use) local l = use(hud); local s = l.timer.w / 560; return UDim2.fromOffset((l.viewport.X - 190 * s) / 2, l.timer.y + l.timer.h + 10 * s) end),
			Size = UDim2.fromOffset(190, 40),
			[Children] = {
				scope:New("UIScale")({ Scale = scope:Computed(function(use) return use(hud).timer.w / 560 end) }),
				UI.hudFill(scope),
				-- A location tag, matching the reference. Plot assignment and travel
				-- are gameplay concerns; this HUD pass does not add a teleport.
				UI.hudText(scope, { Name = "PlotLabel", Position = UDim2.fromOffset(10, 3), Size = UDim2.fromOffset(170, 34),
					Text = "⌂ YOUR PLOT", Font = UI.FONT, TextSize = 21, TextColor3 = WHITE, TextStrokeColor3 = UI.OUTLINE, TextStrokeTransparency = 0.15 }),
			},
		}),
	}
end

-- These menus are authored in StarterGui and bound by NativeHudMenus.start().
function HudView.backpack(_scope: Scope, _hud: any, _playerState: any): nil
	return nil
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

function HudView.settings(_scope: Scope, _hud: any): nil
	return nil
end
return HudView
