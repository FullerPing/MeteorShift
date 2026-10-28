--!strict
-- Reports menu opens to TelemetryService (menu_opened). The menus already mark themselves open with a
-- "<Name>Open" attribute on the local player; this watches the ones in Config.Telemetry.Menus and sends the
-- name on each false-to-true change. The server checks the name and caps the count, so this stays dumb.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Config = require(ReplicatedStorage.Shared.Config)

local player = Players.LocalPlayer
local TelemetryController = Knit.CreateController({ Name = "TelemetryController" })

function TelemetryController:KnitStart()
	local TelemetryService = Knit.GetService("TelemetryService")
	for _, menu in Config.Telemetry.Menus do
		local attribute = menu .. "Open"
		local wasOpen = player:GetAttribute(attribute) == true
		player:GetAttributeChangedSignal(attribute):Connect(function()
			local open = player:GetAttribute(attribute) == true
			if open and not wasOpen then
				TelemetryService.MenuOpened:Fire(menu)
			end
			wasOpen = open
		end)
	end
end

return TelemetryController
