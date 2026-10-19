--!strict
-- Bind the authored HUD menus without constructing views or depending on Fusion.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Knit = require(ReplicatedStorage.Packages.Knit)
local HudLayout = require(ReplicatedStorage.Shared.HudLayout)
local HudResources = require(ReplicatedStorage.Shared.HudResources)
local Format = require(ReplicatedStorage.Shared.Format)
local Icons = require(ReplicatedStorage.Shared.Config.HudIcons)
local UI = require(script.Parent.NativeUI)
local SettingsMenu = require(script.Parent.NativeMenus.Settings)
local MenuTheme = require(script.Parent.MenuTheme)
local player = Players.LocalPlayer
local NativeHudMenus = {}
local started = false
local PREFERENCES = {
	{ name = "HudShowGuide", default = true },
	{ name = "HudShowEventTips", default = true },
	{ name = "ReduceCameraShake", default = false },
	{ name = "ReduceEffects", default = false },
	{ name = "MusicOn", default = true, label = "Music" },
	{ name = "SfxOn", default = true, label = "Sound effects" },
}
local SETTINGS_BLOCKERS = { "ShopOpen", "IndexOpen", "RebirthOpen", "StoreOpen", "PetsOpen", "DailyOpen", "CodesOpen", "OreFieldsOpen", "RefineryOpen", "HatchOpen" }
local BACKPACK_BLOCKERS = { "ShopOpen", "IndexOpen", "RebirthOpen", "StoreOpen", "PetsOpen", "DailyOpen", "CodesOpen", "OreFieldsOpen", "SettingsOpen", "RefineryOpen" }

local function anotherMenuOpen(flags: { string }): boolean
	for _, name in flags do if player:GetAttribute(name) == true then return true end end
	return false
end

