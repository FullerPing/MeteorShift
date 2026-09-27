local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)

Knit.AddServices(script.Parent.Services)

Knit.Start()
	:andThen(function()
		print("[MeteorShift] server started")
	end)
	:catch(warn)
