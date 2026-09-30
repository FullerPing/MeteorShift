--!strict
-- Store: game passes and developer products (spec §9). The STORE button sits under
-- REBIRTH in the HUD button column (hidden while the shop, index or rebirth panel is
-- open, or while the tutorial card takes the column on compact screens) and opens a
-- list of every pass and product from Config.Monetization with its description.
--
-- Each row's button prompts the purchase, or reads "Owned" for a pass you have, or
-- "Not on sale yet" while its Id is 0. Call a Meteor is disabled with the reason
-- while the server says it can't be called (MonetizationService's CallMeteor
-- property), so nobody pays for nothing; a Call a Meteor credit from a refunded
-- call can be spent from the same row. The server grants everything
-- (MonetizationService); this is presentation only.
--
-- VIP chat tag: players whose VIP attribute is set get Config.Monetization.VIPTag in
-- front of their name in TextChatService chat.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")
local UserInputService = game:GetService("UserInputService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local UI = require(script.Parent.Parent.UI)

local Children, OnEvent = Fusion.Children, Fusion.OnEvent
local player = Players.LocalPlayer
local Monetization = Config.Monetization

local StoreController = Knit.CreateController({ Name = "StoreController" })

type Scope = UI.Scope

-- What a row's button shows
type ButtonState = "buy" | "owned" | "offsale" | "unavailable" | "credit"

local PANEL_WIDTH, PANEL_HEIGHT = 620, 470
local ROW_HEIGHT, ROW_GAP = 84, 8
-- The HUD button column: SHOP at 296, then INDEX, REBIRTH, and STORE under REBIRTH
local BUTTON_WIDTH, BUTTON_HEIGHT, BUTTON_GAP = 138, 46, 10
local STORE_BUTTON_Y = 296 + 3 * (BUTTON_HEIGHT + BUTTON_GAP)

local BUTTON_TEXT: { [ButtonState]: string } = {
	buy = "BUY",
	owned = "OWNED",
	offsale = "NOT ON SALE YET",
	unavailable = "UNAVAILABLE",
	credit = "USE CREDIT",
}

-- Adds the VIP tag to chat messages from VIP players (TextChatService only).
local function setUpVipTag()
	if TextChatService.ChatVersion ~= Enum.ChatVersion.TextChatService then
		return
	end
	local ok, err = pcall(function()
		TextChatService.OnIncomingMessage = function(message: TextChatMessage): TextChatMessageProperties?
			local source = message.TextSource
			local speaker = if source then Players:GetPlayerByUserId(source.UserId) else nil
			if not speaker or speaker:GetAttribute("VIP") ~= true then
				return nil
			end
			local properties = Instance.new("TextChatMessageProperties")
			properties.PrefixText = string.format(
				'<font color="%s">%s</font> %s',
				Monetization.VIPTagColor,
				Monetization.VIPTag,
				message.PrefixText
			)
			return properties
		end
	end)
	if not ok then
		warn("[StoreController] VIP chat tag unavailable:", err)
	end
end

local function prompt(kind: "pass" | "product", id: number)
	if id == 0 then
		return -- not on sale: never prompt
	end
	local ok, err = pcall(function()
		if kind == "pass" then
			MarketplaceService:PromptGamePassPurchase(player, id)
		else
			MarketplaceService:PromptProductPurchase(player, id)
		end
	end)
	if not ok then
		warn("[StoreController] purchase prompt failed:", err)
	end
end

-- One store row: name, description, a status line and the buy button.
local function row(
	scope: Scope,
	props: {
		Name: string,
		Order: number,
		Title: string,
		Description: string,
		Status: any, -- Fusion state of the status line text ("" hides it)
		State: any, -- Fusion state of ButtonState
		ButtonText: any, -- Fusion state of the button text
		OnPress: () -> (),
	}
)
	return scope:New("Frame")({
		Name = props.Name,
		LayoutOrder = props.Order,
		Size = UDim2.new(1, -8, 0, ROW_HEIGHT),
		BackgroundColor3 = UI.CARD,
		[Children] = {
			UI.corner(scope, 12),
			UI.label(scope, {
				Position = UDim2.fromOffset(14, 8),
				Size = UDim2.new(1, -220, 0, 26),
				Text = props.Title,
				TextSize = 22,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			UI.body(scope, {
				Position = UDim2.fromOffset(14, 34),
				Size = UDim2.new(1, -220, 0, 30),
				Text = props.Description,
				TextSize = 12,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Top,
			}),
			UI.body(scope, {
				Position = UDim2.fromOffset(14, 64),
				Size = UDim2.new(1, -220, 0, 16),
				Text = props.Status,
				TextSize = 12,
				TextColor3 = UI.ORANGE,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			UI.button(scope, {
				Name = "Buy",
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -12, 0.5, 0),
				Size = UDim2.fromOffset(186, 48),
				TextScaled = true,
				Text = props.ButtonText,
				AutoButtonColor = scope:Computed(function(use)
					local state = use(props.State)
					return state == "buy" or state == "credit"
				end),
				BackgroundColor3 = scope:Computed(function(use)
					local state = use(props.State)
					if state == "buy" then
						return UI.CASH
					elseif state == "owned" or state == "credit" then
						return UI.GREEN
					end
					return UI.DISABLED
				end),
				TextColor3 = scope:Computed(function(use)
					local state = use(props.State)
					return if state == "offsale" or state == "unavailable" then UI.WHITE else UI.OUTLINE
				end),
				[Children] = {
					scope:New("UIPadding")({
						PaddingLeft = UDim.new(0, 10),
						PaddingRight = UDim.new(0, 10),
						PaddingTop = UDim.new(0, 8),
						PaddingBottom = UDim.new(0, 8),
					}),
					scope:New("UITextSizeConstraint")({ MaxTextSize = 22 }),
				},
				[OnEvent("Activated")] = props.OnPress,
			}),
		},
	})
end

function StoreController:KnitStart()
	local MonetizationService = Knit.GetService("MonetizationService")
	local PlayerStateService = Knit.GetService("PlayerStateService")
	local HUDController = Knit.GetController("HUDController")

	setUpVipTag()

	local scope = Fusion.scoped(Fusion)
	local open = scope:Value(false)
	scope:Observer(open):onBind(function()
		player:SetAttribute("StoreOpen", Fusion.peek(open))
	end)

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
	local rebirthOpen = playerFlag("RebirthOpen")
	local tutorialInColumn = playerFlag("TutorialCardInColumn")
	-- The shop, index and rebirth panels sit below this one; STORE would draw over
	-- their dimmers. On compact screens the tutorial card covers this spot too.
	local buttonVisible = scope:Computed(function(use)
		return not use(open)
			and not use(shopOpen)
			and not use(indexOpen)
			and not use(rebirthOpen)
			and not use(tutorialInColumn)
	end)

	-- Same sizing as the other panels: the panel scales to fit the screen height
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

	local ownedPasses = scope:Value({} :: { [string]: boolean })
	MonetizationService.Owned:Observe(function(value)
		ownedPasses:set(value or {})
	end)
	local callMeteor = scope:Value({ available = false, reason = "" })
	MonetizationService.CallMeteor:Observe(function(value)
		if value then
			callMeteor:set(value)
		end
	end)
	local playerState = scope:Value(nil :: any)
	PlayerStateService.State:Observe(function(value)
		playerState:set(value)
	end)
	local credits = scope:Computed(function(use): number
		local s = use(playerState)
		return if s and s.credits then s.credits.callMeteor or 0 else 0
	end)
	local overclockLeft = scope:Computed(function(use): number
		local s = use(playerState)
		return if s and s.overclockLeft then s.overclockLeft else 0
	end)
	MonetizationService.Notice:Connect(function(text: string)
		HUDController:Toast(text)
	end)

	table.insert(scope, UserInputService.InputBegan:Connect(function(input)
		if Fusion.peek(open) and (input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB) then
			open:set(false)
		end
	end))

	local rows = {}
	for order, key in Monetization.PassOrder do
		local pass = Monetization.Passes[key]
		local state = scope:Computed(function(use): ButtonState
			if use(ownedPasses)[key] then
				return "owned"
			end
			return if pass.Id == 0 then "offsale" else "buy"
		end)
		table.insert(rows, row(scope, {
			Name = key,
			Order = order,
			Title = pass.Name,
			Description = pass.Description,
			Status = "",
			State = state,
			ButtonText = scope:Computed(function(use)
				return BUTTON_TEXT[use(state)]
			end),
			OnPress = function()
				if Fusion.peek(state) == "buy" then
					prompt("pass", pass.Id)
				end
			end,
		}))
	end

	local passCount = #Monetization.PassOrder
	for index, key in Monetization.ProductOrder do
		local product = Monetization.Products[key]
		local state = scope:Computed(function(use): ButtonState
			if key == "CallMeteor" then
				local availability = use(callMeteor)
				if use(credits) > 0 and availability.available then
					return "credit"
				elseif product.Id == 0 then
					return "offsale"
				elseif not availability.available then
					return "unavailable"
				end
			end
			return if product.Id == 0 then "offsale" else "buy"
		end)
		local status = scope:Computed(function(use): string
			if key == "CallMeteor" then
				local parts = {}
				local availability = use(callMeteor)
				if not availability.available and availability.reason ~= "" then
					table.insert(parts, availability.reason)
				end
				local n = use(credits)
				if n > 0 then
					table.insert(parts, "Credits: " .. Format.number(n))
				end
				return table.concat(parts, "  ·  ")
			elseif key == "Overclock" then
				local left = use(overclockLeft)
				return if left > 0 then "Active: " .. Format.number(math.ceil(left / 60)) .. " min left" else ""
			end
			return ""
		end)
		table.insert(rows, row(scope, {
			Name = key,
			Order = passCount + index,
			Title = product.Name,
			Description = product.Description,
			Status = status,
			State = state,
			ButtonText = scope:Computed(function(use)
				local current = use(state)
				if current == "credit" then
					return BUTTON_TEXT.credit .. " (" .. Format.number(use(credits)) .. ")"
				end
				return BUTTON_TEXT[current]
			end),
			OnPress = function()
				local current = Fusion.peek(state)
				if current == "buy" then
					prompt("product", product.Id)
				elseif current == "credit" then
					task.spawn(function()
						local ok, called, reason = pcall(function()
							return MonetizationService:UseCallMeteorCredit()
						end)
						if ok and not called and reason then
							HUDController:Toast(reason)
						end
					end)
				end
			end,
		}))
	end

	local listHeight = #rows * (ROW_HEIGHT + ROW_GAP)

	scope:New("ScreenGui")({
		Name = "Store",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		-- Above the shop (20), the index (21) and rebirth (22)
		DisplayOrder = 23,
		Parent = player:WaitForChild("PlayerGui"),
		[Children] = {
			UI.button(scope, {
				Name = "StoreButton",
				AnchorPoint = Vector2.new(1, 0),
				Position = scope:Computed(function(use)
					return UDim2.new(1, -18, 0, 36 + STORE_BUTTON_Y * use(hudScale))
				end),
				Size = UDim2.fromOffset(BUTTON_WIDTH, BUTTON_HEIGHT),
				Text = "STORE",
				TextSize = 28,
				BackgroundColor3 = UI.SHARD,
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
					UI.label(scope, {
						Position = UDim2.fromOffset(22, 12),
						Size = UDim2.new(1, -90, 0, 37),
						Text = "STORE",
						TextSize = 32,
						TextColor3 = UI.SHARD,
						TextXAlignment = Enum.TextXAlignment.Left,
					}),
					UI.body(scope, {
						Position = UDim2.fromOffset(24, 53),
						Size = UDim2.new(1, -48, 0, 40),
						TextSize = 15,
						TextWrapped = true,
						TextXAlignment = Enum.TextXAlignment.Left,
						TextYAlignment = Enum.TextYAlignment.Top,
						Text = "Passes last forever. Nothing here changes meteor or mineral odds.",
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
					scope:New("ScrollingFrame")({
						Name = "List",
						Position = UDim2.fromOffset(9, 104),
						Size = UDim2.new(1, -18, 1, -113),
						BackgroundColor3 = UI.PANEL_DARK,
						BorderSizePixel = 0,
						CanvasSize = UDim2.fromOffset(0, listHeight + 12),
						ScrollingDirection = Enum.ScrollingDirection.Y,
						ScrollBarThickness = 5,
						ScrollBarImageColor3 = UI.CASH,
						[Children] = {
							UI.corner(scope, 12),
							scope:New("UIPadding")({
								PaddingLeft = UDim.new(0, 8),
								PaddingTop = UDim.new(0, 8),
								PaddingRight = UDim.new(0, 8),
							}),
							scope:New("UIListLayout")({
								Padding = UDim.new(0, ROW_GAP),
								SortOrder = Enum.SortOrder.LayoutOrder,
							}),
							rows,
						},
					}),
				},
			}),
		},
	})
end

return StoreController
