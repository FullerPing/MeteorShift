--!strict
-- Bind the editable StarterGui prefab; progression remains server-authoritative.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Knit = require(ReplicatedStorage.Packages.Knit)
local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Rebirth = require(ReplicatedStorage.Shared.Rebirth)
local RebirthLayout = require(ReplicatedStorage.Shared.RebirthLayout)
local ShopLayout = require(ReplicatedStorage.Shared.EquipmentShopLayout)
local Palette = require(ReplicatedStorage.Shared.MenuPalette)
local NativeUI = require(script.Parent.Parent.NativeUI)
local ExactNavButton = require(script.Parent.Parent.ExactNavButton)
local Sfx = require(script.Parent.Parent.Sfx)
local RewardFX = require(script.Parent.Parent.RewardFX)
local RebirthMenu = require(script.Parent.Parent.NativeMenus.Rebirth)
local Theme = require(script.Parent.Parent.MenuTheme)
local player = Players.LocalPlayer
local RebirthController = Knit.CreateController({ Name = "RebirthController" })
local wantOpen = false
local requestOpen: ((boolean) -> ())? = nil

function RebirthController:Open()
	wantOpen = true
	if requestOpen then requestOpen(true) end
end

local function multiplierText(rebirths: number): string
	local value = Rebirth.multiplier(rebirths)
	return (if value < 1000 then string.format("%.6g", value) else Format.number(value)) .. "×"
end

