--!strict
-- The field gates on the map (Map.Gates.<FieldId>, built by tools/map-v3/Fields): a gate still closed to this player
-- shows a solid force field (the Barrier and the Walls round the field) and its rule ("Level 12") on the sign; an open
-- one hides them, lets them walk through and says OPEN.
-- This is the picture only; DebrisService refuses hits, travel and standing on a locked field on the server.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local FieldGate = require(ReplicatedStorage.Shared.FieldGate)
local FieldTravel = require(ReplicatedStorage.Shared.FieldTravel)
local WorldMap = require(ReplicatedStorage.Shared.WorldMap)

local FieldGateController = Knit.CreateController({ Name = "FieldGateController" })

local CLOSED_TRANSPARENCY = 0.35

function FieldGateController:KnitStart()
	local PlayerStateService = Knit.GetService("PlayerStateService")
	local state: any = nil
	local map = WorldMap.wait()

	local function paint(gate: Instance)
		local field = FieldTravel.find(gate.Name)
		if not field then return end
		local open = state ~= nil and FieldGate.isOpen(field, state.level or 1, state.rebirths or 0)
		for _, part in gate:GetChildren() do
			if part:IsA("BasePart") and (part.Name == "Barrier" or part.Name == "Wall") then
				part.CanCollide = not open
				part.Transparency = if open then 1 else CLOSED_TRANSPARENCY
			end
		end
		local rule = gate:FindFirstChild("Rule", true)
		if rule and rule:IsA("TextLabel") then
			rule.Text = if open then "OPEN" else string.upper(FieldGate.label(field))
		end
	end
	local function paintAll()
		local gates = map:FindFirstChild("Gates")
		if not gates then return end
		for _, gate in gates:GetChildren() do paint(gate) end
	end

	-- gates stream in and out (StreamingEnabled): paint each one as its parts arrive
	map.DescendantAdded:Connect(function(item)
		if item.Name ~= "Barrier" and item.Name ~= "Wall" and item.Name ~= "Rule" then return end
		local gates = map:FindFirstChild("Gates")
		if not gates then return end
		local gate = item
		while gate.Parent and gate.Parent ~= gates do gate = gate.Parent :: Instance end
		if gate.Parent == gates then paint(gate) end
	end)
	PlayerStateService.State:Observe(function(value)
		state = value
		paintAll()
	end)
	paintAll()
end

return FieldGateController
