--!strict
-- Health bars above meteor ore clusters, the core and debris rocks. A cluster or
-- rock only gets a bar on your screen after you have hit it yourself. The core's
-- big bar is shared: everyone sees it once the core is exposed (or when close).
-- HP comes from the Hp / MaxHp attributes NodeService replicates at ~10 Hz.
-- A meteor bar whose HP climbs back while its max holds (an Ice node refreezing,
-- spec §8.1) is tinted frost until the next hit.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local WorldMap = require(ReplicatedStorage.Shared.WorldMap)
local Knit = require(ReplicatedStorage.Packages.Knit)

local player = Players.LocalPlayer

local NodeHealthController = Knit.CreateController({
	Name = "NodeHealthController",
})

local NEAR_DISTANCE = 26

-- Parts the local player has landed a hit on
local hitByMe: { [BasePart]: boolean } = {}

type Bar = {
	Part: BasePart,
	Gui: BillboardGui,
	Fill: Frame,
	Label: TextLabel?,
	IsCore: boolean,
	CanRefreeze: boolean, -- meteor nodes and the core; debris HP only rises on respawn
	LastFraction: number, -- HP fraction at the last Hp change
	Frosted: boolean,
	Connections: { RBXScriptConnection },
}

local bars: { [BasePart]: Bar } = {}

local GREEN = Color3.fromRGB(105, 240, 103)
local YELLOW = Color3.fromRGB(255, 210, 72)
local RED = Color3.fromRGB(235, 80, 70)
local FROST = Color3.fromRGB(150, 225, 255)

local function colorFor(fraction: number): Color3
	if fraction > 0.5 then
		return YELLOW:Lerp(GREEN, (fraction - 0.5) * 2)
	end
	return RED:Lerp(YELLOW, fraction * 2)
end

local function fractionOf(part: BasePart): number?
	local hp = part:GetAttribute("Hp")
	local maxHp = part:GetAttribute("MaxHp")
	if typeof(hp) ~= "number" or typeof(maxHp) ~= "number" or maxHp <= 0 then
		return nil
	end
	return math.clamp(hp / maxHp, 0, 1)
end

local function update(bar: Bar)
	local fraction = fractionOf(bar.Part)
	if not fraction then
		return
	end
	bar.Fill.Size = UDim2.fromScale(fraction, 1)
	bar.Fill.BackgroundColor3 = if bar.Frosted
		then FROST
		elseif bar.IsCore then Color3.fromRGB(255, 174, 52)
		else colorFor(fraction)
	if bar.Label then
		-- HP runs on hidden Mining Power (spec §5.3), so show how much is left
		bar.Label.Text = string.format("%d%%", math.ceil(fraction * 100))
	end
end

local function remove(part: BasePart)
	local bar = bars[part]
	if not bar then
		return
	end
	bars[part] = nil
	hitByMe[part] = nil
	for _, connection in bar.Connections do
		connection:Disconnect()
	end
	bar.Gui:Destroy()
end

