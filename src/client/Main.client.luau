local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Sfx = require(script.Parent.Sfx)

Sfx.preload()

Knit.AddControllers(script.Parent.Controllers)

Knit.Start({ ServicePromises = false }):catch(warn)
