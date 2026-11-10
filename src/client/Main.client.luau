local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Sfx = require(script.Parent.Sfx)

require(script.Parent.FixedTextSize).start()
Sfx.bindSettings()
Sfx.preload()

Knit.AddControllers(script.Parent.Controllers)

-- ClientStarted tells the loading screen every controller has started (its menus are built)
Knit.Start({ ServicePromises = false }):andThen(function()
	game:GetService("Players").LocalPlayer:SetAttribute("ClientStarted", true)
end):catch(warn)
