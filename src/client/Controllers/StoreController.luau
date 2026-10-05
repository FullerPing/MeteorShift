--!strict
-- Bind the editable StarterGui Store and its complete, authored catalog.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")
local UserInputService = game:GetService("UserInputService")
local Knit = require(ReplicatedStorage.Packages.Knit)
local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local StoreLayout = require(ReplicatedStorage.Shared.StoreLayout)
local NativeUI = require(script.Parent.Parent.NativeUI)
local ExactNavButton = require(script.Parent.Parent.ExactNavButton)
local player = Players.LocalPlayer
local Monetization = Config.Monetization
local StoreController = Knit.CreateController({ Name = "StoreController" })

type ButtonState = "buy" | "owned" | "offsale" | "unavailable" | "credit" | "loading"
type ProductDetails = { loading: boolean, price: number?, forSale: boolean?, image: string? }
type Card = {
	key: string, kind: "pass" | "product", id: number, intendedPrice: number?, details: ProductDetails,
	frame: Frame, price: TextLabel, title: TextLabel, description: TextLabel, status: TextLabel,
	well: Frame, icon: ImageLabel, buy: TextButton, accent: Color3,
}
local GOLD, MINT = Color3.fromRGB(255, 219, 100), Color3.fromRGB(139, 240, 195)
local ITEM_ICONS: { [string]: string } = {
	TwoXOre = "ore", BiggerBackpack = "backpack", OfflineHours = "bars", AutoDeposit = "foundry", VIP = "premium",
	CallMeteor = "meteor", Overclock = "foundry", TipJar = "premium", PocketChange = "coin", PetTreat = "premium",
	MiniOverclock = "foundry", OreRush = "ore", PetFeast = "premium", CashBundle = "coin", ExtraPetSlot = "plus",
}
local ITEM_ACCENTS: { [string]: Color3 } = {
	TwoXOre = GOLD, BiggerBackpack = NativeUI.CYAN, OfflineHours = MINT, AutoDeposit = MINT, VIP = GOLD,
	CallMeteor = NativeUI.ORANGE, Overclock = NativeUI.CYAN, TipJar = MINT, PocketChange = GOLD, PetTreat = NativeUI.CYAN,
	MiniOverclock = NativeUI.CYAN, OreRush = GOLD, PetFeast = NativeUI.ORANGE, CashBundle = GOLD, ExtraPetSlot = MINT,
}
local BUTTON_TEXT: { [ButtonState]: string } = {
	buy = "BUY", owned = "OWNED", offsale = "NOT ON SALE YET", unavailable = "UNAVAILABLE", credit = "USE CREDIT", loading = "LOADING",
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

function StoreController:KnitStart()
	local MonetizationService = Knit.GetService("MonetizationService")
	local PlayerStateService = Knit.GetService("PlayerStateService")
	local HUDController = Knit.GetController("HUDController")
	setUpChatTags()
	local gui = NativeUI.get("Store")
	local nav = gui:WaitForChild("StoreButton") :: TextButton
	local navRefs = ExactNavButton.bind(nav)
	local tooltip = navRefs.tooltip
	local dimmer = gui:WaitForChild("Dimmer") :: TextButton
	local panel = gui:WaitForChild("Panel") :: Frame
	local close = panel:WaitForChild("Close") :: TextButton
	local subtitle = panel:WaitForChild("Subtitle") :: TextLabel
	local list = panel:WaitForChild("List") :: ScrollingFrame
	local grid = list:WaitForChild("Grid") :: UIGridLayout
	local listPadding = list:WaitForChild("ListPadding") :: UIPadding
	local open = false
	local ownedPasses: { [string]: boolean } = {}
	local callMeteor = { available = false, reason = "" }
	local playerState: any = nil
	local cards: { Card } = {}
	local function credits(): number
		return if playerState and playerState.credits then playerState.credits.callMeteor or 0 else 0
	end
	local function buttonState(card: Card): ButtonState
		if card.kind == "pass" and ownedPasses[card.key] then return "owned" end
		if card.kind == "product" then
			if card.key == "OreRush" and ownedPasses.TwoXOre then return "unavailable" end
			if card.key == "CallMeteor" then
				if credits() > 0 and callMeteor.available then return "credit"
				elseif card.id == 0 then return "offsale"
				elseif not callMeteor.available then return "unavailable" end
			end
		end
		if card.id == 0 then return "offsale" end
		if card.details.loading then return "loading" end
		if card.details.forSale == false then return "offsale" end
		return if card.details.price == nil then "unavailable" else "buy"
	end
	local function statusText(card: Card): string
		if card.kind ~= "product" then return "" end
		if card.key == "CallMeteor" then
			local parts = {}
			if not callMeteor.available and callMeteor.reason ~= "" then table.insert(parts, callMeteor.reason) end
			local n = credits()
			if n > 0 then table.insert(parts, "Credits: " .. Format.number(n)) end
			return table.concat(parts, "  ·  ")
		elseif card.key == "Overclock" or card.key == "MiniOverclock" then
			local left = if playerState then playerState.overclockLeft or 0 else 0
			return if left > 0 then "Active: " .. Format.number(math.ceil(left / 60)) .. " min left" else ""
		elseif card.key == "OreRush" then
			if ownedPasses.TwoXOre then return "You own 2x Ore" end
			local left = if playerState then playerState.oreBoostLeft or 0 else 0
			return if left > 0 then "Active: " .. Format.number(math.ceil(left / 60)) .. " min left" else ""
		end
		return ""
	end
	local function renderCards()
		for _, card in cards do
			local current, info = buttonState(card), card.details
			card.price.Text = if current == "credit" then "1 CREDIT" elseif info.loading then "LOADING PRICE"
				elseif info.price ~= nil then "R$ " .. Format.number(info.price)
				elseif info.forSale == false then "NOT ON SALE" else "NO PRICE"
			local status = statusText(card)
			if status == "" and not info.loading and info.forSale ~= false and info.price == nil then status = "Reopen the store to retry the price." end
			card.status.Text = status
			card.buy.Text = if card.key == "OreRush" and ownedPasses.TwoXOre then "You own 2x Ore"
				elseif current == "credit" then BUTTON_TEXT.credit .. " (" .. Format.number(credits()) .. ")" else BUTTON_TEXT[current]
			local enabled = current == "buy" or current == "credit"
			card.buy.Active, card.buy.Selectable, card.buy.AutoButtonColor = enabled, enabled, enabled
			card.buy.BackgroundColor3 = if current == "buy" then card.accent elseif current == "owned" or current == "credit" then MINT else Color3.fromRGB(73, 83, 94)
			card.buy.TextColor3 = if current == "buy" or current == "credit" or current == "owned" then NativeUI.WHITE else NativeUI.MUTED
			card.icon.Image = info.image or Config.HudIcons[ITEM_ICONS[card.key] or "premium"]
		end
	end
	local function loadPrice(card: Card)
		if card.id == 0 then return end -- No metadata request and no prompt for IDs0.
		card.details = { loading = true }
		renderCards()
		task.spawn(function()
			local ok, info = pcall(function()
				return MarketplaceService:GetProductInfoAsync(card.id, if card.kind == "pass" then Enum.InfoType.GamePass else Enum.InfoType.Product)
			end)
			if ok and type(info) == "table" then
				local iconId = info.IconImageAssetId
				card.details = {
					loading = false, price = if type(info.PriceInRobux) == "number" then info.PriceInRobux else nil,
					forSale = if type(info.IsForSale) == "boolean" then info.IsForSale else nil,
					image = if type(iconId) == "number" and iconId > 0 then "rbxassetid://" .. tostring(iconId) else nil,
				}
			else
				card.details = { loading = false }
				warn("[StoreController] price lookup failed:", card.id, info)
			end
			renderCards()
		end)
	end
	local function bindCard(key: string, kind: "pass" | "product", definition: any)
		local frame = list:WaitForChild(key) :: Frame
		local well = frame:WaitForChild("IconWell") :: Frame
		local card: Card = {
			key = key, kind = kind, id = definition.Id, intendedPrice = definition.Robux,
			details = { loading = definition.Id ~= 0, forSale = if definition.Id == 0 then false else nil, price = if definition.Id == 0 then definition.Robux else nil },
			frame = frame, price = frame:WaitForChild("Price") :: TextLabel, title = frame:WaitForChild("Title") :: TextLabel,
			description = frame:WaitForChild("Description") :: TextLabel, status = frame:WaitForChild("Status") :: TextLabel,
			well = well, icon = well:WaitForChild("ItemIcon") :: ImageLabel, buy = frame:WaitForChild("Buy") :: TextButton,
			accent = ITEM_ACCENTS[key] or NativeUI.CYAN,
		}
		table.insert(cards, card)
		card.buy.Activated:Connect(function()
			local current = buttonState(card)
			if current == "buy" then prompt(card.kind, card.id)
			elseif current == "credit" then
				task.spawn(function()
					local ok, called, reason = pcall(function() return MonetizationService:UseCallMeteorCredit() end)
					if ok and not called and reason then HUDController:Toast(reason) end
				end)
			end
		end)
	end
	for _, key in Monetization.PassOrder do bindCard(key, "pass", Monetization.Passes[key]) end
	for _, key in Monetization.ProductOrder do bindCard(key, "product", Monetization.Products[key]) end
	for _, card in cards do loadPrice(card) end
	local function updateNav()
		nav.Visible = not open and player:GetAttribute("ShopOpen") ~= true and player:GetAttribute("IndexOpen") ~= true
			and player:GetAttribute("RebirthOpen") ~= true and player:GetAttribute("TutorialCardInColumn") ~= true
	end
	local function setOpen(value: boolean)
		local changed = open ~= value
		open = value
		panel.Visible, dimmer.Visible = value, value
		player:SetAttribute("StoreOpen", value)
		updateNav()
		if value and changed then
			for _, card in cards do
				if card.id ~= 0 and not card.details.loading and card.details.price == nil then loadPrice(card) end
			end
		end
	end
	MonetizationService.Owned:Observe(function(value) ownedPasses = value or {} renderCards() end)
	MonetizationService.CallMeteor:Observe(function(value) if value then callMeteor = value renderCards() end end)
	PlayerStateService.State:Observe(function(value) playerState = value renderCards() end)
	MonetizationService.Notice:Connect(function(message: string) HUDController:Toast(message) end)
	nav.Activated:Connect(function() setOpen(true) end)
	close.Activated:Connect(function() setOpen(false) end)
	dimmer.Activated:Connect(function() setOpen(false) end)
	UserInputService.InputBegan:Connect(function(input)
		if open and (input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB) then setOpen(false) end
	end)
	for _, name in { "ShopOpen", "IndexOpen", "RebirthOpen", "TutorialCardInColumn" } do player:GetAttributeChangedSignal(name):Connect(updateNav) end
	local function hover(value: boolean)
		tooltip.Visible = value and nav.Visible and not NativeUI.hudLayout().touch
	end
	nav.MouseEnter:Connect(function() hover(true) end)
	nav.MouseLeave:Connect(function() hover(false) end)
	nav.SelectionGained:Connect(function() hover(true) end)
	nav.SelectionLost:Connect(function() hover(false) end)
	NativeUI.onLayoutChanged(function(layout)
		local g = StoreLayout.compute(layout.viewport, layout.inset, #cards)
		local width, height, gap, paddingList = g.width, g.height, g.gap, g.paddingList
		local cardWidth, cardHeight, compact, padding = g.cardWidth, g.cardHeight, g.compact, g.padding
		local iconSize, descriptionHeight, statusHeight = g.iconSize, g.descriptionHeight, g.statusHeight
		local priceY, titleY, descriptionY, statusY = g.priceY, g.titleY, g.descriptionY, g.statusY
		panel.Position, panel.Size = UDim2.new(0.5, 0, 0.5, layout.inset / 2), UDim2.fromOffset(width, height)
		subtitle.TextSize = if width < 480 then 12 else 15
		grid.CellSize, grid.CellPadding = UDim2.fromOffset(cardWidth, cardHeight), UDim2.fromOffset(gap, gap)
		grid.FillDirectionMaxCells = g.columns
		listPadding.PaddingLeft, listPadding.PaddingRight = UDim.new(0, paddingList), UDim.new(0, paddingList)
		listPadding.PaddingTop, listPadding.PaddingBottom = UDim.new(0, paddingList), UDim.new(0, paddingList)
		list.CanvasSize = UDim2.fromOffset(0, g.canvasHeight)
		for _, card in cards do
			card.frame.Size = UDim2.fromOffset(cardWidth, cardHeight)
			card.well.Size = UDim2.fromOffset(iconSize, iconSize)
			card.price.Position, card.price.Size = UDim2.fromOffset(padding, priceY), UDim2.fromOffset(cardWidth - 2 * padding, 28)
			card.price.TextSize = if compact then 18 else 24
			card.title.Position, card.title.Size = UDim2.fromOffset(padding, titleY), UDim2.fromOffset(cardWidth - 2 * padding, 44)
			card.title.TextSize = if compact then 17 else 24
			local constraint = card.title:FindFirstChildOfClass("UITextSizeConstraint") :: UITextSizeConstraint
			constraint.MaxTextSize = if compact then 17 else 24
			card.description.Position, card.description.Size = UDim2.fromOffset(padding, descriptionY), UDim2.fromOffset(cardWidth - 2 * padding, descriptionHeight)
			card.description.TextSize = if compact then 12 else 14
			card.status.Position, card.status.Size = UDim2.fromOffset(padding, statusY), UDim2.fromOffset(cardWidth - 2 * padding, statusHeight)
			card.buy.Size = UDim2.fromOffset(cardWidth - 2 * padding, 44)
		end
		ExactNavButton.layout(nav, layout, "STORE")
		if layout.touch then tooltip.Visible = false end
	end)
	gui.Enabled = true -- Persistent Store navigation stays visible when its panel closes.
	setOpen(false)
	renderCards()
end

return StoreController
