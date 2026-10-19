--!strict
-- Roblox's Text Size accessibility setting (GuiService.PreferredTextSize) enlarges every label with a fixed
-- TextSize, which overflows the HUD and menus built for exact sizes. Labels that are TextScaled or carry a
-- UITextSizeConstraint are exempt, so every other label in the PlayerGui gets a constraint pinned to the size it
-- is drawn at: its TextSize times the UIScales above it (a constraint limits the on-screen size). It follows
-- TextSize and scale changes and steps aside while the label is TextScaled.
-- A label's own constraint (authored for the menu's 1080p layout) is scaled the same way (Shared.MenuFit.textLimits),
-- or its text would stop growing while the menu around it grows on a big screen. The authored limits are kept in
-- BaseMinTextSize / BaseMaxTextSize attributes; a controller writing MaxTextSize later sets a new base.
local Players = game:GetService("Players")
local MenuFit = require(game:GetService("ReplicatedStorage").Shared.MenuFit)

local FixedTextSize = {}
local NAME = "FixedTextSize"
local pinned: { [Instance]: true } = setmetatable({}, { __mode = "k" }) :: any

local function drawnScale(label: Instance): number
	local scale = 1
	local node: Instance? = label
	while node and not node:IsA("LayerCollector") do
		for _, child in node:GetChildren() do
			if child:IsA("UIScale") then scale *= child.Scale end
		end
		node = node.Parent
	end
	return scale
end

-- Keeps a label's own constraint at its authored limits times the drawn scale
local function follow(label: GuiObject, own: UITextSizeConstraint)
	if own:GetAttribute("BaseMaxTextSize") == nil then
		own:SetAttribute("BaseMaxTextSize", own.MaxTextSize)
		own:SetAttribute("BaseMinTextSize", own.MinTextSize)
	end
	local applied = own.MaxTextSize
	local function sync()
		if not label.Parent then return end
		local min, max = MenuFit.textLimits(own:GetAttribute("BaseMinTextSize") :: number, own:GetAttribute("BaseMaxTextSize") :: number, drawnScale(label))
		applied = max
		if own.MinTextSize == min and own.MaxTextSize == max then return end
		-- MaxTextSize first when growing so Min never passes Max
		if max > own.MaxTextSize then own.MaxTextSize = max; own.MinTextSize = min else own.MinTextSize = min; own.MaxTextSize = max end
	end
	own:GetPropertyChangedSignal("MaxTextSize"):Connect(function()
		if own.MaxTextSize ~= applied then
			-- written from outside (MenuTheme.button follows its TextSize, StoreController sizes titles): the new base
			own:SetAttribute("BaseMaxTextSize", own.MaxTextSize)
			own:SetAttribute("BaseMinTextSize", math.min(own:GetAttribute("BaseMinTextSize") :: number, own.MaxTextSize))
			sync()
		end
	end)
	label:GetPropertyChangedSignal("AbsoluteSize"):Connect(sync)
	label.AncestryChanged:Connect(sync)
	sync()
end

local function pin(label: TextLabel | TextButton | TextBox)
	if pinned[label] then return end
	local own = label:FindFirstChildOfClass("UITextSizeConstraint")
	if own and own.Name ~= NAME then
		pinned[label] = true
		follow(label, own)
		return
	end
	pinned[label] = true
	local constraint = own :: UITextSizeConstraint?
	local function sync()
		if label.TextScaled or not label.Parent then
			if constraint then constraint.Parent = nil end
			return
		end
		if not constraint then
			constraint = Instance.new("UITextSizeConstraint")
			;(constraint :: UITextSizeConstraint).Name = NAME
		end
		local c = constraint :: UITextSizeConstraint
		local size = math.clamp(math.floor(label.TextSize * drawnScale(label) + 0.5), 1, 100)
		if c.MinTextSize == size and c.MaxTextSize == size and c.Parent == label then return end
		-- MaxTextSize first when growing so Min never passes Max
		if size > c.MaxTextSize then c.MaxTextSize = size; c.MinTextSize = size else c.MinTextSize = size; c.MaxTextSize = size end
		c.Parent = label
	end
	label:GetPropertyChangedSignal("TextSize"):Connect(sync)
	label:GetPropertyChangedSignal("TextScaled"):Connect(sync)
	-- a UIScale above changing moves the AbsoluteSize, as does a reparent
	label:GetPropertyChangedSignal("AbsoluteSize"):Connect(sync)
	label.AncestryChanged:Connect(sync)
	-- a constraint of the label's own, added later, takes over
	label.ChildAdded:Connect(function(child)
		if child:IsA("UITextSizeConstraint") and child.Name ~= NAME and constraint then
			constraint:Destroy()
			constraint = nil
			follow(label, child)
		end
	end)
	sync()
end

local function visit(instance: Instance)
	if instance:IsA("TextLabel") or instance:IsA("TextButton") or instance:IsA("TextBox") then
		-- a constraint authored after the label is parented arrives a moment later
		task.defer(pin, instance :: any)
	end
end

function FixedTextSize.start()
	local gui = Players.LocalPlayer:WaitForChild("PlayerGui")
	for _, descendant in gui:GetDescendants() do visit(descendant) end
	gui.DescendantAdded:Connect(visit)
end

return FixedTextSize
