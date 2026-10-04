--!strict
-- Meteor Mining Figma HUD: native Fusion widgets backed by the existing Knit state.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Knit = require(ReplicatedStorage.Packages.Knit)
local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Phase = require(ReplicatedStorage.Shared.Phase)
local Rebirth = require(ReplicatedStorage.Shared.Rebirth)
local UI = require(script.Parent.UI)
local Children, OnEvent = Fusion.Children, Fusion.OnEvent
local player = Players.LocalPlayer
type Scope = UI.Scope
local HudView = {}
local WHITE = Color3.fromRGB(255, 255, 255)
local ORANGE = Color3.fromRGB(255, 179, 92)
local CYAN = Color3.fromRGB(123, 230, 239)

local function text(scope: Scope, value: any, x: number, y: number, w: number, h: number, size: number, color: any?, bold: boolean?)
	return UI.hudText(scope, {
		Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h), Text = value,
		Font = if bold then Enum.Font.GothamBold else Enum.Font.GothamMedium,
		TextSize = size, TextColor3 = color or WHITE, TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
end

local function meter(scope: Scope, x: number, y: number, w: number, fill: any, color: any, height: number?)
	local animated = scope:Spring(fill, 25, 1)
	return scope:New("Frame")({
		Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, height or 4),
		BackgroundColor3 = UI.HUD_BORDER, BorderSizePixel = 0,
		[Children] = {
			UI.corner(scope, 3),
			scope:New("Frame")({
				Size = scope:Computed(function(use) return UDim2.fromScale(math.clamp(use(animated), 0, 1), 1) end),
				BackgroundColor3 = color, BorderSizePixel = 0, [Children] = { UI.corner(scope, 3) },
			}),
		},
	})
end

local function frame(scope: Scope, hud: any, name: string, baseWidth: number, rectFor: (any) -> any, children: { any }, clear: boolean?)
	return scope:New("Frame")({
		Name = name, BorderSizePixel = 0, BackgroundColor3 = UI.HUD_SURFACE,
		BackgroundTransparency = if clear then 1 else 0,
		Position = scope:Computed(function(use)
			local rect = rectFor(use(hud))
			return UDim2.fromOffset(rect.x, rect.y)
		end),
		Size = scope:Computed(function(use)
			local rect = rectFor(use(hud))
			return UDim2.fromOffset(baseWidth, rect.h / (rect.w / baseWidth))
		end),
		[Children] = {
			scope:New("UIScale")({ Scale = scope:Computed(function(use) return rectFor(use(hud)).w / baseWidth end) }),
			if clear then nil else UI.hudFill(scope), children,
		},
	})
end

