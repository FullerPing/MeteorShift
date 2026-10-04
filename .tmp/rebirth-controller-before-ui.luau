--!strict
-- Rebirth panel, "Relocate the Colony" (spec §8.3). The REBIRTH button sits under
-- INDEX in the HUD button column (hidden while the shop or the index is open, or
-- while the tutorial card takes the column on compact screens) and turns green once
-- a rebirth is affordable. The panel shows the current and next cash multiplier,
-- the cost with progress toward it, what resets and what is kept. Its confirm
-- button needs a second press ("ARE YOU SURE?") within Config.Rebirth.ConfirmWindow
-- seconds, and while cash is short it is disabled and says how much is missing.
--
-- RebirthService re-checks the price and does the reset; this reads the `cash` and
-- `rebirths` in the player's State and is presentation only.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local HudLayout = require(ReplicatedStorage.Shared.HudLayout)
local Rebirth = require(ReplicatedStorage.Shared.Rebirth)
local Sfx = require(script.Parent.Parent.Sfx)
local UI = require(script.Parent.Parent.UI)

local Children, OnEvent = Fusion.Children, Fusion.OnEvent
local player = Players.LocalPlayer

local RebirthController = Knit.CreateController({ Name = "RebirthController" })

type Scope = UI.Scope

local PANEL_WIDTH, PANEL_HEIGHT = 720, 640

local RESET_ROWS = { "Cash → $0; gear → Tier 1", "All carried + stored ore / bars", "Hopper, conveyor + collection levels", "Décor + partial refining progress" }
local KEEP_ROWS = { "Refinery level", "Carried Core Shards", "Index discoveries + sale bonuses", "Earned index titles" }

local function multiplierText(rebirths: number): string
	local multiplier = Rebirth.multiplier(rebirths)
	-- Cash formatting floors small values; keep fractional boosts visible here.
	local text = if multiplier < 1000 then string.format("%.6g", multiplier) else Format.number(multiplier)
	return "×" .. text
end

local function card(scope: Scope, props: { [any]: any }, children: { any })
	return scope:New("Frame")({
		Name = props.Name,
		Position = props.Position,
		Size = props.Size,
		BackgroundColor3 = UI.CARD,
		BorderSizePixel = 0,
		[Children] = {
			UI.cardFill(scope),
			children,
		},
	})
end