function NativeHudMenus.start()
	if started then return end
	local settings = UI.getFresh("HudSettings", SettingsMenu.build, SettingsMenu.LAYOUT)
	local backpack = UI.get("BackpackMenu")
	started = true
	local settingsPanel = settings:WaitForChild("SettingsPanel") :: Frame
	UI.fitCentred(settingsPanel, SettingsMenu.SIZE)
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
	local oreImage = (template:WaitForChild("Icon") :: ImageLabel).Image
	-- The popup is a short list under a slim ribbon: a small red X badge on the
	-- corner, and rows that shrink to fit instead of scrolling.
	backpackClose.AnchorPoint, backpackClose.Position, backpackClose.Size = Vector2.zero, UDim2.new(1, -24, 0, -12), UDim2.fromOffset(32, 32)
	backpackClose.ZIndex = math.max(backpackClose.ZIndex, 8)
	local closeIcon = backpackClose:FindFirstChild("Icon")
	if closeIcon and closeIcon:IsA("GuiObject") then closeIcon.Size = UDim2.fromOffset(16, 16) end
	inventory.Position, inventory.Size = UDim2.fromOffset(8, 34), UDim2.new(1, -16, 1, -40)
	inventory.ScrollingEnabled, inventory.Active, inventory.ScrollBarThickness = false, false, 0
	local padding = inventory:FindFirstChildOfClass("UIPadding")
	if padding then padding.PaddingTop, padding.PaddingBottom = UDim.new(0, 0), UDim.new(0, 0) end
	empty.Position = UDim2.fromOffset(8, 34)
	local rowViews: { [string]: Frame } = {}
	-- raw ore, then the bars you carry (tinted ingots); the sell button on the HUD shows their value
	type Row = { id: string, name: string, amount: number, bar: boolean? }
	local rows: { Row } = {}
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
		local wide = rect.w >= 150
		local rowHeight = math.clamp(math.floor((rect.h - 40) / math.max(#rows, 1)), 16, 28)
		title.Text, empty.Visible = if wide then "Backpack" else "Bag", #rows == 0
		local visible: { [string]: boolean } = {}
		for index, resource in rows do
			local key = resource.id .. (if resource.bar then "Bars" else "Ore")
			visible[key] = true
			local row = rowViews[key]
			if not row then
				row = template:Clone()
				row.Name, row.Parent = key, inventory
				rowViews[key] = row
			end
			row.Visible, row.LayoutOrder, row.Size = true, index, UDim2.new(1, 0, 0, rowHeight)
			local tint = if resource.id == "frost" then Color3.fromRGB(123, 230, 239) elseif resource.id == "crystal" then Color3.fromRGB(221, 161, 255) else UI.HUD_GOLD
			local textHeight = rowHeight - 4
			local icon = row:WaitForChild("Icon") :: ImageLabel
			icon.Visible, icon.ImageColor3, icon.Image = wide, tint, if resource.bar then Icons.barStack else oreImage
			icon.Position, icon.Size = UDim2.fromOffset(0, math.floor((rowHeight - textHeight) / 2)), UDim2.fromOffset(textHeight, textHeight)
			local kind = row:WaitForChild("Type") :: TextLabel
			kind.Text, kind.TextColor3 = if resource.bar then resource.name .. " bars" else resource.name, tint
			kind.TextSize = math.floor(textHeight * (if wide then 0.7 else 0.6))
			kind.Position, kind.Size = UDim2.fromOffset(if wide then textHeight + 6 else 0, 2), UDim2.new(1, -(if wide then textHeight + 56 else 38), 0, textHeight)
			local amount = row:WaitForChild("Amount") :: TextLabel
			amount.Text, amount.TextSize = Format.number(resource.amount), math.floor(textHeight * (if wide then 0.78 else 0.6))
			amount.Size = UDim2.fromOffset(if wide then 56 else 32, textHeight)
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
		updateBackpack()
	end
	-- each switch row (a Frame in a section card, named after its attribute) has a chunky Toggle: lime ON, pale OFF
	for _, preference in PREFERENCES do
		if player:GetAttribute(preference.name) == nil then player:SetAttribute(preference.name, preference.default) end
		local row = preferences:FindFirstChild(preference.name, true) :: Frame
		local toggle = row:WaitForChild("Toggle") :: TextButton
		local function update()
			local enabled = player:GetAttribute(preference.name) == true
			toggle.Text = if enabled then "ON" else "OFF"
			MenuTheme.paint(toggle, if enabled then "lime" else "tabOff")
		end
		toggle.Activated:Connect(function() player:SetAttribute(preference.name, player:GetAttribute(preference.name) ~= true) end)
		player:GetAttributeChangedSignal(preference.name):Connect(update)
		update()
	end
	-- Daily rewards and Codes: the two buttons under the switches, and a dot on the gear while a daily reward is waiting
	local dailyRow = settingsPanel:WaitForChild("OpenDaily") :: TextButton
	local codesRow = settingsPanel:WaitForChild("OpenCodes") :: TextButton
	local dot = Instance.new("Frame")
	dot.Name, dot.Size, dot.AnchorPoint, dot.Position = "DailyDot", UDim2.fromOffset(12, 12), Vector2.new(1, 0), UDim2.new(1, -2, 0, 2)
	dot.BackgroundColor3, dot.BorderSizePixel, dot.ZIndex, dot.Visible = Color3.fromRGB(255, 80, 80), 0, 10, false
	Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)
	dot.Parent = openSettings
	local function updateDailyDot() dot.Visible = player:GetAttribute("DailyReady") == true end
	player:GetAttributeChangedSignal("DailyReady"):Connect(updateDailyDot)
	updateDailyDot()
	-- Daily Rewards waits for the first-session tutorial (DailyController sets DailyUnlocked when it is over)
	local openDailyRow = dailyRow
	local function updateDailyRow()
		-- before Daily opens, Codes takes the whole row
		local unlocked = player:GetAttribute("DailyUnlocked") == true
		openDailyRow.Visible = unlocked
		codesRow.Position = if unlocked then UDim2.new(0.5, 6, 1, -78) else UDim2.new(0, 18, 1, -78)
		codesRow.Size = if unlocked then UDim2.new(0.5, -24, 0, 56) else UDim2.new(1, -36, 0, 56)
	end
	player:GetAttributeChangedSignal("DailyUnlocked"):Connect(updateDailyRow)
	updateDailyRow()
	openDailyRow.Activated:Connect(function()
		player:SetAttribute("SettingsOpen", false)
		player:SetAttribute("DailyOpen", true)
	end)
	-- Codes, also for the screens with no room for the HUD button
	codesRow.Activated:Connect(function()
		player:SetAttribute("SettingsOpen", false)
		player:SetAttribute("CodesOpen", true)
	end)
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
		rows = HudResources.ores(state) :: { any }
		for _, bar in HudResources.bars(state) do
			if bar.amount > 0 then table.insert(rows, { id = bar.id, name = bar.name, amount = bar.amount, bar = true }) end
		end
		updateBackpack()
	end)
	updateSettingsOpen()
	updateBackpackOpen()
end

return NativeHudMenus
