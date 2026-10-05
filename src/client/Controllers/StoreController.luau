--!strict
-- Store: game passes and developer products (spec §9). The STORE button sits under
-- REBIRTH in the HUD button column (hidden while the shop, index or rebirth panel is
-- open, or while the tutorial card takes the column on compact screens) and opens a
-- list of every pass and product from Config.Monetization with its description.
--
-- Each card's button prompts the purchase, or reads "Owned" for a pass you have, or
-- "Not on sale yet" while its Id is 0. Call a Meteor is disabled with the reason
-- while the server says it can't be called (MonetizationService's CallMeteor
-- property), so nobody pays for nothing; a Call a Meteor credit from a refunded
-- call can be spent from the same card. The server grants everything
-- (MonetizationService); this is presentation only.
--
-- VIP and session Supporter attributes add their tags in TextChatService chat.

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

-- What a card's button shows
type ButtonState = "buy" | "owned" | "offsale" | "unavailable" | "credit" | "loading"
type ProductDetails = {
	loading: boolean,
	price: number?,
	forSale: boolean?,
	image: string?,
}

local PANEL_WIDTH, PANEL_HEIGHT = 900, 680
local COLUMNS = 3
local ITEM_ICONS: { [string]: string } = {
	TwoXOre = "ore",
	BiggerBackpack = "backpack",
	OfflineHours = "bars",
	AutoDeposit = "foundry",
	VIP = "premium",
	CallMeteor = "meteor",
	Overclock = "foundry",
	TipJar = "premium",
	PocketChange = "coin",
	PetTreat = "premium",
	MiniOverclock = "foundry",
	OreRush = "ore",
	PetFeast = "premium",
	CashBundle = "coin",
	ExtraPetSlot = "plus",
}
local ITEM_ACCENTS: { [string]: Color3 } = {
	TwoXOre = UI.HUD_GOLD,
	BiggerBackpack = UI.SHARD,
	OfflineHours = UI.HUD_MINT,
	AutoDeposit = UI.HUD_MINT,
	VIP = UI.HUD_GOLD,
	CallMeteor = UI.ORANGE,
	Overclock = UI.SHARD,
	TipJar = UI.HUD_MINT,
	PocketChange = UI.HUD_GOLD,
	PetTreat = UI.SHARD,
	MiniOverclock = UI.SHARD,
	OreRush = UI.HUD_GOLD,
	PetFeast = UI.ORANGE,
	CashBundle = UI.HUD_GOLD,
	ExtraPetSlot = UI.HUD_MINT,
}

local BUTTON_TEXT: { [ButtonState]: string } = {
	buy = "BUY",
	owned = "OWNED",
	offsale = "NOT ON SALE YET",
	unavailable = "UNAVAILABLE",
	credit = "USE CREDIT",
	loading = "LOADING",
}

-- Attributes are session state, so a thank-you tag grants no gameplay benefit.
local function setUpChatTags()
	if TextChatService.ChatVersion ~= Enum.ChatVersion.TextChatService then
		return
	end
	local ok, err = pcall(function()
		TextChatService.OnIncomingMessage = function(message: TextChatMessage): TextChatMessageProperties?
			local source = message.TextSource
			local speaker = if source then Players:GetPlayerByUserId(source.UserId) else nil
			if not speaker then
				return nil
			end
			local tags = {}
			if speaker:GetAttribute("VIP") == true then
				table.insert(tags, string.format('<font color="%s">%s</font>', Monetization.VIPTagColor, Monetization.VIPTag))
			end
			if speaker:GetAttribute("Supporter") == true then
				table.insert(tags, string.format('<font color="%s">%s</font>', Monetization.SupporterTagColor, Monetization.SupporterTag))
			end
			if #tags == 0 then return nil end
			local properties = Instance.new("TextChatMessageProperties")
			properties.PrefixText = table.concat(tags, " ") .. " " .. message.PrefixText
			return properties
		end
	end)
	if not ok then
		warn("[StoreController] chat tags unavailable:", err)
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

