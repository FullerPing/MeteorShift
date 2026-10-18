--!strict
-- Pure helpers behind TelemetryService (spec §13): building AnalyticsService
-- custom fields, the hours-away bucket of returned_offline_income, the
-- per-minute action counter, the rows of the meteor event summary, the player_left and session_start rows,
-- per-player meteor participation, and the id-to-key lookup for purchase prompts.
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
	SecondsToCore: number?, -- from the landing until enough crust broke to open the core, nil when it never opened
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
	if summary.SecondsToCore then
		table.insert(rows, {
			Name = "meteor_event_seconds_to_core",
			Value = math.floor(summary.SecondsToCore + 0.5),
			Fields = fields,
		})
	end
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

-- Days since the last session as a bucket for session_start: "new" for a first join (lastSeen 0), then
-- "0" (same day), "1", "2-3", "4-7", "8-30" and "30+".
local DAY_BUCKETS = { { 1, "0" }, { 2, "1" }, { 4, "2-3" }, { 8, "4-7" }, { 31, "8-30" } }

function Telemetry.daysAway(lastSeen: number, now: number): string
	if lastSeen <= 0 then
		return "new"
	end
	local days = math.max(now - lastSeen, 0) / 86400
	for _, bucket in DAY_BUCKETS do
		if days < bucket[1] then
			return bucket[2]
		end
	end
	return "30+"
end

-- How far into the game a player is, as a low-cardinality field: "r0", "r1", "r2-4", "r5-9", "r10+" rebirths.
local STAGES = { { 1, "r0" }, { 2, "r1" }, { 5, "r2-4" }, { 10, "r5-9" } }

function Telemetry.stage(rebirths: number?): string
	local n = rebirths or 0
	for _, bucket in STAGES do
		if n < bucket[1] then
			return bucket[2]
		end
	end
	return "r10+"
end

-- The session_start row: value = whole days since the last session (0 for a new player), fields = the
-- daysAway bucket, the rebirth stage and the tutorial state.
function Telemetry.sessionStart(lastSeen: number, now: number, rebirths: number?, tutorialDone: boolean): Row
	return {
		Name = "session_start",
		Value = if lastSeen > 0 then math.floor(math.max(now - lastSeen, 0) / 86400) else 0,
		Fields = { Telemetry.daysAway(lastSeen, now), Telemetry.stage(rebirths), if tutorialDone then "tutorial_done" else "in_tutorial" },
	}
end

-- One player's part in a meteor event: value = their validated hits on it, fields = meteor type, outcome and
-- their role ("core" when they hit the core, "crust" when only crust, "none" when they were in the server but
-- never swung at it).
export type Participation = { Hits: number, Core: boolean }

function Telemetry.participation(meteorType: string, cracked: boolean, part: Participation?): Row
	local role = if not part or part.Hits == 0 then "none" elseif part.Core then "core" else "crust"
	return {
		Name = "meteor_participation",
		Value = if part then part.Hits else 0,
		Fields = { meteorType, if cracked then "cracked" else "cooled", role },
	}
end

-- The pass or product key whose dashboard id is `id` in Config.Monetization's `list` (Passes or Products), or
-- nil for an id this game doesn't sell (0 never matches).
function Telemetry.keyForId(list: { [string]: { Id: number } }, id: number): string?
	if id == 0 then
		return nil
	end
	for key, def in list do
		if def.Id == id then
			return key
		end
	end
	return nil
end

-- Whether a player's events stay out of analytics: the place's owner (User-owned place) or the owning group's owner
-- (rank 255), so the owner's test sessions don't skew the numbers. `groupRank` is nil when it isn't known.
function Telemetry.excluded(creatorType: string, creatorId: number, userId: number, groupRank: number?): boolean
	if creatorType == "User" then
		return userId == creatorId
	end
	return creatorType == "Group" and (groupRank or 0) >= 255
end

-- Whether a menu name a client reported is one the analytics count (Config.Telemetry.Menus).
function Telemetry.knownMenu(menus: { string }, name: any): boolean
	return type(name) == "string" and table.find(menus, name) ~= nil
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
