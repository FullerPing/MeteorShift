--!strict
-- Arriving in a world past the first (Config.Worlds): once the loading screen is gone, a banner in the menus' look
-- (MenuTheme) pops in under the meteor timer, "WELCOME TO / NEBULA RIFT" and the world's blurb, then shrinks away.
-- World 1 has the intro and tutorial instead, so it shows nothing there.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Worlds = require(ReplicatedStorage.Shared.Worlds)
local Palette = require(ReplicatedStorage.Shared.MenuPalette)
local Theme = require(script.Parent.Parent.MenuTheme)
local N = require(script.Parent.Parent.NativeUI)
local Sfx = require(script.Parent.Parent.Sfx)

local player = Players.LocalPlayer

local WorldWelcomeController = Knit.CreateController({ Name = "WorldWelcomeController" })

local WIDTH, HEIGHT = 520, 132
local SHOW_FOR = 6 -- seconds

function WorldWelcomeController:KnitStart()
	local world = Worlds.here()
	if world.Id == 1 then return end
	task.spawn(function()
		local waited = 0
		while player:GetAttribute("LoadingDone") ~= true and waited < 30 do
			waited += task.wait(0.25)
		end
		task.wait(1)

		local gui = N.create("ScreenGui", { Name = "WorldWelcome", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 40,
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, nil) :: ScreenGui
		local panel = Theme.panel(gui, "Banner", UDim2.fromOffset(WIDTH, HEIGHT))
		panel.AnchorPoint, panel.Position = Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0.19, 0)
		local scale = N.create("UIScale", { Scale = 0 }, panel) :: UIScale

		local small = Theme.label(panel, "Welcome", "WELCOME TO", 22, Palette.SECOND, Theme.TITLE_FONT, Enum.TextXAlignment.Center)
		small.Position, small.Size, small.ZIndex = UDim2.fromOffset(0, 14), UDim2.new(1, 0, 0, 26), 3
		local name = Theme.label(panel, "World", string.upper(world.Name), 46, world.Color, Theme.TITLE_FONT, Enum.TextXAlignment.Center)
		name.Position, name.Size, name.ZIndex = UDim2.fromOffset(0, 40), UDim2.new(1, 0, 0, 50), 3
		Theme.ink(name, true, 3)
		local blurb = Theme.label(panel, "Blurb", world.Blurb, 18, Palette.NAVY, nil, Enum.TextXAlignment.Center)
		blurb.Position, blurb.Size, blurb.ZIndex = UDim2.fromOffset(0, 94), UDim2.new(1, 0, 0, 24), 3
		gui.Parent = player:WaitForChild("PlayerGui")

		-- narrower than the banner on a phone: shrink it to fit with a 16 px margin each side
		local fit = math.min(1, (workspace.CurrentCamera.ViewportSize.X - 32) / WIDTH)
		TweenService:Create(scale, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = fit }):Play()
		Sfx.play("LevelUp")
		task.wait(SHOW_FOR)
		local away = TweenService:Create(scale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Scale = 0 })
		away.Completed:Connect(function() gui:Destroy() end)
		away:Play()
	end)
end

return WorldWelcomeController
