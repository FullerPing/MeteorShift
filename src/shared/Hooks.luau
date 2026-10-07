--!strict
-- Rules for the engagement hooks (Config.Hooks): ore jackpots on the hit, the crate and
-- welcome-back rolls, the shard crumb. Pure; the server feeds them its random numbers.
-- Covered by tests/Hooks.spec.

local Config = require(script.Parent.Config)

local Settings = Config.Hooks

local Hooks = {}

-- Expected multiplier of the jackpot bands alone (a normal hit is 1)
local function veinMean(): number
	local rich, super = Settings.RichVein, Settings.SuperVein
	return (1 - rich.Chance - super.Chance) + rich.Chance * rich.Mult + super.Chance * super.Mult
end

-- Expected ore multiplier of a meteor being golden (a normal one is 1)
local function goldenMean(): number
	local golden = Settings.GoldenMeteor
	return 1 + golden.Chance * (golden.PayMult - 1)
end

-- What every normal swing's ore is multiplied by so the jackpots add nothing on average:
-- the player's expected ore per swing is the pickaxe's. (Pets' hits pay the plain average.)
function Hooks.oreBase(): number
	return 1 / (veinMean() * goldenMean())
end

-- The ore multiplier of one swing: `roll` is uniform in [0, 1). Returns the multiplier (the
-- normalizing base included) and the jackpot kind: "super", "rich" or nil.
function Hooks.vein(roll: number): (number, string?)
	local base = Hooks.oreBase()
	local super, rich = Settings.SuperVein, Settings.RichVein
	if roll < super.Chance then
		return base * super.Mult, "super"
	elseif roll < super.Chance + rich.Chance then
		return base * rich.Mult, "rich"
	end
	return base, nil
end

-- Ore of a Golden Node bonus: `hits` hits' worth of one hit's ore
function Hooks.goldenNodeOre(perHit: number, isBreaker: boolean): number
	local node = Settings.GoldenNode
	return perHit * (if isBreaker then node.Breaker else node.Contributor)
end

-- A crumb of shards for a broken crust node: `roll` and `amountRoll` are uniform in [0, 1).
function Hooks.shardCrumb(roll: number, amountRoll: number): number
	local crumb = Settings.ShardCrumb
	if roll >= crumb.Chance then
		return 0
	end
	return crumb.Min + math.min(math.floor(amountRoll * (crumb.Max - crumb.Min + 1)), crumb.Max - crumb.Min)
end

export type Crate = { kind: string, cash: number, shards: number }

-- One supply crate for a level-up. `lineIncome` is cash per second of the player's line at
-- current prices, `ceiling` the most it may pay in cash, and the three rolls are uniform in [0, 1).
function Hooks.crate(lineIncome: number, ceiling: number, bandRoll: number, sizeRoll: number, shardRoll: number): Crate
	local total = 0
	local chosen = Settings.SupplyCrate[#Settings.SupplyCrate]
	for _, band in Settings.SupplyCrate do
		total += band.Chance
		if bandRoll < total then
			chosen = band
			break
		end
	end
	local cash = 0
	if chosen.MinSeconds then
		local seconds = chosen.MinSeconds + (chosen.MaxSeconds - chosen.MinSeconds) * sizeRoll
		cash = math.floor(math.clamp(lineIncome * seconds, Settings.CrateFloor, math.max(ceiling, Settings.CrateFloor)))
	end
	local shards = 0
	if chosen.Shards then
		local range = chosen.Shards
		shards = range[1] + math.min(math.floor(shardRoll * (range[2] - range[1] + 1)), range[2] - range[1])
	end
	return { kind = chosen.Kind, cash = cash, shards = shards }
end

-- Seconds of line income a crate pays on average (the pacing model credits it per level gained)
function Hooks.crateExpectedSeconds(): number
	local total = 0
	for _, band in Settings.SupplyCrate do
		if band.MinSeconds then
			total += band.Chance * (band.MinSeconds + band.MaxSeconds) / 2
		end
	end
	return total
end

-- The welcome-back bonus multiplier for a roll in [0, 1)
function Hooks.welcomeBack(roll: number): number
	local total = 0
	for _, band in Settings.WelcomeBack do
		total += band[1]
		if roll < total then
			return band[2]
		end
	end
	return 1
end

-- Mineral odds multiplier after `dryHits` validated hits without finding any mineral: 1 until
-- Pity.AfterHits, then up by 1 each StepHits, to Pity.MaxMult. Resets when one is found.
function Hooks.pityMult(dryHits: number): number
	local pity = Settings.Pity
	if dryHits < pity.AfterHits then
		return 1
	end
	return math.min(1 + math.floor((dryHits - pity.AfterHits) / pity.StepHits) + 1, pity.MaxMult)
end

return Hooks
