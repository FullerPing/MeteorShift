--!strict
-- Game-wide events on the client (GlobalEventService, Config.Events): the event card over the quest tracker
-- (NativeMenus.Quests builds it, QuestController stacks it). While an event runs it shows the name, what it does and the
-- time left; in the SoonSeconds before one starts it counts down to it; otherwise it hides. Above it, the hourly Quartz
-- meteor card (Config.Meteor.Hourly) always counts down to the next one. Both hide while a menu is open.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)
local Config = require(ReplicatedStorage.Shared.Config)
local MeteorTypes = require(ReplicatedStorage.Shared.MeteorTypes)
local Phase = require(ReplicatedStorage.Shared.Phase)
local MenuFlags = require(script.Parent.Parent.MenuFlags)
local Sfx = require(script.Parent.Parent.Sfx)
local player = Players.LocalPlayer

local EventController = Knit.CreateController({ Name = "EventController" })
local SOON_SECONDS = 600

local function clock(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

function EventController:KnitStart()
	local GlobalEventService = Knit.GetService("GlobalEventService")
	local tracker = player:WaitForChild("PlayerGui"):WaitForChild("QuestTracker", 30)
	local card = tracker and tracker:WaitForChild("EventCard", 10) :: any
	local hourly = tracker and tracker:WaitForChild("HourlyCard", 10) :: any
	if not card or not hourly then return end
	local meteor: any = nil
	Knit.GetService("MeteorService").State:Observe(function(value) meteor = value end)
	local hourlyName = Config.Meteor.Types[Config.Meteor.Hourly.Type].DisplayName
	local current: any = nil
	local lastActive: string? = nil
	GlobalEventService.Current:Observe(function(value)
		current = value
		local id = if value and value.active then value.active.id else nil
		if id and id ~= lastActive then Sfx.play("Bonus") end
		lastActive = id
	end)
	-- the server clock: os.time() on the client can be off, workspace:GetServerTimeNow() is the server's
	task.spawn(function()
		while true do
			local now = workspace:GetServerTimeNow()
			local show, title, text = false, "", ""
			if current and current.active then
				show, title, text = true, string.upper(current.active.name) .. "  " .. clock(current.active.endsAt - now), current.active.text
			elseif current and current.nextUp and current.nextUp.startsAt - now <= SOON_SECONDS then
				show, title, text = true, current.nextUp.name .. " in " .. clock(current.nextUp.startsAt - now), "A game-wide event on every server. Don't miss it!"
			end
			card.Visible = show and not MenuFlags.anyOpen()
			card.Title.Text, card.Text.Text = title, text
			-- the hourly meteor: always counting down, for everyone; "down now" while it is in the crater
			local down = meteor and meteor.type == Config.Meteor.Hourly.Type and (meteor.phase == Phase.Impact or meteor.phase == Phase.Active)
			if down then
				hourly.Title.Text, hourly.Text.Text = string.upper(hourlyName) .. " IS DOWN!", "Mine it in the crater: triple shards."
			else
				hourly.Title.Text = string.upper(hourlyName) .. "  " .. clock(MeteorTypes.nextHourly(now) - now)
				hourly.Text.Text = "Lands at :" .. string.format("%02d", Config.Meteor.Hourly.Minute) .. " on every server. Triple shards!"
			end
			hourly.Visible = not MenuFlags.anyOpen()
			task.wait(1)
		end
	end)
end

return EventController
