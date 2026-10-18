# Merged Gear Level and Rebirth Price Inflation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans (the owner wants this run inline in one session, no sub-agent fan-out). Steps use checkbox (`- [ ]`) syntax.

**Goal:** One level per gear item that evolves every 10 levels with slightly harder pricing, plus a 3x-per-rebirth cash price inflation matched by a retuned rebirth cost list and an extended number format.

**Architecture:** `Shared.Gear` and `Config.Gear` are rewritten around a single `level` per item (stored as `pickaxeLevel` / `backpackLevel`); a pure `Lib.GearMigration` converts old saves. Price inflation is one pure function, `Rebirth.priceMult(rebirths)`, passed as a trailing `priceMult` into `Gear` price functions and multiplied onto station costs where they are charged and shown. The `Pacing` model learns both changes and the rebirth `Costs` list is refit to it.

**Tech Stack:** Luau (Roblox), Rojo sync, Knit services, the `tests/Runner.luau` harness run inside Studio.

**Specs:**
- `docs/archive/superpowers/specs/2026-10-10-merged-gear-level-design.md`
- `docs/archive/superpowers/specs/2026-10-10-rebirth-price-inflation-design.md`

## Global Constraints

- Evolving stays a separate paid step at the cap: cash, shards, `Levels.evolveLevel` player-level gate (unchanged).
- Pickaxe price curve `Base 45, Growth 1.12`; backpack `Base 37.5, Growth 1.12`; `LevelsPerTier = 10`.
- `Rebirth.priceMult(n) = 3^n` for listed ranks, then x `Legacy.PriceGrowth = 1.2` per rank (`CashMult` stays 5, `Legacy.MultGrowth` stays 2).
- Rebirth keeps gear tiers (already shipped in `RebirthReset.luau`); the level resets to `Gear.levelsForTier(tier)`.
- Shard prices, Robux cash products, and the `Costs` structure (a list of 16, then Legacy growth) do not change shape.
- Save version goes 6 to 7. Server stays the authority on every price; the client only displays it.
- Tests run in Studio edit mode: `require(game.ServerStorage.Tests.Runner)("<filter>")` through `mcp__Roblox_Studio__execute_luau` (Edit datamodel); all 510 existing cases must still pass at the end, apart from cases deliberately rewritten.
- Do not commit unless the owner asks (the branch has a large uncommitted working tree).

## Review Focus

- Old save has `power` above the tier cap, a missing stat, or a non-number: migration clamps to `1..cap(tier)`, never errors (Task 2).
- Old save with speed/reach/crit levels above the tier's fresh level: refund is exact at the old prices, and applied exactly once (Task 2).
- MAX buy at a high rebirth count: the client's `Gear.bulk` total equals what the server charges level by level, with `priceMult` applied identically on both sides (Tasks 4, 6).
- Legacy ranks beyond the listed 16: `priceMult` stays finite and the 5/3 ratio against `multiplier` holds (Task 5).
- Head Start raises the tier above what was owned: the level is `levelsForTier(newTier)`, not a stale value from the old tier (Task 3).
- Numbers past `Dc` and non-finite input to `Format.number`: no crash, no "1000Dc" style overflow (Task 8).

---

## Part A: merged gear level

### Task 1: Single-level `Config.Gear` and `Shared.Gear`

**Files:**
- Modify: `src/shared/Config/Gear.luau`
- Modify: `src/shared/Gear.luau`
- Test: `tests/Gear.spec.luau` (rewrite)

**Interfaces:**
- Produces (all pure; `priceMult` defaults to 1):
  - `Gear.cap(tier): number`, `Gear.levelsForTier(tier): number`, `Gear.power(level): number` (unchanged)
  - `Gear.pickaxe(tier, level): PickaxeInfo` (fields as today: Tier, Name, Color, OrePerHit, Damage, Swing, Power, Reach, CritChance, CritMult, Cost, Shards)
  - `Gear.capacity(tier, level): number`
  - `Gear.price(kind, level, priceMult?): number?`
  - `Gear.canLevel(kind, tier, level): boolean`
  - `Gear.evolution(kind, tier, level, priceMult?): Evolution?` (`{ tier, cost, shards, ready }`)
  - `Gear.bundleCost(kind, tier, priceMult?): number`
  - `Gear.bulk(kind, tier, level, cash, limit, priceMult?): (count, total, allowed, allowedTotal)`
  - `Gear.cleanLevel(tier, saved): number`

