--!strict
-- Pure helpers behind TelemetryService (spec §13): building AnalyticsService
-- custom fields, the hours-away bucket of returned_offline_income, the
-- per-minute action counter, the rows of the meteor event summary and the player_left row.
--
-- Roblox custom and economy events take at most three custom fields
-- (CustomField01..03) with low-cardinality string values, so the event summary
-- is several custom events, each carrying one number as its value and the
-- meteor type and outcome as fields, rather than one event with six fields.

local Telemetry = {}

export type Row = { Name: string, Value: number, Fields: { string } }

export type EventSummary = {
	MeteorType: string,
	Cracked: boolean,
	Players: number, -- players in the server when the event ended
	NodeHitters: number, -- players who hit at least one crust node
	CoreHitters: number, -- players who hit the core
	SecondsToCrack: number?, -- from the start of Active to the crack, nil when it cooled
}

local FIELD_KEYS = {
	Enum.AnalyticsCustomFieldKeys.CustomField01.Name,
	Enum.AnalyticsCustomFieldKeys.CustomField02.Name,
	Enum.AnalyticsCustomFieldKeys.CustomField03.Name,
}

-- A list of up to three strings as an AnalyticsService customFields dictionary.
-- Values past the third are dropped; nil or an empty list gives nil.
function Telemetry.fields(values: { string }?): { [string]: string }?
	if not values or #values == 0 then
		return nil
	end
	local fields = {}
	for index = 1, math.min(#values, #FIELD_KEYS) do
		fields[FIELD_KEYS[index]] = values[index]
	end
	return fields
end

-- Seconds away as whole hours ("0", "1", ...), with everything from `cap`
-- hours on (Config.Telemetry.HoursAwayCap) in one "<cap>+" bucket.
function Telemetry.hoursAway(seconds: number, cap: number): string
	local hours = math.floor(math.max(seconds, 0) / 3600)
	return if hours >= cap then cap .. "+" else tostring(hours)
end

-- One action by `key` in the current window.
function Telemetry.countAction<K>(counts: { [K]: number }, key: K)
	counts[key] = (counts[key] or 0) + 1
end

-- The window's counts, then a fresh window. Keys with no actions are absent.
function Telemetry.drainActions<K>(counts: { [K]: number }): { [K]: number }
	local drained = table.clone(counts)
	table.clear(counts)
	return drained
end

-- The custom events logged when a meteor event ends. meteor_event_ended (value 1)
-- counts cracked vs cooled through its outcome field.
function Telemetry.eventSummary(summary: EventSummary): { Row }
	local fields = { summary.MeteorType, if summary.Cracked then "cracked" else "cooled" }
	local rows: { Row } = {
		{ Name = "meteor_event_ended", Value = 1, Fields = fields },
		{ Name = "meteor_event_players", Value = summary.Players, Fields = fields },
		{ Name = "meteor_event_node_hitters", Value = summary.NodeHitters, Fields = fields },
		{ Name = "meteor_event_core_hitters", Value = summary.CoreHitters, Fields = fields },
	}
	if summary.Cracked and summary.SecondsToCrack then
		table.insert(rows, {
			Name = "meteor_event_seconds_to_crack",
			Value = math.floor(summary.SecondsToCrack + 0.5),
			Fields = fields,
		})
	end
	return rows
end

-- Session length as a coarse low-cardinality bucket for player_left.
local SESSION_BUCKETS = { { 2, "0-2" }, { 5, "2-5" }, { 10, "5-10" }, { 20, "10-20" }, { 40, "20-40" }, { 90, "40-90" } }

function Telemetry.sessionBucket(seconds: number): string
	local minutes = math.max(seconds, 0) / 60
	for _, bucket in SESSION_BUCKETS do
		if minutes < bucket[1] then
			return bucket[2]
		end
	end
	return "90+"
end

-- The part of the meteor cycle a Shared.Phase falls in: the wait, the event, or the few seconds after it.
-- This is what tells whether players leave between meteors (spec §15).
local LEAVE_PHASES: { [string]: string } = {
	Countdown = "countdown",
	Impact = "meteor",
	Active = "meteor",
	CoreCracked = "aftermath",
	Cooled = "aftermath",
	Cleanup = "aftermath",
}

function Telemetry.leavePhase(phase: string): string
	return LEAVE_PHASES[phase] or "unknown"
end

-- The player_left row: value = whole minutes this session, fields = cycle phase, session bucket and whether
-- the player had finished the tutorial (nil when the profile was already gone).
function Telemetry.playerLeft(sessionSeconds: number, phase: string, tutorialDone: boolean?): Row
	local onboarding = if tutorialDone == nil then "unknown" elseif tutorialDone then "tutorial_done" else "in_tutorial"
	return {
		Name = "player_left",
		Value = math.floor(math.max(sessionSeconds, 0) / 60),
		Fields = { Telemetry.leavePhase(phase), Telemetry.sessionBucket(sessionSeconds), onboarding },
	}
end

-- The compact line printed in Studio for every event, so the log proves it fired.
function Telemetry.line(kind: string, name: string, playerName: string, value: number?, fields: { string }?): string
	local parts = { "[Telemetry]", kind, name, playerName }
	if value ~= nil then
		table.insert(parts, tostring(value))
	end
	for _, field in fields or {} do
		table.insert(parts, field)
	end
	return table.concat(parts, " ")
end

return Telemetry
