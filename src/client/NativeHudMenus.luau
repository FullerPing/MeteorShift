--!strict
-- Bind the authored HUD menus without constructing views or depending on Fusion.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Knit = require(ReplicatedStorage.Packages.Knit)
local HudLayout = require(ReplicatedStorage.Shared.HudLayout)
local HudResources = require(ReplicatedStorage.Shared.HudResources)
local Format = require(ReplicatedStorage.Shared.Format)
local UI = require(script.Parent.NativeUI)
local player = Players.LocalPlayer
local NativeHudMenus = {}
local started = false
local PREFERENCES = {
	{ name = "HudShowGuide", default = true },
	{ name = "HudShowEventTips", default = true },
	{ name = "ReduceCameraShake", default = false },
	{ name = "ReduceEffects", default = false },
}
local SETTINGS_BLOCKERS = { "ShopOpen", "IndexOpen", "RebirthOpen", "StoreOpen", "RefineryOpen", "HatchOpen" }
local BACKPACK_BLOCKERS = { "ShopOpen", "IndexOpen", "RebirthOpen", "StoreOpen", "SettingsOpen", "RefineryOpen" }

local function anotherMenuOpen(flags: { string }): boolean
	for _, name in flags do if player:GetAttribute(name) == true then return true end end
	return false
end