- [ ] **Step 1: Rewrite `tests/Gear.spec.luau` for the single level** (failing first, since the module still has the old API). Cases to include, using `Gear.levelsForTier(tier)` as the fresh level:
  - a fresh item of each tier matches the tier table (`Gear.pickaxe(tier, Gear.levelsForTier(tier))` Swing/Damage/OrePerHit/Power, `Gear.capacity(tier, Gear.levelsForTier(tier))` vs `Config.Backpacks`).
  - Power, Swing and capacity grow smoothly across levels 1..80 and level 10 stays below tier 2's value.
  - Reach and Crit follow the one level: `Gear.pickaxe(1, 1).Reach == MineRange`, `CritChance == 0`; `Gear.pickaxe(8, 41)` has `Reach = MineRange + 40 * ReachPerLevel` and `CritChance = 40 * CritPerLevel`.
  - tier caps (`cap`, `canLevel` at 9/10/10-tier-2/last level).
  - `Gear.price("pickaxe", 1) == Config.Gear.Pickaxe.Cost.Base` (45), rises every level, nil at level 80; `Gear.price("backpack", 1) == 38` (37.5 rounded); unknown kind returns nil.
  - `Gear.price("pickaxe", 5, 3) == math.floor(Gear.price-unscaled-formula * 3 + 0.5)` and `priceMult = nil` equals `1`.
  - evolution: ready only at the cap; quotes `Config.Pickaxes[2].Cost` x `priceMult` and the tier's shards; nil at the top tier; backpack at level 10 is ready.
  - `bundleCost("pickaxe", 2)` equals `Config.Pickaxes[2].Cost + sum(price(level) for levels 1..9)`; `bundleCost("pickaxe", 2, 3)` is exactly 3x that sum within rounding of each term; `bundleCost("pickaxe", 99) == 0`.
  - `bulk` takes as many levels as cash and the cap allow (reuse the old assertions with `price1 + price2 + 0.5` cash, `allowed == 9` in tier 1, zero cash gives zero, at the cap gives zero), and with `priceMult = 3` the total equals the sum of scaled single prices.
  - `cleanLevel(2, 999) == 20`, `cleanLevel(2, -4) == 1`, `cleanLevel(2, 7.9) == 7`, `cleanLevel(3, nil) == 21`, `cleanLevel(2, "x") == 11`, `cleanLevel(1, 0/0) == 1`.

- [ ] **Step 2: Run to confirm failure.** Run `Runner("Gear")` in Studio. Expected: failures (functions with the old signatures).

- [ ] **Step 3: Rewrite `Config/Gear.luau`.**

```lua
Gear.LevelsPerTier = 10

export type StatCost = { Base: number, Growth: number } -- cash for level L to L+1 = Base x Growth^(L-1)

Gear.Pickaxe = {
	-- readout lines in the shop; every one of them follows the item's single level
	Stats = { "power", "speed", "reach", "crit" },
	Names = { power = "Power", speed = "Swing speed", reach = "Reach", crit = "Crit chance" },
	Cost = { Base = 45, Growth = 1.12 } :: StatCost,
	ReachPerLevel = 0.15,
	CritPerLevel = 0.003,
	CritMult = 2,
}

Gear.Backpack = {
	Stats = { "capacity" },
	Names = { capacity = "Capacity" },
	Cost = { Base = 37.5, Growth = 1.12 } :: StatCost,
}
```
Update the header comment: one level per item, 1 to `LevelsPerTier x tiers`, tier t caps at `LevelsPerTier x t`, evolving at the cap. Drop `Gate`.

- [ ] **Step 4: Rewrite `Shared/Gear.luau`.** Keep `cap`, `levelsForTier`, `knot`, `power`. Replace the rest:

