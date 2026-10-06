--!strict
-- Instanced only by the local world controller. Never builds a ScreenGui.
local Config = require(script.Parent.Config)
local EquipmentModels = require(script.Parent.EquipmentModels)
local Equipment = require(script.Parent.WorldEquipment)
local Format = require(script.Parent.Format)
local Display = {}
local View = {}
View.__index = View
local STATUS_COLORS = {
	CURRENT = Color3.fromRGB(255, 215, 54),
	UNLOCKED = Color3.fromRGB(130, 245, 183),
	LOCKED = Color3.fromRGB(174, 188, 207),
}

local function make(kind: string, tier: number, frame: CFrame, scale: number, parent: Instance): Model
	local model = if kind == "pickaxe" then EquipmentModels.pickaxe(tier) else EquipmentModels.backpack(tier)
	model:ScaleTo(scale)
	model:PivotTo(frame)
	for _, v in model:GetDescendants() do
		if v:IsA("BasePart") then
			v.Anchored, v.CanCollide, v.CanTouch, v.CanQuery = true, false, false, false
		end
	end
	model.Parent = parent
	return model
end

local function mountFrame(mount: Instance): CFrame
	local pivot = if mount:IsA("Model") then mount:GetPivot() else (mount :: BasePart).CFrame
	local offset = mount:GetAttribute("DisplayOffset")
	assert(typeof(offset) == "CFrame", "Missing relative equipment mount")
	return pivot * offset
end

local function statsLabel(stand: Instance): TextLabel?
	local found = stand:FindFirstChild("Stats", true)
	return if found and found:IsA("TextLabel") then found else nil
end

function Display.mount(hall: Instance): any
	assert(not hall:FindFirstChild("LocalEquipment"), "World displays already mounted")
	local walls, stands = hall:FindFirstChild("TierWalls"), hall:FindFirstChild("CurrentStands")
	assert(walls and stands, "Missing Gear Hall mounts")
	local folder = Instance.new("Folder")
	folder.Name = "LocalEquipment"
	folder:SetAttribute("LocalGearDisplays", true)
	folder.Parent = hall
	local self: any = setmetatable({ folder = folder, cards = {}, stands = {}, current = {}, angle = 0, dead = false }, View)
	for _, kind in { "pickaxe", "backpack" } do
		local catalog = if kind == "pickaxe" then Config.Pickaxes else Config.Backpacks
		for _, item in catalog do
			local card = walls:FindFirstChild(kind .. item.Tier)
			assert(card and card:IsA("BasePart"), "Missing tier mount")
			local model = make(kind, item.Tier, mountFrame(card), card:GetAttribute("DisplayScale") or 1.5, folder)
			model.Name = "Tier_" .. kind .. "_" .. item.Tier
			local colors = {}
			for _, p in model:GetDescendants() do if p:IsA("BasePart") then colors[p] = p.Color end end
			local label = card:FindFirstChild("Status", true)
			table.insert(self.cards, { kind = kind, tier = item.Tier, model = model, colors = colors,
				label = if label and label:IsA("TextLabel") then label else nil })
		end
		local stand = stands:FindFirstChild(kind)
		assert(stand and stand:IsA("Model"), "Missing current equipment stand")
		self.stands[kind] = stand
	end
	self:update(nil)
	return self
end

function View:update(state: any)
	if self.dead then return end
	for _, kind in { "pickaxe", "backpack" } do
		local row = Equipment.current(kind, state)
		local current = self.current[kind]
		if not current or current.tier ~= row.tier then
			if current then current.model:Destroy() end
			local stand = self.stands[kind]
			local model = make(kind, row.tier, mountFrame(stand), stand:GetAttribute("DisplayScale") or 2.2, self.folder)
			model.Name = "Current_" .. kind
			local bottom = stand:GetAttribute("DisplayBottomOffset")
			if typeof(bottom) == "Vector3" then
				local target = stand:GetPivot():PointToWorldSpace(bottom).Y
				local lowest = math.huge
				for _, p in model:GetDescendants() do
					if p:IsA("BasePart") then
						for _, x in { -0.5, 0.5 } do for _, y in { -0.5, 0.5 } do for _, z in { -0.5, 0.5 } do
							lowest = math.min(lowest, p.CFrame:PointToWorldSpace(p.Size * Vector3.new(x, y, z)).Y)
						end end end
					end
				end
				model:PivotTo(model:GetPivot() + Vector3.new(0, target - lowest, 0))
			end
			current = { model = model, tier = row.tier, base = model:GetPivot() }
			self.current[kind] = current
			model:PivotTo(current.base * CFrame.Angles(0, self.angle, 0))
		end
		local label = statsLabel(self.stands[kind])
		if kind == "pickaxe" then
			current.model:SetAttribute("Power", row.stats.power)
			current.model:SetAttribute("Swing", row.stats.swing)
			current.model:SetAttribute("Reach", row.stats.reach)
			if label then label.Text = string.format("%s\nPOWER %.2f  ·  %.2fs\nREACH %.1f  ·  CRIT %.1f%%", row.name, row.stats.power, row.stats.swing, row.stats.reach, row.stats.critChance * 100) end
		else
			current.model:SetAttribute("Capacity", row.stats.capacity)
			if label then label.Text = row.name .. "\n" .. Format.number(math.floor(row.stats.capacity)) .. " ORE CAPACITY" end
		end
		for _, card in self.cards do
			if card.kind == kind then
				local status = if card.tier == row.tier then "CURRENT" elseif card.tier < row.tier then "UNLOCKED" else "LOCKED"
				if card.status ~= status then
					card.status = status
					card.model:SetAttribute("Ownership", status)
					if card.label then card.label.Text, card.label.TextColor3 = status, STATUS_COLORS[status] end
					for p, color in card.colors do
						p.Color = if status == "LOCKED" then color:Lerp(Color3.fromRGB(72, 82, 100), 0.65) else color
					end
				end
			end
		end
	end
end

function View:step(dt: number)
	if self.dead or dt ~= dt or dt < 0 or dt == math.huge then return end
	self.angle = (self.angle + math.rad(22) * dt) % (2 * math.pi)
	for _, current in self.current do current.model:PivotTo(current.base * CFrame.Angles(0, self.angle, 0)) end
end

function View:destroy()
	if self.dead then return end
	self.dead = true
	self.folder:Destroy()
	self.current = {}
end

return Display
