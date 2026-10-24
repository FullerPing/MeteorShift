--!strict
-- Game-wide events (Config.Events, Shared.GlobalEvents). The schedule comes from the UTC clock, so every server runs the
-- same event at the same time without talking to each other; an admin's /event reaches every server through
-- MessagingService (Config.Events.Topic) and overrides the schedule until it ends. Other services read Mult(kind);
-- clients get Current (the running event, or nil, and the next one) for the HUD card.
local MessagingService = game:GetService("MessagingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Config = require(ReplicatedStorage.Shared.Config)
local GlobalEvents = require(ReplicatedStorage.Shared.GlobalEvents)
local SafeLoop = require(script.Parent.Parent.Lib.SafeLoop)

local GlobalEventService = Knit.CreateService({
	Name = "GlobalEventService",
	Client = {
		-- { id, name, text, endsAt } of the running event (nil when none) and { id, name, startsAt } of the next
		Current = Knit.CreateProperty(nil),
	},
})

local override: GlobalEvents.Active? = nil
local active: GlobalEvents.Active? = nil

function GlobalEventService:Active(): GlobalEvents.Active?
	return active
end

-- The multiplier the running event gives `kind` ("sales", "shards", "xp", "relics", "countdown"); 1 when none
function GlobalEventService:Mult(kind: string): number
	return GlobalEvents.mult(active, kind)
end

local function publishState()
	local now = os.time()
	local nextUp = GlobalEvents.nextStart(now)
	local def = if active then GlobalEvents.def(active.id) else nil
	local nextDef = GlobalEvents.def(nextUp.id) :: Config.Event
	GlobalEventService.Client.Current:Set({
		active = if active and def then { id = active.id, name = def.Name, text = def.Text, endsAt = active.endsAt } else nil,
		nextUp = { id = nextUp.id, name = nextDef.Name, startsAt = nextUp.startsAt },
	})
end

-- Starts `id` on every server for `minutes` (admin /event). Returns a reply for the chat command.
function GlobalEventService:StartEverywhere(id: string, minutes: number): string
	local def = GlobalEvents.def(id)
	if not def then
		local ids = {}
		for _, list in { Config.Events.List, Config.Events.AdminOnly } do
			for _, event in list do table.insert(ids, event.Id) end
		end
		return "No such event. Events: " .. table.concat(ids, ", ")
	end
	local now = os.time()
	local message = { id = id, startsAt = now, endsAt = now + math.clamp(minutes, 1, Config.Events.MaxAdminMinutes) * 60 }
	override = message
	local ok, err = pcall(function() MessagingService:PublishAsync(Config.Events.Topic, message) end)
	return def.Name .. " started for " .. math.floor((message.endsAt - now) / 60) .. " min" .. (if ok then " on every server" else " here (other servers not reached: " .. tostring(err) .. ")")
end

function GlobalEventService:KnitStart()
	task.spawn(function()
		local ok, err = pcall(function()
			MessagingService:SubscribeAsync(Config.Events.Topic, function(packet)
				local data = packet.Data
				if type(data) == "table" and type(data.id) == "string" and type(data.startsAt) == "number" and type(data.endsAt) == "number" then
					override = { id = data.id, startsAt = data.startsAt, endsAt = data.endsAt }
				end
			end)
		end)
		if not ok then warn("[GlobalEventService] no cross-server events: " .. tostring(err)) end
	end)
	task.spawn(function()
		local lastKey = ""
		while true do
			SafeLoop.step("GlobalEvents", function()
				local now = os.time()
				active = GlobalEvents.current(now, override)
				local key = (if active then active.id .. active.endsAt else "none") .. "/" .. GlobalEvents.nextStart(now).startsAt
				if key ~= lastKey then
					lastKey = key
					publishState()
				end
			end)
			task.wait(1)
		end
	end)
end

return GlobalEventService