```lua
export type PickaxeStats = never -- removed: one level now

function Gear.pickaxe(tier: number, level: number): any
	local item = Config.Pickaxes[math.clamp(tier, 1, #Config.Pickaxes)]
	local pickaxe = Settings.Pickaxe
	return {
		Tier = item.Tier, Name = item.Name, Color = item.Color, OrePerHit = item.OrePerHit,
		Damage = knot("pickaxe", "Damage", level),
		Swing = knot("pickaxe", "Swing", level),
		Power = Gear.power(level),
		Reach = Config.Meteor.MineRange + pickaxe.ReachPerLevel * (level - 1),
		CritChance = pickaxe.CritPerLevel * (level - 1),
		CritMult = pickaxe.CritMult,
		Cost = item.Cost, Shards = item.Shards,
	}
end

function Gear.capacity(tier: number, level: number): number
	return knot("backpack", "Capacity", level)
end

function Gear.price(kind: string, level: number, priceMult: number?): number?
	if level >= LevelsPerTier * tierCount(kind) then return nil end
	local cost = settingsFor(kind).Cost
	return math.floor(cost.Base * cost.Growth ^ (level - 1) * (priceMult or 1) + 0.5)
end

function Gear.canLevel(kind, tier, level) -- unchanged

function Gear.evolution(kind: string, tier: number, level: number, priceMult: number?): Evolution?
	local list: any = if kind == "pickaxe" then Config.Pickaxes else Config.Backpacks
	local nextTier = list[tier + 1]
	if not nextTier then return nil end
	return {
		tier = nextTier.Tier,
		cost = math.floor(nextTier.Cost * (priceMult or 1) + 0.5),
		shards = nextTier.Shards,
		ready = level >= Gear.cap(tier),
	}
end

function Gear.bundleCost(kind: string, tier: number, priceMult: number?): number
	local list: any = if kind == "pickaxe" then Config.Pickaxes else Config.Backpacks
	local item = list[tier]
	if not item then return 0 end
	local total = math.floor(item.Cost * (priceMult or 1) + 0.5)
	if tier <= 1 then return total end
	for level = Gear.levelsForTier(tier - 1), Gear.cap(tier - 1) - 1 do
		total += Gear.price(kind, level, priceMult) or 0
	end
	return total
end

function Gear.bulk(kind, tier, level, cash, limit, priceMult) -- same loop as today with Gear.price(kind, current, priceMult)

function Gear.cleanLevel(tier: number, saved: any): number
	local fresh = Gear.levelsForTier(tier)
	local value = if type(saved) == "number" and saved == saved and math.abs(saved) < math.huge then saved else fresh
	return math.clamp(math.floor(value), 1, Gear.cap(tier))
end
```
Delete `freshPickaxeStats`, `freshBackpackStats`, `cleanPickaxeStats`, `cleanBackpackStats`, the `PickaxeStats` / `BackpackStats` types, and update the header comment's function list.

- [ ] **Step 5: Run `Runner("Gear")`.** Expected: all Gear cases pass. (Other specs and services that still use the old API are fixed in Tasks 2 to 4; the full suite is run in Task 4.)

### Task 2: Profile fields and the migration

**Files:**
- Create: `src/server/Lib/GearMigration.luau`
- Test: `tests/GearMigration.spec.luau`
- Modify: `src/server/Lib/ProfileTemplate.luau`, `src/server/Services/DataService.luau:105-116`

**Interfaces:**
- Consumes: `Gear.levelsForTier`, `Gear.cap`, `Gear.cleanLevel` (Task 1)
- Produces: `GearMigration.run(data: any): number` (mutates `data`: sets `pickaxeLevel`, `backpackLevel`, clears `pickaxeStats` / `backpackStats`, adds the refund to `data.cash`; returns the refund).

- [ ] **Step 1: Write `tests/GearMigration.spec.luau`** (failing: the module does not exist). Cases, each building a minimal `data = { pickaxeTier, backpackTier, pickaxeStats, backpackStats, cash }`:
  - power 7 in tier 1: `pickaxeLevel == 7`; backpack capacity 3 gives `backpackLevel == 3`; `pickaxeStats` and `backpackStats` are nil afterwards.
  - power 999 in tier 2: clamps to 20. Missing or non-numeric power: falls back to `levelsForTier(tier)`.
  - refund: tier 1, `{ power = 5, speed = 4, reach = 3, crit = 1 }` refunds speed levels 1..3 at 40 x 1.115^(l-1), reach levels 1..2 at 20 x 1.11^(l-1), crit nothing (each rounded per level, summed); expected value computed in the test from those constants. Power and backpack capacity are never refunded.
  - tier 3 save with stats at the tier's fresh level (21) refunds 0 (those levels were free).
  - running it on already-migrated data (`pickaxeStats == nil`) returns 0 and changes nothing.

- [ ] **Step 2: Run `Runner("GearMigration")`**, expect "(require)" failure.

- [ ] **Step 3: Write `Lib/GearMigration.luau`.** Old price constants live here only:

