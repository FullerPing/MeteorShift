--!strict
-- Bind the editable StarterGui prefab; progression remains server-authoritative.
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
	local gui = NativeUI.get("Rebirth")
	local panel = gui:WaitForChild("Panel") :: Frame
	local nav = gui:WaitForChild("RebirthButton") :: TextButton
	local navRefs = ExactNavButton.bind(nav)
	local dimmer = gui:WaitForChild("Dimmer") :: TextButton
	local close = panel:WaitForChild("Close") :: TextButton
	local content = panel:WaitForChild("Content") :: ScrollingFrame
	local currentMultiplier = content:WaitForChild("CurrentMultiplier") :: TextLabel
	local nextMultiplier = content:WaitForChild("NextMultiplier") :: TextLabel
	local cashProgress = content:WaitForChild("CashProgress") :: TextLabel
	local confirm = panel:WaitForChild("Confirm") :: TextButton
	local footer = panel:WaitForChild("Footer") :: TextLabel
	local ready = navRefs.badge
	local tooltip = navRefs.tooltip
	local state: any = nil
	local open, armed, busy, notice = wantOpen, false, false, ""
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
		cashProgress.Text = "You have " .. Format.cash(cash) .. " / " .. Format.cash(cost)
		confirm.Active, confirm.Selectable, confirm.AutoButtonColor = canAfford and not busy, canAfford and not busy, canAfford and not busy
		confirm.Text = if busy then "REBIRTHING..." elseif armed then "CONFIRM REBIRTH" else "Rebirth " .. Format.cash(cost)
		confirm.TextColor3 = if busy or not canAfford then NativeUI.MUTED else NativeUI.WHITE
		confirm.BackgroundColor3 = if busy or not canAfford then Color3.fromRGB(73, 83, 94) elseif armed then GOLD else NativeUI.GREEN
		footer.Text = if notice ~= "" then notice elseif busy then "Rebirthing..."
			elseif armed then "Press again within " .. Format.number(Config.Rebirth.ConfirmWindow) .. " s. This can't be undone."
			elseif not canAfford then "Earn " .. Format.cash(cost - cash) .. " more to rebirth."
			else "Index bonuses stay and stack with this multiplier."
		footer.TextColor3 = if armed or notice ~= "" then GOLD else NativeUI.MUTED
	end
	local function setOpen(value: boolean)
		if open ~= value then disarm() notice = "" end
		open = value
		player:SetAttribute("RebirthOpen", value)
		update()
	end
	requestOpen = setOpen
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
		disarm()
		busy = true
		update()
		task.spawn(function()
			local ok, reborn = pcall(function() return RebirthService:Rebirth() end)
			busy = false
			if not ok then notice = "Couldn't rebirth. Please try again."
			elseif reborn then Sfx.play("Purchase") setOpen(false) end
			update()
		end)
	end
	PlayerStateService.State:Observe(function(value)
		state = value
		if not affordable() then disarm() end
		update()
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
		local geometry = RebirthLayout.compute(layout.viewport, layout.inset)
		local p = geometry.panel
		panel.Position, panel.Size = UDim2.fromOffset(p.x, p.y), UDim2.fromOffset(p.w, p.h)
		content.Position, content.Size = UDim2.fromOffset(16, geometry.contentY), UDim2.new(1, -32, 0, geometry.contentH)
		content.CanvasSize = UDim2.fromOffset(0, geometry.canvasH)
		confirm.Position, footer.Position = UDim2.fromOffset(16, geometry.confirmY), UDim2.fromOffset(16, geometry.footerY)
		ExactNavButton.layout(nav, layout, "REBIRTH")
		if layout.touch then tooltip.Visible = false end
	end)
	gui.Enabled = true -- The persistent navigation tile shares this prefab.
	setOpen(open)
end

return RebirthController
