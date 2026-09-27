local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)

Knit.AddServices(script.Parent.Services)

Knit.Start()
	:andThen(function()
		print("[MeteorShift] server started")
		if RunService:IsStudio() then
			-- Studio only: a hook the command bar can call to hand out cash and ore for testing
			local hook = Instance.new("BindableFunction")
			hook.Name = "DevGrant"
			hook.OnInvoke = function(player: Player, cash: number?, ore: number?)
				local PlayerStateService = Knit.GetService("PlayerStateService")
				if cash then
					PlayerStateService:AddCash(player, cash)
				end
				if ore then
					PlayerStateService:AddOre(player, "iron", ore)
				end
				PlayerStateService:Replicate(player)
				return PlayerStateService:Get(player)
			end
			hook.Parent = ServerStorage
		end
	end)
	:catch(warn)
