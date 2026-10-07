--!strict
-- The ORE button: opens a short list of the four ore fields (Config.Debris.Fields) and asks
-- DebrisService to teleport you to the one you pick. It sits just above the FAST WALK button
-- (FastWalkController places that), hides while a menu is open, and the list closes after a pick.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Config = require(ReplicatedStorage.Shared.Config)
local UI = require(script.Parent.Parent.UI)
local Cartoon = require(script.Parent.Parent.Cartoon)

local player = Players.LocalPlayer
local FieldTravelController = Knit.CreateController({ Name = "FieldTravelController" })

local SIZE = 54
local GAP = 8
local PANEL_FLAGS = { "ShopOpen", "IndexOpen", "RebirthOpen", "StoreOpen", "SettingsOpen", "RefineryOpen", "HatchOpen", "BackpackOpen" }

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
	local playerGui = player:WaitForChild("PlayerGui")
	local anchor = playerGui:WaitForChild("FastWalk"):WaitForChild("FastWalkButton") :: GuiButton

	local gui = Instance.new("ScreenGui")
	gui.Name = "OreFields"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

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
	panel.Size = UDim2.fromOffset(300, 64 + #fields * 56)
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
	for index, field in fields do
		local row = Instance.new("TextButton")
		row.Name = field.Id
		row.AutoButtonColor = true
		row.Text = ""
		row.BackgroundColor3 = field.Color
		row.Size = UDim2.new(1, -24, 0, 46)
		row.Position = UDim2.fromOffset(12, 54 + (index - 1) * 56)
		row.Parent = panel
		local rowCorner = Instance.new("UICorner")
		rowCorner.CornerRadius = UDim.new(0, 12)
		rowCorner.Parent = row
		label(row, string.upper(field.Name), UDim2.new(1, -16, 1, -12), UDim2.fromOffset(8, 6))
		row.Activated:Connect(function()
			panel.Visible = false
			task.spawn(function() DebrisService:TravelTo(field.Id) end)
		end)
	end

	local function panelOpen(): boolean
		for _, flag in PANEL_FLAGS do
			if player:GetAttribute(flag) == true then return true end
		end
		return false
	end
	local function refresh()
		button.Position = UDim2.new(anchor.Position.X.Scale, anchor.Position.X.Offset,
			anchor.Position.Y.Scale, anchor.Position.Y.Offset - SIZE - GAP)
		local hidden = panelOpen()
		button.Visible = not hidden
		if hidden then panel.Visible = false end
	end
	button.Activated:Connect(function() panel.Visible = not panel.Visible end)
	anchor:GetPropertyChangedSignal("Position"):Connect(refresh)
	for _, flag in PANEL_FLAGS do player:GetAttributeChangedSignal(flag):Connect(refresh) end
	gui.Parent = playerGui
	refresh()
end

return FieldTravelController