-- Zero-config entries never request Marketplace metadata. Live prices are read
-- on the client so the displayed amount also follows Roblox's regional pricing.
local function productDetails(scope: Scope, kind: "pass" | "product", id: number, intendedPrice: number?)
	local details = scope:Value({ loading = id ~= 0, forSale = if id == 0 then false else nil, price = if id == 0 then intendedPrice else nil } :: ProductDetails)
	local function load()
		if id == 0 then return end
		details:set({ loading = true })
		task.spawn(function()
			local ok, info = pcall(function()
				return MarketplaceService:GetProductInfoAsync(id, if kind == "pass" then Enum.InfoType.GamePass else Enum.InfoType.Product)
			end)
			if ok and type(info) == "table" then
				local iconId = info.IconImageAssetId
				details:set({
					loading = false,
					price = if type(info.PriceInRobux) == "number" then info.PriceInRobux else nil,
					forSale = if type(info.IsForSale) == "boolean" then info.IsForSale else nil,
					image = if type(iconId) == "number" and iconId > 0 then "rbxassetid://" .. tostring(iconId) else nil,
				})
			else
				details:set({ loading = false })
				warn("[StoreController] price lookup failed:", id, info)
			end
		end)
	end
	load()
	return details, function()
		local current = Fusion.peek(details)
		if id ~= 0 and not current.loading and current.price == nil then load() end
	end
end

