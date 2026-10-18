--!strict
-- The ORE button: opens a short list of the ore fields (Config.Debris.Fields) and asks
-- DebrisService to teleport you to the one you pick. It sits just above the SPRINT button
-- (FastWalkController places that), hides while a menu is open, and the list closes after a pick.
-- A field still locked to you (Shared.FieldGate) shows its rule ("Level 12") in grey and can't be picked;
-- the server refuses it anyway.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Config = require(ReplicatedStorage.Shared.Config)
local FieldGate = require(ReplicatedStorage.Shared.FieldGate)
local HudLayout = require(ReplicatedStorage.Shared.HudLayout)
local UI = require(script.Parent.Parent.UI)
local Cartoon = require(script.Parent.Parent.Cartoon)
local Sfx = require(script.Parent.Parent.Sfx)
local RewardFX = require(script.Parent.Parent.RewardFX)

local player = Players.LocalPlayer
local FieldTravelController = Knit.CreateController({ Name = "FieldTravelController" })

local SIZE = Config.Hud.SideButtons.Size
local GAP = Config.Hud.SideButtons.Gap
local PANEL_FLAGS = { "ShopOpen", "IndexOpen", "RebirthOpen", "StoreOpen", "PetsOpen", "DailyOpen", "CodesOpen", "SettingsOpen", "RefineryOpen", "HatchOpen", "IntroOpen", "BackpackOpen" }

local function label(parent: Instance, text: string, size: UDim2, position: UDim2?): TextLabel
	local item = Instance.new("TextLabel")
	item.BackgroundTransparency = 1
	item.Size = size
	item.Position = position or UDim2.new()
	item.Font = UI.FONT
	item.Text = text
	item.TextScaled = true
	item.TextColor3 = UI.WHITE
	item.ZIndex = 3
	item.Parent = parent
	Cartoon.outlineLabel(item)
	return item
end

function FieldTravelController:KnitStart()
	local DebrisService = Knit.GetService("DebrisService")
	local PlayerStateService = Knit.GetService("PlayerStateService")
	local state: any = nil
	local playerGui = player:WaitForChild("PlayerGui")
	local scope = Fusion.scoped(Fusion)
	local hud = UI.hud(scope)
	local anchor = playerGui:WaitForChild("FastWalk"):WaitForChild("FastWalkButton") :: GuiButton

	local gui = Instance.new("ScreenGui")
	gui.Name = "OreFields"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 2 -- the open list draws over the tutorial card (1), under every menu (10+)

	local button = Instance.new("TextButton")
	button.Name = "OreButton"
	button.Text = ""
	button.AutoButtonColor = false
	button.BackgroundTransparency = 1
	button.Size = UDim2.fromOffset(SIZE, SIZE)
	button.Parent = gui
	Cartoon.surface("orange", { round = true, edge = 3, lip = 4, studs = 0.84, studSize = 18 }).Parent = button
	local text = label(button, "ORE", UDim2.fromScale(1, 1))
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0.14, 0), UDim.new(0.14, 0)
	pad.PaddingTop, pad.PaddingBottom = UDim.new(0.3, 0), UDim.new(0.3, 0)
	pad.Parent = text

	-- The list: a title and one coloured row per field
	local fields = Config.Debris.Fields
	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	local ROW, STEP = 40, 46
	local panelHeight = 64 + #fields * STEP
	panel.Size = UDim2.fromOffset(300, panelHeight)
	local fit = Instance.new("UIScale") -- short screens shrink the list rather than cut it off
	fit.Parent = panel
	panel.BackgroundColor3 = Color3.fromRGB(30, 36, 62)
	panel.Visible = false
	panel.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 16)
	corner.Parent = panel
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = Color3.fromRGB(255, 190, 70)
	stroke.Parent = panel
	label(panel, "ORE FIELDS", UDim2.new(1, -24, 0, 36), UDim2.fromOffset(12, 10))
	local rows: { [any]: { row: TextButton, text: TextLabel } } = {}
	local function isOpen(field: any): boolean
		return state ~= nil and FieldGate.isOpen(field, state.level or 1, state.rebirths or 0)
	end
	for index, field in fields do
		local row = Instance.new("TextButton")
		row.Name = field.Id
		row.AutoButtonColor = true
		row.Text = ""
		row.BackgroundColor3 = field.Color
		row.Size = UDim2.new(1, -24, 0, ROW)
		row.Position = UDim2.fromOffset(12, 54 + (index - 1) * STEP)
		row.Parent = panel
		local rowCorner = Instance.new("UICorner")
		rowCorner.CornerRadius = UDim.new(0, 12)
		rowCorner.Parent = row
		rows[field] = { row = row, text = label(row, string.upper(field.Name), UDim2.new(1, -16, 1, -12), UDim2.fromOffset(8, 6)) }
		row.Activated:Connect(function()
			if not isOpen(field) then
				Sfx.play("Click")
				return
			end
			panel.Visible = false
			task.spawn(function()
				local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
				local from = root and root.Position
				local ok, moved = pcall(function() return DebrisService:TravelTo(field.Id) end)
				if ok and moved then
					-- a puff where you were and one where you land
					Sfx.play("Teleport")
					if from then RewardFX.poof(from, field.Color) end
					RewardFX.poofHere(field.Color)
				end
			end)
		end)
	end

	local function paintRows()
		for field, item in rows do
			local open = isOpen(field)
			item.row.BackgroundColor3 = if open then field.Color else UI.DISABLED
			item.row.AutoButtonColor = open
			item.text.Text = if open then string.upper(field.Name) else string.upper(field.Name) .. "  ·  " .. string.upper(FieldGate.label(field))
		end
	end
	PlayerStateService.State:Observe(function(value)
		state = value
		paintRows()
	end)

	local function panelOpen(): boolean
		for _, flag in PANEL_FLAGS do
			if player:GetAttribute(flag) == true then return true end
		end
		return false
	end
	local function refresh()
		-- Config.HudEdit: "Ore" nudges it from its spot above SPRINT, and hides it
		local layout = Fusion.peek(hud)
		-- desktop gives it a spot in line with the backpack (layout.ore); elsewhere it sits above SPRINT
		local rect = HudLayout.nudged(layout, "Ore", if layout.ore then table.clone(layout.ore) else {
			x = anchor.Position.X.Offset, y = anchor.Position.Y.Offset - SIZE - GAP, w = SIZE, h = SIZE,
		})
		local camera = workspace.CurrentCamera
		fit.Scale = if camera then math.min(1, (camera.ViewportSize.Y - 40) / panelHeight) else 1
		button.Position = UDim2.fromOffset(rect.x, rect.y)
		button.Size = UDim2.fromOffset(rect.w, rect.h)
		local hidden = panelOpen()
		button.Visible = not hidden and not HudLayout.isHidden(layout, "Ore")
		if hidden or not button.Visible then panel.Visible = false end
	end
	scope:Observer(hud):onChange(refresh)
	button.Activated:Connect(function()
		panel.Visible = not panel.Visible
		if panel.Visible then refresh() end
	end)
	anchor:GetPropertyChangedSignal("Position"):Connect(refresh)
	for _, flag in PANEL_FLAGS do player:GetAttributeChangedSignal(flag):Connect(refresh) end
	gui.Parent = playerGui
	refresh()
end

return FieldTravelController