```lua
--!strict
-- Profile v6 to v7: four pickaxe stat levels and the backpack's capacity level become one level each.
-- The Gate stat (Power / Capacity) is the new level. Speed, Reach and Crit levels above a fresh
-- item's were paid for, so their cash is refunded at the old prices.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Gear = require(ReplicatedStorage.Shared.Gear)

local OLD_COST = {
	speed = { Base = 40, Growth = 1.115 },
	reach = { Base = 20, Growth = 1.11 },
	crit = { Base = 40, Growth = 1.11 },
}

local GearMigration = {}

local function level(value: any): number?
	return if type(value) == "number" and value == value and math.abs(value) < math.huge then math.floor(value) else nil
end

function GearMigration.run(data: any): number
	local refund = 0
	local pickaxeStats, backpackStats = data.pickaxeStats, data.backpackStats
	local pickaxeTier, backpackTier = data.pickaxeTier or 1, data.backpackTier or 1
	if type(pickaxeStats) == "table" then
		data.pickaxeLevel = Gear.cleanLevel(pickaxeTier, pickaxeStats.power)
		local fresh = Gear.levelsForTier(pickaxeTier)
		for stat, cost in OLD_COST do
			local owned = math.min(level(pickaxeStats[stat]) or fresh, Gear.cap(pickaxeTier))
			for l = fresh, owned - 1 do
				refund += math.floor(cost.Base * cost.Growth ^ (l - 1) + 0.5)
			end
		end
	end
	if type(backpackStats) == "table" then
		data.backpackLevel = Gear.cleanLevel(backpackTier, backpackStats.capacity)
	end
	data.pickaxeStats, data.backpackStats = nil, nil
	data.cash = (data.cash or 0) + refund
	return refund
end

return GearMigration
```
Note the refund loop starts at `fresh` because those levels beyond the tier's first were the ones bought.

- [ ] **Step 4: Run `Runner("GearMigration")`**, expect pass.

- [ ] **Step 5: `ProfileTemplate.luau`:** `version = 7`; replace the two stats lines with `pickaxeLevel = 1, backpackLevel = 1, -- gear level, 1 to the tier's cap (Shared.Gear)`; update the header comment.

- [ ] **Step 6: `DataService.luau`:** in the `< 3` block set `data.pickaxeStats, data.backpackStats = nil, nil` (the v7 step falls back to a fresh level) instead of `Gear.fresh*Stats`; replace the two `clean*Stats` lines with:

```lua
	if (data.version or 1) < 7 then
		local refund = GearMigration.run(data)
		if refund > 0 then
			data.flags = data.flags or {}
			data.flags.gearRefund = refund -- one-time notice on join (ShopService)
		end
	end
	data.pickaxeLevel = Gear.cleanLevel(data.pickaxeTier, data.pickaxeLevel)
	data.backpackLevel = Gear.cleanLevel(data.backpackTier, data.backpackLevel)
```
and `local GearMigration = require(script.Parent.Parent.Lib.GearMigration)` at the top. Also add `gearRefund = 0` is NOT added to `Template.flags` (it is only present for migrated profiles).

### Task 3: Rebirth reset, server consumers, state

**Files:**
- Modify: `src/server/Lib/RebirthReset.luau`, `src/server/Services/ShopService.luau`, `src/server/Services/PlayerStateService.luau:111-131,260-261`, `src/server/Main.server.luau:26-42,50-69,105-135`, `src/shared/WorldEquipment.luau`
- Test: `tests/RebirthReset.spec.luau`, `tests/WorldEquipment.spec.luau`

**Interfaces:**
- Consumes: Task 1 `Gear.*`, Task 2 fields.
- Produces: replicated state keys `pickaxeLevel`, `backpackLevel`; remote `ShopService.Client:Upgrade(kind)` (was `(kind, stat)`); signals `Upgraded(kind, level)` and `StatUpgraded(player, kind, level, cash)`.

- [ ] **Step 1: Update `RebirthReset.spec.luau`** (failing): the fixture sets `data.pickaxeLevel, data.backpackLevel = 64, 55` (replacing the two stats tables); the first test expects `pickaxeLevel == Gear.levelsForTier(7)` and `backpackLevel == Gear.levelsForTier(6)`; the Head Start test expects, for the raised tier 5 case, `pickaxeLevel == Gear.levelsForTier(5)`.

- [ ] **Step 2: Update `WorldEquipment.spec.luau`** to pass `pickaxeLevel` / `backpackLevel` in snapshots and expect the same derived stats as before for equal levels (a fresh level equals the old fresh stats).

- [ ] **Step 3: Run both specs**, expect failures.