-- Three columns at every viewport size. Cards grow taller on narrow phones
-- instead of shrinking the text; the list scrolls in real screen pixels.
local function itemCard(
	scope: Scope,
	props: {
		Name: string,
		Order: number,
		Title: string,
		Description: string,
		Status: any, -- Fusion state of the status line text ("" hides it)
		State: any, -- Fusion state of ButtonState
		ButtonText: any, -- Fusion state of the button text
		Details: any,
		Geometry: any,
		Kind: "pass" | "product",
		OnPress: () -> (),
	}
)
	local accent = ITEM_ACCENTS[props.Name] or UI.SHARD
	local function cardMetric(key: string)
		return scope:Computed(function(use) return use(props.Geometry)[key] end)
	end
	local function section(yKey: string, heightKey: string)
		return scope:Computed(function(use)
			local g = use(props.Geometry)
			return UDim2.fromOffset(g.padding, g[yKey])
		end), scope:Computed(function(use)
			local g = use(props.Geometry)
			return UDim2.fromOffset(g.cardWidth - 2 * g.padding, g[heightKey])
		end)
	end
	local pricePosition, priceSize = section("priceY", "priceHeight")
	local titlePosition, titleSize = section("titleY", "titleHeight")
	local descriptionPosition, descriptionSize = section("descriptionY", "descriptionHeight")
	local statusPosition, statusSize = section("statusY", "statusHeight")
	return scope:New("Frame")({
		Name = props.Name,
		LayoutOrder = props.Order,
		Size = scope:Computed(function(use)
			local g = use(props.Geometry)
			return UDim2.fromOffset(g.cardWidth, g.cardHeight)
		end),
		BackgroundColor3 = UI.CARD,
		BorderSizePixel = 0,
		[Children] = {
			UI.cardFill(scope),
			UI.body(scope, {
				Name = "Kind",
				Position = UDim2.fromOffset(4, 8),
				Size = UDim2.new(1, -8, 0, 14),
				Text = if props.Kind == "pass" then "GAME PASS" else "PRODUCT",
				Font = Enum.Font.GothamBold,
				TextSize = 10,
				TextColor3 = accent,
			}),
			scope:New("Frame")({
				Name = "IconWell",
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 0, 28),
				Size = scope:Computed(function(use)
					local size = use(props.Geometry).iconSize
					return UDim2.fromOffset(size, size)
				end),
				BackgroundColor3 = UI.PANEL_DARK,
				BorderSizePixel = 0,
				[Children] = {
					UI.corner(scope, 16),
					scope:New("UIStroke")({ Color = accent, Transparency = 0.55, Thickness = 1.5 }),
					UI.hudIcon(scope, ITEM_ICONS[props.Name] or "premium", {
						Name = "ItemIcon",
						AnchorPoint = Vector2.new(0.5, 0.5),
						Position = UDim2.fromScale(0.5, 0.5),
						Size = UDim2.fromScale(0.88, 0.88),
						Image = scope:Computed(function(use)
							return use(props.Details).image or Config.HudIcons[ITEM_ICONS[props.Name] or "premium"]
						end),
					}),
				},
			}),
			UI.label(scope, {
				Name = "Price",
				Position = pricePosition,
				Size = priceSize,
				Text = scope:Computed(function(use)
					local state = use(props.State)
					if state == "credit" then return "1 CREDIT" end
					local info = use(props.Details)
					if info.loading then return "LOADING PRICE" end
					if info.price ~= nil then return "R$ " .. Format.number(info.price) end
					return if info.forSale == false then "NOT ON SALE" else "NO PRICE"
				end),
				TextSize = cardMetric("priceTextSize"),
				TextScaled = true,
				TextWrapped = true,
				TextColor3 = UI.HUD_GOLD,
				TextStrokeTransparency = 1,
				[Children] = { scope:New("UITextSizeConstraint")({ MinTextSize = 12, MaxTextSize = 24 }) },
			}),
			UI.label(scope, {
				Name = "Title",
				Position = titlePosition,
				Size = titleSize,
				Text = props.Title,
				TextSize = cardMetric("titleTextSize"),
				TextScaled = true,
				TextWrapped = true,
				TextStrokeTransparency = 0.65,
				[Children] = { scope:New("UITextSizeConstraint")({ MinTextSize = 12, MaxTextSize = cardMetric("titleTextSize") }) },
			}),
			UI.body(scope, {
				Name = "Description",
				Position = descriptionPosition,
				Size = descriptionSize,
				Text = props.Description,
				TextSize = cardMetric("bodyTextSize"),
				TextColor3 = UI.HUD_MUTED,
				TextWrapped = true,
				TextYAlignment = Enum.TextYAlignment.Top,
			}),
			UI.body(scope, {
				Name = "Status",
				Position = statusPosition,
				Size = statusSize,
				Text = scope:Computed(function(use)
					local status = use(props.Status)
					if status ~= "" then return status end
					local info = use(props.Details)
					return if not info.loading and info.forSale ~= false and info.price == nil
						then "Reopen the store to retry the price." else ""
				end),
				TextSize = 12,
				TextColor3 = UI.ORANGE,
				TextWrapped = true,
				TextYAlignment = Enum.TextYAlignment.Top,
			}),
			UI.button(scope, {
				Name = "Buy",
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.5, 0, 1, -12),
				Size = scope:Computed(function(use)
					local g = use(props.Geometry)
					return UDim2.fromOffset(g.cardWidth - 2 * g.padding, 44)
				end),
				TextScaled = true,
				TextWrapped = true,
				Text = props.ButtonText,
				AutoButtonColor = scope:Computed(function(use)
					local state = use(props.State)
					return state == "buy" or state == "credit"
				end),
				BackgroundColor3 = scope:Computed(function(use)
					local state = use(props.State)
					if state == "buy" then
						return accent
					elseif state == "owned" or state == "credit" then
						return UI.HUD_MINT
					end
					return UI.DISABLED
				end),
				TextColor3 = scope:Computed(function(use)
					local state = use(props.State)
					return if state == "buy" or state == "credit" or state == "owned" then UI.PANEL_DARK else UI.HUD_MUTED
				end),
				[Children] = {
					scope:New("UIPadding")({
						PaddingLeft = UDim.new(0, 4),
						PaddingRight = UDim.new(0, 4),
						PaddingTop = UDim.new(0, 4),
						PaddingBottom = UDim.new(0, 4),
					}),
					scope:New("UITextSizeConstraint")({ MinTextSize = 10, MaxTextSize = 21 }),
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

	setUpChatTags()

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

	-- Keep the modal and card text in screen pixels. Narrow screens scroll taller
	-- cards rather than applying a UIScale that makes three columns unreadable.
	local hud = UI.hud(scope)
	local geometry = scope:Computed(function(use)
		local l = use(hud)
		local width = math.min(PANEL_WIDTH, math.max(1, l.viewport.X - 24))
		local height = math.min(PANEL_HEIGHT, math.max(1, l.viewport.Y - l.inset - 24))
		local gap = if width < 480 then 8 else 12
		local listPadding = if width < 480 then 6 else 12
		local cardWidth = math.floor((width - 28 - 2 * listPadding - 6 - (COLUMNS - 1) * gap) / COLUMNS)
		local compact = cardWidth < 180
		local padding = if compact then 8 else 12
		local iconSize = math.clamp(math.floor(cardWidth * 0.40), 48, 100)
		local charactersPerLine = math.max(8, math.floor((cardWidth - 2 * padding) / 6.3))
		local descriptionHeight = if compact then math.max(96, math.ceil(130 / charactersPerLine) * 15) else 64
		local statusHeight = if compact then math.max(56, math.ceil(78 / charactersPerLine) * 15) else 42
		local priceY = 28 + iconSize + 6
		local titleY = priceY + 28 + 6
		local descriptionY = titleY + 44 + 6
		local statusY = descriptionY + descriptionHeight + 4
		return {
			width = width, height = height, gap = gap, listPadding = listPadding,
			cardWidth = cardWidth, cardHeight = statusY + statusHeight + 8 + 44 + 12,
			padding = padding, iconSize = iconSize,
			priceY = priceY, priceHeight = 28, priceTextSize = if compact then 18 else 24,
			titleY = titleY, titleHeight = 44, titleTextSize = if compact then 17 else 24,
			descriptionY = descriptionY, descriptionHeight = descriptionHeight,
			statusY = statusY, statusHeight = statusHeight, bodyTextSize = if compact then 12 else 14,
		}
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
	local oreBoostLeft = scope:Computed(function(use): number
		local s = use(playerState)
		return if s then s.oreBoostLeft or 0 else 0
	end)
	MonetizationService.Notice:Connect(function(text: string)
		HUDController:Toast(text)
	end)

	table.insert(scope, UserInputService.InputBegan:Connect(function(input)
		if Fusion.peek(open) and (input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB) then
			open:set(false)
		end
	end))

	local cards = {}
	local retryPrices: { () -> () } = {}
	for order, key in Monetization.PassOrder do
		local pass = Monetization.Passes[key]
		local details, retryPrice = productDetails(scope, "pass", pass.Id, pass.Robux)
		table.insert(retryPrices, retryPrice)
		local state = scope:Computed(function(use): ButtonState
			if use(ownedPasses)[key] then
				return "owned"
			end
			if pass.Id == 0 then return "offsale" end
			local info = use(details)
			if info.loading then return "loading" end
			if info.forSale == false then return "offsale" end
			return if info.price == nil then "unavailable" else "buy"
		end)
		table.insert(cards, itemCard(scope, {
			Name = key,
			Order = order,
			Title = pass.Name,
			Description = pass.Description,
			Status = "",
			State = state,
			Details = details,
			Geometry = geometry,
			Kind = "pass",
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
		local details, retryPrice = productDetails(scope, "product", product.Id, product.Robux)
		table.insert(retryPrices, retryPrice)
		local state = scope:Computed(function(use): ButtonState
			if key == "OreRush" and use(ownedPasses).TwoXOre then return "unavailable" end
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
			if product.Id == 0 then return "offsale" end
			local info = use(details)
			if info.loading then return "loading" end
			if info.forSale == false then return "offsale" end
			return if info.price == nil then "unavailable" else "buy"
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
			elseif key == "Overclock" or key == "MiniOverclock" then
				local left = use(overclockLeft)
				return if left > 0 then "Active: " .. Format.number(math.ceil(left / 60)) .. " min left" else ""
			elseif key == "OreRush" then
				if use(ownedPasses).TwoXOre then return "You own 2x Ore" end
				local left = use(oreBoostLeft)
				return if left > 0 then "Active: " .. Format.number(math.ceil(left / 60)) .. " min left" else ""
			end
			return ""
		end)
		table.insert(cards, itemCard(scope, {
			Name = key,
			Order = passCount + index,
			Title = product.Name,
			Description = product.Description,
			Status = status,
			State = state,
			Details = details,
			Geometry = geometry,
			Kind = "product",
			ButtonText = scope:Computed(function(use)
				local current = use(state)
				if key == "OreRush" and use(ownedPasses).TwoXOre then return "You own 2x Ore" end
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

	scope:Observer(open):onChange(function()
		if Fusion.peek(open) then
			for _, retryPrice in retryPrices do retryPrice() end
		end
	end)
	local listHeight = scope:Computed(function(use)
		local g = use(geometry)
		local rowCount = math.ceil(#cards / COLUMNS)
		return rowCount * g.cardHeight + math.max(0, rowCount - 1) * g.gap + 2 * g.listPadding
	end)

	scope:New("ScreenGui")({
		Name = "Store",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		-- Above the shop (20), the index (21) and rebirth (22)
		DisplayOrder = 23,
		Parent = player:WaitForChild("PlayerGui"),
		[Children] = {
			UI.hudButton(scope, hud, "STORE", 28, {
				Name = "StoreButton",
				Text = "STORE",
				BackgroundColor3 = UI.SHARD,
				Visible = buttonVisible,
				[OnEvent("Activated")] = function()
					open:set(true)
				end,
			}),
			scope:New("TextButton")({
				Name = "Dimmer",
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = Color3.fromRGB(8, 11, 14),
				BackgroundTransparency = 0.18,
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
				Position = scope:Computed(function(use)
					return UDim2.new(0.5, 0, 0.5, use(hud).inset / 2)
				end),
				Size = scope:Computed(function(use)
					local g = use(geometry)
					return UDim2.fromOffset(g.width, g.height)
				end),
				BackgroundColor3 = UI.HUD_SURFACE,
				Visible = open,
				ZIndex = 3,
				Active = true,
				[Children] = {
					UI.panelFill(scope),
					UI.hudIcon(scope, "premium", {
						Position = UDim2.fromOffset(20, 17),
						Size = UDim2.fromOffset(38, 38),
					}),
					UI.label(scope, {
						Position = UDim2.fromOffset(66, 12),
						Size = UDim2.new(1, -138, 0, 46),
						Text = "STORE",
						TextSize = 36,
						TextColor3 = UI.HUD_GOLD,
						TextXAlignment = Enum.TextXAlignment.Left,
					}),
					UI.body(scope, {
						Position = UDim2.fromOffset(20, 65),
						Size = UDim2.new(1, -40, 0, 38),
						TextSize = scope:Computed(function(use) return if use(geometry).width < 480 then 12 else 15 end),
						TextColor3 = UI.HUD_MUTED,
						TextWrapped = true,
						TextXAlignment = Enum.TextXAlignment.Left,
						TextYAlignment = Enum.TextYAlignment.Top,
						Text = "Passes last forever. Nothing here changes meteor or mineral odds.",
					}),
					UI.button(scope, {
						Name = "Close",
						AnchorPoint = Vector2.new(1, 0),
						Position = UDim2.new(1, -18, 0, 18),
						Size = UDim2.fromOffset(44, 44),
						Text = "",
						BackgroundColor3 = UI.RED,
						[Children] = {
							UI.hudIcon(scope, "close", {
								AnchorPoint = Vector2.new(0.5, 0.5),
								Position = UDim2.fromScale(0.5, 0.5),
								Size = UDim2.fromOffset(24, 24),
							}),
						},
						[OnEvent("Activated")] = function()
							open:set(false)
						end,
					}),
					scope:New("ScrollingFrame")({
						Name = "List",
						Position = UDim2.fromOffset(14, 112),
						Size = UDim2.new(1, -28, 1, -126),
						BackgroundColor3 = UI.PANEL_DARK,
						BorderSizePixel = 0,
						CanvasSize = scope:Computed(function(use) return UDim2.fromOffset(0, use(listHeight)) end),
						ScrollingDirection = Enum.ScrollingDirection.Y,
						ScrollBarThickness = 5,
						ScrollBarImageColor3 = UI.HUD_GOLD,
						VerticalScrollBarInset = Enum.ScrollBarInset.Always,
						[Children] = {
							UI.corner(scope, 12),
							scope:New("UIPadding")({
								PaddingLeft = scope:Computed(function(use) return UDim.new(0, use(geometry).listPadding) end),
								PaddingTop = scope:Computed(function(use) return UDim.new(0, use(geometry).listPadding) end),
								PaddingRight = scope:Computed(function(use) return UDim.new(0, use(geometry).listPadding) end),
								PaddingBottom = scope:Computed(function(use) return UDim.new(0, use(geometry).listPadding) end),
							}),
							scope:New("UIGridLayout")({
								FillDirection = Enum.FillDirection.Horizontal,
								FillDirectionMaxCells = COLUMNS,
								HorizontalAlignment = Enum.HorizontalAlignment.Center,
								CellPadding = scope:Computed(function(use)
									local gap = use(geometry).gap
									return UDim2.fromOffset(gap, gap)
								end),
								CellSize = scope:Computed(function(use)
									local g = use(geometry)
									return UDim2.fromOffset(g.cardWidth, g.cardHeight)
								end),
								SortOrder = Enum.SortOrder.LayoutOrder,
							}),
							cards,
						},
					}),
				},
			}),
		},
	})
end

return StoreController