local function add(part: BasePart)
	if bars[part] or part:GetAttribute("TargetId") == nil then
		return
	end
	local isCore = part:GetAttribute("TargetKind") == "Core"

	local gui = Instance.new("BillboardGui")
	gui.Name = "NodeHealth"
	gui.Adornee = part
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = if isCore then 400 else 90
	gui.Size = if isCore then UDim2.new(14, 0, 1.2, 0) else UDim2.new(3.6, 0, 0.42, 0)
	gui.StudsOffsetWorldSpace = Vector3.new(0, part.Size.Y / 2 + (if isCore then 6 else 1.4), 0)
	gui.Enabled = false

	local back = Instance.new("Frame")
	back.Size = UDim2.fromScale(1, 1)
	back.BackgroundColor3 = Color3.fromRGB(66, 49, 37)
	back.BackgroundTransparency = 0.05
	back.BorderSizePixel = 0
	back.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = back
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(31, 22, 19)
	stroke.Thickness = 3
	stroke.Transparency = 0
	stroke.Parent = back

	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BorderSizePixel = 0
	fill.Parent = back
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0.5, 0)
	fillCorner.Parent = fill

	local label: TextLabel? = nil
	if isCore then
		local text = Instance.new("TextLabel")
		text.BackgroundTransparency = 1
		text.Size = UDim2.fromScale(1, 1)
		text.Font = Enum.Font.FredokaOne
		text.TextScaled = true
		text.TextColor3 = Color3.new(1, 1, 1)
		text.TextStrokeColor3 = Color3.fromRGB(31, 22, 19)
		text.TextStrokeTransparency = 0
		text.ZIndex = 2
		text.Parent = back
		label = text
	end

	gui.Parent = player:WaitForChild("PlayerGui")

	local bar: Bar = {
		Part = part,
		Gui = gui,
		Fill = fill,
		Label = label,
		IsCore = isCore,
		CanRefreeze = part:GetAttribute("TargetKind") ~= "Debris",
		LastFraction = fractionOf(part) or 1,
		Frosted = false,
		Connections = {},
	}
	bars[part] = bar
	update(bar)

	table.insert(bar.Connections, part:GetAttributeChangedSignal("Hp"):Connect(function()
		-- A rescale keeps the fraction, a hit lowers it; only a refreeze raises it
		local fraction = fractionOf(part)
		if fraction then
			bar.Frosted = bar.CanRefreeze and fraction > bar.LastFraction + 1e-4
			bar.LastFraction = fraction
		end
		update(bar)
		-- A respawned debris rock comes back at full HP: forget the old hits
		local hp, maxHp = part:GetAttribute("Hp"), part:GetAttribute("MaxHp")
		if typeof(hp) == "number" and typeof(maxHp) == "number" and hp >= maxHp then
			hitByMe[part] = nil
		end
	end))
	table.insert(bar.Connections, part:GetAttributeChangedSignal("MaxHp"):Connect(function()
		-- A new max is a rescale or a respawn, never a refreeze
		bar.Frosted = false
		update(bar)
	end))
	table.insert(bar.Connections, part:GetAttributeChangedSignal("TargetId"):Connect(function()
		if part:GetAttribute("TargetId") == nil then
			remove(part)
		end
	end))
	table.insert(bar.Connections, part.AncestryChanged:Connect(function()
		if not part:IsDescendantOf(workspace) then
			remove(part)
		end
	end))
end

local function watch(container: Instance)
	for _, descendant in container:GetDescendants() do
		if descendant:IsA("BasePart") and descendant:GetAttribute("TargetId") ~= nil then
			add(descendant)
		end
	end
	container.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("BasePart") then
			-- Attributes may arrive a moment after the part replicates
			if descendant:GetAttribute("TargetId") ~= nil then
				add(descendant)
			else
				local connection
				connection = descendant:GetAttributeChangedSignal("TargetId"):Connect(function()
					connection:Disconnect()
					add(descendant)
				end)
			end
		end
	end)
end

function NodeHealthController:KnitStart()
	Knit.GetController("MiningController").Hit:Connect(function(part: BasePart)
		hitByMe[part] = true
	end)

	local map = WorldMap.wait()
	watch(map:WaitForChild("Crater"):WaitForChild("ActiveMeteor"))
	watch(map:WaitForChild("Debris"))
	-- Debris respawns reuse the same part; re-add when the TargetId comes back
	for _, rock in map.Debris:GetChildren() do
		rock:GetAttributeChangedSignal("TargetId"):Connect(function()
			if rock:IsA("BasePart") and rock:GetAttribute("TargetId") ~= nil then
				add(rock)
			end
		end)
	end

	-- Your own targets show their bar; the core's bar is for everyone
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < 0.2 then
			return
		end
		accumulator = 0
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		for part, bar in bars do
			local hp = part:GetAttribute("Hp")
			local maxHp = part:GetAttribute("MaxHp")
			local alive = typeof(hp) == "number" and typeof(maxHp) == "number" and hp > 0 and part.Transparency < 1
			local show
			if bar.IsCore then
				local near = root ~= nil and (part.Position - root.Position).Magnitude < NEAR_DISTANCE
				show = alive and (part:GetAttribute("Unlocked") == true or near)
			else
				show = alive and hitByMe[part] == true and hp < maxHp
			end
			bar.Gui.Enabled = show
		end
	end)
end

return NodeHealthController
