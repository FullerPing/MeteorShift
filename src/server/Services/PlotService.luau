--!strict
-- Plot assignment (spec §2): a free plot on join, cleared on leave. The plots,
-- hoppers and refinery machines are saved in Workspace.Map.Plots; this service
-- only claims them and updates their signs and lock visuals.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Signal = require(ReplicatedStorage.Packages.Signal)

local PlotService = Knit.CreateService({
	Name = "PlotService",
	Client = {},
})

PlotService.PlotAssigned = Signal.new() -- (player, plot)
PlotService.PlotReleased = Signal.new() -- (player, plot)

local plots: { Model } = {}
local owners: { [Model]: Player } = {}
local byPlayer: { [Player]: Model } = {}

local function setSign(plot: Model, text: string)
	local sign = plot:FindFirstChild("Sign")
	local label = sign and sign:FindFirstChild("Label")
	local textLabel = label and label:FindFirstChild("Text")
	if textLabel and textLabel:IsA("TextLabel") then
		textLabel.Text = text
	end
end

function PlotService:GetPlot(player: Player): Model?
	return byPlayer[player]
end

function PlotService:GetOwner(plot: Model): Player?
	return owners[plot]
end

-- The plot a part belongs to, if any.
function PlotService:PlotOf(part: Instance): Model?
	local node: Instance? = part
	while node and node ~= workspace do
		if node:IsA("Model") and node:GetAttribute("PlotId") then
			return node
		end
		node = node.Parent
	end
	return nil
end

function PlotService:_assign(player: Player)
	for _, plot in plots do
		if not owners[plot] then
			owners[plot] = player
			byPlayer[player] = plot
			plot:SetAttribute("OwnerUserId", player.UserId)
			player:SetAttribute("PlotId", plot:GetAttribute("PlotId"))
			setSign(plot, player.DisplayName .. "'s Colony")
			self.PlotAssigned:Fire(player, plot)
			return
		end
	end
	warn("[PlotService] no free plot for", player.Name)
end

function PlotService:_release(player: Player)
	local plot = byPlayer[player]
	if not plot then
		return
	end
	self.PlotReleased:Fire(player, plot)
	owners[plot] = nil
	byPlayer[player] = nil
	plot:SetAttribute("OwnerUserId", nil)
	setSign(plot, "Plot " .. tostring(plot:GetAttribute("PlotId")) .. " · free")
end

function PlotService:KnitInit()
	local folder = workspace:WaitForChild("Map"):WaitForChild("Plots")
	for _, child in folder:GetChildren() do
		if child:IsA("Model") and child:GetAttribute("PlotId") then
			table.insert(plots, child)
		end
	end
	table.sort(plots, function(a, b)
		return (a:GetAttribute("PlotId") :: number) < (b:GetAttribute("PlotId") :: number)
	end)
	for _, plot in plots do
		setSign(plot, "Plot " .. tostring(plot:GetAttribute("PlotId")) .. " · free")
	end
end

function PlotService:KnitStart()
	Players.PlayerAdded:Connect(function(player)
		self:_assign(player)
	end)
	for _, player in Players:GetPlayers() do
		self:_assign(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		self:_release(player)
	end)
end

return PlotService
