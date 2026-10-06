--!strict
-- A Gatherer-style upgrade view shared by the gear shop and the refinery: a
-- portrait box with the level and cost under it, selectable stat rows showing
-- the value and its +delta, amount buttons and a big green Upgrade button.
-- Plain Instances built once inside an authored menu screen and marked
-- CartoonCustom so the shared menu skin leaves them alone. The owning
-- controller fills in every value and decides what each press does.
local Cartoon = require(script.Parent.Cartoon)

local UpgradePanel = {}
UpgradePanel.__index = UpgradePanel

local WHITE = Color3.new(1, 1, 1)
local NAVY = Color3.fromRGB(22, 50, 118)
local NAME_FILL = Color3.fromRGB(120, 182, 255)
local VALUE_FILL = Color3.fromRGB(232, 244, 255)
local DELTA_FILL = Color3.fromRGB(150, 245, 80)
local DELTA_INK = Color3.fromRGB(22, 86, 16)
local LEVEL_FILL = Color3.fromRGB(255, 214, 64)
local LEVEL_INK = Color3.fromRGB(120, 66, 0)
local COST_FILL = Color3.fromRGB(120, 236, 70)

export type Row = { id: string, name: string, value: string, delta: string?, locked: boolean? }
export type Info = {
	levelLabel: string?, level: string, costLabel: string?, cost: string,
	button: string, enabled: boolean, tone: string?, amounts: boolean?,
}
export type Options = { amounts: { string }, portrait: boolean }

local function make(class: string, props: { [string]: any }, parent: Instance?): any
	local item = Instance.new(class)
	for key, value in props do (item :: any)[key] = value end
	if parent then item.Parent = parent end
	return item
end

local function label(parent: Instance, name: string, fill: Color3, ink: Color3, align: Enum.TextXAlignment?): TextLabel
	local text = make("TextLabel", {
		Name = name, BackgroundTransparency = 1, Font = Cartoon.FONT, Text = "", TextColor3 = fill,
		TextScaled = true, TextXAlignment = align or Enum.TextXAlignment.Center, ZIndex = 4,
	}, parent)
	Cartoon.textStroke(3, ink).Parent = text
	make("UITextSizeConstraint", { Name = "Limit", MaxTextSize = 40, MinTextSize = 9 }, text)
	return text
end

local function limit(text: TextLabel, size: number)
	(text:FindFirstChild("Limit") :: UITextSizeConstraint).MaxTextSize = size
end

-- A transparent button painted with swappable cartoon faces and an outlined label.
local function cartoonButton(parent: Instance, name: string, kinds: { string }, options: Cartoon.SurfaceOptions?)
	local button = make("TextButton", {
		Name = name, BackgroundTransparency = 1, Text = "", AutoButtonColor = false, ZIndex = 3,
	}, parent)
	local faces: { [string]: Frame } = {}
	for _, kind in kinds do
		local face = Cartoon.surface(kind, options)
		face.Name, face.Visible = kind .. "Face", false
		face.Parent = button
		faces[kind] = face
	end
	local text = label(button, "Label", WHITE, Cartoon.INK)
	text.Position, text.Size = UDim2.fromScale(0.08, 0.14), UDim2.fromScale(0.84, 0.66)
	return button, faces, text
end

local function show(faces: { [string]: Frame }, kind: string)
	for name, face in faces do face.Visible = name == kind end
end

