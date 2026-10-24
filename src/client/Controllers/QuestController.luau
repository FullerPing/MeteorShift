--!strict
-- The Foreman's quest line on the client (QuestService, Config.Quests): the Quests menu (NativeMenus.Quests) and the
-- HUD tracker, a small card sitting on top of the HUD's backpack card that shows the current quest and opens the menu.
-- The tracker hides while any menu is open, before the tutorial is done and once the whole line is finished.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
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
	local levelCard: GuiObject? = nil
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
		-- on a desktop the event card goes under the level card instead, wider so its text reads
		local camera = workspace.CurrentCamera
		local desktop = not UserInputService.TouchEnabled and camera.ViewportSize.X > camera.ViewportSize.Y
		if desktop and not (levelCard and levelCard.Parent) then
			local hud = player.PlayerGui:FindFirstChild("MeteorHUD")
			levelCard = hud and hud:FindFirstChild("Level", true) :: any
			if levelCard then levelCard:GetPropertyChangedSignal("AbsolutePosition"):Connect(place) end
		end
		local b = hudBackpack
		if not b then return end
		local scale = math.clamp(b.AbsoluteSize.X / 292, 0.55, 1.4)
		trackerCard.Fit.Scale = scale
		trackerCard.AnchorPoint = Vector2.new(0, 1)
		-- AbsolutePosition starts under the top bar; this ScreenGui ignores the inset, so add it back
		local inset = GuiService:GetGuiInset().Y
		trackerCard.Position = UDim2.fromOffset(b.AbsolutePosition.X, b.AbsolutePosition.Y - 8 + inset)
		-- the game-wide event card sits on top of the quest card (or in its place when the quest card is hidden)
		local eventCard = tracker:FindFirstChild("EventCard") :: any
		if eventCard and desktop and levelCard then
			local h = levelCard :: GuiObject
			eventCard.Fit.Scale = math.clamp(h.AbsoluteSize.X / 286, 0.6, 1.6) * 1.05 -- the level card is 286 px at HUD scale 1
			eventCard.Size = UDim2.fromOffset(340, 56)
			eventCard.AnchorPoint = Vector2.new(0, 0)
			local top = h.AbsolutePosition.Y + h.AbsoluteSize.Y + 10 + inset
			eventCard.Position = UDim2.fromOffset(h.AbsolutePosition.X, top)
		elseif eventCard then
			eventCard.Fit.Scale = scale
			eventCard.Size = UDim2.fromOffset(292, 56)
			eventCard.AnchorPoint = Vector2.new(0, 1)
			local above = if trackerCard.Visible then (70 + 8) * scale else 0
			eventCard.Position = UDim2.fromOffset(b.AbsolutePosition.X, b.AbsolutePosition.Y - 8 - above + inset)
		end
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
