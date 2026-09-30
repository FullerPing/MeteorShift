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
local Rebirth = require(ReplicatedStorage.Shared.Rebirth)
local UI = require(script.Parent.Parent.UI)

local Children, OnEvent = Fusion.Children, Fusion.OnEvent
local player = Players.LocalPlayer

local RebirthController = Knit.CreateController({ Name = "RebirthController" })

type Scope = UI.Scope

local PANEL_WIDTH, PANEL_HEIGHT = 620, 470
-- The HUD button column: SHOP at 296, INDEX one button below it, REBIRTH under INDEX
local BUTTON_WIDTH, BUTTON_HEIGHT, BUTTON_GAP = 138, 46, 10
local REBIRTH_BUTTON_Y = 296 + 2 * (BUTTON_HEIGHT + BUTTON_GAP)

local RESETS = "• Cash, back to $0\n• Pickaxe, back to Tier 1\n• Backpack, back to Tier 1\n• Ore in your backpack"
local KEEPS = "• Your production line, with its ore and bars\n• Bars you carry\n• Core Shards\n• Mineral index and titles"

local function multiplierText(rebirths: number): string
	return "×" .. Format.number(Rebirth.multiplier(rebirths))
end

-- A dark inset card with a small caption at the top.
local function card(scope: Scope, props: { Name: string, Position: UDim2, Size: UDim2, Caption: string, CaptionColor: Color3 }, children: { any })
	return scope:New("Frame")({
		Name = props.Name,
		Position = props.Position,
		Size = props.Size,
		BackgroundColor3 = UI.CARD,
		[Children] = {
			UI.corner(scope, 12),
			UI.body(scope, {
				Position = UDim2.fromOffset(14, 8),
				Size = UDim2.new(1, -28, 0, 16),
				Text = props.Caption,
				TextSize = 12,
				TextColor3 = props.CaptionColor,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			children,
		},
	})
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

	-- Same sizing as the shop and the index: the panel scales to fit the screen height
	local viewport = scope:Value(Vector2.new(1280, 720))
	local cameraConnection: RBXScriptConnection? = nil
	local function bindCamera()
		if cameraConnection then
			cameraConnection:Disconnect()
		end
		local camera = workspace.CurrentCamera
		if camera then
			cameraConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
				viewport:set(camera.ViewportSize)
			end)
			viewport:set(camera.ViewportSize)
		end
	end
	bindCamera()
	table.insert(scope, workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bindCamera))
	local scale = scope:Computed(function(use)
		return math.min(1, math.max(0.35, (use(viewport).Y - 52) / PANEL_HEIGHT))
	end)
	local hudScale = scope:Computed(function(use)
		local v = use(viewport)
		return math.clamp(math.min(v.X / 1050, v.Y / 760), 0.45, 1)
	end)
	local width = scope:Computed(function(use)
		return math.min(PANEL_WIDTH, (use(viewport).X - 24) / use(scale))
	end)
	local compact = scope:Computed(function(use)
		return use(width) < 560
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
				open:set(false) -- the server announces the rebirth to everyone
			end
		end)
	end

	table.insert(scope, UserInputService.InputBegan:Connect(function(input)
		if Fusion.peek(open) and (input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB) then
			open:set(false)
		end
	end))

	-- Two card columns inside the interior; returns (position, size)
	local function column(y: number, height: number, right: boolean): (UDim2, UDim2)
		return if right then UDim2.new(0.5, 6, 0, y) else UDim2.fromOffset(20, y), UDim2.new(0.5, -26, 0, height)
	end
	local multiplierPosition, topSize = column(118, 96, false)
	local costPosition = column(118, 96, true)
	local resetsPosition, listSize = column(226, 136, false)
	local keepsPosition = column(226, 136, true)

	scope:New("ScreenGui")({
		Name = "Rebirth",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		-- Above the shop (20) and the index (21), so its dimmer covers their buttons
		DisplayOrder = 22,
		Parent = player:WaitForChild("PlayerGui"),
		[Children] = {
			UI.button(scope, {
				Name = "RebirthButton",
				AnchorPoint = Vector2.new(1, 0),
				Position = scope:Computed(function(use)
					return UDim2.new(1, -18, 0, 36 + REBIRTH_BUTTON_Y * use(hudScale))
				end),
				Size = UDim2.fromOffset(BUTTON_WIDTH, BUTTON_HEIGHT),
				Text = "REBIRTH",
				TextSize = 26,
				-- Lights up while a rebirth is affordable
				BackgroundColor3 = scope:Spring(scope:Computed(function(use)
					return if use(affordable) then UI.GREEN else UI.ORANGE
				end), 12, 1),
				Visible = buttonVisible,
				[Children] = { scope:New("UIScale")({ Scale = hudScale }) },
				[OnEvent("Activated")] = function()
					open:set(true)
				end,
			}),
			scope:New("TextButton")({
				Name = "Dimmer",
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = Color3.fromRGB(9, 10, 16),
				BackgroundTransparency = 0.28,
				Text = "",
				AutoButtonColor = false,
				BorderSizePixel = 0,
				Visible = open,
				ZIndex = 2,
				Modal = true,
				[OnEvent("Activated")] = function()
					open:set(false)
				end,
			}),
			scope:New("Frame")({
				Name = "Panel",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = scope:Computed(function(use)
					return UDim2.fromOffset(use(width), PANEL_HEIGHT)
				end),
				BackgroundColor3 = UI.PANEL,
				Visible = open,
				ZIndex = 3,
				Active = true,
				[Children] = {
					UI.panelFill(scope),
					scope:New("UIScale")({ Scale = scale }),
					scope:New("Frame")({
						Name = "Interior",
						Position = UDim2.fromOffset(9, 104),
						Size = UDim2.new(1, -18, 1, -113),
						BackgroundColor3 = UI.PANEL_DARK,
						[Children] = { UI.corner(scope, 12) },
					}),
					UI.label(scope, {
						Position = UDim2.fromOffset(22, 12),
						Size = UDim2.new(1, -90, 0, 37),
						Text = "RELOCATE THE COLONY",
						TextSize = 32,
						TextScaled = true,
						TextColor3 = UI.ORANGE,
						TextXAlignment = Enum.TextXAlignment.Left,
						[Children] = { scope:New("UITextSizeConstraint")({ MaxTextSize = 32 }) },
					}),
					UI.body(scope, {
						Position = UDim2.fromOffset(24, 53),
						Size = UDim2.new(1, -48, 0, 40),
						TextSize = 15,
						TextWrapped = true,
						TextXAlignment = Enum.TextXAlignment.Left,
						TextYAlignment = Enum.TextYAlignment.Top,
						Text = scope:Computed(function(use)
							local count = use(rebirths)
							local done = if count > 0
								then "Rebirths so far: " .. Format.number(count) .. ". "
								else ""
							return done .. "Start over richer: every rebirth multiplies your bar sales for good."
						end),
					}),
					UI.button(scope, {
						Name = "Close",
						AnchorPoint = Vector2.new(1, 0),
						Position = UDim2.new(1, -18, 0, 18),
						Size = UDim2.fromOffset(42, 42),
						Text = "X",
						TextSize = 23,
						BackgroundColor3 = UI.RED,
						TextColor3 = UI.WHITE,
						[OnEvent("Activated")] = function()
							open:set(false)
						end,
					}),
					card(scope, {
						Name = "Multiplier",
						Position = multiplierPosition,
						Size = topSize,
						Caption = "CASH MULTIPLIER  ·  NOW  →  NEXT",
						CaptionColor = UI.SUBTEXT,
					}, {
						UI.label(scope, {
							Position = UDim2.fromOffset(14, 30),
							Size = UDim2.new(1, -28, 0, 52),
							TextScaled = true,
							TextColor3 = UI.CASH,
							Text = scope:Computed(function(use)
								local count = use(rebirths)
								return multiplierText(count) .. "  →  " .. multiplierText(count + 1)
							end),
							[Children] = { scope:New("UITextSizeConstraint")({ MaxTextSize = 38 }) },
						}),
					}),
					card(scope, {
						Name = "Cost",
						Position = costPosition,
						Size = topSize,
						Caption = "COST",
						CaptionColor = UI.SUBTEXT,
					}, {
						UI.label(scope, {
							Position = UDim2.fromOffset(14, 26),
							Size = UDim2.new(1, -28, 0, 30),
							TextScaled = true,
							TextXAlignment = Enum.TextXAlignment.Left,
							TextColor3 = UI.CASH,
							Text = scope:Computed(function(use)
								return Format.cash(use(cost))
							end),
							[Children] = { scope:New("UITextSizeConstraint")({ MaxTextSize = 28 }) },
						}),
						scope:New("Frame")({
							Name = "Progress",
							Position = UDim2.fromOffset(14, 62),
							Size = UDim2.new(1, -28, 0, 8),
							BackgroundColor3 = UI.OUTLINE,
							BorderSizePixel = 0,
							[Children] = {
								UI.corner(scope, 4),
								scope:New("Frame")({
									Size = scope:Computed(function(use)
										return UDim2.fromScale(math.clamp(use(cash) / use(cost), 0, 1), 1)
									end),
									BackgroundColor3 = scope:Computed(function(use)
										return if use(affordable) then UI.GREEN else UI.CASH
									end),
									BorderSizePixel = 0,
									[Children] = { UI.corner(scope, 4) },
								}),
							},
						}),
						UI.body(scope, {
							Position = UDim2.fromOffset(14, 74),
							Size = UDim2.new(1, -28, 0, 16),
							TextSize = 12,
							TextXAlignment = Enum.TextXAlignment.Left,
							Text = scope:Computed(function(use)
								local have, need = use(cash), use(cost)
								local percent = math.floor(math.clamp(have / need, 0, 1) * 100)
								return Format.cash(have) .. " / " .. Format.cash(need) .. "  (" .. percent .. "%)"
							end),
						}),
					}),
					card(scope, {
						Name = "Resets",
						Position = resetsPosition,
						Size = listSize,
						Caption = "RESETS",
						CaptionColor = UI.RED,
					}, {
						UI.body(scope, {
							Position = UDim2.fromOffset(14, 30),
							Size = UDim2.new(1, -28, 1, -38),
							Text = RESETS,
							TextSize = scope:Computed(function(use)
								return if use(compact) then 12 else 14
							end),
							TextWrapped = true,
							TextColor3 = UI.WHITE,
							TextXAlignment = Enum.TextXAlignment.Left,
							TextYAlignment = Enum.TextYAlignment.Top,
						}),
					}),
					card(scope, {
						Name = "Keeps",
						Position = keepsPosition,
						Size = listSize,
						Caption = "YOU KEEP",
						CaptionColor = UI.GREEN,
					}, {
						UI.body(scope, {
							Position = UDim2.fromOffset(14, 30),
							Size = UDim2.new(1, -28, 1, -38),
							Text = KEEPS,
							TextSize = scope:Computed(function(use)
								return if use(compact) then 12 else 14
							end),
							TextWrapped = true,
							TextColor3 = UI.WHITE,
							TextXAlignment = Enum.TextXAlignment.Left,
							TextYAlignment = Enum.TextYAlignment.Top,
						}),
					}),
					UI.button(scope, {
						Name = "Confirm",
						AnchorPoint = Vector2.new(0.5, 0),
						Position = UDim2.new(0.5, 0, 0, 376),
						Size = UDim2.fromOffset(300, 50),
						TextSize = 22,
						AutoButtonColor = affordable,
						Selectable = affordable,
						Text = scope:Computed(function(use)
							if use(busy) then
								return "RELOCATING..."
							elseif not use(affordable) then
								return "NEED " .. Format.cash(use(cost) - use(cash)) .. " MORE"
							elseif use(armed) then
								return "ARE YOU SURE?"
							end
							return "REBIRTH"
						end),
						TextColor3 = scope:Computed(function(use)
							return if not use(affordable) or use(armed) then UI.WHITE else UI.OUTLINE
						end),
						BackgroundColor3 = scope:Computed(function(use)
							if not use(affordable) then
								return UI.DISABLED
							end
							return if use(armed) then UI.RED else UI.GREEN
						end),
						[OnEvent("Activated")] = press,
					}),
					UI.body(scope, {
						Name = "Footer",
						Position = UDim2.new(0, 20, 0, 430),
						Size = UDim2.new(1, -40, 0, 30),
						TextSize = 13,
						TextWrapped = true,
						Text = scope:Computed(function(use)
							local message = use(notice)
							if message ~= "" then
								return message
							elseif not use(affordable) then
								return "Reach " .. Format.cash(use(cost)) .. " cash to relocate the colony."
							elseif use(armed) then
								return "Press again within "
									.. Format.number(Config.Rebirth.ConfirmWindow)
									.. " s to relocate. This can't be undone."
							end
							return "Bar sales go to " .. multiplierText(use(rebirths) + 1) .. " for good."
						end),
						TextColor3 = scope:Computed(function(use)
							return if use(armed) then UI.RED:Lerp(UI.WHITE, 0.3) else UI.SUBTEXT
						end),
					}),
				},
			}),
		},
	})
end

return RebirthController
