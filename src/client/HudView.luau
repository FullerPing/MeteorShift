--!strict
-- Native Fusion HUD: live values and actions, responsive to the actual viewport.
-- Visuals follow the glossy cartoon style in Client.Cartoon: saturated cards with
-- thick ink outlines, floating icons with drop shadows, pill meters and chunky
-- outlined text.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Phase = require(ReplicatedStorage.Shared.Phase)
local Rebirth = require(ReplicatedStorage.Shared.Rebirth)
local HudResources = require(ReplicatedStorage.Shared.HudResources)
local HudLayout = require(ReplicatedStorage.Shared.HudLayout)
local MeteorIcon = require(ReplicatedStorage.Shared.MeteorIcon)
local UI = require(script.Parent.UI)
local Cartoon = require(script.Parent.Cartoon)
local Children, OnEvent = Fusion.Children, Fusion.OnEvent
local player = Players.LocalPlayer
type Scope = UI.Scope
local HudView = {}
local WHITE, ORANGE, CYAN = UI.WHITE, Color3.fromRGB(255, 179, 92), Color3.fromRGB(123, 230, 239)
local GOLD, LIME, ICE, INK = Cartoon.GOLD, Cartoon.LIME, Cartoon.ICE, Cartoon.INK

local function text(scope: Scope, name: string, value: any, x: number, y: number, w: number, h: number, size: any, color: any?)
	return UI.hudText(scope, {
		Name = name, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h), Text = value,
		Font = UI.FONT, TextSize = size, TextColor3 = color or WHITE, TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd, TextStrokeColor3 = INK, TextStrokeTransparency = 0,
	})
end
-- Pill meter: ink track, rounded glossy fill, optional outlined label inside.
local function meter(scope: Scope, name: string, x: number, y: number, w: number, fill: any, color: any, height: number?, label: any?, labelSize: any?)
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
			if label then UI.hudText(scope, {
				Name = "Label", Size = UDim2.fromScale(1, 1), Text = label, Font = UI.FONT, ZIndex = 2,
				TextSize = labelSize or math.floor(h * 0.72), TextColor3 = WHITE, TextStrokeColor3 = INK, TextStrokeTransparency = 0,
			}) else nil,
		},
	})
end
-- An icon that floats on the card with a soft ink drop shadow, no frame around it.
local function floatingIcon(scope: Scope, name: string, x: number, y: number, size: number, props: { [any]: any }?)
	local iconProps: { [any]: any } = { Name = "Icon", Size = UDim2.fromScale(1, 1), ZIndex = 2 }
	if props then for key, value in props do iconProps[key] = value end end
	return scope:New("Frame")({
		Name = name .. "Art", Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(size, size), BackgroundTransparency = 1,
		[Children] = {
			UI.hudIcon(scope, name, { Name = "Shadow", Position = UDim2.fromOffset(2, 4), Size = UDim2.fromScale(1, 1),
				Image = iconProps.Image, ImageColor3 = INK, ImageTransparency = 0.6, ZIndex = 1 }),
			UI.hudIcon(scope, name, iconProps),
		},
	})
end
-- A gold level medal: an orange starburst behind a round gold coin with the number.
local function levelMedal(scope: Scope, name: string, x: number, y: number, size: number, level: any)
	local function burst(rotation: number)
		return scope:New("Frame")({
			Name = "Burst", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.78, 0.78), Rotation = rotation, BackgroundTransparency = 1,
			[Children] = { Cartoon.surface("orange", { radius = 8, edge = 3, lip = 0, stripes = false, shine = false, rim = false }) },
		})
	end
	return scope:New("Frame")({
		Name = name, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(size, size), BackgroundTransparency = 1, ZIndex = 3,
		[Children] = {
			burst(0), burst(45),
			scope:New("Frame")({
				Name = "Coin", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(0.74, 0.74), BackgroundTransparency = 1, ZIndex = 2,
				[Children] = {
					Cartoon.surface("gold", { round = true, edge = 3, lip = 3, stripes = false }),
					UI.hudText(scope, { Name = "Caption", Position = UDim2.fromScale(0, 0.1), Size = UDim2.fromScale(1, 0.26), ZIndex = 2,
						Text = "LV", TextScaled = true, TextColor3 = WHITE, TextStrokeColor3 = INK }),
					UI.hudText(scope, { Name = "Value", Position = UDim2.fromScale(0.08, 0.34), Size = UDim2.fromScale(0.84, 0.5), ZIndex = 2,
						Text = level, TextScaled = true, TextColor3 = WHITE, TextStrokeColor3 = INK }),
				},
			}),
		},
	})
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

