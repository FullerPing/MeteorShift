--!strict
-- The Foreman's quest line on the client (QuestService, Config.Quests): the Quests menu (NativeMenus.Quests) and the
-- HUD tracker, a small card sitting on top of the HUD's backpack card that shows the current quest and opens the menu.
-- The tracker hides while any menu is open, before the tutorial is done and once the whole line is finished.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)
local Format = require(ReplicatedStorage.Shared.Format)
local Palette = require(ReplicatedStorage.Shared.MenuPalette)
local MenuFlags = require(script.Parent.Parent.MenuFlags)
local MenuTheme = require(script.Parent.Parent.MenuTheme)
local NativeUI = require(script.Parent.Parent.NativeUI)
local QuestsMenu = require(script.Parent.Parent.NativeMenus.Quests)
local RewardFX = require(script.Parent.Parent.RewardFX)
local Sfx = require(script.Parent.Parent.Sfx)
local player = Players.LocalPlayer

local QuestController = Knit.CreateController({ Name = "QuestController" })
local OPEN = "QuestsOpen"

function QuestController:Open()
	player:SetAttribute(OPEN, true)
end

function QuestController:KnitStart()
	local QuestService = Knit.GetService("QuestService")
	local DailyService = Knit.GetService("DailyService")
	local gui = NativeUI.getFresh("QuestsMenu", QuestsMenu.build, QuestsMenu.LAYOUT)
	local panel = gui:WaitForChild("Panel") :: Frame
	NativeUI.fitCentred(panel, QuestsMenu.SIZE)
	local card = panel:WaitForChild("Card") :: any
	local claim = panel:WaitForChild("Claim") :: TextButton
	local stepLabel = panel:WaitForChild("Step") :: TextLabel
	local tracker = QuestsMenu.buildTracker()
	tracker.Parent = player:WaitForChild("PlayerGui")
	local trackerCard = tracker:WaitForChild("Card") :: any

	local summary: any = nil
	local tutorialDone = false
	local busy = false
	local place: () -> () = function() end -- set below, once the HUD's backpack card is found

	local function update()
		local s = summary
		if s then
			stepLabel.Text = string.format("QUEST %d / %d", s.step, s.count)
			card.Title.Text, card.Hint.Text = s.title, s.hint
			card.Bar.Visible, card.Count.Visible, card.Reward.Visible = true, true, true
			card.Bar.Fill.Size = UDim2.fromScale(math.clamp(s.value / math.max(s.target, 1), 0, 1), 1)
			card.Count.Text = Format.number(s.value) .. " / " .. Format.number(s.target)
			local parts = {}
			if s.shards > 0 then table.insert(parts, s.shards .. " ◆") end
			if s.cash > 0 then table.insert(parts, Format.cash(s.cash)) end
			card.Reward.Label.Text = "Reward: " .. table.concat(parts, "  +  ")
			MenuTheme.state(claim, s.done and not busy, "lime")
			claim.Text = if busy then "..." elseif s.done then "CLAIM" else "KEEP GOING"
			claim.Visible = true
		else
			stepLabel.Text = ""
			card.Title.Text, card.Hint.Text = "All quests done!", "You finished the Foreman's whole quest line. More quests are on the way."
			card.Bar.Visible, card.Count.Visible, card.Reward.Visible = false, false, false
			claim.Visible = false
		end
		-- the tracker
		local menus = MenuFlags.anyOpen()
		trackerCard.Visible = s ~= nil and tutorialDone and not menus
		place()
		if s then
			trackerCard.Title.Text = s.title
			trackerCard.Bar.Fill.Size = UDim2.fromScale(math.clamp(s.value / math.max(s.target, 1), 0, 1), 1)
			trackerCard.Count.Text = if s.done then "CLAIM!" else Format.number(s.value) .. "/" .. Format.number(s.target)
			trackerCard.Count.TextColor3 = if s.done then Palette.UP else Palette.NAVY
			trackerCard.Tag.Text = if s.done then "QUEST DONE: TAP TO CLAIM" else "QUEST " .. s.step .. " / " .. s.count
		end
	end

	-- the tracker rides on top of the HUD's backpack card, as wide as it is
	local hudBackpack: GuiObject? = nil
	place = function()
		if not hudBackpack or not hudBackpack.Parent then
			local hud = player.PlayerGui:FindFirstChild("MeteorHUD")
			hudBackpack = hud and hud:FindFirstChild("Backpack", true) :: any
			if hudBackpack then
				hudBackpack:GetPropertyChangedSignal("AbsolutePosition"):Connect(place)
				hudBackpack:GetPropertyChangedSignal("AbsoluteSize"):Connect(place)
				hudBackpack:GetPropertyChangedSignal("Visible"):Connect(place)
			end
		end
		local b = hudBackpack
		if not b then return end
		local scale = math.clamp(b.AbsoluteSize.X / 292, 0.55, 1.4)
		trackerCard.Fit.Scale = scale
		trackerCard.AnchorPoint = Vector2.new(0, 1)
		trackerCard.Position = UDim2.fromOffset(b.AbsolutePosition.X, b.AbsolutePosition.Y - 8)
		-- the game-wide event card sits on top of the quest card (or in its place when the quest card is hidden)
		-- and the hourly meteor card on top of that
		local above = if trackerCard.Visible then (70 + 8) * scale else 0
		for _, name in { "EventCard", "HourlyCard" } do
			local card = tracker:FindFirstChild(name) :: any
			if card then
				card.Fit.Scale = scale
				card.AnchorPoint = Vector2.new(0, 1)
				card.Position = UDim2.fromOffset(b.AbsolutePosition.X, b.AbsolutePosition.Y - 8 - above)
				if card.Visible then above += (56 + 8) * scale end
			end
		end
	end
	for _, name in { "Card", "EventCard" } do
		(tracker:WaitForChild(name) :: GuiObject):GetPropertyChangedSignal("Visible"):Connect(function() place() end)
	end
	task.spawn(function()
		for _ = 1, 60 do
			place()
			if hudBackpack then break end
			task.wait(1)
		end
	end)

	trackerCard.Activated:Connect(function() QuestController:Open() end)
	claim.Activated:Connect(function()
		if busy or not summary or not summary.done then return end
		busy = true
		update()
		task.spawn(function()
			local ok, paid = pcall(function() return QuestService:Claim() end)
			if ok and paid then
				Sfx.play("Upgrade", nil, nil, 1.15)
				RewardFX.burst(Color3.fromRGB(150, 230, 90), 0.8)
			end
			busy = false
			update()
		end)
	end)

	QuestService.Summary:Observe(function(value)
		summary = value
		update()
	end)
	DailyService.TutorialDone:Observe(function(done)
		tutorialDone = done == true
		update()
	end)
	QuestService.Open:Connect(function() QuestController:Open() end)
	MenuFlags.onChanged(MenuFlags.ALL, function() update() end)
	player:SetAttribute(OPEN, false)
	NativeUI.bindOpen(gui, OPEN, function() player:SetAttribute(OPEN, false) end)
	update()
end

return QuestController
