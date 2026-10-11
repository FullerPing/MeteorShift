local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Sfx = require(script.Parent.Sfx)

require(script.Parent.FixedTextSize).start()
Sfx.bindSettings()
Sfx.preload()

Knit.AddControllers(script.Parent.Controllers)

Knit.Start({ ServicePromises = false }):catch(warn)
