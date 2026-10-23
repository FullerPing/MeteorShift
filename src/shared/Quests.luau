--!strict
-- The Foreman's quest line (Config.Quests): which step a player is on, how far along it is, adding event progress
-- and the reward. Pure; QuestService owns profile.quest = { step, progress } and tests/Quests.spec covers this.
--
--   step(state)                 the current step's definition, nil once the whole line is done
--   value(def, data, progress)  how far along: the event count, or the profile value for a state step
--   done(def, data, progress)
--   addProgress(state, event, amount, field)  counts an event toward the current step; true when it changed
--   advance(state)              moves to the next step and starts its count at 0
--   reward(def, perSecond, ceiling)
--   summary(data, perSecond, ceiling)  what the tracker and the menu draw
local Config = require(script.Parent.Config.Quests)
local Income = require(script.Parent.Income)

local Quests = {}

export type State = { step: number, progress: number }
export type Summary = {
	step: number, count: number, id: string, title: string, hint: string, value: number, target: number, done: boolean,
	shards: number, cash: number,
}

function Quests.clean(state: any): State
	local step = if type(state) == "table" and type(state.step) == "number" and state.step == state.step then math.max(1, math.floor(state.step)) else 1
	local progress = if type(state) == "table" and type(state.progress) == "number" and state.progress == state.progress then math.max(0, state.progress) else 0
	return { step = step, progress = progress }
end

function Quests.step(state: State): Config.Step?
	return Config.Line[state.step]
end

local function ownedPets(data: any): number
	local count = 0
	if type(data.pets) == "table" and type(data.pets.owned) == "table" then
		for _ in data.pets.owned do count += 1 end
	end
	return count
end

function Quests.value(def: Config.Step, data: any, progress: number): number
	if def.Kind == "event" then return progress end
	if def.Kind == "petsOwned" then return ownedPets(data) end
	local value = data[def.Kind]
	return if type(value) == "number" then value else 0
end

function Quests.done(def: Config.Step, data: any, progress: number): boolean
	return Quests.value(def, data, progress) >= def.Target
end

function Quests.addProgress(state: State, event: string, amount: number, field: string?): boolean
	local def = Quests.step(state)
	if not def or def.Kind ~= "event" or def.Event ~= event then return false end
	if def.Field and def.Field ~= field then return false end
	if state.progress >= def.Target or not (amount > 0) then return false end
	state.progress = math.min(def.Target, state.progress + amount)
	return true
end

function Quests.advance(state: State)
	state.step += 1
	state.progress = 0
end

function Quests.reward(def: Config.Step, perSecond: number, ceiling: number): { cash: number, shards: number }
	local rate = if perSecond == perSecond and perSecond > 0 then perSecond else 0
	local cap = if ceiling == ceiling and ceiling > 0 then ceiling else 0
	return { cash = Income.grant(def.Minutes * 60, rate, Config.CashFloor, cap), shards = def.Shards }
end

function Quests.summary(data: any, perSecond: number, ceiling: number): Summary?
	local state = Quests.clean(data.quest)
	local def = Quests.step(state)
	if not def then return nil end
	local reward = Quests.reward(def, perSecond, ceiling)
	return {
		step = state.step, count = #Config.Line, id = def.Id, title = def.Title, hint = def.Hint,
		value = math.min(Quests.value(def, data, state.progress), def.Target), target = def.Target,
		done = Quests.done(def, data, state.progress), shards = reward.shards, cash = reward.cash,
	}
end

return Quests