local function barViews(scope: Scope, rows: any, scale: any, rowHeight: any)
	local ids = scope:Computed(function(use) local result = {}; for i, row in use(rows) do result[i] = row.id end; return result end)
	return scope:ForPairs(ids, function(_use: any, rowScope: Scope, index: number, id: string)
		local row = rowScope:Computed(function(use)
			for _, entry in use(rows) do if entry.id == id then return entry end end
			return { name = id, amount = 0, value = 0 }
		end)
		local function rowFont(size: number) return rowScope:Computed(function(use) return math.max(size, 11 / use(scale)) end) end
		local tint = if id == "frost" then CYAN elseif id == "crystal" then Color3.fromRGB(221, 161, 255) else UI.HUD_GOLD
		local function line(name: string, value: any, x: number, w: number, color: Color3, align: Enum.TextXAlignment?)
			return UI.hudText(rowScope, {
				Name = name, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, x, 0.5, -2), Size = UDim2.fromOffset(w, 28),
				Text = value, Font = UI.FONT, TextSize = rowFont(21), TextColor3 = color, ZIndex = 2,
				TextXAlignment = align or Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
				TextStrokeColor3 = INK, TextStrokeTransparency = 0,
			})
		end
		-- One chip per bar type: tinted ingots, name, count and what they sell for.
		return index, rowScope:New("Frame")({
			Name = id .. "Bars", LayoutOrder = index, BackgroundTransparency = 1,
			Size = rowScope:Computed(function(use) return UDim2.new(1, 0, 0, use(rowHeight)) end),
			[Children] = {
				Cartoon.surface("deep", { radius = 12, edge = 2.5, lip = 3, stripes = false }),
				UI.hudIcon(rowScope, "barStack", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 12, 0.5, -2),
					Size = UDim2.fromOffset(34, 34), ImageColor3 = tint, ZIndex = 2 }),
				line("Type", rowScope:Computed(function(use) return use(row).name end), 56, 200, tint),
				line("Amount", rowScope:Computed(function(use) return "×" .. Format.number(use(row).amount) end), 262, 110, WHITE),
				line("Value", rowScope:Computed(function(use) return Format.cash(use(row).value) end), 374, 134, GOLD, Enum.TextXAlignment.Right),
			},
		})
	end)
end

