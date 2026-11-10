--!strict
-- The team's announcements (AnnounceService.Dev, from /announce and /giveall): a banner under the meteor timer in the
-- menus' look (MenuTheme), with a red DEV tag, "Name: message" and, for a gift, a lime chip "Received 500 SHARDS!".
-- It pops in with a sound, stays a few seconds and shrinks away; a newer announcement replaces it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local HudIcons = require(ReplicatedStorage.Shared.Config.HudIcons)
local Palette = require(ReplicatedStorage.Shared.MenuPalette)
local Theme = require(script.Parent.Parent.MenuTheme)
local N = require(script.Parent.Parent.NativeUI)
local Sfx = require(script.Parent.Parent.Sfx)

local player = Players.LocalPlayer

local AnnounceController = Knit.CreateController({ Name = "AnnounceController" })

local WIDTH = 600
local SHOW_FOR = 6 -- seconds
local GIFT_ICONS = { cash = "coin", shards = "crystal", pickaxe = "equipment", backpack = "backpack", pet = "pets" }

local function escape(text: string): string
	return (string.gsub(text, "[&<>\"']", { ["&"] = "&amp;", ["<"] = "&lt;", [">"] = "&gt;", ['"'] = "&quot;", ["'"] = "&apos;" }))
end

local function build(message: any): (ScreenGui, UIScale)
	local gui = N.create("ScreenGui", { Name = "DevAnnouncement", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 40,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, nil) :: ScreenGui
	local height = if message.gift then 150 else 104
	local panel = Theme.panel(gui, "Banner", UDim2.fromOffset(WIDTH, height))
	panel.AnchorPoint, panel.Position = Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0.19, 0)
	local scale = N.create("UIScale", { Scale = 0 }, panel) :: UIScale

	-- the red DEV tag poking out of the top left corner
	local tag = Theme.card(panel, "Tag", Palette.NAVY, nil, 9)
	tag.Position, tag.Size, tag.Rotation, tag.ZIndex = UDim2.fromOffset(-12, -16), UDim2.fromOffset(84, 36), -4, 6
	local face = Theme.card(tag, "Face", Palette.WHITE, nil, 7)
	face.Position, face.Size, face.ZIndex = UDim2.fromOffset(3, 3), UDim2.new(1, -6, 1, -9), 7
	Theme.gradient(face, Palette.RED_TOP, Palette.RED_BOTTOM)
	Theme.gloss(face, 0.45, 6)
	local word = Theme.label(face, "Label", "DEV", 20, Palette.WHITE, Theme.TITLE_FONT, Enum.TextXAlignment.Center)
	word.Size, word.ZIndex = UDim2.fromScale(1, 1), 8
	Theme.ink(word, true, 2)

	local line = Theme.label(panel, "Line", "", 28, Palette.NAVY, Theme.TITLE_FONT, Enum.TextXAlignment.Center)
	line.Position, line.Size, line.ZIndex = UDim2.fromOffset(28, 22), UDim2.fromOffset(WIDTH - 56, 60), 3
	line.RichText, line.TextWrapped, line.TextScaled = true, true, true
	N.create("UITextSizeConstraint", { MinTextSize = 14, MaxTextSize = 28 }, line)
	line.Text = string.format('<font color="#%s">%s</font>: %s', Palette.BLUE_BOTTOM:ToHex(), escape(message.name), escape(message.message))

	if message.gift then
		local chip = Theme.chip(panel, "Gift", HudIcons[GIFT_ICONS[message.kind] or "premium"] or "", Palette.LIME)
		chip.AnchorPoint, chip.Position, chip.Size = Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, 92), UDim2.fromOffset(330, 40)
		chip.Text = message.gift
	end
	gui.Parent = player:WaitForChild("PlayerGui")
	return gui, scale
end

function AnnounceController:KnitStart()
	local AnnounceService = Knit.GetService("AnnounceService")
	local current: ScreenGui? = nil
	AnnounceService.Dev:Connect(function(message: any)
		if current then current:Destroy() end
		local gui, scale = build(message)
		current = gui
		-- narrower than the banner on a phone: shrink it to fit with a 16 px margin each side
		local camera = workspace.CurrentCamera
		local fit = math.min(1, (camera.ViewportSize.X - 32) / WIDTH)
		TweenService:Create(scale, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = fit }):Play()
		Sfx.play(if message.gift then "LevelUp" else "Bonus")
		task.delay(SHOW_FOR, function()
			if current ~= gui then return end
			local away = TweenService:Create(scale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Scale = 0 })
			away.Completed:Connect(function() gui:Destroy() end)
			away:Play()
			current = nil
		end)
	end)
end

return AnnounceController