function RebirthController:KnitStart()
	local RebirthService = Knit.GetService("RebirthService")
	local PlayerStateService = Knit.GetService("PlayerStateService")
	local HUDController = Knit.GetController("HUDController")
	-- The saved prefab keeps the owner's REBIRTH nav tile, but its panel can predate the current layout
	-- (no RebirthLayout mark): swap in the panel NativeMenus.Rebirth builds, before the shared skin runs
	local gui = NativeUI.get("Rebirth", function(rebirth)
		if rebirth:GetAttribute("RebirthLayout") == RebirthMenu.LAYOUT then return end
		local fresh = RebirthMenu.build()
		rebirth:WaitForChild("Panel"):Destroy()
		-- the dimmer too (the cartoon light menus sit on a light navy wash), moved first so the panel draws over it
		local oldDimmer = rebirth:FindFirstChild("Dimmer")
		if oldDimmer then oldDimmer:Destroy() end
		fresh:WaitForChild("Dimmer").Parent = rebirth
		fresh:WaitForChild("Panel").Parent = rebirth
		fresh:Destroy()
		rebirth:SetAttribute("RebirthLayout", RebirthMenu.LAYOUT)
	end)
	local panel = gui:WaitForChild("Panel") :: Frame
	local nav = gui:WaitForChild("RebirthButton") :: TextButton
	local navRefs = ExactNavButton.bind(nav)
	local dimmer = gui:WaitForChild("Dimmer") :: TextButton
	local close = panel:WaitForChild("Close") :: TextButton
	local content = panel:WaitForChild("Content") :: ScrollingFrame
	local compare = content:WaitForChild("Compare") :: Frame
	local currentMultiplier = compare:WaitForChild("CurrentBox"):WaitForChild("CurrentMultiplier") :: TextLabel
	local nextMultiplier = compare:WaitForChild("AfterBox"):WaitForChild("NextMultiplier") :: TextLabel
	local priceNote = content:WaitForChild("PriceNote") :: TextLabel
	local requirement = panel:WaitForChild("Requirement") :: Frame
	local reqLabel = requirement:WaitForChild("ReqLabel") :: TextLabel
	local cashProgress = requirement:WaitForChild("CashProgress") :: TextLabel
	local progressBar = requirement:WaitForChild("ProgressBar") :: Frame
	local progressFill = progressBar:WaitForChild("Fill") :: Frame
	local percent = requirement:WaitForChild("Percent") :: TextLabel
	local confirm = panel:WaitForChild("Confirm") :: TextButton
	local keepButton = panel:WaitForChild("Keep") :: TextButton
	local keepCard = panel:WaitForChild("KeepCard") :: Frame
	local perksButton = panel:WaitForChild("PerksButton") :: TextButton
	local wallet = panel:WaitForChild("Wallet") :: TextLabel
	local footer = panel:WaitForChild("Footer") :: TextLabel
	local wide = false
	local ready = navRefs.badge
	local tooltip = navRefs.tooltip
	local state: any = nil
	local open, armed, busy, notice = wantOpen, false, false, ""
	local keepProduct = Config.Monetization.Products.RebirthKeep
	local keepPrice: number? = if keepProduct.Id == 0 then keepProduct.Robux else nil -- the live price replaces it
	local pendingKeep = false -- the player is buying Rebirth and Keep Everything: rebirth as soon as it is theirs
	local perform: () -> ()
	local armToken = 0
	local GOLD, MINT = Color3.fromRGB(255, 219, 100), Color3.fromRGB(139, 240, 195)
	local function affordable(): boolean
		return state ~= nil and state.cash >= Rebirth.cost(state.rebirths or 0)
	end
	local function disarm()
		armToken += 1
		armed = false
	end
	local function update()
		local cash = if state then state.cash else 0
		local rebirths = if state then state.rebirths or 0 else 0
		local cost = Rebirth.cost(rebirths)
		local canAfford = affordable()
		panel.Visible, dimmer.Visible = open, open
		nav.Visible = not open and player:GetAttribute("ShopOpen") ~= true and player:GetAttribute("IndexOpen") ~= true and player:GetAttribute("TutorialCardInColumn") ~= true
		ready.Visible = canAfford
		ready.BackgroundColor3 = if canAfford then MINT else GOLD
		percent.TextColor3 = if canAfford then Palette.UP else Palette.NAVY
		currentMultiplier.Text, nextMultiplier.Text = multiplierText(rebirths), multiplierText(rebirths + 1)
		local gain = Rebirth.multiplier(rebirths + 1) / math.max(Rebirth.multiplier(rebirths), 1e-9)
		priceNote.Text = "Every bar sells for ×" .. string.format("%.3g", gain) .. " more. Upgrade prices rise ×"
			.. string.format("%.3g", Rebirth.priceMult(rebirths + 1) / Rebirth.priceMult(rebirths)) .. ", so you come out ahead."
		local ratio = math.clamp(cash / math.max(cost, 1), 0, 1)
		cashProgress.Text = Format.cash(cash) .. " of " .. Format.cash(cost)
		wallet.Text = Format.cash(cash)
		progressFill.Size = UDim2.fromScale(ratio, 1)
		percent.Text = math.floor(ratio * 100) .. "%"
		local unlock = Rebirth.unlock(rebirths + 1)
		local bonus = Rebirth.overstayShards(if state then state.overflow or 0 else 0, cost)
		local keep = state ~= nil and state.credits ~= nil and (state.credits.rebirthKeep or 0) > 0 -- a Keep Everything credit
		-- grey until you can afford it, lime when you can, red while the second press is pending
		Theme.state(confirm, canAfford and not busy, if armed then "red" else "lime")
		confirm.Text = if busy then "REBIRTHING..." elseif armed then "CONFIRM REBIRTH" else "REBIRTH · " .. Format.cash(cost)
		footer.Text = if notice ~= "" then notice elseif busy then "Rebirthing..."
			elseif armed then "Press again within " .. Format.number(Config.Rebirth.ConfirmWindow) .. " s. "
				.. (if keep then "You keep everything this time." else "This can't be undone.")
			elseif not canAfford then (if ratio >= 0.8 then "Almost there! Earn " else "Earn ") .. Format.cash(cost - cash) .. " more"
			else (if keep then "Keep Everything is ready: nothing resets. " else "")
				.. (if unlock then "Unlocks: " .. unlock .. ". " else "Index bonuses stay and stack with this multiplier. ")
				.. (if bonus > 0 then "+" .. bonus .. " bonus shards now." else "Rebirth now: waiting never beats the x" .. Format.number(Config.Rebirth.CashMult) .. ".")
		footer.TextColor3 = if armed or notice ~= "" then Palette.UNMET else Palette.SECOND
		-- "Rebirth without losing anything": usable at any time, even before you can afford the rebirth.
		-- Uses a credit when you have one, otherwise sells the product
		local usable = not busy and (keep or keepProduct.Id ~= 0)
		Theme.state(keepButton, usable, "gold")
		-- the wide card already says "Rebirth and Keep Everything", so its button carries just the price
		keepButton.Text = if busy then "REBIRTHING..."
			elseif keep then (if wide then "USE 1 CREDIT" else "KEEP EVERYTHING · 1 CREDIT")
			elseif keepProduct.Id == 0 then (if wide then "NOT ON SALE YET" else "KEEP EVERYTHING: NOT ON SALE YET")
			else (if wide then "" else "KEEP EVERYTHING · ") .. Format.ROBUX .. " " .. Format.number(keepPrice or keepProduct.Robux)

	end
	local function setOpen(value: boolean)
		if open ~= value then disarm() notice = "" end
		open = value
		player:SetAttribute("RebirthOpen", value)
		update()
	end
	requestOpen = setOpen
	function perform()
		disarm()
		busy = true
		update()
		task.spawn(function()
			local ok, reborn = pcall(function() return RebirthService:Rebirth() end)
			busy = false
			if not ok then notice = "Couldn't rebirth. Please try again."
			elseif reborn then
				Sfx.play("RebirthWarp")
				task.delay(0.7, function() Sfx.play("Rebirth") end)
				RewardFX.pillar(Config.RewardFX.Colors.Rebirth, 1.5, true)
				setOpen(false)
			end
			update()
		end)
	end
	local function press()
		if not affordable() or busy then return end
		if not armed then
			armToken += 1
			local token = armToken
			armed, notice = true, ""
			update()
			task.delay(Config.Rebirth.ConfirmWindow, function()
				if armToken == token then armed = false update() end
			end)
			return
		end
		perform()
	end
	local function hasKeepCredit(): boolean
		return state ~= nil and state.credits ~= nil and (state.credits.rebirthKeep or 0) > 0
	end
	-- The keep button asks first (it is a purchase or a one-time credit), so there is no second press
	local function pressKeep()
		if busy then return end
		if hasKeepCredit() then perform() return end
		if keepProduct.Id == 0 then return end
		pendingKeep = true
		local ok, err = pcall(function() MarketplaceService:PromptProductPurchase(player, keepProduct.Id) end)
		if not ok then
			pendingKeep = false
			warn("[RebirthController] purchase prompt failed:", err)
		end
	end
	MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId: number, productId: number, purchased: boolean)
		if userId == player.UserId and productId == keepProduct.Id and not purchased then pendingKeep = false end
	end)
	if keepProduct.Id ~= 0 then
		task.spawn(function()
			local ok, info = pcall(function() return MarketplaceService:GetProductInfoAsync(keepProduct.Id, Enum.InfoType.Product) end)
			if ok and type(info) == "table" and type(info.PriceInRobux) == "number" then
				keepPrice = info.PriceInRobux
				update()
			end
		end)
	end
	PlayerStateService.State:Observe(function(value)
		state = value
		if not affordable() then disarm() end
		update()
		-- the purchase just landed as a credit: rebirth now, as the button promised
		if pendingKeep and hasKeepCredit() then
			pendingKeep = false
			if not busy then perform() end
		end
	end)
	RebirthService.Notice:Connect(function(message: string)
		notice = message
		update()
		HUDController:Toast(message)
	end)
	nav.Activated:Connect(function() setOpen(true) end)
	close.Activated:Connect(function() setOpen(false) end)
	dimmer.Activated:Connect(function() setOpen(false) end)
	confirm.Activated:Connect(press)
	keepButton.Activated:Connect(pressKeep)
	UserInputService.InputBegan:Connect(function(input)
		if open and (input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB) then setOpen(false) end
	end)
	for _, name in { "ShopOpen", "IndexOpen", "TutorialCardInColumn" } do
		player:GetAttributeChangedSignal(name):Connect(update)
	end
	local function hover(value: boolean)
		tooltip.Visible = value and nav.Visible and not NativeUI.hudLayout().touch
	end
	nav.MouseEnter:Connect(function() hover(true) end)
	nav.MouseLeave:Connect(function() hover(false) end)
	nav.SelectionGained:Connect(function() hover(true) end)
	nav.SelectionLost:Connect(function() hover(false) end)
	local function box(node: GuiObject, r: RebirthLayout.Rect)
		node.Position, node.Size = UDim2.fromOffset(r.x, r.y), UDim2.fromOffset(r.w, r.h)
	end
	local perksIcon = perksButton:WaitForChild("Face"):WaitForChild("Icon") :: ImageLabel
	NativeUI.onLayoutChanged(function(layout)
		-- the Gear Shop's frame on a roomy window, MenuFit's fit on a small screen
		local view = ShopLayout.view(layout.viewport, layout.inset)
		local g = RebirthLayout.compute(view.viewport, view.inset, view.wide)
		wide = g.wide
		NativeUI.place(panel, g.panel, view)
		box(content, g.content)
		box(requirement, g.requirement)
		box(confirm, g.confirm)
		box(footer, g.footer)
		box(keepButton, g.keep)
		box(perksButton, g.perks)
		keepCard.Visible, wallet.Visible = g.wide, g.wide
		box(keepCard, g.keepCard)
		box(wallet, g.wallet)
		compare.Size = UDim2.new(1, -6, 0, g.compareH)
		confirm.TextSize = if g.wide then 26 else 22
		perksButton.Text = if g.wide then "COLONY PERKS" else "PERKS"
		perksIcon.Visible = g.wide
		-- the requirement card: a label, the percent and a bar over the cash line on the wide layout; one slim row on a small screen
		reqLabel.Visible = g.wide
		if g.wide then
			reqLabel.Position, reqLabel.Size = UDim2.fromOffset(12, 8), UDim2.new(0.6, -12, 0, 22)
			percent.Position, percent.Size = UDim2.new(0.6, 0, 0, 8), UDim2.new(0.4, -12, 0, 22)
			progressBar.Position, progressBar.Size = UDim2.fromOffset(12, 38), UDim2.new(1, -24, 0, 14)
			cashProgress.Position, cashProgress.Size = UDim2.fromOffset(12, 58), UDim2.new(1, -24, 0, 22)
		else
			cashProgress.Position, cashProgress.Size = UDim2.fromOffset(10, 3), UDim2.new(0.7, -10, 0, 18)
			percent.Position, percent.Size = UDim2.new(0.7, 0, 0, 3), UDim2.new(0.3, -10, 0, 18)
			progressBar.Position, progressBar.Size = UDim2.fromOffset(10, g.requirement.h - 15), UDim2.new(1, -20, 0, 9)
		end
		update()
		ExactNavButton.layout(nav, layout, "REBIRTH")
		if layout.touch then tooltip.Visible = false end
	end)
	gui.Enabled = true -- The persistent navigation tile shares this prefab.
	setOpen(open)
end

return RebirthController