function HudView.main(scope: Scope, hud: any, data: { [string]: any })
	local function state(use: any) return use(data.playerState) end
	local function value(field: string)
		return scope:Computed(function(use) local s = state(use); return Format.number(if s then s[field] else 0) end)
	end
	local carried = scope:Computed(function(use) local s = state(use); return if s then s.carried else 0 end)
	local capacity = scope:Computed(function(use) local s = state(use); return if s then s.capacity else 50 end)
	local full = scope:Computed(function(use) return use(carried) >= use(capacity) end)
	local expanded = scope:Value(player:GetAttribute("FoundryExpanded") == true)
	table.insert(scope, player:GetAttributeChangedSignal("FoundryExpanded"):Connect(function()
		expanded:set(player:GetAttribute("FoundryExpanded") == true)
	end))
	local function lineRatio(station: string)
		return scope:Computed(function(use)
			local s = state(use); local line = s and s.line and s.line[station]
			return if line then line.amount / math.max(line.capacity, 1) else 0
		end)
	end
	local function lineText(station: string)
		return scope:Computed(function(use)
			local s = state(use); local line = s and s.line and s.line[station]
			return if line then Format.number(line.amount) .. " / " .. Format.number(line.capacity) else "0 / 0"
		end)
	end
	local walletChildren = {}
	for i, item in { { "coin", "CASH", UI.HUD_GOLD }, { "crystal", "SHARDS", CYAN }, { "bars", "BARS", ORANGE } } do
		local x = (i - 1) * 112
		local amount = if i == 1 then scope:Computed(function(use) return Format.number(use(data.cashShown)) end)
			elseif i == 2 then value("shards") else value("bars")
		table.insert(walletChildren, UI.hudIcon(scope, item[1], { Position = UDim2.fromOffset(x + 10, 17), Size = UDim2.fromOffset(30, 30) }))
		table.insert(walletChildren, text(scope, amount, x + 46, 10, 62, 30, 27, item[3], true))
		table.insert(walletChildren, text(scope, item[2], x + 46, 43, 64, 12, 10, UI.HUD_MUTED))
	end
	local cashMultiplier = text(scope, scope:Computed(function(use)
		local s = state(use); local mult = Rebirth.multiplier(if s then s.rebirths else 0)
		return if mult > 1 then "CASH ×" .. Format.number(mult) else "CASH"
	end), 46, 43, 64, 12, 10, UI.HUD_MUTED)
	walletChildren[3] = cashMultiplier
	local foundryChildren = {
		UI.hudIcon(scope, "backpack", { Position = UDim2.fromOffset(14, 13), Size = UDim2.fromOffset(36, 36) }),
		text(scope, "ORE", 62, 17, 36, 16, 11, UI.HUD_MUTED),
		text(scope, scope:Computed(function(use) return Format.number(use(carried)) .. " / " .. Format.number(use(capacity)) end), 92, 14, 198, 23, 17, WHITE, true),
		meter(scope, 62, 45, 168, scope:Computed(function(use) return use(carried) / math.max(use(capacity), 1) end),
			scope:Computed(function(use) return if use(full) then UI.RED else CYAN end)),
		text(scope, scope:Computed(function(use) return if use(full) then "FULL" else "" end), 338, 17, 82, 20, 12, UI.RED, true),
		UI.hudIcon(scope, "foundry", { Position = UDim2.fromOffset(14, 64), Size = UDim2.fromOffset(29, 29) }),
		text(scope, "FOUNDRY", 53, 69, 82, 21, 13, WHITE, true),
		text(scope, scope:Computed(function(use) local s = state(use); return (if s then Format.number(s.line.rate) else "0") .. " /s" end), 124, 71, 58, 18, 11, UI.HUD_MINT),
		UI.hudIcon(scope, "ore", { Position = UDim2.fromOffset(178, 72), Size = UDim2.fromOffset(19, 19) }),
		text(scope, lineText("hopper"), 204, 71, 75, 20, 11),
		UI.hudIcon(scope, "bars", { Position = UDim2.fromOffset(298, 72), Size = UDim2.fromOffset(19, 19) }),
		text(scope, lineText("collector"), 324, 71, 79, 20, 11),
		scope:New("TextButton")({
			Name = "ToggleFoundry",
			Position = scope:Computed(function(use) return UDim2.fromOffset(0, if use(hud).touch then 0 else 59) end),
			Size = scope:Computed(function(use) return UDim2.new(1, 0, 0, if use(hud).touch then 113 else 54) end),
			Text = "", BackgroundTransparency = 1, ZIndex = 2,
			[OnEvent("Activated")] = function() player:SetAttribute("FoundryExpanded", not Fusion.peek(expanded)) end,
			[Children] = {
				UI.hudIcon(scope, "chevron", { Position = scope:Computed(function(use) return UDim2.fromOffset(401, if use(hud).touch then 72 else 13) end), Size = UDim2.fromOffset(26, 26),
					Rotation = scope:Computed(function(use) return if use(expanded) then 180 else 0 end) }),
			},
		}),
		scope:New("Frame")({
			Name = "ExpandedDetails", Position = UDim2.fromOffset(14, 120), Size = UDim2.fromOffset(420, 144),
			BackgroundTransparency = 1, Visible = expanded,
			[Children] = {
				text(scope, "Hopper", 0, 0, 120, 22, 15, UI.HUD_MUTED),
				text(scope, lineText("hopper"), 240, 0, 180, 22, 15, WHITE, true),
				meter(scope, 0, 28, 420, lineRatio("hopper"), ORANGE, 7),
				text(scope, "Storage", 0, 48, 120, 22, 15, UI.HUD_MUTED),
				text(scope, lineText("collector"), 240, 48, 180, 22, 15, WHITE, true),
				meter(scope, 0, 76, 420, lineRatio("collector"), UI.HUD_GOLD, 7),
				text(scope, scope:Computed(function(use)
					local s = state(use)
					if not s or not s.plotId then return "Claim a plot to start smelting" end
					if s.line.collector.amount >= s.line.collector.capacity then return "Storage full — collect your bars!" end
					if s.line.hopper.amount <= 0 then return "Add ore to start smelting" end
					return "Plot " .. s.plotId .. " · refining ore into bars"
				end), 0, 108, 420, 26, 14, UI.HUD_MUTED),
			},
		}),
	}
	return {
		frame(scope, hud, "Resources", 336, function(l) return l.leftCards.Resources end, walletChildren),
		frame(scope, hud, "Equipment", 244, function(l) return l.leftCards.Equipment end, {
			UI.hudIcon(scope, "equipment", { Position = UDim2.fromOffset(12, 12), Size = UDim2.fromOffset(45, 45) }),
			text(scope, scope:Computed(function(use) local s = state(use); return "TIER " .. (if s then s.pickaxeTier else 1) end), 64, 12, 166, 15, 10, ORANGE),
			text(scope, scope:Computed(function(use) local s = state(use); return (Config.Pickaxes[if s then s.pickaxeTier else 1] or Config.Pickaxes[1]).Name end), 64, 30, 170, 26, 17, WHITE, true),
		}),
		frame(scope, hud, "Production", 448, function(l) return l.leftCards.Production end, foundryChildren),
		frame(scope, hud, "Timer", 593, function(l) return l.timer end, {
			UI.hudIcon(scope, "meteor", { Position = UDim2.fromOffset(0, 10), Size = UDim2.fromOffset(74, 74) }),
			text(scope, scope:Computed(function(use) local s = use(data.meteorState); return if s then string.upper(s.typeName) else "METEOR MINING" end), 82, 2, 316, 28, 24, ORANGE, true),
			text(scope, scope:Computed(function(use)
				local phase = use(data.phase)
				if phase == Phase.Countdown then return "Incoming meteor" end
				if phase == Phase.Impact then return "Impact!" end
				if phase == Phase.Active then return "Cooling down" end
				if phase == Phase.CoreCracked then return "Core cracked!" end
				if phase == Phase.Cooled then return "Meteor cooled" end
				return "Next meteor soon"
			end), 82, 38, 312, 49, 36, WHITE, true),
			text(scope, data.timerText, 405, 3, 188, 86, 64, ORANGE, true),
			meter(scope, 0, 98, 472, scope:Computed(function(use)
				local s = use(data.meteorState); local duration = Config.Meteor.Countdown
				if s and s.phase == Phase.Active then duration = Config.Meteor.Types[s.type].ActiveDuration
				elseif s and s.phase == Phase.Countdown and game:GetService("RunService"):IsStudio() then duration = Config.Meteor.StudioCountdown or duration end
				return use(data.secondsLeft) / math.max(duration, 1)
			end), ORANGE, 6),
		}, true),
		frame(scope, hud, "EquipmentSettings", 40, function(l)
			local e = l.leftCards.Equipment
			local size = if l.touch then math.max(44, 40 * l.scale) else 40 * l.scale
			return { x = e.x + e.w + 29 * l.scale, y = e.y + (e.h - size) / 2, w = size, h = size }
		end, {
			scope:New("ImageButton")({ Name = "OpenEquipment", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
				Image = Config.HudIcons.settings, ScaleType = Enum.ScaleType.Fit,
				[OnEvent("Activated")] = function() Knit.GetController("ShopController"):Open() end }),
		}),
	}
