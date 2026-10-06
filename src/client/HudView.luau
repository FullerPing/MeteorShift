--!strict
-- Native Fusion HUD: live values and actions, responsive to the actual viewport.
-- Visuals follow the glossy cartoon style in Client.Cartoon: saturated cards with
-- thick ink outlines, white icon sockets, pill meters and chunky outlined text.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Phase = require(ReplicatedStorage.Shared.Phase)
local Rebirth = require(ReplicatedStorage.Shared.Rebirth)
local HudResources = require(ReplicatedStorage.Shared.HudResources)
local HudLayout = require(ReplicatedStorage.Shared.HudLayout)
local UI = require(script.Parent.UI)
local Cartoon = require(script.Parent.Cartoon)
local Children, OnEvent = Fusion.Children, Fusion.OnEvent
local player = Players.LocalPlayer
type Scope = UI.Scope
local HudView = {}
local WHITE, ORANGE, CYAN = UI.WHITE, Color3.fromRGB(255, 179, 92), Color3.fromRGB(123, 230, 239)
local GOLD, LIME, ICE, INK = Cartoon.GOLD, Cartoon.LIME, Cartoon.ICE, Cartoon.INK

local function text(scope: Scope, name: string, value: any, x: number, y: number, w: number, h: number, size: any, color: any?, _bold: boolean?, _floating: boolean?)
	return UI.hudText(scope, {
		Name = name, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h), Text = value,
		Font = UI.FONT, TextSize = size, TextColor3 = color or WHITE, TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd, TextStrokeColor3 = INK, TextStrokeTransparency = 0,
	})
