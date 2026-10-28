--!strict
-- Game-wide events on the client (GlobalEventService, Config.Events): the event card over the quest tracker
-- (NativeMenus.Quests builds it, QuestController stacks it). While an event runs it shows the name, what it does and the
-- time left; in the SoonSeconds before one starts it counts down to it; otherwise it hides. Hidden while a menu is open.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)
local MenuFlags = require(script.Parent.Parent.MenuFlags)
local Sfx = require(script.Parent.Parent.Sfx)
local player = Players.LocalPlayer

local EventController = Knit.CreateController({ Name = "EventController" })
local SOON_SECONDS = 180 -- the card counts down to the next hourly event for its last 3 minutes

local function clock(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

function EventController:KnitStart()
	local GlobalEventService = Knit.GetService("GlobalEventService")
	local tracker = player:WaitForChild("PlayerGui"):WaitForChild("QuestTracker", 30)
	local card = tracker and tracker:WaitForChild("EventCard", 10) :: any
	if not card then return end
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
			task.wait(1)
		end
	end)
end

return EventController
