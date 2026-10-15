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
local NativeUI = require(script.Parent.Parent.NativeUI)
local ExactNavButton = require(script.Parent.Parent.ExactNavButton)
local Sfx = require(script.Parent.Parent.Sfx)
local RewardFX = require(script.Parent.Parent.RewardFX)
local RebirthMenu = require(script.Parent.Parent.NativeMenus.Rebirth)
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
	local compare = content:WaitForChild("Compare")
	local currentMultiplier = compare:WaitForChild("CurrentBox"):WaitForChild("CurrentMultiplier") :: TextLabel
	local nextMultiplier = compare:WaitForChild("AfterBox"):WaitForChild("NextMultiplier") :: TextLabel
	local priceNote = content:WaitForChild("ResetBox"):WaitForChild("PriceNote") :: TextLabel
	local requirement = content:WaitForChild("Requirement")
	local cashProgress = requirement:WaitForChild("CashProgress") :: TextLabel
	local progressFill = requirement:WaitForChild("ProgressBar"):WaitForChild("Fill") :: Frame
	local percent = requirement:WaitForChild("Percent") :: TextLabel
	local confirm = panel:WaitForChild("Confirm") :: TextButton
	local keepButton = panel:WaitForChild("Keep") :: TextButton
	local divider = panel:WaitForChild("PremiumDivider") :: Frame
	local footer = panel:WaitForChild("Footer") :: TextLabel
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
		currentMultiplier.Text, nextMultiplier.Text = multiplierText(rebirths), multiplierText(rebirths + 1)
		priceNote.Text = "Upgrade prices rise ×" .. string.format("%.3g", Rebirth.priceMult(rebirths + 1) / Rebirth.priceMult(rebirths))
		local ratio = math.clamp(cash / math.max(cost, 1), 0, 1)
		cashProgress.Text = Format.cash(cash) .. " / " .. Format.cash(cost)
		progressFill.Size = UDim2.fromScale(ratio, 1)
		percent.Text = math.floor(ratio * 100) .. "%"
		local unlock = Rebirth.unlock(rebirths + 1)
		local bonus = Rebirth.overstayShards(if state then state.overflow or 0 else 0, cost)
		local keep = state ~= nil and state.credits ~= nil and (state.credits.rebirthKeep or 0) > 0 -- a Keep Everything credit
		-- grey until you can afford it, green when you can, red while the second press is pending
		confirm.Active, confirm.Selectable, confirm.AutoButtonColor = canAfford and not busy, canAfford and not busy, canAfford and not busy
		confirm.Text = if busy then "REBIRTHING..." elseif armed then "CONFIRM REBIRTH" else "REBIRTH · " .. Format.cash(cost)
		confirm.TextColor3 = if busy or not canAfford then NativeUI.MUTED else NativeUI.WHITE
		confirm.BackgroundColor3 = if busy or not canAfford then Color3.fromRGB(73, 83, 94) elseif armed then NativeUI.RED else NativeUI.GREEN
		footer.Text = if notice ~= "" then notice elseif busy then "Rebirthing..."
			elseif armed then "Press again within " .. Format.number(Config.Rebirth.ConfirmWindow) .. " s. "
				.. (if keep then "You keep everything this time." else "This can't be undone.")
			elseif not canAfford then (if ratio >= 0.8 then "Almost there! Earn " else "Earn ") .. Format.cash(cost - cash) .. " more"
			else (if keep then "Keep Everything is ready: nothing resets. " else "")
				.. (if unlock then "Unlocks: " .. unlock .. ". " else "Index bonuses stay and stack with this multiplier. ")
				.. (if bonus > 0 then "+" .. bonus .. " bonus shards now." else "Rebirth now: waiting never beats the x5.")
		footer.TextColor3 = if armed or notice ~= "" then GOLD else NativeUI.MUTED
		-- "Rebirth without losing anything": usable at any time, even before you can afford the rebirth.
		-- Uses a credit when you have one, otherwise sells the product
		local usable = not busy and (keep or keepProduct.Id ~= 0)
		keepButton.Active, keepButton.Selectable, keepButton.AutoButtonColor = usable, usable, usable
		keepButton.Text = if busy then "REBIRTHING..."
			elseif keep then "REBIRTH & KEEP EVERYTHING (1 CREDIT)"
			elseif keepProduct.Id == 0 then "KEEP EVERYTHING: NOT ON SALE YET"
			else "REBIRTH & KEEP EVERYTHING · R$" .. Format.number(keepPrice or keepProduct.Robux)
		keepButton.TextColor3 = if usable then NativeUI.WHITE else NativeUI.MUTED
		keepButton.BackgroundColor3 = if usable then NativeUI.HUD_GOLD else Color3.fromRGB(73, 83, 94)

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
	NativeUI.onLayoutChanged(function(layout)
		local view = NativeUI.menuView(layout)
		local geometry = RebirthLayout.compute(view.viewport, view.inset)
		NativeUI.place(panel, geometry.panel, view)
		local pad = geometry.padding
		content.Position, content.Size = UDim2.fromOffset(pad, geometry.contentY), UDim2.new(1, -pad * 2, 0, geometry.contentH)
		confirm.Position, confirm.Size = UDim2.fromOffset(pad, geometry.confirmY), UDim2.new(1, -pad * 2, 0, geometry.confirmH)
		footer.Position, footer.Size = UDim2.fromOffset(pad, geometry.footerY), UDim2.new(1, -pad * 2, 0, geometry.footerH)
		divider.Position, divider.Size = UDim2.fromOffset(pad, geometry.dividerY), UDim2.new(1, -pad * 2, 0, geometry.dividerH)
		divider.Visible = geometry.dividerH > 0
		keepButton.Position, keepButton.Size = UDim2.fromOffset(pad, geometry.keepY), UDim2.new(1, -pad * 2, 0, geometry.keepH)
		ExactNavButton.layout(nav, layout, "REBIRTH")
		if layout.touch then tooltip.Visible = false end
	end)
	gui.Enabled = true -- The persistent navigation tile shares this prefab.
	setOpen(open)
end

return RebirthController