local function rulesCard(scope: Scope, props: { [any]: any }, rows: { string }, accent: Color3)
	local children: { any } = {
		scope:New("Frame")({
			Name = "Accent", Position = UDim2.fromOffset(14, 14), Size = UDim2.fromOffset(4, 23),
			BackgroundColor3 = accent, BorderSizePixel = 0, [Children] = { UI.corner(scope, 2) },
		}),
		UI.label(scope, {
			Position = UDim2.fromOffset(26, 10), Size = UDim2.new(1, -40, 0, 30),
			Text = props.Caption, TextSize = 21, TextColor3 = UI.WHITE,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
	}
	for index, text in rows do
		table.insert(children, scope:New("Frame")({
			Position = UDim2.fromOffset(15, 54 + (index - 1) * 25), Size = UDim2.fromOffset(5, 5),
			BackgroundColor3 = accent, BorderSizePixel = 0, [Children] = { UI.corner(scope, 3) },
		}))
		table.insert(children, UI.body(scope, {
			Position = UDim2.fromOffset(28, 46 + (index - 1) * 25), Size = UDim2.new(1, -40, 0, 24),
			Text = text, TextSize = 13, TextColor3 = UI.WHITE, TextXAlignment = Enum.TextXAlignment.Left,
			TextScaled = true, [Children] = { scope:New("UITextSizeConstraint")({ MaxTextSize = 13, MinTextSize = 11 }) },
		}))
	end
	return card(scope, props, children)
end

function RebirthController:KnitStart()
	local RebirthService = Knit.GetService("RebirthService")
	local PlayerStateService = Knit.GetService("PlayerStateService")
	local HUDController = Knit.GetController("HUDController")

	local scope = Fusion.scoped(Fusion)
	local open, armed, busy, notice = scope:Value(false), scope:Value(false), scope:Value(false), scope:Value("")

	-- Flags other controllers set on the local player
	local function playerFlag(name: string)
		local flag = scope:Value(player:GetAttribute(name) == true)
		table.insert(scope, player:GetAttributeChangedSignal(name):Connect(function()
			flag:set(player:GetAttribute(name) == true)
		end))
		return flag
	end
	local shopOpen = playerFlag("ShopOpen")
	local indexOpen = playerFlag("IndexOpen")
	local tutorialInColumn = playerFlag("TutorialCardInColumn")
	-- The shop and index panels sit below this one; REBIRTH would draw over their
	-- dimmers. On compact screens the tutorial card covers this spot too.
	local buttonVisible = scope:Computed(function(use)
		return not use(open) and not use(shopOpen) and not use(indexOpen) and not use(tutorialInColumn)
	end)

	-- Keep type and tap targets full-size on short screens; the body scrolls instead.
	local hud = UI.hud(scope)
	local height = scope:Computed(function(use)
		local l = use(hud)
		return math.min(PANEL_HEIGHT, math.max(280, l.viewport.Y - l.inset - 24))
	end)
	local panelFit = scope:Computed(function(use)
		local l = use(hud)
		return HudLayout.panel(l.viewport, PANEL_WIDTH, use(height), l.inset)
	end)
	local scale = scope:Computed(function(use)
		return use(panelFit).scale
	end)
	local width = scope:Computed(function(use)
		return use(panelFit).width
	end)
	local compact = scope:Computed(function(use)
		return use(width) < 560
	end)
	local short = scope:Computed(function(use)
		return use(height) < 460
	end)
	local bodyTop = scope:Computed(function(use)
		return if use(short) then 84 else 114
	end)

	local playerState = scope:Value(nil :: any)
	PlayerStateService.State:Observe(function(value)
		playerState:set(value)
	end)
	local cash = scope:Computed(function(use): number
		local s = use(playerState)
		return if s then s.cash else 0
	end)
	local rebirths = scope:Computed(function(use): number
		local s = use(playerState)
		return if s and s.rebirths then s.rebirths else 0
	end)
	local cost = scope:Computed(function(use)
		return Rebirth.cost(use(rebirths))
	end)
	local affordable = scope:Computed(function(use)
		return use(cash) >= use(cost)
	end)

	-- The first press arms the button; a second press within the window rebirths
	local armToken = 0
	local function disarm()
		armToken += 1
		armed:set(false)
	end
	scope:Observer(open):onChange(function()
		disarm()
		notice:set("")
	end)
	-- StoreController hides STORE while this panel is open
	scope:Observer(open):onBind(function()
		player:SetAttribute("RebirthOpen", Fusion.peek(open))
	end)
	scope:Observer(affordable):onChange(function()
		if not Fusion.peek(affordable) then
			disarm()
		end
	end)
	RebirthService.Notice:Connect(function(text: string)
		notice:set(text)
		HUDController:Toast(text)
	end)

	local function press()
		if Fusion.peek(busy) or not Fusion.peek(affordable) then
			return
		end
		if not Fusion.peek(armed) then
			armToken += 1
			local token = armToken
			armed:set(true)
			notice:set("")
			task.delay(Config.Rebirth.ConfirmWindow, function()
				if armToken == token then
					armed:set(false)
				end
			end)
			return
		end
		disarm()
		busy:set(true)
		task.spawn(function()
			local ok, reborn = pcall(function()
				return RebirthService:Rebirth()
			end)
			busy:set(false)
			if not ok then
				notice:set("Couldn't relocate the colony. Please try again.")
			elseif reborn then
				Sfx.play("Purchase")
				open:set(false) -- the server announces the rebirth to everyone
			end
		end)
	end

	table.insert(scope, UserInputService.InputBegan:Connect(function(input)
		if Fusion.peek(open) and (input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB) then
			open:set(false)
		end
	end))

	local function rulesPosition(right: boolean)
		return scope:Computed(function(use)
			if use(compact) then
				return UDim2.fromOffset(0, if right then 408 else 236)
			end
			return if right then UDim2.new(0.5, 6, 0, 236) else UDim2.fromOffset(0, 236)
		end)
	end
	local rulesSize = scope:Computed(function(use)
		return if use(compact) then UDim2.new(1, 0, 0, 160) else UDim2.new(0.5, -6, 0, 160)
	end)
	local canPress = scope:Computed(function(use)
		return use(affordable) and not use(busy)
	end)

	scope:New("ScreenGui")({
		Name = "Rebirth",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		-- Above the shop (20) and the index (21), so its dimmer covers their buttons.
		DisplayOrder = 22,
		Parent = player:WaitForChild("PlayerGui"),
		[Children] = {
			UI.hudButton(scope, hud, "REBIRTH", 26, {
				Name = "RebirthButton",
				Text = "REBIRTH",
				BackgroundColor3 = scope:Spring(scope:Computed(function(use)
					return if use(affordable) then UI.HUD_MINT else UI.HUD_GOLD
				end), 12, 1),
				Visible = buttonVisible,
				[OnEvent("Activated")] = function()
					open:set(true)
				end,
			}),
			scope:New("TextButton")({
				Name = "Dimmer", Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = Color3.fromRGB(8, 12, 15), BackgroundTransparency = 0.22,
				Text = "", AutoButtonColor = false, BorderSizePixel = 0,
				Visible = open, ZIndex = 2, Modal = true,
				[OnEvent("Activated")] = function()
					open:set(false)
				end,
			}),
			scope:New("Frame")({
				Name = "Panel", AnchorPoint = Vector2.new(0.5, 0.5),
				Position = scope:Computed(function(use)
					return UDim2.new(0.5, 0, 0.5, use(hud).inset / 2)
				end),
				Size = scope:Computed(function(use)
					return UDim2.fromOffset(use(width), use(height))
				end),
				BackgroundColor3 = UI.PANEL, BorderSizePixel = 0,
				Visible = open, ZIndex = 3, Active = true,
				[Children] = {
					UI.panelFill(scope),
					scope:New("UIScale")({ Scale = scale }),
					UI.body(scope, {
						Name = "Eyebrow", Position = UDim2.fromOffset(22, 14), Size = UDim2.new(1, -100, 0, 16),
						Text = "PERMANENT PROGRESSION", TextSize = 11, Font = Enum.Font.GothamBold,
						TextColor3 = UI.HUD_GOLD, TextXAlignment = Enum.TextXAlignment.Left,
					}),
					UI.label(scope, {
						Name = "Title", Position = UDim2.fromOffset(20, 31), Size = UDim2.new(1, -98, 0, 43),
						Text = "REBIRTH", TextSize = 38, TextColor3 = UI.WHITE, TextXAlignment = Enum.TextXAlignment.Left,
					}),
					UI.body(scope, {
						Name = "Description", Position = UDim2.fromOffset(22, 77), Size = UDim2.new(1, -44, 0, 28),
						Text = "Start fresh for stronger sales. Your index bonuses stay.", TextSize = 13,
						TextColor3 = UI.HUD_MUTED, TextXAlignment = Enum.TextXAlignment.Left,
						TextYAlignment = Enum.TextYAlignment.Top, TextWrapped = true,
						Visible = scope:Computed(function(use) return not use(short) end),
					}),
					UI.button(scope, {
						Name = "Close", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -18, 0, 18),
						Size = scope:Computed(function(use)
							local size = HudLayout.closeSize(44, use(scale))
							return UDim2.fromOffset(size, size)
						end),
						Text = "", BackgroundColor3 = UI.CARD,
						[Children] = {
							UI.hudIcon(scope, "close", { Position = UDim2.fromScale(0.22, 0.22), Size = UDim2.fromScale(0.56, 0.56) }),
						},
						[OnEvent("Activated")] = function() open:set(false) end,
					}),
					scope:New("ScrollingFrame")({
						Name = "Content", Position = scope:Computed(function(use) return UDim2.fromOffset(20, use(bodyTop)) end),
						Size = scope:Computed(function(use) return UDim2.new(1, -40, 0, use(height) - use(bodyTop) - 124) end),
						BackgroundTransparency = 1, BorderSizePixel = 0, ClipsDescendants = true,
						ScrollingDirection = Enum.ScrollingDirection.Y, ScrollBarThickness = 4,
						ScrollBarImageColor3 = UI.HUD_MUTED, VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
						CanvasSize = scope:Computed(function(use) return UDim2.fromOffset(0, if use(compact) then 572 else 400) end),
						[Children] = {
							card(scope, { Name = "Multiplier", Position = UDim2.fromOffset(0, 0), Size = UDim2.new(1, 0, 0, 108) }, {
								UI.body(scope, {
									Position = UDim2.fromOffset(14, 10), Size = UDim2.new(1, -124, 0, 16),
									Text = "REBIRTH SALE MULTIPLIER", TextSize = 11, Font = Enum.Font.GothamBold,
									TextColor3 = UI.HUD_GOLD, TextXAlignment = Enum.TextXAlignment.Left,
								}),
								UI.body(scope, {
									Name = "RebirthCount", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 10),
									Size = UDim2.fromOffset(90, 16), TextSize = 11, TextColor3 = UI.HUD_MUTED,
									TextXAlignment = Enum.TextXAlignment.Right,
									Text = scope:Computed(function(use) return "REBIRTH #" .. Format.number(use(rebirths) + 1) end),
								}),
								UI.body(scope, {
									Position = UDim2.fromOffset(14, 34), Size = UDim2.new(0.42, -14, 0, 16),
									Text = "NOW", TextSize = 11, TextColor3 = UI.HUD_MUTED,
								}),
								UI.label(scope, {
									Name = "CurrentMultiplier", Position = UDim2.fromOffset(14, 49), Size = UDim2.new(0.42, -14, 0, 43),
									TextScaled = true, TextColor3 = UI.WHITE,
									Text = scope:Computed(function(use) return multiplierText(use(rebirths)) end),
									[Children] = { scope:New("UITextSizeConstraint")({ MaxTextSize = 38 }) },
								}),
								UI.body(scope, {
									Position = UDim2.new(0.42, 0, 0, 50), Size = UDim2.new(0.16, 0, 0, 39),
									Text = "→", TextSize = 32, Font = Enum.Font.GothamBold, TextColor3 = UI.HUD_GOLD,
								}),
								UI.body(scope, {
									Position = UDim2.new(0.58, 0, 0, 34), Size = UDim2.new(0.42, -14, 0, 16),
									Text = "AFTER REBIRTH", TextSize = 11, TextColor3 = UI.HUD_MINT,
								}),
								UI.label(scope, {
									Name = "NextMultiplier", Position = UDim2.new(0.58, 0, 0, 49), Size = UDim2.new(0.42, -14, 0, 43),
									TextScaled = true, TextColor3 = UI.HUD_MINT,
									Text = scope:Computed(function(use) return multiplierText(use(rebirths) + 1) end),
									[Children] = { scope:New("UITextSizeConstraint")({ MaxTextSize = 38 }) },
								}),
							}),
							card(scope, { Name = "Cost", Position = UDim2.fromOffset(0, 120), Size = UDim2.new(1, 0, 0, 104) }, {
								UI.body(scope, {
									Position = UDim2.fromOffset(14, 10), Size = UDim2.new(0.55, -14, 0, 16),
									Text = "CASH REQUIRED", TextSize = 11, Font = Enum.Font.GothamBold,
									TextColor3 = UI.HUD_MUTED, TextXAlignment = Enum.TextXAlignment.Left,
								}),
								UI.body(scope, {
									Name = "Readiness", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 10),
									Size = UDim2.new(0.45, -14, 0, 16), TextSize = 11, Font = Enum.Font.GothamBold,
									TextScaled = true,
									[Children] = { scope:New("UITextSizeConstraint")({ MaxTextSize = 11, MinTextSize = 10 }) },
									TextXAlignment = Enum.TextXAlignment.Right,
									Text = scope:Computed(function(use)
										if use(affordable) then return "READY TO REBIRTH" end
										return Format.number(math.floor(math.clamp(use(cash) / use(cost), 0, 1) * 100)) .. "% READY"
									end),
									TextColor3 = scope:Computed(function(use) return if use(affordable) then UI.HUD_MINT else UI.HUD_GOLD end),
								}),
								UI.label(scope, {
									Name = "RequiredCash", Position = UDim2.fromOffset(14, 30), Size = UDim2.new(1, -28, 0, 32),
									TextScaled = true, TextColor3 = UI.HUD_GOLD, TextXAlignment = Enum.TextXAlignment.Left,
									Text = scope:Computed(function(use) return Format.cash(use(cost)) end),
									[Children] = { scope:New("UITextSizeConstraint")({ MaxTextSize = 28 }) },
								}),
								UI.body(scope, {
									Name = "CashProgress", Position = UDim2.fromOffset(14, 65), Size = UDim2.new(1, -28, 0, 16),
									TextSize = 12, TextColor3 = UI.HUD_MUTED, TextXAlignment = Enum.TextXAlignment.Left,
									Text = scope:Computed(function(use) return "You have " .. Format.cash(use(cash)) .. " / " .. Format.cash(use(cost)) end),
								}),
								scope:New("Frame")({
									Name = "Progress", Position = UDim2.fromOffset(14, 87), Size = UDim2.new(1, -28, 0, 7),
									BackgroundColor3 = UI.PANEL_DARK, BorderSizePixel = 0,
									[Children] = {
										UI.corner(scope, 4),
										scope:New("Frame")({
											Name = "Fill", Size = scope:Computed(function(use)
												return UDim2.fromScale(math.clamp(use(cash) / use(cost), 0, 1), 1)
											end),
											BackgroundColor3 = scope:Computed(function(use) return if use(affordable) then UI.HUD_MINT else UI.HUD_GOLD end),
											BorderSizePixel = 0, [Children] = { UI.corner(scope, 4) },
										}),
									},
								}),
							}),
							rulesCard(scope, { Name = "Resets", Position = rulesPosition(false), Size = rulesSize, Caption = "WILL RESET" }, RESET_ROWS, UI.RED:Lerp(UI.WHITE, 0.25)),
							rulesCard(scope, { Name = "Keeps", Position = rulesPosition(true), Size = rulesSize, Caption = "YOU KEEP" }, KEEP_ROWS, UI.HUD_MINT),
						},
					}),
					scope:New("Frame")({
						Name = "FooterDivider", Position = UDim2.new(0, 20, 1, -118), Size = UDim2.new(1, -40, 0, 1),
						BackgroundColor3 = UI.HUD_BORDER, BorderSizePixel = 0,
					}),
					UI.button(scope, {
						Name = "Confirm", Position = UDim2.new(0, 20, 1, -108), Size = UDim2.new(1, -40, 0, 52),
						TextSize = 23, TextScaled = true, AutoButtonColor = canPress, Selectable = canPress,
						Text = scope:Computed(function(use)
							if use(busy) then return "RELOCATING..."
							elseif not use(affordable) then return "NEED " .. Format.cash(use(cost) - use(cash)) .. " MORE"
							elseif use(armed) then return "ARE YOU SURE?"
							end
							return "REBIRTH NOW"
						end),
						TextColor3 = scope:Computed(function(use)
							return if not use(affordable) or use(armed) then UI.WHITE else UI.HUD_SURFACE
						end),
						BackgroundColor3 = scope:Computed(function(use)
							if use(busy) or not use(affordable) then return UI.DISABLED end
							return if use(armed) then UI.RED else UI.HUD_MINT
						end),
						[Children] = { scope:New("UITextSizeConstraint")({ MaxTextSize = 23, MinTextSize = 14 }) },
						[OnEvent("Activated")] = press,
					}),
					UI.body(scope, {
						Name = "Footer", Position = UDim2.new(0, 20, 1, -48), Size = UDim2.new(1, -40, 0, 36),
						TextSize = 12, TextScaled = true, TextWrapped = true,
						[Children] = { scope:New("UITextSizeConstraint")({ MaxTextSize = 12, MinTextSize = 10 }) },
						Text = scope:Computed(function(use)
							local message = use(notice)
							if message ~= "" then return message
							elseif use(busy) then return "Relocating your colony..."
							elseif not use(affordable) then return "Reach " .. Format.cash(use(cost)) .. " cash to rebirth."
							elseif use(armed) then
								return "Press again within " .. Format.number(Config.Rebirth.ConfirmWindow) .. " s. This can't be undone."
							end
							return "Keep refinery level, Core Shards and index bonuses. Cash, gear and resources reset."
						end),
						TextColor3 = scope:Computed(function(use)
							return if use(armed) or use(notice) ~= "" then UI.RED:Lerp(UI.WHITE, 0.35) else UI.HUD_MUTED
						end),
					}),
				},
			}),
		},
	})
end

return RebirthController