end
-- Pill meter: ink track, rounded glossy fill.
local function meter(scope: Scope, name: string, x: number, y: number, w: number, fill: any, color: any, height: number?)
	local animated = scope:Spring(fill, 25, 1)
	local h = math.max(height or 8, 8)
	return scope:New("Frame")({
		Name = name, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h),
		BackgroundColor3 = Color3.fromRGB(10, 26, 70), BackgroundTransparency = 0.1, BorderSizePixel = 0,
		[Children] = {
			scope:New("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
			scope:New("UIStroke")({ Color = INK, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
			scope:New("Frame")({
				Name = "Fill", BackgroundColor3 = color, BorderSizePixel = 0,
				Size = scope:Computed(function(use) return UDim2.fromScale(math.clamp(use(animated), 0, 1), 1) end),
				[Children] = {
					scope:New("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
					scope:New("UIGradient")({ Rotation = 90, Color = ColorSequence.new({
						ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
						ColorSequenceKeypoint.new(0.45, Color3.new(1, 1, 1)),
						ColorSequenceKeypoint.new(1, Color3.fromRGB(170, 170, 170)),
					}) }),
				},
			}),
		},
	})
end
-- A white rounded socket that frames an icon, like the item tiles in the references.
local function socket(scope: Scope, name: string, x: number, y: number, w: number, h: number, kind: string?, children: { any }?)
	return scope:New("Frame")({
		Name = name, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h), BackgroundTransparency = 1,
		[Children] = {
			Cartoon.surface(kind or "white", { radius = 12, edge = 2.5, lip = 3, stripes = false }),
			children,
		},
	})
end
local function icon(scope: Scope, name: string, inset: number, props: { [any]: any }?)
	local merged: { [any]: any } = {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -inset * 2, 1, -inset * 2), ZIndex = 2,
	}
	if props then for key, value in props do merged[key] = value end end
	return UI.hudIcon(scope, name, merged)
end
local function frame(scope: Scope, hud: any, name: string, baseWidth: number, rectFor: (any) -> any, children: { any }, clear: boolean?, kind: string?)
	return scope:New("Frame")({
		Name = name, BorderSizePixel = 0, BackgroundTransparency = 1,
		Visible = scope:Computed(function(use)
			local layout = use(hud)
			if name == "Resources" then return layout.resourcesVisible end
			if name == "Backpack" then return layout.backpackVisible end
			if name == "Timer" then return layout.timerVisible end
			return true
		end),
		Position = scope:Computed(function(use) local r = rectFor(use(hud)); return UDim2.fromOffset(r.x, r.y) end),
		Size = scope:Computed(function(use) local r = rectFor(use(hud)); return UDim2.fromOffset(baseWidth, r.h / (r.w / baseWidth)) end),
		[Children] = {
			scope:New("UIScale")({ Scale = scope:Computed(function(use) return rectFor(use(hud)).w / baseWidth end) }),
			if clear then nil else UI.hudFill(scope, kind), children,
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
				text(rowScope, "Value", rowScope:Computed(function(use) return Format.cash(use(row).value) end), 400, 5, 112, 24, rowFont(17), GOLD, true),
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
			socket(scope, "FoundrySocket", 14, 16, 80, 80, nil, { icon(scope, "foundry", 9) }),
			text(scope, "ProductionLabel", "PRODUCTION", 106, 8, 160, 27, productionFont(20, 12), GOLD, true, true),
			text(scope, "ProductionRate", scope:Computed(function(use) local s = state(use); return (if s and s.line then Format.number(s.line.rate) else "0") .. "/s" end), 352, 6, 132, 32, productionFont(28, 14), LIME, true, true),
			scope:New("Frame")({ Name = "Divider", Position = UDim2.fromOffset(266, 14), Size = UDim2.fromOffset(3, 84), BackgroundColor3 = INK, BackgroundTransparency = 0.55, BorderSizePixel = 0,
				[Children] = { scope:New("UICorner")({ CornerRadius = UDim.new(0.5, 0) }) } }),
			UI.hudIcon(scope, "ore", { Position = UDim2.fromOffset(106, 44), Size = UDim2.fromOffset(28, 28) }),
			text(scope, "HopperAmount", lineText("hopper"), 140, 41, 120, 32, productionFont(23, 12), WHITE, true, true),
			UI.hudIcon(scope, "bars", { Position = UDim2.fromOffset(106, 78), Size = UDim2.fromOffset(28, 28) }),
			text(scope, "CollectorAmount", lineText("collector"), 140, 75, 120, 32, productionFont(23, 12), WHITE, true, true),
			UI.hudIcon(scope, "bars", { Position = UDim2.fromOffset(280, 44), Size = UDim2.fromOffset(62, 62) }),
			text(scope, "CarriedBars", scope:Computed(function(use) return "Bars: " .. use(bars) end), 352, 42, 134, 30, productionFont(22, 12), WHITE, true, true),
			text(scope, "SaleValue", scope:Computed(function(use) local s = state(use); return Format.cash(if s then s.barValue else 0) end), 352, 72, 134, 34, productionFont(27, 12), GOLD, true, true),
			scope:New("TextButton")({
				Name = "ToggleFoundry", Size = UDim2.fromScale(1, 1), Text = "", BackgroundTransparency = 1, ZIndex = 2,
				[OnEvent("Activated")] = toggle,
				[Children] = {
					scope:New("Frame")({ Name = "ExpandFace", Position = UDim2.fromOffset(494, 26), Size = UDim2.fromOffset(46, 62), BackgroundTransparency = 1,
						[Children] = { Cartoon.surface("green", { radius = 12, edge = 3, lip = 4 }) } }),
					UI.hudIcon(scope, "chevron", { Position = UDim2.fromOffset(501, 37), Size = UDim2.fromOffset(32, 32), ZIndex = 3,
						Rotation = scope:Computed(function(use) return if use(expanded) then 180 else 0 end) }),
					scope:New("TextButton")({ Name = "OpenRefinery", Size = scope:Computed(function(use) return UDim2.new(0, HudLayout.closeSize(100, use(productionScale)), 1, 0) end),
						Text = "", BackgroundTransparency = 1, ZIndex = 3, [OnEvent("Activated")] = function() data.openRefinery() end }),
				},
			}),
		},
	})
	local details = scope:New("ScrollingFrame")({
		Name = "ExpandedDetails", Size = scope:Computed(function(use)
			return UDim2.fromOffset(550, math.max(0, use(hud).leftCards.Production.h / use(productionScale) - 116))
		end), BackgroundTransparency = 1, BorderSizePixel = 0, Visible = expanded, Active = true,
		CanvasSize = UDim2.fromOffset(550, 240), ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 4, ScrollBarImageColor3 = WHITE,
		[Children] = {
			text(scope, "Title", "FOUNDRY", 16, 10, 290, 30, productionFont(22, 13), GOLD, true),
			scope:New("ImageButton")({ Name = "CloseDetails", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 10),
				Size = scope:Computed(function(use) local target = HudLayout.closeSize(36, use(productionScale)); return UDim2.fromOffset(target, target) end),
				Image = "", BackgroundTransparency = 1, [OnEvent("Activated")] = toggle,
				[Children] = {
					Cartoon.surface("red", { radius = 9, edge = 2.5, lip = 3 }),
					UI.hudIcon(scope, "close", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.55, 0.55), ZIndex = 2 }),
				} }),
			text(scope, "HopperLabel", "HOPPER", 16, 48, 100, 20, productionFont(15, 10), ICE),
			text(scope, "HopperCapacity", lineText("hopper"), 120, 46, 126, 24, productionFont(18, 11), WHITE, true),
			meter(scope, "HopperMeter", 16, 74, 236, lineRatio("hopper"), ORANGE, 10),
			text(scope, "StorageLabel", "STORAGE", 288, 48, 110, 20, productionFont(15, 10), ICE),
			text(scope, "StorageCapacity", lineText("collector"), 408, 46, 124, 24, productionFont(18, 11), WHITE, true),
			meter(scope, "StorageMeter", 288, 74, 236, lineRatio("collector"), GOLD, 10),
			text(scope, "BarsLabel", "CARRIED BARS", 16, 92, 196, 20, productionFont(15, 10), ICE),
			text(scope, "ValueLabel", "SALE VALUE", 410, 92, 124, 20, productionFont(15, 10), ICE),
			scope:New("ScrollingFrame")({
				Name = "BarInventory", Position = UDim2.fromOffset(14, 116),
				Size = scope:Computed(function(use) return UDim2.fromOffset(522, math.max(24, 104 - use(saleHeight))) end),
				BackgroundTransparency = 1, BorderSizePixel = 0, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
				ScrollBarThickness = 4, ScrollBarImageColor3 = WHITE, ScrollingDirection = Enum.ScrollingDirection.Y,
				[Children] = { scope:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder }), rowViews },
			}),
			scope:New("TextButton")({
				Name = "SellAllBars", AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromOffset(14, 232),
				Size = scope:Computed(function(use) return UDim2.fromOffset(522, use(saleHeight)) end),
				BorderSizePixel = 0, BackgroundTransparency = 1, Text = "",
				AutoButtonColor = false, Selectable = canSell, Active = canSell,
				[OnEvent("Activated")] = function() if Fusion.peek(canSell) then data.sellBars() end end,
				[Children] = {
					scope:Hydrate(Cartoon.surface("green", { radius = 12, lip = 4, name = "Ready" }))({ Visible = canSell }),
					scope:Hydrate(Cartoon.surface("slate", { radius = 12, lip = 4, stripes = false, name = "Idle" }))({
						Visible = scope:Computed(function(use) return not use(canSell) end),
					}),
					UI.hudText(scope, {
						Name = "Label", Size = UDim2.fromScale(1, 1), Text = saleText, Font = UI.FONT, ZIndex = 2,
						TextSize = productionFont(20, 12), TextStrokeColor3 = INK, TextStrokeTransparency = 0,
						TextColor3 = scope:Computed(function(use) return if use(canSell) then WHITE else Color3.fromRGB(226, 232, 242) end),
					}),
				},
			}),
		},
	})
	return {
		frame(scope, hud, "Resources", 292, function(l) return l.leftCards.Resources end, {
			UI.hudIcon(scope, "crystal", { Position = UDim2.fromOffset(14, 10), Size = UDim2.fromOffset(38, 38) }),
			text(scope, "Shards", shards, 60, 6, 220, 42, 34, ICE, true, true),
			UI.hudIcon(scope, "coin", { Position = UDim2.fromOffset(14, 52), Size = UDim2.fromOffset(38, 38) }),
			text(scope, "Cash", scope:Computed(function(use) return Format.cash(use(data.cashShown)) end), 60, 46, 222, 46, 40, GOLD, true, true),
			-- Player level: a gold "LV 5" pill, an XP bar that fills as you hit, then the rebirth sale multiplier
			scope:New("Frame")({
				Name = "LevelPill", Position = UDim2.fromOffset(12, 90), Size = UDim2.fromOffset(54, 22), BackgroundTransparency = 1,
				[Children] = {
					Cartoon.surface("orange", { radius = 8, edge = 2, lip = 2, stripes = false }),
					UI.hudText(scope, { Name = "Level", Size = UDim2.fromScale(1, 1), ZIndex = 2, TextSize = 15,
						Text = scope:Computed(function(use) local s = state(use); return "LV " .. (if s and s.level then s.level else 1) end) }),
				},
			}),
			meter(scope, "LevelMeter", 74, 95, 110, scope:Computed(function(use)
				local s = state(use)
				return if s and s.xpNeeded and s.xpNeeded > 0 then s.xp / s.xpNeeded else 1
			end), GOLD, 10),
			text(scope, "Multiplier", scope:Computed(function(use)
				local s = state(use); local m = Rebirth.multiplier(if s then s.rebirths else 0)
				return if m > 1 then "×" .. Format.number(m) .. " sales" else ""
			end), 192, 90, 96, 22, 15, LIME, true, true),
		}, false),
		frame(scope, hud, "Production", 550, function(l) return l.leftCards.Production end, { details, summary }, false),
		frame(scope, hud, "Backpack", 292, function(l) return l.backpack end, {
			socket(scope, "BackpackSocket", 14, 16, 80, 80, nil, { icon(scope, "backpack", 10) }),
			text(scope, "BackpackLabel", "BACKPACK", 106, 8, 176, 26, 20, GOLD, true, true),
			text(scope, "Capacity", scope:Computed(function(use) return Format.number(use(carried)) .. " / " .. Format.number(use(capacity)) end), 106, 32, 176, 42, 34,
				scope:Computed(function(use) return if use(full) then Color3.fromRGB(255, 92, 92) else WHITE end), true, true),
			meter(scope, "CapacityMeter", 106, 78, 172, scope:Computed(function(use) return use(carried) / math.max(use(capacity), 1) end),
				scope:Computed(function(use) return if use(full) then UI.RED else Color3.fromRGB(92, 220, 255) end), 20),
			UI.hudText(scope, {
				Name = "CapacityPercent", Position = UDim2.fromOffset(106, 78), Size = UDim2.fromOffset(172, 20), ZIndex = 2,
				Text = scope:Computed(function(use) return tostring(math.floor(math.clamp(use(carried) / math.max(use(capacity), 1), 0, 1) * 100 + 0.5)) .. "% full" end),
				Font = UI.FONT, TextSize = 14, TextColor3 = WHITE, TextStrokeColor3 = INK, TextStrokeTransparency = 0,
			}),
			scope:New("TextButton")({
				Name = "OpenBackpack", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", ZIndex = 3,
				[OnEvent("Activated")] = function()
					local opened = player:GetAttribute("BackpackOpen") == true
					player:SetAttribute("FoundryExpanded", false)
					player:SetAttribute("BackpackOpen", not opened)
				end,
			}),
		}, false),
		frame(scope, hud, "Timer", 560, function(l) return l.timer end, {
			socket(scope, "MeteorSocket", 14, 12, 74, 74, nil, { icon(scope, "meteor", 7) }),
			text(scope, "MeteorName", scope:Computed(function(use) local s = use(data.meteorState); return if s then string.upper(s.typeName) else "METEOR MINING" end), 102, 10, 290, 28, font(scope, hud, 560, function(l) return l.timer end, 23, 12), glow, true, true),
			text(scope, "Phase", scope:Computed(function(use)
				local p = use(data.phase)
				if p == Phase.Countdown then return "Incoming meteor" end
				if p == Phase.Impact then return "Impact!" end
				if p == Phase.Active then return "Cooling down" end
				if p == Phase.CoreCracked then return "Core cracked!" end
				if p == Phase.Cooled then return "Meteor cooled" end
				return "Next meteor soon"
			end), 102, 38, 296, 44, 33, WHITE, true, true),
			-- The countdown lives on a white plate so it pops like a price tag.
			socket(scope, "TimePlate", 404, 10, 142, 74, nil, {
				UI.hudText(scope, {
					Name = "TimerLabel", Position = UDim2.fromOffset(0, 5), Size = UDim2.new(1, 0, 0, 18), Font = UI.FONT, ZIndex = 2,
					Text = scope:Computed(function(use) local p = use(data.phase); return if p == Phase.Active then "COOLS IN" elseif p == Phase.Countdown then "ARRIVES IN" else "NEXT EVENT" end),
					TextSize = 15, TextColor3 = Cartoon.INK_BLUE, TextStrokeTransparency = 1,
				}),
				UI.hudText(scope, {
					Name = "Time", Position = UDim2.fromOffset(0, 22), Size = UDim2.new(1, 0, 0, 46), Font = UI.FONT, ZIndex = 2,
					Text = scope:Computed(function(use) local value = use(data.timerText); return if value == "" then "--:--" else value end),
					TextSize = 42, TextColor3 = scope:Computed(function(use) local color = use(data.timerColor); return if color ~= UI.WHITE then color else Color3.fromRGB(255, 196, 40) end),
					TextStrokeColor3 = INK, TextStrokeTransparency = 0,
				}),
			}),
			meter(scope, "RemainingTime", 14, 92, 532, data.timeProgress, glow, 10),
		}, false),
		scope:New("Frame")({
			Name = "YourPlot", BorderSizePixel = 0, BackgroundTransparency = 1,
			Visible = scope:Computed(function(use) local l = use(hud); return l.timerVisible and not l.touch and not l.portrait end),
			Position = scope:Computed(function(use) local l = use(hud); local s = l.timer.w / 560; return UDim2.fromOffset((l.viewport.X - 190 * s) / 2, l.timer.y + l.timer.h + 12 * s) end),
			Size = UDim2.fromOffset(190, 40),
			[Children] = {
				scope:New("UIScale")({ Scale = scope:Computed(function(use) return use(hud).timer.w / 560 end) }),
				-- A location tag styled like the references' purple top pill. Plot
				-- assignment and travel are gameplay concerns; no teleport is added.
				UI.hudFill(scope, "purple", { radius = 12, studs = false :: any }),
				UI.hudText(scope, { Name = "PlotLabel", Position = UDim2.fromOffset(10, 1), Size = UDim2.fromOffset(170, 34), ZIndex = 2,
					Text = "YOUR PLOT", Font = UI.FONT, TextSize = 23, TextColor3 = WHITE, TextStrokeColor3 = INK, TextStrokeTransparency = 0 }),
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
		socket(scope, "MeteorSocket", 12, 10, 38, 38, nil, { icon(scope, "meteor", 4) }),
		text(scope, "Title", scope:Computed(function(use) local s = use(data.meteorState); return if s and s.unlocked then "STRIKE THE CORE" else "BREAK THE CRUST" end), 60, 16, 212, 26, eventFont(18, 10), GOLD, true),
		text(scope, "Objective", scope:Computed(function(use)
			local s, rank = use(data.meteorState), use(data.standing)
			if s and s.unlocked then return "Strike the exposed core!" end
			return if not rank or rank.rank == 0 then "Mine a node to join in" else "Break crust to expose core"
		end), 14, 54, 258, 30, eventFont(20, 12), WHITE, true),
		text(scope, "Progress", scope:Computed(function(use)
			local s = use(data.meteorState)
			if s and not s.unlocked then return "NODES BROKEN  " .. s.crustBroken .. " / " .. math.ceil(s.crustTotal * Config.Meteor.CoreUnlockFraction) end
			return "CORE STRENGTH  " .. math.ceil(math.clamp(use(progress), 0, 1) * 100) .. "%"
		end), 14, 88, 258, 22, eventFont(15, 10), ICE),
		meter(scope, "ProgressMeter", 14, 114, 256, progress, ORANGE, 12),
		text(scope, "Standing", scope:Computed(function(use)
			local rank = use(data.standing)
			if not rank or rank.rank == 0 then return "First hit joins the event." end
			return "You: #" .. rank.rank .. " / " .. rank.players .. " · " .. Format.number(rank.ore) .. " ore"
		end), 14, 136, 258, 24, eventFont(15, 10), LIME),
	})
	scope:Hydrate(card)({ Visible = scope:Computed(function(use) return use(data.inEvent) and use(tips) and use(hud).eventVisible end) })
	return card
end

function HudView.settings(_scope: Scope, _hud: any): nil
	return nil
end
return HudView