end

function HudView.objective(scope: Scope, hud: any, data: { [string]: any })
	local progress = scope:Computed(function(use)
		local s = use(data.meteorState)
		if s and not s.unlocked then return s.crustBroken / math.max(math.ceil(s.crustTotal * Config.Meteor.CoreUnlockFraction), 1) end
		return use(data.coreHp) / math.max(use(data.coreMaxHp), 1)
	end)
	local card = frame(scope, hud, "EventPanel", 284, function(l) return l.eventPanel end, {
		UI.hudIcon(scope, "meteor", { Position = UDim2.fromOffset(16, 16), Size = UDim2.fromOffset(27, 27) }),
		text(scope, scope:Computed(function(use) local s = use(data.meteorState); return if s and s.unlocked then "STRIKE THE CORE" else "BREAK THE CRUST" end), 52, 21, 216, 17, 11, ORANGE),
		text(scope, scope:Computed(function(use)
			local s = use(data.meteorState); local rank = use(data.standing)
			if s and s.unlocked then return "Strike the exposed core!" end
			if not rank or rank.rank == 0 then return "Mine a node to join in" end
			return "Break crust to reach the core!"
		end), 16, 57, 252, 27, 19, WHITE, true),
		text(scope, scope:Computed(function(use)
			local s = use(data.meteorState)
			if s and not s.unlocked then return "NODES BROKEN  " .. s.crustBroken .. " / " .. math.ceil(s.crustTotal * Config.Meteor.CoreUnlockFraction) end
			return "CORE STRENGTH  " .. math.ceil(math.clamp(use(progress), 0, 1) * 100) .. "%"
		end), 16, 94, 252, 20, 12, UI.HUD_MUTED),
		meter(scope, 16, 122, 252, progress, ORANGE),
		text(scope, scope:Computed(function(use)
			local rank = use(data.standing)
			if not rank or rank.rank == 0 then return "Your first hit counts toward the core."
			end
			return "You: #" .. rank.rank .. " / " .. rank.players .. " · " .. Format.number(rank.ore) .. " ore"
		end), 16, 136, 252, 20, 11, UI.HUD_MINT),
	})
	scope:Hydrate(card)({ Visible = data.inEvent })
	return card
end

return HudView