function HudView.main(scope: Scope, hud: any, data: { [string]: any })
	local function state(use: any) return use(data.playerState) end
	local function value(field: string)
		return scope:Computed(function(use) local s = state(use); return Format.number(if s then s[field] or 0 else 0) end)
	end
	local shards = value("shards")
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
			return if line then Format.number(line.amount) .. " / " .. Format.number(line.capacity) else "0 / 2K"
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
	local level = scope:Computed(function(use) local s = state(use); return tostring(if s and s.level then s.level else 1) end)
	local xpRatio = scope:Computed(function(use)
		local s = state(use)
		return if s and s.xpNeeded and s.xpNeeded > 0 then s.xp / s.xpNeeded else 1
	end)
	local levelRect = scope:Computed(function(use) return HudLayout.level(use(hud)) end)
	local levelInline = scope:Computed(function(use) return use(levelRect) == nil end)
	local barRows = scope:Computed(function(use) return HudResources.bars(state(use)) end)
	local productionScale = scope:Computed(function(use) return use(hud).leftCards.Production.w / 550 end)
	local detailsHeight = scope:Computed(function(use)
		return math.max(0, use(hud).leftCards.Production.h / use(productionScale) - 116)
	end)
	local rowHeight = scope:Computed(function(use)
		local count = math.max(#use(barRows), 1)
		return math.clamp(math.floor((use(detailsHeight) - 64 - 8 * (count - 1)) / count), 30, 52)
	end)
	local rowViews = barViews(scope, barRows, productionScale, rowHeight)
	local canSell = scope:Computed(function(use)
		local s = state(use)
		return s ~= nil and s.bars > 0 and not use(data.saleBusy)
	end)
	local sellTop = scope:Computed(function(use)
		if use(data.saleBusy) then return "SELLING..." end
		local s = state(use)
		if not s then return "LOADING..." end
		if s.bars <= 0 then return "NO BARS YET" end
		return "SELL " .. Format.number(s.bars) .. " BARS"
	end)
	-- What the foundry is doing right now, from the production line the server sends.
	local blocked = scope:Computed(function(use)
		local s = state(use); local refinery = s and s.line and s.line.refinery
		return if refinery then refinery.blocked else "hopper"
	end)
	local status = scope:Computed(function(use)
		local why = use(blocked)
		if why == "collector" then return "STORAGE FULL" end
		if why == "hopper" then return "NEEDS ORE" end
		local s = state(use)
		return "REFINING · " .. (if s and s.line then Format.number(s.line.rate) else "0") .. "/s"
	end)
	local statusColor = scope:Computed(function(use)
		local why = use(blocked)
		return if why == "collector" then Color3.fromRGB(255, 120, 120) elseif why == "hopper" then ICE else LIME
	end)

	-- The foundry strip: icon (opens the refinery), two live meters, a sell
	-- button for carried bars and a chevron that opens the bar breakdown.
	local summary = scope:New("Frame")({
		Name = "Summary", AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.fromOffset(550, 116), BackgroundTransparency = 1,
		[Children] = {
			scope:New("Frame")({ Name = "Divider", Position = UDim2.fromOffset(14, 0), Size = UDim2.fromOffset(522, 3), Visible = expanded,
				BackgroundColor3 = INK, BackgroundTransparency = 0.55, BorderSizePixel = 0,
				[Children] = { scope:New("UICorner")({ CornerRadius = UDim.new(0.5, 0) }) } }),
			floatingIcon(scope, "foundry", 12, 22, 74),
			text(scope, "FoundryLabel", "FOUNDRY", 96, 8, 110, 28, productionFont(22, 12), GOLD),
			UI.hudText(scope, {
				Name = "Status", Position = UDim2.fromOffset(200, 10), Size = UDim2.fromOffset(138, 24), Text = status,
				Font = UI.FONT, TextSize = productionFont(16, 10), TextColor3 = statusColor, TextXAlignment = Enum.TextXAlignment.Right,
				TextTruncate = Enum.TextTruncate.AtEnd, TextStrokeColor3 = INK, TextStrokeTransparency = 0,
			}),
			UI.hudIcon(scope, "ore", { Position = UDim2.fromOffset(94, 41), Size = UDim2.fromOffset(28, 28) }),
			meter(scope, "HopperMeter", 128, 43, 210, lineRatio("hopper"), ORANGE, 24, lineText("hopper"), productionFont(17, 10)),
			UI.hudIcon(scope, "bars", { Position = UDim2.fromOffset(94, 77), Size = UDim2.fromOffset(28, 28) }),
			meter(scope, "StorageMeter", 128, 79, 210, lineRatio("collector"), GOLD, 24, lineText("collector"), productionFont(17, 10)),
			scope:New("TextButton")({
				Name = "ToggleFoundry", Size = UDim2.fromScale(1, 1), Text = "", BackgroundTransparency = 1, ZIndex = 2,
				[OnEvent("Activated")] = toggle,
				[Children] = {
					scope:New("Frame")({ Name = "ExpandFace", Position = UDim2.fromOffset(506, 26), Size = UDim2.fromOffset(34, 64), BackgroundTransparency = 1,
						[Children] = { Cartoon.surface("deep", { radius = 10, edge = 3, lip = 4 }) } }),
					UI.hudIcon(scope, "chevron", { Position = UDim2.fromOffset(509, 42), Size = UDim2.fromOffset(28, 28), ZIndex = 3,
						Rotation = scope:Computed(function(use) return if use(expanded) then 90 else -90 end) }),
					scope:New("TextButton")({ Name = "OpenRefinery", Size = scope:Computed(function(use) return UDim2.new(0, HudLayout.closeSize(92, use(productionScale)), 1, 0) end),
						Text = "", BackgroundTransparency = 1, ZIndex = 3, [OnEvent("Activated")] = function() data.openRefinery() end }),
					scope:New("TextButton")({
						Name = "SellBars", Position = UDim2.fromOffset(346, 0), Size = UDim2.fromOffset(154, 116),
						Text = "", BackgroundTransparency = 1, AutoButtonColor = false, ZIndex = 3,
						Selectable = canSell, Active = canSell,
						[OnEvent("Activated")] = function() if Fusion.peek(canSell) then data.sellBars() end end,
						[Children] = {
							scope:New("Frame")({
								Name = "Face", Position = UDim2.fromOffset(4, 12), Size = UDim2.fromOffset(146, 88), BackgroundTransparency = 1,
								[Children] = {
									scope:Hydrate(Cartoon.surface("green", { radius = 14, lip = 5, studs = 0.86, studSize = 30, name = "Ready" }))({ Visible = canSell }),
									scope:Hydrate(Cartoon.surface("slate", { radius = 14, lip = 5, stripes = false, name = "Idle" }))({
										Visible = scope:Computed(function(use) return not use(canSell) end),
									}),
									UI.hudText(scope, {
										Name = "Count", Position = UDim2.fromOffset(6, 8), Size = UDim2.new(1, -12, 0, 22), Text = sellTop, Font = UI.FONT, ZIndex = 2,
										TextSize = productionFont(16, 10), TextStrokeColor3 = INK, TextStrokeTransparency = 0,
										TextColor3 = scope:Computed(function(use) return if use(canSell) then Color3.fromRGB(232, 255, 204) else Color3.fromRGB(226, 232, 242) end),
									}),
									UI.hudText(scope, {
										Name = "Value", Position = UDim2.fromOffset(6, 30), Size = UDim2.new(1, -12, 0, 46), Font = UI.FONT, ZIndex = 2,
										Text = scope:Computed(function(use) local s = state(use); return Format.cash(if s then s.barValue else 0) end),
										TextSize = productionFont(34, 14), TextColor3 = WHITE, TextStrokeColor3 = INK, TextStrokeTransparency = 0,
										TextTruncate = Enum.TextTruncate.AtEnd,
									}),
								},
							}),
						},
					}),
				},
			}),
		},
	})
	-- Expanded: the carried bars by type. Fixed rows, no scrolling.
	local details = scope:New("Frame")({
		Name = "ExpandedDetails", Size = scope:Computed(function(use) return UDim2.fromOffset(550, use(detailsHeight)) end),
		BackgroundTransparency = 1, BorderSizePixel = 0, Visible = expanded, Active = true,
		[Children] = {
			text(scope, "Title", "BARS IN HAND", 16, 12, 300, 30, productionFont(22, 13), GOLD),
			-- The red X stays a small corner badge; its invisible hit area grows to a 44 px touch target.
			scope:New("TextButton")({ Name = "CloseDetails", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 8),
				Size = scope:Computed(function(use) local target = HudLayout.closeSize(36, use(productionScale)); return UDim2.fromOffset(target, target) end),
				Text = "", BackgroundTransparency = 1, ZIndex = 3, [OnEvent("Activated")] = toggle,
				[Children] = {
					scope:New("Frame")({ Name = "Face", AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.fromOffset(36, 36), BackgroundTransparency = 1,
						[Children] = {
							Cartoon.surface("red", { radius = 9, edge = 2.5, lip = 3 }),
							UI.hudIcon(scope, "close", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.5, 0.5), ZIndex = 2 }),
						} }),
				} }),
			scope:New("Frame")({
				Name = "BarInventory", Position = UDim2.fromOffset(14, 52),
				Size = scope:Computed(function(use) return UDim2.fromOffset(522, math.max(0, use(detailsHeight) - 60)) end),
				BackgroundTransparency = 1, BorderSizePixel = 0,
				[Children] = { scope:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8) }), rowViews },
			}),
		},
	})
	return {
		-- Player level gets its own card in the top-left corner when there is room.
		scope:New("Frame")({
			Name = "Level", BorderSizePixel = 0, BackgroundTransparency = 1, Size = UDim2.fromOffset(360, 96),
			Visible = scope:Computed(function(use) return use(levelRect) ~= nil end),
			Position = scope:Computed(function(use) local r = use(levelRect); return if r then UDim2.fromOffset(r.x, r.y) else UDim2.new() end),
			[Children] = {
				scope:New("UIScale")({ Scale = scope:Computed(function(use) local r = use(levelRect); return if r then r.w / 360 else 1 end) }),
				scope:New("Frame")({ Name = "Plate", Position = UDim2.fromOffset(42, 13), Size = UDim2.fromOffset(318, 72), BackgroundTransparency = 1,
					[Children] = { UI.hudFill(scope, "blue", { radius = 14 }) } }),
				text(scope, "LevelLabel", scope:Computed(function(use) return "LEVEL " .. use(level) end), 106, 17, 170, 32, 29, GOLD),
				UI.hudText(scope, {
					Name = "Percent", Position = UDim2.fromOffset(262, 21), Size = UDim2.fromOffset(86, 26), Font = UI.FONT, TextSize = 21,
					Text = scope:Computed(function(use) local s = state(use); return if s and s.xpNeeded and s.xpNeeded > 0 then math.floor(math.clamp(use(xpRatio), 0, 1) * 100) .. "%" else "MAX" end),
					TextColor3 = ICE, TextXAlignment = Enum.TextXAlignment.Right, TextStrokeColor3 = INK, TextStrokeTransparency = 0,
				}),
				meter(scope, "XpMeter", 106, 52, 242, xpRatio, LIME, 26, scope:Computed(function(use)
					local s = state(use)
					return if s and s.xpNeeded and s.xpNeeded > 0 then Format.number(s.xp) .. " / " .. Format.number(s.xpNeeded) .. " XP" else "MAX LEVEL"
				end), 18),
				levelMedal(scope, "Medal", 0, 0, 98, level),
			},
		}),
		frame(scope, hud, "Resources", 292, function(l) return l.leftCards.Resources end, {
			UI.hudIcon(scope, "crystal", { Position = UDim2.fromOffset(14, 10), Size = UDim2.fromOffset(40, 40) }),
			text(scope, "Shards", shards, 62, 6, 150, 46, 36, ICE),
			UI.hudIcon(scope, "coin", { Position = UDim2.fromOffset(12, 60), Size = UDim2.fromOffset(44, 44) }),
			text(scope, "Cash", scope:Computed(function(use) return Format.cash(use(data.cashShown)) end), 62, 56, 222, 52, 44, GOLD),
			UI.hudText(scope, {
				Name = "Multiplier", Size = UDim2.fromOffset(100, 24), Font = UI.FONT, TextSize = 17, TextColor3 = LIME,
				Position = scope:Computed(function(use) return UDim2.fromOffset(if use(levelInline) then 134 else 180, 16) end),
				TextXAlignment = Enum.TextXAlignment.Right, TextStrokeColor3 = INK, TextStrokeTransparency = 0,
				Text = scope:Computed(function(use)
					local s = state(use); local m = Rebirth.multiplier(if s then s.rebirths else 0)
					return if m > 1 then "×" .. Format.number(m) .. " sales" else ""
				end),
			}),
			-- Touch and cramped screens: the level medal sits on the wallet's corner instead.
			scope:Hydrate(levelMedal(scope, "LevelBadge", 238, -22, 64, level))({ Visible = levelInline }),
		}, false),
		frame(scope, hud, "Production", 550, function(l) return l.leftCards.Production end, { details, summary }, false),
		frame(scope, hud, "Backpack", 292, function(l) return l.backpack end, {
			floatingIcon(scope, "backpack", 12, 20, 78),
			text(scope, "BackpackLabel", "BACKPACK", 102, 8, 180, 26, 20, GOLD),
			text(scope, "Capacity", scope:Computed(function(use) return Format.number(use(carried)) .. " / " .. Format.number(use(capacity)) end), 102, 32, 180, 42, 34,
				scope:Computed(function(use) return if use(full) then Color3.fromRGB(255, 92, 92) else WHITE end)),
			meter(scope, "CapacityMeter", 102, 80, 176, scope:Computed(function(use) return use(carried) / math.max(use(capacity), 1) end),
				scope:Computed(function(use) return if use(full) then UI.RED else Color3.fromRGB(92, 220, 255) end), 22,
				scope:Computed(function(use) return if use(full) then "FULL!" else tostring(math.floor(math.clamp(use(carried) / math.max(use(capacity), 1), 0, 1) * 100 + 0.5)) .. "% full" end), 15),
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
			floatingIcon(scope, "meteor", 10, 6, 82, { Image = scope:Computed(function(use)
				local state = use(data.meteorState)
				return MeteorIcon.resolve(if state then state.type else nil)
			end) }),
			text(scope, "MeteorName", scope:Computed(function(use) local s = use(data.meteorState); return if s then string.upper(s.typeName) else "METEOR MINING" end), 102, 10, 284, 28, font(scope, hud, 560, function(l) return l.timer end, 23, 12), glow),
			text(scope, "Phase", scope:Computed(function(use)
				local p = use(data.phase)
				if p == Phase.Countdown then return "Incoming meteor" end
				if p == Phase.Impact then return "Impact!" end
				if p == Phase.Active then return "Cooling down" end
				if p == Phase.CoreCracked then return "Core cracked!" end
				if p == Phase.Cooled then return "Meteor cooled" end
				return "Next meteor soon"
			end), 102, 38, 284, 44, 33, WHITE),
			scope:New("Frame")({ Name = "Divider", Position = UDim2.fromOffset(392, 14), Size = UDim2.fromOffset(3, 66),
				BackgroundColor3 = INK, BackgroundTransparency = 0.55, BorderSizePixel = 0,
				[Children] = { scope:New("UICorner")({ CornerRadius = UDim.new(0.5, 0) }) } }),
			UI.hudText(scope, {
				Name = "TimerLabel", Position = UDim2.fromOffset(398, 8), Size = UDim2.fromOffset(150, 22), Font = UI.FONT,
				Text = scope:Computed(function(use) local p = use(data.phase); return if p == Phase.Active then "COOLS IN" elseif p == Phase.Countdown then "ARRIVES IN" else "NEXT EVENT" end),
				TextSize = 17, TextColor3 = ICE, TextStrokeColor3 = INK, TextStrokeTransparency = 0,
			}),
			UI.hudText(scope, {
				Name = "Time", Position = UDim2.fromOffset(398, 28), Size = UDim2.fromOffset(150, 54), Font = UI.FONT,
				Text = scope:Computed(function(use) local value = use(data.timerText); return if value == "" then "--:--" else value end),
				TextSize = 52, TextColor3 = scope:Computed(function(use) local color = use(data.timerColor); return if color ~= UI.WHITE then color else Color3.fromRGB(255, 206, 50) end),
				TextStrokeColor3 = INK, TextStrokeTransparency = 0,
			}),
			meter(scope, "RemainingTime", 14, 90, 532, data.timeProgress, glow, 12),
		}, true), -- no card behind the clock
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
		floatingIcon(scope, "meteor", 10, 6, 44, { Image = scope:Computed(function(use)
			local state = use(data.meteorState)
			return MeteorIcon.resolve(if state then state.type else nil)
		end) }),
		text(scope, "Title", scope:Computed(function(use) local s = use(data.meteorState); return if s and s.unlocked then "STRIKE THE CORE" else "BREAK THE CRUST" end), 60, 16, 212, 26, eventFont(18, 10), GOLD),
		text(scope, "Objective", scope:Computed(function(use)
			local s, rank = use(data.meteorState), use(data.standing)
			if s and s.unlocked then return "Strike the exposed core!" end
			return if not rank or rank.rank == 0 then "Mine a node to join in" else "Break crust to expose core"
		end), 14, 54, 258, 30, eventFont(20, 12), WHITE),
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