function NativeHudMenus.start()
	if started then return end
	local settings = UI.get("HudSettings")
	local backpack = UI.get("BackpackMenu")
	started = true
	local settingsPanel = settings:WaitForChild("SettingsPanel") :: Frame
	local backdrop = settings:WaitForChild("SettingsBackdrop") :: TextButton
	local openSettings = settings:WaitForChild("OpenSettings") :: ImageButton
	local settingsClose = settingsPanel:WaitForChild("Close") :: GuiButton
	local preferences = settingsPanel:WaitForChild("Preferences") :: ScrollingFrame
	local backpackPanel = backpack:WaitForChild("Panel") :: Frame
	local backpackClose = backpackPanel:WaitForChild("Close") :: GuiButton
	local inventory = backpackPanel:WaitForChild("OreInventory") :: ScrollingFrame
	local empty = backpackPanel:WaitForChild("Empty") :: TextLabel
	local title = backpackPanel:WaitForChild("Title") :: TextLabel
	local template = backpack:WaitForChild("Templates"):WaitForChild("OreRow") :: Frame
	local rowViews: { [string]: Frame } = {}
	local rows: { HudResources.OreRow } = {}
	local layout = UI.hudLayout()
	local function closeSettings() player:SetAttribute("SettingsOpen", false) end
	local function closeBackpack() player:SetAttribute("BackpackOpen", false) end
	local function updateSettingsOpen()
		local opened = player:GetAttribute("SettingsOpen") == true
		if opened and anotherMenuOpen(SETTINGS_BLOCKERS) then closeSettings(); return end
		settings.Enabled = true
		settings.DisplayOrder = if opened then 24 else 10
		settingsPanel.Visible, backdrop.Visible = opened, opened
	end
	local function updateBackpackOpen()
		local opened = player:GetAttribute("BackpackOpen") == true
		if opened and anotherMenuOpen(BACKPACK_BLOCKERS) then closeBackpack(); return end
		backpack.Enabled = opened
	end
	local function updateBackpack()
		local rect = HudLayout.backpackPanel(layout, #rows)
		backpackPanel.Position, backpackPanel.Size = UDim2.fromOffset(rect.x, rect.y), UDim2.fromOffset(rect.w, rect.h)
		local scrolling, wide = #rows * 28 > rect.h - 44, rect.w >= 150
		inventory.Active, inventory.ScrollingEnabled = scrolling, scrolling
		title.Text, empty.Visible = if wide then "Backpack" else "Bag", #rows == 0
		local visible: { [string]: boolean } = {}
		for index, resource in rows do
			visible[resource.id] = true
			local row = rowViews[resource.id]
			if not row then
				row = template:Clone()
				row.Name, row.Parent = resource.id .. "Ore", inventory
				rowViews[resource.id] = row
			end
			row.Visible, row.LayoutOrder = true, index
			local tint = if resource.id == "frost" then Color3.fromRGB(123, 230, 239) elseif resource.id == "crystal" then Color3.fromRGB(221, 161, 255) else UI.HUD_GOLD
			local icon = row:WaitForChild("Icon") :: ImageLabel
			icon.Visible, icon.ImageColor3 = wide, tint
			local kind = row:WaitForChild("Type") :: TextLabel
			kind.Text, kind.TextColor3, kind.TextSize = resource.name, tint, if wide then 14 else 12
			kind.Position, kind.Size = UDim2.fromOffset(if wide then 26 else 0, 2), UDim2.new(1, -(if wide then 76 else 38), 0, 24)
			local amount = row:WaitForChild("Amount") :: TextLabel
			amount.Text, amount.TextSize, amount.Size = Format.number(resource.amount), if wide then 16 else 12, UDim2.fromOffset(if wide then 44 else 32, 24)
		end
		for id, row in rowViews do
			if not visible[id] then row:Destroy(); rowViews[id] = nil end
		end
	end
	local function updateLayout(nextLayout: HudLayout.Layout)
		layout = nextLayout
		local button = layout.settings
		openSettings.Visible = button ~= nil
		if button then
			openSettings.Position, openSettings.Size = UDim2.fromOffset(button.x, button.y), UDim2.fromOffset(button.w, button.h)
		end
		settingsPanel.Position = UDim2.new(0.5, 0, 0, layout.inset + 12)
		settingsPanel.Size = UDim2.fromOffset(math.max(0, math.min(360, layout.viewport.X - 24)), math.max(0, math.min(350, layout.viewport.Y - layout.inset - 24)))
		updateBackpack()
	end
	for _, preference in PREFERENCES do
		if player:GetAttribute(preference.name) == nil then player:SetAttribute(preference.name, preference.default) end
		local row = preferences:WaitForChild(preference.name) :: TextButton
		local value = row:WaitForChild("State") :: TextLabel
		local function update()
			local enabled = player:GetAttribute(preference.name) == true
			value.Text = if enabled then "ON" else "OFF"
			value.BackgroundColor3 = if enabled then UI.GREEN else Color3.fromRGB(29, 30, 35)
		end
		row.Activated:Connect(function() player:SetAttribute(preference.name, player:GetAttribute(preference.name) ~= true) end)
		player:GetAttributeChangedSignal(preference.name):Connect(update)
		update()
	end
	if player:GetAttribute("SettingsOpen") == nil then player:SetAttribute("SettingsOpen", false) end
	if player:GetAttribute("BackpackOpen") == nil then player:SetAttribute("BackpackOpen", false) end
	openSettings.Activated:Connect(function() player:SetAttribute("SettingsOpen", player:GetAttribute("SettingsOpen") ~= true) end)
	backdrop.Activated:Connect(closeSettings)
	settingsClose.Activated:Connect(closeSettings)
	backpackClose.Activated:Connect(closeBackpack)
	player:GetAttributeChangedSignal("SettingsOpen"):Connect(updateSettingsOpen)
	player:GetAttributeChangedSignal("BackpackOpen"):Connect(updateBackpackOpen)
	for _, name in SETTINGS_BLOCKERS do
		player:GetAttributeChangedSignal(name):Connect(function() if player:GetAttribute(name) == true then closeSettings() end end)
	end
	for _, name in BACKPACK_BLOCKERS do
		player:GetAttributeChangedSignal(name):Connect(function() if player:GetAttribute(name) == true then closeBackpack() end end)
	end
	UserInputService.InputBegan:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB then closeSettings(); closeBackpack() end
	end)
	UI.onLayoutChanged(updateLayout)
	Knit.GetService("PlayerStateService").State:Observe(function(state)
		rows = HudResources.ores(state)
		updateBackpack()
	end)
	updateSettingsOpen()
	updateBackpackOpen()
end

return NativeHudMenus
