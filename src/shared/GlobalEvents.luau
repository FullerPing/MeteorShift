--!strict
-- Game-wide event rules (Config.Events). Pure; GlobalEventService runs them and tests/GlobalEvents.spec covers this.
--
--   scheduled(t)          the clock schedule at unix time t: { id, startsAt, endsAt } when one is running, else nil
--   nextStart(t)          the next scheduled event: { id, startsAt, endsAt }
--   current(t, override)  an admin override while it lasts, else the schedule
--   mult(active, kind)    the multiplier an active event gives `kind` (1 when none)
local Config = require(script.Parent.Config.Events)

local GlobalEvents = {}

export type Active = { id: string, startsAt: number, endsAt: number }

function GlobalEvents.def(id: string): Config.Event?
	for _, event in Config.List do
		if event.Id == id then return event end
	end
	return nil
end

local function slot(index: number): Active
	local startsAt = index * Config.Period
	local event = Config.List[index % #Config.List + 1]
	return { id = event.Id, startsAt = startsAt, endsAt = startsAt + Config.Duration }
end

function GlobalEvents.scheduled(t: number): Active?
	local index = math.floor(t / Config.Period)
	local active = slot(index)
	return if t >= active.startsAt and t < active.endsAt then active else nil
end

function GlobalEvents.nextStart(t: number): Active
	local index = math.floor(t / Config.Period)
	local this = slot(index)
	return if t < this.startsAt then this else slot(index + 1)
end

function GlobalEvents.current(t: number, override: Active?): Active?
	if override and GlobalEvents.def(override.id) and t >= override.startsAt and t < override.endsAt then return override end
	return GlobalEvents.scheduled(t)
end

function GlobalEvents.mult(active: Active?, kind: string): number
	local def = if active then GlobalEvents.def(active.id) else nil
	local value = if def then def.Effects[kind] else nil
	return if type(value) == "number" and value > 0 then value else 1
end

return GlobalEvents
