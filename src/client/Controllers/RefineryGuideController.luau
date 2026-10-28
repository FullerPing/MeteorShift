--!strict
-- When the backpack is full, a sparkling orange beam runs from the player to the nearest place to drop ore: the town
-- Refinery, the Commissary or the ore chute of a field the player has open (WorldMap.refineryPoints). It hides within
-- reach of the drop-off, while the tutorial's own beam shows, and as soon as the backpack has room. Presentation only.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)
local WorldMap = require(ReplicatedStorage.Shared.WorldMap)
local FieldGate = require(ReplicatedStorage.Shared.FieldGate)
local FieldTravel = require(ReplicatedStorage.Shared.FieldTravel)

local player = Players.LocalPlayer
local RefineryGuideController = Knit.CreateController({ Name = "RefineryGuideController" })

local COLOR = Color3.fromRGB(255, 150, 40)
local HIDE_WITHIN = 14 -- studs from the drop-off: close enough to see it

function RefineryGuideController:KnitStart()
	local state: any = nil
	Knit.GetService("PlayerStateService").State:Observe(function(value) state = value end)

	local beam = Instance.new("Beam")
	beam.Name = "RefineryGuideBeam"
	beam.Color = ColorSequence.new(COLOR)
	beam.Transparency = NumberSequence.new(0, 0.4)
	beam.LightEmission = 1
	beam.FaceCamera = true
	beam.Width0, beam.Width1 = 1.6, 1.6
	beam.Segments = 1
	beam.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	beam.TextureMode = Enum.TextureMode.Static
	beam.TextureLength = 4
	beam.TextureSpeed = 1.5 -- the sparkles flow toward the drop-off
	beam.Enabled = false
	beam.Parent = workspace.CurrentCamera
	local target = Instance.new("Attachment")
	target.Name = "RefineryGuideTarget"
	target.Parent = workspace.Terrain

	task.spawn(function()
		while true do
			task.wait(0.25)
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local full = state ~= nil and (state.capacity or 0) > 0 and (state.carried or 0) >= state.capacity
			local tutorialBeam = workspace.CurrentCamera:FindFirstChild("TutorialBeam") :: Beam?
			local nearest: BasePart? = nil
			if full and root and not (tutorialBeam and tutorialBeam.Enabled) then
				local best = math.huge
				for _, point in WorldMap.refineryPoints(WorldMap.find()) do
					-- a locked field's chute stands behind its walls
					local field = FieldTravel.find((point.Parent :: Instance).Name)
					if field and field.Unlock and not FieldGate.isOpen(field, state.level or 1, state.rebirths or 0) then continue end
					local distance = (point.Position - root.Position).Magnitude
					if distance < best then best, nearest = distance, point end
				end
				if nearest and best <= HIDE_WITHIN then nearest = nil end
			end
			if nearest and root then
				local from = root:FindFirstChild("RefineryGuideFrom") :: Attachment?
				if not from then
					from = Instance.new("Attachment")
					;(from :: Attachment).Name = "RefineryGuideFrom"
					;(from :: Attachment).Parent = root
				end
				target.WorldPosition = nearest.Position
				beam.Attachment0, beam.Attachment1 = from, target
				beam.Enabled = true
			else
				beam.Enabled = false
			end
		end
	end)
end

return RefineryGuideController