- [ ] **Step 4: `RebirthReset.apply`:** replace the two `for stat, level in Gear.fresh...` loops with

```lua
	data.pickaxeLevel = Gear.levelsForTier(data.pickaxeTier)
	data.backpackLevel = Gear.levelsForTier(data.backpackTier)
```
and update the header comment.

- [ ] **Step 5: `WorldEquipment`:** `levels(...)` becomes `level(kind, tier, saved)` returning `Gear.cleanLevel(tier, saved)`-style clamping (finite check kept); `current` reads `snapshot[kind .. "Level"]` and calls `Gear.capacity(tier, level)` / `Gear.pickaxe(tier, level)`.

- [ ] **Step 6: `PlayerStateService`:** `GetPickaxe` uses `Gear.pickaxe(data.pickaxeTier, data.pickaxeLevel)` and `Gear.pickaxe(1, 1)` for the no-data case; `GetCapacity` uses `Gear.capacity(data.backpackTier, data.backpackLevel)` and `Gear.capacity(1, 1)`; the snapshot replaces the two stats lines with `pickaxeLevel = data.pickaxeLevel, backpackLevel = data.backpackLevel`.

- [ ] **Step 7: `ShopService`:** `STATS_KEY` becomes `LEVEL_KEY = { pickaxe = "pickaxeLevel", backpack = "backpackLevel" }`. `Evolve` calls `Gear.evolution(kind, current, data[LEVEL_KEY[kind]], Rebirth.priceMult(data.rebirths))` and its "Level X to N before evolving" notice reads `string.format("Reach level %d before evolving to the %s.", Gear.cap(current), item.Name)`. `UpgradeStat(player, kind, stat)` becomes `UpgradeLevel(player, kind)`: reads `local level = data[LEVEL_KEY[kind]]`, the price is `Gear.price(kind, level, Rebirth.priceMult(data.rebirths))`, writes `data[LEVEL_KEY[kind]] = level + 1`, fires `Client.Upgraded:Fire(player, kind, level + 1)` and `StatUpgraded:Fire(player, kind, level + 1, price)`. `Client:Upgrade(player, kind)` drops the stat argument and its type check. In `KnitStart`'s `DataService.ProfileLoaded` handler, after `ApplyPickaxe`, if `data.flags.gearRefund` is set, send the one-time notice through `self.Client.Notice:Fire(player, ...)` and set `data.flags.gearRefund = nil`. (Add `local Rebirth = require(ReplicatedStorage.Shared.Rebirth)`.) The notice text: `"Gear upgrades are now one level. You got $X back for the Speed, Reach and Crit levels you bought."` formatted with `Format.cash`.

- [ ] **Step 8: `Main.server.luau`:** `setGear` sets `data.pickaxeLevel = Gear.levelsForTier(data.pickaxeTier)` / the backpack equivalent; `DevGrant` likewise; `DevBench` borrows `data.backpackLevel = Gear.cap(#Config.Backpacks)` and restores `ownLevel`.

- [ ] **Step 9: Search for leftover readers** with Grep for `pickaxeStats|backpackStats|freshPickaxeStats|freshBackpackStats|clean(Pickaxe|Backpack)Stats|\.Gate\b` across `src`, `tests`, `tools`; fix each hit (including `tools/map-v2/GearHall.luau` if it reads stats) before moving on.

- [ ] **Step 10: Run `Runner("RebirthReset")`, `Runner("WorldEquipment")`**, expect pass.

### Task 4: The shop menu

**Files:**
- Modify: `src/client/Controllers/ShopController.luau`
- Check: `src/client/UpgradePanel.luau`, `src/client/NativeMenus/Shop.luau`, `src/shared/EquipmentShopLayout.luau`

**Interfaces:**
- Consumes: Task 1 `Gear.*`, Task 3 state keys `pickaxeLevel` / `backpackLevel`, remote `shop:Upgrade(kind)`; Task 6 adds `priceMult`.

Design deviation from the spec, to keep the change small: the `UpgradePanel` stat rows stay as **read-only readouts** (one per stat in `Config.Gear.<Kind>.Stats`, each showing current value and the change from the next level at the chosen amount) and a final EVOLVE row. Selecting any stat row selects the level upgrade; selecting EVOLVE selects the evolve step. `Config.Gear.<Kind>.Stats` / `.Names` are therefore kept (as display metadata).

