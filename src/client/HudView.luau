--!strict
-- Native Fusion HUD: live values and actions, responsive to the actual viewport.
-- Visuals follow the glossy cartoon style in Client.Cartoon: saturated cards with
-- thick ink outlines, floating icons with drop shadows, pill meters and chunky
-- outlined text.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Phase = require(ReplicatedStorage.Shared.Phase)
local Rebirth = require(ReplicatedStorage.Shared.Rebirth)
local HudLayout = require(ReplicatedStorage.Shared.HudLayout)
local MeteorIcon = require(ReplicatedStorage.Shared.MeteorIcon)
local MeteorTypes = require(ReplicatedStorage.Shared.MeteorTypes)
local UI = require(script.Parent.UI)
local Cartoon = require(script.Parent.Cartoon)
local Children, OnEvent = Fusion.Children, Fusion.OnEvent
local player = Players.LocalPlayer
type Scope = UI.Scope
local HudView = {}
local WHITE, ORANGE = UI.WHITE, Color3.fromRGB(255, 179, 92)
local GOLD, LIME, ICE, INK = Cartoon.GOLD, Cartoon.LIME, Cartoon.ICE, Cartoon.INK
local FOUNDRY_W = 300 -- the foundry button's base width (Config.Hud Production rects keep its 300 x 116 shape)

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
			-- The fill lives in a holder inset by the outline width and clipped to it, and the ink outline is its own
			-- frame drawn on top, so a nearly empty or full fill can never poke past the border.
			scope:New("Frame")({
				Name = "FillHolder", Position = UDim2.fromOffset(2, 2), Size = UDim2.new(1, -4, 1, -4),
				BackgroundTransparency = 1, ClipsDescendants = true,
				[Children] = {
					scope:New("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
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
			}),
			scope:New("Frame")({
				Name = "Outline", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 3,
				[Children] = {
					scope:New("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
					scope:New("UIStroke")({ Color = INK, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
				},
			}),
			if label then UI.hudText(scope, {
				Name = "Label", Size = UDim2.fromScale(1, 1), Text = label, Font = UI.FONT, ZIndex = 4,
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
			-- Config.HudEdit hides cards by their friendly name; the layout already folded it into the flags below
			if HudLayout.isHidden(layout, if name == "Resources" then "Wallet" elseif name == "Production" then "Foundry" else name) then return false end
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

-- The meteor objective, shared by the clock (which turns into the objective while a meteor is down) and the
-- fallback event card: progress toward cracking the crust, then the core's remaining strength.
local function eventObjective(scope: Scope, data: { [string]: any })
	local function goal(s: any) return math.ceil(s.crustTotal * Config.Meteor.CoreUnlockFraction) end
	local progress = scope:Computed(function(use)
		local s = use(data.meteorState)
		if s and not s.unlocked then return s.crustBroken / math.max(goal(s), 1) end
		return use(data.coreHp) / math.max(use(data.coreMaxHp), 1)
	end)
	return {
		progress = progress,
		title = scope:Computed(function(use) local s = use(data.meteorState); return if s and s.unlocked then "STRIKE THE CORE" else "BREAK THE CRUST" end),
		progressText = scope:Computed(function(use)
			local s = use(data.meteorState)
			if s and not s.unlocked then return "NODES BROKEN  " .. s.crustBroken .. " / " .. goal(s) end
			return "CORE STRENGTH  " .. math.ceil(math.clamp(use(progress), 0, 1) * 100) .. "%"
		end),
		standing = scope:Computed(function(use)
			local rank = use(data.standing)
			if not rank or rank.rank == 0 then return "Mine a node to join in!" end
			return "You: #" .. rank.rank .. " / " .. rank.players .. "  |  " .. Format.number(rank.ore) .. " ore"
		end),
	}
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
	local function productionFont(size: number, minimum: number)
		return font(scope, hud, FOUNDRY_W, function(l) return l.leftCards.Production end, size, minimum)
	end
	local glow = scope:Computed(function(use)
		local s = use(data.meteorState); local kind = s and Config.Meteor.Types[s.type]
		return if kind then kind.GlowColor:Lerp(WHITE, 0.2) else ORANGE
	end)
	local tips = flag(scope, "HudShowEventTips", true)
	local merged = scope:Computed(function(use) return use(data.inEvent) and use(tips) end)
	local notMerged = scope:Computed(function(use) return not use(merged) end)
	local function show(instance: Instance, when: any): Instance return scope:Hydrate(instance)({ Visible = when }) end
	local function hide(instance: Instance): Instance return show(instance, notMerged) end
	-- the beginner tip under the clock while a meteor counts down; the hourly pill sits below it when it shows
	local tipShown = scope:Computed(function(use)
		local s = state(use)
		return use(data.phase) == Phase.Countdown and (s == nil or (s.level or 1) <= Config.Hud.CountdownTip.MaxLevel)
	end)
	-- phones in landscape: the clock (countdown, cooldown and the meteor objective alike) sits below the top bar, larger
	local timerHud = scope:Computed(function(use)
		local layout = use(hud)
		if not layout.objective then return layout end
		local moved = table.clone(layout)
		moved.timer = layout.objective
		return moved
	end)
	local function timerFont(size: number, minimum: number) return font(scope, timerHud, 560, function(l) return l.timer end, size, minimum) end
	local objective = eventObjective(scope, data)
	local level = scope:Computed(function(use) local s = state(use); return tostring(if s and s.level then s.level else 1) end)
	local xpRatio = scope:Computed(function(use)
		local s = state(use)
		return if s and s.xpNeeded and s.xpNeeded > 0 then s.xp / s.xpNeeded else 1
	end)
	local levelRect = scope:Computed(function(use)
		local layout = use(hud)
		local rect = HudLayout.level(layout)
		return if rect then HudLayout.nudged(layout, "Level", rect) else nil
	end)
	local levelHidden = scope:Computed(function(use) return HudLayout.isHidden(use(hud), "Level") end)
	local levelInline = scope:Computed(function(use) return use(levelRect) == nil end)
	local productionScale = scope:Computed(function(use) return use(hud).leftCards.Production.w / FOUNDRY_W end)
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
	-- What stops the foundry, from the production line the server sends: a dot on its icon (the meters are on the
	-- sign over the building, FoundrySignController, and in the refinery menu)
	local blocked = scope:Computed(function(use)
		local s = state(use); local refinery = s and s.line and s.line.refinery
		return if refinery then refinery.blocked else "hopper"
	end)

	-- The sell button breathes while there are bars to sell, so it reads as the next thing to press
	local sellPulse = scope:New("UIScale")({ Name = "Pulse" })
	local pulse = TweenService:Create(sellPulse, TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Scale = 1.06 })
	local function syncPulse()
		if Fusion.peek(canSell) and player:GetAttribute("ReduceEffects") ~= true then pulse:Play() else pulse:Cancel(); sellPulse.Scale = 1 end
	end
	scope:Observer(canSell):onBind(syncPulse)
	table.insert(scope, player:GetAttributeChangedSignal("ReduceEffects"):Connect(syncPulse))
	table.insert(scope, pulse)

	-- The foundry button: its icon (opens the refinery, with a dot when the line is stuck) and the sell button for
	-- carried bars. FOUNDRY_W x 116 base units.
	local summary = scope:New("Frame")({
		Name = "Summary", AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.fromOffset(FOUNDRY_W, 116), BackgroundTransparency = 1,
		[Children] = {
			floatingIcon(scope, "foundry", 4, 22, 74),
			-- red: storage full, blue: needs ore; hidden while it refines
			scope:New("Frame")({
				Name = "StatusDot", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(70, 28), Size = UDim2.fromOffset(24, 24),
				BorderSizePixel = 0, ZIndex = 4,
				Visible = scope:Computed(function(use) return use(blocked) ~= nil end),
				BackgroundColor3 = scope:Computed(function(use) return if use(blocked) == "collector" then UI.RED else Color3.fromRGB(92, 200, 255) end),
				[Children] = {
					scope:New("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
					scope:New("UIStroke")({ Color = INK, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
					UI.hudText(scope, { Name = "Mark", Size = UDim2.fromScale(1, 1), Text = "!", Font = UI.FONT, TextSize = 18, ZIndex = 5,
						TextColor3 = WHITE, TextStrokeColor3 = INK, TextStrokeTransparency = 0 }),
				},
			}),
			scope:New("TextButton")({ Name = "OpenRefinery", Size = scope:Computed(function(use) return UDim2.new(0, HudLayout.closeSize(84, use(productionScale)), 1, 0) end),
				Text = "", BackgroundTransparency = 1, ZIndex = 6, [OnEvent("Activated")] = function() data.openRefinery() end }),
			scope:New("TextButton")({
				Name = "SellBars", Position = UDim2.fromOffset(86, 0), Size = UDim2.fromOffset(FOUNDRY_W - 86, 116),
				Text = "", BackgroundTransparency = 1, AutoButtonColor = false, ZIndex = 3,
				Selectable = canSell, Active = canSell,
				[OnEvent("Activated")] = function() if Fusion.peek(canSell) then data.sellBars() end end,
				[Children] = {
					scope:New("Frame")({
						Name = "Face", Position = UDim2.fromOffset(4, 12), Size = UDim2.new(1, -8, 0, 88), BackgroundTransparency = 1,
						[Children] = {
							sellPulse,
							scope:Hydrate(Cartoon.surface("green", { radius = 14, lip = 5, studs = 0.86, studSize = 30, name = "Ready" }))({ Visible = canSell }),
							scope:Hydrate(Cartoon.surface("slate", { radius = 14, lip = 5, stripes = false, name = "Idle" }))({
								Visible = scope:Computed(function(use) return not use(canSell) end),
							}),
							UI.hudText(scope, {
								Name = "Count", Position = UDim2.fromOffset(6, 8), Size = UDim2.new(1, -12, 0, 22), Text = sellTop, Font = UI.FONT, ZIndex = 2,
								TextSize = productionFont(17, 10), TextStrokeColor3 = INK, TextStrokeTransparency = 0,
								TextColor3 = scope:Computed(function(use) return if use(canSell) then Color3.fromRGB(232, 255, 204) else Color3.fromRGB(226, 232, 242) end),
							}),
							UI.hudText(scope, {
								Name = "Value", Position = UDim2.fromOffset(6, 30), Size = UDim2.new(1, -12, 0, 46), Font = UI.FONT, ZIndex = 2,
								Text = scope:Computed(function(use) local s = state(use); return Format.cash(if s then s.barValue else 0) end),
								TextSize = productionFont(36, 14), TextColor3 = WHITE, TextStrokeColor3 = INK, TextStrokeTransparency = 0,
								TextTruncate = Enum.TextTruncate.AtEnd,
							}),
						},
					}),
				},
			}),
		},
	})
	return {
		-- Player level gets its own card in the top-left corner when there is room.
		scope:New("Frame")({
			Name = "Level", BorderSizePixel = 0, BackgroundTransparency = 1, Size = UDim2.fromOffset(360, 96),
			Visible = scope:Computed(function(use) return use(levelRect) ~= nil and not use(levelHidden) end),
			Position = scope:Computed(function(use) local r = use(levelRect); return if r then UDim2.fromOffset(r.x, r.y) else UDim2.new() end),
			[Children] = {
				scope:New("UIScale")({ Scale = scope:Computed(function(use) local r = use(levelRect); return if r then r.w / 360 else 1 end) }),
				-- TRIAL: boardless like the wallet and backpack (the blue "Plate" fill at 42,13 318x72 is gone)
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
			-- No board: big outlined numbers and shadowed icons straight on the world
			floatingIcon(scope, "crystal", 6, 2, 50),
			text(scope, "Shards", shards, 62, 0, 170, 54, 44, ICE),
			floatingIcon(scope, "coin", 2, 56, 58),
			text(scope, "Cash", scope:Computed(function(use) return Format.cash(use(data.cashShown)) end), 62, 54, 230, 62, 54, GOLD),
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
			-- (phones in landscape: above the wallet, in the bottom-left corner)
			scope:Hydrate(levelMedal(scope, "LevelBadge", 238, -22, 64, level))({
				Visible = scope:Computed(function(use) return use(levelInline) and not use(levelHidden) end),
				Position = scope:Computed(function(use) return if use(hud).levelAbove then UDim2.fromOffset(0, -108) else UDim2.fromOffset(238, -22) end),
				Size = scope:Computed(function(use) return UDim2.fromOffset(if use(hud).levelAbove then 104 else 64, if use(hud).levelAbove then 104 else 64) end),
			}),
		}, true),
		frame(scope, hud, "Production", FOUNDRY_W, function(l) return l.leftCards.Production end, { summary }, true),
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
					player:SetAttribute("BackpackOpen", player:GetAttribute("BackpackOpen") ~= true)
				end,
			}),
		}, true), -- TRIAL: boardless like the wallet; `false` brings the blue board back
		frame(scope, timerHud, "Timer", 560, function(l) return l.timer end, {
			floatingIcon(scope, "meteor", 10, 6, 82, { Image = scope:Computed(function(use)
				local state = use(data.meteorState)
				return MeteorIcon.resolve(if state then state.type else nil)
			end) }),
			-- While a meteor is down the clock is the objective card: what to do, how far along, where you stand
			show(text(scope, "EventTitle", objective.title, 102, 6, 288, 36, timerFont(28, 14), GOLD), merged),
			show(text(scope, "EventStanding", objective.standing, 102, 44, 288, 30, timerFont(21, 12), LIME), merged),
			show(meter(scope, "EventProgress", 14, 80, 532, objective.progress, glow, 24, objective.progressText, timerFont(16, 10)), merged),
			hide(text(scope, "MeteorName", scope:Computed(function(use) local s = use(data.meteorState); return if s then string.upper(s.typeName) else "METEOR MINING" end), 102, 10, 284, 28, timerFont(23, 12), glow)),
			hide(text(scope, "Phase", scope:Computed(function(use)
				local p = use(data.phase)
				if p == Phase.Countdown then return "Incoming meteor" end
				if p == Phase.Impact then return "Impact!" end
				if p == Phase.Active then return "Cooling down" end
				if p == Phase.CoreCracked then return "Core cracked!" end
				if p == Phase.Cooled then return "Meteor cooled" end
				return "Next meteor soon"
			end), 102, 38, 284, 44, 33, WHITE)),
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
			hide(meter(scope, "RemainingTime", 14, 90, 532, data.timeProgress, glow, 12)),
			show(scope:Hydrate(text(scope, "CountdownTip", Config.Hud.CountdownTip.Text, 14, 104, 532, 22, timerFont(17, 10), LIME))({
				TextXAlignment = Enum.TextXAlignment.Center,
			}), tipShown),
			-- The hourly Quartz meteor (Config.Meteor.Hourly): a pill hanging under the clock, counting down for everyone
			scope:New("Frame")({
				Name = "HourlyPill", AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.fromOffset(300, 34),
				Position = scope:Computed(function(use) return UDim2.fromOffset(280, if use(tipShown) then 132 else 108) end),
				BackgroundColor3 = Color3.fromRGB(92, 34, 78), BackgroundTransparency = 0.15, BorderSizePixel = 0,
				[Children] = {
					scope:New("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
					scope:New("UIStroke")({ Color = INK, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
					floatingIcon(scope, "meteorQuartz", 8, 1, 32),
					scope:Hydrate(text(scope, "HourlyText", scope:Computed(function(use)
						local s = use(data.meteorState)
						local p = use(data.phase)
						if s and s.type == Config.Meteor.Hourly.Type and (p == Phase.Impact or p == Phase.Active) then
							return "QUARTZ METEOR IS DOWN!"
						end
						local now = use(data.serverNow)
						return "QUARTZ METEOR in " .. Format.time(MeteorTypes.nextHourly(now) - now)
					end), 46, 4, 246, 26, 20, Color3.fromRGB(255, 196, 238)))({ TextXAlignment = Enum.TextXAlignment.Center }),
				},
			}),
		}, true), -- no card behind the clock
	}
end

-- These menus are authored in StarterGui and bound by NativeHudMenus.start().
function HudView.backpack(_scope: Scope, _hud: any, _playerState: any): nil
	return nil
end

-- The event card is the fallback for screens where the clock is hidden; elsewhere the clock carries the objective.
function HudView.objective(scope: Scope, hud: any, data: { [string]: any })
	local tips = flag(scope, "HudShowEventTips", true)
	local function eventFont(size: number, minimum: number) return font(scope, hud, 284, function(l) return l.eventPanel end, size, minimum) end
	local objective = eventObjective(scope, data)
	-- No board: larger outlined text straight on the world, like the wallet
	local card = frame(scope, hud, "EventPanel", 284, function(l) return l.eventPanel end, {
		floatingIcon(scope, "meteor", 4, 0, 54, { Image = scope:Computed(function(use)
			local state = use(data.meteorState)
			return MeteorIcon.resolve(if state then state.type else nil)
		end) }),
		text(scope, "Title", objective.title, 62, 10, 222, 38, eventFont(27, 14), GOLD),
		text(scope, "Objective", scope:Computed(function(use)
			local s = use(data.meteorState)
			return if s and s.unlocked then "Strike the exposed core!" else "Break crust to expose core"
		end), 6, 54, 276, 32, eventFont(24, 14), WHITE),
		text(scope, "Progress", objective.progressText, 6, 88, 276, 24, eventFont(19, 12), ICE),
		meter(scope, "ProgressMeter", 8, 115, 268, objective.progress, ORANGE, 14),
		text(scope, "Standing", objective.standing, 6, 136, 276, 28, eventFont(19, 12), LIME),
	}, true)
	scope:Hydrate(card)({ Visible = scope:Computed(function(use)
		local layout = use(hud)
		return use(data.inEvent) and use(tips) and layout.eventVisible and not layout.timerVisible
			and not HudLayout.isHidden(layout, "EventPanel")
	end) })
	return card
end

function HudView.settings(_scope: Scope, _hud: any): nil
	return nil
end
return HudView