function UpgradePanel.new(parent: Instance, options: Options)
	local self = setmetatable({}, UpgradePanel) :: any
	self.options = options
	self.rows = {} :: { [string]: any }
	self.order = {} :: { string }
	self.selected = nil :: string?
	self.amount = 1
	self.onSelect = function(_id: string) end
	self.onAmount = function(_index: number) end
	self.onUpgrade = function() end

	local root = make("Frame", { Name = "UpgradeView", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 1 })
	root:SetAttribute("CartoonCustom", true)
	self.root = root

	-- Left column: the portrait, then Level and Cost like the reference.
	local portrait = make("Frame", { Name = "Portrait", BackgroundColor3 = Color3.fromRGB(96, 146, 214), BorderSizePixel = 0,
		Visible = options.portrait, ZIndex = 2 }, root)
	make("UICorner", { CornerRadius = UDim.new(0, 12) }, portrait)
	make("UIStroke", { Color = NAVY, Thickness = 4, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, portrait)
	make("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(150, 196, 255), Color3.fromRGB(74, 122, 196)) }, portrait)
	self.art = make("ImageLabel", { Name = "Art", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.72, 0.72), ScaleType = Enum.ScaleType.Fit, ZIndex = 3 }, portrait)
	self.portrait = portrait
	self.levelLabel = label(root, "LevelLabel", LEVEL_FILL, LEVEL_INK)
	self.level = label(root, "Level", LEVEL_FILL, LEVEL_INK)
	self.costLabel = label(root, "CostLabel", COST_FILL, DELTA_INK)
	self.cost = label(root, "Cost", COST_FILL, DELTA_INK)

	-- Right column: stat rows, amount buttons and the Upgrade button.
	self.rowArea = make("Frame", { Name = "Rows", BackgroundTransparency = 1, ZIndex = 2 }, root)
	self.amounts = {} :: { any }
	for index, text in options.amounts do
		local button, faces, caption = cartoonButton(root, "Amount" .. index, { "green", "blue" }, { radius = 10, edge = 3, lip = 4, stripes = true })
		caption.Text = text
		button.Activated:Connect(function() self.onAmount(index) end)
		table.insert(self.amounts, { button = button, faces = faces, caption = caption })
	end
	local upgrade, faces, caption = cartoonButton(root, "Upgrade", { "green", "purple", "slate" }, { radius = 14, edge = 3.5, lip = 6, studs = 0.86, studSize = 34 })
	upgrade.Activated:Connect(function() if upgrade.Active then self.onUpgrade() end end)
	self.upgrade, self.upgradeFaces, self.upgradeCaption = upgrade, faces, caption

	root.Parent = parent
	return self
end

-- Rows are created once per id, in order; values change through :setRows.
function UpgradePanel:setRows(rows: { Row })
	for index, row in rows do
		local view = self.rows[row.id]
		if not view then
			local button = make("TextButton", { Name = row.id .. "Row", BackgroundTransparency = 1, Text = "", AutoButtonColor = false, ZIndex = 2 }, self.rowArea)
			-- Selected rows sit on a soft blue pill like a highlighted line in the reference.
			local highlight = make("Frame", { Name = "Highlight", BackgroundColor3 = Color3.fromRGB(206, 230, 255), BorderSizePixel = 0,
				Size = UDim2.fromScale(1, 1), Visible = false, ZIndex = 2 }, button)
			make("UICorner", { CornerRadius = UDim.new(0, 12) }, highlight)
			make("UIStroke", { Color = Color3.fromRGB(60, 130, 230), Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, highlight)
			local name = label(button, "StatName", NAME_FILL, NAVY, Enum.TextXAlignment.Left)
			local value = label(button, "Value", VALUE_FILL, NAVY, Enum.TextXAlignment.Right)
			local delta = label(button, "Delta", DELTA_FILL, DELTA_INK, Enum.TextXAlignment.Right)
			button.Activated:Connect(function() self.onSelect(row.id) end)
			view = { button = button, highlight = highlight, name = name, value = value, delta = delta }
			self.rows[row.id] = view
			table.insert(self.order, row.id)
		end
		view.button.LayoutOrder = index
		view.name.Text, view.value.Text, view.delta.Text = row.name, row.value, row.delta or ""
		view.delta.TextColor3 = if row.locked then Color3.fromRGB(255, 196, 120) else DELTA_FILL
		view.highlight.Visible = self.selected == row.id
	end
	if self.width then self:layout(self.width, self.height, self.wide) end
end

function UpgradePanel:select(id: string?)
	self.selected = id
	for rowId, view in self.rows do view.highlight.Visible = rowId == id end
end

function UpgradePanel:setPortrait(image: string?)
	self.art.Image = image or ""
end

function UpgradePanel:setInfo(info: Info, amountIndex: number)
	self.levelLabel.Text, self.level.Text = info.levelLabel or "Level", info.level
	self.costLabel.Text, self.cost.Text = info.costLabel or "Cost", info.cost
	self.upgradeCaption.Text = info.button
	show(self.upgradeFaces, if not info.enabled then "slate" else info.tone or "green")
	self.upgrade.Active, self.upgrade.Selectable = info.enabled, info.enabled
	for index, amount in self.amounts do
		amount.button.Visible = info.amounts ~= false
		show(amount.faces, if index == amountIndex then "green" else "blue")
	end
end

-- Lay everything out for a w x h area. Wide areas get the reference's two
-- columns; narrow ones drop the portrait and put Level and Cost on one line.
function UpgradePanel:layout(w: number, h: number, wideOverride: boolean?)
	self.width, self.height, self.wide = w, h, wideOverride
	local wide = if wideOverride == nil then w >= 520 else wideOverride
	local gap = 10
	local upgradeH = math.clamp(math.floor(h * 0.17), 44, 60)
	local amountH = math.clamp(math.floor(h * 0.13), 36, 46)
	local left, rightX = 0, 0
	if wide then
		left = math.clamp(math.floor(w * 0.3), 170, 240)
		rightX = left + 22
		local infoH = 128
		local portraitSize = math.max(60, math.min(left, h - infoH - gap))
		self.portrait.Visible = self.options.portrait
		self.portrait.Position = UDim2.fromOffset(math.floor((left - portraitSize) / 2), 2)
		self.portrait.Size = UDim2.fromOffset(portraitSize, portraitSize)
		self.portraitRect = { x = math.floor((left - portraitSize) / 2), y = 2, w = portraitSize, h = portraitSize }
		local y = portraitSize + gap
		local function place(text: TextLabel, height: number, size: number)
			text.Position, text.Size = UDim2.fromOffset(0, y), UDim2.fromOffset(left, height)
			limit(text, size)
			y += height
		end
		place(self.levelLabel, 22, 22)
		place(self.level, 40, 38)
		place(self.costLabel, 22, 22)
		place(self.cost, 40, 38)
	else
		self.portrait.Visible = false
		self.portraitRect = nil
		local half = math.floor((w - gap) / 2)
		self.levelLabel.Position, self.levelLabel.Size = UDim2.fromOffset(0, 0), UDim2.fromOffset(half, 16)
		self.level.Position, self.level.Size = UDim2.fromOffset(0, 16), UDim2.fromOffset(half, 28)
		self.costLabel.Position, self.costLabel.Size = UDim2.fromOffset(half + gap, 0), UDim2.fromOffset(half, 16)
		self.cost.Position, self.cost.Size = UDim2.fromOffset(half + gap, 16), UDim2.fromOffset(half, 28)
		for _, text in { self.levelLabel, self.costLabel } do limit(text, 16) end
		for _, text in { self.level, self.cost } do limit(text, 28) end
	end
	local rightW = w - rightX
	local top = if wide then 0 else 50
	local upgradeY = h - upgradeH - 6
	local amountY = upgradeY - gap - amountH
	local rowsH = math.max(0, amountY - gap - top)
	self.rowArea.Position, self.rowArea.Size = UDim2.fromOffset(rightX, top), UDim2.fromOffset(rightW, rowsH)
	local count = math.max(#self.order, 1)
	local rowH = math.min(64, math.floor((rowsH - 4 * (count - 1)) / count))
	for _, id in self.order do
		local view = self.rows[id]
		local index = view.button.LayoutOrder
		view.button.Position = UDim2.fromOffset(0, (index - 1) * (rowH + 4))
		view.button.Size = UDim2.fromOffset(rightW, rowH)
		local nameW = math.floor(rightW * 0.5)
		local valueH = math.floor(rowH * (if view.delta.Text ~= "" then 0.56 else 0.8))
		view.name.Position, view.name.Size = UDim2.fromOffset(12, math.floor(rowH * 0.14)), UDim2.fromOffset(nameW, math.floor(rowH * 0.72))
		view.value.Position, view.value.Size = UDim2.fromOffset(nameW + 12, math.floor(rowH * 0.06)), UDim2.fromOffset(rightW - nameW - 24, valueH)
		view.delta.Position, view.delta.Size = UDim2.fromOffset(nameW + 12, math.floor(rowH * 0.06) + valueH), UDim2.fromOffset(rightW - nameW - 24, math.floor(rowH * 0.36))
		limit(view.name, 30); limit(view.value, 28); limit(view.delta, 20)
	end
	local amountCount = #self.amounts
	local amountW = math.floor((rightW - gap * (amountCount - 1)) / math.max(amountCount, 1))
	amountW = math.min(amountW, 96)
	local amountsX = rightX + math.floor((rightW - (amountW * amountCount + gap * (amountCount - 1))) / 2)
	for index, amount in self.amounts do
		amount.button.Position = UDim2.fromOffset(amountsX + (index - 1) * (amountW + gap), amountY)
		amount.button.Size = UDim2.fromOffset(amountW, amountH)
		limit(amount.caption, 24)
	end
	self.upgrade.Position, self.upgrade.Size = UDim2.fromOffset(rightX, upgradeY), UDim2.fromOffset(rightW, upgradeH)
	limit(self.upgradeCaption, 34)
end

return UpgradePanel