- [ ] **Step 1:** Replace `statValue` / `statNumber` helpers so they take `(kind, stat, level)` and call `Gear.pickaxe(1, level)` for every stat (no more `levels[stat] = level` table).
- [ ] **Step 2:** In `update`, drop the hidden per-stat `Rows[stat.."Row"]` block (old lines 170-185). `stats = state[kind.."Stats"]` becomes `level = if state then state[kind .. "Level"] or 1 else 1`.
- [ ] **Step 3:** Evolve banner and view: `e = Gear.evolution(kind, tier, level, priceMult)`; the gate bar fills `level / Gear.cap(tier)`; the needs text reads `"Level " .. level .. "/" .. Gear.cap(tier)`; the evolve button copy `"Max level first"` replaces `"Max <stat> first"`.
- [ ] **Step 4:** Rows: for each stat, `value = statValue(kind, stat, level)`, `delta` from `statNumber(kind, stat, level + count) - statNumber(kind, stat, level)` where `count` is the number of levels the chosen amount would buy now (`Gear.bulk(kind, tier, level, cash, AMOUNTS[entry.amount], priceMult)`; show the 1-level delta when 0 affordable), `locked = cap`; plus the EVOLVE row as before. `entry.selected` defaults to the first stat if `Gear.canLevel(kind, tier, level)` else `"evolve"`.
- [ ] **Step 5:** Info panel for the level mode: `level = "Lv. "..level.." → "..(level + max(count,1))`, cost from `Gear.bulk` total, button states as today; `upgradeSelected` for level mode computes `wanted` with `Gear.bulk(...)` and loops `shop:Upgrade(kind)` `wanted` times (same 0.025s pacing and early break).
- [ ] **Step 6:** Delete the per-stat `Buy1/Buy10` handler loop (old lines 290-305); keep the EvolveBanner `Evolve.Activated` handler.
- [ ] **Step 7: Verify in Studio.** Start Play (standing permission, stop afterward), give cash with `ServerStorage.DevGrant`, open the GEAR menu, check: level readouts update, 1x/10x/MAX buy, cap shows "Tier cap · evolve", EVOLVE works with shards and player level, backpack tab shows Capacity only, phone layout sizes via `EquipmentShopLayout` unchanged. Watch Output for errors; capture a screenshot of both tabs.
- [ ] **Step 8: Run the full suite** (`Runner()`): expect everything but the Pacing cases (Task 7) green; fix any leftover reader reported.

---

## Part B: price inflation

### Task 5: `Rebirth.priceMult`

**Files:**
- Modify: `src/shared/Config/Rebirth.luau`, `src/shared/Rebirth.luau`
- Test: `tests/Rebirth.spec.luau`

**Interfaces:**
- Produces: `Rebirth.priceMult(rebirths: number?): number`; config keys `PriceGrowth = 3`, `Legacy.PriceGrowth = 1.2`.

- [ ] **Step 1: Add failing cases to `tests/Rebirth.spec.luau`:** `priceMult(0) == 1`, `priceMult(1) == 3`, `priceMult(16) == 3^16`, `priceMult(nil) == 1`, `priceMult(-3) == 1`; for ranks 17 and 20, `priceMult(n) == 3^16 * 1.2^(n-16)` (use `t.near` with relative epsilon); strictly increasing for ranks 0..40; `multiplier(n) / priceMult(n)` equals `(5/3)^n` for n <= 16 and `(5/3)^16 * (2/1.2)^(n-16)` after (relative near); `priceMult(200)` is finite.
- [ ] **Step 2: Run `Runner("Rebirth")`**, expect failure.
- [ ] **Step 3: Implement.** In `Config/Rebirth.luau`: `PriceGrowth = 3, -- cash price multiplier gained per rebirth ...` and `Legacy = { CostGrowth = 2.3, MultGrowth = 2, PriceGrowth = 1.2 }`. In `Shared/Rebirth.luau`:

```lua
function Rebirth.priceMult(rebirths: number?): number
	local n = count(rebirths)
	local listed = #Config.Costs
	if n <= listed then
		return Config.PriceGrowth ^ n
	end
	return Config.PriceGrowth ^ listed * Config.Legacy.PriceGrowth ^ (n - listed)
end
```
Update the header comment block.
- [ ] **Step 4: Run `Runner("Rebirth")`**, expect pass.

### Task 6: Charge and show scaled prices

**Files:**
- Modify: `src/server/Services/UpgradeService.luau:47-53`, `src/client/Controllers/RefineryController.luau` (lines using `nextLevel.Cost`: 149-150, 270-277, 295-301, 385), `src/client/Controllers/ShopController.luau`, `src/shared/Price.luau`
- Test: `tests/Price.spec.luau` (create if absent, otherwise add)

