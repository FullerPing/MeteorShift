--!strict
-- The FAST WALK toggle: a round button (and Left Shift on keyboard) that asks
-- PlayerStateService to multiply your walk speed (Shared.CharacterSpeed). The server owns
-- the speed and mirrors the choice in the FastWalk player attribute, which the button
-- shows. On touch the button sits left of Roblox's jump button, otherwise just above the
-- backpack card; it hides while a panel is open.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local UI = require(script.Parent.Parent.UI)
local Cartoon = require(script.Parent.Parent.Cartoon)

local player = Players.LocalPlayer
local FastWalkController = Knit.CreateController({ Name = "FastWalkController" })

local SIZE = 54
local PANEL_FLAGS = { "ShopOpen", "IndexOpen", "RebirthOpen", "StoreOpen", "SettingsOpen", "RefineryOpen", "HatchOpen", "BackpackOpen" }

function FastWalkController:KnitStart()
	local PlayerStateService = Knit.GetService("PlayerStateService")
	local scope = Fusion.scoped(Fusion)
	local hud = UI.hud(scope)

	local gui = Instance.new("ScreenGui")
	gui.Name = "FastWalk"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	local button = Instance.new("TextButton")
	button.Name = "FastWalkButton"
	button.Text = ""
	button.AutoButtonColor = false
	button.BackgroundTransparency = 1
	button.Size = UDim2.fromOffset(SIZE, SIZE)
	button.Parent = gui
	local off = Cartoon.surface("blue", { round = true, edge = 3, lip = 4, studs = 0.84, studSize = 18 })
	local on = Cartoon.surface("green", { round = true, edge = 3, lip = 4, studs = 0.84, studSize = 18 })
	off.Parent, on.Parent = button, button
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = UI.FONT
	label.Text = "FAST\nWALK"
	label.TextScaled = true
	label.TextColor3 = UI.WHITE
	label.ZIndex = 2
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0.14, 0), UDim.new(0.14, 0)
	pad.PaddingTop, pad.PaddingBottom = UDim.new(0.2, 0), UDim.new(0.2, 0)
	pad.Parent = label
	Cartoon.outlineLabel(label)
	label.Parent = button

	local function enabled(): boolean
		return player:GetAttribute("FastWalk") == true
	end
	local function panelOpen(): boolean
		for _, flag in PANEL_FLAGS do
			if player:GetAttribute(flag) == true then return true end
		end
		return false
	end
	local function refresh()
		on.Visible = enabled()
		off.Visible = not enabled()
		button.Visible = not panelOpen()
		local layout = Fusion.peek(hud)
		local jump, pack = layout.jump, layout.backpack
		if jump then
			button.Position = UDim2.fromOffset(jump.x - 10 - SIZE, jump.y + jump.h - SIZE)
		else
			button.Position = UDim2.fromOffset(pack.x + pack.w - SIZE, pack.y - SIZE - 8)
		end
	end
	local function toggle()
		task.spawn(function() PlayerStateService:SetFastWalk(not enabled()) end)
	end

	button.Activated:Connect(toggle)
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.LeftShift then toggle() end
	end)
	player:GetAttributeChangedSignal("FastWalk"):Connect(refresh)
	for _, flag in PANEL_FLAGS do player:GetAttributeChangedSignal(flag):Connect(refresh) end
	scope:Observer(hud):onChange(refresh)
	gui.Parent = player:WaitForChild("PlayerGui")
	refresh()
end

return FastWalkController
