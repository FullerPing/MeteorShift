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
local MenuTheme = require(script.Parent.Parent.MenuTheme)
local Palette = require(ReplicatedStorage.Shared.MenuPalette)
local player = Players.LocalPlayer
local DailyController = Knit.CreateController({ Name = "DailyController" })

local MenuFlags = require(script.Parent.Parent.MenuFlags)
local OTHER_MENUS = MenuFlags.except("DailyOpen")

local function otherMenuOpen(): boolean
	return MenuFlags.anyOpen(OTHER_MENUS)
end

local function clock(seconds: number): string
	return string.format("%dh %02dm", seconds // 3600, seconds % 3600 // 60)
end

-- a day tile's fill (a gradient, top to bottom) and outline: today's claim is gold, day 7 a pale violet jackpot, a claimed
-- day pale green and the rest white
local TILES = {
	today = { Palette.GOLD_TOP, Palette.GOLD_BOTTOM, Palette.EVO_EDGE },
	jackpot = { Color3.fromRGB(246, 236, 255), Color3.fromRGB(214, 190, 250), Color3.fromRGB(150, 110, 220) },
	claimed = { Palette.BOOST, Color3.fromRGB(212, 240, 192), Palette.BOOST_EDGE },
	plain = { Palette.WHITE, Palette.DETAIL_TOP, Palette.NAVY },
}
local function paintTile(tile: Frame, look: { Color3 })
	local gradient = tile:FindFirstChildOfClass("UIGradient")
	if gradient then gradient.Color = ColorSequence.new(look[1], look[2]) end
	local stroke = tile:FindFirstChildOfClass("UIStroke")
	if stroke then stroke.Color = look[3] end
end
-- a claim button: lime while it can be pressed, blue once done, the plain face while locked
local function paintClaim(button: GuiButton, ready: boolean, done: boolean)
	if done then MenuTheme.paint(button, "blue"); button.Active, button.Selectable = false, false
	else MenuTheme.state(button, ready, "lime") end
end

-- A day tile's reward: the cash on the first line, then whatever else the day pays
local function prizeText(entry: any): string
	local lines = { Format.cash(entry.cash) }
	if entry.shards > 0 then table.insert(lines, "+" .. entry.shards .. " shards") end
	if entry.petXp > 0 then table.insert(lines, "+" .. entry.petXp .. " pet XP") end
	if entry.shield > 0 then table.insert(lines, "+1 shield") end
	return table.concat(lines, "\n")
end

local function rewardText(cash: number, shards: number, extra: string?): string
	local parts = { "+" .. Format.cash(cash) }
	if shards > 0 then table.insert(parts, "+" .. shards .. " shards") end
	if extra then table.insert(parts, extra) end
	return table.concat(parts, "  ")
end

function DailyController:KnitStart()
	local DailyService = Knit.GetService("DailyService")
	local HUDController = Knit.GetController("HUDController")
	local gui = NativeUI.getFresh("DailyMenu", DailyMenu.build, DailyMenu.LAYOUT)
	-- the Daily Rewards button in the HUD's menu row (Shared.HudLayout places it as DAILY); it carries the ready dot
	local navGui = Instance.new("ScreenGui")
	navGui.Name, navGui.ResetOnSpawn, navGui.IgnoreGuiInset, navGui.DisplayOrder = "DailyNav", false, true, 24
	navGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	navGui.Parent = player:WaitForChild("PlayerGui")
	local nav = ExactNavButton.author(navGui, "DailyButton", "Daily", Config.HudIcons.daily)
	local navRefs = ExactNavButton.bind(nav)
	local panel = gui:WaitForChild("Panel") :: Frame
	NativeUI.fitCentred(panel, DailyMenu.SIZE)
	local body = panel:WaitForChild("Body") :: ScrollingFrame
	local streak = body:WaitForChild("StreakCard") :: Frame
	local summary: any = nil
	local busy = false
	local popupShown = false
	local tutorialDone = false
	local failNote: string? = nil -- shown in the footer after a claim the server refused

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
			paintTile(tile, if today then TILES.today elseif claimed then TILES.claimed
				elseif index == Config.Daily.CycleLength then TILES.jackpot else TILES.plain)
			;(tile:WaitForChild("Prize") :: TextLabel).Text = prizeText(entry)
			local claim = tile:WaitForChild("Claim") :: TextButton
			paintClaim(claim, today and not busy, claimed)
			claim.Text = if today then "CLAIM" elseif claimed then "CLAIMED" else "LOCKED"
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
				paintClaim(claimBonus, s.bonus.ready and not busy, s.bonus.claimed)
				claimBonus.Text = if s.bonus.claimed then "DONE" else "CLAIM"
				local done = 0
				for _, q in s.quests do if q.claimed then done += 1 end end
				;((row:FindFirstChild("Bar") :: Frame):FindFirstChild("Fill") :: Frame).Size = UDim2.fromScale(if s.bonus.claimed then 1 else math.clamp(done / math.max(#s.quests, 1), 0, 1), 1)
			elseif quest then
				row.Visible = true
				;(row:FindFirstChild("Title") :: TextLabel).Text = (if name == "Weekly" then "WEEKLY: " else "") .. quest.title
				;(row:FindFirstChild("Progress") :: TextLabel).Text = string.format("%s / %s", Format.number(quest.progress), Format.number(quest.target))
				;(row:FindFirstChild("Reward") :: TextLabel).Text = rewardText(quest.cash, quest.shards)
				local claimQuest = row:FindFirstChild("Claim") :: TextButton
				paintClaim(claimQuest, quest.ready and not busy, quest.claimed)
				claimQuest.Text = if quest.claimed then "DONE" else "CLAIM"
				;((row:FindFirstChild("Bar") :: Frame):FindFirstChild("Fill") :: Frame).Size = UDim2.fromScale(math.clamp(quest.progress / math.max(quest.target, 1), 0, 1), 1)
			else
				row.Visible = false
			end
		end
		local footer = body:WaitForChild("Footer") :: TextLabel
		footer.Text = failNote or ""
		footer.TextColor3 = if failNote then Palette.UNMET else Palette.SECOND
		local ready = s.anyReady == true and tutorialDone
		player:SetAttribute("DailyReady", ready)
		navRefs.badge.Visible = ready
	end

	-- Calls the server, then refreshes; the reward burst plays when it paid
	local function request(call: () -> boolean)
		if busy then return end
		busy = true
		failNote = nil
		update()
		task.spawn(function()
			local ok, paid = pcall(call)
			if ok and paid then
				Sfx.play("Upgrade", nil, nil, 1.1)
				RewardFX.burst(Config.RewardFX.Colors.Rebirth, 0.8)
			else
				failNote = if ok then "Couldn't claim that yet. Check the quest and try again." else "Couldn't reach the server. Try again in a moment."
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
	-- once per session, when the day's login reward is waiting and nothing else is on screen (a finished quest only
	-- shows a notification, see announceQuests)
	local function tryPopup()
		-- not on the first day: a new player finds Daily Rewards in the menu themselves
		if popupShown or not tutorialDone or not summary or summary.claimedToday or summary.firstDay then return end
		popupShown = true
		task.spawn(function()
			local waited = 0
			while (player:GetAttribute("LoadingDone") ~= true or otherMenuOpen()) and waited < 30 do
				task.wait(1)
				waited += 1
			end
			if not otherMenuOpen() and summary and not summary.claimedToday then
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
	player:GetAttributeChangedSignal("DailyOpen"):Connect(function()
		if player:GetAttribute("DailyOpen") ~= true and failNote then failNote = nil; update() end
	end)
	DailyService.TutorialDone:Observe(function(done)
		tutorialDone = done == true
		player:SetAttribute("DailyUnlocked", tutorialDone)
		if not tutorialDone then player:SetAttribute("DailyOpen", false) end
		update()
		refreshNav()
		tryPopup()
	end)
	-- A quest that becomes ready mid-session gets a notification (not the menu); what was already ready on joining is
	-- left to the DAILY button's dot
	local announced: { [string]: boolean }? = nil
	local GREEN = Color3.fromRGB(126, 230, 90)
	local function announceQuests(value: any)
		local first = announced == nil
		local seen: { [string]: boolean } = announced or {}
		announced = seen
		local items = table.clone(value.quests or {})
		if value.weekly then table.insert(items, value.weekly) end
		for _, quest in items do
			local key = quest.slot .. ":" .. quest.title
			if quest.ready and not seen[key] then
				seen[key] = true
				if not first and tutorialDone then
					HUDController:Toast("Quest complete: " .. quest.title .. "! Claim it in DAILY.", GREEN, quest.title)
					Sfx.play("Bonus")
				end
			end
		end
		if value.bonus and value.bonus.ready and not seen.bonus then
			seen.bonus = true
			if not first and tutorialDone then HUDController:Toast("All daily quests done! Claim the bonus in DAILY.", GREEN, "All daily quests done!") end
		end
	end
	DailyService.Summary:Observe(function(value)
		summary = value
		if value then announceQuests(value) end
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
