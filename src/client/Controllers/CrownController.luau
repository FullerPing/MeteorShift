--!strict
-- The Meteor Dive's flight (CrownService.Dive): the server sends the launch, this applies it to our own character.
-- PlatformStand holds off the humanoid's air control for the flight so the arc lands where it was aimed.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Sfx = require(script.Parent.Parent.Sfx)

local CrownController = Knit.CreateController({ Name = "CrownController" })

function CrownController:KnitStart()
	local player = Players.LocalPlayer
	Knit.GetService("CrownService").Dive:Connect(function(velocity: Vector3, seconds: number)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not (root and humanoid) then return end
		Sfx.play("Teleport")
		humanoid.PlatformStand = true
		root.AssemblyLinearVelocity = velocity
		-- fly until the ground (or the planned time), then cushion the landing so it doesn't bounce
		task.spawn(function()
			local started = os.clock()
			task.wait(0.3)
			while humanoid.Parent and os.clock() - started < seconds + 1 do
				local params = RaycastParams.new()
				params.FilterDescendantsInstances = { character :: Model }
				local below = workspace:Raycast(root.Position, Vector3.new(0, -5, 0), params)
				if below and root.AssemblyLinearVelocity.Y < 0 then break end
				task.wait()
			end
			if humanoid.Parent then
				local v = root.AssemblyLinearVelocity
				root.AssemblyLinearVelocity = Vector3.new(v.X * 0.15, 0, v.Z * 0.15)
				humanoid.PlatformStand = false
				humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
			end
		end)
	end)
end

return CrownController