**Interfaces:**
- Consumes: `Rebirth.priceMult` (Task 5), `Gear` `priceMult` params (Task 1).
- Produces: `Price.scaled(cost: number, priceMult: number): number` = `math.floor(cost * priceMult + 0.5)`, used by every station price site so server and client round identically.

- [ ] **Step 1: Test `Price.scaled`:** `scaled(2000, 1) == 2000`, `scaled(2000, 3) == 6000`, `scaled(0.5, 3) == 2`, `scaled(0, 9) == 0`; and a station case in the spec: with `priceMult = 3^2`, `Price.scaled(Config.Home.Stations.hopper.Levels[2].Cost, 9) == 72e3` (hopper level 2 costs 8e3).
- [ ] **Step 2: Run, see it fail; implement `Price.scaled`; run, see it pass.**
- [ ] **Step 3: `UpgradeService:BuyStation`:** `local priceMult = Rebirth.priceMult(data.rebirths)`, `local cost = Price.scaled(nextLevel.Cost, priceMult)`; use `cost` in `Price.shortfall` and `data.cash -= cost`. Shards stay `nextLevel.Shards`. Add the `Rebirth` require.
- [ ] **Step 4: `RefineryController`:** at each place that reads `nextLevel.Cost`, use `Price.scaled(nextLevel.Cost, Rebirth.priceMult(state.rebirths))`. `state.rebirths` is already in the replicated state. Introduce one local `stationCost(level)` helper at the top of the controller and use it at all sites (affordability, MAX loop, button copy, the final purchase guard) so the shown price and the checked price cannot differ.
- [ ] **Step 5: `ShopController`:** compute `local priceMult = Rebirth.priceMult(if state then state.rebirths else 0)` once per `update` and pass it to every `Gear.bulk`, `Gear.price`, `Gear.evolution` call, plus the one in `upgradeSelected` and the evolve guard.
- [ ] **Step 6: Verify in Studio Play** with a rebirthed profile: `data.rebirths = 2` through a Studio hook or the existing rebirth flow; station buy button text and the charge both equal base x 9; gear MAX total equals the sum charged (check cash before/after). Stop Play.
- [ ] **Step 7: Run the full suite** (Pacing cases excepted).

### Task 7: The pacing model and the retuned rebirth costs

**Files:**
- Modify: `src/shared/Pacing.luau`, `src/shared/Config/Rebirth.luau` (`Costs`), `tests/Pacing.spec.luau`, `docs/design/economy-rework.md`

**Interfaces:**
- Consumes: `Gear.bundleCost(kind, tier, priceMult)`, `Rebirth.priceMult`.

- [ ] **Step 1: Teach `candidates` the price mult.** Give `candidates(owned, level, priceMult)` a third parameter: pickaxe and backpack `cost = Gear.bundleCost(kind, tier, priceMult)` and station `cost = Price.scaled(level.Cost, priceMult)`. In `simulate`, track `priceMult = Rebirth.priceMult(rebirths)` (1 at rank 0, updated beside `mult` on each rebirth) and pass it at every `candidates` call; the `earnedAt` bundle-price checks also use the current `priceMult`.
- [ ] **Step 2: Keep gear tiers on rebirth in the model** (matches the shipped `RebirthReset`): on rebirth, keep `owned.pickaxe` and `owned.backpack` and reset only `hopper, conveyor, collector` to 1. (Head Start and Station Memory remain unmodelled, as before.)
- [ ] **Step 3: Run `Runner("Pacing")` and record the lap times** with the current `Costs` for 8 rebirths via `execute_luau` (print each lap in minutes). Expect laps to differ from the 13/16/20/24/25 targets.
- [ ] **Step 4: Refit `Costs`.** For ranks 1..16, in Studio via `execute_luau`: for each rank r in order, binary-search the cost `c` (log scale) so lap r equals its target (13, 16, 20, 24, then 25 min) when ranks 1..r-1 use their already-fitted costs; set `Config.Rebirth.Costs[r]` in memory for each probe (the module is required fresh, edit the table in place). Round each fitted value to 2 significant digits. Paste the 16 results into `Config/Rebirth.luau` and update the comment above the list (tuned with gear tiers kept and `PriceGrowth = 3`; date 2026-10-10).
- [ ] **Step 5: Update `tests/Pacing.spec.luau`** only where the targets legitimately move: the assertions about the first four laps lengthening and laps 5-8 within 18..32 min and the first rebirth between 10 and 20 minutes must still hold with the new list; if the refit satisfies them, no edits. Early-game assertions (Steel, 15/30-minute gear, offline cap) are rank-0 and unaffected since `priceMult(0) = 1`; confirm by running them.
- [ ] **Step 6: Add one case:** with `rebirths = 3` the model's purchase `cost` for `hopper2` after the third rebirth equals `Config.Home.Stations.hopper.Levels[2].Cost * 3^3` (find it in `result.purchases` after `rebirthTimes[3]`).
- [ ] **Step 7: Run the full suite**, expect everything green. Add a "Price inflation and merged gear level (2026-10-10)" section to `docs/design/economy-rework.md` stating the factor, the new curve, the bundle table from the gear spec, the retuned `Costs` and the lap times measured.

