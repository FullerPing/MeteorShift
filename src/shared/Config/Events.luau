--!strict
-- Game-wide events (Shared.GlobalEvents, GlobalEventService), owner feedback 2026-10-23: "game-wide events
-- synchronizing servers". Every server reads the same UTC clock, so the schedule needs no messaging: in the first
-- Duration seconds of every Period, the event at (hour index mod #List) runs everywhere at once. An admin can also start
-- one on every server right now with /event <id> [minutes] (MessagingService topic Topic).
-- Effects multiply what the game already pays: sales (bar sale value), shards (a cracked core's shards per player),
-- xp (player XP), relics (relic find chances) and countdown (the meteor countdown length; below 1 is faster).
export type Event = { Id: string, Name: string, Text: string, Effects: { [string]: number } }

local Events = {}

Events.Period = 3600 -- an event every UTC hour
Events.Duration = 900 -- running for its first 15 minutes
Events.Topic = "MeteorShiftGlobalEvent"
Events.MaxAdminMinutes = 120

Events.List = {
	{ Id = "goldenHour", Name = "Golden Hour", Text = "Bars sell for x2 on every server!", Effects = { sales = 2 } },
	{ Id = "shardStorm", Name = "Shard Storm", Text = "Cracked cores pay x2 Core Shards!", Effects = { shards = 2 } },
	{ Id = "meteorShower", Name = "Meteor Shower", Text = "Meteors fall twice as often!", Effects = { countdown = 0.5 } },
	{ Id = "xpRush", Name = "XP Rush", Text = "x2 player XP from everything!", Effects = { xp = 2 } },
	{ Id = "relicHunt", Name = "Relic Hunt", Text = "x3 chance to find relics!", Effects = { relics = 3 } },
} :: { Event }

return Events
