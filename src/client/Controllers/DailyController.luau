--!strict
-- Daily Rewards menu (Config.Daily, Shared.Daily). Opens from the "Daily rewards" row in Settings, and once a session
-- on its own when there is a claim waiting. Sets the DailyReady attribute (something to claim) for the gear's dot.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)
local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local NativeUI = require(script.Parent.Parent.NativeUI)
local Sfx = require(script.Parent.Parent.Sfx)
local RewardFX = require(script.Parent.Parent.RewardFX)
local DailyMenu = require(script.Parent.Parent.NativeMenus.Daily)
local player = Players.LocalPlayer
local DailyController = Knit.CreateController({ Name = "DailyController" })

local OTHER_MENUS = { "ShopOpen", "IndexOpen", "RebirthOpen", "StoreOpen", "PetsOpen", "SettingsOpen", "RefineryOpen", "HatchOpen", "IntroOpen", "BackpackOpen", "PerksOpen" }

local function otherMenuOpen(): boolean
	for _, name in OTHER_MENUS do
		if player:GetAttribute(name) == true then return true end
	end
	return false
end

local function clock(seconds: number): string
	return string.format("%dh %02dm", seconds // 3600, seconds % 3600 // 60)
end

local function rewardText(cash: number, shards: number, extra: string?): string
	local parts = { "+" .. Format.cash(cash) }
	if shards > 0 then table.insert(parts, "+" .. shards .. " ◆") end
	if extra then table.insert(parts, extra) end
	return table.concat(parts, "  ")
end

function DailyController:KnitStart()
	local DailyService = Knit.GetService("DailyService")
	local HUDController = Knit.GetController("HUDController")
	local gui = NativeUI.getOrBuild("DailyMenu", DailyMenu.build)
	local panel = gui:WaitForChild("Panel") :: Frame
	local body = panel:WaitForChild("Body") :: ScrollingFrame
	local streak = body:WaitForChild("StreakCard") :: Frame
	local summary: any = nil
	local busy = false
	local popupShown = false

	local function update()
		local s = summary
		if not s then return end
		;(streak:WaitForChild("Heading") :: TextLabel).Text = string.format("Day %d streak  ·  next reset in %s", s.streak, clock(s.secondsLeft))
		for index = 1, Config.Daily.CycleLength do
			local chip = (streak:WaitForChild("Days") :: Frame):FindFirstChild("Day" .. index) :: Frame?
			if chip then
				local done = index < s.cycleDay or (index == s.cycleDay and s.claimedToday)
				chip.BackgroundColor3 = if done then NativeUI.GREEN elseif index == s.cycleDay then NativeUI.ORANGE else NativeUI.PANEL
			end
		end
		;(streak:WaitForChild("Reward") :: TextLabel).Text = (if s.claimedToday then "Claimed today. Back tomorrow for: " else "Today pays: ")
			.. rewardText(s.reward.cash, s.reward.shards, if s.reward.petXp > 0 then "+" .. s.reward.petXp .. " pet XP" else nil)
		local claim = streak:WaitForChild("Claim") :: TextButton
		NativeUI.enable(claim, not s.claimedToday and not busy, NativeUI.GREEN)
		claim.Text = if s.claimedToday then "CLAIMED" else "CLAIM"
		local note = if s.willReset then " Your streak will start over."
			elseif s.shieldsToUse > 0 then " A shield will cover your missed days."
			else ""
		;(streak:WaitForChild("Shields") :: TextLabel).Text = string.format("Streak shields: %d. Each covers one missed day.%s", s.shields, note)

		local rows: { [string]: any } = { Quest1 = s.quests[1], Quest2 = s.quests[2], Quest3 = s.quests[3], Weekly = s.weekly }
		for _, name in DailyMenu.QUEST_SLOTS do
			local row = body:FindFirstChild(name) :: Frame?
			if not row then continue end
			local quest = rows[name]
			if name == "Bonus" then
				row.Visible = true
				;(row:FindFirstChild("Title") :: TextLabel).Text = "All three daily quests"
				;(row:FindFirstChild("Progress") :: TextLabel).Text = if s.bonus.claimed then "Bonus claimed" else "Claim all three to unlock"
				;(row:FindFirstChild("Reward") :: TextLabel).Text = rewardText(s.bonus.cash, s.bonus.shards)
				local claimBonus = row:FindFirstChild("Claim") :: TextButton
				NativeUI.enable(claimBonus, s.bonus.ready and not busy, NativeUI.GREEN)
				claimBonus.Text = if s.bonus.claimed then "DONE" else "CLAIM"
			elseif quest then
				row.Visible = true
				;(row:FindFirstChild("Title") :: TextLabel).Text = (if name == "Weekly" then "WEEKLY: " else "") .. quest.title
				;(row:FindFirstChild("Progress") :: TextLabel).Text = string.format("%s / %s", Format.number(quest.progress), Format.number(quest.target))
				;(row:FindFirstChild("Reward") :: TextLabel).Text = rewardText(quest.cash, quest.shards)
				local claimQuest = row:FindFirstChild("Claim") :: TextButton
				NativeUI.enable(claimQuest, quest.ready and not busy, NativeUI.GREEN)
				claimQuest.Text = if quest.claimed then "DONE" else "CLAIM"
			else
				row.Visible = false
			end
		end
		;(body:WaitForChild("Footer") :: TextLabel).Text = "Quests and the streak reset at midnight UTC."
		player:SetAttribute("DailyReady", s.anyReady == true)
	end

	-- Calls the server, then refreshes; the reward burst plays when it paid
	local function request(call: () -> boolean)
		if busy then return end
		busy = true
		update()
		task.spawn(function()
			local ok, paid = pcall(call)
			if ok and paid then
				Sfx.play("Upgrade", nil, nil, 1.1)
				RewardFX.burst(Config.RewardFX.Colors.Rebirth, 0.8)
			end
			busy = false
			update()
		end)
	end
	;(streak:WaitForChild("Claim") :: TextButton).Activated:Connect(function()
		request(function() return DailyService:ClaimLogin() end)
	end)
	for _, name in DailyMenu.QUEST_SLOTS do
		local row = body:WaitForChild(name) :: Frame
		;(row:WaitForChild("Claim") :: TextButton).Activated:Connect(function()
			if name == "Bonus" then
				request(function() return DailyService:ClaimBonus() end)
			else
				local slot = if name == "Weekly" then "w" else "d" .. string.sub(name, 6)
				request(function() return DailyService:ClaimQuest(slot) end)
			end
		end)
	end

	player:SetAttribute("DailyOpen", false)
	NativeUI.bindOpen(gui, "DailyOpen", function()
		player:SetAttribute("DailyOpen", false)
	end)
	DailyService.Summary:Observe(function(value)
		summary = value
		update()
		-- once per session, when something is waiting and nothing else is on screen
		if value and value.anyReady and not popupShown then
			popupShown = true
			task.spawn(function()
				local waited = 0
				while (player:GetAttribute("LoadingDone") ~= true or otherMenuOpen()) and waited < 30 do
					task.wait(1)
					waited += 1
				end
				if not otherMenuOpen() and summary and summary.anyReady then
					player:SetAttribute("DailyOpen", true)
				end
			end)
		end
	end)
	DailyService.Notice:Connect(function(message: string)
		HUDController:Toast(message)
	end)
	-- the countdown in the heading
	task.spawn(function()
		while true do
			task.wait(30)
			if summary then summary.secondsLeft = math.max(0, summary.secondsLeft - 30) end
			if gui.Enabled then update() end
		end
	end)
end

return DailyController