### Task 8: Number format

**Files:**
- Modify: `src/shared/Format.luau`
- Test: `tests/Format.spec.luau`

- [ ] **Step 1: Failing cases:** `Format.number(1e33) == "1Dc"`, `Format.number(1.5e36) == "1.5Ud"`, `Format.number(9.99e39) == "9.99Dd"` (new suffixes continue Dc, Ud, Dd, Td, Qad, Qid, Sxd, Spd, Ocd, Nod, Vg), `Format.number(999.96e36)` rolls into the next suffix, never prints a four-digit value below the last suffix; `Format.number(1e200)` and `Format.number(math.huge)` do not error and print a three-digit-or-less value with the last suffix; `NaN` still returns "0"; `Format.cash` follows `Format.number`.
- [ ] **Step 2: Run `Runner("Format")`**, expect failures.
- [ ] **Step 3:** Extend `SUFFIXES` with `"Ud", "Dd", "Td", "Qad", "Qid", "Sxd", "Spd", "Ocd", "Nod", "Vg"`; clamp `math.huge` (use `math.min(abs, 1e300)`).
- [ ] **Step 4: Run `Runner("Format")`**, expect pass.

### Task 9: Player-facing text and docs

**Files:**
- Modify: `src/client/NativeMenus/Rebirth.luau:102` (rules text), `src/client/Controllers/RebirthController.luau` (next-rebirth preview), `src/shared/Config/Perks.luau` (leave Head Start's text as already edited), `README.md`, `docs/guide/native-ui.md` (if it describes the shop rows)
- Check: `assets/native-ui/GearShop.rbxmx` (unchanged: stat rows stay as hidden bindings)

- [ ] **Step 1:** Rebirth rules line: add `Prices rise x3 and sales x5 with every rebirth.` after the keeps list (keep the panel's text-fit; verify it in Play at 3 sizes).
- [ ] **Step 2:** RebirthController: where it shows the next multiplier, add the next price factor from `Rebirth.priceMult(rebirths + 1)` formatted with `Format.number`.
- [ ] **Step 3:** README: one line each for the merged level and the price inflation under the existing gear / rebirth bullets.
- [ ] **Step 4: Final verification** (superpowers:verification-before-completion): run the whole `Runner()` suite and report the exact pass/fail counts; start Play once for a complete pass (join with a migrated old-style profile built in memory by a Studio hook, buy gear, evolve, rebirth, check prices after); stop Play; check Output for errors.
- [ ] **Step 5: Update the two specs** where the implementation deviated (Task 4's retained read-only rows; `Gear.Stats`/`Names` kept), so the specs match the code.

## Self-review notes

- Spec coverage: model and API (Tasks 1, 3), economy curve and bundle table (Tasks 1, 7), migration and refund (Task 2), rebirth (Task 3), menu (Task 4), other readers (Task 3 step 9), `priceMult` rule and scaling sites (Tasks 5, 6), costs retune (Task 7), big numbers (Task 8), text (Task 9), testing (every task).
- Types: `Gear.*` signatures in Task 1 are the ones used in Tasks 3, 4, 6, 7; `LEVEL_KEY` / `pickaxeLevel` / `backpackLevel` are the same names everywhere; `Price.scaled` is defined in Task 6 and used by Task 7.
- Ordering: Task 4's full-suite run excludes Pacing because `Pacing.candidates` still calls `Gear.bundleCost(kind, tier)` (still valid, `priceMult` defaults to 1), so Pacing keeps passing until Task 7 changes the rebirth model; if it fails earlier, the cause is Task 1 and gets fixed there.
