--!strict
-- Daily Rewards menu (Config.Daily, Shared.Daily). Opens from the DAILY button in the HUD or the "Daily rewards" row in
-- Settings, and once a session on its own when there is a claim waiting; none of that happens until the first-session
-- tutorial is finished or skipped. Sets DailyReady (something to claim) for the dots and DailyUnlocked for the Settings row.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)
local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local NativeUI = require(script.Parent.Parent.NativeUI)
local ExactNavButton = require(script.Parent.Parent.ExactNavButton)
local Sfx = require(script.Parent.Parent.Sfx)
local RewardFX = require(script.Parent.Parent.RewardFX)
local DailyMenu = require(script.Parent.Parent.NativeMenus.Daily)
local player = Players.LocalPlayer
local DailyController = Knit.CreateController({ Name = "DailyController" })

local OTHER_MENUS = { "ShopOpen", "IndexOpen", "RebirthOpen", "StoreOpen", "PetsOpen", "CodesOpen", "SettingsOpen", "RefineryOpen", "HatchOpen", "IntroOpen", "BackpackOpen", "PerksOpen" }

local function otherMenuOpen(): boolean
	for _, name in OTHER_MENUS do
		if player:GetAttribute(name) == true then return true end
	end
	return false
end

local function clock(seconds: number): string
	return string.format("%dh %02dm", seconds // 3600, seconds % 3600 // 60)
end

local JACKPOT = Color3.fromRGB(176, 128, 255) -- day 7's tile colour, the same as in NativeMenus/Daily

-- A day tile's reward: the cash on the first line, then whatever else the day pays
local function prizeText(entry: any): string
	local lines = { Format.cash(entry.cash) }
	if entry.shards > 0 then table.insert(lines, "+" .. entry.shards .. " \u{25C6}") end
	if entry.petXp > 0 then table.insert(lines, "+" .. entry.petXp .. " pet XP") end
	if entry.shield > 0 then table.insert(lines, "+1 shield") end
	return table.concat(lines, "\n")
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
	-- the Daily Rewards button in the HUD's menu row (Shared.HudLayout places it as DAILY); it carries the ready dot
	local navGui = Instance.new("ScreenGui")
	navGui.Name, navGui.ResetOnSpawn, navGui.IgnoreGuiInset, navGui.DisplayOrder = "DailyNav", false, true, 24
	navGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	navGui.Parent = player:WaitForChild("PlayerGui")
	local nav = ExactNavButton.author(navGui, "DailyButton", "Daily", Config.HudIcons.daily)
	local navRefs = ExactNavButton.bind(nav)
	local panel = gui:WaitForChild("Panel") :: Frame
	NativeUI.fitCentred(panel, Vector2.new(660, 640))
	local body = panel:WaitForChild("Body") :: ScrollingFrame
	local streak = body:WaitForChild("StreakCard") :: Frame
	local summary: any = nil
	local busy = false
	local popupShown = false
	local tutorialDone = false

	local function update()
		local s = summary
		if not s then return end
		;(streak:WaitForChild("Heading") :: TextLabel).Text = string.format("Day %d streak  ·  next reset in %s", s.streak, clock(s.secondsLeft))
		local days = streak:WaitForChild("Days") :: Frame
		for index = 1, Config.Daily.CycleLength do
			local tile = days:FindFirstChild("Day" .. index) :: Frame?
			local entry = s.days[index]
			if not tile or not entry then continue end
			local claimed = index < s.cycleDay or (index == s.cycleDay and s.claimedToday)
			local today = index == s.cycleDay and not s.claimedToday
			tile.BackgroundColor3 = if today then NativeUI.ORANGE elseif index == Config.Daily.CycleLength then JACKPOT else NativeUI.CARD
			;(tile:WaitForChild("Prize") :: TextLabel).Text = prizeText(entry)
			local claim = tile:WaitForChild("Claim") :: TextButton
			if today then
				NativeUI.enable(claim, not busy, NativeUI.GREEN)
				claim.Text = "CLAIM"
			elseif claimed then
				NativeUI.enable(claim, true, NativeUI.GREEN)
				claim.Active, claim.AutoButtonColor, claim.Selectable = false, false, false
				claim.Text = "CLAIMED"
			else
				NativeUI.enable(claim, false, NativeUI.GREEN)
				claim.Text = "LOCKED!"
			end
		end
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
		local ready = s.anyReady == true and tutorialDone
		player:SetAttribute("DailyReady", ready)
		navRefs.badge.Visible = ready
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
	for index = 1, Config.Daily.CycleLength do
		local tileClaim = ((streak:WaitForChild("Days") :: Frame):WaitForChild("Day" .. index)):WaitForChild("Claim") :: TextButton
		tileClaim.Activated:Connect(function()
			request(function() return DailyService:ClaimLogin() end)
		end)
	end
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

	-- Daily Rewards stays out of the way of the first-session tutorial: the HUD button, the Settings row, the ready dot,
	-- the join popup and the menu itself all wait for it to be finished or skipped (the server says when)
	local lastHud: any = nil
	local function refreshNav()
		local slot = if lastHud then lastHud.buttons.DAILY else nil
		-- a phone too narrow for the button has no DAILY slot in its layout
		nav.Visible = tutorialDone and slot ~= nil
		if slot then ExactNavButton.layout(nav, lastHud, "DAILY") end
	end
	-- once per session, when something is waiting and nothing else is on screen
	local function tryPopup()
		-- not on the first day: a new player finds Daily Rewards in the menu themselves
		if popupShown or not tutorialDone or not summary or not summary.anyReady or summary.firstDay then return end
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

	player:SetAttribute("DailyOpen", false)
	player:SetAttribute("DailyUnlocked", false)
	player:GetAttributeChangedSignal("DailyOpen"):Connect(function()
		if player:GetAttribute("DailyOpen") == true and not tutorialDone then player:SetAttribute("DailyOpen", false) end
	end)
	NativeUI.bindOpen(gui, "DailyOpen", function()
		player:SetAttribute("DailyOpen", false)
	end)
	DailyService.TutorialDone:Observe(function(done)
		tutorialDone = done == true
		player:SetAttribute("DailyUnlocked", tutorialDone)
		if not tutorialDone then player:SetAttribute("DailyOpen", false) end
		update()
		refreshNav()
		tryPopup()
	end)
	DailyService.Summary:Observe(function(value)
		summary = value
		update()
		tryPopup()
	end)
	nav.Activated:Connect(function()
		player:SetAttribute("DailyOpen", player:GetAttribute("DailyOpen") ~= true)
	end)
	NativeUI.onLayoutChanged(function(hud)
		lastHud = hud
		refreshNav()
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
