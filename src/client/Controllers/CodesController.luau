--!strict
-- Codes: the CODES button in the HUD (Shared.HudLayout key CODES, or the Settings row where the screen has no room
-- for it) opens a text box; CodesService checks the code and pays it.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)
local Config = require(ReplicatedStorage.Shared.Config)
local ExactNavButton = require(script.Parent.Parent.ExactNavButton)
local NativeUI = require(script.Parent.Parent.NativeUI)
local RewardFX = require(script.Parent.Parent.RewardFX)
local Sfx = require(script.Parent.Parent.Sfx)
local CodesMenu = require(script.Parent.Parent.NativeMenus.Codes)
local MenuTheme = require(script.Parent.Parent.MenuTheme)
local Palette = require(ReplicatedStorage.Shared.MenuPalette)
local player = Players.LocalPlayer
local CodesController = Knit.CreateController({ Name = "CodesController" })

local GOOD, BAD = Palette.MET, Palette.UNMET -- colours that read on the light body

function CodesController:KnitStart()
	local CodesService = Knit.GetService("CodesService")
	local gui = NativeUI.getFresh("CodesMenu", CodesMenu.build, CodesMenu.LAYOUT)
	local panel = gui:WaitForChild("Panel") :: Frame
	NativeUI.fitWhole(panel, CodesMenu.SIZE)
	local box = panel:WaitForChild("CodeBox") :: TextBox
	local redeem = panel:WaitForChild("Redeem") :: TextButton
	local result = panel:WaitForChild("Result") :: Frame
	local status = result:WaitForChild("Status") :: TextLabel
	local busy = false
	-- the result strip: soft while checking, green when the code paid, pink when it did not; hidden when empty
	local function show(text: string, mood: "wait" | "good" | "bad")
		result.Visible = text ~= ""
		status.Text = text
		status.TextColor3 = if mood == "good" then GOOD elseif mood == "bad" then BAD else Palette.SECOND
		result.BackgroundColor3 = if mood == "good" then Palette.BOOST elseif mood == "bad" then Palette.ALERT else Palette.WHITE
		local edge = result:FindFirstChildOfClass("UIStroke")
		if edge then edge.Color = if mood == "good" then Palette.BOOST_EDGE elseif mood == "bad" then Palette.ALERT_EDGE else Palette.DIVIDER end
	end

	-- the HUD button, in its own screen like the Daily one
	local navGui = Instance.new("ScreenGui")
	navGui.Name, navGui.ResetOnSpawn, navGui.IgnoreGuiInset, navGui.DisplayOrder = "CodesNav", false, true, 24
	navGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	navGui.Parent = player:WaitForChild("PlayerGui")
	local nav = ExactNavButton.author(navGui, "CodesButton", "Codes", Config.HudIcons.codes)
	ExactNavButton.bind(nav)
	nav.Activated:Connect(function()
		player:SetAttribute("CodesOpen", player:GetAttribute("CodesOpen") ~= true)
	end)
	NativeUI.onLayoutChanged(function(hud)
		local slot = hud.buttons.CODES
		-- a screen with no CODES slot keeps the button away; the Settings row still opens the menu
		nav.Visible = slot ~= nil
		if slot then ExactNavButton.layout(nav, hud, "CODES") end
	end)

	local function submit()
		if busy then return end
		local text = box.Text
		busy = true
		MenuTheme.state(redeem, false, "lime")
		show("Checking...", "wait")
		task.spawn(function()
			local ok, accepted, message = pcall(function() return CodesService:Redeem(text) end)
			if ok and accepted then
				box.Text = ""
				show(message, "good")
				Sfx.play("Upgrade", nil, nil, 1.1)
				RewardFX.burst(Config.RewardFX.Colors.Rebirth, 0.8)
			else
				show(if ok then message else "Could not reach the server. Try again.", "bad")
			end
			busy = false
			MenuTheme.state(redeem, true, "lime")
		end)
	end
	redeem.Activated:Connect(submit)
	box.FocusLost:Connect(function(enterPressed)
		if enterPressed then submit() end
	end)

	player:SetAttribute("CodesOpen", false)
	NativeUI.bindOpen(gui, "CodesOpen", function()
		player:SetAttribute("CodesOpen", false)
	end)
	player:GetAttributeChangedSignal("CodesOpen"):Connect(function()
		if player:GetAttribute("CodesOpen") == true then show("", "wait") end
	end)
end

return CodesController
