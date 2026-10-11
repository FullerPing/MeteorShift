--!strict
-- The Pets menu: equip pets and read their benefits (MY PETS) and browse every pet in the game (PET INDEX).
-- Eggs hatch at the Hatchery's prompts (PetService). PetsController binds the named controls and places everything from Shared.PetsLayout.
local RS = game:GetService("ReplicatedStorage")
local Config = require(RS.Shared.Config)
local Icons = require(RS.Shared.Config.HudIcons)
local PetsLayout = require(RS.Shared.PetsLayout)
local N = require(script.Parent.Parent.NativeUI)
local Pets = {}
Pets.LAYOUT = 2 -- bumped when the panel's controls change; an older authored copy is replaced by PetsController

local function viewport(parent: Instance, name: string): ViewportFrame
	return N.create("ViewportFrame", { Name = name, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0,
		Ambient = Color3.fromRGB(195, 201, 220), LightColor = Color3.fromRGB(255, 240, 216), LightDirection = Vector3.new(1, -1, 2), ZIndex = 4 }, parent)
end

-- One pet tile: a model preview, its name and level, a rarity accent, a lime tick while it is out, a blue ring while it is
-- selected and a "?" cover for pets you have not found.
local function petCard(parent: Instance, id: string, order: number)
	local card = N.create("Frame", { Name = "pet_" .. id, LayoutOrder = order, Size = UDim2.fromOffset(150, 172), BackgroundColor3 = N.CARD, BorderSizePixel = 0, ZIndex = 3 }, parent)
	N.surface(card)
	local well = N.create("Frame", { Name = "Well", Position = UDim2.fromOffset(8, 8), Size = UDim2.new(1, -16, 1, -70), BackgroundColor3 = N.PANEL, BorderSizePixel = 0, ZIndex = 3 }, card)
	viewport(well, "Preview")
	local name = N.text(card, "PetLabel", "", UDim2.new(0, 4, 1, -60), UDim2.new(1, -8, 0, 22))
	name.TextSize, name.TextXAlignment, name.TextTruncate = 16, Enum.TextXAlignment.Center, Enum.TextTruncate.AtEnd
	local level = N.text(card, "Level", "", UDim2.new(0, 4, 1, -38), UDim2.new(1, -8, 0, 18), true)
	level.TextSize, level.TextXAlignment, level.Font = 13, Enum.TextXAlignment.Center, N.FONT
	-- "Skin..." names are left alone by the shared menu skin
	local accent = N.create("Frame", { Name = "SkinRarity", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -9), Size = UDim2.new(0.45, 0, 0, 6),
		BackgroundColor3 = N.WHITE, BorderSizePixel = 0, ZIndex = 5 }, card)
	N.create("UICorner", { CornerRadius = UDim.new(0.5, 0) }, accent)
	local badge = N.create("TextLabel", { Name = "Equipped", Text = "✓ EQUIPPED", Size = UDim2.fromOffset(88, 20), Position = UDim2.fromOffset(6, 6), Visible = false,
		BackgroundColor3 = N.GREEN, Font = N.FONT, TextSize = 12, TextColor3 = N.WHITE, BorderSizePixel = 0, ZIndex = 8 }, card)
	N.create("UICorner", { CornerRadius = UDim.new(0.5, 0) }, badge)
	local lock = N.create("Frame", { Name = "Lock", Position = UDim2.fromOffset(8, 8), Size = UDim2.new(1, -16, 1, -70), BackgroundColor3 = Color3.fromRGB(20, 22, 28), BackgroundTransparency = 0.05, Visible = false, BorderSizePixel = 0, ZIndex = 9 }, card)
	N.create("UICorner", { CornerRadius = UDim.new(0, 4) }, lock)
	local mark = N.text(lock, "Mark", "?", UDim2.new(), UDim2.fromScale(1, 1))
	mark.TextSize, mark.TextXAlignment, mark.ZIndex = 44, Enum.TextXAlignment.Center, 10
	local ring = N.create("Frame", { Name = "SelectRing", Position = UDim2.fromOffset(-5, -5), Size = UDim2.new(1, 10, 1, 10), BackgroundTransparency = 1, Visible = false, ZIndex = 11 }, card)
	N.create("UICorner", { CornerRadius = UDim.new(0, 14) }, ring)
	N.create("UIStroke", { Color = Color3.fromRGB(46, 170, 255), Thickness = 4, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, ring)
	N.create("TextButton", { Name = "Select", Text = "", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 12 }, card)
	return card
end

local function petGrid(parent: Instance, name: string, ids: { string }): ScrollingFrame
	local list = N.create("ScrollingFrame", { Name = name, BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromOffset(300, 200),
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y, ScrollBarThickness = 4, ZIndex = 3 }, parent)
	N.create("UIGridLayout", { CellSize = UDim2.fromOffset(150, 172), CellPadding = UDim2.fromOffset(10, 10), SortOrder = Enum.SortOrder.LayoutOrder }, list)
	-- room for the selection ring, which sits outside each card
	N.create("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingTop = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), PaddingBottom = UDim.new(0, 10) }, list)
	for order, id in ids do petCard(list, id, order) end
	return list
end

-- A perk line in the detail: the role on the left, its value on the right
local function perkRow(parent: Instance, index: number)
	local row = N.create("Frame", { Name = "Perk" .. index, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 24), ZIndex = 3 }, parent)
	N.text(row, "Role", "", UDim2.new(), UDim2.new(0.6, 0, 1, 0), true).TextSize = 15
	local value = N.text(row, "Value", "", UDim2.fromScale(0.5, 0), UDim2.fromScale(0.5, 1))
	value.TextSize, value.TextXAlignment = 17, Enum.TextXAlignment.Right
end

function Pets.build(): ScreenGui
	local gui = N.menu("PetsMenu", "Pets", N.GREEN, 860, 620)
	gui.DisplayOrder = 20
	gui:SetAttribute("PetsLayout", Pets.LAYOUT)
	local p = gui.Panel :: any
	local nav = N.button(gui, "PetsButton", "", UDim2.fromOffset(14, 170), UDim2.fromOffset(64, 64), N.GREEN)
	N.create("ImageLabel", { Name = "Icon", Image = Icons.pets, BackgroundTransparency = 1, Size = UDim2.fromScale(.7, .6), Position = UDim2.fromScale(.15, .05), ScaleType = Enum.ScaleType.Fit, ZIndex = 5 }, nav)
	N.text(p, "Wallet", "0 shards", UDim2.new(1, -290, 0, 12), UDim2.fromOffset(230, 30), true)
	-- two centred tabs: the pets you own, and the full index
	local tabs = N.create("Frame", { Name = "Tabs", BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 60), Size = UDim2.new(1, -24, 0, 40), ZIndex = 3 }, p)
	for i, id in { "pets", "index" } do
		local tab = N.button(tabs, id .. "Tab", if id == "pets" then "MY PETS" else "PET INDEX", UDim2.new((i - 1) / 2, if i == 1 then 0 else 4, 0, 0), UDim2.new(1 / 2, -4, 1, 0), N.CARD)
		tab.TextSize = 16
	end

	-- MY PETS: how many are out and the bonuses they give, above everything you own
	local petsScreen = N.create("Frame", { Name = "PetsScreen", BackgroundTransparency = 1, Size = UDim2.fromOffset(400, 300), ZIndex = 3 }, p)
	local slots = N.create("Frame", { Name = "Slots", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 22), ZIndex = 3 }, petsScreen)
	N.text(slots, "Title", "Equipped: 0 / 1", UDim2.new(), UDim2.fromScale(1, 1)).TextSize = 16
	local bonusBar = N.create("Frame", { Name = "BonusBar", Position = UDim2.fromOffset(0, 26), Size = UDim2.new(1, 0, 0, 36), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 3 }, petsScreen)
	local bonuses = N.text(bonusBar, "Bonuses", "", UDim2.new(), UDim2.fromScale(1, 1), true)
	bonuses.RichText, bonuses.TextTruncate, bonuses.TextSize = true, Enum.TextTruncate.AtEnd, 14
	petGrid(petsScreen, "List", (function() local ids = {} for _, def in Config.Pets.List do table.insert(ids, def.Id) end return ids end)())
	N.text(petsScreen, "Empty", "No pets yet. Hatch an egg at the Hatchery in town!", UDim2.fromOffset(0, 110), UDim2.new(1, 0, 0, 60), true).TextWrapped = true

	-- PET INDEX: every pet in the game, found or not
	local index = N.create("Frame", { Name = "IndexScreen", BackgroundTransparency = 1, Size = UDim2.fromOffset(400, 300), ZIndex = 3 }, p)
	N.text(index, "Progress", "DISCOVERED 0/0", UDim2.fromOffset(0, 0), UDim2.new(1, 0, 0, 22)).TextSize = 16
	local bar = N.create("Frame", { Name = "ProgressBar", Position = UDim2.fromOffset(0, 26), Size = UDim2.new(1, 0, 0, 12), BackgroundColor3 = N.PANEL, BorderSizePixel = 0, ZIndex = 3 }, index)
	N.create("Frame", { Name = "Fill", Size = UDim2.fromScale(0, 1), BackgroundColor3 = N.GREEN, BorderSizePixel = 0, ZIndex = 4 }, bar)
	petGrid(index, "List", PetsLayout.indexOrder())

	-- Detail: the selected pet. Its body scrolls where the screen is short; the action stays pinned below it.
	local detail = N.create("Frame", { Name = "Detail", Size = UDim2.fromOffset(300, 300), BackgroundColor3 = N.CARD, BorderSizePixel = 0, ZIndex = 3 }, p)
	N.surface(detail)
	local body = N.create("ScrollingFrame", { Name = "Body", Position = UDim2.fromOffset(10, 8), Size = UDim2.new(1, -20, 1, -64), BackgroundTransparency = 1, BorderSizePixel = 0,
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 4, ScrollingDirection = Enum.ScrollingDirection.Y, ZIndex = 3 }, detail)
	local name = N.text(body, "PetName", "", UDim2.new(), UDim2.new(1, 0, 0, 28))
	name.TextSize, name.TextXAlignment, name.TextTruncate = 24, Enum.TextXAlignment.Center, Enum.TextTruncate.AtEnd
	local rarity = N.text(body, "Rarity", "", UDim2.fromOffset(0, 28), UDim2.new(1, 0, 0, 18), true)
	rarity.TextSize, rarity.TextXAlignment, rarity.Font = 14, Enum.TextXAlignment.Center, N.FONT
	local well = N.create("Frame", { Name = "PreviewWell", Position = UDim2.fromOffset(0, 52), Size = UDim2.fromOffset(120, 120), BackgroundColor3 = N.PANEL, BorderSizePixel = 0, ZIndex = 3 }, body)
	N.surface(well); viewport(well, "Preview")
	N.text(body, "Level", "", UDim2.fromOffset(0, 180), UDim2.new(0.5, 0, 0, 18), true).TextSize = 14
	local xpText = N.text(body, "XpText", "", UDim2.fromScale(0.5, 0), UDim2.new(0.5, 0, 0, 18), true)
	xpText.TextSize, xpText.TextXAlignment = 13, Enum.TextXAlignment.Right
	local xp = N.create("Frame", { Name = "XpBar", Position = UDim2.fromOffset(0, 202), Size = UDim2.new(1, 0, 0, 12), BackgroundColor3 = N.PANEL, BorderSizePixel = 0, ZIndex = 3 }, body)
	N.create("Frame", { Name = "Fill", Size = UDim2.fromScale(0, 1), BackgroundColor3 = N.CYAN, BorderSizePixel = 0, ZIndex = 4 }, xp)
	for i = 1, 3 do perkRow(body, i) end
	local how = N.button(body, "HowButton", "How bonuses work ▼", UDim2.fromOffset(0, 300), UDim2.new(1, 0, 0, 30), N.CARD)
	how.TextSize = 14
	local perkText = N.text(body, "PerkText", "", UDim2.fromOffset(0, 336), UDim2.new(1, -4, 0, 0), true)
	perkText.RichText, perkText.TextWrapped, perkText.AutomaticSize, perkText.TextYAlignment, perkText.TextSize = true, true, Enum.AutomaticSize.Y, Enum.TextYAlignment.Top, 14
	N.button(detail, "Action", "", UDim2.new(0, 10, 1, -52), UDim2.new(1, -20, 0, 44), N.GREEN)

	N.text(p, "Footer", "", UDim2.new(0, 12, 1, -52), UDim2.new(1, -24, 0, 40), true).TextWrapped = true
	return gui
end

return Pets
