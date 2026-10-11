--!strict
-- Bind the editable StarterGui Store and its complete, authored catalog.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")
local UserInputService = game:GetService("UserInputService")
local Knit = require(ReplicatedStorage.Packages.Knit)
local Config = require(ReplicatedStorage.Shared.Config)
local CallMeteorRules = require(ReplicatedStorage.Shared.CallMeteor)
local Format = require(ReplicatedStorage.Shared.Format)
local StoreLayout = require(ReplicatedStorage.Shared.StoreLayout)
local NativeUI = require(script.Parent.Parent.NativeUI)
local StoreMenu = require(script.Parent.Parent.NativeMenus.Store)
local ExactNavButton = require(script.Parent.Parent.ExactNavButton)
local Cartoon = require(script.Parent.Parent.Cartoon)
local player = Players.LocalPlayer
local Monetization = Config.Monetization
local StoreController = Knit.CreateController({ Name = "StoreController" })

type ButtonState = "buy" | "owned" | "offsale" | "unavailable" | "credit" | "loading"
type ProductDetails = { loading: boolean, price: number?, forSale: boolean?, image: string? }
type Card = {
	key: string, kind: "pass" | "product", id: number, intendedPrice: number?, details: ProductDetails,
	frame: Frame, price: TextLabel, title: TextLabel, description: TextLabel, status: TextLabel,
	well: Frame, icon: ImageLabel, buy: TextButton, accent: Color3,
	kindLabel: TextLabel, buyLabel: TextLabel, faces: { buy: GuiObject, owned: GuiObject, idle: GuiObject },
	wide: boolean,
}
local GOLD, MINT = Color3.fromRGB(255, 219, 100), Color3.fromRGB(139, 240, 195)
local ITEM_ICONS: { [string]: string } = {
	TwoXOre = "ore", BiggerBackpack = "backpack", OfflineHours = "bars", AutoDeposit = "foundry", VIP = "premium",
	CallMeteor = "meteor", Overclock = "foundry", TipJar = "premium", PocketChange = "coin",
	MiniOverclock = "foundry", OreRush = "ore", CashBundle = "coin", PetSlot = "plus",
	TwoXCash = "coin", StarterPack = "bars", PetMax = "pets", StreakShield = "premium",
	BossMeteor = "meteorAlien", Shards50 = "crystal", Shards250 = "crystal", Shards1000 = "crystal", RebirthKeep = "rebirth",
}
local ITEM_ACCENTS: { [string]: Color3 } = {
	TwoXOre = GOLD, BiggerBackpack = NativeUI.CYAN, OfflineHours = MINT, AutoDeposit = MINT, VIP = GOLD,
	CallMeteor = NativeUI.ORANGE, Overclock = NativeUI.CYAN, TipJar = MINT, PocketChange = GOLD,
	MiniOverclock = NativeUI.CYAN, OreRush = GOLD, CashBundle = GOLD, PetSlot = MINT,
	TwoXCash = GOLD, StarterPack = MINT, PetMax = NativeUI.ORANGE, StreakShield = NativeUI.CYAN,
	BossMeteor = NativeUI.ORANGE, Shards50 = NativeUI.CYAN, Shards250 = NativeUI.CYAN, Shards1000 = NativeUI.CYAN, RebirthKeep = MINT,
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

local function clearDecor(object: Instance)
	for _, child in object:GetChildren() do
		if child:IsA("UIStroke") or child:IsA("UICorner") or child:IsA("UIGradient") or child:IsA("UIPadding") or child.Name == "StudTexture" then
			child:Destroy()
		end
	end
end

local function outline(label: TextLabel, thickness: number, color: Color3)
	label.Font, label.TextColor3, label.TextStrokeTransparency = Cartoon.FONT, color, 1
	local old = label:FindFirstChild("TextOutline")
	if old then old:Destroy() end
	Cartoon.textStroke(thickness).Parent = label
end

-- Paint one authored card as a glossy coloured tile: a big floating icon, a
-- chunky title and a tall price button. Names and bindings stay as authored.
local function styleCard(frame: Frame, well: Frame, icon: ImageLabel, buy: TextButton, kind: string)
	frame.BackgroundTransparency = 1
	clearDecor(frame)
	Cartoon.surface(kind, { radius = 16, edge = 3.5, lip = 6, studs = 0.9, studSize = 34, name = "CardFace" }).Parent = frame
	well.BackgroundTransparency = 1
	clearDecor(well)
	icon.Size, icon.ZIndex = UDim2.fromScale(1, 1), 3
	local shadow = Instance.new("ImageLabel")
	shadow.Name, shadow.BackgroundTransparency, shadow.ScaleType = "IconShadow", 1, Enum.ScaleType.Fit
	shadow.AnchorPoint, shadow.Position, shadow.Size, shadow.ZIndex = Vector2.new(0.5, 0.5), UDim2.new(0.5, 3, 0.5, 5), UDim2.fromScale(1, 1), 2
	shadow.Image, shadow.ImageColor3, shadow.ImageTransparency = icon.Image, Cartoon.INK, 0.6
	shadow.Parent = well
	icon:GetPropertyChangedSignal("Image"):Connect(function() shadow.Image = icon.Image end)
	for _, name in { "Kind", "Title", "Description", "Status" } do
		local label = frame:FindFirstChild(name)
		if label and label:IsA("TextLabel") then
			outline(label, if name == "Title" then 3.5 else 2, if name == "Status" then Color3.fromRGB(255, 236, 140) else Color3.new(1, 1, 1))
			label.ZIndex = 5
		end
	end
	local price = frame:FindFirstChild("Price")
	if price and price:IsA("GuiObject") then price.Visible = false end -- the price is on the button
	buy.BackgroundTransparency, buy.TextTransparency, buy.TextStrokeTransparency, buy.AutoButtonColor = 1, 1, 1, false
	clearDecor(buy)
	local faces = {
		buy = Cartoon.surface("green", { radius = 14, edge = 3, lip = 5, studs = 0.86, studSize = 30, name = "BuyFace" }),
		owned = Cartoon.surface("blue", { radius = 14, edge = 3, lip = 5, stripes = false, name = "OwnedFace" }),
		idle = Cartoon.surface("slate", { radius = 14, edge = 3, lip = 5, stripes = false, name = "IdleFace" }),
	}
	for _, face in faces do face.Parent = buy end
	local label = Instance.new("TextLabel")
	label.Name, label.BackgroundTransparency, label.ZIndex = "Label", 1, 5
	label.Position, label.Size = UDim2.fromOffset(10, 0), UDim2.new(1, -20, 1, 0)
	label.Font, label.TextScaled, label.TextColor3, label.Text = Cartoon.FONT, true, Color3.new(1, 1, 1), buy.Text
	Cartoon.textStroke(3).Parent = label
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize, limit.MinTextSize, limit.Parent = 28, 10, label
	label.Parent = buy
	return faces, label
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
	local gui = NativeUI.get("Store", function(store)
		-- The authored copy keeps the owner's STORE nav button, but its panel can predate the sectioned page
		-- (no tab strip): swap in the panel built by NativeMenus.Store.
		if store:GetAttribute("StoreLayout") ~= 2 then
			local fresh = StoreMenu.build()
			store:WaitForChild("Panel"):Destroy()
			fresh:WaitForChild("Panel").Parent = store
			fresh:Destroy()
			store:SetAttribute("StoreLayout", 2)
		end
		-- The catalog draws its own cartoon cards and tabs; the ribbon goes blue like the reference.
		local storePanel = store:WaitForChild("Panel")
		storePanel:WaitForChild("List"):SetAttribute("CartoonCustom", true)
		storePanel:WaitForChild("Tabs"):SetAttribute("CartoonCustom", true)
		local header = storePanel:FindFirstChild("MenuHeader")
		if header and header:IsA("GuiObject") then header.BackgroundColor3 = NativeUI.CYAN end
	end)
	local nav = gui:WaitForChild("StoreButton") :: TextButton
	local navRefs = ExactNavButton.bind(nav)
	local tooltip = navRefs.tooltip
	local dimmer = gui:WaitForChild("Dimmer") :: TextButton
	local panel = gui:WaitForChild("Panel") :: Frame
	local close = panel:WaitForChild("Close") :: TextButton
	local subtitle = panel:WaitForChild("Subtitle") :: TextLabel
	local list = panel:WaitForChild("List") :: ScrollingFrame
	local tabs = panel:WaitForChild("Tabs") :: ScrollingFrame
	local sectionsLayout = list:WaitForChild("Sections") :: UIListLayout
	local listPadding = list:WaitForChild("ListPadding") :: UIPadding
	local open = false
	local ownedPasses: { [string]: boolean } = {}
	local callMeteor = { available = false, reason = "" }
	local playerState: any = nil
	local cards: { Card } = {}
	local function credits(key: string?): number
		return if playerState and playerState.credits then playerState.credits[key or "callMeteor"] or 0 else 0
	end
	-- Call a Meteor, Call a Boss Meteor and Rebirth Keep each have their own credit count
	local function creditKey(card: Card): string
		return if card.key == "BossMeteor" then "bossMeteor" elseif card.key == "RebirthKeep" then "rebirthKeep" else "callMeteor"
	end
	-- The boss meteor needs the boss rebirths: the reason shows on the card
	local function bossLocked(): string?
		local unlocked, why = CallMeteorRules.bossUnlocked(if playerState then playerState.rebirths or 0 else 0)
		return if unlocked then nil else why
	end
	local function buttonState(card: Card): ButtonState
		if card.kind == "pass" and ownedPasses[card.key] then return "owned" end
		if card.kind == "product" then
			-- one-off products read as owned once bought
			local bought = if playerState then playerState.purchased else nil
			if bought and ((card.key == "StarterPack" and bought.starterPack) or (card.key == "PetSlot" and bought.extraPetSlot)) then return "owned" end
			if card.key == "OreRush" and ownedPasses.TwoXOre then return "unavailable" end
			if card.key == "CallMeteor" or card.key == "BossMeteor" then
				local locked = card.key == "BossMeteor" and bossLocked() ~= nil
				if credits(creditKey(card)) > 0 and callMeteor.available and not locked then return "credit"
				elseif card.id == 0 then return "offsale"
				elseif not callMeteor.available or locked then return "unavailable" end
			end
		end
		if card.id == 0 then return "offsale" end
		if card.details.loading then return "loading" end
		if card.details.forSale == false then return "offsale" end
		return if card.details.price == nil then "unavailable" else "buy"
	end
	local function statusText(card: Card): string
		if card.kind ~= "product" then return "" end
		if card.key == "CallMeteor" or card.key == "BossMeteor" then
			local parts = {}
			local locked = if card.key == "BossMeteor" then bossLocked() else nil
			if locked then table.insert(parts, locked)
			elseif not callMeteor.available and callMeteor.reason ~= "" then table.insert(parts, callMeteor.reason) end
			local n = credits(creditKey(card))
			if n > 0 then table.insert(parts, "Credits: " .. Format.number(n)) end
			return table.concat(parts, "  ·  ")
		elseif card.key == "RebirthKeep" then
			local n = credits("rebirthKeep")
			return if n > 0 then "Ready for your next rebirth: " .. Format.number(n) else ""
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
				elseif current == "credit" then BUTTON_TEXT.credit .. " (" .. Format.number(credits(creditKey(card))) .. ")"
				elseif current == "buy" and info.price ~= nil then "R$ " .. Format.number(info.price) else BUTTON_TEXT[current]
			card.buyLabel.Text = card.buy.Text
			card.faces.buy.Visible = current == "buy" or current == "credit"
			card.faces.owned.Visible = current == "owned"
			card.faces.idle.Visible = not (current == "buy" or current == "credit" or current == "owned")
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
	local function bindCard(key: string, kind: "pass" | "product", definition: any, cardsFrame: Instance, color: string)
		local frame = cardsFrame:WaitForChild(key) :: Frame
		local well = frame:WaitForChild("IconWell") :: Frame
		local buy = frame:WaitForChild("Buy") :: TextButton
		local icon = well:WaitForChild("ItemIcon") :: ImageLabel
		local faces, buyLabel = styleCard(frame, well, icon, buy, color)
		local card: Card = {
			key = key, kind = kind, id = definition.Id, intendedPrice = definition.Robux,
			details = { loading = definition.Id ~= 0, forSale = if definition.Id == 0 then false else nil, price = if definition.Id == 0 then definition.Robux else nil },
			frame = frame, price = frame:WaitForChild("Price") :: TextLabel, title = frame:WaitForChild("Title") :: TextLabel,
			description = frame:WaitForChild("Description") :: TextLabel, status = frame:WaitForChild("Status") :: TextLabel,
			well = well, icon = icon, buy = buy, accent = ITEM_ACCENTS[key] or NativeUI.CYAN,
			kindLabel = frame:WaitForChild("Kind") :: TextLabel, buyLabel = buyLabel, faces = faces,
			wide = frame:GetAttribute("Wide") == true,
		}
		table.insert(cards, card)
		card.buy.Activated:Connect(function()
			local current = buttonState(card)
			if current == "buy" then prompt(card.kind, card.id)
			elseif current == "credit" then
				task.spawn(function()
					local ok, called, reason = pcall(function()
						return if card.key == "BossMeteor" then MonetizationService:UseBossMeteorCredit() else MonetizationService:UseCallMeteorCredit()
					end)
					if ok and not called and reason then HUDController:Toast(reason) end
				end)
			end
		end)
	end
	-- One titled section per Config.Store entry: bind its cards (styled in the section's colour) and its tab
	local sectionViews: { { section: any, frame: Frame, title: TextLabel, grid: UIGridLayout, cards: { Card }, tab: TextButton?, caption: TextLabel?, tabIcon: ImageLabel? } } = {}
	local function jumpTo(frame: GuiObject)
		local y = frame.AbsolutePosition.Y - list.AbsolutePosition.Y + list.CanvasPosition.Y - listPadding.PaddingTop.Offset
		list.CanvasPosition = Vector2.new(0, math.max(0, y))
	end
	for _, section in Config.Store.Sections do
		local frame = list:WaitForChild("Section_" .. section.Id) :: Frame
		local cardsFrame = frame:WaitForChild("Cards")
		local swatch = Cartoon.swatch(section.Color)
		local view = {
			section = section, frame = frame, title = frame:WaitForChild("SectionTitle") :: TextLabel,
			grid = cardsFrame:WaitForChild("Grid") :: UIGridLayout, cards = {} :: { Card },
			tab = tabs:FindFirstChild("Tab_" .. section.Id) :: TextButton?, caption = nil :: TextLabel?, tabIcon = nil :: ImageLabel?,
		}
		outline(view.title, 4, swatch.top)
		for _, key in section.Keys do
			local before = #cards
			local pass = Monetization.Passes[key]
			bindCard(key, if pass then "pass" else "product", pass or Monetization.Products[key], cardsFrame, section.Color)
			if #cards > before then table.insert(view.cards, cards[#cards]) end
		end
		local tab = view.tab
		if tab then
			Cartoon.surface(section.Color, { radius = 12, edge = 3, lip = 4, studs = 0.9, studSize = 30, name = "TabFace" }).Parent = tab
			view.caption, view.tabIcon = tab:WaitForChild("Caption") :: TextLabel, tab:WaitForChild("Icon") :: ImageLabel
			outline(view.caption :: TextLabel, 2.5, Color3.new(1, 1, 1))
			tab.Activated:Connect(function() jumpTo(view.frame) end)
		end
		table.insert(sectionViews, view)
	end
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
	local function applyCard(card: Card, c: any)
		card.frame.Size = UDim2.fromOffset(c.cardWidth, c.cardHeight)
		local align = if c.wide then Enum.TextXAlignment.Left else Enum.TextXAlignment.Center
		for _, label in { card.kindLabel, card.title, card.description, card.status } do label.TextXAlignment = align end
		card.kindLabel.Position, card.kindLabel.Size = UDim2.fromOffset(c.textX, c.kindY), UDim2.fromOffset(c.textWidth, 14)
		card.kindLabel.TextSize = 13
		if c.wide then
			card.well.AnchorPoint, card.well.Position = Vector2.zero, UDim2.fromOffset(c.iconX, c.iconY)
		else
			card.well.AnchorPoint, card.well.Position = Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, c.iconY)
		end
		card.well.Size = UDim2.fromOffset(c.iconSize, c.iconSize)
		card.title.Position, card.title.Size = UDim2.fromOffset(c.textX, c.titleY), UDim2.fromOffset(c.textWidth, c.titleHeight)
		local titleSize = if c.compact then 20 elseif c.titleHeight < 38 then 24 else 30
		card.title.TextSize = titleSize
		local constraint = card.title:FindFirstChildOfClass("UITextSizeConstraint") :: UITextSizeConstraint
		constraint.MaxTextSize = titleSize
		card.description.Position, card.description.Size = UDim2.fromOffset(c.textX, c.descriptionY), UDim2.fromOffset(c.textWidth, c.descriptionHeight)
		card.description.TextSize = if c.compact then 13 else 15
		card.status.Position, card.status.Size = UDim2.fromOffset(c.textX, c.statusY), UDim2.fromOffset(c.textWidth, c.statusHeight)
		card.status.TextSize = 14
		card.buy.Position = UDim2.new(0.5, 0, 1, if c.wide then -c.padding else -16)
		card.buy.Size = UDim2.fromOffset(c.cardWidth - 2 * c.padding, c.buttonHeight)
	end
	NativeUI.onLayoutChanged(function(layout)
		local g = StoreLayout.compute(layout.viewport, layout.inset)
		local height = g.height
		-- the panel is centred (AnchorPoint 0.5); short phones pin its top just under the top bar
		panel.Position = if g.top then UDim2.new(0.5, 0, 0, g.top + height / 2) else UDim2.new(0.5, 0, 0.5, layout.inset / 2)
		panel.Size = UDim2.fromOffset(g.width, height)
		subtitle.TextSize = if g.narrow then 12 else 15
		list.Position, list.Size = UDim2.fromOffset(14, 112), UDim2.new(0, g.listWidth, 1, -126)
		tabs.Visible = g.tabWidth > 0
		tabs.Position, tabs.Size = UDim2.new(1, -14 - g.tabWidth, 0, 112), UDim2.new(0, g.tabWidth, 1, -126)
		sectionsLayout.Padding = UDim.new(0, g.gap)
		listPadding.PaddingLeft, listPadding.PaddingRight = UDim.new(0, g.paddingList), UDim.new(0, g.paddingList)
		listPadding.PaddingTop, listPadding.PaddingBottom = UDim.new(0, g.paddingList), UDim.new(0, g.paddingList)
		list.ScrollBarImageColor3, list.ScrollBarThickness = Color3.fromRGB(28, 96, 214), 6
		for _, view in sectionViews do
			local style = view.section.Style
			local columns = StoreLayout.columns(g, style, #view.section.Keys)
			local c = StoreLayout.card(StoreLayout.cardWidth(g, columns), style, g.short)
			view.grid.CellSize, view.grid.CellPadding = UDim2.fromOffset(c.cardWidth, c.cardHeight), UDim2.fromOffset(g.gap, g.gap)
			view.grid.FillDirectionMaxCells = columns
			view.title.TextSize = if g.narrow then 26 else 34
			view.title.Size = UDim2.new(1, 0, 0, if g.narrow then 34 else 42)
			for _, card in view.cards do applyCard(card, c) end
			local tab, caption, tabIcon = view.tab, view.caption, view.tabIcon
			if tab and caption and tabIcon then
				tab.Size = UDim2.fromOffset(math.max(40, g.tabWidth - 6), if g.tabCaptions then 64 else 54)
				caption.Visible = g.tabCaptions
				tabIcon.Position = if g.tabCaptions then UDim2.new(0.5, -17, 0, 5) else UDim2.new(0.5, -17, 0.5, -17)
			end
		end
		ExactNavButton.layout(nav, layout, "STORE")
		if layout.touch then tooltip.Visible = false end
	end)
	gui.Enabled = true -- Persistent Store navigation stays visible when its panel closes.
	setOpen(false)
	renderCards()
end

return StoreController
