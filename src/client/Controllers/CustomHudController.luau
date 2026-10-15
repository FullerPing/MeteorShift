--!strict
-- Draws the extra buttons and labels listed in Config.HudEdit.Custom (see that file for the fields). They
-- follow the HUD's screen scale and top-bar inset, hide while a menu is open, and need no code of their own.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Config = require(ReplicatedStorage.Shared.Config)
local UI = require(script.Parent.Parent.UI)
local Cartoon = require(script.Parent.Parent.Cartoon)

local player = Players.LocalPlayer
local CustomHudController = Knit.CreateController({ Name = "CustomHudController" })

local PANEL_FLAGS = { "ShopOpen", "IndexOpen", "RebirthOpen", "StoreOpen", "PetsOpen", "DailyOpen", "CodesOpen", "SettingsOpen", "RefineryOpen", "HatchOpen", "IntroOpen", "BackpackOpen" }
local ANCHORS: { [string]: Vector2 } = {
	TopLeft = Vector2.new(0, 0), Top = Vector2.new(0.5, 0), TopRight = Vector2.new(1, 0),
	Left = Vector2.new(0, 0.5), Center = Vector2.new(0.5, 0.5), Right = Vector2.new(1, 0.5),
	BottomLeft = Vector2.new(0, 1), Bottom = Vector2.new(0.5, 1), BottomRight = Vector2.new(1, 1),
}

-- What a click does: the element's own Click function, or one of the named shortcuts.
local function run(def: { [string]: any })
	local ok, err = pcall(function()
		if type(def.Click) == "function" then
			def.Click(player)
		elseif def.Open == "Shop" then
			Knit.GetController("ShopController"):Open()
		elseif def.Open == "Rebirth" then
			Knit.GetController("RebirthController"):Open()
		elseif def.Open == "Refinery" then
			Knit.GetController("RefineryController"):Open()
		elseif def.Open == "FastWalk" then
			Knit.GetService("PlayerStateService"):SetFastWalk(not (player:GetAttribute("FastWalk") == true))
		end
	end)
	if not ok then warn("[CustomHud] " .. tostring(def.Id) .. " failed: " .. tostring(err)) end
end

function CustomHudController:KnitStart()
	local list = Config.HudEdit.Custom
	if #list == 0 then return end
	local scope = Fusion.scoped(Fusion)
	local hud = UI.hud(scope)

	local gui = Instance.new("ScreenGui")
	gui.Name = "CustomHud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	local seen: { [string]: boolean } = {}
	local items: { { root: GuiObject, scale: UIScale, def: { [string]: any }, width: number, height: number } } = {}
	for _, def in list do
		local id = def.Id
		if type(id) ~= "string" or seen[id] then
			warn("[CustomHud] skipped an element with a missing or repeated Id")
			continue
		end
		seen[id] = true
		local isButton = def.Kind ~= "label"
		local width, height = def.Width or 120, def.Height or 54
		local root: GuiObject
		if isButton then
			local button = Instance.new("TextButton")
			button.Text = ""
			button.AutoButtonColor = false
			button.Activated:Connect(function() run(def) end)
			root = button
		else
			root = Instance.new("Frame")
		end
		root.Name = id
		root.BackgroundTransparency = 1
		root.Size = UDim2.fromOffset(width, height)
		root.Parent = gui
		Cartoon.surface(def.Color or "blue", { radius = 14, edge = 3, lip = 4, studs = 0.84, studSize = 18 }).Parent = root
		local hasIcon = def.Icon ~= nil and Config.HudIcons[def.Icon] ~= nil
		if hasIcon then
			local icon = Instance.new("ImageLabel")
			icon.Name = "Icon"
			icon.BackgroundTransparency = 1
			icon.Image = Config.HudIcons[def.Icon]
			icon.ScaleType = Enum.ScaleType.Fit
			icon.AnchorPoint = Vector2.new(0, 0.5)
			icon.Position = UDim2.new(0, 8, 0.5, -1)
			icon.Size = UDim2.fromOffset(height - 14, height - 14)
			icon.ZIndex = 3
			icon.Parent = root
		end
		if def.Text then
			local text = Instance.new("TextLabel")
			text.Name = "Text"
			text.BackgroundTransparency = 1
			text.Font = UI.FONT
			text.Text = def.Text
			text.TextScaled = true
			text.TextColor3 = UI.WHITE
			text.ZIndex = 3
			local inset = if hasIcon then height - 6 else 8
			text.Position = UDim2.new(0, inset, 0, 6)
			text.Size = UDim2.new(1, -inset - 8, 1, -12)
			Cartoon.outlineLabel(text)
			text.Parent = root
		end
		local scale = Instance.new("UIScale")
		scale.Parent = root
		table.insert(items, { root = root, scale = scale, def = def, width = width, height = height })
	end

	local function panelOpen(): boolean
		for _, flag in PANEL_FLAGS do
			if player:GetAttribute(flag) == true then return true end
		end
		return false
	end
	local function refresh()
		local layout = Fusion.peek(hud)
		local open = panelOpen()
		for _, item in items do
			local anchor = ANCHORS[item.def.Anchor or "TopLeft"] or ANCHORS.TopLeft
			-- never smaller than a 44 px touch target; follows the HUD scale otherwise
			local scale = math.max(layout.scale, Config.Hud.MinTouch / math.min(item.width, item.height))
			item.scale.Scale = math.min(scale, 1.4)
			item.root.AnchorPoint = anchor
			local top = if anchor.Y == 0 then layout.inset else 0
			item.root.Position = UDim2.new(anchor.X, (item.def.X or 0) * layout.scale, anchor.Y, (item.def.Y or 0) * layout.scale + top)
			item.root.Visible = not open
		end
	end
	scope:Observer(hud):onChange(refresh)
	for _, flag in PANEL_FLAGS do player:GetAttributeChangedSignal(flag):Connect(refresh) end
	gui.Parent = player:WaitForChild("PlayerGui")
	refresh()
end

return CustomHudController
