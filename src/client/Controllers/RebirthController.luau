--!strict
-- Compact rebirth card based on the player's design; resets stay server-authoritative.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Knit = require(ReplicatedStorage.Packages.Knit)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Rebirth = require(ReplicatedStorage.Shared.Rebirth)
local RebirthLayout = require(ReplicatedStorage.Shared.RebirthLayout)
local UI = require(script.Parent.Parent.UI)
local Sfx = require(script.Parent.Parent.Sfx)
local Children, OnEvent = Fusion.Children, Fusion.OnEvent
local player = Players.LocalPlayer
local RebirthController = Knit.CreateController({ Name = "RebirthController" })
local wantOpen = false
local isOpen: Fusion.Value<boolean>? = nil

function RebirthController:Open()
	wantOpen = true
	if isOpen then isOpen:set(true) end
end

local function multiplierText(rebirths: number): string
	local value = Rebirth.multiplier(rebirths)
	return (if value < 1000 then string.format("%.6g", value) else Format.number(value)) .. "×"
end

function RebirthController:KnitStart()
	local RebirthService = Knit.GetService("RebirthService")
	local PlayerStateService = Knit.GetService("PlayerStateService")
	local HUDController = Knit.GetController("HUDController")
	local scope = Fusion.scoped(Fusion)
	local open, armed, busy, notice = scope:Value(wantOpen), scope:Value(false), scope:Value(false), scope:Value("")
	isOpen = open
	local hud = UI.hud(scope)
	local geometry = scope:Computed(function(use)
		local layout = use(hud)
		return RebirthLayout.compute(layout.viewport, layout.inset)
	end)
	local function flag(name: string)
		local value = scope:Value(player:GetAttribute(name) == true)
		table.insert(scope, player:GetAttributeChangedSignal(name):Connect(function()
			value:set(player:GetAttribute(name) == true)
		end))
		return value
	end
	local shopOpen, indexOpen, tutorialInColumn = flag("ShopOpen"), flag("IndexOpen"), flag("TutorialCardInColumn")
	local buttonVisible = scope:Computed(function(use)
		return not use(open) and not use(shopOpen) and not use(indexOpen) and not use(tutorialInColumn)
	end)
	local state = scope:Value(nil :: any)
	PlayerStateService.State:Observe(function(value) state:set(value) end)
	local cash = scope:Computed(function(use) local s = use(state) return if s then s.cash else 0 end)
	local rebirths = scope:Computed(function(use) local s = use(state) return if s then s.rebirths or 0 else 0 end)
	local cost = scope:Computed(function(use) return Rebirth.cost(use(rebirths)) end)
	local affordable = scope:Computed(function(use) return use(state) ~= nil and use(cash) >= use(cost) end)
	local canPress = scope:Computed(function(use) return use(affordable) and not use(busy) end)

	-- Retain the two-press confirmation; closing or losing affordability disarms it.
	local armToken = 0
	local function disarm()
		armToken += 1
		armed:set(false)
	end
	scope:Observer(open):onChange(function() disarm() notice:set("") end)
	scope:Observer(open):onBind(function() player:SetAttribute("RebirthOpen", Fusion.peek(open)) end)
	scope:Observer(affordable):onChange(function() if not Fusion.peek(affordable) then disarm() end end)
	RebirthService.Notice:Connect(function(message)
		notice:set(message)
		HUDController:Toast(message)
	end)
	local function press()
		if not Fusion.peek(canPress) then return end
		if not Fusion.peek(armed) then
			armToken += 1
			local token = armToken
			armed:set(true)
			notice:set("")
			task.delay(Config.Rebirth.ConfirmWindow, function()
				if armToken == token then armed:set(false) end
			end)
			return
		end
		disarm()
		busy:set(true)
		task.spawn(function()
			local ok, reborn = pcall(function() return RebirthService:Rebirth() end)
			busy:set(false)
			if not ok then notice:set("Couldn't rebirth. Please try again.")
			elseif reborn then Sfx.play("Purchase") open:set(false) end
		end)
	end
	table.insert(scope, UserInputService.InputBegan:Connect(function(input)
		if Fusion.peek(open) and (input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB) then open:set(false) end
	end))

	scope:New("ScreenGui")({
		Name = "Rebirth", ResetOnSpawn = false, IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 22, Parent = player:WaitForChild("PlayerGui"),
		[Children] = {
			UI.hudButton(scope, hud, "REBIRTH", 26, {
				Name = "RebirthButton", Text = "REBIRTH", Visible = buttonVisible,
				BackgroundColor3 = scope:Spring(scope:Computed(function(use) return if use(affordable) then UI.HUD_MINT else UI.HUD_GOLD end), 12, 1),
				[OnEvent("Activated")] = function() open:set(true) end,
			}),
			scope:New("TextButton")({
				Name = "Dimmer", Size = UDim2.fromScale(1, 1), BackgroundColor3 = UI.OUTLINE,
				BackgroundTransparency = 0.25, Text = "", AutoButtonColor = false, BorderSizePixel = 0,
				Visible = open, ZIndex = 2, Modal = true,
				[OnEvent("Activated")] = function() open:set(false) end,
			}),
			scope:New("Frame")({
				Name = "Panel",
				Position = scope:Computed(function(use) local p = use(geometry).panel return UDim2.fromOffset(p.x, p.y) end),
				Size = scope:Computed(function(use) local p = use(geometry).panel return UDim2.fromOffset(p.w, p.h) end),
				BackgroundColor3 = Color3.fromRGB(45, 47, 48), BorderSizePixel = 0, Visible = open, ZIndex = 3, Active = true,
				[Children] = {
					UI.corner(scope, 24),
					scope:New("UIStroke")({ Color = UI.HUD_BORDER, Thickness = 1, Transparency = 0.45, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
					UI.label(scope, {
						Name = "Title", Position = UDim2.fromOffset(20, 12), Size = UDim2.new(1, -92, 0, 38),
						Text = "REBIRTH", TextSize = 26, TextStrokeTransparency = 1, TextXAlignment = Enum.TextXAlignment.Left,
					}),
					UI.button(scope, {
						Name = "Close", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 8),
						Size = UDim2.fromOffset(44, 44), Text = "", BackgroundColor3 = UI.CARD,
						[Children] = { UI.hudIcon(scope, "close", { Position = UDim2.fromOffset(12, 12), Size = UDim2.fromOffset(20, 20) }) },
						[OnEvent("Activated")] = function() open:set(false) end,
					}),
					scope:New("ScrollingFrame")({
						Name = "Content", Position = scope:Computed(function(use) return UDim2.fromOffset(16, use(geometry).contentY) end),
						Size = scope:Computed(function(use) return UDim2.new(1, -32, 0, use(geometry).contentH) end),
						CanvasSize = scope:Computed(function(use) return UDim2.fromOffset(0, use(geometry).canvasH) end),
						BackgroundTransparency = 1, BorderSizePixel = 0, ScrollingDirection = Enum.ScrollingDirection.Y,
						ScrollBarThickness = 3, ScrollBarImageColor3 = UI.HUD_GOLD, VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
						[Children] = {
							UI.label(scope, {
								Name = "Rules", Size = UDim2.new(1, -4, 0, 86), RichText = true, TextWrapped = true, TextScaled = true,
								Text = '<font color="#FF656A">Resets</font> cash, gear, resources and other upgrades.\nYou keep <font color="#FFDB64">refinery levels</font>, <font color="#FFDB64">core shards</font> and <font color="#FFDB64">index bonuses</font>.',
								TextStrokeTransparency = 1, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
								[Children] = { scope:New("UITextSizeConstraint")({ MinTextSize = 15, MaxTextSize = 18 }) },
							}),
							UI.label(scope, {
								Name = "MultiplierCaption", Position = UDim2.fromOffset(0, 96), Size = UDim2.new(1, -4, 0, 20),
								Text = "Bar sale multiplier", TextSize = 18, TextStrokeTransparency = 1,
							}),
							UI.label(scope, {
								Name = "CurrentMultiplier", Position = UDim2.fromOffset(0, 122), Size = UDim2.new(0.4, -4, 0, 68),
								Text = scope:Computed(function(use) return multiplierText(use(rebirths)) end),
								TextScaled = true, TextStrokeTransparency = 1,
								[Children] = { scope:New("UITextSizeConstraint")({ MinTextSize = 22, MaxTextSize = 56 }) },
							}),
							UI.label(scope, {
								Name = "Arrow", Position = UDim2.new(0.4, 0, 0, 122), Size = UDim2.new(0.2, -4, 0, 68),
								Text = "→", Font = Enum.Font.GothamBold, TextSize = 40, TextColor3 = UI.HUD_GOLD, TextStrokeTransparency = 1,
							}),
							UI.label(scope, {
								Name = "NextMultiplier", Position = UDim2.new(0.6, 0, 0, 122), Size = UDim2.new(0.4, -4, 0, 68),
								Text = scope:Computed(function(use) return multiplierText(use(rebirths) + 1) end),
								TextScaled = true, TextColor3 = Color3.fromRGB(46, 207, 99), TextStrokeTransparency = 1,
								[Children] = { scope:New("UITextSizeConstraint")({ MinTextSize = 22, MaxTextSize = 56 }) },
							}),
							UI.body(scope, {
								Name = "CashProgress", Position = UDim2.fromOffset(0, 202), Size = UDim2.new(1, -4, 0, 20),
								TextScaled = true, TextColor3 = UI.HUD_MUTED,
								Text = scope:Computed(function(use) return "You have " .. Format.cash(use(cash)) .. " / " .. Format.cash(use(cost)) end),
								[Children] = { scope:New("UITextSizeConstraint")({ MinTextSize = 10, MaxTextSize = 12 }) },
							}),
						},
					}),
					UI.button(scope, {
						Name = "Confirm", Position = scope:Computed(function(use) return UDim2.fromOffset(16, use(geometry).confirmY) end),
						Size = UDim2.new(1, -32, 0, 48), TextScaled = true, Active = canPress, AutoButtonColor = canPress, Selectable = canPress,
						Text = scope:Computed(function(use)
							if use(busy) then return "REBIRTHING..."
							elseif use(armed) then return "CONFIRM REBIRTH"
							else return "Rebirth " .. Format.cash(use(cost)) end
						end),
						TextColor3 = scope:Computed(function(use) return if use(busy) or not use(affordable) then UI.HUD_MUTED else UI.OUTLINE end),
						BackgroundColor3 = scope:Computed(function(use)
							return if use(busy) or not use(affordable) then UI.DISABLED elseif use(armed) then UI.HUD_GOLD else Color3.fromRGB(226, 226, 226)
						end),
						[Children] = { scope:New("UITextSizeConstraint")({ MinTextSize = 15, MaxTextSize = 23 }) },
						[OnEvent("Activated")] = press,
					}),
					UI.body(scope, {
						Name = "Footer", Position = scope:Computed(function(use) return UDim2.fromOffset(16, use(geometry).footerY) end),
						Size = UDim2.new(1, -32, 0, 26), TextSize = 11, TextWrapped = true,
						Text = scope:Computed(function(use)
							local message = use(notice)
							if message ~= "" then return message
							elseif use(busy) then return "Rebirthing..."
							elseif use(armed) then return "Press again within " .. Format.number(Config.Rebirth.ConfirmWindow) .. " s. This can't be undone."
							elseif not use(affordable) then return "Earn " .. Format.cash(use(cost) - use(cash)) .. " more to rebirth."
							else return "Index bonuses stay and stack with this multiplier." end
						end),
						TextColor3 = scope:Computed(function(use) return if use(armed) or use(notice) ~= "" then UI.HUD_GOLD else UI.HUD_MUTED end),
					}),
				},
			}),
		},
	})
end

return RebirthController
